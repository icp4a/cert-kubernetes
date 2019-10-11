#!/usr/bin/env bash

. ../common.sh

NUMOFSHARDS=2

#LOG_LEVEL=info
ROUTER_REPLICA=3
SHARD_REPLICA=3
CONFIG_REPLICA=3

CONFIG_PORT=27019
DB_SHARD_PORT=27018
ROUTER_PORT=27017
CONFIG_REPLSET_PREFIX="configReplSet"

ADD_SHARD='./js_base/add_shard.js'
MONGO_INIT='./js_base/mongo_initiate.js'

for i in `seq 0 $((CONFIG_REPLICA-1))`
do
   CONFIG_SERVER_LIST_S="${CONFIG_SERVER_LIST_S}mongodb-configdb-${i}.mongodb-configdb-service.${KUBE_NAME_SPACE}.svc.cluster.local:${CONFIG_PORT},"
done
CONFIG_SERVER_LIST_S=${CONFIG_SERVER_LIST_S:: -1}
echo "CONFIG_SERVER_LIST_S=${CONFIG_SERVER_LIST_S}"

echo "Waiting for all the shards and configdb containers up running"
sleep 30
echo -n "  "
until kubectl exec mongodb-configdb-$((CONFIG_REPLICA-1)) --namespace=${KUBE_NAME_SPACE} -c mongodb-configdb-container -- mongo --host 127.0.0.1 --port ${CONFIG_PORT} --ssl --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done

echo -n "  "
for i in `seq 0 $((NUMOFSHARDS-1))`
do
    until kubectl exec mongodb-shard${i}-$((SHARD_REPLICA-1)) --namespace=${KUBE_NAME_SPACE} -c mongod-shard${i}-container -- mongo --host 127.0.0.1 --port ${DB_SHARD_PORT} --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --quiet --eval 'db.getMongo()'; do
         sleep 5
         echo -n "  "
    done
done
echo "...shards & configdb containers are now running"
echo

sleep 90

for i in `seq 0 $((NUMOFSHARDS-1))`
do
    for j in `seq 0 $((SHARD_REPLICA-1))`
    do
        shard_temp="${shard_temp}mongodb-shard${i}-${j}.mongodb-shard${i}-service.${KUBE_NAME_SPACE}.svc.cluster.local:${DB_SHARD_PORT},"
    done
    SHARD_STRING[${i}]=${shard_temp:: -1}
    unset shard_temp
done

echo "start to initiate config server replicas"
echo

cat $MONGO_INIT | sed s#\$SERVER_LIST_S#"$CONFIG_SERVER_LIST_S"# | sed s#\$CFG_ID#"${CONFIG_REPLSET_PREFIX}"# > mongo_initiate_config.js
kubectl cp mongo_initiate_config.js ${KUBE_NAME_SPACE}/mongodb-configdb-0:/tmp/

kubectl exec mongodb-configdb-0 --namespace=${KUBE_NAME_SPACE} -c mongodb-configdb-container -- mongo --host 127.0.0.1 --port ${CONFIG_PORT} --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem /tmp/mongo_initiate_config.js

echo "start to initiate shard server replicas"
echo

for i in `seq 0 $((NUMOFSHARDS-1))`
do
    cat $MONGO_INIT | sed s#\$SERVER_LIST_S#"${SHARD_STRING[$i]}"# | sed s#\$CFG_ID#"rs\-shard$i"# > mongo_initiate_shard${i}.js
    kubectl cp mongo_initiate_shard${i}.js ${KUBE_NAME_SPACE}/mongodb-shard${i}-0:/tmp/mongo_initiate_shard.js
    kubectl exec mongodb-shard${i}-0 --namespace=${KUBE_NAME_SPACE} -c mongod-shard${i}-container -- mongo --host 127.0.0.1 --port ${DB_SHARD_PORT} --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem /tmp/mongo_initiate_shard.js
done


echo "Wait for each MongoDB Shard's Replica Set + the ConfigDB Replica Set to each have a primary ready"

