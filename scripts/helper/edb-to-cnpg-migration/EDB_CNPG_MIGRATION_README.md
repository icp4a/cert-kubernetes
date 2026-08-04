# EDB to CNPG Migration - Technical Documentation

**IMPORTANT**: This documentation describes the ConfigMap-based state tracking implementation for EDB to CNPG migration during CP4BA upgrades.

## Configuration

### Global Variables in common.sh
Key configuration variables are defined in `helper/common.sh`:

```bash
# EDB to CNPG Migration ConfigMap name
EDB_CNPG_MIGRATION_CM_NAME="edb-cnpg-migration"

# Migration script location
EDB_TO_CNPG_MIGRATION_FOLDER="${PARENT_DIR}/cp4ba-upgrade/project/$1"

# CNPG cluster template location
CNPG_CLUSTER_TEMPLATE="${PARENT_DIR}/descriptors/cnpg/cnpg-cluster-postgres-cp4ba-template.yaml"
```

**Key Points**:
- `EDB_CNPG_MIGRATION_CM_NAME`: ConfigMap name for state tracking
- `EDB_TO_CNPG_MIGRATION_FOLDER`: Directory for migration artifacts (backups, manifests)
- `CNPG_CLUSTER_TEMPLATE`: Template file for CNPG cluster CR generation

### EDB Configuration Variables
The migration script extracts and stores EDB cluster configuration in global variables (defined in `cp4a-migrate-edb-to-cnpg.sh`):

```bash
# Global variables to store EDB cluster configuration
EDB_STORAGE_CLASS=""
EDB_STORAGE_SIZE="100Gi"
EDB_INSTANCES="1"
EDB_CPU_REQUESTS="1"
EDB_MEMORY_REQUESTS="2Gi"
EDB_CPU_LIMITS="2"
EDB_MEMORY_LIMITS="4Gi"
```

These are populated by `extract_edb_cluster_configuration()` before the EDB cluster is deleted, ensuring configuration is preserved for CNPG cluster creation.

## Required RBAC Permissions

The migration script requires specific Kubernetes RBAC permissions to manage database clusters and resources. These permissions must be added to the service account used by the CP4BA API container that executes the upgrade scripts.

### Namespace-Scoped Role Permissions

The following permissions must be added to the **Role** in the operand namespace (where CP4BA and database clusters are deployed):

```yaml
# EDB to CNPG Migration - EDB Cluster operations
- apiGroups: ["postgresql.k8s.enterprisedb.io"]
  resources: ["clusters"]
  verbs: ["get", "list", "watch", "delete"]

# EDB to CNPG Migration - IBM CloudNativePG Cluster operations
- apiGroups: ["pg.ibm.com"]
  resources: ["clusters"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# EDB to CNPG Migration - PVC cleanup
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "delete"]

# EDB to CNPG Migration - Service cleanup (add delete to existing rule)
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "delete"]  # Added delete verb
```

### Permission Breakdown by Operation

| Permission | Used For | Migration Phase | Script Location |
|------------|----------|-----------------|-----------------|
| `clusters.postgresql.k8s.enterprisedb.io` (get, list, watch) | Read EDB cluster configuration | Phase 1: Backup | Line 1150-1159 |
| `clusters.postgresql.k8s.enterprisedb.io` (delete) | Delete old EDB cluster | Phase 2: Create Cluster | Line 1204 |
| `clusters.pg.ibm.com` (create) | Create new CNPG cluster | Phase 2: Create Cluster | Line 1596 |
| `clusters.pg.ibm.com` (get, list, watch) | Monitor CNPG cluster status | Phase 2 & 3 | Line 1606, 1625 |
| `clusters.pg.ibm.com` (update, patch) | Update CNPG cluster if needed | Phase 2 & 3 | Future use |
| `persistentvolumeclaims` (get, list, delete) | Clean up old EDB PVCs | Phase 2: Create Cluster | Line 1217 |
| `services` (delete) | Clean up old EDB services | Phase 2: Create Cluster | Line 1211-1213 |

