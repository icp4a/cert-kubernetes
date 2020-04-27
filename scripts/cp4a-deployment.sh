#!/bin/bash
#set -x
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
unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine="Linux";;
    Darwin*)    machine="Mac";;
    CYGWIN*)    machine="Cygwin";;
    MINGW*)     machine="MinGw";;
    *)          machine="UNKNOWN:${unameOut}"
esac

if [[ "$machine" == "Mac" ]]; then
    SED_COMMAND='sed -i ""'
    SED_COMMAND_FORMAT='sed -i "" s///g'
else
    SED_COMMAND='sed -i'
    SED_COMMAND_FORMAT='sed -i s/\r//g'
fi

CUR_DIR=$(cd $(dirname $0); pwd)
PARENT_DIR=$(dirname "$PWD")

DOCKER_RES_SECRET_NAME="admin.registrykey"
DOCKER_REG_USER=""
if [[ $1 == "dev" ]]
then
    DOCKER_REG_SERVER="cp.stg.icr.io"
else
    DOCKER_REG_SERVER="cp.icr.io"
fi
DOCKER_REG_KEY=""
REGISTRY_IN_FILE="cp.icr.io"
OPERATOR_IMAGE=${DOCKER_REG_SERVER}/cp/cp4a/icp4a-operator:20.0.1 # Need change when release

old_db2="docker.io\/ibmcom"
old_ldap="osixia"
old_db2_etcd="quay.io\/coreos"
old_busybox="docker.io\/library"

TMEP_FOLDER=${CUR_DIR}/.tmp
BAK_FOLDER=${CUR_DIR}/.bak

OPERATOR_FILE=${PARENT_DIR}/descriptors/operator.yaml
OPERATOR_FILE_TMP=$TMEP_FOLDER/.operator_tmp.yaml
OPERATOR_FILE_BAK=$BAK_FOLDER/.operator.yaml

OPERATOR_PVC_FILE=${PARENT_DIR}/descriptors/operator-shared-pvc.yaml
OPERATOR_PVC_FILE_TMP=$TMEP_FOLDER/.operator-shared-pvc_tmp.yaml
OPERATOR_PVC_FILE_BAK=$BAK_FOLDER/.operator-shared-pvc.yaml

CONTENT_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_demo_content.yaml
CONTENT_PATTERN_FILE_TMP=$TMEP_FOLDER/.ibm_cp4a_cr_demo_content_tmp.yaml
CONTENT_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_demo_content.yaml

APPLICATION_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_demo_application.yaml
APPLICATION_PATTERN_FILE_TMP=$TMEP_FOLDER/.ibm_cp4a_cr_demo_application_tmp.yaml
APPLICATION_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_demo_application.yaml

ACA_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_demo_aca.yaml
ACA_PATTERN_FILE_TMP=$TMEP_FOLDER/.ibm_cp4a_cr_demo_aca_tmp.yaml
ACA_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_demo_aca.yaml

WORKSTREAMS_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_demo_workstreams.yaml
WORKSTREAMS_PATTERN_FILE_TMP=$TMEP_FOLDER/.ibm_cp4a_cr_demo_workstreams_tmp.yaml
WORKSTREAMS_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_demo_workstreams.yaml

DECISIONS_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_demo_decisions.yaml
DECISIONS_PATTERN_FILE_TMP=$TMEP_FOLDER/.ibm_cp4a_cr_demo_decisions_tmp.yaml
DECISIONS_PATTERN_FILE_BAK=$BAK_FOLDER/.ibm_cp4a_cr_demo_decisions.yaml

DB2_JDBC_DRIVER_DIR=${CUR_DIR}/jdbc

PATTERN_SELECTED=""
COMPONENTS_SELECTED=""


function validate_cli(){
    which oc &>/dev/null
    [[ $? -ne 0 ]] && \
        echo "Unable to locate Openshift CLI, please install it first." && \
        exit 1

    which timeout &>/dev/null
    [[ $? -ne 0 ]] && \
        while true; do 
            printf "\x1B[1m\"timeout\" Command Not Found\n\x1B[0m"
            printf "\x1B[1mThe \"timeout\" will be installed automatically\n\x1B[0m"
            printf "\x1B[1mDo you accept (Yes/No, default: No): \x1B[0m" 
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_timeout_cli
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                echo -e "You do not accept, exiting...\n"
                exit 0
                ;;
            *)
                echo -e "\x1B[1;31mYou do not accept, exiting....\n\x1B[0m"
                exit 0
                ;;
            esac
        done
}

function install_timeout_cli(){
    if [[ ${machine} = "Mac" ]]; then
        echo -n "Installing timeout ......"; brew install coreutils >/dev/null 2>&1; sudo ln -s /usr/local/bin/gtimeout /usr/local/bin/timeout >/dev/null 2>&1; echo "done.";
    fi
    printf "\n"
 }

