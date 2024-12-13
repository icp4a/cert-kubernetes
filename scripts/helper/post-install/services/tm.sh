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

cp4baTMStatus()
{
  printHeaderMessage "CP4BA Service Status - Task Manager $1"
  rm ${LOG_DIR}/tm-status.log 2> /dev/null
  if [[ $CONTENT_DEPLOYMENT == "true" ]]; then
    kubectl get Content  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components.tm}' 2> /dev/null | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/tm-status.log
  else
    kubectl get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components.tm}' 2> /dev/null | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/tm-status.log
  fi
  TM_DEPLOYMENT_STATUS=`cat ${LOG_DIR}/tm-status.log | grep tmDeployment | awk '{print $2}'`
  if [ -z ${TM_DEPLOYMENT_STATUS}  ]; then
    TM_DEPLOYMENT_STATUS="NotInstalled"
  fi
  echo "tmDeployment                                :  ${TM_DEPLOYMENT_STATUS}"

  TM_SERVICE_STATUS=`cat ${LOG_DIR}/tm-status.log | grep tmService | awk '{print $2}'`
  if [ -z ${TM_SERVICE_STATUS}  ]; then
    TM_SERVICE_STATUS="NotInstalled"
  fi
  echo "tmService                                   :  ${TM_SERVICE_STATUS}"

  TM_ROUTE_STATUS=`cat ${LOG_DIR}/tm-status.log | grep tmRoute | awk '{print $2}'`
  if [ -z ${TM_ROUTE_STATUS}  ]; then
    TM_ROUTE_STATUS="NotInstalled"
  fi
  echo "tmRoute                                     :  ${TM_ROUTE_STATUS}"

  TM_STORAGE_STATUS=`cat ${LOG_DIR}/tm-status.log | grep tmStorage | awk '{print $2}'`
  if [ -z ${TM_STORAGE_STATUS}  ]; then
    TM_STORAGE_STATUS="NotInstalled"
  fi
  echo "tmStorage                                   :  ${TM_STORAGE_STATUS}"
}

cp4baTMConsole()
{
    printHeaderMessage "TM - Task Manager Console"
    rm ${LOG_DIR}/tm-console.log 2> /dev/null
    echo '' > ${LOG_DIR}/tm-console.log

    oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.taskmanager-access-info}' &> ${LOG_DIR}/tm-console.log
    TM_URL=`cat  ${LOG_DIR}/tm-console.log | grep "Task Manager"  | awk '{print $3}'| head -n 1`
    echo "Task Manager                                  : ${BLUE_TEXT}${TM_URL}${RESET_TEXT}"
}
