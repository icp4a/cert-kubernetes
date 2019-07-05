## Populating ca-deploy.yml with correct values

Modify ca-deploy.yml and replace "$Variable" with the actual value. Anything not documented here typically does not need to be changed.

#### Summary of the variable

 Variable Name  | Description  | Occurrence
 ---- | ----- | -----
 $KUBE_NAME_SPACE  | The K8's namespace or OpenShift project that Content Analyzer will be deployed on.  | 179
 $DATAPVC  | Name of PVC for data files created earlier. Default sp-data-pvc.  | 2
 $LOGPVC  | Name of PVC for log files created earlier. Default sp-logs-pvc.  | 15
 $CONFIGPVC  | Name of PVC for config files created earlier. Default sp-config-pvc.  | 1
 $DOCKER_REG_FOR_SERVICES  | Name of the local registry where Content Analyzer images have been loaded, in the format / (for example, docker-registry.default.svc:5000/sp or mycluster.icp:8500/baca).  | 18 
 $VERSION  | Version tag of the docker images loaded into the registry (for example, 1.0.1-gm)  | 18
 $DOCKER_REG_SECRET_NAME  | Docker secret name if you want to use images from a different namespace in your private image registry, otherwise leave blank. | 17
 $LOG_LEVEL  | Blank or debug to enable additional logging. | 15
 $CELERY_REPLICAS  | Determines the number of celery pods to start. Recommended value is 1 per worker node. | 11
 $NON_CELERY_REPLICAS  | Determines the number of pods for non-celery. Recommended value is 1 per worker node. | 2
 $BASE_DB  | Name of the base database created on Db2 (for example, BASECA). | 1
 $BASEDB_SERVER  | Host name of the Db2 server. | 1
 $BASEDB_PORT  | Listener port for the Db2 server. | 1
 $BASEDB_USER  | User to log into Db2 and access Base DB. | 1
 $NODE_TLS_REJECT_UNAUTHORIZED  | 0 or 1 depending on whether self signed certificate if used for SSL. Generally left at 0. | 2
 $USE_LDAP  | true or false depending on whether you are using LDAP. | 2
 $LDAP_FILTER  | Search filter to find user. Use ‘{{username}}’ as substitution variable for example. (&(cn={{username}})(objectClass=person)). If not using LDAP leave blank. | 2
 $LDAP_DN  | DN of bind user (for example, cn=root). If not using LDAP leave blank. | 1
 $LDAP_PORT  | LDAP port (for example, 389). If not using LDAP leave blank. | 1
 $LDAP_URL  | URL of LDAP server (for example, ldap://xx.xx.xx.xx). If not using LDAP leave blank. | 1
 $LDAP_BASE  | LDAP search base. If not using LDAP leave blank. | 1
 $LDAP_CRT_NAME  | If using LDAPS, specify certificate from LDAP server. If not using LDAP leave blank. | 1
 $LDAP_SELF_SIGNED_CRT  | y if using a self-signed certificate. n otherwise. If not using LDAP leave blank. | 1
 $USERNAME  | Username of initial user to log into the IBM Business Automation Content Analyzer. The value should match the login name where you given in the DB creation script AddTenant.sh. | 1
 $BXDOMAINNAME  | Domain name used to access frontend/backend. Generally, fill in host name of proxy node if you are using IBM Cloud Private, fill in host name of infra node if you are using OpenShift. | 1
 $BACKEND_HOST  | Domain used in URL to access backend. Usually the same as BXDOMAINNAME. If using ingress with non-default port (80/443), then include port in hostname (for example, my.domain.com:444). | 1
 $BACKEND_PORT  | For non-ingress solution, enter the node port of the spbackend service, otherwise leave blank. | 1
 $BACKEND_PATH  | If using path based ingress, specify the path for backend (for example, in http://my.domain.com/backendsp/ path would be backendsp). Note that backend port and backend path are mutually exclusive. Only one should be specified. Since OpenShift's router does not support URL rewriting, and therefore leave blank, if you are using OpenShift's router as ingress point. | 1
 $FRONTEND_HOST  | Domain used in URL to access frontend. Similar to backend_host. | 1
 $FRONTEND_PATH  | If using path based ingress, specify the path for frontend (for example, in http://my.domain.com/frontendsp/ path would be frontendsp). Since OpenShift's router does not support URL rewriting, and therefore leave blank if you are using OpenShift's router as ingress point. | 1
 $SSL_VALIDATE  | false if using a self-signed certificate. true otherwise. | 11
 $SSO  | true or false depending on whether you need to authenticate through another portal (for example, in IBM cloud). | 1
 $MONGO_LIMITED_MEMORY  | You can define resource limits for each of the mongo pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $MONGO_ADMIN_LIMITED_MEMORY  | You can define resource limits for each of the mongo-admin pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $MINIO_LIMITED_MEMORY  | You can define resource limits for each of the minio pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $RABBITMQ_LIMITED_MEMORY  | You can define resource limits for each of the rabbitmq pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $REDIS_LIMITED_MEMORY  | You can define resource limits for each of th redis pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $CALLERAPI_LIMITED_MEMORY  | You can define resource limits for each of the callerapi pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $BACKEND_LIMITED_MEMORY  | You can define resource limits for each of the backend pods on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $FRONTEND_LIMITED_MEMORY  | You can define resource limits for each of the spfrontend pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $POST_PROCESS_LIMITED_MEMORY  | You can define resource limits for each of the postprocessing pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $PDF_PROCESS_LIMITED_MEMORY  | You can define resource limits for each of the pdfprocess pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $UTF8_PROCESS_LIMITED_MEMORY  | You can define resource limits for each of the utf8process pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $SETUP_LIMITED_MEMORY  | You can define resource limits for each of the setup pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $OCR_EXTRACTION_LIMITED_MEMORY  | You can define resource limits for each of the ocr-extraction pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $CLASSIFY_LIMITED_MEMORY  | You can define resource limits for each of the classifyprocess-classify pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $PROCESSING_EXTRACTION_LIMITED_MEMORY  | You can define resource limits for each of the processing-extraction pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $INTER_PROCESSING_LIMITED_MEMORY  | You can define resource limits for each of the interprocessing pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $REANALYZE_LIMITED_MEMORY  | You can define resource limits for each of the reanalyze pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $UPDATEFILE_LIMITED_MEMORY  | You can define resource limits for each of the updatefiledetail pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. | 1
 $MONGO_WIREDTIGER_LIMIT  | You can define WiredTiger cache limits for each of the mongo pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. Note this value should just be entered as a number only in GB (for example, .3 and not .3Gi or 300Mi) | 1
  $MONGO_ADMIN_WIREDTIGER_LIMIT  | You can define WiredTiger cache limits for each of the mongo-admin pods based on available memory on the worker/compute nodes to ensure better operating efficiency. Use the sample install script, generateMemoryValues.sh, to determine the appropriate values for each of the following values based on your environment. Note this value should just be entered as a number only in GB (for example, .3 and not .3Gi or 300Mi) | 1
