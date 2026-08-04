#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2026. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
SCRIPTS_DIR="${PARENT_DIR}/scripts"

# Temporarily set CUR_DIR to scripts directory for common.sh to find helper tools
ORIGINAL_CUR_DIR="$CUR_DIR"
CUR_DIR="$SCRIPTS_DIR"

# Import common utilities and environment variables
source ${SCRIPTS_DIR}/helper/common.sh

# Restore CUR_DIR to actual script location
CUR_DIR="$ORIGINAL_CUR_DIR"

# Default values
MODEL_GATEWAY_VERSION="13.0.0"
HELM_CHART_PATH="${PARENT_DIR}/descriptors/CP4BA/helm-charts"
OPERATOR_NAMESPACE=""
INSTANCE_NAMESPACE=""
IMAGE_PULL_SECRET="ibm-entitlement-key"
IMAGE_REGISTRY="cp.icr.io"
SCALE_CONFIG="small"
LICENSE_TYPE="Enterprise"
LICENSE_ACCEPT="false"
STORAGE_CLASS_BLOCK=""
STORAGE_CLASS_FILE=""
STORAGE_VENDOR=""
LITE_INSTALL="false"
DEPLOY_INTERNAL_POSTGRES="false"
REDIS_OPERATOR_CHANNEL="v1.3"
REDIS_OPERATOR_INSTALL_PLAN="Automatic"
REDIS_OPERATOR_PACKAGE="ibm-redis-cp"
REDIS_OPERATOR_SOURCE="ibm-redis-cp-operator-catalog"
HELM_LIST_ALL_FLAG=""

# TLS Certificate Configuration
USE_CUSTOM_TLS="false"
TLS_SECRET_NAME=""
TLS_CERT_PATH=""
TLS_KEY_PATH=""
TLS_CA_CERT_PATH=""
TLS_GENERATE_FROM_CA="false"
TLS_CA_SECRET_NAME="icp4a-root-ca"
TLS_SERVER_CN=""
USE_CUSTOM_TLS_ARG="false"
CUSTOM_CA_SECRET_ARG=""
ADDITIONAL_CA_SECRETS_ARG=""

function show_help() {
    printf "\n"
    title "IBM Model Gateway Operator Deployment Script"
    printf "\n"
    printf "Usage:\n"
    printf "\n"
    printf " %s [OPTIONS]\n" "${CUR_DIR}/cp4a-model-gateway-deployment.sh"
    printf "\n"
    printf "Options:\n"
    printf "\n"
    printf "  -h, --help                    Display this help message\n"
    printf "\n"
    printf "  -o, --operator-namespace      Namespace for Model Gateway operator (optional, defaults to instance namespace)\n"
    printf "\n"
    printf "  -n, --instance-namespace      Namespace for Model Gateway instance (REQUIRED)\n"
    printf "\n"
    printf "  -s, --scale-config            Scale configuration: small|medium|large|small_mincpureq (default: medium)\n"
    printf "\n"
    printf "  -b, --block-storage-class     Block storage class for Redis\n"
    printf "\n"
    printf "  -f, --file-storage-class      File storage class\n"
    printf "\n"
    printf "  -v, --storage-vendor          Storage vendor: ocs|portworx (optional)\n"
    printf "\n"
    printf "  -p, --pull-secret             Image pull secret name (default: ibm-entitlement-key)\n"
    printf "\n"
    printf "  -r, --registry                Image registry (default: cp.icr.io)\n"
    printf "\n"
    printf "  -l, --license                 License type: Enterprise|Standard (default: Enterprise)\n"
    printf "\n"
    printf "  --accept-license              Accept license agreement (required for deployment)\n"
    printf "\n"
    printf "  --lite-install                Use SQLite instead of PostgreSQL (dev/test only)\n"
    printf "\n"
    printf "  --internal-postgres           Use the internal IBM CNPG PostgreSQL operator\n"
    printf "                                Mutually exclusive with --lite-install\n"
    printf "\n"
    printf "  --redis-channel               Redis operator channel (default: v1.3)\n"
    printf "\n"
    printf "  --verify-only                 Only verify prerequisites without deploying\n"
    printf "\n"
    printf "  --use-custom-tls              Use custom TLS certificate (auto-generates from CP4BA root CA)\n"
    printf "  --custom-ca-secret <name>     Custom root CA secret name (default: icp4a-root-ca)\n"
    printf "                                Only used with --use-custom-tls flag\n"
    printf "  --additional-ca-secrets <s1,s2,...>\n"
    printf "                                Comma-separated list of additional CA secret names to trust\n"
    printf "                                Only used with --use-custom-tls flag\n"
    printf "\n"
    printf "  --configure-providers         Configure AI provider credentials (OpenAI, Anthropic, etc.)\n"
    printf "\n"
    printf "  --uninstall                   Uninstall Model Gateway operator and instance\n"
    printf "\n"
    printf "Prerequisites:\n"
    printf "\n"
    tips "PostgreSQL:"
    printf "    By default this script deploys with an external PostgreSQL database.\n"
    printf "    Use --internal-postgres to deploy the internal IBM CNPG PostgreSQL operator instead.\n"
    printf "\n"
    tips "External PostgreSQL (default):"
    printf "    Create secret 'model-gateway-postgres-external-secret' in the instance namespace with:\n"
    printf "      - host: PostgreSQL hostname\n"
    printf "      - port: PostgreSQL port\n"
    printf "      - username: Database username\n"
    printf "      - password: Database password\n"
    printf "      - dbname: Database name\n"
    printf "      - parameters: Connection parameters (e.g., 'sslmode=require')\n"
    printf "\n"
    printf "Examples:\n"
    printf "\n"
    tips "# Deploy with external PostgreSQL (requires secret created first)"
    printf "  ./cp4a-model-gateway-deployment.sh --accept-license -b ocs-storagecluster-ceph-rbd -f ocs-storagecluster-cephfs\n"
    printf "\n"
    tips "# Deploy with internal IBM CNPG PostgreSQL"
    printf "  ./cp4a-model-gateway-deployment.sh --accept-license --internal-postgres -b ocs-storagecluster-ceph-rbd -f ocs-storagecluster-cephfs\n"
    printf "\n"
    tips "# Deploy with custom namespaces and large scale"
    printf "  ./cp4a-model-gateway-deployment.sh --accept-license -o my-operators -n my-instance -s large -b portworx-db -f portworx-shared\n"
    printf "\n"
    tips "# Verify prerequisites only"
    printf "  ./cp4a-model-gateway-deployment.sh --verify-only\n"
    printf "\n"
    tips "# Deploy with custom TLS certificate (auto-generated from CP4BA root CA)"
    printf "  ./cp4a-model-gateway-deployment.sh --accept-license --use-custom-tls -b ocs-storagecluster-ceph-rbd -f ocs-storagecluster-cephfs\n"
    printf "\n"
    tips "# Deploy with custom TLS certificate using custom root CA secret"
    printf "  ./cp4a-model-gateway-deployment.sh --accept-license --use-custom-tls --custom-ca-secret my-custom-ca -b ocs-storagecluster-ceph-rbd -f ocs-storagecluster-cephfs\n"
    printf "\n"
    tips "# Deploy with custom TLS and additional CA secrets"
    printf "  ./cp4a-model-gateway-deployment.sh --accept-license --use-custom-tls --additional-ca-secrets external-ca-1,external-ca-2 -b ocs-storagecluster-ceph-rbd -f ocs-storagecluster-cephfs\n"
    printf "\n"
    tips "# Uninstall Model Gateway"
    printf "  ./cp4a-model-gateway-deployment.sh --uninstall -o cp4ba-operators -n cp4ba-instance\n"
    printf "\n"
}

function check_command() {
    if ! command -v $1 &> /dev/null; then
        error "$1 command not found. Please install $1."
        return 1
    fi
    return 0
}

function read_property_file() {
    local file=$1
    local key=$2
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    local value=$(grep "^${key}=" "$file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [ -n "$value" ]; then
        echo "$value"
        return 0
    fi
    return 1
}

function prompt_yes_no() {
    local prompt=$1
    local default=${2:-"n"}
    
    while true; do
        if [ "$default" = "y" ]; then
            printf "%s [Y/n]: " "$prompt"
        else
            printf "%s [y/N]: " "$prompt"
        fi
        
        read -r response
        response=${response:-$default}
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                warning "Please answer yes or no."
                ;;
        esac
    done
}

function prompt_input() {
    local prompt=$1
    local default=$2
    local value
    
    if [ -n "$default" ]; then
        printf "%s [%s]: " "$prompt" "$default" >&2
    else
        printf "%s: " "$prompt" >&2
    fi
    
    read -r value
    value=${value:-$default}
    echo "$value"
}

function interactive_mode() {
    printf "\n"
    title "IBM Model Gateway Operator - Interactive Deployment"
    printf "\n"
    
    # INSTANCE_NAMESPACE is already set from -n flag
    info "Using instance namespace: $INSTANCE_NAMESPACE"
    printf "\n"
    
    # Step 1: Read CP4BA common config to determine separation of duties
    info "Reading CP4BA configuration..."
    local config_map_name="ibm-cp4ba-common-config"
    local operators_ns=""
    local services_ns=""
    
    if ${CLI_CMD} get configmap "$config_map_name" -n "$INSTANCE_NAMESPACE" &> /dev/null; then
        operators_ns=$(${CLI_CMD} get configmap "$config_map_name" -n "$INSTANCE_NAMESPACE" \
            -o jsonpath='{.data.operators_namespace}' 2>/dev/null)
        services_ns=$(${CLI_CMD} get configmap "$config_map_name" -n "$INSTANCE_NAMESPACE" \
            -o jsonpath='{.data.services_namespace}' 2>/dev/null)
        
        if [ -n "$operators_ns" ] && [ -n "$services_ns" ]; then
            success "Found CP4BA configuration"
            info "  Operators namespace: $operators_ns"
            info "  Services namespace: $services_ns"
            
            if [ "$operators_ns" != "$services_ns" ]; then
                info "Detected separation of duties deployment"
                OPERATOR_NAMESPACE="$operators_ns"
                # INSTANCE_NAMESPACE already set from -n flag
            else
                info "Detected single namespace deployment"
                OPERATOR_NAMESPACE="$INSTANCE_NAMESPACE"
            fi
        else
            warning "ConfigMap found but missing namespace data"
            OPERATOR_NAMESPACE="$INSTANCE_NAMESPACE"
        fi
    else
        warning "ConfigMap '$config_map_name' not found in namespace '$INSTANCE_NAMESPACE'"
        info "Assuming single namespace deployment"
        OPERATOR_NAMESPACE="$INSTANCE_NAMESPACE"
    fi
    
    success "Using operator namespace: $OPERATOR_NAMESPACE"
    success "Using instance namespace: $INSTANCE_NAMESPACE"
    printf "\n"
    
    # Step 2: Accept license
    printf "\n"
    info "IBM Model Gateway does not currently support Power (ppc64le) architecture"
    printf "\n"
    if prompt_yes_no "Do you accept the IBM Model Gateway license agreement?" "n"; then
        LICENSE_ACCEPT="true"
        success "License accepted"
    else
        error "License must be accepted to proceed with deployment"
        exit 1
    fi
    printf "\n"
    
    # Step 3: Storage configuration
    # info "Step 3: Storage Configuration"
    printf "\n"
    
    local property_file="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cp4ba_user_profile.property"
    local storage_found=false
    
    if [ -f "$property_file" ]; then
        info "Found property file: $property_file"
        
        local file_storage=$(read_property_file "$property_file" "CP4BA.FAST_FILE_STORAGE_CLASSNAME")
        local block_storage=$(read_property_file "$property_file" "CP4BA.BLOCK_STORAGE_CLASS_NAME")
        
        if [ -n "$file_storage" ] && [ -n "$block_storage" ]; then
            STORAGE_CLASS_FILE="$file_storage"
            STORAGE_CLASS_BLOCK="$block_storage"
            storage_found=true
            
            success "Found file storage class: $STORAGE_CLASS_FILE"
            success "Found block storage class: $STORAGE_CLASS_BLOCK"
            
            if ! prompt_yes_no "Use these storage classes?" "y"; then
                storage_found=false
            fi
        fi
    fi
    
    if [ "$storage_found" = false ]; then
        STORAGE_CLASS_BLOCK=$(prompt_input "Enter the block storage class (for Redis)" "")
        STORAGE_CLASS_FILE=$(prompt_input "Enter the file storage class" "")
        
        if [ -z "$STORAGE_CLASS_BLOCK" ] || [ -z "$STORAGE_CLASS_FILE" ]; then
            error "Both block and file storage classes are required"
            exit 1
        fi
        
        success "Using block storage class: $STORAGE_CLASS_BLOCK"
        success "Using file storage class: $STORAGE_CLASS_FILE"
    fi
    printf "\n"
    
    # Step 4: Scale configuration
    # info "Step 4: Scale Configuration"
    printf "\n"
    
    local temp_property_file="${PARENT_DIR}/.tmp/.TEMPORARY.property"
    local scale_found=false
    
    if [ -f "$temp_property_file" ]; then
        info "Found temporary property file: $temp_property_file"
        
        local profile_size=$(read_property_file "$temp_property_file" "PROFILE_SIZE_FLAG")
        
        if [ -n "$profile_size" ]; then
            SCALE_CONFIG="$profile_size"
            scale_found=true
            
            success "Found profile size: $SCALE_CONFIG"
            
            if ! prompt_yes_no "Use this profile size?" "y"; then
                scale_found=false
            fi
        fi
    fi
    
    if [ "$scale_found" = false ]; then
        printf "Available scale configurations:\n"
        printf "  - small: Minimal resources\n"
        printf "  - medium: Balanced resources for production\n"
        printf "  - large: Maximum resources for high-load production\n"
        printf "\n"
        
        SCALE_CONFIG=$(prompt_input "Enter the scale configuration" "small")
        
        case "$SCALE_CONFIG" in
            small|medium|large)
                success "Using scale configuration: $SCALE_CONFIG"
                ;;
            *)
                error "Invalid scale configuration: $SCALE_CONFIG"
                error "Valid options: small, medium, large"
                exit 1
                ;;
        esac
    fi
    printf "\n"
    
    # Step 5: TLS Certificate Configuration (Required)
    printf "\n"
    info "TLS Certificate Configuration (Required)"
    printf "\n"
    info "Model Gateway requires custom TLS certificates for secure communication."
    printf "\n"
    
    if ! prompt_tls_configuration; then
        error "TLS configuration failed"
        exit 1
    fi
    
    if ! validate_tls_configuration; then
        error "TLS validation failed"
        exit 1
    fi
    printf "\n"
    success "Custom TLS certificates configured"
    printf "\n"
    
    # Prompt for additional CA secrets
    if ! prompt_additional_ca_secrets; then
        error "Additional CA secrets configuration failed"
        exit 1
    fi
    printf "\n"
    
    # Step 6: AI Provider Configuration (Optional)
    printf "\n"
    info "AI Provider Configuration (Optional)"
    printf "\n"
    info "Model Gateway can connect to external AI providers like OpenAI, Anthropic, AWS Bedrock, etc."
    info "You can configure provider credentials now or skip and configure later."
    printf "\n"
    
    if prompt_yes_no "Do you want to configure AI provider credentials now?" "n"; then
        printf "\n"
        configure_provider_credentials true
        printf "\n"
        success "Provider credentials configured"
    else
        info "Skipping provider configuration. You can configure later with:"
        info "  ./cp4a-model-gateway-deployment.sh --configure-providers"
    fi
    printf "\n"
    
    # Step 7: PostgreSQL Configuration
    if [ "$LITE_INSTALL" != "true" ]; then
        printf "\n"
        info "PostgreSQL Configuration"
        printf "\n"
        info "Model Gateway supports two PostgreSQL options:"
        info "  1. External PostgreSQL - connect to an existing PostgreSQL instance you manage"
        info "  2. Internal IBM CNPG   - deploy the IBM Cloud Native PostgreSQL operator"
        printf "\n"
        
        local pg_choice=""
        while [[ ! "$pg_choice" =~ ^[12]$ ]]; do
            read -p "$(echo -e "${COLOR_CYAN}Select PostgreSQL option (1 or 2): ${COLOR_RESET}")" pg_choice
        done
        
        if [ "$pg_choice" = "2" ]; then
            DEPLOY_INTERNAL_POSTGRES="true"
            success "Using internal IBM CNPG PostgreSQL operator"
        else
            DEPLOY_INTERNAL_POSTGRES="false"
            success "Using external PostgreSQL"
            
            local property_file="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cp4ba_model_gateway.property"
            
            if [ -f "$property_file" ]; then
                info "Existing PostgreSQL configuration found."
                info "You can review and update the configuration or press Enter to keep existing values."
            else
                info "Please provide PostgreSQL connection details."
            fi
            printf "\n"
            
            if ! prompt_postgres_configuration; then
                error "Failed to configure PostgreSQL"
                exit 1
            fi
        fi
        printf "\n"
    fi
    
    # Summary
    info "Deployment Summary:"
    printf "  License: Accepted\n"
    printf "  Operator Namespace: %s\n" "$OPERATOR_NAMESPACE"
    printf "  Instance Namespace: %s\n" "$INSTANCE_NAMESPACE"
    printf "  Block Storage Class: %s\n" "$STORAGE_CLASS_BLOCK"
    printf "  File Storage Class: %s\n" "$STORAGE_CLASS_FILE"
    printf "  Scale Configuration: %s\n" "$SCALE_CONFIG"
    if [ "$LITE_INSTALL" = "true" ]; then
        printf "  PostgreSQL: SQLite (lite install)\n"
    elif [ "$DEPLOY_INTERNAL_POSTGRES" = "true" ]; then
        printf "  PostgreSQL: Internal IBM CNPG\n"
    else
        printf "  PostgreSQL: External\n"
    fi
    printf "\n"
    
    if ! prompt_yes_no "Proceed with deployment?" "y"; then
        info "Deployment cancelled by user"
        exit 0
    fi
    
    printf "\n"
}

