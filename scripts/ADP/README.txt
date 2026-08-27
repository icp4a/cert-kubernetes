 IBM Automation Document Processing Content Project Deployment Service Scripts Readme
© Copyright IBM Corporation 2020-2021

Readme file for: IBM® Automation Document Processing Content Project Deployment Service Scripts
Update name: 
Publication date: 15 June 2021
Last modified date: 15 June 2021

## Project Deployment Scripts

	cpds_getOSConfigStatus.sh (replaces cpds_getOSInitStatus.sh)
	cpds_configureOS.sh (replaces cpds_initOS.sh)
	
	cpds_deployProj.sh
	cpds_getDeployedProjSnapshot.sh
	cpds_getDeploymentRec.sh
	cpds_projectPrecheck.sh
	cpds_systemPrecheck.sh
	
	cpds_cleanUpProject.sh
	cpds_cleanUpTeams.sh
	
	helper_getUMSToken.sh
	helper_getZENToken.sh

## Project Deployment properties sample file

	cpds.properties.sample
	
## General Overview

The Project Deployment Scripts provide unix shell script samples using the Content Project Deployment Service REST API. The scripts provided give samples on how to deploy a project version to a Test/Staging/Production environment, monitor the deployment, and check the Object Store to verify the Content Project Deployment configuration has been performed.
             
The cpds.properties.sample are a list of properties which can be input used as input in to the scripts.  Copy the sample, for example to cpds.properties, and insert your values into the file.
     
The four categories of scripts:
- Content Platform Engine Object store scripts:
    - cpds_getOSConfigStatus.sh - checks the project deployment configuration status on the Object Store
    - cpds_configureOS.sh - initializes or updates/upgrades the Content Platform Engine Object Store to current level. This should be run if the getOSConfigStatus.sh script returns a response which the "isInitialized" value is false.
- Project Deployment related scripts:
    - cpds_deployProj.sh - deploys a content project deployment project version
    - cpds_getDeployedProjSnapshot.sh - returns the project version information for the deployed snapshot/version
    - cpds_getDeploymentStatus.sh - returns the deployment record for the deployment project version.
- Deployment check scripts:	
    - cpds_systemPrecheck.sh - performs a system check for the Content Project Deployment Service and returns status of connections, ADP database projects and if the user can deploy a project to the environment.
    - cpds_projectPrecheck.sh - provides the capability to check/preview data and content definition changes without actually deploying the project version to the object store. The script can be run for new project version before it is deployed to identify changes and issues. The script will returned alerts associated with changes made in the version specified against the previous design repository version and against the object store for existing project deployment.  
- Deployment artifact cleanup scripts. (NOTE: These scripts are intended for development environment use and are NOT RECOMMENDED FOR RUNTIME ENVIRONEMNT USE.):
    - cpds_cleanUpProject.sh - removes documents and metadata from the Content Platform Engine repository and removes the associated ADP Project information.
    - cpds_cleanUpTeams.sh - cleans up teams associated to the specified project name.
- helper_getUMSToken.sh is the UMS authentication script used by all the scripts to login to the ums server and provider a bearer token. 

- helper_getZENToken.sh is the IAM/Zen authentication script used by all the scripts to login to the IAM and Zen server to provided a Zen bearer token. 
	 
NOTE:  The sample scripts all use curl command with "-k" value as an example.   This option allows curl to perform "insecure" SSL connections. This curl option should be replaced with a more secure option like --cacert <cerificate file> using certificate file with one or more PEM certificates to create more secure HTTPS connections. See curl for other curl options for using secure connections and certificates.

## Deploying a Project Version

	cpds_deployProj.sh 

This script is intended for the Test/Staging/Production environment. A Document Processing Designer project and version from the Development Environment is deployed into the Test/Staging/Production (runtime) environment. The project is deployed to the Content Platform Engine Object Store and associated ADP runtime environment. 
	
NOTE: This scripts requires both runtime UMS input and development UMS input. The user must be a member of the Doc Processing Manager team for the runtime and either a Doc Processing Manager or a Doc Processing Analyst for the development environment.
	 