### Why These Permissions Are Required

1. **EDB Cluster Read/Delete**: The migration must read the existing EDB cluster configuration to preserve settings (storage, resources, instances) and then delete the old cluster to free up resources.

2. **CNPG Cluster Create/Manage**: The migration creates a new IBM CloudNativePG cluster with the same configuration as the old EDB cluster and monitors its readiness.

3. **PVC Cleanup**: Old EDB PersistentVolumeClaims must be deleted to prevent storage conflicts and ensure clean migration.

4. **Service Cleanup**: Old EDB services must be deleted to allow the new CNPG cluster to create services with the same names.

### Integration with CP4BA API Service Account

These permissions are added to the CP4BA API service account's Role in the operand namespace. The service account is used by the upgrade container that executes `cp4a-deployment.sh` with the migration script.

**Note**: These are namespace-scoped permissions (Role + RoleBinding), not cluster-wide permissions, following the principle of least privilege.

## Table of Contents

1. [Overview](#overview)
2. [Required RBAC Permissions](#required-rbac-permissions)
   - [Namespace-Scoped Role Permissions](#namespace-scoped-role-permissions)
   - [Permission Breakdown by Operation](#permission-breakdown-by-operation)
   - [Why These Permissions Are Required](#why-these-permissions-are-required)
   - [Integration with CP4BA API Service Account](#integration-with-cp4ba-api-service-account)
3. [Two-Namespace Architecture](#two-namespace-architecture)
   - [Services Namespace](#1-services-namespace-services_namespace)
   - [Operator Namespace](#2-operator-namespace-operator_namespace)
   - [Why Two Namespaces?](#why-two-namespaces)
   - [Namespace Usage in Functions](#namespace-usage-in-functions)
   - [Example Flow](#example-flow)
4. [Three Migration Phases](#three-migration-phases)
   - [Phase 1: Backup](#phase-1-backup)
   - [Phase 2: Create Cluster](#phase-2-create-cluster)
   - [Phase 3: Restore](#phase-3-restore)
5. [Integration with cp4a-deployment.sh](#integration-with-cp4a-deploymentsh)
   - [Mode 1: upgradeOperator (Execution)](#mode-1-upgradeoperator-execution)
   - [Mode 2: upgradeOperatorStatus (Status Check)](#mode-2-upgradeoperatorstatus-status-check)
   - [Mode 3: upgradeDeployment (Validation & Blocking)](#mode-3-upgradedeployment-validation--blocking)
6. [ConfigMap State Tracking](#configmap-state-tracking)
7. [How Retry Works](#how-retry-works)
   - [Automatic Checkpoint Recovery](#automatic-checkpoint-recovery)
   - [Retry Examples](#retry-examples)
8. [Key Functions](#key-functions)
   - [Orchestration](#orchestration)
   - [ConfigMap Management](#configmap-management)
   - [Phase Wrappers](#phase-wrappers)
9. [Key Features](#key-features)
10. [Usage Examples](#usage-examples)
11. [Troubleshooting](#troubleshooting)
12. [Mode Comparison](#mode-comparison)
13. [Files](#files)
14. [Summary](#summary)

---

## Overview

The EDB to CNPG migration migrates PostgreSQL databases from EDB (EnterpriseDB) to IBM CloudNativePG (CNPG) during CP4BA upgrades.

**Before**: EDB PostgreSQL Operator
**After**: IBM CloudNativePG Operator
**Result**: Zero data loss, all data preserved

## Two-Namespace Architecture

The migration script operates across **two distinct namespaces**:

### 1. Services Namespace (`services_namespace`)
This is the namespace where the actual database clusters and application services reside:
- **EDB PostgreSQL cluster** (before migration)
- **IBM CloudNativePG cluster** (after migration)
- **Database pods and services**
- **Migration ConfigMap** (`edb-cnpg-migration`)
- **Application deployments** (scaled down during backup)
- **Database backups and restore operations**

### 2. Operator Namespace (`operator_namespace`)
This is the namespace where the operator subscription and ClusterServiceVersion (CSV) are installed:
- **IBM CloudNativePG operator subscription**
- **Operator ClusterServiceVersion (CSV)**
- **Operator deployment pods**

### Why Two Namespaces?

This separation follows OpenShift/Kubernetes best practices:
- **Operator Installation**: Operators are typically installed in a dedicated namespace (e.g., `openshift-operators`, `ibm-common-services`)
- **Service Deployment**: The actual services (database clusters) are deployed in the application namespace
- **Flexibility**: Allows one operator to manage resources across multiple namespaces
- **Security**: Separates operator privileges from application workloads

### Namespace Usage in Functions

| Function | Uses Services Namespace | Uses Operator Namespace |
|----------|------------------------|------------------------|
| `discover_databases()` | ✅ (queries EDB pods) | ❌ |
| `scale_down_applications()` | ✅ (scales deployments) | ❌ |
| `backup_databases()` | ✅ (backs up from EDB) | ❌ |
| `extract_edb_configuration()` | ✅ (reads EDB cluster CR) | ❌ |
| `delete_edb_cluster()` | ✅ (deletes EDB resources) | ❌ |
| `install_cnpg_operator()` | ❌ | ✅ (creates subscription/CSV) |
| `generate_cnpg_cluster_manifest()` | ✅ (sets namespace in manifest) | ❌ |
| `create_cnpg_cluster()` | ✅ (creates CNPG cluster) | ❌ |
| `restore_databases()` | ✅ (restores to CNPG) | ❌ |
| `verify_migration()` | ✅ (checks CNPG pods) | ✅ (checks operator pods) |

### Example Flow

```
cp4a-deployment.sh (upgradeOperator mode)
  ↓
handle_edb_migration_process(services_ns="cp4ba", operator_ns="ibm-common-services")
  ↓
execute_phased_edb_migration(services_ns, operator_ns, phase, cr_kind)
  ↓
  ├─ Phase 1: Backup
  │    ├─ discover_databases() → uses services_ns
  │    ├─ scale_down_applications() → uses services_ns
  │    └─ backup_databases() → uses services_ns
  │
  ├─ Phase 2: Create Cluster
  │    ├─ extract_edb_configuration() → uses services_ns
  │    ├─ delete_edb_cluster() → uses services_ns
  │    ├─ install_cnpg_operator() → uses operator_ns ⚠️
  │    ├─ generate_cnpg_cluster_manifest() → uses services_ns
  │    └─ create_cnpg_cluster() → uses services_ns
  │
  └─ Phase 3: Restore
       ├─ restore_databases() → uses services_ns
       └─ verify_migration() → uses both namespaces
```

**Key Point**: Only `install_cnpg_operator()` uses the operator namespace. All other operations use the services namespace.

## Three Migration Phases

### Phase 1: Backup
- Discovers all databases in EDB cluster
- Scales down applications
- Backs up databases using pg_dump
- Updates ConfigMap: `backup-completed = "true"`

### Phase 2: Create Cluster
- **Extracts EDB cluster configuration** (storage, resources, instances)
- Deletes old EDB cluster
- Installs IBM CNPG operator
- **Generates CNPG cluster manifest from template** using extracted configuration
- Deploys new CNPG cluster
- Updates ConfigMap: `create-cluster-completed = "true"`

**Configuration Flow**:
```
extract_edb_cluster_configuration()
  ↓ (stores in global EDB_* variables)
delete_edb_cluster()
  ↓
install_cnpg_operator()
  ↓
deploy_cnpg_cluster()
  ↓ (calls generate_cnpg_manifest() if needed)
generate_cnpg_manifest()
  ↓ (uses global EDB_* variables + template)
Apply CNPG cluster CR
```

### Phase 3: Restore
- Restores databases from backups
- Verifies data integrity
- Scales up applications
- Updates ConfigMap: `restore-completed = "true"`

## Integration with cp4a-deployment.sh

### Mode 1: upgradeOperator (Execution)
**Purpose**: Execute migration phases automatically

```bash
./cp4a-deployment.sh -m upgradeOperator -n cp4ba
```

**Behavior**:
- Sources `helper/edb-to-cnpg-migration/cp4a-migrate-edb-to-cnpg.sh`
- Calls `handle_edb_migration_process(namespace, csv_version)`
- Executes phases automatically based on ConfigMap state
- Exits on failure

### Mode 2: upgradeOperatorStatus (Status Check)
**Purpose**: Check migration status (informational only)

```bash
./cp4a-deployment.sh -m upgradeOperatorStatus -n cp4ba
```

**Behavior**:
- Calls `validate_edb_migration_completed(namespace, current_csv, upgraded_csv)`
- Displays status table
- **Does NOT exit on failure** - informational only

### Mode 3: upgradeDeployment (Validation & Blocking)
**Purpose**: Validate migration before deployment

```bash
./cp4a-deployment.sh -m upgradeDeployment -n cp4ba
```

**Behavior**:
- Calls `validate_edb_migration_completed(namespace, current_csv, upgraded_csv)`
- **EXITS on failure** - blocks deployment
- Critical protection mechanism

## ConfigMap State Tracking

**Name**: `edb-cnpg-migration`  
**Namespace**: Same as CP4BA (e.g., `cp4ba`)

**Key Fields**:
- `backup-completed`: "true" or "false"
- `create-cluster-completed`: "true" or "false"
- `restore-completed`: "true" or "false"
- `backup-directory`: Full path to backups
- `cp4ba-csv-version`: Version during migration
- Timestamps for each phase

**Example**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: edb-cnpg-migration
  namespace: cp4ba
data:
  backup-completed: "true"
  create-cluster-completed: "true"
  restore-completed: "true"
  backup-directory: "/opt/.../backup-20260615-143022"
  cp4ba-csv-version: "25.0.0"
  backup-completed-timestamp: "2026-06-15T14:35:22Z"
  create-cluster-completed-timestamp: "2026-06-15T14:42:18Z"
  restore-completed-timestamp: "2026-06-15T14:58:45Z"

### ConfigMap Validity Flag

The ConfigMap includes a `cm-valid` flag that ensures the ConfigMap is only used for the current migration cycle:

**Purpose**: Prevents old ConfigMaps from interfering with future upgrades

**Lifecycle**:
1. **Created**: Set to `"true"` when ConfigMap is first created
2. **During Migration**: Remains `"true"` while migration is in progress
3. **After Completion**: Set to `"false"` when `upgradeOperatorStatus` or `upgradeDeployment` validates successful completion

**Validation Logic**:
```bash
# Both conditions must be true for ConfigMap to be considered valid:
1. cm-valid = "true"
2. cp4ba-csv-version matches current upgrade version

# If either condition fails:
- ConfigMap is treated as invalid/redundant
- Upgrade proceeds without blocking
```

**Example - Valid ConfigMap (Migration in Progress)**:
```yaml
data:
  backup-completed: "true"
  create-cluster-completed: "false"
  restore-completed: "false"
  cm-valid: "true"              # Valid - migration in progress
  cp4ba-csv-version: "25.0.0"   # Matches current upgrade
```

**Example - Invalid ConfigMap (Migration Complete)**:
```yaml
data:
  backup-completed: "true"
  create-cluster-completed: "true"
  restore-completed: "true"
  cm-valid: "false"             # Invalid - migration already complete
  cp4ba-csv-version: "25.0.0"
```

**Example - Invalid ConfigMap (Old Version)**:
```yaml
data:
  backup-completed: "true"
  create-cluster-completed: "true"
  restore-completed: "true"
  cm-valid: "true"
  cp4ba-csv-version: "24.0.0"   # Doesn't match - from previous upgrade
```

**When cm-valid is Set to False**:
- After all CP4BA components are successfully upgraded in `upgradeDeploymentStatus` mode
- Happens in `cp4a-deployment.sh` after `check_if_all_components_are_ready` returns true
- Right before the final success message and exit
- Prevents the ConfigMap from blocking future upgrades

**Code Location**:
- File: `cp4a-deployment.sh`
- Mode: `upgradeDeploymentStatus`
- Location: After all components are in 'Done' status, before `exit 0`

```

## Key Functions

### Orchestration
- `handle_edb_migration_process()` - Main entry point, orchestrates entire migration
- `execute_phased_edb_migration()` - Executes specific phase and updates ConfigMap

### ConfigMap Management
- `create_edb_cnpg_migration_configmap()` - Creates ConfigMap with initial state
- `get_migration_phase_status()` - Retrieves phase status from ConfigMap
- `update_migration_phase_status()` - Updates phase status with timestamp
- `get_next_migration_phase()` - Determines next phase to execute
- `validate_edb_migration_completed()` - Validates migration completion
- `display_migration_status()` - Shows formatted status table
- `is_edb_detected()` - Checks if EDB cluster exists
- `check_migration_configmap_exists()` - Checks if ConfigMap exists

### Phase Wrappers
- `execute_backup_phase()` - Orchestrates backup operations
- `execute_create_cluster_phase()` - Orchestrates cluster creation (includes configuration extraction)
- `execute_restore_phase()` - Orchestrates database restoration

### Core Migration Functions
- `discover_databases()` - Discovers databases in EDB cluster or loads from backup
- `scale_down_applications()` - Scales down CP4BA applications before migration
- `backup_databases()` - Backs up all databases using pg_dump
- `extract_edb_cluster_configuration()` - **NEW**: Extracts EDB configuration before deletion
- `delete_edb_cluster()` - Deletes EDB cluster and associated resources
- `install_cnpg_operator()` - Installs IBM CNPG operator via subscription
- `generate_cnpg_manifest()` - **UPDATED**: Generates CNPG cluster CR from template using extracted config
- `deploy_cnpg_cluster()` - Deploys CNPG cluster and waits for ready state
- `restore_databases()` - Restores databases from backup files
- `verify_migration()` - Verifies database connectivity and data integrity

### Template-Based Manifest Generation
The `generate_cnpg_manifest()` function uses a template-based approach:

**Template Location**: `descriptors/cnpg/cnpg-cluster-postgres-cp4ba-template.yaml`

**Process**:
1. Reads template file using `$CNPG_CLUSTER_TEMPLATE` variable
2. Uses `yq` to modify template with extracted EDB configuration:
   - Namespace
   - Storage class and size
   - Number of instances
   - CPU and memory resources
   - Database initialization list
3. Outputs to: `${TEMP_FOLDER}/cnpg-cluster-postgres-cp4ba.yaml`

**Configuration Source**:
- Uses global `EDB_*` variables populated by `extract_edb_cluster_configuration()`
- Falls back to defaults if extraction fails
- Prompts user for storage class if not extracted

**Example Flow**:
```bash
# Before EDB deletion
extract_edb_cluster_configuration()
  → Sets: EDB_STORAGE_CLASS="ibmc-block-gold"
  → Sets: EDB_STORAGE_SIZE="100Gi"
  → Sets: EDB_INSTANCES="3"
  → Sets: EDB_CPU_REQUESTS="2", etc.

# After EDB deletion, during cluster creation
generate_cnpg_manifest()
  → Reads: $CNPG_CLUSTER_TEMPLATE
  → Applies: EDB_STORAGE_CLASS, EDB_STORAGE_SIZE, etc.
  → Outputs: cnpg-cluster-postgres-cp4ba.yaml
```

## Key Features

1. **Fully Automated**: Phases execute automatically with progression
2. **State-Tracked**: ConfigMap persists progress across retries
3. **Resilient**: Automatically resumes from last successful checkpoint
4. **Version-Aware**: Handles ConfigMaps from previous upgrade cycles
5. **Deployment Protection**: Blocks deployment until migration complete
6. **Zero Data Loss**: Comprehensive backup before destructive operations

## Usage Examples

### Run Migration
```bash
./cp4a-deployment.sh -m upgradeOperator -n cp4ba
```

### Check Status
```bash
./cp4a-deployment.sh -m upgradeOperatorStatus -n cp4ba
```

### Deploy (validates migration first)
```bash
./cp4a-deployment.sh -m upgradeDeployment -n cp4ba
```

## How Retry Works

### Automatic Checkpoint Recovery

The migration uses a ConfigMap (`edb-cnpg-migration`) to track which phases have completed. When you retry the migration, the script:

1. **Reads the ConfigMap** to determine current state
2. **Identifies the next phase** to execute based on completion flags
3. **Skips completed phases** automatically
4. **Resumes from the last incomplete phase**

**Key Point**: The script automatically determines which phase to run from the ConfigMap state.

### Retry Command

When migration fails, you'll see this message:

```
[ATTENTION]: You can run the following command to retry the migration after fixing the issue.
           # ./cp4a-deployment.sh -m upgradeOperator -n <namespace> --original-cp4ba-csv-ver <version>
```

**Correct Retry Command**:
```bash
./cp4a-deployment.sh -m upgradeOperator -n cp4ba --original-cp4ba-csv-ver 24.0.0
```

**Parameters**:
- `-m upgradeOperator`: Run in upgradeOperator mode
- `-n <namespace>`: Your CP4BA namespace (e.g., cp4ba)
- `--original-cp4ba-csv-ver <version>`: CSV version BEFORE upgrade (e.g., 24.0.0)

### Retry Examples

#### Example 1: Backup Failed - Retry After Fixing

**Error Message**:
```
[WARNING] EDB to CNPG migration failed at phase: backup
[ATTENTION]: You can run the following command to retry the migration after fixing the issue.
           # ./cp4a-deployment.sh -m upgradeOperator -n cp4ba --original-cp4ba-csv-ver 24.0.0
```

**ConfigMap State**:
```yaml
data:
  backup-completed: "false"
  create-cluster-completed: "false"
  restore-completed: "false"
```

**Steps**:
1. Fix the issue (e.g., free up disk space)
2. Run retry command:
```bash
./cp4a-deployment.sh -m upgradeOperator -n cp4ba --original-cp4ba-csv-ver 24.0.0
```

**What Happens**:
- Script reads ConfigMap
- Sees `backup-completed = "false"`
- Automatically runs backup phase
- Updates ConfigMap on success
- Continues to create-cluster phase

#### Example 2: Create Cluster Failed - Retry After Fixing

**Error Message**:
```
[WARNING] EDB to CNPG migration failed at phase: create-cluster
[ATTENTION]: You can run the following command to retry the migration after fixing the issue.
           # ./cp4a-deployment.sh -m upgradeOperator -n cp4ba --original-cp4ba-csv-ver 24.0.0
```

**ConfigMap State**:
```yaml
data:
  backup-completed: "true"
  backup-completed-timestamp: "2026-06-15T14:35:22Z"
  create-cluster-completed: "false"
  restore-completed: "false"
```

**Steps**:
1. Fix the issue (e.g., install CNPG operator)
2. Run retry command:
```bash
./cp4a-deployment.sh -m upgradeOperator -n cp4ba --original-cp4ba-csv-ver 24.0.0
```

**What Happens**:
- Script reads ConfigMap
- Sees `backup-completed = "true"` → **SKIPS backup phase**
- Sees `create-cluster-completed = "false"`
- Automatically runs create-cluster phase
- Updates ConfigMap on success
- Continues to restore phase

#### Example 3: Restore Failed - Retry After Fixing

**Error Message**:
```
[WARNING] EDB to CNPG migration failed at phase: restore
[ATTENTION]: You can run the following command to retry the migration after fixing the issue.
           # ./cp4a-deployment.sh -m upgradeOperator -n cp4ba --original-cp4ba-csv-ver 24.0.0
```

**ConfigMap State**:
```yaml
data:
  backup-completed: "true"
  create-cluster-completed: "true"
  restore-completed: "false"
```

**Steps**:
1. Fix the issue (e.g., create missing database role)
2. Run retry command:
```bash
./cp4a-deployment.sh -m upgradeOperator -n cp4ba --original-cp4ba-csv-ver 24.0.0
```

**What Happens**:
- Script reads ConfigMap
- Sees `backup-completed = "true"` → **SKIPS backup phase**
- Sees `create-cluster-completed = "true"` → **SKIPS create-cluster phase**
- Sees `restore-completed = "false"`
- Automatically runs restore phase
- Updates ConfigMap on success
- Migration complete!

### Important Notes

**✅ DO**:
- Always use the retry command with `--original-cp4ba-csv-ver` parameter
- Fix the underlying issue before retrying
- Check status with: `./cp4a-deployment.sh -m upgradeOperatorStatus -n <namespace>`

**❌ DON'T**:
- Don't try to run individual phases manually
- Don't delete the ConfigMap unless you want to start over completely
- Don't modify the ConfigMap manually
- Don't forget the `--original-cp4ba-csv-ver` parameter

---

## Troubleshooting

### Check Migration Status
```bash
./cp4a-deployment.sh -m upgradeOperatorStatus -n cp4ba
```

### Check ConfigMap
```bash
kubectl get configmap edb-cnpg-migration -n cp4ba -o yaml
```

### Retry Migration (After Fixing Issue)
```bash
./cp4a-deployment.sh -m upgradeOperator -n cp4ba --original-cp4ba-csv-ver 24.0.0
```
Replace `24.0.0` with your actual version before upgrade.

### Reset Migration (CAUTION - Starts Over)
```bash
kubectl delete configmap edb-cnpg-migration -n cp4ba
./cp4a-deployment.sh -m upgradeOperator -n cp4ba --original-cp4ba-csv-ver 24.0.0
```
This will restart migration from the beginning.

### Check EDB Cluster
```bash
kubectl get cluster.postgresql.k8s.enterprisedb.io -n cp4ba
```

### Check CNPG Cluster
```bash
kubectl get cluster.postgresql.cnpg.io -n cp4ba
kubectl get pods -n cp4ba -l cnpg.io/cluster=postgres-cp4ba
```

## Mode Comparison

| Aspect | upgradeOperator | upgradeOperatorStatus | upgradeDeployment |
|--------|----------------|----------------------|-------------------|
| **Purpose** | Execute migration | Check status | Validate & block |
| **Executes Phases** | ✅ Yes | ❌ No | ❌ No |
| **Exits on Failure** | ✅ Yes | ❌ No | ✅ Yes |
| **Blocks Deployment** | N/A | ❌ No | ✅ Yes |
| **When to Use** | To run migration | To check progress | Before deployment |

## Files

- **Migration Script**: `/scripts/helper/edb-to-cnpg-migration/cp4a-migrate-edb-to-cnpg.sh` (1,970 lines, 23 functions)
- **Main Deployment**: `/scripts/cp4a-deployment.sh` (integration in 3 modes)
- **Helper Functions**: `/scripts/helper/common.sh` (messaging functions)

## Summary

The EDB to CNPG migration is a production-ready system with:
- Automatic state tracking via ConfigMap
- Seamless integration into three deployment modes
- Intelligent retry capability with checkpoint recovery
- Version-aware logic for handling old ConfigMaps
- Deployment protection to prevent incomplete migrations

All data is preserved with zero data loss through comprehensive backup and validation.
