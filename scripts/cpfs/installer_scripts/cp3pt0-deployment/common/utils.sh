#!/usr/bin/env bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product.
# Please refer to that particular license for additional information.

# ---------- Info functions ----------#

function msg() {
    printf '%b\n' "$1"
}

function info() {
    msg "[INFO] ${1}"
}

function success() {
    msg "\33[32m[✔] ${1}\33[0m"
}

function warning() {
    msg "\33[33m[✗] ${1}\33[0m"
}

function error() {
    local error_message="$1"
    local function_name="${FUNCNAME[1]}"
    local line_number="${BASH_LINENO[0]}"
    local script_name="${BASH_SOURCE[1]}"
    msg "\33[31m[✘] Error in ${script_name} at line $line_number in function ${function_name}: ${error_message}\33[0m"
    exit 1
}

function title() {
    msg "\33[34m# ${1}\33[0m"
}

function debug() {
    msg "\33[33m[DEBUG] ${1}\33[0m"
}

# ---------- Check functions start ----------#

function check_command() {
    local command=$1

    if [[ -z "$(command -v ${command} 2> /dev/null)" ]]; then
        error "${command} command not available"
    else
        success "${command} command available"
    fi
}

function check_yq_version() {
  yq_version=$("${YQ}" --version | awk '{print $NF}' | sed 's/^v//')
  yq_minimum_version=4.18.1

  if [ "$(printf '%s\n' "$yq_minimum_version" "$yq_version" | sort -V | head -n1)" != "$yq_minimum_version" ]; then 
    error "yq version $yq_version must be at least $yq_minimum_version or higher.\nInstructions for installing/upgrading yq are available here: https://github.com/marketplace/actions/yq-portable-yaml-processor"
  fi
}

function check_version() {
    local command=$1
    local version_cmd=$2
    local variant=$3
    local version=$4

    result=$(${command} ${version_cmd})
    echo "$result" | grep -q "${variant}" && echo "$result" | grep -Eq "${version}"
    if [[ $? -ne 0 ]]; then
        error "${command} command is not supported"
    else
        success "${command} command is supported"
    fi
}

function check_return_code() {
    local rc=$1
    local error_message=$2

    if [ "${rc}" -ne 0 ]; then
        error "${error_message}"
    else
        return 0
    fi
}

function restart_job() {
    local namespace=$1
    local job_name=$2

    if [[ ! -z "$(${OC} -n ${namespace} get job ${job_name} --ignore-not-found)" ]]; then
        ${OC} -n ${namespace} patch job ${job_name} --type json -p \
            '[{ "op": "remove", "path": "/spec/selector"},
              { "op": "remove", "path": "/spec/template/metadata/labels/controller-uid"}]' \
            -o yaml --dry-run \
            | ${OC} -n ${namespace} replace --force --timeout=20s -f - 2> /dev/null
    else
        error "Job not found: ${job_name}"
    fi
}

function translate_step() {
    local step=$1
    echo "${step}" | tr '[1-9]' '[a-i]'
}

function wait_for_condition() {
    local condition=$1
    local retries=$2
    local sleep_time=$3
    local wait_message=$4
    local success_message=$5
    local error_message=$6

    info "${wait_message}"
    while true; do
        result=$(eval "${condition}")

        if [[ ( ${retries} -eq 0 ) && ( -z "${result}" ) ]]; then
            error "${error_message}"
        fi

        sleep ${sleep_time}
        result=$(eval "${condition}")

        if [[ -z "${result}" ]]; then
            info "RETRYING: ${wait_message} (${retries} left)"
            retries=$(( retries - 1 ))
        else
            break
        fi
    done

    if [[ ! -z "${success_message}" ]]; then
        success "${success_message}\n"
    fi
}

function wait_for_not_condition() {
    local condition=$1
    local retries=$2
    local sleep_time=$3
    local wait_message=$4
    local success_message=$5
    local error_message=$6

    info "${wait_message}"
    while true; do
        result=$(eval "${condition}")

        if [[ ( ${retries} -eq 0 ) && ( ! -z "${result}" ) ]]; then
            error "${error_message}"
        fi

        sleep ${sleep_time}
        result=$(eval "${condition}")

        if [[ ! -z "${result}" ]]; then
            info "RETRYING: ${wait_message} (${retries} left)"
            retries=$(( retries - 1 ))
        else
            break
        fi
    done

    if [[ ! -z "${success_message}" ]]; then
        success "${success_message}"
    fi
}

