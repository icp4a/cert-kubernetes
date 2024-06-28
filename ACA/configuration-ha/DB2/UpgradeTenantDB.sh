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

if [[ -z $INPUT_PROPS_FILENAME ]]; then
    INPUT_PROPS_FILENAME="./common_for_DB2_Tenant_Upgrade.sh"
fi

if [ -f $INPUT_PROPS_FILENAME ]; then
    echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
    source $INPUT_PROPS_FILENAME
fi

release_schema_version=$(get_release_schema_version)

echo -e "\n-- This script will upgrade your Project DB to ${release_schema_version}"
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

while [[ $tenant_db_name == '' ]]
do
  echo "Please enter a valid value for the tenant database name :"
  read tenant_db_name
  while [ ${#tenant_db_name} -gt 8 ];
  do
    echo "Please enter a valid value for the tenant database name :"
    read tenant_db_name;
    echo ${#tenant_db_name};
  done
done

while [[ $tenant_ontology == '' ]]
do
  echo "Please enter a valid value for the tenant ontology name :"
  read tenant_ontology
done

echo "Checking the tenant DB version ..."
tenant_db_version=$(get_tenant_db_version $base_db_name $base_db_user $tenant_db_name $tenant_ontology)

if [ "$tenant_db_version" == "$release_schema_version" ]; then
  echo "Tenant schema version of DB '${tenant_db_name}' ontology '${tenant_ontology}' is ${tenant_db_version}, already up-to-date."
  exit 0
fi
template_files=$(get_upgrade_templates UpgradeTenantDB $tenant_db_version $release_schema_version)

echo
echo "-- Please confirm these are the desired settings:"
echo " - Base database name: $base_db_name"
echo " - Base database user name: $base_db_user"
echo " - Ontology: $tenant_ontology"
echo " - Tenant database name: $tenant_db_name"
echo ""

echo "Will run the following scripts to upgrade the tenant DB from ${tenant_db_version} to ${release_schema_version}:"
echo "${template_files}"

askForConfirmation

run_tenant_db_upgrade_templates $base_db_name $base_db_user $tenant_db_name $tenant_ontology "${template_files}"

echo
echo "Updating the version number of the Project DB in the Base DB to ${release_schema_version} ...."

set_tenant_db_version $base_db_name $base_db_user $tenant_db_name $tenant_ontology $release_schema_version

echo 
echo "Successfully updated the version number of the Project DB in the Base DB to ${release_schema_version} "

echo -e "\n-- Script completed.\n"