#!/bin/bash
##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

. ./ScriptFunctions.sh

INPUT_PROPS_FILENAME="./common_for_PG.sh"
if [ -f $INPUT_PROPS_FILENAME ]; then
   echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
   . $INPUT_PROPS_FILENAME
fi

echo -e "\n-- This script will delete an existing BACA tenant"
echo

echo
echo -e "PREREQUISITE: Postgres commandline client (psql) is required."
echo
echo "=================================================="
echo

PG_SYSTEM_DB_STR="dbname=${PG_SYSTEM_DB:-postgres}"

# Check the system for psql client command
checkPGClientCommand

# as needed, prompt user for script to setup postgres env
# NOTE: Current plan is to require prequisite that psql env is already initialized to run our DB scripts. If we change our minds, uncomment line below.

# Collect info for SSL
promptForSSLenabled
if [[ "$ssl_enabled" = true ]]; then
   promptForSSLcerts
fi

# ask for DB host and port for the script
getDbHostPort

# get the database host that DPE should use to connect to Postgres
getDbHostPortCA

default_basedb='basedb'
if [[ -z "$base_db_name" ]]; then
  echo -e "\n-- Document Processing Engine Base database info: --"
  echo -e "\nEnter the name of the Base Document Processing Engine Base database. If nothing is entered, we will use the following default value : " $default_basedb
  read base_db_name
  if [[ -z "$base_db_name" ]]; then
    base_db_name=$default_basedb
  fi
fi
DB_BASE_NAME_STR="dbname=${base_db_name}"

default_basedb_user='baseuser'
if [[ -z "$base_db_user" ]]; then
  echo -e "\nEnter the name of the database user for the Document Processing Engine Base database. If nothing is entered, we will use the following default value : " $default_basedb_user
  read base_db_user
  if [[ -z "$base_db_user" ]]; then
    base_db_user=$default_basedb_user
  fi
fi
DB_BASE_USER_STR="user=${base_db_user}"

# get the password for the base DB user
getBaseDBPwd

echo "Enter the tenant ID for the existing tenant: (eg. t4900)"
while [[ -z "$tenant_id" || $tenant_id == '' ]]
do
    echo "Please enter a valid value for the tenant ID:"
    read tenant_id
done

resp=$(psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_BASE_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -q -t -A -F $'\t' -c "SET search_path TO \"$base_db_user\"; select dbname,dbuser from tenantinfo where tenantid = '$tenant_id';")
tenant_db_name=$(echo $resp | awk '{print $1}')
tenant_user=$(echo $resp | awk '{print $2}')

echo
echo "-- Please confirm these are the desired settings:"
echo " - tenant ID: $tenant_id"
echo " - tenant database name: $tenant_db_name"
echo " - base database: $base_db_name"
askForConfirmation

# For DB2, it will require the script is runing under user db2inst1, so we assume it will require postgres for PostgreSQL.
getDbAdminUser
getDbAdminPwd

cp sql/DeleteDB.sql.template sql/DeleteDB.sql
sed -i.bak s/\$tenant_db_name/"$tenant_db_name"/ sql/DeleteDB.sql
echo -e "\nRunning script: sql/DeleteDB.sql"
psql "${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} ${PG_SYSTEM_DB_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -f sql/DeleteDB.sql
psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_BASE_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -c "SET search_path TO \"$base_db_user\"; delete from tenantinfo where tenantid='$tenant_id';"
echo -e "\n-- Done \n"
