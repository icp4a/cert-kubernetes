#!/bin/bash
configMapCustomHostname="cs-onprem-tenant-config"
csNamespace=$operator_namespace
map_to_common_service_namespace=$operand_namespace
custom_hostname=""
wlp_client_id=$(oc get secret -n $map_to_common_service_namespace platform-oidc-credentials -o jsonpath='{.data.WLP_CLIENT_ID}'|base64 -d)
wlp_client_secret=$(oc get secret -n $map_to_common_service_namespace platform-oidc-credentials -o jsonpath='{.data.WLP_CLIENT_SECRET}'|base64 -d)
oauth2_client_registration_secret=$(oc get secret -n $map_to_common_service_namespace platform-oidc-credentials -o jsonpath='{.data.OAUTH2_CLIENT_REGISTRATION_SECRET}'|base64 -d)
admin_password=$(oc get secret -n $map_to_common_service_namespace platform-auth-idp-credentials  -ojsonpath='{.data.admin_password}'|base64 -d)
admin_username=$(oc get secret -n $map_to_common_service_namespace platform-auth-idp-credentials  -ojsonpath='{.data.admin_username}'|base64 -d)

if [[ -z "$csNamespace" || -z "$map_to_common_service_namespace" ]]; then
  echo "Error: One or both required environment variables are not set."
  echo " Operator Namespace: '$csNamespace'"
  echo " Operand Namespace: '$map_to_common_service_namespace'"
  exit 1
fi

echo "Given operator namespace : $csNamespace"
echo "Given operand namespace : $map_to_common_service_namespace"

checkIfConfigMapExist(){
  count=$(oc get cm -n $map_to_common_service_namespace |grep $configMapCustomHostname |wc -l)
  if [[ "$count" -ne 1 ]]; then
  echo "$configMapCustomHostname not found"
  exit 1
  fi
  #checkIfNamespaceExist
  checkIfhostReachable
}

checkIfSecretExist(){
  count=$(oc get configmap -n $map_to_common_service_namespace cs-onprem-tenant-config -o jsonpath='{.data.custom_host_certificate_secret}' |wc -w)
  if [[ "$count" -eq 1 ]]; then
    checkCrtFilesExist
    echo "Deleting old custom-tls-secret if exists"
    oc delete secret $(oc get configmap -n $map_to_common_service_namespace cs-onprem-tenant-config -o jsonpath='{.data.custom_host_certificate_secret}') -n $map_to_common_service_namespace --ignore-not-found
    custom_secret=$(oc get configmap -n $map_to_common_service_namespace cs-onprem-tenant-config -o jsonpath='{.data.custom_host_certificate_secret}')
    echo "Creating custom-tls-secret"
    oc create secret generic $custom_secret -n $map_to_common_service_namespace --from-file=ca.crt=./ca.crt --from-file=tls.crt=./tls.crt --from-file=tls.key=./tls.key
  else
    echo "Custom secret not configured"
  fi
}

checkIfNamespaceExist(){
  csNamespace=$(oc get configmap -n $map_to_common_service_namespace cs-onprem-tenant-config -o jsonpath='{.metadata.namespace}')
  count=$(oc get namespaces |grep $csNamespace |wc -l)
  if [[ "$count" -ne 1 ]]; then
  echo "$csNamespace not found"
  exit 1
  fi
}

checkIfhostReachable() {
  custom_hostname=$(oc get configmap -n $map_to_common_service_namespace cs-onprem-tenant-config -o jsonpath='{.data.custom_hostname}')
  if [ -n "$custom_hostname" ]; then
      echo "Given Custom Hostname: $custom_hostname"
      if host "$custom_hostname" >/dev/null 2>&1; then
        echo "Host is reachable. Proceeding further..."
      else
        echo "$custom_hostname is not reachable. Exiting the script."
        exit 1
      fi
  fi
}

checkCrtFilesExist() {
  echo "Custom Secret is configured in configmap, so checking for crt availability"
  if [[ ! -f "tls.key" ]]; then
     echo "tls.key is not present in current directory, pls keep tls.key, tls.crt and ca.crt files in current directory"
     exit 1
  fi
  if [[ ! -f "tls.crt" ]]; then
     echo "tls.crt is not present in current directory,  pls keep tls.key, tls.crt and ca.crt files in current directory"
     exit 1
  fi
  if [[ ! -f "ca.crt" ]]; then
     echo "ca.crt is not present is not present in current directory,  pls keep tls.key, tls.crt and ca.crt files in current directory"
     exit 1
  fi

}

