#!/bin/bash

###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2024, 2026. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

################################################################################
# CP4BA EDB PostgreSQL to IBM CloudNativePG Migration Script
#
# This script automates the complete migration from EDB PostgreSQL 14 to
# IBM CloudNativePG PostgreSQL 16 for CP4BA deployments.
#
# IMPORTANT: This script is designed to be integrated with upgradeOperator mode.
# It should NOT be executed standalone. It is automatically invoked during:
#   ./cp4a-deployment.sh -m upgradeOperator -n <namespace>
#
# INTEGRATION APPROACH:
# - This script is sourced by cp4a-deployment.sh during upgradeOperator mode
# - Three wrapper functions are called sequentially for each migration phase:
#   1. execute_backup_phase(namespace, backup_dir, cr_kind)
#   2. execute_create_cluster_phase(namespace)
#   3. execute_restore_phase(namespace, backup_dir)
#
# - ConfigMap-based state tracking enables automatic resumption on failure
# - Each phase validates completion before proceeding to the next
# - Application scaling is handled automatically based on CR kind
#
# Prerequisites (handled by upgradeOperator mode):
# - kubectl/oc configured and connected to cluster
# - IBM CNPG operator catalog installed (v28.x)
# - Sufficient disk space for backups
# - CP4BA operators shut down
# - Applications scaled down based on CR kind (ICP4ACluster or Content)
#
# For detailed integration documentation, see: EDB_CNPG_MIGRATION_INTEGRATION.md
################################################################################


# Note: common.sh is already sourced by the calling script (cp4a-deployment.sh)
# This script uses common.sh messaging functions: info, warning, error, success, fail

# Default Configuration
OLD_CLUSTER="postgres-cp4ba"
NEW_CLUSTER="postgres-cp4ba"
BACKUP_DIR=""
CNPG_MANIFEST="${TEMP_FOLDER}/cnpg-cluster-postgres-cp4ba.yaml"
RESTORE_DIR="/var/lib/postgresql/data/restore"
CR_KIND=""  # Top-level CR kind (icp4acluster or content)

# EDB Cluster Configuration (extracted before deletion)
EDB_STORAGE_CLASS=""
EDB_STORAGE_SIZE="100Gi"
EDB_INSTANCES="1"
EDB_CPU_REQUESTS="1"
EDB_MEMORY_REQUESTS="2Gi"
EDB_CPU_LIMITS="2"
EDB_MEMORY_LIMITS="4Gi"

# Operation modes
BACKUP_ONLY=false
RESTORE_ONLY=false
CREATE_CLUSTER_ONLY=false
SKIP_CNPG_CREATION=false

# Database list will be dynamically discovered
DATABASES=()

# Timeout Configuration (in seconds)
# These can be overridden via environment variables for different environments
EDB_CLUSTER_DELETE_TIMEOUT="${EDB_CLUSTER_DELETE_TIMEOUT:-120}"
PVC_DELETE_TIMEOUT="${PVC_DELETE_TIMEOUT:-120}"
SERVICE_DELETE_TIMEOUT="${SERVICE_DELETE_TIMEOUT:-60}"

# CR Kind to Component Mapping
# Maps top-level CR kinds to their associated component CR kinds for deployment scaling
ICP4ACLUSTER_CR_KIND_MAPPING_LIST=("ICP4ACluster" "Content" "InsightsEngine" "ICP4AAutomationDecisionService" "WFPSRuntime" "WorkflowRuntime" "ICP4ADocumentProcessingEngine")
CONTENT_CR_KIND_MAPPING_LIST=("Content" "Foundation" "InsightsEngine")

################################################################################
# Helper Functions
# These functions use common.sh messaging functions for consistency

################################################################################
# EDB to CNPG Migration ConfigMap Management Functions
# These functions manage the migration state using a ConfigMap to track progress
# across the three phases: backup, create-cluster, and restore
#
# CALLED FROM: cp4a-deployment.sh (upgradeOperator mode only)
# NOTE: This script is ONLY sourced by cp4a-deployment.sh
################################################################################

################################################################################
# Function: create_edb_cnpg_migration_configmap
# Purpose: Creates the ${EDB_CNPG_MIGRATION_CM_NAME} ConfigMap with initial state (all phases set to false)
#          and stores the CP4BA CSV version for validation during upgradeDeployment
# Parameters:
#   $1 - namespace: The namespace where the ConfigMap should be created
# Returns: 0 on success, 1 on failure
# Called from: cp4a-deployment.sh (upgradeOperator mode)
################################################################################
function create_edb_cnpg_migration_configmap() {
    local namespace=$1
    
    if [[ -z "$namespace" ]]; then
        fail "Namespace parameter is required for create_edb_cnpg_migration_configmap"
        return 1
    fi
    
    info "Creating ${EDB_CNPG_MIGRATION_CM_NAME} ConfigMap in namespace: $namespace"
    
    # Create ConfigMap with all migration phases set to false and store CP4BA CSV version
    cat <<EOF | ${CLI_CMD} apply -f - >&3 2>&3
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${EDB_CNPG_MIGRATION_CM_NAME}
  namespace: $namespace
  labels:
    app: cp4ba
    migration: edb-to-cnpg
data:
  backup-completed: "false"
  create-cluster-completed: "false"
  restore-completed: "false"
  backup-directory: ""
  cp4ba-csv-version: "$CP4BA_CSV_VERSION"
  upgradeOperator-completed: "true"
  cm-valid: "true"
EOF
    
    if [[ $? -eq 0 ]]; then
        success "Created ${EDB_CNPG_MIGRATION_CM_NAME} ConfigMap successfully"
        return 0
    else
        fail "Failed to create ${EDB_CNPG_MIGRATION_CM_NAME} ConfigMap"
        return 1
    fi
}

################################################################################
# Function: get_migration_phase_status
# Purpose: Retrieves the status of a specific migration phase from the ConfigMap
# Parameters:
#   $1 - namespace: The namespace where the ConfigMap exists
#   $2 - phase: The phase to check (backup-completed, create-cluster-completed, restore-completed)
# Returns: Echoes "true" or "false", returns 0 on success, 1 on failure
# Called from: cp4a-deployment.sh (upgradeOperator, upgradeOperatorStatus, upgradeDeployment modes)
################################################################################
function get_migration_phase_status() {
    local namespace=$1
    local phase=$2
    
    if [[ -z "$namespace" ]] || [[ -z "$phase" ]]; then
        fail "Both namespace and phase parameters are required for get_migration_phase_status"
        return 1
    fi
    
    # Check if ConfigMap exists
    if ! ${CLI_CMD} get configmap ${EDB_CNPG_MIGRATION_CM_NAME} -n $namespace >&3 2>&3; then
        echo "false"
        return 0
    fi
    
    # Get the phase status
    local status=$(${CLI_CMD} get configmap ${EDB_CNPG_MIGRATION_CM_NAME} -n $namespace -o jsonpath="{.data.$phase}" 2>/dev/null || echo "false")
    echo "$status"
    return 0
}

################################################################################
# Function: update_migration_phase_status
# Purpose: Updates the status of a specific migration phase in the ConfigMap
# Parameters:
#   $1 - namespace: The namespace where the ConfigMap exists
#   $2 - phase: The phase to update (backup-completed, create-cluster-completed, restore-completed)
#   $3 - status: The status to set (true or false)
# Returns: 0 on success, 1 on failure
# Called from: cp4a-deployment.sh (upgradeOperator mode)
################################################################################
function update_migration_phase_status() {
    local namespace=$1
    local phase=$2
    local status=$3
    
    if [[ -z "$namespace" ]] || [[ -z "$phase" ]] || [[ -z "$status" ]]; then
        fail "All parameters (namespace, phase, status) are required for update_migration_phase_status"
        return 1
    fi
    
    # Validate status value
    if [[ "$status" != "true" ]] && [[ "$status" != "false" ]]; then
        fail "Status must be 'true' or 'false', got: $status"
        return 1
    fi
    
    info "Updating migration phase '$phase' to '$status' in namespace: $namespace"
    
    # Update the ConfigMap
    ${CLI_CMD} patch configmap ${EDB_CNPG_MIGRATION_CM_NAME} -n $namespace \
        --type merge \
        -p "{\"data\":{\"$phase\":\"$status\",\"$phase-timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}}" >&3 2>&3
    
    if [[ $? -eq 0 ]]; then
        success "Updated migration phase '$phase' to '$status'"
        return 0
    else
        fail "Failed to update migration phase '$phase'"
        return 1
    fi
}

################################################################################
# Function: check_migration_configmap_exists
# Purpose: Checks if the ${EDB_CNPG_MIGRATION_CM_NAME} ConfigMap exists
# Parameters:
#   $1 - namespace: The namespace to check
# Returns: 0 if exists, 1 if not exists
# Called from: cp4a-deployment.sh (upgradeOperator, upgradeOperatorStatus, upgradeDeployment modes)
################################################################################
function check_migration_configmap_exists() {
    local namespace=$1
    
    if [[ -z "$namespace" ]]; then
        fail "Namespace parameter is required for check_migration_configmap_exists"
        return 1
    fi
    
    ${CLI_CMD} get configmap ${EDB_CNPG_MIGRATION_CM_NAME} -n $namespace >&3 2>&3
    return $?
}

################################################################################
# Function: get_next_migration_phase
# Purpose: Determines the next migration phase that needs to be executed
# Parameters:
#   $1 - namespace: The namespace where the ConfigMap exists
#   $2 - variable name to store result (using nameref)
# Returns: 0 on success, 1 on failure
# Called from: cp4a-deployment.sh (upgradeOperator mode)
################################################################################
function get_next_migration_phase() {
    local namespace=$1
    local -n result_var=$2
    
    if [[ -z "$namespace" ]]; then
        fail "Namespace parameter is required for get_next_migration_phase"
        return 1
    fi
    
    # Check if ConfigMap exists, if not, start from backup
    if ! check_migration_configmap_exists "$namespace"; then
        result_var="backup"
        return 0
    fi
    
    # Check each phase in order
    local backup_status=$(get_migration_phase_status "$namespace" "backup-completed")
    local create_status=$(get_migration_phase_status "$namespace" "create-cluster-completed")
    local restore_status=$(get_migration_phase_status "$namespace" "restore-completed")
    
    if [[ "$backup_status" != "true" ]]; then
        result_var="backup"
    elif [[ "$create_status" != "true" ]]; then
        result_var="create-cluster"
    elif [[ "$restore_status" != "true" ]]; then
        result_var="restore"
    else
        result_var="completed"
    fi
    
    return 0
}

################################################################################
# Function: display_migration_status
# Purpose: Displays the current status of all migration phases
# Parameters:
#   $1 - namespace: The namespace where the ConfigMap exists
# Returns: 0 on success
# Called from: cp4a-deployment.sh (upgradeOperator, upgradeOperatorStatus, upgradeDeployment modes)
################################################################################
function display_migration_status() {
    local namespace=$1
    
    if [[ -z "$namespace" ]]; then
        fail "Namespace parameter is required for display_migration_status"
        return 1
    fi
    
    info "=== EDB to IBM CloudNativePG Migration Status ==="
    
    if ! check_migration_configmap_exists "$namespace"; then
        warning "Migration ConfigMap does not exist - migration not started"
        return 0
    fi
    
    local backup_status=$(get_migration_phase_status "$namespace" "backup-completed")
    local create_status=$(get_migration_phase_status "$namespace" "create-cluster-completed")
    local restore_status=$(get_migration_phase_status "$namespace" "restore-completed")
    local backup_dir=$(${CLI_CMD} get configmap ${EDB_CNPG_MIGRATION_CM_NAME} -n $namespace -o jsonpath="{.data.backup-directory}" 2>/dev/null || echo "")
    
    echo ""
    echo "  Phase Status:"
    
    if [[ "$backup_status" == "true" ]]; then
        echo "    ✓ Backup Phase: COMPLETED"
        if [[ -n "$backup_dir" ]]; then
            echo "      Backup Location: $backup_dir"
        fi
    else
        echo "    ○ Backup Phase: PENDING"
    fi
    
    if [[ "$create_status" == "true" ]]; then
        echo "    ✓ Create Cluster Phase: COMPLETED"
    elif [[ "$backup_status" == "true" ]]; then
        echo "    ○ Create Cluster Phase: READY TO START"
    else
        echo "    ○ Create Cluster Phase: WAITING (backup must complete first)"
    fi
    
    if [[ "$restore_status" == "true" ]]; then
        echo "    ✓ Restore Phase: COMPLETED"
    elif [[ "$create_status" == "true" ]]; then
        echo "    ○ Restore Phase: READY TO START"
    else
        echo "    ○ Restore Phase: WAITING (create-cluster must complete first)"
    fi
    
    echo ""
    
    return 0
}

################################################################################
# Function: validate_edb_migration_completed
# Purpose: Validates that EDB to CNPG migration has been completed successfully
#          Always displays migration status, shows retry steps only if incomplete
# Parameters:
#   $1 - namespace: The namespace to check
#   $2 - current_csv_version: Current CP4BA CSV version for comparison
#   $3 - upgraded_csv_version: Target CP4BA CSV version for upgrade
# Returns: 0 if migration is complete and valid, 1 if not complete or invalid
# Called from: cp4a-deployment.sh (upgradeOperatorStatus, upgradeDeployment modes)
# NOTE: Requires messages.sh to be sourced by caller for displayEdbMigrationRetryMessage()
################################################################################
function validate_edb_migration_completed() {
    local namespace=$1
    local current_csv_version=$2
    local upgraded_csv_version=$3
    
    # EDB is detected, check if migration ConfigMap exists
    if ! check_migration_configmap_exists "$namespace"; then
        warning "EDB PostgreSQL detected but migration has not been started"
        echo ""
        
        # Display retry message for not-started case (messages.sh sourced at mode level)
        displayEdbMigrationRetryMessage "not-started" "$namespace" "$current_csv_version"
        
        return 1
    fi
    
    # Check CSV version and cm-valid flag - both must be correct for ConfigMap to be valid
    local cm_csv_version=$(${CLI_CMD} get configmap ${EDB_CNPG_MIGRATION_CM_NAME} -n $namespace -o jsonpath="{.data.cp4ba-csv-version}" 2>/dev/null || echo "")
    local cm_valid_flag=$(${CLI_CMD} get configmap ${EDB_CNPG_MIGRATION_CM_NAME} -n $namespace -o jsonpath="{.data.cm-valid}" 2>/dev/null || echo "")
    
    # Check if CSV version is missing or doesn't match
    if [[ -z "$cm_csv_version" ]]; then
        info "Migration ConfigMap does not contain cp4ba-csv-version field - may be from older version"
        info "ConfigMap is redundant, proceeding with upgrade..."
        return 0
    elif [[ "$cm_csv_version" != "$upgraded_csv_version" ]]; then
        info "Migration ConfigMap CSV version ($cm_csv_version) does not match current version ($upgraded_csv_version)"
        info "ConfigMap is from a previous version and is redundant, proceeding with upgrade..."
        return 0
    fi
    
    # Check if cm-valid flag is not "true" - ConfigMap is invalid
    if [[ "$cm_valid_flag" != "true" ]]; then
        info "Migration ConfigMap cm-valid flag is not 'true' (current value: '$cm_valid_flag')"
        info "ConfigMap is invalid or from a completed previous migration, proceeding with upgrade..."
        return 0
    fi
    
    # Check all phases are completed
    local backup_status=$(get_migration_phase_status "$namespace" "backup-completed")
    local create_status=$(get_migration_phase_status "$namespace" "create-cluster-completed")
    local restore_status=$(get_migration_phase_status "$namespace" "restore-completed")
    
    # ALWAYS display migration status table
    echo ""
    display_migration_status "$namespace"
    echo ""
    
    # Determine which phase is incomplete
    local incomplete_phase=""
    if [[ "$backup_status" != "true" ]]; then
        incomplete_phase="backup"
    elif [[ "$create_status" != "true" ]]; then
        incomplete_phase="create-cluster"
    elif [[ "$restore_status" != "true" ]]; then
        incomplete_phase="restore"
    fi
    
    # If migration is incomplete, display retry steps
    if [[ -n "$incomplete_phase" ]]; then
        warning "EDB to IBM CloudNativePG migration is incomplete"
        
        # Display retry message (messages.sh sourced at mode level)
        displayEdbMigrationRetryMessage "$incomplete_phase" "$namespace" "$current_csv_version"
        
        return 1
    fi
    
    # All validations passed - migration is complete
    success "EDB to IBM CloudNativePG migration validation passed - all phases completed"
    
    return 0
}

################################################################################
# Function: handle_edb_migration_process
# Purpose: Orchestrates the complete EDB to CNPG migration process
#          Loops through all phases until completion or failure
# Parameters:
#   $1 - namespace: The namespace where migration should occur
#   $2 - cr_kind: The CR kind (ICP4ACluster or Content) for deployment scaling
# Returns: 0 on success (all phases complete), 1 on failure
# Called from: cp4a-deployment.sh (upgradeOperator mode)
################################################################################
function handle_edb_migration_process() {
    local services_namespace=$1
    local operator_namespace=$2
    local cr_kind=$3
    local next_phase=""
    
    info "EDB PostgreSQL detected in namespace: $services_namespace"
    info "Starting phased EDB to IBM CloudNativePG migration process..."
    printf "\n"
    
    # Display current migration status
    display_migration_status "$services_namespace"
    printf "\n"
    
    # Loop through all phases until completion
    while true; do
        # Determine the next phase to execute
        get_next_migration_phase "$services_namespace" next_phase
        
        if [[ "$next_phase" == "completed" ]]; then
            success "All EDB to IBM CloudNativePG migration phases have been completed!"
            info "Migration ConfigMap shows all phases are done."
            printf "\n"
            return 0
        fi
        
        info "Executing migration phase: $next_phase"
        printf "\n"
        
        # Execute phased migration with CR kind
        execute_phased_edb_migration "$services_namespace" "$operator_namespace" "$next_phase" "$cr_kind"
        
        # Display updated status after phase completion
        printf "\n"
        display_migration_status "$services_namespace"
        printf "\n"
    done
}

