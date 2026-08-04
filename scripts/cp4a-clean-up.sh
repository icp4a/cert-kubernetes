#!/bin/bash
# set -x
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
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
CLI_CMD="oc"
# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh

#Default Namespace
CPFS_SHARED_NAMESPACE=""
CPFS_CONTROL_NAMESPACE="cs-control"
IBM_CERT_MANAGER_NAMESPACE="ibm-cert-manager"
COMMON_SERVICES_CM_NAMESPACE="kube-public"
IBM_LICENSING_NAMESPACE="ibm-licensing"
OPENSHIFT_OPERATORS_NAMESPACE="openshift-operators"
COMMON_SERVICES_CM_DEDICATED_NAME="common-service-maps"

#Default boolean
HELP="false"
SKIP_CONFIRM="false"
SELECT_ALL="false"
CLEAN_CPFS="true"
CLEAN_CRDS="false"
SEPARATION_DUTY="false"
ALL_NAMESPACE="false"
IS_SHARED_CPFS="false"

CS_MAPS_YAML=""
CS_NAMESPACE_COUNT=0
SHARED_NAMESPACE_COUNT=0
CS_MAP_INDEX=""
REQUEST_NS_INDEX=""
NAMESPACES_MAPPED_TO_CS=""

while getopts 'n:hsa' OPTION; do
	case "$OPTION" in
	n)	CP4BA_NAMESPACE=$OPTARG
		;;
	h)
		HELP="true"
		;;
	s)
		SKIP_CONFIRM="true"
		;;
	a)
		SELECT_ALL="true"
		;;
	?)
		HELP="true"
		;;
	esac
done
shift "$(($OPTIND - 1))"

if [[ $HELP == "true" ]]; then
	echo "This script completely cleans up IBM Cloud Pak for Business Automation and IBM Cloud Pak foundational services."
	echo "Usage: $0 -h -n"
	echo "  -h  Display help"
	echo "  -n  Enter CP4BA namespace for clean up."
	echo "  -s  Use this option to skip confirmation."
	exit 0
fi

# Check if OpenShift CLI is installed
if ! [ -x "$(command -v ${CLI_CMD})" ]; then
	error "OpenShift CLI is not installed. Please install OpenShift CLI before running this script."
	exit 1
fi

# Check if jq is installed
which jq &>/dev/null
[[ $? -ne 0 ]] && \
printf '%b\n'  "\x1B[1;31mUnable to locate the jq CLI. You must install it to run this script.\x1B[0m" && \
exit 1

# Check cluster login
check_cluster_login

# CP4BA Namespace check
if [ -z "$CP4BA_NAMESPACE" ]; then
	error "CP4BA namespace needed. Please enter the CP4BA namespace following -n or use -h for more details."
	exit 1
fi

# Namespace check to avoid cleaning up in the wrong namespace
if [[ "$CP4BA_NAMESPACE" == openshift* ]]; then
	error "Then entered namespace must not be 'openshift' or start with 'openshift'. It should be the namespace where CP4BA is installed. The script has been  aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == kube* ]]; then
	error "Then entered namespace must not be 'kube' or start with 'kube'. It should be the namespace where CP4BA is installed. The script has been  aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "services" ]]; then
	error "Then entered namespace must not be 'services'. It should be the namespace where CP4BA is installed. The script has been aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "default" ]]; then
	error "Then entered namespace must not be 'default'. It should be the namespace where CP4BA is installed. The script has been aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "calico-system" ]]; then
	error "Then entered namespace must not be 'calico-system'. It should be the namespace where CP4BA is installed. The script has been aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-cert-store" ]]; then
	error "Then entered namespace must not be 'ibm-cert-store'. It should be the namespace where CP4BA is installed. The script has been aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-observe" ]]; then
	error "Then entered namespace must not be 'ibm-observe'. It should be the namespace where CP4BA is installed. The script has been aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-odf-validation-webhook" ]]; then
	error "Then entered namespace must not be 'ibm-odf-validation-webhook'. It should be the namespace where CP4BA is installed. The script has been aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-system" ]]; then
	error "Then entered namespace must not be 'ibm-system'. It should be the namespace where CP4BA is installed. The script has been aborted."
	exit 1
fi

# Validate CP4BA_NAMESPACE env var is for existing namespace
if [ -z "$(${CLI_CMD} get project "${CP4BA_NAMESPACE}" 2>/dev/null)" ]; then
	error "Namespace ${CP4BA_NAMESPACE} does not exist. Specify an existing namespace where CP4BA is installed."
	exit 1
fi

# https://jsw.ibm.com/browse/DBACLD-185402 save output to log file
save_log "cp4a-script-logs/project/$CP4BA_NAMESPACE" "cp4a-clean-up-log"
trap cleanup_log EXIT

printf '%b\n' "The CP4BA namespace entered:\n- ${CP4BA_NAMESPACE}\n"
printf '%b\n' "Note: Please ensure you are using the intended namespace for cleanup.\n"
success "All prerequisites passed. Ready for clean up."
echo
printf '%b\n' "\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;33mThis script is only intended to delete any remaining resources in the Cloud Pak for Business Automation and Cloud Pak foundational services namespace(s), and it is not intended for uninstalling Cloud Pak for Business Automation and Cloud Pak foundational services deployment. The script also does not support cleaning up shared Cloud Pak foundational services.\x1B[0m\n"

# <https://jsw.ibm.com/browse/DBACLD-156516> - User need to provide the service namespace in separation of duties
# Check if ibm-cp4ba-common-config is present in the namespace
if [ -z "$(${CLI_CMD} get configmap ibm-cp4ba-common-config -n ${CP4BA_NAMESPACE} 2>/dev/null)" ]; then
	error "Not able to find configmap \"ibm-cp4ba-common-config\" in Namespace ${CP4BA_NAMESPACE}. Please make sure you have provided the namespace where CP4BA is installed or if your have separation of duties please provide the services namespace."
	exit 1
fi

# CP4BA seperation of duty check
CP4BA_CM_CONFIG=$(${CLI_CMD} get configmap ibm-cp4ba-common-config -n ${CP4BA_NAMESPACE} -o jsonpath="{ .data}" 2>/dev/null)
CP4BA_CM_CONFIG_YAML=$(mktemp)
echo "$CP4BA_CM_CONFIG" > "$CP4BA_CM_CONFIG_YAML"
# get operators namespace
CP4BA_OPERATORS_NAMESPACE=$(${YQ_CMD} ".operators_namespace" "$CP4BA_CM_CONFIG_YAML")
# get services namespace (Same as the CP4BA namespace)
CP4BA_SERVICES_NAMESPACE=$(${YQ_CMD} ".services_namespace" "$CP4BA_CM_CONFIG_YAML")

