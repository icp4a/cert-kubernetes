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

# set -o errexit
set -o pipefail
set -o errtrace
set -o nounset

OC=oc
YQ=yq
ORIGINAL_NAMESPACE=
TARGET_NAMESPACE=
backup="false"
restore="false"
cleanup="false"
s390x_ENV="false"
DEBUG=0

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# ---------- Main functions ----------

. $BASE_DIR/../cp3pt0-deployment/common/utils.sh

function main() {
    while [ "$#" -gt "0" ]
    do
        case "$1" in
        "-h"|"--help")
            usage
            exit 0
            ;;
        "--bns")
            ORIGINAL_NAMESPACE=$2
            shift
            ;;
        "--rns")
            TARGET_NAMESPACE=$2
            shift
            ;;
        "-b")
            backup="true"
            ;;
        "-r")
            restore="true"
            ;;
        "-c")
            cleanup="true"
            ;;
        "-v")
            shift
            DEBUG=$1
            ;;
        *)
            error "invalid option -- \`$1\`. Use the -h or --help option for usage info."
            ;;
        esac
        shift
    done

    msg "MongoDB Backup and Restore v1.0.0"
    prereq
    
    if [[ $backup == "true" ]]; then
        prep_backup
        backup
    fi
    if [[ $restore == "true" ]]; then
        prep_restore
        restore
        check_ldap_secret
        refresh_auth_idp
    fi
    if [[ $cleanup == "true" ]]; then
    cleanup
    fi
}

function usage() {
	local script="${0##*/}"

	while read -r ; do echo "${REPLY}" ; done <<-EOF
	Usage: ${script} [OPTION]...
	Migrate Mongo data across Common Service instances
	Options:
	Mandatory arguments to long options are mandatory for short options too.
	  -h, --help                    display this help and exit
      --bns                         specify the namespace to backup/where the backup exists
      --rns                         specify the namespace where data is to be restored
      -b                            run the backup process
      -r                            run the restore process
      -c                            cleanup resources used or created by this script
      -v, --debug integer           verbosity of logs. Default is 0. Set to 1 for debug logs
	EOF
}

