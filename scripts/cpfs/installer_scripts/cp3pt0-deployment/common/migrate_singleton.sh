#!/usr/bin/env bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product. 
# Please refer to that particular license for additional information. 

# ---------- Command arguments ----------

OC=oc
YQ=yq
OPERATOR_NS=""
CONTROL_NS=""
SOURCE_NS="openshift-marketplace"
ENABLE_LICENSING=0
ENABLE_LICENSE_SERVICE_REPORTER=0
LSR_NAMESPACE="ibm-lsr"
LICENSING_NS=""
NEW_MAPPING=""
NEW_TENANT=0
DEBUG=0
PREVIEW_MODE=0

# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# counter to keep track of installation steps
STEP=0

# ---------- Main functions ----------

. ${BASE_DIR}/utils.sh

function main() {
    parse_arguments "$@"
    pre_req

    # Delete CP2.0 Cert-Manager CR
    ${OC} delete certmanager.operator.ibm.com default --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        warning "Failed to delete Cert Manager CR, patching its finalizer to null..."
        ${OC} patch certmanagers.operator.ibm.com default --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi

    if [ ! -z "$CONTROL_NS" ]; then
        # Delegation of CP2 Cert Manager
        ${BASE_DIR}/delegate_cp2_cert_manager.sh "--control-namespace" "$CONTROL_NS" "--yq" "$YQ" "--oc" "$OC"
    fi

    delete_operator "ibm-cert-manager-operator" "$OPERATOR_NS"
    
    if [[ $ENABLE_LICENSING -eq 1 ]]; then

        is_exists=$("$OC" get deployments ibm-licensing-operator -n "$OPERATOR_NS" --ignore-not-found)
        if [ ! -z "$is_exists" ]; then
            # Migrate Licensing Services Data
            ${BASE_DIR}/migrate_cp2_licensing.sh "--control-namespace" "$OPERATOR_NS" "--target-namespace" "$LICENSING_NS" "--yq" "$YQ" "--oc" "$OC"
            local is_deleted=$(("${OC}" delete -n "${CONTROL_NS}" --ignore-not-found OperandBindInfo ibm-licensing-bindinfo --timeout=10s > /dev/null && echo "success" ) || echo "fail")
            if [[ $is_deleted == "fail" ]]; then
                warning "Failed to delete OperandBindInfo, patching its finalizer to null..."
                ${OC} patch -n "${CONTROL_NS}" OperandBindInfo ibm-licensing-bindinfo --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
            fi
        fi

        if [[ $ENABLE_LICENSE_SERVICE_REPORTER -eq 1 ]]; then
            isolate_license_service_reporter
            migrate_license_service_reporter
        fi

        backup_ibmlicensing
        is_exists=$("${OC}" get deployments -n "${CONTROL_NS}" --ignore-not-found ibm-licensing-operator)
        if [ ! -z "$is_exists" ]; then
            "${OC}" delete --ignore-not-found ibmlicensing instance
        fi

        # Delete licensing csv/subscriptions
        delete_operator "ibm-licensing-operator" "$OPERATOR_NS"

        # restore licensing configuration so that subsequent License Service install will pick them up
        restore_ibmlicensing
    fi

    success "Migration is completed for Cloud Pak 3.0 Foundational singleton services."
}

function isolate_license_service_reporter(){
    title "Isolating License Service Reporter"

    local return_value=$( ("${OC}" get crd ibmlicenseservicereporters.operator.ibm.com > /dev/null && echo exists) || echo fail)

    if [[ $return_value == "fail" ]]; then
        return 0
    fi

    local lsr_cr=$("${OC}" get IBMLicenseServiceReporter -A --no-headers)
    local count=$(echo "$lsr_cr" | wc -l)

    if [[ count -eq 0 ]]; then
        info "No LSR for migration found in cluster"
        return 0
    fi

    if [[ count -ne 1 ]]; then
        info "Expecting exactly one IBMLicenseServiceReporter in cluster.${count} found."
        return 0
    fi

    local ns=$(echo "$lsr_cr" | cut -d ' ' -f1)

    return_value=$("${OC}" get ibmlicenseservicereporters -A --no-headers | wc -l)
    if [[ $return_value -gt 0 ]]; then

        # Change persistentVolumeReclaimPolicy to Retain
        local status=$("${OC}" get pvc license-service-reporter-pvc --ignore-not-found -n $ns  --no-headers | awk '{print $2}' )
        debug1 "LSR pvc status: $status"
        if [[ "$status" == "Bound" ]]; then
            local VOL=$("${OC}" get pvc license-service-reporter-pvc --ignore-not-found -n $ns  -o=jsonpath='{.spec.volumeName}')
            debug1 "LSR volume name: $VOL"
            if [[ -z "$VOL" ]]; then
                error "Volume for pvc license-service-reporter-pvc not found in $ns"
            fi

            # label LSR PV as LSR PV for further LSR upgrade
            ${OC} label pv $VOL license-service-reporter-pv=true --overwrite 
            debug1 "License Service Reporter PV labeled with 'license-service-reporter-pv=true'"
        
            ${OC} patch pv $VOL -p '{"spec": { "persistentVolumeReclaimPolicy" : "Retain" }}'
            debug1 "License Service Reporter PV reclaim policy set to 'Retain'"
        else
            info "No Lisense Service Reporter PVC found in $ns or it is not in 'Bound' state, skipping isolation."
        fi
    fi
    success "License Service Reporter isolation process completed."
}

