# Troubleshooting a deployment for demonstration purposes

The troubleshooting information is divided into the following sections:

 - [Cluster admin setup script issues](install_troubleshooting_ocp.md#cluster-admin-setup-script-issues)
 - [Db2 issues](install_troubleshooting_ocp.md#db2-issues)
 - [Route issues](install_troubleshooting_ocp.md#route-issues)
 
## Cluster admin setup script issues

### Issue: During the execution of the cp4a-clusteradmin-setup.sh script the CRD fails to deploy

If the following message is seen in the output, the user ('XYZ' in the example below) does not have cluster-admin permission:
```
Start to create CRD, service account and role ..Error from server (Forbidden): error when retrieving current configuration of:
"/root/git/cert-kubernetes/descriptors/ibm_cp4a_crd.yaml": customresourcedefinitions.apiextensions.k8s.io "icp4aclusters.icp4a.ibm.com" is forbidden: User "XYZ" cannot get customresourcedefinitions.apiextensions.k8s.io at the cluster scope: no RBAC policy matched
```

1. Log out of the current OCP session (non-admin).

2. Log in to OCP with the OCP cluster admin user.
   ```bash
   $ oc login -u dbaadmin 
   ```
   Where dbaadmin is the OC cluster admin user.

## Db2 issues

Db2 is installed as part of the prerequisites of the patterns. The following issues can be resolved by matching the source of the problem with the proposed solution to make Db2 operational again.

### Issue: Intermittent issue where Db2 process is not listening on port 50000

If the `not listening on port 50000` message is found in the logs:

1. Get the current running Db2 pod: 
   ```bash
   $ oc get pod
   ```
2. Go to the pod: 
   ```bash
   $ oc exec -it <db2 pod> bash
   ```
3. Switch to the db2inst1 user: 
   ```bash
   $ su - db2inst
   ```
4. Reapply the configuration: 
   ```bash
   $ db2 update dbm cfg using SVCENAME 50000
   ```
5. Restart Db2:
   ```bash
   $ db2stop
   $ db2start
   ```

### Issue: Db2 pod failed to start where db2u-release-db2u-0 pod shows 0/1 Ready

This issue has the following symptoms in the Db2 pods:
```
[5357278.440940] db2u_root_entrypoint.sh[20]: + sudo /opt/ibm/db2/V11.5.0.0/adm/db2licm -a /db2u/license/db2u-lic
[5357278.531782] db2u_root_entrypoint.sh[20]: LIC1416N  The license could not be added automatically.  Return code: "-100".
[5357278.535893] db2u_root_entrypoint.sh[20]: + [[ 156 -ne 0 ]]
[5357278.536085] db2u_root_entrypoint.sh[20]: + echo '(*) Unable to apply db2 license.'
[5357278.536177] db2u_root_entrypoint.sh[20]: (*) Unable to apply db2 license.
```

To mitigate the issue, you have a number of options: 
 - Option 1: Kill Db2
 - Option 2: Clean up Db2 and redeploy
 - Option 3: Delete the project
 - Option 4: Reboot the cluster

**Option 1: Kill Db2**
1. Run the following command to get the worker node that db2u is running on: 
   ```bash
   $ oc get pods -o wide
   ```
2. Run a ssh command as root on the worker node hosting Db2u: 
   ```bash
   $ ssh root@<worker node>
   ```
3. Run the following command to kill the orphaned db2u semaphores:
   ```bash
   $ ipcrm -S 0x61a8 
   ```
4. Cleanup the affected project/namespace by running the following commands: 
   ```bash
   $ oc get icp4acluster to get  the custom resource name
   $ oc delete icpa4acluster $name from step(a)
   $ oc delete <operator-deployment-name>
   ```
5. Run the deployment script to start again.

**Option 2: Clean Db2 and redeploy**
1. Get the custom resource name for icp4acluster
   ```bash
   $ oc get icp4acluster  
   ```   
2. Delete the CR: 
   ```bash
   $ oc delete icp4acluster $name
   ```
   or
   ```bash
   $ oc delete -f $cr.yaml
   ```
   The `$cr.yaml` is generated in the ./tmp directory, so you also need to delete the operator deployment by running the following command: 
   ```bash
   $ oc delete <operator-deployment-name>
   ```
3. Make sure there is nothing left by running the following commands:
   ```bash
   $ oc get sts
   $ oc get jobs
   $ oc get deployment
   $ oc get pvc | grep db2
   ```
4. Run the deployment script to start again.

**Option 3: Delete the project/namespace**
1. If options 1 or 2 don't work, delete the project and redeployment by running the following steps:
   ```bash
   $ oc delete project $project_name
   ```

**Option 4: Reboot the entire cluster**
1. If none of the other options work, get the names of the nodes and reboot them:
   ```bash
   $ oc get no --no-headers | awk '{print $1}'
   ```
2. Reboot all of the nodes listed (reboot the worker nodes first, then the infrastructure node, and then the master node).

### Issue: db2-release-db2u-restore-morph-job-xxxxx shows "Running", but fails to be "Completed"

Run the following command to check and confirm this issue:
```bash
$ oc get pod
```

The command outputs a table showing the STATUS and READY columns:
```bash
NAME                                        READY        STATUS 
db2-release-db2u-restore-morph-job-xxxxx    1/1          Running
```

If the STATUS does not change to `Completed` after a few minutes.
1. Delete the Db2 pod by running the `oc delete` command: 
   ```bash
   $ oc delete pod db2-release-db2u-restore-morph-job-xxxxx
   ```
2. Confirm that the Db2 job is terminated and a new pod is up and running:
   ```bash
   $ oc get pod -w
   ```
   When the job reads `Completed`, the pattern can continue to deploy.

## Route issues

### Issue: Generated routes do not work

In some environments, route URLs contain the string `apps.`. However, the cp4a-clusteradmin-setup.sh script returns the hostname of the infrastructure node without this string. If you entered the hostname in the cp4a-post-deployment.sh script in an environment that uses `apps.`, the routes do not work. 

**Workaround:**
When you run the cp4a-deployment.sh script, add `apps.` to the infrastructure hostname. 

For example, if the cp4a-clusteradmin-setup.sh script outputs the infrastructure hostname as `ocp-master.tec.uk.ibm.com`, enter `ocp-master.apps.tec.uk.ibm.com` when you run the cp4a-post-deployment.sh script.

Tip: You can find the existing route URL by running `oc get route --all-namespaces`, and extract the common pattern URL for the routes.
