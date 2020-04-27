# Installing Cloud Pak for Automation 20.0.1 on Managed OpenShift on IBM Cloud Public

Before you deploy an automation container on IBM Cloud, you must configure your client environment, create an OpenShift cluster, prepare your container environment, and set up where to get the container images.

Make sure that you have the following list of software on your computer so you can use the command line interfaces (CLIs) you need to interact with the cluster.

- [IBM Cloud CLI](https://cloud.ibm.com/docs/containers?topic=containers-cs_cli_install)
- [OpenShift Container Platform CL](https://docs.openshift.com/container-platform/4.2/cli_reference/openshift_cli/getting-started-cli.html)
- [Kubernetes CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- [Docker CLI (Mac)](https://docs.docker.com/docker-for-mac/install) or [Docker CLI (Linux)](https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-docker-engine)

As an administrator of the cluster you must be able to interact with your environment.

1. Create an account on [IBM Cloud](https://cloud.ibm.com/kubernetes/registry/main/start).
2. Log in to IBM Cloud if you already have an account.

If you do not already have a cluster, then create one. From the [IBM Cloud Overview](https://cloud.ibm.com/kubernetes/overview) page, in the OpenShift Cluster tile, click Create Cluster. Refer to the [IBM Cloud documentation](https://cloud.ibm.com/docs/openshift?topic=openshift-openshift-create-cluster#openshift_create_cluster_console) to create a Kubernetes cluster. The cluster that you create includes attached storage.

- [Step 1: Get access to the container images](install.md#step-1-get-access-to-the-container-images)
- [Step 2: Prepare the cluster for automation software](install.md#step-2-prepare-the-cluster-for-automation-software)
- [Step 3: Create a shared PVC and add the JDBC drivers](install.md#step-3-create-a-shared-pvc-and-add-the-jdbc-drivers)
- [Step 4: Deploy the operator manifest files to your cluster](install.md#step-4-deploy-the-operator-manifest-files-to-your-cluster)
- [Step 5: Configure the software that you want to install](install.md#step-5-configure-the-software-that-you-want-to-install)
- [Step 6: Deploy the operator and custom resources](install.md#step-6-apply-the-custom-resources)
- [Step 7: Verify that the operator and pods are running](install.md#step-7-verify-that-the-operator-and-pods-are-running)
- [Step 8: Complete some post-installation steps](install.md#step-8-complete-some-post-installation-steps)

##  Step 1: Get access to the container images

1. Log in to your IBM Cloud Kubernetes cluster. In the OpenShift web console menu bar, click your profile *IAM#user.name@email.com* > *Copy Login Command* and paste the copied command into your command line.
   ```bash
   $ oc login https://<CLUSTERNAME>:<CLUSTERPORT> --token=<GENERATED_TOKEN>
   ```
2. Run a `kubectl` command to make sure that you have access to Kubernetes.
   ```bash
   $ kubectl cluster-info
   ```
3. Download or clone the repository to your local machine and go to the `cert-kubernetes` directory.
   ```bash
   $ git clone git@github.com:icp4a/cert-kubernetes.git
   $ cd cert-kubernetes
   ```
   The `cert-kubernetes` directory includes all of the scripts and descriptors that are needed to install Cloud Pak for Automation.

4. Create a project for each release that you want to install by running the following commands.
   ```bash
   $ oc new-project <project_name> --description="<description>" --display-name="<display_name>"
   ```
5. Add privileges to the projects. Grant ibm-anyuid-scc privileges to any authenticated user and grant ibm-privileged-scc privileges to any authenticated user.
   ```bash
   $ oc project <project_name>
   $ oc adm policy add-scc-to-user privileged -z default
   $ oc adm policy add-scc-to-group ibm-anyuid-scc system:authenticated
   $ oc adm policy add-scc-to-user ibm-privileged-scc system:authenticatedCopy
   ```
   > Note: You need a privileged account to run the oc adm policy command. The <project_name> must have pull request privileges to the registry where the images are loaded. The <project_name> must also have pull request privileges to push the images into another namespace.

6. Make sure that your entitled container images are available and accessible in one of the IBM docker registries. Use either **option 1** or **option 2**.

### Option 1: Create a pull secret for the IBM Cloud Entitled Registry

1. Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

2. In the **Container software library** tile, click **View library** and then click **Copy key** to copy the entitlement key to the clipboard.

3. Create a pull secret by running a `kubectl create secret` command.
   ```bash
   $ kubectl create secret docker-registry admin.registrykey --docker-server=cp.icr.io --docker-username=iamapikey --docker-password="<API_KEY_GENERATED>" --docker-email=<USER_EMAIL>
   ```
   > **Note**: The `cp.icr.io` value for the **docker-server** parameter is the only registry domain name that contains the images.
   
   > **Note**: Use “cp” for the docker-username. The docker-email has to be a valid email address (associated to your IBM ID). Make sure you are copying the Entitlement Key in the docker-password field within double-quotes.

4. Take a note of the secret and the server values so that you can set them to the **pullSecrets** and **repository** parameters when you run the operator for your containers.

5. Install the Container Registry plug-in.
   ```bash
   $ ibmcloud plugin install container-registry -r 'IBM Cloud'
   ```
6. Log in to your IBM Cloud account.
   ```bash
   $ ibmcloud login -a https://cloud.ibm.com
   ```
7. Set the region as global.
   ```bash
   $ ibmcloud cr region-set global
   ```
8. List the available images by using the following command.
   ```bash
   $ ibmcloud cr image-list --include-ibm | grep -i cp4a
   ```

### Option 2: Download the packages from PPA and load the images

[IBM Passport Advantage (PPA)](https://www-01.ibm.com/software/passportadvantage/pao_customer.html) provides archives (.tgz) for the software. To view the list of Passport Advantage eAssembly installation images, refer to the [20.0.1 download document](https://www.ibm.com/support/pages/ibm-cloud-pak-automation-v2001-download-document).

1. Download one or more PPA packages to a server that is connected to your Docker registry.

2. Check that you can run a docker command.
   ```bash
   $ docker ps
   ```
3. Log in to the Docker registry with a token.
   ```bash
   $ docker login $(oc registry info) -u <ADMINISTRATOR> -p $(oc whoami -t)
   ```

   You can also log in to an external Docker registry using the following command:
   ```bash
   $ docker login <registry_url> -u <your_account>
   ```
4. Run a `kubectl` command to make sure that you have access to Kubernetes.
   ```bash
   $ kubectl cluster-info
   ```
5. Download the loadimages.sh script. Change the permissions so that you can run the script.
   ```bash
   $ chmod +x loadimages.sh
   ```
6. Use the [`scripts/loadimages.sh`](../../scripts/loadimages.sh) script to push the images into the IBM Cloud Container Registry.Specify the two mandatory parameters in the command line.

   ```
   -p  PPA archive files location or archive filename
   -r  Target Docker registry and namespace
   -l  Optional: Target a local registry
   ```
   The following example shows the input values in the command line.
   ```bash
   ./loadimages.sh -p <PPA-ARCHIVE>.tgz -r <registry_domain_name>/<project_name>
   ```

   > Note: A registry domain name is associated with your cluster location. The name us.icr.io for example, is for the region us-south. The region and registry domain names are listed on the https://cloud.ibm.com/docs/services/Registry. The default docker registry is based on the host name, for example "default-route-openshift-image-registry.ibm.com". The project must have pull request privileges to the registry where the images are loaded. The project must also have pull request privileges to push the images into another namespace/project.

7. After you push the images to the registry, check whether they are pushed correctly by running the following command.
   ```bash
   $ ibmcloud cr images --restrict <project_name>
   ```
8. Create a pull secret to be able to pull images from the IBM Cloud Container Registry.
   ```bash
   $ kubectl <project_name> create secret docker-registry admin.registrykey \
   --docker-server=<registry_domain_name> --docker-username=iamapikey \
   --docker-password="<APIKEY>" --docker-email=<IBMID> --namespace 
   ```
   To generate an API KEY, go to Security > Manage > Identity and Access > IBM Cloud API Keys in the IBM Cloud menu and select Generate an IBM Cloud API key.

9. Take a note of the secret names so that you can set them to the **pullSecrets** parameter when you run the installation for your containers.
10. (Optional) If you want to use an external Docker registry, create a Docker registry secret.
   ```bash
   $ oc create secret docker-registry <secret_name> --docker-server=<registry_url> --docker-username=<your_account> --docker-password=<your_password> --docker-email=<your_email>
   ```
   Take a note of the secret and the server values so that you can set them to the **pullSecrets** and **repository** parameters when you run the operator for your containers.

## Step 2: Prepare the cluster for automation software

   Before you install any of the containerized software:

   1. Follow the instructions on preparing the cluster for the software components that you want to install in the [IBM Cloud Pak for Automation 20.0.x](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_prepare_env_k8s.html) Knowledge Center.

      How much preparation you need to do depends on what you want to install and how familiar you are with the cluster.

## Step 3: Create a shared PVC and add the JDBC drivers

  IBM Public Cloud ROKS cluster by default attached to an endurance storage which comes with pre-defined storage classes. In order to copy the JDBC drivers to Operator pod you will need to create a new storage class with the following storage requirements to allow copy of JDBC drivers.
   1. Use one of the available storage classes with "gid". (ibmc-file-bronze-gid , ibmc-file-retain-gold , ibmc-file-silver-gid )
   2. Apply the new storage class yaml
      ```bash
      $ oc apply -f operator-sc.yaml
   
   3. Create a claim for a PV dynamically , [descriptors/operator-shared-pvc.yaml](../../descriptors/operator-shared-pvc.yaml?raw=true).

        > Replace the storage class with the name of the storage class from Step 1. Which is (ibmc-file-bronze-gid , ibmc-file-retain-gold , ibmc-file-silver-gid )

   2. Deploy the PVC.
        ```bash
        $ oc create -f descriptors/operator-shared-pvc.yaml
        ```
        Run the following commands to get the bound PV name and the PV location.
        ```bash
        $ oc get pvc | grep operator-shared-pvc
        $ oc describe PV PV_name
        ```

   3. If your storage configuration needs JDBC drivers, create a `jdbc` parent folder on your remote file system and put your drivers into the following structure.
        ```
            └── jdbc

               ├── db2

               │   ├── db2jcc4.jar

               │   └── db2jcc_license_cu.jar

               ├── oracle

               │   └── ojdbc8.jar
        ```
        > **Note**: File names for JDBC drivers cannot include additional version information.

        ```
           - DB2:
              - db2jcc4.jar
              - db2jcc_license_cu.jar
           - Oracle:
              - ojdbc8.jar
        ```

   4. Copy these files to the operator pod by running the following commands:
        ```bash
        $ podname=$(oc get pod | grep ibm-cp4a-operator | awk '{print $1}')
        $ kubectl cp $PATH_TO_JDBC/jdbc $NAMESPACE/$podname:/opt/ansible/share -c ansible
        ```

   ## Step 4: Deploy the operator manifest files to your cluster

   The Cloud Pak operator has a number of descriptors that must be applied.
     - [descriptors/ibm_icp4a_crd.yaml](../../descriptors/ibm_icp4a_crd.yaml?raw=true) contains the description of the Custom Resource Definition.
     - [descriptors/operator.yaml](../../descriptors/operator.yaml?raw=true) defines the deployment of the operator code.
     - [descriptors/role.yaml](../../descriptors/role.yaml?raw=true) defines the access of the operator.
     - [descriptors/role_binding.yaml](../../descriptors/role_binding.yaml?raw=true) defines the access of the operator.
     - [descriptors/service_account.yaml](../../descriptors/service_account.yaml?raw=true) defines the identity for processes that run inside the pods of the operator.    

   1. Deploy the icp4a-operator on your cluster.

      Use the script [scripts/deployOperator.sh](../../scripts/deployOperator.sh) to deploy these descriptors.
      ```bash
      $ ./scripts/deployOperator.sh -i <registry_url>/icp4a-operator:20.0.1 -p '<my_secret_name>' -a accept
      ```

      Where *registry_url* is the value for your internal docker registry or `cp.icr.io/cp/cp4a` for the IBM Cloud Entitled Registry, *my_secret_name* is the secret created to access the registry, and *accept* means that you accept the [license](../../LICENSE).

      > **Note**: If you plan to use a non-admin user to install the operator, you must add the user to the `ibm-cp4-operator` role. For example:
      ```bash
      $ oc adm policy add-role-to-user ibm-cp4a-operator <user_name>
      ```   

   2. Monitor the pod until it shows a STATUS of *Running*:
      ```bash
      $ oc get pods -w
      ```
      > **Note**: When started, you can monitor the operator logs with the following command:
      ```bash
      $ oc logs -f deployment/ibm-cp4a-operator -c operator
      ```

   ## Step 5: Configure the software that you want to install

   A custom resource (CR) YAML file is a configuration file that describes an ICP4ACluster instance and includes the parameters to install some or all of the components.

   1. Make a copy of the template custom resource YAML file [descriptors/ibm_cp4a_cr_template.yaml](../../descriptors/ibm_cp4a_cr_template.yaml?raw=true) and name it appropriately for your deployment (for example descriptors/my_icp4a_cr.yaml).

      > **Important:** Because the maximum length of labels in Kubernetes is 63 characters, be careful with the lengths of your CR name and instance names. Some components can configure multiple instances, each instance must have a different name. The total length of the CR name and an instance name must not exceed 24 characters, otherwise some component deployments fail.

      You must use a single custom resource file to include all of the components that you want to deploy with an operator instance. Each time that you need to make an update or modification you must use this same file to apply the changes to your deployments. When you apply a new custom resource to an operator you must make sure that all previously deployed resources are included if you do not want the operator to delete them.

   2. Change the default name of your instance in descriptors/my_icp4a_cr.yaml.

      ```yaml
      metadata:
        name: <MY-INSTANCE>
      ```

   3. If you plan to install UMS and/or AAE and you use the IBM entitled registry, uncomment the lines for the `image_pull_secrets` and `images` parameters in the `shared_configuration` section.

      If you use an internal registry, enter your values for these parameters.

      ```yaml
      shared_configuration:
        image_pull_secrets:
        - <pull-secret>
        images:
           keytool_job_container:
             repository: <registry_url>:5000/<my-project>/dba-keytool-initcontainer
             tag: 20.0.1  
           dbcompatibility_init_container:
             repository: <registry_url>:5000/<my-project>/dba-dbcompatibility-initcontainer
             tag: 20.0.1
           keytool_init_container:
             repository: <registry_url>:5000/<my-project>/dba-keytool-jobcontainer
             tag: 20.0.1   
           umsregistration_initjob:
             repository: <registry_url>:5000/<my-project>/dba-umsregistration-initjob
             tag: 20.0.1
           pull_policy: IfNotPresent
       ```

      | Parameter                          | Description                                     |
      | -------------------------------    | ---------------------------------------------   |
      | `keytool_job_container`            | Repository from where to pull the UMS keytool_job_container and the corresponding tag  |
      | `dbcompatibility_init_container`   | Repository from where to pull the AAE init_container and the corresponding tag  |
      | `keytool_init_container`           | Repository from where to pull the UMS keytool_init_container and the corresponding tag |
      | `umsregistration_initjob`          | Repository from where to pull the AAE umsregistration_initjob and the corresponding tag  |
      | `image_pull_secrets`               | Secrets in your target namespace to pull images from the specified repository      |

      > **Note:** If you do not plan to install UMS or AAE, you can leave these lines commented in your copy of the custom resource template file.

   4. Use the following links to configure the software that you want to install.

      - [Configure IBM Automation Digital Worker](../../ADW/README_config.md)
      - [Configure IBM Automation Workstream Services](../../IAWS/README_config.md)
      - [Configure IBM Business Automation Application Engine](../../AAE/README_config.md)
      - [Configure IBM Business Automation Content Analyzer](../../ACA/README_config.md)
      - [Configure IBM Business Automation Insights](../../BAI/README_config.md)
      - [Configure IBM Business Automation Navigator](../../BAN/README_config.md)
      - [Configure IBM Business Automation Studio](../../BAS/README_config.md)
      - [Configure IBM FileNet Content Manager](../../FNCM//README_config.md)
      - [Configure IBM Operational Decision Manager](../../ODM/README_config.md)
      - [Configure the User Management Service](../../UMS/README_config.md)

   ## Step 6: Apply the custom resources

   1. Check that all the components you want to install are configured.

      ```bash
      $ cat descriptors/my_icp4a_cr.yaml
      ```

   2. Deploy the configured components by applying the custom resource.

      ```bash
      $ oc apply -f descriptors/my_icp4a_cr.yaml
      ```

   ## Step 7: Verify that the operator and pods are running

   The operator reconciliation loop might take several minutes.

   Monitor the status of your pods with:
   ```bash
   $ oc get pods -w
   ```

   When all of the pods are *Running*, you can access the status of your services with the following command.
   ```bash
   $ oc status
   ```
   You can now expose the services to your users.

   Refer to the [Troubleshooting section](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_trbleshoot_operators.html) to access the operator logs.

   ## Step 8: Complete some post-installation steps

   Go to [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_deploy_postdeployk8s.html) to follow the post-installation steps.

