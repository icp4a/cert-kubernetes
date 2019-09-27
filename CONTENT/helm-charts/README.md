# Deploying with Helm charts

> **NOTE**: This procedure covers a Helm chart deployment on certified Kubernetes. To deploy the Enterprise Content Management products on IBM Cloud Private 3.1.2, you must use the Business Automation Configuration Container. 

## Requirements and Prerequisites

Ensure that you have completed the following tasks:

- [Preparing FileNet environment](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_ecmk8s.html)

- [Preparing your Kubernetes server with Kubernetes, Helm Tiller, and the Kubernetes command line](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_k8s.html)

- [Downloading the PPA archive](../../README.md)

The Helm commands for deploying the FileNet Content Manager images include a number of required command parameters for specific environment and configuration settings. Review the reference topics for these parameters and determine the values for your environment as part of your preparation:

- [Content Platform Engine Helm command parameters](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_cpeparamsk8s_helm.html)

- [Content Search Services Helm command parameters](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_cssparamsk8s_helm.html)

- [Content Management Interoperability Services Helm command parameters](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_cmisparamsk8s_helm.html)

## Tips: 

- On Openshift, an expired Docker secret can cause errors during deployment. If an admin.registry key already exists and has expired, delete the key with the following command:
   ```console
   kubectl delete secret admin.registrykey -n <new_project>
   ```
    Then generate a new Docker secret with the following command:
    ```console
   kubectl create secret docker-registry admin.registrykey --docker-server=<registry_url> --docker-username=<new_user> --docker-password=$(oc whoami -t) --docker-email=ecmtest@ibm.com -n <new_project>
    ```


## Initializing the command line interface
Use the following commands to initialize the command line interface:
1. Run the init command:
    ```$ helm init --client-only ```
2. Check whether the command line can connect to the remote Tiller server:
   ```console
   $ helm version
    Client: &version.Version{SemVer:"v2.9.1", GitCommit:"f6025bb9ee7daf9fee0026541c90a6f557a3e0bc", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.9.1", GitCommit:"f6025bb9ee7daf9fee0026541c90a6f557a3e0bc", GitTreeState:"clean"}
    ```

## Deploying images
Provide the parameter values for your environment and run the command to deploy the image.
  > **Tip**: Copy the sample command to a file, edit the parameter values, and use the updated command for deployment.
  > **Tip**: The values that are provided for 'resources' inside helm commands are examples only. Each deployment must take into account the demands that their particular workload will place on the system and adjust values accordingly. 

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
To deploy Content Platform Engine:

   ```console
   $ helm install ibm-dba-contentservices-3.1.0.tgz --name dbamc-cpe --namespace dbamc --set cpeProductionSetting.license=accept,cpeProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=18,cpeProductionSetting.JVM_MAX_HEAP_PERCENTAGE=33,service.externalmetricsPort=9103,cpeProductionSetting.licenseModel=FNCM.CU,dataVolume.existingPVCforCPECfgstore=cpe-cfgstore,dataVolume.existingPVCforCPELogstore=cpe-logstore,dataVolume.existingPVCforFilestore=cpe-filestore,dataVolume.existingPVCforICMrulestore=cpe-icmrulesstore,dataVolume.existingPVCforTextextstore=cpe-textextstore,dataVolume.existingPVCforBootstrapstore=cpe-bootstrapstore,dataVolume.existingPVCforFNLogstore=cpe-fnlogstore,autoscaling.enabled=False,resources.requests.cpu=1,replicaCount=1,image.repository=<image_repository_url>:<port>/dbamc/cpe,image.tag=ga-553-p8cpe,cpeProductionSetting.gcdJNDIName=FNGDDS,cpeProductionSetting.gcdJNDIXAName=FNGDDSXA 
   ```
Replace <image_repository_url> with the correct registry URL, for example, docker-registry.default.svc.

