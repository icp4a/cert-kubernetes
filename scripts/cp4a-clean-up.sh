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

if ! [ -x "$(command -v oc)" ]; then
	error "OpenShift CLI is not installed."
	exit 1
fi

oc project > /dev/null 2>&1
if [ $? -gt 0 ]; then
	error "oc login is required for running this script."
	exit 1
fi

# CP4BA Namespace check
if [ -z "$CP4BA_NAMESPACE" ]; then
	error "CP4BA namespace needed. Please enter the CP4BA namespace following -n or use -h for more details."
	exit 1
fi

# Namespace check to avoid cleaning up in the wrong namespace
if [[ "$CP4BA_NAMESPACE" == openshift* ]]; then
	error "Then entered namespace should not be 'openshift' or start with 'openshift'. It should be the namespace where CP4BA is installed. The script aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == kube* ]]; then
	error "Then entered namespace should not be 'kube' or start with 'kube'. It should be the namespace where CP4BA is installed. The script aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "services" ]]; then
	error "Then entered namespace should not be 'services'. It should be the namespace where CP4BA is installed. The script aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "default" ]]; then
	error "Then entered namespace should not be 'default'. It should be the namespace where CP4BA is installed. The script aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "calico-system" ]]; then
	error "Then entered namespace should not be 'calico-system'. It should be the namespace where CP4BA is installed. The script aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-cert-store" ]]; then
	error "Then entered namespace should not be 'ibm-cert-store'. It should be the namespace where CP4BA is installed. The script aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-observe" ]]; then
	error "Then entered namespace should not be 'ibm-observe'. It should be the namespace where CP4BA is installed. The script aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-odf-validation-webhook" ]]; then
	error "Then entered namespace should not be 'ibm-odf-validation-webhook'. It should be the namespace where CP4BA is installed. The script aborted."
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-system" ]]; then
	error "Then entered namespace should not be 'ibm-system'. It should be the namespace where CP4BA is installed. The script aborted."
	exit 1
fi

# Validate CP4BA_NAMESPACE env var is for existing namespace
if [ -z "$(oc get project "${CP4BA_NAMESPACE}" 2>/dev/null)" ]; then
	error "Namespace ${CP4BA_NAMESPACE} does not exist. Specify an existing namespace where CP4BA is installed."
	exit 1
fi

echo -e "The CP4BA namespace entered:\n- ${CP4BA_NAMESPACE}\n"
echo -e "Note: Please make sure you have entered the namespace you intended to clean up.\n"
success "All prerequisites passed. Ready for clean up."
echo
echo -e "\x1B[33;5m[ATTENTION]: \x1B[0m\x1B[1;33mThis script is only intended to delete any remaining resources in the Cloud Pak for Business Automation and Cloud Pak foundational services namespace(s), and it is not intended for uninstalling Cloud Pak for Business Automation and Cloud Pak foundational services deployment. The script also does not support cleaning up shared Cloud Pak foundational services.\x1B[0m\n"

# CP4BA seperation of duty check
CP4BA_CM_CONFIG=$(oc get configmap ibm-cp4ba-common-config -n ${CP4BA_NAMESPACE} -o jsonpath="{ .data}" 2>/dev/null)
CP4BA_CM_CONFIG_YAML=$(mktemp)
echo "$CP4BA_CM_CONFIG" > "$CP4BA_CM_CONFIG_YAML"
# get operators namespace
CP4BA_OPERATORS_NAMESPACE=$(${YQ_CMD} r "$CP4BA_CM_CONFIG_YAML" "operators_namespace")
# get services namespace (Same as the CP4BA namespace)
CP4BA_SERVICES_NAMESPACE=$(${YQ_CMD} r "$CP4BA_CM_CONFIG_YAML" "services_namespace")

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