################################################################################
# Function: execute_phased_edb_migration
# Purpose: Executes a specific phase of the EDB to CNPG migration
#          This function orchestrates the phase execution and ConfigMap updates
# Parameters:
#   $1 - services_namespace: Namespace where EDB/CNPG clusters and databases exist
#   $2 - operator_namespace: Namespace where operator subscription/CSV are installed
#   $3 - phase: The phase to execute (backup, create-cluster, or restore)
#   $4 - cr_kind: The CR kind (ICP4ACluster or Content) for deployment scaling
# Returns: Exits with 0 on success, exits with 1 on failure
# Called from: handle_edb_migration_process() in upgradeOperator mode
# Note: services_namespace is used for all database operations, ConfigMaps, and clusters
#       operator_namespace is used only for operator subscription and CSV
################################################################################
function execute_phased_edb_migration() {
    local services_namespace=$1
    local operator_namespace=$2
    local phase=$3
    local cr_kind=$4
    
    if [[ -z "$services_namespace" ]] || [[ -z "$phase" ]]; then
        fail "Both namespace and phase parameters are required for execute_phased_edb_migration"
        exit 1
    fi
    
    if [[ -z "$cr_kind" ]]; then
        fail "CR kind parameter is required for execute_phased_edb_migration"
        exit 1
    fi
    
    # Validate phase parameter
    if [[ "$phase" != "backup" ]] && [[ "$phase" != "create-cluster" ]] && [[ "$phase" != "restore" ]]; then
        fail "Invalid phase: $phase. Must be one of: backup, create-cluster, restore"
        exit 1
    fi
    
    # Create ConfigMap if it doesn't exist
    if ! check_migration_configmap_exists "$services_namespace"; then
        info "Migration ConfigMap does not exist. Creating it now..."
        if ! create_edb_cnpg_migration_configmap "$services_namespace"; then
            fail "Failed to create migration ConfigMap"
            exit 1
        fi
    fi
    
    # Execute the appropriate phase by calling wrapper functions
    case "$phase" in
        backup)
            info "=========================================================================="
            info "EXECUTING MIGRATION PHASE 1: BACKUP"
            info "=========================================================================="
            
            # Create backup directory structure
            local migration_dir="${EDB_TO_CNPG_MIGRATION_FOLDER}/edb-to-cnpg-migration"
            local backups_dir="${migration_dir}/backups"
            local timestamp=$(date +%Y%m%d-%H%M%S)
            local backup_dir="${backups_dir}/backup-${timestamp}"
            
            info "Creating backup directory structure..."
            mkdir -p "$backup_dir" >&3 2>&3
            
            if [[ $? -ne 0 ]]; then
                fail "Failed to create backup directory: $backup_dir"
                exit 1
            fi
            
            success "Backup directory created: $backup_dir"
            
            info "This phase will:"
            info "  - Discover all databases in the EDB cluster"
            info "  - Backup all databases using pg_dump"
            info "  - Save backup metadata and validation data"
            info "  - Store backups in: $backup_dir"
            printf "\n"
            
            # Execute backup phase by calling wrapper function
            info "Executing backup phase function..."
            if execute_backup_phase "$services_namespace" "$operator_namespace" "$backup_dir" "$cr_kind"; then
                success "Backup phase completed successfully!"
                
                # Store backup directory path in ConfigMap
                info "Storing backup directory path in ConfigMap..."
                ${CLI_CMD} patch configmap ${EDB_CNPG_MIGRATION_CM_NAME} -n $services_namespace \
                    --type merge \
                    -p "{\"data\":{\"backup-directory\":\"$backup_dir\"}}" >&3 2>&3
                
                if [[ $? -eq 0 ]]; then
                    success "Backup directory path stored in ConfigMap"
                else
                    warning "Failed to store backup directory path, but backup was successful"
                    displayEdbMigrationRetryMessage "backup" "$services_namespace" "$cp4a_operator_csv_version"
                    exit 1
                fi
                
                # Update ConfigMap to mark backup as completed
                if update_migration_phase_status "$services_namespace" "backup-completed" "true"; then
                    success "Migration state updated: backup-completed = true"
                else
                    warning "Failed to update migration state, but backup was successful"
                fi
                
                printf "\n"
                info "=========================================================================="
                info "BACKUP PHASE COMPLETED"
                info "=========================================================================="
                info "Backup Location: $backup_dir"
                info "Next phase: create-cluster"
                info "The upgradeOperator will automatically continue to the next phase."
                printf "\n"
                
                return 0
            else
                fail "Backup phase failed"
                printf "\n"
                displayEdbMigrationRetryMessage "backup" "$services_namespace" "$cp4a_operator_csv_version"
                exit 1
            fi
            ;;
            
        create-cluster)
            info "=========================================================================="
            info "EXECUTING MIGRATION PHASE 2: CREATE IBM CloudNativePG CLUSTER"
            info "=========================================================================="
            info "This phase will:"
            info "  - Validate that backup phase is completed"
            info "  - Generate IBM CloudNativePG cluster manifest"
            info "  - Delete the old EDB cluster"
            info "  - Deploy the new IBM CloudNativePG cluster"
            info "  - Wait for the cluster to be ready"
            printf "\n"
            
            # Verify backup is completed
            local backup_status=$(get_migration_phase_status "$services_namespace" "backup-completed")
            if [[ "$backup_status" != "true" ]]; then
                fail "Cannot create cluster: backup phase not completed"
                error "Please complete the backup phase first by re-running upgradeOperator"
                exit 1
            fi
            
            # Execute create-cluster phase by calling wrapper function
            info "Executing create-cluster phase function..."
            if execute_create_cluster_phase "$services_namespace" "$operator_namespace"; then
                success "Create cluster phase completed successfully!"
                
                # Update ConfigMap to mark create-cluster as completed
                if update_migration_phase_status "$services_namespace" "create-cluster-completed" "true"; then
                    success "Migration state updated: create-cluster-completed = true"
                else
                    warning "Failed to update migration state, but cluster creation was successful"
                fi
                
                printf "\n"
                info "=========================================================================="
                info "CREATE CLUSTER PHASE COMPLETED"
                info "=========================================================================="
                info "Next phase: restore"
                info "The upgradeOperator will automatically continue to the next phase."
                printf "\n"
                
                return 0
            else
                fail "Create cluster phase failed in upgradeOperator mode"
                error "Phase: create-cluster"
                error "Services Namespace: $services_namespace"
                error "Operator Namespace: $operator_namespace"
                printf "\n"
                displayEdbMigrationRetryMessage "create-cluster" "$services_namespace" "$cp4a_operator_csv_version"
                exit 1
            fi
            ;;
            
        restore)
            info "=========================================================================="
            info "EXECUTING MIGRATION PHASE 3: RESTORE DATABASES"
            info "=========================================================================="
            info "This phase will:"
            info "  - Validate that create-cluster phase is completed"
            info "  - Restore all databases from backup to IBM CloudNativePG cluster"
            info "  - Validate data integrity"
            info "  - Compare pre/post migration statistics"
            printf "\n"
            
            # Verify create-cluster is completed
            local create_status=$(get_migration_phase_status "$services_namespace" "create-cluster-completed")
            if [[ "$create_status" != "true" ]]; then
                fail "Cannot restore: create-cluster phase not completed"
                error "Please complete the create-cluster phase first by re-running upgradeOperator"
                exit 1
            fi
            
            # Retrieve backup directory from ConfigMap
            local backup_dir=$(${CLI_CMD} get configmap ${EDB_CNPG_MIGRATION_CM_NAME} -n $services_namespace -o jsonpath="{.data.backup-directory}" 2>/dev/null || echo "")
            
            if [[ -z "$backup_dir" ]]; then
                fail "Cannot find backup directory path in ConfigMap"
                error "The backup-directory field is empty in the ${EDB_CNPG_MIGRATION_CM_NAME} ConfigMap"
                error "Please ensure the backup phase completed successfully"
                exit 1
            fi
            
            if [[ ! -d "$backup_dir" ]]; then
                fail "Backup directory does not exist: $backup_dir"
                error "The directory path stored in ConfigMap is invalid or has been deleted"
                error "Please verify the backup directory exists or re-run the backup phase"
                exit 1
            fi
            
            info "Using backup directory from ConfigMap: $backup_dir"
            printf "\n"
            
            # Execute restore phase by calling wrapper function
            info "Executing restore phase function..."
            if execute_restore_phase "$services_namespace" "$operator_namespace" "$backup_dir"; then
                success "Restore phase completed successfully!"
                
                # Update ConfigMap to mark restore as completed
                if update_migration_phase_status "$services_namespace" "restore-completed" "true"; then
                    success "Migration state updated: restore-completed = true"
                else
                    warning "Failed to update migration state, but restore was successful"
                fi
                
                printf "\n"
                success "=========================================================================="
                success "ALL MIGRATION PHASES COMPLETED SUCCESSFULLY!"
                success "=========================================================================="
                info "The EDB to IBM CloudNativePG migration is now complete."
                info "All databases have been migrated to IBM CloudNativePG."
                printf "\n"
                info "Migration Summary:"
                info "  ✓ Phase 1: Backup - COMPLETED"
                info "  ✓ Phase 2: Create Cluster - COMPLETED"
                info "  ✓ Phase 3: Restore - COMPLETED"
                info "  Backup Location: $backup_dir"
                printf "\n"
                info "You can now proceed with the CP4BA deployment upgrade."
                printf "\n"
                
                return 0
            else
                fail "Restore phase failed in upgradeOperator mode"
                error "Phase: restore"
                error "Services Namespace: $services_namespace"
                error "Operator Namespace: $operator_namespace"
                printf "\n"
                displayEdbMigrationRetryMessage "restore" "$services_namespace" "$cp4a_operator_csv_version"
                exit 1
            fi
            ;;
    esac
}

################################################################################

################################################################################
# Function: info
# Purpose: Wrapper for info() from common.sh - displays informational messages
# Parameters: $1 - message to display
################################################################################

