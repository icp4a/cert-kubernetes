# ADP Gitgateway and DICMS Database Configuration

## Table of Contents
1. [Fresh Install Scenarios](#fresh-install-scenarios)
2. [Upgrade Scenarios](#upgrade-scenarios)
3. [Manual Configuration Steps](#manual-configuration-steps)
4. [Manual Configuration Steps for Upgrade](#manual-configuration-steps-for-upgrade)

---

# Database Support Matrix

## FRESH INSTALL - v26.0.0 GA

| Scenario Type | Target Version | DB2 | MSSQL | Oracle | External Postgres | Embedded CNPG |
|---------------|----------------|-----|-------|--------|-------------------|---------------|
| Production Deployment | v26.0.0 GA | ✅ SUPPORTED<br/>[Manual Configuration Steps](#manual-configuration-steps) | ✅ SUPPORTED<br/>[Manual Configuration Steps](#manual-configuration-steps) | ✅ SUPPORTED<br/>[Manual Configuration Steps](#manual-configuration-steps) | ✅ SUPPORTED | ❌ NOT SUPPORTED |
| Starter Deployment | v26.0.0 GA | ❌ NOT SUPPORTED | ❌ NOT SUPPORTED | ❌ NOT SUPPORTED | ❌ NOT SUPPORTED | ❌ NOT SUPPORTED |

**Notes:**
- v26.0.0 GA version requires External Postgres for IM/Zen/BTS, ADP Gitgateway, DICMS Designer and Runtime (Gitservice is a part of Designer)
- **[Manual Configuration Steps](#manual-configuration-steps) required** when CP4BA uses DB2/MSSQL/Oracle database AND ADP Gitgateway/DICMS uses External PostgreSQL
- External PostgreSQL for all components (CP4BA + ADP Gitgateway/DICMS) is fully automated - no manual steps needed

---

## FRESH INSTALL - v26.0.0-IF001+

| Scenario Type | Target Version | DB2 | MSSQL | Oracle | External Postgres | Embedded CNPG |
|---------------|----------------|-----|-------|--------|-------------------|---------------|
| Production Deployment | v26.0.0-IF001+ | ✅ SUPPORTED | ✅ SUPPORTED | ✅ SUPPORTED | ✅ SUPPORTED | ✅ SUPPORTED |

**Notes:**
- v26.0.0-IF001+ supports both Embedded CNPG and External Postgres for all components

---

## UPGRADE TO v26.0.0 GA

| Scenario Type | Target Version | Source Version | DB2 | MSSQL | Oracle | External Postgres | Embedded CNPG |
|---------------|----------------|----------------|-----|-------|--------|-------------------|---------------|
| Upgrade | v26.0.0 GA | v24.0.0-IF009+ | ✅ SUPPORTED<br/>[Manual Configuration Steps for Upgrade](#manual-configuration-steps-for-upgrade) | ✅ SUPPORTED<br/>[Manual Configuration Steps for Upgrade](#manual-configuration-steps-for-upgrade) | ✅ SUPPORTED<br/>[Manual Configuration Steps for Upgrade](#manual-configuration-steps-for-upgrade) | ✅ SUPPORTED | ❌ NOT SUPPORTED |
| Upgrade | v26.0.0 GA | v24.0.1-IF00x | ❌ NOT SUPPORTED | ❌ NOT SUPPORTED | ❌ NOT SUPPORTED | ⚠️ MUST UPGRADE TO v25.0.0-IF004+ FIRST | ❌ NOT SUPPORTED |
| Upgrade | v26.0.0 GA | v25.0.0-IF004+ | ❌ NOT SUPPORTED | ❌ NOT SUPPORTED | ❌ NOT SUPPORTED | ✅ SUPPORTED | ❌ NOT SUPPORTED |
| Upgrade | v26.0.0 GA | v25.0.1-IF001 | N/A | N/A | N/A | ✅ SUPPORTED | N/A |

**Notes: Upgrade from**
- **v24.0.0-IF009+**:
  - Requires External Postgres for IM/Zen/BTS
  - This upgrade migrates MongoDB to External Postgres for ADP Gitgateway & ADS Gitservice
  - Migration MongoDB to Embedded Postgres (CNPG) not supported yet
  - **Note**: Supported upgrade path if user started from v24.0.0-IF004 or before, then upgraded to v24.0.0-IF009, because only before v24.0.0-IF004, users were allowed to have External Postgres for IM/Zen/BTS when CP4BA uses DB2/Oracle/MSSQL
- **v24.0.1-IF00x**: Cannot upgrade directly from v24.0.1. Must upgrade to v25.0.0-IF004+ first.
- **v25.0.0-IF004+**:
  - Requires External Postgres for all components (CP4BA, IM, Zen and BTS)
  - If any of these components (IM, Zen, BTS, ADS GitService, or ADP Gitgateway) are using embedded EDB, cannot upgrade because there is no EDB to CNPG migration yet
- **v25.0.1-IF001**: Only supported External Postgres, so this is the only upgrade path available.

---

## UPGRADE TO v26.0.0-IF001+

| Scenario Type | Target Version | Source Version | DB2 | MSSQL | Oracle | External Postgres | Embedded CNPG |
|---------------|----------------|----------------|-----|-------|--------|-------------------|---------------|
| Upgrade | v26.0.0-IF001+ | v24.0.0-IF009+ | ✅ SUPPORTED | ✅ SUPPORTED | ✅ SUPPORTED | ✅ SUPPORTED | ✅ SUPPORTED |
| Upgrade | v26.0.0-IF001+ | v24.0.1-IF00x | ⚠️ MUST UPGRADE TO v25.0.0-IF004+ FIRST | ⚠️ MUST UPGRADE TO v25.0.0-IF004+ FIRST | ⚠️ MUST UPGRADE TO v25.0.0-IF004+ FIRST | ⚠️ MUST UPGRADE TO v25.0.0-IF004+ FIRST | ⚠️ MUST UPGRADE TO v25.0.0-IF004+ FIRST |
| Upgrade | v26.0.0-IF001+ | v25.0.0-IF004+ | ✅ SUPPORTED | ✅ SUPPORTED | ✅ SUPPORTED | ✅ SUPPORTED | ✅ SUPPORTED |
| Upgrade | v26.0.0-IF001+ | v25.0.1-IF001 | N/A | N/A | N/A | ✅ SUPPORTED | N/A |

**Notes: Upgrade from**
- **v24.0.0-IF009+**:
  - Full CNPG support including EDB to CNPG migration for embedded scenarios
  - All external PG DBs created for external Postgres scenarios
- **v24.0.1-IF00x**: Cannot upgrade directly from v24.0.1. Must upgrade to v25.0.0-IF004+ first.
- **v25.0.0-IF004+**:
  - Full CNPG support including EDB to CNPG migration for embedded scenarios
  - All external PG DBs created for external Postgres scenarios
- **v25.0.1-IF001**: v25.0.1 only supported External Postgres. PG SQL scripts provided for all CP4BA components.

---

# Manual Configuration Steps

**For: CP4BA on DB2/Oracle/MSSQL + ADP Gitgateway/DICMS on External PostgreSQL**

## Prerequisites

Before following these manual configuration steps, you must complete the standard CP4BA prerequisite workflow:

1. **Generate property files**:
   ```bash
   ./cp4a-prerequisites.sh -m property -n <cp4ba-ns>
   ```
2. **Generate secrets and scripts**:
   ```bash
   ./cp4a-prerequisites.sh -m generate -n <cp4ba-ns>
   ```

After completing these steps, the generated secret templates will be available in `./cert-kubernetes/scripts/cp4ba-prerequisites/project/<cp4ba-ns>/secret_template/`.

## Step 1: Create PostgreSQL SSL Secret:

**NOTE: only SSL client certificate authentication is supported**

The following properties in the generated property file (`cp4ba_db_name_user.property`) should be blank if they exist:

- ADP_GG_DB_USER_PASSWORD
- ADP_BASE_DB_USER_PASSWORD
- ADP_PROJECT_DB_USER_PASSWORD
- DICMS_RUNTIME_DB_USER_PASSWORD
- DICMS_DESIGNER_DB_USER_PASSWORD

If they are not blank, please clear the values and re-run the `-m generate` command.  The secret templates will be updated which mean you need to run `create_secret.sh` again.  In the case of Vault, the generated JSON files for Vault secrets will also be updated, so you need to re-create the secrets in Vault.


### For Non-Vault Deployment

Create the SSL secret for external PostgreSQL connection:

```bash
oc create secret generic "ibm-cp4ba-postgresdb-ssl-secret" \
  --from-file=tls.crt="/root/postgres/cert/client.crt" \
  --from-file=ca.crt="/root/postgres/cert/root.crt" \
  --from-file=tls.key="/root/postgres/cert/client.key" \
  --from-literal=sslmode=verify-ca -n <cp4ba-ns>
```

### For Vault Deployment

You need to manually create two files for Vault integration:

1. **Create `ibm-cp4ba-postgresdb-ssl-secret.json`** with your SSL certificate data:
   ```json
   {
     "_comment": "Create a ibm-cp4ba-postgresdb-ssl-secret for Vault (eg: vault kv put /secret/cp4ba/ibm-cp4ba-postgresdb-ssl-secret @ibm-cp4ba-postgresdb-ssl-secret.json)",
     "tls.crt": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
     "ca.crt": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
     "tls.key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
     "sslmode": "verify-ca"
   }
   ```
   NOTE: To convert the certificates and key files to single-line format, you can use the following command:

   ```bash
    cat client.crt | tr '\n' '\\' | sed 's/\\/\\n/g; s/\\n$//'
   ```
2. **Create `ibm-cp4ba-postgresdb-ssl-secret-provider-class.yaml`**:
   ```yaml
   apiVersion: secrets-store.csi.x-k8s.io/v1
   kind: SecretProviderClass
   metadata:
     name: "ibm-cp4ba-postgresdb-ssl-secret"
     namespace: "<cp4ba-ns>"
     labels:
       cp4ba.ibm.com/backup-type: mandatory
     annotations:
       cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator,ibm-dpe-operator,ibm-odm-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
       cp4ba.ibm.com/secret-store-type: tls
   spec:
     provider: vault
     parameters:
       roleName: "csi"
       vaultAddress: "http://vault.vault:8200"
       objects: |
         - secretPath: "/secret/data/cp4ba/ibm-cp4ba-postgresdb-ssl-secret"
           objectName: "tls.crt"
           secretKey: "tls.crt"
         - secretPath: "/secret/data/cp4ba/ibm-cp4ba-postgresdb-ssl-secret"
           objectName: "ca.crt"
           secretKey: "ca.crt"
         - secretPath: "/secret/data/cp4ba/ibm-cp4ba-postgresdb-ssl-secret"
           objectName: "tls.key"
           secretKey: "tls.key"
         - secretPath: "/secret/data/cp4ba/ibm-cp4ba-postgresdb-ssl-secret"
           objectName: "sslmode"
           secretKey: "sslmode"
   ```
    NOTE: For Separation of Duty deployment, create another SecretProviderClass with the same content except the `namespace` property should be updated to the namespace of the operators.  In addition, the filename must have a format of `ibm-cp4ba-postgresdb-ssl-secret-provider-class-<operator-ns>.yaml` to differentiate from the one created for non-Separation of Duty deployment where `<operator-ns>` is the name of the operator namespace.

3. **Create the secret in Vault**:
   ```bash
   vault kv put /secret/cp4ba/ibm-cp4ba-postgresdb-ssl-secret @ibm-cp4ba-postgresdb-ssl-secret.json
   ```

4. **Apply the SecretProviderClass**:
   ```bash
   # Copy the SecretProviderClass YAML to <dir>/cert-kubernetes/cp4ba-prerequisites/project/<cp4ba-ns>/secret_template/vault/tls/
   # Copy both SecretProviderClass YAML files if Separation of Duty deployment where one is for the operators in the same namespace as CP4BA and another one is for the operators in different namespace.
   cp ibm-cp4ba-postgresdb-ssl-secret-provider-class.yaml ./cert-kubernetes/scripts/cp4ba-prerequisites/project/<cp4ba-ns>/secret_template/vault/tls/
   # Apply the SecretProviderClass to the cluster
   # Apply both SecretProviderClass YAML files if Separation of Duty deployment.
   oc apply -f ibm-cp4ba-postgresdb-ssl-secret-provider-class.yaml
   ```
5. **Mount the Vault secret to CP4BA operators pods**:
   ```bash
    cd cert-kubernetes/scripts
    ./cp4a-vault.sh -m patch --csv "ibm-content-operator.v26.0.0,ibm-cp4a-operator.v26.0.0,ibm-cp4a-wfps-operator.v26.0.0,ibm-dpe-operator.v26.0.0,ibm-odm-operator.v26.0.0,ibm-pfs-operator.v26.0.0,ibm-workflow-operator.v26.0.0,icp4a-foundation-operator.v26.0.0" -n <ns> [--operatorNamespace <operator-ns>]  # operatorNamespace is only needed for Separation of Duty deployment if the operator namespace is different from CP4BA namespace
   ```

## Step 2: Create ADP Gitgateway Database if select ADP

**Important**: The username in the SQL script must match the value you configured in the property file.

**Check the property file** (`cp4ba_db_name_user.property`):
```properties
dbserver1.ADP_GG_DB_USER_NAME="adpuser"  # ← Use this username in SQL below
```

This value is used in both Vault and non-Vault scenarios:
- **Non-Vault**: Stored in `./secret_template/adp/ibm-adp-secret.yaml` as `adpggDBUsername`
- **Vault**: Stored in `./secret_template/vault/secrets/adp/ibm-adp-secret.json` as `adpggDBUsername`

**Run SQL script** (as PostgreSQL admin):
```sql
-- Create user (must match adpggDBUsername from secret)
CREATE ROLE adpuser WITH INHERIT LOGIN;

-- Create tablespace (modify location as needed)
CREATE TABLESPACE adpggdb_tbs OWNER adpuser LOCATION '/pgsqldata/adpggdb';
GRANT CREATE ON TABLESPACE adpggdb_tbs TO adpuser;

-- Create database
CREATE DATABASE adpggdb OWNER adpuser TABLESPACE adpggdb_tbs TEMPLATE template0 ENCODING UTF8;

-- Connect and create schema
\c adpggdb;
CREATE SCHEMA IF NOT EXISTS adpuser AUTHORIZATION adpuser;
GRANT ALL ON SCHEMA adpuser TO adpuser;

-- Set default schema
SET ROLE adpuser;
ALTER DATABASE adpggdb SET search_path TO adpuser;
REVOKE CONNECT ON DATABASE adpggdb FROM public;
```

## Step 3: Create DICMS Designer Database if select DICMS Designer

**Important**: The username in the SQL script must match the value you configured in the property file.

**Check the property file** (`cp4ba_db_name_user.property`):
```properties
dbserver1.DICMS_DESIGNER_DB_USER_NAME="adsdesigner"  # ← Use this username in SQL below
```

This value is used in both Vault and non-Vault scenarios:
- **Non-Vault**: Stored in `./secret_template/dicms/ibm-ads-designer-database.yaml` as `username`
- **Vault**: Stored in `./secret_template/vault/secrets/dicms/ibm-dicms-designer-secret.json` as `dbUsername`

**Run SQL script** (as PostgreSQL admin):
```sql
-- Create user (must match username from secret)
CREATE ROLE adsdesigner WITH INHERIT LOGIN;

-- Create tablespace (modify location as needed)
CREATE TABLESPACE adsdesignerdb_tbs OWNER adsdesigner LOCATION '/pgsqldata/adsdesignerdb';
GRANT CREATE ON TABLESPACE adsdesignerdb_tbs TO adsdesigner;

-- Create database
CREATE DATABASE adsdesignerdb OWNER adsdesigner TABLESPACE adsdesignerdb_tbs TEMPLATE template0 ENCODING UTF8;

-- Connect and create schema
\c adsdesignerdb;
CREATE SCHEMA IF NOT EXISTS ads AUTHORIZATION adsdesigner;
GRANT ALL ON SCHEMA ads TO adsdesigner;

-- Set default schema
SET ROLE adsdesigner;
ALTER DATABASE adsdesignerdb SET search_path TO ads;
REVOKE CONNECT ON DATABASE adsdesignerdb FROM public;
```

## Step 4: Create DICMS Runtime Database if select DICMS Runtime

**Important**: The username in the SQL script must match the value you configured in the property file.

**Check the property file** (`cp4ba_db_name_user.property`):
```properties
dbserver1.DICMS_RUNTIME_DB_USER_NAME="adsruntime"  # ← Use this username in SQL below
```

This value is used in both Vault and non-Vault scenarios:
- **Non-Vault**: Stored in `./secret_template/dicms/ibm-ads-runtime-database.yaml` as `username`
- **Vault**: Stored in `./secret_template/vault/secrets/dicms/ibm-dicms-runtime-secret.json` as `dbUsername`

**Run SQL script** (as PostgreSQL admin):
```sql
-- Create user (must match username from secret)
CREATE ROLE adsruntime WITH INHERIT LOGIN;

-- Create tablespace (modify location as needed)
CREATE TABLESPACE adsruntimedb_tbs OWNER adsruntime LOCATION '/pgsqldata/adsruntimedb';
GRANT CREATE ON TABLESPACE adsruntimedb_tbs TO adsruntime;

-- Create database
CREATE DATABASE adsruntimedb OWNER adsruntime TABLESPACE adsruntimedb_tbs TEMPLATE template0 ENCODING UTF8;

-- Connect and create schema
\c adsruntimedb;
CREATE SCHEMA IF NOT EXISTS ads AUTHORIZATION adsruntime;
GRANT ALL ON SCHEMA ads TO adsruntime;

-- Set default schema
SET ROLE adsruntime;
ALTER DATABASE adsruntimedb SET search_path TO ads;
REVOKE CONNECT ON DATABASE adsruntimedb FROM public;
```

## Step 5: Update CR YAML After Deployment Script

After running `./cp4a-deployment.sh -n <cp4ba-ns>`, update the generated CR YAML file.

**Why?** The deployment script generates EDB Postgres configuration by default. You need to change it to external PostgreSQL.

**Update these sections** in the CR YAML:

```yaml
dc_adp_datasource:
  dc_use_postgres: false
  dc_database_type: postgresql
  database_servername: postgres.xyz.com  # Your external PostgreSQL server
  database_name: adpggdb
  database_port: "5432"
  database_ssl_secret_name: 'ibm-cp4ba-postgresdb-ssl-secret'  # Secret from Step 1

dc_ads_designer_datasource:
  dc_use_postgres: false
  dc_database_type: postgresql
  database_servername: postgres.xyz.com  # Your external PostgreSQL server
  database_name: adsdesignerdb
  database_port: "5432"
  current_schema: ads
  ssl_enabled: true
  ssl_mode: verify-ca
  database_instance_secret: ibm-ads-designer-database  # This parameter is not used when Vault is enabled
  database_ssl_secret_name: 'ibm-cp4ba-postgresdb-ssl-secret'  # Secret from Step 1
 
dc_ads_runtime_datasource:
  dc_use_postgres: false
  dc_database_type: postgresql
  database_servername: postgres.xyz.com  # Your external PostgreSQL server
  database_name: adsruntimedb
  database_port: "5432"
  current_schema: ads
  ssl_enabled: true
  ssl_mode: verify-ca
  database_instance_secret: ibm-ads-runtime-database  # This parameter is not used when Vault is enabled
  database_ssl_secret_name: 'ibm-cp4ba-postgresdb-ssl-secret'  # Secret from Step 1
```

---

# Manual Configuration Steps for Upgrade

The `./cp4a-deployment.sh -m upgradeDeployment -n <cp4ba-ns>` command will display messages describing the steps that the user needs to perform.