# verify that all pre-requisite CLI tools exist and parameters set
function prereq() {
    which "${OC}" || error "Missing oc CLI"
    which "${YQ}" || error "Missing yq"

    if [[ -z $ORIGINAL_NAMESPACE ]] && [[ -z $TARGET_NAMESPACE ]]; then
        error "Neither backup nor restore namespaces were set. Use -h or --help to see script usage options"
    elif [[ -z $ORIGINAL_NAMESPACE ]] && [[ $cleanup == "false" ]]; then
        if [[ $backup == "true" || $restore == "true" ]]; then
            error "Backup namespace not specified. Please specify backup namespace with --bns. Use -h or --help for script usage"
        fi
    fi
    
    if [[ $backup == "false" ]] && [[ $restore == "false" ]] && [[ $cleanup == "false" ]]; then
        error "Neither backup nor restore processes were triggered. Use -h or --help to see script usage options"
    fi

    if [[ $restore == "true" ]] && [[ -z $TARGET_NAMESPACE ]]; then
        error "Restore selected but no restore namespace provided with \"--rns\" parameter. Use -h or --help to see script usage options"
    fi

    mongo_node=$(${OC} get pods -n $ORIGINAL_NAMESPACE -o wide | grep icp-mongodb-0 | awk '{print $7}')
    architecture=$(${OC} describe node $mongo_node | grep "Architecture:" | awk '{print $2}')
    if [[ $architecture == "s390x" ]]; then
      s390x_ENV="true"
      info "Z cluster detected, be prepared for multiple restarts of mongo pods. This is expected behavior."
      mongo_op_scaled_original=$(${OC} get deploy -n $ORIGINAL_NAMESPACE | grep ibm-mongodb-operator | egrep '1/1' || echo false)
      if [[ $mongo_op_scaled_original == "false" ]]; then
        info "Mongo operator in $ORIGINAL_NAMESPACE still scaled down, scaling up."
        ${OC} scale deploy -n $ORIGINAL_NAMESPACE ibm-mongodb-operator --replicas=1
        info "Wait for mongo operator to reconcile resources"
        sleep 60
        delete_mongo_pods "$ORIGINAL_NAMESPACE"
      fi
      mongo_op_scaled_target=$(${OC} get deploy -n $TARGET_NAMESPACE | grep ibm-mongodb-operator | egrep '1/1' || echo false)
      if [[ $mongo_op_scaled_target == "false" ]]; then
        info "Mongo operator in $TARGET_NAMESPACE still scaled down, scaling up."
        ${OC} scale deploy -n $TARGET_NAMESPACE ibm-mongodb-operator --replicas=1
        info "Wait for mongo operator to reconcile resources"
        sleep 60
        delete_mongo_pods "$TARGET_NAMESPACE"
      fi
    fi

    runningmongo_original=$(${OC} get po icp-mongodb-0 --no-headers --ignore-not-found -n $ORIGINAL_NAMESPACE | awk '{print $3}')
    if [[ -z "$runningmongo_original" ]] || [[ "$runningmongo_original" != "Running" ]]; then
        error "Mongodb is not running in Namespace $ORIGINAL_NAMESPACE"
    fi

    if [[ -z $TARGET_NAMESPACE ]]; then
        info "Restore not specified, skipping check for mongo in restore namespace..."
    else
        runningmongo_target=$(${OC} get po icp-mongodb-0 --no-headers --ignore-not-found -n $TARGET_NAMESPACE | awk '{print $3}')
        if [[ -z "$runningmongo_target" ]] || [[ "$runningmongo_target" != "Running" ]]; then
            error "Mongodb is not running in Namespace $TARGET_NAMESPACE"
        fi
    fi

    success "Prerequisites present."
}

function prep_backup() {
    title " Preparing for Mongo backup in namespace $ORIGINAL_NAMESPACE "
    msg "-----------------------------------------------------------------------"
    
    #check if files are already present on machine before trying to download (airgap)
    #TODO add clarifying messages and check response code to make more transparent
    #backup files
    info "Checking for necessary backup files..."
    if [[ $s390x_ENV == "false" ]]; then
        if [[ -f "mongodbbackup.yaml" ]]; then
            info "mongodbbackup.yaml already present"
        else
            info "mongodbbackup.yaml not found, downloading from https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongodbbackup.yaml"
            wget -O mongodbbackup.yaml https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongodbbackup.yaml || error "Failed to download mongodbbackup.yaml"
        fi
    else
        if [[ -f "mongodbbackup-z.yaml" ]]; then
            info "mongodbbackup-z.yaml already present"
        else
            info "mongodbbackup-z.yaml not found, downloading from https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongodbbackup-z.yaml"
            wget -O mongodbbackup-z.yaml https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongodbbackup-z.yaml || error "Failed to download mongodbbackup-z.yaml"
        fi
    fi

    if [[ -f "mongo-backup.sh" ]]; then
        info "mongo-backup.sh already present"
    else
        info "mongo-backup.sh not found, downloading from https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongo-backup.sh"
        wget -O mongo-backup.sh https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongo-backup.sh
    fi

    success "Backup prep complete"
}