function prompt_license(){
    clear
    echo -e "\x1B[1;31mIMPORTANT: Review the IBM Cloud Pak for Automation license information here: \n\x1B[0m"
    echo -e "\x1B[1;31mhttps://github.com/icp4a/cert-kubernetes/blob/20.0.1/LICENSE\n\x1B[0m"
    read -rsn1 -p"Press any key to continue";echo
    while true; do
        printf "\n"
        printf "\n"
        printf "\x1B[1mDo you accept the IBM Cloud Pak for Automation license (Yes/No, default: No): \x1B[0m"
        cp -r ${OPERATOR_FILE_BAK} ${OPERATOR_FILE_TMP}
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            echo -e "Installing the Cloud Pak for Automation Operator...\n"
            validate_cli
            ${SED_COMMAND} '/dba_license/{n;s/value:/value: accept/;}' ${OPERATOR_FILE_TMP}
            # yaml set ${OPERATOR_FILE_BAK} spec.template.spec.containers.1.env.4.value accept > ${OPERATOR_FILE_TMP}
            cp -rf ${OPERATOR_FILE_TMP} ${OPERATOR_FILE_BAK}
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            echo -e "Exiting...\n"
            exit 0
            ;;
        *)
            echo -e "\x1B[1;31mYou did not accept the license, exiting...\n\x1B[0m"
            exit 0
            ;;
        esac
    done
}

function select_pattern(){
    # options=("FileNet Content Manager" "Automation Content Analyzer" "Operational Decision Manager" "Automation Workstream Services" "Automation Applications")

    # menu() {
    #     echo -e "\x1B[1mCloud Pak for Automation capabilities:\x1B[0m"
    #     for i in ${!options[@]}; do
    #         printf "%3d%s) %s\n" $((i+1)) "${choices_pattern[i]:- }" "${options[i]}"
    #     done
    #     if [[ "$msg" ]]; then echo "$msg"; fi
    # }

    # prompt="Check an pattern (again to uncheck, ENTER when done): "
    # while menu && read -rp "$prompt" num && [[ "$num" ]]; do
    #     [[ "$num" != *[![:digit:]]* ]] &&
    #     (( num > 0 && num <= ${#options[@]} )) ||
    #     { msg="Invalid option: $num"; continue; }
    #     ((num--)); msg="${options[num]} was ${choices_pattern[num]:+un}checked"
    #     [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="+"
    # done

    # printf "Pattern selected"; msg=" nothing"
    # for i in ${!options[@]}; do
    #     [[ "${choices_pattern[i]}" ]] && { printf " %s" "${options[i]}"; msg=""; }
    # done
    # echo "$msg"
    # export PATTERN_SELECTED="$msg"
    COLUMNS=12
    echo -e "\x1B[1mSelect the Cloud Pak for Automation capability to install: \x1B[0m"
    options=("FileNet Content Manager" "Automation Content Analyzer" "Operational Decision Manager" "Automation Workstream Services" "Automation Applications")
    PS3='Enter a valid option [1 to 5]: '
    select opt in "${options[@]}"
    do
        case $opt in
            "FileNet Content Manager")
                PATTERN_SELECTED=$opt
                break
                ;;
            "Automation Content Analyzer")
                PATTERN_SELECTED=$opt
                break
                ;;
            "Operational Decision Manager")
                PATTERN_SELECTED=$opt
                break
                ;;
            "Automation Workstream Services")
                PATTERN_SELECTED=$opt
                break
                ;;
            "Automation Applications")
                PATTERN_SELECTED=$opt
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}

function select_optional_component(){
# This function support mutiple checkbox, if do not select anything, it will return
    COMPONENTS_SELECTED=""
    COLUMNS=12
    menu_content(){
        options=("None" "Content Manager Interoperability Service (CMIS)")
        PS3="Enter a valid option [1 to ${#options[@]}]: "
        select opt in "${options[@]}"
        do
            case $opt in
                "None")
                    COMPONENTS_SELECTED="None"
                    break
                    ;;
                "Content Manager Interoperability Service (CMIS)")
                    COMPONENTS_SELECTED="cmis"
                    break
                    ;;
                *) echo "invalid option $REPLY";;
            esac
        done
    }
    menu_aca(){
        options=("None" "LDAP" "UMS")
        PS3="Enter a valid option [1 to ${#options[@]}]: "
        select opt in "${options[@]}" 
        do
            case $opt in
                "None")
                    COMPONENTS_SELECTED="None"
                    break
                    ;;
                "LDAP")
                    COMPONENTS_SELECTED="ldap"
                    break
                    ;;
                "UMS")
                    COMPONENTS_SELECTED="ums"
                    break
                    ;;
                *) echo "invalid option $REPLY";;
            esac
        done
    }
    while true; do
        case $PATTERN_SELECTED in
            "FileNet Content Manager")
                echo -e "\x1B[1m$PATTERN_SELECTED: Optional component(s) to deploy: \x1B[0m"
                menu_content
                break
                ;;
            "Automation Content Analyzer")
                echo -e "\x1B[1m$PATTERN_SELECTED: Optional component(s) to deploy: \x1B[0m"
                menu_aca
                break
                ;;
            *)
                # printf "\x1B[1mNone optional components for \"$PATTERN_SELECTED\"\n\x1B[0m"
                COMPONENTS_SELECTED="None"
                break
                ;;
        esac
    done
}

