<!--
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2026 All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
-->
# CP4BA Install and Upgrade API Helm Chart

Helm chart for deploying the CP4BA Install and Upgrade REST API on OpenShift/Kubernetes.

## Features

- 🚀 **GitOps Ready** - Declarative configuration via values.yaml
- 🔒 **TLS/HTTPS Support** - Built-in TLS certificate management with passthrough termination
- 🔐 **HTTP Basic Authentication** - Secure API access with username/password
- 📊 **Health Checks** - Kubernetes liveness and readiness probes
- 🛡️ **Security** - Non-root user, restricted security contexts, read-only root filesystem
- 💾 **Persistent Storage** - RWX storage for logs and data persistence
- 🌐 **OpenShift Route** - Native OpenShift route support with TLS passthrough
- 🏗️ **RBAC** - Comprehensive service account and role-based access control

## Quick Start

### Prerequisites

- Kubernetes 1.19+ or OpenShift 4.10+
- Helm 3.0+
- POSIX-compliant storage class provisioner
- `oc` or `kubectl` CLI binary for RedHat 9. The container needs the CLI to execute the upgrade script.

### Required Configuration

⚠️ **IMPORTANT**: Before installation, you MUST configure the following required values:

1. **serviceAccount.operandNamespace** - Namespace where CP4BA operands run
2. **serviceAccount.operatorNamespace** - Namespace where CP4BA operators run (or "" if same as operands)
3. **route.hostname** - Route hostname (must match TLS certificate)
4. **persistence.storageClass** - Storage class name (must support ReadWriteMany access mode)
5. **auth.username** - Username for HTTP Basic Authentication only if auth.createSecret=true (default false). Not recommended for production.
6. **auth.password** - Password for HTTP Basic Authentication only if auth.createSecret=true (default false). Not recommended for production.

The chart will **fail validation** if these values are not properly configured.

### Required Secrets

Before deploying, you must create the following secrets:

#### 1. TLS Certificate Secret (Required when tls.enabled=true)

```bash
kubectl create secret generic cp4ba-installer-upgrade-tls \
  --from-file=server-cert.pem=/path/to/tls.crt \
  --from-file=server-key.pem=/path/to/tls.key \
  -n <namespace>
```

**Certificate Requirements:**
- Self-signed certificate: `server-cert.pem` contains ONLY the self-signed certificate
- CA-signed certificate: `server-cert.pem` contains the FULL CHAIN (server cert + intermediate CA(s) + root CA)
- `server-key.pem`: Always contains just the private key
- Certificate hostname must match `route.hostname`

#### 2. Authentication Secret (Optional - can be auto-created)

```bash
kubectl create secret generic cp4ba-api-auth \
  --from-literal=username=your-username \
  --from-literal=password=your-secure-password \
  -n <namespace>
```

**Note:** If `auth.createSecret=true`, the chart will create this secret automatically using values from `auth.username` and `auth.password`. For production, it's recommended to create the secret manually and set `auth.createSecret=false`.

### Installation

#### Option 1: Manual Secret Management (Production Recommended)

```bash
# Create TLS secret
kubectl create secret generic cp4ba-installer-upgrade-tls \
  --from-file=server-cert.pem=/path/to/tls.crt \
  --from-file=server-key.pem=/path/to/tls.key \
  -n <namespace>

# Create auth secret manually (more secure for production)
kubectl create secret generic cp4ba-api-auth \
  --from-literal=username=admin \
  --from-literal=password=your-secure-password \
  -n <namespace>

# Create values file with createSecret=false
cat > my-values.yaml <<EOF
serviceAccount:
  operandNamespace: "cp4ba-operand"
  operatorNamespace: ""  # Empty if same namespace
route:
  hostname: "cp4ba-api-cp4ba.apps.mycluster.example.com"
persistence:
  storageClass: "ocs-storagecluster-cephfs"  # Must support ReadWriteMany
auth:
  createSecret: false  # Secret already created manually
EOF

# Install
helm install ibm-cp4ba-api helm/cp4ba-api -f my-values.yaml -n <namespace>
```

#### Option 2: Using Example Values File (Recommended)

