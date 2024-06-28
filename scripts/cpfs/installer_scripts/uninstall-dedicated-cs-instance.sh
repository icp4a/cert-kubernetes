#!/bin/bash
#
# Copyright 2023 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function usage() {
	local script="${0##*/}"

	while read -r ; do echo "${REPLY}" ; done <<-EOF
	Usage: ${script} [OPTION]...
	Uninstall common services
	Options:
	Mandatory arguments to long options are mandatory for short options too.
	  -h, --help                    display this help and exit
	  -n                            specify the namespace where common service is installed
    -cpn                          specify the cloud pak namespace. Can specify multiple cloudpak namespaces with \"cpns1 cpns2\"
	  -f                            force delete specified or default ibm-common-services namespace, skip normal uninstall steps
	EOF
}

function msg() {
  printf '\n%b\n' "$1"
}

function wait_msg() {
  printf '%s\r' "${1}"
}

function success() {
  msg "\33[32m[✔] ${1}\33[0m"
}

function warning() {
  msg "\33[33m[✗] ${1}\33[0m"
}

function error() {
  msg "\33[31m[✘] ${1}\33[0m"
}

function title() {
  msg "\33[1m# [$step] ${1}\33[0m"
  step=$((step + 1))
}

function delete_all(){
  local namespace=$1
  title "Deleting other common service operators, roles, and rolebindings in namespace ${namespace}"
  for cs_op in $cs_op_list; do
    delete_operator "${namespace}" "$cs_op"
    roles=$(${KUBECTL} get roles -n ${namespace} --ignore-not-found | (grep $cs_op || echo fail) | awk '{print $1}')
    if [[ $roles != "fail" ]]; then
      for role in $roles; do
        ${KUBECTL} delete role $role -n ${namespace} --ignore-not-found || error "could not delete role $role in namesapce ${namespace}"
      done
    fi
    rolebindings=$(${KUBECTL} get rolebindings -n ${namespace} --ignore-not-found | (grep $cs_op || echo fail) | awk '{print $1}')
    if [[ $rolebindings != "fail" ]]; then
      for rolebinding in $rolebindings; do
        ${KUBECTL} delete rolebinding $rolebinding -n ${namespace} --ignore-not-found || error "could not delete role $rolebinding in namesapce ${namespace}"
      done
    fi
  done
  #delete automation foundation subs and csvs
  auto_ops=$(${KUBECTL} get subscription.operators.coreos.com -n ${namespace} --ignore-not-found | (grep automation-foundation || echo fail) | awk '{print $1}')
  for af_op in $auto_ops; do
    delete_operator "${namespace}" "$af_op"
  done

  #delete automation foundation roles and rolebindings
  local auto_roles=$(${KUBECTL} get roles -n ${namespace} --ignore-not-found | (grep ibm-automation || echo fail) | awk '{print $1}')
  if [[ "$auto_roles" != "fail" ]]; then
    for role in $auto_roles; do
      ${KUBECTL} delete role $role -n ${namespace} --ignore-not-found || error "could not delete role $role in namesapce ${namespace}"
      ${KUBECTL} delete rolebinding $role -n ${namespace} --ignore-not-found || error "could not delete rolebinding $role in namesapce ${namespace}"
    done
  fi
  local iaf_roles=$(${KUBECTL} get roles -n ${namespace} --ignore-not-found | (grep iaf || echo fail) | awk '{print $1}')
  if [[ "$iaf_roles" != "fail" ]]; then
    for role in $iaf_roles; do
      ${KUBECTL} delete role $role -n ${namespace} --ignore-not-found || error "could not delete role $role in namesapce ${namespace}"
      ${KUBECTL} delete rolebinding $role -n ${namespace} --ignore-not-found || error "could not delete rolebinding $role in namesapce ${namespace}"
    done
  fi
  #delete flink roles
  local flink_roles=$(${KUBECTL} get roles -n ${namespace} --ignore-not-found | (grep flink || echo fail) | awk '{print $1}')
  if [[ "$flink_roles" != "fail" ]]; then
    for role in $flink_roles; do
      ${KUBECTL} delete role $role -n ${namespace} --ignore-not-found || error "could not delete role $role in namesapce ${namespace}"
      ${KUBECTL} delete rolebinding $role -n ${namespace} --ignore-not-found || error "could not delete rolebinding $role in namesapce ${namespace}"
    done
  fi
  #delete automation foundation rolebindings
  local auto_rolebinds=$(${KUBECTL} get rolebindings -n ${namespace} --ignore-not-found | (grep ibm-automation || echo fail) | awk '{print $1}')
  if [[ "$auto_rolebinds" != "fail" ]]; then
    for af_rolebind in $auto_roles; do
      ${KUBECTL} delete rolebinding $af_rolebind -n ${namespace} --ignore-not-found || error "could not delete rolebinding $af_rolebind in namesapce ${namespace}"
    done
  fi
  #delete bts roles
  local bts_roles=$(${KUBECTL} get roles -n ${namespace} --ignore-not-found | (grep ibm-bts || echo fail) | awk '{print $1}')
  if [[ "$bts_roles" != "fail" ]]; then
    for role in $bts_roles; do
      ${KUBECTL} delete role $role -n ${namespace} --ignore-not-found || error "could not delete role $role in namesapce ${namespace}"
    done
  fi
  #delete eventprocessing roles
  local ep_roles=$(${KUBECTL} get roles -n ${namespace} --ignore-not-found | (grep eventprocessing || echo fail) | awk '{print $1}')
  if [[ "$ep_roles" != "fail" ]]; then
    for role in $ep_roles; do
      ${KUBECTL} delete role $role -n ${namespace} --ignore-not-found || error "could not delete role $role in namesapce ${namespace}"
    done
  fi
  title "Deleting deployments in ${namespace}"
  for deploy in $deployments; do
    ${KUBECTL} delete deploy $deploy -n ${namespace} --ignore-not-found
  done
  title "Deleting service accounts in ${namespace}"
  for sa in $serviceaccounts; do
    ${KUBECTL} delete sa $sa -n ${namespace} --ignore-not-found
  done
  title "Deleting statefulsets in ${namespace}"
  for ss in $statefulsets; do
    ${KUBECTL} delete statefulset $ss -n ${namespace} --ignore-not-found
  done
  title "Deleting daemonsets in ${namespace}"
  for ds in $daemonsets; do
    ${KUBECTL} delete ds $ds -n ${namespace} --ignore-not-found
  done
  title "Deleting services in ${namespace}"
  for service in $services; do
    ${KUBECTL} delete service $service -n ${namespace} --ignore-not-found
  done
  title "Deleting routes in ${namespace}"
  for route in $routes; do
    ${KUBECTL} delete route $route -n ${namespace} --ignore-not-found
  done
  #may not be able to delete package manifests
  # title "Deleting package manifests in ${namespace}"
  # for package in $package_manifests; do
  #   ${KUBECTL} delete packagemanifest $package -n ${namespace} --ignore-not-found
  # done
  title "Deleting ingresses in ${namespace}"
  for ingress in $ingresses; do
    ${KUBECTL} delete ingress $ingress -n ${namespace} --ignore-not-found
  done
  title "Deleting configmaps in ${namespace}"
  for cm in $configmaps; do
    ${KUBECTL} delete cm $cm -n ${namespace} --ignore-not-found
  done
  # delete zen cms
  zen_cms=$(${KUBECTL} get cm -n ${namespace} --ignore-not-found | (grep zen || echo fail) | awk '{print $1}')
  if [[ $zen_cms != "fail" ]]; then
    for cm in $zen_cms; do
      ${KUBECTL} delete cm $cm -n ${namespace} --ignore-not-found
    done
  fi
  #delete automation foundation cms
  autofound_cms=$(${KUBECTL} get cm -n ${namespace} --ignore-not-found | (grep automation.ibm.com || echo fail) | awk '{print $1}')
  if [[ $autofound_cms != "fail" ]]; then
    for cm in $autofound_cms; do
      ${KUBECTL} delete cm $cm -n ${namespace} --ignore-not-found
    done
  fi
  iaf_cms=$(${KUBECTL} get cm -n ${namespace} --ignore-not-found | (grep iaf || echo fail) | awk '{print $1}')
  if [[ $iaf_cms != "fail" ]]; then
    for cm in $iaf_cms; do
      ${KUBECTL} delete cm $cm -n ${namespace} --ignore-not-found
    done
  fi
  #delete bts cms
  bts_cms=$(${KUBECTL} get cm -n ${namespace} --ignore-not-found | (grep ibm-bts || echo fail) | awk '{print $1}')
  if [[ $bts_cms != "fail" ]]; then
    for cm in $bts_cms; do
      ${KUBECTL} delete cm $cm -n ${namespace} --ignore-not-found
    done
  fi
  title "Deleting jobs in ${namespace}"
  for job in $jobs; do
    ${KUBECTL} delete job $job -n ${namespace} --ignore-not-found
  done
  zen_jobs=$(${KUBECTL} get job -n ${namespace} --ignore-not-found | (grep zen || echo fail))
  if [[ $zen_jobs != "fail" ]]; then
    msg "zen jobs list: $zen_jobs"
    for job in $zen_jobs; do
      ${KUBECTL} delete job $job -n ${namespace} --ignore-not-found
    done
  fi
  title "Deleting custom resources in ${namespace}"
  #delete CRDs and CRs
  for custom_resource in $custom_resources; do
    cr_check=$(${KUBECTL} get $custom_resource -n ${namespace} --ignore-not-found || echo fail)
    if [[ $cr_check != "fail" ]]; then
      resources=$(${KUBECTL} get $custom_resource -n ${namespace} --ignore-not-found | awk '{print $1}' | awk 'NR!=1 {print}')
      delete_operand_finalizer "${namespace}" "$custom_resource"
      for resource in $resources; do
        ${KUBECTL} delete ${custom_resource} ${resource} -n ${namespace} --ignore-not-found
      done
    fi
  done
  title "Deleting secrets in ${namespace}"
  #delete secrets
  for group in $secrets; do
    secret_check=$(${KUBECTL} get secrets -n ${namespace} --ignore-not-found | (grep ${group} || echo fail))
    if [[ $secret_check != "fail" ]]; then
      secrets_to_remove=$(${KUBECTL} get secrets -n ${namespace} --ignore-not-found | grep ${group} | awk '{print $1}')
      for secret in $secrets_to_remove; do
        ${KUBECTL} delete secret -n ${namespace} ${secret} --ignore-not-found
      done
    fi
  done
  title "Deleting mongodb pvc in ${namespace}"
  pvcs=$(${KUBECTL} get pvc --ignore-not-found -n ${namespace} | (grep mongodbdir-icp-mongodb || echo fail) | awk '{print $1}')
  for pvc in $pvcs; do
    ${KUBECTL} patch pvc ${pvc} -n ${namespace} --type=merge -p '{"spec": {"finalizers":null}}' --ignore-not-found
    ${KUBECTL} delete pvc ${pvc} -n ${namespace} --ignore-not-found
  done
}

