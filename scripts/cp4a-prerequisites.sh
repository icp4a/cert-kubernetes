#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2022. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh

# Import verification func
source ${CUR_DIR}/helper/cp4a-verification.sh

# Import variables for property file
source ${CUR_DIR}/helper/cp4ba-property.sh

# Import function for secret
source ${CUR_DIR}/helper/cp4ba-secret.sh

JDBC_DRIVER_DIR=${CUR_DIR}/jdbc
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
OPTIONAL_COMPONENT_FULL_ARR=("content_integration" "workstreams" "case" "business_orchestration" "ban" "bai" "css" "cmis" "es" "ier" "iccsap" "tm" "ums" "ads_designer" "ads_runtime" "app_designer" "decisionCenter" "decisionServerRuntime" "decisionRunner" "ae_data_persistence" "baw_authoring" "pfs" "baml" "auto_service" "document_processing_runtime" "document_processing_designer" "wfps_authoring" "kafka" "opensearch")

function show_help() {
    echo -e "\nUsage: cp4a-prerequisites.sh -m [modetype]\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -m  The valid mode types are: [property], [generate], or [validate]"
    echo "      STEP1: Run the script in [property] mode. Creates property files (DB/LDAP property file) with default values (database name/user)."
    echo "      STEP2: Modify the DB/LDAP/user property files with your values."
    echo "      STEP3: Run the script in [generate] mode. Generates the DB SQL statement files and YAML templates for the secrets based on the values in the property files."
    echo "      STEP4: Create the databases and secrets by using the modified DB SQL statement files and YAML templates for the secrets."
    echo "      STEP5: Run the script in [validate] mode. Checks whether the databases and the secrets are created before you install CP4BA."
}

