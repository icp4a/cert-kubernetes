# Migrating IBM Operational Decision Manager 8.10.x data to 8.10.3

## Step 1: Review the database configuration parameters

Operational Decision Manager persists data in a database. An external Db2 or PostgreSQL database uses the following configuration parameters:

 - Server type: **externalDatabase.type**
 - Server name: **externalDatabase.serverName**
 - Port: **externalDatabase.port**
 - Database name: **externalDatabase.databaseName**
 - Secret credentials: **externalDatabase.secretCredentials**

Note the name of the secret that encrypts the database user and password that is used to secure access to the database.

A customized database uses the following configuration parameters:

 - Data source secret: **externalCustomDatabase.datasourceRef**
 - Persistent Volume Claim to access the JDBC database driver: **externalCustomDatabase.driverPvc**

If you customized the Decision Center Business console with your own implementation of dynamic domains, custom value editors, or custom ruleset extractors you must note the name of the YAML file you previously created, for example *custom-dc-libs-pvc.yaml*.

An internal database uses a predefined persistent volume claim (PVC) or Kubernetes dynamic provisioning. You must have a persistent volume (PV) already created with accessMode and ReadWriteOnce attributes for Operational Decision Manager containers. Dynamic provisioning uses the default storageClass defined by the Kubernetes admin or by using a custom storageClass that overrides the default.

Predefined PVC

 - **internalDatabase.persistence.enabled**: true (default)
 - **internalDatabase.persistence.useDynamicProvisioning**: false (default)

Kubernetes dynamic provisioning

 - **internalDatabase.persistence.enabled**: true (default)
 - **internalDatabase.persistence.useDynamicProvisioning**: true

## Step 2: Review LDAP settings

Make a note of the Lightweight Directory Access Protocol (LDAP) parameters that are used to connect to the LDAP server to validate users. The Directory service server has a number of mandatory configuration parameters, so save these values somewhere and refer to them when you configure the custom resource YAML file. For more information, see [LDAP configuration parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_k8s_ldap.html).

## Step 3: Review other customizations you applied

If you customized your Operational Decision Manager installation, go to the [IBM Cloud Pak for Automation 20.0.x](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/con_odm_prod.html) Knowledge Center and remind yourself of the customizations you applied and need to apply again in the new ODM instance.

## Step 4: Go back to the platform readme to migrate other components

- [Managed OpenShift migrate page](../platform/roks/migrate.md)
- [OpenShift migrate page](../platform/ocp/migrate.md)
- [Kubernetes migrate page](../platform/k8s/migrate.md)
