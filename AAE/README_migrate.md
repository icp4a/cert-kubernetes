
# Migrating from IBM Business Automation Application Engine (App Engine) 19.0.2 to 20.0.1 

These instructions cover the migration of IBM Business Automation Application Engine (App Engine) from 19.0.2 to 20.0.1.

## Introduction

If you install App Engine 19.0.2 and want to continue to use your 19.0.2 applications in App Engine 20.0.1, you can migrate your applications from App Engine 19.0.2 to 20.0.1.

## Step 1: Export apps that were authored in 19.0.2

Log in to the admin console in your IBM Business Automation Studio 19.0.2 environment, then export your apps as IBM Business App Installation Package (.zip) files. 

## Step 2: Publish the apps to App Engine through Business Automation Navigator

Publish your apps to App Engine through Business Automation Navigator and make sure they work without errors.

## Step 3: Shut down the App Engine 19.0.2 environment

Log in to your OpenShift environment to stop all the development pods. You can scale down the number of development pods to 0 by using the OpenShift console. (Note: JMS and the Resource Registry are stateful and can't be scaled down from the OpenShift console. Keeping them won't impact your next action.)

## Step 4: Reuse the App Engine database from 19.0.2

Reuse the existing App Engine database. Update the database configuration information under application_engine_configuration in the custom resource YAML file.

## Step 5: Install App Engine 20.0.1

[Install IBM Business Automation Application Engine](../AAE/README_config.md).

## Step 6: Migrate IBM Business Automation Navigator from 19.0.2 to 20.0.1 to verify your apps

Following the [IBM Business Automation Navigator migration instructions](../BAN/README_migrate.md), migrate Business Automation Navigator from 19.0.2 to 20.0.1. Then, test your apps.


