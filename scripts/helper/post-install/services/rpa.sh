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

cp4baRPAConsole()
{
    printHeaderMessage "Robotic Process Automation Server Console"
    local RPA_HOST=`oc get routes -n ${CP4BA_RPA_SERVER_NAMESPACE} | grep cpd | awk '{print $2}'`
    if [ -n "${RPA_HOST}" ]; then
      local RPA_URL="https://${RPA_HOST}/rpa/ui/#/en-US/home"
    fi
    echo "RPA Web Console     :      ${BLUE_TEXT}${RPA_URL}${RESET_TEXT}"
    echo "RPA User ID         :      ${CP4BA_RPA_SERVER_FIRST_TENANT_OWNER_ID}"
    echo "RPA Password        :      ${CP4BA_RPA_SERVER_FIRST_TENANT_OWNER_PASSWORD}"

}
cp4baRPAServerStatus()
{
  OCP_SERVER_VERSION=`oc version | grep Server | awk '{print $3}'`
  printHeaderMessage "CP4BA Service Status - RPA Server"
  RPA_SERVER_STATUS=`oc get RoboticProcessAutomation ${CP4BA_RPA_SERVER_NAME} -n ${CP4BA_RPA_SERVER_NAMESPACE} -o jsonpath='{.status.conditions[0].message}' 2> /dev/null | head -n 1`
  RPA_SERVER_VERSION=`oc get RoboticProcessAutomation ${CP4BA_RPA_SERVER_NAME} -n ${CP4BA_RPA_SERVER_NAMESPACE} -o jsonpath='{.spec.version}' 2> /dev/null`
  echo "Status                                      :  ${RPA_SERVER_STATUS}"
  if [ -z "${RPA_SERVER_VERSION}" ]; then
    RPA_SERVER_VERSION="NotInstalled"
  fi
  echo "Version                                     :  ${RPA_SERVER_VERSION}"
}