function get_local_registry_password(){
    printf "\n"
    printf "\x1B[1mEnter the password for your docker registry: \x1B[0m"
    local_registry_password=""
    while [[ $local_registry_password == "" ]]; # While confirmation is not y or n...
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
    local search_term='Pulling|is up to date|not found|no pull access'
    local result=$((timeout --preserve-status "$wait_time" docker 2>&1 pull "$image_full_name" &) | grep -v 'Pulling repository' | egrep -o "$search_term")
    test "$result" || { echo "Timed out too soon. Try using a wait_time greater than $wait_time..."; return 1 ;}
    echo $result | grep -vq 'not found'
    }

    # For Entitlement Registry key
    entitlement_key=""
    printf "\n"
    printf "\n"
    printf "\x1B[1;31mFollow the instructions on how to get your Entitlement Registry key: \n\x1B[0m"
    printf "\x1B[1;31mhttps://github.com/icp4a/cert-kubernetes/blob/20.0.1/platform/ocp/install.md\n\x1B[0m"
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
                        if  [[ $entitlement_key == iamapikey:* ]] ;
                        then
	                        if docker login -u "$DOCKER_REG_USER" -p "$DOCKER_REG_KEY" "$DOCKER_REG_SERVER"; then
	                            printf 'Entitlement Registry key is valid.\n'
	                            entitlement_verify_passed="passed"
	                        else
	                            printf '\x1B[1;31mThe Entitlement Registry key failed. Enter a valid Entitlement Registry key.\n\x1B[0m'
 	                            entitlement_key=''
	                            entitlement_verify_passed=""
	                            entitlement_verify_passed="failed" 
                            fi                              
                        else
	                        docker login -u "$DOCKER_REG_USER" -p "$DOCKER_REG_KEY" "$DOCKER_REG_SERVER" >/dev/null 2>&1
	                        docker_image_exists "${OPERATOR_IMAGE}"
	                        retVal=$?
	                        if [ $retVal -ne 0 ]; then 
	                            printf '\x1B[1;31mThe Entitlement Registry key failed. Enter a valid Entitlement Registry key.\n\x1B[0m'
	                            entitlement_key=''
	                            entitlement_verify_passed=""
	                            entitlement_verify_passed="failed"
	                        else 
	                            printf 'Entitlement Registry key is valid.\n'
	                            entitlement_verify_passed="passed"
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
    oc delete secret "$DOCKER_RES_SECRET_NAME" >/dev/null 2>&1
    CREATE_SECRET_CMD="oc create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$DOCKER_REG_SERVER --docker-username=$DOCKER_REG_USER --docker-password=$DOCKER_REG_KEY --docker-email=ecmtest@ibm.com"
    if $CREATE_SECRET_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1mFailed\x1B[0m"
    fi

}

function get_local_registry_server(){
    # For Local Registry Server
    printf "\n"

    printf "\x1B[1mEnter the OCP docker registry service name, for example: docker-registry.default.svc:5000/<project-name>\n\x1B[0m"
    printf "\x1B[1mor the URL to the docker registry, for example: abc.xyz.com: \x1B[0m"
    local_registry_server=""
    while [[ $local_registry_server == "" ]] # While confirmation is not y or n...
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
    while [[ $local_registry_user == "" ]] # While confirmation is not y or n...
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
    printf "\x1B[1menter the host name of your Infrastructure Node from\n\x1B[0m"
    printf "\x1B[1myour OpenShift Clould Platform environment: \x1B[0m"

    infra_name=""
    while [[ $infra_name == "" ]] # While confirmation is not y or n...
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
    printf "\n"
    printf "\x1B[1mTo provision the persistent volumes and volume claims, enter the dynamic storage classname: \x1B[0m"


    storage_class_name=""
    while [[ $storage_class_name == "" ]] # While confirmation is not y or n...
    do
       read -rp "" storage_class_name
       if [ -z "$storage_class_name" ]; then
       echo -e "\x1B[1;31mEnter a valid dynamic storage classname\x1B[0m"
       fi
    done
    export STORAGE_CLASS_NAME=${storage_class_name}

}