function wait_for_configmap() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get cm --no-headers --ignore-not-found | grep ^${name}"
    local retries=12
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for ConfigMap ${name} in namespace ${namespace} to become available"
    local success_message="ConfigMap ${name} in namespace ${namespace} is available"
    local error_message="Timeout after ${total_time_mins} minutes waiting for ConfigMap ${name} in namespace ${namespace} to become available"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_pod() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get po --no-headers --ignore-not-found | egrep 'Running|Completed|Succeeded' | grep ^${name}"
    local retries=30
    local sleep_time=30
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for pod ${name} in namespace ${namespace} to be running"
    local success_message="Pod ${name} in namespace ${namespace} is running"
    local error_message="Timeout after ${total_time_mins} minutes waiting for pod ${name} in namespace ${namespace} to be running"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_no_pod() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get po --no-headers --ignore-not-found | grep ^${name}"
    local retries=30
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for pod ${name} in namespace ${namespace} to be deleting"
    local success_message="Pod ${name} in namespace ${namespace} is deleted"
    local error_message="Timeout after ${total_time_mins} minutes waiting for pod ${name} in namespace ${namespace} to be deleted"

    wait_for_not_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_project() {
    local name=$1
    local condition="${OC} get project ${name} --no-headers --ignore-not-found"
    local retries=12
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for project ${name} to be created"
    local success_message="Project ${name} is created"
    local error_message="Timeout after ${total_time_mins} minutes waiting for project ${name} to be created"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_operator() {
    local namespace=$1
    local operator_name=$2
    local condition="${OC} -n ${namespace} get csv --no-headers --ignore-not-found | egrep 'Succeeded' | grep ^${operator_name}"
    local retries=50
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for operator ${operator_name} in namespace ${namespace} to become available"
    local success_message="Operator ${operator_name} in namespace ${namespace} is available"
    local error_message="Timeout after ${total_time_mins} minutes waiting for ${operator_name} in namespace ${namespace} to become available"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_issuer() {
    local issuer=$1
    local namespace=$2
    local condition="${OC} -n ${namespace} get issuer.v1.cert-manager.io ${issuer} --ignore-not-found -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}' | grep 'True'"
    local retries=50
    local sleep_time=6
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for Issuer ${issuer} in namespace ${namespace} to be Ready"
    local success_message="Issuer ${issuer} in namespace ${namespace} is Ready"
    local error_message="Timeout after ${total_time_mins} minutes waiting for Issuer ${issuer} in namespace ${namespace} to be Ready"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_certificate() {
    local certificate=$1
    local namespace=$2
    local condition="${OC} -n ${namespace} get certificate.v1.cert-manager.io ${certificate} --ignore-not-found -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}' | grep 'True'"
    local retries=50
    local sleep_time=6
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for Certificate ${certificate} in namespace ${namespace} to be Ready"
    local success_message="Certificate ${certificate} in namespace ${namespace} is Ready"
    local error_message="Timeout after ${total_time_mins} minutes waiting for Certificate ${certificate} in namespace ${namespace} to be Ready"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_csv() {
    local namespace=$1
    local package_name=$2
    local condition="${OC} get subscription.operators.coreos.com -l operators.coreos.com/${package_name}.${namespace}='' -n ${namespace} -o yaml -o jsonpath='{.items[*].status.installedCSV}'"
    local retries=60
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for operator ${package_name} CSV in namespace ${namespace} to be bound to Subscription"
    local success_message="Operator ${package_name} CSV in namespace ${namespace} is bound to Subscription"
    local error_message="Timeout after ${total_time_mins} minutes waiting for ${package_name} CSV in namespace ${namespace} to be bound to Subscription"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_service_account() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get sa ${name} --no-headers --ignore-not-found"
    local retries=20
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for service account ${name} to be created"
    local success_message="Service account ${name} is created"
    local error_message="Timeout after ${total_time_mins} minutes waiting for service account ${name} to be created"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_cscr_status(){
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get commonservice ${name} --no-headers --ignore-not-found -o jsonpath='{.status.phase}' | grep 'Succeeded'"
    local retries=100
    local sleep_time=6
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for CommonService CR ${name} in ${namespace} to be ready"
    local success_message="CommonService CR in ${namespace} is in Succeeded Phase"
    local error_message="Timeout after ${total_time_mins} minutes waiting for CommonService CR in ${namespace} to be ready"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_operand_request() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get operandrequests ${name} --no-headers --ignore-not-found -o jsonpath='{.status.phase}' | grep 'Running'"
    local retries=20
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for operand request ${name} to be running"
    local success_message="Operand request ${name} is running"
    local error_message="Timeout after ${total_time_mins} minutes waiting for operand request ${name} to be running"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_nss_patch() {
    local namespace=$1
    local package_name=$2

    local sub_name=$(${OC} get subscription.operators.coreos.com -n ${namespace} -l operators.coreos.com/${package_name}.${namespace}='' --no-headers | awk '{print $1}')
    local csv_name=$(${OC} get subscription.operators.coreos.com ${sub_name} -n ${namespace} --ignore-not-found -o jsonpath={.status.installedCSV})

    local condition="${OC} -n ${namespace} get csv ${csv_name} -o jsonpath='{.spec.install.spec.deployments[0].spec.template.spec.containers[0].env[?(@.name==\"WATCH_NAMESPACE\")].valueFrom.configMapKeyRef.name}'| grep 'namespace-scope'"
    local retries=30
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for operator ${package_name} CSV to be patched with NamespaceScope ConfigMap"
    local success_message="operator ${package_name} CSV is patched with NamespaceScope ConfigMap"
    local error_message="Timeout after ${total_time_mins} minutes waiting for operator ${package_name} CSV to be patched with NamespaceScope ConfigMap"
    local pod_name=$($OC get pod -n ${namespace} | grep namespace-scope | awk '{print $1}')

    # wait for nss patch
    info "${wait_message}"
    while true; do
        result=$(eval "${condition}")

        # restart namespace scope operator pod to reconcilie
        if [[ ( ${retries} -eq 0 ) && ( -z "${result}" ) ]]; then
            warning "Deleting pod ${pod_name} in namespace ${namespace} to trigger NamespaceScope reconciliaiton"
            $OC delete pod ${pod_name} -n ${namespace}
            # reset retries to 30 times to wait 5 minutes
            retries=30
            wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
            break
        fi


        if [ -z "${result}" ]; then
            info "RETRYING: ${wait_message} (${retries} left)"
            retries=$(( retries - 1 ))
        else
            break
        fi

        sleep ${sleep_time}
    done

    if [[ ! -z "${success_message}" ]]; then
        success "${success_message}\n"
    fi

    # wait for deployment to be ready
    local deployment_name="ibm-common-service-operator"
    wait_for_nss_env_var ${namespace} ${deployment_name}
    wait_for_deployment ${namespace} ${deployment_name}

}

function wait_for_nss_env_var() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get deployment ${name} -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name==\"WATCH_NAMESPACE\")].valueFrom.configMapKeyRef.name}'| grep 'namespace-scope'"
    local retries=10
    local sleep_time=30
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for OLM to update Deployment ${name} in namespace ${namespace} with NamespaceScope ConfigMap"
    local success_message="Deployment ${name} is updated with NamespaceScope ConfigMap"
    local error_message="Timeout after ${total_time_mins} minutes waiting for OLM to update Deployment ${name} in namespace ${namespace} with NamespaceScope ConfigMap"


    # wait for OLM to patch deployment
    info "${wait_message}"
    while true; do
        result=$(eval "${condition}")

        # patch deployment directly when OLM fails to do so
        if [[ ( ${retries} -eq 0 ) && ( -z "${result}" ) ]]; then
            patch_watch_namespace ${namespace} ${name}
            retries=6
            wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
            break
        fi


        if [ -z "${result}" ]; then
            info "RETRYING: ${wait_message} (${retries} left)"
            retries=$(( retries - 1 ))
        else
            break
        fi

        sleep ${sleep_time}
    done

    if [[ ! -z "${success_message}" ]]; then
        success "${success_message}\n"
    fi
}

function patch_watch_namespace() {
    local namespace=$1
    local name=$2
    local retries=5 # Number of retries
    local delay=5 # Delay between retries in seconds

    while [ $retries -gt 0 ]; do
        ${OC} get deployment ${name} -n ${namespace} -o yaml > /tmp/deployment.yaml

        # Delete original reference for WATCH_NAMESPACE in deployment
        # ${YQ} -i 'del(.spec.template.spec.containers[0].env[] | select(.name == "WATCH_NAMESPACE")).valueFrom' /tmp/deployment.yaml
        # The above command does not work because of the error: invalid: spec.template.spec.containers[0].env[1].valueFrom: Invalid value: "": may not have more than one field specified at a time
        # This happens because we need to set the valueFrom.fieldRef to null, to explicitly tell k8s to delete that field
        ${YQ} -i eval '(.spec.template.spec.containers[0].env[] | select(.name == "WATCH_NAMESPACE")).valueFrom.fieldRef = null' /tmp/deployment.yaml
        # Add new reference for WATCH_NAMESPACE in deployment from NamespaceScope ConfigMap
        ${YQ} -i eval '(.spec.template.spec.containers[0].env[] | select(.name == "WATCH_NAMESPACE")).valueFrom.configMapKeyRef.name = "namespace-scope"' /tmp/deployment.yaml
        ${YQ} -i eval '(.spec.template.spec.containers[0].env[] | select(.name == "WATCH_NAMESPACE")).valueFrom.configMapKeyRef.key = "namespaces"' /tmp/deployment.yaml
        ${YQ} -i eval '(.spec.template.spec.containers[0].env[] | select(.name == "WATCH_NAMESPACE")).valueFrom.configMapKeyRef.optional = true' /tmp/deployment.yaml
        # Add new labels intent: projected in deployment template to trigger pod restart by NamespaceScope Operator
        ${YQ} -i eval '.spec.template.metadata.labels.intent = "projected"' /tmp/deployment.yaml

        # Apply the patch for deployment
        ${OC} apply -f /tmp/deployment.yaml
        if [[ $? -eq 0 ]]; then
            success "Successfully patched WATCH_NAMESPACE in Deployment ${name} in ${namespace}\n"
            rm /tmp/deployment.yaml
            return 0
        else
            warning "Failed to patch WATCH_NAMESPACE in Deployment ${name} in ${namespace}. Retrying in ${delay} seconds..."
            sleep ${delay}
            retries=$((retries - 1))
        fi
    done
    rm /tmp/deployment.yaml
    error "Maximum retries reached. Failed to patch Deployment ${name} in ${namespace}"
    return 1
}

function wait_for_deployment() {
    local namespace=$1
    local name=$2
    local needReplicas=$(${OC} -n ${namespace} get deployment ${name} --no-headers --ignore-not-found -o jsonpath='{.spec.replicas}' | awk '{print $1}')
    local readyReplicas="${OC} -n ${namespace} get deployment ${name} --no-headers --ignore-not-found -o jsonpath='{.status.readyReplicas}' | grep '${needReplicas}'"
    local replicas="${OC} -n ${namespace} get deployment ${name} --no-headers --ignore-not-found -o jsonpath='{.status.replicas}' | grep '${needReplicas}'"
    local condition="(${readyReplicas} && ${replicas})"
    local retries=10
    local sleep_time=30
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for Deployment ${name} to be ready"
    local success_message="Deployment ${name} is running"
    local error_message="Timeout after ${total_time_mins} minutes waiting for Deployment ${name} to be running"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_operator_upgrade() {
    local namespace=$1
    local package_name=$2
    local channel=$3
    local install_mode=$4
    local condition="${OC} get subscription.operators.coreos.com -l operators.coreos.com/${package_name}.${namespace}='' -n ${namespace} -o yaml -o jsonpath='{.items[*].status.installedCSV}' | grep -w $channel"

    local retries=20
    local sleep_time=30
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for operator ${package_name} to be upgraded"
    local success_message="Operator ${package_name} is upgraded to latest version in channel ${channel}"
    local error_message="Timeout after ${total_time_mins} minutes waiting for operator ${package_name} to be upgraded"

    # if channel is not set, skip the wait
    if [[ "${channel}" == "null" ]]; then
        info "${wait_message}"
        sleep ${sleep_time}
        warning "Channel is not set for operator ${package_name}. Skipping wait for operator upgrade"
        return 0
    fi

    if [[ "${install_mode}" == "Manual" ]]; then
        wait_message="Waiting for operator ${package_name} to be upgraded \nPlease manually approve installPlan to make upgrade proceeding..."
        error_message="Timeout after ${total_time_mins} minutes waiting for operator ${package_name} to be upgraded \nInstallPlan is not manually approved yet"
    fi

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_cs_webhook() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get service --no-headers | (grep ${name})"
    local retries=20
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for CS webhook service to be ready"
    local success_message="CS Webhook Service ${name} is ready"
    local error_message="Timeout after ${total_time_mins} minutes waiting for common service webhook service to be ready"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_role() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get role ${name} --no-headers --ignore-not-found"
    local retries=10
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for role ${name} in namespace ${namespace} to be created"
    local success_message="Role ${name} in namespace ${namespace} is created"
    local error_message="Timeout after ${total_time_mins} minutes waiting for role ${name} in namespace ${namespace} to be created"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_role_binding() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get rolebinding ${name} --no-headers --ignore-not-found"
    local retries=10
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for rolebinding ${name} in namespace ${namespace} to be created"
    local success_message="Role binding ${name} in namespace ${namespace} is created"
    local error_message="Timeout after ${total_time_mins} minutes waiting for role binding ${name} in namespace ${namespace} to be created"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

# check_catalogsource check if the given catalogsource is available for selected packagemanifest and channel
function check_catalogsource() {
    local catalog_source=$1
    local catalog_namespace=$2
    local package_manifest=$3
    local operator_namespace=$4
    local channel=$5
    local return_value=0
    local result=$(${OC} get packagemanifest -n $operator_namespace -o yaml | ${YQ} eval '.items[] | select(.status.catalogSource == "'${catalog_source}'" and .status.catalogSourceNamespace == "'${catalog_namespace}'" and .status.packageName == "'${package_manifest}'" and .status.channels[].name == "'${channel}'") | .status.catalogSource')
    if [[ -z "$result" || "$result" == "null" ]]; then
        return_value=1
    fi
    echo "$return_value"
}

# get_catalogsource returns the catalogsource and catalognamespace for the given packagemanifest and channel
function get_catalogsource() {
    local package_manifest=$1
    local operator_namespace=$2
    local channel=$3
    local count=0
    local catalog_source=""
    local catalog_namespace=""

    local result=$(${OC} get packagemanifest -n $operator_namespace -o yaml | ${YQ} eval '.items[] | select(.status.packageName == "'${package_manifest}'" and .status.channels[].name == "'${channel}'") | {"name": .status.catalogSource, "namespace": .status.catalogSourceNamespace}')
    local total_count=$(wc -w <<< "$result")
    count=$((total_count / 4))
    if [[ count -eq 1 ]]; then
        # Remove the new line characters
        result=${result//$'\n'/,}
        # Extracting the values using string manipulation
        catalog_source=$(echo "$result" | awk -F': ' '{print $2}' | awk -F',' '{print $1}')
        catalog_namespace=$(echo "$result" | awk -F': ' '{print $NF}')
    fi
    echo "$count $catalog_source $catalog_namespace"
}

# catalogsource_correction corrects the catalogsource and catalogsource namespace if the given catalogsource is not available for selected packagemanifest and channel
function catalogsource_correction() {
    local source="$1"
    local source_ns="$2"
    local pm="$3"
    local operator_ns="$4"
    local channel="$5"
    local catalog_source=$source
    local catalog_namespace=$source_ns
    local return_value=0

    # if the given channel is not default, then check if the given catalogsource is available for selected packagemanifest and channel
    if [[ $channel != "null" ]]; then
        result=$(check_catalogsource $source $source_ns $pm $operator_ns $channel)
        # if the given catalogsource is not available for selected packagemanifest and channel (result is 1), then find the available catalogsource
        if [[ $result == "1" ]]; then
            # get the available catalogsource
            result=$(get_catalogsource $pm $operator_ns $channel)
            IFS=" " read -r count catalog catalog_ns <<< "$result"
            # if the available catalogsource is more than one, then return error
            # if the available catalogsource is zero, then return error
            # if the available catalogsource is one, then use the available catalogsource
            if [[ $count -gt 1 ]]; then
                return_value=1
            elif [[ $count -eq 0 ]]; then
                return_value=2
            else
                catalog_source="$catalog"
                catalog_namespace="$catalog_ns"
                return_value=3
            fi
        fi
    fi
    echo "$return_value $catalog_source $catalog_namespace"
}

# Validate operator CatalogSource and CatalogSourceNamespace
function validate_operator_catalogsource(){
    local pm="$1"
    local operator_ns="$2"
    local source="$3"
    local source_ns="$4"
    local channel="$5"

    title "Validate CatalogSource for operator $pm in $operator_ns namespace"

    correct_result=$(catalogsource_correction $source $source_ns $pm $operator_ns $channel)
    IFS=" " read -r return_value correct_source correct_source_ns <<< "$correct_result"

    # return_value: 0 - correct, 1 - multiple, 2 - none, 3 - wrong and corrected
    if [[ $return_value -eq 0 ]]; then
        success "CatalogSource $source from $source_ns CatalogSourceNamespace is available for $pm in $operator_ns namespace"
    elif [[ $return_value -eq 1 ]]; then
        warning "CatalogSource $source from $source_ns CatalogSourceNamespace is not available for $pm in $operator_ns namespace"
        error "Multiple CatalogSource are available for $pm in $operator_ns namespace, please specify the correct CatalogSource name and namespace"
    elif [[ $return_value -eq 2 ]]; then
        warning "CatalogSource $source from $source_ns CatalogSourceNamespace is not available for $pm in $operator_ns namespace"
        
        # Retry and wait for the CatalogSource to be available
        retries=5
        while [[ $retries -gt 0 ]]; do
            echo "Wait for CatalogSource to be ready..."
            sleep 20
            correct_result=$(catalogsource_correction $source $source_ns $pm $operator_ns $channel)
            IFS=" " read -r return_value correct_source correct_source_ns <<< "$correct_result"
            
            if [[ $return_value -eq 0 ]]; then
                success "CatalogSource $source from $source_ns CatalogSourceNamespace is available for $pm in $operator_ns namespace after retry"
                break
            elif [[ $return_value -eq 3 ]]; then
                success "CatalogSource $correct_source from $correct_source_ns CatalogSourceNamespace is available for $pm in $operator_ns namespace after retry"
                break
            fi

            ((retries--))
        done
        
        # If all retries failed, display an error message
        if [[ $retries -eq 0 ]]; then
            error "No CatalogSource is available for $pm in $operator_ns namespace in the given channel $channel after multiple attempts"
        fi
        
    elif [[ $return_value -eq 3 ]]; then
        warning "CatalogSource $source from $source_ns CatalogSourceNamespace is not available for $pm in $operator_ns namespace"
        success "CatalogSource $correct_source from $correct_source_ns CatalogSourceNamespace is available for $pm in $operator_ns namespace"
    fi

    eval "$6=${correct_source}"
    eval "$7=${correct_source_ns}"
}

function is_sub_exist() {
    local package_name=$1
    if [ $# -eq 2 ]; then
        local namespace=$2
        local name=$(${OC} get subscription.operators.coreos.com -n ${namespace} -o yaml -o jsonpath='{.items[*].spec.name}')
    else
        local name=$(${OC} get subscription.operators.coreos.com -A -o yaml -o jsonpath='{.items[*].spec.name}')
    fi
    is_exist=$(echo "$name" | grep -w "$package_name")
}

function check_cert_manager(){
    local service_name=$1
    local namespace=$2
    title " Checking whether Cert Manager exist..."
    if [[ $PREVIEW_MODE -eq 1 ]]; then
        info "Preview mode is on, skip checking whether Cert Manager exist\n"
        return 0
    fi

    csv_count=`$OC get csv -n "$namespace" | grep "$service_name" | wc -l`
    if [[ $csv_count == 1 ]]; then
        success "Found only one Cert Manager CSV exists in namespace "$namespace", continue smoke checking\n"
    elif [[ $csv_count == 0 ]]; then
        warning "Missing a Cert Manager, continue smoke checking\n"
    elif [[ $csv_count > 1 ]]; then
        error "Multiple Cert Manager csv found. Only one should be installed per cluster\n"
    fi

    cm_smoke_test "test-issuer" "test-certificate" "test-certificate-secret" $namespace
}

function cm_smoke_test(){
    local issuer_name=$1
    local cert_name=$2
    local sercret_name=$3
    local namespace=$4

    title " Smoke test for Cert Manager existence..."
    cleanup_cm_resources $issuer_name $cert_name $sercret_name $namespace
    create_issuer $issuer_name $namespace
    create_certificate $issuer_name $cert_name $sercret_name $namespace
    wait_for_issuer $issuer_name $namespace
    wait_for_certificate $cert_name $namespace
    if [[ $? -eq 0 ]]; then
        cleanup_cm_resources $issuer_name $cert_name $sercret_name $namespace
    fi
}

function check_licensing(){
    title " Checking IBMLicensing..."
    if [[ $PREVIEW_MODE -eq 1 ]]; then
        info "Preview mode is on, skip checking IBMLicensing\n"
        return 0
    fi
    [[ ! $($OC get IBMLicensing) ]] && error "User does not have proper permission to get IBMLicensing or IBMLicensing is not installed"
    instance_count=`$OC get IBMLicensing -o name | wc -l`
    if [[ $instance_count == 1 ]]; then
        success "Found only one IBMLicensing\n"
    elif [[ $instance_count == 0 ]]; then
        error "Missing IBMLicensing\n"
    elif [[ $instance_count > 1 ]]; then
        error "Multiple IBMLicensing are found. Only one should be installed per cluster\n"
    fi
}
# ---------- Check functions end ----------#

# ---------- creation functions start ----------#

function create_namespace() {
    local namespace=$1
    title "Checking whether Namespace $namespace exist..."
    if [[ -z "$(${OC} get namespace ${namespace} --ignore-not-found)" ]]; then
        info "Creating namespace ${namespace}"
        ${OC} create namespace ${namespace}
        if [[ $? -ne 0 ]]; then
            error "Error creating namespace ${namespace}"
        fi
        if [[ $PREVIEW_MODE -eq 0 ]]; then
            wait_for_project ${namespace}
        fi
    else
        success "Namespace ${namespace} already exists. Skip creating\n"
    fi
}

function create_operator_group() {
    local name=$1
    local ns=$2
    local target=$3
    cat <<EOF > ${PREVIEW_DIR}/operatorgroup.yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: $name
  namespace: $ns
spec: $target
EOF

    title "Checking whether OperatorGroup in $ns exist..."
    existing_og=$(${OC} get operatorgroup -n $ns --no-headers --ignore-not-found | wc -l)
    if [[ ${existing_og} -ne 0 ]]; then
        success "OperatorGroup already exists in $ns. Skip creating\n"
        return 0
    fi
    info "Creating following OperatorGroup:\n"
    cat ${PREVIEW_DIR}/operatorgroup.yaml
    echo ""
    cat "${PREVIEW_DIR}/operatorgroup.yaml" | ${OC} apply -f -
    if [[ $? -ne 0 ]]; then
        error "Failed to create OperatorGroup ${name} in ${ns}\n"
    fi
}

function create_subscription() {
    local name=$1
    local ns=$2
    local channel=$3
    local package_name=$4
    local source=$5
    local source_ns=$6
    local install_mode=$7
    cat <<EOF > ${PREVIEW_DIR}/${name}-subscription.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: $name
  namespace: $ns
spec:
  channel: $channel
  installPlanApproval: $install_mode
  name: $package_name
  source: $source
  sourceNamespace: $source_ns
EOF

    info "Creating following Subscription:\n"
    cat ${PREVIEW_DIR}/${name}-subscription.yaml
    echo ""
    cat ${PREVIEW_DIR}/${name}-subscription.yaml | ${OC} apply -f -
    if [[ $? -ne 0 ]]; then
        error "Failed to create subscription ${name} in ${ns}\n"
    fi
}

function create_issuer() {
    local issuer_name=$1
    local namespace=$2
    debug1 "Creating Issuer $issuer_name in namespace $namespace ."
    cat <<EOF > ${PREVIEW_DIR}/issuer.yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: $issuer_name
  namespace: $namespace
spec:
  selfSigned: {}
EOF

    info "Creating following issuer:\n"
    cat ${PREVIEW_DIR}/issuer.yaml
    echo ""
    cat ${PREVIEW_DIR}/issuer.yaml | ${OC} apply -f -
    if [[ $? -ne 0 ]]; then
        error "Failed to create Issuer $issuer_name in $namespace \n"
    fi
}

function create_certificate() {
    local issuer_name=$1
    local cert_name=$2
    local sercret_name=$3
    local namespace=$4
    debug1 "Creating Certificate $cert_name in namespace $namespace ."
    cat <<EOF > ${PREVIEW_DIR}/certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: $cert_name
  namespace: $namespace
spec:
  commonName: $cert_name
  issuerRef:
    kind: Issuer
    name: $issuer_name
  secretName: $sercret_name
EOF

    info "Creating following certificate:\n"
    cat ${PREVIEW_DIR}/certificate.yaml
    echo ""
    cat ${PREVIEW_DIR}/certificate.yaml | ${OC} apply -f -
    if [[ $? -ne 0 ]]; then
        error "Failed to create test Certificate $cert_name in $namespace \n"
    fi
}

# Update/create cs cr
function update_cscr() {
    local operator_ns=$1
    local service_ns=$2
    local nss_list=${3:-""}

    for namespace in ${nss_list//,/ }
    do
        # update or create default CS CR in every namespace
        result=$("${OC}" get commonservice common-service -n ${namespace} --ignore-not-found)
        if [[ -z "${result}" ]]; then
            info "Creating CommonService CR common-service in $namespace"
            # copy commonservice from operator namespace
            ${OC} get commonservice common-service -n "${operator_ns}" -o yaml | ${YQ} eval '.spec += {"operatorNamespace": "'${operator_ns}'", "servicesNamespace": "'${service_ns}'"}' > /tmp/common-service.yaml
        else
            info "Configuring CommonService CR common-service in $namespace"
            ${OC} get commonservice common-service -n "${namespace}" -o yaml | ${YQ} eval '.spec += {"operatorNamespace": "'${operator_ns}'", "servicesNamespace": "'${service_ns}'"}' > /tmp/common-service.yaml
        fi
        ${YQ} eval 'select(.kind == "CommonService") | del(.metadata.resourceVersion) | del(.metadata.uid) | .metadata.namespace = "'${namespace}'"' /tmp/common-service.yaml | ${OC} apply --overwrite=true -f -
        if [[ $? -ne 0 ]]; then
            error "Failed to apply CommonService CR in ${namespace}"
        fi
    done

    rm /tmp/common-service.yaml
}

# Update nss cr
function update_nss_kind() {
    local operator_ns=$1
    local nss_list=$2
    local members=""
    for n in ${nss_list//,/ }
    do
        local members=$members$(cat <<EOF

    - $n
EOF
    )
    done

    local object=$(
        cat <<EOF
apiVersion: operator.ibm.com/v1
kind: NamespaceScope
metadata:
  name: common-service
  namespace: $operator_ns
spec:
  csvInjector:
    enable: true
  namespaceMembers: $members
  restartLabels:
    intent: projected
EOF
    )

    echo
    info "Updating the NamespaceScope object"
    echo "$object" | ${OC} apply -f -
    if [[ $? -ne 0 ]]; then
        error "Failed to create NSS CR in ${OPERATOR_NS}"
    fi
}

function create_nss_configmap(){
    local services_ns=$1
    local nss_list=$2
    local object=$(
        cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-scope
  namespace: $services_ns
data:
    namespaces: ${nss_list}
EOF
    )

    echo
    info "Creating the ConfigMap namesapce-scope in ${services_ns}"
    echo "$object" | ${OC} apply -f -
    if [[ $? -ne 0 ]]; then
        error "Failed to create NamespaceScope ConfigMap in ${services_ns}"
    fi
}

# ---------- creation functions end----------#

# ---------- cleanup functions start----------#

function cleanup_cp2() {
    local operator_ns=$1
    local service_ns=$2
    local control_ns=$3
    local nss_list=$4

    # Clean up the webhook, secretshare and crossplane for single shared CS instance or all namespaces mode
    if [[ "$operator_ns" == "$control_ns" ]] || [[ "$control_ns" == "$service_ns" ]]; then
        title "This is a single shared Common Service instance or all namespace mode upgrade, clean up webhook, secretshare and crossplane"
        cleanup_webhook $control_ns $nss_list
        cleanup_secretshare $control_ns $nss_list
        cleanup_crossplane
        cleanup_OperandBindInfo $control_ns
        cleanup_NamespaceScope $control_ns
    else
        cleanup_OperandBindInfo $operator_ns
        cleanup_NamespaceScope $operator_ns
    fi
}

# clean up webhook deployment and webhookconfiguration
function cleanup_webhook() {
    local control_ns=$1
    local nss_list=${2:-""}
    local resource_types=("podpresets.operator.ibm.com")
    for ns in ${nss_list//,/ }
    do
        delete_resources resource_types[@] $ns
    done
    msg ""

    cleanup_deployment "ibm-common-service-webhook" $control_ns

    info "Deleting MutatingWebhookConfiguration..."
    ${OC} delete MutatingWebhookConfiguration ibm-common-service-webhook-configuration --ignore-not-found
    ${OC} delete MutatingWebhookConfiguration ibm-operandrequest-webhook-configuration --ignore-not-found
    msg ""

    info "Deleting ValidatingWebhookConfiguration..."
    ${OC} delete ValidatingWebhookConfiguration ibm-cs-ns-mapping-webhook-configuration --ignore-not-found

}

# Clean up secretshare deployment and CR in service_ns
function cleanup_secretshare() {
    local control_ns=$1
    local nss_list=${2:-""}
    local resource_types=("secretshare")
    for ns in ${nss_list//,/ }
    do
        delete_resources resource_types[@] $ns
    done
    msg ""

    cleanup_deployment "secretshare" "$control_ns"
}

# Clean up crossplane sub and CR in operator_ns and service_ns
function cleanup_crossplane() {
    # Check if crossplane operator is installed or not
    local is_exist=$($OC get subscription.operators.coreos.com -A --no-headers | (grep ibm-crossplane || echo "fail") | awk '{print $1}')
    local resource_types=("configuration.pkg.ibm.crossplane.io" "lock.pkg.ibm.crossplane.io" "ProviderConfig")
    if [[ $is_exist == "fail" ]]; then
        # Delete CR
        msg "Cleanup crossplane CR"
        delete_resources resource_types[@] 

        # Delete Sub
        info "cleanup crossplane Subscription and ClusterServiceVersion"
        local namespace=$($OC get subscription.operators.coreos.com -A --no-headers | (grep ibm-crossplane-operator-app || echo "fail") | awk '{print $1}')
        if [[ $namespace != "fail" ]]; then
            delete_operator "ibm-crossplane-provider-kubernetes-operator-app" "$namespace"
            delete_operator "ibm-crossplane-provider-ibm-cloud-operator-app" "$namespace"
            delete_operator "ibm-crossplane-operator-app" "$namespace"
        fi
    else
        info "crossplane operator not exist, skip clean crossplane"
    fi
}

function cleanup_OperandBindInfo() {
    local namespace=$1
    ${OC} delete operandbindInfo ibm-commonui-bindinfo -n ${namespace} --ignore-not-found
}

function cleanup_NamespaceScope() {
    local namespace=$1
    resource_types=("namespacescope")

    delete_resources resource_types[@] $namespace
}

function cleanup_OperandRequest() {
    local namespace=$1
    ${OC} delete operandrequest ibm-commonui-request ibm-mongodb-request -n ${namespace} --ignore-not-found
}

function cleanup_deployment() {
    local name=$1
    local namespace=$2
    info "Deleting existing Deployment ${name} in namespace ${namespace}..."
    ${OC} delete deployment ${name} -n ${namespace} --ignore-not-found

    wait_for_no_pod ${namespace} ${name}
}

function delete_resources() {
    local resource_types=("${!1}")
    local namespace=${2:--A}
    local namespace_arg="-A"

    if [ $namespace != "-A" ]; then
        namespace_arg="-n $namespace"
    fi

    for resource_type in "${resource_types[@]}"; do
        msg "Deleting $resource_type resources..."
        # Retrieve resources of the specified type
        resources=$(${OC} get $resource_type ${namespace_arg} --no-headers --ignore-not-found | awk '{print $1}')
        for resource in $resources; do
            msg "Deleting $resource..."
            if ! ${OC} delete $resource_type $resource ${namespace_arg} --ignore-not-found --timeout=60s > /dev/null 2>&1; then
                warning "Deletion of $resource failed. Patching finalizer..."
                if [ "$namespace_arg" == "-A" ]; then
                    ${OC} patch $resource_type $resource --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
                else
                    ${OC} patch $resource_type $resource ${namespace_arg} --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
                fi
            fi
        done 
    done
}

# Clean up issuers, certificates and secrets
function cleanup_cm_resources() {
    local issuer_name=$1
    local cert_name=$2
    local sercret_name=$3
    local namespace=$4

    return_value_issuer=$(${OC} get issuer.v1.cert-manager.io $issuer_name -n $namespace --ignore-not-found )
    if [[ ! -z $return_value_issuer ]]; then
        info "Deleting $issuer_name Issuer ..."
        ${OC} delete issuer.v1.cert-manager.io $issuer_name -n $namespace --ignore-not-found
        msg ""
    fi

    return_value_cert=$(${OC} get certificate.v1.cert-manager.io $cert_name -n $namespace --ignore-not-found )
    if [[ ! -z $return_value_cert ]]; then
        info "Deleting $cert_name Certificate ..."
        ${OC} delete certificate.v1.cert-manager.io $cert_name -n $namespace --ignore-not-found
        msg ""

        info "Deleting $$secret_name Secret ..."
        ${OC} delete secret $sercret_name -n $namespace --ignore-not-found
        msg ""
    fi
}
  
# ---------- cleanup functions end ----------#

function get_control_namespace() {
    # Define the ConfigMap name and namespace
    local config_map_name="common-service-maps"

    # Get the ConfigMap data
    config_map_data=$(${OC} get configmap "${config_map_name}" -n kube-public -o yaml --ignore-not-found | ${YQ} '.data[]')

    # Check if the ConfigMap exists
    if [[ -z "${config_map_data}" ]]; then
        warning "Not found common-serivce-maps ConfigMap in kube-public namespace. It is a single shared Common Service instance or all namespace mode upgrade"
    else
        # Get the controlNamespace value
        control_namespace=$(echo "${config_map_data}" | ${YQ} -r '.controlNamespace')

        # Check if the controlNamespace key exists
        if [[ "${control_namespace}" == "null" ]] || [[ "${control_namespace}" == "" ]]; then
            warning "No controlNamespace is found from common-serivce-maps ConfigMap in kube-public namespace. It is a single shared Common Service instance upgrade"
        else
            CONTROL_NS=$control_namespace
        fi
    fi
}

function compare_semantic_version() {
    # if any channel is not set, return 2
    if [[ "$1" == "null" ]]; then
        info "Existing channel is not set, skip channel check"
        return 2
    fi
    if [[ "$2" == "null" ]]; then
        info "New channel is not set, skip channel check"
        return 2
    fi

    # Extract major, minor, and patch versions from the arguments
    regex='^v([0-9]+)\.?([0-9]*)\.?([0-9]*)?$'
    if [[ $1 =~ $regex ]]; then
        major1=${BASH_REMATCH[1]}
        minor1=${BASH_REMATCH[2]:-0}
        patch1=${BASH_REMATCH[3]:-0}

        if [[  $2 =~ $regex ]]; then
            major2=${BASH_REMATCH[1]}
            minor2=${BASH_REMATCH[2]:-0}
            patch2=${BASH_REMATCH[3]:-0}
        else
            error "Invalid version format: $2"
        fi
    else
        error "Invalid version format: $1"
    fi

    # If the versions have different number of components, add the missing parts
    if [[ -z "$minor1" && -z "$minor2" ]]; then
        minor1=0
        minor2=0
        patch1=0
        patch2=0
    elif [[ -z "$minor1" ]]; then
        minor1=0
        patch1=0
    elif [[ -z "$minor2" ]]; then
        minor2=0
        patch2=0
    fi

    # Compare the versions
    if [[ $major1 -gt $major2 ]]; then
        info "$1 is greater than $2"
        return 1
    elif [[ $major1 -lt $major2 ]]; then
        info "$1 is less than $2"
        return 2
    elif [[ $minor1 -gt $minor2 ]]; then
        info "$1 is greater than $2"
        return 1
    elif [[ $minor1 -lt $minor2 ]]; then
        info "$1 is less than $2"
        return 2
    elif [[ $patch1 -gt $patch2 ]]; then
        info "$1 is greater than $2"
        return 1
    elif [[ $patch1 -lt $patch2 ]]; then
        info "$1 is less than $2"
        return 2
    else
        info "$1 is equal to $2"
        return 0
    fi
}

function compare_catalogsource(){
    # Compare the catalogsource
    if [[ $1 == $2 ]]; then
        info "catalogsource $1 is the same as $2"
        return 0
    else
        info "catalogsource $1 is different from $2"
        return 1
    fi
}

function update_operator() {
    local package_name=$1
    local ns=$2
    local channel=$3
    local source=$4
    local source_ns=$5
    local install_mode=$6
    local remove_opreq_label=${7:-}
    local retries=5 # Number of retries
    local delay=5 # Delay between retries in seconds

    local sub_name=$(${OC} get subscription.operators.coreos.com -n ${ns} -l operators.coreos.com/${package_name}.${ns}='' --no-headers | awk '{print $1}')
    if [ -z "$sub_name" ]; then
        warning "Not found subscription ${package_name} in ${ns}"
        return 0
    fi

    title "Updating ${sub_name} in namesapce ${ns}..."

    # there is currently a bug with oc apply where the removed labels are added back by
    # something (either Open Shift or OLM), so need to use patch
    # "~1" is the escape sequence for "/" character
    if [ ! -z "$remove_opreq_label" ]; then
        ${OC} patch subscription.operators.coreos.com ${sub_name} -n ${ns} --type='json' -p='[{"op": "remove", "path": "/metadata/labels/operator.ibm.com~1opreq-control"}]' || warning "Could not patch Subscription ${sub_name} in ${ns} to remove label"
    fi

    while [ $retries -gt 0 ]; do
        # Retrieve the latest version of the subscription
        ${OC} get subscription.operators.coreos.com ${sub_name} -n ${ns} -o yaml > /tmp/sub.yaml

        existing_channel=$(${YQ} eval '.spec.channel' /tmp/sub.yaml)
        existing_catalogsource=$(${YQ} eval '.spec.source' /tmp/sub.yaml)

        compare_semantic_version $existing_channel $channel
        return_channel_value=$?

        compare_catalogsource $existing_catalogsource $source
        return_catsrc_value=$?

        if [[ $return_channel_value -eq 1 ]]; then
            error "Failed to update channel subscription ${package_name} in ${ns}"
        elif [[ $return_channel_value -eq 2 || $return_catsrc_value -eq 1 ]]; then
            info "$package_name is ready for updating the subscription."
        elif [[ $return_channel_value -eq 0 && $return_catsrc_value -eq 0 ]]; then
            info "$package_name has already updated channel $existing_channel and catalogsource $existing_catalogsource in the subscription."
        fi

        # Update the subscription with the desired changes
        if [[ "$channel" == "null" ]]; then
            ${YQ} -i eval 'select(.kind == "Subscription") | .spec += {"channel": null}' /tmp/sub.yaml
        else
            ${YQ} -i eval 'select(.kind == "Subscription") | .spec += {"channel": "'${channel}'"}' /tmp/sub.yaml
        fi
        ${YQ} -i eval 'select(.kind == "Subscription") | .spec += {"source": "'${source}'"}' /tmp/sub.yaml
        ${YQ} -i eval 'select(.kind == "Subscription") | .spec += {"sourceNamespace": "'${source_ns}'"}' /tmp/sub.yaml
        ${YQ} -i eval 'select(.kind == "Subscription") | .spec += {"installPlanApproval": "'${install_mode}'"}' /tmp/sub.yaml

        # Apply the patch
        ${OC} apply -f /tmp/sub.yaml

        # Check if the patch was successful
        if [[ $? -eq 0 ]]; then
            success "Successfully patched subscription ${package_name} in ${ns}"
            rm /tmp/sub.yaml
            return 0
        else
            warning "Failed to patch subscription ${package_name} in ${ns}. Retrying in ${delay} seconds..."
            sleep ${delay}
            retries=$((retries-1))
        fi
    done

    error "Maximum retries reached. Failed to patch subscription ${sub_name} in ${ns}"
    rm /tmp/sub.yaml
    return 1
}

function delete_operator() {
    subs=$1
    ns=$2
    for sub in ${subs}; do
        title "Deleting ${sub} in namesapce ${ns}..."
        csv=$(${OC} get subscription.operators.coreos.com ${sub} -n ${ns} -o=jsonpath='{.status.installedCSV}' --ignore-not-found)
        in_step=1
        msg "[${in_step}] Removing the subscription of ${sub} in namesapce ${ns} ..."
        ${OC} delete sub ${sub} -n ${ns} --ignore-not-found
        in_step=$((in_step + 1))
        msg "[${in_step}] Removing the csv of ${sub} in namesapce ${ns} ..."
        [[ "X${csv}" != "X" ]] && ${OC} delete csv ${csv}  -n ${ns} --ignore-not-found
        msg ""

        success "Remove $sub successfully."
        msg ""
    done
}

function scale_deployment_csv() {
    local ns=$1
    local csv=$2
    local replicas=$3
    ${OC} patch csv ${csv} -n ${ns} --type='json' -p='[{"op": "replace", "path": "/spec/install/spec/deployments/0/spec/replicas", "value": '$((replicas))'}]'
}

function check_deployment(){
    local ns=$1
    local deployment=$2
    local replicas=$3
    local retries=5
    local count=0

    while [ $count -lt $retries ]; do
        local current_replicas=$(${OC} get deployment ${deployment} -n ${ns} --ignore-not-found -o jsonpath='{.spec.replicas}')

        if [[ -z "$current_replicas" ]]; then
            current_replicas=0
        fi

        if [ "$current_replicas" -eq "$replicas" ]; then
            success "Replicas count is as expected: $current_replicas"
            return 0
        else
            warning "Replica count is not as expected: $current_replicas (expected: $replicas)"
            count=$((count+1))
            sleep 5
        fi
    done

    msg "Failed to reach expected replica count after $retries attempts, scaling deployment..."
    return 1
}

function scale_deployment() {
    local ns=$1
    local deployment=$2
    ${OC} scale deployment ${deployment} -n ${ns} --replicas=$3
}

function scale_down() {
    local operator_ns=$1
    local services_ns=$2
    local channel=$3
    local source=$4
    local cs_sub=$(${OC} get subscription.operators.coreos.com -n ${operator_ns} -l operators.coreos.com/ibm-common-service-operator.${operator_ns}='' --no-headers | awk '{print $1}')
    local cs_CSV=$(${OC} get subscription.operators.coreos.com ${cs_sub} -n ${operator_ns} --ignore-not-found -o jsonpath={.status.installedCSV})
    local odlm_sub=$(${OC} get subscription.operators.coreos.com -n ${services_ns} -l operators.coreos.com/ibm-odlm.${services_ns}='' --no-headers | awk '{print $1}')
    local odlm_CSV=$(${OC} get subscription.operators.coreos.com ${odlm_sub} -n ${services_ns} --ignore-not-found -o jsonpath={.status.installedCSV})

    ${OC} get subscription.operators.coreos.com ${cs_sub} -n ${operator_ns} -o yaml > /tmp/sub.yaml

    existing_channel=$(${YQ} eval '.spec.channel' /tmp/sub.yaml)
    existing_catalogsource=$(${YQ} eval '.spec.source' /tmp/sub.yaml)
    compare_semantic_version $existing_channel $channel
    return_channel_value=$?

    compare_catalogsource $existing_catalogsource $source
    return_catsrc_value=$?

    if [[ $return_channel_value -eq 1 ]]; then
        error "Must provide correct channel. The channel $CHANNEl is less than $existing_channel found in subscription ibm-common-service-operator in $operator_ns"
    elif [[ $return_channel_value -eq 2 || $return_catsrc_value -eq 1 ]]; then
        info "$cs_sub is ready for scaling down."
    elif [[ $return_channel_value -eq 0 && $return_catsrc_value -eq 0 ]]; then
        info "$cs_sub already has updated channel $existing_channel and catalogsource $existing_catalogsource in the subscription."
    fi

    # Scale down CS
    title "Patching CSV ${cs_sub} to scale down deployment in ${operator_ns} namespace to 0..."
    if [[ ! -z "$cs_CSV" ]]; then
        scale_deployment_csv $operator_ns $cs_CSV 0
    fi
    check_deployment $operator_ns ibm-common-service-operator 0
    if [[ $? -ne 0 ]]; then
        msg "Scaling down ibm-common-service-operator deployment in ${operator_ns} namespace to 0..."
        scale_deployment $operator_ns ibm-common-service-operator 0
    fi

    # Scale down ODLM
    title "Patching CSV to scale down operand-deployment-lifecycle-manager deployment in ${services_ns} namespace to 0..."
    if [[ ! -z "$odlm_CSV" ]]; then
        scale_deployment_csv $services_ns $odlm_CSV 0
    fi
    check_deployment $services_ns operand-deployment-lifecycle-manager 0
    if [[ $? -ne 0 ]]; then
        msg "Scaling down operand-deployment-lifecycle-manager deployment in ${services_ns} namespace to 0..."
        scale_deployment $services_ns operand-deployment-lifecycle-manager 0
    fi

    # delete OperandRegistry
    info "Deleting OperandRegistry common-service in ${services_ns} namespace..."
    ${OC} delete operandregistry common-service -n ${services_ns} --ignore-not-found

    # delete validatingwebhookconfiguration
    info "Deleting ValidatingWebhookConfiguration ibm-common-service-validating-webhook-${operator_ns} in ${operator_ns} namespace..."
    ${OC} delete ValidatingWebhookConfiguration ibm-common-service-validating-webhook-${operator_ns} --ignore-not-found
    rm sub.yaml
}

function delete_webhook_configuration(){
    local operator_ns=$1
    # Find the webhook that matches the labels 
    local webhook_name=$(${OC} get validatingwebhookconfiguration -n $operator_ns -l olm.owner.kind=ClusterServiceVersion,olm.owner.namespace=$operator_ns -o=yaml | ${YQ} e '.items[] | select(.metadata.labels."olm.owner" | test("ibm-common-service-operator.v[0-9.]+")) | .metadata.name' -)

    # Check if a matching webhook was found, and delete it if so
    if [ -n "$webhook_name" ]; then
        info "Deleting ValidatingWebhookConfiguration '$webhook_name' in '$operator_ns'..."
        ${OC} delete ValidatingWebhookConfiguration "$webhook_name"
        echo "Webhook '$webhook_name' deleted."
    else
        echo "No matching webhook found."
    fi
}

function wait_for_operand_registry() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get operandregistry ${name} --no-headers --ignore-not-found"
    local retries=20
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for OperandRegistry ${name} to be present"
    local success_message="OperandRegistry ${name} is present"
    local error_message="Timeout after ${total_time_mins} minutes waiting for operand registry ${name} to be present"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function scale_up() {
    local operator_ns=$1
    local services_ns=$2
    local package_name=$3
    local deployment=$4
    local sub=$(${OC} get subscription.operators.coreos.com -n ${operator_ns} -l operators.coreos.com/${package_name}.${operator_ns}='' --no-headers | awk '{print $1}')
    local csv=$(${OC} get subscription.operators.coreos.com ${sub} -n ${operator_ns} --ignore-not-found -o jsonpath={.status.installedCSV})

    if [[ "$deployment" == "operand-deployment-lifecycle-manager" ]]; then
        wait_for_operand_registry ${services_ns} common-service
    fi
    msg "Patching CSV ${csv} to scale up deployment in ${operator_ns} namespace back to 1..."
    scale_deployment_csv $operator_ns $csv 1
    check_deployment $operator_ns $deployment 1
    if [[ $? -ne 0 ]]; then
        msg "Scaling up ${deployment} deployment in ${operator_ns} namespace back to 1..."
        scale_deployment $operator_ns $deployment 1
    fi
}

function accept_license() {
    local kind=$1
    local namespace=$2
    local cr_name=$3
    title "Accepting license for $kind $cr_name in namespace $namespace..."
    if [[ $PREVIEW_MODE -eq 1 ]]; then
        info "Preview mode is on, skip patching license acceptance\n"
        return 0
    fi

    if [[ -z "$(${OC} get $kind $cr_name -n $namespace --ignore-not-found)" ]]; then
        warning "Not found $kind $cr_name in $namespace, skipping updating license acceptance\n"
        return 0
    fi

    local result=$(${OC} patch "$kind" "$cr_name" -n "$namespace" --type='merge' -p '{"spec":{"license":{"accept":true}}}' || echo "fail")
    if [[ "${result}" == "fail" ]]; then
        warning "Failed to update license acceptance for $kind CR $cr_name\n"
    else
        success "License accepted for $kind $cr_name\n"
    fi
}


function fetch_sub_from_package() {
    local package=$1
    local ns=$2

    ${OC} get subscription.operators.coreos.com -n "$ns" -o jsonpath="{.items[?(@.spec.name=='$package')].metadata.name}"
}

function fetch_csv_from_sub() {
    local sub=$1
    local ns=$2

    ${OC} get csv -n "$ns" | grep "$sub" | cut -d ' ' -f1
}

function remove_all_finalizers() {
    local ns=$1

    apiGroups=$(${OC} api-resources --namespaced -o name)
    delete_operand_finalizer "${apiGroups}" "${ns}"

}

function delete_operand_finalizer() {
    local crds=$1
    local ns=$2
    for crd in ${crds}; do
        if [ "${crd}" != "packagemanifests.packages.operators.coreos.com" ] && [ "${crd}" != "events" ] && [ "${crd}" != "events.events.k8s.io" ]; then
            crs=$(${OC} get "${crd}" --no-headers --ignore-not-found -n "${ns}" 2>/dev/null | awk '{print $1}')
            for cr in ${crs}; do
                msg "Removing the finalizers for resource: ${crd}/${cr}"
                ${OC} patch ${crd} ${cr} -n ${ns} --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]' 2>/dev/null
            done
        fi
    done
}

function save_log(){
    local LOG_DIR="$BASE_DIR/$1"
    LOG_FILE="$LOG_DIR/$2_$(date +'%Y%m%d%H%M%S').log"
    local debug=$3

    if [ $debug -eq 1 ]; then
        if [[ ! -d $LOG_DIR ]]; then
            mkdir -p "$LOG_DIR"
        fi

        # Create a named pipe
        PIPE=$(mktemp -u)
        mkfifo "$PIPE"

        # Tee the output to both the log file and the terminal
        tee "$LOG_FILE" < "$PIPE" &

        # Redirect stdout and stderr to the named pipe
        exec > "$PIPE" 2>&1

        # Remove the named pipe
        rm "$PIPE"
    fi
}

function cleanup_log() {
    # Check if the log file already exists
    if [[ -e $LOG_FILE ]]; then
        # Remove ANSI escape sequences from log file
        sed -E 's/\x1B\[[0-9;]+[A-Za-z]//g' "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

function debug1() {
    if [ $DEBUG -eq 1 ]; then
       debug "${1}"
    fi
}

# check if version of CS supports delegation for ibm-cert-manager-operator
# >= v3.19.9 if in v3 channel
# or >= v3.21.0 in any other channel
function is_supports_delegation() {
    local version=$1
    major=$(echo "$version" | cut -d '.' -f1 | cut -d 'v' -f2)
    minor=$(echo "$version" | cut -d '.' -f2)
    patch=$(echo "$version" | cut -d '.' -f3)

    if [ -z "$version" ]; then
        info "No ibm-common-service-operator found on the cluster, skipping delegation check"
        return 0
    fi

    if [ "$major" -gt 3 ]; then
        info "Major version is greater than 3, skipping delegation check"
        return 0
    fi

    if [ "$major" -lt 3 ]; then
        return 1
    fi

    if [ "$minor" -lt 19 ]; then
        return 1
    fi

    # only LTSR starting from 3.19.9 supported delegation
    if [ "$minor" -eq 19 ]; then
        if [ "$patch" -lt 9 ]; then
            return 1
        fi
    fi

    echo "Version: $version supports cert-manager delegation"
}

function prepare_preview_mode() {
    mkdir -p ${PREVIEW_DIR}
    if [[ $PREVIEW_MODE -eq 1 ]]; then
        OC_CMD="${OC} --dry-run=client" # a redirect to the file is needed too
    fi
}
