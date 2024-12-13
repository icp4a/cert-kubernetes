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
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
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