################################################################################
# Function: discover_databases
# Purpose: Discovers all databases in the EDB cluster or loads from backup list
# Parameters: None (uses global variables)
# Global Variables:
#   - RESTORE_ONLY: If true, loads database list from backup directory
#   - BACKUP_DIR: Directory containing database_list.txt for restore mode
#   - OLD_CLUSTER: Name of the EDB cluster to query
#   - SERVICES_NAMESPACE: Kubernetes namespace where EDB cluster exists
#   - DATABASES: Array populated with discovered database names
# Returns: 0 on success, exits on error
################################################################################
function discover_databases() {
    info "=== DISCOVERING DATABASES ==="

    if [[ "$RESTORE_ONLY" = true ]] || [[ "$CREATE_CLUSTER_ONLY" = true ]]; then
        # Phase 2 (create-cluster) and Phase 3 (restore):
        # EDB is already deleted by this point — never attempt to contact it.
        # Read the authoritative database list written by the backup phase.
        if [[ ! -f "$BACKUP_DIR/database_list.txt" ]]; then
            error "Database list file not found in backup directory: $BACKUP_DIR/database_list.txt"
            exit 1
        fi
        info "Loading database list from backup..."
        # Use while-read (Bash 3.2+ safe) — mapfile/readarray require Bash 4+
        DATABASES=()
        while IFS= read -r _db; do
            [[ -n "$_db" ]] && DATABASES+=("$_db")
        done < "$BACKUP_DIR/database_list.txt"

        if [[ ${#DATABASES[@]} -eq 0 ]]; then
            error "Database list file is empty: $BACKUP_DIR/database_list.txt"
            exit 1
        fi
    else
        # Phase 1 (backup): EDB is alive — discover databases directly from the pod.
        info "Looking for EDB PostgreSQL pod..."

        # Try method 1: EDB operator labels (k8s.enterprisedb.io)
        local EDB_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE -l k8s.enterprisedb.io/cluster=$OLD_CLUSTER,role=primary -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

        # Try method 2: EDB-specific name-based search.
        # EDB pods are named <cluster>-<integer> (e.g. postgres-cp4ba-1).
        # IBM CloudNativePG pods share the same cluster-name prefix but have an
        # extra namespace-hash component appended:
        #   postgres-cp4ba-1-postgres-cp4ba-ns-dtf-qa-cp4ba-a-cv-5870937
        # The ERE below anchors the suffix to digits followed immediately by a
        # field separator (space/tab), so CNPG pods are never selected here.
        if [[ -z "$EDB_POD" ]]; then
            EDB_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE --no-headers | grep -E "^${OLD_CLUSTER}-[0-9]+[[:space:]]" | head -1 | awk '{print $1}')
        fi

        if [[ -z "$EDB_POD" ]]; then
            error "Could not find EDB PostgreSQL pod."
            error "Tried the following methods:"
            error "  1. Label: k8s.enterprisedb.io/cluster=$OLD_CLUSTER,role=primary"
            error "  2. Pod name pattern: $OLD_CLUSTER-<integer>"
            error ""
            error "Available pods in namespace $SERVICES_NAMESPACE:"
            ${CLI_CMD} get pods -n $SERVICES_NAMESPACE
            return 1
        fi

        info "Using EDB pod: $EDB_POD"

        # Get list of databases excluding system databases
        info "Querying databases from PostgreSQL instance..."
        # Use while-read to populate the array so that mixed-case names
        # (e.g. ADPGG_scy) are preserved exactly.  The previous approach
        # piped through xargs and used word-splitting ( DATABASES=($db_list) )
        # which loses case on some platforms and would corrupt any name that
        # contains spaces.  IFS= read -r works identically on Bash 3.2+
        # (macOS system Bash) and all Linux Bash versions; mapfile/readarray
        # require Bash 4+ and are absent on macOS by default.
        DATABASES=()
        while IFS= read -r _db; do
            [[ -n "$_db" ]] && DATABASES+=("$_db")
        done < <(${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- \
            psql -U postgres -t -A -c \
            "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres', 'rdsadmin') ORDER BY datname;" \
            2>/dev/null)

        if [[ ${#DATABASES[@]} -eq 0 ]]; then
            error "No databases found in the cluster."
            exit 1
        fi
    fi

    success "Discovered ${#DATABASES[@]} databases:"
    for db in "${DATABASES[@]}"; do
        info "  - $db"
    done

    echo ""
    info "These databases will be processed."
}

################################################################################
# Function: scale_down_applications
# Purpose: Scales down CP4BA applications before database migration
# Parameters: None (uses global variables)
# Global Variables:
#   - CR_KIND: Type of CP4BA CR (ICP4ACluster, Content, etc.)
#   - NAMESPACE: Kubernetes namespace
#   - CLI_CMD: kubectl or oc command
# Returns: 0 on success, 1 on error
# Note: Scales deployments to 0 replicas to prevent database access during migration
################################################################################
function scale_down_applications() {
    info "=== PHASE: SCALING DOWN APPLICATIONS ==="
    
    # Validate CR_KIND is provided
    if [[ -z "$CR_KIND" ]]; then
        error "CR kind not provided. Cannot determine which deployments to scale down."
        error "This parameter should be passed automatically when called from upgradeOperator mode."
        exit 1
    fi
    
    # Convert CR_KIND to lowercase for comparison
    local cr_kind_lower=$(echo "$CR_KIND" | tr '[:upper:]' '[:lower:]')
    
    # Determine which CR kinds to check based on top-level CR kind
    local cr_kinds_to_check=()
    if [[ "$cr_kind_lower" == "icp4acluster" ]]; then
        cr_kinds_to_check=("${ICP4ACLUSTER_CR_KIND_MAPPING_LIST[@]}")
        info "Top-level CR kind: ICP4ACluster"
        info "Will scale down deployments owned by: ${ICP4ACLUSTER_CR_KIND_MAPPING_LIST[*]}"
    elif [[ "$cr_kind_lower" == "content" ]]; then
        cr_kinds_to_check=("${CONTENT_CR_KIND_MAPPING_LIST[@]}")
        info "Top-level CR kind: Content"
        info "Will scale down deployments owned by: ${CONTENT_CR_KIND_MAPPING_LIST[*]}"
    else
        error "Unknown CR kind: $CR_KIND"
        error "Expected 'ICP4ACluster' or 'Content'"
        exit 1
    fi
    
    echo ""
    info "Discovering deployments to scale down..."
    
    # Get all deployments in the namespace
    local all_deployments=$(${CLI_CMD} get deployments -n $SERVICES_NAMESPACE -o json 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$all_deployments" ]]; then
        warning "No deployments found in namespace $SERVICES_NAMESPACE"
        return 0
    fi
    
    # Array to store deployments to scale down
    local deployments_to_scale=()
    
    # Iterate through each deployment and check owner references
    while IFS= read -r deployment_name; do
        # Skip empty lines
        [[ -z "$deployment_name" ]] && continue
        
        # Get owner references for this deployment
        local owner_refs=$(${CLI_CMD} get deployment "$deployment_name" -n $SERVICES_NAMESPACE -o jsonpath='{.metadata.ownerReferences[*].kind}' 2>/dev/null)
        
        if [[ -z "$owner_refs" ]]; then
            continue
        fi
        
        # Check if any owner reference matches our CR kinds
        local should_scale=false
        for cr_kind in "${cr_kinds_to_check[@]}"; do
            if echo "$owner_refs" | grep -q "$cr_kind"; then
                should_scale=true
                break
            fi
        done
        
        if [[ "$should_scale" = true ]]; then
            # Exclude operators and database pods
            if [[ ! "$deployment_name" =~ -operator$ ]] && \
               [[ ! "$deployment_name" =~ ^postgres ]] && \
               [[ ! "$deployment_name" =~ ^edb ]] && \
               [[ ! "$deployment_name" =~ ^ibm-pg-operator ]]; then
                deployments_to_scale+=("$deployment_name")
            fi
        fi
    done < <(echo "$all_deployments" | jq -r '.items[].metadata.name' 2>/dev/null)
    
    # Display deployments to be scaled down
    if [[ ${#deployments_to_scale[@]} -eq 0 ]]; then
        info "No deployments found to scale down"
        return 0
    fi
    
    echo ""
    info "Found ${#deployments_to_scale[@]} deployment(s) to scale down:"
    for dep in "${deployments_to_scale[@]}"; do
        local current_replicas=$(${CLI_CMD} get deployment "$dep" -n $SERVICES_NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null)
        info "  - $dep (current replicas: $current_replicas)"
    done
    
    echo ""
    warning "These deployments will be scaled down to 0 replicas."
    warning "This is necessary to ensure no active database connections during migration."
    echo ""
    
    if [[ "$SKIP_FOR_API" != "true" ]]; then
        prompt_press_any_key_to_continue
    fi
    
    echo ""
    info "Scaling down deployments..."
    
    # Scale down each deployment
    local scaled_count=0
    local failed_count=0
    
    for dep in "${deployments_to_scale[@]}"; do
        info "Scaling down: $dep"
        if ${CLI_CMD} scale deployment "$dep" -n $SERVICES_NAMESPACE --replicas=0 >&3 2>&3; then
            scaled_count=$((scaled_count + 1))
            success "  ✓ Scaled down: $dep"
        else
            failed_count=$((failed_count + 1))
            error "  ✗ Failed to scale down: $dep"
        fi
    done
    
    echo ""
    if [[ $failed_count -eq 0 ]]; then
        success "Successfully scaled down $scaled_count deployment(s)"
    else
        warning "Scaled down $scaled_count deployment(s), $failed_count failed"
    fi
    
    # Wait for pods to terminate
    echo ""
    info "Waiting for pods to terminate..."
    sleep 5
    
    local max_wait=300  # 5 minutes
    local elapsed=0
    local check_interval=10
    
    while [[ $elapsed -lt $max_wait ]]; do
        running_pods=0
        for dep in "${deployments_to_scale[@]}"; do
            pod_count=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE -l app="$dep" --field-selector=status.phase=Running 2>/dev/null | grep -c "$dep" || echo "0")
            pod_count=$(echo "$pod_count" | tr -d '\n' | tr -d ' ')
            running_pods=$((running_pods + ${pod_count:-0}))
        done
        
        if [[ $running_pods -eq 0 ]]; then
            success "All pods have terminated"
            break
        fi
        
        info "Waiting for $running_pods pod(s) to terminate... (${elapsed}s/${max_wait}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    if [[ $elapsed -ge $max_wait ]]; then
        warning "Timeout waiting for all pods to terminate"
        warning "Some pods may still be running. Please verify manually."
    fi
    
    echo ""
    success "Scale down phase completed"
}

################################################################################
# Function: backup_databases
# Purpose: Backs up all discovered databases from EDB cluster using pg_dump
# Parameters: None (uses global variables)
# Global Variables:
#   - BACKUP_DIR: Directory to store backup files
#   - DATABASES: Array of database names to backup
#   - OLD_CLUSTER: Name of the EDB cluster
################################################################################
# Function: validate_database_pre_backup
# Purpose: Validates database before backup by collecting table counts and row estimates
# Parameters:
#   $1 - pod: EDB pod name
#   $2 - db: Database name to validate
# Global Variables:
#   - NAMESPACE: Kubernetes namespace
#   - BACKUP_DIR: Directory to store validation file
#   - CLI_CMD: kubectl or oc command
# Returns: 0 (always succeeds)
# Note: Saves validation data to pre_backup_validation.txt for later comparison
#       with post-restore data
################################################################################
function validate_database_pre_backup() {
    local pod=$1
    local db=$2
    
    info "Validating database before backup: $db"
    
    # Force fresh statistics so n_live_tup is accurate
    info "  Updating database statistics (ANALYZE)..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $pod -- psql -U postgres -d "dbname='$db'" -c "ANALYZE;" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        info "  ✓ Statistics updated"
    else
        warning "  ⚠ Failed to update statistics, row estimates may be inaccurate"
    fi
    
    # Get table count
    local table_count=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $pod -- psql -U postgres -d "dbname='$db'" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema');" 2>/dev/null | xargs)
    
    # Get row count estimate (n_live_tup from pg_stat_user_tables - now fresh after ANALYZE)
    local row_estimate=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $pod -- psql -U postgres -d "dbname='$db'" -t -c "SELECT SUM(n_live_tup) FROM pg_stat_user_tables;" 2>/dev/null | xargs)
    
    # Get database size
    local db_size=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $pod -- psql -U postgres -d "dbname='$db'" -t -c "SELECT pg_size_pretty(pg_database_size(\$\$${db}\$\$));" 2>/dev/null | xargs)
    
    # Save validation data
    echo "$db|$table_count|$row_estimate|$db_size" >> "$BACKUP_DIR/pre_backup_validation.txt"
    
    info "  Tables: $table_count, Estimated Rows: $row_estimate (from fresh statistics), Size: $db_size"
}

################################################################################
# Function: snapshot_edb_databases
# Purpose:  Captures a detailed forensic snapshot of every database on the EDB
#           cluster BEFORE the migration backup begins.  The snapshot is written
#           to $BACKUP_DIR/snapshot/ and is NEVER altered after this point.
#           After restore, compare_snapshot_post_restore() diffs every dimension
#           against the CNPG cluster to surface any regression.
#
#           Dimensions captured per database:
#             roles.txt          - all roles and their attributes
#             db_acl.txt         - database-level ACLs (CONNECT, TEMP, CREATE)
#             schemas.txt        - schema names, owner, ACL
#             tables.txt         - table name, schema, owner, estimated row count
#             columns.txt        - column name, type, nullable, default (schema ordered)
#             indexes.txt        - index name, table, type, unique flag
#             sequences.txt      - sequence name, schema, start/min/max/increment
#             row_counts.txt     - exact row count per table (SELECT COUNT(*))
#             schema_acl.txt     - GRANT ON SCHEMA lines (mirrors schema_grants.sql)
#             table_acl.txt      - GRANT ON TABLE lines for non-system tables
#             extensions.txt     - installed extensions
#
# Parameters: None (uses DATABASES[], SERVICES_NAMESPACE, BACKUP_DIR, CLI_CMD)
# Returns: 0 on success (non-fatal — snapshot failure does not abort migration)
################################################################################
function snapshot_edb_databases() {
    info "=== PHASE: PRE-MIGRATION FORENSIC SNAPSHOT ==="
    info "Capturing detailed database snapshot for post-restore comparison..."

    local SNAP_DIR="$BACKUP_DIR/snapshot"
    mkdir -p "$SNAP_DIR"

    # ── Locate EDB pod (same two-method fallback used by backup_databases) ──
    local EDB_POD
    EDB_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE \
        -l k8s.enterprisedb.io/cluster=$OLD_CLUSTER,role=primary \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -z "$EDB_POD" ]]; then
        EDB_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE --no-headers \
            | grep -E "^${OLD_CLUSTER}-[0-9]+[[:space:]]" | head -1 | awk '{print $1}')
    fi

    if [[ -z "$EDB_POD" ]]; then
        warning "Could not find EDB pod for snapshot — skipping forensic snapshot."
        return 0
    fi

    info "Using EDB pod for snapshot: $EDB_POD"

    # ── 1. Cluster-level: roles ──────────────────────────────────────────────
    info "  Capturing roles..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -t -A -c \
        "SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb,
                rolcanlogin, rolreplication, rolconnlimit, rolvaliduntil,
                rolbypassrls
         FROM pg_roles
         WHERE rolname NOT LIKE 'pg_%'
           AND rolname NOT IN ('rdsadmin','rdsrepladmin','rds_superuser')
         ORDER BY rolname;" \
        > "$SNAP_DIR/roles.txt" 2>/dev/null || true

    # ── 2. Cluster-level: pg_hba / connection info (informational) ───────────
    info "  Capturing PostgreSQL version..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -t -A -c \
        "SELECT version();" > "$SNAP_DIR/pg_version.txt" 2>/dev/null || true

    # ── Per-database snapshots ────────────────────────────────────────────────
    for db in "${DATABASES[@]}"; do
        info "  Snapshotting database: $db"
        local db_dir="$SNAP_DIR/$db"
        mkdir -p "$db_dir"

        # 2. Database-level ACL
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -t -A -c \
            "SELECT d.datname,
                    pg_catalog.pg_get_userbyid(d.datdba) AS owner,
                    (aclexplode(d.datacl)).privilege_type  AS priv,
                    pg_get_userbyid((aclexplode(d.datacl)).grantee) AS grantee
             FROM pg_database d
             WHERE d.datname = \$\$${db}\$\$
             ORDER BY priv, grantee;" \
            > "$db_dir/db_acl.txt" 2>/dev/null || true

        # 3. Schemas (name, owner, ACL string)
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -d "dbname='$db'" -t -A -c \
            "SELECT n.nspname,
                    pg_catalog.pg_get_userbyid(n.nspowner) AS owner,
                    n.nspacl::text
             FROM pg_namespace n
             WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY n.nspname;" \
            > "$db_dir/schemas.txt" 2>/dev/null || true

        # 4. Tables (schema, name, owner)
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -d "dbname='$db'" -t -A -c \
            "SELECT schemaname, tablename, tableowner
             FROM pg_tables
             WHERE schemaname NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY schemaname, tablename;" \
            > "$db_dir/tables.txt" 2>/dev/null || true

        # 5. Columns (schema, table, column, type, nullable, default)
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -d "dbname='$db'" -t -A -c \
            "SELECT c.table_schema, c.table_name, c.column_name,
                    c.data_type, c.is_nullable, c.column_default
             FROM information_schema.columns c
             WHERE c.table_schema NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY c.table_schema, c.table_name, c.ordinal_position;" \
            > "$db_dir/columns.txt" 2>/dev/null || true

        # 6. Indexes
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -d "dbname='$db'" -t -A -c \
            "SELECT schemaname, tablename, indexname, indexdef
             FROM pg_indexes
             WHERE schemaname NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY schemaname, tablename, indexname;" \
            > "$db_dir/indexes.txt" 2>/dev/null || true

        # 7. Sequences
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -d "dbname='$db'" -t -A -c \
            "SELECT sequence_schema, sequence_name, data_type,
                    start_value, minimum_value, maximum_value, increment
             FROM information_schema.sequences
             WHERE sequence_schema NOT IN ('pg_catalog','information_schema')
             ORDER BY sequence_schema, sequence_name;" \
            > "$db_dir/sequences.txt" 2>/dev/null || true

        # 8. Exact row counts per table (slow but exact — run last per db)
        info "    Counting rows in $db (exact counts)..."
        local table_list
        table_list=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres \
            -d "dbname='$db'" -t -A -c \
            "SELECT schemaname || '.' || tablename
             FROM pg_tables
             WHERE schemaname NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY schemaname, tablename;" 2>/dev/null)
        > "$db_dir/row_counts.txt"
        while IFS= read -r qualified_table; do
            [[ -z "$qualified_table" ]] && continue
            local cnt
            cnt=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres \
                -d "dbname='$db'" -t -A \
                -c "SELECT COUNT(*) FROM \"$(echo "$qualified_table" | cut -d. -f1)\".\"$(echo "$qualified_table" | cut -d. -f2)\";" \
                2>/dev/null | xargs)
            # Normalise: if psql failed and returned empty, record 0 so the snapshot
            # never contains a bare "table|" entry that looks like a diff later.
            echo "${qualified_table}|${cnt:-0}" >> "$db_dir/row_counts.txt"
        done <<< "$table_list"

        # 9. Schema-level ACLs (mirrors schema_grants.sql — independent copy)
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -d "dbname='$db'" -t -A -c \
            "SELECT n.nspname AS schema,
                    pg_get_userbyid((aclexplode(n.nspacl)).grantee) AS grantee,
                    (aclexplode(n.nspacl)).privilege_type AS privilege
             FROM pg_namespace n
             WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
               AND n.nspacl IS NOT NULL
               AND (aclexplode(n.nspacl)).grantee != 0
             ORDER BY n.nspname,
                      pg_get_userbyid((aclexplode(n.nspacl)).grantee),
                      (aclexplode(n.nspacl)).privilege_type;" \
            > "$db_dir/schema_acl.txt" 2>/dev/null || true

        # 10. Table-level ACLs
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -d "dbname='$db'" -t -A -c \
            "SELECT schemaname, tablename,
                    grantee, privilege_type, is_grantable
             FROM information_schema.role_table_grants
             WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY schemaname, tablename, grantee, privilege_type;" \
            > "$db_dir/table_acl.txt" 2>/dev/null || true

        # 11. Extensions
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -d "dbname='$db'" -t -A -c \
            "SELECT extname, extversion
             FROM pg_extension
             ORDER BY extname;" \
            > "$db_dir/extensions.txt" 2>/dev/null || true

        success "  ✓ Snapshot complete for $db — saved to $db_dir/"
    done

    # Write a manifest listing all snapshot files for easy reference
    find "$SNAP_DIR" -type f | sort > "$SNAP_DIR/manifest.txt"

    success "Forensic snapshot saved to: $SNAP_DIR/"
    info "  Use compare_snapshot_post_restore() after migration to diff every dimension."
    echo ""
    return 0
}

################################################################################
# Function: compare_snapshot_post_restore
# Purpose:  Diffs the forensic snapshot captured by snapshot_edb_databases()
#           against the live CNPG cluster after restore.  Writes a diff report
#           to $BACKUP_DIR/snapshot/diff_report.txt and prints a summary.
#
#           Compares per database:
#             schemas     - any schema missing or extra after restore
#             tables      - any table missing or extra after restore
#             columns     - any column missing, extra, or changed type
#             indexes     - any index missing or extra
#             sequences   - any sequence missing
#             row_counts  - exact row count match per table
#             schema_acl  - schema-level privilege differences
#             table_acl   - table-level privilege differences
#
# Parameters: None (uses DATABASES[], SERVICES_NAMESPACE, BACKUP_DIR, CLI_CMD)
# Returns: 0 on success (non-fatal — diff failure does not abort restore)
################################################################################
function compare_snapshot_post_restore() {
    info "=== PHASE: POST-RESTORE SNAPSHOT COMPARISON ==="

    local SNAP_DIR="$BACKUP_DIR/snapshot"
    local REPORT="$SNAP_DIR/diff_report.txt"

    if [[ ! -d "$SNAP_DIR" ]]; then
        warning "No snapshot directory found at $SNAP_DIR — skipping comparison."
        warning "Was snapshot_edb_databases() run during the backup phase?"
        return 0
    fi

    # ── Locate CNPG pod ──────────────────────────────────────────────────────
    local CNPG_POD
    CNPG_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE --no-headers 2>/dev/null \
        | grep "^${NEW_CLUSTER}-1 " | awk '{print $1}')
    if [[ -z "$CNPG_POD" ]]; then
        CNPG_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE --no-headers 2>/dev/null \
            | grep "^${NEW_CLUSTER}-" | head -1 | awk '{print $1}')
    fi
    if [[ -z "$CNPG_POD" ]]; then
        warning "Could not find CNPG pod — skipping snapshot comparison."
        return 0
    fi

    info "Comparing EDB snapshot against CNPG cluster (pod: $CNPG_POD)..."
    info "Report will be written to: $REPORT"
    echo ""

    local overall_pass=0   # 0 = all OK, 1 = differences found

    {
        echo "================================================================"
        echo " CP4BA EDB → CNPG Migration — Snapshot Diff Report"
        echo " Generated: $(date)"
        echo " EDB snapshot: $SNAP_DIR"
        echo " CNPG pod:     $CNPG_POD"
        echo "================================================================"
        echo ""
    } > "$REPORT"

    for db in "${DATABASES[@]}"; do
        local db_dir="$SNAP_DIR/$db"
        local db_pass=0    # per-db pass flag

        {
            echo "----------------------------------------------------------------"
            echo " DATABASE: $db"
            echo "----------------------------------------------------------------"
        } >> "$REPORT"

        if [[ ! -d "$db_dir" ]]; then
            echo "  [WARN] No snapshot directory for $db — skipped." >> "$REPORT"
            warning "  No snapshot for $db — skipping"
            continue
        fi

        # ── Derive the database owner (needed for Step 3.5a normalisation) ──
        # Step 3.5a moves tables/types from 'public' into a schema named after
        # the database owner (e.g. 'adpuser').  We look it up from CNPG so we
        # can normalise the EDB snapshot before diffing.
        local db_owner
        db_owner=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres \
            -t -A -c "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname='${db}';" \
            2>/dev/null | xargs)
        # If owner is postgres (non-ADP db) treat as empty so normalisation is a no-op
        [[ "$db_owner" == "postgres" ]] && db_owner=""

        # Helper: query CNPG into a tmp file then diff
        local tmp_cnpg
        tmp_cnpg=$(mktemp)
        local tmp_edb_schemas tmp_cnpg_schemas
        tmp_edb_schemas=$(mktemp)
        tmp_cnpg_schemas=$(mktemp)

        # ── Schemas ─────────────────────────────────────────────────────────
        # Three known cosmetic differences between EDB PG14 and CNPG PG16 are
        # normalised before diffing so they do not trigger a false [DIFF]:
        #   1. PG16 changed the public schema owner from 'postgres' to the
        #      special role 'pg_database_owner' — replace it with 'postgres'
        #      on the CNPG side so the line matches the EDB snapshot.
        #   2. PG16 revoked CREATE from PUBLIC on the public schema.  This
        #      changes the ACL from '{postgres=UC/postgres,=UC/postgres}' to
        #      '{postgres=UC/postgres,=U/postgres}'.  Step 2.7 already re-grants
        #      the correct PG16 defaults; normalise by stripping 'C' from the
        #      PUBLIC grantee entry in the EDB snapshot so both sides read '=U/'.
        #   3. Step 3.5 creates a user-owned schema (db_owner) on CNPG that was
        #      absent on EDB for empty databases.  Strip it from both sides.
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres \
            -d "dbname='$db'" -t -A -c \
            "SELECT n.nspname,
                    pg_catalog.pg_get_userbyid(n.nspowner) AS owner,
                    n.nspacl::text
             FROM pg_namespace n
             WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY n.nspname;" > "$tmp_cnpg" 2>/dev/null || true

        # Normalise EDB snapshot:
        #   a) strip the user-owned schema row (step 3.5 adds it on CNPG)
        #   b) strip 'C' from the PUBLIC grantee in the ACL column so that
        #      the PUBLIC entry '=UC/postgres' becomes '=U/postgres' matching
        #      PG16 behaviour.  Anchor the pattern to the PUBLIC pseudo-role
        #      only (entries preceded by '{' or ',') so that named-role entries
        #      like 'postgres=UC/postgres' are left unchanged — the previous
        #      broad 's/=UC\//=U\//g' incorrectly stripped the postgres
        #      superuser's CREATE privilege and caused a false [DIFF] on every
        #      database even on a fully-successful migration.
        local _edb_strip_schema_pat
        [[ -n "$db_owner" ]] && _edb_strip_schema_pat="^${db_owner}|" || _edb_strip_schema_pat="^$"
        grep -v "$_edb_strip_schema_pat" "$db_dir/schemas.txt" 2>/dev/null \
            | sed 's/,=UC\//,=U\//g; s/{=UC\//{=U\//g' > "$tmp_edb_schemas" || true

        # Normalise CNPG output:
        #   a) replace 'pg_database_owner' with 'postgres' (PG16 cosmetic)
        #   b) strip the user-owned schema row (step 3.5 adds it)
        sed 's/pg_database_owner/postgres/g' "$tmp_cnpg" 2>/dev/null \
            | grep -v "$_edb_strip_schema_pat" > "$tmp_cnpg_schemas" || true

        if ! diff -u "$tmp_edb_schemas" "$tmp_cnpg_schemas" >> "$REPORT" 2>/dev/null; then
            echo "  [DIFF] schemas.txt has differences (see above)" >> "$REPORT"
            db_pass=1
        else
            echo "  [OK]   schemas match" >> "$REPORT"
        fi
        rm -f "$tmp_edb_schemas" "$tmp_cnpg_schemas"

        # ── Tables ──────────────────────────────────────────────────────────
        # Step 3.5a moves tables from 'public' into the owner schema on CNPG.
        # Normalise the EDB snapshot by replacing 'public' with db_owner in
        # the schemaname column so the two sides compare equal.
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres \
            -d "dbname='$db'" -t -A -c \
            "SELECT schemaname, tablename, tableowner
             FROM pg_tables
             WHERE schemaname NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY schemaname, tablename;" > "$tmp_cnpg" 2>/dev/null || true
        local tmp_edb_tables
        tmp_edb_tables=$(mktemp)
        if [[ -n "$db_owner" ]]; then
            sed "s/^public|/${db_owner}|/" "$db_dir/tables.txt" 2>/dev/null \
                | sort > "$tmp_edb_tables" || true
            sort "$tmp_cnpg" > "${tmp_cnpg}.sorted" && mv "${tmp_cnpg}.sorted" "$tmp_cnpg" || true
        else
            cp "$db_dir/tables.txt" "$tmp_edb_tables" 2>/dev/null || true
        fi
        if ! diff -u "$tmp_edb_tables" "$tmp_cnpg" >> "$REPORT" 2>/dev/null; then
            echo "  [DIFF] tables.txt has differences (see above)" >> "$REPORT"
            db_pass=1
        else
            echo "  [OK]   tables match" >> "$REPORT"
        fi
        rm -f "$tmp_edb_tables"

        # ── Columns ─────────────────────────────────────────────────────────
        # Same normalisation: replace 'public' schema with db_owner in EDB snapshot.
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres \
            -d "dbname='$db'" -t -A -c \
            "SELECT c.table_schema, c.table_name, c.column_name,
                    c.data_type, c.is_nullable, c.column_default
             FROM information_schema.columns c
             WHERE c.table_schema NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY c.table_schema, c.table_name, c.ordinal_position;" \
            > "$tmp_cnpg" 2>/dev/null || true
        local tmp_edb_cols
        tmp_edb_cols=$(mktemp)
        if [[ -n "$db_owner" ]]; then
            sed "s/^public|/${db_owner}|/" "$db_dir/columns.txt" 2>/dev/null \
                | sort > "$tmp_edb_cols" || true
            sort "$tmp_cnpg" > "${tmp_cnpg}.sorted" && mv "${tmp_cnpg}.sorted" "$tmp_cnpg" || true
        else
            cp "$db_dir/columns.txt" "$tmp_edb_cols" 2>/dev/null || true
        fi
        if ! diff -u "$tmp_edb_cols" "$tmp_cnpg" >> "$REPORT" 2>/dev/null; then
            echo "  [DIFF] columns.txt has differences (see above)" >> "$REPORT"
            db_pass=1
        else
            echo "  [OK]   columns match" >> "$REPORT"
        fi
        rm -f "$tmp_edb_cols"

        # ── Indexes ─────────────────────────────────────────────────────────
        # Same normalisation: replace 'public' schema with db_owner in EDB snapshot.
        # Also normalise the indexdef expression (which embeds the schema name).
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres \
            -d "dbname='$db'" -t -A -c \
            "SELECT schemaname, tablename, indexname, indexdef
             FROM pg_indexes
             WHERE schemaname NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY schemaname, tablename, indexname;" \
            > "$tmp_cnpg" 2>/dev/null || true
        local tmp_edb_idx
        tmp_edb_idx=$(mktemp)
        if [[ -n "$db_owner" ]]; then
            sed "s/^public|/${db_owner}|/; s/ ON public\./ ON ${db_owner}./g" \
                "$db_dir/indexes.txt" 2>/dev/null | sort > "$tmp_edb_idx" || true
            sort "$tmp_cnpg" > "${tmp_cnpg}.sorted" && mv "${tmp_cnpg}.sorted" "$tmp_cnpg" || true
        else
            cp "$db_dir/indexes.txt" "$tmp_edb_idx" 2>/dev/null || true
        fi
        if ! diff -u "$tmp_edb_idx" "$tmp_cnpg" >> "$REPORT" 2>/dev/null; then
            echo "  [DIFF] indexes.txt has differences (see above)" >> "$REPORT"
            db_pass=1
        else
            echo "  [OK]   indexes match" >> "$REPORT"
        fi
        rm -f "$tmp_edb_idx"

        # ── Sequences ───────────────────────────────────────────────────────
        # Same normalisation: replace 'public' schema with db_owner in EDB snapshot.
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres \
            -d "dbname='$db'" -t -A -c \
            "SELECT sequence_schema, sequence_name, data_type,
                    start_value, minimum_value, maximum_value, increment
             FROM information_schema.sequences
             WHERE sequence_schema NOT IN ('pg_catalog','information_schema')
             ORDER BY sequence_schema, sequence_name;" \
            > "$tmp_cnpg" 2>/dev/null || true
        local tmp_edb_seq
        tmp_edb_seq=$(mktemp)
        if [[ -n "$db_owner" ]]; then
            sed "s/^public|/${db_owner}|/" "$db_dir/sequences.txt" 2>/dev/null \
                | sort > "$tmp_edb_seq" || true
            sort "$tmp_cnpg" > "${tmp_cnpg}.sorted" && mv "${tmp_cnpg}.sorted" "$tmp_cnpg" || true
        else
            cp "$db_dir/sequences.txt" "$tmp_edb_seq" 2>/dev/null || true
        fi
        if ! diff -u "$tmp_edb_seq" "$tmp_cnpg" >> "$REPORT" 2>/dev/null; then
            echo "  [DIFF] sequences.txt has differences (see above)" >> "$REPORT"
            db_pass=1
        else
            echo "  [OK]   sequences match" >> "$REPORT"
        fi
        rm -f "$tmp_edb_seq"

        # ── Exact row counts ─────────────────────────────────────────────────
        # NOTE: The EDB snapshot captures table names under their EDB schema
        # (always 'public' for ADPGG_* databases). Step 3.5a moves those tables
        # into the owner schema (e.g. 'adpuser') on CNPG. To avoid a false [DIFF]
        # on schema name, normalise both sides by stripping the schema prefix and
        # comparing table name + row count only.
        info "  Counting rows in $db on CNPG (exact counts)..."
        local table_list_cnpg
        table_list_cnpg=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres \
            -d "dbname='$db'" -t -A -c \
            "SELECT schemaname || '.' || tablename
             FROM pg_tables
             WHERE schemaname NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY tablename;" 2>/dev/null)
        > "$tmp_cnpg"
        while IFS= read -r qualified_table; do
            [[ -z "$qualified_table" ]] && continue
            local cnt tblname
            cnt=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres \
                -d "dbname='$db'" -t -A \
                -c "SELECT COUNT(*) FROM \"$(echo "$qualified_table" | cut -d. -f1)\".\"$(echo "$qualified_table" | cut -d. -f2)\";" \
                2>/dev/null | xargs)
            # Normalise: strip schema prefix so 'adpuser.foo' and 'public.foo' both
            # compare as 'foo|<count>' against the EDB snapshot.
            # Use 0 if psql failed so we never write a bare "table|" entry.
            tblname=$(echo "$qualified_table" | cut -d. -f2)
            echo "${tblname}|${cnt:-0}" >> "$tmp_cnpg"
        done <<< "$table_list_cnpg"

        # Normalise EDB snapshot the same way (strip schema prefix)
        local tmp_edb_rows tmp_cnpg_rows
        tmp_edb_rows=$(mktemp)
        tmp_cnpg_rows=$(mktemp)
        sed 's|^[^.]*\.||' "$db_dir/row_counts.txt" | sort > "$tmp_edb_rows" 2>/dev/null || true
        sort "$tmp_cnpg" > "$tmp_cnpg_rows" 2>/dev/null || true

        # Row-count diff is split into two categories:
        #   DATA LOSS  — CNPG count is LOWER than EDB   → [DIFF]  (real problem)
        #   LIVE GROWTH — CNPG count is HIGHER than EDB → [WARN]  (expected: app wrote after snapshot)
        # Any table missing entirely from CNPG is also a [DIFF].
        local rc_diff
        rc_diff=$(diff "$tmp_edb_rows" "$tmp_cnpg_rows" 2>/dev/null || true)
        if [[ -z "$rc_diff" ]]; then
            echo "  [OK]   row counts match exactly" >> "$REPORT"
        else
            # Check for shrinkage (lines only in EDB that show higher counts than CNPG)
            # or missing tables (lines only in EDB with no counterpart in CNPG).
            local loss_lines growth_lines
            loss_lines=""
            growth_lines=""
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                local sign="${line:0:1}"
                local rest="${line:1}"
                if [[ "$sign" == "-" ]]; then
                    # Skip diff file-header lines: ---<space>... or ---/path or --<space>
                    # These are metadata emitted by diff, not data records.
                    [[ "$rest" == -* ]] && continue        # --- (unified header)
                    [[ "$rest" == $' '* ]] && continue     # -<space> (context separator)
                    # A valid data line must contain a '|' separator (table|count).
                    [[ "$rest" != *"|"* ]] && continue

                    # This table/count is in EDB but not in CNPG (as-is)
                    local tbl edb_cnt
                    tbl=$(echo "$rest" | cut -d'|' -f1)
                    edb_cnt=$(echo "$rest" | cut -d'|' -f2)
                    # Check if the table exists in CNPG with an equal or higher count
                    local cnpg_cnt
                    cnpg_cnt=$(grep "^${tbl}|" "$tmp_cnpg_rows" 2>/dev/null | cut -d'|' -f2)
                    if [[ -n "$cnpg_cnt" ]] && [[ "$cnpg_cnt" -eq "$edb_cnt" ]] 2>/dev/null; then
                        # Counts match exactly (including both-zero empty tables) — not a diff
                        : # no-op: this line will not appear in loss or growth
                    elif [[ -n "$cnpg_cnt" ]] && [[ "$cnpg_cnt" -gt "$edb_cnt" ]] 2>/dev/null; then
                        growth_lines="${growth_lines}    ${tbl}: EDB=${edb_cnt} CNPG=${cnpg_cnt} (live growth — OK)\n"
                    else
                        loss_lines="${loss_lines}    ${tbl}: EDB=${edb_cnt} CNPG=${cnpg_cnt:-MISSING} ← DATA LOSS\n"
                    fi
                fi
            done < <(echo "$rc_diff")

            if [[ -n "$loss_lines" ]]; then
                {
                    echo "  [DIFF] row_counts.txt — DATA LOSS detected:"
                    printf "%b" "$loss_lines"
                } >> "$REPORT"
                db_pass=1
            fi
            if [[ -n "$growth_lines" ]]; then
                {
                    echo "  [WARN] row_counts.txt — live growth since snapshot (not data loss):"
                    printf "%b" "$growth_lines"
                } >> "$REPORT"
                # growth-only does NOT set db_pass — it is expected behaviour
            fi
            if [[ -z "$loss_lines" ]] && [[ -z "$growth_lines" ]]; then
                # Diff exists but all lines were diff metadata / header lines (skipped)
                # or pure '+' lines (tables present in CNPG but not in EDB snapshot —
                # benign: new objects created after snapshot). Treat as OK.
                echo "  [OK]   row counts — no data loss (CNPG-only additions)" >> "$REPORT"
            fi
            [[ -z "$loss_lines" ]] && [[ -n "$growth_lines" ]] && \
                echo "  [OK]   row counts — no data loss (live growth only)" >> "$REPORT"
        fi
        rm -f "$tmp_edb_rows" "$tmp_cnpg_rows"

        # ── Schema-level ACLs ────────────────────────────────────────────────
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres \
            -d "dbname='$db'" -t -A -c \
            "SELECT n.nspname AS schema,
                    pg_get_userbyid((aclexplode(n.nspacl)).grantee) AS grantee,
                    (aclexplode(n.nspacl)).privilege_type AS privilege
             FROM pg_namespace n
             WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
               AND n.nspacl IS NOT NULL
               AND (aclexplode(n.nspacl)).grantee != 0
             ORDER BY n.nspname,
                      pg_get_userbyid((aclexplode(n.nspacl)).grantee),
                      (aclexplode(n.nspacl)).privilege_type;" \
            > "$tmp_cnpg" 2>/dev/null || true
        if ! diff -u "$db_dir/schema_acl.txt" "$tmp_cnpg" >> "$REPORT" 2>/dev/null; then
            echo "  [DIFF] schema_acl.txt has differences — ACCESS ISSUE LIKELY (see above)" >> "$REPORT"
            db_pass=1
        else
            echo "  [OK]   schema ACLs match" >> "$REPORT"
        fi

        # ── Table-level ACLs ─────────────────────────────────────────────────
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres \
            -d "dbname='$db'" -t -A -c \
            "SELECT schemaname, tablename,
                    grantee, privilege_type, is_grantable
             FROM information_schema.role_table_grants
             WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast')
             ORDER BY schemaname, tablename, grantee, privilege_type;" \
            > "$tmp_cnpg" 2>/dev/null || true
        if ! diff -u "$db_dir/table_acl.txt" "$tmp_cnpg" >> "$REPORT" 2>/dev/null; then
            echo "  [DIFF] table_acl.txt has differences — ACCESS ISSUE LIKELY (see above)" >> "$REPORT"
            db_pass=1
        else
            echo "  [OK]   table ACLs match" >> "$REPORT"
        fi

        rm -f "$tmp_cnpg"

        if [[ $db_pass -eq 0 ]]; then
            success "  ✓ $db — all dimensions match"
            echo "" >> "$REPORT"
        else
            warning "  ⚠ $db — differences found (see $REPORT)"
            echo "" >> "$REPORT"
            overall_pass=1
        fi

    done  # for db

    # ── Summary ───────────────────────────────────────────────────────────────
    {
        echo "================================================================"
        if [[ $overall_pass -eq 0 ]]; then
            echo " RESULT: ALL DATABASES MATCH — migration looks clean"
        else
            echo " RESULT: DIFFERENCES FOUND — review [DIFF] sections above"
            echo ""
            echo " Priority checks:"
            echo "   schema_acl  — if different: app users cannot access schema objects"
            echo "   table_acl   — if different: app users cannot SELECT/INSERT tables"
            echo "   row_counts  — if different: data was not fully migrated"
            echo "   tables      — if different: objects missing from restore"
            echo "   columns     — if different: schema mismatch (type change between PG14/PG16)"
        fi
        echo "================================================================"
    } >> "$REPORT"

    echo ""
    if [[ $overall_pass -eq 0 ]]; then
        success "Snapshot comparison complete — no differences found."
    else
        warning "Snapshot comparison complete — differences found."
        warning "Review full report: $REPORT"
    fi
    info "Full diff report: $REPORT"
    echo ""
    return 0
}

