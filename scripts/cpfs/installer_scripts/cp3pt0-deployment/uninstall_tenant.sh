#!/usr/bin/env bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product. 
# Please refer to that particular license for additional information. 

set -o nounset

# ---------- Command arguments ----------

OC=oc
YQ=yq
TENANT_NAMESPACES=""
OPERATOR_NS_LIST=""
FORCE_DELETE=0
DEBUG=0

# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# log file
LOG_FILE="uninstall_tenant_log_$(date +'%Y%m%d%H%M%S').log"

# ---------- Main functions ----------

. ${BASE_DIR}/common/utils.sh

function main() {
    parse_arguments "$@"
    save_log "logs" "uninstall_tenant_log" "$DEBUG"
    trap cleanup_log EXIT
    pre_req
    set_tenant_namespaces
    if [ $FORCE_DELETE -eq 0 ]; then
        uninstall_odlm
        uninstall_cs_operator
        uninstall_nss
    fi
    delete_rbac_resource
    delete_webhook
    delete_unavailable_apiservice
    delete_tenant_ns
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
        --yq)
            shift
            YQ=$1
            ;;
        --operator-namespace)
            shift
            OPERATOR_NS=$1
            ;;
        -f)
            shift
            FORCE_DELETE=1
            ;;
        -v | --debug)
            shift
            DEBUG=$1
            ;;
        -h | --help)
            print_usage
            exit 1
            ;;
        *) 
            echo "wildcard"
            ;;
        esac
        shift
    done
}

function print_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} --operator-namespace <bedrock-namespace> [OPTIONS]..."
    echo ""
    echo "Uninstall a tenant using Foundational services."
    echo "**NOTE**: this script will uninstall the entire tenant scoped to the Foundational services instance deployed in the namespace from the '--operator-namespace' parameter entered."
    echo "The --operator-namespace must be provided."
    echo ""
    echo "Options:"
    echo "   --oc string                    Optional. File path to oc CLI. Default uses oc in your PATH"
    echo "   --yq string                    Optional. File path to yq CLI. Default uses yq in your PATH"
    echo "   --operator-namespace string    Required. Namespace to uninstall Foundational services operators and the whole tenant."
    echo "   -f                             Optional. Enable force delete. It will take much more time if you add this label, we suggest run this script without -f label first"
    echo "   -v, --debug integer            Optional. Verbosity of logs. Default is 0. Set to 1 for debug logs"
    echo "   -h, --help                     Print usage information"
    echo ""
}

