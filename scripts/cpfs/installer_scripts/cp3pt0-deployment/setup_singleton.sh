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
ENABLE_LICENSING=0
ENABLE_LICENSE_SERVICE_REPORTER=0
ENABLE_PRIVATE_CATALOG=0
MIGRATE_SINGLETON=0
OPERATOR_NS=""
CONTROL_NS=""
CHANNEL="v4.2"
INSTALL_MODE="Automatic"
CM_SOURCE_NS="openshift-marketplace"
LIS_SOURCE_NS="openshift-marketplace"
LSR_SOURCE_NS="openshift-marketplace"
CERT_MANAGER_SOURCE="ibm-cert-manager-catalog"
LICENSING_SOURCE="ibm-licensing-catalog"
LSR_SOURCE="ibm-license-service-reporter-bundle-catalog"
CERT_MANAGER_NAMESPACE="ibm-cert-manager"
LICENSING_NAMESPACE="ibm-licensing"
LSR_NAMESPACE="ibm-lsr"
LICENSE_ACCEPT=0
PREVIEW_MODE=0
DEBUG=0

CHECK_CERT_MANAGER=0
CUSTOMIZED_CM_NAMESPACE=0
CUSTOMIZED_LSR_NAMESPACE=0
CUSTOMIZED_LICENSING_NAMESPACE=0
CERT_MANAGER_V1_OWNER="operator.ibm.com/v1"
CERT_MANAGER_V1ALPHA1_OWNER="operator.ibm.com/v1alpha1"

# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# log file
LOG_FILE="setup_singleton_log_$(date +'%Y%m%d%H%M%S').log"

# preview mode directory
PREVIEW_DIR="/tmp/setup-singleton-$(date +'%Y%m%d%H%M%S')-preview"

# counter to keep track of installation steps
STEP=0

# ---------- Main functions ----------

. ${BASE_DIR}/common/utils.sh

