#!/BIN/BASH

###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2022. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################

# function for creating the template for ldap bind secret

function create_ldap_secret_template(){
  wait_msg "Creating ldap-bind-secret secret YAML template"
  mkdir -p $SECRET_FILE_FOLDER >/dev/null 2>&1

cat << EOF > ${LDAP_SECRET_FILE}
# YAML template for ldap-bind-secret secret
---
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: ldap-bind-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    name: ldap-bind-secret
stringData:
  ldapUsername: "<LDAP_BIND_DN>"
  ldapPassword: "<LDAP_PASSWORD>"
EOF

  success "Created ldap-bind-secret secret YAML template\n"
}

# function for creating the template for external ldap bind secret

function create_ext_ldap_secret_template(){
  wait_msg "Creating ext-ldap-bind-secret secret YAML template"
  mkdir -p $SECRET_FILE_FOLDER >/dev/null 2>&1

cat << EOF > ${EXT_LDAP_SECRET_FILE}
# YAML template for ext-ldap-bind-secret secret
---
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: ext-ldap-bind-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    name: ext-ldap-bind-secret
stringData:
  ldapUsername: "<LDAP_BIND_DN>"
  ldapPassword: "<LDAP_PASSWORD>"
EOF

  success "Created ext-ldap-bind-secret secret YAML template\n"
}