if [[ "$CP4BA_OPERATORS_NAMESPACE" == "openshift-operators" ]]; then
	ALL_NAMESPACE="true"
	CLEAN_CPFS="false"
	info "Operators are installed in namespace openshift-operators. This is a all-namespace scoped deployment, the script will only proceed to clean up CP4BA Namesapce."
fi

if [[ "$CP4BA_OPERATORS_NAMESPACE" != "$CP4BA_SERVICES_NAMESPACE" && "$ALL_NAMESPACE" == "false" ]]; then
	SEPARATION_DUTY="true"
fi
if [[ "$SEPARATION_DUTY" == "true" ]]; then
	info "Seperation of duty detected. CP4BA Operators Namespace: ${CP4BA_OPERATORS_NAMESPACE} and CP4BA Services Namespace: ${CP4BA_SERVICES_NAMESPACE}. Both namespace will be cleaned up."
fi
rm "$CP4BA_CM_CONFIG_YAML"

# CPFS detection (supports both <4.17 using kube-public/common-service-maps CM and 4.17+ using CommonService CR).
if [[ "$ALL_NAMESPACE" == "false" ]]; then
	CS_MAP=$(${CLI_CMD} get configmap "${COMMON_SERVICES_CM_DEDICATED_NAME}" -n "${COMMON_SERVICES_CM_NAMESPACE}" -o jsonpath="{ .data['common-service-maps\.yaml']}" 2>/dev/null)

	if [[ -z "$CS_MAP" ]]; then
		info "No common-service-maps ConfigMap found in ${COMMON_SERVICES_CM_NAMESPACE}. Checking for CommonService CR."
		CS_CR_NAME=$(${CLI_CMD} get commonservice -n "${CP4BA_SERVICES_NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

		if [[ -n "${CS_CR_NAME}" ]]; then
			CPFS_SHARED_NAMESPACE=$(${CLI_CMD} get commonservice "${CS_CR_NAME}" -n "${CP4BA_SERVICES_NAMESPACE}" -o jsonpath='{.spec.servicesNamespace}' 2>/dev/null)		
			if [[ -z "${CPFS_SHARED_NAMESPACE}" ]]; then
				info "CommonService/${CS_CR_NAME} found but spec.servicesNamespace is empty. Skipping CPFS cleanup."
				CLEAN_CPFS="false"
				IS_SHARED_CPFS="false"
				CS_NAMESPACE_COUNT=0
			else
				CLEAN_CPFS="true"
				IS_SHARED_CPFS="false"
				CS_NAMESPACE_COUNT=1
				success "CPFS namespace detected from CommonService CR: ${CPFS_SHARED_NAMESPACE}."
			fi
		else
			error "The CP4BA Namespace \"${CP4BA_NAMESPACE}\" does not map to any Cloud Pak foundational services (not in common-service-maps ConfigMap and no CommonService CR found). Please make sure the namespace you entered is correct. The script aborted."
			exit 1
		fi
	else
		CS_MAPS_YAML=$(mktemp)
		echo "$CS_MAP" > "$CS_MAPS_YAML"
		CS_NAMESPACE_COUNT=$(${YQ_CMD} eval '.namespaceMapping | length // 0' "$CS_MAPS_YAML")
		for(( i = 0; i < CS_NAMESPACE_COUNT; i++ )); do
			# Get CS namespace
			CS_NS=$(${YQ_CMD} ".namespaceMapping[${i}].map-to-common-service-namespace" "$CS_MAPS_YAML")
			# Get CS control namespace
			CPFS_CONTROL_NAMESPACE=$(${YQ_CMD} ".controlNamespace" "$CS_MAPS_YAML")
			# Get Shared namespace count
			SHARED_NAMESPACE_COUNT=$(${YQ_CMD} eval '.namespaceMapping['"${i}"'].requested-from-namespace | length // 0' "$CS_MAPS_YAML")
			# Check if the entered CP4BA namespace is in the list
			for((j = 0; j < SHARED_NAMESPACE_COUNT; j++)); do
				CP_NS=$(${YQ_CMD} ".namespaceMapping[${i}].requested-from-namespace[${j}]" "$CS_MAPS_YAML")
				if [[ "$CP_NS" == "$CP4BA_NAMESPACE" ]];then
					NAMESPACES_MAPPED_TO_CS=$(${YQ_CMD} ".namespaceMapping[${i}].requested-from-namespace" "$CS_MAPS_YAML")
					CPFS_SHARED_NAMESPACE=$(${YQ_CMD} ".namespaceMapping[${i}].map-to-common-service-namespace // \"\"" "$CS_MAPS_YAML")
					CS_MAP_INDEX="${i}"
					REQUEST_NS_INDEX="${j}"
					# Found and break out of nested loop
					break 2
				fi
			done
			
		done

		# Check if CPFS Namespace is found in ConfigMap
		if [[ -z "${CPFS_SHARED_NAMESPACE}" ]]; then
			# Namespace not found in ConfigMap - try CPFS 4.17+ path as fallback
			info "Namespace \"${CP4BA_NAMESPACE}\" not found in common-service-maps ConfigMap. Checking for CPFS CommonService CR"
			
			CS_CR_NAME=$(${CLI_CMD} get commonservice -n "${CP4BA_SERVICES_NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

			if [[ -n "${CS_CR_NAME}" ]]; then
				CPFS_SHARED_NAMESPACE=$(${CLI_CMD} get commonservice "${CS_CR_NAME}" -n "${CP4BA_SERVICES_NAMESPACE}" -o jsonpath='{.spec.servicesNamespace}' 2>/dev/null)
				
				if [[ -z "${CPFS_SHARED_NAMESPACE}" ]]; then
					info "CommonService/${CS_CR_NAME} found but spec.servicesNamespace is empty. Skipping CPFS cleanup."
					CLEAN_CPFS="false"
					IS_SHARED_CPFS="false"
					CS_NAMESPACE_COUNT=0
				else
					# For CPFS 4.17+, assume dedicated CPFS (no way to detect sharing without common-service-maps)
					CLEAN_CPFS="true"
					IS_SHARED_CPFS="false"
					CS_NAMESPACE_COUNT=1
					success "CPFS namespace detected from CommonService CR: ${CPFS_SHARED_NAMESPACE}."
				fi
			else
				error "The CP4BA Namespace \"${CP4BA_NAMESPACE}\" does not map to any Cloud Pak foundational services (not in common-service-maps ConfigMap and no CommonService CR found). Please make sure the namespace you entered is correct. The script aborted."
				exit 1
			fi
		else
			# CPFS mapped to CP4BA namespace found
			printf '%b\n' "\nCloud Pak foundational services namespace:\n- ${CPFS_SHARED_NAMESPACE}"
			if [[ "${SHARED_NAMESPACE_COUNT}" -gt 0 ]]; then
				printf '%b\n' "\nList of namespace(s) that use Cloud Pak foundational services:"
				printf '%b\n' "$NAMESPACES_MAPPED_TO_CS"
			fi

			if [[ "${SHARED_NAMESPACE_COUNT}" -gt 1 && "${SEPARATION_DUTY}" == "false" ]]; then
				info "Multiple namespaces are sharing the same Cloud Pak foundational services. This script does not support cleaning up shared Cloud Pak foundational services. The script will only clean up Cloud Pak for Business Automation namespace."
				CLEAN_CPFS="false"
				IS_SHARED_CPFS="true"
			fi

			if [[ "${SHARED_NAMESPACE_COUNT}" -gt 2 && "${SEPARATION_DUTY}" == "true" ]]; then
				info "Multiple namespaces are sharing the same Cloud Pak foundational services. This script does not support cleaning up shared Cloud Pak foundational services. The script will only clean up Cloud Pak for Business Automation namespace."
				CLEAN_CPFS="false"
				IS_SHARED_CPFS="true"
			fi
		fi
	fi

	if [[ "${CLEAN_CPFS}" == "true" && -n "${CPFS_SHARED_NAMESPACE}" ]]; then
		success "Cloud Pak foundational services detected. Clean-up may continue."
	else
		info "Cloud Pak foundational services cleanup will be skipped."
	fi
fi

# Check if Multiple CP4BA are installed in the same cluster
while true; do
	printf '%b\n' "\x1B[1m\nAre there multiple CP4BA deployments on your cluster? (Yes/No, default: Yes)\x1B[0m"
	read -erp "" ans
	ans=$(echo "${ans}" | tr '[:upper:]' '[:lower:]')
	case "$ans" in
	"y"|"yes"|"")
		info "There are multiple CP4BA deployments, CustomResourceDefinitions will not be cleaned up."
	break
	;;
	"n"|"no")
		info "Since there is only one CP4BA deployment, the script will also clean up CustomResourceDefinitions (CRD)."
		CLEAN_CRDS="true"
	break
	;;
	*)
	warning "Answer must be 'Yes' or 'No'"
	esac
