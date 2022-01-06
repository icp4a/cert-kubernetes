#!/bin/bash
# @---lm_copyright_start
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end

. ./ScriptFunctions.sh

echo -e "\n-- This script will delete all existing ACA projects marked for delete."
echo


default_basedb='BASECA'
if [[ -z "$base_db_name" ]]; then
  echo -e "\nEnter the name of the Base ACA database with the TENANTINFO Table. If nothing is entered, we will use the following default value : " $default_basedb
  read base_db_name
  if [[ -z "$base_db_name" ]]; then
     base_db_name=$default_basedb
  fi
fi

default_basedb_user='CABASEUSER'
if [[ -z "$base_db_user" ]]; then
  echo -e "\nEnter the name of the database user for the Base ACA database. If nothing is entered, we will use the following default value : " $default_basedb_user
  read base_db_user
  if [[ -z "$base_db_user" ]]; then
     base_db_user=$default_basedb_user 
  fi
fi

function delete_tenant(){
    tenant_db=$3
    base_db_name=$1
    base_db_user=$2
    tenant_user=$4
    tenant_id=$5
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
}


SaveIFS="$IFS"

IFS=$'\n'
db2 "connect to $base_db_name"
db2 "set schema $base_db_user"
array=($(db2 -x "select dbname,dbuser,tenantid from tenantinfo where dbstatus=2"))
END=${#array[@]}
echo "Total projects marked for delete: "$END
IFS="$SaveIFS"
for i in $(seq 0 $(($END-1)))
do
  tenant_db=$(echo ${array[i]} | awk '{print $1}')
  tenant_user=$(echo ${array[i]} | awk '{print $2}')
  tenant_id=$(echo ${array[i]} | awk '{print $3}')
  echo "Deleting the project with id: "$tenant_id
  delete_tenant $base_db_name $base_db_user $tenant_db $tenant_user $tenant_id
done
