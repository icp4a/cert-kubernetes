# Connecting to an LDAP Server securely
Because the user management service (UMS) is built on WebSphere Liberty, the documentation about configuring LDAP in WebSphere Liberty applies: [Configuring LDAP user registries in Liberty
](https://www.ibm.com/support/knowledgecenter/SS7K4U_liberty/com.ibm.websphere.wlp.zseries.doc/ae/twlp_sec_ldap.html). As UMS is expected to connect to an LDAP server, the ldapRegistry-3.0 feature is pre-installed.

A secure LDAP connection implies:
* Encrypted LDAPS traffic, typically on port 636
* LDAP bind user configuration with least privileges

## Bind user
Engage your LDAP administrator to provision a bind user ID that has read-only access to the parts of your LDAP server that contain your users and groups. Because this bind user ID and password is _sensitive configuration_ information, you should store it in a kubernetes secret and pass only the secret name to the UMS installation in the `myvalues.yaml` file, see [Sensitive configuration](#Sensitive-configuration).

## Encrypted connection
To ensure that an encrypted connection to LDAP is used, make sure that you specify the secure port, typically 636. For this communication to work, UMS must trust the LDAP server's signer certificate. You can provide a dedicated truststore for that purpose by placing it on a persistent volume that is mounted into UMS. Because the truststore password is _sensitive configuration_ information, you should store it in a secret, see [Sensitive configuration](#Sensitive-configuration).
Note that the default *network security policy* `ums-ldap` whitelists outbound traffic from the UMS pod to port 636 and 389. You can edit the policy to be more restrictive and control the target IP address (range). If your LDAP server is available on a network port other than 389 or 636, you MUST adapt the policy to whitelist your target port.

## High Availability
To ensure a high available LDAP connection, configure `failoverServers` as described in [Configuring LDAP user registries in Liberty
](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/twlp_sec_ldap.html).

```XML
    <failoverServers name="failoverLdapServersGroup1">
		<server host="ldapserver2.mycity.mycompany.com" port="636" />
		<server host="ldapserver3.mycity.mycompany.com" port="636" />
	</failoverServers>
```

### Create a truststore
An easy way to create a truststore is to connect to your LDAP server and download the certificate chain by using the Java keytool (in the following sample replace the host name and password with your own values):
```bash
keytool -printcert -sslserver your.ldap.host.com:636 -rfc > ldap.pem
keytool -import  -noprompt -alias ldap -keystore ldap.jks -storepass changeit -file ldap.pem
keytool -list -v -keystore ldap.jks -storepass changeit
```
This creates a truststore that contains the full certificate chain.

### Make the truststore accessible for UMS
Create a persistent volume (PV) and persistent volume claim (PVC) for UMS as described in the helm chart README.md:

1. Create a `ums-persistence.yaml` file. The following sample points to a Network File System (NFS). Replace the host `1.2.3.4` and path `/binaries` with your own values. 

```yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: ibm-dba-ums-pv
  labels:
    type: ums-binaries
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  nfs:
    server: "1.2.3.4"
    path: "/binaries"
  storageClassName: standard
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ibm-dba-ums-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  selector:
    matchLabels:
      type: ums-binaries
  storageClassName: standard
``` 

2. Create the persistent volume and persistent volume claim:
```bash
kubectl apply -f ums-persistence.yaml
```
3. Create a directory `custom-binaries` in the NFS path (`/binaries/custom-binaries` in the sample). Copy the truststore created in the previous step into that directory and make sure that the root group (0) has read access to the file.
1. In your `myvalues.yaml` file, set `useCustomBinaries` to `true` and specify the PVC name in `global.existingClaimName` to ensure that the volume is mounted into the containers
```yaml
global:
  existingClaimName: ibm-dba-ums-pvc
useCustomBinaries: true
```

## Configuration
The LDAP configuration is passed to UMS by using the `customXml` setting in the `myvalues.yaml` file.

### Sensitive configuration
Some of the LDAP configuration information is sensitive and should therefore be stored in a secret, never in a config map. You should also never pass sensitive configuration information through helm. Create a secret containing the Liberty configuration variables for all sensitive settings that you will later use in your configuration.

For additional security, you can use Liberty's securityUtil to encorde or encrypt sensitive information, e.g. to encrypt the sample password `changeit`, you can invoke the following command in any [free] non-containerized [WebSphere Liberty](https://developer.ibm.com/wasdev/downloads/) or [Open Liberty](https://openliberty.io/downloads/) install.

```bash
 wlp/bin/securityUtility encode --encoding=aes changeit
{aes}AKy63+PNE+g5rNQm4t7Y1nFps9B44emN09iA7TSPaGUx
```

Create a `ums-ldap-secret.yaml` file as shown below.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ums-ldap-secret
type: Opaque
stringData: 
  sensitiveCustomConfig: |
    <server>

        <variable name="ldap.bind.password" value="{aes}ADvQ2SZlRfLRpTS8nRSIi/I9vMFYu8JoZZfOIM3MH2lg" />
        <variable name="ldap.bind.dn" value="cn=ums,o=read-only" />
        <variable name="ldap.trustore.password" value="{aes}AKy63+PNE+g5rNQm4t7Y1nFps9B44emN09iA7TSPaGUx" />

    </server>
```

Create a secret from this file:

```bash
kubectl apply -f ums-ldap-secret.yaml
```

The name of this secret is passed to UMS in `myvalues.yaml` using the `customSecretName` parameter:
```yaml
customSecretName: ums-liberty-secret
```

To reference the value of a variable that is defined in the secret from your LDAP configuration, use the `${VARIABLE_NAME}` syntax, see [Using variables in configuration files
](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/twlp_setup_vars.html).

### LDAP configuration in UMS config map
In `myvalues.yaml`, Liberty configuration can be specified in XML format by using the `customXml` parameter. The required configuration comprises of the following elements:

* A `<keystore>` element to load the truststore
* An `<ssl>` element to refer to this truststore (and optionally restrict TLS version)
* An `<ldapRegistry>` element to specify connection information
* An optional `<federatedRegistry>` element to control the realm name or extend the attribute schema for users and groups when using the [SCIM](https://www.ibm.com/support/knowledgecenter/en/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/rwlp_sec_scim_operations.html) API. When using a federatedRegistry element, make sure to federate the existing BasicRegistry as a `participatingBaseEntry` unless your admin account is specified in LDAP, too.

The full server.xml fragment is passed in myvalues.yaml as illustrated in the following sample. Take care to use consistent indentation to avoid accidentally specifying the next YAML parameter.

```yaml
customXml: |+
    <server>
        <keyStore
              id="ldapKeyStore"
              location="/opt/ibm/wlp/usr/shared/resources/custom-binaries/ldap.jks"
              password="${ldap.trustore.password}"
              type="JKS" />

        <ssl
            id="LDAPSSLSettings"
            sslProtocol="SSL_TLSv2"
            keyStoreRef="ldapKeyStore"
            trustStoreRef="ldapKeyStore" />

        <ldapRegistry id="bp" ldapType="IBM Tivoli Directory Server"
            baseDN="o=example.com"
            host="your.ldap.host.com"
            port="636"
            sslEnabled="true"
            sslRef="LDAPSSLSettings"
            bindDN="${ldap.bind.dn}"
            bindPassword="${ldap.bind.password}" >

            <failoverServers name="failoverLdapServersGroup1">
              <server host="ldapserver2.mycity.mycompany.com" port="636" />
              <server host="ldapserver3.mycity.mycompany.com" port="636" />
            </failoverServers>

            <idsFilters  userFilter="(&amp;(objectclass=inetOrgPerson)(|(uid=%v)(mail=%v)))"
                groupFilter="(&amp;(cn=%v)(objectclass=groupOfUniqueNames))"
                groupMemberIdMap="groupOfUniqueNames:uniqueMember" />

            <attributeConfiguration>
                <attribute name="ismanager" propertyName="isManager" syntax="String" entityType="PersonAccount" />
                <attribute name="jobresponsibilities" propertyName="jobresponsibilities" syntax="String" entityType="PersonAccount" />
            </attributeConfiguration>
        </ldapRegistry>

        <federatedRepository id="vmm">
            <primaryRealm name="o=defaultWIMFileBasedRealm">
                <participatingBaseEntry name="o=BasicRegistry"/>
                <participatingBaseEntry name="o=example.com"/>
            </primaryRealm>

            <extendedProperty dataType="String" name="externalId" entityType="Group"></extendedProperty>
            <extendedProperty dataType="String" name="externalId" entityType="PersonAccount"></extendedProperty>
            <extendedProperty dataType="String" name="isManager" entityType="PersonAccount"></extendedProperty>
            <extendedProperty dataType="String" name="jobresponsibilities" entityType="PersonAccount"></extendedProperty>
        </federatedRepository>
    </server>
