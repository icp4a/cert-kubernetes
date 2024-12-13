#!/usr/bin/env bash
#
# Copyright 2023 IBM Corporation
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

MODE=$1
CS_NAMESPACE=$2
SERVICES_NAMESPACE=$3
if [[ -z $SERVICES_NAMESPACE ]]; then
    $SERVICES_NAMESPACE=$CS_NAMESPACE
fi

function main(){
    if [[ -z $CS_NAMESPACE ]]; then
        error "Namespace parameter not specified"
    fi

    if [[ -z $MODE ]]; then
        error "Script mode not specified, please specify either \"up\" or \"down\""
    fi

    if [[ $MODE == "up" ]]; then
        scale_up
    fi

    if [[ $MODE == "down" ]]; then
        scale_down
    fi
}

function scale_up(){
    info "Z cluster detected, be prepared for multiple restarts of mongo pods. This is expected behavior."
    mongo_op_scaled_original=$(oc get deploy -n $CS_NAMESPACE | grep ibm-mongodb-operator | egrep '1/1' || echo false)
    if [[ $mongo_op_scaled_original == "false" ]]; then
        info "Mongo operator in $CS_NAMESPACE still scaled down, scaling up."
        oc scale deploy -n $CS_NAMESPACE ibm-mongodb-operator --replicas=1
        info "Wait for mongo operator to reconcile resources"
        sleep 60
        delete_mongo_pods "$SERVICES_NAMESPACE"
    fi
    success "Mongo reset successfully."
}

function scale_down(){
    info "Z cluster detected, be prepared for multiple restarts of mongo pods. This is expected behavior."
    info "Scaling down MongoDB operator"
    oc scale deploy -n $CS_NAMESPACE ibm-mongodb-operator --replicas=0
    #get cache size value
    cacheSizeGB=$(oc get cm icp-mongodb -n $SERVICES_NAMESPACE -o yaml | grep cacheSizeGB | awk '{print $2}')

    info "Editing configmap icp-mongodb"
    cat << EOF | oc apply -n $SERVICES_NAMESPACE -f -
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
    delete_mongo_pods "$SERVICES_NAMESPACE"
    success "Mongo prepped for backup or restore successfully."
}

function delete_mongo_pods() {
  local namespace=$1
  local pods=$(oc get pods -n $namespace | grep icp-mongodb | awk '{print $1}' | tr "\n" " ")
  for pod in $pods
  do
    info "Deleting pod $pod"
    oc delete pod $pod -n $namespace --ignore-not-found
    local condition="oc get pod -n $namespace --no-headers --ignore-not-found | grep ${pod} | egrep '2/2' || oc get pod -n $namespace --no-headers --ignore-not-found | grep ${pod} | egrep '1/1' || true"
    local retries=15
    local sleep_time=15
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for mongo pod $pod to restart "
    local success_message="Pod $pod restarted with new mongo config"
    local error_message="Timeout after ${total_time_mins} minutes waiting for pod $pod "
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
  done
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