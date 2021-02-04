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

echo.
echo --
echo This script will load default data into the Project database. 
echo --
echo.

:GETDBNAME
set /p tenant_db_name= "Please enter the name of the Content Analyzer Project database to load data into: (max length 8) :"
IF NOT DEFINED tenant_db_name goto :GETDBNAME
echo.

set /p tenant_ontology= "Enter the ontology name. (It must match the ontology name used when running 'InitTenantDB.sh'). If nothing is entered, the default name will be used 'default' :" 
IF NOT DEFINED tenant_ontology SET "tenant_ontology=default"

echo.
echo -- Please confirm these are the desired settings:
echo  - Project database name: %tenant_db_name%
echo  - Project ontology: %tenant_ontology%
echo.
set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "N" goto :DOEXIT
if /I "%c%" EQU "n" goto :DOEXIT


:LOADDATA
	SET cwd=%CD%
	echo.
	echo cd imports
	cd imports

	db2 -v "CONNECT TO %tenant_db_name%"
	db2 -v "SET SCHEMA %tenant_ontology%"
	db2 -tvf ./importTables.sql
	db2 -v "CONNECT RESET"

	echo.
	echo Return to previous directory: %cwd%
	cd %cwd%
	goto :END
:DOEXIT
	echo Exited on user input
	goto :END
:END
	echo END

ENDLOCAL