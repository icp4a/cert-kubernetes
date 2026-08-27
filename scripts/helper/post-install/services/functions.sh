###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2022. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################

echo " "
echo " "
echo "##########################################################################################################"
echo "                              Running CP4BA Post install $CP4BA_DEPLOYMENT_SERVICE Service"
#echo "                              #Log File - "
echo "##########################################################################################################"

SCRIPT_START_TIME=`date`
echo "Start time : ${SCRIPT_START_TIME}"

cd $DIR
mkdir logs 2> /dev/null
LOG_DIR=$DIR/logs

consoleFooter()
{
  echo "##########################################################################################################"
  SCRIPT_END_TIME=`date`
  echo "End Time: ${SCRIPT_END_TIME}"
  if (( $SECONDS > 3600 )) ; then
      let "hours=SECONDS/3600"
      let "minutes=(SECONDS%3600)/60"
      let "seconds=(SECONDS%3600)%60"
      echo "${1} Completed in $hours hour(s), $minutes minute(s) and $seconds second(s)"
  elif (( $SECONDS > 60 )) ; then
      let "minutes=(SECONDS%3600)/60"
      let "seconds=(SECONDS%3600)%60"
      echo "${1} Completed in $minutes minute(s) and $seconds second(s)"
  else
      echo "${1} Completed in $SECONDS seconds"
  fi
  echo "##########################################################################################################"
  echo ""
}

printHeaderMessage()
{
 echo ""
  if [  "${#2}" -ge 1 ] ;then
      echo "${2}${1}"
  else
      echo "${BLUE_TEXT}${1}"
  fi
  echo "################################################################${RESET_TEXT}"
  sleep 1
}

OS()
{
  printHeaderMessage "Checking OS before continuing on"
  OS=`find /etc | grep -c os-release`
  if [[ "$OS" == "1" || "$OS" == "2" ]]; then
    IS_UBUNTU=`cat /etc/*-release | grep ID | grep -c Ubuntu`
    IS_RH=`cat /etc/os-release | grep ID | grep -c rhel`
    echo "Linux is being used"
    source ~/.profile 2> /dev/null
  else
    IS_MAC=`sw_vers | grep ProductName | awk '{print $2}' | grep -c macOS`
    source ~/.bash_profile 2> /dev/null
    echo "macOS is being used"
  fi
  if [ "$IS_MAC" == "1" ]; then
    MAC=true
  else
    IS_MAC=0
  fi
}