# This function cover LDAP SSL
function create_cp4a_ldap_ssl_secret_template(){
  wait_msg "Creating ldap ssl cert secret YAML template"
  mkdir -p $LDAP_SSL_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${CP4A_LDAP_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4a-ldap-ssl-cert-secret.sh 
if [[ -f "<cp4a-ldap-crt-file-in-local>/ldap-cert.crt" ]]; then
  kubectl delete secret generic "<cp4a-ldap_ssl_secret_name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<cp4a-ldap_ssl_secret_name>" --from-file=tls.crt="<cp4a-ldap-crt-file-in-local>/ldap-cert.crt" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"ldap-cert.crt\" into \"<cp4a-ldap-crt-file-in-local>\" first."
  exit 1
fi
EOF

  success "Created ldap ssl cert secret YAML template\n"
  chmod 755 ${CP4A_LDAP_SSL_SECRET_FILE}
}

# This function cover External LDAP SSL
function create_cp4a_ext_ldap_ssl_secret_template(){
  wait_msg "Creating external ldap ssl cert secret YAML template"
  mkdir -p $LDAP_SSL_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${CP4A_EXT_LDAP_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4ba-external-ldap-ssl-cert-secret.sh
if [[ -f "<cp4a-ldap-crt-file-in-local>/external-ldap-cert.crt" ]]; then
  kubectl delete secret generic "<cp4a-ldap_ssl_secret_name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<cp4a-ldap_ssl_secret_name>" --from-file=tls.crt="<cp4a-ldap-crt-file-in-local>/external-ldap-cert.crt" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"external-ldap-cert.crt\" into \"<cp4a-ldap-crt-file-in-local>\" first."
  exit 1
fi
EOF
  success "Created external ldap ssl cert secret YAML template\n"
  chmod 755 ${CP4A_EXT_LDAP_SSL_SECRET_FILE}
}

# This function cover AE Redis SSL
function create_cp4a_ae_redis_ssl_secret_template(){
  wait_msg "Creating Redis SSL cert secret YAML template for Application Engine"
  mkdir -p $REDIS_SSL_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${CP4A_AE_REDIS_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4a-redis-ssl-cert-secret.sh 
if [[ -f "<cp4a-redis-crt-file-in-local>/redis.pem" ]]; then
  kubectl delete secret generic "<cp4a-redis_ssl_secret_name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<cp4a-redis_ssl_secret_name>" --from-file=tls.crt="<cp4a-redis-crt-file-in-local>/redis.pem" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"redis.pem\" into \"<cp4a-redis-crt-file-in-local>\" first."
  exit 1
fi
EOF

  success "Created Redis SSL cert secret YAML template for Application Engine\n"
  chmod 755 ${CP4A_AE_REDIS_SSL_SECRET_FILE}
}

# This function cover Playback Redis SSL
function create_cp4a_playback_redis_ssl_secret_template(){
  wait_msg "Creating Redis SSL cert secret YAML template for Playback server"
  mkdir -p $REDIS_SSL_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${CP4A_PLAYBACK_REDIS_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4a-redis-ssl-cert-secret.sh 
if [[ -f "<cp4a-redis-crt-file-in-local>/redis.pem" ]]; then
  kubectl delete secret generic "<cp4a-redis_ssl_secret_name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<cp4a-redis_ssl_secret_name>" --from-file=tls.crt="<cp4a-redis-crt-file-in-local>/redis.pem" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"redis.pem\" into \"<cp4a-redis-crt-file-in-local>\" first."
  exit 1
fi
EOF

  success "Created Redis SSL cert secret YAML template for Playback server\n"
  chmod 755 ${CP4A_PLAYBACK_REDIS_SSL_SECRET_FILE}
}

# function for creating the template for CP4BA FNCM capabilities secret  

function create_fncm_secret_template(){
  local gcddbserver=$1
  gcddbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$gcddbserver")
  
  mkdir -p $FNCM_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${FNCM_SECRET_FILE}
# YAML template for ibm-fncm-secret secret
---
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: ibm-fncm-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    gcd-db-server: $gcddbserver
    db-name: ibm-fncm-secret
stringData:
  appLoginUsername: "<APPLOGIN_USER>"
  appLoginPassword: "<APPLOGIN_PASSWORD>"
  gcdDBUsername: "<GCD_DB_USER_NAME>"
  gcdDBPassword: "<GCD_DB_USER_PASSWORD>"
  osDBUsername: "<OS_DB_USER_NAME>"
  osDBPassword: "<OS_DB_USER_PASSWORD>"
  ltpaPassword: "<LTPA_PASSWORD>"
  keystorePassword: "<KEYSTORE_PASSWORD>"
EOF
}

# This function cover DB SSL
function create_cp4a_db_ssl_template(){
  local dbserver=$1
  wait_msg "Creating database ssl secret YAML template"
  mkdir -p $DB_SSL_SECRET_FOLDER/$dbserver >/dev/null 2>&1
  CP4A_DB_SSL_SECRET_FILE=${DB_SSL_SECRET_FOLDER}/$dbserver/ibm-cp4ba-db-ssl-cert-secret-for-${dbserver}.sh
  tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $dbserver.POSTGRESQL_SSL_CLIENT_SERVER)")
  tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
if [[ $DB_TYPE != "postgresql" ]]; then
cat << EOF > ${CP4A_DB_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4a-db-ssl-cert-secret

if [[ -f "<cp4a-db-crt-file-in-local>/db-cert.crt" ]]; then
  kubectl delete secret generic "<cp4a-db-ssl-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<cp4a-db-ssl-secret-name>" --from-file=tls.crt="<cp4a-db-crt-file-in-local>/db-cert.crt" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"db-cert.crt\" into \"<cp4a-db-crt-file-in-local>\" first."
  exit 1
fi
EOF
elif [[ $DB_TYPE == "postgresql" && ($tmp_flag == "no" || $tmp_flag == "false" || $tmp_flag == "" || -z $tmp_flag) ]]; then
cat << \EOF > ${CP4A_DB_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4a-db-ssl-cert-secret

if [[ -f "<cp4a-db-crt-file-in-local>/db-cert.crt" ]]; then
  kubectl delete secret generic "<cp4a-db-ssl-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<cp4a-db-ssl-secret-name>" \
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/db-cert.crt" \
  --from-file=serverca.pem="<cp4a-db-crt-file-in-local>/db-cert.crt" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"db-cert.crt\" into \"<cp4a-db-crt-file-in-local>\" first."
  exit 1
fi
EOF
else
cat << \EOF > ${CP4A_DB_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4a-db-ssl-cert-secret
value_empty=`cat "$0" | grep "sslmode=\[require|verify-ca|verify-full\]" | wc -l`  >/dev/null 2>&1
if [ $value_empty -ne 0 ] ; then
  echo -e "\x1B[1;31mPlease change line 25# in above script, modify \"--from-literal=sslmode\" to use [require or verify-ca or verify-full].\x1B[0m\n"
  
  echo -e "######################### Example ###################################"
  echo -e "# If DATABASE_SSL_ENABLE=\"True\" and POSTGRESQL_SSL_CLIENT_SERVER=\"False\""
  echo -e "# set '--from-literal=sslmode=require'"
  echo -e "# If DATABASE_SSL_ENABLE=\"True\" and POSTGRESQL_SSL_CLIENT_SERVER=\"True\""
  echo -e "# set '--from-literal=sslmode=verify-ca'"
  echo -e "# or"
  echo -e "# set '--from-literal=sslmode=verify-full'"
  echo -e "######################### Example ###################################"
    
  exit 1
fi

if [[ -f "<cp4a-db-crt-file-in-local>/root.crt" && -f "<cp4a-db-crt-file-in-local>/client.crt" && -f "<cp4a-db-crt-file-in-local>/client.key" ]]; then
  kubectl delete secret generic "<cp4a-db-ssl-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<cp4a-db-ssl-secret-name>" \
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/client.crt" \
  --from-file=ca.crt="<cp4a-db-crt-file-in-local>/root.crt" \
  --from-file=tls.key="<cp4a-db-crt-file-in-local>/client.key" \
  --from-literal=sslmode=[require|verify-ca|verify-full] -n "$CP4BA_SERVICES_NS"
  # If DATABASE_SSL_ENABLE="True" and POSTGRESQL_SSL_CLIENT_SERVER="False"
  # set '--from-literal=sslmode=require'
  # If DATABASE_SSL_ENABLE="True" and POSTGRESQL_SSL_CLIENT_SERVER="True"
  # set '--from-literal=sslmode=verify-ca'
  # or
  # set '--from-literal=sslmode=verify-full'
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"root.crt\" \"client.crt\" \"client.key\" into \"<cp4a-db-crt-file-in-local>\" first."
  exit 1
fi
EOF
fi

  success "Created database ssl secret YAML template\n"
  chmod 755 ${CP4A_DB_SSL_SECRET_FILE}
}

function create_fncm_icc_secret_template(){
  mkdir -p $FNCM_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${FNCM_ICC_SECRET_FILE}
# YAML template for ibm-icc-secret secret
---
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: ibm-icc-secret
  namespace: "$CP4BA_SERVICES_NS"
stringData:
  archiveUserId: "<ARCHIVE_USERID>"
  archivePassword: "<ARCHIVE_PASSWORD>"
EOF
}

function create_fncm_iccsap_secret_template(){
  mkdir -p $FNCM_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${FNCM_ICCSAP_SECRET_FILE}
# YAML template for ibm-iccsap-secret secret
---
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: ibm-iccsap-secret
  namespace: "$CP4BA_SERVICES_NS"
stringData:
  keystorePassword: "changeit"
EOF
}

function create_fncm_ier_secret_template(){
  mkdir -p $FNCM_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${FNCM_IER_SECRET_FILE}
# YAML template for ibm-ier-secret secret
---
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: ibm-ier-secret
  namespace: "$CP4BA_SERVICES_NS"
stringData:
  keystorePassword: "changeit"
EOF
}

function create_odm_secret_template(){
  local dbname=$1
  local dbserver=$2
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  wait_msg "Creating Operational Decision Manager secret YAML template"
  mkdir -p $ODM_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${ODM_SECRET_FILE}
# YAML template for ibm-odm-db-secret secret
---
apiVersion: v1
kind: Secret
metadata:
  name: ibm-odm-db-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
type: Opaque
stringData:
  db-user: "Your external database username"
  db-password: "Your external database password"
EOF
  success "Created Operational Decision Manager secret YAML template\n"
}

# function for creating the template for CP4BA BAN capabilities secret 
function create_ban_secret_template(){
  local dbname=$1
  local dbserver=$2
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  mkdir -p $BAN_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${BAN_SECRET_FILE}
# YAML template for ibm-ban-secret secret
---
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: ibm-ban-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
stringData:
  appLoginUsername: "<APPLOGIN_USER>"
  appLoginPassword: "<APPLOGIN_PASSWORD>"
  navigatorDBUsername: "<ICN_DB_USER_NAME>"
  navigatorDBPassword: "<ICNDB_PASSWORD>"
  jMailUsername: "<JMAIL_ADMIN>"
  jMailPassword: "<JMAIL_PASSWORD>"
  ltpaPassword: "<LTPA_PASSWORD>"
  keystorePassword: "<KEYSTORE_PASSWORD>"
EOF
}

# This function cover DB2
function create_ban_db2_ssl_template(){
  wait_msg "Creating BAN db2 ssl secret YAML template"
  mkdir -p $BAN_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${BAN_DB_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-ban-db-ssl-cert-secret
if [[ -f "<ban-crt-file-in-local>/db-cert.crt" ]]; then
  kubectl delete secret generic "<ban-db-ssl-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<ban-db-ssl-secret-name>" --from-file=tls.crt="<ban-crt-file-in-local>" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"db-cert.crt"\" into \"<ban-crt-file-in-local>\" first."
  exit 1
fi
EOF
  success "Created BAN db2 ssl secret YAML template\n"
  chmod 755 ${BAN_DB_SSL_SECRET_FILE}
}

# function for creating the template for CP4BA ADP capabilities secret 
function create_aca_db_secret_template(){
  local dbname=$1
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  wait_msg "Creating DPE DB secret shell script template"
  mkdir -p $ADP_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${ADP_BASE_DB_SECRET_FILE}
#!/bin/bash
#
# Shell template for creating Document Processing Engine (DPE) DB secret
# Run this script in the namespace or project in which you are deploying CP4BA
#
# ---- Sample format of script ----
# kubectl create secret generic "<YOUR_SECRET_NAME>" \\
# --from-literal=BASE_DB_USER="<YOUR_BASE_DB_USER>" \\
# --from-literal=BASE_DB_CONFIG="<YOUR_BASE_DB_PWD>" \\
# One PROJNAME_DB_CONFIG line for each project database your have
# --from-literal=<YOUR_PROJ_NAME>_DB_CONFIG="<YOUR_PROJ_DB_PWD>" \\
# The line below if only needed if using SSL connection for DB2   
# --from-file=CERT="<REPLACE_WITH_PATH_TO_DB2_SSL_CERT_FILE]>"
#
# ---- End of Sample ----
EOF

  # set execute permissions on the file since it is a shell script
  chmod +x ${ADP_BASE_DB_SECRET_FILE}

  # Start kubectl command
  echo "" >> ${ADP_BASE_DB_SECRET_FILE}
  echo "kubectl delete secret generic \"aca-basedb\" -n \"$CP4BA_SERVICES_NS\" >/dev/null 2>&1" >> ${ADP_BASE_DB_SECRET_FILE}
  echo "kubectl create secret generic \"aca-basedb\" -n \"$CP4BA_SERVICES_NS\"\\" >> ${ADP_BASE_DB_SECRET_FILE}

  #  Add basedb user
  local tmp_dbuser="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
  local tmp_dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuser")
  echo " --from-literal=BASE_DB_USER=\"$tmp_dbuser\" \\" >> ${ADP_BASE_DB_SECRET_FILE}

  # Add basedb pwd
  local tmp_dbuserpwd="$(prop_db_name_user_property_file ADP_BASE_DB_USER_PASSWORD)"
  local tmp_dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuserpwd")
  if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
      temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode) 
      echo " --from-literal=BASE_DB_CONFIG='$temp_val' \\" >> ${ADP_BASE_DB_SECRET_FILE}
  else
      echo " --from-literal=BASE_DB_CONFIG=\"$tmp_dbuserpwd\" \\" >> ${ADP_BASE_DB_SECRET_FILE}
  fi
  

  local db_name_array=()
  local db_user_array=()
  local db_userpwd_array=()

  local tmp_dbname=$(prop_db_name_user_property_file ADP_PROJECT_DB_NAME)
  local tmp_dbuser=$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_NAME)
  local tmp_dbuserpwd=$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_PASSWORD)
  tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
  tmp_dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuser")
  tmp_dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuserpwd")

  OIFS=$IFS
  IFS=',' read -ra db_name_array <<< "$tmp_dbname"
  IFS=',' read -ra db_user_array <<< "$tmp_dbuser"
  IFS=',' read -ra db_userpwd_array <<< "$tmp_dbuserpwd"
  IFS=$OIFS

  if [[ ${#db_name_array[@]} != ${#db_user_array[@]} || ${#db_user_array[@]} != ${#db_userpwd_array[@]} ]]; then
    fail "The number of values of: ADP_PROJECT_DB_NAME, ADP_PROJECT_DB_USER_NAME, ADP_PROJECT_DB_USER_PASSWORD must all be equal. Exit ..."
  else
    # Check if SSL is being used, if so, we need to add a line for path to certificate files
    # ADP only supports 1 database server, so only the first property in array will be used
    tmp_dbservername=${db_server_array[0]}
    local db_ssl_enable=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.DATABASE_SSL_ENABLE)")
    db_ssl_enable=$(echo $db_ssl_enable| tr '[:upper:]' '[:lower:]')

    if [[ "$db_ssl_enable" == "true" || "$db_ssl_enable" == "yes" || "$db_ssl_enable" == "y" ]]; then
        # if SSL, include line for CERT
        #  specify SSL cert file folder
        # ADP only supports 1 database server, so only the first property in array will be used
        ssl_folder_path="$(prop_db_server_property_file ${db_server_array[0]}.DATABASE_SSL_CERT_FILE_FOLDER)"
        ssl_folder_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$ssl_folder_path") 

        if [[ "$DB_TYPE" == "postgresql" ]]; then                  
          local tmp_postgresql_client_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
          tmp_postgresql_client_flag=$(echo $tmp_postgresql_client_flag | tr '[:upper:]' '[:lower:]') 
          if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then    
            echo " --from-file=CERT=\"${ssl_folder_path}/client.crt\" \\" >> ${ADP_BASE_DB_SECRET_FILE}
            echo " --from-file=KEY=\"${ssl_folder_path}/client.key\" \\" >> ${ADP_BASE_DB_SECRET_FILE}
            echo " --from-file=ROOTCERT=\"${ssl_folder_path}/root.crt\" \\" >> ${ADP_BASE_DB_SECRET_FILE}
          else
            # when POSTGRESQL_SSL_CLIENT_SERVER=false, only root cert is needed.  in this situation the scripts seem to expect "db-cert.crt" as the filename
            echo " --from-file=ROOTCERT=\"${ssl_folder_path}/db-cert.crt\" \\" >> ${ADP_BASE_DB_SECRET_FILE}
          fi
        else 
          echo " --from-file=CERT=\"${ssl_folder_path}/db-cert.crt\" \\" >> ${ADP_BASE_DB_SECRET_FILE}
        fi
        
    fi

    # Used later in check for when last line of script is reached
    projs_max_index=${#db_name_array[@]}-1
    
    for num in "${!db_name_array[@]}"; do
        tmp_dbname=${db_name_array[num]}
        tmp_dbname=$(echo $tmp_dbname | tr '[:lower:]' '[:upper:]')
        tmp_dbuser=${db_user_array[num]}
        tmp_dbuserpwd=${db_userpwd_array[num]}

        if [[ "$num" -lt "$projs_max_index" ]]; then
            # if not last line, then trailing slash is needed at end of line
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                echo " --from-literal=${tmp_dbname}_DB_CONFIG='${temp_val}' \\" >> ${ADP_BASE_DB_SECRET_FILE}
            else
                echo " --from-literal=${tmp_dbname}_DB_CONFIG=\"${tmp_dbuserpwd}\" \\" >> ${ADP_BASE_DB_SECRET_FILE}
            fi
        else
            # if this is last line, then no trailing slash needed
            if [[ "${tmp_dbuserpwd:0:8}" == "{Base64}"  ]]; then
                temp_val=$(echo "$tmp_dbuserpwd" | sed -e "s/^{Base64}//" | base64 --decode)
                echo " --from-literal=${tmp_dbname}_DB_CONFIG='${temp_val}' " >> ${ADP_BASE_DB_SECRET_FILE} 
            else
                echo " --from-literal=${tmp_dbname}_DB_CONFIG=\"${tmp_dbuserpwd}\" " >> ${ADP_BASE_DB_SECRET_FILE} 
            fi
        fi
    done

    # Add label for DPE secret
    tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ADP_BASE_DB_NAME)"
    check_dbserver_name_valid $tmp_dbservername "ADP_BASE_DB_NAME"
    echo "kubectl label --overwrite secret \"aca-basedb\" base-db-server=$tmp_dbservername" >> ${ADP_BASE_DB_SECRET_FILE}
    echo "kubectl label --overwrite secret \"aca-basedb\" base-db-name=$tmp_dbname" >> ${ADP_BASE_DB_SECRET_FILE}
    # tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ADP_PROJECT_DB_NAME)"
    # echo "kubectl label --overwrite secret \"aca-basedb\" proj-db-server=$tmp_dbservername" >> ${ADP_BASE_DB_SECRET_FILE}

    echo "# IMPORTANT:"
    echo "# Please confirm that the values above are correct, and modify as needed." >> ${ADP_BASE_DB_SECRET_FILE}

    if [[ "$db_ssl_enable" == "true" || "$db_ssl_enable" == "yes" || "$db_ssl_enable" == "y" ]]; then
      echo "# Please confirm that the paths for the SSL certificates and keys are correct." >> ${ADP_BASE_DB_SECRET_FILE}
      echo "# If needed, remove any lines that are not applicable for your database environment." >> ${ADP_BASE_DB_SECRET_FILE}
    fi
  fi

  success "Created DPE DB secret shell script template\n"
}


# function for creating the template for CP4BA ADP capabilities secret 

function create_adp_secret_template(){
  wait_msg "Creating ibm-adp-secret YAML template"
  mkdir -p $ADP_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${ADP_SECRET_FILE}
# YAML template for ibm-adp-secret secret
---
kind: Secret
apiVersion: v1
metadata:
  name: ibm-adp-secret
  namespace: "$CP4BA_SERVICES_NS"
type: Opaque
stringData:
  serviceUser: "<SERVICE_USER>"
  servicePwd: "<SERVICE_PASSWORD>"
  serviceUserBas: "<SERVICE_USER_BAS>"
  servicePwdBas: "<SERVICE_PASSWORD_BAS>"
  serviceUserCa: "<SERVICE_USER_CA>"
  servicePwdCa: "<SERVICE_PASSWORD_CA>"
  envOwnerUser: "<ENV_OWNER_USER>"
  envOwnerPwd: "<ENV_OWNER_PASSWORD>"
  # If you want to use your own Enterprise MongoDB instance in the environment, 
  # you must also include the mongoURI and your Mongo user and password values in the secret
  # mongoUri: "mongodb://mongo:<mongoPwd>@<mongo_database_hostname>:<mongo_database_port>/<mongo_database_name>?authSource=admin&connectTimeoutMS=3000"
  # mongoUser: "<MONGO_USER>"
  # mongoPwd: "<MONGO_PASSWORD>"
EOF
  success "Created ibm-adp-secret secret YAML template\n"
}

function create_adp_git_connection_ssl_template(){
  wait_msg "Creating ADP Git connection ssl secret YAML template"
  mkdir -p $ADP_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${ADP_GIT_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-adp-git-tls-secret
if [[ -f "<adp-git-crt-file-in-local>/git-cert.crt" ]]; then
  kubectl delete secret generic "<adp-git-ssl-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<adp-git-ssl-secret-name>" --from-file=tls.crt="<adp-git-crt-file-in-local>/git-cert.crt" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"git-cert.crt\" into \"<adp-git-crt-file-in-local>\" first."
  exit 1
fi
EOF
  success "Created ADP Git connection ssl secret YAML template\n"
  chmod 755 ${ADP_GIT_SSL_SECRET_FILE}
}

function create_adp_cdra_ssl_template(){
  wait_msg "Creating ADP CDRA route certificate secret YAML template"
  mkdir -p $ADP_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${ADP_CDRA_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-adp-cdra-tls-secret
if [[ -f "<adp-cdra-crt-file-in-local>/cdra_tls_cert.crt" ]]; then
  kubectl delete secret generic "<adp-cdra-ssl-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<adp-cdra-ssl-secret-name>" --from-file=tls.crt="<adp-cdra-crt-file-in-local>/cdra_tls_cert.crt" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"cdra_tls_cert.crt\" into \"<adp-cdra-crt-file-in-local>\" first."
  exit 1
fi
EOF
  success "Created ADP CDRA route certificate secret YAML template\n"
  chmod 755 ${ADP_CDRA_SSL_SECRET_FILE}
}

function create_aca_design_api_key_template(){
  wait_msg "Creating ADP ACA design api key secret YAML template"
  mkdir -p $ADP_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${ADP_ACA_DESIGN_API_KEY_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-adp-cdra-tls-secret
  kubectl delete secret generic "<cp4a-aca-design-api-key-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<cp4a-aca-design-api-key-secret-name>" \
  --from-literal=ZenApiKey=<cp4a-aca-design-api-user>:<cp4a-aca-design-zen-api-key> -n "$CP4BA_SERVICES_NS"
EOF
  success "Creating ADP ACA design api key secret YAML template\n"
  chmod 755 ${ADP_ACA_DESIGN_API_KEY_SECRET_FILE}
}

# function for creating the template for CP4BA Application Engine capabilities secret 
function create_app_engine_secret_template(){
  local dbname=$1
  local dbserver=$2
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  wait_msg "Creating Application Engine secret YAML template"
  mkdir -p $APP_ENGINE_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${APP_ENGINE_SECRET_FILE}
# YAML template for icp4adeploy-workspace-aae-app-engine-admin-secret secret
---
apiVersion: v1
kind: Secret
metadata:
  # the name: {{meta.name}}-workspace-aae-app-engine-admin-secret, {{meta.name}} is the value of metadata.name in CP4BA Custome Resource 
  name: icp4adeploy-workspace-aae-app-engine-admin-secret
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
type: Opaque
stringData: 
  AE_DATABASE_PWD: "Your App Engine database password"
  AE_DATABASE_USER: "Your App Engine database username"
  # It is required if you are using Redis for session persistence
  REDIS_PASSWORD: ""
EOF
  success "Created Application Engine secret YAML template\n"
}

# function for creating the template for CP4BA Application Engine/Playback Server capabilities secret when enable SSL with Oracle

function create_app_engine_oracle_sso_secret_template(){
  local dbserver=$1
  wait_msg "Creating Application Engine/Playback Server secret YAML template for Oracle with ssl enabled"
  mkdir -p $DB_SSL_SECRET_FOLDER/$dbserver >/dev/null 2>&1
  APP_ORACLE_SSO_SSL_SECRET_FILE=${DB_SSL_SECRET_FOLDER}/$dbserver/ibm-ae-oracle-sso-cert-secret-for-${dbserver}.sh

cat << EOF > ${APP_ORACLE_SSO_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for storing wallet SSO binary file when an SSL connection is enabled and Oracle database is selected for Application Engine/Playback server.
if [[ -f "<your-oracle-sso-wallet-file-path>/cwallet.sso" ]]; then
  kubectl delete secret generic "<your-oracle-sso-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "<your-oracle-sso-secret-name>" --from-file=cwallet.sso="<your-oracle-sso-wallet-file-path>/cwallet.sso" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"cwallet.sso\" into \"<your-oracle-sso-wallet-file-path>\" first."
  exit 1
fi

EOF
  success "Created Application Engine/Playback Server secret YAML template for Oracle with ssl enabled\n"
  chmod 755 ${APP_ORACLE_SSO_SSL_SECRET_FILE}
}


function create_bas_secret_template(){
  local dbname=$1
  local dbserver=$2
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  wait_msg "Creating Business Automation Studio secret YAML template"
  mkdir -p $BAS_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${BAS_SECRET_FILE}
# YAML template for icp4adeploy-bas-admin-secret secret
---
apiVersion: v1
kind: Secret
metadata:
  # the name: {{meta.name}}-bas-admin-secret, {{meta.name}} is the value of metadata.name in CP4BA Custome Resource 
  name: icp4adeploy-bas-admin-secret
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
type: Opaque
stringData:
  dbUsername: "Your Studio database username"
  dbPassword: "Your Studio database password"
EOF
  success "Created Business Automation Studio secret YAML template\n"
}

function create_ae_playback_secret_template(){
  local dbname=$1
  local dbserver=$2
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  wait_msg "Creating Application Engine playback server secret YAML template"
  mkdir -p $APP_ENGINE_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${APP_ENGINE_PLAYBACK_SECRET_FILE}
# YAML template for playback-server-admin-secret secret
---
apiVersion: v1
kind: Secret
metadata:
  name: playback-server-admin-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
type: Opaque
stringData:
  AE_DATABASE_PWD: "Your App Engine database password"
  AE_DATABASE_USER: "Your App Engine database username"
  # It is required if you are using Redis for session persistence
  REDIS_PASSWORD: ""

EOF
  success "Created Application Engine playback server secret YAML template\n"
}

function create_baw_authoring_secret_template(){
  local dbname=$1
  local dbserver=$2
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  wait_msg "Creating Business Automation Workflow secret YAML template"
  mkdir -p $BAW_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${BAW_SECRET_FILE}
# YAML template for ibm-baw-wfs-server-db-secret secret
---
apiVersion: v1
kind: Secret
metadata:
  name: ibm-baw-wfs-server-db-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
type: Opaque  
stringData:
  dbUser: <DB_USER>
  password: <DB_USER_PASSWORD>

EOF
  success "Created Business Automation Workflow server secret YAML template\n"
}

function create_ums_secret_template(){
  local dbname=$1
  local dbserver=$2
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  wait_msg "Creating UMS secret YAML template"
  mkdir -p $UMS_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${UMS_SECRET_FILE}
# YAML template for ibm-dba-ums-secret secret
---
apiVersion: v1
kind: Secret
metadata:
  name: ibm-dba-ums-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
type: Opaque  
stringData:
  adminUser: <UMSADMIN>
  adminPassword: <UMSPASSWORD>
  oauthDBUser: <DB_USER>
  oauthDBPassword: <DB_USER_PASSWORD>
  tsDBUser: <DB_USER>
  tsDBPassword:  <DB_USER_PASSWORD>

EOF
  success "Created UMS secret YAML template\n"
}

function create_baw_aws_secret_template(){
  local dbname=$1
  local dbserver=$2
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  wait_msg "Creating Automation Workstream Services secret YAML template"
  mkdir -p $BAW_AWS_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${BAW_AWS_SECRET_FILE}
# YAML template for ibm-aws-wfs-server-db-secret secret
---
apiVersion: v1
kind: Secret
metadata:
  name: ibm-aws-wfs-server-db-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
type: Opaque  
stringData:
  dbUser: <DB_USER>
  password: <DB_USER_PASSWORD>

EOF
  success "Created Automation Workstream Services secret YAML template\n"
}


function create_baw_runtime_secret_template(){
  local dbname=$1
  local dbserver=$2
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
  dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
  wait_msg "Creating Business Automation Workflow secret YAML template"
  mkdir -p $BAW_AWS_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${BAW_RUNTIME_SECRET_FILE}
# YAML template for ibm-baw-wfs-server-db-secret secret
---
apiVersion: v1
kind: Secret
metadata:
  name: ibm-baw-wfs-server-db-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
type: Opaque  
stringData:
  dbUser: <DB_USER>
  password: <DB_USER_PASSWORD>

EOF
  success "Created Business Automation Workflow secret YAML template\n"
}

function create_icp4a_encryption_key_secret_template(){
  wait_msg "Creating encryption key secret YAML template"
  mkdir -p $BAW_AWS_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${ICP4A_ENCRYPTION_KEY_SECRET_FILE}
# YAML template for icp4a-shared-encryption-key secret
---
apiVersion: v1
kind: Secret
metadata:
  name: icp4a-shared-encryption-key
  namespace: "$CP4BA_SERVICES_NS"
type: Opaque
stringData:
  encryptionKey: <ENCRYPTION_KEY>

EOF
  success "Created encryption key secret YAML template\n"
}

function create_ads_secret_template(){
  wait_msg "Creating Automation Decision Services secret YAML template for external MongoDB"
  mkdir -p $ADS_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${ADS_SECRET_FILE}
# YAML template for <instance-name>-ads-mongo-secret secret
---
apiVersion: v1
kind: Secret
metadata:
  name: icp4adeploy-dba-ads-mongo-secret
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-name: ads-mongo
type: Opaque
stringData:
  gitMongoUri: "mongodb://<sampleDbUser>:<sampleDbPassword>@<mongodb0.example.com>:27017/ads-git?retryWrites=true&w=majority&authSource=admin"
  mongoUri: "mongodb://<sampleDbUser>:<sampleDbPassword>@<mongodb1.example.com>:27017/ads?retryWrites=true&w=majority&authSource=admin"
  mongoHistoryUri: "mongodb://<sampleDbUser>:<sampleDbPassword>@<mongodb1.example.com>:27017/ads-history?retryWrites=true&w=majority&authSource=admin"
  runtimeMongoUri: "mongodb://<sampleDbUser>:<sampleDbPassword>@<mongodb1.example.com>:27017/ads-runtime-archive-metadata?retryWrites=true&w=majority&authSource=admin"
EOF
  success "Created Automation Decision Services secret YAML template for external MongoDB \n"
}

function create_zen_external_db_secret_template(){
  wait_msg "Creating ibm-zen-metastore-edb-secret secret YAML template for Zen metastore external Postgres DB"
  mkdir -p $ZEN_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${ZEN_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-zen-metastore-edb-secret.sh
if [[ -f "<cp4a-db-crt-file-in-local>/root.crt" && -f "<cp4a-db-crt-file-in-local>/client.crt" && -f "<cp4a-db-crt-file-in-local>/client.key" ]]; then
  openssl x509 -in <cp4a-db-crt-file-in-local>/root.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1

  openssl x509 -in <cp4a-db-crt-file-in-local>/client.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1

  openssl rsa -in <cp4a-db-crt-file-in-local>/client.key -outform PEM -out <cp4a-db-crt-file-in-local>/client_key.pem >/dev/null 2>&1

  openssl x509 -in <cp4a-db-crt-file-in-local>/client.crt -outform PEM -out <cp4a-db-crt-file-in-local>/client.pem >/dev/null 2>&1

  openssl x509 -in <cp4a-db-crt-file-in-local>/root.crt -outform PEM -out <cp4a-db-crt-file-in-local>/root.pem >/dev/null 2>&1

  kubectl delete secret generic "ibm-zen-metastore-edb-secret" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "ibm-zen-metastore-edb-secret" --from-file=ca.crt="<cp4a-db-crt-file-in-local>/root.pem"\
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/client.pem"\
  --from-file=tls.key="<cp4a-db-crt-file-in-local>/client_key.pem"\
  --type=kubernetes.io/tls -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"root.crt\" \"client.crt\" \"client.key\" into \"<cp4a-db-crt-file-in-local>\" first."
  exit 1
fi
EOF
  success "Created ibm-zen-metastore-edb-secret secret YAML template for Zen metastore external Postgres DB\n"
  chmod 755 ${ZEN_SECRET_FILE}
}

function create_zen_external_db_configmap_template(){
  wait_msg "Creating ibm-zen-metastore-edb-cm configMap YAML template for Zen metastore external Postgres DB"
  mkdir -p $ZEN_SECRET_FOLDER >/dev/null 2>&1
cat << EOF > ${ZEN_CONFIGMAP_FILE}
# YAML template for ibm-zen-metastore-edb-cm configMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ibm-zen-metastore-edb-cm
  namespace: "$CP4BA_SERVICES_NS"
data:
  IS_EMBEDDED: "false"
  DATABASE_CA_CERT: ca.crt
  DATABASE_CLIENT_CERT: tls.crt
  DATABASE_CLIENT_KEY: tls.key
  DATABASE_MONITORING_SCHEMA: <MonitoringSchema>
  DATABASE_NAME: <DatabaseName>
  DATABASE_PORT: "<DatabasePort>"
  DATABASE_R_ENDPOINT: "<DatabaseReadHostName>"
  DATABASE_RW_ENDPOINT: "<DatabaseHostName>"
  DATABASE_SCHEMA: <DatabaseSchema>
  DATABASE_USER: <DatabaseUser>
EOF
  success "Created ibm-zen-metastore-edb-cm configMap YAML template for Zen metastore external Postgres DB\n"
}

function create_im_external_db_secret_template(){
  wait_msg "Creating im-datastore-edb-secret secret YAML template for IM metastore external Postgres DB"
  mkdir -p $IM_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${IM_SECRET_FILE}
#!/bin/bash
# Shell template for im-datastore-edb-secret.sh
if [[ -f "<cp4a-db-crt-file-in-local>/root.crt" && -f "<cp4a-db-crt-file-in-local>/client.crt" && -f "<cp4a-db-crt-file-in-local>/client.key" ]]; then
  openssl x509 -in <cp4a-db-crt-file-in-local>/root.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1
  openssl x509 -in <cp4a-db-crt-file-in-local>/client.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1
  openssl rsa -in <cp4a-db-crt-file-in-local>/client.key -outform PEM -out <cp4a-db-crt-file-in-local>/client_key.pem >/dev/null 2>&1
  openssl x509 -in <cp4a-db-crt-file-in-local>/client.crt -outform PEM -out <cp4a-db-crt-file-in-local>/client.pem >/dev/null 2>&1
  openssl x509 -in <cp4a-db-crt-file-in-local>/root.crt -outform PEM -out <cp4a-db-crt-file-in-local>/root.pem >/dev/null 2>&1
  kubectl delete secret generic "im-datastore-edb-secret" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "im-datastore-edb-secret" --from-file=ca.crt="<cp4a-db-crt-file-in-local>/root.pem"\
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/client.pem"\
  --from-file=tls.key="<cp4a-db-crt-file-in-local>/client_key.pem"\
  --type=kubernetes.io/tls -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"root.crt\" \"client.crt\" \"client.key\" into \"<cp4a-db-crt-file-in-local>\" first."
  exit 1
fi
EOF
  success "Created im-datastore-edb-secret secret YAML template for IM metastore external Postgres DB\n"
  chmod 755 ${IM_SECRET_FILE}
}

function create_im_external_db_configmap_template(){
  wait_msg "Creating im-datastore-edb-cm configMap YAML template for IM metastore external Postgres DB"
  mkdir -p $IM_SECRET_FOLDER >/dev/null 2>&1
cat << EOF > ${IM_CONFIGMAP_FILE}
# YAML template for im-datastore-edb-cm configMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: im-datastore-edb-cm
  namespace: "$CP4BA_SERVICES_NS"
data:
  IS_EMBEDDED: "false"
  DATABASE_PORT: "<DatabasePort>"
  DATABASE_R_ENDPOINT: "<DatabaseReadHostName>"
  DATABASE_RW_ENDPOINT: "<DatabaseHostName>"
  DATABASE_USER: <DatabaseUser>
  DATABASE_NAME: <DatabaseName>
  DATABASE_CA_CERT: ca.crt
  DATABASE_CLIENT_CERT: tls.crt
  DATABASE_CLIENT_KEY: tls.key
EOF
  success "Created im-datastore-edb-cm configMap YAML template for IM metastore external Postgres DB\n"
}

function create_bts_external_db_secret_template(){
  wait_msg "Creating bts-datastore-edb-secret secret YAML template for BTS metastore external Postgres DB"
  mkdir -p $BTS_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${BTS_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for bts-datastore-edb-secret.sh
if [[ -f "<cp4a-db-crt-file-in-local>/root.crt" && -f "<cp4a-db-crt-file-in-local>/client.crt" && -f "<cp4a-db-crt-file-in-local>/client.key" ]]; then
  openssl x509 -in <cp4a-db-crt-file-in-local>/root.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1
  openssl x509 -in <cp4a-db-crt-file-in-local>/client.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1
  openssl rsa -in <cp4a-db-crt-file-in-local>/client.key -outform PEM -out <cp4a-db-crt-file-in-local>/client_key.pem >/dev/null 2>&1
  openssl x509 -in <cp4a-db-crt-file-in-local>/client.crt -outform PEM -out <cp4a-db-crt-file-in-local>/client.pem >/dev/null 2>&1
  openssl x509 -in <cp4a-db-crt-file-in-local>/root.crt -outform PEM -out <cp4a-db-crt-file-in-local>/root.pem >/dev/null 2>&1
  openssl pkcs8 -topk8 -inform PEM -in <cp4a-db-crt-file-in-local>/client_key.pem -outform DER -nocrypt -out <cp4a-db-crt-file-in-local>/tls_key.pk8
  kubectl delete secret generic "bts-datastore-edb-secret" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "bts-datastore-edb-secret" --from-file=ca.crt="<cp4a-db-crt-file-in-local>/root.pem"\
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/client.pem"\
  --from-file=tls.key="<cp4a-db-crt-file-in-local>/tls_key.pk8" -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"root.crt\" \"client.crt\" \"client.key\" into \"<cp4a-db-crt-file-in-local>\" first."
  exit 1
fi
EOF
  success "Created bts-datastore-edb-secret secret YAML template for BTS metastore external Postgres DB\n"
  chmod 755 ${BTS_SSL_SECRET_FILE}
}

function create_bts_external_db_configmap_template(){
  wait_msg "Creating ibm-bts-config-extension configMap YAML template for BTS metastore external Postgres DB"
  mkdir -p $BTS_SECRET_FOLDER >/dev/null 2>&1
cat << EOF > ${BTS_CONFIGMAP_FILE}
# YAML template for ibm-bts-config-extension configMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ibm-bts-config-extension
  namespace: "$CP4BA_SERVICES_NS"
data:
  serverName: "<DatabaseHostName>"
  portNumber: "<DatabasePort>"
  databaseName: <DatabaseName>
  ssl: "true"
  sslMode: verify-ca
  sslSecretName: bts-datastore-edb-secret
  customPropertyName1: sslKey
  customPropertyValue1: "/opt/ibm/wlp/usr/shared/resources/security/db/tls.key"
  customPropertyName2: user
  customPropertyValue2: "postgres"
EOF
  success "Created bts-datastore-edb-cm configMap YAML template for BTS metastore external Postgres DB\n"
}

function create_cp4ba_tls_issuer_template(){
  wait_msg "Creating ibm-cp4ba-tls-issuer-secret secret template for Issuer used by Opensearch/Kafka"
  mkdir -p $CP4BA_TLS_ISSUER_FOLDER >/dev/null 2>&1

cat << EOF > ${CP4BA_TLS_ISSUER_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4ba-tls-issuer-secret.sh
if [[ -f "<cp4a-issuer-tls-crt-file-in-local>/tls.crt" && -f "<cp4a-issuer-tls-crt-file-in-local>/tls.key" ]]; then
  openssl x509 -in <cp4a-issuer-tls-crt-file-in-local>/tls.crt -noout -subject -issuer -startdate -enddate >/dev/null 2>&1
  openssl rsa -in <cp4a-issuer-tls-crt-file-in-local>/tls.key -outform PEM -out <cp4a-issuer-tls-crt-file-in-local>/tls_key.pem >/dev/null 2>&1
  openssl x509 -in <cp4a-issuer-tls-crt-file-in-local>/tls.crt -outform PEM -out <cp4a-issuer-tls-crt-file-in-local>/tls.pem >/dev/null 2>&1
  
  kubectl delete secret generic "ibm-cp4ba-tls-issuer-secret" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  kubectl create secret generic "ibm-cp4ba-tls-issuer-secret" --from-file=tls.crt="<cp4a-issuer-tls-crt-file-in-local>/tls.pem"\
  --from-file=tls.key="<cp4a-issuer-tls-crt-file-in-local>/tls_key.pem"\
  --type=kubernetes.io/tls -n "$CP4BA_SERVICES_NS"
else
  echo -e "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"tls.crt\" and \"tls.key\" into \"<cp4a-issuer-tls-crt-file-in-local>\" first."
  exit 1
fi
EOF
  success "Created ibm-cp4ba-tls-issuer-secret secret template for Issuer used by Opensearch/Kafka\n"
  chmod 755 ${CP4BA_TLS_ISSUER_SECRET_FILE}

  wait_msg "Creating cp4ba-tls-issuer Issuer YAML template for for Opensearch/Kafka"
  mkdir -p $BTS_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${CP4BA_TLS_ISSUER_FILE}
# YAML template for cp4ba-tls-issuer Issuer
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: cp4ba-tls-issuer
  namespace: "$CP4BA_SERVICES_NS"
spec:
  ca:
    secretName: ibm-cp4ba-tls-issuer-secret
EOF
  success "Created cp4ba-tls-issuer Issuer YAML template for for Opensearch/Kafka\n"

}