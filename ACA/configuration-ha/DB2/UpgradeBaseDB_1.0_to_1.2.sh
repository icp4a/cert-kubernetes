#!/usr/bin/env bash
# @---lm_copyright_start
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end

. ./ScriptFunctions.sh

INPUT_PROPS_FILENAME="./common_for_DB2_Upgrade.sh"

if [ -f $INPUT_PROPS_FILENAME ]; then
   echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
   . $INPUT_PROPS_FILENAME
fi

echo -e "\n-- This script will upgrade base DB"
echo

while [[ $base_db_name == '' ]]
do
  echo "Please enter a valid value for the base database name :"
  read base_db_name
  while [ ${#base_db_name} -gt 8 ];
  do
    echo "Please enter a valid value for the base database name :"
    read base_db_name;
    echo ${#base_db_name};
  done
done

while [[ -z "$base_db_user" ||  $base_db_user == "" ]]
do
  echo "Please enter a valid value for the base database user name :"
  read base_db_user
done

echo
echo "-- Please confirm these are the desired settings:"
echo " - Base database name: $base_db_name"
echo " - Base database user name: $base_db_user"
askForConfirmation

if [[ $SaaS != "true" || -z $SaaS ]]; then
    cp sql/UpgradeBaseDB_to_1.1.sql.template sql/UpgradeBaseDB_to_1.1.sql
    sed -i s/\$base_db_name/"$base_db_name"/ sql/UpgradeBaseDB_to_1.1.sql
    sed -i s/\$base_db_user/"$base_db_user"/ sql/UpgradeBaseDB_to_1.1.sql
    echo
    echo "Running upgrade script: sql/UpgradeBaseDB_to_1.1.sql"
    db2 -stvf sql/UpgradeBaseDB_to_1.1.sql
else
    echo "-- Skipping UpgradeBaseDB_to_1.1.sql"
fi

cp sql/UpgradeBaseDB_1.1_to_1.2.sql.template sql/UpgradeBaseDB_1.1_to_1.2.sql
sed -i s/\$base_db_name/"$base_db_name"/ sql/UpgradeBaseDB_1.1_to_1.2.sql
sed -i s/\$base_db_user/"$base_db_user"/ sql/UpgradeBaseDB_1.1_to_1.2.sql
echo
echo "Running upgrade script: sql/UpgradeBaseDB_1.1_to_1.2.sql"
db2 -stvf sql/UpgradeBaseDB_1.1_to_1.2.sql