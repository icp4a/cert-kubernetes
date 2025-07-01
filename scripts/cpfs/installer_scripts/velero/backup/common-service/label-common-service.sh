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

# ---------- Enable No OLM --------------
NO_OLM="false"
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
ENABLE_CERT_MANAGER=0
ENABLE_LICENSING=0
ENABLE_LSR=0
ENABLE_DEEFAULT_CS=0
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
    parse_arguments "$@"
    pre_req
    if [[ $NO_OLM == "false" ]]; then
        label_catalogsource
        label_subscription
    else
        label_helm_cluster_scope
        label_helm_namespace_scope
        if [[ $ENABLE_LICENSING -eq 1 ]]; then
            label_helm_licensing
        fi
        if [[ $ENABLE_LSR -eq 1 ]]; then
            label_helm_lsr
        fi
    fi
    label_ns_and_related 
    label_configmap
    label_cs
    if [[ $SERVICES_NS != "" ]]; then
        label_nss
    fi
    if [[ $ENABLE_LSR -eq 1 ]]; then
        label_lsr
    fi
    label_mcsp
    success "Successfully labeled all the resources"
}

function print_usage(){ #TODO update usage definition
    script_name=`basename ${0}`
    echo "Usage: ${script_name} [OPTIONS]"
    echo ""
    echo "Label Bedrock resources to prepare for Backup."
    echo "Operator namespace is always required. If using a separation of duties topology, make sure to include services and tethered namespaces."
    echo "This script assumes the following:"
    echo "    * An existing CPFS instance installed in the namespaces entered as parameters."
    echo "    * Filled in required variables in the accompanying env.properties file"
    echo ""
    echo "Options:"
    echo "   --oc string                    Optional. File path to oc CLI. Default uses oc in your PATH. Can also be set in env.properties."
    echo "   --operator-ns                  Required. Namespace where Bedrock operators are deployed."
    echo "   --services-ns                  Optional. Namespace where Bedrock operands are deployed. Only optional if not using Separation of Duties topology."
    echo "   --tethered-ns                  Optional. Comma-delimitted list of tethered namespaces using Bedrock services located in operator and services namespaces."
    echo "   --control-ns                   Optional. Only necessary if tenant included is Bedrock LTSR (v3.19.x or 3.23.x)."
    echo "   --cert-manager-ns              Optional. Specifying will enable labeling of the cert manager operator. Permissions may need to be updated to include the namespace."
    echo "   --licensing-ns                 Optional. Specifying will enable labeling of the licensing operator and its resources. Permissions may need to be updated to include the namespace."
    echo "   --lsr-ns                       Optional. Specifying will enable labeling of the license service reporter operator and its resources. Permissions may need to be updated to include the namespace."
    echo "   --enable-private-catalog       Optional. Specifying will look for catalog sources in the operator namespace. If enabled, will look for cert manager, licensing, and lsr catalogs in their respective namespaces."
    echo "   --enable-default-catalog-ns    Optional. Specifying will label all IBM published catalog sources in openshift-marketplace namespace."
    echo "   --additional-catalog-sources   Optional. Comma-delimted list of non-default catalog sources to be labeled."
    echo "   --no-olm                       Optional. Toggles script to backup helm-based install resources instead of OLM-based resources. 4.12+"
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
        --operator-ns)
            shift
            OPERATOR_NS=$1
            ;;
        --services-ns)
            shift
            SERVICES_NS=$1
            ;;
        --tethered-ns)
            shift
            TETHERED_NS=$1
            ;;
        --control-ns)
            shift
            CONTROL_NS=$1
            ;;
        --cert-manager-ns)
            shift
            CERT_MANAGER_NAMESPACE=$1
            ENABLE_CERT_MANAGER=1
            ;;
        --licensing-ns)
            shift
            LICENSING_NAMESPACE=$1
            ENABLE_LICENSING=1
            ;;
        --lsr-ns)
            shift
            LSR_NAMESPACE=$1
            ENABLE_LSR=1
            ;;
        --enable-private-catalog)
            ENABLE_PRIVATE_CATALOG=1
            ;;
        --enable-default-catalog-ns)
            ENABLE_DEEFAULT_CS=1
            ;;
        --additional-catalog-sources)
            shift
            ADDITIONAL_SOURCES=$1
            ;;
        --no-olm)
            NO_OLM="true"
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

        private_namespaces="$OPERATOR_NS"
        if [[ $ENABLE_CERT_MANAGER -eq 1 ]]; then
            private_namespaces+=",$CERT_MANAGER_NAMESPACE"
        fi
        if [[ $ENABLE_LICENSING -eq 1 ]]; then
            private_namespaces+=",$LICENSING_NAMESPACE"
        fi
        if [[ $ENABLE_LSR -eq 1 ]]; then
            private_namespaces+=",$LSR_NAMESPACE"
        fi
        private_namespaces=$(echo "$private_namespaces" | tr ',' '\n')

        while IFS= read -r namespace; do
            label_ibm_catalogsources "$namespace"
        done <<< "$private_namespaces"
    fi
    if [[ $ENABLE_DEEFAULT_CS -eq 1 ]]; then
        label_ibm_catalogsources "$DEFAULT_SOURCE_NS"
    fi
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
    if [[ $CONTROL_NS != "" ]]; then
        namespaces+=",$CONTROL_NS"
    fi
    if [[ $ENABLE_CERT_MANAGER -eq 1 ]]; then
        namespaces+=",$CERT_MANAGER_NAMESPACE"
    fi
    if [[ $ENABLE_LICENSING -eq 1 ]]; then
        namespaces+=",$LICENSING_NAMESPACE"
    fi
    if [[ $ENABLE_LSR -eq 1 ]]; then
        namespaces+=",$LSR_NAMESPACE"
    fi

    namespaces=$(echo "$namespaces" | tr ',' '\n')

    while IFS= read -r namespace; do
        # Label the namespace
        ${OC} label namespace "$namespace" foundationservices.cloudpak.ibm.com=namespace --overwrite=true 2>/dev/null
        
        if [[ $NO_OLM == "false" ]]; then
            # Label the OperatorGroup
            operator_group=$(${OC} get operatorgroup -n "$namespace" -o jsonpath='{.items[*].metadata.name}')
            ${OC} label operatorgroup "$operator_group" foundationservices.cloudpak.ibm.com=operatorgroup -n "$namespace" --overwrite=true 2>/dev/null
        fi

        # Label the entitlement key
        #TODO check for a the pull secret to be a different name in case of no olm, will be defined in one of the deployments
        ${OC} label secret ibm-entitlement-key foundationservices.cloudpak.ibm.com=entitlementkey -n "$namespace" --overwrite=true 2>/dev/null
        
        # Label the OperandRequest
        operand_requests=$(${OC} get operandrequest -n "$namespace" -o custom-columns=NAME:.metadata.name --no-headers)
        # Loop through each OperandRequest name
        while IFS= read -r operand_request; do
            # Skip all the operandrequest with ownerreference
            ownerReferences=$(${OC} get operandrequest $operand_request -n "$namespace" -o jsonpath='{.metadata.ownerReferences}')
            if [[ $ownerReferences != "" ]]; then
                continue
            fi
            # Skip all the operandrequest generate by ODLM
            control_by_odlm=$(${OC} get operandrequest $operand_request -n "$namespace" --show-labels --no-headers | grep "operator.ibm.com/opreq-control=true" || echo "false")
            if [[ $control_by_odlm != "false" ]]; then
                continue
            fi
            
            ${OC} label operandrequests $operand_request foundationservices.cloudpak.ibm.com=operand -n "$namespace" --overwrite=true 2>/dev/null
        done <<< "$operand_requests"

        # Label the Zen Service
        if [[ $NO_OLM == "false" ]]; then
            ${OC} label customresourcedefinition zenservices.zen.cpd.ibm.com zenextensions.zen.cpd.ibm.com foundationservices.cloudpak.ibm.com=zen --overwrite=true 2>/dev/null
        else
            ${OC} label customresourcedefinition zenservices.zen.cpd.ibm.com zenextensions.zen.cpd.ibm.com foundationservices.cloudpak.ibm.com=zen-cluster --overwrite=true 2>/dev/null
        fi
        zen_services=$(${OC} get zenservice -n "$namespace" -o custom-columns=NAME:.metadata.name --no-headers)
        while IFS= read -r zen_service; do
            if [[ $NO_OLM == "false" ]]; then
                ${OC} label zenservice $zen_service foundationservices.cloudpak.ibm.com=zen -n "$namespace" --overwrite=true 2>/dev/null
            else
                ${OC} label zenservice $zen_service foundationservices.cloudpak.ibm.com=zen-chart -n "$namespace" --overwrite=true 2>/dev/null
            fi
        done <<< "$zen_services"
        echo ""

    done <<< "$namespaces"

    #TODO need to ensure we label this script in the operator namespace as well
    ${OC} label secret ibm-entitlement-key foundationservices.cloudpak.ibm.com=entitlementkey -n $DEFAULT_SOURCE_NS --overwrite=true 2>/dev/null
    #TODO need to toggle labeling this due to permission issues
    ${OC} label secret pull-secret -n openshift-config foundationservices.cloudpak.ibm.com=pull-secret --overwrite=true 2>/dev/null
    echo ""
}

