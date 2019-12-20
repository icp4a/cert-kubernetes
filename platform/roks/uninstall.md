# Uninstalling Cloud Pak for Automation 19.0.3 on Managed Red Hat OpenShift

## Delete your automation instances

You can delete your custom resource (CR) deployments by deleting the CR YAML file or the CR instance. The name of the instance is taken from the value of the `name` parameter in the CR YAML file. The following command is used to delete an instance.

```bash
  $ oc delete ICP4ACluster <MY-INSTANCE>
```

> **Note**: You can get the names of the ICP4ACluster instances with the following command:
  ```bash
    $ oc get ICP4ACluster
  ```

## Delete the operator instance and all associated automation instances

Use the [`scripts/deleteOperator.sh`](../../scripts/deleteOperator.sh) to delete all the resources that are linked to the operator.

```bash
   $ ./scripts/deleteOperator.sh
```

Verify that all the pods created with the operator are terminated and deleted.
