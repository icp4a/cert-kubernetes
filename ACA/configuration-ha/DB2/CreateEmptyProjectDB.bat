::
:: Licensed Materials - Property of IBM
:: 5737-I23
:: Copyright IBM Corp. 2018 - 2021. All Rights Reserved.
:: U.S. Government Users Restricted Rights:
:: Use, duplication or disclosure restricted by GSA ADP Schedule
:: Contract with IBM Corp.
::
@echo off

SETLOCAL

IF NOT DEFINED skip_create_base_db (
	set skip_create_base_db=false
)

echo.
echo --
echo This script will create an empty DB2 database for use as a Content Analyzer Project database. 
echo --
echo.

:GETDBNAME
set /p tenant_db_name= "Please enter the name of the new Content Analyzer Project database to create (max length 8) :"
IF NOT DEFINED tenant_db_name goto :GETDBNAME
echo.

echo "We need a database user that Content Analyzer will use to access your Content Analyzer Tenant database."
:GETUSERNAME
set /p tenant_db_user= "Please enter the name of an existing database user to access the Content Analyzer Tenant database: "
IF NOT DEFINED tenant_db_user goto :GETUSERNAME

echo.
echo -- Please confirm these are the desired settings:
echo  - Project database name: %tenant_db_name%
echo  - Project database user: %tenant_db_user%
echo.
set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "N" goto :DOEXIT
if /I "%c%" EQU "n" goto :DOEXIT


:CREATEDB
    copy /Y sql\CreateDB.sql.template sql\CreateDB.sql
	powershell -Command "(gc sql\CreateDB.sql) -replace '\${tenant_db_name}', '%tenant_db_name%' | Out-File -encoding ascii sql\CreateDB.sql
	powershell -Command "(gc sql\CreateDB.sql) -replace '\$tenant_db_user', '%tenant_db_user%' | Out-File -encoding ascii sql\CreateDB.sql
	echo "Creating a database using script sql\CreateDB.sql ...."
    db2 -tvf sql\CreateDB.sql
	goto :END
:DOEXIT
	echo Exited on user input
	goto :END
:END
	echo END

ENDLOCAL