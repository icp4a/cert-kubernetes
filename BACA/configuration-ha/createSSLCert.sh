#!/usr/bin/env bash

#
# Licensed Materials - Property of IBM
# 6949-68N
#
# © Copyright IBM Corp. 2018 All Rights Reserved
#


function createSSLCert() {
    rm -r *.crt *.pem *.key || true

    echo -e "\x1B[1;32mAbout to create a self-signed SSL cert for ingress, celery, mongo, redis, rabbitmq....\x1B[0m"
    echo "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/tls.key -out $PWD/tls.crt -subj "/CN=127.0.0.1" "
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/tls.key -out $PWD/tls.crt -subj "/CN=127.0.0.1"
    cat $PWD/tls.key $PWD/tls.crt > $PWD/tls.pem

    echo "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/celery.key -out $PWD/celery.crt -subj "/CN=127.0.0.1" "
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/celery.key -out $PWD/celery.crt -subj "/CN=127.0.0.1"
    cat $PWD/celery.key $PWD/celery.crt > $PWD/celery.pem
    if [[ $HA_ENABLE = false  ]]; then
        echo "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/mongo.key -out $PWD/mongo.crt -subj "/CN=127.0.0.1" "
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/mongo.key -out $PWD/mongo.crt -subj "/CN=127.0.0.1"
        cat $PWD/mongo.key $PWD/mongo.crt  > $PWD/mongo.pem
    else
        echo "create mongo and mongo admin cluster certifications"
        CERT_DOMAIN="svc.cluster.local"
        openssl genrsa -out $PWD/CA.key 4096
        openssl req -new -x509 -days 365 -key $PWD/CA.key -out $PWD/CA.crt \
            -subj "/C=CA/ST=NS/L=Halifax/O=IBM/CN=IBM baca" 
        openssl genrsa -out $PWD/certificate.key 4096
        openssl req -new -nodes -key $PWD/certificate.key -out $PWD/certificate.csr -config $PWD/openssl.cnf -extensions v3_req \
            -subj "/C=CA/ST=NS/L=Halifax/O=IBM/CN=*.${KUBE_NAME_SPACE}.${CERT_DOMAIN}" 
        openssl x509 -req -days 365 -in $PWD/certificate.csr -CA $PWD/CA.crt -CAkey $PWD/CA.key -set_serial 01 -out $PWD/certificate.crt
        cat $PWD/certificate.key $PWD/certificate.crt > $PWD/mongo.key
        cat $PWD/CA.key $PWD/CA.crt > $PWD/mongo.pem
        cp $PWD/certificate.crt $PWD/mongo.crt
    fi

    echo "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/public.crt -out $PWD/public.crt -subj "/CN=127.0.0.1" "
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/private.key -out $PWD/public.crt -subj "/CN=127.0.0.1"

    echo "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/redis.key -out $PWD/redis.crt -subj "/CN=127.0.0.1" "
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/redis.key -out $PWD/redis.crt -subj "/CN=127.0.0.1"
    cat $PWD/redis.key $PWD/redis.crt > $PWD/redis.pem
    echo "changing file permissions for redis.key ..."
    chmod 600 $PWD/redis.key

    echo "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/rabbitmq.key -out $PWD/rabbitmq.crt -subj "/CN=127.0.0.1" "
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $PWD/rabbitmq.key -out $PWD/rabbitmq.crt -subj "/CN=127.0.0.1"
    cat $PWD/rabbitmq.key $PWD/rabbitmq.crt > $PWD/rabbitmq.pem


}
function createSecret (){

    echo -e "\x1B[1;32mAbout to create a secrets for ingress, celery, mongo, redis, rabbitmq....\x1B[0m"
    echo "kubectl -n $KUBE_NAME_SPACE create secret tls baca-ingress-secret --key $PWD/tls.key --cert $PWD/tls.crt"
    kubectl -n $KUBE_NAME_SPACE create secret tls baca-ingress-secret --key $PWD/tls.key --cert $PWD/tls.crt \
    --dry-run -o yaml | kubectl apply -f -

#    if [[ $DB_SSL == "y" || $DB_SSL == "Y" ]]; then
#        echo "kubectl -n sp create secret generic baca-db2-secret --from-file=$PWD/db2-cert.arm"
#        kubectl -n sp create secret generic baca-db2-secret --from-file=$PWD/db2-cert.arm
#    fi
    if [[ ($LDAP_URL =~ ^'ldaps' && ! -z $LDAP_CRT_NAME) && ($DB_SSL == "n")  ]]; then
        echo "kubectl -n $KUBE_NAME_SPACE create secret generic with LDAP certs AND no DB2 cert "
        kubectl -n $KUBE_NAME_SPACE create secret generic baca-secrets$KUBE_NAME_SPACE \
        --from-file=$PWD/celery.pem --from-file=$PWD/celery.crt --from-file=$PWD/celery.key \
        --from-file=$PWD/mongo.pem --from-file=$PWD/mongo.crt --from-file=$PWD/mongo.key \
        --from-file=$PWD/public.crt --from-file=$PWD/private.key \
        --from-file=$PWD/redis.pem --from-file=$PWD/redis.key --from-file=$PWD/redis.crt \
        --from-file=$PWD/rabbitmq.pem --from-file=$PWD/rabbitmq.key --from-file=$PWD/rabbitmq.crt \
        --from-file=$PWD/$LDAP_CRT_NAME \
        --dry-run -o yaml | kubectl apply -f -
    elif [[ ($LDAP_URL =~ ^'ldaps' && ! -z $LDAP_CRT_NAME) && ($DB_SSL == "y"  && ! -z $DB_CRT_NAME) ]]; then
        echo "kubectl -n $KUBE_NAME_SPACE create secret generic with DB certs AND LDAP certs "
        kubectl -n $KUBE_NAME_SPACE create secret generic baca-secrets$KUBE_NAME_SPACE \
        --from-file=$PWD/celery.pem --from-file=$PWD/celery.crt --from-file=$PWD/celery.key \
        --from-file=$PWD/mongo.pem --from-file=$PWD/mongo.crt --from-file=$PWD/mongo.key \
        --from-file=$PWD/public.crt --from-file=$PWD/private.key \
        --from-file=$PWD/redis.pem --from-file=$PWD/redis.key --from-file=$PWD/redis.crt \
        --from-file=$PWD/rabbitmq.pem --from-file=$PWD/rabbitmq.key --from-file=$PWD/rabbitmq.crt \
        --from-file=$PWD/$LDAP_CRT_NAME \
        --from-file=$PWD/$DB_CRT_NAME \
        --dry-run -o yaml | kubectl apply -f -
    elif [[ ($DB_SSL == "y"  && ! -z $DB_CRT_NAME) && ($LDAP_URL != ^'ldaps') ]]; then
        echo "kubectl -n $KUBE_NAME_SPACE create secret generic with DB certs AND NO LDAP certs "
        kubectl -n $KUBE_NAME_SPACE create secret generic baca-secrets$KUBE_NAME_SPACE \
        --from-file=$PWD/celery.pem --from-file=$PWD/celery.crt --from-file=$PWD/celery.key \
        --from-file=$PWD/mongo.pem --from-file=$PWD/mongo.crt --from-file=$PWD/mongo.key \
        --from-file=$PWD/public.crt --from-file=$PWD/private.key \
        --from-file=$PWD/redis.pem --from-file=$PWD/redis.key --from-file=$PWD/redis.crt \
        --from-file=$PWD/rabbitmq.pem --from-file=$PWD/rabbitmq.key --from-file=$PWD/rabbitmq.crt \
        --from-file=$PWD/$DB_CRT_NAME \
        --dry-run -o yaml | kubectl apply -f -
    else
        echo "kubectl -n $KUBE_NAME_SPACE create secret generic with no LDAP and DB2 certs"
        kubectl -n $KUBE_NAME_SPACE create secret generic baca-secrets$KUBE_NAME_SPACE \
        --from-file=$PWD/celery.pem --from-file=$PWD/celery.crt --from-file=$PWD/celery.key \
        --from-file=$PWD/mongo.pem --from-file=$PWD/mongo.crt --from-file=$PWD/mongo.key \
        --from-file=$PWD/public.crt --from-file=$PWD/private.key \
        --from-file=$PWD/redis.pem --from-file=$PWD/redis.key --from-file=$PWD/redis.crt \
        --from-file=$PWD/rabbitmq.pem --from-file=$PWD/rabbitmq.key --from-file=$PWD/rabbitmq.crt \
        --dry-run -o yaml | kubectl apply -f -
    fi

}
function createMongoSecrets (){
echo -e "\x1B[1;32mAbout to create mongo Secrets....\x1B[0m"
if [[ -z "$MONGOADMINENTRYPASSWORD" && -z "$MONGOADMINUSER" && -z "$MONGOADMINPASSWORD" ]]; then
    echo -e "\x1B[1;32mCreating mongo admin Secrets using random values....\x1B[0m"
    export MONGOADMINENTRYPASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-29)
    export MONGOADMINUSER=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-29)
    export MONGOADMINPASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-29)

    kubectl -n $KUBE_NAME_SPACE create secret generic baca-mongo-admin \
    --from-literal=MONGOADMINENTRYPASSWORD="$MONGOADMINENTRYPASSWORD" \
    --from-literal=MONGOADMINUSER="$MONGOADMINUSER" \
    --from-literal=MONGOADMINPASSWORD="$MONGOADMINPASSWORD" \
    --dry-run -o yaml | kubectl apply -f -
