#!/bin/bash
#set -x
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

# Helper functions to support secrets in Vault 

# ============================================
# Constants
# ============================================

#DBACLD-234491 This is a list of CSVs that will be EXCLUDED from the CSV patch list for Vault integration.
# Some CSV/Operators do not need to have the SecretProviderClass mounted in their pods, and therefore do not need to be patched.
# This exclusion list is used in the logic to generate the final list of CSVs to patch for Vault integration.
## We'll determine the CSV list to patch for Vault integration by:
## 1. Iterate through all the SPC yaml files at $VAULT_SECRET_PARENT_FOLDER
## 2. Read the metadata.annotations."cp4ba.ibm.com/owned-by" field in each SPC yaml file to get the list of comma-separated operators that should have the SPC mounted
## 3. Duplicates will be removed when we aggregate the list of operators from all the SPC yaml files
## 4. If a SPC does not have the "cp4ba.ibm.com/owned-by" annotation, we display a warning and ignore that SPC for CSV patch determination
## 5. Operators in VAULT_EXCLUDE_PATCH_LIST_OF_CSV are excluded from the final _vault_csv_list
VAULT_EXCLUDE_PATCH_LIST_OF_CSV=(
  "ibm-bts-operator"
  "ibm-iam-operator"
)

# Useful for KC links. Set the CP4BA major release version if not already set
CP4BA_RELEASE_BASE=${CP4BA_RELEASE_BASE:-"26.0.0"}

# For 26.0.0 we will only support Hashicorp Vault, but in the future, will add a prompt to ask which external secrets management provider they want to use.
EXT_SECRETS_MGMT_PROVIDER="vault"

##DBACLD-185209: Vault's implementation.  Define supported secret/certificates names for Vault
# If it's a regular (non-tls) secret then use VAULT_SECRET_FILE_FOLDER.  Otherwise, use VAULT_TLS_SECRET_FILE_FOLDER
VAULT_SECRET_PARENT_FOLDER=${SECRET_FILE_FOLDER}/vault
VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_PARENT_FOLDER}/secrets
VAULT_TLS_SECRET_FILE_FOLDER=${VAULT_SECRET_PARENT_FOLDER}/tls

# Sample script file to show commands to create the secrets in vault using "vault kv put"
CREATE_VAULT_SECRET_SCRIPT_FILE=$PREREQUISITES_FOLDER/create_vault_secrets_example.sh

#ldap-bind-secret
VAULT_LDAP_SECRET_FILE=${VAULT_SECRET_FILE_FOLDER}/ldap-bind-secret.json
VAULT_LDAP_SECRET_PROVIDER_CLASS_FILE=${VAULT_SECRET_FILE_FOLDER}/ldap-bind-secret-provider-class

#ldap-bind-secret-tls
VAULT_LDAP_SECRET_TLS_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/cp4ba_ldap_ssl_secret
VAULT_LDAP_SECRET_TLS_FILE=${VAULT_LDAP_SECRET_TLS_FOLDER}/ldap-bind-secret-tls.json
VAULT_LDAP_SECRET_TLS_PROVIDER_CLASS_FILE=${VAULT_LDAP_SECRET_TLS_FOLDER}/ldap-bind-secret-tls-provider-class

#ibm-ban-secret
BAN_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/ban
BAN_VAULT_SECRET_FILE=${BAN_VAULT_SECRET_FILE_FOLDER}/ibm-ban-secret.json
BAN_VAULT_SECRET_PROVIDER_CLASS_FILE=${BAN_VAULT_SECRET_FILE_FOLDER}/ibm-ban-secret-provider-class

##DBACLD-193988: Implementing Vault integration for BTS/ZEN/IM
#bts-datastore-edb-secret
BTS_VAULT_SECRET_FILE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/bts_db_ssl_secret
BTS_VAULT_SECRET_FILE=${BTS_VAULT_SECRET_FILE_FOLDER}/bts-datastore-edb-secret.json
BTS_VAULT_SECRET_PROVIDER_CLASS_FILE=${BTS_VAULT_SECRET_FILE_FOLDER}/bts-datastore-edb-secret-provider-class
#im-datastore-edb-secret
IM_VAULT_SECRET_FILE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/im_db_ssl_secret
IM_VAULT_SECRET_FILE=${IM_VAULT_SECRET_FILE_FOLDER}/im-datastore-edb-secret.json
IM_VAULT_SECRET_PROVIDER_CLASS_FILE=${IM_VAULT_SECRET_FILE_FOLDER}/im-datastore-edb-secret-provider-class
#zen-metastore-edb-secret
ZEN_VAULT_SECRET_FILE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/zen_db_ssl_secret
ZEN_VAULT_SECRET_FILE=${ZEN_VAULT_SECRET_FILE_FOLDER}/zen-metastore-edb-secret.json
ZEN_VAULT_SECRET_PROVIDER_CLASS_FILE=${ZEN_VAULT_SECRET_FILE_FOLDER}/zen-metastore-edb-secret-provider-class

#ibm-fncm-secret
FNCM_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/content-cortex
FNCM_VAULT_SECRET_FILE=${FNCM_VAULT_SECRET_FILE_FOLDER}/ibm-content-cortex-secret.json
FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE=${FNCM_VAULT_SECRET_FILE_FOLDER}/ibm-content-cortex-secret-provider-class

#db-ssl-secret
DB_VAULT_SECRET_FILE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/cp4ba_db_ssl_secret
# DB_VAULT_SECRET_FILE=${DB_VAULT_SECRET_FILE_FOLDER}/ibm-db-ssl-secret.json
# DB_VAULT_SECRET_PROVIDER_CLASS_FILE=${DB_VAULT_SECRET_FILE_FOLDER}/ibm-db-ssl-secret-provider-class.yaml

#ibm-icc-secret
FNCM_ICC_VAULT_SECRET_FILE=${FNCM_VAULT_SECRET_FILE_FOLDER}/ibm-content-cortex-icc-secret.json
FNCM_ICC_VAULT_SECRET_PROVIDER_CLASS_FILE=${FNCM_VAULT_SECRET_FILE_FOLDER}/ibm-content-cortex-icc-secret-provider-class

#ibm-iccsap-secret
FNCM_ICCSAP_VAULT_SECRET_FILE=${FNCM_VAULT_SECRET_FILE_FOLDER}/ibm-content-cortex-iccsap-secret.json
FNCM_ICCSAP_VAULT_SECRET_PROVIDER_CLASS_FILE=${FNCM_VAULT_SECRET_FILE_FOLDER}/ibm-content-cortex-iccsap-secret-provider-class

#ibm-ier-secret
FNCM_IER_VAULT_SECRET_FILE=${FNCM_VAULT_SECRET_FILE_FOLDER}/ibm-content-cortex-ier-secret.json
FNCM_IER_VAULT_SECRET_PROVIDER_CLASS_FILE=${FNCM_VAULT_SECRET_FILE_FOLDER}/ibm-content-cortex-ier-secret-provider-class

#aca-basedb
ADP_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/adp
ADP_BASEDB_VAULT_SECRET_FILE=${ADP_VAULT_SECRET_FILE_FOLDER}/aca-basedb.json
ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE=${ADP_VAULT_SECRET_FILE_FOLDER}/aca-basedb-secret-provider-class

#ibm-adp-secret
ADP_VAULT_SECRET_FILE=${ADP_VAULT_SECRET_FILE_FOLDER}/ibm-adp-secret.json
ADP_VAULT_SECRET_PROVIDER_CLASS_FILE=${ADP_VAULT_SECRET_FILE_FOLDER}/ibm-adp-secret-provider-class

#ibm-adp-git-connection-secret
ADP_GIT_VAULT_SECRET_FILE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/adp_git
ADP_GIT_VAULT_SECRET_FILE=${ADP_GIT_VAULT_SECRET_FILE_FOLDER}/ibm-adp-git-connection-secret.json
ADP_GIT_VAULT_SECRET_PROVIDER_CLASS_FILE=${ADP_GIT_VAULT_SECRET_FILE_FOLDER}/ibm-adp-git-connection-secret-provider-class

#ibm-adp-cdra-ssl-secret
ADP_CDRA_VAULT_SECRET_FILE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/adp_cdra
ADP_CDRA_VAULT_SECRET_FILE=${ADP_CDRA_VAULT_SECRET_FILE_FOLDER}/ibm-adp-cdra-ssl-secret.json
ADP_CDRA_VAULT_SECRET_PROVIDER_CLASS_FILE=${ADP_CDRA_VAULT_SECRET_FILE_FOLDER}/ibm-adp-cdra-ssl-secret-provider-class

#ibm-adp-aca-design-api-key-secret
ADP_ACA_DESIGN_API_KEY_VAULT_SECRET_FILE=${ADP_VAULT_SECRET_FILE_FOLDER}/ibm-adp-aca-design-api-key-secret.json
ADP_ACA_DESIGN_API_KEY_VAULT_SECRET_PROVIDER_CLASS_FILE=${ADP_VAULT_SECRET_FILE_FOLDER}/ibm-adp-aca-design-api-key-secret-provider-class

# ibm-ads-designer-secret
DI_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/dicms
DI_DESIGNER_VAULT_SECRET_FILE=${DI_VAULT_SECRET_FILE_FOLDER}/ibm-dicms-designer-secret.json
DI_DESIGNER_VAULT_SECRET_PROVIDER_CLASS_FILE=${DI_VAULT_SECRET_FILE_FOLDER}/ibm-dicms-designer-provider-class

# ibm-ads-runtime-secret
DI_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/dicms
DI_RUNTIME_VAULT_SECRET_FILE=${DI_VAULT_SECRET_FILE_FOLDER}/ibm-dicms-runtime-secret.json
DI_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE=${DI_VAULT_SECRET_FILE_FOLDER}/ibm-dicms-runtime-provider-class

# ibm-odm-db-secret
ODM_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/odm
ODM_VAULT_SECRET_FILE=${ODM_VAULT_SECRET_FILE_FOLDER}/ibm-odm-db-secret.json
ODM_VAULT_SECRET_PROVIDER_CLASS_FILE=${ODM_VAULT_SECRET_FILE_FOLDER}/ibm-odm-db-secret-provider-class
ODM_VAULT_KEYSTORE_PASSWORD_SECRET_FILE=${ODM_VAULT_SECRET_FILE_FOLDER}/ibm-odm-keystore-secret.json
ODM_VAULT_KEYSTORE_PASSWORD_SECRET_PROVIDER_CLASS_FILE=${ODM_VAULT_SECRET_FILE_FOLDER}/ibm-odm-keystore-secret-provider-class

# ---- Shared secrets variables ----
# root_ca_secret: Folder for storing root CA templates
ROOT_CA_TEMPLATE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/cp4ba_root_ca_secret
ROOT_CA_SECRET_FILE=${ROOT_CA_TEMPLATE_FOLDER}/root-ca-secret.json
ROOT_CA_SECRET_PROVIDER_CLASS_FILE=${ROOT_CA_TEMPLATE_FOLDER}/root-ca-secret-provider-class

# external-tls-cert: Folder for storing external TLS certificate templates
EXTERNAL_TLS_TEMPLATE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/cp4ba_external_tls_certificate
EXTERNAL_TLS_CERT_SECRET_FILE=${EXTERNAL_TLS_TEMPLATE_FOLDER}/external-tls-cert-secret.json
EXTERNAL_TLS_CERT_SECRET_PROVIDER_CLASS_FILE=${EXTERNAL_TLS_TEMPLATE_FOLDER}/external-tls-cert-secret-provider-class

#trusted-certificates. Folder for storing trusted certificate templates
TRUSTED_CERT_TEMPLATE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/trusted_certificate_list

# set flags so we remember if these optional custom secrets have been set in properties files. default to false
FLAG_ROOT_CA_SECRET=false
FLAG_EXTERNAL_CA_SECRET=false
FLAG_TRUSTED_CERT_SECRET=false

# AE Redis SSL secret
AE_REDIS_VAULT_SECRET_FILE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/cp4ba_redis_ssl_secret
AE_REDIS_VAULT_SECRET_FILE=${AE_REDIS_VAULT_SECRET_FILE_FOLDER}/ae-redis-ssl-secret.json
AE_REDIS_VAULT_SECRET_PROVIDER_CLASS_FILE=${AE_REDIS_VAULT_SECRET_FILE_FOLDER}/ae-redis-ssl-secret-provider-class

# Playback Redis SSL secret
PLAYBACK_REDIS_VAULT_SECRET_FILE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/cp4ba_redis_ssl_secret
PLAYBACK_REDIS_VAULT_SECRET_FILE=${PLAYBACK_REDIS_VAULT_SECRET_FILE_FOLDER}/playback-redis-ssl-secret.json
PLAYBACK_REDIS_VAULT_SECRET_PROVIDER_CLASS_FILE=${PLAYBACK_REDIS_VAULT_SECRET_FILE_FOLDER}/playback-redis-ssl-secret-provider-class

# Application Engine secret
APP_ENGINE_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/app_engine
APP_ENGINE_VAULT_SECRET_FILE=${APP_ENGINE_VAULT_SECRET_FILE_FOLDER}/icp4adeploy-workspace-aae-app-engine-admin-secret.json
APP_ENGINE_VAULT_SECRET_PROVIDER_CLASS_FILE=${APP_ENGINE_VAULT_SECRET_FILE_FOLDER}/icp4adeploy-workspace-aae-app-engine-admin-secret-provider-class

# Application Engine Oracle SSO secret
APP_ENGINE_ORACLE_SSO_VAULT_SECRET_FILE_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/app_engine_oracle_sso
APP_ENGINE_ORACLE_SSO_VAULT_SECRET_FILE=${APP_ENGINE_ORACLE_SSO_VAULT_SECRET_FILE_FOLDER}/app-engine-oracle-sso-secret.json
APP_ENGINE_ORACLE_SSO_VAULT_SECRET_PROVIDER_CLASS_FILE=${APP_ENGINE_ORACLE_SSO_VAULT_SECRET_FILE_FOLDER}/app-engine-oracle-sso-secret-provider-class

# Business Automation Studio secret
BAS_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/bas
BAS_VAULT_SECRET_FILE=${BAS_VAULT_SECRET_FILE_FOLDER}/icp4adeploy-bas-admin-secret.json
BAS_VAULT_SECRET_PROVIDER_CLASS_FILE=${BAS_VAULT_SECRET_FILE_FOLDER}/icp4adeploy-bas-admin-secret-provider-class

# AE Playback secret
AE_PLAYBACK_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/ae_playback
AE_PLAYBACK_VAULT_SECRET_FILE=${AE_PLAYBACK_VAULT_SECRET_FILE_FOLDER}/playback-server-admin-secret.json
AE_PLAYBACK_VAULT_SECRET_PROVIDER_CLASS_FILE=${AE_PLAYBACK_VAULT_SECRET_FILE_FOLDER}/playback-server-admin-secret-provider-class

# Workflow Assistant secret
WORKFLOW_ASSISTANT_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/workflow_assistant
WORKFLOW_ASSISTANT_VAULT_SECRET_FILE=${WORKFLOW_ASSISTANT_VAULT_SECRET_FILE_FOLDER}/ibm-workflow-assistant-secrets.json
WORKFLOW_ASSISTANT_VAULT_SECRET_PROVIDER_CLASS_FILE=${WORKFLOW_ASSISTANT_VAULT_SECRET_FILE_FOLDER}/ibm-workflow-assistant-secrets-provider-class

# BAW Authoring secret
BAW_AUTHORING_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/baw_authoring
BAW_AUTHORING_VAULT_SECRET_FILE=${BAW_AUTHORING_VAULT_SECRET_FILE_FOLDER}/ibm-baw-wfs-server-db-secret.json
BAW_AUTHORING_VAULT_SECRET_PROVIDER_CLASS_FILE=${BAW_AUTHORING_VAULT_SECRET_FILE_FOLDER}/ibm-baw-wfs-server-db-secret-provider-class

# BAW AWS (Automation Workstream Services) secret
BAW_AWS_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/baw_aws
BAW_AWS_VAULT_SECRET_FILE=${BAW_AWS_VAULT_SECRET_FILE_FOLDER}/ibm-aws-wfs-server-db-secret.json
BAW_AWS_VAULT_SECRET_PROVIDER_CLASS_FILE=${BAW_AWS_VAULT_SECRET_FILE_FOLDER}/ibm-aws-wfs-server-db-secret-provider-class

# BAW Runtime secret
BAW_RUNTIME_VAULT_SECRET_FILE_FOLDER=${VAULT_SECRET_FILE_FOLDER}/baw_runtime
BAW_RUNTIME_VAULT_SECRET_FILE=${BAW_RUNTIME_VAULT_SECRET_FILE_FOLDER}/ibm-baw-wfs-server-db-secret.json
BAW_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE=${BAW_RUNTIME_VAULT_SECRET_FILE_FOLDER}/ibm-baw-wfs-server-db-secret-provider-class

# Content Cortex AI Services secret file related variables
AI_SERVICES_VAULT_SECRET_FOLDER=${VAULT_SECRET_FILE_FOLDER}/aiservices
AI_SERVICES_VAULT_CONFIG_SECRET_FILE=${AI_SERVICES_VAULT_SECRET_FOLDER}/ibm-providers-config-secret.json
AI_SERVICES_VAULT_CONFIG_SECRET_PROVIDER_CLASS_FILE=${AI_SERVICES_VAULT_SECRET_FOLDER}/ibm-providers-config-secret-provider-class

AI_SERVICES_VAULT_TLS_SECRET_FOLDER=${VAULT_TLS_SECRET_FILE_FOLDER}/aiservices
AI_SERVICES_VAULT_SSL_SECRET_FILE=${AI_SERVICES_VAULT_TLS_SECRET_FOLDER}/watsonx-lwe-ssl-secret.json
AI_SERVICES_VAULT_SSL_SECRET_PROVIDER_CLASS_FILE=${AI_SERVICES_VAULT_TLS_SECRET_FOLDER}/watsonx-lwe-ssl-secret-provider-class

# ============================================
# HELPER functions
# ============================================

# Helper function to extract JSON property values that may contain embedded quotes
# This function also unescapes the backslash-escaped quotes since jq will re-escape them
# Parameters:
#   $1: property name
#   $2: property file path
function prop_user_profile_json_property() {
  local property_name="$1"
  local property_file="$2"
  grep "^${property_name}=" "${property_file}" | sed 's/^[^=]*=//' | sed 's/^"//' | sed 's/"$//' | sed 's/\\"/"/g'
}

# Helper function to append an object to the SecretProviderClass objects string
# Parameters:
#   $1: SecretProviderClass YAML file path
#   $2: secretPath value
#   $3: objectName value
#   $4: secretKey value
function append_to_secretprovider_objects() {
    local file_path="$1"
    local secret_path="$2"
    local object_name="$3"
    local secret_key="$4"
    
    # Create the new object entry with proper indentation
    local new_entry="      - secretPath: \"$secret_path\"
        objectName: \"$object_name\"
        secretKey: \"$secret_key\""
    
    # Use awk to insert before the last line (which should be after the objects block)
    # We insert at the end of the file since objects: | is a literal block
    echo "$new_entry" >> "$file_path"
}

# Helper function to confirm if a valid value was retrieved from Operator SecretProviderClass volume
function check_vault_secret_value() {
    local value=$1
    local secret_name=$2
    local key_name=$3
    local operator_name=$4
    
    if [[ -z "$value" || "$value" == "null" ]]; then
        error "Failed to retrieve value for \"$key_name\" from secret \"$secret_name\" in the \"$operator_name\" operator pod."
        error "This may indicate that the Vault secret was not created or that the \"$operator_name\" Operator CSV has not been patched to mount the SecretProviderClass."
        error "Please ensure you have created the Vault secrets and run the \"cp4a-vault.sh\" script as instructed in the \"-generate\" step to patch the Operator CSVs."
        error "After running cp4a-vault.sh, wait for the operator pods to restart and then re-run this validation."
    fi
}

# ============================================
# "property" mode functions
# ============================================

# Function to ask if customer want to enable integration with external secrets management provider. 
# For 26.0.0, we only support Hashicorp Vault
# Default is No
function ask_enable_vault() {
    while true; do
        printf "\x1B[1mDo you want to enable external secret management (Hashicorp Vault) integration for your custom secrets (Yes/No, default: No)? \x1B[0m"
        read -erp "" enable_vault

        case $(tr '[:upper:]' '[:lower:]' <<< "$enable_vault") in
            y|yes)
                info "IMPORTANT: Vault integration requires prerequisites steps. If you have not yet done so, please ensure you have followed the instructions in the CP4BA Knowledge Center topic 'Optional: Preparing for external secret management'"
                info "Vault integration will be enabled. Please fill out the Vault properties in the properties files in the next step. There will be additional instructions for creating Vault secrets and SecretProviderClasses."
                VAULT_ENABLED=true
                break
                ;;
            n|no|"")
                info "Vault integration will not be enabled."
                VAULT_ENABLED=false
                break
                ;;
            *)
                echo "[ERROR] Invalid input. Please enter Yes/No (Y/N)."
                ;;
        esac
    done
}


