# IBM® Business Automation Content Analyzer


## Introduction

This readme provide instruction to deploy IBM Business Automation Content Analyzer with IBM® Cloud Pak for Automation platform. IBM Business Automation Content Analyzer offers the power of intelligent capture with the flexibility of an API that enables you to extend the value of your core enterprise content management (ECM) technology stack and helps you rapidly accelerate extraction and classification of data in your documents.  


Requirements to Prepare Your Environment
------------

### NOTE:
Verify the latest release of IBM Business Automation Content Analyzer with IBM® Cloud Pak for Automation platform in IBM Fix Central or Entitlement Registry and use that release for deployment. 
For example:  There is a new version of IBM Business Automation Content Analyzer with IBM® Cloud Pak for Automation platform, 20.0.1-ifix1, for the 20.0.1 release. For deployment, edit the CR yaml file. In the `ca_configuration` section, use `20.0.1-ifix1` as the value for the `tag` parameter.

### Step 1 - Preparing users for Content Analyzer

Content Analyzer users need to be configured on the LDAP server. See [Preparing users for Content Analyzer](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_prepare_bacak8s_usergroups.html) for detailed instructions.

### Step 2 - Create DB2 databases for Content Analyzer

For development or testing purposes, you can skip this step and move to "Step 3 - Initialize the Content Analyzer Base database" if you prefer for the Content Analyzer scripts to create the database for you.

See [Create the Db2 database](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_prepare_bacak8s_createdb2.html) for detailed instructions.

### Step 3 - Initialize the Content Analyzer Base database

If you do not have a Db2® database set up, do so now. 

See [Initializing the Content Analyzer Base database](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_prepare_bacak8s_db.html) for detailed instructions.

### Step 4 - Initialize the Content Analyzer Tenant database(s)

If you do not have a tenant database, set up a Db2 tenant database. 

See [Initializing the Tenant database](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_prepare_bacak8s_dbtenant.html) for detailed instructions.

### Step 5 - Optional - DB2 High-Availability

You can set up a Db2 High Availability Disaster Recovery (HADR) database.

See [Setting up Db2 High-Availability](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_prepare_cadb2ha.html) for detailed instructions.

### Step 6 - Create prerequisite resources for IBM Business Automation Content Analyzer

Set up and configure storage to prepare for the container configuration and deployment. You set up permissions to PVC directories, label worker nodes, create the docker secret, create security, and enable SSL communication for LDAP if necessary.

See [Configuring storage and the environment](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_prepare_bacak8s_storage.html) for detailed instructions.

### Step 7 - Configuring the CR YAML file

Update the custom YAML file to provide the details that are relevant to your IBM Business Automation Content Analyzer and your decisions for the deployment of the container.

NOTE: Review this [technote](https://www.ibm.com/support/pages/node/6178437) if you deploy Content Analyzer on ROKS.


See [Content Analyzer parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_k8sca_operparams.html) for detailed instructions.

### Step 8 - Deployment
-----------
1) Once all the required parameters have been filled out for Content Analyzer, the CR can be applied by 

```

oc -n <ns> apply -f <CR yaml>

```
where:
`ns` is the namespace name where you want to install Content Analyzer.
`CR yaml` is the CR yaml name. 

2) The Operator container will deploy Content Analyzer. For more information about Operator, refer to 
https://github.com/icp4a/cert-kubernetes/tree/20.0.1/


Post Deployment
--------------

## Post Deployment steps for route (OpenShift) setup

You can deploy IBM Business Automation Content Analyzer by using an OpenShift route as the ingress point to provide fronted and backend services through an externally reachable, unique hostname such as www.backend.example.com and www.frontend.example.com. A defined route and the endpoints, which are identified by its service, can be consumed by a router to provide named connectivity that allows external clients to reach your applications.   

See [Configuring an OpenShift route](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_postcadeploy_routeOS.html) for detailed instructions.

## Post Deployment steps for NodePort (Non OpenShift) setup

You can modify your LoadBalancer, like the HAProxy, in the Kubernetes cluster to route the request to a specific node port.

See [Configuring routing to a node port](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_postcadeploy_nodeport_NOS.html) for detailed instructions.

## Troubleshooting

This section describes how to get various logs for Content Analyzer.

### Installation:

- Retreieve the Ansible installation logs:

```
kubectl  logs deployment/ibm-cp4a-operator -c operator > Operator.log

kubectl logs deployment/ibm-cp4a-operator -c ansible > Ansible.log
``` 

### Post install:

- Content Analyzer logs are located in the log pvc. Logs are separated into sub-folders based on the component names. 

```
├── backend
├── callerapi
├── classifyprocess-classify
├── frontend
├── mongo
├── mongoadmin
├── ocr-extraction
├── pdfprocess
├── postprocessing
├── processing-extraction
├── setup
├── updatefiledetail
└── utf8process

```

