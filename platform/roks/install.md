# Installing Cloud Pak for Automation 19.0.3 on Managed OpenShift on IBM Cloud Public

- [Step 1: Get access to the container images](install.md#step-1-get-access-to-the-container-images)
- [Step 2: Prepare the cluster for automation software](install.md#step-2-prepare-the-cluster-for-automation-software)
- [Step 3: Create a shared PVC and add the JDBC drivers](install.md#step-3-create-a-shared-pvc-and-add-the-jdbc-drivers)
- [Step 4: Deploy the operator manifest files to your cluster](install.md#step-4-deploy-the-operator-manifest-files-to-your-cluster)
- [Step 5: Configure the software that you want to install](install.md#step-5-configure-the-software-that-you-want-to-install)
- [Step 6: Deploy the operator and custom resources](install.md#step-6-apply-the-custom-resources)
- [Step 7: Verify that the operator and pods are running](install.md#step-7-verify-that-the-operator-and-pods-are-running)
- [Step 8: Complete some post-installation steps](install.md#step-8-complete-some-post-installation-steps)

##  Step 1: Get access to the container images

1. Download or clone the repository to your local machine and go to the `cert-kubernetes` directory.
   ```bash
   $ git clone git@github.com:icp4a/cert-kubernetes.git
   $ cd cert-kubernetes
   ```
   The `cert-kubernetes` directory includes all of the scripts and descriptors that are needed to install Cloud Pak for Automation.
   
2. Go to [Installing containers on Red Hat OpenShift by using CLIs](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_ROKS.html) to get access to the container images. You can access the container images in the IBM Docker registry with your IBMid (Option 1), or you can use the downloaded archives from IBM Passport Advantage (PPA) (Option 2).

3. (Optional) If you loaded the images to an external Docker registry, create a Docker registry secret and take note of the secret and the server values so that you can set them to the **pullSecrets** and **repository** parameters when you run the operator for your containers.

   ```bash
   $ oc create secret docker-registry <secret_name> --docker-server=<registry_url> --docker-username=<your_account> --docker-password=<your_password> --docker-email=<your_email>
   ```

## Step 2: Prepare the cluster for automation software

Before you install any of the containerized software:

1. Follow the instructions on preparing the cluster for the software components that you want to install in the [IBM Cloud Pak for Automation 19.0.x](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_prepare_env_k8s.html) Knowledge Center.

   How much preparation you need to do depends on what you want to install and how familiar you are with the cluster.

## Step 3: Create a shared PVC and add the JDBC drivers

1. Create a claim for a PV dynamically, [descriptors/operator-shared-pvc.yaml](../../descriptors/operator-shared-pvc.yaml?raw=true).

     > Replace the storage class with the name of a "sc" in your environment.

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
     $ kubectl cp $PAHT_TO_JDBC/jdbc $NAMESPACE/$podname:/opt/ansible/share -c ansible
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
   $ ./scripts/deployOperator.sh -i <registry_url>/icp4a-operator:19.0.3 -p '<my_secret_name>' -a accept
   ```

   Where *registry_url* is the value for your internal docker registry or `cp.icr.io/cp/cp4a` for the IBM Cloud Entitled Registry and *my_secret_name* the secret created to access the registry, *accept* means you accept this [license](../../LICENSE).

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
          tag: 19.0.3  
        dbcompatibility_init_container:
          repository: <registry_url>:5000/<my-project>/dba-dbcompatibility-initcontainer
          tag: 19.0.3
        keytool_init_container:
          repository: <registry_url>:5000/<my-project>/dba-keytool-jobcontainer
          tag: 19.0.3   
        umsregistration_initjob:
          repository: <registry_url>:5000/<my-project>/dba-umsregistration-initjob
          tag: 19.0.3
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
   - [Configure IBM Automation Workstream Services](../../IAWS/README_config_ROKS.md)
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

Refer to the [Troubleshooting section](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_trbleshoot_operators.html) to access the operator logs.

## Step 8: Complete some post-installation steps

Go to [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_deploy_postdeployk8s.html) to follow the post-installation steps.
