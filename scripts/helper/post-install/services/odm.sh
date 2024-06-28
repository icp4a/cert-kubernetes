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

cd $DIR
mkdir logs 2> /dev/null
LOG_DIR=$DIR/logs

cp4baODMConsole()
{
  printHeaderMessage "ODM - Operational Decision Manager Console"
  local CP4BA_DEPLOYMENT_TYPE=${1}

  ODM_USERNAME=`oc get secret platform-auth-idp-credentials -n ibm-common-services 2> /dev/null -o go-template --template="{{.data.admin_username|base64decode}}"`
  if [ -z $ODM_USERNAME ]; then
    ODM_USERNAME=`oc get secret platform-auth-idp-credentials -n $CP4BA_AUTO_NAMESPACE 2> /dev/null -o go-template --template="{{.data.admin_username|base64decode}}"`
  fi

  ODM_PASSWORD=`oc get secret platform-auth-idp-credentials -n ibm-common-services 2> /dev/null -o go-template --template="{{.data.admin_password|base64decode}}"`
  if [ -z $ODM_PASSWORD ]; then
      ODM_PASSWORD=`oc get secret platform-auth-idp-credentials -n $CP4BA_AUTO_NAMESPACE 2> /dev/null -o go-template --template="{{.data.admin_password|base64decode}}"`
  fi

  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o=jsonpath='{.data.odm-access-info}' 2>/dev/null &> ${LOG_DIR}/odm-console.log
  if [ "${CP4BA_DEPLOYMENT_TYPE}" == "Starter" ]; then
    ODM_USERNAME=`cat  ${LOG_DIR}/odm-console.log | grep "username"  | awk '{print $4}'`
    echo "Decisions Admin Username                      : ${ODM_USERNAME}"
    ODM_PASSWORD=`cat  ${LOG_DIR}/odm-console.log | grep "password"  | awk '{print $4}'`
    echo "Decisions Admin Password                      : ${ODM_PASSWORD}"
  fi
  if [ "${CP4BA_DEPLOYMENT_TYPE}" == "Production" ]; then
    echo "Username                                      : ${ODM_USERNAME}"
    echo "Password                                      : ${ODM_PASSWORD}"
    echo "Decisions Admin Username                      : ${CP4BA_DEPLOYMENT_PRODUCTION_DECISIONS_ADMIN_USER}"
    echo "Decisions Admin Password                      : ${CP4BA_DEPLOYMENT_PRODUCTION_DECISIONS_LDAP_PASSWORD}"
  fi

  ODM_DC_URL=`cat  ${LOG_DIR}/odm-console.log | grep "ODM Decision Center"  | awk '{print $5}'`
  echo "Decision Center                               : ${BLUE_TEXT}${ODM_DC_URL}${RESET_TEXT}"
  echo "Decisions Trust Store URL                     : ${BLUE_TEXT}${ODM_DC_URL}/assets/truststore.jks${RESET_TEXT}"
  ODM_DR_URL=`cat  ${LOG_DIR}/odm-console.log | grep "ODM Decision Runner"  | awk '{print $5}'`
  echo "Decision Runner                               : ${BLUE_TEXT}${ODM_DR_URL}${RESET_TEXT}"
  ODM_RES_URL=`cat  ${LOG_DIR}/odm-console.log | grep "ODM Decision Server Console"  | awk '{print $6}'`
  echo "Decision Server Console                       : ${BLUE_TEXT}${ODM_RES_URL}${RESET_TEXT}"
  ODM_RESRUN_URL=`cat  ${LOG_DIR}/odm-console.log | grep "ODM Decision Server Runtime"  | awk '{print $6}'`
  echo "Decision Server Runtime                       : ${BLUE_TEXT}${ODM_RESRUN_URL}${RESET_TEXT}"
}

cp4baODMStatus()
{
    printHeaderMessage "CP4BA Service Status - Operational Decision Manager"
    rm ${LOG_DIR}/odm-status.log 2> /dev/null
    echo '' > ${LOG_DIR}/odm-status.log

    kubectl get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components.odm}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/odm-status.log

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionCenterDeployment | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionCenterDeployment                 :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionCenterService | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionCenterService                    :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionCenterZenIntegration | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionCenterZenIntegration             :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionRunnerDeployment | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionRunnerDeployment                 :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionRunnerService | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionRunnerService                    :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionRunnerZenIntegration | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionRunnerZenIntegration             :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionServerConsoleDeployment | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionServerConsoleDeployment          :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionServerConsoleService | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionServerConsoleService             :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionServerConsoleZenIntegration | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionServerConsoleZenIntegration      :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionServerRuntimeDeployment | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionServerRuntimeDeployment          :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionServerRuntimeService | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionServerRuntimeService             :  ${CP4BA_ODM_STATUS}"

    CP4BA_ODM_STATUS=`cat ${LOG_DIR}/odm-status.log | grep odmDecisionServerRuntimeZenIntegration | awk '{print $2}'`
    if [ -z ${CP4BA_ODM_STATUS}  ]; then
      CP4BA_ODM_STATUS="NotInstalled"
    fi
    echo "odmDecisionServerRuntimeZenIntegration      :  ${CP4BA_ODM_STATUS}"
}