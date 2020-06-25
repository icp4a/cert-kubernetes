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
INSTALL_BAI=""
CRD_FILE=${PARENT_DIR}/descriptors/ibm_cp4a_crd.yaml
SA_FILE=${PARENT_DIR}/descriptors/service_account.yaml
CLUSTER_ROLE_FILE=${PARENT_DIR}/descriptors/cluster_role.yaml
CLUSTER_ROLE_BINDING_FILE=${PARENT_DIR}/descriptors/cluster_role_binding.yaml
CLUSTER_ROLE_BINDING_FILE_TEMP=${TEMP_FOLDER}/.cluster_role_binding.yaml
ROLE_FILE=${PARENT_DIR}/descriptors/role.yaml
ROLE_BINDING_FILE=${PARENT_DIR}/descriptors/role_binding.yaml
OPERATOR_FILE=${PARENT_DIR}/descriptors/operator.yaml
BRONZE_STORAGE_CLASS=${PARENT_DIR}/descriptors/cp4a-bronze-storage-class.yaml
SILVER_STORAGE_CLASS=${PARENT_DIR}/descriptors/cp4a-silver-storage-class.yaml
GOLD_STORAGE_CLASS=${PARENT_DIR}/descriptors/cp4a-gold-storage-class.yaml
LICENSE_FILE=${CUR_DIR}/LICENSES/LICENSE
LOG_FILE=${CUR_DIR}/prepare_install.log
PLATFORM_SELECTED=""
PLATFORM_VERSION=""
PROJ_NAME=""

COMMON_SERVICES_CRD_DIRECTORY_OCP311=${PARENT_DIR}/descriptors/common-services/scripts
COMMON_SERVICES_CRD_DIRECTORY=${PARENT_DIR}/descriptors/common-services/crds
COMMON_SERVICES_OPERATOR_ROLES=${PARENT_DIR}/descriptors/common-services/roles
COMMON_SERVICES_TEMP_DIR=$TMEP_FOLDER

mkdir -p $TEMP_FOLDER >/dev/null 2>&1
echo '' > $LOG_FILE

function validate_cli(){
    clear
    echo -e "\x1B[1mThis script prepares the environment for the deployment of some Cloud Pak for Automation capabilities \x1B[0m"
    echo
    which oc &>/dev/null
    [[ $? -ne 0 ]] && \
        echo "Unable to locate an OpenShift CLI. You must install it to run this script." && \
        exit 1
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

    user_name=""
    select_user
}



