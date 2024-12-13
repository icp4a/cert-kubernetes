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
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.bastudio.service`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_BASTUDIO_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_BASTUDIO_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_BASTUDIO_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_BASTUDIO_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_BASTUDIO_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_BASTUDIO_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

PLAYBAK_DEPLOYMENT=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.bastudio_configuration.playback_server.admin_user`
if [[ ! -z "$PLAYBAK_DEPLOYMENT" ]]; then
    # Check playback upgrade status
    isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.ae-${cr_metaname}-pbk.service`
    if [ "$isInstalled" == "NotInstalled" ]; then
        CP4BA_BAA_PBK_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
    elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
        CP4BA_BAA_PBK_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
    elif [[ "$isInstalled" == "Ready" ]]; then
        CP4BA_BAA_PBK_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
    elif [[ "$isInstalled" == "NotReady" ]]; then
        CP4BA_BAA_PBK_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
    elif [[ "$isInstalled" == "Failed" ]]; then
        CP4BA_BAA_PBK_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
    elif [ -z "${isInstalled}"  ]; then
        CP4BA_BAA_PBK_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
    fi
fi

printHeaderMessage "CP4BA Upgrade Status - BAStudio"
echo "BAStudio Upgrade Status                     :  ${CP4BA_BASTUDIO_DEPLOYMENT_STATUS}"
if [[ ! -z "$PLAYBAK_DEPLOYMENT" ]]; then
echo "Application Playback Upgrade Status         :  ${CP4BA_BAA_PBK_DEPLOYMENT_STATUS}"
fi

# echo "Application Playback Service Upgrade Status        :  ${CP4BA_BAA_PBK_DEPLOYMENT_STATUS}"
