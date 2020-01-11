# Installing Cloud Pak for Automation 19.0.3 on Red Hat OpenShift

- [Step 1: Create a namespace and get access to the container images](install.md#step-1-create-a-namespace-and-get-access-to-the-container-images)
- [Step 2: Prepare your environment for automation software](install.md#step-2-prepare-your-environment-for-automation-software)
- [Step 3: Create a shared PV and add the JDBC drivers](install.md#step-3-create-a-shared-pv-and-add-the-jdbc-drivers)
- [Step 4: Deploy the operator manifest files to your cluster](install.md#step-4-deploy-the-operator-manifest-files-to-your-cluster)
- [Step 5: Configure the software that you want to install](install.md#step-5-configure-the-software-that-you-want-to-install)
- [Step 6: Apply the custom resources](install.md#step-6-apply-the-custom-resources)
- [Step 7: Verify that the automation containers are running](install.md#step-7-verify-that-the-automation-containers-are-running)
- [Step 8: Complete some post-installation steps](install.md#step-8-complete-some-post-installation-steps)

##  Step 1: Create a namespace and get access to the container images

From your local machine, you can access the container images in the IBM Docker registry with your IBMid (Option 1), or you can use the downloaded archives from IBM Passport Advantage (PPA) (Option 2).

1. Log in to your cluster.
   ```bash
   $ oc login https://<CLUSTERIP>:8443 -u <ADMINISTRATOR>
   ```
2. Create an OpenShift project (namespace) in which you want to install the operator.
   ```bash
   $ oc new-project my-project
   ```
3. Add privileges to the project.
   ```bash
   $ oc adm policy add-scc-to-user privileged -z default
   ```
4. Download or clone the repository on your local machine and change to `cert-kubernetes` directory
   ```bash
   $ git clone git@github.com:icp4a/cert-kubernetes.git
   $ cd cert-kubernetes
   ```
   You will find there the scripts and kubernetes descriptors that are necessary to install Cloud Pak for Automation.

### Option 1: Create a pull secret for the IBM Cloud Entitled Registry

1. Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

2. In the **Container software library** tile, click **View library** and then click **Copy key** to copy the entitlement key to the clipboard.

3. Create a pull secret by running a `kubectl create secret` command.
   ```bash
   $ kubectl create secret docker-registry <my_secret_name> --docker-server=cp.icr.io --docker-username=cp --docker-password="<API_KEY_GENERATED>" --docker-email=<USER_EMAIL>
   ```

   > **Note**: The `cp.icr.io` value for the **docker-server** parameter is the only registry domain name that contains the images.

4. Take a note of the secret and the server values so that you can set them to the **pullSecrets** and **repository** parameters when you run the operator for your containers.

### Option 2: Download the packages from PPA and load the images

[IBM Passport Advantage (PPA)](https://www-01.ibm.com/software/passportadvantage/pao_customer.html) provides archives (.tgz) for the software. To view the list of Passport Advantage eAssembly installation images, refer to the [19.0.3 download document](https://www.ibm.com/support/pages/ibm-cloud-pak-automation-v1903-download-document).

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

   You can also log in to an external Docker registry using the following command:
   ```bash
   $ docker login <registry_url> -u <your_account>
   ```
4. Run a `kubectl` command to make sure that you have access to Kubernetes.
   ```bash
   $ kubectl cluster-info
   ```
5. Run the [`scripts/loadimages.sh`](../../scripts/loadimages.sh) script to load the images into your Docker registry. Specify the two mandatory parameters in the command line.

   ```
   -p  PPA archive files location or archive filename
   -r  Target Docker registry and namespace
   -l  Optional: Target a local registry
   ```

   The following example shows the input values in the command line on OCP 3.11. On OCP 4.2 the default docker registry is based on the host name, for example "default-route-openshift-image-registry.ibm.com".

   ```
   # scripts/loadimages.sh -p <PPA-ARCHIVE>.tgz -r docker-registry.default.svc:5000/my-project
   ```

   > **Note**: The project must have pull request privileges to the registry where the images are loaded. The project must also have pull request privileges to push the images into another namespace/project.

6. Check that the images are pushed correctly to the registry.
    ```bash
    $ oc get is
    ```
7. (Optional) If you want to use an external Docker registry, create a Docker registry secret.

   ```bash
   $ oc create secret docker-registry <secret_name> --docker-server=<registry_url> --docker-username=<your_account> --docker-password=<your_password> --docker-email=<your_email>
   ```

   Take a note of the secret and the server values so that you can set them to the **pullSecrets** and **repository** parameters when you run the operator for your containers.


## Step 2: Prepare your environment for automation software

Before you install any of the containerized software:

1. Go to the prerequisites page in the [IBM Cloud Pak for Automation 19.0.x](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_prepare_env_k8s.html) Knowledge Center.
2. Follow the instructions on preparing your environment for the software components that you want to install.

  How much preparation you need to do depends on what you want to install and how familiar you are with your environment.

## Step 3: Create a shared PV and add the JDBC drivers

1. Create a persistent volume (PV) for the operator. This PV is needed for the JDBC drivers. The following example YAML defines a PV, but PVs depend on your cluster configuration. 
   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     labels:
       type: local
     name: operator-shared-pv
   spec:
     capacity:
       storage: 1Gi
     accessModes:
       - ReadWriteMany
     hostPath:
       path: "/root/operator"
     persistentVolumeReclaimPolicy: Delete
   ```

2. Deploy the PV.
   ```bash
   $ oc create -f operator-shared-pv.yaml
   ```

3. Create a claim for the PV, or check that the PV is bound dynamically, [descriptors/operator-shared-pvc.yaml](../../descriptors/operator-shared-pvc.yaml?raw=true).

   > Replace the storage class if you do not want to create the relevant persistent volume.

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: operator-shared-pvc
     namespace: my-project
   spec:
     accessModes:
       - ReadWriteMany
     storageClassName: ""
     resources:
       requests:
         storage: 1Gi
     volumeName: operator-shared-pv
   ```

4. Deploy the PVC.
   ```bash
   $ oc create -f descriptors/operator-shared-pvc.yaml
   ```

5. Copy all of the JDBC drivers that are needed by the components you intend to install to the persistent volume. Depending on your storage configuration you might not need these drivers.

   > **Note**: File names for JDBC drivers cannot include additional version information.
     - DB2:
        - db2jcc4.jar
        - db2jcc_license_cu.jar
     - Oracle:
        - ojdbc8.jar

    The following structure shows an example remote file system.

    ```
    pv-root-dir

       └── jdbc

          ├── db2

          │   ├── db2jcc4.jar

          │   └── db2jcc_license_cu.jar

          ├── oracle

          │   └── ojdbc8.jar

    ```

## Step 4: Deploy the operator manifest files to your cluster

The Cloud Pak operator has a number of descriptors that must be applied.
  - [descriptors/ibm_cp4a_crd.yaml](../../descriptors/ibm_cp4a_crd.yaml?raw=true) contains the description of the Custom Resource Definition.
  - [descriptors/operator.yaml](../../descriptors/operator.yaml?raw=true) defines the deployment of the operator code.
  - [descriptors/role.yaml](../../descriptors/role.yaml?raw=true) defines the access of the operator.
  - [descriptors/role_binding.yaml](../../descriptors/role_binding.yaml?raw=true) defines the access of the operator.
  - [descriptors/service_account.yaml](../../descriptors/service_account.yaml?raw=true) defines the identity for processes that run inside the pods of the operator.    

1. Deploy the icp4a-operator on your cluster.

   Use the script [scripts/deployOperator.sh](../../scripts/deployOperator.sh) to deploy these descriptors.
   ```bash
   $ ./scripts/deployOperator.sh -i <registry_url>/icp4a-operator:19.0.3 -p '<my_secret_name>'
   ```

   Where *registry_url* is the value for your internal docker registry or `cp.icr.io/cp/cp4a` for the IBM Cloud Entitled Registry and *my_secret_name* the secret created to access the registry.

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

4. Use the following links to configure the software that you want to install, and you need to make sure the irrelevant softwares are fully commented or removed including the top level of ***_configuration.

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

## Step 6: Apply the custom resource

1. Check that all the components you want to install are configured.

   ```bash
   $ cat descriptors/my_icp4a_cr.yaml
   ```

2. Deploy the configured components by applying the custom resource.

   ```bash
   $ oc apply -f descriptors/my_icp4a_cr.yaml
   ```

## Step 7: Verify that the automation containers are running

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
