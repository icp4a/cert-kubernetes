#!/bin/bash

echo
echo "=================================================="
echo
echo "This script will add a new BACA tenant by initializing a DB2 database to be a CA tenant database and inserting a tenant entry into the CA Base database."
echo
echo "If you want the script to create a DB2 database for you, please exit this script and run 'AddTenant.sh' instead."
echo
echo "=================================================="
echo

export create_new_user=n
export tenant_db_exists=true

./AddTenant.sh