#!/usr/bin/env bash
#
# Copyright 2022 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -o errexit
set -o pipefail
set -o errtrace
set -o nounset
MASTER_NS=
CONTROL_NS=
cm_name="common-service-maps"
OC=oc
YQ=yq
DEBUG=0


function main() {
    which "${OC}" || error "Missing oc CLI"
    which "${YQ}" || error "Missing yq"
    while [ "$#" -gt "0" ]
    do
        case "$1" in
        "-h"|"--help")
            usage
            exit 0
            ;;
        "--original-cs-ns")
            MASTER_NS=$2
            shift
            ;;
        "--control-ns")
            CONTROL_NS=$2
            shift
            ;;
        -v | --debug)
            DEBUG=1
            ;;
        *)
            error "invalid option -- \`$1\`. Use the -h or --help option for usage info."
            ;;
        esac
        shift
    done
    
    if [[ -z $CONTROL_NS ]]; then
        error "Control namespace not specified, please specify control namespace parameter and try again."
    fi
    if [[ -z $MASTER_NS ]]; then
        error "Original common services namespace not specified, please specify common services namespace parameter and try again."
    fi
    collect_data
    rollback
}

function usage() {
	local script="${0##*/}"

	while read -r ; do echo "${REPLY}" ; done <<-EOF
	Usage: ${script} [OPTION]...
	Uninstall common services
	Options:
	Mandatory arguments to long options are mandatory for short options too.
	  -h, --help                    display this help and exit
      --original-cs-ns              specify the original common services namespace
      --control-ns                  specify the existing control namespace
      -v, --debug integer           Verbosity of logs. Default is 0. Set to 1 for debug logs.
	EOF
}

function collect_data() {
    title "Collecting data"
    msg "-----------------------------------------------------------------------"
    
    # info "MasterNS:${master_ns}"
    # cs_operator_channel=$(${OC} get subscription.operators.coreos.com ibm-common-service-operator -n ${master_ns} -o yaml | yq ".spec.channel") 
    # info "channel:${cs_operator_channel}"   
    # catalog_source=$(${OC} get subscription.operators.coreos.com ibm-common-service-operator -n ${master_ns} -o yaml | yq ".spec.source")
    # info "catalog_source:${catalog_source}" 
    #this command gets all of the ns listed in requested from namesapce fields
    requested_ns=$("${OC}" get configmap -n kube-public -o yaml ${cm_name} | yq '.data[]' | yq '.namespaceMapping[].requested-from-namespace' | awk '{print $2}' | tr '\n' ' ')
    #this command gets all of the ns listed in map-to-common-service-namespace
    map_to_cs_ns=$("${OC}" get configmap -n kube-public -o yaml ${cm_name} | yq '.data[]' | yq '.namespaceMapping[].map-to-common-service-namespace' | awk '{print}' | tr '\n' ' ')
    if [[ $MASTER_NS != ${map_to_cs_ns%%[[:space:]]} ]]; then
        error "The original common service namespace value entered does not match the value in the common-service-maps configmap. Make sure there is only one \"map-to-common-service-namesapce\" value specified in the configmap"
    fi
}

