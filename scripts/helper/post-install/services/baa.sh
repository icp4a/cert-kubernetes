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

cp4baBAAStatus()
{
  printHeaderMessage "CP4BA Service Status - Business Automation Application"
  rm ${LOG_DIR}/odm-status.log 2> /dev/null
  kubectl get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components.ae-icp4adeploy-workspace-aae}'  2> /dev/null | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/baa-status.log

    CP4BA_BAA_STATUS=`cat ${LOG_DIR}/baa-status.log | grep "service" | awk '{print $2}'`
    if [ -z ${CP4BA_BAA_STATUS}  ]; then
      CP4BA_BAA_STATUS="NotInstalled"
    fi
    echo "workspace-aae service                       :  ${CP4BA_BAA_STATUS}"

    kubectl get ICP4ACluster  ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components.ae-icp4adeploy-pbk}'  2> /dev/null | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/baa-status.log

      CP4BA_BAA_STATUS=`cat ${LOG_DIR}/baa-status.log | grep "service" | awk '{print $2}'`
      if [ -z ${CP4BA_BAA_STATUS}  ]; then
        CP4BA_BAA_STATUS="NotInstalled"
      fi
      echo "pbk service                                 :  ${CP4BA_BAA_STATUS}"
}

cp4baBAAConsole()
{
  printHeaderMessage "BAA - Business Automation Application Console"
  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.baa-access-info}' &> ${LOG_DIR}/baa-console.log

  DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`
  if [ "$DEPLOYMENT_TYPE_TO_LOWER" == "production" ]; then
    NAV_USERNAME=`oc get secret ibm-ban-secret -o go-template --template="{{.data.appLoginUsername|base64decode}}"`
    echo "Username                                      : ${NAV_USERNAME}"
    NAV_PASSWORD=`oc get secret ibm-ban-secret -o go-template --template="{{.data.appLoginPassword|base64decode}}"`
    echo "Password                                      : ${NAV_PASSWORD}"
  else
      NAV_USERNAME=`cat  ${LOG_DIR}/baa-console.log | grep "username"  | awk '{print $2}'| head -n 1`
      echo "Username                                      : ${NAV_USERNAME}"
      NAV_PASSWORD=`cat  ${LOG_DIR}/baa-console.log | grep "password"  | awk '{print $2}'| head -n 1`
      echo "Password                                      : ${NAV_PASSWORD}"
  fi

  BAA_URL=`cat  ${LOG_DIR}/baa-console.log | grep "Business Automation Application" '-A1' | awk 'NR==2{print $1}'`
  echo "Business Automation Application               : ${BLUE_TEXT}${BAA_URL}${RESET_TEXT}"
}
