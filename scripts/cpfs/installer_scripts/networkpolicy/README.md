# Overview

This folder contains the list of network policies those required for Bedrock Common Services to work in a cluster where the deny_all policy has been implemented. The script **install_networkpolicy.sh** provided to install all the YAML definition of NetworkPolicies for Bedrock Common Services to the specified namespace. If you have the deny-all policy in place, the ingress traffic to all pods in not allowed. In this scenario, for foundational services to work, you need to import and install network policies. If you do not use deny-all policy, you may not need to import or install network policies.

For more details on the usage of the script and to check various supported inputs , refer to the [document section](https://www.ibm.com/docs/en/cpfs?topic=operator-installing-network-policies)

## Sample usage - installing Network Policies

```
networkpolicy % ./install_networkpolicy.sh   
# [0] Checking prerequesites ...
-----------------------------------------------------------------------
[✔] oc command available
[✔] oc command logged in as [redacted]
[✔] IBM Common Services found in namespace ibm-common-services
# [0] Installing Bedrock Network Policies ...
-----------------------------------------------------------------------
ibm-common-services
ibm-common-services
[INFO] Installing bedrock-access-to-auth-idp.yaml ...
networkpolicy.networking.k8s.io/access-to-auth-idp created
[INFO] Installing bedrock-access-to-cert-manager-webhook.yaml ...
networkpolicy.networking.k8s.io/access-to-cert-manager-webhook created
[INFO] Installing bedrock-access-to-ibm-cs-webhook.yaml ...
networkpolicy.networking.k8s.io/access-to-ibm-cs-webhook created
[INFO] Installing bedrock-access-to-meta-api.yaml ...
networkpolicy.networking.k8s.io/access-to-ibm-zen-meta-api created
[INFO] Installing bedrock-acess-to-license-service-reporter.yaml ...
networkpolicy.networking.k8s.io/access-to-ibm-licensing-service-reporter created
[INFO] Installing bedrock-acess-to-license-service.yaml ...
networkpolicy.networking.k8s.io/access-to-ibm-licensing-service-instance created
[INFO] Installing bedrock-acess-to-management-ingress.yaml ...
networkpolicy.networking.k8s.io/access-to-management-ingress created
[INFO] Installing bedrock-allow-webhook-access-from-apiserver.yaml ...
networkpolicy.networking.k8s.io/allow-webhook-access-from-apiserver created
[INFO] Installing zen-access-to-nginx.yaml ...
networkpolicy.networking.k8s.io/access-to-ibm-nginx created
[INFO] Installing zen-access-to-usermgmt.yaml ...
networkpolicy.networking.k8s.io/access-to-usermgmt created
[INFO] Installing zen-access-to-zen-core-api.yaml ...
networkpolicy.networking.k8s.io/access-to-zen-core-api created
[INFO] Installing zen-access-to-zen-core.yaml ...
networkpolicy.networking.k8s.io/access-to-zen-core created
[INFO] Installing zen-allow-iam-config-job.yaml ...
networkpolicy.networking.k8s.io/allow-iam-config-job created
-----------------------------------------------------------------------
[✔] Bedrock NetworkPolicies installation completed at Mon Oct 25 11:13:35 CEST 2021 .

```

## Sample usage - removing Network Policies

```
networkpolicy % ./install_networkpolicy.sh -u
# [0] Checking prerequesites ...
-----------------------------------------------------------------------
[✔] oc command available
[✔] oc command logged in as [redacted]
[✔] IBM Common Services found in namespace ibm-common-services
# [0] Removing Bedrock Network Policies ...
-----------------------------------------------------------------------
networkpolicy.networking.k8s.io "access-to-auth-idp" deleted
networkpolicy.networking.k8s.io "access-to-cert-manager-webhook" deleted
networkpolicy.networking.k8s.io "access-to-ibm-cs-webhook" deleted
networkpolicy.networking.k8s.io "access-to-ibm-licensing-service-instance" deleted
networkpolicy.networking.k8s.io "access-to-ibm-licensing-service-reporter" deleted
networkpolicy.networking.k8s.io "access-to-ibm-nginx" deleted
networkpolicy.networking.k8s.io "access-to-ibm-zen-meta-api" deleted
networkpolicy.networking.k8s.io "access-to-management-ingress" deleted
networkpolicy.networking.k8s.io "access-to-usermgmt" deleted
networkpolicy.networking.k8s.io "access-to-zen-core" deleted
networkpolicy.networking.k8s.io "access-to-zen-core-api" deleted
networkpolicy.networking.k8s.io "allow-iam-config-job" deleted
networkpolicy.networking.k8s.io "allow-webhook-access-from-apiserver" deleted
No resources found
-----------------------------------------------------------------------
[✔] Bedrock NetworkPolicies installation completed at Mon Oct 25 11:15:10 CEST 2021 .
```
