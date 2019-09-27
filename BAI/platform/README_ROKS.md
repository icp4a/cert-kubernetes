# Install IBM Business Automation Insights for production on Red Hat OpenShift on IBM Cloud

## Before you begin: Create a cluster and get access to the container images

Before you run any installation command, make sure that you have created the IBM Cloud cluster and prepared your own environment. You must also create a pull secret to be able to pull your images from a registry.

For more information, see [Installing containers on Red Hat OpenShift by using CLIs](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_ROKS.html).

## Step 1: Install a Business Automation Insights release

> **Tip**: If you activate Business Automation Insights persistence, you need to specify persistent volumes (PV) to install. PV represents an underlying storage capacity in the infrastructure. Before you can install Business Automation Insights, you must create two PVs with access mode set to ReadWriteOnce and storage capacity of 10Gi or more for Elasticsearch storage, and one PV with access mode set to ReadWriteMany and storage capacity of 10Gi or more for Apache Flink storage. You create a PV in the administration console or in a YAML file (.yml or. yaml file name extension).

1. Prerequisites:

    * Install a [Kafka distribution](https://cwiki.apache.org/confluence/display/KAFKA/Ecosystem) and make sure it is accessible from the Managed OpenShift cluster.

2. Get the Business Automation Insights Helm charts:

    a. Download the charts [ibm-business-automation-insights-3.2.0.tgz](../helm-charts/ibm-business-automation-insights-3.2.0.tgz)

3. Apply the security policy:

    a. Create a file named, for example, 'bai-psp.yaml', based on this PSP template, and set the values of the <RELEASE_NAME> and <NAMESPACE> placeholders.
    * Replace `<RELASE_NAME>` with the name of the Business Automation Insights release.
    * Replace `<NAMESPACE>` with the name of the namespace that is associated with your OpenShift project.

    ```console
    apiVersion: policy/v1beta1
    kind: PodSecurityPolicy
    metadata:
      annotations:
        kubernetes.io/description: "This policy is required to allow ibm-dba-ek pods running Elasticsearch to use privileged containers."
      name: <RELEASE_NAME>-bai-psp
    spec:
      privileged: true
      runAsUser:
        rule: RunAsAny
      seLinux:
        rule: RunAsAny
      supplementalGroups:
        rule: RunAsAny
      fsGroup:
        rule: RunAsAny
      volumes:
      - '*'
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: <RELEASE_NAME>-bai-role
      namespace: <NAMESPACE>
    rules:
    - apiGroups:
      - extensions
      resourceNames:
      - <RELEASE_NAME>-bai-psp
      resources:
      - podsecuritypolicies
      verbs:
      - use
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: <RELEASE_NAME>-bai-psp-sa
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: <RELEASE_NAME>-bai-rolebinding
      namespace: <NAMESPACE>
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: <RELEASE_NAME>-bai-role
    subjects:
    - kind: ServiceAccount
      name: <RELEASE_NAME>-bai-psp-sa
      namespace: <NAMESPACE>
    ```

    b. Apply this policy.

    ```console
    $ kubectl apply -f bai-psp.yaml -n <NAMESPACE>
    ```

4. Grant "ibm-privileged-scc" privileges to the service account.

    ```console
    oc adm policy add-scc-to-user ibm-privileged-scc -z <RELEASE_NAME>-bai-psp-sa -n <NAMESPACE>
    ```

5. Create a `values.yaml` file.
    
    a. Pull image secrets
    
    BAI images are available in IBM Docker registry by using a pull secret name.  
    Replace the <MY_PULL_SECRET> placeholder with the secret that you 
    created in [Before you begin](#before-you-begin-create-a-cluster-and-get-access-to-the-container-images). Then, add the following parameters in the `values.yaml` file.
    
    ```
   imageCredentials:
         imagePullSecret: <MY_PULL_SECRET>

   ibm-dba-ek:
     image:
       imagePullSecret: <MY_PULL_SECRET>
    ```
    
    b. Activate persistence.

    The following example uses dynamic provisioning and the `ibmc-file-retain-gold` storage class. For Elasticsearch volumes, use the fastest possible storage class.

    ```console
    persistence:
      useDynamicProvisioning: true

    flinkPv:
      storageClassName: "ibmc-file-retain-gold"

    ibm-dba-ek:
      elasticsearch:
        data:
          storage:
            persistent: true
            useDynamicProvisioning: true
            storageClass: "ibmc-file-retain-gold"
          snapshotStorage:
            enabled: true
            useDynamicProvisioning: true
            storageClass: "ibmc-file-retain-gold"
    ```

    c. Configure the connection between your Kafka tool and Business Automation Insights.

    In the `values.yaml` file, configure the connection to Kafka.

    For example, for a Kafka without authentication:

    ```console
    kafka:
      bootstrapServers: "kafka-hostname:9092"
      securityProtocol: "PLAINTEXT"
      propertiesConfigMap: ""
    ```

    d. Enable init of the Flink storage directory.

    When deploying IBM Business Automation Insights on IBM Cloud, the Flink init container needs to be run as privileged, such that it can
    change the ownership and permissions of its storage directory. For details, see https://cloud.ibm.com/docs/containers?topic=containers-cs_troubleshoot_storage#file_app_failures
    and https://cloud.ibm.com/docs/containers?topic=containers-cs_troubleshoot_storage#cs_storage_nonroot. To enable initialization
    of the Flink storage directory, add `flink.initStorageDirectory: true` in your `values.yaml`.

    ```console
    flink:
      initStorageDirectory: true
    ```

    e. Enable event processing.

    For example, to install only ODM event processing, edit your `values.yaml` file as follows.

    ```console
    bpmn:
      install: false

    icm:
      install: false

    odm:
      install: true

    content:
      install: false

    bawadv:
      install: false
    ```
    
    f. Configure event ingestion in HDFS.
    
    By default, events are ingested in HDFS in a dedicated bucket which must be created beforehand with appropriate permissions. 
    Indicate the path to the HDFS bucket by using the `flink.storageBucketUrl` parameter in your `values.yaml` file. 
    Replace the placeholders <HADOOP_HOST_OR_IP> and <BUCKET_PATH> with the actual values.
    
    ```console
    flink:
      storageBucketUrl: "hdfs://<HADOOP_HOST_OR_IP>/<BUCKET_PATH>"
    
    ingestion:
      install: true  
    ```
 
    For more information about HDFS configuration, see [Preparing to use HDFS](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.bai/topics/tsk_bai_config_hdfs_storage.html).
    
    To disable event ingestion, edit your `values.yaml` file as follows.
     
    ```console
    ingestion:
      install: false  
    ```
      

10. Install the release.

    ```console
    $ helm install --namespace <NAMESPACE> --name <RELEASE_NAME> <PATH_TO>/ibm-business-automation-insights-3.2.0.tgz -f ./values.yaml
    ```

## Step 3: Verify that the Business Automation Insights deployment is running

1. Monitor the Business Automation Insights pods until they show the *Running* or *Completed* STATUS.

    ```console
    $ while oc get pods  | grep -E "(Running|Completed|STATUS)"; do sleep 5; done
    ```

2. Expose the Kibana service to your users by using Openshift routes.

    ```console
    $ oc create route passthrough --service=<RELEASE_NAME>-ibm-dba-ek-kibana -n <NAMESPACE>
    ```

   > **Note**: For more information, refer to the [Openshift documentation](https://docs.openshift.com/container-platform/3.11/dev_guide/routes.html).

    The Kibana URL is available in the 'Routes' section of the Openshift console.

## To uninstall the release

To uninstall and delete the release from the Helm CLI, use the following command.

```console
$ helm delete <RELEASE_NAME> --purge
```
