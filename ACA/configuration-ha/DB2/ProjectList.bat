::
:: Licensed Materials - Property of IBM
:: 5737-I23
:: Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
:: U.S. Government Users Restricted Rights:
:: Use, duplication or disclosure restricted by GSA ADP Schedule
:: Contract with IBM Corp.
::
@echo off

SETLOCAL EnableDelayedexpansion

Title List all ADP projects with its DB name and status

@echo:
@echo:
echo -------------------------------------------------------------------------------
@echo:
echo This script will query the DPE Base database and list all the project databases and their status.
echo status: 0 = not initialized
echo         1 = initialized
echo         2 = marked for deletion
@echo:
echo -------------------------------------------------------------------------------
@echo:

set /p base_db_name= "Enter the name of the DPE Base database. If nothing is entered, we will use the default value 'BASECA': "
IF NOT DEFINED base_db_name SET "base_db_name=BASECA"

@echo:
set /p base_db_user= "Enter the name of the database user for DPE Base database. If nothing is entered, we will use the default value 'CABASEUSER' : "
IF NOT DEFINED base_db_user SET "base_db_user=CABASEUSER"


Set DBListFile=project_db_list.txt
If exist "%DBListFile%" Del "%DBListFile%"
If exist "%DBListFile%".trim Del "%DBListFile%".trim
If exist "%DBListFile%".trim.csv Del "%DBListFile%".trim.csv

@echo:
echo Login to DPE Base database %base_db_name%
db2 connect to %base_db_name%
IF %ERRORLEVEL% NEQ 0 (
  @echo:
  echo ----- ERROR ----
  echo DB2 connection to %base_db_name% failed. Please confirm if the name is correct and you are running as user with DB2 admin privileges
  goto :END
)
echo Setting schema to %base_db_user%
db2 set schema %base_db_user%
db2 -x "select bas_id, dbname, dbstatus from tenantinfo order by bas_id" > %DBListFile%
IF %ERRORLEVEL% NEQ 0 (
   @echo:
   @echo:
   echo -- No databases found.
   echo Check the file '%DBListFile%'  
   echo - If there is an error in the file, please confirm if the database name and username/schema name are correct.
   echo - If the file is empty, the query did no find any databases
   goto :END
)

@echo:
echo Logout DB2 database
db2 connect reset

powershell -Command "Get-Content %DBListFile% | Foreach {$_.TrimEnd()} | Set-Content -encoding ascii %DBListFile%.trim"

If not exist "%DBListFile%".trim (
  @echo:
  echo No databases found
  goto :END
)

REM Convert the list to comma-separted list to make it easier to parse
powershell -Command "Get-Content %DBListFile%.trim | Foreach {$_ -split '\s+',3,\"RegexMatch\" -join ','} | Set-Content -encoding ascii %DBListFile%.trim.csv"

set /a DBCOUNT=0
for /F "tokens=1-5 delims=," %%A in (%DBListFile%.trim.csv) do (
    set /a DBCOUNT+=1
    set bas_id[!DBCOUNT!]=%%~A
    set dbname[!DBCOUNT!]=%%~B
    set dbstatus[!DBCOUNT!]=%%~C
)

@echo:
echo -- "Total projects: %DBCOUNT%

for /l %%i in (1,1,%DBCOUNT%) do (
  echo  [%%i] Project: !bas_id[%%i]!  Database: !dbname[%%i]!  Status: !dbstatus[%%i]!
)

goto :END

:END
    @echo:
    echo End of script
  
ENDLOCAL
