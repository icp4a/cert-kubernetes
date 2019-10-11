# Connecting to an LDAP Server 
Because the user management service (UMS) is built on WebSphere Liberty, the documentation about configuring LDAP in WebSphere Liberty applies: [Configuring LDAP user registries in Liberty
](https://www.ibm.com/support/knowledgecenter/SS7K4U_liberty/com.ibm.websphere.wlp.zseries.doc/ae/twlp_sec_ldap.html). As UMS is expected to connect to an LDAP server, the ldapRegistry-3.0 feature is pre-installed.

## Bind user
The simple LDAP configuration assumes that LDAP allows anonymous binds and therefore skips bind user configuration.

## Network connection
The simple LDAP configuration assumes that LDAP is available over an unecrypted connection on port 389 and therefore skips using a truststore and related configuration. Note that the default *network security policy* `ums-ldap` whitelists outbound traffic from the UMS pod to port 636 and 389. You can edit the policy to be more restrictive and control the target IP address (range). If your LDAP server is available on a network port other than 389 or 636, you MUST adapt the policy to whitelist your target port.

## High Availability
To ensure a high available LDAP connection, configure `failoverServers` as described in [Configuring LDAP user registries in Liberty
](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/twlp_sec_ldap.html).

```XML
    <failoverServers name="failoverLdapServersGroup1">
		<server host="ldapserver2.mycity.mycompany.com" port="389" />
		<server host="ldapserver3.mycity.mycompany.com" port="389" />
	</failoverServers>
```
## Configuration
The LDAP configuration is passed to UMS by using the `customXml` setting in `myvalues.yaml`.

### LDAP configuration in UMS config map
In `myvalues.yaml`, Liberty configuration can be specified in XML format using the `customXml` parameter. The required configuration comprises of the following elements:

* An `<ldapRegistry>` element to specify connection information
* An optional `<federatedRegistry>` element to control the realm name or extend the attribute schema for users and groups when using the [SCIM](https://www.ibm.com/support/knowledgecenter/en/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/rwlp_sec_scim_operations.html) API. When using a federatedRegistry element, make sure to federate the existing BasicRegistry as a `participatingBaseEntry` unless your admin account is specified in LDAP, too.

The full server.xml fragment is passed in myvalues.yaml as illustrated in the following sample. Take care to use consistent indentation to avoid accidentally specifying the next YAML parameter.

```yaml
customXml: |+
    <server>
        <ldapRegistry id="bp" ldapType="IBM Tivoli Directory Server"
            baseDN="o=example.com"
            host="your.ldap.host.com"
            port="389">

            <failoverServers name="failoverLdapServersGroup1">
                <server host="ldapserver2.mycity.mycompany.com" port="389" />
                <server host="ldapserver3.mycity.mycompany.com" port="389" />
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
