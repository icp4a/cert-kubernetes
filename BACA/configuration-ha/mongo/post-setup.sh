. ../../common.sh

NUMOFSHARDS=2
# NFS_IP=172.16.243.23
#KUBE_NAME_SPACE=sp
# ENTRYPASSWORD='bacauser'
LOG_LEVEL=info
ROUTER_REPLICA=3
SHARD_REPLICA=3
CONFIG_REPLICA=3

echo
echo "Waiting for all the shards and configdb containers up running"
sleep 30
echo -n "  "
until kubectl exec mongodb-configdb-$((CONFIG_REPLICA-1)) --namespace=${KUBE_NAME_SPACE} -c mongodb-configdb-container -- mongo --host 127.0.0.1 --port 27019 --ssl --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done

echo -n "  "
until kubectl exec mongodb-shard0-$((SHARD_REPLICA-1)) --namespace=${KUBE_NAME_SPACE} -c mongod-shard0-container -- mongo --host 127.0.0.1 --port 27018 --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done
echo -n "  "
until kubectl exec mongodb-shard1-$((SHARD_REPLICA-1)) --namespace=${KUBE_NAME_SPACE} -c mongod-shard1-container -- mongo --host 127.0.0.1 --port 27018 --ssl --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done
echo "...shards & configdb containers are now running"
echo

sleep 90

echo "Configuring Config Server Replica Sets"
# !!!Replicas if your mongodb-configdb has more than x>=3 replicas, please add {_id: [x-1], host: "mongodb-configdb-[x-1].mongodb-configdb-service.{KUBE_NAME_SPACE}.svc.cluster.local:27019"} after _id: 2 
# !!!Namespace: if you have different namespace {NAME_SPACE}, please add {_id: 2, host: "mongodb-shard0-2.mongodb-shard0-service.{NAME_SPACE}.svc.cluster.local:27018"} 
kubectl exec mongodb-configdb-0 --namespace=${KUBE_NAME_SPACE} -c mongodb-configdb-container -- mongo --host 127.0.0.1 --port 27019 --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --eval 'rs.initiate({_id: "configReplSet", version: 1, members: [ {_id: 0, host: "mongodb-configdb-0.mongodb-configdb-service.sp.svc.cluster.local:27019"}, {_id: 1, host: "mongodb-configdb-1.mongodb-configdb-service.sp.svc.cluster.local:27019"}, {_id: 2, host: "mongodb-configdb-2.mongodb-configdb-service.sp.svc.cluster.local:27019"} ]});'

echo "Configuring shardX Replica Sets" 
# !!!Replicas: if your mongodb-configdb has more than x>=3 replicas, please add {_id: 2, host: "mongodb-shard0-{x-1}.mongodb-shard0-service.{KUBE_NAME_SPACE}.svc.cluster.local:27018"} after _id: 2 
# !!!Namespace: if you have different namespace {s}, please add {_id: 2, host: "mongodb-shard0-2.mongodb-shard0-service.{s}.svc.cluster.local:27018"} 
kubectl exec mongodb-shard0-0 --namespace=${KUBE_NAME_SPACE} -c mongod-shard0-container -- mongo --host 127.0.0.1 --port 27018 --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --eval 'rs.initiate({_id: "rs-shard0", version: 1, members: [ {_id: 0, host: "mongodb-shard0-0.mongodb-shard0-service.sp.svc.cluster.local:27018"}, {_id: 1, host: "mongodb-shard0-1.mongodb-shard0-service.sp.svc.cluster.local:27018"}, {_id: 2, host: "mongodb-shard0-2.mongodb-shard0-service.sp.svc.cluster.local:27018"} ]});'
kubectl exec mongodb-shard1-0 --namespace=${KUBE_NAME_SPACE} -c mongod-shard1-container -- mongo --host 127.0.0.1 --port 27018 --ssl --sslAllowInvalidCertificates  --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --eval 'rs.initiate({_id: "rs-shard1", version: 1, members: [ {_id: 0, host: "mongodb-shard1-0.mongodb-shard1-service.sp.svc.cluster.local:27018"}, {_id: 1, host: "mongodb-shard1-1.mongodb-shard1-service.sp.svc.cluster.local:27018"}, {_id: 2, host: "mongodb-shard1-2.mongodb-shard1-service.sp.svc.cluster.local:27018"} ]});'

echo "Wait for each MongoDB Shard's Replica Set + the ConfigDB Replica Set to each have a primary ready"

kubectl exec mongodb-configdb-0 --namespace=${KUBE_NAME_SPACE} -c mongodb-configdb-container -- mongo --host 127.0.0.1 --port 27019 --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --quiet --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
kubectl exec mongodb-shard0-0 --namespace=${KUBE_NAME_SPACE} -c mongod-shard0-container -- mongo --host 127.0.0.1 --port 27018 --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
kubectl exec mongodb-shard1-0 --namespace=${KUBE_NAME_SPACE} -c mongod-shard1-container -- mongo --host 127.0.0.1 --port 27018 --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'

