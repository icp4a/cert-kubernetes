# Configuring IBM Automation Workstream Services 20.0.1
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
  - [Preparing storage for Process Federation Server](#Preparing-storage-for-Process-Federation-Server)
  - [Preparing storage for Java Messaging Service](#Preparing-storage-for-Java-Messaging-Service)
- [Step 5: Protecting sensitive configuration data](#Step-5-Protecting-sensitive-configuration-data)
  - [Creating required secrets for Automation Workstream Services](#Creating-required-secrets-for-Automation-Workstream-Services)
  - [Creating the Lombardi custom secret](#Creating-the-lombardi-custom-secret)
- [Step 6: Configuring the Custom Resource YAML file to deploy Automation Workstream Services](#Step-6-Configuring-the-Custom-Resource-YAML-file-to-deploy-Automation-Workstream-Services)
  - [Accepting the dba license in the operator.yaml file](#accepting-the-dba-license-in-the-operatoryaml-file)
  - [Adding the prerequisite configuration sections](#Adding-the-prerequisite-configuration-sections)
  - [Adding the required Automation Workstream Services configuration sections](#Adding-the-required-Automation-Workstream-Services-configuration-sections)
  - [Custom configuration](#Custom-configuration)
- [Step 7: Completing the installation](#Step-7-Completing-the-installation)
- [Step 8: Verifying Automation Workstream Services](#Step-8-Verifying-Automation-Workstream-Services)
- [Limitations](#Limitations)
- [Troubleshooting](#Troubleshooting)



## Introduction
The IBM Automation Workstream Services operator deploys the Workstream server, a server engine that runs workstreams that are configured and launched in IBM Workplace.


## Automation Workstream Services component details
The standard configuration includes these components:

- IBM Business Automation Workstream Server component
- IBM Java Messaging Service component
- IBM Process Federation Server component

To support those components, a standard installation generates the following content:

- 7 ConfigMaps that manage the configuration
- 1 StatefulSet running Java Messaging Service
- 1 StatefulSet running Workstream server
- 1 StatefulSet running Process Federation Server
- 1 deployment for Process Federation Server
- 7 or more jobs for Workstream server
- 4 service accounts with related role and role binding
- 20 or more secrets to gain access during installation
- 7 services and Route to route the traffic to the IBM Business Automation Application Engine (App Engine)


## Resources required
Follow the instructions in [Planning your installation](https://docs.openshift.com/container-platform/3.11/install/index.html#single-master-single-box). Then, based on your environment, check the required resources in [System and environment requirements](https://docs.openshift.com/container-platform/3.11/install/prerequisites.html) and set up your environment.

| Component name | Container | CPU | Memory |
| --- | --- | --- | --- |
| IBM Automation Workstream Services | Workstream container | 2 | 3Gi |
| IBM Automation Workstream Services | Init containers | 200m | 128Mi |
| IBM Automation Workstream Services | IBM Java Messaging Service containers | 500m | 512Mi |
| IBM Automation Workstream Services | IBM Process Federation Service containers | 1500m | 2560Mi |

You will need the following storage space:
- 5 GB for Process Federation Service log data
- 10 GB for Process Federation Service Elasticsearch data
- 1 GB for Java Messaging Service data


## Prerequisites
- [OpenShift 3.11 or later](https://docs.openshift.com/container-platform/3.11/welcome/index.html)
- [IBM Db2 11.5](https://www.ibm.com/products/db2-database)
- [User Management Service](../UMS/README_config.md)
- [IBM Business Automation Application Engine](../AAE/README_config.md)
- [IBM Business Automation Navigator](../BAN/README_config.md)
- [IBM FileNet Content Manager](../FNCM/README_config.md)

## Step 1: Preparing to install Automation Workstream Services for production
In addition to performing the steps required to set up the operator environment, complete the following steps before you install Automation Workstream Services.

### Setting up an OpenShift environment
Before you can prepare to install Automation Workstream Services, complete [Step 1 to Step 5](../platform/ocp/install.md) in "Installing Cloud Pak for Automation on Red Hat OpenShift."


### Preparing SecurityContextConstraints

#### Creating a SecurityContextConstraint for Process Federation Server

For Process Federation Server, the pods running Elasticsearch require the hosting worker nodes to be configured to:
- [Disable memory swapping](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/setup-configuration-memory.html) by setting the sysctl value `vm.swappiness` to 1.

- [Increase the limit on the number of open files descriptors](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/file-descriptors.html) for the user running Elasticsearch by setting sysctl value `vm.max_map_count` to 65,536 or higher.

If [privileged container](https://kubernetes.io/docs/concepts/workloads/pods/pod/#privileged-mode-for-pod-containers) is not allowed and the `pfs_configuration.elasticsearch.privileged` property is set to `false` in the Custom Resource configuration, you must ask the cluster administrator to execute the following sample command to change the swap and max_map_count:

```
sysctl -w vm.max_map_count=262144 && sed -i '/^vm.max_map_count /d' /etc/sysctl.conf && echo 'vm.max_map_count = 262144' >> /etc/sysctl.conf && sysctl -w vm.swappiness=1 && sed -i '/^vm.swappiness /d' /etc/sysctl.conf && echo 'vm.swappiness=1' >> /etc/sysctl.conf
```

If you are allowed to run [privileged container](https://kubernetes.io/docs/concepts/workloads/pods/pod/#privileged-mode-for-pod-containers), then setting the `pfs_configuration.elasticsearch.privileged` value to `true` will take care of updating the node configuration using a privileged init container, which will execute the appropriate `sysctl` commands. You must create a SecurityContextConstraint (SCC) for Process Federation Server that contains the following content and save it to the `ibm-pfs-privileged-scc.yaml` file. Then, add this `ibm-pfs-privileged-scc` SCC to the `<CUSTOM_RESOURCE_NAME>-ibm-pfs-es-service-account` Process Federation Server Elasticsearch default service account in the current namespace.

PFS Privileged Security Context Constraint(SCC) definition:

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

**Note:** Specify the value of the `pfs_configuration.elasticsearch.service_account` property for the newly created service account `ibm-pfs-es-service-account` in your Custom Resource configuration file. Don't set the value of the `pfs_configuration.pfs.service_account` property to this service account.


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
- Replace `<IAWS_DB_NAME>` with the IBM Automation Workstream Services database name you want, for example, BPMDB.
- Replace `<DB_USER>` with the user you will use for the database.


### (Optional) Db2 SSL Configuration
To ensure that all communications between the Business Automation Workstream server and Db2 are encoded, you must import the database CA Certificate to the Business Automation Workstream server. To do so, you must create a secret to store the certificate:
```
kubectl create secret generic ibm-dba-baw-db2-cacert --from-file=cacert.crt=
```

**Note:** You must modify the part that points to the certificate file. Do not change the part --from-file=cacert.crt=.

You can then use the resulting secret to set the `iaws_configuration[x].iaws_server.database.sslsecretname: ibm-dba-baw-db2-cacert`, while setting `iaws_configuration[x].iaws_server.database.ssl` to `true`.

### (Optional) Db2 HADR Configuration
If you use Db2 as your database, you can configure high availability by setting up HADR for the Workstream server database. This configuration ensures that the Workstream server automatically retrieves the necessary failover server information when it first  connects to the database. As part of the setup, you must provide a comma-separated list of failover servers and failover ports.

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
      retryinterval: <default value is 10 min>
      maxretries: <default value is 5>
  ... ...
```



## Step 3: Preparing to configure LDAP
An LDAP server is required before you install Automation Workstream Services. You can create the LDAP server secret by refering to [LDAP configuration parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_k8s_ldap.html). 

## Step 4: Preparing storage

### Preparing storage for Process Federation Server

#### Using existing storage classes

If you have existing storage classes for Process Federation Server logs, Process Federation Server outputs, and Elasticsearch storage, you can use dynamic provisioning by making the following updates in the Custom Resource configuration file:

```yaml
pfs_configuration:
  pfs:
    output:
      storage:
        use_dynamic_provisioning: true
        storage_class: "<Storage_Class_for_PFS_Output>"
        ...
    logs:    
      storage:
        use_dynamic_provisioning: true
        storage_class: "<Storage_Class_for_PFS_logs>"
        ...
  elasticsearch:
    storage:
      persistent: true
      use_dynamic_provisioning: true
      storage_class: "<Storage_Class_for_PFS_Elasticsearch>"
      ...
```

#### Preparing your own storage classes

If you don’t have existing storage classes, the following example illustrates the procedure using Network File System (NFS) to create your own storage classes. An existing NFS server is required before you can create persistent volumes (PVs), persistent volume claims (PVCs), and related folders. The deployment process uses these volumes and folders during the deployment.

- Create the required folders on an NFS server. For the NFS server, you must grant minimal privileges. In the `/etc/exports` configuration file, add the following line at the end:
```
<pfs_storage_directory_path> *(rw,sync,no_subtree_check)
```

**Notes:**
- `<pfs_storage_directory_path>` should be an individual directory and not shared with other components.
- **Restart the NFS service** after editing and saving the `/etc/exports` configuration file.


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

- Create the PVs required for the Process Federation Server.

Save the following YAML files on the OpenShift master node and run the `oc apply -f <YAML_FILE_NAME>` commands in the following order.

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

Make the following changes to the Custom Resource configuration file:

```yaml
pfs_configuration:
  pfs:
    output:
      storage:
        use_dynamic_provisioning: false
        storage_class: "pfs-output"
        ...
    logs:    
      storage:
        use_dynamic_provisioning: false
        storage_class: "pfs-logs"
        ...
  elasticsearch:
    storage:
      persistent: true
      use_dynamic_provisioning: false
      storage_class: "pfs-es"
      ...
```

### Preparing storage for Java Messaging Service

#### Using existing storage classes

If you have existing storage classes for Java Messaging Service (JMS), you can use dynamic provisioning by making the following updates in the Custom Resource configuration file:

```yaml
iaws_configuration:
  - name: instance1
    iaws_server:
      jms:
        storage:
          persistent: true
          use_dynamic_provisioning: true
          access_modes:
          - ReadWriteOnce
          storage_class: "<Storage_Class_for_JMS>"
          ...
```

#### Preparing your own storage classes

If you don’t have existing storage classes for JMS, the following example illustrates the procedure using NFS to create your own storage classes. An existing NFS server is required before creating PV and related folders. 

- Create the required folders on an NFS server. For the NFS server, you must grant minimal privileges. In the `/etc/exports` configuration file, add the following line at the end:
```
<jms_storage_directory_path> *(rw,sync,no_subtree_check)
```

**Notes:**
- `<jms_storage_directory_path>` should be an individual directory and not shared with other components.
- **Restart the NFS service** after editing and saving the `/etc/exports` configuration file.

Give the least privilege to the mounted directories using the following commands: 
```bash
sudo mkdir <jms_storage_directory_path>/jms
chown -R :65534 <jms_storage_directory_path>/jms
chmod g+rw <jms_storage_directory_path>/jms
```

- Create the PVs required for JMS.

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
    storage: 1Gi
  nfs:
    path: <jms_storage_directory_path>/jms
    server: <NFS_SERVER_IP>
  persistentVolumeReclaimPolicy: Recycle
```

**Notes:**
- Replace `<jms_storage_directory_path>` with the JMS storage folder on your NFS server.
- `accessModes` should be set to the same value as the `iaws_configuration[x].iaws_server.jms.storage.access_modes` property in the Custom Resource configuration file.
- Replace `<NFS_SERVER_IP>` with your NFS server IP address.

Make the following changes to the Custom Resource configuration file:

```yaml
iaws_configuration:
  - name: instance1
    iaws_server:
      jms:
        storage:
          persistent: true
          use_dynamic_provisioning: false
          access_modes:
          - ReadWriteOnce
          storage_class: "jms-storage-class"
          ...
```


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
- So that the confidential information is shared only between the components that hold the key, use the encryptionKey to encrypt the confidential information at the RR.
- Ensure the encryptionKey is **base64** encoded.

Business Automation Workstream server database secret:
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
- `dbUser` and `password` are the database user name and password. 
- Ensure all values under data are **base64** encoded.

Process Federation Server:
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
- `oidcClientPassword` is registered with User Management Service (UMS) as the OIDC client password.
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

#### 2. Create the Lombardi custom secret.
Run the following command on the OpenShift master node:
```
kubectl create secret generic wfs-lombardi-custom-xml-secret --from-file=sensitiveCustomConfig=./100Custom.xml
```

**Note:** To overwrite the Lombardi configuration settings, specify the value of the  `iaws_configuration[x].iaws_server.lombardi_custom_xml_secret_name` property as the newly created secret name `wfs-lombardi-custom-xml-secret` in the Custom Resource configuration file.



## Step 6: Configuring the Custom Resource YAML file to deploy Automation Workstream Services
### Accepting the dba license in the operator.yaml file
Make sure that you accept the dba license in the operator.yaml file. Set the value of the dba_license property to "accept".

### Adding the prerequisite configuration sections
Make sure that you've set the configuration parameters for the following components in your copy of the template Custom Resource YAML file:

- [User Management Service](../UMS/README_config.md)
- [Business Automation Application Engine](../AAE/README_config.md)
- [Business Automation Navigator](../BAN/README_config.md)
- [FileNet Content Manager](../FNCM/README_config.md)

**Note:** 
Check the values of `spec.initialize_configuration`. See [IBM FileNet Content Manager initialization settings](../FNCM/README_config.md#initialization-settings) and [Initialization parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opinitiparams.html) for the correct settings.

### Adding the required Automation Workstream Services configuration sections
Edit your copy of the template Custom Resource YAML file and make the following updates: 
- Uncomment and update the shared_configuration section if you haven't done it already.

- Update the `iaws_configuration` and `pfs_configuration` sections.
  To install Automation Workstream Services, replace the contents of the `iaws_configuration` and `pfs_configuration` sections in your copy of the template Custom Resource YAML with the values from the [sample_min_value.yaml](./configuration/sample_min_value.yaml) file.
 
- Make sure that iaws_configuration[x].iaws_server.admin_user is the administrator for the Workstream server, and that admin_user is an existing LDAP user.

### Custom configuration
If you want to customize your custom resource YAML file, refer to the [configuration list](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_iaws_params.html) to update the required values of each parameter according to your environment.



## Step 7: Completing the installation
Go back to the relevant installation or update page to configure other components and complete the deployment with the operator.

Installation pages:
   - [Managed OpenShift installation page](../platform/roks/install.md)
   - [OpenShift installation page](../platform/ocp/install.md)
   - [Certified Kubernetes installation page](../platform/k8s/install.md)

Update pages:
   - [Managed OpenShift installation page](../platform/roks/update.md)
   - [OpenShift installation page](../platform/ocp/update.md)
   - [Certified Kubernetes installation page](../platform/k8s/update.md)



## Step 8: Verifying Automation Workstream Services
1. To verify the installation of Automation Workstream Services, get the name of the pods that were deployed by running the following command:
```
oc get pod -n <NAMESPACE_NAME>
```

<div>
<details>
<summary>Click to show a successful Automation Workstream Services pod status. </summary>
<p>

```
NAME                                                         READY   STATUS      RESTARTS   AGE
demo-cmis-deploy-647c9b94b8-j4qq9                            1/1     Running     0          30m
demo-cpe-deploy-7bbd949659-6s4sx                             1/1     Running     0          35m
demo-dba-rr-00160d67de                                       1/1     Running     0          43m
demo-dba-rr-3d52541b1f                                       1/1     Running     0          43m
demo-dba-rr-42c6649189                                       1/1     Running     0          43m
demo-ibm-pfs-0                                               1/1     Running     0          5m19s
demo-ibm-pfs-dbareg-54d9db6cf5-98lwt                         1/1     Running     0          4m56s
demo-ibm-pfs-elasticsearch-0                                 2/2     Running     0          5m32s
demo-ibm-pfs-umsregistry-job-8vjt7                           0/1     Completed   0          5m10s
demo-instance1-aae-ae-db-job-kwlj4                           0/1     Completed   0          15m
demo-instance1-aae-ae-deployment-d69c5bff7-cq6zd             1/1     Running     0          14m
demo-instance1-aae-ae-oidc-job-t4zks                         0/1     Completed   0          14m
demo-instance1-baw-jms-0                                     1/1     Running     0          5m58s
demo-instance1-ibm-iaws-ibm-workplace-init-job-8qlgz         0/1     Completed   0          7m41s
demo-instance1-ibm-iaws-server-0                             1/1     Running     0          7m23s
demo-instance1-ibm-iaws-server-content-init-job-fjlwq        0/1     Completed   0          7m32s
demo-instance1-ibm-iaws-server-database-init-job-ll5c6       0/1     Completed   0          8m
demo-instance1-ibm-iaws-server-database-init-job-pfs-wqm8b   0/1     Completed   0          7m54s
demo-instance1-ibm-iaws-server-ltpa-l9rnr                    0/1     Completed   0          8m7s
demo-instance1-ibm-iaws-server-umsregistry-job-m27h6         0/1     Completed   0          7m49s
demo-navigator-deploy-5dc6967445-2x998                       1/1     Running     0          22m
demo-rr-setup-pod                                            0/1     Completed   0          43m
demo-ums-deployment-5d6d65cd69-mrpcf                         1/1     Running     0          41m
demo-ums-ltpa-creation-job-cgn4j                             0/1     Completed   0          42m
ibm-cp4a-operator-fbb9d454d-hj5wh                            2/2     Running     0          44m

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

  **Note:** The following limitation only applies if you are updating an Automation Workstream Services deployment that uses the embedded Elasticsearch statefulset
  
  * Scaling Elasticsearch statefulset
  
  In the Elasticsearch configuration, the [discovery.zen.minimun_master_nodes property](https://www.elastic.co/guide/en/elasticsearch/reference/6.7/discovery-settings.html#minimum_master_nodes) is automatically set by the operator to the quorum of replicas of the Elasticsearch statefulset. If, during an update, the pfs_configuration.elasticsearch.replicas value is changed, and the change leads to a new computed value for the discovery.zen.minimun_master_nodes configuration property, then all currently running Elasticsearch pods will have to be restarted. During this restart of the pods, there will be a temporary interruption of Elasticsearch and Process Federation Server services.
  * Elasticsearch High Availability

  In the Elasticsearch configuration, the [discovery.zen.minimun_master_nodes property](https://www.elastic.co/guide/en/elasticsearch/reference/6.7/discovery-settings.html#minimum_master_nodes) is automatically set by the operator to the quorum of replicas of the Elasticsearch statefulset. If at some point, some Elasticsearch pods are failing, and the number of running Elasticearch pods is less than the quorum of replicas of the Elasticsearch statefulset, there will be an interruption of Elasticsearch and PFS services, until at least the quorum of running Elasticsearch pods is satisfied again.

* Resource Registry limitation

  Because of the design of etcd, it's recommended that you don't change the replica size after you create the Resource Registry cluster to prevent data loss. If you must set the replica size, set it to an odd number. If you reduce the pod size, the pods are destroyed one by one slowly to prevent data loss or the cluster from becoming out of sync.
  * If you update the Resource Registry admin secret to change the username or password, first delete the <instance_name>-dba-rr-<random_value> pods to cause Resource Registry to enable the updates. Alternatively, you can enable the update manually with etcd commands.
  * If you update the Resource Registry configurations in the icp4acluster custom resource instance, the update might not affect the Resource Registry pod directly. It will affect the newly created pods when you increase the number of replicas.

* The App Engine trusts only Certification Authority (CA) because of a Node.js server limitation. If an external service is used and signed with another root CA, you must add the root CA as trusted instead of the service certificate.

  * The certificate can be self-signed, or signed by a well-known CA.
  * If you're using a depth zero self-signed certificate, it must be listed as a trusted certificate.
  * If you're using a certificate signed by a self-signed CA, the self-signed CA must be in the trusted list. Using a leaf certificate in the trusted list is not supported.
  * If you're adding the root CA of two or more external services to the App Engine trust list, you can't use the same common name for those root CAs.



## Troubleshooting

- How to check Automation Workstream Services detailed version information

Run the `docker inspect cp.icr.io/cp/cp4a/iaws/iaws-server:20.0.1` command to see the specific version of Workstream server. On OpenShift Container Platform 4.x, use `podman inspect cp.icr.io/cp/cp4a/iaws/iaws-server:20.0.1` instead:
```
...
"Labels": {                                                                                                                                                                             
                "architecture": "x86_64",                                                                                                                                                           
                "authoritative-source-url": "registry.access.redhat.com",                                                                                                                           
                "build-date": "2020-01-28T10:53:49.652277",                                                                                                                                         
                "com.ibm.dba.workstream.build-date": "20200312",                                                                                                                                    
                "com.ibm.dba.workstream.build-level": "20200312-074526",                                                                                                                            
                "com.ibm.dba.workstream.ifixes": "[]",                                                                                                                                              
                "com.ibm.dba.workstream.version": "20.0.1",                                                                                                                                         
                "com.redhat.build-host": "cpt-1007.osbs.prod.upshift.rdu2.redhat.com",                                                                                                              
                "com.redhat.component": "ubi7-container",                                                                                                                                           
                "com.redhat.license_terms": "https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI",                                                                              
                "description": "Workstream Server Container provides a server engine that runs workstreams",                                                                                        
                "distribution-scope": "public",                                                                                                                                                     
                "io.k8s.description": "The Universal Base Image is designed and engineered to be the base layer for all of your containerized applications, middleware and utilities. This base imag
e is freely redistributable, but Red Hat only supports Red Hat technologies through subscriptions for Red Hat products. This image is maintained by Red Hat and updated regularly.",                
                "io.k8s.display-name": "Red Hat Universal Base Image 7",                                                                                                                            
                "io.openshift.tags": "base rhel7",                                                                                                                                                  
                "maintainer": "Red Hat, Inc.",                                                                                                                                                      
                "name": "Workstream Server",                                                                                                                                                        
                "release": "20.0.1",                                                                                                                                                                
                "summary": "Workstream Server Container is an application container",                                                                                                               
                "url": "https://access.redhat.com/containers/#/registry.access.redhat.com/ubi7/images/7.7-310",                                                                                     
                "vcs-ref": "4c80c8aa26e69950ab11b87789c8fb7665b1632d",                                                                                                                              
                "vcs-type": "git",                                                                                                                                                                  
                "vendor": "IBM",                                                                                                                                                                    
                "version": "20.0.1"                                                                                                                                                                 
            }
...
```

- How to check Automation Workstream Services pod status and related logs

There are 12 Automation Workstream Services-related pods in total. Run the `oc get pod` command to see the status of each pod:
```
NAME                                                         READY   STATUS      RESTARTS   AGE
demo-ibm-pfs-0                                               1/1     Running     0          5m19s
demo-ibm-pfs-dbareg-54d9db6cf5-98lwt                         1/1     Running     0          4m56s
demo-ibm-pfs-elasticsearch-0                                 2/2     Running     0          5m32s
demo-ibm-pfs-umsregistry-job-8vjt7                           0/1     Completed   0          5m10s
demo-instance1-baw-jms-0                                     1/1     Running     0          5m58s
demo-instance1-ibm-iaws-ibm-workplace-init-job-8qlgz         0/1     Completed   0          7m41s
demo-instance1-ibm-iaws-server-0                             1/1     Running     0          7m23s
demo-instance1-ibm-iaws-server-content-init-job-fjlwq        0/1     Completed   0          7m32s
demo-instance1-ibm-iaws-server-database-init-job-ll5c6       0/1     Completed   0          8m
demo-instance1-ibm-iaws-server-database-init-job-pfs-wqm8b   0/1     Completed   0          7m54s
demo-instance1-ibm-iaws-server-ltpa-l9rnr                    0/1     Completed   0          8m7s
demo-instance1-ibm-iaws-server-umsregistry-job-m27h6         0/1     Completed   0          7m49s
...
```

For pods controlled by Job, the desired `STATUS` is `Completed` and desired `READY` is `0/1`, while for pods controlled by Deployment or StatefulSet, the desired `STATUS` is `Running` and desired `READY` is `1/1` or `2/2`. You can see detailed information for each pod by running the `oc describe pod <POD_NAME>` command, and you can see detailed logs by running the `oc logs <POD_NAME>` command. Although a pod should be in the `Running` Status at first, if a pod doesn‘t change its status, you can use the previous commands to determine what’s causing the blocks.

<div>
<details>
<summary>Click to show an example of how to analyze the Pod "demo-instance1-ibm-iaws-server-0". </summary>
<p>

```yaml
[root@borstal-inf ~]# oc describe pod demo-instance1-ibm-iaws-server-0
Name:         demo-instance1-ibm-iaws-server-0
Namespace:    demo-project
Priority:     0
Node:         worker0.borstal.os.fyre.ibm.com/<OPENSHIFT_NODE_IP>
Start Time:   Thu, 19 Mar 2020 08:06:13 -0700
Labels:       app.kubernetes.io/component=server
              app.kubernetes.io/instance=demo-instance1
              app.kubernetes.io/managed-by=Operator
              app.kubernetes.io/name=workflow-server
              app.kubernetes.io/version=20.0.1
              controller-revision-hash=demo-instance1-ibm-iaws-server-868f989df6
              release=20.0.1
              statefulset.kubernetes.io/pod-name=demo-instance1-ibm-iaws-server-0
Annotations:  cloudpakId: 94a9c8c358bb43ba8fbdea62e7e166a5
              cloudpakName: IBM Cloud Pak for Automation
              cloudpakVersion: 20.0.1
              jvmOptionsConfigurationChecksum: da39a3ee5e6b4b0d3255bfef95601890afd80709
              k8s.v1.cni.cncf.io/networks-status:
                [{
                    "name": "openshift-sdn",
                    "interface": "eth0",
                    "ips": [
                        "10.254.9.15"
                    ],
                    "dns": {},
                    "default-route": [
                        "10.254.8.1"
                    ]
                }]
              openshift.io/scc: dbamc
              productChargedContainers: wf-ps
              productCloudpakRatio: 1:5
              productID: 534103df30f0477bb45ec3e02ef6aba0
              productMetric: VIRTUAL_PROCESSOR_CORE
              productName: IBM Cloud Pak for Automation - Automation Workstream Services
              productVersion: 20.0.1
Status:       Running
IP:           10.254.9.15
IPs:
  IP:           10.254.9.15
Controlled By:  StatefulSet/demo-instance1-ibm-iaws-server
Init Containers:
  ssl-init-container:
    Container ID:   cri-o://d746ac147622e4f236df4469ef24263c2eec9df90d85555e0f159259cf8458a7
    Image:          image-registry.openshift-image-registry.svc:5000/demo-project/dba-keytool-initcontainer@sha256:a428892c7144640f9cf4e15120be4af9c7d1470fd6bf5e6fc8e3294b2feb2147
    Image ID:       image-registry.openshift-image-registry.svc:5000/demo-project/dba-keytool-initcontainer@sha256:a428892c7144640f9cf4e15120be4af9c7d1470fd6bf5e6fc8e3294b2feb2147
    Port:           <none>
    Host Port:      <none>
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Thu, 19 Mar 2020 08:06:22 -0700
      Finished:     Thu, 19 Mar 2020 08:06:45 -0700
    Ready:          True
    Restart Count:  0
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
      /var/run/secrets/kubernetes.io/serviceaccount from demo-instance1-ibm-iaws-sa-token-4zmxj (ro)
  dbcompatibility-init-container:
    Container ID:   cri-o://a334e75dae19335d6fc0af4060726e79dd2fe46d3fe7102ed758a724d6c33a3f
    Image:          image-registry.openshift-image-registry.svc:5000/demo-project/dba-dbcompatibility-initcontainer@sha256:7f03cacee6332b9f1e8f1d506123b1cd98574c07294638418cb37d29670b0e1b
    Image ID:       image-registry.openshift-image-registry.svc:5000/demo-project/dba-dbcompatibility-initcontainer@sha256:7f03cacee6332b9f1e8f1d506123b1cd98574c07294638418cb37d29670b0e1b
    Port:           <none>
    Host Port:      <none>
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Thu, 19 Mar 2020 08:06:46 -0700
      Finished:     Thu, 19 Mar 2020 08:07:07 -0700
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
      /var/run/secrets/kubernetes.io/serviceaccount from demo-instance1-ibm-iaws-sa-token-4zmxj (ro)
  bawdbcompatibility-init-container:
    Container ID:   cri-o://e612b9dede1bd31e025b7b93fbedc3adaddeb6aa1e1ba249442bb88a797abdb5
    Image:          image-registry.openshift-image-registry.svc:5000/demo-project/dba-dbcompatibility-initcontainer@sha256:7f03cacee6332b9f1e8f1d506123b1cd98574c07294638418cb37d29670b0e1b
    Image ID:       image-registry.openshift-image-registry.svc:5000/demo-project/dba-dbcompatibility-initcontainer@sha256:7f03cacee6332b9f1e8f1d506123b1cd98574c07294638418cb37d29670b0e1b
    Port:           <none>
    Host Port:      <none>
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Thu, 19 Mar 2020 08:07:08 -0700
      Finished:     Thu, 19 Mar 2020 08:09:24 -0700
    Ready:          True
    Restart Count:  0
    Limits:
      cpu:     500m
      memory:  256Mi
    Requests:
      cpu:     200m
      memory:  128Mi
    Environment:
      EXPECTED_SCHEMA_VERSION:            1.2.0
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
      /var/run/secrets/kubernetes.io/serviceaccount from demo-instance1-ibm-iaws-sa-token-4zmxj (ro)
Containers:
  wf-ps:
    Container ID:   cri-o://8acdaa919f11964a23d47f96c02686779202439b03cebf484583dea6770ad8f8
    Image:          image-registry.openshift-image-registry.svc:5000/demo-project/iaws-server@sha256:799e69949f9f0ad2554eaafc4b5825e8f4f822fb2c8f183cee6c73320934814c
    Image ID:       image-registry.openshift-image-registry.svc:5000/demo-project/iaws-server@sha256:799e69949f9f0ad2554eaafc4b5825e8f4f822fb2c8f183cee6c73320934814c
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Thu, 19 Mar 2020 08:10:02 -0700
    Ready:          True
    Restart Count:  0
    Limits:
      cpu:     3
      memory:  2096Mi
    Requests:
      cpu:      1
      memory:   1Gi
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
      LDAP_ADMIN_USER:              p8admin
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
      CSRF_ORIGIN_WHITELIST:        https://<OPENSHIFT_MASTER_IP>.nip.io,https://<OPENSHIFT_MASTER_IP>.nip.io:443,https://ums.<OPENSHIFT_MASTER_IP>.nip.io,https://ums.<OPENSHIFT_MASTER_IP>.nip.io:443,https://ae.<OPENSHIFT_MASTER_IP>.nip.io,https://ae.<OPENSHIFT_MASTER_IP>.nip.io:443,https://icn.<OPENSHIFT_MASTER_IP>.nip.io,https://icn.<OPENSHIFT_MASTER_IP>.nip.io:443
      CPE_URL:                      https://demo-cpe-svc:9443/wsi/FNCEWS40MTOM
      CMIS_URL:                     https://demo-cmis-svc:9443/openfncmis_wlp/services
      CPE_DOMAIN_NAME:              P8DOMAIN
      CPE_REPOSITORY:               OS10
      CPE_OBJECTSTORE_ID:           {E340B318-CF17-4C14-8902-AF713D3B0A91}
      CPE_USERNAME:                 <set to the key 'appLoginUsername' in secret 'ibm-fncm-secret'>  Optional: false
      CPE_PASSWORD:                 <set to the key 'appLoginPassword' in secret 'ibm-fncm-secret'>  Optional: false
      WAIT_INTERVAL:                90000
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
      CLUSTERIP_SERVICE_NAME:       demo-instance1-ibm-iaws-server
      APPENGINE_EXTERNAL_HOSTNAME:  ae.<OPENSHIFT_MASTER_IP>.nip.io
      FRAME-ANCESTORS-SETTING:      https://<OPENSHIFT_MASTER_IP>.nip.io https://ums.<OPENSHIFT_MASTER_IP>.nip.io https://ae.<OPENSHIFT_MASTER_IP>.nip.io https://icn.<OPENSHIFT_MASTER_IP>.nip.io
      ENCRYPTION_KEY:               <set to the key 'encryptionKey' in secret 'icp4a-shared-key-secret'>  Optional: false
    Mounts:
      /opt/ibm/wlp/output/defaultServer/resources/security/keystore/jks/server.jks from key-trust-store (rw,path="keystore/jks/server.jks")
      /opt/ibm/wlp/output/defaultServer/resources/security/truststore/jks/trusts.jks from key-trust-store (rw,path="truststore/jks/trusts.jks")
      /opt/ibm/wlp/usr/servers/defaultServer/config/100SCIM.xml from overwrite-configurations (rw,path="100SCIM.xml")
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/jvm.options from overwrite-configurations (rw,path="jvm.options")
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/oidc-rp.xml from overwrite-configurations (rw,path="oidc-rp.xml")
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/processServer_variables_system.xml from overwrite-configurations (rw,path="processServer_variables_system.xml")
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/security100.xml from overwrite-configurations (rw,path="security.xml")
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/ssl.xml from overwrite-configurations (rw,path="ssl.xml")
      /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/z-custom.xml from overwrite-configurations (rw,path="z-custom.xml")
      /opt/ibm/wlp/usr/servers/defaultServer/resources/security from ltpa-store (rw)
      /opt/ibm/wlp/usr/shared/resources/config from configurations (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from demo-instance1-ibm-iaws-sa-token-4zmxj (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
Volumes:
  key-trust-store:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:  <unset>
  trust-tls-volume:
    Type:                Projected (a volume that contains injected data from multiple sources)
    SecretName:          icp4a-root-ca
    SecretOptionalName:  <nil>
    SecretName:          icp4a-root-ca
    SecretOptionalName:  <nil>
  keypair-secret:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  ibm-baw-tls
    Optional:    false
  ltpa-store:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  demo-instance1-ibm-iaws-server-ltpa
    Optional:    false
  overwrite-configurations:
    Type:      ConfigMap (a volume populated by a ConfigMap)
    Name:      demo-instance1-ibm-iaws-server-overwrite-config
    Optional:  false
  configurations:
    Type:      ConfigMap (a volume populated by a ConfigMap)
    Name:      demo-instance1-ibm-iaws-server-config
    Optional:  false
  demo-instance1-ibm-iaws-sa-token-4zmxj:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  demo-instance1-ibm-iaws-sa-token-4zmxj
    Optional:    false
QoS Class:       Burstable
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/memory-pressure:NoSchedule
                 node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason     Age        From                                      Message
  ----    ------     ----       ----                                      -------
  Normal  Scheduled  <unknown>  default-scheduler                         Successfully assigned demo-project/demo-instance1-ibm-iaws-server-0 to worker0.borstal.os.fyre.ibm.com
  Normal  Pulled     11m        kubelet, worker0.borstal.os.fyre.ibm.com  Container image "image-registry.openshift-image-registry.svc:5000/demo-project/dba-keytool-initcontainer@sha256:a428892c7144640f9cf4e15120be4af9c7d1470fd6bf5e6fc8e3294b2feb2147" already present on machine
  Normal  Created    11m        kubelet, worker0.borstal.os.fyre.ibm.com  Created container ssl-init-container
  Normal  Started    11m        kubelet, worker0.borstal.os.fyre.ibm.com  Started container ssl-init-container
  Normal  Pulled     11m        kubelet, worker0.borstal.os.fyre.ibm.com  Container image "image-registry.openshift-image-registry.svc:5000/demo-project/dba-dbcompatibility-initcontainer@sha256:7f03cacee6332b9f1e8f1d506123b1cd98574c07294638418cb37d29670b0e1b" already present on machine
  Normal  Created    11m        kubelet, worker0.borstal.os.fyre.ibm.com  Created container dbcompatibility-init-container
  Normal  Started    11m        kubelet, worker0.borstal.os.fyre.ibm.com  Started container dbcompatibility-init-container
  Normal  Pulled     10m        kubelet, worker0.borstal.os.fyre.ibm.com  Container image "image-registry.openshift-image-registry.svc:5000/demo-project/dba-dbcompatibility-initcontainer@sha256:7f03cacee6332b9f1e8f1d506123b1cd98574c07294638418cb37d29670b0e1b" already present on machine
  Normal  Created    10m        kubelet, worker0.borstal.os.fyre.ibm.com  Created container bawdbcompatibility-init-container
  Normal  Started    10m        kubelet, worker0.borstal.os.fyre.ibm.com  Started container bawdbcompatibility-init-container
  Normal  Pulling    8m36s      kubelet, worker0.borstal.os.fyre.ibm.com  Pulling image "image-registry.openshift-image-registry.svc:5000/demo-project/iaws-server@sha256:799e69949f9f0ad2554eaafc4b5825e8f4f822fb2c8f183cee6c73320934814c"
  Normal  Pulled     7m59s      kubelet, worker0.borstal.os.fyre.ibm.com  Successfully pulled image "image-registry.openshift-image-registry.svc:5000/demo-project/iaws-server@sha256:799e69949f9f0ad2554eaafc4b5825e8f4f822fb2c8f183cee6c73320934814c"
  Normal  Created    7m58s      kubelet, worker0.borstal.os.fyre.ibm.com  Created container wf-ps
  Normal  Started    7m58s      kubelet, worker0.borstal.os.fyre.ibm.com  Started container wf-ps
```

Pod "demo-instance1-ibm-iaws-server-0" has three Init Containers, `ssl-init-container`, `dbcompatibility-init-container` , and `bawdbcompatibility-init-container`. For all Init Containers, the desired State should be `Terminated` with Reason `Completed`. For Container `wf-ps`, the desired Ready state should be `True`.

</p>
</details>
</div>


- Error: failed to start container "demo-cpe-deploy" or "demo-navigator-deploy"

<div>
<details>
<summary>Click to show detailed information and a solution. </summary>
<p>

The detailed error message is something like "Error response from daemon: oci runtime error: container_linux.go:235: starting container process caused "container init exited prematurely"". This kind of error is caused by IBM Content Navigator and Content Platform Engine related PVs and PVCs that are bound incorrectly. The solution is to delete IBM Content Navigator and Content Platform Engine related PVCs, then delete IBM Content Navigator and Content Platform Engine related PVs and NFS folders. Then, re-create them in the reverse order.

</p>
</details>
</div>

- Failed to start Pod "demo-ibm-pfs-elasticsearch-0"

Check the value of the `pfs_configuration.elasticsearch.privileged` property in your Custom Resource configuration. If it's set to `true`, run the `oc describe pod demo-ibm-pfs-elasticsearch-0` command to check the SecurityContextConstraint of pod `demo-ibm-pfs-elasticsearch-0`. Also, ensure it’s set as `openshift.io/scc=ibm-pfs-privileged-scc`. 
```
# oc describe pod demo-ibm-pfs-elasticsearch-0
Name:         demo-ibm-pfs-elasticsearch-0
Namespace:    demo-project
Priority:     0
Node:         worker2.borstal.os.fyre.ibm.com/<OPENSHIFT_NODE_IP>
Start Time:   Thu, 19 Mar 2020 08:25:09 -0700
Labels:       app.kubernetes.io/component=pfs-elasticsearch
              app.kubernetes.io/instance=demo
              app.kubernetes.io/managed-by=Operator
              app.kubernetes.io/name=demo-ibm-pfs-elasticsearch
              app.kubernetes.io/version=20.0.1
              controller-revision-hash=demo-ibm-pfs-elasticsearch-665844b85f
              release=20.0.1
              role=elasticsearch
              statefulset.kubernetes.io/pod-name=demo-ibm-pfs-elasticsearch-0
Annotations:  checksum/config: 6a3747ddc8ce13afdfc85b6793b847d035e8edd5
              cloudpakId: 94a9c8c358bb43ba8fbdea62e7e166a5
              cloudpakName: IBM Cloud Pak for Automation
              cloudpakVersion: 20.0.1
              k8s.v1.cni.cncf.io/networks-status:
                [{
                    "name": "openshift-sdn",
                    "interface": "eth0",
                    "ips": [
                        "10.254.4.254"
                    ],
                    "dns": {},
                    "default-route": [
                        "10.254.4.1"
                    ]
                }]
              openshift.io/scc: ibm-pfs-privileged-scc
              productChargedContainers:
              productCloudpakRatio: 1:1
              productID: 534103df30f0477bb45ec3e02ef6aba0
              productMetric: VIRTUAL_PROCESSOR_CORE
              productName: IBM Cloud Pak for Automation - Automation Workstream Services
              productVersion: 20.0.1
Status:       Running
```

- To enable Automation Workstream Services container logs:

Use the following specification to enable Automation Workstream Services container logs in the Custom Resource configuration:
```yaml
iaws_configuration:
 - name: instance1
   iaws_server:
     logs:
       console_format: “json”
       console_log_level: “INFO”
       console_source: “message,trace,accessLog,ffdc,audit”
       message_format: “basic”
       trace_format: “ENHANCED”
       trace_specification: “WLE.=all:com.ibm.bpm.=all：com.ibm.workflow.*=all”
```

Then, run the `oc logs IAWS_pod_name` command to see the logs, or log into Automation Workstream Services to see the logs.

The following example shows how to check the Automation Workstream Services container logs:
```
$ oc exec -it demo-instance1-ibm-iaws-server-0 bash
$ cat /logs/application/liberty-message.log
```

- To customize the Process Federation Server Liberty server trace setting

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

The following example shows how to check the Process Federation Server container logs:
```
$ oc exec -it demo-ibm-pfs-0 bash
$ cat /logs/application/liberty-message.log
```