function label_configmap() {
    
    title "Start to label the ConfigMaps... "
    ${OC} label configmap common-service-maps foundationservices.cloudpak.ibm.com=configmap -n kube-public --overwrite=true 2>/dev/null
    ${OC} label configmap cs-onprem-tenant-config foundationservices.cloudpak.ibm.com=configmap -n $SERVICES_NS --overwrite=true 2>/dev/null
    ${OC} label configmap common-web-ui-config foundationservices.cloudpak.ibm.com=configmap -n $SERVICES_NS --overwrite=true 2>/dev/null
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
    if [[ $ENABLE_CERT_MANAGER -eq 1 ]]; then
        ${OC} label subscriptions.operators.coreos.com $cm_pm foundationservices.cloudpak.ibm.com=singleton-subscription -n $CERT_MANAGER_NAMESPACE --overwrite=true 2>/dev/null
    fi
    if [[ $ENABLE_LICENSING -eq 1 ]]; then
        ${OC} label subscriptions.operators.coreos.com $lis_pm foundationservices.cloudpak.ibm.com=singleton-subscription -n $LICENSING_NAMESPACE --overwrite=true 2>/dev/null
    fi
    if [[ $ENABLE_LSR -eq 1 ]]; then
        ${OC} label subscriptions.operators.coreos.com $lsr_pm foundationservices.cloudpak.ibm.com=lsr -n $LSR_NAMESPACE --overwrite=true 2>/dev/null
    fi
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
    echo ""
}

