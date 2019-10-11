## Create PVs, PVCs, certificates and secrets using init_deployment.sh

To use the init_deployments.sh script to create preqrequisites:
1) Populate the common.sh file with appropriate values based on the instructions in [common.sh values](./common_sh_values.md)
2) Run the init_deployments.sh script to create objects based on common.sh values
3) Verify the objects were created by running the following commands:  
    Check pvcs
    ```console
    # kubectl -n sp get pvc
    NAME            STATUS    VOLUME            CAPACITY   ACCESS MODES   STORAGECLASS   AGE
    sp-config-pvc   Bound     sp-config-pv-sp   5Gi        RWX                           4d
    sp-data-pvc     Bound     sp-data-pv-sp     60Gi       RWX                           4d
    sp-log-pvc      Bound     sp-log-pv-sp      35Gi       RWX                           4d
    ```
    and verify that 3 PVCs were created  
    
    Check secrets
    ```console
    # kubectl -n sp get secrets
    NAME                       TYPE                                  DATA      AGE
    baca-basedb                Opaque                                1         4d
    baca-ingress-secret        kubernetes.io/tls                     2         4d
    baca-ldap                  Opaque                                1         4d
    baca-minio                 Opaque                                2         4d
    baca-mongo                 Opaque                                3         4d
    baca-mongo-admin           Opaque                                3         4d
    baca-rabbitmq              Opaque                                4         4d
    baca-redis                 Opaque                                1         4d
    baca-secretssp             Opaque                                14        4d

    ```
    and verify that 9 secrets were created (might only be 7 if not using LDAP or ingress)
4) Run `./generateMemoryValues.sh <limited>` or .`/generateMemoryValues.sh <distributed>`
    >Note For smaller system (5 worker-nodes or less) where the mongo database pods will be on the same worker node as other pods, use limited option.  
 
    Copy these values for replacement in the values.yaml file if you want to deploy CA using Helm chart, or replacing these values in the ca-deploy.yml file if you want to deploy CA using kubernetes YAML files.     

    Back to [Overview](../configuration/README.md)
