#!/usr/bin/env bash

. ../common.sh

NUMOFSHARDS=2
# NFS_IP=172.16.243.23
#KUBE_NAME_SPACE=sp
# ENTRYPASSWORD='bacauser'
LOG_LEVEL=info
ROUTER_REPLICA=3
SHARD_REPLICA=3
CONFIG_REPLICA=3

CONFIG_PORT=27019
DB_SHARD_PORT=27018
ROUTER_PORT=27017

CONFIG_REPLSET_ADMIN_PREFIX="configReplSetAdmin"
current_templates_path="../../stable/ibm-dba-baca-prod/charts/mongoadmin-ha/templates"
current_base_path="../../stable/ibm-dba-baca-prod/charts/mongoadmin-ha"
#current_templates_path=$(pwd)/templates
#mkdir $current_templates_path
echo "Removing existing yaml before generating the new ones ...."
rm -rf $current_templates_path/*

#cp templates_base/local-storage-base.yaml templates/local-storage-base.yaml
cp templates_base/mongo-service-base.yaml $current_templates_path/mongo-service.yaml
cp values-base.yaml $current_base_path/values.yaml

echo LOG_LEVEL=$LOG_LEVEL
sed -i.bak s#\$LOG_LEVEL#$LOG_LEVEL# $current_base_path/values.yaml
echo "Replacing '<KUBE_NAME_SPACE>' with $KUBE_NAME_SPACE"
sed -i.bak s#\$KUBE_NAME_SPACE#$KUBE_NAME_SPACE# $current_base_path/values.yaml
echo "Replacing '<NFS_IP>' with $NFS_IP"
# sed -i.bak s#\$NFS_IP#$NFS_IP# values.yaml
sed -i.bak s#\$ROUTER_REPLICA#$ROUTER_REPLICA# $current_base_path/values.yaml
sed -i.bak s#\$SHARD_REPLICA#$SHARD_REPLICA# $current_base_path/values.yaml
sed -i.bak s#\$CONFIG_REPLICA#$CONFIG_REPLICA# $current_base_path/values.yaml
sed -i.bak s#\$LOGPVC#$LOGPVC# $current_base_path/values.yaml

if [ "$SSH_USER" = "root" ]; then
   export SUDO_CMD=""
else
   export SUDO_CMD="sudo"
fi

if [[ $PVCCHOICE == "1" ]]; then
    echo "Creating necessary folder in $NFS_IP..."
    cp templates_base/local-storage-base.yaml $current_templates_path/local-storage.yaml
    for i in `seq 0 $((CONFIG_REPLICA-1))`
    do
       ssh $SSH_USER@$NFS_IP -oStrictHostKeyChecking=no "$SUDO_CMD mkdir -p /exports/smartpages/$KUBE_NAME_SPACE/configdb-admin-${i}"
    done

    for i in `seq 0 $((NUMOFSHARDS-1))`
    do
        for j in `seq 0 $((SHARD_REPLICA-1))`
        do
             ssh $SSH_USER@$NFS_IP -oStrictHostKeyChecking=no "$SUDO_CMD mkdir -p /exports/smartpages/$KUBE_NAME_SPACE/mongodb-admin-shard${i}-${j}"
        done
    done

    ssh $SSH_USER@$NFS_IP -oStrictHostKeyChecking=no "$SUDO_CMD chown -R 51000:51001 /exports/smartpages/$KUBE_NAME_SPACE/*"

    echo "-----------------Creating pv and pvc by sp-persistence for shard admin-------------"
    for i in `seq 0 $((NUMOFSHARDS-1))`
    do
        for j in `seq 0 $((SHARD_REPLICA-1))`
        do
            sed -e "s/\$KUBE_NAME_SPACE/$KUBE_NAME_SPACE/g; s/\$SHARDX/${i}/g; s/\$COUNTER/${j}/g; s#\$NFS_IP#${NFS_IP}#g" \
            ./templates_base/shard-persistence-base.yaml> $current_templates_path/persistence-shard${i}-${j}.yaml
        done
    done

    echo "-------------Creating pv and pvc by sp-persistence for mongodb admin config-----------------"
    for i in `seq 0 $((CONFIG_REPLICA-1))`
    do
        sed -e "s/\$KUBE_NAME_SPACE/$KUBE_NAME_SPACE/g; s/\$COUNTER/${i}/g; s#\$NFS_IP#${NFS_IP}#g" ./templates_base/configdb-persistence-base.yaml> \
        $current_templates_path/configdb-persistence-${i}.yaml
    done
fi
echo "------------cp mongodb admin configsvr--------------------"
sed -e "s/\$KUBE_NAME_SPACE/$KUBE_NAME_SPACE/g; s/\$PORT_NUMBER/$PORT_NUMBER/g" ./templates_base/configdb-service-base.yaml> $current_templates_path/configdb-service.yaml

echo "------------cp mongodb admin shardX------------"
for i in `seq 0 $((NUMOFSHARDS-1))`
do
    sed -e "s/\$SHARDX/${i}/g" ./templates_base/shardX-stateful.yaml> $current_templates_path/shard${i}-stateful.yaml
done

echo "------------cp mongodb admin router(mongos)------------"
# !!!Replicas if your mongodb-admin-configdb has more than x>=3 replicas, please add mongodb-admin-configdb-{x-1}.mongodb-admin-configdb-service.${KUBE_NAME_SPACE}.svc.cluster.local:27019 in the end 
for i in `seq 0 $((CONFIG_REPLICA-1))`
do
   CONFIG_SERVER_LIST_S="${CONFIG_SERVER_LIST_S}mongodb-admin-configdb-${i}.mongodb-admin-configdb-service.${KUBE_NAME_SPACE}.svc.cluster.local:${CONFIG_PORT},"
done
CONFIG_SERVER_LIST_S=${CONFIG_SERVER_LIST_S:: -1}
CONFIG_REPLSET_VALUE="${CONFIG_REPLSET_ADMIN_PREFIX}/${CONFIG_SERVER_LIST_S}"
echo "CONFIG_REPLSET_VALUE=${CONFIG_REPLSET_VALUE}"
#CONFIG_REPLSET_VALUE="configReplSetAdmin/mongodb-admin-configdb-0.mongodb-admin-configdb-service.${KUBE_NAME_SPACE}.svc.cluster.local:27019,mongodb-admin-configdb-1.mongodb-admin-configdb-service.${KUBE_NAME_SPACE}.svc.cluster.local:27019,mongodb-admin-configdb-2.mongodb-admin-configdb-service.${KUBE_NAME_SPACE}.svc.cluster.local:27019"
sed -i.bak s#\$CONFIG_REPLSET_VALUE#$CONFIG_REPLSET_VALUE# $current_base_path/values.yaml
cp ./templates_base/mongos-router-base.yaml $current_templates_path/mongos-router.yaml
