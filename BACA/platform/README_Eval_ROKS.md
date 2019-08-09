# Deploying BACA on Red Hat OpenShift on IBM Cloud

Before you deploy, you must configure your IBM Public Cloud environment and create an OpenShift cluster. Use the following information to configure your environment and deploy the images.

## Step 1: Prepare your client and environment on IBM Cloud

1. Create an account on [IBM Cloud](https://cloud.ibm.com/kubernetes/registry/main/start).
2. Create a Cluster. 
   From the [IBM Cloud Overview page](https://cloud.ibm.com/kubernetes/overview), in the OpenShift Cluster tile, click **Create Cluster**.
   A cluster comes with attached storage, so you do not need to create persistent volumes.
3. Create a Project.
   Select Kubernetes, Clusters.
   Select the name of your newly created cluster, then select OpenShift Web Console.
   Select Create Project.
   For name and display name enter your project name.
4. Set up a client workstation.
   Install the [IBM Cloud CLI](https://cloud.ibm.com/docs/containers?topic=containers-cs_cli_install).
   Install the [OpenShift Container Platform CLI](https://docs.openshift.com/container-platform/3.11/cli_reference/get_started_cli.html#cli-reference-get-started-cli) to manage your applications and to interact with the system.
5. Install the Container Registry plug-in:
    `ibmcloud plugin install container-registry -r Bluemix`
6. On your client workstation, download the following components:
    * ICP4A BACA ppa package from [Passport Advantage](https://spcn.w3cloud.ibm.com/software/spcn/content/Y107038W39561F66.html).
    * BACA installation folder from [GitHub](https://github.com/icp4a/cert-kubernetes/tree/19.0.1/BACA).
  
## Step 2: Push the images to the IBM Cloud Container Registry

Push the downloaded images to your private registry.

1. Log in to your IBM Cloud account. with `ibmcloud login -a https://cloud.ibm.com –-sso`
   When asked to Open the URL in the default browser, select Y.  In some cases, your client may not be able to open the browser automatically in which case you will need to copy the provided URL and open the browser manually.
   Paste the One Time Code into the client. Then as prompted, enter the following:
       *Select an account – Enter the number for the Cloud account holding the baca project.
       *Select a region – Enter the number for the region where the managed instance is located.
2. Create a namespace.
   `ibmcloud cr namespace-add <my_namespace>`
3. Log your local Docker daemon into the IBM Cloud Container Registry.
   `ibmcloud cr login`
4. Push and tag the images to the cluster registry:
   `./loadimages.sh -p <image_name> -r us.icr.io/<my_namespace>`
6. Verify that your images are in your private registry.
   `ibmcloud cr image-list`

## Step 3: Create the PVCs

1. Get a list of your storage classes and select one of the choices to be your storage class.
    `oc get storage classes`
Login to the OpenShift Web Console and select Storage.
2. For each of three PVCs, click on Create PVC and enter the following values.
    * Storage Class – <my_storage_class>
    * Access Mode – Shared Access (RWX)
    * Name and Size (typical name is sp-<logtype>-pvc-<my_namespace>
       * data pvc    60GiB
       * log pvc     35GiB
       * config pvc  20GiB

## Step 4: Create a Secret ID

1. Login to IBM Cloud.
2. Select Manage toward the top right and click on Access (AIM).
3. Select Service IDs and click Create.
4. Enter a name and description, and click Create.
5. Select the API keys tab and click Create.
6. Enter the same name and description and click Create.
7. Copy or download the API key.  You must save it now.

## Step 5: Configure the DB2 databases
BACA requires a dedicated DB2 server.

1. Connect to the database server as user with administrator level access to DB2.
2. Copy the DB2 folder from your client installation folder onto a DB2 server work folder you create.
3. Create the base database.
    `./CreateBaseDB.sh`
4. As prompted, enter the following:
    * Enter the name of the BACA Base database – (enter a unique name of 8 characters or less and no special characters)
    * Enter the name of database user – (enter a database user name) – this can be a new or existing DB2 user
    * Enter the password for the user – (enter a password) – each time when prompted.  If this is an existing user, this prompt will be skipped.
5. Add a tenant.
    `./AddTenant.sh`
6. As prompted, enter the following:
    * Enter the tenanttype – 0 (for Enterprise)
    * Enter the tenant ID – (enter a unique alphanumeric value)
    * Enter the name of the BACA tenant database – (recommend using the tenant id, but can be any unique name of 8 characters or less and no special characters)
    * Enter the host/IP of the database server – (enter the IP address of the database server)
    * Enter the port of the database server – Press Enter to accept default of 50000
    * Do you want this script to create a database user – y (for yes)
    * Please enter the name of database user – (enter an alphanumeric username with no special characters)
    * Enter the password for the user – (enter an alphanumeric password each time when prompted)
    * Enter the tenant ontology name – Press Enter to accept default, or if desired, enter the name you will reference the ontology by.
    * Enter the name of the Base BACA database – (enter the database name entered when creating the base database)
    * Enter the name of the database user for the Base BACA database – (enter the database user entered when creating the base database)
The remaining entries are for setting up the initial user.
    * Please enter the company name – (enter your company name)
    * Please enter the first name - (enter your first name)
    * Please enter the last name - (enter your last name)
    * Please enter a valid email address - (enter your IBM email address)
    * Please enter the login name – (if using LDAP, enter your LDAP name – if not using LDAP, enter the name you prefer to use to login with)
    * Would you like to continue – y (for yes)

## Step 6: Run the BACA predeployment

1. In the configuration folder, copy common_OCP_template.sh to common.sh
2. Edit common.sh following the [Knowledge Center Reference](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/topics/ref_baca_common_params.html).
When editing common.sh, the following are differences specific to OCPoC.
   * OCP_VERSION=3.1.1
   * ICP references in documentation are OCP in common.sh
   * PVCCHOICE=2 (PVCs previously created)
3. Run the predeployment script.
    `./init_deployments.sh`

## Step 7: Generate memory values
An OCPoC install with multiple products may require a systems designer to determine how memory will be configured.  However, for guidance getting a starting point on a basic system, do the following:

1. Change to the configuration folder.
2. Generate the memory values for a small development system
    `./generateMemoryValues.sh limited`
          --- or for a larger system with six or more nodes ---
    `./generateMemoryValues.sh distributed`
3. Note these values as they will be used in the next step.

## Step 8: Deploy the Helm Chart

1. Change to the SmartPages-Helmchart folder.
2. Extract the helm chart.
    `tar xf ibm-dba-baca-prod-1.0.0.tgz`
3. Change to the stable/ibm-dba-baca-prod folder.
4. Edit values.yaml, changing the following values wherever they appear, using the [GitHub values.yaml Reference](https://github.com/icp4a/cert-kubernetes/blob/19.0.1/BACA/docs/values_yaml_parameters.md)
5. When editing values.yaml, for OCPoC under global add the secret ID so the section looks as follows:
    ```
    global:
      image:
        pullSecrets:
          - (secret ID name)
   ```
6. Install the helm chart.
    `helm install . --name celery<my_namespace> -f values.yaml  --namespace <my_namespace> --tiller-namespace tiller`

## Step 9: Create an NGINX Pod
These steps create a pod called folder-creation-baca and its purpose is to provide the ability to add the folder structure required for logging.

1. Change to the platforms folder.
2. Edit the nginx_folders.yaml if needed.
3. Create the pod.
    `kubectl apply -f nginx_folders.yaml`
4. Log in to the pod.
    `kubectl exec -ti folder-creation-baca bash`
5. Create folders used by BACA.
    ```
    cd /logs
    mkdir -p {backend,frontend,callerapi,processing-extraction,pdfprocess,setup,interprocessing,classifyprocess-classify,ocr-extraction,postprocessing,reanalyze,updatefiledetail,spfrontend,minio,redis,rabbitmq,mongo,mongoadmin,utf8process}
    cd /data
    mkdir -p {mongo,mongoadmin,redis,rabbitmq,minio}
    cd /config
    mkdir -p /config/backend
    ```
6. Set folder permissions to 51000:51001.
    ```
    cd /
    chown -Rf 51000:51001 /logs
    chown -Rf 51000:51001 /data
    chown -Rf 51000:51001 /config
    ```
7. Exit the pod.
    `exit`

## Step 10: Configure Routing

1.	Login to the OpenShift Web Console and in the dropdown in the top banner, select Cluster Console.
2. Note the URL, dropping https://console from the front.  This will form the second part of the routing URL. 
Create pass-through routing.
    ```
    oc create route passthrough <my_namespace>frontend --insecure-policy=Redirect --service=spfrontend --hostname=<my_namespace>frontend.<routing URL>
    oc create route passthrough <my_namespace>backend --insecure-policy=Redirect --service=spbackend --hostname=<my_namespace>backend.<routing url>
    ```