function prompt_license(){
    # clear

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
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
                printf "\n"
                # while true; do
                #     if [[ $retVal_baw -eq 0 ]]; then
                #         printf "\n"
                #     fi
                #     if [[ $retVal_baw -eq 1 ]]; then
                #         printf "\x1B[1mDid you deploy Content CR (CRD: contents.icp4a.ibm.com) in current cluster? (Yes/No, default: No): \x1B[0m"
                #     fi
                #     read -rp "" ans
                #     case "$ans" in
                #     "y"|"Y"|"yes"|"Yes"|"YES")
                #         printf "\n"
                #         echo -e "\x1B[1;31mThe cp4a-deployment.sh can not work with existing Content CR together, exiting now...\x1B[0m\n"
                #         exit 1            
                        
                #         ;;
                #     "n"|"N"|"no"|"No"|"NO"|"")
                #         echo -e "Continuing...\n"
                #         break
                #         ;;
                #     *)
                #         echo -e "Answer must be \"Yes\" or \"No\"\n"
                #         ;;
                #     esac
                # done
            # echo -e "*****************************************************"
            # echo -e "**** Starting to prepare DB script for CP4BA ... ****"
            # echo -e "*****************************************************"
            # sleep 2
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

function validate_utility_tool_for_validation(){
    which kubectl &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI. You must install it to run this script.\x1B[0m" && \
        while true; do
            printf "\x1B[1mDo you want install the Kubernetes CLI by the cp4a-prerequisites.sh script? (Yes/No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_kubectl_cli
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                info "Must install the Kubernetes CLI to continue the next validation"
                exit 1
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi
    which java &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate java. You must install it to run this script.\x1B[0m" && \
        while true; do
            printf "\x1B[1mDo you want install the IBM JRE by the cp4a-prerequisites.sh script? (Yes/No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_ibm_jre
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                info "Must install the IBM JRE or other JRE to continue the next validation"
                exit 1
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    else
        java -version &>/dev/null
        if [[ $? -ne 0 ]]; then
            echo -e  "\x1B[1;31mUnable to locate a Java Runtime. You must install JRE to run this script.\x1B[0m" && \
            while true; do
                printf "\x1B[1mDo you want install the IBM JRE by the cp4a-prerequisites.sh script? (Yes/No): \x1B[0m"
                read -rp "" ans
                case "$ans" in
                "y"|"Y"|"yes"|"Yes"|"YES")
                    install_ibm_jre
                    break
                    ;;
                "n"|"N"|"no"|"No"|"NO")
                    info "Must install the IBM JRE or other JRE to continue next validation"
                    exit 1
                    ;;
                *)
                    echo -e "Answer must be \"Yes\" or \"No\"\n"
                    ;;
                esac
            done    
        fi
    fi
    which keytool &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate keytool. You must add it in \"\$PATH\" to run this script.\x1B[0m" && \
        exit 1
    else
        keytool -help &>/dev/null
        if [[ $? -ne 0 ]]; then
            echo -e  "\x1B[1;31mUnable to locate keytool. You must install the IBM JRE or other JRE and add keytool in \"\$PATH\" to run this script\x1B[0m" && \
            exit 1     
        fi
    fi

    which openssl &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate openssl. You must install it to run this script.\x1B[0m" && \
        while true; do
            printf "\x1B[1mDo you want install the OpenSSL by the cp4a-prerequisites.sh script? (Yes/No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_openssl
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                info "Must install the OpenSSL to continue next validation"
                exit 1
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
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
    pattern_starter_tips="\x1B[1mInfo: Except pattern (4/5), Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Business Automation foundation platform. \n\nTips:  After you make your first selection you will be able to make additional selections since you can combine multiple selections.\n\x1B[0m"
    pattern_production_tips="\x1B[1mInfo: Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Business Automation foundation platform. \n\nTips:  After you make your first selection you will be able to make additional selections since you can combine multiple selections.\n\x1B[0m"
    baw_iaws_tips="\x1B[1mInfo: Note that Business Automation Workflow Authoring (5a) cannot be installed together with Automation Workstream Services (6). However, Business Automation Workflow Runtime (5b) can be installed together with Automation Workstream Services (6).\n\x1B[0m"
    linux_starter_tips="\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mIBM Automation Document Processing (6) does NOT support a cluster running a Linux on Z (s390x)/Power architecture.\n\x1B[0m"
    linux_production_tips="\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mIBM Automation Document Processing (7a/7b) does NOT support a cluster running a Linux on Z (s390x)/Power architecture.\n\x1B[0m"
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
                    "8") # ADP
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "${choices_pattern[i]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                        ;;
                    "9") # for WfPS
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
    # echo -e "$msg"

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
        linux_starter_tips="\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mIBM Content Collector for SAP (4) does NOT support a cluster running a Linux on Power architecture.\n\x1B[0m"
        linux_production_tips="\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mIBM Content Collector for SAP (5) does NOT support a cluster running a Linux on Power architecture.\n\x1B[0m"
        ads_tips="\x1B[1mTips:\x1B[0m Decision Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present. \n\nDecision Runtime is typically recommended if you are deploying a test or production environment. \n\nYou should choose at least one these features to have a minimum environment configuration.\n"
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
                echo -e "\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31m You must select at least one of ODM components\x1B[0m.\n"
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
                elif [[ "${optional_components_list[i]}" == "Business Orchestration" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "BusinessOrchestration" ); msg=""; }
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
                    elif [[ "${optional_components_list[i]}" == "Content Integration" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ContentIntegration" )
                    elif [[ "${optional_components_list[i]}" == "IBM Content Navigator" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "IBMContentNavigator" )
                    elif [[ "${optional_components_list[i]}" == "Business Orchestration" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "BusinessOrchestration" )
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
            echo -e "***************** example *****************"
            echo -e "if DB_SERVER_LIST=\"DBSERVER1\""
            echo -e "You need to change"
            echo -e "<DB_SERVER_NAME>.GCD_DB_NAME=\"GCDDB\""
            echo -e "to"
            echo -e "DBSERVER1.GCD_DB_NAME=\"GCDDB\""
            echo -e "***************** example *****************"
            exit 1
        fi
    fi
}

function check_property_file(){
    local empty_value_tag=0
    value_empty=`grep '="<Required>"' "${USER_PROFILE_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<Required>\" in property file \"${USER_PROFILE_PROPERTY_FILE}\", please input the correct value."
        empty_value_tag=1
    fi

    value_empty=`grep '="<Required>"' "${DB_SERVER_INFO_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<Required>\" in property file \"${DB_SERVER_INFO_PROPERTY_FILE}\", please input the correct value."
        empty_value_tag=1
    fi

    value_empty=`grep '^<DB_SERVER_NAME>.' "${DB_NAME_USER_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Please change prefix \"<DB_SERVER_NAME>\" to assign database used by component to which database server or instance in property file \"${DB_NAME_USER_PROPERTY_FILE}\"."
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

    # check ADP_PROJECT_DB_SERVER contain <DB_SERVER_NAME>
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        tmp_dbserver="$(prop_db_name_user_property_file ADP_PROJECT_DB_SERVER)"
        tmp_dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbserver")
        value_empty=`echo $tmp_dbserver | grep '<DB_SERVER_NAME>' | wc -l`  >/dev/null 2>&1
        if [ $value_empty -ne 0 ] ; then
            error "Please change \"<DB_SERVER_NAME>\" for \"ADP_PROJECT_DB_SERVER\" parameter to assign database used by component to which database server or instance in property file \"${DB_NAME_USER_PROPERTY_FILE}\"."
            empty_value_tag=1
        fi
    fi

    value_empty=`grep '="<Required>"' "${DB_NAME_USER_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<Required>\" in property file \"${DB_NAME_USER_PROPERTY_FILE}\", please input the correct value."
        empty_value_tag=1
    fi

    value_empty=`grep -v '^# .*.CHOS_DB_USER_PASSWORD="<yourpassword>"' "${DB_NAME_USER_PROPERTY_FILE}" | grep '="<yourpassword>"' | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<yourpassword>\" in property file \"${DB_NAME_USER_PROPERTY_FILE}\", please input the correct value."
        empty_value_tag=1
    fi

    value_empty=`grep -v '^# .*.CHOS_DB_USER_NAME="<youruser1>"' "${DB_NAME_USER_PROPERTY_FILE}" | grep '="<youruser1>"' | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<youruser1>\" in property file \"${DB_NAME_USER_PROPERTY_FILE}\", please input the correct value."
        empty_value_tag=1
    fi

    value_empty=`grep '="<Required>"' "${LDAP_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<Required>\" in property file \"${LDAP_PROPERTY_FILE}\", please input the correct value."
        empty_value_tag=1
    fi

    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        value_empty=`grep '="<Required>"' "${EXTERNAL_LDAP_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
        if [ $value_empty -ne 0 ] ; then
            error "Found invalid value(s) \"<Required>\" in property file \"${EXTERNAL_LDAP_PROPERTY_FILE}\", please input the correct value."
            empty_value_tag=1
        fi
    fi

    # check prefix in db property is correct element of DB_SERVER_LIST
    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    # check DB_NAME_USER_PROPERTY_FILE
    prefix_array=($(grep '=\"' ${DB_NAME_USER_PROPERTY_FILE} | cut -d'=' -f1 | cut -d'.' -f1 | grep -Ev 'ADP_PROJECT_DB_NAME|ADP_PROJECT_DB_SERVER|ADP_PROJECT_DB_USER_NAME|ADP_PROJECT_DB_USER_PASSWORD|ADP_PROJECT_ONTOLOGY'))
    for item in ${prefix_array[*]}
    do
        if [[ ! ( "${item}" == \#* ) ]]; then
            if [[ ! (" ${db_server_array[@]}" =~ "${item}") ]]; then
                error "The prefix \"$item\" is not in the definition DB_SERVER_LIST=\"${tmp_db_array}\", please check follow example to configure \"${DB_NAME_USER_PROPERTY_FILE}\" again."
                echo -e "***************** example *****************"
                echo -e "if DB_SERVER_LIST=\"DBSERVER1\""
                echo -e "You need to change"
                echo -e "<DB_SERVER_NAME>.GCD_DB_NAME=\"GCDDB\""
                echo -e "to"
                echo -e "DBSERVER1.GCD_DB_NAME=\"GCDDB\""
                echo -e "***************** example *****************"
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
            echo -e "********************* example *********************"
            echo -e "if DB_SERVER_LIST=\"DBSERVER1\""
            echo -e "You need to change"
            echo -e "<DB_SERVER_NAME>.DATABASE_SERVERNAME=\"samplehost\""
            echo -e "to"
            echo -e "DBSERVER1.DATABASE_SERVERNAME=\"samplehost\""
            echo -e "********************* example *********************"
            empty_value_tag=1
            break
        fi
    done

    if [[ "$empty_value_tag" == "1" ]]; then
        exit 1
    fi

    # Check the PostgreSQL DATABASE_SSL_ENABLE/POSTGRESQL_SSL_CLIENT_SERVER
    for item in ${db_server_array[*]}
    do
        db_ssl_flag="$(prop_db_server_property_file ${item}.DATABASE_SSL_ENABLE)"
        client_auth_flag="$(prop_db_server_property_file ${item}.POSTGRESQL_SSL_CLIENT_SERVER)"
        db_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$db_ssl_flag")
        client_auth_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$client_auth_flag")
        db_ssl_flag_tmp=$(echo $db_ssl_flag | tr '[:upper:]' '[:lower:]')
        client_auth_flag_tmp=$(echo $client_auth_flag | tr '[:upper:]' '[:lower:]')
        if [[ ($db_ssl_flag_tmp == "no" || $db_ssl_flag_tmp == "false" || $db_ssl_flag_tmp == "" || -z $db_ssl_flag_tmp) && ($client_auth_flag_tmp == "yes" || $client_auth_flag_tmp == "true") ]]; then
            error "The property \"${item}.DATABASE_SSL_ENABLE\" is \"$db_ssl_flag\", but the property \"${item}.POSTGRESQL_SSL_CLIENT_SERVER\" is \"$client_auth_flag\""
            echo -e "********************* example *********************"
            echo -e "if ${item}.DATABASE_SSL_ENABLE=\"False\""
            echo -e "You also need to change"
            echo -e "${item}.POSTGRESQL_SSL_CLIENT_SERVER=\"False\""
            echo -e "********************* example *********************"
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
                    error "the IPv6 address ${server_name} must be enclosed with square brackets ([...]) for the property DATABASE_SERVERNAME in the file \"${DB_SERVER_INFO_PROPERTY_FILE}\""
                    error_value_tag=1
                fi
            elif [[ ${server_name:0:1} == "[" ]] ; then
                # For IPv4 addresses, make sure they have not included brackets
                error "the IPv4 address ${server_name} should NOT be enclosed with square brackets ([...]) for the property DATABASE_SERVERNAME in the file \"${DB_SERVER_INFO_PROPERTY_FILE}\""
                error_value_tag=1
            fi
        else
            db_check=$(echo $db_type | tr '[:upper:]' '[:lower:]')
            if [[ $db_check != 'oracle' ]]; then
                error "the value is NULL for the property DATABASE_SERVERNAME in the file \"${DB_SERVER_INFO_PROPERTY_FILE}\""
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
    fips_flag=$(echo $fips_flag | tr '[:upper:]' '[:lower:]')

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
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        im_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        im_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$im_external_db_cert_folder")
        cert_dir_array=( "${cert_dir_array[@]}" "${im_external_db_cert_folder}" )
    fi

    # Zen metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_ZEN_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        zen_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        zen_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$zen_external_db_cert_folder")
        cert_dir_array=( "${cert_dir_array[@]}" "${zen_external_db_cert_folder}" )
    fi

    # BTS metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_BTS_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        bts_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        bts_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$bts_external_db_cert_folder")
        cert_dir_array=( "${cert_dir_array[@]}" "${bts_external_db_cert_folder}" )
    fi
    # Issuer to make Opensearch/Kafka use external certificate
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_CERT_OPENSEARCH_KAFKA_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        external_cert_issuer_folder="$(prop_user_profile_property_file CP4BA.EXTERNAL_ROOT_CA_FOR_OPENSEARCH_KAFKA_FOLDER)"
        external_cert_issuer_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$external_cert_issuer_folder")
        cert_dir_array=( "${cert_dir_array[@]}" "${external_cert_issuer_folder}" )
    fi

    declare -A dir_count
    for element in "${cert_dir_array[@]}"; do
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

    if [[ "$error_value_tag" == "1" ]]; then
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
    INFO "Generating YAML template for secret required by CP4BA deployment based on property file"
    printf "\n"
    wait_msg "Creating YAML template for secret"

    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "No") ]]; then
        # Create LDAP bind secret
        create_ldap_secret_template
        #  replace ldap user
        tmp_dbuser="$(prop_ldap_property_file LDAP_BIND_DN)"
        ${SED_COMMAND} "s|\"<LDAP_BIND_DN>\"|\"$tmp_dbuser\"|g" ${LDAP_SECRET_FILE}

        tmp_ldapuserpwd="$(prop_ldap_property_file LDAP_BIND_DN_PASSWORD)"
        if [[ "${tmp_ldapuserpwd:0:8}" == "{Base64}"  ]]; then
            temp_val=$(echo "$tmp_ldapuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
            check_single_quotes_password $temp_val "LDAP_BIND_DN_PASSWORD"
            ${SED_COMMAND} "s|\"<LDAP_PASSWORD>\"|'$(printf '%q' $temp_val)'|g" ${LDAP_SECRET_FILE}
        else
            ${SED_COMMAND} "s|\"<LDAP_PASSWORD>\"|\"$tmp_ldapuserpwd\"|g" ${LDAP_SECRET_FILE}
        fi
        # ${SED_COMMAND} "s|\"<LDAP_PASSWORD>\"|\"$tmp_dbuserpwd\"|g" ${LDAP_SECRET_FILE}

        # Create LDAP bind secret for external share
        if [[ $SET_EXT_LDAP == "Yes" ]]; then
            create_ext_ldap_secret_template
            #  replace ldap user
            tmp_dbuser="$(prop_ext_ldap_property_file LDAP_BIND_DN)"
            ${SED_COMMAND} "s|\"<LDAP_BIND_DN>\"|\"$tmp_dbuser\"|g" ${EXT_LDAP_SECRET_FILE}

            tmp_ldapuserpwd="$(prop_ext_ldap_property_file LDAP_BIND_DN_PASSWORD)"
            if [[ "${tmp_ldapuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_ldapuserpwd" | sed -e "s/^{Base64}//" | base64 --decode) 
                check_single_quotes_password $temp_val "LDAP_BIND_DN_PASSWORD"
                ${SED_COMMAND} "s|\"<LDAP_PASSWORD>\"|'$(printf '%q' $temp_val)'|g" ${EXT_LDAP_SECRET_FILE}
            else
                ${SED_COMMAND} "s|\"<LDAP_PASSWORD>\"|\"$tmp_ldapuserpwd\"|g" ${EXT_LDAP_SECRET_FILE}
            fi
            # ${SED_COMMAND} "s|\"<LDAP_PASSWORD>\"|\"$tmp_dbuserpwd\"|g" ${EXT_LDAP_SECRET_FILE}

        fi
    fi

    # Create FNCM secret
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then

        wait_msg "Creating ibm-fncm-secret secret YAML template for CP4BA"
        # get server/instance for GCD
        tmp_gcd_db_servername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
        tmp_gcd_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_gcd_db_servername")

        check_dbserver_name_valid $tmp_gcd_db_servername "GCD_DB_USER_NAME"

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file GCD_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
        fi

        create_fncm_secret_template $tmp_gcd_db_servername

        # replace appLoginUsername/appLoginPassword
        tmp_appuser="$(prop_user_profile_property_file CONTENT.APPLOGIN_USER)"
        tmp_apppwd="$(prop_user_profile_property_file CONTENT.APPLOGIN_PASSWORD)"
        ${SED_COMMAND} "s|appLoginUsername:.*|appLoginUsername: \"$tmp_appuser\"|g" ${FNCM_SECRET_FILE}
        # ${SED_COMMAND} "s|appLoginPassword:.*|appLoginPassword: \"$tmp_apppwd\"|g" ${FNCM_SECRET_FILE}
        if [[ "${tmp_apppwd:0:8}" == "{Base64}"  ]]; then
            temp_val=$(echo "$tmp_apppwd" | sed -e "s/^{Base64}//" | base64 --decode) 
            check_single_quotes_password $temp_val "CONTENT.APPLOGIN_PASSWORD"
            ${SED_COMMAND} "s|appLoginPassword:.*|appLoginPassword: '$(printf '%q' $temp_val)'|g" ${FNCM_SECRET_FILE}
        else
            ${SED_COMMAND} "s|appLoginPassword:.*|appLoginPassword: \"$tmp_apppwd\"|g" ${FNCM_SECRET_FILE}
        fi

        # replace ltpaPassword/keystorePassword for FNCM
        tmp_ltpapwd="$(prop_user_profile_property_file CONTENT.LTPA_PASSWORD)"
        tmp_kestorepwd="$(prop_user_profile_property_file CONTENT.KEYSTORE_PASSWORD)"
            if [[ "${tmp_ltpapwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_ltpapwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "CONTENT.LTPA_PASSWORD"
                ${SED_COMMAND} "s|ltpaPassword:.*|ltpaPassword: '$(printf '%q' $temp_val)'|g" ${FNCM_SECRET_FILE}
            else
                ${SED_COMMAND} "s|ltpaPassword:.*|ltpaPassword: \"$tmp_ltpapwd\"|g" ${FNCM_SECRET_FILE}
            fi
            # ${SED_COMMAND} "s|ltpaPassword:.*|ltpaPassword: \"$tmp_ltpapwd\"|g" ${BAN_SECRET_FILE}
            if [[ "${tmp_kestorepwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_kestorepwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "CONTENT.KEYSTORE_PASSWORD"
                ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: '$(printf '%q' $temp_val)'|g" ${FNCM_SECRET_FILE}
            else
                ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: \"$tmp_kestorepwd\"|g" ${FNCM_SECRET_FILE}
            fi
        # ${SED_COMMAND} "s|ltpaPassword:.*|ltpaPassword: \"$tmp_ltpapwd\"|g" ${FNCM_SECRET_FILE}
        # ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: \"$tmp_kestorepwd\"|g" ${FNCM_SECRET_FILE}

        #  replace gcddb user
        tmp_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
        ${SED_COMMAND} "s|\"<GCD_DB_USER_NAME>\"|$tmp_dbuser|g" ${FNCM_SECRET_FILE}

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_gcd_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
            ${SED_COMMAND} '/^  gcdDBPassword/d' ${FNCM_SECRET_FILE}
        else
            tmp_dbuserpwd="$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)"
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                check_single_quotes_password $temp_val "GCD_DB_USER_PASSWORD"
                ${SED_COMMAND} "s|\"<GCD_DB_USER_PASSWORD>\"|'$(printf '%q' $temp_val)'|g" ${FNCM_SECRET_FILE}
            else
                ${SED_COMMAND} "s|\"<GCD_DB_USER_PASSWORD>\"|$tmp_dbuserpwd|g" ${FNCM_SECRET_FILE}
            fi
        fi
        # support multiple db server/instance in ibm-fncm-secret
        # add dc_os_lable in ibm-fncm-secret for final cr
        # add os
        nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
        if (( content_os_number > 0 )); then
            for ((j=0;j<$((content_os_number));j++))
            do
                # get server/instance for OS
                tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name OS$((j+1))_DB_USER_NAME)"
                tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
                check_dbserver_name_valid $tmp_os_db_servername "OS$((j+1))_DB_USER_NAME"

                # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
                if [[ $DB_TYPE = "postgresql" ]]; then
                    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                    tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
                fi

                if [[ $DB_TYPE = "postgresql-edb" ]]; then
                    tmp_postgresql_client_flag="true"
                fi

                tmp_dbuserpwd="$(prop_db_name_user_property_file OS$((j+1))_DB_USER_PASSWORD)"
                tmp_dbuser="$(prop_db_name_user_property_file OS$((j+1))_DB_USER_NAME)"
                if [[ "$machine" == "Mac" ]]; then
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $temp_val "OS$((j+1))_DB_USER_PASSWORD"
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  os$((j+1))DBPassword: '$(printf '%q' $temp_val)'\\${nl}" ${FNCM_SECRET_FILE}                    
                    else
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  os$((j+1))DBPassword: $tmp_dbuserpwd\\${nl}" ${FNCM_SECRET_FILE}
                    fi
                    fi
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  os$((j+1))DBUsername: $tmp_dbuser\\${nl}" ${FNCM_SECRET_FILE}
                else
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                        if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                            temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                            check_single_quotes_password $temp_val "OS$((j+1))_DB_USER_PASSWORD"
                            ${SED_COMMAND} "/^  osDBPassword: .*/a\  os$((j+1))DBPassword: '$(printf '%q' $temp_val)'" ${FNCM_SECRET_FILE}
                        else
                            ${SED_COMMAND} "/^  osDBPassword: .*/a\  os$((j+1))DBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}
                        fi
                    fi
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\  os$((j+1))DBUsername: $tmp_dbuser" ${FNCM_SECRET_FILE}
                fi
            done
        fi
        # add aeos 
        if [[ "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
            # get server/instance for OS
            tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name AEOS_DB_USER_NAME)"
            tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
            check_dbserver_name_valid $tmp_os_db_servername "AEOS_DB_USER_NAME"

            # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
            if [[ $DB_TYPE = "postgresql" ]]; then
                tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
            fi

            if [[ $DB_TYPE = "postgresql-edb" ]]; then
                tmp_postgresql_client_flag="true"
            fi

            #  replace aeos user
            tmp_dbuserpwd="$(prop_db_name_user_property_file AEOS_DB_USER_PASSWORD)"
            tmp_dbuser="$(prop_db_name_user_property_file AEOS_DB_USER_NAME)"
            if [[ "$machine" == "Mac" ]]; then
                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                check_single_quotes_password $temp_val "AEOS_DB_USER_PASSWORD"
                ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  aeosDBPassword: '$(printf '%q' $temp_val)'\\${nl}" ${FNCM_SECRET_FILE}
                else
                ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  aeosDBPassword: $tmp_dbuserpwd\\${nl}" ${FNCM_SECRET_FILE}
                fi
                fi
                ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  aeosDBUsername: $tmp_dbuser\\${nl}" ${FNCM_SECRET_FILE}
            else
                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)   
                        check_single_quotes_password $temp_val "AEOS_DB_USER_PASSWORD"             
                        ${SED_COMMAND} "/^  osDBPassword: .*/a\  aeosDBPassword: '$(printf '%q' $temp_val)'" ${FNCM_SECRET_FILE}
                    else
                        ${SED_COMMAND} "/^  osDBPassword: .*/a\  aeosDBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}                
                    fi
                fi
                ${SED_COMMAND} "/^  osDBPassword: .*/a\  aeosDBUsername: $tmp_dbuser" ${FNCM_SECRET_FILE}
            fi
        fi

        # add baw authoring/ baw runtime / bas+ aws os
        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workflow-runtime" ]]; then
            for i in "${!BAW_AUTH_OS_ARR[@]}"; do
                # get server/instance for OS
                tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
                check_dbserver_name_valid $tmp_os_db_servername "${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME"

                # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
                if [[ $DB_TYPE = "postgresql" ]]; then
                    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                    tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
                fi

                if [[ $DB_TYPE = "postgresql-edb" ]]; then
                    tmp_postgresql_client_flag="true"
                fi

                tmp_dbuser="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                tmp_val=$(echo ${BAW_AUTH_OS_ARR[i]} | tr '[:upper:]' '[:lower:]')
                tmp_dbuserpwd="$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD)"
                if [[ "$machine" == "Mac" ]]; then
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    temp_pwd_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $temp_val "${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD"
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  ${tmp_val}DBPassword: '$(printf '%q' $temp_pwd_val)'\\${nl}" ${FNCM_SECRET_FILE}
                    else
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  ${tmp_val}DBPassword: $tmp_dbuserpwd\\${nl}" ${FNCM_SECRET_FILE}
                    fi
                    fi
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  ${tmp_val}DBUsername: $tmp_dbuser\\${nl}" ${FNCM_SECRET_FILE}
                else
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                        if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                            temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                            check_single_quotes_password $temp_val "${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD"
                            ${SED_COMMAND} "/^  osDBPassword: .*/a\  ${tmp_val}DBPassword: '$(printf '%q' $temp_val)'" ${FNCM_SECRET_FILE}
                        else
                            ${SED_COMMAND} "/^  osDBPassword: .*/a\  ${tmp_val}DBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}
                        fi
                    # ${SED_COMMAND} "/^  osDBPassword: .*/a\  ${tmp_val}DBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}
                    fi
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\  ${tmp_val}DBUsername: $tmp_dbuser" ${FNCM_SECRET_FILE}
                fi
            done
            if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
                # get server/instance for OS
                tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
                tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
                check_dbserver_name_valid $tmp_os_db_servername "AWSDOCS_DB_USER_NAME"

                # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
                if [[ $DB_TYPE = "postgresql" ]]; then
                    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                    tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
                fi

                if [[ $DB_TYPE = "postgresql-edb" ]]; then
                    tmp_postgresql_client_flag="true"
                fi

                tmp_dbuserpwd="$(prop_db_name_user_property_file AWSDOCS_DB_USER_PASSWORD)"
                tmp_dbuser="$(prop_db_name_user_property_file AWSDOCS_DB_USER_NAME)"
                if [[ "$machine" == "Mac" ]]; then
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $temp_val "AWSDOCS_DB_USER_PASSWORD"
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  awsdocsDBPassword: '$(printf '%q' $temp_val)'\\${nl}" ${FNCM_SECRET_FILE}
                    else
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  awsdocsDBPassword: $tmp_dbuserpwd\\${nl}" ${FNCM_SECRET_FILE}
                    fi
                    fi
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  awsdocsDBUsername: $tmp_dbuser\\${nl}" ${FNCM_SECRET_FILE}
                else
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                        if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                            temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                            check_single_quotes_password $temp_val "AWSDOCS_DB_USER_PASSWORD"
                            ${SED_COMMAND} "/^  osDBPassword: .*/a\  awsdocsDBPassword: '$(printf '%q' $temp_val)'" ${FNCM_SECRET_FILE}
                        else
                            ${SED_COMMAND} "/^  osDBPassword: .*/a\  awsdocsDBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}
                        fi
                    # ${SED_COMMAND} "/^  osDBPassword: .*/a\  awsdocsDBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}
                    fi
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\  awsdocsDBUsername: $tmp_dbuser" ${FNCM_SECRET_FILE}
                fi
            fi
        fi

            # add AWS os
        if [[ " ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams") ]]; then
            # get server/instance for OS
            tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
            tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
            check_dbserver_name_valid $tmp_os_db_servername "AWSDOCS_DB_USER_NAME"

            # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
            if [[ $DB_TYPE = "postgresql" ]]; then
                tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
            fi

            if [[ $DB_TYPE = "postgresql-edb" ]]; then
                tmp_postgresql_client_flag="true"
            fi

            tmp_dbuserpwd="$(prop_db_name_user_property_file AWSDOCS_DB_USER_PASSWORD)"
            tmp_dbuser="$(prop_db_name_user_property_file AWSDOCS_DB_USER_NAME)"
            if [[ "$machine" == "Mac" ]]; then
                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                check_single_quotes_password $temp_val "AWSDOCS_DB_USER_PASSWORD"
                ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  awsdocsDBPassword: '$(printf '%q' $temp_val)'\\${nl}" ${FNCM_SECRET_FILE}
                else
                ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  awsdocsDBPassword: $tmp_dbuserpwd\\${nl}" ${FNCM_SECRET_FILE}
                fi
                fi
                ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  awsdocsDBUsername: $tmp_dbuser\\${nl}" ${FNCM_SECRET_FILE}
            else
                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $temp_val "AWSDOCS_DB_USER_PASSWORD"
                        ${SED_COMMAND} "/^  osDBPassword: .*/a\  awsdocsDBPassword: '$(printf '%q' $temp_val)'" ${FNCM_SECRET_FILE}
                    else
                        ${SED_COMMAND} "/^  osDBPassword: .*/a\  awsdocsDBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}
                    fi
                # ${SED_COMMAND} "/^  osDBPassword: .*/a\  awsdocsDBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}
                fi
                ${SED_COMMAND} "/^  osDBPassword: .*/a\  awsdocsDBUsername: $tmp_dbuser" ${FNCM_SECRET_FILE}
            fi
        fi

            # add Case History os
        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
            # get server/instance for OS
            tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name CHOS_DB_USER_NAME)"
            tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
            
            if [[ $tmp_os_db_servername != \#* ]] ; then
                check_dbserver_name_valid $tmp_os_db_servername "CHOS_DB_USER_NAME"

                # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
                if [[ $DB_TYPE = "postgresql" ]]; then
                    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                    tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
                fi

                if [[ $DB_TYPE = "postgresql-edb" ]]; then
                    tmp_postgresql_client_flag="true"
                fi

                tmp_dbuserpwd="$(prop_db_name_user_property_file CHOS_DB_USER_PASSWORD)"
                tmp_dbuser="$(prop_db_name_user_property_file CHOS_DB_USER_NAME)"
                if [[ "$machine" == "Mac" ]]; then
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $temp_val "CHOS_DB_USER_PASSWORD"
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
chDBPassword: '$(printf '%q' $temp_val)'\\${nl}" ${FNCM_SECRET_FILE}
                    else
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
chDBPassword: $tmp_dbuserpwd\\${nl}" ${FNCM_SECRET_FILE}
                    fi
                    fi
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
chDBUsername: $tmp_dbuser\\${nl}" ${FNCM_SECRET_FILE}
                else
                    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                    if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                        if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                            temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)    
                            check_single_quotes_password $temp_val "CHOS_DB_USER_PASSWORD"            
                            ${SED_COMMAND} "/^  osDBPassword: .*/a\  chDBPassword: '$(printf '%q' $temp_val)'" ${FNCM_SECRET_FILE}
                        else
                            ${SED_COMMAND} "/^  osDBPassword: .*/a\  chDBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}                
                        fi
                    # ${SED_COMMAND} "/^  osDBPassword: .*/a\  chDBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}
                    fi
                    ${SED_COMMAND} "/^  osDBPassword: .*/a\  chDBUsername: $tmp_dbuser" ${FNCM_SECRET_FILE}
                fi
            fi
        fi

            # add Dev os for ADP
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
            # get server/instance for OS
            tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name DEVOS_DB_USER_NAME)"
            tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
            check_dbserver_name_valid $tmp_os_db_servername "DEVOS_DB_USER_NAME"

            # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
            if [[ $DB_TYPE = "postgresql" ]]; then
                tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
                tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
            fi

            if [[ $DB_TYPE = "postgresql-edb" ]]; then
                tmp_postgresql_client_flag="true"
            fi

            tmp_dbuserpwd="$(prop_db_name_user_property_file DEVOS_DB_USER_PASSWORD)"
            tmp_dbuser="$(prop_db_name_user_property_file DEVOS_DB_USER_NAME)"
            if [[ "$machine" == "Mac" ]]; then
                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                check_single_quotes_password $temp_val "DEVOS_DB_USER_PASSWORD"
                ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  devos1DBPassword: '$(printf '%q' $temp_val)'\\${nl}" ${FNCM_SECRET_FILE}
                else
                ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  devos1DBPassword: $tmp_dbuserpwd\\${nl}" ${FNCM_SECRET_FILE}
                fi
                fi
                ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  devos1DBUsername: $tmp_dbuser\\${nl}" ${FNCM_SECRET_FILE}
            else
                # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
                if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)   
                        check_single_quotes_password $temp_val "DEVOS_DB_USER_PASSWORD"             
                        ${SED_COMMAND} "/^  osDBPassword: .*/a\  devos1DBPassword: '$(printf '%q' $temp_val)'" ${FNCM_SECRET_FILE}
                    else
                        ${SED_COMMAND} "/^  osDBPassword: .*/a\  devos1DBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}                
                    fi
                # ${SED_COMMAND} "/^  osDBPassword: .*/a\  devos1DBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}
                fi
                ${SED_COMMAND} "/^  osDBPassword: .*/a\  devos1DBUsername: $tmp_dbuser" ${FNCM_SECRET_FILE}
            fi
        fi
        ${SED_COMMAND} '/^  osDBUsername/d' ${FNCM_SECRET_FILE}
        ${SED_COMMAND} '/^  osDBPassword/d' ${FNCM_SECRET_FILE}

        success "Created ibm-fncm-secret secret YAML template for CP4BA\n"
        # If select ICCSAP
        if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
            wait_msg "Creating ibm-iccsap-secret secret YAML template for CP4BA"
            create_fncm_iccsap_secret_template

            # replace keystorePassword for ICCSAP
            tmp_kestorepwd="$(prop_user_profile_property_file ICCSAP.KEYSTORE_PASSWORD)"
            if [[ "${tmp_kestorepwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_kestorepwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "ICCSAP.KEYSTORE_PASSWORD"
                ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: '$(printf '%q' $temp_val)'|g" ${FNCM_ICCSAP_SECRET_FILE}
            else
                ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: \"$tmp_kestorepwd\"|g" ${FNCM_ICCSAP_SECRET_FILE}
            fi

            success "Created ibm-iccsap-secret secret YAML template for CP4BA\n"
        fi
        # If select ICC Archive
        if [[ " ${optional_component_cr_arr[@]} " =~ "css" ]]; then
            wait_msg "Creating ibm-icc-secret secret YAML template for CP4BA"
            create_fncm_icc_secret_template

            # replace keystorePassword for ICCSAP
            tmp_archive_id="$(prop_user_profile_property_file CONTENT.ARCHIVE_USER_ID)"
            ${SED_COMMAND} "s|archiveUserId:.*|archiveUserId: \"$tmp_archive_id\"|g" ${FNCM_ICC_SECRET_FILE}

            tmp_archive_pwd="$(prop_user_profile_property_file CONTENT.ARCHIVE_USER_PASSWORD)"
            if [[ "${tmp_archive_pwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_archive_pwd" | sed -e "s/^{Base64}//" | base64 --decode) 
                check_single_quotes_password $temp_val "CONTENT.ARCHIVE_USER_PASSWORD"
                ${SED_COMMAND} "s|archivePassword:.*|archivePassword: '$(printf '%q' $temp_val)'|g" ${FNCM_ICC_SECRET_FILE}
            else
                ${SED_COMMAND} "s|archivePassword:.*|archivePassword: \"$tmp_archive_pwd\"|g" ${FNCM_ICC_SECRET_FILE}
            fi

            success "Created ibm-icc-secret secret YAML template for CP4BA\n"
        fi

        # if select IER
        if [[ " ${optional_component_cr_arr[@]} " =~ "ier" ]]; then
            wait_msg "Creating ibm-ier-secret secret YAML template for CP4BA"
            create_fncm_ier_secret_template

            # replace keystorePassword for IER
            tmp_kestorepwd="$(prop_user_profile_property_file IER.KEYSTORE_PASSWORD)"
            if [[ "${tmp_kestorepwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_kestorepwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "IER.KEYSTORE_PASSWORD"
                ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: '$(printf '%q' $temp_val)'|g" ${FNCM_IER_SECRET_FILE}
            else
                ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: \"$tmp_kestorepwd\"|g" ${FNCM_IER_SECRET_FILE}
            fi
            # ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: \"$tmp_kestorepwd\"|g" ${FNCM_IER_SECRET_FILE}

            success "Created ibm-ier-secret secret YAML template for CP4BA\n"
        fi
    fi

    # Create BAN secret
    if [[ " ${foundation_component_arr[@]}" =~ "BAN" ]]; then
        if [[ ! (" ${pattern_cr_arr[@]} " =~ "workstreams" && "${#pattern_cr_arr[@]}" -eq "1") ]]; then
            wait_msg "Creating ibm-ban-secret secret YAML template for CP4BA"

            # get server/instance for ICN
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
            tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
            check_dbserver_name_valid $tmp_dbservername "ICN_DB_USER_NAME"

            # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
            if [[ $DB_TYPE = "postgresql" ]]; then
                tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
                tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
            fi

            if [[ $DB_TYPE = "postgresql-edb" ]]; then
                tmp_postgresql_client_flag="true"
            fi

            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file ICN_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
            fi

            create_ban_secret_template $tmp_dbname $tmp_dbservername
        
            # replace appLoginUsername/appLoginPassword
            tmp_appuser="$(prop_user_profile_property_file BAN.APPLOGIN_USER)"
            tmp_apppwd="$(prop_user_profile_property_file BAN.APPLOGIN_PASSWORD)"
            ${SED_COMMAND} "s|appLoginUsername:.*|appLoginUsername: \"$tmp_appuser\"|g" ${BAN_SECRET_FILE}
            if [[ "${tmp_apppwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_apppwd" | sed -e "s/^{Base64}//" | base64 --decode) 
                check_single_quotes_password $temp_val "BAN.APPLOGIN_PASSWORD"
                ${SED_COMMAND} "s|appLoginPassword:.*|appLoginPassword: '$(printf '%q' $temp_val)'|g" ${BAN_SECRET_FILE}
            else
                ${SED_COMMAND} "s|appLoginPassword:.*|appLoginPassword: \"$tmp_apppwd\"|g" ${BAN_SECRET_FILE}
            fi

            # replace ltpaPassword/keystorePassword for FNCM
            tmp_ltpapwd="$(prop_user_profile_property_file BAN.LTPA_PASSWORD)"
            tmp_kestorepwd="$(prop_user_profile_property_file BAN.KEYSTORE_PASSWORD)"
            if [[ "${tmp_ltpapwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_ltpapwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "BAN.LTPA_PASSWORD"
                ${SED_COMMAND} "s|ltpaPassword:.*|ltpaPassword: '$(printf '%q' $temp_val)'|g" ${BAN_SECRET_FILE}
            else
                ${SED_COMMAND} "s|ltpaPassword:.*|ltpaPassword: \"$tmp_ltpapwd\"|g" ${BAN_SECRET_FILE}
            fi
            # ${SED_COMMAND} "s|ltpaPassword:.*|ltpaPassword: \"$tmp_ltpapwd\"|g" ${BAN_SECRET_FILE}
            if [[ "${tmp_kestorepwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_kestorepwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "BAN.KEYSTORE_PASSWORD"
                ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: '$(printf '%q' $temp_val)'|g" ${BAN_SECRET_FILE}
            else
                ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: \"$tmp_kestorepwd\"|g" ${BAN_SECRET_FILE}
            fi
            # ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: \"$tmp_kestorepwd\"|g" ${BAN_SECRET_FILE}

            # replace ltpaPassword/keystorePassword for FNCM
            tmp_appuser="$(prop_user_profile_property_file BAN.JMAIL_USER_NAME)"
            tmp_apppwd="$(prop_user_profile_property_file BAN.JMAIL_USER_PASSWORD)"

            tmp_appuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_appuser")
            tmp_apppwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_apppwd")

            if [[ ! ($tmp_appuser == "<Optional>" || $tmp_appuser == "<Optional>") ]]; then
                ${SED_COMMAND} "s|jMailUsername:.*|jMailUsername: \"$tmp_appuser\"|g" ${BAN_SECRET_FILE}
                if [[ "${tmp_apppwd:0:8}" == "{Base64}"  ]]; then
                    temp_val=$(echo "$tmp_apppwd" | sed -e "s/^{Base64}//" | base64 --decode) 
                    check_single_quotes_password $temp_val "BAN.JMAIL_USER_PASSWORD"
                    ${SED_COMMAND} "s|jMailPassword:.*|jMailPassword: '$(printf '%q' $temp_val)'|g" ${BAN_SECRET_FILE}
                else
                    ${SED_COMMAND} "s|jMailPassword:.*|jMailPassword: \"$tmp_apppwd\"|g" ${BAN_SECRET_FILE}
                fi
            fi

            #  replace icndb user
            tmp_dbuser="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
            ${SED_COMMAND} "s|\"<ICN_DB_USER_NAME>\"|$tmp_dbuser|g" ${BAN_SECRET_FILE}

            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
            if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
                ${SED_COMMAND} '/^  navigatorDBPassword/d' ${BAN_SECRET_FILE}
            else
                tmp_dbuserpwd="$(prop_db_name_user_property_file ICN_DB_USER_PASSWORD)"
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode) 
                    check_single_quotes_password $temp_val "ICN_DB_USER_PASSWORD"
                    ${SED_COMMAND} "s|\"<ICNDB_PASSWORD>\"|'$(printf '%q' $temp_val)'|g" ${BAN_SECRET_FILE}
                else
                    ${SED_COMMAND} "s|\"<ICNDB_PASSWORD>\"|$tmp_dbuserpwd|g" ${BAN_SECRET_FILE}
                fi
            fi
            success "Created ibm-ban-secret secret YAML template for CP4BA\n"
        fi
    fi
    # create DPE DB secret
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        # get server/instance for DPE
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ADP_BASE_DB_USER_NAME)"
        check_dbserver_name_valid $tmp_dbservername "ADP_BASE_DB_USER_NAME"
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
        fi

        create_aca_db_secret_template $tmp_dbname $tmp_dbservername

        # create ibm-adp-secret
        create_adp_secret_template

        # replace serviceUser/servicePwd for ADP
        tmp_username="$(prop_user_profile_property_file ADP.SERVICE_USER_NAME)"
        tmp_userpwd="$(prop_user_profile_property_file ADP.SERVICE_USER_PASSWORD)"
        ${SED_COMMAND} "s|serviceUser:.*|serviceUser: \"$tmp_username\"|g" ${ADP_SECRET_FILE}
        if [[ "${tmp_userpwd:0:8}" == "{Base64}"  ]]; then
            temp_val=$(echo "$tmp_userpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
            check_single_quotes_password $temp_val "ADP.SERVICE_USER_PASSWORD"
            ${SED_COMMAND} "s|servicePwd:.*|servicePwd: '$(printf '%q' $temp_val)'|g" ${ADP_SECRET_FILE}
        else
            ${SED_COMMAND} "s|servicePwd:.*|servicePwd: \"$tmp_userpwd\"|g" ${ADP_SECRET_FILE}
        fi

        # replace serviceUserBas/servicePwdBas for ADP
        tmp_username="$(prop_user_profile_property_file ADP.SERVICE_USER_NAME_BASE)"
        tmp_userpwd="$(prop_user_profile_property_file ADP.SERVICE_USER_PASSWORD_BASE)"
        ${SED_COMMAND} "s|serviceUserBas:.*|serviceUserBas: \"$tmp_username\"|g" ${ADP_SECRET_FILE}
        if [[ "${tmp_userpwd:0:8}" == "{Base64}"  ]]; then
            temp_val=$(echo "$tmp_userpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
            check_single_quotes_password $temp_val "ADP.SERVICE_USER_PASSWORD_BASE"
            ${SED_COMMAND} "s|servicePwdBas:.*|servicePwdBas: '$(printf '%q' $temp_val)'|g" ${ADP_SECRET_FILE}
        else
            ${SED_COMMAND} "s|servicePwdBas:.*|servicePwdBas: \"$tmp_userpwd\"|g" ${ADP_SECRET_FILE}
        fi

        # replace serviceUserCa/servicePwdCa for ADP
        tmp_username="$(prop_user_profile_property_file ADP.SERVICE_USER_NAME_CA)"
        tmp_userpwd="$(prop_user_profile_property_file ADP.SERVICE_USER_PASSWORD_CA)"
        ${SED_COMMAND} "s|serviceUserCa:.*|serviceUserCa: \"$tmp_username\"|g" ${ADP_SECRET_FILE}
        if [[ "${tmp_userpwd:0:8}" == "{Base64}"  ]]; then
            temp_val=$(echo "$tmp_userpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
            check_single_quotes_password $temp_val "ADP.SERVICE_USER_PASSWORD_CA"
            ${SED_COMMAND} "s|servicePwdCa:.*|servicePwdCa: '$(printf '%q' $temp_val)'|g" ${ADP_SECRET_FILE}
        else
            ${SED_COMMAND} "s|servicePwdCa:.*|servicePwdCa: \"$tmp_userpwd\"|g" ${ADP_SECRET_FILE}
        fi
        # replace envOwnerUser/envOwnerPwd for ADP
        tmp_username="$(prop_user_profile_property_file ADP.ENV_OWNER_USER_NAME)"
        tmp_userpwd="$(prop_user_profile_property_file ADP.ENV_OWNER_USER_PASSWORD)"
        ${SED_COMMAND} "s|envOwnerUser:.*|envOwnerUser: \"$tmp_username\"|g" ${ADP_SECRET_FILE}
        if [[ "${tmp_userpwd:0:8}" == "{Base64}"  ]]; then
            temp_val=$(echo "$tmp_userpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
            check_single_quotes_password $temp_val "ADP.ENV_OWNER_USER_PASSWORD"
            ${SED_COMMAND} "s|envOwnerPwd:.*|envOwnerPwd: '$(printf '%q' $temp_val)'|g" ${ADP_SECRET_FILE}
        else
            ${SED_COMMAND} "s|envOwnerPwd:.*|envOwnerPwd: \"$tmp_userpwd\"|g" ${ADP_SECRET_FILE}
        fi
 
        # Applying user profile for ibm-adp-secret
        tmp_mongo_flag="$(prop_user_profile_property_file ADP.USE_EXTERNAL_MONGODB)"
        tmp_mongo_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_mongo_flag")

        if [[ $tmp_mongo_flag == "Yes" || $tmp_mongo_flag == "YES" || $tmp_mongo_flag == "Y" || $tmp_mongo_flag == "True" || $tmp_mongo_flag == "true" ]]; then
            # replace mongoUri/mongoUser/mongoPwd for ADP
            tmp_mongo_uri="$(prop_user_profile_property_file ADP.EXTERNAL_MONGO_URI)"
            tmp_username="$(prop_user_profile_property_file ADP.MONGO_USER_NAME)"
            tmp_userpwd="$(prop_user_profile_property_file ADP.MONGO_USER_PASSWORD)"
            ${YQ_CMD} w -i ${ADP_SECRET_FILE} stringData.mongoUri "\"$tmp_mongo_uri\""
            # ${SED_COMMAND} "s|# mongoUri:.*|mongoUri: \"$tmp_mongo_uri\"|g" ${ADP_SECRET_FILE}
            ${SED_COMMAND} "s|# mongoUser:.*|mongoUser: \"$tmp_username\"|g" ${ADP_SECRET_FILE}
            if [[ "${tmp_userpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_userpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "ADP.MONGO_USER_PASSWORD"
                ${SED_COMMAND} "s|# mongoPwd:.*|mongoPwd: '$(printf '%q' $temp_val)'|g" ${ADP_SECRET_FILE}
            else
                ${SED_COMMAND} "s|# mongoPwd:.*|mongoPwd: \"$tmp_userpwd\"|g" ${ADP_SECRET_FILE}
            fi            
            ${SED_COMMAND} "s|'\"|\"|g" ${ADP_SECRET_FILE}
            ${SED_COMMAND} "s|\"'|\"|g" ${ADP_SECRET_FILE}

        fi

        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            # create SSL secret for Git connection
            tmp_git_flag="$(prop_user_profile_property_file ADP.ENABLE_GIT_SSL_CONNECTION)"
            tmp_git_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_git_flag")
            if [[ $tmp_git_flag == "Yes" || $tmp_git_flag == "YES" || $tmp_git_flag == "Y" || $tmp_git_flag == "True" || $tmp_git_flag == "true" ]]; then
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

        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
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
                tmp_name=$CDRA_SSL_CERT_FILE_FOLDER
            fi
            ${SED_COMMAND} "s|<adp-cdra-crt-file-in-local>|$tmp_name|g" ${ADP_CDRA_SSL_SECRET_FILE}
        
        
            # create template for aca-design-api-key
            enable_flag="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_ENABLED)"
            enable_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$enable_flag")
            enable_flag=$(echo $enable_flag | tr '[:upper:]' '[:lower:]')

            type_flag="$(prop_user_profile_property_file ADP.RUNTIME_FEEDBACK_RUNTIME_TYPE)"
            type_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$type_flag")    

            if [[ $enable_flag == "true" && $type_flag == "distributed" ]]; then
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

    # create AE secret
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "application" ]]; then
        # get server/instance for AE
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name APP_ENGINE_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "APP_ENGINE_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
        fi

        create_app_engine_secret_template $tmp_dbname $tmp_dbservername
        #  replace APP Engine DB user
        tmp_dbuser="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
        ${SED_COMMAND} "s|AE_DATABASE_USER: .*|AE_DATABASE_USER: $tmp_dbuser|g" ${APP_ENGINE_SECRET_FILE}

        # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
        if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
            ${SED_COMMAND} '/^  AE_DATABASE_PWD/d' ${APP_ENGINE_SECRET_FILE}
        else
            tmp_dbuserpwd="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_PASSWORD)"
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "APP_ENGINE_DB_USER_PASSWORD"
                ${SED_COMMAND} "s|AE_DATABASE_PWD: .*|AE_DATABASE_PWD: '$(printf '%q' $temp_val)'|g" ${APP_ENGINE_SECRET_FILE}
            else
                ${SED_COMMAND} "s|AE_DATABASE_PWD: .*|AE_DATABASE_PWD: $tmp_dbuserpwd|g" ${APP_ENGINE_SECRET_FILE}
            fi
        fi

        # Redis for AE HA session
        tmp_redis_tls_enabled="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_TLS_ENABLED)"
        tmp_redis_tls_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_tls_enabled")
        if [[ $tmp_redis_tls_enabled == "Yes" || $tmp_redis_tls_enabled == "YES" || $tmp_redis_tls_enabled == "Y" || $tmp_redis_tls_enabled == "True" || $tmp_redis_tls_enabled == "true" ]]; then
            create_cp4a_ae_redis_ssl_secret_template
            #  replace secret name
            tmp_redis_secret_name="$(prop_user_profile_property_file APP_ENGINE.SESSION_REDIS_SSL_SECRET_NAME)"
            tmp_redis_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_secret_name")
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

    # create ODM DB secret
    containsElement "decisions" "${pattern_cr_arr[@]}"
    odm_Val=$?
    if [[ $odm_Val -eq 0 ]]; then
        
        # get server/instance for ODM
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ODM_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "ODM_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        fi

        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file ODM_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
        fi

        create_odm_secret_template $tmp_dbname $tmp_dbservername
        #  replace basedb user
        tmp_dbuser="$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
        ${SED_COMMAND} "s|db-user: .*|db-user: $tmp_dbuser|g" ${ODM_SECRET_FILE}

        # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
        if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
            ${SED_COMMAND} '/^  db-password/d' ${ODM_SECRET_FILE}
        else
            tmp_dbuserpwd="$(prop_db_name_user_property_file ODM_DB_USER_PASSWORD)"
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "ODM_DB_USER_PASSWORD"
                ${SED_COMMAND} "s|db-password: .*|db-password: '$(printf '%q' $temp_val)'|g" ${ODM_SECRET_FILE}
            else
                ${SED_COMMAND} "s|db-password: .*|db-password: $tmp_dbuserpwd|g" ${ODM_SECRET_FILE}
            fi
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
            tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file STUDIO_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)"
        fi 
        create_bas_secret_template $tmp_dbname $tmp_dbservername
        #  replace BAStudio DB user
        tmp_dbuser="$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)"
        ${SED_COMMAND} "s|dbUsername: .*|dbUsername: $tmp_dbuser|g" ${BAS_SECRET_FILE} 

        # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
        if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
            ${SED_COMMAND} '/^  dbPassword/d' ${BAS_SECRET_FILE}
        else
            tmp_dbuserpwd="$(prop_db_name_user_property_file STUDIO_DB_USER_PASSWORD)"
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "STUDIO_DB_USER_PASSWORD"
                ${SED_COMMAND} "s|dbPassword: .*|dbPassword: '$(printf '%q' $temp_val)'|g" ${BAS_SECRET_FILE}
            else
                ${SED_COMMAND} "s|dbPassword: .*|dbPassword: $tmp_dbuserpwd|g" ${BAS_SECRET_FILE}
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
            tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file APP_PLAYBACK_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
        fi      
        create_ae_playback_secret_template $tmp_dbname $tmp_dbservername
        #  replace ae playback db user
        tmp_dbuser="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
        ${SED_COMMAND} "s|AE_DATABASE_USER: .*|AE_DATABASE_USER: $tmp_dbuser|g" ${APP_ENGINE_PLAYBACK_SECRET_FILE}

        # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
        if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
            ${SED_COMMAND} '/^  AE_DATABASE_PWD/d' ${APP_ENGINE_PLAYBACK_SECRET_FILE}
        else
            tmp_dbuserpwd="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_PASSWORD)"
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "APP_PLAYBACK_DB_USER_PASSWORD"
                ${SED_COMMAND} "s|AE_DATABASE_PWD: .*|AE_DATABASE_PWD: '$(printf '%q' $temp_val)'|g" ${APP_ENGINE_PLAYBACK_SECRET_FILE}
            else
                ${SED_COMMAND} "s|AE_DATABASE_PWD: .*|AE_DATABASE_PWD: $tmp_dbuserpwd|g" ${APP_ENGINE_PLAYBACK_SECRET_FILE}
            fi
        fi
        # Redis for Playback HA session
        tmp_redis_tls_enabled="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_TLS_ENABLED)"
        tmp_redis_tls_enabled=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_tls_enabled")
        if [[ $tmp_redis_tls_enabled == "Yes" || $tmp_redis_tls_enabled == "YES" || $tmp_redis_tls_enabled == "Y" || $tmp_redis_tls_enabled == "True" || $tmp_redis_tls_enabled == "true" ]]; then
            create_cp4a_playback_redis_ssl_secret_template
            #  replace secret name
            tmp_redis_secret_name="$(prop_user_profile_property_file APP_PLAYBACK.SESSION_REDIS_SSL_SECRET_NAME)"
            tmp_redis_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_redis_secret_name")
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
            tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
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
        create_baw_runtime_secret_template $tmp_dbname $tmp_dbservername

        #  replace baw db user
        tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
        ${SED_COMMAND} "s|dbUser: .*|dbUser: $tmp_dbuser|g" ${BAW_RUNTIME_SECRET_FILE}

        # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
        if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
            ${SED_COMMAND} '/^  password/d' ${BAW_RUNTIME_SECRET_FILE}
        else
            tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "BAW_RUNTIME_DB_USER_PASSWORD"
                ${SED_COMMAND} "s|password: .*|password: '$(printf '%q' $temp_val)'|g" ${BAW_RUNTIME_SECRET_FILE}
            else
                ${SED_COMMAND} "s|password: .*|password: $tmp_dbuserpwd|g" ${BAW_RUNTIME_SECRET_FILE}
            fi
        fi


        # get server/instance for aws
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
        tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
        check_dbserver_name_valid $tmp_dbservername "AWS_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
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
        create_baw_aws_secret_template $tmp_dbname $tmp_dbservername

        tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
        ${SED_COMMAND} "s|dbUser: .*|dbUser: $tmp_dbuser|g" ${BAW_AWS_SECRET_FILE}

        # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
        if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
            ${SED_COMMAND} '/^  password/d' ${BAW_AWS_SECRET_FILE}
        else
            tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "AWS_DB_USER_PASSWORD"
                ${SED_COMMAND} "s|password: .*|password: '$(printf '%q' $temp_val)'|g" ${BAW_AWS_SECRET_FILE}
            else
                ${SED_COMMAND} "s|password: .*|password: $tmp_dbuserpwd|g" ${BAW_AWS_SECRET_FILE}
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
            tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
        fi 
        create_baw_runtime_secret_template $tmp_dbname $tmp_dbservername
        #  replace baw db user
        tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
        ${SED_COMMAND} "s|dbUser: .*|dbUser: $tmp_dbuser|g" ${BAW_RUNTIME_SECRET_FILE}

        # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
        if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
            ${SED_COMMAND} '/^  password/d' ${BAW_RUNTIME_SECRET_FILE}
        else
            tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "BAW_RUNTIME_DB_USER_PASSWORD"
                ${SED_COMMAND} "s|password: .*|password: '$(printf '%q' $temp_val)'|g" ${BAW_RUNTIME_SECRET_FILE}
            else
                ${SED_COMMAND} "s|password: .*|password: $tmp_dbuserpwd|g" ${BAW_RUNTIME_SECRET_FILE}
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
            tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        fi
        if [[ $DB_TYPE = "postgresql-edb" ]]; then
            tmp_postgresql_client_flag="true"
        fi

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
        fi
        create_baw_aws_secret_template $tmp_dbname $tmp_dbservername
        #  replace aws db user
        tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
        ${SED_COMMAND} "s|dbUser: .*|dbUser: $tmp_dbuser|g" ${BAW_AWS_SECRET_FILE}

        # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
        if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
            ${SED_COMMAND} '/^  password/d' ${BAW_AWS_SECRET_FILE}
        else
            tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)  
                check_single_quotes_password $temp_val "AWS_DB_USER_PASSWORD"
                ${SED_COMMAND} "s|password: .*|password: '$(printf '%q' $temp_val)'|g" ${BAW_AWS_SECRET_FILE}
            else
                ${SED_COMMAND} "s|password: .*|password: $tmp_dbuserpwd|g" ${BAW_AWS_SECRET_FILE}
            fi
        fi
    fi

    # create ads secret
    if [[ " ${pattern_cr_arr[@]}" =~ "decisions_ads" ]]; then
        tmp_mongo_flag="$(prop_user_profile_property_file ADS.USE_EXTERNAL_MONGODB)"
        tmp_mongo_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_mongo_flag")
        if [[ $tmp_mongo_flag == "Yes" || $tmp_mongo_flag == "YES" || $tmp_mongo_flag == "Y" || $tmp_mongo_flag == "True" || $tmp_mongo_flag == "true" ]]; then
            create_ads_secret_template
            # replace gitMongoUri/mongoHistoryUri/runtimeMongoUri for ADS
            tmp_uri="$(prop_user_profile_property_file ADS.EXTERNAL_GIT_MONGO_URI)"
            ${YQ_CMD} w -i ${ADS_SECRET_FILE} stringData.gitMongoUri "\"$tmp_uri\""
            tmp_uri="$(prop_user_profile_property_file ADS.EXTERNAL_MONGO_URI)"
            ${YQ_CMD} w -i ${ADS_SECRET_FILE} stringData.mongoUri "\"$tmp_uri\""
            tmp_uri="$(prop_user_profile_property_file ADS.EXTERNAL_MONGO_HISTORY_URI)"
            ${YQ_CMD} w -i ${ADS_SECRET_FILE} stringData.mongoHistoryUri "\"$tmp_uri\""
            tmp_uri="$(prop_user_profile_property_file ADS.EXTERNAL_RUNTIME_MONGO_URI)"
            ${YQ_CMD} w -i ${ADS_SECRET_FILE} stringData.runtimeMongoUri "\"$tmp_uri\""
            ${SED_COMMAND} "s|'\"|\"|g" ${ADS_SECRET_FILE}
            ${SED_COMMAND} "s|\"'|\"|g" ${ADS_SECRET_FILE}
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
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SSL_ENABLE)")
            tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
            while true; do
                case "$tmp_flag" in
                "true"|"yes"|"y")
                    create_cp4a_db_ssl_template $item

                    #  replace secret name
                    tmp_name="$(prop_db_server_property_file $item.DATABASE_SSL_SECRET_NAME)"
                    tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
                    ${SED_COMMAND} "s|<cp4a-db-ssl-secret-name>|$tmp_name|g" ${CP4A_DB_SSL_SECRET_FILE}

                    #  replace secret file folder
                    tmp_name="$(prop_db_server_property_file $item.DATABASE_SSL_CERT_FILE_FOLDER)"
                    if [[ -z $tmp_name || $tmp_name == "" ]]; then
                        tmp_name=$DB_SSL_CERT_FOLDER/$item
                    fi
                    ${SED_COMMAND} "s|<cp4a-db-crt-file-in-local>|$tmp_name|g" ${CP4A_DB_SSL_SECRET_FILE}
                    
                    # create oracle-wallet-sso-secret-for-$item for AE/APP
                    if [[ $DB_TYPE == "oracle" && (" ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "application" || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer") ]]; then
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

    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "No") ]]; then
        # LDAP SSL Enabled
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ldap_property_file LDAP_SSL_ENABLED)")
        tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        while true; do
            case "$tmp_flag" in
            "true"|"yes"|"y")
                create_cp4a_ldap_ssl_secret_template
                #  replace ldap secret name
                tmp_ldap_secret_name="$(prop_ldap_property_file LDAP_SSL_SECRET_NAME)"
                tmp_ldap_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_secret_name")
                if [[ -z $tmp_ldap_secret_name || -n $tmp_ldap_secret_name || $tmp_ldap_secret_name != "" ]]; then
                    ${SED_COMMAND} "s|<cp4a-ldap_ssl_secret_name>|$tmp_ldap_secret_name|g" ${CP4A_LDAP_SSL_SECRET_FILE}
                fi

                #  replace secret file folder
                tmp_name="$(prop_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
                if [[ -z $tmp_name || $tmp_name == "" ]]; then
                    tmp_name=$LDAP_SSL_CERT_FOLDER
                fi
                ${SED_COMMAND} "s|<cp4a-ldap-crt-file-in-local>|$tmp_name|g" ${CP4A_LDAP_SSL_SECRET_FILE}
                break
                ;;
            "false"|"no"|"n"|"")
                break
                ;;
            *)
                fail "LDAP_SSL_ENABLED is not valid value in the \"cp4ba_LDAP.property\"! Exiting ..."
                exit 1
                ;;
            esac
        done
        
        # External LDAP SSL Enabled
        if [[ $SET_EXT_LDAP == "Yes" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ext_ldap_property_file LDAP_SSL_ENABLED)")
            tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
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
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        create_im_external_db_secret_template
        #  replace secret file folder
        im_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        im_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$im_external_db_cert_folder")
        if [[ -z $im_external_db_cert_folder || $im_external_db_cert_folder == "" ]]; then
            im_external_db_cert_folder=$IM_DB_SSL_CERT_FOLDER
        fi
        ${SED_COMMAND} "s|<cp4a-db-crt-file-in-local>|$im_external_db_cert_folder|g" ${IM_SECRET_FILE}

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

    # Create Secret/configMap for Zen metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_ZEN_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        create_zen_external_db_secret_template
        #  replace secret file folder
        zen_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        zen_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$zen_external_db_cert_folder")
        if [[ -z $zen_external_db_cert_folder || $zen_external_db_cert_folder == "" ]]; then
            zen_external_db_cert_folder=$ZEN_DB_SSL_CERT_FOLDER
        fi
        ${SED_COMMAND} "s|<cp4a-db-crt-file-in-local>|$zen_external_db_cert_folder|g" ${ZEN_SECRET_FILE}

        create_zen_external_db_configmap_template
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

    fi

    # Create Secret/configMap for BTS metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_BTS_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        create_bts_external_db_secret_template
        #  replace secret file folder
        bts_external_db_cert_folder="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER)"
        bts_external_db_cert_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$bts_external_db_cert_folder")
        if [[ -z $bts_external_db_cert_folder || $bts_external_db_cert_folder == "" ]]; then
            bts_external_db_cert_folder=$BTS_DB_SSL_CERT_FOLDER
        fi
        ${SED_COMMAND} "s|<cp4a-db-crt-file-in-local>|$bts_external_db_cert_folder|g" ${BTS_SSL_SECRET_FILE}

        #  replace <DatabaseUser>
        tmp_name="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_USER_NAME)"
        tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
        ${SED_COMMAND} "s|<USERNAME>|$tmp_name|g" ${BTS_SECRET_FILE}

        #  replace <DatabaseUser_password>
        tmp_name="$(prop_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_USER_PASSWORD)"
        tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
        ${SED_COMMAND} "s|<PASSWORD>|$tmp_name|g" ${BTS_SECRET_FILE}

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

    fi

    # Create Issuer to make Opensearch/Kafka use external certificate
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_CERT_OPENSEARCH_KAFKA_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
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

    tips
    msgB "* Enter the <Required> values in the YAML templates for the secrets under $SECRET_FILE_FOLDER"

    # Show which certificate file should be copied into which folder 
    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    for item in "${db_server_array[@]}"; do
        # DB SSL Enabled
        tmp_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SSL_ENABLE)")
        tmp_ssl_flag=$(echo $tmp_ssl_flag | tr '[:upper:]' '[:lower:]')
        while true; do
            case "$tmp_ssl_flag" in
            "true"|"yes"|"y")
                tmp_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SSL_CERT_FILE_FOLDER)")
                if [[ $DB_TYPE == "oracle" ]]; then
                    tmp_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_oracle_server_property_file $item.ORACLE_JDBC_URL)")
                else
                    tmp_dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SERVERNAME)")
                fi
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.POSTGRESQL_SSL_CLIENT_SERVER)")
                    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
                    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
                        msgB "* You enabled PostgreSQL database with both server and client authentication, please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" on your local or remote database server \"$tmp_dbserver\", and copy them into folder \"$tmp_folder\" before you create the secret for PostgreSQL database SSL"
                    elif [[ $tmp_flag == "false" || $tmp_flag == "no" || $tmp_flag == "n" || $tmp_flag == "" ]]; then
                        msgB "* You enabled PostgreSQL database with server-only authentication, please get \"<your-server-certification: db-cert.crt>\"  on remote database server \"$tmp_dbserver\", and copy them into folder \"$tmp_folder\" before you create the secret for PostgreSQL database SSL"
                    fi
                else
                    if [[ $DB_TYPE == "oracle" ]]; then
                        msgB "* Get the certificate file \"db-cert.crt\" from the remote database server that uses the JDBC URL: \"$tmp_db_jdbc_url\", and copy it into the folder \"$tmp_folder\" before you create the Kubernetes secret for the database SSL"
                    else
                        msgB "* Get the certificate file \"db-cert.crt\" from the remote database server \"$tmp_dbserver\", and copy it into the folder \"$tmp_folder\" before you create the Kubernetes secret for the database SSL"
                    fi
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

    # LDAP: Show which certificate file should be copy into which folder 
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ldap_property_file LDAP_SSL_ENABLED)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')

    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        tmp_folder="$(prop_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
        tmp_ldapserver="$(prop_ldap_property_file LDAP_SERVER)"
        msgB "* Get the \"ldap-cert.crt\" from the remote LDAP server \"$tmp_ldapserver\", and copy it into the folder \"$tmp_folder\" before you create the Kubernetes secret for the LDAP SSL"
    fi

    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ext_ldap_property_file LDAP_SSL_ENABLED)")
        tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
            tmp_folder="$(prop_ext_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
            tmp_ldapserver="$(prop_ext_ldap_property_file LDAP_SERVER)"
            msgB "* You enabled external LDAP SSL, so get the \"external-ldap-cert.crt\" from the remote LDAP server \"$tmp_ldapserver\", and copy it into the folder \"$tmp_folder\" before you create the secret for the external LDAP SSL"
        fi
    fi

    # show postgresql ssl setting tip for db secret
    if [[ $DB_TYPE == "postgresql" ]]; then
        tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
        tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
        OIFS=$IFS
        IFS=',' read -ra db_server_array <<< "$tmp_db_array"
        IFS=$OIFS

        for item in "${db_server_array[@]}"; do
            postgresql_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.POSTGRESQL_SSL_CLIENT_SERVER)")
            postgresql_server=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SERVERNAME)")
            tmp_flag=$(echo $postgresql_flag | tr '[:upper:]' '[:lower:]')
            if [[ $tmp_flag == "yes" || $tmp_flag == "true" || $tmp_flag == "y"  ]]; then
                CP4A_DB_SSL_SECRET_FILE_TMP=${DB_SSL_SECRET_FOLDER}/$item/ibm-cp4ba-db-ssl-cert-secret-for-${item}.sh
                msgB "* Found \"POSTGRESQL_SSL_CLIENT_SERVER\" is \"$postgresql_flag\" for database server \"$postgresql_server\" in property file \"${DB_SERVER_INFO_PROPERTY_FILE}\".\n  Set the \"sslmode\" parameter in the script \"${CP4A_DB_SSL_SECRET_FILE_TMP}\" to select which sslmode=[require|verify-ca|verify-full] that you want it."
            fi
        done
    fi

    # show tips for IM metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_IM_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        msgB "* You have enabled IM metastore external Postgres DB, please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from your local or remote database server \"$im_external_db_host_name\", and copy them into folder \"$im_external_db_cert_folder\" before you create the secret for PostgreSQL database SSL"
    fi

    # show tips for Zen metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_ZEN_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        msgB "* You have enabled Zen metastore external Postgres DB, please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from your local or remote database server \"$zen_external_db_host_name\", and copy them into folder \"$zen_external_db_cert_folder\" before you create the secret for PostgreSQL database SSL"
    fi

    # show tips for BTS metastore external Postgres DB
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_BTS_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        msgB "* You have enabled BTS metastore external Postgres DB, please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from your local or remote database server \"$im_external_db_host_name\", and copy them into folder \"$im_external_db_cert_folder\" before you create the secret for PostgreSQL database SSL"
    fi

    msgB "* You can use this shell script to create the secret automatically (NOTE: In case separation of operators and operands is selected - SWITCH TO CP4BA DEPLOYMENT PROJECT): $CREATE_SECRET_SCRIPT_FILE"
    msgB "* Create the databases and Kubernetes secrets manually based on your modified \"DB SQL statement file\" and \"YAML template for secret\".\n* And then run the  \"cp4a-prerequisites.sh -m validate\" command to verify that the databases and secrets are created correctly"
    # msgB "And then run cp4a-prerequisites.sh -m validate script to validate prerequisites"
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
    for item in "${optional_component_arr[@]}"; do
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

    # save external certificate for Opensearch/Kafka flag
    if [[ $EXTERNAL_CERT_OPENSEARCH_KAFKA == "true" ]]; then
        echo "EXTERNAL_CERT_OPENSEARCH_KAFKA_FLAG=true" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "EXTERNAL_CERT_OPENSEARCH_KAFKA_FLAG=false" >> ${TEMPORARY_PROPERTY_FILE}
    fi

    # save profile size 
    echo "PROFILE_SIZE_FLAG=$PROFILE_TYPE" >> ${TEMPORARY_PROPERTY_FILE}
}

