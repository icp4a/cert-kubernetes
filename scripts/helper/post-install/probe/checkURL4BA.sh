#!/usr/bin/env bash
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# Input variables
CLUSTER=$1      # cluster domain e.g starter.ibm.com
NAMESPACE=$2    # namespace where CP4BA is installed
USERAPIKEY=$3   # user Api Key generated from CP4BA console
USERNAME=$4     # user name who has right to open all CP4BA links
USERPASS=$5     # user password for basci authentication
VERBOSE=$6      # verbose option to see additional debug information

# Internal variables
  CAP=""           # internal variable
  IFS=";"          # internal variable
  RED_TEXT=`tput setaf 1`
  GREEN_TEXT=`tput setaf 2`
  BLUE_TEXT=`tput setaf 6`
  RESET_TEXT=`tput sgr0`
  BOLD_TEXT=`tput bold`

PROB_DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $PROB_DIR

# Funtion to check if given keyword is returned by URL
checkURL() {
  DEPLOYMENT=$1      # deployment type (starter, production)
  CAPABILITY=$2      # installed capability name (ODF, Workflow, etc)
  URL_NAME=$3        # functionality name (Business Performance Center, etc)
  SERVER=$4          # unique part of pod/server name (spd, cpe, cpe-stless, etc)
  URL_PATH=$5        # URL path taken from access-info ConfigMap
  CHECK_PATH=$6      # corresponding URL path used in curl
  AUTH=$7            # authentication method (token, basic)
  CHECK_KEYWORD=$8   # keyword used to search curl's output

  if [ "$SERVER" != "SERVER" ] || [ "$DEPLOYMENT" == "" ] # Skip header and empty rows
  then
    if [ "$DEPLOYMENT" == "$DEPLOYMENT_TYPE_TO_LOWER" ] || [ "$DEPLOYMENT" == "both" ] # Use Url for specific deployment only
    then
      if [[ "$CAP" != "$CAPABILITY" ]]; then echo;echo -e "${BOLD_TEXT}#### ${CAPABILITY} ####${RESET_TEXT}";fi
      export CAP=${CAPABILITY}
      if [[ "$VERBOSE" == "-v" ]]; then echo "Searching for: \"${CHECK_KEYWORD}\"";fi
      echo -n "${URL_NAME}..."
      if [[ "$CHECK_PATH" == ":443" ]]; then SUFF=""; else SUFF=${PROTOCOL}; fi

      if [ $DEPLOYMENT_TYPE_TO_LOWER == "production" ]; then
        URL="\"${SUFF}${SERVER}-${NAMESPACE}.apps.${CLUSTER}${CHECK_PATH}\"" # URL for curl verificarion
        URL2="${SUFF}${SERVER}-${NAMESPACE}.apps.${CLUSTER}${URL_PATH}"  # Original URL
      else
        URL="\"${SUFF}${SERVER}-${NAMESPACE}.${CLUSTER}${CHECK_PATH}\"" # URL for curl verificarion
        URL2="${SUFF}${SERVER}-${NAMESPACE}.${CLUSTER}${URL_PATH}"  # Original URL
      fi

      if [[ "$AUTH" == "basic" ]]; then CMD="$CURLB $URL 2>&1"; else CMD="$CURLT $URL 2>&1"; fi
      RET=$(eval $CMD)
      if [[ ! -z $(echo "$RET" | grep "Unauthorized") ]]
      then echo -e "${RED_TEXT}Unauthorized${RESET_TEXT}: ${URL2}"
      else
      if [[ ! -z $(echo "$RET" | grep "404 Not Found") && -z $(echo "$RET" | grep -e "${CHECK_KEYWORD}") ]] || [[ ! -z $(echo "$RET" | grep "503 Service Unavailable") ]] || [[ ! -z $(echo "$RET" | grep "403 Forbidden") ]]
        then echo -e "${BOLD_TEXT}Not installed/Failed${RESET_TEXT}"
        else
          if [[ ! -z $(echo "$RET" | grep -e "${CHECK_KEYWORD}") ]]
          then
            if [[ ! -z $(echo "$RET" | grep "error occurred when the browser") ]]
            then
              echo -e "${BLUE_TEXT}???${RESET_TEXT}"
              echo -e "Check in browser: ${BLUE_TEXT}${URL2}${RESET_TEXT}"
            else echo -e "${GREEN_TEXT}OK${RESET_TEXT}"
            fi
          else
            echo -e "${RED_TEXT}BAD${RESET_TEXT}: ${RED_TEXT}${URL2}${RESET_TEXT}"
	          if [[ "$VERBOSE" == "" ]]; then echo -e "Check in cmd: ${BLUE_TEXT}${CMD} | grep -e \"${CHECK_KEYWORD}\"${RESET_TEXT}";fi
          fi
        fi
      fi
      if [[ "$VERBOSE" == "-v" ]]; then echo -e "Check in cmd: ${BLUE_TEXT}${CMD}${RESET_TEXT} | grep -e \"${CHECK_KEYWORD}\"${RESET_TEXT}";fi
    fi
  fi
}

