#!/usr/bin/env bash
#
# Copyright 2024 IBM Corporation
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

set -o pipefail
set -o errtrace

OUTPUT_FILE="env-oadp.properties"
WRITE="false"
RESTORE_SINGLETONS="false"
BACKUP_CLU_USERNAME="kubeadmin"
RESTORE_CLU_USERNAME="kubeadmin"
DEBUG=1

BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)
. ../cp3pt0-deployment/common/utils.sh
PREVIEW_DIR=${BASE_DIR}

function main() {
    parse_arguments "$@"
    prereq
    if [[ $SETUP_BACKUP == "true" ]]; then
        #checks for an existing oadp on the cluster then installs if cannot find one
        check_for_oadp
    fi
    if [[ $SETUP_RESTORE == "true" ]] && [[ $TARGET_CLUSTER_TYPE == "diff" ]]; then
        login $RESTORE_CLU_SERVER $RESTORE_CLU_USERNAME $RESTORE_CLU_PASSWORD
        check_for_oadp
        login $BACKUP_CLU_SERVER $BACKUP_CLU_USERNAME $BACKUP_CLU_PASSWORD
    else
        check_for_oadp
    fi
    if [[ $BACKUP == "true" ]]; then
       backup_setup
       create_backup
       verify_backup_complete 
    fi
    if [[ $RESTORE == "true" ]]; then
        if [[ $TARGET_CLUSTER_TYPE == "diff" ]]; then
            login $RESTORE_CLU_SERVER $RESTORE_CLU_USERNAME $RESTORE_CLU_PASSWORD
            if [[ $BACKUP == "true" ]]; then
                #in full e2e BR scenarios where we are restoring to a different cluster
                #it takes a few minutes for the backup to be present on the new cluster once completed
                wait_for_backup
            elif [[ $SETUP_RESTORE == "true" ]]; then
                #in scenario where backup was already run but the restore needs to be setup and then the restore needs to run
                #the restore runs before the setup completes and the backup is not present so we need to wait until we can see the backup on the restore cluster
                wait_for_backup
            fi
        fi
        restore_cpfs
        if [[ $TARGET_CLUSTER_TYPE == "diff" ]]; then
            login $BACKUP_CLU_SERVER $BACKUP_CLU_USERNAME $BACKUP_CLU_PASSWORD
        fi
    fi
}

function print_usage(){
    script_name=`basename ${0}`
    echo "Usage: ${script_name} [OPTIONS]"
    echo ""
    echo "Automate running OADP/Velero Backup or Restore."
    echo "One of --backup or --restore is required."
    echo "This script assumes the following:"
    echo "    * At least a Fusion Hub cluster setup with Fusion Backup and Restore Service and CPFS installed."
    echo "    * If 'spoke' selected for --cluster-type, Fusion Backup and Restore Agent Service installed and matching Storageclass to Hub cluster."
    echo "    * Fusion setup was completed with the fusion-backup-setup.sh script"
    echo ""
    echo "Options:"
    echo "   --oc string                    Optional. File path to oc CLI. Default uses oc in your PATH. Can also be set in env.properties."
    echo "   --yq string                    Optional. File path to yq CLI. Default uses yq in your PATH. Can also be set in env.properties."
    echo "   --backup                       Optional. Enable backup mode, it will trigger a backup job."
    echo "   --backup-name                  Necessary. Name of backup. A unique name is required when --backup is enabled. An existing name is required when --restore is enabled"
    echo "   --restore                      Optional. Enable restore mode, it will trigger a restore job."
    echo "   --env-file                     Optional. Enter env var file to populate necessary parameters. Default file name is env-oadp.properties."
    echo "   --write-env-file               Optional. Write set of env variables to specified output file. If --env-file not specified, defaults to env-oadp.properties. File must already exist."
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
        --yq)
            shift
            YQ=$1
            ;;
        --backup)
            BACKUP="true"
            ;;
        --backup-name)
            shift
            BACKUP_NAME=$1
            ;;
        --restore)
            RESTORE="true"
            ;;
        --env-file)
            shift
            OUTPUT_FILE=$1
            source ${BASE_DIR}/$OUTPUT_FILE
            ;;

        --write-env-file)
            WRITE="true"
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

