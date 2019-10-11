# IBM-DBA-AAE-PROD

IBM Business Automation Application Engine (App Engine)

## Introduction

This IBM Business Automation Application Engine Helm chart deploys the App Engine, a user interface service tier to run applications that are built by IBM Business Automation Application Designer (App Designer). This Helm chart is a platform-level Helm chart that deploys all required components.

## Chart Details

This chart deploys several services and components.

In the standard configuration, it includes these components:

* IBM Resource Registry component
* IBM Business Automation Application Engine (App Engine) component

To support those components, a standard installation generates:

  * 3 ConfigMaps that manage the configuration of App Engine
  * 1 deployment running App Engine
  * 1 StatefulSet running Resource Registry
  * 4 or more jobs for Resource Registry, depending on the customized configuration
  * 1 service account with related role and role binding
  * 3 secrets to get access during chart installation
  * 3 services and optionally an Ingress or Route (OpenShift) to route the traffic to the App Engine
  
## Prerequisites

  * [Red Hat OpenShift 3.11](https://docs.openshift.com/container-platform/3.11/welcome/index.html) or later
  * [Helm and Tiller 2.9.1](https://github.com/helm/helm/releases) or later if you are [using helm charts](#using-helm-charts) to deploy your container images
  * [Cert Manager 0.8.0](https://cert-manager.readthedocs.io/en/latest/getting-started/install/openshift.html) or later if you want to use Cert Manager to create the Transport Layer Security (TLS) key and certificate secrets. Otherwise, you can use Secure Sockets Layer (SSL) tools to create the TLS key and certificate secrets.
  * [IBM DB2 11.1.2.2](https://www.ibm.com/products/db2-database) or later
  * [IBM Cloud Pack For Automation - User Management Service (UMS)](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.offerings/topics/con_ums.html)
  * Persistent volume support

### Preparing the environment for the application engine

1. Log in to OC (the OpenShift command line interface (CLI)) by running the following command. You are prompted for the password.

  ``` 
    oc login <OpenShift-URL> -u <username>
  ``` 

2. Create a project (namespace) for the App engine by running the following command:

    ```
    oc new-project <namespace> 
    ```

3. Save and exit.

4. To deploy the service account, role, and role binding successfully, assign the administrator role to the user for this namespace by running the following command:

  ```
  oc project <project-name>
  oc adm policy add-role-to-user admin <deploy-user-name>
  ```

5. If you want to operate persistent volumes (PVs), you must have the storage-admin cluster role, because PVs are a cluster resource in OpenShift. Add the role by running the following command:

  ```
  oc adm policy add-cluster-role-to-user storage-admin <deploy-user-name>
  ```

### Uploading the images

Upload the IBM Business Automation Application Engine images to the Docker registry of the Kubernetes cluster. See [Download a product package from PPA and load the images](https://github.ibm.com/dba/cert-kubernetes/blob/master/README.md#download-ppa-and-load-images).

### Generating the database script and YAML files

Use the [App Engine platform Helm installation helper script](configuration) to generate the database script and YAML files for your environment. Follow the instructions in the [readme](configuration/README.md) for the following requirements:

* Setting up the database for App Engine
* Protecting sensitive configuration data
* Setting up the TLS key and certificate secrets
* Setting the service type

If you don't want to use the helper script, you can create your own secrets and service type by following the instructions in the [Knowledge Center](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/welcome/kc_welcome_dba_distrib.html).


#### Notes
* Image pull secret: The script does not generate the image pull secret. You can follow the instructions in [Configuring the secret for pulling Docker images](#Configuring-the-secret-for-pulling-docker-image) to create your own.
* Storage: The script does not generate a YAML file for persistent volumes. You can follow the instructions in [Implementing storage](#implementing-storage) to create your own perstent volumes.
* UMS-related configuration and TLS certificates: You must do this configuration if you have an existing UMS that is in a different namespace from the App Engine Helm chart.

### Preparing UMS-related configuration and TLS certificates (optional)

If you have an existing UMS that is in a different namespace from the App Engine Helm chart, follow these steps.

If the UMS certificate is not signed by the same root CA, you must add the root CA as trusted instead of the UMS certificate. You should first get the root CA which is used to sign the UMS, and then save it to a certificate named like `ums-cert.crt`, then create the secret by running the following command:


    
      kubectl create secret generic ca-tls-secret --from-file=tls.crt=./ums-cert.crt
    

You will get a secret named ca-tls-secret. Enter this secret value in every TLS section for Resource Registry and App Engine that is listed in [Configuration](#configuration). If you use [App Engine platform Helm installation helper script](configuration) to setup App Engine, you can enter this secret value in [`ums.tlsSecretName`](configuration) The components will trust this certificate and communicate with UMS successfully.

  ```
    tls:
        tlsSecretName: <Your component tls secret>
        tlsTrustList:
        - ca-tls-secret
   ```

### Configuring the secret for pulling Docker images

If you're pulling Docker images from a private registry, you must provide a secret containing credentials for it. For instructions, see the [Kubernetes information about private registries](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line). 

This command can be used for one repository only. If your Docker images come from different repositories, you can create multiple image pull secrets and add the names in global.imagePullSecrets. Or, you can create secrets by using the custom Docker configuration file.

The following sample shows the Docker auth file `config.json`:

```
{
  "auths": {
    "url1.xx.xx.xx.xx": {
      "auth": "xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    },
    "url2.xx.xx.xx.xx": {
      "auth": "xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    },
    "url3.xx.xx.xx.xx": {
      "auth": "xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    },
    "url4.xx.xx.xx.xx": {
      "auth": "xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    }
  }
}
```

The key under auths is the link to the Docker repository, and the value inside that repository name is the authentication string that is used for that repository. You can create the auth string with base64 by running the following command:

```
  # echo -n <username>:<password> | base64
```

You can replace the auth string by running the previous command with your config.json file. Then, create the image pull secret by running the following command:

```
  kubectl create secret generic image-pull-secret --from-file=.dockerconfigjson=<path to config.json> --type=kubernetes.io/dockerconfigjson
```

### Configuring Redis for App Engine (optional)

You can configure the App Engine with Remote Dictionary Server (Redis) to provide more reliable service.

1. Update the Redis host, port, and Time To Live (TTL) settings in `values.yaml`

    ```yaml
    redis:
      host: <Your redis cluster host IP/name>
      port: <Your redis cluster port>
      ttl: 1800
    ```

2. Set `.Values.appengine.session.useExternalStore` to `true`.
3. If Redis is protected by a password, enter the password in the `REDIS_PASSWORD` field in the `ae-secret-credential` secret that you created in [Protecting sensitive configuration data](#Protecting-sensitive-configuration-data).

4. If you want to protect Redis communication with TLS, you have the following options:

    * Sign the Redis certificate with a well-known CA.
    * Sign the Redis certificate with the same root CA used by this installation.
    * Use a zero depth self-signed certificate or sign the certificate with another root CA. Then save the certificate or root CA in the secret and enter the secret name in `.Values.appengine.tls.tlsTrustList`.

## Red Hat OpenShift SecurityContextConstraints Requirements

The predefined SecurityContextConstraints name [`restricted`](https://ibm.biz/cpkspec-scc) has been verified for this chart. If your target namespace is bound to this SecurityContextConstraints resource, you can proceed to install the chart.

This chart also defines a custom SecurityContextConstraints definition that can be used to finely control the permissions and capabilities needed to deploy this chart.

- From the user interface, you can copy and paste the following snippets to enable the custom SecurityContextConstraints.
  - Custom SecurityContextConstraints definition:
   
   ```yaml
      apiVersion: security.openshift.io/v1
      kind: SecurityContextConstraints
      metadata:
      annotations:
        kubernetes.io/description: "This policy is the most restrictive, 
          requiring pods to run with a non-root UID, and preventing pods from accessing the host." 
          cloudpak.ibm.com/version: "1.0.0"
      name: ibm-dba-aae-scc
      allowHostDirVolumePlugin: false
      allowHostIPC: false
      allowHostNetwork: false
      allowHostPID: false
      allowHostPorts: false
      allowPrivilegedContainer: false
      allowPrivilegeEscalation: false
      allowedCapabilities: []
      allowedFlexVolumes: []
      allowedUnsafeSysctls: []
      defaultAddCapabilities: []
      defaultPrivilegeEscalation: false
      forbiddenSysctls:
        - "*"
      fsGroup:
        type: MustRunAs
        ranges:
          - max: 65535
            min: 1
      readOnlyRootFilesystem: false
      requiredDropCapabilities:
      - ALL
      runAsUser:
        type: MustRunAsNonRoot
      seccompProfiles:
      - docker/default
      seLinuxContext:
        type: RunAsAny
      supplementalGroups:
        type: MustRunAs
        ranges:
        - max: 65535
          min: 1
      volumes:
      - configMap
      - downwardAPI
      - emptyDir
      - persistentVolumeClaim
      - projected
      - secret
      priority: 0
    ```

## Resources Required

Follow the OpenShift instructions in [Planning Your Installation](https://docs.openshift.com/container-platform/3.11/install/index.html#single-master-single-box). Then check the required resources in [System and Environment Requirements](https://docs.openshift.com/container-platform/3.11/install/prerequisites.html) and set up your environment.

| Component name | Container | CPU | Memory |
| --- | --- | --- | --- |
| App Engine | App Engine container | 1 | 512Mi |
| App Engine | Init Containers | 200m | 128Mi |
| Resource Registry | Resource Registry container | 200m | 256Mi |
| Resource Registry | Init containers | 200m | 256Mi |

## Installing the Chart

You can deploy your container images with the following methods:

- [Using Helm charts](helm-charts/README.md)
- [Using Kubernetes YAML](k8s-yaml/README.md)


## Configuration

The following table lists the configurable parameters of the chart and their default values. All properties are required, unless they have a default value or are explicitly optional. Although the chart might seem to install correctly when some parameters are omitted, this kind of configuration is not supported.

| Parameter                              | Description                                           | Default                                              |
| -------------------------------------- | ----------------------------------------------------- | ---------------------------------------------------- |
| `global.existingClaimName`             | Existing persistent volume claim name for the JDBC and ODBC library |                                                      |
| `global.nonProductionMode`             | Production mode. This value must be false.             | `false`                                                     |
| `global.imagePullSecrets`              | Existing Docker image secret                          |                                                      |
| `global.caSecretName`                  | Existing CA secret                                    |                                                      |
| `global.dnsBaseName`                   | Kubernetes Domain Name System (DNS) base name                              | `svc.cluster.local`                                                     |
| `global.contributorToolkitsPVC`        | Persistent volume for contributor toolkit storage        |                                                      |
| `global.image.keytoolInitcontainer`    | Image name for TLS init container                     | `dba-keytool-initcontainer:19.0.2`                                                     |
| `global.ums.serviceType`               | UMS service type: `NodePort`, `ClusterIP`, or `Ingress`  |                                                      |
| `global.ums.hostname`                  | UMS external host name                                |                                                      |
| `global.ums.port`                      | UMS port (only effective when using NodePort service) |                                                      |
| `global.ums.adminSecretName`           | Existing UMS administrative secret for sensitive configuration data |                                             |
| `global.resourceRegistry.hostname`     | Resource Registry external host name                  |                                                      |
| `global.resourceRegistry.port`         | Resource Registry port for using NodePort Service      |                                                      |
| `global.resourceRegistry.adminSecretName` | Existing Resource Registry administrative secret for sensitive configuration data |                                             |
| `global.appEngine.serviceType`         | App Engine service type: `NodePort`, `ClusterIP`, or `Ingress`  |                                                      |
| `global.appEngine.hostname`            | App Engine external host name                         |                                                      |
| `global.appEngine.port`                | App Engine port (only effective when using NodePort service) |                                                      |
| `appEngine.install`                    | Switch for installing App Engine                        | `true`                                                     |
| `appEngine.replicaCount`               | Number of deployment replicas                         | `1`                                                  |
| `appEngine.probes.initialDelaySeconds` | Number of seconds after the container has started before liveness or readiness probes are initiated | `5`                   |
| `appEngine.probes.periodSeconds`       | How often (in seconds) to perform the probe. The default is 10 seconds. Minimum value is 1. | `10`                                                  |
| `appEngine.probes.timeoutSeconds`      | Number of seconds after which the probe times out. The default is 1 second. Minimum value is 1. | `5`                                                  |
| `appEngine.probes.successThreshold`    | Minimum consecutive successes for the probe to be considered successful after failing. Minimum value is 1.   | `5`                                                  |
| `appEngine.probes.failureThreshold`    | When a pod starts and the probe fails, Kubernetes will try failureThreshold times before giving up. Minimum value is 1. | `3`                                                  |
| `appEngine.images.appEngine`           | Image name for App Engine container                   | `solution-server:19.0.2`                                                  |
| `appEngine.images.tlsInitContainer`    | Image name for TLS init container                     | `dba-keytool-initcontainer:19.0.2`     |
| `appEngine.images.dbJob`               | Image name for App Engine database job container      | `solution-server-helmjob-db:19.0.2`     |
| `appEngine.images.oidcJob`             | Image name for OpenID Connect (OIDC) registration job container        | `dba-umsregistration-initjob:19.0.2` |
| `appEngine.images.dbcompatibilityInitContainer` | Image name for database compatibility init container          | `dba-dbcompatibility-initcontainer:19.0.2`            |
| `appEngine.images.pullPolicy`          | Pull policy for all containers                        | `IfNotPresent`                       |
| `appEngine.tls.tlsSecretName`          | Existing TLS secret containing `tls.key` and `tls.crt`|                                                  |
| `appEngine.tls.tlsTrustList`           | Existing TLS trust secret                             | `[]`                                                  |
| `appEngine.database.name`              | App Engine database name                              |                                                  |
| `appEngine.database.host`              | App Engine database host                              |                                                 |
| `appEngine.database.port`              | App Engine database port                              |                                                 |
| `appEngine.database.type`              | App Engine database type: `db2`                       |                                                 |
| `appEngine.database.currentSchema`     | App Engine database Schema                            |                                                 |
| `appEngine.database.initialPoolSize`   | Initial pool size of the App Engine database      | `1`                                                |
| `appEngine.database.maxPoolSize`       | Maximum pool size of the App Engine database          | `10`                                                |
| `appEngine.database.uvThreadPoolSize`  | UV thread pool size of the App Engine database    | `4`                                                |
| `appEngine.database.maxLRUCacheSize`   | Maximum Least Recently Used (LRU) cache size of the App Engine database     | `1000`                                                |
| `appEngine.database.maxLRUCacheAge`    | Maximum LRU cache age of the App Engine database      | `600000`                                                |
| `appEngine.useCustomJDBCDrivers`       | Toggle for custom JDBC drivers                        | `false`                                                |
| `appEngine.adminSecretName`            | Existing App Engine administrative secret for sensitive configuration data |                                                 |
| `appEngine.logLevel.node`              | Log level for output from the App Engine server    | `trace`                                                |
| `appEngine.logLevel.browser`           | Log level for output from the web browser            | `2`                                                |
| `appEngine.contentSecurityPolicy.enable`| Enables the content security policy for the App Engine  | `false`                                                |
| `appEngine.contentSecurityPolicy.whitelist`| Configuration of the App Engine content security policy whitelist  | `""`                                                |
| `appEngine.session.duration`           | Duration of the session                           | `1800000`                            |
| `appEngine.session.resave`             | Enables session resave                               | `false`                                                |
| `appEngine.session.rolling`            | Send cookie every time                                | `true`                                                |
| `appEngine.session.saveUninitialized`  | Uninitialized sessions will be saved if checked       | `false`                                                |
| `appEngine.session.useExternalStore`   | Use an external store for storing sessions            | `false`                                                |
| `appEngine.redis.host`                 | Host name of the Redis database that is used by the App Engine |                                            |
| `appEngine.redis.port`                 | Port number of the Redis database that is used by the App Engine |                                                 |
| `appEngine.redis.ttl`                  | Time to live for the Redis database connection that is used by the App Engine |                                                 |
| `appEngine.maxAge.staticAsset`         | Maximum age of a static asset                     | `2592000`                                                |
| `appEngine.maxAge.csrfCookie`          | Maximum age of a Cross-Site Request Forgery (CSRF) cookie                      | `3600000`                                                |
| `appEngine.maxAge.authCookie`          | Maximum age of an authentication cookie           | `900000`                                                |
| `appEngine.env.serverEnvType`          | App Engine server environment type | `development`                                                |
| `appEngine.env.maxSizeLRUCacheRR`      | Maximum size of the LRU cache for the Resource Registry | `1000`                                                |
| `appEngine.resources.ae.limits.cpu`    | Maximum amount of CPU that is required for the App Engine container | `1`                                                |
| `appEngine.resources.ae.limits.memory` | Maximum amount of memory that is required for the App Engine container | `1024Mi`                                                |
| `appEngine.resources.ae.requests.cpu`  | Minimum amount of CPU that is required for the App Engine container    | `500m`                                                |
| `appEngine.resources.ae.requests.memory` | Minimum amount of memory that is required for the App Engine container    | `512Mi`                                                |
| `appEngine.resources.initContainer.limits.cpu`    | Maximum amount of CPU that is required for the App Engine init container | `500m`                                                |
| `appEngine.resources.initContainer.limits.memory` | Maximum amount of memory that is required for the App Engine init container | `256Mi`                                                |
| `appEngine.resources.initContainer.requests.cpu`  | Minimum amount of CPU that is required for the App Engine init container    | `200m`                                                |
| `appEngine.resources.initContainer.requests.memory` | Minimum amount of memory that is required for App Engine init container    | `128Mi`                                                |
| `appEngine.autoscaling.enabled` | Enable the Horizontal Pod Autoscaler for App Engine init container    | `false`                                                |
| `appEngine.autoscaling.minReplicas` | Minimum limit for the number of pods for the App Engine    | `2`                                                |
| `appEngine.autoscaling.maxReplicas` | Maximum limit for the number of pods for the App Engine    | `5`                                                |
| `appEngine.autoscaling.targetAverageUtilization` | Target average CPU utilization over all the pods for the App Engine init container    | `80`                                                |
| `resourceRegistry.install`             | Switch for installing Resource Registry                  | `true`                                                     |
| `resourceRegistry.images.resourceRegistry` | Image name for Resource Registry container        | `dba-etcd:19.0.2`                                                  |
| `resourceRegistry.images.pullPolicy`   | Pull policy for all containers                        | `IfNotPresent`                       |
| `resourceRegistry.tls.tlsSecretName`   | Existing TLS secret containing `tls.key` and `tls.crt`|                                                  |
| `resourceRegistry.replicaCount`        | Number of etcd nodes in cluster                       | `3`                                                 |
| `resourceRegistry.resources.limits.cpu`    | CPU limit for Resource Registry configuration | `500m`                                                |
| `resourceRegistry.resources.limits.memory` | Memory limit for Resource Registry configuration | `512Mi`                                                |
| `resourceRegistry.resources.requests.cpu`  | Requested CPU for Resource Registry configuration | `200m`                                                |
| `resourceRegistry.resources.requests.memory` | Requested memory for Resource Registry configuration   | `256Mi`                                                |
| `resourceRegistry.persistence.enabled` | Enables this deployment to use persistent volumes     | `false`                                                |
| `resourceRegistry.persistence.useDynamicProvisioning` | Enables dynamic binding of persistent volumes to created persistent volume claims     | `true`                                                |
| `resourceRegistry.persistence.storageClassName` | Storage class name                           |                                                 |
| `resourceRegistry.persistence.accessMode` | Access mode as ReadWriteMany ReadWriteOnce         |                                                 |
| `resourceRegistry.persistence.size`    | Storage size                                          |                                                 |
| `resourceRegistry.livenessProbe.enabled` | Liveness probe configuration enabled                | `true`                                   |
| `resourceRegistry.livenessProbe.initialDelaySeconds` | Number of seconds after the container has started before liveness is initiated | `120`                   |
| `resourceRegistry.livenessProbe.periodSeconds`       | How often (in seconds) to perform the probe         | `10`                                                  |
| `resourceRegistry.livenessProbe.timeoutSeconds`      | Number of seconds after which the probe times out    | `5`                                                  |
| `resourceRegistry.livenessProbe.successThreshold`    | Minimum consecutive successes for the probe to be considered successful after failing. Minimum value is 1.   | `1`                                                  |
| `resourceRegistry.livenessProbe.failureThreshold`    | When a pod starts and the probe fails, Kubernetes will try failureThreshold times before giving up. Minimum value is 1. | `3`                                                  |
| `resourceRegistry.readinessProbe.enabled` | Readiness probe configuration enabled               | `true`                                   |
| `resourceRegistry.readinessProbe.initialDelaySeconds` | Number of seconds after the container has started before readiness is initiated | `15`                   |
| `resourceRegistry.readinessProbe.periodSeconds`       | How often (in seconds) to perform the probe          | `10`                                                  |
| `resourceRegistry.readinessProbe.timeoutSeconds`      | Number of seconds after which the probe times out    | `5`                                                  |
| `resourceRegistry.readinessProbe.successThreshold`    | Minimum consecutive successes for the probe to be considered successful after failing. Minimum value is 1.   | `1`                                                  |
| `resourceRegistry.readinessProbe.failureThreshold`    | When a pod starts and the probe fails, Kubernetes will try failureThreshold times before giving up. Minimum value is 1. | `6`                                                  |
| `resourceRegistry.logLevel`    | Log level of the resource registry server. Available options: `debug` `info` `warn` `error` `panic` `fatal` | `info`                                                  |

## Implementing storage

This chart requires an existing persistent volume of any type. The minimum supported size is 1GB. Additionally, a persistent volume claim must be created and referenced in the configuration.

### Persistent volume for JDBC Drivers (optional)

If you don't create this persistent volume and related claim, leave `global.existingClaimName` empty and set `appengine.useCustomJDBCDrivers` to `false`.

The persistent volume should be shareable by pods across the whole cluster. For a single-node Kubernetes cluster, you can use HostPath to create it. For multiple nodes in a cluster, use shareable storage, such as NFS or GlusterFS, for the persistent volume. It must be passed in the values.yaml files (see the global.existingClaimName property in the configuration).

The following example shows the HostPath type of persistent volume.

```yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: jdbc-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/mnt/data"
```

The following example shows the NFS type of persistent volume.

```yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: jdbc-pv-volume
  labels:
    type: nfs
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteMany
  nfs:
    path: /tmp
    server: 172.17.0.2
```

After you create a persistent volume, you can create a persistent volume claim to bind the correct persistent volume with the selector. Or, if you are using GlusterFS with dynamic allocation, create the persistent volume claim with the correct storageClassName to allow the persistent volume to be created automatically.

The following example shows a persistent volume claim.

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: jdbc-pvc
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 2Gi
```

The mounted directory must contain a jdbc sub-directory, which in turn holds subdirectories with the required JDBC driver files. Add the following structure to the mounted directory (which in this case is called binaries):

```
/binaries
  /jdbc
    /db2
      /db2jcc4.jar
      /db2jcc_license_cu.jar
```

The /jdbc folder and its contents depend on the configuration. Copy the JDBC driver files to the mounted directory as shown in the previous example. Make sure those files have the correct access. IBM Cloud Pak for Automation products on OpenShift use an arbitrary UID to run the applications, so make sure those files have read access for root(0) group. Enter the persistent volume claim name in the `global.existingClaimName` field.

### Persistent volume for etcd data for Resource Registry (optional)

Without a persistent volume, the Resource Registry cluster might be broken during pod relocation.
If you don't need data persistence for Resource Registry, you can skip this section by setting resourceRegistry.persistence.enabled to false in the configuration. Otherwise, you must create a persistent volume.

The following example shows a persistent volume definition using NFS.

```yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: etcd-data-volume
  labels:
    type: nfs
spec:
  storageClassName: manual
  capacity:
    storage: 3Gi
  accessModes:
    - ReadWriteOnce
  nfs:
    path: /nfs/general/rrdata
    server: 172.17.0.2
```

You don't need to create a persistent volume claim for Resource Registry. Resource Registry is a StatefulSet, so it creates the persistent volume claim based on the template in the chart. See the [Kubernetes StatefulSets document](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) for more details.

Notes:

* You must give root(0) group read/write access to the mounted directories. Use the following command:

  ```
  chown -R 50001:0 <directory_path>
  chmod g+rw <directory_path>
  ```

* Each Resource Registry server uses its own persistent volume. Create persistent volumes based on the replicas (resourceRegistry.replicaCount in the configuration).

## Limitations

* The solution server image only trusts CA due to the limitation of the Node.js server. For example, if external UMS is used and signed with another root CA, you must add the root CA as trusted instead of the UMS certificate.

  * The certificate can be self-signed, or signed by a well-known CA.
  * If you're using a depth zero self-signed certificate, it must be listed as a trusted certificate.
  * If you're using a certificate signed by a self-signed CA, the self-signed CA must be in the trusted list. Using a leaf certificate in the trusted list is not supported.

* The App Engine supports only the IBM DB2 database.
* The Helm upgrade and rollback operations must use the Helm command line, not the uder interface.

## Documentation

* [Using the IBM Cloud Pak for Automation](https://www.ibm.com/support/knowledgecenter/en/SSYHZ8_19.0.x/welcome/kc_welcome_dba_distrib.html)
* [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
