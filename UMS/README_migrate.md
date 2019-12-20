# Migrate User Management Service configuration from 19.0.2 to 19.0.3


The following table maps User Management Service configuration parameters that were used in the
19.0.2 helm chart to config parameters in the Custom Resource YAML file you use in Cloud Pak for Automation 19.0.3.

## Datasource configuration parameters

| Helm Chart parameters in 19.0.2 | Custom Resource parameter in 19.0.3                                                 |              Comment |
| ------------------------------- | ----------------------------------------------------------------------------------- | -------------------- |
|  oauth.database.type            | datasource_configuration.dc_ums_datasource.dc_ums_oauth_type                   |                      |
|  oauth.database.host            | datasource_configuration.dc_ums_datasource.dc_ums_oauth_host                   |                      |
|  oauth.database.port            | datasource_configuration.dc_ums_datasource.dc_ums_oauth_port                   |                      |
|  oauth.database.name            | datasource_configuration.dc_ums_datasource.dc_ums_oauth_name                   |                      |
|  oauth.database.ssl             | datasource_configuration.dc_ums_datasource.dc_ums_oauth_ssl                    |                      |
|  oauth.database.sslSecretName   | datasource_configuration.dc_ums_datasource.dc_ums_oauth_ssl_secret_name        |                      |
|  oauth.database.driverfiles     | datasource_configuration.dc_ums_datasource.dc_ums_oauth_driverfiles            |                      |
|  oauth.database.alternateHosts  | datasource_configuration.dc_ums_datasource.dc_ums_oauth_alternate_hosts        |                      |
|  oauth.database.alternatePorts  | datasource_configuration.dc_ums_datasource.dc_ums_oauth_alternate_ports        |                      |


## UMS docker images

| Helm Chart parameters in 19.0.2 | Custom Resource parameter in 19.0.3                                            |              Comment |
| ------------------------------- | ------------------------------------------------------------------------------ | -------------------- |
|  images.ums                     | ums_configuration.images.ums.repository, ums_configuration.images.ums.tag      | In 19.0.2 the tag was appended to the repository link |
|  images.initTLS                 | shared_configuration.images.keytool_init_container.repository, shared_configuration.images.keytool_init_container.tag | In 19.0.2 the tag was appended to the repository link                     |
|  images.ltpa                    | shared_configuration.images.keytool_job_container.repository, shared_configuration.images.keytool_job_container.tag | In 19.0.2 the tag was appended to the repository link                     |
|  images.pullPolicy              | shared_configuration.images.pull_policy |


## LDAP configuration

In 19.0.2 LDAP was configured by providing Liberty server LDAP configuration using the customXML parameter.
In 19.0.3 specify the LDAP configuration parameters in `ldap_configuration`. 
For information about LDAP configuration parameters and sample values refer to [Configuring the LDAP and user registry](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_k8s_ldap.html).


## UMS configuration parameters

| Helm Chart parameters in 19.0.2 | Custom Resource parameter in 19.0.3           |         Comment       |
| ------------------------------- | ----------------------------------------------| -------------------- |
|  global.existingClaimName       | ums_configuration.existing_claim_name         |                      |
|  global.isOpenShift             | shared_configuration.sc_deployment_platform   |                      |
|  global.imagePullSecrets        | shared_configuration.image_pull_secrets       |                      |
|  global.ums.serviceType         | ums_configuration.service_type                |                      |
|  global.ums.hostname            | ums_configuration.hostname                    |                      |
|  global.ums.port                | ums_configuration.port                        |                      |
|  global.ums.adminSecretName     | ums_configuration.admin_secret_name           |                      |
|  global.ums.dbSecretName        | ums_configuration.db_secret_name              |                      |
|  global.ums.ltpaSecretName      |                                                    | removed, secret is generated in 19.0.3  |
|  tls.tlsSecretName              |                                                    | removed, secret is generated in 19.0.3  |
|                                 | ums_configuration.external_tls_secret_name    | new parameter in 19.0.3 |
|                                 | ums_configuration.external_tls_ca_secret_name | new parameter in 19.0.3 |
|  oauth.clientManagerGroup       | ums_configuration.oauth.client_manager_group  |                      |
|  resources.limits.cpu           | ums_configuration.resources.limits.cpu        |                      |
|  resources.limits.memory        | ums_configuration.resources.limits.memory     |                      |
|  resources.requests.cpu         | ums_configuration.resources.requests.cpu      |                      |
|  resources.requests.memory      | ums_configuration.resources.requests.memory   |                      |
|  useCustomJDBCDrivers           | ums_configuration.use_custom_jdbc_drivers     |                      |
|  useCustomBinaries              | ums_configuration.use_custom_binaries         |                      |
|  customSecretName               | ums_configuration.custom_secret_name          |                      |
|  logs.tracespefication          | ums_configuration.logs.trace_specification     |                      |
|  logs.consoleFormat             | ums_configuration.logs.console_format          |                      |
|  logs.consoleLogLevel           | ums_configuration.logs.console_log_level        |                      |
|  logs.consoleSource             | ums_configuration.logs.console_source          |                      |
|  logs.traceFormat               | ums_configuration.logs.trace_format            |                      |
|  replicaCount                   | ums_configuration.replica_count               |                      |
|  autoscaling.enabled            | ums_configuration.autoscaling.enabled         |                      |
|  autoscaling.minReplicas        | ums_configuration.autoscaling.min_replicas     |                      |
|  autoscaling.maxReplicas        | ums_configuration.autoscaling.max_replicas     |                      |
|  autoscaling.targetAverageUtilization | ums_configuration.autoscaling.target_average_utilization |       |
|  resources.limits.cpu           | ums_configuration.resources.limits.cpu        |                      |
|  resources.limits.memory        | ums_configuration.resources.limits.memory     |                      |
|  resources.requests.cpu         | ums_configuration.resources.requests.cpu      |                      |
|  resources.requests.memory      | ums_configuration.resources.requests.memory     |                      |
|  customXml                      | ums_configuration.custom_xml                  | for LDAP parameters use ldap_configuration to configure LDAP |
|  customSecretName               | ums_configuration.custom_secret_name          |                      |
|  useCustomBinaries              | ums_configuration.use_custom_binaries         |                      |


Once you understand how the helm configuration parameters map to the parameters in the Custom Resource YAML file, continue with the [UMS configuration](README_config.md)
