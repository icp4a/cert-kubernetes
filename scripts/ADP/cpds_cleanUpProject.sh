#!/bin/bash
#/*
# IBM Confidential
# OCO Source Materials
# 5737-I23
# Copyright IBM Corp. 2021
# The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S Copyright Office.
# */
#
#
# cpds_cleanUpProject.sh: This script will clean up artifacts for the specified deployed project in Content Platform Engine repository and the associated ADP project.
#
#   This scripts removes documents and metadata from the Content Platform Engine repository and removes the associated ADP Project information.
#   
#    NOTE: Clean project is NOT RECOMMENDED FOR RUNTIME ENVIRONMENT USE.
#           Do not run clean project on a project that is active.
#   
#   To run clean project in the authoring environment, the user must be a Doc Processing Manager or Doc Processing Analyst.
#   To run clean project in the runtime environment,the user must be a Doc Processing Manager and have Content Platform Engine administrator security for the repository.
#
#   Runtime Parameters required with UMS SSO authentication which are included in the cpds.properies sample file:
#    runtimeUmsUrl, runtimeUmsClientIdSecret, runtimeUser, runtimePwd=password,runtimeCpdsUrl,runtimeObjectStore
#   
#   Runtime Parameters required with IAN/Zen authentication which are included in the cpds.properies sample file:
#     runtimeUseZen, runtimeZenIamUrl, runtimeZenUrl, runtimeUser, runtimePwd=password,runtimeCpdsUrl,runtimeObjectStore
#	
#    deployedProjectId  - parameter required to identify the deployed project to be cleaned. 
#   
#    cleanProjOptions   JSON string option passed in to clean REST url if not specified, default to $defaultCleanOptions 
#    (defaultCleanOptions=" \"filterIncludeDocDetails\": false, \"timeOutInSecs\": 10, \"cleanPropertyTemplates\": false ")   
#    Clean options description:
#    filterIncludeDocDetails - boolean value with default is false.  If true, returns the details of each deleted document.
#    timeOutInSecs -	integer value with default to 10 seconds.  This value limits the number of seconds to clean up the documents of a project. 
#                                                               If the time is too short, cleanup will not be complete. Default is 10 seconds
#    cleanPropertyTemplates -boolean value with default to false.  If true, removes the property templates associated with the project.  Note: Property templates may be share with 
#                            other projects. Property templates can only be delete if NO other projects in that objectStore are using it, otherwise that property is skipped.   
#
# 	This script uses the helper_getUmsToken scripts to extract the UMS tokens for runtime environment.
#   
# 	This script uses the helper_getZENToken script to extract the IAM and Zen tokens for runtime environment.
#
# Example to run script using the cpds.properties file 
#	./cpds_cleanUpProject.sh --file cpds.properties --deployedProjectId EB9B7698-8C1F-45C1-AD04-B7DA7A10E717
#
# Example to run script with the option to clean the associated property templates
#  ./cpds_cleanUpProject.sh --file cpds.properties --deployedProjectId EB9B7698-8C1F-45C1-AD04-B7DA7A10E717 --cleanProjOptions " \"filterIncludeDocDetails\": true, \"timeOutInSecs\": 120, \"cleanPropertyTemplates\": true "

#uncomment for debugging
#set -x


# Any subsequent(*) commands which fail will cause the shell script to exit immediately
#set -e

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


defaultCleanOptions=" \"filterIncludeDocDetails\": false, \"timeOutInSecs\": 10, \"cleanPropertyTemplates\": false ,\"cleanRoles\": false"
defaultCleanOptionsStr=`echo "$defaultCleanOptions"  | sed 's/"/\\\\"/g'`

acceptLanguage="en-US"

#deployedProjectId=EB9B7698-8C1F-45C1-AD04-B7DA7A10E717