# Sometime delete namespace stuck due to some resources remaining, use this method to get these
# remaining resources to force delete them.
function get_remaining_resources_from_namespace() {
  local namespace=$1
  local remaining=
  if ${KUBECTL} get namespace ${namespace} &>/dev/null; then
    #the following 'message' line does not output anything unless the namespace is in terminating state...
    #so this function runs before the namespace is deleted so it will always run into the problem where the first time this is run, the script will hang up on deleting the target namespace but the second time it will work immediately
    message=$(${KUBECTL} get namespace ${namespace} -o=jsonpath='{.status.conditions[?(@.type=="NamespaceContentRemaining")].message}' | awk -F': ' '{print $2}') 
    [[ "X$message" == "X" ]] && return 0
    remaining=$(echo $message | awk '{len=split($0, a, ", ");for(i=1;i<=len;i++)print a[i]" "}' | while read res; do
      [[ "$res" =~ "pod" ]] && continue
      echo ${res} | awk '{print $1}'
    done)
  fi
  echo $remaining
}

function wait_for_namespace_deleted() {
  local namespace=$1
  retries=30
  interval=5
  index=0
  while true; do
    nsExist=$(${KUBECTL} get namespace ${namespace} || echo "fail")
    if [[ $nsExist != "fail" ]]; then
      if [[ ${index} -eq ${retries} ]]; then
        error "Timeout delete namespace: $namespace"
        return 1
      fi
      sleep $interval
      ((index++))
      wait_msg "DELETE - Waiting: namespace "${namespace}" delete complete [$(($retries - $index)) retries left]"
    else
      break
    fi
  done
  return 0
}
function delete_operator() {
  local subs=$2 
  local namespace=$1 
  for sub in ${subs}; do
    csv=$(${KUBECTL} get subscription.operators.coreos.com ${sub} -n ${namespace} -o=jsonpath='{.status.installedCSV}' --ignore-not-found)
    if [[ "X${csv}" != "X" ]]; then
      msg "Delete operator ${sub} from namespace ${namespace}"
      ${KUBECTL} delete csv ${csv} -n ${namespace} --ignore-not-found
      ${KUBECTL} delete sub ${sub} -n ${namespace} --ignore-not-found
    fi
  done
}
function delete_operand() { 
  local crds=$2  
  local namespace=$1 
  for crd in ${crds}; do
    if ${KUBECTL} api-resources | grep $crd &>/dev/null; then
      crs=$(${KUBECTL} get ${crd} --no-headers --ignore-not-found -n ${namespace} 2>/dev/null | awk '{print $1}')
      if [[ "X${crs}" != "X" ]]; then
        msg "Deleting ${crd} from namespace ${namespace}"
        ${KUBECTL} delete ${crd} --all -n ${namespace} --ignore-not-found &
      fi
    fi
  done
}
function delete_operand_finalizer() {
  local crds=$2 
  local ns=$1 
  for crd in ${crds}; do
    crs=$(${KUBECTL} get ${crd} --no-headers --ignore-not-found -n ${ns} 2>/dev/null | awk '{print $1}')
    for cr in ${crs}; do
      msg "Removing the finalizers for resource: ${crd}/${cr}"
      ${KUBECTL} patch ${crd} ${cr} -n ${ns} --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]' 2>/dev/null
    done
  done
}

