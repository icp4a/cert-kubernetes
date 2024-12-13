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
#################### ADS #######################
# Check adsCredentialsService upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.adsCredentialsService.adsCredentialsServiceDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
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
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.adsGitService.adsGitServiceDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
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
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.adsLtpaCreation.adsLtpaCreationJob`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
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

# Check adsMongo upgrade status
# isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.adsMongo.adsMongoDeployment`
# if [ "$isInstalled" == "NotInstalled" ]; then
#     CP4BA_ADS_MONGO_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
# elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
#     CP4BA_ADS_MONGO_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
# elif [[ "$isInstalled" == "Ready" ]]; then
#     CP4BA_ADS_MONGO_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
# elif [[ "$isInstalled" == "NotReady" ]]; then
#     CP4BA_ADS_MONGO_DEPLOYMENT_STATUS="${RED_TEXT}Not Ready${RESET_TEXT}"
# elif [[ "$isInstalled" == "Failed" ]]; then
#     CP4BA_ADS_MONGO_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
# elif [ -z "${isInstalled}"  ]; then
#     CP4BA_ADS_MONGO_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
# fi

# Check adsParsingService upgrade status
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.adsParsingService.adsParsingServiceDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
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
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.adsRestApi.adsRestApiDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
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
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.adsRrRegistration.adsRrRegistrationJob`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
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
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.adsRunService.adsRunServiceDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
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
isInstalled=`cat ${UPGRADE_STATUS_FILE}| ${YQ_CMD} r - status.components.adsRuntimeService.adsRuntimeServiceDeployment`
if [ "$isInstalled" == "NotInstalled" ]; then
    CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "$isInstalled" == "Upgrading" || "$isInstalled" == "Restoring" ]]; then
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

printHeaderMessage "CP4BA Upgrade Status - ADS"
echo "ADS Build Service Upgrade Status            :  ${CP4BA_ADS_BUILD_SERVICE_DEPLOYMENT_STATUS}"
echo "ADS Credentials Service Upgrade Status      :  ${CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS}"
echo "ADS GitService Upgrade Status               :  ${CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS}"
echo "ADS Ltpa Creation Upgrade Status            :  ${CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS}"
echo "ADS Parsing Service Upgrade Status          :  ${CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS}"
echo "ADS RestApi Upgrade Status                  :  ${CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS}"
echo "ADS RrRegistration Upgrade Status           :  ${CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS}"
echo "ADS Run Service Upgrade Status              :  ${CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS}"
echo "ADS adsRuntimeService Upgrade Status        :  ${CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS}"