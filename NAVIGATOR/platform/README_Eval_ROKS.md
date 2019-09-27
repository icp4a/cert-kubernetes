# Deploying on Red Hat OpenShift on IBM Cloud

Before you deploy, you must configure your IBM Public Cloud environment, create an OpenShift cluster, prepare your Navigator environment, and load the product images to the registry. Use the following information to configure your environment and deploy the images.

## Before you begin: Create a cluster

Before you run any install command, make sure that you have created the IBM Cloud cluster, prepared your own environment, and loaded the product image to the registry.

For detailed information, see [Installing containers on Red Hat OpenShift by using CLIs](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_ROKS.html).

   
## Step 1: Prepare your Navigator environment

To prepare your Navigator environment, you set up databases, LDAP services, storage, and configuration files that are required for use and operation after deployment. 

Use the following instructions to prepare your Navigator environment: [Preparing to install IBM FileNet Content Manager](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_bank8s.html)

**Important:** The instructions provided for preparing storage are specific to non-managed OpenShift deployments. For OpenShift deployments, the cluster you create for OpenShift includes attached storage. As a result, you don't create persistent volumes for the storage- only the listed persistent volume claims. Obtain the storage class name for this OpenShift cluster storage, and assign that value as the `storageClassName` value when you create the required persistent volumes claims for your Navigator environment as described in [Creating volumes and folders for deployment on Kubernetes](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_ban_volumesk8s.html).

The following example uses the storage class name `ibmc-file-retain-bronze`:
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

## Step 2: Deploy the Business Automation Navigator images

When the container images are in the registry, you can complete environment configuration for each component and then run the chart installation.

1. Create a NGINX pod to mount the persistent volumes. The following sample creates a pod named `example-pod-ecm-eval`:  [NGINX Pod Sample](nginx_sample.yaml)

2. Copy the necessary database and LDAP configuration XML files that you prepared for your Navigator environment to the mounted volumes, for example, by accessing the NGINX pod that you created:
   ```console
   $ kubectl cp datasource.xml nginx-pod:/path/to/corresponding/directory
   ```
**Remember:** Make sure the permissions for all the folders set the user and group ownership to 50001:50000.

3. Use the instructions in the [Helm chart readme](../helm-charts) to confirm your environment configuration and install the Helm charts.


## Step 3: Enable Ingress to access your applications
1. Create an SSL certificate:
   ```console
   $ openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $(pwd)/tls.key -out $(pwd)/tls.crt -subj "/CN=dbamc.content
   ```
2. Create a secret using the certificate:
   ```console
   $ kubectl create secret tls icp4a  --key $(pwd)/tls.key --cert $(pwd)/tls.crt
   ```
3. Create an Ingress service for the Navigator component by using the example `ingress_service.yaml` file in the OpenShift console or CLI: [ingress_service.yaml](ingress_service.yaml)

4. Apply the Ingress service:
   ``` console
   $ kubectl apply -f ingress_service.yaml
   ```
5. Create an Ingress endpoint using the [ingress_icn.yaml](ingress_icn.yaml).
6. Apply the Ingress:
   ``` console
   $ kubectl apply -f ingress_icn.yaml
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
8. Copy the `newkey.jks` file to the `overrides` directory.
   ``` console
   $ cp $(pwd)/newkey.jks /some/directory/icn/configDropins/overrides
   ```
9. Create a new XML file, such as `key.xml`, and save it to the `configDropins/Overrides` folder:
   ``` xml
   <server>
      <keyStore id="defaultKeyStore" password="YOUR_PASSWORD" location="/opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/newkey.jks" />
   </server>
   ```   
10. Edit the deployments for all of the components to resolve the hostname in the pods:
    ``` console
    $ kubectl edit deployments dbamc-icn-ibm-dba-navigator
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
12. After you save your changes, new pods are created that include the changes. When the pods are up and running, update any existing repository connection. The new repository connection URL is something like: `https://icp4a-content/navigator`

13. On any system where you want to access the applications, update the localhost file `/etc/hosts` with the Ingress IP and the hostname.