######### Functions
f_usage()
{
    echo "NAME"
    echo "  $0 -- clean up artifacts for the specified deployed project in Content Platform Engine repository and the associated ADP project. "
    echo ""
    echo "USAGE: $0  "
    echo "    [--runtimeUmsUrl      url] "
    echo "    [--runtimeUmsClientId id] "
    echo "    [--runtimeUmsClientSecret secret] "
    echo "    [--runtimeUseZen      true] "
    echo "    [--runtimeZenIamUrl    url] "
    echo "    [--runtimeZenUrl      url] "
    echo "    [--runtimeUser        user] "
	echo "    [--runtimePwd         pwd]"
    echo "    [--runtimeCpdsUrl     UrlToConnectToCPDS] "
    echo "    [--deployedProjectId  deployedProjectId]"
    echo "    [--runtimeObjectStore CPE ObjectStore symbolic name]"
    echo "    [--acceptLanguage     language] (default to en-US if not specified)" 
    echo "    [--file               inputFile to store Key/Value pair for arguments]"
    echo "    [--cleanProjOptions   JSON string option passed in to clean project REST url] "
    echo "                          (default to \"$defaultCleanOptionsStr\" if not specified)"
    echo "    [-h]"
    echo ""
    echo "The order of arguments passed in can be used to override, given preference to the last one. "
    echo "For example, if you want to extract most arguments from a file except for the runtimeObjectStore,"
    echo "you can pass --file <file> --runtimeObjectStore <os>"
    echo ""
    echo "EXAMPLES:"
    echo ""
    echo "Example to run cleanUp project with UMS SSO authentication passed in all required keys. "
    echo "$0 "
    echo "   --runtimeUmsUrl                   https://ums-sso.adp.ibm.com"
    echo "   --runtimeUmsClientId              XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUmsClientSecret          XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUser                     runtimeCCAmember"
    echo "   --runtimePwd                      runtimeCCAmemberPwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --deployedProjectId               EB9B7698-8C1F-45C1-AD04-B7DA7A10E717"
    echo "   --runtimeObjectStore              OS1"
    echo ""
    echo "Example to run system Precheck with a IAM/Zen authentication where all required keys are defined. "
    echo "$0 "
    echo "   --runtimeUseZen                   true"
    echo "   --runtimeZenIamUrl                https://cpd-adp.asp.cp.fyre.ibm.com"
    echo "   --runtimeZenUrl                   https://cp-console.adp.cp.ibm.com"
    echo "   --runtimeUser                     runtimeCCAmember"
    echo "   --runtimePwd                      runtimeCCAmemberPwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --deployedProjectId               EB9B7698-8C1F-45C1-AD04-B7DA7A10E717"
    echo "   --runtimeObjectStore              OS1"
    echo ""
    echo "Example to run cleanUp project where all required keys are defined in cpds.properties file. "
    echo "$0 "
    echo "   --file cpds.properties"
    echo ""
    echo "Example to run cleanUp project where all required keys are defined in cpds.properties file and overriding deployedProjectId. "
    echo "$0 "
    echo "   --file cpds.properties --deployedProjectId EB9B7698-8C1F-45C1-AD04-B7DA7A10E717"
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


getConfirmation ()
{
	echo 
        echo 'WARNING: Deletion of a project will remove most artifacts associated with a deployed project. '
	echo 'These artifacts include:  documents, document classes, roles, ca project, project versions, project, '
        echo 'project deployment records associated with a project. Unreferenced property templates can be deleted '
	echo 'if passed in an override flag. In the dev env, operation is opened to users who are EITHER  members '
	echo 'of Doc Processing Managers or Content Analysts or Project Admins. In  the runtime env, operation is '
	echo 'opened only to users who are members of (either Doc Processing Mgrs or ProjectAdmins) and OS admins.'
	echo


	while true; do
    		read -p "Type YES to proceed with deletion or return to exit ? " yn
    		case $yn in
        		YES ) break;;
        		* ) exit;;
    		esac
	done
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
        --runtimeUser)    	shift
				runtimeUser="$1"
                                ;;
        --runtimePwd)        	shift
				runtimePwd="$1"
                                ;;
        --runtimeCpdsUrl )      shift
                                runtimeCpdsUrl="$1"
                                ;;
        --deployedProjectId)    shift
				deployedProjectId="$1"
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
        --cleanProjOptions)     shift
				cleanProjOptions="$1"
				;;
        -h)                     f_usage
                                exit 1
    esac
    shift
done



#check required params
#if [[ ${runtimeUser} = "" ]] ||  [[ ${runtimePwd} = "" ]] || 
#   [[ ${runtimeCpdsUrl} = "" ]] || [[ ${deployedProjectId} = "" ]] ||
#   [[ ${runtimeUmsClientId} = "" ]] || [[ ${runtimeUmsClientSecret} = "" ]] ||
#   [[ ${runtimeObjectStore} = "" ]]
#then
#	echo "ERROR: Missing required args: --runtimeUser --runtimePwd --runtimeCpdsUrl "
#	echo "                              --deployedProjectId --runtimeUmsClientId --runtimeUmsClientSecret --runtimeObjectStore"
#	echo ""
#	f_usage
#	exit 1
#fi

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


#set cleanProjOptions if never set by param
if [  -z "$cleanProjOptions" ]
then
	cleanProjOptions=${defaultCleanOptions}
fi


# -- Prompt for confirmation on destructive operation 
getConfirmation

# Call CPDS REST pass in bearer tokens 
echo Cleaning project ...
curl -X POST --header "Accept-Language:${acceptLanguage}" --header 'Content-Type:application/json' --header 'Accept:application/json' --header "Authorization:Bearer ${RUN_BEARER}" -w '\nReturn Code=%{http_code}\n\n' "${runtimeCpdsUrl}/ibm-dba-content-deployment/v1/projects/${deployedProjectId}/cleanup?repositoryIdentifier=${runtimeObjectStore}" -k -d "{ ${cleanProjOptions} }"

