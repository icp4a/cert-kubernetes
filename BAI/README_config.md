# Configuring IBM® Business Automation Insights

These instructions cover the basic configuration of IBM Business Automation Insights.

In order to use Business Automation Insights with other components in the IBM Cloud Pak for Automation you also need to configure them to emit events.

For more information on the IBM Cloud Pak for Automation, see the [IBM Cloud Pak for Automation Knowledge Center](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/welcome/kc_welcome_dba_distrib.html).

## Before you start

If you have not done so, go to the [IBM Cloud Pak for Automation 19.0.x](http://engtest01w.fr.eurolabs.ibm.com:9190/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_preparing_baik8s.html) Knowledge Center and follow the steps to prepare your environment for Business Automation Insights.

This README will summarize a number of the preparation steps found in the Knowledge Center. For more information at each stage refer to the Knowledge Center links provided.

## Step 1: Make a copy of the sample Custom Resource

The IBM Cloud Pak for Automation operator uses a single Custom Resource to install the required Cloud Pak products. These instructions provide an example ICP4ACluster Custom Resource [`configuration/bai-sample-values.yaml`](configuration/bai-sample-values.yaml). You can use this yaml file to customize your Business Automation Insights install, then copy the `bai_configuration` section of the CR yaml to the single ICP4ACluster CR yaml for all Cloud Pak products.

To begin customizing a basic installation first clone this repository and then copy the [`configuration/bai-sample-values.yaml`](configuration/bai-sample-values.yaml) configuration file into a working directory.

## Step 2: Edit the Custom Resource

Open the `bai-sample-values.yaml` ICP4ACluster Custom Resource file in a text/code editor.

There are a number of values you need to customize:

* Change all occurrences of `<DOCKER_REGISTRY>` to the location of the registry hosting the Business Automation Insights Docker images

* Change all occurrences of `<PULL_SECRET>` to the name of the Docker pull secret created above, for example `icp4apull`

* Ensure the `tag` value for all configuration matches the Docker tag used for the Docker images in your repository

### Step 2.1: Customize the Apache Kafka Configuration

#### Step 2.1.1: Apache Kafka connection configuration

To configure Business Automation Insights to interact with your installation of Apache Kafka you need to customize the `bai_configuration.kafka` section of the Custom Resource.

Below is an example of a simple Kafka configuration:

```yaml
    kafka:
      bootstrapServers: "kafka-0.example.com:9092,kafka-1.example.com:9092,kafka-2.example.com:9092"
      securityProtocol: "PLAINTEXT"
```

For advanced Apache Kafka configuration, including security options, refer to the [IBM Business Automation Insights Knowledge Center - Apache Kafka parameters](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_bai_k8s_kafka_params.html).

#### Step 2.1.2: Apache Kafka topic configuration

Business Automation Insights uses a number of Apache Kafka topics. To customize the names of these topics, uncomment and alter the settings below:

```yaml
    settings:
      egress: true
      ingressTopic: ibm-bai-ingress
      egressTopic: ibm-bai-egress
      serviceTopic: ibm-bai-service
```

More information about this can be found in the [IBM Business Automation Insights Knowledge Center - Apache Kafka parameters](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_bai_k8s_kafka_params.html), including an explanation of egress functionality.

### Step 2.2 Persistent Storage
When configuring Business Automation Insights you have a number of options regarding persistent storage.

Below is a summary of the persistent storage used by Business Automation Insights:

| Volume                            | Default volume name                        | Default Storage | Required | Access Mode   | Number of volumes |
| --------------------------------- | ------------------------------------------ | --------------- | -------- | ------------- | ----------------- |
| Flink volume                      | <CR_NAME>-bai-pvc                          | 20Gi            | Yes      | ReadWriteMany | 1                 |
| ElasticSearch Master              | data-<CR_NAME>-ibm-dba-ek-master-_replica_ | 10Gi            | No       | ReadWriteOnce | 1 per replica     |
| ElasticSearch Data                | data-<CR_NAME>-ibm-dba-ek-data-_replica_   | 10Gi            | No       | ReadWriteOnce | 1 per replica     |
| ElasticSearchSnapshot Storage     | <CR_NAME>-es-snapshot-storage-pvc          | 30Gi            | No       | ReadWriteMany | 1                 |

The Flink volume is used by multiple pods for normal operation of Business Automation Insights. For more information on the Business Automation Insights persistent volume configuration see [IBM Business Automation Insights Knowledge Center - Apache Flink parameters](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_bai_k8s_flink_params.html).

If you are using the embedded ElasticSearch stack you can choose to enable persistence for the ElasticSearch nodes (with a volume for each replica of the master and data nodes), and for snapshot storage. For more information on the embedded ElasticSearch volume configuration see [IBM Business Automation Insights Knowledge Center - Elasticsearch parameters](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_bai_k8s_es_params.html)

#### Example configuration using dynamic provisioning

If your cluster has dynamic volume provisioning the example shows a storage configuration (as found in the `bai-sample-values.yaml` file) when persistence is enabled:

```yaml
    persistence:
      useDynamicProvisioning: true

    flinkPv:
      storageClassName: "<RWX_STORAGE_CLASS>"

    ibm-dba-ek:
      elasticsearch:
        data:
          storage:
            persistent: true
            useDynamicProvisioning: true
            storageClass: "<RWO_STORAGE_CLASS>"
          snapshotStorage:
            enabled: true
            useDynamicProvisioning: true
            storageClassName: "<RWX_STORAGE_CLASS>"
```

This configuration creates the four `PersistentVolumeClaim` resources listed with the default configuration. To use dynamic provisioning, change all occurrences of `<RWO_STORAGE_CLASS>` and `<RWX_STORAGE_CLASS>` to the name of the storage classes appropriate for your deployment platform.

> Note: The `bai_configuration.flinkPv.storageClassName` and `bai_configuration.ibm-dba-ek.elasticsearch.data.snapshotStorage.storageClassName` storage classes must be capable of access mode `ReadWriteMany`. Additional configuration may be required on some platforms to create a `ReadWriteMany` capable storage class. `bai_configuration.ibm-dba-ek.elasticsearch.data.storage.storageClass` requires a `ReadWriteOnce` access mode capable storage class, available by default on many cloud platforms.

#### Example configuration using static provisioning

If you want to manually create `PersistentVolume` and `PersistentVolumeClaim` resources use the following template for an example configuration:

```yaml
    persistence:
      useDynamicProvisioning: false

    flinkPv:
      existingClaimName: "<EXISTING_FLINK_PVC>"

    ibm-dba-ek:
      elasticsearch:
        data:
          storage:
            persistent: true
            useDynamicProvisioning: false
            storageClass: "<PV_STORAGE_CLASS>"
          snapshotStorage:
            enabled: true
            useDynamicProvisioning: false
            existingClaimName: "<EXISTING_SNAPSHOT_PVC>"
```

### Step 2.3 Product event processors

By default, no event processor setup pods are started when Business Automation Insights is installed. The event processor setup pods are required in order to configure Business Automation Insights to be able to ingest events from other products in the IBM Cloud Pak for Automation.

Each product has an `install` parameter in the `bai_configuration` Custom Resource section, as shown below:

```yaml
    ingestion:
      install: false
      image:
        repository: <DOCKER_REGISTRY>/bai-ingestion
        tag: "19.0.3"

    adw:
      install: false
      image:
        repository: <DOCKER_REGISTRY>/bai-adw
        tag: "19.0.3"
    
    bpmn:
      install: false
      image:
        repository: <DOCKER_REGISTRY>/bai-bpmn
        tag: "19.0.3"

    bawadv:
      install: false
      image:
        repository: <DOCKER_REGISTRY>/bai-bawadv
        tag: "19.0.3"

    icm:
      install: false
      image:
        repository: <DOCKER_REGISTRY>/bai-icm
        tag: "19.0.3"

    odm:
      install: false
      image:
        repository: <DOCKER_REGISTRY>/bai-odm
        tag: "19.0.3"

    content:
      install: false
      image:
        repository: <DOCKER_REGISTRY>/bai-content
        tag: "19.0.3"
```

For each products that you want to process events from change the `install` parameter to `true`. For example to process events from IBM Operation Decision Manager set `spec.bai_configuration.odm.install` to `true`.

## Step 3: Security configuration

Business Automation Insights requires some additional security configuration.

### Step 3.1: Create security configuration

Use the following template to create a [`BAI/configuration/bai-psp-yaml`](configuration/bai-psp.yaml) file containing the required `PodSecurityPolicy`, `Role`, `RoleBinding` and `ServiceAccount` resources needed by BAI.

**Example bai-psp.yaml**

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  annotations:
    kubernetes.io/description: "This policy is required to allow ibm-dba-ek pods running Elasticsearch to use privileged containers."
  name: <CR_NAME>-bai-psp
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
  name: <CR_NAME>-bai-role
rules:
- apiGroups:
  - extensions
  resourceNames:
  - <CR_NAME>-bai-psp
  resources:
  - podsecuritypolicies
  verbs:
  - use
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <CR_NAME>-bai-psp-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: <CR_NAME>-bai-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: <CR_NAME>-bai-role
subjects:
- kind: ServiceAccount
  name: <CR_NAME>-bai-psp-sa
```

After creating the file, replace all occurrences of `<CR_NAME>` with the name of your ICP4ACluster Custom Resource created in Step 3.

### Step 3.2: Apply the security configuration

To apply the configuration you can use the `kubectl` command line utility:

```bash
kubectl apply -f bai-psp.yaml
```

For RedHat OpenShift, additional policies may be required to enable the `Pod` resources to start containers using the required UIDs. To ensure these containers can start use the `oc` command to add the service accounts to the required `privileged` SCC:

```bash
oc adm policy add-scc-to-user privileged -z <CR_NAME>-bai-psp-sa
oc adm policy add-scc-to-user privileged -z default
```

## Step 4: Complete the installation

Go back to the relevant install or update page to configure other components and complete the deployment with the operator.

Install pages:
   - [Managed OpenShift installation page](../platform/roks/install.md)
   - [OpenShift installation page](../platform/ocp/install.md)
   - [Certified Kubernetes installation page](../platform/k8s/install.md)
