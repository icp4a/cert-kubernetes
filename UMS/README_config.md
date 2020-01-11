# Configuring User Management Service 19.0.3

These instructions cover the configuration of the User Management Service.
You need a copy of the custom resources YAML file that you created previously.


## <a name="planning-ums-installation"></a> Planning UMS installation

| Environment size | CPU Minimum (m) | Memory Minimum (Mi) | recommended number of pods |
| ---------- | ----------- | ------------------- | -------------------------- |
| Small      | 500         | 512                 | 2                          |
| Medium     | 1000        | 1024                | 2                          |
| Large      | 2000        | 2048                | 3                          |


## Prerequisites

Make sure in `shared_configuration` you specified the configuration parameter `sc_deployment_platform`.
If you deploy on Red Hat OpenShift, specify

```yaml
spec:
 shared_configuration:
   sc_deployment_platform: OCP
```

otherwise specify

```yaml
spec:
 shared_configuration:
   sc__deployment_platform: !OCP
```


## <a name="Step-1"></a> Step 1: Generate UMS secret and DB secret
If you are using Db2 or Oracle create the OAuth database, e.g. `UMSDB`.

To avoid passing sensitive information via configuration files, you must create two secrets manually before you deploy UMS.
Copy the following as ums-secret.yaml, then edit it to specify the required user identifiers and passwords.

**Note:** The sample below includes sample values for passwords. For `ibm-dba-ums-secret` choose passwords that reflect your security requirements.
For `ibm-dba-ums-db-secret` specify user identifiers and passwords you configured for your OAuth database.

**Note:** Team Server is an experimental internal component that has been in the User Management Service since 19.0.2. 
`ibm-dba-ums-secret` and `ibm-dba-ums-db-secret` must include Team Server parameters, as described below.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ibm-dba-ums-secret
type: Opaque
stringData:
  adminUser: "umsadmin"
  adminPassword: "password"
  sslKeystorePassword: "sslPassword"
  jwtKeystorePassword: "jwtPassword"
  teamserverClientID: "ts"
  teamserverClientSecret: "tsSecret"
  ltpaPassword: "ltpaPassword"
---
apiVersion: v1
kind: Secret
metadata:
  name: ibm-dba-ums-db-secret
type: Opaque
stringData:
  oauthDBUser: "db2inst1"
  oauthDBPassword: "!Passw0rd"
  tsDBUser: "db2inst1"
  tsDBPassword: "!Passw0rd"
```

| Parameter                          | Description                                     |
| -------------------------------    | ---------------------------------------------   |
| `adminUser`                        | User ID of the UMS admin user to create         |
| `adminPassword`                    | Password for the UMS admin user                 |
| `sslKeystorePassword`              | Password for the internal UMS SSL keystore      |
| `jwtKeystorePassword`              | Password for the internal UMS JWT keystore      |
| `teamserverClientID`               | Experimental: ID for the Team Server's OIDC client            |
| `teamserverClientSecret`           | Experimental: Secret for the Team Server's OIDC client        |
| `ltpaPassword`                     | Password for the internal UMS LTPA key          |
| `oauthDBUser`                      | User ID for the OAuth database                  |
| `oauthDBPassword`                  | Password for the OAuth database                 |
| `tsDBUser`                         | Experimental: User ID for the Team Server database            |
| `tsDBPassword`                     | Experimental: Password for the Team Server database           |

Only specify the database settings if you are not using the internal derby database. 
The derby database can only be used for a deployment with one UMS pod in test scenarios.

Apart from the database values that relate to your specific database setup, you can choose all secret values freely.

After modifying the values, save ums-secret.yaml and create the secrets by running the following command

```bash
oc create -f ums-secret.yaml
```

**Note:** `ibm-dba-ums-secret` and `ibm-dba-ums-db-secret` are passed to the Operator 
by specifying corresponding properties in the `ums_configuration` section, as described in the following steps.


## Step 2: Configure the UMS datasource
In the section `dc_ums_datasource` adjust database configuration parameters. 

```yaml
datasource_configuration:
  dc_ums_datasource: # credentials are read from ums_configuration.db_secret_name
    # oauth database config
    dc_ums_oauth_type: db2 # derby (for test), db2 or oracle 
    dc_ums_oauth_host: <your ums oauth db hostname>
    dc_ums_oauth_port: 50000
    dc_ums_oauth_name: UMSDB
    dc_ums_oauth_ssl: false
    dc_ums_oauth_ssl_secret_name: 
    dc_ums_oauth_driverfiles:
    dc_ums_oauth_alternate_hosts:
    dc_ums_oauth_alternate_ports:
