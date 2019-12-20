# IBM® Business Automation Content Analyzer
=========

## Introduction

With these instructions, you can deploy IBM Business Automation Content Analyzer with IBM® Cloud Pak for Automation platform. IBM Business Automation Content Analyzer offers the power of intelligent capture with the flexibility of an API that enables you to extend the value of your core enterprise content management (ECM) technology stack and helps you rapidly accelerate extraction and classification of data in your documents. 


Upgrade
-----------
## Upgrade from 19.0.1 to 19.0.3
Upgrade from Content Analyzer 19.0.1 to 19.0.3 is not supported.

## Upgrade from 19.0.2 to 19.0.3

- To upgrade from Content Analyzer 19.0.2 to 19.0.3, do the following steps:
    - Back up your ontology through the export function from the UI.
    - Back up your Content Analyzer's Base database and Tenant database.
    - Copy the `DB2` [folder](https://github.com/icp4a/cert-kubernetes/tree/19.0.3/ACA/configuration-ha) to the DB2 server.
    - Run the `UpgradeTenantDB.sh` from your database server as `db2inst1` user.
    - Delete the previous Content Analyzer 19.0.2 instance by running `delete_ContentAnalyzer.sh`. 
- Deploy Content Analyzer 19.0.3 using Operator. Make sure to reuse the Base database and Tenant database by filling out the CR yaml file properly.


## Rolling back an upgrade
- Delete the current version of Content Analyzer by following the [README_uninstall.md](README_uninstall.md)
- Restore the Content Analyzer's Base database and Tenant database to the previous release.  For example: Restore the Base database and Tenant database to 19.0.2, that you previously backed up, if you want to rollback to 19.0.2.
- Follow the installation procedure to deploy Content Analyzer for that specific version.
