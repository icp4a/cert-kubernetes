# Migrating Cloud Pak for Automation data on Certified Kubernetes

To migrate your 19.0.x data to 20.0.1, uninstall your current deployment and follow the migration instructions for each component to point to the existing persistent stores.

## Step 1: Prepare your environment and take note of your existing storage settings

Use the following links to help you find the relevant software storage settings that you want to migrate.

- [Configure IBM Business Automation Application Engine](../../AAE/README_migrate.md)
- [Configure IBM Business Automation Content Analyzer](../../ACA/README_migrate.md)
- [Configure IBM Business Automation Insights](../../BAI/README_migrate.md)
- [Configure IBM Business Automation Navigator](../../BAN/README_migrate.md)
- [Configure IBM Business Automation Studio](../../BAS/README_migrate.md)
- [Configure IBM FileNet Content Manager](../../FNCM//README_migrate.md)
- [Configure IBM Operational Decision Manager](../../ODM/README_migrate.md)
- [Configure the User Management Service](../../UMS/README_migrate.md)

## Step 2: Install your chosen components with the operator

 When you have completed all of the preparation steps for each of the components that you want to migrate, follow the instructions in the [installation](install.md) readme.
