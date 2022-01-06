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

echo
echo "=================================================="
echo
echo "This script will load default data into the Project database"
echo
echo "=================================================="
echo

while [[ $tenant_db_name == '' ]]
do
  echo "Please enter the name of the Content Analyzer Project database to load data into: "
  read tenant_db_name
  while [ ${#tenant_db_name} -gt 8 ];
  do
    echo "Please enter a valid value for the project database name of max length 8 :"
    read tenant_db_name;
    echo ${#tenant_db_name};
  done
done

default_ontology='default'
if [[ -z "$tenant_ontology" ]]; then
  echo -e "\nEnter the ontology name. (It must match the ontology name used when running 'InitTenantDB.sh'). If nothing is entered, the default name will be used: " $default_ontology
  read tenant_ontology
  if [[ -z "$tenant_ontology" ]]; then
    tenant_ontology=${default_ontology}
  fi
fi

echo "-- Please confirm these are the desired settings:"
echo " - Project database name: $tenant_db_name"
echo " - ontology name: $tenant_ontology"
askForConfirmation

cwd=$(pwd)

echo 
echo "cd imports"
cd imports

db2 -v "CONNECT TO ${tenant_db_name}"

db2 -v "SET SCHEMA ${tenant_ontology}"

db2 -tvf ./importTables.sql

db2 -v "CONNECT RESET"

echo
echo "return to previous directory: ${cwd}"
cd ${cwd}