# Function to add Vault properties to user profile properties file
function add_vault_props() {
    # if [[ $VAULT_ENABLED == "true" && " ${pattern_cr_arr[@]}" =~ "content" ]]; then
    info "Adding Vault properties to the user profile properties file"
    if [[ $VAULT_ENABLED == "true" ]]; then
        # Only add Vault section header if it doesn't exist
        if ! grep -q "##             Properties for Vault" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "##             Properties for Vault               ##" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        
        # Only add CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION if it doesn't exist
        if ! grep -q "^CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
            echo "## NOTE: If set as \"true\", CP4BA will integrate with Vault to retrieve custom secrets from Vault." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Reference: From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/${CP4BA_RELEASE_BASE} navigate to Planning for a production deployment --> Planning for a CP4BA multi-pattern production deployment --> External secret management" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION=\"$VAULT_ENABLED\"" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        
        # Only add CP4BA.VAULT_ROLE if it doesn't exist
        if ! grep -q "^CP4BA.VAULT_ROLE=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
            echo "# The Vault's role that would allow CP4BA to read the secrets" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CP4BA.VAULT_ROLE=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        
        # Only add CP4BA.VAULT_ADDRESS if it doesn't exist
        if ! grep -q "^CP4BA.VAULT_ADDRESS=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
            echo "# The Vault's address that would allow CP4BA to reach and consume Vault's secret. For example: \"https://vault.default:8200\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CP4BA.VAULT_ADDRESS=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        
        # Only add CP4BA.VAULT_PATH if it doesn't exist
        if ! grep -q "^CP4BA.VAULT_PATH=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
            echo "#The Vault's path to all the secrets.  Only a single path can be specified. For example, if you store all the secrets under /v1/secret/data/cp4a, then use secret/data/cp4a"  >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CP4BA.VAULT_PATH=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        echo
        
        # DBACLD-217419: Support shared secrets in Vault
        # Only add CP4BA.ROOT_CA_SECRET if it doesn't exist
        if ! grep -q "^CP4BA.ROOT_CA_SECRET=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
            echo "## Optional: Name of custom secret in Vault containing root CA certificate" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# If not specified, CP4BA will create and use a Kubernetes secret containing a default root CA certificate" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# If specified, you must create a secret in Vault containing the certificate. A JSON template will be generated in next steps to assist in creating the secret." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# Provide the \"tls.crt\" (CA cert) and \"tls.key\" (private key) files in the directory \"${ROOT_CA_CERT_FOLDER}\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# Reference: From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/${CP4BA_RELEASE_BASE} navigate to Administering --> Configuring security --> Managing certificates --> Allowing external services to connect with endpoints over TLS --> Changing the default root CA signer certificate" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CP4BA.ROOT_CA_SECRET=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi

        # Only add CP4BA.EXTERNAL_TLS_CERTIFICATE_SECRET if it doesn't exist
        if ! grep -q "^CP4BA.EXTERNAL_TLS_CERTIFICATE_SECRET=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
            echo "## Optional: Name of custom secret in Vault containing TLS certificate for external TLS connections" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# If specified, you must create a secret in Vault containing the certificate. A JSON template will be generated in next steps to assist in creating the secret." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# Provide the \"tls.crt\" (TLS cert) and \"tls.key\" (private key) files in the directory \"${EXTERNAL_TLS_CERT_FOLDER}\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# Reference: From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/${CP4BA_RELEASE_BASE} navigate to Administering --> Configuring security --> Managing certificates --> Allowing external services to connect with endpoints over TLS --> Creating secure endpoints for external services" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CP4BA.EXTERNAL_TLS_CERTIFICATE_SECRET=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
                
        # Only add CP4BA.TRUSTED_CERTIFICATE_LIST if it doesn't exist
        if ! grep -q "^CP4BA.TRUSTED_CERTIFICATE_LIST=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
            echo "## Optional: Comma-separated list of names of custom secrets stored in Vault containing your trusted certificates." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# Example: \"secret1,secret2,secret3\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# If specified, you must create the corresponding secrets in Vault containing the certificates. JSON templates will be generated in next steps to assist in creating the secrets." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# Provide the \"<secretname>.crt\" (TLS cert) file for each secret in the directory \"${TRUSTED_CERT_FOLDER}\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "# Reference: From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/${CP4BA_RELEASE_BASE} navigate to Administering --> Configuring security --> Managing certificates --> Connecting endpoints to external services over TLS --> Importing the certificate of an external service" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CP4BA.TRUSTED_CERTIFICATE_LIST=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
          
    fi
}

############################################
## Retrieve original property files and load live CR
############################################
# 1. Attempt to retrieve existing properties files
# 2. If props files are not in current dir, ask user for the location of the props files
#    a. If user does not have existing props files:
#      1. Tell user they must answer all the deployment questions and select the same options that matches their current deployment.
#      2. Exit this function and return to calling function to prompt user for the deployment options
# 3. Copy the files to the current location
# 4. Load the live CR 
# 5. Construct arrays (patterns, optional_components, etc) in order to create TEMP file with values for scripts to use later
function retrieve_orig_props_and_live_cr(){

    # Leverage some of the functions from update components mode
    source ${CUR_DIR}/helper/update-selected-components/update-selected-components.sh

    # Initialize to false
    EXISTING_PROP_FILES_PROVIDED="false"
    retrieve_existing_property_files

    if [[ "$EXISTING_PROP_FILES_PROVIDED" != "true" ]]; then
        # If user is not able to provide the original prop files, return to calling function 
        # and treat this like a fresh deployment (all questions need to be answer by user)
        return
    fi

    # Retrieve current deployment configuration from live CR
    retrieve_current_custom_resource_file "$CP4BA_SERVICES_NS" "prerequisites_script"

    # Build arrays from retrieved values instead of calling select_pattern()
    # This preserves the existing deployment configuration without user interaction
    build_arrays_from_existing_deployment

    # Now create_temp_property_file will use the arrays we just built
    create_temp_property_file

}


# ============================================
# "generate" mode functions 
# - create SecretProviderClass and JSON templates for each secret
# ============================================

function setup_vault_settings() {
    vault_enabled="$(prop_user_profile_property_file CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION 2>/dev/null || echo 'false')"
    vault_enabled=$(echo "$vault_enabled" | tr '[:upper:]' '[:lower:]')

    # Generate root CA secret template if user has customized it
    if [[ $vault_enabled == 'true' ]]; then
        vault_role="$(prop_user_profile_property_file CP4BA.VAULT_ROLE)"
        vault_address="$(prop_user_profile_property_file CP4BA.VAULT_ADDRESS)"
        vault_path="$(prop_user_profile_property_file CP4BA.VAULT_PATH | sed 's|/$||')" # remove trailing slash if any

        # "vault kv put" will automatically add the "/data" in the path, so we should remove "/data" if it is part of path (eg. use "vault kv put secret/cp4a/my-secret")
        kv_vault_path=$(echo "$vault_path" | sed 's|secret/data|secret|')
    fi
}

# ======================================
# Shared secrets 
# ======================================

