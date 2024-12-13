###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2024. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

#Default value
HELP="false"
SKIP_CONFIRM="false"

while getopts 'n:hsa' OPTION; do
	case "$OPTION" in
	n)	ES_NAMESPACE=$OPTARG
		;;
	h)
		HELP="true"
		;;
	s)
		SKIP_CONFIRM="true"
		;;
	?)
		HELP="true"
		;;
	esac
done
shift "$(($OPTIND - 1))"

if [[ $HELP == "true" ]]; then
	echo "This script completely cleans up Elasticsearch Resources."
	echo "Usage: $0 -h -n"
	echo " -h Display help."
	echo " -n Enter the namespace where Elasticsearch is installed."
	echo " -s Use this option to skip confirmation."
	exit 0
fi

#Check oc is installed
if ! [ -x "$(command -v oc)" ]; then
	echo 'Error: oc is not installed.' >&2
	exit 1
fi

#Check if oc login command is executed
oc project > /dev/null 2>&1
if [ $? -gt 0 ]; then
	echo "ERROR: oc login is required for running this script." && exit 1
fi

# Elasticsearch Namespace check
if [ -z $ES_NAMESPACE ]; then
	echo "ERROR: Elasticsearch namespace is required following -n or use -h for more details." && exit 1
fi

# Validate ES_NAMESPACE env var is for existing namespace
if [ -z "$(oc get project "${ES_NAMESPACE}" 2>/dev/null)" ]; then
	echo " ERROR: Namespace ${ES_NAMESPACE} does not exist. Specify an existing namespace where Elasticsearch is installed." && exit 1
fi

echo -e "The Elasticsearch namespace entered: ${ES_NAMESPACE}\n"
echo -e "\x1B[1;31m[ATTENTION]: \x1B[0m\x1B[1;31mThis script is designed to delete deprecated Elasticsearch resources from your cluster, Please ensure that you have completed the data migration from Elasticsearch to OpenSearch before running this script.\x1B[0m\n"
if [[ $SKIP_CONFIRM == "false" ]]; then
	echo "Would you like to clean up Elasticsearch resources right now?"
	echo "Use -s option to skip this confirmation, -h for help."
	read -p "Enter Y or y to continue: " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "You chose to NOT continue.  Bye."
		exit 0
	fi
	echo "OK. Continuing...."
	sleep 2
	echo
fi

oc project ${ES_NAMESPACE}

echo "The cleanup of Elasticsearch resources is in progress..."

function delete_resource() {
	local RESOURCE_NAME=$1
	local ES_NAMESPACE=$2
	oc get "${RESOURCE_NAME}" -n "${ES_NAMESPACE}" --ignore-not-found=true &>/dev/null
	if [ $? -eq 0 ]; then
		for i in $(oc get "${RESOURCE_NAME}" -n "${ES_NAMESPACE}" --no-headers --ignore-not-found=true | awk '{print $1}'); do
			oc patch "${RESOURCE_NAME}"/$i -n "${ES_NAMESPACE}" -p '{"metadata":{"finalizers":[]}}' --type=merge
			oc delete "${RESOURCE_NAME}" $i -n "${ES_NAMESPACE}" --ignore-not-found=true
		done
	fi
}

