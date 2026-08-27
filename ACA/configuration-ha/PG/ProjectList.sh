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

echo
echo "---------------------------------------------------------------------------------------"
echo -e "\n-- This script will list all ADP projects with its DB name and status."
echo "---------------------------------------------------------------------------------------"

echo 
echo "This script will query the DPE Base database and list all the project databases and their status."
echo "status: 0 = not initialized"
echo "        1 = initialized"
echo "        2 = marked for deletion"
echo

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

SaveIFS="$IFS"
IFS=$'\n'
# Declare an array
declare -a array

# PostgreSQL connection and query
while IFS=$'\t' read -r row; do
  # Append the row to the array
  array+=("$row")
done < <(psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_BASE_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -q -t -A -F $'\t' \
  -c "SET search_path TO \"$base_db_user\"; select bas_id, dbname, dbstatus from tenantinfo order by bas_id")
END=${#array[@]}

echo " "
echo "Total projects: "$END
echo " "
IFS="$SaveIFS"

printf "%-30s %-20s %-1s\n" "Project" "Database" "Status"
for i in $(seq 0 $(($END-1)))
do
  bas_id=$(echo ${array[i]} | awk '{print $1}')
  dbname=$(echo ${array[i]} | awk '{print $2}')
  dbstatus=$(echo ${array[i]} | awk '{print $3}')
  printf "%-30s  %-20s  %-1s\n" $bas_id $dbname $dbstatus
done