function allocate_operator_pvc(){
    # For dynamic storage classname
    printf "\n"
    echo -e "\x1B[1mApplying the persistent volumes for the Cloud Pak operator by using the storage classname: ${STORAGE_CLASS_NAME}...\x1B[0m"

    sed "s/<StorageClassName>/$STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_BAK} > ${OPERATOR_PVC_FILE_TMP} # &> /dev/null
    cp -rf ${OPERATOR_PVC_FILE_TMP} ${OPERATOR_PVC_FILE_BAK}
    # Create Operator Persistent Volume.
    CREATE_PVC_CMD="oc apply -f ${OPERATOR_PVC_FILE_TMP}"
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
    until oc get pvc | grep operator-shared-pvc | grep -q -m 1 "Bound" || [ $ATTEMPTS -eq $TIMEOUT ]; do
        ATTEMPTS=$((ATTEMPTS + 1))
        echo -e "......"
        sleep 10
        if [ $ATTEMPTS -eq $TIMEOUT ] ; then
            echo -e "\x1B[1;31mFailed to allocate the persistent volumes!\x1B[0m"
            echo -e "\x1B[1;31mRun the following command to check the claim 'oc describe pvc operator-shared-pvc'\x1B[0m"
            exit 1
        fi
    done
    if [ $ATTEMPTS -lt $TIMEOUT ] ; then
            echo -e "\x1B[1mDone\x1B[0m"
    fi
}

function show_summary(){

    printf "\n"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    echo -e "\x1B[1m                    Summary of input                   \x1B[0m"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    echo -e "\x1B[1;31m1. Cloud Pak capability to deploy: ${PATTERN_SELECTED}\x1B[0m"
    echo -e "\x1B[1;31m2. Optional components to deploy: ${COMPONENTS_SELECTED}\x1B[0m"
    echo -e "\x1B[1;31m3. Entitlement Registry key: ${DOCKER_REG_KEY}\x1B[0m"
    echo -e "\x1B[1;31m4. Docker registry service name or URL: ${LOCAL_REGISTRY_SERVER}\x1B[0m"
    echo -e "\x1B[1;31m5. Docker registry user name: ${LOCAL_REGISTRY_USER}\x1B[0m"
    # echo -e "\x1B[1;31m5. Docker registry password: ${LOCAL_REGISTRY_PWD}\x1B[0m"
    echo -e "\x1B[1;31m6. Docker registry password: \x1B[0m" # not show plaintext password
    echo -e "\x1B[1;31m7. OCP Infrastructure Node: ${INFRA_NAME}\x1B[0m"
    echo -e "\x1B[1;31m8. Dynamic storage classname: ${STORAGE_CLASS_NAME}\x1B[0m"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
}

function create_secret_local_registry(){
    echo -e "\x1B[1mCreating the secret based on the local docker registry information...\x1B[0m"
    # Create docker-registry secret for local Registry Key
    # echo -e "Create docker-registry secret for Local Registry...\n"
    oc delete secret "$DOCKER_RES_SECRET_NAME" >/dev/null 2>&1
    if [[ $LOCAL_REGISTRY_SERVER == docker-registry* ]] ;
    then
        CREATE_SECRET_CMD="oc create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$LOCAL_REGISTRY_SERVER --docker-username=$LOCAL_REGISTRY_USER --docker-password=$(oc whoami -t) --docker-email=ecmtest@ibm.com"
    else
        CREATE_SECRET_CMD="oc create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$LOCAL_REGISTRY_SERVER --docker-username=$LOCAL_REGISTRY_USER --docker-password=$LOCAL_REGISTRY_PWD --docker-email=ecmtest@ibm.com"    
    fi
    if $CREATE_SECRET_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi   
}

function verify_local_registry_password(){
    while [[ $verify_passed == "" ]]
    do
        get_local_registry_server
        get_local_registry_user
        get_local_registry_password
    
        if [[ $LOCAL_REGISTRY_SERVER == docker-registry* ]] ;
        then
            if docker login -u "$LOCAL_REGISTRY_USER" -p $(oc whoami -t) "$LOCAL_REGISTRY_SERVER"; then
                printf 'Verifying Local Registry passed...\n'
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
     done

}

function input_information(){

    select_pattern
    select_optional_component
    get_entitlement_registry

    if [ "$use_entitlement" = "no" ]; then
        verify_local_registry_password
    fi
    get_infra_name
    get_storage_class_name
}

