#!/bin/bash

set -e

echo This script is designed to recover an IBM Business Automation Insights cluster on minikube if persisted checkpoints are corrupted, typically in case of virtual machine sudden stop.
echo WARNING: Elasticsearch data will be recovered, but the Flink state will be reset, therefore the result of the processing is likely to be lost for the last events.

if [ `which jq | wc -l` == "0" ]
    then
    echo ERROR: jq is required to run this script, please install it on your system: https://stedolan.github.io/jq/
    exit 1
fi

echo "Backing up previous flink data in /data/bai.saved..."
minikube ssh "sudo cp -r /data/bai/ /data/bai.saved"

echo "Removing flink related content..."
minikube ssh "sudo rm -rf /data/bai/checkpoints/*"
minikube ssh "sudo rm -rf /data/bai/recovery/*"
minikube ssh "sudo rm -rf /data/bai/savepoints/*"
minikube ssh "sudo rm -rf /data/bai/flink-zookeeper/*"

echo "Restarting jobmanager and zookeeper pods..."
JOB_MANAGER_POD=`kubectl get pods -n bai | egrep jobmanager | awk '{print $1}'`
ZK_POD=`kubectl get pods -n bai | egrep flink-zk | awk '{print $1}'`
kubectl delete pod $JOB_MANAGER_POD -n bai
kubectl delete pod $ZK_POD -n bai

PILLAR_LIST=`kubectl get pods -n bai | grep -v "dba" | grep -v flink | grep -v admin | grep -v setup | grep bai | cut -d " " -f 1 | cut -d "-" -f -4 | sort -u`

for p in $PILLAR_LIST
do
    echo "Restarting pillar job $p..."
    kubectl get job $p -o json -n bai |  jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | kubectl replace --force -f -
done