function create_property_file(){
    if [[ $DB_TYPE == "oracle" ]]; then
        local DB_SERVER_PREFIX="<DB_INSTANCE_NAME>"
    else
        local DB_SERVER_PREFIX="<DB_SERVER_NAME>"
    fi
    printf "\n"
    # mkdir -p $PREREQUISITES_FOLDER_BAK >/dev/null 2>&1

    if [[ -d "$PROPERTY_FILE_FOLDER" ]]; then
        tmp_property_file_dir="${PROPERTY_FILE_FOLDER_BAK}_$(date +%Y-%m-%d-%H:%M:%S)"
        mkdir -p "$tmp_property_file_dir" >/dev/null 2>&1
        ${COPY_CMD} -rf "${PROPERTY_FILE_FOLDER}" "${tmp_property_file_dir}"
    fi
    rm -rf $PROPERTY_FILE_FOLDER >/dev/null 2>&1
    mkdir -p $PROPERTY_FILE_FOLDER >/dev/null 2>&1
    mkdir -p $LDAP_SSL_CERT_FOLDER >/dev/null 2>&1
    mkdir -p $DB_SSL_CERT_FOLDER >/dev/null 2>&1

    > ${DB_SERVER_INFO_PROPERTY_FILE}
    if (( db_server_number > 0 )); then
    INFO "Creating database and LDAP property files for CP4BA"


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
        echo $tip >> ${DB_SERVER_INFO_PROPERTY_FILE}
        tip="## (NOTES: The value (CAN NOT CONTAIN DOT CHARACTER) is alias name for database server/instance, it is not real database server/instance host name.) ##"
        echo $tip >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "DB_SERVER_LIST=\"$db_server_joined\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}

    # Put DB server/instance into array

    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    for item in "${db_server_array[@]}"; do
        item_tmp=$(echo $item| tr '[:upper:]' '[:lower:]')
        replace_str="-"
        item_tmp=${item_tmp//_/$replace_str}

        mkdir -p "${DB_SSL_CERT_FOLDER}/$item" >/dev/null 2>&1
        tip="## Property for Database Server \"$item\" required by IBM Cloud Pak for Business Automation on ${DB_TYPE} type database ##"
        echo "####################################################" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo $tip >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "####################################################" >> ${DB_SERVER_INFO_PROPERTY_FILE}

        for i in "${!GCDDB_COMMON_PROPERTY[@]}"; do
            if [[ ($DB_TYPE == "db2" || $DB_TYPE == "db2HADR") && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_USER_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "ORACLE_JDBC_URL" ]]; then
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
        ${SED_COMMAND} "s|$item.DATABASE_TYPE=\"\"|$item.DATABASE_TYPE=\"${DB_TYPE}\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|$item.DATABASE_SSL_CERT_FILE_FOLDER=\"\"|$item.DATABASE_SSL_CERT_FILE_FOLDER=\"${DB_SSL_CERT_FOLDER}/$item\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|<DB_SSL_CERT_FOLDER>|${DB_SSL_CERT_FOLDER}/$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|$item.DATABASE_SSL_ENABLE=\"\"|$item.DATABASE_SSL_ENABLE=\"True\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|$item.DATABASE_SSL_SECRET_NAME=\"\"|$item.DATABASE_SSL_SECRET_NAME=\"ibm-cp4ba-db-ssl-secret-for-${item_tmp}\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}

        # set default value for PostgreSQL EDB
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
        # insert comment for DATABASE_SSL_CERT_FILE_FOLDER when POSTGRESQL_SSL_CLIENT_SERVER=Yes
        if [[ $DB_TYPE == "postgresql" ]]; then
            # fix sed issue on Mac, DO NOT format code
            nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
            if [[ "$machine" == "Mac" ]]; then
                ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\ 
## If POSTGRESQL_SSL_CLIENT_SERVER is \"True\" and DATABASE_SSL_ENABLE is \"True\", please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\".\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\ 
## If POSTGRESQL_SSL_CLIENT_SERVER is \"False\" and DATABASE_SSL_ENABLE is \"True\", please get the SSL certificate file (rename db-cert.crt) from server and then copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\".\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
            else
                ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\## If POSTGRESQL_SSL_CLIENT_SERVER is \"True\" and DATABASE_SSL_ENABLE is \"True\", please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\"." ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\## If POSTGRESQL_SSL_CLIENT_SERVER is \"False\" and DATABASE_SSL_ENABLE is \"True\", please get the SSL certificate file (rename db-cert.crt) from server and then copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\"." ${DB_SERVER_INFO_PROPERTY_FILE}
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
    success "Created the DB Server property file for CP4BA\n"
    fi

    > ${LDAP_PROPERTY_FILE}
    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "No") ]]; then
        wait_msg "Creating LDAP Server property file for CP4BA"
        
        tip="## Property file for ${LDAP_TYPE} ##"

        echo "###########################" >> ${LDAP_PROPERTY_FILE}
        echo $tip >> ${LDAP_PROPERTY_FILE}
        echo "###########################" >> ${LDAP_PROPERTY_FILE}
        for i in "${!LDAP_COMMON_PROPERTY[@]}"; do
            echo "${COMMENTS_LDAP_PROPERTY[i]}" >> ${LDAP_PROPERTY_FILE}
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
        else
            ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"IBM Security Directory Server\"|g" ${LDAP_PROPERTY_FILE}
            for i in "${!TDS_LDAP_PROPERTY[@]}"; do
                echo "${COMMENTS_TDS_LDAP_PROPERTY[i]}" >> ${LDAP_PROPERTY_FILE}
                echo "${TDS_LDAP_PROPERTY[i]}=\"\"" >> ${LDAP_PROPERTY_FILE}
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
        else
            ${SED_COMMAND} "s|LDAP_USER_NAME_ATTRIBUTE=\"\"|LDAP_USER_NAME_ATTRIBUTE=\"*:uid\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_USER_DISPLAY_NAME_ATTR=\"\"|LDAP_USER_DISPLAY_NAME_ATTR=\"cn\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_NAME_ATTRIBUTE=\"\"|LDAP_GROUP_NAME_ATTRIBUTE=\"*:cn\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_DISPLAY_NAME_ATTR=\"\"|LDAP_GROUP_DISPLAY_NAME_ATTR=\"cn\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"\"|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"(\|(\&(objectclass=groupofnames)(member={0}))(\&(objectclass=groupofuniquenames)(uniquemember={0})))\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBER_ID_MAP=\"\"|LDAP_GROUP_MEMBER_ID_MAP=\"groupofnames:member\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_USER_FILTER=\"\"|LC_USER_FILTER=\"(\&(cn=%v)(objectclass=person))\"|g" ${LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_GROUP_FILTER=\"\"|LC_GROUP_FILTER=\"(\&(cn=%v)(\|(objectclass=groupofnames)(objectclass=groupofuniquenames)(objectclass=groupofurls)))\"|g" ${LDAP_PROPERTY_FILE}
        fi
        success "Created the LDAP Server property file for CP4BA\n"
    fi
    # Create external LDAP property file
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        wait_msg "Creating external LDAP property file for CP4BA"
        mkdir -p $EXT_LDAP_SSL_CERT_FOLDER >/dev/null 2>&1 
        > ${EXTERNAL_LDAP_PROPERTY_FILE}
        tip="## Property file for External LDAP ##"
        echo "#####################################" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
        echo $tip >> ${EXTERNAL_LDAP_PROPERTY_FILE}
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
        else
            # ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"IBM Security Directory Server\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            for i in "${!TDS_LDAP_PROPERTY[@]}"; do
                echo "${COMMENTS_TDS_LDAP_PROPERTY[i]}" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "${TDS_LDAP_PROPERTY[i]}=\"\"" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
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
        else
            ${SED_COMMAND} "s|LDAP_USER_NAME_ATTRIBUTE=\"\"|LDAP_USER_NAME_ATTRIBUTE=\"*:uid\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_USER_DISPLAY_NAME_ATTR=\"\"|LDAP_USER_DISPLAY_NAME_ATTR=\"cn\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_NAME_ATTRIBUTE=\"\"|LDAP_GROUP_NAME_ATTRIBUTE=\"*:cn\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_DISPLAY_NAME_ATTR=\"\"|LDAP_GROUP_DISPLAY_NAME_ATTR=\"cn\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"\"|LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER=\"(\|(\&(objectclass=groupofnames)(member={0}))(\&(objectclass=groupofuniquenames)(uniquemember={0})))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LDAP_GROUP_MEMBER_ID_MAP=\"\"|LDAP_GROUP_MEMBER_ID_MAP=\"groupofnames:member\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_USER_FILTER=\"\"|LC_USER_FILTER=\"(\&(cn=%v)(objectclass=person))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            ${SED_COMMAND} "s|LC_GROUP_FILTER=\"\"|LC_GROUP_FILTER=\"(\&(cn=%v)(\|(objectclass=groupofnames)(objectclass=groupofuniquenames)(objectclass=groupofurls)))\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        fi
        success "Created the external LDAP property file for CP4BA\n"
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
        echo "==================================================================================================================" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "NOTES: Please change the \"$DB_SERVER_PREFIX\" variable to assign each database to a database server or instance." >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "       The \"$DB_SERVER_PREFIX\" must be in [${db_server_array[*]}]" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "==================================================================================================================" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
    fi

    # if only one database server is input, set <DB_SERVER_NAME> auto
    if [ ${#db_server_array[@]} -eq 1 ]; then
        DB_SERVER_PREFIX="${db_server_array[0]}"
    fi

    # Add global property into user_profile for CP4BA
    tip="##           USER Property for CP4BA               ##"
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    # license
    echo "## Use this parameter to specify the license for the CP4A deployment and" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## the possible values are: non-production and production and if not set, the license will" >> ${USER_PROFILE_PROPERTY_FILE}        
    echo "## be defaulted to production.  This value could be different from the other licenses in the CR." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.CP4BA_LICENSE=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        echo "## FileNet Content Manager (FNCM) license and possible values are: user, non-production, and production." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## This value could be different from the rest of the licenses." >> ${USER_PROFILE_PROPERTY_FILE}        
        echo "CP4BA.FNCM_LICENSE=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi

    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" ]]; then
        echo "## Business Automation Workflow (BAW) license and possible values are: user, non-production, and production." >> ${USER_PROFILE_PROPERTY_FILE}
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
    echo "CP4BA.ENABLE_RESTRICTED_INTERNET_ACCESS=\"$RESTRICTED_INTERNET_ACCESS\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    if [[ $EXTERNAL_POSTGRESDB_FOR_IM == "true" ]]; then
        rm -rf $IM_DB_SSL_CERT_FOLDER >/dev/null 2>&1
        mkdir -p $IM_DB_SSL_CERT_FOLDER >/dev/null 2>&1
        echo "## Configuration for external Postgres DB as IM metastore DB." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## YOU NEED TO CREATE THIS POSTGRES DB BY YOURSELF FISTLY BEFORE APPLY CP4BA CUSTOM RESOURCE." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## NOTES: " >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   YOU NEED TO CREATE THIS POSTGRES DB BY YOURSELF FISTLY BEFORE APPLY CP4BA CUSTOM RESOURCE." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   1. Postgres version is 14.7 or higher and 16.x." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   2. Client certificate based authentication is configured on the DB server." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   3. Client certificate rotation is managed by the customer." >> ${USER_PROFILE_PROPERTY_FILE}
        
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory.Default value is \"$IM_DB_SSL_CERT_FOLDER\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER=\"$IM_DB_SSL_CERT_FOLDER\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the database user. The default value is \"imcnp_user\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_USER=\"imcnp_user\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the database. The default value is \"imcnpdb\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_NAME=\"imcnpdb\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Database port number. The default value is \"5432\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_PORT=\"5432\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the read database host cloud-native-postgresql on k8s provides this endpoint. If DB is not running on k8s then same hostname as DB host." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_R_ENDPOINT=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the database host." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_RW_ENDPOINT=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi


    if [[ $EXTERNAL_POSTGRESDB_FOR_ZEN == "true" ]]; then
        rm -rf $ZEN_DB_SSL_CERT_FOLDER >/dev/null 2>&1
        mkdir -p $ZEN_DB_SSL_CERT_FOLDER >/dev/null 2>&1
        echo "## Configuration for external Postgres DB as Zen metastore DB." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## YOU NEED TO CREATE THIS POSTGRES DB BY YOURSELF FISTLY BEFORE APPLY CP4BA CUSTOM RESOURCE." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## NOTES: " >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   YOU NEED TO CREATE THIS POSTGRES DB BY YOURSELF FISTLY BEFORE APPLY CP4BA CUSTOM RESOURCE." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   1. Postgres version is 14.7 or higher and 16.x." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   2. Client certificate based authentication is configured on the DB server." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   3. Client certificate rotation is managed by the customer." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        # Name of the key in k8s secret ibm-zen-metastore-edb-secret do not need customized
        # echo "## Name of the key in k8s secret ibm-zen-metastore-edb-secret for CA certificate. The default value is \"ca.crt\"." >> ${USER_PROFILE_PROPERTY_FILE}
        # echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_CA_CERT=\"ca.crt\"" >> ${USER_PROFILE_PROPERTY_FILE}
        # echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        
        # echo "## Name of the key in k8s secret ibm-zen-metastore-edb-secret for client certificate. The default value is \"tls.crt\"." >> ${USER_PROFILE_PROPERTY_FILE}
        # echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_CLIENT_CERT=\"tls.crt\"" >> ${USER_PROFILE_PROPERTY_FILE}
        # echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        # echo "## Name of the key in k8s secret ibm-zen-metastore-edb-secret for client key. The default value is \"tls.key\"." >> ${USER_PROFILE_PROPERTY_FILE}
        # echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_CLIENT_KEY=\"tls.key\"" >> ${USER_PROFILE_PROPERTY_FILE}
        # echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory.Default value is \"$ZEN_DB_SSL_CERT_FOLDER\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER=\"$ZEN_DB_SSL_CERT_FOLDER\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the schema to store monitoring data. The default value is \"watchdog\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_MONITORING_SCHEMA=\"watchdog\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the database. The default value is \"zencnpdb\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_NAME=\"zencnpdb\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Database port number. The default value is \"5432\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_PORT=\"5432\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the read database host cloud-native-postgresql on k8s provides this endpoint. If DB is not running on k8s then same hostname as DB host." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_R_ENDPOINT=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the database host." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_RW_ENDPOINT=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the schema to store zen metadata. The default value is \"public\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_SCHEMA=\"public\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the database user. The default value is \"zencnp_user\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_USER=\"zencnp_user\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi

    if [[ $EXTERNAL_POSTGRESDB_FOR_BTS == "true" ]]; then
        rm -rf $BTS_DB_SSL_CERT_FOLDER >/dev/null 2>&1
        mkdir -p $BTS_DB_SSL_CERT_FOLDER >/dev/null 2>&1
        echo "## Configuration for external Postgres DB as BTS metastore DB." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## YOU NEED TO CREATE THIS POSTGRES DB BY YOURSELF FISTLY BEFORE APPLY CP4BA CUSTOM RESOURCE." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## NOTES: " >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   YOU NEED TO CREATE THIS POSTGRES DB BY YOURSELF FISTLY BEFORE APPLY CP4BA CUSTOM RESOURCE." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   1. Postgres version is 14.7 or higher and 16.x." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   2. Client certificate based authentication is configured on the DB server." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "##   3. Client certificate rotation is managed by the customer." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory.Default value is \"$BTS_DB_SSL_CERT_FOLDER\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER=\"$BTS_DB_SSL_CERT_FOLDER\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the database host." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_HOSTNAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the database user. The default value is \"btscnp_user\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_USER_NAME=\"btscnp_user\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## The password of the database user." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_USER_PASSWORD=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Name of the database. The default value is \"btscnpdb\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_NAME=\"btscnpdb\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Database port number. The default value is \"5432\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_PORT=\"5432\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi

    if [[ $EXTERNAL_CERT_OPENSEARCH_KAFKA == "true" ]]; then
        rm -rf $CP4BA_TLS_ISSUER_CERT_FOLDER >/dev/null 2>&1
        mkdir -p $CP4BA_TLS_ISSUER_CERT_FOLDER >/dev/null 2>&1
        echo "## Configuration for external certificate used by Opensearch/Kafka." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Please get \"<your-root-ca: tls.crt>\" \"<your-root-ca: tls.key>\" copy into this directory.Default value is \"$CP4BA_TLS_ISSUER_CERT_FOLDER\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.EXTERNAL_ROOT_CA_FOR_OPENSEARCH_KAFKA_FOLDER=\"$CP4BA_TLS_ISSUER_CERT_FOLDER\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi

    # Create DBNAME/DBUSER property file for GCDDB
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        wait_msg "Creating Property file for IBM FileNet Content Manager GCD"
        tip="## FNCM's Property for GCD Database Name and User on ${DB_TYPE} type database ##"
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
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
                if [[ $DB_TYPE == "db2"  ]]; then
                    echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "$DB_SERVER_PREFIX.GCD_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                # fi
            else
                echo "## The designated name of the database on the PostgreSQL EDB for the GCD of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.GCD_DB_NAME=\"gcddb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        fi
        
        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                echo "## Provide the user name of the database for the GCD of P8Domain. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.GCD_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated user name of the database on the PostgreSQL EDB for the GCD of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.GCD_DB_USER_NAME=\"gcduser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        else
            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.GCD_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the user name of the database for the GCD of P8Domain. For example: \"GCDDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.GCD_DB_USER_NAME=\"GCDDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) of the database user for the GCD of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            echo "$DB_SERVER_PREFIX.GCD_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else
            echo "## The designated password of the database user for the GCD of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.GCD_DB_USER_PASSWORD=\"gcduser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # Add property into user_profile for FNCM/ICCSAP/IER
        tip="##           USER Property for FNCM                ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}

        # appLoginUsername/appLoginPassword for FNCM
        echo "## Provide the user name for P8Domain. For example: \"CEAdmin\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT.APPLOGIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the user password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for P8Domain." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT.APPLOGIN_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        # ltpaPassword/keystorePassword for FNCM
        echo "## Provide a string for ltpaPassword in the ibm-fncm-secret that will be used when creating the ltpakey." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: CONTENT.LTPA_PASSWORD must same as BAN.LTPA_PASSWORD)" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT.LTPA_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide a string for keystorePassword in the ibm-fncm-secret that will be used when creating the keystore." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: CONTENT.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled.)" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CONTENT.KEYSTORE_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        # If select ICCSAP, add keystorePassword
        if [[ " ${optional_component_cr_arr[@]} " =~ "iccsap" ]]; then
            echo "## Provide a string for keystorePassword in the ibm-iccsap-secret that will be used when creating the keystore." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: ICCSAP.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled.)" >> ${USER_PROFILE_PROPERTY_FILE}
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
            echo "CONTENT.ARCHIVE_USER_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi

        # if select IER
        if [[ " ${optional_component_cr_arr[@]} " =~ "ier" ]]; then
            echo "## Provide a string for keystorePassword in the ibm-ier-secret that will be used when creating the keystore." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: IER.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled.)" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "IER.KEYSTORE_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi

        # user profile for content initialization
        tip="##       USER Property for Content initialization   ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Enable/disable ECM (FNCM) / BAN initialization (e.g., creation of P8 domain, creation/configuration of object stores," >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## creation/configuration of CSS servers, and initialization of Navigator (ICN)." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## The default valuse is \"Yes\", set \"No\" to disable." >> ${USER_PROFILE_PROPERTY_FILE}
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
            if [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
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
            echo "## Provide a name for the connection point" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        success "Created Property file for IBM FileNet Content Manager GCD\n"

        # Create DBNAME/DBUSER property file for Object store
        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
            
            # INFO "Creating Property file for IBM FileNet Content Manager Object Store"
            tip="## FNCM's Property for Object store Database Name and User on ${DB_TYPE} type database ##"

            echo "###################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
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
                            if [[ $DB_TYPE == "db2"  ]]; then
                                echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            # fi
                            echo "## Provide the user name of the database for the Object Store of P8Domain. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}                        
                        else
                            echo "## The designated name of the database on the PostgreSQL EDB for the Object Store of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_NAME=\"os$((j+1))db\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "## The designated user name of the database for the Object Store of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}                        
                        fi
                    else
                        echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

                        echo "## Provide the user name of the database for the Object Store of P8Domain. For example: \"OS$((j+1))DB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_NAME=\"OS$((j+1))DB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) of the database user for the Object Store of P8Domain. " >> ${DB_NAME_USER_PROPERTY_FILE}
                        if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                            echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        echo "## The designated password of the database user for the Object Store of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_PASSWORD=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
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
                wait_msg "Creating Property file for IBM FileNet Content Manager Object Store required by BAW authoring or BAW Runtime"
                for i in "${!BAW_AUTH_OS_ARR[@]}"; do
                    if [[ $DB_TYPE != "oracle" ]]; then
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then
                            
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_sample_name=$(echo ${BAW_AUTH_OS_ARR[i]} | tr '[:upper:]' '[:lower:]')
                                echo "## Provide the name of the database for the object store required by BAW authoring or BAW Runtime. For example: \"$tmp_db_sample_name\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                                echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_NAME=\"$tmp_db_sample_name\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            else
                                echo "## Provide the name of the database for the object store required by BAW authoring or BAW Runtime. For example: \"${BAW_AUTH_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                                echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_NAME=\"${BAW_AUTH_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi
                            # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                            if [[ $DB_TYPE == "db2"  ]]; then
                                echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            # fi
                            echo "## Provide the user name for the object store database required by BAW authoring or BAW Runtime. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        else
                            tmp_db_name=$(echo ${BAW_AUTH_OS_ARR[i]} | tr '[:upper:]' '[:lower:]')
                            echo "## The designated name of the database on the PostgreSQL EDB for the object store required by BAW authoring or BAW Runtime. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_NAME=\"$tmp_db_name\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "## The designated user name for the object store database required by BAW authoring or BAW Runtime. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                    else
                        echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

                        echo "## Provide the user name for the object store database required by BAW authoring or BAW Runtime. For example: \"${BAW_AUTH_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME=\"${BAW_AUTH_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                        if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                            echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        echo "## The designated password for the user of Object Store of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
                done
                # for case history
                if [[ $DB_TYPE != "oracle" ]]; then
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
                        if [[ $DB_TYPE == "db2"  ]]; then
                            echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        echo "$DB_SERVER_PREFIX.CHOS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        # fi
                        echo "## Provide the user name for the object store database required by Case History when Case History Emitter is enabled. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "# $DB_SERVER_PREFIX.CHOS_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        echo "## The designated name of the database on the PostgreSQL EDB for Case History when Case History Emitter is enabled. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "# $DB_SERVER_PREFIX.CHOS_DB_NAME=\"chos\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "## The designated user name for the object store database required by Case History when Case History Emitter is enabled. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "# $DB_SERVER_PREFIX.CHOS_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                else
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.CHOS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

                    echo "## Provide the user name for the object store database required by Case History when Case History Emitter is enabled. For example: \"CHOS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "# $DB_SERVER_PREFIX.CHOS_DB_USER_NAME=\"CHOS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "# $DB_SERVER_PREFIX.CHOS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## The designated password for the user of Object Store of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "# $DB_SERVER_PREFIX.CHOS_DB_USER_PASSWORD=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
                success "Created Property file for IBM FileNet Content Manager Object Store required by BAW authoring or BAW Runtime\n"
            fi

            # generate property for Object store required by AWS
            if [[ (" ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams")) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
                wait_msg "Creating Property file for IBM FileNet Content Manager Object Store required by AWS"
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
                        if [[ $DB_TYPE == "db2"  ]]; then
                            echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        # fi
                        echo "## Provide the user name for the object store database required by AWS. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        echo "## The designated name of the database on the PostgreSQL EDB for the object store required by AWS. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_NAME=\"awsdocs\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "## The designated user name for the object store database required by AWS. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AWSDOCS_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                else
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWSDOCS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

                    echo "## Provide the user name for the object store database required by AWS. For example: \"AWSDOCS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWSDOCS_DB_USER_NAME=\"AWSDOCS\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                        echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.AWSDOCS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## The designated password for the user of Object Store of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.AWSDOCS_DB_USER_PASSWORD=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
                success "Created Property file for IBM FileNet Content Manager Object Store required by AWS\n"
            fi

            # generate property for Object store required by ADP
            if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
                wait_msg "Creating Property file for IBM FileNet Content Manager Object Store required by ADP"

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
                        if [[ $DB_TYPE == "db2"  ]]; then
                            echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        # fi
                        echo "## Provide the user name for the object store database required by ADP. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        echo "## The designated name of the database on the PostgreSQL EDB for the object store required by ADP. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_NAME=\"devos1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "## The designated user name for the object store database required by ADP. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.DEVOS_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                else
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.DEVOS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

                    echo "## Provide the user name for the object store database required by ADP. For example: \"DEVOS1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.DEVOS_DB_USER_NAME=\"DEVOS1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                        echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.DEVOS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## The designated password for the user of Object Store of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.DEVOS_DB_USER_PASSWORD=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
                success "Created Property file for IBM FileNet Content Manager Object Store required by ADP\n"
            fi

            # generate property for AE Data Persistent
            if [[ " ${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
                for i in "${!AEOS[@]}"; do
                    wait_msg "Creating Property file for IBM FileNet Content Manager Object Store required by AE Data Persistent"            
                    if [[ $DB_TYPE != "oracle" ]]; then
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_sample_name=$(echo ${AEOS[i]} | tr '[:upper:]' '[:lower:]')
                                echo "## Provide the name of the database for the object store required by AE Data Persistent. For example: \"$tmp_db_sample_name\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                                echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_NAME=\"$tmp_db_sample_name\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            else
                                echo "## Provide the name of the database for the object store required by AE Data Persistent. For example: \"${AEOS[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                                echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_NAME=\"${AEOS[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi

                            # if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                            if [[ $DB_TYPE == "db2"  ]]; then
                                echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                            fi
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            # fi
                            echo "## Provide the user name of the database for the object store required by AE Data Persistent. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        else
                            echo "## The designated name of the database on the PostgreSQL EDB for the object store required by AE Data Persistent. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_NAME=\"aeos\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "## The designated user name of the database for the object store required by AE Data Persistent. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                            echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_USER_NAME=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}   
                        fi
                    else
                        echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

                        echo "## Provide the user name of the database for the object store required by AE Data Persistent. For example: \"${AEOS[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.${AEOS[i]}_DB_USER_NAME=\"${AEOS[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    if [[ $DB_TYPE != "postgresql-edb" ]]; then
                        echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Object Store of P8Domain. " >> ${DB_NAME_USER_PROPERTY_FILE}
                        if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                            echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                        fi
                        echo "$DB_SERVER_PREFIX.AEOS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    else
                        echo "## The designated password for the user of Object Store of P8Domain. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                        echo "$DB_SERVER_PREFIX.AEOS_DB_USER_PASSWORD=\"osuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    success "Created Property file for IBM FileNet Content Manager Object Store required by AE Data Persistent"
                done     
            fi
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
            # INFO "Created Property file for IBM FileNet Content Manager Object Store"
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
            
            tip="## BAN's Property for ICN Database Name and User on ${DB_TYPE} type database ##"

            echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
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
                    if [[ $DB_TYPE == "db2"  ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.ICN_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    # fi
                else
                    echo "## The designated name of the database on the PostgreSQL EDB for ICN (Navigator). (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
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
                echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.ICN_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

                echo "## Provide the user name of the database for ICN (Navigator). For example: \"ICNDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.ICN_DB_USER_NAME=\"ICNDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) of the database user for ICN (Navigator). " >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                    echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "$DB_SERVER_PREFIX.ICN_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated password of the database user for ICN (Navigator). (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.ICN_DB_USER_PASSWORD=\"icnuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

            # user profile for content initialization
            tip="##       USER Property for BAN   ##"
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            # appLoginUsername/appLoginPassword for BAN
            echo "## Provide the user name for the Navigator administrator. For example: \"BANAdmin\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.APPLOGIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Provide the user password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the Navigator administrator." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.APPLOGIN_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            # ltpaPassword/keystorePassword for BAN
            echo "## Provide a string for ltpaPassword in the ibm-ban-secret that will be used when creating the ltpakey." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text.(NOTES: BAN.LTPA_PASSWORD must same as CONTENT.LTPA_PASSWORD)" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.LTPA_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Provide a string for keystorePassword in the ibm-ban-secret that will be used when creating the keystore." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: BAN.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled.)" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.KEYSTORE_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            # jMailUsername/jMailPassword for BAN
            echo "## Provide the user name for jMail used by BAN. For example: \"jMailAdmin\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.JMAIL_USER_NAME=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## Provide the user password for jMail used by BAN." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "BAN.JMAIL_USER_PASSWORD=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}

            success "Created Property file for IBM Business Automation Navigator\n"
        fi
    fi
    # Create DBNAME/DBUSER property file for ODM
    containsElement "decisions" "${pattern_cr_arr[@]}"
    odm_Val=$?
    if [[ $odm_Val -eq 0 ]]; then
        wait_msg "Creating Property file for IBM Operational Decision Manager"
        
        tip="## ODM's Property for an external database Name and User on ${DB_TYPE} type database ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
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
                # fi
            else
                echo "## The designated name of the database on the PostgreSQL EDB for ODM. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
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
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            echo "$DB_SERVER_PREFIX.ODM_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else
            echo "## The designated password of the database user for ODM. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ODM_DB_USER_PASSWORD=\"odmuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        success "Created Property file for IBM Operational Decision Manager\n"
    fi


    # generate property for ADP
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        wait_msg "Creating Property file for IBM Automation Document Processing"

        tip="## Document Processing's Property for Document Processing Engine (DPE) databases on ${DB_TYPE} type database ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
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
            # fi
            echo "## Provide the user name for the Document Processing Engine Base database. Must be an existing user. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the Document Processing Engine Base database. " >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else
            echo "## The designated database name on the PostgreSQL EDB for Document Processing Engine Base database. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_NAME=\"adpbase\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated user name for the Document Processing Engine Base database. Must be an existing user. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_USER_NAME=\"acauser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## The designated password for the Document Processing Engine Base database. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.ADP_BASE_DB_USER_PASSWORD=\"acauser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                echo "## Important: The keys below for Document Processing Engine Project databases support comma-separated lists. The number of values should match in each comma-separated list." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the database names for the Document Processing Engine Project databases. (For DB2, name must be 8 chars or less, no special chars.) You need two databases per document processing project. Example: \"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_NAME=\"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the database server(s) for the Document Processing Engine Project databases.  Must match the value of \"DB_SERVER_LIST\" defined in cp4ba_db_server.property. Example: \"DBSERVER1,DBSERVER2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_SERVER=\"$DB_SERVER_PREFIX,$DB_SERVER_PREFIX\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the user names for the Document Processing Engine Project databases.  Must be existing users. Example: \"dbuser1,dbuser2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_NAME=\"<youruser1>,<youruser2>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the passwords (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the Document Processing Engine Project databases. Example: \"mypwd1,mypwd2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                    echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "ADP_PROJECT_DB_USER_PASSWORD=\"{Base64}<yourpassword1>,{Base64}<yourpassword2>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the ontology name for each Document Processing Engine Project database. (Must be 8 characters or less, no special chars.) Example: \"ont1,ont1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## You can leave the default values for property below. The name of ontology can be same for all the databases." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_ONTOLOGY=\"ont1,ont1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## Important: The keys below for Document Processing Engine Project databases support comma-separated lists. The number of values should match in each comma-separated list." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated database names on the PostgreSQL EDB for the Document Processing Engine Project databases. You need two databases per document processing project. Example: \"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_NAME=\"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated database server(s) for the Document Processing Engine Project databases.  Must match the value of \"DB_SERVER_LIST\" defined in cp4ba_db_server.property. Example: \"DBSERVER1,DBSERVER2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_SERVER=\"$DB_SERVER_PREFIX,$DB_SERVER_PREFIX\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user names for the Document Processing Engine Project databases. Example: \"dbuser1,dbuser2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_NAME=\"acauser,acauser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated passwords for the Document Processing Engine Project databases. Example: \"mypwd1,mypwd2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_PASSWORD=\"acauser,acauser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        elif [[ " ${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                echo "## Important: The keys below for Document Processing Engine Project databases support comma-separated lists. The number of values should match in each comma-separated list." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the database name(s) for the Document Processing Engine Project database(s). You need one database per document processing project. This key supports comma-separated lists, example: \"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_NAME=\"proj1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the database server(s) for the Document Processing Engine Project databases.  Must match the value of \"DB_SERVER_LIST\" defined in cp4ba_db_server.property. Example: \"DBSERVER1,DBSERVER2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_SERVER=\"$DB_SERVER_PREFIX\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the user name(s) for the Document Processing Engine Project database(s). For example: \"dbuser1,dbuser2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the password(s) (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the Document Processing Engine Project database(s). For example: \"password1,password2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                    echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "ADP_PROJECT_DB_USER_PASSWORD=\"{Base64}<yourpassword1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the ontology name for each Document Processing Engine Project database. (Must be 8 characters or less, no special chars.) Example: \"ont1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## You can leave the default values for property below. The name of ontology can be same for all the databases." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_ONTOLOGY=\"ont1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## Important: The keys below for Document Processing Engine Project databases support comma-separated lists. The number of values should match in each comma-separated list." >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated database name(s) on the PostgreSQL EDB for the Document Processing Engine Project database(s). You need one database per document processing project. This key supports comma-separated lists, example: \"proj1,proj2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_NAME=\"proj1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated database server(s) for the Document Processing Engine Project databases.  Must match the value of \"DB_SERVER_LIST\" defined in cp4ba_db_server.property. Example: \"DBSERVER1,DBSERVER2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_SERVER=\"$DB_SERVER_PREFIX\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name(s) for the Document Processing Engine Project database(s). For example: \"dbuser1,dbuser2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_NAME=\"acauser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password(s) for the Document Processing Engine Project database(s). For example: \"password1,password2\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "ADP_PROJECT_DB_USER_PASSWORD=\"acauser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # user profile for ADP
        tip="##       USER Property for ADP   ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        # serviceUser/servicePwd for ADP
        echo "## Provide the service user name for ADP. For example: \"CN=sampleServiceUser,DC=sampleDC,DC=com\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the service user password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for ADP." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        # serviceUserBas/servicePwdBas for ADP
        echo "## Provide the service base name for ADP. For example: \"CN=sampleBaseUser,DC=sampleDC,DC=com\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_NAME_BASE=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the service base password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for ADP." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_PASSWORD_BASE=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        # serviceUserCa/servicePwdCa for ADP
        echo "## Provide the service ca name for ADP. For example: \"CN=sampleCAUser,DC=sampleDC,DC=com\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_NAME_CA=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the service ca password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for ADP." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.SERVICE_USER_PASSWORD_CA=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        # envOwnerUser/envOwnerPwd for ADP
        echo "## Provide the environment owner name for ADP. For example: \"CN=sampleOwnerUser,DC=sampleDC,DC=com\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.ENV_OWNER_USER_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the environment owner password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for ADP." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.ENV_OWNER_USER_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        # own Enterprise MongoDB instance for ADP
        echo "## If you want to use your own Enterprise MongoDB instance in the environment. The default vaule is \"No\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.USE_EXTERNAL_MONGODB=\"No\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        # mongoUri/mongoUser/mongoPwd for ADP
        echo "## Provide the mongoURI, for example: \"mongodb://mongo:<mongoPwd>@<mongo_database_hostname>:<mongo_database_port>/<mongo_database_name>?authSource=admin&connectTimeoutMS=3000\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.EXTERNAL_MONGO_URI=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the user name for your own Enterprise MongoDB instance used by ADP. For example: \"admin\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.MONGO_USER_NAME=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the user password for your own Enterprise MongoDB instance used by ADP." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADP.MONGO_USER_PASSWORD=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_runtime" ]]; then
            # Add user property into user_profile for ADP when ADP Runtime Environment
            # The repository service url
            echo "## The repository service url." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## For a runtime environment update this value to point to your" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## development cdra environment URL (not service endpoint)." >> ${USER_PROFILE_PROPERTY_FILE}
            
            echo "ADP.CPDS_REPO_SERVICE_URL=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        
            echo "## In 24.0.0, the feedback feature is enhanced to support `distributed` for the 'runtime_type' parameter. The 'distributed' runtime type is only supported in the Runtime environment."  >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## For more information please refer to https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=project-using-feedback-documents-from-applications-improve-training" >> ${USER_PROFILE_PROPERTY_FILE}

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
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "## The content of ZenAPIKey. This is required if runtime_feedback.enabled is true and runtime_type is 'distributed'." >> ${USER_PROFILE_PROPERTY_FILE}
            echo "ADP.RUNTIME_FEEDBACK_DESIGN_ZEN_API_KEY=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}   
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

        success "Created Property file for IBM Automation Document Processing\n"
    fi

    # generate property for Application Engine Database
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "application" ]]; then
        wait_msg "Creating Property file for Application Engine"

        tip="## Application Engine's Property for Application Engine database required on ${DB_TYPE} type database ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
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
                if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"  ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
            else
                echo "## The designated database name on the PostgreSQL EDB for runtime application engine. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
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
            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

            echo "## Provide the user name of the database for the Application Engine database. For example: \"AAEDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_USER_NAME=\"AAEDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Application Engine database. " >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else
            echo "## The designated password for the user of Application Engine database. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_USER_PASSWORD=\"aeuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # Add user property into user_profile for Application Engine
        tip="##           USER Property for AE                 ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
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
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Your external redis port" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_ENGINE.SESSION_REDIS_PORT=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
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
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        success "Created Property file for Application Engine\n"
    fi

    # # generate property for BAW Authoring
    # if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
    #     wait_msg "Creating Property file for IBM Business Automation Workflow"

    #     tip="## Business Automation Workflow's Property for Authoring database required on ${DB_TYPE} type database ##"

    #     echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
    #     echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
    #     echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
    #     if [[ $DB_TYPE != "oracle" ]]; then
    #         echo "## Provide the database name for Business Automation Workflow Authoring. For example: \"BAWAUDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    #         echo "$DB_SERVER_PREFIX.AUTHORING_DB_NAME=\"BAWAUDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    #     fi
    #     if [[ $DB_TYPE != "oracle" ]]; then
    #         echo "## Provide the user name of the database for the Authoring database. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    #         echo "$DB_SERVER_PREFIX.AUTHORING_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    #     else
    #         echo "## Provide the user name of the database for the Authoring database. For example: \"BAWAUDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    #         echo "$DB_SERVER_PREFIX.AUTHORING_DB_USER_NAME=\"BAWAUDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    #     fi
    #     echo "## Provide the password for the user of Authoring database. " >> ${DB_NAME_USER_PROPERTY_FILE}
    #     echo "$DB_SERVER_PREFIX.AUTHORING_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

    #     echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

    #     success "Created Property file for IBM Business Automation Workflow\n"
    # fi

    # generate property for BAW runtime
    if [[ ( (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams") && " ${pattern_cr_arr[@]}" =~ "workflow-runtime" ) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
        wait_msg "Creating Property file for IBM Business Automation Workflow Runtime"

        tip="## Business Automation Workflow Runtime's Property for database on ${DB_TYPE} ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}

        if [[ $DB_TYPE != "oracle" ]]; then
            if [[ $DB_TYPE != "postgresql-edb" ]]; then
                if [[ $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide the database name for Business Automation Workflow Runtime. For example: \"bawdb\" (Notes: the database name must be lowercase)" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_NAME=\"bawdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                else
                    echo "## Provide the database name for Business Automation Workflow Runtime. For example: \"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                    echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_NAME=\"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"  ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "## Provide the user name of the database for Business Automation Workflow Runtime. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of database for Business Automation Workflow Runtime ." >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                    echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated database name on the PostgreSQL EDB for Business Automation Workflow Runtime. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_NAME=\"bawdb0\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name of the database for Business Automation Workflow Runtime. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_NAME=\"bawuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password for the user of database for Business Automation Workflow Runtime. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_PASSWORD=\"bawuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            # To support customize database schema for postgresql and db2
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            #     echo "## Provide the schema name that is used to qualify unqualified database objects in dynamically prepared SQL statements when" >> ${DB_NAME_USER_PROPERTY_FILE}
            #     echo "## the schema name is different from the user name of the database for Business Automation Workflow." >> ${DB_NAME_USER_PROPERTY_FILE}
            #     echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            # fi
        else
            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

            echo "## Provide the database name for Business Automation Workflow Runtime. For example: \"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_NAME=\"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of database required by Business Automation Workflow Runtime." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # Add user property into user_profile for BAW runtime
        tip="##           USER Property for Workflow Runtime        ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        # BAW runtime profile
        echo "## Designate an existing LDAP user for the Workflow Server admin user." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "BAW_RUNTIME.ADMIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        success "Created Property file for IBM Business Automation Workflow Runtime\n"
    fi

    # generate property for AWS
    if [[ ( (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams") && " ${pattern_cr_arr[@]}" =~ "workstreams" ) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
        wait_msg "Creating Property file for IBM Automation Workstream Services"

        tip="## Automation Workstream Services's Property for database on ${DB_TYPE} ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
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
                if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"  ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.AWS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "## Provide the user name of the database for Automation Workstream Services. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.AWS_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of database required by Automation Workstream Services." >> ${DB_NAME_USER_PROPERTY_FILE}
                if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                    echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "$DB_SERVER_PREFIX.AWS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated database name for database on the PostgreSQL EDB required by Automation Workstream Services. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.AWS_DB_NAME=\"awsdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name of the database for Automation Workstream Services. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.AWS_DB_USER_NAME=\"awsuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated password for the user of database required by Automation Workstream Services. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.AWS_DB_USER_PASSWORD=\"awsuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            # To support customize database schema for postgresql and db2
            # if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            #     echo "## Provide the schema name that is used to qualify unqualified database objects in dynamically prepared SQL statements when" >> ${DB_NAME_USER_PROPERTY_FILE}
            #     echo "## the schema name is different from the user name of the database for Automation Workstream Services." >> ${DB_NAME_USER_PROPERTY_FILE}
            #     echo "$DB_SERVER_PREFIX.AWS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            # fi
        else
            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.AWS_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

            echo "## Provide the database name for Automation Workstream Services. For example: \"AWSDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.AWS_DB_USER_NAME=\"AWSDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of database required by Automation Workstream Services." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.AWS_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # Add user property into user_profile for AWS
        tip="##           USER Property for Automation Workstream Services        ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        # AWS profile
        echo "## Designate an existing LDAP user for the Workstreams Server admin user." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "AWS.ADMIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        success "Created Property file for IBM Automation Workstream Services\n"
    fi


    # generate property for Application Engine Playback database
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
        wait_msg "Creating Property file for Application Playback Server"
        
        tip="## Property for Application Engine Playback database on ${DB_TYPE} type database ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
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

                if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"  ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "## Provide the user name of the database for Application Engine Playback database . For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated database name on the PostgreSQL EDB for Application Engine Playback database . (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_NAME=\"appdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name of the database for Application Engine Playback database . (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_USER_NAME=\"appuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        else
            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

            echo "## Provide the user name of the database for Application Engine Playback database . For example: \"APPDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_USER_NAME=\"APPDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Application Engine Playback database . " >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else
            echo "## The designated password for the user of Application Engine Playback database. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.APP_PLAYBACK_DB_USER_PASSWORD=\"appuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

        # Add user property into user_profile for playback server
        tip="##       USER Property for App Engine Playback Server         ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
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
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Your external redis port" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "APP_PLAYBACK.SESSION_REDIS_PORT=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
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
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        success "Created Property file for Application Playback Server\n"
    fi
    # generate property for BAS
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || "${pattern_cr_arr[@]}" =~ "workflow-authoring" || ( "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $EXTERNAL_DB_WFPS_AUTHORING == "Yes") || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then 
        wait_msg "Creating Property file for IBM Business Automation Studio"

        tip="## Business Automation Studio's Property for Studio database required on ${DB_TYPE} type database ##"

        echo "####################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
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
                if [[ $DB_TYPE == "db2" || $DB_TYPE == "postgresql" ]]; then
                    echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
                    if [[ $DB_TYPE == "db2"  ]]; then
                        echo "## For DB2, the schema name is case-sensitive, and must be specified in uppercase characters." >> ${DB_NAME_USER_PROPERTY_FILE}
                    fi
                    echo "$DB_SERVER_PREFIX.STUDIO_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                fi
                echo "## Provide the user name of the database for the Business Automation Studio database. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.STUDIO_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            else
                echo "## The designated database name on the PostgreSQL EDB for Business Automation Studio database . (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.STUDIO_DB_NAME=\"basdb\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## The designated user name of the database for the Business Automation Studio database. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.STUDIO_DB_USER_NAME=\"basuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
        else
            echo "## Provide database schema name. This parameter is optional. If not set, the schema name is the same as database user name." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.STUDIO_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}

            echo "## Provide the user name of the database for the Business Automation Studio database. For example: \"BASDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.STUDIO_DB_USER_NAME=\"BASDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            echo "## Provide the password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for the user of Business Automation Studio database." >> ${DB_NAME_USER_PROPERTY_FILE}
            if [[ $DB_TYPE == "postgresql" && $FIPS_ENABLED == "true" ]]; then
                echo "## Ensure the length of PostgreSQL DB password must be 16 characters or longer when FIPS enabled and only password authenticaion selected." >> ${DB_NAME_USER_PROPERTY_FILE}
            fi
            echo "$DB_SERVER_PREFIX.STUDIO_DB_USER_PASSWORD=\"{Base64}<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else
            echo "## The designated password for the user of Business Automation Studio database. (Notes: DO NOT change the value in the property)" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.STUDIO_DB_USER_PASSWORD=\"basuser\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

    fi

    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || "${pattern_cr_arr[@]}" =~ "workflow-authoring" || "${pattern_cr_arr[@]}" =~ "workflow-process-service" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then 

        # Add user property into user_profile for BAS
        tip="##           USER Property for BAS                ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        # BAS user profile
        echo "## Designate an existing LDAP user for the BAStudio admin user." >> ${USER_PROFILE_PROPERTY_FILE}
        if [[ $LDAP_WFPS_AUTHORING == "No" ]]; then
            echo "BASTUDIO.ADMIN_USER=\"\"" >> ${USER_PROFILE_PROPERTY_FILE}
        else
            echo "BASTUDIO.ADMIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        fi
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        success "Created Property file for IBM Business Automation Studio\n"
    fi

    if [[ " ${pattern_cr_arr[@]}" =~ "decisions_ads" ]]; then
        # user profile for ADS
        tip="##       USER Property for ADS   ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}

        # gitMongoUri/mongoUri/mongoHistoryUri/runtimeMongoUri for ADS
        echo "## Instantiating an external MongoDB is highly recommended for production use. Default value is \"Yes\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If change it to \"No\", you must input an empty value \"\" to the other related parameters." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADS.USE_EXTERNAL_MONGODB=\"Yes\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Provide the gitMongoUri, for example: \"mongodb+srv://<sampleDbUser>:<sampleDbPassword>@<mongodb0.example.com>:27017/ads-git?retryWrites=true&w=majority&authSource=admin\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADS.EXTERNAL_GIT_MONGO_URI=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the mongoURI, for example: \"mongodb+srv://<sampleDbUser>:<sampleDbPassword>@<mongodb1.example.com>:27017/ads?retryWrites=true&w=majority&authSource=admin\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADS.EXTERNAL_MONGO_URI=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the mongoHistoryUri, for example: \"mongodb+srv://<sampleDbUser>:<sampleDbPassword>@<mongodb1.example.com>:27017/ads-history?retryWrites=true&w=majority&authSource=admin\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADS.EXTERNAL_MONGO_HISTORY_URI=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Provide the runtimeMongoUri, for example: \"mongodb+srv://<sampleDbUser>:<sampleDbPassword>@<mongodb1.example.com>:27017/ads-runtime-archive-metadata?retryWrites=true&w=majority&authSource=admin\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ADS.EXTERNAL_RUNTIME_MONGO_URI=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    fi

    # Create USER_PROFILE_PROPERTY for IM SCIM attribute mappings for SDS/MSAD
    set_scim_attr="true"
    if [[ "${set_scim_attr}" == "true" ]]; then
      if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" || (" ${pattern_cr_arr[@]}" =~ "workflow-process-service" && "${optional_component_cr_arr[@]}" =~ "wfps_authoring") ]]; then
        if [[ $LDAP_TYPE == "AD" ]]; then
            LDAP_NAME="Microsoft Active Directory"
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            LDAP_NAME="IBM Security Directory Server"
        fi

        # user profile SCMI User section
        tip="##       USER Property for the customized IAM SCIM LDAP attributes for the LDAP ($LDAP_NAME) configuration       ##"
        echo "###########################################################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo $tip >> ${USER_PROFILE_PROPERTY_FILE}
        echo "###########################################################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## [NOTES:]" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## For information about SCIM parameters used by the CP4BA deployment, you can refer below link: " >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=parameters-ldap-configuration#ldap_kubernetes__scim." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## For information about LDAP attributes, you can use the ldapsearch tool or other LDAP browser utilitise." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## How to use ldapsearch tool to get LDAP attributes, you can refer below link: " >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.4?topic=users-updating-scim-ldap-attributes-mapping#about_ldap_attributes." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ $LDAP_TYPE == "AD" ]]; then
            tmp_val="dn"
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            tmp_val="dn"
        fi

        echo "## Provide the user unique id attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## This attribute MUST be set to an LDAP attribute that is unique and immutable." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "SCIM.USER_UNIQUE_ID_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ $LDAP_TYPE == "AD" ]]; then
            tmp_val="sAMAccountName"
        elif [[ $LDAP_TYPE == "TDS" ]]; then
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
        fi
        echo "## Provide the user display name attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "SCIM.USER_DISPLAY_NAME_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ $LDAP_TYPE == "AD" ]]; then
            tmp_val="givenName"
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            tmp_val="cn"
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
        fi
        echo "## Provide the user created attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "SCIM.USER_CREATED_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ $LDAP_TYPE == "AD" ]]; then
            tmp_val="whenChanged"
        elif [[ $LDAP_TYPE == "TDS" ]]; then
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
            tmp_val="dn"
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            tmp_val="dn"
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
        fi
        echo "## Provide the group created attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "SCIM.GROUP_CREATED_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ $LDAP_TYPE == "AD" ]]; then
            tmp_val="whenChanged"
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            tmp_val="modifyTimestamp"
        fi
        echo "## Provide the group lastModified attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "SCIM.GROUP_LASTMODIFIED_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ $LDAP_TYPE == "AD" ]]; then
            tmp_val="group"
        elif [[ $LDAP_TYPE == "TDS" ]]; then
            tmp_val="groupOfUniqueNames"
        fi
        echo "## Provide the group object class attribute, the default value \"$tmp_val\" for \"$LDAP_NAME\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "SCIM.GROUP_OBJECT_CLASS_ATTRIBUTE=\"$tmp_val\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        if [[ $LDAP_TYPE == "AD" ]]; then
            tmp_val="member"
        elif [[ $LDAP_TYPE == "TDS" ]]; then
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
    ${SED_COMMAND} "s|HADR_STANDBY_SERVERNAME=\"<Required>\"|HADR_STANDBY_SERVERNAME=\"<Optional>\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
    ${SED_COMMAND} "s|HADR_STANDBY_PORT=\"<Required>\"|HADR_STANDBY_PORT=\"<Optional>\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
    fi

    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "No") ]]; then
        ${SED_COMMAND} "s|LDAP_BIND_DN_PASSWORD=\"\"|LDAP_BIND_DN_PASSWORD=\"{Base64}<Required>\"|g" ${LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|=\"\"|=\"<Required>\"|g" ${LDAP_PROPERTY_FILE}
        ${SED_COMMAND} 's/LC_AD_GC_HOST="<Required>"/LC_AD_GC_HOST=""/g' ${LDAP_PROPERTY_FILE}
        ${SED_COMMAND} 's/LC_AD_GC_PORT="<Required>"/LC_AD_GC_PORT=""/g' ${LDAP_PROPERTY_FILE}

    fi

    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        ${SED_COMMAND} "s|LDAP_BIND_DN_PASSWORD=\"\"|LDAP_BIND_DN_PASSWORD=\"{Base64}<Required>\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|=\"\"|=\"<Required>\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} 's/LC_AD_GC_HOST="<Required>"/LC_AD_GC_HOST=""/g' ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} 's/LC_AD_GC_PORT="<Required>"/LC_AD_GC_PORT=""/g' ${EXTERNAL_LDAP_PROPERTY_FILE}
    fi

    INFO "Created all property files for CP4BA"
    
    # Show some tips for property file
    tips
    echo -e  "Enter the <Required> values in the property files under $PROPERTY_FILE_FOLDER"
    msgRed   "The key name in the property file is created by the cp4a-prerequisites.sh and is NOT EDITABLE."
    msgRed   "The value in the property file must be within double quotes."
    msgRed   "The value for User/Password in [cp4ba_db_name_user.property] [cp4ba_user_profile.property] file should NOT include special characters: single quotation \"'\""
    msgRed   "The value in [cp4ba_LDAP.property] or [cp4ba_External_LDAP.property] [cp4ba_user_profile.property] file should NOT include special character '\"'"

    if (( db_server_number > 0 )); then
        echo -e  "\x1b[32m* [cp4ba_db_server.property]:\x1B[0m"
        echo -e  "  - Properties for database server used by CP4BA deployment, such as DATABASE_SERVERNAME/DATABASE_PORT/DATABASE_SSL_ENABLE.\n"
        echo -e  "  - The value of \"<DB_SERVER_LIST>\" is an alias for the database servers. The key supports comma-separated lists.\n"

        echo -e  "\x1b[32m* [cp4ba_db_name_user.property]:\x1B[0m"
        echo -e  "  - Properties for database name and user name required by each component of the CP4BA deployment, such as GCD_DB_NAME/GCD_DB_USER_NAME/GCD_DB_USER_PASSWORD.\n"
        echo -e  "  - Change the prefix \"<DB_SERVER_NAME>\" to assign which database is used by the component.\n"
        echo -e  "  - The value of \"<DB_SERVER_NAME>\" must match the value of <DB_SERVER_LIST> that is defined in \"<DB_SERVER_LIST>\" of \"cp4ba_db_server.property\".\n"
    fi
    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "No") ]]; then
        echo -e  "\x1b[32m* [cp4ba_LDAP.property]:\x1B[0m"
        echo -e  "  - Properties for the LDAP server that is used by the CP4BA deployment, such as LDAP_SERVER/LDAP_PORT/LDAP_BASE_DN/LDAP_BIND_DN/LDAP_BIND_DN_PASSWORD.\n"
        if [[ $SET_EXT_LDAP == "Yes" ]]; then
            echo -e  "\x1b[32m* [cp4ba_External_LDAP.property]:\x1B[0m"
            echo -e  "  - Properties for the External LDAP server that is used by External Share, such as LDAP_SERVER/LDAP_PORT/LDAP_BASE_DN/LDAP_BIND_DN/LDAP_BIND_DN_PASSWORD.\n"
        fi
    fi

    echo -e  "\x1b[32m* [cp4ba_user_profile.property]:\x1B[0m"
    echo -e  "  - Properties for the global value used by the CP4BA deployment, such as \"sc_deployment_license\".\n"
    echo -e  "  - properties for the value used by each component of CP4BA, such as <APPLOGIN_USER>/<APPLOGIN_PASSWORD>\n"
}

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

    while [[ $block_storage_class_name == "" ]] # While get block storage clase name
    do
        printf "\x1B[1mplease enter the block storage classname for Zen(RWO): \x1B[0m"
        read -rp "" block_storage_class_name
        if [ -z "$block_storage_class_name" ]; then
        echo -e "\x1B[1;31mEnter a valid block storage classname(RWO)\x1B[0m"
        fi
    done

    STORAGE_CLASS_NAME=${storage_class_name}
    SLOW_STORAGE_CLASS_NAME=${sc_slow_file_storage_classname}
    MEDIUM_STORAGE_CLASS_NAME=${sc_medium_file_storage_classname}
    FAST_STORAGE_CLASS_NAME=${sc_fast_file_storage_classname}
    BLOCK_STORAGE_CLASS_NAME=${block_storage_class_name}

}

