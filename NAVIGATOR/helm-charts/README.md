
# Deploying with Helm charts

> **NOTE**: To deploy on IBM Cloud Private 3.1.2 you must use Business Automation Configuration Container (BACC).

## Requirements and Prerequisites

Ensure that you have completed the following tasks:

- [Preparing to install Business Automation Navigator](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_bank8s.html)

- [Preparing your Kubernetes server, including Kubernetes, Helm Tiller, and Kubernetes command line](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_k8s.html)

- [Downloading the PPA archive](../../README.md)

The Helm command for deploying the Business Automation Navigator image include a number of required command parameters for specific environment and configuration settings. Review the reference topic for these parameters and determine the values for your environment as part of your preparation:

- [Business Automation Navigator Helm command parameters](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_banparamsk8s_helm.html)

## Tips: 

- On Openshift, an expired docker secret can cause errors during deployment. If an admin.registry key already exists and has expired, delete the key with the following command:
   ```console
   kubectl delete secret admin.registrykey -n <new_project>
   ```

    Then generate a new docker secret with the following command:

   ```console
   kubectl create secret docker-registry admin.registrykey --docker-server=<registry_url> --docker-username=<new_user> --docker-password=$(oc whoami -t) --docker-email=ecmtest@ibm.com -n <new_project>
   ```


## Initializing the command line interface
Use the following commands to initialize the command line interface:
1. Run the init command:
   ```console
   $ helm init --client-only
   ```
2. Check whether the command line can connect to the remote Tiller server:
   ```console
   $ helm version
    Client: &version.Version{SemVer:"v2.9.1", GitCommit:"f6025bb9ee7daf9fee0026541c90a6f557a3e0bc", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.9.1", GitCommit:"f6025bb9ee7daf9fee0026541c90a6f557a3e0bc", GitTreeState:"clean"}
    ```

## Deploying images
Provide the parameter values for your environment and run the command to deploy the image.
  > **Tip**: Copy the sample command to a file, edit the parameter values, and use the updated command for deployment.
  > **Tip**: The values which are include for 'resources' inside helm install / upgrade commands just suggestions only. Each deployment must take into account the demands their particular workload will place on the system. 
  
For deployments on Red Hat OpenShift, note the following considerations for whether you want to use the Arbitrary UID capability in your environment:

- If you don't want to use Arbitrary UID capability in your Red Hat OpenShift environment, deploy the images as described in the following sections.

- If you do want to use Arbitrary UID, prepare for deployment by checking and if needed editing your Security Context Constraint:
  - Set the desired user id range of minimum and maximum values for the project namespace:
  
    ```$ oc edit namespace <project> ```

    For the uid-range annotation, verify that a value similar to the following is specified:
    
    ```$ openshift.io/sa.scc.uid-range=1000490000/10000 ```
    
    This range is similar to the default range for Red Hat OpenShift.
  
  - Remove authenticated users from anyuid (if set):
  
     ```$ oc adm policy remove-scc-from-group anyuid system:authenticated ```

  - Update the runAsUser value. 
    Find the entry:
    
    ```
    $ oc get scc <SCC name> -o yaml
        runAsUser:
        type: RunAsAny
    ```

     Update the value:
    
    ```
    $ oc get scc <SCC name> -o yaml
      runAsUser:
      type:  MustRunAsRange
    ```

To deploy Business Automation Navigator:

   ```console
   $ helm install ibm-dba-navigator-3.2.0.tgz --name dbamc-navigator --namespace dbamc --set icnProductionSetting.license=accept,icnProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,icnProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,service.externalmetricsPort=9103,icnProductionSetting.icnDBType=db2,icnProductionSetting.icnJNDIDSName=ECMClientDS,icnProductionSetting.icnSChema=ICNDB,icnProductionSetting.icnTableSpace=ICNDBTS,icnProductionSetting.icnAdmin=ceadmin,icnProductionSetting.navigatorMode=0,dataVolume.existingPVCforICNCfgstore=icn-cfgstore,dataVolume.existingPVCforICNLogstore=icn-logstore,dataVolume.existingPVCforICNPluginstore=icn-pluginstore,dataVolume.existingPVCforICNVWCachestore=icn-vw-cachestore,dataVolume.existingPVCforICNVWLogstore=icn-vw-logstore,dataVolume.existingPVCforICNAsperastore=icn-asperastore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:<port>/dbamc/navigator,image.tag=ga-306-icn
   ```
Replace <image_repository_url> with correct registry url. For example --> docker-registry.default.svc

> **Reminder**: After you deploy, return to the instructions in the Knowledge Center, [Configuring IBM Business Automation Navigator in a container environment](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_ecmconfigbank8s.html), to get your Business Automation Navigator environment up and running.

