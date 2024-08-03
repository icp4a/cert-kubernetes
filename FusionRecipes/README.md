# IBM Storage Fusion - Cloud Pak for Business Automation
## _Online backup and restore_

## Software requirements

- IBM Cloud Pak for Business Automation 24.0.0
- [IBM Storage Fusion 2.8.x](https://www.ibm.com/docs/en/storage-fusion-software/2.8.x)
- IBM Cloud Pak for Business Automation services:
    - FileNet Content Manager, Business Automation Workflow Runtime, Business Automation Workflow Authoring
    - There are 3 different recipes for 3 different installations:
        a. FNCM is installed using external database without any additional features and customiaztion like custom certifcates.
        b. BAW Authoring is installed using external database without any additional features and customiaztion like custom certifcates.
        c. BAW Runtime is installed using external database without any additional features and customiaztion like custom certifcates.
- IBM Cloud Pak for Business Automation Fusion scripts and recipes
    - CP4BA cert-kubernetes package
- Install jq bastion host where the Fusion script will be executed
    #### For Mac
    ```
      brew install jq
    ```
    #### For Linux 
    ```
      sudo apt update
      sudo apt install jq
    ```
- Make sure that the production storage that is hosting Cloud Pak for Business Automation is CSI compatible.

## Backup configuration steps

1. Install Storage Fusion 2.8.x
    a. [Obtain the entitlement key](https://www.ibm.com/docs/en/storage-fusion-software/2.8.x?topic=prerequisites-obtaining-entitlement-key).
    b. [Create an image pull secret](https://www.ibm.com/docs/en/storage-fusion-software/2.8.x?topic=prerequisites-creating-image-pull-secret).
    c. Install the IBM Storage Fusion operator. There are different sets of instructions based on the type of OCP deployment. This is an example for [On-premises VMware](https://www.ibm.com/docs/en/storage-fusion-software/2.8.x?topic=fusion-installing-storage-premises-vmware).
    d. [Deploy a Fusion Backup & Restore service](https://www.ibm.com/docs/en/storage-fusion-software/2.8.x?topic=deploying-storage-fusion-services).
2. Configure general Backup & Restore (from the IBM Storage Fusion user interface)  
    a. Create a backup storage location. This object storage is where backups will be stored. It can be any s3 compatible storage or [Microsoft Azure Blob storage](https://www.ibm.com/docs/en/storage-fusion-software/2.8.x?topic=applications-backup-storage-locations).
    b. [Create a backup policy](https://www.ibm.com/docs/en/storage-fusion-software/2.8.x?topic=policies-creating-backup-policy). This defines the frequency of the backup (how often it runs), the retention (how long backups are kept), and location of the backups (backup storage location configured above). 
3. Configure Cloud Pak for Business Automation and IBM Fusion specific Backup & Restore 
    a. Export the cp4ba namespace to the `NAMESPACE` variable. For example:
    ```sh
      export NAMESPACE=<namespace>
    ```
    b. Apply the labels to select the resources in the recipe. 
    - If BAW is installed then update the CP4BA namespace in the `labels_baw_template.sh` script.
        ```sh
        awk -v CP4BA_NAMESPACE="$NAMESPACE" '{gsub(/\$REPLACE_NAMESPACE/, CP4BA_NAMESPACE)}1' scripts/labels_baw_template.sh > scripts/labels_baw.sh 
        ```
        ```sh
        chmod +x ./scripts/labels_baw.sh
        ```
        ```sh
        ./scripts/labels_baw.sh
        ```
    - If FNCM is installed use the FNCM script: 
        ```sh
        ./scripts/labels_fncm.sh
        ```
    c. Update the cluster role in the `transaction-manager-ibm-backup-restore` so you can check the status of custom resource (i.e. Ready). This step is required during a restore on the target cluster i.e. when you do a restore.
    - If BAW is installed then run the following command.
        ```sh
        oc get clusterrole transaction-manager-ibm-backup-restore -o json | jq '.rules += [{"verbs":["get","list"],"apiGroups":["icp4a.ibm.com"],"resources":["icp4aclusters"]}]' | oc apply -f -
         ```
    - If FNCM is installed then run the following command.
        ```sh
        oc get clusterrole transaction-manager-ibm-backup-restore -o json | jq '.rules += [{"verbs":["get","list"],"apiGroups":["icp4a.ibm.com"],"resources":["contents"]}]' | oc apply -f -
        ```
    d. Edit the Fusion application to include these namespaces under the `includedNamespaces: openshift-config, openshift-marketplace`
    ```sh
    oc edit fapp $NAMESPACE -n ibm-spectrum-fusion-ns
    ```
    ```yaml
    spec:
      enableDR: false
      includedNamespaces:
      - <NAMESPACE>
      - openshift-marketplace
      - openshift-config
    ```    
    e. Create the resources for the Zen service backup.
    - Get the storage classes to update in `yamls/zen/zen5-backup-pvc.yaml`
        ```sh
        oc get sc
        ```
    - Update the storage class in `yamls/zen/zen5-backup-pvc.yaml`
    - Apply the following resources.
        ```sh
        oc apply -f yamls/zen/zen5-backup-pvc.yaml -n $NAMESPACE 
        oc apply -f yamls/zen/zen5-br-scripts-cm.yaml -n $NAMESPACE
        oc apply -f yamls/zen/zen5-backup-deployment.yaml -n $NAMESPACE
        oc apply -f yamls/zen/zen5-role.yaml -n $NAMESPACE
        oc apply -f yamls/zen/zen5-sa.yaml -n $NAMESPACE
        oc apply -f yamls/zen/zen5-rolebinding.yaml -n $NAMESPACE
        ```
    f. Update the labels in the recipe in case you updated the database name during installation i.e. `db-name=ICNDBf, db-name=BASDBf, db-name=BAWDBf`
    
    g. Update the CP4BA namespace in the following recipes and then apply.
    **Note**: If you want to use the postgres based common services recipes then use `-v1` files.
    - If FNCM is installed.
        ```sh
        awk -v CP4BA_NAMESPACE="$NAMESPACE" '{gsub(/\$REPLACE_NAMESPACE/, CP4BA_NAMESPACE)}1' cp4ba-fncm-backup-restore-template.yaml > cp4ba-fncm-backup-restore.yaml
        ```
        ```sh
        oc apply -f cp4ba-fncm-backup-restore.yaml
        ```      
    - If BAW Authoring is installed.
        ```sh
        awk -v CP4BA_NAMESPACE="$NAMESPACE" '{gsub(/\$REPLACE_NAMESPACE/, CP4BA_NAMESPACE)}1' cp4ba-baw-authorize-backup-restore-template.yaml > cp4ba-baw-authorize-backup-restore.yaml
        ```
        ```sh
        oc apply -f cp4ba-baw-authorize-backup-restore.yaml 
        ```    
    - If BAW Runtime is installed.
        ```sh
        awk -v CP4BA_NAMESPACE="$NAMESPACE" '{gsub(/\$REPLACE_NAMESPACE/, CP4BA_NAMESPACE)}1' cp4ba-baw-runtime-backup-restore-template.yaml > cp4ba-baw-runtime-backup-restore.yaml
        ```
        ```sh
        oc apply -f cp4ba-baw-runtime-backup-restore.yaml 
        ```
    h. Create a backup policy from the Fusion UI or the CLI.
    - From the Fusion UI --> Backup & restore --> Policies --> Add policy --> (fill details) --> Create policy
         ```sh
        oc get fbp -A 
         ```
    - From the CLI: 
        - Get the fusion backup storage location.
          ```sh
          oc get fbsl -n ibm-spectrum-fusion-ns
          ```
        - Run the following script.
        `/scripts/setup/fbackup_policy.sh <POLICY_NAME> <FBSL_NAME> <RETENTION_PERIOD> <RETENTION_UNIT> <CRON_EXPRESSION> <TIMEZONE>`
        For example:
          ```sh
          ./scripts/setup/fbackup_policy.sh baw-runtime-policy my-bucket 10 days "00 0 1 * *" UTC
          ```
    i. Assign a backup policy to the CP4BA application from Fusion UI and update the policy assignment from the CLI.
    **Note:** CP4BA is installed in the `$NAMESPACE` namespace. So, `$NAMESPACE` is the application that needs to be protected.
    - From the Fusion UI --> Backup & restore --> Backed up applications --> Project apps --> Select a cluster --> Select application --> Next --> Select a backup policy --> Assign
        ```sh
        oc get fpa -A
        ```
    - Update the policy assignment (patch the recipe accordingly i.e FNCM, BAW-Authoring, BAW-Runtime)
        ```sh
        oc -n ibm-spectrum-fusion-ns patch policyassignment baw-authoring-baw-authoring-policy-apps.ocp4xdcd.cp.fyre.ibm.com --type merge -p '{"spec":{"recipe":{"name":"cp4ba-baw-authorize-backup-restore-recipe", "namespace":"ibm-spectrum-fusion-ns"}}}'
        ```
    - From the CLI: Create the backup policy assignment with the custom recipe.

        `/scripts/setup/fbackuppolicy_assignment.sh <POLICY_ASSIGNMENT_NAME> <APPLICATION> <BACKUP_POLICY> <FBSL_NAME> <RECIPE_NAME>`

        For example:
        ```sh
        ./scripts/setup/fbackuppolicy_assignment.sh baw-runtime-fpa baw-runtime baw-runtime-policy my-bucket cp4ba-baw-runtime-backup-restore-recipe 
        ```
    j. Initiate a backup from the Fusion UI.
    - From the Fusion UI --> Backup & restore --> Backed up applications --> Click backed up application --> Actions --> Backup now.

## Restore configuration steps

1. Installation on spoke (optional)
	a. Create a code key from hub.
	b. Launch installation on hub (copy code key from hub).
	c. Show where recipe needs to be deployed on spoke.
2. Restore 
	a. [Restore the IBM Cloud Pak for Business Automation platform instance]( https://www.ibm.com/docs/en/storage-fusion-software/2.8.x?topic=applications-restoring-application)
	b. You can restore to the same OpenShift cluster or a different OpenShift cluster
    - In either case the target namespace(s) must be the same. In the IBM Storage Fusion user interface specify “Use the same project the application is already using”
    - In either case the target namespace(s) must be empty. IBM Storage Fusion will re-install the IBM Cloud Pak for Business Automation platform instance, restore the data, and recover the instance to a working state


## Troubleshooting

1. Debugging Backup & Restore
	a. To obtain the backup or restore recipe log information.
    - Download the `getRecipeWorkflow.sh` shell script from the IBM Storage Fusion git repository: https://github.com/IBM/storage-fusion/tree/master/backup-restore/recipes
    - Obtain the job UID for the backup or restore job from the IBM Storage Fusion user interface:
        - Select the Applications tab from the left hand navigation panel.
        - Select the Application from the table, for example “filebrowser”.
        - Select the Backups tab.
        - For the desired backup, select the right “…” menu and click Details.
        - Click the hyperlink of the job name, for example:
            ```sh
            filebrowser-demo-daily-apps.spparch.spp-ocp.tuc.stglabs.ibm.com-202311220800
            ```
        - Note the Job ID in the details panel, for example:
            ```sh
            63eb6ea5-dc24-41ef-9fb7-199c48df1508
            ```
    - Obtain the job UID for the backup or restore job from the command line.
        - Open the YAML file for the desired Fusion Backup CR, for example:
            ```sh
            oc get fbackup  filebrowser-demo-daily-apps.spparch.spp-ocp.tuc.stglabs.ibm.com-202311220800 -n ibm-spectrum-fusion-ns -o yaml
            ```
        - Locate the uid field in the `spec: metadata`. For example:
            ```sh
            uid: 63eb6ea5-dc24-41ef-9fb7-199c48df1508
            ```
    - Run the `getRecipeWorkflow.sh` shell script with the job uid. For example:
        ```sh
        ./getRecipeWorkflow.sh backup 63eb6ea5-dc24-41ef-9fb7-199c48df1508
        ```

	b. To get a list of the resources that you backed up or restored.
    - Download the `getResources.sh` shell script from the IBM Storage Fusion git repository: https://github.com/IBM/storage-fusion/tree/master/backup-restore/recipes.
    - Obtain the job UID for the backup or restore job as indicated in the previous step.
    - Run the `getResources.sh` shell script with the job uid. For example: 
        ```sh
        ./getResources.sh backup 63eb6ea5-dc24-41ef-9fb7-199c48df1508
        ```
2. Information about protecting the Backup & restore service can be found in the Service protection section of the IBM Storage Fusion Knowledge Center.