function check_cluster_connection() {
    info "Checking cluster connection..."
    
    if ! ${CLI_CMD} cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        return 1
    fi
    
    success "Connected to Kubernetes cluster"
    return 0
}

function check_namespace() {
    local namespace=$1
    
    if ${CLI_CMD} get namespace "$namespace" &> /dev/null; then
        return 0
    fi
    return 1
}

function create_namespace() {
    local namespace=$1
    
    info "Creating namespace: $namespace"
    
    if check_namespace "$namespace"; then
        info "Namespace $namespace already exists"
        return 0
    fi
    
    if ${CLI_CMD} create namespace "$namespace"; then
        success "Created namespace: $namespace"
        return 0
    else
        error "Failed to create namespace: $namespace"
        return 1
    fi
}

function check_image_pull_secret() {
    local namespace=$1
    local secret=$2
    
    if ${CLI_CMD} get secret "$secret" -n "$namespace" &> /dev/null; then
        return 0
    fi
    return 1
}

function check_storage_class() {
    local storage_class=$1
    
    if [ -z "$storage_class" ]; then
        return 0
    fi
    
    if ${CLI_CMD} get storageclass "$storage_class" &> /dev/null; then
        return 0
    fi
    
    error "Storage class not found: $storage_class"
    return 1
}

function set_helm_list_all_flag() {
    # Detect Helm major version and set global flag
    local helm_major_version=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+' | head -1 | tr -d 'v')
    
    # Set --all flag for Helm v3, empty for v4+
    if [ -n "$helm_major_version" ] && [ "$helm_major_version" -lt 4 ]; then
        HELM_LIST_ALL_FLAG="--all"
    else
        HELM_LIST_ALL_FLAG=""
    fi
}

function install_redis_operator() {
    info "Installing IBM Redis operator..."
    
    # Create OperatorGroup if it doesn't exist
    if ! ${CLI_CMD} get operatorgroup -n "$OPERATOR_NAMESPACE" &> /dev/null; then
        info "Creating OperatorGroup in namespace: $OPERATOR_NAMESPACE"
        cat <<EOF | ${CLI_CMD} apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${OPERATOR_NAMESPACE}-operatorgroup
  namespace: ${OPERATOR_NAMESPACE}
spec:
  targetNamespaces:
  - ${OPERATOR_NAMESPACE}
EOF
    fi
    
    # Create Redis operator subscription
    info "Creating IBM Redis operator subscription..."
    cat <<EOF | ${CLI_CMD} apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-redis-cp-operator-catalog-subscription
  namespace: ${OPERATOR_NAMESPACE}
spec:
  channel: ${REDIS_OPERATOR_CHANNEL}
  installPlanApproval: ${REDIS_OPERATOR_INSTALL_PLAN}
  name: ${REDIS_OPERATOR_PACKAGE}
  source: ${REDIS_OPERATOR_SOURCE}
  sourceNamespace: ${OPERATOR_NAMESPACE}
EOF
    
    if [ $? -eq 0 ]; then
        success "IBM Redis operator subscription created"
        
        # Wait for operator to be ready
        info "Waiting for IBM Redis operator to be ready..."
        local max_wait=600
        local elapsed=0
        
        while [ $elapsed -lt $max_wait ]; do
            if ${CLI_CMD} get deployment ibm-redis-cp-operator -n "$OPERATOR_NAMESPACE" &> /dev/null; then
                if ${CLI_CMD} wait --for=condition=available --timeout=60s \
                    deployment ibm-redis-cp-operator -n "$OPERATOR_NAMESPACE" &> /dev/null; then
                    success "IBM Redis operator is ready"
                    return 0
                fi
            fi
            sleep 10
            elapsed=$((elapsed + 10))
            wait_msg "Waiting for Redis operator... ($elapsed/$max_wait seconds)"
        done
        
        error "Timeout waiting for IBM Redis operator"
        return 1
    else
        error "Failed to create IBM Redis operator subscription"
        return 1
    fi
}

function check_zenservice() {
    info "Checking ZenService status..."
    
    # Check if ZenService exists and get its YAML
    local zenservice_yaml=$(${CLI_CMD} get zenservice iaf-zen-cpdservice -n "$INSTANCE_NAMESPACE" -o yaml 2>/dev/null)
    
    if [ -z "$zenservice_yaml" ]; then
        error "ZenService 'iaf-zen-cpdservice' not found in namespace: $INSTANCE_NAMESPACE"
        error "Model Gateway requires ZenService to be installed and ready"
        return 1
    fi
    
    # Extract status fields using YQ_CMD
    local progress=$(echo "$zenservice_yaml" | ${YQ_CMD} '.status.progress' -)
    local zen_status=$(echo "$zenservice_yaml" | ${YQ_CMD} '.status.zenStatus' -)
    local current_version=$(echo "$zenservice_yaml" | ${YQ_CMD} '.status.currentVersion' -)
    
    # Check progress
    if [ "$progress" != "100%" ]; then
        error "ZenService is not fully deployed. Current progress: ${progress:-Unknown}"
        error "Please wait for ZenService to complete deployment (100%)"
        return 1
    fi
    success "ZenService progress: $progress"
    
    # Check status
    if [ "$zen_status" != "Completed" ]; then
        error "ZenService status is not 'Completed'. Current status: ${zen_status:-Unknown}"
        error "Please wait for ZenService to reach 'Completed' status"
        return 1
    fi
    success "ZenService status: $zen_status"
    
    # Check version (should be 6.x.x)
    if [[ ! "$current_version" =~ ^6\.[0-9]+\.[0-9]+$ ]]; then
        error "ZenService version is not compatible. Current version: ${current_version:-Unknown}"
        error "Model Gateway requires ZenService version 6.x.x"
        return 1
    fi
    success "ZenService version: $current_version"
    
    success "ZenService is ready for Model Gateway deployment"
    return 0
}

function prompt_postgres_configuration() {
    local property_dir="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile"
    local cert_dir="${property_dir}/cert/db/postgresql"
    local property_file="${property_dir}/cp4ba_model_gateway.property"
    
    echo
    title "PostgreSQL Configuration"
    echo
    info "Model Gateway requires an external PostgreSQL database."
    info "Please provide the connection details for your PostgreSQL instance."
    echo
    
    # Load existing values from property file if it exists
    local pg_host=""
    local pg_port="5432"
    local pg_username=""
    local pg_password=""
    local pg_dbname="modelgateway"
    local pg_ssl_mode="require"
    local pg_use_client_cert="false"
    local pg_ca_cert_path=""
    local pg_client_cert_path=""
    local pg_client_key_path=""
    
    if [ -f "$property_file" ]; then
        info "Loading existing configuration from property file..."
        pg_host=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_HOST" || echo "")
        pg_port=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_PORT" || echo "5432")
        pg_username=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_USERNAME" || echo "")
        pg_password=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_PASSWORD" || echo "")
        pg_dbname=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_DBNAME" || echo "modelgateway")
        pg_ssl_mode=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_SSL_MODE" || echo "require")
        pg_use_client_cert=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_USE_CLIENT_CERT" || echo "false")
        pg_ca_cert_path=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_CA_CERT_PATH" || echo "")
        pg_client_cert_path=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_CLIENT_CERT_PATH" || echo "")
        pg_client_key_path=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_CLIENT_KEY_PATH" || echo "")
        echo
    fi
    
    # PostgreSQL Host
    local input_host=""
    while [ -z "$input_host" ]; do
        if [ -n "$pg_host" ]; then
            read -p "$(echo -e "${COLOR_CYAN}Enter PostgreSQL hostname or IP address [$pg_host]: ${COLOR_RESET}")" input_host
            input_host=${input_host:-$pg_host}
        else
            read -p "$(echo -e "${COLOR_CYAN}Enter PostgreSQL hostname or IP address: ${COLOR_RESET}")" input_host
        fi
        if [ -z "$input_host" ]; then
            warning "PostgreSQL hostname is required"
        fi
    done
    pg_host="$input_host"
    
    # PostgreSQL Port
    read -p "$(echo -e "${COLOR_CYAN}Enter PostgreSQL port [$pg_port]: ${COLOR_RESET}")" input_port
    pg_port=${input_port:-$pg_port}
    
    # PostgreSQL Username
    local input_username=""
    while [ -z "$input_username" ]; do
        if [ -n "$pg_username" ]; then
            read -p "$(echo -e "${COLOR_CYAN}Enter PostgreSQL username [$pg_username]: ${COLOR_RESET}")" input_username
            input_username=${input_username:-$pg_username}
        else
            read -p "$(echo -e "${COLOR_CYAN}Enter PostgreSQL username: ${COLOR_RESET}")" input_username
        fi
        if [ -z "$input_username" ]; then
            warning "PostgreSQL username is required"
        fi
    done
    pg_username="$input_username"
    
    # PostgreSQL Database Name
    read -p "$(echo -e "${COLOR_CYAN}Enter PostgreSQL database name [$pg_dbname]: ${COLOR_RESET}")" input_dbname
    pg_dbname=${input_dbname:-$pg_dbname}
    
    # PostgreSQL SSL Mode
    echo
    info "PostgreSQL SSL Mode options:"
    info "  1) disable      - No SSL"
    info "  2) require      - SSL required but no certificate verification"
    info "  3) verify-ca    - SSL required with CA certificate verification"
    info "  4) verify-full  - SSL required with full certificate verification"
    
    local ssl_default="2"
    case "$pg_ssl_mode" in
        disable) ssl_default="1" ;;
        require) ssl_default="2" ;;
        verify-ca) ssl_default="3" ;;
        verify-full) ssl_default="4" ;;
    esac
    
    read -p "$(echo -e "${COLOR_CYAN}Select SSL mode [$ssl_default]: ${COLOR_RESET}")" ssl_choice
    ssl_choice=${ssl_choice:-$ssl_default}
    
    case "$ssl_choice" in
        1) pg_ssl_mode="disable" ;;
        2) pg_ssl_mode="require" ;;
        3) pg_ssl_mode="verify-ca" ;;
        4) pg_ssl_mode="verify-full" ;;
        *) pg_ssl_mode="require" ;;
    esac
    
    # Handle CA certificate for verify-ca and verify-full
    if [[ "$pg_ssl_mode" == "verify-ca" || "$pg_ssl_mode" == "verify-full" ]]; then
        echo
        info "SSL mode '$pg_ssl_mode' requires a CA certificate."
        read -p "$(echo -e "${COLOR_CYAN}Enter path to CA certificate [${cert_dir}/ca.crt]: ${COLOR_RESET}")" pg_ca_cert_path
        
        if [ -z "$pg_ca_cert_path" ]; then
            pg_ca_cert_path="${cert_dir}/ca.crt"
            info "Using default CA certificate location: $pg_ca_cert_path"
            info "Please place your CA certificate at this location before deployment."
        elif [ ! -f "$pg_ca_cert_path" ]; then
            warning "CA certificate not found at: $pg_ca_cert_path"
            warning "Please ensure the certificate exists before deployment."
        fi
    fi
    
    # Client Certificate Authentication
    echo
    read -p "$(echo -e "${COLOR_CYAN}Does your PostgreSQL require client certificate authentication? (y/N): ${COLOR_RESET}")" use_client_cert
    if [[ "$use_client_cert" =~ ^[Yy]$ ]]; then
        pg_use_client_cert="true"
        
        read -p "$(echo -e "${COLOR_CYAN}Enter path to client certificate [${cert_dir}/client.crt]: ${COLOR_RESET}")" pg_client_cert_path
        if [ -z "$pg_client_cert_path" ]; then
            pg_client_cert_path="${cert_dir}/client.crt"
            info "Using default client certificate location: $pg_client_cert_path"
        fi
        
        read -p "$(echo -e "${COLOR_CYAN}Enter path to client private key [${cert_dir}/client.key]: ${COLOR_RESET}")" pg_client_key_path
        if [ -z "$pg_client_key_path" ]; then
            pg_client_key_path="${cert_dir}/client.key"
            info "Using default client key location: $pg_client_key_path"
        fi
        
        if [ ! -f "$pg_client_cert_path" ] || [ ! -f "$pg_client_key_path" ]; then
            warning "Client certificate or key not found. Please ensure they exist before deployment."
        fi
    fi
    
    # PostgreSQL Password
    # Password is required for plain and password-over-TLS auth.
    # When client certificate authentication is used, the server may authenticate via the
    # certificate alone (pg_hba.conf: cert), so the password becomes optional.
    echo
    local input_password=""
    if [ "$pg_use_client_cert" = "true" ]; then
        info "Client certificate authentication is enabled."
        info "Password is optional when the server authenticates via client certificate (pg_hba.conf: cert)."
        if [ -n "$pg_password" ]; then
            read -s -p "$(echo -e "${COLOR_CYAN}Enter PostgreSQL password (press Enter to skip) [****]: ${COLOR_RESET}")" input_password
        else
            read -s -p "$(echo -e "${COLOR_CYAN}Enter PostgreSQL password (press Enter to skip): ${COLOR_RESET}")" input_password
        fi
        echo
        pg_password=${input_password:-$pg_password}
    else
        while [ -z "$input_password" ]; do
            if [ -n "$pg_password" ]; then
                read -s -p "$(echo -e "${COLOR_CYAN}Enter PostgreSQL password [****]: ${COLOR_RESET}")" input_password
                input_password=${input_password:-$pg_password}
            else
                read -s -p "$(echo -e "${COLOR_CYAN}Enter PostgreSQL password: ${COLOR_RESET}")" input_password
            fi
            echo
            if [ -z "$input_password" ]; then
                warning "PostgreSQL password is required"
            fi
        done
        pg_password="$input_password"
    fi
    
    # Create directories
    if [ ! -d "$property_dir" ]; then
        mkdir -p "$property_dir"
    fi
    
    if [ ! -d "$cert_dir" ]; then
        mkdir -p "$cert_dir"
    fi
    
    # Create property file with collected values
    info "Creating property file: $property_file"
    cat > "$property_file" << EOF
###############################################################################
# IBM Model Gateway - External PostgreSQL Configuration
###############################################################################
# This file contains the configuration for connecting to an external PostgreSQL database.
# Generated by cp4a-model-gateway-deployment.sh
#
# IMPORTANT: Keep this file secure as it contains sensitive database credentials.
###############################################################################

