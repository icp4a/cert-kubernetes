#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2021, 2023. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
# Removes IAF components from CP4BA deployment
# CLOUD_PAK_CR_KIND="icp4aclusters.icp4a.ibm.com" or "contents.icp4a.ibm.com"
# CLOUD_PAK_CR_NAME="icp4adeploy" # empty for any
# CLOUD_PAK_NAMESPACE="cp4ba-test"
# FOUNDATION_NAMESPACE="cs-control"
# CARTRIDGE_NAME="icp4ba"
# DRY_RUN="none" # none|client|server

function show_help() {
    echo -e "\nUsage: remove_iaf.sh <CLOUD_PAK_CR_KIND> <CLOUD_PAK_CR_NAME> <CLOUD_PAK_NAMESPACE> <FOUNDATION_NAMESPACE> <CARTRIDGE_NAME> <DRY_RUN>\n"
    echo "Options:"
    echo "  -h  Display the help"
}
while getopts "h?s:n:m:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    esac
done

function msg() {

  printf '\n%b\n' "$1"

}

function success() {

  msg "\33[32m[✔] ${1}\33[0m"

}

function info() {

  msg "\x1B[33;5m[INFO] \x1B[0m${1}"

}

function fail() {

  msg "\33[31m[FAILED] ${1}\33[0m"

}

function msgB() {

  echo -e "\x1B[1m${1}\x1B[0m\n"

}
function patch_finalizers(){

  f_count=$(oc get $resource -n ${CLOUD_PAK_NAMESPACE} -o yaml| grep finalizers|wc -l|xargs)
  if [ $f_count -gt 0 ]; then
    oc -n ${CLOUD_PAK_NAMESPACE} patch ${resource} --dry-run=${DRY_RUN} --type=json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
    sleep 2
    f2_count=$(oc get $resource -n ${CLOUD_PAK_NAMESPACE} -o yaml| grep finalizers|wc -l|xargs)
    # patch again if finalizers still there
    if [ $f2_count -gt 0 ]; then
      oc -n ${CLOUD_PAK_NAMESPACE} patch ${resource} --dry-run=${DRY_RUN} --type=json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
      sleep 2
    else 
      info "Finalizers in $resource already been removed."
    fi
  else 
    info "NO finalizers in $resource"
  fi
  
}

CLOUD_PAK_CR_KIND=$1
CLOUD_PAK_CR_NAME=$2
CLOUD_PAK_NAMESPACE=$3
FOUNDATION_NAMESPACE=$4
CARTRIDGE_NAME=$5
DRY_RUN=$6 # none|client|server

if [[ "${CLOUD_PAK_CR_KIND}" =~ "icp4acluster" ]] || [[ "${CLOUD_PAK_CR_KIND}" =~ "content" ]] ; then
  info "Input: CLOUD_PAK_CR_KIND is ${CLOUD_PAK_CR_KIND}"
else
  fail "Please provide CLOUD_PAK_CR_KIND as icp4acluster or content !!"
  exit 1
fi

if [[ -n "${CLOUD_PAK_CR_NAME}" ]] ; then
  info "Input: CLOUD_PAK_CR_NAME is ${CLOUD_PAK_CR_NAME}"
else
  fail "Please provide CLOUD_PAK_CR_NAME !!"
  exit 1
fi

if [[ -n "${CLOUD_PAK_NAMESPACE}" ]] ; then
  info "Input: CLOUD_PAK_NAMESPACE is ${CLOUD_PAK_NAMESPACE}"
else
  fail "Please provide CLOUD_PAK_NAMESPACE. It is the namespace which CP4BA instance deployed, please find it and provide as the Third parameter !!"
  exit 1
fi

if [[ -n "${FOUNDATION_NAMESPACE}" ]] ; then
  info "Input: FOUNDATION_NAMESPACE is ${FOUNDATION_NAMESPACE}"
else
  fail "Please provide FOUNDATION_NAMESPACE. It is the CS contol namespace which is defined in \"common-service-maps\" configmap \"kube-public\" namespace, please find it and provide as the Fourth parameter !! Note: If you do NOT find \"common-service-maps\" configmap, please set FOUNDATION_NAMESPACE as \"ibm-common-services\". "
  exit 1
