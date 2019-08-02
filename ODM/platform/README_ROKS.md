# Install IBM Operational Decision Manager on Red Hat OpenShift on IBM Cloud

Before you install make sure that you have prepared your environment. For more information, see [Preparing to install ODM for production](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_preparing_odmk8s.html) as well as [Customizing ODM for production](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_install_odm.html).

Refer to Red Hat OpenShift on IBM Cloud documentation to [create a kubernetes cluster in IBM Cloud](https://cloud.ibm.com/docs/openshift?topic=openshift-openshift-create-cluster#openshift_create_cluster_console) and to [install the Red Hat OpenShift Container Platform command line interface (CLI)](https://cloud.ibm.com/docs/openshift?topic=openshift-openshift-cli):
* IBM Cloud CLI (`ibmcloud`)
* Kubernetes Service plug-in (`oc` alias for OpenShift clusters)
* Container Registry plug-in (`ibmcloud cr`)

## Step 1: Prepare your environment

As an administrator of the cluster you must be able to interact with your environment. Run the following commands to connect and check your access.

1. Login to your IBM Cloud Kubernetes cluster:

   - Login to [IBM Cloud account](https://www.ibm.com/cloud) and select *Kubernetes* from the menu [hamburger menu icon].
   - Select the cluster and from the cluster details page, click **OpenShift web console**.
   - In the OpenShift web console menu bar, click your profile *IAM#user.name@email.com* > *Copy Login Command* and paste the copied `oc login` command into your terminal to authenticate:
     ```console
     $ oc login https://<CLUSTERNAME>:<CLUSTERPORT> --token=<GENERATED_TOKEN>
     ```

2. Create a project where you want to install Operational Decision Manager.
   ```console
   $ oc new-project odmproject
   $ oc project odmproject
   ```
3. If you use the internal database you must add privileges to the project.
   ```console
   $ oc adm policy add-scc-to-user privileged -z default
   ```
4. Login to the IBM Cloud Container Registry, create the odmproject namespace in the registry and check you can run docker.
   ```console
   $ ibmcloud login -a https://cloud.ibm.com
   $ ibmcloud cr login
   $ ibmcloud cr namespace-add odmproject
   $ docker ps
   ```

5. Run a kubectl command to make sure you have access to Kubernetes.
   ```console
   $ kubectl cluster-info
   ```

6. Create a pull secret to be able to pull from the IBM Cloud Container Registry
   ```console
   $ kubectl --namespace odmproject create secret docker-registry odmpull \
     --docker-server=us.icr.io --docker-username=iamapikey \
     --docker-password="<APIKEY>" --docker-email=<IBMID>
   ```

   > **Note**: To generate an API KEY navigate to IBM Cloud menu *Security* page > *Manage* > *Identity and Access* > *IBM Cloud API Keys*

7. Create PVC with a storage class.
   ```console
   $ kubectl apply -f example-pvc.yaml
   ```
   The following example uses the storage class `ibmc-file-bronze`:
   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: example-pvc
     namespace: default
   spec:
     accessModes:
       - ReadWriteMany
     resources:
       requests:
         storage: 8Gi
     storageClassName: ibmc-file-bronze
   ```

   > **Note**: You can list all storage classes available with `kubectl get sc`. Refer to the documentation to [decide on the file storage configuration](https://cloud.ibm.com/docs/containers?topic=containers-file_storage) or [on block storage configuration](https://cloud.ibm.com/docs/containers?topic=containers-block_storage).

## Step 2: Push and tag the downloaded images in the OpenShift registry

1. If you have not already done so,
  - 1.1 Download the "Operational Decision Manager for Certified Kubernetes" images from PPA (refer to [19.0.1 download document](https://www-01.ibm.com/support/docview.wss?uid=ibm10878709))
  - 1.2 Download the [loadimages.sh](../../scripts/loadimages.sh) file
   > **Note**: Change the permissions so that you can execute the script.
   >   ```console
   >   $ chmod +x loadimages.sh
   >   ```

2. Use the loadimages.sh script to push the docker images into the IBM Cloud Container Registry.
   ```console
   $ ./loadimages.sh -p <PPA-ARCHIVE>.tgz -r us.icr.io/odmproject
   ```

   > **Note**: `us.icr.io` is the registry domain name for the region *us-south*. Refer to the [documentation](https://cloud.ibm.com/docs/services/Registry?topic=registry-registry_overview#registry_regions_local) to find the domain names of the registry associated to the cluster location.

   > **Note**: The project must have pull request privileges to the registry where the Operational Decision Manager images are   loaded. The project must also have pull request privileges to push the images into another namespace/project.

3. Check whether the images have been pushed correctly to the registry.
   ```console
   oc get is --all-namespaces
   ```
   or
   ```console
   oc get is -n odmproject
   ```

## Step 3: Install a Kubernetes release of Operational Decision Manager

You can do this step without administrator rights.

1. Download the [ibm-odm-prod-2.2.0.tgz](../helm-charts/ibm-odm-prod-2.2.0.tgz) file. The archive contains the `ODM for production (ibm-odm-prod)` Helm chart.

2. Install a release with the default configuration and a name of `my-odm-prod-release`. You have 2 options to install Operation Decision Manager on Openshift depending on your security policy.

   * Option 1: Use the helm CLI to generate a template, and then the OpenShift CLI to create a release from the YAML file.

     ```console
     $ helm template \
       --name my-odm-prod-release \
       /path/to/ibm-odm-prod-<version>.tgz \
       --set image.repository=us.icr.io/odmproject\
       --set image.pullSecrets=odmpull \
       --set internalDatabase.persistence.storageClassName=ibmc-file-bronze \
       --set internalDatabase.persistence.useDynamicProvisioning=true > odm-k8s.yaml
     $ oc create --save-config=true -f odm-k8s.yaml
     ```

     > **Note**: For more information, see [k8s-yaml/README.md](../k8s-yaml/README.md).

   * Option 2: If you installed Tiller on your cluster, you can use a single command from the helm CLI.

     ```console
     $ helm install \
       --name my-odm-prod-release \
       /path/to/ibm-odm-prod-<version>.tgz \
       --set image.repository=us.icr.io/odm-bis,image.pullSecrets=odmpull \
       --set internalDatabase.persistence.storageClassName=ibmc-file-bronze \
       --set internalDatabase.persistence.useDynamicProvisioning=true \
       --tiller-namespace <tiller_namespace>
     ```

     > **Note**: For more information, see [helm-charts/README.md](../helm-charts/README.md).

3. The package is deployed asynchronously in a matter of minutes, and is composed of several services.

   > **Note**: You can check the status of the pods that you created:
   >  ```console
   >  $ kubectl get pods
   >  NAME                                                READY   STATUS    RESTARTS   AGE
   >  my-odm-prod-release-dbserver-***                    1/1     Running   0          44m
   >  my-odm-prod-release-odm-decisioncenter-***          1/1     Running   0          44m
   >  my-odm-prod-release-odm-decisionrunner-***          1/1     Running   0          44m
   >  my-odm-prod-release-odm-decisionserverconsole-***   1/1     Running   0          44m
   >  my-odm-prod-release-odm-decisionserverruntime-***   1/1     Running   0          44m
   >  ```

   The release is an instance of the `ibm-odm-prod` chart. All of the components are now running in a Kubernetes cluster.

## Step 4: Verify that the deployment is running

When all of the pods are *Running*, you can access the status of your application with the following command.
```console
$ oc status
In project odm on server https://localhost:8443

svc/odm-release-dbserver - xxx.xx.xx.xx:5432
  deployment/odm-release-dbserver deploys docker-registry.default.svc:5000/odmproject/dbserver:8.10.x-amd64
    deployment #1 running for 27 minutes - 1 pod

svc/odm-release-odm-decisioncenter (all nodes):31070 -> 9453
  deployment/odm-release-odm-decisioncenter deploys docker-registry.default.svc:5000/odmproject/odm-decisioncenter:8.10.x-amd64
    deployment #1 running for 27 minutes - 1 pod

svc/odm-release-odm-decisionrunner (all nodes):31705 -> 9443
  deployment/odm-release-odm-decisionrunner deploys docker-registry.default.svc:5000/odmproject/odm-decisionrunner:8.10.x-amd64
    deployment #1 running for 27 minutes - 1 pod

svc/odm-release-odm-decisionserverconsole-notif - xxx.xx.xx:1883
http://odm-release-odm-decisionserverconsole-odm.xxx.xx.xx.nip.io to pod port decisionserverconsole-https (svc/odm-release-odm-decisionserverconsole)
  deployment/odm-release-odm-decisionserverconsole deploys docker-registry.default.svc:5000/odmproject/odm-decisionserverconsole:8.10.x-amd64
    deployment #1 running for 27 minutes - 1 pod

http://myserver to pod port decisionserverruntime-https (svc/odm-release-odm-decisionserverruntime)
  deployment/odm-release-odm-decisionserverruntime deploys docker-registry.default.svc:5000/odmproject/odm-decisionserverruntime:8.10.x-amd64
    deployment #1 running for 27 minutes - 1 pod

1 info identified, use 'oc status --suggest' to see details.
```

> **Tip**: Refer to [Verify a deployment](../README.md#step-1-verify-a-deployment) post installation step to get the URLs of the services.

## Step 5: Expose the service to your users using routes

1. From the OpenShift web console menu bar, select *Application console* and select `odmproject` project.

2. Navigate to the *Routes* page, found under the *Applications* section and click **Create Route**

3. Create a route for each service with *Secure Route* enabled and *TLS Termination* type set to **Passthrough**.

> **Note**: You can also create the routes using the `oc` cli.
> ```console
> $ oc create route passthrough --service=my-odm-prod-release-odm-decisioncenter -n odmproject
> ```
> For more information, refer to the [Openshift documentation](https://docs.openshift.com/container-platform/3.11/dev_guide/routes.html)

## To customize a release

Refer to the customizing instructions in [k8s-yaml/README.md](../k8s-yaml/README.md#customize-a-kubernetes-release-of-operational-decision-manager).

## To uninstall the Helm chart

   * Option 1: To uninstall and delete a release named `my-odm-prod-release` with the OpenShift CLI, use the following command:

     ```console
     $ oc delete -f odm-k8s.yaml
     ```

     The `odm-k8s.yaml` is the file you created in step 3: [Install an Operational Decision Manager release](README_Openshift.md#step-3-install-a-kubernetes-release-of-operational-decision-manager).

  * Option 2: To uninstall and delete a release named `my-odm-prod-release` with Helm Tiller, use the following command:

     ```console
     $ helm delete my-odm-prod-release --purge --tiller-namespace <tiller_namespace>
     ```

     The command removes all the Kubernetes components associated with the chart, including Persistent Volume Claims (PVCs).
