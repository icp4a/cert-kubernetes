# Deploy Business Automation Content Analyzer

IBM Business Automation Content Analyzer offers the power of intelligent capture with the flexibility of an API that enables you to extend the value of your core enterprise content management (ECM) technology stack. Advanced AI more accurately classifies data and can be configurable in minutes, instead of weeks.

For more information, see [IBM Business Automation Content Analyzer: Details](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.offerings/topics/con_baca.html)

## Requirements and Prerequisites

Perform the following tasks to prepare to deploy your Business Automation Content Analyzer images on Kubernetes:

- Download the PPA. Refer to the top repository [readme](../README.md) to find instructions on how to push and tag the product container images to your Docker registry.

- Several utility scripts are provided in this git repository to assist in the creation of databases, PVCs, secrets, etc. regardless of whether you are installing via the helm chart or generic yaml method.  Information about the utility can be found in the [Configuration Readme](configuration/README.md).

- Prepare environment for IBM Business Automation Content Analyzer. See [Preparing to install automation containers on Kubernetes](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_bacak8s.html).  These procedures include setting up databases, LDAP, storage, and configuration files that are required for use and operation.
                                                                                                                                    
NOTE: To deploy Redis HA,  and Mongo HA,  you need to follow the below instructions to download and push the HA docker images to the appropriate docker registries.
## Steps to load the High-Availability docker images for Redis and Mongo
1) Download the BACA's HA docker images, namely `redis:ha`, `mongo:ha`,  to your ICP's bootmaster node.  Please proceed to IBM Fix Central and search for Fix ID "19.0.1-BACA-HA" to download [19.0.1-BACA-HA.tar.gz](https://www-945.ibm.com/support/fixcentral/swg/selectFixes?parent=Enterprise%20Content%20Management&product=ibm/Other+software/Content+Navigator&release=3.0.5&platform=All&function=fixId&fixids=19.0.1-BACA-HA&includeSupersedes=0).  Untar the main gz file first. 
2) Un-tar the image by `tar xvf <docker image names>.tar.tgz`.  For example: `tar xvf redis-ha.tar.tgz`
3) For OpenShift, be sure to log into docker first by executing:
  - oc login (and enter user name and password)
  - docker login -u $(oc whoami) -p $(oc whoami -t) <repository name>
3) Load the container into your local repository by `docker load --input <docker name>`.  For example: `docker load --input redis-ha.tar`
4) You should see the image shows up as `ibmcom/baca/redis:ha` and `ibmcom/baca/mongo:ha`  by issuing `docker images`
5) Tag the docker images by
`docker tag ibmcom/baca/redis:ha mycluster.icp:8500/sp/redis:ha`
`docker tag ibmcom/baca/mongo:ha mycluster.icp:8500/sp/mongo:ha`
NOTE: 
- `mycluster.icp:8500` is the ICP's clustername and port
- `sp`: the namespace BACA will be deployed on

6) Push the docker image to ICP's repository
- `docker login mycluster.icp:8500`
- `docker push mycluster.icp:8500/sp/redis:ha`
- `docker push mycluster.icp:8500/sp/mongo:ha`
  
NOTE:  Make sure to use the `ha` tag for redis and mongo when filling out the `values.yaml` for redis and mongo

