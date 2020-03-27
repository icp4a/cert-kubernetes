# IBM® Business Automation Content Analyzer


## Introduction

This readme provide instruction to deploy IBM Business Automation Content Analyzer with IBM® Cloud Pak for Automation platform. IBM Business Automation Content Analyzer offers the power of intelligent capture with the flexibility of an API that enables you to extend the value of your core enterprise content management (ECM) technology stack and helps you rapidly accelerate extraction and classification of data in your documents. 


Requirements
------------

### Step 1 - Create DB2 databases for Content Analyzer

Note: For development or testing purposes, you may skip this step and move onto "Step 2 - Initialize the Content Analyzer Base database" if you prefer for the Content Analyzer scripts to create the database for you.

1. Follow the instructions in the IBM DB2 Knowledge Center documentation to create DB2 databases for the following:
  - Content Analyzer Base database.  Make a note of the Base database name for later steps.  
  - Content Analyzer Tenant database.  Only one tenant is required by Content Analyzer, but multiple tenants are also supported.  If multiple tenants are desired, create one DB2 database per Content Analyzer Tenant.  Make a note of the Tenant database name(s) for later steps.

2. Here are the minimum requirements for the databases:
  - For performance reasons, IBM recommends that you create table spaces using automatic storage, rather than database managed or system managed table spaces.
  - Set the DB2 codeset to UTF-8.
  - Set the page size to 32 KB.

### Step 2 - Initialize the Content Analyzer Base database
1. Copy the DB2 [folder](https://github.com/icp4a/cert-kubernetes/tree/master/operator/ACA/configuration-ha/DB2) to your IBM DB2 server
2. From the DB2 folder, run the `InitBaseDB.sh` script on the DB2 server to initialize the Base database. (If your DB2 is on Windows, use `InitBaseDB.bat`.) (Please run as db2inst1 user or a user with privileges to run the DB2 command line and admin privileges for the Base database.)
(Note: For development or testing purposes, if you prefer for the Content Analyzer scripts to create the database for you, then run the `CreateBaseDB.sh` script instead of `InitBaseDB.sh`)
3. As prompted, enter the following data:
  - Enter the name of the Content Analyzer Base database created in Step 1.
  - Enter the name of database user with read and write privileges for the Content Analyzer Base database
4. When you configure the role variables in your CR, specify this database in the role variables: `datasource_configuration->dc_ca_datasource->database_servername`, `datasource_configuration->dc_ca_datasource->database_name`, and `datasource_configuration->dc_ca_datasource->database_port`

### Step 3 - Initialize the Content Analyzer Tenant database(s)
1. From the DB2 folder, run the `InitTenantDB.sh` script on the DB2 server to initialize the tenant database. (If your DB2 is on Windows, use `InitTenantDB.bat`.)  (Please run as db2inst1 user or a user with privileges to run the DB2 command line and admin privileges for the Tenant database.)
(Note: For development or testing purposes, if you prefer for the Content Analyzer scripts to create the DB2 database for you, then run the `AddTenant.sh` script instead of `InitTenantDB.sh`)
2. When prompted, enter the following parameters:
  - Enter the tenant ID (an alphanumeric URL-safe string that is used by the user to reference the tenant).
  - For tenant type, please enter `0` for Enterprise.
  - Enter the name of the Content Analyzer Tenant database created in Step 1.
  - For the data source name (DSN), please accept the default, which is the name of the Content Analyzer Tenant database created in Step 1.
  - For DB2 SSL communication, please hit enter to accept default of `No`.  DB2 SSL communication is not supported in current release of Content Analyzer.
  - Enter the name of the database user to access the Tenant database.
  - Enter the password for the database user.
  - Enter the tenant ontology name. Press Enter to accept 'default' or enter a name to reference the ontology by, if desired. The ontology name must be alphanumeric and URL-safe.
  - Enter the name of the Content Analyzer Base database created in Step 1.
  - Enter the name of the Content Analyzer Base database user.
  - The following prompts are for the initial login user that will be created for Content Analyzer:
  - Enter the company name (e.g. your company name.)
  - Enter the first name of the user (e.g. enter your first name)
  - Enter the last name (e.g. enter your last name)
  - Enter a valid email address (e.g. enter your email address)
  - Enter the login name (if you use LDAP authentication, enter your user name as it appears in the LDAP server)
  - Would you like to continue – y (for yes)
  - Save the tenantID and Ontology name for the later steps.
3. When you configure the role variables in your CR, specify the tenant database name(s) in the role variable `tenant_databases`.  <br/>For example: <br/> `tenant_databases:` <br/> ` - t01db` <br/> ` - t02db`


### Step 4 - Optional - DB2 High-Availability
1. Optionally, if DB2 HADR (High Availability Disaster Recovery) is desired, follow the instructions in the IBM DB2 Knowledge Center documentation for DB2 HADR setup. 
2. The DB2 HADR setup for the Content Analyzer databases must occur AFTER after initializing the schemas for Base database and Tenant database (i.e. Step 2 and Step 3 above).  
3. DB2 ACR (automatic client reroute) is required for Content Analyzer to work with DB2 HADR. (KC link to Db2 ACR: https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.admin.ha.doc/doc/c0011558.html)
4. If your are using DB2 databases that are HADR enabled for Content Analyzer, your must configure at least these 2 variables (see the "Role Variables" section below)
`datasource_configuration->dc_ca_datasource->dc_hadr_standby_servername` and `datasource_configuration->dc_ca_datasource->dc_hadr_standby_port`.


### Step 5 - Create prerequisite resources for IBM Business Automation Content Analyzer

1. Create at least 3 PVCs for Content Analyzer:<p>
   a) Log PVC: The recommended minimum size is 50GB.  Record the name of the PVC under `ca_configuration->global->logs->claimname` section of the CR   
   b) Config PVC: The recommended minimum size is 20GB. Record the name of the PVC under `ca_configuration->global->configs->claimname` section of the CR  
   c) Data PVC: The recommended minimum size is 60GB.  Record the name of the PVC under `ca_configuration->global->data->claimname` section of the CR.  Record the name of the PVC under`ca_configuration->global->mongo->claimname`, and `ca_configuration->global->mongoadmin->claimname` if you plan to share the PVC with Mongo and Mongos Admin DB. <p>
   
   OPTIONAL:
   - You can create four (4) additional PVCs for Mongo and MongoAdmin DB, then record the name of the PVC under`ca_configuration->global->mongo->configdb_claimname`, `ca_configuration->global->mongo->shard_claimname`, `ca_configuration->global->mongoadmin->admin_shard_claimname` and `ca_configuration->global->mongoadmin->admin_configdb_claimname` section of the CR.<p>The recommended sizes for the PVC are 60 GB.<p>
   Otherwise, you can share the data pvc (`ca_configuration->global->data->claimname`) for Mongo.  However, you must increase the size of the data pvc to 300GB in this case.
   
   Below is the sample of the PV/PVC using NFS
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: sp-data-pv-caop
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 60Gi
  nfs:
    path: /exports/smartpages/caop/data
    server: 192.168.1.100
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sp-data-pvc
  namespace: caop
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 60Gi
  volumeName: sp-data-pv-caop