function cleanup_cluster() {
  title "Deleting webhooks"
  ${KUBECTL} delete MutatingWebhookConfiguration namespace-admission-config-${COMMON_SERVICES_NS} --ignore-not-found
  if [[ "$REMOVE_IAM_CP_NS" == "true" ]]; then
    for ns in ${cloudpak_ns}; do
      ${KUBECTL} delete MutatingWebhookConfiguration namespace-admission-config-${ns} --ignore-not-found
    done
  fi
}
function force_delete() {
  local namespace=$1
  local remaining=$(get_remaining_resources_from_namespace "$namespace")
  if [[ "X$remaining" != "X" ]]; then
    warning "Some resources are remaining: $remaining"
    msg "Deleting finalizer for these resources ..."
    delete_operand_finalizer "${namespace}" "${remaining}" 
  fi
}
function delete_iamcr_cloudpak_ns() {
	local crds=$2
	local namespace=$1
	for crd in ${crds}; do
		crs=$(${KUBECTL} get ${crd} --no-headers --ignore-not-found -n ${namespace} 2>/dev/null | awk '{print $1}')
		for cr in ${crs}; do
			msg "Removing the resource: ${crd}/${cr}"
			${KUBECTL} delete ${crd}  $cr -n ${namespace} --ignore-not-found &
		done
	done
}
function force_delete_iamcr_cloudpak_ns() {
	local crds=$2
	local namespace=$1
	# add finializers to resource
	for crd in ${crds}; do
    		crs=$(${KUBECTL} get ${crd} --no-headers --ignore-not-found -n ${namespace} 2>/dev/null | awk '{print $1}')
    		for cr in ${crs}; do
			msg "Removing the finalizers for resource: ${crd}/${cr}"
			${KUBECTL} patch ${crd} ${cr} -n ${namespace} --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]' 2>/dev/null
		done
	done
}

