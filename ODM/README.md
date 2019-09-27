# Install IBM Operational Decision Manager 8.10.2 on Certified Kubernetes

The following architectures are supported for Operational Decision Manager 8.10.2 on Certified Kubernetes:
- AMD64 (or x86_64), which is the 64-bit edition for Linux x86.

> **Note**: Rule Designer is installed as an update site from the [Eclipse Marketplace](https://marketplace.eclipse.org/content/ibm-operational-decision-manager-developers-v-8102-rule-designer) into an existing version of Eclipse.

## Option 1: Install a release for evaluation purposes

The following instructions are to install the Operational Decision Manager for developers Helm chart:

   * [Installing Operational Decision Manager for developers on MiniKube](platform/README_Eval_Minikube.md)
   * [Installing Operational Decision Manager for developers on Openshift](platform/README_Eval_Openshift.md)
   * [Installing Operational Decision Manager for developers on Red Hat OpenShift on IBM Cloud](platform/README_Eval_ROKS.md)

## Option 2: Install a production ready release

The installation of Operational Decision Manager 8.10.2 uses a `ibm-odm-prod` Helm chart, also known as the ODM for production Helm chart. The chart is a package of preconfigured Kubernetes resources that bootstraps an ODM for production deployment on a Kubernetes cluster. You customize the deployment by changing and adding configuration parameters. The default values are appropriate to a production environment, but it is likely that you want to configure at least the security of your kubernetes deployment.

The `ibm-odm-prod` Helm chart includes five containers corresponding to the following services.
- Decision Center Business Console and Enterprise Console
- Decision Server Console
- Decision Server Runtime
- Decision Server Runner
- (Optional) Internal PostgreSQL DB

The services require CPU and memory resources. The following table lists the minimum requirements that are used as default values.

| Service  | CPU Minimum (m) | Memory Minimum (Mi) |
| ---------- | ----------- | ------------------- |
| Decision Center | 500           | 512                  |
| Decision Runner     | 500           | 512                  |
| Decision Server Console  | 500           | 512                  |
| Decision Server Runtime    | 500           | 512                   |
| **Total**  | **2000** (2CPU)     | **2048** (2Gb)             |
| (Optional) Internal DB    | 500           | 512                   |

### *Optional:* Before you install a production ready release with customizations

If you want to customize your Operational Decision Manager installation, go to the [IBM Cloud Pak for Automation 19.0.x](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_install_odm.html) Knowledge Center and choose which customizations you want to apply.
   * [Configuring PVUs](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_config_pvu.html)
   * [Defining the security certificate](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_replace_security_certificate.html)
   * [Configuring the LDAP and user registry](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/con_config_user_registry.html)
   * [Configuring a custom external database](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_custom_external_db.html)
   * [Configuring the ODM event emitter](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_custom_emitters.html)
   * [Configuring Decision Center customization](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_custom_dc.html)

> **Note**: The [configuration](configuration) folder provides sample configuration files that you might find useful. Download the files and edit them for your own customizations.

After you noted the values of the configuration parameters that are needed to customize Operational Decision Manager, choose one of the following deployment options to complete the installation.

The following instructions are to install the ODM for production Helm chart:

  * [Install Operational Decision Manager on MiniKube](platform/README_Minikube.md)
  * [Install Operational Decision Manager on Openshift](platform/README_Openshift.md)
  * [Install Operational Decision Manager on IBM Cloud OpenShift cluster](platform/README_ROKS.md)
  * [Install Operational Decision Manager on other Kubernetes by using Helm and Tiller](helm-charts/README.md)
  * [Install Operational Decision Manager on other Kubernetes by using Kubernetes YAML](k8s-yaml/README.md)



## Post-installation steps

### Step 1: Verify a deployment

You can check the status of the pods by using the following command:
```console
$ kubectl get pods
```

When all of the pods are *Running* and *Ready*, retrieve the <b>cluster-info-ip</b> name and <b>port</b> numbers with the following commands:

<pre>
$ kubectl cluster-info
Kubernetes master is running at https://<b>cluster-info-ip</b>:8443
CoreDNS is running at https://<b>cluster-info-ip</b>:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

$ kubectl get services
NAME                                                  TYPE        CLUSTER-IP  EXTERNAL-IP   PORT(S)                    AGE
kubernetes                                            ClusterIP   ****        none          443/TCP                    9m
my-odm-prod-release-dbserver                          ClusterIP   ****        none          5432/TCP                   3m
my-odm-prod-release-odm-decisioncenter                NodePort    ****        none          9453:<b>dcs-port</b>/TCP   3m
my-odm-prod-release-odm-decisionrunner                NodePort    ****        none          9443:<b>dr-port</b>/TCP    3m
my-odm-prod-release-odm-decisionserverconsole         NodePort    ****        none          9443:<b>dsc-port</b>/TCP   3m
my-odm-prod-release-odm-decisionserverruntime         NodePort    ****        none          9443:<b>dsr-port</b>/TCP   3m
</pre>

With the <b>cluster-info-ip</b> name and <b>port</b> numbers, you have access to the applications with the following URLs:

|Component|URL|Username|Password|
|:-----:|:-----:|:-----:|:-----:|
| Decision Server Console | https://*cluster-info-ip*:*dsc-port*/res |resAdmin/odmAdmin|resAdmin/odmAdmin|
| Decision Server Runtime |https://*cluster-info-ip*:*dsr-port*/DecisionService |N/A|N/A|
| Decision Center Business Console |  https://*cluster-info-ip*:*dcs-port*/decisioncenter |rtsAdmin/odmAdmin|rtsAdmin/odmAdmin|
| Decision Center Enterprise Console |  https://*cluster-info-ip*:*dcs-port*/teamserver |rtsAdmin/odmAdmin|rtsAdmin/odmAdmin|
| Decision Runner |  https://*cluster-info-ip*:*dr-port*/DecisionRunner |resDeployer/odmAdmin|resDeployer/odmAdmin|

To further debug and diagnose deployment problems in the Kubernetes cluster, use the `kubectl cluster-info dump` command.

For more information about how to check the state and recent events of your pods, see
[Troubleshooting](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_troubleshooting.html).

### Step 2: Synchronize users and groups

If you customized the default user registry, you must synchronize the registry with the Decision Center database. For more information, see
[Synchronizing users and groups in Decision Center](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_synchronize_users.html).

### Step 3: Manage your Operational Decision Manager deployment

It is possible to update a deployment after it is installed. Use the following tasks in IBM Knowledge Center to update a deployment whenever you need, and as many times as you need.
   * [Scaling deployments](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.managing/k8s_topics/tsk_odm_scaling.html?view=kc)
   * [Customizing log levels](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.managing/k8s_topics/tsk_odm_custom_logging.html?view=kc)

## Upgrade a release

Refer to the [Upgrade section](helm-charts/README.md#upgrade-a-release) in the helm-charts folder for instructions using Tiller, or the [Upgrade section](k8s-yaml/README.md#upgrade-a-release) in the k8s-yaml folder for instructions on how to use Kubernetes YAML.
