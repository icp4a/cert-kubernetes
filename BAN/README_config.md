# Configuring IBM Business Automation Navigator 3.0.7

IBM Business Automation Navigator configuration settings are recorded and stored in the shared YAML file for operator deployment. After you prepare your environment, you add the values for your configuration settings to the YAML so that the operator can deploy your containers to match your environment. 

## Requirements and prerequisites

Confirm that you have completed the following tasks to prepare to deploy your Business Automation Navigator images:

- Prepare your Business Automation Navigator environment. These procedures include setting up databases, LDAP, storage, and configuration files that are required for use and operation. You must complete all of the [preparation steps for Business Automation Navigator](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/op_topics/tsk_prepare_bank8s.html) before you are ready to deploy the container images. Collect the values for these environment components; you use them to configure your Business Automation Navigator container deployment.

- Prepare your container environment. See [Preparing to install automation containers on Kubernetes](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/welcome/com.ibm.dba.install/op_topics/tsk_prepare_env_k8s.html)

> **Note**: If you plan to use UMS integration with Business Automation Navigator, note that you might encounter registration failure errors during deployment. This can happen if the UMS deployment is not ready by the time the other containers come up. The situation resolves in the next operator loop, so the errors can be ignored.  

## Prepare your security environment

You must also create a secret for the security details of the LDAP directory and datasources that you configured in preparation for use with IBM Business Automation Navigator. Collect the users, password to add to the secret. Using your values, run the following command:

   ```
kubectl create secret generic ibm-ban-secret \
   --from-literal=navigatorDBUsername="user_name" 
   --from-literal=navigatorDBPassword="xxxxxxx" \
   --from-literal=ldapUsername="CN=CEAdmin,OU=Shared,OU=Engineering,OU=FileNet,DC=dockerdom,DC=ecm,DC=ibm,DC=com"
   --from-literal=ldapPassword="xxxxxxx" \
   --from-literal=externalLdapUsername="cn=exUser1,ou=test1OU,dc=fncmad,dc=com" --from-literal=externalLdapPassword="xxxxxxx=" \
   --from-literal=keystorePassword="xxxxxxx" \
   --from-literal=ltpaPassword="xxxxxxx" \
   --from-literal=appLoginUsername=“user_name”
   --from-literal=appLoginPassword=“xxxxxxx”

   ```
The secret you create is the value for the parameter `ban_secret_name`.  
  
### Root CA and trusted certificate list

   The custom YAML file also requires values for the `root_ca_secret` and `trusted_certificate_list` parameters. The TLS secret contains the root CA's key value pair. You have the following choices for the root CA:
   - You can generate a self-signed root CA
   - You can allow the operator (or ROOTCA ansible role) to generate the secret with a self-signed root CA (by not specifying one)
   - You can use a signed root CA. In this case, you create a secret that contains the root CA's key value pair in advance.

   The list of the trusted certificate secrets can be a TLS secret or an opaque secret. An opaque secret must contain a tls.crt file for the trusted certificate. The TLS secret has a tls.key file as the private key.
   
### Apply the Security Context Contstraints

Apply the required Security Context Constraints (SCC) by applying the [SCC YAML](../descriptors/scc-fncm.yaml) file.

   ```bash
   $ oc apply -f descriptors/scc-fncm.yaml
   ```

   > **Note**: `fsGroup` and `supplementalGroups` are `RunAsAny` and  `runAsUser` is `MustRunAsRange`.


## Customize the YAML file for your deployment

All of the configuration values for the components that you want to deploy are included in the [ibm_cp4a_cr_template.yaml](../descriptors/ibm_cp4a_cr_template.yaml) file. Create a copy of this file on the system that you prepared for your container environment, for example `my_ibm_cp4a_cr_template.yaml`. 

The custom YAML file includes the following sections that apply for all of the components:
- shared_configuration - Specify your deployment and your overall security information.
- ldap_configuration - Specify the directory service provider information for all components in this common section.
- datasource configuration - Specify the database information for all components in this common section.
- monitoring_configuration - Optional for deployments where you want to enable monitoring.
- logging_configuration - Optional for deployments where you want to enable logging.

