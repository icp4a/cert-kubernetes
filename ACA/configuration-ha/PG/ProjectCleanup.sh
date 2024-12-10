#!/bin/bash
##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

# set -x 

. ./ScriptFunctions.sh

echo
echo "------------------------------------------------------------------------------------------------------------------"
echo -e "\n-- This script will reinitialize (with default data) all existing ADP project databases marked for reclaiming (DBSTATUS=2)."
echo "------------------------------------------------------------------------------------------------------------------"

askForConfirmation

echo -e "\nThis script will query the DPE Base database to determine which databases (if any) are marked for reclaiming... \n"

echo
echo -e "PREREQUISITE: Postgres commandline client (psql) is required."
echo
echo "=================================================="
echo

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

# Query Base DB for project DBs where dbstatus=2
SaveIFS="$IFS"
IFS=$'\n'
# Declare an array
declare -a array

# PostgreSQL connection and query
while IFS=$'\t' read -r row; do
  # Append the row to the array
  array+=("$row")
done < <(psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_BASE_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -q -t -A -F $'\t' \
  -c "SET search_path TO \"$base_db_user\"; SELECT dbname, dbuser, tenantid, ontology, project_guid FROM tenantinfo WHERE dbstatus=2")
END=${#array[@]}

# End script if no databases found matching query criteria
if [[ "$END" == "0" ]]; then
  echo -e "\nNo projects were found that are marked for reclaim.  No action will be taken."
  exit 0
fi

# Print summary of databases to be cleaned up and ask for confirmation
echo -e "\n-------------------------------------------------------------------------------------------------------------"
echo -e "\nIMPORTANT: The following project databases will be cleaned and reinitialized to default out-of-the-box data."
echo -e "(All changes made to these projects will be lost.) Please verify this is what you want:\n"

for j in $(seq 0 $(($END-1)))
do
  tenant_db_name=$(echo ${array[j]} | awk '{print $1}')
  tenant_id=$(echo ${array[j]} | awk '{print $3}')
  tenant_ontology=$(echo ${array[j]} | awk '{print $4}')
  project_guid=$(echo ${array[j]} | awk '{print $5}')
  echo "-- Project ID: " $project_guid " , tenant ID: " $tenant_id ", database name: " $tenant_db_name ", ontology: " $tenant_ontology
done

echo -e "\n--------------------------------------------------------------------------------------------------"
echo -e "\nTotal number of project databases that will be reinitialized: "$END

unset confirmation
askForConfirmation

# Since the tenant databsaes are controlled by different tenant user, we need to ask for the DB admin username and password to cleanup
# For DB2, it will requrie the script is runing under user db2inst1, so we assume it will requrie postgres for PostgreSQL.
getDbAdminUser
getDbAdminPwd

# Perform cleanup
IFS="$SaveIFS"
for i in $(seq 0 $(($END-1)))
do
  tenant_db_name=$(echo ${array[i]} | awk '{print $1}')
  tenant_user=$(echo ${array[i]} | awk '{print $2}')
  tenant_id=$(echo ${array[i]} | awk '{print $3}')
  tenant_ontology=$(echo ${array[i]} | awk '{print $4}')
  project_guid=$(echo ${array[i]} | awk '{print $5}')

  echo -e "\n-- Cleaning up the project database with project ID: " $project_guid " , tenant ID: " $tenant_id ", database name: " $tenant_db_name ", ontology: " $tenant_ontology
  cp sql/DropBacaTables.sql.template sql/DropBacaTables.sql
  sed -i.bak s/\$tenant_db_name/"$tenant_db_name"/ sql/DropBacaTables.sql
  sed -i.bak s/\$tenant_ontology/"$tenant_ontology"/ sql/DropBacaTables.sql
  echo -e "\nRunning script: sql/DropBacaTables.sql"
  psql "${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} dbname=${tenant_db_name} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -q -f sql/DropBacaTables.sql
  cp sql/CreateBacaTables.sql.template sql/CreateBacaTables.sql
  sed -i.bak s/\$tenant_db_name/"$tenant_db_name"/ sql/CreateBacaTables.sql
  sed -i.bak s/\$tenant_ontology/"$tenant_ontology"/ sql/CreateBacaTables.sql
  echo -e "\nRunning script: sql/CreateBacaTables.sql"
  psql "${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} dbname=${tenant_db_name} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -q -f sql/CreateBacaTables.sql
  cp sql/TablePermissions.sql.template sql/TablePermissions.sql
  sed -i.bak s/\$tenant_db_name/"$tenant_db_name"/ sql/TablePermissions.sql
  sed -i.bak s/\$tenant_ontology/"$tenant_ontology"/ sql/TablePermissions.sql
  sed -i.bak s/\$tenant_user/"$tenant_user"/ sql/TablePermissions.sql
  echo -e "\nRunning script: sql/TablePermissions.sql"
  psql "${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} dbname=${tenant_db_name} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -q -f sql/TablePermissions.sql

  psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_BASE_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -q -c "SET search_path TO \"$base_db_user\"; update tenantinfo set dbstatus=0 where tenantid='$tenant_id' and ontology='$tenant_ontology';"

  echo -e "\n-- Done cleaning up the project database with project ID: " $project_guid " , tenant ID: " $tenant_id ", database name: " $tenant_db_name  "\n"

done