#-------------------------------------- Clean UP --------------------------------------#
#Resource Lists

#also used for roles and rolebindings
cs_op_list="nss operand-deployment-lifecycle-manager cloud-native-postgresql ibm-auditlogging-operator ibm-bts-operator ibm-commonui-operator ibm-events-operator ibm-healthcheck-operator ibm-iam-operator ibm-ingress-nginx-operator ibm-management-ingress-operator ibm-mongodb-operator ibm-monitoring-grafana-operator ibm-platform-api-operator ibm-platform-api-operand ibm-zen-operator zen-cpp-operator"  
deployments="auth-idp auth-pap auth-pdp common-web-ui default-http-backend iam-policy-controller ibm-commonui-operator ibm-content-operator ibm-iam-operator ibm-ingress-nginx-operator ibm-management-ingress-operator ibm-mongodb-operator ibm-nginx ibm-nginx-tester ibm-monitoring-grafana ibm-platform-api-operator ibm-zen-operator audit-policy-controller icp-memcached management-ingress nginx-ingress-controller oidcclient-watcher platform-api secret-watcher secretshare system-healthcheck-service meta-api-deploy usermgmt zen-audit zen-core zen-core-api zen-watcher"
serviceaccounts="ibm-auditlogging-operand ibm-common-service-operator ibm-commonui-operator ibm-common-service-webhook ibm-events-operator ibm-iam-operand-restricted ibm-iam-operand ibm-iam-operator ibm-ingress-nginx-operator ibm-management-ingress-operator ibm-mongodb-operand ibm-mongodb-operator ibm-platform-api-operand ibm-platform-api-operator ibm-zen-operator-serviceaccount management-ingress nginx-ingress operand-deployment-lifecycle-manager secretshare zen-admin-sa zen-editor-sa zen-norbac-sa zen-runtime-sa zen-viewer-sa"
statefulsets="icp-mongodb must-gather-service zen-metastoredb"
daemonsets="audit-logging-fluentd-ds"
services="common-audit-logging common-web-ui default-http-backend iam-pap iam-pdp iam-token-service ibm-monitoring-grafana ibm-nginx-svc ibm-nginx-tester-svc icp-management-ingress icp-mongodb internal-nginx-svc memcached meta-api-svc mongodb must-gather-service nginx-ingress-controller platform-api platform-auth-service platform-identity-management platform-identity-provider system-healthcheck-service usermgmt-svc zen-audit-svc zen-core-api-svc zen-core-svc zen-metastoredb zen-metastoredb-public"
routes="cp-console cp-proxy"
#grep then delete crds and crs
custom_resources="authentications.operator.ibm.com clients.oidc.security.ibm.com commonservices.operator.ibm.com commonwebuis.operators.ibm.com iampolicies.iam.policies.ibm.com kafkabridges.ibmevents.ibm.com kafkaclaims.shim.bedrock.ibm.com kafkacomposites.shim.bedrock.ibm.com kafkaconnectors.ibmevents.ibm.com kafkaconnects.ibmevents.ibm.com kafkamirrormaker2s.ibmevents.ibm.com kafkamirrormakers.ibmevents.ibm.com kafkarebalances.ibmevents.ibm.com kafkas.ibmevents.ibm.com kafkatopics.ibmevents.ibm.com kafkausers.ibmevents.ibm.com managementingresses.operator.ibm.com mongodbs.operator.ibm.com namespacescopes.operator.ibm.com nginxingresses.operator.ibm.com oidcclientwatchers.operator.ibm.com operandbindinfos.operator.ibm.com platformapis.operator.ibm.com policycontrollers.operator.ibm.com policydecisions.operator.ibm.com secretwatchers.operator.ibm.com securityonboardings.operator.ibm.com strimzipodsets.core.ibmevents.ibm.com zenservices.zen.cpd.ibm.com zenextensions.zen.cpd.ibm.com"
#grep then delete secrets
secrets="admin-user-details auth-pdp-secret common-web-ui-cert ibm-common-service-operator ibm-common-service-webhook ibm-commonui-operator ibm-events-operator ibm-iam ibm-ingress-nginx-operator ibm-licensing-bindinfo-ibm-licensing ibm-management-ingress-operator ibm-mongodb ibm-namespace-scope-operator ibm-nginx-internal-tls-ca ibm-platform-api ibm-zen-operator-serviceaccount ibmcloud-cluster-ca-cert icp-management-ingress-tls-secret icp-mongodb identity-provider-secret internal-nginx-svc-tls internal-tls management-ingress mongodb-root-ca-cert nginx-ingress oauth-client-secret operand-deployment-lifecycle-manager platform-api platform-auth platform-identity-management platform-oidc-credentials route-tls-secret secretshare zen"
package_manifests="ibm-crossplane-provider-kubernetes-operator-app ibm-healthcheck-operator-app ibm-odlm ibm-zen-operator ibm-metering-operator-app ibm-monitoring-grafana-operator-app ibm-monitoring-grafana-operator-app ibm-auditlogging-operator-app ibm-monitoring-exporters-operator-app ibm-iam-policy-operator-app ibm-mongodb-operator-app ibm-monitoring-prometheusext-operator-app ibm-platform-api-operator-app ibm-ingress-nginx-operator-app operand-deployment-lifecycle-manager-app ibm-namespace-scope-operator ibm-events-operator ibm-namespace-scope-operator-restricted ibm-iam-operator ibm-licensing-operator-app ibm-licensing-operator-app zen-cpp-operator ibm-commonui-operator-app ibm-crossplane-provider-ibm-cloud-operator-app ibm-common-service-operator ibm-crossplane-operator-app ibm-management-ingress-operator-app"
ingresses="common-web-ui common-web-ui-api common-web-ui-callback iam-pap iam-pdp iam-token iam-token-redirect ibmid-ui-callback id-mgmt idmgmt-v2-api platform-api platform-auth platform-auth-dir platform-id-auth platform-id-auth-block platform-id-provider platform-login platform-oidc platform-oidc-block platform-oidc-introspect platform-oidc-keys platform-oidc-token platform-oidc-token-2 saml-ui-callback version-idmgmt"
#grep then delete only for zen
configmaps="ibm-cpp-config ibm-iam-bindinfo-oauth-client-map ibm-iam-bindinfo-platform-auth-idp management-ingress-ibmcloud-cluster-info auth-pap auth-pdp cf-crossplane common-web-ui-config common-web-ui-log4js common-web-ui-zen-card-extensions common-web-ui-zen-quicknav-extensions ibm-iam-operator-lock ibm-licensing-bindinfo-ibm-licensing-info ibm-licensing-bindinfo-ibm-licensing-upload-config ibm-platform-api-operator icp-mongodb icp-mongodb-init icp-mongodb-install icp-oidcclient-watcher-lock ingress-controller-leader-ibm-icp-management ingress-controller-leader-nginx management-ingress-config management-ingress-info monitoring-json namespace-scope nginx-ingress-controller oauth-client-map odlm-scope platform-api platform-auth-idp platform-permission-extensions platform-user-role-extensions postgresql-operator-default-monitoring"
#grep then delete but only for zen
jobs="create-secrets-job iam-config-job iam-onboarding oidc-client-registration pre-zen-operand-config-job security-onboarding setup-job setup-nginx-job"

