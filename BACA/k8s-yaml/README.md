# Deploying with Kubernetes YAML

If you prefer to use a simpler deployment process that uses a native Kubernetes authorization mechanism (RBAC) instead of Helm and Tiller, use the Helm command line interface (CLI) to generate a Kubernetes manifest. If you choose to use Kubernetes YAML you cannot use certain capabilities of Helm to manage your deployment.

Before you install make sure that you have prepared your environment.

## Prepare environment

### Prerequisites
1. If the Helm client is not installed in your Kubernetes cluster, install [Helm 2.11.0](https://github.com/helm/helm/releases/tag/v2.11.0).


### Step 1 - Create Content Analyzer Base DB
1. Copy the DB2 folder from https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BACA/configuration/DB2 to your IBM DB2 server
2. cd to DB2 folder and run ./CreateBaseDB.sh script. (Ex. Please run with db2inst1 which has 'sudo' privileges)
3. As prompted, enter the following data:
  - Enter the name of the IBM® Business Automation Content Analyzer Base database – (enter a unique name of 8 characters or less and no special characters).
  - Enter the name of database user – (enter a database user name that has full permissions to the base database). This can be a new or an existing Db2 user.
  - Enter the password for the user – (enter a password) – each time when prompted. If this is an existing user, this prompt is skipped

### Step 2 - Create the Content Analyzer Tenant database
1. Still in the DB2 folder, Run ./AddTenant.sh script on the Db2 server.
For more information, see Creating Content Analyzer Tenant database.
2. As prompted, enter the following parameters:
  - Enter the tenant ID – (an alphanumeric value that is used by the user to reference the database)
  - Enter the name of the IBM® Business Automation Content Analyzer tenant database - (an alphanumeric value for the actual database name in Db2)
  - Enter the host/IP of the database server – (the IP address of the database server)
  - Enter the port of the database server – Press Enter to accept default of 50000 (or enter the port number if a different port is needed)
  - Do you want this script to create a database user – y (for yes)
  - Enter the name of database user – (this is the tenant database user - enter an alphanumeric user name with no special characters)
  - Enter the password for the user – (enter an alphanumeric password each time when prompted)
  - Enter the tenant ontology name – Press Enter to accept default (or enter a name to reference the ontology by if desired)
  - Enter the name of the Base Business Automation Content Analyzer database – (enter the database name given when you create the base database)
  - Enter the name of the database user for the Base Business Automation Content Analyzer database – (enter the base user name given when you create the base database)
  - Enter the company name – (enter your company name. This parameter and the remaining values are used to set up the initial user in Business Automation Content Analyzer)
  - Enter the first name - (enter your first name)
  - Enter the last name - (enter your last name)
  - Enter a valid email address - (enter your email address)
  - Enter the login name – (if you use LDAP authentication, enter your user name as it appears in the LDAP server)
  - Would you like to continue – y (for yes)
  - Save the tenantID and Ontology name for the later steps.

### Step 3 - download the configuration files
1. Download all the files and folders except DB2 folder from https://github.com/icp4a/cert-kubernetes/tree/19.0.2/BACA/configuration to where you plan to install Content Analyzer. For example, to a system that can be connected to IBM Cloud Private.

### Step 4 - Edit common.sh
1. Edit and populate the /configuration/common.sh that was downloaded from step 3 with the correct values from the [Prerequisite install parameters table](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/topics/ref_baca_common_params.html). (Since helm server is not being used, be sure USING_HELM is set to N)

### Step 5 - Creates prerequisite resources for IBM Business Automation Content Analyzer
1. Run ./init_deployment.sh from `configuration` folder that was downloaded from step 3.
  - Required persistent volumes and volume claims, secrets are created during the preparation of the environment

### Step 6 - Update values.yaml
1. Download the Helm Chart to the master node from https://github.com/icp4a/cert-kubernetes/blob/19.0.2/BACA/helm-charts/ibm-dba-baca-prod-1.2.0.tgz
2. Extract the helm chart from ibm-dba-prod-1.2.0.tgz.
3. Proceed to ibm-dba-baca-prod/ibm_cloud_pak/pak_extensions directory and copy template.yaml to ibm-dba-baca-prod/values.yaml
4. Edit the values.yaml file and complete the values mentioned in the [Helm Chart configuration parameter section](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/topics/ref_baca_globaloptions_params.html) for options with the parameters and values. 

Note that anything not documented does not need to be changed.

### Step 7 - Download IBM Cloud Pak for Automation V19.0.2 and load IBM Business Automation Content Analyzer base image

1. Please follow the instruction in https://www.ibm.com/support/docview.wss?uid=ibm10958567 to download CC3SEEN package to a server that is connected to your Docker registry.
2. Download the [loadimages.sh](https://github.com/icp4a/cert-kubernetes/blob/19.0.2/scripts/loadimages.sh script from GitHub.
3. Login to the specified Docker registry with the docker login command. This command depends on the environment that you have.
4. Run the loadimages.sh script to load the images into your Docker registry. Specify the two mandatory parameters in the command line.
   - Note: The docker-registry value depends on the platform that you are using
   
   ```
   -p  PPA archive files location or archive filename
   -r  Target Docker registry and namespace
   -l  Optional: Target a local registry
   ```
  The following example shows the input values in the command line.
   ```
  # scripts/loadimages.sh -p /Downloads/PPA/ImageArchive.tgz -r <DOCKER-REGISTRY>/demo-project
   ```
### Step 8 - Generate yaml files and deploy   
1. Create a chart YAML template file with the configuration parameters defined in values.yaml by using the following command in the ibm-dba-baca-prod directory. The `--name` argument sets the name of the release to install.

   ```console
   $ helm template . -f values.yaml\
     --name celery<namespace> \
      > generated-k8s-templates.yaml
   ```

2. Install `celery<namespace>` by using the following command.

   ```console
   $ kubectl -n <namespace> apply -f generated-k8s-templates.yaml
   ```
 
3. Run the following command to see that status of the pods. Wait until all pods are running and ready.
    
    ```$ kubectl -n <namespace> get pods```

    Due to the configuration of the readiness probes, after the pods start, it may take up to 10 or more minutes before the pods enter a ready state.

> **Reminder**: After you deploy, return to the instructions for [Completing post deployment tasks for IBM Business Automation Content Analyzer](../docs/post-deployment.md), to review document for further configuration.

## Uninstalling a Kubernetes release of IBM Business Automation Content Analyzer

To uninstall and delete the IBM Business Automation Content Analyzer release, use the following command:

```console
$ kubectl delete -f generated-k8s-templates.yaml
```

The command removes all the Kubernetes components associated with the release, except any Persistent Volume Claims (PVCs).  This is the default behavior of Kubernetes, and ensures that valuable data is not deleted. To delete the persisted data of the release, you can delete the PVC using the following command:

```console
$ kubectl delete pvc my-baca-prod-release-baca-pvclaim
```

In the configuration folder, the delete_ContentAnalyzer.sh script can also be used to clean up PVs, PVCs, secrets and directories created by the init_deployment.sh script. Simply, run delete_ContentAnalyzer.sh from the master node where the configuration directory was copied to.
