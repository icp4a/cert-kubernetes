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

# ---------- Command arguments ----------

OC=oc
YQ=yq
MASTER_NS=
EXCLUDED_NS=""
ADDITIONAL_NS=""
CONTROL_NS=""
CS_MAPPING_YAML=""
CM_NAME="common-service-maps"
CERT_MANAGER_MIGRATED="false"
DEBUG=0
BACKUP_LICENSING="false"
PREVIEW_MODE=0
IS_ISOLATED=0

# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

#log file
LOG_FILE="isolate_log_$(date +'%Y%m%d%H%M%S').log"

# preview mode directory
PREVIEW_DIR="/tmp/isolate-$(date +'%Y%m%d%H%M%S')-preview"

# ---------- Main functions ----------

. ${BASE_DIR}/cp3pt0-deployment/common/utils.sh

trap 'error "Error occurred in function $FUNCNAME at line $LINENO"' ERR

function main() {
    echo "All arguments passed into the script: $@"

    while [ "$#" -gt "0" ]
    do
        case "$1" in
        "--oc")
            shift
            OC=$1
            ;;
        "--yq")
            shift
            YQ=$1
            ;;
        "-h"|"--help")
            usage
            exit 0
            ;;
        "--original-cs-ns")
            MASTER_NS=$2
            shift
            ;;
        "--excluded-ns")
            EXCLUDED_NS=$2
            shift
            ;;
        "--insert-ns")
            ADDITIONAL_NS=$2
            shift
            ;;
        "--control-ns")
            CONTROL_NS=$2
            shift
            ;;
        "-v"|"--debug")
            shift
            DEBUG=$1
            ;;
        *)
            error "invalid option -- \`$1\`. Use the -h or --help option for usage info."
            ;;
        esac
        shift
    done

    save_log "cp3pt0-deployment/logs" "isolate_log" "$DEBUG"
    trap cleanup_log EXIT
    prepare_preview_mode

    which "${OC}" || error "Missing oc CLI"
    which "${YQ}" || error "Missing yq"

    if [[ -z $CONTROL_NS ]] &&  [[ -z $MASTER_NS ]]; then
        usage
        error "No parameters entered. Please re-run specifying original and control namespace values. Use -h for help."
    elif [[ -z $CONTROL_NS ]] || [[ -z $MASTER_NS ]]; then
        usage
        error "Required parameters missing. Please re-run specifying original and control namespace values. Use -h for help."
    fi
    #make sure cs op and odlm are scaled back to 1 before starting
    prev_fail_check
    #need to get the namespaces for csmaps generation before pausing cs, otherwise namespace-scope cm does not include all namespaces
    prereq
    local ns_list=$(gather_csmaps_ns)
    pause
    cleanup_webhook
    cleanup_secretshare
    create_empty_csmaps
    insert_control_ns
    update_tenant "${MASTER_NS}" "${ns_list}"
    check_cm_ns_exist "$ns_list $CONTROL_NS" # debating on turning this off by default since this technically falls outside the scope of isolate
    removeNSS
    isolate_license_service_reporter
    uninstall_singletons
    isolate_odlm "ibm-odlm" $MASTER_NS
    if [[ $BACKUP_LICENSING == "true" ]]; then
        restore_ibmlicensing
    else
        info "Licensing not marked for backup, skipping."
    fi
    restart
    wait_for_certmanager "${ns_list}"
    wait_for_nss_update "${ns_list}"
    success "Isolation complete"
}

function usage() {
	local script="${0##*/}"

	while read -r ; do echo "${REPLY}" ; done <<-EOF
Usage: ${script} [OPTION]...
Isolate and prepare Cloud Pak 2.0 Foundational Services for upgrade to or additional installation of Cloud Pak 3.0 Foundational Services

Examples:
# isolate the existing instance scope in ibm-common-services namespace and re-deploy cluster singleton services in cs-control namespace
isolate.sh --original-cs-ns ibm-common-services --control-ns cs-control

# remove cloudpak-1 and cloudpak-2 namespace from the existing instance scope in ibm-common-services
isolate.sh --original-cs-ns ibm-common-services --control-ns cs-control --excluded-ns cloudpak-1,cloudpak-2

# add cloudpak-1 and cloudpak-2 namespace into the existing instance scope in ibm-common-services
isolate.sh --original-cs-ns ibm-common-services --control-ns cs-control --insert-ns cloudpak-1,cloudpak-2

"Existing instance scope" refers to the existing common services installation and its attached cloud paks and other workloads.
See https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.0?topic=4x-isolated-migration for more information.

Options:
    -h, --help                    Display this help and exit
    --oc string                   Optional. File path to oc CLI. Default uses oc in your PATH"
    --yq string                   Optional. File path to yq CLI. Default uses yq in your PATH"
    --original-cs-ns              Required. Specify the namespace the original common services installation resides in
    --control-ns                  Required. Specify the control namespace value in the common-service-maps configmap
    --excluded-ns                 Optional. Specify namespaces to be excluded from the instance scope in original-cs-ns. Comma separated no spaces.
    --insert-ns                   Optional. Specify namespaces to be inserted into the instance scope in original-cs-ns. Comma separated no spaces.
    -v, --debug integer           Optional. Verbosity of logs. Default is 0. Set to 1 for debug logs.
	EOF
}

