# Install IBM Business Automation Insights on Minikube

This procedure guides you to install and run IBM Business Automation Insights Developer Edition on a local Minikube cluster.

### Disclaimer

The deployment of IBM Business Automation Insights Developer Edition on Minikube is **not going to provide any high performance, scalability, high availability or allow any long term storage of the data**. Use with care. In order to get high performance, high availability and features not available in the Developer Edition you must install the commercial release of IBM Business Automation Insights on a scalable Kubernetes cluster.
As a consequence, and not limited to the following, machine hibernation or shutdown without having properly shutdown the Minikube virtual machine may have unpredictable effects on Kubernetes persistent storage. This may also prevent Minikube from restarting properly.
***

- [Prerequisites](#prerequisites)
- [Automated installation](#automated-installation-fast-path)
- [Step by step installation](#step-by-step-installation)
  - [1. Initialize minikube](#1-initialize-minikube)
  - [2. Initialize minikube persistent volumes](#2-initialize-minikube-persistent-volumes)
  - [3. Initialize Helm](#3-initialize-helm)
  - [4. Install Apache Kafka](#4-install-apache-kafka)
  - [5. Install IBM Business Automation Insights Developer Edition](#5-install-ibm-business-automation-insights-developer-edition)
    - [1. Add IBM Charts repository](#1-add-ibm-charts-repository)
    - [2. Create a security policy and a service account for elasticsearch](#2-create-a-security-policy-and-a-service-account-for-elasticsearch)
    - [3. Choose the type of event processing you want to deploy](#3-choose-the-type-of-event-processing-you-want-to-deploy)
    - [4. Deploy BAI release](#4-deploy-the-bai-release)
    - [5. Verify](#5-verify)
- [Starting/stopping minikube](#starting-or-stopping-minikube)
- [Next step: configure your Event Emitter](#next-step-configure-your-event-emitter)
- [Troubleshooting](#troubleshooting)
***

## Prerequisites

- Resources:
  - MacOS Mojave or Windows 10
  - 2CPUs  + 6Gb RAM free space
  - In addition to the space for Docker, Minikube, and Helm, 15Gb disk space for images and persisted data
  - There are [known networking issues](https://github.com/kubernetes/minikube/issues/1099) when using Minikube while Cisco AnyConnect is running on the same machine. Before running Minikube, make sure that your Cisco AnyConnect VPN is NOT running.

- Tools that must be installed:
  - **[Docker](https://docs.docker.com/install)**, tested with [Docker Desktop](https://www.docker.com/products/docker-desktop) on MacOS and [Docker Toolbox](https://docs.docker.com/toolbox/overview/) on Windows
  - **[VirtualBox latest](https://www.virtualbox.org/wiki/Downloads)**
  - **[Minikube](https://kubernetes.io/docs/setup/minikube)**, tested with [v1.0.1](https://github.com/kubernetes/minikube/releases/tag/v1.0.1) (MacOS and Windows)
  - **[Helm](https://docs.helm.sh/using_helm/#installing-helm)**, tested with [v2.12.3](https://github.com/helm/helm/releases/tag/v2.12.3) (MacOS) and [v2.13.1](https://github.com/helm/helm/releases/tag/v2.13.1) (Windows)
  - **[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)**, tested with latest version
  - **[jq](https://stedolan.github.io/jq/)**, tested with latest version (MacOS and Windows)

- IBM Business Automation Insights Developer Edition:
  - Choose a destination directory where the installation artifacts below will be downloaded.
    - On Windows, this must be on the drive where your ```MINIKUBE_HOME``` environment variable points to. If this is not set, it defaults to the ```C:``` drive (current [restriction of ```minikube```](https://github.com/kubernetes/minikube/issues/1574))
  - Download the following files:
    - [configuration/easy-install-kafka.yaml](configuration/easy-install-kafka.yaml?raw=true)
    - [configuration/easy-install.yaml](configuration/easy-install.yaml?raw=true)
    - [configuration/pv.yaml](configuration/pv.yaml?raw=true)
    - [configuration/bai-psp.yaml](configuration/bai-psp.yaml?raw=true)
    - [install-bai-minikube.sh](./install-bai-minikube.sh?raw=true)
    - [install-bai.sh](./install-bai.sh?raw=true)
    - [utilities.sh](./utilities.sh?raw=true)
  - [Mac/Linux only] Ensure proper execution permissions of downloaded scripts: `chmod +x *.sh`

## Automated installation ("fast path")

  - See [installation prerequisites](#prerequisites)
  - Choose an \<event-type\> to deal with. The valid values are "odm", "icm", "bpmn", "bawadv", "content", or "baiw".
  - If your event emitter is not hosted by the local host, you must use the ```-i ``` option to specify the local machine IP address that is reachable by the event emitter.
  - To bypass the check of the Minikube version used, pass the ``` -f ``` option.
  - Make sure that the VirtualBox ```VBoxManage``` command is on the ```PATH```.
  - Example: ```./install-bai-minikube.sh -e <event-type> -i 9.128.37.112 -f```
    - On Windows, you must run this command from the Git [```bash```](https://gitforwindows.org/) command tool, which comes with Docker Toolbox.
  - Processed data is stored locally in the ```minikube virtual machine /data``` directory and subdirectories.


## Step-by-step installation

Run the following commands from the destination folder where you downloaded the IBM Business Automation Insights Developer Edition files (archive + YAML files). Your working directory structure should be:

```
.
|____./configuration/easy-install.yaml
|____./configuration/easy-install-kafka.yaml
|____./configuration/bai-psp.yaml
|____./configuration/pv.yaml
```

### 1. Initialize Minikube

```
minikube start --cpus 2 --memory 6144
minikube docker-env
eval $(minikube docker-env)
```
### 2. Initialize minikube persistent volumes

```
kubectl create ns bai
kubectl apply -f configuration/pv.yaml -n bai
minikube ssh "sudo mkdir /data/bai"
minikube ssh "sudo mkdir /data/bai-elasticsearch-data-1"
minikube ssh "sudo mkdir /data/bai-elasticsearch-master-1"
minikube ssh "sudo chmod -R 777 /data"
```

### 3. Initialize Helm

```
helm init --wait
```

### 4. Install Apache Kafka

#### Scenario 1: Your event emitter (BPMN, BAW Advanced, Case, ODM, Content, or BAIW) is running on your local machine.

If you plan to feed your Business Automation Insights instance with events from a Business Automation Worfklow server or from an Operational Decision Manager server running on your local machine, use the following procedure to install Apache Kafka:

```
helm repo add confluent https://confluentinc.github.io/cp-helm-charts
helm repo update
kubectl create ns kafka
helm install --wait --name kafka-release --namespace kafka -f configuration/easy-install-kafka.yaml --set cp-kafka.customEnv.ADVERTISED_LISTENER_HOST=$(minikube ip) confluent/cp-helm-charts
```

After the command completes, check the deployment status of Kafka pods with `kubectl get pods -n kafka` until all pods are running. <div><details><summary>Click to show an example of successful completed deployment.</summary>
<p>

```
NAME                           READY     STATUS    RESTARTS   AGE
kafka-release-cp-kafka-0       2/2       Running   0          108s
kafka-release-cp-zookeeper-0   2/2       Running   0          108s
```

</p>
</details></div>

#### Scenario 2: Your event emitter (BPMN, BAW Advanced, Case, ODM, Content, or BAIW) is running on an external machine.

If you plan to feed your Business Automation Insights instance with events from a Business Automation Worfklow server or from an Operational Decision Manager server running on an external machine (for example, on IBM Cloud), you need to through the following steps:

1. Retrieve the IP address of your local machine (addressable from an external machine).
1. Set up Kafka so that it informs its listener of this IP address.
1. Set up VirtualBox to redirect the connection to your local machine IP to the Minikube VM.
1. Disable your local firewall. This is particularly important on Mac OSx where the firewall is enabled by default. Or add a rule to allow remote connection to port `31090`.

In the following procedure, replace `1.2.3.4` with the actual IP address of your local machine:

```
VBoxManage controlvm "minikube" natpf1 "kafka service,tcp,,31090,,31090"
helm repo add confluent https://confluentinc.github.io/cp-helm-charts
helm repo update
kubectl create ns kafka
helm install --wait --name kafka-release --namespace kafka -f configuration/easy-install-kafka.yaml --set cp-kafka.customEnv.ADVERTISED_LISTENER_HOST=1.2.3.4 confluent/cp-helm-charts
```

After the command completes, check the deployment status of Kafka pods with `kubectl get pods -n kafka` until all pods are running. <div><details><summary>Click to show an example of successful completed deployment.</summary>
<p>

```
NAME                           READY     STATUS    RESTARTS   AGE
kafka-release-cp-kafka-0       2/2       Running   0          108s
kafka-release-cp-zookeeper-0   2/2       Running   0          108s
```

</p>
</details></div>

---
**Re-installing Kafka when the external IP address changes**

If your external IP address changes when you restart your computer, update the Kafka settings so that it correctly sends the new IP address to Kafka listeners.

To update Kafla settings, run the following commands (replacing 2.3.4.5 with the actual new IP address of your local machine):

```
./ip-upgrade.sh -i 2.3.4.5
```

---
### 5. Install IBM Business Automation Insights Developer Edition

#### 1. Add IBM Charts repository

```
helm repo add ibm-charts https://raw.githubusercontent.com/IBM/charts/master/repo/stable
helm repo update
```

#### 2. Create a security policy and a service account for Elasticsearch.

```
kubectl create -f configuration/bai-psp.yaml -n bai
kubectl create rolebinding bai-rolebinding --role=bai-role --serviceaccount=bai:bai-release-bai-psp-sa -n bai
```

#### 3. Choose the type of event processing you want to deploy.

You can choose: `bpmn`, `bawadv`, `icm`, `odm`, `content`, or `baiw`.

```
EVENT_PROCESSING_TYPE=<event-processing-type>
```

#### 4. Deploy the bai release.

```
helm install ibm-charts/ibm-business-automation-insights-dev --version 3.2.0 --wait --name bai-release --namespace bai -f configuration/easy-install.yaml --set kafka.bootstrapServers=$(minikube ip):31090 --set ${EVENT_PROCESSING_TYPE}.install=true
```

#### 5. Verify

- Run `kubectl get pods -n bai -w` to monitor the deployment status of bai pods.

<ul><div><details><summary>Click to show an example of successful completed deployment.</summary>
<p>

```
$ kubectl get pods -n bai
NAME                                                READY     STATUS      RESTARTS   AGE
bai-release-bai-admin-6bc755fc5f-mwvl7              1/1       Running     0          36m
bai-release-bai-bpmn-bxknx                          0/1       Completed   0          36m
bai-release-bai-flink-jobmanager-5bff88579b-vkhmn   1/1       Running     0          36m
bai-release-bai-flink-taskmanager-0                 1/1       Running     0          36m
bai-release-bai-flink-zk-0                          1/1       Running     0          36m
bai-release-bai-setup-5vrvd                         0/1       Completed   0          36m
bai-release-ibm-dba-ek-client-6ccf856d5d-f7xk6      2/2       Running     0          36m
bai-release-ibm-dba-ek-data-0                       1/1       Running     0          36m
bai-release-ibm-dba-ek-kibana-6f9c464574-zhxnq      2/2       Running     0          36m
bai-release-ibm-dba-ek-master-0                     1/1       Running     0          36m
```

</p>
</details></div></ul>

- Run `echo "https://$(minikube ip):31501"` to obtain the URL of Kibana.
- Kibana credentials are admin / passw0rd

Note:
- Elasticsearch REST endpoint is available on port `31200`.
- The Business Automation Insights administration service is available on port `31100`.

## Starting or stopping Minikube

- To start Minikube: ```minikube start --cpus 2 --memory 6144```
- To stop Minikube: ```minikube stop```

## Next step: configure your event emitter

To configure your event emitter, you need the following information:

- The **Kafka bootstrap URL**. By default, you can connect to Kafka from your host by using the bootstrap URL that is returned by this command:
  - `echo $(minikube ip):31090`
- The **name of the Kafka topic** that Event Processing Jobs use to consume messages sent by event emitters:
  - `bai-release-ingress`

## Troubleshooting

- After Minikube is restarted, the task manager is not running properly (READY: 0/1). Solution: Restart the job manager: `kubectl delete pod <bai-release-bai-flink-jobmanager-pod-name> -n bai`

- If your Minikube is not responsive anymore, you probably undersized it and deployed too many elements on it. It is safer to call `minikube delete` and start all over again than to try to fix separate issues.

- If you get errors such as `Error: error validating "": error validating data: field` when you install Kafka or the Helm Chart for Business Automation Insights, use the exact Minikube and Helm versions this procedure was tested with (see [Prerequisites](#prerequisites)).

- If, when Minikube starts, you get an error such as : ```💣  Error starting cluster: timed out waiting to elevate kube-system RBAC privileges: creating clusterrolebinding: Post https://192.168.99.110:8443/apis/rbac.authorization.k8s.io/v1beta1/clusterrolebindings?timeout=1m0s: dial tcp 192.168.99.110:8443: connect: network is unreachable```, try the following actions:
    - Delete the VirtualBox "vboxnet0" network adapter and try restarting.
    - Turn ```off``` your VPN.
    - Restart your computer
    - See [Can't use Minikube on VPN](https://github.com/kubernetes/minikube/issues/1099)

- If you get errors such as `Error: release kafka-release failed: namespaces "kafka" is forbidden: User "system:serviceaccount:kube-system:default" cannot get resource "namespaces" in API group "" in the namespace "kafka"`, run the following commands to fix the issue:
    - `kubectl --namespace kube-system create serviceaccount tiller`
    - `kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller`
    - `kubectl --namespace kube-system patch deploy tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}`

- In case the minikube VM is stopped suddently (aborted, power off...), checkpoints might be corrupted. In this case jobmanager will keep crashing, and a `kubectl logs bai-release-bai-flink-jobmanager<JOBID> --namespace bai | egrep -i error.*Could not read any of the . checkpoints from storage"` will show an error.
    - run [recover-minikube-bai.sh](./recover-minikube-bai.sh?raw=true)
    - monitor proper pod recovery using `kubectl --namespace bai get pods -w`
    - Elasticsearch data will be recovered, but the Flink state will be reset, therefore the result of the processing is likely to be lost for the last events.

- Troubleshooting Apache Flink jobs: [Knowledge Center - Troubleshooting Apache Flink jobs](http://engtest01w.fr.eurolabs.ibm.com:9190/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.bai/topics/con_bai_troubleshoot_jobs.html)

***