################################################################################
#   - NAMESPACE: Kubernetes namespace
#   - CLI_CMD: kubectl or oc command
# Returns: 0 on success, exits on error
# Note: Creates individual .sql files for each database and a database_list.txt
################################################################################
function backup_databases() {
    info "=== PHASE: BACKING UP DATABASES ==="
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    info "Backup directory: $BACKUP_DIR"
    
    # Get EDB pod name - try two methods
    info "Looking for EDB PostgreSQL pod..."
    local EDB_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE -l k8s.enterprisedb.io/cluster=$OLD_CLUSTER,role=primary -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$EDB_POD" ]]; then
        EDB_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE --no-headers | grep -E "^${OLD_CLUSTER}-[0-9]+[[:space:]]" | head -1 | awk '{print $1}')
    fi
    
    if [[ -z "$EDB_POD" ]]; then
        error "Could not find EDB PostgreSQL pod."
        return 1
    fi
    
    info "Using EDB pod: $EDB_POD"
    
    # Validate databases before backup
    info "Validating databases before backup..."
    for db in "${DATABASES[@]}"; do
        validate_database_pre_backup "$EDB_POD" "$db"
    done
    success "Pre-backup validation complete."
    echo ""
    
    # Backup globals
    info "Backing up global objects (roles, tablespaces)..."
    if ! ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- pg_dumpall -U postgres --globals-only > "$BACKUP_DIR/globals.sql"; then
        local exit_code=$?
        error "pg_dumpall failed for global objects with exit code $exit_code"
        error "Backup file may be incomplete or corrupted"
        return 1
    fi
    
    # Verify globals backup file was created and has content
    if [[ ! -f "$BACKUP_DIR/globals.sql" ]]; then
        error "Globals backup file not created: $BACKUP_DIR/globals.sql"
        return 1
    fi
    
    local globals_size=$(stat -f%z "$BACKUP_DIR/globals.sql" 2>/dev/null || stat -c%s "$BACKUP_DIR/globals.sql" 2>/dev/null)
    if [[ "$globals_size" -eq 0 ]]; then
        error "Globals backup file is empty: $BACKUP_DIR/globals.sql"
        return 1
    fi
    
    success "Globals backed up to $BACKUP_DIR/globals.sql (size: $(du -h "$BACKUP_DIR/globals.sql" | cut -f1))"
    
    # Backup database-level ownership and GRANT statements
    # pg_dumpall --globals-only captures roles but NOT database-level ACLs
    # (ALTER DATABASE ... OWNER TO / GRANT ... ON DATABASE).
    # We extract them explicitly here so they can be applied during restore.
    info "Backing up database-level ownership and grant statements..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -t -A -c \
        "SELECT 'ALTER DATABASE ' || quote_ident(d.datname) || ' OWNER TO ' || quote_ident(r.rolname) || ';'
         FROM pg_database d
         JOIN pg_roles r ON d.datdba = r.oid
         WHERE d.datistemplate = false
           AND d.datname NOT IN ('postgres', 'rdsadmin')
         ORDER BY d.datname;" > "$BACKUP_DIR/db_ownership_grants.sql"

    # Cast grantee OID to role name via pg_get_userbyid() rather than ::regrole::text.
    # OID 0 = PUBLIC pseudo-role.  Two cases from the live \l output:
    #   "=T/adpuser"  → PUBLIC has TEMP on that database — emit "GRANT TEMP ON DATABASE x TO PUBLIC"
    #   Named role    → emit "GRANT <priv> ON DATABASE x TO <rolename>"
    # We include OID=0 rows only for TEMP (the CONNECT default for PUBLIC is implicit
    # and does not need to be re-granted on PG16).
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -t -A -c \
        "SELECT 'GRANT ' || privilege_type || ' ON DATABASE ' || quote_ident(db)
                || ' TO ' || CASE WHEN grantee_oid = 0 THEN 'PUBLIC'
                                  ELSE quote_ident(pg_get_userbyid(grantee_oid)) END || ';'
         FROM (
             SELECT d.datname AS db,
                    (aclexplode(d.datacl)).privilege_type AS privilege_type,
                    (aclexplode(d.datacl)).grantee        AS grantee_oid
             FROM pg_database d
             WHERE d.datistemplate = false
               AND d.datname NOT IN ('postgres', 'rdsadmin')
               AND d.datacl IS NOT NULL
         ) acls
         WHERE grantee_oid != 0
            OR (grantee_oid = 0 AND privilege_type = 'TEMP')
         ORDER BY db, grantee_oid, privilege_type;" >> "$BACKUP_DIR/db_ownership_grants.sql"

    if [[ -f "$BACKUP_DIR/db_ownership_grants.sql" ]] && [[ -s "$BACKUP_DIR/db_ownership_grants.sql" ]]; then
        success "Database ownership and grants backed up to $BACKUP_DIR/db_ownership_grants.sql"
    else
        warning "No database-level ownership/grants found or file is empty"
        # Create empty file to avoid errors during restore
        touch "$BACKUP_DIR/db_ownership_grants.sql"
    fi

    # Backup schema-level and table-level grants for the public schema.
    # PostgreSQL 14 (EDB) granted USAGE+CREATE on public to PUBLIC by default, so
    # application users (e.g. adpuser) could access public-schema tables without any
    # explicit grant being recorded in the dump.  PostgreSQL 16 (CNPG) revoked those
    # defaults (PostgreSQL 16 release notes: "REVOKE CREATE ON SCHEMA public FROM PUBLIC").
    # After pg_restore the tables exist but non-superuser app users cannot SELECT/INSERT
    # until the grants are explicitly re-applied.  We capture them here from EDB so they
    # can be replayed verbatim on the CNPG cluster.
    info "Backing up schema-level and table-level grants (public schema, PG16 compat)..."
    # NOTE: grantee is an OID — must resolve to a role name via pg_get_userbyid().
    # Using grantee::text would emit the raw numeric OID (e.g. "16384") which
    # produces invalid SQL like: GRANT USAGE ON SCHEMA public TO "16384";
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -t -A -c \
        "SELECT 'GRANT ' || string_agg(privilege_type, ', ')
                || ' ON SCHEMA ' || quote_ident(nspname)
                || ' TO ' || CASE WHEN grantee = 0 THEN 'PUBLIC'
                                  ELSE quote_ident(pg_get_userbyid(grantee))
                             END || ';'
         FROM (
             SELECT n.nspname,
                    (aclexplode(n.nspacl)).grantee AS grantee,
                    (aclexplode(n.nspacl)).privilege_type AS privilege_type
             FROM pg_namespace n
             WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
               AND n.nspacl IS NOT NULL
         ) grants
         GROUP BY nspname, grantee
         ORDER BY nspname, grantee;" > "$BACKUP_DIR/schema_grants.sql"

    # Also capture default privileges so future objects created in each schema
    # are automatically accessible to the same roles as before (e.g. adpuser
    # getting SELECT on tables created by postgres in the public schema).
    # Expand the ACL array so each grantee becomes a separate row, then build
    # one ALTER DEFAULT PRIVILEGES statement per (grantor, schema, grantee) tuple.
    # Using aclexplode() avoids casting the raw ACL array to text.
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -t -A -c \
        "SELECT 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || quote_ident(r.rolname)
                || ' IN SCHEMA ' || quote_ident(n.nspname)
                || ' GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO '
                || quote_ident(pg_get_userbyid((aclexplode(d.defaclacl)).grantee)) || ';'
         FROM pg_default_acl d
         JOIN pg_roles r ON r.oid = d.defaclrole
         JOIN pg_namespace n ON n.oid = d.defaclnamespace
         WHERE d.defaclobjtype = 'r'
           AND d.defaclnamespace != 0
           AND (aclexplode(d.defaclacl)).grantee != 0
         ORDER BY r.rolname, n.nspname;" >> "$BACKUP_DIR/schema_grants.sql" 2>/dev/null || true

    if [[ -f "$BACKUP_DIR/schema_grants.sql" ]] && [[ -s "$BACKUP_DIR/schema_grants.sql" ]]; then
        success "Schema-level grants backed up to $BACKUP_DIR/schema_grants.sql"
    else
        info "No non-default schema grants found in EDB (expected on PG14) — will apply PG16 compatibility grants at restore"
        touch "$BACKUP_DIR/schema_grants.sql"
    fi

    # Backup each database
    for db in "${DATABASES[@]}"; do
        info "Backing up database: $db"
        
        # Execute pg_dump and capture exit code.
        # Use the dbname= keyword form so that mixed-case names (e.g. ADPGG_scy) are
        # passed verbatim to libpq and are not lowercased by the connstring parser.
        if ! ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- pg_dump -U postgres -Fc -d "dbname='$db'" > "$BACKUP_DIR/$db.dump"; then
            local exit_code=$?
            error "pg_dump failed for database $db with exit code $exit_code"
            error "Backup file may be incomplete or corrupted"
            return 1
        fi
        
        # Verify backup file was created and has content
        if [[ ! -f "$BACKUP_DIR/$db.dump" ]]; then
            error "Backup file not created: $BACKUP_DIR/$db.dump"
            return 1
        fi
        
        local file_size=$(stat -f%z "$BACKUP_DIR/$db.dump" 2>/dev/null || stat -c%s "$BACKUP_DIR/$db.dump" 2>/dev/null)
        if [[ "$file_size" -eq 0 ]]; then
            error "Backup file is empty: $BACKUP_DIR/$db.dump"
            return 1
        fi
        
        local size=$(du -h "$BACKUP_DIR/$db.dump" | cut -f1)
        success "Database $db backed up successfully (size: $size)"
    done

    # Backup per-database search_path settings.
    # pg_dumpall --globals-only captures roles and tablespace definitions but NOT
    # ALTER DATABASE ... SET search_path statements. These are set by the CP4BA
    # provisioning scripts (e.g. for ADPGG) and must be re-applied after restore
    # otherwise applications hit "no schema has been selected to create in" errors.
    info "Backing up per-database search_path and session default settings..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $EDB_POD -- psql -U postgres -t -A -c \
        "SELECT 'ALTER DATABASE ' || quote_ident(d.datname)
                || ' SET ' || s.setconfig[i] || ';'
         FROM pg_database d,
              pg_db_role_setting s,
              generate_subscripts(s.setconfig, 1) AS i
         WHERE s.setrole = 0
           AND s.setdatabase = d.oid
           AND d.datistemplate = false
           AND d.datname NOT IN ('postgres', 'rdsadmin')
         ORDER BY d.datname;" > "$BACKUP_DIR/db_session_defaults.sql"

    if [[ -f "$BACKUP_DIR/db_session_defaults.sql" ]] && [[ -s "$BACKUP_DIR/db_session_defaults.sql" ]]; then
        success "Per-database session defaults backed up to $BACKUP_DIR/db_session_defaults.sql"
    else
        info "No per-database session defaults found (search_path etc.) — skipping"
        touch "$BACKUP_DIR/db_session_defaults.sql"
    fi

    # Save database list for restore phase
    printf "%s\n" "${DATABASES[@]}" > "$BACKUP_DIR/database_list.txt"
    info "Database list saved to $BACKUP_DIR/database_list.txt"
    
    success "All databases backed up to $BACKUP_DIR"
    info "Backup contents:"
    ls -lh "$BACKUP_DIR"
    if [[ "$SKIP_FOR_API" != "true" ]]; then
        prompt_press_any_key_to_continue
    fi
    return 0
}

