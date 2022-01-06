#!/bin/bash
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
#runtimeUmsUrl=https://ums-sso.adp.ibm.com
#devUmsClientId=XXXXXXX
#devUmsClientSecret=XXXXXX
#runtimeUser=Admin
#runtimePwd=password

#runtimeCpdsUrl=https://cpds.adp.ibm.com
#runtimeObjectStore=OS1

#deploymentRecId=


######### Functions
f_usage()
{
    echo "NAME"
    echo "  $0 -- retrieve the deployment record of a deployed Project version."
    echo ""
    echo "USAGE: $0  "
    echo "    [--runtimeUmsUrl url]  [--runtimeUmsClientId id] [--runtimeUmsClientSecret secret]    [ --runtimeUser user]     [--runtimePwd pwd]"
    echo "    [--runtimeCpdsUrl     UrlToConnectToCPDS] "
    echo "    [--deploymentRecId    deploymentRecId]"
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
    echo "   --deploymentRecId                 D00E6C75-0000-CB1E-9CA6-ED3F7DB2AE9B"
    echo "   --runtimeObjectStore			  OS1"
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
        --deploymentRecId)      shift
								deploymentRecId="$1"
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
CMD="./helper_getUMSToken.sh --url ${runtimeUmsUrl}  --id ${runtimeUmsClientId} --secret ${runtimeUmsClientSecret} --usr ${runtimeUser} --pwd ${runtimePwd}"
echo Getting Runtime UMSToken ... 
RUNTIME_BEARER=$(${CMD})
#echo 

echo Retrieving deploymentRecord ...
curl -X GET --header 'Content-Type:application/json' --header 'Accept:application/json' --header "Authorization:Bearer ${RUNTIME_BEARER}" "${runtimeCpdsUrl}/ibm-dba-content-deployment/v1/deploymentrecords/${deploymentRecId}?repositoryIdentifier=${runtimeObjectStore}" -w '\nReturn Code=%{http_code}\n\n'  -k