fi 

if [[ -n "${CARTRIDGE_NAME}" ]] ; then
  info "Input: CARTRIDGE_NAME is ${CARTRIDGE_NAME}"
else
  fail "Please provide CARTRIDGE_NAME. It is \"icp4ba\" for CP4BA instance, please provide it as the Fifth parameter !!"
  exit 1
fi 

if [[ "${DRY_RUN}" == "none" ]] || [[ "${DRY_RUN}" == "client" ]] || [[ "${DRY_RUN}" == "server" ]]  ; then
  info "Input: DRY_RUN is ${DRY_RUN}"
else
  fail "Please provide DRY_RUN as none|client|server , ${DRY_RUN} is not valid input, please correct it !!"
  exit 1
fi 

PATCH_INVENTORY=(
  "Certificate.cert-manager.io/foundation-iaf-automationbase-ab-ss-ca"
  "Certificate.cert-manager.io/iaf-system-elasticsearch-es-ss-ca"
  "Certificate.cert-manager.io/iaf-system-automationui-aui-zen-ca"
  "Certificate.cert-manager.io/iaf-system-automationui-aui-zen-cert"
  "Certificate.cert-manager.io/iaf-system-elasticsearch-es-client-cert"
  "Issuer.cert-manager.io/iaf-system-automationui-aui-zen-issuer"
  "Issuer.cert-manager.io/iaf-system-automationui-aui-zen-ss-issuer"
  "Issuer.cert-manager.io/foundation-iaf-automationbase-ab-issuer"
  "Issuer.cert-manager.io/foundation-iaf-automationbase-ab-ss-issuer"
  "Issuer.cert-manager.io/iaf-system-elasticsearch-es-issuer"
  "Issuer.cert-manager.io/iaf-system-elasticsearch-es-ss-issuer"
  "Secret/foundation-iaf-automationbase-ab-ca"
#  "Secret/foundation-iaf-automationbase-ab-ss-ca"
  "Secret/iaf-system-cluster-ca"
  "Secret/iaf-system-cluster-ca-cert"
  "Secret/iaf-system-bindinfo"
  "Secret/external-tls-secret"
  "Secret/icp4ba-kafka-auth-0-bindinfo"
  "KafkaClaim.shim.bedrock.ibm.com/iaf-system"     
  "KafkaClaim.shim.bedrock.ibm.com/${CARTRIDGE_NAME}-kafka-auth-0"
  "CommonService.operator.ibm.com/iaf-system"         
  "Elasticsearch.elastic.automation.ibm.com/iaf-system"
  "KafkaClaim/iaf-system"
  "KafkaClaim/${CARTRIDGE_NAME}-kafka-auth-0"
  "Secret/icp4ba-es-auth"
  "PersistentVolumeClaim/${CLOUD_PAK_CR_NAME}-bai-pvc"
)

DELETE_INVENTORY=(
  "CartridgeRequirements.base.automation.ibm.com/icp4ba"
  "CartridgeRequirements.base.automation.ibm.com/insights-engine"
  "AutomationBase.base.automation.ibm.com/foundation-iaf"
  "Cartridge.core.automation.ibm.com/icp4ba"
  "AutomationUIConfig.core.automation.ibm.com/iaf-system"
  "InsightsEngine.insightsengine.automation.ibm.com/iaf-insights-engine"
#  "EventProcessor.eventprocessing.automation.ibm.com/iaf-insights-engine-event-processor"
)
# Validate that Cloud Pak install exists before continuing
CR_COUNT=$(oc get --no-headers --ignore-not-found ${CLOUD_PAK_CR_KIND} -n ${CLOUD_PAK_NAMESPACE} ${CLOUD_PAK_CR_NAME} | wc -l | xargs)
if [ $CR_COUNT -gt 0 ]; then
  info "Found Cloud Pak CR in namespace"
else
  fail "No Cloud Pak CR found in namespace $CLOUD_PAK_NAMESPACE"
  exit 1
fi

OPERATOR_NAMESPACE=$CLOUD_PAK_NAMESPACE

