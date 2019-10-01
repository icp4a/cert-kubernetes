# Mongodb

[Mongodb](https://www.mongodb.com/) is a general purpose, document-based, distributed database built for modern application developers and for the cloud era. No database is more productive to use

## TL;DR;

```bash
$ helm install stable/mongo-ha
```

By default this chart install 12 pods total:
 * three pods containing a mongos router
 * three pods containing a mongodb config server
 * three pods containing a mongdb shard 
 * three pods containing a mongdb shard 
## Introduction

This chart bootstraps a[Mongodb](https://www.mongodb.com/) highly available Shard+Replica statefulset in a [Kubernetes](http://kubernetes.io) cluster using the Helm package manager.

## Prerequisites

- Kubernetes 1.8+ with Beta APIs enabled
- PV provisioner support in the underlying infrastructure or an existing PVC claim created when running `init_deployments.sh`
- PV for shards and replicas will be created in generate.sh
- Change the values for the `reposittory` and `tag` under `image` and tag to match your mongo cluster environment.  For example:
```
image:
  repository: mycluster.com:8500/sp/mongocluster
  tag: latest
  pullPolicy: Always
```
mongocluster image can be downloaded from TBD
The current default namespace is `sp`. If you have different namespace, please make sure you update generate.sh as well. Next version will fixed this issue.
openssl.cnf and ssl_generator.sh are used to create x509 certificate for mongo cluster.
## Upgrading the Chart

You can use Helm to update MongoCluster version in a live release. Assuming your release is named as `my-release`, get the values using the command:

## Installing the Chart

To install the chart

```bash
sh generate.sh
```

The command will generate templates for mongodb shards and replicas, save them into templates folder. And then create values.yaml based on values-base.yaml. It will deploys Mongodb Cluster on the Kubernetes cluster in the default configuration. By default this chart install 2 shards, 3 mongodb config and 3 mongos router.

> **Tip**: List all releases using `helm list`

## Uninstalling the Chart

To uninstall/delete the deployment:

```bash
$ helm delete <chart-name> --purge --tls
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the MongoDB chart and their default values.

| Parameter                | Description                                                                                                                                                                                              | Default                                                                                    |
|:-------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------------------------------------------------------|
| `image.repository`                  | Mongodb image                                                                                                                                                                                              | `mongocluster`                                                                                    |
| `image.tag`                    | Mongodb tag                                                                                                                                                                                                | `latest`                                                                             |
| `image.pullPolicy`               | Pull Image policy                                                                                                                                                                        | `Always`                                                                                        |
| `storageClassName`  | Specifies storage class name                                                                                                                                                     | local-storage                                                                                     |
| `nfsIP`    | The NFS location                                                                                                                                                                |                                              |
| `nameSpace`            | use kubernetes namespace                                                                                                                                                                            |                                                                                  `sp`    |  
| `wiredTigerCache`             | mondo db cache limitiation                                                                                                                                                                        | `0.5`                                                                                      |
| `secretVolume`           | Where the certification stored                                                                                                               | created from setup.sh script                                                                           |
| `logs.claimname`     | Where the location of log, depends on setup.sh                                                                                                         | ``                                                                                         |
| `logs.path`        | log path inside the pod                                                                                                                                               | `/var/log/`                                                                                       |
| `logs.logLevel`          | log level                                                                                                                                                                      | `debug`                                                                                    |
| `mongoDBConfig.storageCapacity`        | Mongodb config storage size                                                                                                                                                   | `10Gi`                                                                                        |
| `mongoDBConfig.labelName`        | label name                                                                                           | mongodb-configdb                                                                            |
| `mongoDBConfig.replicas`  |  mongodb config replicas, variable in generate.sh                                                                                                   | ``                                                                                         |
| `mongoDBConfig.replicaSetName`     | replica set name                                                                                                                                                   | `ConfigDBRepSet`                                                                                       |
| `mongoDBConfig.resources`         | CPU/Memory for init Container node resource requests/limits                                                                                                                                              | `{}`                                                                                       |
| `mongosRouter.name`                   | name of the mongos router                                                                                                                                      | `mongos-router`                                                                                    |
| `mongosRouter.replicas`          | mongodb router replicas, need to change in generate.sh                                                                                      | ``                                                                                         |
| `mongosRouter.configReplset`                | generate by generate.sh, do not change.                                                                                                                                                |                                                                                     |
| `mongoDBShard.storageCapacity`         | Mongodb shard storage size   | `15Gi`                                                                                         |
| `mongoDBShard.replicas`           | mongodb shard replicas, variable in generate.sh                                                                                                                                                                          | `{}`                                                                                       |
| `logs.logLevel`            | log level                                                                                                                                                                      | `[]`                                                                                       |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```bash
$ helm install \
  --set image=mongocluster \
  --set tag=latest \
    stable/mongo-ha
```

The above command sets the Mongodb server within `default` namespace.


> **Tip**: There is no [values.yaml](values.yaml) file, and will generate [values.yaml](values.yaml) on the fly based on [values-base.yaml](values-base.yaml) 

Persistence
-----------

This generate.sh provisions a PersistentVolume and pods will create PersistentVolumeClaim and mounts corresponding persistent volume under the same storage class name to default location `/export/smartpages/`. You'll need physical storage available in the Kubernetes cluster for this to work. 

Configure TLS
-------------

Always enable TLS for mongodb containers, acquire TLS certificates from a CA or create self-signed certificates. While creating / acquiring certificates ensure the corresponding domain names are set as per the standard [DNS naming conventions](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#pod-identity) in a Kubernetes StatefulSet (for a distributed mongodb setup). Then create a secret using

```bash
$ kubectl create secret generic baca-secrets${NAMESPACE}  --from-file=path/to/private.key --from-file=path/to/public.crt
```

Then install the chart, specifying the path you'd like to mount to the TLS secret:
