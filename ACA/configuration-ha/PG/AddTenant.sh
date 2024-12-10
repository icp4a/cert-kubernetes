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

# TODO: add check to confirm "psql" is on the path

NUMARGS=$#

# if an argument of '1' is passed, it is assumed that a tenant already exists,
# and the script will add a new ontology to an existing tenant
if [[ "$NUMARGS" -gt 0 ]]; then
        use_existing_tenant=$1
fi

if [[ ! -z "$use_existing_tenant" && $use_existing_tenant -eq 1 ]]; then
    tenant_db_exists="true"
    user_already_defined=1
    create_new_user="n"
fi


echo
echo "=================================================="
echo
if [[ -z "$tenant_db_exists" || $tenant_db_exists != "true" ]]; then
  if [[ -z "$skip_setup_schema" ||  $skip_setup_schema != "true" ]]; then
    echo -e "This script will create a Postgres database and create the tables for a Document Processing Engine Project database."
    echo
    echo -e "If you want the script to create the tables in an existing database, please exit this script and run 'InitTenantDB.sh'."
  else
    echo -e "\nThis script will create a Postgres database."
    echo
    echo -e "If you want the script to create tables for a Document Processing Engine Project database in an existing database, please exit this script and run 'InitTenantDB.sh'."
  fi
else
  if [[ -z "$use_existing_tenant" || $use_existing_tenant -ne 1 ]]; then
    if [[ -z "$skip_setup_schema" ||  $skip_setup_schema != "true" ]]; then
      echo
      echo "This script will initialize an existing PostgreSQL database to be used as a Document Processing Engine Project database."
      echo
      echo "If you want the script to also create the PostgreSQL database for you, please exit this script and run 'AddTenant.sh' instead."
      echo
      echo "If you have already run 'AddTenant.sh' script, you do NOT need to run this script."
      echo
    fi
  else
    echo -e "This script will add an ontology to an existing Document Processing Engine project and initialize tables."
  fi
fi
echo
echo -e "PREREQUISITE: Postgres commandline client (psql) is required."
echo
echo "=================================================="
echo

# Check the system for psql client command
checkPGClientCommand

# as needed, prompt user for script to setup postgres env
# NOTE: Current plan is to require prequisite that psql env is already initialized to run our DB scripts. If we change our minds, uncomment line below.
# setupPostgresEnv

# Collect info for SSL
promptForSSLenabled
if [[ "$ssl_enabled" = true ]]; then
   promptForSSLcerts
fi

# ask for DB host and port for the script
getDbHostPort

# get the database host that DPE should use to connect to Postgres
getDbHostPortCA

# if we are creating the Project DB, we need to ask for the DB admin username
if [[ $use_existing_tenant -ne 1 ]]; then
  getDbAdminUser
fi

# Check if we need to provide the postgres admin password 
if [[ $use_existing_tenant -ne 1  &&  -z "$db_adm_pwd_skip" ]]; then
  getDbAdminPwd
fi

getTenantID

getTenantType

getTenantDBName

getTenantDBUser

getTenantDBPwd

# get the tablespace name and location
getTableSpace

PG_SYSTEM_DB_STR="dbname=${PG_SYSTEM_DB:-postgres}"

default_ontology='default'
if [[ -z "$tenant_ontology" ]]; then
  echo -e "\nEnter the project ontology name. If nothing is entered, the default name will be used: " $default_ontology
  read tenant_ontology
  if [[ -z "$tenant_ontology" ]]; then
    tenant_ontology=$default_ontology
  fi
fi

# Collect info about base DB in order to insert tenant into Base DB table TENANTINFO
if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
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
fi


# These are to support AddOnotolgy.sh
if [[ $use_existing_tenant -eq 1 ]]; then
   resp=$(psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_BASE_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -q -t -A -F $'\t' -c "SET search_path TO \"$base_db_user\"; SELECT tenanttype, dailylimit FROM tenantinfo WHERE tenantid = '$tenant_id';")
   tenant_type=$(echo $resp | awk '{print $1}')
   daily_limit=$(echo $resp | awk '{print $2}')
fi

rdbmsconnection="DB=$tenant_db_name;USR=$tenant_db_user;SRV=${db_server_for_ca};PORT=${db_port_for_ca};"

if [[ "$ssl_enabled" = true ]]; then
    echo
    rdbmsconnection+="Security=SSL;"
    echo "--- with SSL rdbstring  : " $rdbmsconnection
fi

echo
echo "-- Information gathering is completed.  The script is about to begin."
echo "-- Please confirm these are the desired settings:"
echo " - Database server (for script to connect to Postgres):  $db_server"
echo " - Database port (for script to connect to Postgres):  $db_port"
echo " - Database server (for ADP/DPE to connect to Postgres):  $db_server_for_ca"
echo " - Database port (for ADP/DPE to connect to Postgres):  $db_port_for_ca"
if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
  echo " - Tenant ID: $tenant_id"
fi
if [[ -z "$tenant_db_exists" ||  $tenant_db_exists != "true" ]]; then
  echo " - Project database will be created and initialized by this script"
