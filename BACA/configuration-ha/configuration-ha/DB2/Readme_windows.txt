Prerequisite  : DB2 v11 fixpack 2 or higher
Intructions to create BACA databases. Baca uses two database one is called
base database and the other is called tenant database.
1. Before running the scripts file you need to create two windows non-admin
   users who are also db2 regular users.These users are used to connect 
   databases.The db scripts are initilized with cabaseuser and tenantuser.
2. Open db2 administrator command window to run the script files.
3. Run the CreateBaseDB.bat to create the base database.
3. Run AddTenant.bat to add a new tenant db and ontology. 
   You can aslo run this script file to add a new ontology
   for existing tenant database.