```
    
   d) Grant permission to the PVC directories.  Assuming you have the following directory structures for your PVCs
   
```
├── caop
│   ├── config
│   ├── data
│   └── log 


chown -Rf 51000:0 caop/
chgrp -R 0 caop/
chmod -R g=u caop/
```
       

2. Label the worker nodes.
   - Content Analyzer will only deploy on nodes that have specific labeling.  The nodes should be labeled as `celery<ns>=aca`, `mongo<ns>=aca`, `mongo-admin<ns>=aca`
   (where `<ns>` is the name of the namespace that Content Analyzer will be deployed on).  
   For example: You would run the following command to label the nodes if the namespace is `sp`.   
   
   ```
   kubectl label nodes {node1.ibm.com,node2.ibm.com,node3.ibm.com} {celerysp=aca,mongosp=aca,mongo-adminsp=aca}
   ```
   
   `node1.ibm.com`, `node2.ibm.com`, and `node3.ibm.com` are the node names you want to label.
   
   - We recommend to dedicate 3 worker nodes for Mongo and MongoAdmin for high volume environment.  In this case, the worker nodes should be labeled as followed:
   
   ```
   kubectl label nodes {node1.ibm.com,node2.ibm.com,node3.ibm.com} {celerysp=aca}

   kubectl label nodes {node4.ibm.com,node5.ibm.com,node6.ibm.com} {mongosp=aca,mongo-adminsp=aca}
   ```


3.  Create the docker secret for registry and update this information in the Content Analyzer section of CRD yaml.

```
kubectl -n <{KUBE_NAME_SPACE}> create secret docker-registry <{DOCKER_REG_SECRET_NAME}> --docker-server=<{DOCKER_REG_FOR_SERVICES}> --docker-username=<{DOCKER_USER}> --docker-password=<{DOCKER_PWD_DECODED}> --docker-email='

