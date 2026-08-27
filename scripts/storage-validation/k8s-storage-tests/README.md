# Storage Validation Tool for IBM Cloud Paks

Kubernetes has gained a lot of momentum with storage vendors providing support on various container orchestration platforms with [CSI](https://kubernetes-csi.github.io/docs/drivers.html) drivers and other mechanisms.

It has become essential for platform administrators to quickly validate a storage platform for their modernized workloads on IBM Cloud Paks and check its readiness level.

This Ansible Playbook helps functionally validate a storage on `ReadWriteOnce` and `ReadWriteMany` volumes. Note that these tests covers readiness and are only meant to be a pre-cursor to a full blown test with actual Cloud Pak workloads.

>**Note that: if the tests in this storage readiness project are successful, it's strongly recommended that you continue to perform further performance tests on the storage by following this companion project at https://github.com/IBM/k8s-storage-perf, and perform the tests provided there. It will give you a good assessment of the particular storage performance.**

The following tests are performed:

 - Dynamic provisioning of a volume
 - Mounting volume from a node
 - Sequential [Read Write Consistency](./roles/storage-readiness/README.md#read-write-tests) from single and multiple nodes
 - Parallel Read Write Consistency from single and multiple nodes
 - Parallel Read Write Consistency across multiple threads
 - File Permissions on mounted volumes
 - Accessibility based on POSIX compliance [Group ID Permissions](./roles/storage-readiness/README.md#gid-tests)
 - [SubPath](https://kubernetes.io/docs/concepts/storage/volumes/#using-subpath) test for volumes
 - [File Locking](https://pubs.opengroup.org/onlinepubs/9699919799/functions/fcntl.html) test

### Prerequisites

- Ensure you have python 3.6 or later and [pip](https://pip.pypa.io/en/stable/installation/) 21.1.3 or later installed

  `python --version`

  `pip --version`

  >NB: if your python interpreter is using `python3` or `python37` or other Python 3 executables, you can create a symlink for `python` using this command

  ```
  ln -s -f /usr/bin/python3 /usr/bin/python
 
  # OR depends on the Python 3 installation location
 
  ln -s -f /usr/local/bin/python3 /usr/local/bin/python
  ```

  >NB: if `pip` is not available or is an older version, run the command below to upgrade it, and then check its version again. If `pip` command
  can't be found after the below command, add `/usr/local/bin` into your PATH ENV variable.
  
  `python -m pip install --upgrade pip`
  
- Install Ansible 2.10.5 or later

  `pip install ansible==2.10.5`

- Install ansible k8s modules

  `pip install openshift`

  `ansible-galaxy collection install operator_sdk.util`

  `ansible-galaxy collection install kubernetes.core`

   >NB: the `openshift` package installation requires PyYAML >= 5.4.1, and if the existing PyYAML is an older version, then PyYAML's 
   installation will fail. To overcome this issue, manually delete the exsiting PyYAML package as below (adjust the paths in the commands 
   according to the your host environment):
   
   ```
   rm -rf /usr/lib64/python3.6/site-packages/yaml
   rm -f  /usr/lib64/python3.6/site-packages/PyYAML-*
   ```
   
- Install [OpenShift Client 4.6 or later](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.6.31) based on your OS.

- Access to the OpenShift Cluster (at least 3 compute nodes) setup with RWX and RWO storage classes with cluster admin access.

### Setup

  - Clone this git repo to your client

   ```
     git clone https://github.com/IBM/k8s-storage-tests.git
   ```

 - Update the `params.yml` file with your OCP URL and Credentials

   ```
    ocp_url: https://<required>:6443
    ocp_username: <required>
    ocp_password: <required>
    ocp_token: <required if user/password not available>
   ```

 - Update the `params.yml` file for the `required` storage parameters

    ```
    storageClass_ReadWriteOnce: <required>
    storageClass_ReadWriteMany: <required>
    storage_validation_namespace: <required>
    ```

### Running the Playbook

 - From the root of this repository, run:

  ```bash
    ansible-playbook main.yml --extra-vars "@./params.yml" | tee output.log
  ```

  If the playbook fails to run due to SSL verification error, you can disable it by setting this environment variable before running the playbook

  ```
  export K8S_AUTH_VERIFY_SSL=no
  ```


### Running the Playbook with the Container

#### Environment Setup

```sh
export dockerexe=podman # or docker
export container_name=k8s-storage-test
export docker_image=icr.io/cpopen/cpd/k8s-storage-test:v1.0.0

alias k8s_storage_test_exec="${dockerexe} exec ${container_name}"
alias run_k8s_storage_test="k8s_storage_test_exec ansible-playbook main.yml --extra-vars \"@/tmp/work-dir/params.yml\" | tee output.log"
alias run_k8s_storage_test_cleanup="k8s_storage_test_exec cleanup.sh -n ${NAMESPACE} -d"
```

#### Start the Container

```sh
mkdir -p /tmp/k8s_storage_test/work-dir
cp ./params.yml /tmp/k8s_storage_test/work-dir/params.yml

${dockerexe} pull ${docker_image}
${dockerexe} run --name ${container_name} -d -v /tmp/k8s_storage_test/work-dir:/tmp/work-dir ${docker_image}
```

#### Run the Playbook

```sh
run_k8s_storage_test
```

#### Optional Cleanup the Cluster

```sh
run_k8s_storage_test_cleanup

[INFO ] running clean up for namespace storage-validation-1 and the namespace will be deleted
[INFO ] please run the following command in a terminal that has access to the cluster to clean up after the ansible playbooks

oc get job -n storage-validation-1 -o name | xargs -I % -n 1 oc delete % -n storage-validation-1 && \
oc get pvc -n storage-validation-1 -o name | xargs -I % -n 1 oc delete % -n storage-validation-1 && \
oc get cm -n storage-validation-1 -o name | xargs -I % -n 1 oc delete % -n storage-validation-1 && \
oc delete ns storage-validation-1 --ignore-not-found && \
oc delete scc zz-fsgroup-scc --ignore-not-found

[INFO ] cleanup script finished with no errors
```

### Verifying your results

Regardless of whether you run the Playbook or use the Container,
on a successful run, you should see the following output:

```
 ######################## MOUNT TESTS PASSED FOR ReadWriteOnce Volume  #################################
 ######################## MOUNT TESTS PASSED FOR ReadWriteMany Volume  #################################
 ######################## SEQUENTIAL READ WRITE TEST PASSED FOR ReadWriteOnce Volume ###################
 ######################## SEQUENTIAL READ WRITE TEST PASSED FOR ReadWriteMany Volume ###################
 ######################## SINGLE THREAD PARALLEL READ WRITE TEST PASSED for ReadWriteOnce ##############
 ######################## SINGLE THREAD PARALLEL READ WRITE TEST PASSED for ReadWriteMany ##############
 ######################## MULTI NODE PARALLEL READ WRTIE TEST PASSED FOR ReadWriteOnce #################
 ######################## MULTI NODE PARALLEL READ WRTIE TEST PASSED FOR ReadWriteMany #################
 ######################## FILE UID TEST PASSED FOR ReadWriteMany Volume ################################
 ######################## FILE PERMISSIONS TEST PASSED FOR ReadWriteMany Volume ########################
 ######################## FILE PERMISSIONS TEST PASSED FOR ReadWriteOnce Volume ########################
 ######################## SUB PATH TEST PASSED FOR ReadWriteMany Volume ################################
 ######################### FILE LOCK TESTS PASSED FOR ReadWriteMany Volume #############################
```

```
 PLAY RECAP *********************************************************************
 localhost                  : ok=109  changed=42   unreachable=0    failed=0    skipped=7    rescued=0    ignored=0   
```

## Clean-up Resources

Delete the kuberbetes namespace that you created in [Setup](#setup), you can also run these commands to clean up the
resources in the namespace

```
oc delete job $(oc get jobs -n <storage_validation_namespace> | awk '{ print $1 }') -n <storage_validation_namespace>
oc delete cm $(oc get cm -n <storage_validation_namespace> | awk '{ print $1 }') -n <storage_validation_namespace>
oc delete pvc $(oc get pvc -n <storage_validation_namespace> | awk '{ print $1 }') -n <storage_validation_namespace>
oc delete scc zz-fsgroup-scc
```

OR

```
oc delete project <storage_validation_namespace>
oc delete scc zz-fsgroup-scc
```
