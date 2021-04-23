#!/bin/bash

# cpds_getDeployedProjSnapshot.sh: script to extract the deployed project version information from the deployment using the project name and snapshot version used to deploy.
#                                  The lastDeploymentRecordId returned can be used to monitor the deployment by using the cpds_getDeploymentStatus.sh
# 
## Runtime parameters required which are included in the cpds.properies sample file:
#    runtimeUmsUrl, runtimeUmsClientId, runtimeUmsClientSecret, runtimeUser, runtimePwd=password,runtimeCpdsUrl,runtimeObjectStore
#
# Development parameters required for the project name and version (parameters also available listed in default cpds.properties.sample files)
#    projectName: The Document Project Designer project name
#    snapshotVersion: The Document Project Designer version name
#
# 
#Example to run script:
#	./cpds_getDeployedProjSnapshot.sh --file cdps.properties
#   
#      
#
# this script will call lower script, passed in CPDS host/port, CE bearer token, project GUID, CE Object Store
#     tied to the 'run-time' env..
# One can make similar script for 'dev' env.
#


#uncomment for debugging
#set -x


######## Constants 
# Provide defaults that can be override by passed in params
#runtimeUmsUrl=https://ums-sso.adp.ibm.com
#runtimeUmsClientId=XXXXXXXX
#runtimeUmsClientSecret=XXXXXXXXX
#runtimeUser=Admin
#runtimePwd=password

#runtimeCpdsUrl=https://cpds.adp.ibm.com
#projectName=PRJ123
#snapshotVersion=v2-2020-10-13-1825
#runtimeObjectStore=OS1



######### Functions
f_usage()
{
    echo "NAME"
    echo "  $0 -- retrieve the deployed Project version. "
    echo ""
    echo "USAGE: $0  "
    echo "    [--runtimeUmsUrl url]  [--runtimeClientId id] [--runtimeClientSecret secret]  [ --runtimeUser user]     [--runtimePwd pwd]"
    echo "    [--runtimeCpdsUrl     UrlToConnectToCPDS] "
    echo "    [--projectName        ProjectName]"
    echo "    [--snapshotVersion    ProjectSnapshotVersion]"
    echo "    [--runtimeObjectStore CPE ObjectStore symbolic name]]"
    echo "    [--file               inputFile to store Key/Value pair for arguments]"
    echo "    [-h]"
    echo ""
    echo "The order of arguments passed in can be used to override, given preference to the last one. "
    echo "For example, if you want to extract most arguments from a file except for the runtimeObjectStore,"
    echo "you can pass --file <file> --runtimeObjectStore <os>"
    echo ""
    echo "EXAMPLE:"
    echo "$0 "
    echo "   --runtimeUmsUrl                   https://ums-sso.adp.ibm.com"
    echo "   --runtimeUmsClientId              DfPtsBMyLOjYVPqChIKL"
    echo "   --runtimeUmsClientSecret          Dwvj3D0tp4HaugA2s22a"
    echo "   --runtimeUser                     deploy_user"
    echo "   --runtimePwd                      deploy_pwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --projectName                     GIT_PROJECT_23"
    echo "   --snapshotVersion                 v2-2020-10-13-1825"
    echo "   --runtimeObjectStore              OS1"
    echo ""
    echo "$0 "
    echo "   --file filename"
}

f_extractFieldsFromFile()
{
	echo 'Extracting fields from file' $INPUT_FILE ......
        export $(grep -v '^#' ${INPUT_FILE} | tr -d '"' | xargs)

	for t in "${allParamsKeys[@]}"
	do
		val=$(eval echo \${$t})
		#echo $t =  $val
	done

}

####### Main

#parse arg
while [ "$1" != "" ]; do
    case $1 in
        --runtimeUmsUrl)        shift
                                runtimeUmsUrl="$1"
                                ;;
       --runtimeUmsClientId)   shift
								runtimeUmsClientId="$1"
                                ;;
        --runtimeUmsClientSecret)   shift
								runtimeUmsClientSecret="$1"
                                ;;  
        --runtimeUser)    		shift
								runtimeUser="$1"
                                ;;
        --runtimePwd)        	shift
								runtimePwd="$1"
                                ;;
        --runtimeCpdsUrl)       shift
                                runtimeCpdsUrl="$1"
                                ;;
        --projectName)         	shift
								projectName="$1"
                                ;;
        --snapshotVersion)    	shift
								snapshotVersion="$1"
                                ;;
        --runtimeObjectStore)   shift
								runtimeObjectStore="$1"
                                ;;
        --file)                 shift
								INPUT_FILE="$1"
								f_extractFieldsFromFile
								;;
        -h)                     f_usage
                                exit 1
    esac
    shift
done




# Extract Bearer token to runtime env to connect to GIT
CMD="./helper_getUMSToken.sh --url ${runtimeUmsUrl} --id ${runtimeUmsClientId} --secret ${runtimeUmsClientSecret} --usr ${runtimeUser} --pwd ${runtimePwd}"
echo Getting Runtime UMSToken ... 
RUNTIME_BEARER=$(${CMD})
#echo 

# Call CPDS deploy REST pass in both bearer tokens with different header
echo Retrieving the deployed project information for ${runtimeObjectStore}/${projectName}/${snapshotVersion} ...
curl -X GET --header Content-Type:application/json --header Accept:application/json --header "Authorization:Bearer ${RUNTIME_BEARER}" -w '\nReturn Code=%{http_code}\n\n' ${runtimeCpdsUrl}/ibm-dba-content-deployment/v1/deployment/projects/${projectName}/branches/master/snapshots/${snapshotVersion}?repositoryIdentifier=${runtimeObjectStore} -k
