#!/bin/bash
#set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# This script offers the user the option to pull the Kafka connection information from a
# preexisting IBM Event Streams instance, and to fill the shared_configuration
# element of an ICP4A Custom Resource (CR) such that the operator can automatically configure the Kafka
# clients of ICP4A products.
# The purpose of this script is primarily to be called by the demo pattern script.
# You can also execute it directly, passing a CR file path as unique argument.
# Prerequisite: oc login must be already done.

readonly PULL_ES_SCRIPT_PATH=$(dirname $0)
readonly TEMP_PULL_ES_FOLDER=${PULL_ES_SCRIPT_PATH}/.tmpPullEventstreamsConfig
CUR_DIR=$(cd ${PULL_ES_SCRIPT_PATH}; pwd)

# Import common utilities and environment variables
source ${PULL_ES_SCRIPT_PATH}/helper/common.sh

function usage() {
    echo "Augment an ICP4A Custom Resource with Kafka connection information extracted"
    echo "automatically from an Event Streams instance already present in the current namespace."
    echo "Syntax:"
    echo "  $(basename $0) -f <icp4a_cr_file>"
    echo "Options:"
    echo "  -c icp4a_cr_file (required) The path of an ICP4A CR file."
    echo "  -h                          This help"
    echo "IMPORTANT: oc login must be already done when calling this script."
    echo
    exit 1
}

# Initialize environment variables, initialize CLI, and perform initial cleanup.
function init() {
    # Name of the EventStreams KafkaUser kubernetes object used for ICP4A.
    readonly ES_KAFKA_USER_RESOURCE_NAME="eventstreams-for-icp4a-kafka-user"

    # Name of the temporary file used for deploying an EventStreams KafkaUser resource.
    readonly ES_KAFKA_USER_FILENAME="${TEMP_PULL_ES_FOLDER}/kafkauser.yaml"

    # Name of the YAML file of the Kafka connection secret
    readonly KAFKA_CONNECTION_SECRET_FILENAME="${TEMP_PULL_ES_FOLDER}/kafkasecret.yaml"

    # Name of the secret that contains Kafka connection information
    readonly KAFKA_CONNECTION_SECRET="icp4a-kafka-connection-secret"

    cleanup

    mkdir -p ${TEMP_PULL_ES_FOLDER} >/dev/null 2>&1

    validate_cli
}

# Removes temporary files, if any left from a previous run.
function cleanup() {
    rm -f ${ES_KAFKA_USER_FILENAME}
    rm -f ${KAFKA_CONNECTION_SECRET_FILENAME}
    rm -rf ${TEMP_PULL_ES_FOLDER}
}

function get_eventsreams_connection_info() {
    local ICP4A_CR_NAME=${1:?Missing ICP4A CR name}

    # Search for an EventStreams instance in the current namespace
    echo "Searching for an EventStreams instance in the current namespace..."

    oc get EventStreams --no-headers | grep "Ready" >/dev/null 2>&1
    returnValue=$?
    if [ "$returnValue" == 1 ] ; then
        echo_bold "No instance of EventStreams found. Aborting."
        exit 1
    fi
    echo_bold "EventStreams instance found."
    # Extract the first word from the output of the oc command
    local ES_CR_NAME="$(oc get EventStreams --no-headers | grep "Ready" | awk '{print $1;}')"
    echo "EventStreams CR name: ${ES_CR_NAME}"

    ES_CR_STATUS_PHASE="$(oc get EventStreams ${ES_CR_NAME} -o jsonpath='{.status.phase}')"
    echo "EventStreams CR status.phase: ${ES_CR_STATUS_PHASE}"

    if [[ "${ES_CR_STATUS_PHASE}" != "Ready" ]]; then
        echo_red "The found EventStreams instance does not have status.phase=Ready. Aborting."
        exit 1
    fi

    deploy_eventstreams_kakfa_user ${ES_CR_NAME} ${ICP4A_CR_NAME}
}

function deploy_eventstreams_kakfa_user() {
    local ES_CR_NAME=${1:?Missing EventStreams CR name argument}
    local ICP4A_CR_NAME=${2:?Missing ICP4A CR name argument}

    cat <<EOF > "${ES_KAFKA_USER_FILENAME}"
apiVersion: eventstreams.ibm.com/v1beta1
kind: KafkaUser
metadata:
  labels:
    eventstreams.ibm.com/cluster: ${ES_CR_NAME}
  name: ${ES_KAFKA_USER_RESOURCE_NAME}
spec:
  authentication:
    type: scram-sha-512
  authorization:
    acls:
      - host: '*'
        operation: Read
        resource:
          name: '*'
          patternType: literal
          type: topic
      - host: '*'
        operation: Describe
        resource:
          name: '*'
          patternType: literal
          type: topic
      - host: '*'
        operation: Read
        resource:
          name: '*'
          patternType: literal
          type: group
      - host: '*'
        operation: Write
        resource:
          name: '*'
          patternType: literal
          type: topic
      - host: '*'
        operation: Create
        resource:
          name: '*'
          patternType: literal
          type: topic
      - host: '*'
        operation: Describe
        resource:
          name: '*'
          patternType: literal
          type: topic
    type: simple
EOF

    echo "Deploying KafkaUser ${ES_KAFKA_USER_RESOURCE_NAME}..."
    oc apply -f ${ES_KAFKA_USER_FILENAME}

    # It typically takes about 2 minutes before the KafkaUser object passes in Ready status.
    echo "Wait 5 seconds for KafkaUser ${ES_KAFKA_USER_RESOURCE_NAME} to pass in Ready status..."
    sleep 5

    local ES_KAFKA_USER_STATUS=$(oc get KafkaUser ${ES_KAFKA_USER_RESOURCE_NAME} -o jsonpath='{.status.conditions[0].type}')
    if [[ "${ES_KAFKA_USER_STATUS}" != "Ready" ]]; then
        echo_red "${ES_KAFKA_USER_RESOURCE_NAME} is not ready. Aborting."
        exit 1
    fi

    local KAFKA_SERVER_CERTIFICATE=$(get_kafka_server_certificate_base64 ${ES_CR_NAME})
    local KAFKA_USERNAME=$(get_kafka_username_base64)
    local KAFKA_PASSWORD=$(get_kafka_password_base64)

    local KAFKA_BOOTSTRAP_HOST="$(oc get EventStreams ${ES_CR_NAME} -o jsonpath='{.status.kafkaListeners[1].addresses[0].host}')"
    local KAFKA_BOOTSTRAP_PORT="$(oc get EventStreams ${ES_CR_NAME} -o jsonpath='{.status.kafkaListeners[1].addresses[0].port}')"
    local KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_HOST}:${KAFKA_BOOTSTRAP_PORT}"

    # For use in the operator to configure the Kafka connection of products, store
    # confidential connection information in a secret. The name is provided
    # in shared_configuration.kafka_configuration.kafka_connection_secret.
    deploy_kafka_connection_secret ${KAFKA_USERNAME} ${KAFKA_PASSWORD} ${KAFKA_SERVER_CERTIFICATE}

    # Non-confidential Kafka connection information is provided in the CR.
    apply_changes_to_icp4a_cr ${ICP4A_CR_NAME} ${KAFKA_BOOTSTRAP_SERVERS} ${ES_CR_NAME}
}

