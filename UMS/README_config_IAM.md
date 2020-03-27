# Configure the User Management Service to delegate authentication to Identity and Access Manager (IAM) provided by IBM Common Services

## Prerequisites
IAM is accessible.

IAM is connected to an LDAP that will be used to authenticate users.

## Introduction
To configure UMS to delegate authentication to IAM, you must perform the following steps:
1. Register UMS as an OIDC client with IAM
2. Create IAM secrets in OpenShift
3. Configure UMS to delegate authentication


## Register UMS as OIDC client of IAM
Login to your OpenShift environment where IAM is deployed.

### Determine the OAUTH client registration secret

Determine the OAUTH2_CLIENT_REGISTRATION_SECRET by running the following command:
```
oc -n kube-system get secret platform-oidc-credentials -o yaml
```

As output you will see something like the following:

```
apiVersion: v1
data:
  OAUTH2_CLIENT_REGISTRATION_SECRET: <registration_secret>
  WLP_CLIENT_ID: <client_id>
  WLP_CLIENT_SECRET: <client_secret>
  WLP_SCOPE: <scope>
kind: Secret
metadata:
  creationTimestamp: "2019-12-18T16:02:32Z"
  labels:
    app: auth-idp
    chart: auth-idp-3.4.0
    component: auth-idp
    heritage: Tiller
    release: auth-idp
  name: platform-oidc-credentials
  namespace: kube-system
  resourceVersion: "29985"
  selfLink: /api/v1/namespaces/kube-system/secrets/platform-oidc-credentials
  uid: cccf8d27-21af-11ea-af97-0050569bd162
type: Opaque

```

Decode the value of the ```OAUTH2_CLIENT_REGISTRATION_SECRET```. You will need it later to authenticate the ```oauthadmin``` when the OIDC client is being registered.


### Generate client id and client secret
Generate a unique client id, for example, a random 32-character alphanumeric string. The client id will be the identifier of UMS.
It must be unique across all clients that IAM manages.

Generate a sufficiently random client secret. The client secret will be used by UMS to authenticate against IAM.



### Construct the client registration payload

To construct the client registration payload execute

```
oc get configmaps -n kube-system registration-json -o jsonpath='{.data.*}' > registration.json
```

Edit the file registration.json 
* replace the ```client_id``` with the id value that you generated in the previous step
* replace the ```client_secret``` with the secret value that you generated in the previous step
* Add the UMS URL to the list of ```trusted_uri_prefixes```, for example, https://<ums-host>
* Add the URL https://<ums-host>/oidcclient/redirect/<client_id> to the list of ```redirect_uris```


```
{
"token_endpoint_auth_method":"client_secret_basic",
"client_id": <client_id>,
"client_secret": <client_secret>,
"scope":"openid profile email",
"grant_types":[
   "authorization_code",
   "client_credentials",
   "password",
   "implicit",
   "refresh_token",
   "urn:ietf:params:oauth:grant-type:jwt-bearer"
],
"response_types":[
   "code",
   "token",
   "id_token token"
],
"application_type":"web",
"subject_type":"public",
"post_logout_redirect_uris":[
   "https://<ICP_PROXY_IP>:<PORT>"   ],
"preauthorized_scope":"openid profile email general",
"introspect_tokens":true,
"trusted_uri_prefixes":[
   "https://<ICP_PROXY_IP>","<ICP_ENDPOINT>:<PORT>", "https://<UMS-HOST>"    ],
"redirect_uris":[
  "https://<ICP_ENDPOINT>:<PORT>/auth/liberty/callback", "https://127.0.0.1:443/idauth/oidc/endpoint/OP", "https://<ICP_ENDPOINT>:<PORT>/oidc/endpoint/OP/authorize", "https://<UMS-HOST>:<UMS-PORT>/oidcclient/redirect/<client_id>"]
}
```

### Register the OIDC client

Run the followng command to register the OIDC client:
```
curl -i -k -X POST -u oauthadmin:<OAUTH2_CLIENT_REGISTRATION_SECRET> -H "Content-Type: application/json" --data @registration.json https://<ICP_ENDPOINT>:<PORT>/idauth/oidc/endpoint/OP/registration
```

UMS is now registered as an OIDC client with IAM.


## Create IAM secrets

### Obtain the IAM signer certificate
* Login to the OpenShift Administrator UI.
* Select the project ```kube-system```
* Navigate to Workloads > Secrets
* Select the ```icp-management-ingress-tls-secret```
* In section Data copy the contents of ```tls.crt```. 

### Create a secret that contains the IAM signer certificate

Create a configuration file for the secret. 
Specify a name for the secret, for example, ```iam-tls```.
In section ```stringData```  add the IAM signer certificate as the value of the property ```tls.crt```.