COMMON_SERVICES_NS=
KUBECTL=$(command -v kubectl 2>/dev/null)
[[ "X$KUBECTL" == "X" ]] && error "kubectl: command not found" && exit 1
step=0
FORCE_DELETE=false
REMOVE_IAM_CP_NS=false
while [ "$#" -gt "0" ]
do
	case "$1" in
	"-h"|"--help")
		usage
		exit 0
		;;
	"-f")
		FORCE_DELETE=true
		;;
	"-n")
		COMMON_SERVICES_NS=$2
		shift
		;;
	"-cpn")
		cloudpak_ns=$2
		REMOVE_IAM_CP_NS=true
		shift
		;;
	*)
		warning "invalid option -- \`$1\`"
		usage
		exit 1
		;;
	esac
	shift
done
if [[ "$COMMON_SERVICES_NS" == "" ]]; then
  error "Common service namespace flag \"-n\" was not set. Please re-run script with \"-n\" option. Re-run script with \"-h\" or \"--help\" option for more info"
  exit 1
fi
#not sure if we need to make sure they set the cpn flag yet
# if [[ "$cloudpak_ns" == "" ]]; then
#   error "CloudPak/requested from namespace flag \"-cpn\" was not set. Please re-run script with \"-cpn\" option. Re-run script with \"-h\" or \"--help\" option for more info"
#   exit 1
# fi
#check if cs namespace exists (for example on a second or third run)
csnsExist=$(${KUBECTL} get namespaces | (grep  ${COMMON_SERVICES_NS} || echo "fail") | awk '{print $1}')
if [[ "$csnsExist" == "fail" ]]; then
  msg "Creating dummy CS namespace for script to run in namespace ${COMMON_SERVICES_NS}"
  ${KUBECTL} create namespace ${COMMON_SERVICES_NS} || error "Failed to create namespace ${COMMON_SERVICES_NS}" && exit 1
