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
#DBACLD-185209: Vault implementation
function create_ldap_secret_vault_template(){
  wait_msg "Creating ldap-bind-secret secret JSON template for Vault"
  mkdir -p $VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _ldap_bind_dn=${1}
  local _ldap_password=${2}
  local _vault_address=${3}
  local _vault_role=${4}
  local _vault_path=${5}

cat << EOF > "${VAULT_LDAP_SECRET_FILE}"
{
  "_comment": "Create a ldap-bind-secret for Vault (eg: vault kv put <path>/ldap-bind-secret @${VAULT_LDAP_SECRET_FILE}).  The name should be ldap-bind-secret and it must match with the name of the ldap-bind-secret-provider-class.yaml. Optionally, this property, _comment, can be removed before creating the secret.",
  "ldapUsername": "${_ldap_bind_dn}",
  "ldapPassword": "${_ldap_password}"
}
EOF

cat << EOF > "${VAULT_LDAP_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for ldap-bind-secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: ldap-bind-secret)
# The keys in this template should match with the keys in the ldap-bind-secret JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: ldap-bind-secret             
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    name: ldap-bind-secret
spec:
  provider: vault                           
  parameters:                               
    roleName: "$_vault_role"
    vaultAddress: "$_vault_address"
    objects:  |
      - secretPath: "$_vault_path/ldap-bind-secret"
        objectName: "ldapUsername"
        secretKey: "ldapUsername"
      - secretPath: "$_vault_path/ldap-bind-secret"
        objectName: "ldapPassword"
        secretKey: "ldapPassword"
EOF

#Create SecretProviderClass for ldap-bind-secret for separation of duties deployment
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for ldap-bind-secret in namespace $CP4BA_OPERATOR_NS"
  cp "${VAULT_LDAP_SECRET_PROVIDER_CLASS_FILE}.yaml" "${VAULT_LDAP_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${VAULT_LDAP_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi

  success "Created ldap-bind-secret secret JSON template and SecretProviderClass template for Vault\n"
}

