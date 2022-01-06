#!/bin/bash
# @---lm_copyright_start
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end

. ./ScriptFunctions.sh

echo -e "\n-- This script will delete an existing BACA tenant"
echo

echo "Enter the tenant ID for the existing tenant: (eg. t4900)"
while [[ -z "$tenant_id" || $tenant_id == '' ]]
do
    echo "Please enter a valid value for the tenant ID:"
    read tenant_id
done

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



db2 "connect to $base_db_name"
db2 "set schema $base_db_user"
resp=$(db2 -x "select dbname,dbuser from tenantinfo where tenantid = '$tenant_id'")
tenant_db=$(echo  $resp | awk '{print $1}')
tenant_user=$(echo  $resp | awk '{print $2}') 

echo
echo "-- Please confirm these are the desired settings:"
echo " - tenant ID: $tenant_id"
echo " - tenant database name: $tenant_db"
echo " - base database: $base_db_name"
askForConfirmation

db2 "connect to $tenant_db"
resp=$(db2 -x "QUIESCE DATABASE IMMEDIATE FORCE CONNECTIONS")
rc=$(echo  $resp | awk '{print $1}')

if [[ "$rc" == "DB20000I" || "$rc" == "SQL1371W" ]]
then
   echo "DB Quiesced"
   db2 "unquiesce database"
   db2 "connect reset"
   resp=$(db2 -x "drop db $tenant_db")
   rc=$(echo  $resp | awk '{print $1}')
   if [[ "$rc" == "DB20000I" ]]
   then
      echo "DB Dropped"
      db2 "connect to $base_db_name"
      db2 "set schema $base_db_user"
      db2 "delete from tenantinfo where tenantid='$tenant_id'"
   else
      echo "Failed to drop the database: " $rc
   fi
else 
   echo "Quiesce failed: " $rc
fi 

