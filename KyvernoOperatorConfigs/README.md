# CP4BA Operator's patch files for Kyverno policies for IBM Cloud Pak for Business Automation deployments

This directory contains JSON files and sample CR yaml that will be used to patch the Operator's CSV to enforce best practices and optional configurations for IBM Cloud Pak for Business Automation deployments. The JSON and YAML files cover three Kyverno policies:

1. **High Availability (HA) Configuration for Operators**: This policy ensures that the deployments of various operators within IBM Cloud Pak for Business Automation are configured for high availability by setting the number of replicas to a minimum of 2.
2. **Pod Disruption Budget (PDB) Configuration for Operators**: This policy ensures that the deployments of various operators within IBM Cloud Pak for Business Automation have a Pod Disruption Budget (PDB) configured to maintain availability during disruptions.  The PDB will be configured with `minAvailable: 1` to ensure that at least one replica is always available.
3. **Ephemeral Volume Configuration**:
     - **Operators**: This policy ensures that the deployments of various operators within IBM Cloud Pak for Business Automation are configured to use ephemeral volumes instead of emptyDir volumes. The ephemeral configuration for operator will be achieved by patching the CSV manually or by using the provided `cp4ba-kyverno-patch.sh` script to automate the patching process for all relevant operators. See the "Usage" section below for more details on how to use the script. 
     - **Operands**:  This policy ensures that the deployments of various operands within IBM Cloud Pak for Business Automation are configured to use ephemeral volumes instead of emptyDir volumes.  To enable this policy, you must set the following in the Custom Resource (CR)

        ```yaml
        spec:
          shared_configuration:
            sc_kyverno_compliance_mode_enabled:
              no_empty_dir_on_mount: true
        ```

NOTE:

- The block storage class (spec.shared_configuration.sc_block_storage_classname) will be used to create the ephemeral volumes.
- The ephemeral volumes will be created with default size.  They can be resized by updating the Custom Resource (CR) if needed.  Please refer to the sample CR in the subdirectories for more information.

## Directory Structure

- `ibm-ads-operator/`: Contains JSON files for patching DICMS operator's CSV to support HA, PDB template and ephemeral volume configurations.
- `ibm-ccx-ai-services-operator/`: Contains JSON files for patching Content Cortex AI Services operator's CSV to support HA, PDB template and ephemeral volume configurations.
- `ibm-content-operator/`: Contains JSON files for patching Content operator's CSV to support HA, PDB template and ephemeral volume configurations.
- `ibm-cp4a-operator/`: Contains JSON files for patching CP4BA operator's CSV to support HA, PDB template and ephemeral volume configurations.
- `ibm-cp4a-wfps-operator/`: Contains JSON files for patching WFPS operator's CSV to support HA, PDB template,PDB template and ephemeral volume configurations.
- `ibm-dpe-operator/`: Contains JSON files for patching DPE operator's CSV to support HA, PDB template and ephemeral volume configurations.
- `ibm-insights-engine-operator/`: Contains JSON files for patching BAI operator's CSV to support HA, PDB template and ephemeral volume configurations.
- `ibm-odm-operator/`: Contains JSON files for patching ODM operator's CSV to support HA, PDB template and ephemeral volume configurations.
- `ibm-pfs-operator/`: Contains JSON files for patching PFS operator's CSV to support HA, PDB template and ephemeral volume configurations.
- `ibm-workflow-runtime-operator/`: Contains JSON files for patching Workflow Runtime operator's CSV to support HA, PDB template and ephemeral volume configurations.
- `icp4a-foundation-operator/`: Contains JSON files for patching CP4BA Foundation operator's CSV to support HA, PDB template and ephemeral volume configurations.
  
Each subdirectory contains three JSON files and one YAML file:

- `optional-<operator>-ha.json`: JSON file to support Kyverno policy for enforcing high availability configuration.
- `optional-<operator>-ephemeral-volume.json`: JSON file to support Kyverno policy for enforcing ephemeral volume configuration.
- `optional-<operator>-emptydir-volume.json`: JSON file to revert Kyverno policy for enforcing emptyDir volume configuration.  This file is provided in case you want to revert back to using emptyDir volumes.
- `optional-<operator>-pdb.yaml`: YAML file for the Pod Disruption Budget (PDB) that can be applied to the operator's namespace to enforce the PDB policy.  This file is only provided for operators that have the PDB policy.

## Usage

### Manual Patching for CP4BA Operators

1. Review the JSON files in each subdirectory to understand the configurations being enforced and modify them as needed. 

2. Retrieve the name of the ClusterServiceVersion (CSV) for the operator you want to patch. You can do this by running the following command:

   ```bash
   kubectl get csv -n <operator-namespace>
   ```

3. To patch the CSVs, use the following command. Replace `<patch-file>` with the path to the desired patch file. Replace `<csv name>` with the name of the ClusterServiceVersion you retrieved in the previous step.

   ```bash
   kubectl patch csv <csv name> --patch-file <patch-file> --type json
   ```

4. If you want to apply the Pod Disruption Budget (PDB) configuration, you can apply the provided YAML file using the following command:

   ```bash
   kubectl apply -f <pdb-yaml-file>
   ```

### Automated Patching for CP4BA Operators

You can use the provided `cp4ba-kyverno-patch.sh` script to automate the patching process for all relevant operators. When using ephemeral mode, the script will automatically update the `storageClassName` in all JSON templates, eliminating the need for manual JSON file editing.

To execute the script:

```bash
bash cp4ba-kyverno-patch.sh -n <namespace> -m <mode> [-s <storage-class>] [-o <operator1,operator2,...>]
```

Where:

- `<namespace>` is the namespace where the operators are installed (required).
- `<mode>` can be one of the following (required):
  - `ha`: Apply high availability configuration patches. This will include setting the number of replicas to 2 for the operator deployments and applying the provided PDB configuration with `minAvailable` set to `1`.
  - `ephemeral`: Apply ephemeral volume configuration patches.
  - `emptydir`: Revert to emptyDir volume configuration patches.
  - `pdb`: Create operator PDB using the provided YAML file.  The script will check for the existence of the operator CSV to determine the replica count for setting the `minAvailable` value in the PDB. If the operator CSV does not exist, it will default to setting `minAvailable` to 0.
- `<storage-class>` is an optional block storage class to be used for ephemeral volumes. If not provided when using `ephemeral` mode, the script will prompt you to enter it interactively.
- `<operator names>` is an optional comma-separated list of operator names to patch. The operator name must match the directory name (eg: cp4a-operator, content-operator, etc..). If not provided, all available operators will be patched.