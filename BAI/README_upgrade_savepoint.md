# Upgrading Business Automation Insights from a specific checkpoint or savepoint

This document describes how to restart event processing from a specific checkpoint or savepoint during an IBM Business Automation Insights upgrade.

### Prerequisites

Make sure you have the **jq** command-line JSON processor installed. The **jq** tool is available from this page: https://stedolan.github.io/jq/.

### Procedure

1. Retrieve the name of the job manager pod.

```
JOBMANAGER=`kubectl get pods --selector=release=<my-release> --namespace <NAMESPACE> | grep bai-flink-jobmanager | awk '{print $1}'`
```

2. Create savepoints for all the running processing jobs by using the script provided in the job manager pod. The processing is stopped right after the creation of the savepoints.

```
kubectl exec -it $JOBMANAGER --namespace <NAMESPACE> -- scripts/create-savepoints.sh -s
```

This command stops the jobs and returns the path to the created savepoints.
Savepoint stored in `file:/mnt/pv/savepoints/dba/bai-<JOB_NAME>/savepoint-<id>`.


3. If the `create-savepoints.sh` script returns an error while savepoints are created, **and only in this case**, use the latest successful checkpoint.
The `create-savepoints.sh` script returns the names and identifiers of the jobs that failed to create savepoints. <br/>
Not able to create savepoint for job 'dba/bai-`<JOB_NAME>`' with ID: `<JOB_ID>`

   a. Cancel the jobs to prevent the creation of new checkpoints.

   ```
   kubectl exec -it $JOBMANAGER --namespace <NAMESPACE> -- flink cancel <JOB_ID>
   ```

   b. Retrieve the latest successful checkpoint.

   ```
   kubectl exec -it $JOBMANAGER --namespace <NAMESPACE> -- curl -sk https://localhost:8081/jobs/<JOB_ID>/checkpoints | jq ".latest.completed.external_path"
   ```


4. To ensure that, after upgrading, the processing restarts from the saved checkpoints, specify the `<JOB_NAME>.recoveryPath` parameter of each job submitter in the custom resource YAML file.

For this purpose, in the `spec.bai_configuration` element of your custom resource, make sure you have defined the path to the previously saved savepoints or checkpoints from which each job must recover. To use the default workflow of the job, leave this option empty.

|        Job name              | Custom Resource parameter                                          |
| ------------------------------------------------------------------------|-------------------------|
|    **bai-bpmn**              | `bpmn.recoveryPath`                                                |
|    **bai-bawadv**            | `bawadv.recoveryPath`                                              |
|    **bai-icm**               | `icm.recoveryPath`                                                 |
|    **bai-odm**               | `odm.recoveryPath`                                                 |
|    **bai-content**           | `content.recoveryPath`                                             |
|    **bai-ingestion**         | `ingestion.recoveryPath`                                           |
|    **bai-adw**               | `adw.recoveryPath`                                                 |


By default, you can restart a job from a same checkpoint or savepoint only once. This is a safety mechanism in case you forget to remove the value of the `<JOB_NAME>.recoveryPath` parameter. If you try to restart more than once, the job submitter falls into error state and returns a message such as **Error: The savepoint <path/to/savepoint> was already used. The Job won't be run from there.**

### Completing the Business Automation Insights upgrade

Go back to the upgrade page to continue the Business Automation Insights upgrading procedure.
 * [Upgrading IBM Business Automation Insights](./README_upgrade.md).