```bash
# Copy and customize the example values file
cp helm/cp4ba-api/values.yaml my-values.yaml

# Edit my-values.yaml and set required values:
# - serviceAccount.operandNamespace
# - serviceAccount.operatorNamespace
# - route.hostname
# - persistence.storageClass (must support ReadWriteMany)
# - auth.username and auth.password

# Create TLS secret
kubectl create secret generic cp4ba-installer-upgrade-tls \
  --from-file=server-cert.pem=/path/to/tls.crt \
  --from-file=server-key.pem=/path/to/tls.key \
  -n <namespace>

# Install with your custom values (auth secret will be auto-created)
helm install ibm-cp4ba-api helm/cp4ba-api -f my-values.yaml -n <namespace>
```

#### Option 3: Using Command Line Parameters

```bash
# Create TLS secret first
kubectl create secret generic cp4ba-installer-upgrade-tls \
  --from-file=server-cert.pem=/path/to/tls.crt \
  --from-file=server-key.pem=/path/to/tls.key \
  -n <namespace>

# Install with command line parameters (auth secret will be auto-created)
helm install ibm-cp4ba-api helm/cp4ba-api \
  --set serviceAccount.operandNamespace=cp4ba-operand \
  --set serviceAccount.operatorNamespace="" \
  --set route.hostname=cp4ba-api-cp4ba.apps.mycluster.example.com \
  --set persistence.storageClass="ocs-storagecluster-cephfs" \
  --set auth.createSecret=true \
  --set auth.username=admin \
  --set auth.password=your-secure-password \
  -n <namespace>
```



### Validation

The chart includes built-in validation that will fail with helpful error messages if required values are missing:

```bash
# Test validation (will show errors if required values are missing)
helm lint helm/cp4ba-api

# Test with your values
helm lint helm/cp4ba-api -f my-values.yaml

# Dry-run to see what will be deployed
helm install ibm-cp4ba-api helm/cp4ba-api -f my-values.yaml --dry-run --debug
```

### Upgrade

```bash
helm upgrade ibm-cp4ba-api . -f custom-values.yaml
```

### Uninstall

⚠️ **IMPORTANT**: `helm uninstall` does NOT automatically delete cluster-scoped resources (ClusterRoles, ClusterRoleBindings) or RoleBindings in other namespaces. These must be manually deleted to ensure a complete cleanup.

#### 1. Uninstall the Helm chart
```bash
helm uninstall ibm-cp4ba-api -n <namespace>
```

**What gets deleted automatically:**
- ServiceAccount (in release namespace)
- Role (in release namespace)
- RoleBinding (in release namespace)
- Deployment, Service, Route
- PVC (if managed by Helm)

**What does NOT get deleted:**
- ClusterRole resources
- ClusterRoleBinding resources
- RoleBindings in other namespaces

#### 2. Delete ClusterRoles and ClusterRoleBindings (Required)

These cluster-scoped resources must be manually deleted:

```bash
# Delete ClusterRoles
kubectl delete clusterrole ibm-cp4ba-api-cluster-scoped-role
kubectl delete clusterrole ibm-cp4ba-api-namespace-scoped-role

# Delete ClusterRoleBinding
kubectl delete clusterrolebinding ibm-cp4ba-api-cluster-scoped-binding
```

#### 3. Delete RoleBindings in other namespaces (Required)

These RoleBindings exist in various namespaces and must be manually deleted:

```bash
# Delete RoleBindings in system namespaces
kubectl delete rolebinding ibm-cp4ba-api-kubesystem-binding -n kube-system
kubectl delete rolebinding ibm-cp4ba-api-marketplace-binding -n openshift-marketplace
kubectl delete rolebinding ibm-cp4ba-api-openshiftoperators-binding -n openshift-operators

# Delete RoleBindings in CPFS namespaces
kubectl delete rolebinding ibm-cp4ba-api-certmanager-binding -n cert-manager
kubectl delete rolebinding ibm-cp4ba-api-certmanageroperator-binding -n cert-manager-operator
kubectl delete rolebinding ibm-cp4ba-api-ibmlicensing-binding -n ibm-licensing

# Delete RoleBindings in CP4BA operator namespace for Separation of duty installation
# Note: These are in DIFFERENT namespaces than where the chart is installed,
# so helm uninstall will NOT delete them automatically
kubectl delete rolebinding ibm-cp4ba-api-operator-binding -n <operator-namespace>
```

**Note:** Use `--ignore-not-found=true` flag to avoid errors if resources don't exist:
```bash
kubectl delete clusterrole ibm-cp4ba-api-cluster-scoped-role --ignore-not-found=true
```

