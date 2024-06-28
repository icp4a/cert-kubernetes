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
function create_ums_db_sqlserver_sql_file(){
    dbname=$1
    dbuser=$2
    dbuserpwd=$3
    dbserver=$4
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    mkdir -p $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql
cat << EOF > $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql
-- create ums database
CREATE DATABASE ${dbname};
GO
ALTER DATABASE ${dbname} SET READ_COMMITTED_SNAPSHOT ON;

USE ${dbname}
GO
CREATE USER ${dbuser} FOR LOGIN ${dbuser} WITH DEFAULT_SCHEMA=${dbuser}
GO
CREATE SCHEMA ${dbuser} AUTHORIZATION ${dbuser}
GO
EXEC sp_addrolemember 'db_ddladmin', ${dbuser};
EXEC sp_addrolemember 'db_datareader', ${dbuser};
EXEC sp_addrolemember 'db_datawriter', ${dbuser};
EXEC sp_addrolemember 'db_securityadmin', ${dbuser};
GO
EOF
}