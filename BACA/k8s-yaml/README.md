# Deploying with Kubernetes YAML

Use the command line to deploy the IBM Business Automation Content Analyzer images using the parameters in ca-deploy.yml for specific environment and configuration settings. Review the reference topics for these parameters and determine the values for your environment as part of your preparation:
[CA Kubernetes YAML parameters](./ca_deploy_yaml_parameters.md)

## Deploying component images

After the parameter values for your environment are configured in the ca-deploy.yml file, deploy IBM Business Automation Content Analyzer by following steps:

 1. Use the deployment file to deploy IBM Business Automation Content Analyzer:
    
    ```kubectl apply -f ca-deploy.yml```
 
 Due to the configuration of the readiness probes, after the pods start, it may take up to 10 or more minutes before the pods enter a ready state.
 
 2. Run the following command to see that status of the pods. Wait until all pods are running and ready.
    
    ```kubectl -n <namespace> get pods```

> **Reminder**: After you deploy, return to the instructions for [Completing post deployment tasks for IBM Business Automation Content Analyzer](../docs/post-deployment.md), to review document for further configuration.

## Uninstalling a Kubernetes release of IBM Business Automation Content Analyzer

To uninstall and delete the IBM Business Automation Content Analyzer release, use the following command:

```console
$ kubectl delete -f <ca-deploy.yml>
```

The command removes all the Kubernetes components associated with the release, except any Persistent Volume Claims (PVCs).  This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. To delete the persisted data of the release, you can delete the PVC using the following command:

```console
$ kubectl delete pvc my-baca-prod-release-baca-pvclaim
```

In the configuration folder, the delete_ContentAnalyzer.sh script can also be used to clean up PVs, PVCs, secrets and directories created by the init_deployment.sh script. Simply, run delete_ContentAnalyzer.sh from the master node where the configuration directory was copied to.
