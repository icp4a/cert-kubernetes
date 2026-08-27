#!/bin/bash
##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

echo
echo "---------------------------------------------------------------------------------------"
echo "This script will query the DPE Base database and list all the project databases and their status."
echo "status: 0 = not initialized"
echo "        1 = initialized"
echo "        2 = marked for deletion"
echo "---------------------------------------------------------------------------------------"


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


SaveIFS="$IFS"

IFS=$'\n'
db2 "connect to $base_db_name"
if [ $? -ne 0 ]; then
      exit
fi
db2 "set schema $base_db_user"
if [ $? -ne 0 ]; then
      exit
fi
array=($(db2 -x "select bas_id, dbname, dbstatus from tenantinfo order by bas_id"))
END=${#array[@]}
echo " "
echo "Total projects: "$END
echo " "
IFS="$SaveIFS"

printf "%-30s %-20s %-1s\n" "Project" "Database" "Status"
for i in $(seq 0 $(($END-1)))
do
  bas_id=$(echo ${array[i]} | awk '{print $1}')
  dbname=$(echo ${array[i]} | awk '{print $2}')
  dbstatus=$(echo ${array[i]} | awk '{print $3}')
  printf "%-30s  %-20s  %-1s\n" $bas_id $dbname $dbstatus
done