function backup() {
    title " Backing up MongoDB in namespace $ORIGINAL_NAMESPACE "
    msg "-----------------------------------------------------------------------"
    export CS_NAMESPACE=$ORIGINAL_NAMESPACE
    export ibm_mongodb_image=$(${OC} get pod icp-mongodb-0 -n $ORIGINAL_NAMESPACE -o=jsonpath='{range .spec.containers[0]}{.image}{end}')
    local pvx=$(${OC} get pv | grep mongodbdir | awk 'FNR==1 {print $1}')
    local storageClassName=$("${OC}" get pv -o yaml ${pvx} | yq '.spec.storageClassName' | awk '{print}')
    if [[ $s390x_ENV == "true" ]]; then
        info "Z cluster detected"
        info "Scaling down MongoDB operator"
        ${OC} scale deploy -n $ORIGINAL_NAMESPACE ibm-mongodb-operator --replicas=0
        #get cache size value
        cacheSizeGB=$(${OC} get cm icp-mongodb -n $ORIGINAL_NAMESPACE -o yaml | grep cacheSizeGB | awk '{print $2}')
        
        info "Editing configmap icp-mongodb"
        cat << EOF | ${OC} apply -n $ORIGINAL_NAMESPACE -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: icp-mongodb
  labels:
    app.kubernetes.io/component: database
    app.kubernetes.io/instance: icp-mongodb
    app.kubernetes.io/managed-by: operator
    app.kubernetes.io/name: icp-mongodb
    app.kubernetes.io/part-of: common-services-cloud-pak
    app.kubernetes.io/version: 4.0.12-build.3
    release: mongodb
data:
  mongod.conf: |-
    storage:
      dbPath: /data/db
      wiredTiger:
        engineConfig:
          cacheSizeGB: $cacheSizeGB
    net:
      bindIpAll: true
      port: 27017
      ssl:
        mode: preferSSL
        CAFile: /data/configdb/tls.crt
        PEMKeyFile: /work-dir/mongo.pem
    replication:
      replSetName: rs0
    # Uncomment for TLS support or keyfile access control without TLS
    security:
      authorization: enabled
      keyFile: /data/configdb/key.txt
EOF
        delete_mongo_pods "$ORIGINAL_NAMESPACE"
    fi
    chmod +x mongo-backup.sh
    ./mongo-backup.sh "$storageClassName" "$s390x_ENV"

    local jobPod=$(${OC} get pods -n $ORIGINAL_NAMESPACE | grep mongodb-backup | awk '{ print $1 }')
    local fileName="backup_from_${ORIGINAL_NAMESPACE}_for_${TARGET_NAMESPACE}.log"
    ${OC} logs $jobPod -n $ORIGINAL_NAMESPACE > $fileName
    info "Backup logs can be found in $fileName. Job pod will be cleaned up."

    info "Verify cs-mongodump PVC exists..."
    local return_value=$("${OC}" get pvc -n $ORIGINAL_NAMESPACE | grep cs-mongodump || echo failed)
    if [[ $return_value == "failed" ]]; then
        error "Backup PVC cs-mongodump not found"
    else
        return_value="reset"
        info "Backup PVC cs-mongodump found"
        
        VOL=$(${OC} get pvc cs-mongodump -n $ORIGINAL_NAMESPACE  -o=jsonpath='{.spec.volumeName}')
        ${OC} patch pv $VOL -p '{"spec": { "persistentVolumeReclaimPolicy" : "Retain" }}'
        
        return_value=$(${OC} get pvc cs-mongodump -n $ORIGINAL_NAMESPACE -o yaml | yq '.spec.storageClassName' | awk '{print}')
        if [[ "$return_value" != "$storageClassName" ]]; then
            error "Backup PVC cs-mongodump not bound to persistent volume provisioned by correct storage class. Provisioned by \"${return_value}\" instead of \"$storageClassName\""
            #TODO probably need to handle this situation as the script may not be able to handle it as is
            #should be an edge case though as script is designed to attach to specific pv
        else
            info "Backup PVC cs-mongodump successfully bound to persistent volume provisioned by $storageClassName storage class."
        fi
    fi
    if [[ $s390x_ENV == "true" ]]; then
        #reset changes for z environment
        info "Reverting change to icp-mongodb configmap" 
        delete_mongo_pods "$ORIGINAL_NAMESPACE"
        info "Scale mongo operator back up to 1"
        #scaling back up to one will reset the icp-mongodb configmap
        ${OC} scale deploy -n $ORIGINAL_NAMESPACE ibm-mongodb-operator --replicas=1
    fi
    success "MongoDB successfully backed up"
}