else
  echo " - Project database already exists and will be initialized by this script"
fi
echo " - Project database name: $tenant_db_name"
if [[ $table_space_already_defined -ne 1 ]]; then
  echo " - Project database tablespace name: $tablespace_name"
  echo " - Project database tablespace location: $tablespace_location"
else
  echo " - Project database tablespace name: $tablespace_name"
fi
echo " - Database enabled for ssl : $ssl"
if [[ $user_already_defined -ne 1 ]]; then
  echo " - Project database user will be created by this script"
else
  echo " - Project database user already exists and will not be created by this script"
fi
echo " - Project database user: $tenant_db_user"
echo " - Ontology name: $tenant_ontology"

if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
  echo " - Base database: $base_db_name"
  echo " - Base database user: $base_db_user"
fi

askForConfirmation

# --- Create user ---
if [[ $user_already_defined -ne 1 ]]; then
    echo
    echo "Creating user $tenant_db_user..."

    cp sql/CreateTenantUser.sql.template sql/CreateTenantUser.sql
    sed -i.bak s/\$tenant_db_user/"$tenant_db_user"/ sql/CreateTenantUser.sql
    sed -i.bak s/\$tenant_db_pwd/"$tenant_db_pwd"/ sql/CreateTenantUser.sql

    if [[ ! -z $DEV_MODE && $DEV_MODE == "true" ]]; then
      echo "Running cmd: psql \"${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} ${PG_SYSTEM_DB_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}\" --set ON_ERROR_STOP=on -f sql/CreateTenantUser.sql"
    fi
    psql "${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} ${PG_SYSTEM_DB_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -f sql/CreateTenantUser.sql

    if [[ $? -eq 0 ]]; then
      echo "User $tenant_db_user has been added to system!"
    else
      echo "ERROR: Failed to add a user $tenant_db_user!  Please try again..."
      exit 1
    fi
fi

# -------- convert certain variables to lower-case to standardize ----
if [[ ! -z "$tenant_db_exists" ]]; then
   tenant_db_exists=$(echo "$tenant_db_exists" | tr '[:upper:]' '[:lower:]')
fi

if [[ ! -z "$skip_create_ont" ]]; then
   skip_create_ont=$(echo "$skip_create_ont" | tr '[:upper:]' '[:lower:]')
fi

if [[ ! -z "$skip_setup_schema" ]]; then
   skip_setup_schema=$(echo "$skip_setup_schema" | tr '[:upper:]' '[:lower:]')
fi

if [[ ! -z "$skip_set_integrity" ]]; then
   skip_set_integrity=$(echo "$skip_set_integrity" | tr '[:upper:]' '[:lower:]')
fi

if [[ ! -z "$skip_insert_tenant" ]]; then
   skip_insert_tenant=$(echo "$skip_insert_tenant" | tr '[:upper:]' '[:lower:]')
fi

if [[ ! -z "$skip_insert_user" ]]; then
   skip_insert_user=$(echo "$skip_insert_user" | tr '[:upper:]' '[:lower:]')
fi
# ----- end convert variables ------


# Only create DB for new tenants
if [[ $use_existing_tenant -ne 1 ]]; then
    # allow using existing DB if the flag "tenant_db_exists" is true
    if [[ -z "$tenant_db_exists" ||  $tenant_db_exists != "true" ]]; then
      create_table_space_stmt=""
      if [[ $table_space_already_defined -ne 1 ]]; then
        # Substitute create tablespace stmt
        create_table_space_stmt="CREATE TABLESPACE \"$tablespace_name\" owner \"$tenant_db_user\" location '$tablespace_location';"
      fi
      cp sql/CreateDB.sql.template sql/CreateDB.sql
      sed -i.bak s/\$tenant_db_name/"$tenant_db_name"/ sql/CreateDB.sql
      sed -i.bak s/\$tenant_db_user/"$tenant_db_user"/ sql/CreateDB.sql
      sed -i.bak s/\$tablespace_name/"$tablespace_name"/ sql/CreateDB.sql
      sed -i.bak -e  "s|\$create_table_space_stmt|$create_table_space_stmt|g" sql/CreateDB.sql

      echo -e "\nRunning script: sql/CreateDB.sql"
      # If in Dev mode, output command for debugging purposes
      if [[ ! -z $DEV_MODE && $DEV_MODE == "true" ]]; then
        echo "Running cmd: psql \"${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} ${PG_SYSTEM_DB_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}\" --set ON_ERROR_STOP=on -f sql/CreateDB.sql"
      fi   
      psql "${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} ${PG_SYSTEM_DB_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -f sql/CreateDB.sql
      if [[ $? -eq 0 ]]; then
        echo "Tenant database $tenant_db_name has been created!"
      else
        echo "ERROR: Failed to create tenant database $tenant_db_name!  Please try again..."
        exit 1
      fi
    fi
fi

