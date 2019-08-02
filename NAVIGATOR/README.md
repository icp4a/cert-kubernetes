# Deploy Business Automation Navigator

IBM® Business Automation Navigator provides a console to work with content from multiple content servers. The console enables teams to view their documents, folders, and searches in ways that help them to complete their tasks.

You can use IBM Business Automation Navigator with IBM FileNet Content Manager to accomplish a wide range of business needs:
- Browse for content that is stored in a repository.
- Search for content by running a text search.
- Save document, folders, and other content as favorites.
- Edit documents.
- Add documents to content servers.
- Organize documents by creating folders and adding content to the folders.
- Use the version control rules that are set on the repository.
- Create teamspaces to provide a focused view of the content and objects in the repository.

For more information see [Business Automation Navigator in the Knowledge Center](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.offerings/topics/con_ban.html)

## Requirements and Prerequisites

Perform the following tasks to prepare to deploy your Business Automation Navigator images on Kubernetes:

- Prepare your Kubernetes environment. See [Preparing to install automation containers on Kubernetes](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_k8s.html)

- Download the PPA. Refer to the top repository [readme](../README.md) to find instructions on how to push and tag the product container images to your Docker registry.

- Prepare your Business Automation Navigator environment. These procedures include setting up databases, LDAP, storage, and configuration files that are required for use and operation. If you plan to use the YAML file method, you also create YAML files that include the applicable parameter values for your deployment. You must complete all of the [preparation steps for Business Automation Navigator](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_bank8s.html) before you are ready to deploy the container images. 


## Deploying

On Red Hat OpenShift on IBM Cloud, use the following information to deploy your container images:

- [Deploying on Red Hat OpenShift on IBM Cloud](platform/README_Eval_ROKS.md)

On other certified Kubernetes platforms, you can deploy your container images with the following methods:

- [Using Helm charts](helm-charts/README.md)
- [Using Kubernetes YAML](k8s-yaml/README.md)

## Completing post deployment configuration

After you deploy your container images, you perform some required and some optional steps to get your Business Automation Navigator environment up and running. For detailed instructions, see [Configuring IBM Business Automation Navigator in a container environment](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_18.0.x/com.ibm.dba.install/k8s_topics/tsk_ecmconfigbank8s.html).
