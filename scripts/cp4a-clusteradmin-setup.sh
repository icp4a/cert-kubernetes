#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh
RUNTIME_MODE=$1

TEMP_FOLDER=${CUR_DIR}/.tmp
INSTALL_BAI=""
CRD_FILE=${PARENT_DIR}/descriptors/ibm_cp4a_crd.yaml
SA_FILE=${PARENT_DIR}/descriptors/service_account.yaml
# CLUSTER_ROLE_FILE=${PARENT_DIR}/descriptors/cluster_role.yaml
# CLUSTER_ROLE_BINDING_FILE=${PARENT_DIR}/descriptors/cluster_role_binding.yaml
# CLUSTER_ROLE_BINDING_FILE_TEMP=${TEMP_FOLDER}/.cluster_role_binding.yaml
ROLE_FILE=${PARENT_DIR}/descriptors/role.yaml
ROLE_BINDING_FILE=${PARENT_DIR}/descriptors/role_binding.yaml
BRONZE_STORAGE_CLASS=${PARENT_DIR}/descriptors/cp4a-bronze-storage-class.yaml
SILVER_STORAGE_CLASS=${PARENT_DIR}/descriptors/cp4a-silver-storage-class.yaml
GOLD_STORAGE_CLASS=${PARENT_DIR}/descriptors/cp4a-gold-storage-class.yaml
LOG_FILE=${CUR_DIR}/prepare_install.log
PLATFORM_SELECTED=""
PLATFORM_VERSION=""
PROJ_NAME=""
DOCKER_RES_SECRET_NAME="admin.registrykey"
REGISTRY_IN_FILE="cp.icr.io"
OPERATOR_FILE=${PARENT_DIR}/descriptors/operator.yaml
OPERATOR_FILE_TMP=$TEMP_FOLDER/.operator_tmp.yaml

OPERATOR_PVC_FILE=${PARENT_DIR}/descriptors/operator-shared-pvc.yaml
OPERATOR_PVC_FILE_TMP1=${TEMP_FOLDER}/.operator-shared-pvc_tmp1.yaml
OPERATOR_PVC_FILE_TMP=${TEMP_FOLDER}/.operator-shared-pvc_tmp.yaml
OPERATOR_PVC_FILE_BAK=${TEMP_FOLDER}/.operator-shared-pvc.yaml
JDBC_DRIVER_DIR=${CUR_DIR}/jdbc

COMMON_SERVICES_CRD_DIRECTORY_OCP311=${PARENT_DIR}/descriptors/common-services/scripts
COMMON_SERVICES_CRD_DIRECTORY=${PARENT_DIR}/descriptors/common-services/crds
COMMON_SERVICES_OPERATOR_ROLES=${PARENT_DIR}/descriptors/common-services/roles
COMMON_SERVICES_TEMP_DIR=$TMEP_FOLDER

mkdir -p $TEMP_FOLDER >/dev/null 2>&1
echo "creating temp folder"
# During the development cycle we will need to apply cp4a_catalogsource.yaml
# catalog_source.yaml is the final deliver yaml.
if [[ $RUNTIME_MODE == "dev" ]];then
    OLM_CATALOG=${PARENT_DIR}/descriptors/op-olm/cp4a_catalogsource.yaml
else
    OLM_CATALOG=${PARENT_DIR}/descriptors/op-olm/catalog_source.yaml
fi

# the source is different for stage of development and final public
if [[ $RUNTIME_MODE == "dev" ]]; then
    online_source="ibm-cp4a-operator-catalog"
else
    online_source="ibm-operator-catalog"
fi

OLM_OPT_GROUP=${PARENT_DIR}/descriptors/op-olm/operator_group.yaml
OLM_SUBSCRIPTION=${PARENT_DIR}/descriptors/op-olm/subscription.yaml

OLM_CATALOG_TMP=${TEMP_FOLDER}/.catalog_source.yaml
OLM_OPT_GROUP_TMP=${TEMP_FOLDER}/.operator_group.yaml
OLM_SUBSCRIPTION_TMP=${TEMP_FOLDER}/.subscription.yaml


echo '' > $LOG_FILE

function validate_cli(){
    clear
    if [[ $SCRIPT_MODE == "OLM" ]];then
        echo -e "\x1B[1mThis script prepares the OLM for the deployment of some Cloud Pak for Business Automation capabilities \x1B[0m"
    else
        echo -e "\x1B[1mThis script prepares the environment for the deployment of some Cloud Pak for Business Automation capabilities \x1B[0m"
    fi
    echo
    if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]]; then
        which oc &>/dev/null
        [[ $? -ne 0 ]] && \
            echo "Unable to locate an OpenShift CLI. You must install it to run this script." && \
            exit 1
    fi
    if  [[ $PLATFORM_SELECTED == "other" ]]; then
        which kubectl &>/dev/null
        [[ $? -ne 0 ]] && \
            echo "Unable to locate Kubernetes CLI, please install it first." && \
            exit 1
    fi
}

function collect_input() {
    project_name=""
    while [[ $project_name == "" ]]; 
    do
       echo
       read -p "Enter the name for a new project or an existing project (namespace): " project_name
       if [ -z "$project_name" ]; then
           echo -e "\x1B[1;31mEnter a valid project name, project name can not be blank\x1B[0m"
       elif [[ "$project_name" == openshift* ]]; then
           echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
           project_name=""
       elif [[ "$project_name" == kube* ]]; then
           echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
           project_name=""
       else
           create_project
       fi
    done
    if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS" ]]; then
        user_name=""
        select_user
    fi
}