```

For information about UMS configuration parameters and their default values, see
[UMS Database Configuration Parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_ums_params_database.html)


## <a name="configure-failover"></a> Step 2a (optional): Configure database failover servers

To cover the possibility that the primary server is unavailable during the initial connection attempt, you can configure a list of failover servers, as described in [Configuring client reroute for applications that use DB2 databases](https://www.ibm.com/support/knowledgecenter/en/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/twlp_config_reroute_db2.html).

In the custom resources YAML file, provide a comma-separated list of failover servers and failover ports. 
For example, if there are two failover servers
* server1.db2.company.com on port 50443
* server2.db2.company.com on port 51443

in `dc_ums_datasource section` specify:
```yaml
datasource_configuration:
  dc_ums_datasource: 
    ...
    dc_ums_oauth_alternate_hosts: "server1.db2.company.com, server2.db2.company.com"
    dc_ums_oauth_alternate_ports: "50443, 51443"
```
	
	
## <a name="configure-db2-ssl"></a>Step 2b (optional): Configure SSL between UMS and Db2  
To ensure that all communications between UMS and Db2 are encrypted, import the database CA Certificate to UMS and create a secret to store the certificate:

```
oc create secret generic ibm-dba-ums-db2-cacert --from-file=cacert.crt=<path-to-certificate-file>
```

**Note:** The certificate must be in PEM format. Specify the `<path-to-certificate-file>` to point to the certificate file. Do not change the part `--from-file=cacert.crt=`.

Use the generated secret to configure the Db2 SSL parameters in the custom resources YAML file: 
```yaml
datasource_configuration:
  dc_ums_datasource: 
    ...
    dc_ums_oauth_ssl_secret_name: ibm-dba-ums-db2-cacert
    dc_ums_oauth_ssl: true
```


## <a name="Step-3"></a> Step 3: Configure LDAP

In section `ldap_configuration`, adapt the LDAP configuration parameter values to match your LDAP server.

For information about LDAP configuration parameters and sample values refer to 
[Configuring the LDAP and user registry](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_k8s_ldap.html).


## Step 4: Configure UMS
In section `ums_configuration` adapt the UMS-specific configuration

```yaml
  ums_configuration:
    existing_claim_name:
    replica_count: 2
    service_type: Route
    hostname:  <your external UMS host name>
    port: 443
    images:
      ums:
        repository: cp.icr.io/cp/cp4a/ums/ums
        tag: 19.0.3
    admin_secret_name: ibm-dba-ums-secret
    db_secret_name: ibm-dba-ums-db-secret
    external_tls_secret_name: ibm-dba-ums-external-tls-secret
    external_tls_ca_secret_name: ibm-dba-ums-external-tls-ca-secret
    oauth:
      client_manager_group:
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 200m
        memory: 256Mi
    ## Horizontal Pod Autoscaler
    autoscaling:
      enabled: true
      min_replicas: 2
      max_replicas: 5
      target_average_utilization: 98
    use_custom_jdbc_drivers: false
    use_custom_binaries: false
    custom_secret_name:
    custom_xml:
    logs:
      console_format: json
      console_log_level: INFO
      console_source: message,trace,accessLog,ffdc,audit
      trace_format: ENHANCED
      trace_specification: "*=info"
```

For information about UMS configuration parameters and their default values, see 
[UMS Configuration Parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_ums_params_ums.html) 


## <a name="Step-4a"></a> Step 4a (optional): Configure secure communication with UMS 

See [Configuring secure communication with UMS](README_config_SSL.md)

## Step 5: Complete the installation

Return to the appropriate install or update page to configure other components and complete the deployment with the operator.

Install pages:
   - [Managed OpenShift installation page](../platform/roks/install.md)
   - [OpenShift installation page](../platform/ocp/install.md)
   - [Certified Kubernetes installation page](../platform/k8s/install.md)

Update pages:
   - [Managed OpenShift installation page](../platform/roks/update.md)
   - [OpenShift installation page](../platform/ocp/update.md)
   - [Certified Kubernetes installation page](../platform/k8s/update.md)