function prereq() {
    #check that oc and yq are available
    check_command "${OC}"
    check_command "${YQ}"
    # Check yq version
    check_yq

    # Checking oc command logged in
    user=$(${OC} whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        error "You must be logged into the OpenShift Cluster from the oc command line"
    else
        success "oc command logged in as ${user}"
    fi
    
    #this value always needs to be present so always going to check it
    if [[ $OADP_NS == "" ]]; then
        error "OADP_NS name not specified. Make sure it is either set in the parameters file or as an env variable."
    fi

    #check variables are present
    # check backup/restore name
    if [[ $BACKUP == "true" ]]; then
        if [[ $BACKUP_NAME == "" ]]; then
            error "Backup name is necessary if Backup is enabled"
        fi
    fi
    if [[ $RESTORE == "true" ]]; then
        if [[ $BACKUP_NAME == "" ]]; then
            error "An existing backup's name must be specified with --backup-name if Restore is enabled."
        fi
        if [[ $OPERATOR_NS == "" ]]; then
            error "OPERATOR_NS value not set. Make sure it is either set in the parameters file or as an env variable."
        elif [[ $SERVICES_NS == "" ]]; then
            warning "SERVICES_NS value not set. Setting value equal to OPERATOR_NS value $OPERATOR_NS."
            SERVICES_NS=$OPERATOR_NS
        fi
        
        # check if any singleton is enabled individually and then check namespace values for each one
        #if any singleton enabled, trigger singleton enabled var
        if [[ $ENABLE_CERT_MANAGER == "true" ]]; then
            RESTORE_SINGLETONS="true"
            if [[ $CERT_MANAGER_NAMESPACE == "" ]]; then
                warning "Cert manager namespace not specified, setting to default ibm-cert-manager"
                CERT_MANAGER_NAMESPACE="ibm-cert-manager"
            fi
        fi
        if [[ $ENABLE_LICENSING == "true" ]]; then
            RESTORE_SINGLETONS="true"
            if [[ $LICENSING_NAMESPACE == "" ]]; then
                warning "Licensing namespace not specified, setting to default ibm-licensing"
                LICENSING_NAMESPACE="ibm-licensing"
            fi
        fi
        if [[ $ENABLE_LSR == "true" ]]; then
            RESTORE_SINGLETONS="true"
            if [[ $LSR_NAMESPACE == "" ]]; then
                warning "License service reporter namespace not specified, setting to default ibm-ls-reporter"
                LSR_NAMESPACE="ibm-licensing"
            fi
        fi

        #if zen enabled, verify zen namespace and zenservice name are both present
        if [[ $ZEN_ENABLED == "true" ]]; then
            if [[ $ZEN_NAMESPACE == "" ]]; then
                error "ZEN_NAMESPACE value not set. Make sure it is either set in the parameters file or as an env variable."
            fi
            if [[ $ZENSERVICE_NAME == "" ]]; then
                error "ZENSERVICE_NAME value not set. Make sure it is either set in the parameters file or as an env variable."
            fi
        fi
    fi
    if [[ $BACKUP != "true" ]] && [[ $RESTORE != "true" ]] && [[ $SETUP_BACKUP != "true" ]] && [[ $SETUP_RESTORE != "true" ]]; then
        error "Neither Backup, Restore, or setup options were specified. Please select at least one before rerunning."
    fi
    
    #OADP setup checks
    if [[ $BACKUP_SETUP == "true" ]] || [[ $RESTORE_SETUP == "true" ]]; then
        if [[ $BACKUP_STORAGE_LOCATION_NAME == "" ]]; then
            error "Backup Storage Location name not specified. It should be in the format \"<DPA_NAME>-1\". Make sure it is either set in the parameters file or as an env variable."
        fi
        if [[ $DPA_NAME == "" ]]; then
            error "DPA_NAME (dataprotectionapplication name) not specified. Make sure it is either set in the parameters file or as an env variable."
        fi
        if [[ $BUCKET_REGION == "" ]]; then
            error "BUCKET_REGION not specified. Make sure it is either set in the parameters file or as an env variable."
        fi
        if [[ $STORAGE_BUCKET_NAME == "" ]]; then
            error "STORAGE_BUCKET_NAME not specified. Make sure it is either set in the parameters file or as an env variable."
        fi
        if [[ $S3_URL == "" ]]; then
            error "S3_URL not specified. Make sure it is either set in the parameters file or as an env variable."
        fi
        if [[ $STORAGE_SECRET_ACCESS_KEY == "" ]]; then
            error "STORAGE_SECRET_ACCESS_KEY not specified. Make sure it is either set in the parameters file or as an env variable."
        fi
        if [[ $S3_URL == "" ]]; then
            error "STORAGE_SECRET_ACCESS_KEY_ID not specified. Make sure it is either set in the parameters file or as an env variable."
        fi
    fi

    #check that Server and Token info parameters are filled in target cluster type is diff
    check_cluster_credentials
    
    #write env variables to output file
    if [[ $WRITE == "true" ]]; then
        write_specific_env_vars_to_file $OUTPUT_FILE "OC YQ OPERATOR_NS SERVICES_NS TETHERED_NS BACKUP RESTORE SETUP OADP_INSTALL OADP_RESOURCE_CREATION OADP_NS BACKUP_STORAGE_LOCATION_NAMESTORAGE_BUCKET_NAME S3_URL STORAGE_SECRET_ACCESS_KEY STORAGE_SECRET_ACCESS_KEY_ID IM_ENABLED ZEN_ENABLED NSS_ENABLED UMS_ENABLED MCSP_ENABLED CERT_MANAGER_NAMESPACE LICENSING_NAMESPACE LSR_NAMESPACE CPFS_VERSION ZENSERVICE_NAME ZEN_NAMESPACE ENABLE_CERT_MANAGER ENABLE_LICENSING ENABLE_LSR ENABLE_PRIVATE_CATALOG ENABLE_DEFAULT_CS ADDITIONAL_SOURCES CONTROL_NS BACKUP_CLU_SERVER BACKUP_CLU_USERNAME BACKUP_CLU_PASSWORD RESTORE_CLU_SERVER RESTORE_CLU_USERNAME RESTORE_CLU_PASSWORD TARGET_CLUSTER_TYPE BACKUP_NAME"
    fi
}


#cluster credentials validation function (will be necessary for setup as well)
#need some kind of validation for restoring to different cluster
# if restore to or setup for different cluster enabled, need login creds for both clusters
# test by logging in to the other cluster and then logging back into the base cluster
function check_cluster_credentials() {
    if [[ $TARGET_CLUSTER_TYPE == "" ]]; then
        error "TARGET_CLUSTER_TYPE value not set. Make sure it is either set in the parameters file or as an env variable."
    else
        if [[ $TARGET_CLUSTER_TYPE == "diff" ]]; then
            if [[ $BACKUP_CLU_SERVER == "" ]] || [[ $BACKUP_CLU_USERNAME == "" ]] || [[ $BACKUP_CLU_PASSWORD == "" ]] ||  [[ $RESTORE_CLU_SERVER == "" ]] || [[ $BACKUP_CLU_USERNAME == "" ]] || [[ $RESTORE_CLU_PASSWORD == "" ]]; then
                error "If interacting with a different cluster (either restore or setup), all of BACKUP_CLU_SERVER BACKUP_CLU_USERNAME BACKUP_CLU_PASSWORD RESTORE_CLU_SERVER RESTORE_CLU_USERNAME and RESTORE_CLU_PASSWORD must be defined either in the parameters file or as an env variable." 
            else
                info "Different cluster selected. Validating login credentials work..."
                ${OC} login -u $RESTORE_CLU_USERNAME -p $RESTORE_CLU_PASSWORD --server=$RESTORE_CLU_SERVER --insecure-skip-tls-verify=true
                info "Logging back into home cluster..."
                ${OC} login -u $BACKUP_CLU_USERNAME -p $BACKUP_CLU_PASSWORD --server=$BACKUP_CLU_SERVER --insecure-skip-tls-verify=true
            fi
        fi
        success "Backup and Restore cluster login credentials verified."
    fi
}

function restore_cpfs(){
    title "Start CPFS restore."
    if [ -d "templates" ]; then
        rm -rf templates
    fi
    mkdir templates
    info "Copying template files..."
    cp -r ../velero/restore ${BASE_DIR}/templates/
        
    local all_namespaces=()
    local namespaces=("$OPERATOR_NS")
    local tethered_array=()
    local singleton_namespaces=()
    local extra_namespaces=("openshift-marketplace" "openshift-config" "kube-public")

    if [[ $SERVICES_NS != "$OPERATOR_NS" ]]; then
        namespaces+=("$SERVICES_NS")
    fi
    
    if [[ $TETHERED_NS != "" ]]; then
        local space_delimited="${TETHERED_NS//,/ }"
        tethered_array=($space_delimited)
    fi
    
    if [[ $ENABLE_CERT_MANAGER == "true" ]]; then
        singleton_namespaces+=("$CERT_MANAGER_NAMESPACE")
    fi
    if [[ $ENABLE_LICENSING == "true" ]]; then
        singleton_namespaces+=("$LICENSING_NAMESPACE")
    fi
    if [[ $ENABLE_LSR == "true" ]]; then
        singleton_namespaces+=("$LSR_NAMESPACE")
    fi
    
    all_namespaces=("${namespaces[@]}" "${tethered_array[@]}" "${extra_namespaces[@]}" "${singleton_namespaces[@]}")
    info "All namespaces in scope ${all_namespaces[*]}"

    for file in "${BASE_DIR}/templates/restore"/*; do
        if [[ "${file}" == *.yaml ]]; then
            sed -i -E "s/__BACKUP_NAME__/$BACKUP_NAME/" $file
            if [[ $OADP_NS != "velero" ]]; then
                set_oadp_namespace $file
            fi
            update_restore_name $file
            if [[ "${file}" != *restore-crd.yaml ]] && [[ "${file}" != *restore-cluster-auto.yaml ]]; then
                update_restore_namespaces $file "${all_namespaces[@]}"
            fi
        else
            info "File $file does not end in \".yaml\", skipping..."
        fi
    done
    #start no olm specific
    if [[ $NO_OLM == "true" ]]; then
    #update values in no-olm directory for no olm specific restore resources
        for file in "${BASE_DIR}/templates/restore/no-olm"/*; do
            if [[ "${file}" == *.yaml ]]; then
                sed -i -E "s/__BACKUP_NAME__/$BACKUP_NAME/" $file
                if [[ $OADP_NS != "velero" ]]; then
                    set_oadp_namespace $file
                fi
                update_restore_name $file
                if [[ "${file}" != *restore-crd.yaml ]] && [[ "${file}" != *restore-cluster-auto.yaml ]]; then
                    update_restore_namespaces $file "${all_namespaces[@]}"
                fi
            else
                info "File $file does not end in \".yaml\", skipping..."
            fi
        done
    fi
    #end no olm specific

    custom_columns_str="-o custom-columns=NAME:.metadata.name,STATUS:.status.phase,ITEMS_RESTORED:.status.progress.itemsRestored,TOTAL_ITEMS:.status.progress.totalItems,BACKUP:.spec.backupName,WARN:.status.warnings,ERR:.status.errors"
    info "Begin restore process..."
    #Initial restore objects, rarely fail, could theoretically be applied at once   
    info "Restoring namespaces and entitlement keys..."
    ${OC} apply -f ${BASE_DIR}/templates/restore/restore-namespace.yaml -f ${BASE_DIR}/templates/restore/restore-pull-secret.yaml -f ${BASE_DIR}/templates/restore/restore-entitlementkey.yaml
    ${OC} get restores.velero.io -n $OADP_NS $custom_columns_str
    wait_for_restore restore-namespace-$OPERATOR_NS
    wait_for_restore restore-entitlementkey-$OPERATOR_NS
    
    #start olm specific
    if [[ $NO_OLM == "false" ]]; then
        info "Cleanup existing pull secret..."
        ${OC} delete secret pull-secret -n openshift-config --ignore-not-found
        info "Restoring pull secret..."
        ${OC} apply -f ${BASE_DIR}/templates/restore/restore-pull-secret.yaml
        wait_for_restore restore-pull-secret-$OPERATOR_NS
        ${OC} get restores.velero.io -n $OADP_NS $custom_columns_str
        info "Restoring catalog sources..."
        ${OC} apply -f ${BASE_DIR}/templates/restore/restore-catalog.yaml
        wait_for_restore restore-catalog-$OPERATOR_NS
        info "Restore operator groups..."
        ${OC} apply -f ${BASE_DIR}/templates/restore/restore-operatorgroup.yaml 
        ${OC} get restores.velero.io -n $OADP_NS $custom_columns_str
        wait_for_restore restore-operatorgroup-$OPERATOR_NS
    fi
    #end olm specific
    info "Restore CRDs..."
    ${OC} apply -f ${BASE_DIR}/templates/restore/restore-crd.yaml && ${OC} apply -f ${BASE_DIR}/templates/restore/restore-cluster-auto.yaml
    wait_for_restore restore-crd-$OPERATOR_NS
    wait_for_restore restore-cluster-auto-$OPERATOR_NS
    info "Restore configmaps..."
    ${OC} apply -f ${BASE_DIR}/templates/restore/restore-configmap.yaml
    wait_for_restore restore-configmap-$OPERATOR_NS
    
    #Singleton subscriptions (Cert manager, licensing, LSR)
    if [[ $RESTORE_SINGLETONS == "true" ]]; then
        #we restore licensing before subs because the configmaps need to be there before licensing starts up
        if [[ $ENABLE_LICENSING == "true" ]]; then
            info "Restoring licensing configmaps..."
            #this will restore the licensing chart in no olm
            ${OC} apply -f ${BASE_DIR}/templates/restore/restore-licensing.yaml
            wait_for_restore restore-licensing-$OPERATOR_NS
        fi
        # same principle for lsr here as for licensing above
        if [[ $ENABLE_LSR == "true" ]]; then
            info "Restoring License Service Reporter instance..."
            #this will restore the LSR chart in no olm
            ${OC} apply -f ${BASE_DIR}/templates/restore/restore-lsr.yaml
            wait_for_restore restore-lsr-$OPERATOR_NS
        fi
        
        #start olm specific
        if [[ $NO_OLM == "false" ]]; then
            #this step restores the cert manager and licensing subs
            info "Restoring Singleton subscriptions..."
            ${OC} apply -f ${BASE_DIR}/templates/restore/restore-singleton-subscriptions.yaml
            wait_for_restore restore-singleton-subscription-$OPERATOR_NS
        fi
        #end olm specific

        #start no olm specific
        if [[ $NO_OLM == "true" ]]; then
            #restore cert manager chart
            info "Restoring Cert Manager Operator Chart..."
            ${OC} apply -f ${BASE_DIR}/templates/restore/no-olm/restore-ibm-cm-chart.yaml
            wait_for_restore restore-ibm-cm-chart-$OPERATOR_NS
        fi
        #end no olm specific

        if [[ $ENABLE_LSR == "true" ]]; then
            info "Restoring License Service Reporter data..."
            wait_for_deployment $LSR_NAMESPACE "ibm-license-service-reporter-instance" 30
            ${OC} apply -f ${BASE_DIR}/templates/restore/restore-lsr-data.yaml
            wait_for_restore restore-lsr-data-$OPERATOR_NS
        fi
    fi
    ${OC} get restores.velero.io -n $OADP_NS $custom_columns_str
    
    wait_for_cert_manager $CERT_MANAGER_NAMESPACE $SERVICES_NS
    info "Restoring cert manager resources (secrets, certificates, issuers, etc.)..."
    ${OC} apply -f ${BASE_DIR}/templates/restore/restore-cert-manager.yaml
    wait_for_restore restore-cert-manager-$OPERATOR_NS
    
    #Restore the common service CR and the tenant scope via nss
    info "Restoring common service CR..."
    ${OC} apply -f ${BASE_DIR}/templates/restore/restore-commonservice.yaml
    wait_for_restore restore-commonservice-$OPERATOR_NS

    #start olm specific
    if [[ $NO_OLM == "false" ]]; then
        if [[ $NSS_ENABLED == "true" ]]; then 
            info "Restoring Namespace Scope resources..."
            #this will restore nss cluster and chart resources as well in no olm
            ${OC} apply -f ${BASE_DIR}/templates/restore/restore-nss.yaml
            wait_for_restore restore-nss-$OPERATOR_NS
            ${OC} get restores.velero.io -n $OADP_NS $custom_columns_str
            validate_nss $OPERATOR_NS
        fi
        #restore common service subscription and odlm operator
        info "Restore CS and ODLM Operators..."
        ${OC} apply -f ${BASE_DIR}/templates/restore/restore-subscriptions.yaml
        wait_for_restore restore-subscription-$OPERATOR_NS
        validate_cs_odlm $OPERATOR_NS
    fi
    #end olm specific
    #start no olm specific
    if [[ $NO_OLM == "true" ]]; then
        #restore cluster charts no-olm/restore-cluster-scope.yaml
        info "Restoring cluster wide operator resources..."
        ${OC} apply -f ${BASE_DIR}/templates/restore/no-olm/restore-cluster-scope.yaml
        wait_for_restore restore-cluster-charts-$OPERATOR_NS
        
        #restore namespace scope operator chart
        if [[ $NSS_ENABLED == "true" ]]; then 
            info "Restoring Namespace Scope resources..."
            #this will restore nss chart resources as well in no olm
            ${OC} apply -f ${BASE_DIR}/templates/restore/restore-nss.yaml
            wait_for_restore restore-nss-$OPERATOR_NS
            ${OC} get restores.velero.io -n $OADP_NS $custom_columns_str
            wait_for_deployment $OPERATOR_NS ibm-namespace-scope-operator
        fi

        #restore cs op/odlm chart no-olm/restore-installer-ns-charts.yaml
        info "Restoring CS Operator and ODLM charts..."
        ${OC} apply -f ${BASE_DIR}/templates/restore/no-olm/restore-installer-ns-charts.yaml
        wait_for_restore restore-installer-charts-$OPERATOR_NS
        wait_for_deployment $OPERATOR_NS ibm-common-service-operator
        wait_for_deployment $OPERATOR_NS operand-deployment-lifecycle-manager
        #restore im ns chart no-olm/restore-im-ns-charts.yaml
        #This restore resource is how we restore the EDB chart. 
        #Technically, zen could be enabled and set IM to false but we would still need to restore the edb chart so we would still need to apply this resource
        if [[ $IM_ENABLED == "true" ]] || [[ $ZEN_ENABLED == "true" ]]; then
            info "Restoring IM, Common UI, and EDB charts..."
            ${OC} apply -f ${BASE_DIR}/templates/restore/no-olm/restore-im-ns-charts.yaml
            wait_for_restore restore-im-charts-$OPERATOR_NS
            #TODO implement check for im so we don't wait for im and ui deployments in case where zen does not enable im since this is where we need to restore and check edb
            wait_for_deployment $OPERATOR_NS ibm-iam-operator
            wait_for_deployment $OPERATOR_NS ibm-commonui-operator
            wait_for_deployment $OPERATOR_NS postgresql-operator-controller-manager-1-25-1
        fi
    fi
    #end no olm specific
    

    #restore ums has to happen before operand requests are restored so ODLM does not create default values for restore resources
    if [[ $UMS_ENABLED == "true" ]]; then
        info "Restoring UMS resources..."
        ${OC} apply -f ${BASE_DIR}/templates/restore/restore-ums.yaml
        wait_for_restore restore-ums-$OPERATOR_NS
    fi
    
    ${OC} get restores.velero.io -n $OADP_NS $custom_columns_str
    info "Restoring operands..."
    ${OC} apply -f ${BASE_DIR}/templates/restore/restore-operands.yaml
    wait_for_restore restore-operands-$OPERATOR_NS
    
    #start no olm specific
    if [[ $NO_OLM == "true" ]]; then
        #restore zen ns chart no-olm/restore-zen-ns-charts.yaml 
        info "Restoring Zen chart..."
        ${OC} apply -f ${BASE_DIR}/templates/restore/no-olm/restore-zen-ns-chart.yaml
        wait_for_restore restore-zen-chart-$OPERATOR_NS
    fi
    #end no olm specific

    if [[ $IM_ENABLED == "true" ]]; then
        restore_im
    fi
    if [[ $ZEN_ENABLED == "true" ]]; then
        restore_zen
    fi
    
    success "CPFS Restore completed."
}

function wait_for_restore() {
    restore=$1
    status=$(${OC} get restores.velero.io $restore -n $OADP_NS -o jsonpath='{.status.phase}')
    retries=30
    sleep_time=20
    if [[ $restore == "restore-zen5-data" ]]; then
        retries=120
        sleep_time=30
    elif [[ $restore == "restore-lsr-data" ]]; then
        retries=60
        sleep_time=15
    fi
    while [[ $status != "Completed" ]] && [[ $retries -gt 0 ]]; do
        info "Wait for restore $restore to complete. Try again in $sleep_time seconds."
        sleep $sleep_time
        status=$(${OC} get restores.velero.io $restore -n $OADP_NS -o jsonpath='{.status.phase}')
        retries=$((retries-1))
        if [[ $status == "Failed" ]] || [[ $status == "PartiallyFailed" ]]; then
            if [[ $restore == "restore-zen5-data" ]]; then
                apply_zen_workaround $ZEN_NAMESPACE $ZENSERVICE_NAME
                status="Completed"
            elif [[ $restore == "restore-cs-db-data" ]]; then
                apply_im_workaround $SERVICES_NS
                status="Completed"
            elif [[ $restore == "restore-lsr-data" ]]; then
                apply_lsr_workaround $LSR_NAMESPACE
                status="Completed"
            else
                ${OC} get restores.velero.io $restore -n $OADP_NS $custom_columns_str
                error "Restore $restore failed with status: $status. For more details, run \"velero restore describe --details $restore\"."
            fi
        fi
    done
    if [[ $status == "Completed" ]]; then
        info "Restore $restore completed successfully. For more details, run \"velero restore describe --details $restore\"."
    else
        error "Timed out waiting for restore $restore to complete successfully. For more details, run \"velero restore describe --details $restore\"."
    fi
}

function validate_nss() {
    local namespace=$1
    wait_for_csv "$namespace" "ibm-namespace-scope-operator"
    wait_for_operator "$namespace" "ibm-namespace-scope-operator"
}

function validate_cs_odlm() {
    local namespace=$1
    wait_for_csv "$namespace" "ibm-common-service-operator"
    wait_for_operator "$namespace" "ibm-common-service-operator"
    wait_for_csv "$namespace" "ibm-odlm"
    wait_for_operator "$namespace" "operand-deployment-lifecycle-manager"
    wait_for_cscr_status "$namespace" "common-service"
}

function restore_im() {
    info "Restoring IM Data..."
    wait_for_im $SERVICES_NS
    if [[ $MCSP_ENABLED == "true" ]]; then
        wait_for_deployment $SERVICES_NS "account-iam-ui-account-deployment"
    fi
    ${OC} apply -f ${BASE_DIR}/templates/restore/restore-cs-db.yaml
    wait_for_restore restore-cs-db-data-$OPERATOR_NS
    success "IM data restored successfully."
}

function wait_for_im() {
    info "Sleep for 5 minutes for IM operator to create authentication cr"
    sleep 300
    local namespace=$1
    local name="platform-identity-provider"
    wait_for_deployment $namespace $name 40
}

function restore_zen() {
    info "Restoring zenservice..."
    ${OC} apply -f ${BASE_DIR}/templates/restore/restore-zen.yaml
    wait_for_restore restore-zen-$OPERATOR_NS
    wait_for_zenservice
    info "Restoring zen data..."
    ${OC} apply -f ${BASE_DIR}/templates/restore/restore-zen5-data.yaml
    wait_for_restore restore-zen5-data-$OPERATOR_NS
    success "Zen data restored successfully"
}

function wait_for_zenservice {
    info "Waiting for zenservice $ZENSERVICE_NAME to complete in namespace $ZEN_NAMESPACE."
    zenservice_exists=$(oc get zenservice $ZENSERVICE_NAME -n $ZEN_NAMESPACE --no-headers || echo fail)
    if [[ $zenservice_exists != "fail" ]]; then
        completed=$(oc get zenservice $ZENSERVICE_NAME -n $ZEN_NAMESPACE -o jsonpath='{.status.progress}')
        retry_count=60
        sleep_time=60
        while [[ $completed != "100%" ]] && [[ $retry_count > 0 ]]
        do
            info "Wait for zenservice $ZENSERVICE_NAME to complete. Completion % is $completed. Try again in 60s."
            sleep $sleep_time
            completed=$(oc get zenservice $ZENSERVICE_NAME -n $ZEN_NAMESPACE -o jsonpath='{.status.progress}')
            retry_count=$((retry_count-1))
        done

        if [[ $retry_count == 0 ]] && [[ $completed != "100%" ]]; then
            error "Timed out waiting for zenservice $ZENSERVICE_NAME."
        else
            info "Zenservice $ZENSERVICE_NAME ready."
        fi
    else
        error "Zenservice $ZENSERVICE_NAME not present."
    fi
}

function apply_im_workaround() {
    local namespace=$1
    info "IM data restored failed, attempting workaround..."
    ${OC} delete deployment cs-db-backup -n $namespace
    sed -i -E "s/<cs-db namespace>/$namespace/" ${BASE_DIR}/templates/restore/common-service-db/cs-db-restore-job.yaml
    info "Creating workaround job cs-db-restore-job"
    ${OC} apply -f ${BASE_DIR}/templates/restore/common-service-db/cs-db-restore-job.yaml
    wait_for_job_complete cs-db-restore-job $namespace

}

function apply_zen_workaround() {
    local namespace=$1
    local zenservice=$2
    info "Zen data restored failed, attempting workaround..."
    ${OC} delete deployment zen5-backup -n $namespace
    sed -i -E "s/<zenservice namespace>/$namespace/" ${BASE_DIR}/templates/restore/zen/zen5-restore-job.yaml
    sed -i -E "s/<zenservice name>/$zenservice/" ${BASE_DIR}/templates/restore/zen/zen5-restore-job.yaml
    info "Creating workaround job zen5-restore-job"
    ${OC} apply -f ${BASE_DIR}/templates/restore/zen/zen5-restore-job.yaml
    wait_for_job_complete zen5-restore-job $namespace
}

function apply_lsr_workaround() {
    local namespace=$1
    info "License Service Reporter data restored failed, attempting workaround..."
    ${OC} delete deployment lsr-backup -n $namespace
    sed -i -E "s/<lsr namespace>/$namespace/" ${BASE_DIR}/templates/restore/lsr/lsr-data-restore-job.yaml
    info "Creating workaround job lsr-restore-job"
    ${OC} apply -f ${BASE_DIR}/templates/restore/lsr/lsr-data-restore-job.yaml
    wait_for_job_complete lsr-restore-job $namespace
}

function wait_for_job_complete() {
  local job_name=$1
  local namespace=$2
  local condition="${OC} get pod -n $namespace --no-headers --ignore-not-found | grep ${job_name} | grep 'Completed' || true"
  local retries=50
  local sleep_time=30
  local total_time_mins=$(( sleep_time * retries / 60))
  local wait_message="Waiting for job pod $job_name to complete"
  local success_message="Job $job_name completed in namespace $namespace"
  local error_message="Timeout after ${total_time_mins} minutes waiting for job $job_name"
  wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
  info "For more details on ${job_name}, check its pod logs."
}

function wait_for_cert_manager() {
    local cm_namespace=$1
    local name="cert-manager-webhook"
    local test_namespace=$2
    wait_for_deployment $cm_namespace $name 
    #from utils.sh, checks if cert manager exists and then runs smoke test
    check_cert_manager cert-manager $test_namespace
}

function write_specific_env_vars_to_file() {
    local output_file="$1"
    local vars=$2
    
    info "Writing specific environment variables to '$output_file'..."
    
    if ! touch "$output_file" 2>/dev/null; then
        error "Error: Cannot write to file '$output_file'"
    fi
    
    # Write each specified variable
    local count=0
    for var_name in $vars; do
        local var_value=$(printenv "$var_name")
        echo "$var_name=${var_value}" >> "$output_file"
        ((count++))
    done
    
    success "Successfully wrote $count environment variables to '$output_file'"
}

function set_oadp_namespace() {
        local file=$1
        ${YQ} eval ".metadata.namespace = \"$OADP_NS\"" -i $file
}

function backup_setup() {
    title "Prepping CPFS instance with Operator NS $OPERATOR_NS for backup."
    local namespaces="$OPERATOR_NS,$SERVICES_NS,$TETHERED_NS"
    info "Labeling cert manager resources in namespaces: ${namespaces//,/ }"
    ./../velero/backup/cert-manager/label-cert-manager.sh --namespaces $namespaces || error "Cert Manager resource labeling script did not complete successfully."
    info "Labeling CPFS instance and Singleton resources..."
    label_arg_str="--operator-ns $OPERATOR_NS"
    deploy_arg_str=""
    if [[ $SERVICES_NS != $OPERATOR_NS ]]; then
        label_arg_str="$label_arg_str --services-ns $SERVICES_NS"
        deploy_arg_str="--services-ns $SERVICES_NS"
    else
        deploy_arg_str="--operator-ns $OPERATOR_NS"
    fi
    if [[ $TETHERED_NS != "" ]]; then
        label_arg_str="$label_arg_str --tethered-ns $TETHERED_NS"
    fi
    if [[ $ENABLE_CERT_MANAGER == "true" ]]; then
        label_arg_str="$label_arg_str --cert-manager-ns $CERT_MANAGER_NAMESPACE"
    fi
    if [[ $ENABLE_LICENSING == "true" ]]; then
        label_arg_str="$label_arg_str --licensing-ns $LICENSING_NAMESPACE"
        info "Labeling licensing resources in namespace $LICENSING_NAMESPACE..."
        ./../velero/backup/licensing/label-licensing-configmaps.sh $LICENSING_NAMESPACE || error "Licensing labeling script did not complete successfully."
    fi
    if [[ $ENABLE_LSR == "true" ]]; then
        label_arg_str="$label_arg_str --lsr-ns $LSR_NAMESPACE"
        deploy_arg_str="$deploy_arg_str --lsr-ns $LSR_NAMESPACE --lsr"
    fi
    if [[ $ENABLE_PRIVATE_CATALOG == "true" ]]; then
        label_arg_str="$label_arg_str --enable-private-catalog"
    fi
    if [[ $ENABLE_DEFAULT_CS == "true" ]]; then
        label_arg_str="$label_arg_str --enable-default-catalog-ns"
    fi
    if [[ $ADDITIONAL_SOURCES != "" ]]; then
        label_arg_str="$label_arg_str --additional-catalog-sources $ADDITIONAL_SOURCES"
    fi
    if [[ $NO_OLM == "true" ]]; then
        label_arg_str="$label_arg_str --no-olm"
    fi
    
    info "Labeling script parameters: $label_arg_str"
    ./../velero/backup/common-service/label-common-service.sh $label_arg_str || error "Script label-common-service.sh failed to complete."
    if [[ $IM_ENABLED == "true" ]] || [[ $ZEN_ENABLED == "true" ]] || [[ $ENABLE_LSR == "true" ]]; then
        if [[ $IM_ENABLED == "true" ]]; then
            deploy_arg_str="$deploy_arg_str --im"
        fi
        if [[ $ZEN_ENABLED == "true" ]]; then
            deploy_arg_str="$deploy_arg_str --zen --zen-ns $ZEN_NAMESPACE"
        fi
        if [[ $STORAGE_CLASS != "" ]]; then
            deploy_arg_str="$deploy_arg_str --storage-class $STORAGE_CLASS"
        fi
        info "Deploying necessary backup resources for tenant $OPERATOR_NS..."
        info "Backup resource deployment script parameters: $deploy_arg_str"
        ./../velero/schedule/deploy-br-resources.sh $deploy_arg_str || error "Script deploy-br-resources.sh failed to deploy BR resources."
        if [[ $IM_ENABLED == "true" ]]; then
            wait_for_deployment $SERVICES_NS "cs-db-backup" 
        fi
        if [[ $ZEN_ENABLED == "true" ]]; then
            wait_for_deployment $ZEN_NAMESPACE "zen5-backup" 
        fi
        if [[ $ENABLE_LSR == "true" ]]; then
            wait_for_deployment $LSR_NAMESPACE "lsr-backup" 
        fi
    fi

    success "CPFS instance with operator namespace $OPERATOR_NS labeled for backup."
}

function create_backup() {
    title "Starting backup..."
    if [ -d "templates" ]; then
        rm -rf templates
    fi
    mkdir templates
    info "Copying backup template..."
    cp ../velero/backup/backup.yaml ${BASE_DIR}/templates/

    sed -i -E "s/__BACKUP_NAME__/$BACKUP_NAME/" ${BASE_DIR}/templates/backup.yaml
    sed -i -E "s/<storage location name>/$BACKUP_STORAGE_LOCATION_NAME/" ${BASE_DIR}/templates/backup.yaml

    if [[ $OADP_NS != "velero" ]]; then
        set_oadp_namespace ${BASE_DIR}/templates/backup.yaml
    fi

    ${OC} apply -f ${BASE_DIR}/templates/backup.yaml
    info "Backup resource created, backup in progress"
}

function verify_backup_complete() {
    title "Waiting for backup to complete..."
    status=$(${OC} get backups.velero.io $BACKUP_NAME -n $OADP_NS -o jsonpath='{.status.phase}')
    retries=30
    sleep_time=20
    while [[ $status != "Completed" ]] && [[ $retries -gt 0 ]]; do
        info "Wait for backup $BACKUP_NAME to complete. Try again in $sleep_time seconds."
        sleep $sleep_time
        status=$(${OC} get backups.velero.io $BACKUP_NAME -n $OADP_NS -o jsonpath='{.status.phase}')
        retries=$((retries-1))
        if [[ $status == "Failed" ]] || [[ $status == "PartiallyFailed" ]] || [[ $status == "FailedValidation" ]]; then
            ${OC} get backups.velero.io $BACKUP_NAME -n $OADP_NS $custom_columns_str
            error "Backup $BACKUP_NAME failed with status: $status. For more details, run \"velero backup describe --details $BACKUP_NAME\"."
        fi
    done
    if [[ $status == "Completed" ]]; then
        success "Backup $BACKUP_NAME completed successfully. For more details, run \"velero backup describe --details $BACKUP_NAME\"."
    else
        error "Timed out waiting for backup $BACKUP_NAME to complete successfully. For more details, run  \"velero backup describe --details $BACKUP_NAME\"."
    fi
}

function check_for_oadp() {
    info "checking cluster for existing OADP install..."
    oadp_exists=$(${OC} get csv -A | grep oadp-operator)
    if [[ $oadp_exists == "" ]]; then
        info "No OADP found on cluster, continuing with install..."
        install_oadp
    else
        info "OADP already installed on cluster, skipping oeprator setup."
        dpa_exists=$(${OC} get dataprotectionapplication $DPA_NAME -n $OADP_NS --ignore-not-found --no-headers)
        if [[ $dpa_exists == "" ]]; then
            info "DataProtectionApplication matching parameter DPA_NAME ($DPA_NAME) not found in namespace $OADP_NS. Creating..."
            create_dpa
        else
            info "DataProtectionApplication matching parameter DPA_NAME ($DPA_NAME) found in namespace $OADP_NS. Skipping creation..."
        fi
        
    fi
}

function install_oadp(){
    title "Installing and configuring OADP/Velero..."
    
    #check for ns and operator group to already exist
    if ${OC} get ns "$OADP_NS" >/dev/null 2>&1; then
        info "Namespace $OADP_NS exists, continuing..."
    else
        info "Namespace $OADP_NS does not exist, creating..."
        ${OC} create namespace $OADP_NS
    fi
    
    opgroup_exists=$(${OC} get operatorgroup -n $OADP_NS --ignore-not-found --no-headers)
    if [[ -z $opgroup_exists ]]; then
        info "No operatorgroup found, creating..."
        cat << EOF | ${OC} apply -n $OADP_NS -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  annotations:
    olm.providedAPIs: Backup.v1.velero.io,BackupRepository.v1.velero.io,BackupStorageLocation.v1.velero.io,CloudStorage.v1alpha1.oadp.openshift.io,DataDownload.v2alpha1.velero.io,DataProtectionApplication.v1alpha1.oadp.openshift.io,DataUpload.v2alpha1.velero.io,DeleteBackupRequest.v1.velero.io,DownloadRequest.v1.velero.io,PodVolumeBackup.v1.velero.io,PodVolumeRestore.v1.velero.io,Restore.v1.velero.io,Schedule.v1.velero.io,ServerStatusRequest.v1.velero.io,VolumeSnapshotLocation.v1.velero.io
  name: $OADP_NS-operatorgroup
spec:
  targetNamespaces:
  - $OADP_NS
  upgradeStrategy: Default
EOF
    fi

    info "Creating operator subscription..."
    #create sub
    cat << EOF | ${OC} apply -n $OADP_NS -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/redhat-oadp-operator.velero: ""
  name: redhat-oadp-operator
spec:
  installPlanApproval: Automatic
  name: redhat-oadp-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

    wait_for_operator $OADP_NS oadp-operator

    create_dpa

    success "OADP successfully installed and configured."
}

function create_dpa() {
    #create secret for oadp resources
    info "Preparing storage location credentials file..."
    rm -f credentials-velero
    echo "[default]" >>credentials-velero
    echo "aws_access_key_id="$STORAGE_SECRET_ACCESS_KEY_ID >>credentials-velero
    echo "aws_secret_access_key="$STORAGE_SECRET_ACCESS_KEY >>credentials-velero
    info "Creating secret for OADP/Velero..."
    ${OC} create secret generic cloud-credentials -n $OADP_NS --from-file cloud=credentials-velero
    
    #create backup storage location
    cat << EOF | ${OC} apply -f -
apiVersion: oadp.openshift.io/v1alpha1
kind: DataProtectionApplication
metadata:
  name: $DPA_NAME
  namespace: $OADP_NS
spec:
  backupLocations:
    - velero:
        config:
          profile: default
          region: $BUCKET_REGION
          s3ForcePathStyle: 'true'
          s3Url: '$S3_URL'
        credential:
          key: cloud
          name: cloud-credentials
        default: true
        objectStorage:
          bucket: $STORAGE_BUCKET_NAME
          prefix: tmp/
        provider: aws
  configuration:
    nodeAgent:
      enable: true
      uploaderType: kopia
    velero:
      defaultPlugins:
        - openshift
        - aws
      podConfig:
        resourceAllocations:
          limits:
            cpu: '1'
            memory: 1Gi
          requests:
            cpu: 500m
            memory: 512Mi
EOF
}

function wait_for_backup() {
    local condition="${OC} get backup.velero.io -n $OADP_NS --no-headers --ignore-not-found | grep $BACKUP_NAME"
    local retries=20
    local sleep_time=30
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for backup $BACKUP_NAME to be available on Restore cluster."
    local success_message="Backup $BACKUP_NAME accessible from Restore cluster."
    local error_message="Timeout after ${total_time_mins} minutes waiting for backup $BACKUP_NAME to be accessible on Restore cluster."
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function login() {
    server=$1
    username=$2
    password=$3
    title "Logging in to server $server"
    #oc login to spoke cluster
    ${OC} login -u $username -p $password --server=$server --insecure-skip-tls-verify=true
}


function check_yq() {
  yq_version=$("${YQ}" --version | awk '{print $NF}' | sed 's/^v//')
  yq_minimum_version=4.18.1

  if [ "$(printf '%s\n' "$yq_minimum_version" "$yq_version" | sort -V | head -n1)" != "$yq_minimum_version" ]; then 
    error "yq version $yq_version must be at least $yq_minimum_version or higher.\nInstructions for installing/upgrading yq are available here: https://github.com/marketplace/actions/yq-portable-yaml-processor"
  fi
}

function update_restore_namespaces() {
    local file="$1"
    shift
    local namespaces=("$@")
    info "Updating restore resource in file $file to specify namespaces ${namespaces[*]}..."
    
    # Build namespace array
    local json_array="["
    for i in "${!namespaces[@]}"; do
        [ $i -gt 0 ] && json_array+=","
        json_array+="\"${namespaces[$i]}\""
    done
    json_array+="]"
    
    # Update Restore file
    ${YQ} eval ".spec.includedNamespaces = $json_array" -i "$file"

}

function update_restore_name() {
    local file="$1"
    cur_name=$(${YQ} '.metadata.name' $file)
    cur_name+="-${OPERATOR_NS}"
    ${YQ} -i '.metadata.name = "'"$cur_name"'"' $file
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

main $*