NOTE: Prior to running the scripts the configuration for a runtime object store requires the cpds container environment variables ADP_DEPLOYMENT_ENV = RUNTIME and REPO_SERVICE_URL to point to the Content Designer Rest API (CDRA) url on the development environment.  The SSL certificates should have been imported as secrets into your runtime cpds environment
		
	
	Example to run script using cpds.properties file:
	./cpds_deployProj.sh --file cpds.properties 
	Example to run script using cpds.properties file but overriding file runtimeObjectStore value with a different Object store name
	./cpds_deployProj.sh --file cpds.properties --runtimeObjectStore OS2
	
	Documentation in the Knowledge Center will provide more information for the POST /v1/deployment/projects/{projectIdentifier}/branches/{branchName}/snapshots/{snapshotName} 
	
	Sample Output 
	./cpds_deployProj.sh --file cpds.properties 
	Extracting fields from file cpds.properties ......
	Getting RunTime UMSToken ...
	Getting Dev UMSToken ...
	Deploying project ...
	If deployment takes a long time,
	1. You can run cpds_getDeployedProjSnapshot.sh to return the overview information about the deployed project version.
	2. You can run cpds_getDeploymentRec.sh, pass in a deploymentRecordId from in the previous step retrieved lastDeploymentRecordId value, to retrieve detailed progress.
	<This can take about 1-3 minutes>
	
		
	
	There are 3 possible Return Codes for deploy: 
	200: deployment is successful
	202: deployment fails in midstream and there are some deployment artifacts created..
	anything that is NOT 200 or 202: deployment fails at start due to configuration issue. No artifact has been created. 
	
	
	Example of 200 return code:
	{"data":{"branchName":"master","caProjectDescriptor":"10f8d31b-9498-4b26-abba-4aafb887fc31","deploymentStatus":{"status":"Success","type":"New"},"lastDeploymentRecordId":"{50668C79-0000-CC1A-874E-82225FA4D67B}","precheckDetails":{"alerts":[{"alertAction":"No action is needed.","alertCode":"A200","alertMessage":"The class definition DbaJL125BillofLading will be added to the object store.","alertSeverity":"Informational","artifactType":"Class","changeSourceType":"ObjectStore","changeType":"ClassAdded","classSymbolicName":"DbaJL125BillofLading","referenceId":0},{"alertAction":"No action is needed.","alertCode":"A200","alertMessage":"The class definition DbaJL125Invoice will be added to the object store.","alertSeverity":"Informational","artifactType":"Class","changeSourceType":"ObjectStore","changeType":"ClassAdded","classSymbolicName":"DbaJL125Invoice","referenceId":1},{"alertAction":"No action is needed.","alertCode":"A200","alertMessage":"The class definition DbaJL125UtilBill will be added to the object store.","alertSeverity":"Informational","artifactType":"Class","changeSourceType":"ObjectStore","changeType":"ClassAdded","classSymbolicName":"DbaJL125UtilBill","referenceId":2}],"classes":[{"referenceId":0,"definitionFile":"CD_BillofLading.json","displayName":"Bill of Lading","symbolicName":"DbaJL125BillofLading"},{"referenceId":1,"definitionFile":"CD_Invoice.json","displayName":"Invoice","symbolicName":"DbaJL125Invoice"},{"referenceId":2,"definitionFile":"CD_UtilBill.json","displayName":"UtilBill","symbolicName":"DbaJL125UtilBill"}],"propertyTemplates":[]},"projectId":"{279D24C9-B026-461B-BCF8-B5E4BFC37ACF}","projectIdentifier":"JL125","projectVersionId":"{F07A7D09-2F47-45C9-B028-5E5E912B514D}","repositoryIdentifier":"OS1","snapshotName":"v32-2021-05-14-1654"},"status":{"code":200,"message":"Successfully deployed the project.","messageId":"FNRDD0003I"}}
	Return Code=200

	
	See Project Precheck section for explanation of alerts. 
	
	Explanation of output:
	{
	  "data": {
	    "branchName": "master",
	    "caProjectDescriptor": "a1263c2a-778f-452a-b4ca-e55ef79dda9d", =>ADP Project descriptor associated with the deployment project.
	    "deploymentStatus": {
	      "status": "Success", => Options are Success or Failed
	      "type": "Redeploy" => New, the first time the version is deployed or Redeploy, a subsequent deployment of the same version
	    },
	    "lastDeploymentRecordId": "{50A5E775-0000-C314-82C6-1D87C9F34749}", => the last deployment record can be used to find out information about the deployment. See  cpds_getDeploymentStatus.sh
        "precheckDetails": {
            "alerts": [
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDCustomernumber will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDCustomernumber", 
                    "referenceId": 0
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDAccountnumber will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDAccountnumber", 
                    "referenceId": 1
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDDuedate will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDDuedate", 
                    "referenceId": 2
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDPaymentreceived will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDPaymentreceived", 
                    "referenceId": 3
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDPreviousbalance will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDPreviousbalance", 
                    "referenceId": 4
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDTotalamountdue will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDTotalamountdue", 
                    "referenceId": 5
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDCompanynameandaddress will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDCompanynameandaddress", 
                    "referenceId": 6
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDUnpaidAndNewCharge will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDUnpaidAndNewCharge", 
                    "referenceId": 7
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDPin will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDPin", 
                    "referenceId": 8
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDWebSite will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDWebSite", 
                    "referenceId": 9
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A800", 
                    "alertMessage": "The property template DbaCDDStatementDate will be added to the object store.        ", 
                    "alertSeverity": "Informational", 
                    "artifactType": "PropertyTemplate", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "PropertyAdded", 
                    "propertySymbolicName": "DbaCDDStatementDate", 
                    "referenceId": 10
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A200", 
                    "alertMessage": "The class definition DbaJL126UtilityBill will be added to the object store.", 
                    "alertSeverity": "Informational", 
                    "artifactType": "Class", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "ClassAdded", 
                    "classSymbolicName": "DbaJL126UtilityBill", 
                    "referenceId": 11
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A200", 
                    "alertMessage": "The class definition DbaJL126Invoice will be added to the object store.", 
                    "alertSeverity": "Informational", 
                    "artifactType": "Class", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "ClassAdded", 
                    "classSymbolicName": "DbaJL126Invoice", 
                    "referenceId": 12
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A200", 
                    "alertMessage": "The class definition DbaJL126GasBill will be added to the object store.", 
                    "alertSeverity": "Informational", 
                    "artifactType": "Class", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "ClassAdded", 
                    "classSymbolicName": "DbaJL126GasBill", 
                    "referenceId": 13
                }, 
                {
                    "alertAction": "No action is needed.", 
                    "alertCode": "A200", 
                    "alertMessage": "The class definition DbaJL126INVOICE will be added to the object store.", 
                    "alertSeverity": "Informational", 
                    "artifactType": "Class", 
                    "changeSourceType": "ObjectStore", 
                    "changeType": "ClassAdded", 
                    "classSymbolicName": "DbaJL126INVOICE", 
                    "referenceId": 14
                }
            ], 
            "classes": [
                {
                    "referenceId": 11, 
                    "definitionFile": "CD_UtilityBill.json", 
                    "displayName": "Utility Bill", 
                    "symbolicName": "DbaJL126UtilityBill"
                }, 
                {
                    "referenceId": 12, 
                    "definitionFile": "CD_Invoice.json", 
                    "displayName": "Invoice", 
                    "symbolicName": "DbaJL126Invoice"
                }, 
                {
                    "referenceId": 13, 
                    "definitionFile": "CD_GasBill.json", 
                    "displayName": "Gas Bill", 
                    "symbolicName": "DbaJL126GasBill"
                }, 
                {
                    "referenceId": 14, 
                    "definitionFile": "CD_INVOICE.json", 
                    "displayName": "INVOICE", 
                    "symbolicName": "DbaJL126INVOICE"
                }
            ], 
            "propertyTemplates": [
                {
                    "referenceId": 0, 
                    "cardinality": "Single", 
                    "dataDefinitionFile": "proj://CDD/DD_cfe8c0fd-5df8-4a92-81fc-a75aa09997c7_CustomerNumber.json", 
                    "dataType": "String", 
                    "definitionName": "Customernumber", 
                    "symbolicName": "DbaCDDCustomernumber"
                }, 
                {
                    "referenceId": 1, 
                    "cardinality": "Single", 
                    "dataDefinitionFile": "proj://CDD/DD_a3e14089-d37f-4e97-9453-da46d35f0f1b_AccountNumber.json", 
                    "dataType": "String", 
                    "definitionName": "Accountnumber", 
                    "symbolicName": "DbaCDDAccountnumber"
                }, 
                {
                    "referenceId": 2, 
                    "cardinality": "Single", 
                    "dataDefinitionFile": "proj://CDD/DD_25f602c8-c310-48f1-8e8f-9ae9a892b3ab_DueDate.json", 
                    "dataType": "DateTime", 
                    "definitionName": "Duedate", 
                    "symbolicName": "DbaCDDDuedate"
                }, 
                {
                    "referenceId": 3, 
                    "cardinality": "Multi", 
                    "dataDefinitionFile": "proj://CDD/DD_8743e449-ca39-4229-874f-65df2590e932_Paymentreceived.json", 
                    "dataType": "Boolean", 
                    "definitionName": "Paymentreceived", 
                    "symbolicName": "DbaCDDPaymentreceived"
                }, 
                {
                    "referenceId": 4, 
                    "cardinality": "Single", 
                    "dataDefinitionFile": "proj://CDD/DD_35ad3772-179b-4490-8955-e3c8b7d36c18_Balance.json", 
                    "dataType": "Float", 
                    "definitionName": "Previousbalance", 
                    "symbolicName": "DbaCDDPreviousbalance"
                }, 
                {
                    "referenceId": 5, 
                    "cardinality": "Single", 
                    "dataDefinitionFile": "proj://CDD/DD_35ad3772-179b-4490-8955-e3c8b7d36c18_Balance.json", 
                    "dataType": "Float", 
                    "definitionName": "Totalamountdue", 
                    "symbolicName": "DbaCDDTotalamountdue"
                }, 
                {
                    "referenceId": 6, 
                    "cardinality": "Single", 
                    "dataDefinitionFile": "proj://CDD/DD_709aa21d-79fa-4a2c-b3ba-dea7cfdf01a5_Companynameandaddress.json", 
                    "dataType": "String", 
                    "definitionName": "Companynameandaddress", 
                    "symbolicName": "DbaCDDCompanynameandaddress"
                }, 
                {
                    "referenceId": 7, 
                    "cardinality": "Single", 
                    "dataDefinitionFile": "proj://CDD/DD_e3181ef1-02f8-402d-8e0c-8a3993ed86b9_unpaidandnewcharge.json", 
                    "dataType": "String", 
                    "definitionName": "UnpaidAndNewCharge", 
                    "symbolicName": "DbaCDDUnpaidAndNewCharge"
                }, 
                {
                    "referenceId": 8, 
                    "cardinality": "Single", 
                    "dataDefinitionFile": "proj://CDD/DD_f6e6c14e-5c04-43bf-b12d-da10a1dcfd42_Pin.json", 
                    "dataType": "String", 
                    "definitionName": "Pin", 
                    "symbolicName": "DbaCDDPin"
                }, 
                {
                    "referenceId": 9, 
                    "cardinality": "Single", 
                    "dataDefinitionFile": "proj://CDD/DD_d3418061-4b46-4a36-b0e6-61eb0ff26597_WebSite.json", 
                    "dataType": "String", 
                    "definitionName": "WebSite", 
                    "symbolicName": "DbaCDDWebSite"
                }, 
                {
                    "referenceId": 10, 
                    "cardinality": "Single", 
                    "dataDefinitionFile": "proj://CDD/DD_04a73b45-4c57-4a5b-859e-b83db33377a5_InvoiceDate.json", 
                    "dataType": "DateTime", 
                    "definitionName": "StatementDate", 
                    "symbolicName": "DbaCDDStatementDate"
                }
            ]
        }, 
	    "projectId": "{2A0DDE5C-4753-441E-B7AB-107E1D708898}", => the project id guid for the deployed project
	    "projectIdentifier": "PRJ999", => the project identifier for the deployed project
	    "projectVersionId": "{9D7B952E-8E1D-4E11-AD11-2D0395904E64}",  => the deployed project version guid.  For each version deployed of a project, a deployed project version is created.
	    "repositoryIdentifier": "OS3", ==> the Object store the project was deployed 
	    "snapshotName": "v1-2020-11-19-0105" ==> The version of the project deployed
	  },
	  "status": {
	    "code": 200,
	    "message": "Successfully deployed the project.",
	    "messageId": "FNRDD0003I"
	  }
	}
	
	
	Example of failed deployment in mid stream: 202 status
	{"data":{"branchName":"master","deploymentStatus":{"status":"Failed","type":"Redeploy"},"lastDeploymentRecordId":"{B0CC2C75-0000-C91B-97E0-AA7AA72CEEB8}","projectId":"{57D925F8-FA2C-4563-A958-ADF599460DE5}","projectIdentifier":"PRJ123","projectVersionId":"{F02D3B92-E938-4F6B-8099-743149472830}","repositoryIdentifier":"OS3","snapshotName":"v2-2020-10-13-1825"},"status":{"code":202,"message":"Team Server URL is not defined or invalid: root cause [For input string: \"w\"].","messageId":"FNRJC0511I"}}Return Code=202
	
	
	Example of failed on starting deployment: any status beside 200 and 202.
	If this script returns immediately with a status that is NOT 200 or 202, then there might be issues that need to be corrected before redeploy.  There is no need to call the next shell script as this is a global setup issue that needs to be fixed before one can deploy any project in this environment. This is an example of such error.
	
	
	{"errors":[{"action":"Ask your system administrator to check the value for the Document Processing Designer Repository API URL configured on the Content Project Deployment Service application server. ","errorId":508,"explanation":"The Document Processing Designer Repository API URL is not defined or is invalid."}],"status":{"code":500,"message":"The Document Processing Designer Repository API URL is not defined or is invalid: root cause no protocol: null/download/PRJ123/master?snapshot_name=v2-2020-10-13-1825","messageId":"FNRJC508"}}Return Code=500
	
	
	In this case, go to the CPDS server and ensure that the Content Designer Rest API (CDRA) url (REPO_SERVICE_URL environment variable) is configured correctly to allow the CPDS server to connect to the CDRA server. Consult the system.log on the CPDS server for more information. 
	
	
	
