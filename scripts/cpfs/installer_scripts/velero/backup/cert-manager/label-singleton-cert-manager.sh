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
CERT_MANAGER_NAMESPACE="ibm-cert-manager"

# Catalog sources and namespace
ENABLE_PRIVATE_CATALOG=0
CM_SOURCE="ibm-cert-manager-catalog"
CM_SOURCE_NS="openshift-marketplace"

# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# ---------- Main functions ----------

function main() {
    parse_arguments "$@"
    pre_req
    label_catalogsource
    label_ns_and_related 
    label_subscription
    label_cert_manager_resources
    success "Successfully labeled all the resources"
}

function print_usage(){ #TODO update usage definition
    script_name=`basename ${0}`
    echo "Usage: ${script_name} [OPTIONS]"
    echo ""
    echo "Label Cert Manager resources to prepare for Backup."
    echo "Cert Manager namespace is always required."
    echo ""
    echo "Options:"
    echo "   --oc string                    Optional. File path to oc CLI. Default uses oc in your PATH. Can also be set in env.properties."
    echo "   --cert-manager-ns              Optional. Specifying will enable labeling of the cert manager operator. Permissions may need to be updated to include the namespace."
    echo "   --enable-private-catalog       Optional. Specifying will look for catalog sources in the operator namespace. If enabled, will look for cert manager in its respective namespaces."
    echo "   --cert-manager-catalog         Optional. Specifying will look for the cert manager catalog source name."
    echo "   --cert-manager-catalog-ns      Optional. Specifying will look for the cert manager catalog source namespace."
    echo "   -h, --help                     Print usage information"
    echo ""
    
}

function parse_arguments() {
    script_name=`basename ${0}`
    echo "All arguments passed into the ${script_name}: $@"
    echo ""

    # process options
    while [[ "$@" != "" ]]; do
        case "$1" in
        --oc)
            shift
            OC=$1
            ;;
        --cert-manager-ns)
            shift
            CERT_MANAGER_NAMESPACE=$1
            ;;
        --enable-private-catalog)
            ENABLE_PRIVATE_CATALOG=1
            ;;
        --cert-manager-catalog)
            shift
            CM_SOURCE=$1
            ;;
        --cert-manager-catalog-ns)
            shift
            CM_SOURCE_NS=$1
            ;;
        -h | --help)
            print_usage
            exit 1
            ;;
        *)
            echo "Entered option $1 not supported. Run ./${script_name} -h for script usage info."
            ;;
        esac
        shift
    done
    echo ""
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
}

function label_catalogsource() {

    title "Start to label the Cert Manager catalog sources... "
    # Label the Private CatalogSources in provided namespaces
    if [ $ENABLE_PRIVATE_CATALOG -eq 1 ]; then
        CM_SOURCE_NS=$CERT_MANAGER_NAMESPACE
    fi
    ${OC} label catalogsource "$CM_SOURCE" foundationservices.cloudpak.ibm.com=catalog -n "$CM_SOURCE_NS" --overwrite=true 2>/dev/null
    echo ""
}

function label_ns_and_related() {

    title "Start to label the namespaces, operatorgroups... "

    # Label the cert manager namespace
    ${OC} label namespace "$CERT_MANAGER_NAMESPACE" foundationservices.cloudpak.ibm.com=namespace --overwrite=true 2>/dev/null
    
    # Label the cert manager OperatorGroup
    operator_group=$(${OC} get operatorgroup -n "$CERT_MANAGER_NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    ${OC} label operatorgroup "$operator_group" foundationservices.cloudpak.ibm.com=operatorgroup -n "$CERT_MANAGER_NAMESPACE" --overwrite=true 2>/dev/null
    
    echo ""
}


function label_subscription() {

    title "Start to label the Subscriptions... "
    local cm_pm="ibm-cert-manager-operator"
    ${OC} label subscriptions.operators.coreos.com $cm_pm foundationservices.cloudpak.ibm.com=singleton-subscription -n $CERT_MANAGER_NAMESPACE --overwrite=true 2>/dev/null
    echo ""
}

function label_cert_manager_resources(){
    title "Start to label the Cert Manager resources... "
    ${OC} label customresourcedefinition certmanagerconfigs.operator.ibm.com foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true 2>/dev/null
    ${OC} label customresourcedefinition certificates.cert-manager.io foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true 2>/dev/null
    ${OC} label customresourcedefinition issuers.cert-manager.io foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true 2>/dev/null
    info "Start to label the Cert Manager Configs"
    cert_manager_configs=$(${OC} get certmanagerconfigs.operator.ibm.com -n $CERT_MANAGER_NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    while IFS= read -r cert_manager_config; do
        ${OC} label certmanagerconfigs.operator.ibm.com $cert_manager_config foundationservices.cloudpak.ibm.com=cert-manager -n $CERT_MANAGER_NAMESPACE --overwrite=true 2>/dev/null
    done <<< "$cert_manager_configs"
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