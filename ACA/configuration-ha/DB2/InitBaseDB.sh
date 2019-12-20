#!/bin/bash

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

