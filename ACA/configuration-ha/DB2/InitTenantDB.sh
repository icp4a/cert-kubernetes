#!/bin/bash
# @---lm_copyright_start
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end

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