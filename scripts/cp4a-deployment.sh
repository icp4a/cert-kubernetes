#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2024. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh

# Import variables for property file
source ${CUR_DIR}/helper/cp4ba-property.sh

DOCKER_RES_SECRET_NAME="ibm-entitlement-key"
DOCKER_REG_USER=""
SCRIPT_MODE=$1

if [[ "$SCRIPT_MODE" == "baw-dev" || "$SCRIPT_MODE" == "dev" || "$SCRIPT_MODE" == "review" ]] # During dev, OLM uses stage image repo
then
    DOCKER_REG_SERVER="cp.stg.icr.io"
    if [[ -z $2 ]]; then
        IMAGE_TAG_DEV="${CP4BA_RELEASE_BASE}"
    else
        IMAGE_TAG_DEV=$2
    fi
    IMAGE_TAG_FINAL="${CP4BA_RELEASE_BASE}"
else
    DOCKER_REG_SERVER="cp.icr.io"
fi
DOCKER_REG_KEY=""
REGISTRY_IN_FILE="cp.icr.io"
# OPERATOR_IMAGE=${DOCKER_REG_SERVER}/cp/cp4a/icp4a-operator:21.0.2

old_db2="docker.io\/ibmcom"
old_db2_alpine="docker.io\/alpine"
old_ldap="docker.io\/osixia"
old_db2_etcd="quay.io\/coreos"
old_busybox="docker.io\/library"

TEMP_FOLDER=${CUR_DIR}/.tmp
BAK_FOLDER=${CUR_DIR}/.bak
FINAL_CR_FOLDER=${CUR_DIR}/generated-cr

DEPLOY_TYPE_IN_FILE_NAME="" # Default value is empty
OPERATOR_FILE=${PARENT_DIR}/descriptors/operator.yaml
OPERATOR_FILE_TMP=$TEMP_FOLDER/.operator_tmp.yaml
OPERATOR_FILE_BAK=$BAK_FOLDER/.operator.yaml

# PREREQUISITES_FOLDER=${CUR_DIR}/cp4ba-prerequisites
# PROPERTY_FILE_FOLDER=${PREREQUISITES_FOLDER}/propertyfile
# TEMPORARY_PROPERTY_FILE=${TEMP_FOLDER}/.TEMPORARY.property
# LDAP_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_LDAP.property
# EXTERNAL_LDAP_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_External_LDAP.property

# DB_NAME_USER_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_db_name_user.property
# DB_SERVER_INFO_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_db_server.property


# OPERATOR_PVC_FILE=${PARENT_DIR}/descriptors/operator-shared-pvc.yaml
# OPERATOR_PVC_FILE_TMP1=$TEMP_FOLDER/.operator-shared-pvc_tmp1.yaml
# OPERATOR_PVC_FILE_TMP=$TEMP_FOLDER/.operator-shared-pvc_tmp.yaml
# OPERATOR_PVC_FILE_BAK=$BAK_FOLDER/.operator-shared-pvc.yaml


CP4A_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_final_tmp.yaml
CP4A_PATTERN_FILE_BAK=$FINAL_CR_FOLDER/ibm_cp4a_cr_final.yaml
FNCM_SEPARATE_PATTERN_FILE_BAK=$FINAL_CR_FOLDER/ibm_content_cr_final.yaml
CP4A_EXISTING_BAK=$TEMP_FOLDER/.ibm_cp4a_cr_final_existing_bak.yaml
CP4A_EXISTING_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_final_existing_tmp.yaml

JDBC_DRIVER_DIR=${CUR_DIR}/jdbc
SAP_LIB_DIR=${CUR_DIR}/saplibs
ACA_MODEL_FILES_DIR=../ACA/configuration-ha/
PLATFORM_SELECTED=""
PATTERN_SELECTED=""
COMPONENTS_SELECTED=""
OPT_COMPONENTS_CR_SELECTED=""
OPT_COMPONENTS_SELECTED=()
LDAP_TYPE=""
TARGET_PROJECT_NAME=""
CP4BA_JDBC_URL=""

FOUNDATION_CR_SELECTED=""
optional_component_arr=()
optional_component_cr_arr=()
foundation_component_arr=()
FOUNDATION_FULL_ARR=("BAN" "RR" "BAS" "UMS" "AE")
OPTIONAL_COMPONENT_FULL_ARR=("content_integration" "workstreams" "case" "ban" "bai" "css" "cmis" "es" "ier" "iccsap" "tm" "ums" "ads_designer" "ads_runtime" "app_designer" "decisionCenter" "decisionServerRuntime" "decisionRunner" "ae_data_persistence" "baw_authoring" "pfs" "baml" "auto_service" "document_processing_runtime" "document_processing_designer" "wfps_authoring" "kafka" "opensearch")

## VARIABLES TO CHECK IF CPE IS
## CONFIGURED WITH SCIM
CPE_SERVICE_NAME="cpe-stateless-svc"
CPE_SERVICE_PORT="9443"
RUNNABLE_JAR_NAME="cp4ba-scim-upgrade.jar"
CLASS_PATH="/tmp/Jace.jar;/opt/ibm/content_emitter/stax-api.jar;/opt/ibm/content_emitter/xlxpScanner.jar;/opt/ibm/content_emitter/xlxpScannerUtils.jar"
## PODS LABELS
CONTENT_OPERATOR_LABEL="name=ibm-content-operator"
CP4A_OPERATOR_LABEL="name=ibm-cp4a-operator"
CPE_LABEL="cpe-deploy"
## Jar files section
JACE_NAME="Jace.jar"
STAX_NAME="stax-api.jar"
SCANNER_NAME="xlxpScanner.jar"
SCANNER_UTILS_NAME="xlxpScannerUtils.jar"
## Truststore names
TRUSTSTORE_NAME="ibm_customFNCMTrustStore.p12"
POST_UPGRADE_TRUSTSTORE_NAME="trusts.p12"
## paths to files
JACE_PATH="/opt/ibm/wlp/usr/servers/defaultServer/jaceLib/${JACE_NAME}"
STAX_PATH="/opt/ibm/content_emitter/${STAX_NAME}"
SCANNER_PATH="/opt/ibm/content_emitter/${SCANNER_NAME}"
SCANNER_UTILS_PATH="/opt/ibm/content_emitter/${SCANNER_UTILS_NAME}"
CPE_TRUSTSTORE_PATH="/opt/ibm/wlp/usr/servers/defaultServer/resources/security/${TRUSTSTORE_NAME}"
POST_UPGRADE_CPE_TRUSTSTORE_PATH="/shared/tls/truststore/pkcs12/${POST_UPGRADE_TRUSTSTORE_NAME}"

function prompt_license(){
    clear

    get_baw_mode
    retVal_baw=$?
    if [[ $retVal_baw -eq 1 ]]; then
        echo -e "\x1B[1;31mIMPORTANT: Review the IBM Cloud Pak for Business Automation license information here: \n\x1B[0m"
        echo -e "\x1B[1;31mhttps://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-FNHF-F9RU7N\n\x1B[0m"
        INSTALL_BAW_ONLY="No"
    fi

    read -rsn1 -p"Press any key to continue";echo

    printf "\n"
    while true; do
        if [[ $retVal_baw -eq 1 ]]; then
            printf "\x1B[1mDo you accept the IBM Cloud Pak for Business Automation license (Yes/No, default: No): \x1B[0m"
        fi
        if  [[ $CP4BA_LICENSE_ACCEPT == "Accept" || $CP4BA_LICENSE_ACCEPT == "accept" || $CP4BA_LICENSE_ACCEPT == "ACCEPT"   ]]; then
            ans='Yes'
            IBM_LICENS='Accept'
        else
            read -rp "" ans
        fi
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
                printf "\n"
                while true; do
                    if [[ $retVal_baw -eq 0 ]]; then
                        printf "\n"
                    fi
                    if [[ $retVal_baw -eq 1 ]]; then
                        printf "\x1B[1mDid you deploy Content CR (CRD: contents.icp4a.ibm.com) in current cluster? (Yes/No, default: No): \x1B[0m"
                    fi
                    if  [[ $CONTENT_CR_EXISTS == "" ]]; then
                        read -rp "" ans
                    else
                        ans=$CONTENT_CR_EXISTS
                    fi
                    case "$ans" in
                    "y"|"Y"|"yes"|"Yes"|"YES")
                        echo -e "Continuing...\n"
                        # echo -e "\x1B[1;31mThe cp4a-deployment.sh can not work with existing Content CR together, exiting now...\x1B[0m\n"
                        CONTENT_DEPLOYED="Yes"
                        break
                        ;;
                    "n"|"N"|"no"|"No"|"NO"|"")
                        echo -e "Continuing...\n"
                        CONTENT_DEPLOYED="No"
                        break
                        ;;
                    *)
                        echo -e "Answer must be \"Yes\" or \"No\"\n"
                        ;;
                    esac
                done
            echo -e "Starting to Install the Cloud Pak for Business Automation Operator...\n"
            IBM_LICENS="Accept"
            validate_cli
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            echo -e "Exiting...\n"
            exit 0
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function create_configmap_os_migration(){
    # info "Creating ibm-cp4ba-os-migration-status configMap for this CP4BA deployment in the project \"$TARGET_PROJECT_NAME\"."

    mkdir -p ${TEMP_FOLDER} >/dev/null 2>&1
cat << EOF > ${TEMP_FOLDER}/ibm-cp4ba-os-migration-status-configmap.yaml
# YAML template for ibm-cp4ba-os-migration-status
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: ibm-cp4ba-os-migration-status
  namespace: "$TARGET_PROJECT_NAME"
data:
  opensearch_migration_done: "$MIGRATE_ES_TO_OS_DONE"
EOF
    ${CLI_CMD} delete -f ${TEMP_FOLDER}/ibm-cp4ba-os-migration-status-configmap.yaml >/dev/null 2>&1
    ${CLI_CMD} apply -f ${TEMP_FOLDER}/ibm-cp4ba-os-migration-status-configmap.yaml >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        # success "Created ibm-cp4ba-os-migration-status configMap for this CP4BA deployment in the project \"$TARGET_PROJECT_NAME\"."
        sleep 1
    else
        warning "Failed to create ibm-cp4ba-os-migration-status configMap for this CP4BA deployment in the project \"$TARGET_PROJECT_NAME\"!"
        exit 1
    fi
}

function show_tips_es_to_os_migration(){
    which jq &>/dev/null
    [[ $? -ne 0 ]] && \
    echo -e  "\x1B[1;31mUnable to locate jq CLI. You must install it to run this migration script.\x1B[0m"

    # For step1
    ELASTICSEARCH_CR_NAME=$(${CLI_CMD} get elasticsearch.elastic.automation.ibm.com -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found -o name)
    if [[ ! -z $ELASTICSEARCH_CR_NAME  ]]; then
        ELASTICSEARCH_CR_NAME=$(echo $ELASTICSEARCH_CR_NAME | cut -d'/' -f2)
        ELASTICSEARCH_URL=$(${CLI_CMD} get route ${ELASTICSEARCH_CR_NAME}-es -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found -o jsonpath='{.spec.host}')
        ELASTIC_PASSWORD=$(${CLI_CMD} get secret ${ELASTICSEARCH_CR_NAME}-elasticsearch-es-default-user -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found -o jsonpath='{.data.password}' | base64 -d)
        OPENSEARCH_URL=$(${CLI_CMD} get route opensearch-route -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found -o jsonpath='{.spec.host}')
        OPENSEARCH_PASSWORD=$(${CLI_CMD} get secret opensearch-ibm-elasticsearch-cred-secret -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found -o jsonpath='{.data.elastic}' | base64 -d)
    else
        fail "Not found Elasticsearch custom resource in the project \"$TARGET_PROJECT_NAME\"."
    fi
    printf "\n"
    echo -e "\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mYou need to complete migration from Elasticsearch to Opensearch first before upgrade CP4BA.\n\x1B[0m"
    echo "${YELLOW_TEXT}* How to do migration from Elasticsearch to Opensearch${RESET_TEXT}"
    # For step1
    printf "\n"
    echo "  ${YELLOW_TEXT}- STEP 1 (Optional)${RESET_TEXT}: Run pre-migration"
    echo "    For high volume data you can reduce Business Automation Insights downtime by running pre-migration. This step must be executed following instructions documented in Knowledge Center: \"Preparing to migrate Elasticsearch to OpenSearch\" topic:"
    echo "    - if upgrading from 21.0.3: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=2103-preparing-migrate-elasticsearch-opensearch]"
    echo "    - if upgrading from 23.0.2: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=2302-preparing-migrate-elasticsearch-opensearch]"

    echo "    ${YELLOW_TEXT}GOAL${RESET_TEXT}: To migrate those immutable indices first in order to reduce downtime. If you want to migrate all data at one time while downtime, you could bypass this step."
    echo "    ${YELLOW_TEXT}* Before execute the migration script, run the prerequesties to export varaiables in your terminal${RESET_TEXT}"
    echo "      execute commands:"
    echo -e '\033[0;32m      # export ELASTICSEARCH_URL=https://'"${ELASTICSEARCH_URL}"':443\033[0m'
    echo -e '\033[0;32m      # export ELASTIC_USERNAME="elasticsearch-admin"\033[0m'
    echo -e '\033[0;32m      # export ELASTIC_PASSWORD=$('"${CLI_CMD}"' get secret iaf-system-elasticsearch-es-default-user -n '"$TARGET_PROJECT_NAME"' --no-headers --ignore-not-found -o jsonpath='{.data.password}' | base64 -d)\033[0m'
    echo -e '\033[0;32m      # export OPENSEARCH_URL=https://'"${OPENSEARCH_URL}"'\033[0m'
    echo -e '\033[0;32m      # export OPENSEARCH_USERNAME="elastic"\033[0m'
    echo -e '\033[0;32m      # export OPENSEARCH_PASSWORD=$('"${CLI_CMD}"' get secret opensearch-ibm-elasticsearch-cred-secret -n '"$TARGET_PROJECT_NAME"' --no-headers --ignore-not-found -o jsonpath='{.data.elastic}' | base64 -d)\033[0m'
    echo "    ${YELLOW_TEXT}* Migration script Usage:${RESET_TEXT}"
    echo "      For more information, please refer to Knowledge Center: \"Migrating from Elasticsearch to OpenSearch\" topic:"
    echo "      - if upgrading from 21.0.3: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=2103-migrating-from-elasticsearch-opensearch]"
    echo "      - if upgrading from 23.0.2: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=2302-migrating-from-elasticsearch-opensearch]"
    echo "      execute commands:"
    echo "      ${GREEN_TEXT}# $OPENSEARCH_MIGRATION_SCRIPT${RESET_TEXT} [-dryrun] [-doc_count] [-include=<comma separated indices>] [-exclude=<comma separated indices>] [-include_regex=<comma separated regex patterns>] [-exclude_regex=<comma separated regex patterns>] [-startdate=<start date>] [-enddate=<end date>] [-timestamp_key=<date field key>] [-delete] [logfile] [--help]"
    echo "      Options:"
    echo "        -dryrun                              List of indices of elastic and displaying dry run steps"
    echo "        -doc_count                           List all indices of elastic and opensearch with document count, and exit."
    echo "        -include=<comma separated indices>   List of indices to include"
    echo "        -exclude=<comma separated indices>   List of indices to exclude"
    echo "        -include_regex=<regex pattern>       List of regex pattern to include indices"
    echo "        -exclude_regex=<regex pattern>       List of regex pattern to exclude indices"
    echo "        -startdate=<start date>              Start date for data migration (format: 'YYYY-MM-DDTHH:MM:SS')"
    echo "        -enddate=<end date>                  End date for data migration (format: 'YYYY-MM-DDTHH:MM:SS')"
    echo "        -timestamp_key=<key>                 Key for date values (default: 'timestamp')"
    echo "        -delete                              delete Opensearch indices"
    echo "        logfile                              Optional: Log file to save migration summary"
    echo "        --help                               Display usage details"
    echo "    ${YELLOW_TEXT}* Sample execute commands:${RESET_TEXT}"
    echo "      - To migrate only included indices data which is speicified in include option"
    echo "        execute commands:"
    echo "        ${GREEN_TEXT}# $OPENSEARCH_MIGRATION_SCRIPT -include=iaf_elastic_index_mapping,test_iaf_elastic_index_mapping${RESET_TEXT}"
    echo "      - To migrate all indices based on the date range"
    echo "        execute commands:"
    echo "        ${GREEN_TEXT}# $OPENSEARCH_MIGRATION_SCRIPT -startdate=\"2023-01-28T12:00:00\" -enddate=\"2024-02-07T00:00:00\"${RESET_TEXT}"
    echo "      - To migrate all PFS indices"
    echo "        execute commands:"
    echo "        ${GREEN_TEXT}# $OPENSEARCH_MIGRATION_SCRIPT -include_regex=ibm-pfs@*${RESET_TEXT}"
    echo "      - To migrate PFS index one by one"
    echo "        execute commands:"
    echo "        ${GREEN_TEXT}# $OPENSEARCH_MIGRATION_SCRIPT -include=icp4ba-pfs@94c01f27-716f-4289-92b9-f596b540cdc6${RESET_TEXT}"

    # For step2
    step_num=2
    if [[ ( $CONTENT_CR_EXIST="Yes" || " ${EXISTING_PATTERN_ARR[@]}" =~ "workflow-runtime" || " ${EXISTING_PATTERN_ARR[@]}" =~ "workflow-authoring" || " ${EXISTING_PATTERN_ARR[@]}" =~ "workstreams" || " ${EXISTING_PATTERN_ARR[@]}" =~ "content" || " ${EXISTING_PATTERN_ARR[@]}" =~ "document_processing" || "${EXISTING_OPT_COMPONENT_ARR[@]}" =~ "ae_data_persistence") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai" || $bai_flag == "true") ]]; then
        printf "\n"
        echo "  ${YELLOW_TEXT}- STEP ${step_num} (Required)${RESET_TEXT}: Stop Content emitter if Content capabilty is installed in this CP4BA deployment and \"oc_cpe_obj_store_enable_content_event_emitter\" is \"true\" under in initialize_configuration section in the custom resource for any object store."
        echo "    ${YELLOW_TEXT}* Before starting to upgrade the Cloud Pak, disable the Content Event Emitter if it is configured on an object store for Content Platform Engine.${RESET_TEXT}"
        echo "      1. Log in to the Administration Console for Content Platform Engine."
        echo "      2. Go to Object Stores > object store name > Events, Actions, Processes > Subscriptions."
        echo "      3. Click ContentEventEmitterSubscription or the name of the existing subscription used by the Content event emitter."
        echo "      4. Click the Properties tab."
        echo "      5. For the row with the Property Name of Is Enabled, click the Property Value dropdown and select False."
        echo "      6. Click Save."
        step_num=$((step_num + 1))
    fi

    # For step3
    if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") || $bai_flag == "true" ]]; then
        printf "\n"
        echo "  ${YELLOW_TEXT}- STEP ${step_num} (Required)${RESET_TEXT}: Create Flink savepoints and stop Flink jobs.${RED_TEXT}(NOTES: ONE-TIME OPERATION, THE COMMAND WILL RETURN NOTHING IF REPEAT RUN)${RESET_TEXT}"
        step_num=$((step_num + 1))
        ${CLI_CMD} get crd |grep insightsengines.icp4a.ibm.com >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            INSIGHTS_ENGINE_CR=$(${CLI_CMD} get insightsengines.icp4a.ibm.com --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o name)
        fi
        if [[ -z $INSIGHTS_ENGINE_CR ]]; then
            INSIGHTS_ENGINE_CR=$(${CLI_CMD} get insightsengines.insightsengine.automation.ibm.com --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o name)
            if [[ -z $INSIGHTS_ENGINE_CR ]]; then
                error "Not found insightsengines custom resource instance in the project \"${TARGET_PROJECT_NAME}\"."
            fi
            # exit 1
        fi
        if [[ ! -z $INSIGHTS_ENGINE_CR ]]; then
            MANAGEMENT_URL=$(${CLI_CMD} get ${INSIGHTS_ENGINE_CR} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].uri}')
            MANAGEMENT_AUTH_SECRET=$(${CLI_CMD} get ${INSIGHTS_ENGINE_CR} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].authentication.secret.secretName}')
            MANAGEMENT_USERNAME=$(${CLI_CMD} get secret ${MANAGEMENT_AUTH_SECRET} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.data.username}' | base64 -d)
            MANAGEMENT_PASSWORD=$(${CLI_CMD} get secret ${MANAGEMENT_AUTH_SECRET} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.data.password}' | base64 -d)
            if [[ -z "$MANAGEMENT_URL" || -z "$MANAGEMENT_AUTH_SECRET" || -z "$MANAGEMENT_USERNAME" || -z "$MANAGEMENT_PASSWORD" ]]; then
                error "Can not create the BAI savepoints for recovery path."
                # exit 1
            else
                if [[ -e ${UPGRADE_DEPLOYMENT_CR}/bai.json ]]; then
                    [ "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" != "[]" ] && mkdir -p ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup && cp ${UPGRADE_DEPLOYMENT_CR}/bai.json ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup/bai_$(date +'%Y%m%d%H%M%S').json
                fi
                # touch ${UPGRADE_DEPLOYMENT_BAI_TMP} >/dev/null 2>&1
                echo "    ${YELLOW_TEXT}* Create Flink savepoint and stop Flink job at the same time${RESET_TEXT}"
                echo "      execute commands:"
                # echo "      ${GREEN_TEXT}# curl -X POST -k -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} \"${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints?cancel-job=true\" -o ${UPGRADE_DEPLOYMENT_CR}/bai.json >/dev/null 2>&1 && cat ${UPGRADE_DEPLOYMENT_CR}/bai.json && echo ${RESET_TEXT}"
                echo -e '\033[0;32m      '"${GREEN_TEXT}"'# curl -X POST -k -u '"${MANAGEMENT_USERNAME}"':'"${MANAGEMENT_PASSWORD}"' "'"${MANAGEMENT_URL}"'/api/v1/processing/jobs/savepoints?cancel-job=true" -o /tmp/tmp_bai.json && [ "$(cat /tmp/tmp_bai.json)" != "[]" ] && '"${COPY_CMD}"' -rf /tmp/tmp_bai.json '"${UPGRADE_DEPLOYMENT_CR}"'/bai.json || rm -rf /tmp/tmp_bai.json\033[0m'
            fi
        fi

        bpc_deployment_name=$(${CLI_CMD} get deployment --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME  -o name | grep insights-engine-cockpit)
        if [[ ! -z $bpc_deployment_name ]]; then
            printf "\n"
            echo "  ${YELLOW_TEXT}- STEP ${step_num} (Required)${RESET_TEXT}: Scale down Business Performance Center (BPC) to ensure the prevention of dirty data generation while migration${RESET_TEXT}"
            echo "    execute commands:"
            bai_operator_name=$(${CLI_CMD} get deployment --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME  -o name | grep insights-engine-operator-controller-manager)
            if [[ ! -z $bai_operator_name ]]; then
                echo -e '\033[0;32m    '"${GREEN_TEXT}"'# '"${CLI_CMD}"' scale --replicas=0 '"${bai_operator_name}"' -n '"${TARGET_PROJECT_NAME}"'\033[0m'
            fi
            bai_operator_name=$(${CLI_CMD} get deployment --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME  -o name | grep ibm-insights-engine-operator)
            if [[ ! -z $bai_operator_name ]]; then
                echo -e '\033[0;32m    '"${GREEN_TEXT}"'# '"${CLI_CMD}"' scale --replicas=0 '"${bai_operator_name}"' -n '"${TARGET_PROJECT_NAME}"'\033[0m'
            fi

            echo -e '\033[0;32m    '"${GREEN_TEXT}"'# '"${CLI_CMD}"' scale --replicas=0 '"${bpc_deployment_name}"' -n '"${TARGET_PROJECT_NAME}"'\033[0m'
            step_num=$((step_num + 1))
        fi
    fi

    # For step4
    printf "\n"
    echo "  ${YELLOW_TEXT}- STEP ${step_num} (Required)${RESET_TEXT}: Run migration script ${RED_TEXT}(WARNING: if pre-migration [STEP 1] has been run, STEP ${step_num} must be executed following instructions in Knowledge Center: \"Migrating from Elasticsearch to OpenSearch\" topic:"
    echo "    - if upgrading from 21.0.3: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=2103-migrating-from-elasticsearch-opensearch]"
    echo "    - if upgrading from 23.0.2: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=2302-migrating-from-elasticsearch-opensearch])${RESET_TEXT}"
    step_num=$((step_num + 1))
    echo "    ${YELLOW_TEXT}GOAL${RESET_TEXT}: To migrate all data from Elasticsearch to Opensearch as soon as possible during downtime before upgrade CP4BA deployment."
    echo "    ${YELLOW_TEXT}* Before execute the migration script, run the prerequesties to export varaiables in your terminal${RESET_TEXT}"
    echo "      execute commands:"
    echo -e '\033[0;32m      # export ELASTICSEARCH_URL=https://'"${ELASTICSEARCH_URL}"':443\033[0m'
    echo -e '\033[0;32m      # export ELASTIC_USERNAME="elasticsearch-admin"\033[0m'
    echo -e '\033[0;32m      # export ELASTIC_PASSWORD=$('"${CLI_CMD}"' get secret iaf-system-elasticsearch-es-default-user -n '"$TARGET_PROJECT_NAME"' --no-headers --ignore-not-found -o jsonpath='{.data.password}' | base64 -d)\033[0m'
    echo -e '\033[0;32m      # export OPENSEARCH_URL=https://'"${OPENSEARCH_URL}"'\033[0m'
    echo -e '\033[0;32m      # export OPENSEARCH_USERNAME="elastic"\033[0m'
    echo -e '\033[0;32m      # export OPENSEARCH_PASSWORD=$('"${CLI_CMD}"' get secret opensearch-ibm-elasticsearch-cred-secret -n '"$TARGET_PROJECT_NAME"' --no-headers --ignore-not-found -o jsonpath='{.data.elastic}' | base64 -d)\033[0m'
    echo "    ${YELLOW_TEXT}* Run the following command to migrate all the indexes, except the indexes related to Process Federation Server (if any) which must not be migrated with the migration script.${RESET_TEXT}"
    echo "      execute commands:"
    echo "      ${GREEN_TEXT}# $OPENSEARCH_MIGRATION_SCRIPT -exclude_regex=icp4ba-pfs@*${RESET_TEXT}"
    echo "    ${YELLOW_TEXT}* If your Cloud Pak for Business Automation includes IBM Process Federation Server or if your Cloud Pak for Business Automation includes at least a Business Automation Workflow or Workflow Process Service instance which has full text search enabled, run the following command to migrate IBM Process Federation Server saved searches indexes from Elasticsearch to OpenSearch.${RESET_TEXT}"
    echo "      execute commands:"
    echo "      ${GREEN_TEXT}# $OPENSEARCH_MIGRATION_SCRIPT -include_regex=ibmpfssavedsearches*${RESET_TEXT}"

    # For step5
    printf "\n"
    echo "  ${YELLOW_TEXT}- STEP ${step_num} (Required)${RESET_TEXT}: Verify all data migration done."
    step_num=$((step_num + 1))
    echo "    ${YELLOW_TEXT}* Before execute verification, run the prerequesties to export varaiables in your terminal${RESET_TEXT}"
    echo "      execute commands:"
    echo -e '\033[0;32m      # export ELASTICSEARCH_URL=https://'"${ELASTICSEARCH_URL}"':443\033[0m'
    echo -e '\033[0;32m      # export ELASTIC_USERNAME="elasticsearch-admin"\033[0m'
    echo -e '\033[0;32m      # export ELASTIC_PASSWORD=$('"${CLI_CMD}"' get secret iaf-system-elasticsearch-es-default-user -n '"$TARGET_PROJECT_NAME"' --no-headers --ignore-not-found -o jsonpath='{.data.password}' | base64 -d)\033[0m'
    echo -e '\033[0;32m      # export OPENSEARCH_URL=https://'"${OPENSEARCH_URL}"'\033[0m'
    echo -e '\033[0;32m      # export OPENSEARCH_USERNAME="elastic"\033[0m'
    echo -e '\033[0;32m      # export OPENSEARCH_PASSWORD=$('"${CLI_CMD}"' get secret opensearch-ibm-elasticsearch-cred-secret -n '"$TARGET_PROJECT_NAME"' --no-headers --ignore-not-found -o jsonpath='{.data.elastic}' | base64 -d)\033[0m'
    echo "    ${YELLOW_TEXT}* To list the indices in Elasticsearch${RESET_TEXT}"
    echo "      execute commands:"
    echo -e '\033[0;32m      # curl -X GET -u ${ELASTIC_USERNAME}:${ELASTIC_PASSWORD} --insecure "${ELASTICSEARCH_URL}/_cat/indices?v&s=docs.count:desc,index"\033[0m'
    echo "    ${YELLOW_TEXT}* To list the indices in OpenSearch${RESET_TEXT}"
    echo "      execute commands:"
    echo -e '\033[0;32m      # curl -X GET -u ${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD} --insecure "${OPENSEARCH_URL}/_cat/indices?v&s=docs.count:desc,index"\033[0m'
    echo "    ${YELLOW_TEXT}* To compare above two outputs and check whether any missing indice between Elasticsearch and OpenSearch.${RESET_TEXT}"
    # For step6
    printf "\n"
    echo "  ${YELLOW_TEXT}- STEP ${step_num} (Required)${RESET_TEXT}: Upgrade CP4BA operators."
    echo "    execute commands:"
    echo "    ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME${RESET_TEXT}"
}

function select_private_catalog_cp4ba(){
    printf "\n"
    echo "${YELLOW_TEXT}[NOTES] You can switch the CP4BA deployment as a private catalog (namespace scope) or keep the global catalog namespace (GCN). The private catalog (recommended) uses the same target namespace of the CP4BA deployment, the GCN uses the openshift-marketplace namespace.${RESET_TEXT}"

    while true; do
        printf "\x1B[1mDo you want to switch CP4BA deployment using private catalog? (Yes/No, default: Yes): \x1B[0m"
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
                info "Found this CP4BA operator is in All namespace, CAN NOT to use private catalog (namespace-scoped), keep to use global catalog namespace (GCN)."
                ENABLE_PRIVATE_CATALOG=0
            else
                ENABLE_PRIVATE_CATALOG=1
            fi
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            ENABLE_PRIVATE_CATALOG=0
            break
            ;;
        *)
            PRIVATE_CATALOG=""
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function select_private_catalog_opensearch(){
    printf "\n"
    echo "${YELLOW_TEXT}[NOTES] You can install the Opensearch as either a private catalog (namespace-scoped) or the global catalog namespace (GCN). The private option uses the same target namespace of the CP4BA deployment, the GCN uses the openshift-marketplace namespace.${RESET_TEXT}"
    while true; do
        printf "\x1B[1mDo you want to deploy Opensearch using private catalog?\x1B[0m (Yes/No, default: Yes): "
        read -rp "" ans

        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
                info "Found this CP4BA operator is in All namespace, CAN NOT to use private catalog (namespace-scoped), keep to use global catalog namespace (GCN)."
                ENABLE_PRIVATE_CATALOG=0
                sleep 3
            else
                ENABLE_PRIVATE_CATALOG=1
            fi
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            ENABLE_PRIVATE_CATALOG=0
            break
            ;;
        *)
            PRIVATE_CATALOG=""
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function setup_opensearch_catalog(){
# Create catalog source for Opensearch
    info "Creating ibm-cs-opensearch-catalog CatalogSource for Opensearch in the project \"$OPENSEARCH_CATALOG_NS\"."
    OLM_CATALOG=${PARENT_DIR}/descriptors/op-olm/catalog_source.yaml
    local LINE_NUM=$(grep -E '^  image: icr\.io/cpopen/opencontent-elasticsearch-operator-catalog@sha256:[0-9a-f]+' $OLM_CATALOG)
    local CURRENT_DIGEST=$(echo $LINE_NUM | sed -E 's/^.*@sha256:([0-9a-f]+).*$/\1/')

cat << EOF > ${TEMP_FOLDER}/ibm-cp4ba-os-catalog-source.yaml
# IBM CS Opensearch Operator Catalog 1.1.2131
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-cs-opensearch-catalog
  namespace: "${OPENSEARCH_CATALOG_NS}"
spec:
  displayName: IBM CS Opencontent Opensearch Catalog
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/opencontent-elasticsearch-operator-catalog@sha256:${CURRENT_DIGEST}
  updateStrategy:
    registryPoll:
      interval: 45m
  priority: 100
EOF
    # ${CLI_CMD} delete -f ${TEMP_FOLDER}/ibm-cp4ba-os-catalog-source.yaml >/dev/null 2>&1
    ${CLI_CMD} apply -f ${TEMP_FOLDER}/ibm-cp4ba-os-catalog-source.yaml >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        success "Created ibm-cs-opensearch-catalog CatalogSource for Opensearch in the project \"$OPENSEARCH_CATALOG_NS\"."
        sleep 3
    else
        warning "Failed to create ibm-cs-opensearch-catalog CatalogSource for Opensearch in the project \"$OPENSEARCH_CATALOG_NS\"!"
        exit 1
    fi

    info "Checking Opensearch operator catalog pod ready or not in the project \"$OPENSEARCH_CATALOG_NS\""
    maxRetry=10
    for ((retry=0;retry<=${maxRetry};retry++)); do
        opensearch_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-cs-opensearch-catalog -n $OPENSEARCH_CATALOG_NS -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')

        if [[  -z $opensearch_catalog_pod_name ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                if [[ -z $opensearch_catalog_pod_name ]]; then
                    warning "Timeout waiting for ibm-cs-opensearch-catalog catalog pod to be ready in the project \"$OPENSEARCH_CATALOG_NS\""
                 fi
                exit 1
            else
                sleep 30
                echo -n "..."
                continue
            fi
        else
            success "Opensearch operator catalog pod to be ready in the project \"$OPENSEARCH_CATALOG_NS\"!"
            break
        fi
    done
}

function setup_opensearch_subscription(){
    local operator_project_name=$1
    operator_project_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$operator_project_name")
# Create Opensearch subscription
    info "Creating ibm-elasticsearch-operator Subscription for Opensearch in the project \"$operator_project_name\"."

cat << EOF > ${TEMP_FOLDER}/ibm-cp4ba-os-subscription.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  annotations:
    $operator_project_name.common-service/config: "true"
    $operator_project_name.common-service/registry: "true"
    $operator_project_name.opensearch-request.ibm-elasticsearch-operator/operatorNamespace: $operator_project_name
    $operator_project_name.opensearch-request.ibm-elasticsearch-operator/request: v1.1
  labels:
    operator.ibm.com/opreq-control: "true"
    operators.coreos.com/ibm-elasticsearch-operator.$operator_project_name: ""
  name: ibm-elasticsearch-operator
  namespace: "$operator_project_name"
spec:
  channel: v1.1
  installPlanApproval: Automatic
  name: ibm-elasticsearch-operator
  source: ibm-cs-opensearch-catalog
  sourceNamespace: "$OPENSEARCH_CATALOG_NS"
EOF
    # ${CLI_CMD} delete -f ${TEMP_FOLDER}/ibm-cp4ba-os-subscription.yaml >/dev/null 2>&1
    ${CLI_CMD} apply -f ${TEMP_FOLDER}/ibm-cp4ba-os-subscription.yaml >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        success "Created ibm-elasticsearch-operator Subscription for Opensearch in the project \"$operator_project_name\"."
        sleep 3
    else
        warning "Failed to create ibm-elasticsearch-operator Subscription for Opensearch in the project \"$operator_project_name\"!"
        exit 1
    fi


    info "Checking Opensearch operator pod ready or not in the project \"$operator_project_name\""
    maxRetry=50
    for ((retry=0;retry<=${maxRetry};retry++)); do
        opensearch_pod_name=$(${CLI_CMD} get pod -l=name=ibm-cloudpakopen-elasticsearch-operator -n $operator_project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')

        if [[  -z $opensearch_pod_name ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                if [[ -z $opensearch_pod_name ]]; then
                    warning "Timeout waiting for Opensearch operator pod to be ready in the project \"$operator_project_name\""
                 fi
                exit 1
            else
                sleep 30
                echo -n "..."
                continue
            fi
        else
            success "Opensearch operator pod to be ready in the project \"$operator_project_name\"!"
            msg "Pod: $opensearch_pod_name"
            break
        fi
    done
}

function setup_opensearch_issuer(){
# Create Issuer for Opensearch
    info "Creating opensearch-tls-issuer Issuer for Opensearch in the project \"$TARGET_PROJECT_NAME\"."
    if [[ -z $cp4ba_root_ca_secret_name || $cp4ba_root_ca_secret_name == *"meta.name"* ]]; then
        cp4ba_root_ca_secret_name="${cp4ba_cr_metaname}-root-ca"
    fi

cat << EOF > ${TEMP_FOLDER}/ibm-cp4ba-os-issuer.yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: opensearch-tls-issuer
  namespace: "$TARGET_PROJECT_NAME"
spec:
  ca:
    secretName: $cp4ba_root_ca_secret_name
EOF
    # ${CLI_CMD} delete -f ${TEMP_FOLDER}/ibm-cp4ba-os-issuer.yaml >/dev/null 2>&1
    ${CLI_CMD} apply -f ${TEMP_FOLDER}/ibm-cp4ba-os-issuer.yaml >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        success "Created opensearch-tls-issuer Issuer for Opensearch in the project \"$TARGET_PROJECT_NAME\"."
        sleep 3
    else
        warning "Failed to create opensearch-tls-issuer Issuer for Opensearch in the project \"$TARGET_PROJECT_NAME\"!"
        exit 1
    fi
}

function setup_opensearch_cr(){
# Create ElasticsearchCluster
    info "Creating Opensearch cluster in the project \"$TARGET_PROJECT_NAME\"."
    sa_scc_mcs=$(${CLI_CMD} get project $TARGET_PROJECT_NAME --no-headers --ignore-not-found -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.mcs}')
    if [ -z $sa_scc_mcs ]; then
        fail "Can NOT get value for \"sa.scc.mcs\" from the attribute of project \"$TARGET_PROJECT_NAME\"."
        exit 1
    fi

    # retrieve the elasticsearch cr metaname
    elasticsearch_cr_name=$(${CLI_CMD} get elasticsearch.elastic.automation.ibm.com -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
    if [[ ! -z $elasticsearch_cr_name ]]; then
        cr_metaname=$(${CLI_CMD} get elasticsearch.elastic.automation.ibm.com $elasticsearch_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)

        es_storage_class_node=$(${CLI_CMD} get elasticsearch.elastic.automation.ibm.com $elasticsearch_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.nodegroupspecs.[0].storage.class)
        if [ -z $es_storage_class_node ]; then
            fail "Can NOT get value for \"storage.class\" from the existing Elasticsearch custom resource \"$elasticsearch_cr_name\" in the project \"$TARGET_PROJECT_NAME\"."
            exit 1
        fi

        es_storage_size_node=$(${CLI_CMD} get elasticsearch.elastic.automation.ibm.com $elasticsearch_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.nodegroupspecs.[0].storage.size)
        if [ -z $es_storage_size_node ]; then
            fail "Can NOT get value for \"storage.size\" from the existing Elasticsearch custom resource \"$elasticsearch_cr_name\" in the project \"$TARGET_PROJECT_NAME\"."
            exit 1
        fi
        es_storage_class_snapshot=$(${CLI_CMD} get elasticsearch.elastic.automation.ibm.com $elasticsearch_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.snapshotStores.[0].storage.class)
        if [ -z $es_storage_class_snapshot ]; then
            fail "Can NOT get value for \"storage.class\" from the existing Elasticsearch custom resource \"$elasticsearch_cr_name\" in the project \"$TARGET_PROJECT_NAME\"."
            exit 1
        fi

        es_storage_size_snapshot=$(${CLI_CMD} get elasticsearch.elastic.automation.ibm.com $elasticsearch_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.snapshotStores.[0].storage.size)
        if [ -z $es_storage_size_snapshot ]; then
            fail "Can NOT get value for \"storage.size\" from the existing Elasticsearch custom resource \"$elasticsearch_cr_name\" in the project \"$TARGET_PROJECT_NAME\"."
            exit 1
        fi

        es_secret_name="${cr_metaname}-elasticsearch-es-client-cert-kp"

        es_route_hostname=$(${CLI_CMD} get Route ${elasticsearch_cr_name}-es -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.host)
    else
        fail "Not found Elasticsearch custom resource in the project \"$TARGET_PROJECT_NAME\"."
        exit 1
    fi
    # setting profile type
    if [[ $PROFILE_TYPE == "small" ]]; then
        es_resources_limits_cpu="800m"
        es_resources_limits_memory="2Gi"

        es_resources_requests_cpu="500m"
        es_resources_requests_memory="820Mi"

        ha_resources_limits_cpu="800m"
        ha_resources_limits_memory="2Gi"

        ha_resources_requests_cpu="500m"
        ha_resources_requests_memory="820Mi"
    elif [[ $PROFILE_TYPE == "medium" ]]; then
        es_resources_limits_cpu="1000m"
        es_resources_limits_memory="5Gi"

        es_resources_requests_cpu="500m"
        es_resources_requests_memory="3512Mi"

        ha_resources_limits_cpu="1000m"
        ha_resources_limits_memory="5Gi"

        ha_resources_requests_cpu="500m"
        ha_resources_requests_memory="3512Mi"
    elif [[ $PROFILE_TYPE == "large" ]]; then
        es_resources_limits_cpu="2000m"
        es_resources_limits_memory="5Gi"

        es_resources_requests_cpu="1000m"
        es_resources_requests_memory="3512Mi"

        ha_resources_limits_cpu="2000m"
        ha_resources_limits_memory="5Gi"

        ha_resources_requests_cpu="1000m"
        ha_resources_requests_memory="3512Mi"
    fi
cat << EOF > ${TEMP_FOLDER}/ibm-cp4ba-os-cluster.yaml
apiVersion: elasticsearch.opencontent.ibm.com/v1
kind: ElasticsearchCluster
metadata:
  annotations:
    productName: CloudpakOpen Elasticsearch
  name: opensearch
  namespace: "$TARGET_PROJECT_NAME"
spec:
  addDefaultPlugins: true
  minimumMasterNodes: 2
  allowRebuildOnChange: false
  enableDataNodeService: false
  sharedStoragePVC: ''
  credentialSecret: ''
  odlmRegistryNamespace: ibm-common-services
  tlsSecret: ''
  maxUnavailable: 0
  imagePullSecret: ''
  nodes:
    - nodeSelector: {}
      jvmOpts: ''
      master: true
      environmentVariables: {}
      ingest: true
      schedulerName: ''
      nodeAffinity: {}
      mountSecrets:
        - name: $es_secret_name
          path: /workdir/apps/elasticsearch/config/esos
      data: true
      name: all
      haResources:
        limits:
          cpu: $ha_resources_limits_cpu
          ephemeral-storage: 6Gi
          memory: $ha_resources_limits_memory
        requests:
          cpu: $ha_resources_requests_cpu
          ephemeral-storage: 10Mi
          memory: $ha_resources_requests_memory
      podAffinity: {}
      additionalConfiguration:
        - name: gateway.expected_data_nodes
          value: '0'
        - name: reindex.remote.allowlist
          value: '["$es_route_hostname:443"]'
        - name: reindex.ssl.certificate_authorities
          value: '/workdir/apps/elasticsearch/config/esos/ca.crt'
        - name: reindex.ssl.certificate
          value: '/workdir/apps/elasticsearch/config/esos/tls.crt'
        - name: reindex.ssl.key
          value: '/workdir/apps/elasticsearch/config/esos/tls.key'
      podAntiAffinity: {}
      topologySpreadConstraints: []
      addKeys: []
      esResources:
        limits:
          cpu: $es_resources_limits_cpu
          ephemeral-storage: 5Gi
          memory: $es_resources_limits_memory
        requests:
          cpu: $es_resources_requests_cpu
          ephemeral-storage: 10Mi
          memory: $es_resources_requests_memory
      secureEnvironmentVariables: []
      replicas: 3
      storageSize: '$es_storage_size_node'
      description: All in one nodes
      nodeGroupLabels:
        app: ibm-opensearch
      roles:
        - data
        - ingest
        - cluster_manager
      storageClass: $es_storage_class_node
  imagePullPolicy: IfNotPresent
  odlmRegistry: common-service
  tlsIssuer: 'opensearch-tls-issuer'
  useResourceRequestLimitsForJVMHeapRatio: 0.5
  snapshotRepo:
    enabled: true
    seLinuxOptionsLevels: '$sa_scc_mcs'
    size: 10Gi
    snapshotActivity: none
    storageClass: $es_storage_class_snapshot
  useResourceRequestLimitsForJVMHeap: true
  proxyHttpPort: 9200
  version: '2'
  serviceAccount: ''
  image: ''
  ignoreForMaintenance: false
  updateStrategy: RollingUpdate
  proxyTransportPort: 9300
  useODLM: false
  enableNetworkPolicy: true
  useCertificateManager: true
  sessionAffinity: ClientIP
EOF
    ${CLI_CMD} apply -f ${TEMP_FOLDER}/ibm-cp4ba-os-cluster.yaml >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        success "Created Opensearch cluster in the project \"$TARGET_PROJECT_NAME\"."
        sleep 3
    else
        warning "Failed to create Opensearch cluster in the project \"$TARGET_PROJECT_NAME\"!"
        exit 1
    fi

    info "Checking Opensearch cluster pod ready or not in the project \"$TARGET_PROJECT_NAME\""
    maxRetry=50
    for ((podnum=0;podnum<=2;podnum++)); do
        for ((retry=0;retry<=${maxRetry};retry++)); do
            opensearch_pod_name=$(${CLI_CMD} get pod -n $TARGET_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep "opensearch-ib-.*-es-server-all-${podnum}" | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
            if [[ -z $opensearch_pod_name ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    printf "\n"
                    if [[ -z $opensearch_pod_name ]]; then
                        warning "Timeout waiting for Opensearch cluster pod to be ready in the project \"$TARGET_PROJECT_NAME\""
                    fi
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            else
                break
            fi
        done
        success "Opensearch cluster pod-${podnum} ready in the project \"$TARGET_PROJECT_NAME\"!"
        msg "Pod: $opensearch_pod_name"
    done
}

function setup_opensearch_route(){
# Creat route for Opensearch
    info "Creating opensearch-route Route for Opensearch in the project \"$TARGET_PROJECT_NAME\"."
    openshift_hostname=$(${CLI_CMD} get IngressController default -n openshift-ingress-operator --no-headers --ignore-not-found -o jsonpath='{.status.domain}')
    if [ -z $openshift_hostname ]; then
        fail "Can NOT get value for \"openshift_ingress_domain.status.domain\" for project \"openshift-ingress-operator\"."
        exit 1
    fi
cat << EOF > ${TEMP_FOLDER}/ibm-cp4ba-os-route.yaml
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  annotations:
    haproxy.router.openshift.io/balance: roundrobin
    haproxy.router.openshift.io/disable_cookies: 'true'
    haproxy.router.openshift.io/timeout: 3600s
  name: opensearch-route
  namespace: "$TARGET_PROJECT_NAME"
  labels:
    app.kubernetes.io/component: OpenSearch
    app.kubernetes.io/instance: ibm-opensearch
    app.kubernetes.io/managed-by: Operator
    app.kubernetes.io/name: ibm-opensearch
spec:
  host: opensearch-$TARGET_PROJECT_NAME.$openshift_hostname
  to:
    kind: Service
    name: opensearch-ibm-elasticsearch-srv
    weight: 100
  port:
    targetPort: https
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: None
  wildcardPolicy: None
EOF
    ${CLI_CMD} delete -f ${TEMP_FOLDER}/ibm-cp4ba-os-route.yaml >/dev/null 2>&1
    ${CLI_CMD} apply -f ${TEMP_FOLDER}/ibm-cp4ba-os-route.yaml >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        success "Created opensearch-route Route for Opensearch in the project \"$TARGET_PROJECT_NAME\"."
        sleep 3
    else
        warning "Failed to create opensearch-route Route for Opensearch in the project \"$TARGET_PROJECT_NAME\"!"
        exit 1
    fi
}

function setup_opensearch_networkpolicy(){
# Creat networkPolicy for Opensearch for CPfs issue https://github.ibm.com/IBMPrivateCloud/roadmap/issues/63514 as workaround
    info "Creating \"opensearch-network-policy-allow-all\" network policy for Opensearch in the project \"$TARGET_PROJECT_NAME\"."
    # opensearch_ss_name=$(${CLI_CMD} get StatefulSet -n $TARGET_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name' --no-headers | grep "opensearch-ib-.*-es-server-all" )
    # if [[ -z ${opensearch_ss_name} ]]; then
    #     fail "No found opensearch StatefulSet in the project \"$TARGET_PROJECT_NAME\"."
    # else
    # opensearch_label=$(${CLI_CMD} get StatefulSet $opensearch_ss_name -n $TARGET_PROJECT_NAME -o jsonpath='{.metadata.labels.ibm-es-server}')
cat << EOF > ${TEMP_FOLDER}/ibm-cp4ba-os-network-policy.yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: ${cp4ba_cr_metaname}-cp4a-ingress-allow-opensearch
  namespace: "$TARGET_PROJECT_NAME"
spec:
  podSelector:
    matchLabels:
      app: ibm-opensearch
  ingress:
    - ports:
        - protocol: TCP
          port: 9200
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 2112
  policyTypes:
    - Ingress
EOF
        ${CLI_CMD} delete -f ${TEMP_FOLDER}/ibm-cp4ba-os-network-policy.yaml >/dev/null 2>&1
        ${CLI_CMD} apply -f ${TEMP_FOLDER}/ibm-cp4ba-os-network-policy.yaml >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            success "Created \"${cp4ba_cr_metaname}-cp4a-ingress-allow-opensearch\" network policy for Opensearch in the project \"$TARGET_PROJECT_NAME\"."
            sleep 3
        else
            warning "Failed to create \"${cp4ba_cr_metaname}-cp4a-ingress-allow-opensearch\" network policy for Opensearch in the project \"$TARGET_PROJECT_NAME\"!"
            exit 1
        fi
}

function select_upgrade_mode_simple(){
    UPGRADE_MODE=""
    while [[ $UPGRADE_MODE == "" ]]; do
        printf "\n"
        options=("Cluster-scoped to Cluster-scoped" "Cluster-scoped to Namespace-scoped" "Namespace-scoped to Namespace-scoped")
        tips=("This migration mode will first isolate the shared 3.x version of foundational services on the cluster, then install a new instance of foundational services version 4.6.2. Any data from the original foundational services will be copied to the new instance." "This migration mode will migrate a single shared instance of foundational services that is shared by all IBM Cloud Paks in the entire cluster, all of its core foundational services operators to the cluster-scope namespace will be upgraded v4.6.2 without creating new instances." "This migration mode will migrate a dedicated foundational services without creating any new instances of foundational services. This method should only be used if the foundational services you are migrating is only for IBM Cloud Pak for Business Automation.")
        pros_tips=("The namespace-scoped foundational services for each Cloud Pak or CP4BA component." "The fewer resource required for a single shared instance of foundational services.")
        cons_tips=("The more resource required for each namespace-scoped instance of IBM Cloud Pak foundational services." "It is not flexible for all Cloud Pak or CP4BA component to share same one instance of IBM Cloud Pak foundational services.")

        echo -e "\x1B[1mWhich migration mode for the IBM Cloud Pak foundational services do you plan to migrate to? \x1B[0m${YELLOW_TEXT}(NOTES: This choice will decide to either use a private catalog (namespace-scoped) or a global catalog namespace (GCN) for Opensearch installation. Make sure you choose SAME MIGRATION MODE when rerun [upgradeOperator] for upgrade IBM Cloud Pak foundational services next.)${RESET_TEXT}\x1B[0m"

        echo -e "${YELLOW_TEXT}1) Cluster-scoped to Cluster-scoped${RESET_TEXT}"
        if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
            echo -e "   ${YELLOW_TEXT}[Tips]${RESET_TEXT}: ${tips[1]}"
            # echo -e "   ${GREEN_TEXT}[Pros]${RESET_TEXT}: ${pros_tips[1]}"
            # echo -e "   ${RED_TEXT}[Cons]${RESET_TEXT}: ${cons_tips[1]}"
        fi
        # echo -e "${YELLOW_TEXT}2) Namespace-scoped to Namespace-scoped${RESET_TEXT}"
        # if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
        #     echo -e "   ${YELLOW_TEXT}[Tips]${RESET_TEXT}: ${tips[2]}"
        #     # echo -e "   ${GREEN_TEXT}[Pros]${RESET_TEXT}: ${pros_tips[0]}"
        #     # echo -e "   ${RED_TEXT}[Cons]${RESET_TEXT}: ${cons_tips[0]}"
        # fi
        echo -e "${YELLOW_TEXT}2) Cluster-scoped to Namespace-scoped${RESET_TEXT}"
        if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
            echo -e "   ${YELLOW_TEXT}[Tips]${RESET_TEXT}: ${tips[0]}"
            # echo -e "   ${GREEN_TEXT}[Pros]${RESET_TEXT}: ${pros_tips[0]}"
            # echo -e "   ${RED_TEXT}[Cons]${RESET_TEXT}: ${cons_tips[0]}"
        fi

        read -p "Enter your choice [1 or 2]: " choice
        case $choice in
            1)
                UPGRADE_MODE="shared2shared"
                ;;
            # 2)
            #     UPGRADE_MODE="dedicated2dedicated"
            #     ;;
            2)
                UPGRADE_MODE="shared2dedicated"
                ;;
            *)
                echo "Invalid choice. Please select 1 or 2."
                sleep 2
                ;;
        esac
        if [[ ! -z $UPGRADE_MODE ]]; then
            echo "You selected: ${options[$choice-1]}"
            printf "\n"
            sleep 2
        fi
    done
}

function setup_opensearch(){
    mkdir -p ${TEMP_FOLDER} >/dev/null 2>&1

    if [[ -z $UPGRADE_MODE ]]; then
        cs_dedicated=$(${CLI_CMD} get cm -n ${COMMON_SERVICES_CM_NAMESPACE}  | grep ${COMMON_SERVICES_CM_DEDICATED_NAME} | awk '{print $1}')

        cs_shared=$(${CLI_CMD} get cm -n ${COMMON_SERVICES_CM_NAMESPACE}  | grep ${COMMON_SERVICES_CM_SHARED_NAME} | awk '{print $1}')

        if [[ "$cs_dedicated" != "" || "$cs_shared" != ""  ]] ; then
            control_namespace=$(${CLI_CMD} get cm ${COMMON_SERVICES_CM_DEDICATED_NAME} --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE} -o jsonpath='{ .data.common-service-maps\.yaml }' | grep  'controlNamespace' | cut -d':' -f2 )
            control_namespace=$(sed -e 's/^"//' -e 's/"$//' <<<"$control_namespace")
            control_namespace=$(sed "s/ //g" <<< $control_namespace)
        fi

        if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
            UPGRADE_MODE="shared2shared"
            ENABLE_PRIVATE_CATALOG=0
            info "Found the IBM Cloud Pak foundational services/IBM Cloud Pak for Business Automation are installed into all namespaces, Opensearch will install uisng global catalog."
        elif [[ "$cs_dedicated" != "" && "$cs_shared" == "" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Namespace-scoped\"."
            UPGRADE_MODE="dedicated2dedicated"
        elif [[ "$cs_dedicated" == "" && "$cs_shared" != "" && $ALL_NAMESPACE_FLAG == "No" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
            # select_upgrade_mode_simple
            UPGRADE_MODE="shared2dedicated"
            info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
            read -rsn1 -p"Press any key to continue";echo
        elif [[ "$cs_dedicated" != "" && "$cs_shared" != "" && "$control_namespace" == "" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
            # select_upgrade_mode_simple
            UPGRADE_MODE="shared2dedicated"
            info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
            read -rsn1 -p"Press any key to continue";echo
        elif [[ "$cs_dedicated" != "" && "$cs_shared" != "" && "$control_namespace" != "" ]]; then
            ${CLI_CMD} get cm ${COMMON_SERVICES_CM_DEDICATED_NAME} --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE} -o jsonpath='{ .data.common-service-maps\.yaml }' > /tmp/common-service-maps.yaml
            index=0
            common_service_namespace=`cat /tmp/common-service-maps.yaml | ${YQ_CMD} r - namespaceMapping.[$index].map-to-common-service-namespace`
            while [[ ! -z $common_service_namespace ]]
            do
                if [[ $common_service_namespace == "ibm-common-services" ]]; then
                    info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
                    # select_upgrade_mode_simple
                    UPGRADE_MODE="shared2dedicated"
                    info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
                    read -rsn1 -p"Press any key to continue";echo
                    break
                fi
                ((index++))
                common_service_namespace=`cat /tmp/common-service-maps.yaml | ${YQ_CMD} r - namespaceMapping.[$index].map-to-common-service-namespace`
                if [[ -z $common_service_namespace ]]; then
                    info "IBM Cloud Pak foundational services is working in \"Namespace-scoped\"."
                    UPGRADE_MODE="dedicated2dedicated"
                fi
            done
        elif [[ $ALL_NAMESPACE_FLAG == "No" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
            # select_upgrade_mode_simple
            UPGRADE_MODE="shared2dedicated"
            info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
            read -rsn1 -p"Press any key to continue";echo
        fi

        if [[ $UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated" ]]; then
            if ${CLI_CMD} get catalogsource -n $TARGET_PROJECT_NAME | grep ibm-cp4a-operator-catalog >/dev/null 2>&1; then
                PRIVATE_CATALOG_FOUND="Yes"
                ENABLE_PRIVATE_CATALOG=1
                info "Found this CP4BA deployment is installed using private catalog \"ibm-cp4a-operator-catalog\" under project \"$TARGET_PROJECT_NAME\", Opensearch will install using private catalog."
            else
                select_private_catalog_opensearch
            fi
        else
            info "If you plan to migrate IBM Cloud Pak foundational services \"cluster-scoped to cluster-scoped\", Opensearch will keep to use global catalog in the project \"openshift-marketplace\" same as other IBM Cloud Pak foundational services/CP4BA operators."    
            sleep 3
        fi
    fi

    # if ${CLI_CMD} get catalogsource --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME | grep ibm-cp4a-operator-catalog >/dev/null 2>&1; then
    #     PRIVATE_CATALOG_FOUND="Yes"
    #     ENABLE_PRIVATE_CATALOG=1
    #     info "Found this CP4BA deployment is installed using private catalog in the project \"$TARGET_PROJECT_NAME\", the Opensearch will be installed using private catalog also"
    # elif ${CLI_CMD} get catalogsource --no-headers --ignore-not-found -n openshift-marketplace | grep ibm-cp4a-operator-catalog >/dev/null 2>&1; then
    #     PRIVATE_CATALOG_FOUND="No"
    #     # info "Found this CP4BA deployment is installed using global catalog in the project \"openshift-marketplace\""
    #     if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
    #         ENABLE_PRIVATE_CATALOG=0
    #         info "Found CP4BA deployment is installed into All Namespaces, will keep to use global catalog in the project \"openshift-marketplace\" for Opensearch same as other CP4BA operators."
    #     else
    #         info "Found CP4BA deployment is installed into specific Namespaces."
    #         select_upgrade_mode_simple
    #         if [[ $UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated" ]]; then
    #             select_private_catalog_opensearch
    #         else
    #             info "The migration mode is \"cluster-scoped to cluster-scoped\", will keep to use global catalog in the project \"openshift-marketplace\" for Opensearch same as other CP4BA operators."    
    #             sleep 3
    #         fi
    #     fi
    # fi

    if [[ ($ENABLE_PRIVATE_CATALOG -eq 1 && $ALL_NAMESPACE_FLAG == "Yes") || $ENABLE_PRIVATE_CATALOG -eq 0 ]]; then
        OPENSEARCH_CATALOG_NS="openshift-marketplace"
    elif [[ $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
        OPENSEARCH_CATALOG_NS="$TARGET_PROJECT_NAME"
    fi

    select_profile_type
    setup_opensearch_catalog
    # support All namespace scenario
    if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
        setup_opensearch_subscription "openshift-operators"
    else
        setup_opensearch_subscription "$TARGET_PROJECT_NAME"
    fi

    setup_opensearch_issuer
    setup_opensearch_cr
    setup_opensearch_route
    setup_opensearch_networkpolicy

    openshift_user_pwd=$(${CLI_CMD} get secret opensearch-ibm-elasticsearch-cred-secret -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found -o jsonpath='{.data.elastic}')
    if [ -z $openshift_user_pwd ]; then
        fail "Can NOT get password from secret \"opensearch-ibm-elasticsearch-cred-secret\" in the project \"$TARGET_PROJECT_NAME\"."
        exit 1
    else
        tmp_val=$(echo "$openshift_user_pwd" | base64 -d)
        info "Access URL for Opensearch Cluster: https://opensearch-$TARGET_PROJECT_NAME.$openshift_hostname"
        msg "       username: elastic"
        msg "       password: ***************"
        echo -e '       NOTES: To get password using this command: \033[0;32m'"${CLI_CMD}"' get secret opensearch-ibm-elasticsearch-cred-secret -n '"$TARGET_PROJECT_NAME"' --no-headers --ignore-not-found -o jsonpath='{.data.elastic}' | base64 -d && echo\033[0m'
    fi
}

function create_project() {
    local project_name=$1
    project_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$project_name")

    isProjExists=`${CLI_CMD} get project $project_name --ignore-not-found | wc -l`  >/dev/null 2>&1

    if [ $isProjExists -ne 2 ] ; then
        oc new-project ${project_name} >/dev/null 2>&1
        returnValue=$?
        if [ "$returnValue" == 1 ]; then
            if [ -z "$CP4BA_AUTO_NAMESPACE" ]; then
                echo -e "\x1B[1;31mInvalid project name, please enter a valid name...\x1B[0m"
                project_name=""
                return 1
            else
                echo -e "\x1B[1;31mInvalid project name \"$CP4BA_AUTO_NAMESPACE\", please set a valid name...\x1B[0m"
                project_name=""
                exit 1
            fi
        else
            echo -e "\x1B[1mUsing project ${project_name}...\x1B[0m"
            return 0
        fi
    else
        echo -e "\x1B[1mProject \"${project_name}\" already exists! Continue...\x1B[0m"
        return 0
    fi
}

function check_selection_migration(){
    es_to_os_migration_flag=$(${CLI_CMD} get configmap ibm-cp4ba-os-migration-status --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath={.data.opensearch_migration_done})
    # es_to_os_migration_flag=$(echo $es_to_os_migration_flag | tr '[:upper:]' '[:lower:]')
    if [[ $es_to_os_migration_flag == "NONEED" ]]; then
        ES_TO_OS_MIGRATION_SELECTED="No"
        MIGRATE_ES_TO_OS_DONE="NONEED"
        create_configmap_os_migration
        success "Found the \"opensearch_migration_done\" is \"$es_to_os_migration_flag\" in ibm-cp4ba-os-migration-status configMap in the project \"$TARGET_PROJECT_NAME\""
        info "Script will bypass the migration of Elasticsearch to OpenSearch and continue to upgrade CP4BA operators and IBM Cloud Pak foundational services."
        sleep 5
    elif [[ ! -z $es_to_os_migration_flag ]]; then
        ES_TO_OS_MIGRATION_SELECTED="Yes"
        success "Found the \"opensearch_migration_done\" is \"$es_to_os_migration_flag\" in ibm-cp4ba-os-migration-status configMap in the project \"$TARGET_PROJECT_NAME\""
    elif [[ -z $es_to_os_migration_flag ]]; then
        # For PFS
        while true; do
            printf "\n"
            printf "\x1B[1mAre you planning to use IBM Process Federation Server (PFS) after the upgrade AND if you want to perform the migration of Elasticsearch to OpenSearch?\x1B[0m (Yes/No): "
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                ES_TO_OS_MIGRATION_SELECTED="Yes"
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                ES_TO_OS_MIGRATION_SELECTED="No"
                break
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi
}

function check_es_to_os_migration(){
    which jq &>/dev/null
    [[ $? -ne 0 ]] && \
    fail  "Unable to locate \"jq\" CLI. You must install it first for migration from Elasticsearch to Opensearch, for example \"yum -y install jq\" on Linux" && \
    exit 1

    printf "\n"
    while true; do
        printf "\x1B[1mDid you complete migration from Elasticsearch to Opensearch? \x1B[0m${YELLOW_TEXT}(NOTES: If you select \"No\", the script will guide you to complete migration.)${RESET_TEXT} (Yes/No, default: No): "
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            info "Checking ElasticsearchCluster custom resource existing or not in the project \"$TARGET_PROJECT_NAME\""
            ${CLI_CMD} get crd |grep elasticsearch.opencontent.ibm.com >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                opensearch_cr_name=$(${CLI_CMD} get ElasticsearchCluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
            fi
            if [[ ! -z $opensearch_cr_name ]]; then
                os_cr_metaname=$(${CLI_CMD} get ElasticsearchCluster $opensearch_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
                if [[ ! -z $os_cr_metaname ]]; then
                    success "Found ElasticsearchCluster custom resource \"$os_cr_metaname\" existing or not in the project \"$TARGET_PROJECT_NAME\""
                fi

                info "Checking Opensearch cluster pods ready or not in the project \"$TARGET_PROJECT_NAME\""
                maxRetry=3
                declare -A opensearch_pod_name_array
                for ((podnum=0;podnum<=2;podnum++)); do
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        opensearch_pod_name_array[$podnum]=$(${CLI_CMD} get pod -n $TARGET_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep "opensearch-ib-.*-es-server-all-${podnum}" | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                        if [[ -z ${opensearch_pod_name_array[$podnum]} ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                printf "\n"
                                if [[ -z ${opensearch_pod_name_array[$podnum]} ]]; then
                                    fail "Not found Opensearch cluster all pods ready in the project \"$TARGET_PROJECT_NAME\""
                                    printf "\n"
                                    echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}${RED_TEXT}You need to install Elasticsearch cluster and complete migration from Elasticsearch to Opensearch first.${RESET_TEXT}"
                                fi
                                MIGRATE_ES_TO_OS_DONE="No"
                                create_configmap_os_migration
                                setup_opensearch
                                show_tips_es_to_os_migration
                                exit 1
                            else
                                sleep 1
                                echo -n "..."
                                continue
                            fi
                        else
                            break
                        fi
                    done
                    success "Opensearch cluster pod-${podnum} ready in the project \"$TARGET_PROJECT_NAME\"!"
                    msg "Pod: ${opensearch_pod_name_array[$podnum]}"
                done
                ## Add more logic to check migration done if CPfs migration script supports checking migration status.
                MIGRATE_ES_TO_OS_DONE="Yes"
                create_configmap_os_migration
            else
                fail "Not found ElasticsearchCluster custom resource in the project \"$TARGET_PROJECT_NAME\"."
                printf "\n"
                echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}${RED_TEXT}You need to install Opensearch cluster and complete migration from Elasticsearch to Opensearch first.${RESET_TEXT}"
                MIGRATE_ES_TO_OS_DONE="No"
                create_configmap_os_migration
                setup_opensearch
                show_tips_es_to_os_migration
                exit 1
            fi
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            MIGRATE_ES_TO_OS_DONE="No"
            create_configmap_os_migration
            ${CLI_CMD} get crd |grep elasticsearch.opencontent.ibm.com >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                opensearch_cr_name=$(${CLI_CMD} get ElasticsearchCluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
            fi
            if [ -z $opensearch_cr_name ]; then
                while true; do
                    printf "\n"
                    printf "\x1B[1mDo you want to install Opensearch by script for migration Elasticsearch to Opensearch?\x1B[0m (Yes/No, default: Yes): "
                    read -rp "" ans
                    case "$ans" in
                    "y"|"Y"|"yes"|"Yes"|"YES"|"")
                        # MIGRATE_ES_TO_OS_DONE="No"
                        # create_configmap_os_migration
                        setup_opensearch
                        show_tips_es_to_os_migration
                        exit 1
                        ;;
                    "n"|"N"|"no"|"No"|"NO")
                        printf "\n"
                        echo -e "\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mYou need to install Opensearch first for migration from Elasticsearch to Opensearch.\n\x1B[0m"
                        # MIGRATE_ES_TO_OS_DONE="No"
                        # create_configmap_os_migration
                        echo "Exiting..."
                        exit 1
                        ;;
                    *)
                        echo -e "Answer must be \"Yes\" or \"No\"\n"
                        ;;
                    esac
                done
            else
                success "Found one existing ElasticsearchCluster \"$opensearch_cr_name\" custom resource for Opensearch cluster in the project \"$TARGET_PROJECT_NAME\"."
                sleep 3

                # the script will check Opensearch pod ready or not even ElasticsearchCluster CR existing.
                info "Checking Opensearch cluster pod ready or not in the project \"$TARGET_PROJECT_NAME\""
                maxRetry=50
                for ((podnum=0;podnum<=2;podnum++)); do
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        opensearch_pod_name=$(${CLI_CMD} get pod -n $TARGET_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep "opensearch-ib-.*-es-server-all-${podnum}" | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                        if [[ -z $opensearch_pod_name ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                printf "\n"
                                if [[ -z $opensearch_pod_name ]]; then
                                    warning "Timeout waiting for Opensearch cluster pod to be ready in the project \"$TARGET_PROJECT_NAME\""
                                fi
                                exit 1
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            break
                        fi
                    done
                    success "Opensearch cluster pod-${podnum} ready in the project \"$TARGET_PROJECT_NAME\"!"
                    msg "Pod: $opensearch_pod_name"
                done

                openshift_route=$(${CLI_CMD} get route opensearch-route -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found -o name)
                if [[ -z $openshift_route ]]; then
                    warning "Not found route for opensearch cluster in the project \"$TARGET_PROJECT_NAME\"."
                    setup_opensearch_route
                    setup_opensearch_networkpolicy
                fi
            fi
            show_tips_es_to_os_migration
            exit 1
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}
function retrieve_dependencies(){
  # get pods -l 'name=ibm-content-operators' --no-headers --ignore-not-found
  # Check if the content operator exists
  # kubectl get pods | grep  cpe-deploy | head -n 1 | awk '{print $1}'
  local content_operator=$( $CLI_CMD get pods -l "${CONTENT_OPERATOR_LABEL}" --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}' )
  # Check if the cp4a operator exists for upgrade from 21.0.3+
  # ibm-cp4a-operator
  local cp4a_operator=$($CLI_CMD get pods -l "${CP4A_OPERATOR_LABEL}" --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}' )

  local cpe_pod=$($CLI_CMD get pods -n $TARGET_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep "${CPE_LABEL}" | grep 'Running' | grep 'true' | grep '<none>' | head -n 1 | awk '{print $1}')
  if [[ -z $cpe_pod ]]; then
    ${CLI_CMD} scale --replicas=1 deployment ${cr_metaname}-cpe-deploy -n $TARGET_PROJECT_NAME >/dev/null 2>&1
    info "Waiting for cpe-deploy pod to be ready in the project \"$TARGET_PROJECT_NAME\"."
    maxRetry=25
    for ((retry=0;retry<=${maxRetry};retry++)); do
        cpe_pod=$($CLI_CMD get pods -n $TARGET_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep "${CPE_LABEL}" | grep 'Running' | grep 'true' | grep '<none>' | head -n 1 | awk '{print $1}')
        if [[ -z $cpe_pod ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                if [[ -z $cpe_pod ]]; then
                    warning "Timeout waiting for cpe-deploy pod to be ready in the project \"$TARGET_PROJECT_NAME\"."
                fi
                exit 1
            else
                sleep 30
                echo -n "..."
                continue
            fi
        else
            break
        fi
    done
  fi

  local option=$1

  if [[ ${cpe_pod} != ""  ]]; then
    $CLI_CMD cp $cpe_pod:${JACE_PATH} ${TEMP_FOLDER}/${JACE_NAME} -n $TARGET_PROJECT_NAME  >/dev/null 2>&1
    $CLI_CMD cp $cpe_pod:${CPE_TRUSTSTORE_PATH} ${TEMP_FOLDER}/${TRUSTSTORE_NAME} -n $TARGET_PROJECT_NAME  >/dev/null 2>&1
    OLD_TRUSTSTORE_EXISTS=$( $CLI_CMD exec -i -n $TARGET_PROJECT_NAME  $cpe_pod -- bash -c "(ls ${CPE_TRUSTSTORE_PATH} >> /dev/null 2>&1 && echo yes) || echo no")
    if [[ $option == "POSTUPGRADE"  || $OLD_TRUSTSTORE_EXISTS == "no" ]]; then
      $CLI_CMD cp $cpe_pod:${POST_UPGRADE_CPE_TRUSTSTORE_PATH} ${TEMP_FOLDER}/${POST_UPGRADE_TRUSTSTORE_NAME} -n $TARGET_PROJECT_NAME  >/dev/null 2>&1
    fi
  else
    return 1
  fi


  if [[  ${content_operator} != "" ]]; then
    EXEC_OPERATOR=$content_operator

    $CLI_CMD cp ${TEMP_FOLDER}/${JACE_NAME}  $content_operator:/tmp/${JACE_NAME} -n $TEMP_OPERATOR_PROJECT_NAME  >/dev/null 2>&1
    $CLI_CMD cp ${TEMP_FOLDER}/${TRUSTSTORE_NAME} $content_operator:/tmp/${TRUSTSTORE_NAME} -n $TEMP_OPERATOR_PROJECT_NAME   >/dev/null 2>&1
    $CLI_CMD cp ${CUR_DIR}/helper/$RUNNABLE_JAR_NAME  $content_operator:/tmp/${RUNNABLE_JAR_NAME} -n $TEMP_OPERATOR_PROJECT_NAME  >/dev/null 2>&1

    if [[ $option == "POSTUPGRADE" || $OLD_TRUSTSTORE_EXISTS == "no" ]]; then
      $CLI_CMD cp ${TEMP_FOLDER}/${POST_UPGRADE_TRUSTSTORE_NAME} $content_operator:/tmp/${POST_UPGRADE_TRUSTSTORE_NAME} -n $TEMP_OPERATOR_PROJECT_NAME  >/dev/null 2>&1
    fi

  elif [[ ${cp4a_operator} != "" ]]; then
    EXEC_OPERATOR=$cp4a_operator
    $CLI_CMD cp ${TEMP_FOLDER}/${JACE_NAME}  $cp4a_operator:/tmp/${JACE_NAME} -n $TEMP_OPERATOR_PROJECT_NAME  >/dev/null 2>&1
    $CLI_CMD cp ${TEMP_FOLDER}/${TRUSTSTORE_NAME} $cp4a_operator:/tmp/${TRUSTSTORE_NAME} -n $TEMP_OPERATOR_PROJECT_NAME  >/dev/null 2>&1
    $CLI_CMD cp ${CUR_DIR}/helper/$RUNNABLE_JAR_NAME  $cp4a_operator:/tmp/${RUNNABLE_JAR_NAME} -n $TEMP_OPERATOR_PROJECT_NAME   >/dev/null 2>&1
    if [[ $option == "POSTUPGRADE" || $OLD_TRUSTSTORE_EXISTS == "no" ]]; then
     $CLI_CMD cp ${TEMP_FOLDER}/${POST_UPGRADE_TRUSTSTORE_NAME} $cp4a_operator:/tmp/${POST_UPGRADE_TRUSTSTORE_NAME} -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
   fi

  else
    return 1
  fi
  return 0
}

function is_scim_enabled(){
  retrieve_dependencies
  ecode=$?
  if [[ $ecode -ne 0 ]]; then
    error "Failed to retrieve dependencies to determine if Content Process Engine is configured with SCIM as the directory provider type."
    warning "We're assuming that Content Process Engine directory provider type is set to SCIM."
    echo "    ${YELLOW_TEXT}* We advice you to verify that Content Process Engine directory provider type is truly SCIM to determine if you need to execute the script cp4a-pre-upgrade-and-post-upgrade-optional.sh${RESET_TEXT}"
    echo "      1. Log in to the Administration Console for Content Platform Engine."
    echo "      2. Go to Directory Configuration tab."
    echo "      3. Verify your Directory Server Type."
    IS_SCIM_ENABLED="True"

  else

    if [[ $CP4BA_IBM_FNCM_SECRET_NAME == "" ]]; then
      IBM_FNCM_SECRET_NAME='ibm-fncm-secret'
    else
      IBM_FNCM_SECRET_NAME="$CP4BA_IBM_FNCM_SECRET_NAME"
    fi

    local app_login_user=$( decode_xor_password $( $CLI_CMD get secret $IBM_FNCM_SECRET_NAME -n $TARGET_PROJECT_NAME -o jsonpath='{ .data.appLoginUsername }' | base64 -d ) $TEMP_OPERATOR_PROJECT_NAME $EXEC_OPERATOR )
    local app_login_pwd=$( decode_xor_password $( $CLI_CMD get secret $IBM_FNCM_SECRET_NAME -n $TARGET_PROJECT_NAME -o jsonpath='{ .data.appLoginPassword }' | base64 -d ) $TEMP_OPERATOR_PROJECT_NAME $EXEC_OPERATOR )
    local key_store_pass=$( decode_xor_password $( $CLI_CMD get secret $IBM_FNCM_SECRET_NAME -n $TARGET_PROJECT_NAME -o jsonpath='{ .data.keystorePassword }' | base64 -d ) $TEMP_OPERATOR_PROJECT_NAME $EXEC_OPERATOR | sed  's/\$/\\$/g' )
    local cpe_svc_name=$( $CLI_CMD get svc -n $TARGET_PROJECT_NAME | grep $CPE_SERVICE_NAME | awk '{print $1}' )
    local class_path="/tmp/Jace.jar;/opt/ibm/content_emitter/stax-api.jar;/opt/ibm/content_emitter/xlxpScanner.jar;/opt/ibm/content_emitter/xlxpScannerUtils.jar"
    local truststore="/tmp/ibm_customFNCMTrustStore.p12"
    if [[ $OLD_TRUSTSTORE_EXISTS == "no" ]]; then
        truststore="/tmp/trusts.p12"
    fi
    if [[ $UPGRADE_MODE == "dedicated2dedicated" ]]; then
      TARGET_PROJECT_NAME_CS=$TARGET_PROJECT_NAME
    elif [[ $UPGRADE_MODE == "shared2shared" || $UPGRADE_MODE == "shared2dedicated" ]]; then
      TARGET_PROJECT_NAME_CS="ibm-common-services"
    fi

    IS_SCIM_ENABLED_RESPONSE=$( ${CLI_CMD} exec -i -n $TEMP_OPERATOR_PROJECT_NAME $EXEC_OPERATOR -- bash -c "java -cp \"${CLASS_PATH}\" -jar -Duser.language=en -Duser.country=US -Djavax.net.ssl.trustStore=$truststore -Djavax.net.ssl.trustStoreType=pkcs12  -Djavax.net.ssl.trustStorePassword=\"${key_store_pass}\" /tmp/${RUNNABLE_JAR_NAME} SCIMENABLED $cpe_svc_name.$TARGET_PROJECT_NAME.svc $CPE_SERVICE_PORT $app_login_user  $app_login_pwd  $TARGET_PROJECT_NAME_CS" )
    ## "TRUE : The p8domain is configured with a scim directory"
    if [[ $IS_SCIM_ENABLED_RESPONSE =~ "TRUE : The p8domain is configured with a scim directory" ]]; then
      IS_SCIM_ENABLED="True"
      info "Content Process Engine directory provider type is set to SCIM."
    else
      IS_SCIM_ENABLED="False"
      info "Content Process Engine directory provider type is not set to SCIM."
    fi
  fi
}

function set_script_mode(){
    if [[ -f $TEMPORARY_PROPERTY_FILE && -f $DB_NAME_USER_PROPERTY_FILE && -f $DB_SERVER_INFO_PROPERTY_FILE && -f $LDAP_PROPERTY_FILE ]]; then
        DEPLOYMENT_WITH_PROPERTY="Yes"
    else
        DEPLOYMENT_WITH_PROPERTY="No"
    fi
}

function validate_kube_oc_cli(){
    if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]]; then
        which oc &>/dev/null
        [[ $? -ne 0 ]] && \
        echo -e  "\x1B[1;31mUnable to locate an OpenShift CLI. You must install it to run this script.\x1B[0m" && \
        exit 1
    fi
    if  [[ $PLATFORM_SELECTED == "other" ]]; then
        which kubectl &>/dev/null
        [[ $? -ne 0 ]] && \
        echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI, You must install it to run this script.\x1B[0m" && \
        exit 1
    fi
}

function prop_tmp_property_file() {
    grep "\b${1}\b" ${TEMPORARY_PROPERTY_FILE}|cut -d'=' -f2
}

function load_property_before_generate(){
    if [[ ! -f $TEMPORARY_PROPERTY_FILE || ! -f $DB_NAME_USER_PROPERTY_FILE || ! -f $DB_SERVER_INFO_PROPERTY_FILE || ! -f $LDAP_PROPERTY_FILE ]]; then
        fail "Not Found existing property file under \"$PROPERTY_FILE_FOLDER\", Please run \"cp4a-prerequisites.sh\" to complate prerequisites"
        exit 1
    fi

    # load pattern into pattern_cr_arr
    pattern_list="$(prop_tmp_property_file PATTERN_LIST)"
    pattern_name_list="$(prop_tmp_property_file PATTERN_NAME_LIST)"
    optional_component_list="$(prop_tmp_property_file OPTION_COMPONENT_LIST)"
    optional_component_name_list="$(prop_tmp_property_file OPTION_COMPONENT_NAME_LIST)"
    foundation_list="$(prop_tmp_property_file FOUNDATION_LIST)"

    OIFS=$IFS
    IFS=',' read -ra pattern_cr_arr <<< "$pattern_list"
    IFS=',' read -ra PATTERNS_CR_SELECTED <<< "$pattern_list"

    IFS=',' read -ra pattern_arr <<< "$pattern_name_list"
    IFS=',' read -ra optional_component_cr_arr <<< "$optional_component_list"
    IFS=',' read -ra optional_component_arr <<< "$optional_component_name_list"
    IFS=',' read -ra foundation_component_arr <<< "$foundation_list"
    IFS=$OIFS

    # load db_name_full_array and db_user_full_array
    db_name_list="$(prop_tmp_property_file DB_NAME_LIST)"
    db_user_list="$(prop_tmp_property_file DB_USER_LIST)"
    db_user_pwd_list="$(prop_tmp_property_file DB_USER_PWD_LIST)"

    OIFS=$IFS
    IFS=',' read -ra db_name_full_array <<< "$db_name_list"
    IFS=',' read -ra db_user_full_array <<< "$db_user_list"
    IFS=',' read -ra db_user_pwd_full_array <<< "$db_user_pwd_list"
    IFS=$OIFS

    # load db ldap type
    LDAP_TYPE="$(prop_tmp_property_file LDAP_TYPE)"
    DB_TYPE="$(prop_tmp_property_file DB_TYPE)"

    # load CONTENT_OS_NUMBER
    content_os_number=$(prop_tmp_property_file CONTENT_OS_NUMBER)

    # load DB_SERVER_NUMBER
    db_server_number=$(prop_tmp_property_file DB_SERVER_NUMBER)

    # load external ldap flag
    SET_EXT_LDAP=$(prop_tmp_property_file EXTERNAL_LDAP_ENABLED)

    # load limited CPE storage support flag
    CPE_FULL_STORAGE=$(prop_tmp_property_file CPE_FULL_STORAGE_ENABLED)

    # load GPU enabled worker nodes flag
    ENABLE_GPU_ARIA=$(prop_tmp_property_file ENABLE_GPU_ARIA_ENABLED)
    nodelabel_key=$(prop_tmp_property_file NODE_LABEL_KEY)
    nodelabel_value=$(prop_tmp_property_file NODE_LABEL_VALUE)

    # load LDAP/DB required flag for wfps
    LDAP_WFPS_AUTHORING=$(prop_tmp_property_file LDAP_WFPS_AUTHORING_FLAG)
    EXTERNAL_DB_WFPS_AUTHORING=$(prop_tmp_property_file EXTERNAL_DB_WFPS_AUTHORING_FLAG)

    # load fips enabled flag
    FIPS_ENABLED=$(prop_tmp_property_file FIPS_ENABLED_FLAG)

    # load profile size  flag
    PROFILE_TYPE=$(prop_tmp_property_file PROFILE_SIZE_FLAG)
}

function validate_docker_podman_cli(){
    if [[ $OCP_VERSION == "3.11" || "$machine" == "Mac" ]];then
        which podman &>/dev/null
        if [[ $? -ne 0 ]]; then
            PODMAN_FOUND="No"

            which docker &>/dev/null
            [[ $? -ne 0 ]] && \
                DOCKER_FOUND="No"
            if [[ $DOCKER_FOUND == "No" && $PODMAN_FOUND == "No" ]]; then
                echo -e "\x1B[1;31mUnable to locate docker and podman, please install either of them first.\x1B[0m" && \
                exit 1
            fi
        fi
    elif [[ $OCP_VERSION == "4.4OrLater" ]]
    then
        which podman &>/dev/null
        [[ $? -ne 0 ]] && \
            echo -e "\x1B[1;31mUnable to locate podman, please install it first.\x1B[0m" && \
            exit 1
    fi
}

function select_project() {
    while [[ $TARGET_PROJECT_NAME == "" ]];
    do
        printf "\n"
        echo -e "\x1B[1mWhere do you want to deploy Cloud Pak for Business Automation?\x1B[0m"
        read -p "Enter the name for an existing project (namespace): " TARGET_PROJECT_NAME
        if [ -z "$TARGET_PROJECT_NAME" ]; then
            echo -e "\x1B[1;31mEnter a valid project name, project name can not be blank\x1B[0m"
        elif [[ "$TARGET_PROJECT_NAME" == openshift* ]]; then
            echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
            TARGET_PROJECT_NAME=""
        elif [[ "$TARGET_PROJECT_NAME" == kube* ]]; then
            echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
            TARGET_PROJECT_NAME=""
        else
            isProjExists=`${CLI_CMD} get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l`  >/dev/null 2>&1

            if [ "$isProjExists" -ne 2 ] ; then
                echo -e "\x1B[1;31mInvalid project name, please enter a existing project name ...\x1B[0m"
                TARGET_PROJECT_NAME=""
            else
                echo -e "\x1B[1mUsing project ${TARGET_PROJECT_NAME}...\x1B[0m"
            fi
        fi
    done
}

function containsElement(){
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

function containsObjectStore(){
    OBJECT_NAME=$1
    FILE=$2
    os_num=0
    os_index_array=()
    while true; do
        object_name_tmp=`cat $FILE | ${YQ_CMD} r - spec.datasource_configuration.dc_os_datasources.[$os_num].dc_common_os_datasource_name`

        if [ -z "$object_name_tmp" ]; then
            break
        else
            if [[ "$OBJECT_NAME" == "$object_name_tmp" ]]; then
                os_index_array=( "${os_index_array[@]}" "${os_num}" )
            fi
        fi
        ((os_num++))
    done
}

function getTotalFNCMObjectStore(){
    object_array=("FNOS1DS" "FNOS2DS" "FNOS3DS" "FNOS4DS" "FNOS5DS" "FNOS6DS" "FNOS7DS" "FNOS8DS" "FNOS9DS" "FNOS10DS")
    FILE=$1
    os_index_array=()
    total_os=0
    for object_name in "${object_array[@]}"
    do
        os_num=0
        while true; do
            object_name_tmp=`cat $FILE | ${YQ_CMD} r - spec.datasource_configuration.dc_os_datasources.[$os_num].dc_common_os_datasource_name`
            if [ -z "$object_name_tmp" ]; then
                break
            else
                if [[ "$object_name" == "$object_name_tmp" ]]; then
                    os_index_array=( "${os_index_array[@]}" "${os_num}" )
                fi
            fi
            ((os_num++))
        done
    done
    total_os=${#os_index_array[@]}
}

function containsInitObjectStore(){
    OBJECT_NAME=$1
    FILE=$2
    os_num=0
    os_index_array=()
    while true; do
        object_name_tmp=`cat $FILE | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[$os_num].oc_cpe_obj_store_display_name`
        if [ -z "$object_name_tmp" ]; then
            break
        else
            if [[ "$OBJECT_NAME" == "$object_name_tmp" ]]; then
                os_index_array=( "${os_index_array[@]}" "${os_num}" )
            fi
        fi
        ((os_num++))
    done
}

function containsInitLDAPGroups(){
    FILE=$1
    ldap_num=0
    ldap_groups_index_array=()
    while true; do
        name_tmp=`cat $FILE | ${YQ_CMD} r - spec.initialize_configuration.ic_ldap_creation.ic_ldap_admins_groups_name.[$ldap_num]`
        if [ -z "$name_tmp" ]; then
            break
        else
            ldap_groups_index_array=( "${ldap_groups_index_array[@]}" "${ldap_num}" )
        fi
        ((ldap_num++))
    done
}

function containsInitLDAPUsers(){
    FILE=$1
    ldap_num=0
    ldap_users_index_array=()
    while true; do
        name_tmp=`cat $FILE | ${YQ_CMD} r - spec.initialize_configuration.ic_ldap_creation.ic_ldap_admin_user_name.[$ldap_num]`
        if [ -z "$name_tmp" ]; then
            break
        else
            ldap_users_index_array=( "${ldap_users_index_array[@]}" "${ldap_num}" )
        fi
        ((ldap_num++))
    done
}

function containsBAWInstance(){
    BAW_INS_NAME=$1
    FILE=$2
    baw_instance_num=0
    baw_index_array=()
    while true; do
        name_tmp=`cat $FILE | ${YQ_CMD} r - spec.baw_configuration.[$baw_instance_num].name`
        if [ -z "$name_tmp" ]; then
            break
        else
            if [[ "$BAW_INS_NAME" == "$name_tmp" ]]; then
                baw_index_array=( "${baw_index_array[@]}" "${baw_instance_num}" )
            fi
        fi
        ((baw_instance_num++))
    done
}

function containsAEInstance(){
    FILE=$1
    ae_instance_num=0
    ae_index_array=()
    while true; do
        name_tmp=`cat $FILE | ${YQ_CMD} r - spec.application_engine_configuration.[$ae_instance_num].name`
        if [ -z "$name_tmp" ]; then
            break
        else
            ae_index_array=( "${ae_index_array[@]}" "${ae_instance_num}" )
        fi
        ((ae_instance_num++))
    done
}

function containsICNRepos(){
    FILE=$1
    icn_repo_instance_num=0
    icn_repo_index_array=()
    while true; do
        name_tmp=`cat $FILE | ${YQ_CMD} r - spec.initialize_configuration.ic_icn_init_info.icn_repos.[$icn_repo_instance_num].add_repo_id`
        if [ -z "$name_tmp" ]; then
            break
        else
            icn_repo_index_array=( "${icn_repo_index_array[@]}" "${icn_repo_instance_num}" )
        fi
        ((icn_repo_instance_num++))
    done
}

function containsICNDesktop(){
    FILE=$1
    icn_desktop_instance_num=0
    icn_desktop_index_array=()
    while true; do
        name_tmp=`cat $FILE | ${YQ_CMD} r - spec.initialize_configuration.ic_icn_init_info.icn_desktop.[$icn_desktop_instance_num].add_desktop_id`
        if [ -z "$name_tmp" ]; then
            break
        else
            icn_desktop_index_array=( "${icn_desktop_index_array[@]}" "${icn_desktop_instance_num}" )
        fi
        ((icn_desktop_instance_num++))
    done
}

function containsTenantDB(){
    FILE=$1
    tenant_db_instance_num=0
    tenant_db_index_array=()
    while true; do
        name_tmp=`cat $FILE | ${YQ_CMD} r - spec.datasource_configuration.dc_ca_datasource.tenant_databases.[$tenant_db_instance_num]`
        if [ -z "$name_tmp" ]; then
            break
        else
            tenant_db_index_array=( "${tenant_db_index_array[@]}" "${tenant_db_instance_num}" )
        fi
        ((tenant_db_instance_num++))
    done
}

function get_baw_mode(){
    if [[ "$SCRIPT_MODE" == "baw" || "$SCRIPT_MODE" == "baw-dev" ]]; then
       return 0
    else
       return 1
    fi
}

function select_platform(){
    printf "\n"
    echo -e "\x1B[1mSelect the cloud platform to deploy: \x1B[0m"
    COLUMNS=12
    if [ -z "$existing_platform_type" ]; then
        if [[ $DEPLOYMENT_TYPE == "starter" ]];then
            options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
            PS3='Enter a valid option [1 to 2]: '
        elif [[ $DEPLOYMENT_TYPE == "production" ]]
        then
            if [[ "${SCRIPT_MODE}" == "OLM" ]]; then
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
                PS3='Enter a valid option [1 to 2]: '
            else
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud" "Other ( Certified Kubernetes Cloud Platform / CNCF)")
                PS3='Enter a valid option [1 to 3]: '
            fi
        fi
        if [[ -z "${CP4BA_AUTO_PLATFORM}" ]]; then
            select opt in "${options[@]}"
            do
                case $opt in
                    "RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud")
                        PLATFORM_SELECTED="ROKS"
                        use_entitlement="yes"
                        break
                        ;;
                    "Openshift Container Platform (OCP) - Private Cloud")
                        PLATFORM_SELECTED="OCP"
                        use_entitlement="yes"
                        break
                        ;;
                    "Other ( Certified Kubernetes Cloud Platform / CNCF)")
                        PLATFORM_SELECTED="other"
                        break
                        ;;
                    *) echo "invalid option $REPLY";;
                esac
            done
        else
           PLATFORM_SELECTED="${CP4BA_AUTO_PLATFORM}"
           use_entitlement="yes"
        fi
    else
        if [[ $DEPLOYMENT_TYPE == "starter" ]];then
            options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
            options_var=("ROKS" "OCP")
        elif [[ $DEPLOYMENT_TYPE == "production" ]]
        then
            if [[ "${SCRIPT_MODE}" == "OLM" ]]; then
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
                options_var=("ROKS" "OCP")
            else
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud" "Other ( Certified Kubernetes Cloud Platform / CNCF)")
                options_var=("ROKS" "OCP" "other")
            fi
        fi
        for i in ${!options_var[@]}; do
            if [[ "${options_var[i]}" == "$existing_platform_type" ]]; then
                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Selected)"
            else
                printf "%1d) %s\n" $((i+1)) "${options[i]}"
            fi
        done
        echo -e "\x1B[1;31mExisting platform type found in CR: \"$existing_platform_type\"\x1B[0m"
        # echo -e "\x1B[1;31mDo not need to select again.\n\x1B[0m"
        read -rsn1 -p"Press any key to continue ...";echo
    fi

    if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS" ]]; then
        CLI_CMD=oc
    elif [[ "$PLATFORM_SELECTED" == "other" ]]
    then
        CLI_CMD=kubectl
    fi

    validate_kube_oc_cli

    # For Azure Red Hat OpenShift (ARO)/Red Hat OpenShift Service on AWS (ROSA)
    if [[ "$PLATFORM_SELECTED" == "OCP" && "${DEPLOYMENT_TYPE}" == "starter" ]]; then
        while true; do
            printf "\n"
            printf "\x1B[1mIs your OCP deployed on AWS or Azure? (Yes/No, default: No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                printf "\n"
                echo -e "\x1B[1mWhich platform is OCP deployed on? \x1B[0m"
                COLUMNS=12
                options=("AWS (ROSA: Red Hat OpenShift Service on AWS)" "Azure (ARO: Azure Red Hat OpenShift)")
                PS3='Enter a valid option [1 to 2]: '
                select opt in "${options[@]}"
                do
                    case $opt in
                        "Azure"*)
                            OCP_PLATFORM="ARO"
                            break
                            ;;
                        "AWS"*)
                            OCP_PLATFORM="ROSA"
                            break
                            ;;
                        *) echo "invalid option $REPLY";;
                    esac
                done
                break
                ;;
            "n"|"N"|"no"|"No"|"NO"|"")
                OCP_PLATFORM=""
                break
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi
}

function check_ocp_version(){
    if [[ ${PLATFORM_SELECTED} == "OCP" || ${PLATFORM_SELECTED} == "ROKS" ]];then
        temp_ver=`${CLI_CMD} version | grep v[1-9]\.[1-9][0-9] | tail -n1`
        if [[ $temp_ver == *"Kubernetes Version"* ]]; then
            currentver="${temp_ver:20:7}"
        else
            currentver="${temp_ver:11:7}"
        fi
        requiredver="v1.17.1"
        if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" = "$requiredver" ]; then
            OCP_VERSION="4.4OrLater"
        else
            # OCP_VERSION="3.11"
            OCP_VERSION="4.4OrLater"
            echo -e "\x1B[1;31mIMPORTANT: The apiextensions.k8s.io/v1beta API has been deprecated from k8s 1.16+, OCp4.3 is using k8s 1.16.x. recommend you to upgrade your OCp to 4.4 or later\n\x1B[0m"
            read -rsn1 -p"Press any key to continue";echo
            # exit 0
        fi
    fi
}

function select_pattern(){
# This function support mutiple checkbox, if do not select anything, it will return None

    PATTERNS_SELECTED=""
    choices_pattern=()
    pattern_arr=()
    pattern_cr_arr=()
    AUTOMATION_SERVICE_ENABLE=""
    AE_DATA_PERSISTENCE_ENABLE=""
    CPE_FULL_STORAGE=""


    if [[ "${PLATFORM_SELECTED}" == "other" ]]; then
        if [[ "${DEPLOYMENT_TYPE}" == "starter" ]];
        then
            options=("FileNet Content Manager" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Business Automation Workflow Authoring and Automation Workstream Services" "IBM Automation Document Processing")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow-workstreams" "document_processing")
            foundation_0=("BAN" "RR")                 # Foundation for FileNet Content Manager
            foundation_1=("BAN" "RR")                # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR" "UMS")     # Foundation for Automation Decision Services
            foundation_3=("RR" "UMS" "BAS")     # Foundation for Business Automation Applications (full)
            foundation_4=("RR" "UMS" "AE" "BAS")           # Foundation for Business Automation Workflow and workstreams(Demo)
            foundation_5=("BAN" "RR" "AE" "BAS" "UMS")  # Foundation for IBM Automation Document Processing
        else
            options=("FileNet Content Manager" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Business Automation Workflow" "(a) Workflow Authoring" "(b) Workflow Runtime" "Automation Workstream Services" "IBM Automation Document Processing" "(a) Development Environment" "(b) Runtime Environment" "Workflow Process Service Authoring")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow" "workflow-authoring" "workflow-runtime" "workstreams" "document_processing" "document_processing_designer" "document_processing_runtime" "workflow-process-service")
            foundation_0=("BAN" "RR")                 # Foundation for FileNet Content Manager
            foundation_1=("BAN" "RR")                 # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR" "UMS")     # Foundation for Automation Decision Services
            foundation_3=("BAN" "RR" "UMS" "AE")     # Foundation for Business Automation Applications (full)
            foundation_4=("BAN" "RR")           # Foundation for dummy
            foundation_5=("BAN" "RR" "UMS" "BAS")          # Foundation for Business Automation Workflow - Workflow Authoring (5a)
            foundation_6=("BAN" "RR" "UMS" "AE")           # Foundation for Business Automation Workflow - Workflow Runtime (5b)
            foundation_7=("BAN" "RR" "UMS" "AE")           # Foundation for Automation Workstream Services (6)
            foundation_8=("BAN" "RR")  # Foundation for IBM Automation Document Processing
            foundation_9=("BAN" "RR" "AE" "BAS" "UMS")  # Foundation for IBM Automation Document Processing - 7a Development Environment
            foundation_10=("BAN" "RR" "AE" "UMS")  # Foundation for IBM Automation Document Processing - 7b Runtime Environment
            foundation_11=("BAS")           # Foundation for Workflow Process Service Authoring
            foundation_12=("BAN" "RR" "UMS" "AE")           # Foundation for Business Automation Workflow and workstreams(5b+6)
        fi
    else
        if [[ "${DEPLOYMENT_TYPE}" == "starter" ]];
        then
            options=("FileNet Content Manager" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Business Automation Workflow Authoring and Automation Workstream Services" "IBM Automation Document Processing")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow-workstreams" "document_processing")
            foundation_0=("BAN" "RR")                 # Foundation for FileNet Content Manager
            foundation_1=("BAN" "RR")                # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR")     # Foundation for Automation Decision Services
            foundation_3=("RR" "BAS")     # Foundation for Business Automation Applications (full)
            foundation_4=("RR" "AE" "BAS")           # Foundation for Business Automation Workflow and workstreams(Demo)
            foundation_5=("BAN" "RR" "AE" "BAS")  # Foundation for IBM Automation Document Processing
        else
            options=("FileNet Content Manager" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Business Automation Workflow" "(a) Workflow Authoring" "(b) Workflow Runtime" "Automation Workstream Services" "IBM Automation Document Processing" "(a) Development Environment" "(b) Runtime Environment" "Workflow Process Service Authoring")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow" "workflow-authoring" "workflow-runtime" "workstreams" "document_processing" "document_processing_designer" "document_processing_runtime" "workflow-process-service")
            foundation_0=("BAN" "RR")                 # Foundation for FileNet Content Manager
            foundation_1=("BAN" "RR")                 # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR")     # Foundation for Automation Decision Services
            foundation_3=("BAN" "RR" "AE")     # Foundation for Business Automation Applications (full)
            foundation_4=("BAN" "RR")           # Foundation for dummy
            foundation_5=("BAN" "RR" "BAS")           # Foundation for Business Automation Workflow - Workflow Authoring (5a)
            foundation_6=("BAN" "RR" "AE")           # Foundation for Business Automation Workflow - Workflow Runtime (5b)
            foundation_7=("BAN" "RR" "AE")           # Foundation for Automation Workstream Services (6)
            foundation_8=("BAN" "RR")  # Foundation for IBM Automation Document Processing
            foundation_9=("BAN" "RR" "AE" "BAS")  # Foundation for IBM Automation Document Processing - 7a Development Environment
            foundation_10=("BAN" "RR" "AE")  # Foundation for IBM Automation Document Processing - 7b Runtime Environment
            foundation_11=("BAS")           # Foundation for Workflow Process Service Authoring
            foundation_12=("BAN" "RR" "AE")           # Foundation for Business Automation Workflow and workstreams(5b+6)
        fi
    fi
    patter_ent_input_array=("1" "2" "3" "4" "5a" "5b" "5A" "5B" "6" "7a" "7b" "7A" "7B" "8" "5b,6" "5B,6" "5b, 6" "5B, 6" "5b 6" "5B 6")
    tips1="\x1B[1;31mTips\x1B[0m:\x1B[1mPress [ENTER] to accept the default (None of the patterns is selected)\x1B[0m"
    tips2="\x1B[1;31mTips\x1B[0m:\x1B[1mPress [ENTER] when you are done\x1B[0m"
    pattern_starter_tips="\x1B[1mInfo: Except pattern (4/5), Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Business Automation foundation platform. \n\nTips:  After you make your first selection you will be able to make additional selections since you can combine multiple selections.\n\x1B[0m"
    pattern_production_tips="\x1B[1mInfo: Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Business Automation foundation platform. \n\nTips:  After you make your first selection you will be able to make additional selections since you can combine multiple selections.\n\x1B[0m"
    baw_iaws_tips="\x1B[1mInfo: Note that Business Automation Workflow Authoring (5a) cannot be installed together with Automation Workstream Services (6). However, Business Automation Workflow Runtime (5b) can be installed together with Automation Workstream Services (6).\n\x1B[0m"
    linux_starter_tips="\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mIBM Automation Document Processing (6) does NOT support a cluster running a Linux on Z (s390x)/Power architecture.\n\x1B[0m"
    linux_production_tips="\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mIBM Automation Document Processing (7a/7b) does NOT support a cluster running a Linux on Z (s390x)/Power architecture.\n\x1B[0m"
    content_deployed_tips="\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31m\"FileNet Content Manager\" can not be selected because one Content (Kind: content.icp4a.ibm.com) custom resource was deployed.\n\x1B[0m"
    indexof() {
        i=-1
        for ((j=0;j<${#options_cr_val[@]};j++));
        do [ "${options_cr_val[$j]}" = "$1" ] && { i=$j; break; }
        done
        echo $i
    }
    menu() {
        clear
        echo -e "\x1B[1mSelect the Cloud Pak for Business Automation capability to install: \x1B[0m"
        for i in ${!options[@]}; do
            if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                containsElement "${options_cr_val[i]}" "${EXISTING_PATTERN_ARR[@]}"
                retVal=$?
                if [ $retVal -ne 0 ]; then
                    printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                else
                    if [[ "${choices_pattern[i]}" == "(To Be Uninstalled)" ]]; then
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                    else
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Installed)"
                    fi
                fi
            elif [[ $DEPLOYMENT_TYPE == "production" ]]
            then
                containsElement "${options_cr_val[i]}" "${EXISTING_PATTERN_ARR[@]}"
                retVal=$?
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") ]]; then
                    wwVal=0
                elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" ]]; then
                    wwVal=1
                fi
                containsElement "baw_authoring" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                baw_authoring_Val=$?
                containsElement "document_processing_designer" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                document_processing_designer_Val=$?
                containsElement "document_processing_runtime" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                document_processing_runtime_Val=$?
                if [[ $retVal -ne 0 ]]; then
                    case "$i" in
                    "7") # for Automation Workstream Services
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" 6 "${options[i]}"  "${choices_pattern[i]}"
                        ;;
                    "8")
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "${choices_pattern[i]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                        ;;
                    "9") # for wfps
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" 8 "${options[i+2]}"  "${choices_pattern[i+2]}"
                        ;;
                    "4") # 5 for Workflow Authoring, 6 for Workflow Runtime
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                        ;;
                    "0"|"1"|"2"|"3")
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                        ;;
                    esac
                else
                    if [[ "${choices_pattern[i]}" == "(To Be Uninstalled)" ]]; then
                        case "$i" in
                        "7") # for Automation Workstream Services
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" 6 "${options[i]}"  "${choices_pattern[i]}"
                            ;;
                        "4") # 5 for Workflow Authoring, 6 for Workflow Runtime
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                            printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                            printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            ;;
                        "0"|"1"|"2"|"3"|"4")
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                            ;;
                        "8") # 9 for Development Environment, 10 for Runtime Environment,
                            # if [[ "${choices_pattern[i+1]}" == "(Selected)" || "${choices_pattern[i+2]}" == "(Selected)" ]]; then
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "${choices_pattern[i]}"
                            printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                            printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            ;;
                        "9") # for wfps
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" 8 "${options[i+2]}"  "${choices_pattern[i+2]}"
                            ;;
                        esac
                    else
                        case "$i" in
                        "7") # for Automation Workstream Services
                            if [[ (${choices_pattern[6]} == "(To Be Uninstalled)" && ${choices_pattern[7]} == "(To Be Uninstalled)") ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 6 "${options[i]}"  "${choices_pattern[i]}"
                            else
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 6 "${options[i]}"  "(Installed)"
                            fi
                            ;;
                        "4") # 5 for Workflow Authoring, 6 for Workflow Runtime
                            if [[ ${choices_pattern[6]} == "(To Be Uninstalled)" && ${choices_pattern[7]} == "(To Be Uninstalled)" && ${choices_pattern[5]} == "" ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(To Be Uninstalled)"
                                if [[ $baw_authoring_Val -eq 0 ]]; then
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                                else
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                                fi
                            elif [[ ${choices_pattern[6]} == "(To Be Uninstalled)" && ${choices_pattern[7]} == "(To Be Uninstalled)" && ${choices_pattern[5]} == "(Selected)" ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            elif [[ $baw_authoring_Val -eq 0 && ${choices_pattern[5]} == "(To Be Uninstalled)" && ${choices_pattern[6]} != "" ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"   "${choices_pattern[i]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"   "${choices_pattern[i+1]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            elif [[ $baw_authoring_Val -eq 0 && ${choices_pattern[5]} == "(To Be Uninstalled)" && ${choices_pattern[6]} == "" ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"   "(To Be Uninstalled)"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"   "${choices_pattern[i+1]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            else
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"   "(Installed)"
                                if [[ $baw_authoring_Val -eq 0 ]]; then
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "(Installed)"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                                else
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "(Installed)"
                                fi
                            fi
                            ;;
                        "0"|"1"|"2"|"3")
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Installed)"
                            ;;
                        "8")
                            if [[ ${choices_pattern[9]} == "" && ${choices_pattern[10]} == "" ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "(Installed)"
                                if [[ $document_processing_designer_Val -eq 0 ]]; then
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "(Installed)"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i]}"
                                elif [[ $document_processing_runtime_Val -eq 0 ]]
                                then
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i]}"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "(Installed)"
                                fi
                            elif [[ (${choices_pattern[9]} == "(To Be Uninstalled)" && ${choices_pattern[10]} == "(Selected)") || (${choices_pattern[9]} == "(Selected)" && ${choices_pattern[10]} == "(To Be Uninstalled)") ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "(Selected)"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            elif [[ (${choices_pattern[8]} == "(Selected)" && ${choices_pattern[9]} == "(To Be Uninstalled)") || (${choices_pattern[8]} == "(Selected)" && ${choices_pattern[10]} == "(To Be Uninstalled)") ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "(To Be Uninstalled)"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            fi
                            ;;
                        "9") # for wfps
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" 8 "${options[i+2]}"  "(Installed)"
                            ;;
                        esac
                   fi
                fi
            fi
        done
        if [[ "$msg" ]]; then echo "$msg"; fi
        printf "\n"
        if [[ $DEPLOYMENT_TYPE == "production" ]]; then
            echo -e "${baw_iaws_tips}"
        fi

        if [[ $DEPLOYMENT_TYPE == "production" ]]; then
            echo -e "${pattern_production_tips}"
            echo -e "${linux_production_tips}"
            if [[ $CONTENT_DEPLOYED == "Yes" ]]; then
                echo -e "${content_deployed_tips}"
            fi
        else
            echo -e "${pattern_starter_tips}"
            echo -e "${linux_starter_tips}"
        fi
        # Show different tips according components select or unselect
        containsElement "(Selected)" "${choices_pattern[@]}"
        retVal=$?
        if [ $retVal -ne 0 ]; then
            echo -e "${tips1}"
        else
            echo -e "${tips2}"
        fi
# ##########################DEBUG############################
#     for i in "${!choices_pattern[@]}"; do
#         printf "%s\t%s\n" "$i" "${choices_pattern[$i]}"
#     done
# ##########################DEBUG############################
    }

    if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
        prompt="Enter a valid option [1 to ${#options[@]}]: "
    elif [[ $DEPLOYMENT_TYPE == "production" ]]
    then
        prompt="Enter a valid option [1 to 4, 5a, 5b, 6, 7a, 7b, 8]: "
    fi

    while menu && read -rp "$prompt" num && [[ "$num" ]]; do
        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
            [[ "$num" != *[![:digit:]]* ]] &&
            (( num > 0 && num <= ${#options[@]} )) ||
            { msg="Invalid option: $num"; continue; }
            ((num--));
        elif [[ $DEPLOYMENT_TYPE == "production" ]]
        then
            containsElement "${num}" "${patter_ent_input_array[@]}"
            inputretVal=$?
            [[ "${inputretVal}" -eq 0 ]] ||
            { msg="Invalid option: $num"; continue; }
            case "$num" in
            "5a"|"5A")
                num=5
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then
                    choices_pattern[6]=""
                    choices_pattern[7]=""
                elif [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && (${choices_pattern[6]} == "" || ${choices_pattern[7]} == "") ]]; then
                    choices_pattern[5]="(Selected)"
                elif [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && (${choices_pattern[6]} == "(To Be Uninstalled)") && (${choices_pattern[7]} == "(To Be Uninstalled)") ]]; then
                    num=5
                elif [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring") && ${choices_pattern[5]} == "(To Be Uninstalled)" && (${choices_pattern[6]} == "(Selected)" || ${choices_pattern[7]} == "(Selected)") ]]; then
                    num=5
                fi
                ;;
            "5b"|"5B")
                num=6
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then

                    choices_pattern[5]=""
                elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" && ${choices_pattern[5]} == "(Selected)" ]]; then

                    choices_pattern[6]=""
                elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring" ]]; then
                        if [[ ${choices_pattern[5]} == "(To Be Uninstalled)" ]]; then

                            num=6
                        elif [[ ${choices_pattern[5]} == "(Selected)" || ${choices_pattern[5]} == "" ]]; then
                            choices_pattern[6]="(Selected)"
                            # choices_pattern[7]=""
                        fi
                fi
                ;;
            6)
                num=7
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then
                    choices_pattern[5]=""
                elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring" ]]; then
                        if [[ ${choices_pattern[5]} == "(To Be Uninstalled)" ]]; then
                            num=7
                        elif [[ ${choices_pattern[5]} == "(Selected)" || ${choices_pattern[5]} == "" ]]; then
                            choices_pattern[7]="(Selected)"
                            # choices_pattern[7]=""
                        fi
                fi
                ;;
            "5b,6"|"5B,6"|"5b, 6"|"5B, 6"|"5b 6"|"5B 6")
                num=12
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then
                    choices_pattern[5]=""
                else
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring" || ${choices_pattern[5]} == "" ]]; then
                        choices_pattern[6]="(Selected)"
                        choices_pattern[7]="(Selected)"
                    fi
                fi
                ;;
            "1"|"2"|"3"|"4")
                ((num--))
                ;;
            "7a"|"7A")
                num=9
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") ]]; then
                    choices_pattern[10]=""
                else
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer" && ${choices_pattern[10]} == "" ]]; then
                        num=9
                    elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer" && ${choices_pattern[10]} == "(Selected)" ]]; then
                        choices_pattern[9]=""
                        choices_pattern[8]=""
                    elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_runtime" && ${choices_pattern[10]} == "" ]]; then
                        choices_pattern[9]="(Selected)"
                    fi
                fi
                ;;
            "7b"|"7B")
                num=10
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") ]]; then
                    choices_pattern[9]=""
                else
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_runtime" && ${choices_pattern[9]} == "" ]]; then
                        num=10
                    elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_runtime" && ${choices_pattern[9]} == "(Selected)" ]]; then
                        choices_pattern[10]=""
                        choices_pattern[8]=""
                    elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer" && ${choices_pattern[9]} == "" ]]; then
                        choices_pattern[10]="(Selected)"
                    fi
                fi
                ;;
            "8")
                num=11
                ;;
            esac
        else
            echo "Deployment type is invalid"
            exit 0
        fi
        containsElement "${options_cr_val[num]}" "${EXISTING_PATTERN_ARR[@]}"
        retVal=$?
        containsElement "baw_authoring" "${EXISTING_OPT_COMPONENT_ARR[@]}"
        baw_authoring_Val=$?
        if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") ]]; then
            wwVal=0
        elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" ]]; then
            wwVal=1
        fi

        if [[ $retVal -ne 0 ]]; then
            if [[ ($num -eq 12) && ($wwVal -eq 0) ]]; then
                [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(Selected)"
                [[ "${choices_pattern[num]}" ]] && choices_pattern[4]="(Selected)" || choices_pattern[4]=""
                [[ "${choices_pattern[num]}" ]] && choices_pattern[6]="(Selected)" || choices_pattern[6]=""
                [[ "${choices_pattern[num]}" ]] && choices_pattern[7]="(Selected)" || choices_pattern[7]=""
            elif [[ ($num -eq 12) && ($wwVal -eq 1) ]]; then
                if [[ ${choices_pattern[4]} == "(Selected)" && ${choices_pattern[5]} == "(Selected)" ]]; then
                    choices_pattern[6]="(To Be Uninstalled)"
                    choices_pattern[7]="(To Be Uninstalled)"
                    choices_pattern[12]="(To Be Uninstalled)"
                else
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[4]="(To Be Uninstalled)" || choices_pattern[4]=""
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[6]="(To Be Uninstalled)" || choices_pattern[6]=""
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[7]="(To Be Uninstalled)" || choices_pattern[7]=""
                fi
            else
                [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(Selected)"
            fi
            if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                if [[ ${choices_pattern[5]} == "(Selected)" || ${choices_pattern[6]} == "(Selected)"  ]]; then
                    choices_pattern[4]="(Selected)"
                fi
                if  [[ "${choices_pattern[5]}" == "" && "${choices_pattern[6]}" == "" ]]; then
                    choices_pattern[4]=""
                fi
                if [[ ${choices_pattern[9]} == "(Selected)" || ${choices_pattern[10]} == "(Selected)"  ]]; then
                    choices_pattern[8]="(Selected)"
                fi
                if  [[ "${choices_pattern[9]}" == "" && "${choices_pattern[10]}" == "" ]]; then
                    choices_pattern[8]=""
                fi
                if [[ ${choices_pattern[0]} == "(Selected)" && "$CONTENT_DEPLOYED" == "Yes" && "$INSTALLATION_TYPE" == "new" ]]; then
                    choices_pattern[0]=""
                fi
            fi
        else
            if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
            elif [[ $DEPLOYMENT_TYPE == "production" ]]
            then
                case "$num" in
                "5")
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring" && ("${choices_pattern[6]}" == "(Selected)" || "${choices_pattern[7]}" == "(Selected)") ]]; then
                        choices_pattern[num]="(To Be Uninstalled)"
                    else
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num-1]="" || choices_pattern[num-1]="(To Be Uninstalled)"
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    fi
                    ;;
                "6")
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" && "${choices_pattern[7]}" == "(To Be Uninstalled)" ]]; then
                        if [[ "${choices_pattern[5]}" == "" ]]; then
                            if [[ choices_pattern[num]="(To Be Uninstalled)" ]]; then
                                choices_pattern[num]="(To Be Uninstalled)"
                            else
                                choices_pattern[num]=""
                            fi
                        elif [[ "${choices_pattern[5]}" == "(Selected)" ]]; then
                            choices_pattern[num]="(To Be Uninstalled)"
                        fi

                        # choices_pattern[num-2]="(Installed)"
                    elif  [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" && "${choices_pattern[7]}" == "" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" && "${choices_pattern[6]}" == "" ]]; then
                        choices_pattern[num]=""
                    else
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num-2]="" || choices_pattern[num-2]="(To Be Uninstalled)"
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    fi
                    ;;
                "7")
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && "${choices_pattern[6]}" == "(To Be Uninstalled)" ]]; then
                        if [[ "${choices_pattern[5]}" == "" ]]; then
                            if [[ choices_pattern[num]="(To Be Uninstalled)" ]]; then
                                choices_pattern[num]="(To Be Uninstalled)"
                            else
                                choices_pattern[num]=""
                            fi
                        elif [[ "${choices_pattern[5]}" == "(Selected)" ]]; then
                            choices_pattern[num]="(To Be Uninstalled)"
                        fi

                        # choices_pattern[num-2]="(Installed)"
                    elif  [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && "${choices_pattern[7]}" == "" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" && "${choices_pattern[6]}" == "" ]]; then
                        choices_pattern[num]=""
                    else
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    fi
                    ;;
                "9")
                    if [[ ${choices_pattern[10]} == "(Selected)" ]]; then
                        choices_pattern[8]="(Selected)"
                    else
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num-1]="" || choices_pattern[num-1]="(To Be Uninstalled)"
                    fi
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    ;;
                "10")
                    if [[ ${choices_pattern[9]} == "(Selected)" ]]; then
                        choices_pattern[8]="(Selected)"
                    else
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num-2]="" || choices_pattern[num-2]="(To Be Uninstalled)"
                    fi
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    ;;
                "0"|"1"|"2"|"3")
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    ;;
                esac
            fi
        fi
    done

    # echo "choices_pattern: ${choices_pattern[*]}"
    # read -rsn1 -p"Press any key to continue (DEBUG MODEL)";echo
    # Generate list of the pattern which will be installed or To Be Uninstalled
    for i in ${!options[@]}; do
        array_varname=foundation_$i[@]
        containsElement "${options_cr_val[i]}" "${EXISTING_PATTERN_ARR[@]}"
        retVal=$?
        if [ $retVal -ne 0 ]; then
            [[ "${choices_pattern[i]}" ]] && { pattern_arr=( "${pattern_arr[@]}" "${options[i]}" ); pattern_cr_arr=( "${pattern_cr_arr[@]}" "${options_cr_val[i]}" ); msg=""; }
            [[ "${choices_pattern[i]}" ]] && { foundation_component_arr=( "${foundation_component_arr[@]}" "${!array_varname}" ); }
        else
            if [[ "${choices_pattern[i]}" == "(To Be Uninstalled)" ]]; then
                pos=`indexof "${pattern_cr_arr[i]}"`
                if [[ "$pos" != "-1" ]]; then
                { pattern_cr_arr=(${pattern_cr_arr[@]:0:$pos} ${pattern_cr_arr[@]:$(($pos + 1))}); pattern_arr=(${pattern_arr[@]:0:$pos} ${pattern_arr[@]:$(($pos + 1))}); }

                fi
            else
                { pattern_arr=( "${pattern_arr[@]}" "${options[i]}" ); pattern_cr_arr=( "${pattern_cr_arr[@]}" "${options_cr_val[i]}" ); msg=""; }
                { foundation_component_arr=( "${foundation_component_arr[@]}" "${!array_varname}" ); }
            fi
        fi
    done
    echo -e "$msg"

    # 4Q: add workflow-workstream into pattern list when select both workflow-runtime and workstream
    if [[ " ${pattern_cr_arr[@]} " =~ "workflow" && " ${pattern_cr_arr[@]} " =~ "workstreams" && "${DEPLOYMENT_TYPE}" == "production" ]]; then
        pattern_cr_arr=( "${pattern_cr_arr[@]}" "workflow-workstreams" )
        if [[ $PLATFORM_SELECTED == "other" ]]; then
            foundation_ww=("BAN" "RR" "UMS" "AE")
        else
            foundation_ww=("BAN" "RR" "AE")
        fi
        foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_ww[@]}" )
    fi

    if [ "${#pattern_arr[@]}" -eq "0" ]; then
        PATTERNS_SELECTED="None"
        printf "\x1B[1;31mPlease select one pattern at least, exiting... \n\x1B[0m"
        exit 1
    else
        PATTERNS_SELECTED=$( IFS=$','; echo "${pattern_arr[*]}" )
        PATTERNS_CR_SELECTED=$( IFS=$','; echo "${pattern_cr_arr[*]}" )

    fi
    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
        select_ae_data_persistence
        AUTOMATION_SERVICE_ENABLE="No"
    fi
    # select_cpe_full_storage
    FOUNDATION_CR_SELECTED=($(echo "${foundation_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    x=0;while [ ${x} -lt ${#FOUNDATION_CR_SELECTED[*]} ] ; do FOUNDATION_CR_SELECTED_LOWCASE[$x]=$(tr [A-Z] [a-z] <<< ${FOUNDATION_CR_SELECTED[$x]}); let x++; done
    FOUNDATION_DELETE_LIST=($(echo "${FOUNDATION_CR_SELECTED[@]}" "${FOUNDATION_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))

    PATTERNS_CR_SELECTED=($(echo "${pattern_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

function select_optional_component(){
# This function support mutiple checkbox, if do not select anything, it will return
    OPT_COMPONENTS_CR_SELECTED=()
    OPTIONAL_COMPONENT_DELETE_LIST=()
    KEEP_COMPOMENTS=()
    OPT_COMPONENTS_SELECTED=()
    optional_component_arr=()
    optional_component_cr_arr=()
    BAI_SELECTED=""
    show_optional_components(){
        COMPONENTS_SELECTED=""
        choices_component=()
        component_arr=()

        tips1="\x1B[1;31mTips\x1B[0m:\x1B[1m Press [ENTER] if you do not want any optional components or when you are finished selecting your optional components\x1B[0m"
        tips2="\x1B[1;31mTips\x1B[0m:\x1B[1m Press [ENTER] when you are done\x1B[0m"
        fncm_tips="\x1B[1mNote: IBM Enterprise Records (IER) and IBM Content Collector for SAP (ICCSAP) do not integrate with User Management Service (UMS).\n"
        linux_starter_tips="\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mIBM Content Collector for SAP (4) does NOT support a cluster running a Linux on Power architecture.\n\x1B[0m"
        linux_production_tips="\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mIBM Content Collector for SAP (5) does NOT support a cluster running a Linux on Power architecture.\n\x1B[0m"
        ads_tips="\x1B[1mTips:\x1B[0m Decision Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present. \n\nDecision Runtime is typically recommended if you are deploying a test or production environment. \n\nYou should choose at least one these features to have a minimum environment configuration.\n"
        if [[ $DEPLOYMENT_TYPE == "starter" ]];then
            decision_tips="\x1B[1mTips:\x1B[0m Decision Center, Rule Execution Server and Decision Runner will be installed by default.\n"
        else
            decision_tips="\x1B[1mTips:\x1B[0m Decision Center is typically required for development and testing environments. \nRule Execution Server is typically required for testing and production environments and for using Business Automation Insights. \nYou should choose at least one these 2 features to have a minimum environment configuration. \n"
        fi
        application_tips_demo="\x1B[1mTips:\x1B[0m Application Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present.  \n\nMake your selection or press enter to proceed. \n"
        application_tips_ent="\x1B[1mTips:\x1B[0m Application Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present. \n\nApplication Engine is automatically installed in the environment.  \n\nMake your selection or press enter to proceed. \n"

        indexof() {
            i=-1
            for ((j=0;j<${#optional_component_cr_arr[@]};j++));
            do [ "${optional_component_cr_arr[$j]}" = "$1" ] && { i=$j; break; }
            done
            echo $i
        }
        menu() {
            clear
            echo -e "\x1B[1;31mPattern \"$item_pattern\": \x1B[0m\x1B[1mSelect optional components: \x1B[0m"
            # echo -e "\x1B[1mSelect optional components: \x1B[0m"
            containsElement "bai" "${EXISTING_OPT_COMPONENT_ARR[@]}"
            bai_cr_retVal=$?
            for i in ${!optional_components_list[@]}; do
                if [[ ("${choices_component[i]}" == "(Selected)" || "${choices_component[i]}" == "(Installed)") && "${optional_components_list[i]}" == "Business Automation Insights" ]];then
                    BAI_SELECTED="Yes"
                elif [[ ( $bai_cr_retVal -ne 0 || "${choices_component[i]}" == "(To Be Uninstalled)") && "${optional_components_list[i]}" == "Business Automation Insights" ]]
                then
                    BAI_SELECTED="No"
                fi
            done

            for i in ${!optional_components_list[@]}; do
                containsElement "${optional_components_cr_list[i]}" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                retVal=$?
                containsElement "${optional_components_cr_list[i]}" "${optional_component_cr_arr[@]}"
                selectedVal=$?
                if [ $retVal -ne 0 ]; then
                    if [[ "${item_pattern}" == "FileNet Content Manager" || ( "${item_pattern}" == "Operational Decision Manager" && "${DEPLOYMENT_TYPE}" == "production" ) ]];then
                        if [[ "${optional_components_list[i]}" == "User Management Service" && "${BAI_SELECTED}" == "Yes" ]];then
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "(Selected)"
                        elif [ $selectedVal -ne 0 ]
                        then
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "${choices_component[i]}"
                        else
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "(Selected)"
                        fi
                    else
                        if [ $selectedVal -ne 0 ]; then
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "${choices_component[i]}"
                        else
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "(Selected)"
                        fi
                    fi
                else
                    if [[ "${optional_components_list[i]}" == "User Management Service" ]];then
                        if [[ "${choices_component[i]}" == "(To Be Uninstalled)" ]]; then
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "${choices_component[i]}"
                        else
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "(Installed)"
                        fi
                    elif [[ "${choices_component[i]}" == "(To Be Uninstalled)" ]]
                    then
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "${choices_component[i]}"
                    else
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "(Installed)"
                        if [[ "${optional_components_cr_list[i]}" == "bai" ]];then
                            BAI_SELECTED="Yes"
                        fi
                    fi
                fi
            done
            if [[ "$msg" ]]; then echo "$msg"; fi
            printf "\n"

            if [[ "${item_pattern}" == "Automation Decision Services" ]]; then
                echo -e "${ads_tips}"
            fi
            if [[ "${item_pattern}" == "Operational Decision Manager" ]]; then
                echo -e "\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31m You must select at least one of ODM components.\x1B[0m\n"
                echo -e "${decision_tips}"
            fi
            if [[ "${item_pattern}" == "Business Automation Application" ]]; then

                echo -e "${application_tips}"
                if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                    echo -e "${application_tips_demo}"
                elif [[ $DEPLOYMENT_TYPE == "production" ]]
                then
                    echo -e "${application_tips_ent}"
                fi
            fi

            if [[ "${item_pattern}" == "FileNet Content Manager" ]]; then
                if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                    echo -e "${linux_starter_tips}"
                elif [[ $DEPLOYMENT_TYPE == "production" ]]
                then
                    echo -e "${linux_production_tips}"
                fi
            fi
            # Show different tips according components select or unselect
            containsElement "(Selected)" "${choices_component[@]}"
            retVal=$?
            if [ $retVal -eq 0 ]; then
                echo -e "${tips2}"
            elif [ $selectedVal -eq 0 ]
            then
                echo -e "${tips2}"
            else
                echo -e "${tips1}"
            fi
# ##########################DEBUG############################
#         for i in "${!choices_component[@]}"; do
#             printf "%s\t%s\n" "$i" "${choices_component[$i]}"
#         done
# ##########################DEBUG############################
        }

        prompt="Enter a valid option [1 to ${#optional_components_list[@]} or ENTER]: "
        while menu && read -rp "$prompt" num && [[ "$num" ]]; do
            [[ "$num" != *[![:digit:]]* ]] &&
            (( num > 0 && num <= ${#optional_components_list[@]} )) ||
            { msg="Invalid option: $num"; continue; }
            if [[ "${item_pattern}" == "FileNet Content Manager" && "$DEPLOYMENT_TYPE" == "production" ]]; then
                case "$num" in
                "1"|"2"|"3"|"4"|"5"|"6"|"7"|"8")
                    ((num--))
                    ;;
                esac
            elif [[ "${item_pattern}" == "FileNet Content Manager" && "$DEPLOYMENT_TYPE" == "starter" ]]; then
                case "$num" in
                "1"|"2"|"3"|"4"|"5"|"6"|"7")
                    ((num--))
                    ;;
                esac
            else
                ((num--))
            fi
            containsElement "${optional_components_cr_list[num]}" "${EXISTING_OPT_COMPONENT_ARR[@]}"
            retVal=$?
            if [ $retVal -ne 0 ]; then
                [[ "${choices_component[num]}" ]] && choices_component[num]="" || choices_component[num]="(Selected)"
                if [[ $PLATFORM_SELECTED == "other" && ("${item_pattern}" == "FileNet Content Manager" || ("${item_pattern}" == "Operational Decision Manager" && "${DEPLOYMENT_TYPE}" == "production")) ]]; then
                    if [[ "${optional_components_cr_list[num]}" == "bai" && ${choices_component[num]} == "(Selected)" ]]; then
                        choices_component[num-1]="(Selected)"
                    fi
                    if [[ "${optional_components_cr_list[num]}" == "ums" && ${choices_component[num+1]} == "(Selected)" ]]; then
                        choices_component[num]="(Selected)"
                    fi
                fi
            else
                containsElement "ums" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                ums_retVal=$?
                containsElement "bai" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                bai_retVal=$?
                if [[ "${optional_components_cr_list[num]}" == "bai" && $ums_retVal -eq 0 ]];then
                    ((ums_check_num=num-1))
                    if [[ "${choices_component[num]}" == "(To Be Uninstalled)" ]];then
                        [[ "${choices_component[num]}" ]] && choices_component[num]="" || choices_component[num]=""
                        [[ "${choices_component[num]}" ]] && choices_component[num]="" || choices_component[ums_check_num]=""
                    else
                        [[ "${choices_component[num]}" ]] && choices_component[num]="" || choices_component[num]="(To Be Uninstalled)"
                    fi
                elif [[ "${optional_components_cr_list[num]}" == "ums" && $bai_retVal -eq 0 && ("${choices_component[num+1]}" == "" || "${choices_component[num+1]}" == "(Installed)") ]]
                then
                    [[ "${choices_component[num]}" ]] && choices_component[num]="" || choices_component[num]=""
                else
                    [[ "${choices_component[num]}" ]] && choices_component[num]="" || choices_component[num]="(To Be Uninstalled)"
                fi
            fi
        done

        # printf "\x1B[1mCOMPONENTS selected: \x1B[0m"; msg=" None"
        for i in ${!optional_components_list[@]}; do
            # [[ "${choices_component[i]}" ]] && { printf " \"%s\"" "${optional_components_list[i]}"; msg=""; }

            containsElement "${optional_components_cr_list[i]}" "${EXISTING_OPT_COMPONENT_ARR[@]}"
            retVal=$?
            if [ $retVal -ne 0 ]; then
                # [[ "${choices_component[i]}" ]] && { pattern_arr=( "${pattern_arr[@]}" "${options[i]}" ); pattern_cr_arr=( "${pattern_cr_arr[@]}" "${options_cr_val[i]}" ); msg=""; }
                if [[ "${optional_components_list[i]}" == "External Share" ]]; then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ExternalShare" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Task Manager" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "TaskManager" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Content Search Services" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ContentSearchServices" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Decision Center" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "DecisionCenter" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Rule Execution Server" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "RuleExecutionServer" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Decision Runner" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "DecisionRunner" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Decision Designer" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "DecisionDesigner" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Decision Runtime" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "DecisionRuntime" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Content Management Interoperability Services" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ContentManagementInteroperabilityServices" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "User Management Service" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "UserManagementService" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Business Automation Insights" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "BusinessAutomationInsights" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Process Federation Server" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ProcessFederationServer" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Data Collector and Data Indexer" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "DataCollectorandDataIndexer" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Exposed Kafka Services" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ExposedKafkaServices" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Exposed OpenSearch" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ExposedOpenSearch" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Business Automation Machine Learning" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "BusinessAutomationMachineLearning" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Application Designer" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ApplicationDesigner" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Business Automation Application Data Persistence" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "BusinessAutomationApplicationDataPersistence" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "IBM Enterprise Records" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "IBMEnterpriseRecords" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "IBM Content Collector for SAP" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "IBMContentCollectorforSAP" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Content Integration" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ContentIntegration" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "IBM Content Navigator" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "IBMContentNavigator" ); msg=""; }
                else
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "${optional_components_list[i]}" ); msg=""; }
                fi
                [[ "${choices_component[i]}" ]] && { optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "${optional_components_cr_list[i]}" ); msg=""; }
            else
                if [[ "${choices_component[i]}" == "(To Be Uninstalled)" ]]; then
                    pos=`indexof "${optional_component_cr_arr[i]}"`
                    if [[ "$pos" != "-1" ]]; then
                    { optional_component_cr_arr=(${optional_component_cr_arr[@]:0:$pos} ${optional_component_cr_arr[@]:$(($pos + 1))}); optional_component_arr=(${optional_component_arr[@]:0:$pos} ${optional_component_arr[@]:$(($pos + 1))}); }
                    fi
                else
                    if [[ "${optional_components_list[i]}" == "External Share" ]]; then
                        optional_component_arr=( "${optional_component_arr[@]}" "ExternalShare" )
                    elif [[ "${optional_components_list[i]}" == "Task Manager" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "TaskManager" )
                    elif [[ "${optional_components_list[i]}" == "Content Search Services" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ContentSearchServices" )
                    elif [[ "${optional_components_list[i]}" == "Decision Center" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "DecisionCenter" )
                    elif [[ "${optional_components_list[i]}" == "Rule Execution Server" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "RuleExecutionServer" )
                    elif [[ "${optional_components_list[i]}" == "Decision Runner" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "DecisionRunner" )
                    elif [[ "${optional_components_list[i]}" == "Decision Designer" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "DecisionDesigner" )
                    elif [[ "${optional_components_list[i]}" == "Decision Runtime" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "DecisionRuntime" )
                    elif [[ "${optional_components_list[i]}" == "Content Management Interoperability Services" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ContentManagementInteroperabilityServices" )
                    elif [[ "${optional_components_list[i]}" == "User Management Service" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "UserManagementService" )
                    elif [[ "${optional_components_list[i]}" == "Business Automation Insights" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "BusinessAutomationInsights" )
                    elif [[ "${optional_components_list[i]}" == "Process Federation Server" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ProcessFederationServer" )
                    elif [[ "${optional_components_list[i]}" == "Data Collector and Data Indexer" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "DataCollectorandDataIndexer" )
                    elif [[ "${optional_components_list[i]}" == "Exposed Kafka Services" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ExposedKafkaServices" )
                    elif [[ "${optional_components_list[i]}" == "Exposed OpenSearch" ]]
                    then
                        [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ExposedOpenSearch" ); msg=""; }
                    elif [[ "${optional_components_list[i]}" == "Business Automation Machine Learning" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "BusinessAutomationMachineLearning" )
                    elif [[ "${optional_components_list[i]}" == "Application Designer" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ApplicationDesigner" )
                    elif [[ "${optional_components_list[i]}" == "Business Automation Application Data Persistence" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "BusinessAutomationApplicationDataPersistence" )
                    elif [[ "${optional_components_list[i]}" == "IBM Enterprise Records" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "IBMEnterpriseRecords" )
                    elif [[ "${optional_components_list[i]}" == "IBM Content Collector for SAP" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "IBMContentCollectorforSAP" )
                    elif [[ "${optional_components_list[i]}" == "Content Integration" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ContentIntegration" )
                    elif [[ "${optional_components_list[i]}" == "IBM Content Navigator" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "IBMContentNavigator" )
                    else
                        optional_component_arr=( "${optional_component_arr[@]}" "${optional_components_list[i]}" )
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "${optional_components_cr_list[i]}" )
                fi
            fi
        done
        # echo -e "$msg"

        if [ "${#optional_component_arr[@]}" -eq "0" ]; then
            COMPONENTS_SELECTED="None"
        else
            OPT_COMPONENTS_CR_SELECTED=$( IFS=$','; echo "${optional_component_arr[*]}" )

        fi
    }
    for item_pattern in "${pattern_arr[@]}"; do
        while true; do
            case $item_pattern in
                "FileNet Content Manager")
                    # echo "select $item_pattern pattern optional components"
                    if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                        optional_components_list=("Content Search Services" "Content Management Interoperability Services" "IBM Enterprise Records" "IBM Content Collector for SAP" "Business Automation Insights" "Task Manager")
                        optional_components_cr_list=("css" "cmis" "ier" "iccsap" "bai" "tm")
                    elif [[ $DEPLOYMENT_TYPE == "production" ]]
                    then
                        if [[ $PLATFORM_SELECTED == "other" ]]; then
                            optional_components_list=("Content Search Services" "Content Management Interoperability Services" "IBM Enterprise Records" "IBM Content Collector for SAP" "User Management Service" "Business Automation Insights" "Task Manager")
                            optional_components_cr_list=("css" "cmis" "ier" "iccsap" "ums" "bai" "tm")
                        else
                            optional_components_list=("Content Search Services" "Content Management Interoperability Services" "IBM Enterprise Records" "IBM Content Collector for SAP" "Business Automation Insights" "Task Manager")
                            optional_components_cr_list=("css" "cmis" "ier" "iccsap" "bai" "tm")
                        fi
                    fi
                    show_optional_components
                    if [[ $PLATFORM_SELECTED == "other" ]]; then
                        containsElement "bai" "${optional_component_cr_arr[@]}"
                        retVal=$?
                        if [[ $retVal -eq 0 ]]; then
                            optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ums" )
                            optional_component_arr=( "${optional_component_arr[@]}" "UserManagementService" )
                        fi
                    fi
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "Document Processing Engine")
                    # echo "Without optional components for $item_pattern pattern."
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "Operational Decision Manager")
                    # echo "select $item_pattern pattern optional components"
                    if [[ "${DEPLOYMENT_TYPE}" == "starter" ]]; then
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "decisionCenter" )
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "decisionServerRuntime" )
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "decisionRunner" )
                        optional_components_list=("Business Automation Insights")
                        optional_components_cr_list=("bai")
                    else
                        if [[ $PLATFORM_SELECTED == "other" ]]; then
                            optional_components_list=("Decision Center" "Rule Execution Server" "Decision Runner" "User Management Service" "Business Automation Insights")
                            optional_components_cr_list=("decisionCenter" "decisionServerRuntime" "decisionRunner" "ums" "bai")
                        else
                            optional_components_list=("Decision Center" "Rule Execution Server" "Decision Runner" "Business Automation Insights")
                            optional_components_cr_list=("decisionCenter" "decisionServerRuntime" "decisionRunner" "bai")
                        fi
                    fi
                        show_optional_components
                        if [[ $PLATFORM_SELECTED == "other" ]]; then
                            containsElement "bai" "${optional_component_cr_arr[@]}"
                            retVal=$?
                            if [[ $retVal -eq 0 ]]; then
                                optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ums" )
                                optional_component_arr=( "${optional_component_arr[@]}" "UserManagementService" )
                            fi
                        fi
                        optional_components_list=()
                        optional_components_cr_list=()
                    break
                    ;;
                "Automation Decision Services")
                    # echo "select $item_pattern pattern optional components"
                    if [[ "${DEPLOYMENT_TYPE}" == "starter" ]]; then
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ads_designer" )
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ads_runtime" )
                        optional_components_list=("Business Automation Insights")
                        optional_components_cr_list=("bai")
                        show_optional_components
                        optional_components_list=()
                        optional_components_cr_list=()
                    else
                        optional_components_list=("Business Automation Insights" "Decision Designer" "Decision Runtime")
                        optional_components_cr_list=("bai" "ads_designer" "ads_runtime")
                        show_optional_components
                        optional_components_list=()
                        optional_components_cr_list=()
                    fi
                    break
                    ;;
                "Business Automation Workflow")
                    # The logic for BAW only in 4Q
                    if [[ $DEPLOYMENT_TYPE == "starter" && $retVal_baw -eq 0 ]]; then
                        optional_components_list=("Business Automation Insights")
                        optional_components_cr_list=("bai")
                        show_optional_components
                    fi
                    if [[ $DEPLOYMENT_TYPE == "production" && $retVal_baw -eq 0 ]]; then
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "bai" )
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ae_data_persistence" )
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "(a) Workflow Authoring")
                    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                        optional_components_list=("Business Automation Insights" "Data Collector and Data Indexer" "Exposed Kafka Services")
                        optional_components_cr_list=("bai" "pfs" "kafka")
                        show_optional_components
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "baw_authoring" )
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "(b) Workflow Runtime")
                    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                        optional_components_list=("Business Automation Insights" "Exposed Kafka Services" "Exposed OpenSearch")
                        optional_components_cr_list=("bai" "kafka" "opensearch")
                        show_optional_components
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    # optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "bai" )
                    # if [[ ! ((" ${pattern_cr_arr[@]} " =~ "workflow-runtime" && "${#pattern_cr_arr[@]}" -eq "2") || (" ${pattern_cr_arr[@]} " =~ "workflow-runtime" && " ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "4")) ]]; then
                    #     optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ae_data_persistence" )
                    # fi
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "Business Automation Workflow Authoring and Automation Workstream Services")
                    if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                        optional_components_list=("Case" "Content Integration" "Workstreams" "Data Collector and Data Indexer" "Business Automation Insights" "Business Automation Machine Learning")
                        optional_components_cr_list=("case" "content_integration" "workstreams" "pfs" "bai" "baml")
                        show_optional_components
                    # elif [[ $DEPLOYMENT_TYPE == "production" ]]; then
                    #     optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "bai" )
                    #     optional_component_arr=( "${optional_component_arr[@]}" "BusinessAutomationInsights" )
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "baw_authoring" )
                    if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                        containsElement "baml" "${optional_component_cr_arr[@]}"
                        retVal=$?
                        if [[ $retVal -eq 0 ]]; then
                            optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "bai" "pfs")
                            optional_component_arr=( "${optional_component_arr[@]}" "BusinessAutomationInsights" "ProcessFederationServer")
                        fi
                    fi
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "Automation Workstream Services")
                    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                        optional_components_list=("Exposed Kafka Services" "Exposed OpenSearch")
                        optional_components_cr_list=("kafka" "opensearch")
                        show_optional_components
                    fi
                    # echo "Without optional components for $item_pattern pattern."
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    # if [[ ! ((" ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "1") || (" ${pattern_cr_arr[@]} " =~ "workflow-runtime" && " ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "4")) ]]; then
                    #     optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ae_data_persistence" )
                    # fi
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "Business Automation Application")
                    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                        # echo "select $item_pattern pattern optional components"
                        optional_components_list=("Application Designer")
                        optional_components_cr_list=("app_designer")
                        show_optional_components
                        optional_components_list=()
                        optional_components_cr_list=()
                    else
                        if [[ ! (" ${pattern_cr_arr[@]} " =~ "content" || " ${pattern_cr_arr[@]} " =~ "document_processing" || " ${pattern_cr_arr[@]} " =~ "workflow") ]]; then
                            optional_components_list=("IBM Content Navigator")
                            optional_components_cr_list=("ban")
                            show_optional_components
                        fi
                        optional_components_list=()
                        optional_components_cr_list=()
                    fi
                    break
                    ;;
                "Automation Digital Worker")
                    optional_components_list=("Business Automation Insights")
                    optional_components_cr_list=("bai")
                    show_optional_components
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "IBM Automation Document Processing")
                    if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                        optional_components_list=("Content Search Services" "Content Management Interoperability Services" "Task Manager")
                        optional_components_cr_list=("css" "cmis" "tm")
                        show_optional_components
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "document_processing_designer" )
                    fi
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "(a) Development Environment")
                    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                        if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" || " ${pattern_cr_arr[@]} " =~ "workflow" || " ${pattern_cr_arr[@]} " =~ "workstreams" ]]; then
                            optional_components_list=("Content Search Services" "Task Manager")
                            optional_components_cr_list=("css" "tm")
                        else
                            optional_components_list=("Content Search Services" "Content Management Interoperability Services" "Task Manager")
                            optional_components_cr_list=("css" "cmis" "tm")
                        fi
                        show_optional_components
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ae_data_persistence" )
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "document_processing_designer" )
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "(b) Runtime Environment")
                    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                        if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" || " ${pattern_cr_arr[@]} " =~ "workflow" || " ${pattern_cr_arr[@]} " =~ "workstreams" ]]; then
                            optional_components_list=("Content Search Services")
                            optional_components_cr_list=("css")
                        else
                            optional_components_list=("Content Search Services" "Content Management Interoperability Services" "Task Manager")
                            optional_components_cr_list=("css" "cmis" "tm")
                        fi
                        show_optional_components
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ae_data_persistence" )
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "document_processing_runtime" )
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "Workflow Process Service Authoring")
                    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                        optional_components_list=("Business Automation Insights" "Data Collector and Data Indexer" "Exposed Kafka Services")
                        optional_components_cr_list=("bai" "pfs" "kafka")
                        show_optional_components
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "wfps_authoring" )
                    fi
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
            esac
        done
    done

    if [[ "$AE_DATA_PERSISTENCE_ENABLE" == "Yes" ]]; then
        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ae_data_persistence" )
    fi

    if [[ "$AUTOMATION_SERVICE_ENABLE" == "Yes" ]]; then
        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "auto_service" )
        foundation_component_arr=( "${foundation_component_arr[@]}" "UMS" )
        # optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ums" ) # remove it when UMS pattern aware auto_service
    fi

    OPT_COMPONENTS_CR_SELECTED=($(echo "${optional_component_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    OPTIONAL_COMPONENT_DELETE_LIST=($(echo "${OPT_COMPONENTS_CR_SELECTED[@]}" "${OPTIONAL_COMPONENT_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))
    KEEP_COMPOMENTS=($(echo ${FOUNDATION_CR_SELECTED_LOWCASE[@]} ${OPTIONAL_COMPONENT_DELETE_LIST[@]} | tr ' ' '\n' | sort | uniq -d | uniq))
    OPT_COMPONENTS_SELECTED=($(echo "${optional_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # Will an external LDAP be used as part of the configuration?
    containsElement "es" "${OPT_COMPONENTS_CR_SELECTED[@]}"
    retVal_ext_ldap=$?
    if [[ $retVal_ext_ldap -eq 0 && "${DEPLOYMENT_TYPE}" == "production" ]];then
        set_external_ldap
    fi
}

function get_local_registry_password(){
    printf "\n"
    printf "\x1B[1mEnter the password for your docker registry: \x1B[0m"
    local_registry_password=""
    while [[ $local_registry_password == "" ]];
    do
       read -rsp "" local_registry_password
       if [ -z "$local_registry_password" ]; then
       echo -e "\x1B[1;31mEnter a valid password\x1B[0m"
       fi
    done
    export LOCAL_REGISTRY_PWD=${local_registry_password}
    printf "\n"
}

function get_local_registry_password_double(){
    pwdconfirmed=1
    pwd=""
    pwd2=""
        while [ $pwdconfirmed -ne 0 ] # While pwd is not yet received and confirmed (i.e. entered teh same time twice)
        do
                printf "\n"
                while [[ $pwd == '' ]] # While pwd is empty...
                do
                        printf "\x1B[1mEnter the password for your docker registry: \x1B[0m"
                        read -rsp " " pwd
                done

                printf "\n"
                while [[ $pwd2 == '' ]]  # While pwd is empty...
                do
                        printf "\x1B[1mEnter the password again: \x1B[0m"
                        read -rsp " " pwd2
                done

            if [ "$pwd" == "$pwd2" ]; then
                   pwdconfirmed=0
                else
                   printf "\n"
                   echo -e "\x1B[1;31mThe passwords do not match. Try again.\x1B[0m"
                   unset pwd
                   unset pwd2
                fi
        done

        printf "\n"

        export LOCAL_REGISTRY_PWD="${pwd}"
}



function get_entitlement_registry(){

    docker_image_exists() {
    local image_full_name="$1"; shift
    local wait_time="${1:-5}"
    local search_term='Pulling|Copying|is up to date|already exists|not found|unable to pull image|no pull access'
    if [[ $OCP_VERSION == "3.11" ]];then
        local result=$((timeout --preserve-status "$wait_time" docker 2>&1 pull "$image_full_name" &) | grep -v 'Pulling repository' | egrep -o "$search_term")

    elif [[ $OCP_VERSION == "4.4OrLater" ]]
    then
        local result=$((timeout --preserve-status "$wait_time" podman 2>&1 pull "$image_full_name" &) | grep -v 'Pulling repository' | egrep -o "$search_term")

    fi
    test "$result" || { echo "Timed out too soon. Try using a wait_time greater than $wait_time..."; return 1 ;}
    echo $result | grep -vq 'not found'
    }

    # For Entitlement Registry key
    entitlement_key=""
    printf "\n"
    printf "\n"
    printf "\x1B[1;31mFollow the instructions on how to get your Entitlement Key: \n\x1B[0m"
    printf "\x1B[1;31mhttps://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-getting-access-images-from-public-entitled-registry\n\x1B[0m"
    printf "\n"
    while true; do
        printf "\x1B[1mDo you have a Cloud Pak for Business Automation Entitlement Registry key (Yes/No, default: No): \x1B[0m"
        read -rp "" ans

        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            use_entitlement="yes"
            if [[ "$SCRIPT_MODE" == "dev" || "$SCRIPT_MODE" == "review" || "$SCRIPT_MODE" == "OLM" ]]
            then
                DOCKER_REG_SERVER="cp.stg.icr.io"
            else
                DOCKER_REG_SERVER="cp.icr.io"
            fi
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            use_entitlement="no"
            DOCKER_REG_KEY="None"
            if [[ "$PLATFORM_SELECTED" == "ROKS" || "$PLATFORM_SELECTED" == "OCP" ]]; then
                printf "\n"
                printf "\x1B[1;31m\"${PLATFORM_SELECTED}\" only supports the Entitlement Registry, exiting...\n\x1B[0m"
                exit 1
            else
                break
            fi
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function create_secret_entitlement_registry(){
    printf "\x1B[1mCreating docker-registry secret for Entitlement Registry key...\n\x1B[0m"
# Create docker-registry secret for Entitlement Registry Key
    ${CLI_CMD} delete secret "$DOCKER_RES_SECRET_NAME" >/dev/null 2>&1
    CREATE_SECRET_CMD="${CLI_CMD} create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$DOCKER_REG_SERVER --docker-username=$DOCKER_REG_USER --docker-password=$DOCKER_REG_KEY --docker-email=ecmtest@ibm.com"
    if $CREATE_SECRET_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1mFailed\x1B[0m"
    fi
}

function get_local_registry_server(){
    # For internal/external Registry Server
    printf "\n"
    if [[ "${REGISTRY_TYPE}" == "internal" && ("${OCP_VERSION}" == "4.4OrLater") ]];then
        #This is required for docker/podman login validation.
        printf "\x1B[1mEnter the public image registry or route (e.g., default-route-openshift-image-registry.apps.<hostname>). \n\x1B[0m"
        printf "\x1B[1mThis is required for docker/podman login validation: \x1B[0m"
        local_public_registry_server=""
        while [[ $local_public_registry_server == "" ]]
        do
            read -rp "" local_public_registry_server
            if [ -z "$local_public_registry_server" ]; then
            echo -e "\x1B[1;31mEnter a valid service name or the URL for the docker registry.\x1B[0m"
            fi
        done
    fi

    if [[ "${OCP_VERSION}" == "3.11" && "${REGISTRY_TYPE}" == "internal" ]];then
        printf "\x1B[1mEnter the OCP docker registry service name, for example: docker-registry.default.svc:5000/<project-name>: \x1B[0m"
    elif [[ "${REGISTRY_TYPE}" == "internal" && "${OCP_VERSION}" == "4.4OrLater" ]]
    then
        printf "\n"
        printf "\x1B[1mEnter the local image registry (e.g., image-registry.openshift-image-registry.svc:5000/<project>)\n\x1B[0m"
        printf "\x1B[1mThis is required to pull container images and Kubernetes secret creation: \x1B[0m"
        builtin_dockercfg_secrect_name=$(${CLI_CMD} get secret | grep default-dockercfg | awk '{print $1}')
        if [ -z "$builtin_dockercfg_secrect_name" ]; then
            DOCKER_RES_SECRET_NAME="ibm-entitlement-key"
        else
            DOCKER_RES_SECRET_NAME=$builtin_dockercfg_secrect_name
        fi
    elif [[ "${REGISTRY_TYPE}" == "external" || $PLATFORM_SELECTED == "other" ]]
    then
        printf "\x1B[1mEnter the URL to the docker registry, for example: abc.xyz.com: \x1B[0m"
    fi
    local_registry_server=""
    while [[ $local_registry_server == "" ]]
    do
        read -rp "" local_registry_server
        if [ -z "$local_registry_server" ]; then
        echo -e "\x1B[1;31mEnter a valid service name or the URL for the docker registry.\x1B[0m"
        fi
    done
    LOCAL_REGISTRY_SERVER=${local_registry_server}
    # convert docker-registry.default.svc:5000/project-name
    # to docker-registry.default.svc:5000\/project-name
    OIFS=$IFS
    IFS='/' read -r -a docker_reg_url_array <<< "$local_registry_server"
    delim=""
    joined=""
    for item in "${docker_reg_url_array[@]}"; do
            joined="$joined$delim$item"
            delim="\/"
    done
    IFS=$OIFS
    CONVERT_LOCAL_REGISTRY_SERVER=${joined}
}

function get_local_registry_user(){
    # For Local Registry User
    printf "\n"
    printf "\x1B[1mEnter the user name for your docker registry: \x1B[0m"
    local_registry_user=""
    while [[ $local_registry_user == "" ]]
    do
       read -rp "" local_registry_user
       if [ -z "$local_registry_user" ]; then
       echo -e "\x1B[1;31mEnter a valid user name.\x1B[0m"
       fi
    done
    export LOCAL_REGISTRY_USER=${local_registry_user}
}

function get_storage_class_name(){

    # For dynamic storage classname
    storage_class_name=""
    block_storage_class_name=""
    sc_slow_file_storage_classname=""
    sc_medium_file_storage_classname=""
    sc_fast_file_storage_classname=""

    printf "\n"
    if [[ $DEPLOYMENT_TYPE == "starter" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other")]] ;
    then
        printf "\x1B[1mTo provision the persistent volumes and volume claims, enter the file storage classname(RWX): \x1B[0m"

        while [[ $storage_class_name == "" ]]
        do
            read -rp "" storage_class_name
            if [ -z "$storage_class_name" ]; then
               echo -e "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
            fi
        done
        printf "\x1B[1mTo provision the persistent volumes and volume claims, enter the block storage classname(RWO): \x1B[0m"
        if [[ $PLATFORM_SELECTED == "OCP" ]]; then
        while [[ $block_storage_class_name == "" ]]
        do
            read -rp "" block_storage_class_name
            if [ -z "$block_storage_class_name" ]; then
               echo -e "\x1B[1;31mEnter a valid block storage classname(RWO)\x1B[0m"
            fi
        done
        fi
    elif [[ ($DEPLOYMENT_TYPE == "production" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other")) || $PLATFORM_SELECTED == "ROKS" ]]
    then
        printf "\x1B[1mTo provision the persistent volumes and volume claims\n\x1B[0m"
        while [[ $sc_slow_file_storage_classname == "" ]] # While get slow storage clase name
        do
            printf "\x1B[1mplease enter the file storage classname for slow storage(RWX): \x1B[0m"
            read -rp "" sc_slow_file_storage_classname
            if [ -z "$sc_slow_file_storage_classname" ]; then
               echo -e "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
            fi
        done

        while [[ $sc_medium_file_storage_classname == "" ]] # While get medium storage clase name
        do
            printf "\x1B[1mplease enter the file storage classname for medium storage(RWX): \x1B[0m"
            read -rp "" sc_medium_file_storage_classname
            if [ -z "$sc_medium_file_storage_classname" ]; then
               echo -e "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
            fi
        done

        while [[ $sc_fast_file_storage_classname == "" ]] # While get fast storage clase name
        do
            printf "\x1B[1mplease enter the file storage classname for fast storage(RWX): \x1B[0m"
            read -rp "" sc_fast_file_storage_classname
            if [ -z "$sc_fast_file_storage_classname" ]; then
               echo -e "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
            fi
        done
        if [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]]; then
        while [[ $block_storage_class_name == "" ]] # While get block storage clase name
        do
            printf "\x1B[1mplease enter the block storage classname for Zen(RWO): \x1B[0m"
            read -rp "" block_storage_class_name
            if [ -z "$block_storage_class_name" ]; then
               echo -e "\x1B[1;31mEnter a valid block storage classname(RWO)\x1B[0m"
            fi
        done
        fi
    fi
    STORAGE_CLASS_NAME=${storage_class_name}
    SLOW_STORAGE_CLASS_NAME=${sc_slow_file_storage_classname}
    MEDIUM_STORAGE_CLASS_NAME=${sc_medium_file_storage_classname}
    FAST_STORAGE_CLASS_NAME=${sc_fast_file_storage_classname}
    BLOCK_STORAGE_CLASS_NAME=${block_storage_class_name}
}

function create_secret_local_registry(){
    echo -e "\x1B[1mCreating the secret based on the local docker registry information...\x1B[0m"
    # Create docker-registry secret for local Registry Key
    # echo -e "Create docker-registry secret for Local Registry...\n"
    if [[ $LOCAL_REGISTRY_SERVER == docker-registry* || $LOCAL_REGISTRY_SERVER == image-registry.openshift-image-registry* ]] ;
    then
        builtin_dockercfg_secrect_name=$(${CLI_CMD} get secret | grep default-dockercfg | awk '{print $1}')
        DOCKER_RES_SECRET_NAME=$builtin_dockercfg_secrect_name
        # CREATE_SECRET_CMD="${CLI_CMD} create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$LOCAL_REGISTRY_SERVER --docker-username=$LOCAL_REGISTRY_USER --docker-password=$(${CLI_CMD} whoami -t) --docker-email=ecmtest@ibm.com"
    else
        ${CLI_CMD} delete secret "$DOCKER_RES_SECRET_NAME" >/dev/null 2>&1
        CREATE_SECRET_CMD="${CLI_CMD} create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$LOCAL_REGISTRY_SERVER --docker-username=$LOCAL_REGISTRY_USER --docker-password=$LOCAL_REGISTRY_PWD --docker-email=ecmtest@ibm.com"
        if $CREATE_SECRET_CMD ; then
            echo -e "\x1B[1mDone\x1B[0m"
        else
            echo -e "\x1B[1;31mFailed\x1B[0m"
        fi
    fi
}

function verify_local_registry_password(){
    # require to preload image for CP4A image and ldap/db2 image for demo
    printf "\n"
    while true; do
        printf "\x1B[1mHave you pushed the images to the local registry using 'loadimages.sh' (CP4A images) (Yes/No)? \x1B[0m"
        # printf "\x1B[1mand 'loadPrereqImages.sh' (Db2 and OpenLDAP for demo) scripts (Yes/No)? \x1B[0m"
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            PRE_LOADED_IMAGE="Yes"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            echo -e "\x1B[1;31mPlease pull the images to the local images to proceed.\n\x1B[0m"
            exit 1
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done

    # Select which type of image registry to use.
    if [[ "${PLATFORM_SELECTED}" == "OCP" ]]; then
        printf "\n"
        echo -e "\x1B[1mSelect the type of image registry to use: \x1B[0m"
        COLUMNS=12
        options=("Other ( External image registry: abc.xyz.com )")

        PS3='Enter a valid option [1 to 1]: '
        select opt in "${options[@]}"
        do
            case $opt in
                "Openshift Container Platform (OCP) - Internal image registry")
                    REGISTRY_TYPE="internal"
                    break
                    ;;
                "Other ( External image registry: abc.xyz.com )")
                    REGISTRY_TYPE="external"
                    break
                    ;;
                *) echo "invalid option $REPLY";;
            esac
        done
    else
        REGISTRY_TYPE="external"
    fi
    get_local_registry_server
}
function select_installation_type(){
    COLUMNS=12
    echo -e "\x1B[1mIs this a new installation or an existing installation?\x1B[0m"
    options=("New" "Existing")
    PS3='Enter a valid option [1 to 2]: '
    select opt in "${options[@]}"
    do
        case $opt in
            "New")
                INSTALLATION_TYPE="new"
                break
                ;;
            "Existing")
                INSTALLATION_TYPE="existing"
                mkdir -p $TEMP_FOLDER >/dev/null 2>&1
                mkdir -p $BAK_FOLDER >/dev/null 2>&1
                mkdir -p $FINAL_CR_FOLDER >/dev/null 2>&1
                get_existing_pattern_name
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
    if [[ "${INSTALLATION_TYPE}" == "new" ]]; then
        clean_up_temp_file
        rm -rf $BAK_FOLDER >/dev/null 2>&1
        rm -rf $FINAL_CR_FOLDER >/dev/null 2>&1

        mkdir -p $TEMP_FOLDER >/dev/null 2>&1
        mkdir -p $BAK_FOLDER >/dev/null 2>&1
        mkdir -p $FINAL_CR_FOLDER >/dev/null 2>&1
    fi
}

function select_iam_default_admin(){
    printf "\n"
    while true; do
        echo -e "\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mIf you are unable to use [cpadmin] as the default IAM admin user due to it having the same user name in your LDAP Directory, you need to change the Cloud Pak administrator username. See: \"https://www.ibm.com/docs/en/cpfs?topic=configurations-changing-cloud-pak-administrator-access-credentials#user-name\"\x1B[0m"
        printf "\x1B[1mDo you want to use the default IAM admin user: [cpadmin] (Yes/No, default: Yes): \x1B[0m"
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            USE_DEFAULT_IAM_ADMIN="Yes"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            USE_DEFAULT_IAM_ADMIN="No"
            while [[ $NON_DEFAULT_IAM_ADMIN == "" ]];
            do
                printf "\n"
                echo -e "\x1B[1mWhat is the non default IAM admin user you renamed?\x1B[0m"
                read -p "Enter the admin user name: " NON_DEFAULT_IAM_ADMIN

                if [ -z "$NON_DEFAULT_IAM_ADMIN" ]; then
                    echo -e "\x1B[1;31mEnter a valid admin user name, user name can not be blank\x1B[0m"
                    NON_DEFAULT_IAM_ADMIN=""
                elif [[ "$NON_DEFAULT_IAM_ADMIN" == "cpadmin" ]]; then
                    echo -e "\x1B[1;31mEnter a valid admin user name, user name should not be 'cpadmin'\x1B[0m"
                    NON_DEFAULT_IAM_ADMIN=""
                fi
            done
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function select_profile_type(){
    printf "\n"
    COLUMNS=12
    if [ -z $OPENSEARCH_CATALOG_NS ]; then
        echo -e "\x1B[1mPlease select the deployment profile. Refer to the documentation in CP4BA Docs for details on profile.\x1B[0m"
    else
        echo -e "\x1B[1mPlease select the deployment profile for Opensearch. Refer to the documentation in Opensearch Docs for details on profile.\x1B[0m"
    fi
    options=("small" "medium" "large")
    if [ -z "$existing_profile_type" ]; then
      if [[ $PROFILE_TYPE == "" ]]; then
        PS3='Enter a valid option [1 to 3]: '
        select opt in "${options[@]}"
        do
            case $opt in
                "small")
                    PROFILE_TYPE="small"
                    break
                    ;;
                "medium")
                    PROFILE_TYPE="medium"
                    break
                    ;;
                "large")
                    PROFILE_TYPE="large"
                    break
                    ;;
                *) echo "invalid option $REPLY";;
            esac
        done
      fi
    else
        options_var=("small" "medium" "large")
        for i in ${!options_var[@]}; do
            if [[ "${options_var[i]}" == "$existing_profile_type" ]]; then
                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Selected)"
            else
                printf "%1d) %s\n" $((i+1)) "${options[i]}"
            fi
        done
        echo -e "\x1B[1;31mExisting profile size type found in CR: \"$existing_profile_type\"\x1B[0m"
        # echo -e "\x1B[1;31mDo not need to select again.\n\x1B[0m"
        read -rsn1 -p"Press any key to continue ...";echo
    fi
}

function select_ocp_olm(){
    printf "\n"
    while true; do
        printf "\x1B[1mAre you using the OCP Catalog (OLM) to perform this install? (Yes/No, default: No) \x1B[0m"

        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            SCRIPT_MODE="OLM"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}


function select_deployment_type(){
    printf "\n"

    if [[ "$SCRIPT_MODE" == "OLM" ]]
    then
        DEPLOYMENT_TYPE="production"
        echo -e "An enterprise deployment will be prepared for the OCP Catalog."
    else
        echo -e "\x1B[1mWhat type of deployment is being performed?\x1B[0m"

        COLUMNS=12
        options=("Starter" "Production")
        if [ -z "$existing_deployment_type" ]; then
          if [[ $CP4BA_DEPLOYMENT_TYPE != ""  ]]; then
            DEPLOYMENT_TYPE=$CP4BA_DEPLOYMENT_TYPE
          else
            PS3='Enter a valid option [1 to 2]: '
            select opt in "${options[@]}"
            do
                case $opt in
                    "Starter")
                        DEPLOYMENT_TYPE="starter"
                        break
                        ;;
                    "Production")
                        DEPLOYMENT_TYPE="production"
                        break
                        ;;
                    *) echo "invalid option $REPLY";;
                esac
            done
          fi
        else
            options_var=("Starter" "Production")
            for i in ${!options_var[@]}; do
                if [[ "${options_var[i]}" == "$existing_deployment_type" ]]; then
                    printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Selected)"
                else
                    printf "%1d) %s\n" $((i+1)) "${options[i]}"
                fi
            done
            echo -e "\x1B[1;31mExisting deployment type found in CR: \"$existing_deployment_type\"\x1B[0m"
            # echo -e "\x1B[1;31mDo not need to select again.\n\x1B[0m"
            read -rsn1 -p"Press any key to continue ...";echo
        fi
    fi
}

function enable_ae_data_persistence_workflow_authoring(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        ${COPY_CMD} -rf ${WORKFLOW_AUTHOR_PATTERN_FILE_BAK} ${WORKFLOW_AUTHOR_PATTERN_FILE_TMP}
        content_start="$(grep -n "## object store for AEOS" ${WORKFLOW_AUTHOR_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        content_stop="$(tail -n +$content_start < ${WORKFLOW_AUTHOR_PATTERN_FILE_TMP} | grep -n "dc_hadr_max_retries_for_client_reroute: 3" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${WORKFLOW_AUTHOR_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1
        ###########
        content_start="$(grep -n "## Configuration for the application engine object store" ${WORKFLOW_AUTHOR_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        content_stop="$(tail -n +$content_start < ${WORKFLOW_AUTHOR_PATTERN_FILE_TMP} | grep -n "\"<Required>\" # user name and group name for object store admin" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start + 1))
        vi ${WORKFLOW_AUTHOR_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/      # /      ' -c ':wq' >/dev/null 2>&1

        ${COPY_CMD} -rf ${WORKFLOW_AUTHOR_PATTERN_FILE_TMP} ${WORKFLOW_AUTHOR_PATTERN_FILE_BAK}
    fi
}

function enable_ae_data_persistence_baa(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        ${COPY_CMD} -rf ${APPLICATION_PATTERN_FILE_BAK} ${APPLICATION_PATTERN_FILE_TMP}
        content_start="$(grep -n "The beginning section of database configuration for CP4A" ${APPLICATION_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        content_stop="$(tail -n +$content_start < ${APPLICATION_PATTERN_FILE_TMP} | grep -n "dc_os_xa_datasource_name: \"AEOSXA\"" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start + 1))
        vi ${APPLICATION_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/  # /  ' -c ':wq' >/dev/null 2>&1
        ${COPY_CMD} -rf ${APPLICATION_PATTERN_FILE_TMP} ${APPLICATION_PATTERN_FILE_BAK}
    fi
}

function select_ldap_type_for_wfps_authoring(){
    info "LDAP configuration is not required for the IBM Workflow Process Service Authoring, but if you want to login with LDAP user, please select Yes. If you select No, you can do post actions with https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=cpbaf-business-automation-studio to add the LDAP connection manually after install."
    while true; do
        printf "\x1B[1mDo you want use the LDAP for the IBM Workflow Process Service Authoring? (Yes/No): \x1B[0m"
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            LDAP_WFPS_AUTHORING="Yes"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            LDAP_WFPS_AUTHORING="No"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function select_upgrade_mode(){
    UPGRADE_MODE=""
    while [[ $UPGRADE_MODE == "" ]]; do
        printf "\n"
        options=("Cluster-scoped to Cluster-scoped" "Cluster-scoped to Namespace-scoped")
        tips=("This migration mode will first isolate the shared 3.x version of foundational services on the cluster, then install a new instance of foundational services version 4.6.2. Any data from the original foundational services will be copied to the new instance." "This migration mode will migrate a single shared instance of foundational services that is shared by all IBM Cloud Paks in the entire cluster, all of its core foundational services operators to the cluster-scope namespace will be upgraded to v4.6.2 without creating new instances.")
        pros_tips=("The namespace-scoped foundational services for each Cloud Pak or CP4BA component." "The fewer resource required for a single shared instance of foundational services.")
        cons_tips=("The more resource required for each namespace-scoped instance of IBM Cloud Pak foundational services." "It is not flexible for all Cloud Pak or CP4BA component to share same one instance of IBM Cloud Pak foundational services.")

        if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
            echo -e "\x1B[1mWhich migration mode for the IBM Cloud Pak foundational services are you migrating to? \x1B[0m"
        elif [[ $RUNTIME_MODE == "upgradeDeployment" ]]; then
            echo -e "\x1B[1mWhich migration mode for the IBM Cloud Pak foundational services are you migrating to when run [upgradeOperator]? \x1B[0m"
        fi
        echo -e "${YELLOW_TEXT}1) Cluster-scoped to Cluster-scoped${RESET_TEXT}"
        if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
            echo -e "   ${YELLOW_TEXT}[Tips]${RESET_TEXT}: ${tips[1]}"
            echo -e "   ${GREEN_TEXT}[Pros]${RESET_TEXT}: ${pros_tips[1]}"
            echo -e "   ${RED_TEXT}[Cons]${RESET_TEXT}: ${cons_tips[1]}"
        fi
        echo -e "${YELLOW_TEXT}2) Cluster-scoped to Namespace-scoped (Recommended)${RESET_TEXT}"
        if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
            echo -e "   ${YELLOW_TEXT}[Tips]${RESET_TEXT}: ${tips[0]}"
            echo -e "   ${GREEN_TEXT}[Pros]${RESET_TEXT}: ${pros_tips[0]}"
            echo -e "   ${RED_TEXT}[Cons]${RESET_TEXT}: ${cons_tips[0]}"
        fi

        read -p "Enter your choice [1 or 2]: " choice
        case $choice in
            1)
                UPGRADE_MODE="shared2shared"
                ;;
            2)
                UPGRADE_MODE="shared2dedicated"
                ;;
            *)
                echo "Invalid choice. Please select 1 or 2."
                sleep 2
                ;;
        esac
        if [[ ! -z $UPGRADE_MODE ]]; then
            echo "You selected: ${options[$choice-1]}"
            printf "\n"
            sleep 2
        fi
    done
}

function select_restricted_internet_access(){
    printf "\n"
    echo ""
    while true; do
        printf "\x1B[1mDo you want to restrict network egress to unknown external destination for this CP4BA deployment?\x1B[0m ${YELLOW_TEXT}(Notes: CP4BA $CP4BA_RELEASE_BASE prevents all network egress to unknown destinations by default. You can either (1) enable all egress or (2) accept the new default and create network policies to allow your specific communication targets as documented in the knowledge center.)${RESET_TEXT} (Yes/No, default: Yes): "
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            RESTRICTED_INTERNET_ACCESS="true"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            RESTRICTED_INTERNET_ACCESS="false"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function select_fips_enable(){
    select_project
    all_fips_enabled_flag=$(${CLI_CMD} get configmap cp4ba-fips-status --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath={.data.all-fips-enabled})
    if [ -z $all_fips_enabled_flag ]; then
        if [[ ("$DEPLOYMENT_TYPE" == "production" && $DEPLOYMENT_WITH_PROPERTY == "No") || "$DEPLOYMENT_TYPE" == "starter" ]]; then
            info "Not found configmap \"cp4ba-fips-status\" in the project \"$TARGET_PROJECT_NAME\". setting \"shared_configuration.enable_fips\" as \"false\" by default in the final custom resource."
            FIPS_ENABLED="false"
        fi
    elif [[ "$all_fips_enabled_flag" == "Yes" ]]; then
        printf "\n"
        while true; do
            printf "\x1B[1mYour OCP cluster has FIPS enabled, do you want to enable FIPS with this CP4BA deployment？\x1B[0m${YELLOW_TEXT} (Notes: If you select \"Yes\", in order to complete enablement of FIPS for CP4BA, please refer to \"FIPS wall\" configuration in IBM documentation.)${RESET_TEXT} (Yes/No, default: No): "
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
            FIPS_ENABLED="true"
            break
            ;;
            "n"|"N"|"no"|"No"|"NO"|"")
                FIPS_ENABLED="false"
                break
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    elif [[ "$all_fips_enabled_flag" == "No" ]]; then
        FIPS_ENABLED="false"
    fi
}

function select_ldap_type(){
    printf "\n"
    COLUMNS=12
    echo -e "\x1B[1mWhat is the LDAP type that is used for this deployment? \x1B[0m"
    options=("Microsoft Active Directory" "IBM Tivoli Directory Server / Security Directory Server")
    PS3='Enter a valid option [1 to 2]: '
    select opt in "${options[@]}"
    do
        case $opt in
            "Microsoft Active Directory")
                LDAP_TYPE="AD"
                break
                ;;
            "IBM Tivoli"*)
                LDAP_TYPE="TDS"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

}
function set_ldap_type_foundation(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}

        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${CP4A_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "tds:" ${CP4A_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${CP4A_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${CP4A_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_content_pattern(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        ${COPY_CMD} -rf ${CONTENT_PATTERN_FILE_BAK} ${CONTENT_PATTERN_FILE_TMP}

        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "## The User script will uncomment" ${CONTENT_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "## The User script will uncomment" ${CONTENT_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start + 2))
        vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'d' -c ':wq' >/dev/null 2>&1

        ${COPY_CMD} -rf ${CONTENT_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_adp_pattern(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        ${COPY_CMD} -rf ${ARIA_PATTERN_FILE_BAK} ${ARIA_PATTERN_FILE_TMP}

        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "## The User script will uncomment" ${ARIA_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "## The User script will uncomment" ${ARIA_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${ARIA_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start + 2))
        vi ${ARIA_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'d' -c ':wq' >/dev/null 2>&1

        ${COPY_CMD} -rf ${ARIA_PATTERN_FILE_TMP} ${ARIA_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_workstreams_pattern(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        ${COPY_CMD} -rf ${WORKSTREAMS_PATTERN_FILE_BAK} ${WORKSTREAMS_PATTERN_FILE_TMP}

        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${WORKSTREAMS_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "tds:" ${WORKSTREAMS_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${WORKSTREAMS_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${WORKSTREAMS_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        ${COPY_CMD} -rf ${WORKSTREAMS_PATTERN_FILE_TMP} ${WORKSTREAMS_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_workflow_pattern(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        ${COPY_CMD} -rf ${WORKFLOW_PATTERN_FILE_BAK} ${WORKFLOW_PATTERN_FILE_TMP}

        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${WORKFLOW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "tds:" ${WORKFLOW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${WORKFLOW_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${WORKFLOW_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        ${COPY_CMD} -rf ${WORKFLOW_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_ww_pattern(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        ${COPY_CMD} -rf ${WW_PATTERN_FILE_BAK} ${WW_PATTERN_FILE_TMP}

        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${WW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "tds:" ${WW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${WW_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${WW_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        ${COPY_CMD} -rf ${WW_PATTERN_FILE_TMP} ${WW_PATTERN_FILE_BAK}
    fi
}
function set_external_ldap(){
    printf "\n"

    while true; do
        printf "\x1B[1mWill an external LDAP be used as part of the configuration?: \x1B[0m"

        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            SET_EXT_LDAP="Yes"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            SET_EXT_LDAP="No"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done

}
function set_external_share_content_pattern(){
    if [[ $DEPLOYMENT_TYPE == "production" && $SET_EXT_LDAP == "Yes" ]] ;
    then
        containsElement "es" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${COPY_CMD} -rf ${CONTENT_PATTERN_FILE_BAK} ${CONTENT_PATTERN_FILE_TMP}
            # un-comment ext_ldap_configuration
            content_start="$(grep -n "ext_ldap_configuration:" ${CONTENT_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
            content_stop="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "lc_ldap_group_member_id_map:" | head -n1 | cut -d: -f1)"
            content_stop=$(( $content_stop + $content_start - 1))
            vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/  # /  ' -c ':wq' >/dev/null 2>&1

            # un-comment LDAP
            if [[ $DEPLOYMENT_TYPE == "starter" || ($DEPLOYMENT_TYPE == "production" && $DEPLOYMENT_WITH_PROPERTY == "No") ]]; then
                if [[ "$LDAP_TYPE" == "AD" ]]; then
                    # content_start="$(grep -n "ad:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
                    content_start="$(grep -n "ad:" ${CONTENT_PATTERN_FILE_TMP} | cut -d: -f1)"
                else
                    # content_start="$(grep -n "tds:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
                    content_start="$(grep -n "tds:" ${CONTENT_PATTERN_FILE_TMP} | cut -d: -f1)"
                fi
            elif [[ $DEPLOYMENT_TYPE == "production" && $DEPLOYMENT_WITH_PROPERTY == "Yes" ]]; then
                tmp_ldap_type="$(prop_ext_ldap_property_file LDAP_TYPE)"
                tmp_ldap_type=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_type")
                if [[ $tmp_ldap_type == "Microsoft Active Directory" ]]; then
                    # content_start="$(grep -n "ad:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
                    content_start="$(grep -n "ad:" ${CONTENT_PATTERN_FILE_TMP} | cut -d: -f1)"
                elif [[ $tmp_ldap_type == "IBM Security Directory Server" ]]; then
                    # content_start="$(grep -n "tds:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
                    content_start="$(grep -n "tds:" ${CONTENT_PATTERN_FILE_TMP} | cut -d: -f1)"
                else
                    fail "The value for \"LDAP_TYPE\" in the property file \"${EXTERNAL_LDAP_PROPERTY_FILE}\" is not valid. The possible values are: \"IBM Security Directory Server\" or \"Microsoft Active Directory\""
                    exit 1
                fi
            fi
            content_stop="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
            content_stop=$(( $content_stop + $content_start - 1))
            vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq'

            ${COPY_CMD} -rf ${CONTENT_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
        fi
    fi
}

function set_object_store_content_pattern(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        ${COPY_CMD} -rf ${CONTENT_PATTERN_FILE_BAK} ${CONTENT_PATTERN_FILE_TMP}
        if [[ $content_os_number -gt 0 ]]; then
            content_start="$(grep -n "datasource_configuration:" ${CONTENT_PATTERN_FILE_TMP} |  head -n 1 | cut -d: -f1)"
            content_tmp="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "dc_os_datasources:" | head -n1 | cut -d: -f1)"
            content_tmp=$(( content_tmp + $content_start - 1))
            content_stop="$(tail -n +$content_tmp < ${CONTENT_PATTERN_FILE_TMP} | grep -n "dc_database_type:" | head -n1 | cut -d: -f1)"
            content_start=$(( $content_stop + $content_tmp - 1))
            content_tmp="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "dc_hadr_max_retries_for_client_reroute:" | head -n1 | cut -d: -f1)"
            content_stop=$(( $content_start + $content_tmp - 1))

            for ((j=1;j<${content_os_number};j++))
            do
                vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"' copy '"${content_stop}"'' -c ':wq' >/dev/null 2>&1
            done

            for ((j=1;j<${content_os_number};j++))
            do
                ((obj_num=j+1))
                ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[${j}].dc_common_os_datasource_name "\"FNOS${obj_num}DS\""
                ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[${j}].dc_common_os_xa_datasource_name "\"FNOS${obj_num}DSXA\""
            done

            # Add additional OS into initialize_configuration
            content_start="$(grep -n "ic_obj_store_creation:" ${CONTENT_PATTERN_FILE_TMP} |  head -n 1 | cut -d: -f1)"
            content_tmp="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "object_stores:" | head -n1 | cut -d: -f1)"
            content_tmp=$(( content_tmp + $content_start - 1))
            content_stop="$(tail -n +$content_tmp < ${CONTENT_PATTERN_FILE_TMP} | grep -n "oc_cpe_obj_store_display_name:" | head -n1 | cut -d: -f1)"
            content_start=$(( $content_stop + $content_tmp - 1))
            content_tmp="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "\"<Required>\" # user name and group name for object store admin" | head -n1 | cut -d: -f1)"
            content_stop=$(( $content_start + $content_tmp - 1))

            for ((j=1;j<${content_os_number};j++))
            do
                vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"' copy '"${content_stop}"'' -c ':wq' >/dev/null 2>&1
            done

            for ((j=1;j<${content_os_number};j++))
            do
                ((obj_num=j+1))
                if [[ $obj_num -lt "10" ]]; then
                    ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_display_name "\"OS0${obj_num}\""
                    ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_symb_name "\"OS0${obj_num}\""
                else
                    ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_display_name "\"OS${obj_num}\""
                    ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_symb_name "\"OS${obj_num}\""
                fi
                ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_conn.name "\"objectstore${obj_num}_connection\""
                ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_conn.dc_os_datasource_name "\"FNOS${obj_num}DS\""
                ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_conn.dc_os_xa_datasource_name "\"FNOS${obj_num}DSXA\""
            done

            if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" && $DEPLOYMENT_WITH_PROPERTY == "Yes" ]]; then
                for ((j=0;j<${content_os_number};j++))
                do
                    ((obj_num=j+1))
                    tmp_os_db_enable_adp="$(prop_db_name_user_property_file OS${obj_num}_ENABLE_DOCUMENT_PROCESSING)"
                    tmp_os_db_enable_adp=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_enable_adp")
                    if [[ $tmp_os_db_enable_adp == "Yes" || $tmp_os_db_enable_adp == "YES" || $tmp_os_db_enable_adp == "Y" || $tmp_os_db_enable_adp == "True" || $tmp_os_db_enable_adp == "true" ]]; then
                        ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_enable_document_processing "true"
                    fi
                done
            fi

        fi
        ${COPY_CMD} -rf ${CONTENT_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
    fi
}

function set_object_store_adp_pattern(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        ${COPY_CMD} -rf ${ARIA_PATTERN_FILE_BAK} ${ARIA_PATTERN_FILE_TMP}
        if [[ $content_os_number -gt 0 ]]; then
            content_start="$(grep -n "datasource_configuration:" ${ARIA_PATTERN_FILE_TMP} |  head -n 1 | cut -d: -f1)"
            content_tmp="$(tail -n +$content_start < ${ARIA_PATTERN_FILE_TMP} | grep -n "dc_os_datasources:" | head -n1 | cut -d: -f1)"
            content_tmp=$(( content_tmp + $content_start - 1))
            content_stop="$(tail -n +$content_tmp < ${ARIA_PATTERN_FILE_TMP} | grep -n "dc_database_type:" | head -n1 | cut -d: -f1)"
            content_start=$(( $content_stop + $content_tmp - 1))
            content_tmp="$(tail -n +$content_start < ${ARIA_PATTERN_FILE_TMP} | grep -n "dc_hadr_max_retries_for_client_reroute:" | head -n1 | cut -d: -f1)"
            content_stop=$(( $content_start + $content_tmp - 1))

            for ((j=1;j<${content_os_number};j++))
            do
                vi ${ARIA_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"' copy '"${content_stop}"'' -c ':wq' >/dev/null 2>&1
            done

            for ((j=1;j<${content_os_number};j++))
            do
                ((obj_num=j+1))
                ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[${j}].dc_common_os_datasource_name "\"FNOS${obj_num}DS\""
                ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[${j}].dc_common_os_xa_datasource_name "\"FNOS${obj_num}DSXA\""
            done

            # Add additional OS into initialize_configuration
            content_start="$(grep -n "ic_obj_store_creation:" ${ARIA_PATTERN_FILE_TMP} |  head -n 1 | cut -d: -f1)"
            content_tmp="$(tail -n +$content_start < ${ARIA_PATTERN_FILE_TMP} | grep -n "object_stores:" | head -n1 | cut -d: -f1)"
            content_tmp=$(( content_tmp + $content_start - 1))
            content_stop="$(tail -n +$content_tmp < ${ARIA_PATTERN_FILE_TMP} | grep -n "oc_cpe_obj_store_display_name:" | head -n1 | cut -d: -f1)"
            content_start=$(( $content_stop + $content_tmp - 1))
            content_tmp="$(tail -n +$content_start < ${ARIA_PATTERN_FILE_TMP} | grep -n "\"<Required>\" # user name and group name for object store admin" | head -n1 | cut -d: -f1)"
            content_stop=$(( $content_start + $content_tmp - 1))

            for ((j=1;j<${content_os_number};j++))
            do
                vi ${ARIA_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"' copy '"${content_stop}"'' -c ':wq' >/dev/null 2>&1
            done

            for ((j=1;j<${content_os_number};j++))
            do
                ((obj_num=j+1))
                if [[ $obj_num -lt "10" ]]; then
                    ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_display_name "\"OS0${obj_num}\""
                    ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_symb_name "\"OS0${obj_num}\""
                else
                    ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_display_name "\"OS${obj_num}\""
                    ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_symb_name "\"OS${obj_num}\""
                fi
                ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_conn.name "\"objectstore${obj_num}_connection\""
                ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_conn.dc_os_datasource_name "\"FNOS${obj_num}DS\""
                ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_conn.dc_os_xa_datasource_name "\"FNOS${obj_num}DSXA\""
            done

            if [[ $DEPLOYMENT_WITH_PROPERTY == "Yes" ]]; then
                for ((j=0;j<${content_os_number};j++))
                do
                    ((obj_num=j+1))
                    tmp_os_db_enable_adp="$(prop_db_name_user_property_file OS${obj_num}_ENABLE_DOCUMENT_PROCESSING)"
                    tmp_os_db_enable_adp=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_enable_adp")
                    if [[ $tmp_os_db_enable_adp == "Yes" || $tmp_os_db_enable_adp == "YES" || $tmp_os_db_enable_adp == "Y" || $tmp_os_db_enable_adp == "True" || $tmp_os_db_enable_adp == "true" ]]; then
                        ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[${j}].oc_cpe_obj_store_enable_document_processing "true"
                    fi
                done
            fi
        fi
        ${COPY_CMD} -rf ${ARIA_PATTERN_FILE_TMP} ${ARIA_PATTERN_FILE_BAK}
    fi
}

function set_aca_tenant_pattern(){
    if [[ $DEPLOYMENT_TYPE == "production" ]] ;
    then
        ${COPY_CMD} -rf ${ACA_PATTERN_FILE_BAK} ${ACA_PATTERN_FILE_TMP}
        # ${YQ_CMD} d -i ${ACA_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases
        if [ ${#aca_tenant_arr[@]} -eq 0 ]; then
            echo -e "\x1B[1;31mNot any element in ACA tenant list found\x1B[0m:\x1B[1m"
        else
            for i in ${!aca_tenant_arr[@]}; do
               ${YQ_CMD} w -i ${ACA_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases.[${i}] "${aca_tenant_arr[i]}"
             done
        fi
        ${COPY_CMD} -rf ${ACA_PATTERN_FILE_TMP} ${ACA_PATTERN_FILE_BAK}
    fi
}

function select_automation_service(){
    if [[ !(" ${PATTERNS_CR_SELECTED[@]} " =~ "application" || " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-authoring" || " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-runtime" || " ${PATTERNS_CR_SELECTED[@]} " =~ "workstreams" || " ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing")]]; then
        printf "\n"
        while true; do
            printf "\x1B[1mDo you want to enable the Business Automation Service? (Yes/No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                foundation_component_arr=( "${foundation_component_arr[@]}" "AE" )
                AUTOMATION_SERVICE_ENABLE="Yes"
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                break
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi
}

function select_cpe_full_storage(){
    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing" ]]; then
        printf "\n"
        while true; do
            printf "\x1B[1mDo you want limited CPE storage support? (Yes/No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                CPE_FULL_STORAGE="No"
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                CPE_FULL_STORAGE="Yes"
                break
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi
}

function select_enable_deep_learning(){
    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing" ]]; then
        printf "\n"
        while true; do
            printf "\x1B[1mDo you want to enable Deep Learning Capability (Yes/No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                ADP_DL_ENABLED="Yes"
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                ADP_DL_ENABLED="No"
                break
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi
}

function select_ae_data_persistence(){
    if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence" ]]; then
        foundation_component_arr=( "${foundation_component_arr[@]}" "AE" )
        AE_DATA_PERSISTENCE_ENABLE="Yes"
    else
        if [[ (" ${PATTERNS_CR_SELECTED[@]} " =~ "application") ]]; then
            printf "\n"
            while true; do
                printf "\x1B[1mDo you want to enable Business Automation Application Data Persistence? (Yes/No): \x1B[0m"
                read -rp "" ans
                case "$ans" in
                "y"|"Y"|"yes"|"Yes"|"YES")
                    foundation_component_arr=( "${foundation_component_arr[@]}" "AE" )
                    AE_DATA_PERSISTENCE_ENABLE="Yes"
                    # optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ae_data_persistence" )
                    break
                    ;;
                "n"|"N"|"no"|"No"|"NO"|"")
                    break
                    ;;
                *)
                    echo -e "Answer must be \"Yes\" or \"No\"\n"
                    ;;
                esac
            done
        fi
    fi
}

function select_aca_tenant(){
    printf "\n"
    printf "\x1B[1mHow many projects do you want to create initially with Document Processing Engine (DPE)? \x1B[0m"
    aca_tenant_number=""
    aca_tenant_arr=()
    while [[ $aca_tenant_number == "" ]];
    do
        read -rp "" aca_tenant_number
        if ! [[ "$aca_tenant_number" =~ ^[0-9]+$ ]]; then
            echo -e "\x1B[1;31mEnter a valid tenant number\x1B[0m"
            aca_tenant_number=""
        fi
    done

    order_number=1
    while (( ${#aca_tenant_arr[@]} < $aca_tenant_number ));
    do
        printf "\x1B[1mWhat is the name of tenant ${order_number}? \x1B[0m"
        read -rp "" aca_tenant_name
        if [ -z "$aca_tenant_number" ]; then
            echo -e "\x1B[1;31mEnter a valid tenant name\x1B[0m"
        else
            aca_tenant_arr=( "${aca_tenant_arr[@]}" "${aca_tenant_name}" )
        fi
        ((order_number++))
        printf "\n"
    done
    printf "\n"
}

function select_baw_only(){
    pattern_arr=()
    pattern_cr_arr=()
    printf "\n"
    echo -e "\x1B[1mSelect the Cloud Pak for Business Automation capability to install: \x1B[0m"
    COLUMNS=12

    options=("Business Automation Workflow")
    PS3='Enter a valid option [1 to 1]: '

    select opt in "${options[@]}"
    do
        case $opt in
            "Business Automation Workflow")
                pattern_arr=("Business Automation Workflow")
                pattern_cr_arr=("workflow")
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    if [[ $PLATFORM_SELECTED == "other" ]]; then
        foundation_baw=("BAN" "RR" "UMS" "AE")
    else
        foundation_baw=("BAN" "RR" "AE")
    fi

    foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_baw[@]}" )
    PATTERNS_CR_SELECTED=$( IFS=$','; echo "${pattern_cr_arr[*]}" )

    FOUNDATION_CR_SELECTED=($(echo "${foundation_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    # FOUNDATION_CR_SELECTED_LOWCASE=( "${FOUNDATION_CR_SELECTED[@],,}" )

    x=0;while [ ${x} -lt ${#FOUNDATION_CR_SELECTED[*]} ] ; do FOUNDATION_CR_SELECTED_LOWCASE[$x]=$(tr [A-Z] [a-z] <<< ${FOUNDATION_CR_SELECTED[$x]}); let x++; done
    FOUNDATION_DELETE_LIST=($(echo "${FOUNDATION_CR_SELECTED[@]}" "${FOUNDATION_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))

    PATTERNS_CR_SELECTED=($(echo "${pattern_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

function clean_up_temp_file(){
    local files=()
    if [[ -d $TEMP_FOLDER ]]; then
        files=($(find $TEMP_FOLDER -name '*.yaml'))
        for item in ${files[*]}
        do
            rm -rf $item >/dev/null 2>&1
        done

        files=($(find $TEMP_FOLDER -name '*.swp'))
        for item in ${files[*]}
        do
            rm -rf $item >/dev/null 2>&1
        done
    fi
}

function input_information(){
    if [[ $DEPLOYMENT_WITH_PROPERTY == "No" || $DEPLOYMENT_TYPE == "starter" ]]; then
        select_installation_type
    elif [[ $DEPLOYMENT_WITH_PROPERTY == "Yes" ]]; then
        INSTALLATION_TYPE="new"
    fi
    # clean_up_temp_file
    # rm -rf $BAK_FOLDER >/dev/null 2>&1
    # rm -rf $FINAL_CR_FOLDER >/dev/null 2>&1

    mkdir -p $TEMP_FOLDER >/dev/null 2>&1
    mkdir -p $BAK_FOLDER >/dev/null 2>&1
    mkdir -p $FINAL_CR_FOLDER >/dev/null 2>&1

    if [[ ${INSTALLATION_TYPE} == "existing" ]]; then
        # INSTALL_BAW_IAWS="No"
        prepare_pattern_file
        select_deployment_type
        if [[ $DEPLOYMENT_TYPE == "production" && (-z $PROFILE_TYPE) ]]; then
            select_profile_type
        fi
        select_platform
        if [[ ("$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS") && "$DEPLOYMENT_TYPE" == "production" && "$USE_DEFAULT_IAM_ADMIN" == "" && "$NON_DEFAULT_IAM_ADMIN" == "" ]]; then
            select_iam_default_admin
        fi
        if [[ ("$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS") && "$DEPLOYMENT_TYPE" == "starter" ]]; then
            select_project
        fi
        check_ocp_version
        validate_docker_podman_cli
    elif [[ ${INSTALLATION_TYPE} == "new" ]]
    then
        # select_ocp_olm
        select_deployment_type
        if [[ $DEPLOYMENT_WITH_PROPERTY == "Yes" && $DEPLOYMENT_TYPE == "production" ]]; then
            TARGET_PROJECT_NAME=$CP4BA_AUTO_NAMESPACE
            load_property_before_generate
            show_summary_pattern_selected
        fi
        if [[ $DEPLOYMENT_TYPE == "production" && (-z $PROFILE_TYPE) ]]; then
            select_profile_type
        fi
        select_platform
        if [[ ("$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS") && "$DEPLOYMENT_TYPE" == "production" && "$USE_DEFAULT_IAM_ADMIN" == "" && "$NON_DEFAULT_IAM_ADMIN" == "" ]]; then
            select_iam_default_admin
        fi
        if [[ ("$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS") && "$DEPLOYMENT_TYPE" == "starter" ]]; then
            select_project
        fi
        check_ocp_version
        validate_docker_podman_cli
        prepare_pattern_file
        # select_baw_iaws_installation
    fi

    if [[ "${INSTALLATION_TYPE}" == "existing" ]] && (( ${#EXISTING_PATTERN_ARR[@]} == 0 )); then
        echo -e "\x1B[1;31mTHERE IS NOT ANY EXISTING PATTERN FOUND!\x1B[0m"
        read -rsn1 -p"Press any key to continue install new pattern...";echo
    fi

    if [[ "${INSTALL_BAW_ONLY}" == "No" ]];
    then
        if [[ $DEPLOYMENT_TYPE == "starter" || $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
            select_pattern
        elif [[ $DEPLOYMENT_WITH_PROPERTY == "Yes" && $DEPLOYMENT_TYPE == "production" ]]; then
            FOUNDATION_CR_SELECTED=($(echo "${foundation_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

            x=0;while [ ${x} -lt ${#FOUNDATION_CR_SELECTED[*]} ] ; do FOUNDATION_CR_SELECTED_LOWCASE[$x]=$(tr [A-Z] [a-z] <<< ${FOUNDATION_CR_SELECTED[$x]}); let x++; done
            FOUNDATION_DELETE_LIST=($(echo "${FOUNDATION_CR_SELECTED[@]}" "${FOUNDATION_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))

            PATTERNS_CR_SELECTED=($(echo "${pattern_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        fi
    else
        select_baw_only
    fi

    if [[ $DEPLOYMENT_TYPE == "starter" || $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
        select_optional_component
    elif [[ $DEPLOYMENT_WITH_PROPERTY == "Yes" && $DEPLOYMENT_TYPE == "production" ]]; then
        OPT_COMPONENTS_CR_SELECTED=($(echo "${optional_component_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        OPTIONAL_COMPONENT_DELETE_LIST=($(echo "${OPT_COMPONENTS_CR_SELECTED[@]}" "${OPTIONAL_COMPONENT_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))
        KEEP_COMPOMENTS=($(echo ${FOUNDATION_CR_SELECTED_LOWCASE[@]} ${OPTIONAL_COMPONENT_DELETE_LIST[@]} | tr ' ' '\n' | sort | uniq -d | uniq))
        OPT_COMPONENTS_SELECTED=($(echo "${optional_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    fi



    # get jdbc url according to whether ICCSAP component selected
    if [[ ( $DEPLOYMENT_TYPE == "starter" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") || $DEPLOYMENT_TYPE == "production" ]]; then
        get_jdbc_url
    fi
    if [[ "$INSTALLATION_TYPE" == "new" ]]; then
        if [[ $PLATFORM_SELECTED == "other" ]]; then
            get_entitlement_registry
        fi
        if [[ "$use_entitlement" == "no" ]]; then
            verify_local_registry_password
        fi

        # if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]];
        # then
        #     get_infra_name
        # fi
        # load storage class name
        if [[ $DEPLOYMENT_TYPE == "starter" || $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
            get_storage_class_name
        elif [[ $DEPLOYMENT_WITH_PROPERTY == "Yes" && $DEPLOYMENT_TYPE == "production" ]]; then
            SLOW_STORAGE_CLASS_NAME=$(prop_user_profile_property_file CP4BA.SLOW_FILE_STORAGE_CLASSNAME)
            MEDIUM_STORAGE_CLASS_NAME=$(prop_user_profile_property_file CP4BA.MEDIUM_FILE_STORAGE_CLASSNAME)
            FAST_STORAGE_CLASS_NAME=$(prop_user_profile_property_file CP4BA.FAST_FILE_STORAGE_CLASSNAME)
            BLOCK_STORAGE_CLASS_NAME=$(prop_user_profile_property_file CP4BA.BLOCK_STORAGE_CLASS_NAME)
            if [[ -z $SLOW_STORAGE_CLASS_NAME || -z $MEDIUM_STORAGE_CLASS_NAME || -z $FAST_STORAGE_CLASS_NAME || -z $BLOCK_STORAGE_CLASS_NAME ]]; then
                get_storage_class_name
            fi
        fi

        # Select FIPS enable or not

        if  [[ ("$DEPLOYMENT_TYPE" == "production" && $DEPLOYMENT_WITH_PROPERTY == "No") && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
            select_fips_enable
        elif [[ "$DEPLOYMENT_TYPE" == "starter" ]]; then
            FIPS_ENABLED="false"
        fi

        if  [[  ("$DEPLOYMENT_TYPE" == "production" && $DEPLOYMENT_WITH_PROPERTY == "No") && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
            select_restricted_internet_access
        elif [[ "$DEPLOYMENT_TYPE" == "starter" ]]; then
            # For starter deployment, always set sc_restricted_internet_access: true
            info "For starter deployment, always setting \"sc_restricted_internet_access\" as \"true\" in final custom resource."
            RESTRICTED_INTERNET_ACCESS="true"
        fi

        if [[ "$DEPLOYMENT_TYPE" == "production" && $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then

            # whether wfps authoring require LDAP
            if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" ]]; then
                select_ldap_type_for_wfps_authoring
            fi

            if [[ -z $LDAP_WFPS_AUTHORING || $LDAP_WFPS_AUTHORING == "Yes" ]]; then
                select_ldap_type
            fi

        fi
    elif [[ "$INSTALLATION_TYPE" == "existing" ]]
    then
        existing_infra_name=`cat $CP4A_EXISTING_BAK | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_hostname_suffix`
        if [ ! -z "$existing_infra_name" ]; then
            chrlen=${#existing_infra_name}
            INFRA_NAME=${existing_infra_name:21:chrlen}
        fi
        existing_ldap_type=`cat $CP4A_EXISTING_BAK | ${YQ_CMD} r - spec.ldap_configuration.lc_selected_ldap_type`
        if [[ "$existing_ldap_type" == "Microsoft Active Directory" ]];then
            LDAP_TYPE="AD"

        elif [[ "$existing_ldap_type" == "IBM Security Directory Server" ]]
        then
            LDAP_TYPE="TDS"
        fi
        existing_docker_reg_server=`cat $CP4A_EXISTING_BAK | ${YQ_CMD} r - spec.shared_configuration.sc_image_repository`
        if [[ "$existing_docker_reg_server" == *"icr.io"* ]]; then
            use_entitlement="yes"
        fi

        local_registry_server=`cat $CP4A_EXISTING_BAK | ${YQ_CMD} r - spec.shared_configuration.sc_image_repository`
        DOCKER_REG_SERVER="${existing_docker_reg_server}"
        LOCAL_REGISTRY_SERVER=${local_registry_server}
        OIFS=$IFS
        IFS='/' read -r -a docker_reg_url_array <<< "$local_registry_server"
        delim=""
        joined=""
        for item in "${docker_reg_url_array[@]}"; do
                joined="$joined$delim$item"
                delim="\/"
        done
        IFS=$OIFS
        CONVERT_LOCAL_REGISTRY_SERVER=${joined}
        DOCKER_RES_SECRET_NAME=`cat $CP4A_EXISTING_BAK | ${YQ_CMD} r - spec.shared_configuration.image_pull_secrets.[0]`
        STORAGE_CLASS_NAME=`cat $CP4A_EXISTING_BAK | ${YQ_CMD} r - spec.shared_configuration.storage_configuration.sc_dynamic_storage_classname`
        SLOW_STORAGE_CLASS_NAME=`cat $CP4A_EXISTING_BAK | ${YQ_CMD} r - spec.shared_configuration.storage_configuration.sc_slow_file_storage_classname`
        MEDIUM_STORAGE_CLASS_NAME=`cat $CP4A_EXISTING_BAK | ${YQ_CMD} r - spec.shared_configuration.storage_configuration.sc_medium_file_storage_classname`
        FAST_STORAGE_CLASS_NAME=`cat $CP4A_EXISTING_BAK | ${YQ_CMD} r - spec.shared_configuration.storage_configuration.sc_fast_file_storage_classname`
        BLOCK_STORAGE_CLASS_NAME=`cat $CP4A_EXISTING_BAK | ${YQ_CMD} r - spec.shared_configuration.storage_configuration.sc_block_storage_classname`
    fi

    if [[ "$DEPLOYMENT_TYPE" == "production" && $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
        if [[ " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
            select_objectstore_number
        fi
    fi
    if [[ $DEPLOYMENT_TYPE == "starter" || $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
        select_cpe_full_storage

        containsElement "document_processing_designer" "${PATTERNS_CR_SELECTED[@]}"
        retVal=$?
        if [[ ( $retVal -eq 0 ) && "$DEPLOYMENT_TYPE" == "production" ]]; then
            select_gpu_document_processing
        fi

        containsElement "document_processing" "${PATTERNS_CR_SELECTED[@]}"
        retVal=$?
        if [[ ( $retVal -eq 0 ) && "$DEPLOYMENT_TYPE" == "starter" ]]; then
            select_enable_deep_learning
            if [[ $ADP_DL_ENABLED == "Yes" ]]; then
                select_gpu_document_processing
            elif [[ $ADP_DL_ENABLED == "No" || -z $ADP_DL_ENABLED ]]; then
                ENABLE_GPU_ARIA="No"
            fi
        fi
    fi
    if [[ ! (" ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1") ]]; then
        if [[ $IBM_LICENS == "Accept" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ibm_license "accept"
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ibm_license ""
        fi
    fi
}

function apply_cp4a_operator(){
    ${COPY_CMD} -rf ${OPERATOR_FILE_BAK} ${OPERATOR_FILE_TMP}

    printf "\n"
    if [[ ("$SCRIPT_MODE" != "review") && ("$SCRIPT_MODE" != "OLM") ]]; then
        echo -e "\x1B[1mInstalling the Cloud Pak for Business Automation operator...\x1B[0m"
    fi
    # set db2_license
    ${SED_COMMAND} '/baw_license/{n;s/value:.*/value: accept/;}' ${OPERATOR_FILE_TMP}
    # Set operator image pull secret
    ${SED_COMMAND} "s|ibm-entitlement-key|$DOCKER_RES_SECRET_NAME|g" ${OPERATOR_FILE_TMP}
    ${SED_COMMAND} "s|admin.registrykey|$DOCKER_RES_SECRET_NAME|g" ${OPERATOR_FILE_TMP}
    # Set operator image registry
    new_operator="$REGISTRY_IN_FILE\/cp\/cp4a"

    if [ "$use_entitlement" = "yes" ] ; then
        ${SED_COMMAND} "s/$REGISTRY_IN_FILE/$DOCKER_REG_SERVER/g" ${OPERATOR_FILE_TMP}

    else
        ${SED_COMMAND} "s/$new_operator/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${OPERATOR_FILE_TMP}
    fi

    if [[ "${OCP_VERSION}" == "3.11" ]];then
        ${SED_COMMAND} "s/\# runAsUser\: 1001/runAsUser\: 1001/g" ${OPERATOR_FILE_TMP}
    fi

    if [[ $INSTALLATION_TYPE == "new" ]]; then
        ${CLI_CMD} delete -f ${OPERATOR_FILE_TMP} >/dev/null 2>&1
        sleep 5
    fi

    INSTALL_OPERATOR_CMD="${CLI_CMD} apply -f ${OPERATOR_FILE_TMP}"
    if $INSTALL_OPERATOR_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi

    ${COPY_CMD} -rf ${OPERATOR_FILE_TMP} ${OPERATOR_FILE_BAK}
    printf "\n"
    # Check deployment rollout status every 5 seconds (max 10 minutes) until complete.
    echo -e "\x1B[1mWaiting for the Cloud Pak operator to be ready. This might take a few minutes... \x1B[0m"
    ATTEMPTS=0
    ROLLOUT_STATUS_CMD="${CLI_CMD} rollout status deployment/ibm-cp4a-operator"
    until $ROLLOUT_STATUS_CMD || [ $ATTEMPTS -eq 120 ]; do
        $ROLLOUT_STATUS_CMD
        ATTEMPTS=$((ATTEMPTS + 1))
        sleep 5
    done
    if $ROLLOUT_STATUS_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi
    printf "\n"
}

function copy_jdbc_driver(){
    # Get pod name
    echo -e "\x1B[1mCopying the JDBC driver for the operator...\x1B[0m"
    operator_podname=$(${CLI_CMD} get pod|grep ibm-cp4a-operator|grep Running|awk '{print $1}')

    # ${CLI_CMD} exec -it ${operator_podname} -- rm -rf /opt/ansible/share/jdbc
    COPY_JDBC_CMD="${CLI_CMD} cp ${JDBC_DRIVER_DIR} ${operator_podname}:/opt/ansible/share/"

    if $COPY_JDBC_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi
}


function get_jdbc_url(){
    CP4BA_JDBC_URL=""
    while [[ $CP4BA_JDBC_URL == "" ]];
    do
        if [ -z "$CP4BA_JDBC_URL" ]; then
            printf "\n"
            echo -e "\x1B[1mProvide a URL to zip file that contains JDBC and/or ICCSAP drivers.\x1B[0m"
            read -p "(optional - if not provided, the Operator will configure using the default shipped JDBC driver): " CP4BA_JDBC_URL
            if [[ ( -z "$CP4BA_JDBC_URL" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ]]; then
                printf "\n"
                echo -e "\x1B[1;31mIBM Content Collector for SAP is selected, please provide a URL to zip file that contains ICCSAP drivers.\x1B[0m"
                CP4BA_JDBC_URL=""
            elif [[ ( -z "$CP4BA_JDBC_URL" ) && ( ! " ${optional_component_cr_arr[@]} " =~ "iccsap" ) ]]; then
                printf "\n"
                echo -e "\x1B[1mThe Operator will configure using the default shipped JDBC driver.\x1B[0m"
                break
            fi
        fi
    done
}

function copy_sap_libraries(){
    SAP_LIBS_LIST=("libicudata.so.50" "libicudecnumber.so" "libicui18n.so.50" "libicuuc.so.50" "libsapcrypto.so" "libsapjco3.so" "libsapnwrfc.so" "sapjco3.jar" "libsapucum.so")
    # Get pod name

    echo -e "\x1B[1mCopying the SAP libraries for the operator...\x1B[0m"
    #Check if saplibs folder exists
    if [ ! -d ${SAP_LIB_DIR} ]; then
        echo -e "\x1B[1;31m\"${SAP_LIB_DIR}\" directory does not exist! Please refer to the documentation to get the SAP libraries for ICCSAP. Exiting...
Check the following KC for details--> https://www.ibm.com/support/knowledgecenter/SSYHZ8_$CP4BA_RELEASE_BASE/com.ibm.dba.install/op_topics/tsk_deploy_demo.html \n\x1B[0m"
        exit 0
    fi

    #Check if all required SAP libs are present and print missing
    missing_libs="no"
    for file in "${SAP_LIBS_LIST[@]}"; do
        if [ ! -f ${SAP_LIB_DIR}/$file ]; then
            echo -e "\x1B[1;31m\"${SAP_LIB_DIR}/$file\" file does not exist!\n\x1B[0m"
            missing_libs="yes"
        fi
    done

    if [ $missing_libs == "yes" ]; then
        echo -e "\x1B[1;31mMissing required SAP Libraries. Please refer to the documentation to get the SAP libraries for ICCSAP. Exiting...
Check the following KC for details--> https://www.ibm.com/support/knowledgecenter/SSYHZ8_$CP4BA_RELEASE_BASE/com.ibm.dba.install/op_topics/tsk_deploy_demo.html \n\x1B[0m"
        exit 0
    fi

    operator_podname=$(${CLI_CMD} get pod|grep ibm-cp4a-operator|grep Running|awk '{print $1}')

    #Delete existing saplibs directory from /opt/ansible/share/ before creating new one
    if [[ $INSTALLATION_TYPE == "existing" ]]; then
        ${CLI_CMD} exec -it ${operator_podname} -- rm -rf /opt/ansible/share/saplibs
    fi

    COPY_SAP_CMD="${CLI_CMD} cp ${SAP_LIB_DIR} ${operator_podname}:/opt/ansible/share/"

    if $COPY_SAP_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi
}


function set_foundation_components(){
    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}
    if (( ${#FOUNDATION_DELETE_LIST[@]} > 0 ));then
        if (( ${#OPT_COMPONENTS_CR_SELECTED[@]} > 0 ));then
            # OPT_COMPONENTS_CR_SELECTED
            OPT_COMPONENTS_CR_SELECTED_UPPERCASE=()
            x=0;while [ ${x} -lt ${#OPT_COMPONENTS_CR_SELECTED[*]} ] ; do OPT_COMPONENTS_CR_SELECTED_UPPERCASE[$x]=$(tr [a-z] [A-Z] <<< ${OPT_COMPONENTS_CR_SELECTED[$x]}); let x++; done

            for host in ${OPT_COMPONENTS_CR_SELECTED_UPPERCASE[@]}; do
                FOUNDATION_DELETE_LIST=( "${FOUNDATION_DELETE_LIST[@]/$host}" )
            done
        fi

        for item in "${FOUNDATION_DELETE_LIST[@]}"; do
            if [[ "$item" == "BAS" ]];then
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration
            fi
            if [[ "$item" == "UMS" ]];then
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ums_configuration
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ums_datasource
            fi
            if [[ "$item" == "BAN" ]];then
                if [[ " ${optional_component_cr_arr[@]} " =~ "case" ]]; then
                    break
                else
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.navigator_configuration
                fi
            fi
            if [[ "$item" == "RR" ]];then
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.resource_registry_configuration
            fi
            if [[ "$item" == "AE" ]];then
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration
            fi
        done
    fi
    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}
}

function merge_pattern(){
    # echo "length of optional_component_cr_arr:${#optional_component_cr_arr[@]}"
    # echo "!!optional_component_cr_arr!!!${optional_component_cr_arr[*]}"
    # echo "EXISTING_PATTERN_ARR: ${EXISTING_PATTERN_ARR[*]}"
    # echo "PATTERNS_CR_SELECTED: ${PATTERNS_CR_SELECTED[*]}"
    # echo "EXISTING_OPT_COMPONENT_ARR: ${EXISTING_OPT_COMPONENT_ARR[*]}"
    # echo "OPT_COMPONENTS_CR_SELECTED: ${OPT_COMPONENTS_CR_SELECTED[*]}"
    # echo "FOUNDATION_CR_SELECTED_LOWCASE: ${FOUNDATION_CR_SELECTED_LOWCASE[*]}"
    # echo "FOUNDATION_DELETE_LIST: ${FOUNDATION_DELETE_LIST[*]}"
    # echo "OPTIONAL_COMPONENT_DELETE_LIST: ${OPTIONAL_COMPONENT_DELETE_LIST[*]}"
    # echo "KEEP_COMPOMENTS: ${KEEP_COMPOMENTS[*]}"
    # echo "REMOVED FOUNDATION_CR_SELECTED FROM OPTIONAL_COMPONENT_DELETE_LIST: ${OPTIONAL_COMPONENT_DELETE_LIST[*]}"
    # echo "pattern list in CR: ${pattern_joined}"
    # echo "optional components list in CR: ${opt_components_joined}"
    # echo "length of optional_component_arr:${#optional_component_arr[@]}"

    # read -rsn1 -p"Press any key to continue (DEBUG MODEL)";echo

    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}
    set_ldap_type_foundation
    for item in "${PATTERNS_CR_SELECTED[@]}"; do
        while true; do
            case $item in
                "content")
                    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
                        ${COPY_CMD} -rf "${CONTENT_SEPARATE_PATTERN_FILE}" "${CONTENT_PATTERN_FILE_BAK}"
                    fi
                    set_ldap_type_content_pattern
                    set_external_share_content_pattern
                    set_object_store_content_pattern
                    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
                        ${COPY_CMD} -rf "${CONTENT_PATTERN_FILE_BAK}" "${CP4A_PATTERN_FILE_TMP}"
                    else
                        ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
                    fi
                    break
                    ;;
                "contentanalyzer")
                    set_aca_tenant_pattern
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases
                    ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${ACA_PATTERN_FILE_BAK}
                    break
                    ;;
                "decisions")
                    set_decision_feature
                    ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${DECISIONS_PATTERN_FILE_BAK}
                    break
                    ;;
                "workflow")
                    # set_ldap_type_workflow_pattern
                    if [[ "${INSTALL_BAW_ONLY}" == "Yes" ]]; then
                        # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration
                        if [[ $DEPLOYMENT_TYPE == "production" ]];then
                            # if [[ $INSTALLATION_TYPE == "existing" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.datasource_configuration.dc_os_datasources
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.initialize_configuration
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.bastudio_configuration
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.baw_configuration
                            # fi
                            ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
                        elif [[ $DEPLOYMENT_TYPE == "starter" ]]
                        then
                            # if [[ $INSTALLATION_TYPE == "existing" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.baw_configuration
                            # fi
                            ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
                            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration
                        fi
                    fi
                    break
                    ;;
                "workflow-authoring")
                    # set_ldap_type_workstreams_pattern
                    ## Remove AE data persistent for workflow authoring from 22.0.2
                    # if [[ "$AE_DATA_PERSISTENCE_ENABLE" == "Yes" ]]; then
                    #     enable_ae_data_persistence_workflow_authoring
                    # fi
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration


                    if [[ $DEPLOYMENT_TYPE == "production" ]];then
                        # if [[ $INSTALLATION_TYPE == "existing" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring") ]]; then
                        #     ${YQ_CMD} d -i ${WORKFLOW_AUTHOR_PATTERN_FILE_BAK} spec.datasource_configuration.dc_os_datasources
                        #     ${YQ_CMD} d -i ${WORKFLOW_AUTHOR_PATTERN_FILE_BAK} spec.initialize_configuration
                        #     ${YQ_CMD} d -i ${WORKFLOW_AUTHOR_PATTERN_FILE_BAK} spec.bastudio_configuration
                        # fi
                        ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_AUTHOR_PATTERN_FILE_BAK}
                    fi
                    break
                    ;;
                "workflow-runtime")
                    # set_ldap_type_workstreams_pattern
                    if [[ $DEPLOYMENT_TYPE == "production" ]];then
                        if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workstreams" && " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-runtime" ]]; then
                            break
                        else
                            # if [[ $INSTALLATION_TYPE == "existing" ]]; then
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.baw_configuration
                            # fi
                            # if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" ]]; then
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.datasource_configuration.dc_os_datasources
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.initialize_configuration
                            # fi
                            ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
                        fi
                    elif [[ $DEPLOYMENT_TYPE == "starter" ]]
                    then
                        ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
                        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration
                    fi
                    break
                    ;;
                "workstreams")
                    # set_ldap_type_workstreams_pattern
                    ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WORKSTREAMS_PATTERN_FILE_BAK}
                    break
                    ;;
                "workflow-workstreams")
                    # set_ldap_type_ww_pattern
                    # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration
                    if [[ $DEPLOYMENT_TYPE == "production" ]];then
                        if [[ $INSTALLATION_TYPE == "existing" ]]; then
                            # if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime") ]]; then
                            #     ${YQ_CMD} d -i ${WORKSTREAMS_PATTERN_FILE_BAK} spec.datasource_configuration.dc_os_datasources.[1]
                            #     ${YQ_CMD} d -i ${WORKSTREAMS_PATTERN_FILE_BAK} spec.initialize_configuration.ic_ldap_creation
                            #     ${YQ_CMD} d -i ${WORKSTREAMS_PATTERN_FILE_BAK} spec.initialize_configuration.ic_obj_store_creation.object_stores.[1]
                            #     ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WORKSTREAMS_PATTERN_FILE_BAK}
                            # elif [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime") ]]
                            # then
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.datasource_configuration.dc_os_datasources.[3]
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.initialize_configuration.ic_ldap_creation
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.initialize_configuration.ic_obj_store_creation.object_stores.[3]
                            #     ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
                            # fi
                            ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WW_PATTERN_FILE_BAK}
                        else
                            ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WW_PATTERN_FILE_BAK}

                        fi
                    elif [[ $DEPLOYMENT_TYPE == "starter" ]]
                    then
                        ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WW_PATTERN_FILE_BAK}
                        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration
                    fi
                    break
                    ;;
                "application")
                    set_baa_app_designer
                    if [[ "$AE_DATA_PERSISTENCE_ENABLE" == "Yes" || " ${OPT_COMPONENTS_CR_SELECTED[@]} " =~ "ae_data_persistence" ]]; then
                        enable_ae_data_persistence_baa
                    fi
                    ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${APPLICATION_PATTERN_FILE_BAK}
                    break
                    ;;
                "digitalworker")
                    ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${ADW_PATTERN_FILE_BAK}
                    break
                    ;;
                "decisions_ads")
                    set_ads_designer_runtime
                    ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${ADS_PATTERN_FILE_BAK}
                    break
                    ;;
                "document_processing")
                    set_ldap_type_adp_pattern
                    set_aria_gpu
                    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                        if [[ $content_os_number -gt 0 && "${pattern_cr_arr[@]}" =~ "document_processing" && (! "${pattern_cr_arr[@]}" =~ "content") ]]; then
                            set_object_store_adp_pattern
                        else
                            OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${ARIA_PATTERN_FILE_BAK} | grep -Fn 'FNOS1DS'|cut -d':' -f1)
                            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                                ${YQ_CMD} d -i ${ARIA_PATTERN_FILE_BAK} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER]
                            fi
                            OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${ARIA_PATTERN_FILE_BAK} | grep -Fn 'FNOS1DS'|cut -d':' -f1)
                            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                                ${YQ_CMD} d -i ${ARIA_PATTERN_FILE_BAK} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER]
                            fi

                        fi
                        if [[ "${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
                            ${SED_COMMAND} "s/  #ecm_configuration:/  ecm_configuration:/g" ${ARIA_PATTERN_FILE_BAK}
                            ${SED_COMMAND} "s/  #  document_processing:/    document_processing:/g" ${ARIA_PATTERN_FILE_BAK}
                            ${SED_COMMAND} "s/  #    cpds:/      cpds:/g" ${ARIA_PATTERN_FILE_BAK}
                            ${SED_COMMAND} "s/  #      production_setting:/        production_setting:/g" ${ARIA_PATTERN_FILE_BAK}
                            ${SED_COMMAND} "s/  #        repo_service_url: \"<Required>\"/          repo_service_url: \"<Required>\"/g" ${ARIA_PATTERN_FILE_BAK}
                        fi
                    fi
                    ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${ARIA_PATTERN_FILE_BAK}
                    break
                    ;;
                "document_processing_runtime")
                    break
                    ;;
                "document_processing_designer")
                    break
                    ;;
                "workflow-process-service")
                    ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${WFPS_AUTHOR_PATTERN_FILE_BAK}
                    break
                    ;;
                "foundation")
                    break
                    ;;
            esac
        done
    done
}

function merge_optional_components(){
    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}
    for item in "${OPTIONAL_COMPONENT_DELETE_LIST[@]}"; do
        while true; do
            case $item in
                "bas")
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration
                    break
                    ;;
                "ums")
                    if [[ $PLATFORM_SELECTED == "other" ]]; then
                        containsElement "bai" "${optional_component_cr_arr[@]}"
                        retVal=$?
                        if [[ $retVal -eq 1 ]]; then
                            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ums_configuration
                            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ums_datasource
                        fi
                    else
                        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ums_configuration
                        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ums_datasource
                    fi
                    break
                    ;;
                "cmis")
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration.cmis
                    break
                    ;;
                "css")
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration.css
                    break
                    ;;
                "es")
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration.es
                    break
                    ;;
                "tm")
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration.tm
                    break
                    ;;
                "ier")
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ier_configuration
                    break
                    ;;
                "iccsap")
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.iccsap_configuration
                    break
                    ;;
                "ban")
                    break
                    ;;
                "case")
                    if [[ "${DEPLOYMENT_TYPE}" == "starter" && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "workstreams") && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "content_integration") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration
                    fi
                    break
                    ;;
                "workstreams")
                    if [[ "${DEPLOYMENT_TYPE}" == "starter" && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "case") && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "content_integration") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration
                    fi
                    break
                    ;;
                "content_integration")
                    if [[ "${DEPLOYMENT_TYPE}" == "starter" && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "workstreams") && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "case") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration
                    fi
                    break
                    ;;
                "bai")
                    if [[ (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-runtime") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workstreams") ]]; then
                        break
                    elif [[ "${DEPLOYMENT_TYPE}" == "starter" && (" ${OPT_COMPONENTS_CR_SELECTED[@]} " =~ "baml") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        break
                    else
                        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bai_configuration
                        break
                    fi
                    ;;
                "pfs")
                    if [[ "${DEPLOYMENT_TYPE}" == "starter" && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.pfs_configuration
                    fi
                    break
                    ;;
                "baml")
                    if [[ "${DEPLOYMENT_TYPE}" == "starter" && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baml_configuration
                    fi
                    break
                    ;;
                "ads_designer")
                    break
                    ;;
                "ads_runtime")
                    break
                    ;;
                "decisionCenter")
                    break
                    ;;
                "decisionRunner")
                    break
                    ;;
                "decisionServerRuntime")
                    break
                    ;;
                "app_designer")
                    break
                    ;;
                "ae_data_persistence")
                    break
                    ;;
                "baw_authoring")
                    break
                    ;;
                "auto_service")
                    break
                    ;;
                "document_processing_designer")
                    break
                    ;;
                "document_processing_runtime")
                    break
                    ;;
                "wfps_authoring")
                    break
                    ;;
                "kafka")
                    break
                    ;;
                "opensearch")
                    break
                    ;;
            esac
        done
    done
    FOUNDATION_CR_SELECTED=($(echo "${foundation_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    # FOUNDATION_CR_SELECTED_LOWCASE=( "${FOUNDATION_CR_SELECTED[@],,}" )

    x=0;while [ ${x} -lt ${#FOUNDATION_CR_SELECTED[*]} ] ; do FOUNDATION_CR_SELECTED_LOWCASE[$x]=$(tr [A-Z] [a-z] <<< ${FOUNDATION_CR_SELECTED[$x]}); let x++; done
    FOUNDATION_DELETE_LIST=($(echo "${FOUNDATION_CR_SELECTED[@]}" "${FOUNDATION_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))

    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}
}

function get_existing_pattern_name(){
    existing_pattern_cr_name=""
    existing_pattern_list=""
    existing_opt_component_list=""
    existing_platform_type=""
    existing_deployment_type=""
    existing_profile_type=""
    printf "\x1B[1mProvide the path and file name to the existing custom resource (CR)?\n\x1B[0m"
    printf "\x1B[1mPress [Enter] to accept default.\n\x1B[0m"
    # printf "\x1B[1mDefault is \x1B[0m(${CP4A_PATTERN_FILE_BAK}): "
    # existing_pattern_cr_name=`${CLI_CMD} get icp4acluster|awk '{if(NR>1){if(NR==2){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }'`

    while [[ $existing_pattern_cr_name == "" ]];
    do
        read -p "[Default=$CP4A_PATTERN_FILE_BAK]: " existing_pattern_cr_name
        : ${existing_pattern_cr_name:=$CP4A_PATTERN_FILE_BAK}
        if [ -f "$existing_pattern_cr_name" ]; then
            existing_pattern_list=`cat $existing_pattern_cr_name | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
            existing_opt_component_list=`cat $existing_pattern_cr_name | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`

            existing_platform_type=`cat $existing_pattern_cr_name | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_platform`
            existing_deployment_type=`cat $existing_pattern_cr_name | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_type`
            existing_profile_type=`cat $existing_pattern_cr_name | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_profile_size`

            if [[ $existing_deployment_type == "demo" ]];then
                existing_deployment_type="Starter"
            elif [[ $existing_deployment_type == "enterprise" ]];then
                existing_deployment_type="Production"
            fi
            case "${existing_deployment_type}" in
                starter*|Starter*)     DEPLOYMENT_TYPE="starter";;
                production*|Production*)    DEPLOYMENT_TYPE="production";;
                *)
                    echo -e "\x1B[1;31mNot valid deployment type found in CR, exiting....\n\x1B[0m"
                    exit 0
                    ;;
            esac

            case "${existing_platform_type}" in
                ROKS*)     PLATFORM_SELECTED="ROKS";;
                OCP*)    PLATFORM_SELECTED="OCP";;
                other*)     PLATFORM_SELECTED="other";;
                *)
                    echo -e "\x1B[1;31mNot valid platform type found in CR, exiting....\n\x1B[0m"
                    exit 0
                    ;;
            esac
            OIFS=$IFS
            IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
            IFS=$OIFS

            OIFS=$IFS
            IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
            IFS=$OIFS

            FOUNDATION_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOYMENT_TYPE}_foundation.yaml
            if [[ "$existing_pattern_cr_name" == "$CP4A_PATTERN_FILE_BAK" ]]; then
                ${COPY_CMD} -rf "${CP4A_PATTERN_FILE_BAK}" "${CP4A_EXISTING_BAK}"
                ${COPY_CMD} -rf "${CP4A_PATTERN_FILE_BAK}" "${CP4A_EXISTING_TMP}"
            else
                ${COPY_CMD} -rf "${existing_pattern_cr_name}" "${CP4A_PATTERN_FILE_BAK}"
                ${COPY_CMD} -rf "${existing_pattern_cr_name}" "${CP4A_EXISTING_BAK}"
                ${COPY_CMD} -rf "${existing_pattern_cr_name}" "${CP4A_EXISTING_TMP}"
            fi
            # ${COPY_CMD} -rf "${FOUNDATION_PATTERN_FILE}" "${CP4A_PATTERN_FILE_TMP}"
            # ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}
            # ${COPY_CMD} -rf "${CP4A_PATTERN_FILE_BAK}" "${CP4A_PATTERN_FILE_TMP}"
        else
            echo -e "\x1B[1;31m\"$existing_pattern_cr_name\" file does not exist! \n\x1B[0m"
            existing_pattern_cr_name=""
        fi
    done
    # existing_pattern_list=`${CLI_CMD} get icp4acluster $existing_pattern_cr_name -o yaml | yq r - spec.shared_configuration.sc_deployment_patterns`
    # existing_pattern_deploy_type=`${CLI_CMD} get icp4acluster $existing_pattern_cr_name -o yaml | yq r - spec.shared_configuration.sc_deployment_type`

    if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") ]]; then
        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "workflow-authoring" )
    fi

    if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && !(" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && ($retVal_baw -eq 1) ]]; then
        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "workflow-runtime" )
    fi

    if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer") ]]; then
        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "document_processing_designer" )
    fi

    if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_runtime") ]]; then
        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "document_processing_runtime" )
    fi

    if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-workstreams") && ("${DEPLOYMENT_TYPE}" == "production") ]]; then
        echo -e "\x1B[1;31mYou are updating existing patterns including workflow-workstreams which is not supported.\x1B[0m"
        echo -e "\x1B[1;31mRefer to the documentation to upgrade or add another pattern manually.\x1B[0m"
        echo -e "\x1B[1;31mexiting...\x1B[0m"
        read -rsn1 -p"Press any key to exit";echo
        exit 1
    fi
}

function select_objectstore_number(){
    content_os_number=""
    while true; do
        printf "\n"
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" && $DEPLOYMENT_WITH_PROPERTY == "Yes" ]]; then
            info "One default FNCM object store \"DEVOS1\" is added into property file. You could add more custom object store for ADP/Content pattern."
        elif [[ " ${pattern_cr_arr[@]}" =~ "document_processing" && $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
            info "One default FNCM object store \"DEVOS1\" is added into custom resource file. You could add more custom object store for ADP/Content pattern."
        fi

        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" && (! " ${pattern_cr_arr[@]}" =~ "content") ]]; then
            printf "\x1B[1mHow many additional object stores will be deployed for the document processing pattern? \x1B[0m"
        elif [[ " ${pattern_cr_arr[@]}" =~ "content" && (! " ${pattern_cr_arr[@]}" =~ "document_processing") ]]; then
            printf "\x1B[1mHow many object stores will be deployed for the content pattern? \x1B[0m"
        elif [[ " ${pattern_cr_arr[@]}" =~ "document_processing" && " ${pattern_cr_arr[@]}" =~ "content" ]]; then
            printf "\x1B[1mHow many object stores will be deployed for the content pattern and how many additional object stores will be deployed for the document processing pattern? \x1B[0m"
        fi
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" && (! " ${pattern_cr_arr[@]}" =~ "content") ]]; then
            read -rp "" content_os_number
            [[ $content_os_number =~ ^[0-9]+$ ]] || { echo -e "\x1B[1;31mEnter a valid number [0 to 10]\x1B[0m"; continue; }
            if [ "$content_os_number" -ge 0 ] && [ "$content_os_number" -le 10 ]; then
                break
            else
                echo -e "\x1B[1;31mEnter a valid number [0 to 10]\x1B[0m"
                content_os_number=""
            fi
        elif [[ " ${pattern_cr_arr[@]}" =~ "content" ]]; then
            read -rp "" content_os_number
            [[ $content_os_number =~ ^[0-9]+$ ]] || { echo -e "\x1B[1;31mEnter a valid number [1 to 10]\x1B[0m"; continue; }
            if [ "$content_os_number" -ge 1 ] && [ "$content_os_number" -le 10 ]; then
                break
            else
                echo -e "\x1B[1;31mEnter a valid number [1 to 10]\x1B[0m"
                content_os_number=""
            fi
        fi
    done
}

function select_gpu_document_processing(){
    printf "\n"
    set_gpu_enabled=""
    ENABLE_GPU_ARIA=""
    while [[ $set_gpu_enabled == "" ]];
    do
        printf "\x1B[1mAre there GPU enabled worker nodes (Yes/No)? \x1B[0m"
        read -rp "" set_gpu_enabled
        case "$set_gpu_enabled" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            ENABLE_GPU_ARIA="Yes"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            ENABLE_GPU_ARIA="No"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            set_gpu_enabled=""
            ENABLE_GPU_ARIA=""
            ;;
        esac
    done
    if [[ "${ENABLE_GPU_ARIA}" == "Yes" ]]; then
        printf "\n"
        printf "\x1B[1mWhat is the node label key used to identify the GPU worker node(s)? \x1B[0m"
        nodelabel_key=""
        while [[ $nodelabel_key == "" ]];
        do
            read -rp "" nodelabel_key
            if [ -z "$nodelabel_key" ]; then
            echo -e "\x1B[1;31mEnter the node label key.\x1B[0m"
            fi
        done

        printf "\n"
        printf "\x1B[1mWhat is the node label value used to identify the GPU worker node(s)? \x1B[0m"
        nodelabel_value=""
        while [[ $nodelabel_value == "" ]];
        do
            read -rp "" nodelabel_value
            if [ -z "$nodelabel_value" ]; then
            echo -e "\x1B[1;31mEnter the node label value.\x1B[0m"
            fi
        done
    fi
}

function set_baa_app_designer(){
    ${COPY_CMD} -rf ${APPLICATION_PATTERN_FILE_BAK} ${APPLICATION_PATTERN_FILE_TMP}
    if [[ $DEPLOYMENT_TYPE == "starter"  ]] ;
    then
        foundation_baa=("BAS")
        foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_baa[@]}" )

    elif [[ $DEPLOYMENT_TYPE == "production" ]]
    then
        containsElement "app_designer" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            foundation_baa=("BAS")
            foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_baa[@]}" )
        fi
    fi
    ${COPY_CMD} -rf ${APPLICATION_PATTERN_FILE_TMP} ${APPLICATION_PATTERN_FILE_BAK}
}

function set_ads_designer_runtime(){
    ${COPY_CMD} -rf ${ADS_PATTERN_FILE_BAK} ${ADS_PATTERN_FILE_TMP}
    if [[ $DEPLOYMENT_TYPE == "starter"  ]] ;
    then
        ${YQ_CMD} w -i ${ADS_PATTERN_FILE_TMP} spec.ads_configuration.decision_designer.enabled "true"
        ${YQ_CMD} w -i ${ADS_PATTERN_FILE_TMP} spec.ads_configuration.decision_runtime.enabled "true"
        foundation_ads=("BAS")
        foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_ads[@]}" )

    elif [[ $DEPLOYMENT_TYPE == "production" ]]
    then
        containsElement "ads_designer" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${YQ_CMD} w -i ${ADS_PATTERN_FILE_TMP} spec.ads_configuration.decision_designer.enabled "true"
            foundation_ads=("BAS")
            foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_ads[@]}" )
        else
            ${YQ_CMD} w -i ${ADS_PATTERN_FILE_TMP} spec.ads_configuration.decision_designer.enabled "false"
        fi
        containsElement "ads_runtime" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${YQ_CMD} w -i ${ADS_PATTERN_FILE_TMP} spec.ads_configuration.decision_runtime.enabled "true"
        else
            ${YQ_CMD} w -i ${ADS_PATTERN_FILE_TMP} spec.ads_configuration.decision_runtime.enabled "false"
        fi

    fi
    ${COPY_CMD} -rf ${ADS_PATTERN_FILE_TMP} ${ADS_PATTERN_FILE_BAK}
}


function set_decision_feature(){
    ${COPY_CMD} -rf ${DECISIONS_PATTERN_FILE_BAK} ${DECISIONS_PATTERN_FILE_TMP}
    if [[ $DEPLOYMENT_TYPE == "starter"  ]] ;
    then
        ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionCenter.enabled "true"
        ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionServerRuntime.enabled "true"
        ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionRunner.enabled "true"
    elif [[ $DEPLOYMENT_TYPE == "production" ]]
    then
        containsElement "decisionCenter" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionCenter.enabled "true"
        else
            ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionCenter.enabled "false"
        fi
        containsElement "decisionServerRuntime" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionServerRuntime.enabled "true"
        else
            ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionServerRuntime.enabled "false"
        fi
        containsElement "decisionRunner" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionRunner.enabled "true"
        else
            ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionRunner.enabled "false"
        fi
    fi
    ${COPY_CMD} -rf ${DECISIONS_PATTERN_FILE_TMP} ${DECISIONS_PATTERN_FILE_BAK}
}

function set_aria_gpu(){
    ${COPY_CMD} -rf ${ARIA_PATTERN_FILE_BAK} ${ARIA_PATTERN_FILE_TMP}
    if [[ ($DEPLOYMENT_TYPE == "production" && (" ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing_designer")) || $DEPLOYMENT_TYPE == "starter" ]] ;
    then
        if [[ "$ENABLE_GPU_ARIA" == "Yes" ]]; then
            ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.ca_configuration.deeplearning.gpu_enabled "true"
            # ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.ca_configuration.deeplearning.nodelabel_key "$nodelabel_key"
            ${SED_COMMAND} "s|nodelabel_key:.*|nodelabel_key: \"$nodelabel_key\"|g" ${ARIA_PATTERN_FILE_TMP}
            # ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.ca_configuration.deeplearning.nodelabel_value "$nodelabel_value"
            ${SED_COMMAND} "s|nodelabel_value:.*|nodelabel_value: \"$nodelabel_value\"|g" ${ARIA_PATTERN_FILE_TMP}

        elif [[ "$ENABLE_GPU_ARIA" == "No" ]]
        then
            ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.ca_configuration.deeplearning.gpu_enabled "false"
        fi
    else
        ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.ca_configuration.deeplearning.gpu_enabled "false"
    fi

    if [[ $DEPLOYMENT_TYPE == "starter" ]] ;
    then
        if [[ "$ADP_DL_ENABLED" == "Yes" ]]; then
            ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.ca_configuration.ocrextraction.deep_learning_object_detection.enabled "true"
        elif [[ "$ADP_DL_ENABLED" == "No" ]]
        then
            ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.ca_configuration.ocrextraction.deep_learning_object_detection.enabled "false"
        fi
    fi
    ${COPY_CMD} -rf ${ARIA_PATTERN_FILE_TMP} ${ARIA_PATTERN_FILE_BAK}
}

function get_oracle_service_name(){
    local JDBC_URL=$1

    JDBC_URL=$(sed -e 's/^"//' -e 's/"$//' <<<"$JDBC_URL")
    # Parse format is "jdbc:oracle:thin:@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=oracle21c1.fyre.ibm.com)(PORT=<your-database-port>))(CONNECT_DATA=(SERVICE_NAME=ORCLPDB1)))"
    if [[ "$JDBC_URL" == *"SERVICE_NAME="* || "$JDBC_URL" == *"service_name="* ]]; then
        if [[ "$machine" == "Mac" ]]; then
            local tmp_val_array=()
            local tmp_svc_array=()
            OIFS=$IFS
            IFS=')' read -ra tmp_val_array <<< "$JDBC_URL"
            IFS=$OIFS
            for item in "${tmp_val_array[@]}"
            do
                if [[ $item == *"SERVICE_NAME="* || $item == *"service_name="* ]]; then
                    OIFS=$IFS
                    IFS='=' read -ra tmp_svc_array <<< "$item"
                    IFS=$OIFS
                    ORACLE_SERVICE_NAME=${tmp_svc_array[${#tmp_svc_array[@]}-1]}
                fi
            done
        else
            ORACLE_SERVICE_NAME=$(echo "$JDBC_URL" | grep -oP '(?<=SERVICE_NAME=).*(?=)')
            if [[ -z "$ORACLE_SERVICE_NAME" ]]; then
                ORACLE_SERVICE_NAME=$(echo "$JDBC_URL" | grep -oP '(?<=service_name=).*(?=)')
            fi
            ORACLE_SERVICE_NAME=$(sed -e 's/^(//' -e 's/)$//' <<<"$ORACLE_SERVICE_NAME")

            until [[ "$ORACLE_SERVICE_NAME" != *")"* ]]; do
                ORACLE_SERVICE_NAME=$(sed -e 's/^(//' -e 's/)$//' <<<"$ORACLE_SERVICE_NAME")
            done
        fi
    else
        # Parse format is "jdbc:oracle:thin:@//oracle_server:1521/orcl"
        ORACLE_SERVICE_NAME=$(echo "$JDBC_URL" | cut -d"/" -f4)
    fi
    ORACLE_SERVICE_NAME=$(echo $ORACLE_SERVICE_NAME | tr '[:lower:]' '[:upper:]')
}

function sync_property_into_final_cr(){
    printf "\n"

    wait_msg "Applying value in property file into final CR"

    # Applying global value in user profile property into final CR
    tmp_value="$(prop_user_profile_property_file CP4BA.CP4BA_LICENSE)"
    ${SED_COMMAND} "s|sc_deployment_license:.*|sc_deployment_license: \"$tmp_value\"|g" ${CP4A_PATTERN_FILE_TMP}

    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        tmp_value="$(prop_user_profile_property_file CP4BA.FNCM_LICENSE)"
        ${SED_COMMAND} "s|sc_deployment_fncm_license:.*|sc_deployment_fncm_license: \"$tmp_value\"|g" ${CP4A_PATTERN_FILE_TMP}

        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" ]]; then
            tmp_value="$(prop_user_profile_property_file CP4BA.BAW_LICENSE)"
            ${SED_COMMAND} "s|sc_deployment_baw_license:.*|sc_deployment_baw_license: \"$tmp_value\"|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_baw_license
        fi
        # Applying value in GCDDB property file into final CR
        tmp_gcd_db_servername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
        tmp_gcd_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_gcd_db_servername")

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_gcd_db_name="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
        else
            tmp_gcd_db_name="$(prop_db_name_user_property_file GCD_DB_NAME)"
        fi
        tmp_gcd_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_gcd_db_name")
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_gcd_db_name=$(echo $tmp_gcd_db_name | tr '[:upper:]' '[:lower:]')
        fi

        for i in "${!GCDDB_CR_MAPPING[@]}"; do
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${GCDDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_gcd_db_servername.${GCDDB_COMMON_PROPERTY[i]})\""
        done

        # remove database_name if oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            get_oracle_service_name $(prop_db_server_property_file $tmp_gcd_db_servername.ORACLE_JDBC_URL)
            if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_gcd_datasource.database_name "\"${ORACLE_SERVICE_NAME}GCD\""
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_gcd_datasource.database_name "\"<Required>\""
            fi
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_gcd_datasource.database_name "\"$tmp_gcd_db_name\""
            if [[ $DB_TYPE == "postgresql-edb" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_gcd_datasource.dc_database_type "postgresql"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_gcd_datasource.dc_use_postgres "true"
            fi
        fi

        # Apply customized schema for GCDDB
        tmp_schema_name=$(prop_db_name_user_property_file GCD_DB_CURRENT_SCHEMA)
        tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
        if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_schema_name=$(echo $tmp_schema_name | tr '[:upper:]' '[:lower:]')
            fi
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration.cpe_production_setting.gcd_schema  "\"${tmp_schema_name}\""
        fi

        # Applying user profile for CONTENT INITIONLIZATION
        tmp_init_flag="$(prop_user_profile_property_file CONTENT_INITIALIZATION.ENABLE)"
        tmp_init_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_init_flag")
        if [[ $tmp_init_flag == "Yes" || $tmp_init_flag == "YES" || $tmp_init_flag == "Y" || $tmp_init_flag == "True" || $tmp_init_flag == "true" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_content_initialization "true"

            # Set initialize_configuration.ic_ldap_creation
            tmp_admin_user_name=$(prop_user_profile_property_file CONTENT_INITIALIZATION.LDAP_ADMIN_USER_NAME)
            tmp_admin_user_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_admin_user_name")

            tmp_admin_group_name=$(prop_user_profile_property_file CONTENT_INITIALIZATION.LDAP_ADMINS_GROUPS_NAME)
            tmp_admin_group_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_admin_group_name")

            OIFS=$IFS
            IFS=',' read -ra admin_user_name_array <<< "$tmp_admin_user_name"
            IFS=',' read -ra admin_group_name_array <<< "$tmp_admin_group_name"
            IFS=$OIFS

            for num in "${!admin_user_name_array[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_ldap_creation.ic_ldap_admin_user_name.[$((num))] "\"${admin_user_name_array[num]}\""
            done

            for num in "${!admin_group_name_array[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_ldap_creation.ic_ldap_admins_groups_name.[$((num))] "\"${admin_group_name_array[num]}\""
            done
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_content_initialization "false"
        fi
    else
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_fncm_license
    fi

    # Applying value in FNCM OSDB property file into final CR
    if (( content_os_number > 0 )); then
        for ((j=0;j<${content_os_number};j++)); do
            tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name OS$((j+1))_DB_USER_NAME)"
            tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")

            if [[ $DB_TYPE == "oracle" ]]; then
                tmp_os_db_name="$(prop_db_name_user_property_file OS$((j+1))_DB_USER_NAME)"
            else
                tmp_os_db_name="$(prop_db_name_user_property_file OS$((j+1))_DB_NAME)"
            fi
            # tmp_os_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_name")
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_os_db_name=$(echo $tmp_os_db_name | tr '[:upper:]' '[:lower:]')
            fi

            OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn "FNOS$((j+1))DS"|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                for i in "${!OSDB_CR_MAPPING[@]}"; do
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[i]})\""
                done
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label "\"os$((j+1))\""

                # remove database_name if oracle
                if [[ $DB_TYPE == "oracle" ]]; then
                    get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                    if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"${ORACLE_SERVICE_NAME}OS$((j+1))\""
                    else
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"<Required>\""
                    fi
                    # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name $tmp_os_db_name
                    if [[ $DB_TYPE == "postgresql-edb" ]]; then
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_database_type "postgresql"
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_use_postgres "true"
                    fi
                fi
            fi
        done

        # apply oc_cpe_obj_store_admin_user_groups for FNCM OS
        for ((j=0;j<${content_os_number};j++))
        do
            OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn FNOS$((j+1))DS|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
                tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
                OIFS=$IFS
                IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
                IFS=$OIFS

                for num in "${!admin_user_group_array[@]}"; do
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups.[$((num))]  "\"${admin_user_group_array[num]}\""
                done
                # Apply customized schema
                # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                tmp_schema_name=$(prop_db_name_user_property_file OS$((j+1))_DB_CURRENT_SCHEMA)
                tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
                if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        tmp_schema_name=$(echo $tmp_schema_name | tr '[:upper:]' '[:lower:]')
                    fi
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name  "\"${tmp_schema_name}\""
                fi
                # fi
            fi
        done

    fi
    # Apply value in FNCM OS required by BAW authoring property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
        for i in "${!BAW_AUTH_OS_ARR[@]}"; do
            OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_AUTH_OS_ARR[i]}|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
                if [[ $DB_TYPE == "oracle" ]]; then
                    tmp_os_db_name="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                else
                    tmp_os_db_name="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_NAME)"
                fi
                # tmp_os_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_name")
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_os_db_name=$(echo $tmp_os_db_name | tr '[:upper:]' '[:lower:]')
                fi
                for j in "${!OSDB_CR_MAPPING[@]}"; do
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[j]}" "\"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[j]})\""
                done

                tmp_label=$(echo ${BAW_AUTH_OS_ARR[i]} | tr '[:upper:]' '[:lower:]')
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label "\"$tmp_label\""
                # remove database_name if oracle
                if [[ $DB_TYPE == "oracle" ]]; then
                    get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                    if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"${ORACLE_SERVICE_NAME}${BAW_AUTH_OS_ARR[i]}\""
                    else
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"<Required>\""
                    fi
                    # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name $tmp_os_db_name
                    if [[ $DB_TYPE == "postgresql-edb" ]]; then
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_database_type "postgresql"
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_use_postgres "true"
                    fi
                fi
            fi
            # Apply customized schema
            OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_AUTH_OS_ARR[i]} |cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                tmp_schema_name=$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_CURRENT_SCHEMA)
                tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
                if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        tmp_schema_name=$(echo $tmp_schema_name | tr '[:upper:]' '[:lower:]')
                    fi
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name  "\"${tmp_schema_name}\""
                fi
                # fi
            fi
        done

        # apply oc_cpe_obj_store_admin_user_groups for FNCM OS used by BAW authoring
        for i in "${!BAW_AUTH_OS_ARR[@]}"; do
            OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_AUTH_OS_ARR[i]}|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
                tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
                OIFS=$IFS
                IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
                IFS=$OIFS

                for num in "${!admin_user_group_array[@]}"; do
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups.[$((num))]  "\"${admin_user_group_array[num]}\""
                done
            fi
        done

        # apply property for workflow initionlization into final cr
        if [[ "${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" ]]; then
            tmp_workflow_flag=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ENABLE_WORKFLOW)
            tmp_workflow_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_workflow_flag")
            if [[ $tmp_workflow_flag == "Yes" || $tmp_workflow_flag == "YES" || $tmp_workflow_flag == "Y" || $tmp_workflow_flag == "True" || $tmp_workflow_flag == "true" ]]; then
                tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_val=$(echo $tmp_val | tr '[:upper:]' '[:lower:]')
                elif [[ $DB_TYPE == "oracle" ]]; then
                    tmp_val=$(echo $tmp_val | tr '[:lower:]' '[:upper:]')
                fi
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_data_tbl_space  "\"$tmp_val\""

                tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_ADMIN_GROUP)
                tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_admin_group  "\"$tmp_val\""

                tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_CONFIG_GROUP)
                tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_config_group  "\"$tmp_val\""

                tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME)
                tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_pe_conn_point_name  "\"$tmp_val\""
            fi
        fi

    fi

    # Apply value in FNCM OS required by BAW runtime property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" ]]; then
        BAW_RUNTIME_OS_ARR=("BAWINS1DOCS" "BAWINS1DOS" "BAWINS1TOS")
        for i in "${!BAW_AUTH_OS_ARR[@]}"; do
            OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_RUNTIME_OS_ARR[i]}|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
                if [[ $DB_TYPE == "oracle" ]]; then
                    tmp_os_db_name="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                else
                    tmp_os_db_name="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_NAME)"
                fi
                # tmp_os_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_name")
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_os_db_name=$(echo $tmp_os_db_name | tr '[:upper:]' '[:lower:]')
                fi
                for j in "${!OSDB_CR_MAPPING[@]}"; do
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[j]}" "\"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[j]})\""
                done

                tmp_label=$(echo ${BAW_AUTH_OS_ARR[i]} | tr '[:upper:]' '[:lower:]')

                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label "\"$tmp_label\""

                # remove database_name if oracle
                if [[ $DB_TYPE == "oracle" ]]; then
                    get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                    if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"${ORACLE_SERVICE_NAME}${BAW_AUTH_OS_ARR[i]}\""
                    else
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"<Required>\""
                    fi
                    # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name $tmp_os_db_name
                    if [[ $DB_TYPE == "postgresql-edb" ]]; then
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_database_type "postgresql"
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_use_postgres "true"
                    fi
                fi
            fi

            # Apply customized schema
            OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_RUNTIME_OS_ARR[i]} |cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                tmp_schema_name=$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_CURRENT_SCHEMA)
                tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
                if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        tmp_schema_name=$(echo $tmp_schema_name | tr '[:upper:]' '[:lower:]')
                    fi
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name  "\"${tmp_schema_name}\""
                fi
                # fi
            fi
        done

        # apply oc_cpe_obj_store_admin_user_groups for FNCM OS used by BAW runtime
        for i in "${!BAW_RUNTIME_OS_ARR[@]}"; do
            OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_RUNTIME_OS_ARR[i]}|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
                tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
                OIFS=$IFS
                IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
                IFS=$OIFS

                for num in "${!admin_user_group_array[@]}"; do
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups.[$((num))]  "\"${admin_user_group_array[num]}\""
                done
            fi
            # apply property for workflow initionlization into final cr
            if [[ "${BAW_RUNTIME_OS_ARR[i]}" == "BAWINS1TOS" ]]; then
                tmp_workflow_flag=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ENABLE_WORKFLOW)
                tmp_workflow_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_workflow_flag")
                if [[ $tmp_workflow_flag == "Yes" || $tmp_workflow_flag == "YES" || $tmp_workflow_flag == "Y" || $tmp_workflow_flag == "True" || $tmp_workflow_flag == "true" ]]; then
                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        tmp_val=$(echo $tmp_val | tr '[:upper:]' '[:lower:]')
                    elif [[ $DB_TYPE == "oracle" ]]; then
                        tmp_val=$(echo $tmp_val | tr '[:lower:]' '[:upper:]')
                    fi
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_data_tbl_space  "\"$tmp_val\""

                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_ADMIN_GROUP)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_admin_group  "\"$tmp_val\""

                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_CONFIG_GROUP)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_config_group  "\"$tmp_val\""

                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_pe_conn_point_name  "\"$tmp_val\""
                fi
            fi
        done

    fi

    # Apply value in FNCM OS required by AWS property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AWSINS1DOCS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
            tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
            if [[ $DB_TYPE == "oracle" ]]; then
                tmp_os_db_name="$(prop_db_name_user_property_file AWSDOCS_DB_USER_NAME)"
            else
                tmp_os_db_name="$(prop_db_name_user_property_file AWSDOCS_DB_NAME)"
            fi
            # tmp_os_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_name")
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_os_db_name=$(echo $tmp_os_db_name | tr '[:upper:]' '[:lower:]')
            fi
            for i in "${!OSDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[i]})\""
            done

            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label "\"awsdocs\""

            # remove database_name if oracle
            if [[ $DB_TYPE == "oracle" ]]; then
                get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"${ORACLE_SERVICE_NAME}AWSDOCS\""
                else
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"<Required>\""
                fi
                # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name $tmp_os_db_name
                if [[ $DB_TYPE == "postgresql-edb" ]]; then
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_database_type "postgresql"
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_use_postgres "true"
                fi
            fi
        fi

        # Apply customized schema
        OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AWSINS1DOCS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_schema_name=$(prop_db_name_user_property_file AWSDOCS_DB_CURRENT_SCHEMA)
            tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
            if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_schema_name=$(echo $tmp_schema_name | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name  "\"${tmp_schema_name}\""
            fi
            # fi
        fi

        # apply oc_cpe_obj_store_admin_user_groups for FNCM OS used by workstreams
        OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AWSINS1DOCS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
            tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
            OIFS=$IFS
            IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
            IFS=$OIFS

            for num in "${!admin_user_group_array[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups.[$((num))]  "\"${admin_user_group_array[num]}\""
            done
        fi
    fi

    # Apply value in DEVOS1 property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'DEVOS1DS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name DEVOS_DB_USER_NAME)"
            tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")

            if [[ $DB_TYPE == "oracle" ]]; then
                tmp_os_db_name="$(prop_db_name_user_property_file DEVOS_DB_USER_NAME)"
            else
                tmp_os_db_name="$(prop_db_name_user_property_file DEVOS_DB_NAME)"
            fi
            # tmp_os_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_name")
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_os_db_name=$(echo $tmp_os_db_name | tr '[:upper:]' '[:lower:]')
            fi
            for i in "${!OSDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[i]})\""
            done
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label "\"devos1\""
            # remove database_name if oracle
            if [[ $DB_TYPE == "oracle" ]]; then
                get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"${ORACLE_SERVICE_NAME}DEVOS\""
                else
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"<Required>\""
                fi
                # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name $tmp_os_db_name
                if [[ $DB_TYPE == "postgresql-edb" ]]; then
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_database_type "postgresql"
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_use_postgres "true"
                fi
            fi
        fi
        # apply oc_cpe_obj_store_admin_user_groups for FNCM OS used by DEVOS1
        OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'DEVOS1DS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
            tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
            OIFS=$IFS
            IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
            IFS=$OIFS
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups
            for num in "${!admin_user_group_array[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups.[$((num))]  "\"${admin_user_group_array[num]}\""
            done
        fi

        # Apply customized schema
        OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'DEVOS1DS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_schema_name=$(prop_db_name_user_property_file DEVOS_DB_CURRENT_SCHEMA)
            tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
            if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_schema_name=$(echo $tmp_schema_name | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name  "\"${tmp_schema_name}\""
            fi
            # fi
        fi
    fi

    # Apply value in FNCM OS required by AE data persistent property file into final CR
    if [[ "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name AEOS_DB_USER_NAME)"
            tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")

            if [[ $DB_TYPE == "oracle" ]]; then
                tmp_os_db_name="$(prop_db_name_user_property_file AEOS_DB_USER_NAME)"
            else
                tmp_os_db_name="$(prop_db_name_user_property_file AEOS_DB_NAME)"
            fi
            # tmp_os_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_name")
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_os_db_name=$(echo $tmp_os_db_name | tr '[:upper:]' '[:lower:]')
            fi
            for i in "${!OSDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[i]})\""
            done
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label "\"aeos\""
            # remove database_name if oracle
            if [[ $DB_TYPE == "oracle" ]]; then
                get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"${ORACLE_SERVICE_NAME}AEOS\""
                else
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"<Required>\""
                fi
                # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name $tmp_os_db_name
                if [[ $DB_TYPE == "postgresql-edb" ]]; then
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_database_type "postgresql"
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_use_postgres "true"
                fi
            fi
        fi

        # Apply customized schema
        OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_schema_name=$(prop_db_name_user_property_file AEOS_DB_CURRENT_SCHEMA)
            tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
            if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_schema_name=$(echo $tmp_schema_name | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name  "\"${tmp_schema_name}\""
            fi
            # fi
        fi

        # apply oc_cpe_obj_store_admin_user_groups for FNCM OS used by AE data persistent
        OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
            tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
            OIFS=$IFS
            IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
            IFS=$OIFS

            for num in "${!admin_user_group_array[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups.[$((num))]  "\"${admin_user_group_array[num]}\""
            done
        fi
    fi

    # Apply value in FNCM OS required by Case history property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'CHOS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name CHOS_DB_USER_NAME)"
            tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")

            if [[ $DB_TYPE == "oracle" ]]; then
                tmp_os_db_name="$(prop_db_name_user_property_file CHOS_DB_USER_NAME)"
            else
                tmp_os_db_name="$(prop_db_name_user_property_file CHOS_DB_NAME)"
            fi
            # tmp_os_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_name")
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_os_db_name=$(echo $tmp_os_db_name | tr '[:upper:]' '[:lower:]')
            fi
            for i in "${!OSDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[i]})\""
            done

            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label "\"ch\""

            # remove database_name if oracle
            if [[ $DB_TYPE == "oracle" ]]; then
                get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"${ORACLE_SERVICE_NAME}CHOS\""
                else
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name "\"<Required>\""
                fi
                # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name $tmp_os_db_name
                if [[ $DB_TYPE == "postgresql-edb" ]]; then
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_database_type "postgresql"
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_use_postgres "true"
                fi
            fi
        fi
        # Apply customized schema
        OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'CHOS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_schema_name=$(prop_db_name_user_property_file CHOS_DB_CURRENT_SCHEMA)
            tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
            if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_schema_name=$(echo $tmp_schema_name | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name  "\"${tmp_schema_name}\""
            fi
            # fi
        fi
    fi

    # Applying value in ICN property file into final CR
    if [[ " ${foundation_component_arr[@]}" =~ "BAN" ]]; then
        if [[ ! (" ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "1") ]]; then
            tmp_icn_db_servername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
            tmp_icn_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_icn_db_servername")

            if [[ $DB_TYPE == "oracle" ]]; then
                tmp_icn_db_name="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
            else
                tmp_icn_db_name="$(prop_db_name_user_property_file ICN_DB_NAME)"
            fi
            # tmp_icn_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_icn_db_name")
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_icn_db_name=$(echo $tmp_icn_db_name | tr '[:upper:]' '[:lower:]')
            fi

            for i in "${!ICNDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${ICNDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_icn_db_servername.${ICNDB_COMMON_PROPERTY[i]})\""
                # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${ICNDB_CR_MAPPING[i]}" "\"$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_icn_db_servername.${ICNDB_COMMON_PROPERTY[i]})")\""
            done

            # remove database_name if oracle
            if [[ $DB_TYPE == "oracle" ]]; then
                get_oracle_service_name $(prop_db_server_property_file $tmp_icn_db_servername.ORACLE_JDBC_URL)
                if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_icn_datasource.database_name "\"${ORACLE_SERVICE_NAME}ICN\""
                else
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_icn_datasource.database_name "\"<Required>\""
                fi
                # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_icn_datasource.database_name $tmp_icn_db_name
                if [[ $DB_TYPE == "postgresql-edb" ]]; then
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_icn_datasource.dc_database_type "postgresql"
                    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_icn_datasource.dc_use_postgres "true"
                fi
            fi
            # Apply customized schema for GCDDB
            tmp_schema_name=$(prop_db_name_user_property_file ICN_DB_CURRENT_SCHEMA)
            tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
            if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_schema_name=$(echo $tmp_schema_name | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.navigator_configuration.icn_production_setting.icn_schema  "\"${tmp_schema_name}\""
            fi
        fi
    fi

    # Applying value in ODM property file into final CR
    containsElement "decisions" "${pattern_cr_arr[@]}"
    odm_Val=$?
    if [[ $odm_Val -eq 0 ]]; then
        tmp_odm_db_servername="$(prop_db_name_user_property_file_for_server_name ODM_DB_USER_NAME)"
        tmp_odm_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_odm_db_servername")

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_odm_db_name="$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
        else
            tmp_odm_db_name="$(prop_db_name_user_property_file ODM_DB_NAME)"
        fi
        tmp_odm_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_odm_db_name")

        for i in "${!ODMDB_CR_MAPPING[@]}"; do
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${ODMDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_odm_db_servername.${ODMDB_COMMON_PROPERTY[i]})\""
        done
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_odm_datasource.dc_database_type "postgresql"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_odm_datasource.dc_use_postgres "true"
        fi
        # For ODM, set dc_ssl_secret_name only when db is db2/oracle/postgresql with clientAuth
        if [[ $DB_TYPE == "postgresql" ]]; then
            postgresql_ssl_enable=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_odm_db_servername.DATABASE_SSL_ENABLE)")
            tmp_ssl_flag=$(echo $postgresql_ssl_enable | tr '[:upper:]' '[:lower:]')

            postgresql_client_auth_enable=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_odm_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_client_auth_flag=$(echo $postgresql_client_auth_enable | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            tmp_ssl_flag="true"
            tmp_client_auth_flag="true"
        fi
        if [[ ($tmp_ssl_flag == "yes" || $tmp_ssl_flag == "true" || $tmp_ssl_flag == "y") && ($tmp_client_auth_flag == "yes" || $tmp_client_auth_flag == "true" || $tmp_client_auth_flag == "y") ]]; then
            create_odm_postgresql_secret="Yes"
        else
            create_odm_postgresql_secret="No"
        fi
        if [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" || $DB_TYPE == "oracle" || $create_odm_postgresql_secret == "Yes" ]]; then
            tmp_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_odm_db_servername.DATABASE_SSL_ENABLE)")
            tmp_ssl_flag=$(echo $tmp_ssl_flag | tr '[:upper:]' '[:lower:]')
            if [[ $tmp_ssl_flag == "yes" || $tmp_ssl_flag == "true" || $tmp_ssl_flag == "y" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_odm_datasource.dc_ssl_secret_name "$(prop_db_server_property_file $tmp_odm_db_servername.DATABASE_SSL_SECRET_NAME)"
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_odm_datasource.dc_ssl_secret_name "\"\""
            fi
        else
            ${SED_COMMAND} "s|dc_ssl_secret_name: |# dc_ssl_secret_name: |g" ${CP4A_PATTERN_FILE_TMP}
        fi

        # set dc_odm_datasource.dc_common_database_instance_secret
        tmp_secret_name=`kubectl get secret -l db-name=${tmp_odm_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_odm_datasource.dc_common_database_instance_secret "\"$tmp_secret_name\""

        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_odm_db_name=$(echo $tmp_odm_db_name | tr '[:upper:]' '[:lower:]')
        fi
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_odm_datasource.dc_common_database_name "\"$tmp_odm_db_name\""
        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_odm_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_odm_db_servername.ORACLE_JDBC_URL)")
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_odm_datasource.dc_common_database_url "\"$tmp_odm_db_jdbc_url\""
        fi
    fi

    # Applying value in BAW Authoring property file into final CR (only 21.0.3.x/22.0.1.x)
    # if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then

    #     tmp_baw_authoring_db_servername="$(prop_db_name_user_property_file_for_server_name AUTHORING_DB_USER_NAME)"
    #     tmp_baw_authoring_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_authoring_db_servername")

    #     if [[ $DB_TYPE == "oracle" ]]; then
    #         tmp_baw_authoring_db_name="$(prop_db_name_user_property_file AUTHORING_DB_USER_NAME)"
    #     else
    #         tmp_baw_authoring_db_name="$(prop_db_name_user_property_file AUTHORING_DB_NAME)"
    #     fi

    #     tmp_baw_authoring_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_authoring_db_name")

    #     for i in "${!BAW_AUTHORING_CR_MAPPING[@]}"; do
    #         if [[ ("${BAW_AUTHORING_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${BAW_AUTHORING_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
    #             ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${BAW_AUTHORING_CR_MAPPING[i]}" "\"<Remove>\""
    #         else
    #             ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${BAW_AUTHORING_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_baw_authoring_db_servername.${BAW_AUTHORING_COMMON_PROPERTY[i]})\""
    #         fi
    #     done

    #     tmp_secret_name=`kubectl get secret -l db-name=${tmp_baw_authoring_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`

    #     # set workflow_authoring_configuration
    #     ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.workflow_authoring_configuration.database.secret_name "\"$tmp_secret_name\""
    #     if [[ $DB_TYPE == "postgresql" ]]; then
    #         tmp_baw_authoring_db_name=$(echo $tmp_baw_authoring_db_name | tr '[:upper:]' '[:lower:]')
    #     fi

    #     # remove database_name if oracle
    #     if [[ $DB_TYPE == "oracle" ]]; then
    #         ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.workflow_authoring_configuration.database.database_name "\"<Remove>\""
    #         # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
    #     else
    #         ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.workflow_authoring_configuration.database.database_name "\"$tmp_baw_authoring_db_name\""
    #     fi
    #     # remove jdbc_url/custom_jdbc_pvc
    #     if [[ $DB_TYPE == "oracle" || $DB_TYPE == "postgresql" ]]; then
    #         tmp_baw_authoring_db_jdbc_url="$(prop_db_server_property_file $tmp_baw_runtime_db_servername.ORACLE_JDBC_URL)"
    #         tmp_baw_authoring_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_authoring_db_jdbc_url")
    #         ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.workflow_authoring_configuration.database.jdbc_url "\"$tmp_baw_authoring_db_jdbc_url\""
    #     else
    #         ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.workflow_authoring_configuration.database.jdbc_url "\"<Remove>\""
    #         ${SED_COMMAND} "s|jdbc_url: '\"<Remove>\"'|# jdbc_url: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
    #     fi
    #     ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.workflow_authoring_configuration.database.custom_jdbc_pvc "\"<Remove>\""
    #     ${SED_COMMAND} "s|custom_jdbc_pvc: '\"<Remove>\"'|# custom_jdbc_pvc: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
    # fi

    # Applying value in BAW Runtime property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams") ]]; then

        tmp_baw_runtime_db_servername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
        tmp_baw_runtime_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_servername")

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_baw_runtime_db_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
        else
            tmp_baw_runtime_db_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
        fi

        tmp_baw_runtime_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_name")

        for i in "${!BAW_RUNTIME_CR_MAPPING[@]}"; do
            if [[ ("${BAW_RUNTIME_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${BAW_RUNTIME_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${BAW_RUNTIME_CR_MAPPING[i]}" "\"<Remove>\""
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${BAW_RUNTIME_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_baw_runtime_db_servername.${BAW_RUNTIME_COMMON_PROPERTY[i]})\""
            fi
        done

        tmp_secret_name=`kubectl get secret -l db-name=${tmp_baw_runtime_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`

        # set baw_configuration
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.secret_name "\"$tmp_secret_name\""
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_baw_runtime_db_name=$(echo $tmp_baw_runtime_db_name | tr '[:upper:]' '[:lower:]')
        fi

        # remove database_name if oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.database_name "\"<Remove>\""
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.database_name "\"$tmp_baw_runtime_db_name\""
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_baw_runtime_db_jdbc_url="$(prop_db_server_property_file $tmp_baw_runtime_db_servername.ORACLE_JDBC_URL)"
            tmp_baw_runtime_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_jdbc_url")
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.jdbc_url "\"$tmp_baw_runtime_db_jdbc_url\""
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.jdbc_url "\"<Remove>\""
            ${SED_COMMAND} "s|jdbc_url: '\"<Remove>\"'|# jdbc_url: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        fi
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.custom_jdbc_pvc "\"<Remove>\""
        ${SED_COMMAND} "s|custom_jdbc_pvc: '\"<Remove>\"'|# custom_jdbc_pvc: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}

        # set current schema name for db2 and postgresql
        if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_baw_runtime_db_current_schema_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_CURRENT_SCHEMA)"
            tmp_baw_runtime_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_current_schema_name")
            if [[ $tmp_baw_runtime_db_current_schema_name != "<Optional>" && $tmp_baw_runtime_db_current_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_baw_runtime_db_current_schema_name=$(echo $tmp_baw_runtime_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.current_schema "\"$tmp_baw_runtime_db_current_schema_name\""
            fi
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.type "postgresql"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.dc_use_postgres "true"
            # always use default schema for postgresql EDB
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.current_schema
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`cat $CP4A_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.baw_configuration.[0].database`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.enable_ssl "true"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.db_cert_secret_name "{{ meta.name }}-pg-client-cert-secret"
            fi
        fi
        # Applying user profile for BAW runtime
        tmp_baw_runtime_admin="$(prop_user_profile_property_file BAW_RUNTIME.ADMIN_USER)"
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].admin_user "\"$tmp_baw_runtime_admin\""
    fi

    # Applying value in BAW Runtime+Workstreams property file into final CR
    if [[ "${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
        tmp_baw_runtime_db_servername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
        tmp_baw_runtime_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_servername")

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_baw_runtime_db_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
        else
            tmp_baw_runtime_db_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
        fi

        tmp_baw_runtime_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_name")

        for i in "${!BAW_RUNTIME_CR_MAPPING[@]}"; do
            if [[ ("${BAW_RUNTIME_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${BAW_RUNTIME_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${BAW_RUNTIME_CR_MAPPING[i]}" "\"<Remove>\""
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${BAW_RUNTIME_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_baw_runtime_db_servername.${BAW_RUNTIME_COMMON_PROPERTY[i]})\""
            fi
        done

        tmp_secret_name=`kubectl get secret -l db-name=${tmp_baw_runtime_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`

        # set baw_configuration
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.secret_name "\"$tmp_secret_name\""
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_baw_runtime_db_name=$(echo $tmp_baw_runtime_db_name | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.database_name "\"<Remove>\""
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.database_name "\"$tmp_baw_runtime_db_name\""
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_baw_runtime_db_jdbc_url="$(prop_db_server_property_file $tmp_baw_runtime_db_servername.ORACLE_JDBC_URL)"
            tmp_baw_runtime_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_jdbc_url")
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.jdbc_url "\"$tmp_baw_runtime_db_jdbc_url\""
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.jdbc_url "\"<Remove>\""
            ${SED_COMMAND} "s|jdbc_url: '\"<Remove>\"'|# jdbc_url: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        fi
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.custom_jdbc_pvc "\"<Remove>\""
        ${SED_COMMAND} "s|custom_jdbc_pvc: '\"<Remove>\"'|# custom_jdbc_pvc: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}

        # set current schema name for db2 and postgresql
        if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_baw_runtime_db_current_schema_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_CURRENT_SCHEMA)"
            tmp_baw_runtime_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_current_schema_name")
            if [[ $tmp_baw_runtime_db_current_schema_name != "<Optional>" && $tmp_baw_runtime_db_current_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_baw_runtime_db_current_schema_name=$(echo $tmp_baw_runtime_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                fi

                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.current_schema "\"$tmp_baw_runtime_db_current_schema_name\""
            fi
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.type "postgresql"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.dc_use_postgres "true"
            # always use default schema for postgresql EDB
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.current_schema
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`cat $CP4A_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.baw_configuration.[0].database`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.enable_ssl "true"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.db_cert_secret_name "{{ meta.name }}-pg-client-cert-secret"
            fi
        fi

        tmp_aws_db_servername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
        tmp_aws_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_servername")
        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_aws_db_name="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
        else
            tmp_aws_db_name="$(prop_db_name_user_property_file AWS_DB_NAME)"
        fi
        tmp_aws_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_name")

        for i in "${!AWS_CR_MAPPING[@]}"; do
            if [[ ("${AWS_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${AWS_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${AWS_CR_MAPPING[i]}" "\"<Remove>\""
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${AWS_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_aws_db_servername.${AWS_COMMON_PROPERTY[i]})\""
            fi
        done

        tmp_secret_name=`kubectl get secret -l db-name=${tmp_aws_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`

        # set baw_configuration
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.secret_name "\"$tmp_secret_name\""
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_aws_db_name=$(echo $tmp_aws_db_name | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.database_name "\"<Remove>\""
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.database_name "\"$tmp_aws_db_name\""
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_aws_db_jdbc_url="$(prop_db_server_property_file $tmp_aws_db_servername.ORACLE_JDBC_URL)"
            tmp_aws_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_jdbc_url")
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.jdbc_url "\"$tmp_aws_db_jdbc_url\""
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.jdbc_url "\"<Remove>\""
            ${SED_COMMAND} "s|jdbc_url: '\"<Remove>\"'|# jdbc_url: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        fi
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.custom_jdbc_pvc "\"<Remove>\""
        ${SED_COMMAND} "s|custom_jdbc_pvc: '\"<Remove>\"'|# custom_jdbc_pvc: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}

        # set current schema name for db2 and postgresql
        if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_aws_db_current_schema_name="$(prop_db_name_user_property_file AWS_DB_CURRENT_SCHEMA)"
            tmp_aws_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_current_schema_name")
            if [[ $tmp_aws_db_current_schema_name != "<Optional>" && $tmp_aws_db_current_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_aws_db_current_schema_name=$(echo $tmp_aws_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                fi

                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.current_schema "\"$tmp_aws_db_current_schema_name\""
            fi
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.type "postgresql"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.dc_use_postgres "true"
            # always use default schema for postgresql EDB
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.current_schema
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`cat $CP4A_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.baw_configuration.[1].database`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.enable_ssl "true"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].database.db_cert_secret_name "{{ meta.name }}-pg-client-cert-secret"
            fi
        fi

        # Applying user profile for BAW runtime
        tmp_baw_runtime_admin="$(prop_user_profile_property_file BAW_RUNTIME.ADMIN_USER)"
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].admin_user "\"$tmp_baw_runtime_admin\""

        # Applying user profile for AWS
        tmp_aws_admin="$(prop_user_profile_property_file AWS.ADMIN_USER)"
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[1].admin_user "\"$tmp_aws_admin\""
    fi

    # Applying value in Workstreams property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams") ]]; then
        tmp_aws_db_servername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
        tmp_aws_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_servername")

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_aws_db_name="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
        else
            tmp_aws_db_name="$(prop_db_name_user_property_file AWS_DB_NAME)"
        fi
        tmp_aws_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_name")
        for i in "${!AWS_ONLY_CR_MAPPING[@]}"; do
            if [[ ("${AWS_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${AWS_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${AWS_ONLY_CR_MAPPING[i]}" "\"<Remove>\""
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${AWS_ONLY_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_aws_db_servername.${AWS_COMMON_PROPERTY[i]})\""
            fi
        done

        tmp_secret_name=`kubectl get secret -l db-name=${tmp_aws_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`

        # set baw_configuration
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.secret_name "\"$tmp_secret_name\""

        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_aws_db_name=$(echo $tmp_aws_db_name | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.database_name "\"<Remove>\""
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.database_name "\"$tmp_aws_db_name\""
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_aws_db_jdbc_url="$(prop_db_server_property_file $tmp_aws_db_servername.ORACLE_JDBC_URL)"
            tmp_aws_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_jdbc_url")
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.jdbc_url "\"$tmp_aws_db_jdbc_url\""
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.jdbc_url "\"<Remove>\""
            ${SED_COMMAND} "s|jdbc_url: '\"<Remove>\"'|# jdbc_url: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        fi
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.custom_jdbc_pvc "\"<Remove>\""
        ${SED_COMMAND} "s|custom_jdbc_pvc: '\"<Remove>\"'|# custom_jdbc_pvc: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}

        if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_aws_db_current_schema_name="$(prop_db_name_user_property_file AWS_DB_CURRENT_SCHEMA)"
            tmp_aws_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_current_schema_name")
            if [[ $tmp_aws_db_current_schema_name != "<Optional>" && $tmp_aws_db_current_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_aws_db_current_schema_name=$(echo $tmp_aws_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                fi

                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.current_schema "\"$tmp_aws_db_current_schema_name\""
            fi
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.type "postgresql"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.dc_use_postgres "true"
            # always use default schema for postgresql EDB
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.current_schema
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`cat $CP4A_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.baw_configuration.[0].database`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.enable_ssl "true"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.db_cert_secret_name "{{ meta.name }}-pg-client-cert-secret"
            fi
        fi

        # Applying user profile for AWS
        tmp_aws_admin="$(prop_user_profile_property_file AWS.ADMIN_USER)"
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[0].admin_user "\"$tmp_aws_admin\""
    fi

    # Applying value in ADS property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "decisions_ads" ]]; then
        tmp_mongo_flag="$(prop_user_profile_property_file ADS.USE_EXTERNAL_MONGODB)"
        tmp_mongo_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_mongo_flag")
        if [[ $tmp_mongo_flag == "Yes" || $tmp_mongo_flag == "YES" || $tmp_mongo_flag == "Y" || $tmp_mongo_flag == "True" || $tmp_mongo_flag == "true" ]]; then
            tmp_secret_name=`kubectl get secret -l db-name=ads-mongo -o yaml | ${YQ_CMD} r - items.[0].metadata.name`
            if [[ -z $tmp_secret_name ]]; then
                info "Not found ibm-dba-ads-mongo-secret secret for an external MongoDB"
            fi
            # set baw_configuration
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ads_configuration.mongo.use_embedded "false"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ads_configuration.mongo.admin_secret_name "\"$tmp_secret_name\""
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ads_configuration.mongo.use_embedded "true"
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ads_configuration.mongo.admin_secret_name
        fi
    fi

    # Applying value in ACA property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        tmp_adp_db_servername="$(prop_db_name_user_property_file_for_server_name ADP_BASE_DB_USER_NAME)"
        tmp_adp_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_db_servername")

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_adp_db_name="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
        else
            tmp_adp_db_name="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
        fi
        tmp_adp_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_db_name")

        for i in "${!ADPDB_CR_MAPPING[@]}"; do
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${ADPDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_adp_db_servername.${ADPDB_COMMON_PROPERTY[i]})\""
        done
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.database_name "\"$tmp_adp_db_name\""

        # set dc_ca_datasource.tenant_databases
        local db_name_array=()
        tmp_dbname=$(prop_db_name_user_property_file ADP_PROJECT_DB_NAME)

        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

        OIFS=$IFS
        IFS=',' read -ra db_name_array <<< "$tmp_dbname"
        IFS=$OIFS
        # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases
        for i in ${!db_name_array[@]}; do
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases.[${i}] "\"${db_name_array[i]}\""
        done
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.dc_database_type "postgresql"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.dc_use_postgres "true"
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`cat $CP4A_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_ca_datasource`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.dc_database_ssl_enabled "true"
                # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.dc_ssl_secret_name "{{ meta.name }}-pg-client-cert-secret"
            fi
        fi

        # Apply git connection secret if true when ADP designer
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            tmp_git_flag="$(prop_user_profile_property_file ADP.ENABLE_GIT_SSL_CONNECTION)"
            tmp_git_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_git_flag")
            if [[ $tmp_git_flag == "Yes" || $tmp_git_flag == "YES" || $tmp_git_flag == "Y" || $tmp_git_flag == "True" || $tmp_git_flag == "true" ]]; then
                tmp_git_secret_name="$(prop_user_profile_property_file ADP.GIT_SSL_SECRET_NAME)"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.trusted_certificate_list.[0] "\"$tmp_git_secret_name\""
            fi
        fi

        # Apply repo_service_url and CDRA route certificate and runtime_feedback if ADP runtime
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
            tmp_repo_service_url="$(prop_user_profile_property_file ADP.CPDS_REPO_SERVICE_URL)"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration.document_processing.cpds.production_setting.repo_service_url "\"$tmp_repo_service_url\""

            tmp_cdra_secret_name="$(prop_user_profile_property_file ADP.CDRA_SSL_SECRET_NAME)"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.trusted_certificate_list.[0] "\"$tmp_cdra_secret_name\""

            tmp_runtime_feedback_enabled="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_ENABLED)"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ca_configuration.global.runtime_feedback.enabled "\"$tmp_runtime_feedback_enabled\""

            tmp_runtime_feedback_runtime_type="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_RUNTIME_TYPE)"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ca_configuration.global.runtime_feedback.runtime_type "\"$tmp_runtime_feedback_runtime_type\""

            tmp_runtime_feedback_design_api_secret="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_DESIGN_API_SECRET)"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ca_configuration.global.runtime_feedback.design_api_secret "\"$tmp_runtime_feedback_design_api_secret\""

            tmp_runtime_feedback_design_tls_secret="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_DESIGN_TLS_SECRET)"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ca_configuration.global.runtime_feedback.design_tls_secret "\"$tmp_runtime_feedback_design_tls_secret\""
        fi
    fi

    # Applying value in BAStudio property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-process-service" || " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || "${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
        tmp_bas_db_servername="$(prop_db_name_user_property_file_for_server_name STUDIO_DB_USER_NAME)"
        tmp_bas_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_bas_db_servername")

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_bas_db_name="$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)"
        else
            tmp_bas_db_name="$(prop_db_name_user_property_file STUDIO_DB_NAME)"
        fi
        tmp_bas_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_bas_db_name")

        for i in "${!BASDB_CR_MAPPING[@]}"; do
            if [[ ("${BASDB_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${BASDB_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${BASDB_CR_MAPPING[i]}" "\"<Remove>\""
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${BASDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_bas_db_servername.${BASDB_COMMON_PROPERTY[i]})\""
            fi
        done

        tmp_secret_name=`kubectl get secret -l db-name=${tmp_bas_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`

        # set bastudio_configuration
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.admin_secret_name "\"$tmp_secret_name\""
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_bas_db_name=$(echo $tmp_bas_db_name | tr '[:upper:]' '[:lower:]')
        fi

        # remove database_name if oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.database.name "\"<Remove>\""
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.database.name "\"$tmp_bas_db_name\""
        fi


        if [[ $DB_TYPE != "oracle" ]]; then
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.database.oracle_url
        fi

        # Applying user profile for BAS
        tmp_bas_admin="$(prop_user_profile_property_file BASTUDIO.ADMIN_USER)"
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.admin_user "\"$tmp_bas_admin\""

        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.database.type "postgresql"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.database.dc_use_postgres "true"
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`cat $CP4A_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.bastudio_configuration.database`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.database.ssl_enabled "true"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.database.certificate_secret_name "{{ meta.name }}-pg-client-cert-secret"
            fi
        fi
    fi

    # Applying value in playback server property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then

        tmp_app_db_servername="$(prop_db_name_user_property_file_for_server_name APP_PLAYBACK_DB_USER_NAME)"
        tmp_app_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_app_db_servername")

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_app_db_name="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
        else
            tmp_app_db_name="$(prop_db_name_user_property_file APP_PLAYBACK_DB_NAME)"
        fi
        tmp_app_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_app_db_name")

        for i in "${!PLAYBACKDB_CR_MAPPING[@]}"; do
            if [[ ("${PLAYBACKDB_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${PLAYBACKDB_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${PLAYBACKDB_CR_MAPPING[i]}" "\"<Remove>\""
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${PLAYBACKDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_app_db_servername.${PLAYBACKDB_COMMON_PROPERTY[i]})\""
            fi
        done

        tmp_secret_name=`kubectl get secret -l db-name=${tmp_app_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`

        # set bastudio_configuration.playback_server
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.admin_secret_name "\"$tmp_secret_name\""
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_app_db_name=$(echo $tmp_app_db_name | tr '[:upper:]' '[:lower:]')
        fi

        # remove database_name if oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.database.name "\"<Remove>\""
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.database.name "\"$tmp_app_db_name\""
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.database.oracle_url_without_wallet_directory
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.database.oracle_url_with_wallet_directory
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.database.oracle_sso_wallet_secret_name
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.database.type "postgresql"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.database.dc_use_postgres "true"
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`cat $CP4A_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.bastudio_configuration.playback_server.database`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.database.enable_ssl "true"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.database.db_cert_secret_name "{{ meta.name }}-pg-client-cert-secret"
            fi
        fi
        # Applying user profile for Playback
        tmp_playback_admin="$(prop_user_profile_property_file APP_PLAYBACK.ADMIN_USER)"
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.admin_user "\"$tmp_playback_admin\""

        # Applying user profile for AE HA Redis session
        tmp_session_flag="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_USE_EXTERNAL_STORE)"
        tmp_session_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_session_flag")
        if [[ $tmp_session_flag == "Yes" || $tmp_session_flag == "YES" || $tmp_session_flag == "Y" || $tmp_session_flag == "True" || $tmp_session_flag == "true" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.session.use_external_store "true"

            tmp_redis_host="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_HOST)"
            tmp_redis_port="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_PORT)"
            tmp_redis_ssl_secret_name="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_SSL_SECRET_NAME)"
            tmp_redis_tls_enabled="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_TLS_ENABLED)"
            tmp_redis_tls_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_tls_enabled")
            tmp_redis_username="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_USERNAME)"

            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.redis.host "\"$tmp_redis_host\""
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.redis.port "\"$tmp_redis_port\""
            if [[ $tmp_redis_tls_enabled == "Yes" || $tmp_redis_tls_enabled == "YES" || $tmp_redis_tls_enabled == "Y" || $tmp_redis_tls_enabled == "True" || $tmp_redis_tls_enabled == "true" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.redis.tls_enabled "true"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.tls.tls_trust_list.[0] "\"$tmp_redis_ssl_secret_name\""
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.redis.tls_enabled "false"
            fi
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.redis.username "\"$tmp_redis_username\""
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.session.use_external_store "false"
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server.redis
        fi
    fi

    # Applying value in Automation Application server property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "application" || " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then

        tmp_ae_db_servername="$(prop_db_name_user_property_file_for_server_name APP_ENGINE_DB_USER_NAME)"
        tmp_ae_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ae_db_servername")
        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_ae_db_name="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
        else
            tmp_ae_db_name="$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)"
        fi
        tmp_ae_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ae_db_name")

        for i in "${!AEDB_CR_MAPPING[@]}"; do
            if [[ ("${AEDB_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${AEDB_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${AEDB_CR_MAPPING[i]}" "\"<Remove>\""
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${AEDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_ae_db_servername.${AEDB_COMMON_PROPERTY[i]})\""
            fi
        done

        tmp_secret_name=`kubectl get secret -l db-name=${tmp_ae_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`

        # set application_engine_configuration
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].admin_secret_name "\"$tmp_secret_name\""
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_ae_db_name=$(echo $tmp_ae_db_name | tr '[:upper:]' '[:lower:]')
        fi
        # remove database_name if oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.name "\"<Remove>\""
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.name "\"$tmp_ae_db_name\""
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.oracle_url_without_wallet_directory
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.oracle_url_with_wallet_directory
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.oracle_sso_wallet_secret_name
        fi

        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.type "postgresql"
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.dc_use_postgres "true"
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`cat $CP4A_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.application_engine_configuration.[0].database`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.enable_ssl "true"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.db_cert_secret_name "{{ meta.name }}-pg-client-cert-secret"
            fi
        fi
        # Applying user profile for AE
        tmp_ae_admin="$(prop_user_profile_property_file APP_ENGINE.ADMIN_USER)"
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].admin_user "\"$tmp_ae_admin\""

        # Applying user profile for AE HA Redis session
        tmp_session_flag="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_USE_EXTERNAL_STORE)"
        tmp_session_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_session_flag")
        if [[ $tmp_session_flag == "Yes" || $tmp_session_flag == "YES" || $tmp_session_flag == "Y" || $tmp_session_flag == "True" || $tmp_session_flag == "true" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].session.use_external_store "true"

            tmp_redis_host="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_HOST)"
            tmp_redis_port="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_PORT)"
            tmp_redis_ssl_secret_name="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_SSL_SECRET_NAME)"
            tmp_redis_tls_enabled="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_TLS_ENABLED)"
            tmp_redis_tls_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_tls_enabled")
            tmp_redis_username="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_USERNAME)"

            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].redis.host "\"$tmp_redis_host\""
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].redis.port "\"$tmp_redis_port\""
            if [[ $tmp_redis_tls_enabled == "Yes" || $tmp_redis_tls_enabled == "YES" || $tmp_redis_tls_enabled == "Y" || $tmp_redis_tls_enabled == "True" || $tmp_redis_tls_enabled == "true" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].redis.tls_enabled "true"
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].tls.tls_trust_list.[0] "\"$tmp_redis_ssl_secret_name\""
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].redis.tls_enabled "false"
            fi
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].redis.username "\"$tmp_redis_username\""
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].session.use_external_store "false"
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].redis
        fi
    fi

    # set dc_ssl_enabled always true for postgresql-edb
    if [[ $DB_TYPE == "postgresql-edb" ]]; then

        ds_cfg_val=`cat $CP4A_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.datasource_configuration`
        if [[ ! -z "$ds_cfg_val" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ssl_enabled "true"
        fi
    fi

    # Applying value in LDAP property file into final CR
    for i in "${!LDAP_COMMON_CR_MAPPING[@]}"; do
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${LDAP_COMMON_CR_MAPPING[i]}" "\"$(prop_ldap_property_file ${LDAP_COMMON_PROPERTY[i]})\""
    done

    if [[ $LDAP_TYPE == "AD" ]]; then
        for i in "${!AD_LDAP_CR_MAPPING[@]}"; do
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${AD_LDAP_CR_MAPPING[i]}" "\"$(prop_ldap_property_file ${AD_LDAP_PROPERTY[i]})\""
        done
    else
        for i in "${!TDS_LDAP_CR_MAPPING[@]}"; do
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${TDS_LDAP_CR_MAPPING[i]}" "\"$(prop_ldap_property_file ${TDS_LDAP_PROPERTY[i]})\""
        done
    fi
    # set lc_bind_secret
    tmp_secret_name=`kubectl get secret -l name=ldap-bind-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.name`
    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_bind_secret "\"$tmp_secret_name\""
    # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_ldap_bind_dn
    # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_ldap_bind_dn_pwd
    # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_ldap_ssl_secret_folder


    # Applying value in External LDAP property file into final CR
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        for i in "${!LDAP_COMMON_CR_MAPPING[@]}"; do
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${EXT_LDAP_COMMON_CR_MAPPING[i]}" "\"$(prop_ext_ldap_property_file ${LDAP_COMMON_PROPERTY[i]})\""
        done

        tmp_ldap_type="$(prop_ext_ldap_property_file LDAP_TYPE)"
        tmp_ldap_type=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_type")
        if [[ $tmp_ldap_type == "Microsoft Active Directory" ]]; then
            for i in "${!AD_LDAP_CR_MAPPING[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${EXT_AD_LDAP_CR_MAPPING[i]}" "\"$(prop_ext_ldap_property_file ${AD_LDAP_PROPERTY[i]})\""
            done
        elif [[ $tmp_ldap_type == "IBM Security Directory Server" ]]; then
            for i in "${!TDS_LDAP_CR_MAPPING[@]}"; do
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${EXT_TDS_LDAP_CR_MAPPING[i]}" "\"$(prop_ext_ldap_property_file ${TDS_LDAP_PROPERTY[i]})\""
            done
        else
            fail "The value for \"LDAP_TYPE\" in the property file \"${EXTERNAL_LDAP_PROPERTY_FILE}\" is not valid. The possible values are: \"IBM Security Directory Server\" or \"Microsoft Active Directory\""
            exit 1
        fi

        # set lc_bind_secret
        tmp_secret_name=`kubectl get secret -l name=ext-ldap-bind-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.name`
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ext_ldap_configuration.lc_bind_secret "\"$tmp_secret_name\""
        # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ext_ldap_configuration.lc_ldap_bind_dn
        # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ext_ldap_configuration.lc_ldap_bind_dn_pwd
        # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ext_ldap_configuration.lc_ldap_ssl_secret_folder
    fi

    # Applying value in scim property file into final CR
    set_scim_attr="true"
    if [[ "${set_scim_attr}" == "true" ]]; then
      if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" || (" ${pattern_cr_arr[@]}" =~ "workflow-process-service" && "${optional_component_cr_arr[@]}" =~ "wfps_authoring") ]]; then
          for i in "${!SCIM_PROPERTY[@]}"; do
              ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${SCIM_CR_MAPPING[i]}" "\"$(prop_user_profile_property_file ${SCIM_PROPERTY[i]})\""
          done
      fi
    fi
    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} null
    ${SED_COMMAND} "s|'\"|\"|g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|\"'|\"|g" ${CP4A_PATTERN_FILE_TMP}
    # ${SED_COMMAND} "s|\"\"|\"|g" ${CP4A_PATTERN_FILE_TMP}
    # Remove HADR if dose not input value
    ${SED_COMMAND} "s/: \"<Optional>\"/: \"\"/g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"\"<Optional>\"\"/: \"\"/g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: <Optional>/: \"\"/g" ${CP4A_PATTERN_FILE_TMP}

    ${SED_COMMAND} "s/database_ip: \"<Required>\"/database_ip: \"\"/g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/dc_hadr_standby_ip: \"<Required>\"/dc_hadr_standby_ip: \"\"/g" ${CP4A_PATTERN_FILE_TMP}

    # convert ssl enable true or false to meet CSV
    ${SED_COMMAND} "s/: \"True\"/: true/g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"False\"/: false/g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"true\"/: true/g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"false\"/: false/g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"Yes\"/: true/g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"yes\"/: true/g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"No\"/: false/g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"no\"/: false/g" ${CP4A_PATTERN_FILE_TMP}

    # Remove all null string
    ${SED_COMMAND} "s/: null/: /g" ${CP4A_PATTERN_FILE_TMP}


    # comment out sc_ingress_tls_secret_name if OCP platform
    if [[ $PLATFORM_SELECTED == "OCP" ]]; then
        ${SED_COMMAND} "s/sc_ingress_tls_secret_name: /# sc_ingress_tls_secret_name: /g" ${CP4A_PATTERN_FILE_TMP}
    fi

    # comment out the database_servername/database_port/database_name/HADR if the db is oracle
    if [[ $DB_TYPE == "oracle" ]]; then
        ${SED_COMMAND} "s/database_servername:/# database_servername:/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/database_port:/# database_port:/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/database_name: \"<Remove>\"/# database_name: \"\"/g" ${CP4A_PATTERN_FILE_TMP}

        ${SED_COMMAND} "s/alternative_host:/# alternative_host:/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/alternative_port:/# alternative_port:/g" ${CP4A_PATTERN_FILE_TMP}

        ${SED_COMMAND} "s/server_name: \"<Remove>\"/# server_name: \"\"/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/port: \"<Remove>\"/# port: \"\"/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/host: \"<Remove>\"/# host: \"\"/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/name: \"<Remove>\"/# name: \"\"/g" ${CP4A_PATTERN_FILE_TMP}

        ${SED_COMMAND} "s/dc_hadr_standby_servername:/# dc_hadr_standby_servername:/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_hadr_standby_port:/# dc_hadr_standby_port:/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_hadr_retry_interval_for_client_reroute:/# dc_hadr_retry_interval_for_client_reroute:/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_hadr_max_retries_for_client_reroute:/# dc_hadr_max_retries_for_client_reroute:/g" ${CP4A_PATTERN_FILE_TMP}
    fi

    # ensure nodelabel_value is string
    if [[ "$ENABLE_GPU_ARIA" == "Yes" ]]; then
        ${SED_COMMAND} "s|nodelabel_value:.*|nodelabel_value: \"$nodelabel_value\"|g" ${CP4A_PATTERN_FILE_TMP}
    fi
    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}
    success "Applied value in property file into final CR under $FINAL_CR_FOLDER"
    msgB "Please confirm final custom resource under $FINAL_CR_FOLDER"
}

# Begin - Modify FOUNDATION pattern yaml according patterns/components selected
function apply_pattern_cr(){
    # echo -e "\x1B[1mCreating a custom resource YAML file for IBM CP4A Operator ......\x1B[0m"
    # echo "length of optional_component_cr_arr:${#optional_component_cr_arr[@]}"
    # echo "!!optional_component_cr_arr!!!${optional_component_cr_arr[*]}"
    # echo "EXISTING_PATTERN_ARR: ${EXISTING_PATTERN_ARR[*]}"
    # echo "PATTERNS_CR_SELECTED: ${PATTERNS_CR_SELECTED[*]}"
    # echo "EXISTING_OPT_COMPONENT_ARR: ${EXISTING_OPT_COMPONENT_ARR[*]}"
    # echo "OPT_COMPONENTS_CR_SELECTED: ${OPT_COMPONENTS_CR_SELECTED[*]}"
    # echo "FOUNDATION_CR_SELECTED_LOWCASE: ${FOUNDATION_CR_SELECTED_LOWCASE[*]}"
    # echo "FOUNDATION_DELETE_LIST: ${FOUNDATION_DELETE_LIST[*]}"
    # echo "OPTIONAL_COMPONENT_DELETE_LIST: ${OPTIONAL_COMPONENT_DELETE_LIST[*]}"
    # echo "KEEP_COMPOMENTS: ${KEEP_COMPOMENTS[*]}"
    # echo "REMOVED FOUNDATION_CR_SELECTED FROM OPTIONAL_COMPONENT_DELETE_LIST: ${OPTIONAL_COMPONENT_DELETE_LIST[*]}"
    # echo "pattern list in CR: ${pattern_joined}"
    # echo "optional components list in CR: ${opt_components_joined}"
    # echo "length of optional_component_arr:${#optional_component_arr[@]}"

    # read -rsn1 -p"Press any key to continue (DEBUG MODEL)";echo

    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}
    # remove merge issue
    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} metadata.labels.app.*

    # Keep existing value
    if [[ "${INSTALLATION_TYPE}" == "existing" ]]; then
        # read -rsn1 -p"Before Merge: Press any key to continue";echo
        ${YQ_CMD} d -i ${CP4A_EXISTING_TMP} spec.shared_configuration.sc_deployment_patterns
        ${YQ_CMD} d -i ${CP4A_EXISTING_TMP} spec.shared_configuration.sc_optional_components
        ${SED_COMMAND} '/tag: /d' ${CP4A_EXISTING_TMP}
        ${SED_COMMAND} '/appVersion: /d' ${CP4A_EXISTING_TMP}
        ${SED_COMMAND} '/release: /d' ${CP4A_EXISTING_TMP}
        # ${YQ_CMD} m -a -i -M ${CP4A_EXISTING_BAK} ${CP4A_PATTERN_FILE_TMP}
        # ${COPY_CMD} -rf ${CP4A_EXISTING_BAK} ${CP4A_PATTERN_FILE_TMP}
        # ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${CP4A_EXISTING_BAK}
        # read -rsn1 -p"After Merge: Press any key to continue";echo
    fi

    ${SED_COMMAND_FORMAT} ${CP4A_PATTERN_FILE_TMP}
    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}

    tps=" ${OPTIONAL_COMPONENT_DELETE_LIST[*]} "
    for item in ${KEEP_COMPOMENTS[@]}; do
        tps=${tps/ ${item} / }
    done
    OPTIONAL_COMPONENT_DELETE_LIST=( $tps )
    # Convert pattern array to pattern list by common
    delim=""
    pattern_joined=""
    for item in "${PATTERNS_CR_SELECTED[@]}"; do
        if [[ "${DEPLOYMENT_TYPE}" == "starter" ]]; then
            pattern_joined="$pattern_joined$delim$item"
            delim=","
        elif [[ ${DEPLOYMENT_TYPE} == "production" ]]
        then
            case "$item" in
            "workflow-authoring"|"workflow-runtime"|"workflow-workstreams"|"document_processing_designer"|"document_processing_runtime")
                ;;
            *)
                pattern_joined="$pattern_joined$delim$item"
                delim=","
                ;;
            esac
        fi
    done

    if [[ "${DEPLOYMENT_TYPE}" == "starter" ]]; then
        if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
            echo
        elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "application" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
            echo
        elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams" && " ${PATTERNS_CR_SELECTED[@]} " =~ "application" && "${#PATTERNS_CR_SELECTED[@]}" -eq "2" ]]; then
            echo
        else
            pattern_joined="foundation$delim$pattern_joined"
        fi
    else
        if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service") ]]; then
            pattern_joined="foundation$delim$pattern_joined"
        else
            pattern_joined="$pattern_joined"
        fi

    fi
    # if [[ $INSTALL_BAW_IAWS == "No" ]];then
    #     pattern_joined="foundation$delim$pattern_joined"
    # fi

    # remove cmis for BAW when starter deployment
    local tmp_val="cmis"
    local tmp_idx
    for idx in "${!OPT_COMPONENTS_CR_SELECTED[@]}"; do
        if [[ "${OPT_COMPONENTS_CR_SELECTED[$idx]}" = "${tmp_val}" ]]; then
            tmp_idx=$idx;
        fi
    done

    if [[ "${DEPLOYMENT_TYPE}" == "starter" ]]; then
        if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
            OPT_COMPONENTS_CR_SELECTED=(${OPT_COMPONENTS_CR_SELECTED[@]:0:$tmp_idx} ${OPT_COMPONENTS_CR_SELECTED[@]:$(($tmp_idx + 1))})
        elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams" && " ${PATTERNS_CR_SELECTED[@]} " =~ "application" && "${#PATTERNS_CR_SELECTED[@]}" -eq "2" ]]; then
            OPT_COMPONENTS_CR_SELECTED=(${OPT_COMPONENTS_CR_SELECTED[@]:0:$tmp_idx} ${OPT_COMPONENTS_CR_SELECTED[@]:$(($tmp_idx + 1))})
        fi
    fi

   # Convert optional components array to list by common
    delim=""
    opt_components_joined=""
    for item in "${OPT_COMPONENTS_CR_SELECTED[@]}"; do
        opt_components_joined="$opt_components_joined$delim$item"
        delim=","
    done

    merge_pattern
    merge_optional_components
    set_foundation_components

    if [[ $INSTALLATION_TYPE == "existing" ]]; then
        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring") && !(" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-authoring") ]]; then
            # Delete Object Store for BAW Authoring
            object_array=("BAWDOCS" "BAWDOS" "BAWTOS")
        elif [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime") && !(" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-runtime") ]]; then
            # Delete Object Store for BAW Runtime
            object_array=("BAWINS1DOCS" "BAWINS1DOS" "BAWINS1TOS")
        elif [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${PATTERNS_CR_SELECTED[@]} " =~ "workstreams") ]]; then
            # Delete Object Store for workstreams
            object_array=("AWSINS1DOCS")
        else
            object_array=()
        fi
        if (( ${#object_array[@]} >= 1 ));then
            for object_name in "${object_array[@]}"
            do
                containsObjectStore "$object_name" "${CP4A_EXISTING_TMP}"
                if (( ${#os_index_array[@]} >= 1 ));then
                    # ((index_array_temp=${#os_index_array[@]}-1))
                    for ((j=0;j<${#os_index_array[@]};j++))
                    do
                        ((index_os=${os_index_array[$j]}-j))
                        ${YQ_CMD} d -i ${CP4A_EXISTING_TMP} spec.datasource_configuration.dc_os_datasources.[$index_os]
                    done
                fi
                containsInitObjectStore "$object_name" "${CP4A_EXISTING_TMP}"
                if (( ${#os_index_array[@]} >= 1 ));then
                    # ((index_array_temp=${#os_index_array[@]}-1))
                    for ((j=0;j<${#os_index_array[@]};j++))
                    do
                        ((index_os=${os_index_array[$j]}-j))
                        ${YQ_CMD} d -i ${CP4A_EXISTING_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$index_os]
                    done
                fi
            done
            object_array=()
        fi
        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") && !(" ${PATTERNS_CR_SELECTED[@]} " =~ "content") ]]; then
            # Delete Object Store for FNCM
            object_array=("FNOS1DS" "FNOS2DS" "FNOS3DS" "FNOS4DS" "FNOS5DS" "FNOS6DS" "FNOS7DS" "FNOS8DS" "FNOS9DS" "FNOS10DS")
        else
            object_array=()
        fi
        if (( ${#object_array[@]} >= 1 ));then
            for object_name in "${object_array[@]}"
            do
                containsObjectStore "$object_name" "${CP4A_EXISTING_TMP}"
                if (( ${#os_index_array[@]} >= 1 ));then
                    # ((index_array_temp=${#os_index_array[@]}-1))
                    for ((j=0;j<${#os_index_array[@]};j++))
                    do
                        ((index_os=${os_index_array[$j]}-j))
                        ${YQ_CMD} d -i ${CP4A_EXISTING_TMP} spec.datasource_configuration.dc_os_datasources.[$index_os]
                    done
                fi
            done
            object_array=()
        fi

        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "content") ]]; then
            total_os_new=0
            total_os_exist=0
            os_index_array_new=()
            os_index_array_exist=()

            getTotalFNCMObjectStore "${CP4A_PATTERN_FILE_TMP}"
            total_os_new=$total_os
            os_index_array_new=( "${os_index_array[@]}" )
            # echo "total_os_new: ${total_os_new}"
            # echo "os_index_array_new: ${os_index_array_new[*]}"
            # echo "length of os_index_array_new:${#os_index_array_new[@]}"

            getTotalFNCMObjectStore "${CP4A_EXISTING_TMP}"
            total_os_exist=$total_os
            os_index_array_exist=( "${os_index_array[@]}" )
            # echo "total_os_exist: ${total_os_exist}"
            # echo "os_index_array_exist: ${os_index_array_exist[*]}"
            # echo "length of os_index_array_exist:${#os_index_array_exist[@]}"
        fi

        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && !(" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow") ]]; then
            # Delete BAW Instance
            baw_name_array=("bawins1")
        elif [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${PATTERNS_CR_SELECTED[@]} " =~ "workstreams") ]]; then
            baw_name_array=("awsins1")
        else
            baw_name_array=()
        fi
        if (( ${#baw_name_array[@]} >= 1 ));then
            for object_name in "${baw_name_array[@]}"
            do
                containsBAWInstance "$object_name" "${CP4A_EXISTING_TMP}"
                if (( ${#baw_index_array[@]} >= 1 ));then
                    # ((index_array_temp=${#baw_index_array[@]}-1))
                    for ((j=0;j<${#baw_index_array[@]};j++))
                    do
                        ((index_os=${baw_index_array[$j]}-j))
                        ${YQ_CMD} d -i ${CP4A_EXISTING_TMP} spec.baw_configuration
                    done
                fi
            done
            baw_name_array=()
        fi

        if grep "ums_configuration:" $CP4A_EXISTING_TMP > /dev/null
        then
            ${YQ_CMD} w -i ${CP4A_EXISTING_TMP} spec.ums_configuration.fix "dummy"
        fi
        # read -rsn1 -p"Before:Press any key to exit";echo
        ${YQ_CMD} m -i -a -M --overwrite --autocreate=false ${CP4A_PATTERN_FILE_TMP} ${CP4A_EXISTING_TMP}
        # read -rsn1 -p"After:Press any key to exit";echo
        ${YQ_CMD} d -i ${CP4A_EXISTING_TMP} spec.ums_configuration.fix
        ${SED_COMMAND} "s|ums_configuration: {}|ums_configuration:|g" ${CP4A_EXISTING_TMP}
        ${SED_COMMAND} "s|ums_configuration: {}|ums_configuration:|g" ${CP4A_PATTERN_FILE_TMP}
    fi

    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}
    if [[ " ${OPT_COMPONENTS_CR_SELECTED[@]} " =~ "ae_data_persistence" ]]; then
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_content_initialization "true"
    elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow" || " ${PATTERNS_CR_SELECTED[@]} " =~ "workstreams" ]]; then
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_content_initialization "true"
    fi

    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing" ]]; then
        if [[ "$CPE_FULL_STORAGE" == "Yes" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_cpe_limited_storage "false"
        elif [[ "$CPE_FULL_STORAGE" == "No" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_cpe_limited_storage "true"
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_cpe_limited_storage "false"
        fi
    fi

    # If only select FNCM pattern, only generate "kind: Content" cr
    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
        for item in "${OPT_COMPONENTS_CR_SELECTED[@]}"; do
            while true; do
                case $item in
                    "bai")
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.content_optional_components.bai "true"
                        break
                        ;;
                    "cmis")
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.content_optional_components.cmis "true"
                        break
                        ;;
                    "css")
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.content_optional_components.css "true"
                        break
                        ;;
                    "es")
                        # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.content_optional_components.es "true"
                        break
                        ;;
                    "iccsap")
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.content_optional_components.iccsap "true"
                        break
                        ;;
                    "ier")
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.content_optional_components.ier "true"
                        break
                        ;;
                    "tm")
                        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.content_optional_components.tm "true"
                        break
                        ;;
                esac
            done
        done
    else
        # Set sc_deployment_patterns
        ${SED_COMMAND} "s|sc_deployment_patterns:.*|sc_deployment_patterns: \"$pattern_joined\"|g" ${CP4A_PATTERN_FILE_TMP}

        # Set sc_optional_components='' when none optional component selected
        if [ "${#optional_component_cr_arr[@]}" -eq "0" ]; then
            ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"\"|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"$opt_components_joined\"|g" ${CP4A_PATTERN_FILE_TMP}
        fi
    fi
    # Set sc_deployment_platform
    ${SED_COMMAND} "s|sc_deployment_platform:.*|sc_deployment_platform: \"$PLATFORM_SELECTED\"|g" ${CP4A_PATTERN_FILE_TMP}

    # Set sc_deployment_type
    case "${DEPLOYMENT_TYPE}" in
    starter*|Starter*)
    ${SED_COMMAND} "s|sc_deployment_type:.*|sc_deployment_type: \"Starter\"|g" ${CP4A_PATTERN_FILE_TMP}
    ;;
    production*|Production*)
    ${SED_COMMAND} "s|sc_deployment_type:.*|sc_deployment_type: \"Production\"|g" ${CP4A_PATTERN_FILE_TMP}
    ;;
    esac

    # Set sc_deployment_hostname_suffix

    if [ -z "$existing_infra_name" ]; then
        echo ""
    else
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_hostname_suffix "$existing_infra_name"
        if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]];
        then
            ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}.${INFRA_NAME}\"|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}\"|g" ${CP4A_PATTERN_FILE_TMP}
        fi
    fi


    # Set lc_selected_ldap_type

    if [[ $DEPLOYMENT_TYPE == "production" ]];then
        if [[ $LDAP_TYPE == "AD" ]];then
            # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_selected_ldap_type "\"Microsoft Active Directory\""
            ${SED_COMMAND} "s|lc_selected_ldap_type:.*|lc_selected_ldap_type: \"Microsoft Active Directory\"|g" ${CP4A_PATTERN_FILE_TMP}

        elif [[ $LDAP_TYPE == "TDS" ]]
        then
            # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_selected_ldap_type "IBM Security Directory Server"
            ${SED_COMMAND} "s|lc_selected_ldap_type:.*|lc_selected_ldap_type: \"IBM Security Directory Server\"|g" ${CP4A_PATTERN_FILE_TMP}
        fi
    fi

    # Set fips_enable
    if  [[ ("$DEPLOYMENT_TYPE" == "starter" || ("$DEPLOYMENT_TYPE" == "production" && $DEPLOYMENT_WITH_PROPERTY == "No")) && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
        if [[ $FIPS_ENABLED == "true" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.enable_fips "true"
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.enable_fips "false"
        fi
    elif [[ $DEPLOYMENT_WITH_PROPERTY == "Yes" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
         fips_flag="$(prop_user_profile_property_file CP4BA.ENABLE_FIPS)"
        fips_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$fips_flag")
        fips_flag=$(echo $fips_flag | tr '[:upper:]' '[:lower:]')
        if [[ ! -z $fips_flag ]]; then
            if [[ $fips_flag == "true" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.enable_fips "true"
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.enable_fips "false"
            fi
        fi
    fi

    # Set sc_restricted_internet_access
    if  [[ ("$DEPLOYMENT_TYPE" == "starter" || ("$DEPLOYMENT_TYPE" == "production" && $DEPLOYMENT_WITH_PROPERTY == "No")) && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
        if [[ $RESTRICTED_INTERNET_ACCESS == "true" ]]; then
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access "true"
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access "false"
        fi
    elif [[ $DEPLOYMENT_WITH_PROPERTY == "Yes" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
        restricted_flag="$(prop_user_profile_property_file CP4BA.ENABLE_RESTRICTED_INTERNET_ACCESS)"
        restricted_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$restricted_flag")
        restricted_flag=$(echo $restricted_flag | tr '[:upper:]' '[:lower:]')
        if [[ ! -z $restricted_flag ]]; then
            if [[ $restricted_flag == "true" ]]; then
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access "true"
            else
                ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access "false"
            fi
        else
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access "true"
        fi
    fi

    # Set sc_dynamic_storage_classname
    if [[ "$PLATFORM_SELECTED" == "ROKS" ]]; then
        ${SED_COMMAND} "s|sc_dynamic_storage_classname:.*|sc_dynamic_storage_classname: \"${FAST_STORAGE_CLASS_NAME}\"|g" ${CP4A_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s|sc_dynamic_storage_classname:.*|sc_dynamic_storage_classname: \"${STORAGE_CLASS_NAME}\"|g" ${CP4A_PATTERN_FILE_TMP}
    fi
    ${SED_COMMAND} "s|sc_slow_file_storage_classname:.*|sc_slow_file_storage_classname: \"${SLOW_STORAGE_CLASS_NAME}\"|g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|sc_medium_file_storage_classname:.*|sc_medium_file_storage_classname: \"${MEDIUM_STORAGE_CLASS_NAME}\"|g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|sc_fast_file_storage_classname:.*|sc_fast_file_storage_classname: \"${FAST_STORAGE_CLASS_NAME}\"|g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|sc_block_storage_classname:.*|sc_block_storage_classname: \"${BLOCK_STORAGE_CLASS_NAME}\"|g" ${CP4A_PATTERN_FILE_TMP}
    # Set image_pull_secrets
    # ${SED_COMMAND} "s|image-pull-secret|$DOCKER_RES_SECRET_NAME|g" ${CP4A_PATTERN_FILE_TMP}
    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.image_pull_secrets
    ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.image_pull_secrets.[0] "$DOCKER_RES_SECRET_NAME"

    # set sc_drivers_url
    if [ -z "$CP4BA_JDBC_URL" ]; then
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_drivers_url ""
    else
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_drivers_url "$CP4BA_JDBC_URL"
    fi

    # support profile size for production
    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_profile_size "\"$PROFILE_TYPE\""
    fi

    # set the sc_iam.default_admin_username
    if [[ ("$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS") && "$DEPLOYMENT_TYPE" == "production" && "$USE_DEFAULT_IAM_ADMIN" == "No" ]]; then
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_iam.default_admin_username "\"$NON_DEFAULT_IAM_ADMIN\""
    fi

    # set sc_image_repository
    if [ "$use_entitlement" = "yes" ] ; then
        ${SED_COMMAND} "s|sc_image_repository:.*|sc_image_repository: ${DOCKER_REG_SERVER}|g" ${CP4A_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s|sc_image_repository:.*|sc_image_repository: ${CONVERT_LOCAL_REGISTRY_SERVER}|g" ${CP4A_PATTERN_FILE_TMP}
    fi

    # Replace image URL
    old_fmcn="$REGISTRY_IN_FILE\/cp\/cp4a\/fncm"
    old_ban="$REGISTRY_IN_FILE\/cp\/cp4a\/ban"
    old_ums="$REGISTRY_IN_FILE\/cp\/cp4a\/ums"
    old_bas="$REGISTRY_IN_FILE\/cp\/cp4a\/bas"
    old_aae="$REGISTRY_IN_FILE\/cp\/cp4a\/aae"
    old_baca="$REGISTRY_IN_FILE\/cp\/cp4a\/baca"
    old_odm="$REGISTRY_IN_FILE\/cp\/cp4a\/odm"
    old_baw="$REGISTRY_IN_FILE\/cp\/cp4a\/baw"
    old_iaws="$REGISTRY_IN_FILE\/cp\/cp4a\/iaws"
    old_ads="$REGISTRY_IN_FILE\/cp\/cp4a\/ads"
    old_bai="$REGISTRY_IN_FILE\/cp\/cp4a"
    old_workflow="$REGISTRY_IN_FILE\/cp\/cp4a\/workflow"
    old_demo="$REGISTRY_IN_FILE\/cp\/cp4a\/demo"
    old_adp="$REGISTRY_IN_FILE\/cp\/cp4a\/iadp"
    old_ier="$REGISTRY_IN_FILE\/cp\/cp4a\/ier"
    old_iccsap="$REGISTRY_IN_FILE\/cp\/cp4a\/iccsap"

    if [ "$use_entitlement" = "yes" ] ; then
        ${SED_COMMAND} "s/$REGISTRY_IN_FILE/$DOCKER_REG_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s/$old_db2/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2_alpine/$CONVERT_LOCAL_REGISTRY_SERVER\/alpine/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ldap/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2_etcd/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_busybox/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_demo/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_fmcn/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ban/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ums/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_bas/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_aae/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_baca/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_odm/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_baw/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_iaws/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ads/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_workflow/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_adp/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ier/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_iccsap/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/imageCredentials:/{n;s/registry:.*/registry: "${CONVERT_LOCAL_REGISTRY_SERVER}"/;}" ${CP4A_PATTERN_FILE_TMP}

    fi

    object_array=("DEVOS1DS" "DEVOS1" "AEOS" "BAWINS1DOCS" "BAWINS1DOS" "BAWINS1TOS" "BAWDOCS" "BAWDOS" "BAWTOS" "AWSINS1DOCS")
    for object_name in "${object_array[@]}"
    do
        containsObjectStore "$object_name" "${CP4A_PATTERN_FILE_TMP}"
        if (( ${#os_index_array[@]} > 1 ));then
            ((index_array_temp=${#os_index_array[@]}-1))
            # read -rsn1 -p"index_array_temp: $index_array_temp";echo
            for ((j=0;j<${index_array_temp};j++))
            do
                ((index_os=${os_index_array[$j]}-j))
                # read -rsn1 -p"index_os: $index_os";echo
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$index_os]
            done
        fi
        containsInitObjectStore "$object_name" "${CP4A_PATTERN_FILE_TMP}"
        if (( ${#os_index_array[@]} > 1 ));then
            ((index_array_temp=${#os_index_array[@]}-1))
            for ((j=0;j<${index_array_temp};j++))
            do
                ((index_os=${os_index_array[$j]}-j))
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$index_os]
            done
        fi
    done

    if (( total_os_new >= total_os_exist ));then
        object_array=()
        for ((j=0;j<${#os_index_array_exist[@]};j++))
        do
            ((num_os=j+1))
            object_array=( "${object_array[@]}" "FNOS${num_os}DS" )
        done

        for object_name in "${object_array[@]}"
        do
            containsObjectStore "$object_name" "${CP4A_PATTERN_FILE_TMP}"
            if (( ${#os_index_array[@]} > 1 ));then
                ((index_array_temp=${#os_index_array[@]}-1))
                for ((j=0;j<${index_array_temp};j++))
                do
                    ((index_os=${os_index_array[$j]}-j))
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$index_os]
                done
            fi
        done
    elif (( total_os_new < total_os_exist ))
    then
        object_array=()
        for ((j=0;j<${#os_index_array_new[@]};j++))
        do
            ((num_os=j+1))
            object_array=( "${object_array[@]}" "FNOS${num_os}DS" )
        done

        for object_name in "${object_array[@]}"
        do
            containsObjectStore "$object_name" "${CP4A_PATTERN_FILE_TMP}"
            if (( ${#os_index_array[@]} > 1 ));then
                ((index_array_temp=${#os_index_array[@]}-1))
                for ((j=0;j<${index_array_temp};j++))
                do
                    ((index_os=${os_index_array[$j]}-j))
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$index_os]
                done
            fi
        done

        object_array_new=()
        object_array_exist=()

        for ((j=0;j<${#os_index_array_new[@]};j++))
        do
            ((num_os=j+1))
            object_array_new=( "${object_array_new[@]}" "FNOS${num_os}DS" )
        done

        for ((j=0;j<${#os_index_array_exist[@]};j++))
        do
            ((num_os=j+1))
            object_array_exist=( "${object_array_exist[@]}" "FNOS${num_os}DS" )
        done
        object_array=($(echo "${object_array_new[@]}" "${object_array_exist[@]}" | tr ' ' '\n' | sort | uniq -u))

        for object_name in "${object_array[@]}"
        do
            containsObjectStore "$object_name" "${CP4A_PATTERN_FILE_TMP}"
            if (( ${#os_index_array[@]} > 0 ));then
                ((index_array_temp=${#os_index_array[@]}))
                for ((j=0;j<${index_array_temp};j++))
                do
                    ((index_os=${os_index_array[$j]}-j))
                    ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$index_os]
                done
            fi
        done
    fi

    containsInitLDAPGroups "${CP4A_PATTERN_FILE_TMP}"
    if (( ${#ldap_groups_index_array[@]} > 1 ));then
        ((index_array_temp=${#ldap_groups_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${ldap_groups_index_array[$j]}-j))
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_ldap_creation.ic_ldap_admins_groups_name.[$index_os]
        done

    fi

    containsInitLDAPUsers "${CP4A_PATTERN_FILE_TMP}"
     if (( ${#ldap_users_index_array[@]} > 1 ));then
        ((index_array_temp=${#ldap_users_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${ldap_users_index_array[$j]}-j))
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_ldap_creation.ic_ldap_admin_user_name.[$index_os]
        done

    fi

    baw_name_array=("bawins1" "awsins1")
    for object_name in "${baw_name_array[@]}"
    do
        containsBAWInstance "$object_name" "${CP4A_PATTERN_FILE_TMP}"
        if (( ${#baw_index_array[@]} > 1 ));then
            ((index_array_temp=${#baw_index_array[@]}-1))
            for ((j=0;j<${index_array_temp};j++))
            do
                ((index_os=${baw_index_array[$j]}-j))
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration.[$index_os]
            done
        fi
    done

    containsAEInstance "${CP4A_PATTERN_FILE_TMP}"
     if (( ${#ae_index_array[@]} > 1 ));then
        ((index_array_temp=${#ae_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${ae_index_array[$j]}-j))
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration.[$index_os]
        done
    fi

    containsICNRepos "${CP4A_PATTERN_FILE_TMP}"
     if (( ${#icn_repo_index_array[@]} > 1 ));then
        ((index_array_temp=${#icn_repo_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${icn_repo_index_array[$j]}-j))
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_icn_init_info.icn_repos.[$index_os]
        done
    fi

    containsICNDesktop "${CP4A_PATTERN_FILE_TMP}"
     if (( ${#icn_desktop_index_array[@]} > 1 ));then
        ((index_array_temp=${#icn_desktop_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${icn_desktop_index_array[$j]}-j))
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_icn_init_info.icn_desktop.[$index_os]
        done
    fi

    containsTenantDB "${CP4A_PATTERN_FILE_TMP}"
     if (( ${#tenant_db_index_array[@]} > 1 ));then
        ((index_array_temp=${#tenant_db_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${tenant_db_index_array[$j]}-j))
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases.[$index_os]
        done
    fi

    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}
    if [[ "$SCRIPT_MODE" == "baw-dev" || "$SCRIPT_MODE" == "dev" || "$SCRIPT_MODE" == "review" ]]; then
        ${SED_COMMAND} "s|tag: \"${IMAGE_TAG_FINAL}\"|tag: \"${IMAGE_TAG_DEV}\"|g" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s|tag: ${IMAGE_TAG_FINAL}|tag: \"${IMAGE_TAG_DEV}\"|g" ${CP4A_PATTERN_FILE_TMP}
    fi

    if [[ "$IMAGE_TAG_DEV" != "$IMAGE_TAG_FINAL" && ("$SCRIPT_MODE" == "baw-dev" || "$SCRIPT_MODE" == "dev" || "$SCRIPT_MODE" == "review") ]]; then
        ${SED_COMMAND} "/cp\/cp4a\/fncm\/cpe/{n;s/tag:.*/tag: \"${IMAGE_TAG_DEV}\"/;}" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/cp\/cp4a\/fncm\/css/{n;s/tag:.*/tag: \"${IMAGE_TAG_DEV}\"/;}" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/cp\/cp4a\/fncm\/graphql/{n;s/tag:.*/tag: \"${IMAGE_TAG_DEV}\"/;}" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/cp\/cp4a\/fncm\/cmis/{n;s/tag:.*/tag: \"${IMAGE_TAG_DEV}\"/;}" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/cp\/cp4a\/fncm\/extshare/{n;s/tag:.*/tag: \"${IMAGE_TAG_DEV}\"/;}" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/cp\/cp4a\/fncm\/taskmgr/{n;s/tag:.*/tag: \"${IMAGE_TAG_DEV}\"/;}" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/cp\/cp4a\/ier\/ier/{n;s/tag:.*/tag: \"${IMAGE_TAG_DEV}\"/;}" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/cp\/cp4a\/iccsap\/iccsap/{n;s/tag:.*/tag: \"${IMAGE_TAG_DEV}\"/;}" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/cp\/cp4a\/ban\/navigator/{n;s/tag:.*/tag: \"${IMAGE_TAG_DEV}\"/;}" ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/cp\/cp4a\/ban\/navigator-sso/{n;s/tag:.*/tag: \"${IMAGE_TAG_DEV}\"/;}" ${CP4A_PATTERN_FILE_TMP}
    fi

    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing" ]]; then
        ${SED_COMMAND} "s/.*# ecm_configuration:.*/  # ecm_configuration:/g" ${CP4A_PATTERN_FILE_TMP}
    fi

    if [[ $PLATFORM_SELECTED == "other" ]]; then
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.storage_configuration.sc_block_storage_classname
    fi

    # if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
    #     if [[ (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams" || " ${PATTERNS_CR_SELECTED[@]} " =~ "decisions_ads") && !(" ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing") && !(" ${PATTERNS_CR_SELECTED[@]} " =~ "application") ]]; then
    #         ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server
    #     fi
    # fi

    # Remove dc_os_datasources for `FNOS1DS` if content_os_number = 0
    if [[ $DEPLOYMENT_TYPE == "production" && $content_os_number -eq 0 ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'FNOS1DS'|cut -d':' -f1)
        # read -rsn1 -p"Press any key to continue";echo "$OS_DATASOURCE_NUMBER"
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
        OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER]
        fi
    fi

    # Apply value in property file into final cr
    if [[ $DEPLOYMENT_TYPE == "production" && $DEPLOYMENT_WITH_PROPERTY == "Yes" ]]; then
        sync_property_into_final_cr
    fi

    # Format value
    ${SED_COMMAND} "s|'\"|\"|g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|\"'|\"|g" ${CP4A_PATTERN_FILE_TMP}
    # remove ldap_configuration and datasource_configuration when only select WfPS authoring
    if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "No" ]]; then
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration
    fi

    if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $EXTERNAL_DB_WFPS_AUTHORING == "No" ]]; then
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.admin_secret_name
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.database
    fi

    if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" ]]; then
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_fncm_license
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_baw_license
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_content_initialization
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_cpe_limited_storage
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration
    fi

    # remove application_engine_configuration/playback_server when only select BAW authoring/only WfPS authoring/both BAW authoring and WfPS authoring
    if [[ (! (" ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "application" || " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workstreams")) && ("${pattern_cr_arr[@]}" =~ "workflow-authoring" || "${pattern_cr_arr[@]}" =~ "workflow-process-service") ]]; then
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration
    fi

    if [[ (! (" ${pattern_cr_arr[@]}" =~ "document_processing_designer" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer")) && ("${pattern_cr_arr[@]}" =~ "workflow-authoring" || "${pattern_cr_arr[@]}" =~ "workflow-process-service") ]]; then
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server
    fi
    # remove gcd/aeos/init without ae data persistent when only select BAA pattern

    if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "application" && (! "${optional_component_cr_arr[@]}" =~ "ae_data_persistence") ]]; then
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_gcd_datasource
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration
    fi

    if [[ "${#pattern_cr_arr[@]}" -gt "1" && (! "${optional_component_cr_arr[@]}" =~ "ae_data_persistence") ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER]
        fi

        OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER]
        fi
    fi

    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
        # 5b/6: Remove pfs_configuration/application_engine_configuration ae_data_persistence/AEOS
        if [[ " ${pattern_cr_arr[@]} " =~ "application" || " ${pattern_cr_arr[@]} " =~ "document_processing" ]]; then
            echo # keep application_engine_configuration for BAA/ADP
        else
            if [[ (" ${pattern_cr_arr[@]} " =~ "workstreams") || (" ${pattern_cr_arr[@]} " =~ "workflow-runtime") ]]; then
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.pfs_configuration
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.application_engine_configuration
                ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.elasticsearch_configuration
            fi
        fi
    # 6: remove Navigator/GraphQL
        if [[ " ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "1" ]]; then
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration.graphql
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ecm_configuration.navigator_configuration
            ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_icn_datasource
        fi
    fi

    # For ARO/ROSA platform type
    if [[ $OCP_PLATFORM == "ARO" ]]; then
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_ocp_platform "ARO"
    elif [[ $OCP_PLATFORM == "ROSA" ]]; then
        ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_ocp_platform "ROSA"
    fi

    # Remove sc_deployment_baw_license
    if [[ ! (" ${pattern_cr_arr[@]}" =~ "workflow-runtime") ]]; then
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_baw_license
    fi

    # Remove sc_deployment_fncm_license
    if [[ ! (" ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence") ]]; then
        ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_baw_license
    fi

    if [[ -z $TARGET_PROJECT_NAME ]]; then
        while [[ $TARGET_PROJECT_NAME == "" ]];
        do
            if [ -z "$CP4BA_AUTO_CS_SERVICE_NAMESPACE" ]; then
                echo
                echo -e "\x1B[1mWhere (namespace) do you want to deploy CP4BA operands (i.e., runtime pods)? \x1B[0m"
                read -p "Enter the name for a new project or an existing project (namespace): " TARGET_PROJECT_NAME
            else
                if [[ "$CP4BA_AUTO_CS_SERVICE_NAMESPACE" == openshift* ]]; then
                    echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
                    exit 1
                elif [[ "$CP4BA_AUTO_CS_SERVICE_NAMESPACE" == kube* ]]; then
                    echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
                    exit 1
                elif [[ "$TARGET_PROJECT_NAME" == "$project_name_operator" ]]; then
                    fail "\x1B[1;31mThe project name for CPfs services (IM Services) should NOT same as the project name \"$project_name_operator\" for CP4BA operators. \x1B[0m"
                    exit 1
                fi
                TARGET_PROJECT_NAME=$CP4BA_AUTO_CS_SERVICE_NAMESPACE
            fi

            if [ -z "$TARGET_PROJECT_NAME" ]; then
                echo -e "\x1B[1;31mEnter a valid project name, project name can not be blank\x1B[0m"
            elif [[ "$TARGET_PROJECT_NAME" == openshift* ]]; then
                echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
                TARGET_PROJECT_NAME=""
            elif [[ "$TARGET_PROJECT_NAME" == kube* ]]; then
                echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
                TARGET_PROJECT_NAME=""
            fi
        done
    fi
    # Apply separation of operands into final CR
    if ${CLI_CMD} get configMap ibm-cp4ba-common-config -n $TARGET_PROJECT_NAME >/dev/null 2>&1; then
        cp4ba_services_namespace=$(${CLI_CMD} get configMap ibm-cp4ba-common-config -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found -o jsonpath='{.data.services_namespace}')
        cp4ba_operators_namespace=$(${CLI_CMD} get configMap ibm-cp4ba-common-config -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found -o jsonpath='{.data.operators_namespace}')
        if [[ (! -z $cp4ba_services_namespace) && (! -z $cp4ba_operators_namespace) ]]; then
            if [[ $cp4ba_services_namespace != $cp4ba_operators_namespace ]]; then
                info "This CP4BA deployment is separation of operators and operands"
            fi
            info "the script will set \"$cp4ba_services_namespace\" as namespace in the final custom resource."
            ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} metadata.namespace "$cp4ba_services_namespace"
        else
            warning "Not found \"services_namespace\" in configMap ibm-cp4ba-common-config in the project \"$TARGET_PROJECT_NAME\""
            info "You need to apply custom resource in the project for CP4BA operand but not project for CP4BA operators"
        fi
    fi

    # rename final CR to ibm_content_cr_final.yaml
    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
        CP4A_PATTERN_FILE_BAK=$FNCM_SEPARATE_PATTERN_FILE_BAK
    fi
    ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}
    if [[ "$DEPLOYMENT_TYPE" == "starter" && "$INSTALLATION_TYPE" == "new" && !("$SCRIPT_MODE" == "review" || "$SCRIPT_MODE" == "OLM") ]];then
        ${CLI_CMD} delete -f ${CP4A_PATTERN_FILE_TMP} >/dev/null 2>&1
        sleep 5
        printf "\n"
        echo -e "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"

        if [[ "${ALL_NAMESPACE}" == "Yes" ]]; then
            APPLY_CONTENT_CMD="${CLI_CMD} apply -f ${CP4A_PATTERN_FILE_BAK} -n openshift-operators"
        else
            APPLY_CONTENT_CMD="${CLI_CMD} apply -f ${CP4A_PATTERN_FILE_BAK} -n $TARGET_PROJECT_NAME"
        fi
        if $APPLY_CONTENT_CMD ; then
            echo -e "\x1B[1mDone\x1B[0m"
        else
            echo -e "\x1B[1;31mFailed\x1B[0m"
        fi
    elif  [[ "$DEPLOYMENT_TYPE" == "starter" && "$INSTALLATION_TYPE" == "existing" && !("$SCRIPT_MODE" == "review" || "$SCRIPT_MODE" == "OLM") ]]
    then
        echo -e "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"

        if [[ "${ALL_NAMESPACE}" == "Yes" ]]; then
            APPLY_CONTENT_CMD="${CLI_CMD} apply -f ${CP4A_PATTERN_FILE_BAK} -n openshift-operators"
        else
            APPLY_CONTENT_CMD="${CLI_CMD} apply -f ${CP4A_PATTERN_FILE_BAK} -n $TARGET_PROJECT_NAME"
        fi

        if $APPLY_CONTENT_CMD ; then
            echo -e "\x1B[1mDone\x1B[0m"
        else
            echo -e "\x1B[1;31mFailed\x1B[0m"
        fi
    elif  [[ "$DEPLOYMENT_TYPE" == "production" && "$INSTALLATION_TYPE" == "new" && "$DEPLOYMENT_WITH_PROPERTY" == "Yes" ]]
    then
        ## CP4BA_APPLY_CR is going to be a environment variable to apply the CR for silent install.
        if [[ "$CP4BA_APPLY_CR" == "Yes" || "$CP4BA_APPLY_CR" == "YES" || "$CP4BA_APPLY_CR" == "yes" || "$CP4BA_APPLY_CR" == "True"  || "$CP4BA_APPLY_CR" == "TRUE"  || "$CP4BA_APPLY_CR" == "true" ]]; then
           echo -e "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"
           echo -e "${CP4A_PATTERN_FILE_BAK}"
           APPLY_CUSTOM_RESOURCE_CMD="${CLI_CMD} apply -f ${CP4A_PATTERN_FILE_BAK} -n $TARGET_PROJECT_NAME"
           if $APPLY_CUSTOM_RESOURCE_CMD ; then
               echo -e "\x1B[1mDone\x1B[0m"
           else
               echo -e "\x1B[1;31mFailed\x1B[0m"
           fi
        else
            echo -e "${YELLOW_TEXT}[NOTE]${RESET_TEXT} The custom resource (CR) file has been generated, but is not yet deployed (applied).\n"

            echo -e "${YELLOW_TEXT}[ATTENTION]${RESET_TEXT} Prior to deploying (applying) the custom resource (CR), please follow the steps in the Knowledge Center topic ${BLUE_TEXT}\"Checking and completing your custom resource\"${RESET_TEXT} to configure the custom resource file for the capabilities that you have selected:${BLUE_TEXT} https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=deployment-checking-completing-your-custom-resource ${RESET_TEXT}  \n"

            echo -e "${YELLOW_TEXT}[ATTENTION]${RESET_TEXT} After you have finished configuring the custom resource (CR) file, please follow the steps in the Knowledge Center to deploy (apply) your custom resource:${BLUE_TEXT} https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=cpd-option-1b-deploying-custom-resource-you-created-deployment-script ${RESET_TEXT} \n"
        fi
    fi

    echo -e "\x1B[1mThe custom resource file located at: \"${CP4A_PATTERN_FILE_BAK}\"\x1B[0m"
    if [[ "$DEPLOYMENT_TYPE" == "production" && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams" || " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-runtime" || " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-authoring") ]]; then
        printf "\n"
        echo -e "\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1mIf the cluster is running a Linux on Z (s390x)/Power architecture, remove the \x1B[0m\x1B[1;31mbaml_configuration\x1B[0m \x1B[1msection from \"${CP4A_PATTERN_FILE_BAK}\" before you apply the custom resource. Business Automation Machine Learning Server (BAML) is not supported on this architecture.\n\x1B[0m"
    fi
    printf "\n"
    echo -e "\x1B[1mTo monitor the deployment status, follow the Operator logs.\x1B[0m"
    echo -e "\x1B[1mFor details, refer to the troubleshooting section in Knowledge Center here: \x1B[0m"
    echo -e "\x1B[1mhttps://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-troubleshooting\x1B[0m"
}
# End - Modify FOUNDATION pattern yaml according pattent/components selected

function show_summary_pattern_selected(){
    printf "\n"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    echo -e "\x1B[1m            Summary of CP4BA capabilities              \x1B[0m"
    echo -e "\x1B[1m*******************************************************\x1B[0m"

    echo -e "\x1B[1;31m1. Cloud Pak capability to deploy: \x1B[0m"
    if [ "${#pattern_arr[@]}" -eq "0" ]; then
        printf '   * %s\n' "None"
    else
        for each_pattern in "${pattern_arr[@]}"
        do
            if [[ "$each_pattern" =~ .*"Workflow Authoring".* || "$each_pattern" =~ .*"Workflow Runtime".* || "$each_pattern" =~ .*"Development Environment".* || "$each_pattern" =~ .*"Runtime Environment".* ]];then
               printf '     %s\n' "${each_pattern}"
            else
                printf '   * %s\n' "${each_pattern}"
            fi
        done
    fi

    echo -e "\x1B[1;31m2. Optional components to deploy: \x1B[0m"
    if [ "${#optional_component_arr[@]}" -eq "0" ]; then
        printf '   * %s\n' "None"
    else
        # printf '   * %s\n' "${OPT_COMPONENTS_SELECTED[@]}"
        for each_opt_component in "${optional_component_arr[@]}"
        do
            if [[ ${each_opt_component} == "ExternalShare" ]]; then
                printf '   * %s\n' "External Share"
            elif [[ ${each_opt_component} == "TaskManager" ]]
            then
                printf '   * %s\n' "Task Manager"
            elif [[ ${each_opt_component} == "ContentSearchServices" ]]
            then
                printf '   * %s\n' "Content Search Services"
            elif [[ ${each_opt_component} == "DecisionCenter" ]]
            then
                printf '   * %s\n' "Decision Center"
            elif [[ ${each_opt_component} == "RuleExecutionServer" ]]
            then
                printf '   * %s\n' "Rule Execution Server"
            elif [[ ${each_opt_component} == "DecisionRunner" ]]
            then
                printf '   * %s\n' "Decision Runner"
            elif [[ ${each_opt_component} == "DecisionDesigner" ]]
            then
                printf '   * %s\n' "Decision Designer"
            elif [[ ${each_opt_component} == "DecisionRuntime" ]]
            then
                printf '   * %s\n' "Decision Runtime"
            elif [[ "${each_opt_component}" == "ContentManagementInteroperabilityServices" ]]
            then
                printf '   * %s\n' "Content Management Interoperability Services"
            elif [[ "${each_opt_component}" == "UserManagementService" ]]
            then
                printf '   * %s\n' "User Management Service"
            elif [[ "${each_opt_component}" == "BusinessAutomationInsights" ]]
            then
                printf '   * %s\n' "Business Automation Insights"
            elif [[ "${each_opt_component}" == "ProcessFederationServer" ]]
            then
                printf '   * %s\n' "Process Federation Server"
            elif [[ "${each_opt_component}" == "DataCollectorandDataIndexer" ]]
            then
                printf '   * %s\n' "Data Collector and Data Indexer"
            elif [[ "${each_opt_component}" == "ExposedKafkaServices" ]]
            then
                printf '   * %s\n' "Exposed Kafka Services"
            elif [[ "${each_opt_component}" == "ExposedOpenSearch" ]]
            then
                printf '   * %s\n' "Exposed OpenSearch"
            elif [[ "${each_opt_component}" == "BusinessAutomationMachineLearning" ]]
            then
                printf '   * %s\n' "Business Automation Machine Learning"
            elif [[ "${each_opt_component}" == "ApplicationDesigner" ]]
            then
                printf '   * %s\n' "Application Designer"
            elif [[ "${each_opt_component}" == "BusinessAutomationApplicationDataPersistence" ]]
            then
                printf '   * %s\n' "Business Automation Application Data Persistence"
            elif [[ "${each_opt_component}" == "IBMEnterpriseRecords" ]]
            then
                printf '   * %s\n' "IBM Enterprise Records"
            elif [[ "${each_opt_component}" == "IBMContentCollectorforSAP" ]]
            then
                printf '   * %s\n' "IBM Content Collector for SAP"
            elif [[ "${each_opt_component}" == "IBMContentNavigator" ]]
            then
                printf '   * %s\n' "IBM Content Navigator"
            elif [[ "${each_opt_component}" == "ContentIntegration" ]]
            then
                printf '   * %s\n' "Content Integration"
            else
                printf '   * %s\n' "${each_opt_component}"
            fi
        done
    fi
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    info "Above CP4BA capabilities is already selected in the cp4a-prerequisites.sh script"
    read -rsn1 -p"Press any key to continue";echo
}

function show_summary(){
    printf "\n"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    echo -e "\x1B[1m                    Summary of input                   \x1B[0m"
    echo -e "\x1B[1m*******************************************************\x1B[0m"

    echo -e "\x1B[1;31m1. Cloud Pak capability to deploy: \x1B[0m"
    if [ "${#pattern_arr[@]}" -eq "0" ]; then
        printf '   * %s\n' "None"
    else
        for each_pattern in "${pattern_arr[@]}"
        do
            if [[ "$each_pattern" =~ .*"Workflow Authoring".* || "$each_pattern" =~ .*"Workflow Runtime".* || "$each_pattern" =~ .*"Development Environment".* || "$each_pattern" =~ .*"Runtime Environment".* ]];then
               printf '     %s\n' "${each_pattern}"
            else
                printf '   * %s\n' "${each_pattern}"
            fi
        done
    fi

    echo -e "\x1B[1;31m2. Optional components to deploy: \x1B[0m"
    if [ "${#OPT_COMPONENTS_SELECTED[@]}" -eq "0" ]; then
        printf '   * %s\n' "None"
    else
        # printf '   * %s\n' "${OPT_COMPONENTS_SELECTED[@]}"
        for each_opt_component in "${OPT_COMPONENTS_SELECTED[@]}"
        do
            if [[ ${each_opt_component} == "ExternalShare" ]]; then
                printf '   * %s\n' "External Share"
            elif [[ ${each_opt_component} == "TaskManager" ]]
            then
                printf '   * %s\n' "Task Manager"
            elif [[ ${each_opt_component} == "ContentSearchServices" ]]
            then
                printf '   * %s\n' "Content Search Services"
            elif [[ ${each_opt_component} == "DecisionCenter" ]]
            then
                printf '   * %s\n' "Decision Center"
            elif [[ ${each_opt_component} == "RuleExecutionServer" ]]
            then
                printf '   * %s\n' "Rule Execution Server"
            elif [[ ${each_opt_component} == "DecisionRunner" ]]
            then
                printf '   * %s\n' "Decision Runner"
            elif [[ ${each_opt_component} == "DecisionDesigner" ]]
            then
                printf '   * %s\n' "Decision Designer"
            elif [[ ${each_opt_component} == "DecisionRuntime" ]]
            then
                printf '   * %s\n' "Decision Runtime"
            elif [[ "${each_opt_component}" == "ContentManagementInteroperabilityServices" ]]
            then
                printf '   * %s\n' "Content Management Interoperability Services"
            elif [[ "${each_opt_component}" == "UserManagementService" ]]
            then
                printf '   * %s\n' "User Management Service"
            elif [[ "${each_opt_component}" == "BusinessAutomationInsights" ]]
            then
                printf '   * %s\n' "Business Automation Insights"
            elif [[ "${each_opt_component}" == "ProcessFederationServer" ]]
            then
                printf '   * %s\n' "Process Federation Server"
            elif [[ "${each_opt_component}" == "DataCollectorandDataIndexer" ]]
            then
                printf '   * %s\n' "Data Collector and Data Indexer"
            elif [[ "${each_opt_component}" == "ExposedKafkaServices" ]]
            then
                printf '   * %s\n' "Exposed Kafka Services"
            elif [[ "${each_opt_component}" == "ExposedOpenSearch" ]]
            then
                printf '   * %s\n' "Exposed OpenSearch"
            elif [[ "${each_opt_component}" == "BusinessAutomationMachineLearning" ]]
            then
                printf '   * %s\n' "Business Automation Machine Learning"
            elif [[ "${each_opt_component}" == "ApplicationDesigner" ]]
            then
                printf '   * %s\n' "Application Designer"
            elif [[ "${each_opt_component}" == "BusinessAutomationApplicationDataPersistence" ]]
            then
                printf '   * %s\n' "Business Automation Application Data Persistence"
            elif [[ "${each_opt_component}" == "IBMEnterpriseRecords" ]]
            then
                printf '   * %s\n' "IBM Enterprise Records"
            elif [[ "${each_opt_component}" == "IBMContentCollectorforSAP" ]]
            then
                printf '   * %s\n' "IBM Content Collector for SAP"
            elif [[ "${each_opt_component}" == "IBMContentNavigator" ]]
            then
                printf '   * %s\n' "IBM Content Navigator"
            elif [[ "${each_opt_component}" == "ContentIntegration" ]]
            then
                printf '   * %s\n' "Content Integration"
            else
                printf '   * %s\n' "${each_opt_component}"
            fi
        done
    fi

    if [[ $PLATFORM_SELECTED == "other" ]]; then
        echo -e "\x1B[1;31m3. Entitlement Registry key:\x1B[0m" # not show plaintext password
        echo -e "\x1B[1;31m4. Docker registry service name or URL:\x1B[0m ${LOCAL_REGISTRY_SERVER}"
        echo -e "\x1B[1;31m5. Docker registry user name:\x1B[0m ${LOCAL_REGISTRY_USER}"
        # echo -e "\x1B[1;31m5. Docker registry password: ${LOCAL_REGISTRY_PWD}\x1B[0m"
        echo -e "\x1B[1;31m6. Docker registry password:\x1B[0m" # not show plaintext password
    fi
    if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]];
    then
        if [ -z "$existing_infra_name" ]; then
            if  [[ $DEPLOYMENT_TYPE == "starter" && $PLATFORM_SELECTED == "OCP" ]];
            then
                echo -e "\x1B[1;31m3. File storage classname(RWX):\x1B[0m ${STORAGE_CLASS_NAME}"
                echo -e "\x1B[1;31m4. Block storage classname(RWO):\x1B[0m ${BLOCK_STORAGE_CLASS_NAME}"
                if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
                    echo -e "\x1B[1;31m5. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
                fi
            else
                echo -e "\x1B[1;31m3. File storage classname(RWX):\x1B[0m"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Slow:" "${SLOW_STORAGE_CLASS_NAME}"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Medium:" "${MEDIUM_STORAGE_CLASS_NAME}"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Fast:" "${FAST_STORAGE_CLASS_NAME}"
                echo -e "\x1B[1;31m4. Block storage classname(RWO): \x1B[0m${BLOCK_STORAGE_CLASS_NAME}"
                echo -e "\x1B[1;31m5. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
            fi
        else
            if  [[ $PLATFORM_SELECTED == "OCP" ]]; then
                echo -e "\x1B[1;31m3. OCP Infrastructure Node:\x1B[0m ${INFRA_NAME}"
            elif [[ $PLATFORM_SELECTED == "ROKS" ]]
            then
                echo -e "\x1B[1;31m3. ROKS Infrastructure Node:\x1B[0m ${INFRA_NAME}"
            fi
            if  [[ $DEPLOYMENT_TYPE == "starter" && $PLATFORM_SELECTED == "OCP" ]];
            then
                echo -e "\x1B[1;31m4. File storage classname(RWX):\x1B[0m ${STORAGE_CLASS_NAME}"
                echo -e "\x1B[1;31m5. Block storage classname(RWO):\x1B[0m ${BLOCK_STORAGE_CLASS_NAME}"
                if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
                    echo -e "\x1B[1;31m6. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
                fi
            else
                echo -e "\x1B[1;31m4. File storage classname(RWX):\x1B[0m"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Slow:" "${SLOW_STORAGE_CLASS_NAME}"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Medium:" "${MEDIUM_STORAGE_CLASS_NAME}"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Fast:" "${FAST_STORAGE_CLASS_NAME}"
                echo -e "\x1B[1;31m5. Block storage classname(RWO): \x1B[0m${BLOCK_STORAGE_CLASS_NAME}"
                echo -e "\x1B[1;31m6. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
            fi
        fi
    else
        if  [[ $DEPLOYMENT_TYPE == "starter" ]];
        then
            echo -e "\x1B[1;31m3. File storage classname(RWX):\x1B[0m ${STORAGE_CLASS_NAME}"
            echo -e "\x1B[1;31m4. Block storage classname(RWO):\x1B[0m ${BLOCK_STORAGE_CLASS_NAME}"
            if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
                echo -e "\x1B[1;31m5. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
            fi
        else
            if [[ $PLATFORM_SELECTED == "other" ]]; then
                echo -e "\x1B[1;31m7. File storage classname(RWX):\x1B[0m"
            else
                echo -e "\x1B[1;31m3. File storage classname(RWX):\x1B[0m"
            fi
        fi
        printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Slow:" "${SLOW_STORAGE_CLASS_NAME}"
        printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Medium:" "${MEDIUM_STORAGE_CLASS_NAME}"
        printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Fast:" "${FAST_STORAGE_CLASS_NAME}"
        if [[ $PLATFORM_SELECTED == "other" ]]; then
            echo -e "\x1B[1;31m8. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
        fi
        if [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]]; then
            echo -e "\x1B[1;31m4. Block storage classname(RWO):\x1B[0m ${BLOCK_STORAGE_CLASS_NAME}"
            echo -e "\x1B[1;31m5. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
        fi
    fi
    echo -e "\x1B[1m*******************************************************\x1B[0m"
}

function prepare_pattern_file(){
    ${COPY_CMD} -rf "${OPERATOR_FILE}" "${OPERATOR_FILE_BAK}"
    # ${COPY_CMD} -rf "${OPERATOR_PVC_FILE}" "${OPERATOR_PVC_FILE_BAK}"

    if [[ "$DEPLOYMENT_TYPE" == "production" ]];then
        DEPLOY_TYPE_IN_FILE_NAME="production"
    else
        DEPLOY_TYPE_IN_FILE_NAME="starter"
    fi

    FOUNDATION_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_foundation.yaml

    CONTENT_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_content.yaml
    CONTENT_SEPARATE_PATTERN_FILE=${PARENT_DIR}/descriptors/sub-operator/FNCM/ibm_content_cr_${DEPLOY_TYPE_IN_FILE_NAME}.yaml

    CONTENT_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_content_tmp.yaml
    CONTENT_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_content.yaml

    APPLICATION_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_application.yaml
    APPLICATION_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_application_tmp.yaml
    APPLICATION_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_application.yaml

    DECISIONS_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_decisions.yaml
    DECISIONS_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_decisions_tmp.yaml
    DECISIONS_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_decisions.yaml

    ADS_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_decisions_ads.yaml
    ADS_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_decisions_ads_tmp.yaml
    ADS_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_decisions_ads.yaml

    ARIA_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_document_processing.yaml
    ARIA_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_document_processing_tmp.yaml
    ARIA_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_document_processing.yaml

    ${COPY_CMD} -rf "${CONTENT_PATTERN_FILE}" "${CONTENT_PATTERN_FILE_BAK}"
    ${COPY_CMD} -rf "${APPLICATION_PATTERN_FILE}" "${APPLICATION_PATTERN_FILE_BAK}"
    ${COPY_CMD} -rf "${ADS_PATTERN_FILE}" "${ADS_PATTERN_FILE_BAK}"
    ${COPY_CMD} -rf "${DECISIONS_PATTERN_FILE}" "${DECISIONS_PATTERN_FILE_BAK}"
    ${COPY_CMD} -rf "${ARIA_PATTERN_FILE}" "${ARIA_PATTERN_FILE_BAK}"

    ${COPY_CMD} -rf "${FOUNDATION_PATTERN_FILE}" "${CP4A_PATTERN_FILE_TMP}"
    if [[ "$DEPLOYMENT_TYPE" == "starter" ]];then
        WORKFLOW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow.yaml
        WORKFLOW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_tmp.yaml
        WORKFLOW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow.yaml

        WW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_authoring-workstreams.yaml
        WW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_authoring-workstreams_tmp.yaml
        WW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_authoring-workstreams.yaml
        ${COPY_CMD} -rf "${WORKFLOW_PATTERN_FILE}" "${WORKFLOW_PATTERN_FILE_BAK}"
        ${COPY_CMD} -rf "${WW_PATTERN_FILE}" "${WW_PATTERN_FILE_BAK}"
    elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
    then
        WORKFLOW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow.yaml
        WORKFLOW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_tmp.yaml
        WORKFLOW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow.yaml

        WORKSTREAMS_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workstreams.yaml
        WORKSTREAMS_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workstreams_tmp.yaml
        WORKSTREAMS_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workstreams.yaml

        WORKFLOW_AUTHOR_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_authoring.yaml
        WORKFLOW_AUTHOR_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_authoring_tmp.yaml
        WORKFLOW_AUTHOR_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_authoring.yaml

        WFPS_AUTHOR_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_process_service_authoring.yaml
        WFPS_AUTHOR_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_process_service_authoring_tmp.yaml
        WFPS_AUTHOR_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_process_service_authoring.yaml

        # merge workflow with workstreams templat for workflow-workstreams in 4Q
        ${YQ_CMD} m -a -M ${WORKFLOW_PATTERN_FILE} ${WORKSTREAMS_PATTERN_FILE} > /tmp/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_workstreams.yaml
        WW_PATTERN_FILE=/tmp/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_workstreams.yaml
        ${YQ_CMD} d -i ${WW_PATTERN_FILE} spec.initialize_configuration.ic_obj_store_creation.object_stores.[3]
        ${YQ_CMD} d -i ${WW_PATTERN_FILE} spec.datasource_configuration.dc_os_datasources.[3]
        ${YQ_CMD} d -i ${WW_PATTERN_FILE} spec.initialize_configuration.ic_ldap_creation.ic_ldap_admin_user_name.[1]
        ${YQ_CMD} d -i ${WW_PATTERN_FILE} spec.initialize_configuration.ic_ldap_creation.ic_ldap_admins_groups_name.[1]
        ${YQ_CMD} w -i ${WW_PATTERN_FILE} spec.baw_configuration.[0].host_federated_portal false
        ${YQ_CMD} w -i ${WW_PATTERN_FILE} spec.baw_configuration.[1].host_federated_portal false
        ${YQ_CMD} w -i ${WW_PATTERN_FILE} spec.baw_configuration.[0].host_federated_portal true
        WW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_workstreams_tmp.yaml
        WW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_workstreams.yaml

        ${COPY_CMD} -rf "${WORKFLOW_PATTERN_FILE}" "${WORKFLOW_PATTERN_FILE_BAK}"
        ${COPY_CMD} -rf "${WORKSTREAMS_PATTERN_FILE}" "${WORKSTREAMS_PATTERN_FILE_BAK}"
        ${COPY_CMD} -rf "${WORKFLOW_AUTHOR_PATTERN_FILE}" "${WORKFLOW_AUTHOR_PATTERN_FILE_BAK}"
        ${COPY_CMD} -rf "${WW_PATTERN_FILE}" "${WW_PATTERN_FILE_BAK}"
        ${COPY_CMD} -rf "${WFPS_AUTHOR_PATTERN_FILE}" "${WFPS_AUTHOR_PATTERN_FILE_BAK}"
    fi
}


function startup_operator(){
    # scale up CP4BA operators
    local project_name=$1
    local run_mode=$2  # silent
    # info "Scaling up \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator"
    kubectl scale --replicas=1 deployment ibm-cp4a-operator -n $project_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sleep 1
        if [[ -z "$run_mode" ]]; then
            echo "Done!"
        fi
    else
        fail "Failed to scale up \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator"
    fi

    # info "Scaling up \"IBM CP4BA FileNet Content Manager\" operator"
    kubectl scale --replicas=1 deployment ibm-content-operator -n $project_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sleep 1
        if [[ -z "$run_mode" ]]; then
            echo "Done!"
        fi
    else
        fail "Failed to scale up \"IBM CP4BA FileNet Content Manager\" operator"
    fi

    # info "Scaling up \"IBM CP4BA Foundation\" operator"
    kubectl scale --replicas=1 deployment icp4a-foundation-operator -n $project_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sleep 1
        if [[ -z "$run_mode" ]]; then
            echo "Done!"
        fi
    else
        fail "Failed to scale up \"IBM CP4BA Foundation\" operator"
    fi

    # info "Scaling up \"IBM CP4BA Automation Decision Service\" operator"
    kubectl scale --replicas=1 deployment ibm-ads-operator -n $project_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sleep 1
        if [[ -z "$run_mode" ]]; then
            echo "Done!"
        fi
    else
        fail "Failed to scale up \"IBM CP4BA Automation Decision Service\" operator"
    fi

    # info "Scaling up \"IBM CP4BA Workflow Process Service\" operator"
    kubectl scale --replicas=1 deployment ibm-cp4a-wfps-operator -n $project_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sleep 1
        if [[ -z "$run_mode" ]]; then
            echo "Done!"
        fi
    else
        fail "Failed to scale up \"IBM CP4BA Workflow Process Service\" operator"
    fi

    # DPE only support x86 so check the target cluster arch type
    arch_type=$(kubectl get cm cluster-config-v1 -n kube-system -o yaml | grep -i architecture|tail -1| awk '{print $2}')
    if [[ "$arch_type" == "amd64" ]]; then
        # info "Scaling up \"IBM Document Processing Engine\" operator"
        kubectl scale --replicas=1 deployment ibm-dpe-operator -n $project_name >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            sleep 1
            if [[ -z "$run_mode" ]]; then
                echo "Done!"
            fi
        else
            fail "Failed to scale up \"IBM Document Processing Engine\" operator"
        fi
    fi
    # info "Scaling up \"IBM CP4BA Insights Engine\" operator"
    kubectl scale --replicas=1 deployment ibm-insights-engine-operator -n $project_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sleep 1
        if [[ -z "$run_mode" ]]; then
            echo "Done!"
        fi
    else
        fail "Failed to scale up \"IBM CP4BA Insights Engine\" operator"
    fi

    # info "Scaling up \"IBM Operational Decision Manager\" operator"
    kubectl scale --replicas=1 deployment ibm-odm-operator -n $project_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sleep 1
        if [[ -z "$run_mode" ]]; then
            echo "Done!"
        fi
    else
        fail "Failed to scale up \"IBM Operational Decision Manager\" operator"
    fi

    # info "Scaling up \"IBM CP4BA Process Federation Server\" operator"
    kubectl scale --replicas=1 deployment ibm-pfs-operator -n $project_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sleep 1
        if [[ -z "$run_mode" ]]; then
            echo "Done!"
        fi
    else
        fail "Failed to scale up \"IBM CP4BA Process Federation Server\" operator"
    fi

    # info "Scaling up \"IBM CP4BA Workflow\" operator"
    kubectl scale --replicas=1 deployment ibm-workflow-operator -n $project_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sleep 1
        if [[ -z "$run_mode" ]]; then
            echo "Done!"
        fi
    else
        fail "Failed to scale up \"IBM CP4BA Workflow\" operator"
    fi
}

function shutdown_operator(){
    # scale down CP4BA operators
    local project_name=$1
    info "Scaling down \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator"
    kubectl scale --replicas=0 deployment ibm-cp4a-operator -n $project_name >/dev/null 2>&1
    sleep 1
    echo "Done!"

    info "Scaling down \"IBM CP4BA FileNet Content Manager\" operator"
    kubectl scale --replicas=0 deployment ibm-content-operator -n $project_name >/dev/null 2>&1
    sleep 1
    echo "Done!"

    info "Scaling down \"IBM CP4BA Foundation\" operator"
    kubectl scale --replicas=0 deployment icp4a-foundation-operator -n $project_name >/dev/null 2>&1
    sleep 1
    echo "Done!"

    info "Scaling down \"IBM CP4BA Automation Decision Service\" operator"
    kubectl scale --replicas=0 deployment ibm-ads-operator-controller-manager -n $project_name >/dev/null 2>&1
    kubectl scale --replicas=0 deployment ibm-ads-operator -n $project_name >/dev/null 2>&1
    sleep 1
    echo "Done!"

    info "Scaling down \"IBM CP4BA Workflow Process Service\" operator"
    kubectl scale --replicas=0 deployment ibm-cp4a-wfps-operator-controller-manager -n $project_name >/dev/null 2>&1
    kubectl scale --replicas=0 deployment ibm-cp4a-wfps-operator -n $project_name >/dev/null 2>&1
    sleep 1
    echo "Done!"

    info "Scaling down \"IBM Document Processing Engine\" operator"
    kubectl scale --replicas=0 deployment ibm-dpe-operator -n $project_name >/dev/null 2>&1
    sleep 1
    echo "Done!"

    info "Scaling down \"IBM CP4BA Insights Engine\" operator"
    kubectl scale --replicas=0 deployment ibm-insights-engine-operator -n $project_name >/dev/null 2>&1
    kubectl scale --replicas=0 deployment iaf-insights-engine-operator-controller-manager -n $project_name >/dev/null 2>&1
    sleep 1
    echo "Done!"

    info "Scaling down \"IBM Operational Decision Manager\" operator"
    kubectl scale --replicas=0 deployment ibm-odm-operator -n $project_name >/dev/null 2>&1
    sleep 1
    echo "Done!"

    info "Scaling down \"IBM CP4BA Process Federation Server\" operator"
    kubectl scale --replicas=0 deployment ibm-pfs-operator -n $project_name >/dev/null 2>&1
    echo "Done!"

    info "Scaling down \"IBM CP4BA Workflow\" operator"
    kubectl scale --replicas=0 deployment ibm-workflow-operator -n $project_name >/dev/null 2>&1
    echo "Done!"
}

function cncf_install(){
  sed -e '/dba_license/{n;s/value:.*/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  sed -e '/baw_license/{n;s/value:.*/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  sed -e '/fncm_license/{n;s/value:.*/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  sed -e '/ier_license/{n;s/value:.*/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml

  if [ ! -z ${IMAGEREGISTRY} ]; then
  # Change the location of the image
  echo "Using the operator image name: $IMAGEREGISTRY"
  sed -e "s|image: .*|image: \"$IMAGEREGISTRY\" |g" ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  fi

  # Change the pullSecrets if needed
  if [ ! -z ${PULLSECRET} ]; then
      echo "Setting pullSecrets to $PULLSECRET"
      sed -e "s|ibm-entitlement-key|$PULLSECRET|g" ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  else
      sed -e '/imagePullSecrets:/{N;d;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  fi
  kubectl apply -f ${CUR_DIR}/../descriptors/service_account.yaml --validate=false
  kubectl apply -f ${CUR_DIR}/../descriptors/role.yaml --validate=false
  kubectl apply -f ${CUR_DIR}/../descriptors/role_binding.yaml --validate=false
  kubectl apply -f ${CUR_DIR}/../upgradeOperator.yaml --validate=false
}

function show_help() {
    echo -e "\nUsage: cp4a-deployment.sh -m [modetype] -n <NAMESPACE>\n"
    echo "Options:"
    echo "  -h  Display the help"
    echo "  -m  The valid mode types are:[upgradeOperator], [upgradeOperatorStatus], [upgradeDeployment] and [upgradeDeploymentStatus]"
    # echo "  -s  The value of the update approval strategy. The valid values are: [automatic] and [manual]."
    echo "  -n  The target namespace of the CP4BA deployment."
    echo "  -i  Optional: Operator image name, by default it is cp.icr.io/cp/cp4a/icp4a-operator:$CP4BA_RELEASE_BASE"
    echo "  -p  Optional: Pull secret to use to connect to the registry, by default it is ibm-entitlement-key"
    echo "  --enable-private-catalog Optional: Set this flag to let the script to switch CatalogSource from global to namespace scoped. Default is in openshift-marketplace namespace"
    echo "  ${YELLOW_TEXT}* Running the script to create a custom resource file for new CP4BA deployment:${RESET_TEXT}"
    echo "      - STEP 1: Run the script without any parameter."
    echo "  ${YELLOW_TEXT}* Running the script to upgrade a CP4BA deployment from 21.0.3 IF031/23.0.2 IF003 or later IFIX to $CP4BA_RELEASE_BASE GA/$CP4BA_RELEASE_BASE.X. You must run the modes in the following order:${RESET_TEXT}"
    echo "      - STEP 1 (Required): Run the script in [upgradeOperator] mode to upgrade CP4BA operators/migrate (Cluster-scoped -> Cluster-scoped [AllNamespaces] / Cluster-scoped -> Namespace-scoped / Namespace-scoped -> Namespace-scoped) the IBM Cloud Pak foundational services and then shutdown all CP4BA operators before upgrade CP4BA deployment."
    echo "      - STEP 2 (Optional): Run the script in [upgradeOperatorStatus] mode to check that the upgrade of the CP4BA operator and its dependencies is successful."
    echo "      - STEP 3 (Required): Run the script in [upgradeDeployment] mode to upgrade the CP4BA deployment (The script will generate the new version custom resource, and you can choose review/modification it offline and apply it later or apply it by script without review/modification)."
    echo "      - STEP 4 (Required): Run the script in [upgradeDeploymentStatus] mode to start necessary CP4BA operators to upgrade the dependent service (zenService) firslty and then start up all CP4BA operators to complete upgrade of the CP4BA deployment, meanwhile, it will check that the upgrade of the CP4BA deployment is successful."
    # echo "      - STEP 5 (Required): Run the script in [upgradePostconfig] mode to show the configuration post CP4BA deployment upgrade."
    echo "  ${YELLOW_TEXT}* Running the script to upgrade a CP4BA deployment from $CP4BA_RELEASE_BASE GA/$CP4BA_RELEASE_BASE.X to $CP4BA_RELEASE_BASE.X. You must run the modes in the following order:${RESET_TEXT}"
    echo "      - STEP 1 (Required): Run the script in [upgradeOperator] mode to upgrade the IBM Cloud Pak foundational services/CP4BA operators and then shutdown all CP4BA operators before upgrade CP4BA deployment."
    echo "      - STEP 2 (Optional): Run the script in [upgradeOperatorStatus] mode to check that the upgrade of the CP4BA operator and its dependencies is successful."
    echo "      - STEP 3 (Required): Run the script in [upgradeDeploymentStatus] mode to start necessary CP4BA operators to upgrade the dependent service (zenService) firslty and then start up all CP4BA operators to complete upgrade of the CP4BA deployment, meanwhile, it will check that the upgrade of the CP4BA deployment is successful."

}

function parse_arguments() {
    # process options
    while [[ "$@" != "" ]]; do
        case "$1" in
        -m)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -m requires an argument"
                exit 1
            fi
            RUNTIME_MODE=$1
            if [[ $RUNTIME_MODE == "upgradeOperator" || $RUNTIME_MODE == "upgradeOperatorStatus" || $RUNTIME_MODE == "upgradeDeployment" || $RUNTIME_MODE == "upgradeDeploymentStatus" ]]; then
                echo -n
            else
                msg "Use a valid value: -m [upgradeOperator] or [upgradeOperatorStatus] or [upgradeDeployment] or [upgradeDeploymentStatus]"
                exit -1
            fi
            ;;
        # -s)
        #     shift
        #     if [ -z $1 ]; then
        #         echo "Invalid option: -s requires an argument"
        #         exit 1
        #     fi
        #     UPDATE_APPROVAL_STRATEGY=$1
        #     if [[ $UPDATE_APPROVAL_STRATEGY == "automatic" || $UPDATE_APPROVAL_STRATEGY == "manual" ]]; then
        #         echo -n
        #     else
        #         msg "Use a valid value: -s [automatic] or [manual]"
        #         exit -1
        #     fi
        #     ;;
        -n)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -n requires an argument"
                exit 1
            fi
            TARGET_PROJECT_NAME=$1
            case "$TARGET_PROJECT_NAME" in
            "")
                echo -e "\x1B[1;31mEnter a valid namespace name, namespace name can not be blank\x1B[0m"
                exit -1
                ;;
            "openshift"*)
                echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
                exit -1
                ;;
            "kube"*)
                echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
                exit -1
                ;;
            *)
                isProjExists=`kubectl get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l`  >/dev/null 2>&1
                if [ $isProjExists -ne 2 ] ; then
                    echo -e "\x1B[1;31mInvalid project name \"$TARGET_PROJECT_NAME\", please set a valid name...\x1B[0m"
                    exit 1
                fi
                echo -n
                ;;
            esac
            ;;
        -i)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -i requires an argument"
                exit 1
            fi
            IMAGEREGISTRY=$1
            ;;
        -p)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -p requires an argument"
                exit 1
            fi
            PULLSECRET=$1
            ;;
        -h | --help | \?)
            show_help
            exit 0
            ;;
        --enable-private-catalog)
            ENABLE_PRIVATE_CATALOG=1
            ;;
        --original-cp4ba-csv-ver)
            shift
            CP4BA_ORIGINAL_CSV_VERSION=$1
            ;;
        --cpfs-upgrade-mode)
            shift
            UPGRADE_MODE=$1
            ;;
        *)
            echo "Invalid option"
            show_help
            exit 1
            ;;
        esac
        shift
    done
}
################################################
#### Begin - Main step for install operator ####
################################################
save_log "cp4a-script-logs" "cp4a-deployment-log"
trap cleanup_log EXIT
if [[ $1 == "" || $1 == "dev" || $1 == "review" || $1 == "baw-dev" ]]
then
    prompt_license

    set_script_mode

    input_information

    show_summary

    while true; do

        printf "\n"
        printf "\x1B[1mVerify that the information above is correct.\n\x1B[0m"
        printf "\x1B[1mTo proceed with the deployment, enter \"Yes\".\n\x1B[0m"
        printf "\x1B[1mTo make changes, enter \"No\" (default: No): \x1B[0m"
        if [[ -z ${CP4BA_SKIP_SUMMARY} ]]; then
          read -rp "" ans
        else
            ans=${CP4BA_SKIP_SUMMARY}
        fi
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            if [[ ("$SCRIPT_MODE" != "review") && ("$SCRIPT_MODE" != "OLM") ]]; then
                if [[ $DEPLOYMENT_TYPE == "production" ]];then
                    printf "\n"
                    echo -e "\x1B[1mCreating the Custom Resource of the Cloud Pak for Business Automation operator...\x1B[0m"
                fi
            fi
            printf "\n"
            if [[ "${INSTALLATION_TYPE}"  == "new" ]]; then
                if [[ "$SCRIPT_MODE" == "review" ]]; then
                    echo -e "\x1B[1mReview mode running, just generate final CR, will not deploy operator\x1B[0m"
                    # read -rsn1 -p"Press any key to continue";echo
                elif [[ "$SCRIPT_MODE" == "OLM" ]]
                then
                    echo -e "\x1B[1mA custom resource file to apply in the OCP Catalog is being generated.\x1B[0m"
                    # read -rsn1 -p"Press any key to continue";echo
                else
                    if [ "$use_entitlement" = "no" ] ; then
                        isReady=$(${CLI_CMD} get secret | grep ibm-entitlement-key)
                        if [[ -z $isReady ]]; then
                            echo "NOT found secret \"ibm-entitlement-key\", exiting..."
                            exit 1
                        else
                            echo "Found secret \"ibm-entitlement-key\", continue...."
                        fi
                    fi
                fi
            fi
            apply_pattern_cr
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|*)
            while true; do
                printf "\n"
                show_summary
                printf "\n"

                if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]];
                then
                    printf "\x1B[1mEnter the number from 1 to 5 that you want to change: \x1B[0m"
                else
                    printf "\x1B[1mEnter the number from 1 to 7 that you want to change: \x1B[0m"
                fi

                read -rp "" ans
                if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]];
                then
                    case "$ans" in
                    "1")
                        if [[ $DEPLOYMENT_TYPE == "starter" || $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
                            select_pattern
                            select_optional_component
                            if [[ ( -z "$CP4BA_JDBC_URL" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ]]; then
                                get_jdbc_url
                            fi
                        else
                            info "Please run cp4a-prerequisites.sh to modify CP4BA pattern"
                            read -rsn1 -p"Press any key to continue";echo
                        fi
                        break
                        ;;
                    "2")
                        if [[ $DEPLOYMENT_TYPE == "starter" || $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
                            select_optional_component
                            if [[ ( -z "$CP4BA_JDBC_URL" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ]]; then
                                get_jdbc_url
                            fi
                        else
                            info "Please run cp4a-prerequisites.sh to modify optional components"
                            read -rsn1 -p"Press any key to continue";echo
                        fi
                        break
                        ;;
                    "3"|"4")
                        if [[ $DEPLOYMENT_TYPE == "starter" || $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
                            get_storage_class_name
                        else
                            info "Please run cp4a-prerequisites.sh to modify storage class name"
                            read -rsn1 -p"Press any key to continue";echo
                        fi
                        break
                        ;;
                    "5")
                        get_jdbc_url
                        break
                        ;;
                    *)
                        echo -e "\x1B[1mEnter a valid number [1 to 5] \x1B[0m"
                        ;;
                    esac
                else
                    case "$ans" in
                    "1")
                        if [[ $DEPLOYMENT_TYPE == "starter" || $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
                            select_pattern
                            select_optional_component
                            if [[ ( -z "$CP4BA_JDBC_URL" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ]]; then
                                get_jdbc_url
                            fi
                        else
                            info "Please run cp4a-prerequisites.sh to modify CP4BA pattern"
                            read -rsn1 -p"Press any key to continue";echo
                        fi
                        break
                        ;;
                    "2")
                        if [[ $DEPLOYMENT_TYPE == "starter" || $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
                            select_optional_component
                            if [[ ( -z "$CP4BA_JDBC_URL" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ]]; then
                                get_jdbc_url
                            fi
                        else
                            info "Please run cp4a-prerequisites.sh to modify optional components"
                            read -rsn1 -p"Press any key to continue";echo
                        fi
                        break
                        ;;
                    "3")
                        get_entitlement_registry
                        break
                        ;;
                    "4")
                        get_local_registry_server
                        break
                        ;;
                    "5")
                        get_local_registry_user
                        break
                        ;;
                    "6")
                        get_local_registry_password
                        break
                        ;;
                    "7")
                        if [[ $DEPLOYMENT_TYPE == "starter" || $DEPLOYMENT_WITH_PROPERTY == "No" ]]; then
                            get_storage_class_name
                        else
                            info "Please run cp4a-prerequisites.sh to modify storage class name"
                            read -rsn1 -p"Press any key to continue";echo
                        fi
                        break
                        ;;
                    "8")
                        get_jdbc_url
                        break
                        ;;
                    *)
                        echo -e "\x1B[1mEnter a valid number [1 to 8] \x1B[0m"
                        ;;
                    esac
                fi
            done
            show_summary
            ;;
        esac
    done
else
    # Import upgrade prerequisite.sh script
    source ${CUR_DIR}/helper/upgrade/prerequisite.sh
    ENABLE_PRIVATE_CATALOG=0
    parse_arguments "$@"
    if [[ -z "$RUNTIME_MODE" ]]; then
        echo -e "\x1B[1;31mPlease input value for \"-m <MODE_NAME>\" option.\n\x1B[0m"
        exit 1
    fi
    if [[ -z "$TARGET_PROJECT_NAME" ]]; then
        echo -e "\x1B[1;31mPlease input value for \"-n <NAME_SPACE>\" option.\n\x1B[0m"
        exit 1
    fi
fi

# Import upgrade upgrade_check_version.sh script
source ${CUR_DIR}/helper/upgrade/upgrade_check_status.sh

if [ "$RUNTIME_MODE" == "upgradeOperator" ]; then
    project_name=$TARGET_PROJECT_NAME
    UPGRADE_DEPLOYMENT_FOLDER=${CUR_DIR}/cp4ba-upgrade/project/$TARGET_PROJECT_NAME
    UPGRADE_DEPLOYMENT_PROPERTY_FILE=${UPGRADE_DEPLOYMENT_FOLDER}/cp4ba_upgrade.property

    UPGRADE_DEPLOYMENT_CR=${UPGRADE_DEPLOYMENT_FOLDER}/custom_resource
    UPGRADE_DEPLOYMENT_CR_BAK=${UPGRADE_DEPLOYMENT_CR}/backup
    UPGRADE_DEPLOYMENT_CONTENT_CR=${UPGRADE_DEPLOYMENT_CR}/content.yaml
    UPGRADE_DEPLOYMENT_CONTENT_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.content_tmp.yaml
    UPGRADE_DEPLOYMENT_CONTENT_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/content_cr_backup.yaml

    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR=${UPGRADE_DEPLOYMENT_CR}/icp4acluster.yaml
    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.icp4acluster_tmp.yaml
    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/icp4acluster_cr_backup.yaml

    UPGRADE_DEPLOYMENT_BAI_TMP=${UPGRADE_DEPLOYMENT_CR}/.bai_tmp.yaml

    if which oc >/dev/null 2>&1; then
        CLI_CMD=oc
    elif which kubectl >/dev/null 2>&1; then
        CLI_CMD=kubectl
    else
        echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI or OpenShift CLI. You must install it to run this script.\x1B[0m" && \
        exit 1
    fi

    mkdir -p ${UPGRADE_DEPLOYMENT_CR} >/dev/null 2>&1
    mkdir -p ${TEMP_FOLDER} >/dev/null 2>&1

    # As workaround for https://github.ibm.com/IBMPrivateCloud/roadmap/issues/64017
    # require to remove ibm-operator-catalog first, and then to add back after upgrading.
    info "Checking \"ibm-operator-catalog\" exist or not in project \"openshift-marketplace\""
    printf "\n"
    if ${CLI_CMD} get catalogsource -n openshift-marketplace --no-headers --ignore-not-found | grep ibm-operator-catalog >/dev/null 2>&1; then
        echo "${RED_TEXT}[WARNING]: ${RESET_TEXT}${YELLOW_TEXT}Detected \"ibm-operator-catalog\" catalog source in project \"openshift-marketplace\".  This configuration could cause IBM Cloud Pak foundational services script to timeout and potentially impact the upgrade, if you encounter a timeout, you could follow the tips from the output and rerun the commands to continue upgrade.${RESET_TEXT}"
        read -rsn1 -p"Press any key to continue";echo
    fi

    cp4a_operator_csv_name_target_ns=$(${CLI_CMD} get csv -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
    cp4a_operator_csv_name_allnamespace_ns=$(${CLI_CMD} get csv -n $ALL_NAMESPACE_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')

    if [[ -z $cp4a_operator_csv_name_allnamespace_ns && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
        success "Found IBM Cloud Pak for Business Automation Operator deployed in the project \"$TARGET_PROJECT_NAME\"."
        ALL_NAMESPACE_FLAG="No"
        TEMP_OPERATOR_PROJECT_NAME=$TARGET_PROJECT_NAME
    elif [[ (! -z $cp4a_operator_csv_name_allnamespace_ns) && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
        success "Found IBM Cloud Pak for Business Automation Operator deployed as AllNamespace mode in the project \"$ALL_NAMESPACE_NAME\"."
        ALL_NAMESPACE_FLAG="Yes"
        project_name="openshift-operators"
        TEMP_OPERATOR_PROJECT_NAME="openshift-operators"
    fi

    source ${CUR_DIR}/helper/upgrade/upgrade_merge_yaml.sh $TARGET_PROJECT_NAME

    # Confirm finish migration from Elasticsearch to Opensearch.
    info "Checking legacy Elasticsearch is installed for this CP4BA deployment or not."

    ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        content_cr_name=$(${CLI_CMD} get content -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
        if [ ! -z $content_cr_name ]; then
            cr_type="content"
            cp4ba_cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
            owner_ref=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
            if [[ ${owner_ref} == "ICP4ACluster" ]]; then
                echo
            else
                ${CLI_CMD} get $cr_type $content_cr_name -n $TARGET_PROJECT_NAME -o yaml > ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                bai_flag=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP | ${YQ_CMD} r - spec.content_optional_components.bai`
                bai_flag=$(echo $bai_flag | tr '[:upper:]' '[:lower:]')
                CONTENT_CR_EXIST="Yes"
                cp4ba_root_ca_secret_name=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.root_ca_secret`
            fi
        fi
    fi

    icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $icp4acluster_cr_name ]; then
        cr_type="icp4acluster"
        cp4ba_cr_metaname=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
        ${CLI_CMD} get $cr_type $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml > ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        cp4ba_root_ca_secret_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.root_ca_secret`
        convert_olm_cr "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        if [[ $olm_cr_flag == "No" ]]; then
            # Get EXISTING_PATTERN_ARR/EXISTING_OPT_COMPONENT_ARR
            existing_pattern_list=""
            existing_opt_component_list=""
            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
            existing_opt_component_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`

            OIFS=$IFS
            IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
            IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
            IFS=$OIFS
        fi
    fi
    if [[ -z $content_cr_name && -z $icp4acluster_cr_name ]]; then
        fail "Not found any CP4BA custom resource in cluster in the project \"$TARGET_PROJECT_NAME\"."
        exit 1
    fi


    old_elastic_cr_name=$(${CLI_CMD} get Elasticsearch.elastic.automation.ibm.com -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
    # if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") || $bai_flag == "True" || $bai_flag == "true" ]]; then
    if [[  ! -z $old_elastic_cr_name  ]]; then
        info "Found the legacy Elasticsearch deployment in the project \"$TARGET_PROJECT_NAME\"."
        if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") || $bai_flag == "true" ]]; then
        # test_flag="true"
        # if [[ $test_flag == "false" ]]; then
            info "Found the BAI component selected for this CP4BA deployment in the project \"$TARGET_PROJECT_NAME\"."
            es_to_os_migration_flag=$(${CLI_CMD} get configmap ibm-cp4ba-os-migration-status --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath={.data.opensearch_migration_done})
            es_to_os_migration_flag=$(echo $es_to_os_migration_flag | tr '[:upper:]' '[:lower:]')
            if [[ -z $es_to_os_migration_flag || $es_to_os_migration_flag == "no" ]]; then
                check_es_to_os_migration
            elif [[ $es_to_os_migration_flag == "yes" ]]; then
                # the script still need check ElasticsearchCluster cr even opensearch_migration_done is yes
                ${CLI_CMD} get crd |grep elasticsearch.opencontent.ibm.com >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    opensearch_cr_name=$(${CLI_CMD} get ElasticsearchCluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
                    if [ -z $opensearch_cr_name ]; then
                        warning "Opensearch is not installed (ElasticsearchCluster custom resource could not be found in project \"$TARGET_PROJECT_NAME\")."
                        check_es_to_os_migration
                    else
                        success "Found the \"opensearch_migration_done\" is \"Yes\" in ibm-cp4ba-os-migration-status configMap in the project \"$TARGET_PROJECT_NAME\""
                        sleep 5
                    fi
                else
                    warning "Not found ElasticsearchCluster CRD, you need to install Opensearch cluster before migration from Elasticserch to Opensearch."
                    check_es_to_os_migration
                fi
            fi
        else
            info "Not found the BAI component selected for this CP4BA deployment in the project \"$TARGET_PROJECT_NAME\"."
            check_selection_migration
            if [[ $ES_TO_OS_MIGRATION_SELECTED == "Yes" ]]; then
                es_to_os_migration_flag=$(${CLI_CMD} get configmap ibm-cp4ba-os-migration-status --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath={.data.opensearch_migration_done})
                es_to_os_migration_flag=$(echo $es_to_os_migration_flag | tr '[:upper:]' '[:lower:]')
                if [[ -z $es_to_os_migration_flag || $es_to_os_migration_flag == "no" ]]; then
                    check_es_to_os_migration
                elif [[ $es_to_os_migration_flag == "yes" ]]; then
                    # the script still need check ElasticsearchCluster cr even opensearch_migration_done is yes
                    ${CLI_CMD} get crd |grep elasticsearch.opencontent.ibm.com >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        opensearch_cr_name=$(${CLI_CMD} get ElasticsearchCluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
                        if [ -z $opensearch_cr_name ]; then
                            warning "Opensearch is not installed (ElasticsearchCluster custom resource could not be found in project \"$TARGET_PROJECT_NAME\")."
                            check_es_to_os_migration
                        else
                            success "Found the \"opensearch_migration_done\" is \"Yes\" in ibm-cp4ba-os-migration-status configMap in the project \"$TARGET_PROJECT_NAME\""
                            sleep 5
                        fi
                    else
                        warning "Not found ElasticsearchCluster CRD, you need to install Opensearch cluster before migration from Elasticserch to Opensearch."
                        check_es_to_os_migration
                    fi
                fi
            elif [[ $ES_TO_OS_MIGRATION_SELECTED == "No" ]]; then
                MIGRATE_ES_TO_OS_DONE="NONEED"
                create_configmap_os_migration
            fi
        fi
    fi

    info "Starting to upgrade CP4BA operators and IBM Cloud Pak foundational services"
    # check current cp4ba version
    check_cp4ba_operator_version $TARGET_PROJECT_NAME

    if [[ "$cp4a_operator_csv_version" == "${CP4BA_CSV_VERSION//v/}" ]]; then
        warning "The CP4BA operator already is $CP4BA_CSV_VERSION."
        printf "\n"
        while true; do
            printf "\n"
            printf "\x1B[1mDo you want to continue to do upgrade? (Yes/No, default: No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again."
                echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                echo "           Usage:"
                echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                echo "           Example command: "
                echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31${RESET_TEXT}"
                exit 1
                ;;
            "n"|"N"|"no"|"No"|"NO"|"")
                echo "Exiting..."
                exit 1
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi

    info "Checking ibm-cp4ba-shared-info/ibm-cp4ba-content-shared-info configMap existing or not in the project \"$TARGET_PROJECT_NAME\""
    ibm_cp4ba_shared_info_cm=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.data.cp4ba_operator_of_last_reconcile}')
    ibm_cp4ba_content_shared_info_cm=$(${CLI_CMD} get configmap ibm-cp4ba-content-shared-info --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.data.content_operator_of_last_reconcile}')

    # Create ibm-cp4ba-shared-info configMap if not exist
    icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $icp4acluster_cr_name ]; then
        cr_verison=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.appVersion)
        cr_metaname=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
        cr_uid=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.uid)
        if [[ -z $ibm_cp4ba_shared_info_cm ]]; then
            info "Not found ibm-cp4ba-shared-info configMap,creating it."
            create_ibm_cp4ba_shared_info_cm_yaml
            ${SED_COMMAND} "s|<cp4a_namespace>|$TARGET_PROJECT_NAME|g" ${UPGRADE_ICP4A_SHARED_INFO_CM_FILE}
            ${SED_COMMAND} "s|<cr_metaname>|$cr_metaname|g" ${UPGRADE_ICP4A_SHARED_INFO_CM_FILE}
            ${SED_COMMAND} "s|<cr_uid>|$cr_uid|g" ${UPGRADE_ICP4A_SHARED_INFO_CM_FILE}
            ${SED_COMMAND} "s|<cr_version>|$cp4a_operator_csv_version|g" ${UPGRADE_ICP4A_SHARED_INFO_CM_FILE}

            ${CLI_CMD} apply -f $UPGRADE_ICP4A_SHARED_INFO_CM_FILE  >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                success "Created ibm-cp4ba-shared-info configMap in the project \"$TARGET_PROJECT_NAME\"!"
            else
                fail "Failed to create ibm-cp4ba-shared-info configMap in the project \"$TARGET_PROJECT_NAME\"!"
            fi
        else
            success "Found ibm-cp4ba-shared-info configMap under \"$TARGET_PROJECT_NAME\"!"
        fi
    fi

    # Create ibm-cp4ba-content-shared-info configMap if not exist
    ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        content_cr_name=$(${CLI_CMD} get content -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
        if [ ! -z $content_cr_name ]; then
            cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
            owner_ref=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
            if [[ ${owner_ref} != "ICP4ACluster" ]]; then
                cr_verison=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.appVersion)
                cr_uid=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.uid)
                if [[ -z $ibm_cp4ba_content_shared_info_cm ]]; then
                    info "Not found ibm-cp4ba-content-shared-info configMap,creating it."
                    create_ibm_cp4ba_content_shared_info_cm_yaml
                    ${SED_COMMAND} "s|<content_namespace>|$TARGET_PROJECT_NAME|g" ${UPGRADE_ICP4A_CONTENT_SHARED_INFO_CM_FILE}
                    ${SED_COMMAND} "s|<cr_metaname>|$cr_metaname|g" ${UPGRADE_ICP4A_CONTENT_SHARED_INFO_CM_FILE}
                    ${SED_COMMAND} "s|<cr_uid>|$cr_uid|g" ${UPGRADE_ICP4A_CONTENT_SHARED_INFO_CM_FILE}
                    ${SED_COMMAND} "s|<cr_version>|${cp4a_operator_csv_version}|g" ${UPGRADE_ICP4A_CONTENT_SHARED_INFO_CM_FILE}

                    ${CLI_CMD} apply -f $UPGRADE_ICP4A_CONTENT_SHARED_INFO_CM_FILE  >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        success "Created ibm-cp4ba-content-shared-info configMap in the project \"$TARGET_PROJECT_NAME\"!"
                    else
                        fail "Failed to create ibm-cp4ba-content-shared-info configMap in the project \"$TARGET_PROJECT_NAME\"!"
                    fi
                else
                    success "Found ibm-cp4ba-content-shared-info configMap under \"$TARGET_PROJECT_NAME\"!"
                fi
            fi
        fi
    fi

    # # check content operator version if CP4BA is 22.0.1 or later
    # check_content_operator_version $TARGET_PROJECT_NAME
    PLATFORM_SELECTED=$(eval echo $(${CLI_CMD} get icp4acluster $(${CLI_CMD} get icp4acluster --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME | grep NAME -v | awk '{print $1}') --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o yaml | grep sc_deployment_platform | tail -1 | cut -d ':' -f 2))
    if [[ -z $PLATFORM_SELECTED ]]; then
        PLATFORM_SELECTED=$(eval echo $(${CLI_CMD} get content $(${CLI_CMD} get content --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME | grep NAME -v | awk '{print $1}') --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o yaml | grep sc_deployment_platform | tail -1 | cut -d ':' -f 2))
        if [[ -z $PLATFORM_SELECTED ]]; then
            fail "Not found any custom resource for CP4BA in the project \"$TARGET_PROJECT_NAME\", exiting"
            exit 1
        fi
    fi

    # Checking the CPfs mode
    if [[ -z $UPGRADE_MODE ]]; then
        cs_dedicated=$(${CLI_CMD} get cm -n ${COMMON_SERVICES_CM_NAMESPACE}  | grep ${COMMON_SERVICES_CM_DEDICATED_NAME} | awk '{print $1}')

        cs_shared=$(${CLI_CMD} get cm -n ${COMMON_SERVICES_CM_NAMESPACE}  | grep ${COMMON_SERVICES_CM_SHARED_NAME} | awk '{print $1}')

        if [[ "$cs_dedicated" != "" || "$cs_shared" != ""  ]] ; then
            control_namespace=$(${CLI_CMD} get cm ${COMMON_SERVICES_CM_DEDICATED_NAME} --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE} -o jsonpath='{ .data.common-service-maps\.yaml }' | grep  'controlNamespace' | cut -d':' -f2 )
            control_namespace=$(sed -e 's/^"//' -e 's/"$//' <<<"$control_namespace")
            control_namespace=$(sed "s/ //g" <<< $control_namespace)
        fi


        if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
            UPGRADE_MODE="shared2shared"
            ENABLE_PRIVATE_CATALOG=0
            info "Found the IBM Cloud Pak foundational services/IBM Cloud Pak for Business Automation are installed into all namespaces, IBM Cloud Pak foundational services only can be migrated from \"Cluster-scoped\" to \"Cluster-scoped\"!"
        elif [[ "$cs_dedicated" != "" && "$cs_shared" == "" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Namespace-scoped\"."
            UPGRADE_MODE="dedicated2dedicated"
        elif [[ "$cs_dedicated" == "" && "$cs_shared" != "" && $ALL_NAMESPACE_FLAG == "No" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
            # select_upgrade_mode
            UPGRADE_MODE="shared2dedicated"
            info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
            read -rsn1 -p"Press any key to continue";echo
        elif [[ "$cs_dedicated" != "" && "$cs_shared" != "" && "$control_namespace" == "" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
            # select_upgrade_mode
            UPGRADE_MODE="shared2dedicated"
            info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
            read -rsn1 -p"Press any key to continue";echo
        elif [[ "$cs_dedicated" != "" && "$cs_shared" != "" && "$control_namespace" != "" ]]; then
            ${CLI_CMD} get cm ${COMMON_SERVICES_CM_DEDICATED_NAME} --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE} -o jsonpath='{ .data.common-service-maps\.yaml }' > /tmp/common-service-maps.yaml
            index=0
            common_service_namespace=`cat /tmp/common-service-maps.yaml | ${YQ_CMD} r - namespaceMapping.[$index].map-to-common-service-namespace`
            while [[ ! -z $common_service_namespace ]]
            do
                if [[ $common_service_namespace == "ibm-common-services" ]]; then
                    info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
                    # select_upgrade_mode
                    UPGRADE_MODE="shared2dedicated"
                    info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
                    read -rsn1 -p"Press any key to continue";echo
                    break
                fi
                ((index++))
                common_service_namespace=`cat /tmp/common-service-maps.yaml | ${YQ_CMD} r - namespaceMapping.[$index].map-to-common-service-namespace`
                if [[ -z $common_service_namespace ]]; then
                    info "IBM Cloud Pak foundational services is working in \"Namespace-scoped\"."
                    UPGRADE_MODE="dedicated2dedicated"
                fi
            done
        elif [[ $ALL_NAMESPACE_FLAG == "No" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
            # select_upgrade_mode
            UPGRADE_MODE="shared2dedicated"
            info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
            read -rsn1 -p"Press any key to continue";echo
        fi
    fi

    if [[ "$PLATFORM_SELECTED" != "others" ]]; then
        # checking existing catalog type
        if ${CLI_CMD} get catalogsource -n openshift-marketplace --no-headers --ignore-not-found | grep ibm-cp4a-operator-catalog >/dev/null 2>&1; then
            CATALOG_FOUND="Yes"
            PINNED="Yes"
        elif ${CLI_CMD} get catalogsource -n openshift-marketplace --no-headers --ignore-not-found | grep ibm-operator-catalog >/dev/null 2>&1; then
            CATALOG_FOUND="Yes"
            PINNED="No"
        else
            CATALOG_FOUND="No"
            PINNED="Yes" # Fresh install use pinned catalog source
        fi

        # Check --enable-private-catalog is set or not and whether reasonable for shared2shared
        # To call select_private_catalog_cp4ba if not set --enable-private-catalog option.
        if ${CLI_CMD} get catalogsource -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | grep ibm-cp4a-operator-catalog >/dev/null 2>&1; then
            PRIVATE_CATALOG_FOUND="Yes"
            ENABLE_PRIVATE_CATALOG=1
            info "Found this CP4BA deployment is installed using private catalog in the project \"$TARGET_PROJECT_NAME\""
        elif ${CLI_CMD} get catalogsource -n openshift-marketplace --no-headers --ignore-not-found | grep ibm-cp4a-operator-catalog >/dev/null 2>&1; then
            PRIVATE_CATALOG_FOUND="No"
            info "Found this CP4BA deployment is installed using global catalog in the project \"openshift-marketplace\""
            if [[ $ENABLE_PRIVATE_CATALOG -eq 1 && $UPGRADE_MODE == "shared2shared" ]]; then
                ENABLE_PRIVATE_CATALOG=0
                warning "Can NOT switch catalog source from global catalog namespace (GCN) to private catalog (namespace-scoped) when migration IBM Cloud Pak foundational services from \"Cluster-scoped to Namespace-scoped\"."
                read -rsn1 -p"Press any key to continue";echo
            elif [[ $ENABLE_PRIVATE_CATALOG -eq 1 && ($UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated") ]]; then
                info "You set the option \"--enable-private-catalog\" for this CP4BA deployment to use private catalog"
            elif [[ $ENABLE_PRIVATE_CATALOG -eq 0 || -z $ENABLE_PRIVATE_CATALOG ]]; then
                if [[ $UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated" ]]; then
                    select_private_catalog_cp4ba
                elif [[ $UPGRADE_MODE == "shared2shared" ]]; then
                    info "Keep to use global catalog namespace (GCN) for this CP4BA deployment when migration IBM Cloud Pak foundational services from \"Cluster-scoped\" to \"Cluster-scoped\"."
                    sleep 2
                fi
            fi
        fi

        # Checking whether can switch GCN to namesapce scoped catalog source if CPfs/CP4BA is in AllNamespace
        if [[ $ENABLE_PRIVATE_CATALOG -eq 1 && $ALL_NAMESPACE_FLAG == "Yes" ]]; then
            ENABLE_PRIVATE_CATALOG=0
            warning "Can NOT switch catalog source from global catalog namespace (GCN) to private catalog (namespace-scoped) when CP4BA is in AllNamespaces."
            read -rsn1 -p"Press any key to continue";echo
        elif [[ $ENABLE_PRIVATE_CATALOG -eq 1 && $PRIVATE_CATALOG_FOUND == "No" && ($UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated") ]]; then
            info "The global catalog namespace (GCN) will be switched to private catalog (namespace-scoped)."
            sleep 2
        elif [[ $PRIVATE_CATALOG_FOUND == "Yes" ]]; then
            ENABLE_PRIVATE_CATALOG=1
            info "Keep to use private catalog (namespace-scoped) for this CP4BA deployment."
            sleep 2
        fi

        # For shared->dedicated upgrade, we should allow user option to keep "global catalog"
        if [[ $ENABLE_PRIVATE_CATALOG -eq 0 && $UPGRADE_MODE == "shared2dedicated" ]]; then
            echo "${RED_TEXT}[WARNING]${RESET_TEXT}: ${YELLOW_TEXT}Before proceeding with the upgrade: if you have multiple CP4BA deployments on this cluster and you don't want them to be updated, please update installPlan approval for BTS, EDB PostgreSQL on the other CP4BA deployments from \"Automatic\" to \"Manual\".${RESET_TEXT}"
            read -rsn1 -p"Press any key to continue ...";echo
        fi
    fi

    # Create ibm-cp4ba-common-config configMap for this CP4BA deployment
    create_zen_yaml
    info "Creating ibm-cp4ba-common-config configMap for this CP4BA deployment in the project \"$TARGET_PROJECT_NAME\"."
    if [[ $UPGRADE_MODE == "shared2shared" ]]; then
        if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
            # ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"openshift-operators\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
            ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} data.operators_namespace "\"openshift-operators\""
        elif [[ $ALL_NAMESPACE_FLAG == "No" ]]; then
            # ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"ibm-common-services\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
             ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} data.operators_namespace "\"ibm-common-services\""
        fi
        # ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"ibm-common-services\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
        ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} data.services_namespace "\"ibm-common-services\""
    elif [[ $UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated" ]]; then
        # ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
        # ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
        ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} data.operators_namespace "\"$TARGET_PROJECT_NAME\""
        ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} data.services_namespace "\"$TARGET_PROJECT_NAME\""
    fi

    ${SED_COMMAND} "s|'\"|\"|g" ${UPGRADE_CS_ZEN_FILE}
    ${SED_COMMAND} "s|\"'|\"|g" ${UPGRADE_CS_ZEN_FILE}

    ${CLI_CMD} delete -f ${UPGRADE_CS_ZEN_FILE} -n $TARGET_PROJECT_NAME >/dev/null 2>&1
    ${CLI_CMD} apply -f ${UPGRADE_CS_ZEN_FILE} -n $TARGET_PROJECT_NAME >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        success "Created ibm-cp4ba-common-config configMap for this CP4BA deployment in the project \"$TARGET_PROJECT_NAME\"."
        sleep 3
    else
        warning "Failed to create ibm-cp4ba-common-config configMap for this CP4BA deployment in the project \"$TARGET_PROJECT_NAME\"!"
        exit 1
    fi

    # checking whether executed cp4a-pre-upgrade-and-post-upgrade-optional.sh
    # Retrieve existing Content CR
    ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        content_cr_name=$(${CLI_CMD} get content -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
        if [ ! -z $content_cr_name ]; then
            cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
            owner_ref=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
            
            if [[ ${owner_ref} != "ICP4ACluster" ]]; then
                CONTENT_CR_EXIST="Yes"
                css_flag=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.content_optional_components.css)
                css_flag=$(echo $css_flag | tr '[:upper:]' '[:lower:]')
            fi
        fi
    fi

    # Retrieve existing ICP4ACluster CR
    icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')

    if [ ! -z $icp4acluster_cr_name ]; then
        cr_metaname=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
        ${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml > ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        convert_olm_cr "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        if [[ $olm_cr_flag == "No" ]]; then
            existing_pattern_list=""
            existing_opt_component_list=""
            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
            existing_opt_component_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`
            OIFS=$IFS
            IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
            IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
            IFS=$OIFS
        fi
    fi

    if [[ $CONTENT_CR_EXIST == "Yes" || (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (! " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service")) || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
        info "Determining if the directory provider type is SCIM for Content Process Engine."
        ## Start up cp4a-operator/conent-operator for 
        ${CLI_CMD} scale --replicas=1 deployment ibm-cp4a-operator -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
        info "Waiting for ibm-cp4a-operator pod to be ready in the project \"$TEMP_OPERATOR_PROJECT_NAME\"."
        maxRetry=25
        for ((retry=0;retry<=${maxRetry};retry++)); do
            pod_name=$(${CLI_CMD} get pod -l=name=ibm-cp4a-operator -n $TEMP_OPERATOR_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
            if [[ -z $pod_name ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    printf "\n"
                    if [[ -z $pod_name ]]; then
                        warning "Timeout waiting for ibm-cp4a-operator pod to be ready in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    fi
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            else
                break
            fi
        done

        CONTENT_DEPLOYMENT_NAME=$(${CLI_CMD} get deployment ibm-content-operator --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME  -o name)
        if [[ ! -z $CONTENT_DEPLOYMENT_NAME ]]; then
            ${CLI_CMD} scale --replicas=1 deployment ibm-content-operator -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
            info "Waiting for ibm-content-operator pod to be ready in the project \"$TEMP_OPERATOR_PROJECT_NAME\"."
            maxRetry=25
            for ((retry=0;retry<=${maxRetry};retry++)); do
                pod_name=$(${CLI_CMD} get pod -l=name=ibm-content-operator -n $TEMP_OPERATOR_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [[ -z $pod_name ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                        printf "\n"
                        if [[ -z $pod_name ]]; then
                            warning "Timeout waiting for ibm-content-operator pod to be ready in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                        fi
                        exit 1
                    else
                        sleep 30
                        echo -n "..."
                        continue
                    fi
                else
                    break
                fi
            done
        fi
        is_scim_enabled
        if [[ $IS_SCIM_ENABLED == "True" ]]; then
          if [[ "$cp4a_operator_csv_version" == "21.3."* && $UPGRADE_MODE == "shared2dedicated" ]]; then
              printf "\n"
              echo -e "\x1B[33;5m[ATTENTION]: \x1B[0mYou ${RED_TEXT}DO NOT${RESET_TEXT} need to run the script ${YELLOW_TEXT}./cp4a-pre-upgrade-and-post-upgrade-optional.sh${RESET_TEXT} in ${YELLOW_TEXT}\"pre-upgrade\"${RESET_TEXT} mode when upgrade CP4BA from 21.0.3 to 24.0.0 (migrate IBM Cloud Pak foundational services from Cluster-scoped to Namespace-scoped)."
              read -rsn1 -p"Press any key to continue";echo
          fi
          if [[ "$cp4a_operator_csv_version" == "22.2."* && $UPGRADE_MODE == "shared2dedicated" ]]; then
              printf "\n"
              echo -e "\x1B[33;5m[ATTENTION]: \x1B[0mYou ${RED_TEXT}DO NOT${RESET_TEXT} need to run the script ${YELLOW_TEXT}./cp4a-pre-upgrade-and-post-upgrade-optional.sh${RESET_TEXT} in ${YELLOW_TEXT}\"pre-upgrade\"${RESET_TEXT} mode when upgrade CP4BA from 22.0.2 to 24.0.0 (migrate IBM Cloud Pak foundational services from Cluster-scoped to Namespace-scoped)."
              read -rsn1 -p"Press any key to continue";echo
          fi
          if [[ "$cp4a_operator_csv_version" == "23.2."* ]]; then
              printf "\n"
              echo -e "\x1B[33;5m[ATTENTION]: \x1B[0mYou ${RED_TEXT}DO NOT${RESET_TEXT} need to run the script ${YELLOW_TEXT}./cp4a-pre-upgrade-and-post-upgrade-optional.sh${RESET_TEXT} in ${YELLOW_TEXT}\"pre-upgrade\"${RESET_TEXT} mode when upgrade CP4BA from 23.0.2 to 24.0.0."
              read -rsn1 -p"Press any key to continue";echo
          fi
          if [[ "$cp4a_operator_csv_version" == "21.3."* || "$cp4a_operator_csv_version" == "22.2."* ]]; then
              if [[ $UPGRADE_MODE == "shared2shared" || $UPGRADE_MODE == "dedicated2dedicated" ]]; then
                  info "Checking whether executed \"./cp4a-pre-upgrade-and-post-upgrade-optional.sh pre-upgrade\""
                  if [[ $UPGRADE_MODE == "shared2shared" ]]; then
                      info "Checking whether cp-console-iam-provider/cp-console-iam-idmgmt routes exist in the project \"ibm-common-services\"."
                      iam_provider=$(${CLI_CMD} get route cp-console-iam-provider --no-headers --ignore-not-found -n ibm-common-services -o 'jsonpath={.metadata.name}') >/dev/null 2>&1
                      iam_idmgmt=$(${CLI_CMD} get route cp-console-iam-idmgmt --no-headers --ignore-not-found -n ibm-common-services -o 'jsonpath={.metadata.name}') >/dev/null 2>&1
                      if [[ "${iam_provider}" == "cp-console-iam-provider" && "${iam_idmgmt}" == "cp-console-iam-idmgmt" ]]; then
                          success "Found cp-console-iam-provider/cp-console-iam-idmgmt routes in the project \"ibm-common-services\"."
                      else
                          error "Not found cp-console-iam-provider/cp-console-iam-idmgmt routes in the project \"ibm-common-services\", you NEED to run \"./cp4a-pre-upgrade-and-post-upgrade-optional.sh pre-upgrade\" first, and then RERUN \"./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME\"."
                          exit 1
                      fi
                  elif [[ $UPGRADE_MODE == "dedicated2dedicated" ]]; then
                      info "Checking whether cp-console-iam-provider/cp-console-iam-idmgmt routes exist in the project \"$TARGET_PROJECT_NAME\"."
                      iam_provider=$(${CLI_CMD} get route cp-console-iam-provider --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o 'jsonpath={.metadata.name}') >/dev/null 2>&1
                      iam_idmgmt=$(${CLI_CMD} get route cp-console-iam-idmgmt --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o 'jsonpath={.metadata.name}') >/dev/null 2>&1
                      if [[ "${iam_provider}" == "cp-console-iam-provider" && "${iam_idmgmt}" == "cp-console-iam-idmgmt" ]]; then
                          success "Found cp-console-iam-provider/cp-console-iam-idmgmt routes in the project \"$TARGET_PROJECT_NAME\"."
                      else
                          error "Not found cp-console-iam-provider/cp-console-iam-idmgmt routes in the project \"$TARGET_PROJECT_NAME\", you NEED to run \"./cp4a-pre-upgrade-and-post-upgrade-optional.sh pre-upgrade\" first, and then RERUN \"./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME\"."
                          exit 1
                      fi
                  fi
              fi
              printf "\n"
              # post-upgrade mode requird for all CPfs migration mode
              echo -e "\x1B[33;5m[ATTENTION]: \x1B[0mAfter upgrading IBM Cloud Pak for Business Automation deployment, you ${RED_TEXT}NEED${RESET_TEXT} to run the script ${YELLOW_TEXT}./cp4a-pre-upgrade-and-post-upgrade-optional.sh${RESET_TEXT} in ${YELLOW_TEXT}\"post-upgrade\"${RESET_TEXT} mode."
              read -rsn1 -p"Press any key to continue";echo
          elif [[ $UPGRADE_MODE == "shared2dedicated" && "$cp4a_operator_csv_version" == "23.2."* ]]; then
              printf "\n"
              echo -e "\x1B[33;5m[ATTENTION]: \x1B[0mAfter upgrading IBM Cloud Pak for Business Automation, you ${RED_TEXT}NEED${RESET_TEXT} to run the script ${YELLOW_TEXT}./cp4a-pre-upgrade-and-post-upgrade-optional.sh${RESET_TEXT} in ${YELLOW_TEXT}\"post-upgrade\"${RESET_TEXT} mode."
              read -rsn1 -p"Press any key to continue";echo
          fi
        fi
    fi

    # if [[ "$cp4a_operator_csv_version" == "${CP4BA_CSV_VERSION//v/}" ]]; then
    #     warning "The CP4BA operator already is $CP4BA_CSV_VERSION."
    #     printf "\n"
    #     while true; do
    #         printf "\x1B[1mDo you want to continue to do upgrade? (Yes/No, default: No): \x1B[0m"
    #         read -rp "" ans
    #         case "$ans" in
    #         "y"|"Y"|"yes"|"Yes"|"YES")
    #             echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again."
    #             echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
    #             echo "           Usage:"
    #             echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
    #             echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
    #             echo "           Example command: "
    #             echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
    #             exit 1
    #             ;;
    #         "n"|"N"|"no"|"No"|"NO"|"")
    #             echo "Exiting..."
    #             exit 1
    #             ;;
    #         *)
    #             echo -e "Answer must be \"Yes\" or \"No\"\n"
    #             ;;
    #         esac
    #     done
    # fi

    # Checking CSV for cp4ba-operator/content-operator/bai-operator to decide whether to do BAI save point during IFIX to IFIX upgrade
    sub_inst_list=$(${CLI_CMD} get subscriptions.operators.coreos.com -n $TEMP_OPERATOR_PROJECT_NAME|grep ibm-cp4a-operator-catalog|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
    if [[ -z $sub_inst_list ]]; then
        info "Not found any existing CP4BA subscriptions, continue ..."
        # exit 1
    fi
    sub_array=($sub_inst_list)
    target_csv_version=${CP4BA_CSV_VERSION//v/}
    for i in ${!sub_array[@]}; do
        if [[ ! -z "${sub_array[i]}" ]]; then
            if [[ ${sub_array[i]} = ibm-cp4a-operator* || ${sub_array[i]} = ibm-content-operator* || ${sub_array[i]} = ibm-insights-engine-operator* ]]; then
                current_version=$(${CLI_CMD} get subscriptions.operators.coreos.com ${sub_array[i]} --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                installed_version=$(${CLI_CMD} get subscriptions.operators.coreos.com ${sub_array[i]} --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                if [[ -z $current_version || -z $installed_version ]]; then
                    error "fail to get installed or current CSV, abort the upgrade procedure. Please check ${sub_array[i]} subscription status."
                    exit 1
                fi
                case "${sub_array[i]}" in
                "ibm-cp4a-operator"*)
                    prefix_sub="ibm-cp4a-operator.v"
                    ;;
                "ibm-content-operator"*)
                    prefix_sub="ibm-content-operator.v"
                    ;;
                "ibm-insights-engine-operator"*)
                    prefix_sub="ibm-insights-engine-operator.v"
                    ;;
                esac
                current_version=${current_version#"$prefix_sub"}
                installed_version=${installed_version#"$prefix_sub"}
                if [[ $current_version != $installed_version || $current_version != $target_csv_version || $installed_version != $target_csv_version ]]; then
                    RUN_BAI_SAVEPOINT="Yes"
                fi
            fi
        else
            fail "No found subscription '${sub_array[i]}'! exiting now..."
            exit 1
        fi
    done


    # In 24.0.0, only merge bai.json into yaml but not call savepoint RestAPI because that savepoint should be done during migration from ES to OS
    if [[ $RERUN_UPGRADE_DEPLOYMENT == "Yes" ]]; then
        RUN_BAI_SAVEPOINT="Yes"
    fi
    if [[ $RUN_BAI_SAVEPOINT == "Yes" ]]; then
        ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            content_cr_name=$(${CLI_CMD} get content -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
            if [ ! -z $content_cr_name ]; then
                info "Retrieving existing CP4BA Content (Kind: content.icp4a.ibm.com) Custom Resource"
                cr_type="content"
                cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
                owner_ref=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)

                if [[ ${owner_ref} != "ICP4ACluster" ]]; then
                    ${CLI_CMD} get $cr_type $content_cr_name -n $TARGET_PROJECT_NAME -o yaml > ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

                    # Backup existing content CR
                    mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK} >/dev/null 2>&1
                    ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_CONTENT_CR_BAK}

                    mkdir -p ${TEMP_FOLDER} >/dev/null 2>&1
                    bai_flag=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP | ${YQ_CMD} r - spec.content_optional_components.bai`
                    if [[ $bai_flag == "True" || $bai_flag == "true" ]]; then
                        if [[ "$machine" == "Mac" ]]; then
                            which jq &>/dev/null
                            [[ $? -ne 0 ]] && \
                            echo -e  "\x1B[1;31mUnable to locate an jq CLI. You must install it to run this script on MacOS.\x1B[0m" && \
                            exit 1
                        fi

                        if [[ -e ${UPGRADE_DEPLOYMENT_CR}/bai.json ]]; then
                            # Check if bai.json is empty
                            info "Found the Flink savepoint in the temp file \"${UPGRADE_DEPLOYMENT_CR}/bai.json\""
                            info "Starting to parse and merge into temp custom resource file \"${UPGRADE_DEPLOYMENT_BAI_TMP}\""
                            touch ${UPGRADE_DEPLOYMENT_BAI_TMP} >/dev/null 2>&1
                            if [[ -e ${UPGRADE_DEPLOYMENT_CR}/bai.json ]]; then
                                [ "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" != "[]" ] && mkdir -p ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup && cp ${UPGRADE_DEPLOYMENT_CR}/bai.json ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup/bai_$(date +'%Y%m%d%H%M%S').json
                            fi
                            # json_file_content="[]"
                            if [ "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" == "[]" ] ;then
                                warning "Please fetch Flink job savepoints for recovery path using above REST API manually, and then put JSON file (bai.json) under the directory \"${TEMP_FOLDER}/\""
                            else
                                ##########################################################################################################################
                                ## From 24.0.0, the content and event-forwarder do not need recovery_path for flink savepoint after migration from es to op
                                ##########################################################################################################################
                                # if [[ "$machine" == "Mac" ]]; then
                                #     tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-event-forwarder)
                                # else
                                #     tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-event-forwarder |cut -d':' -f2)
                                # fi
                                # tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                # if [ ! -z "$tmp_recovery_path" ]; then
                                #     ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.event-forwarder.recovery_path ${tmp_recovery_path}
                                #     success "Create savepoint for Event-forwarder: \"$tmp_recovery_path\""
                                #     info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.event-forwarder.recovery_path."
                                # fi
                                # if [[ "$machine" == "Mac" ]]; then
                                #     tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-content)
                                # else
                                #     tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-content |cut -d':' -f2)
                                # fi
                                # tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                # if [ ! -z "$tmp_recovery_path" ]; then
                                #     ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.content.recovery_path ${tmp_recovery_path}
                                #     success "Merged Flink savepoint for Content: \"$tmp_recovery_path\""
                                #     info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.content.recovery_path."
                                # fi
                                if [[ "$machine" == "Mac" ]]; then
                                    tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-icm)
                                else
                                    tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-icm |cut -d':' -f2)
                                fi
                                tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                if [ ! -z "$tmp_recovery_path" ]; then
                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.icm.recovery_path ${tmp_recovery_path}
                                    success "Merged Flink savepoint for ICM: \"$tmp_recovery_path\" into \"${UPGRADE_DEPLOYMENT_BAI_TMP}\""
                                    info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.icm.recovery_path."
                                fi
                                if [[ "$machine" == "Mac" ]]; then
                                    tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-odm)
                                else
                                    tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-odm |cut -d':' -f2)
                                fi
                                tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                if [ ! -z "$tmp_recovery_path" ]; then
                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.odm.recovery_path ${tmp_recovery_path}
                                    success "Merged Flink savepoint for ODM: \"$tmp_recovery_path\" into \"${UPGRADE_DEPLOYMENT_BAI_TMP}\""
                                    info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.odm.recovery_path."
                                fi
                                if [[ "$machine" == "Mac" ]]; then
                                    tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-bawadv)
                                else
                                    tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-bawadv |cut -d':' -f2)
                                fi
                                tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                if [ ! -z "$tmp_recovery_path" ]; then
                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.bawadv.recovery_path ${tmp_recovery_path}
                                    success "Merged Flink savepoint for BAW ADV: \"$tmp_recovery_path\" into \"${UPGRADE_DEPLOYMENT_BAI_TMP}\""
                                    info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.bawadv.recovery_path."
                                fi
                                if [[ "$machine" == "Mac" ]]; then
                                    tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-bpmn)
                                else
                                    tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-bpmn |cut -d':' -f2)
                                fi
                                tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                if [ ! -z "$tmp_recovery_path" ]; then
                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.bpmn.recovery_path ${tmp_recovery_path}
                                    success "Merged Flink savepoint for BPMN: \"$tmp_recovery_path\" into \"${UPGRADE_DEPLOYMENT_BAI_TMP}\""
                                    info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.bpmn.recovery_path."
                                fi
                            fi
                        else
                            fail "Not found \"${UPGRADE_DEPLOYMENT_CR}/bai.json\" for Flink savepoint."
                            msg "Please fetch Flink job savepoints for recovery path using above REST API manually, and then put JSON file (bai.json) under the directory \"${TEMP_FOLDER}/\""
                        fi
                    fi
                fi
            fi
        fi

        # Retrieve existing ICP4ACluster CR for Create BAI save points
        icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
        if [ ! -z $icp4acluster_cr_name ]; then
            info "Retrieving existing CP4BA ICP4ACluster (Kind: icp4acluster.icp4a.ibm.com) Custom Resource"
            cr_type="icp4acluster"
            cr_metaname=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
            ${CLI_CMD} get $cr_type $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml > ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

            # Backup existing icp4acluster CR
            mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK}


            convert_olm_cr "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
            if [[ $olm_cr_flag == "No" ]]; then
                # Get EXISTING_PATTERN_ARR/EXISTING_OPT_COMPONENT_ARR
                existing_pattern_list=""
                existing_opt_component_list=""

                EXISTING_PATTERN_ARR=()
                EXISTING_OPT_COMPONENT_ARR=()
                existing_pattern_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
                existing_opt_component_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`

                OIFS=$IFS
                IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
                IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
                IFS=$OIFS
            fi

            # Check BAI save points json
            mkdir -p ${TEMP_FOLDER} >/dev/null 2>&1
            if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") ]]; then
                # Check the jq install on MacOS
                if [[ "$machine" == "Mac" ]]; then
                    which jq &>/dev/null
                    [[ $? -ne 0 ]] && \
                    echo -e  "\x1B[1;31mUnable to locate an jq CLI. You must install it to run this script on MacOS.\x1B[0m" && \
                    exit 1
                fi

                if [[ -e ${UPGRADE_DEPLOYMENT_CR}/bai.json ]]; then
                    info "Found the Flink savepoint in the temp file \"${UPGRADE_DEPLOYMENT_CR}/bai.json\""
                    info "Starting to parse and merge into temp custom resource file \"${UPGRADE_DEPLOYMENT_BAI_TMP}\""
                    touch ${UPGRADE_DEPLOYMENT_BAI_TMP} >/dev/null 2>&1
                    if [[ -e ${UPGRADE_DEPLOYMENT_CR}/bai.json ]]; then
                        [ "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" != "[]" ] && mkdir -p ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup && cp ${UPGRADE_DEPLOYMENT_CR}/bai.json ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup/bai_$(date +'%Y%m%d%H%M%S').json
                    fi
                    # json_file_content="[]"
                    if [ "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" == "[]" ] ;then
                        warning "Please fetch Flink job savepoints for recovery path using above REST API manually, and then put JSON file (bai.json) under the directory \"${TEMP_FOLDER}/\""
                    else
                        # if [[ "$machine" == "Mac" ]]; then
                        #     tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-event-forwarder)
                        # else
                        #     tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-event-forwarder |cut -d':' -f2)
                        # fi
                        # tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        # if [ ! -z "$tmp_recovery_path" ]; then
                        #     ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.event-forwarder.recovery_path ${tmp_recovery_path}
                        #     success "Create savepoint for Event-forwarder: \"$tmp_recovery_path\""
                        #     info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.event-forwarder.recovery_path."
                        # fi
                        # if [[ "$machine" == "Mac" ]]; then
                        #     tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-content)
                        # else
                        #     tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-content |cut -d':' -f2)
                        # fi
                        # tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        # if [ ! -z "$tmp_recovery_path" ]; then
                        #     ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.content.recovery_path ${tmp_recovery_path}
                        #     success "Merged Flink savepoint for Content: \"$tmp_recovery_path\""
                        #     info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.content.recovery_path."
                        # fi

                        if [[ "$machine" == "Mac" ]]; then
                            tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-icm)
                        else
                            tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-icm |cut -d':' -f2)
                        fi
                        tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        if [ ! -z "$tmp_recovery_path" ]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.icm.recovery_path ${tmp_recovery_path}
                            success "Merged Flink savepoint for ICM: \"$tmp_recovery_path\" into \"${UPGRADE_DEPLOYMENT_BAI_TMP}\""
                            info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.icm.recovery_path."
                        fi

                        if [[ "$machine" == "Mac" ]]; then
                            tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-odm)
                        else
                            tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-odm |cut -d':' -f2)
                        fi
                        tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        if [ ! -z "$tmp_recovery_path" ]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.odm.recovery_path ${tmp_recovery_path}
                            success "Merged Flink savepoint for ODM: \"$tmp_recovery_path\" into \"${UPGRADE_DEPLOYMENT_BAI_TMP}\""
                            info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.odm.recovery_path."
                        fi

                        if [[ "$machine" == "Mac" ]]; then
                            tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-bawadv)
                        else
                            tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-bawadv |cut -d':' -f2)
                        fi
                        tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        if [ ! -z "$tmp_recovery_path" ]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.bawadv.recovery_path ${tmp_recovery_path}
                            success "Merged Flink savepoint for BAW ADV: \"$tmp_recovery_path\" into \"${UPGRADE_DEPLOYMENT_BAI_TMP}\""
                            info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.bawadv.recovery_path."
                        fi

                        if [[ "$machine" == "Mac" ]]; then
                            tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-bpmn)
                        else
                            tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-bpmn |cut -d':' -f2)
                        fi
                        tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        if [ ! -z "$tmp_recovery_path" ]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.bpmn.recovery_path ${tmp_recovery_path}
                            success "Merged Flink savepoint for BPMN: \"$tmp_recovery_path\" into \"${UPGRADE_DEPLOYMENT_BAI_TMP}\""
                            info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.bpmn.recovery_path."
                        fi
                    fi
                else
                    fail "Not found \"${UPGRADE_DEPLOYMENT_CR}/bai.json\" for Flink savepoint."
                    msg "Please fetch Flink job savepoints for recovery path using above REST API manually, and then put JSON file (bai.json) under the directory \"${TEMP_FOLDER}/\""
               fi
            fi
        fi
    fi
    # In 24.0.0, follow the flow of migration from  Elasticsearch to Opensearch, the bai savepoint creation already done before upgrade CP4BA
    # So do not rerun savepoint. But need to covert bai json into UPGRADE_DEPLOYMENT_BAI_TMP for next upgradeDeployment mode.
    # Keep below logic for future IFIX to IFX upgrade
    RUN_BAI_SAVEPOINT="No"
    if [[ $RUN_BAI_SAVEPOINT == "Yes" ]]; then
        # Retrieve existing Content CR for Create BAI save points
        ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            content_cr_name=$(${CLI_CMD} get content -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
            if [ ! -z $content_cr_name ]; then
                info "Retrieving existing CP4BA Content (Kind: content.icp4a.ibm.com) Custom Resource"
                cr_type="content"
                cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
                owner_ref=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
                if [[ ${owner_ref} == "ICP4ACluster" ]]; then
                    echo
                else
                    ${CLI_CMD} get $cr_type $content_cr_name -n $TARGET_PROJECT_NAME -o yaml > ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

                    # Backup existing content CR
                    mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK} >/dev/null 2>&1
                    ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_CONTENT_CR_BAK}

                    # Create BAI save points
                    info "Checking whether BAI install in this CP4BA deployment."

                    mkdir -p ${TEMP_FOLDER} >/dev/null 2>&1
                    bai_flag=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP | ${YQ_CMD} r - spec.content_optional_components.bai`
                    if [[ $bai_flag == "True" || $bai_flag == "true" ]]; then
                        info "Found BAI installed in this CP4BA deployment."
                        # Check the jq install on MacOS
                        if [[ "$machine" == "Mac" ]]; then
                            which jq &>/dev/null
                            [[ $? -ne 0 ]] && \
                            echo -e  "\x1B[1;31mUnable to locate an jq CLI. You must install it to run this script on MacOS.\x1B[0m" && \
                            exit 1
                        fi

                        info "Create the BAI savepoints for recovery path when merge custom resource"
                        ${CLI_CMD} get crd |grep insightsengines.icp4a.ibm.com >/dev/null 2>&1
                        if [ $? -eq 0 ]; then
                            INSIGHTS_ENGINE_CR=$(${CLI_CMD} get insightsengines.icp4a.ibm.com --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o name)
                        fi
                        if [[ -z $INSIGHTS_ENGINE_CR ]]; then
                            INSIGHTS_ENGINE_CR=$(${CLI_CMD} get insightsengines.insightsengine.automation.ibm.com --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o name)
                            if [[ -z $INSIGHTS_ENGINE_CR ]]; then
                                error "Not found insightsengines custom resource instance in the project \"${TARGET_PROJECT_NAME}\"."
                            fi
                            # exit 1
                        fi
                        if [[ ! -z $INSIGHTS_ENGINE_CR ]]; then
                            MANAGEMENT_URL=$(${CLI_CMD} get ${INSIGHTS_ENGINE_CR} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].uri}')
                            MANAGEMENT_AUTH_SECRET=$(${CLI_CMD} get ${INSIGHTS_ENGINE_CR} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].authentication.secret.secretName}')
                            MANAGEMENT_USERNAME=$(${CLI_CMD} get secret ${MANAGEMENT_AUTH_SECRET} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.data.username}' | base64 -d)
                            MANAGEMENT_PASSWORD=$(${CLI_CMD} get secret ${MANAGEMENT_AUTH_SECRET} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.data.password}' | base64 -d)
                            if [[ -z "$MANAGEMENT_URL" || -z "$MANAGEMENT_AUTH_SECRET" || -z "$MANAGEMENT_USERNAME" || -z "$MANAGEMENT_PASSWORD" ]]; then
                                error "Can not create the BAI savepoints for recovery path."
                                # exit 1
                            else
                                # rm -rf ${UPGRADE_DEPLOYMENT_CR}/bai.json >/dev/null 2>&1
                                touch ${UPGRADE_DEPLOYMENT_BAI_TMP} >/dev/null 2>&1
                                if [[ -e ${UPGRADE_DEPLOYMENT_CR}/bai.json ]]; then
                                    [ "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" != "[]" ] && mkdir -p ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup && cp ${UPGRADE_DEPLOYMENT_CR}/bai.json ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup/bai_$(date +'%Y%m%d%H%M%S').json
                                fi
                                curl -X POST -k -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} "${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints" -o ${UPGRADE_DEPLOYMENT_CR}/bai.json >/dev/null 2>&1

                                json_file_content="[]"
                                if [ "$json_file_content" == "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" ] ;then
                                    fail "None return in \"${UPGRADE_DEPLOYMENT_CR}/bai.json\" when request BAI savepoint through REST API: curl -X POST -k -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} \"${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints\" "
                                    warning "Please fetch Flink job savepoints for recovery path using above REST API manually, and then put JSON file (bai.json) under the directory \"${TEMP_FOLDER}/\""
                                    read -rsn1 -p"Press any key to continue";echo
                                fi

                                # if [[ "$machine" == "Mac" ]]; then
                                #     tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-event-forwarder)
                                # else
                                #     tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-event-forwarder |cut -d':' -f2)
                                # fi
                                # tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                # if [ ! -z "$tmp_recovery_path" ]; then
                                #     ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.event-forwarder.recovery_path ${tmp_recovery_path}
                                #     success "Create savepoint for Event-forwarder: \"$tmp_recovery_path\""
                                #     info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.event-forwarder.recovery_path."
                                # fi
                                # if [[ "$machine" == "Mac" ]]; then
                                #     tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-content)
                                # else
                                #     tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-content |cut -d':' -f2)
                                # fi
                                # tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                # if [ ! -z "$tmp_recovery_path" ]; then
                                #     ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.content.recovery_path ${tmp_recovery_path}
                                #     success "Merged Flink savepoint for Content: \"$tmp_recovery_path\""
                                #     info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.content.recovery_path."
                                # fi
                                if [[ "$machine" == "Mac" ]]; then
                                    tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-icm)
                                else
                                    tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-icm |cut -d':' -f2)
                                fi
                                tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                if [ ! -z "$tmp_recovery_path" ]; then
                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.icm.recovery_path ${tmp_recovery_path}
                                    success "Merged Flink savepoint for ICM: \"$tmp_recovery_path\""
                                    info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.icm.recovery_path."
                                fi
                                if [[ "$machine" == "Mac" ]]; then
                                    tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-odm)
                                else
                                    tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-odm |cut -d':' -f2)
                                fi
                                tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                if [ ! -z "$tmp_recovery_path" ]; then
                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.odm.recovery_path ${tmp_recovery_path}
                                    success "Merged Flink savepoint for ODM: \"$tmp_recovery_path\""
                                    info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.odm.recovery_path."
                                fi
                                if [[ "$machine" == "Mac" ]]; then
                                    tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-bawadv)
                                else
                                    tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-bawadv |cut -d':' -f2)
                                fi
                                tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                if [ ! -z "$tmp_recovery_path" ]; then
                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.bawadv.recovery_path ${tmp_recovery_path}
                                    success "Merged Flink savepoint for BAW ADV: \"$tmp_recovery_path\""
                                    info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.bawadv.recovery_path."
                                fi
                                if [[ "$machine" == "Mac" ]]; then
                                    tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-bpmn)
                                else
                                    tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-bpmn |cut -d':' -f2)
                                fi
                                tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")

                                if [ ! -z "$tmp_recovery_path" ]; then
                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.bpmn.recovery_path ${tmp_recovery_path}
                                    success "Merged Flink savepoint for BPMN: \"$tmp_recovery_path\""
                                    info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.bpmn.recovery_path."
                                fi
                            fi
                        fi
                    fi
                fi
            fi
        fi

        # Retrieve existing ICP4ACluster CR for Create BAI save points
        icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
        if [ ! -z $icp4acluster_cr_name ]; then
            info "Retrieving existing CP4BA ICP4ACluster (Kind: icp4acluster.icp4a.ibm.com) Custom Resource"
            cr_type="icp4acluster"
            cr_metaname=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
            ${CLI_CMD} get $cr_type $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml > ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

            # Backup existing icp4acluster CR
            mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK}

            convert_olm_cr "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
            if [[ $olm_cr_flag == "No" ]]; then
                # Get EXISTING_PATTERN_ARR/EXISTING_OPT_COMPONENT_ARR
                existing_pattern_list=""
                existing_opt_component_list=""

                EXISTING_PATTERN_ARR=()
                EXISTING_OPT_COMPONENT_ARR=()
                existing_pattern_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
                existing_opt_component_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`

                OIFS=$IFS
                IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
                IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
                IFS=$OIFS
            fi

            # Create BAI save points
            info "Checking whether BAI install in this CP4BA deployment."
            mkdir -p ${TEMP_FOLDER} >/dev/null 2>&1
            if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") ]]; then
                info "Found BAI installed in this CP4BA deployment."
                # Check the jq install on MacOS
                if [[ "$machine" == "Mac" ]]; then
                    which jq &>/dev/null
                    [[ $? -ne 0 ]] && \
                    echo -e  "\x1B[1;31mUnable to locate an jq CLI. You must install it to run this script on MacOS.\x1B[0m" && \
                    exit 1
                fi
                info "Create the BAI savepoints for recovery path when merge custom resource"
                ${CLI_CMD} get crd |grep insightsengines.icp4a.ibm.com >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    INSIGHTS_ENGINE_CR=$(${CLI_CMD} get insightsengines.icp4a.ibm.com --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o name)
                fi
                if [[ -z $INSIGHTS_ENGINE_CR ]]; then
                    INSIGHTS_ENGINE_CR=$(${CLI_CMD} get insightsengines.insightsengine.automation.ibm.com --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o name)
                    if [[ -z $INSIGHTS_ENGINE_CR ]]; then
                        error "Not found insightsengines custom resource instance in the project \"${TARGET_PROJECT_NAME}\"."
                    fi
                    # exit 1
                fi
                if [[ ! -z $INSIGHTS_ENGINE_CR ]]; then
                    MANAGEMENT_URL=$(${CLI_CMD} get ${INSIGHTS_ENGINE_CR} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].uri}')
                    MANAGEMENT_AUTH_SECRET=$(${CLI_CMD} get ${INSIGHTS_ENGINE_CR} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].authentication.secret.secretName}')
                    MANAGEMENT_USERNAME=$(${CLI_CMD} get secret ${MANAGEMENT_AUTH_SECRET} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.data.username}' | base64 -d)
                    MANAGEMENT_PASSWORD=$(${CLI_CMD} get secret ${MANAGEMENT_AUTH_SECRET} --no-headers --ignore-not-found -n ${TARGET_PROJECT_NAME} -o jsonpath='{.data.password}' | base64 -d)
                    if [[ -z "$MANAGEMENT_URL" || -z "$MANAGEMENT_AUTH_SECRET" || -z "$MANAGEMENT_USERNAME" || -z "$MANAGEMENT_PASSWORD" ]]; then
                        error "Can not create the BAI savepoints for recovery path."
                        # exit 1
                    else
                        # rm -rf ${UPGRADE_DEPLOYMENT_CR}/bai.json >/dev/null 2>&1
                        touch ${UPGRADE_DEPLOYMENT_BAI_TMP} >/dev/null 2>&1
                        if [[ -e ${UPGRADE_DEPLOYMENT_CR}/bai.json ]]; then
                            [ "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" != "[]" ] && mkdir -p ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup && cp ${UPGRADE_DEPLOYMENT_CR}/bai.json ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup/bai_$(date +'%Y%m%d%H%M%S').json
                        fi
                        curl -X POST -k -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} "${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints" -o ${UPGRADE_DEPLOYMENT_CR}/bai.json >/dev/null 2>&1

                        json_file_content="[]"
                        if [ "$json_file_content" == "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" ] ;then
                            fail "None return in \"${UPGRADE_DEPLOYMENT_CR}/bai.json\" when request BAI savepoint through REST API: curl -X POST -k -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} \"${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints\" "
                            warning "Please fetch Flink job savepoints for recovery path using above REST API manually, and then put JSON file (bai.json) under the directory \"${TEMP_FOLDER}/\""
                            read -rsn1 -p"Press any key to continue";echo
                        fi

                        # if [[ "$machine" == "Mac" ]]; then
                        #     tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-event-forwarder)
                        # else
                        #     tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-event-forwarder |cut -d':' -f2)
                        # fi
                        # tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        # if [ ! -z "$tmp_recovery_path" ]; then
                        #     ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.event-forwarder.recovery_path ${tmp_recovery_path}
                        #     success "Create savepoint for Event-forwarder: \"$tmp_recovery_path\""
                        #     info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.event-forwarder.recovery_path."
                        # fi
                        # if [[ "$machine" == "Mac" ]]; then
                        #     tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-content)
                        # else
                        #     tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-content |cut -d':' -f2)
                        # fi
                        # tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        # if [ ! -z "$tmp_recovery_path" ]; then
                        #     ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.content.recovery_path ${tmp_recovery_path}
                        #     success "Merged Flink savepoint for Content: \"$tmp_recovery_path\""
                        #     info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.content.recovery_path."
                        # fi

                        if [[ "$machine" == "Mac" ]]; then
                            tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-icm)
                        else
                            tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-icm |cut -d':' -f2)
                        fi
                        tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        if [ ! -z "$tmp_recovery_path" ]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.icm.recovery_path ${tmp_recovery_path}
                            success "Merged Flink savepoint for ICM: \"$tmp_recovery_path\""
                            info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.icm.recovery_path."
                        fi

                        if [[ "$machine" == "Mac" ]]; then
                            tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-odm)
                        else
                            tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-odm |cut -d':' -f2)
                        fi
                        tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        if [ ! -z "$tmp_recovery_path" ]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.odm.recovery_path ${tmp_recovery_path}
                            success "Merged Flink savepoint for ODM: \"$tmp_recovery_path\""
                            info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.odm.recovery_path."
                        fi

                        if [[ "$machine" == "Mac" ]]; then
                            tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-bawadv)
                        else
                            tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-bawadv |cut -d':' -f2)
                        fi
                        tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        if [ ! -z "$tmp_recovery_path" ]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.bawadv.recovery_path ${tmp_recovery_path}
                            success "Merged Flink savepoint for BAW ADV: \"$tmp_recovery_path\""
                            info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.bawadv.recovery_path."
                        fi

                        if [[ "$machine" == "Mac" ]]; then
                            tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep bai-bpmn)
                        else
                            tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep bai-bpmn |cut -d':' -f2)
                        fi
                        tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
                        if [ ! -z "$tmp_recovery_path" ]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_BAI_TMP} spec.bai_configuration.bpmn.recovery_path ${tmp_recovery_path}
                            success "Merged Flink savepoint for BPMN: \"$tmp_recovery_path\""
                            info "When run \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.bpmn.recovery_path."
                        fi
                    fi
                fi
            fi
        fi
    fi

    if [[ "$PLATFORM_SELECTED" == "others" ]]; then
        [ -f ${UPGRADE_DEPLOYMENT_FOLDER}/upgradeOperator.yaml ] && rm ${UPGRADE_DEPLOYMENT_FOLDER}/upgradeOperator.yaml
        cp ${CUR_DIR}/../descriptors/operator.yaml ${UPGRADE_DEPLOYMENT_FOLDER}/upgradeOperator.yaml
        cncf_install
    else
        #  Switch CP4BA Operator to private catalog source
        if [ $ENABLE_PRIVATE_CATALOG -eq 1 ]; then
            # switch CP4BA
            sub_inst_list=$(${CLI_CMD} get subscriptions.operators.coreos.com -n $TARGET_PROJECT_NAME|grep ibm-cp4a-operator-catalog|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
            if [[ -z $sub_inst_list ]]; then
                info "Not found any existing CP4BA subscriptions, continue ..."
                # exit 1
            fi

            sub_array=($sub_inst_list)
            for i in ${!sub_array[@]}; do
                if [[ ! -z "${sub_array[i]}" ]]; then
                    if [[ ${sub_array[i]} = ibm-cp4a-operator* || ${sub_array[i]} = ibm-cp4a-wfps-operator* || ${sub_array[i]} = ibm-content-operator* || ${sub_array[i]} = icp4a-foundation-operator* || ${sub_array[i]} = ibm-pfs-operator* || ${sub_array[i]} = ibm-ads-operator* || ${sub_array[i]} = ibm-dpe-operator* || ${sub_array[i]} = ibm-odm-operator* || ${sub_array[i]} = ibm-insights-engine-operator* ]]; then
                        ${CLI_CMD} patch subscriptions.operators.coreos.com ${sub_array[i]} -n $TARGET_PROJECT_NAME -p '{"spec":{"sourceNamespace":"'"$TARGET_PROJECT_NAME"'"}}' --type=merge >/dev/null 2>&1
                        if [ $? -eq 0 ]
                        then
                            sleep 1
                            success "Switched the CatalogSource of subscription '${sub_array[i]}' to project \"$TARGET_PROJECT_NAME\"!"
                            printf "\n"
                        else
                            fail "Failed to switch the CatalogSource of subscription '${sub_array[i]}' to project \"$TARGET_PROJECT_NAME\"!"
                        fi
                    fi
                else
                    fail "No found subscription '${sub_array[i]}' in the project \"$TARGET_PROJECT_NAME\"! exiting now..."
                    exit 1
                fi
            done
        fi

        #  Patch CP4BA channel to latest version, wait for all the operators are upgraded before applying operandRequest.
        sub_inst_list=$(${CLI_CMD} get subscriptions.operators.coreos.com -n $TEMP_OPERATOR_PROJECT_NAME|grep ibm-cp4a-operator-catalog|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
        if [[ -z $sub_inst_list ]]; then
            info "Not found any existing CP4BA subscriptions, continue ..."
            # exit 1
        fi

        sub_array=($sub_inst_list)
        for i in ${!sub_array[@]}; do
            if [[ ! -z "${sub_array[i]}" ]]; then
                if [[ ${sub_array[i]} = ibm-cp4a-operator* || ${sub_array[i]} = ibm-cp4a-wfps-operator* || ${sub_array[i]} = ibm-content-operator* || ${sub_array[i]} = icp4a-foundation-operator* || ${sub_array[i]} = ibm-pfs-operator* || ${sub_array[i]} = ibm-ads-operator* || ${sub_array[i]} = ibm-dpe-operator* || ${sub_array[i]} = ibm-odm-operator* || ${sub_array[i]} = ibm-insights-engine-operator* || ${sub_array[i]} = ibm-workflow-operator* ]]; then
                    ${CLI_CMD} patch subscriptions.operators.coreos.com ${sub_array[i]} -n $TEMP_OPERATOR_PROJECT_NAME -p '{"spec":{"channel":"v24.0"}}' --type=merge >/dev/null 2>&1
                    if [ $? -eq 0 ]
                    then
                        success "Updated the channel of subscription '${sub_array[i]}' to $CP4BA_CHANNEL_VERSION"
                        printf "\n"
                    else
                        fail "Failed to update the channel of subscription '${sub_array[i]}' to $CP4BA_CHANNEL_VERSION! exiting now..."
                        exit 1
                    fi
                fi
            else
                fail "No found subscription '${sub_array[i]}'! exiting now..."
                exit 1
            fi
        done

        success "Completed to switch the channel of subscription for CP4BA operators"

        # Apply the new catalog source

        if [[ ($CATALOG_FOUND == "Yes" && $PINNED == "Yes") || $PRIVATE_CATALOG_FOUND == "Yes" ]]; then
            # switch catalog from "global" to "namespace" catalog or keep private catalog source
            if [ $ENABLE_PRIVATE_CATALOG -eq 1 ]; then
                TEMP_CATALOG_PROJECT_NAME=${TARGET_PROJECT_NAME}
                OLM_CATALOG=${PARENT_DIR}/descriptors/op-olm/catalog_source.yaml
                OLM_CATALOG_TMP=${TEMP_FOLDER}/.catalog_source.yaml

                info "Creating project \"$CERT_MANAGER_PROJECT\" for IBM Cert Manager operator catalog."
                create_project "$CERT_MANAGER_PROJECT"
                if [[ $? -eq 0 ]]; then
                    success "Created project \"$CERT_MANAGER_PROJECT\" for IBM Cert Manager operator catalog."
                fi

                info "Creating project \"$LICENSE_MANAGER_PROJECT\" for IBM Licensing operator catalog."
                create_project "$LICENSE_MANAGER_PROJECT"
                if [[ $? -eq 0 ]]; then
                    success "Created project \"$LICENSE_MANAGER_PROJECT\" for IBM Licensing operator catalog."
                fi

                sed "s/REPLACE_CATALOG_SOURCE_NAMESPACE/$CATALOG_NAMESPACE/g" ${OLM_CATALOG} > ${OLM_CATALOG_TMP}
                # replace all other catalogs with <CP4BA NS> namespaces
                ${SED_COMMAND} "s|namespace: .*|namespace: \"$TARGET_PROJECT_NAME\"|g" ${OLM_CATALOG_TMP}
                # replace openshift-marketplace for ibm-cert-manager-catalog with ibm-cert-manager
                ${SED_COMMAND} "/name: ibm-cert-manager-catalog/{n;s/namespace: .*/namespace: ibm-cert-manager/;}" ${OLM_CATALOG_TMP}
                # replace openshift-marketplace for ibm-licensing-catalog with ibm-licensing
                ${SED_COMMAND} "/name: ibm-licensing-catalog/{n;s/namespace: .*/namespace: ibm-licensing/;}" ${OLM_CATALOG_TMP}

                ${CLI_CMD} apply -f $OLM_CATALOG_TMP
                if [ $? -eq 0 ]; then
                    echo "IBM Operator Catalog source updated!"
                else
                    echo "Generic Operator catalog source update failed"
                    exit 1
                fi
            else
                TEMP_CATALOG_PROJECT_NAME="openshift-marketplace"
                info "Apply latest CP4BA catalog source ..."
                OLM_CATALOG=${PARENT_DIR}/descriptors/op-olm/catalog_source.yaml
                ${CLI_CMD} apply -f $OLM_CATALOG >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                    echo "IBM Cloud Pak for Business Automation Operator catalog source update failed"
                    exit 1
                fi
                echo "Done!"
            fi

            # Checking ibm-cp4a-operator catalog source pod
            info "Checking CP4BA operator catalog pod ready or not in the project \"$TEMP_CATALOG_PROJECT_NAME\""
            maxRetry=50
            for ((retry=0;retry<=${maxRetry};retry++)); do
                cp4a_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-cp4a-operator-catalog -n $TEMP_CATALOG_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                fncm_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-fncm-operator-catalog -n $TEMP_CATALOG_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                postgresql_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=cloud-native-postgresql-catalog -n $TEMP_CATALOG_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                cs_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=$CS_CATALOG_VERSION -n $TEMP_CATALOG_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ $ENABLE_PRIVATE_CATALOG -eq 1 ]; then
                    cert_mgr_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-cert-manager-catalog -n $CERT_MANAGER_PROJECT -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    license_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-licensing-catalog -n $LICENSE_MANAGER_PROJECT -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                else
                    cert_mgr_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-cert-manager-catalog -n openshift-marketplace -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    license_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-licensing-catalog -n openshift-marketplace -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                fi
                if [[ ( -z $cert_mgr_catalog_pod_name) || ( -z $license_catalog_pod_name) || ( -z $cs_catalog_pod_name) || ( -z $cp4a_catalog_pod_name) || (-z $fncm_catalog_pod_name) || (-z $postgresql_catalog_pod_name) ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                        printf "\n"
                        if [[ -z $cp4a_catalog_pod_name ]]; then
                            warning "Timeout waiting for ibm-cp4a-operator-catalog catalog pod to be ready in the project \"$TEMP_CATALOG_PROJECT_NAME\""
                        elif [[ -z $fncm_catalog_pod_name ]]; then
                            warning "Timeout waiting for ibm-fncm-operator-catalog catalog pod to be ready in the project \"$TEMP_CATALOG_PROJECT_NAME\""
                        elif [[ -z $postgresql_catalog_pod_name ]]; then
                            warning "Timeout waiting for cloud-native-postgresql-catalog catalog pod to be ready in the project \"$TEMP_CATALOG_PROJECT_NAME\""
                        elif [[ -z $cs_catalog_pod_name ]]; then
                            warning "Timeout waiting for $CS_CATALOG_VERSION catalog pod to be ready in the project \"$TEMP_CATALOG_PROJECT_NAME\""
                        elif [[ -z $cert_mgr_catalog_pod_name ]]; then
                            warning "Timeout waiting for ibm-cert-manager-catalog catalog pod to be ready in the project \"openshift-marketplace\""
                        elif [[ -z $license_catalog_pod_name ]]; then
                            warning "Timeout waiting for ibm-licensing-catalog catalog pod to be ready in the project \"openshift-marketplace\""
                        fi
                        exit 1
                    else
                        sleep 30
                        echo -n "..."
                        continue
                    fi
                else
                    success "CP4BA operator catalog pod to be ready in the project \"$TEMP_CATALOG_PROJECT_NAME\"!"
                    break
                fi
            done
        else
            fail "Not found IBM Cloud Pak for Business Automation catalog source!"
            exit 1
        fi

        # check_cp4ba_operator_version $TARGET_PROJECT_NAME
        # check_content_operator_version $TARGET_PROJECT_NAME
        # if [ -z "$UPDATE_APPROVAL_STRATEGY" ]; then
        #     # info "The default value is [automatic] for \"-s <UPDATE_APPROVAL_STRATEGY>\" option. "
        #     # info "run script with -h option for help. "
        #     # read -rsn1 -p"Press any key to continue or CTRL+C to break";echo
        #     UPDATE_APPROVAL_STRATEGY="automatic"
        # fi

        # Upgrade CP4BA operator
        info "Starting to upgrade CP4BA operator"

        # Check ibm-bts-operator/cloud-native-postgresql already upgrade to latest version
        if [[ $UPGRADE_MODE == "dedicated2dedicated"  ]]; then
            cs_service_target_namespace="$TARGET_PROJECT_NAME"
        elif [[ $UPGRADE_MODE == "shared2shared" || $UPGRADE_MODE == "shared2dedicated" ]]; then
            cs_service_target_namespace="ibm-common-services"
        fi

        # Check cloud-native-postgresql/ibm-bts-operator
        if [[ $ENABLE_PRIVATE_CATALOG -eq 0 ]]; then
            cloud_native_postgresql_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com cloud-native-postgresql --no-headers --ignore-not-found -n $cs_service_target_namespace | wc -l)
            ibm_bts_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com ibm-bts-operator --no-headers --ignore-not-found -n $cs_service_target_namespace | wc -l)
            maxRetry=50
            if [ $cloud_native_postgresql_flag -ne 0 ]; then
                info "Checking the version of subscription 'cloud-native-postgresql' in the project \"$cs_service_target_namespace\""
                sleep 60
                for ((retry=0;retry<=${maxRetry};retry++)); do
                    current_version_postgresql=$(${CLI_CMD} get subscriptions.operators.coreos.com cloud-native-postgresql --no-headers --ignore-not-found -n $cs_service_target_namespace -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                    installed_version_postgresql=$(${CLI_CMD} get subscriptions.operators.coreos.com cloud-native-postgresql --no-headers --ignore-not-found -n $cs_service_target_namespace -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                    prefix_postgresql="cloud-native-postgresql.v"
                    current_version_postgresql=${current_version_postgresql#"$prefix_postgresql"}
                    installed_version_postgresql=${installed_version_postgresql#"$prefix_postgresql"}
                    # REQUIREDVER_POSTGRESQL="1.18.5"
                    if [[ (! "$(printf '%s\n' "$REQUIREDVER_POSTGRESQL" "$current_version_postgresql" | sort -V | head -n1)" = "$REQUIREDVER_POSTGRESQL") || (! "$(printf '%s\n' "$REQUIREDVER_POSTGRESQL" "$installed_version_postgresql" | sort -V | head -n1)" = "$REQUIREDVER_POSTGRESQL") ]]; then
                        if [[ $retry -eq ${maxRetry} ]]; then
                            info "Timeout Checking for the version of cloud-native-postgresql subscription in the project \"$cs_service_target_namespace\""
                            cloud_native_postgresql_ready="No"
                            break
                        else
                            sleep 30
                            echo -n "..."
                            continue

                        fi
                    else
                        success "The version of subscription 'cloud-native-postgresql' is v$current_version_postgresql."
                        cloud_native_postgresql_ready="Yes"
                        break
                    fi
                done
            else
                cloud_native_postgresql_ready="Yes"
            fi

            if [ $ibm_bts_operator_flag -ne 0 ]; then
                info "Checking the version of subscription 'ibm-bts-operator' in the project \"$cs_service_target_namespace\""
                for ((retry=0;retry<=${maxRetry};retry++)); do
                    current_version_bts=$(${CLI_CMD} get subscriptions.operators.coreos.com ibm-bts-operator --no-headers --ignore-not-found -n $cs_service_target_namespace -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                    installed_version_bts=$(${CLI_CMD} get subscriptions.operators.coreos.com ibm-bts-operator --no-headers --ignore-not-found -n $cs_service_target_namespace -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                    prefix_bts="ibm-bts-operator.v"
                    current_version_bts=${current_version_bts#"$prefix_bts"}
                    installed_version_bts=${installed_version_bts#"$prefix_bts"}
                    # REQUIREDVER_BTS="3.28.0"
                    if [[ (! "$(printf '%s\n' "$REQUIREDVER_BTS" "$current_version_bts" | sort -V | head -n1)" = "$REQUIREDVER_BTS") || (! "$(printf '%s\n' "$REQUIREDVER_BTS" "$installed_version_bts" | sort -V | head -n1)" = "$REQUIREDVER_BTS") ]]; then
                        if [[ $retry -eq ${maxRetry} ]]; then
                            info "Timeout Checking for the version of ibm-bts-operator subscription in the project \"$cs_service_target_namespace\""
                            ibm_bts_operator_ready="No"
                            break
                        else
                            sleep 30
                            echo -n "..."
                            continue
                        fi
                    else
                        success "The version of subscription 'ibm-bts-operator' is v$current_version_bts."
                        ibm_bts_operator_ready="Yes"
                        break
                    fi
                done
            else
                ibm_bts_operator_ready="Yes"
            fi

            if [[ "$cp4a_operator_csv_version" == "21.3."* || "$cp4a_operator_csv_version" == "22.2."* ]]; then
                ibm_cp4a_wfps_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-cp4a-wfps-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | wc -l)

                if [ $ibm_cp4a_wfps_operator_flag -ne 0 ]; then
                    ibm_cp4a_wfps_sub_name=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-cp4a-wfps-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}')

                    info "Checking the version of subscription '$ibm_cp4a_wfps_sub_name' in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        current_version_wfps=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_wfps_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                        installed_version_wfps=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_wfps_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                        prefix_bts="ibm-cp4a-wfps-operator.v"
                        current_version_wfps=${current_version_wfps#"$prefix_bts"}
                        installed_version_wfps=${installed_version_wfps#"$prefix_bts"}
                        REQUIREDVER_VERSION="${CP4BA_CSV_VERSION//v/}"
                        if [[ (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$current_version_wfps" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") || (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$installed_version_wfps" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                info "Timeout Checking for the version of $ibm_cp4a_wfps_sub_name subscription in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                ibm_cp4a_wfps_operator_ready="No"
                                break
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            success "The version of subscription '$ibm_cp4a_wfps_sub_name' is v$current_version_wfps."
                            ibm_cp4a_wfps_operator_ready="Yes"
                            break
                        fi
                    done
                fi
            fi

            if [[ "$cp4a_operator_csv_version" == "22.2."* ]]; then
                # Check ADS Operator upgrade done or not
                ibm_cp4a_ads_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-ads-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | wc -l)

                if [ $ibm_cp4a_ads_operator_flag -ne 0 ]; then
                    ibm_cp4a_ads_sub_name=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-ads-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}')

                    info "Checking the version of subscription '$ibm_cp4a_ads_sub_name' in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        current_version_ads=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_ads_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                        installed_version_ads=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_ads_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                        prefix_bts="ibm-ads-operator.v"
                        current_version_ads=${current_version_ads#"$prefix_bts"}
                        installed_version_ads=${installed_version_ads#"$prefix_bts"}
                        REQUIREDVER_VERSION="${CP4BA_CSV_VERSION//v/}"
                        if [[ (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$current_version_ads" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") || (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$installed_version_ads" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                info "Timeout Checking for the version of $ibm_cp4a_ads_sub_name subscription in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                ibm_cp4a_ads_operator_ready="No"
                                break
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            success "The version of subscription '$ibm_cp4a_ads_sub_name' is v$current_version_ads."
                            ibm_cp4a_ads_operator_ready="Yes"
                            break
                        fi
                    done
                fi
                # Check Content Operator upgrade done or not
                ibm_cp4a_content_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-content-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | wc -l)

                if [ $ibm_cp4a_content_operator_flag -ne 0 ]; then
                    ibm_cp4a_content_sub_name=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-content-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}')

                    info "Checking the version of subscription '$ibm_cp4a_content_sub_name' in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        current_version_content=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_content_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                        installed_version_content=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_content_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                        prefix_bts="ibm-content-operator.v"
                        current_version_content=${current_version_content#"$prefix_bts"}
                        installed_version_content=${installed_version_content#"$prefix_bts"}
                        REQUIREDVER_VERSION="${CP4BA_CSV_VERSION//v/}"
                        if [[ (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$current_version_content" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") || (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$installed_version_content" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                info "Timeout Checking for the version of $ibm_cp4a_content_sub_name subscription in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                ibm_cp4a_content_operator_ready="No"
                                break
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            success "The version of subscription '$ibm_cp4a_content_sub_name' is v$current_version_content."
                            ibm_cp4a_content_operator_ready="Yes"
                            break
                        fi
                    done
                fi
                # Check PFS Operator upgrade done or not
                ibm_cp4a_pfs_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-pfs-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | wc -l)

                if [ $ibm_cp4a_pfs_operator_flag -ne 0 ]; then
                    ibm_cp4a_pfs_sub_name=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-pfs-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}')

                    info "Checking the version of subscription '$ibm_cp4a_pfs_sub_name' in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        current_version_pfs=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_pfs_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                        installed_version_pfs=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_pfs_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                        prefix_bts="ibm-pfs-operator.v"
                        current_version_pfs=${current_version_pfs#"$prefix_bts"}
                        installed_version_pfs=${installed_version_pfs#"$prefix_bts"}
                        REQUIREDVER_VERSION="${CP4BA_CSV_VERSION//v/}"
                        if [[ (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$current_version_pfs" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") || (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$installed_version_pfs" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                info "Timeout Checking for the version of $ibm_cp4a_pfs_sub_name subscription in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                ibm_cp4a_pfs_operator_ready="No"
                                break
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            success "The version of subscription '$ibm_cp4a_pfs_sub_name' is v$current_version_pfs."
                            ibm_cp4a_pfs_operator_ready="Yes"
                            break
                        fi
                    done
                fi
                # Check Foundation Operator upgrade done or not
                ibm_cp4a_foundation_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/icp4a-foundation-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | wc -l)

                if [ $ibm_cp4a_foundation_operator_flag -ne 0 ]; then
                    ibm_cp4a_foundation_sub_name=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/icp4a-foundation-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}')

                    info "Checking the version of subscription '$ibm_cp4a_foundation_sub_name' in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        current_version_foundation=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_foundation_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                        installed_version_foundation=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_foundation_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                        prefix_bts="icp4a-foundation-operator.v"
                        current_version_foundation=${current_version_foundation#"$prefix_bts"}
                        installed_version_foundation=${installed_version_foundation#"$prefix_bts"}
                        REQUIREDVER_VERSION="${CP4BA_CSV_VERSION//v/}"
                        if [[ (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$current_version_foundation" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") || (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$installed_version_foundation" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                info "Timeout Checking for the version of $ibm_cp4a_foundation_sub_name subscription in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                ibm_cp4a_foundation_operator_ready="No"
                                break
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            success "The version of subscription '$ibm_cp4a_foundation_sub_name' is v$current_version_foundation."
                            ibm_cp4a_foundation_operator_ready="Yes"
                            break
                        fi
                    done
                fi

            fi
        elif [[ $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
            # For shared2dedicated/dedicated2dedicated enable private catalog, we do not switch common serivce catalog source in ibm-common-services project.
            ibm_bts_operator_ready="Yes"
            cloud_native_postgresql_ready="Yes"

            if [[ "$cp4a_operator_csv_version" == "21.3."* || "$cp4a_operator_csv_version" == "22.2."* ]]; then
                ibm_cp4a_wfps_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-cp4a-wfps-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | wc -l)

                if [ $ibm_cp4a_wfps_operator_flag -ne 0 ]; then
                    ibm_cp4a_wfps_sub_name=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-cp4a-wfps-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}')

                    info "Checking the version of subscription '$ibm_cp4a_wfps_sub_name' in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        current_version_wfps=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_wfps_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                        installed_version_wfps=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_wfps_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                        prefix_bts="ibm-cp4a-wfps-operator.v"
                        current_version_wfps=${current_version_wfps#"$prefix_bts"}
                        installed_version_wfps=${installed_version_wfps#"$prefix_bts"}
                        REQUIREDVER_VERSION="${CP4BA_CSV_VERSION//v/}"
                        if [[ (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$current_version_wfps" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") || (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$installed_version_wfps" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                info "Timeout Checking for the version of $ibm_cp4a_wfps_sub_name subscription in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                ibm_cp4a_wfps_operator_ready="No"
                                break
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            success "The version of subscription '$ibm_cp4a_wfps_sub_name' is v$current_version_wfps."
                            ibm_cp4a_wfps_operator_ready="Yes"
                            break
                        fi
                    done
                fi
            fi

            if [[ "$cp4a_operator_csv_version" == "22.2."* ]]; then
                # Check ADS Operator upgrade done or not
                ibm_cp4a_ads_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-ads-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | wc -l)

                if [ $ibm_cp4a_ads_operator_flag -ne 0 ]; then
                    ibm_cp4a_ads_sub_name=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-ads-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}')

                    info "Checking the version of subscription '$ibm_cp4a_ads_sub_name' in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        current_version_ads=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_ads_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                        installed_version_ads=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_ads_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                        prefix_bts="ibm-ads-operator.v"
                        current_version_ads=${current_version_ads#"$prefix_bts"}
                        installed_version_ads=${installed_version_ads#"$prefix_bts"}
                        REQUIREDVER_VERSION="${CP4BA_CSV_VERSION//v/}"
                        if [[ (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$current_version_ads" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") || (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$installed_version_ads" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                info "Timeout Checking for the version of $ibm_cp4a_ads_sub_name subscription in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                ibm_cp4a_ads_operator_ready="No"
                                break
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            success "The version of subscription '$ibm_cp4a_ads_sub_name' is v$current_version_ads."
                            ibm_cp4a_ads_operator_ready="Yes"
                            break
                        fi
                    done
                fi
                # Check Content Operator upgrade done or not
                ibm_cp4a_content_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-content-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | wc -l)

                if [ $ibm_cp4a_content_operator_flag -ne 0 ]; then
                    ibm_cp4a_content_sub_name=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-content-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}')

                    info "Checking the version of subscription '$ibm_cp4a_content_sub_name' in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        current_version_content=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_content_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                        installed_version_content=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_content_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                        prefix_bts="ibm-content-operator.v"
                        current_version_content=${current_version_content#"$prefix_bts"}
                        installed_version_content=${installed_version_content#"$prefix_bts"}
                        REQUIREDVER_VERSION="${CP4BA_CSV_VERSION//v/}"
                        if [[ (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$current_version_content" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") || (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$installed_version_content" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                info "Timeout Checking for the version of $ibm_cp4a_content_sub_name subscription in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                ibm_cp4a_content_operator_ready="No"
                                break
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            success "The version of subscription '$ibm_cp4a_content_sub_name' is v$current_version_content."
                            ibm_cp4a_content_operator_ready="Yes"
                            break
                        fi
                    done
                fi
                # Check PFS Operator upgrade done or not
                ibm_cp4a_pfs_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-pfs-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | wc -l)

                if [ $ibm_cp4a_pfs_operator_flag -ne 0 ]; then
                    ibm_cp4a_pfs_sub_name=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/ibm-pfs-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}')

                    info "Checking the version of subscription '$ibm_cp4a_pfs_sub_name' in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        current_version_pfs=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_pfs_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                        installed_version_pfs=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_pfs_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                        prefix_bts="ibm-pfs-operator.v"
                        current_version_pfs=${current_version_pfs#"$prefix_bts"}
                        installed_version_pfs=${installed_version_pfs#"$prefix_bts"}
                        REQUIREDVER_VERSION="${CP4BA_CSV_VERSION//v/}"
                        if [[ (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$current_version_pfs" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") || (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$installed_version_pfs" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                info "Timeout Checking for the version of $ibm_cp4a_pfs_sub_name subscription in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                ibm_cp4a_pfs_operator_ready="No"
                                break
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            success "The version of subscription '$ibm_cp4a_pfs_sub_name' is v$current_version_pfs."
                            ibm_cp4a_pfs_operator_ready="Yes"
                            break
                        fi
                    done
                fi
                # Check Foundation Operator upgrade done or not
                ibm_cp4a_foundation_operator_flag=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/icp4a-foundation-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | wc -l)

                if [ $ibm_cp4a_foundation_operator_flag -ne 0 ]; then
                    ibm_cp4a_foundation_sub_name=$(${CLI_CMD} get subscriptions.operators.coreos.com -l=operators.coreos.com/icp4a-foundation-operator.$TEMP_OPERATOR_PROJECT_NAME --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME | awk '{print $1}')

                    info "Checking the version of subscription '$ibm_cp4a_foundation_sub_name' in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                    for ((retry=0;retry<=${maxRetry};retry++)); do
                        current_version_foundation=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_foundation_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                        installed_version_foundation=$(${CLI_CMD} get subscriptions.operators.coreos.com $ibm_cp4a_foundation_sub_name --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                        prefix_bts="icp4a-foundation-operator.v"
                        current_version_foundation=${current_version_foundation#"$prefix_bts"}
                        installed_version_foundation=${installed_version_foundation#"$prefix_bts"}
                        REQUIREDVER_VERSION="${CP4BA_CSV_VERSION//v/}"
                        if [[ (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$current_version_foundation" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") || (! "$(printf '%s\n' "$REQUIREDVER_VERSION" "$installed_version_foundation" | sort -V | head -n1)" = "$REQUIREDVER_VERSION") ]]; then
                            if [[ $retry -eq ${maxRetry} ]]; then
                                info "Timeout Checking for the version of $ibm_cp4a_foundation_sub_name subscription in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                ibm_cp4a_foundation_operator_ready="No"
                                break
                            else
                                sleep 30
                                echo -n "..."
                                continue
                            fi
                        else
                            success "The version of subscription '$ibm_cp4a_foundation_sub_name' is v$current_version_foundation."
                            ibm_cp4a_foundation_operator_ready="Yes"
                            break
                        fi
                    done
                fi

            fi
        fi

        # # Do NOT need to upgrade CPFS 4.2 when upgrade from CP4BA 23.0.1 IF004 to 23.0.2
        # isReady=$(${CLI_CMD} get csv ibm-common-service-operator.$CS_OPERATOR_VERSION --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.status.phase}')
        # if [[ -z $isReady || $isReady != "Succeeded" ]]; then
        #     # Upgrade IBM Cert Manager/Licensing to $CERT_LICENSE_OPERATOR_VERSION for $CP4BA_RELEASE_BASE upgrade
        #     info "Upgrading IBM Cert Manager/Licensing operators to $CERT_LICENSE_OPERATOR_VERSION."
        #     $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq "$CPFS_YQ_PATH" -c $CERT_LICENSE_CHANNEL_VERSION
        #     # Upgrade CPFS from 23.0.1.X to $CS_OPERATOR_VERSION for $CP4BA_RELEASE_BASE upgrade
        #     isReadyCommonService=$(${CLI_CMD} get csv ibm-common-service-operator.$CS_OPERATOR_VERSION --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.status.phase}')
        #     if [[ -z $isReadyCommonService ]]; then
        #         if [ $ENABLE_PRIVATE_CATALOG -eq 1 ]; then
        #             info "Upgrading/Switching the catalog of IBM Cloud Pak foundational services to $TARGET_PROJECT_NAME."
        #             $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --enable-private-catalog --license-accept
        #             success "Upgraded/Switched the catalog of IBM Cloud Pak foundational services to $TARGET_PROJECT_NAME."
        #         else
        #             info "Upgrading IBM Cloud Pak foundational services to $CS_OPERATOR_VERSION."
        #             $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -n openshift-marketplace --license-accept
        #         fi
        #     fi
        # fi

        # Migrate CPfs from 3.x to 4.6 for upgrade CP4BA 21.0.3.x/22.0.2 to latest
        if [[ "$cp4a_operator_csv_version" == "21.3."* && (("$ibm_bts_operator_ready" == "Yes" && "$cloud_native_postgresql_ready" == "Yes" )) && "$ibm_cp4a_wfps_operator_ready" == "Yes" ]]; then
            READY_FOR_DIRECT_UPGRADE="Yes"
        elif [[ "$cp4a_operator_csv_version" == "22.2."* && (("$ibm_bts_operator_ready" == "Yes" && "$cloud_native_postgresql_ready" == "Yes" )) && "$ibm_cp4a_wfps_operator_ready" == "Yes" && "$ibm_cp4a_pfs_operator_ready" == "Yes" && "$ibm_cp4a_ads_operator_ready" == "Yes" && "$ibm_cp4a_content_operator_ready" == "Yes" && "$ibm_cp4a_foundation_operator_ready" == "Yes" ]]; then
            READY_FOR_DIRECT_UPGRADE="Yes"
        elif [[ "$cp4a_operator_csv_version" == "23.2."* || "$cp4a_operator_csv_version" == "24.0."* ]]; then
            READY_FOR_DIRECT_UPGRADE="Yes"
        else
            READY_FOR_DIRECT_UPGRADE="No"
            fail "Prerequisite for upgrade did not complete, exiting..."
        fi

        if [[ $READY_FOR_DIRECT_UPGRADE == "Yes" ]]; then
            # Check IAF operator and remove IAF
            info "Prerequisite for upgrade passed, continue..."
            mkdir -p $UPGRADE_DEPLOYMENT_IAF_LOG_FOLDER >/dev/null 2>&1
            info "Checking IBM Automation Foundation components in the project \"$TEMP_OPERATOR_PROJECT_NAME\"."
            iaf_core_operator_pod_name=$(${CLI_CMD} get pod -l=app.kubernetes.io/name=iaf-core-operator,app.kubernetes.io/instance=iaf-core-operator -n $TEMP_OPERATOR_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep '<none>' | head -1 | awk '{print $1}')
            iaf_operator_pod_name=$(${CLI_CMD} get pod -l=app.kubernetes.io/name=iaf-operator,app.kubernetes.io/instance=iaf-operator -n $TEMP_OPERATOR_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep '<none>' | head -1 | awk '{print $1}')

            if [[ (! -z "$iaf_core_operator_pod_name") || (! -z "$iaf_operator_pod_name") ]]; then
            # remove IAF components from CP4BA deployment
                info "Starting to remove IAF components from CP4BA deployment in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                cp4ba_cr_name=$(${CLI_CMD} get icp4acluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')

                if [[ -z $cp4ba_cr_name ]]; then
                    cp4ba_cr_name=$(${CLI_CMD} get content -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
                    cr_type="contents.icp4a.ibm.com"
                else
                    cr_type="icp4aclusters.icp4a.ibm.com"
                fi

                if [[ -z $cp4ba_cr_name ]]; then
                    fail "Not found any custom resource for CP4BA deployment in the project \"$TARGET_PROJECT_NAME\", exit..."
                    exit 1
                else
                    cp4ba_cr_metaname=$(${CLI_CMD} get $cr_type $cp4ba_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
                fi


                if [[ $UPGRADE_MODE == "dedicated2dedicated" ]]; then
                    control_namespace=$(${CLI_CMD} get cm ${COMMON_SERVICES_CM_DEDICATED_NAME} --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE} -o jsonpath='{ .data.common-service-maps\.yaml }' | grep  'controlNamespace' | cut -d':' -f2 )
                    control_namespace=$(sed -e 's/^"//' -e 's/"$//' <<<"$control_namespace")
                    control_namespace=$(sed "s/ //g" <<< $control_namespace)

                    if [[ ! -z $control_namespace ]]; then
                        msg "All arguments passed into the script: ${CUR_DIR}/helper/upgrade/remove_iaf.sh $cr_type $cp4ba_cr_metaname $TARGET_PROJECT_NAME $control_namespace \"icp4ba\" \"none\""
                        source ${CUR_DIR}/helper/upgrade/remove_iaf.sh $cr_type $cp4ba_cr_metaname $TARGET_PROJECT_NAME $control_namespace "icp4ba" "none" >/dev/null 2>&1
                    else
                        fail "Not found \"controlNamespace\" in configMap \"${COMMON_SERVICES_CM_DEDICATED_NAME}\" in the project \"${COMMON_SERVICES_CM_NAMESPACE}\""
                        exit 1
                    fi
                elif [[ $UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "shared2shared" ]]; then
                    msg "All arguments passed into the script: ${CUR_DIR}/helper/upgrade/remove_iaf.sh $cr_type $cp4ba_cr_metaname $TARGET_PROJECT_NAME ibm-common-services \"icp4ba\" \"none\""
                    source ${CUR_DIR}/helper/upgrade/remove_iaf.sh $cr_type $cp4ba_cr_metaname $TARGET_PROJECT_NAME ibm-common-services "icp4ba" "none" >/dev/null 2>&1
                fi
                info "Checking if IAF components be removed from the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                maxRetry=10
                for ((retry=0;retry<=${maxRetry};retry++)); do
                    iaf_core_operator_pod_name=$(${CLI_CMD} get pod -l=app.kubernetes.io/name=iaf-core-operator,app.kubernetes.io/instance=iaf-core-operator -n $TEMP_OPERATOR_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep '<none>' | head -1 | awk '{print $1}')
                    iaf_operator_pod_name=$(${CLI_CMD} get pod -l=app.kubernetes.io/name=iaf-operator,app.kubernetes.io/instance=iaf-operator -n $TEMP_OPERATOR_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep '<none>' | head -1 | awk '{print $1}')

                    # if [[ -z $isReadyWebhook || -z $isReadyCertmanager || -z $isReadyCainjector || -z $isReadyCertmanagerOperator ]]; then
                    if [[ (! -z $iaf_core_operator_pod_name) || (! -z $iaf_operator_pod_name) ]]; then
                        if [[ $retry -eq ${maxRetry} ]]; then
                            printf "\n"
                            warning "Timeout waiting for IBM Automation Foundation be removed from the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                            echo -e "\x1B[1mPlease remove IAF manually with cmd: \"${CUR_DIR}/helper/upgrade/remove_iaf.sh $cr_type $cp4ba_cr_metaname $TARGET_PROJECT_NAME $control_namespace \"icp4ba\" \"none\"\"\x1B[0m"
                            exit 1
                        else
                            sleep 30
                            echo -n "..."
                            continue
                        fi
                    else
                        success "IBM Automation Foundation was removed successfully!"
                        break
                    fi
                done
            else
                success "IBM Automation Foundation components already were removed from the project \"$TEMP_OPERATOR_PROJECT_NAME\"!"
            fi

            if [[ "$cp4a_operator_csv_version" == "21.3."* || "$cp4a_operator_csv_version" == "22.2."* ]]; then
                info "Starting to migrate IBM Cloud Pak foundational services from 3.x to $CS_OPERATOR_VERSION"

                # Check if without option --enable-private-catalog, the catalog is in target project, set the private catalog as default.
                info "Checking ibm-cp4a-operator-catalog catalog source is global or private namespace scoped"
                if [[ $ENABLE_PRIVATE_CATALOG -eq 0 ]]; then
                    if ${CLI_CMD} get catalogsource -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | grep ibm-cp4a-operator-catalog >/dev/null 2>&1; then
                        ENABLE_PRIVATE_CATALOG=1
                    else
                        info "Not found ibm-cp4a-operator-catalog catalog source under target project \"$TARGET_PROJECT_NAME\""
                    fi
                fi

                if [[ $UPGRADE_MODE == "dedicated2dedicated" && $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --cert-manager-source ibm-cert-manager-catalog --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept --enable-private-catalog"
                    # switch catalog from GCN to private
                    $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --cert-manager-source ibm-cert-manager-catalog --enable-licensing --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept --enable-private-catalog
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --cert-manager-source ibm-cert-manager-catalog --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept --enable-private-catalog"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                elif [[ $UPGRADE_MODE == "dedicated2dedicated" && $ENABLE_PRIVATE_CATALOG -eq 0 ]]; then
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --cert-manager-source ibm-cert-manager-catalog --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept"
                    # keep GCN catalog
                    $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --cert-manager-source ibm-cert-manager-catalog --enable-licensing --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --cert-manager-source ibm-cert-manager-catalog --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                elif [[ $UPGRADE_MODE == "shared2dedicated" && $ENABLE_PRIVATE_CATALOG -eq 1 && $ALL_NAMESPACE_FLAG == "No" ]]; then
                    ## Apply workaround for https://jsw.ibm.com/browse/DBACLD-137719 before start migration CPfs
                    ## Shutdown ibm-bts-operator-controller-manager in ibm-common-services project
                    bts_operator_name=$(${CLI_CMD} get deployment ibm-bts-operator-controller-manager --no-headers --ignore-not-found -n ibm-common-services -o name)
                    if [[ ! -z $bts_operator_name ]]; then                    
                        ${CLI_CMD} scale --replicas=0 deployment ibm-bts-operator-controller-manager -n ibm-common-services >/dev/null 2>&1
                        if [[ $? -ne 0 ]]; then
                            warning "Failed to scale down ibm-bts-operator-controller-manager operator in the project \"ibm-common-services\". Please scale down ibm-bts-operator-controller-manager operator manually."
                        fi
                    fi
                    # switch catalog from GCN to private
                    # shared2dedicated dose not support All namespace
                    ## Isolated CP4BA instance in $TARGET_PROJECT_NAME namespace
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/isolate.sh --original-cs-ns ibm-common-services --control-ns cs-control --excluded-ns $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\""
                    $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/isolate.sh --original-cs-ns ibm-common-services --control-ns cs-control --excluded-ns $TARGET_PROJECT_NAME --yq "$CPFS_YQ_PATH"
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/isolate.sh --original-cs-ns ibm-common-services --control-ns cs-control --excluded-ns $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\""
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    ## Migrate Cert-Manager and Licensing service from v3.x to v4.x
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --operator-namespace ibm-common-services --enable-licensing --license-accept --enable-private-catalog --yq \"$CPFS_YQ_PATH\" -v 1"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --operator-namespace ibm-common-services --enable-licensing --license-accept --enable-private-catalog --yq "$CPFS_YQ_PATH" -v 1
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --operator-namespace ibm-common-services --enable-licensing --license-accept --enable-private-catalog --yq \"$CPFS_YQ_PATH\" -v 1"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    ## Preload data
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/preload_data.sh --original-cs-ns ibm-common-services --services-ns $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\""
                    $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/preload_data.sh --original-cs-ns ibm-common-services --services-ns $TARGET_PROJECT_NAME --yq "$CPFS_YQ_PATH"
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/preload_data.sh --original-cs-ns ibm-common-services --services-ns $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\""
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    ## Fresh install foundational services version 4.x
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --enable-private-catalog --license-accept -s $CS_CATALOG_VERSION -c $CS_CHANNEL_VERSION --yq \"$CPFS_YQ_PATH\" -v 1"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --enable-private-catalog --license-accept -s $CS_CATALOG_VERSION -c $CS_CHANNEL_VERSION --yq "$CPFS_YQ_PATH" -v 1
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --enable-private-catalog --license-accept -s $CS_CATALOG_VERSION -c $CS_CHANNEL_VERSION --yq \"$CPFS_YQ_PATH\" -v 1"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                elif [[ $UPGRADE_MODE == "shared2dedicated" && $ENABLE_PRIVATE_CATALOG -eq 0 && $ALL_NAMESPACE_FLAG == "No" ]]; then
                    ## Apply workaround for https://jsw.ibm.com/browse/DBACLD-137719 before start migration CPfs
                    ## Shutdown ibm-bts-operator-controller-manager in ibm-common-services project
                    bts_operator_name=$(${CLI_CMD} get deployment ibm-bts-operator-controller-manager --no-headers --ignore-not-found -n ibm-common-services -o name)
                    if [[ ! -z $bts_operator_name ]]; then  
                        ${CLI_CMD} scale --replicas=0 deployment ibm-bts-operator-controller-manager -n ibm-common-services >/dev/null 2>&1
                        if [[ $? -ne 0 ]]; then
                            warning "Failed to scale down ibm-bts-operator-controller-manager operator in the project \"ibm-common-services\". Please scale down ibm-bts-operator-controller-manager operator manually."
                        fi
                    fi
                    # keep GCN catalog
                    # shared2dedicated dose not support All namespace
                    ## Isolated CP4BA instance in $TARGET_PROJECT_NAME namespace
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/isolate.sh --original-cs-ns ibm-common-services --control-ns cs-control --excluded-ns $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\""
                    $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/isolate.sh --original-cs-ns ibm-common-services --control-ns cs-control --excluded-ns $TARGET_PROJECT_NAME --yq "$CPFS_YQ_PATH"
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/isolate.sh --original-cs-ns ibm-common-services --control-ns cs-control --excluded-ns $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\""
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    ## Migrate Cert-Manager and Licensing service from v3.x to v4.x
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --operator-namespace ibm-common-services --enable-licensing --license-accept --yq \"$CPFS_YQ_PATH\" -v 1"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --operator-namespace ibm-common-services --enable-licensing --license-accept --yq "$CPFS_YQ_PATH" -v 1
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --operator-namespace ibm-common-services --enable-licensing --license-accept --yq \"$CPFS_YQ_PATH\" -v 1"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    ## Preload data
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/preload_data.sh --original-cs-ns ibm-common-services --services-ns $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\""
                    $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/preload_data.sh --original-cs-ns ibm-common-services --services-ns $TARGET_PROJECT_NAME --yq "$CPFS_YQ_PATH"
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_PARENT_FOLDER/preload_data.sh --original-cs-ns ibm-common-services --services-ns $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\""
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    ## Fresh install foundational services version 4.x
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --license-accept -s $CS_CATALOG_VERSION -c $CS_CHANNEL_VERSION --yq \"$CPFS_YQ_PATH\" -v 1"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --license-accept -s $CS_CATALOG_VERSION -c $CS_CHANNEL_VERSION --yq "$CPFS_YQ_PATH" -v 1
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --operator-namespace $TARGET_PROJECT_NAME --license-accept -s $CS_CATALOG_VERSION -c $CS_CHANNEL_VERSION --yq \"$CPFS_YQ_PATH\" -v 1"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                elif [[ $UPGRADE_MODE == "shared2shared" && $ALL_NAMESPACE_FLAG == "Yes" ]]; then
                    # keep GCN catalog
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace openshift-operators --cert-manager-source ibm-cert-manager-catalog --licensing-source ibm-licensing-catalog --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept"
                    $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace openshift-operators --cert-manager-source ibm-cert-manager-catalog --licensing-source ibm-licensing-catalog --enable-licensing --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace openshift-operators --cert-manager-source ibm-cert-manager-catalog --licensing-source ibm-licensing-catalog --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    # workaround for https://github.ibm.com/IBMPrivateCloud/roadmap/issues/63676
                    cs_namespace="ibm-common-services"
                    info "Removing ibm-events-operator from the project \"$cs_namespace\"."
                    ${CLI_CMD} delete csv -l operators.coreos.com/ibm-events-operator.$cs_namespace='' -n $cs_namespace >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        success "Removed ibm-events-operator from the project \"$cs_namespace\"."
                    else
                        fail "Faild to remove ibm-events-operator from the project \"$cs_namespace\"."
                    fi
                elif [[ $UPGRADE_MODE == "shared2shared" && $ALL_NAMESPACE_FLAG == "No" ]]; then
                    # keep GCN catalog
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace ibm-common-services --services-namespace ibm-common-services --cert-manager-source ibm-cert-manager-catalog --licensing-source ibm-licensing-catalog --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept"
                    $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace ibm-common-services --services-namespace ibm-common-services --cert-manager-source ibm-cert-manager-catalog --licensing-source ibm-licensing-catalog --enable-licensing --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/migrate_tenant.sh --operator-namespace ibm-common-services --services-namespace ibm-common-services --cert-manager-source ibm-cert-manager-catalog --licensing-source ibm-licensing-catalog --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --license-accept"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                fi
            elif [[ "$cp4a_operator_csv_version" == "23.2."* ]]; then
                info "Starting to upgrade IBM Cloud Pak foundational services to $CS_OPERATOR_VERSION"
                # Check if without option --enable-private-catalog, the catalog is in target project, set the private catalog as default.
                info "Checking ibm-cp4a-operator-catalog catalog source is global or private namespace scoped"
                if [[ $ENABLE_PRIVATE_CATALOG -eq 0 ]]; then
                    if ${CLI_CMD} get catalogsource -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | grep ibm-cp4a-operator-catalog >/dev/null 2>&1; then
                        ENABLE_PRIVATE_CATALOG=1
                    else
                        info "Not found ibm-cp4a-operator-catalog catalog source under target project \"$TARGET_PROJECT_NAME\""
                    fi
                fi
                if [[ $UPGRADE_MODE == "dedicated2dedicated" && $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
                    # Upgrading Cert-Manager and Licensing Service
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --enable-private-catalog --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --enable-private-catalog --yq "$CPFS_YQ_PATH" -c $CERT_LICENSE_CHANNEL_VERSION
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --enable-private-catalog --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    # switch catalog from GCN to private
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --enable-private-catalog -v 1"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --enable-private-catalog -v 1
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --enable-private-catalog -v 1"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                elif [[ $UPGRADE_MODE == "dedicated2dedicated" && $ENABLE_PRIVATE_CATALOG -eq 0 ]]; then
                    # Upgrading Cert-Manager and Licensing Service
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq "$CPFS_YQ_PATH" -c $CERT_LICENSE_CHANNEL_VERSION
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    # keep GCN catalog
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $TARGET_PROJECT_NAME --services-namespace $TARGET_PROJECT_NAME --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                elif [[ $UPGRADE_MODE == "shared2shared" && $ALL_NAMESPACE_FLAG == "Yes" ]]; then
                    # It is not recommended to install 23.0.2 in all namespace. but script keep coverage for it
                    # Upgrading Cert-Manager and Licensing Service
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq "$CPFS_YQ_PATH" -c $CERT_LICENSE_CHANNEL_VERSION
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    # workaround for https://github.ibm.com/IBMPrivateCloud/roadmap/issues/63676
                    cs_namespace="ibm-common-services"
                    info "Removing ibm-events-operator from the project \"$cs_namespace\"."
                    ${CLI_CMD} delete csv -l operators.coreos.com/ibm-events-operator.$cs_namespace='' -n $cs_namespace >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        success "Removed ibm-events-operator from the project \"$cs_namespace\"."
                    else
                        fail "Faild to remove ibm-events-operator from the project \"$cs_namespace\"."
                    fi
                    # keep GCN catalog
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace openshift-operators --services-namespace ibm-common-services --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --enable-private-catalog -v 1"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace openshift-operators --services-namespace ibm-common-services --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --enable-private-catalog -v 1
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace openshift-operators --services-namespace ibm-common-services --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --enable-private-catalog -v 1"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                elif [[ $UPGRADE_MODE == "shared2shared" && $ALL_NAMESPACE_FLAG == "No" ]]; then
                    # Upgrading Cert-Manager and Licensing Service
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq "$CPFS_YQ_PATH" -c $CERT_LICENSE_CHANNEL_VERSION
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                    # keep GCN catalog
                    msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $TARGET_PROJECT_NAME --services-namespace ibm-common-services --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1"
                    $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $TARGET_PROJECT_NAME --services-namespace ibm-common-services --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1
                    if [ $? -ne 0 ]; then
                        warning "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $TARGET_PROJECT_NAME --services-namespace ibm-common-services --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1"
                        echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fix migration issue of IBM Cloud Pak foundational services."
                        echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
                        echo "           Usage:"
                        echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
                        echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade, the example value [21.3.31] for 21.0.3-IF031/[22.2.6] for 22.0.2-IF006/[23.2.3] for 23.0.2-IF003"
                        echo "           Example command: "
                        echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $TARGET_PROJECT_NAME --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 21.3.31"
                        exit 1
                    fi
                fi
            fi
        fi

        # Check IBM Cloud Pak foundational services Operator $CS_OPERATOR_VERSION
        maxRetry=30
        echo "****************************************************************************"
        info "Checking for IBM Cloud Pak foundational operator pod initialization"
        for ((retry=0;retry<=${maxRetry};retry++)); do
            isReady=$(${CLI_CMD} get csv ibm-common-service-operator.$CS_OPERATOR_VERSION --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o jsonpath='{.status.phase}')
            # isReady=$(${CLI_CMD} exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine $CP4BA_RELEASE_BASE")
            if [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM Cloud Pak foundational operator to start"
                echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $TEMP_OPERATOR_PROJECT_NAME|grep ibm-common-service-operator|awk '{print $1}') -n $TEMP_OPERATOR_PROJECT_NAME"
                printf "\n"
                echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
                echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $TEMP_OPERATOR_PROJECT_NAME|grep ibm-common-service-operator|awk '{print $1}') -n $TEMP_OPERATOR_PROJECT_NAME"
                printf "\n"
                exit 1
                else
                sleep 30
                echo -n "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                pod_name=$(${CLI_CMD} get pod -l=name=ibm-common-service-operator -n $TEMP_OPERATOR_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM Cloud Pak foundational Operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM Cloud Pak foundational Operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            fi
        done
        echo "****************************************************************************"

        # if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") || $bai_flag == "true" ]]; then
        #     # Check IBM Events Operator $EVENTS_OPERATOR_VERSION
        #     maxRetry=10
        #     echo "****************************************************************************"
        #     info "Checking for IBM Events operator pod initialization"
        #     for ((retry=0;retry<=${maxRetry};retry++)); do
        #         isReady=$(${CLI_CMD} get csv ibm-events-operator.$EVENTS_OPERATOR_VERSION --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o jsonpath='{.status.phase}')
        #         # isReady=$(${CLI_CMD} exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine $CP4BA_RELEASE_BASE")
        #         if [[ $isReady != "Succeeded" ]]; then
        #             if [[ $retry -eq ${maxRetry} ]]; then
        #             printf "\n"
        #             warning "Timeout waiting for IBM Events operator to start"
        #             echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
        #             echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $TEMP_OPERATOR_PROJECT_NAME|grep ibm-events-operator|awk '{print $1}') -n $TEMP_OPERATOR_PROJECT_NAME"
        #             printf "\n"
        #             echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
        #             echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $TEMP_OPERATOR_PROJECT_NAME|grep ibm-events-operator|awk '{print $1}') -n $TEMP_OPERATOR_PROJECT_NAME"
        #             printf "\n"
        #             exit 1
        #             else
        #             sleep 30
        #             echo -n "..."
        #             continue
        #             fi
        #         elif [[ $isReady == "Succeeded" ]]; then
        #             pod_name=$(${CLI_CMD} get pod -l=name=ibm-events-operator -n $TEMP_OPERATOR_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
        #             if [ -z $pod_name ]; then
        #                 error "IBM Events Operator pod is NOT running"
        #                 CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
        #                 break
        #             else
        #                 success "IBM Events Operator is running"
        #                 info "Pod: $pod_name"
        #                 CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
        #                 break
        #             fi
        #         fi
        #     done
        #     echo "****************************************************************************"
        # fi

        # Checking CP4BA operator CSV
        # change this value for $CP4BA_RELEASE_BASE-IFIX
        sub_inst_list=$(${CLI_CMD} get subscriptions.operators.coreos.com -n $TEMP_OPERATOR_PROJECT_NAME|grep ibm-cp4a-operator-catalog|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
        if [[ -z $sub_inst_list ]]; then
            fail "Not found any existing CP4BA subscriptions (version $CP4BA_CSV_VERSION), exiting ..."
            exit 1
        fi
        sub_array=($sub_inst_list)
        target_csv_version=${CP4BA_CSV_VERSION//v/}
        for i in ${!sub_array[@]}; do
            if [[ ! -z "${sub_array[i]}" ]]; then
                if [[ ${sub_array[i]} = ibm-cp4a-operator* || ${sub_array[i]} = ibm-cp4a-wfps-operator* || ${sub_array[i]} = ibm-content-operator* || ${sub_array[i]} = icp4a-foundation-operator* || ${sub_array[i]} = ibm-pfs-operator* || ${sub_array[i]} = ibm-ads-operator* || ${sub_array[i]} = ibm-dpe-operator* || ${sub_array[i]} = ibm-odm-operator* || ${sub_array[i]} = ibm-insights-engine-operator* || ${sub_array[i]} = ibm-workflow-operator* ]]; then
                info "Checking the channel of subscription '${sub_array[i]}'!"
                currentChannel=$(${CLI_CMD} get subscriptions.operators.coreos.com ${sub_array[i]} -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.spec.channel}') >/dev/null 2>&1
                    if [[ "$currentChannel" == "$CP4BA_CHANNEL_VERSION" ]]
                    then
                        success "The channel of subscription '${sub_array[i]}' is $currentChannel!"
                        printf "\n"
                        maxRetry=40
                        info "Waiting for the \"${sub_array[i]}\" subscription be upgraded to the ClusterServiceVersions(CSV) \"v$target_csv_version\""
                        for ((retry=0;retry<=${maxRetry};retry++)); do
                            current_version=$(${CLI_CMD} get subscriptions.operators.coreos.com ${sub_array[i]} --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.currentCSV}') >/dev/null 2>&1
                            installed_version=$(${CLI_CMD} get subscriptions.operators.coreos.com ${sub_array[i]} --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o 'jsonpath={.status.installedCSV}') >/dev/null 2>&1
                            if [[ -z $current_version || -z $installed_version ]]; then
                                error "fail to get installed or current CSV, abort the upgrade procedure. Please check ${sub_array[i]} subscription status."
                                exit 1
                            fi
                            case "${sub_array[i]}" in
                            "ibm-cp4a-operator"*)
                                prefix_sub="ibm-cp4a-operator.v"
                                ;;
                            "ibm-cp4a-wfps-operator"*)
                                prefix_sub="ibm-cp4a-wfps-operator.v"
                                ;;
                            "ibm-content-operator"*)
                                prefix_sub="ibm-content-operator.v"
                                ;;
                            "icp4a-foundation-operator"*)
                                prefix_sub="icp4a-foundation-operator.v"
                                ;;
                            "ibm-pfs-operator"*)
                                prefix_sub="ibm-pfs-operator.v"
                                ;;
                            "ibm-ads-operator"*)
                                prefix_sub="ibm-ads-operator.v"
                                ;;
                            "ibm-dpe-operator"*)
                                prefix_sub="ibm-dpe-operator.v"
                                ;;
                            "ibm-odm-operator"*)
                                prefix_sub="ibm-odm-operator.v"
                                ;;
                            "ibm-insights-engine-operator"*)
                                prefix_sub="ibm-insights-engine-operator.v"
                                ;;
                            "ibm-workflow-operator"*)
                                prefix_sub="ibm-workflow-operator.v"
                                ;;
                            esac

                            current_version=${current_version#"$prefix_sub"}
                            installed_version=${installed_version#"$prefix_sub"}
                            if [[ $current_version != $installed_version || $current_version != $target_csv_version || $installed_version != $target_csv_version ]]; then
                                approval_mode=$(${CLI_CMD} get subscription.operators.coreos.com ${sub_array[i]} --no-headers --ignore-not-found -n $TEMP_OPERATOR_PROJECT_NAME -o jsonpath={.spec.installPlanApproval})
                                if [[ $approval_mode == "Manual" ]]; then
                                    error "${sub_array[i]} subscription is set to Manual Approval mode, please approve installPlan to upgrade."
                                    exit 1
                                fi
                                if [[ $retry -eq ${maxRetry} ]]; then
                                    warning "Timeout waiting for upgrading \"${sub_array[i]}\" subscription from ${installed_version} to ${target_csv_version} in the project \"$TEMP_OPERATOR_PROJECT_NAME\""
                                    break
                                else
                                    sleep 10
                                    echo -n "..."
                                    continue
                                fi
                            else
                                success "ClusterServiceVersions ${installed_version} is now the latest available version in ${currentChannel} channel."
                                break
                            fi
                        done

                    else
                        fail "Failed to update the channel of subscription '${sub_array[i]}' to $CP4BA_CHANNEL_VERSION! exiting now..."
                        exit 1
                    fi
                fi
            else
                fail "No found subscription '${sub_array[i]}'! exiting now..."
                exit 1
            fi
        done
        success "Completed to check the channel of subscription for CP4BA operators"

        info "Shutdown CP4BA Operators before upgrade CP4BA capabilities."
        shutdown_operator $TEMP_OPERATOR_PROJECT_NAME
        printf "\n"
        if [[ $CONTENT_CR_EXIST == "Yes" || (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (! " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service")) || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
            if [[ $UPGRADE_MODE == "shared2dedicated" ]]; then
                echo -e "\x1B[33;5m[ATTENTION]: \x1B[0m${RED_TEXT}DO NOT need to run \"./cp4a-pre-upgrade-and-post-upgrade-optional.sh\" in \"pre-upgrade\" mode when migrate IBM Cloud Pak foundational services from \"Cluster-scoped\" to \"Namespace-scoped\"!${RESET_TEXT}"
                read -rsn1 -p"Press any key to continue";echo
            fi
        fi
        printf "\n"
        echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}"
        echo "${YELLOW_TEXT}  - All CP4BA operators were shutdown already by script.${RESET_TEXT}"
        echo "${YELLOW_TEXT}  - All CP4BA operators will start up by script automatically when run the [upgradeDeploymentStatus] mode of the cp4a-deployment.sh script.${RESET_TEXT}"
        printf "\n"
        echo "${YELLOW_TEXT}[NEXT ACTIONS]:${RESET_TEXT}"
        step_num=1
        echo "  - STEP ${step_num} ${YELLOW_TEXT}(Optional)${RESET_TEXT}: You can run ${GREEN_TEXT}\"./cp4a-deployment.sh -m upgradeOperatorStatus -n $TARGET_PROJECT_NAME\"${RESET_TEXT} to check that the upgrade of the CP4BA operator and its dependencies is successful."
        step_num=$((step_num + 1))

        if [[ $css_flag == "true" || " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "css" ]]; then
            echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You have Content Search Services (CSS) installed. Make sure you stop the IBM Content Search Services index dispatcher. Refer to the FileNet P8 Platform Documentation for more details."
            echo "    ${YELLOW_TEXT}* Stopping the IBM Content Search Services index dispatcher.${RESET_TEXT}"
            echo "      1. Log in to the Administration Console for Content Platform Engine."
            echo "      2. In the navigation pane, select the domain icon."
            echo "      3. In the edit pane, click the Text Search Subsystem tab and clear the Enable indexing check box."
            echo "      4. Click Save to save your changes."
            step_num=$((step_num + 1))
        fi
        echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You need to run ${GREEN_TEXT}\"./cp4a-deployment.sh -m upgradeDeployment -n $TARGET_PROJECT_NAME\"${RESET_TEXT} to upgrade CP4BA deployment."
        echo "    ${RED_TEXT}[ATTENTION]: ${RESET_TEXT}${YELLOW_TEXT}When you run the [upgradeDeployment] mode of the cp4a-deployment.sh script, the updated custom resource (CR) must be manually applied so required additional actions can be completed before the upgrade of the deployment begins. Please refer to the Knowledge Center: \"Updating the custom resource for each capability in your deployment\" topic to complete REQUIRED steps for the installed pattern(s)."
        echo "      - if upgrading from 21.0.3: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment]"
        echo "      - if upgrading from 23.0.2: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment-1]${RESET_TEXT}"
    fi
fi

if [ "$RUNTIME_MODE" == "upgradeOperatorStatus" ]; then
    project_name=$TARGET_PROJECT_NAME
    
    UPGRADE_DEPLOYMENT_FOLDER=${CUR_DIR}/cp4ba-upgrade/project/$TARGET_PROJECT_NAME
    UPGRADE_DEPLOYMENT_CR=${UPGRADE_DEPLOYMENT_FOLDER}/custom_resource
    UPGRADE_DEPLOYMENT_CONTENT_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.content_tmp.yaml
    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.icp4acluster_tmp.yaml
    mkdir -p $UPGRADE_DEPLOYMENT_CR >/dev/null 2>&1
    source ${CUR_DIR}/helper/upgrade/upgrade_merge_yaml.sh $TARGET_PROJECT_NAME

    if which oc >/dev/null 2>&1; then
        CLI_CMD=oc
    elif which kubectl >/dev/null 2>&1; then
        CLI_CMD=kubectl
    else
        echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI or OpenShift CLI. You must install it to run this script.\x1B[0m" && \
        exit 1
    fi

    cp4a_operator_csv_name_target_ns=$(${CLI_CMD} get csv -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
    cp4a_operator_csv_name_allnamespace_ns=$(${CLI_CMD} get csv -n $ALL_NAMESPACE_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')

    if [[ -z $cp4a_operator_csv_name_allnamespace_ns && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
        success "Found IBM Cloud Pak for Business Automation Operator deployed in the project \"$TARGET_PROJECT_NAME\"."
        ALL_NAMESPACE_FLAG="No"
        TEMP_OPERATOR_PROJECT_NAME=$TARGET_PROJECT_NAME
    elif [[ (! -z $cp4a_operator_csv_name_allnamespace_ns) && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
        success "Found IBM Cloud Pak for Business Automation Operator deployed as AllNamespace mode in the project \"$ALL_NAMESPACE_NAME\"."
        ALL_NAMESPACE_FLAG="Yes"
        project_name="openshift-operators"
        TEMP_OPERATOR_PROJECT_NAME="openshift-operators"
    fi

    ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        content_cr_name=$(${CLI_CMD} get content -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
        if [ ! -z $content_cr_name ]; then
            cr_type="content"
            cp4ba_cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
            owner_ref=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
            if [[ ${owner_ref} == "ICP4ACluster" ]]; then
                echo
            else
                ${CLI_CMD} get $cr_type $content_cr_name -n $TARGET_PROJECT_NAME -o yaml > ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                bai_flag=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP | ${YQ_CMD} r - spec.content_optional_components.bai`
                bai_flag=$(echo $bai_flag | tr '[:upper:]' '[:lower:]')
                CONTENT_CR_EXIST="Yes"
                cp4ba_root_ca_secret_name=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.root_ca_secret`
            fi
        fi
    fi

    icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $icp4acluster_cr_name ]; then
        cr_type="icp4acluster"
        cp4ba_cr_metaname=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
        ${CLI_CMD} get $cr_type $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml > ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        cp4ba_root_ca_secret_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.root_ca_secret`
        convert_olm_cr "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        if [[ $olm_cr_flag == "No" ]]; then
            # Get EXISTING_PATTERN_ARR/EXISTING_OPT_COMPONENT_ARR
            existing_pattern_list=""
            existing_opt_component_list=""

            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
            existing_opt_component_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`

            OIFS=$IFS
            IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
            IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
            IFS=$OIFS
        fi
    fi
    if [[ -z $content_cr_name && -z $icp4acluster_cr_name ]]; then
        fail "Not found any CP4BA custom resource in cluster in the project \"$TARGET_PROJECT_NAME\"."
        exit 1
    fi

    info "Checking CP4BA operators upgrade done or not"
    check_operator_status $TEMP_OPERATOR_PROJECT_NAME "full" "channel"

    if [[ " ${CHECK_CP4BA_OPERATOR_RESULT[@]} " =~ "FAIL" ]]; then
        fail "Failed to upgrade CP4BA operators"
    else
        success "CP4BA operators upgraded successfully!"
        info "All CP4BA operators are shutting down before upgrade Zen/IM/CP4BA capabilities!"
        shutdown_operator $TEMP_OPERATOR_PROJECT_NAME
        printf "\n"
        echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}: "
        msg "${YELLOW_TEXT}* Run the script in [upgradeDeployment] mode to upgrade the CP4BA deployment when upgrade CP4BA to $CP4BA_RELEASE_BASE.${RESET_TEXT}"
        msg "# ./cp4a-deployment.sh -m upgradeDeployment -n $TARGET_PROJECT_NAME"
        msg "${YELLOW_TEXT}* Run the script in [upgradeDeploymentStatus] mode directly when upgrade CP4BA from $CP4BA_RELEASE_BASE IFix to IFix.${RESET_TEXT}"
        msg "# ./cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME"
    fi
fi

if [ "$RUNTIME_MODE" == "upgradeDeployment" ]; then
    project_name=$TARGET_PROJECT_NAME

    if which oc >/dev/null 2>&1; then
        CLI_CMD=oc
    elif which kubectl >/dev/null 2>&1; then
        CLI_CMD=kubectl
    else
        echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI or OpenShift CLI. You must install it to run this script.\x1B[0m" && \
        exit 1
    fi

    cp4a_operator_csv_name_target_ns=$(${CLI_CMD} get csv -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
    cp4a_operator_csv_name_allnamespace_ns=$(${CLI_CMD} get csv -n $ALL_NAMESPACE_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')

    if [[ -z $cp4a_operator_csv_name_allnamespace_ns && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
        success "Found IBM Cloud Pak for Business Automation Operator deployed in the project \"$TARGET_PROJECT_NAME\"."
        ALL_NAMESPACE_FLAG="No"
        TEMP_OPERATOR_PROJECT_NAME=$TARGET_PROJECT_NAME
    elif [[ (! -z $cp4a_operator_csv_name_allnamespace_ns) && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
        success "Found IBM Cloud Pak for Business Automation Operator deployed as AllNamespace mode in the project \"$ALL_NAMESPACE_NAME\"."
        ALL_NAMESPACE_FLAG="Yes"
        project_name="openshift-operators"
        TEMP_OPERATOR_PROJECT_NAME="openshift-operators"
    fi

    source ${CUR_DIR}/helper/upgrade/upgrade_merge_yaml.sh $TARGET_PROJECT_NAME

    ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        content_cr_name=$(${CLI_CMD} get content -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
        if [ ! -z $content_cr_name ]; then
            # info "Retrieving existing CP4BA Content (Kind: content.icp4a.ibm.com) Custom Resource"
            cr_type="content"
            cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
            owner_ref=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
            if [[ ${owner_ref} != "ICP4ACluster" ]]; then
                cr_verison=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.appVersion)
                if [[ $cr_verison == "${CP4BA_RELEASE_BASE}" ]]; then
                    warning "The release version of content custom resource \"$content_cr_name\" is already \"$cr_verison\". Exit..."
                    printf "\n"
                    while true; do
                        printf "\x1B[1mDo you want to continue run upgrade? (Yes/No, default: No): \x1B[0m"
                        read -rp "" ans
                        case "$ans" in
                        "y"|"Y"|"yes"|"Yes"|"YES")
                            RERUN_UPGRADE_DEPLOYMENT="Yes"
                            break
                            ;;
                        "n"|"N"|"no"|"No"|"NO"|"")
                            echo "Exiting..."
                            exit 1
                            ;;
                        *)
                            echo -e "Answer must be \"Yes\" or \"No\"\n"
                            ;;
                        esac
                    done
                fi
            fi
        fi
    fi

    icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $icp4acluster_cr_name ]; then
        cr_verison=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.appVersion)
        if [[ $cr_verison == "${CP4BA_RELEASE_BASE}" ]]; then
            warning "The release version of icp4acluster custom resource \"$icp4acluster_cr_name\" is already \"$cr_verison\"."
            printf "\n"
            while true; do
                printf "\x1B[1mDo you want to continue run upgrade? (Yes/No, default: No): \x1B[0m"
                read -rp "" ans
                case "$ans" in
                "y"|"Y"|"yes"|"Yes"|"YES")
                    RERUN_UPGRADE_DEPLOYMENT="Yes"
                    break
                    ;;
                "n"|"N"|"no"|"No"|"NO"|"")
                    echo "Exiting..."
                    exit 1
                    ;;
                *)
                    echo -e "Answer must be \"Yes\" or \"No\"\n"
                    ;;
                esac
            done
        fi
    fi
    # info "Starting to upgrade CP4BA Deployment..."
    # info "Incomming..."

    # trap 'startup_operator $TARGET_PROJECT_NAME' EXIT
    # info "Checking CP4BA operator and dependencies ready or not"
    # check_operator_status $TARGET_PROJECT_NAME
    # if [[ " ${CHECK_CP4BA_OPERATOR_RESULT[@]} " =~ "FAIL" ]]; then
    #     fail "CP4BA or dependency operaotrs is NOT ready all!"
    #     exit 1
    # else
    #     info "The CP4BA and dependency operaotrs is ready for upgrade CP4BA deployment!"
    # fi
    # create_upgrade_property
    # if [[ -z $UPGRADE_MODE ]]; then
    #     cs_dedicated=$(${CLI_CMD} get cm -n ${COMMON_SERVICES_CM_NAMESPACE}  | grep ${COMMON_SERVICES_CM_DEDICATED_NAME} | awk '{print $1}')

    #     cs_shared=$(${CLI_CMD} get cm -n ${COMMON_SERVICES_CM_NAMESPACE}  | grep ${COMMON_SERVICES_CM_SHARED_NAME} | awk '{print $1}')

    #     if [[ "$cs_dedicated" != "" || "$cs_shared" != ""  ]] ; then
    #         control_namespace=$(${CLI_CMD} get cm ${COMMON_SERVICES_CM_DEDICATED_NAME} --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE} -o jsonpath='{ .data.common-service-maps\.yaml }' | grep  'controlNamespace' | cut -d':' -f2 )
    #         control_namespace=$(sed -e 's/^"//' -e 's/"$//' <<<"$control_namespace")
    #         control_namespace=$(sed "s/ //g" <<< $control_namespace)
    #     fi

    #     # For shared to shared, the common-service-maps be created under kube-public also.
    #     # So the script need to check structure of common-service-maps to decide this is shared or dedicated
    #     if [[ ("$cs_dedicated" != "" && "$cs_shared" == "") || (! -z $control_namespace)  ]]; then
    #         UPGRADE_MODE="dedicated2dedicated"
    #     elif [[ $ALL_NAMESPACE_FLAG == "No" ]]; then
    #         # Dedicde upgrade mode by customer
    #         select_upgrade_mode
    #     elif [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
    #         UPGRADE_MODE="shared2shared"
    #         ENABLE_PRIVATE_CATALOG=0
    #         info "Found the IBM Cloud Pak foundational services/IBM Cloud Pak for Business Automation are in all namespaces, IBM Cloud Pak foundational services only can be migrated from \"Cluster-scoped\" to \"Cluster-scoped\"!"
    #     fi
    # fi

    # if [[ $UPGRADE_MODE == "shared2shared" ]]; then
    #     ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$TEMP_OPERATOR_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #     ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"ibm-common-services\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    # elif [[ $UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated" ]]; then
    #     ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #     ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    # fi

    # if [[ "$cs_dedicated" != "" && "$cs_shared" == ""  ]]; then
    #     UPGRADE_MODE="dedicated2dedicated"
    #     ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #     ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    # elif [[ "$cs_dedicated" != "" && "$cs_shared" != "" ]]; then
    #     ${CLI_CMD} get cm ${COMMON_SERVICES_CM_DEDICATED_NAME} --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE} -o jsonpath='{ .data.common-service-maps\.yaml }' > /tmp/common-service-maps.yaml
    #     common_service_namespace=`cat /tmp/common-service-maps.yaml | ${YQ_CMD} r - namespaceMapping.[0].map-to-common-service-namespace`
    #     common_service_flag=`cat /tmp/common-service-maps.yaml | ${YQ_CMD} r - namespaceMapping.[1].map-to-common-service-namespace`
    #     if [[ -z $common_service_flag && $common_service_namespace == "ibm-common-services" ]]; then
    #         UPGRADE_MODE="shared2shared"
    #         ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"ibm-common-services\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #         if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
    #             ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$ALL_NAMESPACE_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #         elif [[ $ALL_NAMESPACE_FLAG == "No" ]]; then
    #             ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #         fi
    #     elif [[ $common_service_flag != ""  ]]; then
    #         UPGRADE_MODE="shared2dedicated"
    #         ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #         ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #     elif [[ $common_service_flag == ""  ]]; then
    #         UPGRADE_MODE="dedicated2dedicated"
    #         ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #         ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #     fi
    # elif  [[ "$cs_dedicated" == "" && "$cs_shared" != "" && $ALL_NAMESPACE_FLAG == "No" ]]; then
    #     # Dedicde upgrade mode by customer
    #     select_upgrade_mode
    #     if [[ $UPGRADE_MODE == "shared2shared" ]]; then
    #         ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$TEMP_OPERATOR_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #         ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"ibm-common-services\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #     elif [[ $UPGRADE_MODE == "shared2dedicated" ]]; then
    #         ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #         ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"$TARGET_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #     fi
    # elif  [[ "$cs_dedicated" == "" && "$cs_shared" != "" && $ALL_NAMESPACE_FLAG == "Yes" ]]; then
    #     UPGRADE_MODE="shared2shared"
    #     ${SED_COMMAND} "s|CS_OPERATOR_NAMESPACE=\"\"|CS_OPERATOR_NAMESPACE=\"$TEMP_OPERATOR_PROJECT_NAME\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    #     ${SED_COMMAND} "s|CS_SERVICES_NAMESPACE=\"\"|CS_SERVICES_NAMESPACE=\"ibm-common-services\"|g" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
    # fi


    # $TARGET_PROJECT_NAME for cp4ba deployment, $TEMP_OPERATOR_PROJECT_NAME for cp4ba operators
    upgrade_deployment $TARGET_PROJECT_NAME $TEMP_OPERATOR_PROJECT_NAME

    echo "${YELLOW_TEXT}[TIPS]${RESET_TEXT}"
    echo "* When run the script in [upgradeDeploymentStatus] mode, the script will detect the Zen/IM ready or not."
    echo "* After the Zen/IM ready, the script will start up all CP4BA operators autmatically."
    printf "\n"
    echo "If the script run in [upgradeDeploymentStatus] mode for checking the Zen/IM timeout, you could check status follow below command."
    msgB "How to check zenService version manually: "
    echo "  # ${CLI_CMD} get zenService $(${CLI_CMD} get zenService --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME |awk '{print $1}') --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.status.currentVersion}'"
    printf "\n"
    msgB "How to check zenService status and progress manually: "
    echo "  # ${CLI_CMD} get zenService $(${CLI_CMD} get zenService --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME |awk '{print $1}') --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.status.zenStatus}'"
    echo "  # ${CLI_CMD} get zenService $(${CLI_CMD} get zenService --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME |awk '{print $1}') --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.status.Progress}'"

    # if [[  " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai" || "${bai_flag}" == "true" ]]; then
    #     printf "\n"
    #     echo -e "\x1B[33;5m[ATTENTION]: \x1B[0m${YELLOW_TEXT}AFTER UPGRADING IBM CLOUD PAK FOR BUSINESS AUTOMATION (CP4BA) DEPLOYMENT SUCCESSFULLY, YOU NEED TO REMOVE${RESET_TEXT} ${RED_TEXT}\"recovery_path\"${RESET_TEXT} ${YELLOW_TEXT}FROM CUSTOM RESOURCE UNDER${RESET_TEXT} ${RED_TEXT}\"bai_configuration\"${RESET_TEXT} ${YELLOW_TEXT}MANUALLY IF EXISTING.${RESET_TEXT}"
    # fi

    # if [[ $CONTENT_CR_EXIST == "Yes" || " ${EXISTING_PATTERN_ARR[@]}" =~ "workflow-runtime" || " ${EXISTING_PATTERN_ARR[@]}" =~ "workflow-authoring" || " ${EXISTING_PATTERN_ARR[@]}" =~ "content" || " ${EXISTING_PATTERN_ARR[@]}" =~ "document_processing" || "${EXISTING_OPT_COMPONENT_ARR[@]}" =~ "ae_data_persistence" ]]; then
    #     printf "\n"
    #     echo -e "\x1B[33;5m[ATTENTION]: \x1B[0m${YELLOW_TEXT}AFTER UPGRADING IBM CLOUD PAK FOR BUSINESS AUTOMATION (CP4BA) DEPLOYMENT SUCCESSFULLY, YOU NEED TO RUN${RESET_TEXT} ${RED_TEXT}\"./cp4a-pre-upgrade-and-post-upgrade-optional.sh post-upgrade\"${RESET_TEXT}, ${YELLOW_TEXT}AND THEN CLEAN BROWSER COOKIE BEFORE LOGIN${RESET_TEXT} ${RED_TEXT}[NOTES: DO NOT need to run it when upgrade CP4BA from 23.0.2.X to 24.0.0 (migration IBM Cloud Pak foundational services from Cluster-scoped -> Cluster-scoped or Namespace-scoped -> Namespace-scoped)]${RESET_TEXT}"
    # fi
fi

if [[ "$RUNTIME_MODE" == "upgradeDeploymentStatus" ]]; then
    UPGRADE_DEPLOYMENT_FOLDER=${CUR_DIR}/cp4ba-upgrade/project/$TARGET_PROJECT_NAME
    TEMP_CP_CONSOLE_FILE=${UPGRADE_DEPLOYMENT_FOLDER}/original-cp-console.yaml
    TEMP_CP_CONSOLE_FILE_ID_PROVIDER=${UPGRADE_DEPLOYMENT_FOLDER}/id-provider-cp-console.yaml
    TEMP_CP_CONSOLE_FILE_ID_MGMT=${UPGRADE_DEPLOYMENT_FOLDER}/id-mgmt-cp-console.yaml
    source ${CUR_DIR}/helper/upgrade/upgrade_merge_yaml.sh $TARGET_PROJECT_NAME

    CP_CONSOLE='cp-console'
    ID_PROVIDER_ROUTE_NAME='cp-console-iam-provider'
    ID_PROVIDER_PATH='/idprovider/'
    ID_MGMT_ROUTE_NAME='cp-console-iam-idmgmt'
    ID_MGMT_PATH='/idmgmt/'

    function get_default_cp_console_route() {

        if [ ! -d $UPGRADE_DEPLOYMENT_FOLDER ]; then
            mkdir $UPGRADE_DEPLOYMENT_FOLDER
        fi

        rm -fr $TEMP_CP_CONSOLE_FILE
        local tmp_cp_console=$( ${CLI_CMD} get route $CP_CONSOLE --no-headers --ignore-not-found  -n $TARGET_PROJECT_NAME_CS | awk '{print $1}' )
        if [ -n $tmp_cp_console  ]; then
            # echo -e "${BLUE}Creating backup yaml for route $CP_CONSOLE${COLOR_OFF}"
            ${CLI_CMD} get route $CP_CONSOLE -o yaml -n $TARGET_PROJECT_NAME_CS > $TEMP_CP_CONSOLE_FILE
            CP_CONSOLE_HOST=$(${YQ_CMD} r $TEMP_CP_CONSOLE_FILE spec.host )
            ID_MGMT_CP_CONSOLE=$( echo "id-mgmt-${CP_CONSOLE_HOST}" | sed   "s/-$TARGET_PROJECT_NAME_CS//g" )
            ID_PROVIDER_CP_CONSOLE=$( echo "id-provider-${CP_CONSOLE_HOST}" | sed  "s/-$TARGET_PROJECT_NAME_CS//g")
            cp $TEMP_CP_CONSOLE_FILE $TEMP_CP_CONSOLE_FILE_ID_PROVIDER
            cp $TEMP_CP_CONSOLE_FILE $TEMP_CP_CONSOLE_FILE_ID_MGMT
        else
            warning "Could not find the route \"$CP_CONSOLE\" in the project \"$TARGET_PROJECT_NAME_CS\""
            return 1
        fi
        return 0
    }

    function create_custom_idprovider_route() {

        if [ -a ${TEMP_CP_CONSOLE_FILE_ID_PROVIDER} ]; then

            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.name "$ID_PROVIDER_ROUTE_NAME"
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER spec.path "$ID_PROVIDER_PATH"
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER spec.host "$ID_PROVIDER_CP_CONSOLE"
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.labels.path "idprovider"


            ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.ownerReferences
            ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.uid
            ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.resourceVersion
            ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER status
            ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.creationTimestamp

            if [[ "$1" == "platform-identity-provider" ]]; then
            ${SED_COMMAND} "s/-$TARGET_PROJECT_NAME_CS//g" $TEMP_CP_CONSOLE_FILE_ID_PROVIDER
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER spec.to.name "platform-identity-provider"
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER spec.port.targetPort "4300"
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER 'metadata.annotations."haproxy.router.openshift.io/rewrite-target"' '/'
            fi

            # echo -e "Creating new route named $ID_PROVIDER_ROUTE_NAME"
            ${CLI_CMD} apply -f $TEMP_CP_CONSOLE_FILE_ID_PROVIDER -n $TARGET_PROJECT_NAME_CS >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                warning "Failed to create route named $ID_PROVIDER_ROUTE_NAME in the project \"$TARGET_PROJECT_NAME_CS\"!"
                exit 1
            fi
        else
            fail "File not found: ${TEMP_CP_CONSOLE_FILE_ID_PROVIDER}"
            return -1
        fi

        return 0

    }

    function create_custom_idmgmt_route() {

        if [ -a ${TEMP_CP_CONSOLE_FILE_ID_MGMT} ]; then

            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.name "$ID_MGMT_ROUTE_NAME"
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.labels.path "idmgmt"
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT spec.path "$ID_MGMT_PATH"
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT spec.host "$ID_MGMT_CP_CONSOLE"

            ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.ownerReferences
            ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.uid
            ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.resourceVersion
            ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_MGMT status
            ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.creationTimestamp

            if [[ "$1" == "platform-identity-management" ]]; then
            ${SED_COMMAND} "s/-$TARGET_PROJECT_NAME_CS//g" $TEMP_CP_CONSOLE_FILE_ID_MGMT
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT spec.to.name "platform-identity-management"
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT spec.port.targetPort "4500"
            ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT 'metadata.annotations."haproxy.router.openshift.io/rewrite-target"' '/'

            fi

            # echo -e "Creating new route named $ID_MGMT_ROUTE_NAME"
            ${CLI_CMD} apply -f $TEMP_CP_CONSOLE_FILE_ID_MGMT -n $TARGET_PROJECT_NAME_CS >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                warning "Failed to create route named $ID_MGMT_ROUTE_NAME in the project \"$TARGET_PROJECT_NAME_CS\"!"
                exit 1
            fi
        else
            fail "File not found: ${TEMP_CP_CONSOLE_FILE_ID_MGMT}"
            return -1
        fi
        return 0
    }

    project_name=$TARGET_PROJECT_NAME
    if which oc >/dev/null 2>&1; then
        CLI_CMD=oc
    elif which kubectl >/dev/null 2>&1; then
        CLI_CMD=kubectl
    else
        echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI or OpenShift CLI. You must install it to run this script.\x1B[0m" && \
        exit 1
    fi

    cp4a_operator_csv_name_target_ns=$(${CLI_CMD} get csv -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
    cp4a_operator_csv_name_allnamespace_ns=$(${CLI_CMD} get csv -n $ALL_NAMESPACE_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')

    if [[ -z $cp4a_operator_csv_name_allnamespace_ns && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
        success "Found IBM Cloud Pak for Business Automation Operator deployed in the project \"$TARGET_PROJECT_NAME\"."
        ALL_NAMESPACE_FLAG="No"
        TEMP_OPERATOR_PROJECT_NAME=$TARGET_PROJECT_NAME
    elif [[ (! -z $cp4a_operator_csv_name_allnamespace_ns) && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
        success "Found IBM Cloud Pak for Business Automation Operator deployed as AllNamespace mode in the project \"$ALL_NAMESPACE_NAME\"."
        ALL_NAMESPACE_FLAG="Yes"
        project_name="openshift-operators"
        TEMP_OPERATOR_PROJECT_NAME="openshift-operators"
    fi

    ${CLI_CMD} get crd | grep contents.icp4a.ibm.com >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        content_cr_name=$(${CLI_CMD} get content -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
        if [[ ! -z $content_cr_name ]]; then
            # info "Retrieving existing CP4BA Content (Kind: content.icp4a.ibm.com) Custom Resource"
            cr_type="content"
            cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
            owner_ref=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
            if [[ "$owner_ref" != "ICP4ACluster" ]]; then
                CONTENT_CR_EXIST="Yes"
                info "Scaling up \"IBM CP4BA FileNet Content Manager\" operator"
                ${CLI_CMD} scale --replicas=1 deployment ibm-content-operator -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    sleep 1
                else
                    fail "Failed to scale up \"IBM CP4BA FileNet Content Manager\" operator"
                fi

                info "Scaling up \"IBM CP4BA Foundation\" operator"
                ${CLI_CMD} scale --replicas=1 deployment icp4a-foundation-operator -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    sleep 1
                else
                    fail "Failed to scale up \"IBM CP4BA Foundation\" operator"
                fi
                cr_verison=$(${CLI_CMD} get content $content_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.appVersion)
                if [[ $cr_verison != "${CP4BA_RELEASE_BASE}" ]]; then
                    fail "The release version: \"$cr_verison\" in content custom resource \"$content_cr_name\" is not correct, please apply new version of CR first."
                    exit 1
                fi
            else
                CONTENT_CR_EXIST="No"
            fi
        fi
    fi

    icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $icp4acluster_cr_name ]; then
        info "Scaling up \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator"
        ${CLI_CMD} scale --replicas=1 deployment ibm-cp4a-operator -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            sleep 1
        else
            fail "Failed to scale up \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator"
        fi

        info "Scaling up \"IBM CP4BA FileNet Content Manager\" operator"
        ${CLI_CMD} scale --replicas=1 deployment ibm-content-operator -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            sleep 1
        else
            fail "Failed to scale up \"IBM CP4BA FileNet Content Manager\" operator"
        fi

        info "Scaling up \"IBM CP4BA Foundation\" operator"
        ${CLI_CMD} scale --replicas=1 deployment icp4a-foundation-operator -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            sleep 1
        else
            fail "Failed to scale up \"IBM CP4BA Foundation\" operator"
        fi

        cr_verison=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - spec.appVersion)
        if [[ $cr_verison != "${CP4BA_RELEASE_BASE}" ]]; then
            fail "The release version: \"$cr_verison\" in icp4acluster custom resource \"$icp4acluster_cr_name\" is not correct, please apply new version of CR first."
            exit 1
        fi
    fi
    # info "Scaling up \"IBM CP4BA FileNet Content Manager\" operator"
    # ${CLI_CMD} scale --replicas=1 deployment ibm-content-operator -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
    # if [ $? -eq 0 ]; then
    #     sleep 1
    #     echo "Done!"
    # else
    #     fail "Failed to scale up \"IBM CP4BA FileNet Content Manager\" operator"
    # fi
    # info "Scaling up \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator"
    # ${CLI_CMD} scale --replicas=1 deployment ibm-cp4a-operator -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
    # if [ $? -eq 0 ]; then
    #     sleep 1
    #     echo "Done!"
    # else
    #     fail "Failed to scale up \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator"
    # fi

    # info "Scaling up \"IBM CP4BA Foundation\" operator"
    # ${CLI_CMD} scale --replicas=1 deployment icp4a-foundation-operator -n $TEMP_OPERATOR_PROJECT_NAME >/dev/null 2>&1
    # if [ $? -eq 0 ]; then
    #     sleep 1
    #     echo "Done!"
    # else
    #     fail "Failed to scale up \"IBM CP4BA Foundation\" operator"
    # fi

    while true; do
        clear
        isReady_cp4ba=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.data.cp4ba_operator_of_last_reconcile}')
        isReady_foundation=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.data.foundation_operator_of_last_reconcile}')
        if [[ -z "$isReady_cp4ba" && -z "$isReady_foundation" ]]; then
            CP4BA_DEPLOYMENT_STATUS="Getting Upgrade Status ..."
            printf '%s %s\n' "$(date)" "[refresh interval: 30s]"
            echo -en "[Press Ctrl+C to exit] \t\t"
            printHeaderMessage "CP4BA Upgrade Status"
            echo -en "${GREEN_TEXT}$CP4BA_DEPLOYMENT_STATUS${RESET_TEXT}"
            sleep 30
        else
            break
        fi
    done

   # check for zenStatus and currentverison for zen

    zen_service_name=$(${CLI_CMD} get zenService --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME |awk '{print $1}')
    if [[ ! -z "$zen_service_name" ]]; then
        clear
        maxRetry=120
        for ((retry=0;retry<=${maxRetry};retry++)); do
            zenservice_version=$(${CLI_CMD} get zenService $zen_service_name --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.status.currentVersion}')
            isCompleted=$(${CLI_CMD} get zenService $zen_service_name --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.status.zenStatus}')
            isProgressDone=$(${CLI_CMD} get zenService $zen_service_name --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath='{.status.Progress}')

            if [[ "$isCompleted" != "Completed" || "$isProgressDone" != "100%" || "$zenservice_version" != "${ZEN_OPERATOR_VERSION//v/}" ]]; then
                clear
                CP4BA_DEPLOYMENT_STATUS="Waiting for the zenService to be ready (could take up to 120 minutes) before upgrade the CP4BA capabilities..."
                printf '%s %s\n' "$(date)" "[refresh interval: 60s]"
                echo -en "[Press Ctrl+C to exit] \t\t"
                printf "\n"
                echo "${YELLOW_TEXT}$CP4BA_DEPLOYMENT_STATUS${RESET_TEXT}"
                printHeaderMessage "CP4BA Upgrade Status"
                if [[ "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
                    echo "zenService Version (${ZEN_OPERATOR_VERSION//v/})       : ${GREEN_TEXT}$zenservice_version${RESET_TEXT}"
                else
                    echo "zenService Version (${ZEN_OPERATOR_VERSION//v/})       : ${RED_TEXT}$zenservice_version${RESET_TEXT}"
                fi
                if [[ "$isCompleted" == "Completed" && "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
                    echo "zenService Status (Completed)    : ${GREEN_TEXT}$isCompleted${RESET_TEXT}"
                else
                    echo "zenService Status (Completed)    : ${RED_TEXT}$isCompleted${RESET_TEXT}"
                fi

                if [[ "$isProgressDone" == "100%" && "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
                    echo "zenService Progress (100%)       : ${GREEN_TEXT}$isProgressDone${RESET_TEXT}"
                else
                    echo "zenService Progress (100%)       : ${RED_TEXT}$isProgressDone${RESET_TEXT}"
                fi
                sleep 60
            elif [[ "$isCompleted" == "Completed" && "$isProgressDone" == "100%" && "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
                break
            elif [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for the Zen Service to start"
                echo -e "\x1B[1mPlease check the status of the Zen Service\x1B[0m"
                printf "\n"
                exit 1
            fi
        done
        clear
        # success "The Zen Service (${ZEN_OPERATOR_VERSION//v/}) is ready for CP4BA"
        CP4BA_DEPLOYMENT_STATUS="The Zen Service (${ZEN_OPERATOR_VERSION//v/}) is ready for CP4BA"
        printf '%s %s\n' "$(date)" "[refresh interval: 30s]"
        echo -en "[Press Ctrl+C to exit] \t\t"
        printf "\n"
        echo "${YELLOW_TEXT}$CP4BA_DEPLOYMENT_STATUS${RESET_TEXT}"
        info "Starting all CP4BA Operators to upgrade CP4BA capabilities"
        printHeaderMessage "CP4BA Upgrade Status"
        if [[ "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
            echo "zenService Version        : ${GREEN_TEXT}$zenservice_version${RESET_TEXT}"
        else
            echo "zenService Version        : ${RED_TEXT}$zenservice_version${RESET_TEXT}"
        fi
        if [[ "$isCompleted" == "Completed" ]]; then
            echo "zenService Status         : ${GREEN_TEXT}$isCompleted${RESET_TEXT}"
        else
            echo "zenService Status         : ${RED_TEXT}$isCompleted${RESET_TEXT}"
        fi

        if [[ "$isProgressDone" == "100%" && "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
            echo "zenService Progress       : ${GREEN_TEXT}$isProgressDone${RESET_TEXT}"
        else
            echo "zenService Progress       : ${RED_TEXT}$isProgressDone${RESET_TEXT}"
        fi

        ## Create tow route after zenService ready
        TARGET_PROJECT_NAME_CS=$(${CLI_CMD} get route --no-headers --ignore-not-found  -A |grep  cp-console-iam-provider|awk '{print $1}')
        if [[ -z $TARGET_PROJECT_NAME_CS ]]; then
            warning "Not found cp-console-iam-provider in the cluster. continue..."
        else
            get_default_cp_console_route
            res=$?
            if [[ ${res} == "0" ]]; then
                create_custom_idprovider_route "platform-identity-provider"
                create_custom_idmgmt_route "platform-identity-management"
            fi
        fi
        
        # start all cp4ba operators after zen/im ready
        startup_operator $TEMP_OPERATOR_PROJECT_NAME "silent"
        sleep 10

        ## Apply workaround for https://jsw.ibm.com/browse/DBACLD-137719 before start migration CPfs
        ## keep to scale down ibm-bts-operator-controller-manager in ibm-common-services project after zenService ready
        bts_operator_name=$(${CLI_CMD} get deployment ibm-bts-operator-controller-manager --no-headers --ignore-not-found -n ibm-common-services -o name)
        if [[ ! -z $bts_operator_name ]]; then
            ${CLI_CMD} scale --replicas=0 deployment ibm-bts-operator-controller-manager -n ibm-common-services >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                warning "Failed to scale down ibm-bts-operator-controller-manager operator in the project \"ibm-common-services\". Please scale down ibm-bts-operator-controller-manager operator manually."
            fi
        fi
    else
        fail "No found the zenService in the project \"$TARGET_PROJECT_NAME\", exit..."
        echo "****************************************************************************"
        exit 1
    fi

    # show_cp4ba_upgrade_status
    while true
    do
        printf '%s\n' "$(clear; show_cp4ba_upgrade_status)"
        sleep 30
    done
fi

if [ "$RUNTIME_MODE" == "upgradePostconfig" ]; then
    project_name=$TARGET_PROJECT_NAME
    if which oc >/dev/null 2>&1; then
        CLI_CMD=oc
    elif which kubectl >/dev/null 2>&1; then
        CLI_CMD=kubectl
    else
        echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI or OpenShift CLI. You must install it to run this script.\x1B[0m" && \
        exit 1
    fi
    UPGRADE_DEPLOYMENT_FOLDER=${CUR_DIR}/cp4ba-upgrade/project/$project_name
    UPGRADE_DEPLOYMENT_PROPERTY_FILE=${UPGRADE_DEPLOYMENT_FOLDER}/cp4ba_upgrade.property

    UPGRADE_DEPLOYMENT_CR=${UPGRADE_DEPLOYMENT_FOLDER}/custom_resource
    UPGRADE_DEPLOYMENT_CR_BAK=${UPGRADE_DEPLOYMENT_CR}/backup

    UPGRADE_DEPLOYMENT_CONTENT_CR=${UPGRADE_DEPLOYMENT_CR}/content.yaml
    UPGRADE_DEPLOYMENT_CONTENT_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.content_tmp.yaml
    UPGRADE_DEPLOYMENT_CONTENT_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/content_cr_backup.yaml

    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR=${UPGRADE_DEPLOYMENT_CR}/icp4acluster.yaml
    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.icp4acluster_tmp.yaml
    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/icp4acluster_cr_backup.yaml

    mkdir -p ${UPGRADE_DEPLOYMENT_CR} >/dev/null 2>&1
    mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK} >/dev/null 2>&1

    source ${CUR_DIR}/helper/upgrade/upgrade_merge_yaml.sh $TARGET_PROJECT_NAME

    info "Starting to execute script for post CP4BA upgrade"
    # Retrieve existing WfPSRuntime CR
    exist_wfps_cr_array=($(${CLI_CMD} get WfPSRuntime -n $TARGET_PROJECT_NAME --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_wfps_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            info "Retrieving existing IBM CP4BA Workflow Process Service (Kind: WfPSRuntime.icp4a.ibm.com) Custom Resource: \"${item}\""
            cr_type="WfPSRuntime"
            cr_metaname=$(${CLI_CMD} get $cr_type ${item} -n $TARGET_PROJECT_NAME -o yaml | ${YQ_CMD} r - metadata.name)
            UPGRADE_DEPLOYMENT_WFPS_CR=${UPGRADE_DEPLOYMENT_CR}/wfps_${cr_metaname}.yaml
            UPGRADE_DEPLOYMENT_WFPS_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.wfps_${cr_metaname}_tmp.yaml
            UPGRADE_DEPLOYMENT_WFPS_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/wfps_cr_${cr_metaname}_backup.yaml

            ${CLI_CMD} get $cr_type ${item} -n $TARGET_PROJECT_NAME -o yaml > ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # Backup existing WfPSRuntime CR
            mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} ${UPGRADE_DEPLOYMENT_WFPS_CR_BAK}

            info "Merging existing IBM CP4BA Workflow Process Service custom resource: \"${item}\" with new version ($CP4BA_RELEASE_BASE)"
            # Delete unnecessary section in CR
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} status
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.annotations
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.creationTimestamp
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.generation
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.resourceVersion
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.uid

            # replace release/appVersion
            # ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_PFS_CR_TMP}
            ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # # change failureThreshold/periodSeconds for WfPS after upgrade
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} spec.node.probe.startupProbe.failureThreshold 80
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} spec.node.probe.startupProbe.periodSeconds 5

            ${SED_COMMAND} "s|'\"|\"|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            ${SED_COMMAND} "s|\"'|\"|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}


            success "Completed to merge existing IBM CP4BA Workflow Process Service custom resource with new version ($CP4BA_RELEASE_BASE)"
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} ${UPGRADE_DEPLOYMENT_WFPS_CR}

            info "Apply the new version ($CP4BA_RELEASE_BASE) of IBM CP4BA Workflow Process Service custom resource"
            ${CLI_CMD} annotate WfPSRuntime ${item} kubectl.kubernetes.io/last-applied-configuration- -n $TARGET_PROJECT_NAME >/dev/null 2>&1
            sleep 3
            ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_WFPS_CR} -n $TARGET_PROJECT_NAME >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                fail "IBM CP4BA Workflow Process Service custom resource update failed"
                exit 1
            else
                echo "Done!"

                printf "\n"
                echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
                msgB "Run \"cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME\" to get overview upgrade status for IBM CP4BA Workflow Process Service"
            fi
        done
    fi

    # # Retrieve existing Content CR for remove route cp-console-iam-provider/cp-console-iam-idmgmt
    # content_cr_name=$(${CLI_CMD} get content -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    # if [ ! -z $content_cr_name ]; then
    #     info "Retrieving existing CP4BA Content (Kind: content.icp4a.ibm.com) Custom Resource"
    #     cr_type="content"
    #     cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $project_name -o yaml | ${YQ_CMD} r - metadata.name)
    #     owner_ref=$(${CLI_CMD} get content $content_cr_name -n $project_name -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
    #     if [[ ${owner_ref} != "ICP4ACluster" ]]; then
    #         iam_idprovider=$(${CLI_CMD} get route -n $project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-provider)
    #         iam_idmgmt=$(${CLI_CMD} get route -n $project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-idmgmt)
    #         if [[ ! -z $iam_idprovider ]]; then
    #             info "Remove \"cp-console-iam-provider\" route from project \"$project_name\"."
    #             ${CLI_CMD} delete route $iam_idprovider -n $project_name >/dev/null 2>&1
    #         fi
    #         if [[ ! -z $iam_idmgmt ]]; then
    #             info "Remove \"cp-console-iam-idmgmt\" route from project \"$project_name\"."
    #             ${CLI_CMD} delete route $iam_idmgmt -n $project_name >/dev/null 2>&1
    #         fi
    #     fi
    # fi
    # Retrieve existing ICP4ACluster CR for ADP post upgrade
    icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $icp4acluster_cr_name ]; then
        info "Retrieving existing CP4BA ICP4ACluster (Kind: icp4acluster.icp4a.ibm.com) Custom Resource"
        cr_type="icp4acluster"
        cr_metaname=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $project_name -o yaml | ${YQ_CMD} r - metadata.name)
        ${CLI_CMD} get $cr_type $icp4acluster_cr_name -n $project_name -o yaml > ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        # Backup existing icp4acluster CR
        mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
        ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK}

        convert_olm_cr "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        if [[ $olm_cr_flag == "No" ]]; then
            # Get EXISTING_PATTERN_ARR/EXISTING_OPT_COMPONENT_ARR
            existing_pattern_list=""
            existing_opt_component_list=""

            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
            existing_opt_component_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`

            OIFS=$IFS
            IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
            IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
            IFS=$OIFS
        fi

        # Remove cp-console-iam-provider/cp-console-iam-idmgmt
        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || ("${EXISTING_OPT_COMPONENT_ARR[@]}" =~ "ae_data_persistence") || ("${EXISTING_OPT_COMPONENT_ARR[@]}" =~ "baw_authoring") ]]; then
            iam_idprovider=$(${CLI_CMD} get route -n $project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-provider)
            iam_idmgmt=$(${CLI_CMD} get route -n $project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-idmgmt)
            if [[ ! -z $iam_idprovider ]]; then
                info "Remove \"cp-console-iam-provider\" route from project \"$project_name\"."
                ${CLI_CMD} delete route $iam_idprovider -n $project_name >/dev/null 2>&1
            fi
            if [[ ! -z $iam_idmgmt ]]; then
                info "Remove \"cp-console-iam-idmgmt\" route from project \"$project_name\"."
                ${CLI_CMD} delete route $iam_idmgmt -n $project_name >/dev/null 2>&1
            fi
        fi
    fi
    success "Completed to execute script for post CP4BA upgrade"
fi
