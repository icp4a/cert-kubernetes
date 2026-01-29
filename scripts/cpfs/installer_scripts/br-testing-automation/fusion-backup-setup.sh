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

HUB_SETUP="false"
BACKUP_SETUP="false"
RESTORE_SETUP="false"

BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)
OUTPUT_FILE="${BASE_DIR}/env-fusion.properties"
. ../cp3pt0-deployment/common/utils.sh

function main() {
    parse_arguments "$@"
    prereq
    info "Base Directory: $BASE_DIR"
    source $OUTPUT_FILE
    if [[ $HUB_SETUP == "true" ]]; then
        save_log "logs" "hub_setup_log"
        trap cleanup_log EXIT
        validate_sc
        install_sf_br "hub"
        success "Fusion installed on Hub Cluster."
    fi
    if [[ $BACKUP_SETUP == "true" ]]; then
        create_sf_resources
        deploy_cs_br_resources
        label_cs_resources
        success "Fusion resources configured on Hub Cluster, ready for Backup."
    fi
    if [[ $RESTORE_SETUP == "true" ]]; then
        save_log "logs" "spoke_setup_log"
        trap cleanup_log EXIT
        install_sf_br "spoke"
        success "Spoke cluster prepped for Restore."
    fi
}

function print_usage(){
    script_name=`basename ${0}`
    echo "Usage: ${script_name} [OPTIONS]"
    echo ""
    echo "Set up either a hub cluster or a spoke cluster to use Spectrum Fusion Backup and Restore."
    echo "One of --hub-setup or --spoke-setup is required."
    echo "This script assumes the following:"
    echo "    * An existing CPFS instance on the hub cluster with IM, Zen, Licensing, Cert Manager, and License Service Reporter present"
    echo "    * Filled in required variables in the accompanying env.properties file"
    echo ""
    echo "Options:"
    echo "   --oc string                    Optional. File path to oc CLI. Default uses oc in your PATH. Can also be set in env.properties."
    echo "   --yq string                    Optional. File path to yq CLI. Default uses yq in your PATH. Can also be set in env.properties."
    echo "   --backup-setup                 Optional. Create Fusion recipes and application resources for specified instance. Label CPFS resources to prep for Backup."
    echo "   --hub-setup                    Optional. Set up Spectrum Fusion Backup and Restore Hub cluster."
    echo "   --spoke-setup                  Optional. Set up Spectrum Fusion Backup and Restore Spoke cluster. Must have an existing Hub cluster to connect to."
    echo "   --env-file                     Optional. Enter env var file to populate necessary parameters. Default file name is env-oadp.properties."
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
        --backup-setup)
            BACKUP_SETUP="true"
            ;;
        --hub-setup)
            HUB_SETUP="true"
            ;;
        --spoke-setup)
            RESTORE_SETUP="true"
            ;;
        --env-file)
            shift
            OUTPUT_FILE=$1
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
    #check that oc yq and skopeo are available
    check_command "${OC}"
    check_command "${YQ}"
    check_command "skopeo"
    # Check yq version
    check_yq

    # Checking oc command logged in
    user=$(${OC} whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        error "You must be logged into the OpenShift Cluster from the oc command line"
    else
        success "oc command logged in as ${user}"
    fi

    #check docker access (so far not necessary)

    #check variables are present
    if [[ $BACKUP_SETUP == "true" ]] && [[ $RESTORE_SETUP == "true" ]]; then
        error "Both Hub and Spoke setup options selected. Please rerun selecting one or the other (Hub has to come first)."
    elif [[ $BACKUP_SETUP == "false" ]] && [[ $RESTORE_SETUP == "false" ]]; then
        error "Neither Hub nor Spoke setup options selected. Please rerun selecting one or the other (Hub has to come first)."
    elif [[ $BACKUP_SETUP == "true" ]] || [[ $RESTORE_SETUP == "true" ]]; then
        if [[ -z $CS_CATALOG_SOURCE ]] || [[ -z $FUSION_CATALOG_SOURCE ]] || [[ -z $CAT_SRC_NS ]] || [[ -z $SF_NAMESPACE ]] || [[ -z $GITHUB_USER ]] || [[ -z $GITHUB_TOKEN ]] || [[ -z $STORAGE_CLASS ]]; then
            error "Missing value for one or more of CS_CATALOG_SOURCE, FUSION_CATALOG_SOURCE, CAT_SRC_NS, SF_NAMESPACE, GITHUB_USER, GITHUB_TOKEN, or STORAGE_CLASS. Please update env.properties file with correct parameters and rerun."
        fi
        if [[ $BACKUP_SETUP == "true" ]]; then
            if [[ -z $OPERATOR_NS ]] || [[ -z $SERVICES_NS ]] || [[ -z $BACKUP_STORAGE_LOCATION_NAME ]] || [[ -z $STORAGE_BUCKET_NAME ]] || [[ -z $S3_URL ]] || [[ -z $STORAGE_SECRET_ACCESS_KEY ]] || [[ -z $STORAGE_SECRET_ACCESS_KEY_ID ]] || [[ -z $CERT_MANAGER_NAMESPACE ]] || [[ -z $LICENSING_NAMESPACE ]] || [[ -z $LSR_NAMESPACE ]] || [[ -z $CPFS_VERSION ]] || [[ -z $ZENSERVICE_NAME ]]; then
                error "Missing value for one or more of OPERATOR_NAMESPACE, SERVICES_NS, BACKUP_STORAGE_LOCATION_NAME, STORAGE_BUCKET_NAME, S3_URL, STORAGE_SECRET_ACCESS_KEY, STORAGE_SECRET_ACCESS_KEY_ID, CERT_MANAGER_NAMESPACE, LICENSING_NAMESPACE, LSR_NAMESPACE, CPFS_VERSION, ZENSERVICE_NAME. Please update env.properties file with correct parameters and rerun."
            fi
        elif [[ $RESTORE_SETUP == "true" ]]; then
            if [[ -z $HUB_USERNAME ]] || [[ -z $HUB_PASSWORD ]] || [[ -z $HUB_SERVER ]] || [[ -z $SPOKE_USERNAME ]] || [[ -z $SPOKE_PASSWORD ]] || [[ -z $SPOKE_SERVER ]]; then
                error "Missing value for one or more of HUB_USERNAME, HUB_PASSWORD, HUB_SERVER, SPOKE_USERNAME, SPOKE_PASSWORD, SPOKE_SERVER. Please update env.properties file with correct parameters and rerun."
            fi
        fi
    fi

}

