 IBM Aria Content Project Deployment Service Scripts Readme
© Copyright IBM Corporation 2020-2021

Readme file for: IBM® Aria Content Project Deployment Service Scripts
Update name: 
Publication date: 9 February 2021
Last modified date: 9 February 2021

Project Deployment Scripts

	cpds_getOSInitStat.sh
	cpds_initOS.sh
	cpds_deployProj.sh
	cpds_getDeployedProjSnapshot.sh
	cpds_getDeploymentRec.sh
	
	helper_getUMSToken.sh

Project Deployment properties sample file

	cpds.properties.sample
	
General Overview

     The Project Deployment Scripts provide unix shell script samples using the Content Project Deployment Service REST API.
     The scripts provided give samples on how to deploy a project version to a Test/Staging/Production environment, monitor the deployment,
     and check the Object Store to verify the Content Project Deployment Initialization has been performed.
             
     The cpds.properties.sample are a list of properties which can be input used as input in to the scripts.  Copy the sample, for example to cpds.properties, and insert your values into the file.
     
     The five main scripts are:
     	cpds_getOSInitStat.sh - checks the initialization status on the Object Store
     	cpds_initOS.sh - initializes or updates/upgrades the Content Platform Engine Object Store to current level. This should be run if the cpds_getOSInitStat.sh script returns a response which the "isInitialized" value is false.
	    cpds_deployProj.sh - deploys a content project deployment project version
	    cpds_getDeployedProjSnapshot.sh - returns the project version information for the deployed snapshot/version
		cpds_getDeploymentStatus.sh - returns the deployment record for the deployment project version
	    
	 helper_getUMSToken.sh is the UMS authentication script used by all the scripts to login to the ums server and provider a bearer token. 
	 
	 NOTE:  The sample scripts all use curl command with "-k" value as an example.   This option allows curl to perform "insecure" SSL connections. This curl option should be replaced with a more secure option like --cacert <cerificate file> using certificate file with one or more PEM certificates to create more secure HTTPS connections. See curl for other curl options for using secure connections and certificates.
	    

Deploying a Project Version

	cpds_deployProj.sh 
	This script is intended for the Test/Staging/Production environment. A Document Processing Designer project and version from the 
	Development Environment is deployed into the Test/Staging/Production (runtime) environment. The project is deployed to the Content Platform Engine Object Store and associated Content Analyzer runtime environment. 
	
	 NOTE: This scripts requires both runtime UMS input and development UMS input. The user must be a member of the Doc Processing Manager team for the runtime and either a Doc Processing Manager or a Doc Processing Analyst for the development environment.
	 
	 NOTE: Prior to running the scripts the configuration for a runtime object store requires the CDPS container environment variables ADP_DEPLOYMENT_ENV = RUNTIME and REPO_SERVICE_URL to point to the Content Designer Rest API (CDRA) url on the development environment.  The SSL certificates should have been imported as secrets into your runtime CDPS environment
		
	
	Example to run script using cdps.properties file:
	./cpds_deployProj.sh --file cdps.properties 
	Example to run script using cdps.properties file but overriding file runtimeObjectStore value with a different Object store name
	./cpds_deployProj.sh --file cdps.properties --runtimeObjectStore OS2
	
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
	{"data":{"branchName":"master","caProjectDescriptor":"a1263c2a-778f-452a-b4ca-e55ef79dda9d","deploymentStatus":{"status":"Success","type":"Redeploy"},"lastDeploymentRecordId":"{50A5E775-0000-C314-82C6-1D87C9F34749}","projectId":"{2A0DDE5C-4753-441E-B7AB-107E1D708898}","projectIdentifier":"PRJ999","projectVersionId":"{9D7B952E-8E1D-4E11-AD11-2D0395904E64}","repositoryIdentifier":"OS3","snapshotName":"v1-2020-11-19-0105"},"status":{"code":200,"message":"Successfully deployed the project.","messageId":"FNRDD0003I"}}
	Return Code=200
	
	
	Explanation of output:
	{
	  "data": {
	    "branchName": "master",
	    "caProjectDescriptor": "a1263c2a-778f-452a-b4ca-e55ef79dda9d", =>Content Analyzer Project descriptor associated with the deployment project.
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
	    "message": "Successfully deployed the project.",
	    "messageId": "FNRDD0003I"
	  }
	}
	
	
	Example of failed deployment in mid stream: 202 status
	{"data":{"branchName":"master","deploymentStatus":{"status":"Failed","type":"Redeploy"},"lastDeploymentRecordId":"{B0CC2C75-0000-C91B-97E0-AA7AA72CEEB8}","projectId":"{57D925F8-FA2C-4563-A958-ADF599460DE5}","projectIdentifier":"PRJ123","projectVersionId":"{F02D3B92-E938-4F6B-8099-743149472830}","repositoryIdentifier":"OS3","snapshotName":"v2-2020-10-13-1825"},"status":{"code":202,"message":"UMS Team Server URL is not defined or invalid: root cause [For input string: \"w\"].","messageId":"FNRJC0511I"}}Return Code=202
	
	
	Example of failed on starting deployment: any status beside 200 and 202.
	If this script returns immediately with a status that is NOT 200 or 202, then there might be issues that need to be corrected before redeploy.  There is no need to call the next shell script as this is a global setup issue that needs to be fixed before one can deploy any project in this environment. This is an example of such error.
	
	
	{"errors":[{"action":"Ask your system administrator to check the value for the Document Processing Designer Repository API URL configured on the Content Project Deployment Service application server. ","errorId":508,"explanation":"The Document Processing Designer Repository API URL is not defined or is invalid."}],"status":{"code":500,"message":"The Document Processing Designer Repository API URL is not defined or is invalid: root cause no protocol: null/download/PRJ123/master?snapshot_name=v2-2020-10-13-1825","messageId":"FNRJC508"}}Return Code=500
	
	
	In this case, go to the CPDS server and ensure that the Content Designer Rest API (CDRA) url (REPO_SERVICE_URL environment variable) is configured correctly to allow the CPDS server to connect to the CDRA server. Consult the system.log on the CPDS server for more information. 
	
	
	
