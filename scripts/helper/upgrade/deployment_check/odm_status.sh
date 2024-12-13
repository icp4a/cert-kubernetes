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
#################### ODM #######################
# Check odmDecisionCenterDeployment upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.odm.odmDecisionCenterDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ODM_DECISION_CENTER_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ODM_DECISION_CENTER_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ODM_DECISION_CENTER_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ODM_DECISION_CENTER_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ODM_DECISION_CENTER_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ODM_DECISION_CENTER_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check odmDecisionRunnerDeployment upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.odm.odmDecisionRunnerDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ODM_DECISION_RUNNER_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ODM_DECISION_RUNNER_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ODM_DECISION_RUNNER_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ODM_DECISION_RUNNER_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ODM_DECISION_RUNNER_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ODM_DECISION_RUNNER_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check odmDecisionServerConsoleDeployment upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.odm.odmDecisionServerConsoleDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ODM_DECISIONSERVER_CONSOLE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ODM_DECISIONSERVER_CONSOLE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ODM_DECISIONSERVER_CONSOLE_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ODM_DECISIONSERVER_CONSOLE_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ODM_DECISIONSERVER_CONSOLE_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ODM_DECISIONSERVER_CONSOLE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check odmDecisionServerRuntimeDeployment upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.odm.odmDecisionServerRuntimeDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ODM_DECISIONSERVER_RUNTIME_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ODM_DECISIONSERVER_RUNTIME_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ODM_DECISIONSERVER_RUNTIME_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ODM_DECISIONSERVER_RUNTIME_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ODM_DECISIONSERVER_RUNTIME_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ODM_DECISIONSERVER_RUNTIME_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

printHeaderMessage "CP4BA Upgrade Status - ODM"
echo "ODM Decision Center Upgrade Status          :  ${CP4BA_ODM_DECISION_CENTER_DEPLOYMENT_STATUS}"
echo "ODM Decision Runner Upgrade Status          :  ${CP4BA_ODM_DECISION_RUNNER_DEPLOYMENT_STATUS}"
echo "ODM Decision Server Console Upgrade Status  :  ${CP4BA_ODM_DECISIONSERVER_CONSOLE_DEPLOYMENT_STATUS}"
echo "ODM Decision Server Runtime Upgrade Status  :  ${CP4BA_ODM_DECISIONSERVER_RUNTIME_DEPLOYMENT_STATUS}"