function apply_cp4a_operator(){
    printf "\n"
    echo -e "\x1B[1mInstalling the Cloud Pak for Automation operator...\x1B[0m"
    # Set operator image pull secret
    ${SED_COMMAND} "s|admin.registrykey|$DOCKER_RES_SECRET_NAME|g" ${OPERATOR_FILE_TMP}
    # Set operator image registry
    new_operator="$REGISTRY_IN_FILE\/cp\/cp4a"

    if [ "$use_entitlement" = "yes" ] ; then
        ${SED_COMMAND} "s/$REGISTRY_IN_FILE/$DOCKER_REG_SERVER/g" ${OPERATOR_FILE_TMP}

    else
        ${SED_COMMAND} "s/$new_operator/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${OPERATOR_FILE_TMP}
    fi
    cp -rf ${OPERATOR_FILE_TMP} ${OPERATOR_FILE_BAK}

    oc delete -f ${OPERATOR_FILE_TMP} >/dev/null 2>&1
    sleep 5

    INSTALL_OPERATOR_CMD="oc apply -f ${OPERATOR_FILE_TMP}"
    if $INSTALL_OPERATOR_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi

    printf "\n"
    # Check deployment rollout status every 5 seconds (max 10 minutes) until complete.
    echo -e "\x1B[1mWaiting for the Cloud Pak operator to be ready. This might take a few minutes... \x1B[0m"
    ATTEMPTS=0
    ROLLOUT_STATUS_CMD="oc rollout status deployment/ibm-cp4a-operator"
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

function copy_db2_jdbc(){
    # Get pod name
    echo -e "\x1B[1mCopying the Db2 JDBC driver for the operator...\x1B[0m"
    operator_podname=$(oc get pod|grep ibm-cp4a-operator|grep Running|awk '{print $1}')
    COPY_JDBC_CMD="oc cp ${DB2_JDBC_DRIVER_DIR} ${operator_podname}:/opt/ansible/share/jdbc -c ansible"

    if $COPY_JDBC_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi
}
# Begin - Modify CONTENT pattern yaml according pattent/components selected
function apply_content_pattern_cr(){
    cp -r ${CONTENT_PATTERN_FILE_BAK} ${CONTENT_PATTERN_FILE_TMP}

    # Set sc_optional_components='' when none optional component selected
    if [ "$COMPONENTS_SELECTED" = "None" ]; then
        ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"\"|g" ${CONTENT_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"$COMPONENTS_SELECTED\"|g" ${CONTENT_PATTERN_FILE_TMP}
        content_start="$(grep -n "cmis:" ${CONTENT_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        content_stop="$(tail -n +$content_start < ${CONTENT_PATTERN_FILE_TMP} | grep -n "tag:" | head -n1 | cut -d: -f1)"
        content_stop=$(( $content_stop + $content_start - 1))
        vi ${CONTENT_PATTERN_FILE_TMP} -c ':'"${content_start}"','"${content_stop}"'s/^#/' -c ':wq'
    fi

    # Set sc_deployment_patterns=content
    ${SED_COMMAND} "s|sc_deployment_patterns:.*|sc_deployment_patterns: content|g" ${CONTENT_PATTERN_FILE_TMP}

    # Set sc_deployment_hostname_suffix
    ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}.${INFRA_NAME}\"|g" ${CONTENT_PATTERN_FILE_TMP}

    # Set sc_dynamic_storage_classname
    ${SED_COMMAND} "s|sc_dynamic_storage_classname:.*|sc_dynamic_storage_classname: ${storage_class_name}|g" ${CONTENT_PATTERN_FILE_TMP}

    old_fmcn="$REGISTRY_IN_FILE\/cp\/cp4a\/fncm"
    old_ban="$REGISTRY_IN_FILE\/cp\/cp4a\/ban"

    if [ "$use_entitlement" = "yes" ] ; then
        ${SED_COMMAND} "s/$REGISTRY_IN_FILE/$DOCKER_REG_SERVER/g" ${CONTENT_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s/$old_fmcn/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CONTENT_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ban/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CONTENT_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CONTENT_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ldap/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CONTENT_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2_etcd/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CONTENT_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_busybox/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${CONTENT_PATTERN_FILE_TMP}
    fi
    # cp -rf ${CONTENT_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}
    ${SED_COMMAND_FORMAT} ${CONTENT_PATTERN_FILE_TMP}
    cp -rf ${CONTENT_PATTERN_FILE_TMP} ${CONTENT_PATTERN_FILE_BAK}

    oc delete -f ${CONTENT_PATTERN_FILE_BAK} >/dev/null 2>&1
    sleep 5
    printf "\n"
    echo -e "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"

    APPLY_CONTENT_CMD="oc apply -f ${CONTENT_PATTERN_FILE_BAK}"

    if $APPLY_CONTENT_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi

    printf "\n"
    echo -e "\x1B[1mThe custom resource file used is: \"${CONTENT_PATTERN_FILE_BAK}\"\x1B[0m"

    printf "\n"
    echo -e "\x1B[1mTo monitor the deployment status, follow the Operator logs.  For details, refer to the troubleshooting section in Knowledge Center here: \x1B[0m"
    echo -e "\x1B[1mhttps://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_ca_troubleshoot.html\x1B[0m"
    
}
# End - Modify CONTENT pattern yaml according pattent/components selected

# Begin - Modify APPLICATION pattern yaml according pattent/components selected
function apply_application_pattern_cr(){
    cp -r ${APPLICATION_PATTERN_FILE_BAK} ${APPLICATION_PATTERN_FILE_TMP}
    # # Set sc_deployment_patterns=application
    # ${SED_COMMAND} "s|sc_deployment_patterns:.*|sc_deployment_patterns: application|g" ${APPLICATION_PATTERN_FILE_TMP}

    # Set sc_deployment_hostname_suffix
    ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}.${INFRA_NAME}\"|g" ${APPLICATION_PATTERN_FILE_TMP}

    # Set sc_dynamic_storage_classname
    ${SED_COMMAND} "s|sc_dynamic_storage_classname:.*|sc_dynamic_storage_classname: ${storage_class_name}|g" ${APPLICATION_PATTERN_FILE_TMP}

    # Set image_pull_secrets
    ${SED_COMMAND} "s|image-pull-secret|$DOCKER_RES_SECRET_NAME|g" ${APPLICATION_PATTERN_FILE_TMP}

    if [ "$use_entitlement" = "yes" ] ; then
        # new_docker_reg_server="$DOCKER_REG_SERVER\/cp\/cp4a\/fncm"
        ${SED_COMMAND} "s/cp.icr.io/$DOCKER_REG_SERVER/g" ${APPLICATION_PATTERN_FILE_TMP}
    else
        old_ums="cp.icr.io\/cp\/cp4a\/ums"
        old_aae="cp.icr.io\/cp\/cp4a\/aae"
        old_ban="cp.icr.io\/cp\/cp4a\/ban"
        old_bas="cp.icr.io\/cp\/cp4a\/bas"

        ${SED_COMMAND} "s/$old_ums/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${APPLICATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_aae/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${APPLICATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ban/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${APPLICATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_bas/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${APPLICATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${APPLICATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ldap/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${APPLICATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2_etcd/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${APPLICATION_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_busybox/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${APPLICATION_PATTERN_FILE_TMP}
    fi

    ${SED_COMMAND_FORMAT} ${APPLICATION_PATTERN_FILE_TMP}
    cp -rf ${APPLICATION_PATTERN_FILE_TMP} ${APPLICATION_PATTERN_FILE_BAK}

    oc delete -f ${APPLICATION_PATTERN_FILE_BAK} >/dev/null 2>&1
    sleep 5
    printf "\n"
    echo -e "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"
    # printf "\n"
    APPLY_APPLICATION_CMD="oc apply -f ${APPLICATION_PATTERN_FILE_BAK}"
    if $APPLY_APPLICATION_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi
    printf "\n"
    echo -e "\x1B[1mThe custom resource file used is: \"${APPLICATION_PATTERN_FILE_BAK}\"...\x1B[0m"
}
# End - Modify APPLICATION pattern yaml according pattent/components selected

# Begin - Modify Automation Content Analyzer pattern yaml according pattent/components selected
function apply_aca_pattern_cr(){
    cp -r ${ACA_PATTERN_FILE_BAK} ${ACA_PATTERN_FILE_TMP}
    # Set sc_optional_components='' when none optional component selected
    if [ "$COMPONENTS_SELECTED" = "None" ]; then
        ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"\"|g" ${ACA_PATTERN_FILE_TMP}
    else
        ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"$COMPONENTS_SELECTED\"|g" ${ACA_PATTERN_FILE_TMP}
    fi

    if [[ $COMPONENTS_SELECTED == *"ums"* ]]; then
        aca_start="$(grep -n "ums_configuration:" ${ACA_PATTERN_FILE_TMP} | head -n 1 | cut -d: -f1)"
        aca_stop="$(tail -n +$aca_start < ${ACA_PATTERN_FILE_TMP} | grep -n "tag:" | head -n1 | cut -d: -f1)"
        aca_stop=$(( $aca_stop + $aca_start - 1))

        vi ${ACA_PATTERN_FILE_TMP} -c ':'"${aca_start}"','"${aca_stop}"'s/^#/' -c ':wq'
    fi

    # Set sc_deployment_hostname_suffix
    ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}.${INFRA_NAME}\"|g" ${ACA_PATTERN_FILE_TMP}

    # Set sc_dynamic_storage_classname
    ${SED_COMMAND} "s|sc_dynamic_storage_classname:.*|sc_dynamic_storage_classname: ${storage_class_name}|g" ${ACA_PATTERN_FILE_TMP}

    if [ "$use_entitlement" = "yes" ] ; then
        ${SED_COMMAND} "s/cp.icr.io/$DOCKER_REG_SERVER/g" ${ACA_PATTERN_FILE_TMP}
    else
        old_ums="cp.icr.io\/cp\/cp4a\/ums"
        old_aca="cp.icr.io\/cp\/cp4a\/baca"

        ${SED_COMMAND} "s/$old_ums/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${ACA_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_aca/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${ACA_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${ACA_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ldap/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${ACA_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2_etcd/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${ACA_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_busybox/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${ACA_PATTERN_FILE_TMP}
    fi

    ${SED_COMMAND_FORMAT} ${ACA_PATTERN_FILE_TMP}
    cp -rf ${ACA_PATTERN_FILE_TMP} ${ACA_PATTERN_FILE_BAK}

    oc delete -f ${ACA_PATTERN_FILE_BAK} >/dev/null 2>&1
    sleep 5
    printf "\n"
    echo -e "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"

    APPLY_ACA_CMD="oc apply -f ${ACA_PATTERN_FILE_BAK}"
    if $APPLY_ACA_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi

    printf "\n"
    echo -e "\x1B[1mThe custom resource file used is: \"${ACA_PATTERN_FILE_BAK}\"...\x1B[0m"
}
# End - Modify Automation Content Analyzer pattern yaml according pattent/components selected

