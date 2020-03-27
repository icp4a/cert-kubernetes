# Business Automation Insights with demo patterns on Red Hat OpenShift 3.11

- [Installing Business Automation Insights with two demo patterns](install_insights_ocp.md#installing-business-automation-insights-with-two-demo-patterns)
- [Uninstalling Business Automation Insights and the demo patterns](install_insights_ocp.md#uninstalling-business-automation-insights-and-the-demo-patterns)
- [Troubleshooting](install_insights_ocp.md#troubleshooting)

# Installing Business Automation Insights with two demo patterns

Business Automation Insights is installed on a single node with a script. The Operational Decision Manager pattern and the FileNet Content Manager pattern are installed by the Cloud Pak operator with a cluster setup script and a deployment script.

- [Prerequisites](install_insights_ocp.md#prerequisites)
- [Task 1: Prepare your environment](install_insights_ocp.md#task-1-prepare-your-environment)
- [Task 2: Install Business Automation Insights for a server](install_insights_ocp.md#task-2-install-business-automation-insights-for-a-server)
- [Task 3: Install the Operational Decision Manager demo pattern (optional)](install_insights_ocp.md#task-3-install-the-operational-decision-manager-demo-pattern-optional)
- [Task 4: Verify the Decision dashboard in Business Automation Insights](install_insights_ocp.md#task-4-verify-the-decision-dashboard-in-business-automation-insights)
- [Task 5: Install the FileNet Content Manager demo pattern (optional)](install_insights_ocp.md#task-5-install-the-filenet-content-manager-demo-pattern-optional)
- [Task 6: Verify the Content dashboard in Business Automation Insights](install_insights_ocp.md#task-6-verify-the-content-dashboard-in-business-automation-insights)


## Prerequisites
Make sure you have access to the following configuration:
- A Red Hat OpenShift cluster v3.11
- A single macOS or Linux machine to host Business Automation Insights

## Task 1: Prepare your environment
1. Install Docker and Docker Compose on your machine
   - On macOS: 
   
     Follow the instructions here https://docs.docker.com/docker-for-mac/
   
   - On Linux:
   
     a. Install Docker 
     ```
     yum install docker
     ```
     b. Install Docker Compose 
     ```
     curl -L "https://github.com/docker/compose/releases/download/1.25.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
     ```
     c. Start the Docker daemon
     ```
     systemctl start docker
     ```
     d. Check that Docker has started correctly
     ```
     docker version
     ```
     e. Change execution permissions
     ```
     chmod +x /usr/local/bin/docker-compose
     ```
     f. Check that Docker Compose is installed correctly
     ```
     docker-compose version
     ```
     
2. If the `hostname` command is not installed on your machine, install it
     ```
     yum install bind-utils
     ```
3. Install the `oc` client

   a. Select and download the desired openshift-client from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/ 
   
   b. Extract the `oc` client files
   
   Example: 
   ```
   wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-4.3.1.tar.gz
   tar -xvf ./openshift-client-linux-4.3.1.tar.gz
   ```
   
   On Linux, you can add the `oc` client to your path as follows:
   ```
   mv oc /usr/local/bin/
   ```

## Task 2: Install Business Automation Insights for a server
1. Download the installation files

   a. Search for the Business Automation Insights for a server part number (CC5PYEN) on the Xtrem Leverage site https://w3-03.ibm.com/software/xl/download/ticket.wss 
   
   b. Extract the files
   ```
   tar -xzvf bai-for-server-$VERSION.tgz
   ```
2. Install Business Automation Insights for a server

   a. Go to the `bai-for-server-$VERSION` directory.
     ```
     cd bai-for-server-$VERSION
     ```
   
   b. Start IBM Business Automation Insights.
   ```
   ./bin/bai-start --acceptLicense --init
   ```
     The first time you start IBM Business Automation Insights, you must read and accept the license, and pass the `--init` option, which initializes the product configuration and generates the various necessary certificates. If you later restart the product, do not pass the `--init` option.
   
   c. Answer the script questions.
   
     The username and password information of each component (Kafka, Elasticsearch...) is available in the `<BAI DIR>/.env` hidden file, as well as any other required information. 
     
     The output of the script is a Kibana URL. 
     
   d. To verify the installation of Business Automation Insights, launch the Kibana URL. 
   
      Enter the kibana user and kibana password that you specified in the `bai-start` script.  



## Task 3: Install the Operational Decision Manager demo pattern (optional)

1. Log in to your OpenShift cluster 

   a. Open the  cluster console.
   
   b. In the top right of the console, click `copy login command`.
   
   c. In a terminal window, paste this command as `oc login ...`
    
2. Create the namespace where you plan to install Operational Decision Manager.
   ```
   oc new-project <odmproject>
   ```
3. Create a Kubernetes secret for the Business Automation Insights emitter with Operational Decision Manager

   a. Create the configuration file `plugin-configuration.properties`, for example:
      ```
      com.ibm.rules.bai.plugin.kafka.sasl.mechanism=PLAIN
      com.ibm.rules.bai.plugin.kafka.security.protocol=SASL_SSL
      com.ibm.rules.bai.plugin.kafka.ssl.enabled.protocols=TLSv1.2
      com.ibm.rules.bai.plugin.kafka.ssl.truststore.location=/config/baiemitterconfig/truststore.jks
      com.ibm.rules.bai.plugin.kafka.ssl.truststore.password=TRUSTSTOREPASSWORD
      com.ibm.rules.bai.plugin.kafka.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required  username="KAFKAUSER" password="KAFKAPASSWORD";
      com.ibm.rules.bai.plugin.topic=bai-ingress
      com.ibm.rules.bai.plugin.kafka.bootstrap.servers=KAFKAHOST:29092
      ```
     - Make sure the file is named exactly `plugin-configuration.properties`
     - Edit the file 
       - TRUSTSTOREPASSWORD - Copy the value from the file `<BAI DIR>/certs/kafka/store-password.txt` 
       - KAFKAUSER -  Credentials that you specified as kafka user in the `bai-start` script
       - KAFKAPASSWORD - Credentials that you specified as kafka password in the `bai-start` script.
 You have to decode it and put it in plain text in `plugin-configuration.properties`
       - KAFKAHOST - The machine host name that you entered when installing Business Automation Insights (found by typing `hostname -f` on Linux, for example)
  
   b. Create a new directory
      ```
      mkdir odmsecret
      ```
   c. Get the `truststore.jks` file found in `<BAI DIR>/certs/kafka/` and put it together with the `plugin-configuration.properties` file inside the `odmsecret` folder.
   ```
   scp root@<bai for a Server url>:<BAI DIR>/certs/kafka/truststore.jks . 
   scp root@<bai for a Server url>:<BAI DIR>/certs/kafka/store-password.txt .
   ```
   
   d. Go to the `odmsecret` folder and create the Kubernetes secret
   ```
   oc create secret generic baiodmsecrets --from-file=./plugin-configuration.properties --from-file=./truststore.jks
   ```
4. Get the Operational Decision Manager pattern from GitHub

   Download or clone the following GitHub repository on your local machine and go to the `cert-kubernetes` directory.
   ```
   git clone https://github.ibm.com/dba/cert-kubernetes
   $ cd cert-kubernetes
   ```
5. Edit the `cert-kubernetes/descriptors/patterns/ibm_cp4a_cr_demo_decisions.yaml` CR file to add the Kubernetes secret
   - Uncomment the lines `customization` and `baiEmitterSecretRef: baiodmsecrets` (near the end of the .yaml file, at the same level as `image`)
   
6. Run the installation script
   ```
   $ cd scripts
   $ ./cp4a-demo-admin.sh
   $ ./cp4a-pattern-deployment.sh 
   ```
   - Answer the script questions
   - Select `Operational Decision Manager`
   - Put `iamapikey:yourkey` for the entitled registry
  


## Task 4: Verify the Decision Dashboard in Business Automation Insights

Wait for the installation to complete, and then verify that the Operational Decision Manager emitters are present. 
Because the ODM demo pattern comes with a built-in sample, you can easily check ODM sending events to Business Automation Insights by using the Decision Server console.

1. Open the Decision Server console (in the OpenShift console, look at the generated routes and click `odm-ds-onsole`).
Sign in with `odmAdmin`/`odmAdmin`.

   a. Click Explore > LoanValidationDS > loan_validation_production ruleset

   b. Click Add Property > Select `bai.emitter.enable`> Enter `true` > Click Add

   c. Click Retrieve HTDS Description File

   d. Select REST > Select JSON format > Click Test
   
   A new window opens that allows you to execute a ruleset.
   In the execution request, you might want to remove the line "DecisionID" so that multiple events display in Kibana.

   e. Click Execute Request
   
   You get a server response. An event should have been sent to Kafka.
   
2. Launch the Kibana URL to check the results

   a. Open the Kibana Decision Dashboard. Credentials are the ones you specified when you installed Business Automation Insights for a server. 
   
   b. Click Dashboard > Select Decisions Dashboard




## Task 5: Install the FileNet Content Manager demo pattern (optional)

1. Install the ECM pattern in a separate namespace 

   a. Login to your cluster using `oc`.
   
     - Open your cluster console
   
     - In the top right of the console, click `copy login command`.
   
     - In a terminal window, paste this command as `oc login ...`
    
   b. Create the namespace where you plan to install ECM.
      ```
      oc new-project <ecmproject>
      ```
     
   c. Get the ECM pattern from GitHub

      Download or clone the following GitHub repository on your local machine and go to the `cert-kubernetes` directory.
      ```
      git clone https://github.ibm.com/dba/cert-kubernetes
      $ cd cert-kubernetes
      ```  

    d. Run the installation script

      ```
      $ cd scripts
      $ ./cp4a-demo-admin.sh
      $ ./cp4a-pattern-deployment.sh 
      ```
      - Answer the script questions
      - Select `FileNet Content Manager`
      - Put `iamapikey:yourkey` for the entitled registry

2. Configure ECM to send events to Business Automation Insights

   a. Retrieve the Content event emitter module
   
      - Locate the `cpe-deploy` pod by running the command
        ```
        oc get pods
        ```
      - Download the `bai-content-emitter`archive
        ```
        oc cp <CPEPod>:lib/ContentBAI/eventhandler .
        ```
        For example:
        ```
        oc cp content-cpe-deploy-5464884bf6-k9xq:lib/ContentBAI/eventhandler .
        ```

  
   
   b. Configure the Content event emitter
   
      - Log into the FileNet Administration Console for Content Platform Engine
      - Find the `cpe` route in OpenShift Console > Applications > Routes > content-cpe-route
      - Paste the hostname into a browser and add `/acce` to the URL
        The `acce` console opens
      - In OpenShift Console > Resources > Secrets > ibm-fncm-secret, look for the username and password
      - Create a new Event Action
        - Locate `Event Actions` in the left menu, and then right click and select `New Event Action`
        - Enter a name for this event action (for example, `myBAIEventAction`), and then click `Next`
        - At the `Specify the Type of Event Action` section:
          - Check `Status: Enabled`
          - Select `Type: Class`
          - At `Java class handler`, enter `com.ibm.bai.content.event.emitter.eventhandler.ContentEmitterHandler`
          - Check `Configure code module`
          - Click `Next`
        - At the `Specify the Code Module` section:
          - Enter the `Code module title`. Example: `EmitterCodeModule`
          - At `Content elements`, click `Browser` to select the `bai-content-emitter.jar` you retrieved in the previous step.
          - Click `Next`, and then click `Finish`
          
      - Create an Event Subscription
        - Locate the `Subscriptions` folder in the left menu, and then right-click and select `New Subscription`.
        - Enter a display name (for example, `BAISubscription`), and then click `Next`
        - At the `Select Classes` section, set `Class type` and `Class` to `Document`. Click Next.
        - At the `Specify the Subscription Behavior` section, keep the default settings. Click Next.
        - At the `Select the Triggers` section, select `Creation Event and Update Event`. Click Next.
        - At the Event action section, for `Select an event action`, select the event action you created in an earlier step (for example, `myBAIEventAction`). Click Next.
        - At the `Specify Additional Options` section:
          - For `Initial state`, select `Enable the Subscription`
          - For `Subclass option`, select `Include subclasses` if you want to emit them.
          - Do not select `Run synchronously`
          - Click `Next`, and then click `Finish
           
     
   c. Customize the configuration file
   
   - Locate the `cpe-cfgstore` persistent volume on your cluster. For example:
     ```
     ssh root@mycluster.ocp
     cd /export/NFS
     ```
   - Locate the persistent volume by searching the directory, for example: 
     ```
     cd ecm-project-cpe-cfgstore123454
     ```
   - Create a new directory named `BAIForContent`
   - Set permissions on the directory:
     ```
     chown 50001:50000 BAIForContent
     chmod -R g=u BAIForContent
     chgrp -R 0 BAIForContent
   - Copy the `truststore.jks` file found in /certs/kafka/  into the `BAIForContent directory`
   - Edit a new file with the following template and name it `configuration` with no extension      
      ```
      contentemitter.input.content.server=CPE_HOSTNAME
      contentemitter.output.kafka.topic=bai-ingress
      contentemitter.output.kafka.bootstrap.servers=KAFKA_HOST:29092
      contentemitter.output.kafka.security.protocol=SASL_SSL
      contentemitter.output.kafka.ssl.truststore.location=/opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/BAIForContent/truststore.jks
      contentemitter.output.kafka.ssl.truststore.password=KAFKA_BROKERS_TRUSTSTORE_PASSWORD
      contentemitter.output.kafka.ssl.enabled.protocols=TLSv1.2
      contentemitter.output.kafka.ssl.truststore.type=JKS
      contentemitter.output.kafka.ssl.endpoint.identification.algorithm=
      contentemitter.output.kafka.sasl.mechanism=PLAIN
      contentemitter.output.kafka.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="JAAS_CLIENT_USERNAME" password="JAAS_CLIENT_USER_PASSWORD";
      ```
               
   - Change the values according to your installation
   
     CPE_HOSTNAME: Use the IP address of the master node
     
     KAFKA_BROKERS_TRUSTSTORE_PASSWORD: Copy the value from the file `/certs/kafka/store-password.txt`
     
     KAFKA_HOST: The machine host name that you entered when installing Business Automation Insights (found by typing `hostname -f on Linux`, for example)
     
     JAAS_CLIENT_USERNAME: Credentials that you specified as kafka user in the `bai-start` script
     
     JAAS_CLIENT_USER_PASSWORD: Credentials that you specified as kafka password in the `bai-start` script. You have to decode it and put it in plain text
     
   d. Restart the CPE pod 
      For example: 
      ```
      oc delete pod <CPEPod>
      ```

## Task 6: Verify the Content dashboard in Business Automation Insights

In order to verify that an event has been submitted from FileNet to Business Automation Insights, you need to trigger the event by adding a new document.

1. Open the FileNet console

2. Log in to the FileNet navigator console

   a. Find the `cpe` route in OpenShift Console > Applications > Routes > content-navigator-route
  
   b. Paste the hostname into a browser and add `/navigator` to the URL
   
     The navigator console opens.
     
   c. In the OpenShift Console > Resources > Secrets > ibm-fncm-secret, look for the username and password

3. Add a new document

   a. In the top right menu, click `Add Document`
  
   b. Enter a name and upload a test document
  
   c. Click `Add`
   
     A creation event must have been sent.

4. Launch the Kibana URL to check the results

    a. Open the Kibana Content Dashboard. Credentials are the ones you specified when you installed Business Automation Insights for a server.   
   
    b. Click Dashboard > Select Content Dashboard

  
 

# Uninstalling Business Automation Insights and the demo patterns

To uninstall a demo deployment, delete the namespace by running the following command:
```
$ oc delete project <project-name>
```
   
To uninstall the cluster role, cluster role binding, and the CRD, run the following commands:
```
$ oc delete clusterrolebinding <NAMESPACE>-cp4a-operator 
$ oc delete clusterrole ibm-cp4a-operator 
$ oc delete crd icp4aclusters.icp4a.ibm.com
```

To uninstall Business Automation Insights for a server, refer to the Knowledge Center http://ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/bai_sn_topics/tsk_bai_sn_uninstall.html


# Troubleshooting

Refer to the Knowledge Center http://ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.bai/topics/con_bai_sn_troubleshooting_top.html
