# Install with the Helm chart

This directory includes the [IBM Business Automation Insights Helm Chart](./ibm-business-automation-insights-3.1.0.tgz) and explains how to install it.

## Initializing Helm and installing Tiller

Tiller is a companion to the helm command that runs on your cluster. It receives commands from Helm and communicates directly with the Kubernetes API to create and delete resources.

To install Tiller on your cluster, run:

```sh
helm init
```

To grant Tiller the required cluster-admin permissions to deploy Business Automation Insights, run:
```sh
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```

> **Note:** For clusters where Tiller is already deployed, you only need to initialize the client part:

```sh
helm init --client-only
```

## Installing IBM Business Automation Insights

### Prerequisites

First follow the [Requirements](../README.md#requirements) and [Before you begin](../README.md#before-you-begin).

### Install the Helm chart

To install the IBM Business Automation Helm chart, you need to decide on a release name and use this name when you run the helm command, as follows:

```sh
helm install ibm-business-automation-insights-3.1.0.tgz --name <RELEASE_NAME> -n <NAMESPACE> -f values.yaml
```

To override the default Business Automation Insights configuration, you must provide a `values.yaml` file with your custom configuration.

Configuration properties and default values are described in the [Business Automation Insights README.md](../README.md#configuration-parameters). An example `values.yaml` is provided [here](../configuration/sample-values.yaml).

### Install the event emitters

You must install the emitters into your IBM Digital Business Automation products to be able to emit events from the products to Business Automation Insights.

You must only install emitters for the products that you enabled during Business Automation Insights installation process. In the provided sample, only the BPMN job is installed, and so only the BPMN emitter must be installed.

Refer to the [Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSYHZ8_18.0.x/com.ibm.dba.bai/topics/con_bai_top_bmpn_events.html) for instructions.

## Updating the Helm chart

Check the Business Automation Insights [Updating](../README.md#updating) section for prerequisites to the update.

After initial installation, you can update the chart configuration as follows:

```sh
helm upgrade <RELEASE_NAME> ibm-business-automation-insights-3.1.0.tgz -n <NAMESPACE> --reuse-values --set a.property=newvalue[,other.property2=newvalue2]
```

## Uninstalling the Helm chart

Run the following command to uninstall the Helm chart:

```sh
helm delete <RELEASE_NAME>
```