function create_project() {

    if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS" ]]; then
        isProjExists=`${CLI_CMD} get project $project_name --ignore-not-found | wc -l`  >/dev/null 2>&1

        if [ $isProjExists -ne 2 ] ; then
            ${CLI_CMD} new-project ${project_name} >> ${LOG_FILE}
            returnValue=$?
            if [ "$returnValue" == 1 ]; then
                echo -e "\x1B[1mInvalid project name, please enter a valid name...\x1B[0m"
                project_name=""
            else
                echo -e "\x1B[1mUsing project ${project_name}...\x1B[0m"
            fi
        else
            echo -e "\x1B[1mProject \"${project_name}\" already exists! Continue...\x1B[0m"
        fi
    elif [[ "$PLATFORM_SELECTED" == "other" ]]
    then
        isProjExists=`kubectl get namespace $project_name --ignore-not-found | wc -l`  >/dev/null 2>&1

        if [ $isProjExists -ne 2 ] ; then
            kubectl create namespace ${project_name} >> ${LOG_FILE}
            returnValue=$?
            if [ "$returnValue" == 1 ]; then
                echo -e "\x1B[1mInvalid namespace, please enter a valid name...\x1B[0m"
                project_name=""
            else
                echo -e "\x1B[1mUsing namespace ${project_name}...\x1B[0m"
            fi
        else
            echo -e "\x1B[1mName space \"${project_name}\" already exists! Continue...\x1B[0m"
        fi
    fi
    PROJ_NAME=${project_name}
}

function check_user_exist() {
    ${CLI_CMD} get user | grep "${user_name}" >/dev/null 2>&1
    returnValue=$?
    if [ "$returnValue" == 1 ] ; then
        echo -e "\x1B[1mUser \"${user_name}\" NOT exists! Please enter an existing username in your cluster...\x1B[0m"
        user_name=""
    else
        echo -e "\x1B[1mUser \"${user_name}\" exists! Continue...\x1B[0m"
    fi
}

function bind_scc() {
    echo
    echo -ne Binding the 'privileged' role to the 'default' service account...
    dba_scc=$(${CLI_CMD} get scc privileged | awk '{print $1}' )
    if [ -n "$dba_scc" ]; then
        ${CLI_CMD} adm policy add-scc-to-user privileged -z default  >>  ${LOG_FILE}
    else
        echo "The 'privileged' security context constraint (SCC) does not exist in the cluster. Make sure that you update your environment to include this SCC."
        exit 1
    fi
    echo "Done"
}

