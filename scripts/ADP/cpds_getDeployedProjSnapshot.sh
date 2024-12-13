#!/bin/bash
#/*
# IBM Confidential
# OCO Source Materials
# 5737-I23
# Copyright IBM Corp. 2021
# The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S Copyright Office.
# */
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
#	./cpds_getDeployedProjSnapshot.sh --file cpds.properties
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
# These parameters are for UMS SSO login
#runtimeUmsUrl=https://ums-sso.adp.ibm.com
#runtimeUmsClientId=XXXXXXXXXXXXXX
#runtimeUmsClientSecret=XXXXXXXXXXXXXX

# These parameters are for Zen login
#runtimeUseZen=true
#runtimeZenIamUrl=https://cpd-adp.apps.adp.cp.ibm.com
#runtimeZenUrl=https://cp-console.apps.adp.cp.ibm.com

#General required parameters
#runtimeUser=Admin
#runtimePwd=password

#runtimeCpdsUrl=https://cpds.adp.ibm.com
#projectName=PRJ123
#snapshotVersion=v2-2020-10-13-1825
#runtimeObjectStore=OS1

acceptLanguage="en-US"

######### Functions
f_usage()
{
    echo "NAME"
    echo "  $0 -- retrieve the deployed Project version. "
    echo ""
    echo "USAGE: $0  "
    echo "    [--runtimeUmsUrl url]  "
    echo "    [--runtimeClientId id] "
    echo "    [--runtimeClientSecret secret]  "
    echo "    [--runtimeUseZen      true] "
    echo "    [--runtimeZenIamUrl    url] "
    echo "    [--runtimeZenUrl      url] "
    echo "    [ --runtimeUser user]     "
    echo "    [--runtimePwd pwd]"
    echo "    [--runtimeCpdsUrl     UrlToConnectToCPDS] "
    echo "    [--projectName        ProjectName]"
    echo "    [--snapshotVersion    ProjectSnapshotVersion]"
    echo "    [--runtimeObjectStore CPE ObjectStore symbolic name]]"
    echo "    [--acceptLanguage       language] (default to en-US if not specified)" 
    echo "    [--file               inputFile to store Key/Value pair for arguments]"
    echo "    [-h]"
    echo ""
    echo "The order of arguments passed in can be used to override, given preference to the last one. "
    echo "For example, if you want to extract most arguments from a file except for the runtimeObjectStore,"
    echo "you can pass --file <file> --runtimeObjectStore <os>"
    echo ""
    echo "EXAMPLE:"
    echo ""
    echo "Example to getDeployedProjSnapshot with UMS SSO authentication where all required keys are passed in. "
    echo "$0 "
    echo "   --runtimeUmsUrl                   https://ums-sso.adp.ibm.com"
    echo "   --runtimeUmsClientId              XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUmsClientSecret          XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUser                     deploy_user"
    echo "   --runtimePwd                      deploy_pwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --projectName                     PROJECT1"
    echo "   --snapshotVersion                 v2-2020-10-13-1825"
    echo "   --runtimeObjectStore              OS1"
    echo ""
    echo "Example to run getDeployedProjSnapshot with a IAM/Zen authentication where all required keys are defined. "
    echo "$0 "
    echo "   --runtimeUseZen                   true"
    echo "   --runtimeZenIamUrl                https://cpd-adp.asp.cp.fyre.ibm.com"
    echo "   --runtimeZenUrl                   https://cp-console.adp.cp.ibm.com"
    echo "   --runtimeUser                     deploy_user"
    echo "   --runtimePwd                      deploy_pwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --projectName                     PROJECT1"
    echo "   --snapshotVersion                 v2-2020-10-13-1825"
    echo "   --runtimeObjectStore              OS1"
    echo ""
    echo "Example to getDeployedProjSnapshot where all required keys are defined in cpds.properties file. "
    echo "$0 "
    echo "   --file cpds.properties		       where filename contains a list of key/value pairs."
    echo "                                     One can specify all required args in the file."
    echo ""
    echo "Example to getDeployedProjSnapshot where all required keys are defined in cpds.properties file and overriding --projectName. "
    echo "$0 "
    echo "   --file cpds.properties --projectName PROJECT2" --snapshotVersion v3-2020-10-14-1600 
    echo "                                    to extract all params from filename except for projectName and snapshotVersion"
    echo "                                    Note: order is important. The overriding argument should be listed last."
}

f_extractFieldsFromFile()
{
	echo 'Extracting fields from file' $INPUT_FILE ......
	if [ ! -z $INPUT_FILE ]
	then
    	set -a
    	. "$INPUT_FILE"
    	set +a
    fi

}

####### Main
if [[ $# = 0 ]]; then 
	echo "Parameters are required."
    f_usage
    exit 1
fi

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
        --runtimeZenIamUrl )       shift
                                runtimeZenIamUrl="$1"
                                ;;
        --runtimeUseZen )      shift
                                runtimeUseZen="$1"
                                ;;                        
        --runtimeZenUrl )      shift
                                runtimeZenUrl="$1"
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
        --acceptLanguage)		shift
								acceptLanguage="$1"
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


#check required params
#if [[ ${runtimeUser} = "" ]] ||  [[ ${runtimePwd} = "" ]] || 
#   [[ ${runtimeCpdsUrl} = "" ]] || [[ ${projectName} = "" ]] ||
#   [[ ${snapshotVersion} = "" ]] || [[ ${runtimeObjectStore} = "" ]] ||
#   [[ ${runtimeUmsUrl} = "" ]] || [[ ${runtimeUmsClientId} = "" ]] || [[ ${runtimeUmsClientSecret} = "" ]] 
#then
#	echo "ERROR: Missing required args: --runtimeUser --runtimePwd --runtimeCpdsUrl "
#	echo "                              --projectName --runtimeUmsClientId --runtimeUmsClientSecret"
#	echo ""
#	f_usage
#	exit 1
#fi


# Extract Bearer token to runtime env to connect to GIT, add acceptLang
if [ -z "${runtimeUseZen}" ] || [ "${runtimeUseZen}" != true ]
 then
	CMD="./helper_getUMSToken.sh --acceptLanguage ${acceptLanguage} --url ${runtimeUmsUrl} --id ${runtimeUmsClientId} --secret ${runtimeUmsClientSecret} --usr ${runtimeUser} --pwd ${runtimePwd}"
	echo Getting RunTime UMSToken ... 
	#${CMD}
	RUNTIME_BEARER=$(${CMD})
 else
	CMD="./helper_getZENToken.sh --acceptLanguage ${acceptLanguage} --iamurl ${runtimeZenIamUrl} --zenurl ${runtimeZenUrl} --usr ${runtimeUser} --pwd ${runtimePwd}"
	echo Getting RunTime ZENToken ...
	#${CMD}
	RUNTIME_BEARER=$(${CMD})
fi
#echo 

# Call CPDS deploy REST pass in both bearer tokens with different header
echo Retrieving the deployed project information for ${runtimeObjectStore}/${projectName}/${snapshotVersion} ...
curl -X GET --header "Accept-Language:${acceptLanguage}" --header Content-Type:application/json --header Accept:application/json --header "Authorization:Bearer ${RUNTIME_BEARER}" -w '\nReturn Code=%{http_code}\n\n' ${runtimeCpdsUrl}/ibm-dba-content-deployment/v1/deployment/projects/${projectName}/branches/master/snapshots/${snapshotVersion}?repositoryIdentifier=${runtimeObjectStore} -k
