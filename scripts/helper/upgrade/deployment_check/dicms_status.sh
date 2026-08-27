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
#################### DICMS #######################
# Check adsCredentialsService upgrade status
isInstalled=`cat ${current_cr_details_location} | ${YQ_CMD} '.status.components.adsCredentialsService.adsCredentialsServiceDeployment // ""' -`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" && "$RECONCILE_SEEN_FLAG" == "false" ]]; then
    CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check adsGitService upgrade status
isInstalled=`cat ${current_cr_details_location} | ${YQ_CMD} '.status.components.adsGitService.adsGitServiceDeployment // ""' -`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" && "$RECONCILE_SEEN_FLAG" == "false" ]]; then
    CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check adsLtpaCreation upgrade status
isInstalled=`cat ${current_cr_details_location} | ${YQ_CMD} '.status.components.adsLtpaCreation.adsLtpaCreationJob // ""' -`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" && "$RECONCILE_SEEN_FLAG" == "false" ]]; then
    CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check adsParsingService upgrade status
isInstalled=`cat ${current_cr_details_location} | ${YQ_CMD} '.status.components.adsParsingService.adsParsingServiceDeployment // ""' -`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" && "$RECONCILE_SEEN_FLAG" == "false" ]]; then
    CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check adsRestApi upgrade status
isInstalled=`cat ${current_cr_details_location} | ${YQ_CMD} '.status.components.adsRestApi.adsRestApiDeployment // ""' -`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" && "$RECONCILE_SEEN_FLAG" == "false" ]]; then
    CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check adsRrRegistration upgrade status
isInstalled=`cat ${current_cr_details_location} | ${YQ_CMD} '.status.components.adsRrRegistration.adsRrRegistrationJob // ""' -`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" && "$RECONCILE_SEEN_FLAG" == "false" ]]; then
    CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check adsRunService upgrade status
isInstalled=`cat ${current_cr_details_location} | ${YQ_CMD} '.status.components.adsRunService.adsRunServiceDeployment // ""' -`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" && "$RECONCILE_SEEN_FLAG" == "false" ]]; then
    CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

# Check adsRuntimeService upgrade status
isInstalled=`cat ${current_cr_details_location} | ${YQ_CMD} '.status.components.adsRuntimeService.adsRuntimeServiceDeployment // ""' -`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
    CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" && "$RECONCILE_SEEN_FLAG" == "false" ]]; then
    CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "$isInstalled" == "Ready" ]]; then
    CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "$isInstalled" == "NotReady" ]]; then
    CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
elif [[ "$isInstalled" == "Failed" ]]; then
    CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
elif [ -z "${isInstalled}"  ]; then
    CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
fi

printHeaderMessage "CP4BA Upgrade Status - DICMS"
echo "DICMS Credentials Service Upgrade Status      :  ${CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS}"
echo "DICMS GitService Upgrade Status               :  ${CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS}"
echo "DICMS Ltpa Creation Upgrade Status            :  ${CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS}"
echo "DICMS Parsing Service Upgrade Status          :  ${CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS}"
echo "DICMS RestApi Upgrade Status                  :  ${CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS}"
echo "DICMS RrRegistration Upgrade Status           :  ${CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS}"
echo "DICMS Run Service Upgrade Status              :  ${CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS}"
echo "DICMS RuntimeService Upgrade Status           :  ${CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS}"