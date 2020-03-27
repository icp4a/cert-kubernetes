# Configure Oracle as the UMS datasource

## Update datasource configuration in the Custom Resource
In section `dc_ums_datasource` adjust database configuration parameters. 

```yaml
datasource_configuration:
  dc_ums_datasource: # credentials are read from ums_configuration.admin_secret_name
    # oauth database config
    dc_ums_oauth_type: oracle # derby (for test), db2, oracle
    dc_ums_oauth_host: <your db host>
    dc_ums_oauth_port: 1521
    dc_ums_oauth_name: <SID of your oracle db>
    dc_ums_oauth_schema: <your db user>
    dc_ums_oauth_ssl: false
    dc_ums_oauth_ssl_secret_name:
    dc_ums_oauth_driverfiles: ojdbc8.jar
    dc_ums_oauth_alternate_hosts:
    dc_ums_oauth_alternate_ports:

```

For the mandatory UMS Teams database, only Db2 is supported. 
Follow instructions in [Configure Db2 as the UMS datasource](README_config_db2.md) to configure Db2.

## Provide Oracle JDBC drivers

Create a persistent volume and create a persistent volume claim for that PV. 
Consider the following sample configuration in `my-data-pv.yaml`. Add the hostname or IP address of your NFS server to the configuration.

```yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: data-pv
  labels:
    type: icp4a-pv
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: inf-node
  mountOptions:
    - nolock
  nfs:
    path: /data
    server: <IP/hostname of the NFS server> 
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: data-pvc
spec:
  accessModes:
    - ReadWriteMany
  volumeMode: Filesystem
  storageClassName: inf-node
  resources:
    requests:
      storage: 1Gi
  selector:
    matchLabels:
      type: icp4a-pv
  volumeName: data-pv
```

Deploy the PV and PVC:
```
oc create -f my-data-pv.yaml
```

In section `ums_configuration` configure parameters `use_custom_jdbc_drivers` and `existing_claim_name`:

```
use_custom_jdbc_drivers: true
existing_claim_name: data-pvc
```

Copy the Oracle JDBC driver to the jdbc/oracle directory on the mounted file system. 

```
    /data

       └── jdbc

          └── oracle

              └── ojdbc8.jar

```
**Note:** The name of the JDBC driver is referenced in property `datasource_configuration.dc_ums_oauth_driverfiles` in the Custom Resource.

For information about UMS configuration parameters and their default values, see
[UMS Database Configuration Parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_ums_params_database.html)

## Continue with UMS configuration
You configured Oracle as the UMS datasource.

Continue with the UMS configuration: [README_config.md](README_config.md)
