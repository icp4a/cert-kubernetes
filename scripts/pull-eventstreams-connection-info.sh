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
# clients of ICP4A components.
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
    echo "  -f icp4a_cr_file (required) The path of an ICP4A custom resource file."
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

    # Name of the YAML file of the Kafka certificate secret
    readonly KAFKA_CERTIFICATE_SECRET_FILENAME="${TEMP_PULL_ES_FOLDER}/kafkacertsecret.yaml"

    # Name of the secret that contains Kafka connection information
    readonly KAFKA_CONNECTION_SECRET="icp4a-kafka-connection-secret"

    # Name of the secret that contains Kafka certificate
    readonly KAFKA_CERTIFICATE_SECRET="icp4a-kafka-certificate-secret"

    cleanup

    mkdir -p ${TEMP_PULL_ES_FOLDER} >/dev/null 2>&1

    validate_cli
}

# Removes temporary files, if any left from a previous run.
function cleanup() {
    rm -f ${ES_KAFKA_USER_FILENAME}
    rm -f ${KAFKA_CONNECTION_SECRET_FILENAME}
    rm -f ${KAFKA_CERTIFICATE_SECRET_FILENAME}
    rm -rf ${TEMP_PULL_ES_FOLDER}
}

function get_eventsreams_connection_info() {
    local ICP4A_CR_NAME=${1:?Missing ICP4A custom resource name}

    # Search for an EventStreams instance in the current namespace
    echo "Searching for an IBM Event Streams instance in the current namespace..."

    oc get EventStreams --no-headers | grep "Ready" >/dev/null 2>&1
    returnValue=$?
    if [ "$returnValue" == 1 ] ; then
        echo_bold "No instance of Event Streams found. Aborting."
        exit 1
    fi

    # Extract the first word from the output of the oc command
    local ES_CR_NAME="$(oc get EventStreams --no-headers | grep "Ready" | awk '{print $1;}')"

    local EVENT_STREAMS_VERSION="$(oc get EventStreams ${ES_CR_NAME} -o jsonpath='{.status.versions.reconciled}')"
    # Note that the Event Streams operator can install previous versions of Event Streams.
    # The shown version number corresponds to the installed instance.
    echo_bold "IBM Event Streams ${EVENT_STREAMS_VERSION} instance found."

    echo "Event Streams custom resource name: ${ES_CR_NAME}"

    ES_CR_STATUS_PHASE="$(oc get EventStreams ${ES_CR_NAME} -o jsonpath='{.status.phase}')"
    echo "Event Streams custom resource status.phase: ${ES_CR_STATUS_PHASE}"

    if [[ "${ES_CR_STATUS_PHASE}" != "Ready" ]]; then
        echo_red "The found Event Streams instance does not have status.phase=Ready. Aborting."
        exit 1
    fi

    deploy_eventstreams_kakfa_user ${ES_CR_NAME} ${ICP4A_CR_NAME}
}

function deploy_eventstreams_kakfa_user() {
    local ES_CR_NAME=${1:?Missing EventStreams custom resource name argument}
    local ICP4A_CR_NAME=${2:?Missing ICP4A custom resource name argument}

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
      - host: '*'
        operation: Read
        resource:
          name: '__schema_'
          patternType: prefix
          type: topic
      - host: '*'
        operation: Alter
        resource:
          name: '__schema_'
          patternType: prefix
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

    # Event Streams 10.1 and later supports Apicurio and Event Streams schema registry types.
    # Event Streams 10.0.x supports the proprietary Event Streams schema registry type.
    local EVENT_STREAMS_APICURIO_SCHEMA_REGISTRY="$(oc get EventStreams ${ES_CR_NAME} -o jsonpath='{.spec.apicurioRegistry}')"
    local EVENT_STREAMS_PROPRIETARY_SCHEMA_REGISTRY="$(oc get EventStreams ${ES_CR_NAME} -o jsonpath='{.spec.schemaRegistry}')"
    local KAFKA_SCHEMA_REGISTRY_TYPE="not_configured"
    local KAFKA_SCHEMA_REGISTRY_URL="not_configured"

    # Use Apicurio if available.
    if [ -n "$EVENT_STREAMS_APICURIO_SCHEMA_REGISTRY" ]; then
      echo "Configuring ICP4A to use the Apicurio schema registry..."
      KAFKA_SCHEMA_REGISTRY_TYPE="APICURIO"
      KAFKA_SCHEMA_REGISTRY_URL="https://$(oc get EventStreams ${ES_CR_NAME} -o jsonpath='{.status.routes.ac-reg-external}')"
    elif [ -n "$EVENT_STREAMS_PROPRIETARY_SCHEMA_REGISTRY" ]; then
      echo_red "Apicurio schema registry not found. Configuring ICP4A with the IBM Event Streams schema registry, thus IBM Business Automation Insights will not be able to process Avro events..."
      KAFKA_SCHEMA_REGISTRY_TYPE="EVENT_STREAMS"
      KAFKA_SCHEMA_REGISTRY_URL="https://$(oc get EventStreams ${ES_CR_NAME} -o jsonpath='{.status.routes.schema-external}')"
    else
      echo_red "Found no schema registry configured in the custom resource of IBM Event Streams."
      echo_red "In IBM Business Automation Insights, the configuration of an Apicurio schema registry is a prerequisite for processing Avro events."
      echo_red "The configuration continues but without support for Avro events."
    fi

    # For use in the operator to configure the Kafka connection of ICP4A components, store
    # confidential connection information in a secret. The name is provided
    # in shared_configuration.kafka_configuration.kafka_connection_secret.
    deploy_kafka_connection_secret ${KAFKA_USERNAME} ${KAFKA_PASSWORD} ${KAFKA_SERVER_CERTIFICATE}
    
    # For use in the operator roles that need the server certificate of Kafka to be
    # referenced in shared_configuration.trusted_certificate_list.
    deploy_kafka_certificate_secret ${KAFKA_SERVER_CERTIFICATE}

    # Non-confidential Kafka connection information is provided in the CR.
    apply_changes_to_icp4a_cr ${ICP4A_CR_NAME} ${KAFKA_BOOTSTRAP_SERVERS} ${KAFKA_SCHEMA_REGISTRY_URL} ${KAFKA_SCHEMA_REGISTRY_TYPE} ${KAFKA_SERVER_CERTIFICATE} ${ES_CR_NAME}
}

