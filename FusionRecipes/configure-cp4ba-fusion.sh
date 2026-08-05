#!/usr/bin/env bash
################################################################################
# IBM CP4BA Storage Fusion Backup Configuration Script
#
# This script configures IBM Storage Fusion for CP4BA backup and restore.
# It performs the following operations:
#   1. Patches the transaction-manager ClusterRole with CP4BA permissions
#   2. Discovers the IBM Storage Fusion namespace
#   3. Patches the Fusion Application to include required namespaces
#   4. Labels CP4BA resources for backup/restore operations
#
# Usage:
#   ./configure-cp4ba-fusion-backup.sh [OPTIONS]
#
# Options:
#   -n, --namespace NAMESPACE       CP4BA namespace (required)
#   -d, --dry-run                   Show what would be done without making changes
#   -v, --verbose                   Enable verbose output
#   -h, --help                      Show this help message
#
# Examples:
#   ./configure-cp4ba-fusion-backup.sh -n cp4ba-prod
#   ./configure-cp4ba-fusion-backup.sh -n cp4ba-prod --dry-run
#
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script variables
SCRIPT_NAME=$(basename "$0")
CP4BA_NAMESPACE=""
DRY_RUN=false
VERBOSE=false

################################################################################
# Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $*"
    fi
}

show_help() {
    sed -n '/^# Usage:/,/^################################################################################$/p' "$0" | sed 's/^# \?//'
    exit 0
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    if ! ( command -v kubectl &> /dev/null || command -v oc &> /dev/null ) ; then
        missing_tools+=("kubectl or oc")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi
    
    # Define kubernetes client executable
    if command -v kubectl &> /dev/null ; then
        KC=kubectl
    else
        KC=oc
    fi
    
    # Check cluster connectivity
    if ! $KC cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    log_success "All prerequisites met"
}

discover_fusion_namespace() {
    log_info "Discovering IBM Storage Fusion namespace..." >&2
    
    local fusion_ns
    fusion_ns=$($KC get spectrumfusion -A -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    
    if [[ -z "$fusion_ns" ]]; then
        log_error "Could not discover Fusion namespace. SpectrumFusion resource not found."
        log_error "Please specify the Fusion namespace using -f/--fusion-namespace option."
        exit 1
    fi
    
    log_success "Discovered Fusion namespace: $fusion_ns" >&2
    echo "$fusion_ns"
}

patch_clusterrole() {
    log_info "Checking transaction-manager-ibm-backup-restore ClusterRole..."
    
    # Check if the ClusterRole exists
    if ! $KC get clusterrole transaction-manager-ibm-backup-restore &> /dev/null; then
        log_error "ClusterRole 'transaction-manager-ibm-backup-restore' not found. Fusion B&R Service or Fusion B&R Agent Service should be installed. Aborting."
        exit 1
    fi
    
    # Check if the rule already exists
    local rule_count
    rule_count=$($KC get clusterrole transaction-manager-ibm-backup-restore -o json | \
        jq '.rules | map(select(.apiGroups | map(. == "icp4a.ibm.com") | any)) | length')
    
    if [[ "$rule_count" -gt 0 ]]; then
        log_success "ClusterRole already has icp4a.ibm.com permissions. Skipping patch."
        return 0
    fi
    
    log_info "Patching ClusterRole to add icp4a.ibm.com permissions..."
    
    local patch='[
  {
    "op": "add",
    "path": "/rules/-",
    "value": {
      "apiGroups": [
        "icp4a.ibm.com"
      ],
      "resources": [
        "icp4aclusters",
        "icp4aoperationaldecisionmanagers",
        "contents"
      ],
      "verbs": [
        "get",
        "list"
      ]
    }
  }
]'
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would patch ClusterRole with:"
        echo "$patch" | jq .
    else
        $KC patch clusterrole transaction-manager-ibm-backup-restore --type json --patch "$patch"
        log_success "ClusterRole patched successfully"
    fi
}

