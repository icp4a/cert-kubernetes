# Updating Cloud Pak for Automation 20.0.1 on Certified Kubernetes

- [Step 1: Modify the software that is installed](update.md#step-1-modify-the-software-that-is-installed)
- [Step 2: Apply the updated custom resources](update.md#step-2-apply-the-updated-custom-resources)
- [Step 3: Verify the updated automation containers](update.md#step-3-verify-the-updated-automation-containers)

## Step 1: Modify the software that is installed

An update to the custom resource (CR), overwrites the deployed resources during the operator control loop (observe, analyze, act) that occurs as a result of constantly watching the state of the Kubernetes resources.

Use the following links to configure the software that is already installed. You can modify the installed software, remove it, or add new components. Use the same CR YAML file that you deployed with the operator to make the updates (for example descriptors/my_icp4a_cr.yaml).

- [Configure IBM Automation Digital Worker](../../ADW/README_config.md)
- [Configure IBM Automation Workstream Services](../../IAWS/README_config.md)
- [Configure IBM Business Automation Application Engine](../../AAE/README_config.md)
- [Configure IBM Business Automation Content Analyzer](../../ACA/README_config.md)
- [Configure IBM Business Automation Insights](../../BAI/README_config.md)
- [Configure IBM Business Automation Navigator](../../BAN/README_config.md)
- [Configure IBM Business Automation Studio](../../BAS/README_config.md)
- [Configure IBM FileNet Content Manager](../../FNCM//README_config.md)
- [Configure IBM Operational Decision Manager](../../ODM/README_config.md)
- [Configure the User Management Service](../../UMS/README_config.md)

## Step 2: Apply the updated custom resources

1. Review your CR YAML file to make sure it contains all of your intended modifications.

   ```bash
   $ cat descriptors/my_icp4a_cr.yaml
   ```

2. Run the following commands to apply the updates to the operator:

   ```bash
   $ kubectl apply -f descriptors/my_icp4a_cr.yaml --overwrite=true
   ```

## Step 3: Verify the updated automation containers

The operator reconciliation loop might take several minutes.

Monitor the status of your pods with:
```bash
$ kubectl get pods -w
```

When all of the pods are *Running*, you can access the status of your services with the following commands.
```bash
$ kubectl cluster-info
$ kubectl get services
```

Refer to the [Troubleshooting section](https://www.ibm.com/support/knowledgecenter/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_trbleshoot_operators.html) to access the operator logs.
