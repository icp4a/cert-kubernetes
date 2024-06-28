###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2023. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################
#################### FNCM #######################
# Check CPE upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.cpe.cpeDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_CPE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_CPE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_CPE_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_CPE_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_CPE_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_CPE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check graphql upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.graphql.graphqlDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_GRAPHQL_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_GRAPHQL_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_GRAPHQL_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_GRAPHQL_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_GRAPHQL_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_GRAPHQL_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi
# Check CSS upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.css.cssDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_CSS_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_CSS_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_CSS_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_CSS_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_CSS_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi
# Check CMIS upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.cmis.cmisDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_CMIS_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_CMIS_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_CMIS_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_CMIS_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_CMIS_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_CMIS_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi
# Check IER upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.ier.ierDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_IER_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_IER_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_IER_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_IER_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_IER_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_IER_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi
# Check ICCSAP upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.iccsap.iccsapDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ICC_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ICC_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ICC_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ICC_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ICC_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ICC_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi
# Check TaskManager upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.tm.tmDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_TM_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_TM_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_TM_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_TM_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_TM_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_TM_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi
# Check BAN upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.navigator.navigatorDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_BAN_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_BAN_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_BAN_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_BAN_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_BAN_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_BAN_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi
# Check ExternalShare upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.extshare.extshareDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ES_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ES_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ES_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ES_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ES_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ES_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

printHeaderMessage "CP4BA Upgrade Status - Content"
echo "CPE Upgrade Status                          :  ${CP4BA_CPE_DEPLOYMENT_STATUS}"
echo "CSS Upgrade Status                          :  ${CP4BA_CSS_DEPLOYMENT_STATUS}"
echo "CMIS Upgrade Status                         :  ${CP4BA_CMIS_DEPLOYMENT_STATUS}"
echo "GRAPHQL Upgrade Status                      :  ${CP4BA_GRAPHQL_DEPLOYMENT_STATUS}"
echo "TaskManager Upgrade Status                  :  ${CP4BA_TM_DEPLOYMENT_STATUS}"
echo "BAN Upgrade Status                          :  ${CP4BA_BAN_DEPLOYMENT_STATUS}"
echo "IER Upgrade Status                          :  ${CP4BA_IER_DEPLOYMENT_STATUS}"
echo "ICC Upgrade Status                          :  ${CP4BA_ICC_DEPLOYMENT_STATUS}"