# PostgreSQL hostname or IP address
MODEL_GATEWAY_POSTGRES_HOST="${pg_host}"

# PostgreSQL port
MODEL_GATEWAY_POSTGRES_PORT="${pg_port}"

# PostgreSQL database username
MODEL_GATEWAY_POSTGRES_USERNAME="${pg_username}"

# PostgreSQL database password
MODEL_GATEWAY_POSTGRES_PASSWORD="${pg_password}"

# PostgreSQL database name
MODEL_GATEWAY_POSTGRES_DBNAME="${pg_dbname}"

# PostgreSQL SSL Mode
MODEL_GATEWAY_POSTGRES_SSL_MODE="${pg_ssl_mode}"

# PostgreSQL CA Certificate Path
MODEL_GATEWAY_POSTGRES_CA_CERT_PATH="${pg_ca_cert_path}"

# PostgreSQL Client Certificate Authentication
MODEL_GATEWAY_POSTGRES_USE_CLIENT_CERT="${pg_use_client_cert}"

# PostgreSQL Client Certificate Path
MODEL_GATEWAY_POSTGRES_CLIENT_CERT_PATH="${pg_client_cert_path}"

# PostgreSQL Client Private Key Path
MODEL_GATEWAY_POSTGRES_CLIENT_KEY_PATH="${pg_client_key_path}"

###############################################################################
# Certificate File Locations:
#   CA Certificate:     ${cert_dir}/ca.crt
#   Client Certificate: ${cert_dir}/client.crt
#   Client Private Key: ${cert_dir}/client.key
###############################################################################
# End of configuration
###############################################################################
EOF
    
    success "Property file created: $property_file"
    
    # Display summary
    echo
    info "PostgreSQL Configuration Summary:"
    info "  Host:     $pg_host"
    info "  Port:     $pg_port"
    info "  Database: $pg_dbname"
    info "  Username: $pg_username"
    info "  SSL Mode: $pg_ssl_mode"
    
    if [[ "$pg_ssl_mode" == "verify-ca" || "$pg_ssl_mode" == "verify-full" ]]; then
        info "  CA Cert:  $pg_ca_cert_path"
    fi
    
    if [[ "$pg_use_client_cert" == "true" ]]; then
        info "  Client Cert: $pg_client_cert_path"
        info "  Client Key:  $pg_client_key_path"
    fi
    
    return 0
}

function create_postgres_property_file() {
    local property_dir="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile"
    local property_file="${property_dir}/cp4ba_model_gateway.property"
    local cert_dir="${property_dir}/cert/db/postgresql"
    
    # Check if property file already exists
    if [ -f "$property_file" ]; then
        return 0
    fi
    
    # Property file doesn't exist - prompt for configuration
    if ! prompt_postgres_configuration; then
        error "Failed to create PostgreSQL property file"
        return 1
    fi
    
    return 0
}