checkIfConfigMapExist
checkIfSecretExist

# delete completed job if exists
echo "Deleting old job of iam-custom-hostname if exists"
oc delete job iam-custom-hostname --ignore-not-found -n $csNamespace

echo "Running custom hostname job"
tmpfile=$(mktemp)
cat <<EOF > "$tmpfile"
apiVersion: batch/v1
kind: Job
metadata:
  name: iam-custom-hostname
  namespace: $csNamespace
  labels:
    app: iam-custom-hostname
spec:
  template:
    metadata:
      labels:
        app: iam-custom-hostname
    spec:
      containers:
      - name: iam-custom-hostname
        image: icr.io/cpopen/cpfs/iam-custom-hostname:latest
        command: ["python3", "/scripts/saas_script.py"]
        imagePullPolicy: Always
        env:
          - name: OPENSHIFT_URL
            value: https://kubernetes.default:443
          - name: IDENTITY_PROVIDER_URL
            value: https://platform-identity-provider.$map_to_common_service_namespace.svc:4300
          - name: PLATFORM_AUTH_URL
            value: https://platform-auth-service.$map_to_common_service_namespace.svc:9443
          - name: POD_NAMESPACE
            value: $map_to_common_service_namespace
          - name: WLP_CLIENT_ID
            value: $wlp_client_id
          - name: WLP_CLIENT_SECRET
            value: $wlp_client_secret
          - name: OAUTH2_CLIENT_REGISTRATION_SECRET
            value: $oauth2_client_registration_secret
          - name: DEFAULT_ADMIN_USER
            value: $admin_username
          - name: DEFAULT_ADMIN_PASSWORD
            value: $admin_password
      serviceAccountName: ibm-iam-operator
      restartPolicy: OnFailure
EOF
oc apply -f "$tmpfile"
rm "$tmpfile"

# Function to check if the job has completed
check_job_completion() {
  oc wait job iam-custom-hostname --for condition=complete --timeout=120s
}

# Call the function to check job completion
check_job_completion iam-custom-hostname $csNamespace

deployment_name="platform-auth-service"
timeout_seconds=180  # assuming auth-service will come in 3 mins after restart

start_time=$(date +%s)
end_time=$((start_time + timeout_seconds))

while true; do
  status=$(oc get deployment "$deployment_name" -n $map_to_common_service_namespace  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
  
  echo "Triggered restart of platform-auth-service pod"
  oc delete pod -l app=platform-auth-service -n "$map_to_common_service_namespace"
  pod_phase=$(oc get pod -l app=platform-auth-service -n "$map_to_common_service_namespace" -o jsonpath='{.items[0].status.phase}' 2>/dev/null)

  if [[ "$status" == "True" &&  "$pod_phase" == "Running" ]]; then
    echo "$deployment_name deployment is available and pod is running"
    break
  fi

  current_time=$(date +%s)
  if [[ "$current_time" -gt "$end_time" ]]; then
    echo "Timeout exceeded. $deployment_name is not available within the specified time."
    exit 1
  fi

  sleep 5  # Wait for 5 seconds before checking again
done

#sleep for 10s and compare existing custom_hostname with the current route
sleep 15

username=$(oc get secret platform-auth-idp-credentials -n ibm-common-services -o json | jq -r .data.admin_username| base64 -d)
password=$(oc get secret platform-auth-idp-credentials -n ibm-common-services -o json | jq -r .data.admin_password | base64 -d)
route=$(oc get routes cp-console -o jsonpath='{.spec.host}')


curl --silent -k -X POST -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8"  -d "grant_type=password&username=$username&password=$password&scope=openid" https://$route/idprovider/v1/auth/identitytoken > token_output
if [ -f "token_output" ]; then
  if grep -l '"access_token":"[^"]\+' token_output ; then
      echo "Access token is present."
      echo "Route changes validated successfully"
  fi 
  rm -f token_output
else
    echo "token_output does not exist."
fi

new_hostname=$(oc get routes cp-console --no-headers | awk '{print $2}')

if [ "$new_hostname" = "$custom_hostname" ]; then
    echo "successfully updated the custom hostname"
else
    echo "update custom hostname failed "
fi