```
apiVersion: v1
kind: Secret
metadata:
  name: iam-tls
type: Opaque
stringData:
  tls.crt: |+
    -----BEGIN CERTIFICATE-----
    MIIFMDCCAxigAwIBAgIRAJP7QsFhLJkEv6a8TFmV9NwwDQYJKoZIhvcNAQELBQAw
    YzELMAkGA1UEBhMCVVMxETAPBgNVBAgMCE5ldyBZb3JrMQ8wDQYDVQQHDAZBcm1v
    bmsxGjAYBgNVBAoMEUlCTSBDbG91ZCBQcml2YXRlMRQwEgYDVQQDDAt3d3cuaWJt
    LmNvbTAeFw0xOTEyMTgxNjAyMTdaFw0yMDAzMTcxNjAyMTdaMDQxFTATBgNVBAoT
    DGNlcnQtbWFuYWdlcjEbMBkGA1UEAxMSbWFuYWdlbWVudC1pbmdyZXNzMIIBIjAN
    BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5BcGDQUxzcFIq9UhiMSo7G/BNUQX
    sUgtpbVyrrfKAp73Tg/Y+HVduok1GOkdDhDjNGikuQtXFrudehvzKzcpS/WWI9t9
    BJFxHS39X82UxxH6rRzOJIHWsnsedkFgI8rI99I1347SAYNNtYaZmne+JLMJ/RB9
    Hhy2UvON3RKiJ/pIxY7UYkmK8f+kMWHw/FbKGqCSR/0TaNvDr+vft4ANLXRF6gXF
    Ih3Ee0h2BbihjyYU1d0PSj8whquC2V0x5qiyu/dWMYlSvvqJCWZZv5XIxDbm4muI
    cbLFVR0+8eZ8sjBoRDMUSM4KUsQsT6wdd+iw8RaEGSOYWwWoJS7Rxu8kxQIDAQAB
    o4IBDDCCAQgwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDAYDVR0TAQH/BAIwADAfBgNV
    HSMEGDAWgBSKi6oWBNLWS5M/RHLSqVAdLSYepDCBwQYDVR0RBIG5MIG2ghJtYW5h
    Z2VtZW50LWluZ3Jlc3OCNmljcC1jb25zb2xlLmFwcHMuYXNoMi00MmdhLW9jcy5w
    dXJwbGUtY2hlc3RlcmZpZWxkLmNvbYIiaWNwLW1hbmFnZW1lbnQtaW5ncmVzcy5r
    dWJlLXN5c3RlbYImaWNwLW1hbmFnZW1lbnQtaW5ncmVzcy5rdWJlLXN5c3RlbS5z
    dmOCFmljcC1tYW5hZ2VtZW50LWluZ3Jlc3OHBH8AAAEwDQYJKoZIhvcNAQELBQAD
    ggIBAB3GoxrF4lcsQvuv8Fwfo7Zln3HlnE64MYBbUR+LOA7o/7vkIV7f0/t3+hQX
    3zrCoJO2OMzDK90I2Hc9/fLbOeuPQHuEJymPAuJZDFQh7wk6C2/YW3lsUi1H20r9
    64OKG+kxUvPbA7pXpKu7VbW2U0llAqXCWZSV5Xpd6C4ue4WIrAxENm7mbbUd+X1h
    0kGrWVafOu2rXC5B4Dt+pUneC0BMdMP2OMMje1Vazpm8M9WTj1xLSgUsYTuvd9mS
    Co7nzTLSEZ6muQyy+glMa2LqzIXJk313OgZz/58NZyBELOTuaxxkmDKeyxS++Moc
    iQjS9YtLyglkqUZlePU9M4tVUYHFah/SWa+kyxgqjljREug0qZ8SuY175vTWrxet
    F5yTyrzDb8ilmVCLpqGmQ0oahtqAS1PspvzeVJqsWCXlYUjEURmr25phbgYNsMRz
    5EPIXyUsZ1Amv+cJsfB9/qcmlaeePoIXIpahsmJwQFliLiYW++Ckxam7YbllwK1T
    MViwrfwd9i+5MAGp7us36msIzdH957C2jUMbvqsHxtBW3UoShkcGvTgm4O5t+aOD
    wVi5jq/I1//W/E6rRqUzEcVOzpXncUATE6umdxuv2nPDajV9Ep+/si1WiHlewotL
    TTEzzhGZiMIJoqLwHyJ6Rt/fHFg0dyA9KL4x1p+vvediodPV
    -----END CERTIFICATE-----
```

Save the configuration file, for example, as ```iam-secret.yaml```

Create the secret by running
```
oc apply -f iam-secret.yaml
```


## Configure UMS to delegate authentication

### Specify the IAM secret in the Custom Resource

Edit the Custom Resource.

In section ```shared_configuration.trusted_certificate_list``` add the name of the secret that you created in the previous step.
```
    trusted_certificate_list:
      - iam-tls
```

**Note:** During deployment, the operator adds the IAM signer certificate to the truststore of the User Management Service.

### Specify OpenID Client configuration

Navigate to ```https://<ICP_ENDPOINT>:<PORT>/idauth/oidc/endpoint/OP/.well-known/openid-configuration```.
From the response of this web site obtain the ```authorizationEndpointUrl```, ```tokenEndpointUrl```, ```issuerIdentifier```, ```jwkEndpointUrl``` and ```signatureAlgorithm```.

Edit the Custom Resource.

In the ```ums_configuration``` for the ```cusom_xml``` parameter specify ```cliendId```, ```clientSecret``` and the values that you obtained in the previous step.
Specify the authFilter to redirect only URLs that point to ```/oidc/endpoint/ums/authorize```

```
    custom_xml: |
      <server>
        <openidConnectClient id="<client_id>" 
          clientId="<client_id>" 
          clientSecret="<client_secret>" 
          authorizationEndpointUrl="https://<ICP_ENDPOINT>:<PORT>/idprovider/v1/auth/authorize" 
          tokenEndpointUrl="https://<ICP_ENDPOINT>:<PORT>/idauth/oidc/endpoint/OP/token " 
          issuerIdentifier="https://127.0.0.1:443/idauth/oidc/endpoint/OP" 
          jwkEndpointUrl="https://<ICP_ENDPOINT>:<PORT>/idauth/oidc/endpoint/OP/jwk"
          signatureAlgorithm="RS256">
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
You configured the User Management Service to delegate authentication to IAM.

Continue with the UMS configuration: [README_config.md](README_config.md)
