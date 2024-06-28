#!/bin/bash

# getUMSToken - A script to echo back the UMS token given the 
#  . UMS_Server_URL
#  . UMS clientId
#   .UMS clientPwd
#  . USER
#  . PWD
#
# DO NOT add any echo cmd to this script as this script is called from others to get back token
# This script should only echo back the stripped token.  This script is a helper script for the main scripts.


#Comment out for debugging to echo cmds back
#set -x

######## Constants 
# Provide defaults that can be override by passed in params
#IAM_URL=https://cp-console.apps.etched.cp.fyre.ibm.com
#ZEN_URL=https://cpd-adp.apps.etched.cp.fyre.ibm.com
#CLIENT_ID=
#CLIENT_SECRET=XXXXXXXXX
#USER=CEAdmin
#PWD=Genius1
acceptLanguage="en-US"


######### Functions
usage()
{
    echo "usage: getUMSToken [[[--iamurl IAMurl][--zenurl ZENurl] [ --usr user] [--pwd pwd]] | [-h]]"
}


#
######## Main

#parsing args 
while [ "$1" != "" ]; do
    case $1 in
        --iamurl)           	shift
                                IAM_URL="$1"
                                ;;
        --zenurl)         	    shift
				                ZEN_URL="$1"
                                ;;
        --usr)    		        shift
				                USER="$1"
                                ;;
        --pwd)    		        shift
				                PWD="$1"
                                ;;                        
        --acceptLanguage)		shift
								acceptLanguage="$1"
								;;
        -h)                     usage
                                exit 1
    esac
    shift
done





#echo

TOKEN=$(curl -k -X POST -d "grant_type=password&scope=openid&username=${USER}&password=${PWD}" "${IAM_URL}/idprovider/v1/auth/identitytoken" | grep -o "access_token\":[^}]*")
#echo $TOKEN
#strip prefix access_token out of TOKEN
STRIPPED_IAM_TOKEN=$(echo "$TOKEN" | sed 's/.*access_token":"//g' | sed 's/".*//g')
#echo "${STRIPPED_IAM_TOKEN}"

ZENTOKEN=$(curl -sk "${ZEN_URL}/v1/preauth/validateAuth" -H "username:${USER}" -H "iam-token: ${STRIPPED_IAM_TOKEN}")

#echo $ZENTOKEN

ZENTOKEN=$(echo "$ZENTOKEN" | grep -o ",\"accessToken\":\"[^\"]*")

#echo $ZENTOKEN

#strip prefix access_token out of TOKEN 
STRIPPED_TOKEN=$(echo "$ZENTOKEN" | sed -e 's/.*accessToken":"//g')
echo  "${STRIPPED_TOKEN}"

