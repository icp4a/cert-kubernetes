# Deploying with YAML files

## Requirements and Prerequisites

Ensure that you have completed the following tasks:

- [Preparing your Kubernetes server](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_k8s.html)
- [Downloading the PPA archive](../../README.md)
- [Preparing to install Business Automation Navigator](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_bank8s.html)

## Deploying component images

Use the command line to deploy the image using the parameters in the appropriate YAML file. You also use the command line to determine access information for your deployed images.

For deployments on Red Hat OpenShift, note the following considerations for whether you want to use the Arbitrary UID capability in your environment:

- If you don't want to use Arbitrary UID capability in your Red Hat OpenShift environment, deploy the image as described in the following section.

- If you do want to use Arbitrary UID, prepare for deployment by updating your deployment file and editing your Security Context Constraint:

  - Remove the following line from your deployment YAML file: `runAsUser: 50001`.
  
  - In your SCC, set the desired user id range of minimum and maximum values for the project namespace:
  
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
 1. Use the deployment file to deploy Business Automation Navigator:
    
    ```kubectl apply -f icn-deploy.yml```
 2. Run following command to get the Public IP and port to access Business Automation Navigator:
    
    ```kubectl get svc | grep ecm-icn```


> **Reminder**: After you deploy, return to the instructions in the Knowledge Center, [Configuring IBM Business Automation Navigator in a container environment](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_ecmconfigbank8s.html), to get your Business Automation Navigator environment up and running.

## Upgrading deployments
   > **Tip**: You can discover the necessary resource values for the deployment from corresponding product deployments in IBM Cloud Private Console and Openshift Container Platform.

### Before you begin
Before you run the upgrade commands, you must prepare the environment for upgrades by updating permissions on your persistent volumes. Complete the preparation steps in the following topic before you start the upgrade: [Upgrading Business Automation Navigator releases](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.upgrading/topics/tsk_cn_upgrade.html)

If you already have a customized YAML file for your existing deployment, update the file with the new parameters for this release before you apply the YAML as part of the upgrade. See the sample YAML files for more information.

You must also [download the PPA archive](../../README.md) before you begin the upgrade process.


### Preparing for upgrade on Red Hat OpenShift

For upgrades on Red Hat OpenShift, note the following considerations when you want to use the Arbitrary UID capability in your updated environment:

- If you don't want to use Arbitrary UID capability in your Red Hat OpenShift environment, use the instructions in Running the upgrade deployments.

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

2. Remove the following line from your deployment YAML file: `runAsUser: 50001`.

3. Update other values in your deployment YAML file to reflect the values for your existing environment and any updates in the new samples.

4. Stop all existing containers.

5. Run the deployment commands for the containers, in the following section. 
### Running the upgrade deployment

<b>Reminder:</b> Update the values in your deployment YAML file to reflect the values for your existing environment.

To deploy Business Automation Navigator: 
 1. Use the deployment file to deploy Business Automation Navigator:
    
    ```kubectl apply -f icn-deploy.yml```
 2. Run following command to get the Public IP and port to access Business Automation Navigator:
    
    ```kubectl get svc | grep ecm-icn```


## Uninstalling a Kubernetes release of Business Automation Navigator

To uninstall and delete the Business Automation Navigator release, use the following command:

```console
$ kubectl delete -f <icn-deploy.yml>
```

The command removes all the Kubernetes components associated with the release, except any Persistent Volume Claims (PVCs).  This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. To delete the persisted data of the release, you can delete the PVC using the following command:

```console
$ kubectl delete pvc my-icn-prod-release-icn-pvclaim
```