function prep_restore() {
    title " Pepare for restore in namespace $TARGET_NAMESPACE "
    msg "-----------------------------------------------------------------------"
    
    #Restore files
    info "Checking for necessary restore files..."
    if [[ $s390x_ENV == "false" ]]; then
        if [[ -f "mongodbrestore.yaml" ]]; then
            info "mongodbrestore.yaml already present"
        else
            info "mongodbrestore.yaml not found, downloading from https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongodbrestore.yaml"
            wget -O mongodbrestore.yaml https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongodbrestore.yaml || error "Failed to download mongodbrestore.yaml"
        fi
    else
        if [[ -f "mongodbrestore-z.yaml" ]]; then
            info "mongodbrestore-z.yaml already present"
        else
            info "mongodbrestore-z.yaml not found, downloading from https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongodbrestore-z.yaml"
            wget -O mongodbrestore-z.yaml https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongodbrestore-z.yaml || error "Failed to download mongodbrestore-z.yaml"
        fi
    fi

    if [[ -f "set_access.js" ]]; then
        info "set_access.js already present"
    else
        info "set_access.js not found, downloading from https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/set_access.js"
        wget -O set_access.js https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/set_access.js || error "Failed to download set_access.js"
    fi

    if [[ -f "mongo-restore.sh" ]]; then
        info "mongo-restore.sh already present"
    else
        info "mongo-restore.sh not found, downloading from https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongo-restore.sh"
        wget -O mongo-restore.sh https://raw.githubusercontent.com/IBM/ibm-common-service-operator/scripts/backup_restore_mongo/mongo-restore.sh || error "Failed to download mongo-restore.sh"
    fi
    
    ${OC} get pvc -n ${ORIGINAL_NAMESPACE} cs-mongodump -o yaml > cs-mongodump-copy.yaml
    # get the origin pv from the cs-mongodump pvc
    local pvx=$(${OC} get pvc cs-mongodump -n $ORIGINAL_NAMESPACE  -o=jsonpath='{.spec.volumeName}')
    export PVX=${pvx}
    ${OC} delete job mongodb-backup -n ${ORIGINAL_NAMESPACE}
    ${OC} delete pvc cs-mongodump -n ${ORIGINAL_NAMESPACE} --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        info "Failed to delete pvc cs-mongodump, patching its finalizer to null..."
        ${OC} patch pvc cs-mongodump -n ${ORIGINAL_NAMESPACE} --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi
    ${OC} patch pv ${pvx} --type=merge -p '{"spec": {"claimRef":null}}'
    
    #Check if the backup PV has come available yet
    #need to error handle, if a pv/pvc from a previous attempt exists in any ns it will mess this up
    #if cs-mongdump pvc already exists in the target namespace, it will break
    #Not sure if these checks are something to incorporate into the script or include in a troubleshooting section of the doc
    #On a fresh run where you don't have to worry about any existing pv or pvc, it works perfectly
    #New cleanup function running before and after completion should solve this problem
    local pvStatus=$("${OC}" get pv -o yaml ${pvx}| yq '.status.phase' | awk '{print}')
    local retries=6
    echo "PVX: ${pvx} PV status: ${pvStatus}"
    while [ $retries != 0 ]
    do
        if [[ "${pvStatus}" != "Available" ]]; then
            retries=$(( $retries - 1 ))
            info "Persistent Volume ${pvx} not available yet. Retries left: ${retries}. Waiting 30 seconds..."
            sleep 30s
            pvStatus=$("${OC}" get pv -o yaml ${pvx}| yq '.status.phase' | awk '{print}')
            echo "PVX: ${pvx} PV status: ${pvStatus}"
        else
            info "Persistent Volume ${pvx} available. Moving on..."
            break
        fi
    done

    # Clean up used restore resources before starting restore process
    local return_value=$("${OC}" get pvc -n $TARGET_NAMESPACE | grep cs-mongodump)
    if [[ ! -z $return_value ]]; then
        #delete retore items in target namespace
        local boundPV=$(${OC} get pvc cs-mongodump -n $TARGET_NAMESPACE -o yaml | yq '.spec.volumeName' | awk '{print}')
        ${OC} delete pvc cs-mongodump -n $TARGET_NAMESPACE --ignore-not-found --timeout=10s
        if [ $? -ne 0 ]; then
            info "Failed to delete pvc cs-mongodump, patching its finalizer to null..."
            ${OC} patch pvc cs-mongodump -n $TARGET_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
        fi
        ${OC} patch pv $boundPV --type=merge -p '{"metadata": {"finalizers":null}}'
        ${OC} delete pv $boundPV
    fi

    #edit the cs-mongodump-copy.yaml pvc file and apply it in the target namespace
    export TARGET_NAMESPACE=$TARGET_NAMESPACE
    ${YQ} -i eval 'select(.kind == "PersistentVolumeClaim") | del(.metadata.resourceVersion) | del(.metadata.uid) | del(.metadata.creationTimestamp) | del(.metadata.generation)' cs-mongodump-copy.yaml
    ${YQ} -i '.metadata.namespace=strenv(TARGET_NAMESPACE)' cs-mongodump-copy.yaml
    ${OC} apply -f cs-mongodump-copy.yaml
    
    #Check PV status to make sure it binds to the right PVC
    #If more than one pv provisioned by the sc created in this script exists, this part will break as it lists all of the pvs provisioned by backup-sc as $PVX
    pvStatus=$("${OC}" get pv -o yaml ${pvx}| yq '.status.phase' | awk '{print}')
    retries=6
    while [ $retries != 0 ]
    do
        if [[ "${pvStatus}" != "Bound" ]]; then
            retries=$(( $retries - 1 ))
            info "Persitent Volume ${pvx} not bound yet. Retries left: ${retries}. Waiting 30 seconds..."
            sleep 30s
            pvStatus=$("${OC}" get pv -o yaml ${pvx}| yq '.status.phase' | awk '{print}')
        else
            info "Persitent Volume ${pvx} bound. Checking PVC..."
            boundPV=$("${OC}" get pvc cs-mongodump -n ${TARGET_NAMESPACE} -o yaml | yq '.spec.volumeName' | awk '{print}')
            if [[ "${boundPV}" != "${pvx}" ]]; then
                error "Error binding cs-mongodump PVC to backup PV ${pvx}. Bound to ${boundPV} instead."
            else
                info "PVC cs-mongodump successfully bound to backup PV ${pvx}"
                break
            fi
        fi
    done

    success "Preparation for Restore completed successfully."
    
}