function main() {
    parse_arguments "$@"
    save_log "logs" "setup_singleton_log" "$DEBUG"
    trap cleanup_log EXIT
    pre_req
    prepare_preview_mode
    cert_manager_deployment_check

    is_migrate_licensing
    is_migrate_cert_manager
    if [ $MIGRATE_SINGLETON -eq 1 ]; then
        if [ $ENABLE_LICENSING -eq 1 ]; then
            if [ $ENABLE_LICENSE_SERVICE_REPORTER -eq 1 ]; then
                ${BASE_DIR}/common/migrate_singleton.sh "--operator-namespace" "$OPERATOR_NS" "--control-namespace" "$CONTROL_NS" "--enable-licensing" "--licensing-namespace" "$LICENSING_NAMESPACE" "--enable-license-service-reporter" "--lsr-namespace" "$LSR_NAMESPACE" "-v" "$DEBUG" "--yq" "$YQ" "--oc" "$OC"
            else
                ${BASE_DIR}/common/migrate_singleton.sh "--operator-namespace" "$OPERATOR_NS" "--control-namespace" "$CONTROL_NS" "--enable-licensing" "--licensing-namespace" "$LICENSING_NAMESPACE" "-v" "$DEBUG" "--yq" "$YQ" "--oc" "$OC"
            fi
        else
            ${BASE_DIR}/common/migrate_singleton.sh "--operator-namespace" "$OPERATOR_NS" "--control-namespace" "$CONTROL_NS" "-v" "$DEBUG" "--yq" "$YQ" "--oc" "$OC"
        fi
    fi

    install_cert_manager
    install_licensing
    verify_cert_manager
    install_license_service_reporter
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
        -ls | --enable-licensing)
            ENABLE_LICENSING=1
            ;;
        -lsr | --enable-license-service-reporter)
            ENABLE_LICENSE_SERVICE_REPORTER=1
            ;;
        --enable-private-catalog)
            ENABLE_PRIVATE_CATALOG=1
            ;;
        --cert-manager-source)
            shift
            CERT_MANAGER_SOURCE=$1
            ;;
        --licensing-source)
            shift
            LICENSING_SOURCE=$1
            ;;
        --lsr-source)
            shift
            LSR_SOURCE=$1
            ;;
        --license-accept)
            LICENSE_ACCEPT=1
            ;;
        -cmNs | --cert-manager-namespace)
            shift
            CERT_MANAGER_NAMESPACE=$1
            CUSTOMIZED_CM_NAMESPACE=1
            ;;
        -licensingNs | --licensing-namespace)
            shift
            LICENSING_NAMESPACE=$1
            CUSTOMIZED_LICENSING_NAMESPACE=1
            ;;
        -lsrNs | --license-service-reporter-namespace)
            shift
            LSR_NAMESPACE=$1
            CUSTOMIZED_LSR_NAMESPACE=1
            ;;
        --check-cert-manager)
            CHECK_CERT_MANAGER=1
            ;;
        --preview)
            PREVIEW_MODE=1
            ;;
        -c | --channel)
            shift
            CHANNEL=$1
            ;;
        -i | --install-mode)
            shift
            INSTALL_MODE=$1
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
    echo "Usage: ${script_name} --license-accept [OPTIONS]..."
    echo ""
    echo "Install Cloud Pak 3 pre-reqs if they do not already exist: ibm-cert-manager-operator and optionally ibm-licensing-operator"
    echo "The ibm-cert-manager-operator will be installed in namespace ibm-cert-manager"
    echo "The ibm-licensing-operator will be installed in namespace ibm-licensing"
    echo "The --license-accept must be provided."
    echo "See https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.0?topic=manager-installing-cert-licensing-by-script for more information."
    echo ""
    echo "Options:"
    echo "   --oc string                                            Optional. File path to oc CLI. Default uses oc in your PATH"
    echo "   --yq string                                            Optional. File path to yq CLI. Default uses yq in your PATH"
    echo "   --operator-namespace string                            Optional. Namespace to migrate Cloud Pak 2 Foundational services"
    echo "   -ls, --enable-licensing                                Optional. Set this flag to install ibm-licensing-operator"
    echo "   -licensingNs, --licensing-namespace string             Optional. Set custom namespace for ibm-licensing-operator. Default is ibm-licensing"
    echo "   -lsr, --enable-license-service-reporter                Optional. Set this flag to install ibm-license-service-reporter-operator. Always use with -ls(--enable-licensing) flag"
    echo "   -lsrNs, --license-service-reporter-namespace string    Optional. Set custom namespace for License Service Reporter. Default is ibm-lsr"
    echo "   --enable-private-catalog                               Optional. Set this flag to use namespace scoped CatalogSource. Default is in openshift-marketplace namespace"
    echo "   --cert-manager-source string                           Optional. CatalogSource name of ibm-cert-manager-operator. This assumes your CatalogSource is already created. Default is ibm-cert-manager-catalog"
    echo "   --licensing-source string                              Optional. CatalogSource name of ibm-licensing. This assumes your CatalogSource is already created. Default is ibm-licensing-catalog"
    echo "   --lsr-source string                                    Optional. CatalogSource name of ibm-license-service-reporter. This assumes your CatalogSource is already created. Default is ibm-license-service-reporter-bundle-catalog"
    echo "   -cmNs, --cert-manager-namespace string                 Optional. Set custom namespace for ibm-cert-manager-operator. Default is ibm-cert-manager"
    echo "   --license-accept                                       Required. Set this flag to accept the license agreement."
    echo "   --preview                                              Optional.  Enable preview mode (dry run)"
    echo "   -c, --channel string                                   Optional. Channel for Subscription(s). Default is v4.2"
    echo "   -i, --install-mode string                              Optional. InstallPlan Approval Mode. Default is Automatic. Set to Manual for manual approval mode"
    echo "   -v, --debug integer                                    Optional. Verbosity of logs. Default is 0. Set to 1 for debug logs"
    echo "   -h, --help                                             Print usage information"
    echo ""
}