## Gets the Deployment of the Project Version

	cpds_getDeployedProjSnapshot.sh

The deployment of a project version may take a few minutes and the script provides return the project version id and lasted deployment record id	for the snapshot/version deployed.	This script can be run about 20 seconds after the deployment has started. The deployment record id, which is the latestDeploymentRecordId in the output, should be entered as input to the cpds_getDeploymentStatus.sh script, to get deployment status.  
	
	Example to run script using cpds.properties file:
	./cpds_getDeployedProjSnapshot.sh --file cpds.properties
	
	Documentation in the Knowledge Center will provide more information for the GET /v1/deployment/projects/{projectIdentifier}/branches/{branchName}/snapshots/{snapshotName} 
	
	  Sample Output
	./cpds_getDeployedProjSnapshot.sh --file cpds.properties
	Extracting fields from file cpds.properties ......
	Getting Runtime UMSToken ...
	Retrieving the deployed project information for OS3/PRJ999/v1-2020-11-19-0105 ...
	
	
	{"data":{"branchName":"master","caProjectDescriptor":"a1263c2a-778f-452a-b4ca-e55ef79dda9d","deploymentStatus":{"status":"Success","type":"Redeploy"},"lastDeploymentRecordId":"{50A5E775-0000-C314-82C6-1D87C9F34749}","projectId":"{9D7B952E-8E1D-4E11-AD11-2D0395904E64}","projectIdentifier":"PRJ999","projectVersionId":"{9D7B952E-8E1D-4E11-AD11-2D0395904E64}","repositoryIdentifier":"OS3","snapshotName":"v1-2020-11-19-0105"},"status":{"code":200,"message":"Successfully retrieved the information for the deployed project snapshot.","messageId":"FNRDD0009I"}}
	Return Code=200
	
	
	Explanation of output:
	{
	  "data": {
	    "branchName": "master",
	    "caProjectDescriptor": "a1263c2a-778f-452a-b4ca-e55ef79dda9d", =>ADP Project descriptor associated with the deployment project.
	    "deploymentStatus": {
	      "status": "Success", => Options are Success or Failed
	      "type": "Redeploy" => New, the first time the version is deployed or Redeploy, a subsequent deployment of the same version
	    },
	    "lastDeploymentRecordId": "{50A5E775-0000-C314-82C6-1D87C9F34749}", => the last deployment record can be used to find out information about the deployment. See  cpds_getDeploymentStatus.sh
	    "projectId": "{2A0DDE5C-4753-441E-B7AB-107E1D708898}", => the project id guid for the deployed project
	    "projectIdentifier": "PRJ999", => the project identifier for the deployed project
	    "projectVersionId": "{9D7B952E-8E1D-4E11-AD11-2D0395904E64}",  => the deployed project version guid.  For each version deployed of a project, a deployed project version is created.
	    "repositoryIdentifier": "OS3", ==> the Object store the project was deployed 
	    "snapshotName": "v1-2020-11-19-0105" ==> The version of the project deployed
	  },
	  "status": {
	    "code": 200,
	    "message": "Successfully retrieved the information for the deployed project snapshot.",
	    "messageId": "FNRDD0009I"
	  }
	}
	    
	Get Failed - Invalid input Sample:
	If the information is all correct, this error can result because of timing.  The deployment project and deployment project version may not have been created by the time the GET request for the project and version has been issued.  Wait a few seconds and try again.
	
	
	{
	  "status": {
	    "code": 400,
	    "messageId": "FNRDD1004E"",
	    "message": " Invalid input::java.lang.IllegalArgumentException null projectIdentifier = PRJ123, branchName = master, snapshotName = v4-2020-12-01-0051"
	  },
	  "errors": [
	    {
	      "errorId": 1004,
	      "explanation": "Invalid input ",
	      "action": "Reenter your information and try again"
	    }
	  ]
	}
	
	
	
## Returns the Deployment Record for the Project Version

	cpds_getDeploymentStatus.sh