patch_fusion_app() {
    local fusion_ns="$1"
    local cp4ba_ns="$2"
    
    log_info "Checking Fusion Application configuration..."
    
    # Check if the fapp exists
    if ! $KC -n "$fusion_ns" get fapp/"$cp4ba_ns" &> /dev/null; then
        log_error "Fusion Application '$cp4ba_ns' not found in namespace '$fusion_ns'. Skipping patch."
        exit 1
    fi
    
    # Check and add openshift-config namespace
    local has_config_ns
    has_config_ns=$($KC -n "$fusion_ns" get fapp/"$cp4ba_ns" -o jsonpath='{.spec.includedNamespaces[?(@=="openshift-config")]}' 2>/dev/null)
    
    if [[ -z "$has_config_ns" ]]; then
        log_info "Adding 'openshift-config' to Fusion Application includedNamespaces..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would add 'openshift-config' to fapp/$cp4ba_ns"
        else
            $KC patch fapp "$cp4ba_ns" -n "$fusion_ns" --type json \
                --patch '[{"op":"add","path":"/spec/includedNamespaces/-","value":"openshift-config"}]'
            log_success "Added 'openshift-config' to includedNamespaces"
        fi
    else
        log_success "'openshift-config' already in includedNamespaces"
    fi
    
    # Check and add openshift-marketplace namespace
    local has_marketplace_ns
    has_marketplace_ns=$($KC -n "$fusion_ns" get fapp/"$cp4ba_ns" -o jsonpath='{.spec.includedNamespaces[?(@=="openshift-marketplace")]}' 2>/dev/null)
    
    if [[ -z "$has_marketplace_ns" ]]; then
        log_info "Adding 'openshift-marketplace' to Fusion Application includedNamespaces..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would add 'openshift-marketplace' to fapp/$cp4ba_ns"
        else
            $KC patch fapp "$cp4ba_ns" -n "$fusion_ns" --type json \
                --patch '[{"op":"add","path":"/spec/includedNamespaces/-","value":"openshift-marketplace"}]'
            log_success "Added 'openshift-marketplace' to includedNamespaces"
        fi
    else
        log_success "'openshift-marketplace' already in includedNamespaces"
    fi
}

label_resource() {
    local namespace="$1"
    local resource_type="$2"
    local resource_name="$3"
    local label="$4"
    
    if ! $KC -n "$namespace" get "$resource_type" "$resource_name" &> /dev/null; then
        log_verbose "Resource $resource_type/$resource_name not found in namespace $namespace. Skipping."
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_verbose "[DRY-RUN] Would label $resource_type/$resource_name with $label"
    else
        $KC -n "$namespace" label "$resource_type" "$resource_name" "$label" --overwrite &> /dev/null || true
        log_verbose "Labeled $resource_type/$resource_name with $label"
    fi
}

label_core_resources() {
    local cp4ba_ns="$1"
    
    log_info "Labeling core CP4BA resources..."
    
    # Core resources that should always be labeled
    label_resource "openshift-config" "secret" "htpass-secret" "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" "configmap" "cp4ba-fips-status" "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" "configmap" "ibm-cp4ba-common-config" "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" "secret" "ibm-entitlement-key" "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" "secret" "cp4ba-entitlement-key-sslsecret" "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" "secret" "ibm-cp4ba-db-ssl-secret-for-dbserver1" "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" "secret" "ibm-cp4ba-ldap-ssl-secret" "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" "secret" "platform-auth-ldaps-ca-cert" "cp4ba.ibm.com/backup-type=mandatory"
    set +e
    initialization_cm="$($KC -n $cp4ba_ns get configmaps -o name | grep initialization-config | tr '/' ' ')"
    verification_cm="$($KC -n $cp4ba_ns get configmaps -o name | grep verification-config | tr '/' ' ')"
    set -e
    label_resource "$cp4ba_ns" ${initialization_cm:-"configmaps" "-"} "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" ${verification_cm:-"configmaps" "-"} "cp4ba.ibm.com/backup-type=mandatory"
    
    log_success "Core resources labeled"
}

