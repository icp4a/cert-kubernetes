# Uninstall

> **WARNING** If you have used dynamic provisioning to provision the snapshot storage that is used by the embedded Elasticsearch, the persistent volume claim (PVC) will be deleted as part of the uninstallation process. Before you follow these instructions, back up any snapshots.

## Step 1: Uninstalling custom resources

You can find detailed instructions on the uninstallation page for your platform.
   - [Managed OpenShift installation page](../platform/roks/uninstall.md)
   - [OpenShift installation page](../platform/ocp/uninstall.md)
   - [Certified Kubernetes installation page](../platform/k8s/uninstall.md)

## Step 2: Deallocating storage

To clean up storage used by Business Automation Insights, follow these instructions.

### Statically provisioned storage

If you chose to statically provision storage for Flink or snapshot storage, the persistent volume claims (PVCs) and persistent volumes (PVs) that you manually created are not deleted when the custom resource is removed. To completely remove all data, delete this storage manually.

### Embedded Elasticsearch volumes

If you installed with embedded Elasticsearch enabled, the volumes that were created for the *master* and *data* replicas of the Elasticsearch pods are not deleted by the uninstallation process. To remove an installation completely, delete the relevant PVCs and PVs by using this command.

```bash
kubectl delete pvc/<pvc-name>
```

For example:

```bash
kubectl delete pvc/data-bai-ibm-dba-ek-data-0
```

To get a list of all PVCs, run this command.

```bash
kubectl get pvc
```

If you are working on a Red Hat OpenShift platform, use the `oc` command instead of `kubectl`.

## Step 3: Removing the security configuration

If you used the `bai-psp.yaml` file that is referenced in [README_config.yaml](README_config.yaml) to install the required `PodSecurityPolicy`, `Role`, `RoleBinding`, and `ServiceAccount` resources that are needed by Business Automation Insights, remove this configuration by using this command.

```bash
kubectl delete -f bai-psp.yaml
```

If you are working on a Red Hat OpenShift platform, it is advised that you also remove the default service account and Business Automation Insights service account (defined in the `bai-psp.yaml` file) from privileged SCC:

```bash
oc adm policy remove-scc-from-user privileged -z <CR_NAME>-bai-psp-sa
oc adm policy remove-scc-from-user privileged -z default
```
