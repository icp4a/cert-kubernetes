@echo off
REM ************************************************************************************
REM * @---lm_copyright_start
REM * 5737-I23, 5900-A30
REM * Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
REM * U.S. Government Users Restricted Rights:
REM * Use, duplication or disclosure restricted by GSA ADP Schedule
REM * Contract with IBM Corp.
REM * @---lm_copyright_end
REM ************************************************************************************

SETLOCAL

IF NOT DEFINED skip_create_base_db (
	set skip_create_base_db=false
)

IF "%skip_create_base_db%"=="true" (
    echo --
    echo This script will initialize an existing DB2 database for use as a Content Analyzer base database. 
	echo --
) ELSE (
    echo --
    echo This script will create and initialize a new DB2 database for use as a Content Analyzer base database. An existing database user must exist.
	echo --
)

	
set /p base_db_name= Enter the name of the Content Analyzer Base database. If nothing is entered, we will use the following default value 'CABASEDB': 
IF NOT DEFINED base_db_name SET "base_db_name=CABASEDB"

set /p base_db_user= Enter the name of the database user for the Content Analyzer Base database. If nothing is entered, we will use the following default value 'CABASEUSER' : 
IF NOT DEFINED base_db_user SET "base_db_user=CABASEUSER"

set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "N" goto :DOEXIT
if /I "%c%" EQU "n" goto :DOEXIT

IF "%skip_create_base_db%"=="true" (
    goto :DOCREATETABLE
) ELSE (
    goto :DOCREATE
)

:DOCREATE
    copy /Y sql\CreateBaseDB.sql.template sql\CreateBaseDB.sql
	powershell -Command "(gc sql\CreateBaseDB.sql) -replace '\$base_db_name', '%base_db_name%' | Out-File -encoding ascii sql\CreateBaseDB.sql
	powershell -Command "(gc sql\CreateBaseDB.sql) -replace '\$base_db_user', '%base_db_user%' | Out-File -encoding ascii sql\CreateBaseDB.sql
	echo "Creating a database using script sql\CreateBaseDB.sql"
    db2 -tvf sql\CreateBaseDB.sql
	goto DOCREATETABLE
:DOCREATETABLE
    copy /Y sql\CreateBaseTable.sql.template sql\CreateBaseTable.sql
	powershell -Command "(gc sql\CreateBaseTable.sql) -replace '\$base_db_name', '%base_db_name%' | Out-File -encoding ascii sql\CreateBaseTable.sql
	powershell -Command "(gc sql\CreateBaseTable.sql) -replace '\$base_db_user', '%base_db_user%' | Out-File -encoding ascii sql\CreateBaseTable.sql
	echo "Creating table TENANTINFO using script sql\CreateBaseTable.sql"
    db2 -tvf sql\CreateBaseTable.sql
	goto END
:DOEXIT
	echo "Exited on user input"
	goto END
:END
    set skip_create_base_db=
	echo "END"

ENDLOCAL