function pre_req() {
    # Check the value of DEBUG
    if [[ "$DEBUG" != "1" && "$DEBUG" != "0" ]]; then
        error "Invalid value for DEBUG. Expected 0 or 1."
    fi

    check_command "${OC}"
    check_command "${YQ}"
    check_yq_version

    # Checking oc command logged in
    user=$(${OC} whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        error "You must be logged into the OpenShift Cluster from the oc command line"
    else
        success "oc command logged in as ${user}"
    fi

    if [ "$OPERATOR_NS" == "" ]; then
        error "Must provide operator namespace"
    fi

    if [ $FORCE_DELETE -eq 1 ]; then
        warning "It will take much more time"
    fi
}

function set_tenant_namespaces() {
    # check if user want to cleanup operatorNamespace
    for ns in ${OPERATOR_NS//,/ }; do
        # if this namespace is operatorNamespace
        temp_namespace=$(${OC} get -n "$ns" configmap namespace-scope -o jsonpath='{.data.namespaces}' --ignore-not-found)
        if [ "$temp_namespace" != "" ]; then
            if [ "$TENANT_NAMESPACES" == "" ]; then
                TENANT_NAMESPACES=$temp_namespace
                OPERATOR_NS_LIST=$ns
            else
                TENANT_NAMESPACES="${TENANT_NAMESPACES},${temp_namespace}"
                OPERATOR_NS_LIST="${OPERATOR_NS_LIST},${ns}"
            fi
            continue
        fi

        # if this namespace is servicesNamespace
        operator_ns=$(${OC} get -n "$ns" commonservice common-service -o jsonpath='{.spec.operatorNamespace}' --ignore-not-found)
        services_ns=$(${OC} get -n "$ns" commonservice common-service -o jsonpath='{.spec.servicesNamespace}' --ignore-not-found)
        if [ "$services_ns" == "$ns" ]; then
            temp_namespace=$(${OC} get -n "$operator_ns" configmap namespace-scope -o jsonpath='{.data.namespaces}' --ignore-not-found)
            if [ "$TENANT_NAMESPACES" == "" ]; then
                TENANT_NAMESPACES=$temp_namespace
                OPERATOR_NS_LIST=$operator_ns
            else
                TENANT_NAMESPACES="${TENANT_NAMESPACES},${temp_namespace}"
                OPERATOR_NS_LIST="${OPERATOR_NS_LIST},${operator_ns}"
            fi
            continue
        fi

        # if this namespace neither operatorNamespace nor serviceNamsespace
        if [ "$TENANT_NAMESPACES" == "" ]; then
            TENANT_NAMESPACES=$ns
        else
            TENANT_NAMESPACES="${TENANT_NAMESPACES},${ns}"
        fi
    done

    # delete duplicate namespace in TENANT_NAMESPACES and OPERATOR_NS_LIST
    TENANT_NAMESPACES=$(echo "$TENANT_NAMESPACES" | sed -e 's/,/\n/g' | sort -u | tr "\r\n" "," | sed '$ s/,$//')
    OPERATOR_NS_LIST=$(echo "$OPERATOR_NS_LIST" | sed -e 's/,/\n/g' | sort -u | tr "\r\n" "," | sed '$ s/,$//')
    info "Tenant namespaces are: $TENANT_NAMESPACES"
}

function uninstall_odlm() {
    title "Uninstalling OperandRequests and ODLM"

    local grep_args=""
    for ns in ${TENANT_NAMESPACES//,/ }; do
        local opreq=$(${OC} get -n "$ns" operandrequests --no-headers | cut -d ' ' -f1)
        if [ "$opreq" != "" ]; then
            ${OC} delete -n "$ns" operandrequests ${opreq//$'\n'/ } --timeout=30s
        fi
        grep_args="${grep_args}-e $ns "
    done

    if [ "$grep_args" == "" ]; then
        grep_args='no-operand-requests'
    fi

    for ns in ${TENANT_NAMESPACES//,/ }; do
        local condition="${OC} get operandrequests -n ${ns} --no-headers | cut -d ' ' -f1 | grep -w ${grep_args} || echo Success"
        local retries=20
        local sleep_time=10
        local total_time_mins=$(( sleep_time * retries / 60))
        local wait_message="Waiting for all OperandRequests in tenant namespaces:${ns} to be deleted"
        local success_message="This tenant OperandRequests deleted"
        local error_message="Timeout after ${total_time_mins} minutes waiting for tenant OperandRequests to be deleted"

        # ideally ODLM will ensure OperandRequests are cleaned up neatly
        wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
    done

        for ns in ${TENANT_NAMESPACES//,/ }; do
        local sub=$(fetch_sub_from_package ibm-odlm $ns)
        if [ "$sub" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" sub "$sub"
        fi

        local csv=$(fetch_csv_from_sub operand-deployment-lifecycle-manager "$ns")
        if [ "$csv" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" csv "$csv"
        fi
    done
}

function uninstall_cs_operator() {
    title "Uninstalling ibm-common-service-operator in tenant namespaces"

    for ns in ${TENANT_NAMESPACES//,/ }; do
        local sub=$(fetch_sub_from_package ibm-common-service-operator $ns)
        if [ "$sub" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" sub "$sub"
        fi

        local csv=$(fetch_csv_from_sub "$sub" "$ns")
        if [ "$csv" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" csv "$csv"
        fi
    done
}

function uninstall_nss() {
    title "Uninstall ibm-namespace-scope-operator"

    for ns in ${TENANT_NAMESPACES//,/ }; do
        ${OC} delete --ignore-not-found nss -n "$ns" common-service --timeout=30s
        for op_ns in ${OPERATOR_NS_LIST//,/ }; do
            ${OC} delete --ignore-not-found rolebinding -n "$ns" "nss-managed-role-from-$op_ns"
            ${OC} delete --ignore-not-found role -n "$ns" "nss-managed-role-from-$op_ns"
            ${OC} delete --ignore-not-found rolebinding -n "$ns" "nss-runtime-managed-role-from-$op_ns"
            ${OC} delete --ignore-not-found role -n "$ns" "nss-runtime-managed-role-from-$op_ns"
        done

        sub=$(fetch_sub_from_package ibm-namespace-scope-operator "$ns")
        if [ "$sub" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" sub "$sub"
        fi
        csv=$(fetch_csv_from_sub "$sub" "$ns")
        if [ "$csv" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" csv "$csv"
        fi
    done
}

function delete_webhook() {
    title "Deleting webhookconfigurations in ${TENANT_NAMESPACES}"
    for ns in ${TENANT_NAMESPACES//,/ }; do
        ${OC} delete ValidatingWebhookConfiguration ibm-common-service-validating-webhook-${ns} --ignore-not-found
        ${OC} delete MutatingWebhookConfiguration ibm-common-service-webhook-configuration ibm-operandrequest-webhook-configuration namespace-admission-config ibm-operandrequest-webhook-configuration-${ns} --ignore-not-found
    done
}

function delete_rbac_resource() {
    info "delete rbac resource"
    for ns in ${TENANT_NAMESPACES//,/ }; do
        ${OC} delete ClusterRoleBinding ibm-common-service-webhook secretshare-${ns} $(${OC} get ClusterRoleBinding | grep nginx-ingress-clusterrole | awk '{print $1}') --ignore-not-found
        ${OC} delete ClusterRole ibm-common-service-webhook secretshare nginx-ingress-clusterrole --ignore-not-found
        ${OC} delete scc nginx-ingress-scc --ignore-not-found
    done
}

function delete_unavailable_apiservice() {
    info "delete unavailable apiservice"
    rc=0
    apis=$(${OC} get apiservice | grep False | awk '{print $1}')
    if [ "X${apis}" != "X" ]; then
        warning "Found some unavailable apiservices, deleting ..."
        for api in ${apis}; do
        msg "${OC} delete apiservice ${api}"
        ${OC} delete apiservice ${api}
        if [[ "$?" != "0" ]]; then
            error "Delete apiservcie ${api} failed"
            rc=$((rc + 1))
            continue
        fi
        done
    fi
    return $rc
}

function cleanup_dedicate_cr() {
    for ns in ${TENANT_NAMESPACES//,/ }; do
        cleanup_webhook $ns $TENANT_NAMESPACES
        cleanup_secretshare $ns $TENANT_NAMESPACES
        cleanup_crossplane $ns
    done
}

function delete_tenant_ns() {
    title "Deleting tenant namespaces"
    for ns in ${TENANT_NAMESPACES//,/ }; do
        ${OC} delete --ignore-not-found ns "$ns" --timeout=30s
        if [ $? -ne 0 ] || [ $FORCE_DELETE -eq 1 ]; then
            warning "Failed to delete namespace $ns, force deleting remaining resources..."
            remove_all_finalizers $ns && success "Namespace $ns is deleted successfully."
        fi
        update_namespaceMapping $ns
    done

    cleanup_cs_control

    success "Common Services uninstall finished and successfull." 
}

function update_namespaceMapping() {
    namespace=$1
    title "Updating common-service-maps $namespace"
    msg "-----------------------------------------------------------------------"
    local current_yaml=$("${OC}" get -n kube-public cm common-service-maps -o yaml | ${YQ} '.data.["common-service-maps.yaml"]')
    local isExist=$(echo "$current_yaml" | ${YQ} '.namespaceMapping[] | select(.map-to-common-service-namespace == "'$namespace'")')

    if [ "$isExist" ]; then
        info "The map-to-common-service-namespace: $namespace, exist in common-service-maps"
        info "Deleting this tenant in common-service-maps"
        updated_yaml=$(echo "$current_yaml" | ${YQ} 'del(.namespaceMapping[] | select(.map-to-common-service-namespace == "'$namespace'"))')
        local padded_yaml=$(echo "$updated_yaml" | awk '$0="    "$0')
        update_cs_maps "$padded_yaml"
    else
        info "Namespace: $namespace does not exist in .map-to-common-service-namespace, skipping"
    fi
}

# update_cs_maps Updates the common-service-maps with the given yaml. Note that
# the given yaml should have the right indentation/padding, minimum 2 spaces per
# line. If there are multiple lines in the yaml, ensure that each line has
# correct indentation.
function update_cs_maps() {
    local yaml=$1

    local object="$(
        cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: common-service-maps
  namespace: kube-public
data:
  common-service-maps.yaml: |
${yaml}
EOF
)"
    echo "$object" | ${OC} apply -f -
}

# check if we need to cleanup contorl namespace and clean it
function cleanup_cs_control() {
    local current_yaml=$("${OC}" get -n kube-public cm common-service-maps -o yaml | ${YQ} '.data.["common-service-maps.yaml"]')
    local isExist=$(echo "$current_yaml" | ${YQ} '.namespaceMapping[] | has("map-to-common-service-namespace")' )
    if [ "$isExist" ]; then
        info "map-to-common-service-namespace exist in common-service-maps, don't clean up control namespace"
    else
        title "Clean up control namespace"
        msg "-----------------------------------------------------------------------"
        get_control_namespace
        # cleanup namespaceScope in Control namespace
        cleanup_NamespaceScope $CONTROL_NS
        # cleanup webhook
        cleanup_webhook $CONTROL_NS ""
        # cleanup secretshare
        cleanup_secretshare $CONTROL_NS ""
        # cleanup crossplane    
        cleanup_crossplane
        # delete common-service-maps 
        ${OC} delete configmap common-service-maps -n kube-public
        # delete namespace
        ${OC} delete --ignore-not-found ns "$CONTROL_NS" --timeout=30s
        if [ $? -ne 0 ] || [ $FORCE_DELETE -eq 1 ]; then
            warning "Failed to delete namespace $CONTROL_NS, force deleting remaining resources..."
            remove_all_finalizers $ns && success "Namespace $CONTROL_NS is deleted successfully."
        fi

        success "Control namespace: ${CONTROL_NS} is cleanup"
    fi

}


main $*