if [[ "$ALL_NAMESPACE" == "false" ]]; then
	# CPFS shared check
	CS_MAP=$(oc get configmap "${COMMON_SERVICES_CM_DEDICATED_NAME}"  -n kube-public -o jsonpath="{ .data['common-service-maps\.yaml']}" 2>/dev/null)
	if [[ -z $CS_MAP ]]; then
		error "No Cloud Pak foundational services mapping was detected, Cloud Pak foundational services could be shared or does not exist. The script aborted."
		exit 1
	else
		CS_MAPS_YAML=$(mktemp) 
		echo "$CS_MAP" > "$CS_MAPS_YAML"
		CS_NAMESPACE_COUNT=$(${YQ_CMD} r "$CS_MAPS_YAML" "namespaceMapping" -l)
		for(( i = 0; i < $CS_NAMESPACE_COUNT; i++ ))
		do
			# Get CS namespace
			CS_NS=$(${YQ_CMD} r "$CS_MAPS_YAML" "namespaceMapping[${i}].map-to-common-service-namespace")
			# Get CS control namespace
			CPFS_CONTROL_NAMESPACE=$(${YQ_CMD} r "$CS_MAPS_YAML" "controlNamespace")
			# Get Shared namespace count
			SHARED_NAMESPACE_COUNT=$(${YQ_CMD} r "$CS_MAPS_YAML" "namespaceMapping[${i}].requested-from-namespace" -l)
			# Check if the Entered CP4BA namespace is in the list
			for((j = 0; j < $SHARED_NAMESPACE_COUNT; j++))
			do
				# Get Cloud Pak namespace
				CP_NS=$(${YQ_CMD} r "$CS_MAPS_YAML" "namespaceMapping[${i}].requested-from-namespace[${j}]")
				if [[ "$CP_NS" == "$CP4BA_NAMESPACE" ]];then
					NAMESPACES_MAPPED_TO_CS=$(${YQ_CMD} r "$CS_MAPS_YAML" "namespaceMapping[${i}].requested-from-namespace")
					CPFS_SHARED_NAMESPACE=$(${YQ_CMD} r "$CS_MAPS_YAML" "namespaceMapping[${i}].map-to-common-service-namespace")
					CS_MAP_INDEX="${i}"
					# Found and break out of nested loop
					break 2
				fi
			done
			
		done

		# Check if CPFS Namespace is found
		if [[ -z ${CPFS_SHARED_NAMESPACE} ]]; then
			error "The CP4BA Namespace \"${CP4BA_NAMESPACE}\" does not map to any Cloud Pak foundational services, please make sure the namespace you entered is correct. The script aborted."
			exit 1
		else
			# CPFS mapped to CP4BA namespace found
			echo -e "\nCloud Pak foundational services namespace:\n- ${CPFS_SHARED_NAMESPACE}"
			if [[ "${SHARED_NAMESPACE_COUNT}" -gt 0 ]]; then
				echo -e "\nList of namespace(s) that use Cloud Pak foundational services:"
				echo -e "$NAMESPACES_MAPPED_TO_CS"
			fi

			if [[ "${SHARED_NAMESPACE_COUNT}" -gt 1 && "${SEPARATION_DUTY}" == "false" ]]; then
				info "Multiple namespaces are sharing the same Cloud Pak foundational services. This script does not support cleaning up shared Cloud Pak foundational services. The script will only clean up Cloud Pak for Business Automation namespace."
				CLEAN_CPFS="false"
			fi

			if [[ "${SHARED_NAMESPACE_COUNT}" -gt 2 && "${SEPARATION_DUTY}" == "true" ]]; then
				info "Multiple namespaces are sharing the same Cloud Pak foundational services. This script does not support cleaning up shared Cloud Pak foundational services. The script will only clean up Cloud Pak for Business Automation namespace."
				CLEAN_CPFS="false"
			fi
		fi
	fi
	success "Cloud Pak foundational services mapping detected. Clean-up may continue."
fi

# Check if Multiple CP4BA are installed in the same cluster
while true; do
	echo -e "\x1B[1m\nAre there multiple CP4BA deployments on your cluster? (Yes/No, default: Yes)\x1B[0m"
	read -rp "" ans 
	ans=$(echo "${ans}" | tr '[:upper:]' '[:lower:]')
	case "$ans" in
	"y"|"yes"|"")
		info "There are multiple CP4BA deployments, CustomResourceDefinitions will not be cleaned up."
	break
	;;
	"n"|"no")
		info "There is only one CP4BA deployment, CustomResourceDefinitions will be cleaned up."
		CLEAN_CRDS="true"
	break
	;;
	*)
	warning "Answer must be 'Yes' or 'No'"
	esac
