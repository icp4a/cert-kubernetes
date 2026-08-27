#!/bin/bash

###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
## This files contains various functions that contain messages used in the scripts
# Import common utilities and environment variables
# source ${CUR_DIR}/common.sh


function displayUpgradeOperatorMessage() {
  local tmp_message=$1
  local tmp_target_project_name=$2
  local tmp_original_cp4ba_csv_ver=$3
  warning "$tmp_message"
  echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run follow command to try upgrade again after fixing the issue of IBM Cloud Pak foundational services."
  echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $tmp_target_project_name --cpfs-upgrade-mode <migration mode> --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
  echo "           Usage:"
  echo "           --cpfs-upgrade-mode     : The migration mode for IBM Cloud Pak foundational services, the valid values [shared2shared/shared2dedicated/dedicated2dedicated]"
  echo "           --original-cp4ba-csv-ver: The version of csv for CP4BA operator before upgrade such as $tmp_original_cp4ba_csv_ver"
  echo "           Example command: "
  echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $tmp_target_project_name --cpfs-upgrade-mode dedicated2dedicated --original-cp4ba-csv-ver $tmp_original_cp4ba_csv_ver"
}
function generateImZenBTSMessage() {
  local component=$1
  local ssl_folder=$2
  #Set component specific variables such as default dbname, username, etc...
  #DBACLD-223078: Change the logic to ignore the case when checking component name to avoid issue caused by user input such as "im" or "Im"
  if [[ "$(echo "$component" | tr '[:lower:]' '[:upper:]')" == "IM" ]]; then
    default_dbname="imcnpdb"
    default_username="imcnp_user"
  elif [[ "$(echo "$component" | tr '[:lower:]' '[:upper:]')" == "ZEN" ]]; then
    default_dbname="zencnpdb"
    default_username="zencnp_user"
  elif [[ "$(echo "$component" | tr '[:lower:]' '[:upper:]')" == "BTS" ]]; then
    default_dbname="btscnpdb"
    default_username="btscnp_user"
  else
    return
  fi
  #Common message for IM, ZEN, BTS
  echo "## Configuration for external Postgres DB as "$component" metastore DB." >> ${USER_PROFILE_PROPERTY_FILE}
  echo "## YOU NEED TO CREATE THIS POSTGRES DB BY YOURSELF FIRST BEFORE APPLYING THE CP4BA CUSTOM RESOURCE." >> ${USER_PROFILE_PROPERTY_FILE}
  echo "## NOTES: " >> ${USER_PROFILE_PROPERTY_FILE}
  echo "##   1. Client certificate based authentication is configured on the DB server." >> ${USER_PROFILE_PROPERTY_FILE}
  echo "##   2. Client certificate rotation is managed by the customer." >> ${USER_PROFILE_PROPERTY_FILE}
  echo "##   3. Please ensure that the server certificate includes a Subject Alternative Name (SAN)." >> ${USER_PROFILE_PROPERTY_FILE}


  echo "" >> ${USER_PROFILE_PROPERTY_FILE}
  echo "## Please get \"<your-server-certification: root.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory.Default value is \"$ssl_folder\"." >> ${USER_PROFILE_PROPERTY_FILE}
  echo "CP4BA.${component}_EXTERNAL_POSTGRES_DATABASE_SSL_CERT_FILE_FOLDER=\"$ssl_folder\"" >> ${USER_PROFILE_PROPERTY_FILE}
  echo "" >> ${USER_PROFILE_PROPERTY_FILE}


  echo "## Name of the database. The default value is \"$default_dbname\"." >> ${USER_PROFILE_PROPERTY_FILE}
  echo "CP4BA.${component}_EXTERNAL_POSTGRES_DATABASE_NAME=\"$default_dbname\"" >> ${USER_PROFILE_PROPERTY_FILE}
  echo "" >> ${USER_PROFILE_PROPERTY_FILE}

  echo "## Database port number. The default value is \"5432\"." >> ${USER_PROFILE_PROPERTY_FILE}
  echo "CP4BA.${component}_EXTERNAL_POSTGRES_DATABASE_PORT=\"5432\"" >> ${USER_PROFILE_PROPERTY_FILE}
  echo "" >> ${USER_PROFILE_PROPERTY_FILE}

  # Common message for IM and Zen
  if [[ "$component" == "IM" || "$component" == "ZEN" ]]; then

    echo "## Name of the database user. The default value is \"$default_username\"." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.${component}_EXTERNAL_POSTGRES_DATABASE_USER=\"$default_username\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## Name of the read database host cloud-native-postgresql on k8s provides this endpoint. If DB is not running on k8s then same hostname as DB host." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.${component}_EXTERNAL_POSTGRES_DATABASE_R_ENDPOINT=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## Name of the database host." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.${component}_EXTERNAL_POSTGRES_DATABASE_RW_ENDPOINT=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}
  fi
  # Specific message for BTS
  if [[ "$component" == "BTS" ]]; then
    echo "## Name of the database host." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_HOSTNAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## Name of the database user. The default value is \"btscnp_user\"." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_USER_NAME=\"btscnp_user\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}
  fi
  #specific message for Zen
  if [[ "$component" == "ZEN" ]]; then
    echo "## Name of the schema to store monitoring data. The default value is \"watchdog\"." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_MONITORING_SCHEMA=\"watchdog\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## Name of the schema to store zen metadata. The default value is \"public\"." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_SCHEMA=\"public\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}
  fi
}