function validate_sc(){
    #check sc
    if [[ $STORAGE_CLASS == "" ]]; then
        STORAGE_CLASS=$(${OC} get sc | grep "(default)" | awk '{print $1}') 
    fi
    #if rook ceph, verify no pools
    if [[ $STORAGE_CLASS == "rook-cephfs" ]]; then
        pool_exist=$(oc get sc $STORAGE_CLASS -o jsonpath='{.parameters.pool}')
        if [[ $pool_exist != "" ]]; then
            error "Spectrum Fusion BR will not work with Rook-CephFS if the pool parameter is enabled. See \`oc get sc $STORAGE_CLASS -o jsonpath=\'{.parameters.pool}\'\` for more details."
        else
            info "Pool parameter correctly not specified in rook-cephfs, continuing..."
        fi
    fi
    #if odf, that works

    #ensure volumesnapshotclass created
    vcs_exists=$(${OC} get volumesnapshotclass)
    if [[ $vcs_exists == "" ]]; then
        driver=$(${OC} get sc $STORAGE_CLASS -o jsonpath='{.provisioner}')
        clusterID=$(${OC} get sc $STORAGE_CLASS -o jsonpath='{.parameters.clusterID}')
        snapshotter_secret_name=$(${OC} get sc $STORAGE_CLASS -o yaml | ${YQ} '.parameters."csi.storage.k8s.io/provisioner-secret-name"')
        snapshotter_secret_namespace=$(${OC} get sc $STORAGE_CLASS -o yaml | ${YQ} '.parameters."csi.storage.k8s.io/provisioner-secret-namespace"')

        cat << EOF | ${OC} apply -f -
apiVersion: snapshot.storage.k8s.io/v1
deletionPolicy: Delete
driver: $driver
kind: VolumeSnapshotClass
metadata:
  name: $STORAGE_CLASS-snapclass
parameters:
  clusterID: $clusterID
  csi.storage.k8s.io/snapshotter-secret-name: $snapshotter_secret_name
  csi.storage.k8s.io/snapshotter-secret-namespace: $snapshotter_secret_namespace
EOF
    fi
}

