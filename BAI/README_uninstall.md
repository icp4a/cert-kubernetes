# Uninstalling IBM® Business Automation Insights

These instructions cover uninstalling IBM® Business Automation Insights.

> **WARNING** If you have used Dynamic Provision to provision the snapshot storage used by the embedded Elasticsearch, the PVC will be deleted as part of the uninstall. It is recommended to back-up any snapshots before following these instructions.

## Step 1: Uninstall Custom Resource

Detailed uninstall instructions can be found on the uninstall page for your platform:
   - [Managed OpenShift installation page](../platform/roks/uninstall.md)
   - [OpenShift installation page](../platform/ocp/uninstall.md)
   - [Certified Kubernetes installation page](../platform/k8s/uninstall.md)

As mentioned in the above pages to begin the uninstall of Business Automation Insights use `kubectl` to delete the Custom Resource:

```bash
kubectl delete -f my_icp4a_cr.yaml
```

Alternatively, you can use the `oc` command to delete the Custom Resource:

```bash
oc delete -f my_icp4a_cr.yaml
```

The Operator will now start to uninstall Business Automation Insights.

## Step 2: Deallocate storage

To clean up storage used by Business Automation Insights, you will have to follow the instructions below.

### Statically provisioned storage

If you chose to statically provision storage for Flink or Snapshot Storage, the PersistentVolumeClaims and PersistentVolumes that you manually created will not be deleted. To completely remove all data, you will need to delete this storage manually.

### Embedded Elasticsearch volumes

If you installed with the embedded Elasticsearch enabled, the volumes created for the *master* and *data* replicas of the Elasticsearch pods will not be deleted when uninstalling. To completely remove an installation you will need to delete the relevant PersistentVolumeClaims and PersistentVolumes.

To do this run the command:

```bash
kubectl delete pvc/pvc-name
```

For example:

```bash
kubectl delete pvc/data-bai-ibm-dba-ek-data-0
```

To get a list of all PersistentVolumeClaims run the command:

```bash
kubectl get pvc
```

## Step 3: Security configuration

If you used the bai-psp.yaml file referenced in [README_config.yaml](README_config.yaml) to install the required `PodSecurityPolicy`, `Role`, `RoleBinding` and `ServiceAccount` resources needed by Business Automation Insights, you will need to remove this configuration using `kubectl`:

```bash
kubectl delete -f bai-psp.yaml
```

If you are using RedHat OpenShift, it is advised you also remove the default service account and Business Automation Insights service account (defined in the bai-psp.yaml file) from privileged SCC:

```bash
oc adm policy remove-scc-from-user privileged -z <CR_NAME>-bai-psp-sa
oc adm policy remove-scc-from-user privileged -z default
```