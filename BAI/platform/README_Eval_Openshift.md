# Install IBM Business Automation Insights for developers on Red Hat OpenShift 

IBM® Business Automation Insights collects and continuously feeds operational data from IBM Automation Platform for Digital Business on Cloud to data lakes to provide users with a 360-degree view of operations and to enable machine learning from historical data.

By downloading and installing this no-charge Developer Edition of IBM Business Automation Insights, you can benefit from the following capabilities:
   * Collect data from IBM Business Automation Workflow, Operational Decision Manager, IBM FileNet® Content Manager, and BAIW, and store it on Elasticsearch.
   * Visualize the data through predefined or user-configured dashboards in Kibana.

See the following license section for restrictions on the use of this product: http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-ASAY-BEEGE4

Note: You can use IBM Business Automation Insights Developer Edition only for non-production environments, primarily to try out IBM Business Automation Insights with your own event types and business data. You can connect your existing on-premise IBM Business Automation Workflow non-production systems to IBM Business Automation Insights Developer Edition.

Note: You can also install Developer Edition on Minikube. For more information, see https://github.com/icp4a/cert-kubernetes/blob/19.0.2/BAI/platform/minikube/README.md.

## Step 1: Prerequisites

Make sure to go through the Prerequisites sections that are documented at https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BAI/README.md:

   * [Requirements](https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BAI/README.md#requirements)
   * [Connect to the cluster](https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BAI/README.md#connect-to-the-cluster)
   * [Upload the images](https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BAI/README.md#upload-the-images) This step must be skipped for the Developer Edition because images are pulled from Docker Hub public registry.
   * [Configure the storage](https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BAI/README.md#configure-the-storage). Note that the Developer Edition embeds Elasticsearch.
   * [Configure the image policy](https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BAI/README.md#configure-the-image-policy) This step must be skipped for the Developer Edition.
   * [PodSecurityPolicy Requirements](https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BAI/README.md#podsecuritypolicy-requirements)
   * [Red Hat OpenShift SecurityContextConstraints Requirements](https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BAI/README.md#red-hat-openshift-securitycontextconstraints-requirements)

Note: When the `kubectl create namespace <NAMESPACE>` command is executed, an associated Kubernetes namespace is created with the project name. In subsequent commands, replace the `<NAMESPACE>` placeholder with your actual project name.

## Step 2: Install an IBM Business Automation Insights Developer Edition release


1. Create a `values.yaml` file.

    a. Configure the connection between your Kafka tool and Business Automation Insights:

    In the `values.yaml` file, configure the connection to Kafka.

    For example, for a Kafka without authentication:

    ```yaml
    kafka:
      bootstrapServers: "kafka-hostname:9092"
      securityProtocol: "PLAINTEXT"
      propertiesConfigMap: ""
    ```

	IBM Business Automation Insights creates Kafka topics if they do not exist. Default Kafka topic names are documented at [General configuration](https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BAI/README.md#general-configuration).
	
    b. Enable event processing.

    For example, to install only ODM event processing, edit your `values.yaml` file as follows.

    ```yaml
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
      
    baiw:
      install: false
    ```
    
2. Install the release.

    a. Add the IBM Charts repository
    ```console
     $ helm repo add ibm-charts https://raw.githubusercontent.com/IBM/charts/master/repo/stable
     $ helm repo update
    ```
    b. Run the helm install command

    ```console
     $ helm install --namespace <NAMESPACE> --name <RELEASE_NAME> ibm-charts/ibm-business-automation-insights-dev -f ./values.yaml --version=3.2.0
    ```

## Step 3: Verify that IBM Business Automation Insights deployment is running

IBM Business Automation Insights is correctly deployed when all the jobs are completed, all the pods are running and ready, and all the services are reachable.

- Monitor the status of the jobs and check that all of them are marked as successful by executing the following command:
```sh
oc get jobs -n <NAMESPACE>
```
- Monitor the status of the pods and check that all of them are in `Running` mode and with all their containers `Ready` (for example, 2/2) by executing the following command:
```sh
oc get pods -n <NAMESPACE>
```

## To uninstall the release

To uninstall and delete the release from the Helm CLI, use the following command:

```console
$ helm delete <RELEASE_NAME> --purge
```