function restore () {
    title " Restore copy of backup in namespace $TARGET_NAMESPACE "
    msg "-----------------------------------------------------------------------"
    #export csnamespace to reflect the new target namespace
    #restore script is setup to look for CS_NAMESPACE and is used in other backup/restore processes unrelated to this script
    export CS_NAMESPACE=$TARGET_NAMESPACE
    export ibm_mongodb_image=$(${OC} get pod icp-mongodb-0 -n $ORIGINAL_NAMESPACE -o=jsonpath='{range .spec.containers[0]}{.image}{end}')
    if [[ $s390x_ENV == "true" ]]; then
        info "Z cluster detected"
        info "Scaling down MongoDB operator"
        ${OC} scale deploy -n $TARGET_NAMESPACE ibm-mongodb-operator --replicas=0

        #get cache size value
        cacheSizeGB=$(${OC} get cm icp-mongodb -n $TARGET_NAMESPACE -o yaml | grep cacheSizeGB | awk '{print $2}')
        
        info "Editing configmap icp-mongodb"
        cat << EOF | ${OC} apply -n $TARGET_NAMESPACE -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: icp-mongodb
  labels:
    app.kubernetes.io/component: database
    app.kubernetes.io/instance: icp-mongodb
    app.kubernetes.io/managed-by: operator
    app.kubernetes.io/name: icp-mongodb
    app.kubernetes.io/part-of: common-services-cloud-pak
    app.kubernetes.io/version: 4.0.12-build.3
    release: mongodb
data:
  mongod.conf: |-
    storage:
      dbPath: /data/db
      wiredTiger:
        engineConfig:
          cacheSizeGB: $cacheSizeGB
    net:
      bindIpAll: true
      port: 27017
      ssl:
        mode: preferSSL
        CAFile: /data/configdb/tls.crt
        PEMKeyFile: /work-dir/mongo.pem
    replication:
      replSetName: rs0
    # Uncomment for TLS support or keyfile access control without TLS
    security:
      authorization: enabled
      keyFile: /data/configdb/key.txt
EOF
        #need to delete the mongo pods one at a time
        delete_mongo_pods "$TARGET_NAMESPACE"
    fi
    chmod +x mongo-restore.sh
    ./mongo-restore.sh "$ORIGINAL_NAMESPACE" "$s390x_ENV"

    local jobPod=$(${OC} get pods -n $TARGET_NAMESPACE | grep mongodb-restore | awk '{ print $1 }')
    local fileName="restore_to_${TARGET_NAMESPACE}_from_${ORIGINAL_NAMESPACE}.log"
    ${OC} logs $jobPod -n $TARGET_NAMESPACE > $fileName
    info "Restore logs can be found in $fileName. Job pod will be cleaned up."
    if [[ $s390x_ENV == "true" ]]; then
        #reset changes for z environment
        info "Reverting change to icp-mongodb configmap" 
        delete_mongo_pods "$TARGET_NAMESPACE"
        info "Scale mongo operator back up to 1"
        #scaling back up to one will reset the icp-mongodb configmap
        ${OC} scale deploy -n $TARGET_NAMESPACE ibm-mongodb-operator --replicas=1
    fi
    success "Restore completed successfully in namespace $TARGET_NAMESPACE"

}

