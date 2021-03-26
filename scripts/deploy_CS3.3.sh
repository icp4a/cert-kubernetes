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

TEMP_FOLDER=${CUR_DIR}/.tmp
LOG_FILE=${CUR_DIR}/CS_prepare_install33.log

#product_install=${1:-nonbai} 

function func_operand_request_cr_bai_33()
{

   echo "Creating Common Services V3.3 Operand Request for BAI deployments on OCP 4.2+ ..\x1B[0m" >> ${LOG_FILE}
   operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandrequest33_cr.yaml
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


# Deploy CS 3.3 if OCP 4.2 or 3.11 as per requirements.  
# The components for CS 3.3 in this case will only be Licensing and Metering (also CommonUI as a base requirment)

function func_operand_request_cr_nonbai_33()
{

echo "$(date) Creating Common Services V3.3 Request Operand for non-BAI deployments on OCP 3.11, 4.2+"  >> ${LOG_FILE}
   operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandrequest33_cr.yaml
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

function install_common_service_33(){
    echo
    echo -e "The installation of Common Services Relase 3.3 has started..." >> ${LOG_FILE}
        create_project_cs
        apply_cs_operator_source
        func_crd_rbac
        func_install_odlm
        sleep 20
        func_wait
        func_operand_request_cr
      #   func_operand_config_cr
      #   func_operand_registry
      #   func_wait2 
        echo "waiting on csv's to be ready..."
        sleep 
        func_check_csv
        set_mongodb_single_copy
        #func_check_statefulset
        #func_check_jobs
   	sleep 20
    echo -e "Done"
}


function create_project_cs() {
    project_name="ibm-common-services"
    isProjExists=`oc get project $project_name --ignore-not-found | wc -l`  >/dev/null 2>&1

   if [ $isProjExists -ne 2 ] ; then
        oc new-project ${project_name} >> ${LOG_FILE}
        returnValue=$?
        if [ "$returnValue" == 1 ]; then
            echo -e "\x1B[1mInvalid project name, please enter a valid name...\x1B[0m" >> ${LOG_FILE}
            project_name=""
        else
            echo -e "\x1B[1mCreate project ${project_name}...\x1B[0m" >> ${LOG_FILE}
        fi
    else
        echo -e "$date : A Previous Installation & Project \"${project_name}\" already exists..please cleanup existing deployment and resume!!.." >> ${LOG_FILE}
        exit
    fi
    PROJ_NAME=${project_name}
}



# create common-services operator source
function apply_cs_operator_source () {

echo "Applying common-services operator source...." >> ${LOG_FILE}
operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_source.yaml
oc apply -f ${operator_source_path} >> ${LOG_FILE}
sleep 10
}

# create Common Services crd and rbac
function func_crd_rbac () {
   
   echo "Creating Common-Services OLDM CRDs.....\x1B[0m" >> ${LOG_FILE}

   
   oc apply -f https://raw.githubusercontent.com/IBM/operand-deployment-lifecycle-manager/release-1.1/deploy/crds/operator.ibm.com_operandregistries_crd.yaml >> ${LOG_FILE}
   oc apply -f https://raw.githubusercontent.com/IBM/operand-deployment-lifecycle-manager/release-1.1/deploy/crds/operator.ibm.com_operandconfigs_crd.yaml >> ${LOG_FILE}
   oc apply -f https://raw.githubusercontent.com/IBM/operand-deployment-lifecycle-manager/release-1.1/deploy/crds/operator.ibm.com_operandrequests_crd.yaml >> ${LOG_FILE}
   sleep 20

  
   oc apply -f https://raw.githubusercontent.com/IBM/operand-deployment-lifecycle-manager/release-1.1/deploy/service_account.yaml  >> ${LOG_FILE}
   oc apply -f https://raw.githubusercontent.com/IBM/operand-deployment-lifecycle-manager/release-1.1/deploy/role.yaml >> ${LOG_FILE}
   oc apply -f https://raw.githubusercontent.com/IBM/operand-deployment-lifecycle-manager/release-1.1/deploy/role_binding.yaml >> ${LOG_FILE}
   sleep 20
}

function func_install_odlm () {
    oc project ibm-common-services
    echo "Creating Common-Services operator......" >> ${LOG_FILE}
    operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator.yaml
    oc apply -f ${operator_source_path} >> ${LOG_FILE}
   while ! oc get deployments/operand-deployment-lifecycle-manager -n "ibm-common-services" | egrep "1/1|2/2|3/3"; do
      echo "Waiting for odlm deployment to complete..." >> ${LOG_FILE}
      sleep 5
   done
    sleep 20
}

function func_wait() {

   echo "Waiting for odlm deployment to complete.." >> ${LOG_FILE}
    while ! oc get deployments/operand-deployment-lifecycle-manager -n "ibm-common-services" | egrep "1/1|2/2|3/3"; do
      echo "Waiting for odlm deployment to complete..." >> ${LOG_FILE}
      sleep 5
   done


while ! oc get deployments --all-namespaces | egrep -i operand-deployment-lifecycle-manager | egrep "1/1|2/2|3/3"; do
      echo "Waiting for odlm..."
      sleep 10
   done


echo "CatalogSource:"
   while ! oc project ibm-common-services 2>/dev/null; do
      echo -e " wait for namespace $NAMESPACE to appear"
      sleep 10
   done

 echo "OperandRegistry:"
while ! oc get operandregistry | egrep -qi common-service; do
      echo -e " wait for operandregistry to appear"
      sleep 10
   done

   echo "OperandConfig:"
   while ! oc get operandconfig | egrep -qi common-service; do
      echo -e " wait for operandconfig to appear"
      sleep 10
   done

}

#create waits after operandrequest
func_wait2 () {
   echo "OperandRequest:"
   NAMESPACE="ibm-common-services"

   while ! oc get operandrequest -n $NAMESPACE | egrep -qi common-service; do
      echo -e "	wait for operandrequest to appear"
      sleep 10
   done
   
   echo "OperatorGroup:"
   while ! oc get operatorgroup -n $NAMESPACE | egrep -qi operand; do
      echo -e "	wait for operatorgroup to appear"
      sleep 10
   done
   
   echo "Subscriptions:"
   while ! oc get subscriptions -n $NAMESPACE | egrep -qi ibm; do
      echo -e "	wait for subscription to appear"
      sleep 10
   done

   echo "CSV:"
   while ! oc get csv -n $NAMESPACE | egrep -qi ibm; do
      echo -e "	wait for csv to appear"
      sleep 30
   done
}


# check that csv are good
func_check_csv () {
   NAMESPACE="ibm-common-services"
   ROUND=0
   #func_link_secret_delete_pod
   while oc get csv -n $NAMESPACE | egrep -v "DISPLAY|Succeeded"; do
      ROUND=$((ROUND+1))
      echo "Making sure csv's are succeeded status round $ROUND..."
      sleep 30
      
      if [[ $ROUND -gt 40 ]]; then
         echo -e "	!.! csvs timeout"
         break
      fi
   done
}


# check statefulsets to make sure running normal
func_check_statefulsets () {
   ROUND=0
   NAMESPACE="ibm-common-services"
 #  func_link_secret_delete_pod
   while oc get statefulset -n $NAMESPACE | egrep "0/1|0/2|1/2|0/3|1/3|2/3"; do
      ROUND=$((ROUND+1))
      echo "Waiting for statefulsets round $ROUND..." >> ${LOG_FILE}
      sleep 30
      #func_link_secret_delete_pod
      if [[ $ROUND -gt 40 ]]; then
         echo -e "	!.! mongodb timeout" >> ${LOG_FILE}
         break
      fi
   done
}

# check job status to make sure finished
func_check_jobs () {
   echo "Make sure jobs are finished"
   NAMESPACE="ibm-common-services"
   ROUND=0
   while oc get jobs -n $NAMESPACE | egrep "0/1|0/2|1/2|0/3|1/3|2/3"; do
      echo "Waiting for jobs to finish round $ROUND..." >> ${LOG_FILE}
      ROUND=$((ROUND+1))
      sleep 30
      #func_link_secret_delete_pod
      if [[ $ROUND -gt 30 ]]; then
         echo -e "	!.! jobs timeout" >> ${LOG_FILE}
         break
      fi
   done
}


# create operandrequest to install

function func_operand_request_cr () {
    oc project ibm-common-services
   echo "Creating Common-Services Operand Request operator..." >> ${LOG_FILE}
    operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandrequest33_cr.yaml >> ${LOG_FILE}
    oc apply -f ${operator_source_path} >> ${LOG_FILE}
    sleep 60
}

# create operandconfig to install
function func_operand_config_cr () {
    oc project ibm-common-services
    echo "Applying Common-Services Operand Config operator..." >> ${LOG_FILE}
    operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandconfig_cr.yaml
    oc apply -f ${operator_source_path}
    sleep 60
}

# create operandregistry to install
function func_operand_registry () {
    oc project ibm-common-services
    echo "\x1B[1mApplying Common-Services Operand Registry operator..\x1B[0m" >> ${LOG_FILE}
    operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandregistry_cr.yaml
    oc apply -f ${operator_source_path}
sleep 20
}


# Deploy CS 3.3 if OCP 4.2 or 3.11 as per requirements.  
# The components for CS 3.3 in this case will only be Licensing and Metering (also CommonUI as a base requirment)

function startdeploy_cs()
{

   echo -e "*******************************************************" >> ${LOG_FILE}
    echo "$(date) non-bai deployment as default, The components for CS 3.3 in this case will only be Licensing and Metering " >> ${LOG_FILE}
    func_operand_request_cr_nonbai_33 >> ${LOG_FILE}
    install_common_service_33 >> ${LOG_FILE}
}

#
# Set config so that only one MongoDB replica comes up
#

function set_mongodb_single_copy()
{

index=0
  while [ $index -lt 20 ]
  do
    #jsonpath="{ range  .spec.services[$index]}{.name}"
    item=$(oc get operandconfig common-service -n ibm-common-services --ignore-not-found -o=jsonpath="{ range  .spec.services["$index"]}{.name}")
    
    if [ "$item" = "ibm-mongodb-operator" ]; then
    
     oc patch operandconfig common-service -n ibm-common-services --type json \
        -p '[{"op":"replace","path":"/spec/services/'$index'/spec/mongoDB", "value":{"replicas": 1}}]' >> ${LOG_FILE}
      break;
    fi
    index=$(( index + 1 ))
  done
}

function show_summary(){

   PLATFORM_SELECTED="OCP"
   PLATFORM_VERSION=">=4.2+ < 4.4"
   project_name="ibm-common-services"

    printf "\n"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    echo -e "\x1B[1m                    Summary of input                   \x1B[0m"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    echo -e "\x1B[1;31m1. Cloud platform to deploy: ${PLATFORM_SELECTED} ${PLATFORM_VERSION}\x1B[0m"
    echo -e "\x1B[1;31m2. Project to deploy: ${project_name}\x1B[0m"
    echo -e "\x1B[1;31m3. CS Operators to be Installed: Licensing and Metering + dependencies \x1B[0m"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
}

####               ####
##    Main Logic     ##
####               ####
startdeploy_cs
show_summary >> ${LOG_FILE}