function install_sf_br(){
    title "Installing Spectrum Fusion and its Backup and Restore service from catalog $FUSION_CATALOG_SOURCE."
    role=$1
    info "Cloning SF cmd-line-install repo..."
    git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.ibm.com/ProjectAbell/cmd-line-install.git
    
    #TODO verify catalog source pod is actually running
    catalog_image=$(${OC} get catalogsource -o jsonpath='{.spec.image}' $FUSION_CATALOG_SOURCE -n $CAT_SRC_NS)

    info "executing install-isf-br.sh script with catalog image $catalog_image in namespace $SF_NAMESPACE."
    if [[ $role == "hub" ]]; then
        info "Installing Spectrum Fusion BR Hub..."
        ./cmd-line-install/install/install-isf-br.sh $catalog_image -n $SF_NAMESPACE || error "SF install script failed to install on hub cluster."
        apiurl=$(oc whoami --show-server)
        cluster=$(echo $apiurl | cut -d":" -f2 | tr -d /)
        info "Waiting for BR Hub service to install on hub cluster $cluster..."
        while [[ $(${OC} get fusionserviceinstance ibm-backup-restore-service-instance -n $SF_NAMESPACE -o jsonpath='{.status.installStatus.status}') != "Completed" ]]; do
            sleep 30
            progress=$(${OC} get fusionserviceinstance ibm-backup-restore-service-instance -n $SF_NAMESPACE -o jsonpath='{.status.installStatus}')
            info "Install progress: $progress"
        done
        success "Spectrum Fusion and Backup and Restore Hub Service installed."
    elif [[ $role == "spoke" ]]; then
        info "Installing Spectrum Fusion BR spoke..."
        error="false"
        info "Connecting to spoke cluster $SPOKE_SERVER"
        #oc login to spoke cluster
        ${OC} login -u $SPOKE_USERNAME -p $SPOKE_PASSWORD --server=$SPOKE_SERVER --insecure-skip-tls-verify=true
        validate_sc
        ./cmd-line-install/install/install-isf-br.sh -s $catalog_image -n $SF_NAMESPACE || error="true"
        if [[ $error == "true" ]]; then
            ${OC} login -u $HUB_USERNAME -p $HUB_PASSWORD --server=$HUB_SERVER --insecure-skip-tls-verify=true
            error "SF install script failed to install on spoke cluster. Logging back into hub cluster $HUB_SERVER."
        fi
        info "Connecting to hub cluster $HUB_SERVER"
        #oc login to the hub cluster
        ${OC} login -u $HUB_USERNAME -p $HUB_PASSWORD --server=$HUB_SERVER --insecure-skip-tls-verify=true
        apiurl=$(oc whoami --show-server)
        cluster=$(echo $apiurl | cut -d":" -f2 | tr -d /)
        file=spokes_$cluster.yaml
        work_dir=$HOME/spokes/$cluster
        info "Creating spoke yaml..."
        ./cmd-line-install/install/create-spokes-yaml.sh $BR_SERVICE_NAMESPACE $STORAGE_CLASS
        
        info "Re-connecting to spoke cluster $SPOKE_SERVER"
        #oc login to spoke cluster
        ${OC} login -u $SPOKE_USERNAME -p $SPOKE_PASSWORD --server=$SPOKE_SERVER --insecure-skip-tls-verify=true
        info "Applying spoke yaml..."
        #apply generated yaml file
        ${OC} apply -f $work_dir/$file || error="true"
        if [[ $error == "true" ]]; then
            ${OC} login -u $HUB_USERNAME -p $HUB_PASSWORD --server=$HUB_SERVER --insecure-skip-tls-verify=true
            error "Failed to apply spoke yaml on spoke cluster $SPOKE_SERVER. Logging back into hub cluster $HUB_SERVER."
        fi
        info "Waiting for BR Agent service to install on spoke cluster $SPOKE_SERVER..."
        retries=15
        loop=0
        while [[ $(${OC} get fusionserviceinstance ibm-backup-restore-agent-service-instance -n $SF_NAMESPACE -o jsonpath='{.status.installStatus.status}') != "Completed" ]] && [[ $retries > 0 ]]; do
            sleep 30
            progress=$(${OC} get fusionserviceinstance ibm-backup-restore-agent-service-instance -n $SF_NAMESPACE -o jsonpath='{.status.installStatus}')
            info "Install progress: $progress"
            retries=$((retries-1))
            if [[ $(${OC} get fusionserviceinstance ibm-backup-restore-agent-service-instance -n $SF_NAMESPACE -o jsonpath='{.status.installStatus.status}') != "Completed" ]] && [[ $retries == 0 ]] && [[ $loop == 0 ]]; then
                warning "Editing dataprotectionagent CR to restart idp-agent-operator reconcile..."
                dpagent=$(${OC} get dataprotectionagent -n $BR_SERVICE_NAMESPACE --no-headers | awk '{print $1}')
                ${OC} patch dataprotectionagent $dpagent -n $BR_SERVICE_NAMESPACE --type='merge' -p '{"spec":{"transactionManager":{"logLevel":"DEBUG"}}}' || error "Unable to edit dataprotectionagent CR $dpagent in namespace $BR_SERVICE_NAMESPACE."
                retries=15
                loop=$((loop++))
            fi
        done
        if [[ $(${OC} get fusionserviceinstance ibm-backup-restore-agent-service-instance -n $SF_NAMESPACE -o jsonpath='{.status.installStatus.status}') != "Completed" ]] && [[ $retries == 0 ]]; then
            ${OC} login -u $HUB_USERNAME -p $HUB_PASSWORD --server=$HUB_SERVER --insecure-skip-tls-verify=true
            error "Timed out waiting for agent service install to come ready on spoke cluster $SPOKE_SERVER. Reconnecting to hub cluster $HUB_SERVER."
        fi
        
        info "Re-connecting to hub cluster $HUB_SERVER"
        #oc login to the hub cluster
        ${OC} login -u $HUB_USERNAME -p $HUB_PASSWORD --server=$HUB_SERVER --insecure-skip-tls-verify=true
        success "Spectrum Fusion and Backup and Restore Spoke Service installed."
    fi

}