getCloudPakAPIKey()
{
  printHeaderMessage "Get Cloud Pak API Key ${4} (LOG ${LOG_DIR}/getCloudPakAPIKey.log ) "
  local CP_HOST=${1}
  local CP_USERNAME=${2}
  local CP_PASSWORD=${3}
  local CP_API_NAME=${4}
  if [ -z  ${CP_HOST}  ]; then
    echo "${RED_TEXT}${ICON_FAIL} Missing Cloud Pak Host Name${RESET_TEXT}"
  fi
  if [ -z  ${CP_USERNAME} ]; then
    echo "${RED_TEXT}${ICON_FAIL} Missing Cloud Pak User Name${RESET_TEXT}"
  fi
  if [ -z  ${CP_PASSWORD} ]; then
    echo "${RED_TEXT}${ICON_FAIL} Missing Cloud Pak Password${RESET_TEXT}"
  fi
  if [ -z  ${CP_API_NAME} ]; then
    echo "${RED_TEXT}${ICON_FAIL} Missing Cloud Pak API Name${RESET_TEXT}"
  fi
  if  [ -z  ${CP_HOST}  ]  || [ -z  ${CP_USERNAME} ] || [ -z  ${CP_PASSWORD} ] || [ -z  ${CP_API_NAME} ]; then
    return 99
  fi
  #local API_FILE=${OCP_KUBECONFIG_DIR}/${CLUSTER_NAME}/${CP_API_NAME}-${CP_USERNAME}.apikey
  local API_FILE=$LOG_DIR/test.apikey
  if [ -f ${API_FILE} ]; then
      echo "Current API Key (${API_FILE})"
      cat ${API_FILE} | jq
  else
      echo "Getting New Access Token"
      local ACCESS_TOKEN=$(curl -s -k -X POST --header 'Content-Type: application/json' --header 'Accept: application/json'  -d '{"username": "'${CP_USERNAME}'", "password": "'${CP_PASSWORD}'", "grant_type": "password", "scope": "openid"}'  https://${CP_HOST}/icp4d-api/v1/authorize | tee  ${LOG_DIR}/getCloudPakAPIKey.log | jq .token 2>/dev/null | sed s'/\"//g')
      if [ -z ${ACCESS_TOKEN} ] || [ "$ACCESS_TOKEN}" == '' ];then
        echo "${RED_TEXT}${ICON_FAIL} Failed to login and get token${RESET_TEXT}" | tee  -a ${TEMP_DIR}/getCloudPakAPIKey.log
      	echo "CP_HOST=${CP_HOST}" | tee  -a ${LOG_DIR}/getCloudPakAPIKey.log
        echo "CP_USERNAME=${CP_USERNAME}" | tee  -a ${LOG_DIR}/getCloudPakAPIKey.log
      	echo "CP_PASSWORD=${CP_PASSWORD}" | tee  -a ${LOG_DIR}/getCloudPakAPIKey.log
        echo ""
      else
        echo "************************ Acces token: $ACCESS_TOKEN"
      	echo "Getting new API Key for ${CP_USERNAME} @ https://${CP_HOST}/usermgmt/v1/user/apiKey"
      	curl -s -k -X GET --header 'Content-Type: application/json' --header 'Accept: application/json' --header "Authorization: Bearer ${ACCESS_TOKEN}" -d '{"name": "daffy_platform_apikey", "description": "Description for Daffy platform apikey ","boundTo": "self"}' https://${CP_HOST}/usermgmt/v1/user/apiKey &>${API_FILE}
        ERROR_GETTING_API_KEY=$(cat ${API_FILE} | grep -c "Error\|exception\|x86_64")
        if [ ${ERROR_GETTING_API_KEY} -ge 1 ]; then
          cat ${API_FILE} | tee  -a ${LOG_DIR}/getCloudPakAPIKey.log
          rm -fR ${API_FILE} 2>/dev/null
        fi
      fi
  fi
}

cp4baServiceStatus()
{
  verifyAgainstDeploymentType $1
  case $1 in
    starter|Starter|demo) #| production|Production
        cp4baHighLevelStatus
        echo "Deployment Type                             :  ${CP4BA_DEPLOYMENT_TYPE}"
        cp4baStatusDump
        cp4baBAIStatus
        cp4baBaStudioStatus
        cp4baTMStatus
        cp4baNavigatorStatus
        cp4baBAWStatus
        cp4baBAMLStatus
        cp4baPFSStatus
        cp4baBAAStatus
        cp4baADSStatus
        cp4baODMStatus
        cp4baFilenetStatus
        ;;
  esac
}
verifyAgainstDeploymentType()
{
  if [ "$1" != "$DEPLOYMENT_TYPE_TO_LOWER" ]; then
    if [ "$1" == "starter" ] && [ "$DEPLOYMENT_TYPE_TO_LOWER" == "demo" ]; then
      return
    else
      echo "${RED_TEXT}*** No resources found for deployment type $1. *** ${RESET_TEXT}"
      consoleFooter "${CP_FUNCTION_NAME}"
      exit
    fi
  fi
}

cp4baServiceConsole()
{
  verifyAgainstDeploymentType $1
  case $1 in
    starter|Starter|demo)
        cp4baConfigMapDump
        #cp4baCommonServicesConsoleInfo
        cp4baODMConsole "Starter"
        cp4baFilenetConsole "Starter"
        cp4baBAIConsole "Starter"
        cp4baBAWConsole "Starter"
        cp4baBaStudioConsole "Starter"
        cp4baBAAConsole "Starter"
        cp4baADSConsole "Starter"
        cp4baTMConsole "Starter"
        cp4baNavigatorConsole "Starter"
        cp4baLDAPConsole "Starter"
        ;;
      production|Production)
        cp4baProductionServiceConsole
        ;;
  esac
  if [ "${CP4BA_ENABLE_SERVICE_OPS}" == "true" ]; then
    cp4baOPSDisplaySwaggerURL
  fi
}

cp4baHighLevelStatus()
{
  #validateCP4BAVersion
  local MESSAGE1=`oc get ICP4ACluster ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.conditions[0].message}' 2> /dev/null | head -n 1`
  if [ -z  "${MESSAGE1}"  ]; then
    MESSAGE1=`oc get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.conditions[0].reason}' 2> /dev/null | head -n 1`
  fi
  if [ "${MESSAGE1}"  == "---" ]; then
      MESSAGE1=`oc get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.conditions[0].message}' 2> /dev/null | head -n 2| tail -1 `
  fi
  local MESSAGE2=`oc get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.conditions[1].message}' 2> /dev/null | head -n 1`
  printHeaderMessage "CP4BA Service Status - High level"
  ####mainStatusHeader
  echo "CP4BA Version                               :  ${CP4BA_VERSION} ${CP4BA_IFIX}"
  echo "Project/Namespace                           :  ${CP4BA_AUTO_NAMESPACE}"
  echo "Zen Version                                 :  ${CP4BA_ZEN_VERSION}"
  echo "Message 1                                   :  ${MESSAGE1}"
  echo "Message 2                                   :  ${MESSAGE2}"
}