check_component_installed() {
    local cp4ba_ns="$1"
    local component="$2"
    
    case "$component" in
        "content")
            # Check for Content CR or ICP4ACluster with content pattern
            if $KC get content -n "$cp4ba_ns" content &> /dev/null; then
                return 0
            fi
            
            local patterns
            patterns=$($KC get icp4acluster -n "$cp4ba_ns" -o jsonpath='{.items[*].spec.shared_configuration.sc_deployment_patterns}' 2>/dev/null)
            if [[ "$patterns" == *"content"* ]]; then
                return 0
            fi
            return 1
            ;;
        "workflow")
            # Check for ICP4ACluster with workflow pattern
            local patterns
            patterns=$($KC get icp4acluster -n "$cp4ba_ns" -o jsonpath='{.items[*].spec.shared_configuration.sc_deployment_patterns}' 2>/dev/null)
            if [[ "$patterns" == *"workflow"* ]]; then
                return 0
            fi
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

label_fncm_resources() {
    local cp4ba_ns="$1"
    
    # FNCM-specific resources
    label_resource "$cp4ba_ns" "secret" "ibm-icc-secret" "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" "secret" "ibm-iccsap-secret" "cp4ba.ibm.com/backup-type=mandatory"
    content_cr="$($KC -n $cp4ba_ns get contents -o name | tr '/' ' ')"

    # MongoDB certificates (commented out in original - legacy common services)
    # label_resource "$cp4ba_ns" "secret" "icp-mongodb-client-cert" "custom-label=cp4ba-mongo-cert"
    # label_resource "$cp4ba_ns" "secret" "mongodb-root-ca-cert" "custom-label=cp4ba-mongo-cert"
    
    log_success "FNCM resources labeled"
}

label_baw_resources() {
    local cp4ba_ns="$1"
    
    # BAW-specific resources
    label_resource "$cp4ba_ns" "secret" "ibm-iaws-shared-key-secret" "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" "secret" "icp4adeploy-cpe-oidc-secret" "cp4ba.ibm.com/backup-type=mandatory"
    label_resource "$cp4ba_ns" "secret" "ibm-bts-cnpg-${cp4ba_ns}-cp4ba-bts-app" "cp4ba.ibm.com/backup-type=mandatory"
    
    log_success "BAW resources labeled"
}

################################################################################
# Main Script
################################################################################

main() {
    log_info "Starting CP4BA Storage Fusion backup configuration..."
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Discover Fusion namespace if not provided
    FUSION_NAMESPACE=$(discover_fusion_namespace)
    
    # Step 3: Patch ClusterRole
    patch_clusterrole
    
    # Step 4: Patch Fusion Application
    patch_fusion_app "$FUSION_NAMESPACE" "$CP4BA_NAMESPACE"
    
    # Step 5: Label core resources
    label_core_resources "$CP4BA_NAMESPACE"
    
    # Step 6: Label FNCM resources (if installed)
    log_info "Checking for FNCM (FileNet Content Manager) installation..."
    if ! check_component_installed "$CP4BA_NAMESPACE" "content"; then
        log_info "FNCM not detected. Skipping FNCM-specific resource labeling."
    else
        log_info "FNCM detected. Labeling FNCM-specific resources..."
        label_fncm_resources "$CP4BA_NAMESPACE"
    fi
    
    # Step 7: Label BAW resources (if installed)
    log_info "Checking for BAW (Business Automation Workflow) installation..."
    if ! check_component_installed "$CP4BA_NAMESPACE" "workflow"; then
        log_info "BAW not detected. Skipping BAW-specific resource labeling."
    else
        log_info "BAW detected. Labeling BAW-specific resources..."
        label_baw_resources "$CP4BA_NAMESPACE"
    fi
    
    # Summary
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry-run completed successfully!"
        log_info "Run without --dry-run to apply changes."
    else
        log_success "CP4BA Storage Fusion backup configuration completed successfully!"
    fi
}

################################################################################
# Argument Parsing
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            CP4BA_NAMESPACE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use -h or --help for usage information."
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$CP4BA_NAMESPACE" ]]; then
    log_error "CP4BA namespace is required. Use -n or --namespace option."
    echo "Use -h or --help for usage information."
    exit 1
fi

# Run main function
main

exit 0
