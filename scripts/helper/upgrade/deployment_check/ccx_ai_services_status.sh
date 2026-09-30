###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2024. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################
#################### CCX AI Services #######################
# The CCXAIServices CR uses status.conditions[] (array of Condition objects)
# rather than the status.components.<name>.<field> pattern used by other CRs.
# We look for a condition with type "DeployCompleted" and status "True" to
# determine that the upgrade/deployment has finished successfully.
#
# Variable consumed from the calling scope:
#   UPGRADE_DEPLOYMENT_CCXAISERVICES_CR_TMP  - path to the temp YAML dump of
#                                              the CCXAIServices CR
#   RECONCILE_SEEN_FLAG                      - "true" once the operator has
#                                              reconciled at least once

deploy_condition_status=$(cat "${UPGRADE_DEPLOYMENT_CCXAISERVICES_CR_TMP}" | \
    ${YQ_CMD} '.status.conditions[] | select(.type == "DeployCompleted") | .status // ""' - 2>/dev/null | head -1)

if [[ -z "${deploy_condition_status}" ]]; then
    CP4BA_CCXAISERVICES_DEPLOYMENT_STATUS="${YELLOW_TEXT}Not Installed${RESET_TEXT}"
elif [[ "${deploy_condition_status}" == "True" && "$RECONCILE_SEEN_FLAG" == "false" ]]; then
    CP4BA_CCXAISERVICES_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
elif [[ "${deploy_condition_status}" == "True" ]]; then
    CP4BA_CCXAISERVICES_DEPLOYMENT_STATUS="${GREEN_TEXT}Done${RESET_TEXT}"
elif [[ "${deploy_condition_status}" == "False" ]]; then
    CP4BA_CCXAISERVICES_DEPLOYMENT_STATUS="${RED_TEXT}Failed${RESET_TEXT}"
else
    CP4BA_CCXAISERVICES_DEPLOYMENT_STATUS="${BLUE_TEXT}In Progress${RESET_TEXT}"
fi

printHeaderMessage "CP4BA Upgrade Status - CCX AI Services (instance: $ccxaiservices_cr_metaname)"
echo "CCX AI Services Upgrade Status              :  ${CP4BA_CCXAISERVICES_DEPLOYMENT_STATUS}"
