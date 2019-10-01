#!/bin/bash
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


if [[ -z "$use_existing_tenant" || $use_existing_tenant -ne 1 ]]; then
  echo -e "\n-- This script will create a BACA database and an ontology for a new tenant and load it with default data"
  echo
fi

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
        echo -e "\n\x1B[1;31mEnter the tenanttype\x1B[0m"
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
if [[ -z "$use_existing_tenant" || $use_existing_tenant -ne 1 ]]; then
  echo "Enter the name of the new BACA tenant database to create: (eg. t4900)"
else
  echo "Enter the name of the existing BACA tenant database: (eg. t4900)"
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

if [[ -z "$baca_database_server_ip" ]]; then
  echo -e "\nEnter the host/IP of the database server: "
  read baca_database_server_ip
fi

default_dbport=50000
if [[ -z "$baca_database_port" ]]; then
   echo -e "\nEnter the port of the database server. If nothing is entered we will use the following default value: " $default_dbport
   read baca_database_port
   if [[ -z "$baca_database_port" ]]; then
      baca_database_port=$default_dbport
   fi
fi

default_ssl='No'
if [[ -z "$ssl" ]]; then
  echo -e "\nWould you like to enable SSL to communicate with DB2 server? If nothing is entered we will use the default value: " $default_ssl
  read ssl
  if [[ -z "$ssl" ]]; then
    ssl=$default_ssl
  fi
fi

if [[ $use_existing_tenant -eq 1 ]]; then
  user_already_defined=1
fi

echo
echo "We need a non-admin database user that BACA will use to access your BACA tenant database."
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
        echo "Please enter the name of an existing database user"
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
  echo -e "\nEnter the name of the Base BACA database with the TENANTINFO Table. If nothing is entered, we will use the following default value : " $default_basedb
  read base_db_name
  if [[ -z "$base_db_name" ]]; then
     base_db_name=$default_basedb
  fi
fi

default_basedb_user='CABASEUSER'
if [[ -z "$base_db_user" ]]; then
  echo -e "\nEnter the name of the database user for the Base BACA database. If nothing is entered, we will use the following default value : " $default_basedb_user
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
#     echo "Enter the password for the BACA base database user: "
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
echo "Now we will gather information about the initial BACA user that will be defined:"

while [[ $tenant_company == '' ]] 
do
  echo -e "\nPlease enter the company name for the initial BACA user:"
  read tenant_company
done


while [[ $tenant_first_name == '' ]] 
do
  echo -e "\nPlease enter the first name for the initial BACA user:"
  read tenant_first_name
done


while [[ $tenant_last_name == '' ]] 
do
   echo -e "\nPlease enter the last name for the initial BACA user:"
   read tenant_last_name
done


while [[ $tenant_email == '' || ! $tenant_email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]
do
   echo -e "\nPlease enter a valid email address for the initial BACA user:"
   read tenant_email
done


while [[ $tenant_user_name == '' ]] 
do
   echo -e "\nPlease enter the login name for the initial BACA user:"
   read tenant_user_name
done

if [[ $use_existing_tenant -eq 1 ]]; then
  db2 "connect to $base_db_name"
  db2 "set schema $base_db_user"
  resp=$(db2 -x "select tenanttype,dailylimit from tenantinfo where tenantid = '$tenant_id'")
  tenant_type=$(echo  $resp | awk '{print $1}')
  daily_limit=$(echo  $resp | awk '{print $2}') 
fi

rdbmsconnection="DATABASE=$tenant_db_name;HOSTNAME=$baca_database_server_ip;PORT=$baca_database_port;PROTOCOL=TCPIP;UID=$tenant_db_user;PWD=$tenant_db_pwd;"
if [[ "$ssl" == "Yes" || "$ssl" == "y" || "$ssl" == "Y" ]]; then
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
echo " - database server hostname/IP: $baca_database_server_ip"
echo " - database server port: $baca_database_port"
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

# Only create DB for new tenants
if [[ $use_existing_tenant -ne 1 ]]; then
    # allow using existing DB if the flag "tenant_db_exists" is true
    if [[ -z "$tenant_db_exists" ||  $tenant_db_exists == "false" ]]; then
      cp sql/CreateDB.sql.template sql/CreateDB.sql
      sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/CreateDB.sql
      sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/CreateDB.sql

      echo -e "\nRunning script: sql/CreateDB.sql"
      db2 -stvf sql/CreateDB.sql
    fi
fi

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

cp sql/LoadData.sql.template sql/LoadData.sql
sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/LoadData.sql
sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/LoadData.sql
echo -e "\nRunning script: sql/LoadData.sql"
db2 -stvf sql/LoadData.sql

cp sql/InsertTenant.sql.template sql/InsertTenant.sql
sed -i s/\$base_db_name/"$base_db_name"/ sql/InsertTenant.sql
sed -i s/\$base_db_user/"$base_db_user"/ sql/InsertTenant.sql
sed -i s/\$tenant_id/"$tenant_id"/ sql/InsertTenant.sql
sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/InsertTenant.sql
sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/InsertTenant.sql
sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/InsertTenant.sql
sed -i s/\$baca_database_server_ip/"$baca_database_server_ip"/ sql/InsertTenant.sql
sed -i s/\$baca_database_port/"$baca_database_port"/ sql/InsertTenant.sql
sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/InsertTenant.sql
sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/InsertTenant.sql
sed -i s/\$tenant_db_pwd/"$tenant_db_pwd"/ sql/InsertTenant.sql
sed -i s/\$tenant_type/"$tenant_type"/ sql/InsertTenant.sql
sed -i s/\$daily_limit/"$daily_limit"/ sql/InsertTenant.sql
sed -i s/\$rdbmsconnection/"$rdbmsconnection"/ sql/InsertTenant.sql
echo -e "\nRunning script: sql/InsertTenant.sql"
db2 -stvf sql/InsertTenant.sql


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

echo -e "\n-- Add completed succesfully.  Tenant ID: $tenant_id , Ontology: $tenant_ontology \n"

echo "-- URL (replace frontend with your frontend host): https://frontend/?tid=$tenant_id&ont=$tenant_ontology"
