# Install User Management Service 19.0.2 on Certified Kubernetes
You can use the User Management Service (UMS) option to provide users of multiple applications with a single sign-on experience.

You can also use UMS to provide a common login page for all IBM Cloud Pak for Automation web applications. If you have multiple deployments, users can have a single sign-on experience when they interact with more than one of them.

Because Cloud Pak for Automation combines several technologies and runtime servers in your virtual cloud-based environments, UMS helps you manage this complexity by consolidating aspects of user management in a single place.

## Planning your installation

| Environment size | CPU Minimum (m) | Memory Minimum (Mi) | recommended number of pods |
| ---------- | ----------- | ------------------- | -------------------------- |
| Small      | 500         | 512                 | 2                          |
| Medium     | 1000        | 1024                | 2                          |
| Large      | 2000        | 2048                | 3                          |

### Prerequisites
1. A database
1. Certificates for HTTPS and signing of identity tokens
1. Kubernetes secrets that contain the credentials to access the database, UMS system account, keystores, etc.
1. Persistent volume [optional] to host JDBC drivers, truststores, custom binaries

### Installation options
* with Tiller - which is the typical option for ICP
* without Tiller - which is the typical option for OpenShift

### Secure Deployment Guidelines
* JDBC over TLS, see "Db2 SSL Configuration" in the helm chart readme
* LDAP over TLS, see [Secure LDAP](configuration/secure-ldap.md)
* Account lockout policies and password complexity rules must be configured in LDAP for end user accounts. The built-in basic user registry for system accounts does not support such policies. User Management Service connects to your LDAP server which manages end user credentials (userids and passwords). It is expected that the LDAP bind user for connecting to LDAP has read-only permissions. Locking accounts in LDAP is therefore only possible by implementing an account lockout policy in LDAP.
Because User Management Service is just one out of many applications connecting to LDAP, locking accounts upon a number of failed login attempts has little value: attackers can just switch to another application to continue probing.
* Encrypted file system: It is recommended to host persistent volumes and database storage on encrypted file system (see "Database Requirements" in the helm chart readme)
* RBAC for operations: Installing UMS in IBM Cloud Private requires the `Administrator` role for the given namespace in order to create and assign RBAC roles. For daily operations, the `Editor` role is sufficient to scale up and down as well as viewing logs and modifying configuration. On other kubernetes platforms, it is also recommended to create a RBAC role for daily operations - avoiding `kubectl exec ...` permissions in daily operations.

## Prepare your environment
1. Download and initialize command line interfaces:
    * kubectl
    * cloudctl for ICP
    * helm for ICP
    * oc for OpenShift
2. Create a database
1. Create a namespace `kubectl create namespace`
1. Create an image pull secret `kubectl create secret docker-registry ums-pull-secret1 --docker-server=myregistry:port --docker-username=dockeruser --docker-password=dockerpassword`
1. Create a TLS certificate for UMS pod HTTPS communication `openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt` and store them in a secret `kubectl create secret tls ibm-dba-ums-tls --key=tls.key --cert=tls.crt`
1. Create a TLS certificate for signing identity tokens `openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout jwt.key -out jwt.crt` and store them in a secret `kubectl create secret tls ibm-dba-ums-jwt --key=jwt.key --cert=jwt.crt`
1. Create secrets for system account credentials, see sample [ums-secret.yaml](configuration/ums-secret.yaml)
1. Create a secret for sensitive configuration (such as LDAP bind password), see [secure LDAP](configuration/secure-ldap.md)
1. Create a persistent volume to host JDBC drivers, truststores and custom binaries, see [Db2 HADR](configuration/db2-hadr.md)
1. Load docker images into your docker registry as described in [Download PPA and load images](../README.md#step-2-download-a-product-package-from-ppa-and-load-the-images)

## Customize the installation
1. In a shell, extract the downloaded package
```bash
tar -xvf ibm-dba-ums-prod-1.0.0.tgz
```
1. Review `values.yaml` and create an environment specific `myvalues.yaml` file to override defaults where necessary and to specify values for settings without defaults. Review `README.md` inside the helm chart for more details on the individual settings. 

## Option 1: With Tiller (for ICP)
`helm install --tls -n <release-name> -f <myvalues.yaml> ibm-dba-ums-prod-1.0.0.tgz`

## Option 2: Without Tiller (for OpenShift)
```bash
rm -rf yamls ; mkdir yamls ; helm template -n cp4aums1 -f helmvalues.yaml ../../ibm-dba-ums-prod/ --output-dir yamls
kubectl apply -f ./yamls/ -R
```

## Specific k8s env
* Sample for [Openshift](platform/README-openshift.md)
* Sample for [Openshift on IBM Cloud](platform/README-ROKS.md)
* Sample for [IBM Cloud Private](platform/README-icp.md)
* Sample for [Minikube](platform/README-minikube.md)

# Verify
Use the host of this ingress to access https://<ums-host>/ums to view the login page. 

# Configuration
Configuration can be applied during installation by editing the values.yaml file. See the helm chart readme for details on the various settings. There are also samples in the [configuration folder](configuration).
