# Install IBM Business Automation Insights on Red Hat OpenShift on IBM Cloud

Refer to [Red Hat OpenShift on IBM Cloud documentation](https://cloud.ibm.com/docs/openshift?topic=openshift-openshift-create-cluster#openshift_create_cluster_console) to create a Kubernetes cluster in IBM Cloud.

## Step 1: Install the Red Hat OpenShift Container Platform command line interface (CLI) and Helm

Refer to Red Hat OpenShift on IBM Cloud documentation to [create a kubernetes cluster in IBM Cloud](https://cloud.ibm.com/docs/openshift?topic=openshift-openshift-create-cluster#openshift_create_cluster_console) and to [install the Red Hat OpenShift Container Platform command line interface (CLI)](https://cloud.ibm.com/docs/openshift?topic=openshift-openshift-cli):
* IBM Cloud CLI (ibmcloud)
* Kubernetes Service plug-in (oc alias for OpenShift clusters)
* Container Registry plug-in (ibmcloud cr)
* Helm CLI (`helm`)

## Step 2: Install a Business Automation Insights release

> **Tip**: If you activate Business Automation Insights persistence, you need to specify persistent volumes (PV) to install. PV represents an underlying storage capacity in the infrastructure. Before you can install Business Automation Insights, you must create two PVs with access mode set to ReadWriteOnce and storage capacity of 10Gi or more for Elasticsearch storage, and one PV with access mode set to ReadWriteMany and storage capacity of 10Gi or more for Apache Flink storage. You create a PV in the administration console or in a YAML file (.yml or. yaml file name extension).

1. Prerequisites:

	* Install a [Kafka distribution](https://cwiki.apache.org/confluence/display/KAFKA/Ecosystem) and make sure it is accessible from the Managed OpenShift cluster.

2. Log in to your IBM Cloud Kubernetes cluster:

	* Log in to [IBM Cloud account](https://www.ibm.com/cloud) and select *Kubernetes* from the menu [hamburger menu icon].
	* Select the cluster and from the cluster details page, click **OpenShift web console**.
	* In the menu bar of the OpenShift web console, click your profile *IAM#user.name@email.com* > *Copy Login Command* and paste the copied `oc login` command into your terminal to authenticate:
	```console
	$ oc login https://<CLUSTERNAME>:<CLUSTERPORT> --token=<GENERATED_TOKEN>
	```
     
3. Create a project to contain your release by running the following commands:

	```console
	$ oc new-project <project_name> --description="<description>" --display-name="<display_name>"
	$ oc project <project_name>
	```
   
	An associated Kubernetes namespace is created with the project name. In subsequent command lines, replace the <NAMESPACE> placeholder with your actual project name.

4. Install the Business Automation Insights Helm charts:

	a. Download the charts from https://github.com/icp4a/cert-kubernetes/tree/19.0.1/BAI/helm-charts/ibm-business-automation-insights-3.1.1.tgz
	
	b. Download the "Business Automation Insights" images from PPA (refer to [19.0.1 download document](https://www-01.ibm.com/support/docview.wss?uid=ibm10878709))

	c. Upload the images to the registry by running this script: [loadimages.sh](https://github.com/icp4a/cert-kubernetes/blob/19.0.1/scripts/loadimages.sh)
	> **Note**: Change the permissions so that you can execute the script.
	>   ```console
	>   $ chmod +x loadimages.sh
	>   
	
	Use the [loadimages.sh](https://github.com/icp4a/cert-kubernetes/blob/19.0.1/scripts/loadimages.sh) script to push the docker images into the IBM Cloud Container Registry.
	```console
	$ ./loadimages.sh -p <PPA-ARCHIVE>.tgz -r us.icr.io/baiproject
	```

	> **Note**: `us.icr.io` is the registry domain name for the region *us-south*. Refer to the [documentation](https://cloud.ibm.com/docs/services/Registry?topic=registry-registry_overview#registry_regions_local) to find the domain names of the registry associated to the cluster location.

	> **Note**: The project must have pull request privileges to the registry where the Business Automation Insights images are loaded. The project must also have pull request privileges to push the images into another namespace/project.

	d. Check whether the images have been pushed correctly to the registry.
	
	```console
	ibmcloud cr images
	```
	
5. Grant "ibm-anyuid-scc" privileges to any authenticated users:

	```console
	$ oc adm policy add-scc-to-group ibm-anyuid-scc system:authenticated
	```
	
6. Grant "ibm-privileged-scc" privileges to any authenticated users:

	```console
	$ oc adm policy add-scc-to-user ibm-privileged-scc system:authenticated
	```
	
7. Before you install Business Automation Insights, apply the security policy:

	a. Create a file named, for example, 'bai-psp.yaml', based on this PSP template, and set the values of the <RELEASE_NAME> and <NAMESPACE> placeholders.
	* Replace `<RELASE_NAME>` with the name of the Business Automation Insights release.
	* Replace `<NAMESPACE>` with the name of the namespace that is associated with your OpenShift project.
       
	```console       
	apiVersion: extensions/v1beta1
	kind: PodSecurityPolicy
	metadata:
	  annotations:
	    kubernetes.io/description: "This policy is required to allow ibm-dba-ek pods running Elasticsearch to use privileged containers."
	  name: <RELEASE_NAME>-bai-psp
	spec:
	  privileged: true
	  runAsUser:
	    rule: RunAsAny
	  seLinux:
	    rule: RunAsAny
	  supplementalGroups:
	    rule: RunAsAny
	  fsGroup:
	    rule: RunAsAny
	  volumes:
	  - '*'
	---
	apiVersion: rbac.authorization.k8s.io/v1
	kind: Role
	metadata:
	  name: <RELEASE_NAME>-bai-role
	  namespace: <NAMESPACE>
	rules:
	- apiGroups:
	  - extensions
	  resourceNames:
	  - <RELEASE_NAME>-bai-psp
	  resources:
	  - podsecuritypolicies
	  verbs:
	  - use
	---
	apiVersion: v1
	kind: ServiceAccount
	metadata:
	  name: <RELEASE_NAME>-bai-psp-sa  
	---
	apiVersion: rbac.authorization.k8s.io/v1
	kind: RoleBinding
	metadata:
	  name: <RELEASE_NAME>-bai-rolebinding
	  namespace: <NAMESPACE>
	roleRef:
	  apiGroup: rbac.authorization.k8s.io
	  kind: Role
	  name: <RELEASE_NAME>-bai-role
	subjects:
	- kind: ServiceAccount
	  name: <RELEASE_NAME>-bai-psp-sa
	  namespace: <NAMESPACE>    		   
	```
		   
    b. Apply this policy by executing the following command:
    
	```console
	$ kubectl apply -f bai-psp.yaml -n <NAMESPACE>
	```
	
8. Grant "ibm-privileged-scc" privileges to the service account:

	```console
	oc adm policy add-scc-to-user ibm-privileged-scc -z <RELEASE_NAME>-bai-psp-sa -n <NAMESPACE>
	```
		
9. Create a values.yaml file.
	
	a. Activate persistence:
	
	The following example uses dynamic provisioning and the ibmc-file-retain-gold storage class.
		
	```console		
	persistence:
	  useDynamicProvisioning: true
	
	flinkPv:
	  storageClassName: "ibmc-file-retain-gold"
	  
	ibm-dba-ek:
	  elasticsearch:
	    data:
          storage:
            persistent: true
            useDynamicProvisioning: true
            storageClass: "ibmc-file-retain-gold"
	      snapshotStorage:
	        enabled: true
	        useDynamicProvisioning: true
	        storageClass: "ibmc-file-retain-gold"		
	```
			
	b. Configure the connection between your Kafka tool and Business Automation Insights:
	
	In the values.yaml file, configure the connection to Kafka.
	
	For example, for a Kafka without authentification:
	
	```console
	kafka:
	  bootstrapServers: "kafka-hostname:9092"
	  securityProtocol: "PLAINTEXT"
	  propertiesConfigMap: ""		
	```
		
	c. Enable event processing.
	
	For example, to install only ODM event processing, edit your values.yaml file as follows.

	```console
	bpmn:
	  install: false		
	
	icm:
	  install: false
	
	odm:
	  install: true
	
	content:
	  install: false
	
	bawadv:
	  install: false		
	```
		
10. Install the release.

	```console
	$ helm install --namespace <NAMESPACE> --name <RELEASE_NAME> charts/ibm-business-automation-insights -f ./values.yaml
	```

## Step 3: Verify that the Business Automation Insights deployment is running

1. Monitor the Business Automation Insights pods until they show the *Running* or *Completed* STATUS.

	```console
	$ while oc get pods  | grep -E "(Running|Completed|STATUS)"; do sleep 5; done
	```
   
2. You can now expose the Kibana service to your users by using Openshift routes.

	```console
	$ oc create route passthrough --service=<RELEASE_NAME>-ibm-dba-ek-kibana -n <NAMESPACE>
	```
	
   > **Note**: For more information, refer to the [Openshift documentation](https://docs.openshift.com/container-platform/3.11/dev_guide/routes.html).

	The Kibana URL is available in the 'Routes' section of the Openshift console.

## To uninstall the release

To uninstall and delete the release from the Helm CLI, use the following command.

```console
$ helm delete <RELEASE_NAME> --purge
```
