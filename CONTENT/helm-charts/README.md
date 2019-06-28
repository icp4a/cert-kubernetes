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

- On Openshift, the security context constraint can cause deployment errors. To prevent this, update the namespace to include the constraints for the components that you want to deploy. For example, the following update accommodates the Content Manager components (50000,50001):

   ```console
   oc edit namespace dbamc-project
   openshift.io/sa.scc.supplemental-groups: 500/50000
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
  > **Tip**: The values that are provided for 'resources' inside helm commands are exampless only. Each deployment must take into account the demands that their particular workload will place on the system and adjust values accordingly. 
  
To deploy Content Platform Engine:

   ```console
   $ helm install ibm-dba-contentservices-3.0.0.tgz --name dbamc-cpe --namespace dbamc --set cpeProductionSetting.license=accept,cpeProductionSetting.jvmHeapXms=512,cpeProductionSetting.jvmHeapXmx=1024,cpeProductionSetting.licenseModel=FNCM.CU,dataVolume.existingPVCforCPECfgstore=cpe-cfgstore,dataVolume.existingPVCforCPELogstore=cpe-logstore,dataVolume.existingPVCforFilestore=cpe-filestore,dataVolume.existingPVCforICMrulestore=cpe-icmrulesstore,dataVolume.existingPVCforTextextstore=cpe-textextstore,dataVolume.existingPVCforBootstrapstore=cpe-bootstrapstore,dataVolume.existingPVCforFNLogstore=cpe-fnlogstore,autoscaling.enabled=False,resources.requests.cpu=1,replicaCount=1,image.repository=<cluster.registry.repo>/dbamc/cpe,image.tag=ga-553-p8cpe,cpeProductionSetting.gcdJNDIName=FNGCDDS,cpeProductionSetting.gcdJNDIXAName=FNGCDDSXA 
   ```

To deploy Content Search Services:

   ```console     
     $ helm install ibm-dba-contentsearch-3.0.0.tgz --name dbamc-css --namespace dbamc --set cssProductionSetting.license=accept,service.name=csssvc,service.externalSSLPort=8199,cssProductionSetting.jvmHeapXmx=3072,dataVolume.existingPVCforCSSCfgstore=css-cfgstore,dataVolume.existingPVCforCSSLogstore=css-logstore,dataVolume.existingPVCforCSSTmpstore=css-tempstore,dataVolume.existingPVCforIndex=css-indexstore,dataVolume.existingPVCforCSSCustomstore=css-customstore,resources.limits.memory=7Gi,cssProductionSetting.jvmHeapXmx=4096,image.repository=<image_repository_url>:5000/dbamc/css,image.tag=ga-553-p8css,imagePullSecrets.name=admin.registrykey
   ```     
 Replace <image_repository_url> with the correct registry URL, for example, docker-registry.default.svc.
 
Some environments require multiple Content Search Services deployments. To deploy multiple Content Search Services instances, specify a unique release name and service name, and a new set of persistent volumes and persistent volume claims (PVs and PVCs).  The example below shows a deployment using a new release name `dbamc-css2`, a new service name `csssvc2`, and a new set of persistent volumes `css2-cfgstore`, `css2-logstore`, `css2-tempstore`, `css2-indexstore`, and `css2-customstore`.  You can reuse the same persistent volume for the indexstore if you want to have multiple Content Search Services deployments that access the same set of index collections.  However, it is recommended that the other persistent volumes be unique.
 
   ```console     
     $ helm install ibm-dba-contentsearch-3.0.0.tgz --name dbamc-css2 --namespace dbamc --set cssProductionSetting.license=accept,service.externalSSLPort=8199,service.name=csssvc2,cssProductionSetting.jvmHeapXmx=3072,dataVolume.existingPVCforCSSCfgstore=css2-cfgstore,dataVolume.existingPVCforCSSLogstore=css2-logstore,dataVolume.existingPVCforCSSTmpstore=css2-tempstore,dataVolume.existingPVCforIndex=css2-indexstore,dataVolume.existingPVCforCSSCustomstore=css2-customstore,resources.limits.memory=7Gi,cssProductionSetting.jvmHeapXmx=4096,image.repository=<image_repository_url>:5000/dbamc/css,image.tag=ga-553-p8css,imagePullSecrets.name=admin.registrykey
   ```
 
 Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.
 
 
 To deploy Content Management Interoperability Services:

   ```console
     $ helm install ibm-dba-cscmis-1.7.0.tgz --name dbamc-cmis --namespace dbamc --set cmisProductionSetting.license=accept,cmisProductionSetting.jvmHeapXms=512,cmisProductionSetting.jvmHeapXmx=1024,dataVolume.existingPVCforCMISCfgstore=cmis-cfgstore,dataVolume.existingPVCforCMISLogstore=cmis-logstore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:5000/dbamc/cmis,image.tag=ga-304-cmis-if007,cmisProductionSetting.cpeUrl=http://10.0.0.110:9080/wsi/FNCEWS40MTOM 
   ```
Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.

> **Reminder**: After you deploy, return to the instructions in the Knowledge Center, [Completing post deployment tasks for IBM FileNet Content Manager](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_deploy_postecmdeployk8s.html), to get your FileNet Content Manager environment up and running

## Deploying the External Share container

If you want to optionally include the external share capability in your environment, you also configure and deploy the External Share container. 

Ensure that you have completed the all of the preparation steps for deploying the External Share container: [Configuring external share for containers](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_ecmexternalsharek8s.html)

To deploy the External Share container:

   ```
     $ helm install ibm-dba-extshare-prod-3.0.0.tgz --name dbamc-es --namespace dbamc --set esProductionSetting.license=accept,esProductionSetting.jvmHeapXms=512,esProductionSetting.jvmHeapXmx=1024,dataVolume.existingPVCforESCfgstore=es-cfgstore,dataVolume.existingPVCforESLogstore=es-logstore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:5000/dbamc/extshare,image.tag=ga-306-es,esProductionSetting.esDBType=db2,esProductionSetting.esJNDIDSName=ECMClientDS,esProductionSetting.esSChema=ICNDB,esProductionSetting.esTableSpace=ICNDBTS,esProductionSetting.esAdmin=ceadmin
   ```
    
  Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.
 
## Deploying the Technology Preview: Content Services GraphQL API container
If you want to use the Content Services GraphQL API container, follow the instructions in the Getting Started technical notice: [Technology Preview: Getting started with Content Services GraphQL API](http://www.ibm.com/support/docview.wss?uid=ibm10883630)

To deploy the ContentGraphQL Container:

   ```
     $ helm install ibm-dba-contentrestservice-dev-3.0.0.tgz --name dbamc-crs --namespace dbamc --set crsProductionSetting.license=accept,crsProductionSetting.jvmHeapXms=512,crsProductionSetting.jvmHeapXmx=1024,dataVolume.existingPVCforCfgstore=crs-icp-cfgstore,dataVolume.existingPVCforCfglogs=crs-icp-logs,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:5000/dbamc/crs,image.tag=5.5.3,crsProductionSetting.cpeUri=https://<CPE_Hostname>:<port>/wsi/FNCEWS40MTOM
   ```
   Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.
   Replace <CPE_Hostname>:<port> with the FileNet Content Engine application host and Port.
   


## Upgrading deployments
   > **Tip**: You can discover the necessary resource values for the deployment from corresponding product deployments in IBM Cloud Private Console and Openshift Container Platform.
   
Before you run the upgrade commands, you must prepare the environment for upgrades to Content Search Services and Content Management Interoperability Services. If you plan to upgrade those containers, complete the preparation steps in the following topic before you start the upgrade: [Upgrading Content Manager releases](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/com.ibm.dba.upgrading/topics/tsk_cm_upgrade.htm)

To upgrade Content Platform Engine:

```
   helm upgrade dbamc-cpe /helm-charts/ibm-dba-contentservices-3.0.0.tgz --reuse-values --set image.repository=<image_repository_url>:5000/dbamc/cpe,image.tag=ga-553-p8cpe,imagePullSecrets.name=admin.registrykey,resources.requests.cpu=500m,resources.requests.memory=512Mi,resources.limits.cpu=1,resources.limits.memory=2048Mi,log.format=json
```   
Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc

To upgrade Content Search Services:

```
   $ helm upgrade dbamc-css /helm-charts/ibm-dba-contentsearch-3.0.0.tgz  --reuse-values --set image.repository=<image_repository_url>:5000/dbamc/css,image.tag=ga-553-p8css,imagePullSecrets.name=admin.registrykey,resources.requests.cpu=500m,resources.requests.memory=512Mi,resources.limits.cpu=8,resources.limits.memory=8192Mi,log.format=json,dataVolume.nameforCSSCustomstore=custom-stor,dataVolume.existingPVCforCSSCustomstore=css-icp-customstore
```

Replace <image_repository_url> with correct registry URL, for example, docker-registry.default.svc.

To upgrade Content Management Interoperability Services:

```
   $ helm upgrade dbamc-cmis /helm-charts/ibm-dba-cscmis-1.7.0.tgz  --reuse-values --set image.repository=<image_repository_url>:5000/dbamc/cmis,image.tag=ga-304-cmis-if007,imagePullSecrets.name=admin.registrykey,resources.requests.cpu=500m,resources.requests.memory=512Mi,resources.limits.cpu=1,resources.limits.memory=1024Mi,log.format=json
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
