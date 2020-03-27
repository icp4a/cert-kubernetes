# Configuring IBM Business Automation Studio 20.0.1 

These instructions cover the basic installation and configuration of IBM Business Automation Studio.

## Table of contents
 - [Business Automation Studio Component Details](#Business-Automation-Studio-Component-Details)
 - [Prerequisites](#Prerequisites)
 - [Resources Required](#Resources-Required)
 - [Step 1: Preparing to install Business Automation Studio for Production](#Step-1-Preparing-to-install-Business-Automation-Studio-for-Production)
 - [Step 2: Configuring Redis for App Engine Playback Server (Optional)](#Step-2-Configuring-Redis-for-App-Engine-Playback-Server-Optional)
 - [Step 3: Implementing storage (Optional)](#Step-3-implementing-storage-optional)
 - [Step 4: Configuring the custom resource YAML file for your Business Automation Studio deployment](#Step-4-Configuring-the-custom-resource-YAML-file-for-your-Business-Automation-Studio-deployment)
 - [Step 5: Completing the installation](#Step-5-Completing-the-installation)
 - [Limitations](#Limitations)
 
## Introduction

This installation deploys a Business Automation Studio environment, the single authoring and development environment for the IBM Cloud Pak for Automation platform, where you can go to author business services, applications, and digital workers.

## Business Automation Studio Component Details

This component deploys several services and components.

In the standard configuration, it includes these components:

* IBM Business Automation Studio (BAStudio) component
* IBM Resource Registry component
* IBM Business Automation Application Engine (App Engine) playback server component

Notes: 
   - The IBM Business Automation Application Engine (App Engine) playback server component is designed to provide a playback environment for application development use. The App Engine installed as a playback server doesn't contain all the features needed by the App Engine in a production environment and can't be used as a production App Engine server.
   - For a production environment, deploy the App Engine following the instructions in [Application Engine Configuration](../AAE/README_config.md).
  
To support those components, a standard installation generates:

  * 5 ConfigMaps that manage the configuration of Business Automation Studio server
  * 2 deployments running the Business Automation Studio server and App Engine playback server
  * 1 StatefulSet running JMS
  * 4 or more jobs for Business Automation Studio and Resource Registry
  * 5 secrets to get access
  * 5 services to route the traffic to Business Automation Studio server

## Prerequisites

  * [User Management Service](../UMS/README_config.md) 
  * Resource Registry, which is included in the Business Automation Studio configuration. If you already configured Resource Registry through another component, you need not install it again.
  
## Resources Required

Follow the OpenShift instructions in [Planning Your Installation 3.11](https://docs.openshift.com/container-platform/3.11/install/index.html#single-master-single-box) or [Planning your Installation 4.2](https://docs.openshift.com/container-platform/4.2/welcome/index.html). Then check the required resources in [System and Environment Requirements on OCP 3.11](https://docs.openshift.com/container-platform/3.11/install/prerequisites.html) or [System and Environment Requirements on OCP 4.2](https://docs.openshift.com/container-platform/4.2/architecture/architecture.html) and set up your environment.

| Component name | Container | CPU | Memory |
| --- | --- | --- | --- |
| BAStudio | BAStudio container | 2 | 2Gi |
| BAStudio | Init containers    | 200m | 256Mi |
| BAStudio | JMS containers     | 500m | 512Mi |
| Resource Registry | Resource Registry container   | 200m | 256Mi |
| Resource Registry | Init containers               | 100m | 128Mi |
| App Engine Playback Server | App Engine container | 1    | 1Gi   |
| App Engine Playback Server | Init containers      | 200m | 128Mi |
  
## Step 1: Preparing to install Business Automation Studio for Production
 
Besides the common steps to set up the operator environment, you must do the following steps before you install Business Automation Studio.

* Create the Business Automation Studio and App Engine playback server databases. See [Creating databases](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_basprep_db.html). 
* Create the required secrets. See [Protecting sensitive configuration data](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_basprep_data.html).  

## Step 2: Configuring Redis for App Engine Playback Server (Optional)

The default replica size of the App Engine playback server is 1. You can have only one App Engine pod because it's a playback server for application development use. If you need the replica size to be more than 1 or you enabled the Horizontal Pod Autoscaler for the playback server, you must configure the App Engine playback server with Remote Dictionary Server (Redis). For instructions, see [Optional: Configuring App Engine playback server with Redis](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_basprep_redis.html). 

## Step 3: Implementing storage (Optional)

You can optionally add your own persistent volume (PV) and persistent volume claim (PVC) if you want to use your own JDBC driver or you want Resource Registry to be backed up automatically. The minimum supported size is 1 GB. For instructions see [Optional: Implementing storage](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_basprep_storage.html). 
  
  
## Step 4: Configuring the custom resource YAML file for your Business Automation Studio deployment

   1. Make sure that you've set the configuration parameters for [User Management Service](../UMS/README_config.md) in your copy of the template custom resource YAML file.
   2. Edit your copy of the template custom resource YAML file and make the following updates. After completing those updates, if you need to install other components, go to [Step 5](README_config.md#step-5-Completing-the-installation) and do the configuration for those components, using the same YAML file.
   
      a. Uncomment and update the shared_configuration section if you haven't done it already.

      b. Update the `bastudio_configuration` and `resource_registry_configuration` sections.
         * Automatic backup for Resource Registry is recommended. See [Enabling Resource Registry disaster recovery](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.managing/topics/tsk_enabling_disaster_recovery.html) for configuration information.
         * If you just want to install BAStudio with the minimal required values, replace the contents of `bastudio_configuration` and `resource_registry_configuration` in your copy of the template custom resource YAML file with the values from the [sample_min_value.yaml](configuration/sample_min_value.yaml) file.
         * If you want to use the full configuration list and customize the values, update the required values in `bastudio_configuration` and `resource_registry_configuration` in your copy of the template custom resource YAML file based on your configuration.

Note: The hostname must be less than 64 characters. Use a wildcard DNS (https://nip.io/) if the hostname is too long. For example, instead of:

```
 resource_registry_configuration:
   admin_secret_name: op-bas-rr-admin-secret
   hostname: hostname: rr-{{ meta.namespace }.I-have-a-very-long-hostname-which-exceeds-64-characters.cloud.com
```

the hostname can use a wildcard:

```
 resource_registry_configuration:
   admin_secret_name: op-bas-rr-admin-secret
   hostname: rr-{{ meta.namespace }.<Public IP of Hostname>.nip.io
```   

### Configuration 

If you want to customize your custom resource YAML file, refer to the [configuration list](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_bas_params.html) for each parameter.

## Step 5: Completing the installation

Go back to the relevant installation or update page to configure other components and complete the deployment with the operator.

Installation pages:
   - [Managed OpenShift installation page](../platform/roks/install.md)
   - [OpenShift installation page](../platform/ocp/install.md)
   - [Certified Kubernetes installation page](../platform/k8s/install.md)

Update pages:
   - [Managed OpenShift installation page](../platform/roks/update.md)
   - [OpenShift installation page](../platform/ocp/update.md)
   - [Certified Kubernetes installation page](../platform/k8s/update.md)
   
   
## Limitations

* After you deploy Business Automation Studio, you can't change the Business Automation Studio or App Engine playback server admin user.

* Because of a node.js server limitation, App Engine playback server image trusts only root CA. If an external service is used and signed with another root CA, you must add the root CA as trusted instead of the service certificate.

  * The certificate can be self-signed, or signed by a well-known root CA.
  * If you're using a depth zero self-signed certificate, it must be listed as a trusted certificate.
  * If you're using a certificate signed by a self-signed root CA, the self-signed root CA must be in the trusted list. Using a leaf certificate in the trusted list is not supported.
  * If you're adding the root CA of two or more external services to the App Engine trust list, you can't use the same common name for those root CAs.

* The Business Automation Studio components support only the IBM DB2 database.

* The App Engine playback server supports only the IBM DB2 database.

* The JMS statefulset doesn't support scale. You must keep the replica size of the JMS statefulset at 1.

* Resource Registry limitation

  Because of the design of etcd, it's recommended that you don't change the replica size after you create the Resource Registry cluster to prevent data loss. If you must set the replica size, set it to an odd number. If you reduce the pod size, the pods are destroyed one by one slowly to prevent data loss or the cluster getting out of sync.

  * If you update the Resource Registry admin secret to change the username or password, first delete the <instance_name>-dba-rr-<random_value> pods to cause Resource Registry to enable the updates. Alternatively, you can enable the update manually with etcd commands.
  * If you update the Resource Registry configurations in the icp4acluster custom resource instance. the update might not affect the Resource Registry pod directly. It will affect the newly created pods when you increase the number of replicas.
