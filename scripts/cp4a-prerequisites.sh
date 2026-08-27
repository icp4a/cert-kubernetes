#!/bin/bash
#set -x
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
CLI_CMD="kubectl"

#https://jsw.ibm.com/browse/DBACLD-218483 -Initialize fd 3,will be redirected to log file by save_log() in common.sh
exec 3>/dev/null

# Based on recommendation by Bob, we need to parse for TARGET_PROJECT_NAME before sourcing common.sh,
# so that PREREQUISITES_FOLDER and related paths are set correctly on the first (and only) source.
# We cannot call "parse_arguments" function before we source "common.sh" because there is a circular dependency:
# "parse_arguments" function depends on "msg" and "check_cluster_login" which are defined in "common.sh"
TARGET_PROJECT_NAME=""
for _i in "$@"; do
    if [[ "$_prev_arg" == "-n" ]]; then
        TARGET_PROJECT_NAME="$_i"
        break
    fi
    _prev_arg="$_i"
done
unset _i _prev_arg

source ${CUR_DIR}/helper/common.sh $TARGET_PROJECT_NAME
source ${CUR_DIR}/helper/messages.sh $COMMON_SERVICES_SCRIPT_FOLDER

# DBACLD-217419: Support shared secrets in Vault 
source "${CUR_DIR}/helper/ext-secrets-mgmt/common_functions_vault.sh"

source "${CUR_DIR}/cp4a-storage-validation.sh"

# Define constant for external PostgreSQL server prefix used for ADPGG/DICMS
EXTERNAL_POSTGRES_SERVER_PREFIX="postgresql-external"

# Open fd 3 for logging early (before parse_arguments) so >&3 redirects in parse_arguments work.
# TARGET_PROJECT_NAME may be empty here if -n was not provided; save_log handles that gracefully.
if [[ -n "$TARGET_PROJECT_NAME" ]]; then
    save_log "cp4a-script-logs/project/$TARGET_PROJECT_NAME" "cp4a-prerequisites-log"
    trap cleanup_log EXIT
fi

function show_help() {
    printf '%b\n' "\nUsage: cp4a-prerequisites.sh -m [modetype] -n [cp4baNamespace] [options]\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -m  The valid mode types are: [property], [generate], or [validate]"
    echo "  -n  The target namespace of the CP4BA deployment."
    echo "  --java-path  Optional path to Java (JRE) installation directory"
    echo "      STEP1: Run the script in [property] mode. It creates property files (DB/LDAP property file) with default values (database name/user)."
    echo "      STEP2: Modify the DB/LDAP/user property files with your values."
    echo "      STEP3: Run the script in [generate] mode. Generates the DB SQL statement files and YAML templates for the secrets based on the values in the property files."
    echo "      STEP4: Create the databases and secrets by using the modified DB SQL statement files and YAML templates for the secrets."
    echo "      STEP5: Run the script in [validate] mode. Checks whether the databases and the secrets are created before you install CP4BA."
    echo "  --run-storage-validation"
    echo "      Optional flag for validate mode. If supplied, runs storage validation automatically without prompting."
    echo "  --enable-external-secret-management"
    echo "      Enable external secret management integration for user-created secrets used by CP4BA."
    echo "      Prerequisites:"
    echo "        - An external secret management instance must be available and configured for CP4BA to access. See CP4BA Knowledge Center topic 'Optional: Preparing for external secret management'"
    echo "        - Only Hashicorp Vault is currently supported."
    echo "        - Use with \"-m property\", \"-m generate\", \"-m validate\" modes, in that order."
    echo "        - This flag is only applicable with an existing deployment of CP4BA in the namespace specified with \"-n\"."
    echo "        - This flag is not applicable when performing a new deployment. For a new deployment, external secrets management integration can be selected as part of the normal deployment steps."
    echo "  --update-components"
    echo "      Updates deployment patterns and optional components in an existing installation,then regenerates property files with the new configuration."
    echo "      Prerequisites:"
    echo "        - Active deployment in the namespace specified with \"-n\"."
    echo "        - Original property files must be available."
    echo "        - Must be used exclusively with \"-m property\" mode."
}

###########################
# PARSE ARGUMENTS
###########################
function parse_arguments() {
    # ------- Initialize vault flags to false before parsing arguments -------
    # Enabling Vault in general (new or existing deployment)
    if [[ -z "$VAULT_ENABLED" ]]; then
        VAULT_ENABLED="false"
    fi
    # Enabling Vault on existing deployment
    if [[ -z "$ENABLE_VAULT_ON_EXIST" ]]; then
        ENABLE_VAULT_ON_EXIST="false"
        ENABLE_VAULT_ON_EXIST_PROP_TYPE="none"
    fi

    local args=("$@")
    local i=0
    
    while [ $i -lt ${#args[@]} ]; do
        local key="${args[$i]}"
        case $key in
        -m)
            ((i++))
            if [ $i -ge ${#args[@]} ] || [ -z "${args[$i]}" ]; then
                echo "Invalid option: -m requires an argument"
                exit 1
            fi
            RUNTIME_MODE="${args[$i]}"
            if [[ $RUNTIME_MODE == "property" || $RUNTIME_MODE == "generate" || $RUNTIME_MODE == "validate" ]]; then
                echo
            else
                msg "Use a valid value: -m [property] or [generate] or [validate]"
                exit 1
            fi
            ;;
        -n)
            ((i++))
            if [ $i -ge ${#args[@]} ] || [ -z "${args[$i]}" ]; then
                echo "Invalid option: -n requires an argument"
                exit 1
            fi
            TARGET_PROJECT_NAME="${args[$i]}"
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
                isProjExists=`${CLI_CMD} get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l`  >&3 2>&3
                if [ $isProjExists -ne 2 ] ; then
                    printf '%b\n' "\x1B[1;31mInvalid project name \"$TARGET_PROJECT_NAME\", please set a existing project name.\x1B[0m"
                    exit 1
                fi
                : # Null command - validation passed, continue execution
                ;;
            esac
            ;;
        -h|--help|\?)
            show_help
            exit 0
            ;;
        --update-components)
            UPDATE_COMPONENTS="true"
            ;;
        --run-storage-validation)
            RUN_STORAGE_VALIDATION="yes"
            ;;
        --enable-external-secret-management)
            # Enabling Vault in general (new or existing deployment)
            VAULT_ENABLED="true"
            # Enabling Vault on existing deployment
            ENABLE_VAULT_ON_EXIST="true"
            ;;
        --java-path)
            ((i++))
            if [ $i -ge ${#args[@]} ] || [ -z "${args[$i]}" ]; then
                echo "Invalid option: --java-path requires an argument"
                exit 1
            fi
            CUSTOM_JAVA_PATH="${args[$i]}"
            # Verify the path exists
            if [ ! -d "$CUSTOM_JAVA_PATH" ]; then
                printf '%b\n' "\x1B[1;31mThe specified Java (JRE) path does not exist: ${CUSTOM_JAVA_PATH}\x1B[0m"
                exit 1
            fi
            ;;
        --java-path=*)
            CUSTOM_JAVA_PATH="${key#*=}"
            if [ -z "$CUSTOM_JAVA_PATH" ]; then
                echo "Invalid option: --java-path requires a value"
                exit 1
            fi
            # Verify the path exists
            if [ ! -d "$CUSTOM_JAVA_PATH" ]; then
                printf '%b\n' "\x1B[1;31mThe specified Java (JRE) path does not exist: ${CUSTOM_JAVA_PATH}\x1B[0m"
                exit 1
            fi
            ;;
        *)
            echo "Invalid option: $key"
            show_help
            exit 1
            ;;
        esac
        ((i++))
    done
}

# Pass all arguments to parse_arguments
parse_arguments "$@"

# Import verification functions after parsing arguments
# CUSTOM_JAVA_PATH variable is already set by parse_arguments if --java-path was provided
# cp4a-verification.sh will use this variable directly
source ${CUR_DIR}/helper/cp4a-verification.sh

if [[ -z "$RUNTIME_MODE" ]]; then
    printf '%b\n' "\x1B[1;31mPlease input value for \"-m <MODE_TYPE>\" option.\n\x1B[0m"
    show_help
    exit 1
fi
if [[ -z "$TARGET_PROJECT_NAME" ]]; then
    printf '%b\n' "\x1B[1;31mPlease input value for \"-n <CP4BA_NAMESPACE>\" option.\n\x1B[0m"
    show_help
    exit 1
fi

info "The cp4a-prerequisite script is currently being executed in the ${RUNTIME_MODE} mode"
printf "\n"

IBM_LICENSE="Accept"
INSTALL_BAW_ONLY="No"

# Based on recommendation by Bob, we can consolidate the "source common.sh" to one place in the script (see top of script)
# source ${CUR_DIR}/helper/common.sh $TARGET_PROJECT_NAME

# Import variables for property file
source ${CUR_DIR}/helper/cp4ba-property.sh

# Import function for secret
source ${CUR_DIR}/helper/cp4ba-secret.sh

# Import upgrade upgrade_check_version.sh script
source ${CUR_DIR}/helper/upgrade/upgrade_check_status.sh

JDBC_DRIVER_DIR=${CUR_DIR}/jdbc
PLATFORM_SELECTED=""
PATTERN_SELECTED=""
COMPONENTS_SELECTED=""
OPT_COMPONENTS_CR_SELECTED=""
OPT_COMPONENTS_SELECTED=()
LDAP_TYPE=""
CP4BA_JDBC_URL=""

FOUNDATION_CR_SELECTED=""
optional_component_arr=()
optional_component_cr_arr=()
foundation_component_arr=()
FOUNDATION_FULL_ARR=("BAN" "RR" "BAS" "UMS" "AE")
OPTIONAL_COMPONENT_FULL_ARR=("content_integration" "workstreams" "case" "business_orchestration" "ban" "bai" "css" "cmis" "es" "ier" "iccsap" "tm" "ums" "ads_designer" "ads_runtime" "app_designer" "decisionCenter" "decisionServerRuntime" "decisionRunner" "ae_data_persistence" "baw_authoring" "pfs" "baml" "auto_service" "document_processing_runtime" "document_processing_designer" "wfps_authoring" "kafka" "opensearch")

function prompt_license(){
    # clear



    printf '%b\n' "\x1B[1;31mIMPORTANT: Review the IBM Cloud Pak for Business Automation license information here: \n\x1B[0m"
    printf '%b\n' "\x1B[1;31mhttps://www.ibm.com/support/customer/csol/terms/?id=L-VFRQ-EPLMC3\n\x1B[0m"
    INSTALL_BAW_ONLY="No"


    prompt_press_any_key_to_continue

    printf "\n"
    while true; do
        
        printf "\x1B[1mDo you accept the IBM Cloud Pak for Business Automation license (Yes/No, default: No): \x1B[0m"
        
        read -erp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            printf "\n"
            # New license message from 26.0.0 GA for https://jsw.ibm.com/browse/DBACLD-218047
            printf '%b\n' "${BOLD_TEXT}${RED_TEXT}IMPORTANT: By accepting the license, you agree and understand that by default the program collects certain data and metrics regarding deployment and usage.\nFor more information, please consult the License Information for Cloud Pak for Business Automation.${RESET_TEXT}"
            echo
            prompt_press_any_key_to_continue
            echo
            IBM_LICENSE="Accept"
            validate_cli
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            echo
            printf '%b\n' "Exiting...\n"
            exit 0
            ;;
        *)
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function validate_utility_tool_for_validation(){
    which kubectl &>/dev/null
    if [[ $? -ne 0 ]]; then
        printf '%b\n'  "\x1B[1;31mUnable to locate Kubernetes CLI. Kubernetes CLI must be installed to run this script.\x1B[0m" && \
        while true; do
            printf "\x1B[1mDo you want install the Kubernetes CLI by the cp4a-prerequisites.sh script? (Yes/No): \x1B[0m"
            read -erp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_kubectl_cli
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                info "Kubernetes CLI must be installed to continue the next validation"
                exit 1
                ;;
            *)
                printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi
    # DBACLD-198782: Check if Java is installed and meets the minimum version requirement
    # Priority: --java-path > JAVA_HOME > system PATH
    JAVA_PATH="${CUSTOM_JAVA_PATH:-$JAVA_HOME}"
    validate_java_runtime "$JAVA_PATH"

    which openssl &>/dev/null
    if [[ $? -ne 0 ]]; then
        printf '%b\n'  "\x1B[1;31mUnable to locate openssl. OpenSSL must be installed to run this script.\x1B[0m" && \
        while true; do
            printf "\x1B[1mDo you want install the OpenSSL by the cp4a-prerequisites.sh script? (Yes/No): \x1B[0m"
            read -erp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_openssl
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                info "OpenSSL must be installed for the next validation"
                exit 1
                ;;
            *)
                printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi
}

function containsElement(){
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}


function select_pattern(){
# This function support mutiple checkbox, if do not select anything, it will return None
    PATTERNS_SELECTED=""
    choices_pattern=()
    temp_choices_pattern=()
    pattern_arr=()
    pattern_cr_arr=()
    AUTOMATION_SERVICE_ENABLE=""
    AE_DATA_PERSISTENCE_ENABLE=""
    #CPE_FULL_STORAGE=""


    if [[ "${PLATFORM_SELECTED}" == "other" ]]; then
        if [[ "${DEPLOYMENT_TYPE}" == "starter" ]];
        then
            options=("Content Cortex Essentials" "Operational Decision Manager" "Decision Intelligence Client Managed Software" "Business Automation Application" "Business Automation Workflow Authoring and Automation Workstream Services" "IBM Automation Document Processing")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow-workstreams" "document_processing")
            foundation_0=("BAN" "RR")                 # Foundation for Content Cortex Essentials
            foundation_1=("BAN" "RR")                # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR" "UMS")     # Foundation for Decision Intelligence Client Managed Software
            foundation_3=("RR" "UMS" "BAS")     # Foundation for Business Automation Applications (full)
            foundation_4=("RR" "UMS" "AE" "BAS")           # Foundation for Business Automation Workflow and workstreams(Demo)
            foundation_5=("BAN" "RR" "AE" "BAS" "UMS")  # Foundation for IBM Automation Document Processing
        else
            options=("Content Cortex Essentials" "Operational Decision Manager" "Decision Intelligence Client Managed Software" "Business Automation Application" "Business Automation Workflow" "(a) Workflow Authoring" "(b) Workflow Runtime" "Automation Workstream Services" "IBM Automation Document Processing" "(a) Development Environment" "(b) Runtime Environment" "Workflow Process Service Authoring")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow" "workflow-authoring" "workflow-runtime" "workstreams" "document_processing" "document_processing_designer" "document_processing_runtime" "workflow-process-service")
            foundation_0=("BAN" "RR")                 # Foundation for Content Cortex Essentials
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
        if [[ "${DEPLOYMENT_TYPE}" == "starter" ]];
        then
            options=("Content Cortex Essentials" "Operational Decision Manager" "Decision Intelligence Client Managed Software" "Business Automation Application" "Business Automation Workflow Authoring and Automation Workstream Services" "IBM Automation Document Processing")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow-workstreams" "document_processing")
            foundation_0=("BAN" "RR")                 # Foundation for Content Cortex Essentials
            foundation_1=("BAN" "RR")                # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR")     # Foundation for Decision Intelligence Client Managed Software
            foundation_3=("RR" "BAS")     # Foundation for Business Automation Applications (full)
            foundation_4=("RR" "AE" "BAS")           # Foundation for Business Automation Workflow and workstreams(Demo)
            foundation_5=("BAN" "RR" "AE" "BAS")  # Foundation for IBM Automation Document Processing
        else
            options=("Content Cortex Essentials" "Operational Decision Manager" "Decision Intelligence Client Managed Software" "Business Automation Application" "Business Automation Workflow" "(a) Workflow Authoring" "(b) Workflow Runtime" "Automation Workstream Services" "IBM Automation Document Processing" "(a) Development Environment" "(b) Runtime Environment" "Workflow Process Service Authoring")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow" "workflow-authoring" "workflow-runtime" "workstreams" "document_processing" "document_processing_designer" "document_processing_runtime" "workflow-process-service")
            foundation_0=("BAN" "RR")                 # Foundation for Content Cortex Essentials
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
    tips1="\x1B[1;31mTips\x1B[0m: \x1B[1mPress [ENTER] to accept the default (None of the capabilities is selected)\x1B[0m"
    tips2="\x1B[1;31mTips\x1B[0m: \x1B[1mPress [ENTER] when you are done\x1B[0m"
    pattern_starter_tips="\x1B[1mInfo: Except pattern (4/5), Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Business Automation foundation platform. \n\nTips: After you make your first selection you will be able to make additional selections since you can combine multiple selections.\n\x1B[0m"
    pattern_production_tips="\x1B[1mInfo: Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Business Automation foundation platform. \n\nTips: After you make your first selection you will be able to make additional selections since you can combine multiple selections.\n\x1B[0m"
    baw_iaws_tips="\x1B[1mInfo: Note that Business Automation Workflow Authoring (5a) cannot be installed together with Automation Workstream Services (6). However, Business Automation Workflow Runtime (5b) can be installed together with Automation Workstream Services (6).\n\x1B[0m"
    update_components_tips="\x1B[1m When updating the selection of Cloud Pak for Business Automation capabilities, please note these restrictions:\n 1. Business Automation Workflow Authoring (5a) cannot be deployed alongside Automation Workstream Services (6) and Business Automation Workflow Runtime (5b)\n 2. IBM Automation Document Processing Designer (7a) cannot be deployed alongside IBM Automation Document Processing Runtime (7b).\n Please deselect any conflicting components before proceeding with your selection.\n\x1B[0m"
    linux_starter_tips="\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mIBM Automation Document Processing (6) does NOT support a cluster running a Linux on Z (s390x)/Power architecture.\n\x1B[0m"
    linux_production_tips="\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mIBM Automation Document Processing (7a/7b) does NOT support a cluster running a Linux on Z (s390x)/Power architecture.\n\x1B[0m"
    
    #Function to remove a component from an array
    # Usage: EXISTING_OPT_COMPONENT_ARR=($(remove_component "component_to_remove" "${EXISTING_OPT_COMPONENT_ARR[@]}"))
    remove_component() {
        local component_to_remove="$1"
        shift
        local result=""
        
        # Loop through all arguments (array elements)
        for item in "$@"; do
            # Add to result only if it doesn't match the component to remove
            if [[ "$item" != "$component_to_remove" ]]; then
                # Add space if not the first element
                if [[ -n "$result" ]]; then
                    result="$result $item"
                else
                    result="$item"
                fi
            fi
        done
        
        # Return the result
        echo "$result"
    }
    
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
                    "8") # ADP
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "${choices_pattern[i]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                        ;;
                    "11") # for WfPS
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" 8 "${options[i]}"  "${choices_pattern[i]}"
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
                        "11") # for WfPS
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" 8 "${options[i]}"  "${choices_pattern[i]}"
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
                        "11")
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" 8 "${options[i]}"  "(Installed)"
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
                            else
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "(Installed)"
                                if [[ $document_processing_designer_Val -eq 0 ]]; then
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "(Installed)"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                                elif [[ $document_processing_runtime_Val -eq 0 ]]
                                then
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "(Installed)"
                                fi
                            fi
                            ;;
                        esac
                   fi
                fi
            fi
        done
        if [[ "$msg" ]]; then echo "$msg"; fi
        printf "\n"
        if [[ $DEPLOYMENT_TYPE == "production" ]]; then
            printf '%b\n' "${baw_iaws_tips}"
        fi

        if [[ $DEPLOYMENT_TYPE == "production" ]]; then
            printf '%b\n' "${pattern_production_tips}"
            printf '%b\n' "${linux_production_tips}"
            if [[ "$UPDATE_COMPONENTS" == "true" ]]; then
                printf '%b\n' "${update_components_tips}"
                echo
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
    elif [[ $DEPLOYMENT_TYPE == "production" ]]
    then
        prompt="Enter a valid option [1 to 4, 5a, 5b, 6, 7a, 7b, 8]: "
    fi
    
    # Outer loop to ensure at least one capability is selected
    while true; do
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
                # choices_pattern[11]=""
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
                # choices_pattern[11]=""
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
                # choices_pattern[10]=""
                # choices_pattern[9]=""
                # choices_pattern[8]=""
                ;;
            esac
        else
            echo "Deployment type is invalid."
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
            fi
        else
            if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
            elif [[ $DEPLOYMENT_TYPE == "production" ]]
            then
                # Only once do we have to initialize each pattern that was already part of the existing pattern list to Installed
                # If we don't then everytime the menu screen refreshes, the value gets reset to installed even if the user decides to mark it as uninstalled 
                # And subsequent times when a pattern is selected it will remain as uninstalled and wont get re-selected
                # https://jsw.ibm.com/browse/DBACLD-200499
                if [[ "${temp_choices_pattern[num]}" != "false" ]]; then
                    choices_pattern[num]="(Installed)"
                    temp_choices_pattern[num]="false"
                fi
                case "$num" in
                "5")
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring" && ("${choices_pattern[6]}" == "(Selected)" || "${choices_pattern[7]}" == "(Selected)") ]]; then
                        choices_pattern[num]="(To Be Uninstalled)"
                    else
                        if [[ "${choices_pattern[num]}" == "(Installed)" ]]; then
                            choices_pattern[num-1]="(To Be Uninstalled)"
                            choices_pattern[num]="(To Be Uninstalled)"
                        # If the user selects a pattern that is already uninstalled, then it would be marked as To be Uninstalled.
                        # But if they once again select that same pattern we need to mark that pattern back as Installed.
                        # https://jsw.ibm.com/browse/DBACLD-200499
                        elif [[ "${choices_pattern[num]}" == "(To Be Uninstalled)" ]]; then
                            choices_pattern[num-1]="(Installed)"
                            choices_pattern[num]="(Installed)"
                        else
                            # Original logic for other cases
                            [[ "${choices_pattern[num]}" ]] && choices_pattern[num-1]="" || choices_pattern[num-1]="(To Be Uninstalled)"
                            [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                        fi
                    fi
                    # IF we are deciding to remove workflow authoring, we need to remove it from the optional components
                    # https://jsw.ibm.com/browse/DBACLD-200499
                    if [[ "${choices_pattern[num]}" == "(To Be Uninstalled)" ]]; then
                        # Remove "baw_authoring" from EXISTING_OPT_COMPONENT_ARR
                        EXISTING_OPT_COMPONENT_ARR=($(remove_component "baw_authoring" "${EXISTING_OPT_COMPONENT_ARR[@]}"))
                    fi
                    # If the user selects a pattern that is already uninstalled, then it would be marked as To be Uninstalled.
                    # But if they once again select that same pattern we need to mark that pattern back as Installed.
                    # https://jsw.ibm.com/browse/DBACLD-200499
                    if [[ "${choices_pattern[num]}" == "Installed)" ]]; then
                        choices_pattern[num-2]="(Installed)"
                        choices_pattern[num]="(Installed)"
                        EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "baw_authoring" )
                    fi
                    ;;
                "6")
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" && "${choices_pattern[7]}" == "(To Be Uninstalled)" ]]; then
                        if [[ "${choices_pattern[5]}" == "" ]]; then
                            choices_pattern[num]="(To Be Uninstalled)"
                        elif [[ "${choices_pattern[5]}" == "(Selected)" ]]; then
                            choices_pattern[num]="(To Be Uninstalled)"
                        fi

                        # choices_pattern[num-2]="(Installed)"
                    elif  [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" && "${choices_pattern[7]}" == "" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" && "${choices_pattern[6]}" == "" ]]; then
                        choices_pattern[num]=""
                    else
                        if [[ "${choices_pattern[num]}" == "(Installed)" ]]; then
                            choices_pattern[num-2]="(To Be Uninstalled)"
                            choices_pattern[num]="(To Be Uninstalled)"
                        # If the user selects a pattern that is already uninstalled, then it would be marked as To be Uninstalled.
                        # But if they once again select that same pattern we need to mark that pattern back as Installed.
                        # https://jsw.ibm.com/browse/DBACLD-200499
                        elif [[ "${choices_pattern[num]}" == "(To Be Uninstalled)" ]]; then
                            choices_pattern[num-2]="(Installed)"
                            choices_pattern[num]="(Installed)"
                        else
                            # Original logic for other cases
                            [[ "${choices_pattern[num]}" ]] && choices_pattern[num-2]="" || choices_pattern[num-2]="(To Be Uninstalled)"
                            [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                        fi
                    fi
                    ;;
                "7")
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && "${choices_pattern[6]}" == "(To Be Uninstalled)" ]]; then
                        if [[ "${choices_pattern[5]}" == "" ]]; then
                            choices_pattern[num]="(To Be Uninstalled)"
                        elif [[ "${choices_pattern[5]}" == "(Selected)" ]]; then
                            choices_pattern[num]="(To Be Uninstalled)"
                        fi

                    elif  [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && "${choices_pattern[7]}" == "" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" && "${choices_pattern[6]}" == "" ]]; then
                        choices_pattern[num]=""
                    else
                        # Handle the case when choices_pattern[num] is "(Installed)"
                        if [[ "${choices_pattern[num]}" == "(Installed)" ]]; then
                            choices_pattern[num]="(To Be Uninstalled)"
                        # If the user selects a pattern that is already uninstalled, then it would be marked as To be Uninstalled.
                        # But if they once again select that same pattern we need to mark that pattern back as Installed.
                        # https://jsw.ibm.com/browse/DBACLD-200499
                        elif [[ "${choices_pattern[num]}" == "(To Be Uninstalled)" ]]; then
                            choices_pattern[num]="(Installed)"
                        elif [[ -n "${choices_pattern[num]}" ]]; then
                            choices_pattern[num]=""
                        else
                            choices_pattern[num]="(To Be Uninstalled)"
                        fi
                    fi
                    ;;
                "9")
                    if [[ ${choices_pattern[10]} == "(Selected)" ]]; then
                        choices_pattern[8]="(Selected)"
                    else
                        # Handle item num-1 based on the status of item num
                        if [[ "${choices_pattern[num]}" == "(Installed)" ]]; then
                            # If installed, mark for uninstallation
                            choices_pattern[num-1]="(To Be Uninstalled)"
                        # If the user selects a pattern that is already uninstalled, then it would be marked as To be Uninstalled.
                        # But if they once again select that same pattern we need to mark that pattern back as Installed.
                        # https://jsw.ibm.com/browse/DBACLD-200499
                        elif [[ "${choices_pattern[num]}" == "(To Be Uninstalled)" ]]; then
                            choices_pattern[num-1]="(Installed)"
                        elif [[ -n "${choices_pattern[num]}" ]]; then
                            # If not empty but not installed, clear it
                            choices_pattern[num-1]=""
                        else
                            # If empty, mark for uninstallation
                            choices_pattern[num-1]="(To Be Uninstalled)"
                        fi
                    fi

                    # Handle item num based on its own status
                    if [[ "${choices_pattern[num]}" == "(Installed)" ]]; then
                        # If installed, mark for uninstallation
                        choices_pattern[num]="(To Be Uninstalled)"
                        # Remove "document_processing_designer" from EXISTING_OPT_COMPONENT_ARR
                        # https://jsw.ibm.com/browse/DBACLD-200499
                        EXISTING_OPT_COMPONENT_ARR=($(remove_component "document_processing_designer" "${EXISTING_OPT_COMPONENT_ARR[@]}"))
                    # If the user selects a pattern that is already uninstalled, then it would be marked as To be Uninstalled.
                    # But if they once again select that same pattern we need to mark that pattern back as Installed.
                    # https://jsw.ibm.com/browse/DBACLD-200499
                    elif [[ "${choices_pattern[num]}" == "(To Be Uninstalled)" ]]; then
                        choices_pattern[num]="(Installed)"
                        EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "document_processing_designer" )
                    elif [[ -n "${choices_pattern[num]}" ]]; then
                        # If not empty but not installed, clear it
                        choices_pattern[num]=""
                    else
                        # If empty, mark for uninstallation
                        choices_pattern[num]="(To Be Uninstalled)"
                    fi
                    ;;
                "10")
                    if [[ ${choices_pattern[9]} == "(Selected)" ]]; then
                        # If item 9 is selected, also select item 8
                        choices_pattern[8]="(Selected)"
                    else
                        # Handle item num-2 based on the status of item num
                        if [[ "${choices_pattern[num]}" == "(Installed)" ]]; then
                            # If installed, mark for uninstallation
                            choices_pattern[num-2]="(To Be Uninstalled)"
                        # If the user selects a pattern that is already uninstalled, then it would be marked as To be Uninstalled.
                        # But if they once again select that same pattern we need to mark that pattern back as Installed.
                        # https://jsw.ibm.com/browse/DBACLD-200499
                        elif [[ "${choices_pattern[num]}" == "(To Be Uninstalled)" ]]; then
                            choices_pattern[num-2]="(Installed)"
                        elif [[ -n "${choices_pattern[num]}" ]]; then
                            # If not empty but not installed, clear it
                            choices_pattern[num-2]=""
                        else
                            # If empty, mark for uninstallation
                            choices_pattern[num-2]="(To Be Uninstalled)"
                        fi
                    fi

                    # Handle item num based on its own status
                    if [[ "${choices_pattern[num]}" == "(Installed)" ]]; then
                        # If installed, mark for uninstallation
                        choices_pattern[num]="(To Be Uninstalled)"
                        # Remove "document_processing_runtime" from EXISTING_OPT_COMPONENT_ARR
                        # https://jsw.ibm.com/browse/DBACLD-200499
                        EXISTING_OPT_COMPONENT_ARR=($(remove_component "document_processing_runtime" "${EXISTING_OPT_COMPONENT_ARR[@]}"))
                    # If the user selects a pattern that is already uninstalled, then it would be marked as To be Uninstalled.
                    # But if they once again select that same pattern we need to mark that pattern back as Installed.
                    # https://jsw.ibm.com/browse/DBACLD-200499
                    elif [[ "${choices_pattern[num]}" == "(To Be Uninstalled)" ]]; then
                        choices_pattern[num]="(Installed)"
                        EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "document_processing_runtime" )

                    elif [[ -n "${choices_pattern[num]}" ]]; then
                        # If not empty but not installed, clear it
                        choices_pattern[num]=""
                    else
                        # If empty, mark for uninstallation
                        choices_pattern[num]="(To Be Uninstalled)"
                    fi
                    ;;
                "0"|"1"|"2"|"3"|"11")
                    if [[ "${choices_pattern[num]}" == "(Installed)" ]]; then
                        # If it's specifically "(Installed)", mark for uninstallation
                        choices_pattern[num]="(To Be Uninstalled)"
                        #temp_choices_pattern[num]="True"
                    
                    # If the user selects a pattern that is already uninstalled, then it would be marked as To be Uninstalled.
                    # But if they once again select that same pattern we need to mark that pattern back as Installed.
                    # https://jsw.ibm.com/browse/DBACLD-200499
                    elif [[ "${choices_pattern[num]}" == "(To Be Uninstalled)" ]]; then
                        choices_pattern[num]="(Installed)"
                    elif [[ -n "${choices_pattern[num]}" ]]; then
                        # If non-empty but not "(Installed)", set to empty
                        choices_pattern[num]=""
                    else
                        # If empty, mark for uninstallation
                        choices_pattern[num]="(To Be Uninstalled)"
                    fi
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
    # printf '%b\n' "$msg"

    # 4Q: add workflow-workstream into pattern list when select both workflow-runtime and workstream
    # https://jsw.ibm.com/browse/DBACLD-174822 (modified if condition by changing workflow to workflow-runtime)
    if [[ " ${pattern_cr_arr[@]} " =~ "workflow-runtime" && " ${pattern_cr_arr[@]} " =~ "workstreams" && "${DEPLOYMENT_TYPE}" == "production" ]]; then
        pattern_cr_arr=( "${pattern_cr_arr[@]}" "workflow-workstreams" )
        if [[ $PLATFORM_SELECTED == "other" ]]; then
            foundation_ww=("BAN" "RR" "UMS" "AE")
        else
            foundation_ww=("BAN" "RR" "AE")
        fi
        foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_ww[@]}" )
    fi

        # Check if at least one capability is selected (marked with "(Selected)")
        containsElement "(Selected)" "${choices_pattern[@]}"
        selected_retVal=$?
        
        if [ $selected_retVal -ne 0 ] && [ "${#pattern_arr[@]}" -eq "0" ]; then
            PATTERNS_SELECTED="None"
            echo -e "\x1B[1;31mPlease select at least one capability to continue.\n\x1B[0m"
            prompt_press_any_key_to_continue
            continue
            echo ""
            # Continue the outer loop to re-display the menu
            continue
        else
            PATTERNS_SELECTED=$( IFS=$','; echo "${pattern_arr[*]}" )
            PATTERNS_CR_SELECTED=$( IFS=$','; echo "${pattern_cr_arr[*]}" )
            # Break out of the outer loop when at least one capability is selected
            break
        fi
    done
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
    # Array to Keep a track of optional components that are already installed in a deployment and the user has currently selected them to be uninstalled
    # https://jsw.ibm.com/browse/DBACLD-200504
    optional_components_removed=()
    BAI_SELECTED=""

    #Function to remove a component from an array
    #Usage: EXISTING_OPT_COMPONENT_ARR=($(remove_component "component_to_remove" "${EXISTING_OPT_COMPONENT_ARR[@]}"))
    remove_component() {
        local component_to_remove="$1"
        shift
        local result=""
        
        # Loop through all arguments (array elements)
        for item in "$@"; do
            # Add to result only if it doesn't match the component to remove
            if [[ "$item" != "$component_to_remove" ]]; then
                # Add space if not the first element
                if [[ -n "$result" ]]; then
                    result="$result $item"
                else
                    result="$item"
                fi
            fi
        done
        
        # Return the result
        echo "$result"
    }
    show_optional_components(){
        COMPONENTS_SELECTED=""
        choices_component=()
        component_arr=()

        tips1="\x1B[1;31mTips\x1B[0m: \x1B[1m Press [ENTER] if you do not want any optional components or when you are finished selecting your optional components\x1B[0m"
        tips2="\x1B[1;31mTips\x1B[0m: \x1B[1m Press [ENTER] when you are done\x1B[0m"
        fncm_tips="\x1B[1mNote: IBM Enterprise Records (IER) and IBM Content Collector for SAP (ICCSAP) do not integrate with User Management Service (UMS).\n"
        linux_starter_tips="\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mIBM Content Collector for SAP (4) does NOT support a cluster running a Linux on Power architecture.\n\x1B[0m"
        linux_production_tips="\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mIBM Content Collector for SAP (4) does NOT support a cluster running a Linux on Power architecture.\n\x1B[0m"
        ads_tips="\x1B[1mTips:\x1B[0m Decision Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present. \n\nDecision Runtime is typically recommended if you are deploying a test or production environment. \n\nYou should choose at least one these features to have a minimum environment configuration.\n ${YELLOW_TEXT} Note: You must select at least \"Decision Designer and Decision Runtime\" or \"Decision Runtime\"\n ${RESET_TEXT}"
        if [[ $DEPLOYMENT_TYPE == "starter" ]];then
            decision_tips="\x1B[1mTips:\x1B[0m Decision Center, Rule Execution Server and Decision Runner will be installed by default.\n"
        else
            decision_tips="\x1B[1mTips:\x1B[0m Decision Center is typically required for development and testing environments. \nRule Execution Server is typically required for testing and production environments and for using Business Automation Insights. \nYou should choose at least one these 2 features to have a minimum environment configuration. \n"
        fi
        application_tips_demo="\x1B[1mTips:\x1B[0m Application Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present.  \n\n\x1B[33;5mBusiness Orchestration is technical preview. \x1B[0m\n\nMake your selection or press enter to proceed. \n"
        application_tips_ent="\x1B[1mTips:\x1B[0m Application Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present. \n\nApplication Engine is automatically installed in the environment.  \n\nMake your selection or press enter to proceed. \n"

        indexof() {
            i=-1
            for ((j=0;j<${#optional_component_cr_arr[@]};j++));
            do [ "${optional_component_cr_arr[$j]}" = "$1" ] && { i=$j; break; }
            done
            echo "$i"
        }
        menu() {
            clear
            printf '%b\n' "\x1B[1;31mPattern \"$item_pattern\": \x1B[0m\x1B[1mSelect optional components: \x1B[0m"
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
                    if [[ "${item_pattern}" == "Content Cortex Essentials" || ( "${item_pattern}" == "Operational Decision Manager" && "${DEPLOYMENT_TYPE}" == "production" ) ]];then
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
                        # If the component currently being looked at already exists in EXISTING_OPT_COMPONENT_ARR that means it is currently installed on the deployment
                        # Based on the optional_components_removed array, we can display whether the optional component has installed or to be uninstalled
                        # If it is present in the array that means this component was probably showing up for another pattern and during that selection it was chosen to be uninstalled, so we make sure it still shows uninstalled
                        # If it is not present in the optional_components_removed array , that means it is Installed
                        # https://jsw.ibm.com/browse/DBACLD-200504
                        containsElement "${optional_components_cr_list[i]}" "${optional_components_removed[@]}"
                        selected_to_removeVal=$?
                        if [ $selected_to_removeVal -eq 0 ]; then
                            choices_component[i]="(To Be Uninstalled)"
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "(To Be Uninstalled)"
                        else
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "(Installed)"
                        fi
                        if [[ "${optional_components_cr_list[i]}" == "bai" ]];then
                            BAI_SELECTED="Yes"
                        fi
                    fi
                fi
            done
            if [[ "$msg" ]]; then echo "$msg"; fi
            printf "\n"

            if [[ "${item_pattern}" == "Decision Intelligence Client Managed Software" ]]; then
                printf '%b\n' "${ads_tips}"
            fi
            if [[ "${item_pattern}" == "Operational Decision Manager" ]]; then
                printf '%b\n' "\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31m You must select at least one of ODM components\x1B[0m.\n"
                printf '%b\n' "${decision_tips}"
            fi
            if [[ "${item_pattern}" == "Business Automation Application" ]]; then

                printf '%b\n' "${application_tips}"
                if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                    printf '%b\n' "${application_tips_demo}"
                elif [[ $DEPLOYMENT_TYPE == "production" ]]
                then
                    printf '%b\n' "${application_tips_ent}"
                fi
            fi

            if [[ "${item_pattern}" == "Content Cortex Essentials" ]]; then
                if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                    printf '%b\n' "${linux_starter_tips}"
                elif [[ $DEPLOYMENT_TYPE == "production" ]]
                then
                    printf '%b\n' "${linux_production_tips}"
                fi
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
        while menu && read -rp "$prompt" num && [[ "$num" ]]; do
            [[ "$num" != *[![:digit:]]* ]] &&
            (( num > 0 && num <= ${#optional_components_list[@]} )) ||
            { msg="Invalid option: $num"; continue; }
            if [[ "${item_pattern}" == "Content Cortex Essentials" && "$DEPLOYMENT_TYPE" == "production" ]]; then
                case "$num" in
                "1"|"2"|"3"|"4"|"5"|"6"|"7"|"8")
                    ((num--))
                    ;;
                esac
            elif [[ "${item_pattern}" == "Content Cortex Essentials" && "$DEPLOYMENT_TYPE" == "starter" ]]; then
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
                if [[ $PLATFORM_SELECTED == "other" && ("${item_pattern}" == "Content Cortex Essentials" || ("${item_pattern}" == "Operational Decision Manager" && "${DEPLOYMENT_TYPE}" == "production")) ]]; then
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
                    #If the component currently being looked at already exists in EXISTING_OPT_COMPONENT_ARR that means it is currently installed on the deployment
                    # Based on the optional_components_removed we can display the pattern has installed or to be uninstalled
                    # If it is present in the array that means this component was probably showing up for another pattern and during that selection it was chosen to be uninstalled
                    # https://jsw.ibm.com/browse/DBACLD-200504
                    containsElement "${optional_components_cr_list[num]}" "${optional_components_removed[@]}"
                    selected_to_removeVal=$?
                    if [ $selected_to_removeVal -ne 0 ]; then
                        choices_component[num]="(To Be Uninstalled)"
                        # Keep a track of the list of optional components that were already installed and then chosen to be removed
                        # This is so that if they show up as an optional component for another pattern it will show as uninstalled
                        optional_components_removed=( "${optional_components_removed[@]}" "${optional_components_cr_list[num]}" )
                    else
                        choices_component[num]="(Installed)"
                        # Since the optional component that was chosen to be uninstalled has been selected again, we can remove it from the array that we used because it is no longer being marked for uninstallation
                        optional_components_removed=($(remove_component "${optional_components_cr_list[num]}" "${optional_components_removed[@]}"))
                    fi
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
                elif [[ "${optional_components_list[i]}" == "Decision Designer and Decision Runtime" ]]
                then
                    # This is to make sure if Decisions Designer is selected, we automatically add Designer Runtime
                    # For https://jsw.ibm.com/browse/DBACLD-159303
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "DecisionDesigner" ); msg=""; }
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "DecisionRuntime" ); msg=""; }
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
                elif [[ "${optional_components_list[i]}" == "Content Cortex for Microsoft Office" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ContentCortexforMicrosoftOffice" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Content Integration" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ContentIntegration" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "IBM Content Navigator" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "IBMContentNavigator" ); msg=""; }
                elif [[ "${optional_components_list[i]}" == "Business Orchestration" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "BusinessOrchestration" ); msg=""; }
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
                else
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "${optional_components_list[i]}" ); msg=""; }
                fi
                [[ "${choices_component[i]}" ]] && { optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "${optional_components_cr_list[i]}" ); msg=""; }
                # This is to make sure if Decisions Designer is selected, we automatically add Designer Runtime
                # For https://jsw.ibm.com/browse/DBACLD-159303
                if [[ "${optional_components_list[i]}" == "Decision Designer and Decision Runtime" ]]; then
                    [[ "${choices_component[i]}" ]] && { optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ads_runtime" ); msg=""; }
                fi
            else
                if [[ "${choices_component[i]}" == "(To Be Uninstalled)" ]]; then
                    pos=`indexof "${optional_components_cr_list[i]}"`
                    if [[ "$pos" != "-1" ]]; then
                    { optional_component_cr_arr=(${optional_component_cr_arr[@]:0:$pos} ${optional_component_cr_arr[@]:$(($pos + 1))}); optional_component_arr=(${optional_component_arr[@]:0:$pos} ${optional_component_arr[@]:$(($pos + 1))}); }
                    fi
                else
                    choices_component[i]="(Installed)"
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
                    elif [[ "${optional_components_list[i]}" == "Decision Designer and Decision Runtime" ]]
                    then
                        # This is to make sure if Decisions Designer is selected, we automatically add Designer Runtime
                        # For https://jsw.ibm.com/browse/DBACLD-159303
                        optional_component_arr=( "${optional_component_arr[@]}" "DecisionDesigner" )
                        optional_component_arr=( "${optional_component_arr[@]}" "DecisionRuntime" )
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
                        [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "DataCollectorandDataIndexer" ); msg=""; }
                    elif [[ "${optional_components_list[i]}" == "Exposed Kafka Services" ]]
                    then
                        [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ExposedKafkaServices" ); msg=""; }
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
                    elif [[ "${optional_components_list[i]}" == "Business Orchestration" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "BusinessOrchestration" )
                    elif [[ "${optional_components_list[i]}" == "Workplace Assistant" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "WorkplaceAssistant" )
                    elif [[ "${optional_components_list[i]}" == "(Preview) Authoring Assistant" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "AuthoringAssistant" )
                    else
                        optional_component_arr=( "${optional_component_arr[@]}" "${optional_components_list[i]}" )
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "${optional_components_cr_list[i]}" )
                    # This is to make sure if Decisions Designer is selected, we automatically add Designer Runtime
                    # For https://jsw.ibm.com/browse/DBACLD-159303
                    if [[ "${optional_components_list[i]}" == "Decision Designer and Decision Runtime" ]]; then
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ads_runtime" )
                    fi
                    
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
                "Content Cortex Essentials")
                    # echo "select $item_pattern pattern optional components"
                    if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                        optional_components_list=("Content Search Services" "Content Management Interoperability Services" "IBM Enterprise Records" "IBM Content Collector for SAP" "Business Automation Insights" "Task Manager" "Content Cortex for Microsoft Office")
                        optional_components_cr_list=("css" "cmis" "ier" "iccsap" "bai" "tm" "ccxmo")
                    elif [[ $DEPLOYMENT_TYPE == "production" ]]
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
                "Decision Intelligence Client Managed Software")
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
                        # This is to make sure if Decisions Designer is selected, we automatically add Designer Runtime
                        # For https://jsw.ibm.com/browse/DBACLD-159303
                        optional_components_list=("Business Automation Insights" "Decision Designer and Decision Runtime" "Decision Runtime")
                        optional_components_cr_list=("bai" "ads_designer" "ads_runtime")
                        show_optional_components
                        optional_components_list=()
                        optional_components_cr_list=()
                    fi
                    break
                    ;;
                "Business Automation Workflow")
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "(a) Workflow Authoring")
                    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                        optional_components_list=("Application Connectors" "Business Automation Insights" "Data Collector and Data Indexer" "Exposed Kafka Services" "Workplace Assistant" "(Preview) Authoring Assistant" "Workflow Runtime MCP Server")
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
                    if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                        optional_components_list=("Application Connectors" "Business Automation Insights" "Exposed Kafka Services" "Exposed OpenSearch" "Workplace Assistant" "Workflow Runtime MCP Server")
                        optional_components_cr_list=("application_connectors" "bai" "kafka" "opensearch" "workplace_assistant" "workflow_runtime_mcp_server")
                        show_optional_components
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    # optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "bai" )
                    # optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ae_data_persistence" )
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
                    # optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ae_data_persistence" )
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
                        optional_components_list=("Business Orchestration" "IBM Content Navigator")
                        optional_components_cr_list=("business_orchestration" "ban")
                        show_optional_components
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
                        optional_components_list=("Application Connectors" "Business Automation Insights" "Data Collector and Data Indexer" "Exposed Kafka Services" "Workplace Assistant" "(Preview) Authoring Assistant" "Workflow Runtime MCP Server")
                        optional_components_cr_list=("application_connectors" "bai" "pfs" "kafka" "workplace_assistant" "workflow_assistant" "workflow_runtime_mcp_server")
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
    if [[ $retVal_ext_ldap -eq 0 && "${DEPLOYMENT_TYPE}" == "production" ]];then
        set_external_ldap
    fi
}

function check_db2_name_valid(){
    local dbname=$1
    local dbserver=$2
    local keyname=$3
    local num=$4
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    keyname=$(sed -e 's/^"//' -e 's/"$//' <<<"$keyname")

    if [ ${#dbname} -gt 8 ]; then
        if [[ $keyname == "ADP_PROJECT_DB_NAME" ]]; then
            error "The length of DB2 database name: \"$dbname\" in the number[$num] of the parameter: \"ADP_PROJECT_DB_NAME\" more than 8 characters. Please input a valid value for it, exiting ..."
        else
            error "The length of DB2 database name: \"$dbname\" for the parameter: \"$dbserver.$keyname\" more than 8 characters. Please input a valid value for it, exiting ..."
        fi
        exit 1
    fi
}

function check_dbserver_name_valid(){
    # check server name is valid or not
    local temp
    local tmp_db_array=()
    local input_servername=$1
    local parameter_name=$2
    input_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$input_servername")
    # get db alias server from DB_SERVER_LIST
    temp=$(prop_db_server_property_file DB_SERVER_LIST)
    temp=$(sed -e 's/^"//' -e 's/"$//' <<<"$temp")
    OIFS=$IFS
    IFS=',' read -ra tmp_db_array <<< "$temp"
    IFS=$OIFS

    if [[ ! ( "${input_servername}" == \#* ) ]]; then
        if [[ ! (" ${tmp_db_array[@]}" =~ "${input_servername}") ]]; then
            error "The prefix \"$input_servername\" in front of \"$parameter_name\" is not in the definition DB_SERVER_LIST=\"${temp}\", please check follow example to configure"
            printf '%b\n' "***************** example *****************"
            printf '%b\n' "if DB_SERVER_LIST=\"DBSERVER1\""
            printf '%b\n' "You need to change"
            printf '%b\n' "<DB_ALIAS_NAME>.GCD_DB_NAME=\"GCDDB\""
            printf '%b\n' "to"
            printf '%b\n' "DBSERVER1.GCD_DB_NAME=\"GCDDB\""
            printf '%b\n' "***************** example *****************"
            exit 1
        fi
    fi
}



function check_property_file(){
    local empty_value_tag=0
    local invalid_ai_services_property=0
    # Parse AI Services property file FIRST if AI Services is selected
    # This must happen before validate_ssl_certificates so that PARSED_PROVIDERS
    # array is populated for SSL certificate validation
    if [[ "$SETUP_CONTENT_CORTEX_AI_SERVICES" == "true" ]]; then
        # Source the AI services script to access parsing function
        source ${CUR_DIR}/cp4a-content-cortex-ai-services-setup.sh
        
        # Set namespace for validation
        NAMESPACE="$CP4BA_SERVICES_NS"
        
        # Parse the property file - this will validate the TOML format, provider configurations,
        # enabled providers, and default model selection
        # Note: parse_multi_provider_property_file displays specific error messages
        if ! parse_multi_provider_property_file; then
            empty_value_tag=1
            invalid_ai_services_property=1
        fi
    fi

    # Function to check for valid certificates (LDAP, DB, IM, ZEN, BTS, AI Services)
    # For https://jsw.ibm.com/browse/DBACLD-180201
    # NOTE: AI Services SSL validation now works because PARSED_PROVIDERS is populated above
    validate_ssl_certificates

    # Function to check for missing quotes in any of the property files
    # For https://jsw.ibm.com/browse/DBACLD-161426
    check_missing_quotes

    # Validate required properties in configuration files
    INFO "Validating required properties in configuration files"

    # Check <Required> values for cp4ba_user_profile.property
    check_required_values "<Required>" "${USER_PROFILE_PROPERTY_FILE}"
    ## --https://jsw.ibm.com/browse/DBACLD-158616 <- ## Check for missing "{Base64}<Required>" placeholders in the user profile property file and display an error message if not provided.>
    check_required_values "{Base64}<Required>" "${USER_PROFILE_PROPERTY_FILE}"
    ## -- https://jsw.ibm.com/browse/DBACLD-172803 - We are now asking user to use {xor} for special characters in password for some parameters, so we need to check if the "{xor}<Required>" is not filled out.
    check_required_values "{xor}<Required>" "${USER_PROFILE_PROPERTY_FILE}"

    # Change for DBACLD-190482: Mark Database SSL params optional if SSL is disabled
    # Add Database SSL parameters to OPTIONAL_PARAMETERS_LIST if DATABASE_SSL_ENABLE is "False" for each database server
    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    if [[ -n "$tmp_db_array" ]]; then
        OIFS=$IFS
        IFS=',' read -ra db_server_array <<< "$tmp_db_array"
        IFS=$OIFS

        # Remove any existing database SSL parameters from the optional list to handle toggling
        OPTIONAL_PARAMETERS_LIST=($(printf '%s\n' "${OPTIONAL_PARAMETERS_LIST[@]}" | grep -v "^.*\.DATABASE_SSL_SECRET_NAME$" | grep -v "^.*\.DATABASE_SSL_CERT_FILE_FOLDER$" | grep -v "^.*\.POSTGRESQL_SSL_CLIENT_SERVER$"))

        # Check each database server's SSL configuration
        for db_alias in "${db_server_array[@]}"; do
            db_ssl_enabled=$(prop_db_server_property_file "${db_alias}.DATABASE_SSL_ENABLE" | tr '[:upper:]' '[:lower:]')
            if [[ ${db_ssl_enabled} =~ ^(no|n|false)$ ]]; then
                OPTIONAL_PARAMETERS_LIST+=("${db_alias}.DATABASE_SSL_SECRET_NAME")
                OPTIONAL_PARAMETERS_LIST+=("${db_alias}.DATABASE_SSL_CERT_FILE_FOLDER")
                
                # For PostgreSQL, also check client-server SSL flag
                db_type=$(prop_db_server_property_file "${db_alias}.DATABASE_TYPE" | tr '[:upper:]' '[:lower:]')
                if [[ "$db_type" == "postgresql" ]]; then
                    postgresql_ssl_client_server=$(prop_db_server_property_file "${db_alias}.POSTGRESQL_SSL_CLIENT_SERVER" | tr '[:upper:]' '[:lower:]')
                    if [[ ${postgresql_ssl_client_server} =~ ^(no|n|false)$ ]]; then
                        OPTIONAL_PARAMETERS_LIST+=("${db_alias}.POSTGRESQL_SSL_CLIENT_SERVER")
                    fi
                fi
            fi
        done
        
        # Mark the database SSL parameters as optional
        mark_optional
    fi

    #DBACLD-203586: Mark any fields with "dbserver1.<xx>_DB_USER_PASSWORD" in DB_NAME_USER_PROPERTY_FILE file as optional and add into OPTIONAL_PARAMETER_LIST when is_pg_client_auth = true and DB_TYPE = postgresql
    if is_pg_client_auth && [[ $DB_TYPE == "postgresql" ]]; then
        # Search for all keys ending with _DB_USER_PASSWORD in the DB_NAME_USER_PROPERTY_FILE
        pg_password_key=$(grep -E '^[[:space:]]*[^#[:space:]]+.*_DB_USER_PASSWORD=' "${DB_NAME_USER_PROPERTY_FILE}" | awk -F'=' '{print $1}' | tr -d ' ')
        
        # Validate that all password parameters are empty and collect any that are not
        local invalid_params=()
        while IFS= read -r param; do
            if [[ -n "$param" ]]; then
                value=$(grep -E "^[[:space:]]*${param}[[:space:]]*=" "${DB_NAME_USER_PROPERTY_FILE}" 2>/dev/null | awk -F'=' '{print $2}' | tr -d '[:space:]' | tr -d '"')
                if [[ -n "${value}" ]]; then
                    invalid_params+=("${param}")
                fi
            fi
        done <<< "$pg_password_key"
        
        # If any parameters have non-empty values, display them all and exit
        if [[ ${#invalid_params[@]} -gt 0 ]]; then
            error "ERROR: The following parameters in ${DB_NAME_USER_PROPERTY_FILE} must be empty since PostgreSQL Client Authentication is enabled:"
            printf '  - %s\n' "${invalid_params[@]}"
            exit 1
        fi
        
        # Add each password parameter to OPTIONAL_PARAMETERS_LIST after all validations pass
        while IFS= read -r param; do
            if [[ -n "$param" ]]; then
                OPTIONAL_PARAMETERS_LIST+=("$param")
            fi
        done <<< "$pg_password_key"
        # Mark the database password parameters as optional
        mark_optional
    fi

    # DBACLD-244343: When the main DB is not PostgreSQL (e.g. DB2) but an external PostgreSQL is used for ADPGG/DICMS with client authentication enabled, 
	# mark only the passwords belonging to that external PostgreSQL server alias as optional (the main DB passwords are unaffected).
    if is_pg_client_auth && [[ $DB_TYPE != "postgresql" && $EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS == "true" ]]; then
        local _ext_pg_alias="$EXTERNAL_POSTGRES_SERVER_PREFIX"
        if [[ -n "$_ext_pg_alias" ]]; then
            local _ext_pg_ssl
            _ext_pg_ssl=$(prop_db_server_property_file "${_ext_pg_alias}.DATABASE_SSL_ENABLE" | tr '[:upper:]' '[:lower:]' | tr -d '"')
            local _ext_pg_client
            _ext_pg_client=$(prop_db_server_property_file "${_ext_pg_alias}.POSTGRESQL_SSL_CLIENT_SERVER" | tr '[:upper:]' '[:lower:]' | tr -d '"')
            if [[ "$_ext_pg_ssl" == "true" && ( "$_ext_pg_client" == "true" || "$_ext_pg_client" == "yes" || "$_ext_pg_client" == "y" ) ]]; then
                # Collect only password keys prefixed with the external PostgreSQL server alias
                pg_password_key=$(grep -E "^[[:space:]]*${_ext_pg_alias}\\..*_DB_USER_PASSWORD=" "${DB_NAME_USER_PROPERTY_FILE}" | awk -F'=' '{print $1}' | tr -d ' ')

                local invalid_params=()
                while IFS= read -r param; do
                    if [[ -n "$param" ]]; then
                        value=$(grep -E "^[[:space:]]*${param}[[:space:]]*=" "${DB_NAME_USER_PROPERTY_FILE}" 2>/dev/null | awk -F'=' '{print $2}' | tr -d '[:space:]' | tr -d '"')
                        if [[ -n "${value}" ]]; then
                            invalid_params+=("${param}")
                        fi
                    fi
                done <<< "$pg_password_key"

                if [[ ${#invalid_params[@]} -gt 0 ]]; then
                    error "ERROR: The following parameters in ${DB_NAME_USER_PROPERTY_FILE} must be empty since PostgreSQL Client Authentication is enabled:"
                    printf '  - %s\n' "${invalid_params[@]}"
                    exit 1
                fi

                while IFS= read -r param; do
                    if [[ -n "$param" ]]; then
                        OPTIONAL_PARAMETERS_LIST+=("$param")
                    fi
                done <<< "$pg_password_key"
                mark_optional
            fi
        fi
    fi

    # Mark LC_AD_GC_HOST and LC_AD_GC_PORT as optional before validation
    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "no") && "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then
        # Remove existing entries to prevent duplicates
        OPTIONAL_PARAMETERS_LIST=($(printf '%s\n' "${OPTIONAL_PARAMETERS_LIST[@]}" | grep -v "^LC_AD_GC_HOST$" | grep -v "^LC_AD_GC_PORT$"))
        
        ${SED_COMMAND} 's/LC_AD_GC_HOST="<Required>"/LC_AD_GC_HOST=""/g' ${LDAP_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("LC_AD_GC_HOST")
        ${SED_COMMAND} 's/LC_AD_GC_PORT="<Required>"/LC_AD_GC_PORT=""/g' ${LDAP_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("LC_AD_GC_PORT")
    fi

    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        ${SED_COMMAND} 's/LC_AD_GC_HOST="<Required>"/LC_AD_GC_HOST=""/g' ${EXTERNAL_LDAP_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("LC_AD_GC_HOST")
        ${SED_COMMAND} 's/LC_AD_GC_PORT="<Required>"/LC_AD_GC_PORT=""/g' ${EXTERNAL_LDAP_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("LC_AD_GC_PORT")
    fi

    # Mark the LDAP parameters as optional
    mark_optional

    # Check for empty values in the user profile property file
    validate_property_file_required_fields "${USER_PROFILE_PROPERTY_FILE}"

    # Check <Required> values for cp4ba_db_server.property 
    check_required_values "<Required>" "${DB_SERVER_INFO_PROPERTY_FILE}"

    # Check for empty values in the db server info property file
    validate_property_file_required_fields "${DB_SERVER_INFO_PROPERTY_FILE}"

    value_empty=`grep '^<DB_ALIAS_NAME>.' "${DB_NAME_USER_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        parameter_name=$(grep '^<DB_ALIAS_NAME>.' "${DB_NAME_USER_PROPERTY_FILE}" | awk -F'=' '{print $1}'  | tr -d ' ' | paste -sd ',' -)
        error "Please change prefix \"<DB_ALIAS_NAME>\" for parameter \"$parameter_name\" to assign database used by component to which database server or instance in property file \"${DB_NAME_USER_PROPERTY_FILE}\"."
        empty_value_tag=1
    fi

    # check DB_SERVER_LIST contains doc char
    tmp_dbservername=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
    value_empty=`echo "${tmp_dbservername}" | grep '\.' | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found dot character(.) from the value of \"DB_SERVER_LIST\" parameter in property file \"${DB_SERVER_INFO_PROPERTY_FILE}\"."
        empty_value_tag=1
    fi

    # check ADP_PROJECT_DB_SERVER contain <DB_ALIAS_NAME>
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        tmp_dbserver="$(prop_db_name_user_property_file ADP_PROJECT_DB_SERVER)"
        tmp_dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbserver")
        value_empty=`echo $tmp_dbserver | grep '<DB_ALIAS_NAME>' | wc -l`  >/dev/null 2>&1
        if [ $value_empty -ne 0 ] ; then
            error "Please change \"<DB_ALIAS_NAME>\" for \"ADP_PROJECT_DB_SERVER\" parameter to assign database used by component to which database server or instance in property file \"${DB_NAME_USER_PROPERTY_FILE}\"."
            empty_value_tag=1
        fi
    fi

    # Check <Required> values for cp4ba_db_name_user.property 
    check_required_values "<Required>" "${DB_NAME_USER_PROPERTY_FILE}"

    # Check for empty values in the db name user property file
    validate_property_file_required_fields "${DB_NAME_USER_PROPERTY_FILE}"

    ##--https://jsw.ibm.com/browse/DBACLD-168735 <- ## Ensure that only uncommented parameters trigger errors, while commented ones are ignored.
    value_empty=`grep -E '^[[:space:]]*[^#[:space:]]+.*="<yourpassword>"' "${DB_NAME_USER_PROPERTY_FILE}" | wc -l`  >&3 2>&3
    if [ $value_empty -ne 0 ] ; then
        parameter_name=$(grep -E '^[[:space:]]*[^#[:space:]]+.*="<yourpassword>"' "${DB_NAME_USER_PROPERTY_FILE}" | awk -F'=' '{print $1}'  | tr -d ' ' | paste -sd ',' -)
        error "Found invalid value(s) \"<yourpassword>\" for parameter \"$parameter_name\" in property file \"${DB_NAME_USER_PROPERTY_FILE}\", please input the correct value(s)."
        empty_value_tag=1
    fi

    ##--https://jsw.ibm.com/browse/DBACLD-168735 <- ## Ensure that only uncommented parameters trigger errors, while commented ones are ignored.
    #Extract the parameter name and include it to the error message when the property not defined in the file.
    value_empty=`grep -E '^[[:space:]]*[^#[:space:]]+.*="<youruser1>"' "${DB_NAME_USER_PROPERTY_FILE}" | wc -l`  >&3 2>&3
    if [ $value_empty -ne 0 ] ; then
        parameter_name=$(grep -E '^[[:space:]]*[^#[:space:]]+.*="<youruser1>"' "${DB_NAME_USER_PROPERTY_FILE}" | awk -F'=' '{print $1}'  | tr -d ' ' | paste -sd ',' -)
        error "Found invalid value(s) \"<youruser1>\" for parameter \"$parameter_name\" in property file \"${DB_NAME_USER_PROPERTY_FILE}\", please input the correct value(s)."
        empty_value_tag=1
    fi

    ## --https://jsw.ibm.com/browse/DBACLD-158616 <- ## Check for missing "{Base64}<yourpassword>" placeholders in the user profile property file and display an error message if not provided.>
    value_empty=`grep -E '^[[:space:]]*[^#[:space:]]+.*="{Base64}<yourpassword>"' "${DB_NAME_USER_PROPERTY_FILE}" | wc -l`  >&3 2>&3
    if [ $value_empty -ne 0 ] ; then
        parameter_name=$(grep -E '^[[:space:]]*[^#[:space:]]+.*="{Base64}<yourpassword>"' "${DB_NAME_USER_PROPERTY_FILE}" | awk -F'=' '{print $1}'  | tr -d ' ' | paste -sd ',' -)
        error "Found invalid value(s) \"{Base64}<yourpassword>\" for parameter \"$parameter_name\" in property file \"${DB_NAME_USER_PROPERTY_FILE}\", please input the correct value(s)."
        empty_value_tag=1
    fi

    if [[ "$LDAP_WFPS_AUTHORING" != "no" && "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then
        # Check <Required> values for cp4ba_LDAP.property
        check_required_values "<Required>" "${LDAP_PROPERTY_FILE}"
        ## -- https://jsw.ibm.com/browse/DBACLD-172803 - We are now asking user to use {xor} for special characters in password for some parameters, so we need to check if the "{xor}<Required>" is not filled out.
        check_required_values "{xor}<Required>" "${LDAP_PROPERTY_FILE}"
        # Check for empty values in the ldap property file
        validate_property_file_required_fields "${LDAP_PROPERTY_FILE}"
    fi

    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        check_required_values "<Required>" "${EXTERNAL_LDAP_PROPERTY_FILE}"
        # Check for empty values in the external ldap property file
        validate_property_file_required_fields "${EXTERNAL_LDAP_PROPERTY_FILE}"
    fi

    if [[ "$SETUP_CONTENT_CORTEX_AI_SERVICES" == "true" ]]; then
        # Check <Required> values for cp4ba_ai_services.property property file
        # Note: Property file was already parsed earlier (before SSL validation)
        # so we just need to check for required values here
        check_required_values "<Required>" "${AI_SERVICES_PROPERTY_FILE}"
        
        if [[ "$empty_value_tag" != "1" && "$invalid_ai_services_property" != "1" ]]; then
            success "All required properties in ${AI_SERVICES_PROPERTY_FILE} have valid values."
        else
            error "Please review the above listed issues with the Content Cortex AI Services property file located at ${AI_SERVICES_PROPERTY_FILE}"
        fi
    fi

    # check prefix in db property is correct element of DB_SERVER_LIST
    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    # check DB_NAME_USER_PROPERTY_FILE
    prefix_array=($(grep '=\"' ${DB_NAME_USER_PROPERTY_FILE} | grep -v '^[[:space:]]*#' | cut -d'=' -f1 | cut -d'.' -f1 | grep -Ev 'ADP_PROJECT_DB_NAME|ADP_PROJECT_DB_SERVER|ADP_PROJECT_DB_USER_NAME|ADP_PROJECT_DB_USER_PASSWORD|ADP_PROJECT_ONTOLOGY'))
    for item in ${prefix_array[*]}
    do
        if [[ ! ( "${item}" == \#* ) ]]; then
            if [[ ! (" ${db_server_array[@]}" =~ "${item}") ]]; then
                error "The prefix \"$item\" is not in the definition DB_SERVER_LIST=\"${tmp_db_array}\", please check follow example to configure \"${DB_NAME_USER_PROPERTY_FILE}\" again."
                printf '%b\n' "***************** example *****************"
                printf '%b\n' "if DB_SERVER_LIST=\"DBSERVER1\""
                printf '%b\n' "You need to change"
                printf '%b\n' "<DB_ALIAS_NAME>.GCD_DB_NAME=\"GCDDB\""
                printf '%b\n' "to"
                printf '%b\n' "DBSERVER1.GCD_DB_NAME=\"GCDDB\""
                printf '%b\n' "***************** example *****************"
                empty_value_tag=1
                break
            fi
        fi
    done

    # check DB_SERVER_INFO_PROPERTY_FILE
    prefix_array=($(grep '=\"' ${DB_SERVER_INFO_PROPERTY_FILE} | cut -d'=' -f1 | cut -d'.' -f1 | tail -n +2))
    for item in ${prefix_array[*]}
    do
        if [[ ! (" ${db_server_array[@]}" =~ "${item}") ]]; then
            error "The prefix \"$item\" is not in the definition DB_SERVER_LIST=\"${tmp_db_array}\", please check follow example to configure \"${DB_SERVER_INFO_PROPERTY_FILE}\" again."
            printf '%b\n' "********************* example *********************"
            printf '%b\n' "if DB_SERVER_LIST=\"DBSERVER1\""
            printf '%b\n' "You need to change"
            printf '%b\n' "<DB_ALIAS_NAME>.DATABASE_SERVERNAME=\"samplehost\""
            printf '%b\n' "to"
            printf '%b\n' "DBSERVER1.DATABASE_SERVERNAME=\"samplehost\""
            printf '%b\n' "********************* example *********************"
            empty_value_tag=1
            break
        fi
    done

    if [[ "$empty_value_tag" == "1" ]]; then
        clean_up_temp_file
        exit 1
    fi


    # Check the PostgreSQL DATABASE_SSL_ENABLE/POSTGRESQL_SSL_CLIENT_SERVER
    for item in ${db_server_array[*]}
    do
        db_ssl_flag="$(prop_db_server_property_file ${item}.DATABASE_SSL_ENABLE)"
        client_auth_flag="$(prop_db_server_property_file ${item}.POSTGRESQL_SSL_CLIENT_SERVER)"
        db_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$db_ssl_flag")
        client_auth_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$client_auth_flag")
        db_ssl_flag_tmp=$(echo "$db_ssl_flag" | tr '[:upper:]' '[:lower:]')
        client_auth_flag_tmp=$(echo "$client_auth_flag" | tr '[:upper:]' '[:lower:]')
        if [[ ($db_ssl_flag_tmp == "no" || $db_ssl_flag_tmp == "false" || $db_ssl_flag_tmp == "" || -z $db_ssl_flag_tmp) && ($client_auth_flag_tmp == "yes" || $client_auth_flag_tmp == "true") ]]; then
            error "The property \"${item}.DATABASE_SSL_ENABLE\" is \"$db_ssl_flag\", but the property \"${item}.POSTGRESQL_SSL_CLIENT_SERVER\" is \"$client_auth_flag\""
            printf '%b\n' "********************* example *********************"
            printf '%b\n' "if ${item}.DATABASE_SSL_ENABLE=\"False\""
            printf '%b\n' "You also need to change"
            printf '%b\n' "${item}.POSTGRESQL_SSL_CLIENT_SERVER=\"False\""
            printf '%b\n' "********************* example *********************"
            error_value_tag=1
        fi
    done

    # Check the IPv6 address in DATABASE_SERVERNAME is enclosed with the square brackets.
    for item in ${db_server_array[*]}
    do
        server_name="$(prop_db_server_property_file ${item}.DATABASE_SERVERNAME)"
        server_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$server_name")

        #Finding the db type
        db_type="$(prop_db_server_property_file ${item}.DATABASE_TYPE)"
        db_type=$(sed -e 's/^"//' -e 's/"$//' <<<"$db_type")

        if [[ ! -z $server_name ]]; then
            if [[ ${server_name:1:${#server_name}-2} =~ ^([0-9a-fA-F]{1,4}:).*[0-9a-fA-F]{1,4}$ ]]; then
                # Regular expression to match IPv6 address format with square brackets
                if [[ ! $server_name =~ ^\[(::|[0-9a-fA-F]{1,4}:.*(:[0-9a-fA-F]{1,4}))\]$ ]]; then
                    error "The IPv6 address ${server_name} must be enclosed with square brackets ([...]) for the property DATABASE_SERVERNAME in the file \"${DB_SERVER_INFO_PROPERTY_FILE}\""
                    error_value_tag=1
                fi
            elif [[ ${server_name:0:1} == "[" ]] ; then
                # For IPv4 addresses, make sure they have not included brackets
                error "The IPv4 address ${server_name} should NOT be enclosed with square brackets ([...]) for the property DATABASE_SERVERNAME in the file \"${DB_SERVER_INFO_PROPERTY_FILE}\""
                error_value_tag=1
            fi
        fi
    done

    # check BAN.LTPA_PASSWORD same as CONTENT.LTPA_PASSWORD
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        content_tmp_ltpapwd="$(prop_user_profile_property_file CONTENT.LTPA_PASSWORD)"
        ban_tmp_ltpapwd="$(prop_user_profile_property_file BAN.LTPA_PASSWORD)"
        content_tmp_ltpapwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$content_tmp_ltpapwd")
        ban_tmp_ltpapwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$ban_tmp_ltpapwd")

        if [[ (! -z "$content_tmp_ltpapwd") && (! -z "$ban_tmp_ltpapwd") ]]; then
            if [[ "$ban_tmp_ltpapwd" != "$content_tmp_ltpapwd" ]]; then
                fail "The CONTENT.LTPA_PASSWORD: \"$content_tmp_ltpapwd\" is NOT equal to BAN.LTPA_PASSWORD: \"$ban_tmp_ltpapwd\"."
                echo "The value of CONTENT.LTPA_PASSWORD must be equal to the value of BAN.LTPA_PASSWORD."
                error_value_tag=1
            fi
        else
            if [[ -z "$content_tmp_ltpapwd" ]]; then
                fail "The CONTENT.LTPA_PASSWORD is empty, it is required one valid value."
                error_value_tag=1
            fi
            if [[ -z "$ban_tmp_ltpapwd" ]]; then
                fail "The BAN.LTPA_PASSWORD is empty, it is required one valid value."
                error_value_tag=1
            fi
        fi
    fi

    # Check keystorePassword in ibm-fncm-secret and ibm-ban-secret must exceed 16 characters when fips enabled.
    fips_flag="$(prop_user_profile_property_file CP4BA.ENABLE_FIPS)"
    fips_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$fips_flag")
    fips_flag=$(echo "$fips_flag" | tr '[:upper:]' '[:lower:]')

    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        if [[ (! -z $fips_flag) && $fips_flag == "true" ]]; then
            content_tmp_keystorepwd="$(prop_user_profile_property_file CONTENT.KEYSTORE_PASSWORD)"
            if [[ ! -z $content_tmp_keystorepwd ]]; then
                content_tmp_keystorepwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$content_tmp_keystorepwd")
                if [[ ${#content_tmp_keystorepwd} -lt 16 ]]; then
                    fail "CONTENT.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled in cp4ba_user_profile.property."
                    error_value_tag=1
                fi
            fi
        fi
    fi

    if [[ " ${foundation_component_arr[@]}" =~ "BAN" ]]; then
        if [[ (! -z $fips_flag) && $fips_flag == "true" ]]; then
            ban_tmp_keystorepwd="$(prop_user_profile_property_file BAN.KEYSTORE_PASSWORD)"
            if [[ ! -z $ban_tmp_keystorepwd ]]; then
                ban_tmp_keystorepwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$ban_tmp_keystorepwd")
                if [[ ${#ban_tmp_keystorepwd} -lt 16 ]]; then
                    fail "BAN.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled in cp4ba_user_profile.property."
                    error_value_tag=1
                fi
            fi
        fi
    fi

    if [[ " ${optional_component_cr_arr[@]}" =~ "iccsap" ]]; then
        if [[ (! -z $fips_flag) && $fips_flag == "true" ]]; then
            iccsap_tmp_keystorepwd="$(prop_user_profile_property_file ICCSAP.KEYSTORE_PASSWORD)"
            if [[ ! -z $iccsap_tmp_keystorepwd ]]; then
                iccsap_tmp_keystorepwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$iccsap_tmp_keystorepwd")
                if [[ ${#iccsap_tmp_keystorepwd} -lt 16 ]]; then
                    fail "ICCSAP.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled in cp4ba_user_profile.property."
                    error_value_tag=1
                fi
            fi
        fi
    fi

    if [[ " ${optional_component_cr_arr[@]}" =~ "ier" ]]; then
        if [[ (! -z $fips_flag) && $fips_flag == "true" ]]; then
            ier_tmp_keystorepwd="$(prop_user_profile_property_file IER.KEYSTORE_PASSWORD)"
            if [[ ! -z $ier_tmp_keystorepwd ]]; then
                ier_tmp_keystorepwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$ier_tmp_keystorepwd")
                if [[ ${#ier_tmp_keystorepwd} -lt 16 ]]; then
                    fail "IER.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled in cp4ba_user_profile.property."
                    error_value_tag=1
                fi
            fi
        fi
    fi

    # Check the directory for certificate should be different for IM/Zen/BTS/cp4ba_tls_issuer
    # IM metastore external Postgres DB
    cert_dir_array=()
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_IM_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        im_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        im_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$im_external_db_cert_folder")
        cert_dir_array=( "${cert_dir_array[@]}" "${im_external_db_cert_folder}" )
    fi

    # Zen metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_ZEN_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        zen_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        zen_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$zen_external_db_cert_folder")
        cert_dir_array=( "${cert_dir_array[@]}" "${zen_external_db_cert_folder}" )
    fi

    # BTS metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_BTS_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        bts_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        bts_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$bts_external_db_cert_folder")
        cert_dir_array=( "${cert_dir_array[@]}" "${bts_external_db_cert_folder}" )
    fi

    # ADPGG/DICMS external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        adpgg_dicmis_external_db_cert_folder="${DB_SSL_CERT_FOLDER}/${EXTERNAL_POSTGRES_SERVER_PREFIX}"
        cert_dir_array=( "${cert_dir_array[@]}" "${adpgg_dicmis_external_db_cert_folder}" )
    fi

    # Issuer to make Opensearch/Kafka use external certificate
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_CERT_OPENSEARCH_KAFKA_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        external_cert_issuer_folder="$(prop_user_profile_property_file CP4BA.EXTERNAL_ROOT_CA_FOR_OPENSEARCH_KAFKA_FOLDER)"
        external_cert_issuer_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$external_cert_issuer_folder")
        cert_dir_array=( "${cert_dir_array[@]}" "${external_cert_issuer_folder}" )
    fi

    declare -A dir_count
    for element in "${cert_dir_array[@]}"; do
        # Skip empty elements
        if [[ -z "$element" ]]; then
            continue
        fi
        if [[ -n "${dir_count[$element]}" ]]; then
            dir_count[$element]=$((dir_count[$element] + 1))
        else
            dir_count[$element]=1
        fi
    done

    duplicates_dir_found="No"
    for element in "${!dir_count[@]}"; do
        if [[ ${dir_count[$element]} -gt 1 ]]; then
            duplicates_dir_found="Yes"
        fi
    done

    if [[ $duplicates_dir_found == "Yes" ]]; then
        error_value_tag=1
        error "Found the same directory is used for below certificate folder's property."
        if [[ ! -z $im_external_db_cert_folder ]]; then
            msg "CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER: \"$im_external_db_cert_folder\""
        fi
        if [[ ! -z $im_external_db_cert_folder ]]; then
            msg "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER: \"$zen_external_db_cert_folder\""
        fi
        if [[ ! -z $im_external_db_cert_folder ]]; then
            msg "CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER: \"$bts_external_db_cert_folder\""
        fi
        if [[ ! -z $im_external_db_cert_folder ]]; then
            msg "CP4BA.EXTERNAL_ROOT_CA_FOR_OPENSEARCH_KAFKA_FOLDER: \"$external_cert_issuer_folder\""
        fi
        warning "You need to use different directory for above certificate folder's property."

    fi

    if [[ "$error_value_tag" == "1" || "$SSL_CERT_ERROR_TAG" == "true" || "$MISSING_REQUIRED_PARAMETERS" == "true" ]]; then
        clean_up_temp_file
        exit 1
    fi
}

function check_single_quotes_password() {
    local temp_pwd=$1
    local variable_name=$2
    temp_pwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$temp_pwd")
    variable_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$variable_name")
    if [[ $temp_pwd == *"'"* ]]; then
        fail "Found single quotes (') in \"$variable_name\". Exiting..."
        warning "DO NOT use special character single quotes (') in the password."
        exit 1
    fi
}

function create_prerequisites() {
    rm -rf $SECRET_FILE_FOLDER
    INFO "Generating YAML templates for all secrets required by CP4BA deployment based on patterns and components selected as part of property mode."
    printf "\n"
    wait_msg "Creating YAML templates for secrets"

    # DBACLD-217419: Support shared secrets in Vault
    setup_vault_settings  # check and set the vault settings (eg. vault_enabled, vault_role, vault_address, vault_path)
    create_shared_secrets_vault_templates

    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "no") && "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then

        tmp_ldapuser="$(prop_ldap_property_file LDAP_BIND_DN)"
        tmp_ldapuserpwd="$(prop_ldap_property_file LDAP_BIND_DN_PASSWORD)"

        if [[ $vault_enabled == 'true' ]]; then
            wait_msg "Creating ldap-bind-secret JSON template and SecretProviderClass template for Vault"
            create_ldap_secret_vault_template "$tmp_ldapuser" "$tmp_ldapuserpwd" 
        else
        # Create LDAP bind secret for non-vault
            create_ldap_secret_template
            ${YQ_CMD} -i ".stringData.ldapUsername = \"$tmp_ldapuser\"" "${LDAP_SECRET_FILE}"
        # For https://jsw.ibm.com/browse/DBACLD-157020
        # Function that updates the secret template with the base64 password
        # update_secret_template_passwords "$tmp_ldapuserpwd" "ldapPassword" "$LDAP_SECRET_FILE"
            update_secret_template_passwords "$tmp_ldapuserpwd" "ldapPassword" "$LDAP_SECRET_FILE"
        fi
        #  replace ldap user
        # tmp_ldapuser="$(prop_ldap_property_file LDAP_BIND_DN)"
        # ${YQ_CMD} w -i "${LDAP_SECRET_FILE}" "stringData.ldapUsername" "$tmp_ldapuser"

        # tmp_ldapuserpwd="$(prop_ldap_property_file LDAP_BIND_DN_PASSWORD)"

        # For https://jsw.ibm.com/browse/DBACLD-157020
        # Function that updates the secret template with the base64 password
        # update_secret_template_passwords "$tmp_ldapuserpwd" "ldapPassword" "$LDAP_SECRET_FILE"

        # Create LDAP bind secret for external share
        if [[ $SET_EXT_LDAP == "Yes" ]]; then
            create_ext_ldap_secret_template
            #  replace ldap user
            tmp_ldapuser="$(prop_ext_ldap_property_file LDAP_BIND_DN)"
            ${YQ_CMD} -i ".stringData.ldapUsername = \"$tmp_ldapuser\"" "${EXT_LDAP_SECRET_FILE}"

            tmp_ldapuserpwd="$(prop_ext_ldap_property_file LDAP_BIND_DN_PASSWORD)"
            # For https://jsw.ibm.com/browse/DBACLD-157020
            # Function that updates the secret template with the base64 password
            update_secret_template_passwords "$tmp_ldapuserpwd" "ldapPassword" "$EXT_LDAP_SECRET_FILE"

        fi
    fi

    # -------------------------------------
    # Create FNCM secret (ibm-fncm-secret)
    # -------------------------------------
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then

        # get server/instance for GCD
        tmp_gcd_db_servername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
        tmp_gcd_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_gcd_db_servername")

        check_dbserver_name_valid $tmp_gcd_db_servername "GCD_DB_USER_NAME"

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file GCD_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
        fi

        # create_fncm_secret_template $tmp_gcd_db_servername

        # replace appLoginUsername/appLoginPassword
        tmp_appuser="$(prop_user_profile_property_file CONTENT.APPLOGIN_USER)"
        tmp_apppwd="$(prop_user_profile_property_file CONTENT.APPLOGIN_PASSWORD)"

        # replace ltpaPassword/keystorePassword for Content Cortex
        tmp_ltpapwd="$(prop_user_profile_property_file CONTENT.LTPA_PASSWORD)"
        tmp_kestorepwd="$(prop_user_profile_property_file CONTENT.KEYSTORE_PASSWORD)"

        #  replace gcddb user
        tmp_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_gcd_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi
        #DBACLD-194917: For EDB, we will need to read the password.
        if [[ (! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" )) || ($DB_TYPE == "postgresql-edb") ]]; then
            # ${SED_COMMAND} '/^  gcdDBPassword/d' ${FNCM_SECRET_FILE}
            tmp_dbuserpwd="$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)"
        fi
        # support multiple db server/instance in ibm-fncm-secret
        # add dc_os_lable in ibm-fncm-secret for final cr
        # add os
        nl=$'\n' # fix sed issue on Mac, DO NOT change the script format

        # DBACLD-185209: Vault implementation for ibm-fncm-secret
        if [[ $vault_enabled == "true" ]]; then # Vault-enabled
            # --- Start of Vault scenario for "ibm-fncm-secret" ----
            wait_msg "Creating Content Cortex secret JSON template and SecretProviderClass template for Vault"
            create_fncm_secret_vault_template "$tmp_gcd_db_servername"
            # --- end of Vault scenario for "ibm-fncm-secret" ----
        else 
            # --- Start of Non-vault scenario for "ibm-fncm-secret" ----
            wait_msg "Creating the YAML secret template for Content Cortex" 
            create_fncm_secret_template "$tmp_gcd_db_servername"

            ${YQ_CMD} -i ".stringData.appLoginUsername = \"$tmp_appuser\"" "${FNCM_SECRET_FILE}"

            # DBACLD-157020: Function that updates the secret template with the base64 password
            update_secret_template_passwords "$tmp_apppwd" "appLoginPassword" "$FNCM_SECRET_FILE"
            update_secret_template_passwords "$tmp_ltpapwd" "ltpaPassword" "$FNCM_SECRET_FILE"
            update_secret_template_passwords "$tmp_kestorepwd" "keystorePassword" "$FNCM_SECRET_FILE"
            ${YQ_CMD} -i ".stringData.gcdDBUsername = \"$tmp_dbuser\"" "${FNCM_SECRET_FILE}"

            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ) && $DB_TYPE != "postgresql-edb" ]]; then
                ${SED_COMMAND} '/^  gcdDBPassword/d' ${FNCM_SECRET_FILE}
            else
                # DBACLD-157020: Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_dbuserpwd" "gcdDBPassword" "$FNCM_SECRET_FILE"
            fi

            #Calling add_content_os_dynamically in the helper function
            add_content_os_dynamically "$vault_enabled" "$content_os_number" "" ""
            
            # END OF base case for "ibm-fncm-secret".  There are more conditional "ibm-fncm-secret" modifications below.

            # ---------------------------------------------
            # "ibm-fncm-secret": add "aeos" user/pwd
            # ---------------------------------------------
            if [[ "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
                # Use helper func to set var "aeos_postgresql_client_flag"
                get_postgresql_client_flag "AEOS_DB_USER_NAME" "aeos_postgresql_client_flag" "false"

                #  replace aeos user
                tmp_dbuserpwd="$(prop_db_name_user_property_file AEOS_DB_USER_PASSWORD)"
                tmp_dbuser="$(prop_db_name_user_property_file AEOS_DB_USER_NAME)"
                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret, the below condition adds the password for POSTGRESQL_SSL_CLIENT_SERVER as false. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                if [[ ! ($aeos_postgresql_client_flag == "true" || $aeos_postgresql_client_flag == "yes" || $aeos_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
                    # DBACLD-157020: Function that updates the secret template with the base64 password
                    update_secret_template_passwords "$tmp_dbuserpwd" "osDBPassword" "$FNCM_SECRET_FILE" "aeosDBPassword"
                fi
                ${YQ_CMD} -i ".stringData.aeosDBUsername = \"$tmp_dbuser\"" "${FNCM_SECRET_FILE}"
            fi
                  
            # --------------------------------------------
            # "ibm-fncm-secret": add baw authoring/ baw runtime / bas+ aws os
            # --------------------------------------------
            if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workflow-runtime" ]]; then
                for i in "${!BAW_AUTH_OS_ARR[@]}"; do
                    # get server/instance for OS
                    tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                    tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
                    check_dbserver_name_valid $tmp_os_db_servername "${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME"

                    # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
                    if [[ $DB_TYPE = "postgresql" ]]; then
                        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                        tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
                    fi

                    if [[ $DB_TYPE = "postgresql-edb" ]]; then
                        tmp_postgresql_client_flag="true"
                    fi

                    tmp_dbuser="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                    tmp_val=$(echo "${BAW_AUTH_OS_ARR[i]}" | tr '[:upper:]' '[:lower:]')
                    tmp_dbuserpwd="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD)"
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
                        # For https://jsw.ibm.com/browse/DBACLD-157020
                        # Function that updates the secret template with the base64 password
                        update_secret_template_passwords "$tmp_dbuserpwd" "osDBPassword" "$FNCM_SECRET_FILE" "${tmp_val}DBPassword"
                    fi
                    ${YQ_CMD} -i ".stringData.${tmp_val}DBUsername = \"$tmp_dbuser\"" "${FNCM_SECRET_FILE}"

                    # TODO: Add vault support for "BAW_AUTH_OS_ARR" in "common_functions_vault.sh" in "function create_fncm_secret_vault_template"
                done

                if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
                    # get server/instance for OS
                    tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
                    tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
                    check_dbserver_name_valid $tmp_os_db_servername "AWSDOCS_DB_USER_NAME"

                    # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
                    if [[ $DB_TYPE = "postgresql" ]]; then
                        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                        tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
                    fi

                    if [[ $DB_TYPE = "postgresql-edb" ]]; then
                        tmp_postgresql_client_flag="true"
                    fi

                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWSDOCS_DB_USER_PASSWORD)"
                    tmp_dbuser="$(prop_db_name_user_property_file AWSDOCS_DB_USER_NAME)"
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
                        # For https://jsw.ibm.com/browse/DBACLD-157020
                        # Function that updates the secret template with the base64 password
                        update_secret_template_passwords "$tmp_dbuserpwd" "osDBPassword" "$FNCM_SECRET_FILE" "awsdocsDBPassword"
                    fi
                    ${YQ_CMD} -i ".stringData.awsdocsDBUsername = \"$tmp_dbuser\"" "${FNCM_SECRET_FILE}"
                fi

                # TODO: Add vault support for "AWS doc" in "common_functions_vault.sh" in "function create_fncm_secret_vault_template"
            fi

            # --------------------------------------------
            # "ibm-fncm-secret": add AWS os
            # --------------------------------------------
            if [[ " ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams") ]]; then
                # get server/instance for OS
                tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
                tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
                check_dbserver_name_valid $tmp_os_db_servername "AWSDOCS_DB_USER_NAME"

                # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
                if [[ $DB_TYPE = "postgresql" ]]; then
                    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                    tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
                fi

                if [[ $DB_TYPE = "postgresql-edb" ]]; then
                    tmp_postgresql_client_flag="true"
                fi

                tmp_dbuserpwd="$(prop_db_name_user_property_file AWSDOCS_DB_USER_PASSWORD)"
                tmp_dbuser="$(prop_db_name_user_property_file AWSDOCS_DB_USER_NAME)"
                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
                    # For https://jsw.ibm.com/browse/DBACLD-157020
                    # Function that updates the secret template with the base64 password
                    update_secret_template_passwords "$tmp_dbuserpwd" "osDBPassword" "$FNCM_SECRET_FILE" "awsdocsDBPassword"
                fi
                ${YQ_CMD} -i ".stringData.awsdocsDBUsername = \"$tmp_dbuser\"" "${FNCM_SECRET_FILE}"

                # TODO: Add vault support for "AWS doc" in "common_functions_vault.sh" in "function create_fncm_secret_vault_template"
            fi

            # --------------------------------------------
            # "ibm-fncm-secret": add Case History os
            # --------------------------------------------
            if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
                # get server/instance for OS
                tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name CHOS_DB_USER_NAME)"
                tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")

                if [[ $tmp_os_db_servername != \#* ]] ; then
                    check_dbserver_name_valid $tmp_os_db_servername "CHOS_DB_USER_NAME"

                    # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
                    if [[ $DB_TYPE = "postgresql" ]]; then
                        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                        tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
                    fi

                    if [[ $DB_TYPE = "postgresql-edb" ]]; then
                        tmp_postgresql_client_flag="true"
                    fi

                    tmp_dbuserpwd="$(prop_db_name_user_property_file CHOS_DB_USER_PASSWORD)"
                    tmp_dbuser="$(prop_db_name_user_property_file CHOS_DB_USER_NAME)"
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
                        # For https://jsw.ibm.com/browse/DBACLD-157020
                        # Function that updates the secret template with the base64 password
                        update_secret_template_passwords "$tmp_dbuserpwd" "osDBPassword" "$FNCM_SECRET_FILE" "chDBPassword"
                    fi
                    ${YQ_CMD} -i ".stringData.chDBUsername = \"$tmp_dbuser\"" "${FNCM_SECRET_FILE}"
                fi

                # TODO: Add vault support for "case history" in "common_functions_vault.sh" in "function create_fncm_secret_vault_template"
            fi

            # --------------------------------------------
            # "ibm-fncm-secret": add "devos" for ADP
            # --------------------------------------------
            if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
                # Use helper func to set var "devos_postgresql_client_flag"
                get_postgresql_client_flag "DEVOS_DB_USER_NAME" "devos_postgresql_client_flag" "false"

                tmp_dbuserpwd="$(prop_db_name_user_property_file DEVOS_DB_USER_PASSWORD)"
                tmp_dbuser="$(prop_db_name_user_property_file DEVOS_DB_USER_NAME)"
                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                if [[ ! ($devos_postgresql_client_flag == "true" || $devos_postgresql_client_flag == "yes" || $devos_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
                    # DBACLD-157020: Function that updates the secret template with the base64 password
                    update_secret_template_passwords "$tmp_dbuserpwd" "osDBPassword" "$FNCM_SECRET_FILE" "devos1DBPassword"
                fi
                ${YQ_CMD} -i ".stringData.devos1DBUsername = \"$tmp_dbuser\"" "${FNCM_SECRET_FILE}"           
            fi  


            # THe template for the content cortex secret(fncm secret) contains osDBPassword and osDBPassword but the script will make updates to update the key accordingly
            # No version of the secret will contain the key osDBPassword and osDBPassword so we do not need to retain the password even for postgres EDB
            # There was a condition to not remove it for edb/cnpg in DBACLD-194917 , but since this username password combination is never actually used it can be removed in all cases
            # Condition removed for https://jsw.ibm.com/browse/DBACLD-244031
            ${SED_COMMAND} '/^  osDBUsername/d' ${FNCM_SECRET_FILE}
            ${SED_COMMAND} '/^  osDBPassword/d' ${FNCM_SECRET_FILE}
            
            success "YAML secret template for Content Cortex has been created.\n"

            # --- End of Non-vault scenario for "ibm-fncm-secret" ----
        fi 
        # --------- End of create FNCM secret (ibm-fncm-secret) -----------


        # --------------------------------------------
        # Create "ibm-iccsap-secret"
        # --------------------------------------------
        if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
            # replace keystorePassword for ICCSAP
            tmp_keystorepwd="$(prop_user_profile_property_file ICCSAP.KEYSTORE_PASSWORD)"

            #DBACLD-185209: Vault's implementation for ibm-iccsap-secret
            if [[ $vault_enabled == 'true' ]]; then
                wait_msg "Creating ibm-iccsap-secret JSON template and SecretProviderClass template for Vault"
                tmp_keystorepwd="$(decode_base64_password "$tmp_keystorepwd")"
                create_fncm_iccsap_secret_vault_template "$tmp_keystorepwd"
            else #Non-vault
                wait_msg "Creating ibm-iccsap-secret secret YAML template for CP4BA"
                create_fncm_iccsap_secret_template
                # For https://jsw.ibm.com/browse/DBACLD-157020
                # Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_keystorepwd" "keystorePassword" "$FNCM_ICCSAP_SECRET_FILE"

                success "ibm-iccsap-secret secret YAML template for CP4BA has been created.\n"
            fi
        fi

        # --------------------------------------------
        # Create "ibm-icc-secret"
        # --------------------------------------------
        # If select ICC Archive
        if [[ " ${optional_component_cr_arr[@]} " =~ "css" ]]; then
            # create_fncm_icc_secret_template

            # replace keystorePassword for ICCSAP
            tmp_archive_id="$(prop_user_profile_property_file CONTENT.ARCHIVE_USER_ID)"
            # ${YQ_CMD} w -i "${FNCM_ICC_SECRET_FILE}" "stringData.archiveUserId" "$tmp_archive_id"

            tmp_archive_pwd="$(prop_user_profile_property_file CONTENT.ARCHIVE_USER_PASSWORD)"
            # For https://jsw.ibm.com/browse/DBACLD-157020
            # Function that updates the secret template with the base64 password
            # update_secret_template_passwords "$tmp_archive_pwd" "archivePassword" "$FNCM_ICC_SECRET_FILE"
            
            #DBACLD-185209: Vault's implementation for ibm-icc-secret           
            if [[ $vault_enabled == 'true' ]]; then
                wait_msg "Creating ibm-icc-secret JSON template and SecretProviderClass template for Vault"
                tmp_archive_pwd="$(decode_base64_password "$tmp_archive_pwd")"
                create_fncm_icc_secret_vault_template "$tmp_archive_id" "$tmp_archive_pwd"

            else #Non-vault
                wait_msg "Creating ibm-icc-secret secret YAML template for CP4BA"
                create_fncm_icc_secret_template
                ${YQ_CMD} -i ".stringData.archiveUserId = \"$tmp_archive_id\"" "${FNCM_ICC_SECRET_FILE}"
                update_secret_template_passwords "$tmp_archive_pwd" "archivePassword" "$FNCM_ICC_SECRET_FILE"

            fi

        fi

        # --------------------------------------------
        # Create "ibm-ier-secret"
        # --------------------------------------------
        # if select IER
        if [[ " ${optional_component_cr_arr[@]} " =~ "ier" ]]; then
            # replace keystorePassword for IER
            tmp_kestorepwd="$(prop_user_profile_property_file IER.KEYSTORE_PASSWORD)"

            #DBACLD-185209: Vault's implementation for ibm-ier-secret
            if [[ $vault_enabled == 'true' ]]; then
                wait_msg "Creating ibm-ier-secret JSON template and SecretProviderClass template for Vault"
                tmp_kestorepwd="$(decode_base64_password "$tmp_kestorepwd")"
                create_fncm_ier_secret_vault_template "$tmp_kestorepwd"

            else #Non-vault
                wait_msg "Creating ibm-ier-secret secret YAML template for CP4BA"
                create_fncm_ier_secret_template
                # For https://jsw.ibm.com/browse/DBACLD-157020
                # Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_kestorepwd" "keystorePassword" "$FNCM_IER_SECRET_FILE"

                success "ibm-ier-secret secret YAML template for CP4BA has been created.\n"
            fi
        fi

    fi 
    # -------- End of FNCM-related secrets creation ---------

    # -----------------------------------
    # Create BAN secret
    # -----------------------------------
    if [[ " ${foundation_component_arr[@]}" =~ "BAN" ]]; then
        if [[ ! (" ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "1") ]]; then


            # get server/instance for ICN
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
            tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
            check_dbserver_name_valid $tmp_dbservername "ICN_DB_USER_NAME"

            # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
            if [[ $DB_TYPE = "postgresql" ]]; then
                tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
                tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
            fi

            if [[ $DB_TYPE = "postgresql-edb" ]]; then
                tmp_postgresql_client_flag="true"
            fi

            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file ICN_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
            fi

            # create_ban_secret_template $tmp_dbname $tmp_dbservername

            # replace appLoginUsername/appLoginPassword
            tmp_appuser="$(prop_user_profile_property_file BAN.APPLOGIN_USER)"
            tmp_apppwd="$(prop_user_profile_property_file BAN.APPLOGIN_PASSWORD)"

            # replace ltpaPassword/keystorePassword for Content Cortex
            tmp_ltpapwd="$(prop_user_profile_property_file BAN.LTPA_PASSWORD)"
            tmp_kestorepwd="$(prop_user_profile_property_file BAN.KEYSTORE_PASSWORD)"

            # replace ltpaPassword/keystorePassword for Content Cortex
            tmp_jmailuser="$(prop_user_profile_property_file BAN.JMAIL_USER_NAME)"
            tmp_jmailpwd="$(prop_user_profile_property_file BAN.JMAIL_USER_PASSWORD)"

            tmp_jmailuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_jmailuser")
            tmp_jmailpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_jmailpwd")


            #  replace icndb user
            tmp_dbuser="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
        
            # # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. But for vault, we still want to keep the password in vault even POSTGRESQL_SSL_CLIENT_SERVER is true.
            if [[ (! ( $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" )) || $DB_TYPE == "postgresql-edb" ]]; then
                tmp_dbuserpwd="$(prop_db_name_user_property_file ICN_DB_USER_PASSWORD)"
            fi


            #DBACLD-185209: Vault's implementation
            if [[ $vault_enabled == 'true' ]]; then
                # Decode passwords for Vault (if needed)
                tmp_apppwd="$(decode_base64_password "$tmp_apppwd")"
                tmp_ltpapwd="$(decode_base64_password "$tmp_ltpapwd")"
                tmp_kestorepwd="$(decode_base64_password "$tmp_kestorepwd")"
                tmp_jmailpwd="$(decode_base64_password "$tmp_jmailpwd")"
                if [[ -n "$tmp_dbuserpwd" ]]; then
                    tmp_dbuserpwd="$(decode_base64_password "$tmp_dbuserpwd")"
                fi
                vault_role=$(prop_user_profile_property_file CP4BA.VAULT_ROLE)
                vault_address=$(prop_user_profile_property_file CP4BA.VAULT_ADDRESS)
                vault_path="$(prop_user_profile_property_file CP4BA.VAULT_PATH | sed 's|/$||')"
                wait_msg "Creating ibm-ban-secret JSON template and SecretProviderClass template for Vault"
                create_ban_secret_vault_template \
                    "$tmp_appuser" \
                    "$tmp_apppwd" \
                    "$tmp_dbuser" \
                    "$tmp_dbuserpwd" \
                    "$tmp_jmailuser" \
                    "$tmp_jmailpwd" \
                    "$tmp_ltpapwd" \
                    "$tmp_kestorepwd" \
                    "$tmp_postgresql_client_flag" \
                    "$tmp_dbservername" \
                    "$tmp_dbname"
            else # Non Vault
                wait_msg "Creating ibm-ban-secret secret YAML template for CP4BA"
                create_ban_secret_template $tmp_dbname $tmp_dbservername
                # Make sure the $BAN_SECRET_FILE is created
                if [[ -f ${BAN_SECRET_FILE} ]]; then
                    ${YQ_CMD} -i ".stringData.appLoginUsername = \"$tmp_appuser\"" "${BAN_SECRET_FILE}"
                    update_secret_template_passwords "$tmp_apppwd" "appLoginPassword" "$BAN_SECRET_FILE"
                    update_secret_template_passwords "$tmp_ltpapwd" "ltpaPassword" "$BAN_SECRET_FILE"
                    update_secret_template_passwords "$tmp_kestorepwd" "keystorePassword" "$BAN_SECRET_FILE"

                    if [[ ! ($tmp_jmailuser == "<Optional>" || $tmp_jmailpwd == "<Optional>" ) ]]; then
                        echo "Setting jMail credentials in secret"
                        ${YQ_CMD} -i ".stringData.jMailUsername = \"$tmp_jmailuser\"" "${BAN_SECRET_FILE}"
                        # For https://jsw.ibm.com/browse/DBACLD-157020
                        # Function that updates the secret template with the base64 password
                        update_secret_template_passwords "$tmp_jmailpwd" "jMailPassword" "$BAN_SECRET_FILE"
                    else
                        echo "Skipping jMail credentials - value is optional or empty"
                    fi
                    ${YQ_CMD} -i ".stringData.navigatorDBUsername = \"$tmp_dbuser\"" "${BAN_SECRET_FILE}"

                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                    if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                        ${SED_COMMAND} '/^  navigatorDBPassword/d' ${BAN_SECRET_FILE}
                    else
                        # For https://jsw.ibm.com/browse/DBACLD-157020
                        # Function that updates the secret template with the base64 password
                        update_secret_template_passwords $tmp_dbuserpwd "navigatorDBPassword" "$BAN_SECRET_FILE"
                    fi
                else
                    error "Failed to create ibm-ban-secret secret YAML template for CP4BA."
                    exit 1
                fi
            success "ibm-ban-secret secret YAML template for CP4BA has been created.\n"
            fi
           
        fi
    fi
    
    # ---------------------------
    # create DPE DB secret
    # ---------------------------
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        # get server/instance for DPE
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ADP_BASE_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "ADP_BASE_DB_USER_NAME"

        # get db type for the db server
        tmp_dbtype="$(prop_db_server_property_file $tmp_dbservername.DATABASE_TYPE)"
        tmp_dbtype=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbtype")
        tmp_dbtype=$(echo "$tmp_dbtype" | tr '[:upper:]' '[:lower:]')

        if [[ $tmp_dbtype != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
        fi

        # create aca db secret and populate the function
        if [[ $vault_enabled == 'true' ]]; then
            create_aca_db_secret_vault_template
        else
            create_aca_db_secret_template
        fi

        # create ibm-adp-secret
        if [[ $vault_enabled == 'true' ]]; then
            create_adp_secret_vault_template "$tmp_dbservername"
        else
            # Non-vault scenario:
            create_adp_secret_template "$tmp_dbservername"

            # replace serviceUser/servicePwd for ADP
            tmp_username="$(prop_user_profile_property_file ADP.SERVICE_USER_NAME)"
            tmp_userpwd="$(prop_user_profile_property_file ADP.SERVICE_USER_PASSWORD)"
            ${YQ_CMD} -i ".stringData.serviceUser = \"$tmp_username\"" "${ADP_SECRET_FILE}"
            # For DBACLD-157020: Function that updates the secret template with the base64 password
            update_secret_template_passwords "$tmp_userpwd" "servicePwd" "$ADP_SECRET_FILE"

            # replace serviceUserBas/servicePwdBas for ADP
            tmp_username="$(prop_user_profile_property_file ADP.SERVICE_USER_NAME_BASE)"
            tmp_userpwd="$(prop_user_profile_property_file ADP.SERVICE_USER_PASSWORD_BASE)"
            ${YQ_CMD} -i ".stringData.serviceUserBas = \"$tmp_username\"" "${ADP_SECRET_FILE}"
            # For DBACLD-157020: Function that updates the secret template with the base64 password
            update_secret_template_passwords "$tmp_userpwd" "servicePwdBas" "$ADP_SECRET_FILE"

            # replace serviceUserCa/servicePwdCa for ADP
            tmp_username="$(prop_user_profile_property_file ADP.SERVICE_USER_NAME_CA)"
            tmp_userpwd="$(prop_user_profile_property_file ADP.SERVICE_USER_PASSWORD_CA)"
            ${YQ_CMD} -i ".stringData.serviceUserCa = \"$tmp_username\"" "${ADP_SECRET_FILE}"
            # For DBACLD-157020: Function that updates the secret template with the base64 password
            update_secret_template_passwords "$tmp_userpwd" "servicePwdCa" "$ADP_SECRET_FILE"
            
            # replace envOwnerUser/envOwnerPwd for ADP
            tmp_username="$(prop_user_profile_property_file ADP.ENV_OWNER_USER_NAME)"
            tmp_userpwd="$(prop_user_profile_property_file ADP.ENV_OWNER_USER_PASSWORD)"
            ${YQ_CMD} -i ".stringData.envOwnerUser = \"$tmp_username\"" "${ADP_SECRET_FILE}"
            # For DBACLD-157020: Function that updates the secret template with the base64 password
            update_secret_template_passwords "$tmp_userpwd" "envOwnerPwd" "$ADP_SECRET_FILE"

            ### <https://jsw.ibm.com/browse/DBACLD-168161> - Added new section for ADP Gitgateway database username and password with base64 password
            # replace adpggDBUsername/adpggDBPassword for ADPGG
            # DBACLD-178324:  ADPGG properties are only needed for document_processing_designer only
            if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
                tmp_username="$(prop_db_name_user_property_file ADP_GG_DB_USER_NAME)"
                tmp_userpwd="$(prop_db_name_user_property_file ADP_GG_DB_USER_PASSWORD)"
                ${YQ_CMD} -i ".stringData.adpggDBUsername = \"$tmp_username\"" "${ADP_SECRET_FILE}"
                
                # Call helper function to determine the postgres client flag
                get_postgresql_client_flag "ADP_GG_DB_USER_NAME" "adpgg_postgresql_client_flag" "true"

                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret.  For EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                if [[ ($adpgg_postgresql_client_flag == "true" || $adpgg_postgresql_client_flag == "yes" || $adpgg_postgresql_client_flag == "y") && $tmp_dbtype != "postgresql-edb" ]]; then
                    ${SED_COMMAND} '/^[[:space:]]*adpggDBPassword/d' ${ADP_SECRET_FILE}
                else
                    # Function that updates the secret template with the base64 password
                    update_secret_template_passwords "$tmp_userpwd" "adpggDBPassword" "$ADP_SECRET_FILE"
                fi
            else
                ${SED_COMMAND} '/^[[:space:]]*adpggDBUsername/d' ${ADP_SECRET_FILE}
                ## when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret.  For EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                if [[ ($adpgg_postgresql_client_flag == "true" || $adpgg_postgresql_client_flag == "yes" || $adpgg_postgresql_client_flag == "y") && $tmp_dbtype != "postgresql-edb" ]]; then
                    ${SED_COMMAND} '/^[[:space:]]*adpggDBPassword/d' ${ADP_SECRET_FILE}
                fi
            fi
        fi


        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            # create SSL secret for Git connection
            tmp_git_flag="$(prop_user_profile_property_file ADP.ENABLE_GIT_SSL_CONNECTION)"
            tmp_git_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_git_flag")
            if [[ $tmp_git_flag == "Yes" || $tmp_git_flag == "YES" || $tmp_git_flag == "Y" || $tmp_git_flag == "True" || $tmp_git_flag == "true" ]]; then
                if [[ $vault_enabled == 'true' ]]; then
                    create_adp_git_connection_ssl_vault_template
                else
                    # Non-vault scenario
                    create_adp_git_connection_ssl_template

                    #  replace secret name
                    tmp_secret_name="$(prop_user_profile_property_file ADP.GIT_SSL_SECRET_NAME)"
                    tmp_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_secret_name")
                    if [[ -n $tmp_secret_name || $tmp_secret_name != "" ]]; then
                        ${SED_COMMAND} "s|<adp-git-ssl-secret-name>|$tmp_secret_name|g" ${ADP_GIT_SSL_SECRET_FILE}
                    fi

                    #  replace secret file folder
                    tmp_name="$(prop_user_profile_property_file ADP.GIT_SSL_CERT_FILE_FOLDER)"
                    if [[ -z $tmp_name || $tmp_name == "" ]]; then
                        tmp_name=$ADP_GIT_SSL_CERT_FOLDER
                    fi
                    ${SED_COMMAND} "s|<adp-git-crt-file-in-local>|$tmp_name|g" ${ADP_GIT_SSL_SECRET_FILE}
                fi
            fi
        fi

        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
            if [[ $vault_enabled == 'true' ]]; then
                create_adp_cdra_ssl_vault_template
            else
                # Non-vault scenario
                create_adp_cdra_ssl_template

                #  replace secret name
                tmp_secret_name="$(prop_user_profile_property_file ADP.CDRA_SSL_SECRET_NAME)"
                tmp_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_secret_name")
                if [[ -n $tmp_secret_name || $tmp_secret_name != "" ]]; then
                    ${SED_COMMAND} "s|<adp-cdra-ssl-secret-name>|$tmp_secret_name|g" ${ADP_CDRA_SSL_SECRET_FILE}
                fi

                #  replace secret file folder
                tmp_name="$(prop_user_profile_property_file ADP.CDRA_SSL_CERT_FILE_FOLDER)"
                if [[ -z $tmp_name || $tmp_name == "" ]]; then
                    tmp_name=$ADP_CDRA_CERT_FOLDER
                fi
                ${SED_COMMAND} "s|<adp-cdra-crt-file-in-local>|$tmp_name|g" ${ADP_CDRA_SSL_SECRET_FILE}
            fi
        fi

        # create template for aca-design-api-key
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
            enable_flag="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_ENABLED)"
            enable_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$enable_flag")
            enable_flag=$(echo "$enable_flag" | tr '[:upper:]' '[:lower:]')

            type_flag="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_RUNTIME_TYPE)"
            type_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$type_flag")

            if [[ $enable_flag == "true" && $type_flag == "distributed" ]]; then
                if [[ $vault_enabled == 'true' ]]; then
                    # Get secret name and API key for Vault
                    tmp_secret_name="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_DESIGN_API_KEY_SECRET_NAME)"
                    tmp_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_secret_name")
                    if [[ -z $tmp_secret_name || $tmp_secret_name == "" ]]; then
                        tmp_secret_name="ibm-adp-aca-design-api-key-secret"
                    fi
                    
                    # Build ZenApiKey value
                    tmp_api_user="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_DESIGN_API_USER)"
                    tmp_api_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_api_user")
                    tmp_zen_key="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_DESIGN_ZEN_API_KEY)"
                    tmp_zen_key=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_zen_key")
                    tmp_zen_api_key="${tmp_api_user}:${tmp_zen_key}"
                    
                    create_aca_design_api_key_vault_template "$tmp_secret_name" "$tmp_zen_api_key"
                else
                    # Non-vault scenario
                    create_aca_design_api_key_template

                    tmp_secret_name="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_DESIGN_API_SECRET)"
                    tmp_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_secret_name")
                    if [[ -n $tmp_secret_name || $tmp_secret_name != "" ]]; then
                        ${SED_COMMAND} "s|<cp4a-aca-design-api-key-secret-name>|$tmp_secret_name|g" ${ADP_ACA_DESIGN_API_KEY_SECRET_FILE}
                    fi

                    tmp_name="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_DESIGN_API_USER)"
                    tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
                    if [[ -n $tmp_name || $tmp_name != "" ]]; then
                        ${SED_COMMAND} "s|<cp4a-aca-design-api-user>|$tmp_name|g" ${ADP_ACA_DESIGN_API_KEY_SECRET_FILE}
                    fi

                    tmp_name="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_DESIGN_ZEN_API_KEY)"
                    tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
                    if [[ -n $tmp_name || $tmp_name != "" ]]; then
                        ${SED_COMMAND} "s|<cp4a-aca-design-zen-api-key>|$tmp_name|g" ${ADP_ACA_DESIGN_API_KEY_SECRET_FILE}
                    fi
                fi
            fi
        fi

        #  replace serviceUser/serviceUserBas/serviceUserCa/envOwnerUser
        # tmp_dbuser="$(prop_ldap_property_file LDAP_BASE_DN)"
        # ${SED_COMMAND} "s|\"<SERVICE_USER>\"|\"$tmp_dbuser\"|g" ${ADP_SECRET_FILE}
        # ${SED_COMMAND} "s|\"<SERVICE_USER_BAS>\"|\"$tmp_dbuser\"|g" ${ADP_SECRET_FILE}
        # ${SED_COMMAND} "s|\"<SERVICE_USER_CA>\"|\"$tmp_dbuser\"|g" ${ADP_SECRET_FILE}
        # ${SED_COMMAND} "s|\"<ENV_OWNER_USER>\"|\"$tmp_dbuser\"|g" ${ADP_SECRET_FILE}

        # tmp_dbuserpwd="$(prop_ldap_property_file LDAP_PASSWORD)"
        # ${SED_COMMAND} "s|\"<SERVICE_PASSWORD>\"|\"$tmp_dbuser\"|g" ${ADP_SECRET_FILE}
        # ${SED_COMMAND} "s|\"<SERVICE_PASSWORD_BAS>\"|\"$tmp_dbuserpwd\"|g" ${ADP_SECRET_FILE}
        # ${SED_COMMAND} "s|\"<SERVICE_PASSWORD_CA>\"|\"$tmp_dbuserpwd\"|g" ${ADP_SECRET_FILE}
        # ${SED_COMMAND} "s|\"<ENV_OWNER_PASSWORD>\"|\"$tmp_dbuserpwd\"|g" ${ADP_SECRET_FILE}
    fi

    # --------------------------
    # create AE secret
    # --------------------------
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "application" ]]; then
        # get server/instance for AE
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name APP_ENGINE_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "APP_ENGINE_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
        fi

        if [[ $vault_enabled == 'true' ]]; then
            tmp_dbuser="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
            # when POSTGRESQL_SSL_CLIENT_SERVER is true, pass empty password. Except EDB, we will keep the password even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                create_app_engine_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "" ""
            else
                tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file APP_ENGINE_DB_USER_PASSWORD)")"
                create_app_engine_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "$tmp_dbuserpwd" ""
            fi
        else
            create_app_engine_secret_template $tmp_dbname $tmp_dbservername
            #  replace APP Engine DB user
            tmp_dbuser="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
            ${YQ_CMD} -i ".stringData.AE_DATABASE_USER = \"$tmp_dbuser\"" ${APP_ENGINE_SECRET_FILE}
            

            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                ${SED_COMMAND} '/^  AE_DATABASE_PWD/d' ${APP_ENGINE_SECRET_FILE}
            else
                tmp_dbuserpwd="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_PASSWORD)"
                # For https://jsw.ibm.com/browse/DBACLD-157020
                # Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_dbuserpwd" "AE_DATABASE_PWD" "$APP_ENGINE_SECRET_FILE"
            fi
        fi

        # Redis for AE HA session
        tmp_redis_tls_enabled="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_TLS_ENABLED)"
        tmp_redis_tls_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_tls_enabled")
        if [[ $tmp_redis_tls_enabled == "Yes" || $tmp_redis_tls_enabled == "YES" || $tmp_redis_tls_enabled == "Y" || $tmp_redis_tls_enabled == "True" || $tmp_redis_tls_enabled == "true" ]]; then
            tmp_redis_secret_name="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_SSL_SECRET_NAME)"
            tmp_redis_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_secret_name")
            if [[ $vault_enabled == 'true' ]]; then
                create_cp4a_ae_redis_ssl_vault_template "$tmp_redis_secret_name" "$AE_REDIS_SSL_CERT_FOLDER"
            else
                create_cp4a_ae_redis_ssl_secret_template
                #  replace secret name
                if [[ -n $tmp_redis_secret_name || $tmp_redis_secret_name != "" ]]; then
                    ${SED_COMMAND} "s|<cp4a-redis_ssl_secret_name>|$tmp_redis_secret_name|g" ${CP4A_AE_REDIS_SSL_SECRET_FILE}
                fi

                #  replace secret file folder
                tmp_name="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_SSL_CERT_FILE_FOLDER)"
                if [[ -z $tmp_name || $tmp_name == "" ]]; then
                    tmp_name=$AE_REDIS_SSL_CERT_FOLDER
                fi
                ${SED_COMMAND} "s|<cp4a-redis-crt-file-in-local>|$tmp_name|g" ${CP4A_AE_REDIS_SSL_SECRET_FILE}
            fi

        fi
    fi

    # create ODM DB secret
    containsElement "decisions" "${pattern_cr_arr[@]}"
    odm_Val=$?
    if [[ $odm_Val -eq 0 ]]; then

        # get server/instance for ODM
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ODM_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "ODM_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        tmp_postgresql_client_flag="false"
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file ODM_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
        fi

        tmp_dbuser="$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
        
        # Generate a random 16-character password for odm-keystore-password secret so we don't need to need to take user inputs
        # https://jsw.ibm.com/browse/DBACLD-238578
        tmp_odm_keystore_password="$(openssl rand -hex 8)"

        if [[ $vault_enabled == 'true' ]]; then
            create_odm_secret_vault_template $tmp_dbname $tmp_dbservername $tmp_dbuser $tmp_postgresql_client_flag
            # Create ODM secret json and secretProviderClass template for the ODM keystore password secret
            # https://jsw.ibm.com/browse/DBACLD-238578
            create_odm_keystore_password_secret_vault_template "$tmp_odm_keystore_password"
        else
            create_odm_secret_template $tmp_dbname $tmp_dbservername
            ${YQ_CMD} -i ".stringData.db-user = \"$tmp_dbuser\"" ${ODM_SECRET_FILE}

            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                ${SED_COMMAND} '/^  db-password/d' ${ODM_SECRET_FILE}
            else
                tmp_dbuserpwd="$(prop_db_name_user_property_file ODM_DB_USER_PASSWORD)"
                # For https://jsw.ibm.com/browse/DBACLD-157020
                # Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_dbuserpwd" "db-password" "$ODM_SECRET_FILE"
            fi

            # Create ODM secret template for the ODM keystore password secret
            # https://jsw.ibm.com/browse/DBACLD-238578
            create_odm_keystore_password_secret_template "$tmp_odm_keystore_password"
            # Function that updates the secret template with the base64 password
            update_secret_template_passwords "$tmp_odm_keystore_password" "keystorePassword" "$ODM_KEYSTORE_SECRET_FILE"
        fi

    fi

    # create BAS secret
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || "${pattern_cr_arr[@]}" =~ "workflow-authoring" || ("${pattern_cr_arr[@]}" =~ "workflow-process-service" && $EXTERNAL_DB_WFPS_AUTHORING == "Yes") || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
        # get server/instance for BAS
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name STUDIO_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "STUDIO_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file STUDIO_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)"
        fi
        # Get username and password for both Vault and non-Vault scenarios
        tmp_dbuser="$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)"
        tmp_dbuserpwd="$(prop_db_name_user_property_file STUDIO_DB_USER_PASSWORD)"
        
        if [[ $vault_enabled == 'true' ]]; then
            # For Vault: pass username and password to the template function
            # If PostgreSQL SSL client auth is enabled, pass empty password
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                create_bas_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" ""
            else
                create_bas_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "$tmp_dbuserpwd"
            fi
        else
            create_bas_secret_template $tmp_dbname $tmp_dbservername
            #  replace BAStudio DB user
            ${YQ_CMD} -i ".stringData.dbUsername = \"$tmp_dbuser\"" ${BAS_SECRET_FILE}

            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                ${SED_COMMAND} '/^  dbPassword/d' ${BAS_SECRET_FILE}
            else
                # For https://jsw.ibm.com/browse/DBACLD-157020
                # Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_dbuserpwd" "dbPassword" "$BAS_SECRET_FILE"
            fi
        fi

    fi

    # create AP play back secret
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
        # get server/instance for AP play back
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name APP_PLAYBACK_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "APP_PLAYBACK_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file APP_PLAYBACK_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
        fi
        if [[ $vault_enabled == 'true' ]]; then
            tmp_dbuser="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
            # when POSTGRESQL_SSL_CLIENT_SERVER is true, pass empty password. Except EDB, we will keep the password even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                create_ae_playback_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "" ""
            else
                tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_PASSWORD)")"
                create_ae_playback_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "$tmp_dbuserpwd" ""
            fi
        else
            create_ae_playback_secret_template $tmp_dbname $tmp_dbservername
            #  replace ae playback db user
            tmp_dbuser="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
            ${YQ_CMD} -i ".stringData.AE_DATABASE_USER = \"$tmp_dbuser\"" ${APP_ENGINE_PLAYBACK_SECRET_FILE}

            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                ${SED_COMMAND} '/^  AE_DATABASE_PWD/d' ${APP_ENGINE_PLAYBACK_SECRET_FILE}
            else
                tmp_dbuserpwd="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_PASSWORD)"
                # For https://jsw.ibm.com/browse/DBACLD-157020
                # Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_dbuserpwd" "AE_DATABASE_PWD" "$APP_ENGINE_PLAYBACK_SECRET_FILE"
            fi
        fi
        # Redis for Playback HA session
        tmp_redis_tls_enabled="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_TLS_ENABLED)"
        tmp_redis_tls_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_tls_enabled")
        if [[ $tmp_redis_tls_enabled == "Yes" || $tmp_redis_tls_enabled == "YES" || $tmp_redis_tls_enabled == "Y" || $tmp_redis_tls_enabled == "True" || $tmp_redis_tls_enabled == "true" ]]; then
            tmp_redis_secret_name="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_SSL_SECRET_NAME)"
            tmp_redis_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_secret_name")
            if [[ $vault_enabled == 'true' ]]; then
                create_cp4a_playback_redis_ssl_vault_template "$tmp_redis_secret_name" "$PLAYBACK_REDIS_SSL_CERT_FOLDER"
            else
                create_cp4a_playback_redis_ssl_secret_template
                #  replace secret name
                if [[ -n $tmp_redis_secret_name || $tmp_redis_secret_name != "" ]]; then
                    ${SED_COMMAND} "s|<cp4a-redis_ssl_secret_name>|$tmp_redis_secret_name|g" ${CP4A_PLAYBACK_REDIS_SSL_SECRET_FILE}
                fi

                #  replace secret file folder
                tmp_name="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_SSL_CERT_FILE_FOLDER)"
                if [[ -z $tmp_name || $tmp_name == "" ]]; then
                    tmp_name=$PLAYBACK_REDIS_SSL_CERT_FOLDER
                fi
                ${SED_COMMAND} "s|<cp4a-redis-crt-file-in-local>|$tmp_name|g" ${CP4A_PLAYBACK_REDIS_SSL_SECRET_FILE}
            fi
        fi
    fi

    # # create baw authoring secret
    # if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
    #     # get server/instance for AP play back
    #     tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AUTHORING_DB_USER_NAME)"
    #     check_dbserver_name_valid $tmp_dbservername "AUTHORING_DB_USER_NAME"
    #     if [[ $DB_TYPE != "oracle" ]]; then
    #         tmp_dbname="$(prop_db_name_user_property_file AUTHORING_DB_NAME)"
    #     else
    #         tmp_dbname="$(prop_db_name_user_property_file AUTHORING_DB_USER_NAME)"
    #     fi
    #     create_baw_authoring_secret_template $tmp_dbname $tmp_dbservername
    #     #  replace baw db user
    #     tmp_dbuser="$(prop_db_name_user_property_file AUTHORING_DB_USER_NAME)"
    #     ${SED_COMMAND} "s|dbUser: .*|dbUser: $tmp_dbuser|g" ${BAW_SECRET_FILE}

    #     tmp_dbuserpwd="$(prop_db_name_user_property_file AUTHORING_DB_USER_PASSWORD)"
    #     ${SED_COMMAND} "s|password: .*|password: $tmp_dbuserpwd|g" ${BAW_SECRET_FILE}
    # fi

    # create baw-aws secret
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
        # get server/instance for baw runtime
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "BAW_RUNTIME_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        # get server/instance for baw-aws
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
            check_dbserver_name_valid $tmp_dbservername "BAW_RUNTIME_DB_USER_NAME"
            tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
        fi
        if [[ $vault_enabled == 'true' ]]; then
            tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
            # when POSTGRESQL_SSL_CLIENT_SERVER is true, pass empty password. Except EDB, we will keep the password even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                create_baw_runtime_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "" "$tmp_postgresql_client_flag"
            else
                tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)")"
                create_baw_runtime_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_postgresql_client_flag"
            fi
        else
            create_baw_runtime_secret_template $tmp_dbname $tmp_dbservername

            #  replace baw db user
            tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
            #${SED_COMMAND} "s|dbUser: .*|dbUser: $tmp_dbuser|g" ${BAW_RUNTIME_SECRET_FILE}
            ${YQ_CMD} -i ".stringData.dbUser = \"$tmp_dbuser\"" ${BAW_RUNTIME_SECRET_FILE}

            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                ${SED_COMMAND} '/^  password/d' ${BAW_RUNTIME_SECRET_FILE}
            else
                tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                # For https://jsw.ibm.com/browse/DBACLD-157020
                # Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_dbuserpwd" "password" "$BAW_RUNTIME_SECRET_FILE"
            fi
        fi


        # get server/instance for aws
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "AWS_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        # get server/instance for baw-aws
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
            check_dbserver_name_valid $tmp_dbservername "AWS_DB_USER_NAME"
            tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
        fi
        
        if [[ $vault_enabled == 'true' ]]; then
            tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
            # when POSTGRESQL_SSL_CLIENT_SERVER is true, pass empty password. Except EDB, we will keep the password even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                create_baw_aws_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "" "$tmp_postgresql_client_flag"
            else
                tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)")"
                create_baw_aws_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_postgresql_client_flag"
            fi
        else
            create_baw_aws_secret_template $tmp_dbname $tmp_dbservername

            tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
            ${YQ_CMD} -i ".stringData.dbUser = \"$tmp_dbuser\"" ${BAW_AWS_SECRET_FILE}

            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                ${SED_COMMAND} '/^  password/d' ${BAW_AWS_SECRET_FILE}
            else
                tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
                # For https://jsw.ibm.com/browse/DBACLD-157020
                # Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_dbuserpwd" "password" "$BAW_AWS_SECRET_FILE"
            fi
        fi
    elif [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
        # get server/instance for baw runtime
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "BAW_RUNTIME_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
        fi
        if [[ $vault_enabled == 'true' ]]; then
            tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
            # when POSTGRESQL_SSL_CLIENT_SERVER is true, pass empty password. Except EDB, we will keep the password even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                create_baw_runtime_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "" "$tmp_postgresql_client_flag"
            else
                tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)")"
                create_baw_runtime_secret_vault_template $tmp_dbname $tmp_dbservername "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_postgresql_client_flag"
            fi
        else
            create_baw_runtime_secret_template $tmp_dbname $tmp_dbservername
            #  replace baw db user
            tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
       
            ${YQ_CMD} -i ".stringData.dbUser = \"$tmp_dbuser\"" ${BAW_RUNTIME_SECRET_FILE}

            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                ${SED_COMMAND} '/^  password/d' ${BAW_RUNTIME_SECRET_FILE}
            else
                tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                # For https://jsw.ibm.com/browse/DBACLD-157020
                # Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_dbuserpwd" "password" "$BAW_RUNTIME_SECRET_FILE"
            fi
        fi
    elif [[ " ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
        # get server/instance for AWS
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "AWS_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
        fi
        if [[ $vault_enabled == 'true' ]]; then
            tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
            tmp_dbuserpwd="$(decode_base64_password "$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)")"
            create_baw_aws_secret_vault_template $tmp_dbname $tmp_dbservername $tmp_dbuser "$tmp_dbuserpwd" "$tmp_postgresql_client_flag"
        else
            create_baw_aws_secret_template $tmp_dbname $tmp_dbservername
            #  replace aws db user
            tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
            ${YQ_CMD} -i ".stringData.dbUser = \"$tmp_dbuser\"" ${BAW_AWS_SECRET_FILE}

            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $DB_TYPE != "postgresql-edb" ]]; then
                ${SED_COMMAND} '/^  password/d' ${BAW_AWS_SECRET_FILE}
            else
                tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
                # For https://jsw.ibm.com/browse/DBACLD-157020
                # Function that updates the secret template with the base64 password
                update_secret_template_passwords "$tmp_dbuserpwd" "password" "$BAW_AWS_SECRET_FILE"
            fi
        fi
    fi

    if [[ "${optional_component_cr_arr[@]}" =~ "workflow_assistant" || "${optional_component_cr_arr[@]}" =~ "workplace_assistant" ]]; then
       if [[ $vault_enabled == 'true' ]]; then
           create_workflow_assistant_secret_vault_template
       else
           create_workflow_assistant_secret_template
       fi
    fi

    # -- <https://jsw.ibm.com/browse/DBACLD-147652> [Story] - Create DICMS secret for DecisionDesigner and DecisionRuntime for external postgres db
    ## -- <https://jsw.ibm.com/browse/DBACLD-153348> [Story] - Migration from Mongo to Postgres-edb for DICMS
    ### -- <https://jsw.ibm.com/browse/DBACLD-168160> [Bug] - Fixes issue with password not encoded in base64 and in data section. Combined the above two stories, since the two scenarios runs the exact same code.
    # create DICMS secret for DecisionDesigner and DecisionRuntime
    if [[ "${pattern_cr_arr[@]}" =~ "decisions_ads" ]]; then
        # create secret for DICMS Designer
        if [[ "${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
            if [[ $vault_enabled == 'true' ]]; then
                create_di_designer_secret_vault_template
            else
                # get server/instance for DICMS Designer
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name DICMS_DESIGNER_DB_NAME)"
                tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
                check_dbserver_name_valid $tmp_dbservername "DICMS_DESIGNER_DB_NAME"

                # Get DB type for DICMS Designer
                tmp_dbtype="$(prop_db_server_property_file $tmp_dbservername.DATABASE_TYPE)"
                tmp_dbtype=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbtype")
                tmp_dbtype=$(echo "$tmp_dbtype" | tr '[:upper:]' '[:lower:]')

                tmp_dbname="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_NAME)"
                tmp_dbuser="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_USER_NAME)"
                tmp_dbpass="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_USER_PASSWORD)"

                create_ads_decisiondesigner_secret_template $tmp_dbname $tmp_dbservername
                ${YQ_CMD} -i ".stringData.username = \"$tmp_dbuser\"" ${ADS_DESIGNER_FILE}

                # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
                if [[ $tmp_dbtype == "postgresql" ]]; then
                    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
                    tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
                else
                    tmp_postgresql_client_flag="true"
                fi

                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $tmp_dbtype != "postgresql-edb" ]]; then
                    ${SED_COMMAND} '/^[[:space:]]*password/d' ${ADS_DESIGNER_FILE}
                else
                    # Function that updates the secret template with the base64 password
                    update_secret_template_passwords "$tmp_dbpass" "password" "$ADS_DESIGNER_FILE"
                fi
            fi
        fi
        # create secret for DICMS Runtime
        if [[ "${optional_component_cr_arr[@]}" =~ "ads_runtime" ]]; then
            if [[ $vault_enabled == 'true' ]]; then
                create_di_runtime_secret_vault_template
            else
                # get server/instance for DICMS Runtime
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name DICMS_RUNTIME_DB_NAME)"
                tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
                check_dbserver_name_valid $tmp_dbservername "DICMS_RUNTIME_DB_NAME"

                # Get DB type for DICMS Runtime
                tmp_dbtype="$(prop_db_server_property_file $tmp_dbservername.DATABASE_TYPE)"
                tmp_dbtype=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbtype")
                tmp_dbtype=$(echo "$tmp_dbtype" | tr '[:upper:]' '[:lower:]')

                tmp_dbname="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_NAME)"
                tmp_dbuser="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_USER_NAME)"
                tmp_dbpass="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_USER_PASSWORD)"

                create_ads_decisionruntime_secret_template $tmp_dbname $tmp_dbservername
                ${YQ_CMD} -i ".stringData.username = \"$tmp_dbuser\"" ${ADS_RUNTIME_FILE}

                # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
                if [[ $tmp_dbtype == "postgresql" ]]; then
                    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
                    tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
                else
                    tmp_postgresql_client_flag="true"
                fi

                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
                if [[ ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") && $tmp_dbtype != "postgresql-edb" ]]; then
                    ${SED_COMMAND} '/^[[:space:]]*password/d' ${ADS_RUNTIME_FILE}
                else
                    # Function that updates the secret template with the base64 password
                    update_secret_template_passwords "$tmp_dbpass" "password" "$ADS_RUNTIME_FILE"
                fi
            fi
        fi
    fi

    if [[ $DB_TYPE != "postgresql-edb" ]]; then
        # Create secret for DB SSL enabled
        # Put DB server/instance into array
        tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
        tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
        OIFS=$IFS
        IFS=',' read -ra db_server_array <<< "$tmp_db_array"
        IFS=$OIFS

        for item in "${db_server_array[@]}"; do

            # DB SSL Enabled
            tmp_db_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SSL_ENABLE)")
            tmp_db_ssl_flag=$(echo "$tmp_db_ssl_flag" | tr '[:upper:]' '[:lower:]')
            while true; do
                case "$tmp_db_ssl_flag" in
                "true"|"yes"|"y")
                    # create_cp4a_db_ssl_template $item

                    #  replace secret name
                    tmp_ssl_secret_name="$(prop_db_server_property_file $item.DATABASE_SSL_SECRET_NAME)"
                    tmp_ssl_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ssl_secret_name")
                    # ${SED_COMMAND} "s|<cp4a-db-ssl-secret-name>|$tmp_name|g" ${CP4A_DB_SSL_SECRET_FILE}

                    #  replace secret file folder
                    tmp_cert_folder_name="$(prop_db_server_property_file $item.DATABASE_SSL_CERT_FILE_FOLDER)"
                    if [[ -z $tmp_cert_folder_name || $tmp_cert_folder_name == "" ]]; then
                        tmp_cert_folder_name=$DB_SSL_CERT_FOLDER/$item
                    fi
                    # ${SED_COMMAND} "s|<cp4a-db-crt-file-in-local>|$tmp_name|g" ${CP4A_DB_SSL_SECRET_FILE}

                    #  replace sslMode for postgresql
                    # Get the DATABASE_TYPE for this specific item to support mixed database scenarios
                    tmp_item_db_type=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_TYPE)")
                    tmp_item_db_type=$(echo "$tmp_item_db_type" | tr '[:upper:]' '[:lower:]')
                    # Initialize variables for PostgreSQL SSL settings
                    tmp_ssl_client_server=""
                    tmp_pg_ssl_mode=""
                    if [[ $tmp_item_db_type == "postgresql" ]]; then
                        tmp_ssl_client_server=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.POSTGRESQL_SSL_CLIENT_SERVER)")
                        tmp_ssl_client_server=$(echo "$tmp_ssl_client_server" | tr '[:upper:]' '[:lower:]')
                        if [[ $tmp_ssl_client_server == "yes" || $tmp_ssl_client_server == "true" ]]; then
                            tmp_pg_ssl_mode="$(prop_db_server_property_file $item.POSTGRESQL_SSL_MODE)"
                            tmp_pg_ssl_mode=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_pg_ssl_mode")
                            # ${SED_COMMAND} "s/--from-literal=sslmode=\[require|verify-ca|verify-full\]/--from-literal=sslmode=$tmp_name/" ${CP4A_DB_SSL_SECRET_FILE}
                        fi
                    fi

                    #DBACLD-185209: Vault's implementation for DB SSL
                    if [[ $vault_enabled == "true" ]]; then # Vault
                        create_cp4a_db_ssl_vault_template \
                        "$item" \
                        "$tmp_ssl_secret_name" \
                        "$tmp_cert_folder_name" \
                        "$tmp_ssl_client_server" \
                        "$tmp_pg_ssl_mode" \
                        "$tmp_item_db_type"
                    else # Non-Vault
                        create_cp4a_db_ssl_template $item $tmp_ssl_client_server
                        ${SED_COMMAND} "s|<cp4a-db-ssl-secret-name>|$tmp_ssl_secret_name|g" ${CP4A_DB_SSL_SECRET_FILE}
                        ${SED_COMMAND} "s|<cp4a-db-crt-file-in-local>|$tmp_cert_folder_name|g" ${CP4A_DB_SSL_SECRET_FILE}
                        if [[ $tmp_ssl_client_server == "yes" || $tmp_ssl_client_server == "true" ]]; then
                            ${SED_COMMAND} "s/--from-literal=sslmode=\[require|verify-ca|verify-full\]/--from-literal=sslmode=$tmp_pg_ssl_mode/" ${CP4A_DB_SSL_SECRET_FILE}
                        fi
                    fi # End of Vault's implementation for DB SSL


                    # create oracle-wallet-sso-secret-for-$item for AE/APP
                    if [[ $DB_TYPE == "oracle" && (" ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "application" || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer") ]]; then
                        if [[ $vault_enabled == 'true' ]]; then
                            #  get secret name
                            tmp_name="$(prop_db_server_property_file $item.ORACLE_SSO_WALLET_SECRET_NAME)"
                            tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
                            
                            #  get secret file folder
                            tmp_cert_folder="$(prop_db_server_property_file $item.ORACLE_SSO_WALLET_CERT_FOLDER)"
                            if [[ -z $tmp_cert_folder || $tmp_cert_folder == "" ]]; then
                                tmp_cert_folder=$DB_SSL_CERT_FOLDER/$item
                            fi
                            create_app_engine_oracle_sso_secret_vault_template $item "$tmp_name" "$tmp_cert_folder"
                        else
                            create_app_engine_oracle_sso_secret_template $item
                            #  replace secret name
                            tmp_name="$(prop_db_server_property_file $item.ORACLE_SSO_WALLET_SECRET_NAME)"
                            tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
                            ${SED_COMMAND} "s|<your-oracle-sso-secret-name>|$tmp_name|g" ${APP_ORACLE_SSO_SSL_SECRET_FILE}

                            #  replace secret file folder
                            tmp_name="$(prop_db_server_property_file $item.ORACLE_SSO_WALLET_CERT_FOLDER)"
                            if [[ -z $tmp_name || $tmp_name == "" ]]; then
                                tmp_name=$DB_SSL_CERT_FOLDER/$item
                            fi
                            ${SED_COMMAND} "s|<your-oracle-sso-wallet-file-path>|$tmp_name|g" ${APP_ORACLE_SSO_SSL_SECRET_FILE}
                        fi
                    fi
                    break
                    ;;
                "false"|"no"|"n"|"")
                    break
                    ;;
                *)
                    fail "$item.DATABASE_SSL_ENABLE is not valid value in the \"cp4ba_db_server.property\"! Exiting ..."
                    exit 1
                    ;;
                esac
            done
        done
    fi


    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "no") && "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then
        # LDAP SSL Enabled
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ldap_property_file LDAP_SSL_ENABLED)")
        tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        while true; do
            case "$tmp_flag" in
            "true"|"yes"|"y")
                tmp_ldap_secret_name="$(prop_ldap_property_file LDAP_SSL_SECRET_NAME)"
                tmp_ldap_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_secret_name")
                tmp_name="$(prop_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
                if [[ -z $tmp_name || $tmp_name == "" ]]; then
                    tmp_name=$LDAP_SSL_CERT_FOLDER
                fi
                #DBACLD-185209: Vault implementation
                if [[ $vault_enabled == 'true' ]]; then
                    wait_msg "Creating $tmp_ldap_secret_name JSON template and SecretProviderClass template for Vault"
                    create_ldap_tls_secret_vault_template $tmp_ldap_secret_name $tmp_name
                else
                    create_cp4a_ldap_ssl_secret_template
                    if [[ -z $tmp_ldap_secret_name || -n $tmp_ldap_secret_name || $tmp_ldap_secret_name != "" ]]; then
                        ${SED_COMMAND} "s|<cp4a-ldap_ssl_secret_name>|$tmp_ldap_secret_name|g" ${CP4A_LDAP_SSL_SECRET_FILE}
                    fi
                    ${SED_COMMAND} "s|<cp4a-ldap-crt-file-in-local>|$tmp_name|g" ${CP4A_LDAP_SSL_SECRET_FILE}
                fi
                break
                ;;
            "false"|"no"|"n"|"")
                break
                ;;
            *)
                fail "LDAP_SSL_ENABLED does not have a valid value in the \"cp4ba_LDAP.property\"! Exiting ..."
                exit 1
                ;;
            esac
        done

        # External LDAP SSL Enabled
        if [[ $SET_EXT_LDAP == "Yes" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ext_ldap_property_file LDAP_SSL_ENABLED)")
            tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
            while true; do
                case "$tmp_flag" in
                "true"|"yes"|"y")
                    create_cp4a_ext_ldap_ssl_secret_template
                    #  replace ldap secret name
                    tmp_ldap_secret_name="$(prop_ext_ldap_property_file LDAP_SSL_SECRET_NAME)"
                    tmp_ldap_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_secret_name")
                    if [[ -z $tmp_ldap_secret_name || -n $tmp_ldap_secret_name || $tmp_ldap_secret_name != "" ]]; then
                        ${SED_COMMAND} "s|<cp4a-ldap_ssl_secret_name>|$tmp_ldap_secret_name|g" ${CP4A_EXT_LDAP_SSL_SECRET_FILE}
                    fi

                    #  replace secret file folder
                    tmp_name="$(prop_ext_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
                    if [[ -z $tmp_name || $tmp_name == "" ]]; then
                        tmp_name=$EXT_LDAP_SSL_CERT_FOLDER
                    fi
                    ${SED_COMMAND} "s|<cp4a-ldap-crt-file-in-local>|$tmp_name|g" ${CP4A_EXT_LDAP_SSL_SECRET_FILE}
                    break
                    ;;
                "false"|"no"|"n"|"")
                    break
                    ;;
                *)
                    fail "LDAP_SSL_ENABLED is not valid value in the \"cp4ba_External_LDAP.property\"! Exiting ..."
                    exit 1
                    ;;
                esac
            done
        fi
    fi

    # Create Secret/configMap for IM metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_IM_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        #  replace secret file folder
        im_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        im_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$im_external_db_cert_folder")
        if [[ -z $im_external_db_cert_folder || $im_external_db_cert_folder == "" ]]; then
            im_external_db_cert_folder=$IM_DB_SSL_CERT_FOLDER
        fi
        create_im_external_db_secret_template
        if [[ -f $IM_SECRET_FILE ]]; then
            ${SED_COMMAND} "s|<cp4a-db-crt-file-in-local>|$im_external_db_cert_folder|g" ${IM_SECRET_FILE}
        fi

        # Skip generating K8s IM Configmap if ENABLE_VAULT_ON_EXIST mode is on
        if [[ "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
            create_im_external_db_configmap_template
            #  replace <DatabasePort>
            tmp_name="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_PORT)"
            tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
            ${SED_COMMAND} "s|<DatabasePort>|$tmp_name|g" ${IM_CONFIGMAP_FILE}

            #  replace <DatabaseReadHostName>
            tmp_name="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_R_ENDPOINT)"
            tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
            ${SED_COMMAND} "s|<DatabaseReadHostName>|$tmp_name|g" ${IM_CONFIGMAP_FILE}

            #  replace <DatabaseHostName>
            im_external_db_host_name="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_RW_ENDPOINT)"
            im_external_db_host_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$im_external_db_host_name")
            ${SED_COMMAND} "s|<DatabaseHostName>|$im_external_db_host_name|g" ${IM_CONFIGMAP_FILE}

            #  replace <DatabaseUser>
            tmp_name="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_USER)"
            tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
            ${SED_COMMAND} "s|<DatabaseUser>|$tmp_name|g" ${IM_CONFIGMAP_FILE}

            #  replace <DatabaseName>
            tmp_name="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_NAME)"
            tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
            ${SED_COMMAND} "s|<DatabaseName>|$tmp_name|g" ${IM_CONFIGMAP_FILE}
        fi
    fi

    # Create Secret/configMap for Zen metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_ZEN_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        
			zen_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
			zen_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$zen_external_db_cert_folder")
			if [[ -z $zen_external_db_cert_folder || $zen_external_db_cert_folder == "" ]]; then
					zen_external_db_cert_folder=$ZEN_DB_SSL_CERT_FOLDER
			fi
			create_zen_external_db_secret_template
			#  replace secret file folder (only needed for non-vault path which creates ZEN_SECRET_FILE)
			if [[ $vault_enabled != 'true' ]]; then
					${SED_COMMAND} "s|<cp4a-db-crt-file-in-local>|$zen_external_db_cert_folder|g" ${ZEN_SECRET_FILE}
			fi

        #DBACLD-245957 Skip generating the Zen configmap template during upgrade (ENABLE_VAULT_ON_EXIST), consistent with IM and BTS.
        # Zen metastore does not support K8s-secret-to-Vault migration on existing deployments.
			if [[ "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
				create_zen_external_db_configmap_template
				#DBACLD-230919: We need to insert DATABASE_CREDENTIAL_SOURCE and DATABASE_SECRET_PROVIDER_CLASS into the ZEN_CONFIGMAP_FILE when Vault is enabled. This is because the ZEN_CONFIGMAP_FILE is used to create the Zen metastore external Postgres DB secret and configmap, and the DATABASE_CREDENTIAL_SOURCE and DATABASE_SECRET_PROVIDER_CLASS are required for Vault to work properly.
				# DBACLD-245957:NOTE: Zen metastore does not support migrating from K8s secrets to Vault on an existing deployment (ENABLE_VAULT_ON_EXIST).
				# The vault-specific configmap fields are only applicable for a fresh install with Vault enabled.
				if [[ $vault_enabled == 'true' ]]; then
						${YQ_CMD} -i '.data.DATABASE_CREDENTIAL_SOURCE = "VAULT"' "${ZEN_CONFIGMAP_FILE}"
						${YQ_CMD} -i '.data.DATABASE_SECRET_PROVIDER_CLASS = "ibm-zen-metastore-secret"' "${ZEN_CONFIGMAP_FILE}"
				fi
			
				#  replace MonitoringSchema
				tmp_name="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_MONITORING_SCHEMA)"
				tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
				${SED_COMMAND} "s|<MonitoringSchema>|$tmp_name|g" ${ZEN_CONFIGMAP_FILE}

				#  replace <DatabaseName>
				tmp_name="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_NAME)"
				tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
				${SED_COMMAND} "s|<DatabaseName>|$tmp_name|g" ${ZEN_CONFIGMAP_FILE}

				#  replace <DatabasePort>
				tmp_name="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_PORT)"
				tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
				${SED_COMMAND} "s|<DatabasePort>|$tmp_name|g" ${ZEN_CONFIGMAP_FILE}

				#  replace <DatabaseReadHostName>
				tmp_name="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_R_ENDPOINT)"
				tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
				${SED_COMMAND} "s|<DatabaseReadHostName>|$tmp_name|g" ${ZEN_CONFIGMAP_FILE}

				#  replace <DatabaseHostName>
				zen_external_db_host_name="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_RW_ENDPOINT)"
				zen_external_db_host_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$zen_external_db_host_name")
				${SED_COMMAND} "s|<DatabaseHostName>|$zen_external_db_host_name|g" ${ZEN_CONFIGMAP_FILE}

				#  replace <DatabaseSchema>
				tmp_name="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_SCHEMA)"
				tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
				${SED_COMMAND} "s|<DatabaseSchema>|$tmp_name|g" ${ZEN_CONFIGMAP_FILE}

				#  replace <DatabaseUser>
				tmp_name="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_USER)"
				tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
				${SED_COMMAND} "s|<DatabaseUser>|$tmp_name|g" ${ZEN_CONFIGMAP_FILE}
			fi # End of ENABLE_VAULT_ON_EXIST check
   	fi

    # Create Secret/configMap for BTS metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_BTS_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        #  replace secret file folder
        bts_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        bts_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$bts_external_db_cert_folder")
        if [[ -z $bts_external_db_cert_folder || $bts_external_db_cert_folder == "" ]]; then
            bts_external_db_cert_folder=$BTS_DB_SSL_CERT_FOLDER
        fi
        
        create_bts_external_db_secret_template

        # #  replace <DatabaseUser>
        # tmp_name="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_USER_NAME)"
        # tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
        # ${SED_COMMAND} "s|<USERNAME>|$tmp_name|g" ${BTS_SECRET_FILE}

        # #  replace <DatabaseUser_password>
        # tmp_name="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_USER_PASSWORD)"
        # tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
        # ${SED_COMMAND} "s|<PASSWORD>|$tmp_name|g" ${BTS_SECRET_FILE}

        # Skip generating K8s BTS Configmap if ENABLE_VAULT_ON_EXIST mode is on
        if [[ "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
            create_bts_external_db_configmap_template
            #  replace <DatabaseHostName>
            tmp_name="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_HOSTNAME)"
            tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
            ${SED_COMMAND} "s|<DatabaseHostName>|$tmp_name|g" ${BTS_CONFIGMAP_FILE}

            #  replace <DatabasePort>
            tmp_name="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_PORT)"
            tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
            ${SED_COMMAND} "s|<DatabasePort>|$tmp_name|g" ${BTS_CONFIGMAP_FILE}

            #  replace <DatabaseName>
            tmp_name="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_NAME)"
            tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
            ${SED_COMMAND} "s|<DatabaseName>|$tmp_name|g" ${BTS_CONFIGMAP_FILE}

            #  replace <DatabaseUserName>
            tmp_name="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_USER_NAME)"
            tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
            ${SED_COMMAND} "s|<DatabaseUserName>|$tmp_name|g" ${BTS_CONFIGMAP_FILE}
        fi
    fi

    # Create Issuer to make Opensearch/Kafka use external certificate
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_CERT_OPENSEARCH_KAFKA_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        create_cp4ba_tls_issuer_template
        #  replace secret file folder
        external_cert_issuer_folder="$(prop_user_profile_property_file CP4BA.EXTERNAL_ROOT_CA_FOR_OPENSEARCH_KAFKA_FOLDER)"
        external_cert_issuer_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$external_cert_issuer_folder")
        if [[ -z $external_cert_issuer_folder || $external_cert_issuer_folder == "" ]]; then
            external_cert_issuer_folder=$CP4BA_TLS_ISSUER_CERT_FOLDER
        fi
        ${SED_COMMAND} "s|<cp4a-issuer-tls-crt-file-in-local>|$external_cert_issuer_folder|g" ${CP4BA_TLS_ISSUER_SECRET_FILE}
    fi

    # Create Content Cortex AI Services secret
    if [[ "$SETUP_CONTENT_CORTEX_AI_SERVICES" == "true" ]]; then
        wait_msg "Creating Content Cortex AI Services secret template"
        
        # Note: Property file was already parsed and validated in the validation section
        # We just need to generate the secret here
        
        # Skip generating K8s CCX secret if vault is enabled
        if [[ $vault_enabled != 'true' ]]; then
            # Generate multi-provider secret (property file already parsed during validation)
            generate_multi_provider_secret
            
            # Generate SSL secret template for WatsonX LWE providers with SSL enabled
            create_watsonx_lwe_ssl_secret_template
            
            # Note: CR generation is not needed here - it will be handled by the main CP4BA CR generation
        else
        # Generate SPC and JSON template for Vault
           # Generate multi-provider secret (property file already parsed during validation)
           generate_multi_provider_vault_template

           # Generate SSL secret template for WatsonX LWE providers with SSL enabled
           create_watsonx_lwe_ssl_vault_template
        fi
        
        success "Created Content Cortex AI Services secret template\n"
    fi

    tips

    # Show which certificate file should be copied into which folder
    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    for item in "${db_server_array[@]}"; do
        # DB SSL Enabled
        tmp_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SSL_ENABLE)")
        tmp_ssl_flag=$(echo "$tmp_ssl_flag" | tr '[:upper:]' '[:lower:]')
        while true; do
            case "$tmp_ssl_flag" in
            "true"|"yes"|"y")
                tmp_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SSL_CERT_FILE_FOLDER)")
                if [[ $DB_TYPE == "oracle" ]]; then
                    tmp_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_oracle_server_property_file $item.ORACLE_JDBC_URL)")
                else
                    tmp_dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SERVERNAME)")
                fi
                # check AE/APP for oracle
                if [[ $DB_TYPE == "oracle" && (" ${pattern_cr_arr[@]}" =~ "application" || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer") ]]; then
                    tmp_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.ORACLE_SSO_WALLET_CERT_FOLDER)")
                    if [[ ! -z $tmp_folder || $tmp_folder != "" ]]; then
                        msgB "* Get the wallet SSO file \"cwallet.sso\" from your local or remote database server that uses the JDBC URL: \"$tmp_db_jdbc_url\", and copy this wallet SSO file into the folder \"$tmp_folder\" before you create the secret for the oracle database SSL"
                    fi
                fi
                break
                ;;
            "false"|"no"|"n"|"")
                break
                ;;
            *)
                fail "$item.DATABASE_SSL_ENABLE is not valid value in the \"cp4ba_db_server.property\". Exiting ..."
                exit 1
                ;;
            esac
        done
        tmp_redis_host="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_HOST)"
        tmp_redis_cert_folder="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_SSL_CERT_FILE_FOLDER)"
        tmp_redis_tls_enabled="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_TLS_ENABLED)"
        tmp_redis_tls_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_tls_enabled")
        if [[ $tmp_redis_tls_enabled == "Yes" || $tmp_redis_tls_enabled == "YES" || $tmp_redis_tls_enabled == "Y" || $tmp_redis_tls_enabled == "True" || $tmp_redis_tls_enabled == "true" ]]; then
            msgB "* Get the certificate file \"redis.pem\" from the remote Redis database server \"$tmp_redis_host\", and copy it into the folder \"$tmp_redis_cert_folder\" before you create the Kubernetes secret for the database SSL"
        fi

        tmp_redis_host="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_HOST)"
        tmp_redis_cert_folder="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_SSL_CERT_FILE_FOLDER)"
        tmp_redis_tls_enabled="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_TLS_ENABLED)"
        tmp_redis_tls_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_tls_enabled")
        if [[ $tmp_redis_tls_enabled == "Yes" || $tmp_redis_tls_enabled == "YES" || $tmp_redis_tls_enabled == "Y" || $tmp_redis_tls_enabled == "True" || $tmp_redis_tls_enabled == "true" ]]; then
            msgB "* Get the certificate file \"redis.pem\" from the remote Redis database server \"$tmp_redis_host\", and copy it into the folder \"$tmp_redis_cert_folder\" before you create the Kubernetes secret for the database SSL"
        fi

    done

    # AI Services: Show which certificate file should be copied into which folder
    # Note: With multi-provider support, SSL certificates are handled per provider
    # The property file contains ENABLE_TLS_CERT and TLS_CERT_LOCATION for each provider
    if [[ "$SETUP_CONTENT_CORTEX_AI_SERVICES" == "true" ]]; then
        # Certificate instructions are now included in the property file comments
        # Users should refer to the property file for provider-specific SSL configuration
        :  # No-op - SSL cert handling is now per-provider in the property file
    fi

    # LDAP: Show which certificate file should be copy into which folder
    #tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ldap_property_file LDAP_SSL_ENABLED)")
    #tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')

    #if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
    #    tmp_folder="$(prop_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
    #    tmp_ldapserver="$(prop_ldap_property_file LDAP_SERVER)"
    #    msgB "* Get the \"ldap-cert.crt\" from the remote LDAP server \"$tmp_ldapserver\", and copy it into the folder \"$tmp_folder\" before you create the Kubernetes secret for the LDAP SSL"
    #fi

    #if [[ $SET_EXT_LDAP == "Yes" ]]; then
    #    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ext_ldap_property_file LDAP_SSL_ENABLED)")
    #   tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    #    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
    #        tmp_folder="$(prop_ext_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
    #        tmp_ldapserver="$(prop_ext_ldap_property_file LDAP_SERVER)"
    #        msgB "* You enabled external LDAP SSL, so get the \"external-ldap-cert.crt\" from the remote LDAP server \"$tmp_ldapserver\", and copy it into the folder \"$tmp_folder\" before you create the secret for the external LDAP SSL"
    #    fi
    #fi


    if [[ $vault_enabled != 'true' ]]; then
       msgB "* You can use this shell script to create the secret automatically (NOTE: In the scenario that separation of operators and operands is selected , you must switch to the CP4BA DEPLOYMENT PROJECT first): $CREATE_SECRET_SCRIPT_FILE"
    #DBACLD-185209: Vault implementation
    else
       
        echo_red "\n**** For Vault integration ****"

        # Check CSV version to determine if we are in the middle of an upgrade scenario
        cp4a_oper_csv_name=$(${CLI_CMD} get csv -n $CP4BA_OPERATOR_NS --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
        cp4a_oper_csv_ver=$(${CLI_CMD} get csv -n $CP4BA_OPERATOR_NS $cp4a_oper_csv_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')

        if [[ "$cp4a_oper_csv_ver" == "${CP4BA_CSV_VERSION//v/}" ]]; then
            # If CSV version matches the cert-kube CSV, it means we are NOT in a upgrade scenario (i.e. we are enabling vault on non-vault deployment)
            get_vault_secret_list

            echo_bold " 1. If you have not yet done so, please ensure you have followed the instructions in the CP4BA Knowledge Center topic \"Optional: Preparing for external secret management\""
            echo_bold "\n 2. Please REVIEW the JSON templates in the folders listed below and create the secrets in Vault: " 
            echo "    - $VAULT_SECRET_FILE_FOLDER"
            echo "    - $VAULT_TLS_SECRET_FILE_FOLDER"
            echo_bold "\n 3. If you want to manually configure other optional custom secrets in your deployment NOT covered by these templates, you will need to manually create the SecretProviderClass and Vault secret based on the corresponding topic for that custom secret in the Knowledge Center, and copy the SecretProviderClass template to the folder from Step 1 (use 'secret' subfolder for non-certificate secrets, and 'tls' subfolder for certificate secrets)"
            echo "    - FYI: The script has created templates for the following custom secrets (these secrets are already covered):"
            echo_bold "     $VAULT_SECRET_LIST"
            echo_bold "\n 4. Please run the script \"${CREATE_SECRET_SCRIPT_FILE}\" to create the 'SecretProviderClasses' in your cluster."
            echo "    - NOTE: This script only creates the 'SecretProviderClasses', it will NOT create secrets in Vault.  You must manually create them using the provided JSON templates mentioned in Step 2."
    
            # Iterate through all the SPC yaml files at $VAULT_SECRET_PARENT_FOLDER
            # Read the metadata.annotations."cp4ba.ibm.com/owned-by" field in each SPC yaml file
            # to get the list of comma-separated operators that should have the SPC mounted.
            # Duplicates will be removed when we aggregate the list of operators from all the SPC yaml files.
            # If a SPC does not have the "cp4ba.ibm.com/owned-by" annotation, we display a warning
            # and ignore that SPC for the purpose of determining which CSVs to patch.
            # Operators in VAULT_EXCLUDE_PATCH_LIST_OF_CSV (exclusion list) are removed from the final CSV list.
            get_vault_csv_list_from_spc "$CP4BA_CSV_VERSION"
            
            if [[ -n "$_vault_csv_list" ]]; then
                echo_bold "\n 5. Please run the following command to patch the Operator CSV(s) for Vault:"
                if [[ $SEPARATE_OPERAND_FLAG == "No" ]]; then
                    msgB "  ./cp4a-vault.sh -m patch --csv \"$_vault_csv_list\" -n $CP4BA_SERVICES_NS"
                else
                    msgB "  ./cp4a-vault.sh -m patch --csv \"$_vault_csv_list\" -n $CP4BA_SERVICES_NS --operatorNamespace $CP4BA_OPERATOR_NS"
                fi
            fi
            
            # If enabling Vault for existing deployment, they do not need to configure databases or recreate the CR.
            if [[ "$ENABLE_VAULT_ON_EXIST" == "true" ]]; then
                echo_bold "\n 6. Please run the command \"./cp4a-prerequisites.sh -m validate --enable-external-secret-management -n $CP4BA_SERVICES_NS\" to verify the configurations selected for this deployment and verify that the required secrets have been created correctly."
                echo_bold "\n 7. Please edit your CR to set the following property to enable Vault integration for custom secrets: \"spec.shared_configuration.sc_vault_configuration.enable_external_secret_store: true\""
            fi

        # End of the non-upgrade scenario (enabling vault for non-vault deployment)
        else # UPGRADE SCENARIO
            # For upgrade scenario, we want different wording for the instructions and we don't want user to run "cp4a-vault.sh" and "cp4a-prerequisites.sh -m validate"
            echo_bold "\nIt has been detected that you are upgrading from an earlier version of CP4BA with Vault-enabled. Please follow the steps below.\n" 
            echo_bold " 1. Please review the instructions in the CP4BA Knowledge Center topic \"Optional: Preparing for external secret management\" for any changes in the prerequisites for Vault since the last release of CP4BA."
            echo_bold "\n 2. There may be new secrets needed in this version of CP4BA. Please REVIEW the JSON templates in the folders listed below and create any secrets you don't yet have in Vault: " 
            echo "    - $VAULT_SECRET_FILE_FOLDER"
            echo "    - $VAULT_TLS_SECRET_FILE_FOLDER"
            echo_bold "\n 3. Please run the script \"${CREATE_SECRET_SCRIPT_FILE}\" to create the 'SecretProviderClasses' in your cluster."
            echo_bold "\n NOTE: Please do NOT run the \"cp4a-vault.sh\" script in this scenario.  It will be handled by the upgrade portion in the subsequent steps."
            echo_bold "\n 4. Please reference the upgrade topic in the CP4BA Knowledge Center for the remaining steps for upgrade."
        fi 
        # End of the upgrade scenario (vault-enabled to vault-enabled)

    fi
    # End of the "vault-enabled" clause

    if [[ "$UPDATE_COMPONENTS" == "true" ]]; then
        msgB "* If you have manually added additional object stores post deployment, you must review the \"ibm-fncm-secret\" secret template generated at ${CUR_DIR}/cp4ba-prerequisites/project/$CP4BA_SERVICES_NS/secret_template/content-cortex and make neccessary updates for the additional content object stores before applying the secret templates. For more information, from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE, navigate to Installing --> Installing Production Deployment --> Installing a CP4BA multi-pattern production deployment --> Preparing your chosen capabilities --> Content Cortex  --> Creating the Content Cortex  databases and secrets without running the provided scripts --> Creating secrets to protect sensitive Content Cortex  configuration data."
    fi 

    if [[ "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
      msgB "* Create the databases and Kubernetes secrets manually based on your modified \"DB SQL statement file\" and \"YAML template for secret\"."
      msgB "* Run the command  \"./cp4a-prerequisites.sh -m validate -n $CP4BA_SERVICES_NS\" to verify the configurations selected for this deployment and verify that the required secrets have been created correctly."
    fi
    
}

function create_temp_property_file(){
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
            *)
                pattern_joined="$pattern_joined$delim$item"
                delim=","
                ;;
            esac
        fi
    done
    # pattern_joined="foundation$delim$pattern_joined"

   # Convert pattern display name array to list by common
    delim=""
    pattern_name_joined=""
    for item in "${pattern_arr[@]}"; do
        pattern_name_joined="$pattern_name_joined$delim$item"
        delim=","
    done

   # Convert optional components array to list by common
    delim=""
    opt_components_joined=""
    for item in "${OPT_COMPONENTS_CR_SELECTED[@]}"; do
        opt_components_joined="$opt_components_joined$delim$item"
        delim=","
    done

   # Convert optional components name to list by common
    delim=""
    opt_components_name_joined=""
    for item in "${OPT_COMPONENTS_SELECTED[@]}"; do
        opt_components_name_joined="$opt_components_name_joined$delim$item"
        delim=","
    done


   # Convert foundation array to list by common
    delim=""
    foundation_components_joined=""
    for item in "${foundation_component_arr[@]}"; do
        foundation_components_joined="$foundation_components_joined$delim$item"
        delim=","
    done

    # Keep pattern_joined value in temp property file
    rm -rf $TEMPORARY_PROPERTY_FILE >/dev/null 2>&1
    mkdir -p $TEMP_FOLDER >/dev/null 2>&1
    > $TEMPORARY_PROPERTY_FILE
    # save pattern list
    echo "PATTERN_LIST=$pattern_joined" >> ${TEMPORARY_PROPERTY_FILE}

    # same pattern name list
    echo "PATTERN_NAME_LIST=$pattern_name_joined" >> ${TEMPORARY_PROPERTY_FILE}

    # save foundation list
    echo "FOUNDATION_LIST=$foundation_components_joined" >> ${TEMPORARY_PROPERTY_FILE}

    # save components list
    if [ "${#optional_component_cr_arr[@]}" -eq "0" ]; then
        echo "OPTION_COMPONENT_LIST=" >> ${TEMPORARY_PROPERTY_FILE}
        echo "OPTION_COMPONENT_NAME_LIST=" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "OPTION_COMPONENT_LIST=$opt_components_joined" >> ${TEMPORARY_PROPERTY_FILE}
        echo "OPTION_COMPONENT_NAME_LIST=$opt_components_name_joined" >> ${TEMPORARY_PROPERTY_FILE}
    fi
    # save ldap type
    echo "LDAP_TYPE=$LDAP_TYPE" >> ${TEMPORARY_PROPERTY_FILE}
    # save db type
    echo "DB_TYPE=$DB_TYPE" >> ${TEMPORARY_PROPERTY_FILE}
    # save content_os_number
    # msgB "$content_os_number"; sleep 300
    if (( content_os_number >= 0 )); then
        echo "CONTENT_OS_NUMBER=$content_os_number" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "CONTENT_OS_NUMBER=" >> ${TEMPORARY_PROPERTY_FILE}
    fi
    # save content_os_number db_server_number
    if (( db_server_number > 0 )); then
        echo "DB_SERVER_NUMBER=$db_server_number" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "DB_SERVER_NUMBER=0" >> ${TEMPORARY_PROPERTY_FILE}
    fi
    # save external ldap flag
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        echo "EXTERNAL_LDAP_ENABLED=Yes" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "EXTERNAL_LDAP_ENABLED=No" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # save limited CPE storage support flag
    if [[ $CPE_FULL_STORAGE == "Yes" ]]; then
        echo "CPE_FULL_STORAGE_ENABLED=Yes" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "CPE_FULL_STORAGE_ENABLED=No" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # save GPU enabled worker nodes flag
    if [[ $ENABLE_GPU_ARIA == "Yes" ]]; then
        echo "ENABLE_GPU_ARIA_ENABLED=Yes" >> ${TEMPORARY_PROPERTY_FILE}
        echo "NODE_LABEL_KEY=${nodelabel_key}" >> ${TEMPORARY_PROPERTY_FILE}
        echo "NODE_LABEL_VALUE=${nodelabel_value}" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "ENABLE_GPU_ARIA_ENABLED=No" >> ${TEMPORARY_PROPERTY_FILE}
        echo "NODE_LABEL_KEY=" >> ${TEMPORARY_PROPERTY_FILE}
        echo "NODE_LABEL_VALUE=" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # save LDAP/DB required flag for wfps
    echo "LDAP_WFPS_AUTHORING_FLAG=$LDAP_WFPS_AUTHORING" >> ${TEMPORARY_PROPERTY_FILE}

    # From $CP4BA_RELEASE_BASE. the wfps authoring always use external postgresql db
    EXTERNAL_DB_WFPS_AUTHORING="Yes"
    echo "EXTERNAL_DB_WFPS_AUTHORING_FLAG=$EXTERNAL_DB_WFPS_AUTHORING" >> ${TEMPORARY_PROPERTY_FILE}

    # save fips enabled flag
    if [[ $FIPS_ENABLED == "true" ]]; then
        echo "FIPS_ENABLED_FLAG=true" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "FIPS_ENABLED_FLAG=false" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # save external Postgres DB as IM metastore DB flag
    if [[ $EXTERNAL_POSTGRESDB_FOR_IM == "true" ]]; then
        echo "EXTERNAL_POSTGRESDB_FOR_IM_FLAG=true" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "EXTERNAL_POSTGRESDB_FOR_IM_FLAG=false" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # save external Postgres DB as Zen metastore DB flag
    if [[ $EXTERNAL_POSTGRESDB_FOR_ZEN == "true" ]]; then
        echo "EXTERNAL_POSTGRESDB_FOR_ZEN_FLAG=true" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "EXTERNAL_POSTGRESDB_FOR_ZEN_FLAG=false" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # save external Postgres DB as BTS metastore DB flag
    if [[ $EXTERNAL_POSTGRESDB_FOR_BTS == "true" ]]; then
        echo "EXTERNAL_POSTGRESDB_FOR_BTS_FLAG=true" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "EXTERNAL_POSTGRESDB_FOR_BTS_FLAG=false" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # save external Postgres DB for ADPGG/DICMS flag
    if [[ $EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS == "true" ]]; then
        echo "EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS_FLAG=true" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS_FLAG=false" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # save external certificate for Opensearch/Kafka flag
    if [[ $EXTERNAL_CERT_OPENSEARCH_KAFKA == "true" ]]; then
        echo "EXTERNAL_CERT_OPENSEARCH_KAFKA_FLAG=true" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "EXTERNAL_CERT_OPENSEARCH_KAFKA_FLAG=false" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # save profile size
    echo "PROFILE_SIZE_FLAG=$PROFILE_TYPE" >> ${TEMPORARY_PROPERTY_FILE}

    # Writing a flag to the temp property file so that we can detect if the script is being used for updating the deployment patterns.
    # This flag will help the cp4a-deployment.sh script perform the neccessary logic to generate the CR
    if [[ -z $UPDATE_COMPONENTS ]]; then
        echo "UPDATE_COMPONENTS=false" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "UPDATE_COMPONENTS=true" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # Add the flag for content cortex AI services operator
    if [[ -z $SETUP_CONTENT_CORTEX_AI_SERVICES ]]; then
        echo "SETUP_CONTENT_CORTEX_AI_SERVICES=false" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "SETUP_CONTENT_CORTEX_AI_SERVICES=$SETUP_CONTENT_CORTEX_AI_SERVICES" >> ${TEMPORARY_PROPERTY_FILE}
    fi
    # Add Watsonx deployment type and authentication method
    if [[ -n $WATSONX_DEPLOYMENT_TYPE ]]; then
        echo "WATSONX_DEPLOYMENT_TYPE=$WATSONX_DEPLOYMENT_TYPE" >> ${TEMPORARY_PROPERTY_FILE}
    fi
    # Save WFA-specific deployment type (set interactively by select_wfa_deployment_type())
    # Used by create_workflow_assistant_secret_template() during generate mode.
    if [[ -n $WFA_WATSONX_DEPLOYMENT_TYPE ]]; then
        echo "WFA_WATSONX_DEPLOYMENT_TYPE=$WFA_WATSONX_DEPLOYMENT_TYPE" >> ${TEMPORARY_PROPERTY_FILE}
    fi
    
    if [[ -n $WATSONX_HAS_API_KEY ]]; then
        echo "WATSONX_HAS_API_KEY=$WATSONX_HAS_API_KEY" >> ${TEMPORARY_PROPERTY_FILE}
    fi
}

function create_property_file(){
    #DBACLD-194917: Create a random password for EDB/CNPG to use.
    local RANDOM_EDB_PASSWORD
    RANDOM_EDB_PASSWORD=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 16)
    if [[ $DB_TYPE == "oracle" ]]; then
        local DB_SERVER_PREFIX="<DB_INSTANCE_NAME>"
    else
        local DB_SERVER_PREFIX="<DB_ALIAS_NAME>"
    fi
    printf "\n"
    # mkdir -p $PREREQUISITES_FOLDER_BAK >/dev/null 2>&1

    if [[ -d "$PROPERTY_FILE_FOLDER" ]]; then
        tmp_property_file_dir="${PROPERTY_FILE_FOLDER_BAK}_$(date +%Y-%m-%d-%H:%M:%S)"
        mkdir -p "$tmp_property_file_dir" >&3 2>&3
        ${COPY_CMD} -rf "${PROPERTY_FILE_FOLDER}" "${tmp_property_file_dir}"
    fi
    rm -f $PROPERTY_FILE_FOLDER/cp4ba_db_name_user.property >/dev/null 2>&1
    rm -f $PROPERTY_FILE_FOLDER/cp4ba_db_server.property >/dev/null 2>&1
    rm -f $PROPERTY_FILE_FOLDER/cp4ba_LDAP.property >/dev/null 2>&1
    rm -f $PROPERTY_FILE_FOLDER/cp4ba_user_profile.property >/dev/null 2>&1
    rm -f $PROPERTY_FILE_FOLDER/cp4ba_ai_services.property >/dev/null 2>&1
    
    # Only if the user is NOT running the script to update components or enable vault, we remove the SSL folder each reconcile
    if [[ -z $UPDATE_COMPONENTS && "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
        rm -rf $SSL_CERT_FOLDER >/dev/null 2>&1
    fi
    # We run these commands regardless of whether the script is used to update components or not
    # For the case it is not being used for updating components , we will have a new set of cert folders each reconcile which is the expected behaviour
    # If the script is being used for updating components, the user could be
    # 1. Using the same folder paths to re-run the scripts and in that case any already created folder paths will remain as is and hence the certs in those folders will not be removed
    # 2. Using a different folder path as compared to what was used when the script was run the first time and in this scenario we would still need to recreate all folder paths and user WILL have to recopy the certs
    # https://jsw.ibm.com/browse/DBACLD-206231
    mkdir -p $SSL_CERT_FOLDER >/dev/null 2>&1
    mkdir -p $LDAP_SSL_CERT_FOLDER >/dev/null 2>&1
    # Create the SSL secret folder for the content cortex AI Services operator if chosen
    if [[ $SETUP_CONTENT_CORTEX_AI_SERVICES == "true" ]]; then
        mkdir -p $WATSONX_SSL_CERT_FOLDER >/dev/null 2>&1
    fi

    mkdir -p $DB_SSL_CERT_FOLDER >/dev/null 2>&1

    # DBACLD-217419: Only create Vault certificate folders if Vault integration is enabled
    if [[ "$VAULT_ENABLED" == "true" ]]; then
        mkdir -p $ROOT_CA_CERT_FOLDER >/dev/null 2>&1
        mkdir -p $EXTERNAL_TLS_CERT_FOLDER >/dev/null 2>&1
        mkdir -p $TRUSTED_CERT_FOLDER >/dev/null 2>&1 
    fi

    > ${DB_SERVER_INFO_PROPERTY_FILE}
    if (( db_server_number > 0 )); then
    INFO "Creating database and LDAP property files for CP4BA."


    wait_msg "Creating DB Server property file for CP4BA"
    # Assumption: all FNCM DB use same database server in phase1
    # > ${DB_SERVER_INFO_PROPERTY_FILE}

    # For mutiple db server/instance in phase2
    # get value from db_server_array for db server/instance

        delim=""
        db_server_joined=""
        for ((j=0;j<${db_server_number};j++)); do
            db_server_joined="$db_server_joined$delim${db_server_array[j]}"
            delim=","
        done
        tip="## Please input the value for the multiple database server/instance name, this key supports comma-separated lists. ##"
        echo "$tip" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        tip="## (NOTES: The value (CAN NOT CONTAIN DOT CHARACTER) is alias name for database server/instance, it is not real database server/instance host name.) ##"
        echo "$tip" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "DB_SERVER_LIST=\"$db_server_joined\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}

    # Put DB server/instance into array

    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    for item in "${db_server_array[@]}"; do
        item_tmp=$(echo "$item"| tr '[:upper:]' '[:lower:]')
        replace_str="-"
        item_tmp=${item_tmp//_/$replace_str}

        mkdir -p "${DB_SSL_CERT_FOLDER}/$item" >/dev/null 2>&1
        tip="## Property for Database Server \"$item\" required by IBM Cloud Pak for Business Automation on ${DB_TYPE} type database ##"
        echo "####################################################" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "$tip" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "####################################################" >> ${DB_SERVER_INFO_PROPERTY_FILE}

        for i in "${!GCDDB_COMMON_PROPERTY[@]}"; do
            if [[ ($DB_TYPE == "db2"*) && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_USER_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "ORACLE_JDBC_URL" ]]; then
                echo "${GCDDB_PROPERTY_COMMENTS[i]}" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "$item.${GCDDB_COMMON_PROPERTY[i]}=\"\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "" >> "${DB_SERVER_INFO_PROPERTY_FILE}"
            elif [[ $DB_TYPE == "oracle" && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_USER_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "DATABASE_SERVERNAME" && ${GCDDB_COMMON_PROPERTY[i]} != "DATABASE_PORT" && ${GCDDB_COMMON_PROPERTY[i]} != "HADR_STANDBY_SERVERNAME" && ${GCDDB_COMMON_PROPERTY[i]} != "HADR_STANDBY_PORT" ]]; then
                echo "${GCDDB_PROPERTY_COMMENTS[i]}" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "$item.${GCDDB_COMMON_PROPERTY[i]}=\"\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "" >> "${DB_SERVER_INFO_PROPERTY_FILE}"
            elif [[ ($DB_TYPE == "postgresql"* || $DB_TYPE == "sqlserver") && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_USER_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "HADR_STANDBY_SERVERNAME" && ${GCDDB_COMMON_PROPERTY[i]} != "HADR_STANDBY_PORT" && ${GCDDB_COMMON_PROPERTY[i]} != "ORACLE_JDBC_URL" ]]; then
                echo "${GCDDB_PROPERTY_COMMENTS[i]}" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "$item.${GCDDB_COMMON_PROPERTY[i]}=\"\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "" >> "${DB_SERVER_INFO_PROPERTY_FILE}"
            fi
        done
        # set default value
        # For db2HADR we are using this variable DB_TYPE in lowercase in the script but want to make sure in the property file it is db2HADR hence the special condition
        if [[ $DB_TYPE == "db2hadr" ]]; then
            ${SED_COMMAND} "s|$item.DATABASE_TYPE=\"\"|$item.DATABASE_TYPE=\""db2HADR"\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        # For db2rdsHADR we are using this variable DB_TYPE in lowercase in the script but want to make sure in the property file it is db2rdsHADR hence the special condition
        # For DBACLD-163779
        elif [[ $DB_TYPE == "db2rdshadr" ]]; then
            ${SED_COMMAND} "s|$item.DATABASE_TYPE=\"\"|$item.DATABASE_TYPE=\""db2rdsHADR"\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        else
            ${SED_COMMAND} "s|$item.DATABASE_TYPE=\"\"|$item.DATABASE_TYPE=\"${DB_TYPE}\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        fi
        ${SED_COMMAND} "s|$item.DATABASE_SSL_CERT_FILE_FOLDER=\"\"|$item.DATABASE_SSL_CERT_FILE_FOLDER=\"${DB_SSL_CERT_FOLDER}/$item\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|<DB_SSL_CERT_FOLDER>|${DB_SSL_CERT_FOLDER}/$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|$item.DATABASE_SSL_ENABLE=\"\"|$item.DATABASE_SSL_ENABLE=\"True\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|$item.DATABASE_SSL_SECRET_NAME=\"\"|$item.DATABASE_SSL_SECRET_NAME=\"ibm-cp4ba-db-ssl-secret-for-${item_tmp}\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}

        # set default value for EDB Postgres
        if [[ $DB_TYPE == "postgresql-edb" ]]; then
            ${SED_COMMAND} "s|$item.DATABASE_SSL_SECRET_NAME=\"ibm-cp4ba-db-ssl-secret-for-${item_tmp}\"|$item.DATABASE_SSL_SECRET_NAME=\"\{{ meta.name }}-pg-client-cert-secret\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} "s|$item.DATABASE_SERVERNAME=\"\"|$item.DATABASE_SERVERNAME=\"postgres-cp4ba-rw.{{ meta.namespace }}.svc\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} "s|$item.DATABASE_PORT=\"\"|$item.DATABASE_PORT=\"5432\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            # By default, the DATABASE_SSL_ENABLE/ POSTGRESQL_SSL_CLIENT_SERVER always is true.
            ${SED_COMMAND} "/^## The parameter is used to support database connection over SSL/d" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE/d" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} "/^## If enabled DB SSL, you need copy the SSL certificate file/d" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER/d" ${DB_SERVER_INFO_PROPERTY_FILE}
        fi

        # set postgreSQL client and server authentication by default for 22.0.2 (All components support client/server auth)
        if [[ $DB_TYPE == "postgresql" ]]; then
            # fix sed issue on Mac, DO NOT format code
            nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
            if [[ "$machine" == "Mac" ]]; then
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\ 
element_val.POSTGRESQL_SSL_CLIENT_SERVER=\"True\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\ 
## Whether your PostgreSQL database enables server only or both server and client authentication. Default value is \"True\" for enabling both server and client authentication, \"False\" is for enabling server-only authentication.\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
            else
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\element_val.POSTGRESQL_SSL_CLIENT_SERVER=\"True\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\## Whether your PostgreSQL database enables server only or both server and client authentication. Default value is \"True\" for enabling both server and client authentication, \"False\" is for enabling server-only authentication." ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}
            fi
            ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        fi

        # Add sslmode [require|verify-ca|verify-full] for postgresql
        if [[ $DB_TYPE == "postgresql" ]]; then
            nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
            if [[ "$machine" == "Mac" ]]; then
                ${SED_COMMAND} "/^$item.POSTGRESQL_SSL_CLIENT_SERVER=.*/a\
element_val.POSTGRESQL_SSL_MODE=\"require\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.POSTGRESQL_SSL_CLIENT_SERVER=.*/a\
## There are three modes [require|verify-ca|verify-full]. Update this value to match your PostgreSQL server SSL configuration.\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.POSTGRESQL_SSL_CLIENT_SERVER=.*/a\
## The value for the sslmode which determines whether or with what priority a secure SSL TCP/IP connection will be negotiated with the PostgreSQL database server.\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.POSTGRESQL_SSL_CLIENT_SERVER=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
            else
                ${SED_COMMAND} "/^$item.POSTGRESQL_SSL_CLIENT_SERVER=.*/a\element_val.POSTGRESQL_SSL_MODE=\"require\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.POSTGRESQL_SSL_CLIENT_SERVER=.*/a\## There are three modes [require|verify-ca|verify-full]. Update this value to match your PostgreSQL server SSL configuration." ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.POSTGRESQL_SSL_CLIENT_SERVER=.*/a\## The value for the sslmode which determines whether or with what priority a secure SSL TCP/IP connection will be negotiated with the PostgreSQL database server." ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.POSTGRESQL_SSL_CLIENT_SERVER=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}
            fi
            ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        fi

        # insert comment for DATABASE_SSL_CERT_FILE_FOLDER when POSTGRESQL_SSL_CLIENT_SERVER=Yes
        if [[ $DB_TYPE == "postgresql" ]]; then
            # fix sed issue on Mac, DO NOT format code
            nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
            if [[ "$machine" == "Mac" ]]; then
                ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\ 
## If POSTGRESQL_SSL_CLIENT_SERVER is \"True\" and DATABASE_SSL_ENABLE is \"True\", please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\".\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                #DBACLD-237301: Remove this comment line in 26.0.0-GA to indicate only certificate-based authentication is supported for PostgreSQL in 26.0.0-GA.
                if ! skip_edb; then
                    ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\ 
## If POSTGRESQL_SSL_CLIENT_SERVER is \"False\" and DATABASE_SSL_ENABLE is \"True\", please get the SSL certificate file (rename db-cert.crt) from server and then copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\".\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                fi
            else
                ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\## If POSTGRESQL_SSL_CLIENT_SERVER is \"True\" and DATABASE_SSL_ENABLE is \"True\", please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\"." ${DB_SERVER_INFO_PROPERTY_FILE}
                if ! skip_edb; then
                    ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\## If POSTGRESQL_SSL_CLIENT_SERVER is \"False\" and DATABASE_SSL_ENABLE is \"True\", please get the SSL certificate file (rename db-cert.crt) from server and then copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\"." ${DB_SERVER_INFO_PROPERTY_FILE}
                fi
            fi
            ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} '/## If enabled DB SSL/d' ${DB_SERVER_INFO_PROPERTY_FILE}
        fi

        # set oracle_url_without_wallet_directory for AE/APP
        if [[ $DB_TYPE == "oracle" && (" ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "application" || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer") ]]; then
            # fix sed issue on Mac, DO NOT format code
            nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
            if [[ "$machine" == "Mac" ]]; then
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
element_val.ORACLE_SSO_WALLET_CERT_FOLDER=\"${DB_SSL_CERT_FOLDER}//$item\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
## Get the wallet SSO file cwallet.sso on your local or remote database server. Copy this wallet SSO file to \"${DB_SSL_CERT_FOLDER}//$item\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
element_val.ORACLE_SSO_WALLET_SECRET_NAME=\"oracle-wallet-sso-secret-for-$item_tmp\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
## Secret name for wallet SSO file, only for Application Engine or Playback Server with oracle database and ssl enabled.\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
element_val.ORACLE_URL_WITH_WALLET_DIRECTORY=\"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your-oracle-database-hostname>)(PORT=<your-database-port>))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-database-service-name>))(SECURITY=(SSL_SERVER_DN_MATCH=FALSE)(MY_WALLET_DIRECTORY=/shared/resources/oracle/wallet)))\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
## Required only by Application Engine or Application Playback Server when type is Oracle and SSL is enabled. The format must be purely oracle descriptor like: (DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your-oracle-database-hostname>)(PORT=<your-database-port>))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-database-service-name>))(SECURITY=(SSL_SERVER_DN_MATCH=FALSE)(MY_WALLET_DIRECTORY=/shared/resources/oracle/wallet)))\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
element_val.ORACLE_URL_WITHOUT_WALLET_DIRECTORY=\"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your-database-host/IP>)(PORT=<your-database-port>))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-service-name>)))\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
## Required only by Application Engine or Application Playback Server when type is Oracle, both ssl and non-ssl (NOTES: PROTOCOL=TCP for non-ssl, PROTOCOL=TCPS for ssl). The format must be purely oracle descriptor like: (DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your-database-host/IP>)(PORT=<your-database-port>))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-service-name>)))\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            else
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\element_val.ORACLE_SSO_WALLET_CERT_FOLDER=\"${DB_SSL_CERT_FOLDER}/$item\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\## Get the wallet SSO file cwallet.sso on your local or remote database server. Copy this wallet SSO file to \"${DB_SSL_CERT_FOLDER}/$item\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\element_val.ORACLE_SSO_WALLET_SECRET_NAME=\"oracle-wallet-sso-secret-for-$item_tmp\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\## Secret name for wallet SSO file, only for Application Engine or Playback Server with oracle database and ssl enabled." ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\element_val.ORACLE_URL_WITH_WALLET_DIRECTORY=\"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your-oracle-database-hostname>)(PORT=<your-database-port>))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-database-service-name>))(SECURITY=(SSL_SERVER_DN_MATCH=FALSE)(MY_WALLET_DIRECTORY=/shared/resources/oracle/wallet)))\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\## Required only by Application Engine or Application Playback Server when type is Oracle and SSL is enabled. The format must be purely oracle descriptor like: (DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your-oracle-database-hostname>)(PORT=<your-database-port>))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-database-service-name>))(SECURITY=(SSL_SERVER_DN_MATCH=FALSE)(MY_WALLET_DIRECTORY=/shared/resources/oracle/wallet)))" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\element_val.ORACLE_URL_WITHOUT_WALLET_DIRECTORY=\"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your-database-host/IP>)(PORT=<your-database-port>))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-service-name>)))\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\## Required only by Application Engine or Application Playback Server when type is Oracle, both ssl and non-ssl (NOTES: PROTOCOL=TCP for non-ssl, PROTOCOL=TCPS for ssl). The format must be purely oracle descriptor like: (DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your-database-host/IP>)(PORT=<your-database-port>))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-service-name>)))" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            fi
        fi
    done

    # Add external PostgreSQL configuration for ADPGG/DICMS when using non-PostgreSQL databases
    if [[ "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" ]]; then
        # Create SSL certificate folder for external PostgreSQL server
        mkdir -p "${DB_SSL_CERT_FOLDER}/${EXTERNAL_POSTGRES_SERVER_PREFIX}" >/dev/null 2>&1
        
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## Please input the value for the external PostgreSQL database server/instance name, which is used for ADPGG/DICMS databases ##" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## (NOTES: The value (CAN NOT CONTAIN DOT CHARACTER) is alias name for database server/instance, it is not real database server/instance host name.) ##" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        
        # Update DB_SERVER_LIST to include external PostgreSQL server
        tmp_db_list=$(prop_db_server_property_file DB_SERVER_LIST)
        tmp_db_list=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_list")
        if [[ -n "$tmp_db_list" ]]; then
            ${SED_COMMAND} "s|DB_SERVER_LIST=\"${tmp_db_list}\"|DB_SERVER_LIST=\"${tmp_db_list},${EXTERNAL_POSTGRES_SERVER_PREFIX}\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        else
            ${SED_COMMAND} "s|DB_SERVER_LIST=\"\"|DB_SERVER_LIST=\"${EXTERNAL_POSTGRES_SERVER_PREFIX}\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        fi
        
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "####################################################" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## Property for Database Server \"${EXTERNAL_POSTGRES_SERVER_PREFIX}\" required by IBM Cloud Pak for Business Automation on postgresql type database ##" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "####################################################" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "${EXTERNAL_POSTGRES_SERVER_PREFIX}.DATABASE_TYPE=\"postgresql\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## Provide the database server name or IP address of the database server. If use IPv6, the addresses need to be enclosed with the square brackets ([...]), e.g. [XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX]." >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "${EXTERNAL_POSTGRES_SERVER_PREFIX}.DATABASE_SERVERNAME=\"<Required>\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## Provide the database server port.  For Postgresql, the default is \"5432\"." >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "${EXTERNAL_POSTGRES_SERVER_PREFIX}.DATABASE_PORT=\"5432\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## The parameter is used to support database connection over SSL for database. Default value is \"True\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "${EXTERNAL_POSTGRES_SERVER_PREFIX}.DATABASE_SSL_ENABLE=\"True\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## Whether your PostgreSQL database enables server only or both server and client authentication. Default value is \"True\" for enabling both server and client authentication, \"False\" is for enabling server-only authentication." >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "${EXTERNAL_POSTGRES_SERVER_PREFIX}.POSTGRESQL_SSL_CLIENT_SERVER=\"True\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## The value for the sslmode which determines whether or with what priority a secure SSL TCP/IP connection will be negotiated with the PostgreSQL database server." >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## There are three modes [require|verify-ca|verify-full]. Update this value to match your PostgreSQL server SSL configuration." >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "${EXTERNAL_POSTGRES_SERVER_PREFIX}.POSTGRESQL_SSL_MODE=\"require\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## If POSTGRESQL_SSL_CLIENT_SERVER is \"True\" and DATABASE_SSL_ENABLE is \"True\", please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory." >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## If POSTGRESQL_SSL_CLIENT_SERVER is \"False\" and DATABASE_SSL_ENABLE is \"True\", please get the SSL certificate file (rename db-cert.crt) from server and then copy into this directory." >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "${EXTERNAL_POSTGRES_SERVER_PREFIX}.DATABASE_SSL_CERT_FILE_FOLDER=\"${DB_SSL_CERT_FOLDER}/${EXTERNAL_POSTGRES_SERVER_PREFIX}\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## The name of the secret that contains the PostgreSQL SSL certificate if SSL is enabled" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "${EXTERNAL_POSTGRES_SERVER_PREFIX}.DATABASE_SSL_SECRET_NAME=\"ibm-cp4ba-db-ssl-secret-for-${EXTERNAL_POSTGRES_SERVER_PREFIX}\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}
    fi

    success "DB Server property file for CP4BA has been created.\n"
    fi

    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "no") && "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then
    > ${LDAP_PROPERTY_FILE}
        wait_msg "Creating LDAP Server property file for CP4BA"

        tip="## Property file for ${LDAP_TYPE} ##"

        echo "###########################" >> ${LDAP_PROPERTY_FILE}
        echo "$tip" >> ${LDAP_PROPERTY_FILE}
        echo "###########################" >> ${LDAP_PROPERTY_FILE}
        for i in "${!LDAP_COMMON_PROPERTY[@]}"; do
            printf '%b\n' "${COMMENTS_LDAP_PROPERTY[i]}" >> ${LDAP_PROPERTY_FILE}
            echo "${LDAP_COMMON_PROPERTY[i]}=\"\"" >> ${LDAP_PROPERTY_FILE}
            echo "" >> ${LDAP_PROPERTY_FILE}
        done
        if [[ $LDAP_TYPE == "AD" ]]; then
            ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"Microsoft Active Directory\"|g" ${LDAP_PROPERTY_FILE}
            for i in "${!AD_LDAP_PROPERTY[@]}"; do
                echo "${COMMENTS_AD_LDAP_PROPERTY[i]}" >> ${LDAP_PROPERTY_FILE}
                echo "${AD_LDAP_PROPERTY[i]}=\"\"" >> ${LDAP_PROPERTY_FILE}
                echo "" >> ${LDAP_PROPERTY_FILE}
            done
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"IBM Security Directory Server\"|g" ${LDAP_PROPERTY_FILE}
            for i in "${!TDS_LDAP_PROPERTY[@]}"; do
                echo "${COMMENTS_TDS_LDAP_PROPERTY[i]}" >> ${LDAP_PROPERTY_FILE}
                echo "${TDS_LDAP_PROPERTY[i]}=\"\"" >> ${LDAP_PROPERTY_FILE}
                echo "" >> ${LDAP_PROPERTY_FILE}
            done
        else
            ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"PingDirectory Server\"|g" ${LDAP_PROPERTY_FILE}
            for i in "${!PDS_LDAP_PROPERTY[@]}"; do
                echo "${COMMENTS_PDS_LDAP_PROPERTY[i]}" >> ${LDAP_PROPERTY_FILE}
                echo "${PDS_LDAP_PROPERTY[i]}=\"\"" >> ${LDAP_PROPERTY_FILE}
                echo "" >> ${LDAP_PROPERTY_FILE}
            done
        fi
        # Set default value
        ${SED_COMMAND} "s|LDAP_SSL_ENABLED=\"\"|LDAP_SSL_ENABLED=\"True\"|g" ${LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|LDAP_SSL_SECRET_NAME=\"\"|LDAP_SSL_SECRET_NAME=\"ibm-cp4ba-ldap-ssl-secret\"|g" ${LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|LDAP_SSL_CERT_FILE_FOLDER=\"\"|LDAP_SSL_CERT_FILE_FOLDER=\"${LDAP_SSL_CERT_FOLDER}\"|g" ${LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|<LDAP_SSL_CERT_FOLDER>|\"${LDAP_SSL_CERT_FOLDER}\"|g" ${LDAP_PROPERTY_FILE}
        if [[ $LDAP_TYPE == "AD" ]]; then
            ${SED_COMMAND} "s|LDAP_USER_NAME_ATTRIBUTE=\"\"|LDAP_USER_NAME_ATTRIBUTE=\"user:sAMAccountName\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_USER_DISPLAY_NAME_ATTR=\"\"|LDAP_USER_DISPLAY_NAME_ATTR=\"sAMAccountName\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_NAME_ATTRIBUTE=\"\"|LDAP_GROUP_NAME_ATTRIBUTE=\"*:cn\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_DISPLAY_NAME_ATTR=\"\"|LDAP_GROUP_DISPLAY_NAME_ATTR=\"cn\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"\"|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"(\&(cn=%v)(objectcategory=group))\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBER_ID_MAP=\"\"|LDAP_GROUP_MEMBER_ID_MAP=\"memberOf:member\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_USER_FILTER=\"\"|LC_USER_FILTER=\"(\&(sAMAccountName=%v)(objectcategory=user))\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_GROUP_FILTER=\"\"|LC_GROUP_FILTER=\"(\&(cn=%v)(objectcategory=group))\"|g" ${LDAP_PROPERTY_FILE}
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            ${SED_COMMAND} "s|LDAP_USER_NAME_ATTRIBUTE=\"\"|LDAP_USER_NAME_ATTRIBUTE=\"*:uid\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_USER_DISPLAY_NAME_ATTR=\"\"|LDAP_USER_DISPLAY_NAME_ATTR=\"cn\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_NAME_ATTRIBUTE=\"\"|LDAP_GROUP_NAME_ATTRIBUTE=\"*:cn\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_DISPLAY_NAME_ATTR=\"\"|LDAP_GROUP_DISPLAY_NAME_ATTR=\"cn\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"\"|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"(\|(\&(objectclass=groupofnames)(member={0}))(\&(objectclass=groupofuniquenames)(uniquemember={0})))\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBER_ID_MAP=\"\"|LDAP_GROUP_MEMBER_ID_MAP=\"groupofnames:member\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_USER_FILTER=\"\"|LC_USER_FILTER=\"(\&(cn=%v)(objectclass=person))\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_GROUP_FILTER=\"\"|LC_GROUP_FILTER=\"(\&(cn=%v)(\|(objectclass=groupofnames)(objectclass=groupofuniquenames)(objectclass=groupofurls)))\"|g" ${LDAP_PROPERTY_FILE}
        else
            ${SED_COMMAND} "s|LDAP_USER_NAME_ATTRIBUTE=\"\"|LDAP_USER_NAME_ATTRIBUTE=\"*:uid\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_USER_DISPLAY_NAME_ATTR=\"\"|LDAP_USER_DISPLAY_NAME_ATTR=\"uid\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_NAME_ATTRIBUTE=\"\"|LDAP_GROUP_NAME_ATTRIBUTE=\"*:cn\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_DISPLAY_NAME_ATTR=\"\"|LDAP_GROUP_DISPLAY_NAME_ATTR=\"cn\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"\"|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"(\&(cn=%v)(objectClass=groupOfUniqueNames))\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBER_ID_MAP=\"\"|LDAP_GROUP_MEMBER_ID_MAP=\"groupOfUniqueNames:uniquemember\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_USER_FILTER=\"\"|LC_USER_FILTER=\"(\&(uid=%v)(objectclass=person))\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_GROUP_FILTER=\"\"|LC_GROUP_FILTER=\"(\&(cn=%v)(\|(objectclass=groupOfUniqueNames)))\"|g" ${LDAP_PROPERTY_FILE}
        fi
        success "LDAP Server property file for CP4BA has been created.\n"
    fi
    # Create external LDAP property file
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        wait_msg "Creating external LDAP property file for CP4BA"
        mkdir -p $EXT_LDAP_SSL_CERT_FOLDER >/dev/null 2>&1
        > ${EXTERNAL_LDAP_PROPERTY_FILE}
        tip="## Property file for External LDAP ##"
        echo "#####################################" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
        echo "$tip" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
        echo "#####################################" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
        for i in "${!LDAP_COMMON_PROPERTY[@]}"; do
            echo "${COMMENTS_LDAP_PROPERTY[i]}" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
            echo "${LDAP_COMMON_PROPERTY[i]}=\"\"" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
            echo "" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
        done
        if [[ $LDAP_TYPE == "AD" ]]; then
            # ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"Microsoft Active Directory\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            for i in "${!AD_LDAP_PROPERTY[@]}"; do
                echo "${COMMENTS_AD_LDAP_PROPERTY[i]}" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "${AD_LDAP_PROPERTY[i]}=\"\"" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
            done
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            # ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"IBM Security Directory Server\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            for i in "${!TDS_LDAP_PROPERTY[@]}"; do
                echo "${COMMENTS_TDS_LDAP_PROPERTY[i]}" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "${TDS_LDAP_PROPERTY[i]}=\"\"" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
            done
        else
            # ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"PingDirectory Server\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            for i in "${!PDS_LDAP_PROPERTY[@]}"; do
                echo "${COMMENTS_PDS_LDAP_PROPERTY[i]}" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "${PDS_LDAP_PROPERTY[i]}=\"\"" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
            done
        fi
        # set default vaule
        ${SED_COMMAND} "s|LDAP_SSL_ENABLED=\"\"|LDAP_SSL_ENABLED=\"True\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|LDAP_SSL_SECRET_NAME=\"\"|LDAP_SSL_SECRET_NAME=\"ibm-cp4ba-ext-ldap-ssl-secret\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|LDAP_SSL_CERT_FILE_FOLDER=\"\"|LDAP_SSL_CERT_FILE_FOLDER=\"${EXT_LDAP_SSL_CERT_FOLDER}\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|<LDAP_SSL_CERT_FOLDER>|\"${EXT_LDAP_SSL_CERT_FOLDER}\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|ldap-cert.crt|\external-ldap-cert.crt|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        if [[ $LDAP_TYPE == "AD" ]]; then
            ${SED_COMMAND} "s|LDAP_USER_NAME_ATTRIBUTE=\"\"|LDAP_USER_NAME_ATTRIBUTE=\"user:sAMAccountName\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_USER_DISPLAY_NAME_ATTR=\"\"|LDAP_USER_DISPLAY_NAME_ATTR=\"sAMAccountName\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_NAME_ATTRIBUTE=\"\"|LDAP_GROUP_NAME_ATTRIBUTE=\"*:cn\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_DISPLAY_NAME_ATTR=\"\"|LDAP_GROUP_DISPLAY_NAME_ATTR=\"cn\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"\"|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"(\&(cn=%v)(objectcategory=group))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBER_ID_MAP=\"\"|LDAP_GROUP_MEMBER_ID_MAP=\"memberOf:member\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_USER_FILTER=\"\"|LC_USER_FILTER=\"(\&(sAMAccountName=%v)(objectcategory=user))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_GROUP_FILTER=\"\"|LC_GROUP_FILTER=\"(\&(cn=%v)(objectcategory=group))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            ${SED_COMMAND} "s|LDAP_USER_NAME_ATTRIBUTE=\"\"|LDAP_USER_NAME_ATTRIBUTE=\"*:uid\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_USER_DISPLAY_NAME_ATTR=\"\"|LDAP_USER_DISPLAY_NAME_ATTR=\"cn\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_NAME_ATTRIBUTE=\"\"|LDAP_GROUP_NAME_ATTRIBUTE=\"*:cn\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_DISPLAY_NAME_ATTR=\"\"|LDAP_GROUP_DISPLAY_NAME_ATTR=\"cn\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"\"|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"(\|(\&(objectclass=groupofnames)(member={0}))(\&(objectclass=groupofuniquenames)(uniquemember={0})))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBER_ID_MAP=\"\"|LDAP_GROUP_MEMBER_ID_MAP=\"groupofnames:member\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_USER_FILTER=\"\"|LC_USER_FILTER=\"(\&(cn=%v)(objectclass=person))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_GROUP_FILTER=\"\"|LC_GROUP_FILTER=\"(\&(cn=%v)(\|(objectclass=groupofnames)(objectclass=groupofuniquenames)(objectclass=groupofurls)))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        else
            ${SED_COMMAND} "s|LDAP_USER_NAME_ATTRIBUTE=\"\"|LDAP_USER_NAME_ATTRIBUTE=\"*:uid\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_USER_DISPLAY_NAME_ATTR=\"\"|LDAP_USER_DISPLAY_NAME_ATTR=\"uid\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_NAME_ATTRIBUTE=\"\"|LDAP_GROUP_NAME_ATTRIBUTE=\"*:cn\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_DISPLAY_NAME_ATTR=\"\"|LDAP_GROUP_DISPLAY_NAME_ATTR=\"cn\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"\"|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"(\&(cn=%v)(objectClass=groupOfUniqueNames))\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBER_ID_MAP=\"\"|LDAP_GROUP_MEMBER_ID_MAP=\"groupOfUniqueNames:uniquemember\"|g"  ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_USER_FILTER=\"\"|LC_USER_FILTER=\"(\&(uid=%v)(objectclass=person))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_GROUP_FILTER=\"\"|LC_GROUP_FILTER=\"(\&(cn=%v)(\|(objectclass=groupOfUniqueNames)))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        fi
        success "External LDAP property file for CP4BA has been created.\n"
    else
        rm -rf ${EXTERNAL_LDAP_PROPERTY_FILE} >/dev/null 2>&1
    fi
    # msgB "After done, press any key to next!"
    # read -rsn1 -p"Press any key to continue";echo
    > ${DB_NAME_USER_PROPERTY_FILE}
    if (( db_server_number > 0 )); then
    # create property file for database name and user
    INFO "Creating property file for database name and user required by CP4BA"
    # > ${DB_NAME_USER_PROPERTY_FILE}
        if (( db_server_number > 1 )); then
        tip="## NOTES: Please change the \"$DB_SERVER_PREFIX\" variable to assign each database to a database server or instance. ##\n"
        tip+="##        The \"$DB_SERVER_PREFIX\" must be in [${db_server_array[*]}] ##"
        echo "#################################################################################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        printf '%b\n' "$tip" >> "$DB_NAME_USER_PROPERTY_FILE"
        echo "################################################################################################################# " >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
    fi

    # if only one database server is input, set <DB_ALIAS_NAME> auto
    if [ ${#db_server_array[@]} -eq 1 ]; then
        DB_SERVER_PREFIX="${db_server_array[0]}"
    fi

    # Add global property into user_profile for CP4BA
    tip="##           USER Property for CP4BA               ##"
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    # license
    echo "## Use this parameter to specify the license for the CP4A deployment and" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## the possible values are: non-production and production and if not set, the license will" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## be defaulted to production.  This value could be different from the other licenses in the CR." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.CP4BA_LICENSE=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        echo "## The Content Cortex license and possible values are: user, concurrent-user, authorized-user, non-production, and production." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## This value could be different from the rest of the licenses." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.CONTENT_CORTEX_LICENSE=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi

    # CP4BA.BAW_LICENSE required for either workflow runtime or workflow authoring
    # For https://jsw.ibm.com/browse/DBACLD-161792
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
        echo "## Business Automation Workflow (BAW) license and possible values are: concurrent-user, authorized-user, non-production, and production." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## This value could be different from the other licenses in the CR." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.BAW_LICENSE=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi

    echo "## On OCP 3.x and 4.x, the User script will populate these three (3) parameters based on your input for \"production\" deployment." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## If you manually deploying without using the User script, then you would provide the different storage classes for the slow, medium" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## and fast storage parameters below.  If you only have 1 storage class defined, then you can use that 1 storage class for all 3 parameters." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## sc_block_storage_classname is for Zen, Zen requires/recommends block storage (RWO) for metastoreDB" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.SLOW_FILE_STORAGE_CLASSNAME=\"$SLOW_STORAGE_CLASS_NAME\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.MEDIUM_FILE_STORAGE_CLASSNAME=\"$MEDIUM_STORAGE_CLASS_NAME\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.FAST_FILE_STORAGE_CLASSNAME=\"$FAST_STORAGE_CLASS_NAME\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.BLOCK_STORAGE_CLASS_NAME=\"$BLOCK_STORAGE_CLASS_NAME\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## Enable/disable FIPS mode for the deployment (default value is \"false\")." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## Note: If set as \"true\", in order to complete enablement of FIPS for CP4BA, please refer to \"FIPS wall\" configuration in IBM documentation." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.ENABLE_FIPS=\"$FIPS_ENABLED\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## Enable or disable egress access to external systems." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## true: All CP4A pods will not have access any external systems unless custom, curated egress network policy or polices with specific 'matchLabels' are created. Please refer to documentation for more detail." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## false: All CP4A pods will have unrestricted network access to external systems." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.ENABLE_GENERATE_SAMPLE_NETWORK_POLICIES=\"$GENERATE_SAMPLE_NETWORK_POLICIES\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## Enable or disable Instana instrumentation for cp4ba deployment." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## Note: set as \"true\" for enabling the Instana monitoring for the deployment." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.ENABLE_INSTANA_MONITORING=\"$ENABLE_INSTANA_MONITORING\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    if [[ $EXTERNAL_POSTGRESDB_FOR_IM == "true" ]]; then
        mkdir -p $IM_DB_SSL_CERT_FOLDER >/dev/null 2>&1
        #Calling generateImZenBTSMessage function to show message related to IM external DB
        generateImZenBTSMessage "IM" $IM_DB_SSL_CERT_FOLDER

    fi


    if [[ $EXTERNAL_POSTGRESDB_FOR_ZEN == "true" ]]; then
        mkdir -p $ZEN_DB_SSL_CERT_FOLDER >/dev/null 2>&1
        #Calling generateImZenBTSMessage function to show message related to ZEN external DB
        generateImZenBTSMessage "ZEN" $ZEN_DB_SSL_CERT_FOLDER

    fi

    if [[ $EXTERNAL_POSTGRESDB_FOR_BTS == "true" ]]; then
        mkdir -p $BTS_DB_SSL_CERT_FOLDER >/dev/null 2>&1
        #Calling generateImZenBTSMessage function to show message related to BTS external DB
        generateImZenBTSMessage "BTS" $BTS_DB_SSL_CERT_FOLDER
    fi

    if [[ $EXTERNAL_CERT_OPENSEARCH_KAFKA == "true" ]]; then
        mkdir -p $CP4BA_TLS_ISSUER_CERT_FOLDER >/dev/null 2>&1
        echo "## Configuration for external certificate used by Opensearch/Kafka." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Please get \"<your-root-ca: tls.crt>\" \"<your-root-ca: tls.key>\" copy into this directory.Default value is \"$CP4BA_TLS_ISSUER_CERT_FOLDER\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.EXTERNAL_ROOT_CA_FOR_OPENSEARCH_KAFKA_FOLDER=\"$CP4BA_TLS_ISSUER_CERT_FOLDER\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi

    #DBACLD-185209: Update the property files to include Vault properties if VAULT_ENABLE=true
    add_vault_props

    # Create DBNAME/DBUSER property file for GCDDB
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        wait_msg "Creating Property file for IBM Content Cortex GCD Database"
        tip="## Property for Content Cortex's GCD Database Name and User on ${DB_TYPE} type database ##"
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}

        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide the name of the database for the GCD of P8Domain. For example: \"gcddb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.GCD_DB_NAME=\"gcddb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## Provide the name of the database for the GCD of P8Domain. For example: \"GCDDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.GCD_DB_NAME=\"GCDDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "db2"* ]]; then
                    echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "$DB_SERVER_PREFIX.GCD_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.GCD_DB_CURRENT_SCHEMA")
                # fi
            else
                echo "## The designated name of the database on the EDB Postgres for the GCD of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.GCD_DB_NAME=\"gcddb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                echo "## Provide the user name of the database for the GCD of P8Domain. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.GCD_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated user name of the database on the EDB Postgres for the GCD of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.GCD_DB_USER_NAME=\"gcduser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        else
            echo "## Provide the user name of the database for the GCD of P8Domain. For example: \"GCDDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.GCD_DB_USER_NAME=\"GCDDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi

        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) of the database user for the GCD of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
            #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
            if [[ $DB_TYPE == "postgresql" ]]; then
                displayPGClientAuthMessage
            fi
            echo "$DB_SERVER_PREFIX.GCD_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else #EDB
            #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
            echo "## The designated password of the database user for the GCD of P8Domain. " >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.GCD_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # Add property into user_profile for FNCM/ICCSAP/IER
        tip="##           USER Property for Content Cortex                ##"
        echo "###############################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "###############################################################" >> ${USER_PROFILE_PROPERTY_FILE}

        # appLoginUsername/appLoginPassword for FNCM
        echo "## Provide the user name for P8Domain. For example: \"CEAdmin\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT.APPLOGIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the user password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for P8Domain." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT.APPLOGIN_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        # ltpaPassword/keystorePassword for FNCM
        echo "## Provide a string for ltpaPassword in the ibm-fncm-secret that will be used when creating the ltpakey." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: CONTENT.LTPA_PASSWORD must match BAN.LTPA_PASSWORD)" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT.LTPA_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide a string for keystorePassword in the ibm-fncm-secret that will be used when creating the keystore." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: CONTENT.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled.)" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT.KEYSTORE_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        # If select ICCSAP, add keystorePassword
        if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
            echo "## Provide a string for keystorePassword in the ibm-iccsap-secret that will be used when creating the keystore." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: ICCSAP.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled.)" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ICCSAP.KEYSTORE_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        # If select ICC Archive, add ARCHIVE_USERID/ARCHIVE_PASSWORD
        if [[ " ${optional_component_cr_arr[@]} " =~ "css" ]]; then
            echo "## Provide ARCHIVE_USERID used in the ibm-icc-secret secret for the security details of the login credentials for the Content Platform Engine services. This login user ID must have domain-wide read access to all documents to be indexed." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## This login user ID must have domain-wide read access to all documents to be indexed." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CONTENT.ARCHIVE_USER_ID=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Provide ARCHIVE_PASSWORD used in the ibm-icc-secret secret (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text)." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CONTENT.ARCHIVE_USER_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi

        # if select IER
        if [[ " ${optional_component_cr_arr[@]} " =~ "ier" ]]; then
            echo "## Provide a string for keystorePassword in the ibm-ier-secret that will be used when creating the keystore." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: IER.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled.)" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "IER.KEYSTORE_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi

        # user profile for content initialization
        tip="##       USER Property for Content initialization   ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Enable/disable ECM (Content Cortex) / BAN initialization (e.g., creation of P8 domain, creation/configuration of object stores," >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## creation/configuration of CSS servers, and initialization of Navigator (ICN)." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## The default value is \"Yes\", set \"No\" to disable." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT_INITIALIZATION.ENABLE=\"Yes\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## user name for GCD administrator, for example, \"CEAdmin\". This parameter accepts comma-separated lists (without spacing), for example, \"CEAdmin1,CEAdmin2\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT_INITIALIZATION.LDAP_ADMIN_USER_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Names of groups containing GCD administrators, for example, \"P8Administrators\". This parameter accepts comma-separated lists (without spacing), for example, \"P8Group1,P8Group2\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT_INITIALIZATION.LDAP_ADMINS_GROUPS_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## user name and group name for object store admin, for example, \"CEAdmin\" or \"P8Administrators\". This parameter accepts comma-separated lists (without spacing), for example, \"P8Group1,P8Group2\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
            # property for oc_cpe_obj_store_enable_workflow
            echo "## Specify whether to enable workflow for the object store, the default vaule is \"Yes\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_ENABLE_WORKFLOW=\"Yes\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            # property for oc_cpe_obj_store_workflow_data_tbl_space
            echo "## Specify a table space for the workflow data." >> ${USER_PROFILE_PROPERTY_FILE}
            if [[ $DB_TYPE == "db2"* ]]; then
                echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE=\"VWDATA_TS\"" >> ${USER_PROFILE_PROPERTY_FILE}
            elif [[ $DB_TYPE == "sqlserver" ]]; then
                echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE=\"PRIMARY\"" >> ${USER_PROFILE_PROPERTY_FILE}
            elif [[ $DB_TYPE == "oracle" ]]; then
                echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE=\"BAWTOSDATATS\"" >> ${USER_PROFILE_PROPERTY_FILE}
            elif [[ $DB_TYPE == "postgresql" || $DB_TYPE == "postgresql-edb" ]]; then
                echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE=\"bawtos_tbs\"" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            # property for oc_cpe_obj_store_workflow_admin_group
            echo "## Designate an LDAP group for the workflow admin group." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_ADMIN_GROUP=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            # property for oc_cpe_obj_store_workflow_config_group
            echo "## Designate an LDAP group for the workflow config group" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_CONFIG_GROUP=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            # property for oc_cpe_obj_store_workflow_pe_conn_point_name
            echo "## Provide a name for the connection point. For example: \"pe_conn_os1"\" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        success "Property file for IBM Content Cortex GCD has been created.\n"

        # Create DBNAME/DBUSER property file for Object store
        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then

            # INFO "Creating Property file for IBM Content Cortex  Object Store"
            tip="## Property for Content Cortex's Object store Database Name and User on ${DB_TYPE} type database ##"

            echo "###################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "###################################################" >> ${DB_NAME_USER_PROPERTY_FILE}

            if (( content_os_number > 0 )); then
                for ((j=0;j<${content_os_number};j++))
                do
                    if [[ $DB_TYPE != "oracle" ]]; then
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then

                            if [[ $DB_TYPE == "postgresql" ]]; then
                                echo "## Provide the name of the database for the Object Store of P8Domain. For example: \"os$((j+1))db\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                                echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_NAME=\"os$((j+1))db\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            else
                                echo "## Provide the name of the database for the Object Store of P8Domain. For example: \"OS$((j+1))DB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                                echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_NAME=\"OS$((j+1))DB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi
                            # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                            if [[ $DB_TYPE == "db2"* ]]; then
                                echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.OS$((j+1))_DB_CURRENT_SCHEMA")
                            ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                            ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                            echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.OS$((j+1))_DB_INDEX_STORAGE_LOCATION")
                            echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.OS$((j+1))_DB_TABLE_STORAGE_LOCATION")
                            echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.OS$((j+1))_DB_LOB_STORAGE_LOCATION")
                            # fi
                            echo "## Provide the user name of the database for the Object Store of P8Domain. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        else
                            echo "## The designated name of the database on the EDB Postgres for the Object Store of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_NAME=\"os$((j+1))db\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "## The designated user name of the database for the Object Store of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                    else
                        ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                        ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                        echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.OS$((j+1))_DB_INDEX_STORAGE_LOCATION")
                        echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.OS$((j+1))_DB_TABLE_STORAGE_LOCATION")
                        echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.OS$((j+1))_DB_LOB_STORAGE_LOCATION")

                        echo "## Provide the user name of the database for the Object Store of P8Domain. For example: \"OS$((j+1))DB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_NAME=\"OS$((j+1))DB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) of the database user for the Object Store of P8Domain. " >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                        if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                            echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
                        #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            displayPGClientAuthMessage
                        fi
                        
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else #EDB
                        #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
                        echo "## The designated password of the database user for the Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}

                    fi
                    # If ADP selected, the oc_cpe_obj_store_enable_document_processing should set as true for OS required by ADP
                    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
                        echo "## If this is a object store for the ADP, set as \"True\" to initialize object store for the document processing code module creation." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_ENABLE_DOCUMENT_PROCESSING=\"False\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
                done
            fi

            # generate property for Object store required by BAW authoring or BAW Runtime or BAW+AWS
            if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || (" ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams")) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
                echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Property for BAW's Object Store Database Name and User on ${DB_TYPE} type database ##" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
                wait_msg "Creating Property file for IBM Content Cortex  Object Store required by BAW authoring or BAW Runtime"
                for i in "${!BAW_AUTH_OS_ARR[@]}"; do
                    if [[ $DB_TYPE != "oracle" ]]; then
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then

                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_sample_name=$(echo "${BAW_AUTH_OS_ARR[i]}" | tr '[:upper:]' '[:lower:]')
                                echo "## Provide the name of the database for the object store required by BAW authoring or BAW Runtime. For example: \"$tmp_db_sample_name\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                                echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_NAME=\"$tmp_db_sample_name\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            else
                                echo "## Provide the name of the database for the object store required by BAW authoring or BAW Runtime. For example: \"${BAW_AUTH_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                                echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_NAME=\"${BAW_AUTH_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi
                            # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                            if [[ $DB_TYPE == "db2"* ]]; then
                                echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${BAW_AUTH_OS_ARR[i]}_DB_CURRENT_SCHEMA")

                            ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                            ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                            echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${BAW_AUTH_OS_ARR[i]}_DB_INDEX_STORAGE_LOCATION")
                            echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${BAW_AUTH_OS_ARR[i]}_DB_TABLE_STORAGE_LOCATION")
                            echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${BAW_AUTH_OS_ARR[i]}_DB_LOB_STORAGE_LOCATION")
                            # fi
                            echo "## Provide the user name for the object store database required by BAW authoring or BAW Runtime. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        else
                            tmp_db_name=$(echo "${BAW_AUTH_OS_ARR[i]}" | tr '[:upper:]' '[:lower:]')
                            echo "## The designated name of the database on the EDB Postgres for the object store required by BAW authoring or BAW Runtime. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_NAME=\"$tmp_db_name\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "## The designated user name for the object store database required by BAW authoring or BAW Runtime. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                    else

                        ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                        ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                        echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${BAW_AUTH_OS_ARR[i]}_DB_INDEX_STORAGE_LOCATION")
                        echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${BAW_AUTH_OS_ARR[i]}_DB_TABLE_STORAGE_LOCATION")
                        echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${BAW_AUTH_OS_ARR[i]}_DB_LOB_STORAGE_LOCATION")

                        echo "## Provide the user name for the object store database required by BAW authoring or BAW Runtime. For example: \"${BAW_AUTH_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME=\"${BAW_AUTH_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                        if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                            echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
                        #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            displayPGClientAuthMessage
                        fi                        
                        echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else #EDB
                        #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
                        echo "## The designated password for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
                done
                # for case history
                if [[ $DB_TYPE != "oracle" ]]; then
                    echo "## Uncomment the parameters below when Case History Emitter is enabled by removing the \"#\" in front." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            echo "## Provide the name of the database for Case History when Case History Emitter is enabled. For example: \"chos\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "# $DB_SERVER_PREFIX.CHOS_DB_NAME=\"chos\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        else
                            echo "## Provide the name of the database for Case History when Case History Emitter is enabled. For example: \"CHOS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "# $DB_SERVER_PREFIX.CHOS_DB_NAME=\"CHOS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi

                        # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                        echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                        if [[ $DB_TYPE == "db2"* ]]; then
                            echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        echo "# $DB_SERVER_PREFIX.CHOS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.CHOS_DB_CURRENT_SCHEMA")
                        # fi
                        echo "## Provide the user name for the object store database required by Case History when Case History Emitter is enabled. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "# $DB_SERVER_PREFIX.CHOS_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        echo "## The designated name of the database on the EDB Postgres for Case History when Case History Emitter is enabled. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "# $DB_SERVER_PREFIX.CHOS_DB_NAME=\"chos\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "## The designated user name for the object store database required by Case History when Case History Emitter is enabled. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "# $DB_SERVER_PREFIX.CHOS_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                else
                    echo "## Provide the user name for the object store database required by Case History when Case History Emitter is enabled. For example: \"CHOS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "# $DB_SERVER_PREFIX.CHOS_DB_USER_NAME=\"CHOS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
                    #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        displayPGClientAuthMessage
                    fi                    
                    echo "# $DB_SERVER_PREFIX.CHOS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else #EDB
                    #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
                    echo "## The designated password for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "# $DB_SERVER_PREFIX.CHOS_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
                success "Property file for IBM Content Cortex  Object Store required by BAW authoring or BAW Runtime has been created.\n"
            fi

            # generate property for Object store required by AWS
            if [[ (" ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams")) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
                wait_msg "Creating Property file for IBM Content Cortex Object Store required by AWS"
                if [[ $DB_TYPE != "oracle" ]]; then
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then

                        if [[ $DB_TYPE == "postgresql" ]]; then
                            echo "## Provide the name of the database for the object store required by AWS. For example: \"awsdocs\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.AWSDOCS_DB_NAME=\"awsdocs\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        else
                            echo "## Provide the name of the database for the object store required by AWS. For example: \"AWSDOCS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.AWSDOCS_DB_NAME=\"AWSDOCS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                        echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                        if [[ $DB_TYPE == "db2"* ]]; then
                            echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWSDOCS_DB_CURRENT_SCHEMA")
                        ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                        ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                        echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWSDOCS_DB_INDEX_STORAGE_LOCATION")
                        echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWSDOCS_DB_TABLE_STORAGE_LOCATION")
                        echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWSDOCS_DB_LOB_STORAGE_LOCATION")

                        # fi
                        echo "## Provide the user name for the object store database required by AWS. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        echo "## The designated name of the database on the EDB Postgres for the object store required by AWS. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_NAME=\"awsdocs\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "## The designated user name for the object store database required by AWS. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                else
                    ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                    ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                    echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWSDOCS_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWSDOCS_DB_INDEX_STORAGE_LOCATION")
                    echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWSDOCS_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWSDOCS_DB_TABLE_STORAGE_LOCATION")
                    echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWSDOCS_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWSDOCS_DB_LOB_STORAGE_LOCATION")

                    echo "## Provide the user name for the object store database required by AWS. For example: \"AWSDOCS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWSDOCS_DB_USER_NAME=\"AWSDOCS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                        echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
                    #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        displayPGClientAuthMessage
                    fi                    
                    echo "$DB_SERVER_PREFIX.AWSDOCS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else #EDB
                    #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
                    echo "## The designated password for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWSDOCS_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
                success "Property file for IBM Content Cortex Object Store required by AWS has been created.\n"
            fi

            # generate property for Object store required by ADP
            if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
                wait_msg "Creating Property file for IBM Content Cortex Object Store required by ADP"

                if [[ $DB_TYPE != "oracle" ]]; then
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            echo "## Provide the name of the database for the object store required by ADP. For example: \"devos1\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.DEVOS_DB_NAME=\"devos1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        else
                            echo "## Provide the name of the database for the object store required by ADP. For example: \"DEVOS1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.DEVOS_DB_NAME=\"DEVOS1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi

                        # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                        echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                        if [[ $DB_TYPE == "db2"*  ]]; then
                            echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.DEVOS_DB_CURRENT_SCHEMA")
                        ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                        ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                        echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.DEVOS_DB_INDEX_STORAGE_LOCATION")
                        echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.DEVOS_DB_TABLE_STORAGE_LOCATION")
                        echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.DEVOS_DB_LOB_STORAGE_LOCATION")

                        # fi
                        echo "## Provide the user name for the object store database required by ADP. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        echo "## The designated name of the database on the EDB Postgres for the object store required by ADP. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_NAME=\"devos1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "## The designated user name for the object store database required by ADP. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                else
                    ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                    ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                    echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.DEVOS_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.DEVOS_DB_INDEX_STORAGE_LOCATION")
                    echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.DEVOS_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.DEVOS_DB_TABLE_STORAGE_LOCATION")
                    echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.DEVOS_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.DEVOS_DB_LOB_STORAGE_LOCATION")

                    echo "## Provide the user name for the object store database required by ADP. For example: \"DEVOS1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.DEVOS_DB_USER_NAME=\"DEVOS1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                        echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
                    #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        displayPGClientAuthMessage
                    fi
                    echo "$DB_SERVER_PREFIX.DEVOS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else #EDB
                    #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
                    echo "## The designated password for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.DEVOS_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
                success "Property file for IBM Content Cortex Object Store required by ADP has been created.\n"
            fi

            # generate property for AE Data Persistent
            if [[ " ${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
                for i in "${!AEOS[@]}"; do
                    wait_msg "Creating Property file for IBM Content Cortex Object Store required by AE Data Persistent"
                    if [[ $DB_TYPE != "oracle" ]]; then
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_sample_name=$(echo "${AEOS[i]}" | tr '[:upper:]' '[:lower:]')
                                echo "## Provide the name of the database for the object store required by AE Data Persistent. For example: \"$tmp_db_sample_name\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                                echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_NAME=\"$tmp_db_sample_name\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            else
                                echo "## Provide the name of the database for the object store required by AE Data Persistent. For example: \"${AEOS[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                                echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_NAME=\"${AEOS[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi

                            # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                            if [[ $DB_TYPE == "db2"* ]]; then
                                echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${AEOS[i]}_DB_CURRENT_SCHEMA")
                            ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                            ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                            echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${AEOS[i]}_DB_INDEX_STORAGE_LOCATION")
                            echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${AEOS[i]}_DB_TABLE_STORAGE_LOCATION")
                            echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${AEOS[i]}_DB_LOB_STORAGE_LOCATION")

                            # fi
                            echo "## Provide the user name of the database for the object store required by AE Data Persistent. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        else
                            echo "## The designated name of the database on the EDB Postgres for the object store required by AE Data Persistent. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_NAME=\"aeos\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "## The designated user name of the database for the object store required by AE Data Persistent. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                    else
                        ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                        ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                        echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${AEOS[i]}_DB_INDEX_STORAGE_LOCATION")
                        echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${AEOS[i]}_DB_TABLE_STORAGE_LOCATION")
                        echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.${AEOS[i]}_DB_LOB_STORAGE_LOCATION")

                        echo "## Provide the user name of the database for the object store required by AE Data Persistent. For example: \"${AEOS[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_USER_NAME=\"${AEOS[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Object Store of P8Domain. " >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                        if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                            echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
                        #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            displayPGClientAuthMessage
                        fi
                        echo "$DB_SERVER_PREFIX.AEOS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else #EDB
                        #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
                        echo "## The designated password for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AEOS_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    success "Property file for IBM Content Cortex Object Store required by AE Data Persistent has been created.\n"
                done
            fi
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
            # INFO "Created Property file for IBM Content Cortex  Object Store"
        fi
    fi

    # Create DBNAME/DBUSER property file for ICNDB
    # echo "pattern_cr_arr: ${pattern_cr_arr[*]}"
    # echo "length of pattern_cr_arr:${#pattern_cr_arr[@]}"
    # echo "pattern list in CR: ${pattern_joined}"
    # echo "debug"; sleep 3000
    if [[ " ${foundation_component_arr[@]}" =~ "BAN" ]]; then
        if [[ ! (" ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "1") ]]; then
            wait_msg "Creating Property file for IBM Business Automation Navigator"

            tip="## Property for BAN's ICN Database Name and User on ${DB_TYPE} type database ##"

            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE != "oracle" ]]; then
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        echo "## Provide the name of the database for ICN (Navigator). For example: \"icndb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.ICN_DB_NAME=\"icndb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        echo "## Provide the name of the database for ICN (Navigator). For example: \"ICNDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.ICN_DB_NAME=\"ICNDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi

                    # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"* ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.ICN_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.ICN_DB_CURRENT_SCHEMA")
                    # fi
                else
                    echo "## The designated name of the database on the EDB Postgres for ICN (Navigator). (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.ICN_DB_NAME=\"icndb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
            fi
            if [[ $DB_TYPE != "oracle" ]]; then
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    echo "## Provide the user name of the database for ICN (Navigator). For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.ICN_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## The designated user name of the database for ICN (Navigator). (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.ICN_DB_USER_NAME=\"icnuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
            else
                echo "## Provide the user name of the database for ICN (Navigator). For example: \"ICNDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.ICN_DB_USER_NAME=\"ICNDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) of the database user for ICN (Navigator). " >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                    echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
                #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
                if [[ $DB_TYPE == "postgresql" ]]; then
                    displayPGClientAuthMessage
                fi
                echo "$DB_SERVER_PREFIX.ICN_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else #EDB
                #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
                echo "## The designated password of the database user for ICN (Navigator)." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.ICN_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

            # user profile for content initialization
            tip="##       USER Property for BAN   ##"
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            # appLoginUsername/appLoginPassword for BAN
            echo "## Provide the user name for the Navigator administrator. For example: \"BANAdmin\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.APPLOGIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Provide the user password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the Navigator administrator." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.APPLOGIN_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            # ltpaPassword/keystorePassword for BAN
            echo "## Provide a string for ltpaPassword in the ibm-ban-secret that will be used when creating the ltpakey." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text.(NOTES: BAN.LTPA_PASSWORD must match CONTENT.LTPA_PASSWORD)" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.LTPA_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Provide a string for keystorePassword in the ibm-ban-secret that will be used when creating the keystore." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: BAN.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled.)" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.KEYSTORE_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            # jMailUsername/jMailPassword for BAN
            echo "## Provide the user name for jMail used by BAN. For example: \"jMailAdmin\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.JMAIL_USER_NAME=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("BAN.JMAIL_USER_NAME")
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Provide the user password for jMail used by BAN." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.JMAIL_USER_PASSWORD=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("BAN.JMAIL_USER_PASSWORD")
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            success "Property file for IBM Business Automation Navigator has been created.\n"
        fi
    fi

    # Create DBNAME/DBUSER property file for ODM
    containsElement "decisions" "${pattern_cr_arr[@]}"
    odm_Val=$?
    if [[ $odm_Val -eq 0 ]]; then
        wait_msg "Creating Property file for IBM Operational Decision Manager"

        tip="## Property for  ODM's an external database Name and User on ${DB_TYPE} type database ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide the name of the database for ODM. For example: \"odmdb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.ODM_DB_NAME=\"odmdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## Provide the name of the database for ODM. For example: \"ODMDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.ODM_DB_NAME=\"ODMDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi

                # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                #     echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                #     if [[ $DB_TYPE == "db2"  ]]; then
                #         echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                #     fi
                #     echo "$DB_SERVER_PREFIX.ODM_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                #     OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.ODM_DB_CURRENT_SCHEMA")
                # fi
            else
                echo "## The designated name of the database on the EDB Postgres for ODM. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.ODM_DB_NAME=\"odmdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                echo "## Provide the user name of the database for ODM. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.ODM_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated user name of the database for ODM. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.ODM_DB_USER_NAME=\"odmuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        else
            echo "## Provide the user name of the database for ODM. For example: \"ODMDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ODM_DB_USER_NAME=\"ODMDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) of the database user for ODM. " >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
            #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
            if [[ $DB_TYPE == "postgresql" ]]; then
                displayPGClientAuthMessage
            fi
            echo "$DB_SERVER_PREFIX.ODM_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else #EDB
            #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
            echo "## The designated password of the database user for ODM." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ODM_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        
        # user property section for ODM which for now has just a keystorePassword field
        # DBACLD-239524: Moved this code to helper function "add_odm_props" so we can call it in multiple scenarios
        # No longer needed as we will be auto generating the keystore password -> https://jsw.ibm.com/browse/DBACLD-238578?focusedId=30084545&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-30084545
        #add_odm_props
    fi

    ### -- https://jsw.ibm.com/browse/DBACLD-153348 - <Migration from Mongo to Postgres-edb for ADP>
    # generate property for ADP
    if [[ "${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        wait_msg "Creating Property file for IBM Automation Document Processing"
        # Resolve the ADP secret name from the live CR; fall back to the default name.
        _adp_secret_name=$(echo "$cr_output" | ${YQ_CMD} '.spec.document_processing.ibm_adp_secret' - 2>/dev/null | sed -e 's/^"//' -e 's/"$//')
        if [[ -z "$_adp_secret_name" || "$_adp_secret_name" == "null" ]]; then
            _adp_secret_name="ibm-adp-secret"
        fi
        tip="## Property for Document Processing Engine (DPE) databases on ${DB_TYPE} type database ##"
        # DBACLD-244556: Emit ADP section header unconditionally so ADP properties are always
        # placed under their own section, separate from ODM's section.
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        #Generating property file (cp4ba_db_name_user.property) for ADP Gitgateway databases
        if [[ $DB_TYPE == "postgresql-edb" && "${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
                note="## If you select the ${DB_TYPE} type database then the operator will deploy the Postgres EDB instance, so you won't need to provide DB service/server details and create a database ##"
                echo "$note" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated database name for Automation Document Processing." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.ADP_GG_DB_NAME=\"adpggdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name of the database for Automation Document Processing." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.ADP_GG_DB_USER_NAME=\"adpuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password for the user of Automation Document Processing." >> ${DB_NAME_USER_PROPERTY_FILE}
                # When enabling Vault on an existing deployment (no prop files), read the live password
                # from the existing ADP secret (name resolved from CR, defaulting to ibm-adp-secret).
                if [[ "$ENABLE_VAULT_ON_EXIST" == "true" && "$ENABLE_VAULT_ON_EXIST_PROP_TYPE" == "none" ]]; then
                    _existing_adpgg_pwd=$($CLI_CMD get secret "$_adp_secret_name" -n "$CP4BA_SERVICES_NS" -o jsonpath='{.data.adpggDBPassword}' 2>/dev/null | base64 --decode 2>/dev/null)
                    if [[ -n "$_existing_adpgg_pwd" ]]; then
                        echo "$DB_SERVER_PREFIX.ADP_GG_DB_USER_PASSWORD=\"$_existing_adpgg_pwd\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        warning "Could not retrieve adpggDBPassword from secret $_adp_secret_name; you must manually set ${DB_SERVER_PREFIX}.ADP_GG_DB_USER_PASSWORD in the property file to match the existing database password (found in the 'adpggDBPassword' key of secret $_adp_secret_name) before running generate mode."
                        echo "$DB_SERVER_PREFIX.ADP_GG_DB_USER_PASSWORD=\"<Required>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                else
                    echo "$DB_SERVER_PREFIX.ADP_GG_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi

        ### -- https://jsw.ibm.com/browse/DBACLD-154816 - <Migration from Mongo to Postgres-edb for ADP>
        #Generating property file (cp4ba_db_name_user.property) for ADP Gitgateway databases
        if [[ $DB_TYPE == "db2"* && "${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
                # Use external PostgreSQL server prefix if external PostgreSQL is enabled for ADPGG/DICMS
                if [[ "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" ]]; then
                    ADP_DB_SERVER_PREFIX="$EXTERNAL_POSTGRES_SERVER_PREFIX"
                else
                    ADP_DB_SERVER_PREFIX="$DB_SERVER_PREFIX"
                fi
                
                if [[ "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" ]]; then
                    note="## NOTE: \"${EXTERNAL_POSTGRES_SERVER_PREFIX}\" identifies your external PostgreSQL server for the ADPGG database. All other CP4BA databases use your ${DB_TYPE} server alias \"${DB_SERVER_PREFIX}\". You will need to create this PostgreSQL database using the auto-generated DB scripts before applying the CP4BA Custom Resource. ##"
                else
                    note="## If you select the ${DB_TYPE} type database then the operator will deploy the Postgres EDB instance, so you won't need to provide DB service/server details and create a database ##"
                fi
                echo "$note" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated database name for Automation Document Processing. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$ADP_DB_SERVER_PREFIX.ADP_GG_DB_NAME=\"adpggdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" ]]; then
                    echo "## The designated user name of the database for Automation Document Processing." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$ADP_DB_SERVER_PREFIX.ADP_GG_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "## The designated schema name for the ADP Git Gateway database. This parameter is optional. If not set, the database user name will be used." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$ADP_DB_SERVER_PREFIX.ADP_GG_DB_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "## The designated password for the user of Automation Document Processing. (Provide the password in plain text or Base64 encoded with {Base64} prefix if it contains special characters.)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$ADP_DB_SERVER_PREFIX.ADP_GG_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## The designated user name of the database for Automation Document Processing. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$ADP_DB_SERVER_PREFIX.ADP_GG_DB_USER_NAME=\"adpuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}

                    echo "## The designated password for the user of Automation Document Processing." >> ${DB_NAME_USER_PROPERTY_FILE}
                    # When enabling Vault on an existing deployment (no prop files), read the live password
                    # from the existing ADP secret (name resolved from CR, defaulting to ibm-adp-secret).
                    if [[ "$ENABLE_VAULT_ON_EXIST" == "true" && "$ENABLE_VAULT_ON_EXIST_PROP_TYPE" == "none" ]]; then
                        _existing_adpgg_pwd=$($CLI_CMD get secret "$_adp_secret_name" -n "$CP4BA_SERVICES_NS" -o jsonpath='{.data.adpggDBPassword}' 2>/dev/null | base64 --decode 2>/dev/null)
                        if [[ -n "$_existing_adpgg_pwd" ]]; then
                            echo "$ADP_DB_SERVER_PREFIX.ADP_GG_DB_USER_PASSWORD=\"$_existing_adpgg_pwd\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        else
                            warning "Could not retrieve adpggDBPassword from secret $_adp_secret_name; you must manually set ${ADP_DB_SERVER_PREFIX}.ADP_GG_DB_USER_PASSWORD in the property file to match the existing database password (found in the 'adpggDBPassword' key of secret $_adp_secret_name) before running generate mode."
                            echo "$ADP_DB_SERVER_PREFIX.ADP_GG_DB_USER_PASSWORD=\"<Required>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                    else
                        echo "$ADP_DB_SERVER_PREFIX.ADP_GG_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                fi
                echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi

        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            echo "## Provide the database name for Document Processing Engine Base database. (For DB2, name must be 8 chars or less, no special chars.) For example: \"adpbase\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_NAME=\"adpbase\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            # ADP database scripts do not use the ADP_BASE_DB_CURRENT_SCHEMA property.  The schema used is the base DB user's default schema in the base DB
            # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
            #     echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
            #     if [[ $DB_TYPE == "db2"  ]]; then
            #         echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            #     fi
            #     echo "$DB_SERVER_PREFIX.ADP_BASE_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            #     OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.ADP_BASE_DB_CURRENT_SCHEMA")
            # fi
            echo "## Provide the user name for the Document Processing Engine Base database. Must be an existing user. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the Document Processing Engine Base database. " >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
            #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
            if [[ $DB_TYPE == "postgresql" ]]; then
                displayPGClientAuthMessage
            fi    
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else #EDB
            echo "## The designated database name on the EDB Postgres for Document Processing Engine Base database." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_NAME=\"adpbase\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated user name for the Document Processing Engine Base database. Must be an existing user." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_USER_NAME=\"acauser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated password for the Document Processing Engine Base database. " >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        if [[ "${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                echo "## Important: The keys below for Document Processing Engine Project databases support comma-separated lists. The number of values should match in each comma-separated list." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the database names for the Document Processing Engine Project databases. (For DB2, name must be 8 chars or less, no special chars.) You need two databases per document processing project. Example: \"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_NAME=\"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the database server(s) for the Document Processing Engine Project databases.  Must match the value of \"DB_SERVER_LIST\" defined in cp4ba_db_server.property. Example: \"DBSERVER1,DBSERVER2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_SERVER=\"$DB_SERVER_PREFIX,$DB_SERVER_PREFIX\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the user names for the Document Processing Engine Project databases.  Must be existing users. Example: \"dbuser1,dbuser2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_NAME=\"<youruser1>,<youruser2>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the passwords (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the Document Processing Engine Project databases. Example: \"mypwd1,mypwd2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                    echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
                #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
                if [[ $DB_TYPE == "postgresql" ]]; then
                    displayPGClientAuthMessage
                fi
                echo "ADP_PROJECT_DB_USER_PASSWORD=\"{Base64}<yourpassword1>,{Base64}<yourpassword2>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the ontology name for each Document Processing Engine Project database. (Must be 8 characters or less, no special chars.) Example: \"ont1,ont1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## You can leave the default values for property below. The name of ontology can be same for all the databases." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_ONTOLOGY=\"ont1,ont1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else #EDB
                echo "## Important: The keys below for Document Processing Engine Project databases support comma-separated lists. The number of values should match in each comma-separated list." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated database names on the EDB Postgres for the Document Processing Engine Project databases. You need two databases per document processing project. Example: \"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_NAME=\"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated database server(s) for the Document Processing Engine Project databases.  Must match the value of \"DB_SERVER_LIST\" defined in cp4ba_db_server.property. Example: \"DBSERVER1,DBSERVER2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_SERVER=\"$DB_SERVER_PREFIX,$DB_SERVER_PREFIX\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user names for the Document Processing Engine Project databases. Example: \"dbuser1,dbuser2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Note: When using postgresql-edb as database type, ADP_PROJECT_DB_USER_NAME will be same as ADP_PROJECT_DB_NAME" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_NAME=\"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated passwords for the Document Processing Engine Project databases. Example: \"mypwd1,mypwd2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD,$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        elif [[ "${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                echo "## Important: The keys below for Document Processing Engine Project databases support comma-separated lists. The number of values should match in each comma-separated list." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the database name(s) for the Document Processing Engine Project database(s). You need one database per document processing project. This key supports comma-separated lists, example: \"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_NAME=\"proj1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the database server(s) for the Document Processing Engine Project databases.  Must match the value of \"DB_SERVER_LIST\" defined in cp4ba_db_server.property. Example: \"DBSERVER1,DBSERVER2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_SERVER=\"$DB_SERVER_PREFIX\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the user name(s) for the Document Processing Engine Project database(s). For example: \"dbuser1,dbuser2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the password(s) (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the Document Processing Engine Project database(s). For example: \"password1,password2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                    echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
                #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
                if [[ $DB_TYPE == "postgresql" ]]; then
                    displayPGClientAuthMessage
                fi
                echo "ADP_PROJECT_DB_USER_PASSWORD=\"{Base64}<yourpassword1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the ontology name for each Document Processing Engine Project database. (Must be 8 characters or less, no special chars.) Example: \"ont1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## You can leave the default values for property below. The name of ontology can be same for all the databases." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_ONTOLOGY=\"ont1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else #EDB
                echo "## Important: The keys below for Document Processing Engine Project databases support comma-separated lists. The number of values should match in each comma-separated list." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated database name(s) on the EDB Postgres for the Document Processing Engine Project database(s). You need one database per document processing project. This key supports comma-separated lists, example: \"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_NAME=\"proj1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated database server(s) for the Document Processing Engine Project databases.  Must match the value of \"DB_SERVER_LIST\" defined in cp4ba_db_server.property. Example: \"DBSERVER1,DBSERVER2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_SERVER=\"$DB_SERVER_PREFIX\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name(s) for the Document Processing Engine Project database(s). For example: \"dbuser1,dbuser2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_NAME=\"acauser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password(s) for the Document Processing Engine Project database(s). For example: \"password1,password2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        if [[ "$DB_TYPE" == "postgresql" && " ${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            wait_msg "Creating Property file for Automation Document Processing Git Gateway"

            tip="## Property for ADP Git Gateway Database Name and User on ${DB_TYPE} type database ##"

            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the name of the database for DICMS. For example: \"adpggdb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_GG_DB_NAME=\"adpggdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the ADP Git Gateway schema name. This parameter is optional. If not set, the database user name will be used." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_GG_DB_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the user name of the database for the ADP Git Gateway of P8Domain. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_GG_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) of the database user for the DICMS of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            # If FIPS chosen make sure the requirements are met
            if [[ $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
            #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
            if [[ $DB_TYPE == "postgresql" ]]; then
                displayPGClientAuthMessage
            fi
            echo "$DB_SERVER_PREFIX.ADP_GG_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi

        # user profile for ADP
        tip="##       USER Property for ADP   ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}

        # serviceUser/servicePwd for ADP
	    echo "## Fully Qualified Distinguished Name (FQDN) for the user is required for this setting." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the service user name for ADP. For example: \"CN=sampleServiceUser,DC=sampleDC,DC=com\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the service user password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for ADP." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        
        # serviceUserBas/servicePwdBas for ADP
	echo "## Fully Qualified Distinguished Name (FQDN) for the user is required for this setting." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the service base name for ADP. For example: \"CN=sampleBaseUser,DC=sampleDC,DC=com\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_NAME_BASE=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the service base password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for ADP." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_PASSWORD_BASE=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        # serviceUserCa/servicePwdCa for ADP
	echo "## Fully Qualified Distinguished Name (FQDN) for the user is required for this setting." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the service ca name for ADP. For example: \"CN=sampleCAUser,DC=sampleDC,DC=com\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_NAME_CA=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the service ca password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for ADP." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_PASSWORD_CA=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        # envOwnerUser/envOwnerPwd for ADP
	echo "## Fully Qualified Distinguished Name (FQDN) for the user is required for this setting." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the environment owner name for ADP. For example: \"CN=sampleOwnerUser,DC=sampleDC,DC=com\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.ENV_OWNER_USER_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the environment owner password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for ADP." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.ENV_OWNER_USER_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
            # Add user property into user_profile for ADP when ADP Runtime Environment
            # The repository service url
            echo "## The repository service url." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## For a runtime environment update this value to point to your" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## development cdra environment URL (not service endpoint)." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## https://<Authoring Environment's CPD (Zen) Route>/adp/cdra/cdapi. This value for CPDS_REPO_SERVICE_URL will set the REPO_SERVICE_URL: \"<Required>\" value in the generated CR. " >> ${USER_PROFILE_PROPERTY_FILE}
            
            echo "ADP.REPO_SERVICE_URL=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## In $CP4BA_RELEASE_BASE, the feedback feature is enhanced to support 'distributed' for the 'runtime_type' parameter. The 'distributed' runtime type is only supported in the Runtime environment."  >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## For more information, from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE, navigate to Document Processing --> Creating a document processing project --> Using feedback documents from applications to improve training" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Default is true." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.RUNTIME_FEEDBACK_ENABLED=\"true\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Default is \"sandbox\".  Allowed values are \"sandbox\" and \"distributed\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.RUNTIME_FEEDBACK_RUNTIME_TYPE=\"sandbox\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## The secret name that contains the design API key. This is required if runtime_feedback.enabled is true and runtime_type is 'distributed', (Default is 'aca-design-api-key')." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.RUNTIME_FEEDBACK_DESIGN_API_SECRET=\"aca-design-api-key\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## The name of API. This is required if runtime_feedback.enabled is true and runtime_type is 'distributed'." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.RUNTIME_FEEDBACK_DESIGN_API_USER=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("ADP.RUNTIME_FEEDBACK_DESIGN_API_USER")
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## The content of ZenAPIKey. This is required if runtime_feedback.enabled is true and runtime_type is 'distributed'." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.RUNTIME_FEEDBACK_DESIGN_ZEN_API_KEY=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("ADP.RUNTIME_FEEDBACK_DESIGN_ZEN_API_KEY")
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## The secret name that contains the TLS certificate and key for the design API. This is required if runtime_feedback.enabled is true and runtime_type is 'distributed' (Default is 'adp-cdra-tls-secret' the same secret used for CDRA_SSL_SECRET_NAME)." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.RUNTIME_FEEDBACK_DESIGN_TLS_SECRET=\"adp-cdra-tls-secret\"" >> ${USER_PROFILE_PROPERTY_FILE}
        fi

        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            mkdir -p $ADP_GIT_SSL_CERT_FOLDER >/dev/null 2>&1
            # git connection ssl for ADP
            echo "## Configure a secure connection to the required Git server. " >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.ENABLE_GIT_SSL_CONNECTION=\"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## If enabled secure connection for Git server, you need copy the SSL certificate file (named git-cert.crt) into this directory. Default value is \"${ADP_GIT_SSL_CERT_FOLDER}\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.GIT_SSL_CERT_FILE_FOLDER=\"$ADP_GIT_SSL_CERT_FOLDER\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## The name of the secret that Git SSL certificate." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.GIT_SSL_SECRET_NAME=\"adp-git-tls-secret\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi


        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
            mkdir -p $ADP_CDRA_CERT_FOLDER >/dev/null 2>&1
            # CDRA-route for ADP
            echo "## Get the root CA that is used to sign your development environment CDRA route and save it to a certificate (name cdra_tls_cert.crt) under this directory. Default value is \"${ADP_CDRA_CERT_FOLDER}\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.CDRA_SSL_CERT_FILE_FOLDER=\"$ADP_CDRA_CERT_FOLDER\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## The name of the secret that CDRA route certificate." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.CDRA_SSL_SECRET_NAME=\"adp-cdra-tls-secret\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi

        success "Property file for IBM Automation Document Processing has been created.\n"
    fi

    # generate property for Application Engine Database
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "application" ]]; then
        wait_msg "Creating Property file for Application Engine"

        tip="## Property for Application Engine database required on ${DB_TYPE} type database ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then

                if [[ $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide the database name for runtime application engine. For example: \"aaedb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_NAME=\"aaedb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## Provide the database name for runtime application engine. For example: \"AAEDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_NAME=\"AAEDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE == "db2"*|| $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"* ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.APP_ENGINE_DB_CURRENT_SCHEMA")
                fi
            else
                echo "## The designated database name on the EDB Postgres for runtime application engine. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_NAME=\"aaedb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                echo "## Provide the user name of the database for the Application Engine database. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated user name of the database for the Application Engine database. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_USER_NAME=\"aeuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        else
            echo "## Provide the user name of the database for the Application Engine database. For example: \"AAEDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_USER_NAME=\"AAEDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Application Engine database. " >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            #DBACLD-203586: Update property file to state the password field should be blank when DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER are both set to "TRUE"
            #NOTE: We cannot call the is_pg_client_auth function yet b/c we generate the property files first.
            if [[ $DB_TYPE == "postgresql" ]]; then
                displayPGClientAuthMessage
            fi
            echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else #EDB
            #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
            echo "## The designated password for the user of Application Engine database." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # Add user property into user_profile for Application Engine
        tip="##           USER Property for AE                 ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        # AE Admin
        echo "## Designate an existing LDAP user for the Application Engine admin user." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## This user ID should be in the IBM Business Automation Navigator administrator role, as specified as appLoginUsername in the Navigator secret. " >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Required only when User Management Service (UMS) is configured: This user should also belong to UMS Teams admin group or the UMS Teams Administrators team."  >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If not, follow the instructions in \"Completing post-deployment tasks for Business Automation Studio and Application Engine\" in the IBM Documentation to add it to the Navigator Administrator role and UMS team server admin group." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_ENGINE.ADMIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        # Enable redis HA session for AE
        mkdir -p $AE_REDIS_SSL_CERT_FOLDER >/dev/null 2>&1
        echo "## If you want better HA experience. Set the session.use_external_store to true, fill in your redis server information" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## The default value is \"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_ENGINE.SESSION_REDIS_USE_EXTERNAL_STORE=\"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Your external redis host/ip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_ENGINE.SESSION_REDIS_HOST=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("APP_ENGINE.SESSION_REDIS_HOST")
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Your external redis port" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_ENGINE.SESSION_REDIS_PORT=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("APP_ENGINE.SESSION_REDIS_PORT")
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If your redis enabled TLS connection set this to true, You should add redis server CA certificate in tls_trust_list or trusted_certificate_list" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## The default value is \"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_ENGINE.SESSION_REDIS_TLS_ENABLED=\"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## If enabled Redis SSL, you need copy the SSL certificate file (named redis.pem) into this directory. Default value is \"${AE_REDIS_SSL_CERT_FOLDER}\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_ENGINE.SESSION_REDIS_SSL_CERT_FILE_FOLDER=\"${AE_REDIS_SSL_CERT_FOLDER}\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## The name of the secret that contains the Redis SSL certificate." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_ENGINE.SESSION_REDIS_SSL_SECRET_NAME=\"ibm-dba-ae-redis-cacert\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If you are using Redis V6 and above with username fill in this field. Otherwise leave this field as empty" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## The default value is empty \"\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_ENGINE.SESSION_REDIS_USERNAME=\"\"" >> ${USER_PROFILE_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("APP_ENGINE.SESSION_REDIS_USERNAME")
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        success "Property file for Application Engine has been created.\n"
    fi

    # generate property for BAW runtime
    if [[ ( (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams") && " ${pattern_cr_arr[@]}" =~ "workflow-runtime" ) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
        wait_msg "Creating Property file for IBM Business Automation Workflow Runtime"

        tip="## Property for Business Automation Workflow Runtime's database on ${DB_TYPE} ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}

        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide the database name for Business Automation Workflow Runtime. For example: \"bawdb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_NAME=\"bawdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    displayPGClientAuthMessage
                else
                    echo "## Provide the database name for Business Automation Workflow Runtime. For example: \"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_NAME=\"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE == "db2"* || $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"*  ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.BAW_RUNTIME_DB_CURRENT_SCHEMA")
                    ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                    ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                    echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.BAW_RUNTIME_DB_INDEX_STORAGE_LOCATION")
                    echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.BAW_RUNTIME_DB_TABLE_STORAGE_LOCATION")
                    echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.BAW_RUNTIME_DB_LOB_STORAGE_LOCATION")
                fi
                echo "## Provide the user name of the database for Business Automation Workflow Runtime. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of database for Business Automation Workflow Runtime ." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                    echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else #EDB
                echo "## The designated database name on the EDB Postgres for Business Automation Workflow Runtime." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_NAME=\"bawdb0\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name of the database for Business Automation Workflow Runtime." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_NAME=\"bawuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password for the user of database for Business Automation Workflow Runtime." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            # To support customize database schema for postgresql and db2
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            #     echo "## Provide the schema name that is used to qualify unqualified database objects in dynamically prepared SQL statements when" >> ${DB_NAME_USER_PROPERTY_FILE}
            #     echo "## the schema name is different from the user name of the database for Business Automation Workflow." >> ${DB_NAME_USER_PROPERTY_FILE}
            #     echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            #     OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.BAW_RUNTIME_DB_CURRENT_SCHEMA")
            # fi
        else
            ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
            ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
            echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.BAW_RUNTIME_DB_INDEX_STORAGE_LOCATION")
            echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.BAW_RUNTIME_DB_TABLE_STORAGE_LOCATION")
            echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.BAW_RUNTIME_DB_LOB_STORAGE_LOCATION")

            echo "## Provide the database name for Business Automation Workflow Runtime. For example: \"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_NAME=\"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of database required by Business Automation Workflow Runtime." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # Add user property into user_profile for BAW runtime
        tip="##           USER Property for Workflow Runtime        ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        # BAW runtime profile
        echo "## Designate an existing LDAP user for the Workflow Server admin user." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "BAW_RUNTIME.ADMIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        success "Property file for IBM Business Automation Workflow Runtime has been created.\n"
    fi

    # generate property for Workflow Assistants
    if [[ "${optional_component_cr_arr[@]}" =~ "workflow_assistant" || "${optional_component_cr_arr[@]}" =~ "workplace_assistant" ]]; then
        # Add user property into user_profile for Workflow Assistant
        # WFA_WATSONX_DEPLOYMENT_TYPE was already set interactively in input_information()
        wait_msg "Creating Property file for Workflow Assistant ($WFA_WATSONX_DEPLOYMENT_TYPE deployment)"

        tip="##           USER Property for Workflow Assistant        ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ "$WFA_WATSONX_DEPLOYMENT_TYPE" == "SaaS" ]]; then
            echo "## Properties for SaaS Deployment (IBM Cloud)" >> ${USER_PROFILE_PROPERTY_FILE}
            
            echo "## IBM Cloud API Key for WatsonX.ai SaaS" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "WFA.WATSONX_API_KEY=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## WatsonX.ai SaaS service endpoint URL" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Example: https://us-south.ml.cloud.ibm.com" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "WFA.WATSONX_URL=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## WatsonX.ai Project ID" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "WFA.WATSONX_PROJECT_ID=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        else
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Properties for LWE Deployment (Lightweight Engine)" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            
            echo "## WatsonX.ai LWE cluster URL" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Example: https://cpd-cluster.company.com" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "WFA.WATSONX_URL=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## WatsonX.ai LWE username" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "WFA.WATSONX_USERNAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## WatsonX.ai LWE password" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "WFA.WATSONX_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## WatsonX.ai LWE version" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Example: 5.0.0" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "WFA.WATSONX_VERSION=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi

        echo "## Flag to run the Workplace Assistant" >> ${USER_PROFILE_PROPERTY_FILE}
        if [[ "${optional_component_cr_arr[@]}" =~ "workplace_assistant" ]]; then
          echo "WFA.RUN_WORKPLACE_AGENT=\"true\"" >> ${USER_PROFILE_PROPERTY_FILE}
        else
          echo "WFA.RUN_WORKPLACE_AGENT=\"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Flag to run the (Preview) Authoring Assistant" >> ${USER_PROFILE_PROPERTY_FILE}
        if [[ "${optional_component_cr_arr[@]}" =~ "workflow_assistant" ]]; then
          echo "WFA.RUN_AUTHORING_AGENT=\"true\"" >> ${USER_PROFILE_PROPERTY_FILE}
        else
          echo "WFA.RUN_AUTHORING_AGENT=\"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Optional - The ID of the LLM model to use. Default set to meta-llama/llama-3-3-70b-instruct." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "WFA.WATSONX_MODEL_ID=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        # Generate appropriate deployment ID parameters based on deployment type
        if [[ "${pattern_cr_arr[@]}" =~ "workflow-authoring" || ("${pattern_cr_arr[@]}" =~ "workflow-process-service" && "${optional_component_cr_arr[@]}" =~ "wfps_authoring") ]]; then
            # For Authoring environment (BAW or WFPS), include both Authoring and Runtime parameters
            echo "## Optional - Only required if a custom deployment LLM model is being used for Authoring Agent." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "WFA.AUTHORING_AGENT_WATSONX_DEPLOYMENT_ID=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Optional - Only required if a custom deployment LLM model is being used for Runtime Agent." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "WFA.RUNTIME_AGENT_WATSONX_DEPLOYMENT_ID=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        elif [[ "${pattern_cr_arr[@]}" =~ "workflow-runtime" ]]; then
            # For Runtime environment, include only Runtime parameter
            echo "## Optional - Only required if a custom deployment LLM model is being used for Runtime Agent." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "WFA.RUNTIME_AGENT_WATSONX_DEPLOYMENT_ID=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi

        success "Property file for Workflow Assistant ($WFA_WATSONX_DEPLOYMENT_TYPE deployment) has been created.\n"
    fi

    # generate property for AWS
    if [[ ( (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams") && " ${pattern_cr_arr[@]}" =~ "workstreams" ) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
        wait_msg "Creating Property file for IBM Automation Workstream Services"

        tip="## Property for Automation Workstream Services's database on ${DB_TYPE} ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}

        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then

                if [[ $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide the database name for database required by Automation Workstream Services. For example: \"awsdb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWS_DB_NAME=\"awsdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## Provide the database name for database required by Automation Workstream Services. For example: \"AWSDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWS_DB_NAME=\"AWSDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE == "db2"* || $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"* ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.AWS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWS_DB_CURRENT_SCHEMA")
                    ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
                    ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
                    echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWS_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWS_DB_INDEX_STORAGE_LOCATION")
                    echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWS_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWS_DB_TABLE_STORAGE_LOCATION")
                    echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWS_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWS_DB_LOB_STORAGE_LOCATION")
                fi
                echo "## Provide the user name of the database for Automation Workstream Services. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.AWS_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of database required by Automation Workstream Services." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                    echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE == "postgresql" ]]; then
                    displayPGClientAuthMessage
                fi
                echo "$DB_SERVER_PREFIX.AWS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else #EDB
                echo "## The designated database name for database on the EDB Postgres required by Automation Workstream Services." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.AWS_DB_NAME=\"awsdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name of the database for Automation Workstream Services." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.AWS_DB_USER_NAME=\"awsuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password for the user of database required by Automation Workstream Services." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.AWS_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            # To support customize database schema for postgresql and db2
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            #     echo "## Provide the schema name that is used to qualify unqualified database objects in dynamically prepared SQL statements when" >> ${DB_NAME_USER_PROPERTY_FILE}
            #     echo "## the schema name is different from the user name of the database for Automation Workstream Services." >> ${DB_NAME_USER_PROPERTY_FILE}
            #     echo "$DB_SERVER_PREFIX.AWS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            #     OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWS_DB_CURRENT_SCHEMA")
            # fi
        else
            ## These new properties are being added to support creating the object stores with index, table and/or LOB storage location.
            ## This also mimics to what the user whould see when creating the object store from the ACCE object store wizard.
            echo "## Provide database index storage location. This parameter is optional. If not set, the database index storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.AWS_DB_INDEX_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWS_DB_INDEX_STORAGE_LOCATION")
            echo "## Provide database table storage location. This parameter is optional. If not set, the database table storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.AWS_DB_TABLE_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWS_DB_TABLE_STORAGE_LOCATION")
            echo "## Provide database LOB storage location. This parameter is optional. If not set, the database LOB storage location will not be set when creating the object store." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.AWS_DB_LOB_STORAGE_LOCATION=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.AWS_DB_LOB_STORAGE_LOCATION")

            echo "## Provide the database name for Automation Workstream Services. For example: \"AWSDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.AWS_DB_USER_NAME=\"AWSDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of database required by Automation Workstream Services." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.AWS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # Add user property into user_profile for AWS
        tip="##           USER Property for Automation Workstream Services        ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        # AWS profile
        echo "## Designate an existing LDAP user for the Workstreams Server admin user." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "AWS.ADMIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        success "Property file for IBM Automation Workstream Services has been created.\n"
    fi


    # generate property for Application Engine Playback database
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
        wait_msg "Creating Property file for Application Playback Server"

        tip="## Property for Application Engine Playback database on ${DB_TYPE} type database ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide the database name for Application Engine Playback database. For example: \"appdb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_NAME=\"appdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## Provide the database name for Application Engine Playback database. For example: \"APPDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_NAME=\"APPDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi

                if [[ $DB_TYPE == "db2"* || $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"* ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.APP_PLAYBACK_DB_CURRENT_SCHEMA")
                fi
                echo "## Provide the user name of the database for Application Engine Playback database. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated database name on the EDB Postgres for Application Engine Playback database. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_NAME=\"appdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name of the database for Application Engine Playback database. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_USER_NAME=\"appuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        else
            echo "## Provide the user name of the database for Application Engine Playback database. For example: \"APPDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_USER_NAME=\"APPDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Application Engine Playback database. " >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            if [[ $DB_TYPE == "postgresql" ]]; then
                displayPGClientAuthMessage
            fi
            echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else #EDB
            #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
            echo "## The designated password for the user of Application Engine Playback database." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # Add user property into user_profile for playback server
        tip="##       USER Property for App Engine Playback Server         ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        # playback user profile
        echo "## Designate an existing LDAP user for the Playback Application Engine admin user." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## This user ID should be in the IBM Business Automation Navigator administrator role, as specified as appLoginUsername in the Navigator secret."  >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_PLAYBACK.ADMIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        mkdir -p $PLAYBACK_REDIS_SSL_CERT_FOLDER >/dev/null 2>&1
        # Enable redis HA session for playback server
        echo "## If you want better HA experience. Set the session.use_external_store to true, fill in your redis server information" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## The default value is \"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_PLAYBACK.SESSION_REDIS_USE_EXTERNAL_STORE=\"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Your external redis host/ip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_PLAYBACK.SESSION_REDIS_HOST=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("APP_PLAYBACK.SESSION_REDIS_HOST")
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Your external redis port" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_PLAYBACK.SESSION_REDIS_PORT=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("APP_PLAYBACK.SESSION_REDIS_PORT")
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If your redis enabled TLS connection set this to true, You should add redis server CA certificate in tls_trust_list or trusted_certificate_list" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## The default value is \"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_PLAYBACK.SESSION_REDIS_TLS_ENABLED=\"false\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If enabled Redis SSL, you need copy the SSL certificate file (named redis.pem) into this directory. Default value is \"${PLAYBACK_REDIS_SSL_CERT_FOLDER}\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_PLAYBACK.SESSION_REDIS_SSL_CERT_FILE_FOLDER=\"${PLAYBACK_REDIS_SSL_CERT_FOLDER}\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## The name of the secret that contains the Redis SSL certificate." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_PLAYBACK.SESSION_REDIS_SSL_SECRET_NAME=\"ibm-dba-playback-redis-cacert\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## If you are using Redis V6 and above with username fill in this field. Otherwise leave this field as empty" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## The default value is empty \"\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_PLAYBACK.SESSION_REDIS_USERNAME=\"\"" >> ${USER_PROFILE_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("APP_PLAYBACK.SESSION_REDIS_USERNAME")
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        success "Property file for Application Playback Server has been created.\n"
    fi

### -- https://jsw.ibm.com/browse/DBACLD-153348 - <Migration from Mongo to Postgres-edb for DICMS>
# generate property for Decision Intelligence Client Managed Software (DICMS) database
if [[ "${pattern_cr_arr[@]}" =~ "decisions_ads" && "$DB_TYPE" = "postgresql-edb" ]]; then
    wait_msg "Creating Property file for Decision Intelligence Client Managed Software"
    # Resolve DICMS secret names from the live CR; fall back to the operator-created defaults.
    _dicms_designer_secret_name=$(echo "$cr_output" | ${YQ_CMD} '.spec.datasource_configuration.dc_ads_designer_datasource.database_instance_secret' - 2>/dev/null | sed -e 's/^"//' -e 's/"$//')
    if [[ -z "$_dicms_designer_secret_name" || "$_dicms_designer_secret_name" == "null" ]]; then
        _dicms_designer_secret_name="icp4adeploy-ads-designer-postgres-secret"
    fi
    _dicms_runtime_secret_name=$(echo "$cr_output" | ${YQ_CMD} '.spec.datasource_configuration.dc_ads_runtime_datasource.database_instance_secret' - 2>/dev/null | sed -e 's/^"//' -e 's/"$//')
    if [[ -z "$_dicms_runtime_secret_name" || "$_dicms_runtime_secret_name" == "null" ]]; then
        _dicms_runtime_secret_name="icp4adeploy-ads-runtime-postgres-secret"
    fi
    # Generating property file (cp4ba_db_name_user.property) when Decision Designer as optional component for DICMS
    if [[ "${optional_component_arr[@]}" =~ "DecisionDesigner" ]]; then
            tip="## Property for Decision Intelligence Client Managed Software(DICMS) with Decision Designer as optional component ##"
            note="## If you select the ${DB_TYPE} type database then the operator will deploy the Postgres EDB instance, so you won't need to provide DB service/server details and create a database ##"
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$note" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated database name on the Decision Intelligence Client Managed Software(DICMS) with Decision Designer as optional component." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.DICMS_DESIGNER_DB_NAME=\"adsdesignerdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated user name of the database for Decision Intelligence Client Managed Software(DICMS)." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_NAME=\"adsdesigner\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated password for the user of Decision Intelligence Client Managed Software(DICMS)." >> ${DB_NAME_USER_PROPERTY_FILE}
            # When enabling Vault on an existing deployment (no prop files), read the live password
            # from the existing DICMS Designer secret so the property file matches the running deployment.
            if [[ "$ENABLE_VAULT_ON_EXIST" == "true" && "$ENABLE_VAULT_ON_EXIST_PROP_TYPE" == "none" ]]; then
                _existing_dicms_designer_pwd=$($CLI_CMD get secret "$_dicms_designer_secret_name" -n "$CP4BA_SERVICES_NS" -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode 2>/dev/null)
                if [[ -n "$_existing_dicms_designer_pwd" ]]; then
                    echo "$DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_PASSWORD=\"$_existing_dicms_designer_pwd\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    warning "Could not retrieve password from secret $_dicms_designer_secret_name; you must manually set ${DB_SERVER_PREFIX}.DICMS_DESIGNER_DB_USER_PASSWORD in the property file to match the existing database password (found in the 'password' key of secret $_dicms_designer_secret_name) before running generate mode."
                    echo "$DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_PASSWORD=\"<Required>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
            else
                echo "$DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
    fi

    if [[ "${optional_component_arr[@]}" =~ "DecisionRuntime" ]]; then
            tip="## Property for Decision Intelligence Client Managed Software(DICMS) with Decision Runtime as optional component ##"
            note="## If you select the ${DB_TYPE} type database then the operator will deploy the Postgres EDB instance, so you won't need to provide DB service/server details and create a database ##"
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$note" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated database name on the Decision Intelligence Client Managed Software(DICMS) with Decision Runtime as optional component." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.DICMS_RUNTIME_DB_NAME=\"adsruntimedb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated user name of the database for Decision Intelligence Client Managed Software(DICMS)." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_NAME=\"adsruntime\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated password for the user of Decision Intelligence Client Managed Software(DICMS)." >> ${DB_NAME_USER_PROPERTY_FILE}
            # When enabling Vault on an existing deployment (no prop files), read the live password
            # from the existing DICMS Runtime secret so the property file matches the running deployment.
            if [[ "$ENABLE_VAULT_ON_EXIST" == "true" && "$ENABLE_VAULT_ON_EXIST_PROP_TYPE" == "none" ]]; then
                _existing_dicms_runtime_pwd=$($CLI_CMD get secret "$_dicms_runtime_secret_name" -n "$CP4BA_SERVICES_NS" -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode 2>/dev/null)
                if [[ -n "$_existing_dicms_runtime_pwd" ]]; then
                    echo "$DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_PASSWORD=\"$_existing_dicms_runtime_pwd\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    warning "Could not retrieve password from secret $_dicms_runtime_secret_name; you must manually set ${DB_SERVER_PREFIX}.DICMS_RUNTIME_DB_USER_PASSWORD in the property file to match the existing database password (found in the 'password' key of secret $_dicms_runtime_secret_name) before running generate mode."
                    echo "$DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_PASSWORD=\"<Required>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
            else
                echo "$DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
    fi
    success "Property file for Decision Intelligence Client Managed Software has been created\n"
fi

    # generate property for BAS
    if [[ "${pattern_cr_arr[@]}" =~ "document_processing_designer" || "${pattern_cr_arr[@]}" =~ "workflow-authoring" || ( "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $EXTERNAL_DB_WFPS_AUTHORING == "Yes") || "${optional_component_cr_arr[@]}" =~ "app_designer" || "${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
        wait_msg "Creating Property file for IBM Business Automation Studio"

        tip="## Property for Business Automation Studio's Studio database required on ${DB_TYPE} type database ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}

        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide the database name for Business Automation Studio database. For example: \"basdb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.STUDIO_DB_NAME=\"basdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## Provide the database name for Business Automation Studio database. For example: \"BASDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.STUDIO_DB_NAME=\"BASDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE == "db2"* || $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"*  ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.STUDIO_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.STUDIO_DB_CURRENT_SCHEMA")
                fi
                echo "## Provide the user name of the database for the Business Automation Studio database. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.STUDIO_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated database name on the EDB Postgres for Business Automation Studio database . (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.STUDIO_DB_NAME=\"basdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name of the database for the Business Automation Studio database. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.STUDIO_DB_USER_NAME=\"basuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        else
            echo "## Provide the user name of the database for the Business Automation Studio database. For example: \"BASDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.STUDIO_DB_USER_NAME=\"BASDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Business Automation Studio database." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            if [[ $DB_TYPE == "postgresql" ]]; then
                displayPGClientAuthMessage
            fi
            echo "$DB_SERVER_PREFIX.STUDIO_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else #EDB
            #DBACLD-194917: Generate random password for GCD_DB_USER_PASSWORD when it's EDB enabled
            echo "## The designated password for the user of Business Automation Studio database." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.STUDIO_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

    fi

    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || "${pattern_cr_arr[@]}" =~ "workflow-authoring" || "${pattern_cr_arr[@]}" =~ "workflow-process-service" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then

        if [[ $LDAP_WFPS_AUTHORING == "no" ]]; then
            #echo "BASTUDIO.ADMIN_USER=\"\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo
        else
            # Add user property into user_profile for BAS
            tip="##           USER Property for BAS                ##"
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            # BAS user profile
            echo "## Designate an existing LDAP user for the BAStudio admin user." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BASTUDIO.ADMIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        success "Property file for IBM Business Automation Studio has been created.\n"
    fi


    # DICMS is chosen as a component and need to use external postgres
    if [[ " ${pattern_cr_arr[@]} " =~ " decisions_ads " && "$DB_TYPE" == "postgresql" ]]; then
        wait_msg "Creating Property file for Decision Intelligence Client Managed Software"
        # Create sql scripts based on the chosen optional components
        if [[ " ${optional_component_cr_arr[@]} " =~ " ads_designer " ]]; then
            tip="## DICMS's Property for DICMS DESIGNER Database Name and User on ${DB_TYPE} type database ##"
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the name of the database for DICMS. For example: \"adsdesignerdb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.DICMS_DESIGNER_DB_NAME=\"adsdesignerdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the DICMS DESIGNER schema name. Default is "ads". Provide a custom name if needed." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.DICMS_DESIGNER_DB_CURRENT_SCHEMA=\"ads\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the user name of the database for the DICMS DESIGNER. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) of the database user for the DICMS." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            # If FIPS chosen make sure the requirements are met
            if [[ $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            if [[ $DB_TYPE == "postgresql" ]]; then
                displayPGClientAuthMessage
            fi
            echo "$DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi

        if [[ " ${optional_component_cr_arr[@]} " =~ " ads_runtime " ]]; then
            tip="## DICMS's Property for DICMS RUNTIME Database Name and User on ${DB_TYPE} type database ##"
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the name of the database for DICMS. For example: \"adsruntimedb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.DICMS_RUNTIME_DB_NAME=\"adsruntimedb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the DICMS RUNTIME schema name. Default is "ads". Provide a custom name if needed." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.DICMS_RUNTIME_DB_CURRENT_SCHEMA=\"ads\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the user name of the database for the DICMS RUNTIME. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) of the database user for the DICMS." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            if [[ $DB_TYPE == "postgresql" ]]; then
                displayPGClientAuthMessage
            fi
            echo "$DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi       
    fi

### -- https://jsw.ibm.com/browse/DBACLD-154816 - <Migration from Mongo to Postgres-edb for DICMS>
# generate property for Decision Intelligence Client Managed Software (DICMS) database if the database is db2/Oracle/MSSQL
if [[ "${pattern_cr_arr[@]}" =~ "decisions_ads" && "$DB_TYPE" != "postgresql-edb" ]]; then
    wait_msg "Creating Property file for Decision Intelligence Client Managed Software"
    # Resolve DICMS secret names from the live CR; fall back to the operator-created defaults.
    _dicms_designer_secret_name=$(echo "$cr_output" | ${YQ_CMD} '.spec.datasource_configuration.dc_ads_designer_datasource.database_instance_secret' - 2>/dev/null | sed -e 's/^"//' -e 's/"$//')
    if [[ -z "$_dicms_designer_secret_name" || "$_dicms_designer_secret_name" == "null" ]]; then
        _dicms_designer_secret_name="icp4adeploy-ads-designer-postgres-secret"
    fi
    _dicms_runtime_secret_name=$(echo "$cr_output" | ${YQ_CMD} '.spec.datasource_configuration.dc_ads_runtime_datasource.database_instance_secret' - 2>/dev/null | sed -e 's/^"//' -e 's/"$//')
    if [[ -z "$_dicms_runtime_secret_name" || "$_dicms_runtime_secret_name" == "null" ]]; then
        _dicms_runtime_secret_name="icp4adeploy-ads-runtime-postgres-secret"
    fi
    
    # Use external PostgreSQL server prefix if external PostgreSQL is enabled for ADPGG/DICMS
    if [[ "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" ]]; then
        DICMS_DB_SERVER_PREFIX="$EXTERNAL_POSTGRES_SERVER_PREFIX"
    else
        DICMS_DB_SERVER_PREFIX="$DB_SERVER_PREFIX"
    fi
    
    # Generating property file (cp4ba_db_name_user.property) when Decision Designer as optional component for DICMS
    if [[ "${optional_component_arr[@]}" =~ "DecisionDesigner" ]]; then
        if [[ $DB_TYPE == "db2"* || $DB_TYPE == "oracle" || $DB_TYPE == "sqlserver" ]]; then
            if [[ "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" ]]; then
                tip="## Property for Decision Intelligence Client Managed Software(DICMS) with Decision Designer as optional component - using external PostgreSQL for ADPGG/DICMS ##"
                note="## NOTE: \"${EXTERNAL_POSTGRES_SERVER_PREFIX}\" identifies your external PostgreSQL server for the DICMS Designer database. All other CP4BA databases use your ${DB_TYPE} server alias \"${DB_SERVER_PREFIX}\". You will need to create this PostgreSQL database using the auto-generated DB scripts before applying the CP4BA Custom Resource. ##"
            else
                tip="## Property for Decision Intelligence Client Managed Software(DICMS) with Decision Designer as optional component ##"
                note="## If you select the ${DB_TYPE} type database then the operator will deploy the Postgres EDB instance, so you won't need to provide DB service/server details and create a database ##"
            fi
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$note" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated database name on the Decision Intelligence Client Managed Software(DICMS) with Decision Designer as optional component." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DICMS_DB_SERVER_PREFIX.DICMS_DESIGNER_DB_NAME=\"adsdesignerdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" ]]; then
                echo "## The designated user name of the database for Decision Intelligence Client Managed Software(DICMS)." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DICMS_DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password for the user of Decision Intelligence Client Managed Software(DICMS). (Provide the password in plain text or Base64 encoded with {Base64} prefix if it contains special characters.)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DICMS_DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated schema name for the DICMS Designer database. Default value is \"adsdesigner\". You can change this to match your external PostgreSQL schema." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DICMS_DB_SERVER_PREFIX.DICMS_DESIGNER_DB_CURRENT_SCHEMA=\"adsdesigner\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated user name of the database for Decision Intelligence Client Managed Software(DICMS)." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DICMS_DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_NAME=\"adsdesigner\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password for the user of Decision Intelligence Client Managed Software(DICMS)." >> ${DB_NAME_USER_PROPERTY_FILE}
                # When enabling Vault on an existing deployment (no prop files), read the live password
                # from the existing DICMS Designer secret so the property file matches the running deployment.
                if [[ "$ENABLE_VAULT_ON_EXIST" == "true" && "$ENABLE_VAULT_ON_EXIST_PROP_TYPE" == "none" ]]; then
                    _existing_dicms_designer_pwd=$($CLI_CMD get secret "$_dicms_designer_secret_name" -n "$CP4BA_SERVICES_NS" -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode 2>/dev/null)
                    if [[ -n "$_existing_dicms_designer_pwd" ]]; then
                        echo "$DICMS_DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_PASSWORD=\"$_existing_dicms_designer_pwd\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        warning "Could not retrieve password from secret $_dicms_designer_secret_name; you must manually set ${DICMS_DB_SERVER_PREFIX}.DICMS_DESIGNER_DB_USER_PASSWORD in the property file to match the existing database password (found in the 'password' key of secret $_dicms_designer_secret_name) before running generate mode."
                        echo "$DICMS_DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_PASSWORD=\"<Required>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                else
                    echo "$DICMS_DB_SERVER_PREFIX.DICMS_DESIGNER_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
            fi
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
    fi

    if [[ "${optional_component_arr[@]}" =~ "DecisionRuntime" ]]; then
        if [[ $DB_TYPE = "db2"* || $DB_TYPE = "oracle" || $DB_TYPE = "sqlserver" ]]; then
            if [[ "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" ]]; then
                tip="## Property for Decision Intelligence Client Managed Software(DICMS) with Decision Runtime as optional component - using external PostgreSQL for ADPGG/DICMS ##"
                note="## NOTE: \"${EXTERNAL_POSTGRES_SERVER_PREFIX}\" identifies your external PostgreSQL server for the DICMS Runtime database. All other CP4BA databases use your ${DB_TYPE} server alias \"${DB_SERVER_PREFIX}\". You will need to create this PostgreSQL database using the auto-generated DB scripts before applying the CP4BA Custom Resource. ##"
            else
                tip="## Property for Decision Intelligence Client Managed Software(DICMS) with Decision Runtime as optional component ##"
                note="## If you select the ${DB_TYPE} type database then the operator will deploy the Postgres EDB instance, so you won't need to provide DB service/server details and create a database ##"
            fi
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$tip" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$note" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated database name on the Decision Intelligence Client Managed Software(DICMS) with Decision Runtime as optional component." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DICMS_DB_SERVER_PREFIX.DICMS_RUNTIME_DB_NAME=\"adsruntimedb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" ]]; then
                echo "## The designated user name of the database for Decision Intelligence Client Managed Software(DICMS)." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DICMS_DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password for the user of Decision Intelligence Client Managed Software(DICMS). (Provide the password in plain text or Base64 encoded with {Base64} prefix if it contains special characters.)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DICMS_DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated schema name for the DICMS Runtime database. Default value is \"adsruntime\". You can change this to match your external PostgreSQL schema." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DICMS_DB_SERVER_PREFIX.DICMS_RUNTIME_DB_CURRENT_SCHEMA=\"adsruntime\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated user name of the database for Decision Intelligence Client Managed Software(DICMS)." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DICMS_DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_NAME=\"adsruntime\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password for the user of Decision Intelligence Client Managed Software(DICMS)." >> ${DB_NAME_USER_PROPERTY_FILE}
                # When enabling Vault on an existing deployment (no prop files), read the live password
                # from the existing DICMS Runtime secret so the property file matches the running deployment.
                if [[ "$ENABLE_VAULT_ON_EXIST" == "true" && "$ENABLE_VAULT_ON_EXIST_PROP_TYPE" == "none" ]]; then
                    _existing_dicms_runtime_pwd=$($CLI_CMD get secret "$_dicms_runtime_secret_name" -n "$CP4BA_SERVICES_NS" -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode 2>/dev/null)
                    if [[ -n "$_existing_dicms_runtime_pwd" ]]; then
                        echo "$DICMS_DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_PASSWORD=\"$_existing_dicms_runtime_pwd\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        warning "Could not retrieve password from secret $_dicms_runtime_secret_name; you must manually set ${DICMS_DB_SERVER_PREFIX}.DICMS_RUNTIME_DB_USER_PASSWORD in the property file to match the existing database password (found in the 'password' key of secret $_dicms_runtime_secret_name) before running generate mode."
                        echo "$DICMS_DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_PASSWORD=\"<Required>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                else
                    echo "$DICMS_DB_SERVER_PREFIX.DICMS_RUNTIME_DB_USER_PASSWORD=\"$RANDOM_EDB_PASSWORD\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
            fi
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
    fi
    success "Property file for Decision Intelligence Client Managed Software has been created\n"
fi

    # DICMS is chosen as a component and whatever database is used, if vault mode is enabled we need more user properties
    # DBACLD-239112: This code was originally in this script, but is now moved to function "add_dicms_props_for_vault" so it can be reused in diff situations
    add_dicms_props_for_vault

    # Create USER_PROFILE_PROPERTY for IM SCIM attribute mappings for SDS/MSAD/PDS
    # Skip entirely for External IDP — SCIM attributes are LDAP-specific
    set_scim_attr="true"
    if [[ "${set_scim_attr}" == "true" && "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then
        ## <https://jsw.ibm.com/browse/DBACLD-158645> -  Added checks when workflow-process-service, wfps_authoring selected and LDAP_WFPS_AUTHORING == "Yes".
        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" || (" ${pattern_cr_arr[@]}" =~ "workflow-process-service" && "${optional_component_cr_arr[@]}" =~ "wfps_authoring" && $LDAP_WFPS_AUTHORING == "yes") ]]; then
            if [[ $LDAP_TYPE == "AD" ]]; then
                LDAP_NAME="Microsoft Active Directory"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                LDAP_NAME="IBM Security Directory Server"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                LDAP_NAME="PingDirectory Server"
            fi

            # user profile SCMI User section
            tip="##       USER Property for the customized IAM SCIM LDAP attributes for the LDAP ($LDAP_NAME) configuration       ##"
            echo "###########################################################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "###########################################################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## [NOTES:]" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## For information about SCIM parameters used by the CP4BA deployment, from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE, navigate to Reference --> CP4BA multi-pattern deployment reference --> Custom resource configuration parameters --> Shared configuration parameters --> LDAP Configuration" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## For information about LDAP attributes, you can use the ldapsearch tool or other LDAP browser utilitise." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## How to use ldapsearch tool to get LDAP attributes, you can refer below link: " >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## https://www.ibm.com/docs/en/cloud-paks/foundational-services/$CS_CHANNEL_KC?topic=users-updating-scim-ldap-attributes-mapping#about_ldap_attributes." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="sAMAccountName"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="ibm-entryuuid"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="entryUUID"
            fi

            echo "## Provide the user unique id attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## This attribute MUST be set to an LDAP attribute that is unique and immutable." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_UNIQUE_ID_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="sAMAccountName"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="uid"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="uid"
            fi
            
            echo "## Provide the user name attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_NAME_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user principal name attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_PRINCIPAL_NAME_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}


            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="displayName"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="cn"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="cn"
            fi
            echo "## Provide the user display name attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_DISPLAY_NAME_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="givenName"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="cn"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="givenName"
            fi
            echo "## Provide the user given name attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_GIVEN_NAME_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user family name attribute, the default value \"sn\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_FAMILY_NAME_ATTRIBUTE=\"sn\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user full name attribute, the default value \"cn\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_FULL_NAME_ATTRIBUTE=\"cn\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user external id attribute, the default value \"dn\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_EXTERNAL_ID_ATTRIBUTE=\"dn\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user emails attribute, the default value \"mail\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_EMAILS_ATTRIBUTE=\"mail\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="whenCreated"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="createTimestamp"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="createTimestamp"
            fi
            echo "## Provide the user created attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_CREATED_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="whenChanged"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="modifyTimestamp"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="modifyTimestamp"
            fi
            echo "## Provide the user lastModified attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_LASTMODIFIED_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user phoneNumbers value (first), the default value \"mobile\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_PHONENUMBERS_VALUE1=\"mobile\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user phoneNumbers type (first), the default value \"mobile\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_PHONENUMBERS_TYPE1=\"mobile\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user phoneNumbers value (second), the default value \"telephoneNumber\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_PHONENUMBERS_VALUE2=\"telephoneNumber\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user phoneNumbers type (second), the default value \"work\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_PHONENUMBERS_TYPE2=\"work\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user object class attribute, the default value \"person\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_OBJECT_CLASS_ATTRIBUTE=\"person\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the user groups attribute, the default value \"memberOf\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.USER_GROUPS_ATTRIBUTE=\"memberOf\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            # user profile SCMI Group section
            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="sAMAccountName"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="ibm-entryuuid"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="entryUUID"
            fi

            echo "## Provide the group unique id attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## This attribute MUST be set to an LDAP attribute that is unique and immutable." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.GROUP_UNIQUE_ID_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the group name attribute, the default value \"cn\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.GROUP_NAME_ATTRIBUTE=\"cn\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the group principal name attribute, the default value \"cn\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.GROUP_PRINCIPAL_NAME_ATTRIBUTE=\"cn\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the group display name attribute, the default value \"cn\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.GROUP_DISPLAY_NAME_ATTRIBUTE=\"cn\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            echo "## Provide the group external id attribute, the default value \"dn\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.GROUP_EXTERNAL_ID_ATTRIBUTE=\"dn\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="whenCreated"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="createTimestamp"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="createTimestamp"
            fi
            echo "## Provide the group created attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.GROUP_CREATED_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="whenChanged"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="modifyTimestamp"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="modifyTimestamp"
            fi
            echo "## Provide the group lastModified attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.GROUP_LASTMODIFIED_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="group"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="groupOfUniqueNames"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="groupOfUniqueNames"
            fi
            echo "## Provide the group object class attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.GROUP_OBJECT_CLASS_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            if [[ $LDAP_TYPE == "AD" ]]; then
                tmp_val="member"
            elif [[ $LDAP_TYPE == "TDS" ]]; then
                tmp_val="uniqueMember"
            elif [[ $LDAP_TYPE == "PDS" ]]; then
                tmp_val="uniqueMember"
            fi
            echo "## Provide the group members attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "SCIM.GROUP_MEMBERS_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
    fi


    # Add <Required> in each mandatory value
    if (( db_server_number > 0 )); then
        ${SED_COMMAND} "s|=\"\"|=\"<Required>\"|g" ${DB_NAME_USER_PROPERTY_FILE}
        ${SED_COMMAND} "s|=\"\"|=\"<Required>\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        #set DB2 HADR as optional
        if [[ $DB_TYPE != "db2hadr" && $DB_TYPE != "db2rdshadr" ]]; then
            ${SED_COMMAND} "s|HADR_STANDBY_SERVERNAME=\"<Required>\"|HADR_STANDBY_SERVERNAME=\"<Optional>\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.HADR_STANDBY_SERVERNAME")
            ${SED_COMMAND} "s|HADR_STANDBY_PORT=\"<Required>\"|HADR_STANDBY_PORT=\"<Optional>\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            OPTIONAL_PARAMETERS_LIST+=("${DB_SERVER_PREFIX}.HADR_STANDBY_PORT")
        elif [[ $DB_TYPE == "db2rdshadr" ]]; then
            ${SED_COMMAND} "/HADR_STANDBY_SERVERNAME=\"<Required>\"/d" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} "/HADR_STANDBY_PORT=\"<Required>\"/d" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} "/If the database type is Db2 HADR, then complete the rest of the parameters below. Provide the database server name or IP address of the standby database server./d" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} "/Provide the standby database server port./d" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} $'$a\\\n## For Amazon RDS for Db2, High Availability Disaster Recovery (HADR) is handle by AWS, please refer to AWS documentation: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Db2.Concepts.FeatureSupport.html#db2-unsupported-features' ${DB_SERVER_INFO_PROPERTY_FILE}
        fi
    fi

    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "no") && "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then
        ${SED_COMMAND} "s|LDAP_BIND_DN_PASSWORD=\"\"|LDAP_BIND_DN_PASSWORD=\"{Base64}<Required>\"|g" ${LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|=\"\"|=\"<Required>\"|g" ${LDAP_PROPERTY_FILE}
        ${SED_COMMAND} 's/LC_AD_GC_HOST="<Required>"/LC_AD_GC_HOST=""/g' ${LDAP_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("LC_AD_GC_HOST")
        ${SED_COMMAND} 's/LC_AD_GC_PORT="<Required>"/LC_AD_GC_PORT=""/g' ${LDAP_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("LC_AD_GC_PORT")

    fi

    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        ${SED_COMMAND} "s|LDAP_BIND_DN_PASSWORD=\"\"|LDAP_BIND_DN_PASSWORD=\"{Base64}<Required>\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|=\"\"|=\"<Required>\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} 's/LC_AD_GC_HOST="<Required>"/LC_AD_GC_HOST=""/g' ${EXTERNAL_LDAP_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("LC_AD_GC_HOST")
        ${SED_COMMAND} 's/LC_AD_GC_PORT="<Required>"/LC_AD_GC_PORT=""/g' ${EXTERNAL_LDAP_PROPERTY_FILE}
        OPTIONAL_PARAMETERS_LIST+=("LC_AD_GC_PORT")
    fi

    # Create the property file for the content cortex AI Services operator if chosen
    # Provider selection was done earlier; now we just generate the property file
    if [[ $SETUP_CONTENT_CORTEX_AI_SERVICES == "true" ]]; then
        INFO "Creating property file for IBM Content Cortex AI Services"
        wait_msg "Creating the provider configuration required for IBM Content Cortex AI Services"
        
        # Generate multi-provider property file using previously selected providers
        # Skip storage properties as they are already configured globally in cp4a-prerequisites.sh
        generate_multi_provider_property_file "skip_storage"
        
        success "Property file for IBM Content Cortex AI Services has been created.\n"
    fi
    

    # Marks all entries in "OPTIONAL_PARAMETERS_LIST" as optional by appending them to the TEMPORARY_PROPERTY_FILE under "OPTIONAL_PARAMETERS:"
    mark_optional

    if [[ ! -z "$ENABLE_VAULT_ON_EXIST" && "$ENABLE_VAULT_ON_EXIST" == "true" && ! -z "$EXISTING_PROP_FILES_PROVIDED" && "$EXISTING_PROP_FILES_PROVIDED" == "true" ]]; then
        # if we are enabling external secret management (Vault) and provided existing prop files, 
        # then we want to skip these output msgs below because we will be merging the values from original prop files. 
        # We will output messages more specific the Vault scenario after merging the prop files and adding Vault props.
        return
    fi
    
    INFO "All property files for CP4BA has been created."

    # Show some tips for property file
    tips
    printf '%b\n'  "Enter the <Required> values in the property files under $PROPERTY_FILE_FOLDER"
    msgRed   "The key name in the property file is created by the cp4a-prerequisites.sh and is NOT EDITABLE."
    msgRed   "The value in the property file must be within double quotes."
    msgRed   "The value for User/Password in [cp4ba_db_name_user.property] [cp4ba_user_profile.property] file should NOT include special characters: single quotation \"'\""
    msgRed   "The value in [cp4ba_LDAP.property] or [cp4ba_External_LDAP.property] [cp4ba_user_profile.property] file should NOT include special character '\"'"
    # This is an important note for to display to the user which is only applicable while adding /removing new patterns
    if [[ ! -z $UPDATE_COMPONENTS ]]; then
        msgRed "If you have selected a new deployment pattern/optional component that is not supported with the existing Database Type, you must update the property files to chose a supported Database Type for the new deployment patterns/optional components selected\n"
    fi

   
    
    if (( db_server_number > 0 )); then
        printf '%b\n'  "\x1b[32m* [cp4ba_db_server.property]:\x1B[0m"
        printf '%b\n'  "  - Properties for database server used by CP4BA deployment, such as DATABASE_SERVERNAME/DATABASE_PORT/DATABASE_SSL_ENABLE.\n"
        printf '%b\n'  "  - The value of \"<DB_SERVER_LIST>\" is an alias for the database servers. The key supports comma-separated lists.\n"

        printf '%b\n'  "\x1b[32m* [cp4ba_db_name_user.property]:\x1B[0m"
        printf '%b\n'  "  - Properties for database name and user name required by each component of the CP4BA deployment, such as GCD_DB_NAME/GCD_DB_USER_NAME/GCD_DB_USER_PASSWORD.\n"
        printf '%b\n'  "  - Change the prefix \"<DB_ALIAS_NAME>\" to assign which database is used by the component.\n"
        printf '%b\n'  "  - The value of \"<DB_ALIAS_NAME>\" must match the value of <DB_SERVER_LIST> that is defined in \"<DB_SERVER_LIST>\" of \"cp4ba_db_server.property\".\n"

        printf '%b\n' "\x1b[32m* [Database SSL Certificates]:\x1B[0m"
        echo
        # We want to inform the customer that the SSL certificates for Databases must be added into the property files folder prior to running generate mode
        # This is because aca-basedb uses the ssl cert value and base64 encodes it into a string while generating the template.
        # This is unlike the LDAP ssl secret which uses --from-file based format for the SSL certificates which allows the user to add the ssl certs to the folders even after the secret templates are generated.
        # https://jsw.ibm.com/browse/DBACLD-179824
        if [[ $DB_TYPE == "postgresql" ]]; then
            printf '%b\n' " - $RED_TEXT[REQUIRED]$RESET_TEXT If you plan to enable SSL-based connections for your PostgreSQL database server and SSL is configured with both server and client authentication, retrieve the following certificates from your database server: the server certificate, client certificate, and client private key. Copy them into the folder \"$DB_SSL_CERT_FOLDER/<DB_ALIAS_NAME>\" before running the cp4a-prerequisites.sh script in \"generate\" mode.$RED_TEXT The files must be named root.crt, client.crt, and client.key respectively.$RESET_TEXT"
            echo
            printf '%b\n' " - $RED_TEXT[REQUIRED]$RESET_TEXT If you plan to enable SSL-based connections for your PostgreSQL database server and SSL is configured with server-only authentication, retrieve the server certificate from your database server and copy it into the folder \"$DB_SSL_CERT_FOLDER/<DB_ALIAS_NAME>\" before running the cp4a-prerequisites.sh script in \"generate\" mode.$RED_TEXT The certificate must be named db-cert.crt $RESET_TEXT"
            echo
        else
            printf '%b\n' " - $RED_TEXT[REQUIRED]$RESET_TEXT If you plan to enable SSL-based connections for your database server, retrieve the server certificate file from your remote database server and copy it into the folder \"$DB_SSL_CERT_FOLDER/<DB_ALIAS_NAME>\" before running the cp4a-prerequisites.sh script in \"generate\" mode.$RED_TEXT The certificate must be named db-cert.crt. $RESET_TEXT"  
            echo
        fi
    fi
    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "no") ]]; then
        printf '%b\n'  "\x1b[32m* [cp4ba_LDAP.property]:\x1B[0m"
        printf '%b\n'  "  - Properties for the LDAP server that is used by the CP4BA deployment, such as LDAP_SERVER/LDAP_PORT/LDAP_BASE_DN/LDAP_BIND_DN/LDAP_BIND_DN_PASSWORD.\n"
        
        # We want to inform the customer that the SSL certificates for LDAP must be copied prior to running generate mode
        # https://jsw.ibm.com/browse/DBACLD-179824
        echo
        printf '%b\n' "\x1b[32m* [LDAP SSL Certificates]:\x1B[0m"
        echo
        printf '%b\n' "  - $RED_TEXT[REQUIRED]$RESET_TEXT If you plan to enable SSL-based connections for your LDAP server, retrieve the server certificate file from your remote LDAP server and copy it into the folder \"$LDAP_SSL_CERT_FOLDER\" before running the cp4a-prerequisites.sh script in \"generate\" mode.$RED_TEXT The certificate must be named ldap-cert.crt. $RESET_TEXT"  
        echo

        if [[ $SET_EXT_LDAP == "Yes" ]]; then
            printf '%b\n'  "\x1b[32m* [cp4ba_External_LDAP.property]:\x1B[0m"
            printf '%b\n'  "  - Properties for the External LDAP server that is used by External Share, such as LDAP_SERVER/LDAP_PORT/LDAP_BASE_DN/LDAP_BIND_DN/LDAP_BIND_DN_PASSWORD.\n"
            echo
            printf '%b\n' "\x1b[32m* [External LDAP SSL Certificates]:\x1B[0m"
            echo
            printf '%b\n' "  - $RED_TEXT[REQUIRED]$RESET_TEXT If you plan to enable SSL-based connections for your external LDAP server, retrieve the server certificate file from your remote LDAP server and copy it into the folder \"$LDAP_SSL_CERT_FOLDER\" before running the cp4a-prerequisites.sh script in \"generate\" mode.$RED_TEXT The certificate must be named external-ldap-cert.crt. $RESET_TEXT"  
            echo
        fi
    fi


    if [[ $SETUP_CONTENT_CORTEX_AI_SERVICES == "true" ]]; then
        printf '%b\n'  "\x1b[32m* [cp4ba_ai_services.property]:\x1B[0m"
        printf '%b\n'  "  - Properties for the setup and deployment of Content Cortex AI Services, such as PROVIDER_URL/MODEL_ID/ENABLE_REDIS.\n"
        echo
        printf '%b\n' "\x1b[32m* [SSL Certificates for Content Cortex AI Services]:\x1B[0m"
        echo
        printf '%b\n' "  - $RED_TEXT[REQUIRED]$RESET_TEXT If you plan to configuring WatsonX Lightweight Engine and will be enabling SSL-based connections, retrieve the server certificate file and copy it into the folder \"$WATSONX_SSL_CERT_FOLDER\" before running the cp4a-prerequisites.sh script in \"generate\" mode.$RED_TEXT The certificate must be named lwe.crt. $RESET_TEXT"  
        echo
    fi

    # show tips for IM metastore external Postgres DB
    if [[ $EXTERNAL_POSTGRESDB_FOR_IM == "true" ]]; then
        msgB "* You have enabled IM metastore external Postgres DB, please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from your local or remote database server, and copy them into folder \"$IM_DB_SSL_CERT_FOLDER\" before you execute the generate mode of cp4a-prerequisites.sh script."
    fi

    # show tips for Zen metastore external Postgres DB
    if [[ $EXTERNAL_POSTGRESDB_FOR_ZEN == "true"  ]]; then
        msgB "* You have enabled Zen metastore external Postgres DB, please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from your local or remote database server, and copy them into folder \"$ZEN_DB_SSL_CERT_FOLDER\" before you execute the generate mode of cp4a-prerequisites.sh script."
    fi

    # show tips for BTS metastore external Postgres DB
    if [[ $EXTERNAL_POSTGRESDB_FOR_BTS == "true" ]]; then
        msgB "* You have enabled BTS metastore external Postgres DB, please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from your local or remote database server, and copy them into folder \"$BTS_DB_SSL_CERT_FOLDER\" before you execute the generate mode of cp4a-prerequisites.sh script."
    fi

    printf '%b\n'  "\x1b[32m* [cp4ba_user_profile.property]:\x1B[0m"
    printf '%b\n'  "  - Properties for the global value used by the CP4BA deployment, such as \"sc_deployment_license\".\n"
    printf '%b\n'  "  - Properties for the value used by each component of CP4BA, such as <APPLOGIN_USER>/<APPLOGIN_PASSWORD>\n"
    if [[ $VAULT_ENABLED == "true" ]]; then
      printf '%b\n'  "  - Properties for Vault integration, such as \"VAULT_ROLE\", \"VAULT_ADDRESS\", etc.\n"
    fi

    echo
    printf '%b\n' "$RED_TEXT[IMPORTANT]:$RESET_TEXT Please make sure to save the property files located at $PROPERTY_FILE_FOLDER after you have deployed. These property files will be leveraged in the future for certain upgrade scenarios as well as when you are adding/removing components to your deployment. "  
    echo

    #DBACLD-196427 - clear next-step instruction after running with -m property mode
    printf '%b\n' "\x1b[32m* [Next Step]:\x1B[0m"
    printf '%b\n' "  - When all the required certificates and property files are prepared, run the following command to generate the database scripts and secret YAML files:"
    
    if [[ "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
        printf '%b\n' "    $RED_TEXT\"./cp4a-prerequisites.sh -m generate -n $CP4BA_SERVICES_NS\"${RESET_TEXT}"
    else 
        printf '%b\n' "    $RED_TEXT\"./cp4a-prerequisites.sh -m generate --enable-external-secret-management  -n $CP4BA_SERVICES_NS\"${RESET_TEXT}"
    fi
}
# ----------- End of function create_property_file() -----------

function select_storage_class(){
    printf "\n"
    storage_class_name=""
    block_storage_class_name=""
    sc_slow_file_storage_classname=""
    sc_medium_file_storage_classname=""
    sc_fast_file_storage_classname=""
    local sample_pvc_name=""

    printf "\n"
    printf "\x1B[1mTo provision the persistent volumes and volume claims\n\x1B[0m"

    while [[ $sc_slow_file_storage_classname == "" ]] # While get slow storage clase name
    do
        printf "\x1B[1mplease enter the file storage classname for slow storage(RWX): \x1B[0m"
        read -erp "" sc_slow_file_storage_classname
        if [ -z "$sc_slow_file_storage_classname" ]; then
        printf '%b\n' "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
        fi
    done

    while [[ $sc_medium_file_storage_classname == "" ]] # While get medium storage clase name
    do
        printf "\x1B[1mplease enter the file storage classname for medium storage(RWX): \x1B[0m"
        read -erp "" sc_medium_file_storage_classname
        if [ -z "$sc_medium_file_storage_classname" ]; then
        printf '%b\n' "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
        fi
    done

    while [[ $sc_fast_file_storage_classname == "" ]] # While get fast storage clase name
    do
        printf "\x1B[1mplease enter the file storage classname for fast storage(RWX): \x1B[0m"
        read -erp "" sc_fast_file_storage_classname
        if [ -z "$sc_fast_file_storage_classname" ]; then
        printf '%b\n' "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
        fi
    done

    while [[ $block_storage_class_name == "" ]] # While get block storage clase name
    do
        printf "\x1B[1mplease enter the block storage classname for Zen(RWO): \x1B[0m"
        read -erp "" block_storage_class_name
        if [ -z "$block_storage_class_name" ]; then
        printf '%b\n' "\x1B[1;31mEnter a valid block storage classname(RWO)\x1B[0m"
        fi
    done

    STORAGE_CLASS_NAME=${storage_class_name}
    SLOW_STORAGE_CLASS_NAME=${sc_slow_file_storage_classname}
    MEDIUM_STORAGE_CLASS_NAME=${sc_medium_file_storage_classname}
    FAST_STORAGE_CLASS_NAME=${sc_fast_file_storage_classname}
    BLOCK_STORAGE_CLASS_NAME=${block_storage_class_name}

}

function load_property_before_generate(){
    
    # load LDAP/DB required flag for wfps
    LDAP_WFPS_AUTHORING=$(prop_tmp_property_file LDAP_WFPS_AUTHORING_FLAG)
    # Convert to lowercase for comparison
    LDAP_WFPS_AUTHORING=$(echo "$LDAP_WFPS_AUTHORING" | tr '[:upper:]' '[:lower:]')

    # load ldap type (needed before the LDAP property file existence check below)
    LDAP_TYPE=$(prop_tmp_property_file LDAP_TYPE)
    
    # Load Content Cortex AI Services configuration with defaults
    SETUP_CONTENT_CORTEX_AI_SERVICES="$(prop_tmp_property_file SETUP_CONTENT_CORTEX_AI_SERVICES)"
    if [[ -z "$SETUP_CONTENT_CORTEX_AI_SERVICES" ]]; then
        SETUP_CONTENT_CORTEX_AI_SERVICES="false"
    fi
    
    # Check for required property files based on configuration flags
    missing_property_files=()
    
    if [[ ! -f $TEMPORARY_PROPERTY_FILE ]]; then
        missing_property_files+=("$TEMPORARY_PROPERTY_FILE")
    fi
    
    if [[ ! -f $DB_NAME_USER_PROPERTY_FILE ]]; then
        missing_property_files+=("$DB_NAME_USER_PROPERTY_FILE")
    fi
    
    if [[ ! -f $DB_SERVER_INFO_PROPERTY_FILE ]]; then
        missing_property_files+=("$DB_SERVER_INFO_PROPERTY_FILE")
    fi
    
    # Only check LDAP_PROPERTY_FILE if LDAP_WFPS_AUTHORING is not "no" and not External IDP
    if [[ "$LDAP_WFPS_AUTHORING" != "no" && "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then
        if [[ ! -f $LDAP_PROPERTY_FILE ]]; then
            missing_property_files+=("$LDAP_PROPERTY_FILE")
        fi
    fi
    
    # Only check AI_SERVICES_PROPERTY_FILE if SETUP_CONTENT_CORTEX_AI_SERVICES is not "false"
    if [[ "$SETUP_CONTENT_CORTEX_AI_SERVICES" != "false" ]]; then
        if [[ ! -f $AI_SERVICES_PROPERTY_FILE ]]; then
            missing_property_files+=("$AI_SERVICES_PROPERTY_FILE")
        fi
    fi
    
    # If any files are missing, display them and exit
    if [[ ${#missing_property_files[@]} -gt 0 ]]; then
        fail "The following required property files could not be found in the expected propertyfile folder: \"$PROPERTY_FILE_FOLDER\""
        for missing_file in "${missing_property_files[@]}"; do
            echo "  - $missing_file" >&2
        done
        exit 1
    fi

    # load pattern into pattern_cr_arr
    pattern_list="$(prop_tmp_property_file PATTERN_LIST)"
    optional_component_list="$(prop_tmp_property_file OPTION_COMPONENT_LIST)"
    foundation_list="$(prop_tmp_property_file FOUNDATION_LIST)"
    OIFS=$IFS
    IFS=',' read -ra pattern_cr_arr <<< "$pattern_list"
    IFS=',' read -ra optional_component_cr_arr <<< "$optional_component_list"
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
    # For DBACLD-165328
    DB_TYPE=$(echo "$DB_TYPE" | tr '[:upper:]' '[:lower:]')
    
    # DBACLD-217419: Load Vault enable flag for use in validate_ssl_certificates
    vault_enabled="$(prop_user_profile_property_file CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION | tr '[:upper:]' '[:lower:]')"
    vault_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$vault_enabled")
    # Default for IS_RDS is false
    # For DBACLD-163779
    IS_RDS=false
    
    # For Database type DB2 DB2HADR and DB2 RDS the generate mode and validate mode are all identical and in the script taken care off using $DB_TYPE == "db2"
    # Using a separate flag to determine if it is DB2 RDS solely so that different sql files are generated and the jar used for validate mode can accordingly add the additional parameters required
    # For DBACLD-163779
    if [[ $DB_TYPE == "db2"* ]]; then
        if [[ $DB_TYPE == "db2rds"* ]]; then
            IS_RDS=true
        fi
        DB_TYPE="db2"  
    fi

    # load CONTENT_OS_NUMBER
    content_os_number=$(prop_tmp_property_file CONTENT_OS_NUMBER)
    # msgB "$content_os_number"; sleep 300

    # load DB_SERVER_NUMBER
    db_server_number=$(prop_tmp_property_file DB_SERVER_NUMBER)

    # load external ldap flag
    SET_EXT_LDAP=$(prop_tmp_property_file EXTERNAL_LDAP_ENABLED)

    EXTERNAL_DB_WFPS_AUTHORING=$(prop_tmp_property_file EXTERNAL_DB_WFPS_AUTHORING_FLAG)

    # Load external PostgreSQL flags for IM, ZEN, BTS, and ADPGG/DICMS
    tmp_flag=$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_IM_FLAG)
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        EXTERNAL_POSTGRESDB_FOR_IM="true"
    else
        EXTERNAL_POSTGRESDB_FOR_IM="false"
    fi

    tmp_flag=$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_ZEN_FLAG)
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        EXTERNAL_POSTGRESDB_FOR_ZEN="true"
    else
        EXTERNAL_POSTGRESDB_FOR_ZEN="false"
    fi

    tmp_flag=$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_BTS_FLAG)
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        EXTERNAL_POSTGRESDB_FOR_BTS="true"
    else
        EXTERNAL_POSTGRESDB_FOR_BTS="false"
    fi

    tmp_flag=$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS_FLAG)
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS="true"
    else
        EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS="false"
    fi

    # Change for DBACLD-190482: Mark LDAP SSL params optional if SSL is disabled
    SELECTED_LDAP="No"
    if [[ " ${pattern_cr_arr[@]} " =~ "content" || " ${pattern_cr_arr[@]} " =~ "workflow-runtime" || " ${pattern_cr_arr[@]} " =~ "workstreams" || " ${pattern_cr_arr[@]} " =~ "document_processing" ]]; then
        SELECTED_LDAP="Yes"
    fi

    # Conditionally mark LDAP SSL params optional AFTER loading all variables
    OPTIONAL_PARAMETERS_LIST=($(printf '%s\n' "${OPTIONAL_PARAMETERS_LIST[@]}" | grep -v "^LDAP_SSL_SECRET_NAME$" | grep -v "^LDAP_SSL_CERT_FILE_FOLDER$" | grep -v "^EXT_LDAP_SSL_SECRET_NAME$" | grep -v "^EXT_LDAP_SSL_CERT_FILE_FOLDER$"))

    # Handle LDAP SSL parameters (skip for External IDP — no LDAP property file exists)
    if [[ $SELECTED_LDAP == "Yes" && "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ldap_property_file LDAP_SSL_ENABLED)")
        tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        if [[ ${tmp_flag} =~ ^(no|n|false)$ ]]; then
            OPTIONAL_PARAMETERS_LIST+=("LDAP_SSL_SECRET_NAME")
            OPTIONAL_PARAMETERS_LIST+=("LDAP_SSL_CERT_FILE_FOLDER")
        fi
    fi

    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        tmp_ext_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ext_ldap_property_file LDAP_SSL_ENABLED)")
        tmp_ext_flag=$(echo "$tmp_ext_flag" | tr '[:upper:]' '[:lower:]')
        if [[ ${tmp_ext_flag} =~ ^(no|n|false)$ ]]; then
            OPTIONAL_PARAMETERS_LIST+=("EXT_LDAP_SSL_SECRET_NAME")
            OPTIONAL_PARAMETERS_LIST+=("EXT_LDAP_SSL_CERT_FILE_FOLDER")
        fi
    fi

    # These parameters are for Redis V6+ with username support
    if [[ " ${pattern_cr_arr[@]} " =~ "document_processing" || " ${pattern_cr_arr[@]} " =~ "application" ]]; then
        OPTIONAL_PARAMETERS_LIST+=("APP_ENGINE.SESSION_REDIS_USERNAME")
    fi

    if [[ " ${pattern_cr_arr[@]} " =~ "document_processing_designer" || " ${optional_component_cr_arr[@]} " =~ "app_designer" || " ${optional_component_cr_arr[@]} " =~ "ads_designer" ]]; then
        OPTIONAL_PARAMETERS_LIST+=("APP_PLAYBACK.SESSION_REDIS_USERNAME")
    fi

    # load the flag that detects whether the script is being run to generate a CR to with updated list of components
    UPDATE_COMPONENTS=$(prop_tmp_property_file UPDATE_COMPONENTS)

    # Load Content Cortex AI Services configuration with defaults
    SETUP_CONTENT_CORTEX_AI_SERVICES="$(prop_tmp_property_file SETUP_CONTENT_CORTEX_AI_SERVICES)"
    if [[ -z "$SETUP_CONTENT_CORTEX_AI_SERVICES" ]]; then
        SETUP_CONTENT_CORTEX_AI_SERVICES="false"
    fi

    # If it is set up then we must make sure the property file for the AI Services is created and can be found
    if [[ "$SETUP_CONTENT_CORTEX_AI_SERVICES" == "true" ]]; then
        if [[ ! -f $AI_SERVICES_PROPERTY_FILE ]]; then
            fail "Based on the configurations selected, you have selected to setup Content Cortex AI Services, however the script cannot find the related property file $AI_SERVICES_PROPERTY_FILE in the expected propertyfile folder \"$PROPERTY_FILE_FOLDER\". Please re-run the cp4a-prerequisites.sh script in the property mode to fix this."
            exit 1
        fi
    fi

    # Mark the LDAP SSL parameters as optional
    mark_optional
}

function create_db_script(){
    local db_name_full_array=()
    local db_user_full_array=()
    local db_user_pwd_full_array=()

    INFO "Generating DB SQL Statement file required by CP4BA deployment based on property file"
    # Generate db2 sql statement file for FNCM
    rm -rf $DB_SCRIPT_FOLDER
    printf "\n"

    


    # Create db script when DB_TYPE is postgresql OR when external PostgreSQL is enabled for ADPGG/DICMS
    if [[ " ${pattern_cr_arr[@]} " =~ " decisions_ads " && ("$DB_TYPE" == "postgresql" || "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true") ]]; then

        # Create db script for each optional components chosen

        if [[ " ${optional_component_cr_arr[@]} " =~ " ads_designer " ]]; then
            echo "Creating the DB SQL statement file for DICMS DESIGNER database"
            tmp_dbname="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_NAME)"
            tmp_dbschemaname=""
            tmp_db_current_schema_name="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_CURRENT_SCHEMA)"
            # Remove leading and trailing spaces
            tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")

            if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                # db name should be lower case
                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
            fi

            tmp_dbuser="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_USER_NAME)"
            tmp_dbuserpwd="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_USER_PASSWORD)"
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name DICMS_DESIGNER_DB_USER_NAME)"

            check_dbserver_name_valid "$tmp_dbservername" "DICMS_DESIGNER_DB_USER_NAME"

            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                # decode password and remove Base64 string
                tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                check_single_quotes_password "$tmp_dbuserpwd" "DICMS_DESIGNER_DB_USER_PASSWORD"
            fi

            # Get DATABASE_TYPE for this server to support mixed database scenarios
            tmp_database_type=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file ${tmp_dbservername}.DATABASE_TYPE)")
            
            # Source PostgreSQL DICMS script functions if needed for external PostgreSQL DICMS database
            if [[ "$tmp_database_type" == "postgresql" && "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" && $DB_TYPE != "postgresql" ]]; then
                source ${CUR_DIR}/helper/database-sql/postgresql/dicms/create-dicms-dbscript.sh
            fi
            
            create_adsdesignerdb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_db_current_schema_name" "$tmp_database_type"

            success "Created the DB SQL statement file for DICMS DESIGNER database\n"
        fi

        if [[ " ${optional_component_cr_arr[@]} " =~ " ads_runtime " ]]; then
            echo "Creating the DB SQL statement file for DICMS Runtime database"
            tmp_dbname="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_NAME)"
            tmp_dbschemaname=""
            tmp_db_current_schema_name="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_CURRENT_SCHEMA)"
            # Remove leading and trailing spaces
            tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")

            if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                # db name should be lower case
                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
            fi

            tmp_dbuser="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_USER_NAME)"
            tmp_dbuserpwd="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_USER_PASSWORD)"
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name DICMS_RUNTIME_DB_USER_NAME)"

            check_dbserver_name_valid "$tmp_dbservername" "DICMS_RUNTIME_DB_USER_NAME"

            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
              # decode password and remove Base64 string
                tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                check_single_quotes_password "$tmp_dbuserpwd" "DICMS_RUNTIME_DB_USER_PASSWORD"
            fi

            # Get DATABASE_TYPE for this server to support mixed database scenarios
            tmp_database_type=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file ${tmp_dbservername}.DATABASE_TYPE)")
            
            # Source PostgreSQL DICMS script functions if needed for external PostgreSQL DICMS database
            if [[ "$tmp_database_type" == "postgresql" && "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" && $DB_TYPE != "postgresql" ]]; then
                source ${CUR_DIR}/helper/database-sql/postgresql/dicms/create-dicms-dbscript.sh
            fi
            
            create_adsruntimedb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_db_current_schema_name" "$tmp_database_type"

            success "Created the DB SQL statement file for DICMS RUNTIME database\n"
        fi
    fi


    # Generate DB SQL for GCD
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        wait_msg "Creating the DB SQL statement file for Content Cortex GCD database"
        while true; do
            case "$DB_TYPE" in
            "db2"|"sqlserver"|"postgresql")
                tmp_dbname="$(prop_db_name_user_property_file GCD_DB_NAME)"

                tmp_dbschemaname=""
                if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                    tmp_db_current_schema_name="$(prop_db_name_user_property_file GCD_DB_CURRENT_SCHEMA)"
                    tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                    if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschemaname=$tmp_db_current_schema_name
                    fi
                fi

                tmp_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"

                check_dbserver_name_valid "$tmp_dbservername" "GCD_DB_USER_NAME"
                # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "GCD_DB_USER_PASSWORD"
                fi
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_fncm_gcddb_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_fncm_gcddb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_dbschemaname"
                elif [[ $DB_TYPE == "db2" ]]; then
                    check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "GCD_DB_NAME"
                    # Calling a different function that will take care of creating the db2rds sql file
                    # DBACLD-163779
                    if [[ $IS_RDS == true ]]; then
                        create_fncm_gcddb_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname" "$tmp_dbuserpwd"
                    else
                        create_fncm_gcddb_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname"
                    fi
                fi
                break
                ;;
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "GCD_DB_USER_NAME"
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "GCD_DB_USER_PASSWORD"
                fi
                create_fncm_gcddb_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                break
                ;;
            esac
        done

        # ${SED_COMMAND} "s|\"||g" $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/createGCDDB.sql
        success "DB SQL statement file for Content Cortex GCD database has been created.\n"
    fi

   # Generate DB SQL for Objectstore
    if (( content_os_number > 0 )); then
        for ((j=1;j<=${content_os_number};j++))
        do
            wait_msg "Creating the DB SQL statement file for Content Cortex Object store database: os${j}db"

            ## Retrieving the tables,index, and lob storage location from the properties files
            ## to be passed to the helper functions to create the sql files.
            tmp_table_storage_location=""
            tmp_index_storage_location=""
            tmp_lob_storage_location=""
            tmp_table_storage_location_prop="$(prop_db_name_user_property_file OS${j}_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
            tmp_index_storage_location_prop="$(prop_db_name_user_property_file OS${j}_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
            tmp_lob_storage_location_prop="$(prop_db_name_user_property_file OS${j}_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
            if [[ $tmp_table_storage_location_prop != "<Optional>" && $tmp_table_storage_location_prop != "" ]]; then
              tmp_table_storage_location=$tmp_table_storage_location_prop
            fi
            if [[ $tmp_index_storage_location_prop != "<Optional>" && $tmp_index_storage_location_prop != "" ]]; then
              tmp_index_storage_location=$tmp_index_storage_location_prop
            fi
            if [[ $tmp_lob_storage_location_prop != "<Optional>" && $tmp_lob_storage_location_prop != "" ]]; then
              tmp_lob_storage_location=$tmp_lob_storage_location_prop
            fi

            while true; do
                case "$DB_TYPE" in
                "db2"|"sqlserver"|"postgresql")
                    tmp_dbname="$(prop_db_name_user_property_file OS${j}_DB_NAME)"
                    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file OS${j}_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbuser="$(prop_db_name_user_property_file OS${j}_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file OS${j}_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name OS${j}_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "OS${j}_DB_USER_NAME"
                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "OS${j}_DB_USER_PASSWORD"
                    fi
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_fncm_osdb_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" ${j} "" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                        # remove db_securityadmin/bulkadmin
                        ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/createOS${j}DB.sql
                        ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/createOS${j}DB.sql
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_fncm_osdb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "${j}" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                    elif [[ $DB_TYPE == "db2" ]]; then
                        check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "OS${j}_DB_NAME"
                        # Calling a different function that will take care of creating the db2rds sql file
                        # DBACLD-163779
                        if [[ $IS_RDS == true ]]; then
                            #echo "$tmp_dbname -- $tmp_dbuser --  $tmp_dbservername --- ${j} -- \"\" -- \"$tmp_dbschemaname\" --- \"$tmp_table_storage_location\" -- \"$tmp_index_storage_location\" -- \"$tmp_lob_storage_location\" --- \"$tmp_dbuserpwd\" "
                            create_fncm_osdb_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "${j}" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location" "$tmp_dbuserpwd"
                        else
                            create_fncm_osdb_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "${j}" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                        fi

                    fi
                    break
                    ;;
                "oracle")
                    tmp_dbuser="$(prop_db_name_user_property_file OS${j}_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file OS${j}_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name OS${j}_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "OS${j}_DB_USER_NAME"
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "OS${j}_DB_USER_PASSWORD"
                    fi
                    create_fncm_osdb_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" ${j} "" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                    break
                    ;;
                esac
            done

            # ${SED_COMMAND} "s|\"||g" $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/createOS${j}DB.sql
            success "DB SQL statement file for Content Cortex Object store database: os${j}db has been created.\n"
        done
    fi

    # Generate DB SQL for ICN
    if [[ " ${foundation_component_arr[@]}" =~ "BAN" ]]; then
        if [[ ! (" ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "1") ]]; then
            wait_msg "Creating the DB SQL statement file for ICN database"
            while true; do
                case "$DB_TYPE" in
                "db2"|"sqlserver"|"postgresql")
                    tmp_dbname="$(prop_db_name_user_property_file ICN_DB_NAME)"

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file ICN_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbuser="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file ICN_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "ICN_DB_USER_NAME"
                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "ICN_DB_USER_PASSWORD"
                    fi
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_ban_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_ban_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_dbschemaname"
                    elif [[ $DB_TYPE == "db2" ]]; then
                        check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "ICN_DB_NAME"
                        # Calling a different function that will take care of creating the db2rds sql file
                        # DBACLD-163779
                        if [[ $IS_RDS == true ]]; then
                            create_ban_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname" "$tmp_dbuserpwd"
                        else
                            create_ban_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname"                        
                        fi

                    fi
                    break
                    ;;
                "oracle")
                    tmp_dbuser="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file ICN_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "ICN_DB_USER_NAME"
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "ICN_DB_USER_PASSWORD"
                    fi
                    create_ban_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                    break
                    ;;
                esac
            done
            success "DB SQL statement file for ICN database has been created.\n"
        fi
    fi

    # Generate DB SQL for ODM
    containsElement "decisions" "${pattern_cr_arr[@]}"
    odm_Val=$?
    if [[ $odm_Val -eq 0 ]]; then
        wait_msg "Creating the DB SQL statement file for Operational Decision Manager database"
        while true; do
            case "$DB_TYPE" in
            "db2"|"sqlserver"|"postgresql")
                tmp_dbname="$(prop_db_name_user_property_file ODM_DB_NAME)"
                tmp_dbuser="$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file ODM_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ODM_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "ODM_DB_USER_NAME"
                # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "ODM_DB_USER_PASSWORD"
                fi
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_odm_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_odm_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                elif [[ $DB_TYPE == "db2" ]]; then
                    check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "ODM_DB_NAME"
                    # Calling a different function that will take care of creating the db2rds sql file
                    # DBACLD-163779
                    if [[ $IS_RDS == true ]]; then
                        ## https://jsw.ibm.com/browse/DBACLD-178818 - the 4th argument is for db schema name, but ODM is configure without schema.
                        create_odm_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "$tmp_dbuserpwd"
                    else
                        create_odm_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername"                        
                    fi
                fi
                break
                ;;
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file ODM_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ODM_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "ODM_DB_USER_NAME"
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "ODM_DB_USER_PASSWORD"
                fi
                create_odm_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                break
                ;;
            esac
        done
        success "DB SQL statement file for Operational Decision Manager database has been created.\n"
    fi

    # Generate DB SQL for ObjectStore required by BAW Authoring or BAW Runtime/AWS
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
        while true; do
            case "$DB_TYPE" in
            "oracle")
                if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
                    for i in "${!BAW_AUTH_OS_ARR[@]}"; do
                        tmp_dbuser=$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)
                        tmp_dbuserpwd=$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD)
                        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                        check_dbserver_name_valid "$tmp_dbservername" "${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME"
                        # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                        # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                        # Check base64 encoded or plain text
                        if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                            tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                            check_single_quotes_password "$tmp_dbuserpwd" "${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD"
                        fi
                        # echo "$tmp_dbuser"; sleep 3
                        wait_msg "Creating the DB SQL statement file for BAW: ${BAW_AUTH_OS_ARR[i]}"
                        ## Retrieving the tables,index, and lob storage location from the properties files
                        ## to be passed to the helper functions to create the sql files.
                        tmp_table_storage_location=""
                        tmp_index_storage_location=""
                        tmp_lob_storage_location=""
                        tmp_table_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                        tmp_index_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                        tmp_lob_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
                        if [[ $tmp_table_storage_location_prop != "<Optional>" && $tmp_table_storage_location_prop != "" ]]; then
                          tmp_table_storage_location=$tmp_table_storage_location_prop
                        fi
                        if [[ $tmp_index_storage_location_prop != "<Optional>" && $tmp_index_storage_location_prop != "" ]]; then
                          tmp_index_storage_location=$tmp_index_storage_location_prop
                        fi
                        if [[ $tmp_lob_storage_location_prop != "<Optional>" && $tmp_lob_storage_location_prop != "" ]]; then
                          tmp_lob_storage_location=$tmp_lob_storage_location_prop
                        fi
                        if [[ "${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" ]]; then
                            tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                            create_fncm_osdb_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "$tmp_tablespace" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                        else
                            create_fncm_osdb_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                        fi
                        success "DB SQL statement file for BAW: ${BAW_AUTH_OS_ARR[i]} has been created.\n"
                    done

                    # for case history
                    tmp_dbuser=$(prop_db_name_user_property_file CHOS_DB_USER_NAME)
                    tmp_dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuser")
                    tmp_dbuserpwd=$(prop_db_name_user_property_file CHOS_DB_USER_PASSWORD)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name CHOS_DB_USER_NAME)"
                    if [[ $tmp_dbservername != \#* ]] ; then
                        check_dbserver_name_valid "$tmp_dbservername" "CHOS_DB_USER_NAME"
                        # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                        # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                        # Check base64 encoded or plain text
                        if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                            tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                            check_single_quotes_password "$tmp_dbuserpwd" "CHOS_DB_USER_PASSWORD"
                        fi
                        wait_msg "Creating the DB SQL statement file for Case History: $tmp_dbuser"
                        create_fncm_osdb_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                        success "DB SQL statement file for Case History: $tmp_dbuser has been created.\n"
                    fi
                fi
                if [[ " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
                    ## Retrieving the tables,index, and lob storage location from the properties files
                    ## to be passed to the helper functions to create the sql files.
                    tmp_table_storage_location=""
                    tmp_index_storage_location=""
                    tmp_lob_storage_location=""
                    tmp_table_storage_location_prop="$(prop_db_name_user_property_file AWSDOCS_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                    tmp_index_storage_location_prop="$(prop_db_name_user_property_file AWSDOCS_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                    tmp_lob_storage_location_prop="$(prop_db_name_user_property_file AWSDOCS_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
                    if [[ $tmp_table_storage_location_prop != "<Optional>" && $tmp_table_storage_location_prop != "" ]]; then
                      tmp_table_storage_location=$tmp_table_storage_location_prop
                    fi
                    if [[ $tmp_index_storage_location_prop != "<Optional>" && $tmp_index_storage_location_prop != "" ]]; then
                      tmp_index_storage_location=$tmp_index_storage_location_prop
                    fi
                    if [[ $tmp_lob_storage_location_prop != "<Optional>" && $tmp_lob_storage_location_prop != "" ]]; then
                      tmp_lob_storage_location=$tmp_lob_storage_location_prop
                    fi
                    tmp_dbuser=$(prop_db_name_user_property_file AWSDOCS_DB_USER_NAME)
                    tmp_dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuser")
                    tmp_dbuserpwd=$(prop_db_name_user_property_file AWSDOCS_DB_USER_PASSWORD)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "AWSDOCS_DB_USER_NAME"
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "AWSDOCS_DB_USER_PASSWORD"
                    fi
                    # echo "$tmp_dbuser"; sleep 3
                    wait_msg "Creating the DB SQL statement file for BAW: $tmp_dbuser"
                    create_fncm_osdb_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                    success "Created the DB SQL statement file for BAW: $tmp_dbuser\n"
                fi
                break
                ;;
            "db2"|"sqlserver"|"postgresql")
                if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
                    for i in "${!BAW_AUTH_OS_ARR[@]}"; do
                        tmp_dbuser=$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)
                        tmp_dbname=$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_NAME)
                        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                        tmp_dbschemaname=""
                        if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                            tmp_db_current_schema_name="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_CURRENT_SCHEMA)"
                            tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                            if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                                if [[ $DB_TYPE == "postgresql" ]]; then
                                    tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                                fi
                                tmp_dbschemaname=$tmp_db_current_schema_name
                            fi
                        fi

                        tmp_dbuserpwd=$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD)
                        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                        check_dbserver_name_valid "$tmp_dbservername" "${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME"

                        # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                        # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                        # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                        # Check base64 encoded or plain text
                        if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                            tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                            check_single_quotes_password "$tmp_dbuserpwd" "${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD"
                        fi

                        ## Retrieving the tables,index, and lob storage location from the properties files
                        ## to be passed to the helper functions to create the sql files.
                        tmp_table_storage_location=""
                        tmp_index_storage_location=""
                        tmp_lob_storage_location=""
                        tmp_table_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                        tmp_index_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                        tmp_lob_storage_location_prop="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
                        if [[ $tmp_table_storage_location_prop != "<Optional>" && $tmp_table_storage_location_prop != "" ]]; then
                          tmp_table_storage_location=$tmp_table_storage_location_prop
                        fi
                        if [[ $tmp_index_storage_location_prop != "<Optional>" && $tmp_index_storage_location_prop != "" ]]; then
                          tmp_index_storage_location=$tmp_index_storage_location_prop
                        fi
                        if [[ $tmp_lob_storage_location_prop != "<Optional>" && $tmp_lob_storage_location_prop != "" ]]; then
                          tmp_lob_storage_location=$tmp_lob_storage_location_prop
                        fi

                        # echo "$tmp_dbname"; sleep 300
                        wait_msg "Creating the DB SQL statement file for BAW: ${BAW_AUTH_OS_ARR[i]}"
                        if [[ $DB_TYPE == "sqlserver" ]]; then
                            if [[ "${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" ]]; then
                                tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                                create_fncm_osdb_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "$tmp_tablespace" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                            else
                                create_fncm_osdb_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                            fi

                            if [[ ! ("${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" || "${BAW_AUTH_OS_ARR[i]}" == "BAWDOS") ]]; then
                                ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                                ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                            fi
                        elif [[ $DB_TYPE == "postgresql" ]]; then
                            if [[ "${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" ]]; then
                                tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                                create_fncm_osdb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "$tmp_tablespace" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                            else
                                create_fncm_osdb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                            fi
                        elif [[ $DB_TYPE == "db2" ]]; then
                            check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "${BAW_AUTH_OS_ARR[i]}_DB_NAME"
                            if [[ "${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" ]]; then
                                tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                                # Calling a different function that will take care of creating the db2rds sql file
                                # DBACLD-163779
                                if [[ $IS_RDS == true ]]; then
                                    create_fncm_osdb_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "$tmp_tablespace" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location" "$tmp_dbuserpwd"
                                else
                                    create_fncm_osdb_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "$tmp_tablespace" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"                        
                                fi
                                
                            else
                                # Calling a different function that will take care of creating the db2rds sql file
                                # DBACLD-163779
                                if [[ $IS_RDS == true ]]; then
                                    create_fncm_osdb_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location" "$tmp_dbuserpwd"
                                else
                                    create_fncm_osdb_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"                      
                                fi
                            fi
                        fi
                        success "Created the DB SQL statement file for BAW: ${BAW_AUTH_OS_ARR[i]}\n"
                    done
                    # for case history
                    tmp_dbname=$(prop_db_name_user_property_file CHOS_DB_NAME)
                    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file CHOS_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbuser=$(prop_db_name_user_property_file CHOS_DB_USER_NAME)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name CHOS_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "CHOS_DB_USER_NAME"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file CHOS_DB_USER_PASSWORD)"

                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "CHOS_DB_USER_PASSWORD"
                    fi
                    if [[ $tmp_dbservername != \#* ]] ; then
                        wait_msg "Creating the DB SQL statement file for Case History: $tmp_dbname"
                        if [[ $DB_TYPE == "sqlserver" ]]; then
                            create_fncm_osdb_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                            # remove db_securityadmin/bulkadmin
                            ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                            ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                        elif [[ $DB_TYPE == "postgresql" ]]; then
                            create_fncm_osdb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_dbschemaname"
                        elif [[ $DB_TYPE == "db2" ]]; then
                            check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "CHOS_DB_NAME"
                            # Calling a different function that will take care of creating the db2rds sql file
                            # DBACLD-163779
                            if [[ $IS_RDS == true ]]; then
                                create_fncm_osdb_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "" "" "" "$tmp_dbuserpwd"
                            else
                                create_fncm_osdb_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "" "$tmp_dbschemaname"                      
                            fi
                        fi
                        success "Created the DB SQL statement file for Case History: $tmp_dbname\n"
                    fi
                fi
                if [[ " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
                    tmp_dbname=$(prop_db_name_user_property_file AWSDOCS_DB_NAME)
                    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file AWSDOCS_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbuser=$(prop_db_name_user_property_file AWSDOCS_DB_USER_NAME)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "AWSDOCS_DB_USER_NAME"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWSDOCS_DB_USER_PASSWORD)"


                    ## Retrieving the tables,index, and lob storage location from the properties files
                    ## to be passed to the helper functions to create the sql files.
                    tmp_table_storage_location=""
                    tmp_index_storage_location=""
                    tmp_lob_storage_location=""
                    tmp_table_storage_location_prop="$(prop_db_name_user_property_file AWSDOCS_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                    tmp_index_storage_location_prop="$(prop_db_name_user_property_file AWSDOCS_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                    tmp_lob_storage_location_prop="$(prop_db_name_user_property_file AWSDOCS_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
                    if [[ $tmp_table_storage_location_prop != "<Optional>" && $tmp_table_storage_location_prop != "" ]]; then
                      tmp_table_storage_location=$tmp_table_storage_location_prop
                    fi
                    if [[ $tmp_index_storage_location_prop != "<Optional>" && $tmp_index_storage_location_prop != "" ]]; then
                      tmp_index_storage_location=$tmp_index_storage_location_prop
                    fi
                    if [[ $tmp_lob_storage_location_prop != "<Optional>" && $tmp_lob_storage_location_prop != "" ]]; then
                      tmp_lob_storage_location=$tmp_lob_storage_location_prop
                    fi

                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "AWSDOCS_DB_USER_PASSWORD"
                    fi
                    wait_msg "Creating the DB SQL statement file for BAW: $tmp_dbname"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_fncm_osdb_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                        # remove db_securityadmin/bulkadmin
                        ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                        ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_fncm_osdb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                    elif [[ $DB_TYPE == "db2" ]]; then
                        check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "AWSDOCS_DB_NAME"
                        # Calling a different function that will take care of creating the db2rds sql file
                        # DBACLD-163779
                        if [[ $IS_RDS == true ]]; then
                            create_fncm_osdb_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location" "$tmp_dbuserpwd"
                        else
                            create_fncm_osdb_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"                      
                        fi
                        
                    fi
                    success "DB SQL statement file for BAW: $tmp_dbname has been created.\n"
                fi
                if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
                    tmp_dbname=$(prop_db_name_user_property_file DEVOS_DB_NAME)
                    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file DEVOS_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbuser=$(prop_db_name_user_property_file DEVOS_DB_USER_NAME)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name DEVOS_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "DEVOS_DB_USER_NAME"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file DEVOS_DB_USER_PASSWORD)"

                    ## Retrieving the tables,index, and lob storage location from the properties files
                    ## to be passed to the helper functions to create the sql files.
                    tmp_table_storage_location=""
                    tmp_index_storage_location=""
                    tmp_lob_storage_location=""
                    tmp_table_storage_location_prop="$(prop_db_name_user_property_file DEVOS_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                    tmp_index_storage_location_prop="$(prop_db_name_user_property_file DEVOS_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
                    tmp_lob_storage_location_prop="$(prop_db_name_user_property_file DEVOS_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
                    if [[ $tmp_table_storage_location_prop != "<Optional>" && $tmp_table_storage_location_prop != "" ]]; then
                      tmp_table_storage_location=$tmp_table_storage_location_prop
                    fi
                    if [[ $tmp_index_storage_location_prop != "<Optional>" && $tmp_index_storage_location_prop != "" ]]; then
                      tmp_index_storage_location=$tmp_index_storage_location_prop
                    fi
                    if [[ $tmp_lob_storage_location_prop != "<Optional>" && $tmp_lob_storage_location_prop != "" ]]; then
                      tmp_lob_storage_location=$tmp_lob_storage_location_prop
                    fi
                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "DEVOS_DB_USER_PASSWORD"
                    fi
                    wait_msg "Creating the DB SQL statement file for ADP: $tmp_dbname"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_fncm_osdb_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                        # remove db_securityadmin/bulkadmin
                        ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                        ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_fncm_osdb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                    elif [[ $DB_TYPE == "db2" ]]; then
                        check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "DEVOS_DB_NAME"
                        # Calling a different function that will take care of creating the db2rds sql file
                        # DBACLD-163779
                        if [[ $IS_RDS == true ]]; then
                            create_fncm_osdb_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location" "$tmp_dbuserpwd"
                        else
                            create_fncm_osdb_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"                      
                        fi
                        
                    fi
                    success "DB SQL statement file for ADP: $tmp_dbname has been created.\n"
                fi
                break
                ;;
            esac
        done
    fi

    # Generate DB SQL for ADP on db2 or postgresql
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        local db_name_array=()
        local db_user_array=()
        local db_userpwd_array=()
        local db_ontology_array=()

        base_dbname=$(prop_db_name_user_property_file ADP_BASE_DB_NAME)
        base_dbuser=$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)
        base_dbuserpwd=$(prop_db_name_user_property_file ADP_BASE_DB_USER_PASSWORD)
        base_dbservername="$(prop_db_name_user_property_file_for_server_name ADP_BASE_DB_USER_NAME)"
        check_dbserver_name_valid "$base_dbservername" "ADP_BASE_DB_USER_NAME"
        db_name_full_array=(${db_name_full_array[@]} $base_dbname)
        db_user_full_array=(${db_user_full_array[@]} $base_dbuser)
        db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $base_dbuserpwd)

        wait_msg "Creating the DB SQL statement file for Document Processing Engine databases"
        if [[ $DB_TYPE == "db2" ]]; then
          check_db2_name_valid "$base_dbname" "$base_dbservername" "ADP_BASE_DB_NAME"
        fi
        # Create script for creating base database
        # Calling a different function that will take care of creating the db2rds sql file
        # DBACLD-163779
        if [[ $IS_RDS == true ]]; then
            create_adp_basedb_rds_sql "$base_dbname" "$base_dbuser" "$base_dbservername" "$base_dbuserpwd"
        else
            create_adp_basedb_sql "$base_dbname" "$base_dbuser" "$base_dbservername"
        fi
        # For DB2, there is separate SQL script for granting permissions on DB
        if [[ $DB_TYPE == "db2" ]]; then
            # Calling a different function that will take care of creating the db2rds sql file
            # DBACLD-163779
            if [[ $IS_RDS == true ]]; then
                grant_perms_adp_basedb_rds_sql "$base_dbuser" "$base_dbservername"
            else
                grant_perms_adp_basedb_sql "$base_dbname" "$base_dbuser" "$base_dbservername"
            fi
        fi
        if [[ $IS_RDS == true ]]; then
            # Calling a different function that will take care of creating the db2rds sql file
            # DBACLD-163779
            create_adp_basedb_rds_tables_sql "$base_dbuser" "$base_dbservername"
        else
            create_adp_basedb_tables_sql "$base_dbname" "$base_dbuser" "$base_dbservername"
        fi
        success "Created the DB SQL statement file for Document Processing Engine Base database: $base_dbname \n"

        tmp_dbname=$(prop_db_name_user_property_file ADP_PROJECT_DB_NAME)
        tmp_dbuser=$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_NAME)
        tmp_dbuserpwd=$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_PASSWORD)
        tmp_ontology=$(prop_db_name_user_property_file ADP_PROJECT_ONTOLOGY)
        tmp_dbservername=$(prop_db_name_user_property_file ADP_PROJECT_DB_SERVER)
        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
        tmp_dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuser")
        tmp_dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuserpwd")
        tmp_ontology=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ontology")
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")

        OIFS=$IFS
        IFS=',' read -ra db_name_array <<< "$tmp_dbname"
        IFS=',' read -ra db_user_array <<< "$tmp_dbuser"
        IFS=',' read -ra db_userpwd_array <<< "$tmp_dbuserpwd"
        IFS=',' read -ra db_ontology_array <<< "$tmp_ontology"
        IFS=',' read -ra db_server_array <<< "$tmp_dbservername"
        IFS=$OIFS

        # Validate array lengths - password array only checked if not using client auth
        if [[ (${#db_name_array[@]} != ${#db_user_array[@]}) || (${#db_name_array[@]} != ${#db_ontology_array[@]}) || (${#db_name_array[@]} != ${#db_server_array[@]}) ]]; then
            fail "The number of values of: ADP_PROJECT_DB_NAME, ADP_PROJECT_DB_USER_NAME, ADP_PROJECT_ONTOLOGY, ADP_PROJECT_DB_SERVER must all be equal. Exit ..."
        fi
        if ! is_pg_client_auth && [[ ${#db_name_array[@]} != ${#db_userpwd_array[@]} ]]; then
            fail "The number of values of: ADP_PROJECT_DB_USER_PASSWORD must match other arrays when not using client certificate authentication. Exit ..."
        fi
        
        if [[ ${#db_name_array[@]} -gt 0 ]]; then
            for num in "${!db_name_array[@]}"; do
                tmp_dbname=${db_name_array[num]}
                tmp_dbuser=${db_user_array[num]}
                tmp_dbuserpwd=${db_userpwd_array[num]}
                tmp_ontology=${db_ontology_array[num]}
                tmp_dbservername=${db_server_array[num]}

                tmp_dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.DATABASE_SERVERNAME)")
                tmp_dbport=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.DATABASE_PORT)")

                db_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.DATABASE_SSL_ENABLE)")
                db_ssl_flag=$(echo "$db_ssl_flag"| tr '[:upper:]' '[:lower:]')

                # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                ((j=num+1))
                # echo "$tmp_dbname"; sleep 300
                wait_msg "Creating the DB SQL statement files for Document Processing Engine Project databases: ${db_name_array[num]}"
                # Create script to create tenant DB
                if [[ $DB_TYPE == "db2" ]]; then
                  check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "ADP_PROJECT_DB_NAME" ${j}
                fi
                # Calling a different function that will take care of creating the db2rds sql file
                # DBACLD-163779
                if [[ $IS_RDS == true ]]; then
                    create_adp_tenantdb_rds_sql "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "${j}" "$tmp_dbuserpwd"
                else
                    create_adp_tenantdb_sql "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" ${j}
                fi
                # For DB2, there is separate SQL script for granting permissions on DB
                if [[ $DB_TYPE == "db2" ]]; then
                    # Calling a different function that will take care of creating the db2rds sql file
                    # DBACLD-163779
                    if [[ $IS_RDS == true ]]; then
                        grant_perms_adp_tenantdb_rds_sql "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "${j}"
                    else
                        grant_perms_adp_tenantdb_sql "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" ${j}
                    fi
                fi
                
                # Calling a different function that will take care of creating the db2rds sql file
                # DBACLD-163779
                # Create tables in tenant DB and inserting tenant into base DB
                if [[ $IS_RDS == true ]]; then
                    create_adp_tenantdb_tables_rds_sql "$tmp_dbname" "$tmp_dbuser" "$tmp_ontology" "$tmp_dbservername" "${j}"  
                    create_adp_insert_tenant_rds_sql "$base_dbname" "$base_dbuser" "$tmp_dbname" "$tmp_dbuser" "$tmp_ontology" "$tmp_dbservername" "$db_ssl_flag" "${j}" "$tmp_dbserver" "$tmp_dbport"
                else
                    create_adp_tenantdb_tables_sql "$tmp_dbname" "$tmp_dbuser" "$tmp_ontology" "$tmp_dbservername" ${j}
                    create_adp_insert_tenant_sql "$base_dbname" "$base_dbuser" "$tmp_dbname" "$tmp_dbuser" "$tmp_ontology" "$tmp_dbservername" "$db_ssl_flag" ${j} "$tmp_dbserver" "$tmp_dbport"
                fi
                success "DB SQL statement files for Document Processing Engine Project databases: ${db_name_array[num]} has been created.\n"
            done
        fi

        # set flag for CA database PostgresQL to true, so we can output certain help statements
        if [[ $DB_TYPE == "postgresql" ]]; then
          ca_db_pg_flag=true
        fi

    fi

    # Create ADP GITGATEWAY database script when DB_TYPE is postgresql OR when external PostgreSQL is enabled for ADPGG/DICMS
    if [[ " ${pattern_cr_arr[@]} " =~ " document_processing_designer " && ("$DB_TYPE" == "postgresql" || "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true") ]]; then
            echo "Creating the DB SQL statement file for ADP GITGATEWAY database"
            tmp_dbname="$(prop_db_name_user_property_file ADP_GG_DB_NAME)"
            tmp_dbschemaname=""
            tmp_db_current_schema_name="$(prop_db_name_user_property_file ADP_GG_DB_SCHEMA)"
            # Remove leading and trailing spaces
            tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")

            if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                # db name should be lower case
                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
            fi

            tmp_dbuser="$(prop_db_name_user_property_file ADP_GG_DB_USER_NAME)"
            tmp_dbuserpwd="$(prop_db_name_user_property_file ADP_GG_DB_USER_PASSWORD)"
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ADP_GG_DB_USER_NAME)"

            check_dbserver_name_valid "$tmp_dbservername" "ADP_GG_DB_USER_NAME"

            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                # decode password and remove Base64 string
                tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                check_single_quotes_password "$tmp_dbuserpwd" "ADP_GG_DB_USER_PASSWORD"
            fi

            # Get DATABASE_TYPE for this server to support mixed database scenarios
            tmp_database_type=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file ${tmp_dbservername}.DATABASE_TYPE)")
            
            # Source PostgreSQL ADP script functions if needed for external PostgreSQL ADPGG database
            if [[ "$tmp_database_type" == "postgresql" && "$EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS" == "true" && $DB_TYPE != "postgresql" ]]; then
                source ${CUR_DIR}/helper/database-sql/postgresql/adp/create-adp-dbscript.sh
            fi
            
            create_adpggdb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_dbschemaname" "$tmp_database_type"

            success "Created the DB SQL statement file for ADP GITGATEWAY database\n"
    fi

    # Generate DB SQL for AE data persistent
    if [[ " ${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        wait_msg "Creating the DB SQL statement file for Application Engine Data Persistent"
        ## Retrieving the tables,index, and lob storage location from the properties files
        ## to be passed to the helper functions to create the sql files.
        tmp_table_storage_location=""
        tmp_index_storage_location=""
        tmp_lob_storage_location=""
        tmp_table_storage_location_prop="$(prop_db_name_user_property_file AEOS_DB_TABLE_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
        tmp_index_storage_location_prop="$(prop_db_name_user_property_file AEOS_DB_INDEX_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//' )"
        tmp_lob_storage_location_prop="$(prop_db_name_user_property_file AEOS_DB_LOB_STORAGE_LOCATION | sed -e 's/^"//' -e 's/"$//')"
        if [[ $tmp_table_storage_location_prop != "<Optional>" && $tmp_table_storage_location_prop != "" ]]; then
          tmp_table_storage_location=$tmp_table_storage_location_prop
        fi
        if [[ $tmp_index_storage_location_prop != "<Optional>" && $tmp_index_storage_location_prop != "" ]]; then
          tmp_index_storage_location=$tmp_index_storage_location_prop
        fi
        if [[ $tmp_lob_storage_location_prop != "<Optional>" && $tmp_lob_storage_location_prop != "" ]]; then
          tmp_lob_storage_location=$tmp_lob_storage_location_prop
        fi
        while true; do
            case "$DB_TYPE" in
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file AEOS_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file AEOS_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AEOS_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "AEOS_DB_USER_NAME"
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "AEOS_DB_USER_PASSWORD"
                fi
                create_fncm_osdb_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                break
                ;;
            "db2"|"sqlserver"|"postgresql")
                tmp_dbname=$(prop_db_name_user_property_file AEOS_DB_NAME)
                tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                tmp_dbschemaname=""
                if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                    tmp_db_current_schema_name="$(prop_db_name_user_property_file AEOS_DB_CURRENT_SCHEMA)"
                    tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                    if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschemaname=$tmp_db_current_schema_name
                    fi
                fi

                tmp_dbuser="$(prop_db_name_user_property_file AEOS_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file AEOS_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AEOS_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "AEOS_DB_USER_NAME"
                # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "AEOS_DB_USER_PASSWORD"
                fi
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_fncm_osdb_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                    # remove db_securityadmin/bulkadmin
                    ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                    ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_fncm_osdb_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"
                elif [[ $DB_TYPE == "db2" ]]; then
                    check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "AEOS_DB_NAME"
                    # Calling a different function that will take care of creating the db2rds sql file
                    # DBACLD-163779
                    if [[ $IS_RDS == true ]]; then
                        create_fncm_osdb_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location" "$tmp_dbuserpwd"
                    else
                        create_fncm_osdb_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "" "" "$tmp_dbschemaname" "$tmp_table_storage_location" "$tmp_index_storage_location" "$tmp_lob_storage_location"                     
                    fi
                    
                fi
                break
                ;;
            esac
        done
        success "DB SQL statement file for Application Engine Data Persistent has been created.\n"
        # ${SED_COMMAND} "s|\"||g" $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/create${tmp_dbname}.sql
    fi

    # # Generate DB SQL for BAW Authoring Database

    # if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
    #     wait_msg "Creating the DB SQL statement file for Business Automation Workflow database"
    #     while true; do
    #         case "$DB_TYPE" in
    #         "db2"|"sqlserver"|"postgresql")
    #             tmp_dbname="$(prop_db_name_user_property_file AUTHORING_DB_NAME)"
    #             tmp_dbuser="$(prop_db_name_user_property_file AUTHORING_DB_USER_NAME)"
    #             tmp_dbuserpwd="$(prop_db_name_user_property_file AUTHORING_DB_USER_PASSWORD)"
    #             tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AUTHORING_DB_USER_NAME)"
    #             check_dbserver_name_valid "$tmp_dbservername" "AUTHORING_DB_USER_NAME"
    #             db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
    #             db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
    #             db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
    #             if [[ $DB_TYPE == "sqlserver" ]]; then
    #                 create_baw_db_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
    #             elif [[ $DB_TYPE == "postgresql" ]]; then
    #                 create_baw_db_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
    #             elif [[ $DB_TYPE == "db2" ]]; then
    #                 create_baw_db_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername"
    #             fi
    #             break
    #             ;;
    #         "oracle")
    #             tmp_dbuser="$(prop_db_name_user_property_file AUTHORING_DB_USER_NAME)"
    #             tmp_dbuserpwd="$(prop_db_name_user_property_file AUTHORING_DB_USER_PASSWORD)"
    #             tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AUTHORING_DB_USER_NAME)"
    #             check_dbserver_name_valid "$tmp_dbservername" "AUTHORING_DB_USER_NAME"
    #             db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
    #             db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

    #             create_baw_db_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
    #             break
    #             ;;
    #         esac
    #     done
    #     success "Created the DB SQL statement file for Business Automation Workflow database\n"
    # fi

    # Generate DB SQL for BAW_INSTANCE1_DB_NAME and BAW_INSTANCE2_DB_NAME for BAW/AWS

    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
        while true; do
            case "$DB_TYPE" in
            "db2"|"sqlserver"|"postgresql")
                if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "BAW_RUNTIME_DB_USER_NAME"

                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "BAW_RUNTIME_DB_USER_PASSWORD"
                    fi
                    wait_msg "Creating the DB SQL statement file for Business Automation Workflow database instance1 required by BAW"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_bawaws1_db_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_bawaws1_db_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_dbschemaname"
                    elif [[ $DB_TYPE == "db2" ]]; then
                        check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "BAW_RUNTIME_DB_NAME"
                        # Calling a different function that will take care of creating the db2rds sql file
                        # DBACLD-163779
                        if [[ $IS_RDS == true ]]; then
                            create_bawaws1_db_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname" "$tmp_dbuserpwd"
                        else
                            create_bawaws1_db_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname"                    
                        fi
                    fi
                    success "DB SQL statement file for Business Automation Workflow database instance1 required by BAW has been created.\n"

                    tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
                    tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "AWS_DB_USER_NAME"

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file AWS_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "AWS_DB_USER_PASSWORD"
                    fi
                    wait_msg "Creating the DB SQL statement file for Business Automation Workflow database instance2 required by AWS"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_bawaws2_db_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_bawaws2_db_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_dbschemaname"
                    elif [[ $DB_TYPE == "db2" ]]; then
                        check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "AWS_DB_NAME"
                        # Calling a different function that will take care of creating the db2rds sql file
                        # DBACLD-163779
                        if [[ $IS_RDS == true ]]; then
                            create_bawaws2_db_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname" "$tmp_dbuserpwd"
                        else
                            create_bawaws2_db_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname"                    
                        fi
                    fi
                    success "DB SQL statement file for Business Automation Workflow database instance2 required by AWS has been created.\n"
                elif [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
                    tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "BAW_RUNTIME_DB_USER_NAME"

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi
                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "BAW_RUNTIME_DB_USER_PASSWORD"
                    fi
                    wait_msg "Creating the DB SQL statement file for database required by Business Automation Workflow Runtime"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_bawaws1_db_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_bawaws1_db_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_dbschemaname"
                    elif [[ $DB_TYPE == "db2" ]]; then
                        check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "BAW_RUNTIME_DB_NAME"
                        # Calling a different function that will take care of creating the db2rds sql file
                        # DBACLD-163779
                        if [[ $IS_RDS == true ]]; then
                            create_bawaws1_db_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname" "$tmp_dbuserpwd"
                        else
                            create_bawaws1_db_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname"                   
                        fi
                        
                    fi
                    success "DB SQL statement file for database required by Business Automation Workflow Runtime has been created.\n"
                elif [[ " ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
                    tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "AWS_DB_USER_NAME"

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file AWS_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "AWS_DB_USER_PASSWORD"
                    fi

                    wait_msg "Creating the DB SQL statement file for database required by Automation Workstream Services"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_bawaws2_db_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_bawaws2_db_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_dbschemaname"
                    elif [[ $DB_TYPE == "db2" ]]; then
                        check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "AWS_DB_NAME"
                        # Calling a different function that will take care of creating the db2rds sql file
                        # DBACLD-163779
                        if [[ $IS_RDS == true ]]; then
                            create_bawaws2_db_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname" "$tmp_dbuserpwd"
                        else
                            create_bawaws2_db_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname"                   
                        fi
                        
                    fi
                    success "DB SQL statement file for database required by Automation Workstream Services has been created.\n"
                fi
                break
                ;;
            "oracle")
                if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "BAW_RUNTIME_DB_USER_NAME"

                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "BAW_RUNTIME_DB_USER_PASSWORD"
                    fi

                    wait_msg "Creating the DB SQL statement file for Business Automation Workflow database instance1 required by BAW"
                    create_bawaws1_db_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                    success "DB SQL statement file for Business Automation Workflow database instance1 required by BAW has been created.\n"

                    tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "AWS_DB_USER_NAME"

                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "AWS_DB_USER_PASSWORD"
                    fi

                    wait_msg "Creating the DB SQL statement file for Business Automation Workflow database instance1 required by BAW"
                    create_bawaws2_db_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                    success "DB SQL statement file for Business Automation Workflow database instance1 required by BAW has been created.\n"
                elif [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "BAW_RUNTIME_DB_USER_NAME"

                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "BAW_RUNTIME_DB_USER_PASSWORD"
                    fi

                    wait_msg "Creating the DB SQL statement file for database required by Business Automation Workflow Runtime"
                    create_bawaws1_db_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                    success "DB SQL statement file for database required by Business Automation Workflow Runtime has been created.\n"

                elif [[ " ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
                    check_dbserver_name_valid "$tmp_dbservername" "AWS_DB_USER_NAME"

                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password "$tmp_dbuserpwd" "AWS_DB_USER_PASSWORD"
                    fi

                    wait_msg "Creating the DB SQL statement file for database required by Business Automation Workflow Runtime"
                    create_bawaws2_db_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                    success "DB SQL statement file for database required by Business Automation Workflow Runtime has been created.\n"

                fi
                break
                ;;
            esac
        done
    fi

    # Generate DB SQL for BAS

    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || ("${pattern_cr_arr[@]}" =~ "workflow-process-service" && $EXTERNAL_DB_WFPS_AUTHORING == "Yes") || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
        wait_msg "Creating the DB SQL statement file for BAS Studio database"
        while true; do
            case "$DB_TYPE" in
            "db2"|"sqlserver"|"postgresql")
                tmp_dbname="$(prop_db_name_user_property_file STUDIO_DB_NAME)"
                tmp_dbuser="$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file STUDIO_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name STUDIO_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "STUDIO_DB_USER_NAME"

                tmp_dbschemaname=""
                if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                    tmp_db_current_schema_name="$(prop_db_name_user_property_file STUDIO_DB_CURRENT_SCHEMA)"
                    tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                    if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschemaname=$tmp_db_current_schema_name
                    fi
                fi

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "STUDIO_DB_USER_PASSWORD"
                fi

                db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_bas_studio_db_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_bas_studio_db_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_dbschemaname"
                elif [[ $DB_TYPE == "db2" ]]; then
                    check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "STUDIO_DB_NAME"
                    # Calling a different function that will take care of creating the db2rds sql file
                    # DBACLD-163779
                    if [[ $IS_RDS == true ]]; then
                        create_bas_studio_db_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname" "$tmp_dbuserpwd"
                    else
                        create_bas_studio_db_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname"                   
                    fi
                    
                fi
                break
                ;;
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file STUDIO_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name STUDIO_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "STUDIO_DB_USER_NAME"

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "STUDIO_DB_USER_PASSWORD"
                fi

                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                create_bas_studio_db_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                break
                ;;
            esac
        done
        success "DB SQL statement file for BAS Studio database has been created.\n"
    fi

    # Generate DB SQL for Application Engine Playback database
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
        wait_msg "Creating the DB SQL statement file for Application Engine Playback database"
        while true; do
            case "$DB_TYPE" in
            "db2"|"sqlserver"|"postgresql")
                tmp_dbname="$(prop_db_name_user_property_file APP_PLAYBACK_DB_NAME)"
                tmp_dbuser="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name APP_PLAYBACK_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "APP_PLAYBACK_DB_USER_NAME"

                tmp_dbschemaname=""
                if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                    tmp_db_current_schema_name="$(prop_db_name_user_property_file APP_PLAYBACK_DB_CURRENT_SCHEMA)"
                    tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                    if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschemaname=$tmp_db_current_schema_name
                    fi
                fi

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "APP_PLAYBACK_DB_USER_PASSWORD"
                fi

                db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_ae_playback_db_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_ae_playback_db_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_dbschemaname"
                elif [[ $DB_TYPE == "db2" ]]; then
                    check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "APP_PLAYBACK_DB_NAME"
                    # Calling a different function that will take care of creating the db2rds sql file
                    # DBACLD-163779
                    if [[ $IS_RDS == true ]]; then
                        create_ae_playback_db_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname" "$tmp_dbuserpwd"
                    else
                        create_ae_playback_db_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname"                   
                    fi
                    
                fi
                break
                ;;
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name APP_PLAYBACK_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "APP_PLAYBACK_DB_USER_NAME"

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "APP_PLAYBACK_DB_USER_PASSWORD"
                fi

                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                create_ae_playback_db_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                break
                ;;
            esac
        done

        success "DB SQL statement file for Application Engine Playback database has been created.\n"
    fi

    # Generate DB SQL for Application Engine database
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "application" ]]; then
        wait_msg "Creating the DB SQL statement file for Application Engine database"
        while true; do
            case "$DB_TYPE" in
            "db2"|"sqlserver"|"postgresql")
                tmp_dbname="$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)"
                tmp_dbuser="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name APP_ENGINE_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "APP_ENGINE_DB_USER_NAME"

                tmp_dbschemaname=""
                if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                    tmp_db_current_schema_name="$(prop_db_name_user_property_file APP_ENGINE_DB_CURRENT_SCHEMA)"
                    tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                    if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            tmp_db_current_schema_name=$(echo "$tmp_db_current_schema_name" | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschemaname=$tmp_db_current_schema_name
                    fi
                fi

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "APP_ENGINE_DB_USER_PASSWORD"
                fi
                # echo "debug"; sleep 3000
                db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_baa_app_engine_db_sqlserver_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_baa_app_engine_db_postgresql_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername" "$tmp_dbschemaname"
                elif [[ $DB_TYPE == "db2" ]]; then
                    check_db2_name_valid "$tmp_dbname" "$tmp_dbservername" "APP_ENGINE_DB_NAME"
                    # Calling a different function that will take care of creating the db2rds sql file
                    # DBACLD-163779
                    if [[ $IS_RDS == true ]]; then
                        create_baa_app_engine_db_db2rds_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname" "$tmp_dbuserpwd"
                    else
                        create_baa_app_engine_db_db2_sql_file "$tmp_dbname" "$tmp_dbuser" "$tmp_dbservername" "$tmp_dbschemaname"                   
                    fi
                    
                fi
                break
                ;;
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name APP_ENGINE_DB_USER_NAME)"
                check_dbserver_name_valid "$tmp_dbservername" "APP_ENGINE_DB_USER_NAME"

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password "$tmp_dbuserpwd" "APP_ENGINE_DB_USER_PASSWORD"
                fi

                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                create_baa_app_engine_db_oracle_sql_file "$tmp_dbuser" "$tmp_dbuserpwd" "$tmp_dbservername"
                break
                ;;
            esac
        done
        # ${SED_COMMAND} "s|\"||g" $BAS_DB_SCRIPT_FOLDER/$DB_TYPE/create_bas_playback_db.sql
        success "DB SQL statement file for Application Engine database has been created.\n"
    fi

    # CLeaning all DB SQL files for any unwanted return characters
    remove_carriage_returns_from_sql_files "${DB_SCRIPT_FOLDER}"
    
    tips ""
    msgB "* The DB SQL statement files for CP4BA are created under directory ${DB_SCRIPT_FOLDER}. You can modify them or use the default setting to create the databases.\n(NOTES: DO NOT CHANGE DBNAME/DBUSER/DBPASSWORD DIRECTLY in the DB SQL statement files. CHANGE THEM IN THE PROPERTY FILES IF NEEDED, AND THEN RUN [-m generate] AGAIN)"

    # Output some additional messages for DPE Postgres files (if applicable)
    if [[ ! -z "$ca_db_pg_flag" && "$ca_db_pg_flag" = true ]]; then
       msgB "* For the DB SQL statement files for Document Processing Engine created under directory ${ADP_DB_SCRIPT_FOLDER}/${DB_TYPE}, please be aware that the filename indicates the user that each script should be run as."
    fi

   # Convert db name/user array to list by common
    delim=""
    db_name_joined=""
    for item in "${db_name_full_array[@]}"; do
        item=$(sed -e 's/^"//' -e 's/"$//' <<<"$item")
        db_name_joined="$db_name_joined$delim$item"
        delim=","
    done

    delim=""
    db_user_joined=""
    for item in "${db_user_full_array[@]}"; do
        item=$(sed -e 's/^"//' -e 's/"$//' <<<"$item")
        db_user_joined="$db_user_joined$delim$item"
        delim=","
    done

    delim=""
    db_user_pwd_joined=""
    for item in "${db_user_pwd_full_array[@]}"; do
        item=$(sed -e 's/^"//' -e 's/"$//' <<<"$item")
        db_user_pwd_joined="$db_user_pwd_joined$delim$item"
        delim=","
    done

    ${SED_COMMAND} '/DB_NAME_LIST/d' ${TEMPORARY_PROPERTY_FILE}
    ${SED_COMMAND} '/DB_USER_LIST/d' ${TEMPORARY_PROPERTY_FILE}
    ${SED_COMMAND} '/DB_USER_PWD_LIST/d' ${TEMPORARY_PROPERTY_FILE}

    echo "DB_NAME_LIST=$db_name_joined" >> ${TEMPORARY_PROPERTY_FILE}
    echo "DB_USER_LIST=$db_user_joined" >> ${TEMPORARY_PROPERTY_FILE}
    echo "DB_USER_PWD_LIST=$db_user_pwd_joined" >> ${TEMPORARY_PROPERTY_FILE}
}

function select_ldap_type_for_wfps_authoring(){
    info "LDAP configuration is not required for the IBM Workflow Process Service Authoring, but if you want to login with LDAP user, please select Yes. If you select No, you can do post actions to add the LDAP connection manually after install. For more information, from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE, navigate to Installing --> Installing Production Deployment --> Installing a CP4BA multi-pattern production deployment --> Completing post-installation tasks --> Cloud Pak for Business Automation Foundation --> Business Automation Studio."
    while true; do
        printf "\x1B[1mDo you want use the LDAP for the IBM Workflow Process Service Authoring? (Yes/No, default: Yes): \x1B[0m"
        read -erp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            LDAP_WFPS_AUTHORING="yes"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            LDAP_WFPS_AUTHORING="no"
            break
            ;;
        *)
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function select_external_postgresdb_for_im_zen(){
    printf "\n"
    echo ""
    while true; do
        #DBACLD-222678: Since there no EDB, we won't ask customer whether they want to use external Postgres DB for IM/Zen.  They must use external Postgres DB if they want to install IM/Zen for 25.0.1-GA
        # Display Knowledge Center link once
        echo "${GREEN_TEXT}PLEASE REFER THE KNOWLEDGE CENTER: https://www.ibm.com/docs/en/cloud-paks/foundational-services/$CS_CHANNEL_KC?topic=im-setting-up-external-edb-postgresql-database-server#dbcreate${RESET_TEXT}"
        
        if skip_edb; then
            printf "\x1B[1mFor this ${VERSION_TO_SKIP_EDB} version, you must use an external Postgres DB \x1B[0m[${RED_TEXT}YOU NEED TO CREATE THE POSTGRESQL DBs BY YOURSELF FIRST BEFORE APPLYING THE CP4BA CUSTOM RESOURCE${RESET_TEXT}] \x1B[1mfor IM and Zen services in this CP4BA deployment.\x1B[0m"
            printf "\n"
            EXTERNAL_POSTGRESDB_FOR_IM="true"
            EXTERNAL_POSTGRESDB_FOR_ZEN="true"
            break
        else
            printf "\x1B[1mDo you want to use an external Postgres DB for IM and Zen in this CP4BA deployment?\x1B[0m (Yes/No, default: No): "
            printf "\n"
            printf "[${YELLOW_TEXT}NOTE${RESET_TEXT}: YOU WILL NEED TO CREATE THE POSTGRESQL DBs BY YOURSELF FIRST BEFORE APPLYING THE CP4BA CUSTOM RESOURCE]\n"
            read -erp "" ans

            ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')

            case "$ans" in
            "y"|"yes")
                EXTERNAL_POSTGRESDB_FOR_IM="true"
                EXTERNAL_POSTGRESDB_FOR_ZEN="true"
                break
                ;;
            "n"|"no"|"")
                EXTERNAL_POSTGRESDB_FOR_IM="false"
                EXTERNAL_POSTGRESDB_FOR_ZEN="false"
                break
                ;;
            *)
                printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        fi
    done
}

function select_external_postgresdb_for_bts(){
    printf "\n"
    echo ""
    while true; do
        #DBACLD-194974: Since there no EDB, we won't ask customer whether they want to use external Postgres DB for BTS.  They must use external Postgres DB if they want to install BTS with 25.0.1-GA
        echo "${GREEN_TEXT}PLEASE REFER THE KNOWLEDGE CENTER: https://www.ibm.com/docs/en/cloud-paks/foundational-services/$CS_CHANNEL_KC?topic=service-external-database#configuring-an-external-database-with-the-bts-custom-resource${RESET_TEXT}"
        if skip_edb; then
            printf "\x1B[1mFor this ${VERSION_TO_SKIP_EDB} version, you must use an external Postgres DB \x1B[0m[${RED_TEXT}YOU NEED TO CREATE THE POSTGRESQL DBs BY YOURSELF FIRST BEFORE APPLYING THE CP4BA CUSTOM RESOURCE${RESET_TEXT}] \x1B[1m for BTS service in this CP4BA deployment.\x1B[0m"
            printf "\n"
            EXTERNAL_POSTGRESDB_FOR_BTS="true"
            break
        else
            printf "\x1B[1mDo you want to use an external Postgres DB for BTS in this CP4BA deployment?\x1B[0m (Yes/No, default: No): "
            printf "\n"
            printf "[${YELLOW_TEXT}NOTE${RESET_TEXT}: YOU WILL NEED TO CREATE THIS POSTGRESQL DB BY YOURSELF FIRST BEFORE APPLYING THE CP4BA CUSTOM RESOURCE]\n"
            read -erp "" ans
            ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
            case "$ans" in
            "y"|"yes")
                EXTERNAL_POSTGRESDB_FOR_BTS="true"
                break
                ;;
            "n"|"no"|"")
                EXTERNAL_POSTGRESDB_FOR_BTS="false"
                break
                ;;
            *)
                printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        fi

    done
}

function select_external_postgresdb_for_adpgg_dicmis(){
    printf "\n"
    echo ""
    while true; do
        if skip_edb; then
            printf "\x1B[1mFor this ${VERSION_TO_SKIP_EDB} version, you must use an external Postgres DB \x1B[0m[${RED_TEXT}YOU NEED TO CREATE THE POSTGRESQL DBs BY YOURSELF FIRST BEFORE APPLYING THE CP4BA CUSTOM RESOURCE${RESET_TEXT}] \x1B[1m for ADPGG and DICMS in this CP4BA deployment.\x1B[0m"
            printf "\n"
            EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS="true"
            break
        else
            printf "\x1B[1mDo you want to use an external Postgres DB for ADPGG and DICMS in this CP4BA deployment?\x1B[0m\n"
            printf "[${YELLOW_TEXT}NOTE${RESET_TEXT}: IF YES, DB SCRIPTS WILL BE AUTO-GENERATED. YOU WILL NEED TO CREATE THE POSTGRESQL DBs USING THESE SCRIPTS BEFORE APPLYING THE CP4BA CUSTOM RESOURCE. IF NO (DEFAULT), CNPG (CloudNativePG) WILL BE USED FOR ADPGG AND DICMS.]\n"
            read -erp "Enter your choice (Yes for external PG/No for CNPG, default: No): " ans
            ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
            case "$ans" in
            "y"|"yes")
                EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS="true"
                break
                ;;
            "n"|"no"|"")
                EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS="false"
                break
                ;;
            *)
                printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        fi

    done
}

function select_external_cert_opensearch_kafka(){
    printf "\n"
    echo ""
    while true; do
        printf "\x1B[1mDo you want to use an external certificate (root CA) for this Opensearch/Kafka deployment?\x1B[0m ${YELLOW_TEXT}(Notes: Opensearch/Kafka operator can consume external tls certificate. If select \"No\", CP4BA operator will create leaf certificates based on CP4BA's root CA )${RESET_TEXT} (Yes/No, default: No): "
        read -erp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            EXTERNAL_CERT_OPENSEARCH_KAFKA="true"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            EXTERNAL_CERT_OPENSEARCH_KAFKA="false"
            break
            ;;
        *)
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}


function generate_sample_network_policies(){
    printf "\n"
    echo ""
    while true; do
        printf "\x1B[1mDo you want to generate the network policy templates for this CP4BA deployment?\x1B[0m ${YELLOW_TEXT}(Notes: Starting from 25.0.0, the CP4BA operators no longer install network policies automatically. If you want the operators to generate network policies from a set of templates, select Yes. You can install the network policies by running a script after the CP4BA Deployment is installed. If you select No, then no network policies will be generated.)${RESET_TEXT} (Yes/No, default: No):" 
        read -erp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            GENERATE_SAMPLE_NETWORK_POLICIES="true"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            GENERATE_SAMPLE_NETWORK_POLICIES="false"
            break
            ;;
        *)
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function ask_to_setup_content_cortex_ai_services(){
    # Display architecture warning only once using a flag
    if [[ -z "$AI_SERVICES_ARCH_WARNING_SHOWN" ]]; then
        printf "\n"
        echo "${YELLOW_TEXT}[IMPORTANT] Content Cortex AI Services deployment requires an x86/amd64 architecture environment.${RESET_TEXT}"
        echo ""
        export AI_SERVICES_ARCH_WARNING_SHOWN="true"
    fi
    
    printf "\n"
    while true; do
        printf "\x1B[1mDo you want to deploy Content Cortex AI Services as a part of the Content Cortex Essentials?\x1B[0m (Yes/No, default: No): "
        read -erp "" ans
        ans="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"
        case "$ans" in
        "y"|"yes")
            SETUP_CONTENT_CORTEX_AI_SERVICES="true"
            break
            ;;
        "n"|"no"|"")
            SETUP_CONTENT_CORTEX_AI_SERVICES="false"
            break
            ;;
        *)
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function enable_instana_monitoring(){
    printf "\n"
    echo ""
    while true; do
        printf "\x1B[1mDo you want to enable the Instana Monitoring for this CP4BA deployment?\x1B[0m ${YELLOW_TEXT}(Notes: If you want the operators to enable the Instana monitoring for this cp4ba deployment, select Yes.)${RESET_TEXT} (Yes/No, default: No):" 
        read -erp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            ENABLE_INSTANA_MONITORING="true"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            ENABLE_INSTANA_MONITORING="false"
            break
            ;;
        *)
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
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
            isProjExists=`${CLI_CMD} get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l`  >&3 2>&3

            if [ "$isProjExists" -ne 2 ] ; then
                printf '%b\n' "\x1B[1;31mInvalid project name, please enter a existing project name ...\x1B[0m"
                TARGET_PROJECT_NAME=""
            else
                printf '%b\n' "\x1B[1mUsing project ${TARGET_PROJECT_NAME}...\x1B[0m"
            fi
        fi
    done
}

function select_fips_enable(){
    if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS" ]]; then
        CLI_CMD=oc
    elif [[ "$PLATFORM_SELECTED" == "other" ]]
    then
        CLI_CMD=kubectl
    fi
    select_project
    all_fips_enabled_flag=$(${CLI_CMD} get configmap cp4ba-fips-status --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath={.data.all-fips-enabled})
    if [ -z $all_fips_enabled_flag ]; then
        FIPS_ENABLED="false"
        info "Configmap \"cp4ba-fips-status\" not found in the project \"$CP4BA_SERVICES_NS\". setting \"shared_configuration.enable_fips\" as \"false\" by default in the final custom resource."
    elif [[ "$all_fips_enabled_flag" == "Yes" ]]; then
        printf "\n"
        while true; do
            printf "\x1B[1mYour OCP cluster has FIPS enabled, do you want to enable FIPS with this CP4BA deployment？\x1B[0m${YELLOW_TEXT} (Notes: If you select \"Yes\", in order to complete enablement of FIPS for CP4BA, please refer to \"FIPS wall\" configuration in IBM documentation.)${RESET_TEXT} (Yes/No, default: No): "
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
    options=("Microsoft Active Directory" "IBM Tivoli Directory Server / Security Directory Server" "PingDirectory Server" "External IDP (no LDAP)")
    PS3='Enter a valid option [1 to 4]: '
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
            "External IDP (no LDAP)")
                LDAP_TYPE="EXTERNAL_IDP"
                printf '%b\n' "\x1B[1;33m[NOTE]: \x1B[0mExternal IDP selected. LDAP configuration will be skipped during the prerequisites flow and will not be included in the generated CR. You must provide the required External IDP details directly in the CR after running the deployment script.\x1B[0m"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    if [[ "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then
        msgRed "You can change the parameter \"LDAP_SSL_ENABLED\" in the property file \"$LDAP_PROPERTY_FILE\" later. \"LDAP_SSL_ENABLED\" is \"TRUE\" by default."
    fi
}

function select_wfa_deployment_type(){
    printf "\n"
    printf "\x1B[1mSelect the WatsonX.ai deployment type for Workplace Assistant and/or Workflow Authoring Assistant:\x1B[0m\n"
    printf "\n"
    printf "  1) IBM SaaS (IBM Cloud)\n"
    printf "  2) Lightweight Engine (LWE)\n"
    printf "\n"
    while true; do
        printf "Enter a valid option [1 to 2, default: 1]: "
        read -erp "" ans
        case "$ans" in
            "1"|"")
                WFA_WATSONX_DEPLOYMENT_TYPE="SaaS"
                info "Selected: IBM SaaS deployment"
                break
                ;;
            "2")
                WFA_WATSONX_DEPLOYMENT_TYPE="LWE"
                info "Selected: Lightweight Engine (LWE) deployment"
                break
                ;;
            *)
                echo "Invalid option \"$ans\". Please enter 1 or 2."
                ;;
        esac
    done
}

function select_profile_type(){
    printf "\n"
    COLUMNS=12
    printf '%b\n' "\x1B[1mPlease select the deployment profile (default: small).  Refer to the documentation in CP4BA Knowledge Center for details on profile.\x1B[0m"
    options=("small" "medium" "large")
    if [ -z "$existing_profile_type" ]; then
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

function select_db_type(){
    printf "\n"
    COLUMNS=12
    printf '%b\n' "\x1B[1mWhat is the Database type that is used for this deployment? \x1B[0m"
    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        ## -- https://jsw.ibm.com/browse/DBACLD-170077 <updating the name of the DB type of PostgreSQL>
        options=("IBM Db2 Database" "IBM Db2 HADR" "Amazon RDS for Db2" "Amazon RDS for Db2 HADR" "External PostgreSQL" "IBM Cloud Native Postgres (deployed by the CP4BA Operator)")
        PS3='Enter a valid option [1 to 6]: '
        # else
        #     options=("IBM Db2 Database" "PostgreSQL")
        #     PS3='Enter a valid option [1 to 2]: '
        # fi
    elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-process-service" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("External PostgreSQL" "IBM Cloud Native Postgres (deployed by the CP4BA Operator)")
        PS3='Enter a valid option [1 to 2]: '
        # else
        #     options=("PostgreSQL")
        #     PS3='Enter a valid option [1 to 1]: '
        # fi
    elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-process-service" && " ${PATTERNS_CR_SELECTED[@]} " =~ "decisions" && "${#PATTERNS_CR_SELECTED[@]}" -eq "2" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("External PostgreSQL" "IBM Cloud Native Postgres (deployed by the CP4BA Operator)")
        PS3='Enter a valid option [1 to 2]: '
        # else
        #     options=("PostgreSQL")
        #     PS3='Enter a valid option [1 to 1]: '
        # fi
    elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-process-service" && " ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "2" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("External PostgreSQL" "IBM Cloud Native Postgres (deployed by the CP4BA Operator)")
        PS3='Enter a valid option [1 to 2]: '
        # else
        #     options=("PostgreSQL")
        #     PS3='Enter a valid option [1 to 1]: '
        # fi
    elif [[ ("${PATTERNS_CR_SELECTED[@]}" =~ "workflow-authoring" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer") && " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-process-service" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("IBM Db2 Database" "IBM Db2 HADR" "Amazon RDS for Db2" "Amazon RDS for Db2 HADR" "Oracle" "Microsoft SQL Server" "External PostgreSQL" "IBM Cloud Native Postgres (deployed by the CP4BA Operator)")
        PS3='Enter a valid option [1 to 8]: '
        # else
        #     options=("IBM Db2 Database" "Oracle" "Microsoft SQL Server" "PostgreSQL")
        #     PS3='Enter a valid option [1 to 4]: '
        # fi
    elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-process-service" && " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-runtime" && "${#PATTERNS_CR_SELECTED[@]}" -eq "3" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("External PostgreSQL" "IBM Cloud Native Postgres (deployed by the CP4BA Operator)")
        PS3='Enter a valid option [1 to 2]: '
        # else
        #     options=("PostgreSQL")
        #     PS3='Enter a valid option [1 to 1]: '
        # fi
    else
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("IBM Db2 Database" "IBM Db2 HADR" "Amazon RDS for Db2" "Amazon RDS for Db2 HADR" "Oracle" "Microsoft SQL Server" "External PostgreSQL" "IBM Cloud Native Postgres (deployed by the CP4BA Operator)")
        PS3='Enter a valid option [1 to 8]: '
        # else
        #     options=("IBM Db2 Database" "Oracle" "Microsoft SQL Server" "PostgreSQL")
        #     PS3='Enter a valid option [1 to 4]: '
        # fi
    fi

    #DBACLD-194974: Remove the "IBM Cloud Native Postgres (deployed by the CP4BA Operator)" option out of options when skip_edb returns 0
    if skip_edb; then
        # DBACDL-226283: Remove all the database options except "External PostgreSQL" for all patterns.
        #DBACLD-231157: Allow other DB-types such as DB2, Oracle, external PG, MSSQL except for EDB
        new_options_2=()
        for option in "${options[@]}"; do
            if [[ "$option" != "IBM Cloud Native Postgres (deployed by the CP4BA Operator)" ]]; then
                new_options_2+=("$option")
            fi
        done
        # info "\x1B[1m${YELLOW_TEXT}NOTE: Please be aware that for this ${VERSION_TO_SKIP_EDB} version, only external Postgres is supported. Other database types will be supported in the upcoming iFix and next release.\x1B[0m${RESET_TEXT}"
        
        options=("${new_options_2[@]}")
        PS3="Enter a valid option [1 to ${#options[@]}]: "
    fi

    select opt in "${options[@]}"
    do
        case $opt in
            "IBM Db2 Database")
                DB_TYPE="db2"
                break
                ;;
            "IBM Db2 HADR")
                DB_TYPE="db2hadr"
                break
                ;;
            "Amazon RDS for Db2")
                DB_TYPE="db2rds"
                break
                ;;
            "Amazon RDS for Db2 HADR")
                DB_TYPE="db2rdshadr"
                break
                ;;
            "Oracle")
                DB_TYPE="oracle"
                break
                ;;
            "Microsoft SQL Server")
                DB_TYPE="sqlserver"
                break
                ;;
            "External PostgreSQL")
                DB_TYPE="postgresql"
                break
                ;;
            "IBM Cloud Native Postgres (deployed by the CP4BA Operator)")
                DB_TYPE="postgresql-edb"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    # Ask user if they want to use external PostgreSQL for ADPGG/DICMS when using non-PostgreSQL databases
    # Only ask when document_processing or decisions patterns are selected (these patterns require PostgreSQL for ADPGG/DICMS)
    if [[ ($DB_TYPE == "db2" || $DB_TYPE == "db2hadr" || $DB_TYPE == "db2rds" || $DB_TYPE == "db2rdshadr" || $DB_TYPE == "oracle" || $DB_TYPE == "sqlserver") && (" ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing" || " ${PATTERNS_CR_SELECTED[@]} " =~ "decisions") ]]; then
        select_external_postgresdb_for_adpgg_dicmis
    fi

    if [[ $DB_TYPE != "postgresql-edb" ]]; then
        msgRed "You can change the parameter \"DATABASE_SSL_ENABLE\" in the property file \"$DB_SERVER_INFO_PROPERTY_FILE\" later. \"DATABASE_SSL_ENABLE\" is \"TRUE\" by default."
    fi

    if [[ $DB_TYPE == "postgresql" ]]; then
        msgRed "You can change the parameter \"POSTGRESQL_SSL_CLIENT_SERVER\" in the property file \"$DB_SERVER_INFO_PROPERTY_FILE\" later. \"POSTGRESQL_SSL_CLIENT_SERVER\" is \"TRUE\" by default"
        msgRed "- POSTGRESQL_SSL_CLIENT_SERVER=\"True\": For a PostgreSQL database with both server and client authentication"
        msgRed "- POSTGRESQL_SSL_CLIENT_SERVER=\"False\": For a PostgreSQL database with server-only authentication"
        msgRed "- When both DATABASE_SSL_ENABLE and POSTGRESQL_SSL_CLIENT_SERVER properties are set to \"TRUE\" this means client certificate authentication is enabled. You should not specify any PostgreSQL DB passwords in the $DB_NAME_USER_PROPERTY_FILE"
    fi
}


function set_external_ldap(){
    printf "\n"

    while true; do
        printf "\x1B[1mWill an external LDAP be used as part of the configuration?: \x1B[0m"

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
            read -rp "" nodelabel_key
            if [ -z "$nodelabel_key" ]; then
            printf '%b\n' "\x1B[1;31mEnter the node label key.\x1B[0m"
            fi
        done

        printf "\n"
        printf "\x1B[1mWhat is the node label value used to identify the GPU worker node(s)? \x1B[0m"
        nodelabel_value=""
        while [[ $nodelabel_value == "" ]];
        do
            read -rp "" nodelabel_value
            if [ -z "$nodelabel_value" ]; then
            printf '%b\n' "\x1B[1;31mEnter the node label value.\x1B[0m"
            fi
        done
    fi
}

function select_ae_data_persistence(){
    if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence" ]]; then
        # In the scenario of updating components, the EXISTING_OPT_COMPONENT_ARR array could have ae_data_persistence, but if the user decides to remove BAA(application) pattern,the script will still add ae_data_persistence as an optional component.
        # Instead we can add another check where we see if application was selected. If it was deselected we can skip adding AE and if it was kept or added the script will accordingly keep AE
        if [[ (" ${PATTERNS_CR_SELECTED[@]} " =~ "application") ]]; then
            foundation_component_arr=( "${foundation_component_arr[@]}" "AE" )
            AE_DATA_PERSISTENCE_ENABLE="Yes"
        fi
    else
        if [[ (" ${PATTERNS_CR_SELECTED[@]} " =~ "application") ]]; then
            printf "\n"
            while true; do
                printf "\x1B[1mDo you want to enable Business Automation Application Data Persistence? (Yes/No, default: No): \x1B[0m"
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
    # FOUNDATION_CR_SELECTED_LOWCASE=( "${FOUNDATION_CR_SELECTED[@],}" )

    x=0;while [ ${x} -lt ${#FOUNDATION_CR_SELECTED[*]} ] ; do FOUNDATION_CR_SELECTED_LOWCASE[$x]=$(tr [A-Z] [a-z] <<< ${FOUNDATION_CR_SELECTED[$x]}); let x++; done
    FOUNDATION_DELETE_LIST=($(echo "${FOUNDATION_CR_SELECTED[@]}" "${FOUNDATION_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))

    PATTERNS_CR_SELECTED=($(echo "${pattern_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

function input_information(){
    EXISTING_OPT_COMPONENT_ARR=()
    EXISTING_PATTERN_ARR=()
    # rm -rf $TEMPORARY_PROPERTY_FILE >/dev/null 2>&1
    if [[ "${INSTALL_BAW_ONLY}" == "No" ]];
    then
        DEPLOYMENT_TYPE="production"
        PLATFORM_SELECTED="OCP"
        select_pattern
    else
        select_baw_only
    fi
    select_optional_component
    # Ask WatsonX deployment type for workflow_assistant or workplace_assistant after optional component selection
    if [[ "${optional_component_cr_arr[@]}" =~ "workflow_assistant" || "${optional_component_cr_arr[@]}" =~ "workplace_assistant" ]]; then
        select_wfa_deployment_type
    fi
    # whether wfps authoring require LDAP
    if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" ]]; then
        select_ldap_type_for_wfps_authoring
    fi

    if [[ -z $LDAP_WFPS_AUTHORING || $LDAP_WFPS_AUTHORING == "yes" ]]; then
        select_ldap_type
    fi
    select_storage_class
    select_profile_type

    if [[ -z $EXTERNAL_DB_WFPS_AUTHORING || $EXTERNAL_DB_WFPS_AUTHORING == "Yes" ]]; then
        select_db_type
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            get_db_server_list
        else
            db_server_array=("postgresql-edb")
            db_server_number=${#db_server_array[@]}
        fi
    else
        db_server_number=0
    fi

    if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]]; then
        select_fips_enable
    fi
    
    if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]]; then
        # DBACLD-185209: Vault implementation.  Ask if user want to enable Vault integration
        if [[ "$ENABLE_VAULT_ON_EXIST" == "true" ]]; then
            # if in "--enable-external-secret-management" mode, then no need to ask user if they want to enable vault integration
            info "You are running with '--enable-external-secret-management' flag, so it is assumed you want to enable external secret management with Vault."
            info "IMPORTANT: Vault integration requires prerequisites steps. If you have not yet done so, please ensure you have followed the instructions in the CP4BA Knowledge Center topic 'Optional: Preparing for external secret management'"
            info "IMPORTANT: If you do not want to enable external secret management integration, please run the script WITHOUT the '--enable-external-secret-management' flag."
            VAULT_ENABLED="true"
        else
            # if not in "--enable-external-secret-management" then ask user if they want to enable vault integration
            ask_enable_vault
        fi 

        generate_sample_network_policies
        enable_instana_monitoring
	
        
        #DBACLD-194974: Combine IM/Zen question for ext. PG.  Ask regardless of DB_TYPE 
        #DBACLD-222678: We need to ask the question about PG for IM/Zen for all the DB types instead of only when external PostgreSQL is selected, as even for non-PostgreSQL DB types, users may still want to use external PostgreSQL for IM/Zen if they want to have a separate DB for IM/Zen other than the main DB for other CP4BA components.
        # The scenarios where external Postgres can be used for CPFS is
        # CP4BA and CPFS use CNPG
        # CP4BA uses external Postgres and CPFS uses CNPG
        # CP4BA uses external Postgres and CPFS uses external Postgres
        # CP4BA uses a non Postgres flavor DB type (DB2 , Oracle , MSSQL ) and CPFS uses CNPG     
        
        ### <https://jsw.ibm.com/browse/DBACLD-251522> - Since now we support CNPG from 26.0.0-IF001, We  prompt the user to ask if they want to use external PostgreSQL for Zen and IM only when external PostgreSQL is selected for CP4BA.
        if [[ $DB_TYPE == "postgresql" ]]; then
            select_external_postgresdb_for_im_zen
        else
            EXTERNAL_POSTGRESDB_FOR_IM="false"
            EXTERNAL_POSTGRESDB_FOR_ZEN="false"
        fi

        # Create Secret/configMap for BTS metastore external Postgres DB
        containsElement "decisions_ads" "${pattern_cr_arr[@]}"
        ads_Val=$?

        if [[ $ads_Val -eq 0 || " ${pattern_cr_arr[@]} " =~ "workflow-authoring" || " ${pattern_cr_arr[@]} " =~ "document_processing" || " ${pattern_cr_arr[@]} " =~ "application" || " ${optional_component_cr_arr[@]} " =~ "bai" ]]; then
                #DBACLD-194974: Combine IM/Zen question for ext. PG.  Ask regardless of DB_TYPE 

            # The scenarios where external Postgres can be used for CPFS is
            # CP4BA and CPFS use CNPG
            # CP4BA uses external Postgres and CPFS uses CNPG
            # CP4BA uses external Postgres and CPFS uses external Postgres
            # CP4BA uses a non Postgres flavor DB type (DB2 , Oracle , MSSQL ) and CPFS uses CNPG
            ### <https://jsw.ibm.com/browse/DBACLD-251522> - Since now we support CNPG from 26.0.0-IF001, We only prompt the user to ask if they want to use external PostgreSQL for BTS when external PostgreSQL is selected.
            if [[ $DB_TYPE == "postgresql" ]]; then
                select_external_postgresdb_for_bts
            else
                EXTERNAL_POSTGRESDB_FOR_BTS="false"
            fi

            if [[ " ${pattern_cr_arr[@]} " =~ "workflow-authoring" || " ${pattern_cr_arr[@]} " =~ "workflow-runtime" || " ${optional_component_cr_arr[@]} " =~ "bai" ]]; then
                select_external_cert_opensearch_kafka
            fi
        fi
    fi

    # select_db_server_number
    if [[ " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        select_objectstore_number
    fi

    select_cpe_full_storage
    containsElement "document_processing_designer" "${pattern_cr_arr[@]}"
    retVal=$?
    if [[ ( $retVal -eq 0 ) && "$DEPLOYMENT_TYPE" == "production" ]]; then
        select_gpu_document_processing
    fi

    containsElement "document_processing" "${pattern_cr_arr[@]}"
    retVal=$?
    if [[ ( $retVal -eq 0 ) && "$DEPLOYMENT_TYPE" == "starter" ]]; then
        select_gpu_document_processing
    fi

    # Ask if they wish to setup Content Cortex AI Services Operator
    #if [[ " ${pattern_cr_arr[@]}" =~ "content" ]]; then
    # At this point in time of the script execution, the script does not add dependant patterns when a certain pattern is selected.
    # These are the patterns that require content and these are the same patterns for which we check when we add the FNCM LICENSE property to the user property file
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        ask_to_setup_content_cortex_ai_services
        
        # If AI Services is enabled, prompt for provider selection now
        # Property file will be generated later with other property files
        #set -x
        if [[ "$SETUP_CONTENT_CORTEX_AI_SERVICES" == "true" ]]; then
            source ${CUR_DIR}/cp4a-content-cortex-ai-services-setup.sh
            
            # Set namespace for AI services setup
            NAMESPACE="$TARGET_PROJECT_NAME"
            
            # Initialize context for multi-provider setup
            #initialize_mode_runner_context
            
            # Prompt for provider selection using multi-select interface
            prompt_provider_types_multiselect
        fi
    fi

    create_temp_property_file
}

function select_objectstore_number(){
    content_os_number=""
    while true; do
        printf "\n"
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
            info "One default Content Cortex object store \"DEVOS1\" is added into property file. You could add more custom object store for ADP/Content pattern."
        fi

        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" && (! " ${pattern_cr_arr[@]}" =~ "content") ]]; then
            printf "\x1B[1mHow many additional object stores will be deployed for the document processing pattern? \x1B[0m"
        elif [[ " ${pattern_cr_arr[@]}" =~ "content" && (! " ${pattern_cr_arr[@]}" =~ "document_processing") ]]; then
            printf "\x1B[1mHow many object stores will be deployed for the Content Cortex deployment pattern? \x1B[0m"
        elif [[ " ${pattern_cr_arr[@]}" =~ "document_processing" && " ${pattern_cr_arr[@]}" =~ "content" ]]; then
            printf "\x1B[1mHow many object stores will be deployed for the Content Cortex deployment pattern and how many additional object stores will be deployed for the document processing pattern? \x1B[0m"
        fi

        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" && (! " ${pattern_cr_arr[@]}" =~ "content") ]]; then
            read -rp "" content_os_number
            [[ $content_os_number =~ ^[0-9]+$ ]] || { printf '%b\n' "\x1B[1;31mEnter a valid number [0 to 10]\x1B[0m"; continue; }
            if [ "$content_os_number" -ge 0 ] && [ "$content_os_number" -le 10 ]; then
                break
            else
                printf '%b\n' "\x1B[1;31mEnter a valid number [0 to 10]\x1B[0m"
                content_os_number=""
            fi
        elif [[ " ${pattern_cr_arr[@]}" =~ "document_processing" && " ${pattern_cr_arr[@]}" =~ "content" ]]; then
            read -rp "" content_os_number
            [[ $content_os_number =~ ^[0-9]+$ ]] || { printf '%b\n' "\x1B[1;31mEnter a valid number [1 to 10]\x1B[0m"; continue; }
            if [ "$content_os_number" -ge 1 ] && [ "$content_os_number" -le 10 ]; then
                break
            else
                printf '%b\n' "\x1B[1;31mEnter a valid number [1 to 10]\x1B[0m"
                content_os_number=""
            fi
        elif [[ " ${pattern_cr_arr[@]}" =~ "content" && (! " ${pattern_cr_arr[@]}" =~ "document_processing") ]]; then
            read -rp "" content_os_number
            [[ $content_os_number =~ ^[0-9]+$ ]] || { printf '%b\n' "\x1B[1;31mEnter a valid number [1 to 10]\x1B[0m"; continue; }
            if [ "$content_os_number" -ge 1 ] && [ "$content_os_number" -le 10 ]; then
                break
            else
                printf '%b\n' "\x1B[1;31mEnter a valid number [1 to 10]\x1B[0m"
                content_os_number=""
            fi
        fi
    done
}

function select_db_server_number(){
    db_server_number=""
    while true; do
        printf "\n"
        printf "\x1B[1mHow many database servers or instances will be used for the CP4BA deployment? \x1B[0m"
        read -rp "" db_server_number
        [[ $db_server_number =~ ^[0-9]+$ ]] || { printf '%b\n' "\x1B[1;31mEnter a valid number [1 to 999]\x1B[0m"; continue; }
        if [ "$db_server_number" -ge 1 ] && [ "$db_server_number" -le 999 ]; then
            break
        else
            printf '%b\n' "\x1B[1;31mEnter a valid number [1 to 999]\x1B[0m"
            db_server_number=""
        fi
    done
}

function get_db_server_list(){
    local db_server_list_input=""
    while true; do
        printf "\n"
        printf "\x1B[1mEnter the alias name(s) for the database server(s)/instance(s) to be used by the CP4BA deployment.\x1B[0m\n"
        printf '%b\n' "\x1B[1;31m(NOTE: NOT the host name of the database server, and CANNOT include a dot[.] character)\x1B[0m"
        printf '%b\n' "\x1B[1;31m(NOTE: This key supports comma-separated lists (for example: dbserver1,dbserver2,dbserver3)\x1B[0m"
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
            printf '%b\n' "\x1B[1;31m(NOTE: IBM Automation Document Processing only supports 1 database server. For Automation Document processing, only the first database server in the list is used.)\x1B[0m"
        fi
        read -erp "The alias name(s): " db_server_list_input
        value_empty=`echo "${db_server_list_input}" | grep '\.' | wc -l`  >/dev/null 2>&1
        if [ $value_empty -ne 0 ] ; then
            error "Found dot character(.) in your input value. Please do not contain dot character(.)!"
            db_server_list_input=""
        else
            if [ -z $db_server_list_input ]; then
                error "Please input valid value."
                db_server_list_input=""
            else
                break
            fi
        fi
    done

    # get db alias server from db_server_list_input
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$db_server_list_input"
    IFS=$OIFS

    db_server_number=${#db_server_array[@]}
}



function validate_prerequisites(){
    # DBACLD-202948: remove -Dsemeru.fips option from all java commands for connection verification
    # DBACLD-185209: Check for Vault enable flag
    vault_enabled="$(prop_user_profile_property_file CP4BA.ENABLE_EXTERNAL_VAULT_INTEGRATION | tr '[:upper:]' '[:lower:]')"
    vault_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$vault_enabled")

    # Set default values if variables are not set (DBACLD-170075 Allow customers to customize the country and language being passed to the jar files being used for validation in cp4a-prerequisites.sh)
    CP4BA_AUTO_LANGUAGE=${CP4BA_AUTO_LANGUAGE:-"EN"}
    CP4BA_AUTO_REGION=${CP4BA_AUTO_REGION:-"US"} #bug-170075

    # Validate that both values are exactly two characters long
    if [[ ${#CP4BA_AUTO_LANGUAGE} -ne 2 || ${#CP4BA_AUTO_REGION} -ne 2 ]]; then
        echo "Error: CP4BA_AUTO_LANGUAGE and CP4BA_AUTO_REGION must each be exactly 2 characters long."
        exit 1
    fi

    # validate the storage class
    # skip validating storage class if we are only enabling vault
    if [[ "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
        INFO "Checking Slow/Medium/Fast/Block storage class required by CP4BA"
        tmp_storage_classname=$(prop_user_profile_property_file CP4BA.SLOW_FILE_STORAGE_CLASSNAME)
        sample_pvc_name="cp4ba-test-slow-pvc-$RANDOM"
        verify_storage_class_valid $tmp_storage_classname "ReadWriteMany" $sample_pvc_name

        tmp_storage_classname=$(prop_user_profile_property_file CP4BA.MEDIUM_FILE_STORAGE_CLASSNAME)
        sample_pvc_name="cp4ba-test-medium-pvc-$RANDOM"
        verify_storage_class_valid $tmp_storage_classname "ReadWriteMany" $sample_pvc_name

        tmp_storage_classname=$(prop_user_profile_property_file CP4BA.FAST_FILE_STORAGE_CLASSNAME)
        sample_pvc_name="cp4ba-test-fase-pvc-$RANDOM"
        verify_storage_class_valid $tmp_storage_classname "ReadWriteMany" $sample_pvc_name

        tmp_storage_classname=$(prop_user_profile_property_file CP4BA.BLOCK_STORAGE_CLASS_NAME)
        sample_pvc_name="cp4ba-test-block-pvc-$RANDOM"
        verify_storage_class_valid $tmp_storage_classname "ReadWriteOnce" $sample_pvc_name

        if [[ $verification_sc_passed == "No" ]]; then
            ${CLI_CMD} delete pvc -l cp4ba=test-only >&3 2>&3
            exit 0
        fi
    fi

    # Validate Secret for CP4BA
    validate_secret_in_cluster

    # DBACLD-239908 the cp4a-operator pod name variable was not defined for the case where only WFPS pattern is selected without LDAP
    cp4a_operator=$( $CLI_CMD get pods -l name=ibm-cp4a-operator --no-headers --ignore-not-found -n $cp4ba_operators_namespace | awk '{print $1}' )        

    # Validate LDAP connection for CP4BA (skip for External IDP — no LDAP is configured)
    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "no") && "$LDAP_TYPE" != "EXTERNAL_IDP" ]]; then
        INFO "Checking LDAP connection required by CP4BA"
        tmp_servername="$(prop_ldap_property_file LDAP_SERVER)"
        tmp_serverport="$(prop_ldap_property_file LDAP_PORT)"
        tmp_basdn="$(prop_ldap_property_file LDAP_BASE_DN)"
        tmp_ldapssl="$(prop_ldap_property_file LDAP_SSL_ENABLED)"
        
        #DBACLD-185209: Vault implementation
        ## <https://jsw.ibm.com/browse/DBACLD-172803> - We are now asking user to use {xor} for special characters in password, so we need to use decode_xor_password to get the password decoded before validation.
        if [[ "$vault_enabled" == 'true' ]]; then
            #Read the secret inside cp4ba_operator pod locate at /tmp/secret/ldap-bind-secret/
            tmp_user=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ldap-bind-secret/ldapUsername 2>/dev/null )
            check_vault_secret_value "$tmp_user" "ldap-bind-secret" "ldapUsername" "$cp4a_operator"
            tmp_userpwd=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ldap-bind-secret/ldapPassword 2>/dev/null )
            check_vault_secret_value "$tmp_userpwd" "ldap-bind-secret" "ldapPassword" "$cp4a_operator"
        else #Non-Vault
            tmp_user=$($CLI_CMD get secret -n "$CP4BA_SERVICES_NS" -l name=ldap-bind-secret -o jsonpath='{.items[0].data.ldapUsername}' | ${BASE64_DECODE})
            tmp_userpwd=$($CLI_CMD get secret -n "$CP4BA_SERVICES_NS" -l name=ldap-bind-secret -o jsonpath='{.items[0].data.ldapPassword}' | ${BASE64_DECODE})
            if [[ "$tmp_userpwd" =~ "{xor}" ]]; then
                tmp_userpwd=$(decode_xor_password $tmp_userpwd $cp4ba_operators_namespace $cp4a_operator)
            fi

        fi

        tmp_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_servername")
        tmp_serverport=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_serverport")
        tmp_basdn=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_basdn")
        tmp_ldapssl=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldapssl")
        tmp_ldapssl=$(echo "$tmp_ldapssl" | tr '[:upper:]' '[:lower:]')
        tmp_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user")
        tmp_userpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_userpwd")

        #This function processes and sets all parameters needed for the LDAP validation functions performed by the jar
        ldap_validation_parameter_generator
        #ldap_details is a array created which has all required details for additional parameters required to be passed to the LDAP JAR
        #DBACLD-159742
        tmp_ldap_group_basedn=${ldap_details[0]}
        tmp_ldap_user_filter=${ldap_details[1]}
        tmp_ldap_group_filter=${ldap_details[2]}
        tmp_ldap_user_password_list=${ldap_details[3]}
        tmp_ldap_group_list=${ldap_details[4]}

        verify_ldap_connection "$tmp_servername" "$tmp_serverport" "$tmp_basdn" "$tmp_user" "$tmp_userpwd" "$tmp_ldapssl" "$tmp_ldap_group_basedn" "$tmp_ldap_user_filter" "$tmp_ldap_group_filter" "$tmp_ldap_user_password_list" "$tmp_ldap_group_list"

        if [[ $SET_EXT_LDAP == "Yes" ]]; then
            # Validate External LDAP connection for CP4BA
            msgB "Checking the External LDAP connection.."
            tmp_servername="$(prop_ext_ldap_property_file LDAP_SERVER)"
            tmp_serverport="$(prop_ext_ldap_property_file LDAP_PORT)"
            tmp_basdn="$(prop_ext_ldap_property_file LDAP_BASE_DN)"
            tmp_ldapssl="$(prop_ext_ldap_property_file LDAP_SSL_ENABLED)"
            tmp_user=$($CLI_CMD get secret -n "$CP4BA_SERVICES_NS" -l name=ext-ldap-bind-secret -o jsonpath='{.items[0].data.ldapUsername}' | ${BASE64_DECODE})
            ## <https://jsw.ibm.com/browse/DBACLD-172803> - We are now asking user to use {xor} for special characters in password, so we need to use decode_xor_password to get the password decoded before validation.
            tmp_userpwd=$($CLI_CMD get secret -n "$CP4BA_SERVICES_NS" -l name=ext-ldap-bind-secret -o jsonpath='{.items[0].data.ldapPassword}' | ${BASE64_DECODE})
            if [[ "$tmp_userpwd" =~ "{xor}" ]]; then
                tmp_userpwd=$(decode_xor_password $tmp_userpwd $cp4ba_operators_namespace $cp4a_operator)
            fi

            tmp_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_servername")
            tmp_serverport=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_serverport")
            tmp_basdn=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_basdn")
            tmp_ldapssl=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldapssl")
            tmp_ldapssl=$(echo "$tmp_ldapssl" | tr '[:upper:]' '[:lower:]')
            tmp_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user")
            tmp_userpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_userpwd")

            verify_ldap_connection "$tmp_servername" "$tmp_serverport" "$tmp_basdn" "$tmp_user" "$tmp_userpwd" "$tmp_ldapssl"

        fi
    fi

    # Validate DB connection for CP4BA
    if [[ $DB_TYPE != "postgresql-edb" ]]; then

        INFO "Checking DB connection required by CP4BA"

        # check db connection for GCDDB
        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        
            #DBACLD-185209: Vault implementation
            if [[ "$vault_enabled" == 'true' ]]; then
                # check DBNAME/DBUSER for GCDDB
                tmp_dbserver=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].metadata.labels."gcd-db-server"' - 2>/dev/null)
                tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/gcdDBUsername 2>/dev/null )
                check_vault_secret_value "$tmp_dbusername" "ibm-fncm-secret" "gcdDBUsername" "$cp4a_operator"
                tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/gcdDBPassword 2>/dev/null )
                # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)

            else # Non-Vault
                # check DBNAME/DBUSER for GCDDB
                tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].metadata.labels."gcd-db-server"' -`
                tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].data.gcdDBUsername' - | base64 --decode`
                tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].data.gcdDBPassword' - | base64 --decode`
            fi

            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.GCD_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.GCD_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

            # Check DB connection for ssl/nonssl
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            fi

            # check db connection for FNCM ObjectStore
            if (( content_os_number > 0 )); then
                for ((j=0;j<${content_os_number};j++))
                do
                    # tmp_dbserver=`kubectl get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
                    tmp_dbserver="$(prop_db_name_user_property_file_for_server_name OS$((j+1))_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbserver "OS$((j+1))_DB_USER_NAME"
                    
                    #DBACLD-185209: Vault's implementation
                    if [[ "$vault_enabled" == 'true' ]]; then
                        tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/os$((j+1))DBUsername 2>/dev/null )
                        check_vault_secret_value "$tmp_dbusername" "ibm-fncm-secret" "os$((j+1))DBUsername" "$cp4a_operator"
                        tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/os$((j+1))DBPassword 2>/dev/null )
                        # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                    else # Non-Vault
                        tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} ".items[0].data.os$((j+1))DBUsername" - | base64 --decode`
                        tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} ".items[0].data.os$((j+1))DBPassword" - | base64 --decode`
                    fi

                    if [[ $DB_TYPE != "oracle" ]]; then
                        tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.OS$((j+1))_DB_NAME)"
                    else
                        tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.OS$((j+1))_DB_USER_NAME)"
                    fi
                    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
                    # Check DB non-SSL and SSL
                    if [[ $DB_TYPE == "oracle" ]]; then
                        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                    else
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then
                            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                        fi
                    fi
                done
            fi

            # check db connection for objectstore used by BAW authoring/BAW Runtime/BAW+AWS
            if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || (" ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams")) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
                for i in "${!BAW_AUTH_OS_ARR[@]}"; do
                    # tmp_dbserver=`kubectl get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
                    tmp_dbserver="$(prop_db_name_user_property_file_for_server_name ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbserver "${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME"
                    tmp_label=$(echo "${BAW_AUTH_OS_ARR[i]}"| tr '[:upper:]' '[:lower:]')
                    
                    #DBACLD-185209: Vault's implementation
                    if [[ "$vault_enabled" == 'true' ]]; then
                        tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/${tmp_label}DBUsername 2>/dev/null )
                        check_vault_secret_value "$tmp_dbusername" "ibm-fncm-secret" "${tmp_label}DBUsername" "$cp4a_operator"
                        tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/${tmp_label}DBPassword 2>/dev/null )
                        # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                    else # Non-Vault
                        tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} ".items[0].data.${tmp_label}DBUsername" - | base64 --decode`
                        tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} ".items[0].data.${tmp_label}DBPassword" - | base64 --decode`
                    fi

                    if [[ $DB_TYPE != "oracle" ]]; then
                        tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.${BAW_AUTH_OS_ARR[i]}_DB_NAME)"
                    else
                        tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                    fi
                    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
                    # Check DB non-SSL and SSL
                    if [[ $DB_TYPE == "oracle" ]]; then
                        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                    else
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then
                            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                        fi
                    fi
                done

                # check db connection for case history

                tmp_dbserver="$(prop_db_name_user_property_file_for_server_name CHOS_DB_USER_NAME)"
                if [[ $tmp_dbserver != \#* ]] ; then
                    check_dbserver_name_valid $tmp_dbserver "CHOS_DB_USER_NAME"
                    # tmp_label=$(echo "${BAW_AUTH_OS_ARR[i]}"| tr '[:upper:]' '[:lower:]')
                    
                    #DBACLD-185209: Vault's implementation
                    if [[ "$vault_enabled" == 'true' ]]; then
                        tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/chDBUsername 2>/dev/null )
                        check_vault_secret_value "$tmp_dbusername" "ibm-fncm-secret" "chDBUsername" "$cp4a_operator"
                        tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/chDBPassword 2>/dev/null )
                        # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                    else # Non-Vault
                        tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].data.chDBUsername' - | base64 --decode`
                        tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].data.chDBPassword' - | base64 --decode`
                    fi

                    if [[ $DB_TYPE != "oracle" ]]; then
                        tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.CHOS_DB_NAME)"
                    else
                        tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.CHOS_DB_USER_NAME)"
                    fi
                    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
                    # Check DB non-SSL and SSL
                    if [[ $DB_TYPE == "oracle" ]]; then
                        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                    else
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then
                            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                        fi
                    fi
                fi
            fi

            # check db connection for AWSDocs objectstore used by AWS only or BAW+AWS
            if [[ (" ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams")) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
                # tmp_dbserver=`kubectl get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
                tmp_dbserver="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbserver "AWSDOCS_DB_USER_NAME"
                
                #DBACLD-185209: Vault's implementation
                if [[ "$vault_enabled" == 'true' ]]; then
                    tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/awsdocsDBUsername 2>/dev/null )
                    check_vault_secret_value "$tmp_dbusername" "ibm-fncm-secret" "awsdocsDBUsername" "$cp4a_operator"
                    tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/awsdocsDBPassword 2>/dev/null )
                    # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                else # Non-Vault
                    tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].data.awsdocsDBUsername' - | base64 --decode`
                    tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].data.awsdocsDBPassword' - | base64 --decode`
                fi

                if [[ $DB_TYPE != "oracle" ]]; then
                    tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.AWSDOCS_DB_NAME)"
                else
                    tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.AWSDOCS_DB_USER_NAME)"
                fi
                tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
                # Check DB non-SSL and SSL
                if [[ $DB_TYPE == "oracle" ]]; then
                    verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                else
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                    fi
                fi
            fi

            # check db connection for objectstore used by AE data persistent
            if [[ " ${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then

                for i in "${!AEOS[@]}"; do
                    tmp_dbserver="$(prop_db_name_user_property_file_for_server_name AEOS_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbserver "AEOS_DB_USER_NAME"
                    # tmp_dbserver=`kubectl get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
                    
                    #DBACLD-185209: Vault's implementation
                    if [[ "$vault_enabled" == 'true' ]]; then
                        tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/aeosDBUsername 2>/dev/null )
                        check_vault_secret_value "$tmp_dbusername" "ibm-fncm-secret" "aeosDBUsername" "$cp4a_operator"
                        tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/aeosDBPassword 2>/dev/null )
                        # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                    else # Non-Vault
                        tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].data.aeosDBUsername' - | base64 --decode`
                        tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].data.aeosDBPassword' - | base64 --decode`
                    fi

                    if [[ $DB_TYPE != "oracle" ]]; then
                        tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.AEOS_DB_NAME)"
                    else
                        tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.AEOS_DB_USER_NAME)"
                    fi
                    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
                    # Check DB non-SSL and SSL
                    if [[ $DB_TYPE == "oracle" ]]; then
                        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                    else
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then
                            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                        fi
                    fi
                done
            fi

            # check db connection for objectstore used by ADP
            if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
                # tmp_dbserver=`kubectl get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
                tmp_dbserver="$(prop_db_name_user_property_file_for_server_name DEVOS_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbserver "DEVOS_DB_USER_NAME"
                
                #DBACLD-185209: Vault's implementation
                if [[ "$vault_enabled" == 'true' ]]; then
                    tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/devos1DBUsername 2>/dev/null )
                    check_vault_secret_value "$tmp_dbusername" "ibm-fncm-secret" "devos1DBUsername" "$cp4a_operator"
                    tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-fncm-secret/devos1DBPassword 2>/dev/null )
                    # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                else # Non-Vault
                    tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].data.devos1DBUsername' - | base64 --decode`
                    tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} '.items[0].data.devos1DBPassword' - | base64 --decode`
                fi

                if [[ $DB_TYPE != "oracle" ]]; then
                    tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.DEVOS_DB_NAME)"
                else
                    tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.DEVOS_DB_USER_NAME)"
                fi
                tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
                # Check DB non-SSL and SSL
                if [[ $DB_TYPE == "oracle" ]]; then
                    verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                else
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                    fi
                fi
            fi
        fi

        # check db connection for ICN
        if [[ " ${foundation_component_arr[@]}" =~ "BAN" ]]; then
            if [[ ! (" ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "1") ]]; then
                if [[ $DB_TYPE != "oracle" ]]; then
                    tmp_dbname="$(prop_db_name_user_property_file ICN_DB_NAME)"
                else
                    tmp_dbname="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
                fi
                tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                # DBACLD-185209: Vault's implementation
                if [[ "$vault_enabled" == 'true' ]]; then
                    tmp_dbserver=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].metadata.labels."db-server"' - 2>/dev/null)
                    tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-ban-secret/navigatorDBUsername 2>/dev/null )
                    check_vault_secret_value "$tmp_dbusername" "ibm-ban-secret" "navigatorDBUsername" "$cp4a_operator"
                    tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-ban-secret/navigatorDBPassword 2>/dev/null )
                    # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                else # Non-vault
                    tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].metadata.labels.db-server' -`
                    tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.navigatorDBUsername' - | base64 --decode`
                    tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.navigatorDBPassword' - | base64 --decode`
                fi

                # Check DB non-SSL and SSL
                if [[ $DB_TYPE == "oracle" ]]; then
                    verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                else
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                    fi
                fi
            fi
        fi

        # check db connection for ODM
        containsElement "decisions" "${pattern_cr_arr[@]}"
        odm_Val=$?
        if [[ $odm_Val -eq 0 ]]; then
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file ODM_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
            #DBACLD-233362: Vault's implementation
            if [[ "$vault_enabled" == 'true' ]]; then
                local spc_yaml
                spc_yaml=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml 2>/dev/null)
                tmp_dbserver=$(${YQ_CMD} '.items[0].metadata.labels.db-server' - <<< "$spc_yaml")
                tmp_op_name=$(${YQ_CMD} '.items[0].metadata.annotations["cp4ba.ibm.com/owned-by"]' - <<< "$spc_yaml")

                tmp_odm_op_name=$($CLI_CMD get pod -l name=$tmp_op_name -n $cp4ba_operators_namespace --no-headers --ignore-not-found | awk '{print $1}' 2>/dev/null)
                tmp_dbusername=$( $CLI_CMD exec $tmp_odm_op_name -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-odm-db-secret/db-user 2>/dev/null )

                check_vault_secret_value "$tmp_dbusername" "ibm-odm-db-secret" "db-user" "$tmp_odm_op_name"
                tmp_dbuserpassword=$( $CLI_CMD exec $tmp_odm_op_name -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-odm-db-secret/db-password 2>/dev/null )

                # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
            else # Non-Vault
                tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
                tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.db-user' - | base64 --decode`
                tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.db-password' - | base64 --decode`
            fi

            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            fi
        fi

        # check db connection for ADP GitGateway
        if [[ "${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file ADP_GG_DB_NAME)"
                tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                #DBACLD-185209: Vault's implementation
                if [[ "$vault_enabled" == 'true' ]]; then
                    # echo "[DEBUG]: adpggdb - get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=ibm-adp-secret -o yaml | ${YQ_CMD} '.items[0].metadata.labels.db-server'"
                    tmp_dbserver=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=ibm-adp-secret -o yaml | ${YQ_CMD} '.items[0].metadata.labels.db-server' - 2>/dev/null)
                    tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-adp-secret/adpggDBUsername 2>/dev/null )
                    check_vault_secret_value "$tmp_dbusername" "ibm-adp-secret" "adpggDBUsername" "$cp4a_operator"
                    tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-adp-secret/adpggDBPassword 2>/dev/null )
                    # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                else # Non-Vault
                    tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-adp-secret -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
                    tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-adp-secret -o yaml | ${YQ_CMD} '.items[0].data.adpggDBUsername' - | base64 --decode`
                    tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=ibm-adp-secret -o yaml | ${YQ_CMD} '.items[0].data.adpggDBPassword' - | base64 --decode`
                fi

                verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            fi
        fi

        # check db connection for DPE Base DB
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

            #DBACLD-185209: Vault's implementation
            if [[ "$vault_enabled" == 'true' ]]; then
                tmp_dbserver=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l base-db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].metadata.labels.base-db-server' - 2>/dev/null)
                tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/aca-basedb/BASE_DB_USER 2>/dev/null )
                check_vault_secret_value "$tmp_dbusername" "aca-basedb" "BASE_DB_USER" "$cp4a_operator"
                tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/aca-basedb/BASE_DB_CONFIG 2>/dev/null )
                # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
            else # Non-Vault
                tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l base-db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.base-db-server' -`
                tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l base-db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.BASE_DB_USER' - | base64 --decode`
                tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l base-db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.BASE_DB_CONFIG' - | base64 --decode`
            fi

            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            fi
        fi

        # check db connection for DPE Project DB
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_base_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
            else
                tmp_base_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
            fi
            tmp_base_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_base_dbname")

            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file ADP_PROJECT_DB_NAME)"
                tmp_dbusername="$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_NAME)"
            else
                tmp_dbusername="$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_NAME)"
            fi
            tmp_dbserver="$(prop_db_name_user_property_file ADP_PROJECT_DB_SERVER)"
            tmp_dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbserver")
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
            tmp_dbusername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbusername")

            local db_name_array=()
            local db_user_array=()
            local db_server_array=()

            OIFS=$IFS
            IFS=',' read -ra db_name_array <<< "$tmp_dbname"
            IFS=',' read -ra db_user_array <<< "$tmp_dbusername"
            IFS=',' read -ra db_server_array <<< "$tmp_dbserver"
            IFS=$OIFS

            # tmp_dbserver=`kubectl get secret -n "$CP4BA_SERVICES_NS" -l base-db-name=${tmp_base_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.base-db-server`
            # tmp_dbusername=`kubectl get secret -n "$CP4BA_SERVICES_NS" -l base-db-name=${tmp_base_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.BASE_DB_USER | base64 --decode`

            if [[ ${#db_name_array[@]} != ${#db_user_array[@]} || ${#db_user_array[@]} != ${#db_server_array[@]} ]]; then
                fail "The number of values of: ADP_PROJECT_DB_NAME, ADP_PROJECT_DB_USER_NAME, ADP_PROJECT_DB_SERVER must all be equal. Exit ..."
            else
                # check connection for proj db
                projs_max_index=${#db_name_array[@]}-1

                for num in "${!db_name_array[@]}"; do
                    tmp_dbname=${db_name_array[num]}
                    tmp_dbusername=${db_user_array[num]}
                    # tmp_dbuserpassword=${db_userpwd_array[num]}
                    # the "aca-basedb" secret uses all upper-case DB name in the field name for the DB pwd, example:TEST1PROJ1_DB_CONFIG
                    tmp_dbname_caps=$(echo "$tmp_dbname" | tr '[:lower:]' '[:upper:]')
                    
                    #DBACLD-185209: Vault's implementation
                    if [[ "$vault_enabled" == 'true' ]]; then
                        tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/aca-basedb/${tmp_dbname_caps}_DB_CONFIG 2>/dev/null )
                        # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                    else # Non-Vault
                        tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l base-db-name=${tmp_base_dbname} -o yaml | ${YQ_CMD} ".items[0].data.${tmp_dbname_caps}_DB_CONFIG" - | base64 --decode`
                    fi
                    tmp_dbserver=${db_server_array[num]}

                    # Check DB non-SSL and SSL and SSL
                    if [[ $DB_TYPE == "oracle" ]]; then
                        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                    else
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then
                            # for verifying DB, use the actual case-sensitive DB name, since PG DB names are case-sensitive
                            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                        fi
                    fi
                done
            fi
        fi

        # check db connection for AE database
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "application" ]]; then
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

            #DBACLD-185209: Vault's implementation
            if [[ "$vault_enabled" == 'true' ]]; then
                tmp_dbserver=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].metadata.labels.db-server' - 2>/dev/null)
                tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/icp4adeploy-workspace-aae-app-engine-admin-secret/AE_DATABASE_USER 2>/dev/null )
                check_vault_secret_value "$tmp_dbusername" "icp4adeploy-workspace-aae-app-engine-admin-secret" "AE_DATABASE_USER" "$cp4a_operator"
                tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/icp4adeploy-workspace-aae-app-engine-admin-secret/AE_DATABASE_PWD 2>/dev/null )
                # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
            else # Non-Vault
                tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
                tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.AE_DATABASE_USER' - | base64 --decode`
                tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.AE_DATABASE_PWD' - | base64 --decode`
            fi

            # Check DB non-SSL and SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            fi
        fi


        # # check db connection for BAW Authoring database
        # if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
        #     if [[ $DB_TYPE != "oracle" ]]; then
        #         tmp_dbname="$(prop_db_name_user_property_file AUTHORING_DB_NAME)"
        #     else
        #         tmp_dbname="$(prop_db_name_user_property_file AUTHORING_DB_USER_NAME)"
        #     fi
        #     tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

        #     tmp_dbserver=`kubectl get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
        #     tmp_dbusername=`kubectl get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbUser | base64 --decode`
        #     tmp_dbuserpassword=`kubectl get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.password | base64 --decode`

        #     # Check DB non-SSL and SSL
        #     if [[ $DB_TYPE == "oracle" ]]; then
        #         verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        #     else
        #         verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        #     fi
        # fi

        # check db connection for BAW+AWS/BAW runtime/AWS

        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
            # check baw runtime
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

            #DBACLD-185209: Vault's implementation
            if [[ "$vault_enabled" == 'true' ]]; then
                tmp_dbserver=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].metadata.labels.db-server' - 2>/dev/null)
                tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-baw-wfs-server-db-secret/dbUser 2>/dev/null )
                check_vault_secret_value "$tmp_dbusername" "ibm-baw-wfs-server-db-secret" "dbUser" "$cp4a_operator"
                tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-baw-wfs-server-db-secret/password 2>/dev/null )
                # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
            else # Non-Vault
                tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
                tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.dbUser' - | base64 --decode`
                tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.password' - | base64 --decode`
            fi

            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            fi

            # check aws
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

            #DBACLD-185209: Vault's implementation
            if [[ "$vault_enabled" == 'true' ]]; then
                tmp_dbserver=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].metadata.labels.db-server' - 2>/dev/null)
                tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-aws-wfs-server-db-secret/dbUser 2>/dev/null )
                check_vault_secret_value "$tmp_dbusername" "ibm-aws-wfs-server-db-secret" "dbUser" "$cp4a_operator"
                tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-aws-wfs-server-db-secret/password 2>/dev/null )
                # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
            else # Non-Vault
                tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
                tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.dbUser' - | base64 --decode`
                tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.password' - | base64 --decode`
            fi

            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            fi
        elif [[ (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams") && " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
            # check db connection for workflows
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

            tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
            tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.dbUser' - | base64 --decode`
            tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.password' - | base64 --decode`

            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            fi
        elif [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
            # check db connection for baw runtime
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

            #DBACLD-185209: Vault's implementation
            if [[ "$vault_enabled" == 'true' ]]; then
                tmp_dbserver=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].metadata.labels.db-server' - 2>/dev/null)
                tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-baw-wfs-server-db-secret/dbUser 2>/dev/null )
                check_vault_secret_value "$tmp_dbusername" "ibm-baw-wfs-server-db-secret" "dbUser" "$cp4a_operator"
                tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/ibm-baw-wfs-server-db-secret/password 2>/dev/null )
                # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
            else # Non-Vault
                tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
                tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.dbUser' - | base64 --decode`
                tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.password' - | base64 --decode`
            fi

            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            fi
        fi

        # check db connection for Application Engine Playback database
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file APP_PLAYBACK_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

            #DBACLD-185209: Vault's implementation
            if [[ "$vault_enabled" == 'true' ]]; then
                tmp_dbserver=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].metadata.labels.db-server' - 2>/dev/null)
                tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/playback-server-admin-secret/AE_DATABASE_USER 2>/dev/null )
                check_vault_secret_value "$tmp_dbusername" "playback-server-admin-secret" "AE_DATABASE_USER" "$cp4a_operator"
                tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/playback-server-admin-secret/AE_DATABASE_PWD 2>/dev/null )
                # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
            else # Non-Vault
                tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
                tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.AE_DATABASE_USER' - | base64 --decode`
                tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.AE_DATABASE_PWD' - | base64 --decode`
            fi

            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            fi
        fi

        # check db connection for BAS
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || "${pattern_cr_arr[@]}" =~ "workflow-authoring" || ("${pattern_cr_arr[@]}" =~ "workflow-process-service" && $EXTERNAL_DB_WFPS_AUTHORING == "Yes") || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file STUDIO_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

            #DBACLD-185209: Vault's implementation
            if [[ "$vault_enabled" == 'true' ]]; then
                tmp_dbserver=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].metadata.labels.db-server' - 2>/dev/null)
                tmp_dbusername=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/icp4adeploy-bas-admin-secret/dbUsername 2>/dev/null )
                check_vault_secret_value "$tmp_dbusername" "icp4adeploy-bas-admin-secret" "dbUsername" "$cp4a_operator"
                tmp_dbuserpassword=$( $CLI_CMD exec $cp4a_operator -n $cp4ba_operators_namespace -- cat /tmp/secrets/icp4adeploy-bas-admin-secret/dbPassword 2>/dev/null )
                # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
            else # Non-Vault
                tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
                tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.dbUsername' - | base64 --decode`
                tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.dbPassword' - | base64 --decode`
            fi
            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            fi
        fi
        # check db connection for DICMS Designer
        if [[ "${pattern_cr_arr[@]}" =~ "decisions_ads" && "${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file DICMS_DESIGNER_DB_NAME)"
                tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                #DBACLD-185209: Vault's implementation
                if [[ "$vault_enabled" == 'true' ]]; then
                    local spc_yaml
                    spc_yaml=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml 2>/dev/null)
                    tmp_dbserver=$(echo "$spc_yaml" | ${YQ_CMD} '.items[0].metadata.labels.db-server' - 2>/dev/null)
                    tmp_op_name=$(${YQ_CMD} '.items[0].metadata.annotations["cp4ba.ibm.com/owned-by"]' - <<< "$spc_yaml")

                    tmp_ads_op_name=$($CLI_CMD get pod -l name=$tmp_op_name -n $cp4ba_operators_namespace --no-headers --ignore-not-found | awk '{print $1}' 2>/dev/null)
                    tmp_dbusername=$( $CLI_CMD exec $tmp_ads_op_name -n $cp4ba_operators_namespace -- cat /tmp/secrets/icp4adeploy-ibm-ads-designer-secret/dbUsername 2>/dev/null )
                    check_vault_secret_value "$tmp_dbusername" "ads-designer-secret" "username" "$cp4a_operator"
                    tmp_dbuserpassword=$( $CLI_CMD exec $tmp_ads_op_name -n $cp4ba_operators_namespace -- cat /tmp/secrets/icp4adeploy-ibm-ads-designer-secret/dbPassword 2>/dev/null )
                    # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                else # Non-Vault
                    tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
                    tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.username' - | base64 --decode`
                    tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.password' - | base64 --decode`
                fi

                verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            fi
        fi

        # check db connection for DICMS Runtime
        if [[ "${pattern_cr_arr[@]}" =~ "decisions_ads" && "${optional_component_cr_arr[@]}" =~ "ads_runtime" ]]; then
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file DICMS_RUNTIME_DB_NAME)"
                tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                #DBACLD-185209: Vault's implementation
                if [[ "$vault_enabled" == 'true' ]]; then
                    local spc_yaml
                    spc_yaml=$($CLI_CMD get SecretProviderClass -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml 2>/dev/null)
                    tmp_dbserver=$(echo "$spc_yaml" | ${YQ_CMD} '.items[0].metadata.labels.db-server' - 2>/dev/null)
                    tmp_op_name=$(${YQ_CMD} '.items[0].metadata.annotations["cp4ba.ibm.com/owned-by"]' - <<< "$spc_yaml")

                    tmp_ads_op_name=$($CLI_CMD get pod -l name=$tmp_op_name -n $cp4ba_operators_namespace --no-headers --ignore-not-found | awk '{print $1}' 2>/dev/null)
                    tmp_dbusername=$( $CLI_CMD exec $tmp_ads_op_name -n $cp4ba_operators_namespace -- cat /tmp/secrets/icp4adeploy-ibm-ads-runtime-secret/dbUsername 2>/dev/null )
                    check_vault_secret_value "$tmp_dbusername" "ads-runtime-secret" "username" "$cp4a_operator"
                    tmp_dbuserpassword=$( $CLI_CMD exec $tmp_ads_op_name -n $cp4ba_operators_namespace -- cat /tmp/secrets/icp4adeploy-ibm-ads-runtime-secret/dbPassword 2>/dev/null )
                    # skip check for tmp_dbuserpassword since the pwd may be empty (if using client auth)
                else # Non-Vault
                    tmp_dbserver=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items.[0].metadata.labels.db-server' -`
                    tmp_dbusername=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.username' - | base64 --decode`
                    tmp_dbuserpassword=`${CLI_CMD} get secret -n "$CP4BA_SERVICES_NS" -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} '.items[0].data.password' - | base64 --decode`
                fi

                verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            fi
        fi
    fi

    # Check db connection for im/zen/bts external postgresql db
    local DB_JDBC_NAME=${JDBC_DRIVER_DIR}/postgresql
    local DB_CONNECTION_JAR_PATH=${CUR_DIR}/helper/verification/postgresql

    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_IM_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        printf "\n"
        im_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        im_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$im_external_db_cert_folder")

        dbserver="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_RW_ENDPOINT)"
        dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
        dbport="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_PORT)"
        dbport=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbport")
        dbname="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_NAME)"
        dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
        dbuser="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_USER)"
        dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
        dbuserpwd="changit" # client auth does not need dbuserpwd

        info "Checking connection for IM metastore external Postgres database \"${dbname}\" belongs to database instance \"${dbserver}\"...."

        postgres_cafile="${im_external_db_cert_folder}/root.crt"
        postgres_clientkeyfile="${im_external_db_cert_folder}/client.key"
        postgres_clientcertfile="${im_external_db_cert_folder}/client.crt"

        rm -rf ${im_external_db_cert_folder}/clientkey.pk8 2>&1 </dev/null
        openssl pkcs8 -topk8 -outform DER -in $postgres_clientkeyfile -out ${im_external_db_cert_folder}/clientkey.pk8 -nocrypt 2>&1 </dev/null

        output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/postgresql-42.7.13.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode verify-ca -ca $postgres_cafile -clientkey ${im_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile 2>&1)
        retVal_verify_db_tmp=$?
        connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
        if [[ ! -z $connection_time ]]; then
            display_latency_warning $connection_time "Database"
        fi

        [[ retVal_verify_db_tmp -ne 0 ]] && \
        warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/postgresql-42.7.13.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode verify-ca -ca $postgres_cafile -clientkey ${im_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile" && \
        fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check the configuration again."
        [[ retVal_verify_db_tmp -eq 0 ]] && \
        success "Checked DB connection for \"$dbname\" on database server \"$dbserver\", PASSED!"
    fi

    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_ZEN_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        printf "\n"
        zen_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        zen_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$zen_external_db_cert_folder")

        dbserver="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_RW_ENDPOINT)"
        dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
        dbport="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_PORT)"
        dbport=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbport")
        dbname="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_NAME)"
        dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
        dbuser="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_USER)"
        dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
        dbuserpwd="changit" # client auth does not need dbuserpwd

        info "Checking connection for Zen metastore external Postgres database \"${dbname}\" belongs to database instance \"${dbserver}\"...."

        postgres_cafile="${zen_external_db_cert_folder}/root.crt"
        postgres_clientkeyfile="${zen_external_db_cert_folder}/client.key"
        postgres_clientcertfile="${zen_external_db_cert_folder}/client.crt"

        rm -rf ${zen_external_db_cert_folder}/clientkey.pk8 2>&1 </dev/null
        openssl pkcs8 -topk8 -outform DER -in $postgres_clientkeyfile -out ${zen_external_db_cert_folder}/clientkey.pk8 -nocrypt 2>&1 </dev/null

        output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/postgresql-42.7.13.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode verify-ca -ca $postgres_cafile -clientkey ${zen_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile 2>&1)
        retVal_verify_db_tmp=$?
        connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
        if [[ ! -z $connection_time ]]; then
            display_latency_warning $connection_time "Database"
        fi

        [[ retVal_verify_db_tmp -ne 0 ]] && \
        warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/postgresql-42.7.13.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode verify-ca -ca $postgres_cafile -clientkey ${zen_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile" && \
        fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check the configuration again."
        [[ retVal_verify_db_tmp -eq 0 ]] && \
        success "Checked DB connection for \"$dbname\" on database server \"$dbserver\", PASSED!"
    fi

    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_BTS_FLAG)")
    tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        printf "\n"
        bts_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        bts_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$bts_external_db_cert_folder")

        dbserver="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_HOSTNAME)"
        dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
        dbport="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_PORT)"
        dbport=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbport")
        dbname="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_NAME)"
        dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
        dbuser="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_USER_NAME)"
        dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
        dbuserpwd="changit" # client auth does not need dbuserpwd

        info "Checking connection for BTS metastore external Postgres database \"${dbname}\" belongs to database instance \"${dbserver}\"...."

        postgres_cafile="${bts_external_db_cert_folder}/root.crt"
        postgres_clientkeyfile="${bts_external_db_cert_folder}/client.key"
        postgres_clientcertfile="${bts_external_db_cert_folder}/client.crt"

        rm -rf ${bts_external_db_cert_folder}/clientkey.pk8 2>&1 </dev/null
        openssl pkcs8 -topk8 -outform DER -in $postgres_clientkeyfile -out ${bts_external_db_cert_folder}/clientkey.pk8 -nocrypt 2>&1 </dev/null

        output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/postgresql-42.7.13.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode verify-ca -ca $postgres_cafile -clientkey ${bts_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile 2>&1)
        retVal_verify_db_tmp=$?
        connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
        if [[ ! -z $connection_time ]]; then
            display_latency_warning $connection_time "Database"
        fi

        [[ retVal_verify_db_tmp -ne 0 ]] && \
        warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/postgresql-42.7.13.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode verify-ca -ca $postgres_cafile -clientkey ${bts_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile" && \
        fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check the configuration again."
        [[ retVal_verify_db_tmp -eq 0 ]] && \
        success "Checked DB connection for \"$dbname\" on database server \"$dbserver\", PASSED!"
    fi

    echo_red "\n**** Next steps ****"
    if [[ "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
        info "If all prerequisites checks PASSED, you can run cp4a-deployment to deploy CP4BA. Otherwise, please check the configuration again."
        info "After CP4BA is deployed, please refer to the documentation for post-deployment steps."
    else
        info "If all prerequisites checks PASSED:"
        echo " 1. Please edit your CR to set the following property to enable external secret management integration with Vault for custom secrets: \"spec.shared_configuration.sc_vault_configuration.enable_external_secret_store: true\""
        echo
        info "If you encountered problems with prerequisites checks and need to undo the changes and disable external secret management integration:"
        echo " 1. If the property is in your CR, remove the following property: \"spec.shared_configuration.sc_vault_configuration.enable_external_secret_store: true\""
        echo
        get_vault_csv_list_from_spc "$CP4BA_CSV_VERSION"
        if [[ -n "$_vault_csv_list" ]]; then
            echo " 2. Run the following command to unpatch the Operator CSV(s) (remove the volumes for the external secret management):"
            if [[ $SEPARATE_OPERAND_FLAG == "No" ]]; then
                msgB "  ./cp4a-vault.sh -m unpatch --csv \"$_vault_csv_list\" -n $CP4BA_SERVICES_NS"
            else
                msgB "  ./cp4a-vault.sh -m unpatch --csv \"$_vault_csv_list\" -n $CP4BA_SERVICES_NS --operatorNamespace $CP4BA_OPERATOR_NS"
            fi
            echo " 3. You can optionally remove the SecretProviderClass resources created by the script, but it is not required."
        fi 
    fi
}


# Main function that performs the different functionalities required for adding/removing patterns and optional components
function update_components_mode(){
    # Import functions used only for the update components mode
    source ${CUR_DIR}/helper/update-selected-components/update-selected-components.sh
    retrieve_existing_property_files
    retrieve_current_custom_resource_file "$CP4BA_SERVICES_NS" "prerequisites_script"
    print_current_summary_table "$CP4BA_SERVICES_NS"
    DEPLOYMENT_TYPE="production"
    PLATFORM_SELECTED="OCP"
    # this value has to be 1 so that the select patterns and optional component functions that are called here know that this is not to be run for BAW only.(The script should never be executed in baw mode since 25.0.0 but since that code has not been removed , it is initialized here)
    select_pattern
    select_optional_component

    # This array (current_cr_optional_components_array) stores the current optional components deployed.
    # Only ask for the WatsonX deployment type (SaaS or LWE) if workflow_assistant or workplace_assistant
    # was not already present in the CR but has been newly selected during the update.
    if ! [[ " ${current_cr_optional_components_array[@]} " =~ "workflow_assistant" || " ${current_cr_optional_components_array[@]} " =~ "workplace_assistant" ]]; then
        if [[ "${optional_component_cr_arr[@]}" =~ "workflow_assistant" || "${optional_component_cr_arr[@]}" =~ "workplace_assistant" ]]; then
            select_wfa_deployment_type
        fi
    else
        # WPA/WFA was already deployed in the previous iteration. Restore the previously chosen
        # WatsonX deployment type (SaaS or LWE) from the persisted TEMPORARY_PROPERTY_FILE so that
        # create_property_file() regenerates the correct parameter block instead of defaulting to LWE.
        # DBACLD-251199
        if [[ "${optional_component_cr_arr[@]}" =~ "workflow_assistant" || "${optional_component_cr_arr[@]}" =~ "workplace_assistant" ]]; then
            WFA_WATSONX_DEPLOYMENT_TYPE="$(prop_tmp_property_file WFA_WATSONX_DEPLOYMENT_TYPE)"
            if [[ -z "$WFA_WATSONX_DEPLOYMENT_TYPE" ]]; then
                WFA_WATSONX_DEPLOYMENT_TYPE="SaaS"
            fi
            info "Retaining previously selected WatsonX deployment type for Workplace/Workflow Assistant: $WFA_WATSONX_DEPLOYMENT_TYPE"
        fi
    fi

    # This array (current_cr_deployment_patterns_array) stores the current patterns deployed , and we should only ask for the list of object stores numbers if content and document processing was added later
    # This variable gets set in the function retrieve_current_custom_resource_file function
    if ! [[ " ${current_cr_deployment_patterns_array[@]}" =~ "content" || " ${current_cr_deployment_patterns_array[@]}" =~ "document_processing" ]]; then
        # The only way that this condition passes is if content or document processing was selected while adding new patterns
        # In that case we need to ask for object stores
        if [[ " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
            select_objectstore_number
        fi
    fi

    # This array (current_cr_deployment_patterns_array) stores the current patterns deployed , and we should only ask if they want to use external postgres for BTS if they add any of the patterns that need BTS while running the script to update components
    # This variable gets set in the function retrieve_current_custom_resource_file function
    
    if ! [[ " ${current_cr_deployment_patterns_array[@]}" =~ "decisions_ads" || " ${current_cr_deployment_patterns_array[@]}" =~ "workflow-authoring" || " ${current_cr_deployment_patterns_array[@]}" =~ "document_processing" || " ${current_cr_deployment_patterns_array[@]}" =~ "application" || " ${current_cr_optional_components_array[@]} " =~ "bai" ]]; then
        
        # The only way that the below IF condition passes is if any of the patterns/optional components listed below are added when selecting while adding new patterns
        # In that case we need to ask for object stores
        containsElement "decisions_ads" "${pattern_cr_arr[@]}"
        ads_Val=$?

        if [[ $ads_Val -eq 0 || " ${pattern_cr_arr[@]} " =~ "workflow-authoring" || " ${pattern_cr_arr[@]} " =~ "document_processing" || " ${pattern_cr_arr[@]} " =~ "application" || " ${optional_component_cr_arr[@]} " =~ "bai" ]]; then
            ### <https://jsw.ibm.com/browse/DBACLD-217809> - We  prompt the user to ask if they want to use external PostgreSQL for Zen and IM when external PostgreSQL is selected.
            #DBACLD-194974: Combine IM/Zen question for ext. PG.  Ask regardless of DB_TYPE 
            select_external_postgresdb_for_bts
        fi
    fi

    # This array (current_cr_deployment_patterns_array) stores the current patterns deployed and  current_cr_optional_components_array stores the current optional components selected.
    # We should only ask if external certificate should be used by kafka if the below patterns/optional components were not selected initially and later added
    # Both variables get set in the function retrieve_current_custom_resource_file function
    if ! [[ " ${current_cr_deployment_patterns_array[@]} " =~ "workflow-authoring" || " ${current_cr_deployment_patterns_array[@]} " =~ "workflow-runtime" || " ${current_cr_optional_components_array[@]} " =~ "bai" ]]; then
        if [[ " ${pattern_cr_arr[@]} " =~ "workflow-authoring" || " ${pattern_cr_arr[@]} " =~ "workflow-runtime" || " ${optional_component_cr_arr[@]} " =~ "bai" ]]; then
            select_external_cert_opensearch_kafka
        fi
    fi

    # This array (current_cr_deployment_patterns_array) stores the current patterns deployed and  current_cr_optional_components_array stores the current optional components selected
    # Only if Content has been selected during the update components mode will the select_cpe_full_storage be required to be executed
    if ! [[ " ${current_cr_deployment_patterns_array[@]}" =~ "document_processing" ]]; then
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
            select_cpe_full_storage
        fi
    fi

    # This array (current_cr_deployment_patterns_array) stores the current patterns deployed and  current_cr_optional_components_array stores the current optional components selected
    # Only if document_processing_designer has been selected during the update components mode will the select_gpu_document_processing be required to be executed
    if ! [[ " ${current_cr_deployment_patterns_array[@]} " =~ "document_processing_designer" ]]; then
        
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            select_gpu_document_processing
        fi
    fi
    
    # This array (current_cr_deployment_patterns_array) stores the current patterns deployed and  current_cr_optional_components_array stores the current optional components selected    
    # If the existing deployment included the "content" or "document_processing" pattern but it was removed during the update components, set the content object-store count to zero.
    if [[ " ${current_cr_deployment_patterns_array[@]} " =~ "content" ]] || [[ " ${current_cr_deployment_patterns_array[@]} " =~ "document_processing" ]]; then
        if ! [[ " ${pattern_cr_arr[@]} " =~ "content" ]] && ! [[ " ${pattern_cr_arr[@]} " =~ "document_processing" ]]; then
            content_os_number=0
        fi
    fi

 	# If document_processing (ADP) and/or decisions_ads (DICMS) were in the current CR but both have been removed during update components, 
    # reset the external-postgres-for-ADPGG/DICMS flag so that the postgresql-external block is not regenerated. This handles non-Postgres primary DB deployments
    # (e.g. db2, oracle, mssql) where the flag could legitimately be true from the initial deployment.
    if [[ " ${current_cr_deployment_patterns_array[@]} " =~ "document_processing" || " ${current_cr_deployment_patterns_array[@]} " =~ "decisions_ads" ]]; then
        if ! [[ " ${pattern_cr_arr[@]} " =~ "document_processing" || " ${pattern_cr_arr[@]} " =~ "decisions_ads" ]]; then
            EXTERNAL_POSTGRESDB_FOR_ADPGG_DICMS="false"
        fi
    fi
	
    create_temp_property_file
}


################################################
#### Begin - Main step for install operator ####
################################################
# select_script_option2
#prompt_license
clear

###############################
## PROPERTY MODE
###############################
if [[ $RUNTIME_MODE == "property" ]]; then
    check_cp4ba_separate_operand $TARGET_PROJECT_NAME
    if [[ -n "${CP4BA_SERVICES_NS:-}" && "$TARGET_PROJECT_NAME" != "$CP4BA_SERVICES_NS" ]]; then
        printf '%b\n' "\x1B[1;31m[ERROR]\x1B[0m The -n value must be the CP4BA operand namespace in Separation-of-Duty deployments."
        printf '%b\n' "         Re-run: ./cp4a-prerequisites.sh -m ${RUNTIME_MODE} -n ${CP4BA_SERVICES_NS}"
        exit 1
    fi
     
    # initialize this to false.  This will be set to true in the helper functions if the user provides property files for existing deployment
    EXISTING_PROP_FILES_PROVIDED="false"

    # ------ Scenarios for enabling Vault --------
    # 1. During fresh deploy: VAULT_ENABLED="true", ENABLE_VAULT_ON_EXIST="false"
    # 2. On existing deploy with prop files in default dir: VAULT_ENABLED="true", ENABLE_VAULT_ON_EXIST="true", ENABLE_VAULT_ON_EXIST_PROP_TYPE="default"
    # 3. On existing deploy with prop files in user provided dir: VAULT_ENABLED="true", ENABLE_VAULT_ON_EXIST="true", ENABLE_VAULT_ON_EXIST_PROP_TYPE="user"
    # 4. On existing deploy without prop files: VAULT_ENABLED="true", ENABLE_VAULT_ON_EXIST="true", ENABLE_VAULT_ON_EXIST_PROP_TYPE="none"
    # Handle when user wants to enable the use of external secret management (Vault) on existing deployment
    if [[ "$ENABLE_VAULT_ON_EXIST" == "true" ]]; then
        # retrieve the original properties and live cr values that will help us in creating new properties files
        retrieve_orig_props_and_live_cr

        # Handle when user wants to enable Vault on existing deploy and has provided original prop files 
        if [[ "$ENABLE_VAULT_ON_EXIST_PROP_TYPE" != "none" ]]; then
            ## This approach didn't work because of missing props in the new prop files from original prop files and attempt to merge back the missing props was too messy
            ## copy over values from original prop files to the new prop files
            # update_property_files
            
            ## For now, we will just reuse the original property files and add Vault properties
            copy_original_property_files_to_default_dir

            # Add Vault properties to the property file for user to fill out
            add_vault_props

            # DBACLD-239117: Add the cert folders for shared secrets that can be optionally created for Vault
            mkdir -p $ROOT_CA_CERT_FOLDER >/dev/null 2>&1
            mkdir -p $EXTERNAL_TLS_CERT_FOLDER >/dev/null 2>&1
            mkdir -p $TRUSTED_CERT_FOLDER >/dev/null 2>&1 

            # DBACLD-239112: Special handling for ADS/DICMS since there are changes for DICMS in CP4BA 26.0.0
            update_ads_name_to_dicms_in_prop_file  # rename ADS props to DICMS
            add_dicms_props_for_vault # Add new DICMS props introduced in CP4BA 26.0.0

            if [[ " ${pattern_cr_arr[@]} " =~ " decisions " ]]; then
                # DBACLD-239524: Add ODM props (eg. ODM.KEYSTORE_PASSWORD) to the migrated property files
                # not required as we are auto generating the ODM keystore password -> https://jsw.ibm.com/browse/DBACLD-238578?focusedId=30084545&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-30084545
                #add_odm_props
                echo
            fi

            echo_red "\n**** Next steps ****"
            echo_bold " 1. If you have not yet done so, please ensure you have followed the instructions in the CP4BA Knowledge Center topic \"Optional: Preparing for external secret management\""
            echo_bold " \n2. Please carefully review and fill out the new CP4BA.VAULT* properties in the property file ${USER_PROFILE_PROPERTY_FILE} " 
            echo_bold " \n3. Please carefully review all the property files in ${PROPERTY_FILE_FOLDER} and confirm all the properties are set correctly.  For any properties that have changed since your original deployment, please update the values."
            echo_bold " \n   IMPORTANT: There may be other new required properties, so please be sure to set values for all required properties."
            echo_bold " \n4. Please review the certificate files in ${SSL_CERT_FOLDER} folder and add or update if your custom certificates are missing or have changed."
            echo_bold " \n5. Please review and update the *SSL_CERT_FILE_FOLDER properties in the property files to ensure they specify the correct location for your current certificate files.  The directory paths for the 'cert' folder in the property files may be pointing to the old location."
            echo_bold " \nOnce you have completed the above steps, please run the following to generate the templates needed for supporting secrets in Vault (SecretProviderClasses and JSON templates)"
            printf '%b\n' "    $RED_TEXT\"./cp4a-prerequisites.sh -m generate --enable-external-secret-management  -n $CP4BA_SERVICES_NS\"${RESET_TEXT}"

            # skip the rest of the actions since we already have the property files
            exit
        fi
    fi

    # IF the variable UPDATE_COMPONENTS is set that means we are trying to update the list of deployment patterns or optional components
    if [[ ! -z $UPDATE_COMPONENTS ]]; then
        echo
        update_components_mode
        # Set this to true so that we won't prompt user to input information for new deployment
        EXISTING_PROP_FILES_PROVIDED="true"
    fi
    
    # if this is not a situation where we are working with existing props files, then prompt for information for new deployment
    if [[ "$EXISTING_PROP_FILES_PROVIDED" != "true" ]]; then
        input_information
    fi

    create_property_file

   
    # IF the variable UPDATE_COMPONENTS is set that means we are trying to update the list of deployment patterns or optional components 
    if [[ ! -z $UPDATE_COMPONENTS ]]; then
        update_property_files
    fi

    clean_up_temp_file
fi

###############################
## GENERATE MODE
###############################
if [[ $RUNTIME_MODE == "generate" ]]; then
    check_cp4ba_separate_operand $TARGET_PROJECT_NAME
    if [[ -n "${CP4BA_SERVICES_NS:-}" && "$TARGET_PROJECT_NAME" != "$CP4BA_SERVICES_NS" ]]; then
        printf '%b\n' "\x1B[1;31m[ERROR]\x1B[0m The -n value must be the CP4BA operand namespace in Separation-of-Duty deployments."
        printf '%b\n' "         Re-run: ./cp4a-prerequisites.sh -m ${RUNTIME_MODE} -n ${CP4BA_SERVICES_NS}"
        exit 1
    fi

    # reload db type and OS number
    load_property_before_generate
    
    if [[ "$ENABLE_VAULT_ON_EXIST" == "true" ]]; then
        validate_vault_props "$vault_enabled"
    fi

    if (( db_server_number > 0 )); then
        if [[ $DB_TYPE != "postgresql-edb" && "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
            # Import function for DB Script
            source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/fncm/create-fncm-dbscript.sh

            # Import function for DB Script
            source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/ban/create-ban-dbscript.sh

            # Import function for DB Script
            source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/baa/create-baa-dbscript.sh

            # Import function for DB Script
            source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/bas/create-bas-dbscript.sh

            # Import function for DB Script
            source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/baw-authoring/create-baw-dbscript.sh

            # Import function for DB Script
            source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/baw-aws/create-baw-aws-dbscript.sh

            # Import function for DB Script
            source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/odm/create-odm-dbscript.sh

            # Import function for DB Script
            if [[ $DB_TYPE == "postgresql" ]]; then
                source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/dicms/create-dicms-dbscript.sh
            fi

            if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            # Import function for DB Script
                source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/adp/create-adp-dbscript.sh
            fi
            
            # Note: PostgreSQL ADP script functions for ADPGG will be sourced later, right before they're needed
            # to avoid overwriting DB2/Oracle/SQL Server function definitions
            # check whether user already input value for the <Required>
        fi

        check_property_file

        if [[ $DB_TYPE != "postgresql-edb" && "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
            create_db_script
        fi
    fi

    create_prerequisites
    clean_up_temp_file

    if (( db_server_number > 0 )); then
        generate_create_secret_script
    fi

fi

###############################
## VALIDATE MODE
###############################
if [[ $RUNTIME_MODE == "validate" ]]; then
    echo  "*****************************************************"
    echo  "Validating the prerequisites before you install CP4BA"
    echo  "*****************************************************"
    check_cp4ba_separate_operand $TARGET_PROJECT_NAME
    if [[ -n "${CP4BA_SERVICES_NS:-}" && "$TARGET_PROJECT_NAME" != "$CP4BA_SERVICES_NS" ]]; then
        printf '%b\n' "\x1B[1;31m[ERROR]\x1B[0m The -n value must be the CP4BA operand namespace in Separation-of-Duty deployments."
        printf '%b\n' "         Re-run: ./cp4a-prerequisites.sh -m ${RUNTIME_MODE} -n ${CP4BA_SERVICES_NS}"
        exit 1
    fi
    
    validate_utility_tool_for_validation
    load_property_before_generate
    validate_prerequisites

    # if running only to enable Vault, we don't need to run storage performance tests
    if [[ "$ENABLE_VAULT_ON_EXIST" != "true" ]]; then
        storage_and_performance_validation_tests $TARGET_PROJECT_NAME
    fi
fi
################################################
#### End - Main step for install operator ####
################################################

