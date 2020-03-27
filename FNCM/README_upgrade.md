# Upgrading from FileNet Content Manager 19.0.3 to 20.0.1 

These instructions cover the upgrade of FileNet Content Manager from 19.0.3 to 20.0.1.

## Introduction

You can upgrade your FileNet Content Manager for IBM Cloud Pak for Automation 19.0.3 deployments to apply the updates that are associated with FileNet Content Manager for IBM Cloud Pak for Automation 20.0.1.

## Step 1: Update the custom resource YAML file for your FileNet Content Manager for Cloud Pak for Automation 19.0.3 deployment.

Get the custom resource YAML file that you used to deploy FileNet Content Manager in 19.0.3, and edit it by following these steps:

1. Change the release version from 19.0.3 to 20.0.1.

2. Add `appVersion: 20.0.1` to the spec section that appears at the beginning of the file.

```
spec:
   appVersion: 20.0.1
```

3. In the sections for each of the components that are included in your FileNet Content Manager deployment in the `ecm_configuration` section, for example `cpe`, `css`, and so on, update the tag values for the new versions:
 
 * cpe:ga-554-p8cpe-if001
 * css:ga-554-p8css-if001
 * graphql:ga-554-p8cgql-if001
 * cmis:ga-304-cmis-if010
 * extshare:ga-307-es-if002
 * taskmgr:ga-307-tm-if002
 
## Step 2: Update the configuration sections for other deployments

To update the configuration sections for other components, such as User Management Service and IBM Business Automation Navigator, go back to the relevant upgrade page to follow their upgrade documents to update your custom resource YAML file.

Upgrade pages:
   - [Managed OpenShift upgrade page](../platform/roks/upgrade.md)
   - [OpenShift upgrade page](../platform/ocp/upgrade.md)
   - [Certified Kubernetes upgrade page](../platform/k8s/upgrade.md)