function prereq() {
    # Check the value of DEBUG
    if [[ "$DEBUG" != "1" && "$DEBUG" != "0" ]]; then
        error "Invalid value for DEBUG. Expected 0 or 1."
    fi

    #verify one and only one cert manager is installed
    check_certmanager_count
    check_command "${OC}"
    check_command "${YQ}"
    # Check yq version
    check_yq_version

    # Checking oc command logged in
    user=$(${OC} whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        error "You must be logged into the OpenShift Cluster from the oc command line"
    else
        success "oc command logged in as ${user}"
    fi

    return_value="reset"
    # ensure cs-operator is not installed in all namespace mode
    return_value=$("${OC}" get csv -n openshift-operators | grep ibm-common-service-operator > /dev/null || echo pass)
    if [[ $return_value != "pass" ]]; then
        error "The ibm-common-service-operator must not be installed in AllNamespaces mode"
    fi

    local isExists=$("${OC}" get deploy --ignore-not-found -n ${MASTER_NS} operand-deployment-lifecycle-manager)
    if [ -z "$isExists" ]; then
        error "Missing operand-deployment-lifecycle-manager deployment (ODLM) in namespace $MASTER_NS"
    fi

    cs_operator_found=false

    while read -r ns; do
        cs_version=$("${OC}" get csv -n "${ns}" | grep common-service-operator | awk '{print $7}' || echo "")
        if [[ $cs_version == "" ]]; then
            error "Failed to get ibm-common-service-operator csv in namespace ${ns}."
        elif [[ -n "${cs_version}" ]]; then
            IFS='.' read -r major minor patch <<< "${cs_version}"
            if [[ ${major} -lt 3 || (${major} -eq 3 && ${minor} -lt 19) || (${major} -eq 3 && ${minor} -eq 19 && ${patch} -lt 9) ]]; then
                error "Version of Foundational Services is $cs_version in namespace ${ns} does not meet the minimum version requirement. Upgrade to 3.19.9+"
            fi
            if [[ "${ns}" == "${MASTER_NS}" ]]; then
                if [[ ${major} -gt 3 ]]; then
                    error "Version of Foundational Services is $cs_version in namespace ${ns} does not meet the version requirement. Should be either 3.20+ or 3.19.9+"
                fi
            fi
            cs_operator_found=true
        fi
    done < <("${OC}" get subscription.operators.coreos.com --all-namespaces --ignore-not-found | grep ibm-common-service-operator | awk '{print $1}' )

    if [[ "${cs_operator_found}" == false ]]; then
        error "No ibm-common-service-operator subscription found in any namespace."
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
  name: "$CM_NAME"
  namespace: kube-public
data:
  common-service-maps.yaml: |
${yaml}
EOF
)"
    echo "$object" | ${OC} apply -f -
}

# create_empty_csmaps Creates a new common-service-maps configmap and inserts
# an empty common-service-maps.yaml field.
#
# If the common-service-maps already exists, then will error
function create_empty_csmaps() {
    title " Creating empty common-service-maps configmap "
    local isExists=$("${OC}" get configmap --ignore-not-found -n kube-public "$CM_NAME")
    if [ ! -z "$isExists" ]; then
        info "The $CM_NAME already exists, skipping"
        return
    fi
    update_cs_maps ""
    success "Empty common-service-maps configmap created in kube-public namespace"
}

# insert_control_ns Insert the controlNamespace field into the configmap if it
# does not exist
function insert_control_ns() {
    local current_yaml=$("${OC}" get -n kube-public cm "$CM_NAME" -o yaml | "${YQ}" '.data.["common-service-maps.yaml"]')

    current=$(echo "$current_yaml" | "${YQ}" '.controlNamespace')
    if [[ "$current" != "$CONTROL_NS" && "$current" != "" && "$current" != "null" ]]; then
        error "The controlNamespace field in common-service-maps is already set to: $current, and cannot be changed"
    fi

    local updated_yaml=$(echo "$current_yaml" | "${YQ}" '.controlNamespace = "'$CONTROL_NS'"')
    local padded_yaml=$(echo "$updated_yaml" | awk '$0="    "$0')
    update_cs_maps "$padded_yaml"
}

# read_tenant_from_csmaps Gets the list in requested-from-namespace for a given
# map_to_cs_ns and prints it out. If map_to_cs_ns does not exist, then output is
# empty
function read_tenant_from_csmaps() {
    local map_to_cs_ns=$1
    local current_yaml=$("${OC}" get -n kube-public cm "$CM_NAME" -o yaml | "${YQ}" '.data.["common-service-maps.yaml"]')
    local tenant_ns_list=$(echo "$current_yaml" | "${YQ}" eval '.namespaceMapping[] | select(.map-to-common-service-namespace == "'${map_to_cs_ns}'").requested-from-namespace' | awk '{ print $2 }')
    echo "$tenant_ns_list"
}