done

# Get Resource function
function get_resource() {
	local RESOURCE_NAME=$1
	local NAMESPACE_NAME=$2
	${CLI_CMD} get "${RESOURCE_NAME}" -n "${NAMESPACE_NAME}" --ignore-not-found=true &>/dev/null
	if [ $? -eq 0 ]; then
		for i in $(${CLI_CMD} get "${RESOURCE_NAME}" --no-headers -n "${NAMESPACE_NAME}" --ignore-not-found=true| awk '{print $1}'); do
			echo "${RESOURCE_NAME}/${i}"
		done
	fi
}

function delete_resource() {
	local RESOURCE_NAME=$1
	local NAMESPACE_NAME=$2
	${CLI_CMD} get "${RESOURCE_NAME}" -n "${NAMESPACE_NAME}" --ignore-not-found=true &>/dev/null
	if [ $? -eq 0 ]; then
		for i in $(${CLI_CMD} get "${RESOURCE_NAME}" --no-headers -n "${NAMESPACE_NAME}" --ignore-not-found=true | awk '{print $1}'); do
			${CLI_CMD} patch "${RESOURCE_NAME}"/$i -n "${NAMESPACE_NAME}" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null
			${CLI_CMD} delete "${RESOURCE_NAME}" $i -n "${NAMESPACE_NAME}" --ignore-not-found=true --wait=false 2>/dev/null
		done
	fi
}

function delete_specific_resource() {
    local RESOURCE_NAME=$1
    local NAMESPACE_NAME=$2
    local OBJECT_NAME=$3
    itemcount=$(${CLI_CMD} -n "${NAMESPACE_NAME}" get "${RESOURCE_NAME}" "${OBJECT_NAME}" --no-headers --ignore-not-found=true | wc -l)
    if [[ $itemcount == 1 ]]; then
        ${CLI_CMD} patch "${RESOURCE_NAME}"/"${OBJECT_NAME}" -n "${NAMESPACE_NAME}" -p '{"metadata":{"finalizers":[]}}' --type=merge
        # run this in the background because it can sometimes hang
        info "Deleting ${RESOURCE_NAME} ${OBJECT_NAME} in namespace ${NAMESPACE_NAME}"
        ${CLI_CMD} delete "${RESOURCE_NAME}" "${OBJECT_NAME}" -n "${NAMESPACE_NAME}" --ignore-not-found=true --force --grace-period=0 &
        info "Wait for 10 secs before checking if ${RESOURCE_NAME} ${OBJECT_NAME} is removed"
        sleep 10 
        itemcount=$(${CLI_CMD} -n "${NAMESPACE_NAME}" get "${RESOURCE_NAME}" "${OBJECT_NAME}" --no-headers --ignore-not-found=true | wc -l)
        if [[ $itemcount == 1 ]]; then
           info "${RESOURCE_NAME} ${OBJECT_NAME} is still found.  Removing finalizer..."
           ${CLI_CMD} patch "${RESOURCE_NAME}"/"${OBJECT_NAME}" -n "${NAMESPACE_NAME}" -p '{"metadata":{"finalizers":[]}}' --type=merge
        fi
    fi
}

