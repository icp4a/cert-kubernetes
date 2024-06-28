##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

function checkPGClientCommand(){
  echo "Checking Postgres commandline client (psql)..."
  
  # Check if psql command is available
  if command -v psql &> /dev/null; then
      psql_path=$(command -v psql)
      echo "psql is installed at: $psql_path"
  else
      echo "Error: psql is not installed. Please install PostgreSQL client."
      exit 1
  fi
}

function askForConfirmation(){
  while [[  $confirmation != "y" && $confirmation != "n" && $confirmation != "yes" && $confirmation != "no" ]] # While confirmation is not y or n...
  do
    echo
    echo -e "Would you like to continue (Y/N):"
    read confirmation
    confirmation=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')
  done

  if [[ $confirmation == "n" || $confirmation == "no" ]]
    then
      exit
  fi
}


function setupPostgresEnv() {
    # Check if we need to initialize the postgres env 
  if [[ -z "$db_env_script_skip" &&  -z "$db_env_script" ]]; then
    echo -e "\nOPTIONAL: If your commandline does not have Postgres client (psql) initialized, please provide the path to a script to initialize the env for psql."
    echo -e "(If you are running on caommandline thas has psql, then hit enter to skip.)"
    read db_env_script
    if [[ -z "$db_env_script" ]]; then
      db_env_script_skip=true
    else
      # initialize the Postgres env
      . $db_env_script
    fi
  fi
}


