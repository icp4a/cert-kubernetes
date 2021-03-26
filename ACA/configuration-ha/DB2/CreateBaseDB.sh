#!/bin/bash
# @---lm_copyright_start
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end
# NOTES:
# This script will create a new DB2 database to be used as the Content Analyzer Base database and initialize the database.
# If you prefer to create your own database, and only want the script to initialize the existing database, 
# please exit this script and run 'InitBaseDB.sh'."

. ./ScriptFunctions.sh

INPUT_PROPS_FILENAME="./common_for_DB2.sh"

if [ -f $INPUT_PROPS_FILENAME ]; then
   echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
   . $INPUT_PROPS_FILENAME
fi

default_basedb='BASECA'


if [[ -z "$base_db_name" ]]; then
    echo
    if [[ -z "$base_db_exists" ||  $base_db_exists == "false" ]]; then
      echo
      echo "=================================================="
      echo
      echo -e "This script will create a new DB2 database to be used as the Content Analyzer Base database and initialize the database."
      echo
      echo -e "If you prefer to create your own database, and only want the script to initialize the existing database, please exit this script and run 'InitBaseDB.sh'."
      echo
      echo "=================================================="
      echo
      echo -e "\nEnter the name of the database to create. (The name must be 8 chars or less). If nothing is entered, we will use this default value : " $default_basedb
    else
      echo -e "\nEnter the name of an existing DB2 database to initialize as the Content Analyzer Base database."
    fi
    read base_db_name
    if [[ -z "$base_db_name" &&  $base_db_exists != "true" ]]; then
      base_db_name=$default_basedb
    fi
    while [ ${#base_db_name} -gt 8 ];
        do
        echo "Please enter a valid value for the base database name of max length 8 :"
        read base_db_name;
        echo ${#base_db_name};
    done
fi

if [[ -z "$base_valid_user" ]]; then
  base_valid_user=0
fi

while [[ $base_valid_user -ne 1 ]]
do
    echo -e "\nWe need a non-admin database user that BACA will use to access your BASE database."

    if [[ -z "$base_user_already_defined" || $base_user_already_defined -ne 1 ]]; then
         while [[ "$create_new_base_user" != "y" && "$create_new_base_user" != "Y" && "$create_new_base_user" != "n" && "$create_new_base_user" != "N" ]]
         do
           echo "Do you want this script to create a new database user for you (This will create local OS user)? (Please enter y or n)"
           read create_new_base_user
         done

         if [[ "$create_new_base_user" == "n" || "$create_new_base_user" == "N" ]]; then
           base_user_already_defined=1
           base_valid_user=1
         else
           base_user_already_defined=0
         fi
    fi

    while [[ -z "$base_db_user" ||  $base_db_user == "" ]]
    do
      if [[ $base_user_already_defined -ne 1 ]]; then
        echo "Please enter the name of database user to create: "
      else
        echo "Please enter the name of an existing database user with read and write privileges for this database:"
      fi           
      read base_db_user
    done

    if [[ $base_user_already_defined -ne 1 ]]; then
        getent passwd $base_db_user > /dev/null
        if [[ $? -eq 0 ]]; then
            echo "$base_db_user already exists.  Do you want to use this existing user (y/n)"
            read use_existing_user
            if [ "$use_existing_user" = "y" ] || [ "$use_existing_user" = "Y" ]; then
              base_base_user_already_defined=1
              base_valid_user=1
            fi
        else
            base_valid_user=1
        fi
    fi
done

if [[ $base_user_already_defined = 1 ]]; then
 base_pwdconfirmed=1
else
 base_pwdconfirmed=0
fi

while [[ $base_pwdconfirmed -ne 1 ]] # While pwd is not yet received and confirmed (i.e. entered the same time twice)
do
    echo "Enter the password for the user: "
    read -s db_user_pwd
    while [[ $db_user_pwd == '' ]] # While pwd is empty...
    do
        echo "Enter a valid value"
        read -s db_user_pwd
    done

    echo "Please confirm the password by entering it again:"
    read -s db_user_pwd2
    while [[ $db_user_pwd2 == '' ]]  # While pwd is empty...
    do
        echo "Enter a valid value"
        read -s db_user_pwd2
    done

    if [[ "$db_user_pwd" == "$db_user_pwd2" ]]; then
        base_pwdconfirmed=1
    else
        echo "The passwords do not match.  Please enter the password again."
        unset db_user_pwd
        unset db_user_pwd2
    fi  
done

echo
echo "-- Information gathering is completed.  Script execution is starting ...."
askForConfirmation

if [[ $db_user_pwd_b64_encoded -eq 1 ]]; then
  db_user_pwd=$(echo $db_user_pwd | base64 --decode)
fi

if [[ $base_user_already_defined -ne 1 ]]; then
    echo
    echo "Creating user $base_db_user..."

    encrypted_pwd=$(perl -e 'print crypt($ARGV[0], "pwsalt")' $db_user_pwd)
    sudo useradd -m -p $encrypted_pwd $base_db_user
    if [[ $? -eq 0 ]]; then
      echo "User $base_db_user has been added to system!" 
    else 
      echo "ERROR: Failed to add a user $base_db_user!  Please try again..."
      exit 1
    fi
    echo "setting password to not expire"
    sudo chage -E -1 -M -1 $base_db_user
fi

# allow using existing DB if the flag "base_db_exists" is true
if [[ -z "$base_db_exists" ||  $base_db_exists == "false" ]]; then
   cp sql/CreateBaseDB.sql.template sql/CreateBaseDB.sql
   sed -i s/\$base_db_name/"$base_db_name"/ sql/CreateBaseDB.sql
   sed -i s/\$base_db_user/"$base_db_user"/ sql/CreateBaseDB.sql
   echo
   echo "Running script: sql/CreateBaseDB.sql"
   db2 -stvf sql/CreateBaseDB.sql
fi

cp sql/CreateBaseTable.sql.template sql/CreateBaseTable.sql
sed -i s/\$base_db_name/"$base_db_name"/ sql/CreateBaseTable.sql
sed -i s/\$base_db_user/"$base_db_user"/ sql/CreateBaseTable.sql

echo
echo "Running script: sql/CreateBaseTable.sql"
db2 -stvf sql/CreateBaseTable.sql

echo -e "\x1B[1;32mPlease note down the following information as you will need them to create the ADP database secret later: \x1B[0m"
echo "BASE_DB_USER="$base_db_user""
echo "BASE_DB_CONFIG=REPLACE_WITH_YOUR_DB_PASSWORD"