function rollback() {
    info "Reverting multi-instance environment to shared instance environment."

    #checking if control namespace removed from common-service-maps
    return_value=$("${OC}" get configmap -n kube-public -o yaml ${cm_name} | yq '.data' | grep controlNamespace: > /dev/null || echo passed)
    if [[ $return_value != "passed" ]]; then
        error "Configmap: ${cm_name} still has controlNamespace field. This must be removed before proceeding with rollback."
    fi
    return_value="reset"
    
    info "Converting back to shared instance in ${MASTER_NS} namespace."
    # scale down
    ${OC} scale deployment -n ${MASTER_NS} ibm-common-service-operator --replicas=0
    ${OC} scale deployment -n ${MASTER_NS} operand-deployment-lifecycle-manager --replicas=0
    
    #delete operand config and operand registry
    ${OC} delete operandregistry -n ${MASTER_NS} --ignore-not-found common-service 
    ${OC} delete operandconfig -n ${MASTER_NS} --ignore-not-found common-service
    
    # uninstall singleton services
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found certmanagers.operator.ibm.com default
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found sub ibm-cert-manager-operator
    csv=$("${OC}" get -n "${CONTROL_NS}" csv | (grep ibm-cert-manager-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found csv "${csv}"
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found deploy cert-manager-cainjector cert-manager-controller cert-manager-webhook ibm-cert-manager-operator

    return_value=$(("${OC}" get crd ibmlicenseservicereporters.operator.ibm.com > /dev/null && echo exists) || echo fail)
    if [[ $return_value == "exists" ]]; then
        "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found ibmlicensing instance
    fi
    return_value="reset"
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found sub ibm-licensing-operator
    csv=$("${OC}" get -n "${CONTROL_NS}" csv | (grep ibm-licensing-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found csv "${csv}"
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found deploy ibm-licensing-operator ibm-licensing-service-instance
    "${OC}" patch -n "${CONTROL_NS}" operandbindinfo ibm-licensing-bindinfo --type=merge -p '{"metadata": {"finalizers":null}}' || info "Licensing OperandBindInfo not found in ${CONTROL_NS}. Moving on..."
    "${OC}" delete --ignore-not-found -n "${CONTROL_NS}" operandbindinfo ibm-licensing-bindinfo
    
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found sub ibm-crossplane-operator-app
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found sub ibm-crossplane-provider-kubernetes-operator-app
    csv=$("${OC}" get -n "${CONTROL_NS}" csv | (grep ibm-crossplane-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found csv "${csv}"
    csv=$("${OC}" get -n "${CONTROL_NS}" csv | (grep ibm-crossplane-provider-kubernetes-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found csv "${csv}"

    csv=$("${OC}" get -n "${CONTROL_NS}" csv | (grep ibm-namespace-scope-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found sub ibm-namespace-scope-operator
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found csv "${csv}"
    "${OC}" patch namespacescope common-service -n "${CONTROL_NS}" --type=merge -p '{"metadata": {"finalizers":null}}' || info "Namespacescope resource not found in ${CONTROL_NS}. Moving on..."
    "${OC}" delete namespacescope common-service -n "${CONTROL_NS}" --ignore-not-found
    "${OC}" delete -n "${CONTROL_NS}" --ignore-not-found deploy ibm-namespace-scope-operator

    cleanup_webhook
    cleanup_deployment "secretshare" "$CONTROL_NS"

    info "Deleting control namespace ${CONTROL_NS}"
    ${OC} delete namespace ${CONTROL_NS} --ignore-not-found

    removeNSS
    cleanupZenService
    update_opreqs
    un_isolate_odlm "ibm-odlm" $MASTER_NS

    # scale back up
    scale_up_pod

    #verify singleton's are installed in master ns
    retries=20
    sleep_time=15
    total_time_mins=$(( sleep_time * retries / 60))
    info "Waiting for singleton services to deploy to ${MASTER_NS}..."
    sleep 10
    
    while true; do
        if [[ ${retries} -eq 0 ]]; then
            error "Timeout after ${total_time_mins} minutes waiting for IBM Common Services is deployed"
        fi

        certPodCheck=$("${OC}" get pods -n "${MASTER_NS}" | (grep ibm-cert-manager || echo "fail") | awk '{print $1}')
        licPodCheck=$("${OC}" get pods -n "${MASTER_NS}" | (grep ibm-licensing-service || echo "fail") | awk '{print $1}')
        if [ $certPodCheck != "fail" ] || [ $licPodCheck != "fail" ]; then
            info "Singleton services successfully re-deployed in ${MASTER_NS}"
            break
        else
            certPodCheck=$("${OC}" get pods -n "${CONTROL_NS}" --ignore-not-found | (grep ibm-cert-manager || echo "fail") | awk '{print $1}')
            licPodCheck=$("${OC}" get pods -n "${CONTROL_NS}" --ignore-not-found | (grep ibm-licensing-service || echo "fail") | awk '{print $1}')
            if [ $certPodCheck != "fail" ] || [ $licPodCheck != "fail" ]; then
                error "Singleton services re-deployed into control namespace. Verify that the common-services-map configmap in kube-public namespace has had the \"controlNamespace\" field removed and run again."
            else
                info "RETRYING: Waiting for singleton services to deploy to ${MASTER_NS}... (${retries} left)"
            fi
        fi
        retries=$(( retries - 1 ))
        sleep $sleep_time
    done

    refresh_zen
    refresh_kafka

    success "Cluster successfully rolled back from multi-instance to shared-instance."

}

function removeNSS(){
    
    title " Removing ODLM managed Namespace Scope CRs "
    msg "-----------------------------------------------------------------------"

    info "deleting namespace scope nss-managedby-odlm in namespace $MASTER_NS"
    ${OC} delete nss nss-managedby-odlm -n $MASTER_NS --ignore-not-found || (error "unable to delete namespace scope nss-managedby-odlm in $MASTER_NS")
    info "deleting namespace scope odlm-scope-managedby-odlm in namespace $MASTER_NS"
    ${OC} delete nss odlm-scope-managedby-odlm -n $MASTER_NS --ignore-not-found || (error "unable to delete namespace scope odlm-scope-managedby-odlm in $MASTER_NS")
    
    info "deleting namespace scope nss-odlm-scope in namespace $MASTER_NS"
    ${OC} delete nss nss-odlm-scope -n $MASTER_NS --ignore-not-found || (error "unable to delete namespace scope nss-odlm-scope in $MASTER_NS")
    
    info "deleting namespace scope common-service in namespace $MASTER_NS"
    ${OC} delete nss common-service -n $MASTER_NS --ignore-not-found || (error "unable to delete namespace scope common-service in $MASTER_NS")

    success "Namespace Scope CRs cleaned up"
}

function check_healthy() {
    local CS_NAMESPACE=$1

    sleep 10

    retries=20
    sleep_time=15
    total_time_mins=$(( sleep_time * retries / 60))
    info "Waiting for IBM Common Services CR is Succeeded"
    sleep 10
    pod=$(oc get pods -n ${CS_NAMESPACE} | grep ibm-common-service-operator | awk '{print $1}')
    
    while true; do
        if [[ ${retries} -eq 0 ]]; then
            error "Timeout after ${total_time_mins} minutes waiting for IBM Common Services is deployed"
        fi

        phase=$(oc get pod ${pod} -o jsonpath='{.status.phase}' -n ${CS_NAMESPACE})

        if [[ "${phase}" != "Running" ]]; then
            retries=$(( retries - 1 ))
            info "RETRYING: Waiting for IBM Common Services CR is Succeeded (${retries} left)"
            sleep ${sleep_time}
        else
            msg "-----------------------------------------------------------------------"    
            success "Common Services is deployed in ${CS_NAMESPACE}"
            break
        fi
    done
}

function cleanupZenService(){
    title " Cleaning up Zen installation "
    msg "-----------------------------------------------------------------------"
    namespaces="$requested_ns $MASTER_NS"
    for namespace in $namespaces
    do
        # remove cs namespace from zen service cr
        return_value=$(${OC} get zenservice -n ${namespace} || echo "fail")
        if [[ $return_value != "fail" ]]; then
            if [[ $return_value != "" ]]; then
                zenServiceCR=$(${OC} get zenservice -n ${namespace} | awk '{if (NR!=1) {print $1}}')
                ${OC} patch zenservice ${zenServiceCR} -n ${namespace} --type json -p '[{ "op": "remove", "path": "/spec/csNamespace" }]' || info "CS Namespace not defined in ${zenServiceCR} in ${namespace}. Moving on..."
            else
                info "No zen service in namespace ${namespace}. Moving on..."
            fi
        else
          info "Zen not installed in ${namespace}. Moving on..."
        fi
        return_value=""

        # delete iam config job
        return_value=$(${OC} get job -n ${namespace} | grep iam-config-job || echo "fail")
        if [[ $return_value != "fail" ]]; then
            ${OC} delete job iam-config-job -n ${namespace}
        else
            info "iam-config-job not present in namespace ${namespace}. Moving on..."
        fi

        # delete zen client
        return_value=$(${OC} get client -n ${namespace} || echo "fail")
        if [[ $return_value != "fail" ]]; then
            if [[ $return_value != "" ]]; then
                zenClient=$(${OC} get client -n ${namespace} | awk '{if (NR!=1) {print $1}}')
                ${OC} patch client ${zenClient} -n ${namespace} --type=merge -p '{"metadata": {"finalizers":null}}'
                ${OC} delete client ${zenClient} -n ${namespace}
            else
                info "No zen client in ${namespace}. Moving on..."
            fi
        else
            info "Zen not installed in ${namespace}. Moving on..."
        fi
        return_value=""
    done
    
    success "Zen instances cleaned up"
}

# wait for new cs to be ready
function check_IAM(){
    sleep 10

    local nsFromNSS=$(${OC} get nss -n $MASTER_NS -o yaml common-service | ${YQ} '.status.validatedMembers[]' | tr '\n' ' ')
    iam_enabled="false"
    for cp_namespace in $nsFromNSS
    do
        zenservice_exists=$(${OC} get zenservice -n $cp_namespace || echo fail)
        if [[ $zenservice_exists != "fail" ]] && [[ $zenservice_exists != "" ]]; then
            zenservice=$(${OC} get zenservice -n $cp_namespace --no-headers | awk '{print $1}')
            iam_enabled=$(${OC} get zenservice $zenservice -n $cp_namespace -o yaml | ${YQ} '.spec.iamIntegration')
            if [[ $iam_enabled == "true" ]]; then
                break
            fi
        fi
    done
    
    if [[ $iam_enabled == "true" ]]; then
        retries=40
        sleep_time=30
        total_time_mins=$(( sleep_time * retries / 60))
        info "Waiting for IAM to come ready in namespace $MASTER_NS"
        sleep 10
        local cm="ibm-common-services-status"
        local statusName="$MASTER_NS-iamstatus"
        
        while true; do
            if [[ ${retries} -eq 0 ]]; then
                error "Timeout after ${total_time_mins} minutes waiting for IAM to come ready in namespace $MASTER_NS"
            fi

            iamReady=$("${OC}" get configmap -n kube-public -o yaml ${cm} | (grep $statusName || echo fail))

            if [[ "${iamReady}" == "fail" ]]; then
                retries=$(( retries - 1 ))
                info "RETRYING: Waiting for IAM service to be Ready (${retries} left)"
                sleep ${sleep_time}
            else
                msg "-----------------------------------------------------------------------"    
                success "IAM Service Ready in $MASTER_NS"
                break
            fi
        done
    else
        info "IAM not requested by zen, skipping wait."
    fi
}

# update zenservice CRs to be reconciled again
function refresh_zen(){
    title " Refreshing Zen Services "
    msg "-----------------------------------------------------------------------"
    #make sure IAM is ready before reconciling.
    check_IAM #this will likely need to change in the future depending on how we check iam status
    local namespaces="$requested_ns $MASTER_NS"
    for namespace in $namespaces
    do
        return_value=$(${OC} get zenservice -n ${namespace} || echo "fail")
        if [[ $return_value != "fail" ]]; then
            if [[ $return_value != "" ]]; then
                return_value=""
                zenServiceCR=$(${OC} get zenservice -n ${namespace} | awk '{if (NR!=1) {print $1}}')
                conversionField=$("${OC}" get zenservice ${zenServiceCR} -n ${namespace} -o yaml | yq '.spec | has("conversion")')
                if [[ $conversionField == "false" ]]; then
                    ${OC} patch zenservice ${zenServiceCR} -n ${namespace} --type='merge' -p '{"spec":{"conversion":"true"}}' || error "Zenservice ${zenServiceCR} in ${namespace} cannot be updated."
                else
                    ${OC} patch zenservice ${zenServiceCR} -n ${namespace} --type json -p '[{ "op": "remove", "path": "/spec/conversion" }]' || error "Zenservice ${zenServiceCR} in ${namespace} cannot be updated."
                fi
                conversionField=""
            else
                info "No zen service in namespace ${namespace}. Moving on..."
            fi
        else
          info "Zen not installed in ${namespace}. Moving on..."
        fi
        return_value=""
    done

    success "Reconcile loop initiated for Zenservice instances"
}

function refresh_kafka () {
    return_value=$(${OC} get kafkaclaim -A || echo fail)
    if [[ $return_value != "fail" ]]; then
        title " Refreshing Kafka Deployments "
        msg "-----------------------------------------------------------------------"
        local namespaces="$requested_ns $MASTER_NS"
        for namespace in $namespaces
        do
            return_value=$(${OC} get kafkaclaim -n ${namespace} || echo "fail")
            if [[ $return_value != "fail" ]]; then
                if [[ $return_value != "" ]]; then
                    kafkaClaims=$(${OC} get kafkaclaim -n ${namespace} | awk '{if (NR!=1) {print $1}}')
                    #copy kc to file, delete original kc, re-apply copied file (check for an existing of the same name)
                    for kc in $kafkaClaims
                    do
                        ${OC} get kafkaclaim -n ${namespace} $kc -o yaml > tmp.yaml
                        ${OC} patch kafkaclaim ${kc} -n ${namespace} --type=merge -p '{"metadata": {"finalizers":null}}'
                        ${OC} delete kafkaclaim ${kc} -n ${namespace} 
                        ${OC} apply -f tmp.yaml  || info "kafkaclaim ${kc} already recreated. Moving on..."
                    done
                else
                    info "No kafkaclaim in namespace ${namespace}. Moving on..."
                fi
            else
            info "Kafka not installed in ${namespace}. Moving on..."
            fi
            return_value=""
        done
        
        rm tmp.yaml -f
        success "Reconcile loop initiated for Kafka instances"
    else
        info "Kafka not installed on cluster, no refresh needed."
    fi
}

function scale_up_pod() {
    info "scaling back ibm-common-service-operator deployment in ${MASTER_NS} namespace"
    ${OC} scale deployment -n ${MASTER_NS} ibm-common-service-operator --replicas=1
    ${OC} scale deployment -n ${MASTER_NS} operand-deployment-lifecycle-manager --replicas=1
    check_healthy "${MASTER_NS}"
}

function un_isolate_odlm() {
    local package_name=$1
    local ns=$2
    # get subscription of ODLM based on namespace 
    local sub_name=$(${OC} get subscription.operators.coreos.com -n ${ns} -l operators.coreos.com/${package_name}.${ns}='' --no-headers | awk '{print $1}')
    if [ -z "$sub_name" ]; then
        warning "Not found subscription ${package_name} in ${ns}"
        return 0
    fi
    #merge patch overwrites the entire array if you update any values so we need to get any other value specified and make sure it is unchanged
    #loop through all of the values specified in spec.config.env
    env_range=$(${OC} get subscription.operators.coreos.com ${sub_name} -n ${ns} -o yaml | yq '.spec.config.env[].name')
    patch_string=""
    count=0
    for name in $env_range
    do
        #If isolated mode, set value to true. Otherwise keep name value pairs unchanged.
        if [[ $name == "ISOLATED_MODE" ]]; then
            env_value="false"
        else
            env_value=$(${OC} get subscription.operators.coreos.com ${sub_name} -n ${ns} -o yaml | yq '.spec.config.env['"${count}"'].value')
        fi
        #Add name value pair in json format to the patch string
        if [[ $patch_string == "" ]]; then
            patch_string="{\"name\": \"$name\", \"value\": \"$env_value\"}"
        else
            patch_string="$patch_string, {\"name\": \"$name\", \"value\": \"$env_value\"}"
        fi
        count=$((count + 1))
    done
    debug1 "patch string $patch_string"
    #use the patch string to apply the isolate mode patch
    ${OC} patch subscription.operators.coreos.com ${sub_name} -n ${ns} --type=merge -p '{"spec": {"config": {"env": ['"${patch_string}"']}}}'
    if [[ $? -ne 0 ]]; then
        error "Failed to update subscription ${package_name} in ${ns}"
    fi

    check_odlm_env "${ns}" 
}

function check_odlm_env() {
    local namespace=$1
    local name="operand-deployment-lifecycle-manager"
    local condition="${OC} -n ${namespace} get deployment ${name} -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name==\"ISOLATED_MODE\")].value}'| grep "false" || true"
    local retries=10
    local sleep_time=12
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for OLM to update Deployment ${name} "
    local success_message="Deployment ${name} is updated to not run in isolated mode"
    local error_message="Timeout after ${total_time_mins} minutes waiting for OLM to update Deployment ${name} "

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
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
        success "${success_message}"
    fi
}

function cleanup_deployment() {
    local name=$1
    local namespace=$2
    info "Deleting existing Deployment ${name} in namespace ${namespace}..."
    ${OC} delete deployment ${name} -n ${namespace} --ignore-not-found
}

function cleanup_webhook() {
    podpreset_exist="true"
    podpreset_exist=$(${OC} get podpresets.operator.ibm.com -n $CONTROL_NS --no-headers || echo "false")
    if [[ $podpreset_exist != "false" ]] && [[ $podpreset_exist != "" ]]; then
        echo $podpreset_exist
        info "Deleting podpresets in namespace $CONTROL_NS..."
        ${OC} get podpresets.operator.ibm.com -n $CONTROL_NS --no-headers --ignore-not-found | awk '{print $1}' | xargs ${OC} delete -n $CONTROL_NS --ignore-not-found podpresets.operator.ibm.com
    fi

    cleanup_deployment "ibm-common-service-webhook" $CONTROL_NS

    info "Deleting MutatingWebhookConfiguration..."
    ${OC} delete MutatingWebhookConfiguration ibm-common-service-webhook-configuration --ignore-not-found
    ${OC} delete MutatingWebhookConfiguration ibm-operandrequest-webhook-configuration --ignore-not-found

    info "Deleting ValidatingWebhookConfiguration..."
    ${OC} delete ValidatingWebhookConfiguration ibm-cs-ns-mapping-webhook-configuration --ignore-not-found

}

function update_opreqs(){
    title "Updating Operand Requests to use Operand Registry in new CS namespace"
    #check map to namespaces, get list of requested from ns from there
    #update opreq in list of namespaces from common-service-maps configmap

    #this command gets all of the ns listed in requested from namesapce fields
    requested_ns=$("${OC}" get configmap -n kube-public -o yaml common-service-maps | yq '.data[]' | yq '.namespaceMapping[].requested-from-namespace' | awk '{print $2}' | tr '\n' ' ')
    
    for ns in $requested_ns
    do
        opreqs=$(${OC} get operandrequests -n $ns --no-headers | awk '{print $1}' | tr '\n' ' ')
        for opreq in $opreqs
        do
            ${OC} get opreq $opreq -n $ns -o yaml > tmp.yaml
            ${YQ} -i 'del(.metadata.creationTimestamp)' tmp.yaml
            ${YQ} -i 'del(.metadata.resourceVersion)' tmp.yaml
            ${YQ} -i 'del(.metadata.uid)' tmp.yaml
            ${YQ} -i 'del(.metadata.generation)' tmp.yaml
            ${YQ} -i 'del(.metadata.managedFields)' tmp.yaml
            ${YQ} -i '.spec.requests[0].registryNamespace = "ibm-common-services"' tmp.yaml    
            ${OC} apply -n $ns -f tmp.yaml || error "Failed to update registryNamespace value for operand request $opreq in namespace $ns."
            info "Operand request $opreq in namespace $ns updated to use ibm-common-services as registryNamespace."
            rm -f tmp.yaml
        done
    done
    success "Operand requests' registryNamespace values updated."
}

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

function debug1() {
    if [ $DEBUG -eq 1 ]; then
        msg "[DEBUG] ${1}"
    fi
}
# --- Run ---

main $*