#### 4. Delete PVCs (Optional)

If you want to remove persistent data:

```bash
kubectl delete pvc ibm-cp4ba-api-logs -n <namespace>
```

#### 5. Delete secrets (Optional)

```bash
kubectl delete secret <secret-name> -n <namespace> 
```

such as `cp4ba-installer-upgrade-tls` and `cp4ba-api-auth`

#### 6. Delete configmap (Optional)

```bash
kubectl delete configmap cp4ba-install-upgrade-mode-cm -n <namespace> 
```

## Configuration

The following table lists the configurable parameters and their default values.

### Basic Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas. Only support replica of 1 in this release | `1` |
| `image.repository` | Image repository | `icr.io/cpopen/cp4ba-install-upgrade` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.digest` | Image digest (optional) | `""` |

### Service Account & RBAC

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create service account | `true` |
| `serviceAccount.name` | Service account name | `cp4ba-api-service-account` |
| `serviceAccount.annotations` | Service account annotations | `{}` |
| `serviceAccount.operandNamespace` | **REQUIRED** - CP4BA operands namespace | `<Required>` |
| `serviceAccount.operatorNamespace` | **REQUIRED** - CP4BA operators namespace (or "" if same) | `<Required>` |
| `serviceAccount.certManagerNamespace` | Cert-manager namespace | `ibm-cert-manager` |
| `serviceAccount.certManagerOperatorNamespace` | Cert-manager operator namespace | `""` |
| `serviceAccount.marketplaceNamespace` | Marketplace namespace | `openshift-marketplace` |
| `serviceAccount.openshiftOperatorsNamespace` | OpenShift operators namespace | `openshift-operators` |
| `serviceAccount.ibmLicensingNamespace` | IBM Licensing namespace | `ibm-licensing` |
| `serviceAccount.kubeSystemNamespace` | Kubernetes system namespace | `kube-system` |

### TLS/SSL Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tls.enabled` | Enable TLS/HTTPS | `true` |
| `tls.secretName` | TLS secret name | `cp4ba-installer-upgrade-tls` |
| `tls.validationMode` | Certificate validation mode: `required`, `optional`, `none` | `required` |

**TLS Secret Requirements:**
- Secret must contain keys: `server-cert.pem` and `server-key.pem`
- Self-signed cert: `server-cert.pem` contains only the certificate
- CA-signed cert: `server-cert.pem` contains full chain (server + intermediate + root CA)
- Certificate hostname must match `route.hostname`

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.httpsPort` | HTTPS service port (when TLS enabled) | `443` |
| `service.httpsTargetPort` | HTTPS container port | `9443` |
| `service.httpPort` | HTTP service port (when TLS disabled) | `80` |
| `service.httpTargetPort` | HTTP container port | `8000` |

### Route Configuration (OpenShift)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `route.enabled` | Enable OpenShift route | `true` |
| `route.hostname` | **REQUIRED** - Route hostname (must match TLS cert) | `<Required>` |

**Recommended hostname format:** `cp4ba-api-<namespace>.apps.<cluster-domain>`

### Authentication

| Parameter | Description | Default |
|-----------|-------------|---------|
| `auth.secretName` | Authentication secret name | `cp4ba-api-auth` |
| `auth.createSecret` | Auto-create secret from username/password | `false` |
| `auth.username` | **REQUIRED** - Username for HTTP Basic Auth. Only needed when auth.createSecret is `true` | `<Required>` |
| `auth.password` | **REQUIRED** - Password for HTTP Basic Auth. Only needed when auth.createSecret is `true` | `<Required>` |

**Security Note:** For production:
1. Set `auth.createSecret=false` and create the secret manually

### Environment Variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `MAX_TASKS_IN_MEMORY` | Maximum tasks in memory | 50 |
| `TASK_CLEANUP_INTERVAL_MINUTES` | Cleanup interval | 5 |
| `SCRIPT_BASE_PATH` | Base path for scripts | /app/scripts/cert-kubernetes |
| `LOG_LEVEL` | API Logging level | INFO |
| `MAX_LOG_SIZE` | Maximum log size  | 50Mi |
| `MAX_LOG_FILES` | Maximum log files before rotation  | 5 |
| `ENABLE_UI` | Enable Swagger UI for CP4BA Install and Upgrade  | false |


### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.existingClaim` | Use existing PVC | `""` |
| `persistence.storageClass` | **REQUIRED** - Storage class (must support RWX) if `existingClaim` is not defined | `<Required>` |
| `persistence.accessMode` | Access mode | `ReadWriteMany` |
| `persistence.size` | Volume size | `10Gi` |