After the shared section, the YAML includes a section of parameters for each of the available components. If you plan to include a component in your deployment, you un-comment the parameters for that component and update the values. For some parameters, the default values are sufficient. For other parameters, you must supply values that correspond to your specific environment or deployment needs. 

The optional initialize_configuration and verify_configuration section includes values for a set of automatic set up steps for your IBM Business Automation Navigator deployment. 

If you want to exclude any components from your deployment, leave the section for that component and all related parameters commented out in the YAML file. 

A description of the configuration parameters is available in [Configuration reference for operators](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_ban_opparams.html)

Use the information in the following sections to record the configuration settings for the components that you want to deploy.

- [Shared configuration settings](README_config.md#shared-configuration-settings)
- [Business Automation Navigator settings](README_config.md#business-automation-navigator-settings)
- [Initialization settings](README_config.md#initialization-settings)
- [Verification settings](README_config.md#verification-settings)

### Shared configuration settings

Un-comment and update the values for the shared configuration, LDAP, datasource, monitoring, and logging parameters, as applicable.

Use the secrets that you created in Preparing your security environment for the `root_ca_secret` and `trusted_certificate_list` values.

> **Reminder**: If you plan to use External Share with the 2 LDAP model for configuring external users, update the LDAP values in the `ext_ldap_configuration` section of the YAML file with the information about the directory server that you configured for external users. If you are not using external share, leave this section commented out.

For more information about the shared parameters, see the following topics:

- [Shared parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opsharedparams.html)
- [LDAP parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_k8s_ldap.html)
- [Datasource parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_dbparams.html)
- [Monitoring parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opmonparams.html)


### Business Automation Navigator settings

Use the `navigator_configuration` section of the custom YAML to provide values for the configuration of Business Automation Navigator. You provide details for configuration settings that you have already created, like the names of your persistent volume claims. You also provide names for pieces of your Business Automation Navigator environment, and tuning decisions for your runtime environment.

In the Business Automation Navigator section, leave the `enable_appcues` setting with the default value, false.

For more information about the settings, see [Business Automation Navigator parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_ban_opparams.html)

### Initialization settings

Use the `initialize_configuration` section of the custom YAML to provide values for the automatic initialization and setup of Content Platform Engine and Business Automation Navigator. The initialization container creates required configuration of IBM Business Automation Navigator. You also make decisions for your runtime environment.

> **Important**: Do not enable initialization for your operator deployment if you plan to integrate UMS with Content Platform Engine or Business Automation Navigator. In this use case, you must manually create your Content Platform Engine domain, object stores, repositories, and desktops after deployment. If you are integrating UMS with Content Platform Engine and Business Automation Navigator, leave the `initialize_configuration` section commented out.

You can edit the YAML to configure more than one of the available pieces in your automatically initialized environment. For example, if you want to create an additional Business Automation Navigator repository, you copy the stanza for the repository settings, paste it below the original, and add the new values for your additional repository:

   ```
#   icn_repos:
    #   - add_repo_id: "demo_repo1"
    #     add_repo_ce_wsi_url: "http://{{ meta.name }}-cpe-svc:9080/wsi/FNCEWS40MTOM/"
    #     add_repo_os_sym_name: "OS01"
    #     add_repo_os_dis_name: "OS01"
    #     add_repo_workflow_enable: false
    #     add_repo_work_conn_pnt: "pe_conn_os1:1"
    #     add_repo_protocol: "FileNetP8WSI"

   ```

You can create additional object stores, Content Search Services indexes, IBM Content Navigator repositories,  and IBM Content Navigator desktops.

For more information about the settings, see [Initialization parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.ref/k8s_topics/ref_cm_opinitiparams.html)

### Verification settings

Use the `verify_configuration` section of the custom YAML to provide values for the automatic verification of your Content Platform Engine and IBM Content Navigator. The verify container works in conjunction with the automatic setup of the initialize container. You can accept most of the default settings for the verification. However, compare the settings with the values that you supply for the initialization settings. Specific settings like object store names and the Content Platform Engine connection point must match between these two configuration sections.

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
