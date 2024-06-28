###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2023. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
######################## BAA #######################
# Check ae-icp4adeploy-workspace-aae upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.ae-${cr_metaname}-${ae_config_name}-aae.service`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_BAA_WORKSPACE_AAE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_BAA_WORKSPACE_AAE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_BAA_WORKSPACE_AAE_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_BAA_WORKSPACE_AAE_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_BAA_WORKSPACE_AAE_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_BAA_WORKSPACE_AAE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

printHeaderMessage "CP4BA Upgrade Status - AE instance: ${ae_config_name}"
echo "Application Engine Service Upgrade Status   :  ${CP4BA_BAA_WORKSPACE_AAE_DEPLOYMENT_STATUS}"
