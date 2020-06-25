#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

CUR_DIR=$(cd $(dirname $0); pwd)
PARENT_DIR=$(dirname "$PWD")

# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh

DOCKER_RES_SECRET_NAME="admin.registrykey"
DOCKER_REG_USER=""
if [[ $1 == "dev" || $1 == "review" ]]
then
    DOCKER_REG_SERVER="cp.stg.icr.io"
else
    DOCKER_REG_SERVER="cp.icr.io"
fi
DOCKER_REG_KEY=""
REGISTRY_IN_FILE="cp.icr.io"
OPERATOR_IMAGE=${DOCKER_REG_SERVER}/cp/cp4a/icp4a-operator:20.0.2

old_db2="docker.io\/ibmcom"
old_ldap="osixia"
old_db2_etcd="quay.io\/coreos"
old_busybox="docker.io\/library"

TEMP_FOLDER=${CUR_DIR}/.tmp
BAK_FOLDER=${CUR_DIR}/.bak
FINAL_CR_FOLDER=${CUR_DIR}/generated-cr

DEPLOY_TYPE_IN_FILE_NAME="" # Default value is empty
OPERATOR_FILE=${PARENT_DIR}/descriptors/operator.yaml
OPERATOR_FILE_TMP=$TEMP_FOLDER/.operator_tmp.yaml
OPERATOR_FILE_BAK=$BAK_FOLDER/.operator.yaml

OPERATOR_PVC_FILE=${PARENT_DIR}/descriptors/operator-shared-pvc.yaml
OPERATOR_PVC_FILE_TMP=$TEMP_FOLDER/.operator-shared-pvc_tmp.yaml
OPERATOR_PVC_FILE_BAK=$BAK_FOLDER/.operator-shared-pvc.yaml

FOUNDATION_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_final_tmp.yaml
FOUNDATION_PATTERN_FILE_BAK=$FINAL_CR_FOLDER/ibm_cp4a_cr_final.yaml
FOUNDATION_EXISTING_BAK=$TEMP_FOLDER/.ibm_cp4a_cr_final_existing_bak.yaml

JDBC_DRIVER_DIR=${CUR_DIR}/jdbc
PLATFORM_SELECTED=""
PATTERN_SELECTED=""
COMPONENTS_SELECTED=""
OPT_COMPONENTS_CR_SELECTED=""
OPT_COMPONENTS_SELECTED=()
LDAP_TYPE=""

FOUNDATION_CR_SELECTED=""
optional_component_arr=()
optional_component_cr_arr=()
foundation_component_arr=()
FOUNDATION_FULL_ARR=("BAN" "RR" "BAS" "UMS")
OPTIONAL_COMPONENT_FULL_ARR=("bai" "css" "cmis" "es" "ums" "ads_designer" "ads_runtime" "app_designer" "decisionCenter" "decisionServerRuntime" "decisionRunner")

function prompt_license(){
    clear
    
    get_baw_mode
    retVal_baw=$?
    
    if [[ $retVal_baw -eq 0 ]]; then
        echo -e "\x1B[1;31mIMPORTANT: Review the IBM Business Automation Workflow license information here: \n\x1B[0m"
        echo -e "\x1B[1;31mhttps://github.com/ibmbpm/BAW-Ctnr/blob/20.0.2/LICENSE\n\x1B[0m"
    fi
    if [[ $retVal_baw -eq 1 ]]; then
        echo -e "\x1B[1;31mIMPORTANT: Review the IBM Cloud Pak for Automation license information here: \n\x1B[0m"
        echo -e "\x1B[1;31mhttps://github.com/icp4a/cert-kubernetes/blob/20.0.2/LICENSE\n\x1B[0m"     
    fi
    
    read -rsn1 -p"Press any key to continue";echo

    printf "\n"
    while true; do
        if [[ $retVal_baw -eq 0 ]]; then
            printf "\x1B[1mDo you accept the IBM Business Automation Workflow license (Yes/No, default: No): \x1B[0m"
        fi
        if [[ $retVal_baw -eq 1 ]]; then
            printf "\x1B[1mDo you accept the IBM Cloud Pak for Automation license (Yes/No, default: No): \x1B[0m"    
        fi
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            echo -e "Installing the Cloud Pak for Automation Operator...\n"
            validate_cli
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            echo -e "Exiting...\n"
            exit 0
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}


function validate_docker_podman_cli(){
    if [[ $OCP_VERSION == "3.11" || "$machine" == "Mac" ]];then 
        which docker &>/dev/null
        [[ $? -ne 0 ]] && \
            echo -e  "\x1B[1;31mUnable to locate docker, please install it firstly.\x1B[0m" && \
            exit 1
    elif [[ $OCP_VERSION == "4.1" || $OCP_VERSION == "4.2" || $OCP_VERSION == "4.3" || $OCP_VERSION == "4.4" ]]
    then
        which podman &>/dev/null
        [[ $? -ne 0 ]] && \
            echo -e "\x1B[1;31mUnable to locate podman, please install it firstly.\x1B[0m" && \
            exit 1
    fi
}

function containsElement(){
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

function get_baw_mode(){
    if [ -f "$OPERATOR_FILE" ]; then
        content_start="$(grep -n "env:" ${OPERATOR_FILE} | head -n 1 | cut -d: -f1)"
        content_stop="$(tail -n +$content_start < ${OPERATOR_FILE} | grep -n "name: delivery_type" | head -n1 | cut -d: -f1)"

        if [ -z $content_stop ]; then
            return 1
        else
            content_stop=$(( $content_stop + $content_start - 1))
            baw_mode="$(tail -n +$content_stop < ${OPERATOR_FILE} | grep -n "value: " | head -n1 | cut -d: -f3)"
            baw_mode=`echo $baw_mode | sed "s/\"//g"`
            # echo -e "$baw_mode"
            if [[ "${baw_mode}" == "baw" ]]; then
                return 0
            else
                return 1
            fi
        fi
    else
        echo -e "\x1B[1;31m\"${OPERATOR_FILE}\" FILE NOT FOUND\x1B[0m"
        exit 0
    fi
}

function select_platform(){
    printf "\n"
    echo -e "\x1B[1mSelect the cloud platform to deploy: \x1B[0m"
    COLUMNS=12
    options=("Openshift Container Platform (OCP) - Private Cloud" "Other ( Certified Kubernetes Cloud Platform / CNCF)")

    if [ -z "$existing_platform_type" ]; then
        PS3='Enter a valid option [1 to 2]: '
        select opt in "${options[@]}"
        do
            case $opt in
                "RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud")
                    PLATFORM_SELECTED="ROKS"
                    break
                    ;;
                "Openshift Container Platform (OCP) - Private Cloud")
                    PLATFORM_SELECTED="OCP"
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
            options_var=("OCP" "other")
            for i in ${!options_var[@]}; do 
                if [[ "${options_var[i]}" == "$existing_platform_type" ]]; then 
                    printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Selected)"
                else 
                    printf "%1d) %s\n" $((i+1)) "${options[i]}"
                fi           
            done
            echo -e "\x1B[1;31mExisting platform type found in CR: \"$existing_platform_type\"\x1B[0m"
            echo -e "\x1B[1;31mDo not need to select again.\n\x1B[0m"
            read -rsn1 -p"Press any key to continue ...";echo   
    fi

    if [[ "$PLATFORM_SELECTED" == "OCP" ]]; then
        CLI_CMD=oc
    elif [[ "$PLATFORM_SELECTED" == "other" ]]
    then
        CLI_CMD=kubectl
    fi
}

function check_ocp_version(){
    if [[ ${PLATFORM_SELECTED} == "OCP" ]];then
        k8s_version=`${CLI_CMD} version | grep v[1-9]\. | tail -n1`
        while true; do
            case "$k8s_version" in
            *v1.17.*)
                OCP_VERSION="4.4"    
                break
                ;;
            *v1.16.*)
                OCP_VERSION="4.3"    
                break
                ;;
            *v1.14.*) 
                OCP_VERSION="4.2"     
                break
                ;;
            *v1.13.*) 
                OCP_VERSION="4.1"
                break
                ;;
            *v1.11.*) 
                OCP_VERSION="3.11"
                break
                ;;
            *)
                printf "Do not get the version of Openshift Container Platform (OCP), existing ..."
                exit 1
                ;;               
            esac
        done
    fi
}

function select_baw_iaws_installation(){
    
    INSTALL_BAW_IAWS=""
    
    get_baw_mode
    retVal_baw=$?
    
    while true; do
        if [[ $retVal_baw -eq 0 ]]; then
      printf "\x1B[1mDo you plan to install Business Automation Workflow?\n\x1B[0m"
    fi
        if [[ $retVal_baw -eq 1 ]]; then
      printf "\n"
      printf "\x1B[1mDo you plan to install Business Automation Workflow and/or Automation Workstream Services?\n\x1B[0m"
    fi
        printf "Enter a valid option [Yes, No]: "
        read -rp "" ans

        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES") 
            INSTALL_BAW_IAWS="Yes"    
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            INSTALL_BAW_IAWS="No"    
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            INSTALL_BAW_IAWS=""
            ;;
        esac
    done
}

