# Install IBM Operational Decision Manager for developers on Red Hat OpenShift on IBM Cloud

IBM Operational Decision Manager for developers can be used on a personal computer to run and evaluate Operational Decision Manager in Red Hat OpenShift.

Refer to [Red Hat OpenShift on IBM Cloud documentation](https://cloud.ibm.com/docs/openshift?topic=openshift-openshift-create-cluster#openshift_create_cluster_console) to create a kubernetes cluster in IBM Cloud.

## Step 1: Install the Red Hat OpenShift Container Platform command line interface (CLI) and Helm

Refer to the [documentation](https://cloud.ibm.com/docs/openshift?topic=openshift-openshift-cli) to install:
* IBM Cloud CLI (`ibmcloud`)
* Kubernetes Service plug-in (`oc` alias for OpenShift clusters)

## Step 2: Install an Operational Decision Manager for developers release

> **Tip**: Storage Persistent Volume (PV) is required to install this evaluation. PV represents an underlying storage capacity in the infrastructure. PV must be created with accessMode ReadWriteOnce and storage capacity of 5Gi or more, before you install ODM. You create a PV in the Admin console or with a .yaml file.

1. Login to your IBM Cloud Kubernetes cluster:

   - Login to [IBM Cloud account](https://www.ibm.com/cloud) and select *Kubernetes* from the menu [hamburger menu icon].
   - Select the cluster and from the cluster details page, click **OpenShift web console**.
   - In the OpenShift web console menu bar, click your profile *IAM#user.name@email.com* > *Copy Login Command* and paste the copied `oc login` command into your terminal to authenticate:
     ```console
     $ oc login https://<CLUSTERNAME>:<CLUSTERPORT> --token=<GENERATED_TOKEN>
     ```

   > **Note**: As a privileged user, you must grant access to the privileged SCC to *IAM#user.name@email.com* and the default Service Account for project odmeval.
   > ```console
   > $ oc adm policy add-scc-to-user privileged -z default -n odmeval
   > $ oc adm policy add-scc-to-user privileged --serviceaccount=default -n odmeval
   > ```

2. Create a project to contain your release by running the following commands
   ```console
   $ oc new-project odmeval
   $ oc project odmeval
   ```


2. Run the following command to accept the license and install the release:

   ```console
   $ sed 's/view/accept/' ./configuration/odm-eval.yaml | oc create -f -
   ```

## Step 3: Verify that the deployment is running

1. Monitor the pod until it shows a STATUS of *Running* or *Completed*:

   ```console
   $ while oc get pods  | grep -E "(Running|Completed|STATUS)"; do sleep 5; done
   ```

2. When the pod is in *Running* state, you can access the status of your application with the following command:

   ```console
   $ oc status
   In project odmeval on server https://x.xx.xxx.xx:8443

   svc/odmeval-ibm-odm-dev (all nodes):30341 -> 9060
     deployment/odmeval-ibm-odm-dev deploys ibmcom/odm:8.10.x.x_2.x.x-amd64
       deployment #1 running for 34 minutes - 1 pod

   1 info identified, use 'oc status --suggest' to see details.
   ```

3. You can now expose the service to your users using routes:

   ```console
   $ oc create route passthrough --service=odmeval-ibm-odm-dev -n odmeval
   ```
   > **Note**: For more information, refer to the [Openshift documentation](https://docs.openshift.com/container-platform/3.11/dev_guide/routes.html).

> **Note**: You can use odmAdmin/odmAdmin for the user/password to access the applications.

## To uninstall the release

To uninstall and delete the release from the Kubernetes CLI, use the following command:

```console
$  oc delete -f odm-eval.yaml
```
