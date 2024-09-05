# Overview

This folder contains the list of network policies those required for Bedrock Common Services to work in a cluster where the deny_all policy has been implemented. The script **install_networkpolicy.sh** provided to install all the YAML definition of NetworkPolicies for Bedrock Common Services to the specified namespace. If you have the deny-all policy in place, the ingress traffic to all pods in not allowed. In this scenario, for foundational services to work, you need to import and install network policies. If you do not use deny-all policy, you may not need to import or install network policies.

For more details on the usage of the script and to check various supported inputs , refer to the [document section](https://www.ibm.com/docs/en/cpfs?topic=operator-installing-network-policies)

## Sample usage - installing Network Policies

```
networkpolicy % ./install_networkpolicy.sh -n services-namespace -o operators-namespace
# [0] Checking prerequisites ...
-----------------------------------------------------------------------
[✔] oc command available
[✔] oc command logged in as user
[✔] IBM Common Services found in namespace operators-namespace
# [0] Installing IBM Common Services Network Policies ...
-----------------------------------------------------------------------
[INFO] Using IBM Common Services namespace: services-namespace
[INFO] Using operators namespace: operators-namespace
[INFO] Installing access-to-common-web-ui.yaml ...
networkpolicy.networking.k8s.io/access-to-common-web-ui created
[INFO] Installing access-to-edb-postgres.yaml ...
networkpolicy.networking.k8s.io/access-to-edb-postgres created
[INFO] Installing access-to-icp-mongodb.yaml ...
networkpolicy.networking.k8s.io/access-to-icp-mongodb created
[INFO] Installing access-to-platform-auth-service.yaml ...
networkpolicy.networking.k8s.io/access-to-platform-auth-service created
[INFO] Installing access-to-platform-identity-management.yaml ...
networkpolicy.networking.k8s.io/access-to-platform-identity-management created
[INFO] Installing access-to-platform-identity-provider.yaml ...
networkpolicy.networking.k8s.io/access-to-platform-identity-provider created
[INFO] Installing access-to-zen-stopgap.yaml ...
networkpolicy.networking.k8s.io/access-to-zen-stopgap created
[INFO] Installing access-to-edb-postgres-webhooks.yaml ...
networkpolicy.networking.k8s.io/access-to-edb-postgres-webhooks created
[INFO] Installing access-to-ibm-common-service-operator.yaml ...
networkpolicy.networking.k8s.io/access-to-ibm-common-service-operator created
[INFO] Installing access-to-zen-meta-api.yaml ...
networkpolicy.networking.k8s.io/access-to-zen-meta-api created
[INFO] Installing allow-webhook-access-from-apiserver.yaml ...
networkpolicy.networking.k8s.io/allow-webhook-access-from-apiserver created
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
networkpolicy.networking.k8s.io "access-to-common-web-ui" deleted
networkpolicy.networking.k8s.io "access-to-edb-postgres" deleted
networkpolicy.networking.k8s.io "access-to-icp-mongodb" deleted
networkpolicy.networking.k8s.io "access-to-platform-auth-service" deleted
networkpolicy.networking.k8s.io "access-to-platform-identity-management" deleted
networkpolicy.networking.k8s.io "access-to-platform-identity-provider" deleted
networkpolicy.networking.k8s.io "access-to-zen-stopgap" deleted
networkpolicy.networking.k8s.io "access-to-edb-postgres-webhooks" deleted
networkpolicy.networking.k8s.io "access-to-ibm-common-service-operator" deleted
networkpolicy.networking.k8s.io "access-to-zen-meta-api" deleted
networkpolicy.networking.k8s.io "allow-webhook-access-from-apiserver" deleted
No resources found
-----------------------------------------------------------------------
[✔] Bedrock NetworkPolicies installation completed.
```
