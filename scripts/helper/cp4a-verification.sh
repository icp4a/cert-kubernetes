#!/bin/bash
# set -x
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

# Open file descriptor 3 for suppressing output
exec 3>/dev/null

function verify_storage_class_valid(){
  local STORAGE_CLASS_SAMPLE=$TEMP_FOLDER/.storage_sample.yaml
  local sc_name=$1
  local sc_mode=$2
  local sample_pvc_name=$3

cat << EOF > ${STORAGE_CLASS_SAMPLE}
# YAML template for sample storage class
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  labels:
    cp4ba: test-only
  name: ${sample_pvc_name}
spec:
  accessModes:
  - ${sc_mode}
  resources:
    requests:
      storage: 10Mi
  storageClassName: ${sc_name}
EOF
  
    # CREATE_PVC_CMD="kubectl apply -f ${STORAGE_CLASS_SAMPLE}"
    # if $CREATE_PVC_CMD ; then
    #     printf '%b\n' "\x1B[1mDone\x1B[0m"
    # else
    #     printf '%b\n' "\x1B[1;31mFailed\x1B[0m"
    # fi
   # Check Operator Persistent Volume status every 5 seconds (max 1 minutes) until allocate.
    ${CLI_CMD} apply -f ${STORAGE_CLASS_SAMPLE} >&3 2>&3
    ATTEMPTS=0
    TIMEOUT=12
    printf "\n"
    info "Checking the storage class: \"${sc_name}\"..."
    until ${CLI_CMD} get pvc | grep ${sample_pvc_name}| grep -q -m 1 "Bound" || [ $ATTEMPTS -eq $TIMEOUT ]; do
        ATTEMPTS=$((ATTEMPTS + 1))
        printf '%b\n' "......"
        sleep 5
        if [ $ATTEMPTS -eq $TIMEOUT ] ; then
            fail "Failed to allocate the persistent volumes using storage class: \"${sc_name}\"!"
            # info "Run the following command to check the claim 'kubectl describe pvc ${sample_pvc_name}'"
            verification_sc_passed="No"
        fi
    done
    if [ $ATTEMPTS -lt $TIMEOUT ] ; then
            success "Verification storage class: \"${sc_name}\", PASSED!"
            verification_sc_passed="Yes"
            printf "\n"
    fi
    #DBACLD-197700: Clean up sample PVC regardless of pass or fail
    ${CLI_CMD} delete -f ${STORAGE_CLASS_SAMPLE} >&3 2>&3
    rm -rf ${STORAGE_CLASS_SAMPLE} >&3 2>&3
}
# https://jsw.ibm.com/browse/DBACLD-181735
# convert and verify the certificate
function verify_and_convert_cert() {
    local db_cert="$1"
    local db_der="$2"

    # Step 1: Convert to DER format
    echo "Converting to DER..."
    if openssl x509 -outform der -in "$db_cert" -out "$db_der"; then
        echo "Conversion to DER format successful: $db_der"
    else
        echo "Error converting to DER."
        echo "CONVERSION_FAILED"
    fi

    # Step 2: Verify the DER certificate
    echo "Verifying DER certificate..."
    if openssl x509 -in "$db_der" -inform der -noout -text; then
        echo "DER certificate verification successful."
        echo "SUCCESS"
    else
        echo "DER certificate verification failed."
        echo "VERIFICATION_FAILED"
    fi
}

# https://jsw.ibm.com/browse/DBACLD-181735
# verify certifcate in trust store 
function check_cert_in_truststore() {
  local keystore="$1"
  local storepass="$2"
  local alias="$3"
  local cert_file="$4"

  if "$KEYTOOL_CMD" -list -v -keystore "$keystore" -storepass "$storepass" -alias "$alias" 2>/dev/null | grep -q "Alias name:"; then
    echo "Certificate with alias '$alias' already exists in truststore."
    echo "Certificate_not_in_truststore"
  else
    echo "Certificate with alias '$alias' not found. Importing..."
    "$KEYTOOL_CMD" -import -alias "$alias" -keystore "$keystore" -file "$cert_file" -storepass "$storepass" -storetype PKCS12 -noprompt 2>&1 </dev/null
    echo "Certificate_is_available_in_truststore"
  fi
}