function is_migrate_cert_manager() {
    title "Check migrating and deactivating LTSR ibm-cert-manager-operator"
    local webhook_ns=$("$OC" get deployments -A | grep cert-manager-webhook | cut -d ' ' -f1)
    if [ -z "$webhook_ns" ]; then
        info "No cert-manager-webhook found, skipping migration"
        return 0
    fi
    local api_version=$("$OC" get deployments -n "$webhook_ns" cert-manager-webhook -o jsonpath='{.metadata.ownerReferences[*].apiVersion}')
    if [ "$api_version" != "$CERT_MANAGER_V1ALPHA1_OWNER" ]; then
        info "LTSR ibm-cert-manager-operator already deactivated, skipping"
        return 0
    fi
    MIGRATE_SINGLETON=1
    get_and_validate_arguments
}

function is_migrate_licensing() {
    if [ $ENABLE_LICENSING -ne 1 ]; then
        return
    fi

    title "Check migrating LTSR ibm-licensing-operator"
    # wait for ibm-licensing-operator instance 
    local licensing_operator_exist=$("$OC" get deployment -A | (grep ibm-licensing-operator || echo "fail"))  
    if [[ $licensing_operator_exist != "fail" ]]; then
        wait_for_licensing_instance_deployment
    else
        info "No LTSR ibm-licensing-operator to migrate, skipping"
        return 0
    fi

    local licensing_service_count=$("$OC" get deployments -A | grep ibm-licensing-service-instance | wc -l)
    # If multiple Licensing service deployment is found, it should error out
    if [ "$licensing_service_count" -ge 2 ]; then
        error "More than one ibm-licensing-service-instance found in namespace: $ns. There should be only one ibm-licensing-service-instance each cluster."
    fi

    local version=$("$OC" get ibmlicensings.operator.ibm.com instance -o jsonpath='{.spec.version}' --ignore-not-found)
    if [ -z "$version" ]; then
        warning "No version field in ibmlicensing CR, skipping"
        return 0
    fi
    local major=$(echo "$version" | cut -d '.' -f1)
    if [ "$major" -ge 4 ]; then
        info "There is no LTSR ibm-licensing-operator to migrate, skipping"
        if [[ "$CUSTOMIZED_LICENSING_NAMESPACE" -eq 1 ]] && [[ "$ns" != "$LICENSING_NAMESPACE" ]]; then
            error "An ibm-licensing-operator already installed in namespace: $ns, please do not set parameter '-licensingNs $LICENSING_NAMESPACE"
        fi
        LICENSING_NAMESPACE="$ns"
        if [[ $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
            LIS_SOURCE_NS="$ns" 
        fi
        return 0
    fi

    local lsr_ns=$("$OC" get deployments -A | grep ibm-license-service-reporter-operator | cut -d ' ' -f1)
    if [ ! -z "$lsr_ns" ]; then
        if [[ "$CUSTOMIZED_LSR_NAMESPACE" -eq 1 ]] && [[ "$lsr_ns" != "$LSR_NAMESPACE" ]]; then
            error "An ibm-license-service-reporter-operator already installed in namespace: $lsr_ns, expected namespace is: $LSR_NAMESPACE"
        fi
        LSR_NAMESPACE="$lsr_ns"
        if [[ $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
            LSR_SOURCE_NS="$lsr_ns" 
        fi
    fi

    get_and_validate_arguments
    MIGRATE_SINGLETON=1
    if [ -z "$CONTROL_NS" ]; then
        return 0
    fi

    if [[ "$CUSTOMIZED_LICENSING_NAMESPACE" -eq 1 ]] && [[ "$CONTROL_NS" != "$LICENSING_NAMESPACE" ]]; then
        error "Licensing Migration could only be done in $CONTROL_NS, please do not set parameter '-licensingNs $LICENSING_NAMESPACE'"
    fi

    LICENSING_NAMESPACE="$CONTROL_NS"
    if [[ $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
        LIS_SOURCE_NS="$ns" 
    fi
}

function cert_manager_deployment_check(){
    if [ $CHECK_CERT_MANAGER -eq 0 ]; then
        return
    fi

    title "Chekcing cert-manager type"
    local webhook_ns=$("$OC" get deployments -A | grep cert-manager-webhook | cut -d ' ' -f1 ) 

    local api_version=""
    local cm_namespace=""
    
    # loop through all namespaces if multiple cert-manager-webhook found
    # Detect owner and namespace (only need to find one owned by IBM)
    for ns in $webhook_ns; do 
        api_version=$("$OC" get deployments -n "$ns" cert-manager-webhook -o jsonpath='{.metadata.ownerReferences[*].apiVersion}' --ignore-not-found)
        cm_namespace="$ns"
        if [ ! -z "$api_version" ]; then
            if [ "$api_version" == "$CERT_MANAGER_V1_OWNER" ] || [ "$api_version" == "$CERT_MANAGER_V1ALPHA1_OWNER" ]; then
                echo "Found ibm-cert-manager-operator owned cert-manager-webhook in namespace: $ns"
                break
            fi
        fi
    done

    # If we found a cert-manager-webhook namespace
    if [[ ! -z "$cm_namespace" ]]; then

        # Run smoke test
        if cm_smoke_test "test-issuer" "test-certificate" "test-certificate-secret" "$cm_namespace"; then

            if [[ -n "$api_version" ]]; then
                info "Cluster has an ibm-cert-manager-operator already installed."
                exit 1
            fi

            info "Cluster has a third-party cert-manager already installed."
            exit 2
        fi
    fi

    info "There is no functional cert-manager-webhook pod running\n"
    exit 0
    
}

function install_cert_manager() {

    title "Installing cert-manager\n"
    is_sub_exist "cert-manager" # this will catch the packagenames of all cert-manager-operators
    if [ $? -eq 0 ]; then
        warning "There is a cert-manager Subscription already\n"
    fi

    local webhook_ns=$("$OC" get deployments -A | grep cert-manager-webhook | cut -d ' ' -f1 | tr '\n' ' ')
    local webhook_count=$("$OC" get deployments -A | grep cert-manager-webhook | wc -l)
    
    if [ -z "$webhook_ns" ]; then

        info "There is no cert-manager-webhook pod running; proceeding with installation"
    
    else

        warning "There is a cert-manager-webhook pod running; another cert-manager is likely installed"
        info "Continue to upgrade check"

        local api_version=""
        local cm_namespace=""

        # Try to detect owner apiVersion
        # Loop through all namespaces if multiple cert-manager-webhook found, and look for ibm-cert-manager-operator
        for ns in $webhook_ns; do
            api_version=$("$OC" get deployment -n "$ns" cert-manager-webhook -o jsonpath='{.metadata.ownerReferences[*].apiVersion}' --ignore-not-found)
            cm_namespace="$ns"
            if [ ! -z "$api_version" ]; then
                if [ "$api_version" == "$CERT_MANAGER_V1_OWNER" ] || [ "$api_version" == "$CERT_MANAGER_V1ALPHA1_OWNER" ]; then
                    echo "Found ibm-cert-manager-operator owned cert-manager-webhook in namespace: $ns"
                    break
                fi
            fi
        done

        # Run smoke test
        if cm_smoke_test "test-issuer" "test-certificate" "test-certificate-secret" $cm_namespace; then

            # Check owner type
            if [ -z "$api_version" ]; then
                warning "Cluster has a RedHat or Helm cert-manager, skipping"
                return 0
            fi

            # LTSR operator case
            if [ "$api_version" == "$CERT_MANAGER_V1ALPHA1_OWNER" ]; then
                error "Cluster has not deactivated LTSR ibm-cert-manager-operator yet, please re-run this script"
            fi

            # Non-IBM cert-manager
            if [ "$api_version" != "$CERT_MANAGER_V1_OWNER" ]; then
                warning "Cluster has a non ibm-cert-manager-operator already installed, skipping"
                return 0
            fi

            # IBM cert-manager upgrade logic
            info "Upgrading ibm-cert-manager-operator to channel: $CHANNEL"

            if [[ "$cm_namespace" != "$CERT_MANAGER_NAMESPACE" && "$CUSTOMIZED_CM_NAMESPACE" -eq 1 ]]; then
                error "An ibm-cert-manager-operator is already installed in namespace: $cm_namespace; do not set -cmNs $CERT_MANAGER_NAMESPACE"
            fi

            CERT_MANAGER_NAMESPACE="$cm_namespace"

            if [[ $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
                CM_SOURCE_NS="$cm_namespace"
            fi

        else
            # Smoke test failed
            if [ "$webhook_count" -eq 1 ]; then
                info "The existing cert-manager-webhook pod is not functional, proceeding with installation"
            else
                error "Multiple cert-manager-webhook pods found and all are functional; cannot proceed"
            fi
        fi
    fi

    # Validate the CatalogSource of IBM Cert Manager before proceeding with the installation or upgrade
    validate_operator_catalogsource ibm-cert-manager-operator $CERT_MANAGER_NAMESPACE $CERT_MANAGER_SOURCE $CM_SOURCE_NS $CHANNEL CERT_MANAGER_SOURCE CM_SOURCE_NS 

    create_namespace "${CERT_MANAGER_NAMESPACE}"
    create_operator_group "ibm-cert-manager-operator" "${CERT_MANAGER_NAMESPACE}" "{}"
    is_sub_exist "ibm-cert-manager-operator" "${CERT_MANAGER_NAMESPACE}" # this will catch the packagenames of all cert-manager-operators
    if [ $? -eq 0 ]; then
        update_operator "ibm-cert-manager-operator" "${CERT_MANAGER_NAMESPACE}" "$CHANNEL" "${CERT_MANAGER_SOURCE}" "${CM_SOURCE_NS}" "${INSTALL_MODE}"
        wait_for_operator_upgrade "${CERT_MANAGER_NAMESPACE}" "ibm-cert-manager-operator" "$CHANNEL" "${INSTALL_MODE}"
    else
        create_subscription "ibm-cert-manager-operator" "${CERT_MANAGER_NAMESPACE}" "$CHANNEL" "ibm-cert-manager-operator" "${CERT_MANAGER_SOURCE}" "${CM_SOURCE_NS}" "${INSTALL_MODE}"
    fi
    wait_for_csv "${CERT_MANAGER_NAMESPACE}" "ibm-cert-manager-operator"
    wait_for_operator "${CERT_MANAGER_NAMESPACE}" "ibm-cert-manager-operator"
    accept_license "certmanagerconfig.operator.ibm.com" "" "default"
}

function install_licensing() {
    if [ $ENABLE_LICENSING -ne 1 ]; then
        return
    fi

    validate_operator_catalogsource ibm-licensing-operator-app $LICENSING_NAMESPACE $LICENSING_SOURCE $LIS_SOURCE_NS $CHANNEL LICENSING_SOURCE LIS_SOURCE_NS
    if [ $ENABLE_LICENSE_SERVICE_REPORTER -eq 1 ]; then
        validate_operator_catalogsource ibm-license-service-reporter-operator $LSR_NAMESPACE $LSR_SOURCE $LSR_SOURCE_NS $CHANNEL LSR_SOURCE LSR_SOURCE_NS
    fi

    title "Installing licensing\n"
    is_sub_exist "ibm-licensing-operator-app" # this will catch the packagenames of all ibm-licensing-operator-app
    if [ $? -eq 0 ]; then
        warning "There is an ibm-licensing-operator-app Subscription already, so will upgrade it\n"
    else
        info "There is no ibm-licensing-operator-app Subscription installed\n"
    fi

    local ns=$("$OC" get deployments -A | grep ibm-licensing-service-instance | cut -d ' ' -f1)
    if [ ! -z "$ns" ]; then
        if [ "$ns" != "$LICENSING_NAMESPACE" ]; then
            error "An ibm-licensing-operator already installed in namespace: $ns, expected namespace is: $LICENSING_NAMESPACE"
        fi
    fi

    create_namespace "${LICENSING_NAMESPACE}"

    target=$(cat <<EOF
        
  targetNamespaces:
    - ${LICENSING_NAMESPACE}
EOF
)
    create_operator_group "ibm-licensing-operator-app" "${LICENSING_NAMESPACE}" "$target"
    is_sub_exist "ibm-licensing-operator-app" # this will catch the packagenames of all ibm-licensing-operator-app
    if [ $? -eq 0 ]; then
        update_operator "ibm-licensing-operator-app" "${LICENSING_NAMESPACE}" "$CHANNEL" "${LICENSING_SOURCE}" "${LIS_SOURCE_NS}" "${INSTALL_MODE}" "remove_opreq_label"
        wait_for_operator_upgrade "${LICENSING_NAMESPACE}" "ibm-licensing-operator-app" "$CHANNEL" "${INSTALL_MODE}"
    else
        create_subscription "ibm-licensing-operator-app" "${LICENSING_NAMESPACE}" "$CHANNEL" "ibm-licensing-operator-app" "${LICENSING_SOURCE}" "${LIS_SOURCE_NS}" "${INSTALL_MODE}"
    fi
    wait_for_csv "${LICENSING_NAMESPACE}" "ibm-licensing-operator-app"
    wait_for_operator "${LICENSING_NAMESPACE}" "ibm-licensing-operator"
    wait_for_license_instance
    accept_license "ibmlicensing" "" "instance"
}

function wait_for_license_instance() {
    local name="instance"
    local condition="${OC} get ibmlicensing -A --no-headers --ignore-not-found | grep ${name} || true"
    local retries=20
    local sleep_time=15
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for ibmlicensing ${name} to be present."
    local success_message="ibmlicensing ${name} present"
    local error_message="Timeout after ${total_time_mins} minutes waiting for ibmlicensing ${name} to be present."
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function install_license_service_reporter() {
    if [ $ENABLE_LICENSE_SERVICE_REPORTER -ne 1 ] ; then
        return
    fi

    title "Installing License Service Reporter\n"
    is_sub_exist "ibm-license-service-reporter-operator" # this will catch the package names of all ibm-license-service-reporter-operator
    if [ $? -eq 0 ]; then
        warning "There is an ibm-license-service-reporter-operator Subscription already, so will upgrade it\n"
    else
        info "There is no ibm-license-service-reporter-operator Subscription installed\n"
    fi

    local ns=$("$OC" get deployments -A | grep ibm-license-service-reporter-operator | cut -d ' ' -f1)
    if [ ! -z "$ns" ]; then
        if [ "$ns" != "$LSR_NAMESPACE" ]; then
            error "An ibm-license-service-reporter-operator already installed in namespace: $ns, expected namespace is: $LSR_NAMESPACE"
        fi
    fi

    create_namespace "${LSR_NAMESPACE}"

    target=$(cat <<EOF

  targetNamespaces:
    - ${LSR_NAMESPACE}
EOF
    )
    create_operator_group "ibm-license-service-reporter-operator" "${LSR_NAMESPACE}" "$target"
    
    is_sub_exist "ibm-license-service-reporter-operator" # this will catch the package names of all ibm-license-service-reporter-operator
    if [ $? -eq 0 ]; then
        update_operator "ibm-license-service-reporter-operator" "${LSR_NAMESPACE}" "$CHANNEL" "${LSR_SOURCE}" "${LSR_SOURCE_NS}" "${INSTALL_MODE}"
        wait_for_operator_upgrade "${LSR_NAMESPACE}" "ibm-license-service-reporter-operator" "$CHANNEL" "${INSTALL_MODE}"
    else
        create_subscription "ibm-license-service-reporter-operator" "${LSR_NAMESPACE}" "$CHANNEL" "ibm-license-service-reporter-operator" "${LSR_SOURCE}" "${LSR_SOURCE_NS}" "${INSTALL_MODE}"
    fi
    wait_for_csv "${LSR_NAMESPACE}" "ibm-license-service-reporter-operator"
    wait_for_operator "${LSR_NAMESPACE}" "ibm-license-service-reporter-operator"

    configure_lsr_instance
    wait_for_lsr_instance
    accept_license "ibmlicenseservicereporter" "$LSR_NAMESPACE" "$LSR_CR_NAME"
}


function configure_lsr_instance() {
    # Initialize LSR_CR_NAME only if it's unset or null
    LSR_CR_NAME="${LSR_CR_NAME:-}"

    title "Configuring License Service Reporter CR in $LSR_NAMESPACE..."
    # checking LSR_CR_NAME 
    if [ -z "${LSR_CR_NAME}" ]; then
        LSR_CR_NAME="ibm-lsr-instance"
    fi
    count=$("${OC}" get ibmlicenseservicereporter -n ${LSR_NAMESPACE} --no-headers | wc -l)
    if [[ "$count" -eq 1 ]]; then
        info "Configure License Service Reporter CR in $LSR_NAMESPACE\n"
        LSR_CR_NAME=$("${OC}" get ibmlicenseservicereporter -n ${LSR_NAMESPACE} --no-headers | awk '{print $1}')
        ${OC} get ibmlicenseservicereporter ${LSR_CR_NAME} -n ${LSR_NAMESPACE} -o yaml | ${YQ} eval '.spec.authentication.useradmin.enabled = true' > ${PREVIEW_DIR}/licensing_service_reporter.yaml
        ${YQ} -i eval 'select(.kind == "IBMLicenseServiceReporter") | del(.metadata.resourceVersion) | del(.metadata.uid) | del(.metadata.creationTimestamp) | del(.metadata.generation)' ${PREVIEW_DIR}/licensing_service_reporter.yaml
    elif  [[ "$count" -eq 0 ]]; then 
        info "Creating the IBM License Service Reporter object:\n"
        cat <<EOF > ${PREVIEW_DIR}/licensing_service_reporter.yaml
apiVersion: operator.ibm.com/v1alpha1
kind: IBMLicenseServiceReporter
metadata:
  name: ${LSR_CR_NAME}
  namespace: ${LSR_NAMESPACE}
  labels:
    app.kubernetes.io/created-by: ibm-license-service-reporter-operator
    app.kubernetes.io/instance: ibmlicenseservicereporter-instance
    app.kubernetes.io/name: ibmlicenseservicereporter
    app.kubernetes.io/part-of: ibm-license-service-reporter-operator
spec:
  license:
    accept: true
  authentication:
    useradmin:
      enabled: true
EOF
    else
        error "More than one IBMLicenseServiceReporter instances found in namespace: ${LSR_NAMESPACE}."
    fi

    cat ${PREVIEW_DIR}/licensing_service_reporter.yaml
    echo ""
    
    cat "${PREVIEW_DIR}/licensing_service_reporter.yaml" | ${OC} apply -f -

}

function wait_for_lsr_instance() {
    local condition="${OC} get IBMLicenseServiceReporter -A --no-headers --ignore-not-found | grep ${LSR_CR_NAME} || true"
    local retries=20
    local sleep_time=15
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for IBMLicenseServiceReporter ${LSR_CR_NAME} to be present."
    local success_message="IBMLicenseServiceReporter ${LSR_CR_NAME} present"
    local error_message="Timeout after ${total_time_mins} minutes waiting for IBMLicenseServiceReporter ${LSR_CR_NAME} to be present."
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
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

    if [ "$LICENSE_ACCEPT" -ne 1 ]; then
        error "License not accepted. Rerun script with --license-accept flag set. See https://ibm.biz/integration-licenses for more details"
    fi

    # Check INSTALL_MODE
    if [[ "$INSTALL_MODE" != "Automatic" && "$INSTALL_MODE" != "Manual" ]]; then
        error "Invalid INSTALL_MODE: $INSTALL_MODE, allowed values are 'Automatic' or 'Manual'"
    fi
    
    # Check if channel is semantic vx.y
    if [[ $CHANNEL =~ ^v[0-9]+\.[0-9]+$ ]]; then
        # Check if channel is equal or greater than v4.0
        if [[ $CHANNEL == v[4-9].* || $CHANNEL == v[4-9] ]]; then  
            success "Channel $CHANNEL is valid"
        else
            error "Channel $CHANNEL is less than v4.0"
        fi
    elif [[ $CHANNEL == "null" ]]; then
        warning "Channel is not set, default channel from operator bundle will be used"
    else
        error "Channel $CHANNEL is not semantic vx.y"
    fi

    # Check if all CS installations are above 3.19.9
    local csvs=$("$OC" get csv -A | grep ibm-common-service-operator | awk '{print $2}' | sort -V)
    local version=$(echo "$csvs" | head -n 1 | cut -d '.' -f2-)
    is_supports_delegation "$version"

    if [ -z "$OPERATOR_NS" ]; then
        OPERATOR_NS=$("$OC" project --short)
    fi

    if [ $ENABLE_LICENSE_SERVICE_REPORTER -eq 1 ] && [ $ENABLE_LICENSING -eq 0 ]; then
        error "IBM License Service Report is enabled, but IBM Licensing is not enabled. Please always use -ls(--enable-licensing) flag with -lsr(--enable-license-service-reporter) flag"
    fi

    # Using private catalog
    if [[ $ENABLE_PRIVATE_CATALOG -eq 1 ]]; then
        warning "Flag --enable-private-catalog is enabled, please make sure the CatalogSource is deployed in the same namespace as operator"
        CM_SOURCE_NS="${CERT_MANAGER_NAMESPACE}"
        LIS_SOURCE_NS="${LICENSING_NAMESPACE}"
        LSR_SOURCE_NS="${LSR_NAMESPACE}"
    fi

    echo ""
}

# TODO validate argument
function get_and_validate_arguments() {
    get_control_namespace

    if [ ! -z "$CONTROL_NS" ]; then
        return 0
    fi

    local is_all_ns=$(${OC} get -n openshift-operators deployment ibm-common-service-operator)

    if [ ! -z "$is_all_ns" ]; then
        return 0
    fi

    local cm="$(
        cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: "common-service-maps"
  namespace: kube-public
data:
  common-service-maps.yaml: |
    controlNamespace: cs-control
EOF
)"
    create_namespace "cs-control"

    echo "$cm" | ${OC} apply -f -

    get_control_namespace
}

function verify_cert_manager(){
    info "Checking cert manager readiness."
    #check webhook pod runnning
    local name="cert-manager-webhook"
    local retries=20
    local sleep_time=15
    local total_time_mins=$(( sleep_time * retries / 60))
    local condition="${OC} get pod -A --no-headers --ignore-not-found | egrep '1/1' | grep ${name} || true"
    local wait_message="Waiting for pod ${name} to be running ..."
    local success_message="Pod ${name} is running."
    local error_message="Timeout after ${total_time_mins} minutes waiting for pod ${name} to be running."
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"

    #check no duplicate webhook pod
    webhook_deployments=$(${OC} get deploy -A --no-headers --ignore-not-found | grep ${name} -c)
    if [[ $webhook_deployments -gt 1 ]]; then
        warning "More than one cert-manager-webhook deployment exists on the cluster. Checking cert-manager functionality."
        local webhook_ns=$("$OC" get deployments -A | grep cert-manager-webhook | cut -d ' ' -f1)
        if cm_smoke_test "test-issuer" "test-certificate" "test-certificate-secret" $webhook_ns; then
            info "Smoke test passed. Only one Cert Manager is managing the certificate in the cluster."
        else
            error "Smoke test failed. More than one Cert Manager is managing the certificate in the cluster."
        fi
    fi
    
    success "Cert manager is ready."
}

main "$@"
