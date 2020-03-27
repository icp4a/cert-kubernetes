# Upgrade IBM Operational Decision Manager from 19.0.3 to 20.0.1

## Update the custom resource YAML file used in 19.0.3

This document describes the configuration parameter changes between 19.0.3 and 20.0.1 that might affect your ODM upgrade.

### Shared configuration parameter changes

In the custom resource file, make sure that the `spec` section includes the following parameters:

| Custom Resource parameter                                                      |        Comment    |
| ------------------------------------------------------------------------------ | ------------------|
| shared_configuration.sc_deployment_type                                        |  production or non-production |
| shared_configuration.sc_deployment_platform                                    |  OCP, ROKS, or empty. |
| shared_configuration.images.keytool_init_container.tag              | New in 20.0.1 for ODM. Used to manage certificates. |
| shared_configuration.images.keytool_init_container.repository              |  New in 20.0.1 for ODM. Used to manage certificates. |
| shared_configuration.images.pull_policy              | New in 20.0.1 for ODM. Used to manage certificates.  |
| shared_configuration.image_pull_secrets |  New in 20.0.1 for ODM. Used to manage certificates.  |
| shared_configuration.root_ca_secret |  New in 20.0.1 for ODM. Used to manage certificates.  |

For more information, see [Shared configuration parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_shared_config_params.html).

### Datasource configuration parameter changes

The following ODM configuration parameters are new in 20.0.1.
If you use external DB2 Database, you must add this following section in your custom resource with their values in replacement of the `odm_configuration.externalDatabase` parameters.

| Custom Resource parameter                                                      |
| ------------------------------------------------------------------------------ |
| datasource_configuration.dc_odm_datasource.dc_database_type              |                   
| datasource_configuration.dc_odm_datasource.database_servername               |                   
| datasource_configuration.dc_odm_datasource.dc_common_database_name           |                   
| datasource_configuration.dc_odm_datasource.dc_common_database_port             |                   
| datasource_configuration.dc_odm_datasource.dc_common_database_instance_secret          |                   

These parameters are used to configure the datasource for ODM. For more information, see [ODM datasource parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_parameters_prod.html).

### LDAP configuration parameters

The following LDAP configuration parameters can be used for ODM in 20.0.1. If you want to use an LDAP with ODM you need to set values for them.

If your custom resource contains a `ldap_configuration` section and if you have not set the `odm_configuration.customization.authSecretRef`, the Basic Registry and LDAP authentication will be used by ODM in 20.0.1. If you want to have a fine grain Authentication, follow the instructions to [Configuring User Access](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/tsk_config_user_access.html)

| Custom Resource parameter                                                      |  
| ------------------------------------------------------------------------------ |
| ldap_configuration.lc_selected_ldap_type                                        |                   
| ldap_configuration.lc_ldap_server                                     |                   
| ldap_configuration.lc_ldap_port                                     |                   
| ldap_configuration.lc_bind_secret                                     |                   
| ldap_configuration.lc_ldap_base_dn                                     |                   
| ldap_configuration.lc_ldap_ssl_enabled                                     |                   
| ldap_configuration.lc_ldap_ssl_secret_name                                     |                   
| ldap_configuration.lc_ldap_user_name_attribute                                     |                   
| ldap_configuration.lc_ldap_user_display_name_attr                                     |                   
| ldap_configuration.lc_ldap_group_base_dn                                     |                   
| ldap_configuration.lc_ldap_group_name_attribute                                     |                   
| ldap_configuration.lc_ldap_group_display_name_attr                                     |                   
| ldap_configuration.lc_ldap_group_membership_search_filter                                     |                   
| ldap_configuration.lc_ldap_group_member_id_map                                     |                   
| ldap_configuration.ad.lc_user_filter                                     |                   
| ldap_configuration.ad.lc_group_filter                                     |                   
| ldap_configuration.tds.lc_user_filter                                     |                   
| ldap_configuration.tds.lc_group_filter                                      |                   


For more information, see [LDAP configuration parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_k8s_ldap.html).


### Update ODM docker images

Update the ODM docker image tags to point to the new 20.0.1 images.

| Custom Resource parameter                                                      |        Comment    |
| ------------------------------------------------------------------------------ | ------------------|
| odm_configuration.images.tag                                               | update to 8.10.3.0_ICP2001  |
| odm_configuration.version                      | update to 20.0.1           |


### New parameters in ODM configuration
In 20.0.1, changes apply to the following new parameters in `odm_configuration` if needed.

| Custom Resource parameter                     |   
| --------------------------------------------- |
| odm_configuration.decisionServerRuntime.xuConfigRef |  
| odm_configuration.oidc.enabled |  
| odm_configuration.oidc.serverUrl |  
| odm_configuration.oidc.adminRef |
| odm_configuration.oidc.redirectUrisRef |
| odm_configuration.oidc.clientRef |
| odm_configuration.oidc.provider |
| odm_configuration.oidc.allowedDomains |

For more information, see [Optimizing the execution unit (XU)](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/tsk_configuring_xu.html) and  [Configuring user access with UMS documentation](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/tsk_config_odm_ums.html).


## Complete the upgrade
Return to the appropriate upgrade page to configure other components and complete the deployment using the operator.

Upgrade pages:
   - [Managed OpenShift upgrade page](../platform/roks/upgrade.md)
   - [OpenShift upgrade page](../platform/ocp/upgrade.md)
   - [Certified Kubernetes upgrade page](../platform/k8s/upgrade.md)
