# Migrating Business Automation Navigator 3.0.x to V3.0.7

Because of the change in the container deployment method, there is no upgrade path for previous versions of Business Automation Navigator to V3.0.7.

To move a V3.0.x installation to V3.0.7, you prepare your environment and deploy the operator the same way you would for a new installation. The difference is that you use the configuration values for your previously configured environment, including datasource, LDAP, storage volumes, etc. when you customize your deployment YAML file.

Optionally, to protect your production deployment, you can create a replica of your data and use that datasource information for the operator deployment to test your migration. In this option, you follow the instructions for a new deployment.


## Step 1: Collect parameter values from your existing deployment

You can use the reference topics in the [Cloud Pak for Automation Knowldege Center](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_ban_opparams.html) to see the parameters that apply for your components and shared configuration.

You will use the values for your existing deployment to update the custom YAML file for the new operator deployment. For more information, see [Configure Business Automation Navigator](README_config.md). 

> **Note**: When you are ready to deploy the V3.0.7 version of your Business Automation Navigator container, stop your previous container.

## Step 2: Return to the platform readme to migrate other components

- [Managed OpenShift migrate page](../platform/roks/migrate.md)
- [OpenShift migrate page](../platform/ocp/migrate.md)
- [Kubernetes migrate page](../platform/k8s/migrate.md)
