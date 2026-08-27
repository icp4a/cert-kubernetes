#!/bin/bash
##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##


# ==================================================
#
# This script will create the tables for a Document Processing Engine Project database and insert an entry into the Base database.
#
# ==================================================

export create_new_user=n
export tenant_db_exists=true
export tenant_type=0

./AddTenant.sh

unset create_new_user
unset tenant_db_exists
unset tenant_type