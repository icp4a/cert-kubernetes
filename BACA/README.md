# Deploy Business Automation Content Analyzer

IBM Business Automation Content Analyzer offers the power of intelligent capture with the flexibility of an API that enables you to extend the value of your core enterprise content management (ECM) technology stack. Advanced AI more accurately classifies data and can be configurable in minutes, instead of weeks.

For more information, see [IBM Business Automation Content Analyzer: Details](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.offerings/topics/con_baca.html)

## Requirements and Prerequisites

Perform the following tasks to prepare to deploy your Business Automation Content Analyzer images on Kubernetes:

- Download the PPA. Refer to the top repository [readme](../README.md) to find instructions on how to push and tag the product container images to your Docker registry.

- Prepare environment for IBM Business Automation Content Analyzer. See [Preparing to install automation containers on Kubernetes](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_bacak8s.html).  These procedures include setting up databases, LDAP, storage, and configuration files that are required for use and operation.   

- Several utility scripts are provided in this git repository to assist in the creation of databases, PVCs, secrets, etc. regardless of whether you are installing via the helm chart or generic yaml method. See the detail information about the utility in [Configuration Readme](configuration/README.md).  

## Deploying

You can deploy your container images with the following methods:
- [Using Helm charts](helm-charts/README.md)
- [Using Kubernetes YAML](k8s-yaml/README.md)

## Completing post deployment configuration

After you deploy your container images, you might need to perform some required and some optional steps to get your Business Automation Content Analyzer environment up and running. For detail instructions, see [Completing post deployment tasks for Business Automation Content Analyzer](docs/post-deployment.md)