CP4BA_SUB_COUNT=$(oc get sub --no-headers --ignore-not-found  -n ${CLOUD_PAK_NAMESPACE}|grep ibm-cp4a-operator | wc -l | xargs)
if [ $CP4BA_SUB_COUNT -gt 0 ]; then
  OPERATOR_NAMESPACE=$CLOUD_PAK_NAMESPACE 
  info "Found CP4BA Subscription in namespace $OPERATOR_NAMESPACE"
else
  CP4BA_SUB_COUNT=$(oc get sub --no-headers --ignore-not-found  -n openshift-operators |grep ibm-cp4a-operator | wc -l | xargs)
  if [ $CP4BA_SUB_COUNT -gt 0 ]; then
    OPERATOR_NAMESPACE=openshift-operators
    info "Found CP4BA Subscription in namespace $OPERATOR_NAMESPACE"
  else
    info "NOT Found CP4BA Subscription in namespace $CLOUD_PAK_NAMESPACE and openshift-operators ."
  fi
fi

sleep 10
# TODO: Remove/disable IBM CP4BA Orchestrator?
info "Discovering and deleting IBM Automation Foundation Subscriptions and ClusterServiceVersions"
#oc -n ${CLOUD_PAK_NAMESPACE} get subs,csv -o name | grep ibm-automation | grep -v "elastic\|flink" | xargs oc delete -n ${CLOUD_PAK_NAMESPACE} --wait --dry-run=${DRY_RUN}  # TODO: Fully qualify subscription/csv
iaf_count=$(oc get subs,csv -o name --no-headers --ignore-not-found -n ${OPERATOR_NAMESPACE}| grep ibm-automation |wc -l|xargs)
while [[ "$iaf_count" -gt 0 ]] ;
do
  oc -n ${OPERATOR_NAMESPACE} get subs,csv -o name --ignore-not-found| grep ibm-automation | xargs oc delete -n ${OPERATOR_NAMESPACE} --wait --dry-run=${DRY_RUN}  # TODO: Fully qualify subscription/csv
  if [[ "${DRY_RUN}" == "none" ]] ; then 
    sleep 10
    iaf_count=$(oc get subs,csv -o name --no-headers --ignore-not-found -n ${OPERATOR_NAMESPACE}| grep ibm-automation |wc -l|xargs)
  else
    iaf_count=0
  fi
done

# Can we use cascade=orphan for delete instead of removing references?
info "Getting resources to remove ownerReferences. Errors will log for missing resources or resources with no ownerReferences. They may be ignored."
for resource in ${PATCH_INVENTORY[@]}; do
  o_count=$(oc get $resource --ignore-not-found -n ${CLOUD_PAK_NAMESPACE} -o yaml|grep ownerReferences: |wc -l|xargs)
  if [ $o_count -gt 0 ]; then
    oc -n ${CLOUD_PAK_NAMESPACE} patch ${resource} --dry-run=${DRY_RUN} --type=json -p='[{"op": "remove", "path": "/metadata/ownerReferences"}]'
  else
    info "NO ownerReferences in $resource"
  fi
done

# Can we use cascade=orphan for delete instead of removing references?
info "Removing IBM Automation Foundation Resources - AutomationBase, AutomationUIConfig, Cartridge, CartridgeRequirements, InsightsEngine(Eventprocessor)"
iaf_count=$(oc get subs,csv -o name --no-headers --ignore-not-found -n ${OPERATOR_NAMESPACE}| grep ibm-automation |wc -l|xargs)
if [ $iaf_count -gt 0 ]; then
  fail "IBM Automation Foundation Subscriptions and ClusterServiceVersions still there, please rerun this script again."
  exit 1
fi
for resource in ${DELETE_INVENTORY[@]}; do
  # check if finalizers exist
  count=$(oc get --no-headers --ignore-not-found $resource -n ${CLOUD_PAK_NAMESPACE}|wc -l|xargs)
  if [ $count -gt 0 ]; then
    info "Found $resource"
    # Patch to remove finalizer
    patch_finalizers
    oc -n ${CLOUD_PAK_NAMESPACE} delete ${resource} --dry-run=${DRY_RUN} # --cascade=orphan
  else
    info "NO $resource"
  fi
