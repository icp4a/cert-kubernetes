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

# Open file descriptor 3 for suppressing output
exec 3>/dev/null

# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh


function show_help() {
    echo
    echo "Usage:"
    echo
    echo " ${CUR_DIR}/cp4a-deployment.sh -m [modetype] -n <CP4BA_NAMESPACE>"
    echo " ${CUR_DIR}/cp4a-deployment.sh -n <CP4BA_NAMESPACE>"
    echo
    echo "Options:"
    echo
    echo "  -h  Display the help."
    echo
    echo "  -m  Optional: The valid mode types are:[upgradeOperator], [upgradeOperatorStatus], [upgradeDeployment] and [upgradeDeploymentStatus]."
    echo
    echo "  -n  Required: The target namespace of the CP4BA deployment. "
    echo "                If CP4BA is deployed using separate namespaces for operators and operands/services and the script is being used for either upgrade or for generating a custom resource file, the value is the namespace where the CP4BA services/operands are deployed."
    echo
    echo "  -i  Optional: Operator image name. By default, it is icr.io/cpopen/icp4a-operator:$CP4BA_RELEASE_BASE"
    echo
    echo "  -p  Optional: Pull secret to use to connect to the registry. By default, it is ibm-entitlement-key"
    echo
    echo "  --java-path  Optional: Path to Java (JRE) installation directory (e.g., /usr/lib/jvm/java-17-openjdk)"
    echo
    echo "  --enable-private-catalog Optional: Set this flag to switch the CatalogSource from global to namespace-scoped. By default it is in openshift-marketplace namespace."
    echo
    echo "Additional Information:"
    echo
    echo "  ${YELLOW_TEXT}* To create a custom resource file for a new CP4BA deployment, follow these step:${RESET_TEXT}"
    echo "      - STEP 1: Run the script with \"-n <CP4BA_NAMESPACE>\"."
    echo "  ${YELLOW_TEXT}* Running the script to upgrade a CP4BA deployment from $(IFS=', '; echo "${MINIMUM_SUPPORTED_UPGRADE_VERSIONS[*]}") or newer to $CP4BA_RELEASE_BASE-$CP4BA_PATCH_VERSION. You must run the modes in the following order:${RESET_TEXT}"
    echo "      - STEP 1 (Required): Run the script in [upgradeOperator] mode to upgrade CP4BA operators/migrate (Cluster-scoped -> Cluster-scoped [AllNamespaces] / Namespace-scoped -> Namespace-scoped) the IBM Cloud Pak foundational services and then shutdown all CP4BA operators before upgrade CP4BA deployment."
    echo "      - STEP 2 (Optional): Run the script in [upgradeOperatorStatus] mode to verify the upgrade of CP4BA operators and dependencies."
    echo "      - STEP 3 (Required): Run the script in [upgradeDeployment] mode to upgrade the CP4BA deployment. The script will generate the new version of the custom resource, which can be reviewed and modified offline, or applied directly without modification."
    echo "      - STEP 4 (Required): Run the script in [upgradeDeploymentStatus] mode to start the necessary CP4BA operators to upgrade the dependent service (zenService) first, then start all CP4BA operators to complete the upgrade of the CP4BA deployment, while also verifying the success of the upgrade."
    # echo "      - STEP 5 (Required): Run the script in [upgradePostconfig] mode to show the configuration after the CP4BA deployment upgrade."
    echo "  ${YELLOW_TEXT}* To upgrade a CP4BA deployment from $CP4BA_RELEASE_BASE GA/$CP4BA_RELEASE_BASE.X to $CP4BA_RELEASE_BASE.X, follow these steps in order:${RESET_TEXT}"
    echo "      - STEP 1 (Required): Run the script in [upgradeOperator] mode to upgrade the IBM Cloud Pak foundational services and CP4BA operators, then shutdown all CP4BA operators before upgrading the CP4BA deployment."
    echo "      - STEP 2 (Optional): Run the script in [upgradeOperatorStatus] mode to confirm the upgrade of CP4BA operators and dependencies."
    echo "      - STEP 3 (Required): Run the script in [upgradeDeploymentStatus] mode to start the necessary CP4BA operators to upgrade the dependent service (zenService) first, then restart all CP4BA operators to complete the upgrade, while verifying the success of the upgrade."
}

function parse_arguments() {
    while [[ "$@" != "" ]]; do
        case "$1" in
        -m)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -m flag requires an argument"
                exit 1
            fi
            RUNTIME_MODE=$1
            if [[ $RUNTIME_MODE == "upgradeOperator" || $RUNTIME_MODE == "upgradeOperatorStatus" || $RUNTIME_MODE == "upgradeDeployment" || $RUNTIME_MODE == "upgradeDeploymentStatus" ]]; then
                : # Null command - validation passed, continue execution
            else
                printf '%b\n' "Provide a valid argument for -m: [upgradeOperator] or [upgradeOperatorStatus] or [upgradeDeployment] or [upgradeDeploymentStatus]"
                exit 1
            fi
            ;;
        -n)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -n flag requires an argument"
                exit 1
            fi
            TARGET_PROJECT_NAME=$1
            case "$TARGET_PROJECT_NAME" in
            "")
                printf '%b\n' "\x1B[1;31mEnter a valid namespace name, namespace name can not be blank\x1B[0m"
                exit 1
                ;;
            "openshift"*)
                printf '%b\n' "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
                exit 1
                ;;
            "kube"*)
                printf '%b\n' "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
                exit 1
                ;;
            *)
                # Check cluster login
                check_cluster_login
                # Check project name
                isProjExists=`${CLI_CMD} get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l`  >/dev/null 2>&1
                if [ $isProjExists -ne 2 ] ; then
                    printf '%b\n' "\x1B[1;31mInvalid project name \"$TARGET_PROJECT_NAME\", enter a valid name...\x1B[0m"
                    exit 1
                fi
                : # Null command - validation passed, continue execution
                ;;
            esac
            ;;
        -i)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -i flag requires an argument"
                exit 1
            fi
            IMAGEREGISTRY=$1
            ;;
        -p)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -p flag requires an argument"
                exit 1
            fi
            PULLSECRET=$1
            ;;
        -h | --help | \?)
            show_help
            exit 0
            ;;
        --java-path)
            shift
            if [ -z "$1" ]; then
                echo "Invalid option: --java-path flag requires an argument"
                exit 1
            fi
            CUSTOM_JAVA_PATH=$1
            ;;
        --java-path=*)
            CUSTOM_JAVA_PATH="${1#*=}"
            if [ -z "$CUSTOM_JAVA_PATH" ]; then
                echo "Invalid option: --java-path flag requires an argument"
                exit 1
            fi
            ;;
        --enable-private-catalog)
            ENABLE_PRIVATE_CATALOG=1
            ;;
        --silent)
            SKIP_FOR_API=true
            ;;
        --airgap-deployment)
            AIRGAP_INSTALL=yes
            ;;
        --original-cp4ba-csv-ver)
            shift
            CP4BA_ORIGINAL_CSV_VERSION=$1
            ;;
        --cpfs-upgrade-mode)
            shift
            UPGRADE_MODE=$1
            ;;
        --fncm-license)
            shift
            UPDATED_FNCM_LICENSE=$1
            ;;
        dev)
        SCRIPT_MODE="dev"
        ;;
        review)
        SCRIPT_MODE="review"
        ;;
        baw-dev)
        SCRIPT_MODE="baw-dev"
        ;;
        baw)
        SCRIPT_MODE="baw"
        ;;
        #This is an internal flag that allow direct upgrade from the upgrade_blocked_versions list to 24.0.1. This flag can be used to skip logic that related to skip version upgrade.
        allow_direct_upgrade)
        ALLOW_DIRECT_UPGRADE=1
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

parse_arguments "$@"
# if [[ -z "$RUNTIME_MODE" ]]; then
#     printf '%b\n' "\x1B[1;31mInput value for \"-m <MODE_NAME>\" option.\n\x1B[0m"
#     exit 1
# fi
if [[ -z "$TARGET_PROJECT_NAME" ]]; then
    printf '%b\n' "\x1B[1;31mInput value for \"-n <CP4BA_NAMESPACE>\" option.\n\x1B[0m"
    show_help
    exit 1
fi

# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh $TARGET_PROJECT_NAME

# Initialize logging early (for FastAPI integration - outputs LOGFILE to stderr immediately)
save_log "cp4a-script-logs/project/$TARGET_PROJECT_NAME" "cp4a-deployment-log" "true"
trap cleanup_log EXIT

# Import variables for property file
source ${CUR_DIR}/helper/cp4ba-property.sh

DOCKER_RES_SECRET_NAME="ibm-entitlement-key"
DOCKER_REG_USER=""

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
# FINAL_CR_FOLDER is now defined in common.sh

DEPLOY_TYPE_IN_FILE_NAME="" # Default value is empty
OPERATOR_FILE=${PARENT_DIR}/descriptors/operator.yaml
OPERATOR_FILE_TMP=$TEMP_FOLDER/.operator_tmp.yaml
OPERATOR_FILE_BAK=$BAK_FOLDER/.operator.yaml
REDIS_SUBSCRIPTION=${PARENT_DIR}/descriptors/op-olm/redis-subscription.yaml
REDIS_SUBSCRIPTION_TMP=${TEMP_FOLDER}/.redis-subscription.yaml

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
# TARGET_PROJECT_NAME=""

FOUNDATION_CR_SELECTED=""
optional_component_arr=()
optional_component_cr_arr=()
foundation_component_arr=()
FOUNDATION_FULL_ARR=("BAN" "RR" "BAS" "UMS" "AE")
OPTIONAL_COMPONENT_FULL_ARR=("content_integration" "workstreams" "case" "ban" "bai" "css" "cmis" "es" "ier" "iccsap" "tm" "ums" "ads_designer" "ads_runtime" "app_designer" "decisionCenter" "decisionServerRuntime" "decisionRunner" "ae_data_persistence" "baw_authoring" "pfs" "baml" "auto_service" "document_processing_runtime" "document_processing_designer" "wfps_authoring" "kafka" "opensearch" "workflow_runtime_mcp_server" "application_connectors")

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

    
    printf '%b\n' "\x1B[1;31mIMPORTANT: Review the IBM Cloud Pak for Business Automation license information here: \n\x1B[0m"
    printf '%b\n' "\x1B[1;31mhttps://www.ibm.com/support/customer/csol/terms/?id=L-VFRQ-EPLMC3\n\x1B[0m"
    printf '%b\n' "\x1B[1mIf you are selecting BAW capabilities, please refer to the additional license agreement here: \n\x1B[0m"
    printf '%b\n' "\x1B[1;31mhttps://www.ibm.com/support/customer/csol/terms/?id=L-BKWX-VWBQKW\n\x1B[0m"
    INSTALL_BAW_ONLY="No"


    prompt_press_any_key_to_continue

    printf "\n"
    while true; do

        printf "\x1B[1mDo you accept the IBM Cloud Pak for Business Automation license (Yes/No, default: No): \x1B[0m"
        if  [[ $CP4BA_LICENSE_ACCEPT == "Accept" || $CP4BA_LICENSE_ACCEPT == "accept" || $CP4BA_LICENSE_ACCEPT == "ACCEPT"   ]]; then
            ans='Yes'
            IBM_LICENSE='Accept'
        else
            read -erp "" ans
        fi
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
                printf "\n"
                while true; do
                    
                    printf "\n"
                    # New license message from 26.0.0 GA for https://jsw.ibm.com/browse/DBACLD-218047
                    printf '%b\n' "${BOLD_TEXT}${RED_TEXT}IMPORTANT: By accepting the license, you agree and understand that by default the program collects certain data and metrics regarding deployment and usage.\nFor more information, please consult the License Information for Cloud Pak for Business Automation.${RESET_TEXT}"
                    echo
                    prompt_press_any_key_to_continue
                    echo
                    check_cp4ba_separate_operand $TARGET_PROJECT_NAME
                    if [[ -n "${CP4BA_SERVICES_NS:-}" && "$TARGET_PROJECT_NAME" != "$CP4BA_SERVICES_NS" ]]; then
                        printf '%b\n' "\x1B[1;31m[ERROR]\x1B[0m The -n value must be the CP4BA operand namespace in Separation-of-Duty deployments."
                        printf '%b\n' "         Re-run: ./cp4a-deployment.sh -n ${CP4BA_SERVICES_NS}"
                        exit 1
                    fi
                    
                    printf "\x1B[1mDid you deploy Content CR (CRD: contents.icp4a.ibm.com) in current cluster? (Yes/No, default: No): \x1B[0m"

                    if  [[ $CONTENT_CR_EXISTS == "" ]]; then
                        read -erp "" ans
                    else
                        ans=$CONTENT_CR_EXISTS
                    fi
                    case "$ans" in
                    "y"|"Y"|"yes"|"Yes"|"YES")
                        printf '%b\n' "Continuing...\n"
                        # printf '%b\n' "\x1B[1;31mThe cp4a-deployment.sh can not work with existing Content CR together, exiting now...\x1B[0m\n"
                        CONTENT_DEPLOYED="Yes"
                        break
                        ;;
                    "n"|"N"|"no"|"No"|"NO"|"")
                        printf '%b\n' "Continuing...\n"
                        CONTENT_DEPLOYED="No"
                        break
                        ;;
                    *)
                        printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
                        ;;
                    esac
                done
            printf '%b\n' "Starting to Install the Cloud Pak for Business Automation Operator...\n"
            IBM_LICENSE="Accept"
            validate_cli
            # DBACLD-198782: Check if Java is installed and meets the minimum version requirement
            # Priority: --java-path > JAVA_HOME > system PATH
            JAVA_PATH="${CUSTOM_JAVA_PATH:-$JAVA_HOME}"
            validate_java_runtime "$JAVA_PATH"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            echo
            printf '%b\n' "The license agreement was not accepted. The license agreement must be accepted to continue. The script is exiting...\n"
            exit 0
            ;;
        *)
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

# This function only gets asked during upgrade when we move from global to private catalog and ONLY if the scripts are used and not the API endpoints
# With the API endpoints the decision to move from global to private or remain global is determined if the --enable-private-catalog argument is passed into the script via the endpoint.
function select_private_catalog_cp4ba(){
    printf "\n"
    echo "${YELLOW_TEXT}[NOTES] You can choose to deploy CP4BA as a private catalog (namespace scope) or retain the global catalog namespace (GCN). The private catalog (recommended) uses the same target namespace as the CP4BA deployment, while the GCN uses the openshift-marketplace namespace.${RESET_TEXT}"

    while true; do
        printf "\x1B[1mDo you want to switch your CP4BA deployment to use private catalog? (Yes/No, default: Yes): \x1B[0m"
        read -erp "" ans

        # Set default response to the default value if empty
        ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
        if [ -z "$ans" ]; then
            ans="yes"
        fi
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
                info "The CP4BA operator is deployed in the "All" namespace, so the private catalog (namespace-scoped) cannot be used. You must continue using the global catalog namespace (GCN)."
                ENABLE_PRIVATE_CATALOG=0
            else
                info "You have chosen to switch from global catalog (GCN) to private catalog (namespace scope).The CP4BA catalog sources will be applied in the $CP4BA_OPERATOR_NS namespace."
                ENABLE_PRIVATE_CATALOG=1
            fi
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            info "You have chosen to retain the global catalog namespace.The CP4BA catalog sources will remain in the \"openshift-marketplace\" namespace."
            ENABLE_PRIVATE_CATALOG=0
            break
            ;;
        *)
            PRIVATE_CATALOG=""
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function select_private_catalog_opensearch(){
    printf "\n"
    echo "${YELLOW_TEXT}[NOTES] You can install OpenSearch as either a private catalog (namespace-scoped) or in the global catalog namespace (GCN). The private option uses the same target namespace as the CP4BA deployment, while the GCN uses the openshift-marketplace namespace.${RESET_TEXT}"
    while true; do
        printf "\x1B[1mDo you want to deploy Opensearch using private catalog?\x1B[0m (Yes/No, default: Yes): "
        read -erp "" ans

        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
                info "The CP4BA operator is deployed in the "All" namespace, so the private catalog (namespace-scoped) cannot be used. You must continue using the global catalog namespace (GCN)."
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
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function select_upgrade_mode_simple(){
    UPGRADE_MODE=""
    while [[ $UPGRADE_MODE == "" ]]; do
        printf "\n"
        options=("Cluster-scoped to Cluster-scoped" "Cluster-scoped to Namespace-scoped" "Namespace-scoped to Namespace-scoped")
        tips=("This migration mode will first isolate the shared 3.x version of foundational services on the cluster, then install a new instance of foundational services version 4.6.2. Any data from the original foundational services will be copied to the new instance." "This migration mode will migrate a single shared instance of foundational services that is shared by all IBM Cloud Paks in the entire cluster, all of its core foundational services operators to the cluster-scope namespace will be upgraded v4.6.2 without creating new instances." "This migration mode will migrate a dedicated foundational services without creating any new instances of foundational services. This method should only be used if the foundational services you are migrating is only for IBM Cloud Pak for Business Automation.")
        pros_tips=("The namespace-scoped foundational services for each Cloud Pak or CP4BA component." "The fewer resource required for a single shared instance of foundational services.")
        cons_tips=("The more resource required for each namespace-scoped instance of IBM Cloud Pak foundational services." "It is not flexible for all Cloud Pak or CP4BA component to share same one instance of IBM Cloud Pak foundational services.")

        printf '%b\n' "\x1B[1mWhich migration mode for the IBM Cloud Pak foundational services do you plan to migrate to? \x1B[0m${YELLOW_TEXT}(NOTES: This choice will decide to either use a private catalog (namespace-scoped) or a global catalog namespace (GCN) for Opensearch installation. Make sure you choose SAME MIGRATION MODE when rerun [upgradeOperator] for upgrade IBM Cloud Pak foundational services next.)${RESET_TEXT}\x1B[0m"

        printf '%b\n' "${YELLOW_TEXT}1) Cluster-scoped to Cluster-scoped${RESET_TEXT}"
        if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
            printf '%b\n' "   ${YELLOW_TEXT}[Tips]${RESET_TEXT}: ${tips[1]}"
            # printf '%b\n' "   ${GREEN_TEXT}[Pros]${RESET_TEXT}: ${pros_tips[1]}"
            # printf '%b\n' "   ${RED_TEXT}[Cons]${RESET_TEXT}: ${cons_tips[1]}"
        fi
        # printf '%b\n' "${YELLOW_TEXT}2) Namespace-scoped to Namespace-scoped${RESET_TEXT}"
        # if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
        #     printf '%b\n' "   ${YELLOW_TEXT}[Tips]${RESET_TEXT}: ${tips[2]}"
        #     # printf '%b\n' "   ${GREEN_TEXT}[Pros]${RESET_TEXT}: ${pros_tips[0]}"
        #     # printf '%b\n' "   ${RED_TEXT}[Cons]${RESET_TEXT}: ${cons_tips[0]}"
        # fi
        printf '%b\n' "${YELLOW_TEXT}2) Cluster-scoped to Namespace-scoped${RESET_TEXT}"
        if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
            printf '%b\n' "   ${YELLOW_TEXT}[Tips]${RESET_TEXT}: ${tips[0]}"
            # printf '%b\n' "   ${GREEN_TEXT}[Pros]${RESET_TEXT}: ${pros_tips[0]}"
            # printf '%b\n' "   ${RED_TEXT}[Cons]${RESET_TEXT}: ${cons_tips[0]}"
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
                echo "Invalid choice. Select either 1 or 2."
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

function create_project() {
    local project_name=$1
    project_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$project_name")

    isProjExists=`${CLI_CMD} get namespace $project_name --ignore-not-found | wc -l`  >&3 2>&3

    if [ $isProjExists -ne 2 ] ; then
        ${CLI_CMD} create namespace ${project_name} >&3 2>&3
        returnValue=$?
        if [ "$returnValue" == 1 ]; then
            if [ -z "$CP4BA_AUTO_NAMESPACE" ]; then
                printf '%b\n' "\x1B[1;31mInvalid project name, enter a valid name...\x1B[0m"
                project_name=""
                return 1
            else
                printf '%b\n' "\x1B[1;31mInvalid project name \"$CP4BA_AUTO_NAMESPACE\". Set a valid name...\x1B[0m"
                project_name=""
                exit 1
            fi
        else
            printf '%b\n' "\x1B[1mUsing project ${project_name}...\x1B[0m"
            return 0
        fi
    else
        printf '%b\n' "\x1B[1mProject \"${project_name}\" already exists! Continue...\x1B[0m"
        return 0
    fi
}

function detect_property_files(){
    if [[ -f $TEMPORARY_PROPERTY_FILE && -f $DB_NAME_USER_PROPERTY_FILE && -f $DB_SERVER_INFO_PROPERTY_FILE && -f $LDAP_PROPERTY_FILE && -f $USER_PROFILE_PROPERTY_FILE ]]; then
        DEPLOYMENT_WITH_PROPERTY="Yes"
    else
        DEPLOYMENT_WITH_PROPERTY="No"
    fi
}

function configure_vault_shared_secrets(){
    # DBACLD-185209: Configure vault shared secrets in CR
    # This function handles root_ca_secret, external_tls_certificate_secret, and trusted_certificate_list
    
    # Check for shared secrets for vault and include them in the CR if the props were set in the user profile prop file
    root_ca_secret="$(prop_user_profile_property_file CP4BA.ROOT_CA_SECRET 2>/dev/null || echo '')"
    if [[ -n "$root_ca_secret" && "$root_ca_secret" != "<Optional>" ]]; then
        ${YQ_CMD} -i ".spec.shared_configuration.root_ca_secret = \"${root_ca_secret}\"" ${CP4A_PATTERN_FILE_TMP}
    fi
    
    external_tls_cert_secret="$(prop_user_profile_property_file CP4BA.EXTERNAL_TLS_CERTIFICATE_SECRET 2>/dev/null || echo '')"
    if [[ -n "$external_tls_cert_secret" && "$external_tls_cert_secret" != "<Optional>" ]]; then
        ${YQ_CMD} -i ".spec.shared_configuration.external_tls_certificate_secret = \"${external_tls_cert_secret}\"" ${CP4A_PATTERN_FILE_TMP}
    fi
    
    trusted_cert_list="$(prop_user_profile_property_file CP4BA.TRUSTED_CERTIFICATE_LIST 2>/dev/null || echo '')"
    trusted_cert_list=$(sed -e 's/^"//' -e 's/"$//' <<<"$trusted_cert_list")
    if [[ -n "$trusted_cert_list" && "$trusted_cert_list" != "<Optional>" ]]; then
        trusted_cert_list=$(echo "$trusted_cert_list" | sed 's/[[:space:]]*,[[:space:]]*/,/g')
        # Initialize array
        ${YQ_CMD} -i '.spec.shared_configuration.trusted_certificate_list = []' ${CP4A_PATTERN_FILE_TMP}
        # Add each certificate
        IFS=',' read -ra CERT_ARRAY <<< "$trusted_cert_list"
        for cert in "${CERT_ARRAY[@]}"; do
            cert=$(echo "$cert" | xargs)  # Trim whitespace
            if [[ -n "$cert" ]]; then
                ${YQ_CMD} -i ".spec.shared_configuration.trusted_certificate_list += [\"$cert\"]" ${CP4A_PATTERN_FILE_TMP}
            fi
        done
    fi
}

function validate_kube_oc_cli(){
    if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]]; then
        which oc &>/dev/null
        [[ $? -ne 0 ]] && \
        printf '%b\n'  "\x1B[1;31mUnable to locate the OpenShift CLI. You must install it to run this script.\x1B[0m" && \
        exit 1
    fi
    if  [[ $PLATFORM_SELECTED == "other" ]]; then
        which kubectl &>/dev/null
        [[ $? -ne 0 ]] && \
        printf '%b\n'  "\x1B[1;31mUnable to locate the Kubernetes CLI, You must install it to run this script.\x1B[0m" && \
        exit 1
    fi
}

function prop_tmp_property_file() {
    grep "\b${1}\b" ${TEMPORARY_PROPERTY_FILE}|cut -d'=' -f2
}

function load_temp_property_file(){
    if [[ ! -f $TEMPORARY_PROPERTY_FILE ]]; then
        fail "Error while gathering data from the cp4a-prerequisites.sh modes. Run the \"cp4a-prerequisites.sh\" script to complete the prerequisites."
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
    
    # making sure the DB type is in lowercase
    DB_TYPE=$(echo "$DB_TYPE" | tr '[:upper:]' '[:lower:]')
    # For Database type DB2 DB2HADR and DB2 RDS the generate mode and validate mode are all identical and in the script taken care off using $DB_TYPE == "db2"
    if [[ $DB_TYPE == "db2"* ]]; then
        DB_TYPE="db2"
    fi

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
    # Convert to lowercase for comparison
    LDAP_WFPS_AUTHORING=$(echo "$LDAP_WFPS_AUTHORING" | tr '[:upper:]' '[:lower:]')
    EXTERNAL_DB_WFPS_AUTHORING=$(prop_tmp_property_file EXTERNAL_DB_WFPS_AUTHORING_FLAG)

    # load fips enabled flag
    FIPS_ENABLED=$(prop_tmp_property_file FIPS_ENABLED_FLAG)

    # load profile size  flag
    PROFILE_TYPE=$(prop_tmp_property_file PROFILE_SIZE_FLAG)

    # load the flag that detects whether the script is being run to generate a CR to with updated list of components
    UPDATE_COMPONENTS=$(prop_tmp_property_file UPDATE_COMPONENTS)

    # Load Content Cortex AI Services configuration with defaults
    SETUP_CONTENT_CORTEX_AI_SERVICES="$(prop_tmp_property_file SETUP_CONTENT_CORTEX_AI_SERVICES)"
    if [[ -z "$SETUP_CONTENT_CORTEX_AI_SERVICES" ]]; then
        SETUP_CONTENT_CORTEX_AI_SERVICES="false"
    fi

    # Check for required property files based on configuration flags
    missing_property_files=()
    PROPERTY_FILES_FOUND=true
    
    
    if [[ ! -f $DB_NAME_USER_PROPERTY_FILE ]]; then
        missing_property_files+=("$DB_NAME_USER_PROPERTY_FILE")
    fi
    
    if [[ ! -f $DB_SERVER_INFO_PROPERTY_FILE ]]; then
        missing_property_files+=("$DB_SERVER_INFO_PROPERTY_FILE")
    fi
    
    # Only check LDAP_PROPERTY_FILE if LDAP_WFPS_AUTHORING is not "no"
    if [[ "$LDAP_WFPS_AUTHORING" != "no" ]]; then
        if [[ ! -f $LDAP_PROPERTY_FILE ]]; then
            missing_property_files+=("$LDAP_PROPERTY_FILE")
        fi
    fi
    
    # Only check AI_SERVICES_PROPERTY_FILE if SETUP_CONTENT_CORTEX_AI_SERVICES is not "false"
    if [[ "$SETUP_CONTENT_CORTEX_AI_SERVICES" == "true" ]]; then
        if [[ ! -f $AI_SERVICES_PROPERTY_FILE ]]; then
            missing_property_files+=("$AI_SERVICES_PROPERTY_FILE")
        fi
    fi
    
    # If any files are missing, display them and exit
    if [[ ${#missing_property_files[@]} -gt 0 ]]; then
        error "The following required property files could not be found in the expected propertyfile folder: \"$PROPERTY_FILE_FOLDER\""
        for missing_file in "${missing_property_files[@]}"; do
            echo "  - $missing_file" >&2
        done
        PROPERTY_FILES_FOUND=false
    fi
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
                printf '%b\n' "\x1B[1;31mUnable to locate docker and podman. Install either of them first.\x1B[0m" && \
                exit 1
            fi
        fi
    elif [[ $OCP_VERSION == "4.4OrLater" ]]
    then
        which podman &>/dev/null
        [[ $? -ne 0 ]] && \
            printf '%b\n' "\x1B[1;31mUnable to locate podman. Install it first.\x1B[0m" && \
            exit 1
    fi
}

function select_project() {
    while [[ $TARGET_PROJECT_NAME == "" ]];
    do
        printf "\n"
        printf '%b\n' "\x1B[1mWhere do you want to deploy Cloud Pak for Business Automation?\x1B[0m"
        read -p "Enter the name for an existing project (namespace): " TARGET_PROJECT_NAME
        if [ -z "$TARGET_PROJECT_NAME" ]; then
            printf '%b\n' "\x1B[1;31mEnter a valid project name, project name can not be blank\x1B[0m"
        elif [[ "$TARGET_PROJECT_NAME" == openshift* ]]; then
            printf '%b\n' "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
            TARGET_PROJECT_NAME=""
        elif [[ "$TARGET_PROJECT_NAME" == kube* ]]; then
            printf '%b\n' "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
            TARGET_PROJECT_NAME=""
        else
            isProjExists=`${CLI_CMD} get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l`  >/dev/null 2>&1

            if [ "$isProjExists" -ne 2 ] ; then
                printf '%b\n' "\x1B[1;31mInvalid project name. Enter an existing project name ...\x1B[0m"
                TARGET_PROJECT_NAME=""
            else
                printf '%b\n' "\x1B[1mUsing project ${TARGET_PROJECT_NAME}...\x1B[0m"
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
        object_name_tmp=`${YQ_CMD} ".spec.datasource_configuration.dc_os_datasources.[$os_num].dc_common_os_datasource_name // \"\"" "$FILE"`

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
            object_name_tmp=`${YQ_CMD} ".spec.datasource_configuration.dc_os_datasources.[$os_num].dc_common_os_datasource_name // \"\"" "$FILE"`
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
        object_name_tmp=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$os_num].oc_cpe_obj_store_display_name // \"\"" "$FILE"`
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
        name_tmp=`${YQ_CMD} ".spec.initialize_configuration.ic_ldap_creation.ic_ldap_admins_groups_name.[$ldap_num] // \"\"" "$FILE"`
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
        name_tmp=`${YQ_CMD} ".spec.initialize_configuration.ic_ldap_creation.ic_ldap_admin_user_name.[$ldap_num] // \"\"" "$FILE"`
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
        name_tmp=`${YQ_CMD} ".spec.baw_configuration.[$baw_instance_num].name // \"\"" "$FILE"`
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
        name_tmp=`${YQ_CMD} ".spec.application_engine_configuration.[$ae_instance_num].name // \"\"" "$FILE"`
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
        name_tmp=`${YQ_CMD} ".spec.initialize_configuration.ic_icn_init_info.icn_repos.[$icn_repo_instance_num].add_repo_id // \"\"" "$FILE"`
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
        name_tmp=`${YQ_CMD} ".spec.initialize_configuration.ic_icn_init_info.icn_desktop.[$icn_desktop_instance_num].add_desktop_id // \"\"" "$FILE"`
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
        name_tmp=`${YQ_CMD} ".spec.datasource_configuration.dc_ca_datasource.tenant_databases.[$tenant_db_instance_num] // \"\"" "$FILE"`
        if [ -z "$name_tmp" ]; then
            break
        else
            tenant_db_index_array=( "${tenant_db_index_array[@]}" "${tenant_db_instance_num}" )
        fi
        ((tenant_db_instance_num++))
    done
}

function select_platform(){
    printf "\n"
    printf '%b\n' "\x1B[1mSelect the cloud platform to deploy: \x1B[0m"
    COLUMNS=12
    if [ -z "$existing_platform_type" ]; then
        if [[ $DEPLOYMENT_TYPE == "starter" ]];then
            options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
            PS3='Enter a valid option [1 to 2]: '
        elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
        then
            if [[ "${SCRIPT_MODE}" == "OLM" ]]; then
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
                PS3='Enter a valid option [1 to 2]: '
            else
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
                PS3='Enter a valid option [1 to 2]: '
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
        elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
        then
            if [[ "${SCRIPT_MODE}" == "OLM" ]]; then
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
                options_var=("ROKS" "OCP")
            else
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
                options_var=("ROKS" "OCP")
            fi
        fi
        for i in ${!options_var[@]}; do
            if [[ "${options_var[i]}" == "$existing_platform_type" ]]; then
                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Selected)"
            else
                printf "%1d) %s\n" $((i+1)) "${options[i]}"
            fi
        done
        printf '%b\n' "\x1B[1;31mExisting platform type found in CR: \"$existing_platform_type\"\x1B[0m"
        # printf '%b\n' "\x1B[1;31mDo not need to select again.\n\x1B[0m"
        prompt_press_any_key_to_continue
    fi

    if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS" ]]; then
        CLI_CMD=oc
    elif [[ "$PLATFORM_SELECTED" == "other" ]]
    then
        CLI_CMD=kubectl
    fi

    validate_kube_oc_cli

    # For Azure Red Hat OpenShift (ARO)/Red Hat OpenShift Service on AWS (ROSA)
    if [[ "$PLATFORM_SELECTED" == "OCP" && "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" ]] || [[ "$PLATFORM_SELECTED" == "OCP" && "$DEPLOYMENT_TYPE" == "production" ]] ; then   #DBACLD-166320 This code changes addressing the issue while the customer deploying CP4BA into ARO or AWS
        while true; do
            printf "\n"
            printf "\x1B[1mIs your OCP deployed on AWS or Azure? (Yes/No, default: No): \x1B[0m"
            read -erp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                printf "\n"
                printf '%b\n' "\x1B[1mWhich platform is OCP deployed on? \x1B[0m"
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
                printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
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
            printf '%b\n' "\x1B[1;31mIMPORTANT: The apiextensions.k8s.io/v1beta API has been deprecated from k8s 1.16+, OCP 4.3 is using k8s 1.16.x. recommend you to upgrade your OCP to version 4.4 or later\n\x1B[0m"
            prompt_press_any_key_to_continue
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
        if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" ]];
        then
            options=("Content Cortex Standard Edition" "Operational Decision Manager" "Decision Intelligence Client Managed Software" "Business Automation Application" "Business Automation Workflow Authoring and Automation Workstream Services" "IBM Automation Document Processing")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow-workstreams" "document_processing")
            foundation_0=("BAN" "RR")                 # Foundation for Content Cortex Standard Edition
            foundation_1=("BAN" "RR")                # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR" "UMS")     # Foundation for Decision Intelligence Client Managed Software
            foundation_3=("RR" "UMS" "BAS")     # Foundation for Business Automation Applications (full)
            foundation_4=("RR" "UMS" "AE" "BAS")           # Foundation for Business Automation Workflow and workstreams(Demo)
            foundation_5=("BAN" "RR" "AE" "BAS" "UMS")  # Foundation for IBM Automation Document Processing
        else
            options=("Content Cortex Standard Edition" "Operational Decision Manager" "Decision Intelligence Client Managed Software" "Business Automation Application" "Business Automation Workflow" "(a) Workflow Authoring" "(b) Workflow Runtime" "Automation Workstream Services" "IBM Automation Document Processing" "(a) Development Environment" "(b) Runtime Environment" "Workflow Process Service Authoring")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow" "workflow-authoring" "workflow-runtime" "workstreams" "document_processing" "document_processing_designer" "document_processing_runtime" "workflow-process-service")
            foundation_0=("BAN" "RR")                 # Foundation for Content Cortex Standard Edition
            foundation_1=("BAN" "RR")                 # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR" "UMS")     # Foundation for Decision Intelligence Client Managed Software
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
        if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" ]];
        then
            options=("Content Cortex Standard Edition" "Operational Decision Manager" "Decision Intelligence Client Managed Software" "Business Automation Application" "Business Automation Workflow Authoring and Automation Workstream Services" "IBM Automation Document Processing")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow-workstreams" "document_processing")
            foundation_0=("BAN" "RR")                 # Foundation for Content Cortex Standard Edition
            foundation_1=("BAN" "RR")                # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR")     # Foundation for Decision Intelligence Client Managed Software
            foundation_3=("RR" "BAS")     # Foundation for Business Automation Applications (full)
            foundation_4=("RR" "AE" "BAS")           # Foundation for Business Automation Workflow and workstreams(Demo)
            foundation_5=("BAN" "RR" "AE" "BAS")  # Foundation for IBM Automation Document Processing
        else
            options=("Content Cortex Standard Edition" "Operational Decision Manager" "Decision Intelligence Client Managed Software" "Business Automation Application" "Business Automation Workflow" "(a) Workflow Authoring" "(b) Workflow Runtime" "Automation Workstream Services" "IBM Automation Document Processing" "(a) Development Environment" "(b) Runtime Environment" "Workflow Process Service Authoring")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow" "workflow-authoring" "workflow-runtime" "workstreams" "document_processing" "document_processing_designer" "document_processing_runtime" "workflow-process-service")
            foundation_0=("BAN" "RR")                 # Foundation for Content Cortex Standard Edition
            foundation_1=("BAN" "RR")                 # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR")     # Foundation for Decision Intelligence Client Managed Software
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
    tips1="\x1B[1;31mTips\x1B[0m:\x1B[1m Press [ENTER] to accept the default (None of the capabilities is selected). If none of the capabilities is chosen, the script will exit.\x1B[0m"
    tips2="\x1B[1;31mTips\x1B[0m:\x1B[1m Press [ENTER] when you are done\x1B[0m"
    pattern_starter_tips="\x1B[1mInfo: Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Business Automation foundation platform. \n\nTips: After you make your first selection you will be able to make additional selections since you can combine multiple selections.\n\x1B[0m"
    pattern_production_tips="\x1B[1mInfo: Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Business Automation foundation platform. \n\nTips: After you make your first selection you will be able to make additional selections since you can combine multiple selections.\n\x1B[0m"
    baw_iaws_tips="\x1B[1mInfo: Note that Business Automation Workflow Authoring (5a) cannot be installed together with Automation Workstream Services (6). However, Business Automation Workflow Runtime (5b) can be installed together with Automation Workstream Services (6).\n\x1B[0m"
    linux_starter_tips="\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mIBM Automation Document Processing (6) does NOT support a cluster running a Linux on Z (s390x) or Power (ppc64le) architecture.\n\x1B[0m"
    linux_production_tips="\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mIBM Automation Document Processing (7a/7b) does NOT support a cluster running a Linux on Z (s390x) or Power (ppc64le) architecture.\n\x1B[0m"
    content_deployed_tips="\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31m\"Content Cortex Standard Edition\" can not be selected because one Content (Kind: content.icp4a.ibm.com) custom resource was deployed.\n\x1B[0m"
    indexof() {
        i=-1
        for ((j=0;j<${#options_cr_val[@]};j++));
        do [ "${options_cr_val[$j]}" = "$1" ] && { i=$j; break; }
        done
        echo "$i"
    }
    menu() {
        clear
        printf '%b\n' "\x1B[1mSelect the Cloud Pak for Business Automation capability to install: \x1B[0m"
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
            elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
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
        if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
            printf '%b\n' "${baw_iaws_tips}"
        fi

        if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
            printf '%b\n' "${pattern_production_tips}"
            printf '%b\n' "${linux_production_tips}"
            if [[ $CONTENT_DEPLOYED == "Yes" ]]; then
                printf '%b\n' "${content_deployed_tips}"
            fi
        else
            printf '%b\n' "${pattern_starter_tips}"
            printf '%b\n' "${linux_starter_tips}"
        fi
        # Show different tips according components select or unselect
        containsElement "(Selected)" "${choices_pattern[@]}"
        retVal=$?
        if [ $retVal -ne 0 ]; then
            printf '%b\n' "${tips1}"
        else
            printf '%b\n' "${tips2}"
        fi
# ##########################DEBUG############################
#     for i in "${!choices_pattern[@]}"; do
#         printf "%s\t%s\n" "$i" "${choices_pattern[$i]}"
#     done
# ##########################DEBUG############################
    }

    if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
        prompt="Enter a valid option [1 to ${#options[@]}]: "
    elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
    then
        prompt="Enter a valid option [1 to 4, 5a, 5b, 6, 7a, 7b, 8]: "
    fi

    while menu && read -erp "$prompt" num && [[ "$num" ]]; do
        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
            [[ "$num" != *[![:digit:]]* ]] &&
            (( num > 0 && num <= ${#options[@]} )) ||
            { msg="Invalid option: $num"; continue; }
            ((num--));
        elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
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
            if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
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
            elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
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
    # read -rsn1 -p"Press Enter/Return to continue (DEBUG MODEL)";echo
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
    printf '%b\n' "$msg"

    # 4Q: add workflow-workstream into pattern list when select both workflow-runtime and workstream
    # https://jsw.ibm.com/browse/DBACLD-174822 (modified if condition by changing workflow to workflow-runtime)
    if [[ " ${pattern_cr_arr[@]} " =~ "workflow-runtime" && " ${pattern_cr_arr[@]} " =~ "workstreams" && "$DEPLOYMENT_TYPE" == "production" ]]; then
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
        printf "\x1B[1;31mNo selection was made. At least one capability must be chosen to proceed. Exiting. \n\x1B[0m"
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
        linux_production_tips="\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mIBM Content Collector for SAP (4) does NOT support a cluster running a Linux on Power architecture.\n\x1B[0m"
        dicms_tips="\x1B[1mTips:\x1B[0m Decision Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present. \n\nDecision Runtime is typically recommended if you are deploying a test or production environment.\n\nDecision Runtime is required when Decision Designer is selected.\n\nYou should choose at least one these features to have a minimum environment configuration.\n"
        if [[ $DEPLOYMENT_TYPE == "starter" ]];then
            decision_tips="\x1B[1mTips:\x1B[0m Decision Center, Rule Execution Server and Decision Runner will be installed by default.\n"
        else
            decision_tips="\x1B[1mTips:\x1B[0m Decision Center is typically required for development and testing environments. \nRule Execution Server is typically required for testing and production environments and for using Business Automation Insights. \nYou should choose at least one these 2 features to have a minimum environment configuration. \n"
        fi
        application_tips_demo="\x1B[1mTips:\x1B[0m Application Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present.  \n\nMake your selection or press enter to proceed. \n"
        application_tips_ent="\x1B[1mTips:\x1B[0m Application Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present. \n\nApplication Engine is automatically installed in the environment.  \n\nMake your selection or press enter to proceed. \n"
        workflow_tips="\x1B[1mNote:\x1B[0m When Workflow Runtime MCP Server is selected, Exposed OpenSearch will be automatically enabled as it is required for MCP Server functionality.\n"

        indexof() {
            i=-1
            for ((j=0;j<${#optional_component_cr_arr[@]};j++));
            do [ "${optional_component_cr_arr[$j]}" = "$1" ] && { i=$j; break; }
            done
            echo "$i"
        }
        menu() {
            clear
            printf '%b\n' "\x1B[1;31mCapability \"$item_pattern\": \x1B[0m\x1B[1mSelect optional components: \x1B[0m"
            # printf '%b\n' "\x1B[1mSelect optional components: \x1B[0m"
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
                    if [[ "${item_pattern}" == "Content Cortex Standard Edition" || ( "${item_pattern}" == "Operational Decision Manager" && "$DEPLOYMENT_TYPE" == "production" ) ]];then
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

            if [[ "${item_pattern}" == "Decision Intelligence Client Managed Software" ]]; then
                printf '%b\n' "${dicms_tips}"
            fi
            if [[ "${item_pattern}" == "Operational Decision Manager" ]]; then
                printf '%b\n' "\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31m You must select at least one of ODM components.\x1B[0m\n"
                printf '%b\n' "${decision_tips}"
            fi
            if [[ "${item_pattern}" == "Business Automation Application" ]]; then

                printf '%b\n' "${application_tips}"
                if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                    printf '%b\n' "${application_tips_demo}"
                elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
                then
                    printf '%b\n' "${application_tips_ent}"
                fi
            fi

            if [[ "${item_pattern}" == "Content Cortex Standard Edition" ]]; then
                if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                    printf '%b\n' "${linux_starter_tips}"
                elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
                then
                    printf '%b\n' "${linux_production_tips}"
                fi
            fi

            # Display note for Workflow patterns about MCP Server and OpenSearch requirement
            if [[ "${item_pattern}" == *"Workflow"* ]]; then
                printf '%b\n' "${workflow_tips}"
            fi
            # Show different tips according components select or unselect
            containsElement "(Selected)" "${choices_component[@]}"
            retVal=$?
            if [ $retVal -eq 0 ]; then
                printf '%b\n' "${tips2}"
            elif [ $selectedVal -eq 0 ]
            then
                printf '%b\n' "${tips2}"
            else
                printf '%b\n' "${tips1}"
            fi
# ##########################DEBUG############################
#         for i in "${!choices_component[@]}"; do
#             printf "%s\t%s\n" "$i" "${choices_component[$i]}"
#         done
# ##########################DEBUG############################
        }

        prompt="Enter a valid option [1 to ${#optional_components_list[@]} or ENTER]: "
        while menu && read -erp "$prompt" num && [[ "$num" ]]; do
            [[ "$num" != *[![:digit:]]* ]] &&
            (( num > 0 && num <= ${#optional_components_list[@]} )) ||
            { msg="Invalid option: $num"; continue; }
            if [[ "${item_pattern}" == "Content Cortex Standard Edition" && "$DEPLOYMENT_TYPE" == "production" ]]; then
                case "$num" in
                "1"|"2"|"3"|"4"|"5"|"6"|"7"|"8")
                    ((num--))
                    ;;
                esac
            elif [[ "${item_pattern}" == "Content Cortex Standard Edition" && "$DEPLOYMENT_TYPE" == "starter" ]]; then
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
                if [[ "${optional_components_list[num]}" == "Decision Designer" ]]; then
                    choices_component[num+1]="(Selected)"
                fi
                if [[ $PLATFORM_SELECTED == "other" && ("${item_pattern}" == "Content Cortex Standard Edition" || ("${item_pattern}" == "Operational Decision Manager" && "$DEPLOYMENT_TYPE" == "production")) ]]; then
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
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "DecisionDesigner" "DecisionRuntime" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Decision Runtime" ]]
                then
                    if [[ " ${optional_component_arr[*]} " =~ " DecisionDesigner " ]]; then
                       msg="";
                    else
                       [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "DecisionRuntime" ); msg=""; }
                    fi
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
                elif [[ "${optional_components_list[i]}" == "Content Cortex for Microsoft Office" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ContentCortexforMicrosoftOffice" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Content Integration" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ContentIntegration" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "IBM Content Navigator" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "IBMContentNavigator" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Workplace Assistant" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "WorkplaceAssistant" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "(Preview) Authoring Assistant" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "AuthoringAssistant" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Application Connectors" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ApplicationConnectors" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Workflow Runtime MCP Server" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "WorkflowRuntimeMCPServer" ); msg=""; }
                    # Auto-select OpenSearch when Workflow Runtime MCP Server is selected
                    if [[ "${choices_component[i]}" ]]; then
                        containsElement "opensearch" "${optional_component_cr_arr[@]}"
                        opensearch_exists=$?
                        if [[ $opensearch_exists -ne 0 ]]; then
                            optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "opensearch" )
                            optional_component_arr=( "${optional_component_arr[@]}" "ExposedOpenSearch" )
                        fi
                    fi
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
                    elif [[ "${optional_components_list[i]}" == "Content Cortex for Microsoft Office" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ContentCortexforMicrosoftOffice" )
                    elif [[ "${optional_components_list[i]}" == "Content Integration" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ContentIntegration" )
                    elif [[ "${optional_components_list[i]}" == "IBM Content Navigator" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "IBMContentNavigator" )
                    elif [[ "${optional_components_list[i]}" == "Workplace Assistant" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "WorkplaceAssistant" )
                    elif [[ "${optional_components_list[i]}" == "(Preview) Authoring Assistant" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "AuthoringAssistant" )
                    elif [[ "${optional_components_list[i]}" == "Application Connectors" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ApplicationConnectors" )
                    elif [[ "${optional_components_list[i]}" == "Workflow Runtime MCP Server" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "WorkflowRuntimeMCPServer" )
                    else
                        optional_component_arr=( "${optional_component_arr[@]}" "${optional_components_list[i]}" )
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "${optional_components_cr_list[i]}" )
                fi
            fi
        done
        # printf '%b\n' "$msg"

        if [ "${#optional_component_arr[@]}" -eq "0" ]; then
            COMPONENTS_SELECTED="None"
        else
            OPT_COMPONENTS_CR_SELECTED=$( IFS=$','; echo "${optional_component_arr[*]}" )

        fi
    }
    for item_pattern in "${pattern_arr[@]}"; do
        while true; do
            case $item_pattern in
                "Content Cortex Standard Edition")
                    # echo "select $item_pattern pattern optional components"
                    if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                        optional_components_list=("Content Search Services" "Content Management Interoperability Services" "IBM Enterprise Records" "IBM Content Collector for SAP" "Business Automation Insights" "Task Manager" "Content Cortex for Microsoft Office")
                        optional_components_cr_list=("css" "cmis" "ier" "iccsap" "bai" "tm" "ccxmo")
                    elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
                    then
                        if [[ $PLATFORM_SELECTED == "other" ]]; then
                            optional_components_list=("Content Search Services" "Content Management Interoperability Services" "IBM Enterprise Records" "IBM Content Collector for SAP" "User Management Service" "Business Automation Insights" "Task Manager" "Content Cortex for Microsoft Office")
                            optional_components_cr_list=("css" "cmis" "ier" "iccsap" "ums" "bai" "tm" "ccxmo")
                        else
                            optional_components_list=("Content Search Services" "Content Management Interoperability Services" "IBM Enterprise Records" "IBM Content Collector for SAP" "Business Automation Insights" "Task Manager" "Content Cortex for Microsoft Office")
                            optional_components_cr_list=("css" "cmis" "ier" "iccsap" "bai" "tm" "ccxmo")
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
                    if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" ]]; then
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
                "Decision Intelligence Client Managed Software")
                    # echo "select $item_pattern pattern optional components"
                    if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" ]]; then
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
                    if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                        optional_components_list=("Business Automation Insights")
                        optional_components_cr_list=("bai")
                        show_optional_components
                    fi
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "bai" )
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ae_data_persistence" )
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "(a) Workflow Authoring")
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
                        optional_components_list=("Application Connectors" "Business Automation Insights" "Data Collector and Data Indexer" "Exposed Kafka Services" "Workflow Assistant" "(Preview) Authoring Assistant" "Workflow Runtime MCP Server")
                        optional_components_cr_list=("application_connectors" "bai" "pfs" "kafka" "workplace_assistant" "workflow_assistant" "workflow_runtime_mcp_server")
                        show_optional_components
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "baw_authoring" )
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "(b) Workflow Runtime")
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
                        optional_components_list=("Application Connectors" "Business Automation Insights" "Exposed Kafka Services" "Exposed OpenSearch" "Workflow Assistant" "Workflow Runtime MCP Server")
                        optional_components_cr_list=("application_connectors" "bai" "kafka" "opensearch" "workplace_assistant" "workflow_runtime_mcp_server")
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
                    # elif [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
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
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
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
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
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
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
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
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
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
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
                        optional_components_list=("Application Connectors" "Business Automation Insights" "Data Collector and Data Indexer" "Exposed Kafka Services" "Workflow Runtime MCP Server")
                        optional_components_cr_list=("application_connectors" "bai" "pfs" "kafka" "workflow_runtime_mcp_server")
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
    KEEP_COMPOMENTS=($(echo "${FOUNDATION_CR_SELECTED_LOWCASE[@]}" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} | tr ' ' '\n' | sort | uniq -d | uniq))
    OPT_COMPONENTS_SELECTED=($(echo "${optional_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # Will an external LDAP be used as part of the configuration?
    containsElement "es" "${OPT_COMPONENTS_CR_SELECTED[@]}"
    retVal_ext_ldap=$?
    if [[ $retVal_ext_ldap -eq 0 && "$DEPLOYMENT_TYPE" == "production" ]];then
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
       printf '%b\n' "\x1B[1;31mEnter a valid password\x1B[0m"
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
                   printf '%b\n' "\x1B[1;31mThe passwords do not match. Try again.\x1B[0m"
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
    echo "$result" | grep -vq 'not found'
    }

    # For Entitlement Registry key
    entitlement_key=""
    printf "\n"
    printf "\n"
    printf "\x1B[1;31mFollow the instructions on how to get your Entitlement Key: \n\x1B[0m"
    printf "\x1B[1;31mhttps://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE\n\x1B[0m"
    printf "\x1B[1;31mFrom the above Link Navigate to Installing --> Installing Production Deployment --> Installing CP4BA multi-pattern production deployment --> Option1 Preparing your cluster for an online deployment --> Getting access to images from the public IBM Entitled Registry\n\x1B[0m"
    printf "\n"
    while true; do
        printf "\x1B[1mDo you have a Cloud Pak for Business Automation Entitlement Registry key (Yes/No, default: Yes): \x1B[0m"
        read -erp "" ans

        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            use_entitlement="yes"
            if [[ "$SCRIPT_MODE" == "dev" || "$SCRIPT_MODE" == "review" || "$SCRIPT_MODE" == "OLM" ]]
            then
                DOCKER_REG_SERVER="cp.stg.icr.io"
            else
                DOCKER_REG_SERVER="cp.icr.io"
            fi
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
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
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function create_secret_entitlement_registry(){
    printf "\x1B[1mCreating docker-registry secret for Entitlement Registry key...\n\x1B[0m"
# Create docker-registry secret for Entitlement Registry Key
    ${CLI_CMD} delete secret "$DOCKER_RES_SECRET_NAME" >&3 2>&3
    CREATE_SECRET_CMD="${CLI_CMD} create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$DOCKER_REG_SERVER --docker-username=$DOCKER_REG_USER --docker-password=$DOCKER_REG_KEY --docker-email=ecmtest@ibm.com"
    if $CREATE_SECRET_CMD ; then
        printf '%b\n' "\x1B[1mDone\x1B[0m"
    else
        printf '%b\n' "\x1B[1mFailed\x1B[0m"
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
            read -erp "" local_public_registry_server
            if [ -z "$local_public_registry_server" ]; then
            printf '%b\n' "\x1B[1;31mEnter a valid service name or the URL for the docker registry.\x1B[0m"
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
        read -erp "" local_registry_server
        if [ -z "$local_registry_server" ]; then
        printf '%b\n' "\x1B[1;31mEnter a valid service name or the URL for the docker registry.\x1B[0m"
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
       read -erp "" local_registry_user
       if [ -z "$local_registry_user" ]; then
       printf '%b\n' "\x1B[1;31mEnter a valid user name.\x1B[0m"
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
            read -erp "" storage_class_name
            if [ -z "$storage_class_name" ]; then
               printf '%b\n' "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
            fi
        done
        printf "\x1B[1mTo provision the persistent volumes and volume claims, enter the block storage classname(RWO): \x1B[0m"
        if [[ $PLATFORM_SELECTED == "OCP" ]]; then
        while [[ $block_storage_class_name == "" ]]
        do
            read -erp "" block_storage_class_name
            if [ -z "$block_storage_class_name" ]; then
               printf '%b\n' "\x1B[1;31mEnter a valid block storage classname(RWO)\x1B[0m"
            fi
        done
        fi
    elif [[ ("$DEPLOYMENT_TYPE" == "production" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other")) || $PLATFORM_SELECTED == "ROKS" ]]
    then
        printf "\x1B[1mTo provision the persistent volumes and volume claims\n\x1B[0m"
        while [[ $sc_slow_file_storage_classname == "" ]] # While get slow storage clase name
        do
            printf "\x1B[1mEnter the file storage classname for slow storage(RWX): \x1B[0m"
            read -erp "" sc_slow_file_storage_classname
            if [ -z "$sc_slow_file_storage_classname" ]; then
               printf '%b\n' "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
            fi
        done

        while [[ $sc_medium_file_storage_classname == "" ]] # While get medium storage clase name
        do
            printf "\x1B[1mEnter the file storage classname for medium storage(RWX): \x1B[0m"
            read -erp "" sc_medium_file_storage_classname
            if [ -z "$sc_medium_file_storage_classname" ]; then
               printf '%b\n' "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
            fi
        done

        while [[ $sc_fast_file_storage_classname == "" ]] # While get fast storage clase name
        do
            printf "\x1B[1mEnter the file storage classname for fast storage(RWX): \x1B[0m"
            read -erp "" sc_fast_file_storage_classname
            if [ -z "$sc_fast_file_storage_classname" ]; then
               printf '%b\n' "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
            fi
        done
        if [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]]; then
        while [[ $block_storage_class_name == "" ]] # While get block storage clase name
        do
            printf "\x1B[1mEnter the block storage classname for Zen(RWO): \x1B[0m"
            read -erp "" block_storage_class_name
            if [ -z "$block_storage_class_name" ]; then
               printf '%b\n' "\x1B[1;31mEnter a valid block storage classname(RWO)\x1B[0m"
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
    printf '%b\n' "\x1B[1mCreating the secret based on the local docker registry information...\x1B[0m"
    # Create docker-registry secret for local Registry Key
    # printf '%b\n' "Create docker-registry secret for Local Registry...\n"
    if [[ $LOCAL_REGISTRY_SERVER == docker-registry* || $LOCAL_REGISTRY_SERVER == image-registry.openshift-image-registry* ]] ;
    then
        builtin_dockercfg_secrect_name=$(${CLI_CMD} get secret | grep default-dockercfg | awk '{print $1}')
        DOCKER_RES_SECRET_NAME=$builtin_dockercfg_secrect_name
        # CREATE_SECRET_CMD="${CLI_CMD} create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$LOCAL_REGISTRY_SERVER --docker-username=$LOCAL_REGISTRY_USER --docker-password=$(${CLI_CMD} whoami -t) --docker-email=ecmtest@ibm.com"
    else
        ${CLI_CMD} delete secret "$DOCKER_RES_SECRET_NAME" >&3 2>&3
        CREATE_SECRET_CMD="${CLI_CMD} create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$LOCAL_REGISTRY_SERVER --docker-username=$LOCAL_REGISTRY_USER --docker-password=$LOCAL_REGISTRY_PWD --docker-email=ecmtest@ibm.com"
        if $CREATE_SECRET_CMD ; then
            printf '%b\n' "\x1B[1mDone\x1B[0m"
        else
            printf '%b\n' "\x1B[1;31mFailed\x1B[0m"
        fi
    fi
}

function verify_local_registry_password(){
    # require to preload image for CP4A image and ldap/db2 image for demo
    printf "\n"
    while true; do
        printf "\x1B[1mHave you pushed the images to the local registry using 'loadimages.sh' (CP4A images) (Yes/No)? \x1B[0m"
        # printf "\x1B[1mand 'loadPrereqImages.sh' (Db2 and OpenLDAP for demo) scripts (Yes/No)? \x1B[0m"
        read -erp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            PRE_LOADED_IMAGE="Yes"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            printf '%b\n' "\x1B[1;31mPull the images to the local images to proceed.\n\x1B[0m"
            exit 1
            ;;
        *)
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done

    # Select which type of image registry to use.
    if [[ "${PLATFORM_SELECTED}" == "OCP" ]]; then
        printf "\n"
        printf '%b\n' "\x1B[1mSelect the type of image registry to use: \x1B[0m"
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
    printf '%b\n' "\x1B[1mIs this a new installation or an existing installation?\x1B[0m"
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

# Validate custom IAM Admin user using deployment script and change automatically if there is a conflict
# https://jsw.ibm.com/browse/DBACLD-189095
function select_iam_default_admin() {
  printf "\n"
  local default_user="cpadmin"
  local fallback_user="cp4ba-admin"
  local selected_user="" suffix=1

  while true; do
    printf '%b\n' "\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;31mIf 'cpadmin' already exists in your LDAP, you must choose a different IM admin username (local-only).\x1B[0m"
    printf "\x1B[1mDo you want to use the default IM admin user: [cpadmin] (Yes/No, default: Yes): \x1B[0m"
    read -r ans
    case "$ans" in
      "y"|"Y"|"yes"|"Yes"|"YES"|"")
        # For no LDAP with WFPS Authoring we don't need to check if the user is present in the LDAP
        if [[ "$LDAP_WFPS_AUTHORING" != "no" ]]; then
            if iam_user_validation "$default_user"; then
                printf '%b\n' "\x1B[33m[WARNING]:\x1B[0m \x1B[1mUsername '$default_user' exists in LDAP\x1B[0m — \x1B[1;31mSwitching IM admin username to '$fallback_user'\x1B[0m"
                selected_user="$fallback_user"
                while iam_user_validation "$selected_user"; do
                    selected_user="${fallback_user}-${suffix}"
                    ((suffix++))
                done
                USE_DEFAULT_IAM_ADMIN="No"
            else
                printf '%b\n' "\x1B[32m[INFO]:\x1B[0m Username '$default_user' not found in LDAP, using it as IM admin."
                selected_user="$default_user"
                USE_DEFAULT_IAM_ADMIN="Yes"
            fi
        else
            printf '%b\n' "\x1B[32m[INFO]:\x1B[0m Using Username '$default_user' as IM admin."
            selected_user="$default_user"
            USE_DEFAULT_IAM_ADMIN="Yes"
        fi
        break
        ;;
      "n"|"N"|"no"|"No"|"NO")
        while true; do
            printf "\nEnter non-default LOCAL IM admin username (must not exist in LDAP): "
            read -r NON_DEFAULT_IAM_ADMIN
            if [[ -z "$NON_DEFAULT_IAM_ADMIN" || "$NON_DEFAULT_IAM_ADMIN" == "$default_user" ]]; then
                printf '%b\n' "\x1B[1;31mEnter a valid username (cannot be blank or '$default_user').\x1B[0m"
                continue
            fi

            if ! is_valid_username "$NON_DEFAULT_IAM_ADMIN"; then
                continue
            fi
            # For no LDAP with WFPS Authoring we don't need to check if the user is present in the LDAP
            if [[ "$LDAP_WFPS_AUTHORING" != "no" ]]; then
                if iam_user_validation "$NON_DEFAULT_IAM_ADMIN"; then
                    printf '%b\n' "\x1B[1;31mUsername '$NON_DEFAULT_IAM_ADMIN' already exists in LDAP. Choose another.\x1B[0m"
                    continue
                fi
            else
                printf '%b\n' "\x1B[32m[INFO]:\x1B[0m Using Username '$NON_DEFAULT_IAM_ADMIN' as IM admin."
            fi
            selected_user="$NON_DEFAULT_IAM_ADMIN"
            USE_DEFAULT_IAM_ADMIN="No"
            break
        done
        break
        ;;
      *)
        printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
        ;;
    esac
  done
  
  DEFAULT_ADMIN_USERNAME="$selected_user"
  NON_DEFAULT_IAM_ADMIN="$selected_user"
}

function select_profile_type(){
    printf "\n"
    COLUMNS=12
    if [ -z $OPENSEARCH_CATALOG_NS ]; then
        printf '%b\n' "\x1B[1mSelect the deployment profile. Refer to the documentation in CP4BA Docs for details on profile.\x1B[0m"
    else
        printf '%b\n' "\x1B[1mSelect the deployment profile for Opensearch. Refer to the documentation in Opensearch Docs for details on the profile.\x1B[0m"
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
        printf '%b\n' "\x1B[1;31mExisting profile size type found in CR: \"$existing_profile_type\"\x1B[0m"
        # printf '%b\n' "\x1B[1;31mDo not need to select again.\n\x1B[0m"
        prompt_press_any_key_to_continue
    fi
}


function select_deployment_type(){
    printf "\n"

    if [[ "$SCRIPT_MODE" == "OLM" ]]
    then
        DEPLOYMENT_TYPE="production"
        printf '%b\n' "An enterprise deployment will be prepared for the OCP Catalog."
    else
        printf '%b\n' "\x1B[1mWhat type of deployment is being performed?\x1B[0m"

        COLUMNS=12
        options=("Starter" "Production")
        if [ -z "$existing_deployment_type" ]; then
            if [[ $CP4BA_DEPLOYMENT_TYPE != ""  ]]; then
                DEPLOYMENT_TYPE=$CP4BA_DEPLOYMENT_TYPE
            else
                #DBACLD-222678: Skip Starter option for 26.0.0 GA 
                if  skip_edb; then
                    info "Note: Please be aware that for this ${VERSION_TO_SKIP_EDB} version, Starter deployment is not supported. Starter deployment support will be available in the upcoming iFix and next release."
                    options=("Production")
                    PS3='Enter a valid option [1]: '
                else
                    PS3='Enter a valid option [1 to 2]: '
                    
                fi
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
            printf '%b\n' "\x1B[1;31mExisting deployment type found in CR: \"$existing_deployment_type\"\x1B[0m"
            # printf '%b\n' "\x1B[1;31mDo not need to select again.\n\x1B[0m"
            prompt_press_any_key_to_continue
        fi
    fi
}

function enable_ae_data_persistence_workflow_authoring(){
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
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
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
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
    info "LDAP configuration is not required for the IBM Workflow Process Service Authoring, but if you want to login with LDAP user, select Yes. If you select No, you can manually add the LDAP connection after installation. For more information, from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE navigate to Installing --> Installing Production Deployment --> Installing a CP4BA multi-pattern production deployment --> Completing post-installation tasks --> Cloud Pak for Business Automation Foundation --> Business Automation Studio."
    while true; do
        printf "\x1B[1mDo you want use the LDAP for the IBM Workflow Process Service Authoring? (Yes/No): \x1B[0m"
        read -erp "" ans
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
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
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
            printf '%b\n' "\x1B[1mWhich migration mode for the IBM Cloud Pak foundational services are you migrating to? \x1B[0m"
        elif [[ $RUNTIME_MODE == "upgradeDeployment" ]]; then
            printf '%b\n' "\x1B[1mWhich migration mode for the IBM Cloud Pak foundational services are you migrating to when run [upgradeOperator]? \x1B[0m"
        fi
        printf '%b\n' "${YELLOW_TEXT}1) Cluster-scoped to Cluster-scoped${RESET_TEXT}"
        if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
            printf '%b\n' "   ${YELLOW_TEXT}[Tips]${RESET_TEXT}: ${tips[1]}"
            printf '%b\n' "   ${GREEN_TEXT}[Pros]${RESET_TEXT}: ${pros_tips[1]}"
            printf '%b\n' "   ${RED_TEXT}[Cons]${RESET_TEXT}: ${cons_tips[1]}"
        fi
        printf '%b\n' "${YELLOW_TEXT}2) Cluster-scoped to Namespace-scoped (Recommended)${RESET_TEXT}"
        if [[ $RUNTIME_MODE == "upgradeOperator" ]]; then
            printf '%b\n' "   ${YELLOW_TEXT}[Tips]${RESET_TEXT}: ${tips[0]}"
            printf '%b\n' "   ${GREEN_TEXT}[Pros]${RESET_TEXT}: ${pros_tips[0]}"
            printf '%b\n' "   ${RED_TEXT}[Cons]${RESET_TEXT}: ${cons_tips[0]}"
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
                echo "Invalid choice. Select either 1 or 2."
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


function select_fips_enable(){
    select_project
    all_fips_enabled_flag=$(${CLI_CMD} get configmap cp4ba-fips-status --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath={.data.all-fips-enabled})
    if [ -z $all_fips_enabled_flag ]; then
        
        info "Not found configmap \"cp4ba-fips-status\" in the project \"$CP4BA_SERVICES_NS\". setting \"shared_configuration.enable_fips\" as \"false\" by default in the final custom resource."
        FIPS_ENABLED="false"
    elif [[ "$all_fips_enabled_flag" == "Yes" ]]; then
        printf "\n"
        while true; do
            printf "\x1B[1mYour OCP cluster has FIPS enabled, do you want to enable FIPS with this CP4BA deployment?\x1B[0m${YELLOW_TEXT} (Notes: If you select \"Yes\", in order to complete enablement of FIPS for CP4BA, refer to \"FIPS wall\" configuration in IBM documentation.)${RESET_TEXT} (Yes/No, default: No): "
            read -erp "" ans
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
                printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
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
    printf '%b\n' "\x1B[1mWhat is the LDAP type that is used for this deployment? \x1B[0m"
    options=("Microsoft Active Directory" "IBM Tivoli Directory Server / Security Directory Server" "PingDirectory Server")
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
            "PingDirectory Server")
                LDAP_TYPE="PDS"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

}
function set_ldap_type_foundation(){
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
    then
        # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}

        
        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${CP4A_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        elif [[ "$LDAP_TYPE" == "TDS" ]]; then
            content_start="$(grep -n "tds:" ${CP4A_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        elif [[ "$LDAP_TYPE" == "PDS" ]]; then
            content_start="$(grep -n "pds:" ${CP4A_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${CP4A_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${CP4A_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_content_pattern(){
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
    then
        ${COPY_CMD} -rf ${CONTENT_PATTERN_FILE_BAK} ${CONTENT_PATTERN_FILE_TMP}
        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "## The User script will uncomment" ${CONTENT_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        elif [[ "$LDAP_TYPE" == "TDS" ]]; then
            content_start="$(grep -n "## The User script will uncomment" ${CONTENT_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "## The User script will uncomment" ${CONTENT_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start + 5))
        vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'d' -c ':wq' >/dev/null 2>&1

        ${COPY_CMD} -rf ${CONTENT_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_adp_pattern(){
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
    then
        ${COPY_CMD} -rf ${ARIA_PATTERN_FILE_BAK} ${ARIA_PATTERN_FILE_TMP}

        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "## The User script will uncomment" ${ARIA_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        elif [[ "$LDAP_TYPE" == "TDS" ]]; then
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
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
    then
        ${COPY_CMD} -rf ${WORKSTREAMS_PATTERN_FILE_BAK} ${WORKSTREAMS_PATTERN_FILE_TMP}

        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${WORKSTREAMS_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        elif [[ "$LDAP_TYPE" == "TDS" ]]; then
            content_start="$(grep -n "tds:" ${WORKSTREAMS_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        elif [[ "$LDAP_TYPE" == "PDS" ]]; then
            content_start="$(grep -n "pds:" ${WORKSTREAMS_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${WORKSTREAMS_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${WORKSTREAMS_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        ${COPY_CMD} -rf ${WORKSTREAMS_PATTERN_FILE_TMP} ${WORKSTREAMS_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_workflow_pattern(){
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
    then
        ${COPY_CMD} -rf ${WORKFLOW_PATTERN_FILE_BAK} ${WORKFLOW_PATTERN_FILE_TMP}

        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${WORKFLOW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        elif [[ "$LDAP_TYPE" == "TDS" ]]; then
            content_start="$(grep -n "tds:" ${WORKFLOW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        elif [[ "$LDAP_TYPE" == "PDS" ]]; then
            content_start="$(grep -n "pds:" ${WORKFLOW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${WORKFLOW_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${WORKFLOW_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        ${COPY_CMD} -rf ${WORKFLOW_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_ww_pattern(){
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
    then
        ${COPY_CMD} -rf ${WW_PATTERN_FILE_BAK} ${WW_PATTERN_FILE_TMP}

        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${WW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        elif [[ "$LDAP_TYPE" == "TDS" ]]; then
            content_start="$(grep -n "tds:" ${WW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "pds:" ${WW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
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
        printf "\x1B[1mWill an external LDAP be used as part of the configuration? \x1B[0m"

        read -erp "" ans
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
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done

}
function set_external_share_content_pattern(){
    if [[ "$DEPLOYMENT_TYPE" == "production" && $SET_EXT_LDAP == "Yes" ]] ;
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
            if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                if [[ "$LDAP_TYPE" == "AD" ]]; then
                    # content_start="$(grep -n "ad:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
                    content_start="$(grep -n "ad:" ${CONTENT_PATTERN_FILE_TMP} | cut -d: -f1)"
                elif [[ "$LDAP_TYPE" == "TDS" ]]; then
                    # content_start="$(grep -n "tds:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
                    content_start="$(grep -n "tds:" ${CONTENT_PATTERN_FILE_TMP} | cut -d: -f1)"
                elif [[ "$LDAP_TYPE" == "PDS" ]]; then
                    # content_start="$(grep -n "pds:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
                    content_start="$(grep -n "pds:" ${CONTENT_PATTERN_FILE_TMP} | cut -d: -f1)"
                fi
            elif [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
                tmp_ldap_type="$(prop_ext_ldap_property_file LDAP_TYPE)"
                tmp_ldap_type=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_type")
                if [[ $tmp_ldap_type == "Microsoft Active Directory" ]]; then
                    # content_start="$(grep -n "ad:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
                    content_start="$(grep -n "ad:" ${CONTENT_PATTERN_FILE_TMP} | cut -d: -f1)"
                elif [[ $tmp_ldap_type == "IBM Security Directory Server" ]]; then
                    # content_start="$(grep -n "tds:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
                    content_start="$(grep -n "tds:" ${CONTENT_PATTERN_FILE_TMP} | cut -d: -f1)"
                elif [[ $tmp_ldap_type == "PingDirectory Server" ]]; then
                    # content_start="$(grep -n "pds:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
                    content_start="$(grep -n "pds:" ${CONTENT_PATTERN_FILE_TMP} | cut -d: -f1)"
                else
                    fail "The value for \"LDAP_TYPE\" in the property file \"${EXTERNAL_LDAP_PROPERTY_FILE}\" is not valid. The possible values are: \"IBM Security Directory Server\" or \"Microsoft Active Directory\" or \"PingDirectory Server\""
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
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
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
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[${j}].dc_common_os_datasource_name = \"FNOS${obj_num}DS\"" ${CONTENT_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[${j}].dc_common_os_xa_datasource_name = \"FNOS${obj_num}DSXA\"" ${CONTENT_PATTERN_FILE_TMP}
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

            ## Adding the Object Stores to the Custom Resource
            ## spec.initialize_configuration
            for ((j=1;j<${content_os_number};j++))
            do
                ((obj_num=j+1))
                if [[ $obj_num -lt "10" ]]; then
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_display_name = \"OS0${obj_num}\"" ${CONTENT_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_symb_name = \"OS0${obj_num}\"" ${CONTENT_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_display_name = \"OS${obj_num}\"" ${CONTENT_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_symb_name = \"OS${obj_num}\"" ${CONTENT_PATTERN_FILE_TMP}
                fi
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_conn.name = \"objectstore${obj_num}_connection\"" ${CONTENT_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_conn.dc_os_datasource_name = \"FNOS${obj_num}DS\"" ${CONTENT_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_conn.dc_os_xa_datasource_name = \"FNOS${obj_num}DSXA\"" ${CONTENT_PATTERN_FILE_TMP}
            done

            if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
                for ((j=0;j<${content_os_number};j++))
                do
                    ((obj_num=j+1))
                    tmp_os_db_enable_adp="$(prop_db_name_user_property_file OS${obj_num}_ENABLE_DOCUMENT_PROCESSING)"
                    tmp_os_db_enable_adp=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_enable_adp")
                    if [[ $tmp_os_db_enable_adp == "Yes" || $tmp_os_db_enable_adp == "YES" || $tmp_os_db_enable_adp == "Y" || $tmp_os_db_enable_adp == "True" || $tmp_os_db_enable_adp == "true" ]]; then
                        ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_enable_document_processing = \"true\"" ${CONTENT_PATTERN_FILE_TMP}
                    fi
                done
            fi

        fi
        ${COPY_CMD} -rf ${CONTENT_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
    fi
}

function set_object_store_adp_pattern(){
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
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
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[${j}].dc_common_os_datasource_name = \"FNOS${obj_num}DS\"" ${ARIA_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[${j}].dc_common_os_xa_datasource_name = \"FNOS${obj_num}DSXA\"" ${ARIA_PATTERN_FILE_TMP}
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
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_display_name = \"OS0${obj_num}\"" ${ARIA_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_symb_name = \"OS0${obj_num}\"" ${ARIA_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_display_name = \"OS${obj_num}\"" ${ARIA_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_symb_name = \"OS${obj_num}\"" ${ARIA_PATTERN_FILE_TMP}
                fi
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_conn.name = \"objectstore${obj_num}_connection\"" ${ARIA_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_conn.dc_os_datasource_name = \"FNOS${obj_num}DS\"" ${ARIA_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_conn.dc_os_xa_datasource_name = \"FNOS${obj_num}DSXA\"" ${ARIA_PATTERN_FILE_TMP}
            done

            
            for ((j=0;j<${content_os_number};j++))
            do
                ((obj_num=j+1))
                tmp_os_db_enable_adp="$(prop_db_name_user_property_file OS${obj_num}_ENABLE_DOCUMENT_PROCESSING)"
                tmp_os_db_enable_adp=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_enable_adp")
                if [[ $tmp_os_db_enable_adp == "Yes" || $tmp_os_db_enable_adp == "YES" || $tmp_os_db_enable_adp == "Y" || $tmp_os_db_enable_adp == "True" || $tmp_os_db_enable_adp == "true" ]]; then
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[${j}].oc_cpe_obj_store_enable_document_processing = \"true\"" ${ARIA_PATTERN_FILE_TMP}
                fi
            done
        fi
        ${COPY_CMD} -rf ${ARIA_PATTERN_FILE_TMP} ${ARIA_PATTERN_FILE_BAK}
    fi
}

function set_aca_tenant_pattern(){
    if [[ "$DEPLOYMENT_TYPE" == "production" ]] ;
    then
        ${COPY_CMD} -rf ${ACA_PATTERN_FILE_BAK} ${ACA_PATTERN_FILE_TMP}
        # ${YQ_CMD} d -i ${ACA_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases
        if [ ${#aca_tenant_arr[@]} -eq 0 ]; then
            printf '%b\n' "\x1B[1;31mNot any element in ACA tenant list found\x1B[0m:\x1B[1m"
        else
            for i in ${!aca_tenant_arr[@]}; do
               ${YQ_CMD} -i ".spec.datasource_configuration.dc_ca_datasource.tenant_databases[${i}] = \"${aca_tenant_arr[$i]}\"" ${ACA_PATTERN_FILE_TMP}
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
            read -erp "" ans
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
                printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
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
            read -erp "" ans
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
                printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
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
            read -erp "" ans
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
                printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
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
                read -erp "" ans
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
                    printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
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
        read -erp "" aca_tenant_number
        if ! [[ "$aca_tenant_number" =~ ^[0-9]+$ ]]; then
            printf '%b\n' "\x1B[1;31mEnter a valid tenant number\x1B[0m"
            aca_tenant_number=""
        fi
    done

    order_number=1
    while (( ${#aca_tenant_arr[@]} < $aca_tenant_number ));
    do
        printf "\x1B[1mWhat is the name of tenant ${order_number}? \x1B[0m"
        read -erp "" aca_tenant_name
        if [ -z "$aca_tenant_number" ]; then
            printf '%b\n' "\x1B[1;31mEnter a valid tenant name\x1B[0m"
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
    printf '%b\n' "\x1B[1mSelect the Cloud Pak for Business Automation capability to install: \x1B[0m"
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
    INSTALLATION_TYPE="new"
    # clean_up_temp_file
    # rm -rf $BAK_FOLDER >/dev/null 2>&1
    # rm -rf $FINAL_CR_FOLDER >/dev/null 2>&1

    mkdir -p $TEMP_FOLDER >/dev/null 2>&1
    mkdir -p $BAK_FOLDER >/dev/null 2>&1
    mkdir -p $FINAL_CR_FOLDER >/dev/null 2>&1
    

    
        
    select_deployment_type
    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
        # The script will load the temp property file only for production
        
        # Temporary property file is being loaded here so that we can get the information about the flag UPDATE_COMPONENTS stored by the cp4a-prerequisites.sh script.
        load_temp_property_file
        if [[ "$PROPERTY_FILES_FOUND" == "true" ]]; then
            # IF the flag is set to true , we need to load some details from the live CR and know the script is being executed to update a current deployment, otherwise its a fresh install for the first time.
            if [[ "$UPDATE_COMPONENTS" == "true" ]]; then
                # Import functions used only for the update components mode
                source ${CUR_DIR}/helper/update-selected-components/update-selected-components.sh
                retrieve_current_custom_resource_file "$CP4BA_SERVICES_NS" "deployment_script"
            fi
        else
            echo
            error "Since the script could not find all property files required to generate the Custom Resource (CR) for this deployment, the script will now exit."
            echo
            info  "Before executing the \"cp4a-deployment.sh\" script to generate a Custom Resource (CR) file,you must first run \"cp4a-prerequisites.sh\" in the following modes:"
            info  "1. \" cp4a-prerequisites.sh -m property -n $TARGET_PROJECT_NAME \""
            info  "2. \" cp4a-prerequisites.sh -m generate -n $TARGET_PROJECT_NAME \""
            info  "3. \" cp4a-prerequisites.sh -m validate -n $TARGET_PROJECT_NAME \""
            info  "For more information, from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE navigate to Installing --> Installing Production Deployment --> Installing a CP4BA multi-pattern production deployment --> Preparing your chosen capabilities --> Preparing databases and secrets for your chosen capabilities by running a script"
            echo 
            exit
        fi
    fi
    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
        if [[ ! -z $CP4BA_AUTO_NAMESPACE ]]; then
            TARGET_PROJECT_NAME=$CP4BA_AUTO_NAMESPACE
        fi
        show_summary_pattern_selected
        #Only ask the deployment type question if the script is being used for a fresh install
        # Otherwise if it is being used to generate a new CR with an updated list of components , then we get this information from the live CR 
        if [[ "$UPDATE_COMPONENTS" == "false" ]]; then
            select_profile_type
        fi
    fi
    # Only ask the deployment type question if the script is being used for a fresh install/ Starter
    # Otherwise if it is being used to generate a new CR with an updated list of components , then we get this information from the live CR 
    if [[ "$UPDATE_COMPONENTS" == "false" || "$DEPLOYMENT_TYPE" == "starter" ]]; then
        select_platform
    fi

    if [[ ("$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS") && "$DEPLOYMENT_TYPE" == "production" && "$USE_DEFAULT_IAM_ADMIN" == "" && "$NON_DEFAULT_IAM_ADMIN" == "" ]]; then
        # Only ask the deployment type question if the script is being used for a fresh install
        # Otherwise if it is being used to generate a new CR with an updated list of components , then we get this information from the live CR 
        if [[ "$UPDATE_COMPONENTS" == "false" ]]; then
            select_iam_default_admin
        fi
    fi
    
    if [[ ("$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS") && "$DEPLOYMENT_TYPE" == "starter" ]]; then
        select_project
    fi
    check_ocp_version
    validate_docker_podman_cli
    prepare_pattern_file

    

    if [[ "${INSTALL_BAW_ONLY}" == "No" ]]; then
        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
            select_pattern
        elif [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
            FOUNDATION_CR_SELECTED=($(echo "${foundation_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

            x=0;while [ ${x} -lt ${#FOUNDATION_CR_SELECTED[*]} ] ; do FOUNDATION_CR_SELECTED_LOWCASE[$x]=$(tr [A-Z] [a-z] <<< ${FOUNDATION_CR_SELECTED[$x]}); let x++; done
            FOUNDATION_DELETE_LIST=($(echo "${FOUNDATION_CR_SELECTED[@]}" "${FOUNDATION_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))

            PATTERNS_CR_SELECTED=($(echo "${pattern_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        fi
        
    else
        select_baw_only
    fi
    if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
        select_optional_component
    elif [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
        OPT_COMPONENTS_CR_SELECTED=($(echo "${optional_component_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        OPTIONAL_COMPONENT_DELETE_LIST=($(echo "${OPT_COMPONENTS_CR_SELECTED[@]}" "${OPTIONAL_COMPONENT_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))
        KEEP_COMPOMENTS=($(echo "${FOUNDATION_CR_SELECTED_LOWCASE[@]}" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} | tr ' ' '\n' | sort | uniq -d | uniq))
        OPT_COMPONENTS_SELECTED=($(echo "${optional_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    fi


    
    # This question gets asked for 1. Starter and ICCSAP selected and 2. Production and the script is not used for updating the deployment patterns/optional components
    if [[ ( ( ( $DEPLOYMENT_TYPE == "starter" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ) || ("$UPDATE_COMPONENTS" == "false" && "$DEPLOYMENT_TYPE" == "production" )) ]]; then
        get_jdbc_url
    # For modular updates: only prompt if ICCSAP is being added and JDBC URL was not retrieved from existing CR
    elif [[ ("$UPDATE_COMPONENTS" == "true" && " ${optional_component_cr_arr[@]} " =~ "iccsap" && -z "$CP4BA_JDBC_URL") ]]; then
        get_jdbc_url
    fi
    
    if [[ $PLATFORM_SELECTED == "other" ]]; then
        get_entitlement_registry
    fi
    if [[ "$use_entitlement" == "no" ]]; then
        verify_local_registry_password
    fi

    # load storage class name
    if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
        get_storage_class_name
    elif [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
        # Only ask the deployment type question if the script is being used for a fresh install
        # Otherwise if it is being used to generate a new CR with an updated list of components , then we get this information from the live CR 
        if [[ "$UPDATE_COMPONENTS" == "false" ]]; then
            SLOW_STORAGE_CLASS_NAME=$(prop_user_profile_property_file CP4BA.SLOW_FILE_STORAGE_CLASSNAME)
            MEDIUM_STORAGE_CLASS_NAME=$(prop_user_profile_property_file CP4BA.MEDIUM_FILE_STORAGE_CLASSNAME)
            FAST_STORAGE_CLASS_NAME=$(prop_user_profile_property_file CP4BA.FAST_FILE_STORAGE_CLASSNAME)
            BLOCK_STORAGE_CLASS_NAME=$(prop_user_profile_property_file CP4BA.BLOCK_STORAGE_CLASS_NAME)
            if [[ -z $SLOW_STORAGE_CLASS_NAME || -z $MEDIUM_STORAGE_CLASS_NAME || -z $FAST_STORAGE_CLASS_NAME || -z $BLOCK_STORAGE_CLASS_NAME ]]; then
                get_storage_class_name
            fi
        fi
    fi

    # Code block for FIPS, sample network polices and enabling instana monitoring

    if  [[ ("$DEPLOYMENT_TYPE" == "production") && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
        # Only ask the deployment type question if the script is being used for a fresh install
        # Otherwise if it is being used to generate a new CR with an updated list of components , then we get this information from the live CR
        if [[ "$UPDATE_COMPONENTS" == "false" ]]; then
            select_fips_enable
        fi

        GENERATE_SAMPLE_NETWORK_POLICIES="$(prop_user_profile_property_file CP4BA.ENABLE_GENERATE_SAMPLE_NETWORK_POLICIES)"
        if [[ -z "$GENERATE_SAMPLE_NETWORK_POLICIES" ]]; then
            GENERATE_SAMPLE_NETWORK_POLICIES="false"
        fi

        ENABLE_INSTANA_MONITORING="$(prop_user_profile_property_file CP4BA.ENABLE_INSTANA_MONITORING)"
        if [[ -z "$ENABLE_INSTANA_MONITORING" ]]; then
            ENABLE_INSTANA_MONITORING="false"
        fi
    elif [[ "$DEPLOYMENT_TYPE" == "starter" ]]; then
        FIPS_ENABLED="false"
        # For starter deployment, always set generate_sample_network_policies: true
        info "Starter deployments will have \"generate_sample_network_policies\" automatically set to \"true\" in the custom resource configuration."
        GENERATE_SAMPLE_NETWORK_POLICIES="true"
        # For starter deployment, always set enable_instana_monitoring: true
        info "Starter deployments will have \"enable_instana_monitoring\" automatically set to \"true\" in the custom resource configuration."
        ENABLE_INSTANA_MONITORING="true"
    
        select_cpe_full_storage

        containsElement "document_processing_designer" "${PATTERNS_CR_SELECTED[@]}"
        retVal=$?
        if [[ ( $retVal -eq 0 ) ]]; then
            select_gpu_document_processing
        fi

        containsElement "document_processing" "${PATTERNS_CR_SELECTED[@]}"
        retVal=$?
        if [[ ( $retVal -eq 0 ) ]]; then
            select_enable_deep_learning
            if [[ $ADP_DL_ENABLED == "Yes" ]]; then
                select_gpu_document_processing
            elif [[ $ADP_DL_ENABLED == "No" || -z $ADP_DL_ENABLED ]]; then
                ENABLE_GPU_ARIA="No"
            fi
        fi
    fi
    if [[ ! (" ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1") ]]; then
        if [[ $IBM_LICENSE == "Accept" ]]; then
            ${YQ_CMD} -i '.spec.ibm_license = "accept"' ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.ibm_license = ""' ${CP4A_PATTERN_FILE_TMP}
        fi
    fi
}

function apply_cp4a_operator(){
    ${COPY_CMD} -rf ${OPERATOR_FILE_BAK} ${OPERATOR_FILE_TMP}

    printf "\n"
    if [[ ("$SCRIPT_MODE" != "review") && ("$SCRIPT_MODE" != "OLM") ]]; then
        printf '%b\n' "\x1B[1mInstalling the Cloud Pak for Business Automation operator...\x1B[0m"
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
        ${CLI_CMD} delete -f ${OPERATOR_FILE_TMP} >&3 2>&3
        sleep 5
    fi

    INSTALL_OPERATOR_CMD="${CLI_CMD} apply -f ${OPERATOR_FILE_TMP}"
    if $INSTALL_OPERATOR_CMD ; then
        printf '%b\n' "\x1B[1mDone\x1B[0m"
    else
        printf '%b\n' "\x1B[1;31mFailed\x1B[0m"
    fi

    ${COPY_CMD} -rf ${OPERATOR_FILE_TMP} ${OPERATOR_FILE_BAK}
    printf "\n"
    # Check deployment rollout status every 5 seconds (max 10 minutes) until complete.
    printf '%b\n' "\x1B[1mWaiting for the Cloud Pak operator to be ready. This might take a few minutes... \x1B[0m"
    ATTEMPTS=0
    ROLLOUT_STATUS_CMD="${CLI_CMD} rollout status deployment/ibm-cp4a-operator"
    until $ROLLOUT_STATUS_CMD || [ $ATTEMPTS -eq 120 ]; do
        $ROLLOUT_STATUS_CMD
        ATTEMPTS=$((ATTEMPTS + 1))
        sleep 5
    done
    if $ROLLOUT_STATUS_CMD ; then
        printf '%b\n' "\x1B[1mDone\x1B[0m"
    else
        printf '%b\n' "\x1B[1;31mFailed\x1B[0m"
    fi
    printf "\n"
}

function copy_jdbc_driver(){
    # Get pod name
    printf '%b\n' "\x1B[1mCopying the JDBC driver for the operator...\x1B[0m"
    operator_podname=$(${CLI_CMD} get pod|grep ibm-cp4a-operator|grep Running|awk '{print $1}')

    # ${CLI_CMD} exec -it ${operator_podname} -- rm -rf /opt/ansible/share/jdbc
    COPY_JDBC_CMD="${CLI_CMD} cp ${JDBC_DRIVER_DIR} ${operator_podname}:/opt/ansible/share/"

    if $COPY_JDBC_CMD ; then
        printf '%b\n' "\x1B[1mDone\x1B[0m"
    else
        printf '%b\n' "\x1B[1;31mFailed\x1B[0m"
    fi
}


function get_jdbc_url(){
    CP4BA_JDBC_URL=""
    while [[ $CP4BA_JDBC_URL == "" ]];
    do
        if [ -z "$CP4BA_JDBC_URL" ]; then
            printf "\n"
          printf '%b\n' "\x1B[1mProvide a URL to zip file that contains JDBC and/or ICCSAP drivers.\x1B[0m"
          printf '%b\n' "\x1B[1mNote: Custom drivers provided via this URL will automatically take precedence over out-of-the-box drivers.\x1B[0m"
            read -p "(optional - if not provided, the Operator will configure using the default shipped JDBC driver): " CP4BA_JDBC_URL
            if [[ ( -z "$CP4BA_JDBC_URL" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ]]; then
                printf "\n"
                printf '%b\n' "\x1B[1;31mIBM Content Collector for SAP is selected, provide a URL to zip file that contains ICCSAP drivers.\x1B[0m"
                CP4BA_JDBC_URL=""
            elif [[ ( -z "$CP4BA_JDBC_URL" ) && ( ! " ${optional_component_cr_arr[@]} " =~ "iccsap" ) ]]; then
                printf "\n"
                printf '%b\n' "\x1B[1mThe Operator will configure using the default shipped JDBC driver.\x1B[0m"
                break
            fi
        fi
    done
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
                ${YQ_CMD} -i 'del(.spec.bastudio_configuration)' "${CP4A_PATTERN_FILE_TMP}"
            fi
            if [[ "$item" == "UMS" ]];then
                ${YQ_CMD} -i 'del(.spec.ums_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_ums_datasource)' "${CP4A_PATTERN_FILE_TMP}"
            fi
            if [[ "$item" == "BAN" ]];then
                if [[ " ${optional_component_cr_arr[@]} " =~ "case" ]]; then
                    break
                else
                    ${YQ_CMD} -i 'del(.spec.navigator_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                fi
            fi
            if [[ "$item" == "RR" ]];then
                ${YQ_CMD} -i 'del(.spec.resource_registry_configuration)' "${CP4A_PATTERN_FILE_TMP}"
            fi
            if [[ "$item" == "AE" ]];then
                ${YQ_CMD} -i 'del(.spec.application_engine_configuration)' "${CP4A_PATTERN_FILE_TMP}"
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

    # read -rsn1 -p"Press Enter/Return to continue (DEBUG MODEL)";echo

    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}
    
    # Only add LDAP sections if LDAP_WFPS_AUTHORING is not "no"
    if [[ "$LDAP_WFPS_AUTHORING" != "no" ]]; then
        set_ldap_type_foundation
    fi
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
                        ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
                    fi
                    break
                    ;;
                "contentanalyzer")
                    set_aca_tenant_pattern
                    ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_ca_datasource.tenant_databases)' "${CP4A_PATTERN_FILE_TMP}"
                    ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${ACA_PATTERN_FILE_BAK}
                    break
                    ;;
                "decisions")
                    set_decision_feature
                    ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${DECISIONS_PATTERN_FILE_BAK}
                    break
                    ;;
                "workflow")
                    # set_ldap_type_workflow_pattern
                    if [[ "${INSTALL_BAW_ONLY}" == "Yes" ]]; then
                        # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration
                        if [[ "$DEPLOYMENT_TYPE" == "production" ]];then
                            # if [[ $INSTALLATION_TYPE == "existing" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.datasource_configuration.dc_os_datasources
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.initialize_configuration
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.bastudio_configuration
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.baw_configuration
                            # fi
                            ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
                        elif [[ $DEPLOYMENT_TYPE == "starter" ]]
                        then
                            # if [[ $INSTALLATION_TYPE == "existing" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then
                            #     ${YQ_CMD} d -i ${WORKFLOW_PATTERN_FILE_BAK} spec.baw_configuration
                            # fi
                            ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
                            ${YQ_CMD} -i 'del(.spec.bastudio_configuration)' "${CP4A_PATTERN_FILE_TMP}"
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
                    ${YQ_CMD} -i 'del(.spec.baw_configuration)' "${CP4A_PATTERN_FILE_TMP}"


                    if [[ "$DEPLOYMENT_TYPE" == "production" ]];then
                        # if [[ $INSTALLATION_TYPE == "existing" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring") ]]; then
                        #     ${YQ_CMD} d -i ${WORKFLOW_AUTHOR_PATTERN_FILE_BAK} spec.datasource_configuration.dc_os_datasources
                        #     ${YQ_CMD} d -i ${WORKFLOW_AUTHOR_PATTERN_FILE_BAK} spec.initialize_configuration
                        #     ${YQ_CMD} d -i ${WORKFLOW_AUTHOR_PATTERN_FILE_BAK} spec.bastudio_configuration
                        # fi
                        ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_AUTHOR_PATTERN_FILE_BAK}
                    fi
                    break
                    ;;
                "workflow-runtime")
                    # set_ldap_type_workstreams_pattern
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]];then
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
                            ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
                        fi
                    elif [[ $DEPLOYMENT_TYPE == "starter" ]]
                    then
                        ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
                        ${YQ_CMD} -i 'del(.spec.bastudio_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    fi
                    break
                    ;;
                "workstreams")
                    # set_ldap_type_workstreams_pattern
                    ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${WORKSTREAMS_PATTERN_FILE_BAK}
                    break
                    ;;
                "workflow-workstreams")
                    # set_ldap_type_ww_pattern
                    # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.baw_configuration
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then                   
                        ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${WW_PATTERN_FILE_BAK}
                    elif [[ $DEPLOYMENT_TYPE == "starter" ]]
                    then
                        ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${WW_PATTERN_FILE_BAK}
                        ${YQ_CMD} -i 'del(.spec.application_engine_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    fi
                    break
                    ;;
                "application")
                    set_baa_app_designer
                    if [[ "$AE_DATA_PERSISTENCE_ENABLE" == "Yes" || " ${OPT_COMPONENTS_CR_SELECTED[@]} " =~ "ae_data_persistence" ]]; then
                        enable_ae_data_persistence_baa
                    fi
                    ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${APPLICATION_PATTERN_FILE_BAK}
                    break
                    ;;
                "digitalworker")
                    ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${ADW_PATTERN_FILE_BAK}
                    break
                    ;;
                "decisions_ads")
                    set_ads_designer_runtime
                    ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${ADS_PATTERN_FILE_BAK}
                    break
                    ;;
                "document_processing")
                    set_ldap_type_adp_pattern
                    set_aria_gpu
                    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
                        if [[ $content_os_number -gt 0 && "${pattern_cr_arr[@]}" =~ "document_processing" && (! "${pattern_cr_arr[@]}" =~ "content") ]]; then
                            set_object_store_adp_pattern
                        else
                            OS_DATASOURCE_NUMBER=$(grep "^        dc_common_os_datasource_name: " ${ARIA_PATTERN_FILE_BAK} | grep -Fn 'FNOS1DS'|cut -d':' -f1)
                            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                                ${YQ_CMD} -i "del(.spec.datasource_configuration.dc_os_datasources[\"${OS_DATASOURCE_NUMBER}\"])" "${ARIA_PATTERN_FILE_BAK}"
                            fi
                            OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${ARIA_PATTERN_FILE_BAK} | grep -Fn 'FNOS1DS'|cut -d':' -f1)
                            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                                ${YQ_CMD} -i "del(.spec.initialize_configuration.ic_obj_store_creation.object_stores[\"${OS_DATASOURCE_NUMBER}\"])" "${ARIA_PATTERN_FILE_BAK}"
                            fi

                        fi
                        if [[ "${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
                            ${SED_COMMAND} "s/  #ecm_configuration:/  ecm_configuration:/g" ${ARIA_PATTERN_FILE_BAK}
                            ${SED_COMMAND} "s/  #  document_processing:/    document_processing:/g" ${ARIA_PATTERN_FILE_BAK} 
                            if [[ $DB_TYPE = "postgresql-edb" ]]; then
                                # Add ibm_adp_secret under document_processing
                                ${SED_COMMAND} "s/  #    ibm_adp_secret: ibm-adp-secret/      ibm_adp_secret: \"ibm-adp-secret\"/g" ${ARIA_PATTERN_FILE_BAK}
                            else
                                # Remove ibm_adp_secret if DB_TYPE is not postgresql-edb
                                ${YQ_CMD} -i 'del(.'document_processing.ibm_adp_secret')' "${ARIA_PATTERN_FILE_BAK}"
                            fi

                            ${SED_COMMAND} "s/  #    cpds:/      cpds:/g" ${ARIA_PATTERN_FILE_BAK}
                            ${SED_COMMAND} "s/  #      production_setting:/        production_setting:/g" ${ARIA_PATTERN_FILE_BAK}
                            ${SED_COMMAND} "s/  #        REPO_SERVICE_URL: \"<Required>\"/          REPO_SERVICE_URL: \"<Required>\"/g" ${ARIA_PATTERN_FILE_BAK}
                        else
                            ${SED_COMMAND} "s/  #ecm_configuration:/  ecm_configuration:/g" ${ARIA_PATTERN_FILE_BAK}
                            ${SED_COMMAND} "s/  #  document_processing:/    document_processing:/g" ${ARIA_PATTERN_FILE_BAK}
                            ${SED_COMMAND} "s/  #    ibm_adp_secret: ibm-adp-secret/      ibm_adp_secret: \"ibm-adp-secret\"/g" ${ARIA_PATTERN_FILE_BAK}
                        fi
                    fi
                    ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${ARIA_PATTERN_FILE_BAK}
                    break
                    ;;
                "document_processing_runtime")
                    break
                    ;;
                "document_processing_designer")
                    break
                    ;;
                "workflow-process-service")
                    ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${CP4A_PATTERN_FILE_TMP} ${WFPS_AUTHOR_PATTERN_FILE_BAK}
                    break
                    ;;
                "foundation")
                    break
                    ;;
            esac
        done
    done
    # Tidying up final CR file after merging (required after upgrading to yq v4)
    if [[ ! (" ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1") ]]; then
        if [[ $IBM_LICENSE == "Accept" ]]; then
            ${YQ_CMD} -i '.spec.ibm_license = "accept"' ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.ibm_license = ""' ${CP4A_PATTERN_FILE_TMP}
        fi
    fi
    # YQ v4 adds ALL the comments from the other pattern yaml files, this will remove the excess and keep the last one, as before
    clean_license_block "${CP4A_PATTERN_FILE_TMP}"
}

function clean_license_block() {
    local file="$1"
    awk '
        BEGIN { in_block = 0; block = ""; content = ""; last_block = "" }
        /^#{79}$/ {
            if (in_block) {
                block = block $0 "\n"
                last_block = block
                block = ""
                in_block = 0
            } else {
                block = $0 "\n"
                in_block = 1
            }
            next
        }
        in_block {
            block = block $0 "\n"
            next
        }
        {
            content = content $0 "\n"
        }
        END {
            printf "%s%s", last_block, rtrim(content)
        }
        function rtrim(s) {
            sub(/[[:space:]]+$/, "", s)
            return s
        }
    ' "$file" > "${file}.cleaned" && mv "${file}.cleaned" "$file"
}

function merge_optional_components(){
    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}
    for item in "${OPTIONAL_COMPONENT_DELETE_LIST[@]}"; do
        while true; do
            case $item in
                "bas")
                    ${YQ_CMD} -i 'del(.spec.bastudio_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    break
                    ;;
                "ums")
                    if [[ $PLATFORM_SELECTED == "other" ]]; then
                        containsElement "bai" "${optional_component_cr_arr[@]}"
                        retVal=$?
                        if [[ $retVal -eq 1 ]]; then
                            ${YQ_CMD} -i 'del(.spec.ums_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                            ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_ums_datasource)' "${CP4A_PATTERN_FILE_TMP}"
                        fi
                    else
                        ${YQ_CMD} -i 'del(.spec.ums_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                        ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_ums_datasource)' "${CP4A_PATTERN_FILE_TMP}"
                    fi
                    break
                    ;;
                "cmis")
                    ${YQ_CMD} -i 'del(.spec.ecm_configuration.cmis)' "${CP4A_PATTERN_FILE_TMP}"
                    break
                    ;;
                "css")
                    ${YQ_CMD} -i 'del(.spec.ecm_configuration.css)' "${CP4A_PATTERN_FILE_TMP}"
                    break
                    ;;
                "es")
                    ${YQ_CMD} -i 'del(.spec.ecm_configuration.es)' "${CP4A_PATTERN_FILE_TMP}"
                    break
                    ;;
                "tm")
                    ${YQ_CMD} -i 'del(.spec.ecm_configuration.tm)' "${CP4A_PATTERN_FILE_TMP}"
                    break
                    ;;
                "ccxmo")
                    ${YQ_CMD} -i 'del(.spec.ecm_configuration.ccxmo)' "${CP4A_PATTERN_FILE_TMP}"
                    break
                    ;;
                "ier")
                    ${YQ_CMD} -i 'del(.spec.ier_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    break
                    ;;
                "iccsap")
                    ${YQ_CMD} -i 'del(.spec.iccsap_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    break
                    ;;
                "ban")
                    break
                    ;;
                "case")
                    if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "workstreams") && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "content_integration") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        ${YQ_CMD} -i 'del(.spec.ecm_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    fi
                    break
                    ;;
                "workstreams")
                    if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "case") && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "content_integration") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        ${YQ_CMD} -i 'del(.spec.ecm_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    fi
                    break
                    ;;
                "content_integration")
                    if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "workstreams") && (" ${OPTIONAL_COMPONENT_DELETE_LIST[@]} " =~ "case") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        ${YQ_CMD} -i 'del(.spec.ecm_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    fi
                    break
                    ;;
                "bai")
                    if [[ (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-runtime") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workstreams") ]]; then
                        break
                    elif [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" && (" ${OPT_COMPONENTS_CR_SELECTED[@]} " =~ "baml") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        break
                    else
                        ${YQ_CMD} -i 'del(.spec.bai_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                        break
                    fi
                    ;;
                "pfs")
                    if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        ${YQ_CMD} -i 'del(.spec.pfs_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    fi
                    break
                    ;;
                "baml")
                    if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams") ]]; then
                        ${YQ_CMD} -i 'del(.spec.baml_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    fi
                    break
                    ;;
                "workflow_assistant")
                    ${YQ_CMD} -i  'del(.spec.workflow_assistant_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    break
                    ;;
                "workplace_assistant")
                    ${YQ_CMD} -i 'del(.spec.workflow_assistant_configuration)' "${CP4A_PATTERN_FILE_TMP}"
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
                "application_connectors")
                    ${YQ_CMD} -i 'del(.spec.connectivity_pack_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                    break
                    ;;
                "workflow_runtime_mcp_server")
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
    pattern_file_bak=""
    printf "\x1B[1mProvide the path and file name to the existing custom resource (CR)?\n\x1B[0m"
    printf "\x1B[1mPress [Enter] to accept default.\n\x1B[0m"
    # printf "\x1B[1mDefault is \x1B[0m(${CP4A_PATTERN_FILE_BAK}): "
    # existing_pattern_cr_name=`${CLI_CMD} get icp4acluster|awk '{if(NR>1){if(NR==2){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }'`

    # <https://jsw.ibm.com/browse/DBACLD-159385> - Created new variable pattern_file_bak, if user had deployed Content it will switch the file path to ibm_content_cr_final.yaml
    if [[ $CONTENT_DEPLOYED == "Yes" ]]; then
        pattern_file_bak=$FNCM_SEPARATE_PATTERN_FILE_BAK
    else
        pattern_file_bak=$CP4A_PATTERN_FILE_BAK
    fi

    while [[ $existing_pattern_cr_name == "" ]];
    do
        read -p "[Default=$pattern_file_bak]: " existing_pattern_cr_name
        : ${existing_pattern_cr_name:=$pattern_file_bak}
        if [ -f "$existing_pattern_cr_name" ]; then
            existing_cr_type=`${YQ_CMD} ".kind" "$existing_pattern_cr_name"`
            existing_cr_type=$(echo "${existing_cr_type}" | tr '[:upper:]' '[:lower:]')
            # IF the CR kind is content , then some of the parameters are different compared to what we have for an ICP4ACluster type CR
            # The next if else block addresses this
            # For https://jsw.ibm.com/browse/DBACLD-159390
            if [[ "$existing_cr_type" == "content" ]];then
                # For content kind CR the deployment type is under content_deployment_type
                # For https://jsw.ibm.com/browse/DBACLD-159390
                existing_deployment_type=`${YQ_CMD} ".spec.content_deployment_type" "$existing_pattern_cr_name"`
                # For content kind CR the pattern list is foundation,content
                # For https://jsw.ibm.com/browse/DBACLD-159390
                existing_pattern_list="foundation,content"
                existing_opt_component_list=""
                # Loop through the keys and values of spec.content_optional_components which will give us the list of optional components selected
                optional_components_section=$(${YQ_CMD} ".spec.content_optional_components" "$existing_pattern_cr_name")
                while IFS=: read -r key value; do
                    key=$(echo "$key" | xargs)       
                    value=$(echo "$value" | xargs)
                    if [[ "$value" == "true" ]]; then
                        if [[ -n "$existing_opt_component_list" ]]; then
                        existing_opt_component_list+=","
                        fi
                        existing_opt_component_list+="$key"
                    fi
                done <<< "$optional_components_section"
            else
                # IF the CR is generated from the from UI then the sc_deployment_type is not a key that will be in the CR , it will be under olm_deployment_type
                # For https://jsw.ibm.com/browse/DBACLD-159390
                key_value=$(${YQ_CMD} '.spec.shared_configuration.sc_deployment_type' "$existing_pattern_cr_name" 2>/dev/null)
                if [[ "$key_value" ]]; then
                    existing_deployment_type=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_type" "$existing_pattern_cr_name"`
                else
                    existing_deployment_type=`${YQ_CMD} ".spec.olm_deployment_type" "$existing_pattern_cr_name"`
                fi
                key_value=$(${YQ_CMD} '.spec.shared_configuration.sc_deployment_patterns' "$existing_pattern_cr_name" 2>/dev/null)
                if [[ "$key_value" ]]; then
                    existing_pattern_list=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_patterns // \"\"" "$existing_pattern_cr_name"`
                else
                    # IF the CR is generated from the from UI then the sc_deployment_patterns is not a key that will be in the CR , the patterns selected will be mapped to the list of keys below by being set to true for a specific pattern key
                    # For https://jsw.ibm.com/browse/DBACLD-159390
                    keys=("olm_starter_application" "olm_starter_content" "olm_starter_decisions" "olm_starter_decisions_ads" "olm_starter_document_processing" "olm_starter_workflow")
                    for key in "${keys[@]}"; do
                        # Get the value of the current key from the YAML file
                        value=$(${YQ_CMD} ".spec.$key" "$existing_pattern_cr_name")
                        value=$(echo "$value" | xargs)
                        if [[ "$value" == "true" && "$key" == olm_starter_* ]]; then
                            part_after_prefix="${key#olm_starter_}"
                            if [ -z "$existing_pattern_list" ]; then
                                existing_pattern_list="$part_after_prefix"
                            else
                                existing_pattern_list="$existing_pattern_list,$part_after_prefix"
                            fi
                        fi
                    done
                fi
                
                key_value=$(${YQ_CMD} '.spec.shared_configuration.sc_optional_components' "$existing_pattern_cr_name" 2>/dev/null)
                if [[ "$key_value" ]]; then
                    existing_opt_component_list=`${YQ_CMD} ".spec.shared_configuration.sc_optional_components" "$existing_pattern_cr_name"`
                else
                    # IF the CR is generated from the from UI then the sc_deployment_patterns is not a key that will be in the CR , the patterns selected will be mapped to the olm_starter_option section by being set to true for a specific component key
                    # For https://jsw.ibm.com/browse/DBACLD-159390
                    existing_opt_component_list=""
                    # Loop through the keys and values
                    optional_components_section=$(${YQ_CMD} ".spec.olm_starter_option" "$existing_pattern_cr_name")
                    while IFS=: read -r key value; do
                        # Extract key and value using shell parameter expansion
                        key=$(echo "$key" | xargs)       # Trim whitespace from the key
                        value=$(echo "$value" | xargs)
                        if [[ "$value" == "true" ]]; then
                            if [[ -n "$existing_opt_component_list" ]]; then
                            existing_opt_component_list+=","
                            fi
                            existing_opt_component_list+="$key"
                        fi
                    done <<< "$optional_components_section"
                fi 
            fi
            existing_platform_type=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_platform" "$existing_pattern_cr_name"`
            existing_profile_type=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_profile_size" "$existing_pattern_cr_name"`

            if [[ $existing_deployment_type == "demo" ]];then
                existing_deployment_type="Starter"
            elif [[ $existing_deployment_type == "enterprise" ]];then
                existing_deployment_type="Production"
            fi
            case "${existing_deployment_type}" in
                starter*|Starter*)     DEPLOYMENT_TYPE="starter";;
                production*|Production*)    DEPLOYMENT_TYPE="production";;
                *)
                    printf '%b\n' "\x1B[1;31mInvalid deployment type found in CR, exiting....\n\x1B[0m"
                    exit 0
                    ;;
            esac

            case "${existing_platform_type}" in
                ROKS*)     PLATFORM_SELECTED="ROKS";;
                OCP*)    PLATFORM_SELECTED="OCP";;
                *)
                    printf '%b\n' "\x1B[1;31mInvalid platform type found in CR, exiting....\n\x1B[0m"
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
            if [[ "$existing_pattern_cr_name" == "$pattern_file_bak" ]]; then
                ${COPY_CMD} -rf "${pattern_file_bak}" "${CP4A_EXISTING_BAK}"
                ${COPY_CMD} -rf "${pattern_file_bak}" "${CP4A_EXISTING_TMP}"
            else
                ${COPY_CMD} -rf "${existing_pattern_cr_name}" "${pattern_file_bak}"
                ${COPY_CMD} -rf "${existing_pattern_cr_name}" "${CP4A_EXISTING_BAK}"
                ${COPY_CMD} -rf "${existing_pattern_cr_name}" "${CP4A_EXISTING_TMP}"
            fi
            # ${COPY_CMD} -rf "${FOUNDATION_PATTERN_FILE}" "${CP4A_PATTERN_FILE_TMP}"
            # ${YQ_CMD} m -a -i -M ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}
            # ${COPY_CMD} -rf "${CP4A_PATTERN_FILE_BAK}" "${CP4A_PATTERN_FILE_TMP}"
        else
            printf '%b\n' "\x1B[1;31m\"$existing_pattern_cr_name\" file does not exist! \n\x1B[0m"
            existing_pattern_cr_name=""
        fi
    done
    # existing_pattern_list=`${CLI_CMD} get icp4acluster $existing_pattern_cr_name -o yaml | yq r - spec.shared_configuration.sc_deployment_patterns`
    # existing_pattern_deploy_type=`${CLI_CMD} get icp4acluster $existing_pattern_cr_name -o yaml | yq r - spec.shared_configuration.sc_deployment_type`

    if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") ]]; then
        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "workflow-authoring" )
    fi

    if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && !(" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") ]]; then
        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "workflow-runtime" )
    fi

    if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer") ]]; then
        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "document_processing_designer" )
    fi

    if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_runtime") ]]; then
        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "document_processing_runtime" )
    fi

    if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-workstreams") && ("$DEPLOYMENT_TYPE" == "production") ]]; then
        printf '%b\n' "\x1B[1;31mYou are updating existing patterns including workflow-workstreams which is not supported.\x1B[0m"
        printf '%b\n' "\x1B[1;31mRefer to the documentation to upgrade or manually add another pattern.\x1B[0m"
        printf '%b\n' "\x1B[1;31mExiting...\x1B[0m"
        read -rsn1 -p"Press Enter/Return to exit";echo
        exit 1
    fi
}


function select_gpu_document_processing(){
    printf "\n"
    set_gpu_enabled=""
    ENABLE_GPU_ARIA=""
    while [[ $set_gpu_enabled == "" ]];
    do
        printf "\x1B[1mAre there GPU enabled worker nodes (Yes/No)? \x1B[0m"
        read -erp "" set_gpu_enabled
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
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
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
            read -erp "" nodelabel_key
            if [ -z "$nodelabel_key" ]; then
            printf '%b\n' "\x1B[1;31mEnter the node label key.\x1B[0m"
            fi
        done

        printf "\n"
        printf "\x1B[1mWhat is the node label value used to identify the GPU worker node(s)? \x1B[0m"
        nodelabel_value=""
        while [[ $nodelabel_value == "" ]];
        do
            read -erp "" nodelabel_value
            if [ -z "$nodelabel_value" ]; then
            printf '%b\n' "\x1B[1;31mEnter the node label value.\x1B[0m"
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

    elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
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
        ${YQ_CMD} -i '.spec.ads_configuration.decision_designer.enabled = true' ${ADS_PATTERN_FILE_TMP}
        ${YQ_CMD} -i '.spec.ads_configuration.decision_runtime.enabled = true' ${ADS_PATTERN_FILE_TMP}
        foundation_ads=("BAS")
        foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_ads[@]}" )

    elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
    then
        containsElement "ads_designer" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${YQ_CMD} -i '.spec.ads_configuration.decision_designer.enabled = true' ${ADS_PATTERN_FILE_TMP}
            foundation_ads=("BAS")
            foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_ads[@]}" )
        else
            ${YQ_CMD} -i '.spec.ads_configuration.decision_designer.enabled = false' ${ADS_PATTERN_FILE_TMP}
        fi
        containsElement "ads_runtime" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${YQ_CMD} -i '.spec.ads_configuration.decision_runtime.enabled = true' ${ADS_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.ads_configuration.decision_runtime.enabled = false' ${ADS_PATTERN_FILE_TMP}
        fi

    fi
    ${COPY_CMD} -rf ${ADS_PATTERN_FILE_TMP} ${ADS_PATTERN_FILE_BAK}
}


function set_decision_feature(){
    ${COPY_CMD} -rf ${DECISIONS_PATTERN_FILE_BAK} ${DECISIONS_PATTERN_FILE_TMP}
    if [[ $DEPLOYMENT_TYPE == "starter"  ]] ;
    then
        ${YQ_CMD} -i '.spec.odm_configuration.decisionCenter.enabled = true' ${DECISIONS_PATTERN_FILE_TMP}
        ${YQ_CMD} -i '.spec.odm_configuration.decisionServerRuntime.enabled = true' ${DECISIONS_PATTERN_FILE_TMP}
        ${YQ_CMD} -i '.spec.odm_configuration.decisionRunner.enabled = true' ${DECISIONS_PATTERN_FILE_TMP}
    elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
    then
        containsElement "decisionCenter" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${YQ_CMD} -i '.spec.odm_configuration.decisionCenter.enabled = true' ${DECISIONS_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.odm_configuration.decisionCenter.enabled = false' ${DECISIONS_PATTERN_FILE_TMP}
        fi
        containsElement "decisionServerRuntime" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${YQ_CMD} -i '.spec.odm_configuration.decisionServerRuntime.enabled = true' ${DECISIONS_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.odm_configuration.decisionServerRuntime.enabled = false' ${DECISIONS_PATTERN_FILE_TMP}
        fi
        containsElement "decisionRunner" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            ${YQ_CMD} -i '.spec.odm_configuration.decisionRunner.enabled = true' ${DECISIONS_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.odm_configuration.decisionRunner.enabled = false' ${DECISIONS_PATTERN_FILE_TMP}
        fi
    fi
    ${COPY_CMD} -rf ${DECISIONS_PATTERN_FILE_TMP} ${DECISIONS_PATTERN_FILE_BAK}
}

function set_aria_gpu(){
    ${COPY_CMD} -rf ${ARIA_PATTERN_FILE_BAK} ${ARIA_PATTERN_FILE_TMP}
    if [[ ("$DEPLOYMENT_TYPE" == "production" && (" ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing_designer")) || $DEPLOYMENT_TYPE == "starter" ]] ;
    then
        if [[ "$ENABLE_GPU_ARIA" == "Yes" ]]; then
            ${YQ_CMD} -i '.spec.ca_configuration.deeplearning.gpu_enabled = true' ${ARIA_PATTERN_FILE_TMP}
            # ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.ca_configuration.deeplearning.nodelabel_key "$nodelabel_key"
            ${SED_COMMAND} "s|nodelabel_key:.*|nodelabel_key: \"$nodelabel_key\"|g" ${ARIA_PATTERN_FILE_TMP}
            # ${YQ_CMD} w -i ${ARIA_PATTERN_FILE_TMP} spec.ca_configuration.deeplearning.nodelabel_value "$nodelabel_value"
            ${SED_COMMAND} "s|nodelabel_value:.*|nodelabel_value: \"$nodelabel_value\"|g" ${ARIA_PATTERN_FILE_TMP}

        elif [[ "$ENABLE_GPU_ARIA" == "No" ]]
        then
            ${YQ_CMD} -i '.spec.ca_configuration.deeplearning.gpu_enabled = false' ${ARIA_PATTERN_FILE_TMP}
        fi
    else
        ${YQ_CMD} -i '.spec.ca_configuration.deeplearning.gpu_enabled = false' ${ARIA_PATTERN_FILE_TMP}
    fi

    if [[ $DEPLOYMENT_TYPE == "starter" ]] ;
    then
        if [[ "$ADP_DL_ENABLED" == "Yes" ]]; then
            ${YQ_CMD} -i '.spec.ca_configuration.ocrextraction.deep_learning_object_detection.enabled = true' ${ARIA_PATTERN_FILE_TMP}
        elif [[ "$ADP_DL_ENABLED" == "No" ]]
        then
            ${YQ_CMD} -i '.spec.ca_configuration.ocrextraction.deep_learning_object_detection.enabled = false' ${ARIA_PATTERN_FILE_TMP}
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
    ORACLE_SERVICE_NAME=$(echo "$ORACLE_SERVICE_NAME" | tr '[:lower:]' '[:upper:]')
}

function sync_property_into_final_cr(){
    printf "\n"

    wait_msg "Generating the CP4BA Custom Resource file"
    
    # If the cp4a-deployment.sh script is being used to generate a CR with an updated list of optional components/deployment patterns, we want to make sure that the name of the CR currently applied is the same name as the CR that will be generated by the script. 
    # This should happen regardless if a new CR type is being created or the same CR type is being updated
    # $cluster_cr_name is set from the retrieve_current_custom_resource_file() function in update-selected-components.sh helper script
    if [[ "$UPDATE_COMPONENTS" == true ]]; then
        ${YQ_CMD} -i ".metadata.name = \"$cluster_cr_name\"" ${CP4A_PATTERN_FILE_TMP}
    fi

    #DBACLD-231903: For Vault we need to query the secret providerclass to the get the name.  For non-Vault we can continue to query the secret with label db-name
    local _secret_type=""
    if [[ "$vault_enabled" == "true"  && $DEPLOYMENT_TYPE == "production" ]]; then
        _secret_type="SecretProviderClass"
    else
        _secret_type="secret"
    fi
    # Applying global value in user profile property into final CR
    tmp_value="$(prop_user_profile_property_file CP4BA.CP4BA_LICENSE)"
    ${SED_COMMAND} "s|sc_deployment_license:.*|sc_deployment_license: \"$tmp_value\"|g" ${CP4A_PATTERN_FILE_TMP}

    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        tmp_value="$(prop_user_profile_property_file CP4BA.CONTENT_CORTEX_LICENSE)"
        ${SED_COMMAND} "s|sc_deployment_fncm_license:.*|sc_deployment_fncm_license: \"$tmp_value\"|g" ${CP4A_PATTERN_FILE_TMP}

        # sc_deployment_baw_license required for either workflow runtime or workflow authoring
        # For https://jsw.ibm.com/browse/DBACLD-161792
        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
            tmp_value="$(prop_user_profile_property_file CP4BA.BAW_LICENSE)"
            ${SED_COMMAND} "s|sc_deployment_baw_license:.*|sc_deployment_baw_license: \"$tmp_value\"|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_deployment_baw_license)' "${CP4A_PATTERN_FILE_TMP}"
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
            tmp_gcd_db_name=$(echo "$tmp_gcd_db_name" | tr '[:upper:]' '[:lower:]')
        fi
        
        #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
        # Initialize the isfalse variable to validate spec.datasource_configuration.dc_ssl_enabled is true or false
        isfalse=false
        for i in "${!GCDDB_CR_MAPPING[@]}"; do
            ${YQ_CMD} -i ".${GCDDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_gcd_db_servername.${GCDDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                 # Check if we are updating spec.datasource_configuration.dc_ssl_enabled value is False
                if [ "${GCDDB_CR_MAPPING[i]}" == "spec.datasource_configuration.dc_ssl_enabled" ] && [[ "$(prop_db_server_property_file $tmp_gcd_db_servername.${GCDDB_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                    # Set isfalse to true if the value is False
                    isfalse=true
                fi
                # Check if we are updating spec.datasource_configuration.dc_gcd_datasource.database_ssl_secret_name
                if [ "${GCDDB_CR_MAPPING[i]}" == "spec.datasource_configuration.dc_gcd_datasource.database_ssl_secret_name" ]; then
                    if [ "$isfalse" == "true" ]; then
                        # If isfalse is true, set the value to ""
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_gcd_datasource.database_ssl_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                    fi
                fi
        done

        # remove database_name if oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            get_oracle_service_name $(prop_db_server_property_file $tmp_gcd_db_servername.ORACLE_JDBC_URL)
            if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_gcd_datasource.database_name = \"${ORACLE_SERVICE_NAME}GCD\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_gcd_datasource.database_name = "<Required>"' ${CP4A_PATTERN_FILE_TMP}
            fi
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i ".spec.datasource_configuration.dc_gcd_datasource.database_name = \"$tmp_gcd_db_name\"" ${CP4A_PATTERN_FILE_TMP}
            if [[ $DB_TYPE == "postgresql-edb" ]]; then
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_gcd_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_gcd_datasource.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
            fi
        fi

        # Apply customized schema for GCDDB
        tmp_schema_name=$(prop_db_name_user_property_file GCD_DB_CURRENT_SCHEMA)
        tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
        if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_schema_name=$(echo "$tmp_schema_name" | tr '[:upper:]' '[:lower:]')
            fi
            ${YQ_CMD} -i ".spec.ecm_configuration.cpe_production_setting.gcd_schema = \"${tmp_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
        fi

        # By default we will always set the sc_enable_usage_metering flag to true and this will enable the operators to deploy the cron jobs to send usage metrics to software central
        # https://jsw.ibm.com/browse/DBACLD-225399
        ${YQ_CMD} -i ".spec.shared_configuration.sc_enable_usage_metering = true" ${CP4A_PATTERN_FILE_TMP}

        # Applying user profile for CONTENT INITIONLIZATION
        tmp_init_flag="$(prop_user_profile_property_file CONTENT_INITIALIZATION.ENABLE)"
        tmp_init_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_init_flag")
        if [[ $tmp_init_flag == "Yes" || $tmp_init_flag == "YES" || $tmp_init_flag == "Y" || $tmp_init_flag == "True" || $tmp_init_flag == "true" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_content_initialization = true' ${CP4A_PATTERN_FILE_TMP}

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
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_ldap_creation.ic_ldap_admin_user_name[$((num))] = \"${admin_user_name_array[$num]}\"" ${CP4A_PATTERN_FILE_TMP}
            done

            for num in "${!admin_group_name_array[@]}"; do
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_ldap_creation.ic_ldap_admins_groups_name[$((num))] = \"${admin_group_name_array[$num]}\"" ${CP4A_PATTERN_FILE_TMP}
            done
        else
            ${YQ_CMD} -i '.spec.shared_configuration.sc_content_initialization = false' ${CP4A_PATTERN_FILE_TMP}
        fi
    else
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_deployment_fncm_license)' "${CP4A_PATTERN_FILE_TMP}"
    fi

    # Applying value in Content Cortex OSDB property file into final CR
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
                tmp_os_db_name=$(echo "$tmp_os_db_name" | tr '[:upper:]' '[:lower:]')
            fi

            OS_DATASOURCE_NUMBER=$(grep "^        dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn "FNOS$((j+1))DS"|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
                # Initialize the isfalse variable to validate dc_ssl_enabled is true or false
                isfalse=false
                for i in "${!OSDB_CR_MAPPING[@]}"; do
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                    # Check if we are updating database_ssl_enable value is False
                    if [ "${OSDB_CR_MAPPING[i]}" == "database_ssl_enable" ] && [[ "$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                        isfalse=true
                    fi
                    # Check if we are updating database_ssl_secret_name
                    if [ "${OSDB_CR_MAPPING[i]}" == "database_ssl_secret_name" ]; then
                        if [ "$isfalse" == "true" ]; then
                            # If isfalse is true, set the value to ""
                            ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_ssl_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                        fi
                    fi
                done
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_os_label = \"os$((j+1))\"" ${CP4A_PATTERN_FILE_TMP}

                # remove database_name if oracle
                if [[ $DB_TYPE == "oracle" ]]; then
                    get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                    if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"${ORACLE_SERVICE_NAME}OS$((j+1))\"" ${CP4A_PATTERN_FILE_TMP}
                    else
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"<Required>\"" ${CP4A_PATTERN_FILE_TMP}
                    fi
                    # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"$tmp_os_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                    if [[ $DB_TYPE == "postgresql-edb" ]]; then
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_database_type = \"postgresql\"" ${CP4A_PATTERN_FILE_TMP}
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_use_postgres = \"true\"" ${CP4A_PATTERN_FILE_TMP}
                    fi
                fi
            fi
        done

        # apply oc_cpe_obj_store_admin_user_groups for Content Cortex OS
        for ((j=0;j<${content_os_number};j++))
        do
            if [[ $DB_TYPE == "oracle" ]]; then
                tmp_os_db_name="$(prop_db_name_user_property_file OS$((j+1))_DB_USER_NAME)"
            else
                tmp_os_db_name="$(prop_db_name_user_property_file OS$((j+1))_DB_NAME)"
            fi
            OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn FNOS$((j+1))DS|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
                tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
                OIFS=$IFS
                IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
                IFS=$OIFS

                for num in "${!admin_user_group_array[@]}"; do
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups[$((num))] = \"${admin_user_group_array[$num]}\"" ${CP4A_PATTERN_FILE_TMP}
                done
                # Apply customized schema
                # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                tmp_schema_name=$(prop_db_name_user_property_file OS$((j+1))_DB_CURRENT_SCHEMA)
                tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
                if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        tmp_schema_name=$(echo "$tmp_schema_name" | tr '[:upper:]' '[:lower:]')
                    fi
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name = \"${tmp_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
                fi
                # fi
                tmp_table_storage_location_prop="$(prop_db_name_user_property_file OS$((j+1))_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                tmp_index_storage_location_prop="$(prop_db_name_user_property_file OS$((j+1))_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                tmp_lob_storage_location_prop="$(prop_db_name_user_property_file OS$((j+1))_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
                # Function to populate the os tablespace section for table index and lob storage
                # Function definition in common.sh
                # https://jsw.ibm.com/browse/DBACLD-175710
                populate_os_tablespaces "$tmp_os_db_name" "$DB_TYPE" "$OS_DATASOURCE_NUMBER" "$tmp_table_storage_location_prop" "$tmp_index_storage_location_prop" "$tmp_lob_storage_location_prop"
                
                ## End of custom tables,index,lob tablespaces


            fi
        done

    fi
    # Apply value in Content Cortex OS required by BAW authoring property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
        for i in "${!BAW_AUTH_OS_ARR[@]}"; do
            OS_DATASOURCE_NUMBER=$(grep "^        dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_AUTH_OS_ARR[i]}|cut -d':' -f1)
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
                    tmp_os_db_name=$(echo "$tmp_os_db_name" | tr '[:upper:]' '[:lower:]')
                fi
                #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
                # Initialize the isfalse variable to validate dc_ssl_enabled is true or false
                isfalse=false
                for j in "${!OSDB_CR_MAPPING[@]}"; do
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[j]} = \"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[$j]})\"" ${CP4A_PATTERN_FILE_TMP}
                    # Check if we are updating database_ssl_enable value is False
                    if [ "${OSDB_CR_MAPPING[j]}" == "database_ssl_enable" ] && [[ "$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[j]})" =~ ^[fF]alse$ ]]; then
                        isfalse=true
                    fi
                    # Check if we are updating database_ssl_secret_name
                    if [ "${OSDB_CR_MAPPING[j]}" == "database_ssl_secret_name" ]; then
                        if [ "$isfalse" == "true" ]; then
                            # If isfalse is true, set the value to ""
                            ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_ssl_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                        fi
                    fi
                done

                tmp_label=$(echo "${BAW_AUTH_OS_ARR[i]}" | tr '[:upper:]' '[:lower:]')
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label = \"$tmp_label\"" ${CP4A_PATTERN_FILE_TMP}
                # remove database_name if oracle
                if [[ $DB_TYPE == "oracle" ]]; then
                    get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                    if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"${ORACLE_SERVICE_NAME}${BAW_AUTH_OS_ARR[$i]}\"" ${CP4A_PATTERN_FILE_TMP}
                    else
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"<Required>\"" ${CP4A_PATTERN_FILE_TMP}
                    fi
                    # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"$tmp_os_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                    if [[ $DB_TYPE == "postgresql-edb" ]]; then
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_database_type = \"postgresql\"" ${CP4A_PATTERN_FILE_TMP}
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_use_postgres = \"true\"" ${CP4A_PATTERN_FILE_TMP}
                    fi
                fi
            fi
            # Apply customized schema
            OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_AUTH_OS_ARR[i]} |cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                tmp_schema_name=$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_CURRENT_SCHEMA)
                tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
                if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        tmp_schema_name=$(echo "$tmp_schema_name" | tr '[:upper:]' '[:lower:]')
                    fi
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name = \"${tmp_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
                fi

                ## Applying custom table, index, log tablespaces for objectstore creation.
                ## Retrieving the tables,index, and lob storage location from the properties files
                ## to be passed to the helper functions to create the sql files.
                tmp_table_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                tmp_index_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                tmp_lob_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
                # Function to populate the os tablespace section for table index and lob storage
                # Function definition in common.sh
                # https://jsw.ibm.com/browse/DBACLD-175710
                populate_os_tablespaces "$tmp_os_db_name" "$DB_TYPE" "$OS_DATASOURCE_NUMBER" "$tmp_table_storage_location_prop" "$tmp_index_storage_location_prop" "$tmp_lob_storage_location_prop"
                
            fi
        done

        # apply oc_cpe_obj_store_admin_user_groups for Content Cortex OS used by BAW authoring
        for i in "${!BAW_AUTH_OS_ARR[@]}"; do
            OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_AUTH_OS_ARR[i]}|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
                tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
                OIFS=$IFS
                IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
                IFS=$OIFS

                for num in "${!admin_user_group_array[@]}"; do
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups[$((num))] = \"${admin_user_group_array[$num]}\"" ${CP4A_PATTERN_FILE_TMP}
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
                    tmp_val=$(echo "$tmp_val" | tr '[:upper:]' '[:lower:]')
                elif [[ $DB_TYPE == "oracle" ]]; then
                    tmp_val=$(echo "$tmp_val" | tr '[:lower:]' '[:upper:]')
                fi
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_data_tbl_space = \"$tmp_val\"" ${CP4A_PATTERN_FILE_TMP}

                tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_ADMIN_GROUP)
                tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_admin_group = \"$tmp_val\"" ${CP4A_PATTERN_FILE_TMP}

                tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_CONFIG_GROUP)
                tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_config_group = \"$tmp_val\"" ${CP4A_PATTERN_FILE_TMP}

                tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME)
                tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_pe_conn_point_name = \"$tmp_val\"" ${CP4A_PATTERN_FILE_TMP}
            fi
        fi

    fi

    # Apply value in Content Cortex OS required by BAW runtime property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" ]]; then
        BAW_RUNTIME_OS_ARR=("BAWINS1DOCS" "BAWINS1DOS" "BAWINS1TOS")
        for i in "${!BAW_AUTH_OS_ARR[@]}"; do
            OS_DATASOURCE_NUMBER=$(grep "^        dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_RUNTIME_OS_ARR[i]}|cut -d':' -f1)
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
                    tmp_os_db_name=$(echo "$tmp_os_db_name" | tr '[:upper:]' '[:lower:]')
                fi
                #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
                # Initialize the isfalse variable to validate dc_ssl_enabled is true or false for BAWDOCS
                isfalse=false
                for j in "${!OSDB_CR_MAPPING[@]}"; do
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[j]} = \"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[$j]})\"" ${CP4A_PATTERN_FILE_TMP}
                # Check if we are updating database_ssl_enable value to False
                if [ "${OSDB_CR_MAPPING[j]}" == "database_ssl_enable" ] && [[ "$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[j]})" =~ ^[fF]alse$ ]]; then
                    isfalse=true
                fi
                # Check if we are updating database_ssl_secret_name
                if [ "${OSDB_CR_MAPPING[j]}" == "database_ssl_secret_name" ]; then
                    if [ "$isfalse" == "true" ]; then
                        # If isfalse is true, set the value to ""
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_ssl_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                    fi
                fi
                done

                tmp_label=$(echo "${BAW_AUTH_OS_ARR[i]}" | tr '[:upper:]' '[:lower:]')

                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label = \"$tmp_label\"" ${CP4A_PATTERN_FILE_TMP}

                # remove database_name if oracle
                if [[ $DB_TYPE == "oracle" ]]; then
                    get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                    if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"${ORACLE_SERVICE_NAME}${BAW_AUTH_OS_ARR[$i]}\"" ${CP4A_PATTERN_FILE_TMP}
                    else
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"<Required>\"" ${CP4A_PATTERN_FILE_TMP}
                    fi
                    # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"$tmp_os_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                    if [[ $DB_TYPE == "postgresql-edb" ]]; then
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_database_type = \"postgresql\"" ${CP4A_PATTERN_FILE_TMP}
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_use_postgres = \"true\"" ${CP4A_PATTERN_FILE_TMP}
                    fi
                fi
            fi

            # Apply customized schema
            OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_RUNTIME_OS_ARR[i]} |cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                tmp_schema_name=$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_CURRENT_SCHEMA)
                tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
                if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        tmp_schema_name=$(echo "$tmp_schema_name" | tr '[:upper:]' '[:lower:]')
                    fi
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name = \"${tmp_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
                fi
                # fi
            fi
            ## Applying custom table, index, log tablespaces for objectstore creation.
            ## Retrieving the tables,index, and lob storage location from the properties files
            ## to be passed to the helper functions to create the sql files.
            OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_RUNTIME_OS_ARR[i]} |cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                tmp_table_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                tmp_index_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                tmp_lob_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
                # Function to populate the os tablespace section for table index and lob storage
                # Function definition in common.sh
                # https://jsw.ibm.com/browse/DBACLD-175710
                populate_os_tablespaces "$tmp_os_db_name" "$DB_TYPE" "$OS_DATASOURCE_NUMBER" "$tmp_table_storage_location_prop" "$tmp_index_storage_location_prop" "$tmp_lob_storage_location_prop"
            fi

        done

        # apply oc_cpe_obj_store_admin_user_groups for Content Cortex OS used by BAW runtime
        for i in "${!BAW_RUNTIME_OS_ARR[@]}"; do
            OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn ${BAW_RUNTIME_OS_ARR[i]}|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
                tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
                OIFS=$IFS
                IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
                IFS=$OIFS

                for num in "${!admin_user_group_array[@]}"; do
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups[$((num))] = \"${admin_user_group_array[$num]}\"" ${CP4A_PATTERN_FILE_TMP}
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
                        tmp_val=$(echo "$tmp_val" | tr '[:upper:]' '[:lower:]')
                    elif [[ $DB_TYPE == "oracle" ]]; then
                        tmp_val=$(echo "$tmp_val" | tr '[:lower:]' '[:upper:]')
                    fi
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_data_tbl_space = \"$tmp_val\"" ${CP4A_PATTERN_FILE_TMP}

                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_ADMIN_GROUP)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_admin_group = \"$tmp_val\"" ${CP4A_PATTERN_FILE_TMP}

                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_CONFIG_GROUP)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_config_group = \"$tmp_val\"" ${CP4A_PATTERN_FILE_TMP}

                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                    ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_pe_conn_point_name = \"$tmp_val\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        done

    fi

    # Apply value in Content Cortex OS required by AWS property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^        dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AWSINS1DOCS'|cut -d':' -f1)
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
                tmp_os_db_name=$(echo "$tmp_os_db_name" | tr '[:upper:]' '[:lower:]')
            fi
            #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
            # Initialize the isfalse variable to validate dc_ssl_enabled is true or false for AWSDOCS
            isfalse=false
            for i in "${!OSDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
            # Check if we are updating database_ssl_enable value is False
            if [ "${OSDB_CR_MAPPING[i]}" == "database_ssl_enable" ] && [[ "$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                isfalse=true
            fi
            # Check if we are updating database_ssl_secret_name
            if [ "${OSDB_CR_MAPPING[i]}" == "database_ssl_secret_name" ]; then
                if [ "$isfalse" == "true" ]; then
                    # If isfalse is true, set the value to ""
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_ssl_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
            done

            ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_os_label = \"awsdocs\"" ${CP4A_PATTERN_FILE_TMP}

            # remove database_name if oracle
            if [[ $DB_TYPE == "oracle" ]]; then
                get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"${ORACLE_SERVICE_NAME}AWSDOCS\"" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"<Required>\"" ${CP4A_PATTERN_FILE_TMP}
                fi
                # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"$tmp_os_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                if [[ $DB_TYPE == "postgresql-edb" ]]; then
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_database_type = \"postgresql\"" ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_use_postgres = \"true\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        fi

        # Apply customized schema
        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AWSINS1DOCS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_schema_name=$(prop_db_name_user_property_file AWSDOCS_DB_CURRENT_SCHEMA)
            tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
            if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_schema_name=$(echo "$tmp_schema_name" | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name = \"${tmp_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
            fi
            # fi
        fi

        # apply oc_cpe_obj_store_admin_user_groups for Content Cortex OS used by workstreams
        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AWSINS1DOCS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
            tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
            OIFS=$IFS
            IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
            IFS=$OIFS

            for num in "${!admin_user_group_array[@]}"; do
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups[$((num))] = \"${admin_user_group_array[$num]}\"" ${CP4A_PATTERN_FILE_TMP}
            done
        fi


        ## Applying custom table, index, log tablespaces for objectstore creation.
        ## Retrieving the tables,index, and lob storage location from the properties files
        ## to be passed to the helper functions to create the sql files.
        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AWSINS1DOCS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_table_storage_location_prop="$(prop_db_name_user_property_file AWSDOCS_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
            tmp_index_storage_location_prop="$(prop_db_name_user_property_file AWSDOCS_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
            tmp_lob_storage_location_prop="$(prop_db_name_user_property_file AWSDOCS_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
            # Function to populate the os tablespace section for table index and lob storage
            # Function definition in common.sh
            # https://jsw.ibm.com/browse/DBACLD-175710
            populate_os_tablespaces "$tmp_os_db_name" "$DB_TYPE" "$OS_DATASOURCE_NUMBER" "$tmp_table_storage_location_prop" "$tmp_index_storage_location_prop" "$tmp_lob_storage_location_prop"
        fi


    fi

    # Apply value in DEVOS1 property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^        dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'DEVOS1DS'|cut -d':' -f1)
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
                tmp_os_db_name=$(echo "$tmp_os_db_name" | tr '[:upper:]' '[:lower:]')
            fi
            #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
            # Initialize the isfalse variable to validate dc_ssl_enabled is true or false for DEVOS1 
            isfalse=false
            for i in "${!OSDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                # Check if we are updating database_ssl_enable value is False
            if [ "${OSDB_CR_MAPPING[i]}" == "database_ssl_enable" ] && [[ "$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                isfalse=true
            fi
            # Check if we are updating database_ssl_secret_name
            if [ "${OSDB_CR_MAPPING[i]}" == "database_ssl_secret_name" ]; then
                if [ "$isfalse" == "true" ]; then
                    # If isfalse is true, set the value to ""
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_ssl_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
            done
            ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_os_label = \"devos1\"" ${CP4A_PATTERN_FILE_TMP}
            # remove database_name if oracle
            if [[ $DB_TYPE == "oracle" ]]; then
                get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"${ORACLE_SERVICE_NAME}DEVOS\"" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"<Required>\"" ${CP4A_PATTERN_FILE_TMP}
                fi
                # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"$tmp_os_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                if [[ $DB_TYPE == "postgresql-edb" ]]; then
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_database_type = \"postgresql\"" ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_use_postgres = \"true\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        fi
        # apply oc_cpe_obj_store_admin_user_groups for Content Cortex OS used by DEVOS1
        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'DEVOS1DS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
            tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
            OIFS=$IFS
            IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
            IFS=$OIFS
            ${YQ_CMD} -i "del(.spec.initialize_configuration.ic_obj_store_creation.object_stores[\"${OS_DATASOURCE_NUMBER}\"].oc_cpe_obj_store_admin_user_groups)" "${CP4A_PATTERN_FILE_TMP}"
            for num in "${!admin_user_group_array[@]}"; do
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups[$((num))] = \"${admin_user_group_array[$num]}\"" ${CP4A_PATTERN_FILE_TMP}
            done
        fi

        # Apply customized schema
        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'DEVOS1DS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_schema_name=$(prop_db_name_user_property_file DEVOS_DB_CURRENT_SCHEMA)
            tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
            if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_schema_name=$(echo "$tmp_schema_name" | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name = \"${tmp_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
            fi
            # fi
        fi

        ## Applying custom table, index, log tablespaces for objectstore creation.
        ## Retrieving the tables,index, and lob storage location from the properties files
        ## to be passed to the helper functions to create the sql files.
        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'DEVOS1DS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_table_storage_location_prop="$(prop_db_name_user_property_file DEVOS_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
            tmp_index_storage_location_prop="$(prop_db_name_user_property_file DEVOS_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
            tmp_lob_storage_location_prop="$(prop_db_name_user_property_file DEVOS_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
            # Function to populate the os tablespace section for table index and lob storage
            # Function definition in common.sh
            # https://jsw.ibm.com/browse/DBACLD-175710
            populate_os_tablespaces "$tmp_os_db_name" "$DB_TYPE" "$OS_DATASOURCE_NUMBER" "$tmp_table_storage_location_prop" "$tmp_index_storage_location_prop" "$tmp_lob_storage_location_prop"
        fi

    fi

    # Apply value in Content Cortex OS required by AE data persistent property file into final CR
    if [[ "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^        dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS'|cut -d':' -f1)
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
                tmp_os_db_name=$(echo "$tmp_os_db_name" | tr '[:upper:]' '[:lower:]')
            fi
            #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
            # Initialize the isfalse variable to validate dc_ssl_enabled is true or false for AEOS
            isfalse=false
            for i in "${!OSDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
            # Check if we are updating database_ssl_enable value is False
            if [ "${OSDB_CR_MAPPING[i]}" == "database_ssl_enable" ] && [[ "$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                isfalse=true
            fi
            # Check if we are updating database_ssl_secret_name
            if [ "${OSDB_CR_MAPPING[i]}" == "database_ssl_secret_name" ]; then
                if [ "$isfalse" == "true" ]; then
                    # If isfalse is true, set the value to ""
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_ssl_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
            done
            ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_os_label = \"aeos\"" ${CP4A_PATTERN_FILE_TMP}
            # remove database_name if oracle
            if [[ $DB_TYPE == "oracle" ]]; then
                get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"${ORACLE_SERVICE_NAME}AEOS\"" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"<Required>\"" ${CP4A_PATTERN_FILE_TMP}
                fi
                # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"$tmp_os_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                if [[ $DB_TYPE == "postgresql-edb" ]]; then
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_database_type = \"postgresql\"" ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_use_postgres = \"true\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        fi

        # Apply customized schema
        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_schema_name=$(prop_db_name_user_property_file AEOS_DB_CURRENT_SCHEMA)
            tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
            if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_schema_name=$(echo "$tmp_schema_name" | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name = \"${tmp_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
            fi
            # fi
        fi

        # apply oc_cpe_obj_store_admin_user_groups for Content Cortex OS used by AE data persistent
        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
            tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
            OIFS=$IFS
            IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
            IFS=$OIFS

            for num in "${!admin_user_group_array[@]}"; do
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups[$((num))] = \"${admin_user_group_array[$num]}\"" ${CP4A_PATTERN_FILE_TMP}
            done
        fi

        ## Applying custom table, index, log tablespaces for objectstore creation.
        ## Retrieving the tables,index, and lob storage location from the properties files
        ## to be passed to the helper functions to create the sql files.
        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_table_storage_location_prop="$(prop_db_name_user_property_file AEOS_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
            tmp_index_storage_location_prop="$(prop_db_name_user_property_file AEOS_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
            tmp_lob_storage_location_prop="$(prop_db_name_user_property_file AEOS_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
            # Function to populate the os tablespace section for table index and lob storage
            # Function definition in common.sh
            # https://jsw.ibm.com/browse/DBACLD-175710
            populate_os_tablespaces "$tmp_os_db_name" "$DB_TYPE" "$OS_DATASOURCE_NUMBER" "$tmp_table_storage_location_prop" "$tmp_index_storage_location_prop" "$tmp_lob_storage_location_prop"
        fi


    fi

    # Apply value in Content Cortex OS required by Case history property file into final CR
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^        dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'CHOS'|cut -d':' -f1)
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
                tmp_os_db_name=$(echo "$tmp_os_db_name" | tr '[:upper:]' '[:lower:]')
            fi
            for i in "${!OSDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
            done

            ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_os_label = \"ch\"" ${CP4A_PATTERN_FILE_TMP}

            # remove database_name if oracle
            if [[ $DB_TYPE == "oracle" ]]; then
                get_oracle_service_name $(prop_db_server_property_file $tmp_os_db_servername.ORACLE_JDBC_URL)
                if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"${ORACLE_SERVICE_NAME}CHOS\"" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"<Required>\"" ${CP4A_PATTERN_FILE_TMP}
                fi
                # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].database_name = \"$tmp_os_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                if [[ $DB_TYPE == "postgresql-edb" ]]; then
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_database_type = \"postgresql\"" ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_os_datasources[$OS_DATASOURCE_NUMBER].dc_use_postgres = \"true\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        fi
        # Apply customized schema
        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'CHOS' |cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_schema_name=$(prop_db_name_user_property_file CHOS_DB_CURRENT_SCHEMA)
            tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
            if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_schema_name=$(echo "$tmp_schema_name" | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_schema_name = \"${tmp_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
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
                tmp_icn_db_name=$(echo "$tmp_icn_db_name" | tr '[:upper:]' '[:lower:]')
            fi
            
            #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
            # Initialize the isfalse variable to validate dc_ssl_enabled is true or false
            isfalse=false
            for i in "${!ICNDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} -i ".${ICNDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_icn_db_servername.${ICNDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                # Check if we are updating spec.datasource_configuration.dc_ssl_enabled value is false    
                if [ "${ICNDB_CR_MAPPING[i]}" == "spec.datasource_configuration.dc_ssl_enabled" ] && [[ "$(prop_db_server_property_file $tmp_icn_db_servername.${ICNDB_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                    isfalse=true
                fi
                if [ "${ICNDB_CR_MAPPING[i]}" == "spec.datasource_configuration.dc_icn_datasource.database_ssl_secret_name" ] && [ "$isfalse" == "true" ]; then
                    # Set the value to "" if isfalse is true
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_icn_datasource.database_ssl_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                fi
                # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} "${ICNDB_CR_MAPPING[i]}" "\"$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_icn_db_servername.${ICNDB_COMMON_PROPERTY[i]})")\""
            done

            # remove database_name if oracle
            if [[ $DB_TYPE == "oracle" ]]; then
                get_oracle_service_name $(prop_db_server_property_file $tmp_icn_db_servername.ORACLE_JDBC_URL)
                if [[ ! -z "$ORACLE_SERVICE_NAME" ]]; then
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_icn_datasource.database_name = \"${ORACLE_SERVICE_NAME}ICN\"" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_icn_datasource.database_name = "<Required>"' ${CP4A_PATTERN_FILE_TMP}
                fi
                # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_icn_datasource.database_name = \"$tmp_icn_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                if [[ $DB_TYPE == "postgresql-edb" ]]; then
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_icn_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_icn_datasource.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
            # Apply customized schema for GCDDB
            tmp_schema_name=$(prop_db_name_user_property_file ICN_DB_CURRENT_SCHEMA)
            tmp_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_schema_name")
            if [[ $tmp_schema_name != "<Optional>" && $tmp_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_schema_name=$(echo "$tmp_schema_name" | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} -i ".spec.navigator_configuration.icn_production_setting.icn_schema = \"${tmp_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
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
            ${YQ_CMD} -i ".${ODMDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_odm_db_servername.${ODMDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
        done
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_odm_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_odm_datasource.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
            # set dc_common_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`${YQ_CMD} ".spec.datasource_configuration.dc_odm_datasource // \"\"" "$CP4A_PATTERN_FILE_TMP"`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_odm_datasource.dc_common_ssl_enabled = true' ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
        # For ODM, set dc_ssl_secret_name only when db is db2/oracle/postgresql with clientAuth
        if [[ $DB_TYPE == "postgresql" ]]; then
            postgresql_ssl_enable=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_odm_db_servername.DATABASE_SSL_ENABLE)")
            tmp_ssl_flag=$(echo "$postgresql_ssl_enable" | tr '[:upper:]' '[:lower:]')

            postgresql_client_auth_enable=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_odm_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_client_auth_flag=$(echo "$postgresql_client_auth_enable" | tr '[:upper:]' '[:lower:]')
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
            tmp_ssl_flag=$(echo "$tmp_ssl_flag" | tr '[:upper:]' '[:lower:]')
            if [[ $tmp_ssl_flag == "yes" || $tmp_ssl_flag == "true" || $tmp_ssl_flag == "y" ]]; then
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_odm_datasource.dc_ssl_secret_name = \"$(prop_db_server_property_file $tmp_odm_db_servername.DATABASE_SSL_SECRET_NAME)\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_odm_datasource.dc_ssl_secret_name = ""' ${CP4A_PATTERN_FILE_TMP}
            fi
        else
            ${SED_COMMAND} "s|dc_ssl_secret_name: |# dc_ssl_secret_name: |g" ${CP4A_PATTERN_FILE_TMP}
        fi

        # set dc_odm_datasource.dc_common_database_instance_secret
        tmp_secret_name=`${CLI_CMD} get $_secret_type -l db-name=${tmp_odm_db_name} -o yaml -n $CP4BA_SERVICES_NS | ${YQ_CMD} '.items.[0].metadata.name' -`
        ${YQ_CMD} -i ".spec.datasource_configuration.dc_odm_datasource.dc_common_database_instance_secret = \"$tmp_secret_name\"" ${CP4A_PATTERN_FILE_TMP}

        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_odm_db_name=$(echo "$tmp_odm_db_name" | tr '[:upper:]' '[:lower:]')
        fi
        ${YQ_CMD} -i ".spec.datasource_configuration.dc_odm_datasource.dc_common_database_name = \"$tmp_odm_db_name\"" ${CP4A_PATTERN_FILE_TMP}
        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_odm_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_odm_db_servername.ORACLE_JDBC_URL)")
            ${YQ_CMD} -i ".spec.datasource_configuration.dc_odm_datasource.dc_common_database_url = \"$tmp_odm_db_jdbc_url\"" ${CP4A_PATTERN_FILE_TMP}
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
    #         tmp_baw_authoring_db_name=$(echo "$tmp_baw_authoring_db_name" | tr '[:upper:]' '[:lower:]')
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
        
        #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
        # Initialize the isfalse variable to validate dc_ssl_enabled is true or false for BAWDB
        isfalse=false
        for i in "${!BAW_RUNTIME_CR_MAPPING[@]}"; do
            if [[ ("${BAW_RUNTIME_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${BAW_RUNTIME_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} -i ".${BAW_RUNTIME_CR_MAPPING[i]} = \"<Remove>\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".${BAW_RUNTIME_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_baw_runtime_db_servername.${BAW_RUNTIME_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                # Check if we are updating spec.datasource_configuration.dc_ssl_enabled value to false
                if [ "${BAW_RUNTIME_CR_MAPPING[i]}" == "spec.baw_configuration.[0].database.enable_ssl" ] && [[ "$(prop_db_server_property_file $tmp_baw_runtime_db_servername.${BAW_RUNTIME_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                    isfalse=true
                fi
                # If SSL is disabled, set the database_ssl_secret_name to ""
                if [ "${BAW_RUNTIME_CR_MAPPING[i]}" == "spec.baw_configuration.[0].database.db_cert_secret_name" ] && [ "$isfalse" == "true" ]; then
                    ${YQ_CMD} -i ".spec.baw_configuration[0].database.db_cert_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        done
        
        # For DBACLD-155445 where we need to use the namespace value passed to find the secret name and populate the CR accordingly
        tmp_secret_name=`${CLI_CMD} get $_secret_type -l db-name=${tmp_baw_runtime_db_name} -o yaml -n $CP4BA_SERVICES_NS | ${YQ_CMD} '.items.[0].metadata.name' -`
        # set baw_configuration
        ${YQ_CMD} -i ".spec.baw_configuration.[0].database.secret_name = \"$tmp_secret_name\"" ${CP4A_PATTERN_FILE_TMP}
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_baw_runtime_db_name=$(echo "$tmp_baw_runtime_db_name" | tr '[:upper:]' '[:lower:]')
        fi

        # remove database_name if oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.database_name = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i ".spec.baw_configuration.[0].database.database_name = \"$tmp_baw_runtime_db_name\"" ${CP4A_PATTERN_FILE_TMP}
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_baw_runtime_db_jdbc_url="$(prop_db_server_property_file $tmp_baw_runtime_db_servername.ORACLE_JDBC_URL)"
            tmp_baw_runtime_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_jdbc_url")
            ${YQ_CMD} -i ".spec.baw_configuration.[0].database.jdbc_url = \"$tmp_baw_runtime_db_jdbc_url\"" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.jdbc_url = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            ${SED_COMMAND} 's|jdbc_url: "<Remove>"|# jdbc_url: ""|g' ${CP4A_PATTERN_FILE_TMP}
        fi
        ${YQ_CMD} -i '.spec.baw_configuration[0].database.custom_jdbc_pvc = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} 's|custom_jdbc_pvc: "<Remove>"|# custom_jdbc_pvc: ""|g' ${CP4A_PATTERN_FILE_TMP}

        # set current schema name for db2 and postgresql
        if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_baw_runtime_db_current_schema_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_CURRENT_SCHEMA)"
            tmp_baw_runtime_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_current_schema_name")
            if [[ $tmp_baw_runtime_db_current_schema_name != "<Optional>" && $tmp_baw_runtime_db_current_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_baw_runtime_db_current_schema_name=$(echo "$tmp_baw_runtime_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                fi
                ${YQ_CMD} -i ".spec.baw_configuration.[0].database.current_schema = \"$tmp_baw_runtime_db_current_schema_name\"" ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
            # always use default schema for EDB Postgres
            ${YQ_CMD} -i 'del(.spec.baw_configuration.[0].database.current_schema)' "${CP4A_PATTERN_FILE_TMP}"
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`${YQ_CMD} ".spec.baw_configuration.[0].database // \"\"" "$CP4A_PATTERN_FILE_TMP"`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} -i '.spec.baw_configuration[0].database.enable_ssl = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.baw_configuration[0].database.db_cert_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
        # Applying user profile for BAW runtime
        tmp_baw_runtime_admin="$(prop_user_profile_property_file BAW_RUNTIME.ADMIN_USER)"
        ${YQ_CMD} -i ".spec.baw_configuration.[0].admin_user = \"$tmp_baw_runtime_admin\"" ${CP4A_PATTERN_FILE_TMP}
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
        #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
        # Initialize the isfalse variable to validate dc_ssl_enabled is true or false for BAWDB
        isfalse=false
        for i in "${!BAW_RUNTIME_CR_MAPPING[@]}"; do
            if [[ ("${BAW_RUNTIME_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${BAW_RUNTIME_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} -i ".${BAW_RUNTIME_CR_MAPPING[i]} = \"<Remove>\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".${BAW_RUNTIME_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_baw_runtime_db_servername.${BAW_RUNTIME_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                # Check if we are updating spec.datasource_configuration.dc_ssl_enabled value to false
                if [ "${BAW_RUNTIME_CR_MAPPING[i]}" == "spec.baw_configuration.[0].database.enable_ssl" ] && [[ "$(prop_db_server_property_file $tmp_baw_runtime_db_servername.${BAW_RUNTIME_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                    isfalse=true
                fi
                # If SSL is disabled, set the database_ssl_secret_name to ""
                if [ "${BAW_RUNTIME_CR_MAPPING[i]}" == "spec.baw_configuration.[0].database.db_cert_secret_name" ] && [ "$isfalse" == "true" ]; then
                    ${YQ_CMD} -i ".spec.baw_configuration[0].database.db_cert_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        done

        # For DBACLD-155445 where we need to use the namespace value passed to find the secret name and populate the CR accordingly
        tmp_secret_name=`${CLI_CMD} get $_secret_type -l db-name=${tmp_baw_runtime_db_name} -o yaml -n $CP4BA_SERVICES_NS | ${YQ_CMD} '.items.[0].metadata.name' -`
        # set baw_configuration
        ${YQ_CMD} -i ".spec.baw_configuration.[0].database.secret_name = \"$tmp_secret_name\"" ${CP4A_PATTERN_FILE_TMP}
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_baw_runtime_db_name=$(echo "$tmp_baw_runtime_db_name" | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.database_name = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i ".spec.baw_configuration.[0].database.database_name = \"$tmp_baw_runtime_db_name\"" ${CP4A_PATTERN_FILE_TMP}
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_baw_runtime_db_jdbc_url="$(prop_db_server_property_file $tmp_baw_runtime_db_servername.ORACLE_JDBC_URL)"
            tmp_baw_runtime_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_jdbc_url")
            ${YQ_CMD} -i ".spec.baw_configuration.[0].database.jdbc_url = \"$tmp_baw_runtime_db_jdbc_url\"" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.jdbc_url = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            ${SED_COMMAND} 's|jdbc_url: "<Remove>"|# jdbc_url: ""|g' ${CP4A_PATTERN_FILE_TMP}
        fi
        ${YQ_CMD} -i '.spec.baw_configuration[0].database.custom_jdbc_pvc = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} 's|custom_jdbc_pvc: "<Remove>"|# custom_jdbc_pvc: ""|g' ${CP4A_PATTERN_FILE_TMP}

        # set current schema name for db2 and postgresql
        if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_baw_runtime_db_current_schema_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_CURRENT_SCHEMA)"
            tmp_baw_runtime_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_current_schema_name")
            if [[ $tmp_baw_runtime_db_current_schema_name != "<Optional>" && $tmp_baw_runtime_db_current_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_baw_runtime_db_current_schema_name=$(echo "$tmp_baw_runtime_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                fi

                ${YQ_CMD} -i ".spec.baw_configuration.[0].database.current_schema = \"$tmp_baw_runtime_db_current_schema_name\"" ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
            # always use default schema for EDB Postgres
            ${YQ_CMD} -i 'del(.spec.baw_configuration.[0].database.current_schema)' "${CP4A_PATTERN_FILE_TMP}"
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`${YQ_CMD} ".spec.baw_configuration.[0].database // \"\"" "$CP4A_PATTERN_FILE_TMP"`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} -i '.spec.baw_configuration[0].database.enable_ssl = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.baw_configuration[0].database.db_cert_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
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
        #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
        # Initialize the isfalse variable to validate dc_ssl_enabled is true or false for AWSDB
        isfalse=false
        for i in "${!AWS_CR_MAPPING[@]}"; do
            if [[ ("${AWS_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${AWS_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} -i ".${AWS_CR_MAPPING[i]} = \"<Remove>\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".${AWS_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_aws_db_servername.${AWS_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                # Check if we are updating spec.datasource_configuration.dc_ssl_enabled value to false
                if [ "${AWS_CR_MAPPING[i]}" == "spec.baw_configuration.[1].database.enable_ssl" ] && [[ "$(prop_db_server_property_file $tmp_aws_db_servername.${AWS_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                    isfalse=true
                fi
                # If SSL is disabled, set the database_ssl_secret_name to ""
                if [ "${AWS_CR_MAPPING[i]}" == "spec.baw_configuration.[1].database.db_cert_secret_name" ] && [ "$isfalse" == "true" ]; then
                    ${YQ_CMD} -i ".spec.baw_configuration[1].database.db_cert_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        done
        # For DBACLD-155445 where we need to use the namespace value passed to find the secret name and populate the CR accordingly
        tmp_secret_name=`${CLI_CMD} get $_secret_type -l db-name=${tmp_aws_db_name} -o yaml -n $CP4BA_SERVICES_NS | ${YQ_CMD} '.items.[0].metadata.name' -`

        # set baw_configuration
        ${YQ_CMD} -i ".spec.baw_configuration.[1].database.secret_name = \"$tmp_secret_name\"" ${CP4A_PATTERN_FILE_TMP}
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_aws_db_name=$(echo "$tmp_aws_db_name" | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} -i '.spec.baw_configuration[1].database.database_name = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i ".spec.baw_configuration.[1].database.database_name = \"$tmp_aws_db_name\"" ${CP4A_PATTERN_FILE_TMP}
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_aws_db_jdbc_url="$(prop_db_server_property_file $tmp_aws_db_servername.ORACLE_JDBC_URL)"
            tmp_aws_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_jdbc_url")
            ${YQ_CMD} -i ".spec.baw_configuration.[1].database.jdbc_url = \"$tmp_aws_db_jdbc_url\"" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.baw_configuration[1].database.jdbc_url = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            ${SED_COMMAND} 's|jdbc_url: "<Remove>"|# jdbc_url: ""|g' ${CP4A_PATTERN_FILE_TMP}
        fi
        ${YQ_CMD} -i '.spec.baw_configuration[1].database.custom_jdbc_pvc = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} 's|custom_jdbc_pvc: "<Remove>"|# custom_jdbc_pvc: ""|g' ${CP4A_PATTERN_FILE_TMP}

        # set current schema name for db2 and postgresql
        if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_aws_db_current_schema_name="$(prop_db_name_user_property_file AWS_DB_CURRENT_SCHEMA)"
            tmp_aws_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_current_schema_name")
            if [[ $tmp_aws_db_current_schema_name != "<Optional>" && $tmp_aws_db_current_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_aws_db_current_schema_name=$(echo "$tmp_aws_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                fi

                ${YQ_CMD} -i ".spec.baw_configuration.[1].database.current_schema = \"$tmp_aws_db_current_schema_name\"" ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} -i '.spec.baw_configuration[1].database.type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i '.spec.baw_configuration[1].database.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
            # always use default schema for EDB Postgres
            ${YQ_CMD} -i 'del(.spec.baw_configuration.[1].database.current_schema)' "${CP4A_PATTERN_FILE_TMP}"
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`${YQ_CMD} ".spec.baw_configuration.[1].database // \"\"" "$CP4A_PATTERN_FILE_TMP"`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} -i '.spec.baw_configuration[1].database.enable_ssl = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.baw_configuration[1].database.db_cert_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
            fi
        fi

        # Applying user profile for BAW runtime
        tmp_baw_runtime_admin="$(prop_user_profile_property_file BAW_RUNTIME.ADMIN_USER)"
        ${YQ_CMD} -i ".spec.baw_configuration.[0].admin_user = \"$tmp_baw_runtime_admin\"" ${CP4A_PATTERN_FILE_TMP}

        # Applying user profile for AWS
        tmp_aws_admin="$(prop_user_profile_property_file AWS.ADMIN_USER)"
        ${YQ_CMD} -i ".spec.baw_configuration.[1].admin_user = \"$tmp_aws_admin\"" ${CP4A_PATTERN_FILE_TMP}
    fi

    # Applying value in Workflow Assistant property file into final CR
    tmp_is_run_workplace_agent_enabled="$(prop_user_profile_property_file WFA.RUN_WORKPLACE_AGENT)"
    tmp_is_run_workplace_agent_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_is_run_workplace_agent_enabled")

    tmp_is_run_authoring_agent_enabled="$(prop_user_profile_property_file WFA.RUN_AUTHORING_AGENT)"
    tmp_is_run_authoring_agent_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_is_run_authoring_agent_enabled")

    if [[ "true" == $tmp_is_run_workplace_agent_enabled || "true" == $tmp_is_run_authoring_agent_enabled ]]; then
        # tmp_watsonx_url="$(prop_user_profile_property_file WFA.WATSONX_URL)"
        # tmp_watsonx_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_watsonx_url")

        tmp_watsonx_username="$(prop_user_profile_property_file WFA.WATSONX_USERNAME)"
        tmp_watsonx_username=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_watsonx_username")

        tmp_watsonx_instance_id="$(prop_user_profile_property_file WFA.WATSONX_INSTANCE_ID)"
        tmp_watsonx_instance_id=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_watsonx_instance_id")

        tmp_watsonx_version="$(prop_user_profile_property_file WFA.WATSONX_VERSION)"
        tmp_watsonx_version=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_watsonx_version")

        tmp_watsonx_model_id="$(prop_user_profile_property_file WFA.WATSONX_MODEL_ID)"
        tmp_watsonx_model_id=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_watsonx_model_id")

        # Read deployment ID parameters based on deployment type
        if [[ "${pattern_cr_arr[@]}" =~ "workflow-authoring" || ("${pattern_cr_arr[@]}" =~ "workflow-process-service" && "${optional_component_cr_arr[@]}" =~ "wfps_authoring") ]]; then
            # For Authoring environment (BAW or WFPS), read both parameters
            tmp_authoring_agent_watsonx_deployment_id="$(prop_user_profile_property_file WFA.AUTHORING_AGENT_WATSONX_DEPLOYMENT_ID)"
            tmp_authoring_agent_watsonx_deployment_id=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_authoring_agent_watsonx_deployment_id")
            
            tmp_runtime_agent_watsonx_deployment_id="$(prop_user_profile_property_file WFA.RUNTIME_AGENT_WATSONX_DEPLOYMENT_ID)"
            tmp_runtime_agent_watsonx_deployment_id=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_runtime_agent_watsonx_deployment_id")
        elif [[ "${pattern_cr_arr[@]}" =~ "workflow-runtime" ]]; then
            # For Runtime environment, read only Runtime parameter
            tmp_runtime_agent_watsonx_deployment_id="$(prop_user_profile_property_file WFA.RUNTIME_AGENT_WATSONX_DEPLOYMENT_ID)"
            tmp_runtime_agent_watsonx_deployment_id=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_runtime_agent_watsonx_deployment_id")
        fi

        # ${YQ_CMD} -i ".spec.workflow_assistant_configuration.watsonx_url = \"$tmp_watsonx_url\"" "${CP4A_PATTERN_FILE_TMP}"
        ${YQ_CMD} -i ".spec.workflow_assistant_configuration.run_workplace_agent = \"$tmp_is_run_workplace_agent_enabled\"" "${CP4A_PATTERN_FILE_TMP}"
        ${YQ_CMD} -i ".spec.workflow_assistant_configuration.run_authoring_agent = \"$tmp_is_run_authoring_agent_enabled\"" "${CP4A_PATTERN_FILE_TMP}"

        if [[ "<Optional>" != $tmp_watsonx_username ]]; then
          ${YQ_CMD} -i ".spec.workflow_assistant_configuration.watsonx_username = \"$tmp_watsonx_username\"" "${CP4A_PATTERN_FILE_TMP}"
        fi

        if [[ "<Optional>" != $tmp_watsonx_instance_id ]]; then
          ${YQ_CMD} -i ".spec.workflow_assistant_configuration.watsonx_instance_id = \"$tmp_watsonx_instance_id\"" "${CP4A_PATTERN_FILE_TMP}"
        fi

        if [[ "<Optional>" != $tmp_watsonx_version ]]; then
          ${YQ_CMD} -i ".spec.workflow_assistant_configuration.watsonx_version = \"$tmp_watsonx_version\"" "${CP4A_PATTERN_FILE_TMP}"
        fi

        if [[ "<Optional>" != $tmp_watsonx_model_id ]]; then
          ${YQ_CMD} -i ".spec.workflow_assistant_configuration.watsonx_model_id = \"$tmp_watsonx_model_id\"" "${CP4A_PATTERN_FILE_TMP}"
        fi

        # Apply deployment ID parameters to CR (variables are already set based on deployment type above)
        # For Authoring environment: both authoring_agent_watsonx_deployment_id and runtime_agent_watsonx_deployment_id will be added to CR
        # For Runtime environment: only runtime_agent_watsonx_deployment_id will be added to CR
        if [[ -n "$tmp_authoring_agent_watsonx_deployment_id" && "<Optional>" != $tmp_authoring_agent_watsonx_deployment_id ]]; then
          ${YQ_CMD} -i ".spec.workflow_assistant_configuration.authoring_agent_watsonx_deployment_id = \"$tmp_authoring_agent_watsonx_deployment_id\"" "${CP4A_PATTERN_FILE_TMP}"
        fi
        
        if [[ -n "$tmp_runtime_agent_watsonx_deployment_id" && "<Optional>" != $tmp_runtime_agent_watsonx_deployment_id ]]; then
          ${YQ_CMD} -i ".spec.workflow_assistant_configuration.runtime_agent_watsonx_deployment_id = \"$tmp_runtime_agent_watsonx_deployment_id\"" "${CP4A_PATTERN_FILE_TMP}"
        fi

        domain_name=$(${CLI_CMD} get IngressController default -n openshift-ingress-operator --no-headers --ignore-not-found -o jsonpath='{.status.domain}')

        # Define common Zen front door host (shared domain for cookie support)
        zen_frontdoor_host="https://cpd-${CP4BA_SERVICES_NS}.${domain_name}"

        if [[ "$tmp_is_run_workplace_agent_enabled" == "true" ]]; then
            xml_data_workplace+=" <server merge=\"mergeChildren\">
                <portal merge=\"mergeChildren\">
                    <agent-enable merge=\"replace\">true</agent-enable>
                    <agent-endpoint merge=\"replace\">${zen_frontdoor_host}/agent/runtimeChat</agent-endpoint>
                </portal>
            </server>
            "
        fi

        if [[ "$tmp_is_run_authoring_agent_enabled" == "true" ]]; then
            xml_data_authoring+=" <authoring-environment>
                <authoring-agent-endpoint merge=\"replace\">${zen_frontdoor_host}/agent</authoring-agent-endpoint>
            </authoring-environment>
            "
        fi

        # if [[ -n "$xml_data_workplace" || -n "$xml_data_authoring" ]]; then
        #     export csp_url="${zen_frontdoor_host}"
        # fi


        # For workflow-authoring and wfps authoring
        if [[ "${pattern_cr_arr[@]}" =~ "workflow-authoring" || "${pattern_cr_arr[@]}" =~ "workflow-process-service" ]]; then

            SECRET_NAME="lombardi-custom-xml-secret"
            # Delete existing secret if exists
            if ${CLI_CMD} get secret "$SECRET_NAME" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1; then
                # Define backup directory and filename
                BACKUP_FILE="${SECRET_NAME}-backup-$(date +%Y%m%d%H%M%S).xml"
                ${CLI_CMD} get secret "$SECRET_NAME" -n "$CP4BA_SERVICES_NS" -o jsonpath='{.data.sensitiveCustomConfig}' | base64 --decode > "${BACKUP_FILE}"
                ${CLI_CMD} delete secret "$SECRET_NAME" -n "$CP4BA_SERVICES_NS"
            fi
            
            if [[ -n "$xml_data_authoring" ]]; then
                export authoring_xml_literal=$'<properties>\n'"$xml_data_authoring"$'\n</properties>\n\n'
                ${YQ_CMD} -i '.spec.bastudio_configuration.bastudio_custom_xml = env(authoring_xml_literal)' "${CP4A_PATTERN_FILE_TMP}"
            fi

            if [[ -n "$xml_data_workplace" ]]; then
                export runtime_xml=$'<properties>\n'"$xml_data_workplace"$'</properties>\n\n'
                # Create new secret
                ${CLI_CMD} create secret generic "$SECRET_NAME" --from-literal=sensitiveCustomConfig="${runtime_xml}" -n "$CP4BA_SERVICES_NS"
                # Update the CR to reference the secret
                ${YQ_CMD} -i '.spec.workflow_authoring_configuration.lombardi_custom_xml_secret_name = "lombardi-custom-xml-secret"' "${CP4A_PATTERN_FILE_TMP}"
            fi

            # if [[ -n "$xml_data_authoring" || -n "$xml_data_workplace" ]]; then
            #     if [[ "${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
            #         ${YQ_CMD} -i '.spec.workflow_authoring_configuration.environment_config.content_security_policy_additional_connect_src[0] = strenv(csp_url)' "${CP4A_PATTERN_FILE_TMP}"
            #         ${YQ_CMD} -i '.spec.workflow_authoring_configuration.environment_config.content_security_policy_additional_script_src[0] = strenv(csp_url)' "${CP4A_PATTERN_FILE_TMP}"
            #     else
            #         ${YQ_CMD} -i '.spec.workflow_authoring_configuration.additional_csp_folders.connect_src[0] = strenv(csp_url)' "${CP4A_PATTERN_FILE_TMP}"
            #         ${YQ_CMD} -i '.spec.workflow_authoring_configuration.additional_csp_folders.script_src[0] = strenv(csp_url)' "${CP4A_PATTERN_FILE_TMP}"
            #     fi
            # fi

        elif [[ "${pattern_cr_arr[@]}" =~ "workflow-runtime" ]]; then
            if [[ -n "$xml_data_workplace" ]]; then
                # Adding CSP Headers
                # ${YQ_CMD} -i '.spec.baw_configuration.[0].environment_config.content_security_policy_additional_connect_src[0] = strenv(csp_url)' "${CP4A_PATTERN_FILE_TMP}"
                # ${YQ_CMD} -i '.spec.baw_configuration.[0].environment_config.content_security_policy_additional_script_src[0] = strenv(csp_url)' "${CP4A_PATTERN_FILE_TMP}"

                SECRET_NAME="lombardi-custom-xml-secret"
                # Check if the secret exists
                if ${CLI_CMD} get secret "$SECRET_NAME" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1; then
                    # Define backup directory and filename
                    BACKUP_FILE="${SECRET_NAME}-backup-$(date +%Y%m%d%H%M%S).xml"
                    ${CLI_CMD} get secret "$SECRET_NAME" -n "$CP4BA_SERVICES_NS" -o jsonpath='{.data.sensitiveCustomConfig}' | base64 --decode > "${BACKUP_FILE}"
                    ${CLI_CMD} delete secret "$SECRET_NAME" -n "$CP4BA_SERVICES_NS"

                fi
                ${CLI_CMD} create secret generic "$SECRET_NAME" --from-literal=sensitiveCustomConfig="${xml_data_workplace}" -n "$CP4BA_SERVICES_NS"

                ${YQ_CMD} -i '.spec.baw_configuration.[0].lombardi_custom_xml_secret_name = "lombardi-custom-xml-secret"' "${CP4A_PATTERN_FILE_TMP}"
            fi
        fi
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
                ${YQ_CMD} -i ".${AWS_ONLY_CR_MAPPING[i]} = \"<Remove>\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".${AWS_ONLY_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_aws_db_servername.${AWS_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
            fi
        done
        # For DBACLD-155445 where we need to use the namespace value passed to find the secret name and populate the CR accordingly
        tmp_secret_name=`${CLI_CMD} get $_secret_type -l db-name=${tmp_aws_db_name} -o yaml -n $CP4BA_SERVICES_NS | ${YQ_CMD} '.items.[0].metadata.name' -`

        # set baw_configuration
        ${YQ_CMD} -i ".spec.baw_configuration.[0].database.secret_name = \"$tmp_secret_name\"" ${CP4A_PATTERN_FILE_TMP}

        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_aws_db_name=$(echo "$tmp_aws_db_name" | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.database_name = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i ".spec.baw_configuration.[0].database.database_name = \"$tmp_aws_db_name\"" ${CP4A_PATTERN_FILE_TMP}
        fi

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_aws_db_jdbc_url="$(prop_db_server_property_file $tmp_aws_db_servername.ORACLE_JDBC_URL)"
            tmp_aws_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_jdbc_url")
            ${YQ_CMD} -i ".spec.baw_configuration.[0].database.jdbc_url = \"$tmp_aws_db_jdbc_url\"" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.jdbc_url = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            ${SED_COMMAND} 's|jdbc_url: "<Remove>"|# jdbc_url: ""|g' ${CP4A_PATTERN_FILE_TMP}
        fi
        ${YQ_CMD} -i '.spec.baw_configuration[0].database.custom_jdbc_pvc = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
        ${SED_COMMAND} 's|custom_jdbc_pvc: "<Remove>"|# custom_jdbc_pvc: ""|g' ${CP4A_PATTERN_FILE_TMP}

        if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            tmp_aws_db_current_schema_name="$(prop_db_name_user_property_file AWS_DB_CURRENT_SCHEMA)"
            tmp_aws_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_aws_db_current_schema_name")
            if [[ $tmp_aws_db_current_schema_name != "<Optional>" && $tmp_aws_db_current_schema_name != ""  ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_aws_db_current_schema_name=$(echo "$tmp_aws_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                fi

                ${YQ_CMD} -i ".spec.baw_configuration.[0].database.current_schema = \"$tmp_aws_db_current_schema_name\"" ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i '.spec.baw_configuration[0].database.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
            # always use default schema for EDB Postgres
            ${YQ_CMD} -i 'del(.spec.baw_configuration.[0].database.current_schema)' "${CP4A_PATTERN_FILE_TMP}"
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`${YQ_CMD} ".spec.baw_configuration.[0].database // \"\"" "$CP4A_PATTERN_FILE_TMP"`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} -i '.spec.baw_configuration[0].database.enable_ssl = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.baw_configuration[0].database.db_cert_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
            fi
        fi

        # Applying user profile for AWS
        tmp_aws_admin="$(prop_user_profile_property_file AWS.ADMIN_USER)"
        ${YQ_CMD} -i ".spec.baw_configuration.[0].admin_user = \"$tmp_aws_admin\"" ${CP4A_PATTERN_FILE_TMP}
    fi

    # Applying values in DICMS property file into final CR
    if [[ "${pattern_cr_arr[@]}" =~ "decisions_ads" ]]; then
        # Applying values for DICMS Designer into final CR
        if [[ "${optional_component_arr[@]}" =~ "DecisionDesigner" ]]; then

            ### -- https://jsw.ibm.com/browse/DBACLD-151937 - <Migration from Mongo to external Postgresql for DICMS>
            # Applying values for external postgresql into final CR
            if [[ $DB_TYPE = "postgresql" ]]; then
                # Getting values from propertyfiles for external postgresql
                tmp_ads_designer_db_servername_prefix="$(prop_db_name_user_property_file_for_server_name DICMS_DESIGNER_DB_USER_NAME)"
                tmp_ads_designer_db_servername_prefix=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_designer_db_servername_prefix")

                tmp_ads_designer_db_port="$(prop_db_server_property_file $tmp_ads_designer_db_servername_prefix.DATABASE_PORT)"
                tmp_ads_designer_db_port=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_designer_db_port")

                tmp_ads_designer_db_servername="$(prop_db_server_property_file $tmp_ads_designer_db_servername_prefix.DATABASE_SERVERNAME)"
                tmp_ads_designer_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_designer_db_servername")

                tmp_ads_designer_db_name="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_NAME)"
                tmp_ads_designer_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_designer_db_name")
                tmp_ads_designer_db_name=$(echo "$tmp_ads_designer_db_name" | tr '[:upper:]' '[:lower:]')

                # Applying values into final CR
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource = null' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.dc_use_postgres = false' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.database_servername = \"$tmp_ads_designer_db_servername\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.database_name = \"$tmp_ads_designer_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.database_port = \"$tmp_ads_designer_db_port\"" ${CP4A_PATTERN_FILE_TMP}
                
                # DBACLD-238059: Set or delete database_instance_secret based on vault configuration
                if [[ "$vault_enabled" == "true" ]]; then
                    ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_ads_designer_datasource.database_instance_secret)' ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_instance_secret = "ibm-ads-designer-database"' ${CP4A_PATTERN_FILE_TMP}
                fi
            
                # Checking if SSL is enable
                tmp_ads_designer_ssl_flag="$(prop_db_server_property_file $tmp_ads_designer_db_servername_prefix.DATABASE_SSL_ENABLE)"
                tmp_ads_designer_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_designer_ssl_flag")
                tmp_ads_designer_ssl_flag=$(echo "$tmp_ads_designer_ssl_flag" | tr '[:upper:]' '[:lower:]')

                if [[ $tmp_ads_designer_ssl_flag == "yes" || $tmp_ads_designer_ssl_flag == "true" || $tmp_ads_designer_ssl_flag == "y" ]]; then
                    # Getting SSL related values from propertyfile
                    tmp_ads_designer_db_ssl_secret="$(prop_db_server_property_file $tmp_ads_designer_db_servername_prefix.DATABASE_SSL_SECRET_NAME)"
                    tmp_ads_designer_db_ssl_secret=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_designer_db_ssl_secret")
                    tmp_ads_designer_db_ssl_secret=$(echo "$tmp_ads_designer_db_ssl_secret" | tr '[:upper:]' '[:lower:]')

                    tmp_ads_designer_db_ssl_mode="$(prop_db_server_property_file $tmp_ads_designer_db_servername_prefix.POSTGRESQL_SSL_MODE)"
                    tmp_ads_designer_db_ssl_mode=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_designer_db_ssl_mode")
                    tmp_ads_designer_db_ssl_mode=$(echo "$tmp_ads_designer_db_ssl_mode" | tr '[:upper:]' '[:lower:]')

                    # Applying SSL related values into final CR
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.ssl_secret_name = \"$tmp_ads_designer_db_ssl_secret\"" ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_enabled = true' ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.ssl_mode = \"$tmp_ads_designer_db_ssl_mode\"" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_secret_name = null' ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_enabled = false' ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_mode = null' ${CP4A_PATTERN_FILE_TMP}
                fi

                # Applying customized schema for DICMS designer into final CR
                tmp_ads_designer_schema_name=$(prop_db_name_user_property_file DICMS_DESIGNER_DB_CURRENT_SCHEMA)
                tmp_ads_designer_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_designer_schema_name")
                # Check if schema name is not empty <https://jsw.ibm.com/browse/DBACLD-168541>
                if [[ -n $tmp_ads_designer_schema_name ]]; then
                    # Convert schema name to lowercase
                    tmp_ads_designer_schema_name=$(echo "$tmp_ads_designer_schema_name" | tr '[:upper:]' '[:lower:]')
                    # Update the schema in the configuration
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.current_schema = \"${tmp_ads_designer_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
                else
                    # Set default schema to "ads" if empty
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.current_schema = "ads"' ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        fi
        
        # Applying values for DICMS Runtime into final CR
        if [[ "${optional_component_arr[@]}" =~ "DecisionRuntime" ]]; then

            ### -- https://jsw.ibm.com/browse/DBACLD-151937 - <Migration from Mongo to external Postgresql for DICMS>
            # Applying values for external postgresql into final CR
            if [[ $DB_TYPE = "postgresql" ]]; then
                # Getting properties from propertyfiles for external postgresql
                tmp_ads_runtime_db_servername_prefix="$(prop_db_name_user_property_file_for_server_name DICMS_RUNTIME_DB_USER_NAME)"
                tmp_ads_runtime_db_servername_prefix=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_runtime_db_servername_prefix")

                tmp_ads_runtime_db_port="$(prop_db_server_property_file $tmp_ads_runtime_db_servername_prefix.DATABASE_PORT)"
                tmp_ads_runtime_db_port=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_runtime_db_port")

                tmp_ads_runtime_db_servername="$(prop_db_server_property_file $tmp_ads_runtime_db_servername_prefix.DATABASE_SERVERNAME)"
                tmp_ads_runtime_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_runtime_db_servername")

                tmp_ads_runtime_db_name="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_NAME)"
                tmp_ads_runtime_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_runtime_db_name")
                tmp_ads_runtime_db_name=$(echo "$tmp_ads_runtime_db_name" | tr '[:upper:]' '[:lower:]')

                # Applying values into final CR
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource = null' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.dc_use_postgres = false' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.database_servername = \"$tmp_ads_runtime_db_servername\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.database_name = \"$tmp_ads_runtime_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.database_port = \"$tmp_ads_runtime_db_port\"" ${CP4A_PATTERN_FILE_TMP}
                
                # DBACLD-238059: Set or delete database_instance_secret based on vault configuration
                if [[ "$vault_enabled" == "true" ]]; then
                    ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_ads_runtime_datasource.database_instance_secret)' ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_instance_secret = "ibm-ads-runtime-database"' ${CP4A_PATTERN_FILE_TMP}
                fi

                # Checking if SSL is enable
                tmp_ads_runtime_ssl_flag="$(prop_db_server_property_file $tmp_ads_runtime_db_servername_prefix.DATABASE_SSL_ENABLE)"
                tmp_ads_runtime_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_runtime_ssl_flag")
                tmp_ads_runtime_ssl_flag=$(echo "$tmp_ads_runtime_ssl_flag" | tr '[:upper:]' '[:lower:]')

                if [[ $tmp_ads_runtime_ssl_flag == "yes" || $tmp_ads_runtime_ssl_flag == "true" || $tmp_ads_runtime_ssl_flag == "y" ]]; then
                    # Getting SSL related values from propertyfile
                    tmp_ads_runtime_db_ssl_secret="$(prop_db_server_property_file $tmp_ads_runtime_db_servername_prefix.DATABASE_SSL_SECRET_NAME)"
                    tmp_ads_runtime_db_ssl_secret=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_runtime_db_ssl_secret")
                    tmp_ads_runtime_db_ssl_secret=$(echo "$tmp_ads_runtime_db_ssl_secret" | tr '[:upper:]' '[:lower:]')

                    tmp_ads_runtime_db_ssl_mode="$(prop_db_server_property_file $tmp_ads_runtime_db_servername_prefix.POSTGRESQL_SSL_MODE)"
                    tmp_ads_runtime_db_ssl_mode=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_runtime_db_ssl_mode")
                    tmp_ads_runtime_db_ssl_mode=$(echo "$tmp_ads_runtime_db_ssl_mode" | tr '[:upper:]' '[:lower:]')

                    # Applying SSL related values into final CR
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.ssl_secret_name = \"$tmp_ads_runtime_db_ssl_secret\"" ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_enabled = true' ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.ssl_mode = \"$tmp_ads_runtime_db_ssl_mode\"" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_secret_name = null' ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_enabled = false' ${CP4A_PATTERN_FILE_TMP}
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_mode = null' ${CP4A_PATTERN_FILE_TMP}
                fi

                # Applying customized schema for DICMS runtime into final CR
                tmp_ads_runtime_schema_name=$(prop_db_name_user_property_file DICMS_RUNTIME_DB_CURRENT_SCHEMA)
                tmp_ads_runtime_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ads_runtime_schema_name")
                # Check if runtime schema name is not empty <https://jsw.ibm.com/browse/DBACLD-168541>
                if [[ -n $tmp_ads_runtime_schema_name ]]; then
                    # Convert runtime schema name to lowercase
                    tmp_ads_runtime_schema_name=$(echo "$tmp_ads_runtime_schema_name" | tr '[:upper:]' '[:lower:]')
                    # Update the runtime schema in the configuration
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.current_schema = \"${tmp_ads_runtime_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
                else
                    # Set default runtime schema to "ads" if empty
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.current_schema = "ads"' ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        fi
    fi

    # Applying value from ADP Gitgateway property file into final CR
    if [[ "${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        # DBACLD-178324: Remove dc_adp_datasouce section when document_processing_designer is not selected
        if ! [[ "${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_adp_datasource)' "${CP4A_PATTERN_FILE_TMP}"
        else
            ### -- https://jsw.ibm.com/browse/DBACLD-151937 - <Migration from Mongo to external Postgresql for ADP>
            # Applying values for external postgresql into final CR
            if [[ $DB_TYPE = "postgresql" ]]; then
                # Getting properties from propertyfiles for external postgresql
                tmp_adp_gg_db_servername_prefix="$(prop_db_name_user_property_file_for_server_name ADP_GG_DB_USER_NAME)"
                tmp_adp_gg_db_servername_prefix=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_gg_db_servername_prefix")

                tmp_adp_gg_db_port="$(prop_db_server_property_file $tmp_adp_gg_db_servername_prefix.DATABASE_PORT)"
                tmp_adp_gg_db_port=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_gg_db_port")

                tmp_adp_gg_db_servername="$(prop_db_server_property_file $tmp_adp_gg_db_servername_prefix.DATABASE_SERVERNAME)"
                tmp_adp_gg_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_gg_db_servername")

                tmp_adp_gg_db_name="$(prop_db_name_user_property_file ADP_GG_DB_NAME)"
                tmp_adp_gg_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_gg_db_name")
                tmp_adp_gg_db_name=$(echo "$tmp_adp_gg_db_name" | tr '[:upper:]' '[:lower:]')

                # Applying values into final CR
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource = null' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.dc_use_postgres = false' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_servername = \"$tmp_adp_gg_db_servername\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_name = \"$tmp_adp_gg_db_name\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_port = \"$tmp_adp_gg_db_port\"" ${CP4A_PATTERN_FILE_TMP}

                # https://jsw.ibm.com/browse/DBACLD-167259 ( Adding the SSL check )
                # Checking if SSL is enable
                tmp_adp_gg_ssl_flag="$(prop_db_server_property_file $tmp_adp_gg_db_servername_prefix.DATABASE_SSL_ENABLE)"
                tmp_adp_gg_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_gg_ssl_flag")
                tmp_adp_gg_ssl_flag=$(echo "$tmp_adp_gg_ssl_flag" | tr '[:upper:]' '[:lower:]')

                    if [[ $tmp_adp_gg_ssl_flag == "yes" || $tmp_adp_gg_ssl_flag == "true" || $tmp_adp_gg_ssl_flag == "y" ]]; then
                        # Getting SSL related values from propertyfile
                        tmp_adp_gg_db_ssl_secret="$(prop_db_server_property_file $tmp_adp_gg_db_servername_prefix.DATABASE_SSL_SECRET_NAME)"
                        tmp_adp_gg_db_ssl_secret=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_gg_db_ssl_secret")
                        tmp_adp_gg_db_ssl_secret=$(echo "$tmp_adp_gg_db_ssl_secret" | tr '[:upper:]' '[:lower:]')

                        # Applying SSL related values into final CR
                        ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_ssl_secret_name = \"$tmp_adp_gg_db_ssl_secret\"" ${CP4A_PATTERN_FILE_TMP}
                    fi
                            
                # Applying customized schema for ADP into final CR
                tmp_adp_gg_schema_name=$(prop_db_name_user_property_file ADP_GG_DB_SCHEMA)
                tmp_adp_gg_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_gg_schema_name")
                if [[ $tmp_adp_gg_schema_name != "<Optional>" && $tmp_adp_gg_schema_name != ""  ]]; then
                    tmp_adp_gg_schema_name=$(echo "$tmp_adp_gg_schema_name" | tr '[:upper:]' '[:lower:]')
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_schema = \"${tmp_adp_gg_schema_name}\"" ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_schema = null' ${CP4A_PATTERN_FILE_TMP}
                fi

                # Applying ADP database secret into final CR
                ${YQ_CMD} -i '.spec.ecm_configuration.document_processing.ibm_adp_secret = "ibm-adp-secret"' ${CP4A_PATTERN_FILE_TMP}

            fi
        fi
    fi

    ### -- https://jsw.ibm.com/browse/DBACLD-153348 - <Migration from Mongo to Postgres-edb for DICMS>
    # Check if the required pattern is present in pattern_cr_arr for decisions_ads
    if [[ "${pattern_cr_arr[@]}" =~ "decisions_ads" ]]; then

        # Set database names for DICMS Designer and DICMS Runtime
        tmp_dbname_designer="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_NAME)"
        tmp_dbname_runtime="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_NAME)"

        # Applying value in DICMS property file into final CR if postgre-edb selected for all cp4ba for ads_designer
        if [[ "${optional_component_arr[@]}" =~ "DecisionDesigner" ]]; then
            if [[ $DB_TYPE == "postgresql-edb" ]]; then
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource = null' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_servername = "postgres-cp4ba-rw.{{ meta.namespace }}.svc"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.database_name = \"$tmp_dbname_designer\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_port = "5432"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.current_schema = "adsdesigner"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_enabled = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_mode = "verify-ca"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
                
                # DBACLD-238059: Set or delete database_instance_secret based on vault configuration
                if [[ "$vault_enabled" == "true" ]]; then
                    ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_ads_designer_datasource.database_instance_secret)' ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_instance_secret = "ibm-ads-designer-database"' ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        fi
        # Applying value in DICMS property file into final CR if postgre-edb selected for all cp4ba for ads_runtime
        if [[ "${optional_component_arr[@]}" =~ "DecisionRuntime" ]]; then
            if [[ $DB_TYPE == "postgresql-edb" ]]; then
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource = null' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_servername = "postgres-cp4ba-rw.{{ meta.namespace }}.svc"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.database_name = \"$tmp_dbname_runtime\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_port = "5432"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.current_schema = "adsruntime"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_enabled = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_mode = "verify-ca"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
                
                # DBACLD-238059: Set or delete database_instance_secret based on vault configuration
                if [[ "$vault_enabled" == "true" ]]; then
                    ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_ads_runtime_datasource.database_instance_secret)' ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_instance_secret = "ibm-ads-runtime-database"' ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        fi
    fi
    ### -- https://jsw.ibm.com/browse/DBACLD-153348 - <Migration from Mongo to Postgres-edb for ADP>
     # Applying value in ADP property file into final CR if postgre-edb selected for all cp4ba for ADP
     #document_processing
    if [[ "${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        # DBACLD-178324: Remove dc_adp_datasouce section when document_processing_designer is not selected
        if ! [[ "${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_adp_datasource)' "${CP4A_PATTERN_FILE_TMP}"
        else
            tmp_dbname="$(prop_db_name_user_property_file ADP_GG_DB_NAME)"

            if [[ $DB_TYPE = "postgresql-edb" ]]; then
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource = null' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_servername = "postgres-cp4ba-rw.{{ meta.namespace }}.svc"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_name = \"$tmp_dbname\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_port = "5432"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_ssl_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
    fi

    ### -- https://jsw.ibm.com/browse/DBACLD-154816 - <Migration from Mongo to Postgres-edb for DICMS>
    # Check if the required pattern is present in pattern_cr_arr for decisions_ads if select db2
    if [[ "${pattern_cr_arr[@]}" =~ "decisions_ads" ]]; then

        # Set database names for DICMS Designer and DICMS Runtime
        tmp_dbname_designer="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_NAME)"
        tmp_dbname_runtime="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_NAME)"

        # Applying value in DICMS property file into final CR if postgre-edb selected for all cp4ba for ads_designer
        if [[ "${optional_component_arr[@]}" =~ "DecisionDesigner" ]]; then
            if [[ $DB_TYPE == "db2" || $DB_TYPE == "oracle" || $DB_TYPE == "sqlserver" ]]; then
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource = null' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_servername = "postgres-cp4ba-rw.{{ meta.namespace }}.svc"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.database_name = \"$tmp_dbname_designer\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_port = "5432"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.current_schema = "adsdesigner"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_enabled = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_mode = "verify-ca"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
                
                # DBACLD-238059: Set or delete database_instance_secret based on vault configuration
                if [[ "$vault_enabled" == "true" ]]; then
                    ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_ads_designer_datasource.database_instance_secret)' ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_instance_secret = "ibm-ads-designer-database"' ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        fi
        # Applying value in DICMS property file into final CR if postgre-edb selected for all cp4ba for ads_runtime
        if [[ "${optional_component_arr[@]}" =~ "DecisionRuntime" ]]; then
            if [[ $DB_TYPE == "db2" || $DB_TYPE == "oracle" || $DB_TYPE == "sqlserver" ]]; then
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource = null' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_servername = "postgres-cp4ba-rw.{{ meta.namespace }}.svc"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.database_name = \"$tmp_dbname_runtime\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_port = "5432"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.current_schema = "adsruntime"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_enabled = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_mode = "verify-ca"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
                
                # DBACLD-238059: Set or delete database_instance_secret based on vault configuration
                if [[ "$vault_enabled" == "true" ]]; then
                    ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_ads_runtime_datasource.database_instance_secret)' ${CP4A_PATTERN_FILE_TMP}
                else
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_instance_secret = "ibm-ads-runtime-database"' ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        fi  
    fi

    ### -- https://jsw.ibm.com/browse/DBACLD-154816 - <Migration from Mongo to Postgres-edb for ADP>
     # Applying value in ADP property file into final CR if select the db2
     #document_processing
    if [[ "${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        # DBACLD-178324: Remove dc_adp_datasouce section when document_processing_designer is not selected
        if ! [[ "${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_adp_datasource)' "${CP4A_PATTERN_FILE_TMP}"
        else
            tmp_dbname="$(prop_db_name_user_property_file ADP_GG_DB_NAME)"

            if [[ $DB_TYPE == "db2" ]]; then
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource = null' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_servername = "postgres-cp4ba-rw.{{ meta.namespace }}.svc"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_name = \"$tmp_dbname\"" ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_port = "5432"' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_ssl_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
    fi

    # Applying value in ACA property file into final CR
    if [[ "${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        tmp_adp_db_servername="$(prop_db_name_user_property_file_for_server_name ADP_BASE_DB_USER_NAME)"
        tmp_adp_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_db_servername")

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_adp_db_name="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
        else
            tmp_adp_db_name="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
        fi
        tmp_adp_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_adp_db_name")

        for i in "${!ADPDB_CR_MAPPING[@]}"; do
            ${YQ_CMD} -i ".${ADPDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_adp_db_servername.${ADPDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
        done
        ${YQ_CMD} -i ".spec.datasource_configuration.dc_ca_datasource.database_name = \"$tmp_adp_db_name\"" ${CP4A_PATTERN_FILE_TMP}

        # set dc_ca_datasource.tenant_databases
        local db_name_array=()
        tmp_dbname=$(prop_db_name_user_property_file ADP_PROJECT_DB_NAME)

        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

        OIFS=$IFS
        IFS=',' read -ra db_name_array <<< "$tmp_dbname"
        IFS=$OIFS
        # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases
        for i in ${!db_name_array[@]}; do
            ${YQ_CMD} -i ".spec.datasource_configuration.dc_ca_datasource.tenant_databases[${i}] = \"${db_name_array[$i]}\"" ${CP4A_PATTERN_FILE_TMP}
        done
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ca_datasource.dc_database_type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ca_datasource.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`${YQ_CMD} ".spec.datasource_configuration.dc_ca_datasource // \"\"" "$CP4A_PATTERN_FILE_TMP"`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ca_datasource.dc_database_ssl_enabled = true' ${CP4A_PATTERN_FILE_TMP}
                # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.dc_ssl_secret_name "{{ meta.name }}-pg-client-cert-secret"
            fi
        fi

        # Recommend to provide an external MongoDB for production deployments.
        tmp_mongo_flag="$(prop_user_profile_property_file ADP.USE_EXTERNAL_MONGODB)"
        tmp_mongo_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_mongo_flag")

        if [[ $tmp_mongo_flag == "Yes" || $tmp_mongo_flag == "YES" || $tmp_mongo_flag == "Y" || $tmp_mongo_flag == "True" || $tmp_mongo_flag == "true" ]]; then
            ${YQ_CMD} -i '.spec.ecm_configuration.document_processing.deploy_mongo = false' ${CP4A_PATTERN_FILE_TMP}
        elif [[ $tmp_mongo_flag == "No" || $tmp_mongo_flag == "NO" || $tmp_mongo_flag == "N" || $tmp_mongo_flag == "False" || $tmp_mongo_flag == "false" ]]; then
            ${YQ_CMD} -i '.spec.ecm_configuration.document_processing.deploy_mongo = true' ${CP4A_PATTERN_FILE_TMP}
        fi

        # Apply git connection secret if true when ADP designer
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            tmp_git_flag="$(prop_user_profile_property_file ADP.ENABLE_GIT_SSL_CONNECTION)"
            tmp_git_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_git_flag")
            if [[ $tmp_git_flag == "Yes" || $tmp_git_flag == "YES" || $tmp_git_flag == "Y" || $tmp_git_flag == "True" || $tmp_git_flag == "true" ]]; then
                tmp_git_secret_name="$(prop_user_profile_property_file ADP.GIT_SSL_SECRET_NAME)"
                ${YQ_CMD} -i ".spec.shared_configuration.trusted_certificate_list += [\"$tmp_git_secret_name\"]" ${CP4A_PATTERN_FILE_TMP}
            fi
        fi

        # Apply REPO_SERVICE_URL and CDRA route certificate and runtime_feedback if ADP runtime
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
            tmp_REPO_SERVICE_URL="$(prop_user_profile_property_file ADP.REPO_SERVICE_URL)"
            ${YQ_CMD} -i ".spec.ecm_configuration.document_processing.cpds.production_setting.repo_service_url = \"$tmp_REPO_SERVICE_URL\"" ${CP4A_PATTERN_FILE_TMP}

            tmp_cdra_secret_name="$(prop_user_profile_property_file ADP.CDRA_SSL_SECRET_NAME)"
            ${YQ_CMD} -i ".spec.shared_configuration.trusted_certificate_list += [\"$tmp_cdra_secret_name\"]" ${CP4A_PATTERN_FILE_TMP}

            tmp_runtime_feedback_enabled="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_ENABLED)"
            ${YQ_CMD} -i ".spec.ca_configuration.global.runtime_feedback.enabled = \"$tmp_runtime_feedback_enabled\"" ${CP4A_PATTERN_FILE_TMP}

            tmp_runtime_feedback_runtime_type="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_RUNTIME_TYPE)"
            ${YQ_CMD} -i ".spec.ca_configuration.global.runtime_feedback.runtime_type = \"$tmp_runtime_feedback_runtime_type\"" ${CP4A_PATTERN_FILE_TMP}

            tmp_runtime_feedback_design_api_secret="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_DESIGN_API_SECRET)"
            ${YQ_CMD} -i ".spec.ca_configuration.global.runtime_feedback.design_api_secret = \"$tmp_runtime_feedback_design_api_secret\"" ${CP4A_PATTERN_FILE_TMP}

            tmp_runtime_feedback_design_tls_secret="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_DESIGN_TLS_SECRET)"
            ${YQ_CMD} -i ".spec.ca_configuration.global.runtime_feedback.design_tls_secret = \"$tmp_runtime_feedback_design_tls_secret\"" ${CP4A_PATTERN_FILE_TMP}
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
        #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
        # Initialize the isfalse variable to validate dc_ssl_enabled is true or false for BASDB
        isfalse=false
        for i in "${!BASDB_CR_MAPPING[@]}"; do
            if [[ ("${BASDB_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${BASDB_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} -i ".${BASDB_CR_MAPPING[i]} = \"<Remove>\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".${BASDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_bas_db_servername.${BASDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                # Check if we are updating spec.datasource_configuration.dc_ssl_enabled value to false
                if [ "${BASDB_CR_MAPPING[i]}" == "spec.bastudio_configuration.database.ssl_enabled" ] && [[ "$(prop_db_server_property_file $tmp_bas_db_servername.${BASDB_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                    isfalse=true
                fi
                # If SSL is disabled, set the database_ssl_secret_name to ""
                if [ "${BASDB_CR_MAPPING[i]}" == "spec.bastudio_configuration.database.certificate_secret_name" ] && [ "$isfalse" == "true" ]; then
                    ${YQ_CMD} -i ".spec.bastudio_configuration.database.certificate_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        done
        # For DBACLD-155445 where we need to use the namespace value passed to find the secret name and populate the CR accordingly
        tmp_secret_name=`${CLI_CMD} get $_secret_type -l db-name=${tmp_bas_db_name} -o yaml -n $CP4BA_SERVICES_NS | ${YQ_CMD} '.items.[0].metadata.name' -`

        # set bastudio_configuration
        ${YQ_CMD} -i ".spec.bastudio_configuration.admin_secret_name = \"$tmp_secret_name\"" ${CP4A_PATTERN_FILE_TMP}
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_bas_db_name=$(echo "$tmp_bas_db_name" | tr '[:upper:]' '[:lower:]')
        fi

        # remove database_name if oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} -i '.spec.bastudio_configuration.database.name = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i ".spec.bastudio_configuration.database.name = \"$tmp_bas_db_name\"" ${CP4A_PATTERN_FILE_TMP}
        fi


        if [[ $DB_TYPE != "oracle" ]]; then
            ${YQ_CMD} -i 'del(.spec.bastudio_configuration.database.oracle_url)' "${CP4A_PATTERN_FILE_TMP}"
        fi

        # Applying user profile for BAS
        tmp_bas_admin="$(prop_user_profile_property_file BASTUDIO.ADMIN_USER)"
        ${YQ_CMD} -i ".spec.bastudio_configuration.admin_user = \"$tmp_bas_admin\"" ${CP4A_PATTERN_FILE_TMP}

        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} -i '.spec.bastudio_configuration.database.type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i '.spec.bastudio_configuration.database.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`${YQ_CMD} ".spec.bastudio_configuration.database // \"\"" "$CP4A_PATTERN_FILE_TMP"`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} -i '.spec.bastudio_configuration.database.ssl_enabled = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.bastudio_configuration.database.certificate_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
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
        
        #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
        # Initialize the isfalse variable to validate dc_ssl_enabled is true or false for Playback
        isfalse=false
        for i in "${!PLAYBACKDB_CR_MAPPING[@]}"; do
            if [[ ("${PLAYBACKDB_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${PLAYBACKDB_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} -i ".${PLAYBACKDB_CR_MAPPING[i]} = \"<Remove>\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".${PLAYBACKDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_app_db_servername.${PLAYBACKDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                # Check if we are updating spec.bastudio_configuration.playback_server.database.enable_ssl to false
                if [ "${PLAYBACKDB_CR_MAPPING[i]}" == "spec.bastudio_configuration.playback_server.database.enable_ssl" ] && [[ "$(prop_db_server_property_file $tmp_app_db_servername.${PLAYBACKDB_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                    isfalse=true
                fi
                # If SSL is disabled, set the db_cert_secret_name to ""
                if [ "${PLAYBACKDB_CR_MAPPING[i]}" == "spec.bastudio_configuration.playback_server.database.db_cert_secret_name" ] && [ "$isfalse" == "true" ]; then
                    ${YQ_CMD} -i ".spec.bastudio_configuration.playback_server.database.db_cert_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        done
        # For DBACLD-155445 where we need to use the namespace value passed to find the secret name and populate the CR accordingly
        tmp_secret_name=`${CLI_CMD} get $_secret_type -l db-name=${tmp_app_db_name} -o yaml -n $CP4BA_SERVICES_NS | ${YQ_CMD} '.items.[0].metadata.name' -`

        # set bastudio_configuration.playback_server
        ${YQ_CMD} -i ".spec.bastudio_configuration.playback_server.admin_secret_name = \"$tmp_secret_name\"" ${CP4A_PATTERN_FILE_TMP}
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_app_db_name=$(echo "$tmp_app_db_name" | tr '[:upper:]' '[:lower:]')
        fi

        # remove database_name if oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} -i '.spec.bastudio_configuration.playback_server.database.name = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i ".spec.bastudio_configuration.playback_server.database.name = \"$tmp_app_db_name\"" ${CP4A_PATTERN_FILE_TMP}
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            ${YQ_CMD} -i 'del(.spec.bastudio_configuration.playback_server.database.oracle_url_without_wallet_directory)' "${CP4A_PATTERN_FILE_TMP}"
            ${YQ_CMD} -i 'del(.spec.bastudio_configuration.playback_server.database.oracle_url_with_wallet_directory)' "${CP4A_PATTERN_FILE_TMP}"
            ${YQ_CMD} -i 'del(.spec.bastudio_configuration.playback_server.database.oracle_sso_wallet_secret_name)' "${CP4A_PATTERN_FILE_TMP}"
        fi
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} -i '.spec.bastudio_configuration.playback_server.database.type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i '.spec.bastudio_configuration.playback_server.database.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`${YQ_CMD} ".spec.bastudio_configuration.playback_server.database // \"\"" "$CP4A_PATTERN_FILE_TMP"`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} -i '.spec.bastudio_configuration.playback_server.database.enable_ssl = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.bastudio_configuration.playback_server.database.db_cert_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
        # Applying user profile for Playback
        tmp_playback_admin="$(prop_user_profile_property_file APP_PLAYBACK.ADMIN_USER)"
        ${YQ_CMD} -i ".spec.bastudio_configuration.playback_server.admin_user = \"$tmp_playback_admin\"" ${CP4A_PATTERN_FILE_TMP}

        # Applying user profile for AE HA Redis session
        tmp_session_flag="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_USE_EXTERNAL_STORE)"
        tmp_session_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_session_flag")
        if [[ $tmp_session_flag == "Yes" || $tmp_session_flag == "YES" || $tmp_session_flag == "Y" || $tmp_session_flag == "True" || $tmp_session_flag == "true" ]]; then
            ${YQ_CMD} -i '.spec.bastudio_configuration.playback_server.session.use_external_store = true' ${CP4A_PATTERN_FILE_TMP}

            tmp_redis_host="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_HOST)"
            tmp_redis_port="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_PORT)"
            tmp_redis_ssl_secret_name="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_SSL_SECRET_NAME)"
            tmp_redis_tls_enabled="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_TLS_ENABLED)"
            tmp_redis_tls_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_tls_enabled")
            tmp_redis_username="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_USERNAME)"

            ${YQ_CMD} -i ".spec.bastudio_configuration.playback_server.redis.host = \"$tmp_redis_host\"" ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i ".spec.bastudio_configuration.playback_server.redis.port = \"$tmp_redis_port\"" ${CP4A_PATTERN_FILE_TMP}
            if [[ $tmp_redis_tls_enabled == "Yes" || $tmp_redis_tls_enabled == "YES" || $tmp_redis_tls_enabled == "Y" || $tmp_redis_tls_enabled == "True" || $tmp_redis_tls_enabled == "true" ]]; then
                ${YQ_CMD} -i '.spec.bastudio_configuration.playback_server.redis.tls_enabled = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.bastudio_configuration.playback_server.tls.tls_trust_list.[0] = \"$tmp_redis_ssl_secret_name\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i '.spec.bastudio_configuration.playback_server.redis.tls_enabled = false' ${CP4A_PATTERN_FILE_TMP}
            fi
            ${YQ_CMD} -i ".spec.bastudio_configuration.playback_server.redis.username = \"$tmp_redis_username\"" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.bastudio_configuration.playback_server.session.use_external_store = false' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i 'del(.spec.bastudio_configuration.playback_server.redis)' "${CP4A_PATTERN_FILE_TMP}"
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
        
        #https://jsw.ibm.com/browse/DBACLD-158651 << Make ssl_secret_name empty when dc_ssl_enabled value is False>>
        # Initialize the isfalse variable to validate dc_ssl_enabled is true or false for AAE
        isfalse=false
        for i in "${!AEDB_CR_MAPPING[@]}"; do
            if [[ ("${AEDB_COMMON_PROPERTY[i]}" == "DATABASE_SERVERNAME"  || "${AEDB_COMMON_PROPERTY[i]}" == "DATABASE_PORT") && $DB_TYPE == "oracle" ]]; then
                ${YQ_CMD} -i ".${AEDB_CR_MAPPING[i]} = \"<Remove>\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i ".${AEDB_CR_MAPPING[i]} = \"$(prop_db_server_property_file $tmp_ae_db_servername.${AEDB_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                # Check if we are updating spec.datasource_configuration.dc_ssl_enabled value to false
                if [ "${AEDB_CR_MAPPING[i]}" == "spec.application_engine_configuration.[0].database.enable_ssl" ] && [[ "$(prop_db_server_property_file $tmp_ae_db_servername.${AEDB_COMMON_PROPERTY[i]})" =~ ^[fF]alse$ ]]; then
                    isfalse=true
                fi
                # If SSL is disabled, set the database_ssl_secret_name to ""
                if [ "${AEDB_CR_MAPPING[i]}" == "spec.application_engine_configuration.[0].database.db_cert_secret_name" ] && [ "$isfalse" == "true" ]; then
                    ${YQ_CMD} -i ".spec.application_engine_configuration[0].database.db_cert_secret_name = \"\"" ${CP4A_PATTERN_FILE_TMP}
                fi
            fi
        done
        # For DBACLD-155445 where we need to use the namespace value passed to find the secret name and populate the CR accordingly
        tmp_secret_name=`${CLI_CMD} get $_secret_type -l db-name=${tmp_ae_db_name} -o yaml -n $CP4BA_SERVICES_NS | ${YQ_CMD} '.items.[0].metadata.name' -`

        # set application_engine_configuration
        ${YQ_CMD} -i ".spec.application_engine_configuration.[0].admin_secret_name = \"$tmp_secret_name\"" ${CP4A_PATTERN_FILE_TMP}
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_ae_db_name=$(echo "$tmp_ae_db_name" | tr '[:upper:]' '[:lower:]')
        fi
        # remove database_name if oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} -i '.spec.application_engine_configuration[0].database.name = "<Remove>"' ${CP4A_PATTERN_FILE_TMP}
            # ${SED_COMMAND} "s|database_name: '\"<Remove>\"'|# database_name: '\"\"'|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i ".spec.application_engine_configuration.[0].database.name = \"$tmp_ae_db_name\"" ${CP4A_PATTERN_FILE_TMP}
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            ${YQ_CMD} -i 'del(.spec.application_engine_configuration.[0].database.oracle_url_without_wallet_directory)' "${CP4A_PATTERN_FILE_TMP}"
            ${YQ_CMD} -i 'del(.spec.application_engine_configuration.[0].database.oracle_url_with_wallet_directory)' "${CP4A_PATTERN_FILE_TMP}"
            ${YQ_CMD} -i 'del(.spec.application_engine_configuration.[0].database.oracle_sso_wallet_secret_name)' "${CP4A_PATTERN_FILE_TMP}"
        fi

        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${YQ_CMD} -i '.spec.application_engine_configuration[0].database.type = "postgresql"' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i '.spec.application_engine_configuration[0].database.dc_use_postgres = true' ${CP4A_PATTERN_FILE_TMP}
            # set dc_ssl_enabled always true for postgresql-edb
            ds_cfg_val=`${YQ_CMD} ".spec.application_engine_configuration.[0].database // \"\"" "$CP4A_PATTERN_FILE_TMP"`
            if [[ ! -z "$ds_cfg_val" ]]; then
                ${YQ_CMD} -i '.spec.application_engine_configuration[0].database.enable_ssl = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i '.spec.application_engine_configuration[0].database.db_cert_secret_name = "{{ meta.name }}-pg-client-cert-secret"' ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
        # Applying user profile for AE
        tmp_ae_admin="$(prop_user_profile_property_file APP_ENGINE.ADMIN_USER)"
        ${YQ_CMD} -i ".spec.application_engine_configuration.[0].admin_user = \"$tmp_ae_admin\"" ${CP4A_PATTERN_FILE_TMP}

        # Applying user profile for AE HA Redis session
        tmp_session_flag="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_USE_EXTERNAL_STORE)"
        tmp_session_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_session_flag")
        if [[ $tmp_session_flag == "Yes" || $tmp_session_flag == "YES" || $tmp_session_flag == "Y" || $tmp_session_flag == "True" || $tmp_session_flag == "true" ]]; then
            ${YQ_CMD} -i '.spec.application_engine_configuration[0].session.use_external_store = true' ${CP4A_PATTERN_FILE_TMP}

            tmp_redis_host="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_HOST)"
            tmp_redis_port="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_PORT)"
            tmp_redis_ssl_secret_name="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_SSL_SECRET_NAME)"
            tmp_redis_tls_enabled="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_TLS_ENABLED)"
            tmp_redis_tls_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_tls_enabled")
            tmp_redis_username="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_USERNAME)"

            ${YQ_CMD} -i ".spec.application_engine_configuration.[0].redis.host = \"$tmp_redis_host\"" ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i ".spec.application_engine_configuration.[0].redis.port = \"$tmp_redis_port\"" ${CP4A_PATTERN_FILE_TMP}
            if [[ $tmp_redis_tls_enabled == "Yes" || $tmp_redis_tls_enabled == "YES" || $tmp_redis_tls_enabled == "Y" || $tmp_redis_tls_enabled == "True" || $tmp_redis_tls_enabled == "true" ]]; then
                ${YQ_CMD} -i '.spec.application_engine_configuration[0].redis.tls_enabled = true' ${CP4A_PATTERN_FILE_TMP}
                ${YQ_CMD} -i ".spec.application_engine_configuration.[0].tls.tls_trust_list.[0] = \"$tmp_redis_ssl_secret_name\"" ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i '.spec.application_engine_configuration[0].redis.tls_enabled = false' ${CP4A_PATTERN_FILE_TMP}
            fi
            ${YQ_CMD} -i ".spec.application_engine_configuration.[0].redis.username = \"$tmp_redis_username\"" ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.application_engine_configuration[0].session.use_external_store = false' ${CP4A_PATTERN_FILE_TMP}
            ${YQ_CMD} -i 'del(.spec.application_engine_configuration.[0].redis)' "${CP4A_PATTERN_FILE_TMP}"
        fi
    fi

    # set dc_ssl_enabled always true for postgresql-edb
    if [[ $DB_TYPE == "postgresql-edb" ]]; then

        ds_cfg_val=`${YQ_CMD} ".spec.datasource_configuration // \"\"" "$CP4A_PATTERN_FILE_TMP"`
        if [[ ! -z "$ds_cfg_val" ]]; then
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ssl_enabled = true' ${CP4A_PATTERN_FILE_TMP}
        fi
    fi


    # Only process the LDAP configuration if LDAP_WFPS_AUTHORING is not "no"
    if [[ "$LDAP_WFPS_AUTHORING" != "no" ]]; then
        # Applying value in LDAP property file into final CR
        for i in "${!LDAP_COMMON_CR_MAPPING[@]}"; do
            
            ${YQ_CMD} -i ".${LDAP_COMMON_CR_MAPPING[i]} = \"$(prop_ldap_property_file ${LDAP_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
            
        done

        if [[ $LDAP_TYPE == "AD" ]]; then
            for i in "${!AD_LDAP_CR_MAPPING[@]}"; do
                
                ${YQ_CMD} -i ".${AD_LDAP_CR_MAPPING[i]} = \"$(prop_ldap_property_file ${AD_LDAP_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
            
            done
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            for i in "${!TDS_LDAP_CR_MAPPING[@]}"; do
                
                ${YQ_CMD} -i ".${TDS_LDAP_CR_MAPPING[i]} = \"$(prop_ldap_property_file ${TDS_LDAP_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
            done

        elif [[ $LDAP_TYPE == "PDS" ]]; then
            for i in "${!PDS_LDAP_CR_MAPPING[@]}"; do
    
                ${YQ_CMD} -i ".${PDS_LDAP_CR_MAPPING[i]} = \"$(prop_ldap_property_file ${PDS_LDAP_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
                
            done
        fi
    

        # set lc_bind_secret
        # For DBACLD-155445 where we need to use the namespace value passed to find the secret name and populate the CR accordingly
        #DBACLD-193130: Update logic to account for vault
        tmp_secret_name=$(${CLI_CMD} get $_secret_type -l name=ldap-bind-secret -o jsonpath='{.items[0].metadata.name}' -n $CP4BA_SERVICES_NS 2>/dev/null)
        if [[ -z "$tmp_secret_name" || "$tmp_secret_name" == "null" ]]; then
            tmp_secret_name="ldap-bind-secret"
            warning "Cannot find the ldap-bind-secret in the namespace $CP4BA_SERVICES_NS. Using default secret name 'ldap-bind-secret' in the CR."
        fi
        ${YQ_CMD} -i ".spec.ldap_configuration.lc_bind_secret = \"$tmp_secret_name\"" ${CP4A_PATTERN_FILE_TMP}
    
    else
        ${YQ_CMD} -i 'del(.spec.ldap_configuration)' "${CP4A_PATTERN_FILE_TMP}"
    fi

    # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_ldap_bind_dn
    # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_ldap_bind_dn_pwd
    # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_ldap_ssl_secret_folder


    # Applying value in External LDAP property file into final CR
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        for i in "${!LDAP_COMMON_CR_MAPPING[@]}"; do
            ${YQ_CMD} -i ".${EXT_LDAP_COMMON_CR_MAPPING[i]} = \"$(prop_ext_ldap_property_file ${LDAP_COMMON_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
        done

        tmp_ldap_type="$(prop_ext_ldap_property_file LDAP_TYPE)"
        tmp_ldap_type=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_type")
        if [[ $tmp_ldap_type == "Microsoft Active Directory" ]]; then
            for i in "${!AD_LDAP_CR_MAPPING[@]}"; do
                ${YQ_CMD} -i ".${EXT_AD_LDAP_CR_MAPPING[i]} = \"$(prop_ext_ldap_property_file ${AD_LDAP_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
            done
        elif [[ $tmp_ldap_type == "IBM Security Directory Server" ]]; then
            for i in "${!TDS_LDAP_CR_MAPPING[@]}"; do
                ${YQ_CMD} -i ".${EXT_TDS_LDAP_CR_MAPPING[i]} = \"$(prop_ext_ldap_property_file ${TDS_LDAP_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
            done
        elif [[ $tmp_ldap_type == "PingDirectory Server" ]]; then
            for i in "${!PDS_LDAP_CR_MAPPING[@]}"; do
                ${YQ_CMD} -i ".${EXT_PDS_LDAP_CR_MAPPING[i]} = \"$(prop_ext_ldap_property_file ${PDS_LDAP_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
            done
        else
            fail "The value for \"LDAP_TYPE\" in the property file \"${EXTERNAL_LDAP_PROPERTY_FILE}\" is not valid. The possible values are: \"IBM Security Directory Server\" or \"Microsoft Active Directory\" or \"PingDirectory Server\""
            exit 1
        fi

        # set lc_bind_secret
        # For DBACLD-155445 where we need to use the namespace value passed to find the secret name and populate the CR accordingly
        tmp_secret_name=`${CLI_CMD} get secret -l name=ext-ldap-bind-secret -o yaml -n $CP4BA_SERVICES_NS | ${YQ_CMD} '.items.[0].metadata.name' -`
        ${YQ_CMD} -i ".spec.ext_ldap_configuration.lc_bind_secret = \"$tmp_secret_name\"" ${CP4A_PATTERN_FILE_TMP}
        # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ext_ldap_configuration.lc_ldap_bind_dn
        # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ext_ldap_configuration.lc_ldap_bind_dn_pwd
        # ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.ext_ldap_configuration.lc_ldap_ssl_secret_folder
    fi

    # IF ODM is selected then we need to add the CR section that will reference the odm keystore password secret
    # DBACLD-238578: Add passwordSecretRef for ODM keystore password secret for 26.0.0-GA
    if [[ "${CP4BA_RELEASE_BASE}-${CP4BA_PATCH_VERSION}" == "26.0.0-GA" ]]; then
        if [[ "${pattern_cr_arr[@]}" =~ "decisions" ]]; then
            ${YQ_CMD} -i ".spec.odm_configuration.dba.passwordSecretRef = \"ibm-odm-keystore-secret\"" ${CP4A_PATTERN_FILE_TMP}
        fi
    fi

    # Applying value in scim property file into final CR
    set_scim_attr="true"
    if [[ "${set_scim_attr}" == "true" ]]; then
        # DBACLD-181399 scim_configuration_iam section should not be present in the generated CR when deploying WFPS authoring only without LDAP (for 25.0.0 maintenance and 25.0.1)
      if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" || (" ${pattern_cr_arr[@]}" =~ "workflow-process-service" && "${optional_component_cr_arr[@]}" =~ "wfps_authoring" && $LDAP_WFPS_AUTHORING == "yes") ]]; then
          for i in "${!SCIM_PROPERTY[@]}"; do
              ${YQ_CMD} -i ".${SCIM_CR_MAPPING[i]} = \"$(prop_user_profile_property_file ${SCIM_PROPERTY[$i]})\"" ${CP4A_PATTERN_FILE_TMP}
          done
      fi
    fi
    ${YQ_CMD} -i 'del(.null)' "${CP4A_PATTERN_FILE_TMP}"
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
    # "Applied value in property file into final CR under $FINAL_CR_FOLDER"
    success "The CP4BA Custom Resource file has been generated and can be found under $FINAL_CR_FOLDER"
}

# Begin - Modify FOUNDATION pattern yaml according patterns/components selected
function apply_pattern_cr(){
    # printf '%b\n' "\x1B[1mCreating a custom resource YAML file for IBM CP4A Operator ......\x1B[0m"
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

    # read -rsn1 -p"Press Enter/Return to continue (DEBUG MODEL)";echo

    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}
    # DBACLD-185209: Check for Vault enable flag
    vault_enabled="$(prop_user_profile_property_file CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION 2>/dev/null || echo 'false')"
    vault_enabled=$(echo "$vault_enabled" | tr '[:upper:]' '[:lower:]')
    vault_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$vault_enabled")
    # remove merge issue
    ${YQ_CMD} -i 'del(.metadata.labels.app.*)' "${CP4A_PATTERN_FILE_TMP}"

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
        if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" ]]; then
            pattern_joined="$pattern_joined$delim$item"
            delim=","
        elif [[ "$DEPLOYMENT_TYPE" == "production" ]]
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

    if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" ]]; then
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

    if [[ "$(echo "$DEPLOYMENT_TYPE" | tr '[:upper:]' '[:lower:]')" == "starter" ]]; then
        if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
            OPT_COMPONENTS_CR_SELECTED=(${OPT_COMPONENTS_CR_SELECTED[@]:0:$tmp_idx} ${OPT_COMPONENTS_CR_SELECTED[@]:$(($tmp_idx + 1))})
        elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams" && " ${PATTERNS_CR_SELECTED[@]} " =~ "application" && "${#PATTERNS_CR_SELECTED[@]}" -eq "2" ]]; then
            OPT_COMPONENTS_CR_SELECTED=(${OPT_COMPONENTS_CR_SELECTED[@]:0:$tmp_idx} ${OPT_COMPONENTS_CR_SELECTED[@]:$(($tmp_idx + 1))})
        fi
    fi

    # Auto-add opensearch when workflow_runtime_mcp_server is selected
    containsElement "workflow_runtime_mcp_server" "${OPT_COMPONENTS_CR_SELECTED[@]}"
    if [[ $? -eq 0 ]]; then
        containsElement "opensearch" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        if [[ $? -ne 0 ]]; then
            OPT_COMPONENTS_CR_SELECTED=( "${OPT_COMPONENTS_CR_SELECTED[@]}" "opensearch" )
        fi
        
        # Auto-add pfs when workflow_runtime_mcp_server is selected for workflow authoring (baw_authoring only, not wfps_authoring)
        if [[ " ${OPT_COMPONENTS_CR_SELECTED[@]} " =~ "baw_authoring" ]]; then
            containsElement "pfs" "${OPT_COMPONENTS_CR_SELECTED[@]}"
            if [[ $? -ne 0 ]]; then
                OPT_COMPONENTS_CR_SELECTED=( "${OPT_COMPONENTS_CR_SELECTED[@]}" "pfs" )
                info "Auto-adding 'pfs' (Process Federation Server) to optional components because 'workflow_runtime_mcp_server' is selected for workflow authoring pattern."
            fi
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
    # ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_BAK} ${CP4A_PATTERN_FILE_TMP}

    # Add connectivity_pack_configuration directly under spec when Application Connectors is selected
    if [[ " ${OPT_COMPONENTS_CR_SELECTED[@]} " =~ "application_connectors" ]]; then
        ${YQ_CMD} -i '.spec.connectivity_pack_configuration.enable = true' ${CP4A_PATTERN_FILE_TMP}
    fi

    # Set full_text_search.enable to true in baw_configuration when workflow_runtime_mcp_server is selected for runtime patterns
    if [[ " ${OPT_COMPONENTS_CR_SELECTED[@]} " =~ "workflow_runtime_mcp_server" ]]; then
        if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-runtime" ]] || [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow" ]]; then
            # Check if baw_configuration exists and set full_text_search.enable to true
            baw_cfg_exists=$(${YQ_CMD} '.spec.baw_configuration // ""' ${CP4A_PATTERN_FILE_TMP})
            if [[ ! -z "$baw_cfg_exists" ]]; then
                ${YQ_CMD} -i '.spec.baw_configuration[0].full_text_search.enable = true' ${CP4A_PATTERN_FILE_TMP}
                info "Auto-setting 'full_text_search.enable' to true in baw_configuration because 'workflow_runtime_mcp_server' is selected for workflow runtime pattern."
            fi
        fi
    fi

    if [[ " ${OPT_COMPONENTS_CR_SELECTED[@]} " =~ "ae_data_persistence" ]]; then
        ${YQ_CMD} -i '.spec.shared_configuration.sc_content_initialization = true' ${CP4A_PATTERN_FILE_TMP}
    elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow" || " ${PATTERNS_CR_SELECTED[@]} " =~ "workstreams" ]]; then
        ${YQ_CMD} -i '.spec.shared_configuration.sc_content_initialization = true' ${CP4A_PATTERN_FILE_TMP}
    fi

    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing" ]]; then
        if [[ "$CPE_FULL_STORAGE" == "Yes" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_cpe_limited_storage = false' ${CP4A_PATTERN_FILE_TMP}
        elif [[ "$CPE_FULL_STORAGE" == "No" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_cpe_limited_storage = true' ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.shared_configuration.sc_cpe_limited_storage = false' ${CP4A_PATTERN_FILE_TMP}
        fi
    fi

    # If only select Content Cortex pattern, only generate "kind: Content" cr
    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
        for item in "${OPT_COMPONENTS_CR_SELECTED[@]}"; do
            while true; do
                case $item in
                    "bai")
                        ${YQ_CMD} -i '.spec.content_optional_components.bai = true' ${CP4A_PATTERN_FILE_TMP}
                        break
                        ;;
                    "cmis")
                        ${YQ_CMD} -i '.spec.content_optional_components.cmis = true' ${CP4A_PATTERN_FILE_TMP}
                        break
                        ;;
                    "css")
                        ${YQ_CMD} -i '.spec.content_optional_components.css = true' ${CP4A_PATTERN_FILE_TMP}
                        break
                        ;;
                    "es")
                        # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.content_optional_components.es "true"
                        break
                        ;;
                    "iccsap")
                        ${YQ_CMD} -i '.spec.content_optional_components.iccsap = true' ${CP4A_PATTERN_FILE_TMP}
                        break
                        ;;
                    "ier")
                        ${YQ_CMD} -i '.spec.content_optional_components.ier = true' ${CP4A_PATTERN_FILE_TMP}
                        break
                        ;;
                    "tm")
                        ${YQ_CMD} -i '.spec.content_optional_components.tm = true' ${CP4A_PATTERN_FILE_TMP}
                        break
                        ;;
                    "ccxmo")
                        ${YQ_CMD} -i '.spec.content_optional_components.ccxmo = true' ${CP4A_PATTERN_FILE_TMP}
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
        ${YQ_CMD} -i ".spec.shared_configuration.sc_deployment_hostname_suffix = \"$existing_infra_name\"" ${CP4A_PATTERN_FILE_TMP}
        if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]];
        then
            ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}.${INFRA_NAME}\"|g" ${CP4A_PATTERN_FILE_TMP}
        else
            ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}\"|g" ${CP4A_PATTERN_FILE_TMP}
        fi
    fi


    # Set lc_selected_ldap_type

    if [[ "$DEPLOYMENT_TYPE" == "production" ]];then
        if [[ $LDAP_TYPE == "AD" ]];then
            # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_selected_ldap_type "\"Microsoft Active Directory\""
            ${SED_COMMAND} "s|lc_selected_ldap_type:.*|lc_selected_ldap_type: \"Microsoft Active Directory\"|g" ${CP4A_PATTERN_FILE_TMP}

        elif [[ $LDAP_TYPE == "TDS" ]]
        then
            # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_selected_ldap_type "IBM Security Directory Server"
            ${SED_COMMAND} "s|lc_selected_ldap_type:.*|lc_selected_ldap_type: \"IBM Security Directory Server\"|g" ${CP4A_PATTERN_FILE_TMP}
        elif [[ $LDAP_TYPE == "PDS" ]]
        then
            # ${YQ_CMD} w -i ${CP4A_PATTERN_FILE_TMP} spec.ldap_configuration.lc_selected_ldap_type "PingDirectory Server"
            ${SED_COMMAND} "s|lc_selected_ldap_type:.*|lc_selected_ldap_type: \"PingDirectory Server\"|g" ${CP4A_PATTERN_FILE_TMP}
        fi
    fi

    # Set fips_enable
    if  [[ ("$DEPLOYMENT_TYPE" == "starter" ) && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
        if [[ $FIPS_ENABLED == "true" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.enable_fips = true' ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.shared_configuration.enable_fips = false' ${CP4A_PATTERN_FILE_TMP}
        fi
        if [[ $GENERATE_SAMPLE_NETWORK_POLICIES == "true" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_generate_sample_network_policies = true' ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.shared_configuration.sc_generate_sample_network_policies = false' ${CP4A_PATTERN_FILE_TMP}
        fi
        if [[ $ENABLE_INSTANA_MONITORING == "true" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_enable_instana_metric_collection = true' ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.shared_configuration.sc_enable_instana_metric_collection = false' ${CP4A_PATTERN_FILE_TMP}
        fi
        #DBACLD-185209: Vault's implementation
        if [[ "$vault_enabled" == 'true' && "$DEPLOYMENT_TYPE" == "production" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_vault_configuration.enable_external_secret_store = true' ${CP4A_PATTERN_FILE_TMP}
            configure_vault_shared_secrets
        else
            ${YQ_CMD} -i '.spec.shared_configuration.sc_vault_configuration.enable_external_secret_store = false' ${CP4A_PATTERN_FILE_TMP}
        fi
    elif [[ $DEPLOYMENT_TYPE == "production" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
        fips_flag="$(prop_user_profile_property_file CP4BA.ENABLE_FIPS)"
        fips_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$fips_flag")
        fips_flag=$(echo "$fips_flag" | tr '[:upper:]' '[:lower:]')
        if [[ ! -z $fips_flag ]]; then
            if [[ $fips_flag == "true" ]]; then
                ${YQ_CMD} -i '.spec.shared_configuration.enable_fips = true' ${CP4A_PATTERN_FILE_TMP}
            else
                ${YQ_CMD} -i '.spec.shared_configuration.enable_fips = false' ${CP4A_PATTERN_FILE_TMP}
            fi
        fi
    fi

    # Set sc_generate_sample_network_policies
    if  [[ ("$DEPLOYMENT_TYPE" == "starter") && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
        if [[ $GENERATE_SAMPLE_NETWORK_POLICIES == "true" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_generate_sample_network_policies = true' ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.shared_configuration.sc_generate_sample_network_policies = false' ${CP4A_PATTERN_FILE_TMP}
        fi
    elif [[ $DEPLOYMENT_TYPE == "production" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS") ]]; then
        if [[ $GENERATE_SAMPLE_NETWORK_POLICIES == "true" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_generate_sample_network_policies = true' ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.shared_configuration.sc_generate_sample_network_policies = false' ${CP4A_PATTERN_FILE_TMP}
        fi
        if [[ $ENABLE_INSTANA_MONITORING == "true" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_enable_instana_metric_collection = true' ${CP4A_PATTERN_FILE_TMP}
        else
            ${YQ_CMD} -i '.spec.shared_configuration.sc_enable_instana_metric_collection = false' ${CP4A_PATTERN_FILE_TMP}
        fi
        #DBACLD-185209: Vault's implementation
        if [[ "$vault_enabled" == 'true' && "$DEPLOYMENT_TYPE" == "production" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_vault_configuration.enable_external_secret_store = true' ${CP4A_PATTERN_FILE_TMP}
            configure_vault_shared_secrets
        else
            ${YQ_CMD} -i '.spec.shared_configuration.sc_vault_configuration.enable_external_secret_store = false' ${CP4A_PATTERN_FILE_TMP}
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
    ${YQ_CMD} -i 'del(.spec.shared_configuration.image_pull_secrets)' "${CP4A_PATTERN_FILE_TMP}"
    ${YQ_CMD} -i ".spec.shared_configuration.image_pull_secrets[0] = \"$DOCKER_RES_SECRET_NAME\"" ${CP4A_PATTERN_FILE_TMP}

    # set sc_drivers_url - custom drivers automatically take precedence over OOTB drivers
    if [[ -z "$CP4BA_JDBC_URL" || "$CP4BA_JDBC_URL" == "null" ]]; then
        ${YQ_CMD} -i '.spec.shared_configuration.sc_drivers_url = ""' ${CP4A_PATTERN_FILE_TMP}
    else
        ${YQ_CMD} -i ".spec.shared_configuration.sc_drivers_url = \"$CP4BA_JDBC_URL\"" ${CP4A_PATTERN_FILE_TMP}
    fi

    # support profile size for production
    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
        ${YQ_CMD} -i ".spec.shared_configuration.sc_deployment_profile_size = \"$PROFILE_TYPE\"" ${CP4A_PATTERN_FILE_TMP}
    fi

    # set the sc_iam.default_admin_username
    if [[ ("$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS") && "$DEPLOYMENT_TYPE" == "production" && "$USE_DEFAULT_IAM_ADMIN" == "No" ]]; then
        ${YQ_CMD} -i ".spec.shared_configuration.sc_iam.default_admin_username = \"$NON_DEFAULT_IAM_ADMIN\"" ${CP4A_PATTERN_FILE_TMP}
    fi

    # set sc_image_repository
    if [ "$use_entitlement" = "yes" ] ; then
        ${SED_COMMAND} "s|sc_image_repository:.*|sc_image_repository: ${DOCKER_REG_SERVER}|g" ${CP4A_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s|sc_image_repository:.*|sc_image_repository: ${CONVERT_LOCAL_REGISTRY_SERVER}|g" ${CP4A_PATTERN_FILE_TMP}
    fi

    # If the script is being used for updating deployment patterns or components we keep what has already been set in the original CR
    # The variable current_image_repository_chosen is set in the update-selected-components file
    if [[ $UPDATE_COMPONENTS == "true" ]]; then
        ${SED_COMMAND} "s|sc_image_repository:.*|sc_image_repository: ${current_image_repository_chosen}|g" ${CP4A_PATTERN_FILE_TMP}
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
                ${YQ_CMD} -i "del(.spec.datasource_configuration.dc_os_datasources[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
            done
        fi
        containsInitObjectStore "$object_name" "${CP4A_PATTERN_FILE_TMP}"
        if (( ${#os_index_array[@]} > 1 ));then
            ((index_array_temp=${#os_index_array[@]}-1))
            for ((j=0;j<${index_array_temp};j++))
            do
                ((index_os=${os_index_array[$j]}-j))
                ${YQ_CMD} -i "del(.spec.initialize_configuration.ic_obj_store_creation.object_stores[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
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
                    ${YQ_CMD} -i "del(.spec.datasource_configuration.dc_os_datasources[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
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
                    ${YQ_CMD} -i "del(.spec.datasource_configuration.dc_os_datasources[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
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
                    ${YQ_CMD} -i "del(.spec.datasource_configuration.dc_os_datasources[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
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
            ${YQ_CMD} -i "del(.spec.initialize_configuration.ic_ldap_creation.ic_ldap_admins_groups_name[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
        done

    fi

    containsInitLDAPUsers "${CP4A_PATTERN_FILE_TMP}"
     if (( ${#ldap_users_index_array[@]} > 1 ));then
        ((index_array_temp=${#ldap_users_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${ldap_users_index_array[$j]}-j))
            ${YQ_CMD} -i "del(.spec.initialize_configuration.ic_ldap_creation.ic_ldap_admin_user_name[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
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
                ${YQ_CMD} -i "del(.spec.baw_configuration[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
            done
        fi
    done

    containsAEInstance "${CP4A_PATTERN_FILE_TMP}"
     if (( ${#ae_index_array[@]} > 1 ));then
        ((index_array_temp=${#ae_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${ae_index_array[$j]}-j))
            ${YQ_CMD} -i "del(.spec.application_engine_configuration[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
        done
    fi

    containsICNRepos "${CP4A_PATTERN_FILE_TMP}"
     if (( ${#icn_repo_index_array[@]} > 1 ));then
        ((index_array_temp=${#icn_repo_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${icn_repo_index_array[$j]}-j))
            ${YQ_CMD} -i "del(.spec.initialize_configuration.ic_icn_init_info.icn_repos[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
        done
    fi

    containsICNDesktop "${CP4A_PATTERN_FILE_TMP}"
     if (( ${#icn_desktop_index_array[@]} > 1 ));then
        ((index_array_temp=${#icn_desktop_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${icn_desktop_index_array[$j]}-j))
            ${YQ_CMD} -i "del(.spec.initialize_configuration.ic_icn_init_info.icn_desktop[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
        done
    fi

    containsTenantDB "${CP4A_PATTERN_FILE_TMP}"
     if (( ${#tenant_db_index_array[@]} > 1 ));then
        ((index_array_temp=${#tenant_db_index_array[@]}-1))
        for ((j=0;j<${index_array_temp};j++))
        do
            ((index_os=${tenant_db_index_array[$j]}-j))
            ${YQ_CMD} -i "del(.spec.datasource_configuration.dc_ca_datasource.tenant_databases[\"${index_os}\"])" "${CP4A_PATTERN_FILE_TMP}"
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
        ${YQ_CMD} -i 'del(.spec.shared_configuration.storage_configuration.sc_block_storage_classname)' "${CP4A_PATTERN_FILE_TMP}"
    fi

    # if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
    #     if [[ (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams" || " ${PATTERNS_CR_SELECTED[@]} " =~ "decisions_ads") && !(" ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing") && !(" ${PATTERNS_CR_SELECTED[@]} " =~ "application") ]]; then
    #         ${YQ_CMD} d -i ${CP4A_PATTERN_FILE_TMP} spec.bastudio_configuration.playback_server
    #     fi
    # fi

    # Remove dc_os_datasources for `FNOS1DS` if content_os_number = 0
    if [[ "$DEPLOYMENT_TYPE" == "production" && $content_os_number -eq 0 ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^        dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'FNOS1DS'|cut -d':' -f1)
        # prompt_press_any_key_to_continue "$OS_DATASOURCE_NUMBER"
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
        OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
        ${YQ_CMD} -i "del(.spec.datasource_configuration.dc_os_datasources[\"${OS_DATASOURCE_NUMBER}\"])" "${CP4A_PATTERN_FILE_TMP}"
        fi
    fi

    # Apply value in property file into final cr
    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
        sync_property_into_final_cr
    fi

    # Generate Content Cortex AI Services CR if enabled
    if [[ "$SETUP_CONTENT_CORTEX_AI_SERVICES" == "true" ]]; then
        printf "\n"
        INFO "Generating the Content Cortex AI Services Custom Resource File..."
        
        # Source the AI services setup script to access its functions
        source "${CUR_DIR}/cp4a-content-cortex-ai-services-setup.sh"
        
        # Set namespace for CR generation
        NAMESPACE="$TARGET_PROJECT_NAME"
        
        # Parse the multi-provider property file
        parse_multi_provider_property_file || {
            error "Failed to parse AI services property file: ${AI_SERVICES_PROPERTY_FILE}"
            exit 1
        }
        
        # Read storage classes from user profile property file
        ai_services_slow_storage="$(prop_user_profile_property_file CP4BA.SLOW_FILE_STORAGE_CLASSNAME)"
        ai_services_slow_storage=$(sed -e 's/^"//' -e 's/"$//' <<<"$ai_services_slow_storage")
        
        # Read Redis setting from parsed properties (uses PARSED_ENABLE_REDIS variable, not array)
        ai_services_enable_redis="${PARSED_ENABLE_REDIS}"
        ai_services_enable_redis=$(echo "$ai_services_enable_redis" | tr '[:upper:]' '[:lower:]')
        
        # Normalize Redis flag
        if [[ "$ai_services_enable_redis" == "true" || "$ai_services_enable_redis" == "yes" || "$ai_services_enable_redis" == "y" ]]; then
            ai_services_enable_redis="true"
        else
            ai_services_enable_redis="false"
        fi
        
        # Read block storage from user profile if Redis is enabled
        ai_services_block_storage=""
        if [[ "$ai_services_enable_redis" == "true" ]]; then
            ai_services_block_storage="$(prop_user_profile_property_file CP4BA.BLOCK_STORAGE_CLASS_NAME)"
            ai_services_block_storage=$(sed -e 's/^"//' -e 's/"$//' <<<"$ai_services_block_storage")
        fi
        
        # Use the network policies flag from the interactive question (GENERATE_SAMPLE_NETWORK_POLICIES)
        # This variable is set by the ask_generate_network_policy() function
        ai_services_network_policies="$GENERATE_SAMPLE_NETWORK_POLICIES"

        # Use the Instana monitoring flag from the interactive question (ENABLE_INSTANA_MONITORING)
        # This variable is set by the enable_instana_monitoring() function
        ai_services_instana_monitoring="$ENABLE_INSTANA_MONITORING"
        
        # Generate the CR with all parameters (storage classes from user profile)
        generate_content_cortex_ai_services_cr "$TARGET_PROJECT_NAME" "$ai_services_slow_storage" "$ai_services_enable_redis" "$ai_services_block_storage" "$ai_services_network_policies" "$ai_services_instana_monitoring"
        
        success "The Content Cortex AI Services Custom Resource has been generated successfully and can be found under $CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL\n"
    fi

    # Format value
    ${SED_COMMAND} "s|'\"|\"|g" ${CP4A_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|\"'|\"|g" ${CP4A_PATTERN_FILE_TMP}
    # remove ldap_configuration and datasource_configuration when only select WfPS authoring
    if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "no" ]]; then
        ${YQ_CMD} -i 'del(.spec.ldap_configuration)' "${CP4A_PATTERN_FILE_TMP}"
    fi

    if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $EXTERNAL_DB_WFPS_AUTHORING == "No" ]]; then
        ${YQ_CMD} -i 'del(.spec.bastudio_configuration.admin_secret_name)' "${CP4A_PATTERN_FILE_TMP}"
        ${YQ_CMD} -i 'del(.spec.bastudio_configuration.database)' "${CP4A_PATTERN_FILE_TMP}"
    fi

    if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" ]]; then
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_deployment_fncm_license)' "${CP4A_PATTERN_FILE_TMP}"
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_deployment_baw_license)' "${CP4A_PATTERN_FILE_TMP}"
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_content_initialization)' "${CP4A_PATTERN_FILE_TMP}"
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_cpe_limited_storage)' "${CP4A_PATTERN_FILE_TMP}"
        ${YQ_CMD} -i 'del(.spec.datasource_configuration)' "${CP4A_PATTERN_FILE_TMP}"
    fi

    # remove application_engine_configuration/playback_server when only select BAW authoring/only WfPS authoring/both BAW authoring and WfPS authoring
    if [[ (! (" ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "application" || " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workstreams")) && ("${pattern_cr_arr[@]}" =~ "workflow-authoring" || "${pattern_cr_arr[@]}" =~ "workflow-process-service") ]]; then
        ${YQ_CMD} -i 'del(.spec.application_engine_configuration)' "${CP4A_PATTERN_FILE_TMP}"
    fi

    if [[ (! (" ${pattern_cr_arr[@]}" =~ "document_processing_designer" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer")) && ("${pattern_cr_arr[@]}" =~ "workflow-authoring" || "${pattern_cr_arr[@]}" =~ "workflow-process-service") ]]; then
        ${YQ_CMD} -i 'del(.spec.bastudio_configuration.playback_server)' "${CP4A_PATTERN_FILE_TMP}"
    fi
    # remove gcd/aeos/init without ae data persistent when only select BAA pattern

    if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "application" && (! "${optional_component_cr_arr[@]}" =~ "ae_data_persistence") ]]; then
        ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_gcd_datasource)' "${CP4A_PATTERN_FILE_TMP}"
        ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_os_datasources)' "${CP4A_PATTERN_FILE_TMP}"
        ${YQ_CMD} -i 'del(.spec.initialize_configuration)' "${CP4A_PATTERN_FILE_TMP}"
    fi

    if [[ "${#pattern_cr_arr[@]}" -gt "1" && (! "${optional_component_cr_arr[@]}" =~ "ae_data_persistence") ]]; then
        OS_DATASOURCE_NUMBER=$(grep "^        dc_common_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            ${YQ_CMD} -i "del(.spec.datasource_configuration.dc_os_datasources[\"${OS_DATASOURCE_NUMBER}\"])" "${CP4A_PATTERN_FILE_TMP}"
        fi

        OS_DATASOURCE_NUMBER=$(grep "^            dc_os_datasource_name: " ${CP4A_PATTERN_FILE_TMP} | grep -Fn 'AEOS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            ${YQ_CMD} -i "del(.spec.initialize_configuration.ic_obj_store_creation.object_stores[\"${OS_DATASOURCE_NUMBER}\"])" "${CP4A_PATTERN_FILE_TMP}"
        fi
    fi

    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
        # 5b/6: Remove pfs_configuration/application_engine_configuration ae_data_persistence/AEOS
        if [[ " ${pattern_cr_arr[@]} " =~ "application" || " ${pattern_cr_arr[@]} " =~ "document_processing" ]]; then
            echo # keep application_engine_configuration for BAA/ADP
        else
            if [[ (" ${pattern_cr_arr[@]} " =~ "workstreams") || (" ${pattern_cr_arr[@]} " =~ "workflow-runtime") ]]; then
                ${YQ_CMD} -i 'del(.spec.pfs_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                ${YQ_CMD} -i 'del(.spec.application_engine_configuration)' "${CP4A_PATTERN_FILE_TMP}"
                ${YQ_CMD} -i 'del(.spec.elasticsearch_configuration)' "${CP4A_PATTERN_FILE_TMP}"
            fi
        fi
    # 6: remove Navigator/GraphQL
        if [[ " ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "1" ]]; then
            ${YQ_CMD} -i 'del(.spec.ecm_configuration.graphql)' "${CP4A_PATTERN_FILE_TMP}"
            ${YQ_CMD} -i 'del(.spec.ecm_configuration.navigator_configuration)' "${CP4A_PATTERN_FILE_TMP}"
            ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_icn_datasource)' "${CP4A_PATTERN_FILE_TMP}"
        fi
    fi

    # For ARO/ROSA platform type
    if [[ $OCP_PLATFORM == "ARO" ]]; then
        ${YQ_CMD} -i '.spec.shared_configuration.sc_deployment_ocp_platform = "ARO"' ${CP4A_PATTERN_FILE_TMP}
    elif [[ $OCP_PLATFORM == "ROSA" ]]; then
        ${YQ_CMD} -i '.spec.shared_configuration.sc_deployment_ocp_platform = "ROSA"' ${CP4A_PATTERN_FILE_TMP}
    fi

    # sc_deployment_baw_license required for either workflow runtime or workflow authoring
    # For https://jsw.ibm.com/browse/DBACLD-161792
    if [[ ! (" ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring") ]]; then
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_deployment_baw_license)' "${CP4A_PATTERN_FILE_TMP}"
    fi

    # Remove sc_deployment_fncm_license
    if [[ ! (" ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence") ]]; then
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_deployment_baw_license)' "${CP4A_PATTERN_FILE_TMP}"
    fi

    # while [[ $TARGET_PROJECT_NAME == "" ]];
    # do
    #     printf "\n"
    #     printf '%b\n' "\x1B[1mWhere (namespace) do you want to deploy CP4BA operands (i.e., runtime pods)? \x1B[0m"
    #     read -p "Enter the name for an existing project (namespace): " TARGET_PROJECT_NAME
    #     if [ -z "$TARGET_PROJECT_NAME" ]; then
    #         printf '%b\n' "\x1B[1;31mEnter a valid project name, project name can not be blank\x1B[0m"
    #     elif [[ "$TARGET_PROJECT_NAME" == openshift* ]]; then
    #         printf '%b\n' "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
    #         TARGET_PROJECT_NAME=""
    #     elif [[ "$TARGET_PROJECT_NAME" == kube* ]]; then
    #         printf '%b\n' "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
    #         TARGET_PROJECT_NAME=""
    #     else
    #         isProjExists=`${CLI_CMD} get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l`  

    #         if [ "$isProjExists" -ne 2 ] ; then
    #             printf '%b\n' "\x1B[1;31mInvalid project name, please enter a existing project name ...\x1B[0m"
    #             TARGET_PROJECT_NAME=""
    #         else
    #             printf '%b\n' "\x1B[1mUsing project ${TARGET_PROJECT_NAME}...\x1B[0m"
    #         fi
    #     fi
    # done

    # Apply separation of operands into final CR
    if ${CLI_CMD} get configMap ibm-cp4ba-common-config -n $CP4BA_SERVICES_NS >/dev/null 2>&1; then
        cp4ba_services_namespace=$(${CLI_CMD} get configMap ibm-cp4ba-common-config -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found -o jsonpath='{.data.services_namespace}')
        cp4ba_operators_namespace=$(${CLI_CMD} get configMap ibm-cp4ba-common-config -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found -o jsonpath='{.data.operators_namespace}')
        if [[ (! -z $cp4ba_services_namespace) && (! -z $cp4ba_operators_namespace) ]]; then
            if [[ $cp4ba_services_namespace != $cp4ba_operators_namespace ]]; then
                info "This CP4BA deployment has been deployed with operators and operands in separate namespaces."
            fi
            info "The script will set \"$cp4ba_services_namespace\" as the namespace in the final custom resource file(s)."
            ${YQ_CMD} -i ".metadata.namespace = \"$cp4ba_services_namespace\" | .metadata.namespace style=\"double\"" ${CP4A_PATTERN_FILE_TMP}
        else
            warning "\"services_namespace\" was not found in the configMap ibm-cp4ba-common-config in the project \"$CP4BA_SERVICES_NS\""
            info "You need to apply the custom resource in the project for CP4BA operands and services, not in the project for CP4BA operators."
        fi
    else
        warning "ibm-cp4ba-common-config configmap was not found in the project \"$CP4BA_SERVICES_NS\"."
        # For https://jsw.ibm.com/browse/DBACLD-160661 where we have added remediation steps on how to recreate the configmap
        fail "You NEED to first create the \"ibm-cp4ba-common-config\" configMap in the project (namespace) where you want to deploy or upgrade CP4BA operands (i.e., runtime pods)."
        info "${YELLOW_TEXT}- [NEXT-STEPS]${RESET_TEXT}"
        echo "  - STEP 1 ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # Execute the cp4a-clusteradmin-setup.sh script with the \"-fix_configmap\" option to re-create the missing \"ibm-cp4ba-common-config\" configMap in the target namespace.For additional information refer to the Troubleshooting page in the Upgrade Section of the Knowledge Center.${RESET_TEXT}"
        exit 1
    fi

    # rename final CR to ibm_content_cr_final.yaml
    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
        CP4A_PATTERN_FILE_BAK=$FNCM_SEPARATE_PATTERN_FILE_BAK
    fi

    ${COPY_CMD} -rf ${CP4A_PATTERN_FILE_TMP} ${CP4A_PATTERN_FILE_BAK}

    if [[ "$DEPLOYMENT_TYPE" == "starter" && "$INSTALLATION_TYPE" == "new" && !("$SCRIPT_MODE" == "review" || "$SCRIPT_MODE" == "OLM") ]];then
        ${CLI_CMD} delete -f ${CP4A_PATTERN_FILE_TMP} >&3 2>&3
        sleep 5
        printf "\n"
        printf '%b\n' "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"

        if [[ "${ALL_NAMESPACE}" == "Yes" ]]; then
            APPLY_CONTENT_CMD="${CLI_CMD} apply -f ${CP4A_PATTERN_FILE_BAK} -n openshift-operators"
        else
            APPLY_CONTENT_CMD="${CLI_CMD} apply -f ${CP4A_PATTERN_FILE_BAK} -n $CP4BA_SERVICES_NS"
        fi
        if $APPLY_CONTENT_CMD ; then
            printf '%b\n' "\x1B[1mDone\x1B[0m"
        else
            printf '%b\n' "\x1B[1;31mFailed\x1B[0m"
        fi
    elif  [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
        ## CP4BA_APPLY_CR is going to be a environment variable to apply the CR for silent install.
        if [[ "$CP4BA_APPLY_CR" == "Yes" || "$CP4BA_APPLY_CR" == "YES" || "$CP4BA_APPLY_CR" == "yes" || "$CP4BA_APPLY_CR" == "True"  || "$CP4BA_APPLY_CR" == "TRUE"  || "$CP4BA_APPLY_CR" == "true" ]]; then
           printf '%b\n' "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"
           printf '%b\n' "${CP4A_PATTERN_FILE_BAK}"
           APPLY_CUSTOM_RESOURCE_CMD="${CLI_CMD} apply -f ${CP4A_PATTERN_FILE_BAK} -n $CP4BA_SERVICES_NS"
           if $APPLY_CUSTOM_RESOURCE_CMD ; then
               printf '%b\n' "\x1B[1mDone\x1B[0m"
           else
               printf '%b\n' "\x1B[1;31mFailed\x1B[0m"
           fi
        else
            printf "\n"
            printf '%b\n' "${YELLOW_TEXT}[NOTE]${RESET_TEXT} The custom resource (CR) file has been generated, but is not yet deployed (applied).\n"

            printf '%b\n' "${YELLOW_TEXT}[ATTENTION]${RESET_TEXT} Before deploying (applying) the custom resource (CR), follow the steps in the Knowledge Center ${BLUE_TEXT}\"Check and complete your custom resource\"${RESET_TEXT} to add or update any additional configuration to the custom resource file for the capabilities you have selected, which are not configured by the script: ${BLUE_TEXT} from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE navigate to Installing --> Installing Production Deployment --> Installing a CP4BA multi-pattern production deployment --> Creating a production deployment --> Checking and completing your custom resource${RESET_TEXT}  \n"

            if [[ "$UPDATE_COMPONENTS" == "true" ]]; then
                printf '%b\n' "${YELLOW_TEXT}[ATTENTION]${RESET_TEXT} The custom resource (CR) generated now reflects the updated list of deployment patterns and optional components. You must review the newly generated Custom Resource file to add any additional configuration that was manually added to live Custom Resource file on the cluster. Follow the steps in the Knowledge Center ${BLUE_TEXT}\"Check and complete your custom resource\"${RESET_TEXT} to add or update any additional configuration to the custom resource file for the capabilities you have added, which are not configured by the script: ${BLUE_TEXT} https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE ${RESET_TEXT}  \n"
                printf '%b\n' "${YELLOW_TEXT}[ATTENTION]${RESET_TEXT} Before applying the newly generated custom resource (CR), you must complete the below steps\n"
                printf '%b\n' "1. IF you have added any new object stores, you must patch the initialization-config configmap so that the new object stores required for the newly added deployment patterns can be configured. Execute - ${GREEN_TEXT} # ${CLI_CMD} patch cm $cluster_cr_name-initialization-config -n $CP4BA_SERVICES_NS --type merge -p '{\"data\":{\"cpe_initialized\":\"False\"}}' ${RESET_TEXT}. For more information refer to ${BLUE_TEXT} https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE ${RESET_TEXT}.   \n"
                # Currently not needed as we do not support EDB Postgres so using the function skip_edb to detect when to display this message
                if ! skip_edb; then
                printf '%b\n' "2. IF you have chosen EDB Postgres (deployed by the CP4BA Operator) as the Database type, you must patch configmaps \"ibm-cp4ba-shared-info\" and \"postgresql-operator-controller-manager-config\" so that any new databases required for the newly added deployment patterns can be configured. Execute - ${GREEN_TEXT} # ${CLI_CMD} patch cm ibm-cp4ba-shared-info -n $CP4BA_SERVICES_NS --type merge -p '{\"data\":{\"edb_cluster_cr_applied\":\"False\"}}' ${RESET_TEXT} and ${GREEN_TEXT} # ${CLI_CMD} patch cm postgresql-operator-controller-manager-config -n $CP4BA_SERVICES_NS --type merge -p '{\"data\":{\"DATABASE_CREATED\":\"False\"}}' ${RESET_TEXT}. For more information refer to ${BLUE_TEXT} https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE ${RESET_TEXT}.   \n"
                fi
            fi

            printf '%b\n' "${YELLOW_TEXT}[ATTENTION]${RESET_TEXT} After finishing configuring the custom resource (CR) file, follow the steps in the Knowledge Center to deploy (apply) your custom resource:${BLUE_TEXT} from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE navigate to Installing --> Installing Production Deployment --> Installing a CP4BA multi-pattern production deployment --> Creating a production deployment --> Deploying the custom resource you created with the deployment script ${RESET_TEXT} \n"
        fi
    fi
    
    printf '%b\n' "\x1B[1mThe custom resource file is located at: \"${CP4A_PATTERN_FILE_BAK}\"\x1B[0m"
    if [[ "$DEPLOYMENT_TYPE" == "production" && (" ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-workstreams" || " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-runtime" || " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-authoring") ]]; then
        printf "\n"
        printf '%b\n' "\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1mIf the cluster is running a Linux on Z (s390x)/Power architecture, remove the \x1B[0m\x1B[1;31mbaml_configuration\x1B[0m \x1B[1msection from \"${CP4A_PATTERN_FILE_BAK}\" before applying the custom resource. Business Automation Machine Learning Server (BAML) is not supported on this architecture.\n\x1B[0m"
    fi
    
    printf "\n"
    printf '%b\n' "\x1B[1mTo monitor the deployment status, follow the Operator logs.\x1B[0m"
    printf '%b\n' "\x1B[1mFor details, refer to the troubleshooting section in Knowledge Center here: \x1B[0m"
    printf '%b\n' "\x1B[1mfrom https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE navigate to Workflow automation --> Troubleshooting \x1B[0m"
}
# End - Modify FOUNDATION pattern yaml according pattent/components selected

function show_summary_pattern_selected(){
    printf "\n"
    printf '%b\n' "\x1B[1m*******************************************************\x1B[0m"
    printf '%b\n' "\x1B[1m            Summary of CP4BA capabilities              \x1B[0m"
    printf '%b\n' "\x1B[1m*******************************************************\x1B[0m"

    printf '%b\n' "\x1B[1;31m1. Cloud Pak capability to deploy: \x1B[0m"
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

    printf '%b\n' "\x1B[1;31m2. Optional components to deploy: \x1B[0m"
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
            elif [[ "${each_opt_component}" == "ContentCortexforMicrosoftOffice" ]]
            then
                printf '   * %s\n' "Content Cortex for Microsoft Office"
            elif [[ "${each_opt_component}" == "ContentIntegration" ]]
            then
                printf '   * %s\n' "Content Integration"
            elif [[ "${each_opt_component}" == "WorkplaceAssistant" ]]
            then
                printf '   * %s\n' "Workplace Assistant"
            elif [[ "${each_opt_component}" == "AuthoringAssistant" ]]
            then
                printf '   * %s\n' "(Preview) Authoring Assistant"
            elif [[ "${each_opt_component}" == "ContentCortexforMicrosoftOffice" ]]
            then
                printf '   * %s\n' "Content Cortex for Microsoft Office"
            elif [[ "${each_opt_component}" == "WorkflowRuntimeMCPServer" ]]
            then
                printf '   * %s\n' "Workflow Runtime MCP Server"
            else
                printf '   * %s\n' "${each_opt_component}"
            fi
        done
    fi
    printf '%b\n' "\x1B[1m*******************************************************\x1B[0m"
    info "Above CP4BA capabilities have been selected during the execution of the cp4a-prerequisites.sh script"
    prompt_press_any_key_to_continue
}

function show_summary(){
    local summary_index=1
    printf "\n"
    printf '%b\n' "\x1B[1m*******************************************************\x1B[0m"
    printf '%b\n' "\x1B[1m                    Summary of input                   \x1B[0m"
    printf '%b\n' "\x1B[1m*******************************************************\x1B[0m"

    printf '%b\n' "\x1B[1;31m${summary_index}. Cloud Pak capability to deploy: \x1B[0m"
    ((summary_index++))
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

    printf '%b\n' "\x1B[1;31m${summary_index}. Optional components to deploy: \x1B[0m"
    ((summary_index++))
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
            elif [[ "${each_opt_component}" == "ContentCortexforMicrosoftOffice" ]]
            then
                printf '   * %s\n' "Content Cortex for Microsoft Office"
            elif [[ "${each_opt_component}" == "ContentIntegration" ]]
            then
                printf '   * %s\n' "Content Integration"
            elif [[ "${each_opt_component}" == "WorkplaceAssistant" ]]
            then
                printf '   * %s\n' "Workplace Assistant"
            elif [[ "${each_opt_component}" == "AuthoringAssistant" ]]
            then
                printf '   * %s\n' "(Preview) Authoring Assistant"
            elif [[ "${each_opt_component}" == "ContentCortexforMicrosoftOffice" ]]
            then
                printf '   * %s\n' "Content Cortex for Microsoft Office"
            elif [[ "${each_opt_component}" == "WorkflowRuntimeMCPServer" ]]
            then
                printf '   * %s\n' "Workflow Runtime MCP Server"
            else
                printf '   * %s\n' "${each_opt_component}"
            fi
        done
    fi

    # Show Content Cortex AI Services status (only for Production deployment when enabled)
    if [[ "$DEPLOYMENT_TYPE" == "production" && "$SETUP_CONTENT_CORTEX_AI_SERVICES" == "true" ]]; then
        printf '%b\n' "\x1B[1;31m${summary_index}. Content Cortex AI Services:\x1B[0m Enabled"
        ((summary_index++))
    fi

    if [[ $PLATFORM_SELECTED == "other" ]]; then
        printf '%b\n' "\x1B[1;31m${summary_index}. Entitlement Registry key:\x1B[0m" # not show plaintext password
        ((summary_index++))
        printf '%b\n' "\x1B[1;31m${summary_index}. Docker registry service name or URL:\x1B[0m ${LOCAL_REGISTRY_SERVER}"
        ((summary_index++))
        printf '%b\n' "\x1B[1;31m${summary_index}. Docker registry user name:\x1B[0m ${LOCAL_REGISTRY_USER}"
        ((summary_index++))
        # printf '%b\n' "\x1B[1;31m${summary_index}. Docker registry password: ${LOCAL_REGISTRY_PWD}\x1B[0m"
        printf '%b\n' "\x1B[1;31m${summary_index}. Docker registry password:\x1B[0m" # not show plaintext password
        ((summary_index++))
    fi
    if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]];
    then
        if [ -z "$existing_infra_name" ]; then
            if  [[ $DEPLOYMENT_TYPE == "starter" && $PLATFORM_SELECTED == "OCP" ]];
            then
                printf '%b\n' "\x1B[1;31m${summary_index}. File storage classname(RWX):\x1B[0m ${STORAGE_CLASS_NAME}"
                ((summary_index++))
                printf '%b\n' "\x1B[1;31m${summary_index}. Block storage classname(RWO):\x1B[0m ${BLOCK_STORAGE_CLASS_NAME}"
                ((summary_index++))
                if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
                    printf '%b\n' "\x1B[1;31m${summary_index}. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
                    ((summary_index++))
                fi
            else
                printf '%b\n' "\x1B[1;31m${summary_index}. File storage classname(RWX):\x1B[0m"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Slow:" "${SLOW_STORAGE_CLASS_NAME}"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Medium:" "${MEDIUM_STORAGE_CLASS_NAME}"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Fast:" "${FAST_STORAGE_CLASS_NAME}"
                ((summary_index++))
                printf '%b\n' "\x1B[1;31m${summary_index}. Block storage classname(RWO): \x1B[0m${BLOCK_STORAGE_CLASS_NAME}"
                ((summary_index++))
                printf '%b\n' "\x1B[1;31m${summary_index}. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
                ((summary_index++))
            fi
        else
            if  [[ $PLATFORM_SELECTED == "OCP" ]]; then
                printf '%b\n' "\x1B[1;31m${summary_index}. OCP Infrastructure Node:\x1B[0m ${INFRA_NAME}"
                ((summary_index++))
            elif [[ $PLATFORM_SELECTED == "ROKS" ]]
            then
                printf '%b\n' "\x1B[1;31m${summary_index}. ROKS Infrastructure Node:\x1B[0m ${INFRA_NAME}"
                ((summary_index++))
            fi
            if  [[ $DEPLOYMENT_TYPE == "starter" && $PLATFORM_SELECTED == "OCP" ]];
            then
                printf '%b\n' "\x1B[1;31m${summary_index}. File storage classname(RWX):\x1B[0m ${STORAGE_CLASS_NAME}"
                ((summary_index++))
                printf '%b\n' "\x1B[1;31m${summary_index}. Block storage classname(RWO):\x1B[0m ${BLOCK_STORAGE_CLASS_NAME}"
                ((summary_index++))
                if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
                    printf '%b\n' "\x1B[1;31m${summary_index}. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
                    ((summary_index++))
                fi
            else
                printf '%b\n' "\x1B[1;31m${summary_index}. File storage classname(RWX):\x1B[0m"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Slow:" "${SLOW_STORAGE_CLASS_NAME}"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Medium:" "${MEDIUM_STORAGE_CLASS_NAME}"
                printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Fast:" "${FAST_STORAGE_CLASS_NAME}"
                ((summary_index++))
                printf '%b\n' "\x1B[1;31m${summary_index}. Block storage classname(RWO): \x1B[0m${BLOCK_STORAGE_CLASS_NAME}"
                ((summary_index++))
                printf '%b\n' "\x1B[1;31m${summary_index}. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
                ((summary_index++))
            fi
        fi
    else
        if  [[ $DEPLOYMENT_TYPE == "starter" ]];
        then
            printf '%b\n' "\x1B[1;31m${summary_index}. File storage classname(RWX):\x1B[0m ${STORAGE_CLASS_NAME}"
            ((summary_index++))
            printf '%b\n' "\x1B[1;31m${summary_index}. Block storage classname(RWO):\x1B[0m ${BLOCK_STORAGE_CLASS_NAME}"
            ((summary_index++))
            if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
                printf '%b\n' "\x1B[1;31m${summary_index}. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
                ((summary_index++))
            fi
        else
            printf '%b\n' "\x1B[1;31m${summary_index}. File storage classname(RWX):\x1B[0m"
        fi
        printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Slow:" "${SLOW_STORAGE_CLASS_NAME}"
        printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Medium:" "${MEDIUM_STORAGE_CLASS_NAME}"
        printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Fast:" "${FAST_STORAGE_CLASS_NAME}"
        ((summary_index++))
        if [[ $PLATFORM_SELECTED == "other" ]]; then
            printf '%b\n' "\x1B[1;31m${summary_index}. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
            ((summary_index++))
        fi
        if [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]]; then
            printf '%b\n' "\x1B[1;31m${summary_index}. Block storage classname(RWO):\x1B[0m ${BLOCK_STORAGE_CLASS_NAME}"
            ((summary_index++))
            printf '%b\n' "\x1B[1;31m${summary_index}. URL to zip file for JDBC and/or ICCSAP drivers:\x1B[0m ${CP4BA_JDBC_URL}"
            ((summary_index++))
        fi
    fi
    printf '%b\n' "\x1B[1m*******************************************************\x1B[0m"
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
        ${YQ_CMD} eval-all 'select(fi==0) *+ select(fi==1)' ${WORKFLOW_PATTERN_FILE} ${WORKSTREAMS_PATTERN_FILE} > $TEMP_FOLDER/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_workstreams.yaml
        WW_PATTERN_FILE=$TEMP_FOLDER/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_workstreams.yaml
        ${YQ_CMD} -i 'del(.spec.initialize_configuration.ic_obj_store_creation.object_stores.[3])' "${WW_PATTERN_FILE}"
        ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_os_datasources.[3])' "${WW_PATTERN_FILE}"
        ${YQ_CMD} -i 'del(.spec.initialize_configuration.ic_ldap_creation.ic_ldap_admin_user_name.[1])' "${WW_PATTERN_FILE}"
        ${YQ_CMD} -i 'del(.spec.initialize_configuration.ic_ldap_creation.ic_ldap_admins_groups_name.[1])' "${WW_PATTERN_FILE}"
        ${YQ_CMD} -i '.spec.baw_configuration[0].host_federated_portal = false' ${WW_PATTERN_FILE}
        ${YQ_CMD} -i '.spec.baw_configuration[1].host_federated_portal = false' ${WW_PATTERN_FILE}
        ${YQ_CMD} -i '.spec.baw_configuration[0].host_federated_portal = true' ${WW_PATTERN_FILE}
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
    # Loop through the CP4BA_OPERATOR_LIST defined in common.sh and start up the operator from that list
    # If the operator is ibm-dpe-operator then only start up when architecure is amd64
    info "$CP4BA_OPERATOR_LIST"
    for operator in $CP4BA_OPERATOR_LIST; do
        if [[ "$operator" == "ibm-dpe-operator" ]]; then
            arch_type=$(${CLI_CMD} get cm cluster-config-v1 -n kube-system -o yaml | grep -i architecture|tail -1| awk '{print $2}')
            if [[ "$arch_type" == "amd64" ]]; then
                info "Scaling up \"$operator\" operator"
                ${CLI_CMD} scale --replicas=1 deployment $operator -n $project_name >&3 2>&3
                if [ $? -eq 0 ]; then
                    sleep 1
                    if [[ -z "$run_mode" ]]; then
                        echo "Done!"
                    fi
                else
                    fail "Failed to scale up \"$operator\" operator"
                fi
            fi
        else
            info "Scaling up \"$operator\" operator"
            ${CLI_CMD} scale --replicas=1 deployment $operator -n $project_name >&3 2>&3
            if [ $? -eq 0 ]; then
                sleep 1
                if [[ -z "$run_mode" ]]; then
                    echo "Done!"
                fi
            else
                fail "Failed to scale up \"$operator\" operator"
            fi
        fi

    done
}

function shutdown_operator(){
    # scale down CP4BA operators base on the CP4BA_OPERATOR_LIST defined in common.sh
    local project_name=$1
    for operator in $CP4BA_OPERATOR_LIST; do
        
        if [[ $operator == "ibm-ads-operator" || $operator == "ibm-cp4a-wfps-operator" || $operator == "ibm-insights-engine-operator" ]]; then
            info "Scaling down \"$operator\" operator"
            ${CLI_CMD} scale --replicas=0 deployment $operator -n $project_name >&3 2>&3
            ${CLI_CMD} scale --replicas=0 deployment ${operator}-controller-manager -n $project_name >&3 2>&3
            sleep 1
            echo "Done!"

        else
            info "Scaling down \"$operator\" operator"
            ${CLI_CMD} scale --replicas=0 deployment $operator -n $project_name >&3 2>&3
            sleep 1
            echo "Done!"
        fi
    done
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
  ${CLI_CMD} apply -f ${CUR_DIR}/../descriptors/service_account.yaml --validate=false
  ${CLI_CMD} apply -f ${CUR_DIR}/../descriptors/role.yaml --validate=false
  ${CLI_CMD} apply -f ${CUR_DIR}/../descriptors/role_binding.yaml --validate=false
  ${CLI_CMD} apply -f ${CUR_DIR}/../upgradeOperator.yaml --validate=false
}

function patch_edb_configmap(){
# DBACLD-166239 -> Update EDB configmap ibm-zen-metastore-edb-cm to add new parameters with CPFS 4.10 or later.
# During upgrade, we check the existence of the configmap along with these 2 new parameters (DATABASE_ENABLE_SSL and DATABASE_SSL_MODE).
# If those parameters exists then we will not patch the configmap as the configmap is same for embedded and external postgres.
# Input:
#   namespace: The namespace that the configmap is located

local namespace=$1

is_edb_missing_ssl_enable_param=$(${CLI_CMD} get configmap ${ZEN_EDB_CFG} -n $namespace -o jsonpath='{.data.DATABASE_ENABLE_SSL}' 2>&1 )
is_edb_missing_ssl_mode_param=$(${CLI_CMD} get configmap ${ZEN_EDB_CFG} -n $namespace -o jsonpath='{.data.DATABASE_SSL_MODE}' 2>&1 )

#Patch cm if DATABASE_ENABLE_SSL does not exist
if [[  -z $is_edb_missing_ssl_enable_param ]]; then
    info "Patching ${ZEN_EDB_CFG} with DATABASE_ENABLE_SSL parameter"
    ${CLI_CMD} patch configmap ${ZEN_EDB_CFG} -n $namespace --type=merge -p '{"data": {"DATABASE_ENABLE_SSL":"'true'"}}'
fi
#Patch cm if DATABASE_SSL_MODE does not exist
if [[  -z $is_edb_missing_ssl_mode_param ]]; then
    info "Patching ${ZEN_EDB_CFG} with DATABASE_SSL_MODE parameter"
    ${CLI_CMD} patch configmap ${ZEN_EDB_CFG} -n $namespace --type=merge -p '{"data": {"DATABASE_SSL_MODE":"require"}}'

fi
}

# Function to patch the elastic search cluster CR with "quiesce":true which is required before upgrading to opensearch 2.19
# https://jsw.ibm.com/browse/DBACLD-166681
function patch_elasticsearch_cr(){
    local cr_namespace=$1
    # DBACLD-217914 Check if ElasticsearchCluster CRD exists first 
    ${CLI_CMD} get crd elasticsearchclusters.elasticsearch.opencontent.ibm.com >&3 2>&3
    if [ $? -eq 0 ]; then
	    elasticsearch_cr_name=$(${CLI_CMD} get ElasticsearchCluster -n $cr_namespace --no-headers --ignore-not-found | awk '{print $1}')
	    if [[ -n $elasticsearch_cr_name ]]; then
	        info "Patching ElasticsearchCluster $elasticsearch_cr_name in namespace $cr_namespace..."
	        ${CLI_CMD} patch ElasticsearchCluster $elasticsearch_cr_name -n $cr_namespace --type=merge -p '{"spec": {"quiesce":true}}'
	        printf "\n"
	    else
	        info " Manually patch the Elasticsearch Cluster by executing \" ${CLI_CMD} patch ElasticsearchCluster $elasticsearch_cr_name -n $cr_namespace --type=merge -p '{\"spec\": {\"quiesce\":true}}' \" "
	        printf "\n"
	    
	    fi
     fi
}
#DBACLD-166863: This function determines the UPGRADE_MODE
function determine_upgrade_mode () {
############
# This function will set the UPGRADE_MODE.  The main logic will use the following 2 parameters:
# 1. The UPGRADE_MODE: This is the mode that will be set.
# 2. ALLOW_DIRECT_UPGRADE: This is an internal flag that will allow the user to do a direct upgrade from 21.0.3.x/22.0.x/23.0.2.x to 25.0.0.x or later. If it's 1 then we'll use the old orginal logic to determine the UPGRADE_MODE.
## If it set to 0 then the UPGRADE_MODE will be set to "shared2shared" (Allnamespace -> Allnamespace) or "dedicated2dedicated" if the customer is already on 24.0.1.x or later.
############
# This is the original way to check for skip version upgrade such as 21.0.3.x/22.0.x/23.0.2.x to 25.0.0.x or later which we don't officially support in 25.0.0.x unless the ALLOW_DIRECT_UPGRADE is set to 1.
#DBACLD-215558: In CPfs 4.17, CPFS team no creates the common-service-maps in kube-public ns.  The equivalent cm is cpfs-v4-operator-ns
## The big bock (if the check for the existence of the cm in kube-public ns) is no longer the case for 26.0.0.x and later. Because we only allow the customer to upgrade to 26.0.0.x or later from 24.0.0.x/25.0.0.x/25.0.0.x or later. 
## There are only two scenarios for 4.0.0.x/25.0.0.x/25.0.0.x or later which are All-namespace (Allnamespace -> Allnamespace) or dedicated (dedicated -> dedicated)

    # if [[ -z "$UPGRADE_MODE" && "$ALLOW_DIRECT_UPGRADE" == 1 ]]; then
    #     cs_dedicated=$(${CLI_CMD} get cm -n ${COMMON_SERVICES_CM_NAMESPACE}  | grep ${COMMON_SERVICES_CM_DEDICATED_NAME} | awk '{print $1}')

    #     cs_shared=$(${CLI_CMD} get cm -n ${COMMON_SERVICES_CM_NAMESPACE}  | grep ${COMMON_SERVICES_CM_SHARED_NAME} | awk '{print $1}')

    #     if [[ "$cs_dedicated" != "" || "$cs_shared" != ""  ]] ; then
    #         control_namespace=$(${CLI_CMD} get cm ${COMMON_SERVICES_CM_DEDICATED_NAME} --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE} -o jsonpath='{ .data.common-service-maps\.yaml }' | grep  'controlNamespace' | cut -d':' -f2 )
    #         control_namespace=$(sed -e 's/^"//' -e 's/"$//' <<<"$control_namespace")
    #         control_namespace=$(sed "s/ //g" <<< $control_namespace)
    #     fi


    #     if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
    #         info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
    #         UPGRADE_MODE="shared2shared"
    #         ENABLE_PRIVATE_CATALOG=0
    #         info "Found the IBM Cloud Pak foundational services/IBM Cloud Pak for Business Automation are installed into all namespaces, IBM Cloud Pak foundational services only can be migrated from \"Cluster-scoped\" to \"Cluster-scoped\"!"
    #     elif [[ "$cs_dedicated" != "" && "$cs_shared" == "" ]]; then
    #         info "IBM Cloud Pak foundational services is working in \"Namespace-scoped\"."
    #         UPGRADE_MODE="dedicated2dedicated"
    #     elif [[ "$cs_dedicated" == "" && "$cs_shared" != "" && $ALL_NAMESPACE_FLAG == "No" ]]; then
    #         info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
    #         # select_upgrade_mode
    #         UPGRADE_MODE="shared2dedicated"
    #         info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
    #         prompt_press_any_key_to_continue
    #     elif [[ "$cs_dedicated" != "" && "$cs_shared" != "" && "$control_namespace" == "" ]]; then
    #         info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
    #         # select_upgrade_mode
    #         UPGRADE_MODE="shared2dedicated"
    #         info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
    #         prompt_press_any_key_to_continue
    #     elif [[ "$cs_dedicated" != "" && "$cs_shared" != "" && "$control_namespace" != "" ]]; then
    #         ${CLI_CMD} get cm ${COMMON_SERVICES_CM_DEDICATED_NAME} --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE} -o jsonpath='{ .data.common-service-maps\.yaml }' > /tmp/common-service-maps.yaml
    #         index=0
    #         common_service_namespace=`${YQ_CMD} ".namespaceMapping.[$index].map-to-common-service-namespace // \"\"" "/tmp/common-service-maps.yaml"`
    #         while [[ ! -z $common_service_namespace ]]
    #         do
    #             if [[ $common_service_namespace == "ibm-common-services" ]]; then
    #                 # listing all the requested namespaces that are in shared mode
    #                 # If the CP4BA_SERVICES_NS is in this list under ibm-common-services then it is shared otherwise it means CP4BA_SERVICES_NS is dedicated but there are other deployments in shared mode. Just checking if ibm-common-services is listed in namespaceMapping.map-to-common-service-namespace is not sufficient.
    #                 # For https://jsw.ibm.com/browse/DBACLD-168119
    #                 common_service_requested_namespace=`${YQ_CMD} ".namespaceMapping.[$index].requested-from-namespace" "/tmp/common-service-maps.yaml"`
    #                 if echo "$common_service_requested_namespace" | grep -q "$CP4BA_SERVICES_NS"; then
    #                     info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
    #                     # select_upgrade_mode
    #                     UPGRADE_MODE="shared2dedicated"
    #                     info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
    #                     prompt_press_any_key_to_continue
    #                     break
    #                 else
    #                     info "IBM Cloud Pak foundational services is working in \"Namespace-scoped\"."
    #                     UPGRADE_MODE="dedicated2dedicated"
    #                     prompt_press_any_key_to_continue
    #                     break
    #                 fi
    #             fi
    #             ((index++))
    #             common_service_namespace=`${YQ_CMD} ".namespaceMapping.[$index].map-to-common-service-namespace // \"\"" "/tmp/common-service-maps.yaml"`
    #             if [[ -z $common_service_namespace ]]; then
    #                 info "IBM Cloud Pak foundational services is working in \"Namespace-scoped\"."
    #                 UPGRADE_MODE="dedicated2dedicated"
    #             fi
    #         done
    #     elif [[ $ALL_NAMESPACE_FLAG == "No" ]]; then
    #         info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
    #         # select_upgrade_mode
    #         UPGRADE_MODE="shared2dedicated"
    #         info "IBM Cloud Pak foundational services will always migrate from \"Cluster-scoped\" to \"Namespace-scoped\"."
    #         prompt_press_any_key_to_continue
    #     fi
    # fi
# This scenario is the official support scenario for upgrading to 25.0.0.x or later.
# "all namespaces" ==> "all namespaces"
# "dedicated" ==> "dedicated"
    if [[ -z "$UPGRADE_MODE" && "$ALLOW_DIRECT_UPGRADE" != 1 ]]; then
        if [[ $ALL_NAMESPACE_FLAG == "Yes" ]]; then
            info "IBM Cloud Pak foundational services is working in \"Cluster-scoped\"."
            UPGRADE_MODE="shared2shared"
            ENABLE_PRIVATE_CATALOG=0
            info "Found the IBM Cloud Pak foundational services/IBM Cloud Pak for Business Automation are installed into all namespaces, IBM Cloud Pak foundational services only can be migrated from \"Cluster-scoped\" to \"Cluster-scoped\"!"
        else
            info "IBM Cloud Pak foundational services is working in \"Namespace-scoped\"."
            UPGRADE_MODE="dedicated2dedicated"
        fi 
    fi

}



#Function to ask if customer if the deployment being upgraded is an airgap based deployment or not.
function check_airgap_mode(){
    local max_retries=3
    local attempt=0

    printf "\n"

    printf '%b\n' "${BOLD_TEXT}Confirm if the upgrade is being executed for an online based CP4BA deployment or for an airgap/offline based CP4BA deployment : ${RESET_TEXT}"

    options=("Online" "Offline/Airgap")
    PS3='Enter a valid option [1 to 2]: '

    while [[ $attempt -lt $max_retries ]]; do
        select opt in "${options[@]}"
        do
            case $opt in
                "Offline/Airgap")
                    AIRGAP_INSTALL="yes"
                    return 0
                    ;;
                "Online")
                    AIRGAP_INSTALL="no"
                    return 0
                    ;;
                *)
                    attempt=$((attempt + 1))
                    if [[ $attempt -ge $max_retries ]]; then
                        error "Maximum retry limit reached while selecting airgap mode. Exiting..."
                        exit 1
                    fi
                    echo "invalid option $REPLY"
                    break
                    ;;
            esac
        done
    done
}


################################################
#### Begin - Main step for install operator ####
################################################
# Note: save_log moved earlier in script (after parse_arguments) for FastAPI integration

if [[ -n "${RUNTIME_MODE}" ]]; then
    info "The cp4a-deployment script is currently being executed in the ${RUNTIME_MODE} mode"
else
    info "The cp4a-deployment script is currently running in a mode designed to generate the custom resource (CR) file required for a CP4BA deployment"
    printf "\n"
fi

# Import upgrade upgrade_check_version.sh script
source ${CUR_DIR}/helper/upgrade/upgrade_check_status.sh

if [[ ($SCRIPT_MODE == "" && $RUNTIME_MODE == "") || ($SCRIPT_MODE == "dev" && $RUNTIME_MODE == "") || ($SCRIPT_MODE == "review" && $RUNTIME_MODE == "") || ($SCRIPT_MODE == "baw-dev" && $RUNTIME_MODE == "") ]]
then
    prompt_license

    detect_property_files

    # Check whether the CP4BA is separation of operators and operands.
    check_cp4ba_separate_operand $TARGET_PROJECT_NAME

    input_information    

    show_summary
    

    while true; do

        printf "\n"
        printf "\x1B[1mVerify that the information above is correct.\n\x1B[0m"
        printf "\x1B[1mTo proceed with the deployment, enter \"Yes\".\n\x1B[0m"
        printf "\x1B[1mTo make changes, enter \"No\" (default: No): \x1B[0m"
        if [[ -z ${CP4BA_SKIP_SUMMARY} ]]; then
          read -erp "" ans
        else
            ans=${CP4BA_SKIP_SUMMARY}
        fi
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            if [[ ("$SCRIPT_MODE" != "review") && ("$SCRIPT_MODE" != "OLM") ]]; then
                if [[ "$DEPLOYMENT_TYPE" == "production" ]];then
                    printf "\n"
                    printf '%b\n' "\x1B[1mCreating the Custom Resource of the Cloud Pak for Business Automation operator...\x1B[0m"                    
                fi
            fi
            printf "\n"
            
            if [[ "$SCRIPT_MODE" == "review" ]]; then
                printf '%b\n' "\x1B[1mReview mode is running. The final CR will be generated, but the operator will not be deployed.\x1B[0m"
                # prompt_press_any_key_to_continue
            elif [[ "$SCRIPT_MODE" == "OLM" ]]
            then
                printf '%b\n' "\x1B[1mA custom resource file for applying to the OCP Catalog is being generated.\x1B[0m"
                # prompt_press_any_key_to_continue
            else
                if [ "$use_entitlement" = "no" ] ; then
                    isReady=$(${CLI_CMD} get secret | grep ibm-entitlement-key)
                    if [[ -z $isReady ]]; then
                        echo "Secret \"ibm-entitlement-key\" not found, exiting..."
                        exit 1
                    else
                        echo "Secret \"ibm-entitlement-key\" found, continuing..."
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
                    # Prompt based on deployment type
                    if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                        # Starter: 4 options, or 5 if ICCSAP is selected
                        if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
                            printf "\x1B[1mEnter the number from 1 to 5 that you want to change: \x1B[0m"
                        else
                            printf "\x1B[1mEnter the number from 1 to 4 that you want to change: \x1B[0m"
                        fi
                    else
                        # Production: always 5 options
                        printf "\x1B[1mEnter the number from 1 to 5 that you want to change: \x1B[0m"
                    fi
                else
                    printf "\x1B[1mEnter the number from 1 to 7 that you want to change: \x1B[0m"
                fi

                read -erp "" ans
                if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]];
                then
                    case "$ans" in
                    "1")
                        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                            select_pattern
                            select_optional_component
                            if [[ ( -z "$CP4BA_JDBC_URL" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ]]; then
                                get_jdbc_url
                            fi
                        else
                            info "Run cp4a-prerequisites.sh to modify CP4BA capability"
                            prompt_press_any_key_to_continue
                        fi
                        break
                        ;;
                    "2")
                        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                            select_optional_component
                            if [[ ( -z "$CP4BA_JDBC_URL" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ]]; then
                                get_jdbc_url
                            fi
                        else
                            info "Run cp4a-prerequisites.sh to modify optional components"
                            prompt_press_any_key_to_continue
                        fi
                        break
                        ;;
                    "3"|"4")
                        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                            get_storage_class_name
                        else
                            info "Run cp4a-prerequisites.sh to modify storage class name"
                            prompt_press_any_key_to_continue
                        fi
                        break
                        ;;
                    "5")
                        get_jdbc_url
                        break
                        ;;
                    *)
                        # Dynamic error message based on deployment type
                        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                            # Starter: 4 options, or 5 if ICCSAP is selected
                            if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
                                printf '%b\n' "\x1B[1mEnter a valid number [1 to 5] \x1B[0m"
                            else
                                printf '%b\n' "\x1B[1mEnter a valid number [1 to 4] \x1B[0m"
                            fi
                        else
                            # Production: always 5 options
                            printf '%b\n' "\x1B[1mEnter a valid number [1 to 5] \x1B[0m"
                        fi
                        ;;
                    esac
                else
                    case "$ans" in
                    "1")
                        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                            select_pattern
                            select_optional_component
                            if [[ ( -z "$CP4BA_JDBC_URL" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ]]; then
                                get_jdbc_url
                            fi
                        else
                            info "Run cp4a-prerequisites.sh to modify CP4BA pattern"
                            prompt_press_any_key_to_continue
                        fi
                        break
                        ;;
                    "2")
                        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                            select_optional_component
                            if [[ ( -z "$CP4BA_JDBC_URL" ) && (" ${optional_component_cr_arr[@]} " =~ "iccsap") ]]; then
                                get_jdbc_url
                            fi
                        else
                            info "Run cp4a-prerequisites.sh to modify optional components"
                            prompt_press_any_key_to_continue
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
                        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                            get_storage_class_name
                        else
                            info "Run cp4a-prerequisites.sh to modify storage class name"
                            prompt_press_any_key_to_continue
                        fi
                        break
                        ;;
                    "8")
                        get_jdbc_url
                        break
                        ;;
                    *)
                        printf '%b\n' "\x1B[1mEnter a valid number [1 to 8] \x1B[0m"
                        ;;
                    esac
                fi
            done
            show_summary
            
            ;;
        esac
    done

    #DBACLD-231157: Add logic to display external PostgreSQL message for ADP/ADS components
    if [[ "$DEPLOYMENT_TYPE" == "production" && (" ${pattern_cr_arr[@]}" =~ "decisions_ads" || " ${pattern_cr_arr[@]}" =~ "document_processing") && "$DB_TYPE" != "postgresql" ]]; then
        adp_ads_ext_pg_message "deployment" "Decision Intelligence Client Managed Software and/or IBM Automation Document Processing"
    fi  
else
    ENABLE_PRIVATE_CATALOG=0
    # parse_arguments "$@"
    # if [[ -z "$RUNTIME_MODE" ]]; then
    #     printf '%b\n' "\x1B[1;31mPlease input value for \"-m <MODE_NAME>\" option.\n\x1B[0m"
    #     exit 1
    # fi
    # if [[ -z "$TARGET_PROJECT_NAME" ]]; then
    #     printf '%b\n' "\x1B[1;31mPlease input value for \"-n <NAME_SPACE>\" option.\n\x1B[0m"
    #     exit 1
    # fi
fi
############## Start - Migration CPfs mode and upgrade CP4BA Operators ##############

if [ "$RUNTIME_MODE" == "upgradeOperator" ]; then


    #DBACLD-222678: Check to see if we allow upgrade when EDB is used.
    # We only allow upgrade when there's no EDB is installed (is_edb_detected) and EDB is allowed (skip_edb = 1)
    # When 26.0.0-IF001 release where CNPG is supported, the skip_edb would return 1, then this condition would return false and allow the upgrade to proceed even when EDB is detected.
    if is_edb_detected $TARGET_PROJECT_NAME && skip_edb ; then
        info "Upgrade is not supported on ${VERSION_TO_SKIP_EDB} since EDB is being used. Upgrade with EDB will be supported in the upcoming iFix and next release "
        exit 1
    fi

    # Check whether the CP4BA is separation of operators and operands, namely seperation of duty.
    # DBACLD-175890: There is no need for CSV version in 25.0.0.x or later.
    # We want to check this first as from this defect we will be requesting the operand namespace to be passed in for -n argument
    # Once we can detect the SOD scenario we will use CP4BA_SERVICES_NS for the namespace where operands are deployed and CP4BA_OPERATOR_NS for the namespace where operators are deployed
    check_cp4ba_separate_operand $TARGET_PROJECT_NAME
    ALL_NAMESPACE_FLAG="No"
    

    # check current cp4ba version
    check_cp4ba_operator_version $CP4BA_OPERATOR_NS $ALLOW_DIRECT_UPGRADE


    ######## Start - Define variables cp4ba-upgrade for supporting multiple CP4BA instances ########
    UPGRADE_DEPLOYMENT_FOLDER=${CUR_DIR}/cp4ba-upgrade/project/$CP4BA_SERVICES_NS
    UPGRADE_DEPLOYMENT_PROPERTY_FILE=${UPGRADE_DEPLOYMENT_FOLDER}/cp4ba_upgrade.property

    UPGRADE_DEPLOYMENT_CR=${UPGRADE_DEPLOYMENT_FOLDER}/custom_resource
    UPGRADE_DEPLOYMENT_CSV_BAK=${UPGRADE_DEPLOYMENT_FOLDER}/csv/backup
    UPGRADE_DEPLOYMENT_CR_BAK=${UPGRADE_DEPLOYMENT_CR}/backup
    UPGRADE_DEPLOYMENT_CONTENT_CR=${UPGRADE_DEPLOYMENT_CR}/content.yaml
    UPGRADE_DEPLOYMENT_CONTENT_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.content_tmp.yaml
    UPGRADE_DEPLOYMENT_CONTENT_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/content_cr_backup.yaml

    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR=${UPGRADE_DEPLOYMENT_CR}/icp4acluster.yaml
    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.icp4acluster_tmp.yaml
    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/icp4acluster_cr_backup.yaml

    UPGRADE_DEPLOYMENT_BAI_TMP=${UPGRADE_DEPLOYMENT_CR}/.bai_tmp.yaml
    mkdir -p ${UPGRADE_DEPLOYMENT_CR} >/dev/null 2>&1
    mkdir -p ${TEMP_FOLDER} >/dev/null 2>&1
    ######## End - Define variables cp4ba-upgrade variables for supporting multiple CP4BA instances ########


    #Retrieve CR details
    # This function is defined in the common.sh script and the function find the top level CR kind and name
    # Top level CR kind and name are stored in the variables top_level_cr_type and top_level_cr_name
    # The function also stores the name of the icp4acluster and content CR names in the variables icp4acluster_cr_name,content_cr_name
    # The function also reads the CR details for both CR kinds if present and stores the CR details in "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP" "$UPGRADE_DEPLOYMENT_CONTENT_CR_TMP"
    # The top level CR details is stored in the file top_level_cr_details_location
    # FUNCTION HAS TO BE CALLED AFTER THE ABOVE VARIABLE DEFINITION
    # From this point on in the script we should attempt to re-use these variables
    retrieve_custom_resource_details "$CP4BA_SERVICES_NS" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP" "$UPGRADE_DEPLOYMENT_CONTENT_CR_TMP"

    ################## Start - Apply third-party WORKAROUND ####################
    # As workaround for https://github.ibm.com/IBMPrivateCloud/roadmap/issues/64017
    # require to remove ibm-operator-catalog first, and then to add back after upgrading.
    # This check has been commented out since 24.0.0 IF001 as upgrade can now be completed with ibm-operator-catalog
    #info "Checking \"ibm-operator-catalog\" exist or not in project \"openshift-marketplace\""
    #printf "\n"
    #if ${CLI_CMD} get catalogsource -n openshift-marketplace --no-headers --ignore-not-found | grep ibm-operator-catalog ; then
    #    echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}${RED_TEXT}Detected \"ibm-operator-catalog\" catalog source in project \"openshift-marketplace\".  This configuration is not yet supported for upgrade and will be supported in a future interim fix.  The upgrade will terminate.${RESET_TEXT}"
    #    exit 1
    #fi

    # As workaround for https://github.ibm.com/IBMPrivateCloud/roadmap/issues/64207
    # update secret postgresql-operator-controller-manager-config in <cp4ba> namespace and/or ibm-common-services namespace and add this annotation ibm-bts/skip-updates: "true"
    if ${CLI_CMD} get secret -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found | grep postgresql-operator-controller-manager-config >&3 2>&3; then
        ${CLI_CMD} patch secret postgresql-operator-controller-manager-config -n $CP4BA_SERVICES_NS -p '{"metadata": {"annotations": {"ibm-bts/skip-updates": "true"}}}' >&3 2>&3
    fi
    if ${CLI_CMD} get secret -n ibm-common-services --no-headers --ignore-not-found | grep postgresql-operator-controller-manager-config >&3 2>&3; then
        ${CLI_CMD} patch secret postgresql-operator-controller-manager-config -n ibm-common-services -p '{"metadata": {"annotations": {"ibm-bts/skip-updates": "true"}}}' >&3 2>&3
    fi
    ################## End - Apply third-party WORKAROUND ####################

    ################## Start of workaround for https://jsw.ibm.com/browse/DBACLD-167061  
    # We're setting spec.enableSuperuserAccess to true for our postgres-cp4ba edb instance
    info "Determining if EnterpriseDB PostgreSQL \"$EDB_INSTANCE_CP4BA_NAME\" is installed for IBM Cloud Pak for Business Automation."
    # DBACLD-217914 Check if EnterpriseDB PostgreSQL CRD exists first
    ${CLI_CMD} get crd clusters.postgresql.k8s.enterprisedb.io >&3 2>&3
    if [ $? -eq 0 ]; then
	    edb_instance_cp4ba_cr=$( ${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found $EDB_INSTANCE_CP4BA_NAME | awk '{print $1}' )
	    if [[ $edb_instance_cp4ba_cr == $EDB_INSTANCE_CP4BA_NAME  ]]; then
	      info "Found EnterpriseDB PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\""
	
	      info "In certain deployment scenarios, such as if IBM Automation Document Processing deployed"
	      info "Patching the EnterpriseDB PostgreSQL \"$EDB_INSTANCE_CP4BA_NAME\" with '{\"spec\": {\"enableSuperuserAccess\":true}}' is required"
	
	      enable_superuser_access=$( ${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found $EDB_INSTANCE_CP4BA_NAME -o jsonpath='{.spec.enableSuperuserAccess}' )
	      if [[ "$(echo "$enable_superuser_access" | tr '[:upper:]' '[:lower:]')" != "true" ]]; then
	        ${CLI_CMD} patch cluster.postgresql.k8s.enterprisedb.io  $EDB_INSTANCE_CP4BA_NAME -n $CP4BA_SERVICES_NS --type=merge -p '{"spec": {"enableSuperuserAccess":true}}'  >&3 2>&3
	      else
	        info "The EnterpriseDB PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" already as the field \"enableSuperuserAccess\" set to true."
	      fi
	    else 
	      info "Unable to find EnterpriseDB PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\""
	      info "If the EnterpriseDB PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" exists, execute the command: "
	      info "${CLI_CMD} patch cluster.postgresql.k8s.enterprisedb.io  $EDB_INSTANCE_CP4BA_NAME -n $CP4BA_SERVICES_NS --type=merge -p '{\"spec\": {\"enableSuperuserAccess\":true}}'"
	    fi
     fi
    ################## End of setting spec.enableSuperuserAccess to true for our postgres-cp4ba edb instance


    ############## Start - Prepare definition for ibm-cp4ba-shared-info/ibm-cp4ba-content-shared-info/ibm-cp4ba-common-config configMap ##############

    source ${CUR_DIR}/helper/upgrade/upgrade_merge_yaml.sh $CP4BA_SERVICES_NS $ALLOW_DIRECT_UPGRADE
    
    ############## End - Prepare definition for ibm-cp4ba-shared-info/ibm-cp4ba-content-shared-info/ibm-cp4ba-common-config configMap ##############


    # Instead of checking if a crd type content is present and then checking if it is a top level CR and then taking the CR details,
    # we can just use the variables loaded by the retrieve_custom_resource_details function which does all this at the start of each mode
    if [[ "$top_level_cr_kind" == "content" ]]; then
        bai_flag=`${YQ_CMD} ".spec.content_optional_components.bai" "$top_level_cr_details_location"`
        bai_flag=$(echo "$bai_flag" | tr '[:upper:]' '[:lower:]')
        CONTENT_CR_EXIST="Yes"
        cp4ba_root_ca_secret_name=`${YQ_CMD} ".spec.shared_configuration.root_ca_secret" "$top_level_cr_details_location"`
        # Check if CSS has been selected as an optional component or not 
        css_flag=$(${CLI_CMD} get content $content_cr_name -n $CP4BA_SERVICES_NS -o yaml | ${YQ_CMD} '.spec.content_optional_components.css' -)
        css_flag=$(echo "$css_flag" | tr '[:upper:]' '[:lower:]')
        # Check fncm_secret_name for default ibm-fncm-secret
        fncm_secret_name_val=$(${CLI_CMD} get content $content_cr_name -n $CP4BA_SERVICES_NS -o yaml | ${YQ_CMD} '.spec.ecm_configuration.fncm_secret_name // ""' -)
        if [[ ! -z $fncm_secret_name_val ]]; then
            CP4BA_IBM_FNCM_SECRET_NAME=$fncm_secret_name_val
        fi
    elif [[ "$top_level_cr_kind" == "icp4acluster" ]]; then
        cp4ba_root_ca_secret_name=`${YQ_CMD} ".spec.shared_configuration.root_ca_secret" "$top_level_cr_details_location"`
        convert_olm_cr "${top_level_cr_details_location}"
        if [[ $olm_cr_flag == "No" ]]; then
            # Get EXISTING_PATTERN_ARR/EXISTING_OPT_COMPONENT_ARR
            existing_pattern_list=""
            existing_opt_component_list=""
            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_patterns" "$top_level_cr_details_location"`
            existing_opt_component_list=`${YQ_CMD} ".spec.shared_configuration.sc_optional_components" "$top_level_cr_details_location"`

            OIFS=$IFS
            IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
            IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
            IFS=$OIFS
            # BAI and CSS being selected as optional components can be done using EXISTING_OPT_COMPONENT_ARR which stores the list of optional components selected
            # Check fncm_secret_name for default ibm-fncm-secret
            fncm_secret_name_val=`${YQ_CMD} ".spec.ecm_configuration.fncm_secret_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
            if [[ ! -z $fncm_secret_name_val ]]; then
                CP4BA_IBM_FNCM_SECRET_NAME=$fncm_secret_name_val
            fi
        fi
    else
        fail "No top level CP4BA custom resource found on this cluster in the project \"$CP4BA_SERVICES_NS\"."
        exit 1
    fi

    # Updating the elastic search CR to switch the quiesce flag from false to true
    # https://jsw.ibm.com/browse/DBACLD-166681
    if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "pfs") || $bai_flag == "true" ]]; then
        patch_elasticsearch_cr "$CP4BA_SERVICES_NS"
    fi

    # Create the ODM keystore secret before upgrade, keystore password is auto generated
    # ODM secret is only created if it is not found in the existing namespace. There is a chance the user is upgrading from a version that already contains the required changes for this issue.
    # https://jsw.ibm.com/browse/DBACLD-238578
    if [[ "${EXISTING_PATTERN_ARR[@]} " =~ "decisions" ]]; then
        create_odm_keystore_secret_for_upgrade "$CP4BA_SERVICES_NS" "$top_level_cr_details_location"
    fi

    info "Starting to upgrade CP4BA operators and IBM Cloud Pak foundational services"

    ############## Start - Check CP4BA operator is already upgrade and how to rerun upgradeOperator ##############
    if [[ "$cp4a_operator_csv_version" == "${CP4BA_CSV_VERSION//v/}" ]]; then
        warning "The ClusterServiceVersion (CSV) of CP4BA operator already is $CP4BA_CSV_VERSION."
        printf "\n"
        source ${CUR_DIR}/helper/messages.sh

        # For API calls this question will be skipped and we will just execute the script
        # The only time this part of the code is executed is if the user re-runs the API after the operators is already upgraded
        if [[ "$SKIP_FOR_API" != "true" ]]; then
            while true; do
                printf "\n"
                printf "\x1B[1mDo you want to continue to do upgrade? (Yes/No, default: No): \x1B[0m"
                read -rp "" ans
                case "$ans" in
                "y"|"Y"|"yes"|"Yes"|"YES")
                    # if the user is running the upgradeOperator command with --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver 25.0.1 flags that means the user is explicitly trying to re-run upgrade
                    # In that scenario we should not exit out and allow upgrade to continue
                    # For https://jsw.ibm.com/browse/DBACLD-186019
                    if [[ -z $CP4BA_ORIGINAL_CSV_VERSION ]]; then
                        displayUpgradeOperatorMessage '' $CP4BA_SERVICES_NS $cp4a_operator_csv_version
                        exit 1
                    else
                        break
                    fi
                    ;;
                "n"|"N"|"no"|"No"|"NO"|"")
                    echo "Exiting..."
                    exit 1
                    ;;
                *)
                    printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
                    ;;
                esac
            done
        else
            warning "Since the upgrade is being done via API, the rest of the code will execute."
        fi
    fi
    ############## End - Check CP4BA operator is already upgrade and how to rerun upgradeOperator ##############

    # Function call to check for airgap mode
    # For interactive mode we ask the user whether the script is being executed in airgap mode or not
    # For the upgrade Container, the script will only consider the deployment to be airgap if --airgap_deployment is passed as an argument
    if [[ "$SKIP_FOR_API" != "true" ]]; then
        check_airgap_mode
    else
        # IF the variable is not defined at this point that means that it a silent install i.e with the upgradeContainer and it is NOT an airgap install so we set it to no
        if [[ -z "$AIRGAP_INSTALL" ]]; then
            AIRGAP_INSTALL="no"
        fi        
    fi

    ############## Start - Create ibm-cp4ba-shared-info/ibm-cp4ba-content-shared-info configMap ##############
    
    info "Checking if the ibm-cp4ba-shared-info/ibm-cp4ba-content-shared-info configMap exists in the project \"$CP4BA_SERVICES_NS\""
    ibm_cp4ba_shared_info_cm=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath='{.data.cp4ba_operator_of_last_reconcile}')
    ibm_cp4ba_content_shared_info_cm=$(${CLI_CMD} get configmap ibm-cp4ba-content-shared-info --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath='{.data.content_operator_of_last_reconcile}')
    # flag to track which shared-info configmap to use. By default this flag will be true, it will turn false only if it is a content based CR 
    cp4ba_shared_info_used=true

    # Instead of checking if a crd type content is present and then checking if it is a top level CR and then taking the CR details,
    # we can just use the variables loaded by the retrieve_custom_resource_details function which does all this at the start of each mode
    if [[ "$top_level_cr_kind" == "icp4acluster" ]]; then
        
        # Read values from the saved file
        cr_version=$(${YQ_CMD} '.spec.appVersion' ${top_level_cr_details_location})
        cr_metaname=$(${YQ_CMD} '.metadata.name' ${top_level_cr_details_location})
        cr_uid=$(${YQ_CMD} '.metadata.uid' ${top_level_cr_details_location})
        
        # This is a common function that can create the shared info configmap or patch it with required values.
        # The function replaces code that was essentially repeating with the only differences being the name of the configmap based on the top level CR
        # The function takes in 4 parameters
        # 1. The name of the configmap
        # 2. The current details of that configmap
        # 3. The namespace to check for the configmap
        # 4. The temporary file location that is used to as a template yaml to create the configmap if it is not present
        # 5. The top level CR kind
        populate_shared_info_configmap "ibm-cp4ba-shared-info" "$ibm_cp4ba_shared_info_cm" "$CP4BA_SERVICES_NS" "${UPGRADE_ICP4A_SHARED_INFO_CM_FILE}" "$top_level_cr_kind"
        
    elif [[ "$top_level_cr_kind" == "content" ]]; then
        
        # Setting this variable to false so that we know the cp4ba-content-shared-info is to be used
        cp4ba_shared_info_used=false 
        
        # Read values from the saved file
        cr_version=$(${YQ_CMD} '.spec.appVersion' ${top_level_cr_details_location})
        cr_uid=$(${YQ_CMD} '.metadata.uid' ${top_level_cr_details_location})
        cr_metaname=$(${YQ_CMD} '.metadata.name' ${top_level_cr_details_location})

        # This is a common function that can create the shared info configmap or patch it with required values.
        # The function replaces code that was essentially repeating with the only differences being the name of the configmap based on the top level CR
        # The function takes in 4 parameters
        # 1. The name of the configmap
        # 2. The current details of that configmap
        # 3. The namespace to check for the configmap
        # 4. The temporary file location that is used to as a template yaml to create the configmap if it is not present
        # 5. The top level CR kind
        populate_shared_info_configmap "ibm-cp4ba-content-shared-info" "$ibm_cp4ba_content_shared_info_cm" "$CP4BA_SERVICES_NS" "${UPGRADE_ICP4A_CONTENT_SHARED_INFO_CM_FILE}" "$top_level_cr_kind"
    
    else
        fail "No top level CP4BA custom resource found on this cluster in the project \"$CP4BA_SERVICES_NS\"."
        exit 1
    fi

    ############## End - Create ibm-cp4ba-shared-info/ibm-cp4ba-content-shared-info configMap ##############





    ############## Start - Check existing icp4acluster/content cr or not ##############
    PLATFORM_SELECTED=$(eval echo $(${CLI_CMD} get icp4acluster $(${CLI_CMD} get icp4acluster --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS | grep NAME -v | awk '{print $1}') --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o yaml | grep sc_deployment_platform | tail -1 | cut -d ':' -f 2))
    if [[ -z $PLATFORM_SELECTED ]]; then
        PLATFORM_SELECTED=$(eval echo $(${CLI_CMD} get content $(${CLI_CMD} get content --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS | grep NAME -v | awk '{print $1}') --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o yaml | grep sc_deployment_platform | tail -1 | cut -d ':' -f 2))
        if [[ -z $PLATFORM_SELECTED ]]; then
            fail "No custom resource for CP4BA found in the project \"$CP4BA_SERVICES_NS\", exiting"
            exit 1
        fi
    fi
    ############## End - Check existing icp4acluster/content cr or not ##############

    ############## Start - Decide which CPfs migration mode should be used ##############
    #DBACLD-166863: Calling determine_upgrade_mode function
    determine_upgrade_mode
    ############## End - Decide which CPfs migration mode should be used ##############

    ############## Start - Decide which catalog source (GNC/Private) should be used ##############
    if [[ "$PLATFORM_SELECTED" != "other" ]]; then
        # checking existing catalog type
        if ${CLI_CMD} get catalogsource -n openshift-marketplace --no-headers --ignore-not-found | grep ibm-cp4a-operator-catalog >&3 2>&3; then
            CATALOG_FOUND="Yes"
            PINNED="Yes"
        elif ${CLI_CMD} get catalogsource -n openshift-marketplace --no-headers --ignore-not-found | grep ibm-operator-catalog >&3 2>&3; then
            CATALOG_FOUND="Yes"
            PINNED="No"
        else
            CATALOG_FOUND="No"
            PINNED="Yes" # Fresh install use pinned catalog source
        fi

        # Check --enable-private-catalog is set or not and whether reasonable for shared2shared
        # To call select_private_catalog_cp4ba if not set --enable-private-catalog option.
        if ${CLI_CMD} get catalogsource -n $CP4BA_OPERATOR_NS --no-headers --ignore-not-found | grep ibm-cp4a-operator-catalog >&3 2>&3; then
            PRIVATE_CATALOG_FOUND="Yes"
            ENABLE_PRIVATE_CATALOG=1
            info "Found this CP4BA deployment is installed using private catalog in the project \"$CP4BA_OPERATOR_NS\""
        
        # Here are the scenarios you could have if the script enters this below elif ->
        # You are in global catalog based deployment and you are either moving to private catalog or retaining global catalog
        elif ${CLI_CMD} get catalogsource -n openshift-marketplace --no-headers --ignore-not-found | grep ibm-cp4a-operator-catalog >&3 2>&3; then
            PRIVATE_CATALOG_FOUND="No"
            info "Found this CP4BA deployment is installed using global catalog in the project \"openshift-marketplace\""
            
        
            # You will move to private catalog by default if you have passed --enable-private-catalog at the time of executing the script or if the API endpoint does it for you.
            # Eg: cp4a-deployment.sh -m upgradeOperator -n ns --enable-private-catalog will move you to private catalog with either the script or the API endpoint, 
            # the only difference is that the API endpoint will have the --silent flag
            # These are the scenarios that will get the script to enter the below if condition
            if [[ $ENABLE_PRIVATE_CATALOG -eq 1 && ($UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated") ]]; then
                info "You have set the option \"--enable-private-catalog\" for this CP4BA deployment to use a private catalog"
                info "This means you have chosen to switch from global catalog (GCN) to private catalog (namespace scope).The CP4BA catalog sources will be applied in the $CP4BA_OPERATOR_NS namespace."
            
            # For the script to enter the below elif condition, the deployment is in global catalog and the --enable-private-catalog has NOT been passed by either the script or the API endpoint
            elif [[ $ENABLE_PRIVATE_CATALOG -eq 0 || -z $ENABLE_PRIVATE_CATALOG ]]; then
                if [[ $UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated" ]]; then
                    # For API calls this function which asks the question to switch from global to private or retain global will be skipped.
                    # We get the answer to the question for API calls based on if the --enable-private-catalog has been passed.
                    # If the API endpoint has gotten to this condition that means the deployment will remain global catalog which is what the else condition takes care off
                    # If the script gets to this part , we can ask the user to provide information if they wish to keep the global catalog or switch to private catalog
                    if [[ "$SKIP_FOR_API" != "true" ]]; then
                        select_private_catalog_cp4ba
                    else
                        # The only way the script got here is if the deployment is global and the deployment must remain global AND we are using API endpoints
                        info "You have chosen to retain the global catalog namespace.The CP4BA catalog sources will remain in the \"openshift-marketplace\" namespace."
                        ENABLE_PRIVATE_CATALOG=0
                    fi
                fi
            fi
        fi

        if [[ $ENABLE_PRIVATE_CATALOG -eq 1 && $PRIVATE_CATALOG_FOUND == "No" && ($UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated") ]]; then
            info "The global catalog namespace (GCN) will be switched to private catalog (namespace-scoped)."
            sleep 2
        elif [[ $PRIVATE_CATALOG_FOUND == "Yes" ]]; then
            ENABLE_PRIVATE_CATALOG=1
            info "Keep using the private catalog (namespace-scoped) for this CP4BA deployment."
            sleep 2
        fi

        # For shared->dedicated upgrade, we should allow user option to keep "global catalog"
        if [[ $ENABLE_PRIVATE_CATALOG -eq 0 && $UPGRADE_MODE == "shared2dedicated" ]]; then
            echo "${RED_TEXT}[WARNING]${RESET_TEXT}: ${YELLOW_TEXT}Before proceeding with the upgrade: if you have multiple CP4BA deployments on this cluster and you don't want them to be updated, update installPlan approval for BTS and EDB PostgreSQL on the other CP4BA deployments from \"Automatic\" to \"Manual\".${RESET_TEXT}"
            # For API calls this question will be skipped and we will just execute the script
            if [[ "$SKIP_FOR_API" != "true" ]]; then
                prompt_press_any_key_to_continue
            fi
        fi
    fi
    ############## End - Decide which catalog source (GNC/Private) should be used ##############


    ######### START - THE Check to see if SCIM is configured in the Domain ########

    # This check is only when Content pattern exists and can be skipped otherwise
    # https://jsw.ibm.com/browse/DBACLD-157386 https://jsw.ibm.com/browse/DBACLD-178101 https://jsw.ibm.com/browse/DBACLD-177550 https://jsw.ibm.com/browse/DBACLD-177742

    # if [[ $CONTENT_CR_EXIST == "Yes" || (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (! " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service")) || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
    #     info "Determining if the directory provider type is SCIM for Content Process Engine."
    #     CONTENT_DEPLOYMENT_NAME=$(${CLI_CMD} get deployment ibm-content-operator --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o name)
    #     if [[ ! -z $CONTENT_DEPLOYMENT_NAME ]]; then
    #         ${CLI_CMD} scale --replicas=1 deployment ibm-content-operator -n $TARGET_PROJECT_NAME >&3 2>&3
    #         info "Waiting for ibm-content-operator pod to be ready in the project \"$TARGET_PROJECT_NAME\"."
    #         maxRetry=10
    #         for ((retry=0;retry<=${maxRetry};retry++)); do
    #             pod_name=$(${CLI_CMD} get pod -l=name=ibm-content-operator -n $TARGET_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
    #             if [[ -z $pod_name ]]; then
    #                 if [[ $retry -eq ${maxRetry} ]]; then
    #                     printf "\n"
    #                     if [[ -z $pod_name ]]; then
    #                         warning "Timeout waiting for ibm-content-operator pod to be ready in the project \"$TARGET_PROJECT_NAME\""
    #                     fi
    #                     exit 1
    #                 else
    #                     sleep 15
    #                     printf '%s' "..."
    #                     continue
    #                 fi
    #             else
    #                 break
    #             fi
    #         done
    #     fi
    #     # Calling function to check the SCIM configuration
    #     is_scim_enabled
    #     #echo " SCIM DETAILS ->>> $IS_SCIM_ENABLED"
    #     # Based on the shared-info configmap we are using , we will patch the scim_configured value in that CM to later be used in upgradeDeployment mode
    #     if [[ "$cp4ba_shared_info_used" == true ]]; then
    #         shared_info_configmap="ibm-cp4ba-shared-info"
    #     else
    #         shared_info_configmap="ibm-cp4ba-content-shared-info"
    #     fi
    #     #Patching configmap with the SCIM configuration value
    #     if ! ${CLI_CMD} patch configmap "$shared_info_configmap" -n "$CP4BA_SERVICES_NS" --type=json -p="[{'op': 'add', 'path': '/data/scim_configured', 'value': '$(echo "$IS_SCIM_ENABLED")'}]" >&3 2>&3; then
    #         warning "Failed to patch ConfigMap '$shared_info_configmap' in namespace '$CP4BA_SERVICES_NS' with the SCIM configuration details."
    #     fi
    # fi
    ######### END - THE Check to see if SCIM is configured in the Domain ########

    ############## Start - Decide whether to create savepoint for Flink job ##############
    # NOTES: No need to create save point for upgrade IFIX by IFIX
    # Checking CSV for cp4ba-operator/content-operator/bai-operator to decide whether to do BAI save point during IFIX to IFIX upgrade
    sub_inst_list=$(${CLI_CMD} get subscription.operators.coreos.com -n $CP4BA_OPERATOR_NS|grep ibm-cp4a-operator-catalog|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
    if [[ -z $sub_inst_list ]]; then
        info "No existing CP4BA subscriptions found, continuing ..."
        # exit 1
    fi
    sub_array=($sub_inst_list)
    target_csv_version=${CP4BA_CSV_VERSION//v/}
    for i in ${!sub_array[@]}; do
        if [[ ! -z "${sub_array[i]}" ]]; then
            if [[ ${sub_array[i]} = ibm-cp4a-operator* || ${sub_array[i]} = ibm-content-operator* || ${sub_array[i]} = ibm-insights-engine-operator* || ${sub_array[i]} = ibm-workflow-operator* ]]; then
                current_version=$(${CLI_CMD} get subscription.operators.coreos.com ${sub_array[i]} --no-headers --ignore-not-found -n $CP4BA_OPERATOR_NS -o 'jsonpath={.status.currentCSV}') >&3 2>&3
                installed_version=$(${CLI_CMD} get subscription.operators.coreos.com ${sub_array[i]} --no-headers --ignore-not-found -n $CP4BA_OPERATOR_NS -o 'jsonpath={.status.installedCSV}') >&3 2>&3
                if [[ -z $current_version || -z $installed_version ]]; then
                    error "Failed to retrieve the installed or current CSV. Aborting the upgrade procedure. Check the subscription status of ${sub_array[i]}."
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
            fail "Subscription '${sub_array[i]}' not found! Exiting now..."
            exit 1
        fi
    done

    # Creating savepoints based on if BAI is selected or not
    if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") || $bai_flag == "true" ]]; then
        # Create BAI save points ONLY if it is a n-1 to n upgrade ( NOT an IFIX to IFIX upgrade)
        if [[ "$is_ifix_to_ifix_upgrade" == "false" ]]; then
            info "Since BAI has been selected as an optional component, the script will now start to generate BAI savepoints"
            create_bai_savepoints "$CP4BA_SERVICES_NS" "$top_level_cr_details_location" "$top_level_cr_details_backup_location"
        fi
    else
        echo
    fi
    ############## End - Decide whether to create savepoint for Flink job ##############

    ############## Start - Migration CPfs mode and upgrade CP4BA Operators ##############
    if [[ "$PLATFORM_SELECTED" == "other" ]]; then
        [ -f ${UPGRADE_DEPLOYMENT_FOLDER}/upgradeOperator.yaml ] && rm ${UPGRADE_DEPLOYMENT_FOLDER}/upgradeOperator.yaml
        cp ${CUR_DIR}/../descriptors/operator.yaml ${UPGRADE_DEPLOYMENT_FOLDER}/upgradeOperator.yaml
        cncf_install
        
        # DBACLD-168537: need to re-create {{meta.name}}-fncm-custom-ssl-secret to add CSS DNSName (in case they are missing from previous deployment) which will be included in Content Cortex's keystores
        cr_name=$(${CLI_CMD} get icp4acluster -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found | awk '{print $1}')
        if [[ -z $cr_name ]]; then
            cr_name=$(${CLI_CMD} get content -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found | awk '{print $1}')
        fi
        local fncm_custom_ssl_secret=$(${CLI_CMD} get secret --no-headers --ignore-not-found ${cr_name}-fncm-custom-ssl-secret -n $CP4BA_SERVICES_NS | awk '{print $1}') 
        if [[ -z $fncm_custom_ssl_secret ]]; then
            info "${cr_name}-fncm-custom-ssl-secret is not found."
        else
            info "Found ${cr_name}-fncm-custom-ssl-secret and the script will now delete the secret."
            ${CLI_CMD} delete secret ${cr_name}-fncm-custom-ssl-secret -n $CP4BA_SERVICES_NS
        fi
        # DBACLD-178263: need to re-create {{meta.name}}-ban-custom-ssl-secret to add localhost to Navigator's keystore
        local ban_custom_ssl_secret=$(${CLI_CMD} get secret --no-headers --ignore-not-found ${cr_name}-ban-custom-ssl-secret -n $CP4BA_SERVICES_NS | awk '{print $1}') 
        if [[ -z $ban_custom_ssl_secret ]]; then
            info "${cr_name}-ban-custom-ssl-secret is not found."
        else
            info "Found ${cr_name}-ban-custom-ssl-secret and the script will now delete the secret."
            ${CLI_CMD} delete secret ${cr_name}-ban-custom-ssl-secret -n $CP4BA_SERVICES_NS
        fi

    else
        #  Switch CP4BA Operator to private catalog source
        if [ $ENABLE_PRIVATE_CATALOG -eq 1 ]; then
            # switch CP4BA
            sub_inst_list=$(${CLI_CMD} get subscription.operators.coreos.com -n $CP4BA_OPERATOR_NS|grep ibm-cp4a-operator-catalog|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
            if [[ -z $sub_inst_list ]]; then
                info "No existing CP4BA subscriptions found, continuing ..."
                # exit 1
            fi

            sub_array=($sub_inst_list)
            for i in ${!sub_array[@]}; do
                if [[ ! -z "${sub_array[i]}" ]]; then
                    if [[ ${sub_array[i]} = ibm-cp4a-operator* || ${sub_array[i]} = ibm-cp4a-wfps-operator* || ${sub_array[i]} = ibm-content-operator* || ${sub_array[i]} = icp4a-foundation-operator* || ${sub_array[i]} = ibm-pfs-operator* || ${sub_array[i]} = ibm-ads-operator* || ${sub_array[i]} = ibm-dpe-operator* || ${sub_array[i]} = ibm-odm-operator* || ${sub_array[i]} = ibm-insights-engine-operator* || ${sub_array[i]} = ibm-workflow-operator* ]]; then
                        ${CLI_CMD} patch subscription.operators.coreos.com ${sub_array[i]} -n $CP4BA_OPERATOR_NS -p '{"spec":{"sourceNamespace":"'"$CP4BA_OPERATOR_NS"'"}}' --type=merge >&3 2>&3
                        if [ $? -eq 0 ]
                        then
                            sleep 1
                            success "Switched the CatalogSource of subscription '${sub_array[i]}' to project \"$CP4BA_OPERATOR_NS\"!"
                            printf "\n"
                        else
                            fail "Failed to switch the CatalogSource of subscription '${sub_array[i]}' to project \"$CP4BA_OPERATOR_NS\"!"
                        fi
                    fi
                else
                    fail "Subscription '${sub_array[i]}' not found in the project \"$CP4BA_OPERATOR_NS\"! Exiting now..."
                    exit 1
                fi
            done

        fi

        #  Patch CP4BA channel to latest version, wait for all the operators are upgraded before applying operandRequest.
        sub_inst_list=$(${CLI_CMD} get subscription.operators.coreos.com -n $CP4BA_OPERATOR_NS|grep ibm-cp4a-operator-catalog|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
        if [[ -z $sub_inst_list ]]; then
            info "No existing CP4BA subscriptions found, continuing..."
            # exit 1
        fi

        sub_array=($sub_inst_list)
        for i in ${!sub_array[@]}; do
            if [[ ! -z "${sub_array[i]}" ]]; then
                if [[ ${sub_array[i]} = ibm-cp4a-operator* || ${sub_array[i]} = ibm-cp4a-wfps-operator* || ${sub_array[i]} = ibm-content-operator* || ${sub_array[i]} = icp4a-foundation-operator* || ${sub_array[i]} = ibm-pfs-operator* || ${sub_array[i]} = ibm-ads-operator* || ${sub_array[i]} = ibm-dpe-operator* || ${sub_array[i]} = ibm-odm-operator* || ${sub_array[i]} = ibm-insights-engine-operator* || ${sub_array[i]} = ibm-workflow-operator* ]]; then

                    #DBACLD-189643: Retrieve existing CSV and save to UPGRADE_DEPLOYMENT_CSV_BAK before patching subscription to switch channel, which will trigger OLM to upgrade operators and delete existing CSVs. We need the backup CSVs to restore if anything goes wrong during the upgrade.
                    get_existing_csvs $CP4BA_OPERATOR_NS $UPGRADE_DEPLOYMENT_CSV_BAK ${sub_array[i]}
                    ${CLI_CMD} patch subscription.operators.coreos.com ${sub_array[i]} -n $CP4BA_OPERATOR_NS -p "{\"spec\":{\"channel\":\"$CP4BA_CHANNEL_VERSION\"}}" --type=merge >&3 2>&3
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
                fail "Subscription '${sub_array[i]}' not found! Exiting now..."
                exit 1
            fi
        done

        success "Completed to switch the channel of subscription for CP4BA operators"

        # Apply the new catalog source
        if [[ ($CATALOG_FOUND == "Yes" && $PINNED == "Yes") || $PRIVATE_CATALOG_FOUND == "Yes" ]]; then
            # switch catalog from "global" to "namespace" catalog or keep private catalog source
            if [ $ENABLE_PRIVATE_CATALOG -eq 1 ]; then
                TEMP_CATALOG_PROJECT_NAME=${CP4BA_OPERATOR_NS}
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
                    printf "\n"
                fi

                # Additionally, we would check if cs-control namespace exists.
                isProjExists=`${CLI_CMD} get project $DEDICATED_CS_PROJECT --no-headers --ignore-not-found | wc -l`  >&3 2>&3
                if [ $isProjExists -eq 1 ] ; then
                    # If it exists, we will deploy the same ibm-licensing-catalog into cs-control namespace.
                    if [[ $machine == "Linux" ]]; then
                        TMP_LICENSING_OLM_CATALOG=$(mktemp --suffix=.yaml)
                    elif [[ $machine == "Mac" ]]; then
                        TMP_LICENSING_OLM_CATALOG=$(mktemp -t licensing_olm_catalog).yaml
                    fi
                    start_num="# IBM License Manager"
                    end_num="interval: 45m"

                    reading_section=false

                    while IFS= read -r line; do
                        if [[ "$line" == *"$start_num"* ]]; then
                            reading_section=true
                        fi

                        if $reading_section; then
                            echo "$line" >> "$TMP_LICENSING_OLM_CATALOG"
                        fi

                        if [[ "$line" == *"$end_num"* ]]; then
                            reading_section=false
                        fi
                    done < "${OLM_CATALOG}"

                    # replace openshift-marketplace for ibm-licensing-catalog with cs-control
                    ${SED_COMMAND} "/name: ibm-licensing-catalog/{n;s/namespace: .*/namespace: \"$DEDICATED_CS_PROJECT\"/;}" ${TMP_LICENSING_OLM_CATALOG}

                    ${CLI_CMD} apply -f $TMP_LICENSING_OLM_CATALOG >&3 2>&3
                    if [ $? -eq 0 ]; then
                        echo "Create IBM License Manager Catalog source in project \"$DEDICATED_CS_PROJECT\"!"
                    else
                        echo "Generic Operator catalog source update failed"
                        exit 1
                    fi
                    rm -rf $TMP_LICENSING_OLM_CATALOG >/dev/null 2>&1
                fi

                sed "s/REPLACE_CATALOG_SOURCE_NAMESPACE/$CATALOG_NAMESPACE/g" ${OLM_CATALOG} > ${OLM_CATALOG_TMP}
                # replace all other catalogs with <CP4BA NS> namespaces
                ${SED_COMMAND} "s|namespace: .*|namespace: \"$CP4BA_OPERATOR_NS\"|g" ${OLM_CATALOG_TMP}
                # replace openshift-marketplace for ibm-cert-manager-catalog with ibm-cert-manager
                ${SED_COMMAND} "/name: ibm-cert-manager-catalog/{n;s/namespace: .*/namespace: $CERT_MANAGER_PROJECT/;}" ${OLM_CATALOG_TMP}
                # replace openshift-marketplace for ibm-licensing-catalog with ibm-licensing
                ${SED_COMMAND} "/name: ibm-licensing-catalog/{n;s/namespace: .*/namespace: $LICENSE_MANAGER_PROJECT/;}" ${OLM_CATALOG_TMP}

                # Record existing catalog sources before applying new ones for cleanup after upgrade
                CATALOG_BACKUP_FILE="${TEMP_FOLDER}/.pre_upgrade_catalog_sources"
                info "Recording existing catalog sources before upgrade..."
                ${CLI_CMD} get catalogsource -n "$CP4BA_OPERATOR_NS" --no-headers --ignore-not-found 2>/dev/null | awk '{print $1}' > "${CATALOG_BACKUP_FILE}.target"
                ${CLI_CMD} get catalogsource -n "$CERT_MANAGER_PROJECT" --no-headers --ignore-not-found 2>/dev/null | awk '{print $1}' > "${CATALOG_BACKUP_FILE}.cert"
                ${CLI_CMD} get catalogsource -n "$LICENSE_MANAGER_PROJECT" --no-headers --ignore-not-found 2>/dev/null | awk '{print $1}' > "${CATALOG_BACKUP_FILE}.license"
                # Save configuration for cleanup phase
                echo "ENABLE_PRIVATE_CATALOG_USED=1" > "$CATALOG_BACKUP_FILE"
                echo "CP4BA_OPERATOR_NS=\"$CP4BA_OPERATOR_NS\"" >> "$CATALOG_BACKUP_FILE"
                echo "CERT_MANAGER_PROJECT=\"$CERT_MANAGER_PROJECT\"" >> "$CATALOG_BACKUP_FILE"
                echo "LICENSE_MANAGER_PROJECT=\"$LICENSE_MANAGER_PROJECT\"" >> "$CATALOG_BACKUP_FILE"

                ${CLI_CMD} apply -f $OLM_CATALOG_TMP
                if [ $? -eq 0 ]; then
                    echo "IBM Operator Catalog source updated!"
                else
                    echo "Generic Operator catalog source update failed"
                    exit 1
                fi


            else
                TEMP_CATALOG_PROJECT_NAME="openshift-marketplace"

                # Record existing catalog sources before applying new ones for cleanup after upgrade
                CATALOG_BACKUP_FILE="${TEMP_FOLDER}/.pre_upgrade_catalog_sources"
                info "Recording existing catalog sources before upgrade..."
                ${CLI_CMD} get catalogsource -n "openshift-marketplace" --no-headers --ignore-not-found 2>/dev/null | awk '{print $1}' > "${CATALOG_BACKUP_FILE}.marketplace"
                # Save configuration for cleanup phase
                echo "ENABLE_PRIVATE_CATALOG_USED=0" > "$CATALOG_BACKUP_FILE"

                info "Apply latest CP4BA catalog source ..."
                OLM_CATALOG=${PARENT_DIR}/descriptors/op-olm/catalog_source.yaml
                ${CLI_CMD} apply -f $OLM_CATALOG >&3 2>&3
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
                fncm_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-content-cortex-operator-catalog -n $TEMP_CATALOG_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                # DBACLD-216925: Skip EDB catalog check for 26.0.0 GA, will be restored in 26.0.0-IF001 or later
                if ! skip_edb; then
                    postgresql_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=cloud-native-postgresql-catalog -n $TEMP_CATALOG_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                fi
                cs_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=$CS_CATALOG_VERSION -n $TEMP_CATALOG_PROJECT_NAME -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ $ENABLE_PRIVATE_CATALOG -eq 1 ]; then
                    cert_mgr_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-cert-manager-catalog -n $CERT_MANAGER_PROJECT -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    license_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-licensing-catalog -n $LICENSE_MANAGER_PROJECT -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                else
                    cert_mgr_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-cert-manager-catalog -n openshift-marketplace -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    license_catalog_pod_name=$(${CLI_CMD} get pod -l=olm.catalogSource=ibm-licensing-catalog -n openshift-marketplace -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                fi

                
                # DBACLD-222678: Build list of catalog pods to check based on skip_edb flag
                pods_to_check=(
                    "$cert_mgr_catalog_pod_name"
                    "$license_catalog_pod_name"
                    "$cs_catalog_pod_name"
                    "$cp4a_catalog_pod_name"
                    "$fncm_catalog_pod_name"
                )
                if ! skip_edb; then
                    pods_to_check+=("$postgresql_catalog_pod_name")
                fi
                
                # Check if all required catalog pods are ready
                all_ready=true
                for pod in "${pods_to_check[@]}"; do
                    if [[ -z "$pod" ]]; then
                        all_ready=false
                        break
                    fi
                done
                
                if [[ "$all_ready" == "false" ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                        printf "\n"
                        if [[ -z $cp4a_catalog_pod_name ]]; then
                            warning "Timeout waiting for ibm-cp4a-operator-catalog catalog pod to be ready in the project \"$TEMP_CATALOG_PROJECT_NAME\""
                        elif [[ -z $fncm_catalog_pod_name ]]; then
                            warning "Timeout waiting for ibm-content-cortex-operator-catalog catalog pod to be ready in the project \"$TEMP_CATALOG_PROJECT_NAME\""
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
                        printf '%s' "..."
                        continue
                    fi
                else
                    success "CP4BA operator catalog pod ready in the project \"$TEMP_CATALOG_PROJECT_NAME\"!"
                    break
                fi
            done
        else
            fail "IBM Cloud Pak for Business Automation catalog source not found!"
            exit 1
        fi

        # Deploy IBM Redis Operator subscription if not already present
        info "Checking IBM Redis Operator subscription..."
        if ${CLI_CMD} get subscription ibm-redis-cp-operator-catalog-subscription -n $CP4BA_OPERATOR_NS >/dev/null 2>&1; then
            success "IBM Redis Operator subscription already exists"
        else
            info "Deploying IBM Redis Operator subscription..."
            REDIS_SUBSCRIPTION=${PARENT_DIR}/descriptors/op-olm/redis-subscription.yaml
            REDIS_SUBSCRIPTION_TMP=${TEMP_FOLDER}/.redis-subscription.yaml
            
            cp -rf ${REDIS_SUBSCRIPTION} ${REDIS_SUBSCRIPTION_TMP}
            ${SED_COMMAND} "s/REPLACE_NAMESPACE/$CP4BA_OPERATOR_NS/g" ${REDIS_SUBSCRIPTION_TMP}
            
            # Set correct sourceNamespace for private catalog (global catalog uses template default)
            if [[ $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
                ${SED_COMMAND} "s/sourceNamespace: .*/sourceNamespace: $CP4BA_OPERATOR_NS/g" ${REDIS_SUBSCRIPTION_TMP}
            fi
            
            ${CLI_CMD} apply -f ${REDIS_SUBSCRIPTION_TMP}
            if [ $? -eq 0 ]; then
                success "IBM Redis Operator subscription created successfully"
                
                # Wait for Redis operator CSV to be ready
                info "Waiting for IBM Redis Operator CSV to be ready..."
                maxRetry=60
                wait_time=5
                for ((retry=0;retry<=${maxRetry};retry++)); do
                    redis_csv=$(${CLI_CMD} get csv -n $CP4BA_OPERATOR_NS --no-headers --ignore-not-found 2>/dev/null | grep ibm-redis-cp | awk '{print $1}' | head -1)
                    if [[ ! -z "$redis_csv" ]]; then
                        redis_csv_status=$(${CLI_CMD} get csv $redis_csv -n $CP4BA_OPERATOR_NS -o jsonpath='{.status.phase}' 2>/dev/null)
                        if [[ "$redis_csv_status" == "Succeeded" ]]; then
                            success "IBM Redis Operator CSV $redis_csv is ready"
                            break
                        fi
                    fi
                    
                    if [[ $retry -eq ${maxRetry} ]]; then
                        warning "Timeout waiting for IBM Redis Operator CSV to be ready. You may need to check the subscription status manually."
                        break
                    else
                        # Check more frequently at first (5s), then slow down after 10 retries (10s)
                        if [[ $retry -gt 10 ]]; then
                            wait_time=10
                        fi
                        sleep $wait_time
                        printf '%s' "."
                    fi
                done
                echo ""  
            else
                warning "Failed to create IBM Redis Operator subscription. Redis deployment may not be available."
            fi
        fi

        # Upgrade CP4BA operator
        info "Starting to upgrade CP4BA operator"


        # Check ibm-bts-operator/cloud-native-postgresql already upgrade to latest version
        if [[ $UPGRADE_MODE == "dedicated2dedicated"  ]]; then
            cs_service_target_namespace="$CP4BA_OPERATOR_NS"
        elif [[ $UPGRADE_MODE == "shared2shared" || $UPGRADE_MODE == "shared2dedicated" ]]; then
            cs_service_target_namespace="ibm-common-services"
        fi


        ibm_bts_operator_ready="Yes"
        cloud_native_postgresql_ready="Yes"
        READY_FOR_DIRECT_UPGRADE="Yes"
        info "Prerequisite for upgrade passed, continue..."
        
        # # Sourcing the message.sh to use the displayUpgradeOperatorMessage
        source ${CUR_DIR}/helper/messages.sh $COMMON_SERVICES_SCRIPT_FOLDER
        
        # The previous condition was basically checking for any version newer than 22.0.2
        # It did it by listing each version newer than 22.0.2 and explicitly listing each of them
        # This would also need to be updated each release and instead it made sense to use the negation so that we never have to constantly update the conditon with the new version each release
        # This was the old condition
        ###### START of OLD CONDTION #####
        # elif [[ "$cp4a_operator_csv_version" == "23.2."* || "$cp4a_operator_csv_version" == "24.0."* || "$cp4a_operator_csv_version" == "24.1."* ]]; then
        ###### END of OLD CONDTION #####
        # For https://jsw.ibm.com/browse/DBACLD-186019
        if [[ "$cp4a_operator_csv_version" != "21.0."* || "$cp4a_operator_csv_version" != "22.2."* ]]; then
            info "Starting to upgrade IBM Cloud Pak foundational services to $CS_OPERATOR_VERSION"
            # Check if without option --enable-private-catalog, the catalog is in target project, set the private catalog as default.
            info "Checking ibm-cp4a-operator-catalog catalog source is global or private namespace scoped"
            if [[ $ENABLE_PRIVATE_CATALOG -eq 0 ]]; then
                if ${CLI_CMD} get catalogsource -n $CP4BA_OPERATOR_NS --no-headers --ignore-not-found | grep ibm-cp4a-operator-catalog >&3 2>&3; then
                    ENABLE_PRIVATE_CATALOG=1
                else
                    info "Not found ibm-cp4a-operator-catalog catalog source under target project \"$CP4BA_OPERATOR_NS\""
                fi
            fi
            # This is still a valid scenario in 24.0.0 upgrading to 24.0.1.
            if [[ $UPGRADE_MODE == "dedicated2dedicated" && $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
                # Additionally, we would check if cs-control namespace exists.
                isProjExists=`${CLI_CMD} get project $DEDICATED_CS_PROJECT --no-headers --ignore-not-found | wc -l`  >&3 2>&3
                if [ $isProjExists -eq 1 ] ; then
                    # If it exists, we will deploy the same ibm-licensing-catalog into cs-control namespace.
                    if [[ $machine == "Linux" ]]; then
                        TMP_LICENSING_OLM_CATALOG=$(mktemp --suffix=.yaml)
                    elif [[ $machine == "Mac" ]]; then
                        TMP_LICENSING_OLM_CATALOG=$(mktemp -t licensing_olm_catalog).yaml
                    fi
                    start_num="# IBM License Manager"
                    end_num="interval: 45m"

                    reading_section=false

                    while IFS= read -r line; do
                        if [[ "$line" == *"$start_num"* ]]; then
                            reading_section=true
                        fi

                        if $reading_section; then
                            echo "$line" >> "$TMP_LICENSING_OLM_CATALOG"
                        fi

                        if [[ "$line" == *"$end_num"* ]]; then
                            reading_section=false
                        fi
                    done < "${OLM_CATALOG}"

                    # replace openshift-marketplace for ibm-licensing-catalog with cs-control
                    ${SED_COMMAND} "/name: ibm-licensing-catalog/{n;s/namespace: .*/namespace: \"$DEDICATED_CS_PROJECT\"/;}" ${TMP_LICENSING_OLM_CATALOG}

                    ${CLI_CMD} apply -f $TMP_LICENSING_OLM_CATALOG >&3 2>&3
                    if [ $? -eq 0 ]; then
                        echo "Created IBM License Manager Catalog source in project \"$DEDICATED_CS_PROJECT\"!"
                    else
                        echo "Generic Operator catalog source update failed"
                        exit 1
                    fi
                    rm -rf $TMP_LICENSING_OLM_CATALOG >/dev/null 2>&1
                fi

                # Upgrading Cert-Manager and Licensing Service.
                # This command still valid when upgrading from 24.0.0 to 24.0.1
                msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --enable-private-catalog --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --enable-private-catalog --yq "$CPFS_YQ_PATH" -c $CERT_LICENSE_CHANNEL_VERSION
                if [ $? -ne 0 ]; then
                    TMP_MESSAGE="Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --enable-private-catalog --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                    # 
                    displayUpgradeOperatorMessage "$TMP_MESSAGE" $CP4BA_SERVICES_NS $cp4a_operator_csv_version
                    exit 1
                fi
                
                # switch catalog from GCN to private when it's seperation of duty.
                # Upgrading CPFS
                msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $CP4BA_OPERATOR_NS --services-namespace $CP4BA_SERVICES_NS --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --enable-private-catalog -v 1"
                $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $CP4BA_OPERATOR_NS --services-namespace $CP4BA_SERVICES_NS --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --enable-private-catalog -v 1
                if [ $? -ne 0 ]; then
                    TMP_MESSAGE="Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $CP4BA_OPERATOR_NS --services-namespace $CP4BA_SERVICES_NS --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION --enable-private-catalog -v 1"
                    
                    displayUpgradeOperatorMessage "$TMP_MESSAGE" $CP4BA_SERVICES_NS  $cp4a_operator_csv_version
                    exit 1
                fi
            # This is still a valid scenario in 24.0.0 upgrading to 24.0.1.
            # Why does the setup_singleton and setup_tennant looks the same w/ the above `if` condition?
            elif [[ $UPGRADE_MODE == "dedicated2dedicated" && $ENABLE_PRIVATE_CATALOG -eq 0 ]]; then
                # Upgrading Cert-Manager and Licensing Service
                msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq "$CPFS_YQ_PATH" -c $CERT_LICENSE_CHANNEL_VERSION
                if [ $? -ne 0 ]; then
                    TMP_MESSAGE="Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                    
                    displayUpgradeOperatorMessage "$TMP_MESSAGE" $CP4BA_SERVICES_NS $cp4a_operator_csv_version
                    exit 1
                fi
                

                # keep GCN catalog
                msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $CP4BA_OPERATOR_NS --services-namespace $CP4BA_SERVICES_NS --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1"
                $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $CP4BA_OPERATOR_NS --services-namespace $CP4BA_SERVICES_NS --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1
                if [ $? -ne 0 ]; then
                    TMP_MESSAGE= "Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $CP4BA_OPERATOR_NS --services-namespace $CP4BA_SERVICES_NS --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1"
                    
                    displayUpgradeOperatorMessage "$TMP_MESSAGE" $CP4BA_SERVICES_NS $cp4a_operator_csv_version
                    exit 1
                fi
            
            # This is still a valid scenario in 24.0.0 upgrading to 24.0.1.
            elif [[ $UPGRADE_MODE == "shared2shared" && $ALL_NAMESPACE_FLAG == "Yes" ]]; then
                # It is not recommended to install 23.0.2 in all namespace. but script keep coverage for it
                # Upgrading Cert-Manager and Licensing Service
                msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq "$CPFS_YQ_PATH" -c $CERT_LICENSE_CHANNEL_VERSION
                if [ $? -ne 0 ]; then
                    TMP_MESSAGE="Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                    
                    displayUpgradeOperatorMessage "$TMP_MESSAGE" $CP4BA_SERVICES_NS $cp4a_operator_csv_version
                    exit 1
                fi
                # workaround for https://github.ibm.com/IBMPrivateCloud/roadmap/issues/63676
                cs_namespace="ibm-common-services"
                info "Removing ibm-events-operator from the project \"$cs_namespace\"."
                ${CLI_CMD} delete csv -l operators.coreos.com/ibm-events-operator.$cs_namespace='' -n $cs_namespace >&3 2>&3
                if [ $? -eq 0 ]; then
                    success "Removed ibm-events-operator from the project \"$cs_namespace\"."
                else
                    fail "Faild to remove ibm-events-operator from the project \"$cs_namespace\"."
                fi
                # keep GCN catalog
                msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace openshift-operators --services-namespace ibm-common-services --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1"
                $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace openshift-operators --services-namespace ibm-common-services --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1
                if [ $? -ne 0 ]; then
                    TMP_MESSAGE="Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace openshift-operators --services-namespace ibm-common-services --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1"
                    
                    displayUpgradeOperatorMessage "$TMP_MESSAGE" $CP4BA_SERVICES_NS $cp4a_operator_csv_version
                    exit 1

                fi
            # This is not a valid scenario unless allow_direct_upgrade == 1
            elif [[ $UPGRADE_MODE == "shared2shared" && $ALL_NAMESPACE_FLAG == "No" && "$ALLOW_DIRECT_UPGRADE" == 1 ]]; then
                # Upgrading Cert-Manager and Licensing Service
                msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq "$CPFS_YQ_PATH" -c $CERT_LICENSE_CHANNEL_VERSION
                if [ $? -ne 0 ]; then
                    TMP_MESSAGE="Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_singleton.sh --license-accept --enable-licensing --yq \"$CPFS_YQ_PATH\" -c $CERT_LICENSE_CHANNEL_VERSION"
                    
                    displayUpgradeOperatorMessage "$TMP_MESSAGE" $CP4BA_SERVICES_NS $cp4a_operator_csv_version
                    exit 1
                fi
                # keep GCN catalog
                msg "All arguments passed into the CPfs script: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $CP4BA_OPERATOR_NS --services-namespace ibm-common-services --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1"
                $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $CP4BA_OPERATOR_NS --services-namespace ibm-common-services --yq "$CPFS_YQ_PATH" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1
                if [ $? -ne 0 ]; then
                    TMP_MESSAGE="Failed to execute command: $COMMON_SERVICES_SCRIPT_FOLDER/setup_tenant.sh --license-accept --enable-licensing --operator-namespace $CP4BA_OPERATOR_NS --services-namespace ibm-common-services --yq \"$CPFS_YQ_PATH\" -c $CS_CHANNEL_VERSION -s $CS_CATALOG_VERSION -v 1"
                    
                    displayUpgradeOperatorMessage "$TMP_MESSAGE" $CP4BA_SERVICES_NS $cp4a_operator_csv_version
                    exit 1
                fi
            fi
        fi

        # Check IBM Cloud Pak foundational services Operator $CS_OPERATOR_VERSION
        maxRetry=30
        echo "****************************************************************************"
        info "Checking for IBM Cloud Pak foundational operator pod initialization"
        for ((retry=0;retry<=${maxRetry};retry++)); do
            isReady=$(${CLI_CMD} get csv ibm-common-service-operator.$CS_OPERATOR_VERSION --no-headers --ignore-not-found -n $CP4BA_OPERATOR_NS -o jsonpath='{.status.phase}')
            # isReady=$(${CLI_CMD} exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $upgrade_operator_project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine $CP4BA_RELEASE_BASE")
            if [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM Cloud Pak foundational operator to start"
                printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $CP4BA_OPERATOR_NS|grep ibm-common-service-operator|awk '{print $1}') -n $CP4BA_OPERATOR_NS"
                printf "\n"
                printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $CP4BA_OPERATOR_NS|grep ibm-common-service-operator|awk '{print $1}') -n $CP4BA_OPERATOR_NS"
                printf "\n"
                exit 1
                else
                sleep 30
                printf '%s' "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                pod_name=$(${CLI_CMD} get pod -l=name=ibm-common-service-operator -n $CP4BA_OPERATOR_NS -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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

        # Checking CP4BA operator CSV
        # change this value for $CP4BA_RELEASE_BASE-IFIX
        sub_inst_list=$(${CLI_CMD} get subscription.operators.coreos.com -n $CP4BA_OPERATOR_NS|grep ibm-cp4a-operator-catalog|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
        if [[ -z $sub_inst_list ]]; then
            fail "No existing CP4BA subscriptions (version $CP4BA_CSV_VERSION) found! Exiting ..."
            exit 1
        fi
        sub_array=($sub_inst_list)
        target_csv_version=${CP4BA_CSV_VERSION//v/}
        for i in ${!sub_array[@]}; do
            if [[ ! -z "${sub_array[i]}" ]]; then
                if [[ ${sub_array[i]} = ibm-cp4a-operator* || ${sub_array[i]} = ibm-cp4a-wfps-operator* || ${sub_array[i]} = ibm-content-operator* || ${sub_array[i]} = icp4a-foundation-operator* || ${sub_array[i]} = ibm-pfs-operator* || ${sub_array[i]} = ibm-ads-operator* || ${sub_array[i]} = ibm-dpe-operator* || ${sub_array[i]} = ibm-odm-operator* || ${sub_array[i]} = ibm-insights-engine-operator* || ${sub_array[i]} = ibm-workflow-operator* ]]; then
                    info "Checking the channel of subscription '${sub_array[i]}'!"
                    currentChannel=$(${CLI_CMD} get subscription.operators.coreos.com ${sub_array[i]} -n $CP4BA_OPERATOR_NS -o 'jsonpath={.spec.channel}') >&3 2>&3
                    if [[ "$currentChannel" == "$CP4BA_CHANNEL_VERSION" ]]
                    then
                        success "The channel of subscription '${sub_array[i]}' is $currentChannel!"
                        printf "\n"
                        maxRetry=40
                        info "Waiting for the \"${sub_array[i]}\" subscription be upgraded to the ClusterServiceVersions(CSV) \"v$target_csv_version\""
                        for ((retry=0;retry<=${maxRetry};retry++)); do
                            current_version=$(${CLI_CMD} get subscription.operators.coreos.com ${sub_array[i]} --no-headers --ignore-not-found -n $CP4BA_OPERATOR_NS -o 'jsonpath={.status.currentCSV}') >&3 2>&3
                            installed_version=$(${CLI_CMD} get subscription.operators.coreos.com ${sub_array[i]} --no-headers --ignore-not-found -n $CP4BA_OPERATOR_NS -o 'jsonpath={.status.installedCSV}') >&3 2>&3
                            if [[ -z $current_version || -z $installed_version ]]; then
                                error "Failed to retrieve installed or current CSV. Aborting the upgrade procedure. Check the subscription status of ${sub_array[i]}."
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
                                approval_mode=$(${CLI_CMD} get subscription.operators.coreos.com ${sub_array[i]} --no-headers --ignore-not-found -n $CP4BA_OPERATOR_NS -o jsonpath={.spec.installPlanApproval})
                                if [[ $approval_mode == "Manual" ]]; then
                                    error "${sub_array[i]} subscription is set to Manual Approval mode. Approve the installPlan to proceed with the upgrade."
                                    exit 1
                                fi
                                if [[ $retry -eq ${maxRetry} ]]; then
                                    warning "Timeout waiting for upgrading \"${sub_array[i]}\" subscription from ${installed_version} to ${target_csv_version} in the project \"$CP4BA_OPERATOR_NS\""
                                    break
                                else
                                    sleep 10
                                    printf '%s' "..."
                                    continue
                                fi
                            else
                                success "ClusterServiceVersions ${installed_version} is now the latest available version in ${currentChannel} channel."
                                break
                            fi
                        done

                    else
                        fail "Failed to update the channel of subscription '${sub_array[i]}' to $CP4BA_CHANNEL_VERSION! Exiting now..."
                        exit 1
                    fi
                fi
            else
                fail "No subscription found for '${sub_array[i]}'! Exiting now..."
                exit 1
            fi
        done

        # Function to install the ibm usage metering operator or upgrading it if applicable
        # The below Function handles all the usage metering operator related tasks
        # The functions first two arguments are the namespace details
        # The function will also be called during fresh install and hence has a mode argument i.e argument 3
        # The function does take a 4th argument i.e the entitlement key but for upgrade scenario we do not ask for the entitlement key anywhere , so th script will retrieve it.
        # The 5th argument is flag to see if it is a dev mode or not. Internal testing might be done using the dev flag and if that case the sandbox parameter has to be added.
        # The 6th flag is to detect the catalog namespace ( handles the global catalog scenario)    
        # The 7th flag is to tell the script if the deployment is airgap based or not 
        # https://jsw.ibm.com/browse/DBACLD-216413
        install_ibm_usage_metering "$CP4BA_OPERATOR_NS" "$CP4BA_SERVICES_NS" "upgrade" "" "$SCRIPT_MODE" "$TEMP_CATALOG_PROJECT_NAME" "$AIRGAP_INSTALL"


        # Configure Software Central integration for an existing IBMLicensing resource.
        #
        # Flow:
        #   1. Check whether an IBMLicensing resource exists.
        #   2. If no IBMLicensing resource exists, skip the configuration.
        #   3. Check whether the ILS connection point secret already exists.
        #   4. If the secret does not exist:
        #      - use the provided entitlement key if available
        #      - otherwise, for upgrade scenario only, try to retrieve it from ibm-entitlement-key
        #      - if no entitlement key can be obtained, skip secret creation and CR patching ( this would only happen for airgap scenario)
        #      - if entitlement key is available, create the secret
        #   5. Patch the IBMLicensing resource to enable Software Central uploads.
        #   6. In dev mode, also set sandbox=true.
        #
        # Arguments:
        #   $1 - namespace where the ILS connection point secret should exist
        #   $2 - services namespace where ibm-entitlement-key may exist
        #   $3 - entitlement key value; may be empty during upgrade
        #   $4 - scenario value such as "upgrade" or "fresh_install"
        #   $5 - runtime mode such as "dev" or "prod"
        # ILS set up is only required for online/ non-airgap scenarios
        if [[ "$AIRGAP_INSTALL" == "no" ]]; then
            setup_ils_configuration_for_vpc_metrics "ibm-licensing" "$CP4BA_SERVICES_NS" "" "upgrade" "$SCRIPT_MODE"
        fi

        success "Completed to check the channel of subscription for CP4BA operators"

        # Cleanup old catalog sources after operator upgrade completes successfully
        # This removes old catalog sources that were replaced during the operator upgrade
        CATALOG_BACKUP_FILE="${TEMP_FOLDER}/.pre_upgrade_catalog_sources"
        if [[ -f "$CATALOG_BACKUP_FILE" ]]; then
            info "Checking for old catalog sources to cleanup after operator upgrade..."
            
            # Load the saved catalog configuration
            source "$CATALOG_BACKUP_FILE"
            
            # Cleanup catalog sources based on the upgrade mode
            if [[ "$ENABLE_PRIVATE_CATALOG_USED" -eq 1 ]]; then
                # Cleanup in private catalog mode (namespace-scoped)
                for CLEANUP_NAMESPACE in "$CP4BA_OPERATOR_NS" "$CERT_MANAGER_PROJECT" "$LICENSE_MANAGER_PROJECT"; do
                    if [[ "$CLEANUP_NAMESPACE" == "$CP4BA_OPERATOR_NS" ]]; then
                        CLEANUP_BACKUP_FILE="${CATALOG_BACKUP_FILE}.target"
                    elif [[ "$CLEANUP_NAMESPACE" == "$CERT_MANAGER_PROJECT" ]]; then
                        CLEANUP_BACKUP_FILE="${CATALOG_BACKUP_FILE}.cert"
                    else
                        CLEANUP_BACKUP_FILE="${CATALOG_BACKUP_FILE}.license"
                    fi
                    
                    if [[ -f "$CLEANUP_BACKUP_FILE" ]]; then
                        # Get current catalog sources in this namespace
                        current_catalogs=$(${CLI_CMD} get catalogsource -n "$CLEANUP_NAMESPACE" --no-headers --ignore-not-found 2>/dev/null | awk '{print $1}')
                        
                        # Read old catalog sources from backup and process each one
                        while IFS= read -r old_catalog; do
                            if [[ -z "$old_catalog" ]]; then
                                continue
                            fi
                            
                            # Check if this old catalog still exists
                            if echo "$current_catalogs" | grep -q "^${old_catalog}$"; then
                                # Extract base name by removing version suffix
                                base_name=$(echo "$old_catalog" | sed -E 's/-v?[0-9]+(-[0-9]+)*$//')
                                
                                # Check if there's a newer catalog with the same base name
                                newer_exists=false
                                for current_catalog in $current_catalogs; do
                                    current_base=$(echo "$current_catalog" | sed -E 's/-v?[0-9]+(-[0-9]+)*$//')
                                    if [[ "$base_name" == "$current_base" && "$old_catalog" != "$current_catalog" ]]; then
                                        newer_exists=true
                                        break
                                    fi
                                done
                                
                                # If a newer version exists, delete the old one
                                if [[ "$newer_exists" == "true" ]]; then
                                    info "Deleting old catalog source: $old_catalog from namespace: $CLEANUP_NAMESPACE"
                                    ${CLI_CMD} delete catalogsource "$old_catalog" -n "$CLEANUP_NAMESPACE" --ignore-not-found >&3 2>&3
                                    if [ $? -eq 0 ]; then
                                        success "Deleted old catalog source: $old_catalog"
                                    else
                                        warning "Failed to delete old catalog source: $old_catalog"
                                    fi
                                fi
                            fi
                        done < "$CLEANUP_BACKUP_FILE"
                    fi
                done
            else
                # Cleanup in global catalog mode (openshift-marketplace)
                CLEANUP_NAMESPACE="openshift-marketplace"
                CLEANUP_BACKUP_FILE="${CATALOG_BACKUP_FILE}.marketplace"
                
                if [[ -f "$CLEANUP_BACKUP_FILE" ]]; then
                    # Get current catalog sources in openshift-marketplace
                    current_catalogs=$(${CLI_CMD} get catalogsource -n "$CLEANUP_NAMESPACE" --no-headers --ignore-not-found 2>/dev/null | awk '{print $1}')
                    
                    # Read old catalog sources from backup and process each one
                    while IFS= read -r old_catalog; do
                        if [[ -z "$old_catalog" ]]; then
                            continue
                        fi
                        
                        # Check if this old catalog still exists
                        if echo "$current_catalogs" | grep -q "^${old_catalog}$"; then
                            # Extract base name by removing version suffix
                            base_name=$(echo "$old_catalog" | sed -E 's/-v?[0-9]+(-[0-9]+)*$//')
                            
                            # Check if there's a newer catalog with the same base name
                            newer_exists=false
                            for current_catalog in $current_catalogs; do
                                current_base=$(echo "$current_catalog" | sed -E 's/-v?[0-9]+(-[0-9]+)*$//')
                                if [[ "$base_name" == "$current_base" && "$old_catalog" != "$current_catalog" ]]; then
                                    newer_exists=true
                                    break
                                fi
                            done
                            
                            # If a newer version exists, delete the old one
                            if [[ "$newer_exists" == "true" ]]; then
                                info "Deleting old catalog source: $old_catalog from namespace: $CLEANUP_NAMESPACE"
                                ${CLI_CMD} delete catalogsource "$old_catalog" -n "$CLEANUP_NAMESPACE" --ignore-not-found >&3 2>&3
                                if [ $? -eq 0 ]; then
                                    success "Deleted old catalog source: $old_catalog"
                                else
                                    warning "Failed to delete old catalog source: $old_catalog"
                                fi
                            fi
                        fi
                    done < "$CLEANUP_BACKUP_FILE"
                fi
            fi
            
            # Clean up backup files
            rm -f "${CATALOG_BACKUP_FILE}" "${CATALOG_BACKUP_FILE}."* >/dev/null 2>&1
            
            success "Completed cleanup of old catalog sources"
        fi

        # DBACLD-166239 -> Update EDB configmap ibm-zen-metastore-edb-cm to add new parameters with CPFS 4.10 or later by calling patch_edb_configmap()
        patch_edb_configmap $CP4BA_SERVICES_NS

        # DBACLD-168537: need to re-create {{meta.name}}-fncm-custom-ssl-secret to add CSS DNSName (in case they are missing from previous deployment) which will be included in Content Cortex's keystores
        cr_name=$(${CLI_CMD} get icp4acluster -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found | awk '{print $1}')
        if [[ -z $cr_name ]]; then
            cr_name=$(${CLI_CMD} get content -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found | awk '{print $1}')
        fi
        fncm_custom_ssl_secret=$(${CLI_CMD} get secret --no-headers --ignore-not-found ${cr_name}-fncm-custom-ssl-secret -n $CP4BA_SERVICES_NS | awk '{print $1}') 
        if [[ -z $fncm_custom_ssl_secret ]]; then
            info "${cr_name}-fncm-custom-ssl-secret is not found."
        else
            info "Found ${cr_name}-fncm-custom-ssl-secret and the script will now delete the secret."
            ${CLI_CMD} delete secret ${cr_name}-fncm-custom-ssl-secret -n $CP4BA_SERVICES_NS
        fi
        # DBACLD-178263: need to re-create {{meta.name}}-ban-custom-ssl-secret to add localhost to Navigator's keystore
        ban_custom_ssl_secret=$(${CLI_CMD} get secret --no-headers --ignore-not-found ${cr_name}-ban-custom-ssl-secret -n $CP4BA_SERVICES_NS | awk '{print $1}') 
        if [[ -z $ban_custom_ssl_secret ]]; then
            info "${cr_name}-ban-custom-ssl-secret is not found."
        else
            info "Found ${cr_name}-ban-custom-ssl-secret and the script will now delete the secret."
            ${CLI_CMD} delete secret ${cr_name}-ban-custom-ssl-secret -n $CP4BA_SERVICES_NS
        fi
        
        # Patch the BTS datastore secret and CM if required
        # The secret keys have to tls.pk8 as the the client key cert is added in the secret in Pk8 format. If it is tls.key ,BTS expects it to be a PEM format key
        # https://jsw.ibm.com/browse/DBACLD-238245 and https://jsw.ibm.com/browse/DBACLD-238566
        update_bts_datastore_resources "$CP4BA_SERVICES_NS"
        
        
        #DBACLD-189643: Patching new CSV with CSI (Vault) mount by reading the old CSV to get the existing CSI (Vault) related configurations if there is any, and apply them to the new CSV. This is to make sure the new CSV will have the same CSI (Vault) related configurations as old CSV so that the upgrade can be successful without any disruption to the Vault service.
        # Determine if Vault is enabled by reading the saved CR (UPGRADE_DEPLOYMENT_CONTENT_CR_TMP or UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP )
        is_vault_enabled="false"
        cr_to_check=""
        if [[ -f $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP ]]; then
            cr_to_check=$UPGRADE_DEPLOYMENT_CONTENT_CR_TMP
        elif [[ -f $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP ]]; then
            cr_to_check=$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP
        fi
        info "Checking if Vault is enabled by reading the existing CRs ($cr_to_check) to get the value of spec.shared_configuration.sc_vault_configuration.enable_external_secret_store parameter."
        if [[ -n "$cr_to_check" ]]; then
            is_vault_enabled=$(${YQ_CMD} ".spec.shared_configuration.sc_vault_configuration.enable_external_secret_store" "$cr_to_check" | tr '[:upper:]' '[:lower:]')
            is_vault_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$is_vault_enabled")
        else
            warning "No existing CR found to check the value of spec.shared_configuration.sc_vault_configuration.enable_external_secret_store parameter. The script will assume Vault is not enabled and continue with the upgrade process. If Vault is actually enabled in your environment, please make sure to back up your existing CRs and manually check the value of spec.shared_configuration.sc_vault_configuration.enable_external_secret_store parameter. If it's set to true, please make sure to apply the same configuration to the new CSV after the upgrade to avoid any disruption to the Vault service."
        fi
        info "The value of spec.shared_configuration.sc_vault_configuration.enable_external_secret_store parameter is: $is_vault_enabled"
        # End of patching new CSV with CSI (Vault) mount for DBACLD-189643
        # shutdown CP4BA operators and show tips for [NEXT ACTION]
        if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "$CP4BA_RELEASE_BASE_MAJOR_VERSION"*) ]]; then
            #DBACLD-189643: If Vault is able calling cp4a-vault -n ns --operatorNamespace ns -m upgrade to copy the existing Vault related configurations from old CSV to new CSV, and then shutdown CP4BA operators for upgrade.
            if [[ "$is_vault_enabled" == "true" ]]; then
                info "Vault is enabled. The script will now call cp4a-vault script with -m upgrade mode to copy the existing Vault related configurations from old CSV to new CSV before shutting down CP4BA operators for upgrade."
                ./cp4a-vault.sh -n $CP4BA_SERVICES_NS --operatorNamespace $CP4BA_OPERATOR_NS -m upgrade
                if [ $? -ne 0 ]; then
                    fail "Failed to execute command: ./cp4a-vault.sh -n $CP4BA_SERVICES_NS --operatorNamespace $CP4BA_OPERATOR_NS -m upgrade"
                    exit 1
                fi
            fi
            
            info "Shutdown CP4BA Operators before upgrade CP4BA capabilities."
            shutdown_operator $CP4BA_OPERATOR_NS
            printf "\n"
            if [[ $CONTENT_CR_EXIST == "Yes" || (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (! " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service")) || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
                if [[ $UPGRADE_MODE == "shared2dedicated" ]]; then
                    printf '%b\n' "\x1B[33;5m[ATTENTION]: \x1B[0m${RED_TEXT}You DO NOT need to run \"./cp4a-pre-upgrade-and-post-upgrade-optional.sh\" in \"pre-upgrade\" mode when migrate IBM Cloud Pak foundational services from \"Cluster-scoped\" to \"Namespace-scoped\"!${RESET_TEXT}"
                    # For API calls this question will be skipped and we will just execute the script
                    if [[ "$SKIP_FOR_API" != "true" ]]; then
                        prompt_press_any_key_to_continue
                    fi
                fi
            fi
            printf "\n"
            ## -- https://jsw.ibm.com/browse/DBACLD-174848 - <To fix the incorrect script path while running the deployment script in the upgrade mode>
            CUR_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
            echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}"
            echo "${YELLOW_TEXT}  - All CP4BA operators have already been shut down by the script.${RESET_TEXT}"
            echo "${YELLOW_TEXT}  - All CP4BA operators will start up automatically when running [upgradeDeploymentStatus] mode of the cp4a-deployment.sh script.${RESET_TEXT}"
            printf "\n"
            echo "${YELLOW_TEXT}[NEXT ACTIONS]:${RESET_TEXT}"
            step_num=1
            echo "  - STEP ${step_num} ${YELLOW_TEXT}(Optional)${RESET_TEXT}: You can run ${GREEN_TEXT}\"${CUR_DIR}/cp4a-deployment.sh -m upgradeOperatorStatus -n $CP4BA_SERVICES_NS\"${RESET_TEXT} to check whether the upgrade of the CP4BA operator and its dependencies is successful."
            step_num=$((step_num + 1))

            if [[ $css_flag == "true" || " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "css" ]]; then
                echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You have Content Search Services (CSS) installed. Make sure you stop the IBM Content Search Services index dispatcher. Refer to the FileNet P8 Platform Documentation for more details."
                echo "    ${YELLOW_TEXT}* Stopping the IBM Content Search Services index dispatcher.${RESET_TEXT}"
                echo "      1. Log in to the Administration Console for Content Platform Engine."
                echo "      2. In the navigation pane, select the domain icon."
                echo "      3. In the edit pane, click the Text Search Subsystem tab and clear the Enable indexing check box."
                echo "      4. Click Save to apply your changes."
                step_num=$((step_num + 1))
            fi
            echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You need to run ${GREEN_TEXT}\"${CUR_DIR}/cp4a-deployment.sh -m upgradeDeployment -n $CP4BA_SERVICES_NS\"${RESET_TEXT} to upgrade CP4BA deployment."
            echo "    ${RED_TEXT}[ATTENTION]: ${RESET_TEXT}${YELLOW_TEXT}When you run the [upgradeDeployment] mode of the cp4a-deployment.sh script, the updated custom resource (CR) must be manually applied that all required additional actions can be completed before the upgrade process begins. Refer to the Knowledge Center: \"Updating the custom resource for each capability in your deployment\" topic to complete the REQUIRED steps for the installed pattern(s).${RESET_TEXT}"
            step_num=$((step_num + 1))
            echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You can run ${GREEN_TEXT}\"${CUR_DIR}/cp4a-deployment.sh -m upgradeDeploymentStatus -n $CP4BA_SERVICES_NS\"${RESET_TEXT} to check whether the upgrade of the CP4BA deployment was successful."
        else
            # for upgrading IFIX by IFIX
	    ## -- https://jsw.ibm.com/browse/DBACLD-186607 - <To fix the incorrect script path while running the deployment script in the upgrade mode>
            CUR_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
            printf "\n"
            echo "${YELLOW_TEXT}[NEXT ACTIONS]:${RESET_TEXT}"
            step_num=1
            echo "  - STEP ${step_num} ${YELLOW_TEXT}(Optional)${RESET_TEXT}: You can run ${GREEN_TEXT}\"${CUR_DIR}/cp4a-deployment.sh -m upgradeOperatorStatus -n $CP4BA_SERVICES_NS\"${RESET_TEXT} to check whether the upgrade of the CP4BA operator and its dependencies was successful."
            printf "\n"
            step_num=$((step_num + 1))
            echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You can run ${GREEN_TEXT}\"${CUR_DIR}/cp4a-deployment.sh -m upgradeDeploymentStatus -n $CP4BA_SERVICES_NS\"${RESET_TEXT} to check whether the upgrade of the CP4BA deployment was successful."
        fi
    fi
    #DBACLD-198803: Display message to inform customer if they migrated from global catalog to private catalog they may remove the old/global catalog in the openshift-marketplace namespace.
    #PRIVATE_CATALOG_FOUND is set to "No" when we found the cataloge source in the openshift-marketplace namespace.
    if [[ $ENABLE_PRIVATE_CATALOG -eq 1 && ($UPGRADE_MODE == "shared2dedicated" || $UPGRADE_MODE == "dedicated2dedicated") && $PRIVATE_CATALOG_FOUND == "No" ]]; then
        printf "\n"
        echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}"
        echo "${YELLOW_TEXT}  - If you have migrated from global catalog namespace (GCN) to private catalog namespace (namespaced-scope) for IBM Cloud Pak Business Automation, you may remove the old global catalog source in the \"openshift-marketplace\" namespace to avoid confusion.${RESET_TEXT}"
        echo "${YELLOW_TEXT}  - Be sure to check that there are no other deployments using the old global catalog in the openshift-marketplace namespace before removing them.${RESET_TEXT}"
        printf "\n"
    fi
fi
############## End - Migration CPfs mode and upgrade CP4BA Operators ##############

if [ "$RUNTIME_MODE" == "upgradeOperatorStatus" ]; then
    project_name=$TARGET_PROJECT_NAME


    # Check whether the CP4BA is separation of operators and operands.
    # We want to check this first as from this defect we will be requesting the operand namespace to be passed in for -n argument
    # Once we can detect the SOD scenario we will use CP4BA_SERVICES_NS for the namespace where operands are deployed and CP4BA_OPERATOR_NS for the namespace where operators are deployed
    check_cp4ba_separate_operand $TARGET_PROJECT_NAME

    UPGRADE_DEPLOYMENT_FOLDER=${CUR_DIR}/cp4ba-upgrade/project/$CP4BA_SERVICES_NS
    UPGRADE_DEPLOYMENT_CR=${UPGRADE_DEPLOYMENT_FOLDER}/custom_resource
    UPGRADE_DEPLOYMENT_CONTENT_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.content_tmp.yaml
    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.icp4acluster_tmp.yaml
    mkdir -p $UPGRADE_DEPLOYMENT_CR >&3 2>&3


    source ${CUR_DIR}/helper/upgrade/upgrade_merge_yaml.sh $CP4BA_SERVICES_NS $ALLOW_DIRECT_UPGRADE

    # There is no need to detect for all namespaces deployment, instead the script will execute and set the flag it would set when all namespaces was not detected
    success "The IBM Cloud Pak for Business Automation Operator was found deployed in the project \"$CP4BA_OPERATOR_NS\"."
    ALL_NAMESPACE_FLAG="No"

    

    # Get value of cp4ba_original_csv_ver_for_upgrade_script, for upgrade script to know the original version of CP4BA.
    ibm_cp4ba_shared_info_cm=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS)
    ibm_cp4ba_content_shared_info_cm=$(${CLI_CMD} get configmap ibm-cp4ba-content-shared-info --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS)
    if [[ ! -z $ibm_cp4ba_shared_info_cm ]]; then
        tmp_csv_val=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info -n $CP4BA_SERVICES_NS -o jsonpath='{.data.cp4ba_original_csv_ver_for_upgrade_script}')
        if [[ ! -z $tmp_csv_val ]]; then
            cp4ba_original_csv_ver_for_upgrade_script=$tmp_csv_val
        fi
    fi
        
    if [[ ! -z $ibm_cp4ba_content_shared_info_cm ]]; then
        tmp_csv_val=$(${CLI_CMD} get configmap ibm-cp4ba-content-shared-info -n $CP4BA_SERVICES_NS -o jsonpath='{.data.cp4ba_original_csv_ver_for_upgrade_script}')
        if [[ ! -z $tmp_csv_val ]]; then
            cp4ba_original_csv_ver_for_upgrade_script=$tmp_csv_val
        fi
    fi

    # Retrieve CR details
    # This function is defined in the common.sh script and the function find the top level CR kind and name
    # Top level CR kind and name are stored in the variables top_level_cr_type and top_level_cr_name
    # The function also stores the name of the icp4acluster and content CR names in the variables icp4acluster_cr_name,content_cr_name
    # The function also reads the CR details for both CR kinds if present and stores the CR details in "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP" "$UPGRADE_DEPLOYMENT_CONTENT_CR_TMP"
    # The top level CR details is stored in the file top_level_cr_details_location
    # FUNCTION HAS TO BE CALLED AFTER THE ABOVE VARIABLE DEFINITION
    # From this point on in the script we should attempt to re-use these variables
    retrieve_custom_resource_details "$CP4BA_SERVICES_NS" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP" "$UPGRADE_DEPLOYMENT_CONTENT_CR_TMP"

    
    # Instead of checking if a crd type content is present and then checking if it is a top level CR and then taking the CR details,
    # we can just use the variables loaded by the retrieve_custom_resource_details function which does all this at the start of each mode
    if [[ "$top_level_cr_kind" == "content" ]]; then
        bai_flag=`${YQ_CMD} ".spec.content_optional_components.bai" "$top_level_cr_details_location"`
        bai_flag=$(echo "$bai_flag" | tr '[:upper:]' '[:lower:]')
        CONTENT_CR_EXIST="Yes"
        cp4ba_root_ca_secret_name=`${YQ_CMD} ".spec.shared_configuration.root_ca_secret" "$top_level_cr_details_location"`
    
    elif [[ "$top_level_cr_kind" == "icp4acluster" ]]; then
        cp4ba_root_ca_secret_name=`${YQ_CMD} ".spec.shared_configuration.root_ca_secret" "$top_level_cr_details_location"`
        convert_olm_cr "${top_level_cr_details_location}"
        if [[ $olm_cr_flag == "No" ]]; then
            # Get EXISTING_PATTERN_ARR/EXISTING_OPT_COMPONENT_ARR
            existing_pattern_list=""
            existing_opt_component_list=""
            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_patterns" "$top_level_cr_details_location"`
            existing_opt_component_list=`${YQ_CMD} ".spec.shared_configuration.sc_optional_components" "$top_level_cr_details_location"`

            OIFS=$IFS
            IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
            IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
            IFS=$OIFS
        fi
    
    else
        fail "No top level CP4BA custom resource found on this cluster in the project \"$CP4BA_SERVICES_NS\"."
        exit 1
    fi

    info "Checking if the CP4BA operators have been upgraded..."
    #verify whether the upgrade process for the operators is complete, the script verifies the current status of the operators before proceeding.
    check_operator_status $CP4BA_OPERATOR_NS "full" "channel"
    if [[ " ${CHECK_CP4BA_OPERATOR_RESULT[@]} " =~ "FAIL" ]]; then
        fail "Failed to upgrade CP4BA operators"
    else
        success "CP4BA operators upgraded successfully!"
        if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "$CP4BA_RELEASE_BASE_MAJOR_VERSION"*) ]]; then
            info "All CP4BA operators will be shut down before upgrading Zen/IM/CP4BA capabilities!"
            shutdown_operator $CP4BA_OPERATOR_NS
        fi
        printf "\n"
        echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}: "
        #check if the original CSV version is not matching a specific pattern (version "25.0.")
        #check ensures that the shutdown operation is only performed if the version is not the major version, i.e we are not doing a ifix ifix upgrade The version check helps in controlling upgrade.
        CUR_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
        if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "$CP4BA_RELEASE_BASE_MAJOR_VERSION"*) ]]; then
            echo "${YELLOW_TEXT}* Run the script in [upgradeDeployment] mode to upgrade the CP4BA deployment when upgrade CP4BA to $CP4BA_RELEASE_BASE.${RESET_TEXT}"
            echo "${GREEN_TEXT}# ${CUR_DIR}/cp4a-deployment.sh -m upgradeDeployment -n $CP4BA_SERVICES_NS${RESET_TEXT}"
        fi
        printf "\n"
        echo "${YELLOW_TEXT}* Run the script in [upgradeDeploymentStatus] mode directly when upgrade CP4BA from $CP4BA_RELEASE_BASE IFix to IFix.${RESET_TEXT}"
        echo "${GREEN_TEXT}# ${CUR_DIR}/cp4a-deployment.sh -m upgradeDeploymentStatus -n $CP4BA_SERVICES_NS${RESET_TEXT}"
    fi
fi

### Running with -m upgradeDeployment mode.
if [ "$RUNTIME_MODE" == "upgradeDeployment" ]; then
    project_name=$TARGET_PROJECT_NAME

    # Check whether the CP4BA is separation of operators and operands.
    # We want to check this first as from this defect we will be requesting the operand namespace to be passed in for -n argument
    # Once we can detect the SOD scenario we will use CP4BA_SERVICES_NS for the namespace where operands are deployed and CP4BA_OPERATOR_NS for the namespace where operators are deployed
    check_cp4ba_separate_operand $TARGET_PROJECT_NAME
    ALL_NAMESPACE_FLAG="No"

    

    # Get value of cp4ba_original_csv_ver_for_upgrade_script, which stores csv and used in setup of environment
    ibm_cp4ba_shared_info_cm=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS)
    ibm_cp4ba_content_shared_info_cm=$(${CLI_CMD} get configmap ibm-cp4ba-content-shared-info --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS)
    if [[ ! -z $ibm_cp4ba_shared_info_cm ]]; then
        tmp_csv_val=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info -n $CP4BA_SERVICES_NS -o jsonpath='{.data.cp4ba_original_csv_ver_for_upgrade_script}')
        if [[ ! -z $tmp_csv_val ]]; then
            cp4ba_original_csv_ver_for_upgrade_script=$tmp_csv_val
        fi
    fi
        
    if [[ ! -z $ibm_cp4ba_content_shared_info_cm ]]; then
        tmp_csv_val=$(${CLI_CMD} get configmap ibm-cp4ba-content-shared-info -n $CP4BA_SERVICES_NS -o jsonpath='{.data.cp4ba_original_csv_ver_for_upgrade_script}')
        if [[ ! -z $tmp_csv_val ]]; then
            cp4ba_original_csv_ver_for_upgrade_script=$tmp_csv_val
        fi
    fi

    #exit if CSV version is 25.0.*, upgradedeployment is not required if the original CSV version is 25.0.*
    if [[ "$cp4ba_original_csv_ver_for_upgrade_script" == "$CP4BA_RELEASE_BASE_MAJOR_VERSION"* ]]; then
        warning "DO NOT NEED to run [upgradeDeployment] mode for upgrading from ${CP4BA_RELEASE_BASE}GA/${CP4BA_RELEASE_BASE}.X to ${CP4BA_RELEASE_BASE}.X"
        echo "Exiting ..."
        exit 1
    fi

    #check whether operands (resources managed by the operator) are deployed separately from the main CP4BA project
    source ${CUR_DIR}/helper/upgrade/upgrade_merge_yaml.sh $CP4BA_SERVICES_NS $ALLOW_DIRECT_UPGRADE

    # Retrieve CR details
    # This function is defined in the common.sh script and the function find the top level CR kind and name
    # Top level CR kind and name are stored in the variables top_level_cr_type and top_level_cr_name
    # The function also stores the name of the icp4acluster and content CR names in the variables icp4acluster_cr_name,content_cr_name
    # The function also reads the CR details for both CR kinds if present and stores the CR details in "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP" "$UPGRADE_DEPLOYMENT_CONTENT_CR_TMP"
    # The top level CR details is stored in the file top_level_cr_details_location
    # FUNCTION HAS TO BE CALLED AFTER THE ABOVE source of upgrade_merge_yaml.sh so that its VARIABLE DEFINITION are loaded
    # From this point on in the script we should attempt to re-use these variables
    retrieve_custom_resource_details "$CP4BA_SERVICES_NS" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP" "$UPGRADE_DEPLOYMENT_CONTENT_CR_TMP"

    # Retrieve the currently applied top level CR's CR version using the appVersion parameter
    cr_version=$(${CLI_CMD} get $top_level_cr_kind $top_level_cr_name -n $CP4BA_SERVICES_NS -o yaml | ${YQ_CMD} '.spec.appVersion' -)

    if [[ $cr_version == "${CP4BA_RELEASE_BASE}" ]]; then
        warning "The release version of $top_level_cr_kind custom resource \"$top_level_cr_name\" is already \"$cr_version\"."
        printf "\n"

        if [[ "$SKIP_FOR_API" != "true" ]]; then
            while true; do
                printf "\x1B[1mDo you want to continue running the upgrade? (Yes/No, default: No): \x1B[0m"
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
                    printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
                    ;;
                esac
            done
        else
            RERUN_UPGRADE_DEPLOYMENT="Yes"
        fi
    else #DBACLD-160277: Setting the original version of the content CR to the current version of the content CR
        export original_cr_version=$cr_version
    fi
    
    # Function that will make required changes to the CR and create a new CR that should be applied before scaling up the operators
    # 1. Services Namespace
    # 2. Operators Namespace
    # 3. direct upgrade flag which is no longer supported
    # 4. Top level CR kind
    # 5. Top level CR Name
    # 6. Top level CR details location
    # Argument 4 through 6 is retrieved from the retrieve_custom_resource_details function
    # $CP4BA_SERVICES_NS for cp4ba deployment, $CP4BA_OPERATOR_NS for cp4ba operators
    upgrade_deployment "$CP4BA_SERVICES_NS" "$CP4BA_OPERATOR_NS" "$ALLOW_DIRECT_UPGRADE" "$top_level_cr_kind" "$top_level_cr_name" "$top_level_cr_details_location"

    echo "${YELLOW_TEXT}[TIPS]${RESET_TEXT}"
    echo "* When running the script in [upgradeDeploymentStatus] mode, it will detect whether the Zen/IM ready or not."
    echo "* After Zen/IM is ready, the script will automatically start all CP4BA operators."
    printf "\n"
    echo "If the script runs in [upgradeDeploymentStatus] mode to check the Zen/IM timeout, you could check the status by running the below command."
    msgB "To manually check the zenService version: "
    echo "  # ${CLI_CMD} get zenService $(${CLI_CMD} get zenService --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS |awk '{print $1}') --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath='{.status.currentVersion}'"
    printf "\n"
    msgB "To manually check zenService status and progress: "
    echo "  # ${CLI_CMD} get zenService $(${CLI_CMD} get zenService --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS |awk '{print $1}') --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath='{.status.zenStatus}'"
    echo "  # ${CLI_CMD} get zenService $(${CLI_CMD} get zenService --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS |awk '{print $1}') --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath='{.status.progress}'"

fi
### End of running with -m upgradeDeployment mode.

### Beginning of running with -m upgradeDeploymentStatus mode
if [[ "$RUNTIME_MODE" == "upgradeDeploymentStatus" ]]; then
    # Check whether the CP4BA is separation of operators and operands.
    # We want to check this first as from this defect we will be requesting the operand namespace to be passed in for -n argument
    # Once we can detect the SOD scenario we will use CP4BA_SERVICES_NS for the namespace where operands are deployed and CP4BA_OPERATOR_NS for the namespace where operators are deployed
    project_name=$TARGET_PROJECT_NAME
    check_cp4ba_separate_operand $TARGET_PROJECT_NAME
    ALL_NAMESPACE_FLAG="No"
    UPGRADE_DEPLOYMENT_FOLDER=${CUR_DIR}/cp4ba-upgrade/project/$CP4BA_SERVICES_NS
    source ${CUR_DIR}/helper/upgrade/upgrade_merge_yaml.sh $CP4BA_SERVICES_NS $ALLOW_DIRECT_UPGRADE
    source ${CUR_DIR}/helper/messages.sh

    UPGRADE_STATUS_CONTENT_FOLDER=${TEMP_FOLDER}/${CP4BA_SERVICES_NS}
    UPGRADE_STATUS_CP4BA_FOLDER=${TEMP_FOLDER}/${CP4BA_SERVICES_NS}
    mkdir -p ${UPGRADE_STATUS_CONTENT_FOLDER}
    mkdir -p ${UPGRADE_STATUS_CP4BA_FOLDER}

    UPGRADE_STATUS_CONTENT_FILE=${UPGRADE_STATUS_CONTENT_FOLDER}/.content_status.yaml
    UPGRADE_STATUS_CP4BA_FILE=${UPGRADE_STATUS_CP4BA_FOLDER}/.icp4acluster_status.yaml
    UPGRADE_DEPLOYMENT_WFPSRUNTIME_CR_TMP=${UPGRADE_STATUS_CP4BA_FOLDER}/.wfpsruntime_tmp.yaml
    UPGRADE_DEPLOYMENT_PFS_CR_TMP=${UPGRADE_STATUS_CP4BA_FOLDER}/.pfs_tmp.yaml

    # Retrieve CR details
    # This function is defined in the common.sh script and the function find the top level CR kind and name
    # Top level CR kind and name are stored in the variables top_level_cr_type and top_level_cr_name
    # The function also stores the name of the icp4acluster and content CR names in the variables icp4acluster_cr_name,content_cr_name
    # The function also reads the CR details for both CR kinds if present and stores the CR details in "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP" "$UPGRADE_DEPLOYMENT_CONTENT_CR_TMP"
    # The top level CR details is stored in the file top_level_cr_details_location
    # FUNCTION HAS TO BE CALLED AFTER THE ABOVE source of upgrade_merge_yaml.sh so that its VARIABLE DEFINITION are loaded
    # From this point on in the script we should attempt to re-use these variables
    retrieve_custom_resource_details "$CP4BA_SERVICES_NS" "$UPGRADE_STATUS_CP4BA_FILE" "$UPGRADE_STATUS_CONTENT_FILE"

    # Get value of cp4ba_original_csv_ver_for_upgrade_script
    ibm_cp4ba_shared_info_cm=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS)
    ibm_cp4ba_content_shared_info_cm=$(${CLI_CMD} get configmap ibm-cp4ba-content-shared-info --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS)
    if [[ ! -z $ibm_cp4ba_shared_info_cm ]]; then
        tmp_csv_val=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info -n $CP4BA_SERVICES_NS -o jsonpath='{.data.cp4ba_original_csv_ver_for_upgrade_script}')
        if [[ ! -z $tmp_csv_val ]]; then
            cp4ba_original_csv_ver_for_upgrade_script=$tmp_csv_val
        fi
    fi
        
    if [[ ! -z $ibm_cp4ba_content_shared_info_cm ]]; then
        tmp_csv_val=$(${CLI_CMD} get configmap ibm-cp4ba-content-shared-info -n $CP4BA_SERVICES_NS -o jsonpath='{.data.cp4ba_original_csv_ver_for_upgrade_script}')
        if [[ ! -z $tmp_csv_val ]]; then
            cp4ba_original_csv_ver_for_upgrade_script=$tmp_csv_val
        fi
    fi

    # Function to remove the old operands that will conflict with the new version of Events Operator
    # Function defined in common.sh
    # https://jsw.ibm.com/browse/DBACLD-178674
    delete_cpfs_operand_requests "$CP4BA_SERVICES_NS"

    
    # Scale appropriate operator based on CR kind
    # Instead of checking if a crd type content is present and then checking if it is a top level CR and then taking the CR details,
    # we can just use the variables loaded by the retrieve_custom_resource_details function which does all this at the start of each mode
    case "$top_level_cr_kind" in
        "content")
            scale_operator "ibm-content-operator" "IBM CP4BA Content Cortex Standard Edition"
            scale_operator "icp4a-foundation-operator" "IBM CP4BA Foundation"
            CONTENT_CR_EXIST="Yes"
            ;;
        "icp4acluster")
            scale_operator "ibm-content-operator" "IBM CP4BA Content Cortex Standard Edition"
            scale_operator "ibm-cp4a-operator" "IBM Cloud Pak for Business Automation (CP4BA) multi-pattern"
            CONTENT_CR_EXIST="No"
            ;;
        *)
            fail "No top level CP4BA custom resource found on this cluster in the project \"$CP4BA_SERVICES_NS\"."
            exit 1
            ;;
    esac

    # Retrieve the currently applied top level CR's CR version using the appVersion parameter
    cr_version=$(${CLI_CMD} get $top_level_cr_kind $top_level_cr_name -n $CP4BA_SERVICES_NS -o yaml | ${YQ_CMD} '.spec.appVersion' -)
    if [[ $cr_version != "${CP4BA_RELEASE_BASE}" ]]; then
        fail "The release version: \"$cr_version\" in $top_level_cr_kind custom resource \"$top_level_cr_name\" is incorrect. Apply the new version of the CR first."
        exit 1
    fi

    while true; do
        clear
        isReady_cp4ba=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath='{.data.cp4ba_operator_of_last_reconcile}')
        isReady_foundation=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath='{.data.foundation_operator_of_last_reconcile}')
        if [[ -z "$isReady_cp4ba" && -z "$isReady_foundation" ]]; then
            CP4BA_DEPLOYMENT_STATUS="Getting Upgrade Status ..."
            printf '%s %s\n' "$(date)" "[refresh interval: 30s]"
            printf '%b' "[Press Ctrl+C to exit] \t\t"
            printHeaderMessage "CP4BA Upgrade Status"
            printf '%b' "${GREEN_TEXT}$CP4BA_DEPLOYMENT_STATUS${RESET_TEXT}"
            sleep 30
        else
            break
        fi
    done

    # The control variable used to detect if the strimzi patch function has to be executed.
    strimzi_patched=false
    # The control variable used to detect if we should display manual steps to patch strimzipodset, by default we want to print it
    DISPLAY_MANUAL_PATCH_STEPS=true
    
    # Call function to check if the deployment SaaS
    is_saas_deployment=false
    if check_saas_deployment "$top_level_cr_kind" "$top_level_cr_name" "$CP4BA_SERVICES_NS"; then
        is_saas_deployment=true
    else
        is_saas_deployment=false
    fi

    # Track operator reconcile progress during upgradeDeploymentStatus monitoring.
    RECONCILE_SEEN_FLAG=false
    OPERATOR_RECONCILE_COUNT=0
    operator_deployment_name=""
    operator_pod_name=""

    if [[ "$top_level_cr_kind" == "content" ]]; then
        operator_deployment_name="ibm-content-operator"
    else
        operator_deployment_name="ibm-cp4a-operator"
    fi

    # check for zenStatus and currentverison for zen only if the deployment is NOT SaaS.
    # If the deployment is SaaS we can skip the Zen related checks
    if [[ "$is_saas_deployment" == "false" ]]; then
        # Moved the entire Zen Upgrade Status check code into its own function so that the main upgrade flow is much cleaner
        validate_zen_upgrade_status
    fi

    # Start up all other CP4BA operators
    # This was happening inside a zen upgrade check condition after zen was upgraded
    # This will maintain the same behavior but also allow operators to be scaled up when the deployment is SaaS and there is no Zen
    startup_operator $CP4BA_OPERATOR_NS "silent"

    # Patch strimzi podset if required with timeout
    if [[ $strimzi_patched == "false" ]]; then
        info "Checking if Strimzi PodSet patch is required..."
        
        # 10 minutes = 600 seconds / 30 seconds interval = 20 retries
        maxRetry=20
        REFRESH_INTERVAL=30
        retry=0
        
        while [[ $strimzi_patched == "false" && $retry -le $maxRetry ]]
        do
            elapsed_time=$((retry * REFRESH_INTERVAL))
            elapsed_minutes=$((elapsed_time / 60))
            remaining_time=$(((maxRetry - retry) * REFRESH_INTERVAL))
            remaining_minutes=$((remaining_time / 60))
            
            if [[ $retry -gt 0 ]]; then
                echo "Attempting to patch Strimzi PodSet (Elapsed: ${elapsed_minutes}m, Remaining: ${remaining_minutes}m, Attempt: $((retry+1))/${maxRetry})"
            fi
            
            # Each refresh of the zen upgrade, we check if we need to update the kafka strimzi podset
            # The function patch_strimzi_podset which is defined in common.sh will set strimzi_patched to true once the patch is completed
            # For upgrades to 24.0.1 or newer, kafka tasks in the cp4a-operator happen after zen is upgraded so this block is after zen upgrade completes
            # For upgrades to 24.0.0, kafka tasks in the cp4a-operator happen before zen is upgraded
            patch_strimzi_podset "$CP4BA_OPERATOR_NS" "$CP4BA_SERVICES_NS"
            
            # Check if patch was successful
            if [[ $strimzi_patched == "true" ]]; then
                success "Strimzi PodSet patch completed successfully"
                DISPLAY_MANUAL_PATCH_STEPS=false
                break
            fi
            
            # Check if max retries reached
            if [[ $retry -eq $maxRetry ]]; then
                warning "✗ Strimzi PodSet patch failed - Timeout after 10 minutes"
                printf "\n"
                echo "${RED_TEXT}The Strimzi PodSet could not be patched automatically.${RESET_TEXT}"
                echo "This may be due to:"
                echo "  - Events Operator not being ready"
                echo "  - StrimziPodSet resource not found"
                echo "  - Network or permission issues"
                printf "\n"
                DISPLAY_MANUAL_PATCH_STEPS=true
                printf "\n"
                warning "Continuing with the upgrade process. Please apply the manual steps if needed."
                printf "\n"
                # Set to true to prevent further attempts
                strimzi_patched=true
                break
            fi
            
            retry=$((retry + 1))
            sleep ${REFRESH_INTERVAL}
        done
    else
        info "Strimzi PodSet patch not required or already completed"
    fi


    # Monitor CP4BA upgrade status with timeout
    info "Starting CP4BA upgrade status monitoring (timeout: 30 minutes, refresh interval: 60s)"

    # 45 minutes = 2700 seconds / 60 seconds interval = 30 retries
    maxRetry=120
    REFRESH_INTERVAL=60
    retry=0
    all_components_ready=false

    while [[ $retry -le $maxRetry ]]
    do
        clear
        
        
        # Calculate elapsed and remaining time
        elapsed_time=$((retry * REFRESH_INTERVAL))
        elapsed_minutes=$((elapsed_time / 60))
        remaining_time=$(((maxRetry - retry) * REFRESH_INTERVAL))
        remaining_minutes=$((remaining_time / 60))
        

        # Display header with timing info
        printf '%s\n' "$(date)"
        printf '%b' "[Monitoring CP4BA Upgrade Status - Elapsed: ${elapsed_minutes}m, Remaining: ${remaining_minutes}m, Refresh: ${REFRESH_INTERVAL}s]"
        printf "\n"
        printf '%b' "[Press Ctrl+C to exit monitoring]"
        printf "\n\n"
        
        # Global array to track all component status variables
        # Every retry this variable has to be re-initialized so that it can pick up the latest status only
        CP4BA_COMPONENT_STATUS_VALUES=()

        # Check operator reconcile count until it reaches 2 once, then stop checking. We check for 2 because we are looking for the number of log files genererated
        # More than 1 log file means the top level operator has reconciled atleast once
        if [[ "$RECONCILE_SEEN_FLAG" == "false" ]]; then
            operator_pod_name=$(${CLI_CMD} get pods -n "$CP4BA_OPERATOR_NS" -l name="$operator_deployment_name" --no-headers --ignore-not-found 2>/dev/null | awk 'NR==1{print $1}')
            if [[ -n "$operator_pod_name" ]]; then
                if get_cp4ba_operator_reconcile_count "$CP4BA_OPERATOR_NS" "$operator_pod_name" "$top_level_cr_kind" "$top_level_cr_name"; then
                    if [[ "$OPERATOR_RECONCILE_COUNT" -ge 2 ]]; then
                        RECONCILE_SEEN_FLAG=true
                    fi
                fi
            else
                RECONCILE_SEEN_FLAG=true
            fi
        fi

        # Get and display the upgrade status
        show_cp4ba_upgrade_status

        # Display manual patch steps if needed
        # This gets displayed in case the patch by the operator does not work
        if [[ "$DISPLAY_MANUAL_PATCH_STEPS" == "true" ]]; then
            displayManualStrimziPodsetPatchingMessage "$CP4BA_OPERATOR_NS" "$CP4BA_SERVICES_NS"
            echo ""
            echo ""
        fi
        
        
        # Check if all components are ready
        if check_if_all_components_are_ready; then
            all_components_ready=true
            printf "\n"
            success "All components are in 'Done' status which means that all CP4BA components have been upgraded successfully!"
            printf "\n"
            echo "======================================================================================================="
            success "${GREEN_TEXT}The upgrade to CP4BA $CP4BA_RELEASE_BASE $CP4BA_PATCH_VERSION is complete.${RESET_TEXT}"
            echo "======================================================================================================="
            printf "\n"
            exit 0
        fi
        
        # Check if max retries reached
        if [[ $retry -eq $maxRetry ]]; then
            printf "\n"
            error "CP4BA upgrade monitoring timeout - 45 minutes elapsed"
            printf "\n"
            echo "================================================================================"
            echo "${RED_TEXT}CP4BA Upgrade Status - TIMEOUT${RESET_TEXT}"
            echo "================================================================================"
            printf "\n"
            warning "Some components failed to complete the upgrade within the expected timeframe."
            printf "\n"
            echo "${YELLOW_TEXT}Next Steps:${RESET_TEXT}"
            echo "1. Review the component status above to identify which components are not ready"
            echo "2. Check the operator logs for errors:"
            echo "   ${CLI_CMD} logs -n ${CP4BA_OPERATOR_NS} -l name=ibm-cp4a-operator --tail=100"
            echo "3. Check the component pod logs in namespace: ${CP4BA_SERVICES_NS}"
            printf "\n"
            echo "For more information, refer to the CP4BA Knowledge Center - Troubleshooting section"
            printf "\n"
            exit 1
        fi
        
        retry=$((retry + 1))
        sleep ${REFRESH_INTERVAL}
    done

fi
### End of running with -m upgradeDeploymentStatus mode
if [ "$RUNTIME_MODE" == "upgradePostconfig" ]; then
    project_name=$TARGET_PROJECT_NAME

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

    source ${CUR_DIR}/helper/upgrade/upgrade_merge_yaml.sh $TARGET_PROJECT_NAME $ALLOW_DIRECT_UPGRADE

    info "Starting to execute script for post CP4BA upgrade"
    # Retrieve existing WfPSRuntime CR
    exist_wfps_cr_array=($(${CLI_CMD} get WfPSRuntime -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_wfps_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            info "Retrieving existing IBM CP4BA Workflow Process Service (Kind: WfPSRuntime.icp4a.ibm.com) Custom Resource: \"${item}\""
            cr_type="WfPSRuntime"
            cr_metaname=$(${CLI_CMD} get $cr_type ${item} -n $CP4BA_SERVICES_NS -o yaml | ${YQ_CMD} '.metadata.name' -)
            UPGRADE_DEPLOYMENT_WFPS_CR=${UPGRADE_DEPLOYMENT_CR}/wfps_${cr_metaname}.yaml
            UPGRADE_DEPLOYMENT_WFPS_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.wfps_${cr_metaname}_tmp.yaml
            UPGRADE_DEPLOYMENT_WFPS_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/wfps_cr_${cr_metaname}_backup.yaml

            ${CLI_CMD} get $cr_type ${item} -n $CP4BA_SERVICES_NS -o yaml > ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # Backup existing WfPSRuntime CR
            mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} ${UPGRADE_DEPLOYMENT_WFPS_CR_BAK}

            info "Merging existing IBM CP4BA Workflow Process Service custom resource: \"${item}\" with new version ($CP4BA_RELEASE_BASE)"
            # Delete unnecessary section in CR
            ${YQ_CMD} -i 'del(.status)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"
            ${YQ_CMD} -i 'del(.metadata.annotations)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"
            ${YQ_CMD} -i 'del(.metadata.creationTimestamp)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"
            ${YQ_CMD} -i 'del(.metadata.generation)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"
            ${YQ_CMD} -i 'del(.metadata.resourceVersion)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"
            ${YQ_CMD} -i 'del(.metadata.uid)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"

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
            ${CLI_CMD} annotate WfPSRuntime ${item} kubectl.kubernetes.io/last-applied-configuration- -n $CP4BA_SERVICES_NS >&3 2>&3
            sleep 3
            ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_WFPS_CR} -n $CP4BA_SERVICES_NS >&3 2>&3
            if [ $? -ne 0 ]; then
                fail "IBM CP4BA Workflow Process Service custom resource update failed"
                exit 1
            else
                echo "Done!"

                printf "\n"
                echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
                msgB "Run \"cp4a-deployment.sh -m upgradeDeploymentStatus -n $CP4BA_SERVICES_NS\" to get overview upgrade status for IBM CP4BA Workflow Process Service"
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
    #             ${CLI_CMD} delete route $iam_idprovider -n $project_name 
    #         fi
    #         if [[ ! -z $iam_idmgmt ]]; then
    #             info "Remove \"cp-console-iam-idmgmt\" route from project \"$project_name\"."
    #             ${CLI_CMD} delete route $iam_idmgmt -n $project_name 
    #         fi
    #     fi
    # fi
    # Retrieve existing ICP4ACluster CR for ADP post upgrade
    icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $icp4acluster_cr_name ]; then
        info "Retrieving existing CP4BA ICP4ACluster (Kind: icp4acluster.icp4a.ibm.com) Custom Resource"
        cr_type="icp4acluster"
        cr_metaname=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $project_name -o yaml | ${YQ_CMD} '.metadata.name' -)
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
            existing_pattern_list=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_patterns" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
            existing_opt_component_list=`${YQ_CMD} ".spec.shared_configuration.sc_optional_components" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`

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
                ${CLI_CMD} delete route $iam_idprovider -n $project_name >&3 2>&3
            fi
            if [[ ! -z $iam_idmgmt ]]; then
                info "Remove \"cp-console-iam-idmgmt\" route from project \"$project_name\"."
                ${CLI_CMD} delete route $iam_idmgmt -n $project_name >&3 2>&3
            fi
        fi
    fi
    success "Completed to execute script for post CP4BA upgrade"
fi
