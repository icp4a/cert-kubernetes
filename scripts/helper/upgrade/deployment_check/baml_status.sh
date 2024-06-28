###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2023. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
######################## BAML #######################
# Check bamlDeployStatus upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.baml.bamlDeployStatus`
if [ -z "${isInstalled}"  ]; then
    isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.baml.bamlCustomResource`
fi

if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_BAML_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_BAML_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_BAML_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_BAML_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_BAML_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_BAML_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

printHeaderMessage "CP4BA Upgrade Status - BAML"
echo "BAML Service Upgrade Status                 :  ${CP4BA_BAML_DEPLOYMENT_STATUS}"