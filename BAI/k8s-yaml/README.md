# Install with Kubernetes YAML

This directory explains how to install IBM Business Automation Insights without the Helm server (Tiller).

## Initializing Helm

Initialize the Helm client-side as follows:

```sh
helm init --client-only
```

## Installing IBM Business Automation Insights

### Prerequisites

First follow the [Requirements](../README.md#requirements) and [Before you begin](../README.md#before-you-begin).

### Generate the Kubernetes YAML

To install IBM Business Automation Insights, generate the Kubernetes YAML files as follows:

```sh
mkdir yaml-files
helm template ibm-business-automation-insights-3.0.0.tgz --name <your-release> --output-dir yaml-files -f values.yaml
```

To override the default configuration, you must provide a `values.yaml` file that contains your custom configuration.

Configuration properties and default values are described in the [Business Automation Insights README.md](../README.md#configuration-parameters). An example `values.yaml` is provided [here](../configuration/sample-values.yaml).

### Install the Kubernetes YAML

```sh
kubectl apply -f ./yaml-files/ibm-business-automation-insights/templates -n bai && \
kubectl apply -f ./yaml-files/ibm-business-automation-insights/charts/ibm-dba-ek/templates -n bai
```

### Install the event emitters

You must install the emitters into your IBM Digital Business Automation products to be able to emit events from the products to Business Automation Insights.

You must only install emitters for the products that you enabled during Business Automation Insights installation process. In the provided sample, only the BPMN job is installed, and so only the BPMN emitter must be installed.

Refer to the [Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSYHZ8_18.0.x/com.ibm.dba.bai/topics/con_bai_top_bmpn_events.html) for instructions.


## Updating IBM Business Automation Insights

Check the Business Automation Insights [Updating](../README.md#updating) section for prerequisites to the update.

After initial installation, you can update the deployment by following the same steps but passing a different `values.yaml`

## Uninstalling IBM Business Automation Insights

```sh
kubectl delete -f ./yaml-files/ibm-business-automation-insights/templates -n bai && \
kubectl delete -f ./yaml-files/ibm-business-automation-insights/charts/ibm-dba-ek/templates -n bai
```
