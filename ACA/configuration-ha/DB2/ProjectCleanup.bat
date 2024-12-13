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

Title Reinitialize ADP Project Databases that are marked for deletion

@echo:
@echo:
echo -------------------------------------------------------------------------------
@echo:
echo This script will re-initialize with default data all existing ADP projects marked for delete
@echo:
echo -------------------------------------------------------------------------------
@echo:

set validArgs[1]=Y
set validArgs[2]=y
set validArgs[3]=Yes
set validArgs[4]=N
set validArgs[5]=n
set validArgs[6]=No

:CONFIRMLOOP1
  set /P confirm1=Are you sure you want to continue[Y/N]?
  REM Check if the response is valid or not
  for /L %%i in (1,1,6) do if /I "%confirm1%" equ "!validArgs[%%i]!" goto :PROCESSLOOP1 
  REM if not a valid response, ask again
  goto :CONFIRMLOOP1
:PROCESSLOOP1
if /I "%confirm1%" EQU "N" goto :DOEXIT
if /I "%confirm1%" EQU "n" goto :DOEXIT
if /I "%confirm1%" EQU "No" goto :DOEXIT


@echo:
echo - This script will query the DPE Base database to determine if which project databases (if any) are marked for deletion...
@echo:
set /p base_db_name= "Enter the name of the DPE Base database. If nothing is entered, we will use the default value 'CABASEDB': "
IF NOT DEFINED base_db_name SET "base_db_name=CABASEDB"

@echo:
set /p base_db_user= "Enter the name of the database user for DPE Base database. If nothing is entered, we will use the default value 'CABASEUSER' : "
IF NOT DEFINED base_db_user SET "base_db_user=CABASEUSER"


Set DBListFile=db_list_to_reinit.txt
If exist "%DBListFile%" Del "%DBListFile%"
If exist "%DBListFile%".trim Del "%DBListFile%".trim
If exist "%DBListFile%".trim.csv Del "%DBListFile%".trim.csv

@echo:
@echo:
echo - Checking the Base database for project databases marked for deletion

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
db2 -x "select dbname,dbuser,tenantid,project_guid,ontology from tenantinfo where dbstatus=2" > %DBListFile%
IF %ERRORLEVEL% NEQ 0 (
   @echo:
   @echo:
   echo -- No databases found that are marked for deletion [dbstatus=2].
   echo Check the file '%DBListFile%'  
   echo - If there is an error in the file, please confirm if the database name and username/schema name are correct.
   echo - If the file is empty, the query did no find any databases marked for deletion [dbstatus=2]
   goto :END
)

@echo:
echo Logout DB2 database
db2 connect reset

powershell -Command "Get-Content %DBListFile% | Foreach {$_.TrimEnd()} | Set-Content -encoding ascii %DBListFile%.trim"

If not exist "%DBListFile%".trim (
  @echo:
  echo No databases found that were marked for deletion [dbstatus=2] 
  goto :END
)

REM Convert the list to comma-separted list to make it easier to parse
powershell -Command "Get-Content %DBListFile%.trim | Foreach {$_ -split '\s+',5,\"RegexMatch\" -join ','} | Set-Content -encoding ascii %DBListFile%.trim.csv"

set /a DBCOUNT=0
for /F "tokens=1-5 delims=," %%A in (%DBListFile%.trim.csv) do (
    set /a DBCOUNT+=1
    set dbname[!DBCOUNT!]=%%~A
    set dbuser[!DBCOUNT!]=%%~B
    set tenantid[!DBCOUNT!]=%%~C
    set project_guid[!DBCOUNT!]=%%~D
  set ontology[!DBCOUNT!]=%%~E
)

@echo:
echo -- %DBCOUNT% total project databases that will be reinitialized (where db2status=2)

if %DBCOUNT% GTR 0 (
  @echo:
  echo ---------------------------------------------------------------------------------------------------
  echo IMPORTANT: The following project databases will be reinitialized with default data.  Please verify this is what you want: 
  echo ---------------------------------------------------------------------------------------------------
)

for /l %%i in (1,1,%DBCOUNT%) do (
  echo  [%%i] Project ID: !project_guid[%%i]!  tenant ID: !tenantid[%%i]!  database name: !dbname[%%i]!
)

@echo:
:CONFIRMLOOP2
  set /P confirm2=Are you sure you want to continue[Y/N]?
  REM Check if the response is valid or not
  for /L %%i in (1,1,6) do (if /I "%confirm2%" equ "!validArgs[%%i]!" goto :PROCESSLOOP2)
  REM if not a valid response, ask again
  goto :CONFIRMLOOP2
:PROCESSLOOP2
  if /I "%confirm2%" EQU "N" goto :DOEXIT
  if /I "%confirm2%" EQU "n" goto :DOEXIT
  if /I "%confirm2%" EQU "No" goto :DOEXIT


REM For loop to process each database to reinit

for /l %%j in (1,1,%DBCOUNT%) do (
  @echo:
  echo --- Preparing to reinitialize database:  Project ID: !project_guid[%%j]!  tenant ID: !tenantid[%%j]!  database name: !dbname[%%j]!
  @echo:
  
  echo connect to !dbname[%%j]!
  db2 "connect to !dbname[%%j]!"
  IF %ERRORLEVEL% NEQ 0 (
    @echo:
    echo ----- ERROR ----
    echo DB2 connection to !dbname[%%j]! failed. Please confirm the database exists and you are running as user with DB2 admin privileges
    goto :END
  )
  
  @echo:
  echo Setting schema to !ontology[%%j]!
  db2 "set schema !ontology[%%j]!"

  REM ----------- Drop DB tables -----------    
  @echo:
  echo Running script: sql/DropBacaTables.sql
  db2 -stvf sql/DropBacaTables.sql

  REM ----------- Recreate tables DB -----------    
  @echo:
  echo Running script: sql/CreateBacaTables.sql
  db2 -tf sql/CreateBacaTables.sql

  db2 "connect reset"

  @echo:
  echo - Database !dbname[%%j]! has been reinitialized

  REM ----------- Update DBSTATUS in TENANTINFO table -----------
  @echo:
  echo Connecting to Base DB %base_db_name% to update DBSTATUS of project with tenantid !tenantid[%%j]! and ontology='!ontology[%%j]!'
  db2 "connect to %base_db_name%"
  db2 "set schema %base_db_user%"

  @echo:
  echo update tenantinfo set dbstatus=0 where tenantid='!tenantid[%%j]!' and ontology='!ontology[%%j]!'
  db2 "update tenantinfo set dbstatus=0 where tenantid='!tenantid[%%j]!' and ontology='!ontology[%%j]!'"

  db2 "connect reset"

  @echo:
  echo --- Reinitialized database:  Project ID: !project_guid[%%j]!  tenant ID: !tenantid[%%j]!  database name: !dbname[%%j]!

)

goto :END
    
:DOEXIT
    echo Exited on user input
    goto :END
:END
    @echo:
    echo End of script
  
ENDLOCAL