# update_tenant Updates an entire tenant in common-service-maps. The tenant is
# identified by map_to_cs_ns, and will be updated with the given list of
# namespaces which must be space delimited.
#
# If tenant does not exist, then it will be added.
# The map_to_cs_ns will always be added to the requested-from-namespace list.
# Before the common-service-maps is updated, the requested-from-namespace list
# will be made unique, so that there are no duplicates
function update_tenant() {
    local map_to_cs_ns=$1
    shift
    local namespaces=$@

    local current_yaml=$("${OC}" get -n kube-public cm "$CM_NAME" -o yaml | "${YQ}" '.data.["common-service-maps.yaml"]')
    local updated_yaml="$current_yaml"

    local isExists=$(echo "$current_yaml" | "${YQ}" '.namespaceMapping[] | select(.map-to-common-service-namespace == "'$map_to_cs_ns'")')
    if [ -z "$isExists" ]; then
        info "The provided map-to-common-service-namespace: $map_to_cs_ns, does not exist in common-service-maps"
        info "Adding new map-to-common-service-namespace"
        updated_yaml=$(echo "$current_yaml" | "${YQ}" eval 'with(.namespaceMapping; . += [{"map-to-common-service-namespace": "'$map_to_cs_ns'"}])')
    fi

    local tmp="\"$map_to_cs_ns\""
    debug1 "map $map_to_cs_ns namespace $namespaces tmp $tmp"
    for ns in $namespaces; do
        debug1 "ns $ns mapto: $map_to_cs_ns"
        if [[ "$ns" != "$map_to_cs_ns" ]]; then
            tmp="$tmp,\"$ns\""
        fi
    done
    local ns_delimited="${tmp}"
    debug1 "ns_delimited: $ns_delimited"

    updated_yaml=$(echo "$updated_yaml" | "${YQ}" eval 'with(.namespaceMapping[]; select(.map-to-common-service-namespace == "'$map_to_cs_ns'").requested-from-namespace = ['$ns_delimited'])')
    updated_yaml=$(echo "$updated_yaml" | "${YQ}" eval 'with(.namespaceMapping[]; select(.map-to-common-service-namespace == "'$map_to_cs_ns'").requested-from-namespace |= unique)')
    local padded_yaml=$(echo "$updated_yaml" | awk '$0="    "$0')
    update_cs_maps "$padded_yaml"
}

# gather_csmaps_ns Reads in all the namespaces from namespace-scope configmap
# and namesapces from arguments, to output a unique sorted list of namespaces
# with excluded namespaces removed
function gather_csmaps_ns() {
    local ns_scope=$("${OC}" get cm -n "$MASTER_NS" namespace-scope -o yaml | "${YQ}" '.data.namespaces')

    # excluding namespaces is implemented via duplicate removal with uniq -u,
    # so need to make unique the combined lists of namespaces first to avoid
    # accidental removals of namespace which should be included
    local tenant_scope="${ns_scope},${MASTER_NS},${ADDITIONAL_NS}"
    tenant_scope=$(echo "${tenant_scope//,/$'\n'}" | sort -u)

    # adding excluded namespaces to the list allows uniq -u to remove duplicates
    tenant_scope="${tenant_scope},${EXCLUDED_NS},${EXCLUDED_NS}"
    tenant_scope=$(echo "${tenant_scope//,/$'\n'}" | sort | uniq -u)
    echo "$tenant_scope"
}

function pause() {
    title "Pausing Common Services in namespace $MASTER_NS"
    msg "-----------------------------------------------------------------------"
    ${OC} scale deployment -n ${MASTER_NS} ibm-common-service-operator --replicas=0
    ${OC} scale deployment -n ${MASTER_NS} operand-deployment-lifecycle-manager --replicas=0
    ${OC} delete operandregistry -n ${MASTER_NS} --ignore-not-found common-service 
    ${OC} delete operandconfig -n ${MASTER_NS} --ignore-not-found common-service
    
    success "Common Services successfully isolated in namespace ${MASTER_NS}"
}

