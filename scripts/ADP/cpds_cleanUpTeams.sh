#!/bin/bash
#/*
# IBM Confidential
# OCO Source Materials
# 5737-I23
# Copyright IBM Corp. 2021
# The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S Copyright Office.
# */
#
# cpds_cleanUpTeams.sh: script to list or cleans up teams associated to the specified project name in the Teams Server.
#
#
#   In the Teams server, this script will removes teams that are associated with the specified project name by default.
#   
#    NOTE: Clean up of Teams is NOT RECOMMENDED FOR RUNTIME ENVIRONMENT USE.
#          If the project is deployed to multiple Content Platform Engine repositories, the teams are shared. 
#          Teams cleanup will remove all teams associated to the project name, making other deployments of the same project unusable.
#          Re-deploying the project will recreate the teams, but you must add all members again.
#	
#	To run clean project in the design environment, a user must be a Doc Processing Manager.
#   
#   Runtime Parameters required with UMS SSO authentication which are included in the cpds.properies sample file:
#    runtimeUmsUrl, runtimeUmsClientIdSecret, runtimeUser, runtimePwd=password,runtimeCpdsUrl,projectName
#
#   Runtime Parameters required which IAM/Zen Authentication are included in the cpds.properies sample file:
#     runtimeUseZen, runtimeZenIamUrl, runtimeZenUrl, runtimePwd=password,runtimeCpdsUrl,projectName
#
#    By default, the teams will be deleted for the project name.
#            Project related teams (one per project):
#               Project Admins-<projectName>
#               Classification Workers-<projectName>
#               Business Owners-<projectName>
#               Document Owners-<projectName>
#               Document Editors-<projectName>
#               Document Viewers-<projectName>
#             Project class related teams (one per class for the project):
#                  Document Owners-<projectName>-<documentTypeName>
#                  Document Editors-<projectName>-<documentTypeName>
#                  Document Viewers-<projectName>-<documentTypeName>
#   
#    Optionally, a list of all the teams can be returned for review before the deletion by using the --option "\"cleanTeams\": false"
#
# 	This script uses the helper_getUmsToken script to extract the UMS tokens for runtime environment.
# 	This script uses the helper_getZENToken script to extract the IAM and Zen tokens for runtime environment.
#
# Example to run script using the cpds.properties file to delete all project-related teams
#	./cpds_cleanUpTeams.sh --file cpds.properties 
#
# Example to run script using cpds.properties file to list all project-related teams.  Output can be reviewed before actual deletion.
#   ./cpds_cleanUpTeams.sh --file cpds.properties --cleanTeamsOptions "\"cleanTeams\": false"

#uncomment for debugging
#set -x

# Any subsequent(*) commands which fail will cause the shell script to exit immediately
set -e


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

acceptLanguage="en-US"

listOption="\"cleanTeams\": false"
listOptionStr=`echo "$listOption"  | sed 's/"/\\\\"/g'`
delOption="\"cleanTeams\": true"
delOptionStr=`echo "$delOption"  | sed 's/"/\\\\"/g'`

