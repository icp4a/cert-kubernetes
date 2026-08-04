# IBM CloudNativePG Cluster Descriptors

This directory contains IBM CloudNativePG (CNPG) cluster manifests for CP4BA PostgreSQL deployments.

## Files

### cnpg-cluster-postgres-cp4ba-template.yaml

Template file used by the migration script (`scripts/cp4a-migrate-edb-to-cnpg.sh`) to generate the actual CNPG cluster manifest. The script automatically populates values from the existing EDB cluster configuration.

**Placeholders:**
- `<NAMESPACE>`: Target namespace
- `<INSTANCES>`: Number of PostgreSQL instances (extracted from EDB cluster)
- `<STORAGE_SIZE>`: Storage size (extracted from EDB cluster)
- `<STORAGE_CLASS>`: Storage class (extracted from EDB cluster or user-provided)
- `<MEMORY_REQUESTS>`: Memory requests (extracted from EDB cluster)
- `<CPU_REQUESTS>`: CPU requests (extracted from EDB cluster)
- `<MEMORY_LIMITS>`: Memory limits (extracted from EDB cluster)
- `<CPU_LIMITS>`: CPU limits (extracted from EDB cluster)

## Generated Manifest

When you run the migration script, it generates the actual manifest file:
- **Location**: Current working directory
- **Filename**: `cnpg-cluster-postgres-cp4ba.yaml`

Example:
```bash
./scripts/cp4a-migrate-edb-to-cnpg.sh -n cp4ba --create-cluster-only
# Generates: ./cnpg-cluster-postgres-cp4ba.yaml
```

## Manual Deployment

If you want to manually deploy a CNPG cluster without using the migration script:

1. Copy the template:
   ```bash
   cp descriptors/cnpg/cnpg-cluster-postgres-cp4ba-template.yaml my-cnpg-cluster.yaml
   ```

2. Edit the file and replace all placeholders with actual values:
   ```yaml
   metadata:
     name: postgres-cp4ba
     namespace: cp4ba  # Replace <NAMESPACE>
   spec:
     instances: 1  # Replace <INSTANCES>
     storage:
       size: 100Gi  # Replace <STORAGE_SIZE>
       storageClass: ocs-storagecluster-ceph-rbd  # Replace <STORAGE_CLASS>
     resources:
       requests:
         memory: "2Gi"  # Replace <MEMORY_REQUESTS>
         cpu: "1"  # Replace <CPU_REQUESTS>
       limits:
         memory: "4Gi"  # Replace <MEMORY_LIMITS>
         cpu: "2"  # Replace <CPU_LIMITS>
   ```

3. Apply the manifest:
   ```bash
   kubectl apply -f my-cnpg-cluster.yaml
   ```

4. Wait for the cluster to be ready:
   ```bash
   kubectl get cluster.pg.ibm.com postgres-cp4ba -n cp4ba
   kubectl get pods -n cp4ba | grep postgres-cp4ba
   ```

## Configuration Details

### PostgreSQL Version

The template uses IBM PostgreSQL 16:
```yaml
imageName: icr.io/cpopen/ibm-pg/ibm-pg-16:16.14-v28.3.1@sha256:5e27f96dea7c81b29ad1dd8e6dbb2aa021ec4b789fe21765dfcfdfdc242b9a96
```

### PostgreSQL Parameters

The template includes optimized parameters for CP4BA workloads:

**Connection Settings:**
- `max_connections: "400"` - Supports multiple CP4BA components

**Memory Settings:**
- `shared_buffers: "256MB"` - Shared memory for caching
- `effective_cache_size: "1GB"` - Query planner cache estimate
- `work_mem: "2621kB"` - Memory per query operation

**WAL Settings:**
- `min_wal_size: "1GB"` - Minimum WAL size
- `max_wal_size: "4GB"` - Maximum WAL size before checkpoint

**Parallel Query Settings:**
- `max_worker_processes: "4"` - Background worker processes
- `max_parallel_workers: "4"` - Parallel query workers

