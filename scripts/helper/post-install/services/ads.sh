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

cp4baADSStatus()
{
  printHeaderMessage "CP4BA Service Status - Automation Decision Services"
  rm ${LOG_DIR}/ads-status.log 2> /dev/null
  kubectl get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/ads-status.log

  local adsCredentialsServiceDeployment_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsCredentialsServiceDeployment | awk '{print $2}'`
  if [ -z ${adsCredentialsServiceDeployment_STATUS}  ]; then
    adsCredentialsServiceDeployment_STATUS="NotInstalled"
  fi
  echo "adsCredentialsServiceDeployment             :  ${adsCredentialsServiceDeployment_STATUS}"

  local adsCredentialsServiceService_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsCredentialsServiceService | awk '{print $2}'`
  if [ -z ${adsCredentialsServiceService_STATUS}  ]; then
    adsCredentialsServiceService_STATUS="NotInstalled"
  fi
  echo "adsCredentialsServiceService                :  ${adsCredentialsServiceService_STATUS}"

  local adsDownloadServiceDeployment_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsDownloadServiceDeployment | awk '{print $2}'`
  if [ -z ${adsDownloadServiceDeployment_STATUS}  ]; then
    adsDownloadServiceDeployment_STATUS="NotInstalled"
  fi
  echo "adsDownloadServiceDeployment                :  ${adsDownloadServiceDeployment_STATUS}"

  local adsDownloadServiceService_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsDownloadServiceService | awk '{print $2}'`
  if [ -z ${adsDownloadServiceService_STATUS}  ]; then
    adsDownloadServiceService_STATUS="NotInstalled"
  fi
  echo "adsDownloadServiceService                   :  ${adsDownloadServiceService_STATUS}"

  local adsFrontDeployment_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsFrontDeployment | awk '{print $2}'`
  if [ -z ${adsFrontDeployment_STATUS}  ]; then
    adsFrontDeployment_STATUS="NotInstalled"
  fi
  echo "adsFrontDeployment                          :  ${adsFrontDeployment_STATUS}"

  local adsFrontZenIntegration_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsFrontZenIntegration | awk '{print $2}'`
  if [ -z ${adsFrontZenIntegration_STATUS}  ]; then
    adsFrontZenIntegration_STATUS="NotInstalled"
  fi
  echo "adsFrontZenIntegration                     :  ${adsFrontZenIntegration_STATUS}"

  local adsGitServiceService_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsGitServiceService | awk '{print $2}'`
  if [ -z ${adsGitServiceService_STATUS}  ]; then
    adsGitServiceService_STATUS="NotInstalled"
  fi
  echo "adsGitServiceService                        :  ${adsGitServiceService_STATUS}"

  local adsLtpaCreationJob_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsLtpaCreationJob | awk '{print $2}'`
  if [ -z ${adsLtpaCreationJob_STATUS}  ]; then
    adsLtpaCreationJob_STATUS="NotInstalled"
  fi
  echo "adsLtpaCreationJob                          :  ${adsLtpaCreationJob_STATUS}"

  local adsMongoService_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsMongoService | awk '{print $2}'`
  if [ -z ${adsMongoService_STATUS}  ]; then
    adsMongoService_STATUS="NotInstalled"
  fi
  echo "adsMongoService                             :  ${adsMongoService_STATUS}"

  local adsParsingServiceService_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsParsingServiceService | awk '{print $2}'`
  if [ -z ${adsParsingServiceService_STATUS}  ]; then
    adsParsingServiceService_STATUS="NotInstalled"
  fi
  echo "adsParsingServiceService                    :  ${adsParsingServiceService_STATUS}"

#  local adsRestApiService_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsRestApiService | awk '{print $2}'`
#  if [ -z ${adsMongoService_STATUS}  ]; then
#       adsRestApiService_STATUS="NotInstalled"
#  fi
#  echo "adsRestApiService                           :  ${adsRestApiService_STATUS}"

  local adsRestApiService_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsRestApiService | awk '{print $2}'`
  if [ -z ${adsRestApiService_STATUS}  ]; then
       adsRestApiService_STATUS="NotInstalled"
  fi
  echo "adsRestApiService                           :  ${adsRestApiService_STATUS}"

  local adsRuntimeBaiRegistrationJob_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsRuntimeBaiRegistrationJob | awk '{print $2}'`
  if [ -z ${adsRuntimeBaiRegistrationJob_STATUS}  ]; then
       adsRuntimeBaiRegistrationJob_STATUS="NotInstalled"
  fi
  echo "adsRuntimeBaiRegistrationJob                :  ${adsRuntimeBaiRegistrationJob_STATUS}"

  local adsRunServiceService_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsRunServiceService | awk '{print $2}'`
  if [ -z ${adsRunServiceService_STATUS}  ]; then
       adsRunServiceService_STATUS="NotInstalled"
  fi
  echo "adsRunServiceService                        :  ${adsRunServiceService_STATUS}"

  local adsRuntimeBaiRegistrationJob_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsRuntimeBaiRegistrationJob | awk '{print $2}'`
  if [ -z ${adsRuntimeBaiRegistrationJob_STATUS}  ]; then
       adsRuntimeBaiRegistrationJob_STATUS="NotInstalled"
  fi
  echo "adsRuntimeBaiRegistrationJob                :  ${adsRuntimeBaiRegistrationJob_STATUS}"

  local adsRuntimeServiceService_STATUS=`cat ${LOG_DIR}/ads-status.log | grep adsRuntimeServiceService | awk '{print $2}'`
  if [ -z ${adsRuntimeServiceService_STATUS}  ]; then
       adsRuntimeServiceService_STATUS="NotInstalled"
  fi
  echo "adsRuntimeServiceService                    :  ${adsRuntimeServiceService_STATUS}"
}

cp4baADSConsole()
{
  printHeaderMessage "ADS - Automation Decision Services Console"
  rm ${LOG_DIR}/ads-console.log 2> /dev/null

  kubectl get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.ADS-runtime-access-info}' &> ${LOG_DIR}/ads-console.log

  DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`
  if [ "$DEPLOYMENT_TYPE_TO_LOWER" == "production" ]; then
    NAV_USERNAME=`oc get secret ibm-ban-secret -o go-template --template="{{.data.appLoginUsername|base64decode}}"`
    echo "Username                                      : ${NAV_USERNAME}"
    NAV_PASSWORD=`oc get secret ibm-ban-secret -o go-template --template="{{.data.appLoginPassword|base64decode}}"`
    echo "Password                                      : ${NAV_PASSWORD}"
  else
      NAV_USERNAME=`cat  ${LOG_DIR}/ads-console.log | grep "username"  | awk '{print $2}'| head -n 1`
      echo "Username                                      : ${NAV_USERNAME}"
      NAV_PASSWORD=`cat  ${LOG_DIR}/ads-console.log | grep "password"  | awk '{print $2}'| head -n 1`
      echo "Password                                      : ${NAV_PASSWORD}"
  fi

  Runtime_URL=`cat  ${LOG_DIR}/ads-console.log | grep "Runtime URL"  | awk '{print $3}' | head -n 1`
  echo "Runtime URL                                   : ${BLUE_TEXT}${Runtime_URL}${RESET_TEXT}"
}