To deploy Content Search Services:

   ```console     
     $ helm install ibm-dba-contentsearch-3.1.0.tgz --name dbamc-css --namespace dbamc --set cssProductionSetting.license=accept,service.name=csssvc,service.externalSSLPort=8199,cssProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=38,cssProductionSetting.JVM_MAX_HEAP_PERCENTAGE=50,service.externalmetricsPort=9103,dataVolume.existingPVCforCSSCfgstore=css-cfgstore,dataVolume.existingPVCforCSSLogstore=css-logstore,dataVolume.existingPVCforCSSTmpstore=css-tempstore,dataVolume.existingPVCforIndex=css-indexstore,dataVolume.existingPVCforCSSCustomstore=css-customstore,resources.limits.memory=7Gi,image.repository=<image_repository_url>:<por>/dbamc/css,image.tag=ga-553-p8css,imagePullSecrets.name=admin.registrykey
   ```     
 Replace <image_repository_url> with the correct registry URL, for example, docker-registry.default.svc.
 
Some environments require multiple Content Search Services deployments. To deploy multiple Content Search Services instances, specify a unique release name and service name, and a new set of persistent volumes and persistent volume claims (PVs and PVCs).  The example below shows a deployment using a new release name `dbamc-css2`, a new service name `csssvc2`, and a new set of persistent volumes `css2-cfgstore`, `css2-logstore`, `css2-tempstore`, and `css2-customstore`.  You must use the same persistent volume for the indexstore because multiple Content Search Services deployments must access the same set of index collections.  However, it is recommended that the other persistent volumes be unique.
 
   ```console     
     $ helm install ibm-dba-contentsearch-3.1.0.tgz --name dbamc-css2 --namespace dbamc --set cssProductionSetting.license=accept,service.externalSSLPort=8199,service.externalmetricsPort=9103,service.name=csssvc2,cssProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=38,cssProductionSetting.JVM_MAX_HEAP_PERCENTAGE=50,dataVolume.existingPVCforCSSCfgstore=css2-cfgstore,dataVolume.existingPVCforCSSLogstore=css2-logstore,dataVolume.existingPVCforCSSTmpstore=css2-tempstore,dataVolume.existingPVCforIndex=css-indexstore,dataVolume.existingPVCforCSSCustomstore=css2-customstore,resources.limits.memory=7Gi,image.repository=<image_repository_url>:<port>/dbamc/css,image.tag=ga-553-p8css,imagePullSecrets.name=admin.registrykey
   ```
 
 Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.
 
 
 To deploy Content Management Interoperability Services:

   ```console
     $ helm install ibm-dba-cscmis-1.8.0.tgz --name dbamc-cmis --namespace dbamc --set cmisProductionSetting.license=accept,cmisProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,cmisProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,service.externalmetricsPort=9103,dataVolume.existingPVCforCMISCfgstore=cmis-cfgstore,dataVolume.existingPVCforCMISLogstore=cmis-logstore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:<port>/dbamc/cmis,image.tag=ga-304-cmis-if007,cmisProductionSetting.cpeUrl=http://10.0.0.110:9080/wsi/FNCEWS40MTOM 
   ```
Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.

> **Reminder**: After you deploy, return to the instructions in the Knowledge Center, [Completing post deployment tasks for IBM FileNet Content Manager](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_deploy_postecmdeployk8s.html), to get your FileNet Content Manager environment up and running

## Deploying the External Share container

If you want to optionally include the external share capability in your environment, you also configure and deploy the External Share container. 

Ensure that you have completed the all of the preparation steps for deploying the External Share container: [Configuring external share for containers](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_ecmexternalsharek8s.html)

For deployments on Red Hat OpenShift, note the following considerations for whether you want to use the Arbitrary UID capability in your environment:

- If you don't want to use Arbitrary UID capability in your Red Hat OpenShift environment, deploy the images as described in the following sections.

- If you do want to use Arbitrary UID, prepare for deployment by checking and if needed editing your Security Context Constraint to set the desired user id range of minimum and maximum values for the project namespace:
    ```$ oc edit namespace <project> ```

  For the uid-range annotation, verify that a value similar to the following is specified:
    ```$ openshift.io/sa.scc.uid-range=1000490000/10000 ```
  This range is similar to the default range for Red Hat OpenShift.
  
  You can also remove authenticated users:
   ```$ oc adm policy remove-scc-from-group anyuid system:authenticated ```


