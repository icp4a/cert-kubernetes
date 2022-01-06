#!/bin/bash
##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2021. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

. ./ScriptFunctions.sh

INPUT_PROPS_FILENAME="./common_for_DB2.sh"
if [ -f $INPUT_PROPS_FILENAME ]; then
   echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
   . $INPUT_PROPS_FILENAME
fi

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
    echo -e "\nThis script will create a DB2 database and create the tables for a Content Analyzer Project database."
    echo
    echo -e "If you want the script to create the tables in an existing database, please exit this script and run 'InitTenantDB.sh'." 
  else
    echo -e "\nThis script will create a DB2 database."
    echo
    echo -e "If you want the script to create tables for a Content Analyzer Project database in an existing database, please exit this script and run 'InitTenantDB.sh'." 
  fi
else
  if [[ -z "$use_existing_tenant" || $use_existing_tenant -ne 1 ]]; then
    if [[ -z "$skip_setup_schema" ||  $skip_setup_schema != "true" ]]; then
      echo -e "This script will create tables in an existing database for a Content Analyzer Project."
    fi
  else
    echo -e "This script will add an ontology to an existing Content Analyzer tenant and initialize tables."
  fi
fi
echo
echo "=================================================="
echo

if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
  if [[ -z "$use_existing_tenant" || $use_existing_tenant -ne 1 ]]; then
    echo "Enter the tenant ID for the new tenant: (eg. t4900)"
  else
    echo "Enter the tenant ID for the existing tenant: (eg. t4900)"
  fi
  while [[ -z "$tenant_id" || $tenant_id == '' ]]
  do
      echo "Please enter a valid value for the tenant ID:"
      read tenant_id
  done
fi

if [[ -z "$use_existing_tenant" || $use_existing_tenant -ne 1 ]]; then

    while [[ $tenant_type == '' || $tenant_type != "0" && $tenant_type != "1" && $tenant_type != "2"  ]] # While tenant_type is not valid/set
    do
        echo -e "\n\x1B[1;31mEnter the tenant type\x1B[0m"
        echo -e "\x1B[1;31mChoose the number equivalent.\x1B[0m"
        echo -e "\x1B[1;34m0. Enterprise\x1B[0m"
        echo -e "\x1B[1;34m1. Trial\x1B[0m"
        echo -e "\x1B[1;34m2. Internal\x1B[0m"
        read tenant_type
    done

    if [ $tenant_type == 0 ]; then
        daily_limit=0
    elif [ $tenant_type == 1 ]; then
        daily_limit=100
    elif [ $tenant_type == 2 ]; then
        daily_limit=2000
    fi
fi


echo
if [[ -z "$tenant_db_exists" || $tenant_db_exists != "true" ]]; then
  echo "Enter the name of the new Content Analyzer Project database to create: "
else
  echo "Enter the name of an existing DB2 database for the Content Analyzer Project database: "