**Important:** Storage class must support ReadWriteMany (RWX) access mode and be POSIX-compliant.

### Ephemeral Storage

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ephemeralStorage.enabled` | Enable ephemeral storage | `true` |
| `ephemeralStorage.size` | Ephemeral storage size | `1Gi` |

### Resources

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.limits.cpu` | CPU limit | `1000m` |
| `resources.limits.memory` | Memory limit | `1Gi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |

### Health Probes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe.httpGet.path` | Liveness probe path | `/health` |
| `livenessProbe.initialDelaySeconds` | Initial delay | `20` |
| `livenessProbe.periodSeconds` | Check period | `45` |
| `livenessProbe.timeoutSeconds` | Timeout | `5` |
| `livenessProbe.failureThreshold` | Failure threshold | `3` |
| `readinessProbe.httpGet.path` | Readiness probe path | `/health` |
| `readinessProbe.initialDelaySeconds` | Initial delay | `10` |
| `readinessProbe.periodSeconds` | Check period | `60` |
| `readinessProbe.timeoutSeconds` | Timeout | `3` |
| `readinessProbe.failureThreshold` | Failure threshold | `3` |

### Security Context

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podSecurityContext.runAsNonRoot` | Run as non-root user | `true` |
| `podSecurityContext.seccompProfile.type` | Seccomp profile type | `RuntimeDefault` |
| `securityContext.capabilities.drop` | Drop capabilities | `[ALL]` |
| `securityContext.privileged` | Privileged mode | `false` |
| `securityContext.readOnlyRootFilesystem` | Read-only root filesystem | `true` |
| `securityContext.allowPrivilegeEscalation` | Allow privilege escalation | `false` |

### Node Affinity & Tolerations

| Parameter | Description | Default |
|-----------|-------------|---------|
| `affinity` | Node affinity rules | Multi-arch support (amd64, s390x, ppc64le) |
| `tolerations` | Pod tolerations | `[]` |

## Usage Examples

### Example 1: Basic DEV Deployment

```yaml
# my-values.yaml
serviceAccount:
  operandNamespace: "cp4ba-operand"
  operatorNamespace: ""  # Same namespace

route:
  hostname: "cp4ba-api-cp4ba.apps.mycluster.example.com"

persistence:
  storageClass: "ocs-storagecluster-cephfs"  # RWX storage class
  size: 10Gi

auth:
  createSecret: true # Auto-generate secret
  username: "admin"
  password: "MySecurePassword123!"

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 128Mi
```

Deploy:
```bash
# Create TLS secret
kubectl create secret generic cp4ba-installer-upgrade-tls \
  --from-file=server-cert.pem=/path/to/tls.crt \
  --from-file=server-key.pem=/path/to/tls.key \
  -n cp4ba

# Install
helm install ibm-cp4ba-api helm/cp4ba-api -f my-values.yaml -n cp4ba
```

### Example 2: Separate Operator and Operand Namespaces

```yaml
# my-values.yaml
serviceAccount:
  operandNamespace: "cp4ba-operand"
  operatorNamespace: "cp4ba-operators"  # Different namespace

route:
  hostname: "cp4ba-api-cp4ba.apps.mycluster.example.com"

persistence:
  storageClass: "rook-cephfs"
  size: 20Gi

auth:
  createSecret: false  # Create secret manually for better security

env:
  - name: LOG_LEVEL
    value: "INFO"
  - name: MAX_TASKS_IN_MEMORY
    value: "100"
```

Deploy:
```bash
# Create secrets
kubectl create secret generic cp4ba-installer-upgrade-tls \
  --from-file=server-cert.pem=/path/to/tls.crt \
  --from-file=server-key.pem=/path/to/tls.key \
  -n cp4ba

kubectl create secret generic cp4ba-api-auth \
  --from-literal=username=admin \
  --from-literal=password=SecurePassword123! \
  -n cp4ba

