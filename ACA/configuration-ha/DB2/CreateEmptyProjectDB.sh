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

INPUT_PROPS_FILENAME="./common_for_DB2.sh"
if [ -f $INPUT_PROPS_FILENAME ]; then
   echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
   . $INPUT_PROPS_FILENAME
fi

echo
echo "=================================================="
echo 
echo "This script will create an empty database."
echo
echo "=================================================="


echo
while [[ $tenant_db_name == '' ]]
do
  echo "Please enter the name of the new Document Processing Engine Project database to create (max length 8) :"
  read tenant_db_name
  while [ ${#tenant_db_name} -gt 8 ];
  do
    echo "Please enter a valid value for the Project database name of max length 8 :"
    read tenant_db_name;
    echo ${#tenant_db_name};
  done
done

echo
echo "We need a non-admin database user that Document Processing Engine will use to access your Document Processing Engine Project database."
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
        echo "Please enter the name of an existing database user with read and write privileges for the Document Processing Engine Project database: "
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


# --- Info summary ---
echo
echo "-- Information gathering is completed.  Please confirm these are the desired settings:"
echo " - Project database name: $tenant_db_name"
if [[ $user_already_defined -ne 1 ]]; then
  echo " - Project database user will be created by this script"
else
  echo " - Project database user already exists and will not be created by this script"
fi
echo " - Project database user: $tenant_db_user"

askForConfirmation


# --- Create user ---
if [[ $user_already_defined -ne 1 ]]; then
   echo
   echo "Creating user"
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

# --- Create database ---
cp sql/CreateDB.sql.template sql/CreateDB.sql
sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/CreateDB.sql
sed -i s/\${tenant_db_name}/"$tenant_db_name"/ sql/CreateDB.sql
# repeat in order to get any lines that had the string twice on same line
sed -i s/\${tenant_db_name}/"$tenant_db_name"/ sql/CreateDB.sql
sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/CreateDB.sql

echo -e "\nRunning script: sql/CreateDB.sql"
db2 -stvf sql/CreateDB.sql

# allow error when set permission for Tenant DB since DB2 use db2inst1 usually.
cp sql/GrantPermissionsDB.sql.template sql/GrantPermissionsDB.sql
sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/GrantPermissionsDB.sql
sed -i s/\${tenant_db_name}/"$tenant_db_name"/ sql/GrantPermissionsDB.sql
# repeat in order to get any lines that had the string twice on same line
sed -i s/\${tenant_db_name}/"$tenant_db_name"/ sql/GrantPermissionsDB.sql
sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/GrantPermissionsDB.sql
echo
echo "Running script: sql/GrantPermissionsDB.sql"
db2 -tvf sql/GrantPermissionsDB.sql