function create_postgres_secret_from_property() {
    local namespace=$1
    local property_file="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cp4ba_model_gateway.property"
    local cert_dir="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cert/db/postgresql"
    local default_ca_cert_path="${cert_dir}/ca.crt"
    local default_client_cert_path="${cert_dir}/client.crt"
    local default_client_key_path="${cert_dir}/client.key"
    local secret_dir="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/secret_template/modelgateway"
    local secret_file="${secret_dir}/model-gateway-postgres-external-secret.yaml"
    
    if [ ! -f "$property_file" ]; then
        return 1
    fi
    
    info "Reading PostgreSQL configuration from property file..."
    
    # Read values from property file
    local pg_host=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_HOST")
    local pg_port=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_PORT")
    local pg_username=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_USERNAME")
    local pg_password=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_PASSWORD")
    local pg_dbname=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_DBNAME")
    local pg_ssl_mode=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_SSL_MODE")
    local pg_ca_cert_path=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_CA_CERT_PATH")
    local pg_use_client_cert=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_USE_CLIENT_CERT")
    local pg_client_cert_path=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_CLIENT_CERT_PATH")
    local pg_client_key_path=$(read_property_file "$property_file" "MODEL_GATEWAY_POSTGRES_CLIENT_KEY_PATH")
    
    # Set defaults
    pg_ssl_mode=${pg_ssl_mode:-"require"}
    pg_use_client_cert=${pg_use_client_cert:-"false"}
    
    # Validate all required fields are present
    local missing_fields=()
    [ -z "$pg_host" ] && missing_fields+=("MODEL_GATEWAY_POSTGRES_HOST")
    [ -z "$pg_port" ] && missing_fields+=("MODEL_GATEWAY_POSTGRES_PORT")
    [ -z "$pg_username" ] && missing_fields+=("MODEL_GATEWAY_POSTGRES_USERNAME")
    [ -z "$pg_password" ] && missing_fields+=("MODEL_GATEWAY_POSTGRES_PASSWORD")
    [ -z "$pg_dbname" ] && missing_fields+=("MODEL_GATEWAY_POSTGRES_DBNAME")
    
    if [ ${#missing_fields[@]} -gt 0 ]; then
        error "Missing required fields in property file: ${missing_fields[*]}"
        error "Please edit the property file and fill in all required values: $property_file"
        return 1
    fi
    
    # Build parameters based on SSL mode
    local pg_parameters="sslmode=${pg_ssl_mode}"
    local ca_cert_file=""
    local ca_cert_data=""
    local client_cert_file=""
    local client_cert_data=""
    local client_key_file=""
    local client_key_data=""
    
    # Handle CA certificate for verify-ca and verify-full modes
    if [[ "$pg_ssl_mode" == "verify-ca" || "$pg_ssl_mode" == "verify-full" ]]; then
        # Use provided cert path or default
        if [ -n "$pg_ca_cert_path" ]; then
            ca_cert_file="$pg_ca_cert_path"
        else
            ca_cert_file="$default_ca_cert_path"
        fi
        
        # Check if certificate file exists
        if [ ! -f "$ca_cert_file" ]; then
            error "SSL mode is '$pg_ssl_mode' but CA certificate not found at: $ca_cert_file"
            error "Please place your PostgreSQL CA certificate at this location"
            return 1
        fi
        
        # Add certificate path to parameters
        pg_parameters="${pg_parameters}&sslrootcert=/postgres-secrets/ca.crt"
        
        # Read and base64 encode certificate
        ca_cert_data=$(cat "$ca_cert_file" | base64 | tr -d '\n')
        info "Using CA certificate: $ca_cert_file"
    fi
    
    # Handle client certificate authentication (mutual TLS)
    if [[ "$pg_use_client_cert" == "true" ]]; then
        # Use provided paths or defaults
        if [ -n "$pg_client_cert_path" ]; then
            client_cert_file="$pg_client_cert_path"
        else
            client_cert_file="$default_client_cert_path"
        fi
        
        if [ -n "$pg_client_key_path" ]; then
            client_key_file="$pg_client_key_path"
        else
            client_key_file="$default_client_key_path"
        fi
        
        # Check if client certificate files exist
        if [ ! -f "$client_cert_file" ]; then
            error "Client certificate authentication enabled but certificate not found at: $client_cert_file"
            error "Please place your PostgreSQL client certificate at this location"
            return 1
        fi
        
        if [ ! -f "$client_key_file" ]; then
            error "Client certificate authentication enabled but private key not found at: $client_key_file"
            error "Please place your PostgreSQL client private key at this location"
            return 1
        fi
        
        # Add client certificate paths to parameters
        pg_parameters="${pg_parameters}&sslcert=/postgres-secrets/client.crt&sslkey=/postgres-secrets/client.key"
        
        # Read and base64 encode client certificate and key
        client_cert_data=$(cat "$client_cert_file" | base64 | tr -d '\n')
        client_key_data=$(cat "$client_key_file" | base64 | tr -d '\n')
        info "Using client certificate: $client_cert_file"
        info "Using client private key: $client_key_file"
    fi
    
    # Create secret directory if it doesn't exist
    if [ ! -d "$secret_dir" ]; then
        mkdir -p "$secret_dir"
    fi
    
    info "Generating external PostgreSQL secret YAML: $secret_file"
    
    # Base64 encode the secret values
    local host_b64=$(echo -n "$pg_host" | base64 | tr -d '\n')
    local port_b64=$(echo -n "$pg_port" | base64 | tr -d '\n')
    local username_b64=$(echo -n "$pg_username" | base64 | tr -d '\n')
    local password_b64=$(echo -n "$pg_password" | base64 | tr -d '\n')
    local dbname_b64=$(echo -n "$pg_dbname" | base64 | tr -d '\n')
    local parameters_b64=$(echo -n "$pg_parameters" | base64 | tr -d '\n')
    
    # Generate YAML file
    cat > "$secret_file" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: model-gateway-postgres-external-secret
  namespace: ${namespace}
  labels:
    app: model-gateway
    component: postgres
type: Opaque
data:
  host: ${host_b64}
  port: ${port_b64}
  username: ${username_b64}
  password: ${password_b64}
  dbname: ${dbname_b64}
  parameters: ${parameters_b64}
EOF
    
    # Add certificate data if present
    if [ -n "$ca_cert_data" ]; then
        echo "  ca.crt: ${ca_cert_data}" >> "$secret_file"
    fi
    
    # Add client certificate data if present
    if [ -n "$client_cert_data" ]; then
        echo "  client.crt: ${client_cert_data}" >> "$secret_file"
    fi
    
    # Add client key data if present
    if [ -n "$client_key_data" ]; then
        echo "  client.key: ${client_key_data}" >> "$secret_file"
    fi
    
    if [ $? -eq 0 ]; then
        success "External PostgreSQL secret YAML generated: $secret_file"
        info "  Host: $pg_host"
        info "  Port: $pg_port"
        info "  Database: $pg_dbname"
        info "  Username: $pg_username"
        info "  SSL Mode: $pg_ssl_mode"
        [ -n "$ca_cert_data" ] && info "  CA Certificate: included"
        [ -n "$client_cert_data" ] && info "  Client Certificate: included"
        [ -n "$client_key_data" ] && info "  Client Private Key: included"
        
        # Apply the secret
        info "Applying secret to namespace: $namespace"
        if ${CLI_CMD} apply -f "$secret_file"; then
            success "External PostgreSQL secret created successfully"
            return 0
        else
            error "Failed to apply secret YAML"
            return 1
        fi
    else
        error "Failed to generate external PostgreSQL secret YAML"
        return 1
    fi
}

function check_external_postgres_secret() {
    local namespace=$1
    
    info "Checking external PostgreSQL secret..."
    
    if ! ${CLI_CMD} get secret model-gateway-postgres-external-secret -n "$namespace" &> /dev/null; then
        info "External PostgreSQL secret 'model-gateway-postgres-external-secret' not found in namespace '$namespace', it will be created."
        
        # Try to create property file template
        if ! create_postgres_property_file; then
            local property_file="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cp4ba_model_gateway.property"
            error "Failed to create PostgreSQL property file."
            error "Please verify the property file exists and contains all required fields:"
            error "  File: $property_file"
            error "  Required fields:"
            error "    MODEL_GATEWAY_POSTGRES_HOST      - PostgreSQL hostname or IP address"
            error "    MODEL_GATEWAY_POSTGRES_PORT      - PostgreSQL port (e.g. 5432)"
            error "    MODEL_GATEWAY_POSTGRES_USERNAME  - Database username"
            error "    MODEL_GATEWAY_POSTGRES_PASSWORD  - Database password"
            error "    MODEL_GATEWAY_POSTGRES_DBNAME    - Database name"
            error "    MODEL_GATEWAY_POSTGRES_SSL_MODE  - SSL mode (disable|require|verify-ca|verify-full)"
            error "Once the file is populated correctly, re-run the deployment."
            return 1
        fi
        
        # Try to create secret from property file
        if create_postgres_secret_from_property "$namespace"; then
            success "External PostgreSQL secret created from property file"
            return 0
        else
            local property_file="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cp4ba_model_gateway.property"
            error "Failed to create external PostgreSQL secret from property file."
            error "Please verify the property file exists and contains all required fields:"
            error "  File: $property_file"
            error "  Required fields:"
            error "    MODEL_GATEWAY_POSTGRES_HOST      - PostgreSQL hostname or IP address"
            error "    MODEL_GATEWAY_POSTGRES_PORT      - PostgreSQL port (e.g. 5432)"
            error "    MODEL_GATEWAY_POSTGRES_USERNAME  - Database username"
            error "    MODEL_GATEWAY_POSTGRES_PASSWORD  - Database password"
            error "    MODEL_GATEWAY_POSTGRES_DBNAME    - Database name"
            error "    MODEL_GATEWAY_POSTGRES_SSL_MODE  - SSL mode (disable|require|verify-ca|verify-full)"
            error "Once the file is populated correctly, re-run the deployment."
            return 1
        fi
    fi
    
    # Validate required keys
    local required_keys=("host" "port" "username" "password" "dbname" "parameters")
    local missing_keys=()
    
    for key in "${required_keys[@]}"; do
        if ! ${CLI_CMD} get secret model-gateway-postgres-external-secret -n "$namespace" -o jsonpath="{.data.$key}" &> /dev/null; then
            missing_keys+=("$key")
        fi
    done
    
    if [ ${#missing_keys[@]} -gt 0 ]; then
        error "External PostgreSQL secret is missing required keys: ${missing_keys[*]}"
        return 1
    fi
    
    success "External PostgreSQL secret found with all required keys"
    return 0
}

function prompt_tls_configuration() {
    # If --use-custom-tls argument was provided, use defaults without prompting
    if [ "$USE_CUSTOM_TLS_ARG" = "true" ]; then
        echo
        title "Custom TLS Certificate Configuration"
        echo
        info "Using custom TLS certificate with default settings (--use-custom-tls flag detected)"
        USE_CUSTOM_TLS="true"
        TLS_GENERATE_FROM_CA="true"
        
        # Use custom CA secret if provided via --custom-ca-secret, otherwise use default
        if [ -n "$CUSTOM_CA_SECRET_ARG" ]; then
            TLS_CA_SECRET_NAME="$CUSTOM_CA_SECRET_ARG"
            info "Using custom root CA secret: $TLS_CA_SECRET_NAME"
        else
            TLS_CA_SECRET_NAME="icp4a-root-ca"
            info "Using default root CA secret: $TLS_CA_SECRET_NAME"
        fi
        
        # Check if Vault is enabled
        local property_file="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cp4ba_user_profile.property"
        local vault_enabled="false"
        local vault_root_ca_path="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cert/root_ca"
        
        if [ -f "$property_file" ]; then
            local vault_setting=$(read_property_file "$property_file" "CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION")
            if [ "$vault_setting" = "true" ]; then
                vault_enabled="true"
                info "External Vault integration is enabled"
            fi
        fi
        
        local cert_dir="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cert/model-gateway"
        mkdir -p "$cert_dir"
        
        local ca_cert="$cert_dir/ca.crt"
        local ca_key="$cert_dir/ca.key"
        
        # If Vault is enabled, try to find certificate in file system first
        if [ "$vault_enabled" = "true" ]; then
            info "Checking for root CA certificate in certificate directory..."
            
            # Look for certificate files in the root_ca directory
            local found_cert=""
            if [ -d "$vault_root_ca_path" ]; then
                # Look for common certificate file patterns
                for cert_file in "$vault_root_ca_path"/*.crt "$vault_root_ca_path"/*.pem "$vault_root_ca_path"/tls.crt; do
                    if [ -f "$cert_file" ]; then
                        found_cert="$cert_file"
                        break
                    fi
                done
            fi
            
            if [ -n "$found_cert" ]; then
                success "Found root CA certificate in directory: $found_cert"
                
                # Copy certificate to working directory
                cp "$found_cert" "$ca_cert"
                if [ $? -ne 0 ]; then
                    error "Failed to copy CA certificate from directory"
                    return 1
                fi
                
                # Look for corresponding key file
                local cert_basename=$(basename "$found_cert")
                local cert_name="${cert_basename%.*}"
                local found_key=""
                
                for key_file in "$vault_root_ca_path"/${cert_name}.key "$vault_root_ca_path"/tls.key "$vault_root_ca_path"/*.key; do
                    if [ -f "$key_file" ]; then
                        found_key="$key_file"
                        break
                    fi
                done
                
                if [ -z "$found_key" ]; then
                    error "Root CA private key not found in directory: $vault_root_ca_path"
                    error "Please ensure the private key file exists in the certificate directory"
                    return 1
                fi
                
                success "Found root CA private key in directory: $found_key"
                cp "$found_key" "$ca_key"
                if [ $? -ne 0 ]; then
                    error "Failed to copy CA private key from directory"
                    return 1
                fi
            else
                error "Root CA certificate not found in directory: $vault_root_ca_path"
                error "When using --use-custom-tls with Vault enabled, the root CA certificate must exist in the directory"
                return 1
            fi
        else
            # Vault not enabled - use Kubernetes secret
            # Validate CA secret exists
            if ! ${CLI_CMD} get secret "$TLS_CA_SECRET_NAME" -n "$INSTANCE_NAMESPACE" &> /dev/null; then
                error "CA secret '$TLS_CA_SECRET_NAME' not found in namespace: $INSTANCE_NAMESPACE"
                return 1
            fi
            
            # Check for required keys (tls.crt and tls.key)
            local has_cert=$(${CLI_CMD} get secret "$TLS_CA_SECRET_NAME" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
            local has_key=$(${CLI_CMD} get secret "$TLS_CA_SECRET_NAME" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.key}' 2>/dev/null)
            
            if [ -z "$has_cert" ] || [ -z "$has_key" ]; then
                error "CA secret '$TLS_CA_SECRET_NAME' does not contain required keys: tls.crt and tls.key"
                return 1
            fi
            
            # Extract CA certificate and key to temporary files
            # Extract and decode certificate
            ${CLI_CMD} get secret "$TLS_CA_SECRET_NAME" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$ca_cert"
            if [ $? -ne 0 ]; then
                error "Failed to extract CA certificate from secret"
                return 1
            fi
            
            # Extract and decode private key
            ${CLI_CMD} get secret "$TLS_CA_SECRET_NAME" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.key}' | base64 -d > "$ca_key"
            if [ $? -ne 0 ]; then
                error "Failed to extract CA private key from secret"
                rm -f "$ca_cert"
                return 1
            fi
        fi
        
        TLS_CA_CERT_PATH="$ca_cert"
        TLS_CA_KEY_PATH="$ca_key"
        TLS_SERVER_CN="model-gateway-service.${INSTANCE_NAMESPACE}.svc"
        TLS_SECRET_NAME="model-gateway-custom-tls"
        
        info "  CA Secret: $TLS_CA_SECRET_NAME"
        info "  Server CN: $TLS_SERVER_CN"
        info "  TLS Secret: $TLS_SECRET_NAME"
        echo
        return 0
    fi
    
    # When called from interactive setup, USE_CUSTOM_TLS is already set
    # This function just handles the option selection
    USE_CUSTOM_TLS="true"
    echo
    info "You have two options for providing a custom TLS certificate:"
    info "  1. Provide an existing Kubernetes secret containing tls.crt and tls.key"
    info "  2. Generate a server certificate from your CP4BA root CA"
    echo
    
    local tls_option=""
    while [[ ! "$tls_option" =~ ^[12]$ ]]; do
        read -p "$(echo -e "${COLOR_CYAN}Select option (1 or 2): ${COLOR_RESET}")" tls_option
    done
    
    if [ "$tls_option" = "1" ]; then
        # Option 1: Use existing secret
        prompt_existing_tls_secret
    else
        # Option 2: Generate from CA
        prompt_generate_from_ca
    fi
}

function prompt_existing_tls_secret() {
    echo
    info "Provide the name of an existing Kubernetes secret in namespace: $INSTANCE_NAMESPACE"
    info "The secret must contain:"
    info "  - tls.crt: Server certificate"
    info "  - tls.key: Private key"
    echo
    
    local secret_name=""
    while [ -z "$secret_name" ]; do
        read -p "$(echo -e "${COLOR_CYAN}Enter secret name: ${COLOR_RESET}")" secret_name
        
        if [ -z "$secret_name" ]; then
            warning "Secret name cannot be empty"
            continue
        fi
        
        # Validate secret exists and has required keys
        if ! ${CLI_CMD} get secret "$secret_name" -n "$INSTANCE_NAMESPACE" &> /dev/null; then
            warning "Secret '$secret_name' not found in namespace: $INSTANCE_NAMESPACE"
            read -p "$(echo -e "${COLOR_CYAN}Do you want to enter a different name? (y/n) [y]: ${COLOR_RESET}")" retry
            retry=${retry:-y}
            if [ "$retry" = "n" ]; then
                error "Secret validation failed"
                return 1
            fi
            secret_name=""
            continue
        fi
        
        # Check for required keys
        local has_cert=$(${CLI_CMD} get secret "$secret_name" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
        local has_key=$(${CLI_CMD} get secret "$secret_name" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.key}' 2>/dev/null)
        
        if [ -z "$has_cert" ] || [ -z "$has_key" ]; then
            warning "Secret '$secret_name' does not contain required keys: tls.crt and tls.key"
            read -p "$(echo -e "${COLOR_CYAN}Do you want to enter a different name? (y/n) [y]: ${COLOR_RESET}")" retry
            retry=${retry:-y}
            if [ "$retry" = "n" ]; then
                error "Secret validation failed"
                return 1
            fi
            secret_name=""
            continue
        fi
        
        success "Secret '$secret_name' validated successfully"
        TLS_SECRET_NAME="$secret_name"
        TLS_GENERATE_FROM_CA="false"
    done
}

function prompt_generate_from_ca() {
    echo
    info "Generate server certificate from CP4BA root CA"
    info "The CP4BA root CA secret contains the certificate authority used to sign certificates."
    info "Default secret name: icp4a-root-ca"
    echo
    
    # Check if Vault is enabled
    local property_file="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cp4ba_user_profile.property"
    local vault_enabled="false"
    local vault_root_ca_path="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cert/root_ca"
    
    if [ -f "$property_file" ]; then
        local vault_setting=$(read_property_file "$property_file" "CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION")
        if [ "$vault_setting" = "true" ]; then
            vault_enabled="true"
            info "External Vault integration is enabled"
        fi
    fi
    
    # Get CA secret name
    local ca_secret_name=""
    read -p "$(echo -e "${COLOR_CYAN}Enter CP4BA root CA secret name [icp4a-root-ca]: ${COLOR_RESET}")" ca_secret_name
    ca_secret_name=${ca_secret_name:-"icp4a-root-ca"}
    
    local cert_dir="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cert/model-gateway"
    mkdir -p "$cert_dir"
    
    local ca_cert="$cert_dir/ca.crt"
    local ca_key="$cert_dir/ca.key"
    
    # If Vault is enabled, try to find certificate in file system first
    if [ "$vault_enabled" = "true" ]; then
        info "Checking for root CA certificate in certificate directory..."
        
        # Look for certificate files in the root_ca directory
        local found_cert=""
        if [ -d "$vault_root_ca_path" ]; then
            # Look for common certificate file patterns
            for cert_file in "$vault_root_ca_path"/*.crt "$vault_root_ca_path"/*.pem "$vault_root_ca_path"/tls.crt; do
                if [ -f "$cert_file" ]; then
                    found_cert="$cert_file"
                    break
                fi
            done
        fi
        
        if [ -n "$found_cert" ]; then
            success "Found root CA certificate in directory: $found_cert"
            
            # Copy certificate to working directory
            cp "$found_cert" "$ca_cert"
            if [ $? -ne 0 ]; then
                error "Failed to copy CA certificate from directory"
                return 1
            fi
            
            # Look for corresponding key file
            local cert_basename=$(basename "$found_cert")
            local cert_name="${cert_basename%.*}"
            local found_key=""
            
            for key_file in "$vault_root_ca_path"/${cert_name}.key "$vault_root_ca_path"/tls.key "$vault_root_ca_path"/*.key; do
                if [ -f "$key_file" ]; then
                    found_key="$key_file"
                    break
                fi
            done
            
            if [ -n "$found_key" ]; then
                success "Found root CA private key in directory: $found_key"
                cp "$found_key" "$ca_key"
                if [ $? -ne 0 ]; then
                    error "Failed to copy CA private key from directory"
                    return 1
                fi
                info "CA certificate and key extracted from directory"
            else
                warning "Private key not found in directory"
                # Prompt for key location
                local key_path=""
                read -p "$(echo -e "${COLOR_CYAN}Enter path to root CA private key file: ${COLOR_RESET}")" key_path
                
                if [ ! -f "$key_path" ]; then
                    error "Private key file not found: $key_path"
                    return 1
                fi
                
                cp "$key_path" "$ca_key"
                if [ $? -ne 0 ]; then
                    error "Failed to copy CA private key"
                    return 1
                fi
                success "CA private key copied from: $key_path"
            fi
        else
            warning "Root CA certificate not found in directory: $vault_root_ca_path"
            
            # Prompt for certificate location
            local cert_path=""
            read -p "$(echo -e "${COLOR_CYAN}Enter path to root CA certificate file: ${COLOR_RESET}")" cert_path
            
            if [ ! -f "$cert_path" ]; then
                error "Certificate file not found: $cert_path"
                return 1
            fi
            
            cp "$cert_path" "$ca_cert"
            if [ $? -ne 0 ]; then
                error "Failed to copy CA certificate"
                return 1
            fi
            success "CA certificate copied from: $cert_path"
            
            # Prompt for key location
            local key_path=""
            read -p "$(echo -e "${COLOR_CYAN}Enter path to root CA private key file: ${COLOR_RESET}")" key_path
            
            if [ ! -f "$key_path" ]; then
                error "Private key file not found: $key_path"
                return 1
            fi
            
            cp "$key_path" "$ca_key"
            if [ $? -ne 0 ]; then
                error "Failed to copy CA private key"
                return 1
            fi
            success "CA private key copied from: $key_path"
        fi
    else
        # Vault not enabled - use Kubernetes secret
        # Validate secret exists
        if ! ${CLI_CMD} get secret "$ca_secret_name" -n "$INSTANCE_NAMESPACE" &> /dev/null; then
            error "Secret '$ca_secret_name' not found in namespace: $INSTANCE_NAMESPACE"
            return 1
        fi
        
        # Check for required keys (tls.crt and tls.key)
        local has_cert=$(${CLI_CMD} get secret "$ca_secret_name" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
        local has_key=$(${CLI_CMD} get secret "$ca_secret_name" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.key}' 2>/dev/null)
        
        if [ -z "$has_cert" ] || [ -z "$has_key" ]; then
            error "Secret '$ca_secret_name' does not contain required keys: tls.crt and tls.key"
            return 1
        fi
        
        success "CA secret '$ca_secret_name' validated successfully"
        
        # Extract and decode certificate
        ${CLI_CMD} get secret "$ca_secret_name" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$ca_cert"
        if [ $? -ne 0 ]; then
            error "Failed to extract CA certificate from secret"
            return 1
        fi
        
        # Extract and decode private key
        ${CLI_CMD} get secret "$ca_secret_name" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.key}' | base64 -d > "$ca_key"
        if [ $? -ne 0 ]; then
            error "Failed to extract CA private key from secret"
            rm -f "$ca_cert"
            return 1
        fi
        
        info "CA certificate and key extracted from secret"
    fi
    
    # Get server certificate details
    local server_cn=""
    read -p "$(echo -e "${COLOR_CYAN}Enter server Common Name (CN) [model-gateway-service.$INSTANCE_NAMESPACE.svc]: ${COLOR_RESET}")" server_cn
    server_cn=${server_cn:-"model-gateway-service.$INSTANCE_NAMESPACE.svc"}
    
    TLS_CA_CERT_PATH="$ca_cert"
    TLS_CA_KEY_PATH="$ca_key"
    TLS_SERVER_CN="$server_cn"
    TLS_SECRET_NAME="model-gateway-custom-tls"
    TLS_GENERATE_FROM_CA="true"
    
    success "CA certificate configuration saved"
}

function prompt_additional_ca_secrets() {
    # If --additional-ca-secrets argument was provided, process it without prompting
    if [ -n "$ADDITIONAL_CA_SECRETS_ARG" ]; then
        echo
        info "Processing additional CA secrets from command line argument"
        
        # Initialize array to store additional CA secrets
        ADDITIONAL_CA_SECRETS=()
        
        # Split comma-separated list into array
        IFS=',' read -ra secrets_array <<< "$ADDITIONAL_CA_SECRETS_ARG"
        
        for secret_name in "${secrets_array[@]}"; do
            # Trim whitespace
            secret_name=$(echo "$secret_name" | xargs)
            
            if [ -z "$secret_name" ]; then
                continue
            fi
            
            # Validate secret exists
            if ! ${CLI_CMD} get secret "$secret_name" -n "$INSTANCE_NAMESPACE" &> /dev/null; then
                error "Secret '$secret_name' not found in namespace: $INSTANCE_NAMESPACE"
                return 1
            fi
            
            # Check for tls.crt key
            local has_cert=$(${CLI_CMD} get secret "$secret_name" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
            
            if [ -z "$has_cert" ]; then
                error "Secret '$secret_name' does not contain 'tls.crt' key"
                return 1
            fi
            
            ADDITIONAL_CA_SECRETS+=("$secret_name")
            info "  Validated CA secret: $secret_name"
        done
        
        if [ ${#ADDITIONAL_CA_SECRETS[@]} -gt 0 ]; then
            success "Added ${#ADDITIONAL_CA_SECRETS[@]} additional CA secret(s)"
        fi
        echo
        return 0
    fi
    
    # Interactive mode
    echo
    info "Additional TLS CA Secrets (Optional)"
    echo
    info "You can specify additional Kubernetes secrets containing CA certificates"
    info "that should be trusted by Model Gateway. These secrets must exist in the"
    info "namespace: $INSTANCE_NAMESPACE"
    echo
    info "Each secret should contain a 'tls.crt' key with the CA certificate."
    echo
    
    read -p "$(echo -e "${COLOR_YELLOW}Do you want to add additional CA secrets? (y/n) [n]: ${COLOR_RESET}")" add_ca_secrets
    add_ca_secrets=${add_ca_secrets:-n}
    
    if [[ ! "$add_ca_secrets" =~ ^[Yy]$ ]]; then
        info "No additional CA secrets will be added"
        return 0
    fi
    
    # Initialize array to store additional CA secrets
    ADDITIONAL_CA_SECRETS=()
    
    local continue_adding=true
    while [ "$continue_adding" = true ]; do
        echo
        local secret_name=""
        read -p "$(echo -e "${COLOR_CYAN}Enter CA secret name: ${COLOR_RESET}")" secret_name
        
        if [ -z "$secret_name" ]; then
            warning "Secret name cannot be empty"
            continue
        fi
        
        # Validate secret exists
        if ! ${CLI_CMD} get secret "$secret_name" -n "$INSTANCE_NAMESPACE" &> /dev/null; then
            warning "Secret '$secret_name' not found in namespace: $INSTANCE_NAMESPACE"
            read -p "$(echo -e "${COLOR_CYAN}Do you want to enter a different name? (y/n) [y]: ${COLOR_RESET}")" retry
            retry=${retry:-y}
            if [[ "$retry" =~ ^[Nn]$ ]]; then
                continue
            fi
            continue
        fi
        
        # Check for tls.crt key
        local has_cert=$(${CLI_CMD} get secret "$secret_name" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
        
        if [ -z "$has_cert" ]; then
            warning "Secret '$secret_name' does not contain 'tls.crt' key"
            read -p "$(echo -e "${COLOR_CYAN}Do you want to enter a different name? (y/n) [y]: ${COLOR_RESET}")" retry
            retry=${retry:-y}
            if [[ "$retry" =~ ^[Nn]$ ]]; then
                continue
            fi
            continue
        fi
        
        success "Secret '$secret_name' validated successfully"
        ADDITIONAL_CA_SECRETS+=("$secret_name")
        
        echo
        read -p "$(echo -e "${COLOR_YELLOW}Add another CA secret? (y/n) [n]: ${COLOR_RESET}")" add_another
        add_another=${add_another:-n}
        if [[ ! "$add_another" =~ ^[Yy]$ ]]; then
            continue_adding=false
        fi
    done
    
    if [ ${#ADDITIONAL_CA_SECRETS[@]} -gt 0 ]; then
        echo
        success "Added ${#ADDITIONAL_CA_SECRETS[@]} additional CA secret(s)"
        for secret in "${ADDITIONAL_CA_SECRETS[@]}"; do
            info "  - $secret"
        done
    fi
}

function generate_server_certificate() {
    info "Generating server certificate from CA..."
    
    local cert_dir="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cert/model-gateway"
    mkdir -p "$cert_dir"
    
    local server_key="$cert_dir/tls.key"
    local server_csr="$cert_dir/tls.csr"
    local server_cert="$cert_dir/tls.crt"
    local server_cn="${TLS_SERVER_CN:-model-gateway.$INSTANCE_NAMESPACE.svc}"
    
    # Generate server private key
    if ! openssl genrsa -out "$server_key" 2048 2>/dev/null; then
        error "Failed to generate server private key"
        return 1
    fi
    
    # Create OpenSSL config for SAN
    local ssl_config="$cert_dir/openssl.cnf"
    cat > "$ssl_config" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${server_cn}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = model-gateway-service
DNS.2 = model-gateway-service.${INSTANCE_NAMESPACE}
DNS.3 = model-gateway-service.${INSTANCE_NAMESPACE}.svc
DNS.4 = model-gateway-service.${INSTANCE_NAMESPACE}.svc.cluster.local
DNS.5 = ${server_cn}
EOF
    
    # Generate CSR
    if ! openssl req -new -key "$server_key" -out "$server_csr" -config "$ssl_config" 2>/dev/null; then
        error "Failed to generate certificate signing request"
        return 1
    fi
    
    # Sign certificate with CA
    if ! openssl x509 -req -in "$server_csr" \
        -CA "$TLS_CA_CERT_PATH" \
        -CAkey "$TLS_CA_KEY_PATH" \
        -CAcreateserial \
        -out "$server_cert" \
        -days 365 \
        -extensions v3_req \
        -extfile "$ssl_config" 2>/dev/null; then
        error "Failed to sign server certificate"
        return 1
    fi
    
    TLS_CERT_PATH="$server_cert"
    TLS_KEY_PATH="$server_key"
    
    success "Server certificate generated successfully"
    info "Certificate: $server_cert"
    info "Private Key: $server_key"
    
    return 0
}

function create_tls_secret() {
    info "Creating TLS secret: $TLS_SECRET_NAME"
    
    # If generating from CA, generate the certificate first
    if [ "$TLS_GENERATE_FROM_CA" = "true" ]; then
        if ! generate_server_certificate; then
            error "Failed to generate server certificate"
            return 1
        fi
    fi
    
    # Check if secret already exists
    if ${CLI_CMD} get secret "$TLS_SECRET_NAME" -n "$INSTANCE_NAMESPACE" &> /dev/null; then
        warning "Secret '$TLS_SECRET_NAME' already exists in namespace: $INSTANCE_NAMESPACE"
        read -p "$(echo -e "${COLOR_CYAN}Do you want to replace it? (y/n) [n]: ${COLOR_RESET}")" replace
        replace=${replace:-n}
        
        if [ "$replace" = "y" ]; then
            info "Deleting existing secret..."
            ${CLI_CMD} delete secret "$TLS_SECRET_NAME" -n "$INSTANCE_NAMESPACE"
        else
            info "Using existing secret"
            return 0
        fi
    fi
    
    # Create the secret
    if [ "$TLS_GENERATE_FROM_CA" = "true" ]; then
        # Create from generated files
        if ! ${CLI_CMD} create secret tls "$TLS_SECRET_NAME" \
            --cert="$TLS_CERT_PATH" \
            --key="$TLS_KEY_PATH" \
            -n "$INSTANCE_NAMESPACE"; then
            error "Failed to create TLS secret"
            return 1
        fi
    fi
    
    success "TLS secret '$TLS_SECRET_NAME' created successfully"
    return 0
}

function validate_tls_configuration() {
    if [ "$USE_CUSTOM_TLS" != "true" ]; then
        return 0
    fi
    
    info "Validating TLS configuration..."
    
    # Check if secret exists
    if ! ${CLI_CMD} get secret "$TLS_SECRET_NAME" -n "$INSTANCE_NAMESPACE" &> /dev/null; then
        if [ "$TLS_GENERATE_FROM_CA" = "true" ]; then
            # Need to create the secret
            if ! create_tls_secret; then
                error "Failed to create TLS secret"
                return 1
            fi
        else
            error "TLS secret '$TLS_SECRET_NAME' not found in namespace: $INSTANCE_NAMESPACE"
            return 1
        fi
    fi
    
    # Validate secret has required keys
    local has_cert=$(${CLI_CMD} get secret "$TLS_SECRET_NAME" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
    local has_key=$(${CLI_CMD} get secret "$TLS_SECRET_NAME" -n "$INSTANCE_NAMESPACE" -o jsonpath='{.data.tls\.key}' 2>/dev/null)
    
    if [ -z "$has_cert" ] || [ -z "$has_key" ]; then
        error "TLS secret '$TLS_SECRET_NAME' does not contain required keys: tls.crt and tls.key"
        return 1
    fi
    
    success "TLS configuration validated successfully"
    return 0
}


# Provider field schemas matching operator's vars/main.yml
declare -A PROVIDER_FIELDS=(
    ["openai"]="apikey baseURL"
    ["anthropic"]="apikey"
    ["bedrock"]="region accessKeyId secretAccessKey sessionToken baseURL"
    ["azureOpenai"]="resourceName apiVersion apikey subscriptionID resourceGroupName accountName"
    ["cerebras"]="apikey"
    ["cohere"]="apikey"
    ["gemini"]="apikey"
    ["groq"]="apikey"
    ["watsonxai"]="baseURL apikey authURL projectID spaceID apiVersion"
    ["mistral"]="apikey"
    ["nvidiaNim"]="apikey"
    ["ollama"]="host"
    ["xai"]="apikey"
    ["adobeFirefly"]="clientID clientSecret"
)

declare -A PROVIDER_DESCRIPTIONS=(
    ["openai"]="OpenAI (GPT-4, GPT-3.5, etc.)"
    ["anthropic"]="Anthropic (Claude)"
    ["bedrock"]="AWS Bedrock"
    ["azureOpenai"]="Azure OpenAI"
    ["cerebras"]="Cerebras"
    ["cohere"]="Cohere"
    ["gemini"]="Google Gemini"
    ["groq"]="Groq"
    ["watsonxai"]="IBM watsonx.ai"
    ["mistral"]="Mistral AI"
    ["nvidiaNim"]="NVIDIA NIM"
    ["ollama"]="Ollama"
    ["xai"]="xAI (Grok)"
    ["adobeFirefly"]="Adobe Firefly"
)

declare -A FIELD_DESCRIPTIONS=(
    ["apikey"]="API Key"
    ["baseURL"]="Base URL (watsonx.ai ML endpoint, e.g., https://us-south.ml.cloud.ibm.com)"
    ["region"]="AWS Region"
    ["accessKeyId"]="AWS Access Key ID"
    ["secretAccessKey"]="AWS Secret Access Key"
    ["sessionToken"]="AWS Session Token (optional)"
    ["resourceName"]="Azure Resource Name"
    ["apiVersion"]="API Version"
    ["subscriptionID"]="Azure Subscription ID"
    ["resourceGroupName"]="Azure Resource Group Name"
    ["accountName"]="Azure Account Name"
    ["authURL"]="Authentication URL (IAM endpoint, e.g., https://iam.cloud.ibm.com/identity/token)"
    ["projectID"]="Project ID (required if spaceID not provided for Watsonx.ai SaaS.  Optional for IBM Watsonx.ai LightWeightEngine)"
    ["spaceID"]="Space ID (required if projectID not provided for Watsonx.ai SaaS. Optional for IBM Watsonx.ai LightWeightEngine)"
    ["host"]="Host URL"
    ["clientID"]="Client ID"
    ["clientSecret"]="Client Secret"
)

function configure_provider_credentials() {
    local skip_initial_prompt=${1:-false}
    
    info "Configuring AI Provider Credentials"
    echo
    
    local property_dir="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile"
    local secret_dir="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/secret_template/modelgateway"
    local provider_secret_file="${secret_dir}/provider_secret_template.yaml"
    
    # Create directories if they don't exist
    mkdir -p "$property_dir"
    mkdir -p "$secret_dir"
    
    # Initialize arrays to store configuration
    local -a tenants=()
    local -a credentials_data=()
    
    # Ask if user wants to configure provider credentials (unless called from interactive mode)
    if [ "$skip_initial_prompt" != "true" ]; then
        echo
        msgB "═══════════════════════════════════════════════════════════════════════════"
        msgB "  AI Provider Credentials Configuration"
        msgB "═══════════════════════════════════════════════════════════════════════════"
        echo
        info "Model Gateway can connect to external AI providers using Kubernetes Secrets."
        info "This allows you to configure credentials for providers like OpenAI, Anthropic,"
        info "AWS Bedrock, Azure OpenAI, and more."
        echo
        
        read -p "$(echo -e "${COLOR_YELLOW}Do you want to configure AI provider credentials? (y/n): ${COLOR_RESET}")" configure_providers
        
        if [[ ! "$configure_providers" =~ ^[Yy]$ ]]; then
            info "Skipping AI provider credentials configuration"
            return 0
        fi
    fi
    
    echo
    info "You will be prompted to:"
    info "  1. Select AI providers"
    info "  2. Enter credentials for each provider"
    info "  3. Configure model mappings"
    echo
    
    # Use default tenant information
    local tenant_name="default"
    local account_id="999"
    
    info "Using tenant: $tenant_name (Account ID: $account_id)"
    echo
    
    # Collect provider credentials
    local continue_adding=true
    local credential_index=0
    
    while [ "$continue_adding" = true ]; do
        echo
        msgB "───────────────────────────────────────────────────────────────────────────"
        msgB "  Add Provider Credential #$((credential_index + 1))"
        msgB "───────────────────────────────────────────────────────────────────────────"
        echo
        
        # Show available providers
        info "Available AI Providers:"
        echo
        local provider_num=1
        local -a provider_list=()
        for provider in "${!PROVIDER_DESCRIPTIONS[@]}"; do
            provider_list+=("$provider")
        done
        # Sort providers alphabetically
        IFS=$'\n' provider_list=($(sort <<<"${provider_list[*]}"))
        unset IFS
        
        for provider in "${provider_list[@]}"; do
            printf "  %2d. %-15s - %s\n" "$provider_num" "$provider" "${PROVIDER_DESCRIPTIONS[$provider]}"
            provider_num=$((provider_num + 1))
        done
        echo
        
        read -p "$(echo -e "${COLOR_YELLOW}Select provider number (1-${#provider_list[@]}): ${COLOR_RESET}")" provider_choice
        
        if [[ ! "$provider_choice" =~ ^[0-9]+$ ]] || [ "$provider_choice" -lt 1 ] || [ "$provider_choice" -gt "${#provider_list[@]}" ]; then
            error "Invalid selection"
            continue
        fi
        
        local selected_provider="${provider_list[$((provider_choice - 1))]}"
        success "Selected: ${PROVIDER_DESCRIPTIONS[$selected_provider]}"
        echo
        
        # Get credential name with default
        local default_cred_name="${selected_provider}-prod"
        read -p "$(echo -e "${COLOR_YELLOW}Enter a name for this credential (default: ${default_cred_name}): ${COLOR_RESET}")" cred_name
        cred_name=${cred_name:-$default_cred_name}
        
        # Collect fields for this provider
        local fields="${PROVIDER_FIELDS[$selected_provider]}"
        local -A field_values=()
        
        echo
        info "Enter credentials for ${PROVIDER_DESCRIPTIONS[$selected_provider]}:"
        echo
        
        for field in $fields; do
            local field_desc="${FIELD_DESCRIPTIONS[$field]}"
            local is_optional=false
            local default_value=""
            
            # Set default values for watsonx.ai fields
            if [[ "$selected_provider" == "watsonxai" ]]; then
                case "$field" in
                    baseURL)
                        default_value="https://us-south.ml.cloud.ibm.com"
                        ;;
                    authURL)
                        default_value="https://iam.cloud.ibm.com/identity/token"
                        ;;
                    apiVersion)
                        is_optional=true
                        ;;
                esac
            fi
            
            # Mark optional fields
            if [[ "$field" == "sessionToken" ]] || [[ "$field" == "baseURL" && "$selected_provider" != "watsonxai" ]]; then
                is_optional=true
                field_desc="$field_desc (optional)"
            fi
            
            # Mark apiVersion as optional for watsonx.ai
            if [[ "$selected_provider" == "watsonxai" ]] && [[ "$field" == "apiVersion" ]] && [[ "$is_optional" == true ]]; then
                field_desc="$field_desc (optional)"
            fi
            
            # For watsonx.ai: projectID and spaceID are both optional
            if [[ "$selected_provider" == "watsonxai" ]] && [[ "$field" == "projectID" || "$field" == "spaceID" ]]; then
                is_optional=true
            fi
            
            # Build prompt with default value if available
            local prompt_text="  ${field_desc}"
            if [ -n "$default_value" ]; then
                prompt_text="${prompt_text} (default: ${default_value})"
            fi
            prompt_text="${prompt_text}: "
            
            # Handle sensitive fields (don't echo)
            if [[ "$field" =~ (apikey|password|secret|token|Secret) ]]; then
                read -s -p "$(echo -e "${COLOR_YELLOW}${prompt_text}${COLOR_RESET}")" field_value
                echo
            else
                read -p "$(echo -e "${COLOR_YELLOW}${prompt_text}${COLOR_RESET}")" field_value
            fi
            
            # Use default if no value provided
            if [ -z "$field_value" ] && [ -n "$default_value" ]; then
                field_value="$default_value"
            fi
            
            # Validate required fields
            if [ -z "$field_value" ] && [ "$is_optional" = false ]; then
                error "  ${field_desc} is required"
                continue 2
            fi
            
            if [ -n "$field_value" ]; then
                field_values["$field"]="$field_value"
            fi
        done
        
        # Note: For watsonx.ai, projectID and spaceID are both optional
        # No validation required - user can provide neither, one, or both
        
        # Store credential data
        local secret_key="${cred_name//[^a-zA-Z0-9]/-}"
        local cred_json="{"
        local first=true
        for field in "${!field_values[@]}"; do
            if [ "$first" = false ]; then
                cred_json+=","
            fi
            cred_json+="\"$field\":\"${field_values[$field]}\""
            first=false
        done
        cred_json+="}"
        
        credentials_data+=("$secret_key:$cred_json")
        
        # Ask for model configuration
        echo
        info "Configure models for this credential:"
        local add_models=true
        local -a models=()
        
        while [ "$add_models" = true ]; do
            read -p "$(echo -e "${COLOR_YELLOW}  Model ID (e.g., gpt-4, claude-3-opus): ${COLOR_RESET}")" model_id
            if [ -z "$model_id" ]; then
                break
            fi
            
            read -p "$(echo -e "${COLOR_YELLOW}  Model alias (optional, press Enter to skip): ${COLOR_RESET}")" model_alias
            
            if [ -n "$model_alias" ]; then
                models+=("$model_id:$model_alias:$cred_name")
            else
                models+=("$model_id::$cred_name")
            fi
            
            read -p "$(echo -e "${COLOR_YELLOW}  Add another model for this credential? (y/n): ${COLOR_RESET}")" add_another_model
            if [[ ! "$add_another_model" =~ ^[Yy]$ ]]; then
                add_models=false
            fi
        done
        
        # Store tenant configuration
        tenants+=("$tenant_name:$account_id:$cred_name:$selected_provider:$secret_key:${models[*]}")
        
        credential_index=$((credential_index + 1))
        echo
        read -p "$(echo -e "${COLOR_YELLOW}Add another provider credential? (y/n): ${COLOR_RESET}")" add_another
        if [[ ! "$add_another" =~ ^[Yy]$ ]]; then
            continue_adding=false
        fi
    done
    
    # Generate Kubernetes Secret YAML
    echo
    info "Generating Kubernetes Secret and CR configuration..."
    
    # Check if secret already exists
    local existing_secret_data=""
    if ${CLI_CMD} get secret model-gateway-provider-secret -n "$INSTANCE_NAMESPACE" &> /dev/null; then
        info "Found existing provider secret, merging with new credentials..."
        existing_secret_data=$(${CLI_CMD} get secret model-gateway-provider-secret -n "$INSTANCE_NAMESPACE" -o json | ${YQ_CMD} -p json -o json '.data // {}')
    fi
    
    # Start building the secret
    cat > "$provider_secret_file" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: model-gateway-provider-secret
  namespace: ${INSTANCE_NAMESPACE}
  labels:
    app: model-gateway
    component: provider-credentials
type: Opaque
data:
EOF
    
    # If there's existing data, add it first (will be overwritten by new keys with same name)
    if [ -n "$existing_secret_data" ] && [ "$existing_secret_data" != "{}" ]; then
        # Extract existing keys and add them
        local existing_keys=$(echo "$existing_secret_data" | ${YQ_CMD} -p json -r 'keys | .[]')
        while IFS= read -r key; do
            if [ -n "$key" ]; then
                local value=$(echo "$existing_secret_data" | ${YQ_CMD} -p json -r ".[\"$key\"]")
                echo "  $key: $value" >> "$provider_secret_file"
            fi
        done <<< "$existing_keys"
    fi
    
    # Add new credentials to secret (these will override existing keys with same name)
    for cred_data in "${credentials_data[@]}"; do
        local secret_key="${cred_data%%:*}"
        local cred_json="${cred_data#*:}"
        local encoded=$(echo -n "$cred_json" | base64 | tr -d '\n')
        
        # Check if this key already exists in the file
        if grep -q "^  $secret_key:" "$provider_secret_file"; then
            # Replace existing key
            sed -i.bak "s|^  $secret_key:.*|  $secret_key: $encoded|" "$provider_secret_file"
            rm -f "${provider_secret_file}.bak"
            info "Updated existing credential: $secret_key"
        else
            # Add new key
            echo "  $secret_key: $encoded" >> "$provider_secret_file"
            info "Added new credential: $secret_key"
        fi
    done
    
    # Generate CR configuration snippet
    local cr_config_file="${property_dir}/provider_cr_config.yaml"
    cat > "$cr_config_file" << EOF
# Add this to your ModelGateway CR spec:
spec:
  providerK8sSecret: true
  tenants:
EOF
    
    # Process tenants and generate CR config
    local -A tenant_map=()
    for tenant_data in "${tenants[@]}"; do
        IFS=':' read -r t_name t_account cred_name provider secret_key models_str <<< "$tenant_data"
        
        if [ -z "${tenant_map[$t_name]}" ]; then
            tenant_map[$t_name]="$t_account"
            cat >> "$cr_config_file" << EOF
    - name: $t_name
      accountId: "$t_account"
      credentials:
EOF
        fi
        
        cat >> "$cr_config_file" << EOF
        - name: $cred_name
          provider: $provider
          secretKey: $secret_key
EOF
    done
    
    # Add models section
    for tenant_data in "${tenants[@]}"; do
        IFS=':' read -r t_name t_account cred_name provider secret_key models_str <<< "$tenant_data"
        
        if [ -n "$models_str" ]; then
            # Check if we already added models section for this tenant
            if ! grep -q "name: $t_name" "$cr_config_file" | grep -q "models:" ; then
                # Find the tenant and add models
                local temp_file=$(mktemp)
                awk -v tenant="$t_name" '
                    /name: / && $2 == tenant {in_tenant=1}
                    in_tenant && /credentials:/ {print; print "      models:"; in_tenant=0; next}
                    {print}
                ' "$cr_config_file" > "$temp_file"
                mv "$temp_file" "$cr_config_file"
            fi
            
            # Add models
            IFS=' ' read -ra model_array <<< "$models_str"
            for model_entry in "${model_array[@]}"; do
                IFS=':' read -r model_id model_alias model_cred <<< "$model_entry"
                if [ "$model_cred" = "$cred_name" ]; then
                    cat >> "$cr_config_file" << EOF
        - id: "$model_id"
EOF
                    if [ -n "$model_alias" ]; then
                        echo "          alias: \"$model_alias\"" >> "$cr_config_file"
                    fi
                    echo "          credentialName: $cred_name" >> "$cr_config_file"
                fi
            done
        fi
    done
    
    success "Provider configuration files created:"
    info "  Secret YAML: $provider_secret_file"
    info "  CR Config:   $cr_config_file"
    echo
    
    # Apply the secret
    read -p "$(echo -e "${COLOR_YELLOW}Apply the provider secret now? (y/n): ${COLOR_RESET}")" apply_secret
    if [[ "$apply_secret" =~ ^[Yy]$ ]]; then
        if ${CLI_CMD} apply -f "$provider_secret_file"; then
            success "Provider secret created successfully"
        else
            error "Failed to create provider secret"
            return 1
        fi
    else
        info "You can apply the secret later with:"
        info "  kubectl apply -f $provider_secret_file"
    fi
    
    echo
    
    # Check if ModelGateway CR exists and offer to patch it
    if ${CLI_CMD} get modelgateway modelgateway-cr -n "$INSTANCE_NAMESPACE" &> /dev/null; then
        info "Found existing ModelGateway CR: modelgateway-cr"
        echo
        read -p "$(echo -e "${COLOR_YELLOW}Do you want to patch the ModelGateway CR with provider configuration? (y/n): ${COLOR_RESET}")" patch_cr
        
        if [[ "$patch_cr" =~ ^[Yy]$ ]]; then
            info "Patching ModelGateway CR..."
            
            # Get existing CR configuration
            local existing_cr=$(${CLI_CMD} get modelgateway modelgateway-cr -n "$INSTANCE_NAMESPACE" -o json)
            
            # Check if providerK8sSecret is already enabled
            local existing_provider_k8s=$(echo "$existing_cr" | ${YQ_CMD} -p json -r '.spec.providerK8sSecret // false')
            
            # Get existing tenants
            local existing_tenants=$(echo "$existing_cr" | ${YQ_CMD} -p json -o json '.spec.tenants // []')
            
            info "Current configuration:"
            info "  providerK8sSecret: $existing_provider_k8s"
            info "  Existing tenants: $(echo "$existing_tenants" | ${YQ_CMD} -p json -r 'length')"
            echo
            
            # Build merged tenant configuration
            local temp_file=$(mktemp)
            echo "$existing_tenants" > "$temp_file"
            
            # Process each new tenant/credential
            for tenant_data in "${tenants[@]}"; do
                IFS=':' read -r t_name t_account cred_name provider secret_key models_str <<< "$tenant_data"
                
                # Check if tenant exists
                local tenant_idx=$(${YQ_CMD} -p json -r ".[] | select(.name == \"$t_name\") | .name" "$temp_file" 2>/dev/null | wc -l | tr -d ' ')
                
                if [ "$tenant_idx" -eq 0 ]; then
                    # Tenant doesn't exist, add it
                    info "Adding new tenant: $t_name"
                    local new_tenant=$(cat <<EOF
{
  "name": "$t_name",
  "accountId": "$t_account",
  "credentials": [
    {
      "name": "$cred_name",
      "provider": "$provider",
      "secretKey": "$secret_key"
    }
  ],
  "models": []
}
EOF
)
                    echo "$new_tenant" | ${YQ_CMD} -p json -o json '.' > "${temp_file}.new"
                    ${YQ_CMD} -p json -o json '. += [load("'"${temp_file}.new"'")]' "$temp_file" > "${temp_file}.tmp" && mv "${temp_file}.tmp" "$temp_file"
                    rm -f "${temp_file}.new"
                else
                    # Tenant exists, check if credential exists
                    local cred_exists=$(${YQ_CMD} -p json -r ".[] | select(.name == \"$t_name\") | .credentials[]? | select(.name == \"$cred_name\") | .name" "$temp_file" 2>/dev/null | wc -l | tr -d ' ')
                    
                    if [ "$cred_exists" -eq 0 ]; then
                        # Add credential to existing tenant
                        info "Adding credential '$cred_name' to existing tenant: $t_name"
                        ${YQ_CMD} -p json -o json -i "(.[] | select(.name == \"$t_name\") | .credentials) += [{\"name\": \"$cred_name\", \"provider\": \"$provider\", \"secretKey\": \"$secret_key\"}]" "$temp_file"
                    else
                        # Update existing credential
                        info "Updating existing credential '$cred_name' in tenant: $t_name"
                        ${YQ_CMD} -p json -o json -i "(.[] | select(.name == \"$t_name\") | .credentials[] | select(.name == \"$cred_name\")) |= {\"name\": \"$cred_name\", \"provider\": \"$provider\", \"secretKey\": \"$secret_key\"}" "$temp_file"
                    fi
                fi
                
                # Add or update models if configured
                if [ -n "$models_str" ]; then
                    IFS=' ' read -ra model_array <<< "$models_str"
                    for model_entry in "${model_array[@]}"; do
                        IFS=':' read -r model_id model_alias model_cred <<< "$model_entry"
                        if [ "$model_cred" = "$cred_name" ]; then
                            # Check if model exists
                            local model_exists=$(${YQ_CMD} -p json -r ".[] | select(.name == \"$t_name\") | .models[]? | select(.id == \"$model_id\") | .id" "$temp_file" 2>/dev/null | wc -l | tr -d ' ')
                            
                            if [ "$model_exists" -eq 0 ]; then
                                info "Adding model '$model_id' to tenant: $t_name"
                                if [ -n "$model_alias" ]; then
                                    ${YQ_CMD} -p json -o json -i "(.[] | select(.name == \"$t_name\") | .models) += [{\"id\": \"$model_id\", \"alias\": \"$model_alias\", \"credentialName\": \"$cred_name\"}]" "$temp_file"
                                else
                                    ${YQ_CMD} -p json -o json -i "(.[] | select(.name == \"$t_name\") | .models) += [{\"id\": \"$model_id\", \"credentialName\": \"$cred_name\"}]" "$temp_file"
                                fi
                            else
                                info "Updating model '$model_id' in tenant: $t_name"
                                if [ -n "$model_alias" ]; then
                                    ${YQ_CMD} -p json -o json -i "(.[] | select(.name == \"$t_name\") | .models[] | select(.id == \"$model_id\")) |= {\"id\": \"$model_id\", \"alias\": \"$model_alias\", \"credentialName\": \"$cred_name\"}" "$temp_file"
                                else
                                    ${YQ_CMD} -p json -o json -i "(.[] | select(.name == \"$t_name\") | .models[] | select(.id == \"$model_id\")) |= {\"id\": \"$model_id\", \"credentialName\": \"$cred_name\"}" "$temp_file"
                                fi
                            fi
                        fi
                    done
                fi
            done
            
            # Build final patch
            local merged_tenants=$(cat "$temp_file")
            local patch_json=$(echo "{\"spec\": {\"providerK8sSecret\": true, \"tenants\": $merged_tenants}}")
            
            rm -f "$temp_file" "${temp_file}.tmp" "${temp_file}.new"
            
            echo
            info "Merged configuration will have $(echo "$merged_tenants" | ${YQ_CMD} -p json -r 'length') tenant(s)"
            echo
            
            # Apply the patch
            if ${CLI_CMD} patch modelgateway modelgateway-cr -n "$INSTANCE_NAMESPACE" \
                --type merge -p "$patch_json"; then
                success "ModelGateway CR patched successfully"
                echo
                
                # Wait for operator to process the change
                info "Waiting 30 seconds for operator to process the CR update..."
                sleep 30
                echo
                
                # Check ModelGateway CR status before restarting pods
                info "Checking ModelGateway CR reconciliation status..."
                local max_wait=300  # 5 minutes
                local elapsed=0
                local check_interval=10
                local cr_ready=false
                
                while [ $elapsed -lt $max_wait ]; do
                    # Get CR status - looking for modelgatewayStatus=Completed and progress=100%
                    local cr_status=$(${CLI_CMD} get modelgateway modelgateway-cr -n "$INSTANCE_NAMESPACE" \
                        -o jsonpath='{.status.modelgatewayStatus}' 2>/dev/null)
                    local cr_percent=$(${CLI_CMD} get modelgateway modelgateway-cr -n "$INSTANCE_NAMESPACE" \
                        -o jsonpath='{.status.progress}' 2>/dev/null)
                    
                    if [[ "$cr_status" == "Completed" ]] && [[ "$cr_percent" == "100%" ]]; then
                        cr_ready=true
                        success "ModelGateway CR reconciliation completed (100%)"
                        break
                    else
                        info "Current status: ${cr_percent:-0}  complete (waiting for 100%)"
                        sleep $check_interval
                        elapsed=$((elapsed + check_interval))
                    fi
                done
                
                if [ "$cr_ready" = false ]; then
                    warning "Timeout waiting for ModelGateway CR to reach 100% completion"
                    info "Current CR status:"
                    ${CLI_CMD} get modelgateway modelgateway-cr -n "$INSTANCE_NAMESPACE" 2>/dev/null || true
                    echo
                    warning "Skipping pod restart. You can manually restart after reconciliation completes:"
                    info "  ${CLI_CMD} rollout restart deployment/model-gateway -n $INSTANCE_NAMESPACE"
                else
                    echo
                    # Restart Model Gateway pods to pick up new configuration
                    info "Restarting Model Gateway pods to apply new provider configuration..."
                    if ${CLI_CMD} get deployment model-gateway -n "$INSTANCE_NAMESPACE" &> /dev/null; then
                        if ${CLI_CMD} rollout restart deployment/model-gateway -n "$INSTANCE_NAMESPACE"; then
                            success "Model Gateway deployment restart initiated"
                            echo
                            info "Waiting for pods to be ready..."
                            if ${CLI_CMD} rollout status deployment/model-gateway -n "$INSTANCE_NAMESPACE" --timeout=300s; then
                                success "Model Gateway pods restarted successfully"
                                info "New provider configuration is now active"
                            else
                                warning "Timeout waiting for pods to be ready"
                                info "Check pod status with: ${CLI_CMD} get pods -n $INSTANCE_NAMESPACE -l app=model-gateway"
                            fi
                        else
                            warning "Failed to restart Model Gateway deployment"
                            info "You can manually restart with: ${CLI_CMD} rollout restart deployment/model-gateway -n $INSTANCE_NAMESPACE"
                        fi
                    else
                        warning "Model Gateway deployment not found"
                        info "The operator will create it based on the updated CR"
                    fi
                fi
            else
                error "Failed to patch ModelGateway CR"
                warning "You can manually update the CR using the configuration in: $cr_config_file"
            fi
        else
            info "Skipping CR patch. You can manually update the CR later using:"
            info "  Configuration file: $cr_config_file"
        fi
        echo
    else
        info "ModelGateway CR not found. Configuration will be applied during deployment."
        echo
    fi
    
    # Generate Helm values file for provider configuration
    local helm_values_file="${property_dir}/provider_helm_values.yaml"
    cat > "$helm_values_file" <<EOF
modelGateway:
  providerK8sSecret: true
  tenants:
EOF
    
    # Build tenants array
    local tenant_index=0
    local -A processed_tenants=()
    
    for tenant_data in "${tenants[@]}"; do
        IFS=':' read -r t_name t_account cred_name provider secret_key models_str <<< "$tenant_data"
        
        # Add tenant if not already processed
        if [ -z "${processed_tenants[$t_name]}" ]; then
            cat >> "$helm_values_file" <<EOF
  - name: "$t_name"
    accountId: "$t_account"
    credentials: []
    models: []
EOF
            processed_tenants[$t_name]=$tenant_index
            tenant_index=$((tenant_index + 1))
        fi
    done
    
    # Now add credentials and models using yq
    tenant_index=0
    declare -A processed_tenants_idx=()
    
    for tenant_data in "${tenants[@]}"; do
        IFS=':' read -r t_name t_account cred_name provider secret_key models_str <<< "$tenant_data"
        
        if [ -z "${processed_tenants_idx[$t_name]}" ]; then
            processed_tenants_idx[$t_name]=$tenant_index
            tenant_index=$((tenant_index + 1))
        fi
        
        local t_idx=${processed_tenants_idx[$t_name]}
        local cred_idx=$(${YQ_CMD} eval ".modelGateway.tenants[$t_idx].credentials | length" "$helm_values_file")
        
        # Add credential
        ${YQ_CMD} eval ".modelGateway.tenants[$t_idx].credentials[$cred_idx].name = \"$cred_name\"" -i "$helm_values_file"
        ${YQ_CMD} eval ".modelGateway.tenants[$t_idx].credentials[$cred_idx].provider = \"$provider\"" -i "$helm_values_file"
        ${YQ_CMD} eval ".modelGateway.tenants[$t_idx].credentials[$cred_idx].secretKey = \"$secret_key\"" -i "$helm_values_file"
        
        # Add models if configured
        if [ -n "$models_str" ]; then
            IFS=' ' read -ra model_array <<< "$models_str"
            for model_entry in "${model_array[@]}"; do
                IFS=':' read -r model_id model_alias model_cred <<< "$model_entry"
                if [ "$model_cred" = "$cred_name" ]; then
                    local model_idx=$(${YQ_CMD} eval ".modelGateway.tenants[$t_idx].models | length" "$helm_values_file")
                    ${YQ_CMD} eval ".modelGateway.tenants[$t_idx].models[$model_idx].id = \"$model_id\"" -i "$helm_values_file"
                    if [ -n "$model_alias" ]; then
                        ${YQ_CMD} eval ".modelGateway.tenants[$t_idx].models[$model_idx].alias = \"$model_alias\"" -i "$helm_values_file"
                    fi
                    ${YQ_CMD} eval ".modelGateway.tenants[$t_idx].models[$model_idx].credentialName = \"$cred_name\"" -i "$helm_values_file"
                fi
            done
        fi
    done
    
    success "Provider configuration saved to Helm values file: $helm_values_file"
    info "This will be applied during Helm installation"
    
    # Export the path for use during deployment
    export PROVIDER_HELM_VALUES_FILE="$helm_values_file"
    
    echo
    
    return 0
}

function check_prerequisite_operators() {
    info "Checking prerequisite operators..."
    
    local missing_operators=0
    local install_redis=false
    
    # Note: EDB PostgreSQL operator check is disabled for this release
    # Model Gateway now supports external PostgreSQL only
    
    # Check for Redis operator in instance namespace first, then operator namespace
    local redis_found=false
    if ${CLI_CMD} get deployment ibm-redis-cp-operator -n "$INSTANCE_NAMESPACE" &> /dev/null; then
        success "IBM Redis operator found in instance namespace: $INSTANCE_NAMESPACE"
        redis_found=true
    elif ${CLI_CMD} get deployment ibm-redis-cp-operator -n "$OPERATOR_NAMESPACE" &> /dev/null; then
        success "IBM Redis operator found in operator namespace: $OPERATOR_NAMESPACE"
        redis_found=true
    fi
    
    if [ "$redis_found" = false ]; then
        warning "IBM Redis operator not found in namespace: $INSTANCE_NAMESPACE or $OPERATOR_NAMESPACE"
        info "    Attempting to install IBM Redis operator..."
        install_redis=true
    fi
    
    # Install Redis operator if needed
    if [ "$install_redis" = true ]; then
        if install_redis_operator; then
            success "IBM Redis operator installed successfully"
        else
            error "Failed to install IBM Redis operator"
            missing_operators=$((missing_operators + 1))
        fi
    fi
    
    if [ $missing_operators -gt 0 ]; then
        warning "Some prerequisite operators are missing."
        warning "The Model Gateway deployment may fail without these operators."
        return 1
    fi
    
    success "All prerequisite operators found"
    return 0
}

function verify_prerequisites() {
    info "Verifying prerequisites..."
    echo
    
    local errors=0
    
    # Check required commands
    info "Checking required commands..."
    check_command kubectl || errors=$((errors + 1))
    check_command helm || errors=$((errors + 1))
    
    # Set Helm version-specific flag after confirming helm is available
    if command -v helm &> /dev/null; then
        set_helm_list_all_flag
    fi
    echo
    
    # Check cluster connection
    check_cluster_connection || errors=$((errors + 1))
    echo
    
    # Check namespaces
    info "Checking namespaces..."
    
    # Only check operator namespace if it's different from instance namespace
    if [ "$OPERATOR_NAMESPACE" != "$INSTANCE_NAMESPACE" ]; then
        if check_namespace "$OPERATOR_NAMESPACE"; then
            success "Operator namespace exists: $OPERATOR_NAMESPACE"
        else
            warning "Operator namespace does not exist: $OPERATOR_NAMESPACE"
            info "    It will be created during deployment"
        fi
    fi
    
    if check_namespace "$INSTANCE_NAMESPACE"; then
        success "Instance namespace exists: $INSTANCE_NAMESPACE"
    else
        warning "Instance namespace does not exist: $INSTANCE_NAMESPACE"
        info "    It will be created during deployment"
    fi
    echo
    
    # Check ZenService
    if check_namespace "$INSTANCE_NAMESPACE"; then
        check_zenservice || errors=$((errors + 1))
        echo
    fi
    
    # Check image pull secret
    info "Checking image pull secret..."
    
    # Check in instance namespace (primary location)
    if check_image_pull_secret "$INSTANCE_NAMESPACE" "$IMAGE_PULL_SECRET"; then
        success "Image pull secret found in instance namespace: $IMAGE_PULL_SECRET"
    else
        warning "Image pull secret not found in instance namespace: $IMAGE_PULL_SECRET"
        
        # If operator namespace is different, check there too
        if [ "$OPERATOR_NAMESPACE" != "$INSTANCE_NAMESPACE" ]; then
            if check_image_pull_secret "$OPERATOR_NAMESPACE" "$IMAGE_PULL_SECRET"; then
                success "Image pull secret found in operator namespace: $IMAGE_PULL_SECRET"
                info "    It will be copied to instance namespace during deployment"
            else
                warning "Image pull secret not found in operator namespace: $IMAGE_PULL_SECRET"
                info "    Please create the secret before deployment"
                errors=$((errors + 1))
            fi
        else
            info "    Please create the secret before deployment"
            errors=$((errors + 1))
        fi
    fi
    echo
    
    # Check storage classes (only for Redis)
    if [ "$LITE_INSTALL" != "true" ]; then
        info "Checking storage classes..."
        check_storage_class "$STORAGE_CLASS_BLOCK" || errors=$((errors + 1))
        check_storage_class "$STORAGE_CLASS_FILE" || errors=$((errors + 1))
        echo
    fi
    
    # Check external PostgreSQL secret (skip for lite install and internal postgres)
    if [ "$LITE_INSTALL" != "true" ] && [ "$DEPLOY_INTERNAL_POSTGRES" != "true" ]; then
        if check_namespace "$INSTANCE_NAMESPACE"; then
            check_external_postgres_secret "$INSTANCE_NAMESPACE" || errors=$((errors + 1))
        else
            warning "Instance namespace does not exist yet"
            info "Checking for PostgreSQL configuration..."
            
            # Check if property file exists, if not prompt for configuration
            local property_file="${PARENT_DIR}/scripts/cp4ba-prerequisites/project/${INSTANCE_NAMESPACE}/propertyfile/cp4ba_model_gateway.property"
            if [ ! -f "$property_file" ]; then
                info "PostgreSQL property file not found. Configuration is required before deployment."
                echo
                if ! create_postgres_property_file; then
                    error "Failed to create PostgreSQL configuration"
                    errors=$((errors + 1))
                else
                    success "PostgreSQL configuration created successfully"
                    info "Secret will be created when namespace is available during deployment"
                fi
            else
                success "PostgreSQL property file found: $property_file"
                info "Secret will be created when namespace is available during deployment"
            fi
        fi
        echo
    fi
    
    # Check prerequisite operators
    check_prerequisite_operators
    echo
    
    # Check Helm charts
    info "Checking Helm charts..."
    if [ -d "$HELM_CHART_PATH/model-gateway-cluster-scoped" ]; then
        success "Found cluster-scoped Helm chart"
    else
        error "Cluster-scoped Helm chart not found at: $HELM_CHART_PATH/model-gateway-cluster-scoped"
        errors=$((errors + 1))
    fi
    
    if [ -d "$HELM_CHART_PATH/model-gateway" ]; then
        success "Found Model Gateway Helm chart"
    else
        error "Model Gateway Helm chart not found at: $HELM_CHART_PATH/model-gateway"
        errors=$((errors + 1))
    fi
    echo
    
    if [ $errors -gt 0 ]; then
        error "Prerequisites verification failed with $errors error(s)"
        return 1
    fi
    
    success "All prerequisites verified successfully"
    return 0
}

function install_crd() {
    info "Installing Model Gateway CRD..."
    
    if ${CLI_CMD} get crd modelgateway.modelgateway.cpd.ibm.com &> /dev/null; then
        warning "Model Gateway CRD already exists"
        return 0
    fi
    
    if helm install model-gateway-crd \
        "$HELM_CHART_PATH/model-gateway-cluster-scoped"; then
        success "Model Gateway CRD installed successfully"
        
        # Wait for CRD to be established and registered with API server
        info "Waiting for CRD to be established..."
        local max_wait=60
        local wait_time=0
        local sleep_interval=2
        
        while [ $wait_time -lt $max_wait ]; do
            if ${CLI_CMD} get crd modelgateway.modelgateway.cpd.ibm.com -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null | grep -q "True"; then
                success "CRD is established and ready"
                # Additional wait to ensure API server has fully registered the CRD
                info "Waiting for API server to fully register CRD..."
                sleep 5
                return 0
            fi
            sleep $sleep_interval
            wait_time=$((wait_time + sleep_interval))
            echo -n "."
        done
        
        echo
        warning "CRD installation completed but establishment status not confirmed within ${max_wait}s"
        info "Proceeding with deployment - CRD should be available"
        return 0
    else
        error "Failed to install Model Gateway CRD"
        return 1
    fi
}

function install_operator() {
    # Check for existing Helm releases (including failed ones)
    local existing_release=$(helm list $HELM_LIST_ALL_FLAG -n "$OPERATOR_NAMESPACE" -q | grep "^model-gateway-operator$")
    local release_status=""
    
    if [ -n "$existing_release" ]; then
        release_status=$(helm list $HELM_LIST_ALL_FLAG -n "$OPERATOR_NAMESPACE" -o json | ${YQ_CMD} -p json -r ".[] | select(.name == \"model-gateway-operator\") | .status")
        
        if [ "$release_status" = "failed" ] || [ "$release_status" = "pending-install" ] || [ "$release_status" = "pending-upgrade" ]; then
            warning "Found existing release in '$release_status' state"
            info "Uninstalling failed release..."
            if helm uninstall model-gateway-operator -n "$OPERATOR_NAMESPACE" 2>/dev/null; then
                success "Cleaned up failed release"
            else
                warning "Could not uninstall failed release, will attempt upgrade"
            fi
        elif [ "$release_status" = "deployed" ]; then
            info "Model Gateway operator already installed, upgrading..."
            local helm_command="upgrade"
        fi
    fi
    
    if [ -z "$helm_command" ]; then
        info "Installing Model Gateway operator..."
        local helm_command="install"
    fi
    
    # Create namespaces if they don't exist
    create_namespace "$OPERATOR_NAMESPACE" || return 1
    create_namespace "$INSTANCE_NAMESPACE" || return 1
    
    # Copy image pull secret to instance namespace if needed
    if ! check_image_pull_secret "$INSTANCE_NAMESPACE" "$IMAGE_PULL_SECRET"; then
        info "Copying image pull secret to instance namespace..."
        local secret_file=$(mktemp)
        ${CLI_CMD} get secret "$IMAGE_PULL_SECRET" -n "$OPERATOR_NAMESPACE" -o yaml > "$secret_file"
        ${YQ_CMD} eval ".metadata.namespace = \"$INSTANCE_NAMESPACE\"" -i "$secret_file"
        ${YQ_CMD} eval 'del(.metadata.resourceVersion)' -i "$secret_file"
        ${YQ_CMD} eval 'del(.metadata.uid)' -i "$secret_file"
        ${CLI_CMD} apply -f "$secret_file" || warning "Failed to copy image pull secret"
        rm -f "$secret_file"
    fi
    
    # Install operator via Helm
    local helm_args=(
        "model-gateway-operator"
        "$HELM_CHART_PATH/model-gateway"
        "--namespace" "$OPERATOR_NAMESPACE"
        "--set" "global.operatorNamespace=$OPERATOR_NAMESPACE"
        "--set" "global.instanceNamespace=$INSTANCE_NAMESPACE"
        "--set" "global.imagePullSecret=$IMAGE_PULL_SECRET"
        "--set" "global.imagePullPrefix=$IMAGE_REGISTRY"
        "--set" "global.licenseType=$LICENSE_TYPE"
        "--set" "global.licenseAccept=$LICENSE_ACCEPT"
        "--set" "modelGateway.crVersion=$MODEL_GATEWAY_VERSION"
        "--set" "modelGateway.scaleConfig=$SCALE_CONFIG"
        "--set" "modelGateway.cp4ba_license=true"
    )
    
    if [ -n "$STORAGE_CLASS_BLOCK" ]; then
        helm_args+=("--set" "global.blockStorageClass=$STORAGE_CLASS_BLOCK")
    fi
    
    if [ -n "$STORAGE_CLASS_FILE" ]; then
        helm_args+=("--set" "global.fileStorageClass=$STORAGE_CLASS_FILE")
    fi
    
    if [ -n "$STORAGE_VENDOR" ]; then
        helm_args+=("--set" "global.storageVendor=$STORAGE_VENDOR")
    fi
    
    if [ "$LITE_INSTALL" == "true" ]; then
        helm_args+=("--set" "modelGateway.lite_install=true")
    elif [ "$DEPLOY_INTERNAL_POSTGRES" == "true" ]; then
        # Deploy the internal IBM CNPG PostgreSQL operator
        helm_args+=("--set" "modelGateway.deploy_postgres=true")
        info "Using internal IBM CNPG PostgreSQL operator"
        
        # Disable Redis deployment for small scale config
        if [ "$SCALE_CONFIG" == "small" ]; then
            helm_args+=("--set" "modelGateway.deploy_redis=false")
            info "Redis deployment disabled for small scale configuration"
        fi
    else
        # External PostgreSQL — disable internal deployment
        helm_args+=("--set" "modelGateway.deploy_postgres=false")
        
        # Disable Redis deployment for small scale config
        if [ "$SCALE_CONFIG" == "small" ]; then
            helm_args+=("--set" "modelGateway.deploy_redis=false")
            info "Redis deployment disabled for small scale configuration"
        fi
    fi
    
    # Add provider configuration values file if it exists
    if [ -n "$PROVIDER_HELM_VALUES_FILE" ] && [ -f "$PROVIDER_HELM_VALUES_FILE" ]; then
        helm_args+=("--values" "$PROVIDER_HELM_VALUES_FILE")
        info "Including provider configuration from: $PROVIDER_HELM_VALUES_FILE"
    fi
    
    # Add custom TLS certificate configuration
    if [ "$USE_CUSTOM_TLS" = "true" ] && [ -n "$TLS_SECRET_NAME" ]; then
        local ca_secret_index=0
        helm_args+=("--set" "modelGateway.tls_ca_secrets[$ca_secret_index]=ibm-nginx-internal-tls-ca")
        ca_secret_index=$((ca_secret_index + 1))
        helm_args+=("--set" "modelGateway.tls_ca_secrets[$ca_secret_index]=$TLS_SECRET_NAME")
        info "Including custom TLS certificate: $TLS_SECRET_NAME"
        
        # Add additional CA secrets if any were specified
        if [ -n "${ADDITIONAL_CA_SECRETS:-}" ] && [ ${#ADDITIONAL_CA_SECRETS[@]} -gt 0 ]; then
            for secret in "${ADDITIONAL_CA_SECRETS[@]}"; do
                ca_secret_index=$((ca_secret_index + 1))
                helm_args+=("--set" "modelGateway.tls_ca_secrets[$ca_secret_index]=$secret")
                info "Including additional CA secret: $secret"
            done
        fi
    fi
    
    # Execute helm install or upgrade
    if helm "$helm_command" "${helm_args[@]}"; then
        if [ "$helm_command" = "install" ]; then
            success "Model Gateway operator installed successfully"
        else
            success "Model Gateway operator upgraded successfully"
        fi
        return 0
    else
        if [ "$helm_command" = "install" ]; then
            error "Failed to install Model Gateway operator"
            info "Check for existing releases with: helm list -n $OPERATOR_NAMESPACE"
            info "If needed, clean up with: helm uninstall model-gateway-operator -n $OPERATOR_NAMESPACE"
        else
            error "Failed to upgrade Model Gateway operator"
        fi
        return 1
    fi
}

function wait_for_operator() {
    info "Waiting for Model Gateway operator to be ready..."
    
    local max_wait=300
    local elapsed=0
    
    while [ $elapsed -lt $max_wait ]; do
        if ${CLI_CMD} get deployment ibm-cpd-model-gateway-operator -n "$OPERATOR_NAMESPACE" &> /dev/null; then
            if ${CLI_CMD} wait --for=condition=available --timeout=60s \
                deployment/ibm-cpd-model-gateway-operator -n "$OPERATOR_NAMESPACE" &> /dev/null; then
                success "Model Gateway operator is ready"
                return 0
            fi
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
        wait_msg "Waiting for operator... ($elapsed/$max_wait seconds)"
    done
    
    error "Timeout waiting for Model Gateway operator"
    return 1
}

function wait_for_deployment() {
    info "Waiting for Model Gateway deployment to complete..."
    
    local max_wait=600
    local elapsed=0
    
    while [ $elapsed -lt $max_wait ]; do
        local status=$(${CLI_CMD} get modelgateway modelgateway-cr -n "$INSTANCE_NAMESPACE" \
            -o jsonpath='{.status.modelgatewayStatus}' 2>/dev/null)
        
        if [ "$status" == "Completed" ]; then
            success "Model Gateway deployment completed successfully"
            return 0
        elif [ "$status" == "Failed" ]; then
            error "Model Gateway deployment failed"
            return 1
        fi
        
        sleep 15
        elapsed=$((elapsed + 15))
        wait_msg "Waiting for deployment... Status: ${status:-Pending} ($elapsed/$max_wait seconds)"
    done
    
    error "Timeout waiting for Model Gateway deployment"
    return 1
}

function verify_deployment() {
    info "Verifying Model Gateway deployment..."
    echo
    
    # Check operator
    info "Checking operator..."
    if ${CLI_CMD} get deployment ibm-cpd-model-gateway-operator -n "$OPERATOR_NAMESPACE" &> /dev/null; then
        success "Operator deployment found"
    else
        error "Operator deployment not found"
        return 1
    fi
    
    # Check CustomResource
    info "Checking CustomResource..."
    if ${CLI_CMD} get modelgateway modelgateway-cr -n "$INSTANCE_NAMESPACE" &> /dev/null; then
        success "ModelGateway CR found"
        local status=$(${CLI_CMD} get modelgateway modelgateway-cr -n "$INSTANCE_NAMESPACE" \
            -o jsonpath='{.status.modelgatewayStatus}')
        info "    Status: $status"
    else
        error "ModelGateway CR not found"
        return 1
    fi
    
    # Check Model Gateway pods
    info "Checking Model Gateway pods..."
    local pod_count=$(${CLI_CMD} get pods -n "$INSTANCE_NAMESPACE" -l app=model-gateway \
        --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    if [ $pod_count -gt 0 ]; then
        success "Model Gateway pods running: $pod_count"
    else
        warning "No Model Gateway pods running yet"
    fi
    
    # Check PostgreSQL
    if [ "$LITE_INSTALL" != "true" ]; then
        info "Checking PostgreSQL cluster..."
        if ${CLI_CMD} get cluster -n "$INSTANCE_NAMESPACE" &> /dev/null; then
            success "PostgreSQL cluster found"
        else
            warning "PostgreSQL cluster not found"
        fi
    fi
    
    # Check Redis
    if [ "$LITE_INSTALL" != "true" ]; then
        info "Checking Redis cluster..."
        if ${CLI_CMD} get rediscp -n "$INSTANCE_NAMESPACE" &> /dev/null; then
            success "Redis cluster found"
        else
            warning "Redis cluster not found"
        fi
    fi
    
    echo
    success "Deployment verification completed"
    return 0
}

function wait_for_pod() {
    local namespace=$1
    local label=$2
    local max_wait=300
    local elapsed=0
    
    while [ $elapsed -lt $max_wait ]; do
        local pod_name=$(${CLI_CMD} get pod -l "$label" -n "$namespace" --no-headers 2>/dev/null | awk '{print $1}' | head -1)
        if [ -n "$pod_name" ]; then
            if ${CLI_CMD} wait --for=condition=Ready pod/"$pod_name" -n "$namespace" --timeout=60s &> /dev/null; then
                return 0
            fi
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    return 1
}

function uninstall() {
    info "Uninstalling Model Gateway..."
    echo
    
    # Delete CustomResource
    info "Deleting ModelGateway CR..."
    if ${CLI_CMD} delete modelgateway modelgateway-cr -n "$INSTANCE_NAMESPACE" --ignore-not-found; then
        success "ModelGateway CR deleted"
    fi
    
    # Wait for resources to be cleaned up
    info "Waiting for resources to be cleaned up..."
    sleep 30
    
    # Delete Model Gateway secrets
    info "Deleting Model Gateway secrets..."
    local secrets_deleted=0
    
    # Delete postgres external secret (only relevant for external postgres deployments)
    if [ "$DEPLOY_INTERNAL_POSTGRES" != "true" ]; then
        if ${CLI_CMD} get secret model-gateway-postgres-external-secret -n "$INSTANCE_NAMESPACE" &> /dev/null; then
            if ${CLI_CMD} delete secret model-gateway-postgres-external-secret -n "$INSTANCE_NAMESPACE" --ignore-not-found; then
                success "Deleted secret: model-gateway-postgres-external-secret"
                secrets_deleted=$((secrets_deleted + 1))
            fi
        fi
    fi
    
    # Delete provider secret
    if ${CLI_CMD} get secret model-gateway-provider-secret -n "$INSTANCE_NAMESPACE" &> /dev/null; then
        if ${CLI_CMD} delete secret model-gateway-provider-secret -n "$INSTANCE_NAMESPACE" --ignore-not-found; then
            success "Deleted secret: model-gateway-provider-secret"
            secrets_deleted=$((secrets_deleted + 1))
        fi
    fi
    
    if [ $secrets_deleted -eq 0 ]; then
        info "No Model Gateway secrets found to delete"
    fi
    echo
    
    # Uninstall operator
    info "Uninstalling operator..."
    
    # Try to find the Helm release in both namespaces
    local operator_uninstalled=false
    
    # First try operator namespace
    if helm list -n "$OPERATOR_NAMESPACE" 2>/dev/null | grep -q "model-gateway-operator"; then
        if helm uninstall model-gateway-operator -n "$OPERATOR_NAMESPACE"; then
            success "Operator uninstalled from namespace: $OPERATOR_NAMESPACE"
            operator_uninstalled=true
        fi
    # Then try instance namespace
    elif helm list -n "$INSTANCE_NAMESPACE" 2>/dev/null | grep -q "model-gateway-operator"; then
        if helm uninstall model-gateway-operator -n "$INSTANCE_NAMESPACE"; then
            success "Operator uninstalled from namespace: $INSTANCE_NAMESPACE"
            operator_uninstalled=true
        fi
    fi
    
    if [ "$operator_uninstalled" = false ]; then
        warning "Operator Helm release not found in either namespace"
    fi
    
    # Uninstall CRD
    info "Uninstalling CRD..."
    if helm uninstall model-gateway-crd &> /dev/null; then
        success "CRD uninstalled"
    else
        warning "CRD not found or already uninstalled"
    fi
    
    echo
    success "Model Gateway uninstalled successfully"
    return 0
}

function deploy() {
    info "Starting Model Gateway deployment..."
    echo
    
    # Verify prerequisites
    if ! verify_prerequisites; then
        error "Prerequisites verification failed. Please fix the issues and try again."
        return 1
    fi
    
    echo
    
    # Configure TLS certificates if --use-custom-tls flag was used
    if [ "$USE_CUSTOM_TLS_ARG" = "true" ]; then
        if ! prompt_tls_configuration; then
            error "TLS configuration failed"
            return 1
        fi
        
        if ! validate_tls_configuration; then
            error "TLS validation failed"
            return 1
        fi
        echo
    fi
    
    info "Installing Model Gateway..."
    echo
    
    # Install CRD
    if ! install_crd; then
        error "Failed to install CRD"
        return 1
    fi
    
    echo
    
    # Install operator
    if ! install_operator; then
        error "Failed to install operator"
        return 1
    fi
    
    echo
    
    # Wait for operator
    if ! wait_for_operator; then
        error "Operator failed to become ready"
        return 1
    fi
    
    echo
    
    # Wait for deployment
    if ! wait_for_deployment; then
        error "Deployment failed to complete"
        return 1
    fi
    
    echo
    
    # Verify deployment
    verify_deployment
    
    echo
    success "Model Gateway deployment completed successfully!"
    echo
    info "Next steps:"
    info "  1. Verify all pods are running: ${CLI_CMD} get pods -n $INSTANCE_NAMESPACE | grep model"
    info "  2. Check Model Gateway status: ${CLI_CMD} get modelgateway -n $INSTANCE_NAMESPACE"
    info "  3. Access Model Gateway service: ${CLI_CMD} get svc model-gateway-service -n $INSTANCE_NAMESPACE"
    echo
}

function parse_arguments() {
    local verify_only=false
    local uninstall_mode=false
    local configure_providers=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -o|--operator-namespace)
                shift
                OPERATOR_NAMESPACE="$1"
                ;;
            -n|--instance-namespace)
                shift
                INSTANCE_NAMESPACE="$1"
                ;;
            -s|--scale-config)
                shift
                SCALE_CONFIG="$1"
                if [[ ! "$SCALE_CONFIG" =~ ^(small|medium|large)$ ]]; then
                    error "Invalid scale config: $SCALE_CONFIG"
                    error "Valid options: small, medium, large"
                    exit 1
                fi
                ;;
            -b|--block-storage-class)
                shift
                STORAGE_CLASS_BLOCK="$1"
                ;;
            -f|--file-storage-class)
                shift
                STORAGE_CLASS_FILE="$1"
                ;;
            -v|--storage-vendor)
                shift
                STORAGE_VENDOR="$1"
                if [[ ! "$STORAGE_VENDOR" =~ ^(ocs|portworx)$ ]]; then
                    error "Invalid storage vendor: $STORAGE_VENDOR"
                    error "Valid options: ocs, portworx"
                    exit 1
                fi
                ;;
            -p|--pull-secret)
                shift
                IMAGE_PULL_SECRET="$1"
                ;;
            -r|--registry)
                shift
                IMAGE_REGISTRY="$1"
                ;;
            -l|--license)
                shift
                LICENSE_TYPE="$1"
                if [[ ! "$LICENSE_TYPE" =~ ^(Enterprise|Standard)$ ]]; then
                    error "Invalid license type: $LICENSE_TYPE"
                    error "Valid options: Enterprise, Standard"
                    exit 1
                fi
                ;;
            --accept-license)
                LICENSE_ACCEPT="true"
                ;;
            --lite-install)
                LITE_INSTALL="true"
                ;;
            --internal-postgres)
                DEPLOY_INTERNAL_POSTGRES="true"
                ;;
            --redis-channel)
                shift
                REDIS_OPERATOR_CHANNEL="$1"
                ;;
            --verify-only)
                verify_only=true
                ;;
            --use-custom-tls)
                USE_CUSTOM_TLS_ARG="true"
                ;;
            --custom-ca-secret)
                shift
                CUSTOM_CA_SECRET_ARG="$1"
                ;;
            --additional-ca-secrets)
                shift
                ADDITIONAL_CA_SECRETS_ARG="$1"
                ;;
            --configure-providers)
                configure_providers=true
                ;;
            --uninstall)
                uninstall_mode=true
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    # Check that namespace is specified for all operations
    if [ -z "$INSTANCE_NAMESPACE" ]; then
        error "Namespace is required for all operations"
        error "Use -n or --instance-namespace flag to specify the namespace"
        error ""
        error "Examples:"
        error "  ./cp4a-model-gateway-deployment.sh --verify-only -n production"
        error "  ./cp4a-model-gateway-deployment.sh --accept-license -n production"
        error "  ./cp4a-model-gateway-deployment.sh --uninstall -n production"
        error "  ./cp4a-model-gateway-deployment.sh --configure-providers -n production"
        exit 1
    fi
    
    # Validate that --internal-postgres and --lite-install are mutually exclusive
    if [ "$DEPLOY_INTERNAL_POSTGRES" = "true" ] && [ "$LITE_INSTALL" = "true" ]; then
        error "--internal-postgres and --lite-install are mutually exclusive"
        error "Please use only one PostgreSQL option"
        exit 1
    fi
    
    # Validate that --custom-ca-secret is only used with --use-custom-tls
    if [ -n "$CUSTOM_CA_SECRET_ARG" ] && [ "$USE_CUSTOM_TLS_ARG" != "true" ]; then
        error "The --custom-ca-secret flag can only be used with --use-custom-tls"
        error "Please add --use-custom-tls flag when specifying a custom CA secret"
        exit 1
    fi
    
    # Validate that --additional-ca-secrets is only used with --use-custom-tls
    if [ -n "$ADDITIONAL_CA_SECRETS_ARG" ] && [ "$USE_CUSTOM_TLS_ARG" != "true" ]; then
        error "The --additional-ca-secrets flag can only be used with --use-custom-tls"
        error "Please add --use-custom-tls flag when specifying additional CA secrets"
        exit 1
    fi
    
    # If operator namespace not specified, set it to match instance namespace
    if [ -z "$OPERATOR_NAMESPACE" ]; then
        OPERATOR_NAMESPACE="$INSTANCE_NAMESPACE"
        info "Setting operator namespace to match instance namespace: $OPERATOR_NAMESPACE"
    fi
    
    # Execute based on mode
    if [ "$configure_providers" == "true" ]; then
        configure_provider_credentials
        exit $?
    elif [ "$verify_only" == "true" ]; then
        verify_prerequisites
        exit $?
    elif [ "$uninstall_mode" == "true" ]; then
        uninstall
        exit $?
    else
        # If only instance namespace is provided (no license), enter interactive mode
        if [ "$LICENSE_ACCEPT" != "true" ] && [ -z "$STORAGE_CLASS_BLOCK" ] && [ -z "$STORAGE_CLASS_FILE" ]; then
            interactive_mode
            deploy
            exit $?
        fi
        
        # Check license acceptance for deployment
        if [ "$LICENSE_ACCEPT" != "true" ]; then
            error "You must accept the license agreement to deploy Model Gateway"
            error "Use --accept-license flag to accept, or run with only -n flag for interactive mode"
            exit 1
        fi
        
        # Check storage classes for non-lite install
        if [ "$LITE_INSTALL" != "true" ]; then
            if [ -z "$STORAGE_CLASS_BLOCK" ] || [ -z "$STORAGE_CLASS_FILE" ]; then
                error "Block and file storage classes are required for production deployment"
                error "Use -b and -f flags to specify storage classes, or use --lite-install for dev/test"
                exit 1
            fi
        fi
        
        deploy
        exit $?
    fi
}

# Main execution
main() {
    printf "\n"
    title "IBM Model Gateway Operator Deployment"
    printf "\n"
    
    if [ $# -eq 0 ]; then
        # No arguments provided - require -n flag
        error "Instance namespace is required"
        error "Usage: $0 -n <namespace> [options]"
        error "Run with -h or --help for more information"
        exit 1
    fi
    
    parse_arguments "$@"
}

main "$@"

# Made with Bob