################################################################################
# Function: extract_edb_cluster_configuration
# Purpose: Extracts EDB cluster configuration before deletion for CNPG cluster creation
# Parameters: None (uses global variables)
# Global Variables (Set):
#   - EDB_STORAGE_CLASS: Storage class from EDB cluster
#   - EDB_STORAGE_SIZE: Storage size (default: 100Gi)
#   - EDB_INSTANCES: Number of instances (default: 1)
#   - EDB_CPU_REQUESTS: CPU requests (default: 1)
#   - EDB_MEMORY_REQUESTS: Memory requests (default: 2Gi)
#   - EDB_CPU_LIMITS: CPU limits (default: 2)
#   - EDB_MEMORY_LIMITS: Memory limits (default: 4Gi)
# Global Variables (Read):
#   - OLD_CLUSTER: Name of the EDB cluster
#   - NAMESPACE: Kubernetes namespace
#   - CLI_CMD: kubectl or oc command
# Returns: 0 (always succeeds, uses defaults if extraction fails)
# Note: Must be called BEFORE delete_edb_cluster() to preserve configuration
################################################################################
function extract_edb_cluster_configuration() {
    info "=== EXTRACTING EDB CLUSTER CONFIGURATION ==="

    # Check if EDB cluster exists
    if ${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE &> /dev/null; then
        info "Extracting configuration from existing EDB cluster..."

        # Warn if the EDB cluster is in a failed or degraded state.
        # A unhealthy cluster at this point means the backup data may be incomplete
        # or corrupt — the operator should verify backups before proceeding.
        local edb_phase=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER \
            -n $SERVICES_NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        local edb_ready=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER \
            -n $SERVICES_NAMESPACE -o jsonpath='{.status.readyInstances}' 2>/dev/null || echo "")
        local edb_instances_total=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER \
            -n $SERVICES_NAMESPACE -o jsonpath='{.spec.instances}' 2>/dev/null || echo "")

        info "EDB cluster status: phase='${edb_phase:-unknown}' readyInstances=${edb_ready:-unknown}/${edb_instances_total:-unknown}"

        if [[ -n "$edb_phase" ]] && [[ "$edb_phase" != "Cluster in healthy state" ]]; then
            warning "=========================================================="
            warning "WARNING: EDB cluster is NOT in a healthy state!"
            warning "  Current phase : $edb_phase"
            warning "  Ready instances: ${edb_ready:-unknown} / ${edb_instances_total:-unknown}"
            warning "  This may indicate the cluster was already failing before"
            warning "  the backup phase ran. Verify backup integrity before"
            warning "  continuing — restoring from a bad backup will result in"
            warning "  data loss or a non-functional IBM CloudNativePG cluster."
            warning "=========================================================="
        elif [[ -n "$edb_ready" ]] && [[ -n "$edb_instances_total" ]] && \
             [[ "$edb_ready" -lt "$edb_instances_total" ]] 2>/dev/null; then
            warning "=========================================================="
            warning "WARNING: EDB cluster has degraded replica count!"
            warning "  Ready instances: $edb_ready / $edb_instances_total"
            warning "  One or more replicas were not ready when the EDB cluster"
            warning "  was still running. Verify backup integrity before continuing."
            warning "=========================================================="
        fi

        EDB_STORAGE_CLASS=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE -o jsonpath='{.spec.storage.storageClass}' 2>/dev/null || echo "")
        EDB_STORAGE_SIZE=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE -o jsonpath='{.spec.storage.size}' 2>/dev/null || echo "100Gi")
        EDB_INSTANCES=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE -o jsonpath='{.spec.instances}' 2>/dev/null || echo "1")
        EDB_CPU_REQUESTS=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE -o jsonpath='{.spec.resources.requests.cpu}' 2>/dev/null || echo "1")
        EDB_MEMORY_REQUESTS=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE -o jsonpath='{.spec.resources.requests.memory}' 2>/dev/null || echo "2Gi")
        EDB_CPU_LIMITS=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE -o jsonpath='{.spec.resources.limits.cpu}' 2>/dev/null || echo "2")
        EDB_MEMORY_LIMITS=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE -o jsonpath='{.spec.resources.limits.memory}' 2>/dev/null || echo "4Gi")
        
        if [[ -z "$EDB_STORAGE_CLASS" ]]; then
            warning "Could not extract storage class from EDB cluster"
        else
            info "Extracted storage class: $EDB_STORAGE_CLASS"
        fi
        
        info "Configuration extracted:"
        info "  Storage: $EDB_STORAGE_SIZE on ${EDB_STORAGE_CLASS:-<not set>}"
        info "  Instances: $EDB_INSTANCES"
        info "  Resources: CPU($EDB_CPU_REQUESTS/$EDB_CPU_LIMITS) Memory($EDB_MEMORY_REQUESTS/$EDB_MEMORY_LIMITS)"
    else
        warning "EDB cluster does not exist, using default configuration"
    fi
    
    return 0
}


