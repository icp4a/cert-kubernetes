#!/bin/bash
#/*
# IBM Confidential
# OCO Source Materials
# 5737-I23
# Copyright IBM Corp. 2021
# The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S Copyright Office.
# */
# cpds_getOSConfigStatus.sh script to check if ObjectStore is initialized for deployment

#
# Runtime Parameters required which are included in the cpds.properies sample file:
#    runtimeUmsUrl, runtimeUmsClientId, runtimeUmsClientSecret, runtimeUser, runtimePwd=password,runtimeCpdsUrl,runtimeObjectStore
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
#runtimeObjectStore=OS1

acceptLanguage="en-US"



######### Functions
f_usage()
{
    echo "NAME"
    echo "  $0 -- retrieve the status of the ObjectStore for Project deployment."
    echo ""
    echo "USAGE: $0  "
    echo "    [--runtimeUmsUrl      url] "
    echo "    [--runtimeUmsClientId id] "
    echo "    [--runtimeUmsClientSecret secret] "
    echo "    [--runtimeUseZen      true] "
    echo "    [--runtimeZenIamUrl    url] "
    echo "    [--runtimeZenUrl      url] "
    echo "    [--runtimeUser       user] "
    echo "    [--runtimePwd         pwd]"
    echo "    [--runtimeCpdsUrl     UrlToConnectToCPDS] "
    echo "    [--runtimeObjectStore CPE ObjectStore symbolic name]"
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
    echo "Example to run getOSConfigStatus  with UMS SSO authentication passed with UMS environment all required keys. "
    echo "$0 "
    echo "   --runtimeUmsUrl                   https://ums-sso.adp.fyre.ibm.com"
    echo "   --runtimeUmsClientId              XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUmsClientSecret          XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUser                     any_usr"
    echo "   --runtimePwd                      any_pwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --runtimeObjectStore              OS1"
    echo ""
    echo "Example to run getOSConfigStatus with a IAM/Zen authentication all required keys. "
    echo "$0 "
    echo "   --runtimeUseZen                   true"
    echo "   --runtimeZenIamUrl                https://cpd-adp.asp.cp.fyre.ibm.com"
    echo "   --runtimeZenUrl                   https://cp-console.adp.cp.ibm.com"
    echo "   --runtimeUser                     runtimeCCAmember"
    echo "   --runtimePwd                      runtimeCCAmemberPwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --runtimeObjectStore              OS1"
    echo ""
    echo "Example to run getOSConfigStatus where all required keys are defined in cpds.properties file. "
    echo "$0 "
    echo "   --file cpds.properties"
    echo "Example to list all teams about to cleanUp where all required keys are defined in cpds.properties file and overriding --runtimeObjectStore. "
    echo ""
    echo "$0 "
    echo "   --file cpds.properties --runtimeObjectStore OBJECTSTORE1"
    echo "                                    to extract all params from filename except for runtimeObjectStore"
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
        --runtimeUmsUrl )       shift
                                runtimeUmsUrl="$1"
                                ;;
       --runtimeUmsClientId)   shift
								runtimeUmsClientId="$1"
                                ;;
        --runtimeUmsClientSecret)   shift
								runtimeUmsClientSecret="$1"
                                ;;  
       --runtimeZenIamUrl )     shift
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
         --runtimeCpdsUrl )      shift
                                runtimeCpdsUrl="$1"
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



# Extract Bearer token to Runtime environment to connect to CPE/ACA, add acceptLang
if [ -z "${runtimeUseZen}" ] || [ "${runtimeUseZen}" != true ]
 then
	CMD="./helper_getUMSToken.sh --acceptLanguage ${acceptLanguage} --url ${runtimeUmsUrl} --id ${runtimeUmsClientId} --secret ${runtimeUmsClientSecret} --usr ${runtimeUser} --pwd ${runtimePwd}"
	echo Getting RunTime UMSToken ... 
	#${CMD}
	RUN_BEARER=$(${CMD})
 else
	CMD="./helper_getZENToken.sh --acceptLanguage ${acceptLanguage} --iamurl ${runtimeZenIamUrl} --zenurl ${runtimeZenUrl} --usr ${runtimeUser} --pwd ${runtimePwd}"
	echo Getting RunTime ZENToken ...
	#${CMD}
	RUN_BEARER=$(${CMD})
fi

curl -X GET --header "Accept-Language:${acceptLanguage}" --header "Authorization:Bearer ${RUN_BEARER}" --header 'Content-Type: application/json' --header 'Accept: application/json' -w '\nReturn Code=%{http_code}\n\n' "${runtimeCpdsUrl}/ibm-dba-content-deployment/v1/repositories/${runtimeObjectStore}/initialization" -k
#echo $? 	#exit 0 even if REST failed. 