function migrate_license_service_reporter(){
    title "LSR migration from ibm-cmmon-services to ${LSR_NAMESPACE}"

    local lsr_cr=$("${OC}" get IBMLicenseServiceReporter -A --no-headers)
    local count=$(echo "$lsr_cr" | wc -l)

    if [[ count -eq 0 ]]; then
        info "No LSR for migration found in cluster"
        return 0
    fi

    if [[ count -ne 1 ]]; then
        info "Expecting exactly one IBMLicenseServiceReporter in cluster.${count} found."
        return 0
    fi

    local ns=$(echo "$lsr_cr" | cut -d ' ' -f1)

    lsr_cr_name=$("${OC}" get IBMLicenseServiceReporter -n ${ns} --no-headers | awk '{print $1}')
    local lsr_instances=$("${OC}" get IBMLicenseServiceReporter ${lsr_cr_name} -n ${ns} --no-headers | wc -l)

    if [[ lsr_instances -eq 0 ]]; then
        info "No LSR for migration found in ${ns} namespace"
        return 0
    fi

    lsr_pv_nr=$("${OC}" get pv -l license-service-reporter-pv=true --no-headers | wc -l )
    if [[ lsr_pv_nr -ne 1 ]]; then
        warning "Expecting exactly one PV with label license-service-reporter-pv=true. $lsr_pv_nr found. Migration skipped."
        return 0
    fi

    # Prepare LSR PV/PVC which was decoupled in isolate.sh
    # delete old LSR CR - PV will stay as during isolate.sh the policy was set to Retain
    ${OC} delete IBMLicenseServiceReporter ${lsr_cr_name} -n ${ns}
    export LSR_CR_NAME=$lsr_cr_name

    # in case PVC is blocked with deletion, the finalizer needs to be removed
    lsr_pvcs=$("${OC}" get pvc license-service-reporter-pvc -n ${ns}  --no-headers | wc -l)
    if [[ lsr_pvcs -gt 0 ]]; then
        info "Failed to delete pvc license-service-reporter-pvc, patching its finalizer to null..."
        ${OC} patch pvc license-service-reporter-pvc -n ${ns}  --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    else
        debug1 "No pvc license-service-reporter-pvc as expected"
    fi

    if [[ lsr_pv_nr -eq 1 ]]; then
        debug1 "LSR namespace: ${LSR_NAMESPACE}" 
        create_namespace "${LSR_NAMESPACE}"

        # get storage class name
        LSR_PV_NAME=$("${OC}" get pv -l license-service-reporter-pv=true -o=jsonpath='{.items[0].metadata.name}')
        debug1 "PV name: $LSR_PV_NAME"
        
        # on ROKS storage class name cannot be proviced during PVC creation
        roks=$(${OC} cluster-info | grep 'containers.cloud.ibm.com')
        if [[ -z $roks ]]; then
            LSR_STORAGE_CLASS=$("${OC}" get pv -l license-service-reporter-pv=true -o=jsonpath='{.items[0].spec.storageClassName}')
            if [[ -z $LSR_STORAGE_CLASS ]]; then
                error "Cannnot get storage class name from PVC license-service-reporter-pv in $LSR_NAMESPACE"
            fi
        else
            debug1 "Run on ROKS, not setting storageclass name"
            LSR_STORAGE_CLASS=""
                       
            deprecated_region='{.items[0].metadata.labels.failure-domain\.beta\.kubernetes\.io\/region}'
            deprecated_zone='{.items[0].metadata.labels.failure-domain\.beta\.kubernetes\.io\/zone}'


            deprecated_region_label='failure-domain.beta.kubernetes.io/region'
            not_deprecated_region_label='topology.kubernetes.io/region'
            deprecated_zone_label='failure-domain.beta.kubernetes.io/zone'
            not_deprecated_zone_label='topology.kubernetes.io/zone'

            region=$("${OC}" get pv -l license-service-reporter-pv=true -o=jsonpath=$deprecated_region)
            zone=$("${OC}" get pv -l license-service-reporter-pv=true -o=jsonpath=$deprecated_zone)

            if [[ $region != "" ]]; then
                debug1 "Replacing depracated PV labels"
                "${OC}" label pv $LSR_PV_NAME $not_deprecated_region_label=$region $deprecated_region_label- $not_deprecated_zone_label=$zone $deprecated_zone_label- --overwrite 
            fi
        fi

        # create PVC
        TEMP_LSR_PVC_FILE="_TEMP_LSR_PVC_FILE.yaml"

        cat <<EOF >$TEMP_LSR_PVC_FILE
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
            name: license-service-reporter-pvc
            namespace: ${LSR_NAMESPACE}
        spec:
            accessModes:
            - ReadWriteOnce
            resources:
                requests:
                    storage: 1Gi
            storageClassName: "${LSR_STORAGE_CLASS}"
            volumeMode: Filesystem
            volumeName: ${LSR_PV_NAME}
EOF

        ${OC} create -f ${TEMP_LSR_PVC_FILE}
        # checking status of PVC - in case it cannot be boud, the claimRef needs to be set to null
        status=$("${OC}" get pvc license-service-reporter-pvc -n $LSR_NAMESPACE --no-headers | awk '{print $2}')
        while [[ "$status" != "Bound" ]]
        do
            namespace=$("${OC}" get pv ${LSR_PV_NAME} -o=jsonpath='{.spec.claimRef.namespace}')
            if [[ $namespace != $LSR_NAMESPACE ]]; then
                ${OC} patch pv ${LSR_PV_NAME} --type=merge -p '{"spec": {"claimRef":null}}'
            fi
            info "Waiting for pvc license-service-reporter-pvc to bind"
            sleep 10
            status=$("${OC}" get pvc license-service-reporter-pvc -n $LSR_NAMESPACE --no-headers | awk '{print $2}')
        done
    fi
}