if [[ -z "$skip_setup_schema" ||  $skip_setup_schema != "true" ]]; then

  if [[ -z "$skip_create_ont" ||  $skip_create_ont != "true" ]]; then

    cp sql/CreateBacaSchema.sql.template sql/CreateBacaSchema.sql
    sed -i.bak s/\$tenant_db_name/"$tenant_db_name"/ sql/CreateBacaSchema.sql
    sed -i.bak s/\$tenant_ontology/"$tenant_ontology"/ sql/CreateBacaSchema.sql
    echo -e "\nRunning script: sql/CreateBacaSchema.sql"

    # If in Dev mode, output command for debugging purposes
    if [[ ! -z $DEV_MODE && $DEV_MODE == "true" ]]; then
        echo "Running cmd: psql \"${DB_TENANT_USER_STR} ${DB_TENANT_PWD_STR} ${DB_TENANT_DBNAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}\" --set ON_ERROR_STOP=on -f sql/CreateBacaSchema.sql"
    fi
    psql "${DB_TENANT_USER_STR} ${DB_TENANT_PWD_STR} ${DB_TENANT_DBNAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -f sql/CreateBacaSchema.sql
    if [[ $? -eq 0 ]]; then
        echo "Tenant schema $tenant_ontology has been created!"
    else
        echo "ERROR: Failed to create tenant schema $tenant_ontology!  Please try again..."
        exit 1
    fi

  fi

  echo -e "\nRunning script: sql/CreateBacaTables.sql"
  cp sql/CreateBacaTables.sql.template sql/CreateBacaTables.sql
  sed -i.bak s/\$tenant_db_name/"$tenant_db_name"/ sql/CreateBacaTables.sql
  sed -i.bak s/\$tenant_ontology/"$tenant_ontology"/ sql/CreateBacaTables.sql

  # If in Dev mode, output command for debugging purposes
  if [[ ! -z $DEV_MODE && $DEV_MODE == "true" ]]; then
     echo "Running cmd: psql \"${DB_TENANT_USER_STR} ${DB_TENANT_PWD_STR} ${DB_TENANT_DBNAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}\" --set ON_ERROR_STOP=on -f sql/CreateBacaTables.sql"
  fi
  psql "${DB_TENANT_USER_STR} ${DB_TENANT_PWD_STR} ${DB_TENANT_DBNAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -f sql/CreateBacaTables.sql
  if [[ $? -eq 0 ]]; then
    echo "Tenant tables have been created!"
  else
    echo "ERROR: Failed to create tenant tables!  Please try again..."
    exit 1
  fi
fi


if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
  cp sql/InsertTenant.sql.template sql/InsertTenant.sql
  sed -i.bak s/\$base_db_name/"$base_db_name"/ sql/InsertTenant.sql
  sed -i.bak s/\$base_db_user/"$base_db_user"/ sql/InsertTenant.sql
  sed -i.bak s/\$tenant_id/"$tenant_id"/ sql/InsertTenant.sql
  sed -i.bak s/\$tenant_ontology/"$tenant_ontology"/ sql/InsertTenant.sql
  sed -i.bak s/\$tenant_db_name/"$tenant_db_name"/ sql/InsertTenant.sql
  sed -i.bak s/\$tenant_db_user/"$tenant_db_user"/ sql/InsertTenant.sql
  sed -i.bak s/\$tenant_db_pwd/"$tenant_db_pwd"/ sql/InsertTenant.sql
  sed -i.bak s/\$tenant_type/"$tenant_type"/ sql/InsertTenant.sql
  sed -i.bak s/\$daily_limit/"$daily_limit"/ sql/InsertTenant.sql
  sed -i.bak s/\$rdbmsconnection/"$rdbmsconnection"/ sql/InsertTenant.sql
  sed -i.bak s/\$dbstatus/"0"/ sql/InsertTenant.sql
  sed -i.bak s/\$project_guid/"NULL"/ sql/InsertTenant.sql
  sed -i.bak s/\$bas_id/"NULL"/ sql/InsertTenant.sql  
  echo -e "\nRunning script: sql/InsertTenant.sql"

  # If in Dev mode, output command for debugging purposes
  if [[ ! -z $DEV_MODE && $DEV_MODE == "true" ]]; then
    echo "Running cmd: psql \"${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_BASE_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}\" --set ON_ERROR_STOP=on -f sql/InsertTenant.sql"
  fi
  psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_BASE_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -f sql/InsertTenant.sql
  if [[ $? -eq 0 ]]; then
    echo "Tenant $tenant_id:$tenant_ontology has been inserted into tenantinfo table!"
  else
    echo "ERROR: Failed to insert tenant $tenant_id:$tenant_ontology into tenantinfo table!  Please try again..."
    exit 1
  fi
fi

set_tenant_db_version $base_db_name $base_db_user $tenant_db_name $tenant_ontology

echo -e "\n-- Script completed.\n"

# echo "-- URL (replace frontend with your frontend host): https://frontend/?tid=$tenant_id&ont=$tenant_ontology"
echo -e "\x1B[1;32mPlease note down the following information as you will need them to create the ADP database secret later: \x1B[0m"
echo "${tenant_db_name}_DB_CONFIG=REPLACE_WITH_YOUR_DATABASE_PASSWORD" | tr '[:lower:]' '[:upper:]'