# Function to check if webhook belongs to the operators namespace being cleaned
function webhook_belongs_to_namespace() {
    local webhook_name=$1
    local webhook_type=$2

    # Get all service namespaces referenced by this webhook
    local namespaces=$(${CLI_CMD} get ${webhook_type} ${webhook_name} \
        -o jsonpath='{.webhooks[*].clientConfig.service.namespace}' 2>/dev/null)

    # Check if the operators namespace we're cleaning is in the webhook's namespace list
    if echo "$namespaces" | grep -qw "${CP4BA_OPERATORS_NAMESPACE}"; then
        return 0  # Webhook points to our operators namespace
    else
        return 1  # Webhook points to different namespace
    fi
}

# Function to delete subscription and its CSV
function delete_subscription_and_csv() {
    local subName=$1
    local csvName

    csvName=$(${CLI_CMD} get subscription "$subName" -n "${CP4BA_OPERATORS_NAMESPACE}" -o=jsonpath='{.status.installedCSV}' 2>/dev/null)

    if [ -n "$csvName" ]; then
        INFO "Removing subscription: $subName in namespace: ${CP4BA_OPERATORS_NAMESPACE}"
        ${CLI_CMD} delete subscription "$subName" -n "${CP4BA_OPERATORS_NAMESPACE}" --ignore-not-found=true 2>/dev/null || true

        INFO "Removing CSV: $csvName in namespace: ${CP4BA_OPERATORS_NAMESPACE}"
        ${CLI_CMD} delete clusterserviceversion "$csvName" -n "${CP4BA_OPERATORS_NAMESPACE}" --ignore-not-found=true 2>/dev/null || true
    fi
}

# Print resource report
CP4BA_RESOURCES=(
	"cartridgerequirements"
	"automationbase"
	"kafka"
	"elasticsearch"
	"zenservice"
	"cartridge"
	"kafkaclaim"
	"kafkacomposite"
	"clients.oidc.security.ibm.com"
	"icp4aads"
	"pfs"
	"icp4aodm"
	"icp4adocumentprocessingengine"
	"operandrequest"
	"commonservice"
	"operandregistry"
	"operandconfig"
	"nss"
	"issuer"
	"certificate"
	"certificaterequests"
	"csv"
	"sub"
	"zenextension"
	"authentications.operator.ibm.com"
	"namespacescope"
	"operandbindinfo"
	"policycontroller.operator.ibm.com"
	"authentications.operator.ibm.com"
	"nginxingresses.operator.ibm.com"
	"oidcclientwatcher.operator.ibm.com"
	"oidcclientwatchers.operator.ibm.com"
	"commonui.operator.ibm.com"
	"commonui1.operator.ibm.com"
	"commonwebuis.operator.ibm.com"
	"commonwebuis.operators.ibm.com"
	"platformapis.operator.ibm.com"
	"certmanagers"
	"rolebindings.authorization.openshift.io"
	"rolebindings.rbac.authorization.k8s.io"
	"configuration"
	"providerconfig"
	"lock"
	"compositeresourcedefinitions"
	"configurationrevisions"
	"flinkdeployment"
	# <https://jsw.ibm.com/browse/DBACLD-156830> - Added full name of flinkdeployments to be cleaned up
	"flinkdeployments.flink.ibm.com"
	"flinkdeployments.flink.apache.org"
	"secret"
	"kafkatopics.ibmevents.ibm.com"
	"endpoints"
)

if [[ "$SEPARATION_DUTY" == "true" ]]; then
	# Seperation of Duty
	INFO "Resources in CP4BA Operators Namespace: ${CP4BA_OPERATORS_NAMESPACE}"
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		get_resource "${RESOURCE}" "${CP4BA_OPERATORS_NAMESPACE}"
	done
	for i in $(${CLI_CMD} get pv --no-headers | grep "operator-shared-pv*" | awk '{print $1}'); do
		echo "pv/${i}"
		done
	for i in $(${CLI_CMD} get operators --no-headers | grep "${CP4BA_OPERATORS_NAMESPACE} " | awk '{print $1}'); do
		echo "operators/${i}"
	done

	INFO "Resources in CP4BA Services Namespace: ${CP4BA_SERVICES_NAMESPACE}"
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		get_resource "${RESOURCE}" "${CP4BA_SERVICES_NAMESPACE}"
	done
	for i in $(${CLI_CMD} get pv --no-headers | grep "operator-shared-pv*" | awk '{print $1}'); do
		echo "pv/${i}"
	done
	for i in $(${CLI_CMD} get operators --no-headers | grep "${CP4BA_SERVICES_NAMESPACE} " | awk '{print $1}'); do
		echo "operators/${i}"
	done
else
	# Not Seperation of Duty
	INFO "Resources in CP4BA Namespace: ${CP4BA_NAMESPACE}"
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		get_resource "${RESOURCE}" "${CP4BA_NAMESPACE}"
	done

	for i in $(${CLI_CMD} get pv --no-headers -n "${CP4BA_NAMESPACE}" | grep "operator-shared-pv*" | awk '{print $1}'); do
		echo "pv/${i}"
	done
	for i in $(${CLI_CMD} get operators --no-headers | grep "${CP4BA_NAMESPACE} " | awk '{print $1}'); do
		echo "operators/${i}"
	done

fi
	
# Define CP4BA webhook patterns
INFO "GET CP4BA webhook"
CP4BA_WEBHOOK_PATTERNS_VALIDATING="validationwebhook.flink.ibm.com|vbusinessteamsservice|vwfpsruntime"
CP4BA_WEBHOOK_PATTERNS_MUTATING="mutationwebhook.flink.ibm.com"

webhook_configs=$(${CLI_CMD} get ValidatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers 2>/dev/null | grep -E "$CP4BA_WEBHOOK_PATTERNS_VALIDATING" || true)
for webhook in $webhook_configs; do
	[ -n "$webhook" ] || continue
	# Only list webhooks that point to the namespace being cleaned
	if webhook_belongs_to_namespace "$webhook" "ValidatingWebhookConfiguration"; then
		printf '%b\n' "ValidatingWebhookConfiguration/${webhook}"
	fi
done

webhook_configs=$(${CLI_CMD} get MutatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers 2>/dev/null | grep -E "$CP4BA_WEBHOOK_PATTERNS_MUTATING" || true)
for webhook in $webhook_configs; do
	[ -n "$webhook" ] || continue
	# Only list webhooks that point to the namespace being cleaned
	if webhook_belongs_to_namespace "$webhook" "MutatingWebhookConfiguration"; then
		printf '%b\n' "MutatingWebhookConfiguration/${webhook}"
	fi
done