function prepare_install() {
    if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS" ]]; then
        ${CLI_CMD} project ${project_name} >> ${LOG_FILE}
    fi
    # sed -e "s/<NAMESPACE>/${project_name}/g" ${CLUSTER_ROLE_BINDING_FILE} > ${CLUSTER_ROLE_BINDING_FILE_TEMP}
    echo
    echo -ne "Creating the custom resource definition (CRD) and a service account that has the permissions to manage the resources..."
    ${CLI_CMD} apply -f ${CRD_FILE} -n ${project_name} --validate=false >/dev/null 2>&1
    echo " Done!"
    # if [[ "$DEPLOYMENT_TYPE" == "demo" ]];then
    #     ${CLI_CMD} apply -f ${CLUSTER_ROLE_FILE} --validate=false >> ${LOG_FILE}
    #     ${CLI_CMD} apply -f ${CLUSTER_ROLE_BINDING_FILE_TEMP} --validate=false >> ${LOG_FILE}
    # fi
    ${CLI_CMD} apply -f ${SA_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
    ${CLI_CMD} apply -f ${ROLE_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
    
    echo -n "Creating ibm-cp4a-operator role ..."
    while true ; do
        result=$(${CLI_CMD} get role -n $project_name| grep ibm-cp4a-operator)
        if [[ "$result" == "" ]] ; then
            sleep 5
            echo -n "..."
        else
            echo " Done!"
            break    
        fi
    done   
    echo -n "Creating ibm-cp4a-operator role binding ..."
    ${CLI_CMD} apply -f ${ROLE_BINDING_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
        echo "Done!"
        if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS" ]]; then
        echo
        echo -ne Adding the user ${user_name} to the ibm-cp4a-operator role...
        ${CLI_CMD} project ${project_name} >> ${LOG_FILE}
        ${CLI_CMD} adm policy add-role-to-user edit ${user_name} >> ${LOG_FILE}
        ${CLI_CMD} adm policy add-role-to-user registry-editor ${user_name} >> ${LOG_FILE}
        ${CLI_CMD} adm policy add-role-to-user ibm-cp4a-operator ${user_name} >/dev/null 2>&1
        ${CLI_CMD} adm policy add-role-to-user ibm-cp4a-operator ${user_name} >> ${LOG_FILE}
        if [[ "$DEPLOYMENT_TYPE" == "demo" ]];then
            ${CLI_CMD} adm policy add-cluster-role-to-user ibm-cp4a-operator ${user_name} >> ${LOG_FILE}
        fi
        echo "Done!"
    fi
    echo
    echo -ne Label the default namespace to allow network policies to open traffic to the ingress controller using a namespaceSelector...
    ${CLI_CMD} label --overwrite namespace default 'network.openshift.io/policy-group=ingress'
    echo "Done!"
}


function apply_cp4a_operator(){
    ${COPY_CMD} -rf ${OPERATOR_FILE} ${OPERATOR_FILE_TMP}

    printf "\n"
    if [[ ("$SCRIPT_MODE" != "review") && ("$SCRIPT_MODE" != "OLM") ]]; then
        echo -e "\x1B[1mInstalling the Cloud Pak for Business Automation operator...\x1B[0m"
    fi
    # set db2_license
    ${SED_COMMAND} '/baw_license/{n;s/value:.*/value: accept/;}' ${OPERATOR_FILE_TMP}
    # Set operator image pull secret
    ${SED_COMMAND} "s|admin.registrykey|$DOCKER_RES_SECRET_NAME|g" ${OPERATOR_FILE_TMP}
    # Set operator image registry
    new_operator="$REGISTRY_IN_FILE\/cp\/cp4a"

    if [ "$use_entitlement" = "yes" ] ; then
        ${SED_COMMAND} "s/$REGISTRY_IN_FILE/$DOCKER_REG_SERVER/g" ${OPERATOR_FILE_TMP}
    else
        ${SED_COMMAND} "s/$new_operator/$CONVERT_LOCAL_REGISTRY_SERVER/g" ${OPERATOR_FILE_TMP}
    fi
    # if [[ "${OCP_VERSION}" == "3.11" ]];then
    #     ${SED_COMMAND} "s/\# runAsUser\: 1001/runAsUser\: 1001/g" ${OPERATOR_FILE_TMP}
    # fi

    # if [[ $INSTALLATION_TYPE == "new" ]]; then
    #     ${CLI_CMD} delete -f ${OPERATOR_FILE_TMP} >/dev/null 2>&1
    #     sleep 5
    # fi
    INSTALL_OPERATOR_CMD="${CLI_CMD} apply -f ${OPERATOR_FILE_TMP} -n $project_name"
    sleep 5
    if $INSTALL_OPERATOR_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi

    # ${COPY_CMD} -rf ${OPERATOR_FILE_TMP} ${OPERATOR_FILE_BAK}
    printf "\n"
    # Check deployment rollout status every 5 seconds (max 10 minutes) until complete.
    echo -e "\x1B[1mWaiting for the Cloud Pak operator to be ready. This might take a few minutes... \x1B[0m"
    ATTEMPTS=0
    ROLLOUT_STATUS_CMD="${CLI_CMD} rollout status deployment/ibm-cp4a-operator -n $project_name"
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

function prepare_olm_install() {
    local maxRetry=20

    if ${CLI_CMD} get catalogsource -n openshift-marketplace | grep $online_source; then
        echo "Found existing ibm operator catalog source, updating it"
        ${CLI_CMD} apply -f $OLM_CATALOG
        if [ $? -eq 0 ]; then
          echo "IBM Operator Catalog source updated!"
        else
          echo "Generic Operator catalog source update failed"
          exit 1
        fi  
    else
        ${CLI_CMD} apply -f $OLM_CATALOG
        if [ $? -eq 0 ]; then
          echo "IBM Operator Catalog source created!"
        else
          echo "Generic Operator catalog source creation failed"
          exit 1
        fi
    fi

    for ((retry=0;retry<=${maxRetry};retry++)); do        
      echo "Waiting for CP4A Operator Catalog pod initialization"         
       
      isReady=$(${CLI_CMD} get pod -n openshift-marketplace --no-headers | grep $online_source | grep "Running")
      if [[ -z $isReady ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then 
          echo "Timeout Waiting for  CP4BA Operator Catalog pod to start"
          exit 1
        else
          sleep 15
          continue
        fi
      else
        echo "CP4BA Operator Catalog is running $isReady"
        break
      fi
    done

    if [[ $(${CLI_CMD} get og -n "${project_name}" -o=go-template --template='{{len .items}}' ) -gt 0 ]]; then
        echo "Found operator group"
        ${CLI_CMD} get og -n "${project_name}"
    else
      sed "s/REPLACE_NAMESPACE/$project_name/g" ${OLM_OPT_GROUP} > ${OLM_OPT_GROUP_TMP}
      ${CLI_CMD} apply -f ${OLM_OPT_GROUP_TMP}
      if [ $? -eq 0 ]
         then
         echo "CP4BA Operator Group Created!"
       else
         echo "CP4BA Operator Operator Group creation failed"
       fi
    fi

    sed "s/REPLACE_NAMESPACE/$project_name/g" ${OLM_SUBSCRIPTION} > ${OLM_SUBSCRIPTION_TMP}
    ${YQ_CMD} w -i ${OLM_SUBSCRIPTION_TMP} spec.source "$online_source"
    ${CLI_CMD} apply -f ${OLM_SUBSCRIPTION_TMP}
    # sed <"${OLM_SUBSCRIPTION}" "s|REPLACE_NAMESPACE|${project_name}|g; s|REPLACE_CHANNEL_NAME|stable|g" | oc apply -f -
    if [ $? -eq 0 ]
        then
        echo "CP4BA Operator Subscription Created!"
    else
        echo "CP4BA Operator Subscription creation failed"
        exit 1
    fi

   for ((retry=0;retry<=${maxRetry};retry++)); do        
      echo "Waiting for CP4BA operator pod initialization"         
       
      isReady=$(${CLI_CMD} get pod -n "$project_name" --no-headers | grep ibm-cp4a-operator | grep "Running")
      if [[ -z $isReady ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then 
          echo "Timeout Waiting for CP4BA operator to start"
          exit 1
        else
          sleep 15
          continue
        fi
      else
        echo "CP4A operator is running $isReady"
        if [[ "$DEPLOYMENT_TYPE" == "enterprise" && "$RUNTIME_MODE" == "dev" ]]; then
            copy_jdbc_driver
        fi
        break
      fi
    done

    echo
    echo -ne Adding the user ${user_name} to the ibm-cp4a-operator role...
    role_name_olm=$(${CLI_CMD} get role -n "$project_name" --no-headers|grep ibm-cp4a-operator.v|awk '{print $1}')
    if [[ -z $role_name_olm ]]; then
        echo "No role found for CP4BA operator"
        exit 1     
    else
        ${CLI_CMD} project ${project_name} >> ${LOG_FILE}
        ${CLI_CMD} adm policy add-role-to-user edit ${user_name} >> ${LOG_FILE}
        ${CLI_CMD} adm policy add-role-to-user registry-editor ${user_name} >> ${LOG_FILE}
        ${CLI_CMD} adm policy add-role-to-user $role_name_olm ${user_name} >/dev/null 2>&1
        ${CLI_CMD} adm policy add-role-to-user $role_name_olm ${user_name} >> ${LOG_FILE}
        if [[ "$DEPLOYMENT_TYPE" == "demo" ]];then
            cluster_role_name_olm=$(${CLI_CMD} get clusterrole|grep ibm-cp4a-operator.v|sort -t"t" -k1r|awk 'NR==1{print $1}')
            if [[ -z $cluster_role_name_olm ]]; then
                echo "No cluster role found for CP4BA operator"
                exit 1     
            else
                ${CLI_CMD} adm policy add-cluster-role-to-user $cluster_role_name_olm ${user_name} >> ${LOG_FILE}
            fi
        fi
        echo "Done!"
    fi

    echo
    echo -ne Label the default namespace to allow network policies to open traffic to the ingress controller using a namespaceSelector...
    ${CLI_CMD} label --overwrite namespace default 'network.openshift.io/policy-group=ingress'
    echo "Done"
}

function check_existing_sc(){
# Check existing storage class
    sc_result=$(${CLI_CMD} get sc 2>&1)

    sc_substring="No resources found"
    if [[ $sc_result == *"$sc_substring"* ]];
    then
        clear
        echo -e "\x1B[1;31mAt least one dynamic storage class must be available in order to proceed.\n\x1B[0m" 
        echo -e "\x1B[1;31mPlease refer to the README for the requirements and instructions.  The script will now exit!.\n\x1B[0m" 
        exit 1 
    fi
}

function validate_docker_podman_cli(){
    if [[ "$machine" == "Mac" || $PLATFORM_SELECTED == "other" ]];then
        which docker &>/dev/null
        [[ $? -ne 0 ]] && \
            echo -e  "\x1B[1;31mUnable to locate docker, please install it first.\x1B[0m" && \
            exit 1
    elif [[ $OCP_VERSION == "4.4OrLater" ]]
    then
        which podman &>/dev/null
        [[ $? -ne 0 ]] && \
            echo -e "\x1B[1;31mUnable to locate podman, please install it first.\x1B[0m" && \
            exit 1
    fi
}


function get_entitlement_registry(){

    # docker_image_exists() {
    # local image_full_name="$1"; shift
    # local wait_time="${1:-5}"
    # local search_term='Pulling|Copying|is up to date|already exists|not found|unable to pull image|no pull access'
    # if [[ $OCP_VERSION == "3.11" ]];then
    #     local result=$((timeout --preserve-status "$wait_time" docker 2>&1 pull "$image_full_name" &) | grep -v 'Pulling repository' | egrep -o "$search_term")

    # elif [[ $OCP_VERSION == "4.4OrLater" ]]
    # then
    #     local result=$((timeout --preserve-status "$wait_time" podman 2>&1 pull "$image_full_name" &) | grep -v 'Pulling repository' | egrep -o "$search_term")

    # fi
    # test "$result" || { echo "Timed out too soon. Try using a wait_time greater than $wait_time..."; return 1 ;}
    # echo $result | grep -vq 'not found'
    # }

    # For Entitlement Registry key
    entitlement_key=""
    printf "\n"
    printf "\n"
    printf "\x1B[1;31mFollow the instructions on how to get your Entitlement Key: \n\x1B[0m"
    printf "\x1B[1;31mhttps://www.ibm.com/support/knowledgecenter/en/SSYHZ8_21.0.x/com.ibm.dba.install/op_topics/tsk_images_enterp_entitled.html\n\x1B[0m"
    printf "\n"
    while true; do
        printf "\x1B[1mDo you have a Cloud Pak for Business Automation Entitlement Registry key (Yes/No, default: No): \x1B[0m"
        read -rp "" ans

        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            use_entitlement="yes"
            printf "\n"
            printf "\x1B[1mEnter your Entitlement Registry key: \x1B[0m"
            # During dev, OLM uses stage image repo
            if [[ "$RUNTIME_MODE" == "dev" ]]
            then
                DOCKER_REG_SERVER="cp.stg.icr.io"
            else
                DOCKER_REG_SERVER="cp.icr.io"
            fi
            # During dev, OLM uses stage image repo
            while [[ $entitlement_key == '' ]]
            do
                read -rsp "" entitlement_key
                if [ -z "$entitlement_key" ]; then
                    printf "\n"
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
                        printf "\n"
                        printf "\x1B[1mVerifying the Entitlement Registry key...\n\x1B[0m"

                        if [[ "$machine" == "Mac" ]]; then
                        cli_command="docker"
                        else
                        cli_command="podman"
                        fi

                        if $cli_command login -u "$DOCKER_REG_USER" -p "$DOCKER_REG_KEY" "$DOCKER_REG_SERVER"; then
                            printf 'Entitlement Registry key is valid.\n'
                            entitlement_verify_passed="passed"
                        else
                            printf '\x1B[1;31mThe Entitlement Registry key failed.\n\x1B[0m'
                            printf '\x1B[1mEnter a valid Entitlement Registry key.\n\x1B[0m'
                            entitlement_key=''
                            entitlement_verify_passed="failed"
                        fi
                    done
                fi
            done
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            use_entitlement="no"
            DOCKER_REG_KEY="None"
            if [[ "$PLATFORM_SELECTED" == "ROKS" || "$PLATFORM_SELECTED" == "OCP" ]]; then
                printf "\n"
                printf "\x1B[1;31mIBM Cloud Pak® for Business Automation only supports the Entitlement Registry on \"${PLATFORM_SELECTED}\", exiting...\n\x1B[0m"
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
    # Create docker-registry secret for Entitlement Registry Key in target project
    printf "\x1B[1mCreating docker-registry secret for Entitlement Registry key in project $project_name...\n\x1B[0m"  

    ${CLI_CMD} delete secret "$DOCKER_RES_SECRET_NAME" -n "${project_name}" >/dev/null 2>&1
    CREATE_SECRET_CMD="${CLI_CMD} create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$DOCKER_REG_SERVER --docker-username=$DOCKER_REG_USER --docker-password=$DOCKER_REG_KEY --docker-email=ecmtest@ibm.com -n $project_name"
    if $CREATE_SECRET_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1mFailed\x1B[0m"
    fi
}

function get_storage_class_name(){
    if [[ $PLATFORM_SELECTED == "other" || $PLATFORM_SELECTED == "OCP" ]]; then
        check_existing_sc
    fi
    check_storage_class
    # For dynamic storage classname
    storage_class_name=""
    sc_slow_file_storage_classname=""
    sc_medium_file_storage_classname=""
    sc_fast_file_storage_classname=""
    printf "\n"
    if [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other" ]] ;
    then
        printf "\x1B[1mTo provision the persistent volumes and volume claims, enter the dynamic storage classname: \x1B[0m"

        while [[ $storage_class_name == "" ]]
        do
            read -rp "" storage_class_name
            if [ -z "$storage_class_name" ]; then
               echo -e "\x1B[1;31mEnter a valid dynamic storage classname\x1B[0m"
            fi
        done
    elif [[ $PLATFORM_SELECTED == "ROKS" ]]
    then
        printf "\x1B[1mTo provision the persistent volumes and volume claims\n\x1B[0m"

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
    SLOW_STORAGE_CLASS_NAME=${sc_fast_file_storage_classname}
    MEDIUM_STORAGE_CLASS_NAME=${sc_fast_file_storage_classname}
    FAST_STORAGE_CLASS_NAME=${sc_fast_file_storage_classname}
}


function copy_jdbc_driver(){
    # Get pod name
    echo -e "\x1B[1mCopying the JDBC driver for the operator...\x1B[0m"
    operator_podname=$(${CLI_CMD} get pod -n $project_name|grep ibm-cp4a-operator|grep Running|awk '{print $1}')

    # ${CLI_CMD} exec -it ${operator_podname} -- rm -rf /opt/ansible/share/jdbc
    COPY_JDBC_CMD="${CLI_CMD} cp ${JDBC_DRIVER_DIR} ${operator_podname}:/opt/ansible/share/"

    if $COPY_JDBC_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi
}

function allocate_operator_pvc_olm_or_cncf(){
    # For dynamic storage classname
    printf "\n"
    if [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other" ]]; then
        echo -e "\x1B[1mApplying the persistent volumes for the Cloud Pak operator by using the storage classname: ${STORAGE_CLASS_NAME}...\x1B[0m"
        ${COPY_CMD} -rf "${OPERATOR_PVC_FILE}" "${OPERATOR_PVC_FILE_BAK}"
        printf "\n"
        sed "s/<StorageClassName>/$STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_BAK} > ${OPERATOR_PVC_FILE_TMP1}
        sed "s/<Fast_StorageClassName>/$STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_TMP1}  > ${OPERATOR_PVC_FILE_TMP} # &> /dev/null
    else
        echo -e "\x1B[1mApplying the persistent volumes for the Cloud Pak operator by using the storage classname: ${FAST_STORAGE_CLASS_NAME}...\x1B[0m"
        ${COPY_CMD} -rf "${OPERATOR_PVC_FILE}" "${OPERATOR_PVC_FILE_BAK}"
        printf "\n"
        sed "s/<StorageClassName>/$FAST_STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_BAK} > ${OPERATOR_PVC_FILE_TMP1}
        sed "s/<Fast_StorageClassName>/$FAST_STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_TMP1}  > ${OPERATOR_PVC_FILE_TMP} # &> /dev/null    
    fi
    # ${COPY_CMD} -rf ${OPERATOR_PVC_FILE_TMP} ${OPERATOR_PVC_FILE_BAK}
    # Create Operator Persistent Volume.
    CREATE_PVC_CMD="${CLI_CMD} apply -f ${OPERATOR_PVC_FILE_TMP} -n $project_name"
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
    until ${CLI_CMD} get pvc -n $project_name| grep cp4a-shared-log-pvc| grep -q -m 1 "Bound" || [ $ATTEMPTS -eq $TIMEOUT ]; do
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

function display_storage_classes() {
    echo
    echo "Storage classes are needed to run the deployment script. For the "Demo" deployment scenario, you may use one (1) storage class.  For an "Enterprise" deployment, the deployment script will ask for three (3) storage classes to meet the "slow", "medium", and "fast" storage for the configuration of CP4A components.  If you don't have three (3) storage classes, you can use the same one for "slow", "medium", or fast.  Note that you can get the existing storage class(es) in the environment by running the following command: oc get storageclass. Take note of the storage classes that you want to use for deployment. "
	${CLI_CMD} get storageclass
}


function display_node_name() {
    echo
    if  [[ $PLATFORM_VERSION == "3.11" ]];
    then
        echo "Below is the host name of the Infrastructure Node for the environment, which is required as an input during the execution of the deployment script for the creation of routes in OCP.  You can also get the host name by running the following command: ${CLI_CMD} get nodes --selector node-role.kubernetes.io/infra=true -o custom-columns=":metadata.name". Take note of the host name. "
	${CLI_CMD} get nodes --selector node-role.kubernetes.io/infra=true -o custom-columns=":metadata.name"
    elif  [[ $PLATFORM_VERSION == "4.4OrLater" ]];
    then
        echo "Below is the route host name for the environment, which is required as an input during the execution of the deployment script for the creation of routes in OCP. You can also get the host name by running the following command: oc get route console -n openshift-console -o yaml|grep routerCanonicalHostname. Take note of the host name. "
        ${CLI_CMD} get route console -n openshift-console -o yaml|grep routerCanonicalHostname | head -1 | cut -d ' ' -f 6
    fi
}


function create_scc() {
    ${CLI_CMD} create serviceaccount ibm-pfs-es-service-account
    ${CLI_CMD} create -f ibm-pfs-privileged-scc.yaml
    ${CLI_CMD} adm policy add-scc-to-user ibm-pfs-privileged-scc -z ibm-pfs-es-service-account
}


function clean_up(){
    rm -rf ${TEMP_FOLDER} >/dev/null 2>&1
}


function select_platform(){
    printf "\n"
    COLUMNS=12
    echo -e "\x1B[1mSelect the cloud platform to deploy: \x1B[0m"
    options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud" "Other ( Certified Kubernetes Cloud Platform / CNCF)")
    PS3='Enter a valid option [1 to 3]: '
    # if [[ "${SCRIPT_MODE}" == "OLM" ]]; then
    #     options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
    #     PS3='Enter a valid option [1 to 2]: '
    # else
    #     options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud" "Other ( Certified Kubernetes Cloud Platform / CNCF)")
    #     PS3='Enter a valid option [1 to 3]: '
    # fi
    select opt in "${options[@]}"
    do
        case $opt in
            "RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud")
                PLATFORM_SELECTED="ROKS"
                SCRIPT_MODE="OLM"
                break
                ;;
            "Openshift Container Platform (OCP) - Private Cloud")
                PLATFORM_SELECTED="OCP"
                SCRIPT_MODE="OLM"
                break
                ;;
            "Other ( Certified Kubernetes Cloud Platform / CNCF)")
                PLATFORM_SELECTED="other"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
    if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS" ]]; then
        CLI_CMD=oc
    elif [[ "$PLATFORM_SELECTED" == "other" ]]
    then
        CLI_CMD=kubectl
    fi
}


function select_deployment_type(){
    COLUMNS=12
    echo -e "\x1B[1mWhat type of deployment is being performed?\x1B[0m"
    if  [[ $PLATFORM_SELECTED == "other" ]];
    then
        options=("Enterprise")
        PS3='Enter a valid option [1 to 1]: '
        select opt in "${options[@]}"
        do
            case $opt in
                "Enterprise")
                    DEPLOYMENT_TYPE="enterprise"
                    break
                    ;;
                *) echo "invalid option $REPLY";;
            esac
        done    
    else
        options=("Demo" "Enterprise")
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
    fi     
}

function select_user(){
    user_result=$(${CLI_CMD} get user 2>&1)
    user_substring="No resources found"
    if [[ $user_result == *"$user_substring"* ]];
    then
        clear
        echo -e "\x1B[1;31mAt least one user must be available in order to proceed.\n\x1B[0m" 
        echo -e "\x1B[1;31mPlease refer to the README for the requirements and instructions.  The script will now exit.!\n\x1B[0m" 
        exit 1 
    fi
    echo
    userlist=$(${CLI_CMD} get user|awk '{if(NR>1){if(NR==2){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
    COLUMNS=12
    echo -e "\x1B[1mHere are the existing users on this cluster: \x1B[0m"
    options=($userlist)
    usernum=${#options[*]}
    PS3='Enter an existing username in your cluster, valid option [1 to '${usernum}'], non-admin is suggested: '
    select opt in "${options[@]}"
    do
        if [[ -n "$opt" && "${options[@]}" =~ $opt ]]; then
            user_name=$opt
            break
        else
            echo "invalid option $REPLY"
        fi
    done    
}

function display_installationprompt(){
    
    echo "IBM Common Services with Metering & Licensing Components will be installed"

    NAMESPACE_ODLM="common-service"
    ${CLI_CMD} project $NAMESPACE_ODLM >/dev/null 2>&1 || ${CLI_CMD} new-project $NAMESPACE_ODLM >/dev/null 2>&1
}


function check_storage_class() {
    if [[ $PLATFORM_SELECTED == "ROKS" ]];
    then
        # echo ""
        # echo "Applying no_root_squash for demo DB2 deployment on ROKS using CLI"
        # oc get no -l node-role.kubernetes.io/worker --no-headers -o name | xargs -I {} --  oc debug {} -- chroot /host sh -c 'grep "^Domain = slnfsv4.coms" /etc/idmapd.conf || ( sed -i "s/.*Domain =.*/Domain = slnfsv4.com/g" /etc/idmapd.conf; nfsidmap -c; rpc.idmapd )' >> ${LOG_FILE}

       create_storage_classes_roks
    fi
    display_storage_classes
}

function apply_no_root_squash() {
 if [[ $PLATFORM_SELECTED == "ROKS" ]] && [[ "$DEPLOYMENT_TYPE" == "demo" ]]; 
 then
        echo ""
        echo "Applying no_root_squash for demo DB2 deployment on ROKS using CLI"
        ${CLI_CMD} get no -l node-role.kubernetes.io/worker --no-headers -o name | xargs -I {} --  ${CLI_CMD} debug {} -- chroot /host sh -c 'grep "^Domain = slnfsv4.coms" /etc/idmapd.conf || ( sed -i "s/.*Domain =.*/Domain = slnfsv4.com/g" /etc/idmapd.conf; nfsidmap -c; rpc.idmapd )' >> ${LOG_FILE}
fi
}

function create_storage_classes_roks() {
    echo
    echo -ne "\x1B[1mCreate storage classes for deployment... \x1B[0m"
    ${CLI_CMD} apply -f ${BRONZE_STORAGE_CLASS} --validate=false >/dev/null 2>&1
    ${CLI_CMD} apply -f ${SILVER_STORAGE_CLASS} --validate=false >/dev/null 2>&1
    ${CLI_CMD} apply -f ${GOLD_STORAGE_CLASS} --validate=false >/dev/null 2>&1
    echo -e "\x1B[1mDone \x1B[0m"
    
}

function display_storage_classes_roks() {
    sc_bronze_name=cp4a-file-retain-bronze-gid
    sc_silver_name=cp4a-file-retain-silver-gid
    sc_gold_name=cp4a-file-retain-gold-gid
    echo -e "\x1B[1;31m    $sc_bronze_name \x1B[0m"
    echo -e "\x1B[1;31m    $sc_silver_name \x1B[0m"
    echo -e "\x1B[1;31m    $sc_gold_name \x1B[0m" 
}

function check_platform_version(){
    currentver=$(${CLI_CMD}  get nodes | awk 'NR==2{print $5}')
    requiredver="v1.17.1"
    if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" = "$requiredver" ]; then
        PLATFORM_VERSION="4.4OrLater"
        OCP_VERSION="4.4OrLater"
    else
        # PLATFORM_VERSION="3.11"
        PLATFORM_VERSION="4.4OrLater"
        echo -e "\x1B[1;31mIMPORTANT: Only support OCp4.4 or Later, exit...\n\x1B[0m"
        read -rsn1 -p"Press any key to continue";echo
        exit 1
    fi
    # OpenShift 4.0-4.2, install Common Services 3.3
    # OpenShift >= 4.3, install Common Services 3.4
    cs_install_ver="v1.17.1"
    if [ "$(printf '%s\n' "$cs_install_ver" "$currentver" | sort -V | head -n1)" = "$cs_install_ver" ]; then
        CS_VERSION="3.4"  
    else
        CS_VERSION="3.3"
    fi
}

function prepare_common_service(){
   
    echo
    echo -e "\x1B[1mThe script is preparing the custom resources (CR) files for OCP Common Services.  You are required to update (fill out) the necessary values in the CRs and deploy Common Services prior to the deployment. \x1B[0m"
    echo -e "The prepared CRs for IBM common Services are located here: "${COMMON_SERVICES_CRD_DIRECTORY}
    echo -e "After making changes to the CRs, execute the 'deploy_CS.sh' script to install Common Services."
    echo -e "Done"
}

function install_common_service_34(){
    
    if [ "$INSTALL_BAI" == "Yes" ] ; then
    echo -e "Preparing full Common Services Release 3.4 CR for BAI Deployment.."
        func_operand_request_cr_bai_34

    else
    echo -e "Preparing minimal Common Services Release 3.4 CR for non-BAI Deployment.."
        func_operand_request_cr_nonbai_34
    fi
    
     ## TODO: start to install common service
    echo -e "\x1B[1mThe installation of Common Services has started.\x1B[0m"
    #sh ./deploy_CS3.4.sh
    nohup ${PARENT_DIR}/scripts/deploy_CS3.4.sh  &
    echo -e "Done"
}

function install_common_service_33(){
    
        func_operand_request_cr_nonbai_33
    echo -e "\x1B[1mThe installation of Common Services Release 3.3 for OCP 4.2+ has started.\x1B[0m"
    sh ${PARENT_DIR}/scripts/deploy_CS3.3.sh 
  
    echo -e "Done"
}

function func_operand_request_cr_bai_34()
{

   echo "Creating Common Services V3.4 Operand Request for BAI deployments on OCP 4.3+ ..\x1B[0m" >> ${LOG_FILE}
   operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandrequest_cr.yaml
 cat << ENDF > ${operator_source_path}
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  name: common-service
  namespace: ibm-common-services
spec:
  requests:
  - registry: common-service
    registryNamespace: ibm-common-services
    operands:
        - name: ibm-licensing-operator
        - name: ibm-iam-operator
        - name: ibm-monitoring-exporters-operator
        - name: ibm-monitoring-prometheusext-operator
        - name: ibm-monitoring-grafana-operator
        - name: ibm-metering-operator
        - name: ibm-management-ingress-operator
        - name: ibm-commonui-operator
ENDF
}


function func_operand_request_cr_nonbai_34()
{

   echo "Creating Common-Services V3.4 Operand Request for non-BAI deployments on OCP 4.3 ..\x1B[0m" >> ${LOG_FILE}
   operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandrequest_cr.yaml
 cat << ENDF > ${operator_source_path}
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  name: common-service
  namespace: ibm-common-services
spec:
  requests:
  - registry: common-service
    registryNamespace: ibm-common-services
    operands:
        - name: ibm-licensing-operator
        - name: ibm-metering-operator
        - name: ibm-commonui-operator
        - name: ibm-management-ingress-operator
        - name: ibm-iam-operator
        - name: ibm-platform-api-operator


ENDF
}


function func_operand_request_cr_bai_33()
{

   echo "Creating Common Services V3.3 Operand Request for BAI deployments on OCP 4.2+ ..\x1B[0m" >> ${LOG_FILE}
   operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandrequest_cr.yaml
 cat << ENDF > ${operator_source_path}
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  name: common-service
spec:
  requests:
  - registry: common-service
    operands:
        - name: ibm-cert-manager-operator
        - name: ibm-mongodb-operator
        - name: ibm-iam-operator
        - name: ibm-monitoring-exporters-operator
        - name: ibm-monitoring-prometheusext-operator
        - name: ibm-monitoring-grafana-operator
        - name: ibm-management-ingress-operator
        - name: ibm-licensing-operator
        - name: ibm-metering-operator
        - name: ibm-commonui-operator
ENDF
}


function func_operand_request_cr_nonbai_33()
{

   echo "Creating Common Services V3.3 Request Operand for non-BAI deployments on OCP 4.2+ ..\x1B[0m" >> ${LOG_FILE}
   operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandrequest_cr.yaml
 cat << ENDF > ${operator_source_path}
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  name: common-service
spec:
  requests:
  - registry: common-service
    operands:
        - name: ibm-cert-manager-operator
        - name: ibm-mongodb-operator
        - name: ibm-iam-operator
        - name: ibm-management-ingress-operator
        - name: ibm-licensing-operator
        - name: ibm-metering-operator
        - name: ibm-commonui-operator
ENDF
}


function show_summary(){

    printf "\n"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    echo -e "\x1B[1m                    Summary of input                   \x1B[0m"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    if [[ ${PLATFORM_VERSION} == "4.4OrLater" ]]; then
        echo -e "\x1B[1;31m1. Cloud platform to deploy: ${PLATFORM_SELECTED} 4.X\x1B[0m"
    else
        echo -e "\x1B[1;31m1. Cloud platform to deploy: ${PLATFORM_SELECTED} ${PLATFORM_VERSION}\x1B[0m"
    fi
    echo -e "\x1B[1;31m2. Project to deploy: ${project_name}\x1B[0m"
    echo -e "\x1B[1;31m3. User selected: ${user_name}\x1B[0m"
    if  [[ $PLATFORM_SELECTED == "ROKS" ]];
    then
        echo -e "\x1B[1;31m5. Storage Class created: \x1B[0m"
        display_storage_classes_roks
    fi
    echo -e "\x1B[1m*******************************************************\x1B[0m"
}

function check_csoperator_exists()
{

project="common-service"

check_project=`${CLI_CMD} get namespace $project --ignore-not-found | wc -l`  >/dev/null 2>&1
check_operator=$(${CLI_CMD} get csv --all-namespaces |grep "ibm-common-service-operator")
if [ -n "$check_operator" ]; then
    echo ""
    echo "Found an Existing Installation of IBM Common Services.  The current installation of IBM Common Services will be skipped."  >> ${LOG_FILE}
    echo "Found an Existing Installation of IBM Common Services.  The current installation of IBM Common Services will be skipped." 
    
    CS_INSTALL="NO"
    exit 1
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
            DOCKER_RES_SECRET_NAME="admin.registrykey"
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

function verify_local_registry_password(){
    # require to preload image for CP4A image and ldap/db2 image for demo
    printf "\n"
    while true; do
        printf "\x1B[1mHave you pushed the images to the local registry using 'loadimages.sh' (CP4A images) (Yes/No)? \x1B[0m"
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

    while [[ $verify_passed == "" && $PRE_LOADED_IMAGE == "Yes" ]]
    do
        get_local_registry_server
        get_local_registry_user
        get_local_registry_password

        if [[ $LOCAL_REGISTRY_SERVER == docker-registry* || $LOCAL_REGISTRY_SERVER == image-registry* || $LOCAL_REGISTRY_SERVER == default-route-openshift-image-registry* ]] ;
        then
            if [[ $OCP_VERSION == "3.11" ]];then
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
            elif [[ "$machine" == "Mac" ]]
            then
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
            elif [[ $OCP_VERSION == "4.4OrLater" ]]
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
        ${CLI_CMD} delete secret "$DOCKER_RES_SECRET_NAME" -n $project_name >/dev/null 2>&1
        CREATE_SECRET_CMD="${CLI_CMD} create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$LOCAL_REGISTRY_SERVER --docker-username=$LOCAL_REGISTRY_USER --docker-password=$LOCAL_REGISTRY_PWD --docker-email=ecmtest@ibm.com -n $project_name"
        if $CREATE_SECRET_CMD ; then
            echo -e "\x1B[1mDone\x1B[0m"
        else
            echo -e "\x1B[1;31mFailed\x1B[0m"
        fi
    fi
}

if [[ $1 == "dev" ]]
then
    CS_INSTALL="YES"
    
else
    CS_INSTALL="NO"
    
fi

clear
#select_ocp_olm
select_platform
validate_cli
if [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]]; then
    check_platform_version
fi
select_deployment_type
collect_input
${CLI_CMD} project $project_name >/dev/null 2>&1
# create_project
# bind_scc
if [[ $SCRIPT_MODE == "OLM" ]];then
    validate_docker_podman_cli
    get_entitlement_registry
    get_storage_class_name
    create_secret_entitlement_registry
    allocate_operator_pvc_olm_or_cncf
    prepare_olm_install
else
    validate_docker_podman_cli
    if [[ $PLATFORM_SELECTED == "other" ]]; then
        get_entitlement_registry
    fi
    if [[ "$use_entitlement" == "no" ]]; then
        verify_local_registry_password
    fi   
    get_storage_class_name
    if [[ "$use_entitlement" == "yes" ]]; then
        create_secret_entitlement_registry
    fi
    if [[ "$use_entitlement" == "no" ]]; then
        create_secret_local_registry
    fi 
    allocate_operator_pvc_olm_or_cncf
    prepare_install
    apply_cp4a_operator
fi

# create_scc

apply_no_root_squash

if  [[ $PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" ]];
then
    display_node_name
fi

if [[ $SCRIPT_MODE != "OLM" ]]; then
    show_summary
    check_csoperator_exists

    if [[ $PLATFORM_SELECTED == "OCP" ||  $PLATFORM_SELECTED == "ROKS" ]] && [[ $PLATFORM_VERSION == "4.4OrLater" ]] && [[ $CS_VERSION == "3.4" ]];
    then 
        
        if [ "$CS_INSTALL" != "YES" ]; then
            display_installationprompt
            echo ""
        
                nohup ${PARENT_DIR}/scripts/deploy_CS3.4.sh  >> ${LOG_FILE} 2>&1 &
        else
        echo "Review mode: IBM Common Services will be skipped.." 
        fi
    fi

    # Deploy CS 3.3 if OCP 4.2 or 3.11 as per requirements.  The components for CS 3.3 in this case will only be Licensing and Metering (also CommonUI as a base requirment)
    #if  [[[ $PLATFORM_SELECTED == "OCP" ]] && [ $PLATFORM_VERSION == "4.2" ]]] || [[[ $PLATFORM_SELECTED == "OCP" ] && [ $PLATFORM_VERSION == "3.11" ]]]

    if  [[ $PLATFORM_SELECTED == "OCP" ||  $PLATFORM_SELECTED == "ROKS" ]] && [[ $PLATFORM_VERSION == "4.4OrLater" ]] && [[ $CS_VERSION == "3.3" ]];
    then 
        echo "IBM Common Services with Metering & Licensing Components will be installed"
            if [ "$CS_INSTALL" != "YES" ]; then
            nohup ${PARENT_DIR}/scripts/deploy_CS3.3.sh >> ${LOG_FILE} 2>&1 &
            else
        echo "Review mode: IBM Common Services will be skipped.." 
            echo ""
        fi
    fi  

    # Deploy CS 3.3 if OCP 3.11
    if  [[ $PLATFORM_SELECTED == "OCP" ]] && [[ $PLATFORM_VERSION == "3.11" ]]; 
    then 
            echo "IBM Common Services with Metering & Licensing Components will be installed"
            if [ "$CS_INSTALL" != "YES" ]; then
                COMMON_SERVICES_INSTALL_DIRECTORY_OCP311=${PARENT_DIR}/descriptors/common-services/scripts/common-services.sh
                sh ${COMMON_SERVICES_INSTALL_DIRECTORY_OCP311} install --async
            else
                echo "Review mode: IBM Common Services will be skipped.."   
            fi
    fi
fi

clean_up
#set the project context back to the user generated one
${CLI_CMD} project ${PROJ_NAME} > /dev/null