# Function to display the manual steps for StrimziPodset Update
function displayManualStrimziPodsetPatchingMessage(){
  local operator_namespace=$1
  local services_namespace=$2

  echo "=============================================================================================="
  echo " ${YELLOW_TEXT}[IMPORTANT] Manual Steps to Patch Kafka StrimziPodSet Resource:${RESET_TEXT}"
  echo "=============================================================================================="
  echo
  echo "1. Verify the Events Operator is running:"
  echo "     ${CLI_CMD} get pods -n ${operator_namespace} | grep ibm-events-operator"
  echo
  echo "2. Check the StrimziPodSet exists:"
  echo "     ${CLI_CMD} get strimzipodsets.core.ibmevents.ibm.com iaf-system-kafka -n ${services_namespace}"
  echo
  echo "3. Get the current kafka version annotation:"
  echo "     KAFKA_VERSION=\$(${CLI_CMD} get strimzipodsets.core.ibmevents.ibm.com iaf-system-kafka -n ${services_namespace} -o jsonpath='{.metadata.annotations.strimzi\.io/kafka-version}')"
  echo
  echo "4. Apply the patch manually:"
  echo "     ${CLI_CMD} patch strimzipodsets.core.ibmevents.ibm.com iaf-system-kafka -n ${services_namespace} --type=merge -p \"{\\\"metadata\\\":{\\\"annotations\\\":{\\\"strimzi.io/kafka-version\\\":null,\\\"ibmevents.ibm.com/kafka-version\\\":\\\"\$KAFKA_VERSION\\\"}}}\""
  echo
  echo "5. If there are issues with patching the iaf-system-kafka strimzipodset, you must reach out to the IBM CloudPak Foundation Services Team for further assistance."
  echo
  echo "================================================================================"
}

function displayEdbMigrationRetryMessage() {
  local tmp_phase_name=$1
  local tmp_target_project_name=$2
  local tmp_original_cp4ba_csv_ver=$3
  warning "EDB to IBM CloudNativePG migration failed at phase: $tmp_phase_name"
  echo "${YELLOW_TEXT}[ATTENTION]:${RESET_TEXT} You can run the following command to retry the migration after fixing the issue."
  echo "           ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeOperator -n $tmp_target_project_name --original-cp4ba-csv-ver <cp4ba-csv-version-before-upgrade>${RESET_TEXT}"
  echo "           Usage:"
  echo "           --original-cp4ba-csv-ver: The version of CSV for CP4BA operator before upgrade such as $tmp_original_cp4ba_csv_ver"
  echo "           Example command: "
  echo "           # ./cp4a-deployment.sh -m upgradeOperator -n $tmp_target_project_name --original-cp4ba-csv-ver $tmp_original_cp4ba_csv_ver"
  echo ""
  info "The EDB to IBM CloudNativePG migration will automatically resume from the failed phase."
  echo
  info " Migration state is tracked in ConfigMap: edb-cnpg-migration"
}

function next_steps_for_major_upgrade_after_upgrade_operator_mode() {
  local namespace=$1
  local css_flag=$2
  local cur_dir=$3
  # In SOD deployments the upgradeOperatorStatus step must point to the operator namespace,
  # not the operand namespace.  The caller passes CP4BA_OPERATOR_NS as $4; fall back to
  # $namespace when not provided (non-SOD / same-namespace deployments).
  local operator_namespace=${4:-$namespace}

  printf "\n"
  echo "${YELLOW_TEXT}[NEXT ACTIONS]:${RESET_TEXT}"
  step_num=1
  echo "  - STEP ${step_num} ${YELLOW_TEXT}(Optional)${RESET_TEXT}: You can run ${GREEN_TEXT}\"${cur_dir}/cp4a-deployment.sh -m upgradeOperatorStatus -n $operator_namespace\"${RESET_TEXT} to check whether the upgrade of the CP4BA operator and its dependencies is successful."
  step_num=$((step_num + 1))

  if [[ $css_flag == "true" ]]; then
    echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You have Content Search Services (CSS) installed. Make sure you stop the IBM Content Search Services index dispatcher. Refer to the FileNet P8 Platform Documentation for more details."
    echo "    ${YELLOW_TEXT}* Stopping the IBM Content Search Services index dispatcher.${RESET_TEXT}"
    echo "      1. Log in to the Administration Console for Content Platform Engine."
    echo "      2. In the navigation pane, select the domain icon."
    echo "      3. In the edit pane, click the Text Search Subsystem tab and clear the Enable indexing check box."
    echo "      4. Click Save to apply your changes."
    step_num=$((step_num + 1))
  fi
  echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You need to run ${GREEN_TEXT}\"${cur_dir}/cp4a-deployment.sh -m upgradeDeployment -n $namespace\"${RESET_TEXT} to upgrade CP4BA deployment."
  echo "    ${RED_TEXT}[ATTENTION]: ${RESET_TEXT}${YELLOW_TEXT}When you run the [upgradeDeployment] mode of the cp4a-deployment.sh script, the updated custom resource (CR) must be manually applied that all required additional actions can be completed before the upgrade process begins. Refer to the Knowledge Center: \"Updating the custom resource for each capability in your deployment\" topic to complete the REQUIRED steps for the installed pattern(s).${RESET_TEXT}"
  step_num=$((step_num + 1))
  echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You can run ${GREEN_TEXT}\"${cur_dir}/cp4a-deployment.sh -m upgradeDeploymentStatus -n $namespace\"${RESET_TEXT} to check whether the upgrade of the CP4BA deployment was successful."
  printf "\n"
}