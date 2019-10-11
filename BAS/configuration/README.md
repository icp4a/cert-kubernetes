# Business Automation Studio platform Helm installation helper script

1. Extract the IBM Business Applicaition Studio platform Helm installation helper script from the bastudio-helper.tar file and copy it to a specified directory, for example, ibm-dba-bas-helper.

2. Unpack the package by running the following command:

    ```
    tar xvf bastudio-helper.tar
    ```

3. Update the `./pre-install/bastudio.yaml` file with the following settings:

#### Business Automation Studio settings
 | Parameter                              | Description                                           | Default             |
| -------------------------------------- | ----------------------------------------------------- | ---------------------------------------------------- |
| `releaseName`                          | Release Name. If you want to install with a release name other than bastudio, update this field.                                          |                                                      |
| `server.type`             | Kubernetes cluster type. OpenShift is supported.            | `openshift`    |
| `server.infrastructureNodeIP`              | Infrastructure node IP                          |                                                      |
| `server.certificateManagerIntalled`                  | Whether to use Cert Manager installation                            | `false`                                                   |
| `admin.username`                   | Administrative user name, which is used by User Management Service (UMS), App Engine, and Business Automation Studio                              |                                                      |
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
| `resourceRegistry.write.password`              | Resource Registry writer password                       |                                                 |
| `bastudio.hostname`    | Business Automation Studio external host name                     |                                             |
| `bastudio.db.name`              | Business Automation Studio database name                              |                                                  |
| `bastudio.db.hostname`              | Business Automation Studio database host                              |                                                 |
| `bastudio.db.port`              | Business Automation Studio database port                              |                                                 |
| `bastudio.db.username`              | Business Automation Studio database user name                       |                                                 |
| `bastudio.db.password`              | Business Automation Studio database password                       |                                                 |
| `images.bastudio`              | Image name for Business Automation Studio container                       |                                                 |
| `images.jmsContainer`              | Image name for JMS container                       |  `baw-jms-server:19.0.2`                                               |
| `images.appEngine`              | Image name for Application Engine container                         |  `solution-server:19.0.2`                                                |
| `images.dbJob`              | Image name for Application Engine database job container                       |  `solution-server-helmjob-db:19.0.2`                                               |
| `images.resourceRegistry`              |  Image name for Resource Registry container                           |  `dba-etcd:19.0.2`                                               |
| `images.umsInitRegistration`              | Image name for OpenID Connect (OIDC) registration job container                       |  `dba-umsregistration-initjob:19.0.2`                                              |
| `images.tlsInitContainer`              | Image name for TLS init container                        |  `dba-keytool-initcontainer:19.0.2`                                                |
| `images.ltpaInitContainer`              | Image name for job container                    |  `dba-keytool-jobcontainer:19.0.2`                                               |
| `images.dbcompatibilityInitContainer`              | Image name for database compatibility init container                 |   `dba-dbcompatibility-initcontainer:19.0.2`                                               |
| `ImagePullPolicy`              | Pull policy for all containers                |   `Always`                                               |
| `imagePullSecrets`              | Existing Docker image secret                 |   `image-pull-secret`                                               |


4. Run the command`./pre-install/prepare-bastudio.sh -i ./pre-install/bastudio.yaml`. You'll see the following information on your screen:

```
Target folder does not exist. Creating folder
wrote ./output/bastudio-helper/templates/admin-secrets.yaml
wrote ./output/bastudio-helper/templates/certificate.yaml
wrote ./output/bastudio-helper/templates/route-ingress.yaml
wrote ./output/bastudio-helper/templates/NOTES.txt
wrote ./output/bastudio-helper/templates/db-script.sql
wrote ./output/bastudio-helper/templates/updateValues.yaml
---
# Source: bastudio-helper/templates/NOTES.txt
Generating admin secret-related resources in file
./bastudio-helper/templates/admin-secrets.yaml

Generating TLS key and certificate resources with secret in file
./bastudio-helper/templates/certificate.yaml

Generating route definition in file
./bastudio-helper/templates/route-ingress.yaml

Generating values to update in file
./bastudio-helper/templates/updateValues.yaml

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