```

where:

- `<{KUBE_NAME_SPACE}>`: The namespace.  For example: caop

- `<{DOCKER_REG_SECRET_NAME}>`: Name of secret.  For example: ca-docker-secret

- `<{DOCKER_REG_FOR_SERVICES}>`:  Docker registry server name.  For example: default-route-openshift-image-registry.apps.myserver.os.fyre.ibm.com

- `<{DOCKER_USER}>`: Docker registry user

- `<{DOCKER_PWD_DECODED}>`: Docker registry password.

4. Create the SCC, role, rolebinding and network policy for Content Analyzer by:

- Copy the security [folder](https://github.com/icp4a/cert-kubernetes/tree/master/operator/ACA/configuration-ha/security) locally.

- Run the following commands:

```
export KUBE_NAME_SPACE=<{KUBE_NAME_SPACE}>
sed -i.bak s#\$KUBE_NAME_SPACE#"$KUBE_NAME_SPACE"# ./aca-netpol.yaml
sed -i.bak s#\$KUBE_NAME_SPACE#"$KUBE_NAME_SPACE"# ./aca-rolebinding.yaml
kubectl apply -f aca-netpol.yaml
kubectl apply -f aca-scc.yaml --validate=false
kubectl apply -f aca-rolebinding.yaml
oc adm policy add-scc-to-group aca-scc system:serviceaccounts:{KUBE_NAME_SPACE}

