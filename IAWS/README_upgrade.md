# Upgrading from IBM Automation Workstream Services 19.0.3 to 20.0.1

These instructions cover the upgrade of IBM Automation Workstream Services from 19.0.3 to 20.0.1.

## Introduction

If you installed Automation Workstream Services 19.0.3 and want to continue to use your 19.0.3 applications in Automation Workstream Services 20.0.1, you can upgrade your applications from Automation Workstream Services 19.0.3 to 20.0.1.

## Step 1: Remove labels

You must remove the `release` label from the `<CR_NAME>-ibm-pfs-dbareg` Deployment and the `<CR_NAME>-ibm-pfs-elasticsearch` Statefulset. To remove these labels, run the following commands:

```sh
$ oc label deploy <CR_NAME>-ibm-pfs-dbareg release-
$ oc label sts <CR_NAME>-ibm-pfs-elasticsearch release-
```

**Note:** <CR_NAME> is the name you set as the `metadata.name` in your 19.0.3 custom resource file.

## Step 2: Update the custom resource YAML file for your Automation Workstream Services 20.0.1 deployment

Get the custom resource YAML file that you used to deploy Automation Workstream Services 19.0.3, and edit it by following these steps: 

1. Change the release version from 19.0.3 to 20.0.1.

2. Add `appVersion: 20.0.1` to the `spec` section. See the [sample_min_value.yaml](configuration/sample_min_value.yaml) file.

3. Update the `iaws_configuration` and `pfs_configuration` sections.

 * If you just want to update Automation Workstream Services with the minimal required values, use the values in the [sample_min_value.yaml](configuration/sample_min_value.yaml) file.
    * Add `admin_user` to the `iaws_configuration[x].iaws_server` sections
    * Change `iaws_configuration[x].wfs` to `iaws_configuration[x].iaws_server`
    * Change `iaws_configuration[x].wfs.workflow_server_secret` to `iaws_configuration[x].iaws_server.workstream_server_secret`
    * Change the image tags from 19.0.3 to 20.0.1 in all sections

 * If you want to use the full configuration list and customize the values, update the required values in the `iaws_configuration` and `pfs_configuration` sections in your custom resource YAML file based on your configuration. See the [configuration list](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_iaws_params.html) for each parameter.

4. You can apply or remove the `ums_configuration.external_tls_secret_name` and `ums_configuration.external_tls_ca_secret_name` secrets according to your situation, by referring to the [UMS SSL configuration](../UMS/README_config_SSL.md) and [UMS upgrading configuration](../UMS/README_upgrade.md).

## Step 3: Update the configuration sections for other deployments

To update the configuration sections for other components, such as User Management Service and IBM Business Automation Navigator, go back to the relevant upgrade page to follow their upgrade documents to update your custom resource YAML file.

Upgrade pages:
   - [Managed OpenShift upgrade page](../platform/roks/upgrade.md)
   - [OpenShift upgrade page](../platform/ocp/upgrade.md)
   - [Certified Kubernetes upgrade page](../platform/k8s/upgrade.md)
