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
##IBM Common Service Operator and ODLM operator get deployed in the “common-service” 
#the individual operators get deployed in the “ibm-common-services” namespace
###############################################################################
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

TEMP_FOLDER=${CUR_DIR}/.tmp
LOG_FILE=${CUR_DIR}/cs_prepare_install34.log

product_install=${1:-nonbai} 
project_prev=${2:-common-service}

function install_common_service_34(){
    echo -e "$(date) The installation of Common Services Release 3.4 has started" >> ${LOG_FILE}
        
       
        apply_registry
        sleep 60
        create_operator_Group
        create_operator_subscription
        echo "$(date) waiting on Operator..sleeping..." >> ${LOG_FILE}
        sleep 120
        create_operator_request
        sleep 60
        set_mongodb_single_copy
        show_summary  >> ${LOG_FILE}
        #oc project ${project_prev} >> ${LOG_FILE}
        #echo "$(date) Setting project scope back to..${project_prev}"
    echo -e "Done" >> ${LOG_FILE}
}


function func_operand_request_cr_bai_34()
{

   echo "$(date) Creating Common Services V3.4 Operand Request for BAI deployments on OCP 4.3+ ..\x1B[0m" >> ${LOG_FILE}
   operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandrequest34cr.yaml
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

   echo "$(date) Creating Common-Services V3.4 Operand Request for non-BAI deployments on OCP 4.3 .." >> ${LOG_FILE}
   operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandrequest34cr.yaml
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

function apply_registry(){

    echo "$(date) Defining sources for Release 3.4 of IBM Common Services." >> ${LOG_FILE}
    operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/app_registry.yaml
    oc apply -f ${operator_source_path} >>  ${LOG_FILE}
}

function create_project_cs() {
    project_name="common-service"
    isProjExists=`oc get project $project_name --ignore-not-found | wc -l`  >/dev/null 2>&1

   if [ $isProjExists -ne 2 ] ; then
        oc new-project ${project_name} >> ${LOG_FILE}
        returnValue=$?
        if [ "$returnValue" == 1 ]; then
            echo -e "$(date) Invalid project name, please enter a valid name..." >> ${LOG_FILE}
            project_name=""
        else
            echo -e "$(date) Create project ${project_name}..." >> ${LOG_FILE}
        fi
    else
        echo -e "$date : A Previous Installation & Project \"${project_name}\" already exists!!..Cleanup is required before deployment..exiting." >> ${LOG_FILE}
        exit
    fi
    PROJ_NAME=${project_name}

}


function create_operator_Group()
{
    echo "$(date) Creating Operator Group for Release 3.4..." >>  ${LOG_FILE}
    operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_group.yaml
    oc apply -f ${operator_source_path} >>  ${LOG_FILE}
    sleep 2
}

function create_operator_subscription()
{
    echo "$(date) Creating Operator Subscription for Release 3.4..." >>  ${LOG_FILE}
    operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_subscription.yaml
    oc apply -f ${operator_source_path} >>  ${LOG_FILE}
    sleep 2
}

function create_operator_request()
{
echo "$(date) Creating Operator Request CR for Release 3.4..." >> ${LOG_FILE}
operator_source_path=${PARENT_DIR}/descriptors/common-services/crds/operator_operandrequest34cr.yaml
oc apply -f ${operator_source_path} >>  ${LOG_FILE}
sleep 30
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
   PLATFORM_VERSION=">=4.4+"
   project_name="common-services, ibm-common-services"

    printf "\n"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    echo -e "\x1B[1m                    Summary of input                   \x1B[0m"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
    echo -e "\x1B[1;31m1. Cloud platform to deploy: ${PLATFORM_SELECTED} ${PLATFORM_VERSION}\x1B[0m"
    echo -e "\x1B[1;31m2. Project to deploy: ${project_name}\x1B[0m"
    echo -e "\x1B[1;31m3. CS Operators to be Installed: Licensing and Metering + dependencies \x1B[0m"
    echo -e "\x1B[1m*******************************************************\x1B[0m"
}
 

if [ "$product_install" == "bai" ]; then
 echo -e "*******************************************************" >> ${LOG_FILE}
  echo "$(date) bai deployment was selected" >> ${LOG_FILE}
  func_operand_request_cr_bai_34
  install_common_service_34

else
    echo -e "*******************************************************" >> ${LOG_FILE}
    echo "$(date) non-bai deployment was selected" >> ${LOG_FILE}
    
    func_operand_request_cr_nonbai_34
    install_common_service_34
fi

