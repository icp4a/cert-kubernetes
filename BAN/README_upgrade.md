# Upgrading from Business Automation Navigator from 19.0.3 to 20.0.1 

These instructions cover the upgrade of Business Automation Navigator from 19.0.3 to 20.0.1.

## Introduction

You can upgrade your Business Automation Navigator 19.0.3 deployments to apply the updates that are associated with Business Automation Navigator 20.0.1.

## Step 1: Update the custom resource YAML file for your Business Automation Navigator 20.0.1 deployment.

Get the custom resource YAML file that you used to deploy Business Automation Navigator 19.0.3, and edit it by following these steps:

1. Change the release version from 19.0.3 to 20.0.1.

2. Add `appVersion: 20.0.1` to the spec section that appears at the beginning of the file.

```
spec:
   appVersion: 20.0.1
```

3. In the `ban`section, update the tag value for the new version:
 
 * navigator:ga-307-icn-if002
 * navigator-sso:ga-307-icn-if002
 
## Step 2: Update the configuration sections for other deployments

To update the configuration sections for other components, such as FileNet Content Manager, go back to the relevant upgrade page to follow their upgrade documents to update your custom resource YAML file.

Upgrade pages:
   - [Managed OpenShift upgrade page](../platform/roks/upgrade.md)
   - [OpenShift upgrade page](../platform/ocp/upgrade.md)
   - [Certified Kubernetes upgrade page](../platform/k8s/upgrade.md)
