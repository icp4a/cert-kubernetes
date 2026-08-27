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

# function for creating the db sql statement file for BAN
function create_ban_db2_sql_file(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    dbschema=$4
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")

    # use ICNDB as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema="ICNDB" 
    fi

    mkdir -p $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createICNDB.sql
cat << EOF > $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createICNDB.sql
-- Creating DB named: ${dbname}
CREATE DATABASE ${dbname} AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY US PAGESIZE 32 K;
CONNECT TO ${dbname};
CREATE Bufferpool ${dbname}_BP IMMEDIATE SIZE AUTOMATIC PAGESIZE 32K;
CREATE Bufferpool ${dbname}_TEMPBP IMMEDIATE SIZE 200 PAGESIZE 32K;

-- The default table space name is "ICNDB".
-- If use default table space name "ICNDB", you do not need to input the value for spec.navigator_configuration.icn_production_setting.icn_table_space.
-- If change table space name, you need to use same value for spec.navigator_configuration.icn_production_setting.icn_table_space in custom resource.
CREATE REGULAR TABLESPACE ICNDB PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE AUTORESIZE YES INITIALSIZE 20 M INCREASESIZE 20 M BUFFERPOOL ${dbname}_BP;
GRANT USE OF TABLESPACE ICNDB TO user ${dbuser};

CREATE USER TEMPORARY TABLESPACE ${dbname}_TEMP PAGESIZE 32K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL ${dbname}_TEMPBP;
GRANT USE OF TABLESPACE ${dbname}_TEMP TO user ${dbuser};

GRANT CONNECT ON DATABASE TO USER ${dbuser}; 
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};

CONNECT RESET;
EOF
}

# function for creating the db rds sql statement file for BAN
# DBACLD-163779
function create_ban_db2rds_sql_file(){
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

    # use ICNDB as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema="ICNDB" 
    fi

    mkdir -p $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createICNDB.sql
cat << EOF > $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createICNDB.sql
-- Creating DB named: ${dbname}



CALL rdsadmin.create_database('${dbname}',32768,'UTF-8','US' );

--- Comment out all SQL stored procedures below when you are creating the database.
--- Once the database is created, comment out the create_database stored procedure statement and uncomment the below statements and execute them.
--- Creation of the Database can take some time, Please wait for a few minutes before executing the statements below.

CALL rdsadmin.create_bufferpool('${dbname}','${dbname}_BP',1024,'Y','Y',32768,0,32);
CALL rdsadmin.create_bufferpool('${dbname}', '${dbname}_TEMPBP',1024,'Y','Y',32768,0,32);

-- The default table space name is "ICNDB".
-- If use default table space name "ICNDB", you do not need to input the value for spec.navigator_configuration.icn_production_setting.icn_table_space.
-- If change table space name, you need to use same value for spec.navigator_configuration.icn_production_setting.icn_table_space in custom resource.

CALL rdsadmin.create_tablespace( '${dbname}', 'ICNDB', '${dbname}_BP', 32768, NULL, NULL, 'U', 'AUTOMATIC');

CALL rdsadmin.create_tablespace( '${dbname}', '${dbname}_TEMP', '${dbname}_TEMPBP', 32768, NULL, NULL, 'T', 'AUTOMATIC');

-- Create role for the database ICNDB with the role name of BAN
CALL rdsadmin.create_role('${dbname}','BAN');
-- Create a user
CALL rdsadmin.add_user('${dbuser}','${dbpassword}',null);
CALL rdsadmin.grant_role(?,'${dbname}','BAN','USER ${dbuser}','N');
CALL rdsadmin.dbadm_grant(?,'${dbname}','DBADM','USER ${dbuser}');
CALL rdsadmin.update_db_param('${dbname}','LOCKTIMEOUT','30');

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

EOF
}