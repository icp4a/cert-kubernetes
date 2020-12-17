#!/bin/bash
# @---lm_copyright_start
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end


# ==================================================
#
# This script will create the tables for the Content Analyzer Project database and insert an entry into the Base database.
#
# ==================================================

export create_new_user=n
export tenant_db_exists=true
export tenant_type=0

./AddTenant.sh

unset create_new_user
unset tenant_db_exists
unset tenant_type