else
    echo -e "\x1B[1;32mCreating mongo admin Secret based on custom values for MONGOADMINENTRYPASSWORD, MONGOADMINUSER, MONGOADMINPASSWORD\x1B[0m"
    kubectl -n $KUBE_NAME_SPACE create secret generic mongo-admin \
    --from-literal=MONGOADMINENTRYPASSWORD="$MONGOADMINENTRYPASSWORD" \
    --from-literal=MONGOADMINUSER="$MONGOADMINUSER" \
    --from-literal=MONGOADMINPASSWORD="$MONGOADMINPASSWORD" \
    --dry-run -o yaml | kubectl apply -f -
fi

if [[ -z "$MONGOENTRYPASSWORD" && -z "$MONGOUSER" && -z "$MONGOPASSWORD"  ]] ; then
    echo -e "\x1B[1;32mCreating mongo Secrets using random values....\x1B[0m"
    export MONGOENTRYPASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-29)
    export MONGOUSER=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-29)
    export MONGOPASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-29)
    kubectl -n $KUBE_NAME_SPACE create secret generic baca-mongo \
    --from-literal=MONGOENTRYPASSWORD="$MONGOENTRYPASSWORD" \
    --from-literal=MONGOUSER="$MONGOUSER" \
    --from-literal=MONGOPASSWORD="$MONGOPASSWORD" \
    --dry-run -o yaml | kubectl apply -f -
