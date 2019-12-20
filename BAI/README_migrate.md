# Upgrading IBM® Business Automation Insights

These instructions cover upgrading IBM® Business Automation Insights.

## Upgrading from IBM® Business Automation Insights version 19.0.2 to 19.0.3

These intructions will detail upgrading from a Helm / Kubernetes resource installation of Business Automation Insights version 19.0.2 to a Operator install of Business Automation Insights version 19.0.3.

### Important note about Elasticsearch snapshot storage

If Dynamic Provisioning was used to create the Elasticsearch snapshot storage PersistentVolumeClaim for Business Automation Insights version 19.0.2, deleting this release will delete this PersistentVolumeClaim. It is recommended you backup the data in the PersistentVolume before uninstalling this release.

If Static Provisioning was used to provision the snapshot storage PersistentVolumeClaim, this storage can be reused for 19.0.3. The value for `ibm-dba-ek.elasticsearch.data.snapshotStorage.existingClaimName` can be used for the `spec.bai_configuration.ibm-dba-ek.elasticsearch.data.snapshotStorage.existingClaimName` value in the new ICP4ACluster custom resource (see Step 3. Migrate custom values to Custom Resource).

### Step 1: Get latest configuration values

Before uninstalling Business Automation Insights version 19.0.2 ensure the configuration values used for this installation are available.

To do this, either:
* Retrieve the original `values.yaml` configuration parameter overrides file used in the `helm install` or `helm template` command for the installation. This file would have been specified using the `-f` flag in the original install.
* Alternatively, if the configuration parameters have changed since install, it is recommended to export the latest values using this command:

```bash
helm get values my-bai-release
```

### Step 2: Uninstall Business Automation Insights version 19.0.2

> **Note** Events sent to Kafka by product event processors between the uninstallation of the previous release and the completion of the installation of 19.0.3 are not processed by Business Automation Insights 19.0.3.

Depending on the installation method used to install Business Automation Insights, use one of the following methods to uninstall the 19.0.2 version.

#### Helm installation (using `helm install`)

Use the `helm delete` command to delete the Helm release for the Business Automation Insights installation:

```bash
helm delete --purge my-bai-release
```

#### Kubernetes Resource installation (using `helm template`)

Use the following procedure if the `helm template` command was used to generate Kubernetes YAML files to install Business Automation Insights version 19.0.2:
1. Navigate to the directory where the YAML files were exported. This is the directory set using the `--output-dir` flag in the `helm template` command.
2. Run the `kubectl delete` command for the installed resources:

```bash
kubectl delete -f ./ibm-business-automation-insights/templates && \
kubectl delete -f ./ibm-business-automation-insights/charts/ibm-dba-ek/templates
```

### Step 3: Clean up Flink persistent storage

**IMPORTANT** You must ensure that the PersistentVolume used for Flink in the 19.0.2 release is deleted, or the contents are cleared. Due to an upgrade of Apache Flink, the data stored is not able to be reused between installations.

For information regarding cleaning up persistent storage following an uninstallation see [README_uninstall.md](README_uninstall.md).

#### Dynamic Provisioning

If you used dynamically provisioning for your 19.0.2 installation, ensure that the PersistentVolumeClaim that was created as part of the 19.0.2 release has been deleted.

#### Static Provisioning

If you used static provisioning ensure that either:
* The PersistentVolume and PersistentVolumeClaim defined in the flinkPv.existingVolumeClaim parameter in your helm installation has been deleted following uninstallation; or
* The contents of the PersistentVolume have been deleted following uninstallation. This may be applicable if you are using NFS mounted storage

### Step 4: Migrate custom values to Custom Resource

Copy the configuration parameters used to setup and configure Business Automation Insights from the `values.yaml` override file used for the helm installation of a 19.0.2 release of Business Automation Insights (as detailed in Step 1) to a new ICP4ACluster Custom Resource under the `bai_configuration` section.

For more information on how to configure the ICP4ACluster Custom Resource see [README_config.md](README_config.md).

### Step 5: Preinstallation steps

Read [README_config.md](README_config.md) to ensure all preinstallation instructions have been completed before installing Business Automation Insights version 19.0.3

## Step 6: Complete the upgrade

Go back to the relevant update page to configure other components and complete the deployment with the operator.

Update pages:
   - [Managed OpenShift installation page](../platform/roks/update.md)
   - [OpenShift installation page](../platform/ocp/update.md)
   - [Certified Kubernetes installation page](../platform/k8s/update.md)
