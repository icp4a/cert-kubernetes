# Configuring IBM Business Automation Application Engine (App Engine) 20.0.1 

These instructions cover the basic installation and configuration of IBM Business Automation Application Engine (App Engine).

## Table of contents
- [App Engine Component Details](#App-engine-component-details)
- [Prerequisites](#Prerequisites)
- [Resources Required](#Resources-required)
- [Step 1: Preparing to install App Engine for Production](#Step-1-preparing-to-install-app-engine-for-production)
- [Step 2: Configuring Redis for App Engine (Optional)](#Step-2-configuring-redis-for-app-Engine-optional)
- [Step 3: Implementing storage (Optional)](#Step-3-implementing-storage-optional)
- [Step 4: Configuring the custom resource YAML file for your App Engine deployment](#Step-4-configuring-the-custom-resource-YAML-file-for-your-app-engine-deployment)
- [Step 5: Completing the installation](#Step-5-completing-the-installation)
- [Limitations](#Limitations)

## Introduction

This installation deploys the App Engine, a user interface service tier to run applications that are built by IBM Business Automation Application Designer (App Designer). 

## App Engine Component Details

This component deploys several services and components.

In the standard configuration, it includes these components:

* IBM Resource Registry component
* IBM Business Automation Application Engine (App Engine) component

To support those components, a standard installation generates:

  * 3 or more ConfigMaps that manage the configuration of App Engine, depending on the customized configuration
  * 1 or more deployment running App Engine, depending on the customized configuration
  * 4 or more pods for Resource Registry, depending on the customized configuration
  * 1 service account with related role and role binding
  * 3 secrets to get access during operator installation
  * 3 services and optionally an Ingress or Route (OpenShift) to route the traffic to the App Engine

## Prerequisites

  * [Remote Dictionary Server (Redis)](http://download.redis.io/releases/)
  * [User Management Service](../UMS/README_config.md)
  * Resource Registry, which is included in the App Engine configuration. If you already configured Resource Registry through another component, you need not install it again. 

## Resources Required

Follow the OpenShift instructions in [Planning Your Installation 3.11](https://docs.openshift.com/container-platform/3.11/install/index.html#single-master-single-box) or [Planning your Installation 4.2](https://docs.openshift.com/container-platform/4.2/welcome/index.html). Then check the required resources in [System and Environment Requirements on OCP 3.11](https://docs.openshift.com/container-platform/3.11/install/prerequisites.html) or [System and Environment Requirements on OCP 4.2](https://docs.openshift.com/container-platform/4.2/architecture/architecture.html) and set up your environment.

| Component name | Container | CPU | Memory |
| --- | --- | --- | --- |
| App Engine | App Engine container | 1 | 1Gi |
| App Engine | Init containers | 200m | 128Mi |
| Resource Registry | Resource Registry container | 200m | 256Mi |
| Resource Registry | Init containers | 100m | 128Mi |


## Step 1: Preparing to install App Engine for Production

Besides the common steps to set up the operator environment, you must do the following steps before you install App Engine.

* Create the App Engine database. See [Creating the database](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_aeprep_db.html).
* Create the required secrets. See [Creating secrets to protect sensitive configuration data](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_aeprep_data.html). 

## Step 2: Configuring Redis for App Engine (Optional)

You can configure App Engine with Remote Dictionary Server (Redis) to provide more reliable service. See [Configuring App Engine with Redis](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_aeprep_redis.html).
 
## Step 3: Implementing storage (Optional)

You can optionally add your own persistent volume (PV) and persistent volume claim (PVC) if you want to use your own JDBC driver or you want Resource Registry to be backed up automatically. The minimum supported size is 1 GB. For instructions, see [Optional: Implementing storage](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_aeprep_storage.html).


## Step 4: Configuring the custom resource YAML file for your App Engine deployment

1. Make sure that you've set the configuration parameters for the [User Management Service](../UMS/README_config.md) in your copy of the template custom resource YAML file. 

2. Edit your copy of the template custom resource YAML file and make the following updates. After completing those updates, if you need to install other components, please go to [Step 5](README_config.md#step-5-completing-the-installation) and do the configuration for those components, using the same YAML file.  

   a. Uncomment and update the `shared_configuration` section if you haven't done it already.
   
   b. Update the `application_engine_configuration` and `resource_registry_configuration` sections.
     * Automatic backup for Resource Registry is recommended. See [Enabling Resource Registry disaster recovery](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.managing/topics/tsk_enabling_disaster_recovery.html) for configuration information.
     
     * If you just want to install App Engine with the minimal required values, replace the contents of `application_engine_configuration` and `resource_registry_configuration` in your copy of the template custom resource YAML file with the values from the [sample_min_value.yaml](configuration/sample_min_value.yaml) file.

    * If you want to use the full configuration list and customize the values, update the required values in `application_engine_configuration` and `resource_registry_configuration` in your copy of the template custom resource YAML file based on your configuration.
   
### Configuration
If you want to customize your custom resource YAML file, refer to the [configuration list](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_ae_params.html) for each parameter.

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

* After you deploy the App Engine, you can't change App Engine admin user. 

* Because of a Node.js server limitation, App Engine trusts only root CA. If an external service is used and signed with another root CA, you must add the root CA as trusted instead of the service certificate.

  * The certificate can be self-signed, or signed by a well-known root CA.
  * If you're using a depth zero self-signed certificate, it must be listed as a trusted certificate.
  * If you're using a certificate signed by a self-signed root CA, the self-signed CA must be in the trusted list. Using a leaf certificate in the trusted list is not supported.
  * If you're adding the root CA of two or more external services to the App Engine trust list, you can't use the same common name for those root CAs.

* The App Engine supports only the IBM DB2 database.

* Resource Registry limitation

  Because of the design of etcd, it's recommended that you don't change the replica size after you create the Resource Registry cluster to prevent data loss. If you must set the replica size, set it to an odd number. If you reduce the pod size, the pods are destroyed one by one slowly to prevent data loss or the cluster getting out of sync.
  * If you update the Resource Registry admin secret to change the username or password, first delete the <instance_name>-dba-rr-<random_value> pods to cause Resource Registry to enable the updates. Alternatively, you can enable the update manually with etcd commands.
  * If you update the Resource Registry configurations in the icp4acluster custom resource instance. the update might not affect the Resource Registry pod directly. It will affect the newly created pods when you increase the number of replicas.