else
    echo -e "\x1B[1;32mCreating mongo  Secret based on custom values for MONGOENTRYPASSWORD, MONGOUSER, MONGOPASSWORD\x1B[0m"
    kubectl -n $KUBE_NAME_SPACE create secret generic mongo \
    --from-literal=MONGOENTRYPASSWORD="$MONGOENTRYPASSWORD" \
    --from-literal=MONGOUSER="$MONGOUSER" \
    --from-literal=MONGOPASSWORD="$MONGOPASSWORD" \
    --dry-run -o yaml | kubectl apply -f -
fi

}
function createLDAPSecret(){

if [[ $LDAP == "y" && $LDAP_PASSWORD != "" ]]; then
    echo -e "\x1B[1;32mAbout to create LDAP Secret....\x1B[0m"
    echo -e "\x1B[1;32mCreating LDAP Secret....\x1B[0m"
    export LDAP_PASSWORD_DECODE=$(echo $LDAP_PASSWORD | base64 --decode)
    kubectl -n $KUBE_NAME_SPACE create secret generic baca-ldap \
    --from-literal=LDAP_PASSWORD="$LDAP_PASSWORD_DECODE" \
    --dry-run -o yaml | kubectl apply -f -
fi

}
function createBaseDbSecret(){
echo -e "\x1B[1;32mAbout to create secret for Base DB....\x1B[0m"
if [[ -z $BASE_DB_PWD ]]; then
    echo -e "\x1B[1;32m Cannot find BASED_DB_PWD from common.sh..Exiting !!\x1B[0m"
    exit 1
else
    echo -e "\x1B[1;32mCreating Base DB secret....\x1B[0m"
    kubectl -n $KUBE_NAME_SPACE create secret generic baca-basedb \
    --from-literal=BASE_DB_PWD="$BASE_DB_PWD" \
    --dry-run -o yaml | kubectl apply -f -
fi
}

function createRabbitmaSecret(){
echo -e "\x1B[1;32mAbout to create secret for RabbitMQ....\x1B[0m"

export rabbitmq_admin_password=$(openssl rand -base64 10 | tr -d "=+/" | cut -c1-29)
export rabbitmq_erlang_cookie=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-29)
export rabbitmq_password=$(openssl rand -base64 10 | tr -d "=+/" | cut -c1-29)
export rabbitmq_user=$(openssl rand -base64 6 | tr -d "=+/" | cut -c1-29)
export rabbitmq_management_password=$(openssl rand -base64 10 | tr -d "=+/" | cut -c1-29)
export rabbitmq_management_user=$(openssl rand -base64 6 | tr -d "=+/" | cut -c1-29)

kubectl -n $KUBE_NAME_SPACE create secret generic baca-rabbitmq \
--from-literal=rabbitmq-admin-password="$rabbitmq_admin_password" \
--from-literal=rabbitmq-erlang-cookie="$rabbitmq_erlang_cookie" \
--from-literal=rabbitmq-password="$rabbitmq_password" \
--from-literal=rabbitmq-user="$rabbitmq_user" \
--from-literal=rabbitmq-management-password="$rabbitmq_management_password" \
--from-literal=rabbitmq-management-user="$rabbitmq_management_user" \
--dry-run -o yaml | kubectl apply -f -


}

function createRedisSecret(){
echo -e "\x1B[1;32mAbout to create secret for Redis....\x1B[0m"
export redis_password=$(openssl rand -base64 10 | tr -d "=+/" | cut -c1-29)
kubectl -n $KUBE_NAME_SPACE create secret generic baca-redis \
--from-literal=redis-password="$redis_password" \
--dry-run -o yaml | kubectl apply -f -
}