done

# Disable crossplane
info "Disable crossplane"
cs_count=$(oc -n ${CLOUD_PAK_NAMESPACE} get CommonService.operator.ibm.com/iaf-system --ignore-not-found|wc -l|xargs)
if [ $cs_count -gt 0 ]; then
  oc -n ${CLOUD_PAK_NAMESPACE} patch CommonService.operator.ibm.com/iaf-system --dry-run=${DRY_RUN} --type=merge -p '{"spec":{"features": {"bedrockshim": {"crossplaneProviderRemoval": true}}}}'
  # Sleep to allow CommonService CR to be processed - waiting on "Updating" condition is not idempotent after the first run-through
  sleep 5
  # Wait for CommonService to be successful after the update
  oc wait --for=jsonpath='{.status.phase}'="Succeeded" CommonService.operator.ibm.com/iaf-system
fi
# Remove Crossplane Subscription/CSV
info "Discovering and deleting IBM Crossplane Subscriptions and ClusterServiceVersions"
crossplane_count=$(oc -n ${FOUNDATION_NAMESPACE} get subs,csv -o name --ignore-not-found| grep ibm-crossplane-operator |wc -l|xargs)
while [[ "$crossplane_count" -gt 0 ]] ;
do
  oc -n ${FOUNDATION_NAMESPACE} get subs,csv -o name --ignore-not-found| grep ibm-crossplane-operator | xargs oc delete -n ${FOUNDATION_NAMESPACE} --wait --dry-run=${DRY_RUN}  
  if [[ "${DRY_RUN}" == "none" ]] ; then 
    sleep 10
    crossplane_count=$(oc -n ${FOUNDATION_NAMESPACE} get subs,csv -o name --ignore-not-found| grep ibm-crossplane-operator |wc -l|xargs)
  else
    crossplane_count=0
  fi
done
# Remove KafkaClaim resources
k_count=$(oc get --no-headers --ignore-not-found KafkaClaim -n ${CLOUD_PAK_NAMESPACE}|wc -l|xargs)
if [ $k_count -gt 0 ]; then
  info "Patch IBM Crossplane Custom Resources KafkaClaim"
  oc -n ${CLOUD_PAK_NAMESPACE} patch KafkaClaim iaf-system ${CARTRIDGE_NAME}-kafka-auth-0 --dry-run=${DRY_RUN} --type=json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
  oc -n ${CLOUD_PAK_NAMESPACE} delete KafkaClaim iaf-system ${CARTRIDGE_NAME}-kafka-auth-0 --ignore-not-found --wait --dry-run=${DRY_RUN}

else
    info "NO KafkaClaim CR"
fi
sleep 10
crossplane_count=$(oc -n ${FOUNDATION_NAMESPACE} get subs,csv -o name --ignore-not-found| grep ibm-crossplane-operator |wc -l|xargs)
if [[ "$crossplane_count" -gt 0 ]] ; then
  oc -n ${FOUNDATION_NAMESPACE} get subs,csv -o name --ignore-not-found| grep ibm-crossplane-operator | xargs oc delete -n ${FOUNDATION_NAMESPACE} --wait --dry-run=${DRY_RUN}  
else
  info "NO Crossplane subs,csv in ${FOUNDATION_NAMESPACE}"
fi

sleep 20
iaf_count=$(oc get subs,csv -o name --no-headers --ignore-not-found -n ${OPERATOR_NAMESPACE}| grep ibm-automation |wc -l|xargs)
if [ $iaf_count -gt 0 ]; then
  info "Discovering and deleting IBM Automation Foundation Subscriptions and ClusterServiceVersions"
  oc -n ${OPERATOR_NAMESPACE} get subs,csv -o name | grep ibm-automation | xargs oc delete -n ${OPERATOR_NAMESPACE} --wait --dry-run=${DRY_RUN}  # TODO: Fully qualify subscription/csv
else
  info "NO IAF subs,csv in ${OPERATOR_NAMESPACE}"
fi

