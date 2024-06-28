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
function create_ums_db_postgresql_sql_file(){
    dbname=$1
    dbuser=$2
    dbuserpwd=$3
    dbserver=$4
    dbschema=$5
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")

    # convert to lowercase for postgreSQL dbname
    dbname=$(echo $dbname | tr '[:upper:]' '[:lower:]')
    dbschema=$(echo $dbschema | tr '[:upper:]' '[:lower:]')

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser 
    fi

    mkdir -p $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql
cat << EOF > $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql

-- create the user
CREATE ROLE ${dbuser} WITH INHERIT LOGIN ENCRYPTED PASSWORD '${dbuserpwd}';

-- create the database:
CREATE DATABASE ${dbname} WITH OWNER ${dbuser} ENCODING 'UTF8';

-- Connect to your database and create schema
\c ${dbname};
CREATE SCHEMA IF NOT EXISTS ${dbschema} AUTHORIZATION ${dbuser};
GRANT ALL ON schema ${dbschema} to ${dbuser};
EOF
}