######### Functions
f_usage()
{
    echo "NAME"
    echo "  $0 -- clean up or list project-related teams from the teams server. "
    echo ""
    echo "USAGE: $0  "
    echo "    [--runtimeUmsUrl      url] "
    echo "    [--runtimeUmsClientId id] "
    echo "    [--runtimeUmsClientSecret secret] "
    echo "    [--runtimeUseZen      true] "
    echo "    [--runtimeZenIamUrl    url] "
    echo "    [--runtimeZenUrl      url] "
    echo "    [ --runtimeUser       user] "
    echo "    [--runtimePwd         pwd]"
    echo "    [--runtimeCpdsUrl     UrlToConnectToCPDS] "
    echo "    [--acceptLanguage     language] (default to en-US if not specified)" 
    echo "    [--file               inputFile to store Key/Value pair for arguments]"
    echo "    [--projectName        projectIdentifier that teams are associated with]"
    echo "    [--cleanTeamsOptions  JSON string option passed in to clean REST url]"
    echo "                          (default to \"$delOptionStr\" if not specified)"
    echo "    [-h]"
    echo ""
    echo "The order of arguments passed in can be used to override, given preference to the last one. "
    echo "For example, if you want to extract most arguments from a file except for the runtimeObjectStore,"
    echo "you can pass --file <file> --runtimeObjectStore <os>"
    echo ""
    echo "EXAMPLES:"
    echo ""
    echo "Example to run cleanUpTeams with UMS SSO authentication where all required keys are passed in. "
    echo "$0 "
    echo "   --runtimeUmsUrl                   https://ums-sso.adp.ibm.com"
    echo "   --runtimeUmsClientId              XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUmsClientSecret          XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUser                     runtimeCCAmember"
    echo "   --runtimePwd                      runtimeCCAmemberPwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --projectName                     PROJECT1"
    echo "   [--cleanTeamsOptions              \"$listOptionStr\"] (default \"$delOptionStr\" to if not specified)"
    echo "   [--acceptLanguage                 language] (default to en-US if not specified)" 
    echo ""
    echo "Example to run cleanupTeams with a IAM/Zen authentication where all required keys are defined. "
    echo "$0 "
    echo "   --runtimeUseZen                   true"
    echo "   --runtimeZenIamUrl                https://cpd-adp.asp.cp.fyre.ibm.com"
    echo "   --runtimeZenUrl                   https://cp-console.adp.cp.ibm.com"
    echo "   --runtimeUser                     runtimeCCAmember"
    echo "   --runtimePwd                      runtimeCCAmemberPwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --projectName                     PROJECT1"
    echo "   [--cleanTeamsOptions              \"$listOptionStr\"] (default \"$delOptionStr\" to if not specified)"
    echo "   [--acceptLanguage                 language] (default to en-US if not specified)" 
    echo ""
    echo "Example to delete all project associated teams where all required keys are defined in cpds.properties file. "
    echo "$0 "
    echo "   --file cpds.properties		       where filename contains a list of key/value pairs."
    echo "                                     One can specify all required args in the file."
    echo ""
    echo "Example to LIST (see --cleanTeamsOptions) all teams about to cleanUp where all required keys are defined in cpds.properties file and overriding --projectName. "
    echo "$0 "
    echo "   --file cpds.properties --projectName PROJECT2 --cleanTeamsOptions  \"$listOptionStr\""
    echo "                                    to extract all params from filename except for projectName"
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


getConfirmation ()
{
	echo 
	echo 'WARNING: Deletion of project-related teams will remove all teams associated to the project. '
	echo 'If the project is deployed in one or more repositories using these same teams, the project in '
	echo 'these environments will no longer function.'
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
        --runtimeZenIamUrl )    shift
                                runtimeZenIamUrl="$1"
                                ;;
        --runtimeUseZen )       shift
                                runtimeUseZen="$1"
                                ;;                        
        --runtimeZenUrl )       shift
                                runtimeZenUrl="$1"
                                ;;                                                
        --runtimeUser)    	    shift
				                runtimeUser="$1"
                                ;;
        --runtimePwd)        	shift
				                runtimePwd="$1"
                                ;;
        --runtimeCpdsUrl )      shift
                                runtimeCpdsUrl="$1"
                                ;;
        --acceptLanguage)		shift
								acceptLanguage="$1"
								;;
        --projectName)		    shift
				                projectName="$1"
				                ;;
        --file)                 shift
				INPUT_FILE="$1"
				f_extractFieldsFromFile
				;;
	--cleanTeamsOptions)		shift
				cleanTeamsOptions="$1"
				;;
        -h | --help)            f_usage
                                exit 1
    esac
    shift
done

#check required params
if [[ ${runtimeUser} = "" ]] ||  [[ ${runtimePwd} = "" ]] || 
   [[ ${runtimeCpdsUrl} = "" ]] || [[ ${projectName} = "" ]]
#   [[ ${runtimeUmsClientId} = "" ]] || [[ ${runtimeUmsClientSecret} = "" ]]
then
	echo "ERROR: Missing required args: --runtimeUser --runtimePwd --runtimeCpdsUrl "
	echo "                              --projectName "
	echo ""
	f_usage
	exit 1
fi


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
#echo


#set options JSON data: default to delOption if not passed in
if [ "${cleanTeamsOptions}" = "" ]
then
	cleanTeamsOptions="$delOption"
fi
echo $cleanTeamsOptions




# -- Prompt for confirmation on destructive operion 
if [ "${cleanTeamsOptions}" = "${delOption}" ]
then
	getConfirmation
fi

# Call CPDS REST , passed in bearer tokens and other params
curl -X POST --header "Accept-Language:${acceptLanguage}" --header 'Content-Type:application/json' --header 'Accept:application/json' --header "Authorization:Bearer ${RUN_BEARER}" -w '\nReturn Code=%{http_code}\n\n' "${runtimeCpdsUrl}/ibm-dba-content-deployment/v1/projects/${projectName}/teamscleanup" -k -d "{ ${cleanTeamsOptions} }"
