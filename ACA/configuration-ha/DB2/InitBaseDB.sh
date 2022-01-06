#!/bin/bash
##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2021. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

echo
echo "=================================================="
echo
echo "This script will initialize an existing DB2 database to be used as the Content Analyzer Base database."
echo
echo "If you want the script to create a DB2 database for you, please exit this script and run 'CreateBaseDB.sh' instead."
echo
echo "=================================================="
echo

# to skip creating user
export create_new_base_user=n

# To skip creating base DB
export base_db_exists=true

./CreateBaseDB.sh

