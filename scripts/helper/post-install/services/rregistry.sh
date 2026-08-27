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

cp4baRRStatus()
{
  printHeaderMessage "CP4BA Service Status - Resource Registry"
  rm ${LOG_DIR}/rr-status.log 2> /dev/null
  if [[ $CONTENT_DEPLOYMENT == "true" ]]; then
    kubectl get Foundation  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components.resource-registry}' 2> /dev/null | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/rr-status.log
  else
    kubectl get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components.resource-registry}' 2> /dev/null | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/rr-status.log
  fi
  #.decisions_ads
  RR_CLUSTER_STATUS=`cat ${LOG_DIR}/rr-status.log | grep rrCluster | awk '{print $2}'`
  if [ -z ${RR_CLUSTER_STATUS}  ]; then
    CP4BA_ODM_STATUS="NotInstalled"
  fi
  echo "rrCluster                                   :  ${RR_CLUSTER_STATUS}"
  RR_CLUSTER_SERVICE=`cat ${LOG_DIR}/rr-status.log | grep rrService | awk '{print $2}'`
  if [ -z ${RR_CLUSTER_SERVICE}  ]; then
    CP4BA_ODM_STATUS="NotInstalled"
  fi
  echo "rrService                                   :  ${RR_CLUSTER_SERVICE}"

}
cp4baRRConsole()
{
  local CP4BA_DEPLOYMENT_TYPE=${1}
}