### Storage Configuration

The template supports various storage classes. Common options:

**OpenShift Container Storage (OCS):**
```yaml
storageClass: ocs-storagecluster-ceph-rbd
```

**AWS EBS:**
```yaml
storageClass: gp3
```

**Azure Disk:**
```yaml
storageClass: managed-premium
```

**IBM Cloud:**
```yaml
storageClass: ibmc-block-gold
```

### High Availability

The template includes pod anti-affinity to ensure instances run on different nodes:
```yaml
affinity:
  enablePodAntiAffinity: true
  topologyKey: kubernetes.io/hostname
```

## Scaling

### Vertical Scaling (Resources)

To adjust CPU/Memory:

1. Edit the cluster:
   ```bash
   kubectl edit cluster.pg.ibm.com postgres-cp4ba -n cp4ba
   ```

2. Update resources:
   ```yaml
   spec:
     resources:
       requests:
         memory: "4Gi"  # Increase from 2Gi
         cpu: "2"       # Increase from 1
       limits:
         memory: "8Gi"  # Increase from 4Gi
         cpu: "4"       # Increase from 2
   ```

3. Save and wait for rolling update

### Horizontal Scaling (Instances)

To add read replicas:

1. Edit the cluster:
   ```bash
   kubectl edit cluster.pg.ibm.com postgres-cp4ba -n cp4ba
   ```

2. Update instances:
   ```yaml
   spec:
     instances: 3  # Increase from 1
   ```

3. Save and wait for new pods to start

## Monitoring

### Check Cluster Status
```bash
kubectl get cluster.pg.ibm.com postgres-cp4ba -n cp4ba
```

### Check Pods
```bash
kubectl get pods -n cp4ba | grep postgres-cp4ba
```

### Check Services
```bash
kubectl get svc -n cp4ba | grep postgres-cp4ba
```

### View Logs
```bash
# Primary pod
kubectl logs postgres-cp4ba-1 -n cp4ba

# Specific container
kubectl logs postgres-cp4ba-1 -c postgres -n cp4ba
```

### Connect to Database
```bash
# Interactive psql
kubectl exec -it postgres-cp4ba-1 -n cp4ba -- psql -U postgres

# Run query
kubectl exec postgres-cp4ba-1 -n cp4ba -- psql -U postgres -c "SELECT version();"
```

## Backup and Recovery

CNPG includes built-in backup capabilities. To configure backups, add to the cluster spec:

```yaml
spec:
  backup:
    barmanObjectStore:
      destinationPath: s3://my-bucket/postgres-backups
      s3Credentials:
        accessKeyId:
          name: backup-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: backup-creds
          key: ACCESS_SECRET_KEY
      wal:
        compression: gzip
    retentionPolicy: "30d"
```

## Troubleshooting

### Cluster Not Starting

Check operator logs:
```bash
kubectl logs -l app.kubernetes.io/name=cloudnative-pg -n cp4ba
```

### Connection Issues

Check services:
```bash
kubectl get svc postgres-cp4ba-rw -n cp4ba
kubectl get svc postgres-cp4ba-ro -n cp4ba
kubectl get svc postgres-cp4ba-r -n cp4ba
```

### Storage Issues

Check PVCs:
```bash
kubectl get pvc -n cp4ba | grep postgres-cp4ba
kubectl describe pvc postgres-cp4ba-1 -n cp4ba
```

## Related Documentation

- Migration Guide: `scripts/EDB-TO-CNPG-MIGRATION-GUIDE.md`
- Quick Start: `scripts/EDB-TO-CNPG-QUICK-START.md`
- Migration Script: `scripts/cp4a-migrate-edb-to-cnpg.sh`
- Operator Catalog: `descriptors/op-olm/catalog_source.yaml`

## Support

For issues or questions:
1. Check the migration guide for common issues
2. Review CNPG operator logs
3. Consult IBM CloudNativePG documentation
4. Contact IBM Support with cluster details