function restore_ibmlicensing() {

    is_exist=$("${OC}" get cm ibmlicensing-instance-bak -n ${LICENSING_NS} --ignore-not-found)
    if [[ -z "${is_exist}" ]]; then
        warning "No IBMLicensing instance backup found, skipping restore"
        return
    fi
    # extracts the previously saved IBMLicensing CR from ConfigMap and creates the IBMLicensing CR
    "${OC}" get cm ibmlicensing-instance-bak -n ${LICENSING_NS} -o yaml --ignore-not-found | "${YQ}" .data | sed -e 's/.*ibmlicensing.yaml.*//' | 
    sed -e 's/^  //g' | "${OC}" apply -f -
    
    if [[ $? -ne 0 ]]; then
        warning "Failed to restore IBMLicensing instance"
    else
        success "IBMLicensing instance is restored"
    fi

}

function backup_ibmlicensing() {
    create_namespace "${LICENSING_NS}"

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
        exist=$("${OC}" get secret -n ${LICENSING_NS} --ignore-not-found | grep ibm-license-service-reporter-token > /dev/null || echo notexists)
        if [[ $exist == "notexists" ]]; then
            "${OC}" create secret generic -n ${LICENSING_NS} ibm-license-service-reporter-token --from-literal=token=''
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
  namespace: ${LICENSING_NS}
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
        --control-namespace)
            shift
            CONTROL_NS=$1
            ;;
        --licensing-namespace)
            shift
            LICENSING_NS=$1
            ;;
        --enable-licensing)
            ENABLE_LICENSING=1
            ;;
        --enable-license-service-reporter)
            ENABLE_LICENSE_SERVICE_REPORTER=1
            ;;
        --lsr-namespace)
            shift
            LSR_NAMESPACE=$1
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
    echo "Usage: ${script_name} --operator-namespace <foundational-services-namespace> [OPTIONS]..."
    echo ""
    echo "Migrate Cloud Pak 2.0 Foundational singleton services to in Cloud Pak 3.0 Foundational singleton services"
    echo "The --operator-namespace must be provided."
    echo ""
    echo "Options:"
    echo "   --oc string                                    File path to oc CLI. Default uses oc in your PATH"
    echo "   --yq string                                    File path to yq CLI. Default uses yq in your PATH"
    echo "   --operator-namespace string                    Required. Namespace to migrate Foundational services operator"
    echo "   --enable-licensing                             Set this flag to migrate IBM Licensing operator"
    echo "   --enable-license-service-reporter              Set this flag to install IBM License Service Reporter operator"
    echo "   --licensing-namespace                          Required. Namespace to migrate Licensing"
    echo "   --lsr-namespace                                Required. Namespace to migrate License Service Reporter"
    echo "   -v, --debug integer                            Verbosity of logs. Default is 0. Set to 1 for debug logs."
    echo "   -h, --help                                     Print usage information"
    echo ""
}

function pre_req() {
    check_command "${OC}"
    check_command "${YQ}"
    check_yq_version

    if [ "$CONTROL_NS" == "" ]; then
        CONTROL_NS=$OPERATOR_NS
    fi    
}

main "$@"