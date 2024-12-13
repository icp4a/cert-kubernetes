#!/bin/bash
#/*
# IBM Confidential
# OCO Source Materials
# 5737-I23
# Copyright IBM Corp. 2021
# The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S Copyright Office.
# */
#
# cpdp_getDeploymentStatus.sh: script to extract the deployment record associated with a deployment id.
#
# Runtime parameters required which are included in the cpds.properies sample file:
#    runtimeUmsUrl, runtimeUmsClientIdSecret, runtimeUser, runtimePwd=password,runtimeCpdsUrl,runtimeObjectStore
#
# Additional Script Required Parameters:
#    deploymentRecordId: extracted the deploymentRecordId from the JSON response of either the cpds_deployProj.sh or the cpds_getDeployedProjSnapshot.sh (lastDeploymentId)
#
#Example to run script:
#	./cpds_getDeploymentRec.sh --file cdps.properties --deploymentRecId D00E6C75-0000-CB1E-9CA6-ED3F7DB2AE9B


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
#runtimeObjectStore=OS1

#deploymentRecId=

acceptLanguage="en-US"

######### Functions
f_usage()
{
    echo "NAME"
    echo "  $0 -- retrieve the deployment record of a deployed Project version."
    echo ""
    echo "USAGE: $0  "
    echo "    [--runtimeUmsUrl      url]  "
    echo "    [--runtimeUmsClientId id] "
    echo "    [--runtimeUmsClientSecret secret]    "
    echo "    [--runtimeUseZen      true] "
    echo "    [--runtimeZenIamUrl    url] "
    echo "    [--runtimeZenUrl      url] "
    echo "    [ --runtimeUser       user]     "
    echo "    [--runtimePwd         pwd]"
    echo "    [--runtimeCpdsUrl     UrlToConnectToCPDS] "
    echo "    [--deploymentRecId    deployment record guid]"
    echo "    [--acceptLanguage     language] (default to en-US if not specified)" 
    echo "    [--file               inputFile to store Key/Value pair for arguments]"
    echo "    [-h]"
    echo ""
    echo "The order of arguments passed in can be used to override, given preference to the last one. "
    echo "For example, if you want to extract most arguments from a file except for the runtimeObjectStore,"
    echo "you can pass --file <file> --runtimeObjectStore <os>"
    echo ""
    echo "EXAMPLE:"
    echo ""
    echo "Example to get Deployment Status  with UMS SSO authentication passed in all required keys. "
    echo "$0 "
    echo "   --runtimeUmsUrl                   https://ums-sso.adp.ibm.com"
    echo "   --runtimeUmsClientId              XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUmsClientSecret          XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUser                     deploy_user"
    echo "   --runtimePwd                      deploy_pwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --deploymentRecId                 D00E6C75-0000-CB1E-9CA6-ED3F7DB2AE9B"
    echo "   --runtimeObjectStore			   OS1"
    echo ""
    echo "Example to run Deployment Status with a IAM/Zen authentication where all required keys are defined. "
    echo "$0 "
    echo "   --runtimeUseZen                   true"
    echo "   --runtimeZenIamUrl                https://cpd-adp.asp.cp.fyre.ibm.com"
    echo "   --runtimeZenUrl                   https://cp-console.adp.cp.ibm.com"
    echo "   --runtimeUser                     deploy_user"
    echo "   --runtimePwd                      deploy_pwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --deploymentRecId                 D00E6C75-0000-CB1E-9CA6-ED3F7DB2AE9B"
    echo "   --runtimeObjectStore			   OS1"
    echo ""
    echo "Example to get Deployment Status where all required keys are defined in cpds.properties file. "
    echo "$0 "
    echo "   --file cpds.properties"
    echo ""
    echo "Example to get Deployment Status where all required keys are defined in cpds.properties file and deploymentRecId added on command line"
    echo "      along with runtimeObjectStore overriding the input file value."
    echo "      Note: The deploymentRecId value could be the lastDeploymentRecordId value returned by cpds_DeployedProjSnapshot.sh script."
    echo "$0 "
    echo "   --file cpds.properties --deploymentRecId 903B9279-0000-C61E-A4A0-AE9C8D023519  --runtimeObjectStore OS2"
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
        --deploymentRecId)      shift
								deploymentRecId="$1"
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

echo Retrieving deploymentRecord ...
curl -X GET --header "Accept-Language:${acceptLanguage}" --header 'Content-Type:application/json' --header 'Accept:application/json' --header "Authorization:Bearer ${RUNTIME_BEARER}" "${runtimeCpdsUrl}/ibm-dba-content-deployment/v1/deploymentrecords/${deploymentRecId}?repositoryIdentifier=${runtimeObjectStore}" -w '\nReturn Code=%{http_code}\n\n'  -k