cp4baConfigMapDump()
{
  rm $LOG_DIR}/${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info.yaml 2> /dev/null
  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o yaml  &> ${LOG_DIR}/${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info.yaml
  echo "Config Map Dump                               : ${LOG_DIR}/${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info.yaml"
}

cp4baProductionServiceConsole()
{
  DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`
  if [ ! -z $DEPLOYMENT_TYPE_TO_LOWER ]; then
    if [ "production" != $DEPLOYMENT_TYPE_TO_LOWER ] ; then
      echo ""
      echo "${RED_TEXT}*** No resources found for deployment type production. *** ${RESET_TEXT}"
      echo ""
      return
    fi
  fi

 #Status dump
 rm ${LOG_DIR}/production-status.log 2> /dev/null
 echo '' > ${LOG_DIR}/production-status.log
 kubectl get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/production-status.log

  if [ $OLM_DEPLOYMENT == "true" ]; then
    kubectl get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.spec}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/production-status.log
  fi

  printHeaderMessage "Service Console - Common"
  cp4baCommonServicesConsoleInfo

  printHeaderMessage "Service Console"
  local CP4BA_CPD_URL=`oc get routes -n $CP4BA_AUTO_NAMESPACE | grep cpd | awk '{print $2}'`
  echo "Cloud Pak for Business Automation Dashboard   : ${BLUE_TEXT}https://${CP4BA_CPD_URL}${RESET_TEXT}"
  local CPD_USERNAME=`oc get secret ibm-iam-bindinfo-platform-auth-idp-credentials -n ${CP4BA_AUTO_NAMESPACE} -o go-template --template="{{.data.admin_username|base64decode}}" 2> /dev/null`
  local CPD_PASSWORD=`oc get secret ibm-iam-bindinfo-platform-auth-idp-credentials -n ${CP4BA_AUTO_NAMESPACE} -o go-template --template="{{.data.admin_password|base64decode}}" 2> /dev/null`
  echo "Admin Username                                : ${CPD_USERNAME}"
  echo "Admin Password                                : ${CPD_PASSWORD}"
  echo "Decisions Admin Username                      : ${CP4BA_DEPLOYMENT_PRODUCTION_ADMIN_USER}"
  echo "Decisions Admin Password                      : ${CP4BA_DEPLOYMENT_PRODUCTION_LDAP_PASSWORD}"
  #CP4BA_DECISION_IBM_COMMON_SERVICES_CPD_HOST=`oc get routes -n ${CP4BA_COMMON_SERVICES_NAMESPACE} | grep cp-console | awk '{print $2}'`
  #echo "***********************************"
  #echo  "${CP4BA_DECISION_CPD_URL} -- ${CP4BA_DEPLOYMENT_PRODUCTION_DECISIONS_ADMIN_USER} -- ${CP4BA_DEPLOYMENT_PRODUCTION_DECISIONS_LDAP_PASSWORD} -- ${NAMESPACE}"
  #echo "***********************************"

  getCloudPakAPIKey ${CP4BA_CPD_URL} ${CP4BA_DEPLOYMENT_PRODUCTION_DECISIONS_ADMIN_USER} ${CP4BA_DEPLOYMENT_PRODUCTION_DECISIONS_LDAP_PASSWORD} ${NAMESPACE} &>/dev/null
  local API_KEY_VALUE=`cat ${OCP_KUBECONFIG_DIR}/${CLUSTER_NAME}/${NAMESPACE}-${CP4BA_DEPLOYMENT_PRODUCTION_DECISIONS_ADMIN_USER}.apikey 2>/dev/null | jq . 2>/dev/null |  grep apiKey 2>/dev/null | awk '{print $2}' 2>/dev/null | sed "s/\"//g"  2>/dev/null| sed "s/,//g" 2>/dev/null`

  if [ -z "${API_KEY_VALUE}" ]; then
    echo "Decisions Admin Zen API Key                   : "
  else
    echo "Decisions Admin Zen API Key                   : ${API_KEY_VALUE}"
  fi

  CP4BA_BAI_DEPLOYMENT_STATUS=`cat ${LOG_DIR}/production-status.log | grep bai_deploy_status | awk '{print $2}'`

  ### DECISIONS_ADS Console
  local IS_ADS=`echo $DEPLOYMENT_PATTERN | grep "decisions_ads"`
  if [ ! -z $IS_ADS ]; then
    cp4baADSConsole "Production"
  elif [ $OLM_DEPLOYMENT == "true" ]; then
      local ADS_OLM_DEPLOYED=`cat $LOG_DIR/production-status.log | grep "olm_production_decisions_ads" |  awk 'NR==1' | awk '{print $2}'`
      #echo "******************** ADS_OLM_DEPLOYED: $ADS_OLM_DEPLOYED"
      if [ ! -z $ADS_OLM_DEPLOYED ] && [ ${ADS_OLM_DEPLOYED} == "true" ]; then
        #echo "******************** Calling ADS"
        cp4baADSConsole "Production"
      fi
  fi

  ### BAI Console
  if [ ! -z ${CP4BA_BAI_DEPLOYMENT_STATUS}  ] &&  [ ! ${CP4BA_BAI_DEPLOYMENT_STATUS} == "NotInstalled" ]; then
   cp4baBAIConsole "Production"
  fi

  ###cp4baBaStudioConsole "Production"

  ### BAW Console
  local IS_BAW=`echo $DEPLOYMENT_PATTERN | grep "workflow"`
  if [ ! -z $IS_BAW ]; then
    cp4baBAWConsole "Production"
    cp4baBAWWorklowAuthoringConsole "Production"
  elif [ $OLM_DEPLOYMENT == "true" ]; then
      local WORKFLOW_OLM_DEPLOYED=`cat $LOG_DIR/production-status.log | grep "olm_production_workflow" |  awk 'NR==1' | awk '{print $2}'`
      #echo "******************** WORKFLOW_OLM_DEPLOYED: $WORKFLOW_OLM_DEPLOYED"
      if [ ! -z $WORKFLOW_OLM_DEPLOYED ] && [ $WORKFLOW_OLM_DEPLOYED == "true" ]; then
        cp4baBAWConsole "Production"
        cp4baBAWWorklowAuthoringConsole "Production"
      fi
  fi

  ### BAA Console
  local IS_BAA=`echo $DEPLOYMENT_PATTERN | grep "application"`
  if [ ! -z $IS_BAA ]; then
    cp4baBAAConsole "Production"
  elif [ $OLM_DEPLOYMENT == "true" ]; then
      local BAA_OLM_DEPLOYED=`cat $LOG_DIR/production-status.log | grep "olm_production_application" |  awk 'NR==1' | awk '{print $2}'`
      #echo "******************** BAA_OLM_DEPLOYED: $BAA_OLM_DEPLOYED"
      if [ ! -z $BAA_OLM_DEPLOYED ] && [ $BAA_OLM_DEPLOYED == "true" ]; then
         cp4baBAAConsole "Production"
      fi
  fi

  ###cp4baRRConsole

  ### FNCM Console
  local IS_FNCM=`echo $DEPLOYMENT_PATTERN | grep "content"`
  if [ ! -z $IS_FNCM ] || [ "$CONTENT_DEPLOYMENT" == "true" ]; then
    cp4baFilenetConsole "Production"
  elif [ $OLM_DEPLOYMENT == "true" ]; then
      local FNCM_OLM_DEPLOYED=`cat $LOG_DIR/production-status.log | grep "olm_production_content" |  awk 'NR==1' | awk '{print $2}'`
      if [ ! -z $FNCM_OLM_DEPLOYED ] && [ ${FNCM_OLM_DEPLOYED} == "true" ]; then
        cp4baFilenetConsole "Production"
      fi
  fi

  ### Navigator Console
  cp4baNavigatorConsole "Production"
  ### TM Console
  cp4baTMConsole

  local IS_ODM=`echo $DEPLOYMENT_PATTERN | grep "decisions"`
  if [ ! -z $IS_ODM ] ; then #&& [ -z $IS_ADS ]
    cp4baODMConsole "Production"
  elif [ $OLM_DEPLOYMENT == "true" ]; then
      local ODM_OLM_DEPLOYED=`cat $LOG_DIR/production-status.log | grep "olm_production_decisions" |  awk 'NR==1' | awk '{print $2}'`
      #echo "******************** ODM: $ODM_OLM_DEPLOYED"
      if [ ! -z $ODM_OLM_DEPLOYED ] && [ ${ODM_OLM_DEPLOYED} == "true" ]; then
        #echo "******************** Calling ODM"
        cp4baODMConsole "Production"
      fi
  fi

  cp4baLDAPConsole "Production"
}

cp4baProductionServiceStatus()
{
  verifyAgainstDeploymentType "production"

  rm ${LOG_DIR}/production-status.log 2> /dev/null

  cp4baHighLevelStatus
  kubectl get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/production-status.log

  if [ $OLM_DEPLOYMENT == "true" ]; then
    kubectl get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.spec}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/production-status.log
  fi

  CP4BA_BAI_DEPLOYMENT_STATUS=`cat ${LOG_DIR}/production-status.log | grep bai_deploy_status | awk '{print $2}'`
  if [ ! -z ${CP4BA_BAI_DEPLOYMENT_STATUS}  ] &&  [ ! ${CP4BA_BAI_DEPLOYMENT_STATUS} == "NotInstalled" ]; then
    cp4baBAIStatus
  fi

  cp4baRRStatus
  cp4baTMStatus
  cp4baNavigatorStatus
  cp4baBaStudioStatus
  local IS_BAA=`echo $DEPLOYMENT_PATTERN | grep "application"`
  if [ ! -z $IS_BAA ]; then
    cp4baBAAStatus
  elif [ $OLM_DEPLOYMENT == "true" ]; then
      local BAA_OLM_DEPLOYED=`cat $LOG_DIR/production-status.log | grep "olm_production_application" |  awk 'NR==1' | awk '{print $2}'`
      #echo "******************** BAA_OLM_DEPLOYED: $BAA_OLM_DEPLOYED"
      if [ ! -z $BAA_OLM_DEPLOYED ] && [ $BAA_OLM_DEPLOYED == "true" ]; then
        cp4baBAAStatus
      fi
  fi

  local IS_BAW=`echo $DEPLOYMENT_PATTERN | grep "workflow"`
  if [ ! -z $IS_BAW ]; then
      cp4baBAWStatus
  elif [ $OLM_DEPLOYMENT == "true" ]; then
      local WORKFLOW_OLM_DEPLOYED=`cat $LOG_DIR/production-status.log | grep "olm_production_workflow" |  awk 'NR==1' | awk '{print $2}'`
      #echo "******************** WORKFLOW_OLM_DEPLOYED: $WORKFLOW_OLM_DEPLOYED"
      if [ ! -z $WORKFLOW_OLM_DEPLOYED ] && [ $WORKFLOW_OLM_DEPLOYED == "true" ]; then
        cp4baBAWStatus
      fi
  fi

  cp4baBAMLStatus
  cp4baPFSStatus

  local IS_ADS=`echo $DEPLOYMENT_PATTERN | grep "decisions_ads"`
  if [ ! -z $IS_ADS ]; then
    cp4baADSStatus
    local IS_NOT_ODM=`echo $DEPLOYMENT_PATTERN | grep "decisions"`
      if [ ! -z $IS_ODM ]; then ##TODO Check on this
        cp4baODMStatus
      fi
  elif [ $OLM_DEPLOYMENT == "true" ]; then
      local ADS_OLM_DEPLOYED=`cat $LOG_DIR/production-status.log | grep "olm_production_decisions_ads" |  awk 'NR==1' | awk '{print $2}'`
      #echo "******************** ADS_OLM_DEPLOYED: $ADS_OLM_DEPLOYED"
      if [ ! -z $ADS_OLM_DEPLOYED ] && [ ${ADS_OLM_DEPLOYED} == "true" ]; then
        #echo "******************** Calling ADS"
        cp4baADSStatus
      fi
  fi

  local IS_ODM=`echo $DEPLOYMENT_PATTERN | grep "decisions"`
  if [ ! -z $IS_ODM ]; then #&& [ -z $IS_ADS ]
    cp4baODMStatus
  elif [ $OLM_DEPLOYMENT == "true" ]; then
      local ODM_OLM_DEPLOYED=`cat $LOG_DIR/production-status.log | grep "olm_production_decisions" |  awk 'NR==1' | awk '{print $2}'`
      #echo "******************** ODM: $ODM_OLM_DEPLOYED"
      if [ ! -z $ODM_OLM_DEPLOYED ] && [ ${ODM_OLM_DEPLOYED} == "true" ]; then
        #echo "******************** Calling ODM"
        cp4baODMStatus
      fi
  fi

  local IS_FNCM=`echo $DEPLOYMENT_PATTERN | grep "content"`
  if [ ! -z $IS_FNCM ] || [ "$CONTENT_DEPLOYMENT" == "true" ]; then
    cp4baFilenetStatus
  elif [ $OLM_DEPLOYMENT == "true" ]; then
      local FNCM_OLM_DEPLOYED=`cat $LOG_DIR/production-status.log | grep "olm_production_content" |  awk 'NR==1' | awk '{print $2}'`
      if [ ! -z $FNCM_OLM_DEPLOYED ] && [ ${FNCM_OLM_DEPLOYED} == "true" ]; then
        cp4baFilenetStatus
      fi
  fi
}

cp4baCommonServicesConsoleInfo()
{
  local NAMESPACE=${CP4BA_COMMON_SERVICES_NAMESPACE}
  local IBM_COMMON_SERVICES_CPD_URL=`oc get routes -n ${CP4BA_COMMON_SERVICES_NAMESPACE} 2> /dev/null | grep cp-console | awk '{print $2}'`
  if [ -z "$IBM_COMMON_SERVICES_CPD_URL" ]; then
      local IBM_COMMON_SERVICES_CPD_URL=`oc get routes -n ${CP4BA_AUTO_NAMESPACE} 2> /dev/null | grep cp-console | awk '{print $2}'`
      local NAMESPACE=$CP4BA_AUTO_NAMESPACE
  fi

  echo "Cloud Pak Common Dashboard                    : ${BLUE_TEXT}https://${IBM_COMMON_SERVICES_CPD_URL}${RESET_TEXT}"
  COMMON_CPD_USERNAME=`oc get secret platform-auth-idp-credentials -n ${NAMESPACE} -o go-template --template="{{.data.admin_username|base64decode}}"`
  COMMON_CPD_PASSWORD=`oc get secret platform-auth-idp-credentials -n ${NAMESPACE} -o go-template --template="{{.data.admin_password|base64decode}}"`
  echo "Admin Username                                : ${COMMON_CPD_USERNAME}"
  echo "Admin Password                                : ${COMMON_CPD_PASSWORD}"
}

validateOCPAccess()
{
  printHeaderMessage "Validate OCP Access"

  OCP_CONSOLE_URL=`oc whoami --show-console 2> /dev/null`
  if [ -z  "${OCP_CONSOLE_URL}" ]; then
    echo "${RED_TEXT}${ICON_FAIL} ${RESET_TEXT} No access to cluster via oc command. PLease log in and try again...${RESET_TEXT}"
    consoleFooter "${CP_FUNCTION_NAME}"
    exit
  fi
  echo "${BLUE_TEXT}${ICON_SUCCESS} PASSED ${RESET_TEXT} Access to cluster via oc command${RESET_TEXT}"

  OCP_CLUSTER_VERSION=`oc get clusterversion 2> /dev/null | grep version | awk '{print  $2 }'`
  OCP_SERVER_VERSION=`oc get clusterversion 2> /dev/null | grep version | awk '{print  $2 }'`
  ADMIN_USER=`oc whoami`
  CP4BA_AUTO_NAMESPACE=`oc project -q`

  CLUSTER_NAME=`oc -n kube-system get configmap cluster-info -o yaml 2> /dev/null | grep '"name":'  | grep -v cluster-info | sed 's/"//g' | sed 's/,//g' | sed "s/name: //g" | sed "s/ //g"`
  #If cm cluster-info does not exist, check for cm cluster-config-v1
  if [ -z ${CLUSTER_NAME} ]; then
    CLUSTER_NAME=`oc -n kube-system get configmap cluster-config-v1 -o yaml 2> /dev/null | grep name | awk 'NR==3' | awk '{print $2}'`
  fi
  if [ -z ${CLUSTER_NAME} ]; then
    CLUSTER_NAME=`oc describe infrastructure/cluster 2> /dev/null | grep "Infrastructure Name" | awk '{print $3}'`
  fi

  CLUSTER_DOMAIN=`oc describe infrastructure/cluster 2> /dev/null | grep "Etcd Discovery Domain" | awk '{print $4}'`

  if [ -z "$CLUSTER_DOMAIN" ]; then
     CLUSTER_BASE_DOMAIN=`oc -n kube-system get configmap cluster-config-v1 -o yaml 2> /dev/null| grep baseDomain | awk '{print $2}'`
     if [ ! -z "$CLUSTER_BASE_DOMAIN" ]; then
        CLUSTER_DOMAIN="$CLUSTER_NAME"."$CLUSTER_BASE_DOMAIN"
     fi
  fi

  if [ -z "$CLUSTER_DOMAIN" ]; then
     CLUSTER_BASE_DOMAIN=`oc -n kube-system get configmap cluster-config -o yaml 2> /dev/null | grep "baseDomain" | awk '{print $2}'`
     if [ ! -z $CLUSTER_BASE_DOMAIN ]; then
        CLUSTER_DOMAIN="$CLUSTER_NAME"."$CLUSTER_BASE_DOMAIN"
     fi
  fi

  # Load APIs and Operator versions
  operatorAndAPIVersions
  export CP4BA_AUTO_NAMESPACE=$CP4BA_AUTO_NAMESPACE
  export CLUSTER_NAME=$CLUSTER_NAME
  export CLUSTER_DOMAIN=$CLUSTER_DOMAIN

  echo "Cluster name                                  : $CLUSTER_NAME "
  echo "Cluster version                               : $OCP_CLUSTER_VERSION "
  echo "Console URL                                   : $OCP_CONSOLE_URL "
  echo "Logged in as user                             : $ADMIN_USER"
  echo "Using namespace                               : $CP4BA_AUTO_NAMESPACE"
  echo "Deployment name                               : $CP4BA_DEPLOYMENT_NAME"
  echo "Deployment type                               : $CP4BA_DEPLOYMENT_TYPE"
  echo "OLM deployment                                : $OLM_DEPLOYMENT"

  DEPLOYMENT_PATTERN=`kubectl get ICP4ACluster $CP4BA_DEPLOYMENT_NAME 2> /dev/null -o jsonpath="{.spec.shared_configuration.sc_deployment_patterns}"`
  echo "Deployment patterns                           : $DEPLOYMENT_PATTERN"
  if [ "$CONTENT_DEPLOYMENT" == "true" ]; then
    OPTIONAL_COMPONENTS=`kubectl get Content $CP4BA_DEPLOYMENT_NAME 2> /dev/null -o jsonpath="{.spec.content_optional_components}"`
  else
   OPTIONAL_COMPONENTS=`kubectl get ICP4ACluster $CP4BA_DEPLOYMENT_NAME 2> /dev/null -o jsonpath="{.spec.shared_configuration.sc_optional_components}"`
  fi
  echo "Optional components                           : $OPTIONAL_COMPONENTS"

  if [ -z ${CP4BA_DEPLOYMENT_NAME} ]; then
   echo "${RED_TEXT} *** No deployment found in namespace $CP4BA_AUTO_NAMESPACE. ***  ${RESET_TEXT}"
   consoleFooter "${CP_FUNCTION_NAME}"
   exit
  fi
}

cp4baLDAPConsole()
{
#  printHeaderMessage "LDAP Console "
  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o=jsonpath='{.data.openldap-access-info}' &> ${LOG_DIR}/ldap-console.log
#  local USERNAME=`cat  ${LOG_DIR}/ldap-console.log | grep "username"  | awk '{print $2}'| head -n 1`
#  echo "Username                                      : ${USERNAME}"
#  local PASSWORD=`cat  ${LOG_DIR}/ldap-console.log | grep "password"  | awk '{print $2}'| head -n 1`
#  echo "Password                                      : ${PASSWORD}"
#  ##################################################
#  local LDAP_URL=`cat  ${LOG_DIR}/ldap-console.log | grep "ldapwebconsole\|phpldapadmin"  | awk '{print $1}'| head -n 1`
#  echo "LDAP URL                                      : ${BLUE_TEXT}${LDAP_URL}${RESET_TEXT}"
}

operatorAndAPIVersions()
{
  OPERATOR_NAME=`oc get csv  2> /dev/null | grep "ibm-cp4a-operator" | awk '{print $1}'`
  CONTENT_OPERATOR_NAME=`oc get csv 2> /dev/null | grep "ibm-content-operator" | awk '{print $1}'`

  if [ -n "${OPERATOR_NAME}" ]; then
    CP4BA_VERSION=`oc describe csv $OPERATOR_NAME  | grep "Cloudpak Version" | awk '{print $3}'`
  elif [ -n "${CONTENT_OPERATOR_NAME}" ]; then
    CP4BA_VERSION=`oc describe csv $CONTENT_OPERATOR_NAME  | grep "Cloudpak Version" | awk '{print $3}'`
  fi

  CP4BA_ZEN_VERSION=`timeout 30 oc get ZenService  iaf-zen-cpdservice -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.currentVersion} {"\n"}' 2> /dev/null`
  if [ -z ${CP4BA_ZEN_VERSION} ]; then
    CP4BA_ZEN_VERSION="NotInstalled"
  fi

  CONTENT_DEPLOYMENT="false"
  CP4BA_DEPLOYMENT_NAME=`oc get ICP4ACluster  2> /dev/null | awk 'NR==2' | awk '{print $1}'`
  OLM_DEPLOYMENT="false"
  if [ -z "$CP4BA_DEPLOYMENT_NAME" ]; then
    CP4BA_DEPLOYMENT_NAME=`oc get Content 2> /dev/null | awk 'NR==2' | awk '{print $1}'`
    ###CP4BA_DEPLOYMENT_TYPE=`oc get Content $CONTENT_DEPLOYMENT_NAME -o=jsonpath='{.spec.shared_configuration.sc_deployment_type} {"\n"}'`  2> /dev/null
    CP4BA_DEPLOYMENT_TYPE=`oc get Content $CP4BA_DEPLOYMENT_NAME -o=jsonpath='{.spec.content_deployment_type} {"\n"}'`  2> /dev/null
    CONTENT_DEPLOYMENT="true"
  else
    CP4BA_DEPLOYMENT_TYPE=`oc get ICP4ACluster $CP4BA_DEPLOYMENT_NAME -o=jsonpath='{.spec.shared_configuration.sc_deployment_type} {"\n"}'`  2> /dev/null
  fi

  if [ -z $CP4BA_DEPLOYMENT_TYPE ]; then
    CP4BA_DEPLOYMENT_TYPE=`oc get ICP4ACluster $CP4BA_DEPLOYMENT_NAME -o=jsonpath='{.spec.olm_deployment_type} {"\n"}'`  2> /dev/null
    OLM_DEPLOYMENT="true"
  fi

  DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`
  # Just saw deployment type with trailing space, quick fix...
  DEPLOYMENT_TYPE_TO_LOWER=`echo $DEPLOYMENT_TYPE_TO_LOWER | awk '{gsub(/^ +| +$/,"")}1'`

  export CP4BA_DEPLOYMENT_TYPE=$CP4BA_DEPLOYMENT_TYPE
  export CP4BA_DEPLOYMENT_NAME=$CP4BA_DEPLOYMENT_NAME
  export DEPLOYMENT_TYPE_TO_LOWER=$DEPLOYMENT_TYPE_TO_LOWER
  export OLM_DEPLOYMENT=$OLM_DEPLOYMENT
  export CONTENT_DEPLOYMENT=$CONTENT_DEPLOYMENT
}

cleanUp()
{
 cd $DIR
 rm -Rf logs 2> /dev/null
}

cp4baStatusDump()
{
  rm $LOG_DIR/${CP4BA_DEPLOYMENT_NAME}-cp4ba-status-info.yaml 2> /dev/null
  rm $LOG_DIR/${CP4BA_DEPLOYMENT_NAME}-cp4ba-status-info-temp.yaml 2> /dev/null

  kubectl get ICP4ACluster ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null 1> $LOG_DIR/${CP4BA_DEPLOYMENT_NAME}-cp4ba-status-info.yaml

  if [ -s $LOG_DIR/${CP4BA_DEPLOYMENT_NAME}-cp4ba-status-info.yaml ]; then
    cat  $LOG_DIR/${CP4BA_DEPLOYMENT_NAME}-cp4ba-status-info.yaml | jq . >  $LOG_DIR/${CP4BA_DEPLOYMENT_NAME}-cp4ba-status-info-temp.yaml
    mv $LOG_DIR/${CP4BA_DEPLOYMENT_NAME}-cp4ba-status-info-temp.yaml $LOG_DIR/${CP4BA_DEPLOYMENT_NAME}-cp4ba-status-info.yaml
    echo "Status Dump                                 :  $LOG_DIR/${CP4BA_DEPLOYMENT_NAME}-cp4ba-status-info.yaml"
  else
    echo "Status Dump                                 :  Not Found"
    echo ""
  fi
}

cp4baServiceProbe()
{
    printHeaderMessage "CP4BA Service Readiness/Liveness"
    cd $DIR

    helper/post-install/probe/checkURL4BA.sh $CLUSTER_DOMAIN $CP4BA_AUTO_NAMESPACE $PROBE_USER_API_KEY $PROBE_USER_NAME $PROBE_USER_PASSWORD $PROBE_VERBOSE

    echo
    consoleFooter "${CP_FUNCTION_NAME}"
    exit
}
