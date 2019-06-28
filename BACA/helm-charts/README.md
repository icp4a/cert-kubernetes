# Deploying with Helm charts

- Extract the helm chart from ibm-dba-prod-1.0.0.tgz and copy to the ibm-dbamc-baca-prod directory.
- Extract the helm chart from ibm-dba-prod-1.0.0-ha.tgz and copy to the ibm-dbamc-baca-prod directory for complete HA deployment. [Refer the README-HA](../README-HA.md)


- The Helm commands for deploying the IBM Business Automation Content Analyzer images include a number of required parameters in values.yaml for specific environment and configuration settings. Review the reference topics for these parameters and determine the values for your environment as part of your preparation:
[BACA Helm command parameters](../docs/values_yaml_parameters.md)

## Initializing the command line interface
1. Check whether the command line can connect to the remote Tiller server:
   ```console
   $ helm version
    Client: &version.Version{SemVer:"v2.9.1", GitCommit:"f6025bb9ee7daf9fee0026541c90a6f557a3e0bc", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.9.1", GitCommit:"f6025bb9ee7daf9fee0026541c90a6f557a3e0bc", GitTreeState:"clean"}
    ```
If this fails, go back to the prerequisties and ensure helm is installed.

## Deploying images
After the parameter values for your environment have been configured in the [values.yaml file](../docs/values_yaml_parameters.md) you can deploy:  

To deploy Content Analyzer:  

From the ibm-dba-baca-prod directory:  
   ```console
   $ helm install . --name celery<namespace> -f values.yaml  --namespace <namespace> --tls
   ```
   Note: If helm was installed on OpenShift via the script, do not include `--tls`, instead include `--tiller-namespace tiller`

Due to the configuration of the readiness probes, after the pods start, it may take up to 10 or more minutes before the pods enter a ready state. 

Run the command:
```console
$ kubectl -n <namespace> get pods
```
To see that status of the pods. Wait until all pods are Running and Ready.

After you deploy, review the [Completing post deployment tasks for IBM Business Automation Content Analyzer](../docs/post-deployment.md) document for further configuration.

## Uninstalling a Kubernetes release of IBM Business Automation Content Analyzer

To uninstall and delete a release named `celerysp`, use the following command:

```console
$ helm delete celery<namespace> --purge {--tls} {--tiller-namespace tiller}
```
   Note: If helm was installed on OpenShift via the script, do not include `--tls`, instead include `--tiller-namespace tiller`  
   
The command removes all the Kubernetes components associated with the release, except any Persistent Volume Claims (PVCs) and secrets. This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. To delete the persisted data of the release, you can delete the PVC using the following command:

```console
$ kubectl delete pvc my-baca-prod-release-baca-pvclaim
```

In the configuration folder, the delete_ContentAnalyzer.sh script can be used to clean up PVs, PVCs, secrets and directories created by the init_deployment.sh script. Simply, run delete_ContentAnalyzer.sh from the master node where the configuration directory was copied to.
