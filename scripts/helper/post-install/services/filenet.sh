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
LOG_FILE_STATUS=${LOG_DIR}/filenet-status.log
LOG_FILE_CONSOLE=${LOG_DIR}/filenet-console.log

cp4baFilenetConsole()
{
  printHeaderMessage "Content Console"

  rm ${LOG_DIR}/filenet-console.log 2> /dev/null
  rm ${LOG_DIR}/filenet-cpds-console.log 2> /dev/null

  echo '' > ${LOG_DIR}/filenet-console.log
  echo '' > ${LOG_DIR}/filenet-cpds-console.log

  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.cpe-access-info}' &> ${LOG_DIR}/filenet-console.log

  DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`
  if [ "$DEPLOYMENT_TYPE_TO_LOWER" == "production" ]; then
    NAV_USERNAME=`oc get secret ibm-fncm-secret -o go-template --template="{{.data.appLoginUsername|base64decode}}"`
    echo "Username                                      : ${NAV_USERNAME}"
    NAV_PASSWORD=`oc get secret ibm-fncm-secret -o go-template --template="{{.data.appLoginPassword|base64decode}}"`
    echo "Password                                      : ${NAV_PASSWORD}"
  else
      NAV_USERNAME=`cat  ${LOG_DIR}/filenet-console.log | grep "username"  | awk '{print $2}'| head -n 1`
      echo "Username                                      : ${NAV_USERNAME}"
      NAV_PASSWORD=`cat  ${LOG_DIR}/filenet-console.log | grep "password"  | awk '{print $2}'| head -n 1`
      echo "Password                                      : ${NAV_PASSWORD}"
  fi

  #################################################
  #ICCSAP
  #################################################
  if [ $DEPLOYMENT_TYPE_TO_LOWER == "production" ]; then
    oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.ICCSAP-access-info}' &> ${LOG_DIR}/filenet-console.log
    local SAP_SSL_Webport_URL=`cat  ${LOG_DIR}/filenet-console.log | grep "Content Collector for SAP SSL Webport URL"  | awk '{print $8}' | head -n 1`
    echo "Content Collector for SAP SSL Webport URL     : ${BLUE_TEXT}$SAP_SSL_Webport_URL${RESET_TEXT}"
    local SAP_PLUGIN_URL=`cat  ${LOG_DIR}/filenet-console.log | grep "Content Collector for SAP Plugin URL"  | awk '{print $7}' | head -n 1`
    echo "Content Collector for SAP Plugin URL          : ${BLUE_TEXT}$SAP_PLUGIN_URL${RESET_TEXT}"
  fi
  #################################################
  #CPE
  #################################################
  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.cpe-access-info}' &> ${LOG_DIR}/filenet-console.log
  CPE_ADMIN_URL=`cat  ${LOG_DIR}/filenet-console.log | grep "Content Platform Engine administration"  | awk '{print $5}' | head -n 1`
  echo "Content Platform Engine administration        : ${BLUE_TEXT}${CPE_ADMIN_URL}${RESET_TEXT}"
  CPE_HC_URL=`cat  ${LOG_DIR}/filenet-console.log | grep "Content Platform Engine health check"  | awk '{print $6}' | head -n 1`
  echo "Content Platform Engine health check          : ${BLUE_TEXT}${CPE_HC_URL}${RESET_TEXT}"
  CPE_PING_URL=`cat  ${LOG_DIR}/filenet-console.log | grep "Content Platform Engine ping page"  | awk '{print $6}' | head -n 1`
  echo "Content Platform Engine ping page             : ${BLUE_TEXT}${CPE_PING_URL}${RESET_TEXT}"
  FILENET_PING_URL=`cat  ${LOG_DIR}/filenet-console.log | grep "FileNet Process Services ping page"  | awk '{print $6}' | head -n 1`
  #################################################
  #Filenet
  #################################################
  echo "FileNet Process Services ping page            : ${BLUE_TEXT}${FILENET_PING_URL}${RESET_TEXT}"
  FILENET_PROCESS_SERVICES_URL=`cat  ${LOG_DIR}/filenet-console.log | grep "FileNet Process Services details page"  | awk '{print $6}' | head -n 1`
  echo "FileNet Process Services details page         : ${BLUE_TEXT}${FILENET_PROCESS_SERVICES_URL}${RESET_TEXT}"

  CPE_WS_URL=`cat  ${LOG_DIR}/filenet-console.log | grep "FileNet P8 Content Engine Web Service page"  | awk '{print $8}' | head -n 1`
  echo "FileNet P8 Content Engine Web Service page    : ${BLUE_TEXT}${CPE_WS_URL}${RESET_TEXT} "

  CPE_PEWS_URL=`cat  ${LOG_DIR}/filenet-console.log | grep "FileNet Process Engine Web Service(PEWS) page"  | awk '{print $7}' | head -n 1`
  echo "FileNet Process Engine Web Service(PEWS) page : ${BLUE_TEXT}${CPE_PEWS_URL}${RESET_TEXT} "

  CPE_CBRDashboard_URL=`cat  ${LOG_DIR}/filenet-console.log | grep "Content Search Services health check"  | awk '{print $6}' | head -n 1`
  echo "Content Search Services health check          : ${BLUE_TEXT}${CPE_CBRDashboard_URL}${RESET_TEXT} "

  #################################################
  #navigator
  #################################################
#  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.navigator-access-info}' &> ${LOG_DIR}/navigator-console.log
#  NAV_CP4BA_URL=`cat  ${LOG_DIR}/navigator-console.log | grep "Business Automation Navigator for CP4BA"  | awk '{print $6}'| head -n 1`
#  echo "Business Automation Navigator for CP4BA       : ${BLUE_TEXT}${NAV_CP4BA_URL}${RESET_TEXT}"
#  NAV_FNCM_URL=`cat  ${LOG_DIR}/navigator-console.log | grep "Business Automation Navigator for FNCM"  | awk '{print $6}'| head -n 1`
#  echo "Business Automation Navigator for FNCM        : ${BLUE_TEXT}${NAV_FNCM_URL}${RESET_TEXT}"
  #################################################
  #GraphQL
  #################################################
  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.graphql-access-info}' &> ${LOG_DIR}/graphql-console.log
  CONTENT_SERVICES_GRAPHQL_URL=`cat  ${LOG_DIR}/graphql-console.log | grep "Content Services GraphQL"  | awk '{print $4}'| head -n 1`
  echo "Content Services GraphQL                      : ${BLUE_TEXT}${CONTENT_SERVICES_GRAPHQL_URL}${RESET_TEXT}"

  #################################################
  #CPDS
  #################################################
  oc get cm ${CP4BA_DEPLOYMENT_NAME}-cp4ba-access-info -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.data.cpds-access-info}' &> ${LOG_DIR}/filenet-cpds-console.log
  local CPDS_URL=`cat  ${LOG_DIR}/filenet-cpds-console.log | grep "Content Project Deployment Service"  | awk '{print $5}' | head -n 1`
  echo "Content Project Deployment Service            : ${BLUE_TEXT}$CPDS_URL${RESET_TEXT}"
}

cp4baFilenetStatus()
{
    printHeaderMessage "CP4BA Service Status - Content"
    rm ${LOG_DIR}/filenet-status.log 2> /dev/null
    echo '' > ${LOG_DIR}/filenet-status.log
    DEPLOYMENT_TYPE_TO_LOWER=`echo $CP4BA_DEPLOYMENT_TYPE | awk '{print tolower($0)}'`

    if [ "$CONTENT_DEPLOYMENT" == "true" ]; then
      kubectl get Content ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/filenet-status.log
    else
      kubectl get ICP4ACluster ${CP4BA_DEPLOYMENT_NAME} -n ${CP4BA_AUTO_NAMESPACE} -o jsonpath='{.status.components}' 2> /dev/null  | jq  . |  sed 's/\"//g' | sed 's/,//g'  | sed 's/://g' | sed 's/{//g' | sed 's/}//g'  &> ${LOG_DIR}/filenet-status.log
    fi

    #################################################
    #CPE
    #################################################
    CP4BA_CPE_DEPLOYMENT_STATUS=`cat ${LOG_FILE_STATUS} | grep cpeDeployment | awk '{print $2}'`
    if [ -z ${CP4BA_CPE_DEPLOYMENT_STATUS}  ]; then
      CP4BA_CPE_DEPLOYMENT_STATUS="NotInstalled"
    fi
    echo "cpeDeployment                               :  ${CP4BA_CPE_DEPLOYMENT_STATUS}"

    CP4BA_CPE_JDBC_DRIVER_STATUS=`cat ${LOG_FILE_STATUS} | grep cpeJDBCDriver | awk '{print $2}'`
    if [ -z ${CP4BA_CPE_JDBC_DRIVER_STATUS}  ]; then
      CP4BA_CPE_JDBC_DRIVER_STATUS="NotInstalled"
    fi
    echo "cpeJDBCDriver                               :  ${CP4BA_CPE_JDBC_DRIVER_STATUS}"

    CP4BA_CPE_ROUTE_STATUS=`cat ${LOG_FILE_STATUS} | grep cpeRoute | awk '{print $2}'`
    if [ -z ${CP4BA_CPE_ROUTE_STATUS}  ]; then
      CP4BA_CPE_ROUTE_STATUS="NotInstalled"
    fi
    echo "cpeRoute                                    :  ${CP4BA_CPE_ROUTE_STATUS}"

    CP4BA_CPE_SERVICE_STATUS=`cat ${LOG_FILE_STATUS} | grep cpeService | awk '{print $2}'`

    if [ -z ${CP4BA_CPE_SERVICE_STATUS}  ]; then
      CP4BA_CPE_SERVICE_STATUS="NotInstalled"
    fi
    echo "cpeService                                  :  ${CP4BA_CPE_SERVICE_STATUS}"

    CP4BA_CPE_STORAGE_STATUS=`cat ${LOG_FILE_STATUS} | grep cpeStorage | awk '{print $2}'`
    if [ -z ${CP4BA_CPE_STORAGE_STATUS}  ]; then
      CP4BA_CPE_STORAGE_STATUS="NotInstalled"
    fi
    echo "cpeStorage                                  :  ${CP4BA_CPE_STORAGE_STATUS}"

  CP4BA_CPE_ZEN_INEGRATION_STATUS=`cat ${LOG_FILE_STATUS} | grep cpeZenIntegration | awk '{print $2}'`
  if [ -z ${CP4BA_CPE_ZEN_INEGRATION_STATUS}  ]; then
    CP4BA_CPE_ZEN_INEGRATION_STATUS="NotInstalled"
  fi
  echo "cpeZenIntegration                           :  ${CP4BA_CPE_ZEN_INEGRATION_STATUS}"

  #################################################
  #CMIS
  #################################################
  CP4BA_CMIS_DEPLOYMENT_STATUS=`cat ${LOG_FILE_STATUS} | grep cmisDeployment | awk '{print $2}'`
  if [ -z ${CP4BA_CMIS_DEPLOYMENT_STATUS}  ]; then
    CP4BA_CMIS_DEPLOYMENT_STATUS="NotInstalled"
  fi
  echo "cmisDeployment                              :  ${CP4BA_CMIS_DEPLOYMENT_STATUS}"
  CP4BA_CMIS_ROUTE_STATUS=`cat ${LOG_FILE_STATUS} | grep cmisRoute | awk '{print $2}'`
  if [ -z ${CP4BA_CMIS_ROUTE_STATUS}  ]; then
    CP4BA_CMIS_ROUTE_STATUS="NotInstalled"
  fi
  echo "cmisRoute                                   :  ${CP4BA_CMIS_ROUTE_STATUS}"
  CP4BA_CMIS_SERVICE_STATUS=`cat ${LOG_FILE_STATUS} | grep cmisService | awk '{print $2}'`
  if [ -z ${CP4BA_CMIS_SERVICE_STATUS}  ]; then
    CP4BA_CMIS_SERVICE_STATUS="NotInstalled"
  fi
  echo "cmisService                                 :  ${CP4BA_CMIS_SERVICE_STATUS}"
  CP4BA_CMIS_STORAGE_STATUS=`cat ${LOG_FILE_STATUS} | grep cmisStorage | awk '{print $2}'`
  if [ -z ${CP4BA_CMIS_STORAGE_STATUS}  ]; then
    CP4BA_CMIS_STORAGE_STATUS="NotInstalled"
  fi
  echo "cmisStorage                                 :  ${CP4BA_CMIS_STORAGE_STATUS}"
  CP4BA_CMIS_ZEN_STATUS=`cat ${LOG_FILE_STATUS} | grep cmisZenIntegration | awk '{print $2}'`
  if [ -z ${CP4BA_CMIS_ZEN_STATUS}  ]; then
    CP4BA_CMIS_ZEN_STATUS="NotInstalled"
  fi
  echo "cmisZenIntegration                          :  ${CP4BA_CMIS_ZEN_STATUS}"

  #################################################
  #IER
  #################################################
  CP4BA_IER_DEPLOYMENT_STATUS=`cat ${LOG_FILE_STATUS} | grep ierDeployment | awk '{print $2}'`
  if [ -z ${CP4BA_IER_DEPLOYMENT_STATUS}  ]; then
    CP4BA_IER_DEPLOYMENT_STATUS="NotInstalled"
  fi
  echo "ierDeployment                               :  ${CP4BA_IER_DEPLOYMENT_STATUS}"

  CP4BA_IER_ROUTE_STATUS=`cat ${LOG_FILE_STATUS} | grep ierRoute | awk '{print $2}'`
  if [ -z ${CP4BA_IER_ROUTE_STATUS}  ]; then
    CP4BA_IER_ROUTE_STATUS="NotInstalled"
  fi
  echo "ierRoute                                    :  ${CP4BA_IER_ROUTE_STATUS}"

  CP4BA_IER_SERVICE_STATUS=`cat ${LOG_FILE_STATUS} | grep ierService | awk '{print $2}'`
  if [ -z ${CP4BA_IER_SERVICE_STATUS}  ]; then
    CP4BA_IER_SERVICE_STATUS="NotInstalled"
  fi
  echo "ierService                                  :  ${CP4BA_IER_SERVICE_STATUS}"

  CP4BA_IER_STORAGE_STATUS=`cat ${LOG_FILE_STATUS} | grep ierStorageCheck | awk '{print $2}'`
  if [ -z ${CP4BA_IER_STORAGE_STATUS}  ]; then
    CP4BA_IER_STORAGE_STATUS="NotInstalled"
  fi
  echo "ierStorageCheck                             :  ${CP4BA_IER_STORAGE_STATUS}"

  #################################################
  #Navigator
  #################################################
#  CP4BA_NAVIGATOR_DEPLOYMENT_STATUS=`cat ${LOG_FILE_STATUS} | grep navigatorDeployment | awk '{print $2}'`
#  if [ -z "${CP4BA_NAVIGATOR_DEPLOYMENT_STATUS}" ]; then
#      CP4BA_NAVIGATOR_DEPLOYMENT_STATUS="NotInstalled"
#  fi
#  echo "navigatorDeployment                         :  ${CP4BA_NAVIGATOR_DEPLOYMENT_STATUS}"
#
#  CP4BA_NAVIGATOR_SERVICE_STATUS=`cat ${LOG_DIR}/filenet-status.log | grep navigatorService | awk '{print $2}'`
#  if [ -z ${CP4BA_NAVIGATOR_SERVICE_STATUS}  ]; then
#    CP4BA_NAVIGATOR_SERVICE_STATUS="NotInstalled"
#  fi
#  echo "navigatorService                            :  ${CP4BA_NAVIGATOR_SERVICE_STATUS}"
#
#  CP4BA_NAVIGATOR_SETORAGE_STATUS=`cat ${LOG_DIR}/filenet-status.log | grep navigatorStorage | awk '{print $2}'`
#  if [ -z ${CP4BA_NAVIGATOR_SETORAGE_STATUS}  ]; then
#    CP4BA_NAVIGATOR_SETORAGE_STATUS="NotInstalled"
#  fi
#  echo "navigatorStorage                            :  ${CP4BA_NAVIGATOR_SETORAGE_STATUS}"
#
#  CP4BA_NAVIGATOR_ZEN_INEGRATION_STATUS=`cat ${LOG_DIR}/filenet-status.log | grep navigatorZenIntegration | awk '{print $2}'`
#  if [ -z ${CP4BA_NAVIGATOR_ZEN_INEGRATION_STATUS}  ]; then
#    CP4BA_NAVIGATOR_ZEN_INEGRATION_STATUS="NotInstalled"
#  fi
#  echo "navigatorZenIntegration                      :  ${CP4BA_NAVIGATOR_ZEN_INEGRATION_STATUS}"

   #echo "****************** DEPLOYMENT_TYPE_TO_LOWER: $DEPLOYMENT_TYPE_TO_LOWER"
   if [ $DEPLOYMENT_TYPE_TO_LOWER == "production" ]; then
       #################################################
       #ICCSAP
       #################################################
       CP4BA_ICCSAP_DEPLOYMENT_STATUS=`cat ${LOG_FILE_STATUS} | grep iccsapDeployment | awk '{print $2}'`
       if [ -z ${CP4BA_ICCSAP_DEPLOYMENT_STATUS}  ]; then
         CP4BA_ICCSAP_DEPLOYMENT_STATUS="NotInstalled"
       fi
       echo "iccsapDeployment                            :  ${CP4BA_ICCSAP_DEPLOYMENT_STATUS}"

       CP4BA_ICCSAP_ROUTE_STATUS=`cat ${LOG_FILE_STATUS} | grep iccsapRoute | awk '{print $2}'`
       if [ -z ${CP4BA_ICCSAP_ROUTE_STATUS}  ]; then
         CP4BA_ICCSAP_ROUTE_STATUS="NotInstalled"
       fi
       echo "iccsapRoute                                 :  ${CP4BA_ICCSAP_ROUTE_STATUS}"

       CP4BA_ICCSAP_SERVICE_STATUS=`cat ${LOG_FILE_STATUS} | grep iccsapService | awk '{print $2}'`
       if [ -z ${CP4BA_ICCSAP_SERVICE_STATUS}  ]; then
         CP4BA_ICCSAP_SERVICE_STATUS="NotInstalled"
       fi
       echo "iccsapService                               :  ${CP4BA_ICCSAP_SERVICE_STATUS}"

       CP4BA_ICCSAP_STORAGE_STATUS=`cat ${LOG_FILE_STATUS} | grep iccsapStorageCheck | awk '{print $2}'`
       if [ -z ${CP4BA_ICCSAP_STORAGE_STATUS}  ]; then
         CP4BA_ICCSAP_STORAGE_STATUS="NotInstalled"
       fi
       echo "iccsapStorageCheck                          :  ${CP4BA_ICCSAP_STORAGE_STATUS}"

       #################################################
       #  ADPS
       #################################################

       #################################################
      #External Share
       #################################################
      CP4BA_ES_DEPLOYMENT_STATUS=`cat ${LOG_DIR}/filenet-status.log | grep extshareDeployment | awk '{print $2}'`
      if [ -z ${CP4BA_ES_DEPLOYMENT_STATUS}  ]; then
        CP4BA_ES_DEPLOYMENT_STATUS="NotInstalled"
      fi
      echo "extshareDeployment                          :  ${CP4BA_ES_DEPLOYMENT_STATUS}"

      CP4BA_ES_STORAGE_STATUS=`cat ${LOG_DIR}/filenet-status.log | grep extshareStorage | awk '{print $2}'`
      if [ -z ${CP4BA_ES_STORAGE_STATUS}  ]; then
        CP4BA_ES_STORAGE_STATUS="NotInstalled"
      fi
      echo "extshareStorage                             :  ${CP4BA_ES_STORAGE_STATUS}"

      CP4BA_ES_SERVICE_STATUS=`cat ${LOG_DIR}/filenet-status.log | grep extshareService | awk '{print $2}'`
      if [ -z ${CP4BA_ES_SERVICE_STATUS}  ]; then
        CP4BA_ES_SERVICE_STATUS="NotInstalled"
      fi
      echo "extshareService                             :  ${CP4BA_ES_SERVICE_STATUS}"

      CP4BA_ES_ROUTE_STATUS=`cat ${LOG_DIR}/filenet-status.log | grep extshareRoute | awk '{print $2}'`
      if [ -z ${CP4BA_ES_ROUTE_STATUS}  ]; then
        CP4BA_ES_ROUTE_STATUS="NotInstalled"
      fi
      echo "extshareRoute                               :  ${CP4BA_ES_DEPLOYMENT_STATUS}"
  fi
  #################################################
  #GraphQL
  #################################################
  CP4BA_GRAPHQL_ROUTE_STATUS=`cat ${LOG_FILE_STATUS} | grep "graphqlDeployment" | awk '{print $2}'`
  if [ -z ${CP4BA_GRAPHQL_ROUTE_STATUS}  ]; then
    CP4BA_GRAPHQL_ROUTE_STATUS="NotInstalled"
  fi
  echo "graphqlDeployment                           :  ${CP4BA_GRAPHQL_ROUTE_STATUS}"

  CP4BA_GRAPHQL_SERVICE_STATUS=`cat ${LOG_FILE_STATUS} | grep graphqlRoute | awk '{print $2}'`
  if [ -z ${CP4BA_GRAPHQL_SERVICE_STATUS}  ]; then
    CP4BA_GRAPHQL_SERVICE_STATUS="NotInstalled"
  fi
  echo "graphqlRoute                                :  ${CP4BA_GRAPHQL_SERVICE_STATUS}"

  CP4BA_GRAPHQL_SERVICE_STATUS=`cat ${LOG_FILE_STATUS} | grep graphqlService | awk '{print $2}'`
  if [ -z ${CP4BA_GRAPHQL_SERVICE_STATUS}  ]; then
    CP4BA_GRAPHQL_SERVICE_STATUS="NotInstalled"
  fi
  echo "graphqlService                              :  ${CP4BA_GRAPHQL_SERVICE_STATUS}"

  CP4BA_GRAPHQL_STORAGE_STATUS=`cat ${LOG_FILE_STATUS} | grep graphqlStorage | awk '{print $2}'`
  if [ -z ${CP4BA_GRAPHQL_STORAGE_STATUS}  ]; then
    CP4BA_GRAPHQL_STORAGE_STATUS="NotInstalled"
  fi
  echo "graphqlStorage                              :  ${CP4BA_GRAPHQL_STORAGE_STATUS}"

###TODO ???
    #     gitgatewayService:
    #       gitsvcDeployment: NotInstalled
    #       gitsvcPersistentVolume: NotInstalled
    #       gitsvcService: NotInstalled
}