function create_project() {

    isProjExists=`oc get project $project_name --ignore-not-found | wc -l`  >/dev/null 2>&1

   if [ $isProjExists -ne 2 ] ; then
        oc new-project ${project_name} >> ${LOG_FILE}
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
    PROJ_NAME=${project_name}

    if  [[ $PLATFORM_VERSION == "3.11" ]]; then
        oc adm policy add-scc-to-user privileged -z ibm-cp4a-operator -n ${project_name}
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
    echo
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
    echo
    echo -ne "Creating the custom resource definition (CRD) and a service account that has the permissions to manage the resources..."
    oc apply -f ${CRD_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
    oc apply -f ${CLUSTER_ROLE_FILE} --validate=false >> ${LOG_FILE}
    oc apply -f ${CLUSTER_ROLE_BINDING_FILE_TEMP} --validate=false >> ${LOG_FILE}
    oc apply -f ${SA_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
    oc apply -f ${ROLE_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
    oc apply -f ${ROLE_BINDING_FILE} -n ${project_name} --validate=false >> ${LOG_FILE}
    echo "Done"

    echo
    echo -ne Adding the user ${user_name} to the ibm-cp4a-operator role...
    oc project ${project_name} >> ${LOG_FILE}
    oc adm policy add-role-to-user edit ${user_name} >> ${LOG_FILE}
    oc adm policy add-role-to-user registry-editor ${user_name} >> ${LOG_FILE}
    oc adm policy add-role-to-user ibm-cp4a-operator ${user_name} >> ${LOG_FILE}
    oc adm policy add-cluster-role-to-user ibm-cp4a-operator ${user_name} >> ${LOG_FILE}
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
        echo -e "\x1B[1;31mPlease refer to the README for the requirements and instructions.  The script will now exit!.\n\x1B[0m" 
        exit 1 
    fi
}

function display_storage_classes_ocp() {
    echo
    echo "Storage classes are needed to run the deployment script. For the "Demo" deployment scenario, you may use one (1) storage class.  For an "Enterprise" deployment, the deployment script will ask for three (3) storage classes to meet the "slow", "medium", and "fast" storage for the configuration of CP4A components.  If you don't have three (3) storage classes, you can use the same one for "slow", "medium", or fast.  Note that you can get the existing storage class(es) in the environment by running the following command: oc get storageclass. Take note of the storage classes that you want to use for deployment. "
	oc get storageclass
}


function display_node_name() {
    echo
    if  [[ $PLATFORM_VERSION == "3.11" ]];
    then
        echo "Below is the host name of the Infrastructure Node for the environment, which is required as an input during the execution of the deployment script for the creation of routes in OCP.  You can also get the host name by running the following command: oc get nodes --selector node-role.kubernetes.io/infra=true -o custom-columns=":metadata.name". Take note of the host name. "
	oc get nodes --selector node-role.kubernetes.io/infra=true -o custom-columns=":metadata.name"
    elif  [[ $PLATFORM_VERSION == "4.2" || $PLATFORM_VERSION == "4.3" || $PLATFORM_VERSION == "4.4" ]];
    then
        echo "Below is the route host name for the environment, which is required as an input during the execution of the deployment script for the creation of routes in OCP. You can also get the host name by running the following command: oc get route console -n openshift-console -o yaml|grep routerCanonicalHostname. Take note of the host name. "
        oc get route console -n openshift-console -o yaml|grep routerCanonicalHostname | head -1 | cut -d ' ' -f 6
    fi
}


function create_scc() {
    oc create serviceaccount ibm-pfs-es-service-account
    oc create -f ibm-pfs-privileged-scc.yaml
    oc adm policy add-scc-to-user ibm-pfs-privileged-scc -z ibm-pfs-es-service-account
}


function clean_up(){
    rm -rf ${TEMP_FOLDER} >/dev/null 2>&1
}


function select_platform(){
    COLUMNS=12
    echo -e "\x1B[1mSelect the cloud platform to deploy: \x1B[0m"
    options=("Openshift Container Platform (OCP) - Private Cloud" "Other ( Certified Kubernetes Cloud Platform / CNCF)")
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
}


function select_deployment_type(){
    COLUMNS=12
    echo -e "\x1B[1mWhat type of deployment is being performed?\x1B[0m"
    if  [[ $PLATFORM_SELECTED == "ROKS" ]];
    then
        options=("Demo")
        PS3='Enter a valid option [1 to 1]: '
        select opt in "${options[@]}"
        do
            case $opt in
                "Demo")
                    DEPLOYMENT_TYPE="demo"
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
    user_result=$(oc get user 2>&1)
    user_substring="No resources found"
    if [[ $user_result == *"$user_substring"* ]];
    then
        clear
        echo -e "\x1B[1;31mAt least one user must be available in order to proceed.\n\x1B[0m" 
        echo -e "\x1B[1;31mPlease refer to the README for the requirements and instructions.  The script will now exit.!\n\x1B[0m" 
        exit 1 
    fi
    echo
    userlist=$(oc get user|awk '{if(NR>1){if(NR==2){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
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
    
    echo "If you want to install Business Automation Insights, you must have IBM Event Streams already installed before you run the deployment script."
    echo "For more information about the IBM Event Streams supported version number and licensing restrictions, see IBM Knowledge Center."
    echo "" 
    echo "IBM Common Services with Metering & Licensing Components will be installed"

    NAMESPACE_ODLM="common-service"
    oc project $NAMESPACE_ODLM >/dev/null 2>&1 || oc new-project $NAMESPACE_ODLM >/dev/null 2>&1
}


function check_storage_class() {
    if  [[ $PLATFORM_SELECTED == "OCP" ]];
    then
        display_storage_classes_ocp
    fi
    if [[ $PLATFORM_SELECTED == "ROKS" ]];
    then
       create_storage_classes_roks
    fi

}

function create_storage_classes_roks() {
    echo
    echo -ne "\x1B[1mCreate storage classes for deployment: \x1B[0m"
    oc apply -f ${BRONZE_STORAGE_CLASS} --validate=false >> ${LOG_FILE}
    oc apply -f ${SILVER_STORAGE_CLASS} --validate=false >> ${LOG_FILE}
    oc apply -f ${GOLD_STORAGE_CLASS} --validate=false >> ${LOG_FILE}
    echo -e "\x1B[1mDone \x1B[0m"
    #echo
    #echo -e "\x1B[1mTake note of the storage classes that you can use for deployment  \x1B[0m"
    #oc get storageclass
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
    res=$(kubectl  get nodes | awk 'NR==2{print $5}')
    if [[  $res =~ v1.11 ]];
    then
        PLATFORM_VERSION="3.11"
    elif [[  $res =~ v1.14.6 ]];
    then
        PLATFORM_VERSION="4.2"
    elif [[  $res =~ v1.16.2 ]];
    then
        PLATFORM_VERSION="4.3"
    elif [[  $res =~ v1.17.1 ]];
    then
        PLATFORM_VERSION="4.4"
    else
        echo -e "\x1B[1;31mUnable to determine OCP version with node version information: $res . Will NOT install/prepare common service for your deployment\x1B[0m"
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
    nohup ./deploy_CS3.4.sh  &
    echo -e "Done"
}

function install_common_service_33(){
    
        func_operand_request_cr_nonbai_33
    echo -e "\x1B[1mThe installation of Common Services Release 3.3 for OCP 4.2+ has started.\x1B[0m"
    sh ./deploy_CS3.3.sh 
  
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
    echo -e "\x1B[1;31m1. Cloud platform to deploy: ${PLATFORM_SELECTED} ${PLATFORM_VERSION}\x1B[0m"
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
SUB="common-services-operator"

check_project=`oc get project $project --ignore-not-found | wc -l`  >/dev/null 2>&1
check_operator=$(oc get sub -n common-service --ignore-not-found |grep ibm-common-service-operator) >/dev/null 2>&1

if [[ $check_project == 2 ]] || [[ "$check_operator" == *"$SUB"*  ]]; then
    echo ""
    echo "Found an Existing Installation of IBM Common-Services...will be skipped..." >> ${LOG_FILE}
    echo "Found an Existing Installation of IBM Common-Services...will be skipped..."
    CS_INSTALL="NO"
    exit 1
fi

}


validate_cli
if [[ $1 == "dev" ]]
then
    CS_INSTALL="YES"
    
else
    CS_INSTALL="NO"
    
fi

select_platform
check_platform_version
#select_deployment_type
if  [[ $PLATFORM_SELECTED == "OCP" ]];
then
    check_existing_sc
fi
collect_input
#create_project
bind_scc
prepare_install
#create_scc
check_storage_class



if  [[ $PLATFORM_SELECTED == "OCP" ]];
then
    display_node_name
fi

show_summary
check_csoperator_exists

if [[ $PLATFORM_SELECTED == "OCP" ]] && [[ $PLATFORM_VERSION == "4.3" ]] || [[ $PLATFORM_VERSION == "4.4" ]];
then 
    
    if [ "$CS_INSTALL" != "YES" ]; then
        display_installationprompt
        echo ""
       
            nohup ./deploy_CS3.4.sh  >> ${LOG_FILE} 2>&1 &
    else
    echo "Review mode: IBM Common Services will be skipped.." 
    fi
fi

# Deploy CS 3.3 if OCP 4.2 or 3.11 as per requirements.  The components for CS 3.3 in this case will only be Licensing and Metering (also CommonUI as a base requirment)
#if  [[[ $PLATFORM_SELECTED == "OCP" ]] && [ $PLATFORM_VERSION == "4.2" ]]] || [[[ $PLATFORM_SELECTED == "OCP" ] && [ $PLATFORM_VERSION == "3.11" ]]]

if  [[ $PLATFORM_SELECTED == "OCP" ]] && [[ $PLATFORM_VERSION == "4.2" ]]; 
then 
    echo "IBM Common Services with Metering & Licensing Components will be installed"
        if [ "$CS_INSTALL" != "YES" ]; then
        nohup ./deploy_CS3.3.sh >> ${LOG_FILE} 2>&1 &
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


clean_up
#set the project context back to the user generated one
oc project ${PROJ_NAME} > /dev/null