# CPFS Resource
CPFS_RESOURCES=(
	"operandrequest"
	"commonservice"
	"operandregistry"
	"operandconfig"
	"namespacescope"
	"operandbindinfo"
	"policycontroller.operator.ibm.com"
	"authentications.operator.ibm.com"
	"authentications.operator.ibm.com"
	"nginxingresses.operator.ibm.com"
	"oidcclientwatcher.operator.ibm.com"
	"oidcclientwatchers.operator.ibm.com"
	"commonui.operator.ibm.com"
	"commonui1.operator.ibm.com"
	"commonwebuis.operator.ibm.com"
	"platformapis.operator.ibm.com"
	"nss"
	"sub"
	"csv"
	"deploy"
	"sts"
	"job"
	"svc"
	"rolebindings.authorization.openshift.io"
	"rolebindings.rbac.authorization.k8s.io"
	"objects"
)

if [[ $CLEAN_CPFS == "true" ]]; then
	# Get CPFS Shared namespace resources
	INFO "Resources in CPFS Namespace: ${CPFS_SHARED_NAMESPACE}"
	for RESOURCE in "${CPFS_RESOURCES[@]}"; do
		get_resource "${RESOURCE}" "${CPFS_SHARED_NAMESPACE}"
	done

	#Check CPFS Control namespace exist
	${CLI_CMD} get project ${CPFS_CONTROL_NAMESPACE} &>/dev/null
	if [ $? -eq 0 -a "${CS_NAMESPACE_COUNT}" -eq 1 ]; then
		# Get CPFS Control namespace resources
		INFO "Resource in Namespace: ${CPFS_CONTROL_NAMESPACE}"
		for RESOURCE in "${CPFS_RESOURCES[@]}"; do
			get_resource "${RESOURCE}" "${CPFS_CONTROL_NAMESPACE}"
		done
	fi

	#Get webhook
	INFO "Common service Webhook"
	pattern2="ibm-cs-ns-mapping-webhook-configuration"
	pattern3="ibm-common-service-validating-webhook"
	pattern4="namespace-admission-config"
	pattern5="ibm-operandrequest-webhook-configuration"
	pattern6="ibm-common-service-webhook-configuration"

	webhook_configs=$(${CLI_CMD} get ValidatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern2|$pattern3")
	for webhook in $webhook_configs; do
		printf '%b\n' "ValidatingWebhookConfiguration/${webhook}"
	done

	webhook_configs=$(${CLI_CMD} get MutatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern4|$pattern5|$pattern6")
	for webhook in $webhook_configs; do
		printf '%b\n' "MutatingWebhookConfiguration/${webhook}"
	done
fi

# Get CRDs
if [[ $CLEAN_CRDS == "true" ]]; then
	CP4BA_CRDS=(
		"contentrequests.icp4a.ibm.com"
		"contents.icp4a.ibm.com"
		"foundationrequests.icp4a.ibm.com"
		"foundations.icp4a.ibm.com"
		"icp4aclusters.icp4a.ibm.com"
		"processfederationservers.icp4a.ibm.com"
		"wfpsruntimes.icp4a.ibm.com"
		"documentprocessingengines.dpe.ibm.com"
		"icp4aoperationaldecisionmanagers.icp4a.ibm.com"
		"icp4aautomationdecisionservices.icp4a.ibm.com"
		"businessautomationmachinelearnings.icp4a.ibm.com"
		"federatedsystems.icp4a.ibm.com"
		"icp4adocumentprocessingengines.icp4a.ibm.com"
		"insightsenginerequests.icp4a.ibm.com"
		"insightsengines.icp4a.ibm.com"
		"workflowruntimes.icp4a.ibm.com"
	)
	INFO "CustomResourceDefinitions"
	for i in "${CP4BA_CRDS[@]}"; do
		${CLI_CMD} get crd $i &>/dev/null
		if [ $? -eq 0 ]; then
			echo "crd/${i}"
		fi
	done
fi

if [[ $CLEAN_CPFS == "true" ]]; then
	# Configmaps for CPFS
	INFO "Configmaps in ${COMMON_SERVICES_CM_NAMESPACE} namespace"
	for i in $(${CLI_CMD} get cm common-service-maps ibm-common-services-status -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "cm/${i}"
	done

	# Role
	INFO "Other Resources"
	for i in $(${CLI_CMD} get ClusterRoleBinding ibm-common-service-webhook secretshare-ibm-common-services $(${CLI_CMD} get ClusterRoleBinding | grep nginx-ingress-clusterrole | awk '{print $1}') --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "ClusterRoleBinding/${i}"
	done
	for i in $(${CLI_CMD} get ClusterRole ibm-common-service-webhook secretshare nginx-ingress-clusterrole --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "ClusterRole/${i}"
	done
	for i in $(${CLI_CMD} get RoleBinding ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "RoleBinding/${i}"
	done
	for i in $(${CLI_CMD} get Role ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "Role/${i}"
	done
	for i in $(${CLI_CMD} get scc nginx-ingress-scc --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "scc/${i}"
	done

	# Get apiservice
	${CLI_CMD} get apiservice v1beta1.webhook.certmanager.k8s.io &>/dev/null
	if [ $? -eq 0 ]; then
		echo "apiservice/v1beta1.webhook.certmanager.k8s.io"
	fi
	${CLI_CMD} get apiservice v1.metering.ibm.com &>/dev/null
	if [ $? -eq 0 ]; then
		echo "apiservice/v1.metering.ibm.com"
	fi
fi

# Clean up confirmation
if [[ $SKIP_CONFIRM == "false" ]]; then
	info "The list above are resources remaining in the namespaces that will be cleaned up."
	echo
	if [[ $CLEAN_CPFS == "true" ]]; then
		info "This script will clean up IBM Cloud Pak for Business Automation and IBM Cloud Pak foundational services namespace, including deleting the namespaces.\n"
	else
		info "This script will clean up IBM Cloud Pak for Business Automation namespace and delete the namespace.\n"
	fi
	read -p "Enter Y or y to continue: " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		error "Clean up not confirmed. Exiting script."
		exit 0
	fi
	echo
	info "You have confirmed to clean up. Continue to clean up the namespace(s)."
	sleep 2
	echo
fi

INFO "Delete all CSV and Subscriptions to prevent webhook recreation"
# Delete all subscriptions and their CSVs in operator namespace
${CLI_CMD} get subscription.operators.coreos.com -n "${CP4BA_OPERATORS_NAMESPACE}" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | while read -r subName; do
    if [ -n "$subName" ]; then
        delete_subscription_and_csv "$subName"
    fi
done

INFO "Wait 5 seconds for operators to be fully removed"
sleep 5

INFO "Delete CP4BA webhooks that point to operators namespace: ${CP4BA_OPERATORS_NAMESPACE}"

# Delete Validating webhooks that point to operators namespace
webhook_configs=$(${CLI_CMD} get ValidatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers 2>/dev/null | grep -E "$CP4BA_WEBHOOK_PATTERNS_VALIDATING" || true)
for webhook in $webhook_configs; do
    [ -n "$webhook" ] || continue

    # Check if this webhook points to the operators namespace
    if webhook_belongs_to_namespace "$webhook" "ValidatingWebhookConfiguration"; then
        INFO "Deleting ValidatingWebhookConfiguration: $webhook points to ${CP4BA_OPERATORS_NAMESPACE}"
        ${CLI_CMD} delete ValidatingWebhookConfiguration "$webhook" --ignore-not-found=true || true
    fi
done

# Delete Mutating webhooks that point to operators namespace
webhook_configs=$(${CLI_CMD} get MutatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers 2>/dev/null | grep -E "$CP4BA_WEBHOOK_PATTERNS_MUTATING" || true)
for webhook in $webhook_configs; do
    [ -n "$webhook" ] || continue

    # Check if this webhook points to the operators namespace
    if webhook_belongs_to_namespace "$webhook" "MutatingWebhookConfiguration"; then
        INFO "Deleting MutatingWebhookConfiguration: $webhook points to ${CP4BA_OPERATORS_NAMESPACE}"
        ${CLI_CMD} delete MutatingWebhookConfiguration "$webhook" --ignore-not-found=true || true
    fi
done
sleep 5

# CP4BA clean up
if [[ "$SEPARATION_DUTY" == "true" ]]; then
	# Seperation of Duty
	INFO "Cleaning up resources in CP4BA Operators Namespace: ${CP4BA_OPERATORS_NAMESPACE}"
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		delete_resource "${RESOURCE}" "${CP4BA_OPERATORS_NAMESPACE}"
	done
	# Another round of clean up in case of hanging reources
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		delete_resource "${RESOURCE}" "${CP4BA_OPERATORS_NAMESPACE}"
	done
	
	for i in $(${CLI_CMD} get operators --no-headers | grep "${CP4BA_OPERATORS_NAMESPACE} " | awk '{print $1}'); do
		echo "operators/${i}"
	done

	INFO "Cleaning up resources in CP4BA Services Namespace: ${CP4BA_SERVICES_NAMESPACE}"
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		delete_resource "${RESOURCE}" "${CP4BA_SERVICES_NAMESPACE}"
	done
	# Another round of clean up in case of hanging reources
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		delete_resource "${RESOURCE}" "${CP4BA_SERVICES_NAMESPACE}"
	done

	# In separation of duties, the PVC is created in the CP4BA services namespace
	INFO "Cleaning up PVC operator-shared-pvc and corresponding PV in CP4BA Operators Namespace: ${CP4BA_SERVICES_NAMESPACE}"
	delete_specific_resource "pvc" "${CP4BA_SERVICES_NAMESPACE}" "operator-shared-pvc"

	for i in $(${CLI_CMD} get operators --no-headers | grep "${CP4BA_SERVICES_NAMESPACE} " | awk '{print $1}'); do
		${CLI_CMD} delete operator "$i"
	done
else
	INFO "Cleaning up resources in CP4BA Namespace: ${CP4BA_NAMESPACE}"
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		delete_resource "${RESOURCE}" "${CP4BA_NAMESPACE}"
	done
	# Another round of clean up in case of hanging reources
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		delete_resource "${RESOURCE}" "${CP4BA_NAMESPACE}"
	done

	${CLI_CMD} get pv --no-headers | grep "operator-shared-pv*" | grep -E "Available|Failed" | awk '{print $1}' | xargs ${CLI_CMD} delete pv 2>/dev/null

	for i in $(${CLI_CMD} get operators --no-headers | grep "${CP4BA_NAMESPACE} " | awk '{print $1}'); do
		${CLI_CMD} delete operator "$i"
	done
fi

if [[ $CLEAN_CPFS == "true" ]]; then
	# Clean up CPFS
	INFO "Cleaning up resources in CPFS Namespace: ${CPFS_SHARED_NAMESPACE}"
	for RESOURCE in "${CPFS_RESOURCES[@]}"; do
		delete_resource "${RESOURCE}" "${CPFS_SHARED_NAMESPACE}"
	done

	# Another round of clean up in case of hanging reources
	for RESOURCE in "${CPFS_RESOURCES[@]}"; do
		delete_resource "${RESOURCE}" "${CPFS_SHARED_NAMESPACE}"
	done

	# Clean up CPFS control
	${CLI_CMD} get project ${CPFS_CONTROL_NAMESPACE} &>/dev/null
	if [ $? -eq 0 -a "${CS_NAMESPACE_COUNT}" -eq 1 ]; then
		# Delete CPFS Control namespace resources
		INFO "Cleaning up resources in Namespace: ${CPFS_CONTROL_NAMESPACE}"
		for RESOURCE in "${CPFS_RESOURCES[@]}"; do
			delete_resource "${RESOURCE}" "${CPFS_CONTROL_NAMESPACE}"
		done
		# Another round of clean up in case of hanging reources
		for RESOURCE in "${CPFS_RESOURCES[@]}"; do
			delete_resource "${RESOURCE}" "${CPFS_CONTROL_NAMESPACE}"
		done
	fi

	INFO "Delete common service webhook"
	pattern2="ibm-cs-ns-mapping-webhook-configuration"
	pattern3="ibm-common-service-validating-webhook"
	pattern4="namespace-admission-config"
	pattern5="ibm-operandrequest-webhook-configuration"
	pattern6="ibm-common-service-webhook-configuration"

	webhook_configs=$(${CLI_CMD} get ValidatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern2|$pattern3")
	if [ -n "$webhook_configs" ]; then
		for webhook in $webhook_configs; do
			${CLI_CMD} delete ValidatingWebhookConfiguration "$webhook" --ignore-not-found=true
		done
	fi

	webhook_configs=$(${CLI_CMD} get MutatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern4|$pattern5|$pattern6")
	if [ -n "$webhook_configs" ]; then
		for webhook in $webhook_configs; do
			${CLI_CMD} delete MutatingWebhookConfiguration "$webhook" --ignore-not-found=true
		done
	fi
	# Cleaning up Role related resources
	${CLI_CMD} delete ClusterRoleBinding ibm-common-service-webhook secretshare-ibm-common-services $(${CLI_CMD} get ClusterRoleBinding 2>/dev/null | grep nginx-ingress-clusterrole | awk '{print $1}') --ignore-not-found
	${CLI_CMD} delete ClusterRole ibm-common-service-webhook secretshare nginx-ingress-clusterrole --ignore-not-found
	${CLI_CMD} delete RoleBinding ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found
	${CLI_CMD} delete Role ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found
	${CLI_CMD} delete scc nginx-ingress-scc --ignore-not-found

	# Cleaning up apiservice
	${CLI_CMD} get apiservice v1beta1.webhook.certmanager.k8s.io 2>/dev/null
	if [ $? -eq 0 ]; then
		INFO "Delete apiservice v1beta1.webhook.certmanager.k8s.io"
		${CLI_CMD} delete apiservice v1beta1.webhook.certmanager.k8s.io
	fi
	${CLI_CMD} get apiservice v1.metering.ibm.com 2>/dev/null
	if [ $? -eq 0 ]; then
		INFO "Delete apiservice v1.metering.ibm.com"
		${CLI_CMD} delete apiservice v1.metering.ibm.com
	fi
fi

# Update/delete kube-public/common-service-maps ONLY when legacy CM exists.For CPFS 4.17+ there is no CM to patch.
if [[ "${IS_SHARED_CPFS}" == "true" ]]; then
	if [[ -n "${CS_MAPS_YAML:-}" && -f "${CS_MAPS_YAML}" ]]; then
		INFO "Remove mapping from ${COMMON_SERVICES_CM_NAMESPACE} namespace"
		NEW_CS_MAPS=$(${YQ_CMD} eval "del(.namespaceMapping[${CS_MAP_INDEX}].requested-from-namespace[${REQUEST_NS_INDEX}])" "$CS_MAPS_YAML")
		PATCH=$(jq -n --arg v "$NEW_CS_MAPS" \
			'[{"op":"replace","path":"/data/common-service-maps.yaml","value":$v}]')
		${CLI_CMD} patch configmap common-service-maps -n "${COMMON_SERVICES_CM_NAMESPACE}" --type=json -p "$PATCH"
	fi

elif [[ "${CLEAN_CPFS}" == "true" ]]; then
	if [[ -n "${CS_MAPS_YAML:-}" && -f "${CS_MAPS_YAML}" && -n "${CS_MAP_INDEX:-}" ]]; then
		INFO "Remove mapping from ${COMMON_SERVICES_CM_NAMESPACE} namespace"
  		# Check if there are other namespace mappings besides the one being deleted
		REMAINING_MAPPINGS=$(${YQ_CMD} eval '.namespaceMapping | length' "$CS_MAPS_YAML")
		if [[ $REMAINING_MAPPINGS -gt 1 ]]; then
  			# <https://jsw.ibm.com/browse/DBACLD-201104> If there are multiple deployments, only remove this specific mapping
			info "Multiple CP4BA deployments detected. Removing only the mapping for namespace: ${CP4BA_NAMESPACE}"
			NEW_CS_MAPS=$(${YQ_CMD} eval "del(.namespaceMapping[${CS_MAP_INDEX}])" "$CS_MAPS_YAML")
			PATCH=$(jq -n --arg v "$NEW_CS_MAPS" \
				'[{"op":"replace","path":"/data/common-service-maps.yaml","value":$v}]')
			${CLI_CMD} patch configmap common-service-maps -n "${COMMON_SERVICES_CM_NAMESPACE}" --type=json -p "$PATCH"
		else
			INFO "Only one CP4BA deployment detected, deleting common-service-maps ConfigMap"
			${CLI_CMD} delete configmap common-service-maps -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found=true
		fi
	else
		info "Namespace not present in common-service-maps. No ConfigMap update required."
	fi
fi

# Delete resource in openshift-operator namespace
if [[ $SELECT_ALL == "true" ]]; then
	INFO "Cleaning up openshift-operators namespace"
	${CLI_CMD} -n $OPENSHIFT_OPERATORS_NAMESPACE delete operandrequest --force --grace-period=0 --all --ignore-not-found=true --wait=true
	${CLI_CMD} delete csv,sub -n $OPENSHIFT_OPERATORS_NAMESPACE --all --ignore-not-found=true --wait=true
	${CLI_CMD} -n $OPENSHIFT_OPERATORS_NAMESPACE get cm | grep -E "iaf|ibm|namespace-scope" | awk '{print $1}' | xargs ${CLI_CMD} delete cm -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true
	${CLI_CMD} -n $OPENSHIFT_OPERATORS_NAMESPACE get sa | grep -E "iaf|ibm|postgresql" | awk '{print $1}' | xargs ${CLI_CMD} delete sa -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true
	${CLI_CMD} delete rolebinding iaf-insights-engine-operator-leader-election-rolebinding -n $OPENSHIFT_OPERATORS_NAMESPACE
	${CLI_CMD} delete lease,secret,svc,netpol,job,deploy,pvc,role --all -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true
	${CLI_CMD} delete commonservice,operandregistry,operandconfig --all -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true --wait=true 
	for i in $(${CLI_CMD} -n $OPENSHIFT_OPERATORS_NAMESPACE get operandrequest --no-headers | awk '{print $1}'); do
		${CLI_CMD} -n $OPENSHIFT_OPERATORS_NAMESPACE patch operandrequest/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
		${CLI_CMD} -n $OPENSHIFT_OPERATORS_NAMESPACE delete operandrequest $i --ignore-not-found=true --wait=true
	done
fi

# Removing CRDs
INFO "Cleaning up CP4BA CRDs"
if [[ $CLEAN_CRDS == "true" ]]; then
	for i in "${CP4BA_CRDS[@]}"; do
		${CLI_CMD} patch crd/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
		${CLI_CMD} delete crd $i --ignore-not-found=true --grace-period=0 --force
	done
fi

# Switch back to the default namespace
${CLI_CMD} project default


if [[ "$SEPARATION_DUTY" == "true" ]]; then
	INFO "Cleaning up all pods before deleting CP4BA operators namespace: ${CP4BA_OPERATORS_NAMESPACE}"
	${CLI_CMD} delete pod --all -n "$CP4BA_OPERATORS_NAMESPACE" --grace-period=0 --force

	INFO "Deleting CP4BA Namespace: ${CP4BA_OPERATORS_NAMESPACE}"
	${CLI_CMD} delete project "${CP4BA_OPERATORS_NAMESPACE}"

	info "Wait until namespace ${CP4BA_OPERATORS_NAMESPACE} is completely deleted."
	count=0
	while :; do
		${CLI_CMD} get project "${CP4BA_OPERATORS_NAMESPACE}" 2>/dev/null
		if [[ $? -gt 0 ]]; then
			success "Namespace ${CP4BA_OPERATORS_NAMESPACE} deletion successful."
			break
		else
			((count += 1))
			if ((count <= 36)); then
				wait_msg "Waiting for namespace ${CP4BA_OPERATORS_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
				sleep 10
			else
				error "Deleting namespace ${CP4BA_OPERATORS_NAMESPACE} is taking too long and giving up"
				${CLI_CMD} get project "${CP4BA_OPERATORS_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done

	INFO "Cleaning up all pods before deleting CP4BA services operators namespace: ${CP4BA_SERVICES_NAMESPACE}"
	${CLI_CMD} delete pod --all -n "$CP4BA_SERVICES_NAMESPACE" --grace-period=0 --force

	INFO "Deleting CP4BA Namespace: ${CP4BA_SERVICES_NAMESPACE}"
	${CLI_CMD} delete project "${CP4BA_SERVICES_NAMESPACE}"

	info "Wait until namespace ${CP4BA_SERVICES_NAMESPACE} is completely deleted."
	count=0
	while :; do
		${CLI_CMD} get project "${CP4BA_SERVICES_NAMESPACE}" 2>/dev/null
		if [[ $? -gt 0 ]]; then
			success "Namespace ${CP4BA_SERVICES_NAMESPACE} deletion successful."
			break
		else
			((count += 1))
			if ((count <= 36)); then
				wait_msg "Waiting for namespace ${CP4BA_SERVICES_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
				sleep 10
			else
				error "Deleting namespace ${CP4BA_SERVICES_NAMESPACE} is taking too long and giving up"
				${CLI_CMD} get project "${CP4BA_SERVICES_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done

else

	INFO "Cleaning up all pods before deleting CP4BA namespace."
	${CLI_CMD} delete pod --all -n "$CP4BA_NAMESPACE" --grace-period=0 --force

	INFO "Deleting CP4BA Namespace: ${CP4BA_NAMESPACE}"
	${CLI_CMD} delete project "${CP4BA_NAMESPACE}"

	info "Wait until namespace ${CP4BA_NAMESPACE} is completely deleted."
	count=0
	while :; do
		${CLI_CMD} get project "${CP4BA_NAMESPACE}" 2>/dev/null
		if [[ $? -gt 0 ]]; then
			success "Namespace ${CP4BA_NAMESPACE} deletion successful."
			break
		else
			((count += 1))
			if ((count <= 36)); then
				wait_msg "Waiting for namespace ${CP4BA_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
				sleep 10
			else
				error "Deleting namespace ${CP4BA_NAMESPACE} is taking too long and giving up"
				${CLI_CMD} get project "${CP4BA_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done
fi

if [[ $CLEAN_CPFS == "true" ]]; then
	INFO "Cleaning up all pods before deleting CPfs namespace."
	${CLI_CMD} delete pod --all -n "${CPFS_SHARED_NAMESPACE}" --grace-period=0 --force
	
	INFO "Deleting namespace ${CPFS_SHARED_NAMESPACE}"
	${CLI_CMD} delete project "${CPFS_SHARED_NAMESPACE}"

	info "Wait until namespace ${CPFS_SHARED_NAMESPACE} is completely deleted."
	count=0
	while :; do
		${CLI_CMD} get project "${CPFS_SHARED_NAMESPACE}" 2>/dev/null
		if [[ $? -gt 0 ]]; then
			success "Namespace ${CPFS_SHARED_NAMESPACE} deletion successful."
			break
		else
			((count += 1))
			if ((count <= 36)); then
				wait_msg "Waiting for namespace ${CPFS_SHARED_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
				sleep 10
			else
				error "Deleting namespace ${CPFS_SHARED_NAMESPACE} is taking too long and giving up"
				${CLI_CMD} get project "${CPFS_SHARED_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done
	${CLI_CMD} get project "${CPFS_CONTROL_NAMESPACE}" &>/dev/null
	if [ $? -eq 0 -a "${CS_NAMESPACE_COUNT}" -eq 1 ]; then
		# Delete CPfs Control namespace if namespace exists and if there is only one deployment using CPfs
		INFO "Cleaning up all pods before deleting CPfs control namespace."
		${CLI_CMD} delete pod --all -n "${CPFS_CONTROL_NAMESPACE}" --grace-period=0 --force
		INFO "Deleting namespace ${CPFS_CONTROL_NAMESPACE}"
		${CLI_CMD} delete project "${CPFS_CONTROL_NAMESPACE}"
		info "Wait until namespace ${CPFS_CONTROL_NAMESPACE} is completely deleted."
		count=0
		while :; do
			${CLI_CMD} get project "${CPFS_CONTROL_NAMESPACE}" 2>/dev/null
			if [[ $? -gt 0 ]]; then
				success "Namespace ${CPFS_CONTROL_NAMESPACE} deletion successful."
				break
			else
				((count += 1))
				if ((count <= 36)); then
					wait_msg "Waiting for namespace ${CPFS_CONTROL_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
					sleep 10
				else
					error "Deleting namespace ${CPFS_CONTROL_NAMESPACE} is taking too long and giving up"
					${CLI_CMD} get project "${CPFS_CONTROL_NAMESPACE}" -o yaml
					exit 1
				fi
			fi
		done
	fi
fi


# Delete common-service-maps.yaml temp file if it exists
if [[ -n "${CS_MAPS_YAML:-}" && -f "${CS_MAPS_YAML}" ]]; then
	rm -f "${CS_MAPS_YAML}"
fi

success "Clean up has completed."