# Begin - Modify WORKSTREAMS pattern yaml according pattent/components selected
function apply_workstreams_pattern_cr(){
    cp -rf ${WORKSTREAMS_PATTERN_FILE_BAK} ${WORKSTREAMS_PATTERN_FILE_TMP}

    # Set sc_deployment_hostname_suffix
    ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}.${INFRA_NAME}\"|g" ${WORKSTREAMS_PATTERN_FILE_TMP}

    # Set sc_dynamic_storage_classname
    ${SED_COMMAND} "s|sc_dynamic_storage_classname:.*|sc_dynamic_storage_classname: ${storage_class_name}|g" ${WORKSTREAMS_PATTERN_FILE_TMP}

    # Set image_pull_secrets
    ${SED_COMMAND} "s|image-pull-secret|${DOCKER_RES_SECRET_NAME}|g" ${WORKSTREAMS_PATTERN_FILE_TMP}

    if [ "$use_entitlement" = "yes" ] ; then
        # new_docker_reg_server="$DOCKER_REG_SERVER\/cp\/cp4a\/fncm"
        ${SED_COMMAND} "s/cp.icr.io/$DOCKER_REG_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
    else
        old_ums="cp.icr.io\/cp\/cp4a\/ums"
        old_aae="cp.icr.io\/cp\/cp4a\/aae"
        old_ban="cp.icr.io\/cp\/cp4a\/ban"
        old_bas="cp.icr.io\/cp\/cp4a\/bas"
        old_fncm="cp.icr.io\/cp\/cp4a\/fncm"
        old_iaws="cp.icr.io\/cp\/cp4a\/iaws"

        ${SED_COMMAND} "s/$old_ums/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_aae/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ban/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_bas/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_fncm/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_iaws/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ldap/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2_etcd/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_busybox/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${WORKSTREAMS_PATTERN_FILE_TMP}
    fi

    ${SED_COMMAND_FORMAT} ${WORKSTREAMS_PATTERN_FILE_TMP}
    cp -rf ${WORKSTREAMS_PATTERN_FILE_TMP} ${WORKSTREAMS_PATTERN_FILE_BAK}

    oc delete -f ${WORKSTREAMS_PATTERN_FILE_BAK} >/dev/null 2>&1
    sleep 5
    printf "\n"
    echo -e "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"
    # printf "\n"
    APPLY_WORKSTREAMS_CMD="oc apply -f ${WORKSTREAMS_PATTERN_FILE_BAK}"
    if $APPLY_WORKSTREAMS_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi

    printf "\n"
    echo -e "\x1B[1mThe custom resource file used is: \"${WORKSTREAMS_PATTERN_FILE_BAK}\"...\x1B[0m"
}
# End - Modify WORKSTREAMS pattern yaml according pattent/components selected
# Begin - Modify DECISIONS pattern yaml according pattent/components selected
function apply_decisions_pattern_cr(){
    cp -rf ${DECISIONS_PATTERN_FILE_BAK} ${DECISIONS_PATTERN_FILE_TMP}
    # Set dba_license=accept
    ${SED_COMMAND} "s|dba_license:.*|dba_license: accept|g" ${DECISIONS_PATTERN_FILE_TMP}

    # Set sc_optional_components
    ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"\"|g" ${DECISIONS_PATTERN_FILE_TMP}

    # Set sc_deployment_hostname_suffix
    ${SED_COMMAND} "s|sc_deployment_hostname_suffix:.*|sc_deployment_hostname_suffix: \"{{ meta.namespace }}.${INFRA_NAME}\"|g" ${DECISIONS_PATTERN_FILE_TMP}

    # Set sc_dynamic_storage_classname
    ${SED_COMMAND} "s|sc_dynamic_storage_classname:.*|sc_dynamic_storage_classname: ${storage_class_name}|g" ${DECISIONS_PATTERN_FILE_TMP}

    # Set image_pull_secrets
    ${SED_COMMAND} "s|admin.registrykey|${DOCKER_RES_SECRET_NAME}|g" ${DECISIONS_PATTERN_FILE_TMP}

    if [ "$use_entitlement" = "yes" ] ; then

        ${SED_COMMAND} "s/cp.icr.io/$DOCKER_REG_SERVER/g" ${DECISIONS_PATTERN_FILE_TMP}

    else
        old_odm="cp.icr.io\/cp\/cp4a\/odm"

        ${SED_COMMAND} "s/$old_odm/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${DECISIONS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${DECISIONS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_ldap/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${DECISIONS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_db2_etcd/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${DECISIONS_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/$old_busybox/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${DECISIONS_PATTERN_FILE_TMP}
    fi

    ${SED_COMMAND_FORMAT} ${DECISIONS_PATTERN_FILE_TMP}
    cp -rf ${DECISIONS_PATTERN_FILE_TMP} ${DECISIONS_PATTERN_FILE_BAK}

    oc delete -f ${DECISIONS_PATTERN_FILE_BAK} >/dev/null 2>&1
    sleep 5
    printf "\n"
    echo -e "\x1B[1mInstalling the selected Cloud Pak capability...\x1B[0m"
    # printf "\n"
    APPLY_DECISIONS_CMD="oc apply -f ${DECISIONS_PATTERN_FILE_BAK}"
    if $APPLY_DECISIONS_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi

    printf "\n"
    echo -e "\x1B[1mThe custom resource file used is: \"${DECISIONS_PATTERN_FILE_BAK}\"...\x1B[0m"

}
# End - Modify DECISIONS pattern yaml according pattent/components selected

