# IBM Cloud Pak for Automation 20.0.1 for demonstration purposes

This repository includes folders and resources to help you install the Cloud Pak for Automation software for demonstration purposes on Red Hat OpenShift Cloud Platform (OCP) 3.11.

Cloud Pak for Automation capabilities can be installed on OCP by running a deployment script and selecting a deployment pattern. A deployment pattern includes a single Cloud Pak capability, as well as Db2 and OpenLDAP when they are needed.

> **Note:** In 20.0.1, patterns cannot be used to install the Cloud Pak for enterprise purposes.

In addition to the patterns, you can also install Business Automation Insights and Automation Digital Worker for demonstration purposes. These capabilities use a pattern deployment to demonstrate their value.

- [Single capability deployment](README.md#single-capability-deployment)
- [Combined capabilities deployment](README.md#extended-pattern-deployment)

## Single capability deployment

To install a pattern with the Cloud Pak operator, an OCP administrator must run a script to setup a cluster and work with a non-administrator user to help them run the deployment script.

Each pattern has a single Cloud Pak capability and a list of optional components that can be installed with the pattern. The deployment script prompts the user to enter values to get access to the container images and to select what is installed in the deployment. 

To install a pattern, click the link [Install a deployment pattern on Red Hat OpenShift](install_pattern_ocp.md).

## Combined capabilities deployment

Both Business Automation Insights and Automation Digital Worker need other Cloud Pak capabilities. To use more than one capability in an OCP cluster you must install a single deployment pattern by using the Cloud Pak operator, install Business Automation Insights or Automation Digital Worker, and configure the components to work with each other.

To install multiple capabilities, click one of the following links:

- [Install Business Automation Insights with a pattern on Red Hat OpenShift](install_insights_ocp.md)
- [Install Automation Digital Worker with a pattern on Red Hat OpenShift](install_workers_ocp.md)
