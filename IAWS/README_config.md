# Configuring IBM Automation Workstream Services 19.0.3
Learn how to configure IBM Automation Workstream Services.


## Table of contents
- [Introduction](#Introduction)
- [Automation Workstream Services component details](#Automation-Workstream-Services-component-details)
- [Resources required](#Resources-required)
- [Prerequisites](#Prerequisites)
- [Step 1: Preparing to install Automation Workstream Services for production](#Step-1-Preparing-to-install-Automation-Workstream-Services-for-production)
  - [Setting up an OpenShift environment](#Setting-up-an-OpenShift-environment)
  - [Preparing SecurityContextConstraints](#Preparing-SecurityContextConstraints)
- [Step 2: Preparing databases for Automation Workstream Services](#Step-2-Preparing-databases-for-Automation-Workstream-Services)
  - [Creating the database for Automation Workstream Services](#Creating-the-database-for-Automation-Workstream-Services)
  - [(Optional) Db2 SSL Configuration](#Optional-Db2-SSL-Configuration)
  - [(Optional) Db2 HADR Configuration](#Optional-Db2-HADR-Configuration)
- [Step 3: Preparing to configure LDAP](#Step-3-Preparing-to-configure-LDAP)
- [Step 4: Preparing storage](#Step-4-Preparing-storage)
  - [Disabling swapping and increasing the limit on the number of file descriptors](#Disabling-swapping-and-increasing-the-limit-on-the-number-of-file-descriptors)
  - [Preparing storage for Process Federation Server](#Preparing-storage-for-Process-Federation-Server)
  - [Preparing storage for Java Messaging Service](#Preparing-storage-for-Java-Messaging-Service)
- [Step 5: Protecting sensitive configuration data](#Step-5-Protecting-sensitive-configuration-data)
  - [Creating required secrets for Automation Workstream Services](#Creating-required-secrets-for-Automation-Workstream-Services)
  - [Creating the Lombardi custom secret](#Creating-the-lombardi-custom-secret)
- [Step 6: Configuring the Custom Resource YAML file to deploy Automation Workstream Services](#Step-6-Configuring-the-Custom-Resource-YAML-file-to-deploy-Automation-Workstream-Services)
  - [Adding prerequisite configuration sections](#Adding-prerequisite-configuration-sections)
  - [Disabling the Content Platform Engine initialization and verification sections](#Disabling-the-content-platform-engine-initialization-and-verification-sections)
  - [Adding the required Automation Workstream Services configuration section](#Adding-the-required-Automation-Workstream-Services-configuration-section)
  - [Custom configuration](#Custom-configuration)
- [Step 7: Completing the installation](#Step-7-Completing-the-installation)
- [Step 8: Completing post-deployment tasks](#Step-8-Completing-post-deployment-tasks)
  - [Configuring the Content Platform Engine](#Configuring-the-Content-Platform-Engine)
- [Step 9: Verifying Automation Workstream Services](#Step-9-Verifying-Automation-Workstream-Services)
- [Limitations](#Limitations)
- [Troubleshooting](#Troubleshooting)



## Introduction
The IBM Automation Workstream Services operator deploys the Workstream server, a server engine that runs workstreams that are configured and launched in IBM Workplace.


## Automation Workstream Services component details
The standard configuration includes these components:

- IBM Business Automation Workflow Server component
- IBM Java Messaging Service component
- IBM Process Federation Server component

To support those components, a standard installation generates the following content:

- 4 ConfigMaps that manage the configuration
- 1 StatefulSet running Java Messaging Service
- 1 StatefulSet running Workstream server
- 1 StatefulSet running Process Federation Server
- 4 or more jobs for Workstream server
- 3 service accounts with related role and role binding
- 20 secrets to gain access during installation
- 7 services and Route to route the traffic to the App Engine


## Resources required
Follow the instructions in [Planning your installation](https://docs.openshift.com/container-platform/3.11/install/index.html#single-master-single-box). Then, based on your environment, check the required resources in [System and environment requirements](https://docs.openshift.com/container-platform/3.11/install/prerequisites.html) and set up your environment.

| Component name | Container | CPU | Memory |
| --- | --- | --- | --- |
| IBM Automation Workstream Services | Workstream container | 2 | 3Gi |
| IBM Automation Workstream Services | Init containers | 200m | 128Mi |
| IBM Automation Workstream Services | IBM Java Messaging Service containers | 500m | 512Mi |
| IBM Automation Workstream Services | IBM Process Federation Service containers | 1500m | 2560Mi |


## Prerequisites
- [OpenShift 3.11 or later](https://docs.openshift.com/container-platform/3.11/welcome/index.html)
- [IBM DB2 11.5](https://www.ibm.com/products/db2-database)
- [User Management Service](../UMS/README_config.md)
- [Automation Application Engine](../AAE/README_config.md)
- [Business Automation Navigator](../BAN/README_config.md)
- [FileNet Content Manager](../FNCM/README_config.md)



## Step 1: Preparing to install Automation Workstream Services for production
In addition to performing the steps required to set up the operator environment, complete the following steps before you install Automation Workstream Services.

### Setting up an OpenShift environment
Before you prepare to install Automation Workstream Services, complete [Step 1 to Step 5](../platform/ocp/install.md).

### Preparing SecurityContextConstraints
#### Creating a SecurityContextConstraint for Automation Workstream Services
Create a SecurityContextConstraint for Automation Workstream Services that looks like the following content and save it to the ibm-dba-iaws-scc.yaml file. Then add this ibm-dba-iaws-scc SCC  to all service accounts in a namespace:
```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: ibm-dba-iaws-scc
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegeEscalation: true
allowPrivilegedContainer: false
allowedCapabilities: []
defaultAddCapabilities: []
fsGroup:
  type: RunAsAny
groups:
- system:authenticated
readOnlyRootFilesystem: false
requiredDropCapabilities:
- KILL
- MKNOD
- SETUID
- SETGID
runAsUser:
  type: MustRunAsRange
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
users: []
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
priority: 1
```

Run the following commands:

```sh
$ oc apply -f ibm-dba-iaws-scc.yaml
$ oc adm policy add-scc-to-group ibm-dba-iaws-scc system:serviceaccounts:<NAMESPACE_NAME>
```

#### Creating a SecurityContextConstraint for Process Federation Server
If pfs_configuration.elasticsearch.privileged is set to true, you must create a SecurityContextConstraint for Process Federation Server that looks like the following content and save it to the ibm-pfs-privileged-scc.yaml file. Then add this ibm-pfs-privileged-scc SCC to the ibm-pfs-es-service-account Process Federation Server Elasticsearch default service account in the current namespace:

```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: ibm-pfs-privileged-scc
allowHostDirVolumePlugin: true
allowHostIPC: true
allowHostNetwork: true
allowHostPID: true
allowHostPorts: true
allowPrivilegedContainer: true
allowPrivilegeEscalation: true
allowedCapabilities:
- '*'
allowedFlexVolumes: []
allowedUnsafeSysctls:
- '*'
defaultAddCapabilities: []
defaultAllowPrivilegeEscalation: true
forbiddenSysctls: []
fsGroup:
  type: RunAsAny
readOnlyRootFilesystem: false
requiredDropCapabilities: []
runAsUser:
  type: RunAsAny
seccompProfiles:
- '*'
seLinuxContext:
  type: RunAsAny
supplementalGroups:
  type: RunAsAny
volumes:
- '*'
priority: 2
```

Run the following commands:

```sh
$ oc create serviceaccount ibm-pfs-es-service-account
$ oc apply -f ibm-pfs-privileged-scc.yaml
$ oc adm policy add-scc-to-user ibm-pfs-privileged-scc -z ibm-pfs-es-service-account
```

**Tip:** You can use the [`getSCCs.sh`](https://github.com/IBM/cloud-pak/tree/master/samples/utilities) bash script, which displays all the SecurityContextConstraints resources that are mapped to each of the ServiceAccount users in the specified namespace (or project).

**Note:** Specify the value of property `pfs_configuration.elasticsearch.service_account` to the newly created service account `ibm-pfs-es-service-account` in your Custom Resource configuration.



## Step 2: Preparing databases for Automation Workstream Services
### Creating the database for Automation Workstream Services
Create the database for Automation Workstream Services by running the following script on the Db2 server:
```sql
create database <IAWS_DB_NAME> automatic storage yes using codeset UTF-8 territory US pagesize 32768;
-- connect to the created database:
connect to <IAWS_DB_NAME>;
-- A user temporary tablespace is required to support stored procedures in BPM.
CREATE USER TEMPORARY TABLESPACE USRTMPSPC1;
UPDATE DB CFG FOR <IAWS_DB_NAME> USING LOGFILSIZ 16384 DEFERRED;
UPDATE DB CFG FOR <IAWS_DB_NAME> USING LOGSECOND 64 IMMEDIATE;
-- The following grant is used for databases without enhanced security.
-- For more information, review the IBM Knowledge Center for Enhancing Security for DB2.
grant dbadm on database to user <DB_USER>;
connect reset;
```

**Notes:**
- Replace `<IAWS_DB_NAME>` with the Automation Workstream Services database name you want, for example, BPMDB.
- Replace `<DB_USER>` with the user you will use for the database.


### (Optional) Db2 SSL Configuration
To ensure that all communications between the Business Automation Workflow server and Db2 are encoded, you must import the database CA certificate to the Business Automation Workflow server. To do so, you must create a secret to store the certificate:
```
kubectl create secret generic ibm-dba-baw-db2-cacert --from-file=cacert.crt=
```

**Note:** You must modify the part that points to the certificate file. Do not change the part --from-file=cacert.crt=.

You can then use the resulting secret to set the `iaws_configuration[x]. wfs.database.sslsecretname: ibm-dba-baw-db2-cacert`, while setting `iaws_configuration[x].wfs.database.ssl` to `true`.

### (Optional) Db2 HADR Configuration
If you use Db2 as your database, you can configure high availability by setting up HADR for the process server database. This configuration ensures that the process server automatically retrieves the necessary failover server information when it first  connects to the database. As part of the setup, you must provide a comma-separated list of failover servers and failover ports.

For example, if there are two failover servers:

    server1.db2.customer.com on port 50443
    server2.db2.customer.com on port 51443

you can specify these hosts and ports in the Custom Resource configuration YAML file as follows:
```yaml
database:
  ... ...
    hadr:
      standbydb_host: server1.db2.customer.com, server2.db2.customer.com
      standbydb_port: 50443,51443
      retryintervalforclientreroute: <default value is 10 min>
      maxretriesforclientreroute: <default value is 5>
  ... ...
```



## Step 3: Preparing to configure LDAP
An LDAP server is required before you install Automation Workstream Services. Save the following content in a file named `ldap-bind-secret.yaml`. Then apply it by running the `oc apply -f ldap-bind-secret.yaml` command:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ldap-bind-secret
type: Opaque
data:
  ldapUsername: <LDAP_BIND_DN>
  ldapPassword: <LDAP_PASSWORD
```

**Notes:**
- Ensure `ldapUsername` corresponds to the **bindDN** property of your LDAP server with **base64** encoded.
- Ensure `ldapPassword` corresponds to the **bindPassword** property of your LDAP server with **base64** encoded.
- Specify the hostname of your LDAP server in the `ldap_configuration.lc_ldap_server` property.
- Specify the secret name you created above in the `ldap_configuration.lc_bind_secret` property.




## Step 4: Preparing storage
### Disabling swapping and increasing the limit on the number of file descriptors
For node stability and performance, disable memory swapping on all worker nodes. For detailed information, see [Disable swapping for Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/setup-configuration-memory.html). Also, Elasticsearch uses a lot of file descriptors and running out of file descriptors can lead to data loss. Make sure to increase the limit on the number of open file descriptors for the user running Elasticsearch.

By default, `pfs_configuration.elasticsearch.privileged` is set to `true`. In this scenario privileged containers will do the above configuration.

If privileged containers are not allowed, set the property `pfs_configuration.elasticsearch.privileged` to `false` in the Custom Resource configuration. Then ask the cluster administrator to run the following command to change the swap and max_map_count:

```
sysctl -w vm.max_map_count=262144 && sed -i '/^vm.max_map_count /d' /etc/sysctl.conf && echo 'vm.max_map_count = 262144' >> /etc/sysctl.conf && sysctl -w vm.swappiness=1 && sed -i '/^vm.swappiness /d' /etc/sysctl.conf && echo 'vm.swappiness=1' >> /etc/sysctl.conf
```

### Preparing storage for Process Federation Server
The Process Federation Server component requires persistent volumes (PVs), persistent volume claims (PVCs), and related folders to be created before you can deploy. The deployment process uses these volumes and folders during the deployment.

The following example illustrates the procedure using Network File System (NFS). An existing NFS server is required before creating persistent volumes and persistent volume claims.

- Creating folders for Process Federation Server on an NFS server

For the NFS server, you must grant minimal privileges, In the `/etc/exports` configuration file, add the following line at the end:
```
<pfs_storage_directory_path> *(rw,sync,no_subtree_check)
```

**Notes:**
- `<pfs_storage_directory_path>` should be an individual directory and NOT shared with other components.
- **Restart NFS service** after editing and saving `/etc/exports` configuration file.


Give the least privilege to the mounted directories using the following commands: 
```bash
sudo mkdir <pfs_storage_directory_path>/pfs-es-0
sudo mkdir <pfs_storage_directory_path>/pfs-es-1
sudo mkdir <pfs_storage_directory_path>/pfs-logs-0
sudo mkdir <pfs_storage_directory_path>/pfs-logs-1
sudo mkdir <pfs_storage_directory_path>/pfs-output-0
sudo mkdir <pfs_storage_directory_path>/pfs-output-1

chown -R :65534 <pfs_storage_directory_path>/pfs-*
chmod g+rw <pfs_storage_directory_path>/pfs-*
```

- Creating persistent volumes required for Process Federation Server

Save the following YAML files on the OpenShift master node and run the `oc apply -f <YAML_FILE_NAME>` command on the files in the following order.

1. pfs-pv-pfs-es-0.yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pfs-es-0
spec:
  storageClassName: "pfs-es"
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 10Gi
  nfs:
    path: <pfs_storage_directory_path>/pfs-es-0
    server: <NFS_SERVER_IP>
  persistentVolumeReclaimPolicy: Recycle
```

2. pfs-pv-pfs-es-1.yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pfs-es-1
spec:
  storageClassName: "pfs-es"
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 10Gi
  nfs:
    path: <pfs_storage_directory_path>/pfs-es-1
    server: <NFS_SERVER_IP>
  persistentVolumeReclaimPolicy: Recycle
```

3. pfs-pv-pfs-logs-0.yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pfs-logs-0
spec:
  storageClassName: "pfs-logs"
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 5Gi
  nfs:
    path: <pfs_storage_directory_path>/pfs-logs-0
    server: <NFS_SERVER_IP>
  persistentVolumeReclaimPolicy: Recycle
```

4. pfs-pv-pfs-logs-1.yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pfs-logs-1
spec:
  storageClassName: "pfs-logs"
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 5Gi
  nfs:
    path: <pfs_storage_directory_path>/pfs-logs-1
    server: <NFS_SERVER_IP>
  persistentVolumeReclaimPolicy: Recycle
```

5. pfs-pv-pfs-output-0.yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pfs-output-0
spec:
  storageClassName: "pfs-output"
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 5Gi
  nfs:
    path: <pfs_storage_directory_path>/pfs-output-0
    server: <NFS_SERVER_IP>
  persistentVolumeReclaimPolicy: Recycle
```

6. pfs-pv-pfs-output-1.yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pfs-output-1
spec:
  storageClassName: "pfs-output"
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 5Gi
  nfs:
    path: <pfs_storage_directory_path>/pfs-output-1
    server: <NFS_SERVER_IP>
  persistentVolumeReclaimPolicy: Recycle
```

**Notes:**
- Replace `<pfs_storage_directory_path>` with the Process Federation Server storage folder on your NFS server.
- Replace `<NFS_SERVER_IP>` with your NFS server IP address.

### Preparing storage for Java Messaging Service
The Java Messaging Service(JMS) component requires you to create a persistent volume and a related folder to be created before you can deploy. 

The following example illustrates the procedure using NFS. An existing NFS server is required before creating PVs.

- Creating folders for JMS on an NFS server

For the NFS server, you must grant minimal privileges, In the `/etc/exports` configuration file, add the following line at the end:
```
<jms_storage_directory_path> *(rw,sync,no_subtree_check)
```

**Notes:**
- `<jms_storage_directory_path>` should be an individual directory and do NOT shared with other components.
- **Restart the NFS service** after editing and saving the `/etc/exports` configuration file.

Give the least privilege to the mounted directories using the following commands: 
```bash
sudo mkdir <jms_storage_directory_path>/jms
chown -R :65534 <jms_storage_directory_path>/jms
chmod g+rw <jms_storage_directory_path>/jms
```

- Creating persistent volumes for JMS

Save the following YAML files on the OpenShift master node and run the `oc apply -f <YAML_FILE_NAME>` command.
jms-pv.yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jms-pv
spec:
  storageClassName: "jms-storage-class"
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 2Gi
  nfs:
    path: <jms_storage_directory_path>/jms
    server: <NFS_SERVER_IP>
  persistentVolumeReclaimPolicy: Recycle
```

**Notes:**
- Replace `<jms_storage_directory_path>` with the JMS storage folder on your NFS server.
- `accessModes` should be set to the same value as the `iaws_configuration[x].wfs.jms.storage.access_modes` property in the Custom Resource configuration file.
- Replace `<NFS_SERVER_IP>` with your NFS server IP address.



## Step 5: Protecting sensitive configuration data
### Creating required secrets for Automation Workstream Services
A secret is an object that contains a small amount of sensitive data such as a password, a token, or a key. Before you install Automation Workstream Services, you must create the following secrets manually by saving the content in a YAML file and running the `oc apply -f <YAML_FILE_NAME>` command on the OpenShift master node.

Shared encryption key secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: icp4a-shared-key-secret
type: Opaque
data:
  encryptionKey: <ENCRYPTION_KEY>
```
**Notes:**
- So that the confidential information is shared only between the components that hold the key, use the encryptionKey to encrypt the confidential information at the Resource Registry.
- Ensure the encryptionKey is **base64** encoded.

Business Automation Workflow server secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ibm-baw-baw-secret
type: Opaque
data:
  adminUsername: <LDAP_USER>
  adminPassword: <LDAP_USER_PASSWORD>
  sslKeyPassword: <SSL_KEY_PASSWORD>
  oidcClientPassword: <OIDC_CLIENT_PASSWORD>
```
**Note:**
- `adminUsername` and `adminPassword` is the valid LDAP user who will be configured as the admin user of Automation Workstream Services. The password is necessary because it will be created on the Liberty server.
- `sslKeyPassword` will be used as the keystore or trust store password.
- `oidcClientPassword` will be registered with the User Manaement Service(UMS) as the OIDC client password.
- Ensure all values under data are **base64** encoded.

Business Automation Workflow server database secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ibm-baw-wfs-server-db-secret
type: Opaque  
data:
  dbUser: <DB_USER>
  password: <DB_USER_PASSWORD>
```
**Notes:**
- `dbUser` and `password` are the database user name and password respectively. 
- Ensure all values under data are **base64** encoded.

Workstream server integration with IBM Content Platform Engine secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cpe-admin-secret
type: Opaque  
data:
  adminUsername: <LDAP_USER>
  adminPassword: <LDAP_USER_PASSWORD>
```
**Notes:**
- `adminUsername` and `adminPassword` are the Content Platform Engine admin user credentials.
- Ensure all values under data are **base64** encoded.

Process Federation Server secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ibm-pfs-admin-secret
type: Opaque
data:
  ltpaPassword: <LTPA_PASSWORD>
  oidcClientPassword: <OIDC_CLIENT_PASSWORD>
  sslKeyPassword: <SSL_KEY_PASSWORD>
```

**Notes:**
- `sslKeyPassword` is used as the keystore and trust store password.
- `oidcClientPassword` is registered at with UMS as the OIDC client password.
- Ensure all values under data are **base64** encoded.

### Creating the Lombardi custom secret
#### 1. Save the following content in a file named '100Custom.xml'.
```xml
<properties>                                                                                                                                                                                       
  <!--Properties file for customer cluster scoped properties-->                                                                                                                                    
  <server merge="mergeChildren">                                                                                                                                                                   
    <search-index merge="mergeChildren">                                                                                                                                                           
        <!-- For the instance list, we need up-to-date process instance status on all task documents -->                                                                                           
        <task-index-update-completed-tasks merge="replace">true</task-index-update-completed-tasks>                                                                                                
     </search-index>                                                                                                                                                                               
 </server>                                                                                                                                                                                         
</properties>
```

#### 2. Create the Lombardi custom secret
Run the following command on the OpenShift master node:
```
kubectl create secret generic wfs-lombardi-custom-xml-secret --from-file=sensitiveCustomConfig=./100Custom.xml
```

**Note:** To overwrite the Lombardi configuration settings, specify the value of the `iaws_configuration[x].wfs.lombardi_custom_xml_secret_name` property as the newly created secret name `wfs-lombardi-custom-xml-secret` in the Custom Resource configuration file.



## Step 6: Configuring the Custom Resource YAML file to deploy Automation Workstream Services
### Adding prerequisite configuration sections
Make sure that you've set the configuration parameters for the following components in your copy of the template Custom Resource YAML file:

- [User Management Service](../UMS/README_config.md)
- [Automation Application Engine](../AAE/README_config.md)
- [Business Automation Navigator](../BAN/README_config.md)
- [FileNet Content Manager](../FNCM/README_config.md)

### Disabling the Content Platform Engine initialization and verification sections
To ensure that the Content Platform Engine initialization can be completed successfully, remove the `initialize_configuration` and `verify_configuration` sections from the template Custom Resource YAML file.

### Adding the required Automation Workstream Services configuration section
Edit your copy of the template custom resource YAML file and make the following updates. 
- Uncomment and update the shared_configuration section if you haven't done it already.

- Update the `iaws_configuration` and `pfs_configuration` sections.
  To install Automation Workstream Services, replace the contents of `iaws_configuration` and `pfs_configuration` in your copy of the template Custom Resource YAML file with the values from the [sample_min_value.yaml](configuration/sample_min_value.yaml) file.

### Custom configuration
If you want to customize your Custom Resource YAML file, you can refer to the [configuration list](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_iaws_params.html) to update the required values of each parameter according to your environment.


## Step 7: Completing the installation
Go back to the relevant installation or update page to configure other components and complete the deployment with the operator.

Installation pages:
   - [OpenShift installation page](../platform/ocp/install.md)
   - [Certified Kubernetes installation page](../platform/k8s/install.md)

Update pages:
   - [OpenShift installation page](../platform/ocp/update.md)
   - [Certified Kubernetes installation page](../platform/k8s/update.md)


## Step 8: Completing post-deployment tasks
### Configuring the Content Platform Engine

- [Creating the P8Domain manually](https://www.ibm.com/support/knowledgecenter/SSGLW6_5.5.0/com.ibm.p8.install.doc/p8pin328.htm)
- [Creating a database connection manually](https://www.ibm.com/support/knowledgecenter/SSGLW6_5.5.0/com.ibm.p8.install.doc/p8pin327.htm)
- [Creating object stores manually](https://www.ibm.com/support/knowledgecenter/SSGLW6_5.5.0/com.ibm.p8.install.doc/p8pin034.htm)

**Notes:**
- The domain name must be the same as the value of the `iaws_configuration[x].wfs.content_integration.domain_name` property in the Custom Resource configuration file.
- The database connection-related parameters should be from one of the object store databases in the `datasource_configuration.dc_os_datasources` section defined in the Custom Resource configuration file, which is already persisted as datasource configuration inside the Content Platform Engine container.
- The Object Store name must be the same as the value of the `iaws_configuration[x].wfs.content_integration.object_store_name` property in the Custom Resource configuration file.

## Step 9: Verifying Automation Workstream Services
1. Get the name of the pods that were deployed by running the following command:
```
oc get pod -n <NAMESPACE_NAME>
```

<div>
<details>
<summary>Click to show a successful Automation Workstream Service pod status. </summary>
<p>

```
NAME                                                         READY     STATUS      RESTARTS   AGE
demo-cmis-deploy-7f79f86db-crhwb                             1/1       Running     0          18m
demo-cpe-deploy-774c856dfb-ss9p8                             1/1       Running     0          21m
demo-dba-rr-63f407861c                                       1/1       Running     0          24m
demo-dba-rr-7557164eb9                                       1/1       Running     0          24m
demo-dba-rr-875b9f4a8f                                       1/1       Running     0          24m
demo-ibm-pfs-0                                               1/1       Running     0          8m
demo-ibm-pfs-dbareg-5d4b47577f-sp6qk                         1/1       Running     0          8m
demo-ibm-pfs-elasticsearch-0                                 2/2       Running     0          8m
demo-ibm-pfs-umsregistry-job-bqvv6                           0/1       Completed   0          8m
demo-instance1-aae-ae-db-job-9bb4p                           0/1       Completed   0          9m
demo-instance1-aae-ae-deployment-bdf69b4d7-qpj5t             1/1       Running     0          9m
demo-instance1-aae-ae-oidc-job-fgzzv                         0/1       Completed   0          9m
demo-instance1-baw-jms-0                                     1/1       Running     0          10m
demo-instance1-ibm-iaws-ibm-workplace-init-job-wnvcm         0/1       Completed   0          10m
demo-instance1-ibm-iaws-server-0                             1/1       Running     0          10m
demo-instance1-ibm-iaws-server-content-init-job-7k64r        1/1       Running     1          10m
demo-instance1-ibm-iaws-server-database-init-job-czmdn       0/1       Completed   0          10m
demo-instance1-ibm-iaws-server-database-init-job-pfs-zzlwr   0/1       Completed   0          10m
demo-instance1-ibm-iaws-server-ltpa-kh76r                    0/1       Completed   0          10m
demo-instance1-ibm-iaws-server-umsregistry-job-zt7rj         0/1       Completed   0          10m
demo-navigator-deploy-64cc4f44f-hnqbf                        1/1       Running     0          15m
demo-rr-setup-pod                                            0/1       Completed   0          24m
demo-ums-deployment-86b4d9bc6b-bwkvn                         1/1       Running     0          23m
demo-ums-ltpa-creation-job-zkdxb                             0/1       Completed   0          24m
ibm-cp4a-operator-69569b68c8-d49v2                           2/2       Running     0          31m
```

</p>
</details>
</div>

2. For each pod, check under Events to see that the images were successfully pulled and the containers were created and started by running the following command with the specific pod name:
```
oc describe pod <POD_NAME> -n <NAMESPACE_NAME>
```



## Limitations

* Automation Workstream Services supports only the IBM Db2 database.

* Elasticsearch limitation

  **Note:** The following limitation only applies if you are updating an Automation Workstream Services deployment which uses the embedded Elasticsearch statefulset
  
  * Scaling Elasticsearch statefulet
  
  In the Elasticsearch configuration, the [discovery.zen.minimum_master_nodes property](https://www.elastic.co/guide/en/elasticsearch/reference/6.7/discovery-settings.html#minimum_master_nodes) is automatically set by the operator to the quorum of replicas of the Elasticsearch statefulset. If, during an update, the pfs_configuration.elasticsearch.replicas value is changed and the change leads to a new computed value for the discovery.zen.minimum_master_nodes configuration property, then all currently running Elasticsearch pods will have to be restarted. During this restart of the pods, there will be a temporary interruption of Elasticsearch and Process Federation Server services.
  * Elasticsearch High Availability

  In the Elasticsearch configuration, the [discovery.zen.minimum_master_nodes property](https://www.elastic.co/guide/en/elasticsearch/reference/6.7/discovery-settings.html#minimum_master_nodes) is automatically set by the operator to the quorum of replicas of the Elasticsearch statefulset. If at some point, some Elasticsearch pods fail and the number of running Elastisearch pods is less than the quorum of replicas of the Elasticsearch statefulset, there will be an interruption of Elasticsearch and Process Federation Server services, until at least the quorum of running Elasticsearch pods is satisfied again.

* Resource Registry limitation:

  Because of the design of etcd, it's recommended that you don't change the replica size after you create the Resource Registry cluster to prevent data loss. If you must set the replica size, set it to an odd number. If you reduce the pod size, the pods are destroyed one by one slowly to prevent data loss or the cluster from becoming out of sync.
  * If you update the Resource Registry admin secret to change the username or password, first delete the <instance_name>-dba-rr-<random_value> pods to cause Resource Registry to enable the updates. Alternatively, you can enable the update manually with etcd commands.
  * If you update the Resource Registry configurations in the icp4acluster custom resource instance, the update might not affect the Resource Registry pod directly. It will affect the newly created pods when you increase the number of replicas.

* The App Engine trusts only Certification Authority (CA) because of a Node.js server limitation. If an external service is used and signed with another root CA, you must add the root CA as trusted instead of the service certificate.

  * The certificate can be self-signed, or signed by a well-known CA.
  * If you're using a depth zero self-signed certificate, it must be listed as a trusted certificate.
  * If you're using a certificate signed by a self-signed CA, the self-signed CA must be in the trusted list. Using a leaf certificate in the trusted list is not supported.
  * If you're adding the root CA of two or more external services to the App Engine trust list, you can't use the same common name for those root CAs.



## Troubleshooting
- How to check check pod status and related logs for Automation Workstream Services 

There are 12 Automation Workstream Services-related pods in total, Run the oc get pod command to see the status of each pod:
```
NAME                                                         READY     STATUS      RESTARTS   AGE
demo-ibm-pfs-0                                               1/1       Running     0          2h
demo-ibm-pfs-dbareg-5fc759c745-mgsdv                         1/1       Running     1          1h
demo-ibm-pfs-elasticsearch-0                                 2/2       Running     0          2h
demo-ibm-pfs-umsregistry-job-g2qt5                           0/1       Completed   0          2h
demo-instance1-baw-jms-0                                     1/1       Running     0          2h
demo-instance1-ibm-iaws-ibm-workplace-init-job-nz9vw         0/1       Completed   0          2h
demo-instance1-ibm-iaws-server-0                             1/1       Running     0          2h
demo-instance1-ibm-iaws-server-content-init-job-qv9ms        1/1       Completed   12         2h
demo-instance1-ibm-iaws-server-database-init-job-pfs-cfvs5   0/1       Completed   0          2h
demo-instance1-ibm-iaws-server-database-init-job-t8gjt       0/1       Completed   0          2h
demo-instance1-ibm-iaws-server-ltpa-gzhwp                    0/1       Completed   0          2h
demo-instance1-ibm-iaws-server-umsregistry-job-hglww         0/1       Completed   0          2h
...
```

For pods controlled by Job, the desired `STATUS` is `Completed` and desired `READY` is `0/1`, while for pods controlled by Deployment or StatefulSet, the desired `STATUS` is `Running` and desired `READY` is `1/1` or `2/2`. You can see detailed information for each pod by running the `oc describe pod <POD_NAME>` command and you can see detailed logs by running the `oc logs <POD_NAME>` command. Although a pod should be in the `Running` Status at first, if a pod does not change its status, you can use the previous commands to determine what’s causing the blocks.

<div>
<details>
<summary>Click to show an example of how to analyze the Pod "demo-instance1-ibm-iaws-server-0". </summary>
<p>

```yaml
[root@rhel76 ~]# oc describe pod demo-instance1-ibm-iaws-server-0
Name:               demo-instance1-ibm-iaws-server-0
Namespace:          demo-project
Priority:           0
PriorityClassName:  <none>
Node:               rhel76/<OPENSHIFT_MASTER_IP>
Start Time:         Mon, 02 Dec 2019 14:06:10 +0800
Labels:             app.kubernetes.io/component=server
                    app.kubernetes.io/instance=demo-instance1
                    app.kubernetes.io/managed-by=Operator
                    app.kubernetes.io/name=workflow-server
                    app.kubernetes.io/version=19.0.3
                    controller-revision-hash=demo-instance1-ibm-iaws-server-78d49d6667
                    statefulset.kubernetes.io/pod-name=demo-instance1-ibm-iaws-server-0
Annotations:        openshift.io/scc=ibm-dba-iaws-scc
                    productID=5737-I23
                    productName=IBM Cloud Pak for Automation
                    productVersion=19.0.3
Status:             Running
IP:                 10.128.1.85
Controlled By:      StatefulSet/demo-instance1-ibm-iaws-server
Init Containers:
  ssl-init-container:
    Container ID:   docker://e518904579fedc5b276a866f16af134924dba2b62fdaeb3c89e07f52f24b3872
    Image:          dba-keytool-initcontainer:latest
    Image ID:       docker://sha256:e1d8a09881697228664b9a69d72377f7a2f3f0670d4649511b94b1890aa04b1f
    Port:           <none>
    Host Port:      <none>
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Mon, 02 Dec 2019 16:17:06 +0800
      Finished:     Mon, 02 Dec 2019 16:17:23 +0800
    Ready:          True
    Restart Count:  1
    Limits:
      cpu:     500m
      memory:  256Mi
    Requests:
      cpu:     200m
      memory:  128Mi
    Environment:
      KEYTOOL_ACTION:     GENERATE-BOTH
      KEYSTORE_PASSWORD:  <set to the key 'sslKeyPassword' in secret 'ibm-baw-baw-secret'>  Optional: false
    Mounts:
      /shared/resources/cert-trusted from trust-tls-volume (rw)
      /shared/resources/keypair from keypair-secret (rw)
      /shared/tls from key-trust-store (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from demo-instance1-ibm-iaws-sa-token-9r477 (ro)
  dbcompatibility-init-container:
    Container ID:   docker://246c6c72e669101162ade46aeb1b40706d2141450becf11e359655309e591818
    Image:          dba-dbcompatibility-initcontainer:latest
    Image ID:       docker://sha256:fac07eb3d6848ca7c3e63c4ce86b40a25a1bd9e69f595aa68056836532dc05d7
    Port:           <none>
    Host Port:      <none>
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Mon, 02 Dec 2019 16:17:28 +0800
      Finished:     Mon, 02 Dec 2019 16:17:55 +0800
    Ready:          True
    Restart Count:  0
    Limits:
      cpu:     500m
      memory:  256Mi
    Requests:
      cpu:     200m
      memory:  128Mi
    Environment:
      EXPECTED_SCHEMA_VERSION:            1.0.0
      DATABASE_TYPE:                      DB2
      DATABASE_HOST_NAME:                 <DB2_HOST_NAME>
      DATABASE_PORT:                      50000
      DATABASE_NAME:                      BPMDB
      DATABASE_USER:                      <set to the key 'dbUser' in secret 'ibm-baw-wfs-server-db-secret'>    Optional: false
      DATABASE_PWD:                       <set to the key 'password' in secret 'ibm-baw-wfs-server-db-secret'>  Optional: false
      DATABASE_SCHEMA:                    <set to the key 'dbUser' in secret 'ibm-baw-wfs-server-db-secret'>    Optional: false
      SCHEMA_VERSION_TABLE_NAME:          PFS_SCHEMA_PROPERTIES
      SCHEMA_VERSION_KEY_NAME:            Version
      SCHEMA_VERSION_KEY_COLUMN_NAME:     KEY
      SCHEMA_VERSION_VALUE_COLUMN_NAME:   VALUE
      DATABASE_ALTERNATE_PORT:            0
      RETRY_INTERVAL_FOR_CLIENT_REROUTE:  600
      MAX_RETRIES_FOR_CLIENT_REROUTE:     5
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from demo-instance1-ibm-iaws-sa-token-9r477 (ro)
  bawdbcompatibility-init-container:
    Container ID:   docker://ead83f436f485f20658205dd00a7fa7e63d50cfaec8b1f6e63f459e5c2798c6a
    Image:          dba-dbcompatibility-initcontainer:latest
    Image ID:       docker://sha256:fac07eb3d6848ca7c3e63c4ce86b40a25a1bd9e69f595aa68056836532dc05d7
    Port:           <none>
    Host Port:      <none>
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Mon, 02 Dec 2019 16:18:02 +0800
      Finished:     Mon, 02 Dec 2019 16:18:28 +0800
    Ready:          True
    Restart Count:  0
    Limits:
      cpu:     500m
      memory:  256Mi
    Requests:
      cpu:     200m
      memory:  128Mi
    Environment:
      EXPECTED_SCHEMA_VERSION:            1.1.0
      DATABASE_TYPE:                      DB2
      DATABASE_HOST_NAME:                 <DB2_HOST_NAME>
      DATABASE_PORT:                      50000
      DATABASE_NAME:                      BPMDB
      DATABASE_USER:                      <set to the key 'dbUser' in secret 'ibm-baw-wfs-server-db-secret'>    Optional: false
      DATABASE_PWD:                       <set to the key 'password' in secret 'ibm-baw-wfs-server-db-secret'>  Optional: false
      SCHEMA_VERSION_TABLE_NAME:          LSW_SYSTEM_SCHEMA
      SCHEMA_VERSION_KEY_NAME:            DatabaseSchemaVersion
      SCHEMA_VERSION_KEY_COLUMN_NAME:     PROPNAME
      SCHEMA_VERSION_VALUE_COLUMN_NAME:   PROPVALUE
      DATABASE_ALTERNATE_PORT:            0
      RETRY_INTERVAL_FOR_CLIENT_REROUTE:  600
      MAX_RETRIES_FOR_CLIENT_REROUTE:     5
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from demo-instance1-ibm-iaws-sa-token-9r477 (ro)
Containers:
  wf-ps:
    Container ID:   docker://686af04f1b5bb136f546a8ad34a2574f7500387099db812034d9facac33f9020
    Image:          iaws-ps:19.0.3
    Image ID:       docker://sha256:324ae272532971bc2779719239ebfa88adb298bf6ddd8970b568e97caedf4a13
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Mon, 02 Dec 2019 16:18:34 +0800
    Last State:     Terminated
      Reason:       Error
      Exit Code:    255
      Started:      Mon, 02 Dec 2019 14:07:31 +0800
      Finished:     Mon, 02 Dec 2019 16:15:32 +0800
    Ready:          True
    Restart Count:  1
    Limits:
      cpu:     3
      memory:  2096Mi
    Requests:
      cpu:      2
      memory:   1048Mi
    Readiness:  exec [/bin/bash -c if [ "$(curl -sfk https://localhost:9443/ps/rest/v1/config/getProcessServerDatabaseSchemaVersion | grep -Po '(?<="status":")(.*?)(?=")')" != "200" ]; then exit 1; fi] delay=180s timeout=1s period=5s #success=1 #failure=3
    Environment:
      JMS_SERVER_HOST:              demo-instance1-baw-jms-service
      UMS_CLIENT_ID:                demo-instance1-ibm-iaws-server-oidc-client
      UMS_CLIENT_SECRET:            <set to the key 'oidcClientPassword' in secret 'ibm-baw-baw-secret'>  Optional: false
      UMS_HOST:                     ums.<OPENSHIFT_MASTER_IP>.nip.io
      UMS_PORT:                     443
      EXTERNAL_HOSTNAME:            <OPENSHIFT_MASTER_IP>.nip.io
      EXTERNAL_PORT:                443
      WLP_LOGGING_CONSOLE_FORMAT:   json
      WLP_LOGGING_MESSAGE_FORMAT:   basic
      ADMIN_USER:                   <set to the key 'adminUsername' in secret 'ibm-baw-baw-secret'>  Optional: false
      ADMIN_PASSWORD:               <set to the key 'adminPassword' in secret 'ibm-baw-baw-secret'>  Optional: false
      UMS_ADMIN_USER:               <set to the key 'adminUser' in secret 'ibm-dba-ums-secret'>      Optional: false
      UMS_ADMIN_PASSWORD:           <set to the key 'adminPassword' in secret 'ibm-dba-ums-secret'>  Optional: false
      DB_TYPE:                      DB2
      DB_USER:                      <set to the key 'dbUser' in secret 'ibm-baw-wfs-server-db-secret'>    Optional: false
      DB_PASSWORD:                  <set to the key 'password' in secret 'ibm-baw-wfs-server-db-secret'>  Optional: false
      DB_NAME:                      BPMDB
      DB_HOST:                      <DB2_HOST_NAME>
      DB_PORT:                      50000
      SSL_KEY_PASSWORD:             <set to the key 'sslKeyPassword' in secret 'ibm-baw-baw-secret'>        Optional: false
      CSRF_SESSION_TOKENSALT:       <set to the key 'csrfSessionTokenSalt' in secret 'ibm-baw-baw-secret'>  Optional: false
      CSRF_REFERER_WHITELIST:       <OPENSHIFT_MASTER_IP>.nip.io,ums.<OPENSHIFT_MASTER_IP>.nip.io,ae.<OPENSHIFT_MASTER_IP>.nip.io,icn.<OPENSHIFT_MASTER_IP>.nip.io
      CSRF_ORIGIN_WHITELIST:        https://<OPENSHIFT_MASTER_IP>.nip.io,https://<OPENSHIFT_MASTER_IP>.nip.io:443,https://ums.<OPENSHIFT_MASTER_IP>.nip.io,https://ums.<OPENSHIFT_MASTER_IP>.nip.io:443,https://ae.<OPENSHIFT_MASTER_IP>.nip.io,https://icn.<OPENSHIFT_MASTER_IP>.nip.io
      CPE_URL:                      https://demo-cpe-svc:9443/wsi/FNCEWS40MTOM
      CMIS_URL:                     https://demo-cmis-svc:9443/openfncmis_wlp/services
      CPE_DOMAIN_NAME:              P8Domain
      CPE_REPOSITORY:               DOCS
      CPE_OBJECTSTORE_ID:           {E340B318-CF17-4C14-8902-AF713D3B0A91}
      CPE_USERNAME:                 <set to the key 'adminUsername' in secret 'cpe-admin-secret'>  Optional: false
      CPE_PASSWORD:                 <set to the key 'adminPassword' in secret 'cpe-admin-secret'>  Optional: false
      WAIT_INTERVAL:                60000
      DB_SSLCONNECTION:             false
      DB_SSLCERTLOCATION:           fake
      DBCHECK_WAITTIME:             900
      DBCHECK_INTERVALTIME:         15
      STANDBYDB_PORT:               0
      STANDBYDB_RETRYINTERVAL:      600
      STANDBYDB_MAXRETRIES:         5
      RESOURCE_REGISTRY_URL:        https://rr.<OPENSHIFT_MASTER_IP>.nip.io:443
      RESOURCE_REGISTRY_UNAME:      <set to the key 'writeUser' in secret 'rr-admin-secret'>      Optional: false
      RESOURCE_REGISTRY_PASSWORD:   <set to the key 'writePassword' in secret 'rr-admin-secret'>  Optional: false
      CLUSTERIP_SERVICE_NAME:       demo-instance1-ibm-baw-server
      APPENGINE_EXTERNAL_HOSTNAME:  ae.<OPENSHIFT_MASTER_IP>.nip.io
      FRAME-ANCESTORS-SETTING:      https://<OPENSHIFT_MASTER_IP>.nip.io https://ums.<OPENSHIFT_MASTER_IP>.nip.io https://ae.<OPENSHIFT_MASTER_IP>.nip.io https://icn.<OPENSHIFT_MASTER_IP>.nip.io
      ENCRYPTION_KEY:               <set to the key 'encryptionKey' in secret 'icp4a-shared-encryption-key'>  Optional: false
    Mounts:
      /opt/ibm/wlp/output/defaultServer/resources/security/keystore/jks/server.jks from key-trust-store (rw)
      /opt/ibm/wlp/output/defaultServer/resources/security/truststore/jks/trusts.jks from key-trust-store (rw)
      /opt/ibm/wlp/usr/servers/defaultServer/config/100SCIM.xml from configurations (rw)
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/oidc-rp.xml from configurations (rw)
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/processServer_variables_system.xml from configurations (rw)
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/security100.xml from configurations (rw)
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/ssl.xml from configurations (rw)
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/trace-specification.xml from configurations (rw)
      /opt/ibm/wlp/usr/servers/defaultServer/resources/security from ltpa-store (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from demo-instance1-ibm-iaws-sa-token-9r477 (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
Volumes:
  key-trust-store:
    Type:    EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
  trust-tls-volume:
  <unknown>
  keypair-secret:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  ibm-baw-tls
    Optional:    false
  ltpa-store:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  demo-instance1-ibm-iaws-server-ltpa
    Optional:    false
  configurations:
    Type:      ConfigMap (a volume populated by a ConfigMap)
    Name:      demo-instance1-ibm-iaws-server-config
    Optional:  false
  demo-instance1-ibm-iaws-sa-token-9r477:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  demo-instance1-ibm-iaws-sa-token-9r477
    Optional:    false
QoS Class:       Burstable
Node-Selectors:  node-role.kubernetes.io/compute=true
Tolerations:     node.kubernetes.io/memory-pressure:NoSchedule
Events:
  Type     Reason           Age                From             Message
  ----     ------           ----               ----             -------
  Warning  NetworkNotReady  16m (x2 over 16m)  kubelet, rhel76  network is not ready: [runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized]
  Normal   SandboxChanged   15m                kubelet, rhel76  Pod sandbox changed, it will be killed and re-created.
  Normal   Pulled           15m                kubelet, rhel76  Container image "dba-keytool-initcontainer:latest" already present on machine
  Normal   Created          15m                kubelet, rhel76  Created container
  Normal   Started          15m                kubelet, rhel76  Started container
  Normal   Pulled           15m                kubelet, rhel76  Container image "dba-dbcompatibility-initcontainer:latest" already present on machine
  Normal   Created          15m                kubelet, rhel76  Created container
  Normal   Started          15m                kubelet, rhel76  Started container
  Normal   Pulled           14m                kubelet, rhel76  Container image "dba-dbcompatibility-initcontainer:latest" already present on machine
  Normal   Created          14m                kubelet, rhel76  Created container
  Normal   Started          14m                kubelet, rhel76  Started container
  Normal   Pulled           14m                kubelet, rhel76  Container image "iaws-ps:19.0.3" already present on machine
  Normal   Created          14m                kubelet, rhel76  Created container
  Normal   Started          14m                kubelet, rhel76  Started container
```

The "demo-instance1-ibm-iaws-server-0" pod has three init containers, named `ssl-init-container`, `dbcompatibility-init-container` and `bawdbcompatibility-init-container`. For all init containers, the desired STATUS is `Terminated` with Reason `Completed`. For the `wf-ps` container, the desired Ready STATUS is `True`.

</p>
</details>
</div>


- Error: failed to start container "demo-cpe-deploy" or "demo-navigator-deploy"

<div>
<details>
<summary>Click to show detailed information and a solution. </summary>
<p>

The detailed error message is something like "Error response from daemon: oci runtime error: container_linux.go:235: starting container process caused "container init exited prematurely"". This kind of error is caused by Persistent Volumes and Persistent Volume Claims related to IBM Content Navigator and Content Platform Engine that are bound incorrectly. The solution is to delete first the Persistent Volume Claims related to IBM Content Navigator or Content Platform Engine and then the related PVs and NFS folders. Then, re-create them in the reverse order.

</p>
</details>
</div>

- Failed to start Pod "demo-ibm-pfs-elasticsearch-0"

Check the value of the  `pfs_configuration.elasticsearch.privileged` property in your Custom Resource configuration. If it's set to `true`, run the `oc describe pod demo-ibm-pfs-elasticsearch-0` command to check the SecurityContextConstraint of the `demo-ibm-pfs-elasticsearch-0` pod. Also, ensure it’s set as `openshift.io/scc=pfs-privileged-scc`. 
```
# oc describe pod demo-ibm-pfs-elasticsearch-0
Name:               demo-ibm-pfs-elasticsearch-0
Namespace:          demo-project
Priority:           0
PriorityClassName:  <none>
Node:               rhel76/<OPENSHIFT_MASTER_IP>
Start Time:         Thu, 21 Nov 2019 18:10:11 +0800
Labels:             app.kubernetes.io/component=pfs-elasticsearch
                    app.kubernetes.io/instance=demo
                    app.kubernetes.io/managed-by=Operator
                    app.kubernetes.io/name=demo-ibm-pfs-elasticsearch
                    app.kubernetes.io/version=19.0.3
                    controller-revision-hash=demo-ibm-pfs-elasticsearch-8675f484d
                    role=elasticsearch
                    statefulset.kubernetes.io/pod-name=demo-ibm-pfs-elasticsearch-0
Annotations:        checksum/config=6a3747ddc8ce13afdfc85b6793b847d035e8edd5
                    openshift.io/scc=pfs-privileged-scc
                    productID=5737-I23
                    productName=IBM Cloud Pak for Automation
                    productVersion=19.0.3
Status:             Running
```

- To enable Automation Workstream Services container logs:

Use the following specification to enable Automation Workstream Services container logs in the Custom Resource configuration:
```yaml
iaws_configuration:
 - name: instance1
   wfs:
     logs:
       console_format: “json”
       console_log_level: “INFO”
       console_source: “message,trace,accessLog,ffdc,audit”
       message_format: “basic”
       trace_format: “ENHANCED”
       trace_specification: “WLE.=all:com.ibm.bpm.=all：com.ibm.workflow.*=all”
```

Then, run the `oc logs IAWS_pod_name` command to see the logs, or log into Automation Workstream Services to see the logs.

This example shows how to check the Automation Workstream Services container logs:
```
$ oc exec -it demo-instance1-ibm-iaws-server-0 bash
$ cat /logs/application/liberty-message.log
```

- To customize the Process Federation Server liberty server trace setting

Use the following specification to enable Process Federation Server container logs in the Custom Resource configuration:
```yaml
pfs_configuration:
   pfs:
     logs:
       console_format: "json"
       console_log_level: "INFO"
       console_source: "message,trace,accessLog,ffdc,audit"
       trace_format: "ENHANCED"
       trace_specification: "*=info"
```

Then, run the `oc logs PFS_pod_name` command to see the logs, or log into Process Federation Server to see the logs.

This example shows how to check the Process Federation Server container logs:
```
$ oc exec -it demo-ibm-pfs-0 bash
$ cat /logs/application/liberty-message.log
```
