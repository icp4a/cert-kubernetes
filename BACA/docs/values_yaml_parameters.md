## Populating values.yaml with correct values

1.      Copy template.yaml to values.yaml  
2.      Edit values.yaml and fill in values for the following items.   

Note that anything not documented here typically does not need to be changed.

##### GLOBAL OPTIONS:
The following variables are used in multiple places. Perform a global search and replace with the correct information (for example, in vi - `:%s/$REGISTRY_NAME/docker-registry.default.svc:5000\/sp/g`):  

|Tag|Description|
|----|----|
$REGISTRY_NAME  |refers to the name of the local registry where IBM Business Automation Content Analyzer images have been loaded, in the format `<registry>/<namespace>` (for example, docker-registry.default.svc:5000/sp or mycluster.icp:8500/baca).  There are 18 occurrences of this tag in the values.yaml that need to be updated.  
$VERSION_TAG |refers to the version tag of the docker images loaded into the registry (for example, 1.0.1-gm).  There are also 18 occurrences of this value in values.yaml that need to be updated.  
$CELERY_REPLICAS |determines the number of celery pods to start. Recommended value is 1 per worker node. 11 occurrences of this value  
$NON_CELERY_REPLICAS |determines the number of pods for non-celery. Recommended value is 1 per worker node. 2 occurrences of this value. 
$KUBE_NAME_SPACE |the kubernetes namespace or Openshift project where Content Analyzer will be deployed. 5 occurrences of this value.  

##### RESOURCE LIMIT OPTIONS:
You can define resource limits for each of the pods based on available memory on the worker/compute nodes to ensure better operating efficiency.
Use the sample configuration script, [generateMemoryValues.sh](../configuration/generateMemoryValues.sh), to determine the appropriate values for each of the following based on your environment:  
The following values need to be set:  

$CALLERAPI_LIMITED_MEMORY  
$SETUP_LIMITED_MEMORY  
$OCR_EXTRACTION_LIMITED_MEMORY  
$CLASSIFY_LIMITED_MEMORY  
$PROCESSING_EXTRACTION_LIMITED_MEMORY  
$POST_PROCESS_LIMITED_MEMORY  
$INTER_PROCESSING_LIMITED_MEMORY  
$PDF_PROCESS_LIMITED_MEMORY  
$UTF8_PROCESS_LIMITED_MEMORY  
$REANALYZE_LIMITED_MEMORY  
$UPDATEFILE_LIMITED_MEMORY  
$FRONTEND_LIMITED_MEMORY  
$BACKEND_LIMITED_MEMORY  
$MINIO_LIMITED_MEMORY  
$REDIS_LIMITED_MEMORY  
$RABBITMQ_LIMITED_MEMORY  
$MONGO_LIMITED_MEMORY  
$MONGO_ADMIN_LIMITED_MEMORY   
$MONGO_WIREDTIGER_LIMIT #note this value should just be entered as a number only in GB (for example, .3 and not .3Gi or 300Mi)  
 

##### LDAP INTEGRATION OPTIONS:
If integrating with an LDAP repository for logon, set the following:  
>Note that if not using LDAP, then the ldap: setting under spbackend and spfrontend needs to be set to FALSE and the rest of the values left blank)  

###### spfrontend:  
- ldap: TRUE OR FALSE depending on whether you are using LDAP   

###### spbackend:  
- ldap: TRUE OR FALSE depending on whether you are using LDAP  
- ldapFilter: search filter to find user.  Use ‘{{username}}’ as substitution variable for example, (&(cn={{username}})(objectClass=person))  
- ldapDn: dn of bind user (for example, cn=root)  
- ldapURL: URL of ldap server (for example, ldap://xx.xx.xx.xx  
- ldapPort: ldap port (for example, 389)  
- ldapBase: ldap search base   
- userName: username of initial user 
- ldapCrtName: if using LDAPS, specify certificate from LDAP server  
- ldapSelfSignedCert: Y if using a self-signed certificate. N otherwise  

##### DB2 Parameters:  
Set the following parameters on spbackend to tell IBM Business Automation Content Analyzer how to connect to the Base DB on Db2:  
###### DB2 Base DB connection info  
- baseDB: name of the base database created on Db2 (for example, CABASEDB)  
- baseDBServer: host name of the Db2 server  
- baseDBPort: listener port for the Db2 server  
- baseDBUser: user to log into Db2 and access Base DB  
    >Note the password for above user is stored in secret baca-basedb created by init_deployment.sh script or manually.

##### DEPLOYMENT SPECIFIC OPTIONS:

Some deployments require additional settings as described below:

###### spbackend:  
- backendPath: #leave blank for most deployments  
- backendPort: 8080 #leave at default for most deployments  
- nodeTLSRejectUnauthorized: 0 or 1 depending on whether self signed certificate if used for SSL. Generally left at 0  

>Note: Several parameters in spfrontend depend upon whether you wish to use path based ingress (for ICP only) or simply access the app via exposed node ports. If not using ingress in ICP, or using Openshift, be sure there are no values for backendPath & frontendPath, and values for backendPort will need to added post deployment see [Post Deployment Steps](post-deployment.md)
###### spfrontend:  
- backendHost: domain used in URL to access backend. Usually the same as BXDOMAINNAME which is usually the name/address of the proxy or infra node.  If using ingress with non-default port (80/443), then include port in hostname (for example, my.domain.com:444)   
- backendPort: for non-ingress solution, enter the node port of the spbackend service, otherwise leave blank  
- backendPath: if using path based ingress, specify the path (for example, in http://my.domain.com/backendsp/ path would be 'backendsp'). Note that port and path are mutually exclusive. Only one should be specified.  
- frontendHost: domain used in URL to access frontend. Similar to backend_host  
- frontendPath: if using path based ingress, specify the path for frontend  
- nodeTLSRejectUnauthorized: :0 or 1 depending on whether self signed certificate if used for SSL  
- sso:  0 or 1 depending on whether you need to authenticate through another portal (for example, in IBM cloud)  
- bxDomainName: domain name used to access frontend/backend  
 
###### ingress:  
- enabled: TRUE OR FALSE to indicate that path based ingress should be used on ICP (OCP's router does not support url rewriting and consequently will not work with path based ingress)  
-  $HOST_NAME – if ingress enabled, specify the host name used to access  
  
###### nodeSelector:  
label applied to nodes targeted to run celery workers. Default value created by init_deployment.sh is `celery<namespace>: baca`  

for example,  
nodeSelector:    
&nbsp;&nbsp;celerysp: baca                    

###### global:
  configs:  
    - claimname: enter name of PVC for config files created earlier. Default sp-config-pvc  
  logs:  
    - claimname: enter name of PVC for log files created earlier. Default sp-logs-pvc    
    - logLevel: blank or debug to enable additional logging  
  data:  
    - claimname: enter name of PVC for data files created earlier. Default sp-data-pvc  
  celery:  
    - processTimeout: 300 #timeout for OCR processing  
  namespace:  
    - name: #kubernetes namespace where IBM Business Automation Content Analyzer is to be deployed  
  - sslValidate: false #true or false depending on whether you are using a self signed SSL certificate or not (false=self signed)  
  mongo:  
    nodeSelector:  
     - mongosp: baca 'label applied to nodes targeted to run mongo pod. Default value is "mongo<namespace>: baca"  
  mongoadmin:  
    nodeSelector:  
     - mongo-adminsp: baca 'label applied to nodes targeted to run mongo-admin pod. Default value is "mongo-admin<namespace>: baca"  
