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
    #     echo -e "\x1B[1mDone\x1B[0m"
    # else
    #     echo -e "\x1B[1;31mFailed\x1B[0m"
    # fi
   # Check Operator Persistent Volume status every 5 seconds (max 1 minutes) until allocate.
    kubectl apply -f ${STORAGE_CLASS_SAMPLE} >/dev/null 2>&1
    ATTEMPTS=0
    TIMEOUT=12
    printf "\n"
    info "Checking the storage class: \"${sc_name}\"..."
    until kubectl get pvc | grep ${sample_pvc_name}| grep -q -m 1 "Bound" || [ $ATTEMPTS -eq $TIMEOUT ]; do
        ATTEMPTS=$((ATTEMPTS + 1))
        echo -e "......"
        sleep 5
        if [ $ATTEMPTS -eq $TIMEOUT ] ; then
            fail "Failed to allocate the persistent volumes using storage class: \"${sc_name}\"!"
            # info "Run the following command to check the claim 'kubectl describe pvc ${sample_pvc_name}'"
            verification_sc_passed="No"
        fi
    done
    if [ $ATTEMPTS -lt $TIMEOUT ] ; then
            success "Verification storage class: \"${sc_name}\", PASSED!"
            kubectl delete -f ${STORAGE_CLASS_SAMPLE} >/dev/null 2>&1
            verification_sc_passed="Yes"
            printf "\n"
    fi

    rm -rf ${STORAGE_CLASS_SAMPLE} >/dev/null 2>&1
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

  if [[ $ldap_ssl == "true" || $ldap_ssl == "yes" || $ldap_ssl == "y" ]]; then
    tmp_cert_folder="$(prop_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
    if [[ ! -f "${tmp_cert_folder}/ldap-cert.crt" ]]; then
      fail "Not found required certificat file \"ldap-cert.crt\" under \"$tmp_cert_folder\", exit..."
      exit 1
    fi

    rm -rf /tmp/ldap.der 2>&1 </dev/null
    rm -rf /tmp/ldap-truststore.jks 2>&1 </dev/null
    #  add keytool to system PATH.
    sudo -s export PATH="/opt/ibm/java/jre/bin/:$PATH"; export PATH="/opt/ibm/java/jre/bin/:$PATH"; echo "PATH=$PATH:/opt/ibm/java/jre/bin/" >> ~/.bashrc; source ~/.bashrc

    openssl x509 -outform der -in $tmp_cert_folder/ldap-cert.crt -out /tmp/ldap.der 2>&1 </dev/null
    keytool -import -alias cp4baLdapCerts -keystore /tmp/ldap-truststore.jks -file /tmp/ldap.der -storepass changeit -storetype JKS -noprompt 2>&1 </dev/null
    msg "Checking connection for LDAP server \"$ldap_server\" using Bind DN \"$ldap_binddn\".."
    output=$(java -Dsemeru.fips=$fips_flag -Djavax.net.ssl.trustStore=/tmp/ldap-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit -jar ${LDAP_TEST_JAR_PATH}/LdapTest.jar -u "ldaps://$ldap_server:$ldap_port" -b "$ldap_basedn" -D "$ldap_binddn" -w "$ldap_binddn_pwd" 2>&1)
    retVal_verify_ldap_tmp=$?
    connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
    echo "Latency: $connection_time ms"
    # Check if elapsed time is greater than 10 ms using awk
    if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
      echo "The latency is less than 10ms, which is acceptable performance for a simple LDAP operation."
    elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
      echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple LDAP operation, but the service is still accessible."
    elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
      echo "The latency exceeds 30ms for a simple LDAP operation, which indicates potential for failures."
    fi

    [[ retVal_verify_ldap_tmp -ne 0 ]] && \
    warning "Execute: java -Dsemeru.fips=$fips_flag -Djavax.net.ssl.trustStore=/tmp/ldap-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit -jar ${LDAP_TEST_JAR_PATH}/LdapTest.jar -u \"ldaps://$ldap_server:$ldap_port\" -b \"$ldap_basedn\" -D \"$ldap_binddn\" -w \"******\"" && \
    fail "Unable to connect to LDAP server \"$ldap_server\" using Bind DN \"$ldap_binddn\", please check configuration in ldap property again."
    [[ retVal_verify_ldap_tmp -eq 0 ]] && \
    success "Connected to LDAP \"$ldap_server\" using BindDN:\"$ldap_binddn\" successfuly, PASSED!"
  else
    msg "Checking connection for LDAP server \"$ldap_server\" using Bind DN \"$ldap_binddn\".."
    output=$(java -Dsemeru.fips=$fips_flag -jar ${LDAP_TEST_JAR_PATH}/LdapTest.jar -u "ldap://$ldap_server:$ldap_port" -b "$ldap_basedn" -D "$ldap_binddn" -w "$ldap_binddn_pwd" 2>&1)
    retVal_verify_ldap_tmp=$?
    connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
    echo "Latency: $connection_time ms"
    # Check if elapsed time is greater than 10 ms using awk
    if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
      echo "The latency is less than 10ms, which is acceptable performance for a simple LDAP operation."
    elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
      echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple LDAP operation, but the service is still accessible."
    elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
      echo "The latency exceeds 30ms for a simple LDAP operation, which indicates potential for failures."
    fi

    [[ retVal_verify_ldap_tmp -ne 0 ]] && \
    warning "Execution: java -Dsemeru.fips=$fips_flag -jar ${LDAP_TEST_JAR_PATH}/LdapTest.jar -u \"ldap://$ldap_server:$ldap_port\" -b \"$ldap_basedn\" -D \"$ldap_binddn\" -w \"******\"" && \
    fail "Unable to connect to LDAP server \"$ldap_server\" using Bind DN \"$ldap_binddn\", please check configuration in ldap property again."
    [[ retVal_verify_ldap_tmp -eq 0 ]] && \
    success "Connected to LDAP \"$ldap_server\" using BindDN:\"$ldap_binddn\" successfuly, PASSED!"
  fi 
}

