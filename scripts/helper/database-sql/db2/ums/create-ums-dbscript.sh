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
function create_ums_db_db2_sql_file(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    dbschema=$4
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser 
    fi

    mkdir -p $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql
cat << EOF > $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql
-- Creating DB named: ${dbname} 
CREATE DATABASE ${dbname} USING CODESET UTF8 TERRITORY US;

GRANT CONNECT ON DATABASE TO USER ${dbuser}; 
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};
EOF
}

function create_ums_db_db2rds_sql_file(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    dbschema=$4
    dbpassword=$5
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")
    dbpassword=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbpassword")

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser 
    fi

    mkdir -p $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql
cat << EOF > $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql

-- Creating DB named: ${dbname} 
CALL rdsadmin.create_database('${dbname}',32768,'UTF-8','US' );

--- Comment out all SQL stored procedures below when you are creating the database.
--- Once the database is created, comment out the create_database stored procedure statement and uncomment the below statements and execute them.
--- Creation of the Database can take some time, Please wait for a few minutes before executing the statements below.

-- Create role for the database  with the role name of UMS
CALL rdsadmin.create_role('${dbname}','UMS');
-- Create a user
CALL rdsadmin.add_user('${dbuser}','${dbpassword}',null);
CALL rdsadmin.grant_role(?,'${dbname}','UMS','USER ${dbuser}','N');

--- Execute the below statement after the admin user is connected to the newly created Database
GRANT CONNECT ON DATABASE TO USER ${dbuser};
GRANT SELECT ON SYSIBM.SYSVERSIONS TO USER ${dbuser};
GRANT SELECT ON SYSCAT.DATATYPES TO USER ${dbuser};
GRANT SELECT ON SYSCAT.INDEXES TO USER ${dbuser};
GRANT SELECT ON SYSIBM.SYSDUMMY1 TO USER ${dbuser};
GRANT USAGE ON WORKLOAD SYSDEFAULTUSERWORKLOAD TO USER ${dbuser};
GRANT IMPLICIT_SCHEMA ON DATABASE TO USER ${dbuser};
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};
GRANT EXECUTE ON PACKAGE NULLID.SYSSH200 TO USER ${dbuser};

-- Done creating and tuning DB named: ${dbname}
EOF
}