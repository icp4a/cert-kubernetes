# Deploying on Red Hat OpenShift on IBM Cloud

Before you deploy, you must configure your IBM Public Cloud environment and create an OpenShift cluster. Use the following information to configure your environment and deploy the images.


## Step 1: Prepare your client and environment on IBM Cloud

1. Create an account on [IBM Cloud](https://cloud.ibm.com/kubernetes/registry/main/start).
2. Create a cluster. 
   From the [IBM Cloud Overview page](https://cloud.ibm.com/kubernetes/overview), in the OpenShift Cluster tile, click **Create Cluster**.

   A cluster comes with attached storage, so you do not need to create persistent volumes.
3. Create a persistent volume claim with a storage class. The following example uses the name `ibmc-file-retain-bronze`:
   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: example-pvc
     namespace: default
   spec:
     accessModes:
       - ReadWriteMany
     resources:
       requests:
         storage: 8Gi
     storageClassName: ibmc-file-retain-bronze
   ```
4. Download the [loadimages.sh](scripts/loadimages.sh) script.
5. Download the desired IBM PassPort Advantage eAssembly images from the [IBM Cloud Pak for Automation V19.0.1 Download Document](https://www-01.ibm.com/support/docview.wss?uid=ibm10878709).
6. Install the [IBM Cloud CLI](https://cloud.ibm.com/docs/containers?topic=containers-cs_cli_install).
7. Install the [OpenShift Container Platform CLI](https://docs.openshift.com/container-platform/3.11/cli_reference/get_started_cli.html#cli-reference-get-started-cli) to manage your applications and to interact with the system.
8. Install [Helm 2.9.1](https://www.ibm.com/links?url=https%3A%2F%2Fgithub.com%2Fhelm%2Fhelm%2Freleases%2Ftag%2Fv2.9.1) to install the Helm charts with Helm and Tiller.
9. Install the [Kubernetes CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
10. Install the [Docker CLI](https://cloud.ibm.com/docs/containers?topic=containers-cs_cli_install).
11. Install the Container Registry plug-in:
    ```console
    $ ibmcloud plugin install container-registry -r Bluemix
    ```
## Step 2: Push the images to the IBM Cloud Container Registry

Push the downloaded images to your private registry.

1. Log in to your IBM Cloud account. Use <code>ibmcloud login --sso</code> to log in to the IBM Cloud CLI.
2. Create a namespace.
   ```console
   $ ibmcloud cr namespace-add <my_namespace>
   ```
3. Check the cluster:
   ```console
   $ oc get pod
   ```
4. Log your local Docker daemon into the IBM Cloud Container Registry.
   ```console
   $ ibmcloud cr login
   ```
5. Push and tag the images to the cluster registry:
   ```console
   $ ./loadimages.sh -p <image_name>-x86_64.tar.gz -r us.icr.io/<my_namespace>
   ```
6. Verify that your images are in your private registry.
   ```console
   $ ibmcloud cr image-list
   ```
7. Create an API key. 
   a. From the [Manage access and users page](https://cloud.ibm.com/iam/overview), click **Service IDs > Create**.
   b. Add the Service ID name and description, and click **Create**. 
   c. Click the **API keys** tab, click **Create**, and provide a name and description.
8. Create a pull secret: 
   ```console
   $ oc create secret docker-registry <YOUR_SECRET_NAME> --docker-server=us.icr.io --docker-username=iamapikey --docker-password=<CHANGE_ME_API_KEY>
   ```
## Step 3: Deploy the FileNet Content Manager images
When the container images are in the registry, you can continue to set up the environment for each component and then run the chart installation.

1. Create a NGINX pod to mount the persistent volumes. The following sample creates a pod named 'example-pod-ecm-eval':  [NGINX Pod Sample](https://github.ibm.com/dba/cert-kubernetes/blob/19.0.1/CONTENT/platform/nginx_sample.yaml)
2. Create the necessary databases for FileNet Content Engine products by modifying the data source XML files to match your database server and LDAP server information. YAML file templates are found in the [**overrides** folders](https://github.com/icp4a/cert-kubernetes/tree/19.0.1/CONTENT/configration/CPE/configDropins/overrides) 
3. Copy the necessary configuration files to the mounted volumes by accessing the NGINX pod that you created.
   ```console
   $ kubectl cp datasource.xml nginx-pod:/path/to/corresponding/directory
   ```
4. Make sure the permissions for all the folders set the user and group ownership to 50001:50000.
5. Use the instructions in the [Helm chart readme](https://github.com/icp4a/cert-kubernetes/tree/19.0.1/CONTENT/helm-charts) to confirm your environment configuration and install the Helm charts.

## Step 4: Enable Ingress to access your applications
1. Create an SSL certificate.
   ```console
   $ openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $(pwd)/tls.key -out $(pwd)/tls.crt -subj "/CN=dbamc.content
   ```
2. Create a secret using the certificate:
   ```console
   $ kubectl create secret tls icp4a  --key $(pwd)/tls.key --cert $(pwd)/tls.crt
   ```
3. Create an Ingress service for all of the Content components by using the example 'ingress_service.yaml' file in the OpenShift console or CLI: [ingress_service.yaml] (https://github.ibm.com/dba/cert-kubernetes/blob/19.0.1/CONTENT/platform/ingress_service.yaml)
4. Apply the Ingress service:
   ``` console
   $ kubectl apply -f ingress_service.yaml
   ```
5. Create single Ingress endpoint using the [ingess_one.yaml](https://github.ibm.com/dba/cert-kubernetes/blob/19.0.1/CONTENT/platform/ingress_one.yaml)
6. Apply the Ingress:
   ``` console
   $ kubectl apply -f ingess_one.yaml
   ```
7. To use the Ingress for the repository connection URL in Navigator, CMIS, External Share, and GraphQL run the following commands:
   ```console
   $ openssl pkcs12 -export -in $(pwd)/tls.crt -inkey $(pwd)/tls.key -out $(pwd)/newkey.p12
   ```
   ```console
   $ keytool -importkeystore -srckeystore $(pwd)/newkey.p12 \
      -srcstoretype PKCS12 \
      -destkeystore $(pwd)/newkey.jks \
      -deststoretype JKS
   ```
8. Copy the 'newkey.jks' file to the `overrides` directory.
   ``` console
   $ cp $(pwd)/newkey.jks /some/directory/icn/configDropins/overrides
   ```
9. Create a new XML file, for example, `key.xml`, and save it to the `configDropins/Overrides` folder:
   ``` xml
   <server>
      <keyStore id="defaultKeyStore" password="YOUR_PASSWORD" location="/opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/newkey.jks" />
   </server>
   ```   
10. Edit the deployments for all of the components to resolve the hostname in the pods:
    ``` console
    $ kubectl edit deployments dbamc-cpe-ibm-dba-contentservices
    ```
    Add the following lines in the section `spec.template.spec`.
    ``` yaml
    hostAliases:       
       - ip: "<INGRESS IP>"         
    hostnames:         
       - "dbamc.content"
    ```
11. Get the Ingress IP by running the following command:
    ``` console
    $ kubectl get ingress
    ```   
12. After you save your changes, new pods are created that include the changes. When the pods are up and running, update any existing repository connection. The new repository connection URL is something like: `https://icp4a-content/wsi/FNCEWS40MTOM/`
13. Update the localhost file `/etc/hosts` with the Ingress IP and the hostname.
