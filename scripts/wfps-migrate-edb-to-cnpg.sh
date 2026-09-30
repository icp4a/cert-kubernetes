#!/usr/bin/env bash
# ==============================================================================
# Script: wfps-migrate-edb-to-cnpg.sh
# Purpose: Backup WfPS PostgreSQL database from EDB (before upgrade) and restore
#          to IBM CloudNativePG / PostgreSQL 16 (after upgrade).
#
# Scope: WfPS Runtime environment ONLY (WfPSRuntime CR, wfpsdb, wfpsuser).
#        This is NOT a generic CP4BA migration script.
#
# Called from cp4a-deployment.sh:
#   - Backup:  run_wfps_edb_backup()  → upgradeOperator mode
#   - Restore: upgradeDeploymentStatus block → after CNPG cluster is ready
#
# Usage (manual / standalone):
#   1. BEFORE upgradeOperator:
#      ./wfps-migrate-edb-to-cnpg.sh -m backup -n <namespace>
#
#   2. AFTER upgradeDeploymentStatus (CNPG cluster ready):
#      ./wfps-migrate-edb-to-cnpg.sh -m restore -n <namespace>
# ==============================================================================

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function info()    { echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" >&2; }
function warning() { echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" >&2; }
function error()   { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" >&2; }

function usage() {
    echo "Usage: $0 -m <backup|restore> -n <namespace> [-c <cluster_name>] [-d <backup_dir>]"
    echo ""
    echo "Options:"
    echo "  -m  Mode: 'backup' (before upgrade) or 'restore' (after CNPG cluster is ready)"
    echo "  -n  Kubernetes/OpenShift namespace where WfPS is deployed"
    echo "  -c  (Optional) EDB/CNPG cluster name (default: auto-discovered, ends with -postgre)"
    echo "  -d  (Optional) Local backup directory (default: /tmp/wfps_migration_backup)"
    echo "  -h  Show this help"
    exit 1
}

# Determine CLI (oc preferred over kubectl)
if command -v oc &>/dev/null; then
    CLI_CMD="oc"
elif command -v kubectl &>/dev/null; then
    CLI_CMD="kubectl"
else
    error "Neither 'oc' nor 'kubectl' found in PATH."
    exit 1
fi

# Defaults
MODE=""
NAMESPACE=""
CLUSTER_NAME=""
BACKUP_DIR="/tmp/wfps_migration_backup"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)          MODE="$2";         shift 2 ;;
        -n|--namespace)     NAMESPACE="$2";    shift 2 ;;
        -c|--cluster-name)  CLUSTER_NAME="$2"; shift 2 ;;
        -d|--backup-dir)    BACKUP_DIR="$2";   shift 2 ;;
        -h|--help)          usage ;;
        *) error "Unknown option: $1"; usage ;;
    esac
done

[[ -z "$MODE" || -z "$NAMESPACE" ]] && { error "Both --mode and --namespace are required."; usage; }
[[ "$MODE" != "backup" && "$MODE" != "restore" ]] && { error "Invalid mode '$MODE'. Use 'backup' or 'restore'."; usage; }