fi

msg "Removing common services from namespaces: ${COMMON_SERVICES_NS} ${cloudpak_ns}"
if [[ "$FORCE_DELETE" == "true" ]]; then
  msg "-f parameter selected, namespace ${COMMON_SERVICES_NS} will be deleted"
fi

if [[ "$FORCE_DELETE" == "false" ]]; then
  title "Deleting ibm-common-service-operator in namespace ${COMMON_SERVICES_NS}"
  for sub in $(${KUBECTL} get subscription.operators.coreos.com --all-namespaces --ignore-not-found | grep ${COMMON_SERVICES_NS} | awk '{if ($3 =="ibm-common-service-operator") print $1"/"$2}'); do
    namespace=$(echo $sub | awk -F'/' '{print $1}')
    name=$(echo $sub | awk -F'/' '{print $2}')
    delete_operator "${COMMON_SERVICES_NS}" "$name" 
  done
  title "Deleting ODLM in namespace ${COMMON_SERVICES_NS}"
  for sub in $(${KUBECTL} get subscription.operators.coreos.com --all-namespaces --ignore-not-found | grep ${COMMON_SERVICES_NS} | awk '{if ($3 =="ibm-odlm") print $1"/"$2}'); do
    namespace=$(echo $sub | awk -F'/' '{print $1}')
    name=$(echo $sub | awk -F'/' '{print $2}')
    delete_operator "${COMMON_SERVICES_NS}" "$name" 
  done
  title "Deleting ibm-namespace-scope-operator in namespace ${COMMON_SERVICES_NS}"
  for sub in $(${KUBECTL} get subscription.operators.coreos.com --all-namespaces --ignore-not-found | grep ${COMMON_SERVICES_NS} | awk '{if ($3 =="ibm-namespace-scope-operator") print $1"/"$2}'); do
    namespace=$(echo $sub | awk -F'/' '{print $1}')
    name=$(echo $sub | awk -F'/' '{print $2}')
    delete_operator "${COMMON_SERVICES_NS}" "$name" 
  done

  #the meat and potatoes of resource deletion
  delete_all "${COMMON_SERVICES_NS}"
  
  delete_iamcr_cloudpak_ns "${COMMON_SERVICES_NS}" "client"
  delete_operand_finalizer "${COMMON_SERVICES_NS}" "NamespaceScope"
  delete_operand "${COMMON_SERVICES_NS}" "NamespaceScope"
  ${KUBECTL} delete pods --all -n ${COMMON_SERVICES_NS} #clear old pods
