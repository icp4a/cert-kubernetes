# Configuring IBM FileNet Content Manager 5.5.4

IBM FileNet Content Manager provides numerous containerized components for use in your container environment. The configuration settings for the components are recorded and stored in the shared YAML file for operator deployment. After you prepare your environment, you add the values for your configuration settings to the YAML so that the operator can deploy your containers to match your environment. 

## Requirements and prerequisites

Confirm that you have completed the following tasks to prepare to deploy your FileNet Content Manager images:

- Prepare your FileNet Content Manager environment. These procedures include setting up databases, LDAP, storage, and configuration files that are required for use and operation. You must complete all of the [preparation steps for FileNet Content Manager](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_prepare_ecmk8s.html) before you are ready to deploy the container images. Collect the values for these environment components; you use them to configure your FileNet Content Manager container deployment.

- Prepare your container environment. See [Preparing to install automation containers on Kubernetes](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/welcome/com.ibm.dba.install/op_topics/tsk_prepare_env_k8s.html)

- If you want to deploy additional optional containers, prepare the requirements that are specific to those containers. For details see the following information:
  - [Preparing for External Share](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_cm_externalshareop.html)
  - [Preparing volumes and folders for the Content Services GraphQL API](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_gqlvolumesop.html)

If you plan to use external key management in your environment, review the following preparation information before you deploy: [Preparing for external key management](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_prepare_ecm_externalkeyk8s.html)

> **Note**: If you plan to use UMS integration with any of the FileNet Content Manager components, note that you might encounter registration failure errors during deployment. This can happen if the UMS deployment is not ready by the time the other containers come up. The situation resolves in the next operator loop, so the errors can be ignored.  


## Prepare your security environment

Before you deploy, you must create a secret for the security details of the LDAP directory and datasources that you configured in preparation for use with FileNet Content Manager. Collect the users, password, and namespace to add to the secret. Using your values, run the following command:

   ```
kubectl create secret generic ibm-fncm-secret \
--from-literal=gcdDBUsername="db2inst1" --from-literal=gcdDBPassword="xxxxxxxx" \
--from-literal=osDBUsername="db2inst1" --from-literal=osDBPassword="xxxxxxxx" \
--from-literal=ldapUsername="cn=root" --from-literal=ldapPassword="xxxxxxxxxx" \
--from-literal=externalLdapUsername="cn=User1,ou=test,dc=external,dc=com" --from-literal=externalLdapPassword="xxxxxxx" \
--from-literal=appLoginUsername="filenet_admin" --from-literal=appLoginPassword="xxxxxxxx" \
--from-literal=keystorePassword="xxxxx" \
--from-literal=ltpaPassword="xxxxxx"
   ```
The secret you create is the value for the parameter `fncm_secret_name`.

  
### Root CA and trusted certificate list

   The custom YAML file also requires values for the `root_ca_secret` and `trusted_certificate_list` parameters. The TLS secret contains the root CA's key value pair. You have the following choices for the root CA:
   - You can generate a self-signed root CA
   - You can allow the operator (or ROOTCA ansible role) to generate the secret with a self-signed root CA (by not specifying one)
   - You can use a signed root CA. In this case, you create a secret that contains the root CA's key value pair in advance.

   The list of the trusted certificate secrets can be a TLS secret or an opaque secret. An opaque secret must contain a tls.crt file for the trusted certificate. The TLS secret has a tls.key file as the private key.
   
   Note that if you plan to use the external Content Platform Engine tools, you must use either the Root CA and trusted certificate list or Ingress configuration.

## Customize the YAML file for your deployment

All of the configuration values for the components that you want to deploy are included in the [ibm_cp4a_cr_template.yaml](../descriptors/ibm_cp4a_cr_template.yaml) file. Create a copy of this file on the system that you prepared for your container environment, for example `my_ibm_cp4a_cr_template.yaml`. 

The custom YAML file includes the following sections that apply for all of the components:
- shared_configuration - Specify your deployment and your overall security information.
- ldap_configuration - Specify the directory service provider information for all components in this common section.
- datasource configuration - Specify the database information for all components in this common section.
- monitoring_configuration - Optional for deployments where you want to enable monitoring.
- logging_configuration - Optional for deployments where you want to enable logging.

