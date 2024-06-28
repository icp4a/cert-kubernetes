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

cp4baBAMLStatus()
{
    printHeaderMessage "CP4BA Service Status - BAML"
    rm ${LOG_DIR}/baml-status.log 2> /dev/null
    DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`

    kubectl get ICP4ACluster ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/baml-status.log

#   if [ $DEPLOYMENT_TYPE_TO_LOWER == "production" ]; then
#   fi

    CP4BA_BAML_DEPLOYMENT_STATUS=`cat ${LOG_DIR}/baml-status.log| grep bamlDeployStatus | awk '{print $2}'`
    if [ -z "${CP4BA_BAML_DEPLOYMENT_STATUS}"  ]; then
      CP4BA_BAML_DEPLOYMENT_STATUS="NotInstalled"
    fi
    echo "bamlDeployStatus                            :  ${CP4BA_BAML_DEPLOYMENT_STATUS}"

    bamlServiceStatus_STATUS=`cat ${LOG_DIR}/baml-status.log | grep bamlServiceStatus | awk '{print $2}'`
    if [ -z "${bamlServiceStatus_STATUS}"  ]; then
      bamlServiceStatus_STATUS="NotInstalled"
    fi
    echo "bamlServiceStatus                           :  ${bamlServiceStatus_STATUS}"
}

cp4baBAMLConsole()
{

  local CP4BA_DEPLOYMENT_TYPE=${1}
    BAW_USERNAME=`oc get secret platform-auth-idp-credentials -n ibm-common-services 2> /dev/null -o go-template --template="{{.data.admin_username|base64decode}}"`
  if [ -z $BAW_USERNAME ]; then
    BAW_USERNAME=`oc get secret platform-auth-idp-credentials -n $CP4BA_AUTO_NAMESPACE 2> /dev/null -o go-template --template="{{.data.admin_username|base64decode}}"`
  fi

  BAW_PASSWORD=`oc get secret platform-auth-idp-credentials -n ibm-common-services 2> /dev/null -o go-template --template="{{.data.admin_password|base64decode}}"`
  if [ -z $BAW_PASSWORD ]; then
      BAW_PASSWORD=`oc get secret platform-auth-idp-credentials -n $CP4BA_AUTO_NAMESPACE 2> /dev/null -o go-template --template="{{.data.admin_password|base64decode}}"`
  fi

  printHeaderMessage "Workflow, BAML"
  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.bastudio-access-info}' &> ${LOG_DIR}/bastudio-access-info.log

  DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`

  if [ "${CP4BA_DEPLOYMENT_TYPE}" == "Starter" ]; then
    BAW_USERNAME=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "username:"  | awk '{print $2}'| head -n 1`
    echo "User Name                                     : ${BAW_USERNAME}"
    BAW_PASSWORD=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "password"  | awk '{print $2}'| head -n 1`
    echo "Password                                      : ${BAW_PASSWORD}"
  fi
  if [ "${CP4BA_DEPLOYMENT_TYPE}" == "Production" ]; then
    #TODO: Double check on this
    echo "Workflow Admin Username                       : ${NAV_USERNAME}"
    echo "Workflow Admin Password                       : ${NAV_PASSWORD}"
  fi

  CP_DASHBOARD_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Cloudpak Dashboard"  | awk '{print $3}'`
  echo "Cloudpak Dashboard                            : ${BLUE_TEXT}${CP_DASHBOARD_URL}${RESET_TEXT}"
  BA_WORKPLACE_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Business Automation Workplace"  | awk '{print $4}'`
  echo "Business Automation Workplace                 : ${BLUE_TEXT}${BA_WORKPLACE_URL}${RESET_TEXT}"
  BA_WORKFLOW_EXTERNAL_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Business Automation Workflow External base URL"  | awk '{print $7}'`
  echo "Business Automation Workflow External URL     : ${BLUE_TEXT}${BA_WORKFLOW_EXTERNAL_URL}${RESET_TEXT}"
  BA_WORKFLOW_EXTERNAL_REST_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Business Automation Workflow REST API Tester"  | awk '{print $7}'`
  echo "Business Automation Workflow REST API Tester  : ${BLUE_TEXT}${BA_WORKFLOW_EXTERNAL_REST_URL}${RESET_TEXT}"
  BA_WORKFLOW_PORTAL_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Business Automation Process Portal"  | awk '{print $5}'`
  echo "Business Automation Process Portal            : ${BLUE_TEXT}${BA_WORKFLOW_PORTAL_URL}${RESET_TEXT}"
  BA_CASE_CLIENT_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Business Automation Case Client"  | awk '{print $5}'`
  echo "Business Automation Case Client               : ${BLUE_TEXT}${BA_CASE_CLIENT_URL}${RESET_TEXT}"
  BA_CASE_CLIENT_BUILDER_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Business Automation Case Builder"  | awk '{print $5}'`
  echo "Business Automation Case Builder              : ${BLUE_TEXT}${BA_CASE_CLIENT_BUILDER_URL}${RESET_TEXT}"
}