function apply_changes_to_icp4a_cr() {
   local ICP4A_CR_NAME=${1:?Missing ICP4A custom resource file}
   local KAFKA_BOOTSTRAP_SERVERS=${2:?Missing Kafka bootstrap servers}
   local KAFKA_SCHEMA_REGISTRY_URL=${3:?Missing Kafka schema registry URL}
   local KAFKA_SCHEMA_REGISTRY_TYPE=${4:?Missing Kafka schema registry type}
   local KAFKA_SERVER_CERTIFICATE=${5:?Missing Kafka server certificate}
   local ES_CR_NAME=${6:?Missing Event Streams custom resource name argument}

   local PARAM_BASE="spec.shared_configuration.kafka_configuration"
   ${YQ_CMD} w -i ${ICP4A_CR_NAME} ${PARAM_BASE}.bootstrap_servers ${KAFKA_BOOTSTRAP_SERVERS}
   ${YQ_CMD} w -i ${ICP4A_CR_NAME} ${PARAM_BASE}.schema_registry_url ${KAFKA_SCHEMA_REGISTRY_URL}
   ${YQ_CMD} w -i ${ICP4A_CR_NAME} ${PARAM_BASE}.schema_registry_type ${KAFKA_SCHEMA_REGISTRY_TYPE}
   ${YQ_CMD} w -i ${ICP4A_CR_NAME} ${PARAM_BASE}.security_protocol "SASL_SSL"
   ${YQ_CMD} w -i ${ICP4A_CR_NAME} ${PARAM_BASE}.sasl_mechanism "SCRAM-SHA-512"
   ${YQ_CMD} w -i ${ICP4A_CR_NAME} ${PARAM_BASE}.connection_secret_name ${KAFKA_CONNECTION_SECRET}

   # Add the Kafka server certificate to shared_configuration.trusted_certificate_list
   # If the parameter does not exist in the input custom resource, it is created with the Kafka certificate as unique value in the list.
   # If the parameter exists, the Kafka certificate is appended to the list of certificates, unless it is already present.

   # Search for the name of the secret among the items in the current list (if any).
   local FOUND_NAME=$(${YQ_CMD} r ${ICP4A_CR_NAME} "spec.shared_configuration.trusted_certificate_list(.==${KAFKA_CERTIFICATE_SECRET})")

   # If not found, add it.
   if [ -z "${FOUND_NAME}" ]; then
     ${YQ_CMD} w -i ${ICP4A_CR_NAME} spec.shared_configuration.trusted_certificate_list[+] ${KAFKA_CERTIFICATE_SECRET}
   fi

   echo_bold "Filled the section shared_configuration.kafka_configuration of the ICP4A custom resource"
   echo_bold "with the following configuration for the Event Streams instance ${ES_CR_NAME}:"
   # Strip comment lines.
   ${YQ_CMD} r ${ICP4A_CR_NAME} ${PARAM_BASE} | grep -v "#"
}

# Deploys the Kafka connection secret.
# Some ICP4A operator roles need the username, password, and Kafka server certificate to be accessible
# from a secret which name is provided in shared_configuration.kafka_configuration.connection_secret_name.

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

# Deploys the Kafka certificate secret.
# Some ICP4A operator roles need the certificate of the Kafka server to be accessible from a secret
# which name is in shared_configuration.trusted_certificate_list. This secret must contain the
# certificate in its tls.crt key. Therefore, as the secret specified via
# shared_configuration.kafka_configuration.connection_secret_name must contain the secret
# under a different key name (kafka-server-certificate), a distinct secret is deployed with
# the same certificate in the tls.crt key.

function deploy_kafka_certificate_secret() {
    local KAFKA_SERVER_CERTIFICATE=${1:?Missing Kafka server certificate}

    cat <<EOF > "${KAFKA_CERTIFICATE_SECRET_FILENAME}"
apiVersion: v1
kind: Secret
metadata:
  name: ${KAFKA_CERTIFICATE_SECRET}
type: Opaque
data:
  tls.crt: ${KAFKA_SERVER_CERTIFICATE}
EOF

    # Remove existing secret if any
    oc delete secret ${KAFKA_CERTIFICATE_SECRET} --ignore-not-found=true

    echo "Deploying secret ${KAFKA_CERTIFICATE_SECRET}..."
    # --validate=false in order to support keys with no value, although typically all keys do have values.
    oc create -f ${KAFKA_CERTIFICATE_SECRET_FILENAME} --validate=false
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
    local ES_CR_NAME=${1:?Missing Event Streams custom resource name}
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
        echo_red "Missing ICP4A custom resource name argument"
        usage
    fi

    init

    # Augment the CR with the connection information for using a preexisting Event Streams 2002.2.1+ instance.
    get_eventsreams_connection_info ${ICP4A_CR_NAME}

    # Cleanup temporary files created in this run of the script.
    cleanup
}

main "$@"
