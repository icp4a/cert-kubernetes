
# Deploying with Helm charts

> **NOTE**: To deploy Enterprise Content Management products (FNCM , CSS & CMIS) on IBM Cloud Private 3.1.2 you must use Business Automation Configuration Container (BACC).

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

- On Openshift, the security context constraint can cause deployment errors. To prevent this, update the namespace to include the constraints for the components that you want to deploy. For example, the following update accommodates Business Automation Navigator (50000,50001):

   ```console
   oc edit namespace dbamc-project
   openshift.io/sa.scc.supplemental-groups: 50000
   openshift.io/sa.scc.uid-range: 50001
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

To deploy Business Automation Navigator:

   ```console
   $ helm install ibm-dba-navigator-3.0.0.tgz --name dbamc-navigator --namespace dbamc --set icnProductionSetting.license=accept,icnProductionSetting.jvmHeapXms=512,icnProductionSetting.jvmHeapXmx=1024,icnProductionSetting.icnDBType=db2,icnProductionSetting.icnJNDIDSName=ECMClientDS,icnProductionSetting.icnSChema=ICNDB,icnProductionSetting.icnTableSpace=ICNDBTS,icnProductionSetting.icnAdmin=ceadmin,icnProductionSetting.navigatorMode=3,dataVolume.existingPVCforICNCfgstore=icn-cfgstore,dataVolume.existingPVCforICNLogstore=icn-logstore,dataVolume.existingPVCforICNPluginstore=icn-pluginstore,dataVolume.existingPVCforICNVWCachestore=icn-vw-cachestore,dataVolume.existingPVCforICNVWLogstore=icn-vw-logstore,dataVolume.existingPVCforICNAsperastore=icn-asperastore,autoscaling.enabled=False,replicaCount=1,imagePullSecrets.name=admin.registrykey,image.repository=<image_repository_url>:5000/dbamc/navigator,image.tag=ga-306-icn
   ```
Replace <image_repository_url> with correct registry url. For example --> docker-registry.default.svc

> **Reminder**: After you deploy, return to the instructions in the Knowledge Center, [Configuring IBM Business Automation Navigator in a container environment](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_ecmconfigbank8s.html), to get your Business Automation Navigator environment up and running.

## Upgrade images

To deploy Business Automation Navigator:

   IBM Cloud Private 3.1.2
   
```
   $ export HELM_HOME=/root/.helm
   
   Modify **HELM_HOME** directory to match with your respective directory.
   
   $ helm repo add local-charts https://mycluster.icp:8443/helm-repo/charts --ca-file $HELM_HOME/ca.pem --cert-file $HELM_HOME/cert.pem --key-file $HELM_HOME/key.pem
   
   $ helm upgrade dbamc-icn local-charts/ibm-dba-navigator --version=3.0.0 --tls --reuse-values --set image.repository=mycluster.icp:8500/apprentice/navigator,image.tag=stable-ubi,resources.requests.cpu=500m,resources.requests.memory=512Mi,imagePullSecrets.name=admin.registrykey,resources.limits.cpu=1,resources.limits.memory=1024Mi,log.format=json
```
   Certified Kubernetes platform
```
   $ helm upgrade dbamc-icn /helm-charts/ibm-dba-navigator-3.0.0.tgz  --reuse-values --set image.repository=mycluster.icp:8500/apprentice/navigator,image.tag=stable-ubi,resources.requests.cpu=500m,resources.requests.memory=512Mi,imagePullSecrets.name=admin.registrykey,resources.limits.cpu=1,resources.limits.memory=1024Mi,log.format=json
```   
## Uninstalling a Kubernetes release of Business Automation Navigator

To uninstall and delete a release named `my-icn-prod-release`, use the following command:

```console
$ helm delete my-icn-prod-release --purge
```

The command removes all the Kubernetes components associated with the release, except any Persistent Volume Claims (PVCs).  This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. To delete the persisted data of the release, you can delete the PVC using the following command:

```console
$ kubectl delete pvc my-icn-prod-release-icn-pvclaim
```
