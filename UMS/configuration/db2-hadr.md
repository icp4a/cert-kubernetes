# Database high availability
The User Management Service (UMS) requires a database. If you use Db2 as your database, you can configure high availability by setting up [HADR](https://www.ibm.com/support/knowledgecenter/SSEPGG_11.5.0/com.ibm.db2.luw.admin.ha.doc/doc/c0011267.html) for your database.
This configuration ensures that UMS automatically retrieves the necessary failover server information upon initial connection to the database. If the primary server becomes unavailable, UMS fails over to a secondary Db2 server.

To cover the possibility that the primary server is unavailable during the initial connection attempt, you can configure a list of failover servers, as described in [Configuring client reroute for applications that use DB2 databases](https://www.ibm.com/support/knowledgecenter/en/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/twlp_config_reroute_db2.html).

In `myvalues.yaml`, provide a comma-separated list of failover servers and failover ports. For example, if there are two failover servers
* server1.db2.customer.com on port 50443
* server2.db2.customer.com on port 51443
you can specify these hosts and ports in `myvalues.yaml` as follows:

```yaml
...
# UMS OAuth config
oauth:
  database:
    type: db2
    name: umsdb
    host: primary.db2.customer.com
    port: 50443
    ssl: true
    sslSecretName: db2-cert
    #driverfiles:
    alternateHosts: "server1.db2.customer.com, server2.db2.customer.com"
    alternatePorts: "50443, 51443"
  clientManagerGroup:
  jwtSecretName:

# UMS Team Server database config
teamserver:
  database:
    type: db2
    name: umsdb
    host: primary.db2.customer.com
    port: 50443
    ssl: true
    sslSecretName: db2-cert
    #driverfiles:
    alternateHosts: "server1.db2.customer.com, server2.db2.customer.com"
    alternatePorts: "50443, 51443"
```

Note that the _network security policy_ automatically whitelists outbound traffic from UMS pods to the the primary database ports. You can be more restrictive and specify the IP address [range]. If your failover servers use different ports, you MUST whitelist these explicitly by editing _network security policy_ `ums-database`.