function create_sf_resources(){
    title "Creating Spectrum Fusion BR resources in namespace $SF_NAMESPACE."

    if [ -d "templates" ]; then
        rm -rf templates
    fi

    mkdir templates
    info "Copying template files..."
    cp ../velero/spectrum-fusion/application.yaml ./templates/application.yaml
    cp ../velero/spectrum-fusion/backup_storage_location_secret.yaml ./templates/backup_storage_location_secret.yaml
    cp ../velero/spectrum-fusion/backup_storage_location.yaml ./templates/backup_storage_location.yaml
    cp ../velero/spectrum-fusion/policy_assignment.yaml ./templates/policy_assignment.yaml
    cp ../velero/spectrum-fusion/policy.yaml ./templates/policy.yaml

    info "Editing backup storage location resources..."
    #backup storage secret
    sed -i -E "s/<location name>/$BACKUP_STORAGE_LOCATION_NAME/" ./templates/backup_storage_location_secret.yaml
    sed -i -E "s/<spectrum fusion ns>/$SF_NAMESPACE/" ./templates/backup_storage_location_secret.yaml
    encoded_access_key=$(echo $STORAGE_SECRET_ACCESS_KEY | tr -d '\n' | base64 -w 0)
    sed -i -E "s/<base 64 encoded secret access key>/$encoded_access_key/" ./templates/backup_storage_location_secret.yaml
    encoded_access_key_id=$(echo $STORAGE_SECRET_ACCESS_KEY_ID | tr -d '\n' | base64 -w 0)
    sed -i -E "s/<base 64 encoded access key id>/$encoded_access_key_id/" ./templates/backup_storage_location_secret.yaml
    
    #backup storage location
    sed -i -E "s/<location name>/$BACKUP_STORAGE_LOCATION_NAME/" ./templates/backup_storage_location.yaml
    sed -i -E "s/<spectrum fusion ns>/$SF_NAMESPACE/" ./templates/backup_storage_location.yaml
    sed -i -E "s/<bucket name>/$STORAGE_BUCKET_NAME/" ./templates/backup_storage_location.yaml
    #s3 url is breaking the sed command somehow, must be something in how the url is entered, maybe need to escape characters in the env.properties file
    #escaping the : and // after https worked
    sed -i -E "s/<s3 url>/$S3_URL/" ./templates/backup_storage_location.yaml
    ${OC} apply -f ./templates/backup_storage_location_secret.yaml -f ./templates/backup_storage_location.yaml || error "Unable to create backup storage location resources to namespace $SF_NAMESPACE."
    
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
    info "All namespaces ${all_namespaces[*]}"
    if [[ $DYNAMIC == "false" ]]; then
        #application
        info "Editing application resource..."
        update_application_namespaces ./templates/application.yaml "${all_namespaces[@]}"
        # sed -i -E "s/<operator namespace>/$OPERATOR_NS/" ./templates/application.yaml
        # sed -i -E "s/<service namespace>/$SERVICES_NS/" ./templates/application.yaml
        # sed -i -E "s/<tenant namespace 1>/$TETHERED_NAMESPACE1/" ./templates/application.yaml
        # sed -i -E "s/<tenant namespace 2>/$TETHERED_NAMESPACE2/" ./templates/application.yaml
        # sed -i -E "s/<cert manager namespace>/$CERT_MANAGER_NAMESPACE/" ./templates/application.yaml
        # sed -i -E "s/<licensing namespace>/$LICENSING_NAMESPACE/" ./templates/application.yaml
        # sed -i -E "s/<lsr namespace>/$LSR_NAMESPACE/" ./templates/application.yaml
        sed -i -E "s/<spectrum fusion ns>/$SF_NAMESPACE/" ./templates/application.yaml

        ${OC} apply -f ./templates/application.yaml || error "Unable to create application in namespace $SF_NAMESPACE."

        #backup policy
        info "Editing backup policy resource..."
        sed -i -E "s/<storage_location>/$BACKUP_STORAGE_LOCATION_NAME/" ./templates/policy.yaml
        ${OC} apply -f ./templates/policy.yaml -n $SF_NAMESPACE || error "Unable to create policy in namespace $SF_NAMESPACE."

        #policyassignment
        info "Editing policy assignment resource..."
        sed -i -E "s/<spectrum fusion ns>/$SF_NAMESPACE/" ./templates/policy_assignment.yaml
        recipe_name="cs-recipe"
        sed -i -E "s/<recipe namespace>/$SF_NAMESPACE/" ./templates/policy_assignment.yaml
        sed -i -E "s/<recipe name>/$recipe_name/" ./templates/policy_assignment.yaml
        ${OC} apply -f ./templates/policy_assignment.yaml || error "Unable to create policy assignment in namespace $SF_NAMESPACE."

        cp ../velero/spectrum-fusion/recipes/4.7-example-recipe-multi-ns.yaml ./templates/multi-ns-recipe.yaml
        #non-dynamic recipe
        info "Editing recipe resource..."
        sed -i -E "s/<operator namespace>/$OPERATOR_NS/" ./templates/multi-ns-recipe.yaml
        sed -i -E "s/<service namespace>/$SERVICES_NS/" ./templates/multi-ns-recipe.yaml
        sed -i -E "s/<cert manager namespace>/$CERT_MANAGER_NAMESPACE/" ./templates/multi-ns-recipe.yaml
        sed -i -E "s/<licensing namespace>/$LICENSING_NAMESPACE/" ./templates/multi-ns-recipe.yaml
        sed -i -E "s/<lsr namespace>/$LSR_NAMESPACE/" ./templates/multi-ns-recipe.yaml
        sed -i -E "s/<zenservice name>/$ZENSERVICE_NAME/" ./templates/multi-ns-recipe.yaml
        sed -i -E "s/<spectrum fusion ns>/$SF_NAMESPACE/" ./templates/multi-ns-recipe.yaml
        
        tethered_namespaces="$TETHERED_NAMESPACE1,$TETHERED_NAMESPACE2"
        sed -i -E "s/<comma delimited \(no spaces\) list of Cloud Pak workload namespaces that use this foundational services instance>/$tethered_namespaces/" ./templates/multi-ns-recipe.yaml
        sed -i -E "s/<foundational services version number in use i.e. 4.0, 4.1, 4.2, etc>/$CPFS_VERSION/" ./templates/multi-ns-recipe.yaml
        size=$(${OC} get commonservice common-service -n $OPERATOR_NS -o jsonpath='{.spec.size}')
        sed -i -E "s/<.spec.size value from commonservice cr>/$size/" ./templates/multi-ns-recipe.yaml
        sed -i -E "s/<install mode, either Manual or Automatic>/Automatic/" ./templates/multi-ns-recipe.yaml
        sed -i -E "s/<catalog source name>/$CS_CATALOG_SOURCE/" ./templates/multi-ns-recipe.yaml
        sed -i -E "s/<catalog source namespace>/$CAT_SRC_NS/" ./templates/multi-ns-recipe.yaml

        if [[ $change_ns == "true" ]]; then
            ${YQ} -i '.metadata.namesace = "'${SF_NAMESPACE}'"' ./templates/multi-ns-recipe.yaml || error "Could not update namespace value in multi-ns-recipe.yaml."
        fi
        ${OC} apply -f ./templates/multi-ns-recipe.yaml || error "Unable to create recipe in namespace $SF_NAMESPACE."
    else
        #core recipes
        if [[ $NO_OLM == "true" ]]; then
            cp ../velero/spectrum-fusion/recipes/no-olm/core/child-csdb-recipe-2.10.0.yaml ./templates/child-csdb-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/no-olm/core/child-zen-recipe-2.10.0.yaml ./templates/child-zen-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/no-olm/core/parent-cpfs-recipe.yaml ./templates/parent-cpfs-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/no-olm/core/child-cs-odlm-chart-recipe.yaml ./templates/child-cs-odlm-chart-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/no-olm/core/child-edb-chart-recipe.yaml ./templates/child-edb-chart-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/no-olm/core/child-im-ui-chart-recipe.yaml ./templates/child-im-ui-chart-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/no-olm/core/child-nss-chart-recipe.yaml ./templates/child-nss-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/no-olm/core/child-zen-chart-recipe.yaml ./templates/child-zen-chart-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/no-olm/core/peripheral-resources.yaml ./templates/peripheral-resources.yaml
        else
            cp ../velero/spectrum-fusion/recipes/dynamic-recipes/core/child-csdb-recipe-2.10.0.yaml ./templates/child-csdb-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/dynamic-recipes/core/child-zen-recipe-2.10.0.yaml ./templates/child-zen-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/dynamic-recipes/core/child-nss-recipe.yaml ./templates/child-nss-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/dynamic-recipes/core/parent-cpfs-recipe.yaml ./templates/parent-cpfs-recipe.yaml
            cp ../velero/spectrum-fusion/recipes/dynamic-recipes/core/peripheral-resources.yaml ./templates/peripheral-resources.yaml
        fi    
        info "Editing Application Resource..."
        local dynamic_namespaces=("${namespaces[@]}" "${tethered_array[@]}" "${extra_namespaces[@]}")
        info "namespaces: ${dynamic_namespaces[*]}"
        update_application_namespaces ./templates/peripheral-resources.yaml "${dynamic_namespaces[@]}"
        
        info "Editing Backup Policy Resource..."
        sed -i -E "s/<location name>/$BACKUP_STORAGE_LOCATION_NAME/" ./templates/peripheral-resources.yaml
        
        info "Editing Policy Assignment Resource..."
        recipe_name="cs-core"
        sed -i -E "s/<fusion ns>/$SF_NAMESPACE/" ./templates/peripheral-resources.yaml
        sed -i -E "s/<parent recipe namespace>/$OPERATOR_NS/" ./templates/peripheral-resources.yaml
        sed -i -E "s/<recipe name>/$recipe_name/" ./templates/peripheral-resources.yaml

        ${OC} apply -f ./templates/peripheral-resources.yaml || error "Unable to create either application, backup policy, or policy assignment in namespace $SF_NAMESPACE."
        
        info "Editing recipe resources..."
        #parent
        sed -i -E "s/<parent recipe namespace>/$OPERATOR_NS/" ./templates/parent-cpfs-recipe.yaml
        #im
        sed -i -E "s/<parent recipe namespace>/$OPERATOR_NS/" ./templates/child-csdb-recipe.yaml
        sed -i -E "s/<child recipe namespace>/$SERVICES_NS/" ./templates/child-csdb-recipe.yaml
        #nss
        sed -i -E "s/<parent recipe namespace>/$OPERATOR_NS/" ./templates/child-nss-recipe.yaml
        sed -i -E "s/<child recipe namespace>/$OPERATOR_NS/" ./templates/child-nss-recipe.yaml
        #zen
        sed -i -E "s/<parent recipe namespace>/$OPERATOR_NS/" ./templates/child-zen-recipe.yaml
        sed -i -E "s/<zenservice name>/$ZENSERVICE_NAME/" ./templates/child-zen-recipe.yaml
        sed -i -E "s/<child recipe namespace>/$SERVICES_NS/" ./templates/child-zen-recipe.yaml
        if [[ $NO_OLM == "true" ]]; then
            sed -i -E "s/<parent recipe namespace>/$OPERATOR_NS/" ./templates/child-cs-odlm-chart-recipe.yaml
            sed -i -E "s/<parent recipe namespace>/$OPERATOR_NS/" ./templates/child-edb-chart-recipe.yaml
            sed -i -E "s/<parent recipe namespace>/$OPERATOR_NS/" ./templates/child-im-ui-chart-recipe.yaml
            sed -i -E "s/<parent recipe namespace>/$OPERATOR_NS/" ./templates/child-zen-chart-recipe.yaml

            sed -i -E "s/<child recipe namespace>/$OPERATOR_NS/" ./templates/child-cs-odlm-chart-recipe.yaml
            sed -i -E "s/<child recipe namespace>/$OPERATOR_NS/" ./templates/child-edb-chart-recipe.yaml
            sed -i -E "s/<child recipe namespace>/$OPERATOR_NS/" ./templates/child-im-ui-chart-recipe.yaml
            sed -i -E "s/<child recipe namespace>/$OPERATOR_NS/" ./templates/child-zen-chart-recipe.yaml
            
            sed -i -E "s/<operator_ns>/$OPERATOR_NS/" ./templates/child-cs-odlm-chart-recipe.yaml
            sed -i -E "s/<operator_ns>/$OPERATOR_NS/" ./templates/child-edb-chart-recipe.yaml
            sed -i -E "s/<operator_ns>/$OPERATOR_NS/" ./templates/child-im-ui-chart-recipe.yaml
            sed -i -E "s/<operator_ns>/$OPERATOR_NS/" ./templates/child-zen-chart-recipe.yaml
        fi

        #apply recipes
        ${OC} apply -f ./templates/parent-cpfs-recipe.yaml || error "Unable to create core parent recipe in namespace $OPERATOR_NS."
        if [[ $NO_OLM == "true" ]]; then
            ${OC} apply -f ./templates/child-cs-odlm-chart-recipe.yaml || error "Unable to create Installer chart child recipe in namespace $OPERATOR_NS."
        fi
        if [[ $IM_ENABLED == "true" ]]; then
            ${OC} apply -f ./templates/child-csdb-recipe.yaml || error "Unable to create IM child recipe in namespace $SERVICES_NS."
            if [[ $NO_OLM == "true" ]]; then
                ${OC} apply -f ./templates/child-im-ui-chart-recipe.yaml || error "Unable to create IM chart child recipe in namespace $OPERATOR_NS."
                ${OC} apply -f ./templates/child-edb-chart-recipe.yaml || error "Unable to create EDB chart child recipe in namespace $OPERATOR_NS."
            fi
        fi
        if [[ $ZEN_ENABLED == "true" ]]; then
            ${OC} apply -f ./templates/child-zen-recipe.yaml || error "Unable to create Zen child recipe in namespace $SERVICES_NS."
            if [[ $NO_OLM == "true" ]]; then
                ${OC} apply -f ./templates/child-zen-chart-recipe.yaml || error "Unable to create Zen chart child recipe in namespace $OPERATOR_NS."
                if [[ $IM_ENABLED != "true" ]]; then
                    ${OC} apply -f ./templates/child-edb-chart-recipe.yaml || error "Unable to create EDB chart child recipe in namespace $OPERATOR_NS."
                fi
            fi
        fi
        if [[ $NSS_ENABLED == "true" ]]; then
            ${OC} apply -f ./templates/child-nss-recipe.yaml || error "Unable to create NSS child recipe in namespace $OPERATOR_NS."
        fi

        #singleton recipes
        if [[ $ENABLE_CERT_MANAGER == "true" ]] || [[ $ENABLE_LICENSING == "true" ]] || [[ $ENABLE_LSR == "true" ]]; then
            info "Editing singleton fusion resources..."
            if [[ $NO_OLM == "true" ]]; then
                cp ../velero/spectrum-fusion/recipes/no-olm/singletons/parent-singleton-recipe.yaml ./templates/parent-singleton-recipe.yaml
                cp ../velero/spectrum-fusion/recipes/no-olm/singletons/peripheral-resources.yaml ./templates/peripheral-resources.yaml
            else
                cp ../velero/spectrum-fusion/recipes/dynamic-recipes/singletons/parent-singleton-recipe.yaml ./templates/parent-singleton-recipe.yaml
                cp ../velero/spectrum-fusion/recipes/dynamic-recipes/singletons/peripheral-resources.yaml ./templates/peripheral-resources.yaml
            fi
            #edit parent recipe
            sed -i -E "s/<fusion ns>/$SF_NAMESPACE/" ./templates/parent-singleton-recipe.yaml
            #edit peripheral resources
            local dynamic_singleton_namespaces=("${extra_namespaces[@]}" "${singleton_namespaces[@]}")
            info "dynamic singleton namespaces ${dynamic_singleton_namespaces[*]}"
            update_application_namespaces ./templates/peripheral-resources.yaml "${dynamic_singleton_namespaces[@]}"
            sed -i -E "s/<fusion ns>/$SF_NAMESPACE/" ./templates/peripheral-resources.yaml
            sed -i -E "s/<location name>/$BACKUP_STORAGE_LOCATION_NAME/" ./templates/peripheral-resources.yaml
            # sed -i -E "s/<cert manager namespace>/$CERT_MANAGER_NAMESPACE/" ./templates/peripheral-resources.yaml
            # sed -i -E "s/<licensing namespace>/$LICENSING_NAMESPACE/" ./templates/peripheral-resources.yaml
            # sed -i -E "s/<lsr namespace>/$LSR_NAMESPACE/" ./templates/peripheral-resources.yaml
            sed -i -E "s/<s3 url>/$S3_URL/" ./templates/peripheral-resources.yaml

            encoded_access_key=$(echo $STORAGE_SECRET_ACCESS_KEY | tr -d '\n' | base64 -w 0)
            sed -i -E "s/<base 64 encoded secret access key>/$encoded_access_key/" ./templates/peripheral-resources.yaml
            encoded_access_key_id=$(echo $STORAGE_SECRET_ACCESS_KEY_ID | tr -d '\n' | base64 -w 0)
            sed -i -E "s/<base 64 encoded access key id>/$encoded_access_key_id/" ./templates/peripheral-resources.yaml
            
            ${OC} apply -f ./templates/parent-singleton-recipe.yaml || error "Unable to create singleton parent recipe in namespace $SF_NAMESPACE."
            ${OC} apply -f ./templates/peripheral-resources.yaml || error "Unable to create singleton peripheral resources in namespace $SF_NAMESPACE."
            
            if [[ $ENABLE_CERT_MANAGER == "true" ]]; then
                if [[ $NO_OLM == "true" ]]; then
                    cp ../velero/spectrum-fusion/recipes/no-olm/singletons/child-cert-manager-recipe.yaml ./templates/child-cert-manager-recipe.yaml
                else
                    cp ../velero/spectrum-fusion/recipes/dynamic-recipes/singletons/child-cert-manager-recipe.yaml ./templates/child-cert-manager-recipe.yaml
                fi
                #edit cm child recipe
                sed -i -E "s/<cert manager namespace>/$CERT_MANAGER_NAMESPACE/" ./templates/child-cert-manager-recipe.yaml
                sed -i -E "s/<fusion ns>/$SF_NAMESPACE/" ./templates/child-cert-manager-recipe.yaml
                ${OC} apply -f ./templates/child-cert-manager-recipe.yaml || error "Unable to create cert manager child recipe in namespace $CERT_MANAGER_NAMESPACE."
            fi
            if [[ $ENABLE_LICENSING == "true" ]]; then
                if [[ $NO_OLM == "true" ]]; then
                    cp ../velero/spectrum-fusion/recipes/no-olm/singletons/child-licensing-recipe.yaml ./templates/child-licensing-recipe.yaml
                else
                    cp ../velero/spectrum-fusion/recipes/dynamic-recipes/singletons/child-licensing-recipe.yaml ./templates/child-licensing-recipe.yaml
                fi
                #edit licensing child recipe
                sed -i -E "s/<licensing namespace>/$LICENSING_NAMESPACE/" ./templates/child-licensing-recipe.yaml
                sed -i -E "s/<fusion ns>/$SF_NAMESPACE/" ./templates/child-licensing-recipe.yaml
                ${OC} apply -f ./templates/child-licensing-recipe.yaml || error "Unable to create licensing child recipe in namespace $LICENSING_NAMESPACE."
            fi
            if [[ $ENABLE_LSR == "true" ]]; then
                if [[ $NO_OLM == "true" ]]; then
                    cp ../velero/spectrum-fusion/recipes/no-olm/singletons/child-ls-reporter-recipe.yaml ./templates/child-ls-reporter-recipe.yaml
                else
                    cp ../velero/spectrum-fusion/recipes/dynamic-recipes/singletons/child-ls-reporter-recipe.yaml ./templates/child-ls-reporter-recipe.yaml
                fi
                #edit lsr child recipe
                sed -i -E "s/<lsr namespace>/$LSR_NAMESPACE/" ./templates/child-ls-reporter-recipe.yaml
                sed -i -E "s/<fusion ns>/$SF_NAMESPACE/" ./templates/child-ls-reporter-recipe.yaml
                ${OC} apply -f ./templates/child-ls-reporter-recipe.yaml || error "Unable to create license service reporter child recipe in namespace $LSR_NAMESPACE."
            fi
        fi
    fi
    
    success "Spectrum Fusion BR resources created in namespace $SF_NAMESPACE."

}