## Redis 
- You can change the `replicas` value in the `values.yaml` under global->redis to the desired value.  The default is 3, which means you must have 3 worker nodes.  
- You can also adjust the `quorum` value.  For more information on `quorum` can be found [here](https://redis.io/topics/sentinel)

## Minio
- The Minio helm chart has been modified from the base helm chart that is part of the baca package to deploy Minio in distributed mode.  In particular the mode in the values.yaml has been set to 'distributed'.  

- In the 'distributed' mode, the helm chart will use StatefulSet to deploy minio rather than the Deployment which is used for the 'standalone' mode.  There will a PVC dynamically created for each StatefulSet replica.  The default number of replicas is 4.  So, there will be 4 PVC's generated dynamically when minio is deployed.  There needs to be four persistent volumes (PVs) available that will meet the PVC requirements.  The sppersistent.yaml file in the configuration directory contains the definition of the 4 PVs needed by the 4 PVCs.  If you increase the number of replicas (4 is the minimun number replicas required for distributed mode), you will need to create a corresponding number of PVs.  You can use the PV defintion in the sppersistent.yaml as your template for defining additional PVs.


## RabbitMQ

- The `rabbitmq-ha` helm chart is installed as a subchart when installing the `ibm-dba-baca-prod` helm chart. That helm chart deploys RabbitMQ in HA (high-availability) mode for BACA to use.

- No changes are needed to deploy this subchart with the default parameters.  With the default parameters, there will be 3 RabbitMQ pods (this means for each BACA task queue, there will be 1 master queue and 2 mirrors).  If you want to increase or decrease the number of RabbitMQ pods, change the `replicaCount` parameter in the `charts/rabbitmq-ha/values.yaml`. 

## Mongo DBs

- Make sure the `common.sh` has been filled out properly
- Copy the `configuration/mongo/pre-setup.sh` and `configuration/mongo/post-setup.sh` to `stable/ibm-dba-baca-prod/charts/mongo-ha`
- Copy the `configuration/mongoadmin/pre-setup.sh` and `configuration/mongoadmin/post-setup.sh` to `stable/ibm-dba-baca-prod/charts/mongoadmin-ha`
- Run the `stable/ibm-dba-baca-prod/charts/mongo-ha/pre_setup.sh` and `stable/ibm-dba-baca-prod/charts/mongoadmin-ha/pre_setup.sh` respectively.
- By default we have 3 replicas for mongodb config, if you want to increase the number of replicas, please reference comments sections under `cp mongodb router(mongos)` in `pre-setup.sh` for mongo-ha and mongoadmin-ha.
- If you have different namespace other than `sp`, please reference comments sections under `Configuring Config Server Replica Sets`, `Configuring shardX Replica Sets` and `...first mongos router is now running ` in `post-setup.sh` for mongo-ha and mongoadmin-ha.
- By default we have 3 replicas for mongodb, if you want to increase the number of replicas, please reference comments sections under `Configuring Config Server Replica Sets` and `Configuring shardX Replica Sets` in `post-setup.sh` for mongo-ha and mongoadmin-ha.

## Deploying

You can deploy your container images with the following methods:
- [Using Helm charts](helm-charts/README.md)



# Completing post deployment configuration

- After you deploy your container images, you might need to perform some required and some optional steps to get your Business Automation Content Analyzer environment up and running. For detailed instructions, see [Completing post deployment tasks for Business Automation Content Analyzer](docs/post-deployment.md)
## Mongo DBs

1) When you see all the `mongodb-shard<x>-<x>` and `mongodb-admin-shard<x>-<x>` pods are in Running/Ready status (eg: 1/1), you need to run the `stable/ibm-dba-baca-prod/charts/mongo-ha/post_setup.sh` and `stable/ibm-dba-baca-prod/charts/mongoadmin-ha/post_setup.sh` respectively

## Redis

1) Get the Redis master ip address by executing:
- `kubectl -n <ns> get ep`
2) Look for the name `redis-ha-announce-0`, and copy the IP address to the right of it.
3) Edit the spbackend deployments by executing:
- `kubectl -n <ns> edit deploy spbackend`
- Change `RESULT_HOST`'s value to the IP obtained in step 2
4) Edit the callerapi deployment by executing:
- `kubectl -n <ns> edit deploy callerapi`
- Change `RESULTS_URL`'s value to the IP obtained in step 2
5) Edit the reannalyze deployment by executing:
- `kubectl -n <ns> edit deploy reanalyze`
- Change `RESULTS_URL`'s value to the IP obtained in step 2

In the event the redis master goes down, you must use the above procedure to determine the new IP address of the new redis master and follow the same steps to update BACA's containers.
