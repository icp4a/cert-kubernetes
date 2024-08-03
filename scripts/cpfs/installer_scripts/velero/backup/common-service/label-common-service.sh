#!/usr/bin/env bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product.
# Please refer to that particular license for additional information.

set -o errtrace
set -o nounset

# ---------- Command arguments ----------
OC=oc

# Operator and Services namespaces
OPERATOR_NS=""
SERVICES_NS=""
CONTROL_NS=""
CERT_MANAGER_NAMESPACE="ibm-cert-manager"
LICENSING_NAMESPACE="ibm-licensing"
LSR_NAMESPACE="ibm-lsr"

# Catalog sources and namespace
ENABLE_PRIVATE_CATALOG=0
CS_SOURCE_NS="openshift-marketplace"
CM_SOURCE_NS="openshift-marketplace"
LIS_SOURCE_NS="openshift-marketplace"
LSR_SOURCE_NS="openshift-marketplace"

# Additional CatalogSources
ADDITIONAL_SOURCES=""

# default values no change
DEFAULT_SOURCE_NS="openshift-marketplace"

# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# ---------- Main functions ----------

source ${BASE_DIR}/env.properties

function main() {
    pre_req
    label_catalogsource
    label_ns_and_related 
    label_configmap
    label_subscription
    label_lsr
    label_cs
    success "Successfully labeled all the resources"
}