# Required data verification
verifyRequiredData(){
  if [[ ! -e "./urlmap.csv" ]]
  then
    echo -e "${RED_TEXT}I cannot find urlmap.csv in running folder!${RESET_TEXT}"
    exit 1;
  fi
}

# Input parameters verificaton
verifyInputParameters(){
  if [ "$USERPASS" == "" ] # inforamtion in case of wrong parameters
  then
    echo
    echo "*** CP4BA URLs verification ***"
    #echo "$0 <cluster_domain> <CP4BA_namespace> <ApiKey> <LDAP/cp4admin_user> <user_password>"
    echo -e "${BOLD_TEXT}Invalid parameters${RESET_TEXT}"
    echo "Make sure you have provided input parameters PROBE_USER_API_KEY, PROBE_USER_NAME, and PROBE_USER_PASSWORD"
    echo
    echo "* To get <ApiKey>"
    if [[ ! -z $CLUSTER ]]
    then
      echo -e "1. Login to ${BLUE_TEXT}https://cpd-${NAMESPACE}.apps.${CLUSTER}${RESET_TEXT} as:"
    else
      echo "1. Login to https://cpd-<CP4BA_namespace>.apps.<cluster_domain> as:"
    fi
    echo -e " -  ${BOLD_TEXT}LDAP user${RESET_TEXT} in case of production deployment"
    echo -e " -  ${BOLD_TEXT}cp4admin user${RESET_TEXT} in case of starter deployment"
    echo "2. Open 'Profile and settings' window"
    echo "3. Generate new API key using 'API key' button on the right side"
    echo "4. Use red Generate button"
    echo "5. Use blue Copy button"
    echo
    echo -e "* To get ${BOLD_TEXT}cp4admin${RESET_TEXT} password run:"
    echo -e "${BLUE_TEXT}oc describe cm icp4adeploy-cp4ba-access-info -n $2 | grep password | awk '{split(\$0,a,\":\");print a[2]}' | uniq${RESET_TEXT}"
    echo
    #echo "* Example:"
    #echo -e "${BOLD_TEXT}./checkURL4BA.sh cp4ba-multi-p1.cloudpak-bringup.com cp4ba-prod sAHHjkhjhAUlksjsIIJOSLS= BUAdmin BUPassword${RESET_TEXT}"
    echo "Tip: use -v at the end of command for verbose"
    echo
    echo -e "${BOLD_TEXT}Refer to the KC documentation for more details${RESET_TEXT}"
    exit 1
  fi
}

# Curl commands formatting
TOKEN=$(echo $USERNAME:$USERAPIKEY | base64)
CURLT="curl -v -X GET -sk -H \"Authorization: ZenApiKey ${TOKEN}\""
CURLB="curl -v -sk -u $USERNAME:$USERPASS"
PROTOCOL="https://"

displayProductionNote() {
  if [[  "${DEPLOYMENT_TYPE_TO_LOWER}" == "production"  ]]
  then
    echo
    echo -e "${RED_TEXT}* Important note${RESET_TEXT}:"
    echo -e "You have to assign proper roles for ${USERNAME} in Access Control using ${BOLD_TEXT}admin${RESET_TEXT} on ${BLUE_TEXT}https://cpd-${NAMESPACE}.apps.${CLUSTER}${RESET_TEXT}"
    echo -e "To get ${BOLD_TEXT}admin${RESET_TEXT} password run:"
    echo -e "${BLUE_TEXT}oc -n ${NAMESPACE} get secret ibm-iam-bindinfo-platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d && echo${RESET_TEXT}"
    echo
    read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
  fi
}

verifyRequiredData
verifyInputParameters
displayProductionNote

echo
echo "Starting..."
# Reading and processing URLs from map file
while read i
do
  checkURL $i
done < <(grep "" ./urlmap.csv)

echo
echo "Completed!"
exit 0