To deploy the External Share container:

   ```
     $ helm install ibm-dba-extshare-prod-3.0.1.tgz --name dbamc-es --namespace dbamc --set esProductionSetting.license=accept,esProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,esProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,service.externalmetricsPort=9103,dataVolume.existingPVCforESCfgstore=es-cfgstore,dataVolume.existingPVCforESLogstore=es-logstore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:<port>/dbamc/extshare,image.tag=ga-306-es,esProductionSetting.esDBType=db2,esProductionSetting.esJNDIDSName=ECMClientDS,esProductionSetting.esSChema=ICNDB,esProductionSetting.esTableSpace=ICNDBTS,esProductionSetting.esAdmin=ceadmin
   ```
    
  Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.
 
## Deploying the Technology Preview: Content Services GraphQL API container
If you want to use the Content Services GraphQL API container, follow the instructions in the Getting Started technical notice: [Technology Preview: Getting started with Content Services GraphQL API](http://www.ibm.com/support/docview.wss?uid=ibm10883630)

To deploy the ContentGraphQL Container:

   ```
     $ helm install ibm-dba-contentrestservice-dev-3.1.0.tgz --name dbamc-crs --namespace dbamc --set crsProductionSetting.license=accept,crsProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,crsProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,service.externalmetricsPort=9103,dataVolume.existingPVCforCfgstore=crs-icp-cfgstore,dataVolume.existingPVCforCfglogs=crs-icp-logs,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:<port>/dbamc/crs,image.tag=5.5.3,crsProductionSetting.cpeUri=https://<CPE_Hostname>:<port>/wsi/FNCEWS40MTOM
   ```
   Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.
   Replace <CPE_Hostname>:<port> with the FileNet Content Engine application host and Port.
   


## Upgrading deployments
   > **Tip**: You can discover the necessary resource values for the deployment from corresponding product deployments in IBM Cloud Private Console and Openshift Container Platform.

### Before you begin
Before you run the upgrade commands, you must prepare the environment for upgrades by updating permissions on your persistent volumes. Depending on your starting version you might also need to create or update volumes and folders for Content Search Services and Content Management Interoperability Services. Complete the preparation steps in the following topic before you start the upgrade: [Upgrading Content Manager releases](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.upgrading/topics/tsk_cm_upgrade.htm)

For an upgrade to the External share container, complete the 19.0.2 preparation steps for External Share PV and PVC updates in the following topic before you start the upgrade: [Upgrading Content Manager releases](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.upgrading/topics/tsk_cm_upgrade.htm)

You must also [download the PPA archive](../../README.md) before you begin the upgrade process.

### Upgrading on Red Hat OpenShift

For upgrades on Red Hat OpenShift, note the following considerations when you want to use the Arbitrary UID capability in your updated environment:

- If you don't want to use Arbitrary UID capability in your Red Hat OpenShift environment, use the instructions in Upgrading on certified Kubernetes.

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

3. Run the new install (instead of upgrade) commands for the containers. Update the commands provided to include the values for your existing environment. 

> **NOTE**: In this context, the install commands update the application. Updates for your existing data happen automatically when the updated applications start. 

To deploy Content Platform Engine:

   ```console
   $ helm install ibm-dba-contentservices-3.1.0.tgz --name dbamc-cpe --namespace dbamc --set cpeProductionSetting.license=accept,cpeProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=18,cpeProductionSetting.JVM_MAX_HEAP_PERCENTAGE=33,service.externalmetricsPort=9103,cpeProductionSetting.licenseModel=FNCM.CU,dataVolume.existingPVCforCPECfgstore=cpe-cfgstore,dataVolume.existingPVCforCPELogstore=cpe-logstore,dataVolume.existingPVCforFilestore=cpe-filestore,dataVolume.existingPVCforICMrulestore=cpe-icmrulesstore,dataVolume.existingPVCforTextextstore=cpe-textextstore,dataVolume.existingPVCforBootstrapstore=cpe-bootstrapstore,dataVolume.existingPVCforFNLogstore=cpe-fnlogstore,autoscaling.enabled=False,resources.requests.cpu=1,replicaCount=1,image.repository=<image_repository_url>:<port>/dbamc/cpe,image.tag=ga-553-p8cpe,cpeProductionSetting.gcdJNDIName=FNGDDS,cpeProductionSetting.gcdJNDIXAName=FNGDDSXA 
   ```
Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.

To deploy Content Search Services:

   ```console     
     $ helm install ibm-dba-contentsearch-3.1.0.tgz --name dbamc-css --namespace dbamc --set cssProductionSetting.license=accept,service.name=csssvc,service.externalSSLPort=8199,cssProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=38,cssProductionSetting.JVM_MAX_HEAP_PERCENTAGE=50,service.externalmetricsPort=9103,dataVolume.existingPVCforCSSCfgstore=css-cfgstore,dataVolume.existingPVCforCSSLogstore=css-logstore,dataVolume.existingPVCforCSSTmpstore=css-tempstore,dataVolume.existingPVCforIndex=css-indexstore,dataVolume.existingPVCforCSSCustomstore=css-customstore,resources.limits.memory=7Gi,image.repository=<image_repository_url>:<port>/dbamc/css,image.tag=ga-553-p8css,imagePullSecrets.name=admin.registrykey
   ```     
 Replace <image_repository_url> with the correct registry URL, for example, docker-registry.default.svc.

 To deploy Content Management Interoperability Services:

   ```console
     $ helm install ibm-dba-cscmis-1.8.0.tgz --name dbamc-cmis --namespace dbamc --set cmisProductionSetting.license=accept,cmisProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,cmisProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,service.externalmetricsPort=9103,dataVolume.existingPVCforCMISCfgstore=cmis-cfgstore,dataVolume.existingPVCforCMISLogstore=cmis-logstore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:<port>/dbamc/cmis,image.tag=ga-304-cmis-if007,cmisProductionSetting.cpeUrl=http://10.0.0.110:9080/wsi/FNCEWS40MTOM 
   ```
Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.

To deploy the External Share container:

   ```
     $ helm install ibm-dba-extshare-prod-3.0.1.tgz --name dbamc-es --namespace dbamc --set esProductionSetting.license=accept,esProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,esProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,service.externalmetricsPort=9103,dataVolume.existingPVCforESCfgstore=es-cfgstore,dataVolume.existingPVCforESLogstore=es-logstore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:<port>/dbamc/extshare,image.tag=ga-306-es,esProductionSetting.esDBType=db2,esProductionSetting.esJNDIDSName=ECMClientDS,esProductionSetting.esSChema=ICNDB,esProductionSetting.esTableSpace=ICNDBTS,esProductionSetting.esAdmin=ceadmin
   ```
    
  Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.

### Upgrading on certified Kubernetes platforms (for non Arbitrary UID deployments)

To upgrade Content Platform Engine:

On Red Hat OpenShift:

```
   helm upgrade ecm-helm-cpe ibm-dba-contentservices-3.1.0.tgz --reuse-values --set image.repository=docker-registry.default.svc:5000/{project}/cpe,image.tag=ga-553-p8cpe-if001,imagePullSecrets.name=admin.registrykey,log.format=json,cpeProductionSetting.jvmInitialHeapPercentage=18,cpeProductionSetting.jvmMaxHeapPercentage=33,service.externalmetricsPort=9103
```   
On non-Red Hat OpenShift platforms:

```
   helm upgrade ecm-helm-cpe ibm-dba-contentservices-3.1.0.tgz --reuse-values --tls --set image.repository=<image_repository_url>:<port>/{namespace}/cpe,image.tag=ga-553-p8cpe-if001,imagePullSecrets.name=admin.registrykey,log.format=json,cpeProductionSetting.jvmInitialHeapPercentage=18,cpeProductionSetting.jvmMaxHeapPercentage=33,runAsUser=50001,service.externalmetricsPort=9103
``` 


Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc

To upgrade Content Search Services:

On Red Hat OpenShift:

```
   $ helm upgrade dbamc-css /helm-charts/ibm-dba-contentsearch-3.1.0.tgz  --reuse-values --set image.repository=<image_repository_url>:<port>/dbamc/css,image.tag=ga-553-p8css-if001,imagePullSecrets.name=admin.registrykey,resources.requests.cpu=500m,resources.requests.memory=512Mi,resources.limits.cpu=8,resources.limits.memory=8192Mi,log.format=json,dataVolume.nameforCSSCustomstore=custom-stor,dataVolume.existingPVCforCSSCustomstore=css-icp-customstore,service.,cssProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=38,cssProductionSetting.JVM_MAX_HEAP_PERCENTAGE=50,service.externalmetricsPort=9103
```

On non-Red Hat OpenShift platforms:

```
   $ helm upgrade dbamc-css /helm-charts/ibm-dba-contentsearch-3.1.0.tgz  --reuse-values --set image.repository=<image_repository_url>:<port>/dbamc/css,image.tag=ga-553-p8css,imagePullSecrets.name=admin.registrykey,resources.requests.cpu=500m,resources.requests.memory=512Mi,resources.limits.cpu=8,resources.limits.memory=8192Mi,log.format=json,dataVolume.nameforCSSCustomstore=custom-stor,dataVolume.existingPVCforCSSCustomstore=css-icp-customstore,runAsUser=50001,cssProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=38,cssProductionSetting.JVM_MAX_HEAP_PERCENTAGE=50,service.externalmetricsPort=9103
```

Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.

To upgrade Content Management Interoperability Services:

On Red Hat OpenShift:

```
   $ helm upgrade dbamc-cmis /helm-charts/ibm-dba-cscmis-1.8.0.tgz  --reuse-values --set image.repository=<image_repository_url>:<port>/dbamc/cmis,image.tag=ga-304-cmis-if007,imagePullSecrets.name=admin.registrykey,resources.requests.cpu=500m,resources.requests.memory=512Mi,resources.limits.cpu=1,resources.limits.memory=1024Mi,cmisProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,cmisProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,log.format=json,service.externalmetricsPort=9103
```   
On non-Red Hat OpenShift platforms:

```
   $ helm upgrade dbamc-cmis /helm-charts/ibm-dba-cscmis-1.8.0.tgz  --reuse-values --set image.repository=<image_repository_url>:<port>/dbamc/cmis,image.tag=ga-304-cmis-if007,imagePullSecrets.name=admin.registrykey,resources.requests.cpu=500m,resources.requests.memory=512Mi,resources.limits.cpu=1,resources.limits.memory=1024Mi,log.format=json,runAsUser=50001,cmisProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,cmisProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,service.externalmetricsPort=9103
```

Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.

To upgrade the External Share container:

On Red Hat OpenShift:

   ```
     $ helm upgrade ibm-dba-extshare-prod-3.0.1.tgz --name dbamc-es --namespace dbamc --set esProductionSetting.license=accept,esProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,esProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,dataVolume.existingPVCforESCfgstore=es-cfgstore,dataVolume.existingPVCforESLogstore=es-logstore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:5000/dbamc/extshare,image.tag=ga-306-es,esProductionSetting.esDBType=db2,esProductionSetting.esJNDIDSName=ECMClientDS,esProductionSetting.esSChema=ICNDB,esProductionSetting.esTableSpace=ICNDBTS,esProductionSetting.esAdmin=ceadmin,service.externalmetricsPort=9103
   ```

On non-Red Hat OpenShift platforms:

   ```
     $ helm upgrade ibm-dba-extshare-prod-3.0.1.tgz --name dbamc-es --namespace dbamc --set esProductionSetting.license=accept,esProductionSetting.JVM_INITIAL_HEAP_PERCENTAGE=40,esProductionSetting.JVM_MAX_HEAP_PERCENTAGE=66,dataVolume.existingPVCforESCfgstore=es-cfgstore,dataVolume.existingPVCforESLogstore=es-logstore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:5000/dbamc/extshare,image.tag=ga-306-es,esProductionSetting.esDBType=db2,esProductionSetting.esJNDIDSName=ECMClientDS,esProductionSetting.esSChema=ICNDB,esProductionSetting.esTableSpace=ICNDBTS,esProductionSetting.esAdmin=ceadmin,runAsUser=50001,service.externalmetricsPort=9103
   ```

  Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.



## Uninstalling a Kubernetes release of FileNet Content Manager

To uninstall and delete a release named `my-cpe-prod-release`, use the following command:

```console
$ helm delete my-cpe-prod-release --purge --tls
```

The command removes all the Kubernetes components associated with the release, except any Persistent Volume Claims (PVCs).  This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. To delete the persisted data of the release, you can delete the PVC using the following command:

```console
$ kubectl delete pvc my-cpe-prod-release-cpe-pvclaim
```
