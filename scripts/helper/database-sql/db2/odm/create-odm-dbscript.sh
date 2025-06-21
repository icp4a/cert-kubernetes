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

# function for creating the db sql statement file for ODM
function create_odm_db2_sql_file(){
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

    mkdir -p $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createODMDB.sql
cat << EOF > $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createODMDB.sql
-- Creating DB named: ${dbname}
CREATE DATABASE ${dbname} AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY US PAGESIZE 32 K;

-- connect to the created database:
CONNECT TO ${dbname};

-- Create bufferpool and tablespaces
CREATE BUFFERPOOL ${dbname}_BP32K SIZE 2000 PAGESIZE 32K;
CREATE TABLESPACE ${dbname}_RESDWTS PAGESIZE 32K BUFFERPOOL ${dbname}_BP32K;
CREATE SYSTEM TEMPORARY TABLESPACE ${dbname}_RESDWTMPTS PAGESIZE 32K BUFFERPOOL ${dbname}_BP32K;

GRANT CONNECT ON DATABASE TO USER ${dbuser}; 
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};

CONNECT RESET;
EOF
}


# function for creating the db rds sql statement file for ODM
# DBACLD-163779
function create_odm_db2rds_sql_file(){
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

    mkdir -p $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createODMDB.sql
cat << EOF > $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createODMDB.sql

-- Creating DB named: ${dbname} 
CALL rdsadmin.create_database('${dbname}',32768,'UTF-8','US' );

--- Comment out all SQL stored procedures below when you are creating the database.
--- Once the database is created, comment out the create_database stored procedure statement and uncomment the below statements and execute them.
--- Creation of the Database can take some time, Please wait for a few minutes before executing the statements below.

-- Create bufferpool 
CALL rdsadmin.create_bufferpool('${dbname}','${dbname}_BP32K',1024,'Y','Y',32768,0,32);

-- Create table spaces
CALL rdsadmin.create_tablespace( '${dbname}', '${dbname}_RESDWTS', '${dbname}_BP32K', 32768, NULL, NULL, 'T', 'AUTOMATIC');
CALL rdsadmin.create_tablespace( '${dbname}', '${dbname}_RESDWTMPTS', '${dbname}_BP32K', 32768, NULL, NULL, 'S', 'AUTOMATIC');

-- Create role for the database with the role name of ODM
CALL rdsadmin.create_role('${dbname}','ODM');
-- Create a user
CALL rdsadmin.add_user('${dbuser}','${dbpassword}','odm_group');
CALL rdsadmin.grant_role(?,'${dbname}','ODM','USER ${dbuser}','N');
CALL rdsadmin.dbadm_grant(?,'${dbname}','DBADM','GROUP odm_group');

--- Execute the below statement after the admin user is connected to the newly created Database
GRANT CONNECT ON DATABASE TO GROUP odm_group;
GRANT CREATETAB on DATABASE TO GROUP odm_group;
GRANT SELECT ON SYSIBM.SYSVERSIONS TO GROUP odm_group;
GRANT SELECT ON SYSCAT.DATATYPES TO GROUP odm_group;
GRANT SELECT ON SYSCAT.INDEXES TO GROUP odm_group;
GRANT SELECT ON SYSIBM.SYSDUMMY1 TO GROUP odm_group;
GRANT USAGE ON WORKLOAD SYSDEFAULTUSERWORKLOAD TO GROUP odm_group;
GRANT IMPLICIT_SCHEMA ON DATABASE TO GROUP odm_group;
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};
GRANT EXECUTE ON PACKAGE NULLID.SYSSH200 TO GROUP odm_group;
GRANT EXECUTE ON PACKAGE NULLID.SYSSN200 TO GROUP odm_group;
GRANT EXECUTE ON PACKAGE NULLID.SYSSN300 TO GROUP odm_group;
GRANT EXECUTE ON PROCEDURE SYSIBM.SQLGETTYPEINFO TO GROUP odm_group;
GRANT EXECUTE ON PROCEDURE SYSIBM.SQLTABLES TO GROUP odm_group;

-- Done creating and tuning DB named: ${dbname}

EOF
}