function deploy_cs_br_resources() {
    title "Deploying necessary BR resources for persistent CPFS components."
    # cd ../velero/schedule
    deploy_arg_str=""
    if [[ $SERVICES_NS != $OPERATOR_NS ]]; then
        deploy_arg_str="--services-ns $SERVICES_NS"
    else
        deploy_arg_str="--operator-ns $OPERATOR_NS"
    fi
    if [[ $ENABLE_LSR == "true" ]]; then
        deploy_arg_str="$deploy_arg_str --lsr-ns $LSR_NAMESPACE --lsr"
    fi
    if [[ $IM_ENABLED == "true" ]] || [[ $ZEN_ENABLED == "true" ]] || [[ $ENABLE_LSR == "true" ]]; then
        if [[ $IM_ENABLED == "true" ]]; then
            deploy_arg_str="$deploy_arg_str --im"
        fi
        if [[ $ZEN_ENABLED == "true" ]]; then
            deploy_arg_str="$deploy_arg_str --zen"
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
            wait_for_deployment $SERVICES_NS "zen5-backup" 
        fi
        if [[ $ENABLE_LSR == "true" ]]; then
            wait_for_deployment $LSR_NAMESPACE "lsr-backup" 
        fi
    fi
    success "BR resources for persistent CPFS components deployed."
}

