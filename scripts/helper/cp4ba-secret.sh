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
    cp4ba.ibm.com/backup-type: mandatory
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
    cp4ba.ibm.com/backup-type: mandatory
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
  ${CLI_CMD} delete secret "<cp4a-ldap_ssl_secret_name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<cp4a-ldap_ssl_secret_name>" --from-file=tls.crt="<cp4a-ldap-crt-file-in-local>/ldap-cert.crt" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "<cp4a-ldap_ssl_secret_name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"ldap-cert.crt\" into \"<cp4a-ldap-crt-file-in-local>\" first."
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
  ${CLI_CMD} delete secret "<cp4a-ldap_ssl_secret_name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<cp4a-ldap_ssl_secret_name>" --from-file=tls.crt="<cp4a-ldap-crt-file-in-local>/external-ldap-cert.crt" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "<cp4a-ldap_ssl_secret_name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"external-ldap-cert.crt\" into \"<cp4a-ldap-crt-file-in-local>\" first."
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
  ${CLI_CMD} delete secret "<cp4a-redis_ssl_secret_name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<cp4a-redis_ssl_secret_name>" --from-file=tls.crt="<cp4a-redis-crt-file-in-local>/redis.pem" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "<cp4a-redis_ssl_secret_name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"redis.pem\" into \"<cp4a-redis-crt-file-in-local>\" first."
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
  ${CLI_CMD} delete secret "<cp4a-redis_ssl_secret_name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<cp4a-redis_ssl_secret_name>" --from-file=tls.crt="<cp4a-redis-crt-file-in-local>/redis.pem" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "<cp4a-redis_ssl_secret_name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"redis.pem\" into \"<cp4a-redis-crt-file-in-local>\" first."
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
    cp4ba.ibm.com/backup-type: mandatory
    icp4asupport/capability: fncm
    icp4asupport/deployment: ibm-fncm-secret
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
  tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
