## Common.sh parameters

Review common.sh as a reference sample then copy common_ICP_template.sh or common_OCP_template.sh to common.sh based on your platform.

Note Since the common.sh contains several passwords, you need to protect it by assigning appropriate permission such as read-only.

#### common.sh parameters
|Description|Possible values|
|-----------|-----------------------|
SERVER_MEMORY| The amount of memory for Content Analyzer worker nodes 	16,32, etc. Required: Yes
MONGO_SERVER_MEMORY| The amount of memory for Content Analyzer mongo node 	16,32, etc. Required: Yes
MONGO_ADMIN_SERVER_MEMORY| The amount of memory for Content Analyzer mongoadmin node 	16,32, etc. Required: Yes
USING_HELM|Indicate if you want to deploy Content Analyzer with Helm Chart. If given value is "n", will deploy Content Analyzer with Kubernates YAML files 	"y" or "n". Required: Yes
HELM_INIT_BEFORE|This field is used for installing Helm client for Content Analyzer helm install. Set it to "n" if you are not installing Content Analyzer using Helm. 	"y" or "n". Required: Yes
ICP_VERSION or OCP_VERSION|ICP version is 3.1.2. OCP version is 3.11 	"3.1.2" or "3.11". Required: Yes
KUBE_NAME_SPACE| 	The K8's namespace that Content Analyzer will be installed on. 	Any valid namespace. Required: Yes
DOCKER_REG_FOR_SERVICES|This is the Content Analyzer domain used in ICP cluster, docker registry port and your namespace. For example: mycluster.icp:8500/sp where mycluster.icp is the Content Analyzer domain, 8500 is the docker registry port and sp is the namespace you want to install Content Analyzer on. 	Example:mycluster.icp:8500/sp. Required: Yes
LABEL_NODE |-Content Analyzer (CA) processing components will be deployed on node(s) with label celery<KUBE_NAME_SPACE>=baca<br>-mongodb will be deployed on node with label mongo<KUBE_NAME_SPACE>=baca<br>-mongoadmindb will be deployed on node with label mongoadmin<KUBE_NAME_SPACE>=baca<br>Example: The nodes will have these labels where the namespace is "sp":<br>-celerysp=baca<br>-mongosp=baca<br>-mongoadminsp=baca<br>You must manually label your nodes per the above guideline if the value of LABEL_NODE is "n". 	"y" or "n". Required: Yes
CA_WORKERS |A list of comma separated IP address (ICP) or host names (Openshift) of worker nodes to be labeled as "celery<KUBE_NAME_SPACE>=baca". NOTE: You can share the nodes/IP if you have a small cluster for development purposes. 	Required if LABEL_NODE = "y"
MONGO_WORKERS|A list of comma separated IP address (ICP) or host names (Openshift) of worker nodes to be labeled as "mongo<KUBE_NAME_SPACE>=baca". NOTE: You can share the nodes/IP if you have a small cluster for development purposes. 	Required if LABEL_NODE = "y"
MONGO_ADMIN_WORKERS|A list of comma separated IP address (ICP) or host names (Openshift) of worker nodes to be labeled as "mongoadmin<KUBE_NAME_SPACE>=baca". NOTE: You can share the nodes/IP if you have a small cluster for development purposes. 	Required if LABEL_NODE = "y"
ICP_USER or OCP_USER|ICP or OCP username with enough permission to deploy Content Analyzer. Required: Yes
ICP_USER_PASSWORD or OCP_USER_PASSWORD|ICP's or OCP's username password. Must be encoded with base 64. Required: Yes
BXDOMAINNAME|IP address of your ICP's proxy node if you are using ICP. IP address of your OCP's infra node if you are using OCP. Required: Yes
MasterIp|IP address of your ICP's or OCP master node. Required: Yes
PVCCHOICE|Whether to have script create PV/PVC for Content Analyzer. PVCCHOICE=1 means script will create directories.  See note below table for more information. Default 1. Required: yes 
SSH_USER|User for the script to SSH into the NFS server (NFS_IP) to create the necessary folders. This user must have "sudo" privilege. Not required if you create PV/PVC manually.
NFS_IP|NFS Server IP address. Not required if you create PV/PVC manually.
DATAPVC|Name of the data pvc. If you use a different name you must change it in the values.yaml. Default: sp-data-pvc. Required: Yes
LOGPVC|Name of your log pvc. If you use a different name you must change it in the values.yaml 	sp-log-pvc. Required: Yes
CONFIGPVC|Name of your config pvc. If you use a different name you must change it in the values.yaml 	sp-log-pvc. Required: Yes
BASE_DB_PWD|This is the base-64 encoded Content Analyzer base database password. Required: Yes
LDAP|Indicate if you want to integrate Content Analyzer with external LDAP 	"y" or "n". Required: Yes
LDAP_PASSWORD|This is the base-64 encoded Content Analyzer base database password for the LDAP bind user. Required: Yes (if LDAP)
LDAP_URL|LDAP URL such as ldap://192.168.10.10 for non SSL. For ssl, you can use ldaps://192.168.10.10. Required: Yes (if LDAP)
LDAP_CRT_NAME|The name of the LDAP's server client certificate when using 'ldaps' in the LDAP_URL. For more information on how to generate the required certificate, refer to the LDAP vendor documentation.

If you select PVCCHOICE=1, the script will perform the following tasks: 
1) create the following directories on the NFS server:   
    - /exports/smartpages/<KUBE_NAME_SPACE>/{config,data,logs}  
    - /exports/smartpages/<KUBE_NAME_SPACE>/data/{mongo,mongoadmin}
    - /exports/smartpages/<KUBE_NAME_SPACE>/config/backend  
    - /exports/smartpages/<KUBE_NAME_SPACE>/logs/{backend,frontend,callerapi,processing-extraction,pdfprocess,setup,interprocessing,classifyprocess-classify,ocr-extraction,postprocessing,reanalyze,updatefiledetail,minio,redis,rabbitmq,mongo,mongoadmin,utf8process}"  
2) Change the owner on all folders to 51000:51001 
3) Append all the worker's IP to the /etc/exports file on the NFS server.

Back to [Init_Deployment](init_deployment.md)