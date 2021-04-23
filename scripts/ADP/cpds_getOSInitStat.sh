#!/bin/bash
# cpds_getOSInitStat.sh: script to check if ObjectStore is initialized for deployment

#
# Runtime Parameters required which are included in the cpds.properies sample file:
#    runtimeUmsUrl, runtimeUmsClientId, runtimeUmsClientSecret, runtimeUser, runtimePwd=password,runtimeCpdsUrl,runtimeObjectStore
#


#uncomment for debugging
#set -x

######## Constants 
# Provide defaults that can be override by passed in params
#runtimeUmsUrl=https://ums-sso.adp.ibm.com
#runtimeUmsClientId=XXXXXXXXXX
#runtimeUmsClientSecret=XXXXXXXXXX
#runtimeUser=Admin
#runtimePwd=password

#runtimeCpdsUrl=https://cpds.adp.ibm.com
#runtimeObjectStore=OS1




######### Functions
f_usage()
{
    echo "NAME"
    echo "  $0 -- retrieve the status of the ObjectStore for Project deployment."
    echo ""
    echo "USAGE: $0  "
    echo "    [--runtimeUmsUrl url] [--runtimeUmsClientId id] [--runtimeUmsClientSecret secret] [ --runtimeUser user] [--runtimePwd pwd]"
    echo "    [--runtimeCpdsUrl     UrlToConnectToCPDS] "
    echo "    [--runtimeObjectStore CPE ObjectStore symbolic name]"
    echo "    [--file               inputFile to store Key/Value pair for arguments]"
    echo "    [-h]"
    echo ""
    echo "The order of arguments passed in can be used to override, given preference to the last one. "
    echo "For example, if you want to extract most arguments from a file except for the runtimeObjectStore,"
    echo "you can pass --file <file> --runtimeObjectStore <os>"
    echo ""
    echo "EXAMPLE:"
    echo "$0 "
    echo "   --runtimeUmsUrl                   https://ums-sso.adp.fyre.ibm.com"
    echo "   --runtimeUmsClientId              DfPtsBMyLOjYVPqChIKL"
    echo "   --runtimeUmsClientSecret          Dwvj3D0tp4HaugA2s22a"
    echo "   --runtimeUser                     any_usr"
    echo "   --runtimePwd                      any_pwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
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
		echo $t =  $val
	done

}

####### Main

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
        --file)                 shift
								INPUT_FILE="$1"
								f_extractFieldsFromFile
								;;
        -h)                     f_usage
                                exit 1
    esac
    shift
done





# Extract Bearer token to Runtime env to connect to CPE/ACA
CMD="./helper_getUMSToken.sh --url ${runtimeUmsUrl} --id ${runtimeUmsClientId} --secret ${runtimeUmsClientSecret} --usr ${runtimeUser} --pwd ${runtimePwd}"
echo Getting RunTime UMSToken ... 
#${CMD}
RUN_BEARER=$(${CMD})
#echo

curl -X GET --header "Authorization:Bearer ${RUN_BEARER}" --header 'Content-Type: application/json' --header 'Accept: application/json' -w '\nReturn Code=%{http_code}\n\n' "${runtimeCpdsUrl}/ibm-dba-content-deployment/v1/repositories/${runtimeObjectStore}/initialization" -k
#echo $? 	#exit 0 even if REST failed. 