function apply_changes_to_icp4a_cr() {
   local ICP4A_CR_NAME=${1:?Missing ICP4A CR file}
   local KAFKA_BOOTSTRAP_SERVERS=${2:?Missing Kafka bootstrap servers}
   local ES_CR_NAME=${3:?Missing EventStreams CR name argument}

   local PARAM_BASE="spec.shared_configuration.kafka_configuration"
   ${YQ_CMD} w -i ${ICP4A_CR_NAME} ${PARAM_BASE}.bootstrap_servers ${KAFKA_BOOTSTRAP_SERVERS}
   ${YQ_CMD} w -i ${ICP4A_CR_NAME} ${PARAM_BASE}.security_protocol "SASL_SSL"
   ${YQ_CMD} w -i ${ICP4A_CR_NAME} ${PARAM_BASE}.sasl_mechanism "SCRAM-SHA-512"
   ${YQ_CMD} w -i ${ICP4A_CR_NAME} ${PARAM_BASE}.connection_secret_name ${KAFKA_CONNECTION_SECRET}

   echo_bold "Filled the ICP4A CR with the following configuration information for the Event Streams instance ${ES_CR_NAME}:"
   ${YQ_CMD} r ${ICP4A_CR_NAME} ${PARAM_BASE}
}

function deploy_kafka_connection_secret() {
    local KAFKA_USERNAME=${1:?Missing Kafka username}
    local KAFKA_PASSWORD=${2:?Missing Kafka password}
    local KAFKA_SERVER_CERTIFICATE=${3:?Missing Kafka server certificate}

    cat <<EOF > "${KAFKA_CONNECTION_SECRET_FILENAME}"
apiVersion: v1
kind: Secret
metadata:
  name: ${KAFKA_CONNECTION_SECRET}
type: Opaque
data:
  kafka-username: ${KAFKA_USERNAME}
  kafka-password: ${KAFKA_PASSWORD}
  kafka-server-certificate: ${KAFKA_SERVER_CERTIFICATE}
EOF

    # Remove existing secret if any
    oc delete secret ${KAFKA_CONNECTION_SECRET} --ignore-not-found=true

    echo "Deploying secret ${KAFKA_CONNECTION_SECRET}..."
    # --validate=false in order to support keys with no value, although typically all keys do have values.
    oc create -f ${KAFKA_CONNECTION_SECRET_FILENAME} --validate=false
}

function get_kafka_username_base64() {
    echo -n ${ES_KAFKA_USER_RESOURCE_NAME} | base64
}

function get_kafka_password_base64() {
    # Note this is base64-encoded
    local KAFKA_PASSWORD=$(oc get secret ${ES_KAFKA_USER_RESOURCE_NAME} -o=jsonpath='{.data.password}')
    echo ${KAFKA_PASSWORD}
}

function get_kafka_server_certificate_base64() {
    # Note this is base64-encoded
    local ES_CR_NAME=${1:?Missing Event Streams CR name}
    local KAFKA_SERVER_CERTIFICATE=$(oc get secret/${ES_CR_NAME}-cluster-ca-cert -o "jsonpath={.data.ca\.crt}" | openssl enc -d -A)
    echo ${KAFKA_SERVER_CERTIFICATE}
}

function main() {
    local ICP4A_CR_NAME

    while getopts "f:h" option
    do
        case $option in
            f)
                ICP4A_CR_NAME=$OPTARG
                ;;
            h)
                usage
                ;;
            \?)
                echo_red "Unrecognized option $OPTARG"
                usage
                ;;
        esac
    done

    if [[ -z "${ICP4A_CR_NAME}" ]]; then
        echo_red "Missing ICP4A CR name argument"
        usage
    fi

    init

    # Augment the CR with the connection information for using a preexisting Event Streams 2002.2.1+ instance.
    get_eventsreams_connection_info ${ICP4A_CR_NAME}

    # Cleanup temporary files created in this run of the script.
    cleanup
}

main "$@"