# Install
helm install ibm-cp4ba-api helm/cp4ba-api -f my-values.yaml -n cp4ba
```

### Example 3: Using Existing PVC

```yaml
# my-values.yaml
serviceAccount:
  operandNamespace: "cp4ba"
  operatorNamespace: ""

route:
  hostname: "cp4ba-api.apps.mycluster.example.com"

persistence:
  enabled: true
  existingClaim: "my-existing-pvc"  # Use existing PVC

auth:
  createSecret: true
  username: "cp4ba-admin"
  password: "MyPassword123!"
```

### Example 4: HTTP Mode (TLS Disabled - Not Recommended)

```yaml
# my-values-http.yaml
serviceAccount:
  operandNamespace: "cp4ba"
  operatorNamespace: ""

route:
  enabled: true  # Disable route when using HTTP

tls:
  enabled: false  # Disable TLS
  validationMode: "none"

persistence:
  storageClass: "standard"

auth:
  createSecret: true
  username: "admin"
  password: "password"

# Note: When tls.enabled=false, the deployment automatically configures:
# - livenessProbe and readinessProbe to use HTTP scheme and port 8000
# - Container port to use http (8000) instead of https (9443)
```

**Warning:** HTTP mode is not recommended for production use.

## Monitoring

### Health Checks

The chart includes built-in HTTPS health checks:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 9443
    scheme: HTTPS
  initialDelaySeconds: 20
  periodSeconds: 45
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health
    port: 9443
    scheme: HTTPS
  initialDelaySeconds: 10
  periodSeconds: 60
  timeoutSeconds: 3
  failureThreshold: 3
```

### View Logs

```bash
# View pod logs
kubectl logs -f deployment/ibm-cp4ba-api -n <namespace>

# View logs from all pods
kubectl logs -l app.kubernetes.io/name=cp4ba-api -n <namespace>

# View logs from previous instance
kubectl logs deployment/cp4ba-api --previous -n <namespace>

# Follow logs with timestamps
kubectl logs -f deployment/cp4ba-api --timestamps -n <namespace>
```

### Check Status

```bash
# Get pod status
kubectl get pods -l app.kubernetes.io/instance=ibm-cp4ba-api -n <namespace>

# Describe deployment
kubectl describe deployment cp4ba-api -n <namespace>

# Check route status (OpenShift)
oc get route cp4ba-api -n <namespace>

# Check service
kubectl get svc cp4ba-api -n <namespace>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp -n <namespace>
```

### Access the API

```bash
# Get the route URL (OpenShift)
ROUTE_URL=$(oc get route cp4ba-api -n <namespace> -o jsonpath='{.spec.host}')
echo "API URL: https://${ROUTE_URL}"

# Test the health endpoint
curl -k https://${ROUTE_URL}/health

# Test with authentication
curl -k -u admin:password https://${ROUTE_URL}/api/v1/tasks
```

## Troubleshooting

### Pod Not Starting

**Check pod status:**
```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**Common issues:**
1. **Image pull errors:**
   - Check `image.repository` and `image.digest`
   - Verify image exists in registry
   - Check image pull secrets if using private registry

2. **TLS certificate missing:**
   - Verify secret exists: `kubectl get secret cp4ba-installer-upgrade-tls -n <namespace>`
   - Check secret has correct keys: `kubectl describe secret cp4ba-installer-upgrade-tls -n <namespace>`
   - If using `tls.validationMode=required`, certificate must exist

3. **Storage issues:**
   - Verify storage class exists: `kubectl get storageclass`
   - Check PVC status: `kubectl get pvc -n <namespace>`
   - Ensure storage class supports ReadWriteMany (RWX)

4. **RBAC issues:**
   - Check service account: `kubectl get sa cp4ba-api-service-account -n <namespace>`
   - Verify roles and rolebindings: `kubectl get rolebinding -n <namespace>`
   - Check required namespace access

### TLS/Certificate Issues

**Verify TLS secret:**
```bash
# Check if secret exists
kubectl get secret cp4ba-installer-upgrade-tls -n <namespace>

# View secret details
kubectl describe secret cp4ba-installer-upgrade-tls -n <namespace>

