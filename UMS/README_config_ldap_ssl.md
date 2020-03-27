# Configure UMS to use LDAP over SSL

## Generate a secret that contains the LDAP certificate 

### Obtain the LDAP certificate

There are several options to obtain the LDAP certificate.

1. If you have Java installed, you can obtain the certificate (including all its signers) using `keytool`:

```
keytool -printcert -sslserver $ldaphost:$ldapport -rfc > ldapcerts.pem
```

2. You can obtain the certificate (including all its signers) using OpenSSL:

```
echo | openssl s_client -showcerts -connect $ldaphost:$ldapport 2>&1 </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /c/temp/ldapcerts.pem
```


### Generate the secret 

Create a yaml configuration file, e.g. `ldap-ssl-cert.yaml` containing the certificate.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ldap-ssl-cert
type: Opaque
stringData:
  ldap-cacert.crt: |-
    -----BEGIN CERTIFICATE-----
    <include the certificate>
    -----END CERTIFICATE-----
```

Generate the secret by running
```
oc create -f ldap-ssl-cert.yaml
```

## Configure ldap_configuration parameters

In the Custom Resource, enable LDAP over SSL by setting `ldap_configuration.lc_ldap_ssl_enabled: true` and configure the 
parameter `ldap_configuration.lc_ldap_ssl_secret_name` to point to the secret containing the signer certificate of the LDAP:

```yaml
  ldap_configuration:
    ...
    lc_ldap_ssl_enabled: true
    lc_ldap_ssl_secret_name: ldap-ssl-cert

```

**Note:** During deployment, the operator will add the certificate to the truststore of UMS and enable UMS to use SSL for communication with LDAP. 

## Continue with UMS configuration
You enabled UMS to use LDAP over SSL.

Continue with the UMS configuration: [README_config.md](README_config.md)