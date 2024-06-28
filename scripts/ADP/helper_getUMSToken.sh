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
#URL=https://ums-sso.adp.ibm.com
#CLIENT_ID=XXXXXXXXXX
#CLIENT_SECRET=XXXXXXXXX
#USER=Admin
#PWD=password
acceptLanguage="en-US"


######### Functions
usage()
{
    echo "usage: getUMSToken [[[--url UMSurl][--id UMSbase64clientid] [--secret UMSbase64clientsecret] [ --usr user] [--pwd pwd]] | [-h]]"
}


######## Main

#parsing args 
while [ "$1" != "" ]; do
    case $1 in
        --url)            	shift
                                URL="$1"
                                ;;
        --id)         	    shift
				CLIENT_ID="$1"
                                ;;
        --secret)         	shift
				CLIENT_SECRET="$1"
                                ;;
        --usr)    		shift
				USER="$1"
                                ;;
        --pwd)        		shift
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




#TOKEN=$(curl -k -s -i --location --request POST "${URL}" --header "Authorization: Basic ${CLIENT_ID}:${CLIENT_SECRET}" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'scope=openid' --data-urlencode "username=${USER}" --data-urlencode "password=${PWD}" | grep -o "access_token\":[^,]*")


# add acceptLang
TOKEN=$(curl -k -s -i --location --request POST "${URL}/oidc/endpoint/ums/token" --header "Accept-Language:${acceptLanguage}" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'scope=openid' --data-urlencode "username=${USER}" --data-urlencode "password=${PWD}" --user "${CLIENT_ID}:${CLIENT_SECRET}" | grep -o "access_token\":[^,]*")

#echo $TOKEN



#strip prefix access_token out of TOKEN 
STRIPPED_TOKEN=$(echo "$TOKEN" | sed -e 's/^access_token\"://g')
#echo "${STRIPPED_TOKEN}"
STRIPPED_TOKEN=$(echo "$STRIPPED_TOKEN" | sed -e 's/\"//g')
echo "${STRIPPED_TOKEN}"