# ----------------
# root_ca_secret 
# ----------------
# Create templates for "root_ca_secret"
function create_root_ca_vault_template(){
  local _vault_secret_name=${1:-root-ca-secret}

  mkdir -p $ROOT_CA_TEMPLATE_FOLDER >/dev/null 2>&1
  
  # Read certificate files from ROOT_CA_CERT_FOLDER if they exist
  local tls_key_content=""
  local tls_crt_content=""
  
  if [[ -f "${ROOT_CA_CERT_FOLDER}/tls.key" && -f "${ROOT_CA_CERT_FOLDER}/tls.crt" ]]; then
    # Read the actual certificate files
    tls_key_content=$(<${ROOT_CA_CERT_FOLDER}/tls.key)
    tls_crt_content=$(<${ROOT_CA_CERT_FOLDER}/tls.crt)
    
    # Check if files are empty
    if [[ -z "$tls_key_content" || -z "$tls_crt_content" ]]; then
      # Use placeholders if files are empty
      tls_key_content="<Content of custom root CA key in plain-text in a single-line>"
      tls_crt_content="<Content of custom root CA certificate in plain-text in a single-line>"
    else
      # Remove carriage returns and convert multi-line certificates to single line with escaped newlines
      tls_key_content=$(echo "$tls_key_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
      tls_crt_content=$(echo "$tls_crt_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    fi
  else
    # Files don't exist - fail with error
    error "To create the template for the root_ca_secret for Vault, please provide the \"tls.crt\" (CA cert) and \"tls.key\" (private key) files in the directory \"${ROOT_CA_CERT_FOLDER}\"."\
" If you do not want to provide the real files, create empty files with these names and rerun. The template will be created with placeholders."
    exit 1
  fi
  
  cat << EOF > ${ROOT_CA_SECRET_FILE}
{
  "_comment": "Create $_vault_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_vault_secret_name @${ROOT_CA_SECRET_FILE}). The name should match the SecretProviderClass name (e.g. ${_vault_secret_name}). Optionally, this property, _comment, can be removed before creating the secret.",
  "tls.key": "$tls_key_content",
  "tls.crt": "$tls_crt_content"
}

EOF

cat << EOF > ${ROOT_CA_SECRET_PROVIDER_CLASS_FILE}.yaml
# YAML template for OPTIONAL custom CP4BA root CA certificate SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_vault_secret_name), and match with shared_configuration.root_ca_secret
# The keys in this template should match with the keys in the $_vault_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_vault_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator,ibm-insights-engine-operator,ibm-dpe-operator,ibm-odm-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_vault_secret_name"
        objectName: "tls.key"
        secretKey: "tls.key"
      - secretPath: "$vault_path/$_vault_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
EOF

#Create SecretProviderClass for OPTIONAL custom CP4BA root CA certificate when for separation of duties 
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for root-ca in $CP4BA_OPERATOR_NS namespace"
  cp "${ROOT_CA_SECRET_PROVIDER_CLASS_FILE}".yaml "${ROOT_CA_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}".yaml
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${ROOT_CA_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi
success "Created OPTIONAL custom CP4BA root CA certificate template and SecretProviderClass template for Vault\n"
}


# --------------------------
# external_tls_certificate
# --------------------------
# Create templates for "external_tls_certificatet"
function create_external_tls_cert_vault_template(){
  local _vault_secret_name=${1:-external-tls-cert}

  mkdir -p $EXTERNAL_TLS_TEMPLATE_FOLDER >/dev/null 2>&1
  
  # Read certificate files from EXTERNAL_TLS_CERT_FOLDER if they exist
  local tls_key_content=""
  local tls_crt_content=""
  
  if [[ -f "${EXTERNAL_TLS_CERT_FOLDER}/tls.key" && -f "${EXTERNAL_TLS_CERT_FOLDER}/tls.crt" ]]; then
    # Read the actual certificate files
    tls_key_content=$(<${EXTERNAL_TLS_CERT_FOLDER}/tls.key)
    tls_crt_content=$(<${EXTERNAL_TLS_CERT_FOLDER}/tls.crt)
    
    # Check if files are empty
    if [[ -z "$tls_key_content" || -z "$tls_crt_content" ]]; then
      # Use placeholders if files are empty
      tls_key_content="<Content of external TLS certificate key in a single-line>"
      tls_crt_content="<Content of external TLS certificate in a single-line>"
    else
      # Remove carriage returns and convert multi-line certificates to single line with escaped newlines
      tls_key_content=$(echo "$tls_key_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
      tls_crt_content=$(echo "$tls_crt_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    fi
  else
    # Files don't exist - fail with error
    error "To create the template for the external_tls_cert for Vault, please provide the \"tls.crt\" (TLS certificate) and \"tls.key\" (private key) files in the directory \"${EXTERNAL_TLS_TEMPLATE_FOLDER}\"."\
" If you do not want to provide the real files, create empty files with these names and rerun. The template will be created with placeholders."
    exit 1
  fi
  
  cat << EOF > ${EXTERNAL_TLS_CERT_SECRET_FILE}
{
  "_comment": "Create $_vault_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_vault_secret_name @${EXTERNAL_TLS_CERT_SECRET_FILE}). The name should match the SecretProviderClass name (e.g. ${_vault_secret_name}). Optionally, this property, _comment, can be removed before creating the secret.",
  "tls.key": "$tls_key_content",
  "tls.crt": "$tls_crt_content"
}

EOF

cat << EOF > ${EXTERNAL_TLS_CERT_SECRET_PROVIDER_CLASS_FILE}.yaml
# YAML template for external TLS certificate SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_vault_secret_name), and match with shared_configuration.external_tls_certificate_secret
# The keys in this template should match with the keys in the $_vault_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_vault_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator,ibm-insights-engine-operator,ibm-dpe-operator,ibm-cp4a-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_vault_secret_name"
        objectName: "tls.key"
        secretKey: "tls.key"
      - secretPath: "$vault_path/$_vault_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
EOF

#Create SecretProviderClass for external TLS certificate when for separation of duties
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for external-tls-cert in $CP4BA_OPERATOR_NS namespace"
  cp "${EXTERNAL_TLS_CERT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${EXTERNAL_TLS_CERT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${EXTERNAL_TLS_CERT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi
success "Created external TLS certificate template and SecretProviderClass template for Vault\n"
}


# --------------------------
# trusted_certificate_list
# --------------------------
# This function will generate JSON and SecretProviderClass templates for trusted certificates
function create_trusted_cert_vault_template(){
  local _secret_name=${1}

  mkdir -p $TRUSTED_CERT_TEMPLATE_FOLDER >/dev/null 2>&1

  TRUSTED_CERT_SECRET_PROVIDER_CLASS_FILE=${TRUSTED_CERT_TEMPLATE_FOLDER}/${_secret_name}-secret-provider-class
  
  # Read certificate file from TRUSTED_CERT_FOLDER if it exists
  local tls_crt_content=""
  local cert_file="${TRUSTED_CERT_FOLDER}/${_secret_name}.crt"
  
  if [[ -f "$cert_file" ]]; then
    # Read the actual certificate file
    tls_crt_content=$(<"$cert_file")
    
    # Check if file is empty
    if [[ -z "$tls_crt_content" ]]; then
      # Use placeholder if file is empty
      tls_crt_content="<Content of trusted certificate in a single-line>"
    else
      # Remove carriage returns and convert multi-line certificate to single line with escaped newlines
      tls_crt_content=$(echo "$tls_crt_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    fi
  else
    # File doesn't exist - fail with error
    error "To create the template for the trusted certificate \"${_secret_name}\" for Vault, please provide the \"${_secret_name}.crt\" file in the directory \"${TRUSTED_CERT_FOLDER}\". "\
"If you do not want to provide the real file, create an empty file with this name and rerun. The template will be created with a placeholder."
    exit 1
  fi
  
  # Create JSON template for the trusted certificate
  cat << EOF > ${TRUSTED_CERT_TEMPLATE_FOLDER}/${_secret_name}.json
{
  "_comment": "Create $_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_secret_name @${TRUSTED_CERT_TEMPLATE_FOLDER}/${_secret_name}.json). The name should match the SecretProviderClass name (e.g. ${_secret_name}). Optionally, this property, _comment, can be removed before creating the secret.",
  "tls.crt": "$tls_crt_content"
}

EOF

  # Create SecretProviderClass template (without .yaml extension - user must rename to enable)
  cat << EOF > ${TRUSTED_CERT_SECRET_PROVIDER_CLASS_FILE}.yaml
# YAML template for trusted certificate SecretProviderClass: ${_secret_name}
# metadata.name must match with the name of the secret created in Vault (eg: ${_secret_name})
# The keys in this template should match with the keys in the ${_secret_name}.json template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "${_secret_name}"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator,ibm-odm-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/${_secret_name}"
        objectName: "tls.crt"
        secretKey: "tls.crt"
EOF

  # Create SecretProviderClass for separation of duties if needed
  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for ${_secret_name} in $CP4BA_OPERATOR_NS namespace"
    cp "${TRUSTED_CERT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${TRUSTED_CERT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    # Replace the namespace in the copied file
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${TRUSTED_CERT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi
  
  success "Created trusted certificate template and SecretProviderClass template for: ${_secret_name}"

}

# ---------------------------------------------------
# Wrapper function to handle shared secrets for Vault
# ---------------------------------------------------
function create_shared_secrets_vault_templates(){
    # Generate root CA secret template if user has customized it
    if [[ $vault_enabled == 'true' ]]; then
        root_ca_secret="$(prop_user_profile_property_file CP4BA.ROOT_CA_SECRET 2>/dev/null || echo '')"
        if [[ -n "$root_ca_secret" && "$root_ca_secret" != "<Optional>" ]]; then
            FLAG_ROOT_CA_SECRET=true
            wait_msg "Creating root CA secret JSON template and SecretProviderClass template for Vault"
            create_root_ca_vault_template "$root_ca_secret"
        fi
        
        # Generate external TLS certificate secret template if user has customized it
        external_tls_cert_secret="$(prop_user_profile_property_file CP4BA.EXTERNAL_TLS_CERTIFICATE_SECRET 2>/dev/null || echo '')"
        if [[ -n "$external_tls_cert_secret" && "$external_tls_cert_secret" != "<Optional>" ]]; then
            FLAG_EXTERNAL_CA_SECRET=true
            wait_msg "Creating external TLS certificate secret JSON template and SecretProviderClass template for Vault"
            create_external_tls_cert_vault_template "$external_tls_cert_secret"
        fi
        
        # Generate trusted certificate templates if user has specified them
        trusted_cert_list="$(prop_user_profile_property_file CP4BA.TRUSTED_CERTIFICATE_LIST 2>/dev/null || echo '')"
        if [[ -n "$trusted_cert_list" && "$trusted_cert_list" != "<Optional>" ]]; then
            FLAG_TRUSTED_CERT_SECRET=true
            wait_msg "Creating trusted certificate templates and SecretProviderClass templates for Vault"
            # Remove any spaces and split by comma
            trusted_cert_list=$(echo "$trusted_cert_list" | tr -d ' ')
            IFS=',' read -ra cert_array <<< "$trusted_cert_list"
            
            for cert_name in "${cert_array[@]}"; do
                if [[ -n "$cert_name" ]]; then
                    # Convert to lowercase for vault path
                    cert_name_lower=$(echo "$cert_name" | tr '[:upper:]' '[:lower:]')
                    info "Creating template for trusted certificate: $cert_name"
                    create_trusted_cert_vault_template "$cert_name"
                fi
            done
        fi
    fi
}



# ======================================
# LDAP secrets 
# ======================================

# --------------------------
# ldap-bind-secret
# --------------------------
function create_ldap_secret_vault_template(){
  wait_msg "Creating ldap-bind-secret secret JSON template for Vault"
  mkdir -p $VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _ldap_bind_dn=${1}
  local _ldap_password=${2}

cat << EOF > "${VAULT_LDAP_SECRET_FILE}"
{
  "_comment": "Create a ldap-bind-secret for Vault (eg: vault kv put ${kv_vault_path}/ldap-bind-secret @${VAULT_LDAP_SECRET_FILE}).  The name should be ldap-bind-secret and it must match with the name of the ldap-bind-secret-provider-class.yaml. Optionally, this property, _comment, can be removed before creating the secret.",
  "ldapUsername": "${_ldap_bind_dn}",
  "ldapPassword": "${_ldap_password}"
}
EOF

cat << EOF > "${VAULT_LDAP_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for ldap-bind-secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: ldap-bind-secret)
# The keys in this template should match with the keys in the ldap-bind-secret JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: ldap-bind-secret             
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    name: ldap-bind-secret
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator,ibm-odm-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault                           
  parameters:                               
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/ldap-bind-secret"
        objectName: "ldapUsername"
        secretKey: "ldapUsername"
      - secretPath: "$vault_path/ldap-bind-secret"
        objectName: "ldapPassword"
        secretKey: "ldapPassword"
EOF

#Create SecretProviderClass for ldap-bind-secret for separation of duties deployment
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for ldap-bind-secret in namespace $CP4BA_OPERATOR_NS"
  cp "${VAULT_LDAP_SECRET_PROVIDER_CLASS_FILE}.yaml" "${VAULT_LDAP_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${VAULT_LDAP_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi

  success "Created ldap-bind-secret secret JSON template and SecretProviderClass template for Vault\n"
}

# --------------------------
# ldap-bind-secret-tls
# --------------------------
#This function read the content of propertyfile/ldap/ldap-cert.crt and generate the Json and the SecretProviderClass
function create_ldap_tls_secret_vault_template(){
  wait_msg "Creating ldap-bind-secret-tls secret JSON template for Vault"
  mkdir -p $VAULT_LDAP_SECRET_TLS_FOLDER >/dev/null 2>&1  
  local _ldap_secret_name=$1
  local _ldap_secret_folder=$2
   
  _ldap_tls_content=$(<${_ldap_secret_folder}/ldap-cert.crt)
  # Remove carriage returns and convert multi-line certificate to single line with \n escape sequences
  _ldap_tls_content=$(echo "$_ldap_tls_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  
cat << EOF > "${VAULT_LDAP_SECRET_TLS_FILE}"
{
  "_comment": "Create a $_ldap_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_ldap_secret_name @${VAULT_LDAP_SECRET_TLS_FILE}).  The name should match with the LDAP_SSL_SECRET_NAME property in cp4ba_LDAP.property file. Optionally, this property, _comment, can be removed before creating the secret.",
  "tls.crt": "${_ldap_tls_content}"
}
EOF

cat << EOF > "${VAULT_LDAP_SECRET_TLS_PROVIDER_CLASS_FILE}.yaml"
# YAML template for ldap-bind-tls-secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_ldap_secret_name)
# The keys in this template should match with the keys in the $_ldap_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_ldap_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator,ibm-odm-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_ldap_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
EOF

#Create SecretProviderClass for LDAP TLS certificate for separation of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for LDAP TLS certificate in namespace $CP4BA_OPERATOR_NS"
  cp "${VAULT_LDAP_SECRET_TLS_PROVIDER_CLASS_FILE}.yaml" "${VAULT_LDAP_SECRET_TLS_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${VAULT_LDAP_SECRET_TLS_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi

  success "Created $_ldap_secret_name secret JSON template and SecretProviderClass template for Vault\n"
}


# --------------------------
# ibm-fncm-secret
# --------------------------
#DBACLD-185209: Vault's implementation.  Define ibm-fncm-secret for Vault
function create_fncm_secret_vault_template(){

  mkdir -p $FNCM_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _tmp_gcd_db_servername=${1}
  local _fncm_secret_name="ibm-fncm-secret"

  # Build conditional sections for OS databases
  local os_sections=""
  local os_secretprovider_sections=""
  
  # Get content OS number from property file
  local content_os_number
  content_os_number=$(prop_tmp_property_file CONTENT_OS_NUMBER)
  
  # Call helper function and capture output
  local os_result
  os_result=$(add_content_os_dynamically "true" "$content_os_number" "$vault_path" "$_fncm_secret_name")
  
  # Parse the output using awk to extract sections properly
  os_sections=$(echo "$os_result" | awk '/###OS_SECTIONS_START###/{flag=1;next}/###OS_SECTIONS_END###/{flag=0}flag')
  os_secretprovider_sections=$(echo "$os_result" | awk '/###OS_SECRETPROVIDER_SECTIONS_START###/{flag=1;next}/###OS_SECRETPROVIDER_SECTIONS_END###/{flag=0}flag')
  
  # Debug: show what was parsed
  # echo "DEBUG - Parsed os_sections: '$os_sections'"
  # echo "DEBUG - Parsed os_secretprovider_sections: '$os_secretprovider_sections'"

  # Get main GCD database info
  tmp_gcd_db_servername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
  tmp_gcd_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_gcd_db_servername")
  
  # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER for GCD
  local gcd_postgresql_client_flag=""
  if [[ $DB_TYPE = "postgresql" ]]; then
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_gcd_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
    gcd_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
  fi
  
  if [[ $DB_TYPE = "postgresql-edb" ]]; then
    gcd_postgresql_client_flag="true"
  fi
  
  # Get GCD credentials
  tmp_appuser="$(prop_user_profile_property_file CONTENT.APPLOGIN_USER)"
  tmp_apppwd="$(decode_base64_password "$(prop_user_profile_property_file CONTENT.APPLOGIN_PASSWORD)")"
  tmp_ltpapwd="$(decode_base64_password "$(prop_user_profile_property_file CONTENT.LTPA_PASSWORD)")"
  tmp_kestorepwd="$(decode_base64_password "$(prop_user_profile_property_file CONTENT.KEYSTORE_PASSWORD)")"
  tmp_gcd_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
  tmp_gcd_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)")"

  # Build GCD password section for JSON
  local gcd_password_section=""
  if [[ (! ("$gcd_postgresql_client_flag" == "true" || "$gcd_postgresql_client_flag" == "yes" || "$gcd_postgresql_client_flag" == "y")) || $DB_TYPE == "postgresql-edb" ]]; then
    gcd_password_section=",
  \"gcdDBPassword\": \"$tmp_gcd_dbuserpwd\""
  fi

  # Build GCD password section for SecretProviderClass
  local gcd_secretprovider_section=""
  if [[ (! ("$gcd_postgresql_client_flag" == "true" || "$gcd_postgresql_client_flag" == "yes" || "$gcd_postgresql_client_flag" == "y")) || $DB_TYPE == "postgresql-edb" ]]; then
    gcd_secretprovider_section="
      - secretPath: \"$vault_path/$_fncm_secret_name\"
        objectName: \"gcdDBPassword\"
        secretKey: \"gcdDBPassword\""
  fi

  # Create JSON template using pre-built strings
  cat << EOF > "${FNCM_VAULT_SECRET_FILE}"
{
  "_comment": "Create a $_fncm_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_fncm_secret_name @${FNCM_VAULT_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  "appLoginUsername": "$tmp_appuser",
  "appLoginPassword": "$tmp_apppwd",
  "gcdDBUsername": "$tmp_gcd_dbuser"${gcd_password_section}${os_sections},
  "ltpaPassword": "$tmp_ltpapwd",
  "keystorePassword": "$tmp_kestorepwd"
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"

# YAML template for ibm-fncm-secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_fncm_secret_name)
# The keys in this template should match with the keys in the $_fncm_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_fncm_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    gcd-db-server: $_tmp_gcd_db_servername
    db-name: ibm-fncm-secret
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_fncm_secret_name"
        objectName: "appLoginUsername"
        secretKey: "appLoginUsername"
      - secretPath: "$vault_path/$_fncm_secret_name"
        objectName: "appLoginPassword"
        secretKey: "appLoginPassword"
      - secretPath: "$vault_path/$_fncm_secret_name"
        objectName: "gcdDBUsername"
        secretKey: "gcdDBUsername"${gcd_secretprovider_section}${os_secretprovider_sections}
      - secretPath: "$vault_path/$_fncm_secret_name"
        objectName: "ltpaPassword"
        secretKey: "ltpaPassword"
      - secretPath: "$vault_path/$_fncm_secret_name"
        objectName: "keystorePassword"
        secretKey: "keystorePassword"
EOF

    # ----------------------------
    # add "aeos" to fncm secret
    # ----------------------------
    if [[ "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        # Use helper func to set var "aeos_postgresql_client_flag"
        get_postgresql_client_flag "AEOS_DB_USER_NAME" "aeos_postgresql_client_flag" "false"

        tmp_dbuser="$(prop_db_name_user_property_file AEOS_DB_USER_NAME)"
        # Add "aeosDBUsername" to JSON template
        ${YQ_CMD} -i ".aeosDBUsername = \"$tmp_dbuser\"" "${FNCM_VAULT_SECRET_FILE}"
        # Add "aeosDBUsername" object to SecretProviderClass YAML template
        append_to_secretprovider_objects "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_fncm_secret_name" "aeosDBUsername" "aeosDBUsername"

        # Add aeos password
        # when POSTGRESQL_SSL_CLIENT_SERVER is not true, add the pwd. For EDB, we will add pwd even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs pwd to connect.
        if [[ ! ($aeos_postgresql_client_flag == "true" || $aeos_postgresql_client_flag == "yes" || $aeos_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
            tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file AEOS_DB_USER_PASSWORD)")"
            ${YQ_CMD} -i ".aeosDBPassword = \"$tmp_dbuserpwd\"" "${FNCM_VAULT_SECRET_FILE}"

            # Add "aeosDBPassword" object to SecretProviderClass YAML template
            append_to_secretprovider_objects "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_fncm_secret_name" "aeosDBPassword" "aeosDBPassword"
        fi     
    fi  # End handing of "aeos"


    # ----------------------------
    # add "devos" to fncm secret
    # ----------------------------
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        # Use helper func to set var "devos_postgresql_client_flag"
        get_postgresql_client_flag "DEVOS_DB_USER_NAME" "devos_postgresql_client_flag" "false"

        tmp_dbuser="$(prop_db_name_user_property_file DEVOS_DB_USER_NAME)"
        # Add "devos1DBUsername" to JSON template
        ${YQ_CMD} -i ".devos1DBUsername = \"$tmp_dbuser\"" "${FNCM_VAULT_SECRET_FILE}"
        # Add "devos1DBUsername" object to SecretProviderClass YAML template
        append_to_secretprovider_objects "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_fncm_secret_name" "devos1DBUsername" "devos1DBUsername"

        # Add devos1DBPassword password
        # when POSTGRESQL_SSL_CLIENT_SERVER is not true, add the pwd. For EDB, we will add pwd even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs pwd to connect.
        if [[ ! ($devos_postgresql_client_flag == "true" || $devos_postgresql_client_flag == "yes" || $devos_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
            tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file DEVOS_DB_USER_PASSWORD)")"
            ${YQ_CMD} -i ".devos1DBPassword = \"$tmp_dbuserpwd\"" "${FNCM_VAULT_SECRET_FILE}"

            # Add "devos1DBPassword" object to SecretProviderClass YAML template
            append_to_secretprovider_objects "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_fncm_secret_name" "devos1DBPassword" "devos1DBPassword"
        fi  
    fi 

    # ----------------------------
    # add BAW authoring/runtime object stores to fncm secret
    # ----------------------------
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workflow-runtime" ]]; then
        for i in "${!BAW_AUTH_OS_ARR[@]}"; do
            # Use helper func to set var for this OS's postgresql_client_flag
            local os_name="${BAW_AUTH_OS_ARR[i]}"
            local os_postgresql_client_flag_var="${os_name}_postgresql_client_flag"
            get_postgresql_client_flag "${os_name}_DB_USER_NAME" "$os_postgresql_client_flag_var" "false"
            
            # Get the value of the flag variable
            eval local os_postgresql_client_flag=\$$os_postgresql_client_flag_var
            
            tmp_dbuser="$(prop_db_name_user_property_file ${os_name}_DB_USER_NAME)"
            tmp_val=$(echo "${os_name}" | tr '[:upper:]' '[:lower:]')
            
            # Add username to JSON template
            ${YQ_CMD} -i ".${tmp_val}DBUsername = \"$tmp_dbuser\"" "${FNCM_VAULT_SECRET_FILE}"
            # Add username object to SecretProviderClass YAML template
            append_to_secretprovider_objects "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_fncm_secret_name" "${tmp_val}DBUsername" "${tmp_val}DBUsername"
            
            # Add password if not using PostgreSQL SSL client auth (or if using EDB)
            if [[ ! ($os_postgresql_client_flag == "true" || $os_postgresql_client_flag == "yes" || $os_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
                tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file ${os_name}_DB_USER_PASSWORD)")"
                ${YQ_CMD} -i ".${tmp_val}DBPassword = \"$tmp_dbuserpwd\"" "${FNCM_VAULT_SECRET_FILE}"
                
                # Add password object to SecretProviderClass YAML template
                append_to_secretprovider_objects "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_fncm_secret_name" "${tmp_val}DBPassword" "${tmp_val}DBPassword"
            fi
        done
    fi

    # ----------------------------
    # add AWSDOCS (AWS documents) to fncm secret
    # ----------------------------
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" || " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
        # Use helper func to set var "awsdocs_postgresql_client_flag"
        get_postgresql_client_flag "AWSDOCS_DB_USER_NAME" "awsdocs_postgresql_client_flag" "false"
        
        tmp_dbuser="$(prop_db_name_user_property_file AWSDOCS_DB_USER_NAME)"
        # Add "awsdocsDBUsername" to JSON template
        ${YQ_CMD} -i ".awsdocsDBUsername = \"$tmp_dbuser\"" "${FNCM_VAULT_SECRET_FILE}"
        # Add "awsdocsDBUsername" object to SecretProviderClass YAML template
        append_to_secretprovider_objects "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_fncm_secret_name" "awsdocsDBUsername" "awsdocsDBUsername"
        
        # Add awsdocs password
        # when POSTGRESQL_SSL_CLIENT_SERVER is not true, add the pwd. For EDB, we will add pwd even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs pwd to connect.
        if [[ ! ($awsdocs_postgresql_client_flag == "true" || $awsdocs_postgresql_client_flag == "yes" || $awsdocs_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
            tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file AWSDOCS_DB_USER_PASSWORD)")"
            ${YQ_CMD} -i ".awsdocsDBPassword = \"$tmp_dbuserpwd\"" "${FNCM_VAULT_SECRET_FILE}"
            
            # Add "awsdocsDBPassword" object to SecretProviderClass YAML template
            append_to_secretprovider_objects "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_fncm_secret_name" "awsdocsDBPassword" "awsdocsDBPassword"
        fi
    fi

    # ----------------------------
    # add CHOS (Case History) to fncm secret
    # ----------------------------
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
        # Check if CHOS is configured (not commented out)
        tmp_chos_db_servername="$(prop_db_name_user_property_file_for_server_name CHOS_DB_USER_NAME)"
        tmp_chos_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_chos_db_servername")
        
        if [[ $tmp_chos_db_servername != \#* ]] ; then
            # Use helper func to set var "chos_postgresql_client_flag"
            get_postgresql_client_flag "CHOS_DB_USER_NAME" "chos_postgresql_client_flag" "false"
            
            tmp_dbuser="$(prop_db_name_user_property_file CHOS_DB_USER_NAME)"
            # Add "chDBUsername" to JSON template
            ${YQ_CMD} -i ".chDBUsername = \"$tmp_dbuser\"" "${FNCM_VAULT_SECRET_FILE}"
            # Add "chDBUsername" object to SecretProviderClass YAML template
            append_to_secretprovider_objects "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_fncm_secret_name" "chDBUsername" "chDBUsername"
            
            # Add chos password
            # when POSTGRESQL_SSL_CLIENT_SERVER is not true, add the pwd. For EDB, we will add pwd even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs pwd to connect.
            if [[ ! ($chos_postgresql_client_flag == "true" || $chos_postgresql_client_flag == "yes" || $chos_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
                tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file CHOS_DB_USER_PASSWORD)")"
                ${YQ_CMD} -i ".chDBPassword = \"$tmp_dbuserpwd\"" "${FNCM_VAULT_SECRET_FILE}"
                
                # Add "chDBPassword" object to SecretProviderClass YAML template
                append_to_secretprovider_objects "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_fncm_secret_name" "chDBPassword" "chDBPassword"
            fi
        fi
    fi





    #Create SecretProviderClass for DB SSL certificate for separation of duty
    if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
        info "Creating SecretProviderClass for DB SSL certificate in namespace $CP4BA_OPERATOR_NS"
        cp "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
        #replace the namespace in the copied file
        ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    fi

    success "Created $_fncm_secret_name secret JSON template and SecretProviderClass template for Vault\n"
}

# --------------------------
# DB SSL
# --------------------------
#DBACLD-185209: Vault's implementation for DB SSL
function create_cp4a_db_ssl_vault_template(){
  wait_msg "Creating database SSL certificate JSON template for Vault"
  local _dbserver=${1}
  local _tmp_ssl_secret_name=${2}
  local _tmp_cert_folder_name=${3}
  local _tmp_ssl_client_server=${4}
  local _tmp_pg_ssl_mode=${5}

  mkdir -p $DB_VAULT_SECRET_FILE_FOLDER/$_dbserver >/dev/null 2>&1
  local DB_VAULT_SECRET_FILE=${DB_VAULT_SECRET_FILE_FOLDER}/$_dbserver/ibm-cp4ba-db-ssl-cert-secret-for-${_dbserver}.json
  local DB_VAULT_SECRET_PROVIDER_CLASS_FILE=${DB_VAULT_SECRET_FILE_FOLDER}/$_dbserver/ibm-cp4ba-db-ssl-cert-secret-for-${_dbserver}-provider-class

  # Build JSON content based on database type and SSL configuration
  local json_content=""
  local provider_objects=""

  if [[ $DB_TYPE != "postgresql" ]]; then
    # For DB2, Oracle, SQL Server - use tls.crt and cacert.crt
    local tls_cert_content=$(<${_tmp_cert_folder_name}/db-cert.crt)
    local cacert_content=$(<${_tmp_cert_folder_name}/db-cert.crt)
    
    # Remove carriage returns and convert multi-line certificates to single line with escaped newlines
    tls_cert_content=$(echo "$tls_cert_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    cacert_content=$(echo "$cacert_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

    json_content='"tls.crt": "'$tls_cert_content'",
  "cacert.crt": "'$cacert_content'"'
    
    provider_objects='      - secretPath: "'$vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "tls.crt"
        secretKey: "tls.crt"
      - secretPath: "'$vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "cacert.crt"
        secretKey: "cacert.crt"'

  # Postgres with no client_server
  elif [[ $DB_TYPE == "postgresql" && ($_tmp_ssl_client_server == "no" || $_tmp_ssl_client_server == "false" || $_tmp_ssl_client_server == "" || -z $_tmp_ssl_client_server) ]]; then
    # For PostgreSQL with SSL but no client authentication - use tls.crt and serverca.pem
    local tls_cert_content=$(<${_tmp_cert_folder_name}/db-cert.crt)
    local serverca_content=$(<${_tmp_cert_folder_name}/db-cert.crt)
    
    # Remove carriage returns and convert multi-line certificates to single line with escaped newlines
    tls_cert_content=$(echo "$tls_cert_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    serverca_content=$(echo "$serverca_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

    json_content='"tls.crt": "'$tls_cert_content'",
  "serverca.pem": "'$serverca_content'"'
    
    provider_objects='      - secretPath: "'$vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "tls.crt"
        secretKey: "tls.crt"
      - secretPath: "'$vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "serverca.pem"
        secretKey: "serverca.pem"'
  
  else # Postgres with client server
    # For PostgreSQL with SSL client authentication - use tls.crt, ca.crt, tls.key, and sslmode
    local tls_cert_content=$(<${_tmp_cert_folder_name}/client.crt)
    local ca_cert_content=$(<${_tmp_cert_folder_name}/root.crt)
    local tls_key_content=$(<${_tmp_cert_folder_name}/client.key)
    
    # Remove carriage returns and convert multi-line certificates to single line with escaped newlines
    tls_cert_content=$(echo "$tls_cert_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    ca_cert_content=$(echo "$ca_cert_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    tls_key_content=$(echo "$tls_key_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    # Use provided SSL mode or default to verify-full
    local ssl_mode=${_tmp_pg_ssl_mode:-"verify-full"}
    
    json_content='"tls.crt": "'$tls_cert_content'",
  "ca.crt": "'$ca_cert_content'",
  "tls.key": "'$tls_key_content'",
  "sslmode": "'$ssl_mode'"'
    
    provider_objects='      - secretPath: "'$vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "tls.crt"
        secretKey: "tls.crt"
      - secretPath: "'$vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "ca.crt"
        secretKey: "ca.crt"
      - secretPath: "'$vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "tls.key"
        secretKey: "tls.key"
      - secretPath: "'$vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "sslmode"
        secretKey: "sslmode"'
  fi

  # Create JSON template
  cat << EOF > ${DB_VAULT_SECRET_FILE}
{
  "_comment": "Create a $_tmp_ssl_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_tmp_ssl_secret_name @${DB_VAULT_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  $json_content
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${DB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_tmp_ssl_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_tmp_ssl_secret_name)
# The keys in this template should match with the keys in the $_tmp_ssl_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_tmp_ssl_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator,ibm-dpe-operator,ibm-odm-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
$provider_objects
EOF

#Create SecretProviderClass for DB SSL certificate for separation of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for DB SSL certificate in namespace $CP4BA_OPERATOR_NS"
  cp "${DB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${DB_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${DB_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi

  success "Created $_tmp_ssl_secret_name SSL certificate JSON template for Vault\n"

}


#DBACLD-185209: Vault's implementation for ibm-icc-secret
function create_fncm_icc_secret_vault_template(){

  mkdir -p $FNCM_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _archive_id=${1}
  local _archive_pwd=${2}
  local _fncm_icc_secret_name="ibm-icc-secret"

  # Create JSON template
  cat << EOF > ${FNCM_ICC_VAULT_SECRET_FILE}
{
  "_comment": "Create a $_fncm_icc_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_fncm_icc_secret_name @${FNCM_ICC_VAULT_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  "archiveUserId": "$_archive_id",
  "archivePassword": "$_archive_pwd"
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${FNCM_ICC_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_fncm_icc_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_fncm_icc_secret_name)
# The keys in this template should match with the keys in the $_fncm_icc_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_fncm_icc_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-content-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_fncm_icc_secret_name"
        objectName: "archiveUserId"
        secretKey: "archiveUserId"
      - secretPath: "$vault_path/$_fncm_icc_secret_name"
        objectName: "archivePassword"
        secretKey: "archivePassword"
EOF

#Create SecretProviderClass for FNCM ICC secret for separtion of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for FNCM ICC secret in namespace $CP4BA_OPERATOR_NS"
  cp "${FNCM_ICC_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${FNCM_ICC_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${FNCM_ICC_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi
  success "Created $_fncm_icc_secret_name JSON template and SecretProviderClass template for Vault\n"
}

# --------------------------
# ibm-iccsap-secret
# --------------------------
#DBACLD-185209: Vault's implementation for ibm-iccsap-secret
function create_fncm_iccsap_secret_vault_template(){

  mkdir -p $FNCM_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _keystore_password=${1:-"<KEYSTORE_PASSWORD>"}
  local _fncm_iccsap_secret_name="ibm-iccsap-secret"

  # Create JSON template
  cat << EOF > ${FNCM_ICCSAP_VAULT_SECRET_FILE}
{
  "_comment": "Create a $_fncm_iccsap_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_fncm_iccsap_secret_name @${FNCM_ICCSAP_VAULT_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  "keystorePassword": "$_keystore_password"
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${FNCM_ICCSAP_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_fncm_iccsap_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_fncm_iccsap_secret_name)
# The keys in this template should match with the keys in the $_fncm_iccsap_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_fncm_iccsap_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-content-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_fncm_iccsap_secret_name"
        objectName: "keystorePassword"
        secretKey: "keystorePassword"
      - secretPath: "$vault_path/$_fncm_iccsap_secret_name"
        objectName: "ICCSAP_KEYSTORE_PASSWORD"
        secretKey: "keystorePassword"
      - secretPath: "$vault_path/$_fncm_iccsap_secret_name"
        objectName: "ICCSAP_TRUSTSTORE_PASSWORD"
        secretKey: "keystorePassword"
EOF
# NOTE for above: the 3 different objectName mappings ("keystorePassword", "ICCSAP_KEYSTORE_PASSWORD", "ICCSAP_TRUSTSTORE_PASSWORD") 
# for the same secretKey "keystorePassword" is intentional because ICCSAP needs it at all 3 locations

#Create SecretProviderClass for FNCM ICCSAP secret for separation of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for FNCM ICCSAP secret in namespace $CP4BA_OPERATOR_NS"
  cp "${FNCM_ICCSAP_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${FNCM_ICCSAP_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${FNCM_ICCSAP_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi
  success "Created $_fncm_iccsap_secret_name JSON template and SecretProviderClass template for Vault\n"
}

# --------------------------
# ibm-ier-secret
# --------------------------
#DBACLD-185209: Vault's implementation for ibm-ier-secret
function create_fncm_ier_secret_vault_template(){

  mkdir -p $FNCM_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _keystore_password=${1:-"<KEYSTORE_PASSWORD>"}
  local _fncm_ier_secret_name="ibm-ier-secret"

  # Create JSON template
  cat << EOF > ${FNCM_IER_VAULT_SECRET_FILE}
{
  "_comment": "Create a $_fncm_ier_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_fncm_ier_secret_name @${FNCM_IER_VAULT_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  "keystorePassword": "$_keystore_password"
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${FNCM_IER_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_fncm_ier_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_fncm_ier_secret_name)
# The keys in this template should match with the keys in the $_fncm_ier_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_fncm_ier_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-content-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_fncm_ier_secret_name"
        objectName: "keystorePassword"
        secretKey: "keystorePassword"
EOF
#Create SecretProviderClass for FNCM IER secret for separation of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for FNCM IER secret in namespace $CP4BA_OPERATOR_NS"
  cp "${FNCM_IER_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${FNCM_IER_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${FNCM_IER_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi
  success "Created $_fncm_ier_secret_name JSON template and SecretProviderClass template for Vault\n"
}


# --------------------------
# aca-basedb
# --------------------------

# Function to create base templates for "aca-basedb" secret (additional fields may be added later)
function create_aca_db_secret_vault_base_template(){
  local _basedb_secret_name="aca-basedb"
  local _dbserver=${1:-"ADP_DB_SERVER>"}
  local _base_db_user=${2:-"<ADP_BASE_DB_USER_NAME>"}
  local _dbname=${3:-"<ADP_BASE_DB_NAME>"}
  
  wait_msg "Creating $_basedb_secret_name JSON template and SecretProviderClass template for Vault"
  mkdir -p $ADP_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

  # Create JSON template for the secret
  cat << EOF > ${ADP_BASEDB_VAULT_SECRET_FILE}
{
  "_comment": "Create $_basedb_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_basedb_secret_name @${ADP_BASEDB_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name (e.g. ${_basedb_secret_name}). Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "BASE_DB_USER": "$_base_db_user"
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_basedb_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_basedb_secret_name)
# The keys in this template should match with the keys in the $_basedb_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_basedb_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    base-db-server: $_dbserver
    base-db-name: $_dbname
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator,ibm-dpe-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_basedb_secret_name"
        objectName: "BASE_DB_USER"
        secretKey: "BASE_DB_USER"
EOF

}

function create_aca_db_secret_vault_template(){
    tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ADP_BASE_DB_NAME)"
    check_dbserver_name_valid $tmp_dbservername "ADP_BASE_DB_NAME"

    wait_msg "Creating DPE DB secret YAML template"
    
    #  Add basedb user
    local tmp_basedbuser="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
    tmp_basedbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_basedbuser")

    # Function to create starting point templates for "aca-basedb" secret (additional fields will be added later in this function)
    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
    create_aca_db_secret_vault_base_template ${tmp_dbservername} ${tmp_basedbuser} ${tmp_dbname}

    # Process the list of project DBs
    local db_name_array=()
    local db_user_array=()
    local db_userpwd_array=()
    local db_server_array=()

    local tmp_dbname=$(prop_db_name_user_property_file ADP_PROJECT_DB_NAME)
    local tmp_dbuser=$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_NAME)
    local tmp_dbuserpwd=$(decode_base64_password "$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_PASSWORD)")
    local tmp_dbservername_list=$(prop_db_name_user_property_file ADP_PROJECT_DB_SERVER)
    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
    tmp_dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuser")
    tmp_dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuserpwd")
    tmp_dbservername_list=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername_list")

    OIFS=$IFS
    IFS=',' read -ra db_name_array <<< "$tmp_dbname"
    IFS=',' read -ra db_user_array <<< "$tmp_dbuser"
    IFS=',' read -ra db_userpwd_array <<< "$tmp_dbuserpwd"
    IFS=',' read -ra db_server_array <<< "$tmp_dbservername_list"
    IFS=$OIFS

    # Determine postgres client-auth flag for the ADP DB server (used to decide whether to add per-project DB passwords)
    local tmp_postgresql_client_flag="false"
    if [[ "$DB_TYPE" == "postgresql" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
        tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    fi

    # DBACLD-203570 If Postgres client-auth is not enabled, add BASE_DB_CONFIG password field
    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
        # Add BASE_DB_CONFIG object to SecretProviderClass YAML template
        append_to_secretprovider_objects "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/aca-basedb" "BASE_DB_CONFIG" "BASE_DB_CONFIG"
        
        # Add BASE_DB_CONFIG field to Vault JSON template (for Vault, the pwd should be in plain-text)
        local tmp_basedbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file ADP_BASE_DB_USER_PASSWORD)")"
        tmp_basedbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_basedbuserpwd")
        ${YQ_CMD} -i ".BASE_DB_CONFIG = \"$tmp_basedbuserpwd\"" "${ADP_BASEDB_VAULT_SECRET_FILE}"
    fi

    if [[ $DB_TYPE = "postgresql-edb" ]]; then
        tmp_postgresql_client_flag="true"
    fi

    # Validate array lengths - password array only checked if not using client auth
    if [[ (${#db_name_array[@]} != ${#db_user_array[@]}) || (${#db_name_array[@]} != ${#db_server_array[@]}) ]]; then
        fail "The number of values of: ADP_PROJECT_DB_NAME, ADP_PROJECT_DB_USER_NAME, ADP_PROJECT_DB_SERVER must all be equal. Exit ..."
    fi
    if ! is_pg_client_auth && [[ ${#db_name_array[@]} != ${#db_userpwd_array[@]} ]]; then
        fail "The number of values of: ADP_PROJECT_DB_USER_PASSWORD must match other arrays when not using client certificate authentication. Exit ..."
    fi
    
    if [[ ${#db_name_array[@]} -gt 0 ]]; then
        # Check if SSL is being used, if so, we need to add a line for path to certificate files
        # ADP only supports 1 database server, so only the first property in array will be used
        tmp_dbservername=${db_server_array[0]}
        local db_ssl_enable=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.DATABASE_SSL_ENABLE)")
        db_ssl_enable=$(echo "$db_ssl_enable"| tr '[:upper:]' '[:lower:]')

        if [[ "$db_ssl_enable" == "true" || "$db_ssl_enable" == "yes" || "$db_ssl_enable" == "y" ]]; then
            # if SSL, include line for CERT
            ssl_folder_path="$(prop_db_server_property_file ${db_server_array[0]}.DATABASE_SSL_CERT_FILE_FOLDER)"
            ssl_folder_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$ssl_folder_path")
            if [[ "$DB_TYPE" == "postgresql" ]]; then                  
                local tmp_postgresql_client_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
                tmp_postgresql_client_flag=$(echo "$tmp_postgresql_client_flag" | tr '[:upper:]' '[:lower:]') 
                if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
                    # Add CERT field to Vault JSON template (for Vault, the cert should be in plain-text and all on one line)
                    aca_db_cert_content=$(cat ${ssl_folder_path}/client.crt | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
                    ${YQ_CMD} -i ".CERT = \"$aca_db_cert_content\"" "${ADP_BASEDB_VAULT_SECRET_FILE}"
                    
                    # Add CERT object to SecretProviderClass YAML template
                    append_to_secretprovider_objects "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/aca-basedb" "CERT" "CERT"
                    
                    # Add KEY field to Vault JSON template (for Vault, the cert should be in plain-text and all on one line)
                    aca_db_key_content=$(cat ${ssl_folder_path}/client.key | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
                    ${YQ_CMD} -i ".KEY = \"$aca_db_key_content\"" "${ADP_BASEDB_VAULT_SECRET_FILE}"
                    
                    # Add KEY object to SecretProviderClass YAML template
                    append_to_secretprovider_objects "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/aca-basedb" "KEY" "KEY"
                    
                    # Add ROOTCERT field to Vault JSON template (for Vault, the cert should be in plain-text and all on one line)
                    aca_db_rootcert_content=$(cat ${ssl_folder_path}/root.crt | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
                    ${YQ_CMD} -i ".ROOTCERT = \"$aca_db_rootcert_content\"" "${ADP_BASEDB_VAULT_SECRET_FILE}"
                    
                    # Add ROOTCERT object to SecretProviderClass YAML template
                    append_to_secretprovider_objects "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/aca-basedb" "ROOTCERT" "ROOTCERT"
                else                    
                    # when POSTGRESQL_SSL_CLIENT_SERVER=false, only root cert is needed.  in this situation the scripts seem to expect "db-cert.crt" as the filename
                    # Add ROOTCERT field to Vault JSON template (for Vault, the cert should be in plain-text and all on one line)
                    aca_db_rootcert_content=$(cat ${ssl_folder_path}/db-cert.crt | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
                    ${YQ_CMD} -i ".ROOTCERT = \"$aca_db_rootcert_content\"" "${ADP_BASEDB_VAULT_SECRET_FILE}"

                    # Add ROOTCERT object to SecretProviderClass YAML template
                    append_to_secretprovider_objects "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/aca-basedb" "ROOTCERT" "ROOTCERT"
                fi
            else
                # Add CERT field to Vault JSON template (for Vault, the cert should be in plain-text and all on one line)
                aca_db_cert_content=$(cat ${ssl_folder_path}/db-cert.crt| tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
                ${YQ_CMD} -i ".CERT = \"$aca_db_cert_content\"" "${ADP_BASEDB_VAULT_SECRET_FILE}"

                # Add CERT object to SecretProviderClass YAML template
                append_to_secretprovider_objects "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/aca-basedb" "CERT" "CERT"
            fi
            
        fi
        for num in "${!db_name_array[@]}"; do
            tmp_dbname=${db_name_array[num]}
            tmp_dbname=$(echo "$tmp_dbname" | tr '[:lower:]' '[:upper:]')
            tmp_dbuser=${db_user_array[num]}
            tmp_dbuserpwd=${db_userpwd_array[num]}
            # If Postgres client-auth is enabled for the ADP DB server, DO NOT add per-project DB password fields.
            # Other DB types will still add the PROJ_DB_CONFIG passwords. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
                # Add per-project DB password field to Vault JSON template
                ${YQ_CMD} -i ".\"${tmp_dbname}_DB_CONFIG\" = \"$tmp_dbuserpwd\"" "${ADP_BASEDB_VAULT_SECRET_FILE}"
                
                # Add per-project DB password object to SecretProviderClass YAML template
                append_to_secretprovider_objects "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/aca-basedb" "${tmp_dbname}_DB_CONFIG" "${tmp_dbname}_DB_CONFIG"
            fi
        done

    fi

    # Create SecretProviderClass for separation of duties if needed
    if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
        info "Creating SecretProviderClass for ${_basedb_secret_name} in $CP4BA_OPERATOR_NS namespace"
        cp "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
        ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${ADP_BASEDB_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    fi

    success "Created $_basedb_secret_name JSON template and SecretProviderClass template for Vault\n"
}


# --------------------------
# ibm-adp-secret
# --------------------------

# Function to create base templates for "ibm-adp-secret" secret (additional fields may be added later)
function create_adp_secret_vault_base_template(){
    _adp_secret_name="ibm-adp-secret"

    # Create JSON template for the secret
    cat << EOF > ${ADP_VAULT_SECRET_FILE}
{
  "_comment": "Create $_adp_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_adp_secret_name @${ADP_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name (e.g. ${_adp_secret_name}). Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "serviceUser": "$_service_user",
  "serviceUser_none_dn": "$_service_user_none_dn",
  "servicePwd": "$_service_pwd",
  "serviceUserBas": "$_service_user_bas",
  "serviceUserBas_none_dn": "$_service_user_bas_none_dn",
  "servicePwdBas": "$_service_pwd_bas",
  "serviceUserCa": "$_service_user_ca",
  "serviceUserCa_none_dn": "$_service_user_ca_none_dn",
  "servicePwdCa": "$_service_pwd_ca",
  "envOwnerUser": "$_env_owner_user",
  "envOwnerPwd": "$_env_owner_pwd",
  "gitgateway_keystorePwd": "$_gitgateway_keystore_pwd"
}
EOF

    # Create SecretProviderClass template
    cat << EOF > "${ADP_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_adp_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_adp_secret_name)
# The keys in this template should match with the keys in the $_adp_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_adp_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    db-server: $_adp_db_server
    db-name: ibm-adp-secret
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "serviceUser"
        secretKey: "serviceUser"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "serviceUser_none_dn"
        secretKey: "serviceUser_none_dn"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "servicePwd"
        secretKey: "servicePwd"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "serviceUserBas"
        secretKey: "serviceUserBas"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "serviceUserBas_none_dn"
        secretKey: "serviceUserBas_none_dn"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "servicePwdBas"
        secretKey: "servicePwdBas"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "serviceUserCa"
        secretKey: "serviceUserCa"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "serviceUserCa_none_dn"
        secretKey: "serviceUserCa_none_dn"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "servicePwdCa"
        secretKey: "servicePwdCa"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "envOwnerUser"
        secretKey: "envOwnerUser"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "envOwnerPwd"
        secretKey: "envOwnerPwd"
      - secretPath: "$vault_path/$_adp_secret_name"
        objectName: "gitgateway_keystorePwd"
        secretKey: "gitgateway_keystorePwd"
EOF

}


# Create templates for "ibm-adp-secret" secret
function create_adp_secret_vault_template(){

    local _adp_db_server=$1
    _adp_db_server=$(sed -e 's/^"//' -e 's/"$//' <<<"$_adp_db_server")
    
    _adp_secret_name="ibm-adp-secret"
    
    # Collect all parameters for Vault template
    _service_user="$(prop_user_profile_property_file ADP.SERVICE_USER_NAME)"
    _service_user_none_dn="$(echo "$_service_user" | awk -F',' '{print $1}' | awk -F'=' '{print $2}')"
    _service_pwd="$(decode_base64_password "$(prop_user_profile_property_file ADP.SERVICE_USER_PASSWORD)")"
    _service_user_bas="$(prop_user_profile_property_file ADP.SERVICE_USER_NAME_BASE)"
    _service_user_bas_none_dn="$(echo "$_service_user_bas" | awk -F',' '{print $1}' | awk -F'=' '{print $2}')"
    _service_pwd_bas="$(decode_base64_password "$(prop_user_profile_property_file ADP.SERVICE_USER_PASSWORD_BASE)")"
    _service_user_ca="$(prop_user_profile_property_file ADP.SERVICE_USER_NAME_CA)"
    _service_user_ca_none_dn="$(echo "$_service_user_ca" | awk -F',' '{print $1}' | awk -F'=' '{print $2}')"
    _service_pwd_ca="$(decode_base64_password "$(prop_user_profile_property_file ADP.SERVICE_USER_PASSWORD_CA)")"
    _env_owner_user="$(prop_user_profile_property_file ADP.ENV_OWNER_USER_NAME)"
    _env_owner_pwd="$(decode_base64_password "$(prop_user_profile_property_file ADP.ENV_OWNER_USER_PASSWORD)")"
    _gitgateway_keystore_pwd="$(LC_ALL=C tr -dc 'A-Za-z0-9_-' < /dev/urandom | head -c 16)"

    wait_msg "Creating $_adp_secret_name JSON template and SecretProviderClass template for Vault"
    mkdir -p $ADP_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
    
    # Call function to create the base templates (starting point), but we might need to add more to it later
    create_adp_secret_vault_base_template

    ### <https://jsw.ibm.com/browse/DBACLD-168161> - Added new section for ADP Gitgateway database user and pwd
    # Handle ADPGG credentials for document_processing_designer
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
        _adpgg_db_username="$(prop_db_name_user_property_file ADP_GG_DB_USER_NAME)"
        
        # Add "adpggDBUsername" to Vault JSON template and SecretProviderClass YAML
        ${YQ_CMD} -i ".adpggDBUsername = \"$_adpgg_db_username\"" "${ADP_VAULT_SECRET_FILE}"
        append_to_secretprovider_objects "${ADP_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_adp_secret_name" "adpggDBUsername" "adpggDBUsername"

        # Call helper function to determine the postgres client flag
        get_postgresql_client_flag "ADP_GG_DB_USER_NAME" "adpgg_postgresql_client_flag" "true"
 
        # When POSTGRESQL_SSL_CLIENT_SERVER is NOT true, add pwd to secret.
        # For EDB, we will add the pwd to secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs pwd to connect.
        if [[ ! ($adpgg_postgresql_client_flag == "true" || $adpgg_postgresql_client_flag == "yes" || $adpgg_postgresql_client_flag == "y") || $tmp_dbtype == "postgresql-edb" ]]; then
            _adpgg_db_password="$(decode_base64_password "$(prop_db_name_user_property_file ADP_GG_DB_USER_PASSWORD)")"
 
            # Add "adpggDBPassword" to Vault JSON template and SecretProviderClass YAML
            ${YQ_CMD} -i ".adpggDBPassword = \"$_adpgg_db_password\"" "${ADP_VAULT_SECRET_FILE}"
            append_to_secretprovider_objects "${ADP_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_adp_secret_name" "adpggDBPassword" "adpggDBPassword"
        fi
        
    fi

    # Create SecretProviderClass for separation of duties if needed
    if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
        info "Creating SecretProviderClass for ${_adp_secret_name} in $CP4BA_OPERATOR_NS namespace"
        cp "${ADP_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${ADP_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
        ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${ADP_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    fi
    
    success "Created $_adp_secret_name JSON template and SecretProviderClass template for Vault\n"
}


# --------------------------
# ibm-adp-git-connection-secret
# --------------------------
# Create templates for "ibm-adp-git-connection-secret" secret (TLS certificate)
function create_adp_git_connection_ssl_vault_template(){
    
    # Get secret name
    local _git_secret_name="$(prop_user_profile_property_file ADP.GIT_SSL_SECRET_NAME)"
    _git_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$_git_secret_name")
    if [[ -z $_git_secret_name || $_git_secret_name == "" ]]; then
        error "In property file '${USER_PROFILE_PROPERTY_FILE}', ADP.ENABLE_GIT_SSL_CONNECTION was set to true, but ADP.GIT_SSL_SECRET_NAME was not defined. Please set value of ADP.GIT_SSL_SECRET_NAME "
    fi

    wait_msg "Creating $_git_secret_name JSON template and SecretProviderClass template for Vault"
    mkdir -p $ADP_GIT_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

    git_cert_folder="$(prop_user_profile_property_file ADP.GIT_SSL_CERT_FILE_FOLDER)"
    git_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$git_cert_folder")
    if [[ -z $git_cert_folder || $git_cert_folder == "" ]]; then
        # If user doesn't define their own folder, use our default
        git_cert_folder=$ADP_GIT_SSL_CERT_FOLDER
    fi

    # Read certificate file from git_cert_folder if it exists
    local tls_crt_content=""
    local cert_file="${git_cert_folder}/git-cert.crt"
    
    if [[ -f "$cert_file" ]]; then
        tls_crt_content=$(<"$cert_file")
        
        if [[ -z "$tls_crt_content" ]]; then
            tls_crt_content="<Content of ADP Git TLS certificate in a single-line>"
        else
            tls_crt_content=$(echo "$tls_crt_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
        fi
    else
        error "To create the template for $_git_secret_name for Vault, please provide the \"git-cert.crt\" file in the directory \"${git_cert_folder}\". "\
    "If you do not want to provide the real file, create an empty file with this name and rerun. The template will be created with a placeholder."
        exit 1
    fi

    # Create JSON template
    cat << EOF > ${ADP_GIT_VAULT_SECRET_FILE}
{
  "_comment": "Create $_git_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_git_secret_name @${ADP_GIT_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name (e.g. ${_git_secret_name}). Optionally, this property, _comment, can be removed before creating the secret.",
  "tls.crt": "$tls_crt_content"
}
EOF

    # Create SecretProviderClass template
    cat << EOF > "${ADP_GIT_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_git_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_git_secret_name)
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_git_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_git_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
EOF

    if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
        info "Creating SecretProviderClass for ${_git_secret_name} in $CP4BA_OPERATOR_NS namespace"
        cp "${ADP_GIT_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${ADP_GIT_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
        ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${ADP_GIT_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    fi
    
    success "Created $_git_secret_name JSON template and SecretProviderClass template for Vault\n"
}


# --------------------------
# ibm-adp-cdra-ssl-secret
# --------------------------
# Create templates for "ibm-adp-cdra-ssl-secret" secret (TLS certificate)
function create_adp_cdra_ssl_vault_template(){
  
    # Get secret name for Vault
    _cdra_secret_name="$(prop_user_profile_property_file ADP.CDRA_SSL_SECRET_NAME)"
    _cdra_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$_cdra_secret_name")
    if [[ -z $_cdra_secret_name || $_cdra_secret_name == "" ]]; then
        error "In property file '${USER_PROFILE_PROPERTY_FILE}', ADP.CDRA_SSL_SECRET_NAME was not defined. Please set value of ADP.CDRA_SSL_SECRET_NAME "
    fi
                
    wait_msg "Creating $_cdra_secret_name JSON template and SecretProviderClass template for Vault"
    mkdir -p $ADP_CDRA_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
    
    cdra_cert_folder="$(prop_user_profile_property_file ADP.CDRA_SSL_CERT_FILE_FOLDER)"
    cdra_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$cdra_cert_folder")
    # If user doesn't define their own folder, use our default
    if [[ -z $cdra_cert_folder || $cdra_cert_folder == "" ]]; then
        cdra_cert_folder=$ADP_CDRA_CERT_FOLDER
    fi

    # Read certificate file from cdra_cert_folder
    local tls_crt_content=""
    local cert_file="${cdra_cert_folder}/cdra_tls_cert.crt"
    
    if [[ -f "$cert_file" ]]; then
        tls_crt_content=$(<"$cert_file")
        
        if [[ -z "$tls_crt_content" ]]; then
        tls_crt_content="<Content of ADP CDRA route TLS certificate in a single-line>"
        else
        tls_crt_content=$(echo "$tls_crt_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
        fi
    else
        error "To create the template for $_cdra_secret_name for Vault, please provide the \"cdra_tls_cert.crt\" file in the directory \"${cdra_cert_folder}\". "\
    "If you do not want to provide the real file, create an empty file with this name and rerun. The template will be created with a placeholder."
        exit 1
    fi

    # Create JSON template
    cat << EOF > ${ADP_CDRA_VAULT_SECRET_FILE}
{
  "_comment": "Create $_cdra_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_cdra_secret_name @${ADP_CDRA_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name (e.g. ${_cdra_secret_name}). Optionally, this property, _comment, can be removed before creating the secret.",
  "tls.crt": "$tls_crt_content"
}
EOF

    # Create SecretProviderClass template
    # Since this is be inserted into CR property “shared_configuration.trusted_certificate_list”, all operators which mount trusted_certificate_list will need access. 
    cat << EOF > "${ADP_CDRA_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_cdra_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_cdra_secret_name)
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_cdra_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,ibm-dpe-operator,icp4a-foundation-operator,ibm-odm-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_cdra_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
EOF

    if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
        info "Creating SecretProviderClass for ${_cdra_secret_name} in $CP4BA_OPERATOR_NS namespace"
        cp "${ADP_CDRA_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${ADP_CDRA_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
        ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${ADP_CDRA_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    fi
    
    success "Created $_cdra_secret_name JSON template and SecretProviderClass template for Vault\n"
}


# --------------------------
# ibm-adp-aca-design-api-key-secret
# --------------------------
# Create templates for "ibm-adp-aca-design-api-key-secret" secret
function create_aca_design_api_key_vault_template(){
  local _api_key_secret_name=${1:-ibm-adp-aca-design-api-key-secret}
  local _zen_api_key=${2:-"<cp4a-aca-design-api-user>:<cp4a-aca-design-zen-api-key>"}
  
  wait_msg "Creating $_api_key_secret_name JSON template and SecretProviderClass template for Vault"
  mkdir -p $ADP_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

  # Create JSON template
  cat << EOF > ${ADP_ACA_DESIGN_API_KEY_VAULT_SECRET_FILE}
{
  "_comment": "Create $_api_key_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_api_key_secret_name @${ADP_ACA_DESIGN_API_KEY_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name (e.g. ${_api_key_secret_name}). Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "ZenApiKey": "$_zen_api_key"
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${ADP_ACA_DESIGN_API_KEY_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_api_key_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_api_key_secret_name)
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_api_key_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-dpe-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_api_key_secret_name"
        objectName: "ZenApiKey"
        secretKey: "ZenApiKey"
EOF

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for ${_api_key_secret_name} in $CP4BA_OPERATOR_NS namespace"
    cp "${ADP_ACA_DESIGN_API_KEY_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${ADP_ACA_DESIGN_API_KEY_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${ADP_ACA_DESIGN_API_KEY_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi
  
  success "Created $_api_key_secret_name JSON template and SecretProviderClass template for Vault\n"
}


# --------------------------
# ibm-ban-secret
# --------------------------
#DBACLD-185209: Vault's implementation.  Define ibm-ban-secret for Vault
function create_ban_secret_vault_template() {
  wait_msg "Creating ibm-ban-secret JSON template for Vault"
  mkdir -p $BAN_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _app_login_user=${1}
  local _app_login_pwd=${2}
  local _icn_db_user=${3}
  local _icn_db_pwd=${4}
  local _jmail_user=${5}
  local _jmail_pwd=${6}
  local _ltpa_pwd=${7}
  local _keystore_pwd=${8}
  local _pg_client_flag=${9}
  local _db_server=${10}
  local _db_name=${11}
  local _ban_secret_name="ibm-ban-secret"

  # Build conditional sections as variables first
  # Only create this section when it's NOT EDB
  local icn_pwd_section=""
  if [[ (! ("$_pg_client_flag" == "true" || "$_pg_client_flag" == "yes" || "$_pg_client_flag" == "y")) || $DB_TYPE == "postgresql-edb" ]]; then
    icn_pwd_section=',
  "navigatorDBPassword": "'$_icn_db_pwd'"'
  fi
  
  # Only create this section when jmail user and jmail password are not <Optional>
  local jmail_section=""
  if [[ ! ("$_jmail_user" == "<Optional>" || "$_jmail_pwd" == "<Optional>" || -z "$_jmail_user" || -z "$_jmail_pwd") ]]; then
    jmail_section=',
  "jMailUsername": "'$_jmail_user'",
  "jMailPassword": "'$_jmail_pwd'"'
  fi

  # Create JSON template using pre-built strings
  cat << EOF > "${BAN_VAULT_SECRET_FILE}"
{
  "_comment": "Create a $_ban_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_ban_secret_name @${BAN_VAULT_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  "appLoginUsername": "$_app_login_user",
  "appLoginPassword": "$_app_login_pwd",
  "navigatorDBUsername": "$_icn_db_user"${icn_pwd_section}${jmail_section},
  "ltpaPassword": "$_ltpa_pwd",
  "keystorePassword": "$_keystore_pwd"
}
EOF

  # Build conditional sections for SecretProviderClass
  local icn_pwd_secret_section=""
  if [[ (! ("$_pg_client_flag" == "true" || "$_pg_client_flag" == "yes" || "$_pg_client_flag" == "y")) || $DB_TYPE == 'postgresql-edb' ]]; then
    icn_pwd_secret_section='
      - secretPath: "'$vault_path'/'$_ban_secret_name'"
        objectName: "navigatorDBPassword"
        secretKey: "navigatorDBPassword"'
  fi
  
  # Only create this section when jmail user and jmail password are not <Optional>
  local jmail_secret_section=""
  if [[ ! ("$_jmail_user" == "<Optional>" || "$_jmail_pwd" == "<Optional>" || -z "$_jmail_user" || -z "$_jmail_pwd") ]]; then
    jmail_secret_section='
      - secretPath: "'$vault_path'/'$_ban_secret_name'"
        objectName: "jMailUsername"
        secretKey: "jMailUsername"
      - secretPath: "'$vault_path'/'$_ban_secret_name'"
        objectName: "jMailPassword"
        secretKey: "jMailPassword"'
  fi

  # Create SecretProviderClass template using pre-built strings
  cat << EOF > "${BAN_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"

# YAML template for ibm-ban-secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_ban_secret_name)
# The keys in this template should match with the keys in the $_ban_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_ban_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$_db_server"
    db-name: "$_db_name"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-content-operator,icp4a-foundation-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_ban_secret_name"
        objectName: "appLoginUsername"
        secretKey: "appLoginUsername"
      - secretPath: "$vault_path/$_ban_secret_name"
        objectName: "appLoginPassword"
        secretKey: "appLoginPassword"
      - secretPath: "$vault_path/$_ban_secret_name"
        objectName: "navigatorDBUsername"
        secretKey: "navigatorDBUsername"${icn_pwd_secret_section}${jmail_secret_section}
      - secretPath: "$vault_path/$_ban_secret_name"
        objectName: "ltpaPassword"
        secretKey: "ltpaPassword"
      - secretPath: "$vault_path/$_ban_secret_name"
        objectName: "keystorePassword"
        secretKey: "keystorePassword"
EOF

# Create SecretProviderClass for ibm-ban-secret for separation of duties
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for ibm-ban-secret in namespace $CP4BA_OPERATOR_NS"
  cp "${BAN_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${BAN_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${BAN_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi

  success "Created $_ban_secret_name secret JSON template and SecretProviderClass template for Vault\n"
}

#DBACLD-193988: bts-datastore-edb-secret
# --------------------------
# bts-datastore-edb-secret
# --------------------------
#This function read the content of propertyfile/cert/bts_external_db/{tls_key.pk8,client.pem,root.pem} and generate the Json and the SecretProviderClass
function create_bts_datastore_edb_secret_vault_template(){
  wait_msg "Creating bts-datastore-edb-secret secret JSON template and SecretProviderClass template for Vault"
  mkdir -p $BTS_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1  
  local _bts_secret_name=$1
  local _bts_secret_folder=$2
   
  if [[ ! -f "$_bts_secret_folder/root.crt" || ! -f "$_bts_secret_folder/client.crt" || ! -f "$_bts_secret_folder/client.key" ]]; then
    error "Please copy \"root.crt\" \"client.crt\" \"client.key\" into the "$_bts_secret_folder" first"
    exit 1
  else
    openssl x509 -in $_bts_secret_folder/root.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1
    openssl x509 -in $_bts_secret_folder/client.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1
    openssl rsa -in $_bts_secret_folder/client.key -outform PEM -out $_bts_secret_folder/client_key.pem >/dev/null 2>&1
    openssl x509 -in $_bts_secret_folder/client.crt -outform PEM -out $_bts_secret_folder/client.pem >/dev/null 2>&1
    openssl x509 -in $_bts_secret_folder/root.crt -outform PEM -out $_bts_secret_folder/root.pem >/dev/null 2>&1
    openssl pkcs8 -topk8 -inform PEM -in $_bts_secret_folder/client_key.pem -outform DER -nocrypt -out $_bts_secret_folder/tls_key.pk8
  fi
  _bts_client_content=$(<${_bts_secret_folder}/client.pem)
  _bts_root_content=$(<${_bts_secret_folder}/root.pem)
  #NOTE: Since tls_key.pk8 is in DER format, we need to base64 encode it before putting it in the JSON template, and decode it when we use it in the code.  This is because Vault and Kubernetes Secret do not support binary data, but they can support base64 encoded string.
  _bts_tls_content=$(base64 -w 0 < "${_bts_secret_folder}/tls_key.pk8")
  # Remove carriage returns and convert multi-line certificate to single line with \n escape sequences
  _bts_client_content=$(echo "$_bts_client_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  _bts_root_content=$(echo "$_bts_root_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

# For https://jsw.ibm.com/browse/DBACLD-238245 and https://jsw.ibm.com/browse/DBACLD-238566 we now need to update the bts-datastore-edb-secret template to have a different key
# THe key tls.key will be replaced to be tls.pk8 as the client.key file that it stores is in pk8 format. With new Postgres drivers, if you name it tls.key it expects the the key cert to be in PEM format. 
cat << EOF > "${BTS_VAULT_SECRET_FILE}"
{
  "_comment": "Create a $_bts_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_bts_secret_name @${BTS_VAULT_SECRET_FILE}).  Optionally, this property, _comment, can be removed before creating the secret.",
  "ca.crt": "${_bts_root_content}",
  "tls.crt": "${_bts_client_content}",
  "tls.pk8": "${_bts_tls_content}"
}
EOF

cat << EOF > "${BTS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for bts-datastore-edb-secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_bts_secret_name)
# The keys in this template should match with the keys in the $_bts_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_bts_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-bts-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_bts_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
      - secretPath: "$vault_path/$_bts_secret_name"
        objectName: "ca.crt"
        secretKey: "ca.crt"
      - secretPath: "$vault_path/$_bts_secret_name"
        objectName: "tls.pk8"
        secretKey: "tls.pk8"
EOF

#Create SecretProviderClass for BTS TLS certificate for separation of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for BTS TLS certificate in namespace $CP4BA_OPERATOR_NS"
  cp "${BTS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${BTS_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${BTS_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi

  success "Created $_bts_secret_name secret JSON template and SecretProviderClass template for Vault\n"
}

#DBACLD-193988: im-datastore-edb-secret
# --------------------------
# im-datastore-edb-secret
# --------------------------

function create_im_datastore_edb_secret_vault_template(){
  wait_msg "Creating im-datastore-edb-secret secret JSON template for Vault"
  mkdir -p $IM_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1  
  local _im_secret_name=$1
  local _im_secret_folder=$2
   
  if [[ ! -f "$_im_secret_folder/root.crt" || ! -f "$_im_secret_folder/client.crt" || ! -f "$_im_secret_folder/client.key" ]]; then
    error "Please copy \"root.crt\" \"client.crt\" \"client.key\" into the "$_im_secret_folder" first"
    exit 1
  else
    openssl x509 -in $_im_secret_folder/root.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1
    openssl x509 -in $_im_secret_folder/client.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1
    openssl rsa -in $_im_secret_folder/client.key -outform PEM -out $_im_secret_folder/client_key.pem >/dev/null 2>&1
    openssl x509 -in $_im_secret_folder/client.crt -outform PEM -out $_im_secret_folder/client.pem >/dev/null 2>&1
    openssl x509 -in $_im_secret_folder/root.crt -outform PEM -out $_im_secret_folder/root.pem >/dev/null 2>&1
  fi
  _im_client_content=$(<${_im_secret_folder}/client.pem)
  _im_root_content=$(<${_im_secret_folder}/root.pem)
  _im_client_key_content=$(<${_im_secret_folder}/client_key.pem)
  # Remove carriage returns and convert multi-line certificate to single line with \n escape sequences
  _im_client_content=$(echo "$_im_client_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  _im_root_content=$(echo "$_im_root_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  _im_client_key_content=$(echo "$_im_client_key_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

  cat << EOF > "${IM_VAULT_SECRET_FILE}"
{
  "_comment": "Create a $_im_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_im_secret_name @${IM_VAULT_SECRET_FILE}).  Optionally, this property, _comment, can be removed before creating the secret.",
  "ca.crt": "${_im_root_content}",
  "tls.crt": "${_im_client_content}",
  "tls.key": "${_im_client_key_content}"
}
EOF

cat << EOF > "${IM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for im-datastore-edb-secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_im_secret_name)
# The keys in this template should match with the keys in the $_im_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_im_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    authentication.operator.ibm.com/as-volume: "pgsql-certs"
    app.kubernetes.io/part-of: "im"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-iam-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_im_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
      - secretPath: "$vault_path/$_im_secret_name"
        objectName: "ca.crt"
        secretKey: "ca.crt"
      - secretPath: "$vault_path/$_im_secret_name"
        objectName: "tls.key"
        secretKey: "tls.key"
EOF
#NOTE: Per IM team, we don't need to create the SPC in the operator namespace in the SoD case.
# if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
#   info "Creating SecretProviderClass for IM External PG TLS certificate in namespace $CP4BA_OPERATOR_NS"
#   cp "${VAULT_IM_SECRET_TLS_PROVIDER_CLASS_FILE}.yaml" "${VAULT_IM_SECRET_TLS_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
#   #replace the namespace in the copied file
#   ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${VAULT_IM_SECRET_TLS_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
# fi

  success "Created $_im_secret_name secret JSON template and SecretProviderClass template for Vault\n"
}


# --------------------------
# ibm-odm-db-secret
# --------------------------
function create_odm_secret_vault_template(){
  local _dbname=$1
  local _dbserver=$2
  local _odm_db_user=$3
  local _odm_postgresql_client_flag=$4

  local _odm_secret_name="ibm-odm-db-secret"

  _odm_db_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$_odm_db_user")

  wait_msg "Creating $_odm_secret_name JSON template and SecretProviderClass template for Vault"
  mkdir -p $ODM_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

  # start off without password, add the field later (if not Postgres client auth, which doesn't require pwd)
  cat << EOF > "${ODM_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_odm_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_odm_secret_name @${ODM_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name (e.g. ${_odm_secret_name}). Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "db-user": "$_odm_db_user"
}
EOF

  cat << EOF > "${ODM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_odm_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_odm_secret_name)
# The keys in this template should match with the keys in the $_odm_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_odm_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$_dbserver"
    db-name: "$_dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-odm-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_odm_secret_name"
        objectName: "db-user"
        secretKey: "db-user"
EOF


  # If Postgres client-auth is not enabled, add password field
  if [[ ! ($_odm_postgresql_client_flag == "true" || $_odm_postgresql_client_flag == "yes" || $_odm_postgresql_client_flag == "y") ]]; then
    local _odm_db_password="$(decode_base64_password "$(prop_db_name_user_property_file ODM_DB_USER_PASSWORD)")"
    _odm_db_password=$(sed -e 's/^"//' -e 's/"$//' <<<"$_odm_db_password")

    # Add password to SecretProviderClass YAML template
    append_to_secretprovider_objects "${ODM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "$vault_path/$_odm_secret_name" "db-password" "db-password"
    
    # Add password field to Vault JSON template (for Vault, the pwd should be in plain-text)
    ${YQ_CMD} -i ".db-password= \"$_odm_db_password\"" "${ODM_VAULT_SECRET_FILE}"
  fi

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
      info "Creating SecretProviderClass for ${_odm_secret_name} in $CP4BA_OPERATOR_NS namespace"
      cp "${ODM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${ODM_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
      ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${ODM_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created $_odm_secret_name JSON template and SecretProviderClass template for Vault\n"

}



# --------------------------
# ibm-odm-keystore-secret
# --------------------------
#https://jsw.ibm.com/browse/DBACLD-238578: Vault's implementation for ibm-odm-keystore-secret
function create_odm_keystore_password_secret_vault_template(){

  mkdir -p $ODM_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _keystore_password=${1:-"<KEYSTORE_PASSWORD>"}
  local _odm_keystore_password_secret="ibm-odm-keystore-secret"

  # just in case there is "{base64}" prefix in the password, decode it (only if needed)
  _keystore_password="$(decode_base64_password "$_keystore_password")"

  # Create JSON template
  cat << EOF > ${ODM_VAULT_KEYSTORE_PASSWORD_SECRET_FILE}
{
  "_comment": "Create a $_odm_keystore_password_secret for Vault (eg: vault kv put ${kv_vault_path}/$_odm_keystore_password_secret @${ODM_VAULT_KEYSTORE_PASSWORD_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  "keystorePassword": "$_keystore_password"
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${ODM_VAULT_KEYSTORE_PASSWORD_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_odm_keystore_password_secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_odm_keystore_password_secret)
# The keys in this template should match with the keys in the $_odm_keystore_password_secret JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_odm_keystore_password_secret"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-odm-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_odm_keystore_password_secret"
        objectName: "keystorePassword"
        secretKey: "keystorePassword"
EOF
#Create SecretProviderClass for ibm-odm-keystore-secret secret for separation of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for ibm-odm-keystore-secret secret in namespace $CP4BA_OPERATOR_NS"
  cp "${ODM_VAULT_KEYSTORE_PASSWORD_SECRET_PROVIDER_CLASS_FILE}.yaml" "${ODM_VAULT_KEYSTORE_PASSWORD_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${ODM_VAULT_KEYSTORE_PASSWORD_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi
  success "Created $_odm_keystore_password_secret JSON template and SecretProviderClass template for Vault\n"
}


function check_if_property_is_enabled() {
  local _property_value="$1"
  _property_value=$(sed -e 's/^"//' -e 's/"$//' <<<"$_property_value")
  _property_value=$(echo "$_property_value" | tr '[:upper:]' '[:lower:]')
  if [[ "$_property_value" == "true" || "$_property_value" == "yes" || "$_property_value" == "y" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# --------------------------
# ibm-ads-designer-secret
# --------------------------
function create_di_designer_secret_vault_template(){
  local _ads_designer_secret_name="icp4adeploy-ibm-ads-designer-secret"
  local _ads_designer_db_user="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_USER_NAME)"
  local _ads_designer_db_password="$(decode_base64_password "$(prop_db_name_user_property_file DICMS_DESIGNER_DB_USER_PASSWORD)")"
  local _ads_designer_encryptionKeys="$(prop_user_profile_json_property DICMS_DESIGNER_ENCRYPTION_KEYS ${USER_PROFILE_PROPERTY_FILE})"
  local _ads_designer_sslKeystorePassword="$(decode_base64_password "$(prop_user_profile_property_file DICMS_DESIGNER_SSL_KEYSTORE_PASSWORD)")"
 

  _ads_designer_db_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_designer_db_user")
  _ads_designer_db_password=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_designer_db_password")
  # _ads_designer_encryptionKeys already has quotes stripped by prop_user_profile_json_property
  _ads_designer_sslKeystorePassword=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_designer_sslKeystorePassword")

  wait_msg "Creating $_ads_designer_secret_name JSON template and SecretProviderClass template for Vault"
  mkdir -p "${DI_VAULT_SECRET_FILE_FOLDER}" >/dev/null 2>&1

  # get server/instance for DICMS Designer
  local _dbservername="$(prop_db_name_user_property_file_for_server_name DICMS_DESIGNER_DB_NAME)"
  _dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$_dbservername")
  check_dbserver_name_valid $_dbservername "DICMS_DESIGNER_DB_NAME"

  local _postgresql_client_enabled=$(check_if_property_is_enabled "$(prop_db_server_property_file $_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
  local _database_ssl_enabled=$(check_if_property_is_enabled "$(prop_db_server_property_file $_dbservername.DATABASE_SSL_ENABLE)")

  local _ssl_folder_path=""
  local _server_ca_content=""
  local _client_cert_content=""
  local _client_key_content=""
  if [[ "$_database_ssl_enabled" == "true" ]]; then
    _ssl_folder_path="$(prop_db_server_property_file ${_dbservername}.DATABASE_SSL_CERT_FILE_FOLDER)"
    _ssl_folder_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ssl_folder_path")
    if [[ "$_postgresql_client_enabled" == "true" ]]; then
      _client_cert_content=$(cat ${_ssl_folder_path}/client.crt | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
      _client_key_content=$(cat ${_ssl_folder_path}/client.key | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
      _server_ca_content=$(cat ${_ssl_folder_path}/root.crt | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    else
      _server_ca_content=$(cat ${_ssl_folder_path}/db-cert.crt | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    fi
  fi


  # Use jq to properly construct JSON with correct escaping
  jq -n \
    --arg comment "Create $_ads_designer_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_ads_designer_secret_name @${DI_DESIGNER_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name (e.g. ${_ads_designer_secret_name}). Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text." \
    --arg dbUsername "$_ads_designer_db_user" \
    --arg encryptionKeys "$_ads_designer_encryptionKeys" \
    --arg sslKeystorePassword "$_ads_designer_sslKeystorePassword" \
    '{
      "_comment": $comment,
      "dbUsername": $dbUsername,
      "encryptionKeys": $encryptionKeys,
      "sslKeystorePassword": $sslKeystorePassword
    }' > "${DI_DESIGNER_VAULT_SECRET_FILE}"

  # When POSTGRESQL_SSL_CLIENT_SERVER is not true, add dbPassword to JSON
  if [[ "$_postgresql_client_enabled" != "true" ]]; then
    ${YQ_CMD} -i ".dbPassword = \"$_ads_designer_db_password\"" "${DI_DESIGNER_VAULT_SECRET_FILE}"
  fi

  # When DATABASE_SSL_ENABLE is true, add serverCA to JSON
  if [[ "$_database_ssl_enabled" == "true" ]]; then
    ${YQ_CMD} -i ".serverCA = \"$_server_ca_content\"" "${DI_DESIGNER_VAULT_SECRET_FILE}"
  fi

  # When POSTGRESQL_SSL_CLIENT_SERVER is true, add client certificate auth to JSON
  if [[ "$_postgresql_client_enabled" == "true" ]]; then
    ${YQ_CMD} -i ".clientCert = \"$_client_cert_content\"" "${DI_DESIGNER_VAULT_SECRET_FILE}"
    ${YQ_CMD} -i ".clientKey = \"$_client_key_content\"" "${DI_DESIGNER_VAULT_SECRET_FILE}"
  fi

  local _dbname="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_NAME)"

  cat << EOF > "${DI_DESIGNER_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_ads_designer_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_ads_designer_secret_name)
# The keys in this template should match with the keys in the $_ads_designer_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_ads_designer_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$_dbservername"
    db-name: "$_dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-ads-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_ads_designer_secret_name"
        objectName: "dbUsername"
        secretKey: "dbUsername"
      - secretPath: "$vault_path/$_ads_designer_secret_name"
        objectName: "encryptionKeys"
        secretKey: "encryptionKeys"
      - secretPath: "$vault_path/$_ads_designer_secret_name"
        objectName: "sslKeystorePassword"
        secretKey: "sslKeystorePassword"
EOF

  # When POSTGRESQL_SSL_CLIENT_SERVER is not true, add dbPassword object to SecretProviderClass
  if [[ "$_postgresql_client_enabled" != "true" ]]; then
    cat << EOF >> "${DI_DESIGNER_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
      - secretPath: "$vault_path/$_ads_designer_secret_name"
        objectName: "dbPassword"
        secretKey: "dbPassword"
EOF
  fi

  # When DATABASE_SSL_ENABLE is true, add serverCA object to SecretProviderClass
  if [[ "$_database_ssl_enabled" == "true" ]]; then
    cat << EOF >> "${DI_DESIGNER_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
      - secretPath: "$vault_path/$_ads_designer_secret_name"
        objectName: "serverCA"
        secretKey: "serverCA"
EOF
  fi

  # When POSTGRESQL_SSL_CLIENT_SERVER is true, add client certificate auth objects to SecretProviderClass
  if [[ "$_postgresql_client_enabled" == "true" ]]; then
    cat << EOF >> "${DI_DESIGNER_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
      - secretPath: "$vault_path/$_ads_designer_secret_name"
        objectName: "clientCert"
        secretKey: "clientCert"
      - secretPath: "$vault_path/$_ads_designer_secret_name"
        objectName: "clientKey"
        secretKey: "clientKey"
EOF
  fi

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
      info "Creating SecretProviderClass for ${_ads_designer_secret_name} in $CP4BA_OPERATOR_NS namespace"
      cp "${DI_DESIGNER_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${DI_DESIGNER_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
      ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${DI_DESIGNER_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created $_ads_designer_secret_name JSON template and SecretProviderClass template for Vault\n"
}


# --------------------------
# ibm-ads-runtime-secret
# --------------------------
function create_di_runtime_secret_vault_template(){
  local _ads_runtime_secret_name="icp4adeploy-ibm-ads-runtime-secret"
  local _ads_runtime_db_user="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_USER_NAME)"
  local _ads_runtime_db_password="$(decode_base64_password "$(prop_db_name_user_property_file DICMS_RUNTIME_DB_USER_PASSWORD)")"
  local _ads_runtime_deploymentSpaceManagerUsername="$(prop_user_profile_property_file DICMS_RUNTIME_DEPLOYMENT_SPACE_MANAGER_USERNAME)"
  local _ads_runtime_deploymentSpaceManagerPassword="$(decode_base64_password "$(prop_user_profile_property_file DICMS_RUNTIME_DEPLOYMENT_SPACE_MANAGER_PASSWORD)")"
  local _ads_runtime_decisionServiceUsername="$(prop_user_profile_property_file DICMS_RUNTIME_DECISION_SERVICE_USERNAME)"
  local _ads_runtime_decisionServicePassword="$(decode_base64_password "$(prop_user_profile_property_file DICMS_RUNTIME_DECISION_SERVICE_PASSWORD)")"
  local _ads_runtime_decisionServiceManagerUsername="$(prop_user_profile_property_file DICMS_RUNTIME_DECISION_SERVICE_MANAGER_USERNAME)"
  local _ads_runtime_decisionServiceManagerPassword="$(decode_base64_password "$(prop_user_profile_property_file DICMS_RUNTIME_DECISION_SERVICE_MANAGER_PASSWORD)")"
  local _ads_runtime_decisionRuntimeMonitorUsername="$(prop_user_profile_property_file DICMS_RUNTIME_DECISION_RUNTIME_MONITOR_USERNAME)"
  local _ads_runtime_decisionRuntimeMonitorPassword="$(decode_base64_password "$(prop_user_profile_property_file DICMS_RUNTIME_DECISION_RUNTIME_MONITOR_PASSWORD)")"
  local _ads_runtime_encryptionKeys="$(prop_user_profile_json_property DICMS_RUNTIME_ENCRYPTION_KEYS ${USER_PROFILE_PROPERTY_FILE})"
  local _ads_runtime_sslKeystorePassword="$(decode_base64_password "$(prop_user_profile_property_file DICMS_RUNTIME_SSL_KEYSTORE_PASSWORD)")"

  # get server/instance for DICMS Runtime
  local _dbservername="$(prop_db_name_user_property_file_for_server_name DICMS_RUNTIME_DB_NAME)"
  _dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$_dbservername")
  check_dbserver_name_valid $_dbservername "DICMS_RUNTIME_DB_NAME"

  local _postgresql_client_enabled=$(check_if_property_is_enabled "$(prop_db_server_property_file $_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
  local _database_ssl_enabled=$(check_if_property_is_enabled "$(prop_db_server_property_file $_dbservername.DATABASE_SSL_ENABLE)")

  local _ssl_folder_path=""
  local _server_ca_content=""
  local _client_cert_content=""
  local _client_key_content=""
  if [[ "$_database_ssl_enabled" == "true" ]]; then
    _ssl_folder_path="$(prop_db_server_property_file ${_dbservername}.DATABASE_SSL_CERT_FILE_FOLDER)"
    _ssl_folder_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ssl_folder_path")
    if [[ "$_postgresql_client_enabled" == "true" ]]; then
      _client_cert_content=$(cat ${_ssl_folder_path}/client.crt | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
      _client_key_content=$(cat ${_ssl_folder_path}/client.key | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
      _server_ca_content=$(cat ${_ssl_folder_path}/root.crt | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    else
      _server_ca_content=$(cat ${_ssl_folder_path}/db-cert.crt | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    fi
  fi

  _ads_runtime_db_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_db_user")
  _ads_runtime_db_password=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_db_password")
  _ads_runtime_deploymentSpaceManagerUsername=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_deploymentSpaceManagerUsername")
  _ads_runtime_deploymentSpaceManagerPassword=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_deploymentSpaceManagerPassword")
  _ads_runtime_decisionServiceUsername=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_decisionServiceUsername")
  _ads_runtime_decisionServicePassword=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_decisionServicePassword")
  _ads_runtime_decisionServiceManagerUsername=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_decisionServiceManagerUsername")
  _ads_runtime_decisionServiceManagerPassword=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_decisionServiceManagerPassword")
  _ads_runtime_decisionRuntimeMonitorUsername=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_decisionRuntimeMonitorUsername")
  _ads_runtime_decisionRuntimeMonitorPassword=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_decisionRuntimeMonitorPassword")
  # _ads_runtime_encryptionKeys already has quotes stripped by prop_user_profile_json_property
  _ads_runtime_sslKeystorePassword=$(sed -e 's/^"//' -e 's/"$//' <<<"$_ads_runtime_sslKeystorePassword")

  wait_msg "Creating $_ads_runtime_secret_name JSON template and SecretProviderClass template for Vault"
  mkdir -p "${DI_VAULT_SECRET_FILE_FOLDER}" >/dev/null 2>&1

  # Use jq to properly construct JSON with correct escaping
  jq -n \
    --arg comment "Create $_ads_runtime_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_ads_runtime_secret_name @${DI_RUNTIME_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name (e.g. ${_ads_runtime_secret_name}). Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text. You must use distinct values for each user name as they are mapped to distinct application roles." \
    --arg dbUsername "$_ads_runtime_db_user" \
    --arg deploymentSpaceManagerUsername "$_ads_runtime_deploymentSpaceManagerUsername" \
    --arg deploymentSpaceManagerPassword "$_ads_runtime_deploymentSpaceManagerPassword" \
    --arg decisionServiceUsername "$_ads_runtime_decisionServiceUsername" \
    --arg decisionServicePassword "$_ads_runtime_decisionServicePassword" \
    --arg decisionServiceManagerUsername "$_ads_runtime_decisionServiceManagerUsername" \
    --arg decisionServiceManagerPassword "$_ads_runtime_decisionServiceManagerPassword" \
    --arg decisionRuntimeMonitorUsername "$_ads_runtime_decisionRuntimeMonitorUsername" \
    --arg decisionRuntimeMonitorPassword "$_ads_runtime_decisionRuntimeMonitorPassword" \
    --arg encryptionKeys "$_ads_runtime_encryptionKeys" \
    --arg sslKeystorePassword "$_ads_runtime_sslKeystorePassword" \
    '{
      "_comment": $comment,
      "dbUsername": $dbUsername,
      "deploymentSpaceManagerUsername": $deploymentSpaceManagerUsername,
      "deploymentSpaceManagerPassword": $deploymentSpaceManagerPassword,
      "decisionServiceUsername": $decisionServiceUsername,
      "decisionServicePassword": $decisionServicePassword,
      "decisionServiceManagerUsername": $decisionServiceManagerUsername,
      "decisionServiceManagerPassword": $decisionServiceManagerPassword,
      "decisionRuntimeMonitorUsername": $decisionRuntimeMonitorUsername,
      "decisionRuntimeMonitorPassword": $decisionRuntimeMonitorPassword,
      "encryptionKeys": $encryptionKeys,
      "sslKeystorePassword": $sslKeystorePassword
    }' > "${DI_RUNTIME_VAULT_SECRET_FILE}"

  # When POSTGRESQL_SSL_CLIENT_SERVER is not true, add dbPassword to JSON
  if [[ "$_postgresql_client_enabled" != "true" ]]; then
    ${YQ_CMD} -i ".dbPassword = \"$_ads_runtime_db_password\"" "${DI_RUNTIME_VAULT_SECRET_FILE}"
  fi

  # When DATABASE_SSL_ENABLE is true, add serverCA to JSON
  if [[ "$_database_ssl_enabled" == "true" ]]; then
    ${YQ_CMD} -i ".serverCA = \"$_server_ca_content\"" "${DI_RUNTIME_VAULT_SECRET_FILE}"
  fi

  # When POSTGRESQL_SSL_CLIENT_SERVER is true, add client certificate auth to JSON
  if [[ "$_postgresql_client_enabled" == "true" ]]; then
    ${YQ_CMD} -i ".clientCert = \"$_client_cert_content\"" "${DI_RUNTIME_VAULT_SECRET_FILE}"
    ${YQ_CMD} -i ".clientKey = \"$_client_key_content\"" "${DI_RUNTIME_VAULT_SECRET_FILE}"
  fi

  local _dbname="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_NAME)"

  cat << EOF > "${DI_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_ads_runtime_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_ads_runtime_secret_name)
# The keys in this template should match with the keys in the $_ads_runtime_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_ads_runtime_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$_dbservername"
    db-name: "$_dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-ads-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "dbUsername"
        secretKey: "dbUsername"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "deploymentSpaceManagerUsername"
        secretKey: "deploymentSpaceManagerUsername"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "deploymentSpaceManagerPassword"
        secretKey: "deploymentSpaceManagerPassword"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "decisionServiceUsername"
        secretKey: "decisionServiceUsername"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "decisionServicePassword"
        secretKey: "decisionServicePassword"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "decisionServiceManagerUsername"
        secretKey: "decisionServiceManagerUsername"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "decisionServiceManagerPassword"
        secretKey: "decisionServiceManagerPassword"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "decisionRuntimeMonitorUsername"
        secretKey: "decisionRuntimeMonitorUsername"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "decisionRuntimeMonitorPassword"
        secretKey: "decisionRuntimeMonitorPassword"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "encryptionKeys"
        secretKey: "encryptionKeys"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "sslKeystorePassword"
        secretKey: "sslKeystorePassword"
EOF

  # When POSTGRESQL_SSL_CLIENT_SERVER is not true, add dbPassword object to SecretProviderClass
  if [[ "$_postgresql_client_enabled" != "true" ]]; then
    cat << EOF >> "${DI_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "dbPassword"
        secretKey: "dbPassword"
EOF
  fi

  # When DATABASE_SSL_ENABLE is true, add serverCA object to SecretProviderClass
  if [[ "$_database_ssl_enabled" == "true" ]]; then
    cat << EOF >> "${DI_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "serverCA"
        secretKey: "serverCA"
EOF
  fi

  # When POSTGRESQL_SSL_CLIENT_SERVER is true, add client certificate auth objects to SecretProviderClass
  if [[ "$_postgresql_client_enabled" == "true" ]]; then
    cat << EOF >> "${DI_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "clientCert"
        secretKey: "clientCert"
      - secretPath: "$vault_path/$_ads_runtime_secret_name"
        objectName: "clientKey"
        secretKey: "clientKey"
EOF
  fi

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
      info "Creating SecretProviderClass for ${_ads_runtime_secret_name} in $CP4BA_OPERATOR_NS namespace"
      cp "${DI_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${DI_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
      ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${DI_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created $_ads_runtime_secret_name JSON template and SecretProviderClass template for Vault\n"
}

# --------------------------
# AE Redis SSL Secret
# --------------------------
# Create templates for Application Engine Redis SSL certificate
function create_cp4a_ae_redis_ssl_vault_template(){
  local _redis_secret_name=${1}
  local _redis_cert_folder=${2}
  
  wait_msg "Creating Redis SSL cert secret JSON template for Application Engine (Vault)"
  mkdir -p $AE_REDIS_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  
  # Read and encode the Redis certificate
  _redis_tls_content=$(<${_redis_cert_folder}/redis.pem)
  # Remove carriage returns and convert multi-line certificate to single line with \n escape sequences
  _redis_tls_content=$(echo "$_redis_tls_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  
  cat << EOF > "${AE_REDIS_VAULT_SECRET_FILE}"
{
  "_comment": "Create a $_redis_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_redis_secret_name @${AE_REDIS_VAULT_SECRET_FILE}). The name should match with the secret name in the CR. Optionally, this property, _comment, can be removed before creating the secret.",
  "tls.crt": "${_redis_tls_content}"
}
EOF

cat << EOF > "${AE_REDIS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_redis_secret_name SecretProviderClass (Application Engine Redis SSL)
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_redis_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_redis_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
EOF

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for AE Redis SSL in namespace $CP4BA_OPERATOR_NS"
    cp "${AE_REDIS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${AE_REDIS_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${AE_REDIS_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created Redis SSL cert secret JSON template for Application Engine (Vault)\n"
}

# --------------------------
# Playback Redis SSL Secret
# --------------------------
# Create templates for Playback server Redis SSL certificate
function create_cp4a_playback_redis_ssl_vault_template(){
  local _redis_secret_name=${1}
  local _redis_cert_folder=${2}
  
  wait_msg "Creating Redis SSL cert secret JSON template for Playback server (Vault)"
  mkdir -p $PLAYBACK_REDIS_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  
  # Read and encode the Redis certificate
  _redis_tls_content=$(<${_redis_cert_folder}/redis.pem)
  # Remove carriage returns and convert multi-line certificate to single line with \n escape sequences
  _redis_tls_content=$(echo "$_redis_tls_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  
  cat << EOF > "${PLAYBACK_REDIS_VAULT_SECRET_FILE}"
{
  "_comment": "Create a $_redis_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_redis_secret_name @${PLAYBACK_REDIS_VAULT_SECRET_FILE}). The name should match with the secret name in the CR. Optionally, this property, _comment, can be removed before creating the secret.",
  "tls.crt": "${_redis_tls_content}"
}
EOF

cat << EOF > "${PLAYBACK_REDIS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_redis_secret_name SecretProviderClass (Playback Redis SSL)
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_redis_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_redis_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
EOF

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for Playback Redis SSL in namespace $CP4BA_OPERATOR_NS"
    cp "${PLAYBACK_REDIS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${PLAYBACK_REDIS_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${PLAYBACK_REDIS_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created Redis SSL cert secret JSON template for Playback server (Vault)\n"
}

# --------------------------
# Application Engine Secret
# --------------------------
# Create templates for Application Engine admin secret
function create_app_engine_secret_vault_template(){
  local dbname=$1
  local dbserver=$2
  local dbuser=${3:-"Your App Engine database username"}
  local dbpassword=$4
  local redis_password=${5:-""}
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  
  local _ae_secret_name="icp4adeploy-workspace-aae-app-engine-admin-secret"
  
  wait_msg "Creating Application Engine secret JSON template for Vault"
  mkdir -p $APP_ENGINE_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

  # Create JSON template - conditionally include AE_DATABASE_PWD
  if [[ -n "$dbpassword" ]]; then
cat << EOF > "${APP_ENGINE_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_ae_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_ae_secret_name @${APP_ENGINE_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "AE_DATABASE_PWD": "$dbpassword",
  "AE_DATABASE_USER": "$dbuser",
  "REDIS_PASSWORD": "$redis_password"
}
EOF
  else
cat << EOF > "${APP_ENGINE_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_ae_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_ae_secret_name @${APP_ENGINE_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text. Password omitted for PostgreSQL SSL client authentication.",
  "AE_DATABASE_USER": "$dbuser",
  "REDIS_PASSWORD": "$redis_password"
}
EOF
  fi

  # Create SecretProviderClass - conditionally include AE_DATABASE_PWD mapping
  if [[ -n "$dbpassword" ]]; then
cat << EOF > "${APP_ENGINE_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_ae_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_ae_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_ae_secret_name"
        objectName: "AE_DATABASE_PWD"
        secretKey: "AE_DATABASE_PWD"
      - secretPath: "$vault_path/$_ae_secret_name"
        objectName: "AE_DATABASE_USER"
        secretKey: "AE_DATABASE_USER"
      - secretPath: "$vault_path/$_ae_secret_name"
        objectName: "REDIS_PASSWORD"
        secretKey: "REDIS_PASSWORD"
EOF
  else
cat << EOF > "${APP_ENGINE_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_ae_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
# Note: AE_DATABASE_PWD omitted for PostgreSQL SSL client authentication
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_ae_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_ae_secret_name"
        objectName: "AE_DATABASE_USER"
        secretKey: "AE_DATABASE_USER"
      - secretPath: "$vault_path/$_ae_secret_name"
        objectName: "REDIS_PASSWORD"
        secretKey: "REDIS_PASSWORD"
EOF
  fi

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for Application Engine in namespace $CP4BA_OPERATOR_NS"
    cp "${APP_ENGINE_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${APP_ENGINE_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${APP_ENGINE_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created Application Engine secret JSON template for Vault\n"
}

# --------------------------
# Application Engine Oracle SSO Secret
# --------------------------
# Create templates for Application Engine/Playback Oracle SSO wallet
function create_app_engine_oracle_sso_secret_vault_template(){
  local dbserver=$1
  local _oracle_sso_secret_name=${2:-"app-engine-oracle-sso-secret"}
  local _oracle_sso_wallet_path=${3}
  
  wait_msg "Creating Application Engine/Playback Server Oracle SSO secret JSON template for Vault"
  mkdir -p $APP_ENGINE_ORACLE_SSO_VAULT_SECRET_FILE_FOLDER/$dbserver >/dev/null 2>&1
  
  local _oracle_sso_file="${APP_ENGINE_ORACLE_SSO_VAULT_SECRET_FILE_FOLDER}/$dbserver/${_oracle_sso_secret_name}.json"
  local _oracle_sso_provider_file="${APP_ENGINE_ORACLE_SSO_VAULT_SECRET_FILE_FOLDER}/$dbserver/${_oracle_sso_secret_name}-provider-class"
  
  # Read and encode the Oracle SSO wallet file
  if [[ -f "${_oracle_sso_wallet_path}/cwallet.sso" ]]; then
    _oracle_sso_content=$(base64 < "${_oracle_sso_wallet_path}/cwallet.sso" | tr -d '\n')
  else
    _oracle_sso_content="<BASE64_ENCODED_CWALLET_SSO_CONTENT>"
  fi
  
cat << EOF > "${_oracle_sso_file}"
{
  "_comment": "Create $_oracle_sso_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_oracle_sso_secret_name @${_oracle_sso_file}). The cwallet.sso file should be base64 encoded. Optionally, this property, _comment, can be removed before creating the secret.",
  "cwallet.sso": "${_oracle_sso_content}"
}
EOF

cat << EOF > "${_oracle_sso_provider_file}.yaml"
# YAML template for $_oracle_sso_secret_name SecretProviderClass (Oracle SSO Wallet)
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_oracle_sso_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_oracle_sso_secret_name"
        objectName: "cwallet.sso"
        secretKey: "cwallet.sso"
        encoding: "base64"
EOF

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for Oracle SSO in namespace $CP4BA_OPERATOR_NS"
    cp "${_oracle_sso_provider_file}.yaml" "${_oracle_sso_provider_file}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${_oracle_sso_provider_file}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created Application Engine/Playback Server Oracle SSO secret JSON template for Vault\n"
}

# --------------------------
# Business Automation Studio Secret
# --------------------------
# Create templates for Business Automation Studio admin secret
function create_bas_secret_vault_template(){
  local dbname=$1
  local dbserver=$2
  local dbuser=${3:-"Your Studio database username"}
  local dbpassword=$4
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  
  local _bas_secret_name="icp4adeploy-bas-admin-secret"
  
  wait_msg "Creating Business Automation Studio secret JSON template for Vault"
  mkdir -p $BAS_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

  # Create JSON template - conditionally include dbPassword
  if [[ -n "$dbpassword" ]]; then
    # Include password in JSON
cat << EOF > "${BAS_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_bas_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_bas_secret_name @${BAS_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "dbUsername": "$dbuser",
  "dbPassword": "$dbpassword"
}
EOF
  else
    # Omit password from JSON
cat << EOF > "${BAS_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_bas_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_bas_secret_name @${BAS_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text. Password omitted for PostgreSQL SSL client authentication.",
  "dbUsername": "$dbuser"
}
EOF
  fi

  # Create SecretProviderClass - conditionally include dbPassword mapping
  if [[ -n "$dbpassword" ]]; then
    # Include password mapping
cat << EOF > "${BAS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_bas_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_bas_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_bas_secret_name"
        objectName: "dbUsername"
        secretKey: "dbUsername"
      - secretPath: "$vault_path/$_bas_secret_name"
        objectName: "dbPassword"
        secretKey: "dbPassword"
EOF
  else
    # Omit password mapping
cat << EOF > "${BAS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_bas_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
# Note: dbPassword omitted for PostgreSQL SSL client authentication
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_bas_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_bas_secret_name"
        objectName: "dbUsername"
        secretKey: "dbUsername"
EOF
  fi

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for Business Automation Studio in namespace $CP4BA_OPERATOR_NS"
    cp "${BAS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${BAS_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${BAS_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created Business Automation Studio secret JSON template for Vault\n"
}

# --------------------------
# AE Playback Server Secret
# --------------------------
# Create templates for Application Engine Playback server admin secret
function create_ae_playback_secret_vault_template(){
  local dbname=$1
  local dbserver=$2
  local dbuser=${3:-"Your App Engine database username"}
  local dbpassword=$4
  local redis_password=${5:-""}
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  
  local _playback_secret_name="playback-server-admin-secret"
  
  wait_msg "Creating Application Engine playback server secret JSON template for Vault"
  mkdir -p $AE_PLAYBACK_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

  # Create JSON template - conditionally include AE_DATABASE_PWD
  if [[ -n "$dbpassword" ]]; then
cat << EOF > "${AE_PLAYBACK_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_playback_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_playback_secret_name @${AE_PLAYBACK_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "AE_DATABASE_PWD": "$dbpassword",
  "AE_DATABASE_USER": "$dbuser",
  "REDIS_PASSWORD": "$redis_password"
}
EOF
  else
cat << EOF > "${AE_PLAYBACK_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_playback_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_playback_secret_name @${AE_PLAYBACK_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text. Password omitted for PostgreSQL SSL client authentication.",
  "AE_DATABASE_USER": "$dbuser",
  "REDIS_PASSWORD": "$redis_password"
}
EOF
  fi

  # Create SecretProviderClass - conditionally include AE_DATABASE_PWD mapping
  if [[ -n "$dbpassword" ]]; then
cat << EOF > "${AE_PLAYBACK_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_playback_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_playback_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_playback_secret_name"
        objectName: "AE_DATABASE_PWD"
        secretKey: "AE_DATABASE_PWD"
      - secretPath: "$vault_path/$_playback_secret_name"
        objectName: "AE_DATABASE_USER"
        secretKey: "AE_DATABASE_USER"
      - secretPath: "$vault_path/$_playback_secret_name"
        objectName: "REDIS_PASSWORD"
        secretKey: "REDIS_PASSWORD"
EOF
  else
cat << EOF > "${AE_PLAYBACK_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_playback_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
# Note: AE_DATABASE_PWD omitted for PostgreSQL SSL client authentication
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_playback_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_playback_secret_name"
        objectName: "AE_DATABASE_USER"
        secretKey: "AE_DATABASE_USER"
      - secretPath: "$vault_path/$_playback_secret_name"
        objectName: "REDIS_PASSWORD"
        secretKey: "REDIS_PASSWORD"
EOF
  fi

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for AE Playback in namespace $CP4BA_OPERATOR_NS"
    cp "${AE_PLAYBACK_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${AE_PLAYBACK_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${AE_PLAYBACK_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created Application Engine playback server secret JSON template for Vault\n"
}

# --------------------------
# Workflow Assistant Secret
# --------------------------
# Create templates for IBM Workflow Assistant secret
function create_workflow_assistant_secret_vault_template(){
  local watsonx_api_key="$(prop_user_profile_property_file WFA.WATSONX_API_KEY)"
  watsonx_api_key=$(sed -e 's/^"//' -e 's/"$//' <<<"$watsonx_api_key")
  
  local watsonx_project_id="$(prop_user_profile_property_file WFA.WATSONX_PROJECT_ID)"
  watsonx_project_id=$(sed -e 's/^"//' -e 's/"$//' <<<"$watsonx_project_id")
  
  local watsonx_token="$(prop_user_profile_property_file WFA.WATSONX_TOKEN)"
  watsonx_token=$(sed -e 's/^"//' -e 's/"$//' <<<"$watsonx_token")
  
  local watsonx_url="$(prop_user_profile_property_file WFA.WATSONX_URL)"
  watsonx_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$watsonx_url")
  
  if [[ "<Optional>" == $watsonx_token ]]; then
    watsonx_token=""
  fi
  
  local watsonx_password="$(decode_base64_password "$(prop_user_profile_property_file WFA.WATSONX_PASSWORD)")"
  watsonx_password=$(sed -e 's/^"//' -e 's/"$//' <<<"$watsonx_password")
  
  if [[ "<Optional>" == $watsonx_password ]]; then
    watsonx_password=""
  fi
  
  local _wfa_secret_name="ibm-workflow-assistant-secrets"
  
  wait_msg "Creating IBM Workflow Assistant secret JSON template for Vault"
  mkdir -p $WORKFLOW_ASSISTANT_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

cat << EOF > "${WORKFLOW_ASSISTANT_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_wfa_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_wfa_secret_name @${WORKFLOW_ASSISTANT_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "WATSONX_TOKEN": "$watsonx_token",
  "WATSONX_API_KEY": "$watsonx_api_key",
  "WATSONX_PASSWORD": "$watsonx_password",
  "WATSONX_PROJECT_ID": "$watsonx_project_id",
  "WATSONX_URL": "$watsonx_url"
}
EOF

cat << EOF > "${WORKFLOW_ASSISTANT_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_wfa_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_wfa_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    app.kubernetes.io/name: ibm-workflow-assistant-secrets
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_wfa_secret_name"
        objectName: "WATSONX_TOKEN"
        secretKey: "WATSONX_TOKEN"
      - secretPath: "$vault_path/$_wfa_secret_name"
        objectName: "WATSONX_API_KEY"
        secretKey: "WATSONX_API_KEY"
      - secretPath: "$vault_path/$_wfa_secret_name"
        objectName: "WATSONX_PASSWORD"
        secretKey: "WATSONX_PASSWORD"
      - secretPath: "$vault_path/$_wfa_secret_name"
        objectName: "WATSONX_PROJECT_ID"
        secretKey: "WATSONX_PROJECT_ID"
      - secretPath: "$vault_path/$_wfa_secret_name"
        objectName: "WATSONX_URL"
        secretKey: "WATSONX_URL"
EOF

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for Workflow Assistant in namespace $CP4BA_OPERATOR_NS"
    cp "${WORKFLOW_ASSISTANT_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${WORKFLOW_ASSISTANT_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${WORKFLOW_ASSISTANT_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created IBM Workflow Assistant secret JSON template for Vault\n"
}

# --------------------------
# BAW Authoring Secret
# --------------------------
# Create templates for Business Automation Workflow authoring secret
function create_baw_authoring_secret_vault_template(){
  local dbname=$1
  local dbserver=$2
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  
  local _baw_secret_name="ibm-baw-wfs-server-db-secret"
  
  wait_msg "Creating Business Automation Workflow authoring secret JSON template for Vault"
  mkdir -p $BAW_AUTHORING_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

cat << EOF > "${BAW_AUTHORING_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_baw_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_baw_secret_name @${BAW_AUTHORING_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "dbUser": "<DB_USER>",
  "password": "<DB_USER_PASSWORD>"
}
EOF

cat << EOF > "${BAW_AUTHORING_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_baw_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_baw_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_baw_secret_name"
        objectName: "dbUser"
        secretKey: "dbUser"
      - secretPath: "$vault_path/$_baw_secret_name"
        objectName: "password"
        secretKey: "password"
EOF

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for BAW Authoring in namespace $CP4BA_OPERATOR_NS"
    cp "${BAW_AUTHORING_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${BAW_AUTHORING_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${BAW_AUTHORING_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created Business Automation Workflow authoring secret JSON template for Vault\n"
}

# --------------------------
# BAW AWS (Automation Workstream Services) Secret
# --------------------------
# Create templates for Automation Workstream Services secret
function create_baw_aws_secret_vault_template(){
  local dbname=$1
  local dbserver=$2
  local dbuser=${3:-"<DB_USER>"}
  local dbpassword=$4
  local postgresql_client_flag=$5
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  
  local _aws_secret_name="ibm-aws-wfs-server-db-secret"
  
  wait_msg "Creating Automation Workstream Services secret JSON template for Vault"
  mkdir -p $BAW_AWS_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

  # Create JSON template - conditionally include password
  if [[ -n "$dbpassword" ]]; then
cat << EOF > "${BAW_AWS_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_aws_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_aws_secret_name @${BAW_AWS_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "dbUser": "$dbuser",
  "password": "$dbpassword"
}
EOF
  else
cat << EOF > "${BAW_AWS_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_aws_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_aws_secret_name @${BAW_AWS_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text. Password omitted for PostgreSQL SSL client authentication.",
  "dbUser": "$dbuser"
}
EOF
  fi

  # Create SecretProviderClass - conditionally include password mapping
  if [[ -n "$dbpassword" ]]; then
cat << EOF > "${BAW_AWS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_aws_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_aws_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_aws_secret_name"
        objectName: "dbUser"
        secretKey: "dbUser"
      - secretPath: "$vault_path/$_aws_secret_name"
        objectName: "password"
        secretKey: "password"
EOF
  else
cat << EOF > "${BAW_AWS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_aws_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
# Note: password omitted for PostgreSQL SSL client authentication
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_aws_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_aws_secret_name"
        objectName: "dbUser"
        secretKey: "dbUser"
EOF
  fi

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for AWS in namespace $CP4BA_OPERATOR_NS"
    cp "${BAW_AWS_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${BAW_AWS_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${BAW_AWS_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created Automation Workstream Services secret JSON template for Vault\n"
}

# --------------------------
# BAW Runtime Secret
# --------------------------
# Create templates for Business Automation Workflow runtime secret
function create_baw_runtime_secret_vault_template(){
  local dbname=$1
  local dbserver=$2
  local dbuser=$3
  local dbpassword=$4
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
  dbpassword=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbpassword")
  local _baw_runtime_secret_name="ibm-baw-wfs-server-db-secret"
  
  wait_msg "Creating Business Automation Workflow runtime secret JSON template for Vault"
  mkdir -p $BAW_RUNTIME_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1

  # Create JSON template - conditionally include password
  if [[ -n "$dbpassword" ]]; then
cat << EOF > "${BAW_RUNTIME_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_baw_runtime_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_baw_runtime_secret_name @${BAW_RUNTIME_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "dbUser": "$dbuser",
  "password": "$dbpassword"
}
EOF
  else
cat << EOF > "${BAW_RUNTIME_VAULT_SECRET_FILE}"
{
  "_comment": "Create $_baw_runtime_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_baw_runtime_secret_name @${BAW_RUNTIME_VAULT_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text. Password omitted for PostgreSQL SSL client authentication.",
  "dbUser": "$dbuser"
}
EOF
  fi

  # Create SecretProviderClass - conditionally include password mapping
  if [[ -n "$dbpassword" ]]; then
cat << EOF > "${BAW_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_baw_runtime_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_baw_runtime_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_baw_runtime_secret_name"
        objectName: "dbUser"
        secretKey: "dbUser"
      - secretPath: "$vault_path/$_baw_runtime_secret_name"
        objectName: "password"
        secretKey: "password"
EOF
  else
cat << EOF > "${BAW_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_baw_runtime_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
# Note: password omitted for PostgreSQL SSL client authentication
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_baw_runtime_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$dbserver"
    db-name: "$dbname"
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-cp4a-operator,ibm-cp4a-wfps-operator,ibm-pfs-operator,ibm-workflow-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_baw_runtime_secret_name"
        objectName: "dbUser"
        secretKey: "dbUser"
EOF
  fi

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for BAW Runtime in namespace $CP4BA_OPERATOR_NS"
    cp "${BAW_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${BAW_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${BAW_RUNTIME_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created Business Automation Workflow runtime secret JSON template for Vault\n"
}


# ============================================
# Function: validate_vault_props
# Description: Validates vault configuration properties when --enable-external-secret-management flag is set
# Parameters:
#   $1 - vault_enabled: Value of CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION
# Returns: Exits with error code 1 if validation fails
# ============================================
function validate_vault_props() {
    local vault_enabled="$1"
    
    # Check if ENABLE_EXTERNAL_VAULT_INTEGRATION is enabled
    if [[ "$vault_enabled" != "true" ]]; then
        printf '%b\n' "\x1B[1;31m[ERROR]\x1B[0m The --enable-external-secret-management flag requires CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION to be set to \"true\" in 'cp4ba_user_profile.property'"
        printf '%b\n' "\x1B[1;31m[ERROR]\x1B[0m Current value: vault_enabled=\"$vault_enabled\""
        exit 1
    fi
    
    # Check VAULT_ROLE
    local vault_role
    vault_role="$(prop_user_profile_property_file CP4BA.VAULT_ROLE)"
    vault_role=$(sed -e 's/^"//' -e 's/"$//' <<<"$vault_role")
    if [[ -z "$vault_role" || "$vault_role" == "<Required>" ]]; then
        printf '%b\n' "\x1B[1;31m[ERROR]\x1B[0m To enable Vault integration, the CP4BA.VAULT_ROLE must be set in 'cp4ba_user_profile.property' (current value: \"$vault_role\")"
        exit 1
    fi
    
    # Check VAULT_ADDRESS
    local vault_address
    vault_address="$(prop_user_profile_property_file CP4BA.VAULT_ADDRESS)"
    vault_address=$(sed -e 's/^"//' -e 's/"$//' <<<"$vault_address")
    if [[ -z "$vault_address" || "$vault_address" == "<Required>" ]]; then
        printf '%b\n' "\x1B[1;31m[ERROR]\x1B[0m To enable Vault integration, the CP4BA.VAULT_ADDRESS must be set in 'cp4ba_user_profile.property' (current value: \"$vault_address\")"
        exit 1
    fi
    
    # Check VAULT_PATH
    local vault_path
    vault_path="$(prop_user_profile_property_file CP4BA.VAULT_PATH)"
    vault_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$vault_path")
    if [[ -z "$vault_path" || "$vault_path" == "<Required>" ]]; then
        printf '%b\n' "\x1B[1;31m[ERROR]\x1B[0m To enable Vault integration, the CP4BA.VAULT_PATH must be set in 'cp4ba_user_profile.property' (current value: \"$vault_path\")"
        exit 1
    fi
    
    printf '%b\n' "\x1B[1;32m[INFO]\x1B[0m Vault configuration validated successfully for --enable-external-secret-management mode"
}


# ============================================
# Function: get_vault_secret_list
# Description: Iterates through subfolders under VAULT_SECRET_PARENT_FOLDER and creates
#              a comma-separated list of secret names from SecretProviderClass template files
# Returns: Sets global variable VAULT_SECRET_LIST with comma-separated secret names
# ============================================
function get_vault_secret_list() {
    local secret_names=()
    local yaml_file
    local secret_name
    
    # Check if VAULT_SECRET_PARENT_FOLDER exists
    if [[ ! -d "$VAULT_SECRET_PARENT_FOLDER" ]]; then
        warning "Vault secret folder does not exist: $VAULT_SECRET_PARENT_FOLDER"
        VAULT_SECRET_LIST=""
        return 1
    fi
    
    # Find all *-provider-class.yaml files recursively
    while IFS= read -r yaml_file; do
        # Extract metadata.name using yq
        secret_name=$(${YQ_CMD} eval '.metadata.name' "$yaml_file" 2>/dev/null)
        
        # Check if secret_name is valid (not null, not empty, not "null" string)
        if [[ -n "$secret_name" && "$secret_name" != "null" ]]; then
            # Remove quotes if present
            secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$secret_name")
            secret_names+=("$secret_name")
        fi
    done < <(find "$VAULT_SECRET_PARENT_FOLDER" -type f -name "*-provider-class.yaml" 2>/dev/null)
    
    # Sort and create comma-separated list with space after each comma
    if [[ ${#secret_names[@]} -gt 0 ]]; then
        # Sort the array alphabetically using a subshell to preserve IFS
        local sorted_names
        IFS=$'\n' sorted_names=($(printf '%s\n' "${secret_names[@]}" | sort))
        IFS=', '
        # Join sorted array elements with comma and space
        VAULT_SECRET_LIST="${sorted_names[*]}"
        unset IFS
    else
        VAULT_SECRET_LIST=""
    fi
    
    return 0
}

# ============================================
# Function: get_vault_csv_list_from_spc
# Description: Iterates through all SPC yaml files at VAULT_SECRET_PARENT_FOLDER
#              and extracts the list of operators from metadata.annotations."cp4ba.ibm.com/owned-by"
#              to determine which CSVs need to be patched for Vault integration.
# Parameters:
#   $1 - CP4BA_CSV_VERSION (e.g., "26.0.0")
# Returns: Sets global variable _vault_csv_list with comma-separated CSV names with version
# ============================================
function get_vault_csv_list_from_spc() {
    local csv_version="$1"
    local yaml_file
    local owned_by_value
    local operator_name
    local -A unique_operators  # Associative array to track unique operators
    local csv_list=""
    
    # Check if VAULT_SECRET_PARENT_FOLDER exists
    if [[ ! -d "$VAULT_SECRET_PARENT_FOLDER" ]]; then
        warning "Vault secret folder does not exist: $VAULT_SECRET_PARENT_FOLDER"
        _vault_csv_list=""
        return 1
    fi
    
    # Find all yaml files recursively
    while IFS= read -r yaml_file; do
        # First verify this is a SecretProviderClass
        local kind_value
        kind_value=$(${YQ_CMD} eval '.kind' "$yaml_file" 2>/dev/null)
        
        # Skip if not a SecretProviderClass
        if [[ "$kind_value" != "SecretProviderClass" ]]; then
            continue
        fi
        
        # Extract metadata.annotations."cp4ba.ibm.com/owned-by" using yq
        owned_by_value=$(${YQ_CMD} eval '.metadata.annotations."cp4ba.ibm.com/owned-by"' "$yaml_file" 2>/dev/null)
        
        # Check if owned-by annotation exists and is not null
        if [[ -z "$owned_by_value" || "$owned_by_value" == "null" ]]; then
            warning "SecretProviderClass file '$yaml_file' does not have 'cp4ba.ibm.com/owned-by' annotation. This SecretProviderClass will not be patched with any CSV which could be normal in certain cases."
            continue
        fi
        
        # Remove quotes if present
        owned_by_value=$(sed -e 's/^"//' -e 's/"$//' <<<"$owned_by_value")
        
        # Split comma-separated operators and add to unique_operators array
        IFS=',' read -ra operators <<< "$owned_by_value"
        for operator_name in "${operators[@]}"; do
            # Trim whitespace
            operator_name=$(echo "$operator_name" | xargs)
            
            # Skip if operator is in VAULT_EXCLUDE_PATCH_LIST_OF_CSV (exclusion list)
            local skip_operator=false
            for excluded_op in "${VAULT_EXCLUDE_PATCH_LIST_OF_CSV[@]}"; do
                if [[ "$operator_name" == "$excluded_op" ]]; then
                    skip_operator=true
                    break
                fi
            done
            
            # Add to unique operators if not excluded and not empty
            if [[ "$skip_operator" == false && -n "$operator_name" ]]; then
                # Add to unique operators array. For example:
                # File 1: "ibm-content-operator,ibm-workflow-operator"
                # unique_operators["ibm-content-operator"]=1  # Added
                # unique_operators["ibm-workflow-operator"]=1  # Added

                # # File 2: "ibm-content-operator,ibm-pfs-operator"  
                # unique_operators["ibm-content-operator"]=1  # Already exists, overwrites (no duplicate)
                unique_operators["$operator_name"]=1
            fi
        done
    done < <(find "$VAULT_SECRET_PARENT_FOLDER" -type f -name "*.yaml" 2>/dev/null)
    
    # Build comma-separated CSV list with version
    for operator_name in "${!unique_operators[@]}"; do
        if [[ -n "$csv_list" ]]; then
            csv_list+=","
        fi
        csv_list+="${operator_name}.${csv_version}"
    done
    
    # Sort the CSV list alphabetically
    if [[ -n "$csv_list" ]]; then
        # Split by comma, sort, and rejoin
        IFS=',' read -ra csv_array <<< "$csv_list"
        IFS=$'\n' sorted_csvs=($(printf '%s\n' "${csv_array[@]}" | sort))
        IFS=','
        _vault_csv_list="${sorted_csvs[*]}"
        unset IFS
    else
        _vault_csv_list=""
    fi
    
    return 0
}

# --------------------------
# WatsonX LWE SSL Secret for Vault
# --------------------------
# Create Vault templates for WatsonX Lightweight Engine SSL certificate for enabled providers with SSL enabled
#
# Purpose:
#   Generates SecretProviderClass and JSON template to create Vault secret containing
#   the SSL/TLS certificate for WatsonX Lightweight Engine (LWE) providers.
#
# Prerequisites:
#   - PARSED_PROVIDERS array must be populated (from parse_multi_provider_property_file)
#   - AI_SERVICES_SECRET_FOLDER must be defined (from common.sh)
#   - AI_SERVICES_SSL_SECRET_FILE must be defined (from common.sh)
#   - AI_SERVICES_SSL_SECRET_NAME must be defined (from common.sh)
#
# Behavior:
#   - Scans all providers to check if any LWE provider has SSL_ENABLED=true
#   - If no LWE providers with SSL, returns without creating anything
#   - If SSL is enabled,
#     * Validates the certificate file exists (lwe.crt)
#     * Creates SecretProviderClass template and JSON template for Vault secret with the certificate
#     * Labels the secret for backup
#
# Generated Secret:
#   - Name: watsonx-lwe-ssl-secret (from AI_SERVICES_SSL_SECRET_NAME)
#   - Type: generic
#   - Data: tls.crt (mounted from lwe.crt file)
#   - Label: cp4ba.ibm.com/backup-type=mandatory
#
# Certificate Requirements:
#   - File must be named 'lwe.crt'
#   - Must be placed in TLS_CERT_LOCATION folder
#   - Must be valid X.509 certificate
#
# Returns:
#   0 - Success (secret template created or skipped)
#
function create_watsonx_lwe_ssl_vault_template() {
    local provider_count=0
    local has_lwe_ssl=false
    
    # Count total providers by scanning PARSED_PROVIDERS array for PROVIDER_ID keys
    for key in "${!PARSED_PROVIDERS[@]}"; do
        if [[ "$key" =~ ^([0-9]+)_PROVIDER_ID$ ]]; then
            provider_count=$((provider_count + 1))
        fi
    done
    
    # Check if any enabled LWE provider has SSL enabled
    for ((i=1; i<=provider_count; i++)); do
        local provider_name="${PARSED_PROVIDERS[${i}_PROVIDER_NAME]}"
        local provider_enabled="${PARSED_PROVIDERS[${i}_ENABLED]}"
        local ssl_enabled="${PARSED_PROVIDERS[${i}_SSL_ENABLED]}"
        
        if [[ "$provider_enabled" == "true" ]] && [[ "$provider_name" == "watsonx_lightweightengine" ]] && [[ "$ssl_enabled" == "true" ]]; then
            has_lwe_ssl=true
            break
        fi
    done
    
    # Skip secret creation if no LWE providers have SSL enabled
    if [[ "$has_lwe_ssl" == "false" ]]; then
        return 0
    fi
    
    # Create secret folder if it doesn't exist
    mkdir -p "$AI_SERVICES_VAULT_TLS_SECRET_FOLDER" >/dev/null 2>&1
    
    # Get the TLS_CERT_LOCATION from the first enabled LWE provider with SSL
    # All LWE providers share the same SSL secret, so we only need one certificate location
    local cert_location=""
    for ((i=1; i<=provider_count; i++)); do
        local provider_name="${PARSED_PROVIDERS[${i}_PROVIDER_NAME]}"
        local provider_enabled="${PARSED_PROVIDERS[${i}_ENABLED]}"
        local ssl_enabled="${PARSED_PROVIDERS[${i}_SSL_ENABLED]}"
        
        if [[ "$provider_enabled" == "true" ]] && [[ "$provider_name" == "watsonx_lightweightengine" ]] && [[ "$ssl_enabled" == "true" ]]; then
            cert_location="${PARSED_PROVIDERS[${i}_TLS_CERT_LOCATION]}"
            break
        fi
    done
    
    local _lwe_ssl_secret_name="watsonx-lwe-ssl-secret"
    
    wait_msg "Creating WatsonX LWE SSL cert secret JSON template for Vault"
    
    # Read and encode the LWE certificate
    _lwe_tls_content=$(<${cert_location}/lwe.crt)
    # Remove carriage returns and convert multi-line certificate to single line with \n escape sequences
    _lwe_tls_content=$(echo "$_lwe_tls_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    
    cat << EOF > "${AI_SERVICES_VAULT_SSL_SECRET_FILE}"
{
  "_comment": "Create a $_lwe_ssl_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_lwe_ssl_secret_name @${AI_SERVICES_VAULT_SSL_SECRET_FILE}). The name should match with the secret name in the CR. Optionally, this property, _comment, can be removed before creating the secret.",
  "tls.crt": "${_lwe_tls_content}"
}
EOF

cat << EOF > "${AI_SERVICES_VAULT_SSL_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_lwe_ssl_secret_name SecretProviderClass (WatsonX LWE SSL)
# metadata.name must match with the name of the secret created in Vault
#
# Purpose: Creates a SecretProviderClass for WatsonX Lightweight Engine (LWE) SSL certificate
#
# Prerequisites:
#   - Certificate file 'lwe.crt' must exist in: $cert_location
#   - Secret must be created in Vault using the JSON template
#
# Secret Details:
#   - Name: ${_lwe_ssl_secret_name}
#   - Type: generic
#   - Data: tls.crt (from lwe.crt file)
#   - Namespace: $CP4BA_SERVICES_NS
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_lwe_ssl_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-ccx-ai-services-operator"
    cp4ba.ibm.com/secret-store-type: "tls"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_lwe_ssl_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
EOF

  if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
    info "Creating SecretProviderClass for WatsonX LWE SSL in namespace $CP4BA_OPERATOR_NS"
    cp "${AI_SERVICES_VAULT_SSL_SECRET_PROVIDER_CLASS_FILE}.yaml" "${AI_SERVICES_VAULT_SSL_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${AI_SERVICES_VAULT_SSL_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  fi

  success "Created WatsonX LWE SSL cert secret JSON template for Vault\n"

}

# --------------------------
# Multi-Provider Config Secret
# --------------------------
# Generate the JSON-based providers configuration secret for Vault
#
# Purpose:
#   Creates Vault JSON template and SecretProviderClass YAML containing provider 
#   and model configurations. Supports multiple AI providers (WatsonX SaaS, 
#   WatsonX LWE, Azure) with multiple models per provider.
#
# Prerequisites:
#   - PARSED_PROVIDERS array must be populated (from parse_multi_provider_property_file)
#   - PARSED_MODELS array must be populated (from parse_multi_provider_property_file)
#   - AI_SERVICES_VAULT_SECRET_FOLDER must be defined
#   - AI_SERVICES_VAULT_CONFIG_SECRET_FILE must be defined
#   - AI_SERVICES_VAULT_CONFIG_SECRET_PROVIDER_CLASS_FILE must be defined
#   - jq must be installed for JSON generation
#
# Secret Structure:
#   The generated secret contains a JSON configuration with:
#   - active_llm: Key of the default model (from model with DEFAULT=true)
#   - llms: Object containing all model configurations, keyed by "PROVIDER_ID_SANITIZED_MODEL_ID"
#          (special characters like /, -, . are removed from MODEL_ID)
#
# Model Configuration Fields (provider-specific):
#   Common to all:
#     - provider: Provider type ("watsonx" or "azure")
#     - model: Model identifier
#     - temperature: Sampling temperature (optional)
#     - max_completion_tokens: Max tokens to generate (optional)
#     - context_window_token_limit: Max context window size (optional)
#
#   WatsonX SaaS specific:
#     - deployment_mode: "saas"
#     - url: WatsonX API endpoint
#     - api_key: API authentication key
#     - space_id: WatsonX space identifier (optional)
#     - project_id: WatsonX project identifier (optional)
#
#   WatsonX LWE specific:
#     - deployment_mode: "lightweight"
#     - url: LWE endpoint URL
#     - instance_id: "openshift"
#     - version: "5.3"
#     - username: LWE username (optional)
#     - api_key: API key (preferred) OR password: Password (alternative)
#     - verify_ssl: Certificate path or false
#     - ssl_secret_name: Name of SSL secret (if SSL enabled)
#
#   Azure specific:
#     - provider: "azure"
#     - endpoint: Azure endpoint URL
#     - api_key: Azure API key
#     - use_entra_id: false
#     - timeout: 60
#     - api_version: "2024-12-01-preview"
#
function generate_multi_provider_vault_template() {
    # Create secret folder if it doesn't exist
    mkdir -p "$AI_SERVICES_VAULT_SECRET_FOLDER" >/dev/null 2>&1
    
    wait_msg "Creating multi-provider config secret JSON template for Vault"
    
    # Count total providers by scanning PARSED_PROVIDERS array
    local provider_count=0
    for key in "${!PARSED_PROVIDERS[@]}"; do
        if [[ "$key" =~ ^([0-9]+)_PROVIDER_ID$ ]]; then
            provider_count=$((provider_count + 1))
        fi
    done
    
    # Initialize variables for JSON building
    local active_llm_key=""      # Will be set from model with DEFAULT=true
    local llms_json="{}"          # Will contain all model configurations
    
    # Iterate through all providers
    for ((i=1; i<=provider_count; i++)); do
        # Extract provider configuration from PARSED_PROVIDERS array
        local provider_id="${PARSED_PROVIDERS[${i}_PROVIDER_ID]}"
        local provider_name="${PARSED_PROVIDERS[${i}_PROVIDER_NAME]}"
        local provider_enabled="${PARSED_PROVIDERS[${i}_ENABLED]}"
        local provider_url="${PARSED_PROVIDERS[${i}_PROVIDER_URL]}"
        local api_key="${PARSED_PROVIDERS[${i}_API_KEY]}"
        local username="${PARSED_PROVIDERS[${i}_USERNAME]}"
        local password="${PARSED_PROVIDERS[${i}_PASSWORD]}"
        local space_id="${PARSED_PROVIDERS[${i}_SPACE_ID]}"
        local project_id="${PARSED_PROVIDERS[${i}_PROJECT_ID]}"
        local ssl_enabled="${PARSED_PROVIDERS[${i}_SSL_ENABLED]}"
        local tls_cert_location="${PARSED_PROVIDERS[${i}_TLS_CERT_LOCATION]}"
        
        # Skip disabled providers (allows temporary disabling without deletion)
        if [[ "$provider_enabled" != "true" ]]; then
            continue
        fi
        
        # Validate authentication credentials based on provider type
        # LWE: Supports both API_KEY (preferred) and PASSWORD
        # SaaS/Azure: Requires API_KEY only
        if [[ "$provider_name" == "watsonx_lightweightengine" ]]; then
            if [[ -n "$api_key" && "$api_key" != "<Required>" ]]; then
                password=""  # Clear password if API_KEY is provided (API_KEY takes precedence)
            elif [[ -n "$password" && "$password" != "<Required>" ]]; then
                api_key=""   # Clear API_KEY if only PASSWORD is provided
            else
                warning "Skipping provider $provider_id: Neither API_KEY nor PASSWORD provided for LWE"
                continue
            fi
        else
            # SaaS and Azure require API_KEY
            if [[ -z "$api_key" || "$api_key" == "<Required>" ]]; then
                warning "Skipping provider $provider_id: API key not provided"
                continue
            fi
        fi
        
        # Count models for this provider by scanning PARSED_MODELS array
        local model_count=0
        for model_key in "${!PARSED_MODELS[@]}"; do
            if [[ "$model_key" =~ ^${i}_([0-9]+)_MODEL_ID$ ]]; then
                model_count=$((model_count + 1))
            fi
        done
        
        # Generate entries for each model using jq
        for ((m=1; m<=model_count; m++)); do
            local model_id="${PARSED_MODELS[${i}_${m}_MODEL_ID]}"
            local model_default="${PARSED_MODELS[${i}_${m}_DEFAULT]}"
            local temperature="${PARSED_MODELS[${i}_${m}_TEMPERATURE]}"
            local max_tokens="${PARSED_MODELS[${i}_${m}_MAX_TOKENS]}"
            local context_window_token_limit="${PARSED_MODELS[${i}_${m}_CONTEXT_WINDOW_TOKEN_LIMIT]}"
            
            # Generate unique key by concatenating provider_id with sanitized model_id
            # Remove special characters (/, -, ., etc.) from model_id for the key
            local sanitized_model_id=$(echo "$model_id" | tr -d '/-.')
            local llm_key="${provider_id}_${sanitized_model_id}"
            
            # Track default model
            if [[ "$model_default" == "true" ]]; then
                active_llm_key="$llm_key"
            fi
            
            # Build model configuration using jq based on provider type
            local model_json=""
            case "$provider_name" in
                azure)
                    model_json=$(jq -n \
                        --arg provider "azure" \
                        --arg endpoint "$provider_url" \
                        --arg model "$model_id" \
                        --arg api_key "$api_key" \
                        --argjson use_entra_id false \
                        --argjson timeout 60 \
                        --arg api_version "2024-12-01-preview" \
                        '{
                            provider: $provider,
                            endpoint: $endpoint,
                            model: $model,
                            api_key: $api_key,
                            use_entra_id: $use_entra_id,
                            timeout: $timeout,
                            api_version: $api_version
                        }' | \
                        if [[ -n "$max_tokens" && "$max_tokens" != "0" ]]; then
                            jq --argjson max_tokens "$max_tokens" '. + {max_completion_tokens: $max_tokens}'
                        else
                            cat
                        fi | \
                        if [[ -n "$temperature" ]]; then
                            jq --argjson temperature "$temperature" '. + {temperature: $temperature}'
                        else
                            cat
                        fi | \
                        if [[ -n "$context_window_token_limit" ]]; then
                            jq --argjson context_window_token_limit "$context_window_token_limit" '. + {context_window_token_limit: $context_window_token_limit}'
                        else
                            cat
                        fi
                    )
                    ;;
                    
                watsonx_saas)
                    model_json=$(jq -n \
                        --arg provider "watsonx" \
                        --arg deployment_mode "saas" \
                        --arg url "$provider_url" \
                        --arg api_key "$api_key" \
                        --arg model "$model_id" \
                        '{
                            provider: $provider,
                            deployment_mode: $deployment_mode,
                            url: $url,
                            api_key: $api_key,
                            model: $model
                        }' | \
                        if [[ -n "$space_id" ]]; then
                            jq --arg space_id "$space_id" '. + {space_id: $space_id}'
                        else
                            cat
                        fi | \
                        if [[ -n "$project_id" ]]; then
                            jq --arg project_id "$project_id" '. + {project_id: $project_id}'
                        else
                            cat
                        fi | \
                        if [[ -n "$max_tokens" ]]; then
                            jq --argjson max_tokens "$max_tokens" '. + {max_completion_tokens: $max_tokens}'
                        else
                            cat
                        fi | \
                        if [[ -n "$temperature" ]]; then
                            jq --argjson temperature "$temperature" '. + {temperature: $temperature}'
                        else
                            cat
                        fi | \
                        if [[ -n "$context_window_token_limit" ]]; then
                            jq --argjson context_window_token_limit "$context_window_token_limit" '. + {context_window_token_limit: $context_window_token_limit}'
                        else
                            cat
                        fi
                    )
                    ;;
                    
                watsonx_lightweightengine)
                    model_json=$(jq -n \
                        --arg provider "watsonx" \
                        --arg deployment_mode "lightweight" \
                        --arg url "$provider_url" \
                        --arg instance_id "openshift" \
                        --arg version "5.3" \
                        --arg model "$model_id" \
                        '{
                            provider: $provider,
                            deployment_mode: $deployment_mode,
                            url: $url,
                            instance_id: $instance_id,
                            version: $version,
                            model: $model
                        }' | \
                        if [[ -n "$username" ]]; then
                            jq --arg username "$username" '. + {username: $username}'
                        else
                            cat
                        fi | \
                        if [[ -n "$api_key" ]]; then
                            jq --arg api_key "$api_key" '. + {api_key: $api_key}'
                        elif [[ -n "$password" ]]; then
                            jq --arg password "$password" '. + {password: $password}'
                        else
                            cat
                        fi | \
                        if [[ "$ssl_enabled" == "true" ]]; then
                            jq --arg verify_ssl "/etc/certs/lwe/tls.crt" \
                               --arg ssl_secret_name "watsonx-lwe-ssl-secret" \
                               '. + {verify_ssl: $verify_ssl, ssl_secret_name: $ssl_secret_name}'
                        else
                            jq --argjson verify_ssl false '. + {verify_ssl: $verify_ssl}'
                        fi | \
                        if [[ -n "$max_tokens" ]]; then
                            jq --argjson max_tokens "$max_tokens" '. + {max_completion_tokens: $max_tokens}'
                        else
                            cat
                        fi | \
                        if [[ -n "$temperature" ]]; then
                            jq --argjson temperature "$temperature" '. + {temperature: $temperature}'
                        else
                            cat
                        fi | \
                        if [[ -n "$context_window_token_limit" ]]; then
                            jq --argjson context_window_token_limit "$context_window_token_limit" '. + {context_window_token_limit: $context_window_token_limit}'
                        else
                            cat
                        fi
                    )
                    ;;
            esac
            
            # Add model to llms object
            llms_json=$(echo "$llms_json" | jq --arg key "$llm_key" --argjson value "$model_json" '. + {($key): $value}')
        done
    done
    
    # Build final JSON with proper structure for Vault
    local json_content=$(jq -n \
        --arg active_llm "$active_llm_key" \
        --argjson llms "$llms_json" \
        '{active_llm: $active_llm, llms: $llms}')
    
    # Convert the JSON to a single-line string with escaped quotes for Vault storage
    local json_content_escaped=$(echo "$json_content" | jq -c . | sed 's/"/\\"/g')
    
    local _config_secret_name="ibm-providers-config-secret"
    
    # Create the Vault JSON template
    cat > "$AI_SERVICES_VAULT_CONFIG_SECRET_FILE" << EOF
{
  "_comment": "Create $_config_secret_name for Vault (eg: vault kv put ${kv_vault_path}/$_config_secret_name @${AI_SERVICES_VAULT_CONFIG_SECRET_FILE}). The name should match the SecretProviderClass name. Optionally, this property, _comment, can be removed before creating the secret. NOTE: Vault stores passwords in plain text.",
  "providers_config.json": "$json_content_escaped"
}
EOF

    # Create the SecretProviderClass YAML
    cat > "${AI_SERVICES_VAULT_CONFIG_SECRET_PROVIDER_CLASS_FILE}.yaml" << EOF
# YAML template for $_config_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_config_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
  annotations:
    cp4ba.ibm.com/owned-by: "ibm-ccx-ai-services-operator"
    cp4ba.ibm.com/secret-store-type: "secrets"
spec:
  provider: vault
  parameters:
    roleName: "$vault_role"
    vaultAddress: "$vault_address"
    objects: |
      - secretPath: "$vault_path/$_config_secret_name"
        objectName: "providers_config.json"
        secretKey: "providers_config.json"
EOF

    if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
      info "Creating SecretProviderClass for multi-provider config in namespace $CP4BA_OPERATOR_NS"
      cp "${AI_SERVICES_VAULT_CONFIG_SECRET_PROVIDER_CLASS_FILE}.yaml" "${AI_SERVICES_VAULT_CONFIG_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
      ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${AI_SERVICES_VAULT_CONFIG_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
    fi

    success "Created multi-provider config secret JSON template for Vault\n"
}

