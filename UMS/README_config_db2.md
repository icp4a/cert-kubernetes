# Configure Db2 as the UMS datasource

Create the OAuth database, for example, `UMSDB`, by running
```
db2 create database UMSDB automatic storage yes using codeset UTF-8 territory US pagesize 32768
```

In the section `dc_ums_datasource` adjust the database configuration parameters. 

```yaml

datasource_configuration:
  dc_ums_datasource: # credentials are read from ums_configuration.admin_secret_name
    # oauth database config
    dc_ums_oauth_type: db2 # derby (for test), db2, oracle
    dc_ums_oauth_host: <dbhost>
    dc_ums_oauth_port: 50000
    dc_ums_oauth_name: UMSDB
    dc_ums_oauth_schema: <OAuthDBSchema>
    dc_ums_oauth_ssl: false
    dc_ums_oauth_ssl_secret_name:
    dc_ums_oauth_driverfiles:
    dc_ums_oauth_alternate_hosts:
    dc_ums_oauth_alternate_ports:
    # teamserver database config
    dc_ums_teamserver_type: db2 # derby (for test), db2, oracle
    dc_ums_teamserver_host: <dbhost>
    dc_ums_teamserver_port: 50000
    dc_ums_teamserver_name: UMSDB
    dc_ums_teamserver_ssl: false
    dc_ums_teamserver_ssl_secret_name:
    dc_ums_teamserver_driverfiles:
    dc_ums_teamserver_alternate_hosts:
    dc_ums_teamserver_alternate_ports:
```
For information about UMS configuration parameters and their default values, see
[UMS datasource parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_ums_params_database.html)

## <a name="configure-failover"></a>Configure database failover servers (optional)

To cover the possibility that the primary server is unavailable during the initial connection attempt, you can configure a list of failover servers, as described in [Configuring client reroute for applications that use DB2 databases](https://www.ibm.com/support/knowledgecenter/en/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/twlp_config_reroute_db2.html).

In the Custom Resource, provide a comma-separated list of failover servers and failover ports. 
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
    ...
    dc_ums_teamserver_alternate_hosts: "server1.db2.company.com, server2.db2.company.com"
    dc_ums_teamserver_alternate_ports: "50443, 51443"
```
	
	
## <a name="configure-db2-ssl"></a>Configure SSL between UMS and Db2 (optional)
To ensure that all communications between UMS and Db2 are encrypted, import the database CA Certificate to UMS and create a secret to store the certificate:

```
oc create secret generic ibm-dba-ums-db2-cacert --from-file=cacert.crt=<path-to-certificate-file>
```

**Note:** The certificate must be in PEM format. Specify the `<path-to-certificate-file>` to point to the certificate file. Do not change the part `--from-file=cacert.crt=`.

Use the generated secret to configure the Db2 SSL parameters in the Custom Resource: 
```yaml
datasource_configuration:
  dc_ums_datasource: 
    ...
    dc_ums_oauth_ssl_secret_name: ibm-dba-ums-db2-cacert
    dc_ums_oauth_ssl: true
    ...
    dc_ums_ts_ssl_secret_name: ibm-dba-ums-db2-cacert
    dc_ums_ts_ssl: true
```

## Continue with UMS configuration
You configured Db2 as the UMS datasource.

Continue with the UMS configuration: [README_config.md](README_config.md)