# verification db connection

function verify_db_connection(){
  local DB_JDBC_NAME=${JDBC_DRIVER_DIR}/$DB_TYPE
  local DB_CONNECTION_JAR_PATH=${CUR_DIR}/helper/verification/$DB_TYPE
  local LDAP_TEST_JAR_PATH=${CUR_DIR}/helper/verification/ldap
  
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
      info "Checking connection for $DB_TYPE database \"${dbuser}\" belongs to database instance \"${db_server_list_element}\" which defined in <DB_SERVER_LIST>...."

      oracle_url=$(prop_db_oracle_server_property_file  $db_server_list_element.ORACLE_JDBC_URL)
      oracle_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$oracle_url")
  else
      printf "\n"
      info "Checking connection for $DB_TYPE database \"${dbname}\" belongs to database server \"${db_server_list_element}\" which defined in <DB_SERVER_LIST>...."

      dbserver=$(prop_db_server_property_file $db_server_list_element.DATABASE_SERVERNAME)
      dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")

      dbport=$(prop_db_server_property_file $db_server_list_element.DATABASE_PORT)
      dbport=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbport")
  fi
  tmp_dbssl_flag="$(prop_db_server_property_file $db_server_list_element.DATABASE_SSL_ENABLE)"
  tmp_dbssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbssl_flag")
  tmp_dbssl_flag=$(echo $tmp_dbssl_flag| tr '[:upper:]' '[:lower:]')

  if [[ $tmp_dbssl_flag == "true" || $tmp_dbssl_flag == "yes" || $tmp_dbssl_flag == "y" ]]; then
    dbcafolder="$(prop_db_server_property_file $db_server_list_element.DATABASE_SSL_CERT_FILE_FOLDER)"
    dbcafolder=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbcafolder")

    # check certification existing or not
    if [[ $DB_TYPE == "oracle" ]]; then
      if [[ ! -f "${dbcafolder}/db-cert.crt" ]]; then
        fail "Not found required server certificat file \"db-cert.crt\" under \"$dbcafolder\" for $DB_TYPE database instance \"$dbuser\", exit..."
        exit 1
      fi
    elif [[ $DB_TYPE == "db2" || $DB_TYPE == "db2HADR" || $DB_TYPE == "sqlserver" ]]; then
      if [[ ! -f "${dbcafolder}/db-cert.crt" ]]; then
        fail "Not found required server certificat file \"db-cert.crt\" under \"$dbcafolder\" for $DB_TYPE database server \"$dbserver\", exit..."
        exit 1
      fi
    elif [[ $DB_TYPE == "postgresql" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $db_server_list_element.POSTGRESQL_SSL_CLIENT_SERVER)")
        tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        if [[ $tmp_flag == "no" || $tmp_flag == "false" || $tmp_flag == "" || -z $tmp_flag ]]; then
          if [[ ! -f "${dbcafolder}/db-cert.crt" ]]; then
            fail "Not found required server certificat file \"db-cert.crt\" under \"$dbcafolder\" for $DB_TYPE database server \"$dbserver\", exit..."
            exit 1
          fi
        elif [[ $tmp_flag == "yes" || $tmp_flag == "true" || $tmp_flag == "y" ]]; then
          if [[ ! -f "${dbcafolder}/root.crt" ]]; then
            fail "Not found required server certificate file \"root.crt\" under \"$dbcafolder\" for $DB_TYPE database server \"$dbserver\", exit..."
            exit 1
          fi
          if [[ ! -f "${dbcafolder}/client.crt" ]]; then
            fail "Not found required client certificat file \"client.crt\" for under \"$dbcafolder\" for $DB_TYPE database server \"$dbserver\", exit..."
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
              output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -ssl -ca $dbcafolder/db-cert.crt 2>&1)
              retVal_verify_db_tmp=$?
              connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
              if [[ ! -z $connection_time ]]; then
                echo "Latency: $connection_time ms"
                # Check if elapsed time is greater than 10 ms using awk
                if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
                  echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
                  echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
                  echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
                fi
              fi
              [[ retVal_verify_db_tmp -ne 0 ]] && \
              warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar\" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -ssl -ca $dbcafolder/db-cert.crt" && \
              fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
              [[ retVal_verify_db_tmp -eq 0 ]] && \
              success "Checked DB connection for \"$dbname\" on database server \"$dbserver\", PASSED!"
              break
              ;;
          "oracle")                                                                                                                                 # -url "{{ oracle_url }}" -u {{ oracle_user }} -pwd {{ oracle_password_decoded }} -ssl -trustorefile {{trustorefile}} -trustoretype {{trustoretype}} -trustorePwd {{trustorePwd}}
              TRUSTSTORE_FOLDER="/tmp/${DB_TYPE}_db_truststore/${db_server_list_element}"
              rm -rf $TRUSTSTORE_FOLDER 2>&1 </dev/null
              mkdir -p $TRUSTSTORE_FOLDER 2>&1 </dev/null
              #  add keytool to system PATH.
              sudo -s export PATH="/opt/ibm/java/jre/bin/:$PATH"; export PATH="/opt/ibm/java/jre/bin/:$PATH"; echo "PATH=$PATH:/opt/ibm/java/jre/bin/" >> ~/.bashrc; source ~/.bashrc

              openssl x509 -outform der -in $dbcafolder/db-cert.crt -out $TRUSTSTORE_FOLDER/oracle-db-cert.der 2>&1 </dev/null
              keytool -import -alias cp4baOraleCerts -keystore $TRUSTSTORE_FOLDER/oracle-db-truststore.p12 -file $TRUSTSTORE_FOLDER/oracle-db-cert.der -storepass changeit -storetype PKCS12 -noprompt 2>&1 </dev/null

              output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -cp "${DB_JDBC_NAME}/ojdbc8.jar:${DB_CONNECTION_JAR_PATH}/OracleJDBCConnection.jar" OracleConnection -url "$oracle_url" -u $dbuser -pwd $dbuserpwd -ssl -trustorefile $TRUSTSTORE_FOLDER/oracle-db-truststore.p12 -trustoretype "PKCS12" -trustorePwd "changeit" 2>&1)
              retVal_verify_db_tmp=$?
              connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
              if [[ ! -z $connection_time ]]; then
                echo "Latency: $connection_time ms"
                # Check if elapsed time is greater than 10 ms using awk
                if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
                  echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
                  echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
                  echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
                fi
              fi
              [[ retVal_verify_db_tmp -ne 0 ]] && \
              warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -cp \"${DB_JDBC_NAME}/ojdbc8.jar:${DB_CONNECTION_JAR_PATH}/OracleJDBCConnection.jar\" OracleConnection -url \"$oracle_url\" -u $dbuser -pwd ****** -ssl -trustorefile $TRUSTSTORE_FOLDER/oracle-db-truststore.p12 -trustoretype \"PKCS12\" -trustorePwd \"changeit\"" && \
              fail "Unable to connect to database \"$dbuser\" using JDBC URL \"$oracle_url\", please check configuration again."
              [[ retVal_verify_db_tmp -eq 0 ]] && \
              success "Checked DB connection for \"$dbuser\" using JDBC URL \"$oracle_url\", PASSED!"
              break
              ;;
          "sqlserver")                                                                                                          # SQLConnection -h {{ database_servername }} -p {{ database_port }} -d {{ database_name }} -u {{ sqlserver_user }} -pwd {{ sqlserver_password_decoded }} -ssl '{{ ssl_connection_str }}'
              TRUSTSTORE_FOLDER="/tmp/${DB_TYPE}_db_truststore/${db_server_list_element}"
              rm -rf $TRUSTSTORE_FOLDER 2>&1 </dev/null
              mkdir -p $TRUSTSTORE_FOLDER 2>&1 </dev/null
              #  add keytool to system PATH.
              sudo -s export PATH="/opt/ibm/java/jre/bin/:$PATH"; export PATH="/opt/ibm/java/jre/bin/:$PATH"; echo "PATH=$PATH:/opt/ibm/java/jre/bin/" >> ~/.bashrc; source ~/.bashrc

              openssl x509 -outform der -in $dbcafolder/db-cert.crt -out $TRUSTSTORE_FOLDER/sqlserver-db-cert.der 2>&1 </dev/null
              keytool -import -alias cp4baSQLServerCerts -keystore $TRUSTSTORE_FOLDER/sqlserver-db-truststore.p12 -file $TRUSTSTORE_FOLDER/sqlserver-db-cert.der -storepass changeit -storetype PKCS12 -noprompt 2>&1 </dev/null
                                                                                                                        # ssl_connection_str: "encrypt=true;trustServerCertificate=false;trustStore={{ban_cert_dir}}/ibm_customBANTrustStore.p12;trustStorePassword={{ ban_keystore_decoded_pwd|first if '{xor}' in ban_keystore_password else ban_keystore_password }}"
              SSL_CONNECTION_STR="fips=$fips_flag;encrypt=true;trustServerCertificate=false;trustStore=${TRUSTSTORE_FOLDER}/sqlserver-db-truststore.p12;trustStorePassword=changeit"
              output=$(java -Duser.language=en -Duser.country=US -cp "${DB_JDBC_NAME}/mssql-jdbc.jre8.jar:${DB_CONNECTION_JAR_PATH}/SQLJDBCConnection.jar" SQLConnection -h $dbserver -p $dbport -d $dbname -u $dbuser -pwd $dbuserpwd -ssl "$SSL_CONNECTION_STR" 2>&1)
              retVal_verify_db_tmp=$?
              connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
              if [[ ! -z $connection_time ]]; then
                echo "Latency: $connection_time ms"
                # Check if elapsed time is greater than 10 ms using awk
                if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
                  echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
                  echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
                  echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
                fi
              fi

              [[ retVal_verify_db_tmp -ne 0 ]] && \
              warning "Execute: java -Duser.language=en -Duser.country=US -cp \"${DB_JDBC_NAME}/mssql-jdbc.jre8.jar:${DB_CONNECTION_JAR_PATH}/SQLJDBCConnection.jar\" SQLConnection -h $dbserver -p $dbport -d $dbname -u $dbuser -pwd ****** -ssl \"$SSL_CONNECTION_STR\"" && \
              fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
              [[ retVal_verify_db_tmp -eq 0 ]] && \
              success "Checked DB connection for \"$dbname\" on database server \"$dbserver\", PASSED!"
              break
              ;;
          "postgresql")
              tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $db_server_list_element.POSTGRESQL_SSL_CLIENT_SERVER)")
              tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
              if [[ $tmp_flag == "no" || $tmp_flag == "false" || $tmp_flag == "" || -z $tmp_flag ]]; then
                postgres_cafile="${dbcafolder}/db-cert.crt"
                output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode require -ca $postgres_cafile 2>&1)
                retVal_verify_db_tmp=$?
                connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                if [[ ! -z $connection_time ]]; then
                  echo "Latency: $connection_time ms"
                  # Check if elapsed time is greater than 10 ms using awk
                  if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
                    echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
                  elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
                    echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
                  elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
                    echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
                  fi
                fi

                [[ retVal_verify_db_tmp -ne 0 ]] && \
                warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode require -ca $postgres_cafile" && \
                fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
                [[ retVal_verify_db_tmp -eq 0 ]] && \
                success "Checked DB connection for \"$dbname\" on database server \"$dbserver\", PASSED!"
              elif [[ $tmp_flag == "yes" || $tmp_flag == "true" || $tmp_flag == "y" ]]; then
                postgres_cafile="${dbcafolder}/root.crt"
                postgres_clientkeyfile="${dbcafolder}/client.key"
                postgres_clientcertfile="${dbcafolder}/client.crt"

                rm -rf ${dbcafolder}/clientkey.pk8 2>&1 </dev/null
                openssl pkcs8 -topk8 -outform DER -in $postgres_clientkeyfile -out ${dbcafolder}/clientkey.pk8 -nocrypt 2>&1 </dev/null
                dbuserpwd="changit" # client auth does not need dbuserpwd
                output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp "${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode verify-ca -ca $postgres_cafile -clientkey ${dbcafolder}/clientkey.pk8 -clientcert $postgres_clientcertfile 2>&1)
                retVal_verify_db_tmp=$?
                connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
                if [[ ! -z $connection_time ]]; then
                  echo "Latency: $connection_time ms"
                  # Check if elapsed time is greater than 10 ms using awk
                  if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
                    echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
                  elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
                    echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
                  elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
                    echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
                  fi
                fi

                [[ retVal_verify_db_tmp -ne 0 ]] && \
                warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -Djavax.net.ssl.trustStoreType=PKCS12 -cp \"${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode verify-ca -ca $postgres_cafile -clientkey ${dbcafolder}/clientkey.pk8 -clientcert $postgres_clientcertfile" && \
                fail "Unable to connect to database \"$dbname\" on database server \"$dbserver\", please check configuration again."
                [[ retVal_verify_db_tmp -eq 0 ]] && \
                success "Checked DB connection for \"$dbname\" on database server \"$dbserver\", PASSED!"
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
              output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -cp "${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd 2>&1)
              retVal_verify_db_tmp=$?
              connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
              if [[ ! -z $connection_time ]]; then
                echo "Latency: $connection_time ms"
                # Check if elapsed time is greater than 10 ms using awk
                if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
                  echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
                  echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
                  echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
                fi
              fi

              [[ retVal_verify_db_tmp -ne 0 ]] && \
              warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -cp \"${DB_JDBC_NAME}/db2jcc4.jar:${DB_CONNECTION_JAR_PATH}/DB2JDBCConnection.jar\" DB2Connection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ******" && \
              fail "Unable to connect to database \"$dbname\" on database host server \"$dbserver\", please check configuration again."
              [[ retVal_verify_db_tmp -eq 0 ]] && \
              success "Checked DB connection for \"$dbname\" on database host server \"$dbserver\", PASSED!"
              break
              ;;
          "oracle")                                                                                                                                 # -url "{{ oracle_url }}" -u {{ oracle_user }} -pwd {{ oracle_password_decoded }} -ssl -trustorefile {{trustorefile}} -trustoretype {{trustoretype}} -trustorePwd {{trustorePwd}}
              output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -cp "${DB_JDBC_NAME}/ojdbc8.jar:${DB_CONNECTION_JAR_PATH}/OracleJDBCConnection.jar" OracleConnection -url "$oracle_url" -u $dbuser -pwd $dbuserpwd 2>&1)
              retVal_verify_db_tmp=$?
              connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
              if [[ ! -z $connection_time ]]; then
                echo "Latency: $connection_time ms"
                # Check if elapsed time is greater than 10 ms using awk
                if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
                  echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
                  echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
                  echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
                fi
              fi

              [[ retVal_verify_db_tmp -ne 0 ]] && \
              warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -cp \"${DB_JDBC_NAME}/ojdbc8.jar:${DB_CONNECTION_JAR_PATH}/OracleJDBCConnection.jar\" OracleConnection -url \"$oracle_url\" -u $dbuser -pwd ******" && \
              echo -e  "\x1B[1;31mUnable to connect to database \"$dbuser\" using JDBC URL \"$oracle_url\", please check configuration again.\x1B[0m"
              [[ retVal_verify_db_tmp -eq 0 ]] && \
              success "Checked DB connection for \"$dbuser\" using JDBC URL \"$oracle_url\", PASSED!"
              break
              ;;
          "sqlserver")                                                                                                          # SQLConnection -h {{ database_servername }} -p {{ database_port }} -d {{ database_name }} -u {{ sqlserver_user }} -pwd {{ sqlserver_password_decoded }} -ssl 'encrypt=false'
              output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -cp "${DB_JDBC_NAME}/mssql-jdbc.jre8.jar:${DB_CONNECTION_JAR_PATH}/SQLJDBCConnection.jar" SQLConnection -h $dbserver -p $dbport -d $dbname -u $dbuser -pwd $dbuserpwd -ssl 'encrypt=false' 2>&1)
              retVal_verify_db_tmp=$?
              connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
              if [[ ! -z $connection_time ]]; then
                echo "Latency: $connection_time ms"
                # Check if elapsed time is greater than 10 ms using awk
                if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
                  echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
                  echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
                  echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
                fi
              fi
              [[ retVal_verify_db_tmp -ne 0 ]] && \
              warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -cp \"${DB_JDBC_NAME}/mssql-jdbc.jre8.jar:${DB_CONNECTION_JAR_PATH}/SQLJDBCConnection.jar\" SQLConnection -h $dbserver -p $dbport -d $dbname -u $dbuser -pwd ****** -ssl 'encrypt=false'" && \
              fail "Unable to connect to database \"$dbname\" on database host server \"$dbserver\", please check configuration again."
              [[ retVal_verify_db_tmp -eq 0 ]] && \
              success "Checked DB connection for \"$dbname\" on database host server \"$dbserver\", PASSED!"
              break
              ;;
          "postgresql")                                                                                                                                                                                    # -h {{ postgres_host }} -p {{ postgres_port }} -db {{ postgres_db }} -u {{ postgresql_server_user }} -pwd {{ postgres_pwd }} -sslmode require -ca {{ postgres_cafile}}
              output=$(java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -cp "${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd $dbuserpwd -sslmode disable 2>&1)
              retVal_verify_db_tmp=$?
              connection_time=$(echo $output | awk -F 'Round Trip time: ' '{print $2}' | awk '{print $1}')
              if [[ ! -z $connection_time ]]; then
                echo "Latency: $connection_time ms"
                # Check if elapsed time is greater than 10 ms using awk
                if [[ $(awk 'BEGIN { print ("'$connection_time'" < 10) }') -eq 1 ]]; then
                  echo "The latency is less than 10ms, which is acceptable performance for a simple DB operation."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 10 && "'$connection_time'" < 30) }') -eq 1 ]]; then
                  echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple DB operation, but the service is still accessible."
                elif [[ $(awk 'BEGIN { print ("'$connection_time'" > 30) }') -eq 1 ]]; then
                  echo "The latency exceeds 30ms for a simple DB operation, which indicates potential for failures."
                fi
              fi
              [[ retVal_verify_db_tmp -ne 0 ]] && \
              warning "Execute: java -Dsemeru.fips=$fips_flag -Duser.language=en -Duser.country=US -Dcom.ibm.jsse2.overrideDefaultTLS=true -cp \"${DB_JDBC_NAME}/postgresql-42.7.2.jar:${DB_CONNECTION_JAR_PATH}/PostgresJDBCConnection.jar\" PostgresConnection -h $dbserver -p $dbport -db $dbname -u $dbuser -pwd ****** -sslmode disable" && \
              fail "Unable to connect to database \"$dbname\" on database host server \"$dbserver\", please check configuration again."
              [[ retVal_verify_db_tmp -eq 0 ]] && \
              success "Checked DB connection for \"$dbname\" on database host server \"$dbserver\", PASSED!"
              break
              ;;
        esac
    done
  fi 
}
