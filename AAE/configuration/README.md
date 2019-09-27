# App Engine platform Helm installation helper script

1. Extract the IBM Business Applicaition Studio platform Helm installation helper script from the aae-helper.tar file and copy it to a specified directory, for example, ibm-dba-aae-helper.

2. Unpack the package by running the following command:

    ```
    tar xvf aae-helper.tar
    ```

3. Update the `./pre-install/aae.yaml`file with the following settings:

#### App Engine settings
 | Parameter                              | Description                                           | Default             |
| -------------------------------------- | ----------------------------------------------------- | ---------------------------------------------------- |
| `releaseName`                          | Release Name. If you want to install with a release name other than bastudio, update this field.                                          |                                                      |
| `server.type`             | Kubernetes cluster type. OpenShift is supported.             | `openshift`    |
| `server.infrastructureNodeIP`              | Infrastructure node IP                          |                                                      |
| `server.certificateManagerIntalled`                  | Whether to use Cert Manager installation                       | `false`                                                   |
| `admin.username`                   | Administrative username, which is used by User Management Service (UMS), App Engine, and Business Automation Studio                              |                                                      |
| `admin.password`        | Administrative password         |                                             |
| `ums.hostname`    | UMS external host name                     |                                                     |
| `ums.tlsSecretName`    | Enter the UMS root CA secret name in this field                     |                                                     |
| `appEngine.hostname`    | App Engine external host name                     |                                             |
| `appEngine.db.name`              | App Engine database name                              |                                                  |
| `appEngine.db.hostname`              | App Engine database host                              |                                                 |
| `appEngine.db.port`              | App Engine database port                              |                                                 |
| `appEngine.db.username`              | App Engine database user name                       |                                                 |
| `appEngine.db.password`              | App Engine database password                       |                                                 |
| `appEngine.redis.password`              | Set this password only if you are using Redis                      |   `password`                                            |
| `resourceRegistry.hostname`              | Resource Registry external host name                       |                                                 |
| `resourceRegistry.root.password`              | Resource Registry root password                       |                                                 |
| `resourceRegistry.read.username`              | Resource Registry reader user name                       |                                                 |
| `resourceRegistry.read.password`              | Resource Registry reader password                       |                                                 |
| `resourceRegistry.write.username`              | Resource Registry writer user name                       |                                                 |
| `resourceRegistry.write.password`              | Resource Registry writer password                       |                                                 |                                       |
| `images.appEngine`              | Image name for App Engine container                         |  `solution-server:19.0.2`                                                |
| `images.dbJob`              | Image name for App Engine database job container                       |  `solution-server-helmjob-db:19.0.2`                                               |
| `images.resourceRegistry`              |  Image name for Resource Registry container                           |  `dba-etcd:19.0.2`                                               |
| `images.umsInitRegistration`              | Image name for OpenID Connect (OIDC) registration job container                       |  `dba-umsregistration-initjob:19.0.2`                                              |
| `images.tlsInitContainer`              | Image name for TLS init container                        |  `dba-keytool-initcontainer:19.0.2`                                                |
| `images.ltpaInitContainer`              | Image name for job container                    |  `dba-keytool-jobcontainer:19.0.2`                                               |
| `images.dbcompatibilityInitContainer`              | Image name for database compatibility init container                 |   `dba-dbcompatibility-initcontainer:19.0.2`                                               |
| `ImagePullPolicy`              | Pull policy for all containers                |   `Always`                                               |
| `imagePullSecrets`              | Existing Docker image secret                 |   `image-pull-secret`                                               |


4. Run the command `./pre-install/prepare-aae.sh -i ./pre-install/aae.yaml`. You'll see the following information on your screen:

```
Target folder does not exist. Creating folder
wrote ./output/aae-helper/templates/admin-secrets.yaml
wrote ./output/aae-helper/templates/certificate.yaml
wrote ./output/aae-helper/templates/route-ingress.yaml
wrote ./output/aae-helper/templates/NOTES.txt
wrote ./output/aae-helper/templates/db-script.sql
wrote ./output/aae-helper/templates/updateValues.yaml
---
# Source: aae-helper/templates/NOTES.txt
Generating admin secret- related resources in file
./aae-helper/templates/admin-secrets.yaml

Generating TLS key and certificate resources with secret in file
./aae-helper/templates/certificate.yaml

Generating route definition in file
./aae-helper/templates/route-ingress.yaml

Generating values to update in file
./aae-helper/templates/updateValues.yaml

You can apply the resources with command:
kubectl apply -f ./admin-secrets.yaml
kubectl apply -f ./certificate.yaml
oc apply -f ./route-ingress.yaml

Create the database with command:
db2 -tvf ./db-script.sql

```

5. Run the following commands to create sensitive configuration data, create TLS key and certification secrets, and set the service type.

```
 kubectl apply -f ./admin-secrets.yaml
 kubectl apply -f ./certificate.yaml
 oc apply -f ./route-ingress.yaml
```

6. Copy the database script to your dabase and run the command `db2 -tvf ./db-script.sql` on the database.
