@echo off

SETLOCAL

set /p tenant_db_name= Please enter a valid value for the tenant database name :
set /p tenant_db_user= Please enter a valid value for the tenant database user name :
set /p tenant_ontology= Please enter a valid value for the tenant ontology name :

echo
echo "-- Please confirm these are the desired settings:"
echo " - tenant database name: %tenant_db_name%"
echo " - tenant database user name: %tenant_db_user%"
echo " - ontology name: %tenant_ontology%"

set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "Y" goto :DOCREATE
if /I "%c%" EQU "N" goto :DOEXIT

:DOCREATE
	echo "Connecting to db and schema"
	db2 connect to %tenant_db_name%
	db2 set schema %tenant_ontology%
	db2 -stvf sql\WinUpgradeTenantDB_1.3_to_1.4.sql
	goto END
:DOEXIT
	echo "Exited on user input"
	goto END
:END
	echo "END"

ENDLOCAL