#This function read the content of propertyfile/ldap/ldap-cert.crt and generate the Json and the SecretProviderClass
function create_ldap_tls_secret_vault_template(){
  wait_msg "Creating ldap-bind-secret-tls secret JSON template for Vault"
  mkdir -p $VAULT_LDAP_SECRET_TLS_FOLDER >/dev/null 2>&1  
  local _vault_address=$1
  local _vault_role=$2
  local _vault_path=$3
  local _ldap_secret_name=$4
  local _ldap_secret_folder=$5
   
  _ldap_tls_content=$(<${_ldap_secret_folder}/ldap-cert.crt)
  # Remove carriage returns and convert multi-line certificate to single line with \n escape sequences
  _ldap_tls_content=$(echo "$_ldap_tls_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  
cat << EOF > "${VAULT_LDAP_SECRET_TLS_FILE}"
{
  "_comment": "Create a $_ldap_secret_name for Vault (eg: vault kv put <path>/$_ldap_secret_name @${VAULT_LDAP_SECRET_TLS_FILE}).  The name should match with the LDAP_SSL_SECRET_NAME property in cp4ba_LDAP.property file. Optionally, this property, _comment, can be removed before creating the secret.",
  "tls.crt": "${_ldap_tls_content}"
}
EOF

cat << EOF > "${VAULT_LDAP_SECRET_TLS_PROVIDER_CLASS_FILE}.yaml"
# YAML template for ldap-bind-tls-secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_ldap_secret_name)
# The keys in this template should match with the keys in the $_ldap_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_ldap_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
spec:
  provider: vault
  parameters:
    roleName: "$_vault_role"
    vaultAddress: "$_vault_address"
    objects:  |
      - secretPath: "$_vault_path/$_ldap_secret_name"
        objectName: "tls.crt"
        secretKey: "tls.crt"
EOF

#Create SecretProviderClass for LDAP TLS certificate for separation of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for LDAP TLS certificate in namespace $CP4BA_OPERATOR_NS"
  cp "${VAULT_LDAP_SECRET_TLS_PROVIDER_CLASS_FILE}.yaml" "${VAULT_LDAP_SECRET_TLS_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${VAULT_LDAP_SECRET_TLS_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi

  success "Created $_ldap_secret_name secret JSON template and SecretProviderClass template for Vault\n"
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

#DBACLD-185209: Vault's implementation.  Define ibm-fncm-secret for Vault

function create_fncm_secret_vault_template(){
  mkdir -p $FNCM_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _vault_address=${1}
  local _vault_role=${2}
  local _vault_path=${3}
  local _tmp_gcd_db_servername=${4}
  local _fncm_secret_name="ibm-fncm-secret"

  # Build conditional sections for OS databases
  local os_sections=""
  local os_secretprovider_sections=""
  
  # Get content OS number from property file
  local content_os_number
  content_os_number=$(prop_tmp_property_file CONTENT_OS_NUMBER)
  
  # Call helper function and capture output
  local os_result
  os_result=$(add_content_os_dynamically "true" "$content_os_number" "$_vault_path" "$_fncm_secret_name")
  
  # Parse the output using awk to extract sections properly
  os_sections=$(echo "$os_result" | awk '/###OS_SECTIONS_START###/{flag=1;next}/###OS_SECTIONS_END###/{flag=0}flag')
  os_secretprovider_sections=$(echo "$os_result" | awk '/###OS_SECRETPROVIDER_SECTIONS_START###/{flag=1;next}/###OS_SECRETPROVIDER_SECTIONS_END###/{flag=0}flag')
  
  # Debug: show what was parsed
  # echo "DEBUG - Parsed os_sections: '$os_sections'"
  # echo "DEBUG - Parsed os_secretprovider_sections: '$os_secretprovider_sections'"

  # Get main GCD database info
  tmp_gcd_db_servername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
  tmp_gcd_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_gcd_db_servername")
  
  # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER for GCD
  local gcd_postgresql_client_flag=""
  if [[ $DB_TYPE = "postgresql" ]]; then
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_gcd_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
    gcd_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
  fi
  
  if [[ $DB_TYPE = "postgresql-edb" ]]; then
    gcd_postgresql_client_flag="true"
  fi
  
  # Get GCD credentials
  tmp_appuser="$(prop_user_profile_property_file CONTENT.APPLOGIN_USER)"
  tmp_apppwd="$(prop_user_profile_property_file CONTENT.APPLOGIN_PASSWORD)"
  tmp_ltpapwd="$(prop_user_profile_property_file CONTENT.LTPA_PASSWORD)"
  tmp_kestorepwd="$(prop_user_profile_property_file CONTENT.KEYSTORE_PASSWORD)"
  tmp_gcd_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
  tmp_gcd_dbuserpwd="$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)"

  # Build GCD password section for JSON
  local gcd_password_section=""
  if [[ ! ("$gcd_postgresql_client_flag" == "true" || "$gcd_postgresql_client_flag" == "yes" || "$gcd_postgresql_client_flag" == "y") ]]; then
    gcd_password_section=",
  \"gcdDBPassword\": \"$tmp_gcd_dbuserpwd\""
  fi

  # Build GCD password section for SecretProviderClass
  local gcd_secretprovider_section=""
  if [[ ! ("$gcd_postgresql_client_flag" == "true" || "$gcd_postgresql_client_flag" == "yes" || "$gcd_postgresql_client_flag" == "y") ]]; then
    gcd_secretprovider_section="
      - secretPath: \"$_vault_path/$_fncm_secret_name\"
        objectName: \"gcdDBPassword\"
        secretKey: \"gcdDBPassword\""
  fi

  # Create JSON template using pre-built strings
  cat << EOF > "${FNCM_VAULT_SECRET_FILE}"
{
  "_comment": "Create a $_fncm_secret_name for Vault (eg: vault kv put <path>/$_fncm_secret_name @${FNCM_VAULT_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  "appLoginUsername": "$tmp_appuser",
  "appLoginPassword": "$tmp_apppwd",
  "gcdDBUsername": "$tmp_gcd_dbuser"${gcd_password_section}${os_sections},
  "ltpaPassword": "$tmp_ltpapwd",
  "keystorePassword": "$tmp_kestorepwd"
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"

# YAML template for ibm-fncm-secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_fncm_secret_name)
# The keys in this template should match with the keys in the $_fncm_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_fncm_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    gcd-db-server: $_tmp_gcd_db_servername
    db-name: ibm-fncm-secret
    cp4ba.ibm.com/backup-type: mandatory
spec:
  provider: vault
  parameters:
    roleName: "$_vault_role"
    vaultAddress: "$_vault_address"
    objects:  |
      - secretPath: "$_vault_path/$_fncm_secret_name"
        objectName: "appLoginUsername"
        secretKey: "appLoginUsername"
      - secretPath: "$_vault_path/$_fncm_secret_name"
        objectName: "appLoginPassword"
        secretKey: "appLoginPassword"
      - secretPath: "$_vault_path/$_fncm_secret_name"
        objectName: "gcdDBUsername"
        secretKey: "gcdDBUsername"${gcd_secretprovider_section}${os_secretprovider_sections}
      - secretPath: "$_vault_path/$_fncm_secret_name"
        objectName: "ltpaPassword"
        secretKey: "ltpaPassword"
      - secretPath: "$_vault_path/$_fncm_secret_name"
        objectName: "keystorePassword"
        secretKey: "keystorePassword"
EOF

#Create SecretProviderClass for DB SSL certificate for separation of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for DB SSL certificate in namespace $CP4BA_OPERATOR_NS"
  cp "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${FNCM_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi

  success "Created $_fncm_secret_name secret JSON template and SecretProviderClass template for Vault\n"
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

#DBACLD-185209: Vault's implementation for DB SSL
function create_cp4a_db_ssl_vault_template(){
  wait_msg "Creating database SSL certificate JSON template for Vault"
  local _vault_address=${1}
  local _vault_role=${2}
  local _vault_path=${3}
  local _dbserver=${4}
  local _tmp_ssl_secret_name=${5}
  local _tmp_cert_folder_name=${6}
  local _tmp_ssl_client_server=${7}
  local _tmp_pg_ssl_mode=${8}

  mkdir -p $DB_VAULT_SECRET_FILE_FOLDER/$_dbserver >/dev/null 2>&1
  local DB_VAULT_SECRET_FILE=${DB_VAULT_SECRET_FILE_FOLDER}/$_dbserver/ibm-cp4ba-db-ssl-cert-secret-for-${_dbserver}.json
  local DB_VAULT_SECRET_PROVIDER_CLASS_FILE=${DB_VAULT_SECRET_FILE_FOLDER}/$_dbserver/ibm-cp4ba-db-ssl-cert-secret-for-${_dbserver}-provider-class

  # Build JSON content based on database type and SSL configuration
  local json_content=""
  local provider_objects=""

  if [[ $DB_TYPE != "postgresql" ]]; then
    # For DB2, Oracle, SQL Server - use tls.crt and cacert.crt
    local tls_cert_content=$(<${_tmp_cert_folder_name}/db-cert.crt)
    local cacert_content=$(<${_tmp_cert_folder_name}/db-cert.crt)
    
    # Remove carriage returns and convert multi-line certificates to single line with escaped newlines
    tls_cert_content=$(echo "$tls_cert_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    cacert_content=$(echo "$cacert_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

    json_content='"tls.crt": "'$tls_cert_content'",
  "cacert.crt": "'$cacert_content'"'
    
    provider_objects='      - secretPath: "'$_vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "tls.crt"
        secretKey: "tls.crt"
      - secretPath: "'$_vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "cacert.crt"
        secretKey: "cacert.crt"'

  # Postgres with no client_server
  elif [[ $DB_TYPE == "postgresql" && ($_tmp_ssl_client_server == "no" || $_tmp_ssl_client_server == "false" || $_tmp_ssl_client_server == "" || -z $_tmp_ssl_client_server) ]]; then
    # For PostgreSQL with SSL but no client authentication - use tls.crt and serverca.pem
    local tls_cert_content=$(<${_tmp_cert_folder_name}/db-cert.crt)
    local serverca_content=$(<${_tmp_cert_folder_name}/db-cert.crt)
    
    # Remove carriage returns and convert multi-line certificates to single line with escaped newlines
    tls_cert_content=$(echo "$tls_cert_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    serverca_content=$(echo "$serverca_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

    json_content='"tls.crt": "'$tls_cert_content'",
  "serverca.pem": "'$serverca_content'"'
    
    provider_objects='      - secretPath: "'$_vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "tls.crt"
        secretKey: "tls.crt"
      - secretPath: "'$_vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "serverca.pem"
        secretKey: "serverca.pem"'
  
  else # Postgres with client server
    # For PostgreSQL with SSL client authentication - use tls.crt, ca.crt, tls.key, and sslmode
    local tls_cert_content=$(<${_tmp_cert_folder_name}/client.crt)
    local ca_cert_content=$(<${_tmp_cert_folder_name}/root.crt)
    local tls_key_content=$(<${_tmp_cert_folder_name}/client.key)
    
    # Remove carriage returns and convert multi-line certificates to single line with escaped newlines
    tls_cert_content=$(echo "$tls_cert_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    ca_cert_content=$(echo "$ca_cert_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    tls_key_content=$(echo "$tls_key_content" | tr -d '\r' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    # Use provided SSL mode or default to verify-full
    local ssl_mode=${_tmp_pg_ssl_mode:-"verify-full"}
    
    json_content='"tls.crt": "'$tls_cert_content'",
  "ca.crt": "'$ca_cert_content'",
  "tls.key": "'$tls_key_content'",
  "sslmode": "'$ssl_mode'"'
    
    provider_objects='      - secretPath: "'$_vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "tls.crt"
        secretKey: "tls.crt"
      - secretPath: "'$_vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "ca.crt"
        secretKey: "ca.crt"
      - secretPath: "'$_vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "tls.key"
        secretKey: "tls.key"
      - secretPath: "'$_vault_path'/'$_tmp_ssl_secret_name'"
        objectName: "sslmode"
        secretKey: "sslmode"'
  fi

  # Create JSON template
  cat << EOF > ${DB_VAULT_SECRET_FILE}
{
  "_comment": "Create a $_tmp_ssl_secret_name for Vault (eg: vault kv put <path>/$_tmp_ssl_secret_name @${DB_VAULT_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  $json_content
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${DB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_tmp_ssl_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_tmp_ssl_secret_name)
# The keys in this template should match with the keys in the $_tmp_ssl_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_tmp_ssl_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
spec:
  provider: vault
  parameters:
    roleName: "$_vault_role"
    vaultAddress: "$_vault_address"
    objects:  |
$provider_objects
EOF

#Create SecretProviderClass for DB SSL certificate for separation of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for DB SSL certificate in namespace $CP4BA_OPERATOR_NS"
  cp "${DB_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${DB_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${DB_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi

  success "Created $_tmp_ssl_secret_name SSL certificate JSON template for Vault\n"

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
stringData:
  archiveUserId: "<ARCHIVE_USERID>"
  archivePassword: "<ARCHIVE_PASSWORD>"
EOF
}

#DBACLD-185209: Vault's implementation for ibm-icc-secret

function create_fncm_icc_secret_vault_template(){

  mkdir -p $FNCM_ICC_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _vault_address=${1}
  local _vault_role=${2}
  local _vault_path=${3}
  local _archive_id=${4}
  local _archive_pwd=${5}
  local _fncm_icc_secret_name="ibm-icc-secret"

  # Create JSON template
  cat << EOF > ${FNCM_ICC_VAULT_SECRET_FILE}
{
  "_comment": "Create a $_fncm_icc_secret_name for Vault (eg: vault kv put <path>/$_fncm_icc_secret_name @${FNCM_ICC_VAULT_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  "archiveUserId": "$_archive_id",
  "archivePassword": "$_archive_pwd"
}
EOF

  # Create SecretProviderClass template
  cat << EOF > "${FNCM_ICC_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"
# YAML template for $_fncm_icc_secret_name SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_fncm_icc_secret_name)
# The keys in this template should match with the keys in the $_fncm_icc_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_fncm_icc_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
spec:
  provider: vault
  parameters:
    roleName: "$_vault_role"
    vaultAddress: "$_vault_address"
    objects:  |
      - secretPath: "$_vault_path/$_fncm_icc_secret_name"
        objectName: "archiveUserId"
        secretKey: "archiveUserId"
      - secretPath: "$_vault_path/$_fncm_icc_secret_name"
        objectName: "archivePassword"
        secretKey: "archivePassword"
EOF

#Create SecretProviderClass for FNCM ICC secret for separtion of duty
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for FNCM ICC secret in namespace $CP4BA_OPERATOR_NS"
  cp "${FNCM_ICC_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${FNCM_ICC_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${FNCM_ICC_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi
  success "Created $_fncm_icc_secret_name JSON template and SecretProviderClass template for Vault\n"
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

#DBACLD-185209: Vault's implementation.  Define ibm-ban-secret for Vault
function create_ban_secret_vault_template() {
  wait_msg "Creating ibm-ban-secret JSON template for Vault"
  mkdir -p $BAN_VAULT_SECRET_FILE_FOLDER >/dev/null 2>&1
  local _vault_address=${1}
  local _vault_role=${2}
  local _vault_path=${3}
  local _app_login_user=${4}
  local _app_login_pwd=${5}
  local _icn_db_user=${6}
  local _icn_db_pwd=${7}
  local _jmail_user=${8}
  local _jmail_pwd=${9}
  local _ltpa_pwd=${10}
  local _keystore_pwd=${11}
  local _pg_client_flag=${12}
  local _db_server=${13}
  local _db_name=${14}
  local _ban_secret_name="ibm-ban-secret"

  # Build conditional sections as variables first
  # Only create this section when it's NOT EDB
  local icn_pwd_section=""
  if [[ ! ("$_pg_client_flag" == "true" || "$_pg_client_flag" == "yes" || "$_pg_client_flag" == "y") ]]; then
    icn_pwd_section=',
  "navigatorDBPassword": "'$_icn_db_pwd'"'
  fi
  
  # Only create this section when jmail user and jmail password are not <Optional>
  local jmail_section=""
  if [[ ! ("$_jmail_user" == "<Optional>" || "$_jmail_pwd" == "<Optional>" || -z "$_jmail_user" || -z "$_jmail_pwd") ]]; then
    jmail_section=',
  "jMailUsername": "'$_jmail_user'",
  "jMailPassword": "'$_jmail_pwd'"'
  fi

  # Create JSON template using pre-built strings
  cat << EOF > "${BAN_VAULT_SECRET_FILE}"
{
  "_comment": "Create a $_ban_secret_name for Vault (eg: vault kv put <path>/$_ban_secret_name @${BAN_VAULT_SECRET_FILE}). Optionally, this property, _comment, can be removed before creating the secret.",
  "appLoginUsername": "$_app_login_user",
  "appLoginPassword": "$_app_login_pwd",
  "navigatorDBUsername": "$_icn_db_user"${icn_pwd_section}${jmail_section},
  "ltpaPassword": "$_ltpa_pwd",
  "keystorePassword": "$_keystore_pwd"
}
EOF

  # Build conditional sections for SecretProviderClass
  # Only create this section when it's NOT EDB
  local icn_pwd_secret_section=""
  if [[ ! ("$_pg_client_flag" == "true" || "$_pg_client_flag" == "yes" || "$_pg_client_flag" == "y") ]]; then
    icn_pwd_secret_section='
      - secretPath: "'$_vault_path'/'$_ban_secret_name'"
        objectName: "navigatorDBPassword"
        secretKey: "navigatorDBPassword"'
  fi
  
  # Only create this section when jmail user and jmail password are not <Optional>
  local jmail_secret_section=""
  if [[ ! ("$_jmail_user" == "<Optional>" || "$_jmail_pwd" == "<Optional>" || -z "$_jmail_user" || -z "$_jmail_pwd") ]]; then
    jmail_secret_section='
      - secretPath: "'$_vault_path'/'$_ban_secret_name'"
        objectName: "jMailUsername"
        secretKey: "jMailUsername"
      - secretPath: "'$_vault_path'/'$_ban_secret_name'"
        objectName: "jMailPassword"
        secretKey: "jMailPassword"'
  fi

  # Create SecretProviderClass template using pre-built strings
  cat << EOF > "${BAN_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml"

# YAML template for ibm-ban-secret SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_ban_secret_name)
# The keys in this template should match with the keys in the $_ban_secret_name JSON template
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_ban_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
    db-server: "$_db_server"
    db-name: "$_db_name"
spec:
  provider: vault
  parameters:
    roleName: "$_vault_role"
    vaultAddress: "$_vault_address"
    objects:  |
      - secretPath: "$_vault_path/$_ban_secret_name"
        objectName: "appLoginUsername"
        secretKey: "appLoginUsername"
      - secretPath: "$_vault_path/$_ban_secret_name"
        objectName: "appLoginPassword"
        secretKey: "appLoginPassword"
      - secretPath: "$_vault_path/$_ban_secret_name"
        objectName: "navigatorDBUsername"
        secretKey: "navigatorDBUsername"${icn_pwd_secret_section}${jmail_secret_section}
      - secretPath: "$_vault_path/$_ban_secret_name"
        objectName: "ltpaPassword"
        secretKey: "ltpaPassword"
      - secretPath: "$_vault_path/$_ban_secret_name"
        objectName: "keystorePassword"
        secretKey: "keystorePassword"
EOF

# Create SecretProviderClass for ibm-ban-secret for separation of duties
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for ibm-ban-secret in namespace $CP4BA_OPERATOR_NS"
  cp "${BAN_VAULT_SECRET_PROVIDER_CLASS_FILE}.yaml" "${BAN_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${BAN_VAULT_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}.yaml"
fi

  success "Created $_ban_secret_name secret JSON template and SecretProviderClass template for Vault\n"
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
  ${CLI_CMD} label secret "<ban-db-ssl-secret-name>" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
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

    if [[ ${#db_name_array[@]} != ${#db_user_array[@]} || ${#db_user_array[@]} != ${#db_userpwd_array[@]} ]]; then
        fail "The number of values of: ADP_PROJECT_DB_NAME, ADP_PROJECT_DB_USER_NAME, ADP_PROJECT_DB_USER_PASSWORD must all be equal. Exit ..."
    else
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
            # Other DB types will still add the PROJ_DB_CONFIG passwords.
            if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
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
  wait_msg "Creating Automation Decision Services secret for decision designer YAML template"
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
  username: <ADS_DESIGNER_DB_USERNAME>
  password: <ADS_DESIGNER_DB_PASSWORD>
EOF

success "Created Automation Decision Services secret for decision designer YAML template\n"
}

### <https://jsw.ibm.com/browse/DBACLD-168159> - Added missing namespace parameters in secret yaml and update function to match other create secret template functions
# Function to create yaml file for ibm-ads-runtime-database secret
function create_ads_decisionruntime_secret_template(){
  local dbname=$1
  local dbserver=$2
  wait_msg "Creating Automation Decision Services secret for decision runtime YAML template"
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
  username: <ADS_RUNTIME_DB_USERNAME>
  password: <ADS_RUNTIME_DB_USERNAME>
EOF

success "Created Automation Decision Services secret for decision runtime YAML template\n"
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
  ${CLI_CMD} delete secret "bts-datastore-edb-secret" -n "$CP4BA_SERVICES_NS" >/dev/null 2>&1
  ${CLI_CMD} create secret generic "bts-datastore-edb-secret" --from-file=ca.crt="<cp4a-db-crt-file-in-local>/root.pem"\
  --from-file=tls.crt="<cp4a-db-crt-file-in-local>/client.pem"\
  --from-file=tls.key="<cp4a-db-crt-file-in-local>/tls_key.pk8" -n "$CP4BA_SERVICES_NS"
  ${CLI_CMD} label secret "bts-datastore-edb-secret" cp4ba.ibm.com/backup-type=mandatory -n "$CP4BA_SERVICES_NS"
else
  printf '%b\n' "\x1B[1;31m[FAILED]:\x1B[0m Please copy \"root.crt\" \"client.crt\" \"client.key\" into \"<cp4a-db-crt-file-in-local>\" first."
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
  customPropertyValue1: "/opt/ibm/wlp/usr/shared/resources/security/db/tls.key"
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

#DBACLD-185209: Vault's implementation.  Create optional CP4BA root-CA (root-ca).  KC link: https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/25.0.0?topic=tls-changing-default-root-ca-signer-certificate
# This function will genreate the JSON and SecretProviderClass all commented out as this is an optional secret
function create_cp4ba_root_ca_vault_template(){
  local _vault_address=${1}
  local _vault_path=${2}
  local _vault_role=${3}
  local _vault_secret_name=${4:-root-ca}

  mkdir -p $CP4A_ROOT_CA_FOLDER >/dev/null 2>&1
  cat << EOF > ${CP4A_ROOT_CA_SECRET_FILE}
{
  "_comment": "Optional custom CP4BA root CA certificate. Create a custom CP4BA root CA certificate with a name of root-ca.  This certificate will be used to sign other certificates.",
  "key": "<Content of custom root CA key in a single-line>",
  "cert": "<Content of custom root CA certificate in a single-line>"
}

EOF

cat << EOF > ${CP4A_ROOT_CA_SECRET_PROVIDER_CLASS_FILE}
# YAML template for OPTIONAL custom CP4BA root CA certificate SecretProviderClass
# metadata.name must match with the name of the secret created in Vault (eg: $_vault_secret_name), and match with shared_configuration.root_ca_secret
# The keys in this template should match with the keys in the $_vault_secret_name JSON template
# Rename the $CP4A_ROOT_CA_SECRET_PROVIDER_CLASS_FILE to $CP4A_ROOT_CA_SECRET_PROVIDER_CLASS_FILE.yaml to enable
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: "$_vault_secret_name"
  namespace: "$CP4BA_SERVICES_NS"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
spec:
  provider: vault
  parameters:
    roleName: "$_vault_role"
    vaultAddress: "$_vault_address"
    objects: |
      - secretPath: "$_vault_path/$_vault_secret_name"
        objectName: "key"
        secretKey: "key"
      - secretPath: "$_vault_path/$_vault_secret_name"
        objectName: "cert"
        secretKey: "cert"
EOF

#Create SecretProviderClass for OPTIONAL custom CP4BA root CA certificate when for separation of duties 
if [[ $SEPARATE_OPERAND_FLAG == "Yes" &&  $CP4BA_OPERATOR_NS != '' ]]; then
  info "Creating SecretProviderClass for root-ca in $CP4BA_OPERATOR_NS namespace"
  cp "${CP4A_ROOT_CA_SECRET_PROVIDER_CLASS_FILE}" "${CP4A_ROOT_CA_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}"
  #replace the namespace in the copied file
  ${SED_COMMAND} "s/namespace: \"$CP4BA_SERVICES_NS\"/namespace: \"$CP4BA_OPERATOR_NS\"/g" "${CP4A_ROOT_CA_SECRET_PROVIDER_CLASS_FILE}-${CP4BA_OPERATOR_NS}"
fi
success "Created OPTIONAL custom CP4BA root CA certificate template and SecretProviderClass template for Vault\n"
}
