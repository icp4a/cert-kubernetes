# Configuring IBM Automation Digital Worker

The following instructions cover the basic configuration of IBM Automation Digital Worker.


## Prerequisites

Digital Worker requires:
- A [User Management Service](../UMS/README_config.md) instance in order to protect access to Digital Worker designer and APIs
- An [IBM Business Automation Insights](../BAI/README_config.md) instance (recommended but also optional) in order to collect Digital Worker tasks events and monitor them
- An [IBM Business Automation Studio Resource Registry](../BAS/README_config.md) instance (recommended but also optional) in order to integrate with some other components in the pack

Digital Worker includes 5 pods corresponding to the following services:
   - Digital Worker Designer
   - Digital Worker Tasks Runtime
   - Digital Worker Management Server
   - MongoDB
   - NPM registry

The services require CPU and memory resources. The following table lists the minimum requirements that are used as default values.

| Component                               | CPU Minimum (m) |  Memory Minimum (Mi) |
| ----------------------------------------| --------------- | -------------------- |
| Digital Worker Designer                 | 0.1             | 128                  |
| Digital Worker Tasks Runtime            | 0.1             | 128                  |
| Digital Worker Management Server        | 0.1             | 512                  |
| MongoDB                                 | 0.1             | 128                  |
| NPM registry                            | 0.1             | 128                  |


In addition to these 5 services there are 2 Jobs:
   - Setup
   - Registry

## Preparing for Installation

Before you configure, make sure that you have prepared your environment. For more information, see [Preparing to install IBM Automation Digital Worker](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_prepare_adwk8s.html).

### Step 1: Configure the custom resource YAML file for your Automation Digital Worker deployment

In your `my_icp4a_cr.yaml` file, update the `adw_configuration` section with the configuration parameters. See [IBM Automation Digital Worker parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_adw_K8s_parameters.html) to find the default values for each ADW parameter and customize these values in your file.

> **Note**: The [configuration](configuration) folder provides sample configuration files that you might find useful. Download the files and edit them for your own customizations.

### Step 2: Configuring Security

#### Step 2.1: Apply Security Context Constraint

The Digital Worker role requires a SecurityContextConstraint to be bound to the target namespace prior to installation. To meet this requirement there may be cluster scoped as well as namespace scoped pre and post actions that need to occur.

The [`ibm-restricted-scc`](https://ibm.biz/cpkspec-scc) SecurityContextConstraint is required to install the chart.

you must also have a service account that has the [`ibm-restricted-scc`](https://ibm.biz/cpkspec-scc) SecurityContextConstraint to allow running restricted containers:
```bash
oc adm policy add-scc-to-user ibm-restricted-scc -z ibm-cp4a-operator
```

> **Note**: You can define a custom SecurityContextConstraints to finely control the permissions/capabilities needed to deploy this role. An example has been provided.


#### Step 2.2: Apply Pod Security Policy

Digital Worker requires a pod security policy to be bound to the target namespace prior to installation. To meet this requirement there may be cluster scoped as well as namespace scoped pre and post actions that need to occur.

The predefined pod security policy name: [`ibm-restricted-psp`](https://ibm.biz/cpkspec-psp) has been verified for this chart, if your target namespace is bound to it there is no further action needed in terms of pod security policy.

This chart also defines a custom PodSecurityPolicy which can be used to finely control the permissions/capabilities needed to deploy this chart. You can enable this custom PodSecurityPolicy using the OCP user interface or via the OCP CLI.

Using the CLI you can apply the following YAML file to enable the custom pod security policy:
- [Custom PodSecurityPolicy definition](./configuration/adw-psp.yaml)

After creating the policy, replace all occurrences of `< NAMESPACE >` with the name of namespace the operator is deployed in. Then apply using the following command:

```bash
kubectl apply -f adw-psp.yaml
```

For the custom PodSecurityPolicy to take affect you must bind the ServiceAccount to a ClusterRole. This can be done via the command line using the folliowing command:

```bash
kubectl create clusterrolebinding adw-clusterrolebinding --clusterrole=cluster-admin --serviceaccount=<NAMESPACE>:<SERVICE_ACCOUNT>
```

### Step 3: Prepare and Apply the Secret

Using the [Preparing to install IBM Automation Digital Worker](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_prepare_adwk8s.html) and [IBM Automation Digital Worker parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_adw_K8s_parameters.html) pages, create `adw-secret.yaml` then apply it to your instance using the following command.


```bash
kubectl apply -f adw-secret.yaml
```
> **Note**: An empty secret had been provided [adw-secret.yaml](configuration/adw-secret.yaml)

## Complete the installation

When you have finished editing the configuration file, go back to the relevant install or update page to configure other components and complete the deployment with the operator.

Install pages:
   - [Managed OpenShift installation page](../platform/roks/install.md#step-6-configure-the-software-that-you-want-to-install)
   - [OpenShift installation page](../platform/ocp/install.md#step-6-configure-the-software-that-you-want-to-install)
   - [Certified Kubernetes installation page](../platform/k8s/install.md#step-6-configure-the-software-that-you-want-to-install)

Update pages:
   - [Managed OpenShift installation page](../platform/roks/update.md)
   - [OpenShift installation page](../platform/ocp/update.md#step-1-modify-the-software-that-is-installed)
   - [Certified Kubernetes installation page](../platform/k8s/update.md)


## Post installation

If you intend to connect Digital Worker to Resource Registry or have provisioned User Management Service using the same cr, re-run the setup job post deployment with the following command:

```bash
oc get job <SETUP JOB NAME> -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | kubectl replace --force -f - 
```

## Troubleshooting
### Management pod not going into a ready state
If using dynamically provisioned storage, please ensure that the following line is present and set to true in your custom resource file. If not set the managment pod may fail as it needs to be able to write to the volume:

```yaml
grantWritePermissionOnMountedVolumes: true
```
### Digital Worker tile not present in Business Automation Studio

When integrating with resource registry the mangement service must be exposed to resource registry. If you are using SSL the certificate used will require a CN to be set matching the pod name `< DEPLOYMENT NAME >-management`. 

### The Operator is attempting to install Digital Worker despite the configuration not being present in the custom resource

Should the custom resource be removed post deployment the operator on it's next cycle around may attempt to go through the installation task of the operator role. If this issue does occur the adw deployment in the namespace shall be removed as intended and the error can be ignored. 