The deployment of a project version may take a few minutes and the script provides the ability to monitor the progress of the deployment. Since the deployment can take a few minutes, this script can be used to poll the status of the deployment.
	
	Example to run script using the parameters from the cpds.properties and the required deploymentRecId (Use the lastDeploymentRecordId value retrieved from cpds_getDeploymentProjSnapshot.sh or cpds_deployProj.sh):
	./cpds_getDeploymentStatus.sh --file cpds.properties --deploymentRecId D00E6C75-0000-CB1E-9CA6-ED3F7DB2AE9B
	
	Documentation in the Knowledge Center will provide more information for the GET /v1/deploymentrecords/{deploymentRecordId}
	
	Sample Output
	./cpds_getDeploymentStatus.sh --file cpds.properties --deploymentRecId 50A5E775-0000-C314-82C6-1D87C9F34749
	Extracting fields from file cpds.properties ......
	Getting Runtime UMSToken ...
	Retrieving deploymentRecord ...
	
	
	{"data":{"branchName":"master","caProjectDescriptor":"a1263c2a-778f-452a-b4ca-e55ef79dda9d","contentAnalyzerStatus":{"machineLearningElapsedTime":5244,"newProject":false,"ontologyElapsedTime":32734,"projectCreationElapsedTime":0,"startTime":"2020-11-20T21:53:10.173Z"},"contentEngineStatus":{"existingClasses":2,"existingPropertyTemplates":5,"existingRoles":19,"newClasses":0,"newPropertyTemplates":0,"newRoles":0,"propertiesAndClassesElapsedTime":3244,"rolesElapsedTime":8308,"totalClasses":2,"totalPropertyTemplates":5,"totalRoles":19},"id":"50A5E775-0000-C314-82C6-1D87C9F34749","information":{"completionStatus":"Success","completionTime":"2020-11-20T21:53:48.151Z","existingTeams":12,"gitRepoRetrievalStatus":{"dataDefinitionsParsed":5,"gitElapsedTime":0},"newProject":false,"newTeams":0,"newVersion":false,"stages":["ReadSnapshot","Teams","ContentMetadata","Roles","ImportCAML","ImportCAOntology"],"startTime":"2020-11-20T21:52:54.544Z","teamsElapsedTime":2213,"totalElapsedTime":53607,"totalTeams":12},"projectId":"{2A0DDE5C-4753-441E-B7AB-107E1D708898}","projectIdentifier":"DM999","projectVersionId":"{9D7B952E-8E1D-4E11-AD11-2D0395904E64}","snapshotName":"v1-2020-11-19-0105"},"status":{"code":200,"message":"Successfully retrieved the deployment record.","messageId":"FNRDD0006I"}}
		Return Code=200
	
	
	
	
	Explanation of output:
	  
	  "data": {
	    "branchName": "master",
	    "caProjectDescriptor": "a1263c2a-778f-452a-b4ca-e55ef79dda9d", =>ADP Project descriptor associated with the deployment project.
	    "contentAnalyzerStatus": {
	      "machineLearningElapsedTime": 5244,  => The number of milliseconds to import the machine learning
	      "newProject": false, => True if a new ADP project descriptor was created  for the project or false if one existed and was updated during the deployment
	      "ontologyElapsedTime": 32734,=> The number of ms to import the ADP files and definitions 
	      "projectCreationElapsedTime": 0,
	      "startTime": "2020-11-20T21:53:10.173Z"
	    },
	    "contentEngineStatus": {
	      "existingClasses": 2,
	      "existingPropertyTemplates": 5,
	      "existingRoles": 19,
	      "newClasses": 0,
	      "newPropertyTemplates": 0,
	      "newRoles": 0,
	      "propertiesAndClassesElapsedTime": 3244,
	      "rolesElapsedTime": 8308,
	      "totalClasses": 2,
	      "totalPropertyTemplates": 5,
	      "totalRoles": 19
	    },
	    "id": "50A5E775-0000-C314-82C6-1D87C9F34749", => the deployment record id
	    "information": { => overall deployment information
	      "completionStatus": "Success", => Completion status of the deployment , Success or Failed 
	      "completionTime": "2020-11-20T21:53:48.151Z", => Time the deployment was completed
	      "existingTeams": 12,
	      "gitRepoRetrievalStatus": {
	        "dataDefinitionsParsed": 5,
	        "gitElapsedTime": 0
	      },
	      "newProject": false,
	      "newTeams": 0,
	      "newVersion": false,
	      "stages": [
	        "ReadSnapshot",
	        "Teams",
	        "ContentMetadata",
	        "Roles",
	        "ImportCAML",
	        "ImportCAOntology"
	      ],
	      "startTime": "2020-11-20T21:52:54.544Z",
	      "teamsElapsedTime": 2213,
	      "totalElapsedTime": 53607,
	      "totalTeams": 12
	    },
	    "projectId": "{2A0DDE5C-4753-441E-B7AB-107E1D708898}", => the project id guid for the deployed project
	    "projectIdentifier": "PRJ999", => the project identifier for the deployed project
	    "projectVersionId": "{9D7B952E-8E1D-4E11-AD11-2D0395904E64}",  => the deployed project version guid.  For each version deployed of a project, a deployed project version is created.
	    "snapshotName": "v1-2020-11-19-0105" ==> The version of the project deployed
	  },
	  "status": {
	    "code": 200,
	    "message": "Successfully retrieved the deployment record.",
	    "messageId": "FNRDD0006I"
	  }
	}  
	    
	Failed deployment sample response data:
	Deployment can fail. This is an example of the response returned by cpds_getDeploymentStatus.sh when a deployment fails.
	
	
	{"data": {"branchName": "master","contentAnalyzerStatus": {"machineLearningElapsedTime": 0,"newProject": false,"ontologyElapsedTime": 0,"projectCreationElapsedTime": 0,"startTime": "null"},"contentEngineStatus": {"existingClasses": 0,"existingPropertyTemplates": 0,"existingRoles": 0,"newClasses": 0,"newPropertyTemplates": 0,"newRoles": 0,"propertiesAndClassesElapsedTime": 0,"rolesElapsedTime": 0,"totalClasses": 0,"totalPropertyTemplates": 0,"totalRoles": 0},"id": "B0CC2C75-0000-C91B-97E0-AA7AA72CEEB8","information": {"completionStatus": "Failed","completionTime": "2020-10-15T15:06:56.539Z","currentStage": "Teams","existingTeams": 0,"gitRepoRetrievalStatus": {"dataDefinitionsParsed": 2,"gitElapsedTime": 0},"lastError": "Team Server URL is not defined or invalid","lastErrorId": "FNRJC0511I","newProject":false,"newTeams": 0,"newVersion": false,"stages": ["ReadSnapshot","Teams","ContentMetadata","Roles","ImportCAOntology","ImportCAML"],"startTime": "2020-10-15T15:06:50.325Z","teamsElapsedTime": 0,"totalElapsedTime": 6214,"totalTeams": 0},"projectId": "{57D925F8-FA2C-4563-A958-ADF599460DE5}","projectIdentifier": "PRJ123","projectVersionId": "{F02D3B92-E938-4F6B-8099-743149472830}","snapshotName": "v2-2020-10-13-1825"},"status": {"code": 200,"message": "Successfully retrieved the deployment record.","messageId": "FNRJC0006I"}}
	
	
	Note the following fields in data section report the deployment status:
		currentStage: stage where error occurs. List of ordered stages can be found in "stages" field. 
		completionStatus: "Failed"
		lastErrorId: an id assigned to a particular message. 
		lastError: a localized version of the error message. Additional data can be appended to help diagnose issue.
	
	
	In the above example, deployment failed during the second stage: "Teams". Check the configuration on CPDS server and ensure that Team server URL is reachable from CPDS. Then redeploy.
	
	
	In Progress Deployment:
	Deployment can be 'InProgress' for the case where deployment takes some time to complete. The response returned in this case is similar, except that 
		currentStage: set to stage that deployment is currently processing.
		completionStatus: "InProgress"
		lastErrorId and lastError are not set. 
		

## Object Store Initialization Status

	cpds_getOSConfigStatus.sh

Runs the Content Project Deployment Service REST Get initialization endpoint which verify Content Project Deployment is configuration has been run on the Content Platform Engine Object Store and it is at the appropriate software levels.  This script is run for initialization as well as upgrades.
	
	Example to run script using cpds.properties file:
	./cpds_getOSConfigStatus.sh --file cpds.properties
	
	Documentation in the Knowledge Center will provide more information for the GET /v1/repositories/{repositoryIdentifier}/initialization 
	
	Sample Output
	./cpds_getOSConfigStatus.sh --file cpds.properties
		Extracting fields from file cpds.properties ......
		Getting RunTime UMSToken ...
		{"data":{"contentAnalyzerHandlerVersion":"20.0.3.0-dev-180","contentAnalyzerMetadataVersion":"20.0.3.0.8","contentDeploymentMetadataVersion":"20.0.3.0.0","isInitialized":true,"umsRoleHandlerMetadataVersion":"20.0.3.0.1","umsRoleHandlerVersion":"20.0.3.0-dev-180"},"status":{"code":200,"message":"Successfully retrieved the initialization status of the repository.","messageId":"FNRDD0013I"}}
		Return Code=200
	
	
	Explanation of output:
	{
	  "data": {
	    "contentAnalyzerHandlerVersion": "21.0.2.0-dev-246",
	    "contentAnalyzerMetadataVersion": "21.0.2.0.10",
	    "contentDeploymentMetadataVersion": "21.0.3.0.0",
	    "isInitialized": true,   ==> the Object store is configured to the appropriate levels for Document Content Deployment
	    "umsRoleHandlerMetadataVersion": "20.0.3.0.1",
	    "umsRoleHandlerVersion": "21.0.2.0-dev-246"
	  },
	  "status": {
	    "code": 200,
	    "message": "Successfully retrieved the initialization status of the repository.",
	    "messageId": "FNRDD0013I"
	  }
	}
	
## Initialize Object Store

	cpds_configureOS.sh
	
Runs the Content Project Deployment Service REST POST initialization endpoint which Initializes or updates/upgrades the Content Platform Engine Object Store (OS).  If the cpds_getOSInitStat.sh was run and the OS returned false for isInitialized, the operations performed in this script would initialize the OS to the appropriate levels.
	
NOTE: The operator should perform initialization of the Object Store automatically when setting up a Automatic Document Processing (ADP) Object Store.
	
To execute the operation, the user must be a CPE administrator for the OS  and  member of the DocProcessingManagers Team on the Test/Staging/Prod (runtime) Environment. 

NOTE: For Development/Demo environments, the user must be a CPE administrator for the OS and a member of the DocProcessingManagers or DocProcessingAnalysis Team. 
	
	Example to run script using cpds.properties file:
	./cpds_configureOS.sh --file cpds.properties
	
	Documentation in the Knowledge Center will provide more information for the POST /v1/repositories/{repositoryIdentifier}/initialization 
	
	Sample Output
	 ./cpds_configureOS.sh --file cpds.properties
	Extracting fields from file cpds.properties ......
	Getting RunTime UMSToken ...
	{"data":{"elapsedTime":624,"initializationStatus":"Success"},"status":{"code":200,"message":"Successfully initialized the repository.","messageId":"FNRDD0002I"}}
	Return Code=200
	
	
	Explanation of output:
	{
	  "data": {
	    "elapsedTime": 624, => the number of ms to perform the initialization/upgrade
	    "initializationStatus": "Success" => the initialization/upgrade was successful.
	  },
	  "status": {
	    "code": 200,
	    "message": "Successfully initialized the repository.",
	    "messageId": "FNRDD0002I"
	  }
	}


## Precheck new Project Version to be deployed:
	
	cpds_projectPrecheck.sh
	
Runs the Content Project Deployment Service REST Get project precheck endpoint which performs a precheck without initiating a deployment or persisting any other changes to the design repository or the target object store.  
	
	Example to run script using cpds.properties file:
	./cpds_projectPrecheck.sh --file cpds.properties
	
	Documentation in the Knowledge Center will provide more information for the GET /deployment/projects/{projectIdentifier}/branches/{branchName}/snapshots/{snapshotName}/precheck
	
Alert Categories:
	
Alerts are separated into three categories (alertSeverity), below is a list of the types of alerts and examples of types of changes (changeType) which fall into each category. 
1. Incompatible - These are errors which will cause downstream deployment failures.
    1. Data type changes - The Content Designer will prevent these changes. (changeType: DataType)
    2. Cardinality (single/multi value) changes - Earlier Content Designer versions previous to 21.0.2 may have allowed these changes (changeType:Cardinality).
