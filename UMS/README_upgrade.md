# Upgrade User Management Service from 19.0.3 to 20.0.1

This document describes the 20.0.1 updates to the User Management Service related configuration parameters.

## Update shared configuration parameters

In `spec` make sure you have defined

| Custom Resource parameter                                                      |        Comment    |
| ------------------------------------------------------------------------------ | ------------------|
| shared_configuration.sc_deployment_type                                        |                   |
| appVersion                                                                     |  20.0.1           |
| shared_configuration.sc_deployment_platform                                    |  OCP or NonOCP    |

For information about shared configuration parameters refer to [Shared Configuration parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_shared_config_params.html)


## Update datasource configuration parameters

The following UMS configuration parameters are new in 20.0.1. 

| Custom Resource parameter                                                      |        Comment    |
| ------------------------------------------------------------------------------ | ------------------|
| datasource_configuration.dc_ums_datasource.dc_ums_oauth_schema                 | Optional parameter, can be specified if a schema was created. |
| datasource_configuration.dc_ums_datasource.dc_ums_teamserver_type              |                   |
| datasource_configuration.dc_ums_datasource.dc_ums_teamserver_host              |                   |
| datasource_configuration.dc_ums_datasource.dc_ums_teamserver_port              |                   |
| datasource_configuration.dc_ums_datasource.dc_ums_teamserver_name              |                   |
| datasource_configuration.dc_ums_datasource.dc_ums_teamserver_ssl               |                   |
| datasource_configuration.dc_ums_datasource.dc_ums_teamserver_ssl_secret_name   |                   |
| datasource_configuration.dc_ums_datasource.dc_ums_teamserver_driverfiles       |                   |
| datasource_configuration.dc_ums_datasource.dc_ums_teamserver_alternate_hosts   |                   |
| datasource_configuration.dc_ums_datasource.dc_ums_teamserver_alternate_ports   |                   |

Except for the `datasource_configuration.dc_ums_datasource.dc_ums_oauth_schema`, the new parameters are used to configure the datasource for 
UMS Teams, a capability that is new in IBM Cloud Pak for Automation 20.0.1. For more information, see [User Management Service Teams](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/con_ums_teams_option.html).

For information about the database configuration parameters, refer to [UMS datasource parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_ums_params_database.html)

## Update UMS docker images

Update the UMS docker image tags to point to the 20.0.1 images and add the `shared_configuration.umsregistration_initjob` parameter that is new in 20.0.1


| Custom Resource parameter                                                      |        Comment    |
| ------------------------------------------------------------------------------ | ------------------|
| ums_configuration.images.ums.tag                                               | update to 20.0.1            |
| shared_configuration.images.keytool_init_container.tag              |  update to 20.0.1                 |
| shared_configuration.images.keytool_job_container.tag              |   update to 20.0.1                |


## LDAP configuration

There are no changes to the `ldap_configuration` section.
For information about LDAP configuration parameters and sample values refer to [Configuring the LDAP and user registry](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_k8s_ldap.html).


## UMS configuration parameters

### Changed parameters

In 20.0.1, changes in behavior apply to the following parameters in `ums_configuration` 

| Custom Resource parameter                     |              Comment |
| --------------------------------------------- | -------------------- |
| ums_configuration.db_secret_name              | Removed in 20.0.1, move the database credentials to the secret `ums_configuration.admin_secret_name`    |
| ums_configuration.hostname                    | In 20.0.1, if no hostname is specified, the hostname is generated from the `shared_configuration.sc_deployment_hostname_suffix` parameter  |
| ums_configuration.external_tls_secret_name    | In 20.0.1, to avoid an invalid configuration in the Custom Resource it is required to create the secret if the parameter is set. If the parameter is set, but the secret is not created, UMS will not be deployed and an error will be thrown in the operator log.|

This `ums-secret.yaml` configuration file provides an example of how to configure the `ibm-dba-ums-secret` 

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ibm-dba-ums-secret
type: Opaque
stringData:
  adminUser: "admin"
  adminPassword: "admin"
  oauthDBUser: "db2inst1"
  oauthDBPassword: "!Passw0rd"
  tsDBUser: "db2inst1"
  tsDBPassword: "!Passw0rd"
```

After you have created the secret, update your Custom Resource to configure `ums_configuration.db_secret_name` to point to the secret `ibm-dba-ums-secret`.

### New parameters
The following optional parameters are new in 20.0.1, they support long-lived access tokens. For more information, see Refer to [Using long-lived access tokens](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/con_ums_sso_app_token.html).

| Custom Resource parameter                             |
| ----------------------------------------------------- |
|  ums_configuration.oauth.token_manager_group          |
|  ums_configuration.oauth.access_token_lifetime        |
|  ums_configuration.oauth.app_token_lifetime           |
|  ums_configuration.oauth.app_password_lifetime        |
|  ums_configuration.oauth.app_token_or_password_limit  |
|  ums_configuration.oauth.client_secret_encoding       |

For information about UMS configuration parameters and sample values, see [UMS parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_ums_params_ums.html).

## Complete the upgrade
Return to the appropriate update page to configure other components and complete the deployment using the operator.

Update pages:
   - [Managed OpenShift installation page](../platform/roks/update.md)
   - [OpenShift installation page](../platform/ocp/update.md)
   - [Certified Kubernetes installation page](../platform/k8s/update.md)
