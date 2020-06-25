#!/bin/bash
# @---lm_copyright_start
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end
# NOTES:
# This script will create a DB2 database and initialize the database for a Content Analyzer tenant and load it with default data.
# If you prefer to create your own database, and only want the script to initialize the existing database, 
# please exit this script and run 'InitTenantDB.sh'.

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
  echo -e "\nThis script will create a DB2 database and initialize the database for a Content Analyzer tenant and load it with default data."
  echo
  echo -e "If you prefer to create your own database, and only want the script to initialize the existing database, please exit this script and run 'InitTenantDB.sh'."   
else
  if [[ -z "$use_existing_tenant" || $use_existing_tenant -ne 1 ]]; then
    echo -e "This script will initialize an existing database for a Content Analyzer tenant and load it with default data."
  else
    echo -e "This script will add an ontology to an existing Content Analyzer tenant and load it with default data."
  fi
fi
echo
echo "=================================================="
echo

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
  echo "Enter the name of the new Content Analyzer Tenant database to create: "
else
  echo "Enter the name of an existing DB2 database for the Content Analyzer Tenant database: "
fi
while [[ $tenant_db_name == '' ]]
do
  echo "Please enter a valid value for the tenant database name of max length 8 :"
  read tenant_db_name
  while [ ${#tenant_db_name} -gt 8 ];
  do
    echo "Please enter a valid value for the tenant database name of max length 8 :"
    read tenant_db_name;
    echo ${#tenant_db_name};
  done
done

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

# if [[ -z "$baca_database_server_ip" ]]; then
#   echo -e "\nEnter the host/IP of the database server: "
#   read baca_database_server_ip
# fi

# default_dbport=50000
# if [[ -z "$baca_database_port" ]]; then
#    echo -e "\nEnter the port of the database server. If nothing is entered we will use the following default value: " $default_dbport
#    read baca_database_port
#    if [[ -z "$baca_database_port" ]]; then
#       baca_database_port=$default_dbport
#    fi
# fi

default_ssl='No'
if [[ -z "$ssl" ]]; then
  echo -e "\nWould you like to enable SSL to communicate with DB2 server?  (Please note that additional setup steps are required in order to use SSL with DB2.)"
  echo -e "Please enter 'Yes' or 'No'. If nothing is entered we will use the default value of '" $default_ssl "'"
  read ssl
  if [[ -z "$ssl" ]]; then
    ssl=$default_ssl
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

default_basedb='BASECA'
if [[ -z "$base_db_name" ]]; then
  echo -e "\n-- Content Analyzer Base database info: --"
  echo -e "\nEnter the name of the Base Content Analyzer Base database. If nothing is entered, we will use the following default value : " $default_basedb
  read base_db_name
  if [[ -z "$base_db_name" ]]; then
     base_db_name=$default_basedb
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

# FOR NOW, there is no need to collect credentials for Base DB, as we are currently assuming that we are running script as DB2 admin (eg. db2inst1) on the DB2 server. 
# If we decide to run from a remote machine, then UNCOMMENT the following to collect the DB2 admin credentials

# pwdconfirmed=0
# while [[ $pwdconfirmed -ne 1 ]] # While pwd is not yet received and confirmed (i.e. entered teh same time twice)
# do
#     echo "Enter the password for the Content Analyzer base database user: "
#     read -s base_tenant_db_pwd
#     while [[ $base_tenant_db_pwd == '' ]] # While pwd is empty...
#     do
#         echo "Enter a valid value"
#         read -r base_tenant_db_pwd
#     done

#     echo "Please confirm the password by entering it again:"
#     read -s base_tenant_db_pwd2
#     while [[ $base_tenant_db_pwd2 == '' ]]  # While pwd is empty...
#     do
#         echo "Enter a valid value"
#         read -r base_tenant_db_pwd2
#     done

#     if [[ "$base_tenant_db_pwd" == "$base_tenant_db_pwd2" ]]; then
#         pwdconfirmed=1
#     else
#         echo "The passwords do not match.  Please enter the password again."
#         unset base_tenant_db_pwd
#         unset base_tenant_db_pwd2
#     fi
# done

echo
echo "Now we will gather information about the initial Content Analyzer login user"

while [[ $tenant_company == '' ]] 
do
  echo -e "\nPlease enter the company name for the initial Content Analyzer user:"
  read tenant_company
done


while [[ $tenant_first_name == '' ]] 
do
  echo -e "\nPlease enter the first name for the initial Content Analyzer user:"
  read tenant_first_name
done


while [[ $tenant_last_name == '' ]] 
do
   echo -e "\nPlease enter the last name for the initial Content Analyzer user:"
   read tenant_last_name
done


while [[ $tenant_email == '' || ! $tenant_email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]
do
   echo -e "\nPlease enter a valid email address for the initial Content Analyzer user:"
   read tenant_email
done


while [[ $tenant_user_name == '' ]] 
do
   echo -e "\nPlease enter the login name for the initial Content Analyzer user. (IMPORTANT: if you are using LDAP, the login name must the same as your LDAP username.)"
   read tenant_user_name
done

if [[ $use_existing_tenant -eq 1 ]]; then
  db2 "connect to $base_db_name"
  db2 "set schema $base_db_user"
  resp=$(db2 -x "select tenanttype,dailylimit from tenantinfo where tenantid = '$tenant_id'")
  tenant_type=$(echo  $resp | awk '{print $1}')
  daily_limit=$(echo  $resp | awk '{print $2}') 
fi

rdbmsconnection="DSN=$tenant_dsn_name;UID=$tenant_db_user;PWD=$tenant_db_pwd;"
if [[ "$ssl" == "Yes" || "$ssl" == "yes" || "$ssl" == "YES" || "$ssl" == "y" || "$ssl" == "Y" ]]; then
    echo
    rdbmsconnection+="Security=SSL;"
    echo "--- with SSL rdbstring  : " $rdbmsconnection
fi

echo
if [[ $use_existing_tenant -ne 1 ]]; then
  echo "-- Information gathering is completed.  Add tenant is about to begin."
else
  echo "-- Information gathering is completed.  Add ontology is about to begin."
fi
echo "-- Please confirm these are the desired settings:"
echo " - tenant ID: $tenant_id"
echo " - tenant type: $tenant_type"
echo " - daily limit: $daily_limit"
echo " - tenant database name: $tenant_db_name"
# echo " - database server hostname/IP: $baca_database_server_ip"
# echo " - database server port: $baca_database_port"
echo " - database enabled for ssl : $ssl"
if [[ $user_already_defined -ne 1 ]]; then
  echo " - tenant database user will be created by this script"
else
  echo " - tenant database user already exists and will not be created by this script"
fi
echo " - tenant database user: $tenant_db_user"
echo " - ontology name: $tenant_ontology"
echo " - base database: $base_db_name"
echo " - base database user: $base_db_user"
echo " - tenant company name: $tenant_company"
echo " - tenant first name: $tenant_first_name"
echo " - tenant last name: $tenant_last_name"
echo " - tenant email address: $tenant_email"
echo " - tenant login name: $tenant_user_name"
askForConfirmation


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
      sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/CreateDB.sql

      echo -e "\nRunning script: sql/CreateDB.sql"
      db2 -stvf sql/CreateDB.sql
    fi
fi

if [[ -z "$skip_setup_schema" ||  $skip_setup_schema != "true" ]]; then
  cp sql/CreateBacaSchema.sql.template sql/CreateBacaSchema.sql
  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/CreateBacaSchema.sql
  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/CreateBacaSchema.sql
  echo -e "\nRunning script: sql/CreateBacaSchema.sql"
  db2 -stvf sql/CreateBacaSchema.sql

  echo -e "\nRunning script: sql/CreateBacaTables.sql"
  db2 -tf sql/CreateBacaTables.sql
  echo "CONNECT RESET"
  db2 "CONNECT RESET"

  cp sql/TablePermissions.sql.template sql/TablePermissions.sql
  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/TablePermissions.sql
  sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/TablePermissions.sql
  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/TablePermissions.sql
  echo -e "\nRunning script: sql/TablePermissions.sql"
  db2 -stvf sql/TablePermissions.sql
fi

if [[ -z "$skip_load_data" ||  $skip_load_data != "true" ]]; then
  cp sql/LoadData.sql.template sql/LoadData.sql
  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/LoadData.sql
  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/LoadData.sql
  echo -e "\nRunning script: sql/LoadData.sql"
  db2 -stvf sql/LoadData.sql
fi


if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
  cp sql/InsertTenant.sql.template sql/InsertTenant.sql
  sed -i s/\$base_db_name/"$base_db_name"/ sql/InsertTenant.sql
  sed -i s/\$base_db_user/"$base_db_user"/ sql/InsertTenant.sql
  sed -i s/\$tenant_id/"$tenant_id"/ sql/InsertTenant.sql
  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/InsertTenant.sql
  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/InsertTenant.sql
  # sed -i s/\$baca_database_server_ip/"$baca_database_server_ip"/ sql/InsertTenant.sql
  # sed -i s/\$baca_database_port/"$baca_database_port"/ sql/InsertTenant.sql
  sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/InsertTenant.sql
  sed -i s/\$tenant_db_pwd/"$tenant_db_pwd"/ sql/InsertTenant.sql
  sed -i s/\$tenant_type/"$tenant_type"/ sql/InsertTenant.sql
  sed -i s/\$daily_limit/"$daily_limit"/ sql/InsertTenant.sql
  sed -i s/\$rdbmsconnection/"$rdbmsconnection"/ sql/InsertTenant.sql
  echo -e "\nRunning script: sql/InsertTenant.sql"
  db2 -stf sql/InsertTenant.sql
fi


if [[ -z "$skip_set_integrity" ||  $skip_set_integrity != "true" ]]; then
  cp sql/SetIntegrity.sql.template sql/SetIntegrity.sql
  sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/SetIntegrity.sql
  sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/SetIntegrity.sql
  echo -e "\nRunning script: sql/SetIntegrity.sql"
  db2 -stvf sql/SetIntegrity.sql
fi


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
  db2 -stvf sql/InsertUser.sql
fi

echo -e "\n-- Add completed succesfully.  Tenant ID: $tenant_id , Ontology: $tenant_ontology \n"

echo "-- URL (replace frontend with your frontend host): https://frontend/?tid=$tenant_id&ont=$tenant_ontology"
