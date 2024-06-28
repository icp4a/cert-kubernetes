#!/BIN/BASH

###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2022. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################

# function for creating the db sql statement file for UMS database
function create_ums_db_oracle_sql_file(){
    dbuser=$1
    dbuserpwd=$2
    dbserver=$3
    # remove quotes from beginning and end of string
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuser=$(echo $dbuser | tr '[:lower:]' '[:upper:]')
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    mkdir -p $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql
cat << EOF > $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql
-- Please ensure you already have existing oracle instance or pluggable database (PDB). If not, please create one first

-- create a new user
CREATE USER ${dbuser} IDENTIFIED BY "${dbuserpwd}";

-- allow the user to connect to the database
GRANT CONNECT TO ${dbuser};

GRANT CREATE TABLE TO ${dbuser};
GRANT CREATE SESSION TO ${dbuser};
GRANT CREATE SEQUENCE TO ${dbuser};
GRANT UNLIMITED TABLESPACE TO ${dbuser};

EOF
}
