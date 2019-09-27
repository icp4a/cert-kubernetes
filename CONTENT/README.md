# Deploy FileNet Content Manager

IBM® FileNet® Content Manager V5.5 digitizes content and manages the content lifecycle by enabling users to focus on their work and collaborate within the enterprise and with external business partners.

IBM FileNet Content Manager offers enterprise-level scalability and flexibility to handle the most demanding content challenges, the most complex business processes, and integration to all your existing systems. FileNet P8 is a reliable, scalable, and highly available enterprise platform that enables you to capture, store, manage, secure, and process information to increase operational efficiency and lower total cost of ownership. FileNet P8 enables you to streamline and automate business processes, access and manage all forms of content, and automate records management to help meet compliance needs.

For more information see [FileNet Content Manager in the Knowledge Center](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.offerings/topics/con_cm.html)

## Requirements and Prerequisites

Perform the following tasks to prepare to deploy your FileNet Content Manager images on Kubernetes:

- Prepare your Kubernetes environment. See [Preparing to install automation containers on Kubernetes](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_k8s.html)

- Download the PPA. Refer to the top repository [readme](../README.md) to find instructions on how to push and tag the product container images to your Docker registry.

- Prepare your FileNet Content Manager environment. These procedures include setting up databases, LDAP, storage, and configuration files that are required for use and operation. If you plan to use the YAML file method, you also create YAML files that include the applicable parameter values for your deployment. You must complete all of the [preparation steps for FileNet Content Manager](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_ecmk8s.html) before you are ready to deploy the container images. 

- If you want to deploy additional optional containers, prepare the requirements that are specific to those containers. For details see the following information:
  - [Configuring external share for containers](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_ecmexternalsharek8s.html)
  - [Technology Preview: Getting started with the Content Services GraphQL API](http://www.ibm.com/support/docview.wss?uid=ibm10883630)

## Deploying

You can deploy your container images with the following methods:

- [Using Helm charts](helm-charts/README.md)
- [Using Kubernetes YAML](k8s-yaml/README.md)

## Completing post deployment configuration

After you deploy your container images, you perform some required and some optional steps to get your FileNet Content Manager environment up and running. For detailed instructions, see [Completing post deployment tasks for IBM FileNet Content Manager](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_deploy_postecmdeployk8s.html)
