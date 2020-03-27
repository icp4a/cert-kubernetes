# Installing a deployment pattern on Red Hat OpenShift 3.11

This repository includes folders and resources to help you install the Cloud Pak for Automation software for demonstration purposes on Red Hat OpenShift Cloud Platform (OCP) 3.11.

To install a pattern with the Cloud Pak operator, an OCP administrator user must run a script to set up a cluster and work with a non-administrator user to help them run a deployment script. Each pattern has a single Cloud Pak capability, a list of optional components that can be installed, as well as Db2 and OpenLDAP if they are needed. 

> **Note**: The scripts can only be used on a Linux-based operating system: Red Hat (RHEL), CentOS, and macOS.

You can install one of the following capabilities, or patterns, for demonstration purposes:
 - **Automation Applications**, which includes:
   - Business Automation Studio (BAS)
   - App Designer
   - App Engine
   - User Management Service (UMS)
   - Business Automation Navigator (BAN)
   - Application Discovery Plugin
 - **Automation Content Analyzer**, which includes:
   - Automation Content Analyzer (ACA)
   - User Management Service (UMS) as an optional component
 - **Automation Workstream Services**, which includes:
   - AWS server
   - Process Federation Server (PFS)
   - App Engine
   - Business Automation Navigator (BAN)
   - Content Platform Engine (CPE)
   - Content Search Services (CSS)
   - Resource Registry (RR)
   - User Management Service (UMS) as an optional component
 - **FileNet Content Manager**, which includes:
   - Content Platform Engine (CPE)
   - Content Search Services (CSS)
   - Business Automation Navigator (BAN)
   - Content Services GraphQL
   - Content Management Interoperability Services (CMIS) as an optional component
 - **Operational Decision Manager**
   - Operational Decision Manager (ODM)

The "demo" deployment type provisions all of the required services like Db2, OpenLDAP, and Kafka with the default values so there is no need to prepare these in advance. 

