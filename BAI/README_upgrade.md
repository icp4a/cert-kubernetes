# Upgrading IBM Business Automation Insights

This document describes how to upgrade IBM Business Automation Insights.

## Upgrading from IBM Business Automation Insights version 19.0.3 to 20.0.1

### Important note about Elasticsearch snapshot storage

If dynamic provisioning was used to create the Elasticsearch snapshot storage PersistentVolumeClaim for Business Automation Insights version 19.0.3, deleting this release deletes this PersistentVolumeClaim. It is recommended you back up the data in the PersistentVolume before uninstalling this release.

If static provisioning was used to provision the snapshot storage PersistentVolumeClaim, this storage can be used for 20.0.1. The value for `ibm-dba-ek.elasticsearch.data.snapshotStorage.existingClaimName` can be used for the `spec.bai_configuration.ibm-dba-ek.elasticsearch.data.snapshotStorage.existingClaimName` value in the new ICP4ACluster custom resource.

### Important note about restarting from a Flink processor checkpoint or savepoint

If you need to ensure that, after upgrading, the Flink event processing resumes from its state before the upgrade, you must create a checkpoint or savepoint before the upgrade and you must restart the event processing from the specific checkpoint or savepoint after the upgrade. For further information, refer to [Upgrading Business Automation Insights from a specific checkpoint or savepoint](./README_upgrade_savepoint.md)


### Updating the shared configuration parameters

In the `spec` element of your custom resource, make sure you have defined

| Custom Resource parameter                                                      |        Comment    |
| ------------------------------------------------------------------------------ | ------------------|
| shared_configuration.sc_deployment_type                                        |  `production` or `non-production`                  |
| appVersion                                                                     |  20.0.1           |

For information about shared configuration parameters refer to [shared configuration parameters](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.ref/k8s_topics/ref_shared_config_params.html)

### Updating the Business Automation Insights configuration parameters

Make sure that the custom resource YAML code does not contain any tag elements that point to 19.0.3 docker images from Business Automation Insights 19.0.3. Simply removing the tags ensures that the 20.0.1 docker images are used when the updated custom resource is deployed with the 20.0.1 image of the operator.

Example:
``` Example my_icp4a_cr.yaml
bai_configuration:
   setup:
     image:
       repository: <DOCKER_REGISTRY>/bai-setup
   admin:
     image:
       repository: <DOCKER_REGISTRY>/bai-admin
    ...
```

### Scale down the operator deployment

Retrieve the initial number of replicas (`initialReplicas`) with the following command:

`oc get deployment ibm-cp4a-operator -o jsonpath='{.spec.replicas}'`

Scale down the number of operator deployment to `0` by running the following command:

`kubectl scale --replicas=0 deployment ibm-cp4a-operator`


### Prune the Business Automation Insights 19.0.3 installation
Prune the Business Automation Insights 19.0.3 installation by running the delete command as follows.

`kubectl delete PodDisruptionBudget,StatefulSet,Deployment,Job -l release=<CR-NAME> --namespace <NAMESPACE>`


### Scale up the operator deployment
Scale up the operator deployment by using the following command:

`kubectl scale --replicas=<initialReplicas> deployment ibm-cp4a-operator`

## Completing the upgrade

Return to the appropriate update page to configure other components and complete the deployment using the operator.

Update pages:
   - [Managed OpenShift installation page](../platform/roks/update.md)
   - [OpenShift installation page](../platform/ocp/update.md)
   - [Certified Kubernetes installation page](../platform/k8s/update.md)
