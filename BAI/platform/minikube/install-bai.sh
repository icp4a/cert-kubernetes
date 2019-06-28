#!/bin/bash


LVAR_SCRIPT_NAME="$(basename $0)"
LVAR_EMITTER_IP=""
LVAR_KAFKA_IP=""
LVAR_PV_YAML=""
LVAR_KAFKA_YAML=""
LVAR_BAI_YAML=""
LVAR_PSP_YAML=""
LVAR_CONFIG_MAP_YAML=""

set -e

# Common script utilities
source ./utilities.sh

showHelp() {
    echo
    echo "--------------------------------------------------------------------------"
    echo "Installs a Business Automation Insights release."
    echo "--------------------------------------------------------------------------"
    echo "Prerequisites"
    echo "These files must be present in the same directory:"
    echo " - A YAML file that defines the persistent volumes"
    echo " - Optionally, a YAML file for Business Automation Insights ConfigMaps"
    echo " - A YAML file that defines the pod security policy"
    echo " - A YAML file for the Kafka installation"
    echo " - A YAML file for the Business Automation Insights installation"
    echo " - $LVAR_BAI_IMAGES that contains the Business Automation Insights release"
    echo
    echo "--------------------------------------------------------------------------"
    echo "Arguments:"
    echo "  -e <event type>"
    echo "      Mandatory. The <event type> argument must have one of the following values:"
    echo "      - bpmn "
    echo "      - bawadv "
    echo "      - icm  "
    echo "      - odm "
    echo "  -p <YAML file for persistent volumes >  Mandatory. "
    echo "  -s <YAML file for pod security policy >  Mandatory. "
    echo "  -k <YAML file for Kafka installation > Mandatory. "
    echo "  -b <YAML file for bai installation > Mandatory. "
    echo "  -i <event emitter IP address> Mandatory. "
    echo "  -j <IP address of the Kafka bootstrap server > Mandatory. "
    echo "  -c <bai ConfigMaps > Optional. "
    echo
    echo "  -h"
    echo "      Displays this help."
    echo
    echo "Example:"
    echo
    echo "  ./${LVAR_SCRIPT_NAME} -e odm -i 9.x.x.x -j 9.x.x.x -p ./pv.yaml -c ./bai-configmap.yaml -s ./bai-psp.yaml -k ./easy-install-kafka.yaml -b ./easy-install.yaml"
    echo
    echo "---------------------------------------------------------------"
    exit 1
}
echo

while getopts :e:p:k:b:c:s:i:j:h option;
do
    case ${option} in
        e)
            EVENT_PROCESSING_TYPE=$OPTARG
            echo "Event processing is for ${EVENT_PROCESSING_TYPE}"
            ;;
        p)
            LVAR_PV_YAML=$OPTARG
            checkFileExist "$LVAR_PV_YAML"
            ;;
        k)
            LVAR_KAFKA_YAML=$OPTARG
            checkFileExist "$LVAR_KAFKA_YAML"
            ;;
        b)
            LVAR_BAI_YAML=$OPTARG
            checkFileExist "$LVAR_BAI_YAML"
            ;;
        c)
            LVAR_CONFIG_MAP_YAML=$OPTARG
            checkFileExist "$LVAR_CONFIG_MAP_YAML"
            ;;
        s)
            LVAR_PSP_YAML=$OPTARG
            checkFileExist "$LVAR_PSP_YAML"
            ;;
        i)
            LVAR_EMITTER_IP=$OPTARG
            checkValidIP $LVAR_EMITTER_IP
            echo "Event emitter IP address: $LVAR_EMITTER_IP"
            ;;
        j)
            LVAR_KAFKA_IP=$OPTARG
            checkValidIP $LVAR_KAFKA_IP
            echo "Kafka bootstrap server IP address: $LVAR_KAFKA_IP"
            ;;
        h)
            showHelp
            ;;
        \?)
            echo "Invalid option: -${OPTARG}"
            exit 1
            ;;
    esac
done
echo

if [ -z "${EVENT_PROCESSING_TYPE}" ]; then
    echo "ERROR: You must provide an event type to process...."
    showHelp
fi
if [ -z "${LVAR_PV_YAML}" ]; then
    echo "ERROR: You must provide a configuration file for persistent volumes ...."
    showHelp
fi
if [ -z "${LVAR_KAFKA_YAML}" ]; then
    echo "ERROR: You must provide a Kafka configuration file...."
    showHelp
fi
if [ -z "${LVAR_BAI_YAML}" ]; then
    echo "ERROR: You must provide a configuration file for Business Automation Insights...."
    showHelp
fi
if [ -z "${LVAR_PSP_YAML}" ]; then
    echo "ERROR: You must provide a configuration file for the pod security policy...."
    showHelp
fi
if [ -z "${LVAR_EMITTER_IP}" ]; then
    echo "ERROR: You must provide the IP address of the event emitter host...."
    showHelp
fi
if [ -z "${LVAR_KAFKA_IP}" ]; then
    echo "ERROR: You must provide the IP address of the Kafka host...."
    showHelp
fi
if [ ! -z "${LVAR_CONFIG_MAP_YAML}" ] && [ ! -f "${LVAR_CONFIG_MAP_YAML}" ]; then
    echo "ERROR: The ConfigMap file ${LVAR_CONFIG_MAP_YAML} cannot be found...."
    showHelp
fi

echo "Creating the Business Automation Insights namespace"
kubectl create ns bai

echo "Creating persistent volumes"
kubectl apply -f "$LVAR_PV_YAML" -n bai

echo "Initializing helm "
helm init --wait
helm repo add confluent https://confluentinc.github.io/cp-helm-charts
helm repo update

echo "Creating the Kafka namespace"
kubectl create ns kafka

echo "Tiller is $(which tiller)"
echo "Installing Kafka"
# due to https://github.com/helm/helm/issues/3173 and others, adding a timeout argument...
helm install --wait --timeout 999999 --name kafka-release --namespace kafka -f "$LVAR_KAFKA_YAML" --set cp-kafka.customEnv.ADVERTISED_LISTENER_HOST=$(echo $LVAR_EMITTER_IP) confluent/cp-helm-charts

expand-BAI-Charts

if [ ! -z "$LVAR_CONFIG_MAP_YAML" ]; then
    cp "$LVAR_CONFIG_MAP_YAML" charts/ibm-business-automation-insights-dev/templates
fi


echo "Creating a security policy and a service account for Elasticsearch"
kubectl create -f "$LVAR_PSP_YAML" -n bai
kubectl create rolebinding bai-rolebinding --role=bai-role --serviceaccount=bai:bai-release-bai-psp-sa -n bai

echo "Installing Business Automation Insights"
helm install --wait --timeout 999999 --name bai-release --namespace bai charts/ibm-business-automation-insights-dev -f "$LVAR_BAI_YAML" --set kafka.bootstrapServers=$(echo $LVAR_KAFKA_IP):31090 --set ${EVENT_PROCESSING_TYPE}.install=true
