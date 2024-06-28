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

cp4baBAWStatus()
{
    printHeaderMessage "CP4BA Service Status - Workflow"
    rm ${LOG_DIR}/workflow-status.log 2> /dev/null
    rm ${LOG_DIR}/baw-status.log 2> /dev/null
    DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`

    kubectl get ICP4ACluster ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components.workflow-authoring}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/workflow-status.log

     if [ $DEPLOYMENT_TYPE_TO_LOWER == "production" ]; then
        WF_AUTHORING_STATUS=`cat ${LOG_DIR}/workflow-status.log | grep service | awk '{print $2}'`
        if [ -z "${WF_AUTHORING_STATUS}"  ]; then
          WF_AUTHORING_STATUS="NotInstalled"
        fi
        echo "workflow-authoring service                  :  ${WF_AUTHORING_STATUS}"

        kubectl get ICP4ACluster ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components.baw}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/baw-status.log

        CP4BA_BAW_DEPLOYMENT_STATUS=`cat ${LOG_DIR}/baw-status.log| grep bawDeployment |  awk 'NR==1' | awk '{print $2}'`
        if [ -z "${CP4BA_BAW_DEPLOYMENT_STATUS}"  ]; then
          CP4BA_BAW_DEPLOYMENT_STATUS="NotInstalled"
        fi
        echo "bawDeployment                               :  ${CP4BA_BAW_DEPLOYMENT_STATUS}"

        CP4BA_BAW_SERVICE_STATUS=`cat ${LOG_DIR}/baw-status.log| grep bawService |  awk 'NR==1' | awk '{print $2}'`
        if [ -z "${CP4BA_BAW_SERVICE_STATUS}"  ]; then
          CP4BA_BAW_SERVICE_STATUS="NotInstalled"
        fi
        echo "bawService                                  :  ${CP4BA_BAW_SERVICE_STATUS}"

        CP4BA_BAW_ZEN_INTEGRATION_STATUS=`cat ${LOG_DIR}/baw-status.log| grep bawZenIntegration |  awk 'NR==1' | awk '{print $2}'`
        if [ -z "${CP4BA_BAW_ZEN_INTEGRATION_STATUS}"  ]; then
          CP4BA_BAW_ZEN_INTEGRATION_STATUS="NotInstalled"
        fi
        echo "bawZenIntegration                          :  ${CP4BA_BAW_ZEN_INTEGRATION_STATUS}"
     fi
}

cp4baBAWConsole()
{
  rm ${LOG_DIR}/bastudio-access-info.log 2> /dev/null
  rm ${LOG_DIR}/baw-authoring-access-info.log 2> /dev/null

  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.bastudio-access-info}' &> ${LOG_DIR}/bastudio-access-info.log
  if [ ! -s "${LOG_DIR}/bastudio-access-info.log" ]; then
    return
  fi

  local CP4BA_DEPLOYMENT_TYPE=${1}

  BAW_USERNAME=`oc get secret platform-auth-idp-credentials -n ibm-common-services 2> /dev/null -o go-template --template="{{.data.admin_username|base64decode}}"`
  if [ -z $BAW_USERNAME ]; then
    BAW_USERNAME=`oc get secret platform-auth-idp-credentials -n $CP4BA_AUTO_NAMESPACE 2> /dev/null -o go-template --template="{{.data.admin_username|base64decode}}"`
  fi

  BAW_PASSWORD=`oc get secret platform-auth-idp-credentials -n ibm-common-services 2> /dev/null -o go-template --template="{{.data.admin_password|base64decode}}"`
  if [ -z $BAW_PASSWORD ]; then
      BAW_PASSWORD=`oc get secret platform-auth-idp-credentials -n $CP4BA_AUTO_NAMESPACE 2> /dev/null -o go-template --template="{{.data.admin_password|base64decode}}"`
  fi

  printHeaderMessage "BAW - Business Automation Workflow, BA Studio Console"

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
  if [ $DEPLOYMENT_TYPE_TO_LOWER == "production" ]; then
    BA_WORKFLOW_EXTERNAL_REST_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Business Automation Workflow REST API Tester"  | awk '{print $7}'`
    echo "Business Automation Workflow REST API Tester  : ${BLUE_TEXT}${BA_WORKFLOW_EXTERNAL_REST_URL}${RESET_TEXT}"
  fi
  BA_WORKFLOW_PORTAL_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Business Automation Process Portal"  | awk '{print $5}'`
  echo "Business Automation Process Portal            : ${BLUE_TEXT}${BA_WORKFLOW_PORTAL_URL}${RESET_TEXT}"
  BA_CASE_CLIENT_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Business Automation Case Client"  | awk '{print $5}'`
  echo "Business Automation Case Client               : ${BLUE_TEXT}${BA_CASE_CLIENT_URL}${RESET_TEXT}"
  BA_CASE_CLIENT_BUILDER_URL=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "Business Automation Case Builder"  | awk '{print $5}'`
  echo "Business Automation Case Builder              : ${BLUE_TEXT}${BA_CASE_CLIENT_BUILDER_URL}${RESET_TEXT}"
}
cp4baBAWWorklowAuthoringConsole()
{
  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.workflow-authoring-access-info}' &> ${LOG_DIR}/baw-authoring-access-info.log
  if [ ! -s "${LOG_DIR}/baw-authoring-access-info.log" ]; then
    return
  fi

  local CP4BA_DEPLOYMENT_TYPE=${1}
  BAW_USERNAME=`oc get secret platform-auth-idp-credentials -n ibm-common-services 2> /dev/null -o go-template --template="{{.data.admin_username|base64decode}}"`
  if [ -z $BAW_USERNAME ]; then
    BAW_USERNAME=`oc get secret platform-auth-idp-credentials -n $CP4BA_AUTO_NAMESPACE 2> /dev/null -o go-template --template="{{.data.admin_username|base64decode}}"`
  fi

  BAW_PASSWORD=`oc get secret platform-auth-idp-credentials -n ibm-common-services 2> /dev/null -o go-template --template="{{.data.admin_password|base64decode}}"`
  if [ -z $BAW_PASSWORD ]; then
      BAW_PASSWORD=`oc get secret platform-auth-idp-credentials -n $CP4BA_AUTO_NAMESPACE 2> /dev/null -o go-template --template="{{.data.admin_password|base64decode}}"`
  fi

  printHeaderMessage "BAW - Business Automation Workflow Authoring Console"

  DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`

  if [ "${CP4BA_DEPLOYMENT_TYPE}" == "Starter" ]; then
    BAW_USERNAME=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "username:"  | awk '{print $2}'| head -n 1`
    echo "User Name                                     : ${BAW_USERNAME}"
    BAW_PASSWORD=`cat  ${LOG_DIR}/bastudio-access-info.log | grep "password"  | awk '{print $2}'| head -n 1`
    echo "Password                                      : ${BAW_PASSWORD}"
  fi
  if [ "${CP4BA_DEPLOYMENT_TYPE}" == "Production" ]; then
    echo "Workflow Admin Username                       : ${NAV_USERNAME}"
    echo "Workflow Admin Password                       : ${NAV_PASSWORD}"
  fi

  designer_URL=`cat  ${LOG_DIR}/baw-authoring-access-info.log | grep "Visit designers from Cloudpak Dashboard"  | awk '{print $6}'`
  echo "Visit designers from Cloudpak Dashboard       : ${BLUE_TEXT}${designer_URL}${RESET_TEXT}"

  portal_URL=`cat  ${LOG_DIR}/baw-authoring-access-info.log | grep "Business Automation Workflow Authoring Portal"  | awk '{print $6}'`
  echo "BAW Authoring Portal                          : ${BLUE_TEXT}${portal_URL}${RESET_TEXT}"

  externalBase_URL=`cat  ${LOG_DIR}/baw-authoring-access-info.log | grep "Business Automation Workflow Authoring External base URL"  | awk '{print $8}'`
  echo "BAW Authoring External base URL               : ${BLUE_TEXT}${externalBase_URL}${RESET_TEXT}"

  caseBuilder_URL=`cat  ${LOG_DIR}/baw-authoring-access-info.log | grep "Business Automation Case Builder"  | awk '{print $5}'`
  echo "Business Automation Case Builder              : ${BLUE_TEXT}${caseBuilder_URL}${RESET_TEXT}"

  BA_CASE_CLIENT_URL=`cat  ${LOG_DIR}/baw-authoring-access-info.log | grep "Business Automation Case Client"  | awk '{print $5}'`
  echo "Business Automation Case Client               : ${BLUE_TEXT}${BA_CASE_CLIENT_URL}${RESET_TEXT}"

  WORKPLACE_URL=`cat  ${LOG_DIR}/baw-authoring-access-info.log | grep "IBM Workplace"  | awk '{print $3}'`
  echo "IBM Workplace                                 : ${BLUE_TEXT}${WORKPLACE_URL}${RESET_TEXT}"
}
