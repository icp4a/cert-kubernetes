# IBM® Business Automation Content Analyzer
-----------


## Introduction

This readme provide instruction to deploy IBM Business Automation Content Analyzer with IBM® Cloud Pak for Automation platform. IBM Business Automation Content Analyzer offers the power of intelligent capture with the flexibility of an API that enables you to extend the value of your core enterprise content management (ECM) technology stack and helps you rapidly accelerate extraction and classification of data in your documents. 


Upgrade
-----------
## Upgrade from 19.0.2 to 20.0.1
Upgrade from Content Analyzer 19.0.2 to 20.0.1 is not supported.

## Upgrade from 19.0.3 to 20.0.1

- In order to upgrade Content Analyzer from 19.0.3 to 20.0.1, the following procedure must be performed:
- Back up your ontology through the export functionality from the Contenat Analyzer UI.
- Back up your Content Analyzer's base database and tenant database.
- Copy the `DB2` [folder](https://github.com/icp4a/cert-kubernetes/tree/master/ACA/configuration-ha) to the Db2 server.
- Run the `UpgradeTenantDB.sh` from your database server as `db2inst1` user.
- Set the ObjectType feature flag for the tenant by running this SQL in your Content Analyzer's base database. Replace the values of `<ontology>` and `<tenantID>`.
```
set schema <ontology>
update tenantinfo set FEATUREFLAGS=(4 | (select FEATUREFLAGS from tenantinfo where TENANTID='<tenantId>' and ONTOLOGY='<ontology>')) where TENANTID='<tenantID>' and ONTOLOGY='<ontology>'
```
- Change the schema version of tenant to 1.4 by running this SQL in your Content Analyzer's base database. Replace the values of `<ontology>` and `<tenantID>`.
```
update tenantinfo set TENANTDBVERSION=1.4 where TENANTID='<tenantID>' and ONTOLOGY='<ontology>'
```
- Fill out the CR yaml file supplied with 20.0.1 using the same values as the previous deployment. Note that you should use the same number of replicas for mongo/mongo-admin as was in 19.0.3 (e.g. 3).
- Change all existing secret names to the new format by running the following commands (this creates new secrets with the same information as the original secrets):
```       
    oc get secret ca-backend-secret -o yaml|sed -e s#ca-backend-secret#aca-backend-secret# |oc apply -f -
    oc get secret ca-frontend-secret -o yaml|sed -e s#ca-frontend-secret#aca-frontend-secret# |oc apply -f -
    for sec in {basedb,mongo,mongo-admin,rabbitmq,redis,secrets<ns>};do oc get secret baca-$sec -oyaml|sed -e s#baca-$sec#aca-$sec#|oc apply -f -;done  (note that the <ns> tag needs to be replaced with appropriate namespace)
```
Change the name of the baca-dsn configmap to aca-dsn: 
```
    oc get cm baca-dsn -o yaml | sed -e s#baca-dsn#aca-dsn# | oc apply -f -
```   
- In 19.0.3, the baca-basedb secret was created using an encoded password, which is no longer used in 20.0.1. To 
patch the aca-basedb secret with an un-encoded password, run:
 ```
    oc  patch secret aca-basedb --type='json' -p='[{"op" : "replace" ,"path" : "/data/BASE_DB_PWD" ,"value" : '$(echo $(oc  get secret aca-basedb -o yaml |grep BASE_DB_PWD | awk {'print $2'}) |base64 -d)'}]'
```
 - Re-label your worker nodes per step 5.2 of [README_config.md](README_config.md). For example:
 ```
    oc label node <node name> celery<namespace>=aca mongo<namespace>=aca mongo-admin<namespace>=aca --overwrite
```   
- If ACA integrates with UMS, do the next steps.
  Issue the command:
 ```
    oc edit cm {meta.name}-ca-config
 ```
 Change the environment variable:
```
    UMS_REGISTERED: "false"
```


- Deploy Content Analyzer 20.0.1 using Operator 20.0.1 per [Operator Readme](https://github.com/icp4a/cert-kubernetes/blob/master/README.md).

- Apply the updated CR yaml file.

NOTE:  Make sure to keep the `csrf_referrer->whitelist: ""` blank if ACA is integrated with Business Automation Studio.

- Monitor the pods and verify that the old pods terminate and new pods are created.
NOTE:  You may need to delete the `redis` pods if they fail to start.  For example:
```
oc scale sts <xxx>-redis-ha-server --replicas=0 
```

then 

```
oc scale sts <xxx>-redis-ha-server --replicas=3

```
    
- Log in to the Content Analyzer UI and import the ontology that was exported in the above step.

- If any problems are encountered see Troubleshooting in [README_config.md](README_config.md).

## Rolling back an upgrade
- Delete the current version of Content Analyzer by following the [README_uninstall.md](README_uninstall.md).
- Restore the Content Analyzer's Base DB and Tenant DB to the previous release. For example: If you want to rollback to 19.0.2, which has been previously backed up, restore the base DB and tenant DB to 19.0.2.
- Follow the installation procedure to deploy Content Analyzer for that specific version.

## Limitation
After upgrading from Content Analyzer v1.3 to v1.4, any existing Key Alias Patterns in the system, which are **not** assigned to any KeyClass, are **lost** after the upgrade. The Value Patterns (irrespective of being assigned to a key class) and Key Alias Patterns that are assigned to any KeyClass are migrated successfully. 
