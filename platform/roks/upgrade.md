# Upgrading from IBM Cloud Pak for Automation 19.0.3 to 20.0.1 on IBM Cloud

If you installed any of the Cloud Pak for Automation 19.0.3 components on an IBM Cloud cluster and you want to continue to use them in 20.0.1, you can upgrade them.

> **Note:** If you are looking to upgrade Automation Digital Worker (ADW) 19.0.3 to 20.0.1, you must contact [IBM Support]( https://www.ibm.com/mysupport/s/) and open a support case. After your case is submitted, IBM support contacts you. 

## Step 1: Get access to the new container images

Follow the instructions in step 1 of [Installing Cloud Pak for Automation 20.0.1 on Red Hat OpenShift](install.md#step-1-create-a-namespace-and-get-access-to-the-container-images) to clone the 20.0.1 GitHub repository and to get access to the new docker images.

## Step 2: Update the operator version number to 20.0.1

1. Log in to your IBM Cloud cluster. In the OpenShift web console menu bar, click your profile *IAM#user.name@email.com* > *Copy Login Command* and paste the copied command into your command line.
   ```bash
   $ oc login https://<CLUSTERNAME>:<CLUSTERPORT> --token=<GENERATED_TOKEN>
   ```
2. Run a `kubectl` command to make sure that you have access to Kubernetes.
   ```bash
   $ kubectl cluster-info
   ```
3. Go to the downloaded `cert-kubernetes.git` for 20.0.1, and change directory to cert-kubernetes.
   ```bash
   $ cd cert-kubernetes
   ```
4. Upgrade the icp4a-operator on your cluster.

   Use the 20.0.1  [scripts/upgradeOperator.sh](../scripts/upgradeOperator.sh) script to deploy the operator manifest descriptors.
   ```bash
   $ ./scripts/upgradeOperator.sh -i <registry_url>/icp4a-operator:20.0.1 -p '<my_secret_name>' -a accept
   ```

   Where *registry_url* is the value for your internal docker registry or `cp.icr.io/cp/cp4a` for the IBM Cloud Entitled Registry, *my_secret_name* is the secret created to access the registry, and *accept* means that you accept the [license](../../LICENSE).

   > **Note**: If you plan to use a non-administrator user to install the operator, you must add the user to the `ibm-cp4-operator` role. For example:
   ```bash
   $ oc adm policy add-role-to-user ibm-cp4a-operator <user_name>
   ```   

## Step 3: Update the image versions in the custom resource YAML file for your deployment

Get the custom resource YAML file that you deployed and edit it by following the instructions for each component:

- [Configure IBM Automation Workstreams Services](../../IAWS/README_upgrade.md)
- [Configure IBM Business Automation Application Engine](../../AAE/README_upgrade.md)
- [Configure IBM Business Automation Content Analyzer](../../ACA/README_upgrade.md)
- [Configure IBM Business Automation Insights](../../BAI/README_upgrade.md)
- [Configure IBM Business Automation Navigator](../../BAN/README_upgrade.md)
- [Configure IBM Business Automation Studio](../../BAS/README_upgrade.md)
- [Configure IBM FileNet Content Manager](../../FNCM//README_upgrade.md)
- [Configure IBM Operational Decision Manager](../../ODM/README_upgrade.md)
- [Configure the User Management Service](../../UMS/README_upgrade.md)

## Step 4: Apply the updated custom resource to upgrade from 19.0.3 to 20.0.1

1. Check that all the components that you want to upgrade are configured.

   ```bash
   $ cat descriptors/my_icp4a_cr.yaml
   ```

2. Update the configured components by applying the custom resource.

   ```bash
   $ oc apply -f descriptors/my_icp4a_cr.yaml
   ```

## Step 5: Verify the applications

The operator reconciliation loop might take several minutes.

Monitor the status of your pods with:
```bash
$ oc get pods -w
```

Log in to the web applications in your deployment and verify that they are ready and can be accessed.
