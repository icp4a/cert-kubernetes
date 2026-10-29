#!/usr/bin/env bash
# ==============================================================================
# Script: wfps-migrate-edb-to-cnpg.sh
# Purpose: Backup WfPS PostgreSQL database from EDB (before upgrade) and restore 
#          to IBM CloudNativePG / PostgreSQL 16 (after upgrade).
#
# Usage:
#   1. BEFORE upgradeOperator:
#      ./wfps-migrate-edb-to-cnpg.sh -m backup -n <namespace> [-c <cluster_name>]
#
#   2. AFTER upgradeDeploymentStatus (post CR apply):
#      ./wfps-migrate-edb-to-cnpg.sh -m restore -n <namespace> [-c <cluster_name>]
# ==============================================================================

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

function warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

function error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

function usage() {
    echo "Usage: $0 -m <backup|restore> -n <namespace> [-c <cluster_name>] [-d <backup_dir>]"
    echo ""
    echo "Options:"
    echo "  -m, --mode          Mode of operation: 'backup' (run before upgrade) or 'restore' (run after upgrade)"
    echo "  -n, --namespace     Target Kubernetes/OpenShift namespace where WfPS is deployed"
    echo "  -c, --cluster-name  (Optional) PostgreSQL cluster name prefix (default: auto-discovered or wfps-instance1-postgre)"
    echo "  -d, --backup-dir    (Optional) Local directory to store dump files (default: /tmp/wfps_migration_backup)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -m backup -n cp4ba"
    echo "  $0 -m restore -n cp4ba"
    exit 1
}

# Determine CLI command (oc or kubectl)
if command -v oc &> /dev/null; then
    CLI_CMD="oc"
elif command -v kubectl &> /dev/null; then
    CLI_CMD="kubectl"
else
    error "Neither 'oc' nor 'kubectl' command line tool found in PATH."
    exit 1
fi

# Parse Arguments
MODE=""
NAMESPACE=""
CLUSTER_NAME=""
BACKUP_DIR="/tmp/wfps_migration_backup"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -c|--cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -d|--backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option: $1"
            usage
            ;;
    esac
done

if [[ -z "$MODE" || -z "$NAMESPACE" ]]; then
    error "Both --mode and --namespace parameters are required."
    usage
fi

if [[ "$MODE" != "backup" && "$MODE" != "restore" ]]; then
    error "Invalid mode '$MODE'. Valid options are: 'backup' or 'restore'."
    usage
fi

# ------------------------------------------------------------------------------
# Backup Function: Run BEFORE ./cp4a-deployment.sh -m upgradeOperator
# ------------------------------------------------------------------------------
function do_backup() {
    info "================================================================="
    info "Starting WfPS EDB Database Backup in namespace: $NAMESPACE"
    info "================================================================="

    # Auto-discover EDB Cluster if not specified
    if [[ -z "$CLUSTER_NAME" ]]; then
        info "Auto-discovering EDB PostgreSQL cluster in namespace $NAMESPACE..."
        local edb_clusters
        edb_clusters=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io -n "$NAMESPACE" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true)
        
        if [[ -n "$edb_clusters" ]]; then
            # Prefer cluster ending with -postgre or take the first one
            CLUSTER_NAME=$(echo "$edb_clusters" | grep -E -- "-postgre$" | head -n 1 || echo "$edb_clusters" | head -n 1)
            info "Found EDB Cluster: $CLUSTER_NAME"
        else
            error "No EDB cluster (postgresql.k8s.enterprisedb.io) found in namespace '$NAMESPACE'."
            exit 1
        fi
    fi

    # Find the active primary EDB Pod
    local edb_pod="${CLUSTER_NAME}-1"
    info "Checking connectivity to EDB pod: $edb_pod"
    if ! ${CLI_CMD} get pod "$edb_pod" -n "$NAMESPACE" &>/dev/null; then
        # Try finding pod by label
        edb_pod=$(${CLI_CMD} get pods -n "$NAMESPACE" -l "postgresql.k8s.enterprisedb.io/cluster=$CLUSTER_NAME" --no-headers -o custom-columns=":metadata.name" | head -n 1 || true)
        if [[ -z "$edb_pod" ]]; then
            error "Could not find any running pod for EDB cluster '$CLUSTER_NAME' in namespace '$NAMESPACE'."
            exit 1
        fi
    fi

    info "Using EDB Pod: $edb_pod"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    info "Backup files will be saved to: $BACKUP_DIR"

    # 1. Export Global Roles and Passwords
    info "Step 1/3: Exporting global roles, users, and password hashes..."
    if ! ${CLI_CMD} exec -i "$edb_pod" -n "$NAMESPACE" -c postgres -- pg_dumpall -U postgres --globals-only > "${BACKUP_DIR}/globals.sql"; then
        error "Failed to export globals from EDB cluster."
        exit 1
    fi
    info "Globals exported successfully -> ${BACKUP_DIR}/globals.sql"

    # 2. Discover User Databases
    info "Step 2/3: Discovering user databases in EDB cluster..."
    local databases
    databases=$(${CLI_CMD} exec -i "$edb_pod" -n "$NAMESPACE" -c postgres -- psql -U postgres -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');" | tr -d '\r')

    if [[ -z "$databases" ]]; then
        warning "No custom user databases found, defaulting to 'wfpsdb'."
        databases="wfpsdb"
    fi

    echo "$databases" > "${BACKUP_DIR}/databases.list"
    info "Databases to export: $(echo $databases | tr '\n' ' ')"

    # 3. Export each database via pg_dump (-Fc format)
    info "Step 3/3: Exporting database dumps..."
    for db in $databases; do
        [[ -z "$db" ]] && continue
        info "Dumping database '$db'..."
        if ! ${CLI_CMD} exec -i "$edb_pod" -n "$NAMESPACE" -c postgres -- pg_dump -U postgres -Fc -d "$db" > "${BACKUP_DIR}/${db}.dump"; then
            error "Failed to dump database '$db'."
            exit 1
        fi
        info "Database '$db' dumped successfully -> ${BACKUP_DIR}/${db}.dump"
    done

    # Record cluster metadata for restore
    echo "$CLUSTER_NAME" > "${BACKUP_DIR}/cluster_name.txt"

    info "================================================================="
    info "SUCCESS: WfPS Database Backup completed."
    info "Backup location: $BACKUP_DIR"
    ls -lh "$BACKUP_DIR"
    info "You may now proceed with the CP4BA / WfPS operator upgrade commands."
    info "================================================================="
}