kubectl exec mongodb-configdb-0 --namespace=${KUBE_NAME_SPACE} -c mongodb-configdb-container -- mongo --host 127.0.0.1 --port ${CONFIG_PORT} --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --quiet --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
for i in `seq 0 $((NUMOFSHARDS-1))`
do
    kubectl exec mongodb-shard${i}-0 --namespace=${KUBE_NAME_SPACE} -c mongod-shard${i}-container -- mongo --host 127.0.0.1 --port ${DB_SHARD_PORT} --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
done

echo "...initialisation of the MongoDB shard Replica Sets completed"
echo


echo "Waiting for the first mongos router to up and run"
echo -n "  "
until kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) -c mongos-router-container -- mongo --host 127.0.0.1 --port ${ROUTER_PORT} --ssl --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --quiet --eval 'db.getMongo()'; do
    sleep 2
    echo -n "  "
done
echo "...first mongos router is now running"
echo

echo "start to add shard replicas"
echo
for i in `seq 0 $((NUMOFSHARDS-1))`
do
    cat $ADD_SHARD | sed s#\$SHARD_LIST_S#"${SHARD_STRING[$i]}"# | sed s#\$SHARD_ID#"rs\-shard$i"# > add_shard${i}.js
    kubectl cp add_shard${i}.js ${KUBE_NAME_SPACE}/$(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ):/tmp/add_shard.js
    kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) -c  mongos-router-container \
    -- mongo --host 127.0.0.1 --port ${ROUTER_PORT} --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem \
    --authenticationMechanism=MONGODB-X509 --authenticationDatabase='$external' /tmp/add_shard.js
done


# # --------------create admin user start------------------------

 kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) -- bash -c \
 'echo "db.getSiblingDB(\"admin\").createUser({user:mongo_initdb_root_username,pwd:entrypassword,roles:[{role:\"root\",db:\"admin\"}, {role:\"clusterAdmin\",db:\"admin\"}]});" > mongo_create_admin.js;'

 kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
 -- bash -c  'echo mongo --host 127.0.0.1 --port 27017 --sslAllowInvalidCertificates --ssl --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --eval \"var mongo_initdb_root_username="'"'MONGO_INITDB_ROOT_USERNAME'"'",entrypassword="'"'ENTRYPASSWORD'"'"\" mongo_create_admin.js  > mongo_create_admin_bak.sh'

 kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
 -- bash -c  'cat mongo_create_admin_bak.sh | sed s/MONGO_INITDB_ROOT_USERNAME/$MONGO_INITDB_ROOT_USERNAME/g | sed s/ENTRYPASSWORD/$ENTRYPASSWORD/g  > mongo_create_admin.sh'

 kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
 -- bash -c 'sh mongo_create_admin.sh && rm mongo_create_admin.js mongo_create_admin.sh mongo_create_admin_bak.sh'

# # --------------create admin user end------------------------

sleep 10

# # --------------create regular user start------------------------


 kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) -- bash -c \
 'echo "db.createUser({user:mongo_user,pwd:mongo_password,roles:[{role:\"readWrite\",db:mongo_initdb}, {role:\"readWrite\",db:mongo_seconddb}, {role:\"readWrite\", db:\"cronjobs\"}, {role:\"readWrite\",db:\"smartpages\"}]});" > mongo_create_user.js;'

 kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
 -- bash -c  'echo mongo --host 127.0.0.1 --port 27017 $MONGO_INITDB --sslAllowInvalidCertificates --ssl --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem -u $MONGO_INITDB_ROOT_USERNAME -p $ENTRYPASSWORD --authenticationDatabase admin --eval \"var mongo_user="'"'MONGO_USER'"'",  mongo_password="'"'MONGO_PASSWORD'"'", mongo_initdb="'"'MONGO_INITDB'"'", mongo_seconddb="'"'MONGO_SECONDDB'"'"\" mongo_create_user.js > mongo_create_user_bak.sh'

 kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
 -- bash -c  'cat mongo_create_user_bak.sh | sed s/MONGO_USER/$MONGO_USER/g | sed s/MONGO_PASSWORD/$MONGO_PASSWORD/g | sed s/MONGO_INITDB/$MONGO_INITDB/g | sed s/MONGO_SECONDDB/$MONGO_SECONDDB/g > mongo_create_user.sh'

 kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
 -- bash -c 'sh mongo_create_user.sh && rm mongo_create_user.js mongo_create_user.sh mongo_create_user_bak.sh'

echo "==================Done============================"