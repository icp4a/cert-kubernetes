# Monitoring an IBM Business Automation Insights installation on Minikube

After Business Automation Insights is installed on Minikube, you can use the following procedure to monitor the health of you installation and troubleshoot issues.

Table of contents:
- [Retrieving all the logs](#retrieving-all-the-logs)
- [Monitoring Kafka](#monitoring-kafka)
- [Monitoring Elasticsearch](#monitoring-elasticsearch)
- [Monitoring Flink](#monitoring-flink)

## Retrieving all the logs

In order to retrieve the logs of all the main BAI runtime components, run the following command:

``` bash
./get-logs.sh
```

This command creates a `logs` directory under which the following log files are created:

```
elasticsearch-client.log              (last log file for the elasticsearch client pod)
elasticsearch-client.previous.log     (previous log file for the elasticsearch client pod)
elasticsearch-data.log                (last log file for the elasticsearch data pod)
elasticsearch-data.previous.log       (previous log file for the elasticsearch data pod)
elasticsearch-master.log              (last log file for the elasticsearch master pod)
elasticsearch-master.previous.log     (previous log file for the elasticsearch master pod)
flink-jobmanager.log                  (last log file for the flink job manager pod)
flink-jobmanager.previous.log         (previous log file for the flink job manager pod)
flink-taskmanager-n.log               (last log file for the flink task manager pod(s))
flink-taskmanager-n.previous.log      (previous log file for the flink task manager pod(s))
flink-zookeeper.log                   (last log file for the flink zookeeper pod)
flink-zookeeper.previous.log          (previous log file for the flink zookeeper pod)
kafka-zookeeper.log                   (last log file for the kafka zookeeper pod)
kafka-zookeeper.previous.log          (previous log file for the kafka zookeeper pod)
kafka.log                             (last log file for the kafka pod)
kafka.previous.log                    (previous log file for the kafka pod)
```

## Monitoring Kafka

### Checking that Kafka is running

Run the following command:

``` bash
kubectl get pods -n kakfa
```

The expected output should be similar to the following result, indicating two pods running and ready.

```
NAME                           READY   STATUS    RESTARTS   AGE
kafka-release-cp-kafka-0       2/2     Running   0          60m
kafka-release-cp-zookeeper-0   2/2     Running   12         41h
```

After you ensured that your two pods are ready and running, you can check that the Kafka service is correctly exposed by running the following command:

``` bash
kubectl get services -n kafka
```

The expected output should be similar to the following result: a service named `kafka-release-_x_-nodeport` of type `NodePort` should be mapped to TCP port 31090).

```
NAME                                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
kafka-release-0-nodeport              NodePort    10.103.253.72    <none>        19092:31090/TCP     41h
kafka-release-cp-kafka                ClusterIP   10.103.115.114   <none>        9092/TCP            41h
kafka-release-cp-kafka-headless       ClusterIP   None             <none>        9092/TCP            41h
kafka-release-cp-zookeeper            ClusterIP   10.107.231.119   <none>        2181/TCP            41h
kafka-release-cp-zookeeper-headless   ClusterIP   None             <none>        2888/TCP,3888/TCP   41h
```

### Checking that the Kafka topics for Business Automation Insights exist

_Note: Before this verification, make sure to install the [kafka binaries](https://kafka.apache.org/downloads) on your laptop. In the following command, ${KAFKA_HOME} refers to the home directory of your Kafka installation._

Run the following Kafka command:

``` bash
${KAFKA_HOME}/bin/kafka-topics.sh --list --bootstrap-server $(minikube ip):31090
```

The returned list must include the three following Kafka topics:

```
bai-release-ibm-bai-egress
bai-release-ingress
bai-release-service
```

### Checking that messages are sent by the emitter

_Note: Before this verification, make sure to install the [kafka binaries](https://kafka.apache.org/downloads) on your laptop. In the following command, ${KAFKA_HOME} refers to the home directory of your Kafka installation._

Run the following Kafka command to display all messages in the `bai-release-ibm-bai-egress` Kafka topic:

``` bash
${KAFKA_HOME}/bin/kafka-console-consumer.sh --bootstrap-server $(minikube ip):31090 --topic bai-release-ingress --from-beginning
```

Then, interact with your emitter application (the ODM emitter for IBM Operational Decision Manager, or the BPMN or Case emitter for IBM Business Automation Workflow) and check that you can see messages added to the `bai-release-ingress` topic in your console.

### Getting the Kafka logs

Run the following command to get the logs:

``` bash
kubectl logs $(kubectl get pods -n kafka | grep kafka-release-cp-kafka- | awk '{print $1}') cp-kafka-broker  -n kafka
```

## Monitoring Elasticsearch

### Checking that Elasticsearch is running

Run the following command to display the list of Elasticsearch and Kibana pods:

``` bash
kubectl get pods -n bai | grep -e 'RESTARTS\|-ek-'
```

The expected output should be similar to the following result, indicating four pods running and ready.

```
NAME                                                READY   STATUS      RESTARTS   AGE
bai-release-ibm-dba-ek-client-58bc6bf75c-9dwvc      1/1     Running     2          18h
bai-release-ibm-dba-ek-data-0                       1/1     Running     2          18h
bai-release-ibm-dba-ek-kibana-7bcfc6ddf9-ff69f      1/1     Running     2          18h
bai-release-ibm-dba-ek-master-0                     1/1     Running     2          18h
```

After you ensured that your two pods are ready and running, you can check that the Elasticsearch and Kibana services are correctly exposed by running the following command:

``` bash
kubectl get services -n bai | grep 'EXTERNAL-IP\|-ek-'
```

The expected output should be similar to the following result.

```
NAME                                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                               AGE
bai-release-ibm-dba-ek-client           NodePort    10.110.241.254   <none>        9200:31200/TCP                        18h
bai-release-ibm-dba-ek-kibana           NodePort    10.97.123.220    <none>        5601:31501/TCP                        18h
bai-release-ibm-dba-ek-master           ClusterIP   10.111.170.123   <none>        9300/TCP                              18h
```

### Checking that the Elasticsearch cluster is healthy

Run the following command to check the health of your Elasticsearch cluster:

``` bash
curl https://$(minikube ip):31200/_cluster/health?pretty=true --insecure -u admin:passw0rd
```

In the returned JSON code, check that the status is `green` or `yellow`, as in the following example:

``` json
{
  "cluster_name" : "bai-release-ibm-dba-ek-elasticsearch",
  "status" : "yellow",
  "timed_out" : false,
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 1,
  "active_primary_shards" : 42,
  "active_shards" : 42,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 40,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 51.21951219512195
}
```

### Checking that the Elasticsearch indexes exist

Run the following command to retrieve the list of indexes in the Elasticsearch cluster:

``` bash
curl https://$(minikube ip):31200/_cat/indices?v --insecure -u admin:passw0rd
```

In the returned list, check that all expected indexes exist, are open, and have a `green` or `yellow` health status, as in the following example:

```
health status index                                                     uuid                   pri rep docs.count docs.deleted store.size pri.store.size
yellow open   security-auditlog-2019.04.25                              P7LQybcvTySRYpDUCoUftw   5   1        159            0    671.2kb        671.2kb
yellow open   process-summaries-active-idx-ibm-bai-2019.04.25-000001    81GfwYOOTJOK4LD551uVTw   5   1          4            0     96.5kb         96.5kb
green  open   .kibana_1                                                 HyuwkYF8QvKJyONgyECFtw   1   0        135            9    191.5kb        191.5kb
green  open   .opendistro_security                                      SOGNgWczThqAT26vcyg71g   1   0          5            0       32kb           32kb
yellow open   process-summaries-completed-idx-ibm-bai-2019.04.25-000001 qlwuQ1AqTca3FcQ2LB-9xg   5   1          1            0     25.2kb         25.2kb
yellow open   odm-timeseries-idx-ibm-bai-2019.04.25-000001              _SGUSxhfSi-3yfWQ4qdNYQ   5   1          0            0      1.2kb          1.2kb
yellow open   case-summaries-active-idx-ibm-bai-2019.04.25-000001       nwwlbYUZRzmtUPisVusJUw   5   1          0            0      1.2kb          1.2kb
yellow open   security-auditlog-2019.04.26                              -Xqc9GqiQSmLTfVwgzjk9A   5   1         21            0    268.6kb        268.6kb
yellow open   content-timeseries-idx-ibm-bai-2019.04.25-000001          gMs6ZjIfQ8O1eyoK7V02eQ   5   1          0            0      1.2kb          1.2kb
yellow open   case-summaries-completed-idx-ibm-bai-2019.04.25-000001    AS7uaqCYRAOuvPY1S2g2gw   5   1          0            0      1.2kb          1.2kb
```

### Getting the Elasticsearch logs

Run the following command to get the logs of the Elasticsearch master node:

``` bash
kubectl logs $(kubectl get pods -n bai | grep bai-release-ibm-dba-ek-master- | awk '{print $1}') -n bai
```

Run the following command to get the logs of the Elasticsearch data node:

``` bash
kubectl logs $(kubectl get pods -n bai | grep bai-release-ibm-dba-ek-data- | awk '{print $1}') -n bai
```

Run the following command to get the logs of the Elasticsearch client node:

``` bash
kubectl logs $(kubectl get pods -n bai | grep bai-release-ibm-dba-ek-client- | awk '{print $1}') -n bai
```

### Using Elasticsearch head to introspect your cluster

To introspect and monitor your Elasticsearch cluster with a user interface, you can install the [Elasticsearch head chrome plugin](https://chrome.google.com/webstore/detail/elasticsearch-head/ffmkiejjmecolpfloofpjologoblkegm).

To connect the plugin to your Elasticsearch cluster, go through the following steps:

1. Retrieve the URL to the Elasticsearch cluster by running the `echo https://$(minikube ip):31200` command.
1. Enter this URL in your Chrome browser, accept the self-signed certificate if requested, and then use the `admin / passw0rd` credentials to authenticate.
1. After you access the URL, open the Elasticsearch head plugin in the same browser, enter the same URL in the text box at the top of the user interface, and click the `Connect` button.

## Monitoring Flink

### Checking that Flink is running

Run the following command to display the list of Flink pods:

``` bash
kubectl get pods -n bai | grep -e 'RESTARTS\|-flink-'
```

The expected output should be similar to the following result, with all pods running and ready. Note that you might have more or fewer `bai-release-bai-flink-taskmanager-_x_` pods.

```
NAME                                                READY   STATUS      RESTARTS   AGE
bai-release-bai-flink-jobmanager-5d8f74f947-zv6wm   1/1     Running     3          19h
bai-release-bai-flink-taskmanager-0                 1/1     Running     3          19h
bai-release-bai-flink-taskmanager-1                 1/1     Running     3          19h
bai-release-bai-flink-zk-0                          1/1     Running     2          19h
```

