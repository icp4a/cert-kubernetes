# Deploying with YAML files

## Requirements and Prerequisites

Ensure that you have completed the following tasks:

- [Preparing your Kubernetes server](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_k8s.html)
- [Downloading the PPA archive](../../README.md)
- [Preparing to install Business Automation Navigator](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_bank8s.html)

## Deploying component images

Use the command line to deploy the image using the parameters in the appropriate YAML file. You also use the command line to determine access information for your deployed images.

To deploy Business Automation Navigator: 
 1. Use the deployment file to deploy Business Automation Navigator:
    
    ```kubectl apply -f icn-deploy.yml```
 2. Run following command to get the Public IP and port to access Business Automation Navigator:
    
    ```kubectl get svc | grep ecm-icn```


> **Reminder**: After you deploy, return to the instructions in the Knowledge Center, [Configuring IBM Business Automation Navigator in a container environment](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_ecmconfigbank8s.html), to get your Business Automation Navigator environment up and running.

## Upgrading deployments
   > **Tip**: You can discover the necessary resource values for the deployment from corresponding product deployments in IBM Cloud Private Console and Openshift Container Platform.
   
To upgrade Business Automation Navigator:

1. Update the new `icn-deploy.yml` file with the new image name and the parameter values for your existing environment.

2. Run the following command to deploy the image:

```
   kubectl apply -f icn-deploy.yml
```   
3. When the new pod starts, the existing pod terminates automatically.

## Uninstalling a Kubernetes release of Business Automation Navigator

To uninstall and delete the Business Automation Navigator release, use the following command:

```console
$ kubectl delete -f <icn-deploy.yml>
```

The command removes all the Kubernetes components associated with the release, except any Persistent Volume Claims (PVCs).  This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. To delete the persisted data of the release, you can delete the PVC using the following command:

```console
$ kubectl delete pvc my-icn-prod-release-icn-pvclaim
```