Gets the Deployment of the Project Version

	cpds_getDeployedProjSnapshot.sh
	The deployment of a project version may take a few minutes and the script provides return the project version id and lasted deployment record id	for the snapshot/version deployed.	This script can be run about 20 seconds after the deployment has started. The deployment record id, which is the latestDeploymentRecordId in the output, should be entered as input to the cpds_getDeploymentStatus.sh script, to get deployment status.  
	
	Example to run script using cdps.properties file:
	./cpds_getDeployedProjSnapshot.sh --file cdps.properties
	
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
	    "caProjectDescriptor": "a1263c2a-778f-452a-b4ca-e55ef79dda9d", =>Content Analyzer Project descriptor associated with the deployment project.
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
	
	
	
Returns the Deployment Record for the Project Version

	cpds_getDeploymentStatus.sh
	The deployment of a project version may take a few minutes and the script provides the ability to monitor the progress of the deployment. Since the deployment can take a few minutes, this script can be used to poll the status of the deployment.
	
	Example to run script using the parameters from the cpds.properties and the required deploymentRecId (Use the lastDeploymentRecordId value retrieved from cpds_getDeploymentProjSnapshot.sh or cpds_deployProj.sh):
	./cpds_getDeploymentStatus.sh --file cdps.properties --deploymentRecId D00E6C75-0000-CB1E-9CA6-ED3F7DB2AE9B
	
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
	    "caProjectDescriptor": "a1263c2a-778f-452a-b4ca-e55ef79dda9d", =>Content Analyzer Project descriptor associated with the deployment project.
	    "contentAnalyzerStatus": {
	      "machineLearningElapsedTime": 5244,  => The number of milliseconds to import the machine learning
	      "newProject": false, => True if a new content analyzer project descriptor was created  for the project or false if one existed and was updated during the deployment
	      "ontologyElapsedTime": 32734,=> The number of ms to import the content analyzer files and definitions 
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
	
	
	{"data": {"branchName": "master","contentAnalyzerStatus": {"machineLearningElapsedTime": 0,"newProject": false,"ontologyElapsedTime": 0,"projectCreationElapsedTime": 0,"startTime": "null"},"contentEngineStatus": {"existingClasses": 0,"existingPropertyTemplates": 0,"existingRoles": 0,"newClasses": 0,"newPropertyTemplates": 0,"newRoles": 0,"propertiesAndClassesElapsedTime": 0,"rolesElapsedTime": 0,"totalClasses": 0,"totalPropertyTemplates": 0,"totalRoles": 0},"id": "B0CC2C75-0000-C91B-97E0-AA7AA72CEEB8","information": {"completionStatus": "Failed","completionTime": "2020-10-15T15:06:56.539Z","currentStage": "Teams","existingTeams": 0,"gitRepoRetrievalStatus": {"dataDefinitionsParsed": 2,"gitElapsedTime": 0},"lastError": "UMS Team Server URL is not defined or invalid","lastErrorId": "FNRJC0511I","newProject":false,"newTeams": 0,"newVersion": false,"stages": ["ReadSnapshot","Teams","ContentMetadata","Roles","ImportCAOntology","ImportCAML"],"startTime": "2020-10-15T15:06:50.325Z","teamsElapsedTime": 0,"totalElapsedTime": 6214,"totalTeams": 0},"projectId": "{57D925F8-FA2C-4563-A958-ADF599460DE5}","projectIdentifier": "PRJ123","projectVersionId": "{F02D3B92-E938-4F6B-8099-743149472830}","snapshotName": "v2-2020-10-13-1825"},"status": {"code": 200,"message": "Successfully retrieved the deployment record.","messageId": "FNRJC0006I"}}
	
	
	Note the following fields in data section report the deployment status:
		currentStage: stage where error occurs. List of ordered stages can be found in "stages" field. 
		completionStatus: "Failed"
		lastErrorId: an id assigned to a particular message. 
		lastError: a localized version of the error message. Additional data can be appended to help diagnose issue.
	
	
	In the above example, deployment failed during the second stage: "Teams". Check the configuration on CPDS server and ensure that UMS Team server URL is reachable from CPDS. Then redeploy.
	
	
	In Progress Deployment:
	Deployment can be 'InProgress' for the case where deployment takes some time to complete. The response returned in this case is similar, except that 
		currentStage: set to stage that deployment is currently processing.
		completionStatus: "InProgress"
		lastErrorId and lastError are not set. 
		

Object Store Initialization Status

	cpds_getOSInitStat.sh
	Runs the Content Project Deployment Service REST Get initialization endpoint which verify Content Project Deployment Initialization 
	has been run on the Content Platform Engine Object Store.
	
	Example to run script using cdps.properties file:
	./cpds_getOSInitStat.sh --file cpds.properties
	
	Documentation in the Knowledge Center will provide more information for the GET /v1/repositories/{repositoryIdentifier}/initialization 
	
	Sample Output
	./cpds_getOSInitStat.sh --file cpds.properties
		Extracting fields from file cpds.properties ......
		Getting RunTime UMSToken ...
		{"data":{"contentAnalyzerHandlerVersion":"20.0.3.0-dev-180","contentAnalyzerMetadataVersion":"20.0.3.0.8","contentDeploymentMetadataVersion":"20.0.3.0.0","isInitialized":true,"umsRoleHandlerMetadataVersion":"20.0.3.0.1","umsRoleHandlerVersion":"20.0.3.0-dev-180"},"status":{"code":200,"message":"Successfully retrieved the initialization status of the repository.","messageId":"FNRDD0013I"}}
		Return Code=200
	
	
	Explanation of output:
	{
	  "data": {
	    "contentAnalyzerHandlerVersion": "20.0.3.0-dev-180",
	    "contentAnalyzerMetadataVersion": "20.0.3.0.8",
	    "contentDeploymentMetadataVersion": "20.0.3.0.0",
	    "isInitialized": true,   ==> the Object store is initialized for Document Content Deployment
	    "umsRoleHandlerMetadataVersion": "20.0.3.0.1",
	    "umsRoleHandlerVersion": "20.0.3.0-dev-180"
	  },
	  "status": {
	    "code": 200,
	    "message": "Successfully retrieved the initialization status of the repository.",
	    "messageId": "FNRDD0013I"
	  }
	}
	
Initialize Object Store

	cpds_initOS.sh
	
	Runs the Content Project Deployment Service REST POST initialization endpoint which Initializes or updates/upgrades the 
	the Content Platform Engine Object Store (OS).  If the cpds_getOSInitStat.sh was run and the OS returned false for isInitialized,
	the operations performed in this script would initialize the OS to the appropriate levels.
	
	NOTE: The operator should perform initialization of the Object Store automatically when setting up a Automatic Document Processing (ADP) Object Store.
	
	To execute the operation, the user must be a CPE administrator for the OS  and  member of the DocProcessingManagers UMS Team on the Test/Staging/Prod (runtime) Environment. 
	NOTE: For Development/Demo environments, the user must be a CPE administrator for the OS and a member of the DocProcessingManagers or DocProcessingAnalysis UMS Team. 
	
	Example to run script using cdps.properties file:
	./cpds_initOS.sh --file cpds.properties
	
	Documentation in the Knowledge Center will provide more information for the POST /v1/repositories/{repositoryIdentifier}/initialization 
	
	Sample Output
	 ./cpds_initOS.sh --file cpds.properties
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
	
	