if [[ $DB_TYPE != "postgresql" ]]; then
cat << EOF > ${CP4A_DB_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4a-db-ssl-cert-secret

if [[ -f "<cp4a-db-crt-file-in-local>/db-cert.crt" ]]; then
  ${CLI_CMD} delete secret "<cp4a-db-ssl-secret-name>" -n "${CP4BA_SERVICES_NS}" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<cp4a-db-ssl-secret-name>" \
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/db-cert.crt" \
  --from-file=cacert.crt="<cp4a-db-crt-file-in-local>/db-cert.crt" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "<cp4a-db-ssl-secret-name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"db-cert.crt\" into \"<cp4a-db-crt-file-in-local>\" first."
  exit 1
fi
EOF
elif [[ $DB_TYPE == "postgresql" && ($tmp_flag == "no" || $tmp_flag == "false" || $tmp_flag == "" || -z $tmp_flag) ]]; then
cat << EOF > ${CP4A_DB_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4a-db-ssl-cert-secret

if [[ -f "<cp4a-db-crt-file-in-local>/db-cert.crt" ]]; then
  ${CLI_CMD} delete secret "<cp4a-db-ssl-secret-name>" -n "${CP4BA_SERVICES_NS}" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<cp4a-db-ssl-secret-name>" \
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/db-cert.crt" \
  --from-file=serverca.pem="<cp4a-db-crt-file-in-local>/db-cert.crt" -n "${CP4BA_SERVICES_NS}"
  ${CLI_CMD} label secret "<cp4a-db-ssl-secret-name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"db-cert.crt\" into \"<cp4a-db-crt-file-in-local>\" first."
  exit 1
fi
EOF
else
cat << EOF > ${CP4A_DB_SSL_SECRET_FILE}
#!/bin/bash
# Shell template for ibm-cp4a-db-ssl-cert-secret

if [[ -f "<cp4a-db-crt-file-in-local>/root.crt" && -f "<cp4a-db-crt-file-in-local>/client.crt" && -f "<cp4a-db-crt-file-in-local>/client.key" ]]; then
  ${CLI_CMD} delete secret "<cp4a-db-ssl-secret-name>" -n "${CP4BA_SERVICES_NS}" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<cp4a-db-ssl-secret-name>" \
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/client.crt" \
  --from-file=ca.crt="<cp4a-db-crt-file-in-local>/root.crt" \
  --from-file=tls.key="<cp4a-db-crt-file-in-local>/client.key" \
  --from-literal=sslmode=[require|verify-ca|verify-full] -n "${CP4BA_SERVICES_NS}"
  ${CLI_CMD} label secret "<cp4a-db-ssl-secret-name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"root.crt\" \"client.crt\" \"client.key\" into \"<cp4a-db-crt-file-in-local>\" first."
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
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    icp4asupport/capability: fncm
    icp4asupport/deployment: ibm-icc-secret
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
  labels:
    cp4ba.ibm.com/backup-type: mandatory
stringData:
  keystorePassword: "<KEYSTORE_PASSWORD>"
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
  labels:
    cp4ba.ibm.com/backup-type: mandatory
stringData:
  keystorePassword: "<KEYSTORE_PASSWORD>"
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
  labels:
    cp4ba.ibm.com/backup-type: mandatory
stringData:
  keystorePassword: "<KEYSTORE_PASSWORD>"
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
    cp4ba.ibm.com/backup-type: mandatory
type: Opaque
stringData:
  db-user: "Your external database username"
  db-password: "Your external database password"
EOF
  success "Created Operational Decision Manager secret YAML template\n"
}


# K8s secret template function to create the ODM keystore password secret
function create_odm_keystore_password_secret_template(){
  local password=$1 
  mkdir -p $ODM_SECRET_FOLDER >/dev/null 2>&1
  wait_msg "Creating Operational Decision Manager Keystore Password secret YAML template"

cat << EOF > ${ODM_KEYSTORE_SECRET_FILE}
# YAML template for ibm-odm-keystore-secret secret
---
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: ibm-odm-keystore-secret
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
stringData:
  keystorePassword: "$password"
EOF
  success "Created Operational Decision Manager Keystore Password secret YAML template\n"
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
    cp4ba.ibm.com/backup-type: mandatory
    icp4asupport/capability: fncm
    icp4asupport/deployment: ibm-ban-secret
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
  ${CLI_CMD} delete secret "<ban-db-ssl-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<ban-db-ssl-secret-name>" --from-file=tls.crt="<ban-crt-file-in-local>" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "<ban-db-ssl-secret-name>" cp4ba.ibm.com/backup-type=mandatory icp4asupport/capability=fncm icp4asupport/deployment=ibm-ban-db-ssl-cert-secret -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"db-cert.crt"\" into \"<ban-crt-file-in-local>\" first."
  exit 1
fi
EOF
  success "Created BAN db2 ssl secret YAML template\n"
  chmod 755 ${BAN_DB_SSL_SECRET_FILE}
}

# function for creating the yaml template for aca-basedb secret
function create_aca_db_secret_yaml_template(){
    local dbname=$1
    local dbserver=$2
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
cat << EOF > ${ADP_BASE_DB_SECRET_YAML_FILE}
# YAML template for Document Processing Engine (DPE) DB secret
---
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: aca-basedb
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    base-db-server: $dbserver
    base-db-name: $dbname
    cp4ba.ibm.com/backup-type: mandatory
stringData:
  BASE_DB_USER: "<ADP_BASE_DB_USER_NAME>"
  BASE_DB_CONFIG: "<ADP_BASE_DB_USER_PASSWORD>"
EOF

}

# function for creating the template for CP4BA ADP capabilities secret 
function create_aca_db_secret_template(){
    tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ADP_BASE_DB_NAME)"
    check_dbserver_name_valid $tmp_dbservername "ADP_BASE_DB_NAME"
    wait_msg "Creating DPE DB secret YAML template"
    mkdir -p $ADP_SECRET_FOLDER >/dev/null 2>&1
    # Function that creates the yaml template
    create_aca_db_secret_yaml_template $tmp_dbname $tmp_dbservername

    #  Add basedb user
    local tmp_basedbuser="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
    local tmp_basedbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_basedbuser")
    ${YQ_CMD} -i ".stringData.BASE_DB_USER = \"$tmp_basedbuser\"" "$ADP_BASE_DB_SECRET_YAML_FILE"

    # Add basedb pwd
    local tmp_basedbuserpwd="$(prop_db_name_user_property_file ADP_BASE_DB_USER_PASSWORD)"
    local tmp_basedbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_basedbuserpwd")

    local db_name_array=()
    local db_user_array=()
    local db_userpwd_array=()
    local db_server_array=()

    local tmp_dbname=$(prop_db_name_user_property_file ADP_PROJECT_DB_NAME)
    local tmp_dbuser=$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_NAME)
    local tmp_dbuserpwd=$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_PASSWORD)
    local tmp_dbservername_list=$(prop_db_name_user_property_file ADP_PROJECT_DB_SERVER)
    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
    tmp_dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuser")
    tmp_dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbuserpwd")
    tmp_dbservername_list=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername_list")

    OIFS=$IFS
    IFS=',' read -ra db_name_array <<< "$tmp_dbname"
    IFS=',' read -ra db_user_array <<< "$tmp_dbuser"
    IFS=',' read -ra db_userpwd_array <<< "$tmp_dbuserpwd"
    IFS=',' read -ra db_server_array <<< "$tmp_dbservername_list"
    IFS=$OIFS

    # Determine postgres client-auth flag for the ADP DB server (used to decide whether to add per-project DB passwords)
    local tmp_postgresql_client_flag="false"
    if [[ "$DB_TYPE" == "postgresql" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
        tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    fi

    #If Postgres client-auth is enabled, DO NOT add BASE_DB_CONFIG password field
    # https://jsw.ibm.com/browse/DBACLD-203570
    if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
        ${YQ_CMD} -i 'del(.stringData.BASE_DB_CONFIG)' "$ADP_BASE_DB_SECRET_YAML_FILE"
    else
        update_secret_template_passwords "$tmp_basedbuserpwd" "BASE_DB_CONFIG" "$ADP_BASE_DB_SECRET_YAML_FILE"
    fi

    if [[ $DB_TYPE = "postgresql-edb" ]]; then
        tmp_postgresql_client_flag="true"
      fi

    # Validate array lengths - password array only checked if not using client auth
    if [[ (${#db_name_array[@]} != ${#db_user_array[@]}) || (${#db_name_array[@]} != ${#db_server_array[@]}) ]]; then
        fail "The number of values of: ADP_PROJECT_DB_NAME, ADP_PROJECT_DB_USER_NAME, ADP_PROJECT_DB_SERVER must all be equal. Exit ..."
    fi
    if ! is_pg_client_auth && [[ ${#db_name_array[@]} != ${#db_userpwd_array[@]} ]]; then
        fail "The number of values of: ADP_PROJECT_DB_USER_PASSWORD must match other arrays when not using client certificate authentication. Exit ..."
    fi
    
    if [[ ${#db_name_array[@]} -gt 0 ]]; then
        # Check if SSL is being used, if so, we need to add a line for path to certificate files
        # ADP only supports 1 database server, so only the first property in array will be used
        tmp_dbservername=${db_server_array[0]}
        local db_ssl_enable=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.DATABASE_SSL_ENABLE)")
        db_ssl_enable=$(echo "$db_ssl_enable"| tr '[:upper:]' '[:lower:]')

        if [[ "$db_ssl_enable" == "true" || "$db_ssl_enable" == "yes" || "$db_ssl_enable" == "y" ]]; then

            # if SSL, include line for CERT
            #  specify SSL cert file folder
            # ADP only supports 1 database server, so only the first property in array will be used
            ssl_folder_path="$(prop_db_server_property_file ${db_server_array[0]}.DATABASE_SSL_CERT_FILE_FOLDER)"
            ssl_folder_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$ssl_folder_path")
            if [[ "$DB_TYPE" == "postgresql" ]]; then                  
                local tmp_postgresql_client_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
                tmp_postgresql_client_flag=$(echo "$tmp_postgresql_client_flag" | tr '[:upper:]' '[:lower:]') 
                if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then       
                    base64_clientcrt=$(encode_crt_file_to_base64 "${ssl_folder_path}/client.crt")
                    ${YQ_CMD} -i ".data.CERT = \"$base64_clientcrt\"" "$ADP_BASE_DB_SECRET_YAML_FILE"
                    base64_clientkey=$(encode_crt_file_to_base64 "${ssl_folder_path}/client.key")
                    ${YQ_CMD} -i ".data.KEY = \"$base64_clientkey\"" "$ADP_BASE_DB_SECRET_YAML_FILE"
                    base64_rootcrt=$(encode_crt_file_to_base64 "${ssl_folder_path}/root.crt")
                    ${YQ_CMD} -i ".data.ROOTCERT = \"$base64_rootcrt\"" "$ADP_BASE_DB_SECRET_YAML_FILE"
                else
                    # when POSTGRESQL_SSL_CLIENT_SERVER=false, only root cert is needed.  in this situation the scripts seem to expect "db-cert.crt" as the filename
                    base64_dbcrt=$(encode_crt_file_to_base64 "${ssl_folder_path}/db-cert.crt")
                    ${YQ_CMD} -i ".data.ROOTCERT = \"$base64_dbcrt\"" "$ADP_BASE_DB_SECRET_YAML_FILE"
                fi
            else
                base64_dbcrt=$(encode_crt_file_to_base64 "${ssl_folder_path}/db-cert.crt")
                ${YQ_CMD} -i ".data.CERT = \"$base64_dbcrt\"" "$ADP_BASE_DB_SECRET_YAML_FILE"
            fi
            
        fi
        for num in "${!db_name_array[@]}"; do
            tmp_dbname=${db_name_array[num]}
            tmp_dbname=$(echo "$tmp_dbname" | tr '[:lower:]' '[:upper:]')
            tmp_dbuser=${db_user_array[num]}
            tmp_dbuserpwd=${db_userpwd_array[num]}
            # If Postgres client-auth is enabled for the ADP DB server, DO NOT add per-project DB password fields.
            # Other DB types will still add the PROJ_DB_CONFIG passwords. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
            if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
                update_secret_template_passwords "$tmp_dbuserpwd" "${tmp_dbname}_DB_CONFIG" "$ADP_BASE_DB_SECRET_YAML_FILE"
            fi
        done

    fi

    success "Created DPE DB secret YAML template\n"
}

# function for creating the template for CP4BA ADP capabilities secret 
function create_adp_secret_template(){
  local dbserver=$1
  dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
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
# DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: ibm-adp-secret
    cp4ba.ibm.com/backup-type: mandatory
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
  adpggDBUsername: "<ADP_GG_DB_USER_NAME>"
  adpggDBPassword: "<ADP_GG_DB_USER_PASSWORD>"

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
  ${CLI_CMD} delete secret "<adp-git-ssl-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<adp-git-ssl-secret-name>" --from-file=tls.crt="<adp-git-crt-file-in-local>/git-cert.crt" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "<adp-git-ssl-secret-name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"git-cert.crt\" into \"<adp-git-crt-file-in-local>\" first."
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
  ${CLI_CMD} delete secret "<adp-cdra-ssl-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<adp-cdra-ssl-secret-name>" --from-file=tls.crt="<adp-cdra-crt-file-in-local>/cdra_tls_cert.crt" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "<adp-cdra-ssl-secret-name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
  
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"cdra_tls_cert.crt\" into \"<adp-cdra-crt-file-in-local>\" first."
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
  ${CLI_CMD} delete secret "<cp4a-aca-design-api-key-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<cp4a-aca-design-api-key-secret-name>" \
  --from-literal=ZenApiKey=<cp4a-aca-design-api-user>:<cp4a-aca-design-zen-api-key> -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "<cp4a-aca-design-api-key-secret-name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
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
  # For https://jsw.ibm.com/browse/DBACLD-158657
  # Add namespace field for secret template
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
    cp4ba.ibm.com/backup-type: mandatory
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
  ${CLI_CMD} delete secret "<your-oracle-sso-secret-name>" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "<your-oracle-sso-secret-name>" --from-file=cwallet.sso="<your-oracle-sso-wallet-file-path>/cwallet.sso" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "<your-oracle-sso-secret-name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"cwallet.sso\" into \"<your-oracle-sso-wallet-file-path>\" first."
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
  # For https://jsw.ibm.com/browse/DBACLD-158657
  # Add namespace field for secret template
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
    cp4ba.ibm.com/backup-type: mandatory
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
    cp4ba.ibm.com/backup-type: mandatory
type: Opaque
stringData:
  AE_DATABASE_PWD: "Your App Engine database password"
  AE_DATABASE_USER: "Your App Engine database username"
  # It is required if you are using Redis for session persistence
  REDIS_PASSWORD: ""

EOF
  success "Created Application Engine playback server secret YAML template\n"
}

function create_workflow_assistant_secret_template(){
  watsonx_api_key="$(prop_user_profile_property_file WFA.WATSONX_API_KEY)"
  watsonx_api_key=$(sed -e 's/^"//' -e 's/"$//' <<<"$watsonx_api_key")

  watsonx_project_id="$(prop_user_profile_property_file WFA.WATSONX_PROJECT_ID)"
  watsonx_project_id=$(sed -e 's/^"//' -e 's/"$//' <<<"$watsonx_project_id")

  watsonx_token="$(prop_user_profile_property_file WFA.WATSONX_TOKEN)"
  watsonx_token=$(sed -e 's/^"//' -e 's/"$//' <<<"$watsonx_token")

  watsonx_url="$(prop_user_profile_property_file WFA.WATSONX_URL)"
  watsonx_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$watsonx_url")

  if [[ "<Optional>" == $watsonx_token ]]; then
    watsonx_token=""
  fi

  watsonx_password="$(prop_user_profile_property_file WFA.WATSONX_PASSWORD)"
  watsonx_password=$(sed -e 's/^"//' -e 's/"$//' <<<"$watsonx_password")

  if [[ "<Optional>" == $watsonx_password ]]; then
    watsonx_password=""
  fi

  wait_msg "Creating IBM Workflow Assistant secret YAML template"
#  mkdir -p $BAW_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > "${SECRET_FILE_FOLDER}/workflow-assistant-secrets.yaml"
# YAML template for ibm-workflow-assistant-secret secret
---
apiVersion: v1
kind: Secret
metadata:
  name: ibm-workflow-assistant-secrets
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    app.kubernetes.io/name: ibm-workflow-assistant-secrets
    cp4ba.ibm.com/backup-type: mandatory
type: Opaque
stringData:
  WATSONX_TOKEN: "$watsonx_token"
  WATSONX_API_KEY: "$watsonx_api_key"
  WATSONX_PASSWORD: "$watsonx_password"
  WATSONX_PROJECT_ID: "$watsonx_project_id"
  WATSONX_URL: "$watsonx_url"

EOF
  success "Created IBM Workflow Assistant secret YAML template\n"
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
    cp4ba.ibm.com/backup-type: mandatory
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
    cp4ba.ibm.com/backup-type: mandatory
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
    cp4ba.ibm.com/backup-type: mandatory
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
    cp4ba.ibm.com/backup-type: mandatory
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
  labels:
    cp4ba.ibm.com/backup-type: mandatory
type: Opaque
stringData:
  encryptionKey: <ENCRYPTION_KEY>

EOF
  success "Created encryption key secret YAML template\n"
}

### <https://jsw.ibm.com/browse/DBACLD-168159> - Added missing namespace parameters in secret yaml and update function to match other create secret template functions
# Function to create yaml file for ibm-ads-designer-database secret
function create_ads_decisiondesigner_secret_template(){
  local dbname=$1
  local dbserver=$2
  wait_msg "Creating Decision Intelligence Client Managed Software secret for decision designer YAML template"
  mkdir -p $ADS_SECRET_FOLDER >/dev/null 2>&1
  
cat << EOF > ${ADS_DESIGNER_FILE}
# YAML template for ibm-ads-designer-database secret
---
apiVersion: v1
kind: Secret
metadata:
  name: "ibm-ads-designer-database"
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
    cp4ba.ibm.com/backup-type: mandatory
type: Opaque
stringData:
  username: <DICMS_DESIGNER_DB_USERNAME>
  password: <DICMS_DESIGNER_DB_PASSWORD>
EOF

success "Created Decision Intelligence Client Managed Software secret for decision designer YAML template\n"
}

### <https://jsw.ibm.com/browse/DBACLD-168159> - Added missing namespace parameters in secret yaml and update function to match other create secret template functions
# Function to create yaml file for ibm-ads-runtime-database secret
function create_ads_decisionruntime_secret_template(){
  local dbname=$1
  local dbserver=$2
  wait_msg "Creating Decision Intelligence Client Managed Software secret for decision runtime YAML template"
  mkdir -p $ADS_SECRET_FOLDER >/dev/null 2>&1

cat << EOF > ${ADS_RUNTIME_FILE}
# YAML template for ibm-ads-runtime-database secret
---
apiVersion: v1
kind: Secret
metadata:
  name: "ibm-ads-runtime-database"
  namespace: "$CP4BA_SERVICES_NS"
  # DO NOT change the content of metadata.labels
  labels:
    db-server: $dbserver
    db-name: $dbname
    cp4ba.ibm.com/backup-type: mandatory
type: Opaque
stringData:
  username: <DICMS_RUNTIME_DB_USERNAME>
  password: <DICMS_RUNTIME_DB_USERNAME>
EOF

success "Created Decision Intelligence Client Managed Software secret for decision runtime YAML template\n"
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

  ${CLI_CMD} delete secret "ibm-zen-metastore-edb-secret" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "ibm-zen-metastore-edb-secret" --from-file=ca.crt="<cp4a-db-crt-file-in-local>/root.pem"\
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/client.pem"\
  --from-file=tls.key="<cp4a-db-crt-file-in-local>/client_key.pem"\
  --type=kubernetes.io/tls -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "ibm-zen-metastore-edb-secret" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"root.crt\" \"client.crt\" \"client.key\" into \"<cp4a-db-crt-file-in-local>\" first."
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
# Updated for issue https://jsw.ibm.com/browse/DBACLD-166239 with these 2 DATABASE_ENABLE_SSL,DATABASE_SSL_MODE parameters
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ibm-zen-metastore-edb-cm
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
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
  DATABASE_ENABLE_SSL: "true"
  DATABASE_SSL_MODE: require 
EOF
  success "Created ibm-zen-metastore-edb-cm configMap YAML template for Zen metastore external Postgres DB\n"
}

function create_im_external_db_secret_template(){
  wait_msg "Creating im-datastore-edb-secret secret YAML template for IM metastore external Postgres DB"

#DBACLD-193988: IM Vault integration - create secret template for IM metastore external Postgres DB with SSL enabled, the secret will be used to store the certificate/key files for SSL connection to external Postgres DB
if [[ $vault_enabled == "true" ]]; then
  create_im_datastore_edb_secret_vault_template "im-datastore-edb-secret" "$im_external_db_cert_folder"
else
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
  ${CLI_CMD} delete secret "im-datastore-edb-secret" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "im-datastore-edb-secret" --from-file=ca.crt="<cp4a-db-crt-file-in-local>/root.pem"\
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/client.pem"\
  --from-file=tls.key="<cp4a-db-crt-file-in-local>/client_key.pem"\
  --type=kubernetes.io/tls -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "im-datastore-edb-secret" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"root.crt\" \"client.crt\" \"client.key\" into \"<cp4a-db-crt-file-in-local>\" first."
  exit 1
fi
EOF
  success "Created im-datastore-edb-secret secret YAML template for IM metastore external Postgres DB\n"
  chmod 755 ${IM_SECRET_FILE}
fi
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
  labels:
    cp4ba.ibm.com/backup-type: mandatory
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

    # DBACLD-193988: BTS Vault integration - create secret template for BTS metastore external Postgres DB with SSL enabled, the secret will be used to store the certificate/key files for SSL connection to external Postgres DB
    
    # Setting this flag to true initially until overridden by vault_enabled flag
    bts_create_k8_secret="true"

    # --------------------------------------------------
    # IMPORTANT TODO: 
    # As a temporary measure, we need to create both K8s secret and Vault for BTS metastore external Postgres DB
    # Uncomment these 3 lines below once we get BTS Operator that supports Vault for the DB secret 
    # --------------------------------------------------
    if [ "$vault_enabled" == "true" ]; then
        bts_create_k8_secret="false"
    fi
    
    if [[ $vault_enabled == "true" ]]; then
        # Create template for Vault
        create_bts_datastore_edb_secret_vault_template "bts-datastore-edb-secret" "$bts_external_db_cert_folder"
    fi

    if [[ $bts_create_k8_secret == "true" ]]; then # Non-Vault
        mkdir -p $BTS_SECRET_FOLDER >/dev/null 2>&1
        # Create template for K8s secret
        # For https://jsw.ibm.com/browse/DBACLD-238245 and https://jsw.ibm.com/browse/DBACLD-238566 we now need to update the bts-datastore-edb-secret template to have a different key
        # THe key tls.key will be replaced to be tls.pk8 as the client.key file that it stores is in pk8 format. With new Postgres drivers, if you name it tls.key it expects the the key cert to be in PEM format.
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
  ${CLI_CMD} delete secret "bts-datastore-edb-secret" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "bts-datastore-edb-secret" --from-file=ca.crt="<cp4a-db-crt-file-in-local>/root.pem"\
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/client.pem"\
  --from-file=tls.pk8="<cp4a-db-crt-file-in-local>/tls_key.pk8" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "bts-datastore-edb-secret" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"root.crt\" \"client.crt\" \"client.key\" into \"<cp4a-db-crt-file-in-local>\" first."
  exit 1
fi
EOF
        chmod 755 ${BTS_SSL_SECRET_FILE}

        ${SED_COMMAND} "s|<cp4a-db-crt-file-in-local>|$bts_external_db_cert_folder|g" ${BTS_SSL_SECRET_FILE}

        success "Created bts-datastore-edb-secret secret YAML template for BTS metastore external Postgres DB\n"
    fi

}

function create_bts_external_db_configmap_template(){
  wait_msg "Creating ibm-bts-config-extension configMap YAML template for BTS metastore external Postgres DB"
  # For https://jsw.ibm.com/browse/DBACLD-238245 and https://jsw.ibm.com/browse/DBACLD-238566 we now need to update the ibm-bts-config-extension template to have a different file path
  # THe key tls.key file path will be replaced end with tls.pk8 as the client.key file that it stores is in pk8 format. With new Postgres drivers, if you name it tls.key it expects the the key to be in PEM format.
  mkdir -p $BTS_SECRET_FOLDER >/dev/null 2>&1
cat << EOF > ${BTS_CONFIGMAP_FILE}
# YAML template for ibm-bts-config-extension configMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ibm-bts-config-extension
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
data:
  serverName: "<DatabaseHostName>"
  portNumber: "<DatabasePort>"
  databaseName: <DatabaseName>
  ssl: "true"
  sslMode: verify-ca
  sslSecretName: bts-datastore-edb-secret
  customPropertyName1: sslKey
  customPropertyValue1: "/opt/ibm/wlp/usr/shared/resources/security/db/tls.pk8"
  customPropertyName2: user
  customPropertyValue2: "<DatabaseUserName>"
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
  
  ${CLI_CMD} delete secret "ibm-cp4ba-tls-issuer-secret" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "ibm-cp4ba-tls-issuer-secret" --from-file=tls.crt="<cp4a-issuer-tls-crt-file-in-local>/tls.pem"\
  --from-file=tls.key="<cp4a-issuer-tls-crt-file-in-local>/tls_key.pem"\
  --type=kubernetes.io/tls -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "ibm-cp4ba-tls-issuer-secret" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"tls.crt\" and \"tls.key\" into \"<cp4a-issuer-tls-crt-file-in-local>\" first."
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
  labels:
    cp4ba.ibm.com/backup-type: mandatory
spec:
  ca:
    secretName: ibm-cp4ba-tls-issuer-secret
EOF
  success "Created cp4ba-tls-issuer Issuer YAML template for for Opensearch/Kafka\n"

}

# Create WatsonX LWE SSL secret template for enabled providers with SSL enabled
#
# Purpose:
#   Generates a shell script template that creates a Kubernetes secret containing
#   the SSL/TLS certificate for WatsonX Lightweight Engine (LWE) providers.
#
# Prerequisites:
#   - PARSED_PROVIDERS array must be populated (from parse_multi_provider_property_file)
#   - AI_SERVICES_SECRET_FOLDER must be defined (from common.sh)
#   - AI_SERVICES_SSL_SECRET_FILE must be defined (from common.sh)
#   - AI_SERVICES_SSL_SECRET_NAME must be defined (from common.sh)
#
# Behavior:
#   - Scans all providers to check if any LWE provider has SSL_ENABLED=true
#   - If no LWE providers with SSL, returns without creating anything
#   - If SSL is enabled, creates a shell script that:
#     * Validates the certificate file exists (lwe.crt)
#     * Creates/updates the Kubernetes secret with the certificate
#     * Labels the secret for backup
#
# Generated Secret:
#   - Name: watsonx-lwe-ssl-secret (from AI_SERVICES_SSL_SECRET_NAME)
#   - Type: generic
#   - Data: tls.crt (mounted from lwe.crt file)
#   - Label: cp4ba.ibm.com/backup-type=mandatory
#
# Certificate Requirements:
#   - File must be named 'lwe.crt'
#   - Must be placed in TLS_CERT_LOCATION folder
#   - Must be valid X.509 certificate
#
# Returns:
#   0 - Success (secret template created or skipped)
#
function create_watsonx_lwe_ssl_secret_template() {
    local provider_count=0
    local has_lwe_ssl=false
    
    # Count total providers by scanning PARSED_PROVIDERS array for PROVIDER_ID keys
    for key in "${!PARSED_PROVIDERS[@]}"; do
        if [[ "$key" =~ ^([0-9]+)_PROVIDER_ID$ ]]; then
            provider_count=$((provider_count + 1))
        fi
    done
    
    # Check if any enabled LWE provider has SSL enabled
    for ((i=1; i<=provider_count; i++)); do
        local provider_name="${PARSED_PROVIDERS[${i}_PROVIDER_NAME]}"
        local provider_enabled="${PARSED_PROVIDERS[${i}_ENABLED]}"
        local ssl_enabled="${PARSED_PROVIDERS[${i}_SSL_ENABLED]}"
        
        if [[ "$provider_enabled" == "true" ]] && [[ "$provider_name" == "watsonx_lightweightengine" ]] && [[ "$ssl_enabled" == "true" ]]; then
            has_lwe_ssl=true
            break
        fi
    done
    
    # Skip secret creation if no LWE providers have SSL enabled
    if [[ "$has_lwe_ssl" == "false" ]]; then
        return 0
    fi
    
    # Create secret folder if it doesn't exist
    mkdir -p "$AI_SERVICES_SECRET_FOLDER" >/dev/null 2>&1
    
    # Get the TLS_CERT_LOCATION from the first enabled LWE provider with SSL
    # All LWE providers share the same SSL secret, so we only need one certificate location
    local cert_location=""
    for ((i=1; i<=provider_count; i++)); do
        local provider_name="${PARSED_PROVIDERS[${i}_PROVIDER_NAME]}"
        local provider_enabled="${PARSED_PROVIDERS[${i}_ENABLED]}"
        local ssl_enabled="${PARSED_PROVIDERS[${i}_SSL_ENABLED]}"
        
        if [[ "$provider_enabled" == "true" ]] && [[ "$provider_name" == "watsonx_lightweightengine" ]] && [[ "$ssl_enabled" == "true" ]]; then
            cert_location="${PARSED_PROVIDERS[${i}_TLS_CERT_LOCATION]}"
            break
        fi
    done
    
    # Generate the shell script that will create the SSL secret
    # This script is executed by the user after placing the certificate file
    cat << EOF > "${AI_SERVICES_SSL_SECRET_FILE}"
#!/bin/bash
# Shell template for WatsonX LWE SSL certificate secret creation
#
# Purpose: Creates a Kubernetes secret containing the SSL/TLS certificate
#          for WatsonX Lightweight Engine (LWE) providers
#
# Prerequisites:
#   - Certificate file 'lwe.crt' must exist in: $cert_location
#   - User must have permissions to create secrets in namespace: $NAMESPACE
#
# Usage:
#   1. Place your LWE certificate as 'lwe.crt' in: $cert_location
#   2. Run this script: ./watsonx-lwe-ssl-secret.sh
#
# Secret Details:
#   - Name: ${AI_SERVICES_SSL_SECRET_NAME}
#   - Type: generic
#   - Data: tls.crt (from lwe.crt file)
#   - Namespace: $NAMESPACE
#   - Label: cp4ba.ibm.com/backup-type=mandatory

if [[ -f "$cert_location/lwe.crt" ]]; then
  # Delete existing secret if present (allows updates)
  ${CLI_CMD} delete secret "${AI_SERVICES_SSL_SECRET_NAME}" -n "$NAMESPACE" >/dev/null 2>&1
  
  # Create new secret from certificate file
  ${CLI_CMD} create secret generic "${AI_SERVICES_SSL_SECRET_NAME}" --from-file=tls.crt="$cert_location/lwe.crt" -n "$NAMESPACE"
  
  # Label secret for backup
  ${CLI_CMD} label secret "${AI_SERVICES_SSL_SECRET_NAME}" cp4ba.ibm.com/backup-type=mandatory -n "$NAMESPACE"
  
  echo "Successfully created SSL secret: ${AI_SERVICES_SSL_SECRET_NAME}"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"lwe.crt\" into \"$cert_location\" first."
  exit 1
fi
EOF
    
    # Make the script executable
    chmod 755 "${AI_SERVICES_SSL_SECRET_FILE}"
}


# Generate the JSON-based providers configuration secret using jq
#
# Purpose:
#   Creates a Kubernetes secret YAML containing provider and model configurations
#   in JSON format. Supports multiple AI providers (WatsonX SaaS, WatsonX LWE, Azure)
#   with multiple models per provider.
#
# Prerequisites:
#   - PARSED_PROVIDERS array must be populated (from parse_multi_provider_property_file)
#   - PARSED_MODELS array must be populated (from parse_multi_provider_property_file)
#   - AI_SERVICES_SECRET_FOLDER must be defined (from common.sh)
#   - AI_SERVICES_SECRET_FILE must be defined (from common.sh)
#   - jq must be installed for JSON generation
#
# Secret Structure:
#   The generated secret contains a JSON configuration with:
#   - active_llm: Key of the default model (from model with DEFAULT=true)
#   - llms: Object containing all model configurations, keyed by "PROVIDER_ID_SANITIZED_MODEL_ID"
#          (special characters like /, -, . are removed from MODEL_ID)
#
# Model Configuration Fields (provider-specific):
#   Common to all:
#     - provider: Provider type ("watsonx" or "azure")
#     - model: Model identifier
#     - temperature: Sampling temperature (optional)
#     - max_completion_tokens: Max tokens to generate (optional)
#     - context_window_token_limit: Max context window size (optional)
#
#   WatsonX SaaS specific:
#     - deployment_mode: "saas"
#     - url: WatsonX API endpoint
#     - api_key: IBM Cloud API key
#     - space_id: Deployment space ID (optional)
#     - project_id: Project ID (optional)
#
#   WatsonX LWE specific:
#     - deployment_mode: "lightweight"
#     - url: CPD cluster URL
#     - instance_id: "openshift"
#     - version: "5.3"
#     - username: Zen username
#     - api_key: Zen API key (or password)
#     - verify_ssl: false or "/etc/certs/lwe/tls.crt" (if SSL enabled)
#     - ssl_secret_name: "watsonx-lwe-ssl-secret" (if SSL enabled)
#
#   Azure OpenAI specific:
#     - provider: "azure"
#     - endpoint: Azure OpenAI endpoint
#     - api_key: Azure API key
#     - use_entra_id: false
#     - timeout: 60
#     - api_version: "2024-12-01-preview"
#
# Behavior:
#   - Skips disabled providers (ENABLED=false)
#   - Validates credentials (API_KEY or PASSWORD for LWE)
#   - Builds JSON using jq for clean, maintainable code
#   - Generates unique keys for each model: "PROVIDER_ID_SANITIZED_MODEL_ID"
#     (e.g., "watsonx_openaigptoss120b" for model_id "openai/gpt-oss-120b")
#   - Sets active_llm from model with DEFAULT=true
#
# Returns:
#   0 - Success (secret created)
#   1 - Failure (jq not found or other error)
#
function generate_multi_provider_secret() {
    # Create secret folder if it doesn't exist
    mkdir -p "$AI_SERVICES_SECRET_FOLDER" >/dev/null 2>&1
    
    # Count total providers by scanning PARSED_PROVIDERS array
    local provider_count=0
    for key in "${!PARSED_PROVIDERS[@]}"; do
        if [[ "$key" =~ ^([0-9]+)_PROVIDER_ID$ ]]; then
            provider_count=$((provider_count + 1))
        fi
    done
    
    # Initialize variables for JSON building
    local active_llm_key=""      # Will be set from model with DEFAULT=true
    local llms_json="{}"          # Will contain all model configurations
    
    # Iterate through all providers
    for ((i=1; i<=provider_count; i++)); do
        # Extract provider configuration from PARSED_PROVIDERS array
        local provider_id="${PARSED_PROVIDERS[${i}_PROVIDER_ID]}"
        local provider_name="${PARSED_PROVIDERS[${i}_PROVIDER_NAME]}"
        local provider_enabled="${PARSED_PROVIDERS[${i}_ENABLED]}"
        local provider_url="${PARSED_PROVIDERS[${i}_PROVIDER_URL]}"
        local api_key="${PARSED_PROVIDERS[${i}_API_KEY]}"
        local username="${PARSED_PROVIDERS[${i}_USERNAME]}"
        local password="${PARSED_PROVIDERS[${i}_PASSWORD]}"
        local space_id="${PARSED_PROVIDERS[${i}_SPACE_ID]}"
        local project_id="${PARSED_PROVIDERS[${i}_PROJECT_ID]}"
        local ssl_enabled="${PARSED_PROVIDERS[${i}_SSL_ENABLED]}"
        local tls_cert_location="${PARSED_PROVIDERS[${i}_TLS_CERT_LOCATION]}"
        
        # Skip disabled providers (allows temporary disabling without deletion)
        if [[ "$provider_enabled" != "true" ]]; then
            continue
        fi
        
        # Validate authentication credentials based on provider type
        # LWE: Supports both API_KEY (preferred) and PASSWORD
        # SaaS/Azure: Requires API_KEY only
        if [[ "$provider_name" == "watsonx_lightweightengine" ]]; then
            if [[ -n "$api_key" && "$api_key" != "<Required>" ]]; then
                password=""  # Clear password if API_KEY is provided (API_KEY takes precedence)
            elif [[ -n "$password" && "$password" != "<Required>" ]]; then
                api_key=""   # Clear API_KEY if only PASSWORD is provided
            else
                warning "Skipping provider $provider_id: Neither API_KEY nor PASSWORD provided for LWE"
                continue
            fi
        else
            # SaaS and Azure require API_KEY
            if [[ -z "$api_key" || "$api_key" == "<Required>" ]]; then
                warning "Skipping provider $provider_id: API key not provided"
                continue
            fi
        fi
        
        # Count models for this provider by scanning PARSED_MODELS array
        local model_count=0
        for model_key in "${!PARSED_MODELS[@]}"; do
            if [[ "$model_key" =~ ^${i}_([0-9]+)_MODEL_ID$ ]]; then
                model_count=$((model_count + 1))
            fi
        done
        
        # Generate entries for each model using jq
        for ((m=1; m<=model_count; m++)); do
            local model_id="${PARSED_MODELS[${i}_${m}_MODEL_ID]}"
            local model_default="${PARSED_MODELS[${i}_${m}_DEFAULT]}"
            local temperature="${PARSED_MODELS[${i}_${m}_TEMPERATURE]}"
            local max_tokens="${PARSED_MODELS[${i}_${m}_MAX_TOKENS]}"
            local context_window_token_limit="${PARSED_MODELS[${i}_${m}_CONTEXT_WINDOW_TOKEN_LIMIT]}"
            
            # Generate unique key by concatenating provider_id with sanitized model_id
            # Remove special characters (/, -, ., etc.) from model_id for the key
            local sanitized_model_id=$(echo "$model_id" | tr -d '/-.')
            local llm_key="${provider_id}_${sanitized_model_id}"
            
            # Track default model
            if [[ "$model_default" == "true" ]]; then
                active_llm_key="$llm_key"
            fi
            
            # Build model configuration using jq based on provider type
            local model_json=""
            case "$provider_name" in
                azure)
                    model_json=$(jq -n \
                        --arg provider "azure" \
                        --arg endpoint "$provider_url" \
                        --arg model "$model_id" \
                        --arg api_key "$api_key" \
                        --argjson use_entra_id false \
                        --argjson timeout 60 \
                        --arg api_version "2024-12-01-preview" \
                        '{
                            provider: $provider,
                            endpoint: $endpoint,
                            model: $model,
                            api_key: $api_key,
                            use_entra_id: $use_entra_id,
                            timeout: $timeout,
                            api_version: $api_version
                        }' | \
                        if [[ -n "$max_tokens" && "$max_tokens" != "0" ]]; then
                            jq --argjson max_tokens "$max_tokens" '. + {max_completion_tokens: $max_tokens}'
                        else
                            cat
                        fi | \
                        if [[ -n "$temperature" ]]; then
                            jq --argjson temperature "$temperature" '. + {temperature: $temperature}'
                        else
                            cat
                        fi | \
                        if [[ -n "$context_window_token_limit" ]]; then
                            jq --argjson context_window_token_limit "$context_window_token_limit" '. + {context_window_token_limit: $context_window_token_limit}'
                        else
                            cat
                        fi
                    )
                    ;;
                    
                watsonx_saas)
                    model_json=$(jq -n \
                        --arg provider "watsonx" \
                        --arg deployment_mode "saas" \
                        --arg url "$provider_url" \
                        --arg api_key "$api_key" \
                        --arg model "$model_id" \
                        '{
                            provider: $provider,
                            deployment_mode: $deployment_mode,
                            url: $url,
                            api_key: $api_key,
                            model: $model
                        }' | \
                        if [[ -n "$space_id" ]]; then
                            jq --arg space_id "$space_id" '. + {space_id: $space_id}'
                        else
                            cat
                        fi | \
                        if [[ -n "$project_id" ]]; then
                            jq --arg project_id "$project_id" '. + {project_id: $project_id}'
                        else
                            cat
                        fi | \
                        if [[ -n "$max_tokens" ]]; then
                            jq --argjson max_tokens "$max_tokens" '. + {max_completion_tokens: $max_tokens}'
                        else
                            cat
                        fi | \
                        if [[ -n "$temperature" ]]; then
                            jq --argjson temperature "$temperature" '. + {temperature: $temperature}'
                        else
                            cat
                        fi | \
                        if [[ -n "$context_window_token_limit" ]]; then
                            jq --argjson context_window_token_limit "$context_window_token_limit" '. + {context_window_token_limit: $context_window_token_limit}'
                        else
                            cat
                        fi
                    )
                    ;;
                    
                watsonx_lightweightengine)
                    model_json=$(jq -n \
                        --arg provider "watsonx" \
                        --arg deployment_mode "lightweight" \
                        --arg url "$provider_url" \
                        --arg instance_id "openshift" \
                        --arg version "5.3" \
                        --arg model "$model_id" \
                        '{
                            provider: $provider,
                            deployment_mode: $deployment_mode,
                            url: $url,
                            instance_id: $instance_id,
                            version: $version,
                            model: $model
                        }' | \
                        if [[ -n "$username" ]]; then
                            jq --arg username "$username" '. + {username: $username}'
                        else
                            cat
                        fi | \
                        if [[ -n "$api_key" ]]; then
                            jq --arg api_key "$api_key" '. + {api_key: $api_key}'
                        elif [[ -n "$password" ]]; then
                            jq --arg password "$password" '. + {password: $password}'
                        else
                            cat
                        fi | \
                        if [[ "$ssl_enabled" == "true" ]]; then
                            jq --arg verify_ssl "/etc/certs/lwe/tls.crt" \
                               --arg ssl_secret_name "watsonx-lwe-ssl-secret" \
                               '. + {verify_ssl: $verify_ssl, ssl_secret_name: $ssl_secret_name}'
                        else
                            jq --argjson verify_ssl false '. + {verify_ssl: $verify_ssl}'
                        fi | \
                        if [[ -n "$max_tokens" ]]; then
                            jq --argjson max_tokens "$max_tokens" '. + {max_completion_tokens: $max_tokens}'
                        else
                            cat
                        fi | \
                        if [[ -n "$temperature" ]]; then
                            jq --argjson temperature "$temperature" '. + {temperature: $temperature}'
                        else
                            cat
                        fi | \
                        if [[ -n "$context_window_token_limit" ]]; then
                            jq --argjson context_window_token_limit "$context_window_token_limit" '. + {context_window_token_limit: $context_window_token_limit}'
                        else
                            cat
                        fi
                    )
                    ;;
            esac
            
            # Add model to llms object
            llms_json=$(echo "$llms_json" | jq --arg key "$llm_key" --argjson value "$model_json" '. + {($key): $value}')
        done
    done
    
    # Build final JSON
    local json_content=$(jq -n \
        --arg active_llm "$active_llm_key" \
        --argjson llms "$llms_json" \
        '{active_llm: $active_llm, llms: $llms}')
    
    # Create the secret YAML
    cat > "$AI_SERVICES_SECRET_FILE" << EOF
# YAML template for ibm-providers-config-secret
---
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: ibm-providers-config-secret
  namespace: "$NAMESPACE"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
stringData:
  providers_config.json: |
$(echo "$json_content" | sed 's/^/    /')
EOF
}