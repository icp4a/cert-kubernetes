# Deploying with YAML files

## Requirements and Prerequisites

Ensure that you have completed the following tasks:

- [Preparing your Kubernetes server](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_k8s.html)
- [Downloading the PPA archive](../../README.md)
- [Preparing FileNet environment](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_ecmk8s.html) 

## Deploying component images

Use the command line to deploy the image using the parameters in the appropriate YAML file. You also use the command line to determine access information for your deployed images.

For deployments on Red Hat OpenShift, note the following considerations for whether you want to use the Arbitrary UID capability in your environment:

- If you don't want to use Arbitrary UID capability in your Red Hat OpenShift environment, deploy the images as described in the following sections.

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


To deploy Content Platform Engine: 
 1. Use the deployment file to deploy Content Platform Engine:
    
    ```kubectl apply -f cpe-deploy.yml```
 2. Run following command to get the Public IP and port to access Content Platform Engine:
    
    ```kubectl get svc | grep ecm-cpe```

To deploy Content Search Services:
 1. Use the deployment file to deploy Content Search Services:
    
    ```kubectl apply -f css-deploy.yml```
 2. Run the following command to get the Public IP and port to access Content Search Services:
    
    ```kubectl get svc | grep ecm-css```

To deploy Content Management Interoperability Services:
 1. Use the deployment file to deploy Content Management Interoperability Services:
    
    ```kubectl apply -f cmis-deploy.yml```
 2. Run the following command to get the Public IP and port to access Content Management Interoperability Services:
    
    ```kubectl get svc | ecm-cmis```

> **Reminder**: After you deploy, return to the instructions in the Knowledge Center, [Completing post deployment tasks for IBM FileNet Content Manager](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_deploy_postecmdeployk8s.html), to get your FileNet Content Manager environment up and running

## Deploying the External Share container

If you want to optionally include the external share capability in your environment, you also configure and deploy the External Share container. 

Ensure that you have completed the all of the preparation steps for deploying the External Share container: [Configuring external share for containers](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_ecmexternalsharek8s.html)

For deployments on Red Hat OpenShift, if you want to use Arbitrary UID, use the steps in the previous section to prepare for the deployment, including updating your YAML file and editing your Security Context Constraint.


To deploy the External Share container:

 1. Use the deployment file to deploy the External Share container:
    
    ```kubectl apply -f es-deploy.yml```
 2. Run the following command to get the Public IP and port to access External Share:
    
    ```kubectl get svc | ecm-es```

## Deploying the Technology Preview: Content Services GraphQL API container
If you want to use the Content Services GraphQL API container, follow the instructions in the Getting Started technical notice: [Technology Preview: Getting started with Content Services GraphQL API](http://www.ibm.com/support/docview.wss?uid=ibm10883630)

 1. Use the deployment file to deploy the Content Services GraphQL API container:
    
    ```kubectl apply -f crs-deploy.yml```
 2. Run the following command to get the Public IP and port to access the Content Services GraphQL API:
    
    ```kubectl get svc | ecm-crs```

## Upgrading deployments
   > **Tip**: You can discover the necessary resource values for the deployment from corresponding product deployments in IBM Cloud Private Console and Openshift Container Platform.

### Before you begin
Before you run the upgrade commands, you must prepare the environment for upgrades by updating permissions on your persistent volumes. Depending on your starting version you might also need to create or update volumes and folders for Content Search Services and Content Management Interoperability Services. Complete the preparation steps in the following topic before you start the upgrade: [Upgrading Content Manager releases](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/com.ibm.dba.upgrading/topics/tsk_cm_upgrade.htm)

If you already have a customized YAML file for your existing deployment, update the file with the new parameters for this release before you apply the YAML as part of the upgrade. See the sample YAML files for more information.

For an upgrade to the External share container, complete the preparation steps in the following topic before you start the upgrade: [Upgrading External Share releases](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/com.ibm.dba.upgrading/topics/tsk_cm_upgrade.htm)

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

### Running the upgrade deployments

To deploy Content Platform Engine: 
 1. Use the deployment file to deploy Content Platform Engine:
    
    ```kubectl apply -f cpe-deploy.yml```
 2. Run following command to get the Public IP and port to access Content Platform Engine:
    
    ```kubectl get svc | grep ecm-cpe```

To deploy Content Search Services:
 1. Use the deployment file to deploy Content Search Services:
    
    ```kubectl apply -f css-deploy.yml```
 2. Run the following command to get the Public IP and port to access Content Search Services:
    
    ```kubectl get svc | grep ecm-css```

To deploy Content Management Interoperability Services:
 1. Use the deployment file to deploy Content Management Interoperability Services:
    
    ```kubectl apply -f cmis-deploy.yml```
 2. Run the following command to get the Public IP and port to access Content Management Interoperability Services:
    
    ```kubectl get svc | ecm-cmis```

To deploy the External Share container:
 1. Use the deployment file to deploy the External Share container:
    
    ```kubectl apply -f es-deploy.yml```
 2. Run the following command to get the Public IP and port to access External Share:
    
    ```kubectl get svc | ecm-es```


## Uninstalling a Kubernetes release of FileNet Content Manager

To uninstall and delete the Content Platform Engine release, use the following command:

```console
$ kubectl delete -f <cpe-deploy.yml>
```

The command removes all the Kubernetes components associated with the release, except any Persistent Volume Claims (PVCs).  This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. To delete the persisted data of the release, you can delete the PVC using the following command:

```console
$ kubectl delete pvc my-cpe-prod-release-cpe-pvclaim
```
Repeat the process for any other deployments that you want to delete.
