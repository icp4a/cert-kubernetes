#!/usr/bin/env bash
# @---lm_copyright_start
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end

. ./ScriptFunctions.sh

if [[ -z $INPUT_PROPS_FILENAME ]]; then
    INPUT_PROPS_FILENAME="./common_for_DB2_Tenant_Upgrade.sh"
fi

if [ -f $INPUT_PROPS_FILENAME ]; then
   echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
   . $INPUT_PROPS_FILENAME
fi

echo -e "\n-- This script will update the tenant's info in the TENANTINFO table in the base DB"
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

while [[ -z "$tenant_id" || $tenant_id == '' ]]
do
    echo "Please enter a valid value for the tenant ID:"
    read tenant_id
done

while [[ -z "$tenant_ontology" || $tenant_ontology == '' ]]
do
  echo "Please enter a valid value for the tenant ontology:"
  read tenant_ontology
done

echo
echo "-- Please confirm these are the desired settings:"
echo " - Base database name: $base_db_name"
echo " - Base database user name: $base_db_user"
echo " - Tenant ID: $tenant_id"
echo " - Tenant ontology: $tenant_ontology"
askForConfirmation

cp sql/UpdateTenantInfo_in_BaseDB_1.5_to_1.6.sql.template sql/UpdateTenantInfo_in_BaseDB_1.5_to_1.6.sql
sed -i s/\$base_db_name/"$base_db_name"/g sql/UpdateTenantInfo_in_BaseDB_1.5_to_1.6.sql
sed -i s/\$base_db_user/"$base_db_user"/g sql/UpdateTenantInfo_in_BaseDB_1.5_to_1.6.sql
sed -i s/\$tenant_id/"$tenant_id"/g sql/UpdateTenantInfo_in_BaseDB_1.5_to_1.6.sql
sed -i s/\$tenant_ontology/"$tenant_ontology"/g sql/UpdateTenantInfo_in_BaseDB_1.5_to_1.6.sql
echo
echo "Running upgrade script: sql/UpdateTenantInfo_in_BaseDB_1.5_to_1.6.sql"
db2 -stvf sql/UpdateTenantInfo_in_BaseDB_1.5_to_1.6.sql