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

OC=oc
YQ=yq

cs_operator_channel=
cs_operator_sourceNamespace=
cs_operator_installPlanApproval=
catalog_source=
requested_ns=
map_to_cs_ns=
master_ns=$1
control_ns=
cm_name="common-service-maps"
    
function main() {
    msg "Conversion Script Version v1.0.0"
    prereq
    collect_data
    check_topology
    check_cm_ns_exist
    prepare_cluster
    isolate_odlm "ibm-odlm" $master_ns
    update_opreqs
    scale_up_pod
    restart_CS_pods
    install_new_CS
    refresh_zen
    refresh_kafka
}


# verify that all pre-requisite CLI tools exist
function prereq() {
    which "${OC}" || error "Missing oc CLI"
    which "${YQ}" || error "Missing yq"
    
    # Verify that yq is at least version 4.18.1
    yq_minimum_version=4.18.1
    # Get the user's yq version and remove any leading "v" character if present
    yq_version=$("${YQ}" --version | awk '{print $NF}' | sed 's/^v//')

    # Compare yq versions using sort
    if [[ "$(printf '%s\n' "$yq_minimum_version" "$yq_version" | sort -V | head -n 1)" != "$yq_minimum_version" ]]; then
        error "yq version $yq_version must be at least $yq_minimum_version or higher.\nInstructions for installing/upgrading yq are available here: https://github.com/marketplace/actions/yq-portable-yaml-processor"
    fi

    if [[ -z $master_ns ]]; then
        error "Please specify original cs namespace."
    fi

    return_value=$("${OC}" get -n kube-public configmap ${cm_name} > /dev/null || echo failed)
    if [[ $return_value == "failed" ]]; then
        error "Missing configmap: ${cm_name}. This must be configured before proceeding"
    fi
    return_value="reset"

    # configmap should have control namespace specified
    return_value=$("${OC}" get configmap -n kube-public -o yaml ${cm_name} | yq '.data' | grep controlNamespace: > /dev/null || echo failed)
    if [[ $return_value == "failed" ]]; then
        error "Configmap: ${cm_name} did not specify 'controlNamespace' field. This must be configured before proceeding"
    fi
    return_value="reset"

    control_ns=$("${OC}" get configmap -n kube-public -o yaml ${cm_name} | yq '.data' | grep controlNamespace: | awk '{print $2}')
    return_value=$("${OC}" get ns "${control_ns}" > /dev/null || echo failed)
    if [[ $return_value == "failed" ]]; then
        error "The namespace specified in controlNamespace does not exist. This namespace must be created before proceeding."
    fi
    return_value="reset"

    # LicenseServiceReporter should not be installed because it does not support multi-instance mode
    return_value=$(("${OC}" get crd ibmlicenseservicereporters.operator.ibm.com > /dev/null && echo exists) || echo fail)
    if [[ $return_value == "exists" ]]; then
        return_value=$("${OC}" get ibmlicenseservicereporters -A | wc -l)
        if [[ $return_value -gt 0 ]]; then
            error "LicenseServiceReporter does not support multi-instance mode. Remove before proceeding"
        fi
    fi
    return_value="reset"

    # ensure cs-operator is not installed in all namespace mode
    return_value=$("${OC}" get csv -n openshift-operators | grep ibm-common-service-operator > /dev/null || echo pass)
    if [[ $return_value != "pass" ]]; then
        error "The ibm-common-service-operator must not be installed in AllNamespaces mode"
    fi
}

