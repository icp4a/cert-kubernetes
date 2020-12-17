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

set /p base_db_name= Please enter a valid value for the base database name :
set /p base_db_user= Please enter a valid value for the base database user name :
set /p tenant_id= Please enter a valid value for the tenant ID:
set /p tenant_ontology= Please enter a valid value for the tenant ontology:

echo
echo "-- Please confirm these are the desired settings:"
echo " - Base database name: %base_db_name%"
echo " - Base database user name: %base_db_user%"
echo " - Tenant ID: %tenant_id%"
echo " - Tenant ontology: %tenant_ontology%"


set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "Y" goto :DOCREATE
if /I "%c%" EQU "N" goto :DOEXIT

:DOCREATE
	echo "Connecting to db and schema"
	db2 CONNECT TO %base_db_name%
	db2 SET SCHEMA %base_db_user%
	db2 update tenantinfo set TENANTDBVERSION=1.6 where TENANTID='%tenant_id%' and ONTOLOGY='%tenant_ontology%'
	db2 connect reset
	goto END

:DOEXIT
	echo "Exited on user input"
	goto END

:END
	echo "END"

ENDLOCAL