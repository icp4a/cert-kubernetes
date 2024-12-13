#!/bin/bash
#/*
# IBM Confidential
# OCO Source Materials
# 5737-I23
# Copyright IBM Corp. 2021-2022
# The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S Copyright Office.
# */
#
# cpds_systemPrecheck.sh: The script does a system check for Content Project Deployment Service. 
#   The script will use the precheck endpoint to check that user has the permission to deploy a project,
#   verifies that connections used for the Content Project Deployment Service are available, and reports the ADP Project database availability.
#
# 	This script will call the helper_getUmsToken to extract the UMS tokens for both the design/development as well as the runtime environment.
#
# Runtime parameters required with UMS SSO authentication which are included in the cpds.properies sample file:
#    runtimeUmsUrl, runtimeUmsClientId, runtimeUmsClientSecret, runtimeUser, runtimePwd, runtimeCpdsUrl, runtimeObjectStore, projectName
#
# 	This script will call the helper_getZENToken to extract the UMS tokens for both the design/development as well as the runtime environment.
#
# Runtime parameters required with IAM/Zen authentication which are included in the cpds.properies sample file:
#   runtimeUseZen, runtimeZenIamUrl, runtimeZenUrl, runtimeUser, runtimePwd, runtimeCpdsUrl, runtimeObjectStore, projectName
#
# Example to run script using the cpds.properties file for parameter inputs:
#	./cpds_systemPrecheck.sh --file cpds.properties 

#uncomment for debugging
#set -x

# These parameters are for UMS SSO login
#runtimeUmsUrl=https://ums-sso.adp.ibm.com
#runtimeUmsClientId=XXXXXXXXXXXXXX
#runtimeUmsClientSecret=XXXXXXXXXXXXXX

# These parameters are for Zen login
#runtimeUseZen=true
#runtimeZenIamUrl=https://cpd-adp.apps.adp.cp.ibm.com
#runtimeZenUrl=https://cp-console.apps.adp.cp.ibm.com

#devUmsUrl=https://ums-sso.development.adp.ibm.com
#devUmsClientId=XXXXXXXXXXXX
#devUmsClientSecret=XXXXXXXXXX

# These parameters are for Zen login
#devUseZen=true
#devZenIamUrl=https://cpd-adp.apps.adp.development.cp.ibm.com
#devZenUrl=https://cp-console.apps.adp.development.cp.ibm.com

#General required parameters
#devUser=DevAdmin
#devPwd=password

#runtimeCpdsUrl=https://cpds.adp.ibm.com
#projectName=PRJ123
#runtimeObjectStore=OS1


######## Constants 
acceptLanguage="en-US"