After the shared section, the YAML includes a section of parameters for each of the available components. If you plan to include a component in your deployment, you un-comment the parameters for that component and update the values. For some parameters, the default values are sufficient. For other parameters, you must supply values that correspond to your specific environment or deployment needs. 

The optional initialize_configuration and verify_configuration section includes values for a set of automatic set up steps for your FileNet P8 domain and IBM Business Automation Navigator deployment. 

If you want to exclude any components from your deployment, leave the section for that component and all related parameters commented out in the YAML file. 

All FileNet Content Manager components require that you deploy the Content Platform Engine container. For that reason, you must complete the values for that section in all deployment use cases.

For a more focused YAML file that contains the default value for each FileNet Content Manager parameter, see the [fncm_ban_sample_cr.yaml](configuration/fncm_ban_sample_cr.yaml). You can use this shorter sample resource file to compile all the values you need for your FileNet Content Manager environment, then copy the sections into the [ibm_cp4a_cr_template.yaml](../descriptors/ibm_cp4a_cr_template.yaml) file before you deploy.

A description of the configuration parameters is available in [Configuration reference for operators](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_paramsop.html)

Use the information in the following sections to record the configuration settings for the components that you want to deploy.

- [Shared configuration settings](README_config.md#shared-configuration-settings)
- [Content Platform Engine settings](README_config.md#content-platform-engine-settings)
- [Content Search Services settings](README_config.md#content-search-services-settings)
- [Content Management Interoperability Services settings](README_config.md#content-management-interoperability-services-settings)
- [Content Services GraphQL settings](README_config.md#content-services-graphql-settings)
- [External Share settings](README_config.md#external-share-settings)
- [Task Manager settings](README_config.md#task-manager-settings)
- [Initialization settings](README_config.md#initialization-settings)
- [Verification settings](README_config.md#verification-settings)

### Shared configuration settings

Un-comment and update the values for the shared configuration, LDAP, datasource, monitoring, and logging parameters, as applicable.

  > **Reminder**: Set `shared_configuration.sc_deployment_platform` to a blank value if you are deploying on a non-OpenShift certified Kubernetes platform.


Use the secrets that you created in Preparing your security environment for the `root_ca_secret` and `trusted_certificate_list` values.

> **Reminder**: If you plan to use External Share with the 2 LDAP model for configuring external users, update the LDAP values in the `ext_ldap_configuration` section of the YAML file with the information about the directory server that you configured for external users. If you are not using the 2 LDAP model of external share, leave this section commented out.

For more information about the shared parameters, see the following topics:

- [Shared parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opsharedparams.html)
- [LDAP parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_k8s_ldap.html)
- [Datasource parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_dbparams.html)
- [Monitoring parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opmonparams.html)

### Content Platform Engine settings

Use the `cpe` section of the custom YAML to provide values for the configuration of Content Platform Engine. You provide details for configuration settings that you have already created, like the names of your persistent volume claims. You also provide names for pieces of your Content Platform Engine environment, and tuning decisions for your runtime environment.

For more information about the settings, see [Content Platform Engine parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opcpeparams.html)

### Content Search Services settings

Use the `css` section of the custom YAML to provide values for the configuration of Content Search Services. You provide details for configuration settings that you have already created, like the names of your persistent volume claims. You also provide names for pieces of your Content Search Services environment, and tuning decisions for your runtime environment.

For more information about the settings, see [Content Search Services parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opcssparams.html)

### Content Management Interoperability Services settings

Use the `cmis` section of the custom YAML to provide values for the configuration of Content Search Services. You provide details for configuration settings that you have already created, like the names of your persistent volume claims. You also provide names for pieces of your Content Search Services environment, and tuning decisions for your runtime environment.

For more information about the settings, see [Content Management Interoperability Services parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opcmisparams.html)

### Content Services GraphQL settings

Use the `graphql` section of the custom YAML to provide values for the configuration of the Content Services GraphQL API. You provide details for configuration settings that you have already created, like the names of your persistent volume claims. You also provide names for pieces of your Content Services GraphQL environment, and tuning decisions for your runtime environment.

The section includes a parameter for enabling the GraphiQL development interface. Note the following consideration for including GraphiQL in your environment:

- If you are deploying the GraphQL container as part of a test or development environment and you want to use GraphiQL with the API, set the enable_graph_iql parameter to true. 
- If you are deploying the GraphQL container as part of a production environment, it is recommended to set the enable_graph_iql parameter to false.

For more information about the settings, see [Content Services GraphQL parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opgqlparams.html)

### External share settings

Use the `es` section of the custom YAML to provide values for the configuration of External Share. You provide details for configuration settings that you have already created, like the names of your persistent volume claims. You also provide names for pieces of your External Share environment, and tuning decisions for your runtime environment.

> **Reminder**: If you are using the 2 LDAP approach for managing your external users for external share, you must configure the ext_ldap_configuration section in the shared parameters with information about your external user LDAP directory service.

> **Note**: If you are deploying the External Share container as an update instead of as part of the initial container deployment, note that both the Content Platform Engine and the Business Automation Navigator containers will undergo a rolling update to accommodate the External Share configuration.

For more information about the settings, see [External Share parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opesparams.html)

### Task Manager settings

Use the `tm` section of the custom YAML to provide values for the configuration of Task Manager. You provide details for configuration settings that you have already created, like the names of your persistent volume claims. You also provide names for pieces of your Task Manager environment, and tuning decisions for your runtime environment.

If you want to deploy Task Manager, you must also deploy IBM Business Automation Navigator. The Task Manager uses the same database as IBM Business Automation Navigator. Database settings must match between these two components.

For Task Manager, pay particular attention to any relevant values in the `jvm_customize_options` parameter.

For more information about the settings, see [Task Manager parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_optmparams.html)

### Initialization settings

Use the `initialize_configuration` section of the custom YAML to provide values for the automatic initialization and setup of Content Platform Engine and IBM Business Automation Navigator. The initialization container creates initial instances of your FileNet Content Manager components, such as the p8 domain, one or more object stores, and configuration of IBM Business Automation Navigator. You also provide names for pieces of your FileNet Content Manager environment, and make decisions for your runtime environment.

You can edit the YAML to configure more than one of the available pieces in your automatically initialized environment. For example, if you want to create an additional Content Search Services server, you copy the stanza for the server settings, paste it below the original, and add the new values for your additional object store:

   ```
ic_css_creation:
    #   - css_site_name: "Initial Site"
    #     css_text_search_server_name: "{{ meta.name }}-css-1"
    #     affinity_group_name: "aff_group"
    #     css_text_search_server_status: 0
    #     css_text_search_server_mode: 0
    #     css_text_search_server_ssl_enable: "true"
    #     css_text_search_server_credential: "RNUNEWc="
    #     css_text_search_server_host: "{{ meta.name }}-css-svc-1"
    #     css_text_search_server_port: 8199

   ```

You can create additional object stores, Content Search Services indexes, IBM Business Automation Navigator repositories,  and IBM Business Automation Navigator desktops.

For more information about the settings, see [Initialization parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opinitiparams.html)

### Verification settings

Use the `verify_configuration` section of the custom YAML to provide values for the automatic verification of your Content Platform Engine and IBM Business Automation Navigator. The verify container works in conjunction with the automatic setup of the initialize container. You can accept most of the default settings for the verification. However, compare the settings with the values that you supply for the initialization settings. Specific settings like object store names and the Content Platform Engine connection point must match between these two configuration sections.

For more information about the settings, see [Verify parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opverifyparams.html)

## Complete the installation

After you have set all of the parameters for the relevant components, return to to the install or update page for your platform to configure other components and complete the deployment with the operator.

Install pages:
   - [Installing on Managed Red Hat OpenShift on IBM Cloud Public](../platform/roks/install.md)
   - [Installing on Red Hat OpenShift](../platform/ocp/install.md)
   - [Installing on Certified Kubernetes](../platform/k8s/install.md)

Update pages:
   - [Updating on Managed Red Hat OpenShift on IBM Cloud Public](../platform/roks/update.md)
   - [Updating on Red Hat OpenShift](../platform/ocp/update.md)
   - [Updating on Certified Kubernetes](../platform/k8s/update.md)
