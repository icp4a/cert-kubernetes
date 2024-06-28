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

cp4baNavigatorConsole()
{
  printHeaderMessage "Navigator Console"
  rm ${LOG_DIR}/navigator-console.log 2> /dev/null

  #################################################
  #navigator
  #################################################
  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.navigator-access-info}' &> ${LOG_DIR}/navigator-console.log

  if [ "$DEPLOYMENT_TYPE_TO_LOWER" == "production" ]; then
    NAV_USERNAME=`oc get secret ibm-ban-secret -o go-template --template="{{.data.appLoginUsername|base64decode}}"`
    echo "Username                                      : ${NAV_USERNAME}"
    NAV_PASSWORD=`oc get secret ibm-ban-secret -o go-template --template="{{.data.appLoginPassword|base64decode}}"`
    echo "Password                                      : ${NAV_PASSWORD}"
  else
      NAV_USERNAME=`cat  ${LOG_DIR}/navigator-console.log | grep "username"  | awk '{print $2}'| head -n 1`
      echo "Username                                      : ${NAV_USERNAME}"
      NAV_PASSWORD=`cat  ${LOG_DIR}/navigator-console.log | grep "password"  | awk '{print $2}'| head -n 1`
      echo "Password                                      : ${NAV_PASSWORD}"
  fi

  NAV_CP4BA_URL=`cat  ${LOG_DIR}/navigator-console.log | grep "Business Automation Navigator for CP4BA"  | awk '{print $6}'| head -n 1`
  echo "Business Automation Navigator for CP4BA       : ${BLUE_TEXT}${NAV_CP4BA_URL}${RESET_TEXT}"
  NAV_FNCM_URL=`cat  ${LOG_DIR}/navigator-console.log | grep "Business Automation Navigator for FNCM"  | awk '{print $6}'| head -n 1`
  echo "Business Automation Navigator for FNCM        : ${BLUE_TEXT}${NAV_FNCM_URL}${RESET_TEXT}"
  #################################################
}

cp4baNavigatorStatus()
{
  printHeaderMessage "CP4BA Service Status - Navigator"
  rm ${LOG_DIR}/filenet-status.log 2> /dev/null
  if [[ $CONTENT_DEPLOYMENT == "true" ]]; then
    kubectl get Content ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/navigator-status.log
  else
    kubectl get ICP4ACluster ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/navigator-status.log
  fi
  
  #################################################
  #Navigator
  #################################################
  DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`

  CP4BA_NAVIGATOR_DEPLOYMENT_STATUS=`cat ${LOG_DIR}/navigator-status.log | grep navigatorDeployment | awk '{print $2}'`
  if [ -z "${CP4BA_NAVIGATOR_DEPLOYMENT_STATUS}" ]; then
      CP4BA_NAVIGATOR_DEPLOYMENT_STATUS="NotInstalled"
  fi
  echo "navigatorDeployment                         :  ${CP4BA_NAVIGATOR_DEPLOYMENT_STATUS}"

  CP4BA_NAVIGATOR_SERVICE_STATUS=`cat ${LOG_DIR}/navigator-status.log | grep navigatorService | awk '{print $2}'`
  if [ -z ${CP4BA_NAVIGATOR_SERVICE_STATUS}  ]; then
    CP4BA_NAVIGATOR_SERVICE_STATUS="NotInstalled"
  fi
  echo "navigatorService                            :  ${CP4BA_NAVIGATOR_SERVICE_STATUS}"

  CP4BA_NAVIGATOR_SETORAGE_STATUS=`cat ${LOG_DIR}/navigator-status.log | grep navigatorStorage | awk '{print $2}'`
  if [ -z ${CP4BA_NAVIGATOR_SETORAGE_STATUS}  ]; then
    CP4BA_NAVIGATOR_SETORAGE_STATUS="NotInstalled"
  fi
  echo "navigatorStorage                            :  ${CP4BA_NAVIGATOR_SETORAGE_STATUS}"

  CP4BA_NAVIGATOR_ZEN_INEGRATION_STATUS=`cat ${LOG_DIR}/navigator-status.log | grep navigatorZenIntegration | awk '{print $2}'`
  if [ -z ${CP4BA_NAVIGATOR_ZEN_INEGRATION_STATUS}  ]; then
    CP4BA_NAVIGATOR_ZEN_INEGRATION_STATUS="NotInstalled"
  fi
  echo "navigatorZenIntegration                     :  ${CP4BA_NAVIGATOR_ZEN_INEGRATION_STATUS}"

}
