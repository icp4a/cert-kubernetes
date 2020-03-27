# Upgrading from IBM Business Automation Studio 19.0.3 to 20.0.1 

These instructions cover the upgrade of IBM Business Automation Studio from 19.0.3 to 20.0.1.

## Introduction

If you installed Business Automation Studio 19.0.3 and want to continue to use your 19.0.3 applications in Business Automation Studio 20.0.1, you can upgrade your applications from Business Automation Studio 19.0.3 to 20.0.1.

## Step 1: Update the custom resource YAML file for your Business Automation Studio 20.0.1 deployment

Get the custom resource YAML file that you used to deploy Business Automation Studio 19.0.3, and edit it by following these steps:

1. Change the release version from 19.0.3 to 20.0.1.

2. Add `appVersion: 20.0.1` to the `spec` section. See the [sample_min_value.yaml](configuration/sample_min_value.yaml) file.

3. Update the `bastudio_configuration` and `resource_registry_configuration` sections.
 
 * Automatic backup for Resource Registry is recommended. See [Enabling Resource Registry disaster recovery](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.managing/topics/tsk_enabling_disaster_recovery.html) for configuration information.

 * If you just want to update Business Automation Studio with the minimal required values, use the values in the [sample_min_value.yaml](configuration/sample_min_value.yaml) file.
    * Add `admin_user` to the `bastudio_configuration` section.
    * Add `admin_user` to the `playback_server` in the `bastudio_configuration` section.
    * Change the image tags from 19.0.3 to 20.0.1 in all sections.

 * If you want to use the full configuration list and customize the values, update the required values in the `bastudio_configuration` and `resource_registry_configuration` sections in your custom resource YAML file based on your configuration. See the [configuration list](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_bas_params.html) for each parameter.

## Step 2: Update the configuration sections for other deployments

To update the configuration sections for other components, such as User Management Service and IBM Business Automation Navigator, go back to the relevant upgrade page to follow their upgrade documents to update your custom resource YAML file.

Upgrade pages:
   - [Managed OpenShift upgrade page](../platform/roks/upgrade.md)
   - [OpenShift upgrade page](../platform/ocp/upgrade.md)
   - [Certified Kubernetes upgrade page](../platform/k8s/upgrade.md)