fi

#remove from cp namespace as well
if [[ "$REMOVE_IAM_CP_NS" == "true" ]]; then
  for ns in $cloudpak_ns; do
    title "Deleting ibm-common-service-operator in namespace ${ns}"
    for sub in $(${KUBECTL} get subscription.operators.coreos.com --all-namespaces --ignore-not-found | grep ${ns} | awk '{if ($3 =="ibm-common-service-operator") print $1"/"$2}'); do
        namespace=$(echo $sub | awk -F'/' '{print $1}')
        name=$(echo $sub | awk -F'/' '{print $2}')
        delete_operator "${ns}" "$name" 
    done
    title "Deleting ibm-namespace-scope-operator in namespace ${ns}"
    for sub in $(${KUBECTL} get subscription.operators.coreos.com --all-namespaces --ignore-not-found | grep ${ns} | awk '{if ($3 =="ibm-namespace-scope-operator") print $1"/"$2}'); do
      namespace=$(echo $sub | awk -F'/' '{print $1}')
      name=$(echo $sub | awk -F'/' '{print $2}')
      delete_operator "${ns}" "$name" 
    done

    #the meat and potatoes of resource deletion
    delete_all "${ns}"

    delete_iamcr_cloudpak_ns ${ns} "client"
    delete_operand_finalizer "${ns}" "NamespaceScope"
    delete_operand "${ns}" "NamespaceScope"
    ${KUBECTL} delete pods --all -n ${ns} #clear old pods
  done
