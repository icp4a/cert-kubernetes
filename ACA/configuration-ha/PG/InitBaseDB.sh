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
echo "=================================================="
echo
echo "This script will initialize an existing PostgreSQL database to be used as the Document Processing Engine Base database."
echo
echo "If you want the script to create the PostgreSQL database for you, please exit this script and run 'CreateBaseDB.sh' instead."
echo
echo "If you have already run 'CreateBaseDB.sh' script, you do NOT need to run this script."
echo
echo "=================================================="
echo

# to skip creating user
export create_new_base_user=n

# To skip creating base DB
export base_db_exists=true

./CreateBaseDB.sh

