# Configuring IBM Operational Decision Manager 8.10.3

These instructions cover the basic configuration of ODM.

The following architectures are supported for Operational Decision Manager 8.10.3:
- AMD64 (or x86_64), which is the 64-bit edition for Linux x86.

> **Note**: Rule Designer is installed as an update site from the [Eclipse Marketplace](https://marketplace.eclipse.org/content/ibm-operational-decision-manager-developers-v-8103-rule-designer) into an existing version of Eclipse.

ODM for production includes five containers corresponding to the following services.
   - Decision Center Business Console and Enterprise Console
   - Decision Server Console
   - Decision Server Runtime
   - Decision Server Runner
   - (Optional) Internal PostgreSQL DB

The services require CPU and memory resources. The following table lists the minimum requirements that are used as default values.

| Service  | CPU Minimum (m) | Memory Minimum (Mi) |
| ---------- | ----------- | ------------------- |
| Decision Center | 500           | 1500                  |
| Decision Runner     | 500           | 512                  |
| Decision Server Console  | 500           | 512                  |
| Decision Server Runtime    | 500           | 512                   |
| **Total**  | **2000** (2CPU)     | **3036** (3Gb)             |
| (Optional) Internal DB    | 500           | 512                   |

### Step 1: Customize a production ready ODM (*Optional*)

The installation of Operational Decision Manager 8.10.3 can be customized by changing and adding configuration parameters. The default values are appropriate to a production environment, but it is likely that you want to configure at least the security of your kubernetes deployment.

Make a note of the name and value for the different parameters you want to configure so that it is at hand when you enter it in the custom resource YAML file.

Go to the [IBM Cloud Pak for Automation 20.0.x](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/k8s_topics/tsk_install_odm.html) Knowledge Center and choose which customizations you want to apply.
   * [Defining the security certificate](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/tsk_replace_security_certificate.html)
   * [Configuring the LDAP and user registry](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/con_config_user_registry.html)
   * [Configuring a custom external database](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/tsk_custom_external_db.html)
   * [Configuring the ODM event emitter](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/tsk_custom_emitters.html)
   * [Configuring Decision Center customization](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/tsk_custom_dc.html)
   * [Configuring Decision Center time zone](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.managing/op_topics/tsk_set_jvmargs.html)
   * [Configuring the execution unit (XU)](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/tsk_configuring_xu.html)

> **Note**: The [configuration](configuration) folder provides sample configuration files that you might find useful. Download the files and edit them for your own customizations.

### Step 2: Configure the custom resource YAML file for your ODM instance

Before you configure, make sure that you have prepared your environment. For more information, see [Preparing to install ODM for production](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_preparing_odmk8s.html).

In your `descriptors/my_icp4a_cr.yaml` file, update the `odm_configuration` section with the configuration parameters from *Step 1*. You can refer to the [`default-values.yaml`](configuration/default-values.yaml) file to find the default values for each ODM parameter and customize these values in your file.

### Step 3: Complete the installation

When you have finished editing the configuration file, go back to the relevant install or update page to configure other components and complete the deployment with the operator.

Install pages:
   - [Managed OpenShift installation page](../platform/roks/install.md#step-6-configure-the-software-that-you-want-to-install)
   - [OpenShift installation page](../platform/ocp/install.md#step-6-configure-the-software-that-you-want-to-install)
   - [Certified Kubernetes installation page](../platform/k8s/install.md#step-6-configure-the-software-that-you-want-to-install)

Update pages:
   - [Managed OpenShift installation page](../platform/roks/update.md)
   - [OpenShift installation page](../platform/ocp/update.md#step-1-modify-the-software-that-is-installed)
   - [Certified Kubernetes installation page](../platform/k8s/update.md)

### Step 4: Manage your Operational Decision Manager deployment

If you customized the default user registry, you must synchronize the registry with the Decision Center database. For more information, see
[Synchronizing users and groups in Decision Center](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.offerings/topics/tsk_synchronize_users.html).

You might need to update an ODM deployment after it is installed. Use the following tasks in IBM Knowledge Center to update a deployment whenever you need, and as many times as you need.
   * [Customizing JVM arguments](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.managing/op_topics/tsk_set_jvmargs.html)
   * [Customizing log levels](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.managing/op_topics/tsk_odm_custom_logging.html)