done

# Get CP4BA Operator version
cp4a_operator_csv_name_target_ns=$(oc get csv -n "$CP4BA_NAMESPACE" --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
CP4BA_VERSION=$(oc get csv $cp4a_operator_csv_name_target_ns -n "$CP4BA_NAMESPACE" --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')

# Get Resource function
function get_resource() {
	local RESOURCE_NAME=$1
	local NAMESPACE_NAME=$2
	oc get "${RESOURCE_NAME}" -n "${NAMESPACE_NAME}" --ignore-not-found=true &>/dev/null
	if [ $? -eq 0 ]; then
		for i in $(oc get "${RESOURCE_NAME}" --no-headers -n "${NAMESPACE_NAME}" --ignore-not-found=true| awk '{print $1}'); do
			echo "${RESOURCE_NAME}/${i}"
		done
	fi
}

function delete_resource() {
	local RESOURCE_NAME=$1
	local NAMESPACE_NAME=$2
	oc get "${RESOURCE_NAME}" -n "${NAMESPACE_NAME}" --ignore-not-found=true &>/dev/null
	if [ $? -eq 0 ]; then
		for i in $(oc get "${RESOURCE_NAME}" --no-headers -n "${NAMESPACE_NAME}" --ignore-not-found=true | awk '{print $1}'); do
			oc patch "${RESOURCE_NAME}"/$i -n "${NAMESPACE_NAME}" -p '{"metadata":{"finalizers":[]}}' --type=merge
			oc delete "${RESOURCE_NAME}" $i -n "${NAMESPACE_NAME}" --ignore-not-found=true
		done
	fi
}

function delete_specific_resource() {
    local RESOURCE_NAME=$1
    local NAMESPACE_NAME=$2
    local OBJECT_NAME=$3
    itemcount=$(oc -n "${NAMESPACE_NAME}" get "${RESOURCE_NAME}" "${OBJECT_NAME}" --no-headers --ignore-not-found=true | wc -l)
    if [[ $itemcount == 1 ]]; then
        oc patch "${RESOURCE_NAME}"/"${OBJECT_NAME}" -n "${NAMESPACE_NAME}" -p '{"metadata":{"finalizers":[]}}' --type=merge
        # run this in the background because it can sometimes hang
        info "Deleting ${RESOURCE_NAME} ${OBJECT_NAME} in namespace ${NAMESPACE_NAME}"
        oc delete "${RESOURCE_NAME}" "${OBJECT_NAME}" -n "${NAMESPACE_NAME}" --ignore-not-found=true --force --grace-period=0 &
        info "Wait for 10 secs before checking if ${RESOURCE_NAME} ${OBJECT_NAME} is removed"
        sleep 10 
        itemcount=$(oc -n "${NAMESPACE_NAME}" get "${RESOURCE_NAME}" "${OBJECT_NAME}" --no-headers --ignore-not-found=true | wc -l)
        if [[ $itemcount == 1 ]]; then
           info "${RESOURCE_NAME} ${OBJECT_NAME} is still found.  Removing finalizer..."
           oc patch "${RESOURCE_NAME}"/"${OBJECT_NAME}" -n "${NAMESPACE_NAME}" -p '{"metadata":{"finalizers":[]}}' --type=merge
        fi
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
	"secret"
	"kafkatopics.ibmevents.ibm.com"
)

if [[ "$SEPARATION_DUTY" == "true" ]]; then
	# Seperation of Duty
	INFO "Resources in CP4BA Operators Namespace: ${CP4BA_OPERATORS_NAMESPACE}"
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		get_resource "${RESOURCE}" "${CP4BA_OPERATORS_NAMESPACE}"
	done
	for i in $(oc get pv --no-headers | grep "operator-shared-pv*" | awk '{print $1}'); do
		echo "pv/${i}"
		done
	for i in $(oc get operators --no-headers | grep "${CP4BA_OPERATORS_NAMESPACE} " | awk '{print $1}'); do
		echo "operators/${i}"
	done

	INFO "Resources in CP4BA Services Namespace: ${CP4BA_SERVICES_NAMESPACE}"
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		get_resource "${RESOURCE}" "${CP4BA_SERVICES_NAMESPACE}"
	done
	for i in $(oc get pv --no-headers | grep "operator-shared-pv*" | awk '{print $1}'); do
		echo "pv/${i}"
	done
	for i in $(oc get operators --no-headers | grep "${CP4BA_SERVICES_NAMESPACE} " | awk '{print $1}'); do
		echo "operators/${i}"
	done
else
	# Not Seperation of Duty
	INFO "Resources in CP4BA Namespace: ${CP4BA_NAMESPACE}"
	for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
		get_resource "${RESOURCE}" "${CP4BA_NAMESPACE}"
	done

	for i in $(oc get pv --no-headers -n "${CP4BA_NAMESPACE}" | grep "operator-shared-pv*" | awk '{print $1}'); do
		echo "pv/${i}"
	done
	for i in $(oc get operators --no-headers | grep "${CP4BA_NAMESPACE} " | awk '{print $1}'); do
		echo "operators/${i}"
	done

fi

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
	oc get project ${CPFS_CONTROL_NAMESPACE} &>/dev/null
	if [ $? -eq 0 -a $CS_NAMESPACE_COUNT -eq 1 ]; then
		# Get CPFS Control namespace resources
		INFO "Resource in Namespace: ${CPFS_CONTROL_NAMESPACE}"
		for RESOURCE in "${CPFS_RESOURCES[@]}"; do
			get_resource "${RESOURCE}" "${CPFS_CONTROL_NAMESPACE}"
		done
	fi

	#Get webhook
	INFO "Webhook"
	pattern2="ibm-cs-ns-mapping-webhook-configuration"
	pattern3="ibm-common-service-validating-webhook"
	pattern4="namespace-admission-config"
	pattern5="ibm-operandrequest-webhook-configuration"
	pattern6="ibm-common-service-webhook-configuration"

	webhook_configs=$(oc get ValidatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern2|$pattern3")
	for webhook in $webhook_configs; do
		echo -e "ValidatingWebhookConfiguration/${webhook}"
	done

	webhook_configs=$(oc get MutatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern4|$pattern5|$pattern6")
	for webhook in $webhook_configs; do
		echo -e "MutatingWebhookConfiguration/${webhook}"
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
		oc get crd $i &>/dev/null
		if [ $? -eq 0 ]; then
			echo "crd/${i}"
		fi
	done
fi

if [[ $CLEAN_CPFS == "true" ]]; then
	# Configmaps for CPFS
	INFO "Configmaps in ${COMMON_SERVICES_CM_NAMESPACE} namespace"
	for i in $(oc get cm common-service-maps ibm-common-services-status -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "cm/${i}"
	done

	# Role
	INFO "Other Resources"
	for i in $(oc get ClusterRoleBinding ibm-common-service-webhook secretshare-ibm-common-services $(oc get ClusterRoleBinding | grep nginx-ingress-clusterrole | awk '{print $1}') --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "ClusterRoleBinding/${i}"
	done
	for i in $(oc get ClusterRole ibm-common-service-webhook secretshare nginx-ingress-clusterrole --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "ClusterRole/${i}"
	done
	for i in $(oc get RoleBinding ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "RoleBinding/${i}"
	done
	for i in $(oc get Role ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "Role/${i}"
	done
	for i in $(oc get scc nginx-ingress-scc --ignore-not-found --no-headers | awk '{print $1}'); do
		echo "scc/${i}"
	done

	# Get apiservice
	oc get apiservice v1beta1.webhook.certmanager.k8s.io &>/dev/null
	if [ $? -eq 0 ]; then
		echo "apiservice/v1beta1.webhook.certmanager.k8s.io"
	fi
	oc get apiservice v1.metering.ibm.com &>/dev/null
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
	
	for i in $(oc get operators --no-headers | grep "${CP4BA_OPERATORS_NAMESPACE} " | awk '{print $1}'); do
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

	for i in $(oc get operators --no-headers | grep "${CP4BA_SERVICES_NAMESPACE} " | awk '{print $1}'); do
		oc delete operator "$i"
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

	oc get pv --no-headers | grep "operator-shared-pv*" | grep -E "Available|Failed" | awk '{print $1}' | xargs oc delete pv 2>/dev/null

	for i in $(oc get operators --no-headers | grep "${CP4BA_NAMESPACE} " | awk '{print $1}'); do
		oc delete operator "$i"
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
	oc get project ${CPFS_CONTROL_NAMESPACE} &>/dev/null
	if [ $? -eq 0 -a $CS_NAMESPACE_COUNT -eq 1 ]; then
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

	webhook_configs=$(oc get ValidatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern2|$pattern3 &>/dev/null")
	if [ $? -eq 0 ]; then
		for webhook in $webhook_configs; do
			oc delete ValidatingWebhookConfiguration "$webhook"
		done
	fi

	webhook_configs=$(oc get MutatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern4|$pattern5|$pattern6 &>/dev/null")
	if [ $? -eq 0 ]; then
		for webhook in $webhook_configs; do
			oc delete MutatingWebhookConfiguration "$webhook"
		done
	fi
	# Cleaning up Role related resources
	oc delete ClusterRoleBinding ibm-common-service-webhook secretshare-ibm-common-services $(oc get ClusterRoleBinding | grep nginx-ingress-clusterrole | awk '{print $1}') --ignore-not-found
	oc delete ClusterRole ibm-common-service-webhook secretshare nginx-ingress-clusterrole --ignore-not-found
	oc delete RoleBinding ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found
	oc delete Role ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found
	oc delete scc nginx-ingress-scc --ignore-not-found

	# Cleaning up apiservice
	oc get apiservice v1beta1.webhook.certmanager.k8s.io 2>/dev/null
	if [ $? -eq 0 ]; then
		INFO "Delete apiservice v1beta1.webhook.certmanager.k8s.io"
		oc delete apiservice v1beta1.webhook.certmanager.k8s.io
	fi
	oc get apiservice v1.metering.ibm.com 2>/dev/null
	if [ $? -eq 0 ]; then
		INFO "Delete apiservice v1.metering.ibm.com"
		oc delete apiservice v1.metering.ibm.com
	fi
fi

# Delete configmaps in kube-public
if [[ "$CP4BA_VERSION" == "21.3."* && "$CS_NAMESPACE_COUNT" -gt 1 ]]; then
	INFO "Remove mapping from ${COMMON_SERVICES_CM_NAMESPACE} namespace"
	# Remove mapping from common-service-maps.yaml and apply it back
	NEW_CS_MAPS=$(${YQ_CMD} d "$CS_MAPS_YAML" "namespaceMapping[${CS_MAP_INDEX}]")
	padded_yaml=$(echo "$NEW_CS_MAPS" | awk '$0="    "$0')
	NEW_CS_MAPS_YAML="$(
		cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: common-service-maps
  namespace: kube-public
data:
  common-service-maps.yaml: |
${padded_yaml}
EOF
)"
	echo "$NEW_CS_MAPS_YAML" | oc apply -f -
else
	INFO "Delete configmaps from ${COMMON_SERVICES_CM_NAMESPACE} namespace"
	oc delete cm common-service-maps ibm-common-services-status -n "${COMMON_SERVICES_CM_NAMESPACE}" --ignore-not-found
fi

# Delete resource in openshift-operator namespace
if [[ $SELECT_ALL == "true" ]]; then
	INFO "Cleaning up openshift-operators namespace"
	oc -n $OPENSHIFT_OPERATORS_NAMESPACE delete operandrequest --force --grace-period=0 --all --ignore-not-found=true --wait=true
	oc delete csv,sub -n $OPENSHIFT_OPERATORS_NAMESPACE --all --ignore-not-found=true --wait=true
	oc -n $OPENSHIFT_OPERATORS_NAMESPACE get cm | grep -E "iaf|ibm|namespace-scope" | awk '{print $1}' | xargs oc delete cm -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true
	oc -n $OPENSHIFT_OPERATORS_NAMESPACE get sa | grep -E "iaf|ibm|postgresql" | awk '{print $1}' | xargs oc delete sa -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true
	oc delete rolebinding iaf-insights-engine-operator-leader-election-rolebinding -n $OPENSHIFT_OPERATORS_NAMESPACE
	oc delete lease,secret,svc,netpol,job,deploy,pvc,role --all -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true
	oc delete commonservice,operandregistry,operandconfig --all -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true --wait=true 
	for i in $(oc -n $OPENSHIFT_OPERATORS_NAMESPACE get operandrequest --no-headers | awk '{print $1}'); do
		oc -n $OPENSHIFT_OPERATORS_NAMESPACE patch operandrequest/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
		oc -n $OPENSHIFT_OPERATORS_NAMESPACE delete operandrequest $i --ignore-not-found=true --wait=true
	done
fi

# Removing CRDs
INFO "Cleaning up CP4BA CRDs"
if [[ $CLEAN_CRDS == "true" ]]; then
	for i in "${CP4BA_CRDS[@]}"; do
		oc patch crd/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
		oc delete crd $i --ignore-not-found=true --grace-period=0 --force
	done
fi

# Switch back to the default namespace
oc project default


if [[ "$SEPARATION_DUTY" == "true" ]]; then
	INFO "Cleaning up all pods before deleting CP4BA operators namespace: ${CP4BA_OPERATORS_NAMESPACE}"
	oc delete pod --all -n "$CP4BA_OPERATORS_NAMESPACE" --grace-period=0 --force

	INFO "Deleting CP4BA Namespace: ${CP4BA_OPERATORS_NAMESPACE}"
	oc delete project "${CP4BA_OPERATORS_NAMESPACE}"

	info "Wait until namespace ${CP4BA_OPERATORS_NAMESPACE} is completely deleted."
	count=0
	while :; do
		oc get project "${CP4BA_OPERATORS_NAMESPACE}" 2>/dev/null
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
				oc get project "${CP4BA_OPERATORS_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done

	INFO "Cleaning up all pods before deleting CP4BA services operators namespace: ${CP4BA_SERVICES_NAMESPACE}"
	oc delete pod --all -n "$CP4BA_SERVICES_NAMESPACE" --grace-period=0 --force

	INFO "Deleting CP4BA Namespace: ${CP4BA_SERVICES_NAMESPACE}"
	oc delete project "${CP4BA_SERVICES_NAMESPACE}"

	info "Wait until namespace ${CP4BA_SERVICES_NAMESPACE} is completely deleted."
	count=0
	while :; do
		oc get project "${CP4BA_SERVICES_NAMESPACE}" 2>/dev/null
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
				oc get project "${CP4BA_SERVICES_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done

else

	INFO "Cleaning up all pods before deleting CP4BA namespace."
	oc delete pod --all -n "$CP4BA_NAMESPACE" --grace-period=0 --force

	INFO "Deleting CP4BA Namespace: ${CP4BA_NAMESPACE}"
	oc delete project "${CP4BA_NAMESPACE}"

	info "Wait until namespace ${CP4BA_NAMESPACE} is completely deleted."
	count=0
	while :; do
		oc get project "${CP4BA_NAMESPACE}" 2>/dev/null
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
				oc get project "${CP4BA_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done
fi

if [[ $CLEAN_CPFS == "true" ]]; then
	INFO "Cleaning up all pods before deleting CPfs namespace."
	oc delete pod --all -n "${CPFS_SHARED_NAMESPACE}" --grace-period=0 --force
	
	INFO "Deleting namespace ${CPFS_SHARED_NAMESPACE}"
	oc delete project "${CPFS_SHARED_NAMESPACE}"

	info "Wait until namespace ${CPFS_SHARED_NAMESPACE} is completely deleted."
	count=0
	while :; do
		oc get project "${CPFS_SHARED_NAMESPACE}" 2>/dev/null
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
				oc get project "${CPFS_SHARED_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done
	oc get project "${CPFS_CONTROL_NAMESPACE}" &>/dev/null
	if [ $? -eq 0 -a $CS_NAMESPACE_COUNT -eq 1 ]; then
		# Delete CPfs Control namespace if namespace exists and if there is only one deployment using CPfs
		INFO "Cleaning up all pods before deleting CPfs control namespace."
		oc delete pod --all -n "${CPFS_CONTROL_NAMESPACE}" --grace-period=0 --force
		INFO "Deleting namespace ${CPFS_CONTROL_NAMESPACE}"
		oc delete project "${CPFS_CONTROL_NAMESPACE}"
		info "Wait until namespace ${CPFS_CONTROL_NAMESPACE} is completely deleted."
		count=0
		while :; do
			oc get project "${CPFS_CONTROL_NAMESPACE}" 2>/dev/null
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
					oc get project "${CPFS_CONTROL_NAMESPACE}" -o yaml
					exit 1
				fi
			fi
		done
	fi
fi

# For cleaning up IBM Cert Manager and IBM Licensing. DEV and QA only. Using -a option.
if [[ $SELECT_ALL == "true" ]]; then
	# IBM Cert Manager
	oc delete sub,csv --all -n ${IBM_CERT_MANAGER_NAMESPACE} --ignore-not-found=true --wait=true
	oc delete deploy,sts,job,svc --all -n ${IBM_CERT_MANAGER_NAMESPACE} --ignore-not-found=true --wait=true
	oc delete certmanagerconfig --all --ignore-not-found=true --wait=true
	oc delete ValidatingWebhookConfiguration cert-manager-webhook
	oc delete MutatingWebhookConfiguration cert-manager-webhook


	# IBM Licensing
	oc delete ibmlicensing --all -n "${IBM_LICENSING_NAMESPACE}" --ignore-not-found=true --wait=true
	oc delete sub,csv --all -n "${IBM_LICENSING_NAMESPACE}" --ignore-not-found=true --wait=true
	oc delete deploy,sts,job,svc --all -n "${IBM_LICENSING_NAMESPACE}" --ignore-not-found=true --wait=true

	INFO "Deleting namespace ${IBM_CERT_MANAGER_NAMESPACE}"
	oc delete project "${IBM_CERT_MANAGER_NAMESPACE}"
	info "Wait until namespace ${IBM_CERT_MANAGER_NAMESPACE} is completely deleted."
	count=0
	while :; do
		oc get project "${IBM_CERT_MANAGER_NAMESPACE}" 2>/dev/null
		if [[ $? -gt 0 ]]; then
			success "Namespace ${IBM_CERT_MANAGER_NAMESPACE} deletion successful"
			break
		else
			((count += 1))
			if ((count <= 36)); then
				wait_msg "Waiting for namespace ${IBM_CERT_MANAGER_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
				sleep 10
			else
				error "Deleting namespace ${IBM_CERT_MANAGER_NAMESPACE} is taking too long and giving up"
				oc get project "${IBM_CERT_MANAGER_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done

	INFO "Deleting namespace ${IBM_LICENSING_NAMESPACE}"
	oc delete project "${IBM_LICENSING_NAMESPACE}"
	info "Wait until namespace ${IBM_LICENSING_NAMESPACE} is completely deleted."
	count=0
	while :; do
		oc get project "${IBM_LICENSING_NAMESPACE}" 2>/dev/null
		if [[ $? -gt 0 ]]; then
			success "Namespace ${IBM_LICENSING_NAMESPACE} deletion successful."
			break
		else
			((count += 1))
			if ((count <= 36)); then
				wait_msg "Waiting for namespace ${IBM_LICENSING_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
				sleep 10
			else
				error "Deleting namespace ${IBM_LICENSING_NAMESPACE} is taking too long and giving up"
				oc get project "${IBM_LICENSING_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done
fi

# Delete common-service-maps.yaml temp file
rm "$CS_MAPS_YAML"

success "Clean up has completed."