function pre_req(){

    title "Start to validate the parameters passed into script... "
    # Checking oc command logged in
    user=$($OC whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        error "You must be logged into the OpenShift Cluster from the oc command line"
    else
        success "oc command logged in as ${user}"
    fi
    if [ "$OPERATOR_NS" == "" ]; then
        error "Must provide operator namespace"
    else
        if ! $OC get namespace $OPERATOR_NS &>/dev/null; then
            error "Operator namespace $OPERATOR_NS does not exist, please provide a valid namespace"
        fi
    fi

    if [ "$SERVICES_NS" == "" ]; then
        warning "Services namespace is not provided, will use operator namespace as services namespace"
        SERVICES_NS=$OPERATOR_NS
    fi
}

function label_catalogsource() {
    ADDITIONAL_SOURCES=$(echo "$ADDITIONAL_SOURCES" | tr ',' ' ')

    title "Start to label the catalog sources... "
    # Label the Private CatalogSources in provided namespaces
    if [ $ENABLE_PRIVATE_CATALOG -eq 1 ]; then
        CS_SOURCE_NS=$OPERATOR_NS
        CM_SOURCE_NS=$CERT_MANAGER_NAMESPACE
        LIS_SOURCE_NS=$LICENSING_NAMESPACE
        LSR_SOURCE_NS=$LSR_NAMESPACE

        private_namespaces="$OPERATOR_NS,$CERT_MANAGER_NAMESPACE,$LICENSING_NAMESPACE,$LSR_NAMESPACE"
        private_namespaces=$(echo "$private_namespaces" | tr ',' '\n')

        while IFS= read -r namespace; do
            label_ibm_catalogsources "$namespace"
        done <<< "$private_namespaces"
    fi

    label_ibm_catalogsources "$DEFAULT_SOURCE_NS"
    echo ""
}

function label_ibm_catalogsources() {
    local namespace=$1

    # Label the CatalogSource with ".spec.publisher: IBM" in private namespace
    local ibm_catalogsources=""
    while IFS=' ' read -r -a sources; do
        for source in "${sources[@]}"; do
            if ${OC} get catalogsource "$source" -n "$namespace" -o json | grep -q '"publisher": *"IBM"*'; then
                ibm_catalogsources+=" $source"
            fi
        done
    done <<< "$(${OC} get catalogsource -n "$namespace" -o jsonpath='{.items[*].metadata.name}')"
    
    # Add additional catalog sources
    ibm_catalogsources="${ADDITIONAL_SOURCES}${ibm_catalogsources}"
    # Remove leading and trailing spaces
    ibm_catalogsources=$(echo "${ibm_catalogsources}" | tr -s ' ' | sed 's/^ *//g' | sed 's/ *$//g')
    for source in $ibm_catalogsources; do
         ${OC} label catalogsource "$source" foundationservices.cloudpak.ibm.com=catalog -n "$namespace" --overwrite=true 2>/dev/null
    done
}

function label_ns_and_related() {

    title "Start to label the namespaces, operatorgroups and secrets... "
    namespaces=$(${OC} get configmap namespace-scope -n $OPERATOR_NS -oyaml | awk '/^data:/ {flag=1; next} /^  namespaces:/ {print $2; next} flag && /^  [^ ]+: / {flag=0}')
    # add cert-manager namespace and licensing namespace and lsr namespace into the list with comma separated
    namespaces+=",$CONTROL_NS,$CERT_MANAGER_NAMESPACE,$LICENSING_NAMESPACE,$LSR_NAMESPACE"
    namespaces=$(echo "$namespaces" | tr ',' '\n')

    while IFS= read -r namespace; do
        # Label the namespace
        ${OC} label namespace "$namespace" foundationservices.cloudpak.ibm.com=namespace --overwrite=true 2>/dev/null
        
        # Label the OperatorGroup
        operator_group=$(${OC} get operatorgroup -n "$namespace" -o jsonpath='{.items[*].metadata.name}')
        ${OC} label operatorgroup "$operator_group" foundationservices.cloudpak.ibm.com=operatorgroup -n "$namespace" --overwrite=true 2>/dev/null
        
        # Label the entitlement key
        ${OC} label secret ibm-entitlement-key foundationservices.cloudpak.ibm.com=entitlementkey -n "$namespace" --overwrite=true 2>/dev/null
        
        # Label the OperandRequest
        operand_requests=$(${OC} get operandrequest -n "$namespace" -o custom-columns=NAME:.metadata.name --no-headers)
        # Loop through each OperandRequest name
        while IFS= read -r operand_request; do
            ${OC} label operandrequests $operand_request foundationservices.cloudpak.ibm.com=operand -n "$namespace" --overwrite=true 2>/dev/null
        done <<< "$operand_requests"

        # Label the Zen Service
        zen_services=$(${OC} get zenservice -n "$namespace" -o custom-columns=NAME:.metadata.name --no-headers)
        while IFS= read -r zen_service; do
            ${OC} label zenservice $zen_service foundationservices.cloudpak.ibm.com=zen -n "$namespace" --overwrite=true 2>/dev/null
        done <<< "$zen_services"
        echo ""

    done <<< "$namespaces"

    ${OC} label secret ibm-entitlement-key foundationservices.cloudpak.ibm.com=entitlementkey -n $DEFAULT_SOURCE_NS --overwrite=true 2>/dev/null
    ${OC} label secret pull-secret -n openshift-config foundationservices.cloudpak.ibm.com=pull-secret --overwrite=true 2>/dev/null
    echo ""
}

function label_configmap() {
    
    title "Start to label the ConfigMaps... "
    ${OC} label configmap common-service-maps foundationservices.cloudpak.ibm.com=configmap -n kube-public --overwrite=true 2>/dev/null
    ${OC} label configmap cs-onprem-tenant-config foundationservices.cloudpak.ibm.com=configmap -n $SERVICES_NS --overwrite=true 2>/dev/null
    ${OC} label configmap platform-auth-idp foundationservices.cloudpak.ibm.com=configmap -n $SERVICES_NS --overwrite=true 2>/dev/null
    echo ""
}

function label_subscription() {

    title "Start to label the Subscriptions... "
    local cs_pm="ibm-common-service-operator"
    local cm_pm="ibm-cert-manager-operator"
    local lis_pm="ibm-licensing-operator-app"
    local lsr_pm="ibm-license-service-reporter-operator"
    
    ${OC} label subscriptions.operators.coreos.com $cs_pm foundationservices.cloudpak.ibm.com=subscription -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label subscriptions.operators.coreos.com $cm_pm foundationservices.cloudpak.ibm.com=singleton-subscription -n $CERT_MANAGER_NAMESPACE --overwrite=true 2>/dev/null
    ${OC} label subscriptions.operators.coreos.com $lis_pm foundationservices.cloudpak.ibm.com=singleton-subscription -n $LICENSING_NAMESPACE --overwrite=true 2>/dev/null
    ${OC} label subscriptions.operators.coreos.com $lsr_pm foundationservices.cloudpak.ibm.com=lsr -n $LSR_NAMESPACE --overwrite=true 2>/dev/null
    echo ""
}

function label_lsr() {
    
    title "Start to label the License Service Reporter... "
    ${OC} label customresourcedefinition ibmlicenseservicereporters.operator.ibm.com foundationservices.cloudpak.ibm.com=lsr --overwrite=true 2>/dev/null

    info "Start to label the LSR instances"
    lsr_instances=$(${OC} get ibmlicenseservicereporters.operator.ibm.com -n $LSR_NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    while IFS= read -r lsr_instance; do
        ${OC} label ibmlicenseservicereporters.operator.ibm.com $lsr_instance foundationservices.cloudpak.ibm.com=lsr -n $LSR_NAMESPACE --overwrite=true 2>/dev/null
        
        # Label the secrets with OIDC configured
        client_secret_name=$(${OC} get ibmlicenseservicereporters.operator.ibm.com $lsr_instance -n $LSR_NAMESPACE -o yaml | awk -F '--client-secret-name=' '{print $2}' | tr -d '"' | tr -d '\n')
        ${OC} label secret $client_secret_name foundationservices.cloudpak.ibm.com=lsr -n $LSR_NAMESPACE --overwrite=true 2>/dev/null

        provider_ca_secret_name=$(${OC} get ibmlicenseservicereporters.operator.ibm.com $lsr_instance -n $LSR_NAMESPACE -o yaml | awk -F '--provider-ca-secret-name=' '{print $2}' | tr -d '"' | tr -d '\n')
        ${OC} label secret $provider_ca_secret_name foundationservices.cloudpak.ibm.com=lsr -n $LSR_NAMESPACE --overwrite=true 2>/dev/null
    done <<< "$lsr_instances"

    info "Start to label the necessary secrets"
    secrets=$(${OC} get secrets -n $LSR_NAMESPACE | grep ibm-license-service-reporter-token | cut -d ' ' -f1)
    for secret in ${secrets[@]}; do
        ${OC} label secret $secret foundationservices.cloudpak.ibm.com=lsr -n $LSR_NAMESPACE --overwrite=true 2>/dev/null
    done    
    secrets=$(${OC} get secrets -n $LSR_NAMESPACE | grep ibm-license-service-reporter-credential | cut -d ' ' -f1)
    for secret in ${secrets[@]}; do
        ${OC} label secret $secret foundationservices.cloudpak.ibm.com=lsr -n $LSR_NAMESPACE --overwrite=true 2>/dev/null
    done

    echo ""
}

function label_cs(){
    
    title "Start to label the CommonService CR... "
    ${OC} label customresourcedefinition commonservices.operator.ibm.com foundationservices.cloudpak.ibm.com=crd --overwrite=true 2>/dev/null
    ${OC} label commonservices common-service foundationservices.cloudpak.ibm.com=commonservice -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label operandconfig common-service foundationservices.cloudpak.ibm.com=operand -n $SERVICES_NS --overwrite=true 2>/dev/null
    echo ""
}

# ---------- Info functions ----------#

function msg() {
    printf '%b\n' "$1"
}

function success() {
    msg "\33[32m[✔] ${1}\33[0m"
}

function error() {
    msg "\33[31m[✘] ${1}\33[0m"
    exit 1
}

function title() {
    msg "\33[34m# ${1}\33[0m"
}

function info() {
    msg "[INFO] ${1}"
}

function warning() {
    msg "\33[33m[✗] ${1}\33[0m"
}

main $*

# ---------------- finish ----------------