function load_property_before_generate(){
    if [[ ! -f $TEMPORARY_PROPERTY_FILE || ! -f $DB_NAME_USER_PROPERTY_FILE || ! -f $DB_SERVER_INFO_PROPERTY_FILE || ! -f $LDAP_PROPERTY_FILE ]]; then
        fail "Not Found existing property file under \"$PROPERTY_FILE_FOLDER\""
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

    # load CONTENT_OS_NUMBER
    content_os_number=$(prop_tmp_property_file CONTENT_OS_NUMBER)
    # msgB "$content_os_number"; sleep 300

    # load DB_SERVER_NUMBER
    db_server_number=$(prop_tmp_property_file DB_SERVER_NUMBER)

    # load external ldap flag
    SET_EXT_LDAP=$(prop_tmp_property_file EXTERNAL_LDAP_ENABLED)

    # load LDAP/DB required flag for wfps
    LDAP_WFPS_AUTHORING=$(prop_tmp_property_file LDAP_WFPS_AUTHORING_FLAG)
    EXTERNAL_DB_WFPS_AUTHORING=$(prop_tmp_property_file EXTERNAL_DB_WFPS_AUTHORING_FLAG)
}

function create_db_script(){
    clear
    local db_name_full_array=()
    local db_user_full_array=()
    local db_user_pwd_full_array=()
    INFO "Generating DB SQL Statement file required by CP4BA deployment based on property file"
    # Generate db2 sql statement file for FNCM
    rm -rf $DB_SCRIPT_FOLDER
    printf "\n"

    # Generate DB SQL for GCD
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "workstreams" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        wait_msg "Creating the DB SQL statement file for FNCM GCD database"
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
                            tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschemaname=$tmp_db_current_schema_name
                    fi
                fi

                tmp_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"

                check_dbserver_name_valid $tmp_dbservername "GCD_DB_USER_NAME"
                # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "GCD_DB_USER_PASSWORD"
                fi
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_fncm_gcddb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_fncm_gcddb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername $tmp_dbschemaname
                elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                    check_db2_name_valid $tmp_dbname $tmp_dbservername "GCD_DB_NAME"
                    create_fncm_gcddb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername $tmp_dbschemaname
                fi
                break
                ;;
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbservername "GCD_DB_USER_NAME"
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "GCD_DB_USER_PASSWORD"
                fi
                create_fncm_gcddb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                break
                ;;
            esac
        done

        # ${SED_COMMAND} "s|\"||g" $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/createGCDDB.sql
        success "Created the DB SQL statement file for FNCM GCD database\n"
    fi

   # Generate DB SQL for Objectstore
    if (( content_os_number > 0 )); then
        for ((j=1;j<=${content_os_number};j++))
        do
            wait_msg "Creating the DB SQL statement file for FNCM Object store database: os${j}db"
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
                                tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbuser="$(prop_db_name_user_property_file OS${j}_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file OS${j}_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name OS${j}_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "OS${j}_DB_USER_NAME"
                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "OS${j}_DB_USER_PASSWORD"
                    fi
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_fncm_osdb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername ${j}
                        # remove db_securityadmin/bulkadmin
                        ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/createOS${j}DB.sql
                        ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/createOS${j}DB.sql
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_fncm_osdb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername ${j} "" $tmp_dbschemaname
                    elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                        check_db2_name_valid $tmp_dbname $tmp_dbservername "OS${j}_DB_NAME"
                        create_fncm_osdb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername ${j} "" $tmp_dbschemaname
                    fi
                    break
                    ;;
                "oracle")
                    tmp_dbuser="$(prop_db_name_user_property_file OS${j}_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file OS${j}_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name OS${j}_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "OS${j}_DB_USER_NAME"
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "OS${j}_DB_USER_PASSWORD"
                    fi
                    create_fncm_osdb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername ${j}
                    break
                    ;;
                esac
            done            

            # ${SED_COMMAND} "s|\"||g" $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/createOS${j}DB.sql
            success "Created the DB SQL statement file for FNCM Object store database: os${j}db\n"
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
                                tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbuser="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file ICN_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "ICN_DB_USER_NAME"
                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "ICN_DB_USER_PASSWORD"
                    fi
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_ban_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_ban_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername $tmp_dbschemaname
                    elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                        check_db2_name_valid $tmp_dbname $tmp_dbservername "ICN_DB_NAME"
                        create_ban_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername $tmp_dbschemaname
                    fi
                    break
                    ;;
                "oracle")
                    tmp_dbuser="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file ICN_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "ICN_DB_USER_NAME"
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "ICN_DB_USER_PASSWORD"
                    fi
                    create_ban_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    break
                    ;;
                esac
            done
            success "Created the DB SQL statement file for ICN database\n"
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
                check_dbserver_name_valid $tmp_dbservername "ODM_DB_USER_NAME"
                # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "ODM_DB_USER_PASSWORD"
                fi
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_odm_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_odm_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                    check_db2_name_valid $tmp_dbname $tmp_dbservername "ODM_DB_NAME"
                    create_odm_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername
                fi
                break
                ;;
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file ODM_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ODM_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbservername "ODM_DB_USER_NAME"
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "ODM_DB_USER_PASSWORD"
                fi
                create_odm_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                break
                ;;
            esac
        done
        success "Created the DB SQL statement file for Operational Decision Manager database\n"
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
                        check_dbserver_name_valid $tmp_dbservername "${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME"
                        # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                        # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                        # Check base64 encoded or plain text
                        if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                            tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                            check_single_quotes_password $tmp_dbuserpwd "${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD"
                        fi
                        # echo "$tmp_dbuser"; sleep 3
                        wait_msg "Creating the DB SQL statement file for BAW: ${BAW_AUTH_OS_ARR[i]}"
                        if [[ "${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" ]]; then
                            tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                            create_fncm_osdb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" $tmp_tablespace
                        else
                            create_fncm_osdb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                        fi
                        success "Created the DB SQL statement file for BAW: ${BAW_AUTH_OS_ARR[i]}\n"
                    done

                    # for case history
                    tmp_dbuser=$(prop_db_name_user_property_file CHOS_DB_USER_NAME)
                    tmp_dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuser")
                    tmp_dbuserpwd=$(prop_db_name_user_property_file CHOS_DB_USER_PASSWORD)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name CHOS_DB_USER_NAME)"
                    if [[ $tmp_dbservername != \#* ]] ; then
                        check_dbserver_name_valid $tmp_dbservername "CHOS_DB_USER_NAME"
                        # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                        # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                        # Check base64 encoded or plain text
                        if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                            tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                            check_single_quotes_password $tmp_dbuserpwd "CHOS_DB_USER_PASSWORD"
                        fi
                        wait_msg "Creating the DB SQL statement file for Case History: $tmp_dbuser"
                        create_fncm_osdb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                        success "Created the DB SQL statement file for Case History: $tmp_dbuser\n"
                    fi
                fi
                if [[ " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
                    tmp_dbuser=$(prop_db_name_user_property_file AWSDOCS_DB_USER_NAME)
                    tmp_dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuser")
                    tmp_dbuserpwd=$(prop_db_name_user_property_file AWSDOCS_DB_USER_PASSWORD)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "AWSDOCS_DB_USER_NAME"
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "AWSDOCS_DB_USER_PASSWORD"
                    fi
                    # echo "$tmp_dbuser"; sleep 3
                    wait_msg "Creating the DB SQL statement file for BAW: $tmp_dbuser"
                    create_fncm_osdb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
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
                                    tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                                fi
                                tmp_dbschemaname=$tmp_db_current_schema_name
                            fi
                        fi

                        tmp_dbuserpwd=$(prop_db_name_user_property_file ${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD)
                        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                        check_dbserver_name_valid $tmp_dbservername "${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME"
                        
                        # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                        # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                        # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                        # Check base64 encoded or plain text
                        if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                            tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                            check_single_quotes_password $tmp_dbuserpwd "${BAW_AUTH_OS_ARR[i]}_DB_USER_PASSWORD"
                        fi
                        # echo "$tmp_dbname"; sleep 300
                        wait_msg "Creating the DB SQL statement file for BAW: ${BAW_AUTH_OS_ARR[i]}"
                        if [[ $DB_TYPE == "sqlserver" ]]; then
                            if [[ "${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" ]]; then
                                tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                                create_fncm_osdb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" $tmp_tablespace
                            else
                                create_fncm_osdb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                            fi
                            
                            if [[ ! ("${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" || "${BAW_AUTH_OS_ARR[i]}" == "BAWDOS") ]]; then
                                ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                                ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                            fi
                        elif [[ $DB_TYPE == "postgresql" ]]; then
                            if [[ "${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" ]]; then
                                tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                                create_fncm_osdb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" $tmp_tablespace $tmp_dbschemaname
                            else
                                create_fncm_osdb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" "" $tmp_dbschemaname
                            fi
                        elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                            check_db2_name_valid $tmp_dbname $tmp_dbservername "${BAW_AUTH_OS_ARR[i]}_DB_NAME"
                            if [[ "${BAW_AUTH_OS_ARR[i]}" == "BAWTOS" ]]; then
                                tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                                create_fncm_osdb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername "" $tmp_tablespace $tmp_dbschemaname
                            else
                                create_fncm_osdb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername "" "" $tmp_dbschemaname
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
                                tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbuser=$(prop_db_name_user_property_file CHOS_DB_USER_NAME)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name CHOS_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "CHOS_DB_USER_NAME"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file CHOS_DB_USER_PASSWORD)"

                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "CHOS_DB_USER_PASSWORD"
                    fi                     
                    if [[ $tmp_dbservername != \#* ]] ; then
                        wait_msg "Creating the DB SQL statement file for Case History: $tmp_dbname"
                        if [[ $DB_TYPE == "sqlserver" ]]; then
                            create_fncm_osdb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                            # remove db_securityadmin/bulkadmin
                            ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                            ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                        elif [[ $DB_TYPE == "postgresql" ]]; then
                            create_fncm_osdb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" "" $tmp_dbschemaname
                        elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                            check_db2_name_valid $tmp_dbname $tmp_dbservername "CHOS_DB_NAME"
                            create_fncm_osdb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername "" "" $tmp_dbschemaname
                        fi
                        success "Created the DB SQL statement file for Case History: $tmp_dbname\n"
                    fi
                fi
                if [[ " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
                    tmp_dbname=$(prop_db_name_user_property_file AWSDOCS_DB_NAME)
                    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file AWSDOCS_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbuser=$(prop_db_name_user_property_file AWSDOCS_DB_USER_NAME)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "AWSDOCS_DB_USER_NAME"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWSDOCS_DB_USER_PASSWORD)"

                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "AWSDOCS_DB_USER_PASSWORD"
                    fi                    
                    wait_msg "Creating the DB SQL statement file for BAW: $tmp_dbname"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_fncm_osdb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                        # remove db_securityadmin/bulkadmin
                        ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                        ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_fncm_osdb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" "" $tmp_dbschemaname
                    elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                        check_db2_name_valid $tmp_dbname $tmp_dbservername "AWSDOCS_DB_NAME"
                        create_fncm_osdb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername "" "" $tmp_dbschemaname
                    fi
                    success "Created the DB SQL statement file for BAW: $tmp_dbname\n"           
                fi
                if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
                    tmp_dbname=$(prop_db_name_user_property_file DEVOS_DB_NAME)
                    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file DEVOS_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbuser=$(prop_db_name_user_property_file DEVOS_DB_USER_NAME)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name DEVOS_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "DEVOS_DB_USER_NAME"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file DEVOS_DB_USER_PASSWORD)"
                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "DEVOS_DB_USER_PASSWORD"
                    fi
                    wait_msg "Creating the DB SQL statement file for ADP: $tmp_dbname"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_fncm_osdb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                        # remove db_securityadmin/bulkadmin
                        ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                        ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_fncm_osdb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" "" $tmp_dbschemaname
                    elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                        check_db2_name_valid $tmp_dbname $tmp_dbservername "DEVOS_DB_NAME"
                        create_fncm_osdb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername "" "" $tmp_dbschemaname
                    fi
                    success "Created the DB SQL statement file for ADP: $tmp_dbname\n"           
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
        check_dbserver_name_valid $base_dbservername "ADP_BASE_DB_USER_NAME"
        db_name_full_array=(${db_name_full_array[@]} $base_dbname)
        db_user_full_array=(${db_user_full_array[@]} $base_dbuser)
        db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $base_dbuserpwd)

        wait_msg "Creating the DB SQL statement file for Document Processing Engine databases"
        if [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
          check_db2_name_valid $base_dbname $base_dbservername "ADP_BASE_DB_NAME"
        fi
        # Create script for creating base database
        create_adp_basedb_sql $base_dbname $base_dbuser $base_dbservername
        # For DB2, there is separate SQL script for granting permissions on DB
        if [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
          grant_perms_adp_basedb_sql $base_dbname $base_dbuser $base_dbservername
        fi        
        create_adp_basedb_tables_sql $base_dbname $base_dbuser $base_dbservername
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

        if [[ (${#db_name_array[@]} != ${#db_user_array[@]}) || (${#db_user_array[@]} != ${#db_userpwd_array[@]}) || (${#db_name_array[@]} != ${#db_ontology_array[@]}) ]]; then
            fail "The number of values of: ADP_PROJECT_DB_NAME, ADP_PROJECT_DB_USER_NAME, ADP_PROJECT_DB_USER_PASSWORD, ADP_PROJECT_ONTOLOGY must all be equal. Exit ..."
        else
            for num in "${!db_name_array[@]}"; do
                tmp_dbname=${db_name_array[num]}
                tmp_dbuser=${db_user_array[num]}
                tmp_dbuserpwd=${db_userpwd_array[num]}
                tmp_ontology=${db_ontology_array[num]}
                tmp_dbservername=${db_server_array[num]}

                tmp_dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.DATABASE_SERVERNAME)")
                tmp_dbport=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.DATABASE_PORT)")

                db_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.DATABASE_SSL_ENABLE)")
                db_ssl_flag=$(echo $db_ssl_flag| tr '[:upper:]' '[:lower:]') 

                # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                ((j=num+1))
                # echo "$tmp_dbname"; sleep 300
                wait_msg "Creating the DB SQL statement files for Document Processing Engine Project databases: ${db_name_array[num]}"
                # Create script to create tenant DB
                if [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                  check_db2_name_valid $tmp_dbname $tmp_dbservername "ADP_PROJECT_DB_NAME" ${j}
                fi
                create_adp_tenantdb_sql $tmp_dbname $tmp_dbuser $tmp_dbservername ${j}
                # For DB2, there is separate SQL script for granting permissions on DB
                if [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                   grant_perms_adp_tenantdb_sql $tmp_dbname $tmp_dbuser $tmp_dbservername ${j}
                fi                
                # Create script to create tables in tenant DB
                create_adp_tenantdb_tables_sql $tmp_dbname $tmp_dbuser $tmp_ontology $tmp_dbservername ${j}
                # Create script for inserting tenant into base DB
                create_adp_insert_tenant_sql $base_dbname $base_dbuser $tmp_dbname $tmp_dbuser $tmp_ontology $tmp_dbservername $db_ssl_flag ${j} $tmp_dbserver $tmp_dbport
                success "Created the DB SQL statement files for Document Processing Engine Project databases: ${db_name_array[num]}\n"          
            done
        fi

        # set flag for CA database PostgresQL to true, so we can output certain help statements
        if [[ $DB_TYPE == "postgresql" ]]; then
          ca_db_pg_flag=true
        fi

    fi

    # Generate DB SQL for AE data persistent
    if [[ " ${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
        wait_msg "Creating the DB SQL statement file for Application Engine Data Persistent"
        while true; do
            case "$DB_TYPE" in
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file AEOS_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file AEOS_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AEOS_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbservername "AEOS_DB_USER_NAME"
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "AEOS_DB_USER_PASSWORD"
                fi
                create_fncm_osdb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
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
                            tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschemaname=$tmp_db_current_schema_name
                    fi
                fi

                tmp_dbuser="$(prop_db_name_user_property_file AEOS_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file AEOS_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AEOS_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbservername "AEOS_DB_USER_NAME"
                # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "AEOS_DB_USER_PASSWORD"
                fi
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_fncm_osdb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    # remove db_securityadmin/bulkadmin
                    ${SED_COMMAND} '/db_securityadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                    ${SED_COMMAND} '/bulkadmin/d' $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$tmp_dbservername/create$tmp_dbname.sql
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_fncm_osdb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" "" $tmp_dbschemaname
                elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                    check_db2_name_valid $tmp_dbname $tmp_dbservername "AEOS_DB_NAME"
                    create_fncm_osdb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername "" "" $tmp_dbschemaname
                fi
                break
                ;;
            esac
        done
        success "Created the DB SQL statement file for Application Engine Data Persistent\n" 
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
    #             check_dbserver_name_valid $tmp_dbservername "AUTHORING_DB_USER_NAME"
    #             db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
    #             db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
    #             db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
    #             if [[ $DB_TYPE == "sqlserver" ]]; then
    #                 create_baw_db_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
    #             elif [[ $DB_TYPE == "postgresql" ]]; then
    #                 create_baw_db_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
    #             elif [[ $DB_TYPE == "db2" ]]; then
    #                 create_baw_db_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername  
    #             fi
    #             break
    #             ;;
    #         "oracle")
    #             tmp_dbuser="$(prop_db_name_user_property_file AUTHORING_DB_USER_NAME)"
    #             tmp_dbuserpwd="$(prop_db_name_user_property_file AUTHORING_DB_USER_PASSWORD)"
    #             tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AUTHORING_DB_USER_NAME)"
    #             check_dbserver_name_valid $tmp_dbservername "AUTHORING_DB_USER_NAME"
    #             db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
    #             db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

    #             create_baw_db_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
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
                                tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                            fi
                            tmp_dbschemaname=$tmp_db_current_schema_name
                        fi
                    fi

                    tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "BAW_RUNTIME_DB_USER_NAME"

                    # db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "BAW_RUNTIME_DB_USER_PASSWORD"
                    fi
                    wait_msg "Creating the DB SQL statement file for Business Automation Workflow database instance1 required by BAW"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_bawaws1_db_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_bawaws1_db_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername $tmp_dbschemaname
                    elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                        check_db2_name_valid $tmp_dbname $tmp_dbservername "BAW_RUNTIME_DB_NAME"
                        create_bawaws1_db_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername $tmp_dbschemaname
                    fi
                    success "Created the DB SQL statement file for Business Automation Workflow database instance1 required by BAW\n"

                    tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
                    tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "AWS_DB_USER_NAME"

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file AWS_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
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
                        check_single_quotes_password $tmp_dbuserpwd "AWS_DB_USER_PASSWORD"
                    fi
                    wait_msg "Creating the DB SQL statement file for Business Automation Workflow database instance2 required by AWS"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_bawaws2_db_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_bawaws2_db_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername $tmp_dbschemaname
                    elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                        check_db2_name_valid $tmp_dbname $tmp_dbservername "AWS_DB_NAME"
                        create_bawaws2_db_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername $tmp_dbschemaname
                    fi
                    success "Created the DB SQL statement file for Business Automation Workflow database instance2 required by AWS\n"      
                elif [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
                    tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "BAW_RUNTIME_DB_USER_NAME"

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
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
                        check_single_quotes_password $tmp_dbuserpwd "BAW_RUNTIME_DB_USER_PASSWORD"
                    fi
                    wait_msg "Creating the DB SQL statement file for database required by Business Automation Workflow Runtime"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_bawaws1_db_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_bawaws1_db_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername $tmp_dbschemaname
                    elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                        check_db2_name_valid $tmp_dbname $tmp_dbservername "BAW_RUNTIME_DB_NAME"
                        create_bawaws1_db_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername $tmp_dbschemaname
                    fi
                    success "Created the DB SQL statement file for database required by Business Automation Workflow Runtime\n"
                elif [[ " ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
                    tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "AWS_DB_USER_NAME"

                    tmp_dbschemaname=""
                    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                        tmp_db_current_schema_name="$(prop_db_name_user_property_file AWS_DB_CURRENT_SCHEMA)"
                        tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                        if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                            if [[ $DB_TYPE == "postgresql" ]]; then
                                tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
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
                        check_single_quotes_password $tmp_dbuserpwd "AWS_DB_USER_PASSWORD"
                    fi

                    wait_msg "Creating the DB SQL statement file for database required by Automation Workstream Services"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_bawaws2_db_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_bawaws2_db_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername $tmp_dbschemaname
                    elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                        check_db2_name_valid $tmp_dbname $tmp_dbservername "AWS_DB_NAME"
                        create_bawaws2_db_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername $tmp_dbschemaname
                    fi
                    success "Created the DB SQL statement file for database required by Automation Workstream Services\n"                    
                fi
                break
                ;;
            "oracle")
                if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "BAW_RUNTIME_DB_USER_NAME"

                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "BAW_RUNTIME_DB_USER_PASSWORD"
                    fi

                    wait_msg "Creating the DB SQL statement file for Business Automation Workflow database instance1 required by BAW"
                    create_bawaws1_db_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    success "Created the DB SQL statement file for Business Automation Workflow database instance1 required by BAW\n"

                    tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "AWS_DB_USER_NAME"

                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "AWS_DB_USER_PASSWORD"
                    fi

                    wait_msg "Creating the DB SQL statement file for Business Automation Workflow database instance1 required by BAW"
                    create_bawaws2_db_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    success "Created the DB SQL statement file for Business Automation Workflow database instance1 required by BAW\n"
                elif [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "BAW_RUNTIME_DB_USER_NAME"

                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "BAW_RUNTIME_DB_USER_PASSWORD"
                    fi

                    wait_msg "Creating the DB SQL statement file for database required by Business Automation Workflow Runtime"
                    create_bawaws1_db_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    success "Created the DB SQL statement file for database required by Business Automation Workflow Runtime\n"

                elif [[ " ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
                    tmp_dbuser="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file AWS_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name AWS_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "AWS_DB_USER_NAME"

                    # db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    # db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                    # Check base64 encoded or plain text
                    if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                        tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                        check_single_quotes_password $tmp_dbuserpwd "AWS_DB_USER_PASSWORD"
                    fi

                    wait_msg "Creating the DB SQL statement file for database required by Business Automation Workflow Runtime"
                    create_bawaws2_db_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    success "Created the DB SQL statement file for database required by Business Automation Workflow Runtime\n"

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
                check_dbserver_name_valid $tmp_dbservername "STUDIO_DB_USER_NAME"

                tmp_dbschemaname=""
                if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                    tmp_db_current_schema_name="$(prop_db_name_user_property_file STUDIO_DB_CURRENT_SCHEMA)"
                    tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                    if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschemaname=$tmp_db_current_schema_name
                    fi
                fi

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "STUDIO_DB_USER_PASSWORD"
                fi

                db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_bas_studio_db_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_bas_studio_db_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername $tmp_dbschemaname
                elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                    check_db2_name_valid $tmp_dbname $tmp_dbservername "STUDIO_DB_NAME"
                    create_bas_studio_db_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername $tmp_dbschemaname
                fi
                break
                ;;
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file STUDIO_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name STUDIO_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbservername "STUDIO_DB_USER_NAME"

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "STUDIO_DB_USER_PASSWORD"
                fi

                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                create_bas_studio_db_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                break
                ;;
            esac
        done
        success "Created the DB SQL statement file for BAS Studio database\n"
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
                check_dbserver_name_valid $tmp_dbservername "APP_PLAYBACK_DB_USER_NAME"

                tmp_dbschemaname=""
                if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                    tmp_db_current_schema_name="$(prop_db_name_user_property_file APP_PLAYBACK_DB_CURRENT_SCHEMA)"
                    tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                    if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschemaname=$tmp_db_current_schema_name
                    fi
                fi

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "APP_PLAYBACK_DB_USER_PASSWORD"
                fi

                db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_ae_playback_db_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_ae_playback_db_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername $tmp_dbschemaname
                elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                    check_db2_name_valid $tmp_dbname $tmp_dbservername "APP_PLAYBACK_DB_NAME"
                    create_ae_playback_db_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername $tmp_dbschemaname
                fi
                break
                ;;
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name APP_PLAYBACK_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbservername "APP_PLAYBACK_DB_USER_NAME"

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "APP_PLAYBACK_DB_USER_PASSWORD"
                fi

                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                create_ae_playback_db_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                break
                ;;
            esac
        done

        success "Created the DB SQL statement file for Application Engine Playback database\n"
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
                check_dbserver_name_valid $tmp_dbservername "APP_ENGINE_DB_USER_NAME"

                tmp_dbschemaname=""
                if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                    tmp_db_current_schema_name="$(prop_db_name_user_property_file APP_ENGINE_DB_CURRENT_SCHEMA)"
                    tmp_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_current_schema_name")
                    if [[ $tmp_db_current_schema_name != "<Optional>" && $tmp_db_current_schema_name != "" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            tmp_db_current_schema_name=$(echo $tmp_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschemaname=$tmp_db_current_schema_name
                    fi
                fi

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "APP_ENGINE_DB_USER_PASSWORD"
                fi
                # echo "debug"; sleep 3000
                db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_baa_app_engine_db_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_baa_app_engine_db_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername $tmp_dbschemaname
                elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" ]]; then
                    check_db2_name_valid $tmp_dbname $tmp_dbservername "APP_ENGINE_DB_NAME"
                    create_baa_app_engine_db_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername $tmp_dbschemaname
                fi
                break
                ;;
            "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name APP_ENGINE_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbservername "APP_ENGINE_DB_USER_NAME"

                # Check base64 encoded or plain text
                if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                    tmp_dbuserpwd=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                    check_single_quotes_password $tmp_dbuserpwd "APP_ENGINE_DB_USER_PASSWORD"
                fi

                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                create_baa_app_engine_db_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                break
                ;;
            esac
        done
        # ${SED_COMMAND} "s|\"||g" $BAS_DB_SCRIPT_FOLDER/$DB_TYPE/create_bas_playback_db.sql
        success "Created the DB SQL statement file for Application Engine database\n"
    fi

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

function select_external_postgresdb_for_im(){
    printf "\n"
    echo ""
    while true; do
        printf "\x1B[1mDo you want to use an external Postgres DB \x1B[0m${RED_TEXT}[YOU NEED TO CREATE THIS POSTGRESQL DB BY YOURSELF FIRST BEFORE APPLY CP4BA CUSTOM RESOURCE]${RESET_TEXT} \x1B[1mas IM metastore DB for this CP4BA deployment?\x1B[0m ${YELLOW_TEXT}(Notes: IM service can use an external Postgres DB to store IM data. If select \"Yes\", IM service uses an external Postgres DB as IM metastore DB. If select \"No\", IM service uses an embedded cloud native postgresql DB as IM metastore DB.)${RESET_TEXT} (Yes/No, default: No): "
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            EXTERNAL_POSTGRESDB_FOR_IM="true"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            EXTERNAL_POSTGRESDB_FOR_IM="false"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function select_external_postgresdb_for_zen(){
    printf "\n"
    echo ""
    while true; do
        printf "\x1B[1mDo you want to use an external Postgres DB \x1B[0m${RED_TEXT}[YOU NEED TO CREATE THIS POSTGRESQL DB BY YOURSELF FIRST BEFORE APPLY CP4BA CUSTOM RESOURCE]${RESET_TEXT}\x1B[1m as Zen metastore DB for this CP4BA deployment?\x1B[0m ${YELLOW_TEXT}(Notes: Zen stores all metadata such as users, groups, service instances, vault integration, secret references in metastore DB. If select \"Yes\", Zen service uses an external Postgres DB as Zen metastore DB. If select \"No\", Zen service uses an embedded cloud native postgresql DB as Zen metastore DB )${RESET_TEXT} (Yes/No, default: No): "
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            EXTERNAL_POSTGRESDB_FOR_ZEN="true"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            EXTERNAL_POSTGRESDB_FOR_ZEN="false"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function select_external_postgresdb_for_bts(){
    printf "\n"
    echo ""
    while true; do
        printf "\x1B[1mDo you want to use an external Postgres DB \x1B[0m${RED_TEXT}[YOU NEED TO CREATE THIS POSTGRESQL DB BY YOURSELF FIRST BEFORE APPLY CP4BA CUSTOM RESOURCE]${RESET_TEXT}\x1B[1m as BTS metastore DB for this CP4BA deployment?\x1B[0m ${YELLOW_TEXT}(Notes: BTS service can use an external Postgres DB to store meta data. If select \"Yes\", BTS service uses an external Postgres DB as BTS metastore DB. If select \"No\", BTS service uses an embedded cloud native postgresql DB as BTS metastore DB )${RESET_TEXT} (Yes/No, default: No): "
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            EXTERNAL_POSTGRESDB_FOR_BTS="true"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            EXTERNAL_POSTGRESDB_FOR_BTS="false"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function select_external_cert_opensearch_kafka(){
    printf "\n"
    echo ""
    while true; do
        printf "\x1B[1mDo you want to use an external certificate (root CA) for this Opensearch/Kafka deployment?\x1B[0m ${YELLOW_TEXT}(Notes: Opensearch/Kafka operator can consume external tls certificate. If select \"No\", CP4BA operator will creates leaf certificates based CP4BA's root CA )${RESET_TEXT} (Yes/No, default: No): "
        read -rp "" ans
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
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
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
            isProjExists=`kubectl get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l`  >/dev/null 2>&1

            if [ "$isProjExists" -ne 2 ] ; then
                echo -e "\x1B[1;31mInvalid project name, please enter a existing project name ...\x1B[0m"
                TARGET_PROJECT_NAME=""
            else
                echo -e "\x1B[1mUsing project ${TARGET_PROJECT_NAME}...\x1B[0m"
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
    all_fips_enabled_flag=$(${CLI_CMD} get configmap cp4ba-fips-status --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME -o jsonpath={.data.all-fips-enabled})
    if [ -z $all_fips_enabled_flag ]; then
        FIPS_ENABLED="false"
        info "Not found configmap \"cp4ba-fips-status\" in the project \"$TARGET_PROJECT_NAME\". setting \"shared_configuration.enable_fips\" as \"false\" by default in the final custom resource."
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

    msgRed "You can change the parameter \"LDAP_SSL_ENABLED\" in the property file \"$LDAP_PROPERTY_FILE\" later. \"LDAP_SSL_ENABLED\" is \"TRUE\" by default."
}

function select_profile_type(){
    printf "\n"
    COLUMNS=12
    echo -e "\x1B[1mPlease select the deployment profile (default: small).  Refer to the documentation in CP4BA Knowledge Center for details on profile.\x1B[0m"
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
        echo -e "\x1B[1;31mExisting profile size type found in CR: \"$existing_profile_type\"\x1B[0m"
        # echo -e "\x1B[1;31mDo not need to select again.\n\x1B[0m"
        read -rsn1 -p"Press any key to continue ...";echo        
    fi
}

function select_db_type(){
    printf "\n"
    COLUMNS=12
    echo -e "\x1B[1mWhat is the Database type that is used for this deployment? \x1B[0m"
    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("IBM Db2 Database" "PostgreSQL" "PostgreSQL EDB (deployed by CP4BA Operator)")
        PS3='Enter a valid option [1 to 3]: '
        # else
        #     options=("IBM Db2 Database" "PostgreSQL")
        #     PS3='Enter a valid option [1 to 2]: '
        # fi
    elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-process-service" && "${#PATTERNS_CR_SELECTED[@]}" -eq "1" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("PostgreSQL" "PostgreSQL EDB (deployed by CP4BA Operator)")
        PS3='Enter a valid option [1 to 2]: '
        # else
        #     options=("PostgreSQL")
        #     PS3='Enter a valid option [1 to 1]: '
        # fi
    elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-process-service" && " ${PATTERNS_CR_SELECTED[@]} " =~ "decisions" && "${#PATTERNS_CR_SELECTED[@]}" -eq "2" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("PostgreSQL" "PostgreSQL EDB (deployed by CP4BA Operator)")
        PS3='Enter a valid option [1 to 2]: '
        # else
        #     options=("PostgreSQL")
        #     PS3='Enter a valid option [1 to 1]: '
        # fi
    elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-process-service" && " ${PATTERNS_CR_SELECTED[@]} " =~ "content" && "${#PATTERNS_CR_SELECTED[@]}" -eq "2" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("PostgreSQL" "PostgreSQL EDB (deployed by CP4BA Operator)")
        PS3='Enter a valid option [1 to 2]: '
        # else
        #     options=("PostgreSQL")
        #     PS3='Enter a valid option [1 to 1]: '
        # fi
    elif [[ ("${PATTERNS_CR_SELECTED[@]}" =~ "workflow-authoring" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer") && " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-process-service" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("IBM Db2 Database" "Oracle" "Microsoft SQL Server" "PostgreSQL" "PostgreSQL EDB (deployed by CP4BA Operator)")
        PS3='Enter a valid option [1 to 5]: '
        # else
        #     options=("IBM Db2 Database" "Oracle" "Microsoft SQL Server" "PostgreSQL")
        #     PS3='Enter a valid option [1 to 4]: '
        # fi
    elif [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-process-service" && " ${PATTERNS_CR_SELECTED[@]} " =~ "workflow-runtime" && "${#PATTERNS_CR_SELECTED[@]}" -eq "3" ]]; then
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("PostgreSQL" "PostgreSQL EDB (deployed by CP4BA Operator)")
        PS3='Enter a valid option [1 to 2]: '
        # else
        #     options=("PostgreSQL")
        #     PS3='Enter a valid option [1 to 1]: '
        # fi
    else
        # if [[ $PROFILE_TYPE == "small" ]]; then
        options=("IBM Db2 Database" "Oracle" "Microsoft SQL Server" "PostgreSQL" "PostgreSQL EDB (deployed by CP4BA Operator)")
        PS3='Enter a valid option [1 to 5]: '
        # else
        #     options=("IBM Db2 Database" "Oracle" "Microsoft SQL Server" "PostgreSQL")
        #     PS3='Enter a valid option [1 to 4]: '        
        # fi
    fi
    select opt in "${options[@]}"
    do
        case $opt in
            "IBM Db2 Database")
                DB_TYPE="db2"
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
            "PostgreSQL")
                DB_TYPE="postgresql"
                break
                ;;
            "PostgreSQL EDB (deployed by CP4BA Operator)")
                DB_TYPE="postgresql-edb"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    if [[ $DB_TYPE != "postgresql-edb" ]]; then
        msgRed "You can change the parameter \"DATABASE_SSL_ENABLE\" in the property file \"$DB_SERVER_INFO_PROPERTY_FILE\" later. \"DATABASE_SSL_ENABLE\" is \"TRUE\" by default."
    fi

    if [[ $DB_TYPE == "postgresql" ]]; then
        msgRed "You can change the parameter \"POSTGRESQL_SSL_CLIENT_SERVER\" in the property file \"$DB_SERVER_INFO_PROPERTY_FILE\" later. \"POSTGRESQL_SSL_CLIENT_SERVER\" is \"TRUE\" by default"
        msgRed "- POSTGRESQL_SSL_CLIENT_SERVER=\"True\": For a PostgreSQL database with both server and client authentication"
        msgRed "- POSTGRESQL_SSL_CLIENT_SERVER=\"False\": For a PostgreSQL database with server-only authentication"
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

function select_ae_data_persistence(){
    if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence" ]]; then
        foundation_component_arr=( "${foundation_component_arr[@]}" "AE" )
        AE_DATA_PERSISTENCE_ENABLE="Yes"
    else
        if [[ (" ${PATTERNS_CR_SELECTED[@]} " =~ "application") ]]; then
            printf "\n"
            while true; do
                printf "\x1B[1mDo you want to enable Business Automation Application Data Persistence? (Yes/No, default: No): \x1B[0m"
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

function input_information(){
    EXISTING_OPT_COMPONENT_ARR=()
    EXISTING_PATTERN_ARR=()
    retVal_baw=1
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
    # whether wfps authoring require LDAP
    if [[ "${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" ]]; then
        select_ldap_type_for_wfps_authoring
    fi

    if [[ -z $LDAP_WFPS_AUTHORING || $LDAP_WFPS_AUTHORING == "Yes" ]]; then
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
        select_restricted_internet_access
        select_external_postgresdb_for_im
        select_external_postgresdb_for_zen
        select_external_postgresdb_for_bts
        select_external_cert_opensearch_kafka
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

    create_temp_property_file
}

function select_objectstore_number(){
    content_os_number=""
    while true; do
        printf "\n"
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
            info "One default FNCM object store \"DEVOS1\" is added into property file. You could add more custom object store for ADP/Content pattern."
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

function select_db_server_number(){
    db_server_number=""
    while true; do
        printf "\n"
        printf "\x1B[1mHow many database servers or instances will be used for the CP4BA deployment? \x1B[0m"
        read -rp "" db_server_number
        [[ $db_server_number =~ ^[0-9]+$ ]] || { echo -e "\x1B[1;31mEnter a valid number [1 to 999]\x1B[0m"; continue; }
        if [ "$db_server_number" -ge 1 ] && [ "$db_server_number" -le 999 ]; then
            break
        else
            echo -e "\x1B[1;31mEnter a valid number [1 to 999]\x1B[0m"
            db_server_number=""
        fi
    done
}

function get_db_server_list(){
    local db_server_list_input=""
    while true; do
        printf "\n"
        printf "\x1B[1mEnter the alias name(s) for the database server(s)/instance(s) to be used by the CP4BA deployment.\x1B[0m\n"
        echo -e "\x1B[1;31m(NOTE: NOT the host name of the database server, and CANNOT include a dot[.] character)\x1B[0m"
        echo -e "\x1B[1;31m(NOTE: This key supports comma-separated lists (for example: dbserver1,dbserver2,dbserver3)\x1B[0m"
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then   
            echo -e "\x1B[1;31m(NOTE: IBM Automation Document Processing only supports 1 database server. For Automation Document processing, only the first database server in the list is used.)\x1B[0m"
        fi
        read -rp "The alias name(s): " db_server_list_input
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



function clean_up_temp_file(){
    local files=()
    files=($(find $PREREQUISITES_FOLDER -name '*.*""'))
    for item in ${files[*]}
    do
        rm -rf $item >/dev/null 2>&1
    done
    
    files=($(find $TEMP_FOLDER -name '*.*""'))
    for item in ${files[*]}
    do
        rm -rf $item >/dev/null 2>&1
    done
}

function generate_create_secret_script(){
    local files=()
    local CREATE_SECRET_SCRIPT_FILE_TMP=$TEMP_FOLDER/create_secret.sh
    > ${CREATE_SECRET_SCRIPT_FILE_TMP}
    > ${CREATE_SECRET_SCRIPT_FILE}
    files=($(find $SECRET_FILE_FOLDER -name '*.yaml'))
    for item in ${files[*]}
    do
        echo "echo \"****************************************************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"******************************* START **************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"[INFO] Applying YAML template file:$item\"">> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "kubectl apply -f \"$item\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"******************************** END ***************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"****************************************************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "printf \"\\n\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
    done
    
    files=($(find $SECRET_FILE_FOLDER -name '*.sh'))
    for item in ${files[*]}
    do
        echo "echo \"****************************************************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"******************************* START **************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"[INFO] Executing shell script:$item\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "$item" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"******************************** END ***************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"****************************************************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "printf \"\\n\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
    done
    ${COPY_CMD} -rf ${CREATE_SECRET_SCRIPT_FILE_TMP} ${CREATE_SECRET_SCRIPT_FILE}
    chmod 755 $CREATE_SECRET_SCRIPT_FILE
}


function validate_secret_in_cluster(){
    INFO "Checking the Kubernetes secret required by CP4BA existing in cluster or not" 
    local files=()
    SECRET_CREATE_PASSED="true"
    files=($(find $SECRET_FILE_FOLDER -name '*.yaml'))
    for item in ${files[*]}
    do
        secret_name_tmp=`cat $item | ${YQ_CMD} r - metadata.name`
        if [ -z "$secret_name_tmp" ]; then
            error "Not found secret name in YAML file: \"$item\"! Please check and fix it"
            exit 1
        else
            secret_name_tmp=$(sed -e 's/^"//' -e 's/"$//' <<<"$secret_name_tmp")
            # need to check ibm-zen-metastore-edb-cm/im-datastore-edb-cm for Zen/IM and ibm-bts-config-extension external postgresql db support
            if [[ $secret_name_tmp != "ibm-zen-metastore-edb-cm" && $secret_name_tmp != "im-datastore-edb-cm" && $secret_name_tmp != "ibm-bts-config-extension" ]]; then
                secret_exists=`kubectl get secret $secret_name_tmp --ignore-not-found | wc -l`  >/dev/null 2>&1
                if [ "$secret_exists" -ne 2 ] ; then
                    error "Not found secret \"$secret_name_tmp\" in Kubernetes cluster! please create it first before deployment CP4BA"
                    SECRET_CREATE_PASSED="false"
                else
                    success "Found secret \"$secret_name_tmp\" in Kubernetes cluster, PASSED!"              
                fi
            else
                secret_exists=`kubectl get configmap $secret_name_tmp --ignore-not-found | wc -l`  >/dev/null 2>&1
                if [ "$secret_exists" -ne 2 ] ; then
                    error "Not found configMap \"$secret_name_tmp\" in Kubernetes cluster! please create it first before deployment CP4BA"
                    SECRET_CREATE_PASSED="false"
                else
                    success "Found configMap \"$secret_name_tmp\" in Kubernetes cluster, PASSED!"              
                fi
            fi
        fi
    done
    
    files=($(find $SECRET_FILE_FOLDER -name '*.sh'))
    for item in ${files[*]}
    do
        if [[ "$machine" == "Mac" ]]; then
            secret_name_tmp=`grep ' create secret generic' $item | tail -1 | cut -d'"' -f2`

            # for DPE secret format specially
            if [ -z "$secret_name_tmp" ]; then
                secret_name_tmp=`grep ' create secret generic' $item | tail -1 | cut -d'"' -f2`
            fi
        else
            secret_name_tmp=`cat $item | grep -oP '(?<=generic ).*?(?= --from-file)'`

            # for DPE secret format specially
            if [ -z "$secret_name_tmp" ]; then
                secret_name_tmp=`cat $item | grep -oP '(?<=generic ).*?(?= \\\\)' | tail -1`
            fi

        fi
        if [ -z "$secret_name_tmp" ]; then
            error "Not found secret name in shell script file: \"$item\"! Please check and fix it"
            exit 1
        else
            secret_name_tmp=$(sed -e 's/^"//' -e 's/"$//' <<<"$secret_name_tmp")
            secret_exists=`kubectl get secret $secret_name_tmp --ignore-not-found | wc -l`  >/dev/null 2>&1
            if [ "$secret_exists" -ne 2 ] ; then
                error "Not found secret \"$secret_name_tmp\" in Kubernetes cluster! please create it first before deployment CP4BA"
                SECRET_CREATE_PASSED="false"
            else
                success "Found secret \"$secret_name_tmp\" in Kubernetes cluster, PASSED!"              
            fi
        fi
    done
    if [[ $SECRET_CREATE_PASSED == "false" ]]; then
        info "Please create secret in Kubernetes cluster correctly, exiting..."
        exit 1
    else
        INFO "All secrets created in Kubernetes cluster, PASSED!"
    fi
}

function validate_prerequisites(){
    # check FIPS enabled or disabled
    fips_flag="$(prop_user_profile_property_file CP4BA.ENABLE_FIPS)"
    fips_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$fips_flag")
    fips_flag=$(echo $fips_flag | tr '[:upper:]' '[:lower:]')

    # validate the storage class
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
        kubectl delete pvc -l cp4ba=test-only >/dev/null 2>&1
        exit 0
    fi
    # Validate Secret for CP4BA
    validate_secret_in_cluster

    # Validate LDAP connection for CP4BA
    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "No") ]]; then
        INFO "Checking LDAP connection required by CP4BA" 
        tmp_servername="$(prop_ldap_property_file LDAP_SERVER)"
        tmp_serverport="$(prop_ldap_property_file LDAP_PORT)"
        tmp_basdn="$(prop_ldap_property_file LDAP_BASE_DN)"
        tmp_ldapssl="$(prop_ldap_property_file LDAP_SSL_ENABLED)"
        tmp_user=`kubectl get secret -l name=ldap-bind-secret -o yaml | ${YQ_CMD} r - items.[0].data.ldapUsername | base64 --decode`
        tmp_userpwd=`kubectl get secret -l name=ldap-bind-secret -o yaml | ${YQ_CMD} r - items.[0].data.ldapPassword | base64 --decode`

        tmp_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_servername")
        tmp_serverport=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_serverport")
        tmp_basdn=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_basdn")
        tmp_ldapssl=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldapssl")
        tmp_ldapssl=$(echo $tmp_ldapssl | tr '[:upper:]' '[:lower:]')
        tmp_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user")
        tmp_userpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_userpwd")

        verify_ldap_connection "$tmp_servername" "$tmp_serverport" "$tmp_basdn" "$tmp_user" "$tmp_userpwd" "$tmp_ldapssl"

        if [[ $SET_EXT_LDAP == "Yes" ]]; then
            # Validate External LDAP connection for CP4BA
            msgB "Checking the External LDAP connection.." 
            tmp_servername="$(prop_ext_ldap_property_file LDAP_SERVER)"
            tmp_serverport="$(prop_ext_ldap_property_file LDAP_PORT)"
            tmp_basdn="$(prop_ext_ldap_property_file LDAP_BASE_DN)"
            tmp_ldapssl="$(prop_ext_ldap_property_file LDAP_SSL_ENABLED)"
            tmp_user=`kubectl get secret -l name=ext-ldap-bind-secret -o yaml | ${YQ_CMD} r - items.[0].data.ldapUsername | base64 --decode`
            tmp_userpwd=`kubectl get secret -l name=ext-ldap-bind-secret -o yaml | ${YQ_CMD} r - items.[0].data.ldapPassword | base64 --decode`

            tmp_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_servername")
            tmp_serverport=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_serverport")
            tmp_basdn=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_basdn")
            tmp_ldapssl=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldapssl")
            tmp_ldapssl=$(echo $tmp_ldapssl | tr '[:upper:]' '[:lower:]')
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
            # check DBNAME/DBUSER for GCDDB
            tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.gcd-db-server`
            tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.gcdDBUsername | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.gcdDBPassword | base64 --decode`        

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
                    # tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
                    tmp_dbserver="$(prop_db_name_user_property_file_for_server_name OS$((j+1))_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbserver "OS$((j+1))_DB_USER_NAME"
                    tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.os$((j+1))DBUsername | base64 --decode`
                    tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.os$((j+1))DBPassword | base64 --decode`        

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
                    # tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
                    tmp_dbserver="$(prop_db_name_user_property_file_for_server_name ${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbserver "${BAW_AUTH_OS_ARR[i]}_DB_USER_NAME"
                    tmp_label=$(echo ${BAW_AUTH_OS_ARR[i]}| tr '[:upper:]' '[:lower:]')
                    tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBUsername | base64 --decode`
                    tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBPassword | base64 --decode`        

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
                    # tmp_label=$(echo ${BAW_AUTH_OS_ARR[i]}| tr '[:upper:]' '[:lower:]')
                    tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.chDBUsername | base64 --decode`
                    tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.chDBPassword | base64 --decode`        

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
                # tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
                tmp_dbserver="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbserver "AWSDOCS_DB_USER_NAME"
                tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.awsdocsDBUsername | base64 --decode`
                tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.awsdocsDBPassword | base64 --decode`        

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
                    # tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
                    tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.aeosDBUsername | base64 --decode`
                    tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.aeosDBPassword | base64 --decode`        

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
                # tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
                tmp_dbserver="$(prop_db_name_user_property_file_for_server_name DEVOS_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbserver "DEVOS_DB_USER_NAME"
                tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.devos1DBUsername | base64 --decode`
                tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.devos1DBPassword | base64 --decode`        
    
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

                tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
                tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.navigatorDBUsername | base64 --decode`
                tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.navigatorDBPassword | base64 --decode`        

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

            tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
            tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.db-user | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.db-password | base64 --decode`        

            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                if [[ $DB_TYPE != "postgresql-edb" ]]; then
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
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

            tmp_dbserver=`kubectl get secret -l base-db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.base-db-server`
            tmp_dbusername=`kubectl get secret -l base-db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.BASE_DB_USER | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l base-db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.BASE_DB_CONFIG | base64 --decode`        

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

            # tmp_dbserver=`kubectl get secret -l base-db-name=${tmp_base_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.base-db-server`
            # tmp_dbusername=`kubectl get secret -l base-db-name=${tmp_base_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.BASE_DB_USER | base64 --decode`

            if [[ ${#db_name_array[@]} != ${#db_user_array[@]} || ${#db_user_array[@]} != ${#db_server_array[@]} ]]; then
                fail "The number of values of: ADP_PROJECT_DB_NAME, ADP_PROJECT_DB_USER_NAME, ADP_PROJECT_DB_SERVER must all be equal. Exit ..."
            else
                # check connection for proj db 
                projs_max_index=${#db_name_array[@]}-1
            
                for num in "${!db_name_array[@]}"; do
                    tmp_dbname=${db_name_array[num]}
                    tmp_dbname=$(echo $tmp_dbname | tr '[:lower:]' '[:upper:]')
                    tmp_dbusername=${db_user_array[num]}
                    # tmp_dbuserpassword=${db_userpwd_array[num]}
                    tmp_dbuserpassword=`kubectl get secret -l base-db-name=${tmp_base_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_dbname}_DB_CONFIG | base64 --decode`
                    tmp_dbserver=${db_server_array[num]}

                    # Check DB non-SSL and SSL and SSL
                    if [[ $DB_TYPE == "oracle" ]]; then
                        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                    else
                        if [[ $DB_TYPE != "postgresql-edb" ]]; then
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

            tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
            tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.AE_DATABASE_USER | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.AE_DATABASE_PWD | base64 --decode`        

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

        #     tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
        #     tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbUser | base64 --decode`
        #     tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.password | base64 --decode`        

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

            tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
            tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbUser | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.password | base64 --decode`        

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

            tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
            tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbUser | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.password | base64 --decode`        

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

            tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
            tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbUser | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.password | base64 --decode`        

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

            tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
            tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbUser | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.password | base64 --decode`        

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

            tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
            tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.AE_DATABASE_USER | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.AE_DATABASE_PWD | base64 --decode`        

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

            tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
            tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbUsername | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbPassword | base64 --decode`
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

    # Check db connection for im/zen/bts external postgresql db
    local DB_JDBC_NAME=${JDBC_DRIVER_DIR}/postgresql
    local DB_CONNECTION_JAR_PATH=${CUR_DIR}/helper/verification/postgresql

    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_IM_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
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

        output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode verify-ca -ca $postgres_cafile -clientkey ${im_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile 2>&1)
        retVal_verify_db_tmp=$?
        connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
        if [[ ! -z $connection_time ]]; then
            echo "Latency: $connection_time ms"
            # Check if elapsed time is greater than 10 ms using awk
            if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
            echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
            elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
            echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
            elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
            echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
            fi
        fi

        [[ retVal_verify_db_tmp -ne 0 ]] && \
        warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode verify-ca -ca $postgres_cafile -clientkey ${im_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile" && \
        fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
        [[ retVal_verify_db_tmp -eq 0 ]] && \
        success "Checked DB connection for \"$dbname\" on database server \"$dbserver\", PASSED!"
    fi

    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_ZEN_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
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

        output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode verify-ca -ca $postgres_cafile -clientkey ${zen_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile 2>&1)
        retVal_verify_db_tmp=$?
        connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
        if [[ ! -z $connection_time ]]; then
            echo "Latency: $connection_time ms"
            # Check if elapsed time is greater than 10 ms using awk
            if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
            echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
            elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
            echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
            elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
            echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
            fi
        fi

        [[ retVal_verify_db_tmp -ne 0 ]] && \
        warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode verify-ca -ca $postgres_cafile -clientkey ${zen_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile" && \
        fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
        [[ retVal_verify_db_tmp -eq 0 ]] && \
        success "Checked DB connection for \"$dbname\" on database server \"$dbserver\", PASSED!"
    fi

    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_tmp_property_file EXTERNAL_POSTGRESDB_FOR_BTS_FLAG)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
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

        output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode verify-ca -ca $postgres_cafile -clientkey ${bts_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile 2>&1)
        retVal_verify_db_tmp=$?
        connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
        if [[ ! -z $connection_time ]]; then
            echo "Latency: $connection_time ms"
            # Check if elapsed time is greater than 10 ms using awk
            if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
            echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
            elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
            echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
            elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
            echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
            fi
        fi

        [[ retVal_verify_db_tmp -ne 0 ]] && \
        warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode verify-ca -ca $postgres_cafile -clientkey ${bts_external_db_cert_folder}/clientkey.pk8 -clientcert $postgres_clientcertfile" && \
        fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
        [[ retVal_verify_db_tmp -eq 0 ]] && \
        success "Checked DB connection for \"$dbname\" on database server \"$dbserver\", PASSED!"
    fi

    info "If all prerequisites check PASSED, you can run cp4a-deployment to deploy CP4BA. Otherwise, please check configuration again."
    info "After CP4BA is deployed, please refer to documentation for post-deployment steps."
}
################################################
#### Begin - Main step for install operator ####
################################################
# select_script_option2
# prompt_license
save_log "cp4a-script-logs" "cp4a-prerequisites-log"
trap cleanup_log EXIT
IBM_LICENS="Accept"
INSTALL_BAW_ONLY="No"

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:p:n:t:a:m:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        m)  RUNTIME_MODE=$OPTARG
            if [[ $RUNTIME_MODE == "property" || $RUNTIME_MODE == "generate" || $RUNTIME_MODE == "validate" ]]; then
                echo
            else
                msg "Use a valid value: -m [property] or [generate] or [validate]"
                exit -1
            fi
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

clear

if [[ $RUNTIME_MODE == "property" ]]; then
    input_information
    create_property_file
    clean_up_temp_file
fi
if [[ $RUNTIME_MODE == "generate" ]]; then

    # reload db type and OS number
    load_property_before_generate
    if (( db_server_number > 0 )); then
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
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
            
            if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            # Import function for DB Script
                source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/adp/create-adp-dbscript.sh
            fi
            # check whether user already input value for the <Required>
        fi
        check_property_file
        if [[ $DB_TYPE != "postgresql-edb" ]]; then
            create_db_script
        fi
    fi

    if [[ $LDAP_WFPS_AUTHORING == "Yes" || -z $LDAP_WFPS_AUTHORING ]]; then
        create_prerequisites
    fi
    clean_up_temp_file
    if (( db_server_number > 0 )); then
        generate_create_secret_script
    fi
fi

if [[ $RUNTIME_MODE == "validate" ]]; then
    echo  "*****************************************************"
    echo  "Validating the prerequisites before you install CP4BA"
    echo  "*****************************************************"
    validate_utility_tool_for_validation
    load_property_before_generate
    validate_prerequisites
fi
################################################
#### End - Main step for install operator ####
################################################