fi
while [[ $tenant_db_name == '' ]]
do
  echo "Please enter a valid value for the Project database name of max length 8 :"
  read tenant_db_name
  while [ ${#tenant_db_name} -gt 8 ];
  do
    echo "Please enter a valid value for the Project database name of max length 8 :"
    read tenant_db_name;
    echo ${#tenant_db_name};
  done
done

if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
  default_dsn_name=$tenant_db_name
  if [[ -z "$tenant_dsn_name" ]]; then
    echo -e "\nEnter the data source name. This will generally be same name as the "
    echo -e "database name unless you specifiy a different value in the 'db2dsdriver.cfg'. "
    echo -e "If nothing is entered, we will use the following default value : " $default_dsn_name
    read tenant_dsn_name
    if [[ -z "$tenant_dsn_name" ]]; then
      tenant_dsn_name=$default_dsn_name
    fi
  fi

  default_ssl='No'
  if [[ -z "$ssl" ]]; then
    echo -e "\nWould you like to enable SSL to communicate with DB2 server?  (Please note that additional setup steps are required in order to use SSL with DB2.)"
    echo -e "Please enter 'Yes' or 'No'. If nothing is entered we will use the default value of '" $default_ssl "'"
    read ssl
    if [[ -z "$ssl" ]]; then
      ssl=$default_ssl
    fi
  fi
fi

if [[ $use_existing_tenant -eq 1 ]]; then
  user_already_defined=1
fi

echo
echo "We need a non-admin database user that Content Analyzer will use to access your Content Analyzer Tenant database."
while [[ -z "$tenant_db_user" ||  $tenant_db_user == "" ]]
do
    echo
    if [[ -z "$user_already_defined" || $user_already_defined -ne 1 ]]; then
         while [[ "$create_new_user" != "y" && "$create_new_user" != "Y" && "$create_new_user" != "n" && "$create_new_user" != "N" ]]
         do
           echo "Do you want this script to create a new database user for you (This will create local OS user)? (Please enter y or n)"
           echo "Note: The user running this script must have root or sudo privileges in order to create the user."
           read create_new_user
         done

         if [[ "$create_new_user" == "n" || "$create_new_user" == "N" ]]; then
           user_already_defined=1
         else
           user_already_defined=0
         fi
    fi

    while [[ -z "$tenant_db_user" ||  $tenant_db_user == "" ]]
    do
      if [[ "$create_new_user" == "y" || "$create_new_user" = "Y" ]]; then
        echo "Please enter the name of database user to create: "
      else
        echo "Please enter the name of an existing database user with read and write privileges for the Content Analyzer Tenant database: "
      fi           
      read tenant_db_user
    done

    if [[ $user_already_defined -ne 1 ]]; then
        getent passwd $tenant_db_user > /dev/null
        if [[ $? -eq 0 ]]; then                
            while [[ "$use_existing_user" != "y" && "$use_existing_user" != "Y" && "$use_existing_user" != "n" && "$use_existing_user" != "N" ]]
            do
               echo "$tenant_db_user already exists.  Do you want to use this user (Please enter y or n)"
               read use_existing_user
               if [ "$use_existing_user" = "y" ] || [ "$use_existing_user" = "Y" ]; then
                  user_already_defined=1
               else
                  unset tenant_db_user
                  unset user_already_defined
                  unset create_new_user
               fi
            done
        fi
    fi
done


while [[ $pwdconfirmed -ne 1 ]] # While pwd is not yet received and confirmed (i.e. entered teh same time twice)
do
    while [[ $tenant_db_pwd == '' ]] # While pwd is empty...
    do
        echo "Enter the password for the user: "
        read -s tenant_db_pwd
    done

    while [[ $tenant_db_pwd2 == '' ]]  # While pwd is empty...
    do
        echo "Please confirm the password by entering it again:"
        read -s tenant_db_pwd2
    done

    if [[ "$tenant_db_pwd" == "$tenant_db_pwd2" ]]; then
        pwdconfirmed=1
    else
        echo "The passwords do not match.  Please enter the password again."
        unset tenant_db_pwd
        unset tenant_db_pwd2
    fi
done

if [[ $tenant_db_pwd_b64_encoded -eq 1 ]]; then
  tenant_db_pwd=$(echo $tenant_db_pwd | base64 --decode)
fi

default_ontology='default'
if [[ -z "$tenant_ontology" ]]; then
  echo -e "\nEnter the tenant ontology name. If nothing is entered, the default name will be used: " $default_ontology
  read tenant_ontology
  if [[ -z "$tenant_ontology" ]]; then
    tenant_ontology=$default_ontology    
  fi
fi


if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
  default_basedb='BASECA'
  if [[ -z "$base_db_name" ]]; then
    echo -e "\n-- Content Analyzer Base database info: --"
    echo -e "\nEnter the name of the Base Content Analyzer Base database. If nothing is entered, we will use the following default value : " $default_basedb
    read base_db_name
    if [[ -z "$base_db_name" ]]; then
      base_db_name=$default_basedb
    fi
  fi
fi

default_basedb_user='CABASEUSER'
if [[ -z "$base_db_user" ]]; then
  echo -e "\nEnter the name of the database user for the Content Analyzer Base database. If nothing is entered, we will use the following default value : " $default_basedb_user
  read base_db_user
  if [[ -z "$base_db_user" ]]; then
     base_db_user=$default_basedb_user 
  fi
fi

# Hard code CA user for Aria
tenant_company=IBM
tenant_first_name=ACA
tenant_last_name=Admin
tenant_email=acaadmin@ibm.com
tenant_user_name=acaadmin

if [[ $use_existing_tenant -eq 1 ]]; then
  db2 "connect to $base_db_name"
  db2 "set schema $base_db_user"
  resp=$(db2 -x "select tenanttype,dailylimit from tenantinfo where tenantid = '$tenant_id'")
  tenant_type=$(echo  $resp | awk '{print $1}')
  daily_limit=$(echo  $resp | awk '{print $2}') 
fi

rdbmsconnection="DSN=$tenant_dsn_name;UID=$tenant_db_user;"
if [[ "$ssl" == "Yes" || "$ssl" == "yes" || "$ssl" == "YES" || "$ssl" == "y" || "$ssl" == "Y" ]]; then
    echo
    rdbmsconnection+="Security=SSL;"
    echo "--- with SSL rdbstring  : " $rdbmsconnection
fi

echo
echo "-- Information gathering is completed.  The script is about to begin."
echo "-- Please confirm these are the desired settings:"
if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
  echo " - Tenant ID: $tenant_id"
# echo " - tenant type: $tenant_type"
# echo " - daily limit: $daily_limit"
fi
echo " - Project database name: $tenant_db_name"
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
   encrypted_pwd=$(perl -e 'print crypt($ARGV[0], "pwsalt")' $tenant_db_pwd)
   sudo useradd -m -p $encrypted_pwd $tenant_db_user
    if [[ $? -eq 0 ]]; then
        echo "User $tenant_db_user has been added to system!" 
    else 
        echo "ERROR: Failed to add a user $tenant_db_user!  Please try again..."
        exit 1
    fi
    echo "setting password to not expire"
    sudo chage -E -1 -M -1 $tenant_db_user
fi

# -------- convert certain variables to lower-case to standardize ----
if [[ ! -z "$tenant_db_exists" ]]; then
   tenant_db_exists=$(echo "$tenant_db_exists" | tr '[:upper:]' '[:lower:]')
fi 

if [[ ! -z "$skip_setup_schema" ]]; then
   skip_setup_schema=$(echo "$skip_setup_schema" | tr '[:upper:]' '[:lower:]')
fi 

if [[ ! -z "$skip_load_data" ]]; then
   skip_load_data=$(echo "$skip_load_data" | tr '[:upper:]' '[:lower:]')
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
      cp sql/CreateDB.sql.template sql/CreateDB.sql
      sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/CreateDB.sql
      sed -i s/\${tenant_db_name}/"$tenant_db_name"/ sql/CreateDB.sql
      # repeat in order to get any lines that had the string twice on same line
      sed -i s/\${tenant_db_name}/"$tenant_db_name"/ sql/CreateDB.sql
      sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/CreateDB.sql

      echo -e "\nRunning script: sql/CreateDB.sql"
      db2 -tvf sql/CreateDB.sql
    fi
fi

if [[ -z "$skip_setup_schema" ||  $skip_setup_schema != "true" ]]; then
  cp sql/CreateBacaSchema.sql.template sql/CreateBacaSchema.sql
  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/CreateBacaSchema.sql
  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/CreateBacaSchema.sql
  echo -e "\nRunning script: sql/CreateBacaSchema.sql"
  db2 -tvf sql/CreateBacaSchema.sql

  echo -e "\nRunning script: sql/CreateBacaTables.sql"
  db2 -tf sql/CreateBacaTables.sql
  echo "CONNECT RESET"
  db2 "CONNECT RESET"

  cp sql/TablePermissions.sql.template sql/TablePermissions.sql
  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/TablePermissions.sql
  sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/TablePermissions.sql
  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/TablePermissions.sql
  echo -e "\nRunning script: sql/TablePermissions.sql"
  db2 -tvf sql/TablePermissions.sql
fi

if [[ -z "$skip_load_data" ||  $skip_load_data != "true" ]]; then
  cp sql/LoadData.sql.template sql/LoadData.sql
  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/LoadData.sql
  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/LoadData.sql
  echo -e "\nRunning script: sql/LoadData.sql"
  db2 -tvf sql/LoadData.sql
fi


if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
  cp sql/InsertTenant.sql.template sql/InsertTenant.sql
  sed -i s/\$base_db_name/"$base_db_name"/ sql/InsertTenant.sql
  sed -i s/\$base_db_user/"$base_db_user"/ sql/InsertTenant.sql
  sed -i s/\$tenant_id/"$tenant_id"/ sql/InsertTenant.sql
  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/InsertTenant.sql
  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/InsertTenant.sql
  sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/InsertTenant.sql
  sed -i s/\$tenant_db_pwd/"$tenant_db_pwd"/ sql/InsertTenant.sql
  sed -i s/\$tenant_type/"$tenant_type"/ sql/InsertTenant.sql
  sed -i s/\$daily_limit/"$daily_limit"/ sql/InsertTenant.sql
  sed -i s/\$rdbmsconnection/"$rdbmsconnection"/ sql/InsertTenant.sql
  echo -e "\nRunning script: sql/InsertTenant.sql"
  db2 -tvf sql/InsertTenant.sql
fi


# workaround for error that occurs on HADR databases: "SQL0290N  Table space access is not allowed.  SQLSTATE=55039"
# do a deactivate/backup/activate on DB after the load is done, before doing insert user
if [[ -z "$skip_tmp_backup" ||  $skip_tmp_backup != "true" ]]; then
  currentTS=$(date "+%Y%m%d%H%M%S")
  echo "Making a temporary backup dir at /tmp/backup_${tenant_db_name}_${currentTS}"
  mkdir /tmp/backup_${tenant_db_name}_${currentTS}
  db2 -v "connect reset"
  db2 -v "deactivate db ${tenant_db_name}"
  echo "Making a temporary backup of DB (necessary after doing a load on DB)..."
  db2 -v "backup db ${tenant_db_name} to /tmp/backup_${tenant_db_name}_${currentTS} compress"
  db2 -v "activate db ${tenant_db_name}"
  echo "Removing temporary backup dir /tmp/backup_${tenant_db_name}_${currentTS}"
  rm -r /tmp/backup_${tenant_db_name}_${currentTS}
fi

#if [[ -z "$skip_set_integrity" ||  $skip_set_integrity != "true" ]]; then
#  cp sql/SetIntegrity.sql.template sql/SetIntegrity.sql
#  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/SetIntegrity.sql
#  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/SetIntegrity.sql
#  echo -e "\nRunning script: sql/SetIntegrity.sql"
#  db2 -stvf sql/SetIntegrity.sql
#fi


if [[ -z "$skip_insert_user" ||  $skip_insert_user != "true" ]]; then
  cp sql/InsertUser.sql.template sql/InsertUser.sql
  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/InsertUser.sql
  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/InsertUser.sql
  sed -i s/\$tenant_email/"$tenant_email"/ sql/InsertUser.sql
  sed -i s/\$tenant_first_name/"$tenant_first_name"/ sql/InsertUser.sql
  sed -i s/\$tenant_last_name/"$tenant_last_name"/ sql/InsertUser.sql
  sed -i s/\$tenant_user_name/"$tenant_user_name"/ sql/InsertUser.sql
  sed -i s/\$tenant_company/"$tenant_company"/ sql/InsertUser.sql
  sed -i s/\$tenant_email/"$tenant_email"/ sql/InsertUser.sql
  echo -e "\nRunning script: sql/InsertUser.sql"
  db2 -tvf sql/InsertUser.sql
fi

echo -e "\n-- Script completed.\n"

# echo "-- URL (replace frontend with your frontend host): https://frontend/?tid=$tenant_id&ont=$tenant_ontology"
echo -e "\x1B[1;32mPlease note down the following information as you will need them to create the ADP database secret later: \x1B[0m"
echo "${tenant_db_name}_DB_CONFIG=REPLACE_WITH_YOUR_DATABASE_PASSWORD" | tr '[:lower:]' '[:upper:]'