function prepare_cluster() {

    ${OC} scale deployment -n ${master_ns} ibm-common-service-operator --replicas=0
    ${OC} scale deployment -n ${master_ns} operand-deployment-lifecycle-manager --replicas=0
    ${OC} delete operandregistry -n ${master_ns} --ignore-not-found common-service 
    ${OC} delete operandconfig -n ${master_ns} --ignore-not-found common-service

    #clean up cs operators in cloud pak namespaces, ensure they use same catalog source as original cs instance
    cleanupCSOperators

    # remove existing namespace scope CRs
    removeNSS
    cleanupZenService

    # uninstall singleton services
    "${OC}" delete -n "${master_ns}" --ignore-not-found certmanagers.operator.ibm.com default
    "${OC}" delete -n "${master_ns}" --ignore-not-found sub ibm-cert-manager-operator
    csv=$("${OC}" get -n "${master_ns}" csv | (grep ibm-cert-manager-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${master_ns}" --ignore-not-found csv "${csv}"

    # reason for checking again instead of simply deleting the CR when checking
    # for LSR is to avoid deleting anything until the last possible moment.
    # This makes recovery from simple pre-requisite errors easier.
    return_value=$(("${OC}" get crd ibmlicenseservicereporters.operator.ibm.com > /dev/null && echo exists) || echo fail)
    if [[ $return_value == "exists" ]]; then
        migrate_lic_cms $master_ns $control_ns
        "${OC}" delete -n "${master_ns}" --ignore-not-found ibmlicensing instance
    fi
    return_value="reset"
    #might need a more robust check for if licensing is installed
    #"${OC}" delete -n "${master_ns}" --ignore-not-found sub ibm-licensing-operator
    csv=$("${OC}" get -n "${master_ns}" csv | (grep ibm-licensing-operator || echo "fail") | awk '{print $1}')
    if [[ $csv != "fail" ]]; then
        "${OC}" delete -n "${master_ns}" --ignore-not-found sub ibm-licensing-operator
        "${OC}" delete -n "${master_ns}" --ignore-not-found csv "${csv}"
    fi

    "${OC}" delete -n "${master_ns}" --ignore-not-found sub ibm-crossplane-operator-app
    "${OC}" delete -n "${master_ns}" --ignore-not-found sub ibm-crossplane-provider-kubernetes-operator-app
    csv=$("${OC}" get -n "${master_ns}" csv | (grep ibm-crossplane-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${master_ns}" --ignore-not-found csv "${csv}"
    csv=$("${OC}" get -n "${master_ns}" csv | (grep ibm-crossplane-provider-kubernetes-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${master_ns}" --ignore-not-found csv "${csv}"

    cleanup_webhook
    cleanup_deployment "secretshare" "$master_ns"
}

function migrate_lic_cms() {
    title "Copying over Licensing Configmaps"
    msg "-----------------------------------------------------------------------"
    local namespace=$1
    local controlNs=$2
    POSSIBLE_CONFIGMAPS=("ibm-licensing-config"
"ibm-licensing-annotations"
"ibm-licensing-products"
"ibm-licensing-products-vpc-hour"
"ibm-licensing-cloudpaks"
"ibm-licensing-products-groups"
"ibm-licensing-cloudpaks-groups"
"ibm-licensing-cloudpaks-metrics"
"ibm-licensing-products-metrics"
"ibm-licensing-products-metrics-groups"
"ibm-licensing-cloudpaks-metrics-groups"
"ibm-licensing-services"
)

    for cm in ${POSSIBLE_CONFIGMAPS[@]}
    do
        return_value=$(${OC} get cm -n $namespace --ignore-not-found | (grep $cm || echo "fail") | awk '{print $1}')
        if [[ $return_value != "fail" ]]; then
            if [[ $return_value == $cm ]]; then
                ${OC} get cm -n $namespace $cm -o yaml --ignore-not-found > tmp.yaml
                #edit the file to change the namespace to controlNs
                yq -i '.metadata.namespace = "'${controlNs}'"' tmp.yaml

                # apply updated ConfigMap back to cluster
                ${OC} apply -f tmp.yaml
                if [[ $? -eq 0 ]]; then
                    info "Licensing Services ConfigMap $cm copied from $namespace to $controlNs"
                    # delete the original in cs namespace
                    ${OC} delete cm -n $namespace $cm --ignore-not-found
                else
                    error "Failed to move Licensing Services ConfigMap $cm to $controlNs"
                fi
            fi
        fi
    done
    
    rm tmp.yaml -f
    success "Licensing configmaps copied from $namespace to $control_ns"
}

# scale back cs pod 
function scale_up_pod() {
    info "scaling up ibm-common-service-operator deployment in ${master_ns} namespace"
    ${OC} scale deployment -n ${master_ns} ibm-common-service-operator --replicas=1
    ${OC} scale deployment -n ${master_ns} operand-deployment-lifecycle-manager --replicas=1
    check_healthy "${master_ns}"
}

function collect_data() {
    title "Collecting data"
    msg "-----------------------------------------------------------------------"
    
    info "MasterNS:${master_ns}"
    cs_operator_channel=$(${OC} get subscription.operators.coreos.com ibm-common-service-operator -n ${master_ns} -o yaml | yq ".spec.channel") 
    info "channel:${cs_operator_channel}"
    cs_operator_sourceNamespace=$(${OC} get subscription.operators.coreos.com ibm-common-service-operator -n ${master_ns} -o yaml | yq ".spec.sourceNamespace") 
    info "sourceNamespace:${cs_operator_sourceNamespace}"
    cs_operator_installPlanApproval=$(${OC} get subscription.operators.coreos.com ibm-common-service-operator -n ${master_ns} -o yaml | yq ".spec.installPlanApproval") 
    info "installPlanApproval:${cs_operator_installPlanApproval}"
    catalog_source=$(${OC} get subscription.operators.coreos.com ibm-common-service-operator -n ${master_ns} -o yaml | yq ".spec.source")
    info "catalog_source:${catalog_source}"

    #this command gets all of the ns listed in requested from namesapce fields
    requested_ns=$("${OC}" get configmap -n kube-public -o yaml ${cm_name} | yq '.data[]' | yq '.namespaceMapping[].requested-from-namespace' | awk '{print $2}' | tr '\n' ' ')
    #this command gets all of the ns listed in map-to-common-service-namespace
    map_to_cs_ns=$("${OC}" get configmap -n kube-public -o yaml ${cm_name} | yq '.data[]' | yq '.namespaceMapping[].map-to-common-service-namespace' | awk '{print}' | tr '\n' ' ')
    
}

# delete all CS pod and read configmap
function restart_CS_pods() {
    title "restarting ibm-common-service-operator pod"
    msg "-----------------------------------------------------------------------"
    
    local namespaces="$requested_ns $map_to_cs_ns $master_ns"
    for namespace in $namespaces
    do
        cs_pod=$(${OC} get pod -n $namespace | (grep ibm-common-service-operator || echo fail) | awk '{print $1}')
        if [[ $cs_pod != "fail" ]]; then
            msg "deleting pod ${cs_pod} in namespace ${namespace}"
            ${OC} delete pod ${cs_pod} -n ${namespace} || error "Error deleting pod ${cs_pod} in namespace ${namespace}"
        fi
    done
    success "All ibm-common-service-operator pods are deleted"
}

#  install new instances of CS based on cs mapping configmap
function install_new_CS() {
    title "install new instances of CS based on cs mapping configmap"
    msg "-----------------------------------------------------------------------"

    for namespace in $map_to_cs_ns
    do
        info "In_CommonServiceNS:${namespace}"
        create_operator_group "${namespace}"
        install_common_service_operator_sub "${namespace}"
        check_CSCR "${namespace}"
        copy_over_commonservice_cr "${namespace}"
        copy_over_cpp_config_cm "${namespace}"
    done
    
    success "Common Services Operator is converted to multi_instance mode"
}

# wait for new cs to be ready
function check_IAM(){
    sleep 10
    local namespaces=""
    for cs_namespace in $map_to_cs_ns
    do
        local nsFromNSS=$(${OC} get nss -n $cs_namespace -o yaml common-service | yq '.status.validatedMembers[]' | tr '\n' ' ')
        for cp_namespace in $nsFromNSS
        do
            zenservice_exists=$(${OC} get zenservice -n $cp_namespace || echo fail)
            if [[ $zenservice_exists != "fail" ]] && [[ $zenservice_exists != "" ]]; then
                zenservice=$(${OC} get zenservice -n $cp_namespace --no-headers | awk '{print $1}')
                iam_enabled=$(${OC} get zenservice $zenservice -n $cp_namespace -o yaml | ${YQ} '.spec.iamIntegration')
                if [[ $iam_enabled == "true" ]]; then
                    if [[ $namespaces == "" ]]; then
                        namespaces="$cs_namespace"
                        break
                    else
                        namespaces="$namespaces $cs_namespace"
                        break
                    fi
                else
                    info "IAM not requested by zenservice in namespace $cp_namespace, skipping wait."
                fi
            fi
        done
    done 
    for namespace in $namespaces
    do
        retries=40
        sleep_time=30
        total_time_mins=$(( sleep_time * retries / 60))
        info "Waiting for IAM to come ready in namespace ${namespace}"
        sleep 10
        local cm="ibm-common-services-status"
        local statusName="${namespace}-iamstatus"
        
        while true; do
            if [[ ${retries} -eq 0 ]]; then
                error "Timeout after ${total_time_mins} minutes waiting for IAM to come ready in namespace ${namespace}"
            fi

            iamReady=$("${OC}" get configmap -n kube-public -o yaml ${cm} | (grep $statusName || echo fail))

            if [[ "${iamReady}" == "fail" ]]; then
                retries=$(( retries - 1 ))
                info "RETRYING: Waiting for IAM service to be Ready (${retries} left)"
                sleep ${sleep_time}
            else
                msg "-----------------------------------------------------------------------"    
                success "IAM Service Ready in ${namespace}"
                break
            fi
        done
    done
}

# update zenservice CRs to be reconciled again
function refresh_zen(){
    title " Refreshing Zen Services "
    msg "-----------------------------------------------------------------------"
    #make sure IAM is ready before reconciling.
    check_IAM #this will likely need to change in the future depending on how we check iam status
    local namespaces="$requested_ns $map_to_cs_ns"
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
        local namespaces="$requested_ns $map_to_cs_ns"
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

function cleanupCSOperators(){
    title "Checking subs of Common Service Operator in Cloudpak Namespaces"
    msg "-----------------------------------------------------------------------"
    for namespace in $requested_ns
    do
        return_value=$(${OC} get subscription.operators.coreos.com -n ${namespace} | (grep ibm-common-service-operator || echo "fail"))
        if [[ $return_value != "fail" ]]; then
            local sub=$(${OC} get subscription.operators.coreos.com -n ${namespace} | grep ibm-common-service-operator | awk '{print $1}')
            ${OC} get subscription.operators.coreos.com ${sub} -n ${namespace} -o yaml > tmp.yaml 
            ${YQ} -i '.spec.source = "'${catalog_source}'"' tmp.yaml || error "Could not replace catalog source for CS operator subscription in namespace ${namespace}"
            ${YQ} -i '.spec.channel = "'${cs_operator_channel}'"' tmp.yaml || error "Could not replace channel for CS operator subscription in namespace ${namespace}"
            ${YQ} -i '.spec.sourceNamespace = "'${cs_operator_sourceNamespace}'"' tmp.yaml || error "Could not replace sourceNamespace for CS operator subscription in namespace ${namespace}"
            ${YQ} -i '.spec.installPlanApproval = "'${cs_operator_installPlanApproval}'"' tmp.yaml || error "Could not replace installPlanApproval for CS operator subscription in namespace ${namespace}"
            ${YQ} -i 'del(.metadata.creationTimestamp) | del(.metadata.managedFields) | del(.metadata.resourceVersion) | del(.metadata.uid) | del(.status)' tmp.yaml || error "Failed to remove metadata fields from temp cs operator yaml for namespace ${namespace}."
            ${OC} apply -f tmp.yaml || error "Failed to apply catalogsource and channel changes to cs operator subscription in namespace ${namespace}."
            info "Common Service Operator Subscription in namespace ${namespace} updated to use catalog source ${catalog_source}, channel ${cs_operator_channel}, sourceNamespace ${cs_operator_sourceNamespace}, and installPlanApproval ${cs_operator_installPlanApproval}."
        else
            info "No Common Service Operator in namespace ${namespace}. Moving on..."
        fi
        return_value=""
    done
    rm tmp.yaml -f
}

function create_operator_group() {
    local cs_namespace=$1

    title "Checking if OperatorGroup exists in ${cs_namespace}"
    msg "-----------------------------------------------------------------------"

    exists=$("${OC}" get operatorgroups -n "${cs_namespace}" | wc -l)
    if [[ "$exists" -ne 0 ]]; then
        info "Already an OperatorGroup in ${cs_namespace}, skip creating OperatorGroup"
    else
        title "Creating operator group ..."
        msg "-----------------------------------------------------------------------"


        cat <<EOF | tee >("${OC}" apply -f -) | cat
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: common-service
  namespace: ${cs_namespace}
spec:
  targetNamespaces:
  - ${cs_namespace}
EOF

    fi
}

function install_common_service_operator_sub() {
    local CS_NAMESPACE=$1

    title " Installing IBM Common Service Operator subcription "
    msg "-----------------------------------------------------------------------"

    cat <<EOF | tee >(oc apply -f -) | cat
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator
  namespace: ${CS_NAMESPACE}
spec:
  channel: ${cs_operator_channel}
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: ${catalog_source}
  sourceNamespace: openshift-marketplace
EOF

    # error handle

    info "Waiting for IBM Common Service Operator subscription to become active"
    check_healthy "${CS_NAMESPACE}"

    success "IBM Common Service Operator subscription in namespace ${CS_NAMESPACE} is created"
}

# verify all instances are healthy
function check_healthy() {
    local CS_NAMESPACE=$1

    sleep 10

    retries=20
    sleep_time=15
    total_time_mins=$(( sleep_time * retries / 60))
    info "Waiting for IBM Common Services CR is Succeeded"
    sleep 10

    while true; do
        pod=$(oc get pods -n ${CS_NAMESPACE} | (grep ibm-common-service-operator || echo fail) | awk '{print $1}')
        if [[ ${retries} -eq 0 ]]; then
            error "Timeout after ${total_time_mins} minutes waiting for IBM Common Services is deployed"
        fi

        if [[ $pod != "fail" ]]; then
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
        else
            retries=$(( retries - 1 ))
            info "RETRYING: Waiting for IBM Common Services CR is Succeeded (${retries} left)"
            sleep ${sleep_time}
        fi
    done
}

function cleanupZenService(){
    title " Cleaning up Zen installation "
    msg "-----------------------------------------------------------------------"
    local namespaces="$requested_ns $map_to_cs_ns"
    for namespace in $requested_ns
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

function check_CSCR() {
    local CS_NAMESPACE=$1

    retries=30
    sleep_time=15
    total_time_mins=$(( sleep_time * retries / 60))
    info "Waiting for IBM Common Services CR is Succeeded"
    sleep 10

    while true; do
        if [[ ${retries} -eq 0 ]]; then
            error "Timeout after ${total_time_mins} minutes waiting for IBM Common Services CR is Succeeded"
        fi

        phase=$(oc get commonservice common-service -o jsonpath='{.status.phase}' -n ${CS_NAMESPACE})

        if [[ "${phase}" != "Succeeded" ]]; then
            retries=$(( retries - 1 ))
            info "RETRYING: Waiting for IBM Common Services CR is Succeeded (${retries} left)"
            sleep ${sleep_time}
        else
            msg "-----------------------------------------------------------------------"    
            success "IBM Common Services CR is Succeeded, Ready to proceed"
            break
        fi
    done

}

# check that all namespaces in common-service-maps cm exist. 
# Create them if not already present 
# Does not create cs-control namespace
function check_cm_ns_exist(){
    
    title " Verify all namespaces exist "
    msg "-----------------------------------------------------------------------"

    for ns in $requested_ns
    do
        info "Creating namespace $ns"
        ${OC} create namespace $ns || info "$ns already exists, skipping..."
    done
    for ns in $map_to_cs_ns
    do
        info "Creating namespace $ns"
        ${OC} create namespace $ns || info "$ns already exists, skipping..."
    done
    success "All namespaces in $cm_name exist"
}

function removeNSS(){
    
    title " Removing ODLM managed Namespace Scope CRs "
    msg "-----------------------------------------------------------------------"
    namespaces="$map_to_cs_ns $master_ns"
    for ns in $namespaces
    do
        info "deleting namespace scope nss-managedby-odlm in namespace ${ns}"
        ${OC} delete nss nss-managedby-odlm -n ${ns} --ignore-not-found || (error "unable to delete namespace scope nss-managedby-odlm in ${ns}")
        info "deleting namespace scope odlm-scope-managedby-odlm in namespace ${ns}"
        ${OC} delete nss odlm-scope-managedby-odlm -n ${ns} --ignore-not-found || (error "unable to delete namespace scope odlm-scope-managedby-odlm in ${ns}")
        
        info "deleting namespace scope nss-odlm-scope in namespace ${ns}"
        ${OC} delete nss nss-odlm-scope -n ${ns} --ignore-not-found || (error "unable to delete namespace scope nss-odlm-scope in ${ns}")
        
        info "deleting namespace scope common-service in namespace ${ns}"
        ${OC} delete nss common-service -n ${ns} --ignore-not-found || (error "unable to delete namespace scope common-service in ${ns}")

    done

    success "Namespace Scope CRs cleaned up"
}

function check_topology() {
    title " Checking expected vs actual topology based on common-service-maps "
    msg "-----------------------------------------------------------------------"
    cm_maps=$(oc get -n kube-public cm common-service-maps -o yaml | yq '.data.["common-service-maps.yaml"]')
    activeMapTo=
    activeRequestedFrom=
    for csNamespace in $map_to_cs_ns
    do
        allPresent="false"
        nsFromCM=$(echo "$cm_maps" | yq eval '.namespaceMapping[] | select(.map-to-common-service-namespace == "'${csNamespace}'").requested-from-namespace' | awk '{ print $2 }' | tr '\n' ' ')
        nssExist=$(${OC} get nss -n $csNamespace common-service || echo fail)
        if [[ $nssExist == "fail" ]]; then
            allPresent="false"
            nsFromNSS=""
        else
            nsFromNSS=$(${OC} get nss -n $csNamespace -o yaml common-service | yq '.status.validatedMembers[]' | tr '\n' ' ')
            allPresent="true"
        fi
        leftover=""
        leftover=$(echo $nsFromCM $nsFromNSS | tr ' ' '\n' | sort | uniq -u | tr '\n' ' ')
        #if there are no differences between the two lists, the variable is unset.
        #check for unset, if it is, then the grouping doesn't need to be changed anyway
        if [[ -z ${leftover:-} ]]; then
            leftover=""
        fi
        leftover=${leftover%%[[:space:]]}
        if [[ "$leftover" == "$csNamespace" ]] || [[ $leftover == "" ]]; then
            allPresent="true"
        else
            if [[ $activeRequestedFrom == "" ]]; then
                activeRequestedFrom="$nsFromCM"
            else
                activeRequestedFrom="$activeRequestedFrom $nsFromCM"
            fi
            if [[ $activeMapTo == "" ]]; then
                activeMapTo="$csNamespace"
            else
                activeMapTo="$activeMapTo $csNamespace"
            fi
            info "Namespaces $nsFromCM $csNamespace added to conversion pool."
            nsFromCM=""
            allPresent="false"
        fi
        if [[ $allPresent == "true" ]]; then
            info "Namespaces $nsFromCM are already setup to use Common Service instance in namespace $csNamespace"
            nsFromCM=""
        fi
    done

    if [[ $activeRequestedFrom == "" ]] && [[ $activeMapTo == "" ]]; then
        success "No difference in topology detected."
        error "Please update common-service-maps configmap in kube-public and run again."
    else
        requested_ns=$activeRequestedFrom
        map_to_cs_ns=$activeMapTo
        info "Namespaces to be included in conversion process: $requested_ns $map_to_cs_ns"
    fi
    
    success "Topology info collected from common-service-maps configmap"
}

function isolate_odlm() {
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
            env_value="true"
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
    local condition="${OC} -n ${namespace} get deployment ${name} -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name==\"ISOLATED_MODE\")].value}'| grep "true" || true"
    local retries=10
    local sleep_time=12
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for OLM to update Deployment ${name} "
    local success_message="Deployment ${name} is updated to run in isolated mode"
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

function copy_over_commonservice_cr() {
    namespace=$1
    title " Copying existing CommonService CR to new cs instance $namespace "
    msg "-----------------------------------------------------------------------"
    
    ${OC} get commonservice common-service -n ${master_ns} -o yaml > tmp.yaml

    yq -i 'del(.metadata.creationTimestamp)' tmp.yaml
    yq -i 'del(.metadata.resourceVersion)' tmp.yaml
    yq -i 'del(.metadata.uid)' tmp.yaml
    yq -i 'del(.metadata.generation)' tmp.yaml
    yq -i '.metadata.namespace = "'${namespace}'"' tmp.yaml
    ${OC} apply -f tmp.yaml  || error "Could not apply CommonService CR changes in namespace $namespace"

    rm -f tmp.yaml
}

function copy_over_cpp_config_cm() {
    local namespace=$1
    title " Copying existing ibm-cpp-config configmap to new cs instance $namespace "
    msg "-----------------------------------------------------------------------"

    $OC get cm ibm-cpp-config -n $master_ns -o yaml | \
        $YQ '
            del(.metadata.creationTimestamp) | 
            del(.metadata.resourceVersion) | 
            del(.metadata.namespace) | 
            del(.metadata.uid) | 
            del(.metadata.ownerReferences) |
            del(.metadata.managedFields) |
            del(.metadata.labels)
        ' | \
        $OC apply -n $namespace -f - || error "Failed to copy over configmap ibm-cpp-config."
    success "Configmap ibm-cpp-config copied over to $namespace"
}

function cleanup_deployment() {
    local name=$1
    local namespace=$2
    info "Deleting existing Deployment ${name} in namespace ${namespace}..."
    ${OC} delete deployment ${name} -n ${namespace} --ignore-not-found
}

function cleanup_webhook() {
    podpreset_exist="true"
    podpreset_exist=$(${OC} get podpresets.operator.ibm.com -n $master_ns --no-headers || echo "false")
    if [[ $podpreset_exist != "false" ]] && [[ $podpreset_exist != "" ]]; then
        info "Deleting podpresets in namespace $master_ns..."
	${OC} get podpresets.operator.ibm.com -n $master_ns --no-headers --ignore-not-found | awk '{print $1}' | xargs ${OC} delete -n $master_ns --ignore-not-found podpresets.operator.ibm.com
        msg ""
    fi

    cleanup_deployment "ibm-common-service-webhook" $master_ns

    info "Deleting MutatingWebhookConfiguration..."
    ${OC} delete MutatingWebhookConfiguration ibm-common-service-webhook-configuration --ignore-not-found
    ${OC} delete MutatingWebhookConfiguration ibm-operandrequest-webhook-configuration --ignore-not-found
    msg ""

    info "Deleting ValidatingWebhookConfiguration..."
    ${OC} delete ValidatingWebhookConfiguration ibm-cs-ns-mapping-webhook-configuration --ignore-not-found

    local webhook_pod_in_control_ns=$(${OC} get pods -n $control_ns | grep common-service-webhook || echo "fail")
    if [[ $webhook_pod_in_control_ns != "fail" ]]; then
        info "Webhook pod in control namespace, restarting."
        local pod_name=$(${OC} get pods -n $control_ns | grep common-service-webhook | awk '{print $1}')
        ${OC} delete pod $pod_name -n $control_ns
    else
        info "Webhook pod not in control namespace, skipping restart."
    fi
}

function update_opreqs(){
    title "Updating Operand Requests to use Operand Registry in new CS namespace"
    #check map to namespaces, get list of requested from ns from there
    #update opreq in map to first
    #update opreq in list of namespace from first line
    for csns in $map_to_cs_ns
    do
        local namespaces=$(${OC} get cm common-service-maps -o yaml -n kube-public | $YQ '.data[]' | $YQ '.namespaceMapping[] | select(.map-to-common-service-namespace == "'$csns'").requested-from-namespace' | awk '{print $2}' | tr '\n' ' ')
        namespaces="$namespaces $csns"
        for ns in $namespaces
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

# --- Run ---

main $*
