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

echo
echo "------------------------------------------------------------------------------------------------------------------"
echo -e "\n-- This script will reinitialize (with default data) all existing ADP project databases marked for reclaiming (DBSTATUS=2)."
echo "------------------------------------------------------------------------------------------------------------------"

askForConfirmation

echo -e "\nThis script will query the DPE Base database to determine which databases (if any) are marked for reclaiming... \n"

default_basedb='BASECA'
if [[ -z "$base_db_name" ]]; then
  echo -e "\nEnter the name of the Base DPE database with the TENANTINFO Table. If nothing is entered, we will use the following default value : " $default_basedb
  read base_db_name
  if [[ -z "$base_db_name" ]]; then
     base_db_name=$default_basedb
  fi
fi

default_basedb_user='CABASEUSER'
if [[ -z "$base_db_user" ]]; then
  echo -e "\nEnter the name of the database user for the Base DPE database. If nothing is entered, we will use the following default value : " $default_basedb_user
  read base_db_user
  if [[ -z "$base_db_user" ]]; then
     base_db_user=$default_basedb_user 
  fi
fi

# Query Base DB for project DBs where dbstatus=2
SaveIFS="$IFS"
IFS=$'\n'
db2 "connect to $base_db_name"
db2 "set schema $base_db_user"
array=($(db2 -x "select dbname,dbuser,tenantid,ontology,project_guid from tenantinfo where dbstatus=2"))
END=${#array[@]}

# End script if no databases found matching query criteria
if [[ "$END" == "0" ]]; then
  echo -e "\nNo projects were found that are marked for reclaim.  No action will be taken."
  exit 0
fi

# Print summary of databases to be cleaned up and ask for confirmation
echo -e "\n-------------------------------------------------------------------------------------------------------------"
echo -e "\nIMPORTANT: The following project databases will be cleaned and reinitialized to default out-of-the-box data."
echo -e "(All changes made to these projects will be lost.) Please verify this is what you want:\n"

for j in $(seq 0 $(($END-1)))
do
  tenant_db=$(echo ${array[j]} | awk '{print $1}')
  tenant_id=$(echo ${array[j]} | awk '{print $3}')
  tenant_ontology=$(echo ${array[j]} | awk '{print $4}')
  project_guid=$(echo ${array[j]} | awk '{print $5}')
  echo "-- Project ID: " $project_guid " , tenant ID: " $tenant_id ", database name: " $tenant_db ", ontology: " $tenant_ontology
done

echo -e "\n--------------------------------------------------------------------------------------------------"
echo -e "\nTotal number of project databases that will be reinitialized: "$END

unset confirmation
askForConfirmation

# Perform cleanup
IFS="$SaveIFS"
for i in $(seq 0 $(($END-1)))
do
  db2 "connect reset"
  tenant_db=$(echo ${array[i]} | awk '{print $1}')
  tenant_user=$(echo ${array[i]} | awk '{print $2}')
  tenant_id=$(echo ${array[i]} | awk '{print $3}')
  tenant_ontology=$(echo ${array[i]} | awk '{print $4}')
  project_guid=$(echo ${array[i]} | awk '{print $5}')

  echo -e "\n-- Cleaning up the project database with project ID: " $project_guid " , tenant ID: " $tenant_id ", database name: " $tenant_db ", ontology: " $tenant_ontology
  db2 "connect to $tenant_db"
  db2 "set schema $tenant_ontology"
  echo -e "\nRunning script: sql/DropBacaTables.sql"
  db2 -stvf sql/DropBacaTables.sql
  echo -e "\nRunning script: sql/CreateBacaTables.sql"
  db2 -tf sql/CreateBacaTables.sql

  db2 "connect reset"
  db2 "connect to $base_db_name"
  db2 "set schema $base_db_user"
  db2 "update tenantinfo set dbstatus=0 where tenantid='$tenant_id' and ontology='$tenant_ontology'"

  echo -e "\n-- Done cleaning up the project database with project ID: " $project_guid " , tenant ID: " $tenant_id ", database name: " $tenant_db  "\n"

done