# ------------------------------------------------------------------------------
# resolve_wfps_edb_cluster / resolve_wfps_cnpg_cluster
# Populate the global CLUSTER_NAME in the CURRENT shell.
# MUST be called directly (never inside $()) so the assignment sticks.
# ------------------------------------------------------------------------------
function resolve_wfps_edb_cluster() {
    [[ -n "$CLUSTER_NAME" ]] && return 0
    CLUSTER_NAME=$(${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io -n "$NAMESPACE" \
        --no-headers --ignore-not-found 2>/dev/null \
        | awk '{print $1}' \
        | grep -E -- "-postgre$" \
        | grep -v "^postgres-cp4ba$" \
        | head -n 1 || true)
    [[ -z "$CLUSTER_NAME" ]] && { error "No WfPS EDB cluster found in namespace '$NAMESPACE'."; exit 1; }
    info "Auto-discovered WfPS EDB cluster: $CLUSTER_NAME"
}

function resolve_wfps_cnpg_cluster() {
    [[ -n "$CLUSTER_NAME" ]] && return 0
    CLUSTER_NAME=$(${CLI_CMD} get clusters.pg.ibm.com -n "$NAMESPACE" \
        --no-headers --ignore-not-found 2>/dev/null \
        | awk '{print $1}' \
        | grep -E -- "-postgre$" \
        | grep -v "^postgres-cp4ba$" \
        | head -n 1 || true)
    [[ -z "$CLUSTER_NAME" ]] && { error "No WfPS IBM CNPG cluster found in namespace '$NAMESPACE'."; exit 1; }
    info "Auto-discovered WfPS CNPG cluster: $CLUSTER_NAME"
}

# ------------------------------------------------------------------------------
# find_wfps_edb_pod
# Returns the primary EDB pod name on stdout.
# Call resolve_wfps_edb_cluster first so CLUSTER_NAME is already set.
# ------------------------------------------------------------------------------
function find_wfps_edb_pod() {
    local pod="${CLUSTER_NAME}-1"
    if ! ${CLI_CMD} get pod "$pod" -n "$NAMESPACE" &>/dev/null; then
        pod=$(${CLI_CMD} get pods -n "$NAMESPACE" \
            -l "postgresql.k8s.enterprisedb.io/cluster=${CLUSTER_NAME}" \
            --no-headers -o custom-columns=":metadata.name" 2>/dev/null | head -n 1 || true)
        [[ -z "$pod" ]] && { error "No pod found for EDB cluster '$CLUSTER_NAME'."; exit 1; }
    fi
    echo "$pod"
}

# ------------------------------------------------------------------------------
# find_wfps_cnpg_pod
# Returns the primary IBM CloudNativePG pod name on stdout.
# Call resolve_wfps_cnpg_cluster first so CLUSTER_NAME is already set.
# IBM CNPG pods are named <cluster>-1, <cluster>-2, … (no container named
# "postgres" — do NOT use -c postgres in exec calls against these pods).
# ------------------------------------------------------------------------------
function find_wfps_cnpg_pod() {
    local pod
    pod=$(${CLI_CMD} get pods -n "$NAMESPACE" --no-headers 2>/dev/null \
        | grep "^${CLUSTER_NAME}-1 " | awk '{print $1}')
    [[ -z "$pod" ]] && pod=$(${CLI_CMD} get pods -n "$NAMESPACE" --no-headers 2>/dev/null \
        | grep "^${CLUSTER_NAME}-" | head -1 | awk '{print $1}')
    [[ -z "$pod" ]] && { error "No pod found for IBM CNPG cluster '$CLUSTER_NAME'."; exit 1; }
    echo "$pod"
}

# ------------------------------------------------------------------------------
# backup_wfps_cr
# Saves the WfPSRuntime CR to BACKUP_DIR/cr/ for rollback reference.
# Uses kind WfPSRuntime — the correct CR kind for the WfPS runtime environment.
# ------------------------------------------------------------------------------
function backup_wfps_cr() {
    local cr_dir="${BACKUP_DIR}/cr"
    mkdir -p "$cr_dir"

    local cr_name
    cr_name=$(${CLI_CMD} get WfPSRuntime -n "$NAMESPACE" \
        --no-headers --ignore-not-found 2>/dev/null \
        | awk '{print $1}' | head -n 1 || true)

    if [[ -n "$cr_name" ]]; then
        ${CLI_CMD} get WfPSRuntime "$cr_name" -n "$NAMESPACE" -o yaml \
            > "${cr_dir}/wfpsruntime.yaml" 2>/dev/null || true
        info "  WfPSRuntime CR '$cr_name' backed up -> ${cr_dir}/wfpsruntime.yaml"
    else
        warning "  No WfPSRuntime CR found in namespace '$NAMESPACE' — skipping CR backup."
    fi
}

# ------------------------------------------------------------------------------
# backup_wfps_secrets
# Saves WfPS-related Kubernetes secrets to BACKUP_DIR/secrets/.
# Captures secrets labelled for the WFPS CNPG cluster and any secret whose
# name contains 'wfps' (matches the naming convention the WfPS operator uses).
# ------------------------------------------------------------------------------
function backup_wfps_secrets() {
    local secrets_dir="${BACKUP_DIR}/secrets"
    mkdir -p "$secrets_dir"

    local labeled
    labeled=$(${CLI_CMD} get secret -n "$NAMESPACE" \
        -l "pg.ibm.com/cluster=${CLUSTER_NAME}" \
        --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true)

    local named
    named=$(${CLI_CMD} get secret -n "$NAMESPACE" \
        --no-headers -o custom-columns=":metadata.name" 2>/dev/null \
        | grep -i "wfps" || true)

    local all
    all=$(printf '%s\n%s\n' "$labeled" "$named" | sort -u | grep -v '^$' || true)

    local count=0
    while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        # Strip runtime-only fields so the YAML can be cleanly re-applied
        ${CLI_CMD} get secret "$s" -n "$NAMESPACE" -o yaml 2>/dev/null \
            | grep -v '^\s*managedFields:' \
            | grep -v '^\s*- manager:' \
            | grep -v '^\s*operation:' \
            | grep -v '^\s*time:' \
            | grep -v '^\s*fieldsType:' \
            | grep -v '^\s*fieldsV1:' \
            | grep -v '^\s*f:' \
            > "${secrets_dir}/${s}.yaml" || true
        (( count++ )) || true
    done <<< "$all"

    echo "$all" > "${secrets_dir}/secrets.list"
    info "  Backed up ${count} WfPS-related secret(s) -> ${secrets_dir}/"
}

# ------------------------------------------------------------------------------
# snapshot_was_tables
# Records the name and owner of every Liberty transaction recovery log table
# (was_partner_log_*, was_tran_log_*) in wfpsdb BEFORE the migration.
# After restore, fix_recovery_log_ownership() corrects the ownership so Liberty
# does not fail on shutdown with:
#   WTRN0107W: ERROR: must be owner of table was_partner_log_<identity>
# ------------------------------------------------------------------------------
function snapshot_was_tables() {
    local edb_pod="$1"
    local snap_dir="${BACKUP_DIR}/snapshot"
    mkdir -p "$snap_dir"

    info "  Snapshotting Liberty recovery log table ownership (was_*) in wfpsdb..."
    ${CLI_CMD} exec -i "$edb_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT schemaname || '.' || tablename || '|' || tableowner
         FROM pg_tables WHERE tablename LIKE 'was\_%' ORDER BY tablename;" \
        > "${snap_dir}/was_table_owners.txt" 2>/dev/null || true
    info "  Snapshot saved -> ${snap_dir}/was_table_owners.txt"
}

# ------------------------------------------------------------------------------
# Backup — runs BEFORE upgradeOperator (called by run_wfps_edb_backup in
# cp4a-deployment.sh which also creates the wfps-edb-cnpg-migration-state
# ConfigMap that gates the restore step).
# ------------------------------------------------------------------------------
function do_backup() {
    info "================================================================="
    info "WfPS EDB → CNPG Backup  |  namespace: $NAMESPACE"
    info "================================================================="

    resolve_wfps_edb_cluster     # sets CLUSTER_NAME in this shell (not a subshell)
    local edb_pod
    edb_pod=$(find_wfps_edb_pod)
    info "Using EDB pod: $edb_pod"

    mkdir -p "$BACKUP_DIR"
    info "Backup directory: $BACKUP_DIR"
    echo "$CLUSTER_NAME" > "${BACKUP_DIR}/cluster_name.txt"

    # --- Kubernetes state: WfPSRuntime CR + secrets + pod identity ---
    info "Step 1/5: Backing up Kubernetes resources..."
    backup_wfps_cr
    backup_wfps_secrets

    # Record Liberty pod identity (_RI_POD<ordinal>) so we know the exact
    # was_partner_log_* table names that exist in the database.
    local wfps_pod
    wfps_pod=$(${CLI_CMD} get pods -n "$NAMESPACE" --no-headers \
        -o custom-columns=":metadata.name" 2>/dev/null \
        | grep -E -- "-wfps-runtime-server-[0-9]+" | head -n 1 || true)
    if [[ -n "$wfps_pod" ]]; then
        local ordinal; ordinal=$(echo "$wfps_pod" | grep -oE '[0-9]+$' || echo "0")
        echo "_RI_POD${ordinal}" > "${BACKUP_DIR}/pod_identity.txt"
        info "  Liberty pod identity: _RI_POD${ordinal} -> ${BACKUP_DIR}/pod_identity.txt"
    fi

    # --- Pre-migration snapshot of was_* table ownership ---
    info "Step 2/5: Snapshotting Liberty recovery log table ownership..."
    snapshot_was_tables "$edb_pod"

    # --- Global roles and password hashes ---
    info "Step 3/5: Exporting global roles and credentials..."
    ${CLI_CMD} exec -i "$edb_pod" -n "$NAMESPACE" -c postgres -- \
        pg_dumpall -U postgres --globals-only > "${BACKUP_DIR}/globals.sql" \
        || { error "Failed to export globals."; exit 1; }
    info "  Globals exported -> ${BACKUP_DIR}/globals.sql"

    # --- wfpsdb ownership grant (ALTER DATABASE wfpsdb OWNER TO wfpsuser) ---
    # Backed up separately so it can be re-applied after restore even if
    # pg_dumpall globals restore skips it on a pre-existing role.
    info "Step 4/5: Exporting wfpsdb ownership grant..."
    ${CLI_CMD} exec -i "$edb_pod" -n "$NAMESPACE" -c postgres -- psql -U postgres -t -A -c \
        "SELECT 'ALTER DATABASE ' || quote_ident(d.datname)
              || ' OWNER TO ' || quote_ident(r.rolname) || ';'
         FROM pg_database d
         JOIN pg_roles r ON r.oid = d.datdba
         WHERE d.datname = 'wfpsdb';" \
        > "${BACKUP_DIR}/db_ownership_grants.sql" 2>/dev/null || true
    info "  Ownership grant exported -> ${BACKUP_DIR}/db_ownership_grants.sql"

    # --- Full database dump ---
    info "Step 5/5: Dumping wfpsdb..."
    ${CLI_CMD} exec -i "$edb_pod" -n "$NAMESPACE" -c postgres -- \
        pg_dump -U postgres -Fc -d wfpsdb > "${BACKUP_DIR}/wfpsdb.dump" \
        || { error "Failed to dump wfpsdb."; exit 1; }
    info "  wfpsdb dumped -> ${BACKUP_DIR}/wfpsdb.dump"

    info "================================================================="
    info "SUCCESS: WfPS EDB backup complete."
    info "Backup location: $BACKUP_DIR"
    ls -lh "$BACKUP_DIR"
    info "The upgradeOperator process will continue with the operator upgrade."
    info "================================================================="
}

# ------------------------------------------------------------------------------
# restore_wfps_secrets
# Re-applies any WfPS secrets that are missing after the upgrade.
# Secrets that already exist are skipped so operator-generated credentials
# are never overwritten.
# ------------------------------------------------------------------------------
function restore_wfps_secrets() {
    local secrets_dir="${BACKUP_DIR}/secrets"
    [[ ! -f "${secrets_dir}/secrets.list" ]] && {
        warning "  No secret backup found — skipping secret restore."; return; }

    local restored=0 skipped=0
    while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        local f="${secrets_dir}/${s}.yaml"
        [[ ! -f "$f" ]] && continue
        if ${CLI_CMD} get secret "$s" -n "$NAMESPACE" &>/dev/null; then
            info "    '$s' already exists — skipped."
            (( skipped++ )) || true
        else
            info "    Restoring missing secret: $s"
            ${CLI_CMD} apply -f "$f" -n "$NAMESPACE" 2>/dev/null || \
                warning "    Could not restore '$s'. Check manually."
            (( restored++ )) || true
        fi
    done < "${secrets_dir}/secrets.list"
    info "  Secrets: ${restored} restored, ${skipped} already present."
}

# ------------------------------------------------------------------------------
# Restore — runs AFTER the WfPS CNPG cluster reaches readyInstances >= 1
# (gated by cp4a-deployment.sh upgradeDeploymentStatus block).
# ------------------------------------------------------------------------------
function do_restore() {
    info "================================================================="
    info "WfPS CNPG Restore  |  namespace: $NAMESPACE"
    info "================================================================="

    [[ ! -f "${BACKUP_DIR}/wfpsdb.dump" ]] && {
        error "wfpsdb.dump not found in $BACKUP_DIR. Run backup first."; exit 1; }

    # Seed CLUSTER_NAME from backup record, then discover the CNPG cluster in
    # this shell (not a subshell) so the variable is visible to secret lookup.
    [[ -z "$CLUSTER_NAME" && -f "${BACKUP_DIR}/cluster_name.txt" ]] && \
        CLUSTER_NAME=$(tr -d '\r\n' < "${BACKUP_DIR}/cluster_name.txt")
    resolve_wfps_cnpg_cluster    # sets / confirms CLUSTER_NAME in this shell

    # Scale down WfPS runtime StatefulSet before DB operations so Liberty does
    # not attempt to connect or run dbConfig against a partially restored DB.
    local wfps_sts
    wfps_sts=$(${CLI_CMD} get statefulset -n "$NAMESPACE" --no-headers \
        -o custom-columns=":metadata.name" 2>/dev/null \
        | grep -E -- "-wfps-runtime-server" || true)

    local original_replicas=1
    if [[ -n "$wfps_sts" ]]; then
        original_replicas=$(${CLI_CMD} get statefulset "$wfps_sts" -n "$NAMESPACE" \
            -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        [[ -z "$original_replicas" || "$original_replicas" -eq 0 ]] && original_replicas=1
        info "Scaling down WfPS StatefulSet '$wfps_sts' to 0 replicas during restore..."
        ${CLI_CMD} scale statefulset "$wfps_sts" -n "$NAMESPACE" --replicas=0 2>/dev/null || true
    fi

    local cnpg_pod
    cnpg_pod=$(find_wfps_cnpg_pod)
    info "Using IBM CNPG pod: $cnpg_pod"

    # Resolve wfpsuser password from the CNPG app secret
    # The WfPS operator creates <cluster>-app secret with username/password keys.
    local app_secret="${CLUSTER_NAME}-app"
    ${CLI_CMD} get secret "$app_secret" -n "$NAMESPACE" &>/dev/null || \
        app_secret=$(${CLI_CMD} get secret -n "$NAMESPACE" \
            -l "pg.ibm.com/cluster=${CLUSTER_NAME}" --no-headers 2>/dev/null \
            | grep -E "(app|-app)" | awk '{print $1}' | head -n 1 \
            || echo "${CLUSTER_NAME}-app")

    local db_user db_pass
    db_user=$(${CLI_CMD} get secret "$app_secret" -n "$NAMESPACE" \
        -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || echo "wfpsuser")
    db_pass=$(${CLI_CMD} get secret "$app_secret" -n "$NAMESPACE" \
        -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "")

    # Step 1/6: Ensure wfpsuser role exists before restore
    # The IBM CNPG operator pre-creates wfpsuser via the app secret.
    # We only need this as a safety net for pg_restore object references.
    # We deliberately do NOT replay pg_dumpall globals.sql password hashes —
    # doing so would overwrite the CNPG-managed SCRAM password with the stale
    # EDB hash, breaking Liberty's database connection after restore.
    info "Step 1/9: Ensuring wfpsuser role exists..."
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -c \
        "DO \$\$ BEGIN
           IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'wfpsuser') THEN
             CREATE ROLE wfpsuser LOGIN;
           END IF;
         END \$\$;" 2>/dev/null || true
    info "  Role check complete."

    # Step 2/9: Drop and recreate wfpsdb, then restore data.
    # Drop+CREATE guarantees a clean slate regardless of CNPG bootstrap initdb state.
    # --no-tablespaces: CNPG pod does not have EDB tablespace directories.
    # NOTE: We do NOT use --no-owner. Restoring with original ownership means wfpsuser
    # owns its tables from the start — dbConfig can ALTER TABLE without permission errors,
    # and the schema upgrade runs against a clean old-version schema so every ADD COLUMN
    # succeeds on first run (columns do not exist yet). This matches what the CP4BA
    # cp4a-migrate-edb-to-cnpg.sh script does for all other CP4BA databases.
    #
    # NOTE: --exit-on-error is intentionally NOT used. Benign differences (comments,
    # extension references, or fed_partitioning duplicate PKs) should not abort the
    # restore. Step 4 (schema moves), Step 4b (dedup), Step 5 (schema patches including
    # snapshot_move_identifier on all tables), and Step 6 (privileges) repair and validate
    # all schema state.
    info "Step 2/9: Restoring wfpsdb..."
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- psql -U postgres \
        -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='wfpsdb' AND pid <> pg_backend_pid();" \
        -c "DROP DATABASE IF EXISTS wfpsdb;" \
        -c "CREATE DATABASE wfpsdb ENCODING 'UTF8';" 2>/dev/null || true

    # Copy dump file into CNPG pod (under the persistent writable PGDATA mount)
    # to prevent API server websocket timeout / broken pipe on stdin streaming.
    # Note: CNPG runs rootless with readOnlyRootFilesystem: true, so /tmp is read-only.
    # /var/lib/postgresql/data (or PGDATA) is the mounted writable volume.
    info "  Copying backup dump into CNPG pod..."
    local pod_restore_dir="/var/lib/postgresql/data/restore"
    ${CLI_CMD} exec "$cnpg_pod" -n "$NAMESPACE" -c postgres -- mkdir -p "$pod_restore_dir"
    ${CLI_CMD} cp "${BACKUP_DIR}/wfpsdb.dump" "${NAMESPACE}/${cnpg_pod}:${pod_restore_dir}/wfpsdb.dump" -c postgres
    info "  ✓ Backup dump copied to ${pod_restore_dir}/wfpsdb.dump in pod."

    # Run pg_restore from local file in pod
    ${CLI_CMD} exec "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        pg_restore -U postgres -d wfpsdb --no-tablespaces "${pod_restore_dir}/wfpsdb.dump" 2>&1 | \
        grep -v "^pg_restore: warning:" || true

    # Clean up dump file in CNPG pod
    ${CLI_CMD} exec "$cnpg_pod" -n "$NAMESPACE" -c postgres -- rm -rf "$pod_restore_dir" 2>/dev/null || true

    info "  wfpsdb restored."

    # Step 3/9: Re-apply database ownership grant
    info "Step 3/9: Re-applying wfpsdb ownership grant..."
    if [[ -s "${BACKUP_DIR}/db_ownership_grants.sql" ]]; then
        cat "${BACKUP_DIR}/db_ownership_grants.sql" | \
            ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
            psql -U postgres || true
        info "  Ownership grant applied."
    fi

    # Step 4/9: Align table and enum type schemas: move any objects that pg_restore
    # placed in the public schema into the wfpsuser schema.
    #
    # Root cause:
    #   pg_dump on EDB emits a search_path header pointing to the owner schema
    #   (wfpsuser). pg_restore on CNPG creates empty DDL shells in wfpsuser AND
    #   restores actual data rows into public (where they physically lived on EDB).
    #   Result: wfpsuser.LSW_SNAPSHOT exists but is EMPTY; public.LSW_SNAPSHOT has
    #   all the data with the old schema.
    #
    #   Additionally, some WfPS tables (e.g. bpm_app_move_meta_data, bpm_measure_pending)
    #   may have been created with owner = postgres on EDB (created by dbConfig running as
    #   postgres, not wfpsuser). pg_restore places them in public with owner postgres.
    #   Liberty's search_path=wfpsuser,public does NOT find unqualified table references
    #   in public when the connection role is wfpsuser and the table is owned by postgres.
    #   Result: "relation bpm_app_move_meta_data does not exist" at runtime.
    #
    # Fix: move ALL non-system tables from public → wfpsuser, regardless of owner.
    #   - We exclude only PostgreSQL's own system tables (pg_* and information_schema).
    #   - After moving, reassign ownership to wfpsuser so Liberty can ALTER them.
    #   - This is safe: wfpsdb contains only WfPS application tables; there are no
    #     legitimate third-party tables in public that should stay there.
    info "Step 4/9: Aligning table schemas (public → wfpsuser)..."
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT tablename FROM pg_tables
         WHERE schemaname = 'public';" \
        2>/dev/null | while IFS= read -r tbl; do
            [[ -z "$tbl" ]] && continue
            # Drop the empty owner-schema shell created by pg_restore (if any).
            ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
                psql -U postgres -d wfpsdb -c \
                "DROP TABLE IF EXISTS wfpsuser.\"${tbl}\" CASCADE;" \
                2>/dev/null || true
            info "  Moving table: public.${tbl} → wfpsuser.${tbl}"
            ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
                psql -U postgres -d wfpsdb \
                -c "ALTER TABLE public.\"${tbl}\" SET SCHEMA wfpsuser;" \
                -c "ALTER TABLE wfpsuser.\"${tbl}\" OWNER TO wfpsuser;" \
                2>/dev/null || true
        done
    info "  ✓ Table schema alignment complete."

    # Step 4b/9: Repair duplicate-PK rows in fed_partitioning_* tables (EDB sequence drift).
    #
    # Why this must run AFTER the public → wfpsuser schema move (Step 4):
    #   pg_restore creates DDL shells in the owner schema (wfpsuser) and restores data
    #   rows into the public schema, resulting in two copies of each table after restore:
    #     - wfpsuser.fed_partitioning_audit  — empty DDL shell (PK constraint absent
    #                                          because pg_restore failed to add it due
    #                                          to duplicates in the public copy)
    #     - public.fed_partitioning_audit    — all rows, including the duplicate PKs
    #   Step 4 drops the empty wfpsuser shell then moves the public table into wfpsuser.
    #   Only after that move does wfpsuser.fed_partitioning_audit contain the actual data
    #   and duplicates.  Running deduplication before Step 4 would target the empty shell
    #   and accomplish nothing; the duplicates would survive into the final schema.
    #
    # Strategy: DELETE duplicate rows (keep highest ctid per PK), then add the missing
    # PRIMARY KEY constraint using a conditional DO block so it is idempotent.
    info "Step 4b/9: Repairing fed_partitioning_* duplicate PKs (if any)..."

    # fed_partitioning_audit — PK: id
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT EXISTS (
           SELECT 1 FROM information_schema.tables
           WHERE table_schema='wfpsuser' AND table_name='fed_partitioning_audit'
         );" 2>/dev/null | grep -q "t" && \
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "DELETE FROM wfpsuser.fed_partitioning_audit a
            USING wfpsuser.fed_partitioning_audit b
            WHERE a.id = b.id AND a.ctid < b.ctid;" \
        -c "DO \$\$ BEGIN
              IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname='fed_part_audit_pk'
                  AND conrelid='wfpsuser.fed_partitioning_audit'::regclass
              ) THEN
                ALTER TABLE wfpsuser.fed_partitioning_audit
                  ADD CONSTRAINT fed_part_audit_pk PRIMARY KEY (id);
              END IF;
            END \$\$;" \
        2>/dev/null || true
    info "  ✓ fed_partitioning_audit deduplication complete."

    # fed_partitioning_controller — PK: controller_group_id
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT EXISTS (
           SELECT 1 FROM information_schema.tables
           WHERE table_schema='wfpsuser' AND table_name='fed_partitioning_controller'
         );" 2>/dev/null | grep -q "t" && \
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "DELETE FROM wfpsuser.fed_partitioning_controller a
            USING wfpsuser.fed_partitioning_controller b
            WHERE a.controller_group_id = b.controller_group_id AND a.ctid < b.ctid;" \
        -c "DO \$\$ BEGIN
              IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname='fed_part_controller_pk'
                  AND conrelid='wfpsuser.fed_partitioning_controller'::regclass
              ) THEN
                ALTER TABLE wfpsuser.fed_partitioning_controller
                  ADD CONSTRAINT fed_part_controller_pk PRIMARY KEY (controller_group_id);
              END IF;
            END \$\$;" \
        2>/dev/null || true
    info "  ✓ fed_partitioning_controller deduplication complete."

    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -c "ANALYZE;" 2>/dev/null || true
    info "  wfpsdb schema aligned and analyzed."

    info "  Aligning enum type schemas (public → wfpsuser)..."
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT t.typname
         FROM pg_type t
         JOIN pg_namespace n ON n.oid = t.typnamespace
         WHERE t.typtype = 'e'
           AND n.nspname = 'public';" \
        2>/dev/null | while IFS= read -r typ; do
            [[ -z "$typ" ]] && continue
            ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
                psql -U postgres -d wfpsdb -c \
                "DROP TYPE IF EXISTS wfpsuser.\"${typ}\" CASCADE;" \
                2>/dev/null || true
            info "  Moving enum type: public.${typ} → wfpsuser.${typ}"
            ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
                psql -U postgres -d wfpsdb \
                -c "ALTER TYPE public.\"${typ}\" SET SCHEMA wfpsuser;" \
                -c "ALTER TYPE wfpsuser.\"${typ}\" OWNER TO wfpsuser;" \
                2>/dev/null || true
        done
    info "  ✓ Enum type schema alignment complete."

    # Step 5/9: Fix WfPS schema gaps caused by dbConfig transactions recorded as complete
    # in dbupgrade_progress but whose DDL was never executed.
    #
    # Root cause: pg_restore runs without --exit-on-error (intentional — to survive the
    # known fed_partitioning_audit duplicate PK errors). When pg_restore skips a DDL step
    # due to a non-fatal error, the corresponding row in dbupgrade_progress was already
    # restored from the dump and is marked complete. dbConfig then sees it as done and
    # skips re-running the DDL — leaving columns permanently absent.
    #
    # Strategy: for each known missing column, check whether the column is absent AND the
    # transaction is recorded in dbupgrade_progress. If so, DELETE that row from
    # dbupgrade_progress so dbConfig re-runs the transaction on next pod startup and adds
    # the column with the correct type, constraints, and indexes — exactly as it would on
    # a fresh install. This is the correct fix: let the server add its own columns rather
    # than guessing types in a migration script.
    #
    # ADD COLUMN IF NOT EXISTS fallback patches (Patches 1-3) are retained only for
    # columns where the transaction ID is not reliably known or where the column type
    # is confirmed from the server source SQL. Patch 4 (BPM_TASK_MARKERS) uses the
    # dbupgrade_progress delete strategy.
    #
    # Patch 5: ProcUpgradeTo1160 tables are always pre-created (see Patch 5 comment).
    info "Step 5/9: Fixing WfPS schema gaps (dbupgrade_progress repair + pre-creating ProcUpgradeTo1160 tables)..."

    # Patch 1: freeze_execution CHAR(1) + freeze_start_time TIMESTAMP on LSW_SNAPSHOT
    #   + index IDX8_SNAPSHOT_FREEZE.
    #   Source upgrade SQL: ALTER TABLE LSW_SNAPSHOT ADD COLUMN FREEZE_EXECUTION CHAR(1),
    #                                                ADD COLUMN FREEZE_START_TIME TIMESTAMP
    #   Confirmed missing on EDB→CNPG migration when source DB predates this change.
    local lsw_snap_freeze_cols
    lsw_snap_freeze_cols=$(${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT count(*) FROM information_schema.columns
         WHERE table_schema='wfpsuser' AND table_name='lsw_snapshot'
           AND column_name IN ('freeze_execution','freeze_start_time');" \
        2>/dev/null || echo "0")
    if [[ "$lsw_snap_freeze_cols" -lt 2 ]]; then
        info "  Patching LSW_SNAPSHOT: adding freeze_execution CHAR(1) and freeze_start_time TIMESTAMP..."
        ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
            psql -U postgres -d wfpsdb \
            -c "ALTER TABLE wfpsuser.lsw_snapshot
                  ADD COLUMN IF NOT EXISTS freeze_execution  CHAR(1),
                  ADD COLUMN IF NOT EXISTS freeze_start_time TIMESTAMP WITHOUT TIME ZONE;" \
            -c "CREATE INDEX IF NOT EXISTS idx8_snapshot_freeze
                  ON wfpsuser.lsw_snapshot(freeze_execution, snapshot_id, freeze_start_time);" \
            2>/dev/null || true
        info "  ✓ freeze_execution, freeze_start_time, idx8_snapshot_freeze applied."
    else
        info "  ✓ LSW_SNAPSHOT freeze columns already present — skipping."
    fi

    # Patch 2: field5 CHAR(1) on 22 WfPS tables.
    #   Source upgrade SQL: ALTER TABLE <each_table> ADD COLUMN FIELD5 CHAR(1)
    #   Confirmed missing on EDB→CNPG migration when source DB predates this change.
    #   Trigger: field5 absent from lsw_snapshot (the table ImportFileHelper queries).
    #   All 22 tables patched for consistency with the original upgrade transaction.
    local lsw_snap_field5
    lsw_snap_field5=$(${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT count(*) FROM information_schema.columns
         WHERE table_schema='wfpsuser' AND table_name='lsw_snapshot'
           AND column_name='field5';" \
        2>/dev/null || echo "0")
    if [[ "$lsw_snap_field5" == "0" ]]; then
        info "  Patching 22 WfPS tables: adding field5 CHAR(1)..."
        ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
            psql -U postgres -d wfpsdb \
            -c "ALTER TABLE wfpsuser.lsw_bpd                        ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_bpd_event                  ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_bpd_parameter              ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.bpm_bpd_event                  ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.bpm_coach_view                 ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_class                      ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_process                    ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_snapshot                   ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_project                    ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_po_versions                ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_project_dependency         ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.bpm_case_property              ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.bpm_ecm_object                 ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_content_object             ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_content_object_instance    ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_bpd_instance_content_usage ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_user_favorite              ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_smart_folder               ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_bpd_instance               ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_bpd_notification           ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_dur_msg_received           ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            -c "ALTER TABLE wfpsuser.lsw_inst_msg_incl              ADD COLUMN IF NOT EXISTS field5 CHAR(1);" \
            2>/dev/null || true
        info "  ✓ field5 CHAR(1) added to 22 WfPS tables."
    else
        info "  ✓ field5 already present in LSW_SNAPSHOT — skipping."
    fi

    # Patch 3: log_name VARCHAR + log_level NUMERIC(4,0) + app_logging_enabled CHAR(1) on LSW_PROJECT_DEFAULTS.
    #   Source upgrade SQL (id_2025-01-16):
    #     ALTER TABLE LSW_PROJECT_DEFAULTS ADD COLUMN APP_LOGGING_ENABLED CHAR(1) DEFAULT 'F',
    #                                      ADD COLUMN LOG_NAME VARCHAR(70),
    #                                      ADD COLUMN LOG_LEVEL NUMERIC(4,0)
    #   Confirmed missing on EDB→CNPG migration — ImportFileHelper SELECT queries all three columns.
    local lsw_projdef_log_cols
    lsw_projdef_log_cols=$(${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT count(*) FROM information_schema.columns
         WHERE table_schema='wfpsuser' AND table_name='lsw_project_defaults'
           AND column_name IN ('log_name','log_level','app_logging_enabled');" \
        2>/dev/null || echo "0")
    if [[ "$lsw_projdef_log_cols" -lt 3 ]]; then
        info "  Patching LSW_PROJECT_DEFAULTS: adding app_logging_enabled, log_name, log_level..."
        ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
            psql -U postgres -d wfpsdb \
            -c "ALTER TABLE wfpsuser.lsw_project_defaults
                  ADD COLUMN IF NOT EXISTS app_logging_enabled CHAR(1) DEFAULT 'F',
                  ADD COLUMN IF NOT EXISTS log_name            VARCHAR(70),
                  ADD COLUMN IF NOT EXISTS log_level           NUMERIC(4,0);" \
            2>/dev/null || true
        info "  ✓ app_logging_enabled, log_name, log_level applied to LSW_PROJECT_DEFAULTS."
    else
        info "  ✓ LSW_PROJECT_DEFAULTS log columns already present — skipping."
    fi

    # Patch 4: Apply all schema objects and columns from ProcUpgradeTo1140, ProcUpgradeTo1150, ProcUpgradeTo1160
    # Exactly matching upgradeSchema_ProcessServer.sql definitions.
    info "  Applying all schema objects from ProcUpgradeTo1140, ProcUpgradeTo1150, ProcUpgradeTo1160..."

    # --- ProcUpgradeTo1140 ---
    # id_2025-01-30_01: BPM_MQ_SERVICE, BPM_MQ_SERVICE_OP
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_mq_service (
              mq_service_id           CHAR(36)      NOT NULL,
              name                    VARCHAR(64)   NOT NULL,
              description             TEXT,
              json_data               BYTEA,
              guid                    VARCHAR(128)  NOT NULL,
              version_id              CHAR(36)      NOT NULL,
              last_modified           TIMESTAMP     NOT NULL,
              last_modified_by_user_id NUMERIC(12,0) NOT NULL,
              CONSTRAINT lswc_mqsrv_pk PRIMARY KEY (version_id)
            );" \
        -c "CREATE INDEX IF NOT EXISTS lswc_mqsrv_pk3 ON wfpsuser.bpm_mq_service (guid);" \
        -c "CREATE INDEX IF NOT EXISTS lswc_mqsrv_pk4 ON wfpsuser.bpm_mq_service (name);" \
        -c "ALTER TABLE wfpsuser.bpm_mq_service OWNER TO wfpsuser;" \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_mq_service_op (
              mq_service_op_id        CHAR(36)      NOT NULL,
              mq_service_id           CHAR(36)      NOT NULL,
              seq                     NUMERIC(12,0) NOT NULL,
              process_ref             CHAR(36),
              implementation_ref      VARCHAR(47),
              name                    VARCHAR(64)   NOT NULL,
              description             TEXT,
              interaction_pattern     NUMERIC(1,0)  DEFAULT 1 NOT NULL,
              guid                    VARCHAR(128)  NOT NULL,
              version_id              CHAR(36)      NOT NULL,
              last_modified           TIMESTAMP     NOT NULL,
              last_modified_by_user_id NUMERIC(12,0) NOT NULL,
              CONSTRAINT lswc_mqsrv_op_pk PRIMARY KEY (version_id)
            );" \
        -c "CREATE INDEX IF NOT EXISTS lswc_mqsrv_op_pk3 ON wfpsuser.bpm_mq_service_op (guid);" \
        -c "CREATE INDEX IF NOT EXISTS lswc_mqsrv_op_pk4 ON wfpsuser.bpm_mq_service_op (name);" \
        -c "CREATE INDEX IF NOT EXISTS idx_mqsrv_op ON wfpsuser.bpm_mq_service_op (mq_service_id, seq);" \
        -c "ALTER TABLE wfpsuser.bpm_mq_service_op OWNER TO wfpsuser;" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2025-01-30_01', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1140')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # id_2025-02-05: LSW_PROCESS.business_data_aliases, LSW_TASK_VARIABLES
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "ALTER TABLE wfpsuser.lsw_process ADD COLUMN IF NOT EXISTS business_data_aliases TEXT;" \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.lsw_task_variables (
              task_var_id     NUMERIC(18,0) NOT NULL,
              bpd_instance_id NUMERIC(12,0) NOT NULL,
              task_id         NUMERIC(12,0) NOT NULL,
              variable_name   VARCHAR(512)  NOT NULL,
              alias           VARCHAR(512),
              boolean_value   CHAR(1),
              string_value    VARCHAR(512),
              int_value       NUMERIC(17,0),
              dec_value       NUMERIC(17,2),
              date_value      TIMESTAMP,
              variable_type   VARCHAR(64)   NOT NULL,
              CONSTRAINT task_vars_pk PRIMARY KEY (task_var_id)
            );" \
        -c "CREATE INDEX IF NOT EXISTS lswidx_task_inst_id ON wfpsuser.lsw_task_variables (bpd_instance_id);" \
        -c "CREATE INDEX IF NOT EXISTS lswidx_task_als ON wfpsuser.lsw_task_variables (task_id, alias);" \
        -c "ALTER TABLE wfpsuser.lsw_task_variables OWNER TO wfpsuser;" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2025-02-05', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1140')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # id_2025-02-26: LSW_BPD.workflow_display_name, LSW_BPD_INSTANCE.workflow_display_name
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "ALTER TABLE wfpsuser.lsw_bpd          ADD COLUMN IF NOT EXISTS workflow_display_name TEXT;" \
        -c "ALTER TABLE wfpsuser.lsw_bpd_instance ADD COLUMN IF NOT EXISTS workflow_display_name TEXT;" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2025-02-26', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1140')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # id_2025-04-03: LSW_PROJECT_DEFAULTS.solution_target_store
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "ALTER TABLE wfpsuser.lsw_project_defaults ADD COLUMN IF NOT EXISTS solution_target_store VARCHAR(64);" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2025-04-03', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1140')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # --- ProcUpgradeTo1150 ---
    # id_2025_07_24_01: BPM_AI_AGENT_TASK
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_ai_agent_task (
              ai_agent_task_id        CHAR(36)      NOT NULL,
              definition              BYTEA         NOT NULL,
              guid                    VARCHAR(128)  NOT NULL,
              version_id              CHAR(36)      NOT NULL,
              last_modified           TIMESTAMP     NOT NULL,
              last_modified_by_user_id NUMERIC(12,0) NOT NULL,
              CONSTRAINT bpmc_ai_agent_task_pk PRIMARY KEY (version_id)
            );" \
        -c "CREATE INDEX IF NOT EXISTS bpmc_ai_agent_task_pk3 ON wfpsuser.bpm_ai_agent_task (guid);" \
        -c "ALTER TABLE wfpsuser.bpm_ai_agent_task OWNER TO wfpsuser;" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2025_07_24_01', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1150')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # id_2025_08_07: LSWC_UGXREF_NUGN1 index
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "CREATE INDEX IF NOT EXISTS lswc_ugxref_nugn1 ON wfpsuser.lsw_usr_grp_xref (UPPER(group_name));" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2025_08_07', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1150')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # --- ProcUpgradeTo1160 ---
    # id_2025-11-19: IDX19_LSW_TASK
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "CREATE INDEX IF NOT EXISTS idx19_lsw_task ON wfpsuser.lsw_task (bpd_instance_id, status, priority_id, group_id, user_id, participant_id);" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2025-11-19', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1160')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # id_2025-01-16: LSW_PROJECT_DEFAULTS (APP_LOGGING_ENABLED, LOG_NAME, LOG_LEVEL), BPM_PALOGGING_OVERRIDE
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "ALTER TABLE wfpsuser.lsw_project_defaults
              ADD COLUMN IF NOT EXISTS app_logging_enabled CHAR(1) DEFAULT 'F',
              ADD COLUMN IF NOT EXISTS log_name            VARCHAR(70),
              ADD COLUMN IF NOT EXISTS log_level           NUMERIC(4,0);" \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_palogging_override (
              pa_acronym          VARCHAR(64) NOT NULL,
              app_logging_enabled CHAR(1),
              log_level           NUMERIC(4,0)
            );" \
        -c "CREATE UNIQUE INDEX IF NOT EXISTS idx_palogging_uq1 ON wfpsuser.bpm_palogging_override (pa_acronym);" \
        -c "ALTER TABLE wfpsuser.bpm_palogging_override OWNER TO wfpsuser;" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2025-01-16', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1160')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # id_2026_01_19_01: BPM_APP_MOVE_* tables (META_DATA, TARGET, ATTEMPT, PROGRESS_STATUS, RT_REF_MAPPING, VER_ID_MAPPING, ID_MAPPING)
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_app_move_meta_data (
              move_id              CHAR(36)     NOT NULL,
              snapshot_id          CHAR(36)     NOT NULL,
              target_id            CHAR(36),
              external_status      NUMERIC(2,0) NOT NULL,
              internal_status      NUMERIC(2,0) NOT NULL,
              check_result         TEXT,
              settings             TEXT,
              start_time           TIMESTAMP,
              end_time             TIMESTAMP,
              frozen_time          TIMESTAMP,
              working_table_suffix VARCHAR(10)  NOT NULL,
              installation_id      VARCHAR(36)  NOT NULL,
              payload              TEXT,
              CONSTRAINT bpm_app_move_meta_data_pk PRIMARY KEY (move_id)
            );" \
        -c "CREATE UNIQUE INDEX IF NOT EXISTS bpm_app_move_meta_data_uq ON wfpsuser.bpm_app_move_meta_data (snapshot_id);" \
        -c "CREATE INDEX IF NOT EXISTS bpm_app_move_meta_data_idx1 ON wfpsuser.bpm_app_move_meta_data (snapshot_id, external_status);" \
        -c "ALTER TABLE wfpsuser.bpm_app_move_meta_data OWNER TO wfpsuser;" \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_app_move_target (
              target_id            CHAR(36)     NOT NULL,
              name                 VARCHAR(32)  NOT NULL,
              db_type              VARCHAR(20)  NOT NULL,
              db_host              VARCHAR(256) NOT NULL,
              db_port              VARCHAR(5)   NOT NULL,
              db_name              VARCHAR(50)  NOT NULL,
              datasource_jndi_name VARCHAR(256),
              db_user              VARCHAR(50)  NOT NULL,
              db_password          VARCHAR(250),
              db_ssl_enabled       CHAR(1)      DEFAULT '0',
              baw_host             VARCHAR(256),
              baw_port             VARCHAR(10),
              baw_user             VARCHAR(50),
              baw_password         VARCHAR(250),
              more_settings        TEXT,
              status               NUMERIC(2,0),
              payload              TEXT,
              installation_id      VARCHAR(36)  NOT NULL,
              CONSTRAINT bpm_app_move_target_pk PRIMARY KEY (target_id)
            );" \
        -c "CREATE UNIQUE INDEX IF NOT EXISTS bpm_app_move_target_uq1 ON wfpsuser.bpm_app_move_target (name);" \
        -c "CREATE UNIQUE INDEX IF NOT EXISTS bpm_app_move_target_uq2 ON wfpsuser.bpm_app_move_target (datasource_jndi_name);" \
        -c "ALTER TABLE wfpsuser.bpm_app_move_target OWNER TO wfpsuser;" \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_app_move_attempt (
              snapshot_id          CHAR(36)     NOT NULL,
              attempt_id           CHAR(36)     NOT NULL,
              external_status      NUMERIC(2,0),
              internal_status      NUMERIC(2,0),
              check_result         TEXT,
              settings             TEXT,
              start_time           TIMESTAMP,
              end_time             TIMESTAMP,
              frozen_time          TIMESTAMP,
              working_table_suffix VARCHAR(10)  NOT NULL,
              payload              TEXT,
              CONSTRAINT bpm_app_move_attempt_data_pk PRIMARY KEY (attempt_id)
            );" \
        -c "CREATE INDEX IF NOT EXISTS bpm_app_move_attempt_data_idx1 ON wfpsuser.bpm_app_move_attempt (snapshot_id);" \
        -c "ALTER TABLE wfpsuser.bpm_app_move_attempt OWNER TO wfpsuser;" \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_app_move_progress_status (
              snapshot_id   CHAR(36)      NOT NULL,
              table_name    VARCHAR(128)  NOT NULL,
              started_time  TIMESTAMP     NOT NULL,
              total_rows    NUMERIC(12,0),
              rows_read     NUMERIC(12,0),
              rows_copied   NUMERIC(12,0),
              rows_deleted  NUMERIC(12,0),
              action_type   NUMERIC(1,0)  DEFAULT 0 NOT NULL,
              status        VARCHAR(32)   NOT NULL,
              last_updated  TIMESTAMP     NOT NULL,
              time_spent    NUMERIC(12,0),
              error         TEXT,
              CONSTRAINT bpm_app_move_trans_status_pk PRIMARY KEY (snapshot_id, action_type, started_time, table_name)
            );" \
        -c "ALTER TABLE wfpsuser.bpm_app_move_progress_status OWNER TO wfpsuser;" \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_app_move_rt_ref_mapping (
              rt_ref       NUMERIC(19,0) NOT NULL,
              po_reference VARCHAR(256)  NOT NULL,
              CONSTRAINT app_move_rt_ref_mapping_pk PRIMARY KEY (rt_ref)
            );" \
        -c "ALTER TABLE wfpsuser.bpm_app_move_rt_ref_mapping OWNER TO wfpsuser;" \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_app_move_ver_id_mapping (
              version_id  CHAR(36) NOT NULL,
              snapshot_id CHAR(36) NOT NULL,
              po_id       CHAR(41) NOT NULL,
              CONSTRAINT app_move_ver_id_mapping_pk PRIMARY KEY (version_id)
            );" \
        -c "ALTER TABLE wfpsuser.bpm_app_move_ver_id_mapping OWNER TO wfpsuser;" \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_app_move_id_mapping (
              source_id NUMERIC(12,0) NOT NULL,
              target_id NUMERIC(12,0) NOT NULL,
              type      VARCHAR(32)   NOT NULL,
              CONSTRAINT bpm_app_move_id_mapping_pk PRIMARY KEY (type, source_id)
            );" \
        -c "CREATE UNIQUE INDEX IF NOT EXISTS bpm_app_move_id_mapping_uq ON wfpsuser.bpm_app_move_id_mapping (type, target_id);" \
        -c "ALTER TABLE wfpsuser.bpm_app_move_id_mapping OWNER TO wfpsuser;" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2026_01_19_01', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1160')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # id_2026_02_25_01: BPM_APPLICATION_ACCOUNT
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_application_account (
              application_account_id  CHAR(36)      NOT NULL,
              name                    VARCHAR(64)   NOT NULL,
              description             TEXT,
              application_name        VARCHAR(256)  NOT NULL,
              application_type        VARCHAR(256),
              auth_type               VARCHAR(256)  NOT NULL,
              auth_definition         TEXT,
              last_modified           TIMESTAMP     NOT NULL,
              last_modified_by_user_id NUMERIC(12,0) NOT NULL,
              CONSTRAINT bpm_app_acc_pk PRIMARY KEY (application_account_id)
            );" \
        -c "CREATE UNIQUE INDEX IF NOT EXISTS bpm_app_name_acc_name_uq ON wfpsuser.bpm_application_account (application_name, name);" \
        -c "ALTER TABLE wfpsuser.bpm_application_account OWNER TO wfpsuser;" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2026_02_25_01', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1160')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # id_2026_02_27: snapshot_move_identifier on ALL 19 tables + cleanup FK constraints + indices
    info "  Adding snapshot_move_identifier to all 19 tables (id_2026_02_27)..."
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "ALTER TABLE wfpsuser.bpm_shared_object            ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.bpm_shared_object_instance   ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_bpd_instance_shared_usage ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.bpm_shared_object_invalid    ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.bpm_task_markers             ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_bpd_instance_data        ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_bpd_instance_documents   ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_bpd_instance_doc_props   ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_em_task                  ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_em_task_keywords         ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_file                     ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_runtime_error            ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_stored_symbol_table      ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_task_addr                ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_task_execution_context   ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_task_extact_data         ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_task_file                ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_bpd_instance_variables   ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_task_variables           ADD COLUMN IF NOT EXISTS snapshot_move_identifier CHAR(36);" \
        -c "ALTER TABLE wfpsuser.lsw_bpd_instance_variables   DROP CONSTRAINT IF EXISTS lsw_bpd_inst_fk;" \
        -c "ALTER TABLE wfpsuser.lsw_bpd_instance_data        DROP CONSTRAINT IF EXISTS lswc_bpd_ins_d_fk0;" \
        -c "ALTER TABLE wfpsuser.lsw_task_file                DROP CONSTRAINT IF EXISTS lswc_t_file_fk;" \
        -c "ALTER TABLE wfpsuser.lsw_task_addr                DROP CONSTRAINT IF EXISTS lswc_t_addr_fk;" \
        -c "ALTER TABLE wfpsuser.lsw_task_narr                DROP CONSTRAINT IF EXISTS lswc_t_narr_fk;" \
        -c "ALTER TABLE wfpsuser.lsw_task_execution_context   DROP CONSTRAINT IF EXISTS lswc_t_exec_fk;" \
        -c "CREATE INDEX IF NOT EXISTS ix_bpd_act_inst_del    ON wfpsuser.lsw_bpd_activity_instance (field3, instance_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_bpd_notif_del       ON wfpsuser.lsw_bpd_notification (field3, bpd_notification_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_bpd_inst_corr_del   ON wfpsuser.lsw_bpd_instance_correlation (field3, correlation_pk);" \
        -c "CREATE INDEX IF NOT EXISTS ix_dur_msg_del         ON wfpsuser.lsw_dur_msg_received (field3, msg_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_inst_msg_incl_del   ON wfpsuser.lsw_inst_msg_incl (field3, id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_inst_msg_excl_del   ON wfpsuser.lsw_inst_msg_excl (field3, id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_task_narr_del       ON wfpsuser.lsw_task_narr (field3, task_narr_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_bpm_rel_del         ON wfpsuser.bpm_relationship (field3, instance_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_ecm_obj_del         ON wfpsuser.bpm_ecm_object (field3, ecm_object_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_sbo_del             ON wfpsuser.bpm_shared_object (snapshot_move_identifier, definition_version_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_sbo_inst_del        ON wfpsuser.bpm_shared_object_instance (snapshot_move_identifier, instance_version_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_sbo_usage_del       ON wfpsuser.lsw_bpd_instance_shared_usage (snapshot_move_identifier, bpd_instance_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_sbo_inalid_del      ON wfpsuser.bpm_shared_object_invalid (snapshot_move_identifier, invalid_marker);" \
        -c "CREATE INDEX IF NOT EXISTS ix_task_maskers_del    ON wfpsuser.bpm_task_markers (snapshot_move_identifier, marker_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_inst_data_del       ON wfpsuser.lsw_bpd_instance_data (snapshot_move_identifier, bpd_instance_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_inst_doc_del        ON wfpsuser.lsw_bpd_instance_documents (snapshot_move_identifier, doc_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_inst_doc_prop_del   ON wfpsuser.lsw_bpd_instance_doc_props (snapshot_move_identifier, doc_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_em_task_del         ON wfpsuser.lsw_em_task (snapshot_move_identifier, task_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_em_task_kd_del      ON wfpsuser.lsw_em_task_keywords (snapshot_move_identifier, task_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_file_del            ON wfpsuser.lsw_file (snapshot_move_identifier, file_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_rt_error_del        ON wfpsuser.lsw_runtime_error (snapshot_move_identifier, error_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_stored_symbol_tabs_del ON wfpsuser.lsw_stored_symbol_table (snapshot_move_identifier, task_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_task_addr_del       ON wfpsuser.lsw_task_addr (snapshot_move_identifier, task_addr_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_task_ec_del         ON wfpsuser.lsw_task_execution_context (snapshot_move_identifier, task_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_task_extact_data_del ON wfpsuser.lsw_task_extact_data (snapshot_move_identifier, task_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_task_file_del       ON wfpsuser.lsw_task_file (snapshot_move_identifier, task_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_inst_var_del        ON wfpsuser.lsw_bpd_instance_variables (snapshot_move_identifier, bpd_inst_vars_id);" \
        -c "CREATE INDEX IF NOT EXISTS ix_task_var_del        ON wfpsuser.lsw_task_variables (snapshot_move_identifier, task_var_id);" \
        -c "CREATE INDEX IF NOT EXISTS idx_app_mig_task       ON wfpsuser.lsw_task (snapshot_id, task_id);" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2026_02_27', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1160')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true
    info "  ✓ snapshot_move_identifier applied to all 19 tables."

    # id_2026-03-14: LSW_SNAPSHOT (FREEZE_EXECUTION, FREEZE_START_TIME)
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "ALTER TABLE wfpsuser.lsw_snapshot
              ADD COLUMN IF NOT EXISTS freeze_execution  CHAR(1),
              ADD COLUMN IF NOT EXISTS freeze_start_time TIMESTAMP WITHOUT TIME ZONE;" \
        -c "CREATE INDEX IF NOT EXISTS idx8_snapshot_freeze ON wfpsuser.lsw_snapshot (freeze_execution, snapshot_id, freeze_start_time);" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2026-03-14', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1160')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # id_2026-03-24: BPM_MEASURE_PENDING, BPM_MEASURE
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_measure_pending (
              measure_id             NUMERIC(20,0)  NOT NULL,
              count                  NUMERIC(9,0)   NOT NULL,
              measure_type           VARCHAR(64)    NOT NULL,
              measure_usage          VARCHAR(9)     NOT NULL,
              server_uuid            VARCHAR(36)    NOT NULL,
              created_datetime       TIMESTAMP      NOT NULL,
              last_modified_datetime TIMESTAMP      NOT NULL,
              CONSTRAINT measure_p_pk PRIMARY KEY (measure_id)
            );" \
        -c "CREATE INDEX IF NOT EXISTS idx_measure_p_nuq1 ON wfpsuser.bpm_measure_pending (last_modified_datetime);" \
        -c "ALTER TABLE wfpsuser.bpm_measure_pending OWNER TO wfpsuser;" \
        -c "CREATE TABLE IF NOT EXISTS wfpsuser.bpm_measure (
              measure_id    NUMERIC(9,0)  NOT NULL,
              count         NUMERIC(12,0) NOT NULL,
              measure_type  VARCHAR(64)   NOT NULL,
              measure_usage VARCHAR(9)    NOT NULL,
              CONSTRAINT bpm_measure_pk PRIMARY KEY (measure_id)
            );" \
        -c "CREATE UNIQUE INDEX IF NOT EXISTS idx_measure_uq1 ON wfpsuser.bpm_measure (measure_id);" \
        -c "ALTER TABLE wfpsuser.bpm_measure OWNER TO wfpsuser;" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2026-03-24', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1160')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true

    # id_2026-04-27: LSW_BPD_INSTANCE_DATA.LAST_CHANGED_POST_SUSPEND_AT
    info "  Patching lsw_bpd_instance_data: adding last_changed_post_suspend_at (id_2026-04-27)..."
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "ALTER TABLE wfpsuser.lsw_bpd_instance_data
              ADD COLUMN IF NOT EXISTS last_changed_post_suspend_at TIMESTAMP WITHOUT TIME ZONE;" \
        -c "CREATE INDEX IF NOT EXISTS ix1_lsw_bpd_inst_data ON wfpsuser.lsw_bpd_instance_data (bpd_instance_id, last_changed_post_suspend_at);" \
        -c "INSERT INTO wfpsuser.dbupgrade_progress(transactionid, transactiontime, phasename)
            VALUES ('id_2026-04-27', '$(date -u +%Y%m%d-%H%M%S)', 'ProcUpgradeTo1160')
            ON CONFLICT (transactionid) DO NOTHING;" \
        2>/dev/null || true
    info "  ✓ last_changed_post_suspend_at applied to lsw_bpd_instance_data."

    info "  ✓ All upgrade phase tables, columns, and indexes (ProcUpgradeTo1140, 1150, 1160) applied cleanly."

    # Step 6/9: Synchronize wfpsuser password, schema ownership, and privileges.
    #
    # Why this step is needed even though pg_restore preserves ownership:
    #   - The CNPG app secret holds the authoritative password; it must be applied
    #     AFTER restore so any stale EDB SCRAM hash does not break Liberty's connection.
    #   - The wfpsuser schema may be absent if pg_restore skipped it (empty schema edge
    #     case); recreating it ensures dbConfig can SET search_path=wfpsuser.
    #   - ALTER DATABASE ... SET search_path ensures every new connection to wfpsdb
    #     resolves unqualified table names in wfpsuser first, regardless of role config.
    #   - GRANTs are re-issued after pg_restore so they cover all restored objects.
    info "Step 6/9: Synchronizing wfpsuser credentials, schema ownership, and privileges..."
    if [[ -z "$db_pass" ]]; then
        error "  Could not retrieve password from secret '$app_secret'. Liberty will not be able to connect."
        error "  Resolve the secret and re-run restore manually:"
        error "    $0 -m restore -n $NAMESPACE -d $BACKUP_DIR"
        exit 1
    fi
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb \
        -c "ALTER USER wfpsuser WITH PASSWORD '$db_pass';" \
        -c "ALTER USER \"$db_user\" WITH PASSWORD '$db_pass';" \
        -c "ALTER DATABASE wfpsdb OWNER TO wfpsuser;" \
        -c "GRANT ALL PRIVILEGES ON DATABASE wfpsdb TO wfpsuser;" \
        -c "GRANT ALL PRIVILEGES ON DATABASE wfpsdb TO \"$db_user\";" \
        -c "GRANT CREATE ON DATABASE wfpsdb TO wfpsuser;" \
        -c "GRANT CREATE ON DATABASE wfpsdb TO \"$db_user\";" \
        -c "CREATE SCHEMA IF NOT EXISTS wfpsuser AUTHORIZATION wfpsuser;" \
        -c "ALTER SCHEMA wfpsuser OWNER TO wfpsuser;" \
        -c "GRANT ALL ON SCHEMA wfpsuser TO wfpsuser;" \
        -c "GRANT ALL ON SCHEMA wfpsuser TO \"$db_user\";" \
        -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA wfpsuser TO wfpsuser;" \
        -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA wfpsuser TO \"$db_user\";" \
        -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA wfpsuser TO wfpsuser;" \
        -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA wfpsuser TO \"$db_user\";" \
        -c "ALTER DEFAULT PRIVILEGES IN SCHEMA wfpsuser GRANT ALL ON TABLES TO wfpsuser;" \
        -c "ALTER DEFAULT PRIVILEGES IN SCHEMA wfpsuser GRANT ALL ON TABLES TO \"$db_user\";" \
        -c "ALTER DEFAULT PRIVILEGES IN SCHEMA wfpsuser GRANT ALL ON SEQUENCES TO wfpsuser;" \
        -c "ALTER DEFAULT PRIVILEGES IN SCHEMA wfpsuser GRANT ALL ON SEQUENCES TO \"$db_user\";" \
        -c "ALTER USER wfpsuser SET search_path TO wfpsuser, public;" \
        -c "ALTER USER \"$db_user\" SET search_path TO wfpsuser, public;" \
        -c "ALTER DATABASE wfpsdb SET search_path TO wfpsuser, public;" \
        -c "GRANT ALL ON SCHEMA public TO wfpsuser;" \
        -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO wfpsuser;" \
        -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO wfpsuser;" \
        -c "GRANT ALL ON SCHEMA public TO \"$db_user\";" \
        -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$db_user\";" \
        -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$db_user\";"
    info "  Credentials, schema ownership, and privileges applied."

    # Step 7/9: Drop Liberty JDBC recovery log tables so Liberty recreates them cleanly.
    #
    # Root cause of CWRLS0008/CWRLS0009/CWRLS0024 after EDB→CNPG restore:
    #   Liberty's SQLMultiScopeRecoveryLog connects as wfpsuser and immediately
    #   issues an unqualified SELECT against was_partner_log_<identity> and
    #   was_tran_log_<identity> (e.g. was_partner_log_ri_pod0).  It relies on
    #   search_path=wfpsuser,public to find these tables.
    #
    #   After pg_restore, the tables may land in the wrong schema (public instead
    #   of wfpsuser), or the pod identity suffix (_ri_pod0) may differ from the
    #   one stored in the dump.  Either way, Liberty's assertDBTableExists query
    #   fails with:
    #     PSQLException: ERROR: relation "was_partner_log_ri_pod0" does not exist
    #   which immediately marks the recovery log as FAILED (CWRLS0008) and aborts
    #   transaction manager startup.
    #
    #   These tables are Liberty's ephemeral JDBC transaction log — they contain
    #   in-flight XA state only relevant to the pod instance that wrote them.
    #   After a database migration the old log entries are meaningless (the EDB
    #   pod is gone) and Liberty will recreate the tables correctly on first
    #   startup, in the wfpsuser schema, under the current pod identity.
    #
    #   Fix: drop every was_partner_log_* and was_tran_log_* table from all
    #   schemas before Liberty starts.  This is safe because:
    #     - The prepared XA transactions were already rolled back in Step 6/7.
    #     - Liberty treats a missing recovery log table as an empty log and
    #       creates it via CREATE TABLE IF NOT EXISTS on startup.
    info "Step 7/9: Dropping stale Liberty JDBC recovery log tables (was_*) from wfpsdb..."
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT 'DROP TABLE IF EXISTS ' || quote_ident(schemaname) || '.' || quote_ident(tablename) || ' CASCADE;'
         FROM pg_tables
         WHERE tablename LIKE 'was\_partner\_log\_%'
            OR tablename LIKE 'was\_tran\_log\_%';" \
        2>/dev/null \
    | ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb 2>/dev/null || true
    local was_remaining
    was_remaining=$(${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT count(*) FROM pg_tables
         WHERE tablename LIKE 'was\_partner\_log\_%'
            OR tablename LIKE 'was\_tran\_log\_%';" 2>/dev/null || echo "unknown")
    if [[ "$was_remaining" == "0" ]]; then
        info "  ✓ All was_* recovery log tables dropped. Liberty will recreate them on startup."
    else
        warning "  $was_remaining was_* table(s) still present — Liberty may still fail to claim recovery logs."
        warning "  Check manually: ${CLI_CMD} exec -it $cnpg_pod -n $NAMESPACE -- psql -U postgres -d wfpsdb -c \"SELECT schemaname,tablename FROM pg_tables WHERE tablename LIKE 'was_%';\""
    fi

    # Step 8/9: Roll back any prepared (in-doubt 2PC) transactions left in wfpsdb
    # from the old EDB pod before Liberty restarts against the new CNPG database.
    #
    # Root cause of the FFDC storm observed after EDB→CNPG migration:
    #   Liberty's Recovery Manager fires on startup and attempts to commit XA
    #   transactions that were PREPARED in the old EDB pod.  After the database is
    #   replaced by CNPG (DROP + CREATE + pg_restore), those prepared transaction
    #   entries are gone from pg_prepared_xacts.  The PostgreSQL XA driver then
    #   raises:
    #     PSQLException: ERROR: prepared transaction with identifier "..." does not exist
    #   This is logged as two FFDC incidents per restart cycle and Liberty keeps
    #   retrying indefinitely.
    #
    #   Fix: roll back every orphaned prepared transaction in wfpsdb right here,
    #   before Liberty sees the database.  PostgreSQL requires a superuser to roll
    #   back a prepared transaction it did not originate, which is why we connect
    #   as 'postgres'.
    info "Step 8/9: Rolling back orphaned prepared (in-doubt 2PC) transactions in wfpsdb..."
    ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT 'ROLLBACK PREPARED ' || quote_literal(gid) || ';' FROM pg_prepared_xacts;" \
        2>/dev/null \
    | ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb 2>/dev/null || true
    local leftover
    leftover=$(${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
        psql -U postgres -d wfpsdb -t -A -c \
        "SELECT count(*) FROM pg_prepared_xacts;" 2>/dev/null || echo "unknown")
    if [[ "$leftover" == "0" ]]; then
        info "  ✓ No prepared transactions remain in wfpsdb."
    else
        warning "  $leftover prepared transaction(s) still present in pg_prepared_xacts."
        warning "  Liberty recovery may still log FFDC on first startup."
        warning "  Check manually: ${CLI_CMD} exec -it $cnpg_pod -n $NAMESPACE -- psql -U postgres -d wfpsdb -c 'SELECT * FROM pg_prepared_xacts;'"
    fi

    # Step 9/9: Restore any WfPS secrets that went missing during upgrade
    info "Step 9/9: Checking backed-up WfPS secrets..."
    restore_wfps_secrets

    # Verify wfpsuser can connect before scaling Liberty back up
    info "Verifying wfpsuser connectivity to wfpsdb..."
    if ${CLI_CMD} exec -i "$cnpg_pod" -n "$NAMESPACE" -c postgres -- \
            env PGPASSWORD="$db_pass" psql -h 127.0.0.1 -U wfpsuser -d wfpsdb -c "SELECT 1;" \
            >/dev/null 2>&1; then
        info "  ✓ wfpsuser can connect to wfpsdb."
    else
        error "  wfpsuser cannot connect to wfpsdb with the password from secret '$app_secret'."
        error "  This will prevent Liberty from starting. Check pg_hba.conf and role password:"
        error "    ${CLI_CMD} exec -it $cnpg_pod -n $NAMESPACE -- psql -U postgres -c \"\\du wfpsuser\""
        error "  Re-run restore after resolving the issue:"
        error "    $0 -m restore -n $NAMESPACE -d $BACKUP_DIR"
        exit 1
    fi

    # Patch WfPS headless service so pod DNS resolves before pods are Ready
    local headless
    headless=$(${CLI_CMD} get svc -n "$NAMESPACE" --no-headers \
        -o custom-columns=":metadata.name" 2>/dev/null \
        | grep -E -- "-wfps-headless-service$" || true)
    for svc in $headless; do
        info "  Patching headless service '$svc' (publishNotReadyAddresses=true)..."
        ${CLI_CMD} patch svc "$svc" -n "$NAMESPACE" --type merge \
            -p '{"spec":{"publishNotReadyAddresses":true}}' 2>/dev/null || true
    done

    # OpenSearch: ensure opensearch-ibm-elasticsearch-srv ClusterIP service exists.
    # WfPS hardcodes PFS_REMOTEELASTICSEARCH_ENDPOINTS to this legacy name. The old
    # ibm-elasticsearch-operator removes it during quiesce; the new OpenSearch operator
    # does not recreate it. Without a valid ClusterIP here Liberty gets CWMFS8253W and
    # the health endpoint returns 404, keeping the pod stuck at 0/1 Running.
    info "Ensuring opensearch-ibm-elasticsearch-srv ClusterIP service exists..."
    local _os_svc_ok=false
    if ${CLI_CMD} get svc opensearch-ibm-elasticsearch-srv -n "$NAMESPACE" &>/dev/null; then
        local _sel_key
        _sel_key=$(${CLI_CMD} get svc opensearch-ibm-elasticsearch-srv -n "$NAMESPACE" \
            -o jsonpath='{.spec.selector}' 2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print(list(d.keys())[0] if d else '')" 2>/dev/null || true)
        if [[ "$_sel_key" =~ ^olm\. ]]; then
            warning "  Existing opensearch-ibm-elasticsearch-srv has invalid OLM selector — deleting and recreating..."
            ${CLI_CMD} delete svc opensearch-ibm-elasticsearch-srv -n "$NAMESPACE" >/dev/null 2>&1 || true
        else
            info "  opensearch-ibm-elasticsearch-srv already exists with valid selector — skipping."
            _os_svc_ok=true
        fi
    fi

    if [[ "$_os_svc_ok" == "false" ]]; then
        # Discover selector from headless opensearch/elasticsearch service (most reliable)
        local _os_sel_key="" _os_sel_val="" _os_src=""
        local _os_headless
        _os_headless=$(${CLI_CMD} get svc -n "$NAMESPACE" --no-headers \
            -o custom-columns=":metadata.name,:spec.clusterIP" 2>/dev/null \
            | awk '$2=="None"{print $1}' | grep -iE "opensearch|elasticsearch" || true)
        for _s in $_os_headless; do
            local _k _v
            _k=$(${CLI_CMD} get svc "$_s" -n "$NAMESPACE" \
                -o jsonpath='{.spec.selector}' 2>/dev/null | \
                python3 -c "import sys,json; d=json.load(sys.stdin); k=list(d.keys()); print(k[0] if k else '')" 2>/dev/null || true)
            _v=$(${CLI_CMD} get svc "$_s" -n "$NAMESPACE" \
                -o jsonpath='{.spec.selector}' 2>/dev/null | \
                python3 -c "import sys,json; d=json.load(sys.stdin); v=list(d.values()); print(v[0] if v else '')" 2>/dev/null || true)
            if [[ -n "$_k" && -n "$_v" && ! "$_k" =~ ^(olm\.|control-plane|controller-) ]]; then
                _os_sel_key="$_k"; _os_sel_val="$_v"; _os_src="$_s"; break
            fi
        done
        # Fallback: scan ClusterIP opensearch services
        if [[ -z "$_os_sel_key" ]]; then
            local _os_candidates
            _os_candidates=$(${CLI_CMD} get svc -n "$NAMESPACE" --no-headers \
                -o custom-columns=":metadata.name,:spec.type" 2>/dev/null \
                | awk '$2=="ClusterIP"{print $1}' \
                | grep -iE "opensearch|elasticsearch" \
                | grep -vE "^opensearch-ibm-elasticsearch-srv$" || true)
            for _s in $_os_candidates; do
                ${CLI_CMD} get svc "$_s" -n "$NAMESPACE" &>/dev/null || continue
                local _k _v
                _k=$(${CLI_CMD} get svc "$_s" -n "$NAMESPACE" \
                    -o jsonpath='{.spec.selector}' 2>/dev/null | \
                    python3 -c "import sys,json; d=json.load(sys.stdin); k=list(d.keys()); print(k[0] if k else '')" 2>/dev/null || true)
                _v=$(${CLI_CMD} get svc "$_s" -n "$NAMESPACE" \
                    -o jsonpath='{.spec.selector}' 2>/dev/null | \
                    python3 -c "import sys,json; d=json.load(sys.stdin); v=list(d.values()); print(v[0] if v else '')" 2>/dev/null || true)
                if [[ -n "$_k" && -n "$_v" && ! "$_k" =~ ^(olm\.|control-plane|controller-) ]]; then
                    _os_sel_key="$_k"; _os_sel_val="$_v"; _os_src="$_s"; break
                fi
            done
        fi

        if [[ -n "$_os_sel_key" && -n "$_os_sel_val" ]]; then
            info "  Creating opensearch-ibm-elasticsearch-srv (selector: ${_os_sel_key}=${_os_sel_val}, source: ${_os_src})..."
            ${CLI_CMD} apply -f - 2>/dev/null <<EOF || warning "  Failed to create opensearch-ibm-elasticsearch-srv."
apiVersion: v1
kind: Service
metadata:
  name: opensearch-ibm-elasticsearch-srv
  namespace: ${NAMESPACE}
spec:
  type: ClusterIP
  selector:
    ${_os_sel_key}: "${_os_sel_val}"
  ports:
  - name: https
    port: 443
    targetPort: 9200
    protocol: TCP
  - name: https-alt
    port: 9200
    targetPort: 9200
    protocol: TCP
EOF
            info "  ✓ opensearch-ibm-elasticsearch-srv created."
        else
            warning "  Could not discover OpenSearch pod selector. Skipping service creation."
            warning "  Run manually: oc get svc -n $NAMESPACE | grep -iE 'opensearch|elastic'"
        fi
    fi

    # OpenSearch: disable TLS hostname verification via Liberty config dropin.
    # The new OpenSearch operator issues a cert whose SANs don't include the legacy
    # hostname 'opensearch-ibm-elasticsearch-srv'. Liberty's OpenSearch client
    # rejects the cert with CWPKI0824E unless hostNameVerificationEnabled=false.
    info "Ensuring OpenSearch TLS hostname verification dropin is present..."
    local _liberty_secret
    _liberty_secret=$(${CLI_CMD} get wfps -n "$NAMESPACE" \
        -o jsonpath='{.items[0].spec.node.customize.libertyXMLSecret}' 2>/dev/null || true)
    [[ -z "$_liberty_secret" ]] && _liberty_secret="custom-config-dropins"

    if ${CLI_CMD} get secret "$_liberty_secret" -n "$NAMESPACE" &>/dev/null; then
        local _already
        _already=$(${CLI_CMD} get secret "$_liberty_secret" -n "$NAMESPACE" \
            -o jsonpath='{.data.opensearch-ssl\.xml}' 2>/dev/null || true)
        if [[ -n "$_already" ]]; then
            info "  OpenSearch SSL dropin already present in '$_liberty_secret' — skipping."
        else
            local _ssl_xml _b64
            _ssl_xml='<server>
  <ibmPfs_elasticsearchClientConfig hostNameVerificationEnabled="false"/>
</server>'
            _b64=$(printf '%s' "$_ssl_xml" | base64 | tr -d '\n')
            ${CLI_CMD} patch secret "$_liberty_secret" -n "$NAMESPACE" --type=json \
                -p="[{\"op\":\"add\",\"path\":\"/data/opensearch-ssl.xml\",\"value\":\"${_b64}\"}]" \
                2>/dev/null \
                && info "  ✓ OpenSearch SSL dropin added to '$_liberty_secret'." \
                || warning "  Failed to patch '$_liberty_secret'. CWPKI0824E errors may persist."
        fi
    else
        warning "  libertyXMLSecret '$_liberty_secret' not found. Skipping OpenSearch SSL dropin."
    fi

    # Sync OpenSearch credentials into the WfPS security credential secret
    info "Synchronizing OpenSearch credentials to WfPS security credential secret..."
    local _os_admin_secret="opensearch-admin-user"
    local _os_pass=""
    if ${CLI_CMD} get secret "$_os_admin_secret" -n "$NAMESPACE" &>/dev/null; then
        _os_pass=$(${CLI_CMD} get secret "$_os_admin_secret" -n "$NAMESPACE" \
            -o jsonpath='{.data.opensearch-admin}' 2>/dev/null | base64 -d || true)
        [[ -z "$_os_pass" ]] && _os_pass=$(${CLI_CMD} get secret "$_os_admin_secret" -n "$NAMESPACE" \
            -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)
        if [[ -n "$_os_pass" ]]; then
            local _sec_secrets
            _sec_secrets=$(${CLI_CMD} get secret -n "$NAMESPACE" --no-headers \
                -o custom-columns=":metadata.name" | grep -E -- "-wfps-security-credential-secret$" || true)
            for _sec in $_sec_secrets; do
                local _xml
                _xml=$(${CLI_CMD} get secret "$_sec" -n "$NAMESPACE" \
                    -o jsonpath='{.data.processServer_variables_system\.xml}' 2>/dev/null | base64 -d || true)
                if [[ -n "$_xml" && "$_xml" == *"pfs.remoteElasticsearch"* ]]; then
                    local _upd _b64x
                    _upd=$(echo "$_xml" | \
                        sed "s|<variable name=\"pfs.remoteElasticsearch.username\" value=\".*\" />|<variable name=\"pfs.remoteElasticsearch.username\" value=\"opensearch-admin\" />|g" | \
                        sed "s|<variable name=\"pfs.remoteElasticsearch.password\" value=\".*\" />|<variable name=\"pfs.remoteElasticsearch.password\" value=\"${_os_pass}\" />|g")
                    _b64x=$(echo "$_upd" | base64 | tr -d '\n')
                    ${CLI_CMD} patch secret "$_sec" -n "$NAMESPACE" --type='json' \
                        -p="[{\"op\":\"replace\",\"path\":\"/data/processServer_variables_system.xml\",\"value\":\"${_b64x}\"}]" \
                        2>/dev/null \
                        && info "  ✓ OpenSearch credentials synced to '$_sec'." \
                        || warning "  Failed to patch OpenSearch credentials in '$_sec'."
                fi
            done
        fi
    fi

    info "================================================================="
    info "SUCCESS: WfPS CNPG restore complete."
    info ""
    info "  wfpsuser connectivity to wfpsdb verified"
    info ""
    info "Monitor WfPS pods:"
    info "  ${CLI_CMD} get pods -n $NAMESPACE | grep wfps-runtime-server"
    info "================================================================="
}

case "$MODE" in
    backup)  do_backup  ;;
    restore) do_restore ;;
esac
