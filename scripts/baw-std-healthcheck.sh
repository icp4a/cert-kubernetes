#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2022, 2024. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh

function usage() {
echo ""
echo "IBM Business Automation Workflow on containers Health Check.

Usage:
  baw-std-healthcheck.sh -n <namespace>

Options:
  -n|--namespace    Specify the workflow on containers namespace.
  -h|--help         Display the help message.
 "
}

function validate_kube_oc_cli(){
    if which kubectl >/dev/null 2>&1; then
        CLI_CMD=kubectl
    elif which oc >/dev/null 2>&1; then
        CLI_CMD=oc
    else
        echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI or OpenShift CLI. You must install it to run this script.\x1B[0m" && \
        exit 1
    fi
}

function resource_health_check() {
    if [[ -n $1 ]]; then
        _resource_type=$1
        _resource_name=$2
        _resource_ns=$3
        _supported_resource_type=("deployment" "statefulset" "job")
        if echo "${_supported_resource_type[@]}" | grep -w ${_resource_type} &>/dev/null; then
            ${_resource_type}_health_check ${_resource_name} ${_resource_ns}
            return $?
        fi
        return 0
    else
        return 1
    fi
}

function statefulset_health_check() {
    resource_name=$1
    resource_namespace=$2

    _desired_replicas=$(${CLI_CMD} get statefulset $_resource_name -n ${resource_namespace} -o jsonpath={.status.replicas})
    _ready_replicas=$(${CLI_CMD} get statefulset $_resource_name -n ${resource_namespace} -o jsonpath={.status.readyReplicas})

    if [ "${_desired_replicas}" != "${_ready_replicas:-0}" ]; then
        error "The StatefulSet of ${resource_name} in namespace ${resource_namespace} was not ready."
        return 1
    fi

    success "The StatefulSet of ${resource_name} in namespace ${resource_namespace} was ready."
    return 0
}

function deployment_health_check() {
    resource_name=$1
    resource_namespace=$2

    _desired_replicas=$(${CLI_CMD} get deployment ${resource_name} -n ${resource_namespace} -o jsonpath={.status.replicas})
    _ready_replicas=$(${CLI_CMD} get deployment ${resource_name} -n ${resource_namespace} -o jsonpath={.status.readyReplicas})

    if [ "${_desired_replicas}" != "${_ready_replicas:-0}" ]; then
        error "The Deployment of ${resource_name} in namespace ${resource_namespace} was not ready."
        return 1
    fi

    success "The Deployment of ${resource_name} in namespace ${resource_namespace} was ready."
    return 0
}

function job_health_check() {
    resource_name=$1
    resource_namespace=$2
    _is_successed=$(${CLI_CMD} get job $resource_name -n ${resource_namespace} -o jsonpath={.status.succeeded})
    
    if [[ $_is_successed != 1 ]]; then
        error "The Job of ${resource_name} in namespace ${resource_namespace} was not succeeded."
        return 1
    fi

    success "The Job of ${resource_name} in namespace ${resource_namespace} was succeeded."
    return 0
}

#
# Check operator status
# pods / deployment
#
function check_operator_status() {
    # CP4BA operator
    title "Checking CP4BA Operator status: "
    cp4ba_operator_deployment=$(${CLI_CMD} get deployment ibm-cp4a-operator -n ${namespace} --no-headers -o custom-columns=":metadata.name" >/dev/null 2>&1)
    if [[ $? -ne 0 ]]; then
        error "The CP4BA Operator has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} -l "name=ibm-cp4a-operator" --label-columns=release
        cp4ba_operator_deployment_name=$(${CLI_CMD} get deployment ibm-cp4a-operator -n ${namespace} --no-headers -o custom-columns=":metadata.name" 2>&1)
        resource_health_check "deployment" "${cp4ba_operator_deployment_name}" "${namespace}"
    fi

    # Workflow operator
    title "Checking Workflow Operator status: "
    workflow_operator_deployment=$(${CLI_CMD} get deployment ibm-workflow-operator -n ${namespace} --no-headers -o custom-columns=":metadata.name" >/dev/null 2>&1)
    if [[ $? -ne 0 ]]; then
        error "The Workflow Operator has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} -l "name=ibm-workflow-operator" --label-columns=release
        workflow_operator_deployment_name=$(${CLI_CMD} get deployment ibm-workflow-operator -n ${namespace} --no-headers -o custom-columns=":metadata.name" 2>&1)
        resource_health_check "deployment" "${workflow_operator_deployment_name}" "${namespace}"
    fi

    # Content operator
    title "Checking Content Operator status: "
    content_operator_deployment=$(${CLI_CMD} get deployment ibm-content-operator -n ${namespace} --no-headers -o custom-columns=":metadata.name" >/dev/null 2>&1)
    if [[ $? -ne 0 ]]; then
        error "The Content Operator has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} -l "name=ibm-content-operator" --label-columns=release
        content_operator_deployment_name=$(${CLI_CMD} get deployment ibm-content-operator -n ${namespace} --no-headers -o custom-columns=":metadata.name" 2>&1)
        resource_health_check "deployment" "${content_operator_deployment_name}" "${namespace}"
    fi
    
    # # PFS operator
    # title "Checking PFS Operator status: "
    # # In CP4BA, PFS operator deployment name is ibm-pfs-operator
    # # In BAW-STD, PFS operator deployment name is ibm-cp4a-pfs-operator-controller-manager
    # pfs_operator_deployment=$(${CLI_CMD} get deployment ibm-pfs-operator -n ${namespace} --no-headers -o custom-columns=":metadata.name" >/dev/null 2>&1)
    # if [[ $? -ne 0 ]]; then
    #     pfs_operator_deployment=$(${CLI_CMD} get deployment ibm-cp4a-pfs-operator-controller-manager -n ${namespace} --no-headers -o custom-columns=":metadata.name" >/dev/null 2>&1)
    #     if [[ $? -ne 0 ]]; then
    #         error "The PFS Operator has not been deployed."
    #     else 
    #         ${CLI_CMD} get pods -n ${namespace} -l "name=ibm-cp4a-pfs-operator" --label-columns=release
    #         pfs_operator_deployment_name=$(${CLI_CMD} get deployment ibm-cp4a-pfs-operator-controller-manager -n ${namespace} --no-headers -o custom-columns=":metadata.name" 2>&1)
    #         resource_health_check "deployment" "${pfs_operator_deployment_name}" "${namespace}"
    #     fi
    # else
    #     ${CLI_CMD} get pods -n ${namespace} -l "name=ibm-pfs-operator" --label-columns=release
    #     pfs_operator_deployment_name=$(${CLI_CMD} get deployment ibm-pfs-operator -n ${namespace} --no-headers -o custom-columns=":metadata.name" 2>&1)
    #     resource_health_check "deployment" "${pfs_operator_deployment_name}" "${namespace}"
    # fi
}

#
# Check worklow server status
# pods / statefulset / jobs
#
function check_workflow_server_status() {
    title "Checking Workflow Server status: "

    workflow_sts_all=$(${CLI_CMD} get sts -n ${namespace} --no-headers -l "app.kubernetes.io/name=workflow-server" -o custom-columns=":metadata.name")
    if [[ -z "$workflow_sts_all" ]]; then
        error "Workflow Server has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} -l "app.kubernetes.io/name=workflow-server" --label-columns=release

        for sts in ${workflow_sts_all}; do
            resource_health_check "statefulset" "${sts}" "${namespace}"
        done

        workflow_jobs=$(${CLI_CMD} get jobs -n ${namespace} --no-headers -l "app.kubernetes.io/name=workflow-server" -o custom-columns=":metadata.name")
        for job_name in ${workflow_jobs}; do
            resource_health_check "job" "${job_name}" "${namespace}"
        done
    fi
}

#
# Check JMS server status
# pods / statefulset
#
function check_jms_status() {
    title "Checking Java Message Service (JMS) status: "

    jms_pods=$(${CLI_CMD} get pods -n ${namespace} --no-headers -o custom-columns=":metadata.name" | grep "baw-jms")

    if [[ -z "${jms_pods}" ]]; then 
        error "Java Message Service has not been deployed."
    else
        for jms_pod in ${jms_pods}; do
        ${CLI_CMD} get pods ${jms_pod} -n ${namespace} --label-columns=release
        done

        jms_sts_all=$(${CLI_CMD} get sts -n ${namespace} --no-headers -o custom-columns=":metadata.name" | grep "baw-jms")
        for sts in ${jms_sts_all}; do
            resource_health_check "statefulset" "${sts}" "${namespace}"
        done
    fi
}

#
# Check FNCM status (CPE/CMIS/GraphQL/Navigator)
# pods / deployment
#
function check_fncm_status() {
    title "Checking Content Platform Engine (CPE) status: "
    cpe_deployment_name=$(${CLI_CMD} get deployment -n ${namespace} --no-headers -o custom-columns=":metadata.name" -l "app=${CR_NAME}-cpe-deploy")
    if [[ -z "${cpe_deployment_name}" ]]; then
        error "Content Platform Engine has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app=${CR_NAME}-cpe-deploy"
        resource_health_check "deployment" "${cpe_deployment_name}" "${namespace}"
    fi

    title "Checking Content Management Interoperability Services (CMIS) status: "
    cmis_deployment_name=$(${CLI_CMD} get deployment -n ${namespace} --no-headers -o custom-columns=":metadata.name" -l "app=${CR_NAME}-cmis-deploy")
    if [[ -z "${cmis_deployment_name}" ]]; then
        error "Content Management Interoperability Services has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app=${CR_NAME}-cmis-deploy"    
        resource_health_check "deployment" "${cmis_deployment_name}" "${namespace}"
    fi

    title "Checking Content Services GraphQL status: "
    graphql_deployment_name=$(${CLI_CMD} get deployment -n ${namespace} --no-headers -o custom-columns=":metadata.name" -l "app=${CR_NAME}-graphql-deploy")
    if [[ -z "${graphql_deployment_name}" ]]; then
        error "Content Services GraphQL has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app=${CR_NAME}-graphql-deploy"
        resource_health_check "deployment" "${graphql_deployment_name}" "${namespace}"
    fi

    title "Checking Business Automation Navigator status: "
    navigator_deployment_name=$(${CLI_CMD} get deployment -n ${namespace} --no-headers -o custom-columns=":metadata.name" -l "app=${CR_NAME}-navigator-deploy")
    if [[ -z "${navigator_deployment_name}" ]]; then
        error "Business Automation Navigator has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app=${CR_NAME}-navigator-deploy"
        resource_health_check "deployment" "${navigator_deployment_name}" "${namespace}"
    fi
}

#
# Check UMS status
# pods / deployment
#
function check_ums_status() {
    title "Checking User Management Service (UMS) status: "
    ums_deployment_all=$(${CLI_CMD} get deployments -n ${namespace} --no-headers -o custom-columns=":metadata.name" -l "app.kubernetes.io/component=UMS")
    if [[ -z "${ums_deployment_all}" ]]; then
        error "User Management Service has not been deployed."
    else 
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app.kubernetes.io/component=UMS"

        for ums_deploy in ${ums_deployment_all}; do
            # skip ums-profile deployment
            if [[ ! "${ums_deploy}" == *"ums-profile"* ]]; then
                resource_health_check "deployment" "${ums_deploy}" "${namespace}"
            fi
        done
    fi
}

#
# Check RR status
# pods / jobs
#
function check_rr_status() {
    title "Checking Resource Registry status: "

    rr_server_pod_name=$(${CLI_CMD} get pods -n ${namespace} --no-headers -o custom-columns=":metadata.name" -l "app.kubernetes.io/component=etcd-server")

    if [[ -z "${rr_server_pod_name}" ]]; then
        error "Resource Registry has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app.kubernetes.io/name=resource-registry"

        if [[ -n ${rr_server_pod_name} ]]; then
            for rr_pod in ${rr_server_pod_name[*]}
            do
                rr_pod_ready=$(${CLI_CMD} wait --for=condition=Ready pod/${rr_pod} -n ${namespace} --timeout=0s 2>&1)
                _result=$?

                if [[ $_result -ne 0 ]]; then
                    error "The pod of ${rr_pod} in namespace ${namespace} is not ready."
                else
                    success "The pod of ${rr_pod} in namespace ${namespace} is ready."
                fi
            done
        fi

        rr_setup_pod_name=$(${CLI_CMD} get pods -n ${namespace} --no-headers -l "app.kubernetes.io/component=etcd-setup" -o custom-columns=":metadata.name")
        if [[ -n ${rr_setup_pod_name} ]]; then
            rr_pod_ready=$(${CLI_CMD} wait --for=jsonpath='{.status.phase}'=Succeeded pod/${rr_setup_pod_name} -n ${namespace} --timeout=0s 2>&1)
            _result=$?

            if [[ $_result -ne 0 ]]; then
                error "The pod of ${rr_setup_pod_name} in namespace ${namespace} is not ready."
            else
                success "The pod of ${rr_setup_pod_name} in namespace ${namespace} is ready."
            fi
        fi

        rr_backup_jobs=$(${CLI_CMD} get jobs -n ${namespace} --no-headers -l "app.kubernetes.io/component=etcd-auto-backup" -o custom-columns=":metadata.name")
        if [[ -n ${rr_setup_pod_name} ]]; then
            for job_name in ${rr_backup_jobs}; do
                resource_health_check "job" "${job_name}" "${namespace}"
            done
        fi
    fi
}

#
# Check Application Engine status
# pods / deployments / jobs
#
function check_ae_status() {
    title "Checking Application Engine status: "
    ae_deployment_all=$(${CLI_CMD} get deployments -n ${namespace} --no-headers -o custom-columns=":metadata.name" -l "app.kubernetes.io/name=app-engine")
    if [[ -z "${ae_deployment_all}" ]]; then
        error "Application Engine has not been deployed."
    else 
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app.kubernetes.io/name=app-engine"

        for ae_deploy in ${ae_deployment_all}; do
            resource_health_check "deployment" "${ae_deploy}" "${namespace}"
        done

        ae_jobs=$(${CLI_CMD} get jobs -n ${namespace} --no-headers -l "app.kubernetes.io/name=app-engine" -o custom-columns=":metadata.name")
        for job_name in ${ae_jobs}; do
            resource_health_check "job" "${job_name}" "${namespace}"
        done
    fi
}

#
# Check PFS status
# pods / statefulset / deployment / job
#
function check_pfs_status() {
    title "Checking Process Federation Server (PFS) status: "
    pfs_pod=$(${CLI_CMD} get pods -n ${namespace} --no-headers -l "app.kubernetes.io/component=pfs" -o custom-columns=":metadata.name")
    if [[ -z "${pfs_pod}" ]]; then
        error "Process Federation Server has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app.kubernetes.io/component=pfs"
        
        echo ""
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app.kubernetes.io/component=pfs-registration"

        echo ""
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app.kubernetes.io/component=pfs-umsregistry-job"

        pfs_sts_name=$(${CLI_CMD} get sts -n ${namespace} --no-headers -l "app.kubernetes.io/component=pfs" -o custom-columns=":metadata.name")
        resource_health_check "statefulset" "${pfs_sts_name}" "${namespace}"

        pfs_reg_name=$(${CLI_CMD} get deployment -n ${namespace} --no-headers -l "app.kubernetes.io/component=pfs-registration" -o custom-columns=":metadata.name")
        resource_health_check "deployment" "${pfs_reg_name}" "${namespace}"

        pfs_umsreg_jobs=$(${CLI_CMD} get jobs -n ${namespace} --no-headers -l "app.kubernetes.io/component=pfs-umsregistry-job" -o custom-columns=":metadata.name")
        for job_name in ${pfs_umsreg_jobs}; do
            job_health_check ${job_name} ${namespace}
        done
    fi
}

#
# Check Embedded Elasticsearch status
# pods / statefulset
#
function check_es_status() {
    title "Checking Embedded Elasticsearch status: "
    es_pod=$(${CLI_CMD} get pods -n ${namespace} --no-headers -o custom-columns=":metadata.name" -l "app.kubernetes.io/component=elasticsearch")
    if [[ -z "${es_pod}" ]]; then
        error "Embedded Elasticsearch has not been deployed."
    else
        ${CLI_CMD} get pods -n ${namespace} --label-columns=release -l "app.kubernetes.io/component=elasticsearch"
        es_sts_name=$(${CLI_CMD} get sts -n ${namespace} --no-headers -l "app.kubernetes.io/component=elasticsearch" -o custom-columns=":metadata.name")
        resource_health_check "statefulset" "${es_sts_name}" "${namespace}"
    fi
}

function post_tips() {
    echo ""
    echo ""
    tips ""
    msgB "* Wait to reconcile or check the operator log to see if a component has not been deployed yet."
    msgB "* Check if the status of all pods are either 'running' or 'completed'. The release and expected version should also be the same."
    msgB "* For each pod, check under Events to see that the images were successfully pulled and the containers were created and started, by running the following command with the specific pod name:\n  ${CLI_CMD} describe pod <pod_name> -n ${namespace}"

    cm_access_info="${CR_NAME}-cp4ba-access-info"
    wf_access_info=$(${CLI_CMD} get cm ${cm_access_info} -n ${namespace} --no-headers -o custom-columns=":.data.workflow-server-access-info" >/dev/null 2>&1)
    if [[ $? == 0 ]]; then
        wf_access_info=$(${CLI_CMD} get cm ${cm_access_info} -n ${namespace} --no-headers -o custom-columns=":.data.workflow-server-access-info" 2>&1)
        msgB "* You can access Process Portal, Case Client, and Workplace using the following URLs:\n${wf_access_info}"
        msgB "* You can get more URL access information by visiting the ConfigMap - [${cm_access_info}] in namespace ${namespace} using command like:\n  ${CLI_CMD} get configmap ${cm_access_info} -n ${namespace}"
    fi
}

function printTitle()
{
    echo ""
    echo "${GREEN_TEXT}###############################################################${RESET_TEXT}"
    echo "  ${GREEN_TEXT}${1}"
    echo "###############################################################${RESET_TEXT}"
    echo ""
}


if [[ $1 == "" ]]
then
    usage
    exit -1
else
    while [[ "$1" =~ ^- && ! "$1" == "--" ]]; 
    do case $1 in
        -h | --help )
            usage
            exit
            ;;
        -n | --namespace )
            shift; namespace=$1
            ;;
    esac; shift; done
fi

if [[ "${namespace}" == "" ]]; then
    usage
    exit -1
fi

clear

validate_kube_oc_cli

printTitle "IBM Business Automation Workflow on containers Health Check"
info "Checking from namespace ${namespace}..."

if ${CLI_CMD} get namespace "${namespace}" &> /dev/null; then
    step=1
    CR_NAME=$(${CLI_CMD} get icp4acluster -n ${namespace} | awk 'END {print $1}')

    if [[ -z "${CR_NAME}" ]]; then
        fail "Failed to get your deployment name, skip to check."
    else
        check_operator_status
        check_workflow_server_status
        check_fncm_status
        check_ums_status
        check_rr_status

        post_tips && echo ""
    fi
else
    error "Namespace ${namespace} does not exist, skip to check."
    echo ""
    exit -1
fi

printFooterMessage