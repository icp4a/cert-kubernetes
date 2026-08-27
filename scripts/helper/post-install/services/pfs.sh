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

cp4baPFSStatus()
{
    printHeaderMessage "CP4BA Service Status - PFS"
    rm ${LOG_DIR}/pfs-status.log 2> /dev/null

    DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`

    kubectl get ICP4ACluster ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/pfs-status.log

    CP4BA_PFS_DEPLOYMENT_STATUS=`cat ${LOG_DIR}/pfs-status.log | grep pfsDeployment | awk '{print $2}'`
    if [ -z ${CP4BA_PFS_DEPLOYMENT_STATUS}  ]; then
      CP4BA_PFS_DEPLOYMENT_STATUS="NotInstalled"
    fi
    echo "pfsDeployment                               :  ${CP4BA_PFS_DEPLOYMENT_STATUS}"
    CP4BA_PFS_SERVICE_STATUS=`cat ${LOG_DIR}/pfs-status.log| grep pfsService | awk '{print $2}'`
    if [ -z ${CP4BA_PFS_SERVICE_STATUS}  ]; then
      CP4BA_PFS_SERVICE_STATUS="NotInstalled"
    fi
    echo "pfsService                                  :  ${CP4BA_PFS_SERVICE_STATUS}"
    CP4BA_PFS_ZEN_INTEGRATION_STATUS=`cat ${LOG_DIR}/pfs-status.log| grep pfsZenIntegration | awk '{print $2}'`
    if [ -z "${CP4BA_PFS_ZEN_INTEGRATION_STATUS}"  ]; then
      CP4BA_PFS_ZEN_INTEGRATION_STATUS="NotInstalled"
    fi
    echo "pfsZenIntegration                           :  ${CP4BA_PFS_ZEN_INTEGRATION_STATUS}"
}

cp4baPFSConsole()
{
  local CP4BA_DEPLOYMENT_TYPE=${1}
}

