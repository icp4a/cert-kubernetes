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

CUR_DIR=$(pwd)
if [ -n "$(echo $CUR_DIR | grep scripts)" ]; then
    PARENT_DIR=$(dirname "$PWD")
else
    PARENT_DIR=$CUR_DIR
fi
TEMP_FOLDER=${CUR_DIR}/.tmp

CRD_FILE=${PARENT_DIR}/descriptors/ibm_cp4a_crd.yaml
SA_FILE=${PARENT_DIR}/descriptors/service_account.yaml
CLUSTER_ROLE_FILE=${PARENT_DIR}/descriptors/cluster_role.yaml
CLUSTER_ROLE_BINDING_FILE=${PARENT_DIR}/descriptors/cluster_role_binding.yaml
CLUSTER_ROLE_BINDING_FILE_TEMP=${TEMP_FOLDER}/.cluster_role_binding.yaml
ROLE_FILE=${PARENT_DIR}/descriptors/role.yaml
ROLE_BINDING_FILE=${PARENT_DIR}/descriptors/role_binding.yaml
OPERATOR_FILE=${PARENT_DIR}/descriptors/operator.yaml
LICENSE_FILE=${CUR_DIR}/LICENSES/LICENSE
LOG_FILE=${CUR_DIR}/prepare_install.log

mkdir -p $TEMP_FOLDER >/dev/null 2>&1
echo '' > $LOG_FILE

function validate_cli(){
    which oc &>/dev/null
    [[ $? -ne 0 ]] && \
        echo "Unable to locate an OpenShift CLI. You must install it to run this script." && \
        exit 1
}

function collect_input() {
    clear
    echo This script prepares the environment for the deployment of some Cloud Pak for Automation capabilities
    project_name=""
    while [[ $project_name == "" ]]; 
    do
       read -p "Enter the name for a new project or an existing project (namespace): " project_name
       if [ -z "$project_name" ]; then
           echo -e "\x1B[1;31mEnter a valid project name, project name can not be blank\x1B[0m"
       else
           create_project
       fi
    done

    user_name=""
    while [[ $user_name == "" ]]; 
    do
       read -p "Enter an existing username in your cluster, non-admin is suggested: " user_name
       if [ -z "$user_name" ]; then
           echo -e "\x1B[1;31mEnter a valid user name, user name can not be blank\x1B[0m"
       else
           check_user_exist
       fi
    done
}

function create_project() {
    oc get project | grep "${project_name}" >/dev/null 2>&1
    returnValue=$?
    if [ "$returnValue" == 1 ] ; then
        oc new-project ${project_name} >> ${LOG_FILE}
        returnValue=$?
        if [ "$returnValue" == 1 ]; then
            echo -e "\x1B[1mInvalid project name, please enter a valid name...\x1B[0m"
            project_name=""
        else
            echo -e "\x1B[1mCreate project ${project_name}...\x1B[0m"
        fi
    else
        echo -e "\x1B[1mProject \"${project_name}\" already exists! Continue...\x1B[0m"
    fi
 
}

function check_user_exist() {
    oc get user | grep "${user_name}" >/dev/null 2>&1
    returnValue=$?
    if [ "$returnValue" == 1 ] ; then
        echo -e "\x1B[1mUser \"${user_name}\" NOT exists! Please enter an existing username in your cluster...\x1B[0m"
        user_name=""
    else
        echo -e "\x1B[1mUser \"${user_name}\" exists! Continue...\x1B[0m"
    fi
}

function bind_scc() {
   echo -ne Binding the 'privileged' role to the 'default' service account...
   dba_scc=$(oc get scc privileged | awk '{print $1}' )
   if [ -n "$dba_scc" ]; then
     oc adm policy add-scc-to-user privileged -z default  >>  ${LOG_FILE}
   else
     echo "The 'privileged' security context constraint (SCC) does not exist in the cluster. Make sure that you update your environment to include this SCC."
     exit 1
   fi
   echo "Done"
}

function prepare_install() {
    sed -e "s/<NAMESPACE>/${project_name}/g" ${CLUSTER_ROLE_BINDING_FILE} > ${CLUSTER_ROLE_BINDING_FILE_TEMP}

    echo -ne "Creating the custom resource definition (CRD) and a service account that has the permissions to manage the resources..."
    oc apply -f ${CRD_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
    oc apply -f ${CLUSTER_ROLE_FILE} --validate=false >> ${LOG_FILE}
    oc apply -f ${CLUSTER_ROLE_BINDING_FILE_TEMP} --validate=false >> ${LOG_FILE}
    oc apply -f ${SA_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
    oc apply -f ${ROLE_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
    oc apply -f ${ROLE_BINDING_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
    echo "Done"

    echo -ne Adding the user ${user_name} to the ibm-cp4a-operator role...
    oc project ${project_name} >> ${LOG_FILE}
    oc adm policy add-role-to-user edit ${user_name} >> ${LOG_FILE}
    oc adm policy add-role-to-user registry-editor ${user_name} >> ${LOG_FILE}
    oc adm policy add-role-to-user ibm-cp4a-operator ${user_name} >> ${LOG_FILE}
    oc adm policy add-cluster-role-to-user ibm-cp4a-operator ${user_name} >> ${LOG_FILE}
    echo "Done"
}

# ACA need this task to tag node with special labels
function tag_nodes(){
    echo -ne Tagging the worker nodes...
    nodes=$(oc get nodes | grep compute | grep  [^Not]Ready | awk '{print $1}' | cut -d ',' -f1 | tr -d '"')
    for i in $nodes
    do
        if [ $i != 'NAME' ]; then
            # oc label nodes $i {celery$project_name-,mongo$project_name-,mongo-admin$project_name-} >> ${LOG_FILE}
            oc label nodes $i mongo$project_name=aca mongo-admin$project_name=aca celery$project_name=aca --overwrite=true >> ${LOG_FILE}
        fi
    done
    echo "Done"
}

function check_existing_sc(){
# Check existing storage class
    sc_result=$(oc get sc 2>&1)

    sc_substring="No resources found"
    if [[ $sc_result == *"$sc_substring"* ]];
    then
        clear
        echo -e "\x1B[1;31mAt least one dynamic storage class must be available in order to proceed.\n\x1B[0m" 
        echo -e "\x1B[1;31mPlease refer to the README for the requirements and instructions.  The script will now exit.!.\n\x1B[0m" 
        exit 1 
    fi
}

function display_storage_classes() {
    echo
    echo "A storage class is needed to run the deployment script. You can get the existing storage class(es) in the environment by running the following command: oc get storageclass. Take note of the storage class that you want to use. "    
	oc get storageclass
}

function display_node_name() {
    echo
    echo "The Infrastructure Node host name for the environment is needed to run the deployment script. You can get the host name by running the following command: oc get nodes --selector node-role.kubernetes.io/infra=true -o custom-columns=":metadata.name". Take note of the host name. "    
	oc get nodes --selector node-role.kubernetes.io/infra=true -o custom-columns=":metadata.name"
}

function create_scc() {
    oc create serviceaccount ibm-pfs-es-service-account
    oc create -f ibm-pfs-privileged-scc.yaml
    oc adm policy add-scc-to-user ibm-pfs-privileged-scc -z ibm-pfs-es-service-account
}

function clean_up(){
    rm -rf ${TEMP_FOLDER} >/dev/null 2>&1
}

validate_cli
check_existing_sc
collect_input
#create_project
bind_scc
prepare_install
#create_scc
tag_nodes
display_storage_classes
display_node_name
clean_up