# Check certificate content
kubectl get secret cp4ba-installer-upgrade-tls -n <namespace> -o jsonpath='{.data.server-cert\.pem}' | base64 -d | openssl x509 -text -noout
```

**Common TLS issues:**
1. Secret doesn't exist - Create it before deployment
2. Wrong secret keys - Must be `server-cert.pem` and `server-key.pem`
3. Certificate hostname mismatch - Must match `route.hostname`
4. Incomplete certificate chain - CA-signed certs need full chain

### Authentication Issues

**Verify auth secret:**
```bash
# Check if secret exists
kubectl get secret cp4ba-api-auth -n <namespace>

# View secret details (don't show password)
kubectl describe secret cp4ba-api-auth -n <namespace>
```

**Test authentication:**
```bash
# Get route URL
ROUTE_URL=$(oc get route cp4ba-api -n <namespace> -o jsonpath='{.spec.host}')

# Test with correct credentials
curl -k -u admin:password https://${ROUTE_URL}/health

# Should return 401 without credentials
curl -k https://${ROUTE_URL}/health
```

### Storage/PVC Issues

**Check PVC status:**
```bash
# List PVCs
kubectl get pvc -n <namespace>

# Describe PVC
kubectl describe pvc <pvc-name> -n <namespace>

# Check if PVC is bound
kubectl get pvc -n <namespace> | grep cp4ba-api
```

**Common storage issues:**
1. Storage class doesn't support RWX
2. No available storage
3. Storage class doesn't exist
4. Insufficient permissions

### Route/Service Issues

**Check route (OpenShift):**
```bash
# Get route details
oc get route cp4ba-api -n <namespace> -o yaml

# Check route status
oc describe route cp4ba-api -n <namespace>

# Test route connectivity
curl -k https://$(oc get route cp4ba-api -n <namespace> -o jsonpath='{.spec.host}')/health
```

**Check service:**
```bash
# Get service details
kubectl get svc cp4ba-api -n <namespace>

# Describe service
kubectl describe svc cp4ba-api -n <namespace>

# Check endpoints
kubectl get endpoints cp4ba-api -n <namespace>
```

## Security

### Security Context

The chart implements strict security contexts:

**Pod Security Context:**
```yaml
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
```

**Container Security Context:**
```yaml
securityContext:
  capabilities:
    drop:
    - ALL
  privileged: false
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

### TLS/HTTPS

- **Default:** TLS enabled with passthrough termination
- **Certificate validation modes:**
  - `required` - Production (certificates must exist)
  - `optional` - Testing (falls back to HTTP if certs missing)
  - `none` - HTTP only (not recommended)

### Authentication

- HTTP Basic Authentication required for all API endpoints
- Credentials stored in Kubernetes secret
- Can be auto-created or manually managed

### RBAC

The chart creates comprehensive RBAC resources:
- ServiceAccount with minimal required permissions
- Roles and RoleBindings for multiple namespaces:
  - Operand namespace (CP4BA workloads)
  - Operator namespace (CP4BA operators)
  - System namespaces (cert-manager, licensing, etc.)


## Upgrading

### Upgrade Process

```bash
# Check current version
helm list -n <namespace>

# Update values if needed
vim my-values.yaml

# Upgrade
helm upgrade ibm-cp4ba-api helm/cp4ba-api -f my-values.yaml -n <namespace>

# Verify upgrade
kubectl rollout status deployment/ibm-cp4ba-api -n <namespace>
```

### Rollback

```bash
# View revision history
helm history cp4ba-api -n <namespace>

# Rollback to previous version
helm rollback cp4ba-api -n <namespace>

# Rollback to specific revision
helm rollback cp4ba-api <revision> -n <namespace>
```

## Development

### Testing Locally

```bash
# Lint the chart
helm lint helm/cp4ba-api

# Test rendering templates
helm template ibm-cp4ba-api helm/cp4ba-api -f values.yaml

# Dry-run installation
helm install ibm-cp4ba-api helm/cp4ba-api -f my-values.yaml --dry-run --debug -n <namespace>

# Validate with your values
helm lint helm/cp4ba-api -f my-values.yaml
```

### Packaging

```bash
# Package the chart
helm package helm/cp4ba-api

# Generate index
helm repo index .
```

## Additional Resources

- [Cert-kubernetes](https://github.com/icp4a/cert-kubernetes/tree/26.0.0)
- [CP4BA Upgrade Documentation](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/26.0.0?topic=automation-upgrading) - Official IBM upgrade documentation
- [CP4BA Documentation](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation) - Official IBM documentation
- [Helm Documentation](https://helm.sh/docs/) - Helm best practices

