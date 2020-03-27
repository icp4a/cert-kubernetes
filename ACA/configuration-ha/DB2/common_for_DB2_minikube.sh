# Sample script for running the DB2 scripts non-interactively by providing the needed env vars
# To use:  Make a copy and name it "common_for_DB2.sh", update the needed variables.


# --- For Base BACA DB:
# update these variables for the BACA Base database
base_db_name=CABASE
base_db_user=db2inst1


# To skip creating base databse user and skip asking for pwd, use these vars below.  
# Prereq is that the DB2 user (from var "base_db_user") must already be created.
base_valid_user=1
base_user_already_defined=1
base_pwdconfirmed=1

# --- For adding tenant:
# update these variables
tenant_type=1   # Allowed values: 0 for Enterprise, 1 for Trial, 2 for Internal
baca_database_server_ip=baca-db2-ibm-db2oltp-dev-db2
baca_database_port=50000
tenant_id=demo
tenant_db_name=demo
tenant_db_user=db2inst1

# To skip creating tenant database user and skip asking for pwd, use these vars below.  
# Prereq is that the DB2 user (from var "tenant_db_user") must already be created.
user_already_defined=1
pwdconfirmed=1

# update these variables
tenant_db_pwd=YmFjYTEyMwo= #baca123
tenant_db_pwd_b64_encoded=1  # set to 1 if "tenant_db_pwd" is base64 encoded
tenant_ontology=demo

tenant_company=IBM
tenant_first_name=John
tenant_last_name=Smith
tenant_email=johnsmith@ibm.com
tenant_user_name=bacauser

# --- For adding ontology to existing tenant
# uncomment this below to add ontology, and comment out "tenant_ontology" line above in this file
#use_existing_tenant=1
#tenant_ontology=ONT2

# skip confirmation prompts:
confirmation=y

#DB2 ssl Yes/No
ssl=No