```

where:

- `<{KUBE_NAME_SPACE}>`: The namespace's name.  For example: caop
  
5. Optionally, create a K8 secret for the LDAP credentials for Content Analyzer if User Management Services (UMS) integration is not enabled.

```
kubectl create secret generic aca-ldap \
--from-literal=LDAP_PASSWORD="$LDAP_PASSWORD" \
--from-literal=LDAP_DN="$LDAP_DN" 
```

where:

- `$LDAP_DN` is the fully qualified DN for the LDAP bind user
- `$LDAP_PASSWORD` is the LDAP bind user password.  


6. Create a K8 secret for the DB2 credentials for Content Analyzer

```
kubectl  create secret generic aca-basedb \
--from-literal=BASE_DB_USER="$BASE_DB_USER" \
--from-literal=BASE_DB_PWD="$BASE_DB_PWD"
```

where:

- `$BASE_DB_USER` is the user for the Content Analyzer's base database (created in Step 1)
- `$BASE_DB_PWD` is the user password for the Content Analyzer's Base database.

 

7. Optionally, if you want to enable SSL communication for LDAP, set the following variables in the CR yaml file. 

- Set `ldap_configuration -> lc_ldap_ssl_enabled ` to `true` 
- Set `lc_ldap_cert_name` to the name of the LDAP's private certificate.  
   - Please create a "CA" subfolder in the Operator's PVC folder if it does not exist and copy the LDAP public certificate to the "CA" subfolder under Operator's PVC. 
- Set `lc_ldap_self_signed_crt` to `"true"` or `"false"`.  `"true"` indicates it is a self-signed cert.


Role Variables
--------------
### Replace the following variables in the CR yaml file.

|  Parameter | Description  | Values   | 
|---         |---           |---       |
|ldap_configuration->lc_ldap_server| IP address or hostname of LDAP server. | For example: `192.168.1.100`|
|ldap_configuration->lc_ldap_port| LDAP port| For example: `389`|
|ldap_configuration->lc_ldap_base_dn| LDAP search base DN |For example: `dc=example,dc=com`|
|ldap_configuration->lc_ldap_ssl_enabled| Whether or not you want to enable SSL communication between Content Analyzer and LDAP. Additional steps are needed to enable LDAP SSL. Please instructions above.| `true` or `false` |
|ldap_configuration->lc_ldap_cert_name| If using SSL for LDAP, the name of the LDAP SSL certificate if LDAP SSL is enabled | For example: `ldap.crt` |
|ldap_configuration->ca_ldap_configuration->lc_ldap_self_signed_crt| If using SSL for LDAP, specify whether the certificate is self-sign or not| `"true"` or `"false"`|
|ldap_configuration->ca_ldap_configuration->lc_user_filter| LDAP User search filter. | For example on SDS: `"(&(cn={{username}})(objectclass=person))"`. Actual user name will be substituted for {{username}}<p>{{username}} substitution variable must be formatted as {{ '{{' }}username{{ '}}'}}<p> Default: (&(cn={{ '{{' }}username{{ '}}'}})(objectclass=person)) | 
|datasource_configuration->dc_ca_datasource->database_servername| Name of the DB2 server that hosts Content Analyzer's databases |
|datasource_configuration->dc_ca_datasource->database_name| Content Analyzer's Base DB name| For example: BASECA |
|datasource_configuration->dc_ca_datasource->database_port| DB2 port| For example: 50000 |
|datasource_configuration->dc_ca_datasource->tenant_databases| List of 1 or more tenant databases as configured above in `Step 3 - Initialize the Content Analyzer Tenant database(s)` | For example: <br/> `tenant_databases:` <br/> ` - t01db` <br/> ` - t02db`|
|datasource_configuration->dc_ca_datasource->dc_hadr_standby_servername| If using DB2 HADR, provide the DB2 standby server name or IP address|
|datasource_configuration->dc_ca_datasource->dc_hadr_standby_port| If using DB2 HADR, provide the DB2 standby server's port |
|datasource_configuration->dc_ca_datasource->dc_hadr_retry_interval_for_client_reroute| Optional. If using DB2 HADR, optionally provide the retry internal for client reroute in seconds. If not given, default is 2.|
|datasource_configuration->dc_ca_datasource->dc_hadr_max_retries_for_client_reroute| Optional. If using DB2 HADR, provide the maximum number of retries for client reroute. If not given, default is 30. |
|shared_configuration->trusted_certificate_list| Add `aca-backend-secret`, and `aca-frontend-secret` to the list if BAS is enabled| For example: trusted_certificate_list: [aca-backend-secret,aca-frontend-secret] |



### Replace the following variables in the CR yaml file under the "ca_configuration" section.

|  Parameter | Description  | Values   | 
|---         |---           |---       |
|service_type| The service type you want to use for communication (eg:NodePort or Route).  `Route` will be used if Content Analyzer is deployed on OCP.  See `Post Deployment` section below for more information on `Route` |`Route` or `NodePort`       |
|frontend_external_hostname| The unique, external facing hostname for Content Analyzer's frontend (eg: `www.ca.frontendsp`) when `service_type: "Route"`.  See `Post Deployment` section below for more information on `Route`| Leave blank if `service_type` is set to `NodePort`| 
|backend_external_hostname|The unique, external facing hostname for Content Analyzer's backend (eg: `www.ca.backensp`) when `service_type: "Route"`.  See `Post Deployment` section below for more information on `Route` | Leave blank if `service_type` is set to `NodePort`|
|ldap_secret| The ldap secret name created in Step 5 above. | Default `aca-ldap` if blank|
|db_secret| The database secret name created in Step 6 above. | Default: `aca-basedb` if blank| 
|repository| The repository for docker images| A valid, reachable repository name
|tag| Content Analyzer's build | `20.0.1` |
|pull_policy| Docker image pull policy | Recommend to leave default as `IfNotPresent` |
|pull_secrets| Docker registry secret name created in step 3 of the `Create prerequisite resources for IBM Business Automation Content Analyzer` section | |
|authentication_type| Select the authentication type. 0: Non-ldap, not support in Production, 1: LDAP, 2: IBM User Management Service integration| Default is 1|
|retries| The number retries to determine if the deployment of Content Analyzer is successful or not. There is a 20 seconds delay between every retry | Default is 90|
|bas->bas_enabled| Enable BA Studio. (true or false). Note, that you must choose Authentication_type = 2 in order to enable BA Studio | default is "false" | 
|celery->process_timeout| Timeout for Content Analyzer's ocr_extraction, classifyprocess, processing, updatefiledetail components| Default value is 300 seconds
|configs->claimname| The PVC name for storing configuration files created in the Step 1 of `Create prerequisite resources for IBM Business Automation Content Analyzer`|For example:`"sp-config-pvc"`|
|logs->claimname| The PVC name for storing log files created in the Step 1 of `Create prerequisite resources for IBM Business Automation Content Analyzer`|For example:`"sp-log-pvc"`|
|data->claimname| The PVC name for storing data files created in the Step 1 of `Create prerequisite resources for IBM Business Automation Content Analyzer` |For example:`"sp-data-pvc"`|
|mongo->configdb_claimname| The PVC name for storing Mongo's configuration database created in the Step 1 of `Create prerequisite resources for IBM Business Automation Content Analyzer`|For example: `sp-config`|
|mongo->shard_claimname|The PVC name for storing Mongo's shard database created in the Step 1 of `Create prerequisite resources for IBM Business Automation Content Analyzer`
|mongoadmin->admin_configdb_claimname|The PVC name for storing MongoAdmin's configuration database created in the Step 1 of `Create prerequisite resources for IBM Business Automation Content Analyzer`||
|mongoadmin->admin_shard_claimname|The PVC name for storing MongoAdmin's shard database created in the Step 1 of `Create prerequisite resources for IBM Business Automation Content Analyzer`||
|replica_count| The replica count for each of Content Analyzer's sub components.  | NOTE: The minimum `replica_count` for redis, rabbitmq, mongo, and mongoadmin is 2.|
|spfrontend->backend_host| Leave this value to blank if service type is `Route`.  Domain name or IP used in URL to access backend if service type is `NodePort`| |

NOTE: Content Analyzer is designed to be flexible such that you can increase the performance by increasing:
1) `ca_configuration -><Component Names> -> replicas`: You can increase CA's components replicas to increase throughput if your environment has enough resources.  The recommendation is 1 component per node.  Note that increasing the number of replicas may not increase the response time (eg: The time it takes to process a page from end-to-end) 
2) `ca_configuration ->limits->cpu`:  You can increase the CA's components CPU limit to improve the response time.


Deployment
-----------
1) Once all the required parameters have been filled out for Content Analyzer, the CR can be applied by 

```