function getTableSpace() {
  # Check if we need to setup tablespace for db
  if [[ -z "$table_space_already_defined" ]]; then
    local db_on_existing_table_space
    while [[ "$db_on_existing_table_space" != "y" && "$db_on_existing_table_space" != "Y" && "$db_on_existing_table_space" != "n" && "$db_on_existing_table_space" != "N" ]]
    do
      echo "Do you want to create the database on an existing tablespace? (Y/N)"
      read db_on_existing_table_space
    done

    if [[ "$db_on_existing_table_space" == "n" || "$db_on_existing_table_space" == "N" ]]; then
      table_space_already_defined=0
    else
      table_space_already_defined=1
    fi
  fi
  if [[ $table_space_already_defined == 0 ]]; then
    while [[ -z "$tablespace_name" || ${#tablespace_name} -gt 64 ]]
    do
      echo "Please enter a valid name for new database tablespace of max length 64. "
      echo "The tablespace name cannot begin with pg_, as such names are reserved for system tablespaces.:"
      read tablespace_name
    done
    while [[ -z "$tablespace_location" ]]
    do
      echo "Please enter a valid location for new database tablespace. "
      echo "The directory must exist (CREATE TABLESPACE will not create it), should be empty, and must be owned by the PostgreSQL system user. "
      echo "The directory must be specified by an absolute path name. eg. '/data/dbs' :"
      read tablespace_location
    done
  else
    if [[ -z "$tablespace_name" ]]; then
      echo "Enter the tablespace name (hit enter to accept default of 'pg_default'): "
      read tablespace_name
      if [[ -z "$tablespace_name" ]]; then
        echo " - Using default value of 'pg_default' for the tablespace name."
        tablespace_name="pg_default"
      fi
    fi
  fi
}


function getDbAdminUser() {

  if [[ -z "$db_adm_username" ]]; then
      echo -e "\nEnter the name for an admin user for the Postgres server (hit enter to accept default of 'postgres' user): "
      read db_adm_username
      if [[ -z "$db_adm_username" ]]; then
        db_adm_username="postgres"
      fi
  fi

  DB_ADM_USER_STR="user=${db_adm_username}"

}


function getDbAdminPwd() {
  if [[ -z "$db_adm_pwd" ]]; then
    echo -e "\nIf you need to provide password for logging into psql, please provide the Postgres admin user password."
    echo -e "(If your psql does not require password authentication, hit enter to skip.)"
    echo -e "Please enter the Postgres admin password: "
    read -s db_adm_pwd
    if [[ -z "$db_adm_pwd" ]]; then
      db_adm_pwd_skip=true
    else
      # Prompt for the db_admin_pwd
      while [[ -z "$db_adm_pwd_set" ]] # While pwd is not yet received and confirmed (i.e. entered the same time twice)
      do
          echo "Please confirm the admin password by entering it again:"
          read -s db_adm_pwd2

          if [[ "$db_adm_pwd" != "$db_adm_pwd2" ]]; then
              echo "The passwords do not match.  Please try again."
              unset db_adm_pwd
              unset db_adm_pwd2

              echo "Please enter the admin password: "
              read -s db_adm_pwd
          else
              db_adm_pwd_set=true
          fi  
      done
    fi
  fi

  if [[ -z "$db_adm_pwd_skip" && $db_adm_pwd_b64_encoded -eq 1 ]]; then
    db_adm_pwd=$(echo $db_adm_pwd | base64 --decode)
  fi

  if [[ -z "$db_adm_pwd" ]]; then
    DB_ADM_PWD_STR=""
  else
    DB_ADM_PWD_STR="password=$db_adm_pwd"
  fi

}


function getBaseDBUser() {

  if [[ -z "$base_valid_user" ]]; then
     base_valid_user=0
  fi

  while [[ $base_valid_user -ne 1 ]]
  do
    echo -e "\nWe need a non-admin database user that Document Processing Engine will use to access your BASE database."

    if [[ -z "$base_user_already_defined" || $base_user_already_defined -ne 1 ]]; then
         while [[ "$create_new_base_user" != "y" && "$create_new_base_user" != "Y" && "$create_new_base_user" != "n" && "$create_new_base_user" != "N" ]]
         do
           echo "Do you want this script to create a new database user for you? (Please enter y or n)"
           read create_new_base_user
         done

         if [[ "$create_new_base_user" == "n" || "$create_new_base_user" == "N" ]]; then
           base_user_already_defined=1
           base_valid_user=1
         else
           base_user_already_defined=0
         fi
    fi

    while [[ -z "$base_db_user" ||  $base_db_user == "" ]]
    do
      if [[ $base_user_already_defined -ne 1 ]]; then
        echo "Please enter the name of database user to create: "
      else
        echo "Please enter the name of an existing database user with read and write privileges for this database:"
      fi           
      read base_db_user
      base_valid_user=1
    done

    if [ $base_db_user != "" ]; then
      base_valid_user=1
    else
      base_valid_user=0
    fi
  done

  if [[ -z "$base_db_user" ]]; then
     DB_BASE_USER_STR=""
  else
     DB_BASE_USER_STR="user=${base_db_user}"
  fi

}


function getBaseDBPwd() {
  
  while [[ $base_pwdconfirmed -ne 1 ]] # While pwd is not yet received and confirmed (i.e. entered the same time twice)
  do
      echo "Enter the password for the base database user: "
      read -s base_db_pwd
      while [[ $base_db_pwd == '' ]] # While pwd is empty...
      do
          echo "Enter a valid value"
          read -s base_db_pwd
      done

      echo "Please confirm the password for the base database user by entering it again:"
      read -s base_db_pwd2
      while [[ $base_db_pwd2 == '' ]]  # While pwd is empty...
      do
          echo "Enter a valid value"
          read -s base_db_pwd2
      done

      if [[ "$base_db_pwd" == "$base_db_pwd2" ]]; then
          base_pwdconfirmed=1
      else
          echo "The passwords do not match.  Please enter the password again."
          unset base_db_pwd
          unset base_db_pwd2
      fi  
  done

  if [[ $base_db_pwd_b64_encoded -eq 1 ]]; then
    base_db_pwd=$(echo $base_db_pwd | base64 --decode)
  fi
  
  # reset before next run
  base_pwdconfirmed=0

  if [[ -z "$base_db_pwd" ]]; then
     DB_BASE_PWD_STR=""
  else
     DB_BASE_PWD_STR="password=${base_db_pwd}"
  fi

}


function getDbHostPort() {

  if [[ -z "$db_server" ]]; then
    echo
    echo "Enter the hostname or IP address that this script should use to connect to Postgres: "
    read db_server
    if [[ -z "$db_server" ]]; then
       echo "WARNING: You did not give a value for the hostname of IP address of Postgres server."
       echo "If you are running this script locally on the Postgres server, then it is OK to leave this empty (hit enter to continue)."
       echo "Otherwise, please give the hostame or IP address of Postgres server now: "
       read db_server
    fi
  fi

  if [[ -z "$db_port" ]]; then
      echo
      echo "Enter the port number that this script should use to connect to Postgres (hit enter to accept default of '5432'): "
      read db_port
      if [[ -z "$db_port" ]]; then
        echo " - Using default value of 5432 for the Postgres port number."
        db_port=5432
      fi
  fi

  if [[ -z "$db_server" ]]; then
     DB_HOST_CMD_STR=""
  else
     DB_HOST_CMD_STR="host=${db_server} port=${db_port}"
  fi

}

function prompt_for_base_db_name() {
    while [ -z "$base_db_name" -o ${#base_db_name} -gt 64 ]; do
        echo "Please enter a valid value for the base database name :"
        read base_db_name
    done
}

function getDbHostPortCA() {

  # get db server host
  if [[ -z "$db_server_for_ca" ]]; then
    echo
    echo "Enter the hostname, IP address, or service name that DPE (Document Processing Engine) should use to connect to Postgres: "
    echo "  (Important: Depending on your environment, this may be the same or different from the host used by this script to connect to Postgres)"
    
    if [[ ! -z "$db_server" ]]; then
      echo "  (You can hit enter to use the same value given for the script to connect to Postgres host: ${db_server} )"
    fi 

    read db_server_for_ca

    # if no value given and db_server is defined, then default to db_server
    if [[ (-z "$db_server_for_ca") && (! -z "$db_server") ]]; then
       db_server_for_ca=$db_server
    fi 

    # just in case no value is given and there is no default to fall back on
    while [[ -z "$db_server_for_ca" ]]; do
       echo "ERROR: You did not give a value for the hostname or IP address of Postgres server."
       echo
       echo "Enter the hostname or IP address that DPE (Document Processing Engine) should use to connect to Postgres: "
       read db_server_for_ca
    done
  fi

  # get port
  if [[ -z "$db_port_for_ca" ]]; then
    echo
    echo "Enter the port number that DPE (Document Processing Engine) should use to connect to Postgres: "
    echo "  (Important: Depending on your environment, this may be the same or different from the port used by this script to connect to Postgres)"

    if [[ ! -z "$db_port" ]]; then
      echo "  (You can hit enter to use the same value given for the script to connect to Postgres port: ${db_port} )"
    fi 

    read db_port_for_ca

    # if no value given and db_port is defined, then default to db_port
    if [[ (-z "$db_port_for_ca") && (! -z "$db_port") ]]; then
       db_port_for_ca=$db_port
    fi 

    # just in case no value is given and there is no default to fall back on
    while [[ -z "$db_port_for_ca" ]]; do
       echo "ERROR: You did not give a value for the Postgres port number."
       echo
       echo "Enter the port that DPE (Document Processing Engine) should use to connect to Postgres: "
       read db_port_for_ca
    done
  fi
}


function getTenantID() {
  if [[ -z "$skip_insert_tenant" ||  $skip_insert_tenant != "true" ]]; then
    if [[ -z "$use_existing_tenant" || $use_existing_tenant -ne 1 ]]; then
      echo -e "\nEnter the tenant ID for the new tenant: (eg. t4900)"
    else
      echo -e "\nEnter the tenant ID for the existing tenant: (eg. t4900)"
    fi
    while [[ -z "$tenant_id" || $tenant_id == '' ]]
    do
      echo "Please enter a valid value for the tenant ID:"
      read tenant_id
    done
  fi
}


function getTenantType() {
  if [[ -z "$use_existing_tenant" || $use_existing_tenant -ne 1 ]]; then
    while [[ $tenant_type == '' || $tenant_type != "0" && $tenant_type != "1" && $tenant_type != "2"  ]] # While tenant_type is not valid/set
    do
        echo -e "\n\x1B[1;31mEnter the tenant type\x1B[0m"
        echo -e "\x1B[1;31mChoose the number equivalent.\x1B[0m"
        echo -e "\x1B[1;34m0. Enterprise\x1B[0m"
        echo -e "\x1B[1;34m1. Trial\x1B[0m"
        echo -e "\x1B[1;34m2. Internal\x1B[0m"
        read tenant_type
    done

    if [ $tenant_type == 0 ]; then
        daily_limit=0
    elif [ $tenant_type == 1 ]; then
        daily_limit=100
    elif [ $tenant_type == 2 ]; then
        daily_limit=2000
    fi
  fi
}


function getTenantDBName() {
  echo
  if [[ -z "$tenant_db_exists" || $tenant_db_exists != "true" ]]; then
    echo "Enter the name of the new Document Processing Engine Project database to create: "
  else
    echo "Enter the name of an existing database for the Document Processing Engine Project database: "
  fi
  while [[ $tenant_db_name == '' ]]
  do
    echo "Please enter a valid value for the Project database name of max length 64 :"
    read tenant_db_name
    while [ ${#tenant_db_name} -gt 64 ];
    do
      echo "Please enter a valid value for the Project database name of max length 64 :"
      read tenant_db_name;
      echo ${#tenant_db_name};
    done
  done

  DB_TENANT_DBNAME_STR="dbname=${tenant_db_name}"  
}


function getTenantDBUser() {

  if [[ $use_existing_tenant -eq 1 ]]; then
    user_already_defined=1
  fi

  echo
  echo "We need a non-admin database user that Document Processing Engine will use to access your Document Processing Engine Project database."
  while [[ -z "$tenant_db_user" ||  $tenant_db_user == "" ]]
  do
    echo
    if [[ -z "$user_already_defined" || $user_already_defined -ne 1 ]]; then
         while [[ "$create_new_user" != "y" && "$create_new_user" != "Y" && "$create_new_user" != "n" && "$create_new_user" != "N" ]]
         do
           echo "Do you want this script to create a new database user for you? (Please enter y or n)"
           read create_new_user
         done

         if [[ "$create_new_user" == "n" || "$create_new_user" == "N" ]]; then
           user_already_defined=1
         else
           user_already_defined=0
         fi
    fi

    while [[ -z "$tenant_db_user" ||  $tenant_db_user == "" ]]
    do
      if [[ "$create_new_user" == "y" || "$create_new_user" = "Y" ]]; then
        echo "Please enter the name of database user to create: "
      else
        echo "Please enter the name of an existing database user with read and write privileges for the Document Processing Engine Project database: "
      fi
      read tenant_db_user
    done

    # Check if user already exists
    if [[ $user_already_defined -ne 1 ]]; then
        psql "${DB_ADM_USER_STR} ${DB_ADM_PWD_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$tenant_db_user'" | grep 1

        if [[ $? -eq 0 ]]; then
            while [[ "$use_existing_user" != "y" && "$use_existing_user" != "Y" && "$use_existing_user" != "n" && "$use_existing_user" != "N" ]]
            do
               echo "$tenant_db_user already exists.  Do you want to use this user (Please enter y or n)"
               read use_existing_user
               if [ "$use_existing_user" = "y" ] || [ "$use_existing_user" = "Y" ]; then
                  user_already_defined=1
               else
                  unset tenant_db_user
                  unset user_already_defined
                  unset create_new_user
               fi
            done
        fi
    fi
  done

  DB_TENANT_USER_STR="user=${tenant_db_user}"
}



function getTenantDBPwd() {

  while [[ $tenant_pwdconfirmed -ne 1 ]] # While pwd is not yet received and confirmed (i.e. entered teh same time twice)
  do
      while [[ $tenant_db_pwd == '' ]] # While pwd is empty...
      do
          echo "Enter the password for the user: "
          read -s tenant_db_pwd
      done

      while [[ $tenant_db_pwd2 == '' ]]  # While pwd is empty...
      do
          echo "Please confirm the password by entering it again:"
          read -s tenant_db_pwd2
      done

      if [[ "$tenant_db_pwd" == "$tenant_db_pwd2" ]]; then
          tenant_pwdconfirmed=1
      else
          echo "The passwords do not match.  Please enter the password again."
          unset tenant_db_pwd
          unset tenant_db_pwd2
      fi
  done

  # reset to 0 in case next script checks this variable
  tenant_pwdconfirmed=0

  if [[ $tenant_db_pwd_b64_encoded -eq 1 ]]; then
    tenant_db_pwd=$(echo $tenant_db_pwd | base64 --decode)
  fi
  
  if [[ -z "$tenant_db_pwd" ]]; then
     DB_TENANT_PWD_STR=""
  else
     DB_TENANT_PWD_STR="password=${tenant_db_pwd}"
  fi
}

function setSSLEnabled() {
    if [[ "$ssl" == "Yes" || "$ssl" == "yes" || "$ssl" == "YES" || "$ssl" == "y" || "$ssl" == "Y" ]]; then
      ssl_enabled=true
    elif [[ "$ssl" == "No" || "$ssl" == "no" || "$ssl" == "NO" || "$ssl" == "n" || "$ssl" == "N" ]]; then
      ssl_enabled=false
    else
      unset ssl_enabled
    fi
}


function promptForSSLenabled() {
  default_ssl='No'
  #
  # SSL
  while [[ -z "$ssl" ]]
  do
    echo -e "\nDoes your Postgres server have SSL enabled?  (Please note that additional setup steps are required in order to use SSL with Postgres.)"
    echo -e "Please enter 'Yes' or 'No'. If nothing is entered we will use the default value of '$default_ssl'"
    read ssl
    if [[ -z "$ssl" ]]; then
      ssl=$default_ssl
    fi
    
    setSSLEnabled
    
    if [[ -z "$ssl_enabled" ]]; then
      echo -e "\nInvalid response provided for whether or not SSL is enabled for Postgres. Please answer 'Yes' or 'No'."
      unset ssl
    fi 
  done

  # Set ssl_enabled in the case when we are doing silent install using common_for_PG.sh
  if [[ -z "$ssl_enabled" ]]; then
    setSSLEnabled
  fi

}


function promptForSSLcerts() {
    echo
    echo "We will now collect information about SSL certificates (if needed) for connecting to your Postgres server"
    while [[ -z "$client_cert_path" ||  $client_cert_path == "" ]]
    do
       if [[ $client_cert_path == "skip" ]]; then         
         break  # skip asking if "skip" is specified
       fi

       echo -e "\nPlease provide a FULL path (not a relative path) to the SSL client certificate (Please hit enter if no client certificate is needed)"
       read client_cert_path

       if [[ -z "$client_cert_path" ]]; then
          echo -e " - Skipping client certificate path since you didn't provide one."
          break
       else
          if [[ ! -f "$client_cert_path" ]]; then
            echo -e "\nNo file is found at '${client_cert_path}'.  Please give a valid path or hit enter to skip providing client cert."
            unset client_cert_path
          fi
       fi
    done

    while [[ -z "$client_key_path" ||  $client_key_path == "" ]]
    do
       if [[ $client_key_path == "skip" ]]; then         
         break  # skip asking if "skip" is specified
       fi
       
       echo -e "\nPlease provide a FULL path (not a relative path) to the SSL client private key (Please hit enter if no private key is needed)"
       read client_key_path

       if [[ -z "$client_key_path" ]]; then
          echo -e " - Skipping client private key path since you didn't provide one."
          break
       else
          if [[ ! -f "$client_key_path" ]]; then
            echo -e "\nNo file is found at '${client_key_path}'.  Please give a valid path or hit enter to skip providing client private key."
            unset client_key_path
          fi
       fi
    done

    while [[ -z "$root_cert_path" ||  $root_cert_path == "" ]]
    do
       if [[ $root_cert_path == "skip" ]]; then         
         break  # skip asking if "skip" is specified
       fi
       
       echo -e "\nPlease provide a FULL path (not a relative path) to the SSL root cert (Please hit enter if no root certificate is needed)"
       read root_cert_path

       if [[ -z "$root_cert_path" ]]; then
          echo -e " - Skipping root cert path since you didn't provide one."
          break
       else
          if [[ ! -f "$root_cert_path" ]]; then
            echo -e "\nNo file is found at '${root_cert_path}'.  Please give a valid path or hit enter to skip providing root cert path."
            unset root_cert_path
          fi
       fi
    done

    while [[ -z "$client_ssl_mode" ||  $client_ssl_mode == "" ]]
    do
       if [[ $client_ssl_mode == "skip" ]]; then         
         break  # skip asking if "skip" is specified
       fi

       echo -e "\nOptionally, provide the value for Postgres client 'sslmode' (Please hit enter if you don't need to set 'sslmode')"
       echo -e " - Please only give a value if you know what 'sslmode' setting is for."
       echo -e " - See https://www.postgresql.org/docs/current/libpq-ssl.html#LIBPQ-SSL-SSLMODE-STATEMENTS"
       read client_ssl_mode

       if [[ -z "$client_ssl_mode" ]]; then
          echo -e " - Skipping ssl_mode argument since you didn't provide one."
          break         
       fi
    done

    ## Construct the string arguments for SSL
    DB_SSL_STR=""

    if [[ ! -z "$client_cert_path" &&  "$client_cert_path" != "" &&  "$client_cert_path" != "skip" ]]; then
       DB_SSL_STR="sslcert=${client_cert_path}"
    fi

    if [[ ! -z "$client_key_path" &&  "$client_key_path" != "" &&  "$client_key_path" != "skip" ]]; then
       DB_SSL_STR="${DB_SSL_STR} sslkey=${client_key_path}"
    fi

    if [[ ! -z "$root_cert_path" &&  "$root_cert_path" != "" &&  "$root_cert_path" != "skip" ]]; then
       DB_SSL_STR="${DB_SSL_STR} sslrootcert=${root_cert_path}"
    fi

    if [[ ! -z "$client_ssl_mode" &&  "$client_ssl_mode" != "" &&  "$client_ssl_mode" != "skip" ]]; then
       DB_SSL_STR="${DB_SSL_STR} sslmode=${client_ssl_mode}"
    fi

    if [[ ! -z "$DB_SSL_STR" &&  "$DB_SSL_STR" != "" ]]; then
      if [[ ! -z $DEV_MODE && $DEV_MODE == "true" ]]; then
         echo -e "\n - SSL params: ${DB_SSL_STR}"
      fi
    fi
}


function outputSSLsettings() {
    echo " - SSL enabled: $ssl_enabled"
    if [[ ! -z "$client_cert_path" &&  "$client_cert_path" != "" &&  "$client_cert_path" != "skip" ]]; then
      echo " - SSL client cert: $client_cert_path"
    fi
    if [[ ! -z "$client_key_path" &&  "$client_key_path" != "" &&  "$client_key_path" != "skip" ]]; then
       echo " - SSL client private key: $client_key_path"
    fi
    if [[ ! -z "$root_cert_path" &&  "$root_cert_path" != "" &&  "$root_cert_path" != "skip" ]]; then
       echo " - SSL root cert: $root_cert_path"
    fi
    if [[ ! -z "$client_ssl_mode" &&  "$client_ssl_mode" != "" &&  "$client_ssl_mode" != "skip" ]]; then
       echo " - sslmode: $client_ssl_mode"
    fi    
}

function get_release_schema_version() {
    # Get the script release base version

    # If the user sets DB_SCHEMA_VERSION environment variable, return it directly. This is for dev and QA use only.
    set -e
    local release_schema_version=${DB_SCHEMA_VERSION}
    local sp_version_file
    if [ -z "$release_schema_version" ]; then
        # Try sp-version.json. This is the regular use case.
        sp_version_file="./sp-version.json"
        if [ ! -f "${sp_version_file}" ]; then
            # sp-version.json doesn't exist. Try release.env. This only works in dev environment.
            sp_version_file="../../release.env"
            if [ ! -f "${sp_version_file}" ]; then
                echo "ERROR: sp-version.json is missing" >&2
                return 1
            fi
        fi
        # Extract the value of DB_SCHEMA_VERSION from the file. Note that the input file could be a json file or an env file.
        release_schema_version=$(sed -n -r 's/^ *"?DB_SCHEMA_VERSION"?[=:] *"?([0-9.]+)"?/\1/p' $sp_version_file)
    fi
    if [ -z "${release_schema_version}" ]; then
        echo "ERROR: cannot read DB_SCHEMA_VERSION from ${sp_version_file}" >&2
        return 1
    fi
    echo ${release_schema_version}
}

function get_base_db_version() {
    # Get the base DB scheam version
    # Usage:
    #   get_base_db_version <$base_db_name> <$base_db_schema>
    # Arguments:
    #   base_db_name - the base DB name
    #   base_db_schema - the base DB schema. It should be the same as the db user
    # Returns:
    #   The schema version of the base DB.

    set -e
    local base_db_name=${1#dbname=}
    local base_db_schema=${2#user=}
    local schema_version
    local query_result
    local base_options_table_exists
    local DB_NAME_STR="dbname=${base_db_name}"

    # Make sure the schema is correct
    query_result=$( \
        psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -t -c \
        "SELECT 1 FROM pg_tables WHERE UPPER(schemaname)='${base_db_schema^^}' AND UPPER(tablename)='TENANTINFO'" \
    )
    if [ -z "$query_result" ]; then
        echo "ERROR: cannot find base DB tables in database '${base_db_name}' schema '${base_db_schema}'." >&2
        return 1
    fi

    # Try to get the base DB SCHEMA_VERSION from BASE_OPTIONS table. The table is available since in 23.0.2.
    base_options_table_exists=$( \
        psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -t -c \
        "SELECT 1 FROM pg_tables WHERE UPPER(schemaname)='${base_db_schema^^}' AND UPPER(tablename)='BASE_OPTIONS'" \
    )
    if [ -n "${base_options_table_exists}" ]; then
        # BASE_OPTIONS is available. Query the version from there
        schema_version=$( \
            psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -t -c \
            "SELECT SCHEMA_VERSION FROM BASE_OPTIONS" \
        )
    fi

    if [ -z "$schema_version" ]; then
        # There's no BASE_OPTIONS table. We have to guess...
        # The BASE_OPTIONS table was added on 23.0.2, thus it must be 23.0.1 - the first release we have official PG support.
        schema_version="23.0.1"
    fi
    echo $schema_version
}

function get_tenant_db_version() {
    # Get the tenant (project) DB scheam version
    # Usage:
    #   get_tenant_db_version <$base_db_name> <$base_db_schema> <$tenant_db_name> <$tenant_db_schema>
    # Arguments:
    #   base_db_name - the base DB name
    #   base_db_schema - the base DB schema. It should be the same as the db user
    #   tenant_db_name - the tenant DB name matching the DBNAME colum in TenantInfo table. Note that it may be different from the TenantID
    #   tenant_db_schema - the tenant DB schema (i.e., ontology in the TenantInfo table)
    # Returns:
    #   The schema version of the tenant (project) DB.

    set -e
    local base_db_name=${1#dbname=}
    local base_db_schema=${2#user=}
    local tenant_db_name=${3#dbname=}
    local tenant_db_schema=$4
    local DB_NAME_STR="dbname=${base_db_name}"
    local schema_version

    schema_version=$( \
        psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -t -c \
        "SELECT TENANTDBVERSION FROM TENANTINFO WHERE UPPER(DBNAME)='${tenant_db_name^^}' AND UPPER(ONTOLOGY)='${tenant_db_schema^^}'" \
    )

    if [ -z "${schema_version}" ]; then
        echo "ERROR: cannot find the record of tenant DB '${tenant_db_name}' ontology '${tenant_db_schema}' in base DB." >&2
        return 1
    fi

    echo $schema_version
}

function set_base_db_version() {
    # Sets the base DB scheam version
    # Usage:
    #   set_base_db_version <$base_db_name> <$base_db_schema> [$schema_version]
    # Arguments:
    #   base_db_name - the base DB name
    #   base_db_schema - the base DB schema. It should be the same as the db user
    #   schema_version (optional) - the schema version to set. If not provided, the version from get_release_schema_version will be used.

    set -e
    local base_db_name=${1#dbname=}
    local base_db_schema=${2#user=}
    local schema_version=$3
    local DB_NAME_STR="dbname=${base_db_name}"

    if [ -z "$schema_version" ]; then
        schema_version=$(get_release_schema_version)
    fi

    psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -t -c \
    "UPDATE base_options SET schema_version='${schema_version}'"
}

function set_tenant_db_version() {
    # Sets the tenant (project) DB scheam version
    # Usage:
    #   set_tenant_db_version <$base_db_name> <$base_db_schema> <$tenant_db_name> <$tenant_db_schema> [$schema_version]
    # Arguments:
    #   base_db_name - the base DB name
    #   base_db_schema - the base DB schema. It should be the same as the db user
    #   tenant_db_name - the tenant DB name matching the DBNAME colum in TenantInfo table. Note that it may be different from the TenantID
    #   tenant_db_schema - the tenant DB schema (i.e., ontology in the TenantInfo table)
    #   schema_version (optional) - the schema version to set for this tenant (project). If not provided, the version from get_release_schema_version will be used.

    set -e
    local base_db_name=${1#dbname=}
    local base_db_schema=${2#user=}
    local tenant_db_name=${3#dbname=}
    local tenant_db_schema=$4
    local schema_version=$5
    local DB_NAME_STR="dbname=${base_db_name}"

    if [ -z "$schema_version" ]; then
        schema_version=$(get_release_schema_version)
    fi

    psql "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} ${DB_NAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}" --set ON_ERROR_STOP=on -t -c \
    "UPDATE TENANTINFO SET TENANTDBVERSION='${schema_version}', BACAVERSION='${schema_version}' WHERE UPPER(DBNAME)='${tenant_db_name^^}' AND UPPER(ONTOLOGY)='${tenant_db_schema^^}'"
    
}

function get_upgrade_templates() {
    # List the SQL template to run
    # Usage:
    #   get_upgrade_templates <$prefix> <$from_version> <$to_version>
    # Arguments:
    #   prefix - the template prefix. It must be UpgradeBaseDB or UpgradeTenantDB
    #   from_version - the from portion of the template filename
    #   to_version - the to portion of the template filename
    # Returns:
    #   a sorted list of SQL templates to run

    set -e
    local prefix=$1
    local from_version=$2
    local to_version=$3
    local template_files=$(find ./sql/ -name "${prefix}_*.sql.template" | sort -n)
    local this_from
    local this_to
    local matched=false
    for template_file in $template_files; do
        if ! $matched; then
            this_from=$(echo $template_file | sed -r "s/.*${prefix}_([0-9.]+)_to_([0-9.]+)\.sql\.template/\1/")
            if [ "$this_from" == "$from_version" ]; then
                matched=true
            fi
        fi
        if $matched; then
            echo $template_file
            this_to=$(echo $template_file | sed -r "s/.*${prefix}_([0-9.]+)_to_([0-9.]+)\.sql\.template/\2/")
            if [ "$this_to" == "$to_version" ]; then
                break
            fi
        fi
    done
}

function get_base_db_conn() {
    if [ -z "${base_db_name}" ]; then
        echo "ERROR: base_db_name is empty." >&2
        return 1
    fi
    if [ -z "${DB_BASE_USER_STR}" ]; then
        echo "ERROR: DB_BASE_USER_STR is empty." >&2
        return 1
    fi
    echo "${DB_BASE_USER_STR} ${DB_BASE_PWD_STR} dbname=${base_db_name} ${DB_HOST_CMD_STR} ${DB_SSL_STR}"
}

function get_tenant_db_conn() {
    if [ -z "${DB_TENANT_DBNAME_STR}" ]; then
        echo "ERROR: DB_TENANT_DBNAME_STR is empty." >&2
        return 1
    fi
    if [ -z "${DB_TENANT_USER_STR}" ]; then
        echo "ERROR: DB_TENANT_USER_STR is empty." >&2
        return 1
    fi
    echo "${DB_TENANT_USER_STR} ${DB_TENANT_PWD_STR} ${DB_TENANT_DBNAME_STR} ${DB_HOST_CMD_STR} ${DB_SSL_STR}"
}

function run_base_db_upgrade_templates() {
    # Run the base DB sql templates. This function will connect to the database
    # Usage:
    #   run_base_db_upgrade_templates <$base_db_name> <$base_db_schema> <$template_files>
    # Arguments:
    #   base_db_name - the base database name
    #   base_db_schema - the base schema
    #   template_files - a list of template files to run

    set -e
    local base_db_name=${1}
    local base_db_schema=${2#user=}
    local template_files=$3

    local base_db_conn=$(get_base_db_conn)

    local rc
    local template_file
    local this_version
    local last_version

    for template_file in $template_files; do
        # Track the versions
        if [ -z "$last_version" ]; then
            last_version=$(echo $template_file | sed -r "s/.+_([0-9.]+)_to_([0-9.]+)\.sql\.template/\1/")
        fi
        this_version=$(echo $template_file | sed -r "s/.+_([0-9.]+)_to_([0-9.]+)\.sql\.template/\2/")

        # Run the upgrade sql file
        echo ""
        echo "Running upgrade script: ${template_file}"
        set +e
        psql "${base_db_conn} options=--search_path=${base_db_schema}" --set ON_ERROR_STOP=on -f "${template_file}"
        rc=$?
        set -e

        # Error handling
        if [ $rc -ne 0 ]; then
            echo ""
            echo "ERROR  : script ${template_file} failed with rc=${rc}."
            echo "CAUSE  : likely due to unexpected issues in base DB '$base_db_name' schame '$base_db_schema'."
            echo "STATUS : the base DB remains at version ${last_version}."
            echo "Recommendation: review the output above and fix any issues in the database, then re-run the upgrade."
            return $rc
        fi

        # Commit the version upgrade in base DB if base_options table exists
        set_base_db_version $base_db_name $base_db_schema $this_version
        last_version=$this_version
    done
}

function run_tenant_db_upgrade_templates() {
    # Run the base DB sql templates. This function will connect to the database
    # Usage:
    #   run_base_db_upgrade_templates <$base_db_name> <$base_db_schema> <$tenant_db_name> <$tenant_db_schema> <$template_files>
    # Arguments:
    #   base_db_name - the base database name
    #   base_db_schema - the base schema
    #   tenant_db_name - the tenant database name
    #   tenant_db_schema - the tenant schema
    #   template_files - a list of template files to run

    set -e
    local base_db_name=${1}
    local base_db_schema=${2#user=}
    local tenant_db_name=${3}
    local tenant_db_schema=${4#user=}
    local template_files=$5

    local tenant_db_conn=$(get_tenant_db_conn)

    local rc
    local template_file
    local this_version
    local last_version

    for template_file in $template_files; do
        # Track the versions
        if [ -z "$last_version" ]; then
            last_version=$(echo $template_file | sed -r "s/.+_([0-9.]+)_to_([0-9.]+)\.sql\.template/\1/")
        fi
        this_version=$(echo $template_file | sed -r "s/.+_([0-9.]+)_to_([0-9.]+)\.sql\.template/\2/")

        # Run the upgrade sql file
        echo ""
        echo "Running upgrade script: ${template_file}"
        set +e
        psql "${tenant_db_conn} options=--search_path=${tenant_db_schema}" --set ON_ERROR_STOP=on -f "${template_file}"
        rc=$?
        set -e

        # Error handling
        if [ $rc -ne 0 ]; then
            echo ""
            echo "ERROR  : script ${template_file} failed with rc=${rc}."
            echo "CAUSE  : likely due to unexpected issues in base DB '$tenant_db_name' schame '$tenant_db_schema'."
            echo "STATUS : the tenant DB remains at version ${last_version}."
            echo "Recommendation: review the output above and fix any issues in the database, then re-run the upgrade."
            return $rc
        fi

        # Commit the version upgrade in base DB if base_options table exists
        set_tenant_db_version $base_db_name $base_db_schema $tenant_db_name $tenant_db_schema $this_version
        last_version=$this_version
    done
}