function delete_specific_resource() {
    local RESOURCE_NAME=$1
    local ES_NAMESPACE=$2
    local OBJECT_NAME=$3
    itemcount=$(oc get "${RESOURCE_NAME}" "${OBJECT_NAME}" -n "${ES_NAMESPACE}" --no-headers --ignore-not-found=true | wc -l)
    if [[ $itemcount == 1 ]]; then
        oc patch "${RESOURCE_NAME}"/"${OBJECT_NAME}" -n "${ES_NAMESPACE}" -p '{"metadata":{"finalizers":[]}}' --type=merge
        echo "Deleting ${RESOURCE_NAME} ${OBJECT_NAME} in namespace ${ES_NAMESPACE}"
        oc delete "${RESOURCE_NAME}" "${OBJECT_NAME}" -n "${ES_NAMESPACE}" --ignore-not-found=true --force --grace-period=0
        echo "Wait for 10 secs before checking if ${RESOURCE_NAME} ${OBJECT_NAME} is removed"
        sleep 10 
        itemcount=$(oc get "${RESOURCE_NAME}" "${OBJECT_NAME}" -n "${ES_NAMESPACE}" --no-headers --ignore-not-found=true | wc -l)
        if [[ $itemcount == 1 ]]; then
           echo "${RESOURCE_NAME} ${OBJECT_NAME} is still found.  Removing finalizer..."
           oc patch "${RESOURCE_NAME}"/"${OBJECT_NAME}" -n "${ES_NAMESPACE}" -p '{"metadata":{"finalizers":[]}}' --type=merge
        fi
    fi
}

function delete_wildcard_resource() {
    local RESOURCE_NAME=$1
    local ES_NAMESPACE=$2
    local OBJECT_WILDCARD_NAME=$3
    itemcount=$(oc get "${RESOURCE_NAME}" -n "${ES_NAMESPACE}" --no-headers --ignore-not-found=true | grep "${OBJECT_WILDCARD_NAME}" | wc -l)
    if [[ $itemcount == 1 ]]; then
	    obj_name=$(oc get "${RESOURCE_NAME}" -n "${ES_NAMESPACE}" --no-headers --ignore-not-found=true | grep "${OBJECT_WILDCARD_NAME}" | awk '{print $1}')
        oc patch "${RESOURCE_NAME}"/"${obj_name}" -n "${ES_NAMESPACE}" -p '{"metadata":{"finalizers":[]}}' --type=merge
        echo "Deleting ${RESOURCE_NAME} ${obj_name} in namespace ${ES_NAMESPACE}"
        oc delete "${RESOURCE_NAME}" "${obj_name}" -n "${ES_NAMESPACE}" --ignore-not-found=true --force --grace-period=0
        echo "Wait for 10 secs before checking if ${RESOURCE_NAME} ${obj_name} is removed"
        sleep 10 
        itemcount=$(oc -n "${ES_NAMESPACE}" get "${RESOURCE_NAME}" "${obj_name}" --no-headers --ignore-not-found=true | wc -l)
        if [[ $itemcount == 1 ]]; then
		   obj_name=$(oc get "${RESOURCE_NAME}" -n "${ES_NAMESPACE}" --no-headers --ignore-not-found=true | grep "${OBJECT_WILDCARD_NAME}" | awk '{print $1}')
           echo "${RESOURCE_NAME} ${obj_name} is still found.  Removing finalizer..."
           oc patch "${RESOURCE_NAME}"/"${obj_name}" -n "${ES_NAMESPACE}" -p '{"metadata":{"finalizers":[]}}' --type=merge
        fi
    fi
}

echo "Cleaning up resources from Namespace: ${ES_NAMESPACE}"
delete_resource "Elasticsearch" "${ES_NAMESPACE}"
delete_wildcard_resource "subscription" "${ES_NAMESPACE}" "ibm-automation-elastic"
delete_wildcard_resource "csv" "${ES_NAMESPACE}" "ibm-automation-elastic"
delete_specific_resource "operandrequest" "${ES_NAMESPACE}" "elastic-request"
delete_specific_resource "deployment" "${ES_NAMESPACE}" "ibm-elastic-operator-controller-manager"
delete_specific_resource "issuer" "${ES_NAMESPACE}" "foundation-iaf-automationbase-ab-issuer"
delete_specific_resource "secret" "${ES_NAMESPACE}" "foundation-iaf-automationbase-ab-ca"
delete_wildcard_resource "networkpolicy" "${ES_NAMESPACE}" "egress-allow-elasticsearch"
delete_specific_resource "route" "${ES_NAMESPACE}" "iaf-system-es"

echo "Clean up has completed."