# Function that validates if all secrets generated are applied in the cluster
# Moved this function to the common.sh so it can be used by cp4a-content-assistant.sh script and cp4a-prerequisites.sh  -> https://jsw.ibm.com/browse/DBACLD-185712
function validate_secret_in_cluster(){
    INFO "Checking if all secrets required for the deployment patterns selected have been created in the cluster."
    local files=()
    SECRET_CREATE_PASSED="true"
    # Check if secret_template folder is created
    if [ -d $SECRET_FILE_FOLDER ]; then
        files=($(find $SECRET_FILE_FOLDER -name '*.yaml'))
        for item in ${files[*]}
        do
          secret_name_tmp=`${YQ_CMD} ".metadata.name // \"\"" "$item"`
                    
          if [ -z "$secret_name_tmp" ]; then
              error "Secret name in YAML file not found: \"$item\"! Please check and fix it"
              exit 1
          else

            kind_tmp=`${YQ_CMD} ".kind" "$item"`
            
            secret_name_tmp=$(sed -e 's/^"//' -e 's/"$//' <<<"$secret_name_tmp")

            if [[ "$kind_tmp" == "Secret" ]]; then # DBACLD-185209: Vault implementation.  Only check for kind: Secret
              # need to check ibm-zen-metastore-edb-cm/im-datastore-edb-cm for Zen/IM and ibm-bts-config-extension external postgresql db support
              if [[ $secret_name_tmp != "ibm-zen-metastore-edb-cm" && $secret_name_tmp != "im-datastore-edb-cm" && $secret_name_tmp != "ibm-bts-config-extension" && $secret_name_tmp != "cp4ba-tls-issuer" ]]; then
                  secret_exists=`${CLI_CMD} get secret $secret_name_tmp -n "$CP4BA_SERVICES_NS" --ignore-not-found | wc -l`  >/dev/null 2>&1
                  if [ "$secret_exists" -ne 2 ] ; then
                      error "Secret \"$secret_name_tmp\" not found in Kubernetes cluster! please create it first before deploying CP4BA"
                      SECRET_CREATE_PASSED="false"
                  else
                      success "Secret \"$secret_name_tmp\" found in Kubernetes cluster, PASSED!"
                  fi
              else
                  if [[ $secret_name_tmp == "cp4ba-tls-issuer" ]]; then
                      secret_exists=`${CLI_CMD} get Issuer $secret_name_tmp -n "$CP4BA_SERVICES_NS" --ignore-not-found | wc -l`  >/dev/null 2>&1
                      if [ "$secret_exists" -ne 2 ] ; then
                          error "Issuer \"$secret_name_tmp\" not found in Kubernetes cluster! please create it first before deploying CP4BA"
                          SECRET_CREATE_PASSED="false"
                      else
                          success "Issuer \"$secret_name_tmp\" found in Kubernetes cluster, PASSED!"
                      fi
                  else
                      secret_exists=`${CLI_CMD} get configmap $secret_name_tmp -n "$CP4BA_SERVICES_NS" --ignore-not-found | wc -l`  >/dev/null 2>&1
                      if [ "$secret_exists" -ne 2 ] ; then
                          error "ConfigMap \"$secret_name_tmp\" not found in Kubernetes cluster! please create it first before deploying CP4BA"
                          SECRET_CREATE_PASSED="false"
                      else
                          success "ConfigMap \"$secret_name_tmp\" found in Kubernetes cluster, PASSED!"
                      fi
                  fi
              fi
            elif [[ "$kind_tmp" == "SecretProviderClass" ]]; then # DBACLD-185209: Vault implementation.  Only check for kind: SecretProviderClass
              secret_exists=$($CLI_CMD get SecretProviderClass $secret_name_tmp -n "$CP4BA_SERVICES_NS" --ignore-not-found 2>/dev/null | wc -l)  
              if [ "$secret_exists" -ne 2 ] ; then
                  error "SecretProviderClass \"$secret_name_tmp\" not found in Kubernetes cluster! please create it first before deploying CP4BA"
                  SECRET_CREATE_PASSED="false"
              else
                  success "SecretProviderClass \"$secret_name_tmp\" found in Kubernetes cluster, PASSED!"
              fi
            fi # End of Secret and SecretProviderClass checking.
          fi
        done

        files=($(find $SECRET_FILE_FOLDER -name '*.sh'))
        for item in ${files[*]}
        do
            if [[ "$machine" == "Mac" ]]; then
                secret_name_tmp=`grep ' create secret generic' $item | tail -1 | cut -d'"' -f2`

                # for DPE secret format specially
                if [ -z "$secret_name_tmp" ]; then
                    secret_name_tmp=`grep ' create secret generic' $item | tail -1 | cut -d'"' -f2`
                fi
            else
                # extract secret name by grabbing string btw "create secret generic" and the next whitespace
                secret_name_tmp=`cat $item | grep -oP '(?<=create secret generic ).*?(?=\s)' | tail -1`
            fi
            if [ -z "$secret_name_tmp" ]; then
                error "Secret name in shell script file not found: \"$item\"! Please check and fix it"
                exit 1
            else
                secret_name_tmp=$(sed -e 's/^"//' -e 's/"$//' <<<"$secret_name_tmp")
                secret_exists=`${CLI_CMD} get secret $secret_name_tmp -n "$CP4BA_SERVICES_NS" --ignore-not-found | wc -l`  >/dev/null 2>&1
                if [ "$secret_exists" -ne 2 ] ; then
                    error "Secret \"$secret_name_tmp\" not found in Kubernetes cluster! please create it first before deploying CP4BA"
                    SECRET_CREATE_PASSED="false"
                else
                    success "Secret \"$secret_name_tmp\" found in Kubernetes cluster, PASSED!"
                fi
            fi
        done
        if [[ $SECRET_CREATE_PASSED == "false" ]]; then
            info "Please create all required secrets in the cluster correctly, exiting..."
            exit 1
        else
            INFO "All secrets have been created in the cluster, PASSED!"
        fi
    else
        success "No secrets are needed for the selected configuration. Skipping this step."
    fi
}