## Upgrading deployments
   > **Tip**: You can discover the necessary resource values for the deployment from corresponding product deployments in IBM Cloud Private Console and Openshift Container Platform.

### Before you begin
Before you run the upgrade commands, you must prepare the environment for upgrades by updating permissions on your persistent volumes. Complete the preparation steps in the following topic before you start the upgrade: [Upgrading Business Automation Navigator releases](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.upgrading/topics/tsk_cn_upgrade.html)

You must also [download the PPA archive](../../README.md) before you begin the upgrade process.

### Upgrading on Red Hat OpenShift

For upgrades on Red Hat OpenShift, note the following considerations for whether you want to use the Arbitrary UID capability in your updated environment:

- If you don't want to use Arbitrary UID capability in your Red Hat OpenShift environment, use the instructions in Upgrading on certified Kubernetes platforms.

- If you do want to use Arbitrary UID, use the following steps to prepare for the upgrade:

1. Check and if necessary edit your Security Context Constraint to set desired user id range of minimum and maximum values for the project namespace:
    - Set the desired user id range of minimum and maximum values for the project namespace:
  
    ```$ oc edit namespace <project> ```

    For the uid-range annotation, verify that a value similar to the following is specified:
    
    ```$ openshift.io/sa.scc.uid-range=1000490000/10000 ```
    
    This range is similar to the default range for Red Hat OpenShift.
  
   - Remove authenticated users from anyuid (if set):
  
     ```$ oc adm policy remove-scc-from-group anyuid system:authenticated ```

   - Update the runAsUser value. 
     Find the entry:
    
    ```
    $ oc get scc <SCC name> -o yaml
        runAsUser:
        type: RunAsAny
    ```

     Update the value:
    
    ```
    $ oc get scc <SCC name> -o yaml
      runAsUser:
      type:  MustRunAsRange
    ```
2. Stop all existing containers.

3. Run the new install (instead of upgrade) command for the container. Update the command provided to include the values for your existing environment.

> **NOTE**: In this context, the install commands update the application. Updates for your existing data happen automatically when the updated applications start. 

To deploy Business Automation Navigator:

   ```console
   $ helm install ibm-dba-navigator-3.2.0.tgz --name dbamc-navigator --namespace dbamc --set icnProductionSetting.license=accept,icnProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,icnProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,service.externalmetricsPort=9103,icnProductionSetting.icnDBType=db2,icnProductionSetting.icnJNDIDSName=ECMClientDS,icnProductionSetting.icnSChema=ICNDB,icnProductionSetting.icnTableSpace=ICNDBTS,icnProductionSetting.icnAdmin=ceadmin,icnProductionSetting.navigatorMode=0,dataVolume.existingPVCforICNCfgstore=icn-cfgstore,dataVolume.existingPVCforICNLogstore=icn-logstore,dataVolume.existingPVCforICNPluginstore=icn-pluginstore,dataVolume.existingPVCforICNVWCachestore=icn-vw-cachestore,dataVolume.existingPVCforICNVWLogstore=icn-vw-logstore,dataVolume.existingPVCforICNAsperastore=icn-asperastore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:<port>/dbamc/navigator,image.tag=ga-306-icn
   ```
Replace <image_repository_url> with correct registry url. For example --> docker-registry.default.svc


## Upgrading on certified Kubernetes platforms

To deploy Business Automation Navigator:

On Red Hat OpenShift:
   
```
   $ helm upgrade dbamc-helm-navigator ibm-dba-navigator-3.2.0.tgz --reuse-values --set image.repository=<image_repository_url>:<port>/dbamc/navigator/navigator,image.tag=ga-306-icn-if002,resources.requests.cpu=500m,resources.requests.memory=512Mi,icnProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,icnProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,imagePullSecrets.name=admin.registrykey,resources.limits.cpu=1,resources.limits.memory=1024Mi,log.format=json,service.externalmetricsPort=9103
```
On non-Red Hat OpenShift:

```
   $ helm upgrade dbamc-helm-navigator ibm-dba-navigator-3.2.0.tgz --tls --reuse-values --set image.repository=<image_repository_url>:<port>/dbamc/navigator,image.tag=ga-306-icn-if002,icnProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,icnProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,service.externalmetricsPort=9103,runAsUser=50001
```   
Replace <image_repository_url> with correct registry url. For example --> docker-registry.default.svc

## Uninstalling a Kubernetes release of Business Automation Navigator

To uninstall and delete a release named `my-icn-prod-release`, use the following command:

```console
$ helm delete my-icn-prod-release --purge
```

The command removes all the Kubernetes components associated with the release, except any Persistent Volume Claims (PVCs).  This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. To delete the persisted data of the release, you can delete the PVC using the following command:

```console
$ kubectl delete pvc my-icn-prod-release-icn-pvclaim
```