oc -n <ns> apply -f <CR yaml>

```
where:
`ns`: The namespace name where you want to install Content Analyzer.
`CR yaml`: The CR yaml name. 

2) Operator container will deploy Content Analyzer.  For more information about Operator, please refer to 
https://github.com/icp4a/cert-kubernetes/tree/20.0.1/



Post Deployment
--------------

## Post Deployment steps for route (OpenShift) setup

You can also deploy IBM Business Automation Content Analyzer using an OpenShift route as the ingress point to expose the frontend and backend services via an externally-reachable, unique hostname such www.backend.example.com and www.frontend.example.com.  
A defined route and the endpoints identified by its service can be consumed by a router to provide named connectivity that allows external clients to reach your applications.   

1) Access backend endpoint to accept certificate using the URL: `https://<backend_external_hostname>`
`backend_external_hostname` is defined in the CR yaml file under `ca_configuration` section

    **Note**: If the content **WORKS** appears in the page, it means the backend route is working.

2) Access frontend endpoint to accept certificate using the URL: `https://<frontend_external_hostname>/?tid=<tenantid>&ont=<tenant ontology> `   

where:

`<frontend_external_hostname>`: As defined in `ca_configuration->global->frontend_external_hostname`
`<tenantid>`: The tenantID when creating the tenant DB
`<tenant ontology>`: The ontology name when adding the ontology.



## Post Deployment steps for NodePort (Non OpenShift) setup

1) Modify your LoadBalancer (eg: HAProxy) in the K8's cluster to route the request to the specific node port if you set `service_type` to `NodePort`
2) Modify the  /etc/haproxy.cfg for Content Analyzer's frontend and backend to forward to the master nodes like this:

```
frontend spfrontend-svc
       bind *:32195
       default_backend spfrontend-svc
       mode tcp
       option tcplog
backend spfrontend-svc
       balance source
       mode tcp
       server master0 10.16.7.130:32195 check
frontend spbackend-svc
       bind *:30044
       default_backend spbackend-svc
       mode tcp
       option tcplog
backend spbackend-svc
       balance source
       mode tcp
       server master0 10.16.7.130:30044 check
```


  - `32195`: is the NodePort of Content Analyzer's frontend service.  You can obtain the port number by  issuing  the following command `kubectl get svc |grep spfrontend`
  
  - `30044`: is the NodePort of Content Analyzer's backend service.  You can obtain the port number by  issuing  the following command `kubectl get svc |grep spbackend`
   
  - `master0 10.16.7.130`: is the master node name and IP address.
 
3) Verify all the pods are up and running by `kubectl get pods`

4) Access the Content Analyzer URL by:

https://<host-name>:<frontend_port>/?tid=<tenantid>&ont=<tenant ontology>

where:
`<host-name>`: As defined in `ca_configuration->spfrontend->backend_host`
`<frontend_port>`: See step 2 above.
`<tenantid>`: The tenantID when creating the tenant DB
`<tenant ontology>`: The ontology name when adding the ontology.




## Troubleshooting

This section describes how to get various logs for Content Analyzer.

### Installation:

- Retreieve the Ansible installation logs:

```
kubectl  logs deployment/ibm-cp4a-operator -c operator > Operator.log

kubectl logs deployment/ibm-cp4a-operator -c ansible > Ansible.log
``` 

### Post install:

- Content Analyzer logs are located in the log pvc.  Logs are separated into sub-folders based on the component names. 

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