2. ExistingDataImpact - which are warnings which may impact in progress objects. In general changes that are more restrictive in nature and existing data could become invalid.
    1. A property is now required (isRequired). (changeType: IsValueRequired)
    2. The maximum length of a String to a more restrictive length.(changeType: MaximumLength)
    3. Minimum and maximum values of an integer or double value is more restrictive.(changeType: MinimumValue, MaximumValue)
    4. A new property is added so existing data would have no value. (changeType: PropertyAdded)
    5. Class retention settings changes. (changeType: RetentionChange).
3. Information - changes that are less restrictive in nature as well as behavior that CPDS performs silently.
    1. Automatically change isRequired to false for unmapped properties (changeType: PropertyRemoved)
    2. The maximum length of a String to a less restrictive length.(changeType: MaximumLength)
    3. Minimum and maximum values of an integer or double value is less restrictive.(changeType: MinimumValue, MaximumValue)
    4. Other changes that do not impact existing data (changeType: PropertyRemoved, ClassRemoved, ClassAdded).

Note: A project version with incompatible changes will fail when attempted to deploy.
	
The returned data is broken up into three sections.  The alerts, the classes and the propertyTemplates.  The alerts will list all the alerts and each alert will have a reference id.  The reference id corresponds to an artifact in the classes section or the property template section which will provide more information about the identity of the class, property, property template or sub property.
	
In the examples below, alerts with a changeSourceType of "DesignRepo" are only checked when a version is deployed the first time to any object store. It is this first deployment when additional information about the version is captured in the design repository and certain metdata is established. Alerts with a changeSourceType of "ObjectStore" are always checked against what is currently deployed to the object store, if deployed at all. 
	
Note:The information returned in the project precheck details returned are also returned for the deployment endpoint.
	 
		  "data": {

		    "alerts": [
		      // Same alerts as returned from precheck phase of deployment
		    ]

		    "propertyTemplates": [
		      // Same information returned from precheck phase of deployment
		    ]
		    "classes":[ 
		      // Same information returned from precheck phase of deployment
		      ]
		    }   
	
    Sample output:
	  ./cpds_projectPrecheck.sh --file cpds.properties
	  Extracting fields from file cpds.properties ......
	  Getting RunTime UMSToken ...
	
	{"data":{"alerts":[{"alertAction":"No action is needed.","alertCode":"A803","alertMessage":"The property template DbaCDDConsigneeAndShipper0003 is added to the design repository.        ","alertSeverity":"Informational","artifactType":"PropertyTemplate","changeSourceType":"DesignRepo","changeType":"PropertyAdded","propertySymbolicName":"DbaCDDConsigneeAndShipper0003","referenceId":0},{"alertAction":"Ensure that the application is not adversely affected by any missing data.","alertCode":"A403","alertMessage":"The property DbaCDDConsigneeAndShipper0003 will be added to the class DbaJL125BillofLading in this version of the project in the design repository.         ","alertSeverity":"ExistingDataImpact","artifactType":"Property","changeSourceType":"DesignRepo","changeType":"PropertyAdded","classSymbolicName":"DbaJL125BillofLading","propertySymbolicName":"DbaCDDConsigneeAndShipper0003","referenceId":2},{"alertAction":"No action is needed.","alertCode":"A800","alertMessage":"The property template DbaCDDConsigneeAndShipper0003 will be added to the object store.        ","alertSeverity":"Informational","artifactType":"PropertyTemplate","changeSourceType":"ObjectStore","changeType":"PropertyAdded","propertySymbolicName":"DbaCDDConsigneeAndShipper0003","referenceId":0},{"alertAction":"Ensure that the application is not adversely affected by any missing data.","alertCode":"A400","alertMessage":"The property DbaCDDConsigneeAndShipper0003 will be added to the class DbaJL125BillofLading in the object store. Existing instances of the class in the object store will not have values for this property.           ","alertSeverity":"ExistingDataImpact","artifactType":"Property","changeSourceType":"ObjectStore","changeType":"PropertyAdded","classSymbolicName":"DbaJL125BillofLading","propertySymbolicName":"DbaCDDConsigneeAndShipper0003","referenceId":2}],"classes":[{"referenceId":1,"classProperties":[{"referenceId":2,"cardinality":"Single","dataDefinitionFile":"proj://CDD/DD_d23e45a1-abec-4172-af6b-5ec65172e8f3_ConsigneeAndShipper.json","dataType":"Composite","definitionName":"ConsigneeAndShipper","displayName":"ConsigneeAndShipper","symbolicName":"DbaCDDConsigneeAndShipper0003"}],"definitionFile":"CD_BillofLading.json","displayName":"Bill of Lading","symbolicName":"DbaJL125BillofLading"}],"propertyTemplates":[{"referenceId":0,"cardinality":"Single","dataDefinitionFile":"proj://CDD/DD_d23e45a1-abec-4172-af6b-5ec65172e8f3_ConsigneeAndShipper.json","dataType":"Composite","definitionName":"ConsigneeAndShipper","symbolicName":"DbaCDDConsigneeAndShipper0003"}]},"status":{"code":200,"message":"Precheck of project version is successful.","messageId":"FNRDD0020I"}} 
	Return 200
	
	Explanation of output:
	
	{
	  "data": {
	    "alerts": [
	      {
	        "alertAction": "No action is needed.",  ==>What action can be taken for the alert
	        "alertCode": "A803", ==> the alert code.  All alerts start with the letter 'A'.
	        "alertMessage": "The property template DbaCDDConsigneeAndShipper0003 is added to the design repository.",  ==> Alert messages
	        "alertSeverity": "Informational", ==> Type of alert.  See Alert Categories
	        "artifactType": "PropertyTemplate", ==> Type of artifact for this alert.  Types are: Class, PropertyTemplate, Property or SubProperty
	        "changeSourceType": "DesignRepo",  ==>  The type of source where the new project version change is different.  Types are: DesignRepo (Design repository checks with prior version) and ObjectStore (checks with the object store)
	        "changeType": "PropertyAdded", =>  the type of change.  Change types: DataType, Cardinality, MinimumValue, MaximumValue,MaximumLength, IsValueRequired, PropertyAdded, PropertyRemoved, ClassAdded, ClassRemoved, RetentionChange.
	        "propertySymbolicName": "DbaCDDConsigneeAndShipper0003",  ==> the property if the alert is related to a property or property template.
	        "referenceId": 0   ==> The reference id will correspond to the reference id in an artifact defined in the classes or propertyTemplates section
	      },
	      {
	        "alertAction": "Ensure that the application is not adversely affected by any missing data.",
	        "alertCode": "A403",
	        "alertMessage": "The property DbaCDDConsigneeAndShipper0003 will be added to the class DbaJL125BillofLading in this version of the project in the design repository.         ",
	        "alertSeverity": "ExistingDataImpact",
	        "artifactType": "Property",
	        "changeSourceType": "DesignRepo",
	        "changeType": "PropertyAdded",
	        "classSymbolicName": "DbaJL125BillofLading",  ==> the class if the alert is related to a class or property within a class.
	        "propertySymbolicName": "DbaCDDConsigneeAndShipper0003",
	        "referenceId": 2
	      },
	      {
	        "alertAction": "No action is needed.",
	        "alertCode": "A800",
	        "alertMessage": "The property template DbaCDDConsigneeAndShipper0003 will be added to the object store.",
	        "alertSeverity": "Informational",
	        "artifactType": "PropertyTemplate",
	        "changeSourceType": "ObjectStore",
	        "changeType": "PropertyAdded",
	        "propertySymbolicName": "DbaCDDConsigneeAndShipper0003",
	        "referenceId": 0
	      },
	      {
	        "alertAction": "Ensure that the application is not adversely affected by any missing data.",
	        "alertCode": "A400",
	        "alertMessage": "The property DbaCDDConsigneeAndShipper0003 will be added to the class DbaJL125BillofLading in the object store. Existing instances of the class in the object store will not have values for this property. ",
	        "alertSeverity": "ExistingDataImpact",
	        "artifactType": "Property",
	        "changeSourceType": "ObjectStore",
	        "changeType": "PropertyAdded",
	        "classSymbolicName": "DbaJL125BillofLading",
	        "propertySymbolicName": "DbaCDDConsigneeAndShipper0003",
	        "referenceId": 2
	      }
	    ],
	    "classes": [
	      {
	        "referenceId": 1,
	        "classProperties": [
	          {
	            "referenceId": 2,  ==> The reference id can be mapped to alert reference ids for particular alerts.
	            "cardinality": "Single",
	            "dataDefinitionFile": "proj://CDD/DD_d23e45a1-abec-4172-af6b-5ec65172e8f3_ConsigneeAndShipper.json",
	            "dataType": "Composite",
	            "definitionName": "ConsigneeAndShipper",
	            "displayName": "ConsigneeAndShipper",
	            "symbolicName": "DbaCDDConsigneeAndShipper0003"
	          }
	        ],
	        "definitionFile": "CD_BillofLading.json",
	        "displayName": "Bill of Lading",
	        "symbolicName": "DbaJL125BillofLading"
	      }
	    ],
	    "propertyTemplates": [
	      {
	        "referenceId": 0,
	        "cardinality": "Single",
	        "dataDefinitionFile": "proj://CDD/DD_d23e45a1-abec-4172-af6b-5ec65172e8f3_ConsigneeAndShipper.json",
	        "dataType": "Composite",
	        "definitionName": "ConsigneeAndShipper",
	        "symbolicName": "DbaCDDConsigneeAndShipper0003"
	      }
	    ]
	  },
	  "status": {
	    "code": 200,
	    "message": "Precheck of project version is successful.",
	    "messageId": "FNRDD0020I"
	  }
	}:


