# Install IBM Operational Decision Manager with the Helm CLI

A [Helm chart](https://helm.sh/) is a Package Manager for Kubernetes to help you manage (install/upgrade/update) your Kubernetes deployment. If you are using Helm on a cluster that you completely control, like Minikube or a cluster on a private network in which sharing is not a concern, the default installation that applies no security configuration is the easiest option.

However, if your cluster is exposed to a larger network or if you share your cluster with others – production clusters fall into this category – you must secure your installation to prevent careless or malicious actors from damaging the cluster or its data. To secure Helm for use in a production environment and other multi-tenant scenarios, see [Securing a Helm installation](https://helm.sh/docs/using_helm/#securing-your-helm-installation).

Before you install make sure that you have prepared your environment. For more information, see [Preparing to install ODM for production](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_preparing_odmk8s.html) as well as [Customizing ODM for production](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_install_odm.html).

1. If Helm is not installed in your Kubernetes cluster, install [Helm 2.11.0](https://github.com/helm/helm/releases/tag/v2.11.0).
2. When Helm is ready, initialize the local CLI and install Tiller.

   ```console
   $ helm init
   ```
   Tiller is now installed in the Kubernetes cluster with the current-context configuration.

   > **Important**:  Helm looks for Tiller in the kube-system namespace unless --tiller-namespace or TILLER_NAMESPACE is set. If your administrator installed Tiller in a namespace other than kube-system, make sure to set TILLER_NAMESPACE before you use the following helm commands, or add --tiller-namespace to each helm command.

   By default, Tiller does not have authentication enabled. For more information about configuring strong TLS authentication, see the [Tiller TLS guide](https://helm.sh/docs/using_helm/#using-ssl-between-helm-and-tiller).

3. Download the `ibm-odm-prod-2.2.1.tgz` Helm chart from the GitHub repository.
   - [ibm-odm-prod-2.2.1.tgz](ibm-odm-prod-2.2.1.tgz) for Operational Decision Manager 8.10.2

   If you have not done so yet, follow the instructions to download the IBM Operational Decision Manager images and the loadimages.sh file in [Download PPA and load images](../../README.md#step-2-download-a-product-package-from-ppa-and-load-the-images).

4. Install a Kubernetes release with the default configuration and a name of `my-odm-prod-release` by using the following command:

   ```console
   $ helm install --name my-odm-prod-release \
     /path/to/ibm-odm-prod-2.2.1.tgz
   ```
   The package is deployed asynchronously in a matter of minutes, and is composed of several services.

   > **Note**: You can check the status of the pods that have been created:
   ```console
   $ kubectl get pods
   NAME                                                READY   STATUS    RESTARTS   AGE
   my-odm-prod-release-dbserver-***                    1/1     Running   0          44m
   my-odm-prod-release-odm-decisioncenter-***          1/1     Running   0          44m
   my-odm-prod-release-odm-decisionrunner-***          1/1     Running   0          44m
   my-odm-prod-release-odm-decisionserverconsole-***   1/1     Running   0          44m
   my-odm-prod-release-odm-decisionserverruntime-***   1/1     Running   0          44m
   ```

5. List the helm releases in your cluster.

   ```console
   $ helm ls
   ```
   The release is an instance of the `ibm-odm-prod` chart. All the Operational Decision Manager components are now running in a Kubernetes cluster.

   To verify a deployment, go back to the [Post installation steps](../README.md#post-installation-steps).

## Customize a Kubernetes release of Operational Decision Manager

Refer to the [ODM for production Certified Kubernetes parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_parameters_prod.html) for a complete list of values that you can configure.

### To customize the helm install with --set key=value arguments

Using the `helm install` command, you can specify each parameter with a `--set key=value` argument. For example, the following command sets 3 parameters for the internal database.

```console
$ helm install --name my-odm-prod-release \
  --set internalDatabase.databaseName=my-db \
  --set internalDatabase.user=my-user \
  --set internalDatabase.password=my-password \
  /path/to/ibm-odm-prod-2.2.1.tgz
```

> **New in 19.0.1**: Use the new `customlibPvc` parameter to customize Decision Center in your release. Use the name of the persistent volume claim (PVC) you set up when you prepared the release as the parameter value. For more information, see [Preparing to install Operational Decision Manager](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_preparing_odmk8s.html).
```console
--set decisionCenter.customlibPvc=custom-dc-libs-pvc
```

### To customize the helm install with a YAML file

You can use a custom-made .yaml file to specify the values of the parameters when you install the chart. For example, the following command uses the `myvalues.yaml` file.

```console
$ helm install --name my-odm-prod-release -f myvalues.yaml /path/to/ibm-odm-prod-2.2.1.tgz
```

> **Tip**: Refer to the [`sample-values.yaml`](../configuration/sample-values.yaml) file to find the default values used by the `ibm-odm-prod` chart.

## Upgrade a release

1. [Download the latest PPA file from IBM Passport Advantage and load the new images.](../../README.md#step-2-download-a-product-package-from-ppa-and-load-the-images)

2. Run the helm upgrade command on the release that you want to upgrade. The following example command upgrades a release `my-odm-prod-release` with the new Helm chart.
   ```console
   $ helm upgrade my-odm-prod-release /path/to/ibm-odm-prod-2.2.1.tgz --set image.tag=8.10.2.1 --reuse-values
   ```

3. Verify that the version of Decision Center and the Decision Server console is the new version and they are running on the same URL and port as before.

4. If your release uses an internal database, go to the `my-odm-prod-release-dbserver` pod and change the `volumeMounts` definition in the deployment YAML file. The following definition is from a previous version.

   ```console
   "volumeMounts": [ { 
   "name": "my-odm-prod-release-ibm-odm-prod-volume", 
   "mountPath": "/var/lib/postgresql/", 
   "subPath": "pgdata" } ],
   ```
   The definition for chart version 2.2.1 must concatenate the `mountPath` and `SubPath` parameters.

   ```console
   "volumeMounts": [ { 
   "name": "my-odm-prod-release-ibm-odm-prod-volume",
   "mountPath": "/var/lib/postgresql/pgdata" } ],
   ```
    
   > **Caution**: If you do not make this change, historical data from Decision Center and Decision Server is not available in the upgrade.
  
   After you make the change, restart the pod.

## Uninstall a Kubernetes release of Operational Decision Manager

To uninstall and delete a release named `my-odm-prod-release`, use the following command:

```console
$ helm delete my-odm-prod-release --purge
```

The command removes all the Kubernetes components associated with the release, except any Persistent Volume Claims (PVCs).  This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. To delete the persisted data of the release, you can delete the PVC using the following command:

```console
$ kubectl delete pvc my-odm-prod-release-odm-pvclaim
```