sleep 2 # Just a little more sleep to ensure everything is ready!
echo "...initialisation of the MongoDB shard Replica Sets completed"
echo


# Wait for the mongos to have started properly
echo "Waiting for the first mongos router to up and run"
echo -n "  "
until kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) -c mongos-router-container -- mongo --host 127.0.0.1 --port 27017 --ssl --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --quiet --eval 'db.getMongo()'; do
    sleep 2
    echo -n "  "
done
echo "...first mongos router is now running (`date`)"
echo
# !!!Namespace: if you have different namespace {NAME_SPACE}, please change rs-shard0/mongodb-shard0-0.mongodb-shard0-service.{NAME_SPACE}.svc.cluster.local:27018
kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) -c  mongos-router-container \
-- mongo --host 127.0.0.1 --port 27017 --ssl --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --authenticationMechanism=MONGODB-X509 --authenticationDatabase='$external' --eval \
'sh.addShard("rs-shard0/mongodb-shard0-0.mongodb-shard0-service.sp.svc.cluster.local:27018");'

# !!!Namespace: if you have different namespace {NAME_SPACE}, please change rs-shard1/mongodb-shard1-0.mongodb-shard1-service.{NAME_SPACE}.svc.cluster.local:27018
kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) -c  mongos-router-container \
-- mongo --host 127.0.0.1 --port 27017 --ssl  --sslAllowInvalidCertificates --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --authenticationMechanism=MONGODB-X509 --authenticationDatabase='$external' --eval \
'sh.addShard("rs-shard1/mongodb-shard1-0.mongodb-shard1-service.sp.svc.cluster.local:27018");'


# --------------create admin user start------------------------
kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) -- bash -c \
'echo "db.getSiblingDB(\"admin\").createUser({user:mongo_initdb_root_username,pwd:entrypassword,roles:[{role:\"root\",db:\"admin\"}, {role:\"clusterAdmin\",db:\"admin\"}]});" > mongo_create_admin.js;'

kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
-- bash -c  'echo mongo --host 127.0.0.1 --port 27017 --sslAllowInvalidCertificates --ssl --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem --eval \"var mongo_initdb_root_username="'"'MONGO_INITDB_ROOT_USERNAME'"'",entrypassword="'"'ENTRYPASSWORD'"'"\" mongo_create_admin.js  > mongo_create_admin_bak.sh'

kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
-- bash -c  'cat mongo_create_admin_bak.sh | sed s/MONGO_INITDB_ROOT_USERNAME/$MONGO_INITDB_ROOT_USERNAME/g | sed s/ENTRYPASSWORD/$ENTRYPASSWORD/g  > mongo_create_admin.sh'

kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
-- bash -c 'sh mongo_create_admin.sh && rm mongo_create_admin.js mongo_create_admin.sh mongo_create_admin_bak.sh'

# --------------create admin user end------------------------

sleep 10

# --------------create regular user start------------------------


kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) -- bash -c \
'echo "db.createUser({user:mongo_user,pwd:mongo_password,roles:[{role:\"readWrite\",db:mongo_initdb}, {role:\"readWrite\",db:mongo_seconddb}, {role:\"readWrite\", db:\"cronjobs\"}, {role:\"readWrite\",db:\"smartpages\"}]});" > mongo_create_user.js;'

kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
-- bash -c  'echo mongo --host mongos-service.sp.svc.cluster.local --port 27017 $MONGO_INITDB --sslAllowInvalidCertificates --ssl --sslPEMKeyFile /etc/certs/mongo.key --sslCAFile /etc/certs/mongo.pem -u $MONGO_INITDB_ROOT_USERNAME -p $ENTRYPASSWORD --authenticationDatabase admin --eval \"var mongo_user="'"'MONGO_USER'"'",  mongo_password="'"'MONGO_PASSWORD'"'", mongo_initdb="'"'MONGO_INITDB'"'", mongo_seconddb="'"'MONGO_SECONDDB'"'"\" mongo_create_user.js > mongo_create_user_bak.sh'

kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
-- bash -c  'cat mongo_create_user_bak.sh | sed s/MONGO_USER/$MONGO_USER/g | sed s/MONGO_PASSWORD/$MONGO_PASSWORD/g | sed s/MONGO_INITDB/$MONGO_INITDB/g | sed s/MONGO_SECONDDB/$MONGO_SECONDDB/g > mongo_create_user.sh'

kubectl exec --namespace=${KUBE_NAME_SPACE} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${KUBE_NAME_SPACE} ) \
-- bash -c 'sh mongo_create_user.sh && rm mongo_create_user.js mongo_create_user.sh mongo_create_user_bak.sh'

# --------------create regular user end------------------------

# echo "expose mongos router"
# kubectl expose deployment mongos-router --type=ClusterIP --name=mongos-service

# --------------------mongodb shard javascript function--------------------
# sh.enableSharding("test");
# sh.shardCollection("test.testcoll", {"myfield": 1});
# use test;
# db.testcoll.insert({"myfield": "a", "otherfield": "b"});
# db.testcoll.find();
# sh.status();