## Precheck Content Project Deployment Service to verify connections and ADP Project database availability.

	cpds_systemPrecheck.sh

Runs the Content Project Deployment Service REST Get precheck endpoint which verifies that the user has privileges to deploy, the connections used for the Content Project Deployment Service are accessible, and reports the ADP Project database availability Content Project Deployment is configured.	

	Example to run script using cpds.properties file
	./cpds_systemPrecheck.sh --file cpds.properties	
	Documentation in the Knowledge Center will provide more information for the GET /v1/precheck	
	Sample Output:
	 ./cpds_systemPrecheck.sh --file cpds.properties
	Extracting fields from file cpds.properties .....
	Getting RunTime UMSToken ...
	{"data":		{"caConnectionState":"Success","caProjectsAvailable":1,"caProjectsDeleteState":1,"caProjectsUsed":1,"canDeploy":true,"cpeConnectionState":"Success","gitConnectionState":"Success","umsTeamConnectionState":"Success"},"status":{"code":200,"message":"Precheck of Content Project Deployment Service is successful.","messageId":"FNRDD0019I"}} 	Return Code=200	
    Explanation of output:	{
	{  "data": {{
	    "caConnectionState": "Success", => indicates the ADP connection tested was successful.
	    "caProjectsAvailable": 1, ==> number of available ADP Project databases used for new project creation. There needs to be at least one new project available for new projects being deployed.  In a development environment, two projects are required for each deployment.  One for the design and one for the deployment to an object store.
	    "caProjectsDeleteState": 1, ==> number of ADP projects that are in the deletion state.  The admin would be able to cleanup old projects.
	    "caProjectsUsed": 1, ==> number of ADP project used.
	    "canDeploy": true, ==> user has appropriate permissions to be able to deploy.
	    "cpeConnectionState": "Success", ==> indicates the Content Platform Engine connection test was successful.
	    "gitConnectionState": "Success",  ==> indicates the Content Design REST API connection test was successful.
	    "umsTeamConnectionState": "Success" ==> indicates the Teams Services connection test was successful.
	  },
	  "status": {
	    "code": 200
	    "message": "Precheck of Content Project Deployment Service is successful."
	    "messageId": "FNRDD0019I
	 }  
	}	
	Connection issue output sample::
	{	
	  "data": {{
	    "caConnectionError":
	      "action": "Ask your system administrator to review the error logs on the Content Project Deployment Service application server for more details."
	      "errorId": 516
	      "explanation": "Failed to connect to ADP.
	    },
	    "caConnectionState": "Failed", ==> ADP connection test failed.  See caConnectionError for error explanation, errorId and action to be taken. NOTE: Any failure for the connection states (ca, cpe, git, umsTeam) needs to be addresses before a project can be deployed and the Content Project Deployment Service is fully functional.
	    "canDeploy": true
	    "cpeConnectionState": "Success"
	    "gitConnectionState": "Success"
	    "umsTeamConnectionState": "Success
	  },
	  "status": {
	    "code": 200
	    "message": "Precheck of Content Project Deployment Service is successful."
	    "messageId": "FNRDD0019I
	 } 
	}}
	 
	
## Clean project deployed Content Platform Engine object store and deletes the associated ADP project
    
    cpds_cleanUpProject.sh
    
This script will clean up artifacts for the specified deployed project in Content Platform Engine repository and the associated ADP project.  The script prompt the user with a warning and requires the user to type in "YES" before executing the command to the Content Project Deployment Service.
    
NOTE: Clean project should only be used in the Development environment, it is NOT RECOMMENDED FOR RUNTIME ENVIRONMENT USE.  Do not run clean project on a project that is active.

Runs the Content Project Deployment Service REST Post projects cleanup endpoint which deletes artifacts associated to the deployed project id spscified.  This includes documents associated to the project classes, project related classes, roles, deployed project versions and deployed project and metadata from the Content Platform Engine and marks the ADP project as deleted.
	
	Example to run script using cpds.properties file without removing project related templates:
	  ./cpds_cleanUpProject.sh --file cpds.properties --deployedProjectId EB9B7698-8C1F-45C1-AD04-B7DA7A10E717
	
	 Example to run script with the option to clean the associated property templates
	   ./cpds_cleanUpProject.sh --file cpds.properties --deployedProjectId EB9B7698-8C1F-45C1-AD04-B7DA7A10E717 --cleanProjOptions " \"filterIncludeDocDetails\": true, \"timeOutInSecs\": 120, \"cleanPropertyTemplates\": true "
	
	Documentation in the Knowledge Center will provide more information for the POST /projects/{projectId}/cleanup
	
    Clean options description:
	    filterIncludeDocDetails - boolean value with default is false.  If true, returns the details of each deleted document so an additional section,  "documentDetails": [] will be returned with the id, name and className of the each document deleted.  
	    timeOutInSecs -	integer value with default to 10 seconds.  This value limits the number of seconds to clean up the documents of a project. If the time is too short, cleanup will not be complete. Default is 10 seconds
	    cleanPropertyTemplates -boolean value with default to false.  If true, removes the property templates associated with the project.  Note: Property templates may be share with other projects. Property templates can only be delete if NO other projects in that objectStore are using it, otherwise that property is skipped.
	    
      For the script, if no cleanProjOptions are specified the default used is " \"filterIncludeDocDetails\": false, \"timeOutInSecs\": 10, \"cleanPropertyTemplates\": false "   

	
    Sample to cleanup project without removing associated templates output:
	 ./cpds_cleanUpProject.sh --file cpds.properties --deployedProjectId 44542974-9241-4343-8949-AB24C56457ED
	  Extracting fields from file cpds.properties ......
	  Getting RunTime UMSToken ...

	  WARNING: Deletion of a project will remove most artifacts associated with a deployed project. 
	  These artifacts include:  documents, document classes, roles, ca project, project versions, project, 
	  project deployment records associated with a project. Unreferenced property templates can be deleted 
	  if passed in an override flag. In the dev env, operation is opened to users who are EITHER  members 
	  of Doc Processing Managers or Content Analysts. In  the runtime env, operation is opened only to users 
	  who are BOTH members of Doc Processing Mgrs and OS admins.
		
	  Type YES to proceed with deletion or return to exit ? YES
	  Cleaning project ...
	
	{"data":{"documentClassDetails":[{"id":"{4CEA3A2A-973A-4386-8041-75AAB05AC02C}","symbolicName":"DbaJL123UtilityBill"}],"documentsCountDetails":[{"className":"DbaJL123UtilityBill","count":0}],"elapsedTime":2,"id":"44542974-9241-4343-8949-AB24C56457ED","projectVersionDetails":[{"id":"{6D72B307-F901-4A55-9E12-4D9302E0FD4E}","snapshotName":"v34-2021-04-26-1833"}],"roleDetails":[{"displayName":"Document Viewers-JL123 Membership","id":"{70DF79DB-35A6-4041-875E-021978F49B21}","roleClassName":"DbaUMSTeamDynamicRole","umsTeamUUID":"a623f3c6-22c4-460d-abcc-8d60543ab89c"},{"displayName":"Document Viewers-JL123-UtilityBill Membership","id":"{9CFFD44D-1D8C-456C-8011-BDA95C8E152A}","roleClassName":"DbaUMSTeamDynamicRole","umsTeamUUID":"2d9d90a1-7e69-45a0-8788-ca1efb6779ce"},{"displayName":"Document Editors-JL123-UtilityBill Membership","id":"{4107EA60-8EEA-45AA-A948-0CE414186E3B}","roleClassName":"DbaUMSTeamDynamicRole","umsTeamUUID":"b1198b5c-55f1-49c7-8607-741bb2856781"},{"displayName":"Classification Workers-JL123 Membership","id":"{E97B288B-269D-4E95-BA8F-27C55A1C89B8}","roleClassName":"DbaUMSTeamDynamicRole","umsTeamUUID":"dbe5eed2-1509-4768-8f0d-9f8e964a3d07"},{"displayName":"Document Owners-JL123 Membership","id":"{3029DCB3-BA28-40FF-A160-C7C8B194C373}","roleClassName":"DbaUMSTeamDynamicRole","umsTeamUUID":"5c5f0ebc-32d1-4ee3-981a-c03b0fd89a67"},{"displayName":"Project Admins-JL123 Membership","id":"{B75AC624-B88F-419D-BCDF-1D5EECECBD70}","roleClassName":"DbaUMSTeamDynamicRole","umsTeamUUID":"fe6b1bf5-7ce4-4765-8e2a-e3dda6a1d839"},{"displayName":"Document Owners-JL123-UtilityBill Membership","id":"{A1D28D71-612B-449F-8765-ED3405C19377}","roleClassName":"DbaUMSTeamDynamicRole","umsTeamUUID":"435f7476-95f6-42c3-b295-9f1925631352"},{"displayName":"Document Editors-JL123 Membership","id":"{5E71E654-AC39-4FCA-96A2-7C00B9312878}","roleClassName":"DbaUMSTeamDynamicRole","umsTeamUUID":"9c72aab0-3ea7-4440-b124-83258c06b37d"},{"displayName":"Classification Workers-JL123","id":"{B556D3FA-8B6B-40FF-9AA0-C01FAFF0D2FE}","roleClassName":"DbaClassificationWorkersRole"},{"displayName":"Project Admins-JL123","id":"{A1C9578B-1FFC-48F0-9278-1B4A12EAB449}","roleClassName":"DbaProjectAdminsRole"},{"displayName":"Document Owners-JL123-UtilityBill","id":"{3EC70A5A-51B5-420D-8D7E-D32F2EC0CB1D}","roleClassName":"DbaProjectDocumentOwnersRole"},{"displayName":"Document Editors-JL123-UtilityBill","id":"{71BCB3A8-E294-4D62-BAC2-F35851A939DF}","roleClassName":"DbaProjectDocumentEditorsRole"},{"displayName":"Document Viewers-JL123-UtilityBill","id":"{FC86E9F0-70E2-4FE5-A53B-7CE70A7F11A4}","roleClassName":"DbaProjectDocumentViewersRole"}]},"status":{"code":200,"message":"Successfully cleaned up the project.","messageId":"FNRDD0004I"}}
	Return Code=200


	Explanation of output:
	{
	  "data": {
	    "documentClassDetails": [  ==> Classes deleted
	      {
	        "id": "{4CEA3A2A-973A-4386-8041-75AAB05AC02C}",
	        "symbolicName": "DbaJL123UtilityBill"
	      }
	    ],
	    "documentsCountDetails": [  ==> Documents deleted specified by for each Classes deleted
	      {
	        "className": "DbaJL123UtilityBill", ==> deleted class
	        "count": 0  ==> number of documents deleted which were instantiated from the deleted class
	      }
	    ],
	    "elapsedTime": 2,
	    "id": "44542974-9241-4343-8949-AB24C56457ED", ==> Deployed Project guid 
	    "projectVersionDetails": [   ==> Deployed project versions
	      {
	        "id": "{6D72B307-F901-4A55-9E12-4D9302E0FD4E}",
	        "snapshotName": "v34-2021-04-26-1833"
	      }
	    ],
	    "roleDetails": [  ==> Roles associated to the project which were deleted
	      {
	        "displayName": "Document Viewers-JL123 Membership", ==> Display Name
	        "id": "{70DF79DB-35A6-4041-875E-021978F49B21}", ==> Role guid
	        "roleClassName": "DbaUMSTeamDynamicRole",  ==> symbolic role name
	        "umsTeamUUID": "a623f3c6-22c4-460d-abcc-8d60543ab89c"==>Team guid associated with the role
	      },
	      {
	        "displayName": "Document Viewers-JL123-UtilityBill Membership",
	        "id": "{9CFFD44D-1D8C-456C-8011-BDA95C8E152A}",
	        "roleClassName": "DbaUMSTeamDynamicRole",
	        "umsTeamUUID": "2d9d90a1-7e69-45a0-8788-ca1efb6779ce"
	      },
	      {
	        "displayName": "Document Editors-JL123-UtilityBill Membership",
	        "id": "{4107EA60-8EEA-45AA-A948-0CE414186E3B}",
	        "roleClassName": "DbaUMSTeamDynamicRole",
	        "umsTeamUUID": "b1198b5c-55f1-49c7-8607-741bb2856781"
	      },
	      {
	        "displayName": "Classification Workers-JL123 Membership",
	        "id": "{E97B288B-269D-4E95-BA8F-27C55A1C89B8}",
	        "roleClassName": "DbaUMSTeamDynamicRole",
	        "umsTeamUUID": "dbe5eed2-1509-4768-8f0d-9f8e964a3d07"
	      },
	      {
	        "displayName": "Document Owners-JL123 Membership",
	        "id": "{3029DCB3-BA28-40FF-A160-C7C8B194C373}",
	        "roleClassName": "DbaUMSTeamDynamicRole",
	        "umsTeamUUID": "5c5f0ebc-32d1-4ee3-981a-c03b0fd89a67"
	      },
	      {
	        "displayName": "Project Admins-JL123 Membership",
	        "id": "{B75AC624-B88F-419D-BCDF-1D5EECECBD70}",
	        "roleClassName": "DbaUMSTeamDynamicRole",
	        "umsTeamUUID": "fe6b1bf5-7ce4-4765-8e2a-e3dda6a1d839"
	      },
	      {
	        "displayName": "Document Owners-JL123-UtilityBill Membership",
	        "id": "{A1D28D71-612B-449F-8765-ED3405C19377}",
	        "roleClassName": "DbaUMSTeamDynamicRole",
	        "umsTeamUUID": "435f7476-95f6-42c3-b295-9f1925631352"
	      },
	      {
	        "displayName": "Document Editors-JL123 Membership",
	        "id": "{5E71E654-AC39-4FCA-96A2-7C00B9312878}",
	        "roleClassName": "DbaUMSTeamDynamicRole",
	        "umsTeamUUID": "9c72aab0-3ea7-4440-b124-83258c06b37d"
	      },
	      {
	        "displayName": "Classification Workers-JL123",
	        "id": "{B556D3FA-8B6B-40FF-9AA0-C01FAFF0D2FE}",
	        "roleClassName": "DbaClassificationWorkersRole"
	      },
	      {
	        "displayName": "Project Admins-JL123",
	        "id": "{A1C9578B-1FFC-48F0-9278-1B4A12EAB449}",
	        "roleClassName": "DbaProjectAdminsRole"
	      },
	      {
	        "displayName": "Document Owners-JL123-UtilityBill",
	        "id": "{3EC70A5A-51B5-420D-8D7E-D32F2EC0CB1D}",
	        "roleClassName": "DbaProjectDocumentOwnersRole"
	      },
	      {
	        "displayName": "Document Editors-JL123-UtilityBill",
	        "id": "{71BCB3A8-E294-4D62-BAC2-F35851A939DF}",
	        "roleClassName": "DbaProjectDocumentEditorsRole"
	      },
	      {
	        "displayName": "Document Viewers-JL123-UtilityBill",
	        "id": "{FC86E9F0-70E2-4FE5-A53B-7CE70A7F11A4}",
	        "roleClassName": "DbaProjectDocumentViewersRole"
	      }
	    ]
	  },
	  "status": {
	    "code": 200,
	    "message": "Successfully cleaned up the project.",
	    "messageId": "FNRDD0004I"
	  }
	}
	

	
## Clean the Teams generated for a project
    
    cpds_cleanUpTeams.sh
    
Removes Teams associated with the project name specified from the Teams Server. The script prompt the user with a warning and requires the user to type in "YES" before executing the command to the Content Project Deployment Service.
    
NOTE: Cleanup of teams should only be used in the Development environment, it is NOT RECOMMENDED FOR RUNTIME ENVIRONMENT USE. If the project is deployed to multiple Content Platform Engine repositories, the teams are shared. Teams cleanup will remove all teams associated to the project name, making other deployments of the same project unusable.  Re-deploying the project will recreate the teams. However, you must add all the users to teams which were previously deleted.
    
Runs the Content Project Deployment Service REST Post project teamscleanup endpoint which cleans up teams related to the project name.  
	
	Example to run script using cpds.properties file:
	./cpds_cleanUpTeams.sh --file cpds.properties 
	
	Example to run script using cpds.properties file overriding project name:
	./cpds_cleanUpTeams.sh --file cpds.properties --projectName PROJ1
	
	Documentation in the Knowledge Center will provide more information for the POST /projects/{projectIdentifier}/teamscleanup
	
	
	 By default, the teams will be deleted for the project name.
      Project related teams (one per project):
		Project Admins-<projectName>
		Classification Workers-<projectName>
		Business Owners-<projectName>
		Document Owners-<projectName>
		Document Editors-<projectName>
		 Document Viewers-<projectName>
	  Project class related teams (one per class for the project):
		Document Owners-<projectName>-<documentTypeName>
		Document Editors-<projectName>-<documentTypeName>
		Document Viewers-<projectName>-<documentTypeName>
 
	Optionally, a list of all the teams can be returned for review before the deletion by using the --cleanTeamsOptions "\"cleanTeams\": false"
	
	
    Sample output:
	  ./cpds_cleanUpTeams.sh --file cpds.properties
	  Extracting fields from file cpds.properties ......
	  Getting RunTime UMSToken ...
	  "cleanTeams": true
	
	   WARNING: Deletion of project-related teams will remove all teams associated to the project. 
	   If the project is deployed in one or more repositories using these same teams, the project in 
	   these environments will no longer function.
	   
	   Type YES to proceed with deletion or return to exit ? YES
	
     {"data":{"teamDetails":[{"displayName":"Business Owners-JL123","distinguishedName":"cn=businessowners,project=jl123,scope=project,application=capture","uuid":"724735a2-cea3-4c5f-ab39-f27bfacd9e1c"},{"displayName":"Classification Workers-JL123","distinguishedName":"cn=classificationworkers,project=jl123,scope=project,application=capture","uuid":"dbe5eed2-1509-4768-8f0d-9f8e964a3d07"},{"displayName":"Document Editors-JL123","distinguishedName":"cn=documenteditors,project=jl123,scope=project,application=capture","uuid":"9c72aab0-3ea7-4440-b124-83258c06b37d"},{"displayName":"Document Owners-JL123","distinguishedName":"cn=documentowners,project=jl123,scope=project,application=capture","uuid":"5c5f0ebc-32d1-4ee3-981a-c03b0fd89a67"},{"displayName":"Document Viewers-JL123","distinguishedName":"cn=documentviewers,project=jl123,scope=project,application=capture","uuid":"a623f3c6-22c4-460d-abcc-8d60543ab89c"},{"displayName":"ProjectAdmins-JL123","distinguishedName":"cn=projectadmins,project=jl123,scope=project,application=capture","uuid":"fe6b1bf5-7ce4-4765-8e2a-e3dda6a1d839"},{"displayName":"Document Editors-JL123-BillofLading","distinguishedName":"cn=documenteditors,class=billoflading,project=jl123,scope=projectclass,application=capture","uuid":"e18ee7f9-7f25-4ac0-8435-6923762de966"},{"displayName":"Document Editors-JL123-UtilityBill","distinguishedName":"cn=documenteditors,class=utilitybill,project=jl123,scope=projectclass,application=capture","uuid":"b1198b5c-55f1-49c7-8607-741bb2856781"},{"displayName":"Document Owners-JL123-BillofLading","distinguishedName":"cn=documentowners,class=billoflading,project=jl123,scope=projectclass,application=capture","uuid":"3342f424-929e-433c-be0a-0a339d95d1aa"},{"displayName":"Document Owners-JL123-UtilityBill","distinguishedName":"cn=documentowners,class=utilitybill,project=jl123,scope=projectclass,application=capture","uuid":"435f7476-95f6-42c3-b295-9f1925631352"},{"displayName":"Document Viewers-JL123-BillofLading","distinguishedName":"cn=documentviewers,class=billoflading,project=jl123,scope=projectclass,application=capture","uuid":"b8602e0d-a3f6-466b-9598-217c88040e11"},{"displayName":"Document Viewers-JL123-EnergyBill","distinguishedName":"cn=documentviewers,class=energybill,project=jl123,scope=projectclass,application=capture","uuid":"d075177c-c47e-4b5d-90de-97a81bf87646"},{"displayName":"Document Viewers-JL123-Invoice","distinguishedName":"cn=documentviewers,class=invoice,project=jl123,scope=projectclass,application=capture","uuid":"b84af045-bac5-40f2-bfcc-4eda5ec262bf"},{"displayName":"Document Viewers-JL123-UtilityBill","distinguishedName":"cn=documentviewers,class=utilitybill,project=jl123,scope=projectclass,application=capture","uuid":"2d9d90a1-7e69-45a0-8788-ca1efb6779ce"}]},"status":{"code":200,"message":"Retrieved the teams that are associated with the Project Identifier.","messageId":"FNRDD0018I"}}
	Return Code=200

	Explanation of output:
	{
	  "data": {
	    "teamDetails": [ <== array of teams identified by the project name which have been deleted from the Teams Server
	      {
	        "displayName": "Business Owners-JL123",  ==> display name for the Team deleted.
	        "distinguishedName": "cn=businessowners,project=jl123,scope=project,application=capture",  ==> Team Distinguished Name 
	        "uuid": "724735a2-cea3-4c5f-ab39-f27bfacd9e1c"  ==> Team guid for the deleted team
	      },
	      {
	        "displayName": "Classification Workers-JL123",
	        "distinguishedName": "cn=classificationworkers,project=jl123,scope=project,application=capture",
	        "uuid": "dbe5eed2-1509-4768-8f0d-9f8e964a3d07"
	      },
	      {
	        "displayName": "Document Editors-JL123",
	        "distinguishedName": "cn=documenteditors,project=jl123,scope=project,application=capture",
	        "uuid": "9c72aab0-3ea7-4440-b124-83258c06b37d"
	      },
	      {
	        "displayName": "Document Owners-JL123",
	        "distinguishedName": "cn=documentowners,project=jl123,scope=project,application=capture",
	        "uuid": "5c5f0ebc-32d1-4ee3-981a-c03b0fd89a67"
	      },
	      {
	        "displayName": "Document Viewers-JL123",
	        "distinguishedName": "cn=documentviewers,project=jl123,scope=project,application=capture",
	        "uuid": "a623f3c6-22c4-460d-abcc-8d60543ab89c"
	      },
	      {
	        "displayName": "ProjectAdmins-JL123",
	        "distinguishedName": "cn=projectadmins,project=jl123,scope=project,application=capture",
	        "uuid": "fe6b1bf5-7ce4-4765-8e2a-e3dda6a1d839"
	      },
	      {
	        "displayName": "Document Editors-JL123-BillofLading",
	        "distinguishedName": "cn=documenteditors,class=billoflading,project=jl123,scope=projectclass,application=capture",
	        "uuid": "e18ee7f9-7f25-4ac0-8435-6923762de966"
	      },
	      {
	        "displayName": "Document Editors-JL123-UtilityBill",
	        "distinguishedName": "cn=documenteditors,class=utilitybill,project=jl123,scope=projectclass,application=capture",
	        "uuid": "b1198b5c-55f1-49c7-8607-741bb2856781"
	      },
	      {
	        "displayName": "Document Owners-JL123-BillofLading",
	        "distinguishedName": "cn=documentowners,class=billoflading,project=jl123,scope=projectclass,application=capture",
	        "uuid": "3342f424-929e-433c-be0a-0a339d95d1aa"
	      },
	      {
	        "displayName": "Document Owners-JL123-UtilityBill",
	        "distinguishedName": "cn=documentowners,class=utilitybill,project=jl123,scope=projectclass,application=capture",
	        "uuid": "435f7476-95f6-42c3-b295-9f1925631352"
	      },
	      {
	        "displayName": "Document Viewers-JL123-BillofLading",
	        "distinguishedName": "cn=documentviewers,class=billoflading,project=jl123,scope=projectclass,application=capture",
	        "uuid": "b8602e0d-a3f6-466b-9598-217c88040e11"
	      },
	      {
	        "displayName": "Document Viewers-JL123-EnergyBill",
	        "distinguishedName": "cn=documentviewers,class=energybill,project=jl123,scope=projectclass,application=capture",
	        "uuid": "d075177c-c47e-4b5d-90de-97a81bf87646"
	      },
	      {
	        "displayName": "Document Viewers-JL123-Invoice",
	        "distinguishedName": "cn=documentviewers,class=invoice,project=jl123,scope=projectclass,application=capture",
	        "uuid": "b84af045-bac5-40f2-bfcc-4eda5ec262bf"
	      },
	      {
	        "displayName": "Document Viewers-JL123-UtilityBill",
	        "distinguishedName": "cn=documentviewers,class=utilitybill,project=jl123,scope=projectclass,application=capture",
	        "uuid": "2d9d90a1-7e69-45a0-8788-ca1efb6779ce"
	      }
	    ]
	  },
	  "status": {
	    "code": 200,
	    "message": "Retrieved the teams that are associated with the Project Identifier.",
	    "messageId": "FNRDD0018I"
	  }
	}


