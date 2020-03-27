#!/usr/bin/env bash
. ./ScriptFunctions.sh

if [[ -z $INPUT_PROPS_FILENAME ]]; then
    INPUT_PROPS_FILENAME="./common_for_DB2_Tenant_Upgrade.sh"
fi

if [ -f $INPUT_PROPS_FILENAME ]; then
   echo "Found a $INPUT_PROPS_FILENAME.  Reading in variables from that script."
   . $INPUT_PROPS_FILENAME
fi

echo -e "\n-- This script will upgrade tenant DB"
echo

while [[ $tenant_db_name == '' ]]
do
  echo "Please enter a valid value for the tenant database name :"
  read tenant_db_name
  while [ ${#tenant_db_name} -gt 8 ];
  do
    echo "Please enter a valid value for the tenant database name :"
    read tenant_db_name;
    echo ${#tenant_db_name};
  done
done

while [[ -z "$tenant_db_user" ||  $tenant_db_user == "" ]]
do
  echo "Please enter a valid value for the tenant database user name :"
  read tenant_db_user
done

while [[ $tenant_ontology == '' ]]
do
  echo "Please enter a valid value for the tenant ontology name :"
  read tenant_ontology
done

echo
echo "-- Please confirm these are the desired settings:"
echo " - ontology: $tenant_ontology"
echo " - tenant database name: $tenant_db_name"
echo " - tenant database user name: $tenant_db_user"
askForConfirmation

if [[ $SaaS != "true" || -z $SaaS ]]; then
    cp sql/UpgradeTenantDB_to_1.1.sql.template sql/UpgradeTenantDB_to_1.1.sql
    sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/UpgradeTenantDB_to_1.1.sql
    sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/UpgradeTenantDB_to_1.1.sql
    sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/UpgradeTenantDB_to_1.1.sql
    echo
    echo "Running upgrade script: sql/UpgradeTenantDB_to_1.1.sql"
    db2 -stvf sql/UpgradeTenantDB_to_1.1.sql
else
    echo "-- Skipping UpgradeTenantDB_to_1.1.sql"
fi

cp sql/UpgradeTenantDB_1.1_to_1.2.sql.template sql/UpgradeTenantDB_1.1_to_1.2.sql
sed -i s/\$tenant_db_name/"$tenant_db_name"/ sql/UpgradeTenantDB_1.1_to_1.2.sql
sed -i s/\$tenant_ontology/"$tenant_ontology"/ sql/UpgradeTenantDB_1.1_to_1.2.sql
sed -i s/\$tenant_db_user/"$tenant_db_user"/ sql/UpgradeTenantDB_1.1_to_1.2.sql
echo
echo "Running upgrade script: sql/UpgradeTenantDB_1.1_to_1.2.sql"
db2 -stvf sql/UpgradeTenantDB_1.1_to_1.2.sql