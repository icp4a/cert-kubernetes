# Configure the User Management Service to delegate authentication to an OIDC Identity Provider

## Prerequisites
OIDC Identity Provider (IdP) is accessible.

## Introduction

This documentation describes the steps to configure UMS to delegate authentication to an OIDC IdP.
To configure UMS to delegate authentication to an OIDC IdP, perform the following steps:
1. Register UMS as an OIDC client with the IdP
2. Create an IdP secret
3. Configure UMS to delegate authentication


## Register UMS as OIDC client of the OIDC IdP

Follow the instructions of your identity provider to register UMS as an OIDC client.

## Create an OIDC IdP secret

Obtain the signer certificate of your OIDC IdP.

Create a configuration file for the secret. 
Specify a name for the secret, for example, ```idp-tls```.
In section ```stringData```  add the signer certificate that you obtained in the previous step as the value of the property ```tls.crt```.

```
apiVersion: v1
kind: Secret
metadata:
  name: idp-tls
type: Opaque
stringData:
  tls.crt: |+
    -----BEGIN CERTIFICATE-----
    ....
    -----END CERTIFICATE-----
```

Save the configuration file, for example, as ```idp-secret.yaml```

In the namespace where UMS will be deployed, create the secret by using the OpenShift command line interface by running
```
oc apply -f idp-secret.yaml
```


## Configure UMS to delegate authentication

### Specify the secret with the signer certificate in Custom Resource

Edit the Custom Resource.
In section ```shared_configuration.trusted_certificate_list``` add the name of the secret that you created in the previous step.
```
    trusted_certificate_list:
      - idp-tls
```

**Note:** During deployment, the operator adds the IdP signer certificate to the truststore of the User Management Service.

### Specify the OpenID Client configuration

Obtain the ```authorizationEndpointUrl```, ```tokenEndpointUrl```, ```issuerIdentifier```, ```jwkEndpointUrl``` and ```signatureAlgorithm``` of your IdP.

Edit the Custom Resource.

In the ```ums_configuration``` for the ```custom_xml``` parameter specify ```cliendId```, ```clientSecret``` and the values that you obtained in the previois step.
Specify the authFilter to redirect only URLs that point to ```/oidc/endpoint/ums/authorize```

```
    custom_xml: |
      <server>
        <openidConnectClient id="<client_id>" 
          clientId="<client_id>" 
          clientSecret="<client_secret>" 
          authorizationEndpointUrl=""
          tokenEndpointUrl=""
          issuerIdentifier="" 
          jwkEndpointUrl=""
          signatureAlgorithm="">
          <authFilter>
            <requestUrl matchType="contains" urlPattern="/oidc/endpoint/ums/authorize"></requestUrl>
          </authFilter>
        </openidConnectClient>
      </server>
```

For a detailed explanation of the parameters in the OIDC client configuration see [Configuring an OpenID Connect Client in Liberty](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/twlp_config_oidc_rp.html).

Save the Custom Resource.

**Note:** During deployment, the operator adds the OIDC client configuration to the server configuration of the User Management Service.

## Continue with UMS configuration
You configured the User Management Service to delegate authentication to an OIDC IdP.

Continue with the UMS configuration: [README_config.md](README_config.md)
