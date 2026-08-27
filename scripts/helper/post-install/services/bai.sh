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

cp4baBAIStatus()
{
  printHeaderMessage "CP4BA Service Status - Insights"
  rm ${LOG_DIR}/bai-status.log 2> /dev/null
  echo '' > ${LOG_DIR}/bai-status.log

  kubectl get ICP4ACluster ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/bai-status.log

  #################################################
  #BAI
  #################################################
  CP4BA_BAI_DEPLOYMENT_STATUS=`cat ${LOG_DIR}/bai-status.log | grep bai_deploy_status | awk '{print $2}'`
  if [ -z ${CP4BA_BAI_DEPLOYMENT_STATUS}  ]; then
    CP4BA_BAI_DEPLOYMENT_STATUS="NotInstalled"
  fi
  echo "bai_deploy_status:                          :  ${CP4BA_BAI_DEPLOYMENT_STATUS}"
  CP4BA_BAI_INSIGHT_ENGINE_STATUS=`cat ${LOG_DIR}/bai-status.log | grep insightsEngine | awk '{print $2}'`
  if [ -z ${CP4BA_BAI_INSIGHT_ENGINE_STATUS}  ]; then
    CP4BA_BAI_INSIGHT_ENGINE_STATUS="NotInstalled"
  fi
  echo "insightsEngine:                             :  ${CP4BA_BAI_INSIGHT_ENGINE_STATUS}"

}
cp4baBAIConsole()
{
  local CP4BA_DEPLOYMENT_TYPE=${1}
  printHeaderMessage "BAI - Business Automation Insights Console"
  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o yaml &> ${LOG_DIR}/bai-console.yaml

  if [ "${CP4BA_DEPLOYMENT_TYPE}" == "Starter" ]; then
    NAV_USERNAME=`cat  ${LOG_DIR}/bai-console.yaml | grep "Business Performance Center Username"  | awk '{print $5}'| head -n 1`
    echo "Business Performance Center Username          : ${NAV_USERNAME}"
    NAV_PASSWORD=`cat  ${LOG_DIR}/bai-console.yaml | grep "Business Performance Center Password"  | awk '{print $5}'| head -n 1`
    echo "Business Performance Center Password          : ${NAV_PASSWORD}"
  fi
  if [ "${CP4BA_DEPLOYMENT_TYPE}" == "Production" ]; then
    echo "Business Performance Center Username          : Located in your LDAP Sever"
    echo "Business Performance Center Password          : Located in your LDAP Sever"
  fi
  #################################################
  #BAI Desktop
  #################################################
  NAV_CP4BA_URL=`cat  ${LOG_DIR}/bai-console.yaml | grep "Business Performance Center URL"  | awk '{print $5}'| head -n 1`
  echo "Business Performance Center URL               : ${BLUE_TEXT}${NAV_CP4BA_URL}${RESET_TEXT}"
  BAI_Desktop_URL=`cat  ${LOG_DIR}/bai-console.yaml | grep "BAI Desktop"  | awk '{print $3}'| head -n 1`
  echo "BAI Desktop                                   : ${BLUE_TEXT}${BAI_Desktop_URL}${RESET_TEXT}"
  #################################################
  #Elastic Search
  #################################################
  if [ "${CP4BA_DEPLOYMENT_TYPE}" == "Starter" ]; then
    ELS_USERNAME=`cat  ${LOG_DIR}/bai-console.yaml | grep "Elasticsearch Username"  | awk '{print $3}'| head -n 1`
    echo "Elasticsearch Username                        : ${ELS_USERNAME}"
    ELS_PASSWORD=`cat  ${LOG_DIR}/bai-console.yaml | grep "Elasticsearch Password"  | awk '{print $3}'| head -n 1`
    echo "Elasticsearch Password                        : ${ELS_PASSWORD}"
  fi
  if [ "${CP4BA_DEPLOYMENT_TYPE}" == "Production" ]; then
    echo "Elasticsearch Username                        : Located in your LDAP Sever"
    echo "Elasticsearch Password                        : Located in your LDAP Sever"
  fi
  ELS_CP4BA_URL=`cat  ${LOG_DIR}/bai-console.yaml | grep "Elasticsearch URL"  | awk '{print $3}'| head -n 1`
  echo "Elasticsearch URL                             : ${BLUE_TEXT}${ELS_CP4BA_URL}${RESET_TEXT}"

  Apicurio_URL=`cat  ${LOG_DIR}/bai-console.yaml | grep "Apicurio URL"  | awk '{print $3}'| head -n 1`
  echo "Apicurio URL                                  : ${BLUE_TEXT}${Apicurio_URL}${RESET_TEXT}"
}
