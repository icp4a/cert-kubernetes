#!/bin/bash

BAI_NAMESPACE="bai"
KAFKA_NAMESPACE="kafka"
LOG_DIR="./logs"

echo "Creating logs directory"

mkdir -p ${LOG_DIR}

echo "Retrieving logs for Kafka components"
kubectl logs $(kubectl get pods -n ${KAFKA_NAMESPACE} | grep kafka-release-cp-kafka- | awk '{print $1}') cp-kafka-broker  -n ${KAFKA_NAMESPACE} > ${LOG_DIR}/kafka.log
kubectl logs -p $(kubectl get pods -n ${KAFKA_NAMESPACE} | grep kafka-release-cp-kafka- | awk '{print $1}') cp-kafka-broker  -n ${KAFKA_NAMESPACE} > ${LOG_DIR}/kafka.previous.log
kubectl logs $(kubectl get pods -n ${KAFKA_NAMESPACE} | grep kafka-release-cp-zookeeper- | awk '{print $1}') cp-zookeeper-server  -n ${KAFKA_NAMESPACE} > ${LOG_DIR}/kafka-zookeeper.log
kubectl logs -p $(kubectl get pods -n ${KAFKA_NAMESPACE} | grep kafka-release-cp-zookeeper- | awk '{print $1}') cp-zookeeper-server  -n ${KAFKA_NAMESPACE} > ${LOG_DIR}/kafka-zookeeper.previous.log

echo "Retrieving logs for Elasticsearch components"
kubectl logs $(kubectl get pods -n ${BAI_NAMESPACE} | grep bai-release-ibm-dba-ek-master- | awk '{print $1}') -n ${BAI_NAMESPACE} > ${LOG_DIR}/elasticsearch-master.log
kubectl logs -p $(kubectl get pods -n ${BAI_NAMESPACE} | grep bai-release-ibm-dba-ek-master- | awk '{print $1}') -n ${BAI_NAMESPACE} > ${LOG_DIR}/elasticsearch-master.previous.log
kubectl logs $(kubectl get pods -n ${BAI_NAMESPACE} | grep bai-release-ibm-dba-ek-data- | awk '{print $1}') -n ${BAI_NAMESPACE} > ${LOG_DIR}/elasticsearch-data.log
kubectl logs -p $(kubectl get pods -n ${BAI_NAMESPACE} | grep bai-release-ibm-dba-ek-data- | awk '{print $1}') -n ${BAI_NAMESPACE} > ${LOG_DIR}/elasticsearch-data.previous.log
kubectl logs $(kubectl get pods -n ${BAI_NAMESPACE} | grep bai-release-ibm-dba-ek-client- | awk '{print $1}') -n ${BAI_NAMESPACE} > ${LOG_DIR}/elasticsearch-client.log
kubectl logs -p $(kubectl get pods -n ${BAI_NAMESPACE} | grep bai-release-ibm-dba-ek-client- | awk '{print $1}') -n ${BAI_NAMESPACE} > ${LOG_DIR}/elasticsearch-client.previous.log

echo "Retrieving logs for Flink components"
kubectl logs $(kubectl get pods -n ${BAI_NAMESPACE} | grep bai-release-bai-flink-jobmanager- | awk '{print $1}') -n ${BAI_NAMESPACE} > ${LOG_DIR}/flink-jobmanager.log
kubectl logs -p $(kubectl get pods -n ${BAI_NAMESPACE} | grep bai-release-bai-flink-jobmanager- | awk '{print $1}') -n ${BAI_NAMESPACE} > ${LOG_DIR}/flink-jobmanager.previous.log
for pod in $(kubectl get pods -n bai | grep bai-release-bai-flink-taskmanager- | awk '{print $1}'); do `kubectl logs $pod -n ${BAI_NAMESPACE} > ${LOG_DIR}/${pod#bai-release-bai-}.log`; done
for pod in $(kubectl get pods -n bai | grep bai-release-bai-flink-taskmanager- | awk '{print $1}'); do `kubectl logs -p $pod -n ${BAI_NAMESPACE} > ${LOG_DIR}/${pod#bai-release-bai-}.previous.log`; done
kubectl logs $(kubectl get pods -n ${BAI_NAMESPACE} | grep bai-release-bai-flink-zk- | awk '{print $1}') -n ${BAI_NAMESPACE} > ${LOG_DIR}/flink-zookeeper.log
kubectl logs -p $(kubectl get pods -n ${BAI_NAMESPACE} | grep bai-release-bai-flink-zk- | awk '{print $1}') -n ${BAI_NAMESPACE} > ${LOG_DIR}/flink-zookeeper.previous.log
