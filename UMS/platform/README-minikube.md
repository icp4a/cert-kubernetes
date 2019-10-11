# Install User Management Service 19.0.2 on Minikube

User Management Service can be installed on Minikube. This documentation provides a step-by-step instruction on how to install UMS on Minikube for test purposes. The documentation therefore does not include steps to setup a production-ready database, create image policy or configure persistent volume.


## Step 1: Install Minikube and Tiller

1. Refer to the Kubernetes [documentation](https://kubernetes.io/docs/setup/minikube/#installation) to install Minikube and kubectl.

2. Start Minikube.

   ```bash
   minikube start
   ```

   This starts Minikube with the default memory of 2048 MB and 2 cpus.
   This is sufficient for a test install of User Management Service.

   > **Note**: If more cpus or memory are required, stop and delete it before restarting it with different parameters.
   ```bash
   minikube stop
   minikube delete
   minikube start --cpus 6 --memory 4096
   ```

3. Verify your installation.

   ```bash
   kubectl get nodes
   ```

4. Install [Helm 2.14.3](https://github.com/helm/helm/releases/tag/v2.14.3).

5. Install Tiller in the Minikube cluster.

   ```bash
   helm init
   ```

## Step 2: Download PPA and load images to the local content registry 

1.  Follow instructions to download User Management Service images and loadimages.sh file in [Download PPA and load images](https://github.com/icp4a/cert-kubernetes/blob/master/README.md#step-2-download-a-product-package-from-ppa-and-load-the-images)

   > **Note**: **DO NOT** run the loadimages.sh script at this point.

2. Configure your bash shell to use the Minikube built-in [Docker daemon](https://kubernetes.io/docs/setup/minikube/#use-local-images-by-re-using-the-docker-daemon).

   ```bash
   eval $(minikube docker-env)
   ```

   > **Note**: If you are not using the bash shell, execute ```minikube docker-env``` and see what environment variables this would set. Translate it to the corresponding command in your shell.

3. Use the following command to load the images in the Minikube local repository.

   ```bash
   git clone https://github.com/icp4a/cert-kubernetes.git
   cd cert-kubernetes
   scripts/loadimages.sh -l -p <PPA-ARCHIVE>.tgz -r ibmcom
   ```

   On success, the command prints a message such as:
   ```console
   Docker images load to ibmcom completed, and check the following images in the Docker registry:
     -  ibmcom/ums:19.0.2
     -  ibmcom/dba-keytool-initcontainer:19.0.2
     -  ibmcom/dba-keytool-jobcontainer:19.0.2
   ```

   Remember these values since we need them later.


## Step 3: Download helm chart
1. Download the helm chart [ibm-dba-ums-prod-1.0.0.tgz](../helm-charts/ibm-dba-ums-prod-1.0.0.tgz)
2. In a shell extract the downloaded package

   ```bash
   tar -xvf ibm-dba-ums-prod-1.0.0.tgz
   ```

   You find the main settings in the file `ibm-dba-ums-prod/values.yaml`.

## Step 4: Prerequisites and prepare myvalues.yaml

In order to install the User Management Service via helm, you need to create a file `myvalues.yaml` to override some defaults of `values.yaml`, such as your database specific settings. The following section explain the prerequisites and the corresponding settings in `myvalues.yaml`.

### Set the global settings and fill the image location

The `myvalues.yaml` requires some global settings:
The flag isOpenShift must be false, and the serviceType must be NodePort.
By default, Minikube accepts ports in the range 30000-32767.
The hostname should be choosen as the name that will be used to access the User Management Service.

```yaml
global:
  isOpenShift: false
  ums:
    serviceType: NodePort
    hostname: ums-hostname  # replace with your host name
    port: 30000
```

The `loadimages.sh` script has emitted the location of the images.
These need to be entered in `myvalues.yaml` as follows:
```yaml
images:
  ums: ibmcom/ums:19.0.2
  initTLS: ibmcom/dba-keytool-initcontainer:19.0.2
  ltpa: ibmcom/dba-keytool-jobcontainer:19.0.2
```
 

### Create a database
User Management Service needs a database to work.

The simplest test environment with a single replica can use a built-in derby database in the container. Data is not shared across multiple replicas and is lost upon restarting the pod. If these restrictions are acceptable for a simple demonstration environment, you can set `derby` as your database type in your `myvalues.yaml`
```yaml
oauth:
  database:
    type: derby
...
teamserver:
  database:
    type: derby
```
For sharing data between replicas and keeping data when restarting, you must use a remote database, which can be installed in the same kubernetes cluster or "standalone". Follow the instructions of your database vendor, e.g.
* [IBM Db2 Developer-C](https://github.com/IBM/charts/tree/master/stable/ibm-db2oltp-dev)
* IBM Db2 Advanced Enterprise Edition Helm Chart

If you install Db2 in the same kubernetes environment, you can access Db2 using a kubernetes service without exposing a port publicly. The database is available at service-name.namespace, see [Service discovery (kube-dns)
](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_3.1.2/manage_network/service_discovery.html).
For example, if you installed Db2 in namespace `db2` and created a service `umsdb-ibm-db2oltp-dev-db2`, you can use `umsdb-ibm-db2oltp-dev-db2.db2` as hostname:

```yaml
oauth:
  database:
    type: db2
    name: umsdb
    host: umsdb-ibm-db2oltp-dev-db2.db2
    port: 50000
```

### Create namespace
User Management Service should be installed into a dedicated namespace. Use the following command to create a namespace.

```bash
kubectl create namespace minikube-ums
```
Verify the name space:
```bash
kubectl get namespaces
```
This should show all namespaces, including the namespace minikube-ums.
All following kubectl commands need the option `--namespace=minikube-ums`.

### Generate TLS secret
To ensure the internal communication is secure, a TLS secret must be provided.
The secret can be generated by running the following command:
```bash
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt
```
This command queries for some additional information. Ensure that the Common Name is exactly the hostname (e.g. `ums-hostname`) choosen above.
The command generates two files: tls.crt and tls.key. They are used to generate the TLS secret:
```bash
kubectl create secret tls ibm-dba-ums-tls --key=tls.key --cert=tls.crt --namespace=minikube-ums
```

The name of this secret can be passed to helm as a parameter in `myvalues.yaml`

```yaml
tls:
  tlsSecretName: ibm-dba-ums-tls
```

We can also reuse the same secret as OAuth JWT secret in `myvalues.yaml`

```yaml
oauth:
  ...
  jwtSecretName: ibm-dba-ums-tls
```

### Generate UMS secret, DB secrets and LTPA generation secret

To avoid passing sensitive information via `myvalues.yaml`, three secrets need to be created before installing the chart. For these secrets, we use the separate file `ums-secret.yaml`.
1. Edit [ums-secret.yaml](../configuration/ums-secret.yaml)
2. For ibm-dba-ums-secret specify adminUser, adminPassword, sslKeystorePassword, jwtKeystorePassword, teamserverClientID, teamserverClientSecret and ltpaPassword
3. For ibm-dba-ums-db-secret specify oauthDBUser/outhDBPassword and tsDBUser/tsDBPassword.
4. For ibm-dba-ums-ltpa-creation-secret do nothing. Configuration will be performed during LTPA creation.
5. Save `ums-secret.yaml`
6. In a shell run this command to create the required secrets.

```bash
kubectl create -f ums-secret.yaml --namespace=minikube-ums
```

Secret names need to be passed to the chart via the global.ums.adminSecretName, global.ums.dbSecretName and global.ums.ltpaSecretName properties. The file `myvalues.yaml` should now contain:

```yaml
global:
  isOpenShift: false 
  ums:
    ...
    adminSecretName: ibm-dba-ums-secret
    dbSecretName: ibm-dba-ums-db-secret
    ltpaSecretName: ibm-dba-ums-ltpa-creation-secret
```

### Persistent Volume
This is optional. As this is the instruction for a test deployment of UMS, Persistent Volume configuration is not covered. A persistent volume is only required in order to mount
* JDBC drivers for a database other than Db2.
* custom truststore for connecting to LDAP securely
* custom binaries required by your Liberty configuration (such as a .jar file for a Trust Association Interceptor).

### Example myvalues.yaml

Review `values.yaml` and the `myvalues.yaml` file for your release to override defaults where necessary and to specify values for settings without defaults. Review `README.md` inside the helm chart for more details on the individual settings.

Here is an example `myvalues.yaml` for a DB2 database:

```yaml
global:
  isOpenShift: false 
  ums:
    serviceType: NodePort
    hostname: ums-hostname # replace with your hostname
    port: 30000
    adminSecretName: ibm-dba-ums-secret  # defined in ums-secret.yaml
    dbSecretName: ibm-dba-ums-db-secret  # defined in ums-secret.yaml
    ltpaSecretName: ibm-dba-ums-ltpa-creation-secret  # defined in ums-secret.yaml

# UMS Docker images
images:
  ums: ibmcom/ums:19.0.2
  initTLS: ibmcom/dba-keytool-initcontainer:19.0.2
  ltpa: ibmcom/dba-keytool-jobcontainer:19.0.2

# UMS certificate secret
tls:
  tlsSecretName: ibm-dba-ums-tls

# UMS OAuth config
oauth:
  database: # replace with your own db settings
    type: db2
    name: umsdb
    host: umsdb-ibm-db2oltp-dev-db2.db2
    port: 50000
  jwtSecretName: ibm-dba-ums-tls

# UMS Team Server database config
teamserver:
  database: # replace with your own db settings
    type: db2
    name: umsdb
    host: umsdb-ibm-db2oltp-dev-db2.db2
    port: 50000
```


## Step 5: Install the chart

After having created all prerequisites and customized `myvalues.yaml`, you can run

```bash
helm install --namespace minikube-ums --name ums-default -f myvalues.yaml ibm-dba-ums-prod-1.0.0.tgz --debug
```

This installs the User Management Service under the release name ums-default, which is the prefix of the pods that will be created.
The command returns within seconds, summarizing the resources that were created in the cluster.

If the install fails, delete the release ums-default first before trying to install it again:
```bash
helm del --purge ums-default
helm install --namespace minikube-ums --name ums-default -f myvalues.yaml ibm-dba-ums-prod-1.0.0.tgz --debug
```

## Step 6: Verify UMS installation

After the Minikube cluster completes the creation of resources and starting of pods, you can access User Management Service for basic function testing.

Use the following command to observe the current installation and pod starting status: 
```bash
kubectl get pods --namespace minikube-ums
```

During installation / startup, the status shows 0 ready pods.
```bash
kubectl get pods --namespace minikube-ums

NAME                                                    READY     STATUS      RESTARTS   AGE
ums-default-ibm-dba-ums-76d48486f5-4g9l6                0/1       Running     0          45s
ums-default-ibm-dba-ums-76d48486f5-wlfjv                0/1       Running     0          45s
ums-default-ibm-dba-ums-ltpa-creation-job-32881-czhqr   0/1       Completed   0          45s
```

Once the pods respond to readiness probes, the status will be updated:
```bash
kubectl get pods --namespace minikube-ums

NAME                                                READY     STATUS      RESTARTS   AGE
ums-default-ibm-dba-ums-8f9cc7c54-46mjw                 1/1       Running     0          33m
ums-default-ibm-dba-ums-8f9cc7c54-ml8bz                 1/1       Running     0          33m
ums-default-ibm-dba-ums-ltpa-creation-job-32881-czhqr   0/1       Completed   0          33m
```

> **Note:** The <release>-ibm-dba-ums-ltpa-creation-job-<random>-<random> pod is expected in completed state.

To see details of a pod, use the command:
```bash
kubectl describe pod ums-default-ibm-dba-ums-8f9cc7c54-46mjw --namespace minikube-ums
```

To see the services provided by the Minikube cluster:
```bash
kubectl get services --namespace minikube-ums

NAME                      TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
ums-default-ibm-dba-ums   NodePort   10.107.19.17   <none>        9443:30000/TCP   13m
``` 

To access the User Management Service from outside, see the DOCKER_HOST environment variable that was emitted by `minikube dockerenv`. For instance, if the DOCKER_HOST is an IP address 192.168.99.100, combine it with the Minikube port that was specified, to access https://192.168.99.100:30000/ums to view the login page. Log in as the administrative user you specified in ums-secret.yaml or any user of a connected LDAP if you included an LDAP configuration in myvalues.yaml customXML.

Congratulations, your UMS is now on Minikube.