# verify ldap connection
function verify_ldap_connection(){
  local LDAP_TEST_JAR_PATH=${CUR_DIR}/helper/verification/ldap
  local ldap_server=$1
  local ldap_port=$2
  local ldap_basedn=$3
  local ldap_binddn=$4
  local ldap_binddn_pwd=$5
  local ldap_ssl=$6
  local ldap_group_basedn=$7
  local ldap_user_filter=$8
  local ldap_group_filter=$9
  local ldap_user_password_list=${10}
  local ldap_group_list=${11}
  local ldap_truststore_password=$(generate_truststore_password)

  if [[ $ldap_ssl == "true" || $ldap_ssl == "yes" || $ldap_ssl == "y" ]]; then
    tmp_cert_folder="$(prop_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
    if [[ ! -f "${tmp_cert_folder}/ldap-cert.crt" ]]; then
      fail "Not found required certificate file \"ldap-cert.crt\" under \"$tmp_cert_folder\", exit..."
      exit 1
    fi
    rm -rf /tmp/ldap.der 2>&1 </dev/null
    rm -rf /tmp/ldap-truststore.jks 2>&1 </dev/null
    
    openssl x509 -outform der -in $tmp_cert_folder/ldap-cert.crt -out /tmp/ldap.der 2>&1 </dev/null
    "$KEYTOOL_CMD" -import -alias cp4baLdapCerts -keystore /tmp/ldap-truststore.jks -file /tmp/ldap.der -storepass "$ldap_truststore_password" -storetype JKS -noprompt 2>&1 </dev/null
    msg "Checking connection for LDAP server \"$ldap_server\" using BindDN \"$ldap_binddn\".."

  
  # DBACLD-202948: remove -Dsemeru.fips option from all java commands for connection verification
  # https://jsw.ibm.com/browse/DBACLD-187086 - Construct a string for java command to deal with special characters
  java_command_string="$JAVA_CMD -Djavax.net.ssl.trustStore=/tmp/ldap-truststore.jks -Djavax.net.ssl.trustStorePassword=$ldap_truststore_password -jar ${LDAP_TEST_JAR_PATH}/LdapTest.jar -u 'ldaps://$ldap_server:$ldap_port' -b '$ldap_basedn' -D '$ldap_binddn' -w '$ldap_binddn_pwd' -additionalvalidation -gdn '$ldap_group_basedn' -upl '$ldap_user_password_list' -gl '$ldap_group_list' -uf '$ldap_user_filter' -gf '$ldap_group_filter' 2>&1"
  output=$(eval "$java_command_string" | tr -d '\0' )

    # https://jsw.ibm.com/browse/DBACLD-192983 Check for successful connection - ONLY consider it successful if:
    # The output contains "Connected to: ldaps://$ldap_server:$ldap_port" (indicating successful connection)
    if [[ "$output" == *"Connected to: ldaps://$ldap_server:$ldap_port"* ]]; then
      # Moving all additional validation checks to be displayed only if we get a successful connection
      #For https://jsw.ibm.com/browse/DBACLD-158315
      success "Connected to LDAP \"$ldap_server\" using BindDN:\"$ldap_binddn\" successfully, PASSED!"
      printf "\n"
      connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
      if [[ ! -z $connection_time ]]; then
        display_latency_warning $connection_time "LDAP"
      fi
      # Extract everything from "LDAP Users Summary" until "Total time taken"
      # /LDAP Users Summary/ {flag=1} starts printing everything from LDAP Users Summary and /Total time taken/ {flag=0} stops printing when Total time taken is found
      # https://jsw.ibm.com/browse/DBACLD-159190
      # showing the group summary only if grouplist passed to the jar is not empty, One such use case is for an ADS only deployment that requires no LDAP group is required to be specified in the property file
      if [[ ${#ldap_group_list} -eq 0 ]]; then
        ldap_validation_table=$(echo "$output" | awk '/LDAP Users Summary/ {flag=1} /LDAP Groups Summary/ {flag=0} flag')
      else
        ldap_validation_table=$(echo "$output" | awk '/LDAP Users Summary/ {flag=1} /Total time taken/ {flag=0} flag')
      fi
      echo "$ldap_validation_table"
      printf "\n"
    else
      warning "Execute: $JAVA_CMD -Djavax.net.ssl.trustStore=/tmp/ldap-truststore.jks -Djavax.net.ssl.trustStorePassword=$ldap_truststore_password -jar ${LDAP_TEST_JAR_PATH}/LdapTest.jar -u \"ldaps://$ldap_server:$ldap_port\" -b \"$ldap_basedn\" -D \"$ldap_binddn\" -w \"******\"" && \
      fail "Unable to connect to LDAP server \"$ldap_server\" using BindDN \"$ldap_binddn\", please check configuration in LDAP property again."
    fi
  else
    msg "Checking connection for LDAP server \"$ldap_server\" using BindDN \"$ldap_binddn\".."
    # https://jsw.ibm.com/browse/DBACLD-187086 - Construct a string for java command to deal with special characters
    java_command_string="$JAVA_CMD -jar ${LDAP_TEST_JAR_PATH}/LdapTest.jar -u 'ldap://$ldap_server:$ldap_port' -b '$ldap_basedn' -D '$ldap_binddn' -w '$ldap_binddn_pwd' -additionalvalidation -gdn '$ldap_group_basedn' -upl '$ldap_user_password_list' -gl '$ldap_group_list' -uf '$ldap_user_filter' -gf '$ldap_group_filter' 2>&1"
    output=$(eval "$java_command_string" | tr -d '\0' )
    
    # https://jsw.ibm.com/browse/DBACLD-192983 Check for successful connection - ONLY consider it successful if:
    # The output contains "Connected to: ldap://$ldap_server:$ldap_port" (indicating successful connection)
    if [[ "$output" == *"Connected to: ldap://$ldap_server:$ldap_port"* ]]; then
      # Moving all additional validation checks to be displayed only if we get a successful connection
      #For https://jsw.ibm.com/browse/DBACLD-158315
      success "Connected to LDAP \"$ldap_server\" using BindDN:\"$ldap_binddn\" successfully, PASSED!"
      printf "\n"
      connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
      if [[ ! -z $connection_time ]]; then
        display_latency_warning $connection_time "LDAP"
      fi
      # Extract everything from "LDAP Users Summary" until "Total time taken"
      # /LDAP Users Summary/ {flag=1} starts printing everything from LDAP Users Summary and /Total time taken/ {flag=0} stops printing when Total time taken is found
      # https://jsw.ibm.com/browse/DBACLD-159190
      # showing the group summary only if grouplist passed to the jar is not empty, One such use case is for an ADS only deployment that requires no LDAP group is required to be specified in the property file
      if [[ ${#ldap_group_list} -eq 0 ]]; then
        ldap_validation_table=$(echo "$output" | awk '/LDAP Users Summary/ {flag=1} /LDAP Groups Summary/ {flag=0} flag')
      else
        ldap_validation_table=$(echo "$output" | awk '/LDAP Users Summary/ {flag=1} /Total time taken/ {flag=0} flag')
      fi
      echo "$ldap_validation_table"
      printf "\n"
    else
      warning "Execution: $JAVA_CMD -jar ${LDAP_TEST_JAR_PATH}/LdapTest.jar -u \"ldap://$ldap_server:$ldap_port\" -b \"$ldap_basedn\" -D \"$ldap_binddn\" -w \"******\"" && \
      fail "Unable to connect to LDAP server \"$ldap_server\" using BindDN \"$ldap_binddn\", please check configuration in LDAP property again." 
    fi
  fi 
}

# verification db connection

function verify_db_connection(){
  local DB_JDBC_NAME=${JDBC_DRIVER_DIR}/$DB_TYPE
  local DB_CONNECTION_JAR_PATH=${CUR_DIR}/helper/verification/$DB_TYPE
  local LDAP_TEST_JAR_PATH=${CUR_DIR}/helper/verification/ldap
  local db_truststore_password=$(generate_truststore_password)

  # DBACLD-202948: remove -Dsemeru.fips option from all java commands for connection verification
  
  if [[ $DB_TYPE == "oracle" ]]; then
    local dbuser=$1
    local dbuserpwd=$2
    local db_server_list_element=$3
  else
    local dbname=$1
    local dbuser=$2
    local dbuserpwd=$3
    local db_server_list_element=$4
    local base_dbname=$(prop_db_name_user_property_file ADP_BASE_DB_NAME)
    local proj_dbname=$(prop_db_name_user_property_file ADP_PROJECT_DB_NAME)
    IFS=',' read -ra proj_dbname_array <<< "$proj_dbname"
    # postgresql only support lower-case db name
    if [[ "$DB_TYPE" == "postgresql" && "$dbname" != "$base_dbname" ]]; then
      match_found=false
      for proj_dbname in "${proj_dbname_array[@]}"; do
        if [[ "$dbname" == "$proj_dbname" ]]; then
          match_found=true
          break
        fi
      done
      if [[ "$match_found" == false ]]; then
        dbname=$(echo "$dbname" | tr '[:upper:]' '[:lower:]')
      fi
    fi
  fi
  
  retVal_verify_db=0

  if [[ $DB_TYPE == "oracle" ]]; then
      printf "\n"
      info "Checking the connection for $DB_TYPE database \"${dbuser}\" belonging to database instance \"${db_server_list_element}\""

      oracle_url=$(prop_db_oracle_server_property_file  $db_server_list_element.ORACLE_JDBC_URL)
      oracle_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$oracle_url")
  else
      printf "\n"
      info "Checking the connection for $DB_TYPE database \"${dbname}\" belonging to database server \"${db_server_list_element}\""

      dbserver=$(prop_db_server_property_file $db_server_list_element.DATABASE_SERVERNAME)
      dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")

      dbport=$(prop_db_server_property_file $db_server_list_element.DATABASE_PORT)
      dbport=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbport")
  fi
  tmp_dbssl_flag="$(prop_db_server_property_file $db_server_list_element.DATABASE_SSL_ENABLE)"
  tmp_dbssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbssl_flag")
  tmp_dbssl_flag=$(echo "$tmp_dbssl_flag"| tr '[:upper:]' '[:lower:]')

  if [[ $tmp_dbssl_flag == "true" || $tmp_dbssl_flag == "yes" || $tmp_dbssl_flag == "y" ]]; then
    dbcafolder="$(prop_db_server_property_file $db_server_list_element.DATABASE_SSL_CERT_FILE_FOLDER)"
    dbcafolder=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbcafolder")

    # check certification existing or not
    if [[ $DB_TYPE == "oracle" ]]; then
      if [[ ! -f "${dbcafolder}/db-cert.crt" ]]; then
        fail "Not found required server certificate file \"db-cert.crt\" under \"$dbcafolder\" for $DB_TYPE database instance \"$dbuser\", exit..."
        exit 1
      fi
    elif [[ $DB_TYPE == "db2" || $DB_TYPE == "sqlserver" ]]; then
      if [[ ! -f "${dbcafolder}/db-cert.crt" ]]; then
        fail "Not found required server certificate file \"db-cert.crt\" under \"$dbcafolder\" for $DB_TYPE database server \"$dbserver\", exit..."
        exit 1
      fi
    elif [[ $DB_TYPE == "postgresql" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $db_server_list_element.POSTGRESQL_SSL_CLIENT_SERVER)")
        tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
        if [[ $tmp_flag == "no" || $tmp_flag == "false" || $tmp_flag == "" || -z $tmp_flag ]]; then
          if [[ ! -f "${dbcafolder}/db-cert.crt" ]]; then
            fail "Not found required server certificate file \"db-cert.crt\" under \"$dbcafolder\" for $DB_TYPE database server \"$dbserver\", exit..."
            exit 1
          fi
        elif [[ $tmp_flag == "yes" || $tmp_flag == "true" || $tmp_flag == "y" ]]; then
          if [[ ! -f "${dbcafolder}/root.crt" ]]; then
            fail "Not found required server certificate file \"root.crt\" under \"$dbcafolder\" for $DB_TYPE database server \"$dbserver\", exit..."
            exit 1
          fi
          if [[ ! -f "${dbcafolder}/client.crt" ]]; then
            fail "Not found required client certificate file \"client.crt\" for under \"$dbcafolder\" for $DB_TYPE database server \"$dbserver\", exit..."
            exit 1
          fi
          if [[ ! -f "${dbcafolder}/client.key" ]]; then
            fail "Not found required client key file \"client.key\" under \"$dbcafolder\" for $DB_TYPE database server \"$dbserver\", exit..."
            exit 1
          fi
        fi
    fi
    ## DB SSL enable
    while true; do
        case $DB_TYPE in
          "db2")                                                                                   # -h {{ db2_server }} -p {{ db2_port }} -db {{ db2_dbname }} -u {{ db2_user }} -pwd {{ db2_pwd }} -ssl -ca {{ db2_cafile }}
              # Adding a flag to the jar command so that it can validate a db2rds type database
              if [[ $IS_RDS == true ]]; then
                output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -ssl -ca $dbcafolder/db-cert.crt -db2rds 2>&1)
              else
                output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -ssl -ca $dbcafolder/db-cert.crt 2>&1)
              fi
              if [[ "$output" == *"Connected to the database Success"* ]]; then
                success "Check for DB connection for \"$dbname\" on database server \"$dbserver\", has PASSED!"
                printf "\n"
                connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                if [[ ! -z $connection_time ]]; then
                  display_latency_warning $connection_time "Database"
                fi
              else
                if [[ $IS_RDS == true ]]; then
                  warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar\" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -ssl -ca $dbcafolder/db-cert.crt -db2rds" && \
                  fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
                else 
                  warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar\" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -ssl -ca $dbcafolder/db-cert.crt " && \
                  fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
                fi
              fi
              break
              ;;
          "oracle")                                                                                                                                 # -url "{{ oracle_url }}" -u {{ oracle_user }} -pwd {{ oracle_password_decoded }} -ssl -trustorefile {{trustorefile}} -trustoretype {{trustoretype}} -trustorePwd {{trustorePwd}}
              TRUSTSTORE_FOLDER="/tmp/${DB_TYPE}_db_truststore/${db_server_list_element}"
              rm -rf $TRUSTSTORE_FOLDER 2>&1 </dev/null
              mkdir -p $TRUSTSTORE_FOLDER 2>&1 </dev/null
              #  add keytool to system PATH.
              #sudo -s export PATH="/opt/ibm/java/jre/bin/:$PATH"; export PATH="/opt/ibm/java/jre/bin/:$PATH"; echo "PATH=$PATH:/opt/ibm/java/jre/bin/" >> ~/.bashrc; source ~/.bashrc

              result=$(verify_and_convert_cert "$dbcafolder/db-cert.crt" "$TRUSTSTORE_FOLDER/oracle-db-cert.der" 2>&1)
              if [[ "$result" == *"SUCCESS"* ]]; then 
                success "Certificate generation and verification is successful"  
                keytool_result=$(check_cert_in_truststore "$TRUSTSTORE_FOLDER/oracle-db-truststore.p12" "$db_truststore_password" "cp4baOraleCerts" "$TRUSTSTORE_FOLDER/oracle-db-cert.der" 2>&1)
                if [[ "$keytool_result" == *"Certificate_not_in_truststore"* ]]; then
                  fail "The certificate was already present. No import was needed." 
                elif [[ "$keytool_result" == *"Certificate_is_available_in_truststore"* ]]; then
                  success "The certificate was imported successfully."
                fi            
              elif [[ "$result" == *"CONVERSION_FAILED"* ]]; then
                fail "Certificate conversion failed."
              elif [[ "$result" == *"VERIFICATION_FAILED"* ]]; then
                fail "Certificate verification failed."
              fi
              output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp "${DB_JDBC_NAME}/ojdbc8.jar:${DB_CONNECTION_JAR_PATH}/OracleJDBCConnection.jar" OracleConnection -url "$oracle_url" -u $dbuser -pwd $dbuserpwd -ssl -trustorefile $TRUSTSTORE_FOLDER/oracle-db-truststore.p12 -trustoretype "PKCS12" -trustorePwd "$db_truststore_password" 2>&1)
              if [[ "$output" == *"Connected to the database Success"* && "$result" == *"SUCCESS"* ]]; then
                success "Check for DB connection for \"$dbuser\" using JDBC URL \"$oracle_url\", has PASSED!"
                printf "\n"
                connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                if [[ ! -z $connection_time ]]; then
                  display_latency_warning $connection_time "Database"
                fi
              else
                warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp \"${DB_JDBC_NAME}/ojdbc8.jar:${DB_CONNECTION_JAR_PATH}/OracleJDBCConnection.jar\" OracleConnection -url \"$oracle_url\" -u $dbuser -pwd ****** -ssl -trustorefile $TRUSTSTORE_FOLDER/oracle-db-truststore.p12 -trustoretype \"PKCS12\" -trustorePwd \"$db_truststore_password\"" && \
                fail "Unable to connect to database \"$dbuser\" using JDBC URL \"$oracle_url\", please check configuration again."
              fi
              break
              ;;
          "sqlserver")                                                                                                          # SQLConnection -h {{ database_servername }} -p {{ database_port }} -d {{ database_name }} -u {{ sqlserver_user }} -pwd {{ sqlserver_password_decoded }} -ssl '{{ ssl_connection_str }}'
              TRUSTSTORE_FOLDER="/tmp/${DB_TYPE}_db_truststore/${db_server_list_element}"
              rm -rf $TRUSTSTORE_FOLDER 2>&1 </dev/null
              mkdir -p $TRUSTSTORE_FOLDER 2>&1 </dev/null
              #  add keytool to system PATH.
              #sudo -s export PATH="/opt/ibm/java/jre/bin/:$PATH"; export PATH="/opt/ibm/java/jre/bin/:$PATH"; echo "PATH=$PATH:/opt/ibm/java/jre/bin/" >> ~/.bashrc; source ~/.bashrc

              result=$(verify_and_convert_cert "$dbcafolder/db-cert.crt" "$TRUSTSTORE_FOLDER/sqlserver-db-cert.der" 2>&1)
              if [[ "$result" == *"SUCCESS"* ]]; then 
                success "Certificate generation and verification is successful"
                keytool_result=$(check_cert_in_truststore "$TRUSTSTORE_FOLDER/sqlserver-db-truststore.p12" "$db_truststore_password" "cp4baSQLServerCerts" "$TRUSTSTORE_FOLDER/sqlserver-db-cert.der" 2>&1)
                if [[ "$keytool_result" == *"Certificate_not_in_truststore"* ]]; then
                  fail "The certificate was already present. No import was needed."
                elif [[ "$keytool_result" == *"Certificate_is_available_in_truststore"* ]]; then
                  success "The certificate was imported successfully."
                fi
              elif [[ "$result" == *"CONVERSION_FAILED"* ]]; then
                fail "Certificate conversion failed."
              elif [[ "$result" == *"VERIFICATION_FAILED"* ]]; then
                fail "Certificate verification failed."
              fi

              SSL_CONNECTION_STR="encrypt=true;trustServerCertificate=false;trustStore=${TRUSTSTORE_FOLDER}/sqlserver-db-truststore.p12;trustStorePassword=${db_truststore_password}"
              output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp "${DB_JDBC_NAME}/mssql-jdbc.jre11.jar:${DB_CONNECTION_JAR_PATH}/SQLJDBCConnection.jar" SQLConnection -h $dbserver -p $dbport -d $dbname -u $dbuser -pwd $dbuserpwd -ssl "$SSL_CONNECTION_STR" 2>&1)
              if [[ "$output" == *"Connected to the database Success"* && "$result" == *"SUCCESS"* ]]; then
                success "Check for DB connection for \"$dbname\" on database server \"$dbserver\", has PASSED!"
                printf "\n"
                connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                if [[ ! -z $connection_time ]]; then
                  display_latency_warning $connection_time "Database"
                fi
              else
                warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp \"${DB_JDBC_NAME}/mssql-jdbc.jre11.jar:${DB_CONNECTION_JAR_PATH}/SQLJDBCConnection.jar\" SQLConnection -h $dbserver -p $dbport -d $dbname -u $dbuser -pwd ****** -ssl \"$SSL_CONNECTION_STR\"" && \
                fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
              fi
              break
              ;;
          "postgresql")
              tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $db_server_list_element.POSTGRESQL_SSL_CLIENT_SERVER)")
              tmp_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
              if [[ $tmp_flag == "no" || $tmp_flag == "false" || $tmp_flag == "" || -z $tmp_flag ]]; then
                postgres_cafile="${dbcafolder}/db-cert.crt"
              output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode require -ca $postgres_cafile 2>&1)
              if [[ "$output" == *"Connected to the database Success"* ]]; then
                  success "Check for DB connection for \"$dbname\" on database server \"$dbserver\", has PASSED!"
                  printf "\n"
                  connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                  if [[ ! -z $connection_time ]]; then
                    display_latency_warning $connection_time "Database"
                  fi
                else
                  warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode require -ca $postgres_cafile" && \
                  fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
                fi
              elif [[ $tmp_flag == "yes" || $tmp_flag == "true" || $tmp_flag == "y" ]]; then
                postgres_cafile="${dbcafolder}/root.crt"
                postgres_clientkeyfile="${dbcafolder}/client.key"
                postgres_clientcertfile="${dbcafolder}/client.crt"

                rm -rf ${dbcafolder}/clientkey.pk8 2>&1 </dev/null
                openssl pkcs8 -topk8 -outform DER -in $postgres_clientkeyfile -out ${dbcafolder}/clientkey.pk8 -nocrypt 2>&1 </dev/null
                dbuserpwd="changit" # client auth does not need dbuserpwd
                output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode verify-ca -ca $postgres_cafile -clientkey ${dbcafolder}/clientkey.pk8 -clientcert $postgres_clientcertfile 2>&1)
                if [[ "$output" == *"Connected to the database Success"* ]]; then
                  success "Check for DB connection for \"$dbname\" on database server \"$dbserver\", has PASSED!"
                  printf "\n"
                  connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                  if [[ ! -z $connection_time ]]; then
                    display_latency_warning $connection_time "Database"
                  fi
                else
                  warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode verify-ca -ca $postgres_cafile -clientkey ${dbcafolder}/clientkey.pk8 -clientcert $postgres_clientcertfile" && \
                  fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
                fi
              fi                                                                                                                                                                                  # -h {{ postgres_host }} -p {{ postgres_port }} -db {{ postgres_db }} -u {{ postgresql_server_user }} -pwd {{ postgres_pwd }} -sslmode require -ca {{ postgres_cafile}}              
              break
              ;;
        esac
    done  
  else
    ## DB SSL disabled
    while true; do
        case $DB_TYPE in
          "db2")                                                                                                                                                   # -h {{ db2_server }} -p {{ db2_port }} -db {{ db2_dbname }} -u {{ db2_user }} -pwd {{ db2_pwd }} -ssl -ca {{ db2_cafile }}
              # Adding a flag to the jar command so that it can validate a db2rds type database
              if [[ $IS_RDS == true ]]; then
                output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp "${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -db2rds 2>&1)
              else
                output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp "${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd 2>&1)
              fi
              if [[ "$output" == *"Connected to the database Success"* ]]; then
                success "Check for DB connection for \"$dbname\" on database host server \"$dbserver\", has PASSED!"
                printf "\n"
                connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                if [[ ! -z $connection_time ]]; then
                  display_latency_warning $connection_time "Database"
                fi
              else
                if [[ $IS_RDS == true ]]; then
                  warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp \"${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar\" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -db2rds" && \
                  fail "Unable to connect to database \"$dbname\" on database host server \"$dbserver\", please check configuration again."
                else
                  warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp \"${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar\" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ******" && \
                  fail "Unable to connect to database \"$dbname\" on database host server \"$dbserver\", please check configuration again."
                fi
              fi
              break
              ;;
          "oracle")                                                                                                                                 # -url "{{ oracle_url }}" -u {{ oracle_user }} -pwd {{ oracle_password_decoded }} -ssl -trustorefile {{trustorefile}} -trustoretype {{trustoretype}} -trustorePwd {{trustorePwd}}
              output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp "${DB_JDBC_NAME}/ojdbc8.jar:${DB_CONNECTION_JAR_PATH}/OracleJDBCConnection.jar" OracleConnection -url "$oracle_url" -u $dbuser -pwd $dbuserpwd 2>&1)
              if [[ "$output" == *"Connected to the database Success"* ]]; then
                success "Check for DB connection for \"$dbuser\" using JDBC URL \"$oracle_url\", has PASSED!"
                printf "\n"
                connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                if [[ ! -z $connection_time ]]; then
                  display_latency_warning $connection_time "Database"
                fi
              else
                warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp \"${DB_JDBC_NAME}/ojdbc8.jar:${DB_CONNECTION_JAR_PATH}/OracleJDBCConnection.jar\" OracleConnection -url \"$oracle_url\" -u $dbuser -pwd ******" && \
                printf '%b\n'  "\x1B[1;31mUnable to connect to database \"$dbuser\" using JDBC URL \"$oracle_url\", please check configuration again.\x1B[0m"
              fi
              break
              ;;
          "sqlserver")                                                                                                          # SQLConnection -h {{ database_servername }} -p {{ database_port }} -d {{ database_name }} -u {{ sqlserver_user }} -pwd {{ sqlserver_password_decoded }} -ssl 'encrypt=false'
              output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp "${DB_JDBC_NAME}/mssql-jdbc.jre11.jar:${DB_CONNECTION_JAR_PATH}/SQLJDBCConnection.jar" SQLConnection -h $dbserver -p $dbport -d $dbname -u $dbuser -pwd $dbuserpwd -ssl 'encrypt=false' 2>&1)
              if [[ "$output" == *"Connected to the database Success"* ]]; then
                success "Check for DB connection for \"$dbname\" on database host server \"$dbserver\", has PASSED!"
                printf "\n"
                connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                if [[ ! -z $connection_time ]]; then
                  display_latency_warning $connection_time "Database"
                fi
              else
                warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -cp \"${DB_JDBC_NAME}/mssql-jdbc.jre11.jar:${DB_CONNECTION_JAR_PATH}/SQLJDBCConnection.jar\" SQLConnection -h $dbserver -p $dbport -d $dbname -u $dbuser -pwd ****** -ssl 'encrypt=false'" && \
                fail "Unable to connect to database \"$dbname\" on database host server \"$dbserver\", please check configuration again."
              fi
              break
              ;;
          "postgresql")                                                                                                                                                                                    # -h {{ postgres_host }} -p {{ postgres_port }} -db {{ postgres_db }} -u {{ postgresql_server_user }} -pwd {{ postgres_pwd }} -sslmode require -ca {{ postgres_cafile}}
              output=$($JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -cp "${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode disable 2>&1)
              if [[ "$output" == *"Connected to the database Success"* ]]; then
                success "Check for DB connection for \"$dbname\" on database host server \"$dbserver\", has PASSED!"
                printf "\n"
                connection_time=$(echo "$output" | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                if [[ ! -z $connection_time ]]; then
                  display_latency_warning $connection_time "Database"
                fi
              else
                warning "Execute: $JAVA_CMD -Duser.language=$CP4BA_AUTO_LANGUAGE -Duser.country=$CP4BA_AUTO_REGION -Dcom.ibm.jsse2.overrideDefaultTLS=true -cp \"${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode disable" && \
                fail "Unable to connect to database \"$dbname\" on database host server \"$dbserver\", please check configuration again."
              fi
              break
              ;;
        esac
    done
  fi 
}