Use the following sections to install or uninstall a pattern:
- [Install a deployment pattern](install_pattern_ocp.md#install-a-deployment-pattern)
- [Uninstall a deployment pattern](install_pattern_ocp.md#uninstall-a-deployment-pattern)

# Install a deployment pattern

- [Step 1: Plan and prepare (by an OCP cluster administrator)](install_pattern_ocp.md#step-1-plan-and-prepare-(by-an-ocp-cluster-administrator))
- [Step 2: Get access to the container images (by an installer)](install_pattern_ocp.md#step-2-get-access-to-the-container-images-(by-an-installer))
- [Step 3: Run the deployment script (by an installer)](install_pattern_ocp.md#step-3-run-the-deployment-script-(by-an-installer))
- [Step 4: Verify that the automation containers are running](install_pattern_ocp.md#step-4-verify-that-the-automation-containers-are-running)
- [Step 5: Access the services](install_pattern_ocp.md#step-5-access-the-services)
- [Step 6: List the default LDAP users and passwords](install_pattern_ocp.md#step-6-list-the-default-ldap-users-and-passwords)
- [Step 7: Post-installation tasks](install_pattern_ocp.md#step-7-post-installation-tasks)
- [Troubleshoot](install_pattern_ocp.md#troubleshoot)

## Step 1: Plan and prepare (by an OCP cluster administrator)

The role of the cluster administrator is to gather the minimum system requirements to host and run the selected pattern of the Cloud Pak. A conversation needs to happen between the administrator and the non-administrator user (installer) to determine which pattern they want to install.

The administrator must make sure that the target OpenShift cluster has the following tools and attributes.
   - Kubernetes 1.11+.
   - Kubernetes CLI. For more information, see https://kubernetes.io/docs/tasks/tools/install-kubectl/.
   - The OpenShift Container Platform CLI. The CLI has commands for managing your applications, and lower-level tools to interact with each component of your system. Refer to the OpenShift 3.11: https://docs.openshift.com/container-platform/3.11/cli_reference/get_started_cli.html.
   - Dynamic storage created and ready.  
     > **Tip**: For more information, see Kubernetes NFS Client Provisioner: https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client. There are instructions to configure NFS server and client for the OCP nodes if you need to setup an NFS server.
   - At least one non-administrator user that can be used to run the deployment script. For example `cp4a-user`.
   
The OCP cluster needs the following minimum requirements for each pattern:

| Pattern name	| Master/Infra/Worker nodes | CPU per node type | Memory per node | Storage |
| :---	| :---	| :---	| :---	| :--- |
| Automation Applications	| 1/1/3 | 4/4/4 | 8Gi | 53 GB |
| Automation Content Analyzer	| 1/1/2 | 4/4/8 | 16Gi | 100 GB |
| Automation Workstream Services	| 1/1/3 | 6/6/6 | 16Gi | 66 GB |
| FileNet Content Manager	| 1/1/3 | 4/4/4 | 16Gi | 65 GB |
| Operational Decision Manager | 1/1/3 | 4/4/4 | 4Gi | 5 GB |

   > **Note**: The Master and Infrastructure nodes can be located on the same host as long as it has enough resources. Masters with a co-located **etcd** need a minimum of 4 cores. OCP 3.11 does not support Docker alternative runtimes that implement the Kubernetes CRI (Container Runtime Interface), like CRI-O.


The cluster setup script creates an OpenShift project (namespace), applies the custom resource definitions (CRD), adds the specified user to the ibm-cp4a-operator role, binds the role to the service account, and applies a security context constraint (SCC) for the Cloud Pak. 

The script also prompts the administrator to take note of the cluster host name and a dynamic storage class on the cluster. These names must be provided to the user who runs the deployment script. 

Use the following steps to complete the preparation:

1. Download or clone the GitHub repository on your local machine and go to the `cert-kubernetes` directory.
   ```bash
   $ git clone git@github.com:icp4a/cert-kubernetes.git
   $ cd cert-kubernetes
   ```
2. Login to the target cluster as the `<cluster-admin>` user.
   ```bash
   $ oc login https://<cluster-ip>:<port> -u <cluster-admin> -p <password>
   ```
3. Run the cluster setup script from where you downloaded the GitHub repository, and follow the prompts in the command window.
   ```bash
   $ cd scripts
   $ ./cp4a-clusteradmin-setup.sh
   ```
   
   1. Enter the name for a new project or an existing project (namespace). For example `cp4a-demo`.
   2. Enter an existing non-administrator user name in your cluster to run the deployment script. For example `cp4a-user`.
   
   When the script is finished all of the available storage class names are displayed as well as the infrastructure node name. Take a note of the class name that you want to use for the installation and the host name as they are both needed for the deployment script.

## Step 2: Get access to the container images (by an installer)

To get access to the Cloud Pak container images you must have an IBM Entitlement Registry key to pull the images from the IBM docker registry or download the Cloud Pak package (.tgz file) from Passport Advantage (PPA) and push the images to a local docker registry. The deployment script asks for the entitlement key or user credentials for the local registry.

As the non-administrator user, you also need the container images for Db2 and OpenLDAP.
1. Download or clone the GitHub repository on your local machine and go to to `cert-kubernetes` directory.
   ```bash
   $ git clone git@github.com:icp4a/cert-kubernetes.git
   $ cd cert-kubernetes
   ```
   The scripts and Kubernetes descriptors are needed to install Cloud Pak for Automation.
2. To pull and push the Db2 and OpenLDAP images to your docker registry, run a script from a machine that is able to connect to the internet and the target image repository.
   ```bash
   $ ./loadPrereqImages.sh
   ```

### Option 1: Create an entitlement key for the IBM Cloud Entitled Registry

1. Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

2. In the **Container software library** tile, click **View library** and then click **Copy key** to copy the entitlement key to the clipboard. Take a note of the key so that the installer can enter it with the deployment script.

### Option 2: Download the packages from PPA and load the images

[IBM Passport Advantage (PPA)](https://www-01.ibm.com/software/passportadvantage/pao_customer.html) provides archives (.tgz) for the software. To view the list of Passport Advantage eAssembly installation images, refer to the [download document](https://www.ibm.com/support/pages/ibm-cloud-pak-automation-v2001-download-document).

1. Download one or more PPA packages to a server that is connected to your Docker registry.
2. Check that you can run a docker command.
   ```bash
   $ docker ps
   ```
3. Log in to the Docker registry with a token.
   ```bash
   $ docker login $(oc registry info) -u <ADMINISTRATOR> -p $(oc whoami -t)
   ```
   > **Note**: You can connect to a node in the cluster to resolve the `docker-registry.default.svc` parameter.

4. Run a `kubectl` command to make sure that you have access to Kubernetes.
   ```bash
   $ kubectl cluster-info
   ```
5. Run the [`scripts/loadimages.sh`](../scripts/loadimages.sh) script to load the images into your Docker registry. Specify the two mandatory parameters in the command line.

   ```
   -p  PPA archive files location or archive filename
   -r  Target Docker registry and namespace
   -l  Optional: Target a local registry
   ```

   The following example shows the input values in the command line.
   ```
   $ ./loadimages.sh -p <PPA-ARCHIVE>.tgz -r docker-registry.default.svc:5000/<project-name>
   ```

   > **Note**: The `project-name` variable is the name of the project created by the cluster setup script. If you want to use an external Docker registry, take a note of the OCP docker registry service name or the URL to the docker registry, so that you can enter it in the deployment script. If you connect remotely to the OCP cluster from a Linux host/VM then you must have Docker and the OpenShift Commandline Interface (CLI) installed. If you have access to the master node on the OCP v3.11 cluster, the CLI and Docker are already installed.

6. Check that the images are pushed correctly to the registry.
    ```bash
    $ oc get is
    ```

## Step 3: Run the deployment script (by an installer)

Depending on the pattern that you want to install, the deployment script prepares the environment before installing the automation containers. The script applies a customized custom resource (CR) file, which is deployed by the Cloud Pak operator. The deployment script prompts the user to enter values to get access to the container images and to select what is installed with the deployment.

1. Login to the OCP 3.11 cluster with the non-administrator user that the cluster administrator used in Step 1. For example:
   ```bash
   $ oc login -u cp4a-user -p cp4a-user
   ```
2. Run the deployment script from the local directory where you downloaded the GitHub repository, and follow the prompts in the command window.
   ```bash
   $ cd scripts
   $ ./cp4a-deployment.sh
   ```
   
> **Note:** The deployment script makes use of a custom resource (CR) template file for each pattern. The template names include "demo" and are found in the [descriptors/patterns](../descriptors/patterns) folder. The CR files are configured by the deployment script. However, you can copy these templates, configure them by hand, and apply the file from the kubectl command line if you want to run the steps manually.

## Step 4: Verify that the automation containers are running

The operator reconciliation loop can take some time. 

1. You can open the operator log to view the progress.
   ```bash
   $ oc logs <operator pod name> -c operator -n <project-name>
   ```
   
2. Monitor the status of your pods with:
   ```bash
   $ oc get pods -w
   ```

3. When all of the pods are *Running*, you can access the status of your services with the following command.
   ```bash
   $ oc status
   ```

## Step 5: Access the services

When all of the containers are running.

1. Go to to `cert-kubernetes` directory on your local machine.
   ```bash
   $ cd cert-kubernetes
   ```
2. Login to the OCP 3.11 cluster with the non-administrator user that the administrator created in Step 1. For example:
   ```bash
   $ oc login -u cp4a-user -p cp4a-user
   ```
3. Run the post deployment script, which prints out the routes created by the pattern and the user credentials that you need to login to the web applications to get started.
   ```bash
   $ cd scripts
   $ ./cp4a-post-deployment.sh
   ```
   
## Step 6: List the default LDAP users and passwords

After you found the service URLs and admin user credentials, you can also get a list of LDAP users.

1. Get the `<deployment-name>` by running the following command. The `<deployment-name>` is the name of the pattern that you installed.
   ```bash
   $ oc get icp4acluster
   ```
2. Get the usernames and passwords for the LDAP users.
   ```bash
   $ oc get cm <deployment-name>-openldap-customldif -o yaml
   ```
   
## Step 7: Post-installation tasks

If the pattern that you installed includes Business Automation Navigator (BAN) and the User Management Service (UMS), then you need to configure the Single Sign-On (SSO) logout for the Admin desktop. For more information, see [Configuring SSO logout between BAN and UMS](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_configbanumsssok8s.html]).
   
## Troubleshoot 
For more information, see [Troubleshooting a deployment for demonstration purposes](install_troubleshooting_ocp.md).

# Uninstall a deployment pattern

To uninstall the deployment, you can delete the namespace by running the following command:
```bash
$ oc delete project <project-name>
```
To uninstall the cluster role, cluster role binding, and the CRD run the following commands:
```bash
$ oc delete clusterrolebinding <NAMESPACE>-cp4a-operator 
$ oc delete clusterrole ibm-cp4a-operator 
$ oc delete crd icp4aclusters.icp4a.ibm.com
```