################################################################################
# Function: delete_edb_cluster
# Purpose: Deletes the old EDB PostgreSQL cluster and associated resources
# Parameters: None (uses global variables)
# Global Variables:
#   - OLD_CLUSTER: Name of the EDB cluster to delete
#   - NAMESPACE: Kubernetes namespace
#   - CLI_CMD: kubectl or oc command
# Returns: 0 on success, 1 on error
# Note: Deletes cluster, services, and PVCs. Waits for cleanup completion.
################################################################################
function delete_edb_cluster() {
    info "=== PHASE: DELETING OLD EDB CLUSTER ==="
    
    # Check if EDB cluster exists
    if ${CLI_CMD} get clusters.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE &> /dev/null; then
        info "EDB cluster '$OLD_CLUSTER' found."
        warning "This will delete the EDB PostgreSQL cluster: $OLD_CLUSTER"
        warning "Ensure backups are complete and verified before proceeding!"
        if [[ "$SKIP_FOR_API" != "true" ]]; then
            prompt_press_any_key_to_continue
        fi
        
        # Delete cluster using correct EDB API
        info "Deleting EDB cluster..."
        ${CLI_CMD} delete clusters.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE --wait=false
        
        # Poll for actual cluster deletion
        info "Waiting for EDB cluster to be fully deleted..."
        local max_wait=$EDB_CLUSTER_DELETE_TIMEOUT
        local elapsed=0
        local check_interval=5
        
        while ${CLI_CMD} get clusters.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE &>/dev/null; do
            if [[ $elapsed -ge $max_wait ]]; then
                error "Timeout waiting for EDB cluster deletion after ${max_wait} seconds"
                error "Cluster may still be terminating. Check with:"
                error "  ${CLI_CMD} get clusters.postgresql.k8s.enterprisedb.io $OLD_CLUSTER -n $SERVICES_NAMESPACE"
                return 1
            fi
            
            if [[ $((elapsed % 15)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
                info "Still waiting for cluster deletion... (${elapsed}s elapsed)"
            fi
            
            sleep $check_interval
            elapsed=$((elapsed + check_interval))
        done
        
        success "EDB cluster deleted successfully (took ${elapsed}s)"
        
        # Delete services
        info "Deleting old EDB services..."
        ${CLI_CMD} delete svc ${OLD_CLUSTER}-rw -n $SERVICES_NAMESPACE --ignore-not-found=true
        ${CLI_CMD} delete svc ${OLD_CLUSTER}-ro -n $SERVICES_NAMESPACE --ignore-not-found=true
        ${CLI_CMD} delete svc ${OLD_CLUSTER}-r -n $SERVICES_NAMESPACE --ignore-not-found=true
        
        # Wait for services to be deleted
        info "Waiting for services to be deleted..."
        max_wait=$SERVICE_DELETE_TIMEOUT
        elapsed=0
        
        while ${CLI_CMD} get svc -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${OLD_CLUSTER}-" &>/dev/null; do
            if [[ $elapsed -ge $max_wait ]]; then
                warning "Some services still exist after ${max_wait}s, continuing anyway"
                break
            fi
            sleep $check_interval
            elapsed=$((elapsed + check_interval))
        done
        
        success "All EDB services deleted"
        
        # Delete PVCs with proper waiting and finalizer handling
        info "Deleting old EDB PVCs..."
        local pvcs=$(${CLI_CMD} get pvc -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${OLD_CLUSTER}-" | awk '{print $1}')
        
        if [[ -z "$pvcs" ]]; then
            info "No PVCs found for cluster $OLD_CLUSTER"
        else
            info "Found PVCs to delete:"
            echo "$pvcs" | while read pvc; do
                info "  - $pvc"
            done
            
            # Delete PVCs without waiting
            echo "$pvcs" | xargs ${CLI_CMD} delete pvc -n $SERVICES_NAMESPACE --wait=false 2>/dev/null || true
            
            # Wait for PVCs to be fully deleted
            info "Waiting for PVCs to be fully deleted..."
            max_wait=$PVC_DELETE_TIMEOUT
            elapsed=0
            local finalizer_check_done=false
            
            while ${CLI_CMD} get pvc -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${OLD_CLUSTER}-" &>/dev/null; do
                if [[ $elapsed -ge $max_wait ]]; then
                    warning "Some PVCs still terminating after ${max_wait}s"
                    warning "Remaining PVCs:"
                    ${CLI_CMD} get pvc -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${OLD_CLUSTER}-" || true
                    warning "These may need manual cleanup if they remain stuck"
                    break
                fi
                
                # After 30 seconds, check for stuck PVCs with finalizers
                if [[ $elapsed -ge 30 ]] && [[ "$finalizer_check_done" == "false" ]]; then
                    finalizer_check_done=true
                    info "Checking for PVCs stuck with finalizers..."
                    
                    local stuck_pvcs=$(${CLI_CMD} get pvc -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${OLD_CLUSTER}-" | awk '{print $1}')
                    if [[ -n "$stuck_pvcs" ]]; then
                        for pvc in $stuck_pvcs; do
                            # Check if PVC has finalizers
                            local finalizers=$(${CLI_CMD} get pvc $pvc -n $SERVICES_NAMESPACE -o jsonpath='{.metadata.finalizers}' 2>/dev/null)
                            if [[ -n "$finalizers" ]] && [[ "$finalizers" != "[]" ]]; then
                                warning "PVC $pvc has finalizers, attempting to remove them..."
                                info "Finalizers: $finalizers"
                                
                                # Remove finalizers by patching the PVC
                                if ${CLI_CMD} patch pvc $pvc -n $SERVICES_NAMESPACE -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null; then
                                    success "Removed finalizers from PVC $pvc"
                                else
                                    warning "Failed to remove finalizers from PVC $pvc"
                                fi
                            fi
                        done
                    fi
                fi
                
                if [[ $((elapsed % 15)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
                    local remaining=$(${CLI_CMD} get pvc -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${OLD_CLUSTER}-" | wc -l | tr -d ' ')
                    info "Still waiting for $remaining PVC(s) to be deleted... (${elapsed}s elapsed)"
                fi
                
                sleep $check_interval
                elapsed=$((elapsed + check_interval))
            done
            
            # Final verification
            if ! ${CLI_CMD} get pvc -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${OLD_CLUSTER}-" &>/dev/null; then
                success "All PVCs deleted successfully (took ${elapsed}s)"
            fi
        fi
    else
        info "EDB cluster '$OLD_CLUSTER' not found (may have been deleted already)."
        info "Skipping all EDB cluster cleanup (cluster, services, PVCs)..."
        success "No EDB resources to clean up."
    fi
    
    # Check if CNPG cluster exists and warn user
    if ${CLI_CMD} get cluster.pg.ibm.com $NEW_CLUSTER -n $SERVICES_NAMESPACE &> /dev/null; then
        warning "IBM CloudNativePG cluster '$NEW_CLUSTER' already exists!"
        warning "If you want to recreate it, delete it first with:"
        warning "  ${CLI_CMD} delete cluster.pg.ibm.com $NEW_CLUSTER -n $SERVICES_NAMESPACE"
        echo ""
        if [[ "$SKIP_FOR_API" != "true" ]]; then
            read -p "Do you want to continue and skip the IBM CloudNativePG cluster creation? (yes/no): " confirm
        else
            confirm="yes"
        fi
        confirm_lower=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
        if [[ "$confirm_lower" != "yes" ]] && [[ "$confirm_lower" != "y" ]]; then
            info "Operation aborted by user."
            echo ""
            displayEdbMigrationRetryMessage "create-cluster" "$SERVICES_NAMESPACE" "$cp4a_operator_csv_version"
            exit 1
        fi
        # Set a flag to skip cluster creation
        SKIP_CNPG_CREATION=true
    else
        success "All $OLD_CLUSTER PVCs removed"
    fi
    
    success "EDB cluster deleted and cleaned up."
    if [[ "$SKIP_FOR_API" != "true" ]]; then
        prompt_press_any_key_to_continue
    fi
    return 0
}

################################################################################
# Function: install_cnpg_operator
# Purpose: Installs IBM CloudNativePG operator via subscription
# Parameters: None (uses global variables)
# Global Variables:
#   - NAMESPACE: Kubernetes namespace for operator
#   - CLI_CMD: kubectl or oc command
# Returns: 0 on success, 1 on error
# Note: Checks if operator already exists, waits for operator pod to be ready
################################################################################
function install_cnpg_operator() {
    info "=== PHASE: INSTALLING IBM CloudNativePG OPERATOR ==="
    
    # Check if subscription already exists
    if ${CLI_CMD} get subscription ibm-pg-operator -n $OPERATOR_NAMESPACE &> /dev/null; then
        info "IBM CloudNativePG operator subscription already exists, checking operator status..."
        
        # Check if CSV already exists and is ready
        local existing_csv=$(${CLI_CMD} get csv ${CNPG_OPERATOR_CSV_VERSION} -n $OPERATOR_NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [[ "$existing_csv" == "Succeeded" ]]; then
            success "IBM CloudNativePG operator already installed and ready!"
            info "CSV: ${CNPG_OPERATOR_CSV_VERSION}"
            return 0
        elif [[ "$existing_csv" == "Failed" ]]; then
            # CSV reached a terminal failure state — waiting will never recover it.
            # Surface the OLM failure reason so the operator can act, then fail fast.
            error "IBM CloudNativePG operator CSV is in a FAILED state."
            error "Waiting will not recover a failed CSV. Manual intervention is required."
            error ""
            local csv_reason=$(${CLI_CMD} get csv ${CNPG_OPERATOR_CSV_VERSION} \
                -n $OPERATOR_NAMESPACE \
                -o jsonpath='{.status.message}' 2>/dev/null || echo "")
            if [[ -n "$csv_reason" ]]; then
                error "Failure reason: $csv_reason"
            fi
            error ""
            error "To recover, delete the failed subscription and CSV, then re-run:"
            error "  ${CLI_CMD} delete csv ${CNPG_OPERATOR_CSV_VERSION} -n $OPERATOR_NAMESPACE --ignore-not-found"
            error "  ${CLI_CMD} delete subscription ibm-pg-operator -n $OPERATOR_NAMESPACE --ignore-not-found"
            error "Then investigate the CatalogSource and re-run upgradeOperator."
            return 1
        else
            info "Operator subscription exists, CSV not yet ready (phase: '${existing_csv:-not found}')"
            info "Will wait for operator to become ready..."
            # Continue to wait logic below
        fi
    else
        info "Creating IBM CloudNativePG operator subscription..."
        
        # Check if template file exists
        if [[ ! -f "$CNPG_OPERATOR_SUBSCRIPTION_TEMPLATE" ]]; then
            error "IBM CloudNativePG operator subscription template not found: $CNPG_OPERATOR_SUBSCRIPTION_TEMPLATE"
            return 1
        fi
        
        # Generate subscription manifest from template
        local CNPG_SUBSCRIPTION_MANIFEST="${TEMP_FOLDER}/cnpg-operator-subscription.yaml"
        info "Generating IBM CloudNativePG operator subscription manifest from template..."
        
        # Copy template and replace placeholders using yq
        cp "$CNPG_OPERATOR_SUBSCRIPTION_TEMPLATE" "$CNPG_SUBSCRIPTION_MANIFEST"
        
        # Replace namespace placeholder
        ${YQ_CMD} eval ".metadata.namespace = \"$OPERATOR_NAMESPACE\"" -i "$CNPG_SUBSCRIPTION_MANIFEST"
        ${YQ_CMD} eval ".spec.sourceNamespace = \"$OPERATOR_NAMESPACE\"" -i "$CNPG_SUBSCRIPTION_MANIFEST"
        
        # Replace channel placeholder
        ${YQ_CMD} eval ".spec.channel = \"$CNPG_OPERATOR_CHANNEL\"" -i "$CNPG_SUBSCRIPTION_MANIFEST"
        
        info "Applying IBM CloudNativePG operator subscription..."
        info "  Channel: $CNPG_OPERATOR_CHANNEL"
        info "  Namespace: $OPERATOR_NAMESPACE"
        
        ${CLI_CMD} apply -f "$CNPG_SUBSCRIPTION_MANIFEST"
        
        if [[ $? -ne 0 ]]; then
            error "Failed to create IBM CloudNativePG operator subscription"
            return 1
        fi
        
        success "IBM CloudNativePG operator subscription created successfully"
    fi
    
    info "Waiting for IBM CloudNativePG operator to be ready (this may take 5-10 minutes)..."
    
    # Wait for operator to be ready
    local max_wait=600  # 10 minutes
    local elapsed=0
    local interval=10
    local csv=""
    local csv_name=""
    
    while [[ $elapsed -lt $max_wait ]]; do
        # Try to find CSV by exact name first (most reliable)
        csv=$(${CLI_CMD} get csv ${CNPG_OPERATOR_CSV_VERSION} -n $OPERATOR_NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        
        # Debug: show what we got
        if [[ $elapsed -eq 0 ]]; then
            info "Debug: Checking namespace=$OPERATOR_NAMESPACE, csv='$csv', length=${#csv}"
        fi
        
        # If not found by exact name, try to find by name prefix using grep
        if [[ -z "$csv" ]]; then
            csv_name=$(${CLI_CMD} get csv -n $OPERATOR_NAMESPACE --no-headers 2>/dev/null | grep "^ibm-pg-operator" | head -1 | awk '{print $1}')
            if [[ -n "$csv_name" ]]; then
                csv=$(${CLI_CMD} get csv $csv_name -n $OPERATOR_NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
                if [[ $elapsed -eq 0 ]]; then
                    info "Debug: Found CSV by grep: $csv_name, phase='$csv'"
                fi
            fi
        fi
        
        # If still not found, try by display name
        if [[ -z "$csv" ]]; then
            csv=$(${CLI_CMD} get csv -n $OPERATOR_NAMESPACE -o jsonpath='{.items[?(@.spec.displayName=="IBM Cloud Native PostgreSQL")].status.phase}' 2>/dev/null || echo "")
        fi
        
        # Last resort: check if any CSV exists
        if [[ -z "$csv" ]]; then
            csv="NotFound"
        fi
        
        if [[ "$csv" == "Succeeded" ]]; then
            success "IBM CloudNativePG operator is ready!"
            success "IBM CloudNativePG operator installation complete."
            
            # Show which CSV was found
            local csv_name=$(${CLI_CMD} get csv -n $OPERATOR_NAMESPACE --no-headers 2>/dev/null | grep "^ibm-pg-operator" | head -1 | awk '{print $1}')
            if [[ -z "$csv_name" ]]; then
                csv_name="${CNPG_OPERATOR_CSV_VERSION}"
            fi
            info "CSV: $csv_name"
            
            if [[ "$SKIP_FOR_API" != "true" ]]; then
                prompt_press_any_key_to_continue
            fi
            return 0
        fi
        
        # Show more detailed status every 30 seconds
        if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
            info "Detailed status check:"
            ${CLI_CMD} get csv -n $OPERATOR_NAMESPACE 2>/dev/null | head -5 || info "  No CSV found yet"
        fi
        
        info "Operator status: $csv (waiting...)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    # If we get here, we timed out
    error "Timeout waiting for IBM CloudNativePG operator to be ready!"
    error "Operator did not reach 'Succeeded' state within $max_wait seconds."
    echo ""
    info "Checking operator status..."
    ${CLI_CMD} get csv -n $OPERATOR_NAMESPACE 2>/dev/null || warning "No CSV found"
    echo ""
    info "Checking subscription status..."
    ${CLI_CMD} get subscription ibm-pg-operator -n $OPERATOR_NAMESPACE -o yaml 2>/dev/null || warning "No subscription found"
    echo ""
    error "Please check the operator installation and try again."
    info "You can check operator logs with:"
    info "  ${CLI_CMD} get pods -n $OPERATOR_NAMESPACE | grep operator"
    info "  ${CLI_CMD} logs <operator-pod> -n $OPERATOR_NAMESPACE"
    return 1
}

################################################################################
# Function: generate_cnpg_manifest
# Purpose: Generates CNPG cluster manifest from template using extracted EDB configuration
# Parameters: None (uses global variables)
# Global Variables (Read):
#   - CNPG_CLUSTER_TEMPLATE: Path to template file (from common.sh)
#   - EDB_STORAGE_CLASS, EDB_STORAGE_SIZE, EDB_INSTANCES: Extracted EDB config
#   - EDB_CPU_REQUESTS, EDB_MEMORY_REQUESTS, EDB_CPU_LIMITS, EDB_MEMORY_LIMITS
#   - DATABASES: Array of database names for initdb
#   - NEW_CLUSTER: Name for the new CNPG cluster
#   - NAMESPACE: Kubernetes namespace
# Global Variables (Set):
#   - CNPG_MANIFEST: Path to generated manifest file
# Returns: 0 on success, 1 on error
# Note: Uses yq to modify template. Prompts for storage class if not extracted.
#       Template location: descriptors/cnpg/cnpg-cluster-postgres-cp4ba-template.yaml
################################################################################
function generate_cnpg_manifest() {
    # Define where the file for the CNPG cluster template to be applied will be stored
    CNPG_MANIFEST="${TEMP_FOLDER}/cnpg-cluster-postgres-cp4ba.yaml"
    info "=== GENERATING IBM CloudNativePG MANIFEST ==="
    
    if [[ ${#DATABASES[@]} -eq 0 ]]; then
        error "No databases discovered. Cannot generate manifest."
        return 1
    fi
    
    info "Generating manifest for ${#DATABASES[@]} databases..."
    
    # Check if template file exists
    if [[ ! -f "$CNPG_CLUSTER_TEMPLATE" ]]; then
        error "IBM CloudNativePG cluster template not found: $CNPG_CLUSTER_TEMPLATE"
        return 1
    fi
    
    # Use global EDB_* variables (extracted before EDB cluster deletion)
    local storage_class="$EDB_STORAGE_CLASS"
    local storage_size="$EDB_STORAGE_SIZE"
    local instances="$EDB_INSTANCES"
    local cpu_requests="$EDB_CPU_REQUESTS"
    local memory_requests="$EDB_MEMORY_REQUESTS"
    local cpu_limits="$EDB_CPU_LIMITS"
    local memory_limits="$EDB_MEMORY_LIMITS"
    
    info "Using extracted EDB configuration:"
    info "  Storage: $storage_size on ${storage_class:-<not set>}"
    info "  Instances: $instances"
    info "  Resources: CPU($cpu_requests/$cpu_limits) Memory($memory_requests/$memory_limits)"
    
    # If storage class wasn't extracted, ask user or list available options
    if [[ -z "$storage_class" ]]; then
        warning "Storage class not available from EDB cluster"
        info "Available storage classes in the cluster:"
        ${CLI_CMD} get storageclass --no-headers | awk '{print "  - " $1}' || warning "Could not list storage classes"
        echo ""
        read -p "Enter storage class name (or press Enter for default 'ocs-storagecluster-ceph-rbd'): " user_storage_class
        
        if [[ -n "$user_storage_class" ]]; then
            storage_class="$user_storage_class"
            info "Using user-provided storage class: $storage_class"
        else
            storage_class="ocs-storagecluster-ceph-rbd"
            info "Using default storage class: $storage_class"
        fi
    fi
    
    info "Configuration extracted:"
    info "  Storage Class: $storage_class"
    info "  Storage Size: $storage_size"
    info "  Instances: $instances"
    info "  CPU Requests: $cpu_requests, Limits: $cpu_limits"
    info "  Memory Requests: $memory_requests, Limits: $memory_limits"
    
    # Copy template and use yq to replace placeholders
    info "Generating manifest from template: $CNPG_CLUSTER_TEMPLATE"
    cp "$CNPG_CLUSTER_TEMPLATE" "$CNPG_MANIFEST"
    
    # Use yq to replace placeholders with actual values
    ${YQ_CMD} eval -i ".metadata.name = \"${NEW_CLUSTER}\"" "$CNPG_MANIFEST"
    ${YQ_CMD} eval -i ".metadata.namespace = \"${SERVICES_NAMESPACE}\"" "$CNPG_MANIFEST"
    ${YQ_CMD} eval -i ".spec.instances = ${instances}" "$CNPG_MANIFEST"
    ${YQ_CMD} eval -i ".spec.storage.size = \"${storage_size}\"" "$CNPG_MANIFEST"
    ${YQ_CMD} eval -i ".spec.storage.storageClass = \"${storage_class}\"" "$CNPG_MANIFEST"
    ${YQ_CMD} eval -i ".spec.resources.requests.memory = \"${memory_requests}\"" "$CNPG_MANIFEST"
    ${YQ_CMD} eval -i ".spec.resources.requests.cpu = \"${cpu_requests}\"" "$CNPG_MANIFEST"
    ${YQ_CMD} eval -i ".spec.resources.limits.memory = \"${memory_limits}\"" "$CNPG_MANIFEST"
    ${YQ_CMD} eval -i ".spec.resources.limits.cpu = \"${cpu_limits}\"" "$CNPG_MANIFEST"
    
    success "IBM CloudNativePG manifest generated: $CNPG_MANIFEST"
    info "Manifest includes the following databases:"
    for db in "${DATABASES[@]}"; do
        info "  - $db"
    done
    
    echo ""
    info "Manifest configuration (extracted from EDB cluster):"
    info "  - instances: $instances"
    info "  - storage.size: $storage_size"
    info "  - storage.storageClass: $storage_class"
    info "  - resources.requests: cpu=$cpu_requests, memory=$memory_requests"
    info "  - resources.limits: cpu=$cpu_limits, memory=$memory_limits"
    echo ""
    info "You can review and customize the manifest before deployment if needed."
    echo ""
    if [[ "$SKIP_FOR_API" != "true" ]]; then
        prompt_press_any_key_to_continue
    fi
    return 0
}

################################################################################
# Function: deploy_cnpg_cluster
# Purpose: Deploys the IBM CNPG cluster and waits for it to be ready
# Parameters: None (uses global variables)
# Global Variables:
#   - SKIP_CNPG_CREATION: If true, skips cluster creation
#   - CNPG_MANIFEST: Path to generated manifest file
#   - NEW_CLUSTER: Name of the CNPG cluster
#   - NAMESPACE: Kubernetes namespace
#   - CLI_CMD: kubectl or oc command
# Returns: 0 on success, 1 on error
# Note: Calls generate_cnpg_manifest() if manifest doesn't exist.
#       Waits for cluster to reach "Cluster in healthy state" status.
################################################################################
function deploy_cnpg_cluster() {
    info "=== PHASE: DEPLOYING IBM IBM CloudNativePG CLUSTER ==="
    
    # Check if we should skip cluster creation
    if [[ "$SKIP_CNPG_CREATION" = true ]]; then
        info "IBM CloudNativePG cluster already exists, skipping creation."
        success "Using existing IBM CloudNativePG cluster: $NEW_CLUSTER"
        return 0
    fi
    
    # Generate manifest if it doesn't exist or if it contains invalid/outdated fields
    if [[ ! -f "$CNPG_MANIFEST" ]]; then
        info "Manifest not found, generating from discovered databases..."
        generate_cnpg_manifest
    else
        # Validate existing manifest for invalid fields or hardcoded values
        local needs_regeneration=false
        local reason=""
        
        # Check for wrong namespace
        local manifest_namespace=$(grep "namespace:" "$CNPG_MANIFEST" | head -1 | awk '{print $2}')
        if [[ -n "$manifest_namespace" ]] && [[ "$manifest_namespace" != "$SERVICES_NAMESPACE" ]]; then
            needs_regeneration=true
            reason="namespace mismatch (manifest: $manifest_namespace, current: $SERVICES_NAMESPACE)"
        elif grep -q "bootstrap.initdb.databases\|monitoring.enabled" "$CNPG_MANIFEST" 2>/dev/null; then
            needs_regeneration=true
            reason="invalid API fields detected"
        elif grep -q "storageClass: ocs-storagecluster-ceph-rbd" "$CNPG_MANIFEST" 2>/dev/null; then
            needs_regeneration=true
            reason="hardcoded storage class detected (should be extracted from EDB cluster)"
        elif grep -q "instances: 3" "$CNPG_MANIFEST" 2>/dev/null; then
            needs_regeneration=true
            reason="instance count is 3 in manifest (re-extracting from EDB cluster)"
        fi
        
        if [[ "$needs_regeneration" = true ]]; then
            warning "Existing manifest needs regeneration: $reason"
            info "Backing up old manifest to ${CNPG_MANIFEST}.old"
            mv "$CNPG_MANIFEST" "${CNPG_MANIFEST}.old"
            info "Regenerating manifest with configuration from EDB cluster..."
            generate_cnpg_manifest
        else
            info "Using existing manifest: $CNPG_MANIFEST"
            info "Manifest validation: OK"
        fi
    fi
    
    info "Deploying IBM CloudNativePG cluster from $CNPG_MANIFEST..."
    ${CLI_CMD} apply -f $CNPG_MANIFEST
    
    info "Waiting for IBM CloudNativePG cluster to be ready (this may take 2-3 minutes)..."
    
    # Wait for cluster to be ready
    local max_wait=300  # 5 minutes
    local elapsed=0
    local interval=10
    
    while [[ $elapsed -lt $max_wait ]]; do
        local status=$(${CLI_CMD} get cluster.pg.ibm.com $NEW_CLUSTER -n $SERVICES_NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
        
        if [[ "$status" == "Cluster in healthy state" ]]; then
            success "IBM CloudNativePG cluster is ready!"
            break
        fi
        
        info "Cluster status: $status (waiting...)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    if [[ $elapsed -ge $max_wait ]]; then
        error "Timeout waiting for IBM CloudNativePG cluster to be ready."
        exit 1
    fi
    
    # Show cluster status
    info "Cluster details:"
    ${CLI_CMD} get cluster.pg.ibm.com $NEW_CLUSTER -n $SERVICES_NAMESPACE
    
    info "Cluster pods:"
    ${CLI_CMD} get pods -n $SERVICES_NAMESPACE | grep "^${NEW_CLUSTER}-"
    
    success "IBM CloudNativePG cluster deployed successfully."

    # Pre-create tablespace directories on every replica PVC.
    # When instances > 1 the replica must replay WAL records that include
    # "Tablespace/CREATE" entries.  PostgreSQL requires the target directory to
    # already exist on the replica filesystem before WAL recovery can proceed;
    # if it is missing the replica aborts and enters CrashLoopBackOff.
    # This call is a no-op for single-instance clusters.
    if ! prepare_replica_tablespace_dirs; then
        warning "Replica tablespace directory preparation had errors (see above)."
        warning "The cluster may still function if no custom tablespaces exist."
        warning "Check replica pod logs and create missing directories manually if needed."
    fi

    if [[ "$SKIP_FOR_API" != "true" ]]; then
        prompt_press_any_key_to_continue
    fi
    return 0
}

################################################################################
# Function: prepare_replica_tablespace_dirs
# Purpose: Pre-creates tablespace directories on every replica PVC before WAL
#          recovery starts.  When instances > 1, the replica pod bootstraps from
#          a base backup of the primary and then replays WAL.  Any
#          "Tablespace/CREATE" WAL record requires the target directory to
#          already exist on the replica filesystem — PostgreSQL cannot create it
#          during recovery and will abort with:
#            FATAL 58P01  directory ".../pgdata/<name>_tbs" does not exist
#          This function mounts each replica PVC into a short-lived debug pod
#          and creates the missing directories, then deletes the pod.
#          Must be called AFTER the primary pod is Ready (tablespaces already
#          created on the primary) and BEFORE replica WAL recovery completes.
# Parameters: None (uses global variables)
# Global Variables:
#   - NEW_CLUSTER:        IBM PG cluster name
#   - SERVICES_NAMESPACE: Kubernetes namespace
#   - EDB_INSTANCES:      Number of instances (skip when 1)
#   - BACKUP_DIR:         Backup directory (tablespace list read from globals.sql)
#   - CLI_CMD:            kubectl or oc
# Returns: 0 on success, 1 on error
################################################################################
function prepare_replica_tablespace_dirs() {
    local instances="${EDB_INSTANCES:-1}"

    if [[ "$instances" -le 1 ]]; then
        info "Single-instance cluster — no replica tablespace directories to prepare."
        return 0
    fi

    info "=== PREPARING REPLICA TABLESPACE DIRECTORIES (instances=$instances) ==="

    # ── Collect tablespace names from globals.sql ──────────────────────────────
    # Re-use the same globals.sql the restore phase will later process.
    local globals_sql="$BACKUP_DIR/globals.sql"
    local ts_names=()

    if [[ ! -f "$globals_sql" ]]; then
        warning "globals.sql not found at $globals_sql — skipping replica tablespace dir preparation."
        warning "If the cluster has custom tablespaces the replica may enter CrashLoopBackOff."
        warning "Manually run: mkdir -p /var/lib/postgresql/data/pgdata/<ts> on each replica PVC."
        return 0
    fi

    while IFS= read -r line; do
        local ts_name
        ts_name=$(echo "$line" | awk '{print $3}')
        [[ -z "$ts_name" ]] && continue
        ts_names+=("$ts_name")
    done < <(grep '^CREATE TABLESPACE' "$globals_sql" 2>/dev/null)

    if [[ ${#ts_names[@]} -eq 0 ]]; then
        info "No custom tablespaces found in globals.sql — skipping."
        return 0
    fi

    info "Tablespaces to pre-create on replica PVCs: ${ts_names[*]}"

    # ── Build the mkdir command string ────────────────────────────────────────
    local ts_base="/var/lib/postgresql/data/pgdata"
    local mkdir_args=()
    for ts in "${ts_names[@]}"; do
        mkdir_args+=("${ts_base}/${ts}")
    done
    # Join with spaces — safe because tablespace names are plain identifiers
    local mkdir_cmd="mkdir -p ${mkdir_args[*]} && echo OK"

    # ── Resolve image, runAsUser and fsGroup from the running primary pod ─────
    # These values are assigned by OpenShift's SCC admission and vary per
    # namespace — they must NOT be hardcoded.
    local pg_image
    pg_image=$(${CLI_CMD} get pod "${NEW_CLUSTER}-1" -n "$SERVICES_NAMESPACE" \
        -o jsonpath='{.spec.containers[?(@.name=="postgres")].image}' 2>/dev/null)

    if [[ -z "$pg_image" ]]; then
        warning "Could not read image from primary pod — falling back to cluster spec."
        pg_image=$(${CLI_CMD} get cluster.pg.ibm.com "$NEW_CLUSTER" -n "$SERVICES_NAMESPACE" \
            -o jsonpath='{.spec.imageName}' 2>/dev/null)
    fi

    if [[ -z "$pg_image" ]]; then
        error "Could not determine PostgreSQL image. Cannot prepare replica tablespace directories."
        return 1
    fi

    # runAsUser — read from the primary pod's container securityContext
    local run_as_user
    run_as_user=$(${CLI_CMD} get pod "${NEW_CLUSTER}-1" -n "$SERVICES_NAMESPACE" \
        -o jsonpath='{.spec.containers[?(@.name=="postgres")].securityContext.runAsUser}' 2>/dev/null)
    run_as_user="${run_as_user:-26}"

    # fsGroup — read from the primary pod's pod-level securityContext
    local fs_group
    fs_group=$(${CLI_CMD} get pod "${NEW_CLUSTER}-1" -n "$SERVICES_NAMESPACE" \
        -o jsonpath='{.spec.securityContext.fsGroup}' 2>/dev/null)
    fs_group="${fs_group:-26}"

    info "Using image: $pg_image"
    info "Using runAsUser: $run_as_user  fsGroup: $fs_group"

    # ── For each replica instance (2..N) mount its PVC and create the dirs ────
    local rc=0
    for i in $(seq 2 "$instances"); do
        local pvc_name="${NEW_CLUSTER}-${i}"
        local debug_pod="tbs-init-replica-${i}"

        info "Preparing tablespace directories on replica PVC: $pvc_name (pod: $debug_pod)"

        # Wait for the replica PVC to be Bound before mounting it.
        # IBM PG provisions replica PVCs shortly after the primary is ready;
        # the PVC must be Bound before a pod can mount it.
        local pvc_wait=0
        local pvc_status=""
        while [[ $pvc_wait -lt 120 ]]; do
            pvc_status=$(${CLI_CMD} get pvc "$pvc_name" -n "$SERVICES_NAMESPACE" \
                -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
            [[ "$pvc_status" == "Bound" ]] && break
            info "  Waiting for PVC $pvc_name to be Bound (current: $pvc_status)... (${pvc_wait}s)"
            sleep 5
            pvc_wait=$((pvc_wait + 5))
        done
        if [[ "$pvc_status" != "Bound" ]]; then
            error "PVC $pvc_name is not Bound after ${pvc_wait}s (status: $pvc_status)."
            error "Cannot prepare tablespace directories on this replica PVC."
            rc=1
            continue
        fi
        info "  PVC $pvc_name is Bound."

        # Remove any leftover debug pod from a previous interrupted run
        ${CLI_CMD} delete pod "$debug_pod" -n "$SERVICES_NAMESPACE" \
            --ignore-not-found=true --wait=true 2>/dev/null || true

        # Launch a short-lived pod that mounts the replica PVC and creates the dirs.
        # fsGroup and runAsUser are read dynamically from the primary pod above so
        # the debug pod runs as the same UID/GID that owns the PVC data — this avoids
        # "Permission denied" errors that occur when these are hardcoded.
        ${CLI_CMD} run "$debug_pod" \
            --image="$pg_image" \
            --restart=Never \
            --namespace="$SERVICES_NAMESPACE" \
            --overrides="{
              \"spec\": {
                \"restartPolicy\": \"Never\",
                \"securityContext\": { \"fsGroup\": ${fs_group} },
                \"volumes\": [{
                  \"name\": \"pgdata\",
                  \"persistentVolumeClaim\": { \"claimName\": \"${pvc_name}\" }
                }],
                \"containers\": [{
                  \"name\": \"tbs-init\",
                  \"image\": \"${pg_image}\",
                  \"command\": [\"sh\", \"-c\", \"${mkdir_cmd}\"],
                  \"volumeMounts\": [{
                    \"name\": \"pgdata\",
                    \"mountPath\": \"/var/lib/postgresql/data\"
                  }],
                  \"securityContext\": {
                    \"allowPrivilegeEscalation\": false,
                    \"capabilities\": { \"drop\": [\"ALL\"] },
                    \"runAsNonRoot\": true,
                    \"runAsUser\": ${run_as_user},
                    \"seccompProfile\": { \"type\": \"RuntimeDefault\" }
                  }
                }]
              }
            }" 2>&1

        # Poll until the pod Succeeds or Fails (max 60 s)
        local wait_elapsed=0
        local pod_status=""
        while [[ $wait_elapsed -lt 60 ]]; do
            pod_status=$(${CLI_CMD} get pod "$debug_pod" -n "$SERVICES_NAMESPACE" \
                -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
            [[ "$pod_status" == "Succeeded" || "$pod_status" == "Failed" ]] && break
            sleep 3
            wait_elapsed=$((wait_elapsed + 3))
        done

        if [[ "$pod_status" == "Succeeded" ]]; then
            success "Tablespace directories created on replica PVC: $pvc_name"
        else
            error "Debug pod $debug_pod did not succeed (phase: $pod_status)."
            error "Pod logs:"
            ${CLI_CMD} logs "$debug_pod" -n "$SERVICES_NAMESPACE" 2>/dev/null || true
            rc=1
        fi

        # Always remove the debug pod
        ${CLI_CMD} delete pod "$debug_pod" -n "$SERVICES_NAMESPACE" \
            --ignore-not-found=true 2>/dev/null || true
    done

    if [[ $rc -ne 0 ]]; then
        error "One or more replica PVCs could not be prepared."
        error "Replica pods may enter CrashLoopBackOff during WAL recovery."
        error "Manually create the tablespace directories on the affected PVCs and restart the replica pods."
        return 1
    fi

    success "All replica tablespace directories prepared successfully."
    return 0
}



################################################################################
# Function: restore_databases
# Purpose: Restores all databases from backup files to CNPG cluster
# Parameters: None (uses global variables)
# Global Variables:
#   - BACKUP_DIR: Directory containing backup .sql files
#   - DATABASES: Array of database names to restore
#   - NEW_CLUSTER: Name of the CNPG cluster
#   - NAMESPACE: Kubernetes namespace
#   - CLI_CMD: kubectl or oc command
################################################################################
# Function: validate_database_post_restore
# Purpose: Validates a restored database by comparing table counts and row estimates
# Parameters:
#   $1 - pod: CNPG pod name
#   $2 - db: Database name to validate
# Global Variables:
#   - NAMESPACE: Kubernetes namespace
#   - BACKUP_DIR: Directory containing validation files
#   - CLI_CMD: kubectl or oc command
# Returns: 0 (always succeeds, logs warnings for mismatches)
# Note: Saves validation data to post_restore_validation.txt and compares with
#       pre_backup_validation.txt if available
################################################################################
function validate_database_post_restore() {
    local pod=$1
    local db=$2
    
    info "Validating restored database: $db"
    
    # Force fresh statistics so n_live_tup is accurate (critical after restore)
    info "  Updating database statistics (ANALYZE)..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $pod -- psql -U postgres -d "dbname='$db'" -c "ANALYZE;" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        info "  ✓ Statistics updated"
    else
        warning "  ⚠ Failed to update statistics, row estimates may be inaccurate"
    fi
    
    # Get table count
    local table_count=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $pod -- psql -U postgres -d "dbname='$db'" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema');" 2>/dev/null | xargs)
    
    # Get row count estimate (n_live_tup from pg_stat_user_tables - now fresh after ANALYZE)
    local row_estimate=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $pod -- psql -U postgres -d "dbname='$db'" -t -c "SELECT SUM(n_live_tup) FROM pg_stat_user_tables;" 2>/dev/null | xargs)
    
    # Get database size
    local db_size=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $pod -- psql -U postgres -d "dbname='$db'" -t -c "SELECT pg_size_pretty(pg_database_size(\$\$${db}\$\$));" 2>/dev/null | xargs)
    
    # Save validation data
    echo "$db|$table_count|$row_estimate|$db_size" >> "$BACKUP_DIR/post_restore_validation.txt"
    
    info "  Tables: $table_count, Estimated Rows: $row_estimate (from fresh statistics), Size: $db_size"
    
    # Compare with pre-backup data
    if [[ -f "$BACKUP_DIR/pre_backup_validation.txt" ]]; then
        local pre_data=$(grep "^$db|" "$BACKUP_DIR/pre_backup_validation.txt")
        local pre_tables=$(echo "$pre_data" | cut -d'|' -f2)
        local pre_rows=$(echo "$pre_data" | cut -d'|' -f3)
        
        if [[ "$table_count" == "$pre_tables" ]]; then
            success "  ✓ Table count matches: $table_count"
        else
            warning "  ⚠ Table count mismatch: Pre=$pre_tables, Post=$table_count"
        fi
        
        # Allow 5% variance in row count (due to ANALYZE estimates)
        # Note: With fresh ANALYZE on both sides, variance should be minimal (<1%)
        if [[ -n "$pre_rows" ]] && [[ -n "$row_estimate" ]] && [[ "$pre_rows" != "null" ]] && [[ "$row_estimate" != "null" ]]; then
            local diff=$((row_estimate - pre_rows))
            local abs_diff=${diff#-}
            local threshold=$((pre_rows * 5 / 100))
            
            if [[ $abs_diff -le $threshold ]]; then
                success "  ✓ Row count matches: $row_estimate (variance: $diff rows, ${abs_diff} from pre-backup)"
            else
                warning "  ⚠ Row count variance exceeds 5%: Pre=$pre_rows, Post=$row_estimate (diff: $diff)"
                warning "  Note: This compares statistical estimates. Verify with exact counts if concerned."
            fi
        fi
    fi
}

################################################################################
# Function: compare_validation_results
# Purpose: Compares pre-backup and post-restore validation data for all databases
# Parameters: None (uses global variables)
# Global Variables:
#   - BACKUP_DIR: Directory containing validation files
# Returns: 0 (always succeeds)
# Note: Displays formatted comparison table showing table counts and row estimates
#       before and after migration
################################################################################
function compare_validation_results() {
    info "=== VALIDATION COMPARISON ==="
    
    if [[ ! -f "$BACKUP_DIR/pre_backup_validation.txt" ]] || [[ ! -f "$BACKUP_DIR/post_restore_validation.txt" ]]; then
        warning "Validation files not found, skipping comparison."
        return 0
    fi
    
    info "Database validation summary:"
    echo ""
    printf "%-20s %-10s %-15s %-15s %-10s\n" "Database" "Tables" "Rows (Pre)" "Rows (Post)" "Status"
    printf "%-20s %-10s %-15s %-15s %-10s\n" "--------" "------" "-----------" "-----------" "------"
    
    while IFS='|' read -r db tables rows size; do
        local post_line=$(grep "^$db|" "$BACKUP_DIR/post_restore_validation.txt" 2>/dev/null)
        if [[ -n "$post_line" ]]; then
            local post_tables=$(echo "$post_line" | cut -d'|' -f2)
            local post_rows=$(echo "$post_line" | cut -d'|' -f3)
            
            local status="✓ OK"
            if [[ "$tables" != "$post_tables" ]]; then
                status="⚠ WARN"
            fi
            
            printf "%-20s %-10s %-15s %-15s %-10s\n" "$db" "$tables" "$rows" "$post_rows" "$status"
        fi
    done < "$BACKUP_DIR/pre_backup_validation.txt"
    
    echo ""
    success "Validation comparison complete. Check files for details:"
    info "  Pre-backup:  $BACKUP_DIR/pre_backup_validation.txt"
    info "  Post-restore: $BACKUP_DIR/post_restore_validation.txt"
}

# Returns: 0 on success, exits on error
# Note: Uses psql to restore each database from its backup file
################################################################################
function restore_databases() {
    info "=== PHASE: RESTORING DATABASES ==="
    
    # Get CNPG pod name (primary) - use name-based search
    info "Looking for IBM CloudNativePG PostgreSQL primary pod..."
    
    # CNPG pods are named: <cluster-name>-1, <cluster-name>-2, etc.
    # Primary is typically -1
    local CNPG_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${NEW_CLUSTER}-1 " | awk '{print $1}')
    
    # If -1 not found, try any pod from the cluster
    if [[ -z "$CNPG_POD" ]]; then
        CNPG_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${NEW_CLUSTER}-" | head -1 | awk '{print $1}')
    fi
    
    if [[ -z "$CNPG_POD" ]]; then
        error "Could not find IBM CloudNativePG PostgreSQL pod."
        error "Expected pod name pattern: ${NEW_CLUSTER}-1"
        error "Available pods in namespace $SERVICES_NAMESPACE:"
        ${CLI_CMD} get pods -n $SERVICES_NAMESPACE
        return 1
    fi
    
    info "Using IBM CloudNativePG pod: $CNPG_POD"
    
    # Check if databases have already been restored
    info "Checking if databases have already been restored..."
    local already_restored=0
    local databases_with_data=0
    
    for db in "${DATABASES[@]}"; do
        # Check if database exists and has tables
        local table_count=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -d "dbname='$db'" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema');" 2>/dev/null | xargs || echo "0")
        
        if [[ "$table_count" != "0" ]] && [[ -n "$table_count" ]]; then
            databases_with_data=$((databases_with_data + 1))
            info "  Database '$db' already has $table_count tables"
        fi
    done
    
    if [[ $databases_with_data -gt 0 ]]; then
        warning "Found $databases_with_data database(s) that already contain data!"
        warning "This suggests the restore has already been completed."
        echo ""
        if [[ "$SKIP_FOR_API" != "true" ]]; then
            read -p "Do you want to skip restore and proceed to validation? (yes/no): " skip_restore
        else
            skip_restore="yes"
        fi
        
        if [[ "$skip_restore" = "yes" ]]; then
            info "Skipping restore, proceeding to validation..."
            
            # Run post-restore validation
            info "=== POST-RESTORE VALIDATION ==="
            for db in "${DATABASES[@]}"; do
                validate_database_post_restore "$CNPG_POD" "$db"
            done
            success "Post-restore validation complete."
            
            # Compare results
            compare_validation_results
            return 0
        else
            warning "Continuing with restore - this will DROP and recreate databases!"
            echo ""
            if [[ "$SKIP_FOR_API" != "true" ]]; then
                read -p "Are you absolutely sure? (yes/no): " confirm_restore
                if [[ "$confirm_restore" != "yes" ]]; then
                    info "Restore aborted by user."
                    echo ""
                    displayEdbMigrationRetryMessage "restore" "$SERVICES_NAMESPACE" "$cp4a_operator_csv_version"
                    exit 1
                fi
            fi
        fi
    fi
    
    # Create restore directory
    info "Creating restore directory in pod..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- mkdir -p $RESTORE_DIR
    
    # Copy backup files to pod
    info "Copying backup files to pod..."
    ${CLI_CMD} cp "$BACKUP_DIR/globals.sql" $SERVICES_NAMESPACE/$CNPG_POD:$RESTORE_DIR/globals.sql
    
    # Copy database ownership and grants file if it exists
    if [[ -f "$BACKUP_DIR/db_ownership_grants.sql" ]]; then
        ${CLI_CMD} cp "$BACKUP_DIR/db_ownership_grants.sql" $SERVICES_NAMESPACE/$CNPG_POD:$RESTORE_DIR/db_ownership_grants.sql
    fi

    # Copy per-database session defaults file if it exists
    if [[ -f "$BACKUP_DIR/db_session_defaults.sql" ]]; then
        ${CLI_CMD} cp "$BACKUP_DIR/db_session_defaults.sql" $SERVICES_NAMESPACE/$CNPG_POD:$RESTORE_DIR/db_session_defaults.sql
    fi

    # Copy schema-level grants file if it exists (PG14→PG16: public schema grants revoked by default)
    if [[ -f "$BACKUP_DIR/schema_grants.sql" ]]; then
        ${CLI_CMD} cp "$BACKUP_DIR/schema_grants.sql" $SERVICES_NAMESPACE/$CNPG_POD:$RESTORE_DIR/schema_grants.sql
    fi
    
    for db in "${DATABASES[@]}"; do
        info "Copying $db.dump..."
        ${CLI_CMD} cp "$BACKUP_DIR/$db.dump" $SERVICES_NAMESPACE/$CNPG_POD:$RESTORE_DIR/$db.dump
    done
    
    success "Backup files copied to pod."
    
    # STEP 1: Create all databases first (before restoring globals)
    # This ensures that database-level GRANTs in globals.sql will succeed
    info "Creating all databases..."
    for db in "${DATABASES[@]}"; do
        info "Creating database: $db"
        
        # Drop database if exists (for app database created by bootstrap)
        # Use double-quoted identifier to preserve case (e.g. ADPGG_scy must not become adpgg_scy)
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -c "DROP DATABASE IF EXISTS \"$db\";" || true
        
        # Create database with UTF8 encoding
        # Double-quoted identifier preserves mixed-case database names
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -c "CREATE DATABASE \"$db\" ENCODING 'UTF8';"
        
        success "Database $db created."
    done
    echo ""
    
    # STEP 2: Restore globals (roles and database-level permissions from globals.sql)
    # Tablespace CREATE statements are intentionally skipped here — the EDB tablespace
    # directories (e.g. /var/lib/postgresql/data/gcddb) do not exist on the CNPG pod.
    # Tablespaces are recreated in Step 2.1 below with CNPG-compatible paths.
    # All other globals (roles, GRANTs) are restored normally.
    info "Restoring global objects (roles, database permissions)..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
        grep -v '^CREATE TABLESPACE\|^ALTER TABLESPACE\|^COMMENT ON TABLESPACE' \
        $RESTORE_DIR/globals.sql | \
        ${CLI_CMD} exec -i -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres || true
    success "Globals restored (some errors are expected for pre-existing roles)."
    echo ""

    # STEP 2.1: Recreate tablespaces from globals.sql with CNPG-compatible paths.
    #
    # Background: EDB clusters define named tablespaces (e.g. bawtos_tbs, gcddb_tbs)
    # with locations pointing to EDB-specific directories (/var/lib/postgresql/data/<name>).
    # Applications such as FileNet CPE hardcode TABLESPACE <name> in their DDL
    # (e.g. "CREATE TABLE ... TABLESPACE bawtos_tbs") — if the tablespace does not
    # exist the statement fails with "tablespace does not exist".
    #
    # The CNPG pod has a single PVC mounted at /var/lib/postgresql/data/pgdata.
    # We recreate each EDB tablespace as a subdirectory under pgdata so the named
    # tablespace exists and applications can create objects in it.  All existing
    # data was already restored into pg_default via --no-tablespaces on pg_restore,
    # so this step only ensures future DDL that references the tablespace succeeds.
    info "Recreating tablespaces with CNPG-compatible paths (under pgdata)..."
    local ts_base="/var/lib/postgresql/data/pgdata"
    # Parse tablespace definitions from globals.sql:
    # Line format: CREATE TABLESPACE <name> OWNER <owner> LOCATION '<path>';
    local ts_names ts_owners
    ts_names=()
    ts_owners=()
    while IFS= read -r line; do
        local ts_name ts_owner
        ts_name=$(echo "$line" | awk '{print $3}')
        ts_owner=$(echo "$line" | awk '{print $5}')
        [[ -z "$ts_name" || -z "$ts_owner" ]] && continue
        ts_names+=("$ts_name")
        ts_owners+=("$ts_owner")
    done < <(grep '^CREATE TABLESPACE' "$BACKUP_DIR/globals.sql" 2>/dev/null)

    if [[ ${#ts_names[@]} -eq 0 ]]; then
        info "  No custom tablespaces found in globals.sql — skipping."
    else
        local i
        for i in "${!ts_names[@]}"; do
            local ts="${ts_names[$i]}"
            local owner="${ts_owners[$i]}"
            local ts_dir="${ts_base}/${ts}"
            # Create the directory inside the CNPG pod
            ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- mkdir -p "${ts_dir}" 2>/dev/null || true
            # Create the tablespace (idempotent — skip if already exists)
            local result
            result=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
                psql -U postgres -t -A -c \
                "SELECT 1 FROM pg_tablespace WHERE spcname = \$\$${ts}\$\$;" 2>/dev/null | xargs)
            if [[ "$result" == "1" ]]; then
                info "    Tablespace already exists: ${ts} — skipping"
            else
                ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
                    psql -U postgres -c \
                    "CREATE TABLESPACE \"${ts}\" OWNER \"${owner}\" LOCATION '${ts_dir}';" \
                    2>/dev/null && info "    Created tablespace: ${ts} → ${ts_dir}" \
                    || warning "    Could not create tablespace ${ts} — verify manually"
            fi
        done
        success "  ✓ Tablespaces recreated (${#ts_names[@]} processed)"
    fi
    echo ""
    
    # STEP 2.5: Apply database-level ownership and grants
    # This ensures all databases have correct ownership and permissions
    # even if pg_dumpall --globals-only didn't capture them
    if ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- test -f $RESTORE_DIR/db_ownership_grants.sql 2>/dev/null; then
        info "Applying database-level ownership and grants..."
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -f $RESTORE_DIR/db_ownership_grants.sql || true
        success "Database ownership and grants applied."
        echo ""
    else
        warning "Database ownership/grants file not found, skipping this step."
        echo ""
    fi

    # STEP 2.6: Apply per-database session defaults (search_path, etc.)
    # pg_dumpall --globals-only does NOT capture ALTER DATABASE ... SET search_path.
    # These are required by CP4BA components (e.g. ADPGG) to find the correct schema
    # without qualifying every object reference.
    if ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- test -f $RESTORE_DIR/db_session_defaults.sql 2>/dev/null; then
        info "Applying per-database session defaults (search_path etc.)..."
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -f $RESTORE_DIR/db_session_defaults.sql || true
        success "Per-database session defaults applied."
        echo ""
    else
        info "No per-database session defaults file found, skipping."
        echo ""
    fi

    # STEP 2.7: Re-apply schema-level grants (PG14 → PG16 behaviour change)
    # PostgreSQL 16 revoked the implicit USAGE+CREATE ON SCHEMA public TO PUBLIC grant
    # that existed in PG14.  Without this step application users (e.g. adpuser) lose
    # access to the public schema and cannot reach their tables (git_service_* etc.)
    # after migration.  The file was produced by backup_databases() from pg_namespace.nspacl
    # and pg_default_acl in the source cluster.
    if ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- test -s $RESTORE_DIR/schema_grants.sql 2>/dev/null; then
        info "Re-applying schema-level grants (PG14→PG16 public schema fix)..."
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -f $RESTORE_DIR/schema_grants.sql || true
        success "Schema-level grants applied."
        echo ""
    else
        info "No schema grants file found or file is empty, skipping (schemas will use PG16 defaults)."
        echo ""
    fi

    # STEP 3: Restore data for each database
    info "Restoring data for all databases..."
    for db in "${DATABASES[@]}"; do
        info "Restoring data to database: $db"
        
        # Restore data using pg_restore.
        # Use the dbname= keyword form so that mixed-case names (e.g. ADPGG_scy) are
        # passed verbatim to libpq and are not silently lowercased by the connstring parser.
        # --no-tablespaces: the CNPG pod filesystem does not have the original EDB
        # tablespace directories (e.g. /pgsqldata/<db>); without this flag pg_restore
        # would fail trying to SET default_tablespace = <name> before creating objects.
        # --exit-on-error: surface the first real error instead of silently continuing.
        if ! ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
            pg_restore -U postgres \
            --no-tablespaces \
            --exit-on-error \
            -d "dbname='$db'" \
            $RESTORE_DIR/$db.dump; then
            local exit_code=$?
            error "pg_restore failed for database $db with exit code $exit_code"
            return 1
        fi

        # STEP 3.5: Ensure the user-owned schema exists inside each database.
        # The original EDB provisioning script ran:
        #   psql -d $db -U postgres -c "create schema if not exists authorization \"$dbuser\";"
        # pg_restore only re-creates a schema when the dump actually contains it
        # (e.g. empty databases lose their schema). Re-creating it here mirrors
        # that provisioning step and prevents "no schema has been selected to
        # create in" errors (e.g. Liquibase startup) after migration.
        local db_owner
        # Use quote_literal to safely match the database name regardless of case.
        db_owner=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
            psql -U postgres -t -A -c \
            "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname=\$\$${db}\$\$;" \
            2>/dev/null | xargs)

        if [[ -n "$db_owner" ]] && [[ "$db_owner" != "postgres" ]]; then
            info "Ensuring user-owned schema '$db_owner' exists in database '$db'..."
            ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
                psql -U postgres -d "dbname='$db'" -c \
                "CREATE SCHEMA IF NOT EXISTS \"$db_owner\" AUTHORIZATION \"$db_owner\";" \
                && success "  ✓ Schema '$db_owner' present in '$db'" \
                || warning "  ⚠ Could not create schema '$db_owner' in '$db' — verify manually"

            # STEP 3.5a: Move tables from public into the owner schema.
            #
            # Background: EDB provisioned databases with a user-owned schema
            # (e.g. adpuser) AND set search_path = adpuser, public on the role/db.
            # Applications (e.g. gitgateway) connect with search_path=adpuser and
            # expect their tables there. However, Liquibase/JPA sometimes creates
            # tables in the public schema (the second entry in search_path) because
            # the public schema has CREATE granted on PG14.
            #
            # pg_restore behaviour varies by EDB cluster configuration:
            #
            # Case A — shells in owner schema + data in public (pg_dump artifact):
            #   pg_dump emits a search_path header pointing to the owner schema.
            #   pg_restore creates empty DDL shells in the owner schema AND restores
            #   actual data rows into public (where they physically lived on EDB).
            #   Result: empty tables in adpuser + data-bearing tables in public.
            #   The app hits the empty adpuser tables first → sees 0 rows.
            #
            # Case B — all tables only in public, owner schema empty:
            #   Some EDB clusters provision without a search_path header in the dump,
            #   so pg_restore places everything into public with no shells in the owner
            #   schema. The owner schema exists (created by EDB provisioning) but has
            #   0 tables. The app search_path resolves adpuser (empty) then public
            #   (data) — which works with default PG search_path but breaks when
            #   gitgateway sets an explicit search_path=adpuser at connect time.
            #
            # Fix for both cases: move ALL tables from public into the owner schema.
            # - Case A: DROP the owner shell (CASCADE) then ALTER TABLE public → owner.
            # - Case B: No shell to drop; ALTER TABLE public → owner directly.
            # In both cases the result is identical: all tables in owner schema only,
            # public is clean, and search_path=adpuser resolves correctly.
            info "  Moving tables from public schema into '$db_owner' schema (search_path alignment)..."
            ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
                psql -U postgres -d "dbname='$db'" -t -A -c \
                "SELECT tablename FROM pg_tables
                 WHERE schemaname = 'public'
                   AND tableowner = \$\$${db_owner}\$\$;" \
                2>/dev/null | while IFS= read -r tbl; do
                    [[ -z "$tbl" ]] && continue
                    # Drop owner-schema shell if it exists (Case A), no-op for Case B
                    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
                        psql -U postgres -d "dbname='$db'" -c \
                        "DROP TABLE IF EXISTS \"${db_owner}\".\"${tbl}\" CASCADE;" \
                        2>/dev/null || true
                    info "    Moving to owner schema: public.${tbl} → ${db_owner}.${tbl}"
                    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
                        psql -U postgres -d "dbname='$db'" -c \
                        "ALTER TABLE public.\"${tbl}\" SET SCHEMA \"${db_owner}\";" \
                        2>/dev/null || true
                done
            success "  ✓ Table schema alignment complete for '$db_owner' in '$db'"

            # STEP 3.5b: Move enum types from public into the owner schema.
            #
            # Mirrors Step 3.5a — same two cases apply:
            #
            # Case A — shells in owner schema + real types in public (pg_dump artifact):
            #   pg_dump emits CREATE TYPE with a search_path header pointing at the owner
            #   schema. pg_restore creates empty shells (no enum labels) in owner AND the
            #   real labeled type in public. Table columns reference the public OID, but
            #   search_path resolves to the owner-schema shell (wrong OID) → runtime error
            #   "operator does not exist: public.foo <> foo".
            #
            # Case B — all types only in public, owner schema has none:
            #   Some EDB clusters produce dumps without a search_path header so pg_restore
            #   places everything into public. No shells exist in the owner schema. The
            #   same OID mismatch risk exists once tables are moved to owner schema in
            #   Step 3.5a, because table column type OIDs still reference public.
            #
            # Fix for both cases: move ALL enum types from public that are owned by
            # the db_owner role into the owner schema.
            # - Case A: DROP owner shell (CASCADE) then ALTER TYPE public → owner.
            # - Case B: No shell to drop; ALTER TYPE public → owner directly.
            info "  Moving enum types from public schema into '$db_owner' schema (search_path alignment)..."
            ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
                psql -U postgres -d "dbname='$db'" -t -A -c \
                "SELECT t.typname
                 FROM pg_type t
                 JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typtype = 'e'
                   AND n.nspname  = 'public'
                   AND pg_get_userbyid(t.typowner) = \$\$${db_owner}\$\$;" \
                2>/dev/null | while IFS= read -r typ; do
                    [[ -z "$typ" ]] && continue
                    # Drop owner-schema shell if it exists (Case A), no-op for Case B
                    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
                        psql -U postgres -d "dbname='$db'" -c \
                        "DROP TYPE IF EXISTS \"${db_owner}\".\"${typ}\" CASCADE;" \
                        2>/dev/null || true
                    info "    Moving to owner schema: public.${typ} → ${db_owner}.${typ}"
                    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- \
                        psql -U postgres -d "dbname='$db'" -c \
                        "ALTER TYPE public.\"${typ}\" SET SCHEMA \"${db_owner}\";" \
                        2>/dev/null || true
                done
            success "  ✓ Enum type schema alignment complete for '$db_owner' in '$db'"
        else
            info "Database '$db' is owned by postgres or owner unknown; skipping schema creation."
        fi

        # Run ANALYZE to update statistics
        info "Running ANALYZE on $db..."
        ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -d "dbname='$db'" -c "ANALYZE;"
        
        success "Database $db restored successfully."
    done
    
    # Cleanup restore directory
    info "Cleaning up restore directory..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- rm -rf $RESTORE_DIR
    
    success "All databases restored successfully."
    echo ""
    
    # Validate databases after restore
    info "Validating databases after restore..."
    for db in "${DATABASES[@]}"; do
        validate_database_post_restore "$CNPG_POD" "$db"
    done
    success "Post-restore validation complete."
    echo ""
    
    # Compare validation results
    compare_validation_results
    
    if [[ "$SKIP_FOR_API" != "true" ]]; then
        prompt_press_any_key_to_continue
    fi
    return 0
}

################################################################################
# Function: verify_migration
# Purpose: Verifies the migration by checking database connectivity and data
# Parameters: None (uses global variables)
# Global Variables:
#   - NEW_CLUSTER: Name of the CNPG cluster
#   - SERVICES_NAMESPACE: Kubernetes namespace where CNPG cluster exists
#   - OPERATOR_NAMESPACE: Kubernetes namespace where operator is installed
#   - DATABASES: Array of database names to verify
#   - CLI_CMD: kubectl or oc command
# Returns: 0 on success
# Note: Connects to CNPG cluster and lists databases to verify restoration
################################################################################
function verify_migration() {
    info "=== PHASE: VERIFICATION ==="
        
    # Get CNPG pod using name-based search
    local CNPG_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${NEW_CLUSTER}-1 " | awk '{print $1}')
    
    if [[ -z "$CNPG_POD" ]]; then
        CNPG_POD=$(${CLI_CMD} get pods -n $SERVICES_NAMESPACE --no-headers 2>/dev/null | grep "^${NEW_CLUSTER}-" | head -1 | awk '{print $1}')
    fi
    
    info "Verifying PostgreSQL version..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -c "SELECT version();"
    
    info "Verifying databases..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -c "\l"
    
    info "Verifying tablespaces..."
    ${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -c "\db+"
    
    info "Checking database sizes..."
    for db in "${DATABASES[@]}"; do
        local size=$(${CLI_CMD} exec -n $SERVICES_NAMESPACE $CNPG_POD -- psql -U postgres -d "dbname='$db'" -t -c "SELECT pg_size_pretty(pg_database_size(\$\$${db}\$\$));" | xargs)
        info "Database $db size: $size"
    done
    
    info "Checking key application pods..."
    info "IBM CloudNativePG cluster pods:"
    ${CLI_CMD} get pods -n $SERVICES_NAMESPACE | grep "^${NEW_CLUSTER}-\|^NAME"
    
    success "Verification complete."
    return 0
}

################################################################################
# Function: execute_backup_phase
# Purpose: Executes the complete backup phase of migration
# Parameters:
#   $1 - SERVICES_NAMESPACE: Namespace where EDB cluster and databases exist
#   $2 - OPERATOR_NAMESPACE: Namespace where operator subscription/CSV are installed
#   $3 - BACKUP_DIR: Directory to store backups
#   $4 - CR_KIND: Type of CP4BA CR (ICP4ACluster or Content)
# Returns: 0 on success, 1 on error
# Note: Orchestrates: discover_databases → scale_down_applications → backup_databases
#       Uses SERVICES_NAMESPACE for all database operations
################################################################################
function execute_backup_phase() {
    SERVICES_NAMESPACE=$1
    OPERATOR_NAMESPACE=$2
    BACKUP_DIR=$3
    CR_KIND=$4
    
    if [[ -z "$SERVICES_NAMESPACE" ]] || [[ -z "$BACKUP_DIR" ]] || [[ -z "$CR_KIND" ]]; then
        error "Missing required parameters for backup phase"
        error "Usage: execute_backup_phase <namespace> <backup_dir> <cr_kind>"
        return 1
    fi
    
    info "=== EXECUTING BACKUP PHASE ==="
    info "Services Namespace: $SERVICES_NAMESPACE"
    info "Operator Namespace: $OPERATOR_NAMESPACE"
    info "Backup Directory: $BACKUP_DIR"
    info "CR Kind: $CR_KIND"
    printf "\n"
    
    # Execute backup workflow with error handling
    if ! discover_databases; then
        error "Failed to discover databases"
        return 1
    fi

    # Capture forensic snapshot of EDB state BEFORE applications are scaled down
    # and BEFORE pg_dump runs.  Non-fatal: a failure here must not block migration.
    snapshot_edb_databases || warning "Forensic snapshot failed — migration will continue without it."

    if ! scale_down_applications; then
        error "Failed to scale down applications"
        return 1
    fi
    
    if ! backup_databases; then
        error "Failed to backup databases"
        return 1
    fi
    
    success "Backup phase completed successfully!"
    return 0
}

################################################################################
# Function: execute_create_cluster_phase
# Purpose: Executes the cluster creation phase of migration
# Parameters:
#   $1 - SERVICES_NAMESPACE: Namespace where EDB/CNPG clusters exist
#   $2 - OPERATOR_NAMESPACE: Namespace where operator subscription/CSV are installed
# Returns: 0 on success, 1 on error
# Note: Orchestrates: extract_edb_cluster_configuration → delete_edb_cluster →
#       install_cnpg_operator → deploy_cnpg_cluster
#       Configuration is extracted BEFORE deletion to preserve settings
#       OPERATOR_NAMESPACE is used for operator installation
#       SERVICES_NAMESPACE is used for cluster operations
################################################################################
function execute_create_cluster_phase() {
    SERVICES_NAMESPACE=$1
    OPERATOR_NAMESPACE=$2

    
    if [[ -z "$SERVICES_NAMESPACE" ]]; then
        error "Missing required parameter: namespace"
        error "Usage: execute_create_cluster_phase <namespace>"
        return 1
    fi
    
    info "=== EXECUTING CREATE CLUSTER PHASE ==="
    info "Services Namespace: $SERVICES_NAMESPACE"
    info "Operator Namespace: $OPERATOR_NAMESPACE"
    printf "\n"
    
    # Set flag for create-cluster mode (enables fallback to backup directory)
    CREATE_CLUSTER_ONLY=true
    #info "CREATE_CLUSTER_ONLY flag set to: $CREATE_CLUSTER_ONLY"
    
    # Get backup directory from ConfigMap for database discovery fallback
    BACKUP_DIR=$(${CLI_CMD} get configmap ${EDB_CNPG_MIGRATION_CM_NAME} -n "$SERVICES_NAMESPACE" \
        -o jsonpath='{.data.backup-directory}' 2>/dev/null)
    
    if [[ -z "$BACKUP_DIR" ]]; then
        warning "Backup directory not found in ConfigMap"
        warning "Database discovery will attempt to query EDB cluster (will fail if EDB deleted)"
    else
        info "Backup directory from ConfigMap: $BACKUP_DIR"
        if [[ -f "$BACKUP_DIR/database_list.txt" ]]; then
            info "Database list file exists: $BACKUP_DIR/database_list.txt"
        else
            warning "Database list file NOT found: $BACKUP_DIR/database_list.txt"
        fi
    fi
    
    # Load database list from backup (stored in ConfigMap) with error handling
    if ! discover_databases; then
        error "Failed to discover databases"
        error "CREATE_CLUSTER_ONLY=$CREATE_CLUSTER_ONLY"
        error "BACKUP_DIR=$BACKUP_DIR"
        return 1
    fi
    
    # Extract EDB configuration before deletion
    if ! extract_edb_cluster_configuration; then
        error "Failed to extract EDB cluster configuration"
        return 1
    fi
    
    # Execute create-cluster workflow with error handling
    if ! delete_edb_cluster; then
        error "Failed to delete EDB cluster"
        return 1
    fi
    
    if ! install_cnpg_operator; then
        error "Failed to install IBM CloudNativePG operator"
        return 1
    fi
    
    # deploy_cnpg_cluster will call generate_cnpg_manifest if needed
    if ! deploy_cnpg_cluster; then
        error "Failed to deploy IBM CloudNativePG cluster"
        return 1
    fi
    
    success "Create cluster phase completed successfully!"
    return 0
}

################################################################################
# Function: reset_cnpg_database_creation_flags
# Purpose: Resets the operator ConfigMap flags that control database creation so
#          that when the CP4BA operator reconciles after upgradeDeployment it
#          will create any databases (and their credential secrets) that do not
#          yet exist in the new CNPG cluster.  This covers databases that are
#          new in 26.0.0 (e.g. adpggdb, adsdesignerdb, runtimedb) which were
#          never present in the old EDB cluster when upgrading from 24.0.0-IF009+.
#          When upgrading from 25.0.0+ those databases already exist so the
#          flags are left unchanged.
# Parameters:
#   $1 - namespace: The services namespace (SERVICES_NAMESPACE)
# Returns: 0 on success, 1 on error
################################################################################
function reset_cnpg_database_creation_flags() {
    local namespace=$1

    info "=== RESETTING CNPG DATABASE CREATION FLAGS ==="

    # Determine the original CP4BA version from the shared-info ConfigMap.
    # The key cp4ba_original_csv_ver_for_upgrade_script is written by
    # upgradeOperator before migration begins and follows the pattern X.Y.Z
    # where X.Y.Z maps to the operator CSV version (e.g. 24.0.9 = IF009).
    local original_csv_ver=""
    original_csv_ver=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info \
        -n "$namespace" \
        -o jsonpath='{.data.cp4ba_original_csv_ver_for_upgrade_script}' \
        2>/dev/null || echo "")

    if [[ -z "$original_csv_ver" ]]; then
        original_csv_ver=$(${CLI_CMD} get configmap ibm-cp4ba-content-shared-info \
            -n "$namespace" \
            -o jsonpath='{.data.cp4ba_original_csv_ver_for_upgrade_script}' \
            2>/dev/null || echo "")
    fi

    info "Detected original CP4BA version: ${original_csv_ver:-<unknown>}"

    # Only reset the flags when upgrading from 24.0.0-IF009+ (version 24.0.*).
    # When upgrading from 25.0.0 or 26.0.0 the ADPGG/adsdesignerdb/adsruntimedb databases already exist
    # in CNPG so there is nothing for the operator to create.
    if [[ -n "$original_csv_ver" ]] && [[ "$original_csv_ver" != 24.0.* ]]; then
        info "Skipping flag reset: upgrade source is '$original_csv_ver' (not 24.0.x)."
        info "ADP/ADS databases are expected to already exist in the CNPG cluster."
        return 0
    fi

    info "Upgrade source is 24.0.x – resetting flags so the CP4BA operator"
    info "creates any missing databases and credential secrets on next reconciliation."

    local failed=0

    if ${CLI_CMD} patch configmap ibm-cp4ba-shared-info -n "$namespace" \
            --type merge -p '{"data":{"edb_cluster_cr_applied":"False"}}' >&3 2>&3; then
        success "Patched ibm-cp4ba-shared-info: edb_cluster_cr_applied=False"
    else
        error "Failed to patch ibm-cp4ba-shared-info in namespace $namespace"
        failed=1
    fi

    if ${CLI_CMD} patch configmap postgresql-operator-controller-manager-config -n "$namespace" \
            --type merge -p '{"data":{"DATABASE_CREATED":"False"}}' >&3 2>&3; then
        success "Patched postgresql-operator-controller-manager-config: DATABASE_CREATED=False"
    else
        error "Failed to patch postgresql-operator-controller-manager-config in namespace $namespace"
        failed=1
    fi

    if [[ $failed -eq 1 ]]; then
        return 1
    fi

    info "The CP4BA operator will create any missing databases and secrets"
    info "automatically when the CR is applied during upgradeDeployment."
    return 0
}

################################################################################
# Function: execute_restore_phase
# Purpose: Executes the restore phase of migration
# Parameters:
#   $1 - SERVICES_NAMESPACE: Namespace where CNPG cluster and databases exist
#   $2 - OPERATOR_NAMESPACE: Namespace where operator subscription/CSV are installed
#   $3 - BACKUP_DIR: Directory containing backup files
# Returns: 0 on success, 1 on error
# Note: Orchestrates: discover_databases → restore_databases →
#       reset_cnpg_database_creation_flags → verify_migration
#       Uses SERVICES_NAMESPACE for all database operations
################################################################################
function execute_restore_phase() {
    SERVICES_NAMESPACE=$1
    OPERATOR_NAMESPACE=$2
    BACKUP_DIR=$3
    
    if [[ -z "$SERVICES_NAMESPACE" ]] || [[ -z "$BACKUP_DIR" ]]; then
        error "Missing required parameters for restore phase"
        error "Usage: execute_restore_phase <namespace> <backup_dir>"
        return 1
    fi
    
    info "=== EXECUTING RESTORE PHASE ==="
    info "Services Namespace: $SERVICES_NAMESPACE"
    info "Operator Namespace: $OPERATOR_NAMESPACE"
    info "Backup Directory: $BACKUP_DIR"
    printf "\n"
    
    # Set flag for restore mode (uses backup directory)
    RESTORE_ONLY=true

    # Pre-create tablespace directories on replica PVCs.
    # This is needed both when create-cluster ran normally AND when the IBM PG
    # cluster was pre-existing and create-cluster was skipped entirely (e.g. the
    # user deployed the cluster manually or re-runs only the restore phase).
    # prepare_replica_tablespace_dirs is a no-op when EDB_INSTANCES <= 1 or when
    # there are no custom tablespaces in globals.sql.
    # Always re-read EDB_INSTANCES from the live cluster spec here — the script-level
    # default of "1" cannot be trusted when create-cluster was skipped (the variable
    # was never updated by extract_edb_cluster_configuration).
    local live_instances
    live_instances=$(${CLI_CMD} get cluster.pg.ibm.com "$NEW_CLUSTER" \
        -n "$SERVICES_NAMESPACE" \
        -o jsonpath='{.spec.instances}' 2>/dev/null || echo "")
    if [[ -n "$live_instances" ]]; then
        EDB_INSTANCES="$live_instances"
        info "EDB_INSTANCES read from live cluster spec: $EDB_INSTANCES"
    else
        info "Could not read instances from cluster spec — using current value: $EDB_INSTANCES"
    fi
    if ! prepare_replica_tablespace_dirs; then
        warning "Replica tablespace directory preparation had errors (see above)."
        warning "Continuing with restore — check replica pod logs if it enters CrashLoopBackOff."
    fi

    # Load database list from backup with error handling
    if ! discover_databases; then
        error "Failed to discover databases"
        return 1
    fi
    
    # Execute restore workflow with error handling
    if ! restore_databases; then
        error "Failed to restore databases"
        return 1
    fi
    
    # Reset operator flags so the CP4BA operator creates any databases that are
    # new in 26.0.0 (e.g. adpggdb, adsdesignerdb, runtimedb) and their
    # credential secrets on the next reconciliation after upgradeDeployment.
    if ! reset_cnpg_database_creation_flags "$SERVICES_NAMESPACE"; then
        error "Failed to reset CNPG database creation flags"
        return 1
    fi
    
    # Run forensic snapshot diff to surface any data or ACL regression
    # before declaring the migration complete.  Non-fatal: differences are
    # reported to the operator but do not abort the migration.
    compare_snapshot_post_restore || warning "Snapshot comparison failed — review $BACKUP_DIR/snapshot/diff_report.txt manually."

    if ! verify_migration; then
        error "Failed to verify migration"
        return 1
    fi
    
    success "Restore phase completed successfully!"
    return 0
}
