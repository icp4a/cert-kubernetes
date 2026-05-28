# 📋 CP4BA configuration files to apply Kyverno policies

This directory has JSON and YAML files to configure Kyverno policies in Cloud Pak for Business Automation (CP4BA) deployments. Kyverno is used to demonstrate strong compliance with the Supply-chain Levels for Software Artifacts (SLSA) security framework. For more information about Kyverno, see https://kyverno.io/docs/.

The files in this directory support the following configurations:

- ✅ **High availability (HA) configuration for CP4BA operators:** Configure the CP4BA operators for high availability by setting the number of replicas to a minimum of two.
- ✅ **Pod Disruption Budget (PDB) configuration for CP4BA operators:** Configure a Pod Disruption Budget (PDB) to support availability during disruptions. The PDB is configured with `minAvailable: 1` to make sure that one replica is always available.
- ✅ **Ephemeral volume configuration**: For more information about generic ephemeral volumes, see https://kubernetes.io/docs/concepts/storage/ephemeral-volumes/#generic-ephemeral-volumes.
  - **For CP4BA operators**: Configure the CP4BA operators to use generic ephemeral volumes instead of the emptyDir volume storage.
  - **For CP4BA operands**: Configure the CP4BA operands to use generic ephemeral volumes instead of the emptyDir volume storage.

## Directory structure for the Kyverno policy template files

Under the `KyvernoOperatorConfigs` directory you can find a directory for each CP4BA operator. 

- 📁 `ibm-ads-operator`: A directory that has files for the ADS operator.
- 📁 `ibm-content-operator`: A directory that has files for the Content operator.
- 📁 `ibm-cp4a-operator`: A directory that has files for the CP4BA operator.
- 📁 `ibm-cp4a-wfps-operator`: A directory that has files for the Workflow Process Server operator.
- 📁 `ibm-dpe-operator`: A directory that has files for the Document Processing operator.
- 📁 `ibm-insights-engine-operator`: A directory that has files for the BAI operator.
- 📁 `ibm-odm-operator`: A directory that has files for the ODM operator.
- 📁 `ibm-pfs-operator`: A directory that has files for the PFS operator.
- 📁 `ibm-workflow-operator`: A directory that has files for the Workflow operator.
- 📁 `icp4a-foundation-operator`: A directory that has files for the CP4BA foundation operator.

Each directory has template JSON files for the Kyverno policies to patch the `ClusterServiceVersion` (CSV) for the operator, and a YAML file to enforce a Pod Disruption Budget (PDB) policy for operators that support PDB. 

- `optional-${directory_name}-ha.json`: JSON file to enforce a high availability configuration for a Kyverno policy.
- `optional-${directory_name}-ephemeral-volume.json`: JSON file to enforce an ephemeral volume configuration for a Kyverno policy.
- `optional-${directory_name}-emptydir-volume.json`: JSON file to revert an ephemeral volume configuration to emptyDir. This file is provided in case you want to revert to using emptyDir volumes.
- `optional-${directory_name}-pdb.yaml`: YAML file for the Pod Disruption Budget (PDB) that can be applied to the operator's namespace to enforce the PDB policy. The PDB file is provided for operators that can enable PDB.

In the capability directories a sample CR YAML file includes the `no_empty_dir_on_mount` parameter set to true.
- 📁 `sample/optional-ibm_cp4a_cr_production_FC_<pattern_name>.yaml`: The fully customizable CR file for the CP4BA capability or pattern, which includes the `no_empty_dir_on_mount` parameter for CP4BA operands.

## Before you begin

1. Review the Kyverno policies in each operator directory to understand the configurations.

2. Make copies of the files for your environment. 

## Applying Kyverno policies to the CP4BA operators by running a script 

You can use the provided `cp4ba-kyverno-patch.sh` script to automate the patching process for all relevant operators. The script can be run in three different modes. You can choose to apply the patch to all the running operators or select one or more specific operators. 

```bash
bash cp4ba-kyverno-patch.sh -n <namespace> -m <mode> [-s <storage-class>] [-o <operator1,operator2,...>]
```
> **Where:**

- `<namespace>` The namespace where the operators are installed (required).
- `<mode>` You must select one of the following modes (required):
  - `ha`: Applies high availability configuration patches. The mode includes setting the number of replicas to 2 for the CP4BA deployments and applying the provided PDB configuration.
  - `ephemeral`: Applies the ephemeral volume configuration patches. The script automatically updates the `storageClassName` in all the JSON templates, so you do not need to manually edit the JSON files.
  - `emptydir`: Reverts to the emptyDir volume configuration. 
  - `pdb`: Creates the operator PDB by using the provided YAML file. The script checks the replica count in the operator CSV to figure out the minAvailable value setting for the PDB. If the operator CSV does not exist, `minAvailable` is set to 0.
- `<storage-class>` Sets the block storage class to be used for ephemeral volumes (for the `ephemeral` mode only). If you do not provide a storage class name in `ephemeral` mode, then the script prompts you to enter one.
- `<operator-names>` Use a comma-separated list of operator names to patch (optional). The operator names must match the directory names. For example, `ibm-cp4a-operator, ibm-content-operator`. If not provided, all available operators are patched.

> 🎯 **Note:** 
> - The ephemeral volumes are created with the default size. If you need, you can resize them by updating the CR. For more information, see the sample CR files in the `sample/` directories.

## Applying a Kyverno policy to the CP4BA operators manually 

1. Get the name of the CSV for the operator that you want to apply the policy to. You can do this by running the following command:

   ```bash
   oc get csv -n <operator-namespace>
   ```

2. To apply the Kyverno policy that you want, use the following command. 

   ```bash
   oc patch csv <csv-name> --patch-file <patch-file> --type json
   ```
   > - Replace `<csv-name>` with the name of the CSV that you retrieved in step 1.
   > - Replace `<patch-file>` with the path and name of the desired JSON file. 
   
3. If you want to apply the Pod Disruption Budget (PDB) configuration, use the provided YAML file and run the following command:

   ```bash
	oc apply -f optional-${directory_name}-pdb.yaml
	```

## Applying the generic ephemeral volume configuration to a CP4BA deployment (operand)

Sample CR files are provided for you in the `sample` directories to copy and paste the Kyverno-related CR parameters into your CP4BA deployment CR at the correct place.

1. Add the `no_empty_dir_on_mount` configuration parameter to your CP4BA deployment CR. 
   ```yaml
   spec:
     shared_configuration:
       sc_kyverno_compliance_mode_enabled:
         no_empty_dir_on_mount: true
   ```
2. If you updated the CR offline, apply the updated CR.
   ```bash
   oc apply -f <ibm_cp4a_cr>.yaml
   ```
   > - Replace `<ibm_cp4a_cr>` with the name of your CR file.

3. Monitor the status of your pods from the command line. 
   ```bash
   oc get pods -w
   ```

4. When all the pods are "Running", you can access the status of your services with the following command.
   ```bash
   oc status
   ```
