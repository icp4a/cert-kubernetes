# Deploying IBM Business Automation Studio on Red Hat OpenShift on IBM Cloud

These instructions are for installing IBM Business Automation Studio on a managed Red Hat OpenShift cluster on IBM Public Cloud.

## Table of contents

- [Prerequisites](#prerequisites)
- [Step 1: Preparing your client and environment on IBM Cloud](#step-1-preparing-your-client-and-environment-on-ibm-cloud)
- [Step 2: Preparing the OCP client environment](#step-2-preparing-the-ocp-client-environment)
- [Step 3: Downloading the package and uploading it to the local repository](#step-3-downloading-the-package-and-uploading-it-to-the-local-repository)
- [Step 4: Connecting OpenShift with CLI](#step-4-connecting-openshift-with-cli)
- [Step 5: Creating the databases](#step-5-creating-the-databases)
- [Step 6: Creating the routes](#step-6-creating-the-routes)
- [Step 7: Protecting sensitive configuration data](#step-7-protecting-sensitive-configuration-data)
- [Step 8: Configuring TLS key and certificate secrets](#step-8-configuring-tls-key-and-certificate-secrets)
- [Step 9: Preparing persistent storage](#step-9-preparing-persistent-storage)
- [Step 10: Installing Business Automation Studio 19.0.2 on platform Helm](#step-10-installing-business-automation-studio-1902-on-platform-helm)
- [Creating the Navigator service and configuring its UMS](#creating-the-navigator-service-and-configuring-its-ums)
- [References](#references)

## Prerequisites

  * [OpenShift 3.11](https://docs.openshift.com/container-platform/3.11/welcome/index.html) or later
  * [Helm and Tiller 2.9.1](https://github.com/helm/helm/releases) or later
  * [Cert Manager 0.8.0](https://cert-manager.readthedocs.io/en/latest/getting-started/install/openshift.html) or later
  * [IBM DB2 11.1.2.2](https://www.ibm.com/products/db2-database) or later
  * [IBM Cloud Pak For Automation - User Management Service](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.offerings/topics/con_ums.html)
  * Persistent volume support

Before you deploy, you must configure your IBM Public Cloud environment, create an OpenShift cluster and load the product images into the registry. Use the following information to configure your environment and deploy the images.

## Step 1: Preparing your client and environment on IBM Cloud

1. Create an account on [IBM Cloud](https://cloud.ibm.com/kubernetes/registry/main/start).
2. Create a cluster. 
   From the [IBM Cloud Overview page](https://cloud.ibm.com/kubernetes/overview), on the OpenShift Cluster tile, click **Create Cluster**.
   
3. Install the [IBM Cloud CLI](https://cloud.ibm.com/docs/containers?topic=containers-cs_cli_install).
4. Install the [OpenShift Container Platform CLI](https://docs.openshift.com/container-platform/3.11/cli_reference/get_started_cli.html#cli-reference-get-started-cli) to manage your applications and to interact with the system.
5. Install [Helm 2.9.1](https://www.ibm.com/links?url=https%3A%2F%2Fgithub.com%2Fhelm%2Fhelm%2Freleases%2Ftag%2Fv2.9.1) to install the Helm charts with Helm and Tiller.
6. Install the [Kubernetes CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
7. Install the [Docker CLI](https://cloud.ibm.com/docs/containers?topic=containers-cs_cli_install).
8. Get the storage class name for your OpenShift cluster:
   ```console
   $ oc get sc
   ```
  
## Step 2: Preparing the OCP client environment

**1. Log in to IBM Cloud using CLI**

   Open a terminal window on your client machine, then run the following commands:
      
```console
  ibmcloud login -u <IBM ID> -p <IBM_ID_Password> -c  <Account ID or owner user ID> -r <Name of region>
 ```
       -r value               Name of region, such as 'us-south' or 'eu-gb'
       -c value               Account ID or owner user ID (such as user@example.com)

```console
ibmcloud login -u <IBM ID> -p <IBM_ID_Password> -c <Account ID or owner user ID> -r <Name of region>
ibmcloud ks cluster ls
ibmcloud ks cluster config --cluster $cluster | grep export > env.sh
chmod 755 env.sh
. ./env.sh
echo $KUBECONFIG
kubectl version --short
 ```

**2. Configure IBM Cloud Container Registry**

   **a. Log in with your IBM Cloud account. Use “ibmcloud login --sso” to log in to IBM Cloud CLI**
   
 **Note:** After you press "Y" to open the URL in the default browser, IBM Cloud generates a one-time code in the browser. Copy and paste it, then press “Enter" to pass authentication.

```console
$ ibmcloud login --sso
API endpoint: https://cloud.ibm.com
Region: eu-gb
 
Get One Time Code from https://identity-2.ap-north.iam.cloud.ibm.com/identity/passcode to proceed.
Open the URL in the default browser? [Y/n] > yes
One Time Code >
Authenticating...
OK
 
Select an account:
1. XXXXXX's Account (0xxxxxxxxxxxxxxaa9xxx)
2. XXXXXXXX's Account (c56xxxxxxxxxxxxx74xxxxc) <-> 1...7
Enter a number> 2
Targeted account XXXXXXXX's Account (c56xxxxxxxxxxxxx74xxxxc) <-> 1...7
 
                     
API endpoint:      https://cloud.ibm.com  
Region:            eu-gb  
User:              xxxxxxx  
Account:           XXXXXXXX's Account (c56xxxxxxxxxxxxx74xxxxc) <-> 1...7
Resource group:    No resource group targeted, use 'ibmcloud target -g RESOURCE_GROUP'  
CF API endpoint:     
Org:                 
Space:                
 
Tip: If you are managing Cloud Foundry applications and services
- Use 'ibmcloud target --cf' to target Cloud Foundry org/space interactively, or use 'ibmcloud target --cf-api ENDPOINT -o ORG -s SPACE' to target the org/space.
- Use 'ibmcloud cf' if you want to run the Cloud Foundry CLI with current IBM Cloud CLI context.
 
 
New version 0.19.0 is available.
Release notes: https://github.com/IBM-Cloud/ibm-cloud-cli-release/releases/tag/v0.19.0
TIP: use 'ibmcloud config --check-version=false' to disable update check.
 
Do you want to update? [y/N] > y 
 
Installing version '0.19.0'...
Downloading...
 17.45 MiB / 17.45 MiB [========================================================================================] 100.00% 9s
18301051 bytes downloaded
Saved in /Users/ibm/.bluemix/tmp/bx_746509876/IBM_Cloud_CLI_0.19.0.pkg
```

If you encounter errors using "ibmcloud login --sso", you can run "ibmcloud login" and enter your user name and password instead.

   **b. Create a namespace**
    
```console
  $ ibmcloud cr namespace-add <my_namespace>
```

   **c. Check the cluster**
```console  
$ oc get pod
 ```
   **d. Log in to IBM Cloud Container Registry (cr)**
```console 
$ ibmcloud cr login
```
     Example output:
     
```console
$ ibmcloud cr login
Logging in to 'registry.eu-gb.bluemix.net'...
Logged in to 'registry.eu-gb.bluemix.net'.
 
IBM Cloud Container Registry is adopting new icr.io domain names to align with the rebranding of IBM Cloud for a better user experience. The existing bluemix.net domain names are deprecated, but you can continue to use them for the time being, as an unsupported date will be announced later. For more information about registry domain names, see https://cloud.ibm.com/docs/services/Registry?topic=registry-registry_overview#registry_regions_local
 
Logging in to 'us.icr.io'...
Logged in to 'us.icr.io'.
 
IBM Cloud Container Registry is adopting new icr.io domain names to align with the rebranding of IBM Cloud for a better user experience. The existing bluemix.net domain names are deprecated, but you can continue to use them for the time being, as an unsupported date will be announced later. For more information about registry domain names, see https://cloud.ibm.com/docs/services/Registry?topic=registry-registry_overview#registry_regions_local
 
OK
```
Get the container repository host from the "ibmcloud cr" login output. In this example, the Docker repository host is “us.icr.io”

   **e. Verify the images are in your private registry:**
```console
$ ibmcloud cr image-list
```
   **f. Create an API key**

       I. Log in to https://cloud.ibm.com.

       II. Select your own cluster account (upper right corner) and click IBM Cloud -> Security -> Manage -> Identity and Access -> Access (IAM) / IBM Cloud API Keys (left menu) --> Create an IBM Cloud API Key. Then download the API key or copy the API key.

       III. Return to your client terminal window and log in to the local Docker registry:
      
```console
docker login -u iamapikey -p <API_Key>  <docker-server>
```
        Example:
```console
$ docker login -u iamapikey -p <API_Key>  us.icr.io
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Login Succeeded
```
   **g. Create a Docker pull secret in your OpenShift cluster**
```console
oc create secret docker-registry ums-secret --docker-server=us.icr.io --docker-username=iamapikey --docker-password=<API_Key>
 ```
This secret will be passed to the chart in the imagePullSecrets property.  Check the "docker-server" name in the output of the previous command “ibmcloud cr login”.

## Step 3: Downloading the package and uploading it to the local repository
 
1. Download and save the [loadimages.sh](https://github.com/icp4a/cert-kubernetes/blob/master/scripts/loadimages.sh) script to the client machine.
2. Download the Business Automation Studio Passport Advantage packages by following the instructions in [IBM Cloud Pak for Automation 19.0.2 on Certified Kubernetes](https://github.com/icp4a/cert-kubernetes/blob/master/README.md#step-2-get-access-to-the-container-images).
3. Run the following commands to load the images into the Docker repository:
```console
$ ibmcloud cr namespace-add <my_namespace> 
 ```
Example:
```console
./loadimages.sh -p ./CC3I3ML.tgz -r us.icr.io/<my_namespace> 
./loadimages.sh -p ./CC3I4ML.tgz -r us.icr.io/<my_namespace> 
./loadimages.sh -p ./CC3I5ML.tgz -r us.icr.io/<my_namespace> 
./loadimages.sh -p ./CC3HVML.tgz -r us.icr.io/<my_namespace> 
 ```
The name "us.icr.io" is one of the IBM Cloud Container Registry names and your registry name might be different. Get the name from the "ibmcloud cr login" step.
 
4. Get the following Docker images in the IBM Cloud repository, which can be used for future Studio deployments:
```console
     -  us.icr.io/<my namespace>/solution-server:19.0.2
     -  us.icr.io/<my namespace>/dba-etcd:19.0.2
     -  us.icr.io/<my namespace>/solution-server-helmjob-db:19.0.2
     -  us.icr.io/<my namespace>/dba-keytool-initcontainer:19.0.2
     -  us.icr.io/<my namespace>/dba-umsregistration-initjob:19.0.2
     -  us.icr.io/<my namespace>/dba-dbcompatibility-initcontainer:19.0.2
     -  us.icr.io/<my namespace>/navigator:ga-306-icn-if002
     -  us.icr.io/<my namespace>/navigator-sso:ga-306-icn-if002
     -  us.icr.io/<my namespace>/ums:19.0.2
     -  us.icr.io/<my namespace>/dba-keytool-initcontainer:19.0.2
     -  us.icr.io/<my namespace>/dba-keytool-jobcontainer:19.0.2
     -  us.icr.io/<my namespace>/bastudio:19.0.2
     -  us.icr.io/<my namespace>/jms:19.0.2
     -  us.icr.io/<my namespace>/solution-server:19.0.2
     -  us.icr.io/<my namespace>/dba-etcd:19.0.2
     -  us.icr.io/<my namespace>/solution-server-helmjob-db:19.0.2
     -  us.icr.io/<my namespace>/dba-keytool-initcontainer:19.0.2
     -  us.icr.io/<my namespace>/dba-keytool-jobcontainer:19.0.2
     -  us.icr.io/<my namespace>/dba-umsregistration-initjob:19.0.2
     -  us.icr.io/<my namespace>/dba-dbcompatibility-initcontainer:19.0.2
```
## Step 4: Connecting OpenShift with CLI
1. Open a browser and log in to the IBM Cloud website (https://cloud.ibm.com) with your IBM Cloud ID, then navigate to the OpenShift category.
2. Find your OpenShift cluster instance in the Clusters list, select ..., and click OpenShift Web Console.
3. In the OpenShift Web Console, click your user ID (top right) and click Copy Login Command.
4. Paste the login command into the shell in your client machine terminal window:
```console      
 oc login https://<hostname_url>:<port> --token=<token>
 ```
5. Create or switch to the namespace you created by running the following command:
```console
 oc new-project <ocp project> && oc project <ocp project>
 ```
6. To deploy the service account, role, and role binding successfully, assign the administrator role to the user for this namespace by running the following command:
```console
 oc project <project-name>
 oc adm policy add-role-to-user admin <deploy-user-name>
```
7. If you want to operate persistent volumes (PVs), you must have the storage-admin cluster role, because PVs are a cluster resource in OpenShift. Add the role by running the following command:
```console
 oc adm policy add-cluster-role-to-user storage-admin <deploy-user-name>
```
 8. Grant scc ibm-anyuid-scc to your newly created namespace:
 ```console
oc adm policy add-scc-to-group ibm-anyuid-scc system:serviceaccounts:<ocp namespace>
```

## Step 5: Creating the databases

1. Prepare the databases for Studio and App Engine, following the instructions in [Creating databases](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_basprep_db.html).

## Step 6: Creating the routes

1. Choose the release name, for example, “ocp-bas”. You can replace  ```<release name>``` with your own release name in the examples that follow.

2. Choose the route names, for example, "bas-route" for Studio and "ae-route" for App Engine.

3. Prepare the YAML files for the routes. For example:

ums-route.yaml
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ums-route
  namespace: <your ocp namespace>
spec:
  port:
    targetPort: https
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: passthrough
  to:
    kind: Service
    name: <release name>-ibm-dba-ums
    weight: 100
  wildcardPolicy: None
```
bas-route.yaml:
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: bas-route
  namespace: <your ocp namespace>
spec:
  port:
    targetPort: https
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: passthrough
  to:
    kind: Service
    name: <release name>-bastudio-service
    weight: 100
  wildcardPolicy: None
```
ae-route.yaml:
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ae-route
  namespace: <your ocp namespace>
spec:
  port:
    targetPort: https
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: passthrough
  to:
    kind: Service
    name: <release name>-ibm-dba-ae-service
    weight: 100
  wildcardPolicy: None
```

4. Create the routes by running the following commands:
```console
oc create -f bas-route.yaml
oc create -f ae-route.yaml
```
5. Get the host names for Studio and App Engine. You will need them later.
 
a. Run the command "oc get route" to get the host name for each component.
```console
$ oc get route
NAME        HOST/PORT                                                                                                   PATH      SERVICES                       PORT      TERMINATION            WILDCARD
ae-route    ae-route-bastudio. <clusterLongName>.us-east.containers.appdomain.cloud              aa-ibm-dba-ae-service          https     passthrough/Redirect   None
bas-route   bas-route-bastudio. <clusterLongName>.us-east.containers.appdomain.cloud             aa-bastudio-service            https     passthrough/Redirect   None
rr-route    rr-route-bastudio. <clusterLongName>.us-east.containers.appdomain.cloud              aa-resource-registry-service   https     passthrough/Redirect   None
ums-route   ums-route-bastudio. <clusterLongName>.us-east.containers.appdomain.cloud             aa-ibm-dba-ums                 https     passthrough/Redirect   None
```
   
b. Find the host name ```“ums-route-bastudio.<clustername>.us-east.containers.appdomain.cloud”``` and write it down. You  will use it later when creating secrets.
 
c. Ping the host name to get the ip address.

```console
$ping ums-route-bastudio.<clusterLongName>.us-east.containers.appdomain.cloud
PING dbaclusterxxxxxxxxxxxxxx001.us-east.containers.appdomain.cloud (169.x.x.x) 56(84) bytes of data.
64 bytes from xxx.ip4.static.sl-reverse.com (169.x.x.x): icmp_seq=1 ttl=44 time=72.9 ms
64 bytes from xxx.ip4.static.sl-reverse.com (169.x.x.x): icmp_seq=2 ttl=44 time=72.7 ms
```
Write down the IP address 169.x.x.x. It will be used later in the <managed openshift proxy IP address>. For each route (ums-route, bas-route, ae-route, rr-route) write down the host name and IP address. 
 
## Step 7: Protecting sensitive configuration data

You must create the following secrets manually before you install the chart.

* Create the UMS Service following the instructions in [Install User Management Service 19.0.2 on Red Hat OpenShift on IBM Cloud](https://github.com/icp4a/cert-kubernetes/blob/master/UMS/platform/README-ROKS.md).

* Follow the instructions in [Preparing UMS-related configuration and TLS certificates](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_basprep_ums.html) to prepare UMS secrets.

* Follow the instructions in [Protecting sensitive configuration data](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_basprep_data.html) to prepare secrets for Resource Registry, App Engine, and Studio.

The following sample YAML files are for Resource Registry, App Engine, and Studio secrets. Update the values with your own user name, database information, and so on.

Resource Registry yaml:
```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name: resource-registry-admin-secret
  type: Opaque
  stringData:
    rootPassword: "<root-Password>"
    readUser: "reader"
    readPassword: "<reader-pwd>"
    writeUser: "writer"
    writePassword: "<writer-pwd>"
```

App Engine yaml:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ae-secret-credential
type: Opaque
stringData:
  AE_DATABASE_PWD: "<database-password>"
  AE_DATABASE_USER: "<database-username>"
  OPENID_CLIENT_ID: "app_engine"
  OPENID_CLIENT_SECRET: “<your oidc client password>“
  SESSION_SECRET: "bigblue123solutionserver"
  SESSION_COOKIE_NAME: "nsessionid"
  REDIS_PASSWORD: "password"
```
Business Automation Studio yaml:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bastudio-admin-secret
type: Opaque
stringData:
  adminUser: "umsadmin"
  adminPassword: "password"
  sslKeystorePassword: "<Your-ssl-Keystore-Password>"
  dbUsername: "<database-user>"
  dbPassword: "<database-password>"
  oidcClientId: "bastudio-liberty"
  oidcClientSecret: "tsSecret-jdaklfjsef"
```

## Step 8: Configuring TLS key and certificate secrets
Modify all values enclosed in angle brackets like ```<Example>``` in each of the following xxx.conf files with your own values.

Follow [Configuring the TLS key and certificate secrets](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_basprep_secrets.html) to create TLS certificate secrets for UMS, Studio, Resource Registry, and App Engine services.

1. Create the root CA.

Run the following three commands:
```console

openssl genrsa -out rootCA.key.pem 2048

openssl req -x509 -new -nodes -key rootCA.key.pem -sha256 -days 3650 \
        -subj "/CN=rootCA" \
        -out rootCA.crt.pem

kubectl create secret tls ca-tls-secret --key=rootCA.key.pem --cert=rootCA.crt.pem
```

2. Generate the UMS TLS key and certificate.
 
Example: ums-extfile.conf 
```console
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = <release name>-ibm-dba-ums
DNS.2 = <ums route long hostname>
DNS.3 = <ocp namespace>.svc.cluster.local
DNS.4 = svc.cluster.local
DNS.5 = localhost
IP.1 = <managed openshift proxy IP address>
```
Run the following four commands:
```console
openssl genrsa -out ums.key.pem 2048
openssl req -new -key ums.key.pem -out ums.csr \
        -subj "/CN=<ip address from above ums-route> "

openssl x509 -req -in ums.csr -CA rootCA.crt.pem \
             -CAkey rootCA.key.pem \
             -CAcreateserial \
             -out ums.crt.pem \
             -days 1825 -sha256 \
             -extfile ums-extfile.conf
kubectl create secret tls ums-tls-secret --key=ums.key.pem --cert=ums.crt.pem
```
3. Generate the UMS JKS TLS key and certificate.

Example ums-jks-extfile.conf
```console
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = <release name>-ibm-dba-ums
DNS.2 = <release name>-ibm-dba-ums.<ocp namespace>.svc.cluster.local
DNS.3 = svc.cluster.local
DNS.4 = localhost
DNS.5 = c100-e.us-east.containers.cloud.ibm.com
IP.1 = <managed openshift proxy IP address>
```
Run the following four commands:
```console
openssl genrsa -out ums-jks.key.pem 2048
openssl req -new -key ums-jks.key.pem -out ums-jks.csr \
        -subj "/CN= <ip address from above ums-route>"

openssl x509 -req -in ums-jks.csr -CA rootCA.crt.pem \
             -CAkey rootCA.key.pem \
             -CAcreateserial \
             -out ums-jks.crt.pem \
             -days 1825 -sha256 \
             -extfile ums-jks-extfile.conf
kubectl create secret tls ums-jks-tls-secret --key=ums-jks.key.pem --cert=ums-jks.crt.pem
```
4. Generate the Resource Registry TLS key and certificate.

Example rr-extfile.conf
```console
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = <release name >-resource-registry-service
DNS.2 = <rr route long hostname>
DNS.3 = <release name >-resource-registry-service.<ocp namespace>.svc.cluster.local
DNS.4 = svc.cluster.local
DNS.5 = localhost
DNS.6 = c100-e.us-east.containers.cloud.ibm.com
IP.1 = <managed openshift proxy IP address>
```
Run the following four commands:
```console
openssl genrsa -out rr.key.pem 2048
openssl req -new -key rr.key.pem -out rr.csr \
        -subj "/CN= <ip address from above rr-route>"

openssl x509 -req -in rr.csr -CA rootCA.crt.pem \
             -CAkey rootCA.key.pem \
             -CAcreateserial \
             -out rr.crt.pem \
             -days 1825 -sha256 \
             -extfile rr-extfile.conf
kubectl create secret tls rr-tls-secret --key=rr.key.pem --cert=rr.crt.pem
```
5. Generate the App Engine TLS key and certificate.

Example ae-extfile.conf
```console
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = <release name>-ibm-dba-ae-service
DNS.2 = <ae route long hostname>
DNS.3 = <release name>-ibm-dba-ae-service.<ocp namespace>.svc.cluster.local
DNS.4 = svc.cluster.local
DNS.5=localhost
DNS.6=c100-e.us-east.containers.cloud.ibm.com
IP.1 = <managed openshift proxy IP address>
```
Run the following four commands:

```console
openssl genrsa -out ae.key.pem 2048
openssl req -new -key ae.key.pem -out ae.csr \
        -subj "/CN=< ip address from above ae-route > "

openssl x509 -req -in ae.csr -CA rootCA.crt.pem \
             -CAkey rootCA.key.pem \
             -CAcreateserial \
             -out ae.crt.pem \
             -days 1825 -sha256 \
             -extfile ae-extfile.conf
kubectl create secret tls ae-tls-secret --key=ae.key.pem --cert=ae.crt.pem
```
6. Generate the Business Automation Studio TLS key and certificate.

Example bas-extfile.conf

```console
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = <release name>-bastudio-service
DNS.2 = <bas route long hostname>
DNS.3 = <release name>-bastudio-service.<ocp namespace>.svc.cluster.local
DNS.4 = svc.cluster.local
DNS.5 = localhost
DNS.6 = c100-e.us-east.containers.cloud.ibm.com
IP.1 =  <managed openshift proxy IP address>
```
Run the following four commands:
```console
openssl genrsa -out bas.key.pem 2048
openssl req -new -key bas.key.pem -out bas.csr \
        -subj "/CN=< ip address from above bas-route > "

openssl x509 -req -in bas.csr -CA rootCA.crt.pem \
             -CAkey rootCA.key.pem \
             -CAcreateserial \
             -out bas.crt.pem \
             -days 1825 -sha256 \
             -extfile bas-extfile.conf
kubectl create secret tls bas-tls-secret --key=bas.key.pem --cert=bas.crt.pem
```
7. Generate the IBM Content Navigator (ICN) TLS key and certificate.

Example icn-extfile.conf
```console
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = icn.<ip address from above ums-route>.nip.io
DNS.2 = svc.cluster.local
DNS.3 = localhost
IP.1 = <managed openshift proxy IP address>
```
Run the following four commands:
```console
openssl genrsa -out icn.key.pem 2048
openssl req -new -key icn.key.pem -out icn.csr \
        -subj "/CN=< ip address from above ums-route > "

openssl x509 -req -in icn.csr -CA rootCA.crt.pem \
             -CAkey rootCA.key.pem \
             -CAcreateserial \
             -out icn.crt.pem \
             -days 1825 -sha256 \
             -extfile icn-extfile.conf
kubectl create secret tls icn-tls-secret --key=icn.key.pem --cert=icn.crt.pem
```
8. Generate the JKS TLS key and certificate.

Example jks-extfile.conf
```console
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = <release name>-ibm-dba-ums
DNS.2 = ums.<managed openshift proxy IP address>.nip.io
DNS.3 = <release name>-ibm-dba-ums.<ocp namespace>.svc.cluster.local
DNS.4 = svc.cluster.local
IP.1 =  <managed openshift proxy IP address>
```
Run the following four commands:

```console
openssl genrsa -out jks.key.pem 2048
openssl req -new -key jks.key.pem -out jks.csr \
        -subj "/CN=< ip address from above ums-route > "

openssl x509 -req -in jks.csr -CA rootCA.crt.pem \
             -CAkey rootCA.key.pem \
             -CAcreateserial \
             -out jks.crt.pem \
             -days 1825 -sha256 \
             -extfile jks-extfile.conf
kubectl create secret tls jks-tls-secret --key=jks.key.pem --cert=jks.crt.pem
```

## Step 9: Preparing persistent storage

Follow the "Implementing storage" section of [IBM Business Automation Studio installation](https://github.com/icp4a/cert-kubernetes/blob/master/BAS/README.md) to prepare the persistent storage for Studio.

## Step 10: Installing Business Automation Studio 19.0.2 on platform Helm

To install the Business Automation Studio service on a managed Red Hat OpenShift cluster on IBM Public Cloud, choose one of the following options:
* To use Helm charts, follow the instructions in [Deploying with Helm charts](https://github.com/icp4a/cert-kubernetes/blob/master/BAS/helm-charts/README.md).

* To use YAML, follow the instructions in [Deploying with Kubernetes YAML](https://github.com/icp4a/cert-kubernetes/blob/master/BAS/k8s-yaml/README.md).

* To deploy the service on your own, complete the following steps:

**1. Download the Helm charts provided for certificates in the GitHub release pages:**
* Download ibm-dba-aae-prod-1.0.0.tgz from [AAE HELM](https://github.com/icp4a/cert-kubernetes/tree/master/AAE/helm-charts) 
* Download ibm-dba-bas-prod-1.0.0.tgz from [BAS HELM](https://github.com/icp4a/cert-kubernetes/tree/master/BAS/helm-charts) 


**Modify the sample values in the YAML files to match your own environment:**

```yaml
#Shared values across components
global:
  # The persistent volume claim name used to store JDBC and ODBC library
  existingClaimName: <Your-bas-jdbc-pvc>
  # Keep this value as false
  nonProductionMode: false
  # Secret with Docker credentials
  imagePullSecrets: ums-secret
  # global CA secret name
  caSecretName: "ca-tls-secret"
  # Kubernetes dns base name
  dnsBaseName: "svc.cluster.local"
  # Contributor toolkits storage PVC
  contributorToolkitsPVC: "<Your-shared-pvc-name>"
  # Global configuration created by user management service
  ums:
    serviceType: Ingress
    # Get UMS hostname from “oc get route” command
    hostname: "ums-route-bastudio. xxxxx.us-east.containers.appdomain.cloud"
    port: 443
    # Secret with admin credentials
    adminSecretName: ibm-dba-ums-secret

  # Global configuration created by BAStudio
  baStudio:
    serviceType: "Ingress"
    # Get BAStudio hostname from “oc get route” command
    hostname: "bas-route-bastudio. xxxxx.us-east.containers.appdomain.cloud”
    port: 443
    adminSecretName: bastudio-admin-secret
    jmsPersistencePVC:

  # Global configuration created by Resource Registry
  resourceRegistry:
    # Get RR hostname from “oc get route” command
    hostname: "rr-route-bastudio. xxxxx.us-east.containers.appdomain.cloud"
    port: 31099
    adminSecretName: resource-registry-admin-secret

  # Global configuration created by App Engine
  appEngine:
    serviceType: "Ingress"
    # Get AE hostname from “oc get route” command 
    hostname: "ae-route-bastudio.xxxxx.us-east.containers.appdomain.cloud"
    port: 443

# BAStudio private configurations here
baStudio:
  install: true
  # BAStudio private configurations here
  images:
    bastudio: us.icr.io/<your namespace>/bastudio:19.0.2
    umsInitRegistration: us.icr.io/<your namespace>/dba-umsregistration-initjob:19.0.2
    tlsInitContainer: us.icr.io/<your namespace>/dba-keytool-initcontainer:19.0.2
    ltpaInitContainer: us.icr.io/<your namespace>/dba-keytool-jobcontainer:19.0.2
    dbcompatibilityInitContainer: us.icr.io/<your namespace>/dba-dbcompatibility-initcontainer:19.0.2
    jmsContainer: us.icr.io/<your namespace>/jms:19.0.2
    pullPolicy: Always

  tls:
    tlsSecretName: bas-tls-secret
    tlsTrustList: []

  # Database config
  bastudioDB:
    database:
      type: db2
      name: BPMDB
      host: <your db host>
      port: <your db port>
      expectedSchemaVersion: "1.0.0"
      driverfiles: "db2jcc4.jar db2jcc_license_cu.jar"

  # BAStudio scaling config
  replicaCount: 1
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 5
    targetAverageUtilization: 80

  contentSecurityPolicy: upgrade-insecure-requests

  # BAStudio resource config
  resources:
    bastudio:
      limits:
        cpu: 4
        memory: 4Gi
      requests:
        cpu: 2
        memory: 3Gi
    initProcess:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 200m
        memory: 128Mi
    jms:
      limits:
        cpu: 1
        memory: 1G
      requests:
        cpu: 500m
        memory: 512Mi
  logs:
    consoleFormat: basic
    consoleLogLevel: INFO
    consoleSource: message,trace,accessLog,ffdc,audit
    traceFormat: ENHANCED
    traceSpecification: "*=info"

  # Health checks
  livenessProbe:
    initialDelaySeconds: 420
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
    successThreshold: 1
  readinessProbe:
    initialDelaySeconds: 240
    periodSeconds: 5
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1

appengine:
  install: true

  replicaCount: 1

  probes:
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 5
    failureThreshold: 3

  images:
    appEngine: us.icr.io/<your namespace>/solution-server:19.0.2
    tlsInitContainer: us.icr.io/<your namespace>/dba-keytool-initcontainer:19.0.2
    dbJob: us.icr.io/<your namespace>/solution-server-helmjob-db:19.0.2
    oidcJob: us.icr.io/<your namespace>/dba-umsregistration-initjob:19.0.2
    dbcompatibilityInitContainer: us.icr.io/<your namespace>/dba-dbcompatibility-initcontainer:19.0.2
    pullPolicy: Always

  tls:
    tlsSecretName: ae-tls-secret
    tlsTrustList: []

  database:
    name: APPDB
    host: <your db host>
    port: <your db port>
    type: db2
    currentSchema: DBASB
    initialPoolSize: 1
    maxPoolSize: 10
    uvThreadPoolSize: 4
    maxLRUCacheSize: 1000
    maxLRUCacheAge: 600000

  # Toggle for custom JDBC drivers
  useCustomJDBCDrivers: false

  adminSecretName: ae-secret-credential

  logLevel:
    node: trace
    browser: 2

  contentSecurityPolicy:
    enable: false
    whitelist: ""

  session:
    duration: "1800000"
    resave: "false"
    rolling: "true"
    saveUninitialized: "false"
    useExternalStore: "false"

  redis:
    host: localhost
    port: 6379
    ttl: 1800

  maxAge:
    staticAsset: "2592000"
    csrfCookie: "3600000"
    authCookie: "900000"

  env:
    serverEnvType: development
    maxSizeLRUCacheRR: 1000

  resources:
    ae:
      limits:
        cpu: 1500m
        memory: 1024Mi
      requests:
        cpu: 1
        memory: 512Mi
    initContainer:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 200m
        memory: 128Mi

  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 5
    targetAverageUtilization: 80

resourceRegistry:
  install: true

  # Private images for resource registry
  images:
    resourceRegistry: us.icr.io/<your namespace>/dba-etcd:19.0.2
    keytoolInitcontainer: us.icr.io/<your namespace>/dba-keytool-initcontainer:19.0.2
    pullPolicy: Always

  # TLS configurations
  tls:
    tlsSecretName: rr-tls-secret

  # Resource registry cluster size
  replicaCount: 1

  # RR Resource config
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi

  # data persistence config
  persistence:
    enabled: false
    useDynamicProvisioning: true
    storageClassName: "manual"
    accessMode: "ReadWriteOnce"
    size: 3Gi

  livenessProbe:
    enabled: true
    initialDelaySeconds: 120
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
    successThreshold: 1

  readinessProbe:
    enabled: true
    initialDelaySeconds: 15
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1

  logLevel: info
```
**2. Generate and customize the deployment YAML files:**

a.Generate the output folder:
```console
mkdir yamls
```
b.Generate the deployment YAML Files into the created folder:

```console
helm template --name <release name> --namespace <ocp namespace> --output-dir ./yamls -f bas-values.yaml ibm-dba-bas-prod-1.0.0.tgz
```
**3. Move to the bas-yamls folder. Remove the test folders:**
```console
   rm -rf ./yamls/ibm-dba-bas-prod/charts/appengine/templates/tests
   rm -rf ./yamls/ibm-dba-bas-prod/charts/baStudio/templates/tests
   rm -rf ./yamls/ibm-dba-bas-prod/charts/resourceRegistry/templates/tests
   rm -rf ./yamls/ibm-dba-bas-prod/templates/tests
```

**4. Apply the YAML definitions by running the following command:**
```console
kubectl apply -R -f ./yamls
```
    Your output should look similar to the following output:

```console
job.batch/aa-ibm-dba-ae-db-init-707 created
configmap/aa-ibm-dba-ae-env created
configmap/aa-ibm-dba-ae-file created
job.batch/aa-ibm-dba-ae-oidc-641 created
poddisruptionbudget.policy/aa-ibm-dba-ae-pdb-deployment-605 created
deployment.apps/aa-ibm-dba-ae-deployment created
serviceaccount/aa-ibm-dba-ae-deployment-access created
networkpolicy.networking.k8s.io/aa-ibm-dba-ae-db-init created
networkpolicy.networking.k8s.io/aa-ibm-dba-ae-npolicy-all created
networkpolicy.networking.k8s.io/aa-ibm-dba-ae-npolicy-deployment created
networkpolicy.networking.k8s.io/aa-ibm-dba-ae-npolicy-oidc created
networkpolicy.networking.k8s.io/aa-ibm-dba-ae-npolicy-test created
service/aa-ibm-dba-ae-service created
job.batch/aa-bastudio-bootstrap created
configmap/aa-bastudio-config created
deployment.apps/aa-bastudio-deployment created
service/aa-bastudio-jms-service created
statefulset.apps/aa-bastudio-jms created
job.batch/aa-bastudio-ltpa-395 created
secret/aa-bastudio-ltpa created
job.batch/aa-bastudio-oidc-127 created
poddisruptionbudget.policy/aa-bastudio-pdb-deployment-719 created
service/aa-bastudio-service created
poddisruptionbudget.policy/aa-bastudio-pdb-jms-107 created
role.rbac.authorization.k8s.io/aa-bastudio-init created
rolebinding.rbac.authorization.k8s.io/aa-bastudio-init created
serviceaccount/aa-bastudio-init created
networkpolicy.networking.k8s.io/aa-bastudio-npolicy-bas created
networkpolicy.networking.k8s.io/aa-bastudio-npolicy-bootstrap created
networkpolicy.networking.k8s.io/aa-bastudio-npolicy-default created
networkpolicy.networking.k8s.io/aa-bastudio-npolicy-jms created
networkpolicy.networking.k8s.io/aa-bastudio-npolicy-ltpa created
networkpolicy.networking.k8s.io/aa-bastudio-npolicy-oidc created
networkpolicy.networking.k8s.io/aa-bastudio-npolicy-test created
networkpolicy.networking.k8s.io/aa-bastudio-npolicy-upgrade created
serviceaccount/aa-bastudio-bastudio-sa created
poddisruptionbudget.policy/aa-resource-registry-pdb-516 created
service/aa-resource-registry-headless created
configmap/aa-resource-registry-script created
service/aa-resource-registry-service created
statefulset.apps/aa-resource-registry-server created
networkpolicy.networking.k8s.io/aa-resource-registry-npolicy-default created
networkpolicy.networking.k8s.io/aa-resource-registry-npolicy-test created
networkpolicy.networking.k8s.io/aa-resource-registry-networkpolicy created
serviceaccount/aa-resource-registry-sa created
networkpolicy.networking.k8s.io/aa-ibm-dba-base-npolicy-default created
networkpolicy.networking.k8s.io/aa-ibm-dba-base-npolicy-test created
serviceaccount/aa-ibm-dba-base-base-sa created
```

## Creating the Navigator service and configuring its UMS
1.	Create the Navigator service on Redhat Openshift on IBM Cloud:
* https://github.com/icp4a/cert-kubernetes/blob/19.0.1/NAVIGATOR/platform/README_Eval_ROKS.md

2.	Configure it to connect to UMS:
* https://www.ibm.com/support/pages/node/1073240

3.	Configure it to work with App Engine and IBM Business Automation Workflow using the following instructions:
* [Configuring App Engine with IBM Business Automation Navigator](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_basconfig_ban.html)
* [Publishing apps](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.bas/topics/tsk_bas_publishapps.html)
* [Configuring IBM Business Automation Studio with IBM Business Automation Workflow](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_basconfig_baw.html)

## References
* https://github.com/icp4a/cert-kubernetes/blob/master/AAE/README.md 
* https://github.com/icp4a/cert-kubernetes/blob/master/UMS/platform/README-ROKS.md
* https://github.com/icp4a/cert-kubernetes/blob/master/BAS/README.md
* https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_bas.html
* https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_install_bas.html

