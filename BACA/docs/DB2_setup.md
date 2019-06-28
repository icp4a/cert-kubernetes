## Creating BaseDB and TenantDB on Db2

### Create Content Analyzer BaseDB
After the configuration/DB2 directory has been copied to the Db2 server, run the CreateBaseDB.sh script from the command prompt.  
>Note: Run the following scripts with a Db2 user such as db2inst1 who has 'su' privilege.  

#### Procedure:
As prompted, enter the following data:

- Enter the name of the IBM Business Automation Content Analyzer Base database (enter a unique name of 8 characters or less and no special characters. for example, CABASEDB)
- Enter the name of database user – (enter a database user name that will have full permissions to the base database) – this can be a new or existing Db2 user
- Enter the password for the above user – enter a password each time when prompted. If this is an existing user, this prompt will be skipped

### Create Content Analyzer Tenant DB
Create the Content Analyzer Tenant DB and add it to the basedb by running the AddTenant.sh script on the Db2 server.

#### Procedure

As prompted, enter the following:  
   - Enter the tenant ID – (an alphanumeric value that will be used by the user to reference the database)
   - Enter the name of the IBM Business Automation Content Analyzer tenant database to create - (an alphanumeric value for the actual database name in Db2)
   - Enter the host/IP of the database server – (the IP address of the database server)
   - Enter the port of the database server – Press Enter to accept default of 50000 (or enter the port number if a different port is required)
   - Do you want this script to create a database user – y (for yes)
       - Enter the name of database user – (this will be the tenant database user - enter an alphanumeric username with no special characters)
       - Enter the password for the user – (enter an alphanumeric password each time when prompted)
   - Enter the tenant ontology name – Press Enter to accept 'default' (or enter a name to reference the ontology by if desired)
   - Enter the name of the IBM Business Automation Content Analyzer base database (enter the database name given when creating the base database)
   - Enter the name of the database user for the IBM Business Automation Content Analyzer base database (enter the base username given when creating the base database)  
The remaining values will be used to set up the initial user in IBM Business Automation Content Analyzer
   - Enter the company name (enter your company name)
   - Enter the first name (enter your first name)
   - Enter the last name (enter your last name)
   - Enter a valid email address (enter your email address)
   - Enter the login name (if using LDAP authentication, enter your username as it appears in the LDAP server)
   - Would you like to continue (y for yes)  
    
Save the TenantID and Ontology name for the later steps.

Back to prerequisite [Overview](../configuration/README.md)
