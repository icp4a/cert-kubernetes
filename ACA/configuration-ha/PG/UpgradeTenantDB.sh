#!/usr/bin/env bash
##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2023. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

set -e

source ./ScriptFunctions.sh

if [[ -z $INPUT_PROPS_FILENAME ]]; then
    INPUT_PROPS_FILENAME="./common_for_PG.sh"
fi

if [ -f $INPUT_PROPS_FILENAME ]; then
    echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
    source $INPUT_PROPS_FILENAME
fi

release_schema_version=$(get_release_schema_version)

echo -e "\n-- This script will upgrade your Project DB to ${release_schema_version}"
echo ""

# Check the system for psql client command
checkPGClientCommand

prompt_for_base_db_name

# get the username and password for the existing base DB
# we need to tell the script that base DB user already exists, so that prompts are correct
export base_user_already_defined=1  
getBaseDBUser
getBaseDBPwd

# Collect info for SSL
promptForSSLenabled
if [[ "$ssl_enabled" = true ]]; then
   promptForSSLcerts
fi

# ask for DB host and port
getDbHostPort

while [[ $tenant_db_name == '' ]]
do
  echo "Please enter the name of the Document Processing Engine Project database to upgrade: "
  read tenant_db_name
done
DB_TENANT_DBNAME_STR="dbname=${tenant_db_name}"  

default_ontology='default'
if [[ -z "$tenant_ontology" ]]; then
  echo -e "\nEnter the ontology name. (It must match the ontology name used when running 'InitTenantDB.sh'). If nothing is entered, the default name will be used: " $default_ontology
  read tenant_ontology
  if [[ -z "$tenant_ontology" ]]; then
    tenant_ontology=${default_ontology}
  fi
fi

while [[ -z "$tenant_db_user" ||  $tenant_db_user == "" ]]
do
  echo "Please enter the name of an existing database user with read and write privileges for this database:"
  read tenant_db_user
done
DB_TENANT_USER_STR="user=${tenant_db_user}"

getTenantDBPwd

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
echo " - Tenant database user name: $tenant_db_user"
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