function cleanup(){
    title " Cleaning up resources created during backup restore process "
    msg "-----------------------------------------------------------------------"
    
    if [[ $ORIGINAL_NAMESPACE != "" ]]; then
        info "Deleting resources used in backup process from namespace $ORIGINAL_NAMESPACE"
        
        #clean up backup resources
        local return_value=$("${OC}" get pvc -n $ORIGINAL_NAMESPACE | grep cs-mongodump || echo failed)
        if [[ $return_value != "failed" ]]; then
        #delete backup items in original namespace
            ${OC} delete job mongodb-backup -n ${ORIGINAL_NAMESPACE} || info "Backup job already deleted. Moving on..."
            ${OC} delete pvc cs-mongodump -n $ORIGINAL_NAMESPACE --ignore-not-found --timeout=10s
            if [ $? -ne 0 ]; then
                info "Failed to delete pvc cs-mongodump, patching its finalizer to null..."
                ${OC} patch pvc cs-mongodump -n $ORIGINAL_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
            fi
        else
            info "Resources used in backup already cleaned up. Moving on..."
        fi

        local rbac=$(${OC} get clusterrolebinding cs-br -n $ORIGINAL_NAMESPACE || echo failed)
        if [[ $rbac != "failed" ]]; then
            info "Deleting RBAC from backup restore process"
            ${OC} delete clusterrolebinding cs-br -n $ORIGINAL_NAMESPACE
        fi

        local scExist=$(${OC} get sc backup-sc -n $ORIGINAL_NAMESPACE || echo failed)
        if [[ $scExist != "failed" ]]; then
            info "Deleting storage class used in backup restore process"
            ${OC} delete sc backup-sc
        fi
    fi

    if [[ $TARGET_NAMESPACE != "" ]]; then
        info "Deleting resources used in restore process from namespace $TARGET_NAMESPACE"
        #clean up restore resources
        local return_value=$("${OC}" get pvc -n $TARGET_NAMESPACE | grep cs-mongodump || echo failed)
        if [[ $return_value != "failed" ]]; then
        #delete retore items in target namespace
            local boundPV=$(${OC} get pvc cs-mongodump -n $TARGET_NAMESPACE -o yaml | yq '.spec.volumeName' | awk '{print}')
            ${OC} delete job mongodb-restore -n ${TARGET_NAMESPACE} || info "Restore job already deleted. Moving on..."
            ${OC} delete pvc cs-mongodump -n $TARGET_NAMESPACE --ignore-not-found --timeout=10s
            if [ $? -ne 0 ]; then
                info "Failed to delete pvc cs-mongodump, patching its finalizer to null..."
                ${OC} patch pvc cs-mongodump -n $TARGET_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
            fi
            ${OC} patch pv $boundPV --type=merge -p '{"metadata": {"finalizers":null}}'
            ${OC} delete pv $boundPV
        else
            info "Resources used in restore already cleaned up. Moving on..."
        fi
    fi

    success "Cleanup complete."

}