# ------------------------------------------------------------------------------
# Restore Function: Run AFTER upgradeDeploymentStatus (post CR apply)
# ------------------------------------------------------------------------------
function do_restore() {
    info "================================================================="
    info "Starting WfPS IBM CloudNativePG Restore in namespace: $NAMESPACE"
    info "================================================================="

    if [[ ! -f "${BACKUP_DIR}/globals.sql" ]]; then
        error "Backup file '${BACKUP_DIR}/globals.sql' not found in $BACKUP_DIR."
        error "Please ensure you have run backup mode (-m backup) before running restore."
        exit 1
    fi

    # Read previous cluster name if available
    if [[ -z "$CLUSTER_NAME" && -f "${BACKUP_DIR}/cluster_name.txt" ]]; then
        CLUSTER_NAME=$(cat "${BACKUP_DIR}/cluster_name.txt" | tr -d '\r\n')
    fi

    # Auto-discover target IBM CNPG (pg.ibm.com) Cluster
    if [[ -z "$CLUSTER_NAME" ]]; then
        info "Auto-discovering IBM CloudNativePG cluster in namespace $NAMESPACE..."
        local cnpg_clusters
        cnpg_clusters=$(${CLI_CMD} get clusters.pg.ibm.com -n "$NAMESPACE" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true)
        
        if [[ -n "$cnpg_clusters" ]]; then
            CLUSTER_NAME=$(echo "$cnpg_clusters" | grep -E -- "-postgre$" | head -n 1 || echo "$cnpg_clusters" | head -n 1)
            info "Found IBM CloudNativePG Cluster: $CLUSTER_NAME"
        else
            error "No IBM CloudNativePG cluster (clusters.pg.ibm.com) found in namespace '$NAMESPACE'."
            exit 1
        fi
    fi

    # Find the primary IBM CNPG Pod
    info "Locating primary pod for IBM CloudNativePG cluster '$CLUSTER_NAME'..."
    local cnpg_pod="${CLUSTER_NAME}-1"
    if ! ${CLI_CMD} get pod "$cnpg_pod" -n "$NAMESPACE" &>/dev/null; then
        cnpg_pod=$(${CLI_CMD} get pods -n "$NAMESPACE" -l "pg.ibm.com/cluster=$CLUSTER_NAME" --no-headers -o custom-columns=":metadata.name" | head -n 1 || true)
        if [[ -z "$cnpg_pod" ]]; then
            error "Could not find any running pod for IBM CNPG cluster '$CLUSTER_NAME' in namespace '$NAMESPACE'."
            exit 1
        fi
    fi

    info "Using IBM CloudNativePG Pod: $cnpg_pod"

    # 1. Restore Globals (Roles/Users)
    info "Step 1/5: Restoring global roles and credentials into PostgreSQL 16..."
    cat "${BACKUP_DIR}/globals.sql" | ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- psql -U postgres || true
    info "Global roles restored."

    # 2. Restore Databases
    info "Step 2/5: Restoring database schemas and tables..."
    for dump_file in "${BACKUP_DIR}"/*.dump; do
        [[ ! -f "$dump_file" ]] && continue
        local db
        db=$(basename "$dump_file" .dump)
        info "Restoring database '$db'..."

        # Create database if not existing
        ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- psql -U postgres -c "CREATE DATABASE \"$db\" ENCODING 'UTF8';" 2>/dev/null || true

        # Restore dump with --clean --if-exists --no-owner --no-tablespaces
        cat "$dump_file" | ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- pg_restore -U postgres -d "$db" --clean --if-exists --no-owner --no-tablespaces || true

        # Analyze table stats
        ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- psql -U postgres -d "$db" -c "ANALYZE;"
        info "Database '$db' restored and analyzed."
    done

    # 3. Synchronize Application Secret Password & Grant Schema Privileges
    info "Step 3/5: Synchronizing PostgreSQL user credentials with Kubernetes secret..."
    local app_secret="${CLUSTER_NAME}-app"
    if ! ${CLI_CMD} get secret "$app_secret" -n "$NAMESPACE" &>/dev/null; then
        app_secret=$(${CLI_CMD} get secret -n "$NAMESPACE" -l "pg.ibm.com/cluster=$CLUSTER_NAME" --no-headers 2>/dev/null | grep -E "(app|-app)" | awk '{print $1}' | head -n 1 || echo "${CLUSTER_NAME}-app")
    fi

    local db_user db_pass
    db_user=$(${CLI_CMD} get secret "$app_secret" -n "$NAMESPACE" -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || echo "wfpsuser")
    db_pass=$(${CLI_CMD} get secret "$app_secret" -n "$NAMESPACE" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "")

    if [[ -n "$db_pass" ]]; then
        info "Updating password for database user '$db_user' and granting schema privileges..."
        ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- psql -U postgres -d wfpsdb <<EOF || true
ALTER USER wfpsuser WITH PASSWORD '$db_pass';
ALTER USER "$db_user" WITH PASSWORD '$db_pass';
ALTER DATABASE wfpsdb OWNER TO wfpsuser;
GRANT ALL ON SCHEMA public TO wfpsuser;
GRANT ALL ON SCHEMA wfpsuser TO wfpsuser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO wfpsuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO wfpsuser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA wfpsuser TO wfpsuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA wfpsuser TO wfpsuser;
GRANT ALL ON SCHEMA public TO "$db_user";
GRANT ALL ON SCHEMA wfpsuser TO "$db_user";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "$db_user";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "$db_user";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA wfpsuser TO "$db_user";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA wfpsuser TO "$db_user";
EOF
    else
        warning "Could not retrieve password from secret '$app_secret'. Skipped password synchronization."
    fi

    # 4. Patch Headless Service for DNS resolution
    info "Step 4/5: Ensuring WfPS headless service has publishNotReadyAddresses enabled..."
    local headless_services
    headless_services=$(${CLI_CMD} get svc -n "$NAMESPACE" --no-headers -o custom-columns=":metadata.name" | grep -E -- "-wfps-headless-service$" || true)
    for svc in $headless_services; do
        info "Patching headless service '$svc'..."
        ${CLI_CMD} patch svc "$svc" -n "$NAMESPACE" --type merge -p '{"spec":{"publishNotReadyAddresses":true}}' 2>/dev/null || true
    done

    # 5. Restart WfPS Runtime Server
    info "Step 5/5: Restarting WfPS runtime server pod(s) to connect to restored database..."
    local wfps_pods
    wfps_pods=$(${CLI_CMD} get pods -n "$NAMESPACE" --no-headers -o custom-columns=":metadata.name" | grep -E -- "-wfps-runtime-server-[0-9]+" || true)
    for pod in $wfps_pods; do
        info "Restarting pod '$pod'..."
        ${CLI_CMD} delete pod "$pod" -n "$NAMESPACE" --wait=false 2>/dev/null || true
    done

    info "================================================================="
    info "SUCCESS: WfPS Database Restore & Configuration completed."
    info "Monitor WfPS pod startup with:"
    info "  ${CLI_CMD} get pods -n $NAMESPACE -l app.kubernetes.io/name=wfps -w"
    info "================================================================="
}

# Main Execution
case "$MODE" in
    backup)
        do_backup
        ;;
    restore)
        do_restore
        ;;
esac
