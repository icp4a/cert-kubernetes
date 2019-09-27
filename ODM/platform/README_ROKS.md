# Install IBM Operational Decision Manager for production on Red Hat OpenShift on IBM Cloud

## Before you begin: Create a cluster and get access to the container images

Before you run any install command, make sure that you have created the IBM Cloud cluster and prepared your own environment. You must also create a pull secret to be able to pull your images from a registry.

For more information, see [Installing containers on Red Hat OpenShift by using CLIs](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_ROKS.html) and [Customizing ODM for production](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_install_odm.html) if you want to customize your ODM release.

## Step 1: Install a release of Operational Decision Manager

> **Note**: You can do this step without administrator rights.

1. Download the [ibm-odm-prod-2.2.1.tgz](../helm-charts/ibm-odm-prod-2.2.1.tgz) file. The archive contains the `ODM for production (ibm-odm-prod)` Helm chart.

2. Log in to your IBM Cloud Kubernetes cluster. In the OpenShift web console menu bar, click your profile *IAM#user.name@email.com* > *Copy Login Command* and paste the copied command into your command line.

   ```console
   $ oc login https://<CLUSTERNAME>:<CLUSTERPORT> --token=<GENERATED_TOKEN>
   ```

3. Go to the project that you created for your release in OpenShift.

   ```console
   $ oc project <project_name>
   ```

4. Install a release with a name of `my-odm-prod-release`. You have 2 options to install Operation Decision Manager on Openshift depending on your security policy.

   In both cases, you might need to increase the default liveness and readiness probes initial delay to prevent premature termination of the pods and reduce unnecessary errors. 
   
   Refer to the documentation to [decide on the file storage configuration](https://cloud.ibm.com/docs/containers?topic=containers-file_storage) or [on block storage configuration](https://cloud.ibm.com/docs/containers?topic=containers-block_storage). Obtain the storage class name for the OpenShift cluster storage, and assign that value as the storageClassName value. You can list all the available storage classes by running the command `kubectl get sc`.

   * **Option 1**: Use the helm CLI to generate a template, and then the OpenShift CLI to create a release from the YAML file.

     ```console
     $ helm template \
       --name my-odm-prod-release \
       /path/to/ibm-odm-prod-2.2.1.tgz \
       --set image.repository=<registry_domain_name>/<project_name>\
       --set image.pullSecrets=<my_pull_secret> \
       --set image.arch=amd64 \
       --set internalDatabase.persistence.storageClassName=ibmc-file-gold \
       --set internalDatabase.persistence.useDynamicProvisioning=true > odm-k8s.yaml
     $ oc create --save-config=true -f odm-k8s.yaml
     ```

     > **Note**: For more information, see [k8s-yaml/README.md](../k8s-yaml/README.md).

   * **Option 2**: If you installed Tiller on your cluster, you can use a single command from the helm CLI.

     ```console
     $ helm install \
       --name my-odm-prod-release \
       /path/to/ibm-odm-prod-2.2.1.tgz \
       --set image.repository=<registry_domain_name>/<project_name>,image.pullSecrets=<my_pull_secret> \
       --set image.arch=amd64 \
       --set internalDatabase.persistence.storageClassName=ibmc-file-gold \
       --set internalDatabase.persistence.useDynamicProvisioning=true \
       --tiller-namespace <tiller_namespace>
     ```

     > **Note**: For more information, see [helm-charts/README.md](../helm-charts/README.md).

   The release is composed of several services. You can check the status of the pods that you created. Pod names are always prefixed with the name of the deployment.

   ```console
   $ kubectl get pods
   NAME                                                READY   STATUS    RESTARTS   AGE
   my-odm-prod-release-dbserver-***                    1/1     Running   0          44m
   my-odm-prod-release-odm-decisioncenter-***          1/1     Running   0          44m
   my-odm-prod-release-odm-decisionrunner-***          1/1     Running   0          44m
   my-odm-prod-release-odm-decisionserverconsole-***   1/1     Running   0          44m
   my-odm-prod-release-odm-decisionserverruntime-***   1/1     Running   0          44m
   ```

   All of the components are now running in a Kubernetes cluster.

   The release is an instance of the `ibm-odm-prod` chart.

## Step 2: Verify the deployment is running

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

## Step 3: Expose the service to your users by creating routes

1. From the OpenShift web console menu bar, select *Application console* and select `odmproject` project.

2. Navigate to the *Routes* page under the *Applications* section and click **Create Route**.

3. Create a route for each service with *Secure Route* enabled and *TLS Termination* type set to **Passthrough**.

   > **Note**: You can also create the routes using the `oc` CLI.
   > ```console
   > $ oc create route passthrough --service=my-odm-prod-release-odm-decisioncenter -n odmproject
   > ```
   > For more information, refer to the [OpenShift documentation](https://docs.openshift.com/container-platform/3.11/dev_guide/routes.html).

## To uninstall the Helm chart

   * **Option 1**: To uninstall and delete a release named `my-odm-prod-release` by using the OpenShift CLI, run the following command:
     ```console
     $ oc delete -f odm-k8s.yaml
     ```
     The `odm-k8s.yaml` is the file you created in step 1.

   * **Option 2**: To uninstall and delete a release named `my-odm-prod-release` by using Helm Tiller, run the following command:

     ```console
     $ helm delete my-odm-prod-release --purge --tiller-namespace <tiller_namespace>
     ```
     The command removes all of the Kubernetes components associated with the chart.

## To upgrade a release

Make sure that you have the new images in the container registry that you plan to use for your upgrade, and then refer to the [Upgrade section](helm-charts/README.md#upgrade-a-release) in the helm-charts folder for instructions using Tiller, or the [Upgrade section](k8s-yaml/README.md#upgrade-a-release) in the k8s-yaml folder for instructions on how to use Kubernetes YAML.