function select_pattern(){
# This function support mutiple checkbox, if do not select anything, it will return None

    PATTERNS_SELECTED=""
    choices_pattern=()
    pattern_arr=()
    if [[ "${PLATFORM_SELECTED}" == "OCP" && "${DEPLOYMENT_TYPE}" == "enterprise" ]]; 
    then
        options=("FileNet Content Manager" "Automation Content Analyzer" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Automation Digital Worker")
        options_cr_val=("content" "contentanalyzer" "decisions" "decisions_ads" "application" "digitalworker")
        foundation_0=("BAN" "RR")                 # Foundation for FileNet Content Manager
        foundation_1=("BAN" "RR" "BAS" "UMS")     # Foundation for Automation Content Analyzer  
        foundation_2=("BAN" "RR")                # Foundation for Operational Decision Manager
        foundation_3=("BAN" "RR" "UMS")     # Foundation for Automation Decision Services
        # foundation_4=("BAN" "RR" "UMS")           # Foundation for Business Automation Workflow (Demo)
        foundation_4=("BAN" "RR" "UMS")     # Foundation for Business Automation Applications (full)
        foundation_5=("BAN" "RR" "BAS" "UMS")     # Foundation for Automation Digital Worker  
        # foundation_7=("BAN" "RR" "UMS")           # # Foundation for Business Automation Applications (production)
    else
        options=("FileNet Content Manager" "Automation Content Analyzer" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Automation Digital Worker")
        options_cr_val=("content" "contentanalyzer" "decisions" "decisions_ads" "application" "digitalworker")
        foundation_0=("BAN" "RR")                 # Foundation for FileNet Content Manager
        foundation_1=("BAN" "RR" "BAS" "UMS")     # Foundation for Automation Content Analyzer  
        foundation_2=("BAN" "RR")                 # Foundation for Operational Decision Manager
        foundation_3=("BAN" "RR" "UMS")     # Foundation for Automation Decision Services
        # foundation_4=("BAN" "RR" "UMS")           # Foundation for Business Automation Workflow&Worksteams (Demo)
        foundation_4=("BAN" "RR" "UMS")     # Foundation for Business Automation Applications (full)
        foundation_5=("BAN" "RR" "BAS" "UMS")     # Foundation for Automation Digital Worker  
        # foundation_7=("BAN" "RR" "UMS")           # # Foundation for Business Automation Applications (production)
    fi


    tips1="\x1B[1;31mTips\x1B[0m:\x1B[1mPress [ENTER] to accept the default (None of the patterns is selected)\x1B[0m"
    tips2="\x1B[1;31mTips\x1B[0m:\x1B[1mPress [ENTER] when you are done\x1B[0m"
    pattern_tips="\x1B[1mInfo: Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Automation foundation platform. \n\nTips:  After you make your first selection you will be able to make additional selections since you can combine multiple selections. \n\n\x1B[0m"
    indexof() { 
        i=-1
        for ((j=0;j<${#options_cr_val[@]};j++)); 
        do [ "${options_cr_val[$j]}" = "$1" ] && { i=$j; break; } 
        done 
        echo $i 
    }
    menu() {
        clear
        echo -e "\x1B[1mSelect the Cloud Pak for Automation capability to install: \x1B[0m"
        for i in ${!options[@]}; do
            
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
        done
        if [[ "$msg" ]]; then echo "$msg"; fi
        printf "\n"

        echo -e "${pattern_tips}"        
        # Show different tips according components select or unselect
        containsElement "(Selected)" "${choices_pattern[@]}"
        retVal=$?
        if [ $retVal -ne 0 ]; then 
            echo -e "${tips1}" 
        else 
            echo -e "${tips2}" 
        fi

    }
    
    prompt="Enter a valid option [1 to ${#options[@]}]: "
    while menu && read -rp "$prompt" num && [[ "$num" ]]; do
        [[ "$num" != *[![:digit:]]* ]] &&
        (( num > 0 && num <= ${#options[@]} )) ||
        { msg="Invalid option: $num"; continue; }
        ((num--)); 
        containsElement "${options_cr_val[num]}" "${EXISTING_PATTERN_ARR[@]}"
        retVal=$?
        if [ $retVal -ne 0 ]; then 
           [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(Selected)"
        else 
           [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
        fi  
    done

    # Generate list of the pattern which will be installed or To Be Uninstalled
    for i in ${!options[@]}; do
        array_varname=foundation_$i[@]
        containsElement "${options_cr_val[i]}" "${EXISTING_PATTERN_ARR[@]}"
        retVal=$?
        if [ $retVal -ne 0 ]; then 
            [[ "${choices_pattern[i]}" ]] && { pattern_arr=( "${pattern_arr[@]}" "${options[i]}" ); pattern_cr_arr=( "${pattern_cr_arr[@]}" "${options_cr_val[i]}" ); msg=""; }
            # if [[  "${options[i]}" == "Business Automation Application"  && "${DEPLOYMENT_TYPE}" == "enterprise" ]] ; then
            #     [[ "${choices_pattern[i]}" ]] && { foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_7[@]}" ); }
            # else
            [[ "${choices_pattern[i]}" ]] && { foundation_component_arr=( "${foundation_component_arr[@]}" "${!array_varname}" ); }
            # fi
        else 
            if [[ "${choices_pattern[i]}" == "(To Be Uninstalled)" ]]; then
                pos=`indexof "${pattern_cr_arr[i]}"`
                if [[ "$pos" != "-1" ]]; then 
                { pattern_cr_arr=(${pattern_cr_arr[@]:0:$pos} ${pattern_cr_arr[@]:$(($pos + 1))}); pattern_arr=(${pattern_arr[@]:0:$pos} ${pattern_arr[@]:$(($pos + 1))}); }
                
                fi
            else
                { pattern_arr=( "${pattern_arr[@]}" "${options[i]}" ); pattern_cr_arr=( "${pattern_cr_arr[@]}" "${options_cr_val[i]}" ); msg=""; }
                # if [[  "${options[i]}" == "Business Automation Application"  && "${DEPLOYMENT_TYPE}" == "enterprise" ]] ; then
                #     { foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_7[@]}" ); }
                # else
                { foundation_component_arr=( "${foundation_component_arr[@]}" "${!array_varname}" ); }
                # fi
            fi
        fi
    done
    # echo -e "$msg"

    if [ "${#pattern_arr[@]}" -eq "0" ]; then
        PATTERNS_SELECTED="None"
        printf "\x1B[1;31mPlease select one pattern at least, exiting... \n\x1B[0m"
        exit 1
    else
        PATTERNS_SELECTED=$( IFS=$','; echo "${pattern_arr[*]}" )
        PATTERNS_CR_SELECTED=$( IFS=$','; echo "${pattern_cr_arr[*]}" )

    fi

    FOUNDATION_CR_SELECTED=($(echo "${foundation_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    # FOUNDATION_CR_SELECTED_LOWCASE=( "${FOUNDATION_CR_SELECTED[@],,}" )

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

        tips1="\x1B[1;31mTips\x1B[0m:\x1B[1m Press [ENTER] to accept the default (None of the components is selected)\x1B[0m"
        tips2="\x1B[1;31mTips\x1B[0m:\x1B[1m Press [ENTER] when you are done\x1B[0m"
        ads_tips="\x1B[1mTips:\x1B[0m Decision Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present. \n\nDecision Runtime is typically recommended if you are deploying a test or production environment. \n\nYou should choose at least one these features to have a minimum environment configuration.\n"
        if [[ $DEPLOYMENT_TYPE == "demo" ]];then
            decision_tips="\x1B[1mTips:\x1B[0m Decision Center, Rule Execution Server and Decision Runner will be installed by default.\n"
        else
            decision_tips="\x1B[1mTips:\x1B[0m Decision Center is typically required for development and testing environments. \nRule Execution Server is typically required for testing and production environments and for using Business Automation Insights. \nYou should choose at least one these 2 features to have a minimum environment configuration. \n"
        fi
        application_tips="\x1B[1mTips:\x1B[0m Application Designer is typically required if you are deploying a development or test environment.\nThis feature will automatically install Business Automation Studio, if not already present. \n\nApplication Engine is automatically installed in the environment.  \n\nMake your selection or press enter to proceed. \n"

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
                    if [[ "${item_pattern}" == "FileNet Content Manager" || ( "${item_pattern}" == "Operational Decision Manager" && "${DEPLOYMENT_TYPE}" == "enterprise" ) ]];then
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
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${optional_components_list[i]}"  "(Installed)"
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
                echo -e "${decision_tips}" 
            fi
            if [[ "${item_pattern}" == "Business Automation Application" ]]; then 
                echo -e "${application_tips}" 
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
                        
        }
        
        prompt="Enter a valid option [1 to ${#optional_components_list[@]}]: "
        while menu && read -rp "$prompt" num && [[ "$num" ]]; do
            [[ "$num" != *[![:digit:]]* ]] &&
            (( num > 0 && num <= ${#optional_components_list[@]} )) ||
            { msg="Invalid option: $num"; continue; }
            ((num--)); 

            containsElement "${optional_components_cr_list[num]}" "${EXISTING_OPT_COMPONENT_ARR[@]}"
            retVal=$?
            if [ $retVal -ne 0 ]; then 
                [[ "${choices_component[num]}" ]] && choices_component[num]="" || choices_component[num]="(Selected)"
                if [[ "${item_pattern}" == "FileNet Content Manager" || ( "${item_pattern}" == "Operational Decision Manager" && "${DEPLOYMENT_TYPE}" == "enterprise" ) ]];then
                    if [[ "${optional_components_cr_list[num]}" == "bai" && ${choices_component[num]} == "(Selected)" ]];then
                        choices_component[num-1]="(Selected)"
                    fi
                    if [[ "${optional_components_cr_list[num]}" == "ums" && ${choices_component[num+1]} == "(Selected)" ]];then
                        choices_component[num]="(Selected)"
                    fi
                fi
            else
                containsElement "ums" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                ums_retVal=$?
                containsElement "bai" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                bai_retVal=$?
                if [[ "${optional_components_cr_list[num]}" == "bai" && $ums_retVal -eq 0 ]];then
                    ums_check_num=num-1
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
                elif [[ "${optional_components_list[i]}" == "Application Designer" ]]
                then
                    [[ "${choices_component[i]}" ]] && { optional_component_arr=( "${optional_component_arr[@]}" "ApplicationDesigner" ); msg=""; }
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
                    elif [[ "${optional_components_list[i]}" == "Application Designer" ]]
                    then
                        optional_component_arr=( "${optional_component_arr[@]}" "ApplicationDesigner" )
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
                    if [[ $DEPLOYMENT_TYPE == "demo" ]];then
                        optional_components_list=("Content Search Services" "Content Management Interoperability Services" "User Management Service" "Business Automation Insights")
                        optional_components_cr_list=("css" "cmis" "ums" "bai")
                    elif [[ $DEPLOYMENT_TYPE == "enterprise" ]]
                    then
                        optional_components_list=("Content Search Services" "Content Management Interoperability Services" "External Share" "User Management Service" "Business Automation Insights")
                        optional_components_cr_list=("css" "cmis" "es" "ums" "bai")                    
                    fi
                    show_optional_components
                    containsElement "bai" "${optional_component_cr_arr[@]}"
                    retVal=$?
                    if [[ $retVal -eq 0 ]]; then
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ums" )
                        optional_component_arr=( "${optional_component_arr[@]}" "UserManagementService" )
                    fi
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "Automation Content Analyzer")
                    # echo "Without optional components for $item_pattern pattern."
                    optional_components_list=()
                    optional_components_cr_list=()
                    break
                    ;;
                "Operational Decision Manager")
                    # echo "select $item_pattern pattern optional components"
                    if [[ "${DEPLOYMENT_TYPE}" == "demo" ]]; then
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "decisionCenter" )
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "decisionServerRuntime" )
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "decisionRunner" )
                        optional_components_list=("Business Automation Insights")
                        optional_components_cr_list=("bai")
                    else
                        optional_components_list=("Decision Center" "Rule Execution Server" "Decision Runner" "User Management Service" "Business Automation Insights")
                        optional_components_cr_list=("decisionCenter" "decisionServerRuntime" "decisionRunner" "ums" "bai")
                    fi
                        show_optional_components
                        containsElement "bai" "${optional_component_cr_arr[@]}"
                        retVal=$?
                        if [[ $retVal -eq 0 ]]; then
                            optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ums" )
                            optional_component_arr=( "${optional_component_arr[@]}" "UserManagementService" )
                        fi
                        optional_components_list=()
                        optional_components_cr_list=()
                    break
                    ;;
                "Automation Decision Services")
                    # echo "select $item_pattern pattern optional components"
                    if [[ "${DEPLOYMENT_TYPE}" == "demo" ]]; then
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ads_designer" )
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "ads_runtime" )
                        optional_components_list=() 
                        optional_components_cr_list=()  
                    else
                        optional_components_list=("Decision Designer" "Decision Runtime")
                        optional_components_cr_list=("ads_designer" "ads_runtime")
                        show_optional_components
                        optional_components_list=() 
                        optional_components_cr_list=()   
                    fi
                    break
                    ;;
                "Business Automation Workflow"|"Business Automation Workflow and Automation Workstream Services")
                    # echo "Without optional components for $item_pattern pattern."
                    if [[ $DEPLOYMENT_TYPE == "demo" ]]; then
                        optional_components_list=("Business Automation Insights")
                        optional_components_cr_list=("bai")
                        show_optional_components
                    fi
                    if [[ $DEPLOYMENT_TYPE == "enterprise" ]]; then
                        optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "bai" )
                        optional_component_arr=( "${optional_component_arr[@]}" "BusinessAutomationInsights" )
                    fi
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    optional_components_list=() 
                    optional_components_cr_list=()
                    break
                    ;;
                "Automation Workstream Services")
                    # echo "Without optional components for $item_pattern pattern."
                    optional_component_cr_arr=( "${optional_component_cr_arr[@]}" "cmis" )
                    optional_components_list=() 
                    optional_components_cr_list=()
                    break
                    ;;
                "Business Automation Application")
                    if [[ $DEPLOYMENT_TYPE == "enterprise" ]]; then
                        # echo "select $item_pattern pattern optional components"
                        optional_components_list=("Application Designer")
                        optional_components_cr_list=("app_designer")
                        show_optional_components
                        optional_components_list=()
                        optional_components_cr_list=()
                    else
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
            esac
        done
    done

    OPT_COMPONENTS_CR_SELECTED=($(echo "${optional_component_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    OPTIONAL_COMPONENT_DELETE_LIST=($(echo "${OPT_COMPONENTS_CR_SELECTED[@]}" "${OPTIONAL_COMPONENT_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))
    KEEP_COMPOMENTS=($(echo ${FOUNDATION_CR_SELECTED_LOWCASE[@]} ${OPTIONAL_COMPONENT_DELETE_LIST[@]} | tr ' ' '\n' | sort | uniq -d | uniq))
    OPT_COMPONENTS_SELECTED=($(echo "${optional_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
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
    
    elif [[ $OCP_VERSION == "4.1" || $OCP_VERSION == "4.2" || $OCP_VERSION == "4.3" || $OCP_VERSION == "4.4" ]]
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
    printf "\x1B[1;31mFollow the instructions on how to get your Entitlement Registry key: \n\x1B[0m"
    printf "\x1B[1;31mhttps://github.com/icp4a/cert-kubernetes/blob/20.0.2/platform/ocp/install.md\n\x1B[0m"
    printf "\n"
    printf "\x1B[1mDo you have a Cloud Pak for Automation Entitlement Registry key (Yes/No, default: No): \x1B[0m"
    while true; do
        read -rp "" ans

        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            use_entitlement="yes"
            printf "\n"
            printf "\x1B[1mEnter your Entitlement Registry key: \x1B[0m"

            while [[ $entitlement_key == '' ]]
            do
                read -rp "" entitlement_key
                if [ -z "$entitlement_key" ]; then
                    echo -e "\x1B[1;31mEnter a valid Entitlement Registry key\x1B[0m"
                else
                    if  [[ $entitlement_key == iamapikey:* ]] ;
                    then
                        DOCKER_REG_USER="iamapikey"
                        DOCKER_REG_KEY="${entitlement_key#*:}"
                    else
                        DOCKER_REG_USER="cp"
                        DOCKER_REG_KEY=$entitlement_key

                    fi
                    entitlement_verify_passed=""
                    while [[ $entitlement_verify_passed == '' ]]
                    do
                        printf "\x1B[1mVerifying the Entitlement Registry key...\n\x1B[0m"
                        if [[ $OCP_VERSION == "3.11" || "$machine" == "Mac" || $PLATFORM_SELECTED == "other" ]];then
                            if docker login -u "$DOCKER_REG_USER" -p "$DOCKER_REG_KEY" "$DOCKER_REG_SERVER"; then
                                printf 'Entitlement Registry key is valid.\n'
                                entitlement_verify_passed="passed"
                            else
                                printf '\x1B[1;31mThe Entitlement Registry key failed. Enter a valid Entitlement Registry key.\n\x1B[0m'
                                entitlement_key=''
                                entitlement_verify_passed="failed" 
                            fi
                        elif [[ $PLATFORM_SELECTED == "other" || $OCP_VERSION == "4.1" || $OCP_VERSION == "4.2" || $OCP_VERSION == "4.3" || $OCP_VERSION == "4.4" ]]
                        then
                            if podman login -u "$DOCKER_REG_USER" -p "$DOCKER_REG_KEY" "$DOCKER_REG_SERVER" --tls-verify=false; then
                                printf 'Entitlement Registry key is valid.\n'
                                entitlement_verify_passed="passed"
                            else
                                printf '\x1B[1;31mThe Entitlement Registry key failed. Enter a valid Entitlement Registry key.\n\x1B[0m'
                                entitlement_key=''
                                entitlement_verify_passed="failed" 
                            fi
                        fi                              
                    done
                fi
            done
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            use_entitlement="no"
            DOCKER_REG_KEY="None"
            break
            ;;
        *)
            use_entitlement="no"
            DOCKER_REG_KEY="None"
            break
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
    if [[ "${REGISTRY_TYPE}" == "internal" && ("${OCP_VERSION}" == "4.1" || "${OCP_VERSION}" == "4.2"|| "${OCP_VERSION}" == "4.3" || "${OCP_VERSION}" == "4.4") ]];then
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
    elif [[ "${REGISTRY_TYPE}" == "internal" && ("${OCP_VERSION}" == "4.1" || "${OCP_VERSION}" == "4.2"|| "${OCP_VERSION}" == "4.3" || "${OCP_VERSION}" == "4.4") ]]
    then
        printf "\n"
        printf "\x1B[1mEnter the local image registry (e.g., image-registry.openshift-image-registry.svc:5000/<project>)\n\x1B[0m"
        printf "\x1B[1mThis is required to pull container images and Kubernetes secret creation: \x1B[0m"
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


function get_infra_name(){

    # For Infrastructure Node
    printf "\n"
    printf "\x1B[1mIn order for the deployment to create routes for the Cloud Pak services,\n\x1B[0m"
    printf "\x1B[1mYou can get the host name by running the following command: \n\x1B[0m"
    if [[ $OCP_VERSION == "3.11" ]];then
        printf "\x1B[1;31moc get nodes --selector node-role.kubernetes.io/infra=true -o custom-columns=\":metadata.name\"\n\x1B[0m"
    elif [[ $OCP_VERSION == "4.1" || $OCP_VERSION == "4.2" || $OCP_VERSION == "4.3" || $OCP_VERSION == "4.4" ]]
    then
        printf "\x1B[1;31moc get route console -n openshift-console -o yaml|grep routerCanonicalHostname\n\x1B[0m"
    fi
    printf "\x1B[1mInput the host name: \x1B[0m"
      
    infra_name=""
    while [[ $infra_name == "" ]]
    do
       read -rp  "" infra_name
       if [ -z "$infra_name" ]; then
       echo -e "\x1B[1;31mEnter the host name of your Infrastructure Node.\x1B[0m"
       fi
    done
    export INFRA_NAME=${infra_name}

}

function get_storage_class_name(){

    # For dynamic storage classname
    storage_class_name=""
    sc_slow_file_storage_classname=""
    sc_medium_file_storage_classname=""
    sc_fast_file_storage_classname=""
    printf "\n"
    if [[ $DEPLOYMENT_TYPE == "demo" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other")]] ;
    then
        printf "\x1B[1mTo provision the persistent volumes and volume claims, enter the dynamic storage classname: \x1B[0m"
        
        while [[ $storage_class_name == "" ]]
        do
            read -rp "" storage_class_name
            if [ -z "$storage_class_name" ]; then
               echo -e "\x1B[1;31mEnter a valid dynamic storage classname\x1B[0m"
            fi
        done
    elif [[ ($DEPLOYMENT_TYPE == "enterprise" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other")) || $PLATFORM_SELECTED == "ROKS" ]]
    then
        printf "\x1B[1mTo provision the persistent volumes and volume claims\n\x1B[0m"

        while [[ $sc_slow_file_storage_classname == "" ]] # While get slow storage clase name
        do
            printf "\x1B[1mplease enter the dynamic storage classname for slow storage: \x1B[0m"
            read -rp "" sc_slow_file_storage_classname
            if [ -z "$sc_slow_file_storage_classname" ]; then
               echo -e "\x1B[1;31mEnter a valid dynamic storage classname\x1B[0m"
            fi
        done

        while [[ $sc_medium_file_storage_classname == "" ]] # While get medium storage clase name
        do
            printf "\x1B[1mplease enter the dynamic storage classname for medium storage: \x1B[0m"
            read -rp "" sc_medium_file_storage_classname
            if [ -z "$sc_medium_file_storage_classname" ]; then
               echo -e "\x1B[1;31mEnter a valid dynamic storage classname\x1B[0m"
            fi
        done

        while [[ $sc_fast_file_storage_classname == "" ]] # While get fast storage clase name
        do
            printf "\x1B[1mplease enter the dynamic storage classname for fast storage: \x1B[0m"
            read -rp "" sc_fast_file_storage_classname
            if [ -z "$sc_fast_file_storage_classname" ]; then
               echo -e "\x1B[1;31mEnter a valid dynamic storage classname\x1B[0m"
            fi
        done
    fi
    STORAGE_CLASS_NAME=${storage_class_name}
    SLOW_STORAGE_CLASS_NAME=${sc_slow_file_storage_classname}
    MEDIUM_STORAGE_CLASS_NAME=${sc_medium_file_storage_classname}
    FAST_STORAGE_CLASS_NAME=${sc_fast_file_storage_classname}
}

function allocate_operator_pvc(){
    # For dynamic storage classname
    # For dynamic storage classname
    printf "\n"
    echo -e "\x1B[1mApplying the persistent volumes for the Cloud Pak operator by using the storage classname: ${STORAGE_CLASS_NAME}...\x1B[0m"

    printf "\n"
    if [[ $DEPLOYMENT_TYPE == "demo" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other") ]] ;
    then
        sed "s/<StorageClassName>/$STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_BAK} > ${OPERATOR_PVC_FILE_TMP} # &> /dev/null
    elif [[ ($DEPLOYMENT_TYPE == "enterprise" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other")) || $PLATFORM_SELECTED == "ROKS" ]];
    then
        sed "s/<StorageClassName>/$SLOW_STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_BAK} > ${OPERATOR_PVC_FILE_TMP} # &> /dev/null
    fi

    cp -rf ${OPERATOR_PVC_FILE_TMP} ${OPERATOR_PVC_FILE_BAK}
    # Create Operator Persistent Volume.
    CREATE_PVC_CMD="${CLI_CMD} apply -f ${OPERATOR_PVC_FILE_TMP}"
    if $CREATE_PVC_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi
   # Check Operator Persistent Volume status every 5 seconds (max 10 minutes) until allocate.
    ATTEMPTS=0
    TIMEOUT=60
    printf "\n"
    echo -e "\x1B[1mWaiting for the persistent volumes to be ready...\x1B[0m"
    until ${CLI_CMD} get pvc | grep operator-shared-pvc | grep -q -m 1 "Bound" || [ $ATTEMPTS -eq $TIMEOUT ]; do
        ATTEMPTS=$((ATTEMPTS + 1))
        echo -e "......"
        sleep 10
        if [ $ATTEMPTS -eq $TIMEOUT ] ; then
            echo -e "\x1B[1;31mFailed to allocate the persistent volumes!\x1B[0m"
            echo -e "\x1B[1;31mRun the following command to check the claim '${CLI_CMD} describe pvc operator-shared-pvc'\x1B[0m"
            exit 1
        fi
    done
    if [ $ATTEMPTS -lt $TIMEOUT ] ; then
            echo -e "\x1B[1mDone\x1B[0m"
    fi
}

function create_secret_local_registry(){
    echo -e "\x1B[1mCreating the secret based on the local docker registry information...\x1B[0m"
    # Create docker-registry secret for local Registry Key
    # echo -e "Create docker-registry secret for Local Registry...\n"
    ${CLI_CMD} delete secret "$DOCKER_RES_SECRET_NAME" >/dev/null 2>&1
    if [[ $LOCAL_REGISTRY_SERVER == docker-registry* || $LOCAL_REGISTRY_SERVER == image-registry.openshift-image-registry* ]] ;
    then
        CREATE_SECRET_CMD="${CLI_CMD} create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$LOCAL_REGISTRY_SERVER --docker-username=$LOCAL_REGISTRY_USER --docker-password=$(${CLI_CMD} whoami -t) --docker-email=ecmtest@ibm.com"
    else
        CREATE_SECRET_CMD="${CLI_CMD} create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$LOCAL_REGISTRY_SERVER --docker-username=$LOCAL_REGISTRY_USER --docker-password=$LOCAL_REGISTRY_PWD --docker-email=ecmtest@ibm.com"    
    fi
    if $CREATE_SECRET_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi   
}

function verify_local_registry_password(){
    # require to preload image for CP4A image and ldap/db2 image for demo
    printf "\n"
    while true; do
        printf "\x1B[1mHave you pushed the images to the local registry using 'loadimages.sh' (CP4A images)\n\x1B[0m"   
        printf "\x1B[1mand 'loadPrereqImages.sh' (Db2 and OpenLDAP for demo) scripts (Yes/No)? \x1B[0m"    
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

    # Select whice type of image registry to use.
    if [[ "${PLATFORM_SELECTED}" == "OCP" ]]; then
        printf "\n"
        echo -e "\x1B[1mSelect the type of image registry to use:: \x1B[0m"
        COLUMNS=12
        options=("Openshift Container Platform (OCP) - Internal image registry" "Other ( External image registry: abc.xyz.com )")

        PS3='Enter a valid option [1 to 2]: '
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

    while [[ $verify_passed == "" && $PRE_LOADED_IMAGE == "Yes" ]]
    do
        get_local_registry_server
        get_local_registry_user
        get_local_registry_password
        
        if [[ $LOCAL_REGISTRY_SERVER == docker-registry* || $LOCAL_REGISTRY_SERVER == image-registry* || $LOCAL_REGISTRY_SERVER == default-route-openshift-image-registry* ]] ;
        then
            if [[ $OCP_VERSION == "3.11" || "$machine" == "Mac" ]];then
                if docker login -u "$LOCAL_REGISTRY_USER" -p $(${CLI_CMD} whoami -t) "$LOCAL_REGISTRY_SERVER"; then
                    printf 'Verifying Local Registry passed...\n'
                    verify_passed="passed"
                else
                    printf '\x1B[1;31mLogin failed...\n\x1B[0m'
                    verify_passed=""
                    local_registry_user=""
                    local_registry_server=""
                    echo -e "\x1B[1;31mCheck the local docker registry information and try again.\x1B[0m"
                fi
            elif [[ $OCP_VERSION == "4.1" || $OCP_VERSION == "4.2" || $OCP_VERSION == "4.3" || $OCP_VERSION == "4.4" ]]
            then
                which podman &>/dev/null
                if [[ $? -eq 0 ]];then
                    if podman login "$local_public_registry_server" -u "$LOCAL_REGISTRY_USER" -p $(${CLI_CMD} whoami -t) --tls-verify=false; then
                        printf 'Verifying Local Registry passed...\n'
                        verify_passed="passed"
                    else
                        printf '\x1B[1;31mLogin failed...\n\x1B[0m'
                        verify_passed=""
                        local_registry_user=""
                        local_registry_server=""
                        local_public_registry_server=""
                        echo -e "\x1B[1;31mCheck the local docker registry information and try again.\x1B[0m"
                    fi
                else
                     if docker login "$local_public_registry_server" -u "$LOCAL_REGISTRY_USER" -p $(${CLI_CMD} whoami -t); then
                        printf 'Verifying Local Registry passed...\n'
                        verify_passed="passed"
                    else
                        printf '\x1B[1;31mLogin failed...\n\x1B[0m'
                        verify_passed=""
                        local_registry_user=""
                        local_registry_server=""
                        local_public_registry_server=""
                        echo -e "\x1B[1;31mCheck the local docker registry information and try again.\x1B[0m"
                    fi
                fi
            fi
        else
            which podman &>/dev/null
            if [[ $? -eq 0 ]];then
                if podman login -u "$LOCAL_REGISTRY_USER" -p "$LOCAL_REGISTRY_PWD"  "$LOCAL_REGISTRY_SERVER" --tls-verify=false; then
                    printf 'Verifying the information for the local docker registry...\n'
                    verify_passed="passed"
                else
                    printf '\x1B[1;31mLogin failed...\n\x1B[0m'
                    verify_passed=""
                    local_registry_user=""
                    local_registry_server=""
                    echo -e "\x1B[1;31mCheck the local docker registry information and try again.\x1B[0m"
                fi
            else
                if docker login -u "$LOCAL_REGISTRY_USER" -p "$LOCAL_REGISTRY_PWD"  "$LOCAL_REGISTRY_SERVER"; then
                    printf 'Verifying the information for the local docker registry...\n'
                    verify_passed="passed"
                else
                    printf '\x1B[1;31mLogin failed...\n\x1B[0m'
                    verify_passed=""
                    local_registry_user=""
                    local_registry_server=""
                    echo -e "\x1B[1;31mCheck the local docker registry information and try again.\x1B[0m"
                fi 
            fi           
        fi      
     done

}
function select_installation_type(){
    COLUMNS=12
    echo -e "\x1B[1mIs this a new install or an existing install?\x1B[0m"
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
                get_existing_pattern_name
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done    
}

function select_deployment_type(){
    printf "\n"
    echo -e "\x1B[1mWhat type of deployment is being performed?\x1B[0m"
    if  [[ $PLATFORM_SELECTED == "ROKS" ]];
    then
        DEPLOYMENT_TYPE="demo"
        printf "\n"

        echo -e "\x1B[1;31mOnly \"Demo\" deployment is currently supported on RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud.\n\x1B[0m"
        read -rsn1 -p"Press any key to continue ...";echo
        # options=("Demo")
        # PS3='Enter a valid option [1 to 1]: '
        # select opt in "${options[@]}"
        # do
        #     case $opt in
        #         "Demo")
        #             DEPLOYMENT_TYPE="demo"
        #             break
        #             ;;
        #         *) echo "invalid option $REPLY";;
        #     esac
        # done    
    else 
        COLUMNS=12
        options=("Demo" "Enterprise")
        if [ -z "$existing_deployment_type" ]; then
            PS3='Enter a valid option [1 to 2]: '
            select opt in "${options[@]}"
            do
                case $opt in
                    "Demo")
                        DEPLOYMENT_TYPE="demo"
                        break
                        ;;
                    "Enterprise")
                        DEPLOYMENT_TYPE="enterprise"
                        break
                        ;;
                    *) echo "invalid option $REPLY";;
                esac
            done           
        else
            options_var=("demo" "enterprise")
            for i in ${!options_var[@]}; do 
                if [[ "${options_var[i]}" == "$existing_deployment_type" ]]; then 
                    printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Selected)"
                else 
                    printf "%1d) %s\n" $((i+1)) "${options[i]}"
                fi           
            done
            echo -e "\x1B[1;31mExisting deployment type found in CR: \"$existing_deployment_type\"\x1B[0m"
            echo -e "\x1B[1;31mDo not need to select again.\n\x1B[0m"
            read -rsn1 -p"Press any key to continue ...";echo            
        fi
    fi     
}

function select_ldap_type(){
    COLUMNS=12
    echo -e "\x1B[1mWhat is the LDAP type used for this deployment? \x1B[0m"
    options=("Microsoft Active Directory" "Tivoli Directory Server / Security Directory Server")
    PS3='Enter a valid option [1 to 2]: '
    select opt in "${options[@]}"
    do
        case $opt in
            "Microsoft Active Directory")
                LDAP_TYPE="AD"
                break
                ;;
            Tivoli*)
                LDAP_TYPE="TDS"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

}
function set_ldap_type_foundation(){
    if [[ $DEPLOYMENT_TYPE == "enterprise" ]] ;
    then
        cp -r ${FOUNDATION_PATTERN_FILE_BAK} ${FOUNDATION_PATTERN_FILE_TMP}
        
        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${FOUNDATION_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "tds:" ${FOUNDATION_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${FOUNDATION_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${FOUNDATION_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        cp -r ${FOUNDATION_PATTERN_FILE_TMP} ${FOUNDATION_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_content_pattern(){
    if [[ $DEPLOYMENT_TYPE == "enterprise" ]] ;
    then    
        cp -r ${CONTENT_PATTERN_FILE_BAK} ${CONTENT_PATTERN_FILE_TMP}
        
        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${CONTENT_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "tds:" ${CONTENT_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        cp -r ${CONTENT_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_workstreams_pattern(){
    if [[ $DEPLOYMENT_TYPE == "enterprise" ]] ;
    then    
        cp -r ${WORKSTREAMS_PATTERN_FILE_BAK} ${WORKSTREAMS_PATTERN_FILE_TMP} 
        
        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${WORKSTREAMS_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "tds:" ${WORKSTREAMS_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${WORKSTREAMS_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${WORKSTREAMS_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        cp -r ${WORKSTREAMS_PATTERN_FILE_TMP} ${WORKSTREAMS_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_workflow_pattern(){
    if [[ $DEPLOYMENT_TYPE == "enterprise" ]] ;
    then    
        cp -r ${WORKFLOW_PATTERN_FILE_BAK} ${WORKFLOW_PATTERN_FILE_TMP} 
        
        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${WORKFLOW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "tds:" ${WORKFLOW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${WORKFLOW_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${WORKFLOW_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        cp -r ${WORKFLOW_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
    fi
}

function set_ldap_type_ww_pattern(){ 
    if [[ $DEPLOYMENT_TYPE == "enterprise" ]] ;
    then    
        cp -r ${WW_PATTERN_FILE_BAK} ${WW_PATTERN_FILE_TMP} 
        
        if [[ "$LDAP_TYPE" == "AD" ]]; then
            content_start="$(grep -n "ad:" ${WW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        else
            content_start="$(grep -n "tds:" ${WW_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        fi
        content_stop="$(tail -n +$content_start < ${WW_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${WW_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq' >/dev/null 2>&1

        cp -r ${WW_PATTERN_FILE_TMP} ${WW_PATTERN_FILE_BAK}
    fi
}

function set_external_share_content_pattern(){
    if [[ $DEPLOYMENT_TYPE == "enterprise" ]] ;
    then
        containsElement "es" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            cp -r ${CONTENT_PATTERN_FILE_BAK} ${CONTENT_PATTERN_FILE_TMP}
            # un-comment ext_ldap_configuration
            content_start="$(grep -n "ext_ldap_configuration:" ${CONTENT_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
            content_stop="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "lc_ldap_group_member_id_map:" | head -n1 | cut -d: -f1)"
            content_stop=$(( $content_stop + $content_start - 1))
            vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/  # /  ' -c ':wq' >/dev/null 2>&1

            # un-comment LDAP
            if [[ "$LDAP_TYPE" == "AD" ]]; then
                content_start="$(grep -n "ad:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
            else
                content_start="$(grep -n "tds:" ${CONTENT_PATTERN_FILE_TMP} | awk 'NR==2{print $1}' | cut -d: -f1)"
            fi
            content_stop="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "lc_group_filter:" | head -n1 | cut -d: -f1)"
            content_stop=$(( $content_stop + $content_start - 1))
            vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/    # /    ' -c ':wq'

            cp -r ${CONTENT_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
        fi
    fi
}

function set_object_store_content_pattern(){
    if [[ $DEPLOYMENT_TYPE == "enterprise" ]] ;
    then
        cp -r ${CONTENT_PATTERN_FILE_BAK} ${CONTENT_PATTERN_FILE_TMP}
        content_start="$(grep -n "datasource_configuration:" ${CONTENT_PATTERN_FILE_TMP} |  head -n 1 | cut -d: -f1)"
        content_tmp="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "dc_os_datasources:" | head -n1 | cut -d: -f1)"
        content_tmp=$(( content_tmp + $content_start - 1))
        content_stop="$(tail -n +$content_tmp < ${CONTENT_PATTERN_FILE_TMP} | grep -n "dc_database_type:" | head -n1 | cut -d: -f1)"
        content_start=$(( $content_stop + $content_tmp - 1))
        content_tmp="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "dc_hadr_max_retries_for_client_reroute:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_start + $content_tmp - 1))
        # 2nd object store
        if [[ "$content_os_number" == 2 ]]; then
            vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"' copy '"${content_stop}"'' -c ':wq' >/dev/null 2>&1
            ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[1].dc_common_os_datasource_name "FNOS2DS"
            ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[1].dc_common_os_xa_datasource_name "FNOS2DSXA"
        fi
        # 3rd object store
        if [[ "$content_os_number" == 3 ]]; then
            vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"' copy '"${content_stop}"'' -c ':wq' >/dev/null 2>&1
            vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"' copy '"${content_stop}"'' -c ':wq' >/dev/null 2>&1
            ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[1].dc_common_os_datasource_name "FNOS2DS"
            ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[1].dc_common_os_xa_datasource_name "FNOS2DSXA"
            ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[2].dc_common_os_datasource_name "FNOS3DS"
            ${YQ_CMD} w -i ${CONTENT_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[2].dc_common_os_xa_datasource_name "FNOS3DSXA"
        fi
        cp -r ${CONTENT_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
    fi
}

function set_aca_tenant_pattern(){
    if [[ $DEPLOYMENT_TYPE == "enterprise" ]] ;
    then    
        cp -r ${ACA_PATTERN_FILE_BAK} ${ACA_PATTERN_FILE_TMP}
        # ${YQ_CMD} d -i ${ACA_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases
        if [ ${#aca_tenant_arr[@]} -eq 0 ]; then
            echo -e "\x1B[1;31mNot any element in ACA tenant list found\x1B[0m:\x1B[1m"
        else
            for i in ${!aca_tenant_arr[@]}; do
               ${YQ_CMD} w -i ${ACA_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases.[${i}] "${aca_tenant_arr[i]}"
             done         
        fi
        cp -r ${ACA_PATTERN_FILE_TMP} ${ACA_PATTERN_FILE_BAK}
    fi
}

function select_aca_tenant(){
    printf "\n"
    printf "\x1B[1mHow many tenants do you want to create initially with Automation Content Analyzer? \x1B[0m"
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
        printf "\x1B[1mWhat is the name of tenant ${order_number}? \x1B[0m"
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

function select_baw_iaws(){
    pattern_arr=()
    pattern_cr_arr=()
    printf "\n"
    echo -e "\x1B[1mTips\x1B[0m: You may only choose one option for the entire installation as these choices are mutually exclusive. "
    echo -e "\x1B[1mSelect the Cloud Pak for Automation capability to install: \x1B[0m"
    COLUMNS=12
    get_baw_mode
    retVal_baw=$?

    if [[ "${DEPLOYMENT_TYPE}" == "demo" && $retVal_baw -eq 0 ]];
    then
        options=("Business Automation Workflow")
        PS3='Enter a valid option [1 to 1]: '
    elif [[ "${DEPLOYMENT_TYPE}" == "demo" && $retVal_baw -eq 1 ]];
    then 
        options=("Business Automation Workflow and Automation Workstream Services")
        PS3='Enter a valid option [1 to 1]: '   
    elif [[ "${DEPLOYMENT_TYPE}" == "enterprise" && $retVal_baw -eq 0 ]]
    then 
        options=("Business Automation Workflow")
        PS3='Enter a valid option [1 to 1]: '
    elif [[ "${DEPLOYMENT_TYPE}" == "enterprise" && $retVal_baw -eq 1 ]]
    then 
        options=("Business Automation Workflow" "Automation Workstream Services" "Business Automation Workflow and Automation Workstream Services")
        PS3='Enter a valid option [1 to 3]: '
    fi

    select opt in "${options[@]}"
    do
        case $opt in
            "Business Automation Workflow")
                pattern_arr=("Business Automation Workflow")
                pattern_cr_arr=("workflow")
                break
                ;;
            "Automation Workstream Services")
                pattern_arr=("Automation Workstream Services")
                pattern_cr_arr=("workstreams")
                break
                ;;
            "Business Automation Workflow and Automation Workstream Services")
                pattern_arr=("Business Automation Workflow and Automation Workstream Services")
                pattern_cr_arr=("workflow-workstreams")
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
    foundation_ww=("BAN" "RR" "UMS")
    foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_ww[@]}" )
    PATTERNS_CR_SELECTED=$( IFS=$','; echo "${pattern_cr_arr[*]}" )
    
    FOUNDATION_CR_SELECTED=($(echo "${foundation_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    # FOUNDATION_CR_SELECTED_LOWCASE=( "${FOUNDATION_CR_SELECTED[@],,}" )

    x=0;while [ ${x} -lt ${#FOUNDATION_CR_SELECTED[*]} ] ; do FOUNDATION_CR_SELECTED_LOWCASE[$x]=$(tr [A-Z] [a-z] <<< ${FOUNDATION_CR_SELECTED[$x]}); let x++; done
    FOUNDATION_DELETE_LIST=($(echo "${FOUNDATION_CR_SELECTED[@]}" "${FOUNDATION_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))

    PATTERNS_CR_SELECTED=($(echo "${pattern_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

function input_information(){
    select_installation_type

    if [[ ${INSTALLATION_TYPE} == "existing" ]]; then
        INSTALL_BAW_IAWS="No"
        prepare_pattern_file
        select_platform
        check_ocp_version
        validate_docker_podman_cli
        select_deployment_type
    elif [[ ${INSTALLATION_TYPE} == "new" ]]
    then
        select_platform
        check_ocp_version
        validate_docker_podman_cli
        select_deployment_type
        prepare_pattern_file
        select_baw_iaws_installation
    fi
    
    if [[ "${INSTALLATION_TYPE}" == "existing" ]] && (( ${#EXISTING_PATTERN_ARR[@]} == 0 )); then
        # get_existing_pattern_name
        # if (( ${#EXISTING_PATTERN_ARR[@]} == 0 )); then
        echo -e "\x1B[1;31mTHERE IS NOT ANY EXISTING PATTERN FOUND!\x1B[0m"
        read -rsn1 -p"Press any key to continue install new pattern...";echo
    fi

    if [[ "${INSTALL_BAW_IAWS}" = "No" ]];
    then
        select_pattern    
    else
        select_baw_iaws
    fi
    select_optional_component
    get_entitlement_registry
    if [ "$use_entitlement" = "no" ]; then
        verify_local_registry_password
    fi

    if  [[ $PLATFORM_SELECTED == "OCP" ]];
    then
        get_infra_name
    fi
    get_storage_class_name
    
    if [[ "$DEPLOYMENT_TYPE" == "enterprise" ]]; then
        select_ldap_type
    fi

    containsElement "content" "${PATTERNS_CR_SELECTED[@]}"
    retVal=$?
    if [[ ( $retVal -eq 0 ) && "$DEPLOYMENT_TYPE" == "enterprise" ]]; then
        select_objectstore_number
    fi

    containsElement "contentanalyzer" "${PATTERNS_CR_SELECTED[@]}"
    retVal=$?
    if [[ ( $retVal -eq 0 ) && "$DEPLOYMENT_TYPE" == "enterprise" ]]; then
        select_aca_tenant
    fi    

    # containsElement "decisions_ads" "${PATTERNS_CR_SELECTED[@]}"
    # retVal=$?
    # if [[ ( $retVal -eq 0 ) && ( "$DEPLOYMENT_TYPE" == "non-production" || "$DEPLOYMENT_TYPE" == "production") ]]; then
    #     select_ads_designer
    # fi  
}

function apply_cp4a_operator(){
    cp -r ${OPERATOR_FILE_BAK} ${OPERATOR_FILE_TMP}

    printf "\n"
    echo -e "\x1B[1mInstalling the Cloud Pak for Automation operator...\x1B[0m"

    # set db2_license
    ${SED_COMMAND} '/dba_license/{n;s/value:/value: accept/;}' ${OPERATOR_FILE_TMP}
    ${SED_COMMAND} '/baw_license/{n;s/value:/value: accept/;}' ${OPERATOR_FILE_TMP}
    # Set operator image pull secret
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

    ${CLI_CMD} delete -f ${OPERATOR_FILE_TMP} >/dev/null 2>&1
    sleep 5

    INSTALL_OPERATOR_CMD="${CLI_CMD} apply -f ${OPERATOR_FILE_TMP}"
    if $INSTALL_OPERATOR_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi

    cp -rf ${OPERATOR_FILE_TMP} ${OPERATOR_FILE_BAK}
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
    COPY_JDBC_CMD="${CLI_CMD} cp ${JDBC_DRIVER_DIR} ${operator_podname}:/opt/ansible/share/jdbc -c ansible"

    if $COPY_JDBC_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi
}

function set_foundation_components(){
    if (( ${#FOUNDATION_DELETE_LIST[@]} > 0 ));then
        cp -r ${FOUNDATION_PATTERN_FILE_BAK} ${FOUNDATION_PATTERN_FILE_TMP}
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
                ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bastudio_configuration
            fi
            if [[ "$item" == "UMS" ]];then
                ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.ums_configuration
            fi  
            if [[ "$item" == "BAN" ]];then
                ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.navigator_configuration
            fi           
            if [[ "$item" == "RR" ]];then
                ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.resource_registry_configuration
            fi  
        done    
        cp -r ${FOUNDATION_PATTERN_FILE_TMP} ${FOUNDATION_PATTERN_FILE_BAK}
    fi
}

function merge_pattern(){
    cp -r ${FOUNDATION_PATTERN_FILE_BAK} ${FOUNDATION_PATTERN_FILE_TMP}
    set_ldap_type_foundation
    for item in "${PATTERNS_CR_SELECTED[@]}"; do
        while true; do
            case $item in
                "content")
                    set_ldap_type_content_pattern
                    set_external_share_content_pattern
                    set_object_store_content_pattern
                    ${YQ_CMD} m -a -i -M ${FOUNDATION_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
                    break
                    ;;
                "contentanalyzer")
                    set_aca_tenant_pattern
                    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases
                    ${YQ_CMD} m -a -i -M ${FOUNDATION_PATTERN_FILE_TMP} ${ACA_PATTERN_FILE_BAK}
                    break
                    ;;
                "decisions")
                    set_decision_feature
                    ${YQ_CMD} m -a -i -M ${FOUNDATION_PATTERN_FILE_TMP} ${DECISIONS_PATTERN_FILE_BAK}
                    break
                    ;;
                "workflow")
                    set_ldap_type_workflow_pattern
                    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.baw_configuration.[*]
                    if [[ $DEPLOYMENT_TYPE == "enterprise" ]];then
                        cp -rf ${WORKFLOW_PATTERN_FILE_BAK} ${FOUNDATION_PATTERN_FILE_TMP} 
                    elif [[ $DEPLOYMENT_TYPE == "demo" ]]
                    then
                        ${YQ_CMD} m -a -i -M ${FOUNDATION_PATTERN_FILE_TMP} ${WORKFLOW_PATTERN_FILE_BAK}
                        ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bastudio_configuration
                    fi
                    break
                    ;;
                "workstreams")
                    set_ldap_type_workstreams_pattern
                    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.baw_configuration.[*]
                    if [[ $DEPLOYMENT_TYPE == "enterprise" ]];then
                        cp -rf ${WORKSTREAMS_PATTERN_FILE_BAK} ${FOUNDATION_PATTERN_FILE_TMP} 
                    elif [[ $DEPLOYMENT_TYPE == "demo" ]]
                    then
                        ${YQ_CMD} m -a -i -M ${FOUNDATION_PATTERN_FILE_TMP} ${WORKSTREAMS_PATTERN_FILE_BAK}
                    fi
                    break
                    ;;
                "workflow-workstreams")
                    set_ldap_type_ww_pattern
                    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.baw_configuration.[*]
                    if [[ $DEPLOYMENT_TYPE == "enterprise" ]];then
                        cp -rf ${WW_PATTERN_FILE_BAK} ${FOUNDATION_PATTERN_FILE_TMP} 
                    elif [[ $DEPLOYMENT_TYPE == "demo" ]]
                    then
                        ${YQ_CMD} m -a -i -M ${FOUNDATION_PATTERN_FILE_TMP} ${WW_PATTERN_FILE_BAK}
                        ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bastudio_configuration
                    fi
                    break
                    ;;
                "application")
                    set_baa_app_designer
                    ${YQ_CMD} m -a -i -M ${FOUNDATION_PATTERN_FILE_TMP} ${APPLICATION_PATTERN_FILE_BAK}
                    break
                    ;;
                "digitalworker")
                    ${YQ_CMD} m -a -i -M ${FOUNDATION_PATTERN_FILE_TMP} ${ADW_PATTERN_FILE_BAK}
                    break
                    ;;
                "decisions_ads")
                    set_ads_designer_runtime
                    ${YQ_CMD} m -a -i -M ${FOUNDATION_PATTERN_FILE_TMP} ${ADS_PATTERN_FILE_BAK}
                    break
                    ;;
            esac
        done
    done
    # ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.shared_configuration.image_pull_secrets
    # ${YQ_CMD} w -i ${FOUNDATION_PATTERN_FILE_TMP} spec.shared_configuration.image_pull_secrets.[0] "image-pull-secret"
    cp -r ${FOUNDATION_PATTERN_FILE_TMP} ${FOUNDATION_PATTERN_FILE_BAK}
}

function merge_optional_components(){
    cp -r ${FOUNDATION_PATTERN_FILE_BAK} ${FOUNDATION_PATTERN_FILE_TMP}

    for item in "${OPTIONAL_COMPONENT_DELETE_LIST[@]}"; do
        while true; do
            case $item in
                "bas")
                    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bastudio_configuration
                    break
                    ;;
                "ums")
                    containsElement "bai" "${optional_component_cr_arr[@]}"
                    retVal=$?
                    if [[ $retVal -eq 1 ]]; then
                        ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.ums_configuration
                    fi
                    break
                    ;;
                "cmis")
                    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.ecm_configuration.cmis
                    break
                    ;;
                "css")
                    break
                    ;;
                "es")
                    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.ecm_configuration.es
                    break
                    ;;            
                "tm")
                    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.ecm_configuration.tm
                    break
                    ;; 
                "bai")
                    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bai_configuration
                    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.shared_configuration.kafka_configuration
                    break
                    ;;
                "ads_designer")
                    # ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bai_configuration
                    break
                    ;;
                "ads_runtime")
                    # ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bai_configuration
                    break
                    ;;
                "decisionCenter")
                    # ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bai_configuration
                    break
                    ;;
                "decisionRunner")
                    # ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bai_configuration
                    break
                    ;;
                "decisionServerRuntime")
                    # ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bai_configuration
                    break
                    ;;
                "app_designer")
                    # foundation_app=("BAS")
                    # foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_app[@]}" )
                    # ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.bastudio_configuration
                    break
                    ;;
            esac
        done
    done
    FOUNDATION_CR_SELECTED=($(echo "${foundation_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    # FOUNDATION_CR_SELECTED_LOWCASE=( "${FOUNDATION_CR_SELECTED[@],,}" )

    x=0;while [ ${x} -lt ${#FOUNDATION_CR_SELECTED[*]} ] ; do FOUNDATION_CR_SELECTED_LOWCASE[$x]=$(tr [A-Z] [a-z] <<< ${FOUNDATION_CR_SELECTED[$x]}); let x++; done
    FOUNDATION_DELETE_LIST=($(echo "${FOUNDATION_CR_SELECTED[@]}" "${FOUNDATION_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))
    
    cp -r ${FOUNDATION_PATTERN_FILE_TMP} ${FOUNDATION_PATTERN_FILE_BAK}
}

function get_existing_pattern_name(){
    existing_pattern_cr_name=""
    existing_pattern_list=""
    existing_opt_component_list=""
    existing_platform_type=""
    existing_deployment_type=""
    printf "\x1B[1mProvide the path and file name to the existing custom resources (CR)?\n\x1B[0m"
    printf "\x1B[1mPress [Enter] to accept default.\n\x1B[0m"
    # printf "\x1B[1mDefault is \x1B[0m(${FOUNDATION_PATTERN_FILE_BAK}): "  
    # existing_pattern_cr_name=`${CLI_CMD} get icp4acluster|awk '{if(NR>1){if(NR==2){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }'`
    
    while [[ $existing_pattern_cr_name == "" ]];
    do
        read -p "[Default=$FOUNDATION_PATTERN_FILE_BAK]: " existing_pattern_cr_name
        : ${existing_pattern_cr_name:=$FOUNDATION_PATTERN_FILE_BAK}
        if [ -f "$existing_pattern_cr_name" ]; then
            printf "\n"
        else 
            echo -e "\x1B[1;31m\"$existing_pattern_cr_name\" file does not exist! \n\x1B[0m"
            existing_pattern_cr_name=""
        fi
    done     
    # existing_pattern_list=`${CLI_CMD} get icp4acluster $existing_pattern_cr_name -o yaml | yq r - spec.shared_configuration.sc_deployment_patterns`
    # existing_pattern_deploy_type=`${CLI_CMD} get icp4acluster $existing_pattern_cr_name -o yaml | yq r - spec.shared_configuration.sc_deployment_type`
    existing_pattern_list=`cat $existing_pattern_cr_name | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
    existing_opt_component_list=`cat $existing_pattern_cr_name | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`
    
    existing_platform_type=`cat $existing_pattern_cr_name | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_platform`
    existing_deployment_type=`cat $existing_pattern_cr_name | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_type`


    case "${existing_deployment_type}" in
        demo*)     DEPLOYMENT_TYPE="demo";;
        enterprise*)    DEPLOYMENT_TYPE="enterprise";;
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
}

function select_objectstore_number(){
    printf "\n"
    printf "\x1B[1mHow many object stores is being deployed? \x1B[0m"
    content_os_number=""
    while [[ $content_os_number == "" ]];
    do
        read -rp "" content_os_number
        if ! [[ "$content_os_number" =~ ^[1-3]$ ]]; then
            echo -e "\x1B[1;31mEnter a valid number [1 to 3]\x1B[0m"
            content_os_number=""
        fi
    done   
}

# function select_ads_designer(){
#     INSTALL_ADS_DESIGNER=""
#     ads_designer_install=""
#     printf "\n"
#     printf "(Note: if you are deploying a development environment where you want to design\n"
#     printf "and manage your decision projects, then you would want this option)\n"
#     printf "\x1B[1mDo you want ADS Decision Designer to be installed? \x1B[0m"

#     while [[ $ads_designer_install == "" ]];
#     do
#         read -rp "" ads_designer_install
#         case "$ads_designer_install" in
#         "y"|"Y"|"yes"|"Yes"|"YES")
#             INSTALL_ADS_DESIGNER="Yes"
#             break
#             ;;
#         "n"|"N"|"no"|"No"|"NO")
#             INSTALL_ADS_DESIGNER="No"
#             break
#             ;;
#         *)
#             printf "\x1B[1mDo you want ADS Decision Designer to be installed (Yes/No)? \x1B[0m"
#             ads_designer_install=""
#             ;;
#         esac
#     done  
# }


function set_baa_app_designer(){
    cp -r ${APPLICATION_PATTERN_FILE_BAK} ${APPLICATION_PATTERN_FILE_TMP} 
    if [[ $DEPLOYMENT_TYPE == "demo"  ]] ;
    then
        foundation_baa=("BAS")
        foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_baa[@]}" )

    elif [[ $DEPLOYMENT_TYPE == "enterprise" ]]
    then
        containsElement "app_designer" "${OPT_COMPONENTS_CR_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            foundation_baa=("BAS")
            foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_baa[@]}" )
        fi
    fi
    cp -r ${APPLICATION_PATTERN_FILE_TMP} ${APPLICATION_PATTERN_FILE_BAK}
}

function set_ads_designer_runtime(){
    cp -r ${ADS_PATTERN_FILE_BAK} ${ADS_PATTERN_FILE_TMP} 
    if [[ $DEPLOYMENT_TYPE == "demo"  ]] ;
    then
        ${YQ_CMD} w -i ${ADS_PATTERN_FILE_TMP} spec.ads_configuration.decision_designer.enabled "true"
        ${YQ_CMD} w -i ${ADS_PATTERN_FILE_TMP} spec.ads_configuration.decision_runtime.enabled "true"
        foundation_ads=("BAS")
        foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_ads[@]}" )

    elif [[ $DEPLOYMENT_TYPE == "enterprise" ]]
    then
        # yq d -i ${ACA_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases
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
    cp -r ${ADS_PATTERN_FILE_TMP} ${ADS_PATTERN_FILE_BAK}
}


function set_decision_feature(){
    cp -r ${DECISIONS_PATTERN_FILE_BAK} ${DECISIONS_PATTERN_FILE_TMP}
    if [[ $DEPLOYMENT_TYPE == "demo"  ]] ;
    then
        ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionCenter.enabled "true"
        ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionServerRuntime.enabled "true"
        ${YQ_CMD} w -i ${DECISIONS_PATTERN_FILE_TMP} spec.odm_configuration.decisionRunner.enabled "true"
    elif [[ $DEPLOYMENT_TYPE == "enterprise" ]]
    then
        # yq d -i ${ACA_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ca_datasource.tenant_databases
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
    cp -r ${DECISIONS_PATTERN_FILE_TMP} ${DECISIONS_PATTERN_FILE_BAK}
}

# Begin - Modify FOUNDATION pattern yaml according patterns/components selected
function apply_pattern_cr(){
    # echo "length of optional_component_cr_arr:${#optional_component_cr_arr[@]}"
    # echo "!!optional_component_cr_arr!!!${optional_component_cr_arr[*]}"
    # echo "PATTERNS_CR_SELECTED: ${PATTERNS_CR_SELECTED[*]}"
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

    cp -r ${FOUNDATION_PATTERN_FILE_BAK} ${FOUNDATION_PATTERN_FILE_TMP}

    tps=" ${OPTIONAL_COMPONENT_DELETE_LIST[*]} "
    for item in ${KEEP_COMPOMENTS[@]}; do
        tps=${tps/ ${item} / }               
    done
    OPTIONAL_COMPONENT_DELETE_LIST=( $tps ) 
    # Convert pattern array to pattern list by common
    delim=""
    pattern_joined=""
    for item in "${PATTERNS_CR_SELECTED[@]}"; do
        pattern_joined="$pattern_joined$delim$item"
        delim=","
    done
    if [[ $INSTALL_BAW_IAWS == "No" ]];then
        pattern_joined="foundation$delim$pattern_joined"
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

    # Set sc_deployment_patterns
    ${SED_COMMAND} "s|sc_deployment_patterns:.*|sc_deployment_patterns: \"$pattern_joined\"|g" ${FOUNDATION_PATTERN_FILE_TMP}

    # Set sc_optional_components='' when none optional component selected
    if [ "${#optional_component_cr_arr[@]}" -eq "0" ]; then
        ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"\"|g" ${FOUNDATION_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"$opt_components_joined\"|g" ${FOUNDATION_PATTERN_FILE_TMP}
    fi

    # Set sc_deployment_platform
    ${SED_COMMAND} "s|sc_deployment_platform:.*|sc_deployment_platform: \"$PLATFORM_SELECTED\"|g" ${FOUNDATION_PATTERN_FILE_TMP}

    # Set sc_deployment_type
    ${SED_COMMAND} "s|sc_deployment_type:.*|sc_deployment_type: \"$DEPLOYMENT_TYPE\"|g" ${FOUNDATION_PATTERN_FILE_TMP}


    # Set sc_deployment_hostname_suffix
    if  [[ $PLATFORM_SELECTED == "OCP" ]];
    then
        ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}.${INFRA_NAME}\"|g" ${FOUNDATION_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}\"|g" ${FOUNDATION_PATTERN_FILE_TMP}
    fi

    # Set lc_selected_ldap_type

    if [[ $DEPLOYMENT_TYPE == "enterprise" ]];then
        if [[ $LDAP_TYPE == "AD" ]];then
            # ${YQ_CMD} w -i ${FOUNDATION_PATTERN_FILE_TMP} spec.ldap_configuration.lc_selected_ldap_type "\"Microsoft Active Directory\""
            ${SED_COMMAND} "s|lc_selected_ldap_type:.*|lc_selected_ldap_type: \"Microsoft Active Directory\"|g" ${FOUNDATION_PATTERN_FILE_TMP}

        elif [[ $LDAP_TYPE == "TDS" ]]
        then
            # ${YQ_CMD} w -i ${FOUNDATION_PATTERN_FILE_TMP} spec.ldap_configuration.lc_selected_ldap_type "IBM Security Directory Server"
            ${SED_COMMAND} "s|lc_selected_ldap_type:.*|lc_selected_ldap_type: \"IBM Security Directory Server\"|g" ${FOUNDATION_PATTERN_FILE_TMP}
        fi 
    fi
    # Set sc_dynamic_storage_classname
    ${SED_COMMAND} "s|sc_dynamic_storage_classname:.*|sc_dynamic_storage_classname: ${STORAGE_CLASS_NAME}|g" ${FOUNDATION_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|sc_slow_file_storage_classname:.*|sc_slow_file_storage_classname: ${SLOW_STORAGE_CLASS_NAME}|g" ${FOUNDATION_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|sc_medium_file_storage_classname:.*|sc_medium_file_storage_classname: ${MEDIUM_STORAGE_CLASS_NAME}|g" ${FOUNDATION_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|sc_fast_file_storage_classname:.*|sc_fast_file_storage_classname: ${FAST_STORAGE_CLASS_NAME}|g" ${FOUNDATION_PATTERN_FILE_TMP}
    # Set image_pull_secrets
    # ${SED_COMMAND} "s|image-pull-secret|$DOCKER_RES_SECRET_NAME|g" ${FOUNDATION_PATTERN_FILE_TMP}
    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} spec.shared_configuration.image_pull_secrets
    ${YQ_CMD} w -i ${FOUNDATION_PATTERN_FILE_TMP} spec.shared_configuration.image_pull_secrets.[0] "$DOCKER_RES_SECRET_NAME"

    # set sc_image_repository
    if [ "$use_entitlement" = "yes" ] ; then
        ${SED_COMMAND} "s|sc_image_repository:.*|sc_image_repository: ${DOCKER_REG_SERVER}|g" ${FOUNDATION_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s|sc_image_repository:.*|sc_image_repository: ${CONVERT_LOCAL_REGISTRY_SERVER}|g" ${FOUNDATION_PATTERN_FILE_TMP}
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

    if [ "$use_entitlement" = "yes" ] ; then
        ${SED_COMMAND} "s/$REGISTRY_IN_FILE/$DOCKER_REG_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s/$old_fmcn/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ban/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ldap/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2_etcd/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_busybox/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ums/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_bas/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_aae/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_baca/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_odm/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_baw/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_iaws/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ads/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_workflow/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${FOUNDATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "/imageCredentials:/{n;s/registry:.*/registry: "${CONVERT_LOCAL_REGISTRY_SERVER}"/;}" ${FOUNDATION_PATTERN_FILE_TMP}

    fi

    # If BAI is selected as an optional component in a demo deployment, the installation of IBM Event Streams
    # 10.0.0+ in the namespace targeted by the ICP4A deployment is a prerequisite. The connection
    # information for Kafka clients is automatically extracted from the Event Streams instance
    # and stored in shared_configuration.kafka_configuration.

    if [[ $DEPLOYMENT_TYPE == "demo" ]];then
        containsElement "BusinessAutomationInsights" "${OPT_COMPONENTS_SELECTED[@]}"
        retVal=$?
        if [[ $retVal -eq 0 ]]; then
            printf "\n"
            while true; do
                printf "\x1B[1mHas IBM Event Streams already been deployed to the same namespace for CP4A (a prerequisite for Business Automation Insights)?\x1B[0m"
                printf "\n"
                printf "\x1B[1mFor more information about the IBM Event Streams supported version number and licensing restrictions, see IBM Knowledge Center\x1B[0m"
                read -rp "?(Yes/No):" ans
                case "$ans" in
                "y"|"Y"|"yes"|"Yes"|"YES")
                    ${CUR_DIR}/pull-eventstreams-connection-info.sh -f ${FOUNDATION_PATTERN_FILE_TMP} || true
                    break
                    ;;
                "n"|"N"|"no"|"No"|"NO")
                    echo -e "\x1B[1;31mPlease refer to the documentation in Knowledge Center and deploy IBM Event Streams to the same namespace before proceeding with CP4A deployment.\n\x1B[0m"
                    echo -e "Exiting...\n"
                    exit 0
                    ;;
                *)
                    echo -e "Answer must be \"Yes\" or \"No\"\n"
                    ;;
                esac
            done
        fi
    fi
    
    # remove merge issue
    ${YQ_CMD} d -i ${FOUNDATION_PATTERN_FILE_TMP} metadata.labels.app.*
    # Keep existing value 
    if [[ "${DEPLOYMENT_TYPE}" == "existing" ]]; then
        ${YQ_CMD} m -x -i ${FOUNDATION_PATTERN_FILE_TMP} ${FOUNDATION_EXISTING_BAK} 
    fi

    ${SED_COMMAND_FORMAT} ${FOUNDATION_PATTERN_FILE_TMP}
    cp -rf ${FOUNDATION_PATTERN_FILE_TMP} ${FOUNDATION_PATTERN_FILE_BAK}
    if [[ "$DEPLOYMENT_TYPE" == "demo" && "$INSTALLATION_TYPE" == "new" && $1 != "review" ]];then   
        ${CLI_CMD} delete -f ${FOUNDATION_PATTERN_FILE_BAK} >/dev/null 2>&1
        sleep 5 
        printf "\n"
        echo -e "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"

        APPLY_CONTENT_CMD="${CLI_CMD} apply -f ${FOUNDATION_PATTERN_FILE_BAK}"

        if $APPLY_CONTENT_CMD ; then
            echo -e "\x1B[1mDone\x1B[0m"
        else
            echo -e "\x1B[1;31mFailed\x1B[0m"
        fi
    elif  [[ "$DEPLOYMENT_TYPE" == "demo" && "$INSTALLATION_TYPE" == "existing" && $1 != "review" ]]
    then
        echo -e "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"

        APPLY_CONTENT_CMD="${CLI_CMD} apply -f ${FOUNDATION_PATTERN_FILE_BAK}"

        if $APPLY_CONTENT_CMD ; then
            echo -e "\x1B[1mDone\x1B[0m"
        else
            echo -e "\x1B[1;31mFailed\x1B[0m"
        fi

    fi
    printf "\n"
    echo -e "\x1B[1mThe custom resource file used is: \"${FOUNDATION_PATTERN_FILE_BAK}\"\x1B[0m"

    printf "\n"
    echo -e "\x1B[1mTo monitor the deployment status, follow the Operator logs.\x1B[0m"  
    echo -e "\x1B[1mFor details, refer to the troubleshooting section in Knowledge Center here: \x1B[0m"
    echo -e "\x1B[1mhttps://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_trbleshoot_operators.html\x1B[0m"
}
# End - Modify FOUNDATION pattern yaml according pattent/components selected

function show_summary(){
    printf "\n"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    echo -e "\x1B[1m                    Summary of input                   \x1B[0m"
    echo -e "\x1B[1m*******************************************************\x1B[0m"

    echo -e "\x1B[1;31m1. Cloud Pak capability to deploy: \x1B[0m"
    if [ "${#pattern_arr[@]}" -eq "0" ]; then
        printf '   * %s\n' "None"
    else
        printf '   * %s\n' "${pattern_arr[@]}"
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
            elif [[ "${each_opt_component}" == "ApplicationDesigner" ]]
            then
                printf '   * %s\n' "Application Designer"
            else
                printf '   * %s\n' "${each_opt_component}"
            fi
        done
    fi

    echo -e "\x1B[1;31m3. Entitlement Registry key:\x1B[0m ${DOCKER_REG_KEY}"
    echo -e "\x1B[1;31m4. Docker registry service name or URL:\x1B[0m ${LOCAL_REGISTRY_SERVER}"
    echo -e "\x1B[1;31m5. Docker registry user name:\x1B[0m ${LOCAL_REGISTRY_USER}"
    # echo -e "\x1B[1;31m5. Docker registry password: ${LOCAL_REGISTRY_PWD}\x1B[0m"
    echo -e "\x1B[1;31m6. Docker registry password:\x1B[0m" # not show plaintext password
    if  [[ $PLATFORM_SELECTED == "OCP" ]];
    then
        echo -e "\x1B[1;31m7. OCP Infrastructure Node:\x1B[0m ${INFRA_NAME}"
        if  [[ $DEPLOYMENT_TYPE == "demo" ]];
        then
            echo -e "\x1B[1;31m8. Dynamic storage classname:\x1B[0m ${STORAGE_CLASS_NAME}"
        else
            echo -e "\x1B[1;31m8. Dynamic storage classname:\x1B[0m"
            printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Slow:" "${SLOW_STORAGE_CLASS_NAME}"
            printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Medium:" "${MEDIUM_STORAGE_CLASS_NAME}"
            printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Fast:" "${FAST_STORAGE_CLASS_NAME}"
        fi
    else
        if  [[ $DEPLOYMENT_TYPE == "demo" ]];
        then
            echo -e "\x1B[1;31m7. Dynamic storage classname:\x1B[0m ${STORAGE_CLASS_NAME}"
        else
            echo -e "\x1B[1;31m7. Dynamic storage classname:\x1B[0m"
            printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Slow:" "${SLOW_STORAGE_CLASS_NAME}"
            printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Medium:" "${MEDIUM_STORAGE_CLASS_NAME}"
            printf '   * \x1B[1;31m%s\x1B[0m %s\n' "Fast:" "${FAST_STORAGE_CLASS_NAME}"
        fi
    fi
    
    echo -e "\x1B[1m*******************************************************\x1B[0m"
}

function prepare_pattern_file(){
    if [[ "${INSTALLATION_TYPE}" == "new" ]]; then
        rm -rf $TEMP_FOLDER >/dev/null 2>&1
        rm -rf $BAK_FOLDER >/dev/null 2>&1
        rm -rf $FINAL_CR_FOLDER >/dev/null 2>&1
    fi
    mkdir -p $TEMP_FOLDER >/dev/null 2>&1
    mkdir -p $BAK_FOLDER >/dev/null 2>&1
    mkdir -p $FINAL_CR_FOLDER >/dev/null 2>&1

    cp -rf "${OPERATOR_FILE}" "${OPERATOR_FILE_BAK}"
    cp -rf "${OPERATOR_PVC_FILE}" "${OPERATOR_PVC_FILE_BAK}"

    if [[ "$DEPLOYMENT_TYPE" == "enterprise" ]];then
        DEPLOY_TYPE_IN_FILE_NAME="enterprise"
    else
        DEPLOY_TYPE_IN_FILE_NAME="demo"
    fi

    FOUNDATION_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_foundation.yaml


    CONTENT_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_content.yaml
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

    ACA_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_aca.yaml
    ACA_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_aca_tmp.yaml
    ACA_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_aca.yaml

    # Temp to user ADS template.
    ADW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_digitalworker.yaml
    ADW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_digitalworker_tmp.yaml
    ADW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_digitalworker.yaml


    cp -rf "${CONTENT_PATTERN_FILE}" "${CONTENT_PATTERN_FILE_BAK}"
    cp -rf "${APPLICATION_PATTERN_FILE}" "${APPLICATION_PATTERN_FILE_BAK}"
    cp -rf "${ADS_PATTERN_FILE}" "${ADS_PATTERN_FILE_BAK}"
    cp -rf "${DECISIONS_PATTERN_FILE}" "${DECISIONS_PATTERN_FILE_BAK}"
    cp -rf "${ACA_PATTERN_FILE}" "${ACA_PATTERN_FILE_BAK}"
    cp -rf "${ADW_PATTERN_FILE}" "${ADW_PATTERN_FILE_BAK}"
    # support existing installation
    if [ -f "$FOUNDATION_PATTERN_FILE_BAK" ]; then
        cp -rf "${FOUNDATION_PATTERN_FILE_BAK}" "${FOUNDATION_EXISTING_BAK}"
        ${YQ_CMD} d -i ${FOUNDATION_EXISTING_BAK} spec.shared_configuration
    else
        cp -rf "${FOUNDATION_PATTERN_FILE}" "${FOUNDATION_PATTERN_FILE_BAK}"
    fi

    if [[ "$DEPLOYMENT_TYPE" == "demo" ]];then
        WORKFLOW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow.yaml
        WORKFLOW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_tmp.yaml
        WORKFLOW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow.yaml

        # WORKSTREAMS_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workstreams.yaml
        # WORKSTREAMS_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workstreams_tmp.yaml
        # WORKSTREAMS_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workstreams.yaml

        WW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow-workstreams.yaml
        WW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow-workstreams_tmp.yaml
        WW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow-workstreams.yaml
        cp -rf "${WORKFLOW_PATTERN_FILE}" "${WORKFLOW_PATTERN_FILE_BAK}"
        cp -rf "${WW_PATTERN_FILE}" "${WW_PATTERN_FILE_BAK}"
        # get_baw_mode
        # retVal_baw=$?
        # if [ $retVal_baw -eq 0 ]; then
        #     WORKFLOW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow.yaml
        #     WORKFLOW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_tmp.yaml
        #     WORKFLOW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow.yaml
        # else
        #     WORKFLOW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow-workstreams.yaml
        #     WORKFLOW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow-workstreams_tmp.yaml
        #     WORKFLOW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow-workstreams.yaml        
        # fi
    elif [[ "$DEPLOYMENT_TYPE" == "enterprise" ]]
    then
        WORKFLOW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_FC_workflow.yaml
        WORKFLOW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_FC_workflow_tmp.yaml
        WORKFLOW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_FC_workflow.yaml

        WORKSTREAMS_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_FC_workstreams.yaml
        WORKSTREAMS_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_FC_workstreams_tmp.yaml
        WORKSTREAMS_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_FC_workstreams.yaml

        WW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_FC_workflow-workstreams.yaml
        WW_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_FC_workflow-workstreams_tmp.yaml
        WW_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_FC_workflow-workstreams.yaml
        cp -rf "${WORKFLOW_PATTERN_FILE}" "${WORKFLOW_PATTERN_FILE_BAK}"
        cp -rf "${WORKSTREAMS_PATTERN_FILE}" "${WORKSTREAMS_PATTERN_FILE_BAK}"
        cp -rf "${WW_PATTERN_FILE}" "${WW_PATTERN_FILE_BAK}"
    fi
}
################################################
#### Begin - Main step for install operator ####
################################################

prompt_license

input_information

show_summary

while true; do

    printf "\n"
    printf "\x1B[1mVerify that the information above is correct.\n\x1B[0m"
    printf "\x1B[1mTo proceed with the deployment, enter \"Yes\".\n\x1B[0m"
    printf "\x1B[1mTo make changes, enter \"No\" (default: No): \x1B[0m"
    read -rp "" ans
    case "$ans" in
    "y"|"Y"|"yes"|"Yes"|"YES")
        printf "\n"
        echo -e "\x1B[1mInstalling the Cloud Pak for Automation operator...\x1B[0m"
        printf "\n"
        if [[ "${INSTALLATION_TYPE}"  == "new" ]]; then 
            if [ "$use_entitlement" = "no" ] ; then
                create_secret_local_registry
            else
                create_secret_entitlement_registry
            fi
            if [[ $1 == "review" ]]; then
                echo -e "\x1B[1mReview mode running, just generate final CR, will not deploy operator\x1B[0m"
                read -rsn1 -p"Press any key to continue";echo
            else
                allocate_operator_pvc
                apply_cp4a_operator
                copy_jdbc_driver
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
            if  [[ $PLATFORM_SELECTED == "OCP" ]];
            then
                printf "\x1B[1mEnter the number from 1 to 8 that you want to change: \x1B[0m"
            else
                printf "\x1B[1mEnter the number from 1 to 7 that you want to change: \x1B[0m"
            fi

            read -rp "" ans
            if  [[ $PLATFORM_SELECTED == "OCP" ]];
            then
                case "$ans" in
                "1")
                    select_pattern
                    select_optional_component
                    break
                    ;;
                "2")
                    select_optional_component
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
                    get_infra_name
                    break
                    ;;
                "8")
                    get_storage_class_name
                    break
                    ;;
                *)
                    echo -e "\x1B[1mEnter a valid number [1 to 8] \x1B[0m"
                    ;;
                esac
            else
                case "$ans" in
                "1")
                    select_pattern

                    select_optional_component
                    break
                    ;;
                "2")
                    select_optional_component
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
                    get_storage_class_name
                    break
                    ;;
                *)
                    echo -e "\x1B[1mEnter a valid number [1 to 7] \x1B[0m"
                    ;;
                esac
            fi
        done
        show_summary
        ;;
    esac
done
################################################
#### End - Main step for install operator ####
################################################