function label_cs_resources() {
    title "Labeling CS resources."

    info "Labeling cert manager resources..."
    ./../velero/backup/cert-manager/label-cert-manager.sh || error "Unable to complete labeling of cert manager resources."
    
    label_arg_str="--operator-ns $OPERATOR_NS"
    if [[ $SERVICES_NS != $OPERATOR_NS ]]; then
        label_arg_str="$label_arg_str --services-ns $SERVICES_NS"
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
    success "CPFS resources labeled."
}

function check_yq() {
  yq_version=$("${YQ}" --version | awk '{print $NF}' | sed 's/^v//')
  yq_minimum_version=4.18.1

  if [ "$(printf '%s\n' "$yq_minimum_version" "$yq_version" | sort -V | head -n1)" != "$yq_minimum_version" ]; then 
    error "yq version $yq_version must be at least $yq_minimum_version or higher.\nInstructions for installing/upgrading yq are available here: https://github.com/marketplace/actions/yq-portable-yaml-processor"
  fi
}

function update_application_namespaces() {
    local file="$1"
    shift
    local namespaces=("$@")
    info "Updating application in file $file with namespaces $namespaces..."

    # Create temp files
    local temp_dir=$(mktemp -d)
    local app_file="$temp_dir/app.yaml"
    local others_file="$temp_dir/others.yaml"
    
    # Extract documents
    ${YQ} eval 'select(.kind == "Application")' "$file" > "$app_file"
    ${YQ} eval 'select(.kind != "Application")' "$file" > "$others_file"
    
    # Build namespace array
    local json_array="["
    for i in "${!namespaces[@]}"; do
        [ $i -gt 0 ] && json_array+=","
        json_array+="\"${namespaces[$i]}\""
    done
    json_array+="]"
    
    # Update Application file
    ${YQ} eval ".spec.includedNamespaces = $json_array" -i "$app_file"
    
    # Reconstruct file
    cat "$app_file" > "$file"
    if [ -s "$others_file" ]; then
        echo "---" >> "$file"
        cat "$others_file" >> "$file"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
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