################################################
#### Begin - Main step for install operator ####
################################################
rm -rf $TMEP_FOLDER >/dev/null 2>&1
rm -rf $BAK_FOLDER >/dev/null 2>&1

mkdir -p $TMEP_FOLDER >/dev/null 2>&1
mkdir -p $BAK_FOLDER >/dev/null 2>&1
cp -rf "${OPERATOR_FILE}" "${OPERATOR_FILE_BAK}"
cp -rf "${OPERATOR_PVC_FILE}" "${OPERATOR_PVC_FILE_BAK}"
cp -rf "${CONTENT_PATTERN_FILE}" "${CONTENT_PATTERN_FILE_BAK}"
cp -rf "${APPLICATION_PATTERN_FILE}" "${APPLICATION_PATTERN_FILE_BAK}"
cp -rf "${ACA_PATTERN_FILE}" "${ACA_PATTERN_FILE_BAK}"
cp -rf "${WORKSTREAMS_PATTERN_FILE}" "${WORKSTREAMS_PATTERN_FILE_BAK}"
cp -rf "${DECISIONS_PATTERN_FILE}" "${DECISIONS_PATTERN_FILE_BAK}"

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

        if [ "$use_entitlement" = "no" ] ; then
            create_secret_local_registry
        else
            create_secret_entitlement_registry
        fi
        allocate_operator_pvc
        apply_cp4a_operator
        copy_db2_jdbc
        case $PATTERN_SELECTED in
            "FileNet Content Manager")
                apply_content_pattern_cr
                break
                ;;
            "Automation Content Analyzer")
                apply_aca_pattern_cr
                break
                ;;
            "Operational Decision Manager")
                apply_decisions_pattern_cr
                break
                ;;
            "Automation Applications")
                apply_application_pattern_cr
                break
                ;;
            "Automation Workstream Services")
                apply_workstreams_pattern_cr
                break
                ;;
        esac
        break
        ;;
    "n"|"N"|"no"|"No"|"NO"|*)
        while true; do
            printf "\n"
            show_summary
            printf "\n"
            printf "\x1B[1mEnter the number from 1 to 8 that you want to change: \x1B[0m"
            read -rp "" ans
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
        done
        show_summary
        ;;
    esac
done
################################################
#### End - Main step for install operator ####
################################################