######### Functions
f_usage()
{
    echo "NAME"
    echo "  $0 -- checks Content Project Deployment Service connections to all external services are reachable,"
    echo "       login credential can deploy and ADP Project database availability. "
    echo ""
    echo "USAGE: $0  "
    echo "    [--devUmsUrl          url]     "
    echo "    [--devUmsClientId     id]   "
    echo "    [--devUmsClientSecret secret]   " 
    echo "    [--devUseZen      true] "
    echo "    [--devZenIamUrl    url] "
    echo "    [--devZenUrl      url] "
    echo "    [--devUser           user]     "
    echo "    [--devPwd             pwd]"
    echo "    [--runtimeUmsUrl      url] "
    echo "    [--runtimeUmsClientId id] "
    echo "    [--runtimeUmsClientSecret secret] "
    echo "    [--runtimeUseZen      true] "
    echo "    [--runtimeZenIamUrl    url] "
    echo "    [--runtimeZenUrl      url] "
    echo "    [ --runtimeUser       user] "
    echo "    [--runtimePwd         pwd]"
    echo "    [--runtimeCpdsUrl     UrlToConnectToCPDS] "
    echo "    [--projectName        projectName] "
    echo "    [--acceptLanguage     language] (default to en-US if not specified)" 
    echo "    [--file               inputFile to store Key/Value pair for arguments]"
    echo "    [-h]"
    echo ""
    echo "The order of arguments passed in can be used to override, given preference to the last one. "
    echo "For example, if you want to extract most arguments from a file except for the runtimeObjectStore,"
    echo "you can pass --file <file> --runtimePwd <pwd>"
    echo ""
    echo "EXAMPLES:"
    echo ""
    echo "Example to run system Precheck  with UMS SSO authentication where all required keys are defined. "
    echo "$0 "
    echo "   --devUmsUrl                       https://ums-sso.development.adp.ibm.com"
    echo "   --devUmsClientId                  XXXXXXXXXXXXXXXXXXXX"
    echo "   --devUmsClientSecret              XXXXXXXXXXXXXXXXXXXX"
    echo "   --devUser                         devCCAmember"
    echo "   --devPwd                          devCCAmemberPwd"
    echo "   --runtimeUmsUrl                   https://ums-sso.adp.ibm.com"
    echo "   --runtimeUmsClientId              DfPtsBMyLOjYVPqChIKL"
    echo "   --runtimeUmsClientSecret          Dwvj3D0tp4HaugA2s22a"
    echo "   --runtimeUser                     runtimeCCAmember"
    echo "   --runtimePwd                      runtimeCCAmemberPwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --projectName                     ABDProj"
    echo ""
    echo "Example to run system Precheck with a Zen environment where all required keys are defined. "
    echo "$0 "
    echo "   --devUseZen                       true"
    echo "   --devZenIamUrl                    https://cpd-adp.apps.adp.development.cp.ibm.com"
    echo "   --devZenUrl                       https://cp-console.apps.adp.development.cp.ibm.com"
    echo "   --devUser                         devCCAmember"
    echo "   --devPwd                          devCCAmemberPwd"
    echo "   --runtimeUseZen                   true"
    echo "   --runtimeZenIamUrl                https://cpd-adp.asp.cp.fyre.ibm.com"
    echo "   --runtimeZenUrl                   https://cp-console.adp.cp.ibm.com"
    echo "   --runtimeUser                     runtimeCCAmember"
    echo "   --runtimePwd                      runtimeCCAmemberPwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --projectName                     ABDProj"
    echo ""
    echo ""
    echo "Example to run system Precheck  where all required keys are defined in cpds.properties file. "
    echo "$0 "
    echo "   --file cpds.properties"
    echo ""
    echo "Example to run system Precheck  where all required keys are defined in cpds.properties file and overriding runtimeUser. "
    echo "$0 "
    echo "   --file cpds.properties --runtimeUser UserWithPermission"
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
        --runtimeCpdsUrl )      shift
                                runtimeCpdsUrl="$1"
                                ;;
        --devUmsUrl )        	shift
                                devUmsUrl="$1"
                                ;;
        --devUmsClientId)       shift
								devUmsClientId="$1"
                                ;;
        --devUmsClientSecret)   shift
								devUmsClientSecret="$1"
                                ;; 
        --devZenIamUrl )        shift
                                runtimeZenIamUrl="$1"
                                ;;
        --devUseZen )           shift
                                runtimeUseZen="$1"
                                ;;                        
        --devZenUrl )           shift
                                runtimeZenUrl="$1"
                                ;;                                                 
        --devUser)    			shift
								devUser="$1"
                                ;;
        --devPwd)        		shift
								devPwd="$1"
                                ;;                        
        --projectName)      shift
                                projectName="$1"
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

# Extract Bearer token to Design/Development environment to connect to Design Repository 
if [ -z "${devUseZen}" ] || [ "${devUseZen}" != true ]
 then
	CMD="./helper_getUMSToken.sh --acceptLanguage ${acceptLanguage} --url ${devUmsUrl} --id ${devUmsClientId} --secret ${devUmsClientSecret} --usr ${devUser} --pwd ${devPwd}"
	echo Getting Dev UMSToken ... 
	#${CMD}
	DEV_BEARER=$(${CMD})
 else
	CMD="./helper_getZENToken.sh --acceptLanguage ${acceptLanguage} --iamurl ${devZenIamUrl} --zenurl ${devZenUrl} --usr ${devUser} --pwd ${devPwd}"
	echo Getting Dev ZENToken ...
	#${CMD}
	DEV_BEARER=$(${CMD})
fi

echo "systemPrecheck"

#echo 

# Call CPDS url
queryParam=""
if ! [ -z "${projectName}" ]
then
	queryParam="?projectIdentifier=${projectName}"
fi
echo
curl -X GET --header "Accept-Language:${acceptLanguage}" --header 'Content-Type:application/json' --header "X-DBA-DEVToken: ${DEV_BEARER}" --header 'Accept:application/json' --header "Authorization:Bearer ${RUN_BEARER}" -w '\nReturn Code=%{http_code}\n\n' "${runtimeCpdsUrl}/ibm-dba-content-deployment/v1/precheck${queryParam}" -k

