#!/bin/bash

. ScriptFunctions.sh

INPUT_PROPS_FILENAME="./common_for_DB2.sh"

if [ -f $INPUT_PROPS_FILENAME ]; then
   echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
   . $INPUT_PROPS_FILENAME
fi

default_basedb='CABASEDB'
echo -e "\n-- This script will create the BACA Base database."

if [[ -z "$base_db_name" ]]; then
    echo -e "\nEnter the name of the BACA Base database to create. (The name must be 8 chars or less). If nothing is entered, we will use this default value : " $default_basedb
    read base_db_name
    if [[ -z "$base_db_name" ]]; then
      base_db_name=$default_basedb
    fi
    while [ ${#base_db_name} -gt 8 ];
        do
        echo "Please enter a valid value for the tenant database name of max length 8 :"
        read base_db_name;
        echo ${#base_db_name};
    done
fi

if [[ -z "$base_valid_user" ]]; then
  base_valid_user=0
fi

while [[ $base_valid_user -ne 1 ]]
do
    echo -e "\nWe need to create a non-admin database user to access BASE database."
    echo "Enter the name of database user to create: "
    read base_db_user
    while [[ $base_db_user == '' ]]
    do
        echo "Enter a valid value"
        read base_db_user
    done

    getent passwd $base_db_user > /dev/null
    if [[ $? -eq 0 ]]; then
        echo "$base_db_user already exists.  Do you want to use this user (y/n)"
        read use_existing_user
        if [ "$use_existing_user" = "y" ] || [ "$use_existing_user" = "Y" ]; then
           base_user_already_defined=1
           base_valid_user=1
        fi
    else
        base_valid_user=1
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
echo "-- Information gathering is completed.  Create base DB is about to begin."
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

cp sql/CreateBaseDB.sql.template sql/CreateBaseDB.sql
sed -i s/\$base_db_name/"$base_db_name"/ sql/CreateBaseDB.sql
sed -i s/\$base_db_user/"$base_db_user"/ sql/CreateBaseDB.sql
# sed -i s/\$db_user_pwd/"$db_user_pwd"/ sql/CreateBaseDB.sql

echo
echo "Running script: sql/CreateBaseDB.sql"
db2 -stvf sql/CreateBaseDB.sql