fi

cleanup_cluster

if [[ "$FORCE_DELETE" == "true" ]]; then
  title "Deleting common services operand from $COMMON_SERVICES_NS namespaces"
  delete_operand_finalizer "${COMMON_SERVICES_NS}" "OperandRequest"
  delete_operand "${COMMON_SERVICES_NS}" "OperandRequest"
  delete_operand_finalizer "${COMMON_SERVICES_NS}" "CommonService OperandRegistry OperandConfig"
  delete_operand "${COMMON_SERVICES_NS}" "CommonService OperandRegistry OperandConfig" 
  delete_operand_finalizer "${COMMON_SERVICES_NS}" "NamespaceScope"
  delete_operand "${COMMON_SERVICES_NS}" "NamespaceScope" 
  
  title "Deleting iam crs in ${COMMON_SERVICES_NS} namespace"
  force_delete_iamcr_cloudpak_ns ${COMMON_SERVICES_NS} "client rolebinding"
  
  title "Deleting custom resources in ${COMMON_SERVICES_NS} namespace"
  for custom_resource in $custom_resources; do
    cr_check=$(${KUBECTL} get $custom_resource -n ${COMMON_SERVICES_NS} --ignore-not-found || echo fail)
    if [[ $cr_check != "fail" ]]; then
      delete_operand_finalizer "${COMMON_SERVICES_NS}" "$custom_resource"
      resources=$(${KUBECTL} get $custom_resource -n ${COMMON_SERVICES_NS} --ignore-not-found | awk '{print $1}' | awk 'NR!=1 {print}')
      for resource in $resources; do
        msg "resource: ${resource}  resources: ${resources} cr: $custom_resource"
        ${KUBECTL} delete ${custom_resource} ${resource} -n ${COMMON_SERVICES_NS} --ignore-not-found
      done
    fi
  done
  title "Deleting namespace ${COMMON_SERVICES_NS}"
  ${KUBECTL} patch namespace ${COMMON_SERVICES_NS} --type=merge -p '{"spec": {"finalizers":null}}'
  ${KUBECTL} delete namespace ${COMMON_SERVICES_NS} --ignore-not-found 
  title "Force delete remaining resources"
  force_delete "$COMMON_SERVICES_NS" 
  wait $NS
  if wait_for_namespace_deleted ${COMMON_SERVICES_NS}; then
    success "Common Services uninstall successfull from namespace ${COMMON_SERVICES_NS}."
    exit 0
  fi
else
  msg "Cloud Pak and Common Services share namespace so it will not be deleted."
  success "Common Services uninstall successfull from namespace ${COMMON_SERVICES_NS}."
  exit 0
fi
error "Something's wrong, check namespace details:" 
${KUBECTL} get namespace ${COMMON_SERVICES_NS} -oyaml --ignore-not-found
exit 1