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

default_basedb='basedb'

# TODO: add check to confirm "psql" is on the path

if [[ -z "$base_db_name" ]]; then
    echo
    if [[ -z "$base_db_exists" ||  $base_db_exists == "false" ]]; then
      echo
      echo "=================================================="
      echo
      echo -e "This script will create a new Postgres database to be used as the Document Processing Engine Base database and initialize the database."
      echo
      echo -e "If you prefer to create your own database, and only want the script to initialize the existing database, please exit this script and run 'InitBaseDB.sh'."
      echo
      echo -e "PREREQUISITE: Postgres commandline client (psql) is required."
      echo
      echo "=================================================="
      echo
      echo -e "\nEnter the name of the database to create. (The name must be 8 chars or less). If nothing is entered, we will use this default value : " $default_basedb
    else
      echo -e "\nEnter the name of an existing PG database to initialize as the Document Processing Engine Base database."
    fi
    read base_db_name
    if [[ -z "$base_db_name" &&  $base_db_exists != "true" ]]; then
      base_db_name=$default_basedb
    fi
    while [ ${#base_db_name} -gt 64 ];
        do
        echo "Please enter a valid value for the base database name of max length 64 :"
        read base_db_name;
    done
fi

# Check the system for psql client command
checkPGClientCommand

DB_BASE_NAME_STR="dbname=${base_db_name}"
PG_SYSTEM_DB_STR="dbname=${PG_SYSTEM_DB:-postgres}"


# as needed, prompt user for script to setup postgres env
# NOTE: Current plan is to require prequisite that psql env is already initialized to run our DB scripts. If we change our minds, uncomment line below.
# setupPostgresEnv

# Collect info for SSL
promptForSSLenabled
if [[ "$ssl_enabled" = true ]]; then
   promptForSSLcerts
fi

# ask for DB host and port
getDbHostPort

# if we are creating the base DB, we need to ask for the DB admin username
if [[ $base_db_exists != "true" ]]; then
  getDbAdminUser
fi

# Check if we need to provide the postgres admin password 
if [[ $base_db_exists != "true" &&  -z "$db_adm_pwd_skip" ]]; then
  getDbAdminPwd
fi

# get the username and password for the base DB 
getBaseDBUser
getBaseDBPwd

# get the tablespace name and location
getTableSpace

echo
echo "-- Information gathering is completed.  Script execution is about to start ...."
echo "-- Please confirm these are the desired settings:"
echo " - Database server:  $db_server"
echo " - Database port:  $db_port"
if [[ -z "$base_db_exists" ||  $base_db_exists == "false" ]]; then
  echo " - Base database will be created and initialized by this script"
else
  echo " - Base database already exists and will be initialized by this script"
fi
echo " - Base database name: $base_db_name"
if [[ $table_space_already_defined -ne 1 ]]; then
  echo " - Base database tablespace name: $tablespace_name"
  echo " - Base database tablespace location: $tablespace_location"
else
  echo " - Base database tablespace name: $tablespace_name"
fi
if [[ $base_user_already_defined -ne 1 ]]; then
  echo " - Base database user will be created by this script"
else
  echo " - Base database user already exists and will not be created by this script"
fi
echo " - Base database user: $base_db_user"

outputSSLsettings


askForConfirmation

if [[ $base_user_already_defined -ne 1 ]]; then
    echo
    echo "Creating user $base_db_user..."

    cp sql/CreateBaseUser.sql.template sql/CreateBaseUser.sql
    sed -i.bak s/\$base_db_user/"$base_db_user"/ sql/CreateBaseUser.sql
    sed -i.bak s/\$base_db_pwd/"$base_db_pwd"/ sql/CreateBaseUser.sql

    if [[ ! -z $DEV_MODE && $DEV_MODE == "true" ]]; then
      echo "Running cmd: psql \"${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} ${PG_SYSTEM_DB_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}\" --set ON_ERROR_STOP=on -f sql/CreateBaseUser.sql"
    fi
    psql "${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} ${PG_SYSTEM_DB_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -f sql/CreateBaseUser.sql

    if [[ $? -eq 0 ]]; then
      echo "User $base_db_user has been added to system!" 
    else 
      echo "ERROR: Failed to add a user $base_db_user!  Please try again..."
      exit 1
    fi

    echo "for security reasons, deleting file 'sql/CreateBaseUser.sql'"
    rm sql/CreateBaseUser.sql
    rm sql/CreateBaseUser.sql.bak
fi

# allow using existing DB if the flag "base_db_exists" is true
if [[ -z "$base_db_exists" ||  $base_db_exists == "false" ]]; then
   create_table_space_stmt=""
   if [[ $table_space_already_defined -ne 1 ]]; then
    # Substitute create tablespace stmt
    create_table_space_stmt="CREATE TABLESPACE \"$tablespace_name\" owner \"$base_db_user\" location '$tablespace_location';"
   fi
   cp sql/CreateBaseDB.sql.template sql/CreateBaseDB.sql
   sed -i.bak s/\$base_db_name/"$base_db_name"/ sql/CreateBaseDB.sql
   sed -i.bak s/\$base_db_user/"$base_db_user"/ sql/CreateBaseDB.sql
   sed -i.bak s/\$tablespace_name/"$tablespace_name"/ sql/CreateBaseDB.sql
   sed -i.bak -e  "s|\$create_table_space_stmt|$create_table_space_stmt|g" sql/CreateBaseDB.sql

   echo -e "\nCreating database ${base_db_name} ...."
   echo "Running script: sql/CreateBaseDB.sql"

   # If in Dev mode, output command for debugging purposes
   if [[ ! -z $DEV_MODE && $DEV_MODE == "true" ]]; then
     echo "Running cmd: psql \"${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} ${PG_SYSTEM_DB_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}\" --set ON_ERROR_STOP=on -f sql/CreateBaseDB.sql"
   fi   
   psql "${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} ${PG_SYSTEM_DB_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -f sql/CreateBaseDB.sql
   if [[ $? -eq 0 ]]; then
     echo "Base database $base_db_name has been added to system!" 
   else 
     echo "ERROR: Failed to add base database $base_db_name!  Please try again..."
     exit 1
   fi
fi

cp sql/CreateBaseTable.sql.template sql/CreateBaseTable.sql
sed -i.bak s/\$base_db_name/"$base_db_name"/ sql/CreateBaseTable.sql
sed -i.bak s/\$base_db_user/"$base_db_user"/ sql/CreateBaseTable.sql

echo
echo "Running script: sql/CreateBaseTable.sql"
# If in Dev mode, output command for debugging purposes
if [[ ! -z $DEV_MODE && $DEV_MODE == "true" ]]; then
    echo "Running cmd: psql \"${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_BASE_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}\" --set ON_ERROR_STOP=on -f sql/CreateBaseTable.sql"
fi
psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_BASE_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -f sql/CreateBaseTable.sql
if [[ $? -eq 0 ]]; then
  echo "Base schema and tables have been created!" 
else 
  echo "ERROR: Failed to create base schema or tables!  Please try again..."
  exit 1
fi

set_base_db_version $base_db_name $base_db_user

echo -e "\x1B[1;32mPlease note down the following information as you will need them to create the ADP database secret later: \x1B[0m"
echo "BASE_DB_USER="$base_db_user""
echo "BASE_DB_CONFIG=REPLACE_WITH_YOUR_DB_PASSWORD"
