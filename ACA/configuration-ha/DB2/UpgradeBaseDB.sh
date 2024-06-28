#!/usr/bin/env bash

##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

set -e

source ./ScriptFunctions.sh

INPUT_PROPS_FILENAME="./common_for_DB2_Upgrade.sh"

if [ -f $INPUT_PROPS_FILENAME ]; then
    echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
    source $INPUT_PROPS_FILENAME
fi

release_schema_version=$(get_release_schema_version)

echo -e "\n-- This script will upgrade your base DB to ${release_schema_version}"
echo ""

while [[ $base_db_name == '' ]]
do
  echo "Please enter a valid value for the base database name :"
  read base_db_name
  while [ ${#base_db_name} -gt 8 ];
  do
    echo "Please enter a valid value for the base database name :"
    read base_db_name;
    echo ${#base_db_name};
  done
done

while [[ -z "$base_db_user" ||  $base_db_user == "" ]]
do
  echo "Please enter a valid value for the base database user name :"
  read base_db_user
done

echo "Checking the base DB version ..."
base_db_version=$(get_base_db_version $base_db_name $base_db_user)

if [ "$base_db_version" == "$release_schema_version" ]; then
  echo "Base DB schema version ${base_db_version} is already up-to-date."
  exit 0
fi
template_files=$(get_upgrade_templates UpgradeBaseDB $base_db_version $release_schema_version)

echo
echo "-- Please confirm these are the desired settings:"
echo " - Base database name: $base_db_name"
echo " - Base database user name: $base_db_user"
echo ""

echo "Will run the following scripts to upgrade base DB from ${base_db_version} to ${release_schema_version}:"
echo "${template_files}"

askForConfirmation

run_base_db_upgrade_templates $base_db_name $base_db_user "${template_files}"

set_base_db_version $base_db_name $base_db_user $release_schema_version

echo -e "\n-- Script completed.\n"
