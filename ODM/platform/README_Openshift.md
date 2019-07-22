# Install IBM Operational Decision Manager on Red Hat OpenShift

Before you install make sure that you have prepared your environment. For more information, see [Preparing to install ODM for production](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_preparing_odmk8s.html) as well as [Customizing ODM for production](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_install_odm.html).

## Step 1: Prepare your environment

As an administrator of the cluster you must be able to interact with your environment. Run the following commands to connect and check your access.

1. Login to the cluster:
   ```console
   $ oc login https://<CLUSTERIP>:8443 -u <ADMINISTRATOR>
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

4. Generate a permanent token and copy it to the clipboard.
   ```console
   $ oc whoami -t 
   ```
5. Login to the docker registry with the token and check you can run docker.
   ```console
   $ docker login docker-registry.default.svc:5000 -u <ADMINISTRATOR> -p <generated_token>
   $ docker ps
   ```
   > **Note**: You can connect to a node in the cluster to resolve the docker-registry.default.svc parameter.
   
6. Run a kubectl command to make sure you have access to Kubernetes.
   ```console
   $ kubectl cluster-info
   ```


## Step 2: Push and tag the downloaded images in the OpenShift registry

1. If you have not already done so, follow the instructions to download the IBM Operational Decision Manager images and the loadimages.sh file in [Download PPA and load images](../../README.md#step-2-download-a-product-package-from-ppa-and-load-the-images).

   > **Note**: Change the permissions so that you can execute the script.
      ```console
      $ chmod +x loadimages.sh
      ```

2. Use the loadimages.sh script to push the docker images into your registry.
   ```console
   $ ./loadimages.sh -p <PPA-ARCHIVE>.tgz -r docker-registry.default.svc:5000/odmproject
   ```

   > **Note**: The project must have pull request privileges to the registry where the Operational Decision Manager images are   loaded. The project must also have pull request privileges to push the images into another namespace/project. 

## Step 3: Install a Kubernetes release of Operational Decision Manager

You can do this step without administrator rights.

1. Download the [ibm-odm-prod-2.2.0.tgz](../helm-charts/ibm-odm-prod-2.2.0.tgz) file. The archive contains the `ODM for production (ibm-odm-prod)` Helm chart.

2. Install a release with the default configuration and a name of `my-odm-prod-release`. You have 2 options to install Operation Decision Manager on Openshift depending on your security policy.

   * Option 1: Use the helm CLI to generate a template and then the OpenShift CLI to create a release from the YAML file.

     ```console
     $ helm template \
       --name my-odm-prod-release \
       /path/to/ibm-odm-prod-<version>.tgz \
       --set image.repository=docker-registry.default.svc:5000/odmproject/ > odm-k8s.yaml
     $ oc create --save-config=true -f odm-k8s.yaml
     ```

     > **Note**: For more information, see [k8s-yaml/README.md](../k8s-yaml/README.md).

   * Option 2: If you installed Tiller on your cluster, you can use a single command from the helm CLI.

     ```console
     $ helm install \
       --name my-odm-prod-release \
       /path/to/ibm-odm-prod-<version>.tgz \
       --set image.repository=docker-registry.default.svc:5000/odmproject/
     ```

     > **Note**: For more information, see [helm-charts/README.md](../helm-charts/README.md). 

3. The package is deployed asynchronously in a matter of minutes, and is composed of several services.

   > **Note**: You can check the status of the pods that you created:
   ```console
   $ kubectl get pods
   NAME                                                READY   STATUS    RESTARTS   AGE
   my-odm-prod-release-dbserver-***                    1/1     Running   0          44m
   my-odm-prod-release-odm-decisioncenter-***          1/1     Running   0          44m
   my-odm-prod-release-odm-decisionrunner-***          1/1     Running   0          44m
   my-odm-prod-release-odm-decisionserverconsole-***   1/1     Running   0          44m
   my-odm-prod-release-odm-decisionserverruntime-***   1/1     Running   0          44m
   ```

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

You can now expose the service to your users.

> **Tip**: Refer to [Verify a deployment](../README.md#step-1-verify-a-deployment) post installation step to get the URLs of the services.

## To customize a release

Refer to the customizing instructions in [k8s-yaml/README.md](../k8s-yaml/README.md#customize-a-kubernetes-release-of-operational-decision-manager).

## To uninstall the Helm chart

   * Option 1: To uninstall and delete a release named `my-odm-prod-release` from the OpenShift CLI, use the following command:

     ```console
     $ oc delete -f odm-k8s.yaml
     ```

     The `odm-k8s.yaml` is the file you created in step 3: [Install an Operational Decision Manager release](README_Openshift.md#step-3-install-a-kubernetes-release-of-operational-decision-manager).

  * Option 2: To uninstall and delete a release named `my-odm-prod-release` with Helm Tiller, use the following command:

     ```console
     $ helm delete my-odm-prod-release --purge
     ```

     The command removes all the Kubernetes components associated with the chart, except Persistent Volume Claims (PVCs). This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. 
     
  * Optional: To delete the data, you can delete the PVC by using the following command:

     ```console
     $ kubectl delete pvc <release_name>-odm-pvclaim -n <namespace>
     ```