function refresh_auth_idp(){
    title " Restarting auth-idp pod in namespace $TARGET_NAMESPACE "
    msg "-----------------------------------------------------------------------"
    local auth_pod=$(${OC} get pods -n $TARGET_NAMESPACE | grep auth-idp | awk '{print $1}')
    ${OC} delete pod $auth_pod -n $TARGET_NAMESPACE || warning "Pod $auth_pod could not be deleted, try deleting manually"
    success "Pod $auth_pod deleted. Please allow a few minutes for it to restart."
}

function check_ldap_secret() {
    exists=$(${OC} get secret -n $TARGET_NAMESPACE | (grep platform-auth-ldaps-ca-cert || echo fail))
    if [[ $exists != "fail" ]]; then
        certificate=$(${OC} get secret -n $TARGET_NAMESPACE platform-auth-ldaps-ca-cert -o yaml | yq '.data.certificate' )
        og_certificate=$(${OC} get secret -n $ORIGINAL_NAMESPACE platform-auth-ldaps-ca-cert -o yaml | yq '.data.certificate' )
        if [[ $certificate == "" ]] || [[ $certificate != $og_certificate ]]; then
            ${OC} patch secret -n $TARGET_NAMESPACE platform-auth-ldaps-ca-cert --type=merge -p '{"data": {"certificate": "'$og_certificate'"}}'
            info "Secret platform-auth-ldaps-ca-cert in $TARGET_NAMESPACE patched to match secret in $ORIGINAL_NAMESPACE"
        else
            info "Secret platform-auth-ldaps-ca-cert already populated. Moving on..."
        fi
    fi
}

function delete_mongo_pods() {
  local namespace=$1
  local pods=$(${OC} get pods -n $namespace | grep icp-mongodb | awk '{print $1}' | tr "\n" " ")
  for pod in $pods
  do
    debug1 "Deleting pod $pod"
    ${OC} delete pod $pod -n $ORIGINAL_NAMESPACE --ignore-not-found
    local condition="${OC} get pod -n $namespace --no-headers --ignore-not-found | grep ${pod} | egrep '2/2' || ${OC} get pod -n $namespace --no-headers --ignore-not-found | grep ${pod} | egrep '1/1' || true"
    local retries=15
    local sleep_time=15
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for mongo pod $pod to restart "
    local success_message="Pod $pod restarted with new mongo config"
    local error_message="Timeout after ${total_time_mins} minutes waiting for pod $pod "
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
  done
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