# uninstall_singletons Deletes resources related to singletons so that when
# cs-operator and ODLM are restarted, these resources will be re-created in the
# controlNamespace.
#
# Everything here can be deleted without backing up because they will eventually
# be re-created, except for the licensing configmaps. These configmaps will only
# be deleted after successful migration. The configmaps should be deleted
# to avoid overwriting any licensing data if isolate script is run multiple
# times.
function uninstall_singletons() {
    title "Uninstalling Singleton Operators"
    msg "-----------------------------------------------------------------------"

    local isExists=$("${OC}" get deployments -n "${MASTER_NS}" --ignore-not-found ibm-cert-manager-operator)
    if [ ! -z "$isExists" ]; then
        "${OC}" delete --ignore-not-found certmanagers.operator.ibm.com default
        CERT_MANAGER_MIGRATED="true"
        debug1 "Cert Manager marked for migration."
    fi
    "${OC}" delete -n "${MASTER_NS}" --ignore-not-found sub ibm-cert-manager-operator
    local csv=$("${OC}" get -n "${MASTER_NS}" csv | (grep ibm-cert-manager-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${MASTER_NS}" --ignore-not-found csv "${csv}"

    migrate_lic_cms $MASTER_NS

    licensing_exists=""
    licensing_exists=$(${OC} get IBMLicensing || echo "not found")
    if [[ $licensing_exists == "" || $licensing_exists == "not found" ]]; then
        info "No ibmlicensing resources on cluster, skipping backup."
    else
        info "Licensing marked for backup"
        backup_ibmlicensing
        BACKUP_LICENSING="true"
    fi
    isExists=$("${OC}" get deployments -n "${MASTER_NS}" --ignore-not-found ibm-licensing-operator)
    if [ ! -z "$isExists" ]; then
        "${OC}" delete -n "${MASTER_NS}" --ignore-not-found ibmlicensing instance
    fi

    #might need a more robust check for if licensing is installed
    #"${OC}" delete -n "${MASTER_NS}" --ignore-not-found sub ibm-licensing-operator
    csv=$("${OC}" get -n "${MASTER_NS}" csv | (grep ibm-licensing-operator || echo "fail") | awk '{print $1}')
    if [[ $csv != "fail" ]]; then
        "${OC}" delete -n "${MASTER_NS}" --ignore-not-found sub ibm-licensing-operator
        "${OC}" delete -n "${MASTER_NS}" --ignore-not-found csv "${csv}"
        local is_deleted=$(("${OC}" delete -n "${MASTER_NS}" --ignore-not-found OperandBindInfo ibm-licensing-bindinfo --timeout=10s > /dev/null 2>&1 && echo "success" ) || echo "fail")
        if [[ $is_deleted == "fail" ]]; then
            warning "Delete OperandBindInfo by patching its finalizer to null..."
            ${OC} patch -n "${MASTER_NS}" OperandBindInfo ibm-licensing-bindinfo --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
        fi
    fi
    for ns in ${EXCLUDED_NS//,/ }; do
        "${OC}" delete -n "${ns}" --ignore-not-found configmap ibm-license-service-reporter-bindinfo-ibm-license-service-reporter-zen
    done
    "${OC}" delete -n "${MASTER_NS}" --ignore-not-found sub ibm-crossplane-operator-app
    "${OC}" delete -n "${MASTER_NS}" --ignore-not-found sub ibm-crossplane-provider-kubernetes-operator-app
    csv=$("${OC}" get -n "${MASTER_NS}" csv | (grep ibm-crossplane-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${MASTER_NS}" --ignore-not-found csv "${csv}"
    csv=$("${OC}" get -n "${MASTER_NS}" csv | (grep ibm-crossplane-provider-kubernetes-operator || echo "fail") | awk '{print $1}')
    "${OC}" delete -n "${MASTER_NS}" --ignore-not-found csv "${csv}"
    
    cleanup_deployment "secretshare" "$MASTER_NS"
    
    success "Singletons successfully uninstalled"
}

function restart() {
    # patch CR for management ingress before sclaing up ibm-common-service-operator deployment when CS CR exists and previous instance is not isolated
    local isExists=$("${OC}" get commonservice common-service -n "${MASTER_NS}" --ignore-not-found)
    if [[ ! -z "$isExists" ]] && [[ "${IS_ISOLATED}" == "0" ]]; then
        patch_cs_cr_for_management_ingress
    fi

    title "Scaling up ibm-common-service-operator deployment in ${MASTER_NS} namespace"
    msg "-----------------------------------------------------------------------"
    ${OC} scale deployment -n ${MASTER_NS} ibm-common-service-operator --replicas=1
    ${OC} scale deployment -n ${MASTER_NS} operand-deployment-lifecycle-manager --replicas=1
    patch_management_ingress_cr
    check_CSCR "$MASTER_NS"
    success "Common Service Operator restarted."
}

function check_cm_ns_exist() {
    title " Verify all namespaces exist "
    msg "-----------------------------------------------------------------------"
    local namespaces=$1
    for ns in $namespaces
    do
        info "Creating namespace $ns"
        ${OC} create namespace $ns || info "$ns already exists, skipping..."
    done
    success "All namespaces in $CM_NAME exist"
}

#TODO change looping to be more specific? 
#Should this only remove the nss from specified set of namespaces? Or should it be more general?
function removeNSS(){

    title " Removing ODLM managed Namespace Scope CRs "
    msg "-----------------------------------------------------------------------"

    info "deleting namespace scope nss-managedby-odlm in namespace ${MASTER_NS}"
    ${OC} delete nss nss-managedby-odlm -n ${MASTER_NS} --ignore-not-found || (error "unable to delete namespace scope nss-managedby-odlm in ${MASTER_NS}")

    info "deleting namespace scope odlm-scope-managedby-odlm in namespace ${MASTER_NS}"
    ${OC} delete nss odlm-scope-managedby-odlm -n ${MASTER_NS} --ignore-not-found || (error "unable to delete namespace scope odlm-scope-managedby-odlm in ${MASTER_NS}")
    
    info "deleting namespace scope nss-odlm-scope in namespace ${MASTER_NS}"
    ${OC} delete nss nss-odlm-scope -n ${MASTER_NS} --ignore-not-found || (error "unable to delete namespace scope nss-odlm-scope in ${MASTER_NS}")
    
    info "deleting namespace scope common-service in namespace ${MASTER_NS}"
    ${OC} delete nss common-service -n ${MASTER_NS} --ignore-not-found || (error "unable to delete namespace scope common-service in ${MASTER_NS}")

    success "Namespace Scope CRs cleaned up"
}

function migrate_lic_cms() {
    title "Copying over Licensing Configmaps"
    msg "-----------------------------------------------------------------------"
    local namespace=$1
    local possible_cms=("ibm-licensing-config"
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

    local cm_list=$("${OC}" get cm -n $namespace "${possible_cms[@]}" -o yaml --ignore-not-found)
    if [ -z "$cm_list" ]; then
        info "No licensing configmaps to migrate"
        return
    fi

    local cleaned_cm_list=$(export_k8s_list_yaml "$cm_list")
    echo "$cleaned_cm_list" | "${OC}" apply -n "$CONTROL_NS" -f -
    success "Licensing configmaps copied from $namespace to $CONTROL_NS"
    "${OC}" delete cm --ignore-not-found -n "${namespace}" "${possible_cms[@]}"
}

function backup_ibmlicensing() {

    ls_instance=$("${OC}" get IBMLicensing instance --ignore-not-found -o yaml)
    if [[ -z "${ls_instance}" ]]; then
        echo "No IBMLicensing instance found, skipping backup"
        return
    fi
 
    # If LS connected to LicSvcReporter, set a template for sender configuration with url pointing to the IBM LSR docs
    # And create an empty secret 'ibm-license-service-reporter-token' in LS_new_namespace to ensure that LS instance pod will start
    local reporterURL=$(echo "${ls_instance}" | "${YQ}" '.spec.sender.reporterURL')
    if [[ "$reporterURL" != "null" ]]; then
        info "The current sender configuration for sending data from License Service to License Service Reporter:" 
        echo "${ls_instance}" | "${YQ}" '.spec.sender'
        
        info "Resetting to a sender configuration template. Please follow the link ibm.biz/lsr_sender_config for more information"
        exist=$("${OC}" get secret -n ${CONTROL_NS} --ignore-not-found | grep ibm-license-service-reporter-token > /dev/null || echo notexists)
        if [[ $exist == "notexists" ]]; then
            "${OC}" create secret generic -n ${CONTROL_NS} ibm-license-service-reporter-token --from-literal=token=''
        fi

        instance=`"${OC}" get IBMLicensing instance -o yaml --ignore-not-found | "${YQ}" '
            with(.; del(.metadata.creationTimestamp) |
            del(.metadata.managedFields) |
            del(.metadata.resourceVersion) |
            del(.metadata.uid) |
            del(.status) | 
            (.spec.sender.reporterURL)="https://READ_(ibm.biz/lsr_sender_config)" |
            (.spec.sender.reporterSecretToken)="ibm-license-service-reporter-token"
            )
        ' | sed -e 's/^/    /g'`
    else
        instance=`"${OC}" get IBMLicensing instance -o yaml --ignore-not-found | "${YQ}" '
            with(.; del(.metadata.creationTimestamp) |
            del(.metadata.managedFields) |
            del(.metadata.resourceVersion) |
            del(.metadata.uid) |
            del(.status)
            )
        ' | sed -e 's/^/    /g'`
    fi
    debug1 "instance: $instance"
cat << _EOF | ${OC} apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ibmlicensing-instance-bak
  namespace: ${CONTROL_NS}
data:
  ibmlicensing.yaml: |
${instance}
_EOF

    if [[ $? -ne 0 ]]; then
        warning "Failed to backup IBMLicensing instance"
    else
        success "IBMLicensing instance is backed up"
    fi
}

function restore_ibmlicensing() {

    is_exist=$("${OC}" get cm ibmlicensing-instance-bak -n ${CONTROL_NS} --ignore-not-found)
    if [[ -z "${is_exist}" ]]; then
        warning "No IBMLicensing instance backup found, skipping restore"
        return
    fi
    # extracts the previously saved IBMLicensing CR from ConfigMap and creates the IBMLicensing CR
    "${OC}" get cm ibmlicensing-instance-bak -n ${CONTROL_NS} -o yaml --ignore-not-found | "${YQ}" .data | sed -e 's/.*ibmlicensing.yaml.*//' | 
    sed -e 's/^  //g' | "${OC}" apply -f -
    
    if [[ $? -ne 0 ]]; then
        warning "Failed to restore IBMLicensing instance"
    else
        success "IBMLicensing instance is restored"
    fi

}

# export_k8s_list_yaml Takes a k8s list in YAML form,
# e.g. oc get configmap -o yaml, and cleans up the cluster/namespace metadata,
# and prints out a YAML that can be applied into any namespace
function export_k8s_list_yaml() {
    local yaml=$1
    echo "$yaml" | "${YQ}" '
        with(.items[].metadata;
            del(.creationTimestamp) |
            del(.managedFields) |
            del(.resourceVersion) |
            del(.uid) |
            del(.namespace)
        )
    '
}

function check_CSCR() {
    local ns=$1

    local retries=60
    local sleep_time=15
    local total_time_mins=$(( sleep_time * retries / 60))
    info "Waiting for IBM Common Services CR is Succeeded"
    sleep 10

    while true; do
        if [[ ${retries} -eq 0 ]]; then
            error "Timeout after ${total_time_mins} minutes waiting for IBM Common Services CR is Succeeded"
        fi

        local phase=$(${OC} get commonservice common-service -o jsonpath='{.status.phase}' -n ${ns})

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
    env_range=$(${OC} get subscription.operators.coreos.com ${sub_name} -n ${ns} -o yaml | "${YQ}" '.spec.config.env[].name')
    patch_string=""
    count=0
    for name in $env_range
    do
        # If isolated mode, set value to true. Otherwise keep name value pairs unchanged.
        if [[ $name == "ISOLATED_MODE" ]]; then
            # Get the value to check if it is already set to true
            existing_value=$(${OC} get subscription.operators.coreos.com ${sub_name} -n ${ns} -o yaml | "${YQ}" '.spec.config.env['"${count}"'].value')
            if [[ $existing_value == "true" ]]; then
                info "isolated mode already set to true in ODLM subscription..."
                IS_ISOLATED=1
            fi
            env_value="true"
        else
            env_value=$(${OC} get subscription.operators.coreos.com ${sub_name} -n ${ns} -o yaml | "${YQ}" '.spec.config.env['"${count}"'].value')
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
    local condition="${OC} -n ${namespace} get deployment ${name} -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name==\"ISOLATED_MODE\")].value}'| grep "true" || true"
    local retries=10
    local sleep_time=12
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for OLM to update Deployment ${name} "
    local success_message="Deployment ${name} is updated"
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
    podpreset_exist=$(${OC} get podpresets.operator.ibm.com -n $MASTER_NS --no-headers || echo "false")
    if [[ $podpreset_exist != "false" ]] && [[ $podpreset_exist != "" ]]; then
        info "Deleting podpresets in namespace $MASTER_NS..."
        ${OC} get podpresets.operator.ibm.com -n $MASTER_NS --no-headers --ignore-not-found | awk '{print $1}' | xargs ${OC} delete -n $MASTER_NS --ignore-not-found podpresets.operator.ibm.com
        msg ""
    fi

    cleanup_deployment "ibm-common-service-webhook" $MASTER_NS

    info "Deleting MutatingWebhookConfiguration..."
    ${OC} delete MutatingWebhookConfiguration ibm-common-service-webhook-configuration --ignore-not-found
    ${OC} delete MutatingWebhookConfiguration ibm-operandrequest-webhook-configuration --ignore-not-found
    msg ""

    info "Deleting ValidatingWebhookConfiguration..."
    ${OC} delete ValidatingWebhookConfiguration ibm-cs-ns-mapping-webhook-configuration --ignore-not-found

}

function cleanup_secretshare() {
    secretshare_exist="true"
    secretshare_exist=$(${OC} get secretshares.ibmcpcs.ibm.com -n $MASTER_NS --no-headers || echo "false")
    if [[ $secretshare_exist != "false" ]] && [[ $secretshare_exist != "" ]]; then
        info "Deleting secretshares in namespace $MASTER_NS..."
	    ${OC} get secretshares.ibmcpcs.ibm.com -n $MASTER_NS --no-headers --ignore-not-found | awk '{print $1}' | xargs ${OC} delete -n $MASTER_NS --ignore-not-found secretshares.ibmcpcs.ibm.com 
        msg ""
    fi

    cleanup_deployment "secretshare" $MASTER_NS
}

function check_if_certmanager_deployed() {
    local namespaces=$@
    info "Checking for cert manager deployed in scope."
    local deployed="false"
    for ns in $namespaces
    do
        opreqs=$(${OC} get opreq -n $ns --no-headers | awk '{print $1}' | tr '\n' ' ')
        for opreq in $opreqs
        do
            local return_value=$(${OC} get opreq $opreq -n $ns -o yaml | ${YQ} '.spec.requests[]' | grep "name: ibm-cert-manager-operator" || echo "fail")
            if [[ $return_value != "fail" ]]; then
                deployed="true"
                info "Cert manager requested in scope, moving on..."
                break
            fi
        done
    done

    if [[ $deployed == "false" ]]; then
        info "Cert manager not requested in scope, deploying..."
        cat <<EOF > /tmp/tmp-opreq.yaml
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  labels:
    app.kubernetes.io/instance: operand-deployment-lifecycle-manager
    app.kubernetes.io/managed-by: operand-deployment-lifecycle-manager
    app.kubernetes.io/name: odlm
  name: ibm-cert-manager-operator
  namespace: $MASTER_NS
spec:
  requests:
    - operands:
        - name: ibm-cert-manager-operator
      registry: common-service
      registryNamespace: $MASTER_NS
EOF

    ${OC} apply -f /tmp/tmp-opreq.yaml
    rm -f /tmp/tmp-opreq.yaml
    fi

}

function wait_for_certmanager() {
    local namespaces=$@
    title " Wait for Cert Manager pods to come ready "
    msg "-----------------------------------------------------------------------"
    
    check_if_certmanager_deployed "${namespaces}"

    #check cert manager operator pod
    local name="cert-manager-operator"
    local condition="${OC} get deploy -A --no-headers --ignore-not-found | egrep '1/1' | grep ${name} || true"
    local retries=20
    local sleep_time=15
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for deployment ${name} to be running ..."
    local success_message="Deployment ${name} is running."
    local error_message="Timeout after ${total_time_mins} minutes waiting for deployment ${name} to be running."
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"

    #check webhook pod runnning
    name="cert-manager-webhook"
    condition="${OC} get pod -A --no-headers --ignore-not-found | egrep '1/1' | grep ${name} || true"
    wait_message="Waiting for pod ${name} to be running ..."
    success_message="Pod ${name} is running."
    error_message="Timeout after ${total_time_mins} minutes waiting for pod ${name} to be running."
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"

    #check no duplicate webhook pod
    webhook_deployments=$(${OC} get deploy -A --no-headers --ignore-not-found | grep ${name} -c)
    if [[ $webhook_deployments != "1" ]]; then
        error "More than one cert-manager-webhook deployment exists on the cluster."
    fi
    webhook_ns=$(${OC} get deploy -A | grep cert-manager-webhook | awk '{print $1}')
    success "Cert Manager ready. Cert Manager operands deployed in $webhook_ns"
}

function check_certmanager_count(){
    info "Verifying cert manager is deployed"
    csv_count=$(${OC} get csv -A | awk '{print $2}' | grep "cert-manager"| wc -l | tr -d " " || echo "")
    debug1 "cert manager csv count output: $csv_count"
    if [[ "$csv_count" == "0" ]] || [[ "$csv_count" == "" ]]; then
        error "Missing a cert-manager"
    fi
    # if installed in all namespace mode or alongside cp2 cert manager, 
    # csv_count will be >1, need to check for multiple deployments
    if [[ $csv_count > 1 ]]; then 
        webhook_deployments=$(${OC} get deploy -A --no-headers --ignore-not-found | grep "cert-manager-webhook" -c || echo "")
        if [[ $webhook_deployments == "" ]]; then
            error "Failed to cert-manager-webhook deployment"
        elif [[ $webhook_deployments != "1" ]]; then
            error "Multiple cert-managers found. Only one should be installed per cluster"
        fi
    fi
    success "Cert manager deployment verified."
}

function isolate_license_service_reporter(){
    title "Isolating License Service Reporter"
    return_value=$( ("${OC}" get crd ibmlicenseservicereporters.operator.ibm.com > /dev/null && echo exists) || echo fail)
    if [[ $return_value == "exists" ]]; then

        return_value=$("${OC}" get ibmlicenseservicereporters -A --no-headers | wc -l)
        if [[ $return_value -gt 0 ]]; then

            # Change persistentVolumeReclaimPolicy to Retain
            status=$("${OC}" get pvc license-service-reporter-pvc --ignore-not-found -n $MASTER_NS  --no-headers | awk '{print $2}' )
            debug1 "LSR pvc status: $status"
            if [[ "$status" == "Bound" ]]; then
                VOL=$("${OC}" get pvc license-service-reporter-pvc --ignore-not-found -n $MASTER_NS  -o=jsonpath='{.spec.volumeName}')
                debug1 "LSR volume name: $VOL"
                if [[ -z "$VOL" ]]; then
                    error "Volume for pvc license-service-reporter-pvc not found in $MASTER_NS"
                fi

                # label LSR PV as LSR PV for further LSR upgrade
                ${OC} label pv $VOL license-service-reporter-pv=true --overwrite 
                debug1 "License Service Reporter PV labeled with 'license-service-reporter-pv=true'"
            
                ${OC} patch pv $VOL -p '{"spec": { "persistentVolumeReclaimPolicy" : "Retain" }}'
                debug1 "License Service Reporter PV reclaim policy set to 'Retain'"
            else
                info "No Lisense Service Reporter PVC found in $MASTER_NS or it is not in 'Bound' state, skipping isolation."
            fi
        fi
    fi
    success "License Service Reporter isolation process completed."
}

function wait_for_nss_update() {
    local expected_ns_list=${1//$'\n'/ }
    local retries=5
    local wait_time=20
    
    wait_for_nss_exist
    
    for (( i=1; i<=$retries; i++ )); do

        local actual_ns_list=$(${OC} get cm namespace-scope -n ${MASTER_NS} -o yaml | ${YQ} '.data.namespaces')
        actual_ns_list=$(echo "${actual_ns_list//,/ }" | xargs -n1 | sort | xargs)
        expected_ns_list=$(echo "${expected_ns_list}" | xargs -n1 | sort | xargs)
        
        debug1 "expected ns list: $expected_ns_list"
        debug1 "actual ns list: $actual_ns_list"
        
        if [[ "${expected_ns_list}" == "${actual_ns_list}" ]]; then
            success "Namespaces in namespace-scope configmap match expected output."
            break
        else
            if [[ $i -lt $retries ]]; then
                info "Namespaces in namespace-scope configmap do not match expected output. Retrying in $wait_time seconds..."
                sleep $wait_time
            else
                error "Namespaces in namespace-scope configmap do not match expected output after $retries retries."
            fi
        fi
    done
}

function wait_for_nss_exist() {
    local condition="${OC} get cm namespace-scope -n ${MASTER_NS} --ignore-not-found || true"
    local retries=10
    local sleep_time=15
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for configmap namespace-scope in namespace ${MASTER_NS} to be created ..."
    local success_message="Namespace-scope configmap created in ${MASTER_NS}."
    local error_message="Timeout after ${total_time_mins} minutes waiting for namespace-scope configmap to be created."
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function patch_cs_cr_for_management_ingress() {
    title "Updating commonservice common-service in namespace ${MASTER_NS} for management ingress CR ..."
    "${OC}" get commonservice common-service -n "${MASTER_NS}" -o yaml > /tmp/tmp_cs_cr.yaml

    local is_exist_in_cs=$("${YQ}" eval '.spec.services[].name' /tmp/tmp_cs_cr.yaml | grep "ibm-management-ingress-operator" || echo "false")
    if [[ "${is_exist_in_cs}" == "false" ]]; then
        "${YQ}" -i eval '.spec.services += [{"name": "ibm-management-ingress-operator", "spec": {"managementIngress": {"multipleInstancesEnabled": false}}}]' /tmp/tmp_cs_cr.yaml
    else
        info "ibm-management-ingress-operator already exists in CS CR .spec.services, updating it ..."
        "${YQ}" -i eval '(.spec.services[] |= select(.name == "ibm-management-ingress-operator").spec.managementIngress.multipleInstancesEnabled = false)' /tmp/tmp_cs_cr.yaml
    fi
  
    local retries=10
    local sleep_time=5
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for commonservice common-service in namespace ${MASTER_NS} to be updated for management ingress CR ..."
    local success_message="Commonservice common-service updated in ${MASTER_NS} for management ingress CR."
    local error_message="Timeout after ${total_time_mins} minutes waiting for commonservice common-service to be updated for management ingress CR."
    while true; do
        if [[ ${retries} -eq 0 ]]; then
            rm -f /tmp/tmp_cs_cr.yaml
            error "${error_message}"
        fi

        local result=$("${OC}" apply -n "${MASTER_NS}" -f /tmp/tmp_cs_cr.yaml 2>&1 || echo "fail")
        if [[ "${result}" == "fail" ]]; then
            retries=$(( retries - 1 ))
            info "RETRYING: ${wait_message} (${retries} left)"
            sleep ${sleep_time}
        else
            success "${success_message}"
            break
        fi
    done
    rm -f /tmp/tmp_cs_cr.yaml
}

function patch_opconfig_for_management_ingress() {
    title "Updating operandconfig common-service in namespace ${MASTER_NS} for management ingress CR ..."
    "${OC}" get operandconfig common-service -n "${MASTER_NS}" -o yaml > tmp_oc_cr.yaml

    local is_exist_in_opcon=$("${YQ}" eval '.spec.services[].name' tmp_oc_cr.yaml | grep "ibm-management-ingress-operator" || echo "false")
    if [[ "${is_exist_in_opcon}" == "false" ]]; then
        "${YQ}" -i eval '.spec.services += [{"name": "ibm-management-ingress-operator", "spec": {"managementIngress": {"multipleInstancesEnabled": false}}}]' tmp_oc_cr.yaml
    else
        info "ibm-management-ingress-operator already exists in operandconfig CR .spec.services, updating it ..."
        "${YQ}" -i eval '(.spec.services[] |= select(.name == "ibm-management-ingress-operator").spec.managementIngress.multipleInstancesEnabled = false)' tmp_oc_cr.yaml
    fi

    local retries=12
    local sleep_time=5
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for operandconfig common-service in namespace ${MASTER_NS} to be updated for management ingress CR ..."
    local success_message="Operandconfig common-service updated in ${MASTER_NS} for management ingress CR."
    local error_message="Timeout after ${total_time_mins} minutes waiting for operandconfig common-service to be updated for management ingress CR."
    while true; do
        if [[ ${retries} -eq 0 ]]; then
            rm -f tmp_oc_cr.yaml
            error "${error_message}"
        fi

        local result=$("${OC}" apply -n "${MASTER_NS}" -f tmp_oc_cr.yaml 2>&1 || echo "fail")
        if [[ "${result}" == "fail" ]]; then
            retries=$(( retries - 1 ))
            info "RETRYING: ${wait_message} (${retries} left)"
            sleep ${sleep_time}
        else
            success "${success_message}"
            break
        fi
    done
    rm -f tmp_oc_cr.yaml
}

function wait_for_management_ingress_be_patched() {
    local condition="${OC} get managementingress default -n ${MASTER_NS} -o jsonpath='{.spec.multipleInstancesEnabled}' | grep 'false' || true"
    local retries=10
    local sleep_time=5
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for managementingress default in namespace ${MASTER_NS} to be patched with multipleInstancesEnabled false ..."
    local success_message="Managementingress default in ${MASTER_NS} patched with multipleInstancesEnabled false."
    local error_message="Timeout after ${total_time_mins} minutes waiting for managementingress default to be patched with multipleInstancesEnabled false."
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function patch_management_ingress_cr() {
    if [[ "${IS_ISOLATED}" == "0" ]]; then
        wait_for_cs_cr_exist
        patch_cs_cr_for_management_ingress
        wait_for_opconfig_exist
        patch_opconfig_for_management_ingress
    else
        warning "Instance has been isolated previously, skipping patching commonservice and operandconfig for management ingress CR..."
    fi
}

function wait_for_cs_cr_exist() {
    local condition="${OC} get commonservice common-service -n ${MASTER_NS} --ignore-not-found || true"
    local retries=20
    local sleep_time=5
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for commonservice common-service in namespace ${MASTER_NS} to be created ..."
    local success_message="Commonservice common-service created in ${MASTER_NS}."
    local error_message="Timeout after ${total_time_mins} minutes waiting for commonservice common-service to be created."
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_opconfig_exist() {
    local condition="${OC} get operandconfig common-service -n ${MASTER_NS} --ignore-not-found || true"
    local retries=60
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for operandconfig common-service in namespace ${MASTER_NS} to be created ..."
    local success_message="Operandconfig common-service created in ${MASTER_NS}."
    local error_message="Timeout after ${total_time_mins} minutes waiting for operandconfig common-service to be created."
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

#this function checks to see if the cluster is in an error state due to a previous failed run
#specifically, looks to see if cs operator and odlm have been rescaled back to 1 replica each
#also checks for cert manager to be deployed before failing in the case that cert manager is uninstalled in a previous run but previous run failed before reinstalling
function prev_fail_check() {
    info "Checking for common service operator and odlm pods"
    local cs_operator_scaled=$(${OC} get deploy -n $MASTER_NS | egrep '1/1'| grep ibm-common-service-operator || echo "false")
    debug1 "cs op scaled output: $cs_operator_scaled"
    local cs_op_scale_needed="false"
    if [[ "$cs_operator_scaled" == "false" ]]; then 
        ${OC} scale deploy ibm-common-service-operator -n $MASTER_NS --replicas=1
        info "Common Service Operator scaled back to 1"
        cs_op_scale_needed="true"
    else
        info "Common Service Operator already scaled, skipping."
    fi
    local odlm_scaled=$(${OC} get deploy -n $MASTER_NS | egrep '1/1'| grep operand-deployment-lifecycle-manager || echo "false")
    debug1 "odlm scaled output: $odlm_scaled"
    if [[ "$odlm_scaled" == "false" ]]; then 
        ${OC} scale deploy operand-deployment-lifecycle-manager -n $MASTER_NS --replicas=1
        info "ODLM scaled back to 1"
    else
        info "ODLM already scaled, skipping."
    fi

    if [[ $cs_op_scale_needed == "true" ]]; then
        check_CSCR "$MASTER_NS"
        #wait for cert manager to come back ready after scaling up
        local ns_list=$(gather_csmaps_ns)
        wait_for_certmanager "${ns_list}"
    fi

}

function check_yq() {
    yq_version=$("${YQ}" --version | awk '{print $NF}' | sed 's/^v//')
    yq_minimum_version=4.18.1

    if [ "$(printf '%s\n' "$yq_minimum_version" "$yq_version" | sort -V | head -n1)" != "$yq_minimum_version" ]; then 
        error "yq version $yq_version must be at least $yq_minimum_version or higher.\nInstructions for installing/upgrading yq are available here: https://github.com/marketplace/actions/yq-portable-yaml-processor"
    fi
}

function msg() {
    printf '%b\n' "$1"
}

function success() {
    msg "\33[32m[✔] ${1}\33[0m"
}

function warning() {
    msg "\33[33m[✗] ${1}\33[0m"
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