function label_nss(){
    title "Label Namespacescope resources"
    local nss_pm="ibm-namespace-scope-operator"
    # Using the same label as common service operator has for both sub and crd
    if [[ $NO_OLM == "false" ]]; then
        ${OC} label subscriptions.operators.coreos.com $nss_pm foundationservices.cloudpak.ibm.com=subscription -n $OPERATOR_NS --overwrite=true 2>/dev/null
        ${OC} label customresourcedefinition namespacescopes.operator.ibm.com foundationservices.cloudpak.ibm.com=crd --overwrite=true 2>/dev/null
    else
        #cluster scoped resources
        ${OC} label clusterrole ibm-namespace-scope-operator foundationservices.cloudpak.ibm.com=nss-cluster --overwrite=true 2>/dev/null
        ${OC} label clusterrolebinding ibm-namespace-scope-operator foundationservices.cloudpak.ibm.com=nss-cluster --overwrite=true 2>/dev/null
        ${OC} label customresourcedefinition namespacescopes.operator.ibm.com foundationservices.cloudpak.ibm.com=nss-cluster --overwrite=true 2>/dev/null
        nss_cluster_release_name=$(${OC} get crd namespacescopes.operator.ibm.com -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
        nss_cluster_release_namespace=$(${OC} get crd namespacescopes.operator.ibm.com -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
        ${OC} label secret sh.helm.release.v1.$nss_cluster_release_name.v1 -n $nss_cluster_release_namespace foundationservices.cloudpak.ibm.com=nss-cluster  --overwrite=true 2>/dev/null
        #namespace scoped resources
        ${OC} label deployment ibm-namespace-scope-operator foundationservices.cloudpak.ibm.com=nss -n $OPERATOR_NS --overwrite=true 2>/dev/null
        nss_release_name=$(${OC} get deploy ibm-namespace-scope-operator -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
        nss_release_namespace=$(${OC} get deploy ibm-namespace-scope-operator -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
        ${OC} label secret sh.helm.release.v1.$nss_release_name.v1 -n $nss_release_namespace foundationservices.cloudpak.ibm.com=nss  --overwrite=true 2>/dev/null
        ${OC} label role ibm-namespace-scope-operator -n $OPERATOR_NS foundationservices.cloudpak.ibm.com=nss  --overwrite=true 2>/dev/null
        ${OC} label rolebinding ibm-namespace-scope-operator -n $OPERATOR_NS foundationservices.cloudpak.ibm.com=nss  --overwrite=true 2>/dev/null
    fi

    # The following resources are labeled with 'nss' are bundled together for backup
    ${OC} label namespacescopes.operator.ibm.com common-service foundationservices.cloudpak.ibm.com=nss -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label serviceaccount ibm-namespace-scope-operator foundationservices.cloudpak.ibm.com=nss -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role nss-managed-role-from-$OPERATOR_NS foundationservices.cloudpak.ibm.com=nss -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role nss-managed-role-from-$OPERATOR_NS foundationservices.cloudpak.ibm.com=nss -n $SERVICES_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding nss-managed-role-from-$OPERATOR_NS foundationservices.cloudpak.ibm.com=nss -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding nss-managed-role-from-$OPERATOR_NS foundationservices.cloudpak.ibm.com=nss -n $SERVICES_NS --overwrite=true 2>/dev/null
    if [[ $TETHERED_NS != "" ]]; then
        for namespace in ${TETHERED_NS//,/ }
        do
            ${OC} label role nss-managed-role-from-$OPERATOR_NS foundationservices.cloudpak.ibm.com=nss -n $namespace --overwrite=true 2>/dev/null
            ${OC} label rolebinding nss-managed-role-from-$OPERATOR_NS foundationservices.cloudpak.ibm.com=nss -n $namespace --overwrite=true 2>/dev/null
        done
    fi
    echo ""
}

function label_mcsp(){

    title "Start to label mcsp resources"
    ${OC} label secret user-mgmt-bootstrap foundationservices.cloudpak.ibm.com=user-mgmt -n $SERVICES_NS --overwrite=true 2>/dev/null
    echo ""
}

function label_helm_cluster_scope(){
    title "Begin labeling cluster scoped resources installed via helm..."
    #TODO get name of helm secret for each chart
    #odlm cluster resources (crds)
    ${OC} label crd operandbindinfos.operator.ibm.com operandconfigs.operator.ibm.com operandregistries.operator.ibm.com operandrequests.operator.ibm.com operatorconfigs.operator.ibm.com foundationservices.cloudpak.ibm.com=odlm-cluster  --overwrite=true 2>/dev/null
    #helm secret
    odlm_release_name=$(${OC} get crd operandbindinfos.operator.ibm.com -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    odlm_release_namespace=$(${OC} get crd operandbindinfos.operator.ibm.com -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$odlm_release_name.v1 -n $odlm_release_namespace foundationservices.cloudpak.ibm.com=odlm-cluster  --overwrite=true 2>/dev/null

    #cs operator cluster resources (crds, clusterrole, clusterrolebinding), crd covered elsewhere in script
    ${OC} label clusterrole ibm-common-service-operator-$OPERATOR_NS foundationservices.cloudpak.ibm.com=cs-cluster  --overwrite=true 2>/dev/null
    ${OC} label clusterrolebinding ibm-common-service-operator-$OPERATOR_NS foundationservices.cloudpak.ibm.com=cs-cluster  --overwrite=true 2>/dev/null
    cs_release_name=$(${OC} get crd commonservices.operator.ibm.com -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    cs_release_namespace=$(${OC} get crd commonservices.operator.ibm.com -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$cs_release_name.v1 -n $cs_release_namespace foundationservices.cloudpak.ibm.com=cs-cluster  --overwrite=true 2>/dev/null

    #IM operator cluster resources (crds, clusterrole, clusterrolebinding)
    ${OC} label crd clients.oidc.security.ibm.com authentications.operator.ibm.com foundationservices.cloudpak.ibm.com=iam-cluster  --overwrite=true 2>/dev/null
    ${OC} label clusterrole ibm-iam-operator-$OPERATOR_NS foundationservices.cloudpak.ibm.com=iam-cluster  --overwrite=true 2>/dev/null
    ${OC} label clusterrolebinding ibm-iam-operator-$OPERATOR_NS foundationservices.cloudpak.ibm.com=iam-cluster  --overwrite=true 2>/dev/null
    im_release_name=$(${OC} get crd authentications.operator.ibm.com -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    im_release_namespace=$(${OC} get crd authentications.operator.ibm.com -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$im_release_name.v1 -n $im_release_namespace foundationservices.cloudpak.ibm.com=iam-cluster  --overwrite=true 2>/dev/null

    #UI (crds)
    ${OC} label crd commonwebuis.operators.ibm.com navconfigurations.foundation.ibm.com switcheritems.operators.ibm.com foundationservices.cloudpak.ibm.com=ui-cluster  --overwrite=true 2>/dev/null
    ui_release_name=$(${OC} get crd commonwebuis.operators.ibm.com -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    ui_release_namespace=$(${OC} get crd commonwebuis.operators.ibm.com -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$ui_release_name.v1 -n $ui_release_namespace foundationservices.cloudpak.ibm.com=ui-cluster  --overwrite=true 2>/dev/null

    #edb (crds, clusterrole, clusterrolebinding, webhooks) 
    #TODO verify none of this info changes
    ${OC} label crd backups.postgresql.k8s.enterprisedb.io clusters.postgresql.k8s.enterprisedb.io poolers.postgresql.k8s.enterprisedb.io scheduledbackups.postgresql.k8s.enterprisedb.io clusterimagecatalogs.postgresql.k8s.enterprisedb.io imagecatalogs.postgresql.k8s.enterprisedb.io publications.postgresql.k8s.enterprisedb.io subscriptions.postgresql.k8s.enterprisedb.io databases.postgresql.k8s.enterprisedb.io foundationservices.cloudpak.ibm.com=edb-cluster  --overwrite=true 2>/dev/null
    #still need the final name value for these items, will likely match the deployment name
    ${OC} label clusterrole postgresql-operator-controller-manager-$OPERATOR_NS foundationservices.cloudpak.ibm.com=edb-cluster  --overwrite=true 2>/dev/null
    ${OC} label clusterrolebinding postgresql-operator-controller-manager-$OPERATOR_NS foundationservices.cloudpak.ibm.com=edb-cluster  --overwrite=true 2>/dev/null
    ${OC} label validatingwebhookconfiguration postgresql-operator-validating-webhook-configuration-$OPERATOR_NS foundationservices.cloudpak.ibm.com=edb-cluster  --overwrite=true 2>/dev/null
    ${OC} label mutatingwebhookconfiguration postgresql-operator-mutating-webhook-configuration-$OPERATOR_NS foundationservices.cloudpak.ibm.com=edb-cluster  --overwrite=true 2>/dev/null
    edb_release_name=$(${OC} get crd clusters.postgresql.k8s.enterprisedb.io -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    edb_release_namespace=$(${OC} get crd clusters.postgresql.k8s.enterprisedb.io -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$edb_release_name.v1 -n $edb_release_namespace foundationservices.cloudpak.ibm.com=edb-cluster  --overwrite=true 2>/dev/null

    #zen? (crds, clusterrole, clusterrolebinding)
    #assuming we are still responsible for zen
    #CRD covered in label_ns_and_related function
    ${OC} label clusterrole ibm-zen-operator-cluster-role-$OPERATOR_NS foundationservices.cloudpak.ibm.com=zen-cluster  --overwrite=true 2>/dev/null
    ${OC} label clusterrolebinding ibm-zen-operator-cluster-role-binding-$OPERATOR_NS foundationservices.cloudpak.ibm.com=zen-cluster  --overwrite=true 2>/dev/null
    zen_release_name=$(${OC} get clusterrole ibm-zen-operator-cluster-role -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    zen_release_namespace=$(${OC} get clusterrole ibm-zen-operator-cluster-role -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$zen_release_name.v1 -n $zen_release_namespace foundationservices.cloudpak.ibm.com=zen-cluster  --overwrite=true 2>/dev/null

    success "Cluster scoped charts labeled."
}

function label_helm_namespace_scope(){
    title "Begin labeling namespace scoped resources installed via helm..."
    #label rbac and resources in operator and services namespace first
    #odlm
    ${OC} label deploy operand-deployment-lifecycle-manager foundationservices.cloudpak.ibm.com=odlm-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label serviceaccount operand-deployment-lifecycle-manager foundationservices.cloudpak.ibm.com=odlm-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role operand-deployment-lifecycle-manager foundationservices.cloudpak.ibm.com=odlm-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding operand-deployment-lifecycle-manager foundationservices.cloudpak.ibm.com=odlm-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role operand-deployment-lifecycle-manager foundationservices.cloudpak.ibm.com=odlm-chart -n $SERVICES_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding operand-deployment-lifecycle-manager foundationservices.cloudpak.ibm.com=odlm-chart -n $SERVICES_NS --overwrite=true 2>/dev/null
    odlm_release_name=$(${OC} get deploy operand-deployment-lifecycle-manager -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    odlm_release_namespace=$(${OC} get deploy operand-deployment-lifecycle-manager -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$odlm_release_name.v1 -n $odlm_release_namespace foundationservices.cloudpak.ibm.com=odlm-chart  --overwrite=true 2>/dev/null

    #cs operator
    #cs CR handled in label_cs
    ${OC} label deployment ibm-common-service-operator foundationservices.cloudpak.ibm.com=cs-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label serviceaccount ibm-common-service-operator foundationservices.cloudpak.ibm.com=cs-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role ibm-common-service-operator foundationservices.cloudpak.ibm.com=cs-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding ibm-common-service-operator foundationservices.cloudpak.ibm.com=cs-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role ibm-common-service-operator foundationservices.cloudpak.ibm.com=cs-chart -n $SERVICES_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding ibm-common-service-operator foundationservices.cloudpak.ibm.com=cs-chart -n $SERVICES_NS --overwrite=true 2>/dev/null
    cs_release_name=$(${OC} get deploy ibm-common-service-operator -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    cs_release_namespace=$(${OC} get deploy ibm-common-service-operator -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$cs_release_name.v1 -n $cs_release_namespace foundationservices.cloudpak.ibm.com=cs-chart  --overwrite=true 2>/dev/null

    #ibm iam operator
    ${OC} label deployment ibm-iam-operator foundationservices.cloudpak.ibm.com=iam-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label serviceaccount ibm-iam-operator foundationservices.cloudpak.ibm.com=iam-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role ibm-iam-operator foundationservices.cloudpak.ibm.com=iam-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding ibm-iam-operator foundationservices.cloudpak.ibm.com=iam-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role ibm-iam-operator foundationservices.cloudpak.ibm.com=iam-chart -n $SERVICES_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding ibm-iam-operator foundationservices.cloudpak.ibm.com=iam-chart -n $SERVICES_NS --overwrite=true 2>/dev/null
    im_release_name=$(${OC} get deploy ibm-iam-operator -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    im_release_namespace=$(${OC} get deploy ibm-iam-operator -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$im_release_name.v1 -n $im_release_namespace foundationservices.cloudpak.ibm.com=iam-chart  --overwrite=true 2>/dev/null
    
    #common ui
    ${OC} label deployment ibm-commonui-operator foundationservices.cloudpak.ibm.com=ui-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label serviceaccount ibm-commonui-operator foundationservices.cloudpak.ibm.com=ui-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role ibm-commonui-operator foundationservices.cloudpak.ibm.com=ui-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role ibm-commonui-operator foundationservices.cloudpak.ibm.com=ui-chart -n $SERVICES_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding ibm-commonui-operator foundationservices.cloudpak.ibm.com=ui-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding ibm-commonui-operator foundationservices.cloudpak.ibm.com=ui-chart -n $SERVICES_NS --overwrite=true 2>/dev/null
    ui_release_name=$(${OC} get deploy ibm-commonui-operator -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    ui_release_namespace=$(${OC} get deploy ibm-commonui-operator -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$ui_release_name.v1 -n $ui_release_namespace foundationservices.cloudpak.ibm.com=ui-chart  --overwrite=true 2>/dev/null
    
    #edb
    deploy=$(${OC} get deploy -n $OPERATOR_NS | grep postgresql-operator-controller-manager | awk '{print $1}')
    ${OC} label deployment $deploy foundationservices.cloudpak.ibm.com=edb-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label configmap cloud-native-postgresql-image-list postgresql-operator-default-monitoring foundationservices.cloudpak.ibm.com=edb-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label service postgresql-operator-webhook-service foundationservices.cloudpak.ibm.com=edb-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label serviceaccount postgresql-operator-manager foundationservices.cloudpak.ibm.com=edb-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role postgresql-operator-controller-manager foundationservices.cloudpak.ibm.com=edb-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding postgresql-operator-controller-manager foundationservices.cloudpak.ibm.com=edb-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role postgresql-operator-controller-manager foundationservices.cloudpak.ibm.com=edb-chart -n $SERVICES_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding postgresql-operator-controller-manager foundationservices.cloudpak.ibm.com=edb-chart -n $SERVICES_NS --overwrite=true 2>/dev/null
    edb_release_name=$(${OC} get deploy $deploy -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    edb_release_namespace=$(${OC} get deploy $deploy -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$edb_release_name.v1 -n $edb_release_namespace foundationservices.cloudpak.ibm.com=edb-chart  --overwrite=true 2>/dev/null

    #zen
    ${OC} label deploy ibm-zen-operator foundationservices.cloudpak.ibm.com=zen-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    #zenservice covered in label_ns_and_related function
    ${OC} label role ibm-zen-operator-role foundationservices.cloudpak.ibm.com=zen-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding ibm-zen-operator-rolebinding foundationservices.cloudpak.ibm.com=zen-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label serviceaccount ibm-zen-operator-serviceaccount foundationservices.cloudpak.ibm.com=zen-chart -n $OPERATOR_NS --overwrite=true 2>/dev/null
    ${OC} label role ibm-zen-operator-role foundationservices.cloudpak.ibm.com=zen-chart  -n $SERVICES_NS --overwrite=true 2>/dev/null
    ${OC} label rolebinding ibm-zen-operator-rolebinding foundationservices.cloudpak.ibm.com=zen-chart  -n $SERVICES_NS --overwrite=true 2>/dev/null
    zen_release_name=$(${OC} get deploy ibm-zen-operator -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    zen_release_namespace=$(${OC} get deploy ibm-zen-operator -n $OPERATOR_NS -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$zen_release_name.v1 -n $zen_release_namespace foundationservices.cloudpak.ibm.com=zen-chart  --overwrite=true 2>/dev/null

    #loop through tethered namespaces to label remaining roles and rolebindings
    if [[ $TETHERED_NS != "" ]]; then
        for namespace in ${TETHERED_NS//,/ }
        do
            #ODLM
            ${OC} label role operand-deployment-lifecycle-manager foundationservices.cloudpak.ibm.com=odlm-chart -n $namespace --overwrite=true 2>/dev/null
            ${OC} label rolebinding operand-deployment-lifecycle-manager foundationservices.cloudpak.ibm.com=odlm-chart -n $namespace --overwrite=true 2>/dev/null
            
            #cs
            ${OC} label role ibm-common-service-operator foundationservices.cloudpak.ibm.com=iam-chart -n $namespace --overwrite=true 2>/dev/null
            ${OC} label rolebinding ibm-common-service-operator foundationservices.cloudpak.ibm.com=iam-chart -n $namespace --overwrite=true 2>/dev/null
            
            #im
            ${OC} label role ibm-iam-operator foundationservices.cloudpak.ibm.com=iam-chart -n $namespace --overwrite=true 2>/dev/null
            ${OC} label rolebinding ibm-iam-operator foundationservices.cloudpak.ibm.com=iam-chart -n $namespace --overwrite=true 2>/dev/null

            #ui
            ${OC} label role ibm-commonui-operator foundationservices.cloudpak.ibm.com=ui-chart -n $namespace --overwrite=true 2>/dev/null
            ${OC} label rolebinding ibm-commonui-operator foundationservices.cloudpak.ibm.com=ui-chart -n $namespace --overwrite=true 2>/dev/null

            #edb
            ${OC} label role postgresql-operator-controller-manager foundationservices.cloudpak.ibm.com=edb-chart -n $namespace --overwrite=true 2>/dev/null
            ${OC} label rolebinding postgresql-operator-controller-manager foundationservices.cloudpak.ibm.com=edb-chart -n $namespace --overwrite=true 2>/dev/null
            
            #zen
            ${OC} label role ibm-zen-operator-role foundationservices.cloudpak.ibm.com=zen-chart -n $namespace --overwrite=true 2>/dev/null
            ${OC} label rolebinding ibm-zen-operator-rolebinding foundationservices.cloudpak.ibm.com=zen-chart -n $namespace --overwrite=true 2>/dev/null
        done
    fi

    success "Namespace scoped charts labeled."
}

function label_helm_licensing() {
    title "Labeling Licensing cluster and namespace resources..."
    ${OC} label clusterrole ibm-license-service ibm-license-service-restricted ibm-licensing-default-reader ibm-licensing-operator foundationservices.cloudpak.ibm.com=ls-cluster  --overwrite=true 2>/dev/null
    ${OC} label clusterrolebinding ibm-license-service ibm-license-service-restricted ibm-licensing-default-reader ibm-licensing-operator ibm-license-service-cluster-monitoring-view foundationservices.cloudpak.ibm.com=ls-cluster  --overwrite=true 2>/dev/null
    ${OC} label customresourcedefinition ibmlicensingdefinitions.operator.ibm.com ibmlicensingquerysources.operator.ibm.com ibmlicensings.operator.ibm.com foundationservices.cloudpak.ibm.com=ls-cluster  --overwrite=true 2>/dev/null

    ${OC} label ibmlicensing instance -n $LICENSING_NAMESPACE foundationservices.cloudpak.ibm.com=ls-chart --overwrite=true 2>/dev/null
    ${OC} label deployment ibm-licensing-operator -n $LICENSING_NAMESPACE foundationservices.cloudpak.ibm.com=ls-chart --overwrite=true 2>/dev/null
    ${OC} label role ibm-license-service ibm-license-service-restricted ibm-licensing-operator -n $LICENSING_NAMESPACE foundationservices.cloudpak.ibm.com=ls-chart --overwrite=true 2>/dev/null
    ${OC} label rolebinding ibm-license-service ibm-license-service-restricted ibm-licensing-operator -n $LICENSING_NAMESPACE foundationservices.cloudpak.ibm.com=ls-chart --overwrite=true 2>/dev/null
    ${OC} label serviceaccount ibm-license-service ibm-license-service-restricted ibm-licensing-default-reader ibm-licensing-operator -n $LICENSING_NAMESPACE foundationservices.cloudpak.ibm.com=ls-chart --overwrite=true 2>/dev/null
    
    lis_release_name=$(${OC} get deploy ibm-licensing-operator -n $LICENSING_NAMESPACE -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    lis_release_namespace=$(${OC} get deploy ibm-licensing-operator -n $LICENSING_NAMESPACE -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$lis_release_name.v1 -n $lis_release_namespace foundationservices.cloudpak.ibm.com=ls-chart  --overwrite=true 2>/dev/null

    success "Licensing resources labeled"

}

function label_helm_lsr() {
    title "Labeling License Service Reporter cluster and namespace resources..."
    ${OC} label clusterrole manager-role foundationservices.cloudpak.ibm.com=lsr-cluster  --overwrite=true 2>/dev/null
    ${OC} label clusterrolebinding manager-rolebinding foundationservices.cloudpak.ibm.com=lsr-cluster  --overwrite=true 2>/dev/null
    ${OC} label customresourcedefinition ibmlicenseservicereporters.operator.ibm.com foundationservices.cloudpak.ibm.com=lsr-cluster  --overwrite=true 2>/dev/null

    ${OC} label ibmlicenseservicereporters.operator.ibm.com instance -n $LSR_NAMESPACE foundationservices.cloudpak.ibm.com=lsr-chart  --overwrite=true 2>/dev/null
    ${OC} label deployment ibm-license-service-reporter-operator -n $LSR_NAMESPACE foundationservices.cloudpak.ibm.com=lsr-chart  --overwrite=true 2>/dev/null
    ${OC} label role ibm-license-service-reporter leader-election-role manager-role -n $LSR_NAMESPACE foundationservices.cloudpak.ibm.com=lsr-chart  --overwrite=true 2>/dev/null
    ${OC} label rolebinding ibm-license-service-reporter leader-election-rolebinding manager-rolebinding -n $LSR_NAMESPACE foundationservices.cloudpak.ibm.com=lsr-chart  --overwrite=true 2>/dev/null
    ${OC} label serviceaccount ibm-license-service-reporter ibm-license-service-reporter-operator -n $LSR_NAMESPACE foundationservices.cloudpak.ibm.com=lsr-chart  --overwrite=true 2>/dev/null
    
    lsr_release_name=$(${OC} get deploy ibm-license-service-reporter-operator -n $LSR_NAMESPACE -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' --ignore-not-found)
    lsr_release_namespace=$(${OC} get deploy ibm-license-service-reporter-operator -n $LSR_NAMESPACE -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' --ignore-not-found)
    ${OC} label secret sh.helm.release.v1.$lsr_release_name.v1 -n $lsr_release_namespace foundationservices.cloudpak.ibm.com=lsr-chart  --overwrite=true 2>/dev/null

    success "LSR resources labeled"
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