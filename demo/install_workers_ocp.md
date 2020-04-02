# Automation Digital Worker with a pattern on Red Hat OpenShift 3.11

- [Installing Automation Digital Worker combined to a pattern](install_workers_ocp.md#installing-automation-digital-worker-combined-to-a-pattern)
- [Uninstalling Automation Digital Worker](install_workers_ocp.md#uninstalling-automation-digital-worker)
- [Troubleshooting](install_workers_ocp.md#troubleshooting)


# Installing Automation Digital Worker combined to a pattern

- [Prerequisites](install_workers_ocp.md#prerequisites)
- [Task 1: Prepare your environment](install_workers_ocp.md#task-1-prepare-your-environment)
- [Task 2: Install Automation Applications](install_workers_ocp.md#task-2-install-automation-applications)
- [Task 3: Install Automation Digital Worker](install_workers_ocp.md#task-3-install-automation-digital-worker)
- [Task 4: Verify the installation](install_workers_ocp.md#task-4-verify-the-installation)
- [Task 5: Install Automation Content Analyzer (optional)](install_workers_ocp.md#task-5-install-automation-content-analyzer-optional)
- [Task 6: Install Operational Decision Manager (optional)](install_workers_ocp.md#task-6-install-operational-decision-manager-optional)

## Prerequisites
Make sure you have access to the following configuration:
- A Red Hat OpenShift cluster v3.11

## Task 1: Prepare your environment

Install the `oc` client on your local machine or where you plan to install Automation Digital Worker

1. Select and download the desired openshift-client from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/ 
   
2. Extract the `oc` client files
   
   Example: 
   ```
   wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-4.3.1.tar.gz
   tar -xvf ./openshift-client-linux-4.3.1.tar.gz
   ```
   
   On Linux, you can add the `oc` client to your path as follows:
   ```
   mv oc /usr/local/bin/
   ```

## Task 2: Install Automation Applications


1. Create a project to install Automation Digital Worker 
  ```
  oc login ...
  oc new-project <adwproject>
  ```

2. Get the Applications pattern from GitHub

Download or clone the following GitHub repository on your local machine and go to the `cert-kubernetes` directory.
```
git clone https://github.com/icp4a/cert-kubernetes
$ cd cert-kubernetes
```

3. Run the install script
  ```
  $ cd scripts
  $ ./cp4a-clusteradmin-setup.sh
  $ ./cp4a-deployment.sh 
  ```
  - Pick option 5 "automation applications"
  - Answer the script questions
  - Put `iamapikey:yourkey` for the entitled registry
  
  At the end of the installation, you get an output like this one:
  
  ```
  The custom resource file used is: "/root/cert-kubernetes/scripts/.bak/.ibm_cp4a_cr_demo_application.yaml"...
  ```
  
   It is this CR file that you will modify in later steps. Copy it from the output. For example:
   
  `cp /root/cert-kubernetes/scripts/.bak/.ibm_cp4a_cr_demo_application.yaml ./mycr.yaml`
 
4. Get the OCP infrastructure name
  ```
  export INFRA_NAME=<infra name>
  export NAMESPACE=adwproject
  ```
  `<infra name>` is given by the  `./cp4a-clusteradmin-setup.sh`script.

5. Get the UMS credentials, you will need to enter them in later steps

   - The user name is `umsadmin` and the password is the value of `umsadminpassword`, which is randomly generated.
To get the password, look in OpenShift Console > Resources > Secrets > ibm-dba-ums-secret.
   
  
## Task 3: Install Automation Digital Worker

   1. Create the SSL certificate and adw-tls-secret by copy-pasting the following code.
   ```
   echo "$(date +%T) - ### Generating SSL certificate for ADW ###"
   openssl genrsa -out server.key 2048
   openssl rsa -in server.key -out server.key
   openssl req -sha256 -new -key server.key -out server.csr -subj "/CN=adwmanagement.$NAMESPACE.$INFRA_NAME"
   openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
   echo "$(date +%T) - ### Creating secret to allow BAS communication ###"
   oc create secret tls adw-tls-secret --key server.key --cert=server.crt
   ```
   
   2. Create the Automation Digital Worker secret
   
      a. Copy the ADW secret template code below.
      
      b. Fill it in with the following values.
     
         - nmpUser => leave as is
         - nmpPassword => leave as is
         - SkillEncryptionSeed => leave as is
         - oidcclientId => leave as is
         - oidcclientpassword => leave as is
         - oidcUserName => leave as is
         - oidcPassword => umsadmin password encoded in base64. Can be found in the secret `ibm-dba-ums-secret`. Example for a macOS user: `echo -n <the password in plain text> | base64`
         - registryPassword => found in application-rr-admin-secret (writePassword to be encoded in base64)
         - registryUser => leave as is 
         - servert.crt => certificate generated just before in base64
         - server.key => key generated just before in base64
         - oc apply -f adw-secret.yaml
     
 ADW secret template code:    
     
 ```
 apiVersion: v1
kind: Secret
metadata:
  name: adw-secret
type: Opaque
data:
  npmUser: YmFpdw==
  npmPassword: YmFpdw==
  skillEncryptionSeed: YmFpdy1za2lsbHM=
  oidcClientId: bXljbGllbnRpZCAtbgo=
  oidcClientSecret: Y2xpZW50cGFzc3dvcmQ=
  oidcUserName: dW1zYWRtaW4=
  oidcPassword: WHpUeTN6ZzVtQXFZWE5oT2pyMU8=
  registryPassword: eXBHWlB2TWxNVGZudWRS
  registryUser: d3JpdGVy
  server.crt: 
cxLwpUeUFhUWVsT3Nad3NLcU5KWldtQ0FLWVZmTmZnWkVQeE96dnIrbDExU2dzWEU5Q0tTK2JjOFJYejFBemllRFJ1Cm9HSU96T0Uxc2ZTRG93WnZZL0J2TVVsT3V0bXd1YUJXNFpDd25ib29URl
VtSE0wQ0F3RUFBVEFOQmdrcWhraUcKOXcwQkFRc0ZBQU9DQVFFQXBweEQwbEtQU2xpWk5ZTCthWGM4VFhoUDN1TFFsMFoxenNzK0ZNc2Jodmc2Z2F6YQpVbW9sR081S2tyV3VYZHZDYW0zbkdBR2
xTakRxT21pZnNZTVJxejh6dE93TWQ0TXN0YjdJQzVQUlBGWXRIanJ0ClJFQU81NnVzZVcrNGFQWVNZZEcxUmNZa0o3MFlVRnY1UllXOEcrTy9Rd0NrcTRHazdVcVptMVA4VUU2OUtTaXYKY05Oa1
cyYmpRdWIrNTJpTDlWaVJpcWpQcW5EM1ZRY1FxQzZLOURjN3o5dXc3VU8yVmNyWmJJcE45UHhzWTEreQpwSTVQdlRic0pTMXhNOVNkcVlHUDk3YUtnK24vVkhwV1oyOU5ydEIzT1g0UktkcjRjUW
RWUEZobUpSS20yTkZKCkx3YmRKRzB3MTJrTk9ESXYrZGJUVlNRQzIzcy84U0pZSWsycFZnPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
  server.key: 
BMOGtiVmFmOWJrMlFyMmpTcS9ZZGFsejNrbjg2eExBMUlnTUg4ejByYndqY3ZpUWMyVzA4CmZtVlJlbWxqQ3k0S2NQM1hpN01LenNSdWwzSXg1aEl4dTZHWWhCbzhmOWtSY21DZ2lDbDVsY1ZKYU
E2am1nUVgKd0gwa2hUN3lkQ2RqcVBkTVFYODA4d2gvb0gxZFV3eXpyWVVLazRWQ0tJcFJzWDU5Q2NsSEZ6d3VnSEJIV3cwYQorVElEN3E0eVJYZXRVbGZESkVES2tHTVVEOW1QN21nR1BLcFFtTV
lkbTB6NlVwa002c0dKTXJvUHR1ZmhYOWtSCnZMNUNFM2t5bXRkZ2sxdEdDRWo1UXBycVJzMy96UERyOTloZUx2ZzJPM0QxNlFVSkg2NGFndFNXVWxtM2JpSWkKUUR3eG5OS2RBb0dCQU5xaGlDRF
JqYWNaUFFKMlpvK1UzSWpJZ3RWZFJSVDBCby9wUThJVjkwVDVibXZGeE00dwpJOVlLSUpEd0tNNVZMZ3lYSXB2U1pqNHlhS211bTVRbmlxTlpvU3ZqcjdpV2dvcmt1NktTUzdxRVZzaDFQOGVHCm
JoYjBIVXQ1QUJKY2VCc25xNUZqeGpRbUJVSWNrQWpVWWhKQlJqdUpWUlI4MDl3Mk5UZmhUcWhQQW9HQkFNaGsKenY5bG1KQU5oTkFuTDE1dzRGYTZubmw2WXZFVWtkT3IwdTZkckp2Vi9ldkxKcz
lXWXc2ZEdTcjNaTHdRWkJmaAo3bnFrZWg0M2xxR3o2NHpFT0VvZkRPSGIvSlNvai93SWdaWWYzUUsvUW9CODNUZzF6WGdSMjFTYkJvdFV3Zzh0CmFUcngwdFYwNm5oNmNWc2N2ajhUdS82VExWTU
5JU2xUN1RJMVNNWWpBb0dCQUpnTzBzdm9rem5OenVZQWpWSjkKZVdqVTlGSUxYYm0yQXo1aVFaTWlqZWoyQm51RWdGM2JrNEVSYUJjR1FZdElLUS91cWM1d1psWUozMHRzdXA0dgpaamc0WldWT0
pYQWZsa21kem5iQ2cxTUZLZ3FmcWExTzdSQ2YxaVFnMHhEeUtVTFJzMzBhUk1jT1RvZnRyNnZFCmN6VTVHdXpibGtYNmo2dFFOSEZhRGNmM0FvR0FDcmt5Um9KMlJvY2lxMHpkZ1ExRFJBRGFpQi
tmZWMwaS9KTysKUnR5VEp3ZXRmZGV5TFBndmR0RzdUZ3hOREs5SDIrdFFLcW53aXZ0b2lTQ3FveTdBNEY2Ry92TVpzZzdQSGFxSwozTEM1ei9MU0tUUUZWb095aWhGU2psVjVaUzFVOFNENTk1aU
hNcnI5N1JLSVRGcmVaMXV6L0t4OWlXc3pjaFcyCnBMQXJROGNDZ1lBL01KcUQxM0NXVDJ1S0crMU9QdStJbW1jdEJBbkt5Q0k5UlRXMjJKcmRBalZ1bjdnc0MrVzEKT1JFaGYxVVJieXBXVGFFRE
ZveFcra0tJLytIYWdzMGRaTmw3RitMZy9uMFlCa29oVUw5WVczSUFvYzc0UEVlTQpvb2paMVpTSmkrMWNscS9SMFBpT21LMlNwQm1FZTJiVGV2dFBUVEUySG1GRU1KYkwvWEZwUGc9PQotLS0tLU
VORCBSU0EgUFJJVkFURSBLRVktLS0tLQo=
```

3. Modify the `cert-kubernetes/descriptors/patterns/ibm_cp4a_cr_demo_application.yaml` CR file that was generated when you ran the Automation Applications installation script in Task 2. 
   
   a. Add a `adw_configuration` block to the CR file (see below), at the same level as the other configuration blocks (like `ums_configuration` or `basstudio_configuration`)
   
   b. In the `adw_configuration` block, set the URLs for 
     - designer (example: adw.mycluster.mydomain.com)
     - management
     - runtime 
     - UMS (you can find the values of the routes "application-ums-route" and you have to add something at the end, example : )
     - Resource Registry (you can find the values in the "routes" of your cluster and you have to add something at the end, example : )
     
   c. In the `bastudio_configuration`block, add the TLS trust list
   
CR file:

```
apiVersion: icp4a.ibm.com/v1
kind: ICP4ACluster
metadata:
  name: application
  labels:
    app.kubernetes.io/instance: ibm-dba
    app.kubernetes.io/managed-by: ibm-dba
    app.kubernetes.io/name: ibm-dba
    release: 20.0.1
spec:
  adw_configuration:
    adwSecret: adw-secret
    designer:
      externalUrl: 'https://adw.application.mycluster.mydomain.com'
      image:
        repository: cp.icr.io/cp/cp4a/adw/adw-designer
        tag: 20.0.1
      service:
        type: Route
    global:
      imagePullSecret: admin.registrykey
      kubernetes:
        serviceAccountName: ''
    init:
      image:
        repository: cp.icr.io/cp/cp4a/adw/adw-init
        tag: 20.0.1
    management:
      externalUrl: 'https://adwmanagement.application.mycluster.mydomain.com'
      image:
        repository: cp.icr.io/cp/cp4a/adw/adw-management
        tag: 20.0.1
      service:
        type: Route
    oidc:
      endpoint: https://ums.application.mycluster.mydomain.com/oidc/endpoint/ums
    registry:
      endpoint: 'https://rr.application.mycluster.mydomain.com/v3beta'
    runtime:
      externalUrl: 'https://adwruntime.application.mycluster.mydomain.com'
      image:
        repository: cp.icr.io/cp/cp4a/adw/adw-runtime
        tag: 20.0.1
      service:
        type: Route
    setup:
      image:
        repository: cp.icr.io/cp/cp4a/adw/adw-setup
        tag: 20.0.1
  bastudio_configuration:
    images:
      bastudio:
        repository: cp.icr.io/cp/cp4a/bas/bastudio
        tag: 20.0.1
    jms_server:
      image:
        repository: cp.icr.io/cp/cp4a/bas/jms
        tag: 20.0.1
    playback_server:
      images:
        db_job:
          repository: cp.icr.io/cp/cp4a/bas/solution-server-helmjob-db
          tag: 20.0.1
        solution_server:
          repository: cp.icr.io/cp/cp4a/bas/solution-server
          tag: 20.0.1
    tls:
      tls_trust_list:
        - adw-tls-secret
  navigator_configuration:
    image:
      repository: cp.icr.io/cp/cp4a/ban/navigator-sso
      tag: 20.0.1
  resource_registry_configuration:
    images:
      resource_registry:
        repository: cp.icr.io/cp/cp4a/aae/dba-etcd
        tag: 20.0.1
  shared_configuration:
    image_pull_secrets:
      - admin.registrykey
    images:
      busybox:
        repository: docker.io/library/busybox
        tag: latest
      db2:
        repository: docker.io/ibmcom/db2
        tag: 11.5.1.0-CN1
      db2_auxiliary:
        repository: docker.io/ibmcom/db2u.auxiliary.auth
        tag: 11.5.1.0-CN1
      db2_etcd:
        repository: quay.io/coreos/etcd
        tag: v3.3.10
      db2_init:
        repository: docker.io/ibmcom/db2u.instdb
        tag: 11.5.1.0-CN1
      db2u_tools:
        repository: docker.io/ibmcom/db2u.tools
        tag: 11.5.1.0-CN1
      dbcompatibility_init_container:
        repository: cp.icr.io/cp/cp4a/aae/dba-dbcompatibility-initcontainer
        tag: 20.0.1
      keytool_init_container:
        repository: cp.icr.io/cp/cp4a/ums/dba-keytool-initcontainer
        tag: 20.0.1
      keytool_job_container:
        repository: cp.icr.io/cp/cp4a/ums/dba-keytool-jobcontainer
        tag: 20.0.1
      openldap:
        repository: osixia/openldap
        tag: 1.3.0
      umsregistration_initjob:
        repository: cp.icr.io/cp/cp4a/aae/dba-umsregistration-initjob
        tag: 20.0.1
    root_ca_secret: '{{ meta.name }}-root-ca'
    sc_deployment_hostname_suffix: '{{ meta.name }}.mycluster.mydomain.com'
    sc_deployment_patterns: application
    sc_deployment_platform: OCP
    sc_deployment_type: demo
    storage_configuration:
      sc_dynamic_storage_classname: managed-nfs-storage
  ums_configuration:
    images:
      ums:
        repository: cp.icr.io/cp/cp4a/ums/ums
        tag: 20.0.1
 ```

4. Re-apply the CR file
```
oc apply -f cert-kubernetes/descriptors/patterns/ibm_cp4a_cr_demo_application.yaml
```

## Task 4: Verify the installation 

1. Check that all the pods are in a `Running` or `Completed` status

2. Check that Automation Digital Worker is available in Business Automation Studio

   a. Look at the routes in the OpenShift Console, find Business Automation Studio, and then add `/BAStudio` to the Business Automation Studio URL  
  
   b. Open a Browser on the Business Automation Studio URL 
  
   c. Open Automation Digital Worker from Business Automation Studio 
  
3. Check that you can go back to Business Automation Studio by clicking the breadcrumbs in Automation Digital Worker.

## Task 5: Install Automation Content Analyzer (optional)


1. Create a project to install Content Analyzer 
  ```
  oc new-project <acnproject>
  ```

2. Get the Content Analyzer pattern from GitHub

   We  assume you already cloned the git repository:
   ```
   git clone https://github.com/icp4a/cert-kubernetes
   ```

3. Run the install script
  ```
  $ cd scripts
  $ ./cp4a-clusteradmin-setup.sh
  $ ./cp4a-deployment.sh 
  ```
  - Answer the script questions
  - Put `iamapikey:yourkey` for the entitled registry
  
4. Verify that the installation is complete

   The operator reconciliation loop can take some time.

   Open the operator log to view the progress:
   ```
   $ oc logs -c operator -n
   ```
   
   Monitor the status of your pods with:
   ```
   $ oc get pods -w
   ```
   
   When all of the pods are `Running`, you can access the status of your services with the following command:
   ```
   $ oc status
   ```
   
 5. Configure Digital Worker to use Content Analyzer
 
   For details, refer to  https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.adw/topics/con_task_create.html
   
## Task 6: Install Operational Decision Manager (optional)


1. Create a project to install ODM 
  ```
  oc new-project <odmproject>
  ```

2. Get the ODM pattern from GitHub

   We  assume you already cloned the git repository:
   ```
   git clone https://github.com/icp4a/cert-kubernetes
   ```

3. Run the install script
  ```
  $ cd scripts
  $ ./cp4a-clusteradmin-setup.sh
  $ ./cp4a-deployment.sh 
  ```
  - Answer the script questions
  - Put `iamapikey:yourkey` for the entitled registry
  
4. Verify that the installation is complete

   The operator reconciliation loop can take some time.

   Open the operator log to view the progress:
   ```
   $ oc logs -c operator -n
   ```
   
   Monitor the status of your pods with:
   ```
   $ oc get pods -w
   ```
   
   When all of the pods are `Running`, you can access the status of your services with the following command:
   ```
   $ oc status
   ```
 5. Configure Digital Worker to use ODM
 
   For details, refer to  https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.adw/topics/con_task_create.html   
   
# Uninstalling Automation Digital Worker 

To uninstall Automation Digital Worker, delete the namespace by running the following command:
```
oc delete project <adw-project>
```
   
# Troubleshooting 

If Automation Digital Worker is not available in Business Automation Studio, restart the setup job with the following command

```
oc get job dba-adw-2001-setup -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | kubectl replace --force -f -
