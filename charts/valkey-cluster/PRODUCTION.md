# Production Deployment Guide

This guide provides recommendations for deploying the Valkey Cluster Helm chart in production environments.

---

## Security Hardening

### 1. NetworkPolicy Configuration

**Default:** NetworkPolicy is **disabled by default** for backward compatibility.

**Production Recommendation:** Enable NetworkPolicy to restrict network access to Valkey pods.

#### Basic Configuration

```yaml
networkPolicy:
  enabled: true
  ingress:
    # Allow external client connections from specific namespaces
    allowExternal: true
    namespaceSelector:
      matchLabels:
        name: "app-namespace"  # Your application namespace
    # Or restrict to specific pods
    podSelector:
      matchLabels:
        app: "my-app"
    # Configure Prometheus namespace for metrics scraping
    prometheusNamespaceSelector:
      matchLabels:
        name: "monitoring"
```

#### Advanced Configuration (with Egress)

```yaml
networkPolicy:
  enabled: true
  ingress:
    allowExternal: true
    namespaceSelector:
      matchLabels:
        environment: "production"
  egress:
    # Enable egress rules to restrict outbound traffic
    enabled: true
```

**What NetworkPolicy Does:**
- ✅ Allows intra-cluster communication (pod-to-pod + cluster bus port 16379)
- ✅ Allows Prometheus metrics scraping (port 9121)
- ✅ Restricts client connections to authorized namespaces/pods
- ✅ (Optional) Restricts egress to DNS + intra-cluster only

---

### 2. TLS Encryption

**Status:** TLS support is **not yet implemented**. The configuration structure is defined in `values.yaml` but templates do not implement TLS.

**Current Structure:**
```yaml
tls:
  enabled: false
  port: 6380
  clusterEnabled: false
  existingSecret: ""
  authClients: "no"
```

**When TLS is Implemented (Future):**
- `tls.enabled: true` - Enable TLS for client connections
- `tls.clusterEnabled: true` - Enable TLS for cluster bus communication
- `tls.existingSecret` - Reference to secret containing `tls.crt`, `tls.key`, `ca.crt`
- `tls.authClients: "yes"` - Require client certificates (mTLS)

**Current Workaround:**
Until TLS is implemented in the chart, you can:
1. Use network-level encryption (e.g., Istio service mesh with mTLS)
2. Deploy Valkey in isolated VPC/subnet with NetworkPolicy
3. Use VPN tunnels for client connections

---

### 3. Authentication Configuration

**Production Recommendations:**

#### Option A: Explicit Password (Recommended)

```yaml
auth:
  enabled: true
  password: ""  # Leave empty, use existingSecret
  existingSecret: "valkey-password"  # Create this secret externally
  existingSecretPasswordKey: "password"
```

Create the secret:
```bash
kubectl create secret generic valkey-password \
  --from-literal=password="$(openssl rand -base64 32)" \
  --namespace valkey-cluster
```

#### Option B: Auto-Generated Password (Dev/Test Only)

```yaml
auth:
  enabled: true
  password: ""
  autoGenerate: true  # WARNING: Not recommended for production
```

**Why Not Auto-Generate in Production:**
- Password changes on every `helm template` render
- Not persisted across chart re-installations
- Requires manual retrieval from cluster after deployment

---

## High Availability Configuration

### 1. PodDisruptionBudget

**Default:** PDB is **enabled by default** with `minAvailable: 4` (for 6-node clusters).

**Recommendations:**
- 6-node cluster: Keep `minAvailable: 4` (allows 2 nodes to be disrupted)
- 3-node cluster: Set `minAvailable: 2` (allows 1 node to be disrupted)
- Large clusters (9+): Consider `maxUnavailable: 2` instead

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 4  # For 6-node cluster
  # OR use maxUnavailable
  # maxUnavailable: 2
```

---

### 2. Topology Spread Constraints

**Default:** Enabled with `whenUnsatisfiable: ScheduleAnyway` (soft constraint).

**Production Recommendation:** Use `DoNotSchedule` for strict AZ distribution.

```yaml
topologySpreadConstraints:
  enabled: true
  maxSkew: 1
  topologyKey: "topology.kubernetes.io/zone"
  whenUnsatisfiable: "DoNotSchedule"  # Strict enforcement
```

**Impact:**
- Pods will **not** be scheduled unless they can be distributed across zones
- Requires cluster to have nodes in multiple AZs
- Prevents all pods from landing in a single AZ

---

### 3. Pod Anti-Affinity

**Default:** Soft (preferred) anti-affinity with weight 100.

**Production Consideration:**
- Keep `type: "preferred"` to allow scheduling flexibility
- Only use `type: "required"` if you have sufficient nodes (>= replicaCount)

```yaml
affinity:
  podAntiAffinity:
    type: "preferred"  # Allows colocation if needed
    weight: 100
```

---

## Resource Management

### 1. Memory Configuration

**Critical:** Set `maxmemory` to ~90% of container memory limit.

```yaml
resources:
  limits:
    memory: 2Gi
    cpu: 1000m
  requests:
    memory: 256Mi
    cpu: 100m

config:
  maxmemory: "1800mb"  # 90% of 2Gi limit
  maxmemory-policy: "noeviction"  # or "allkeys-lru" for cache use case
```

**Why This Matters:**
- Prevents OOM kills by Kubernetes
- Allows overhead for Valkey metadata, connections, buffers
- `maxmemory-policy` controls eviction behavior when limit is reached

---

### 2. Persistence Configuration

**Production Recommendations:**

```yaml
persistence:
  enabled: true
  storageClass: "ebs-sc"  # Use your storage class
  size: 8Gi  # Size based on dataset + growth

config:
  # Enable both RDB and AOF for durability
  appendonly: "yes"
  appendfsync: "everysec"  # Balance durability vs performance
  save: "900 1 300 10 60 10000"
```

**RDB vs AOF Trade-offs:**
- RDB: Point-in-time snapshots, faster restarts, less disk I/O
- AOF: Better durability, larger files, slower restarts
- **Recommendation:** Use both (as configured by default)

---

## Cluster Configuration

### 1. Partial Availability

**Default:** `requireFullCoverage: "no"` (allows partial availability).

**Production Recommendation:** Keep default unless strict consistency is required.

```yaml
cluster:
  requireFullCoverage: "no"  # Recommended for production
  allowReadsWhenDown: "no"   # Prevent stale reads
```

**Impact:**
- Cluster accepts writes even if some hash slots are uncovered
- Allows partial operation during node failures
- Trade-off: Some keys may be temporarily unavailable

---

### 2. Cluster Timeouts

**Defaults:**
- `nodeTimeout: 5000` (5 seconds)
- `replicaValidityFactor: 10` (50 seconds before replica invalid for failover)

**Recommendations:**
- Keep defaults for most deployments
- Increase `nodeTimeout` for networks with higher latency
- Decrease `replicaValidityFactor` for faster failovers (more aggressive)

```yaml
cluster:
  nodeTimeout: 5000  # Increase to 10000 for high-latency networks
  replicaValidityFactor: 10  # Decrease to 5 for faster failovers
```

---

## Monitoring

### 1. ServiceMonitor Configuration

**Production Setup:**

```yaml
metrics:
  enabled: true

serviceMonitor:
  enabled: true
  labels:
    release: prometheus  # Match your Prometheus Operator release
  interval: 30s
  scrapeTimeout: 10s
  # If Prometheus is in different namespace
  namespaceSelector:
    matchNames:
      - "valkey-cluster"
```

---

### 2. Key Metrics to Monitor

Monitor these metrics via Prometheus:
- `redis_connected_clients` - Active client connections
- `redis_used_memory_bytes` - Memory usage vs `maxmemory`
- `redis_evicted_keys_total` - Key evictions (should be 0 with noeviction)
- `redis_keyspace_hits_total` / `redis_keyspace_misses_total` - Hit rate
- `redis_cluster_state` - Cluster health (should be 1 = ok)
- `redis_cluster_slots_ok` - Covered hash slots (should be 16384)

---

## Backup & Disaster Recovery

### 1. RDB Backups

**Recommendation:** Use Kubernetes CronJob to copy RDB files to S3/GCS/Azure Blob.

```yaml
# Example backup job (not included in chart)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: valkey-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: amazon/aws-cli
            command:
            - sh
            - -c
            - |
              for i in 0 1 2 3 4 5; do
                kubectl cp valkey-cluster-$i:/data/dump.rdb /tmp/dump-$i.rdb
                aws s3 cp /tmp/dump-$i.rdb s3://my-bucket/valkey/$(date +%Y%m%d)/dump-$i.rdb
              done
```

---

### 2. Point-in-Time Recovery

AOF provides better recovery guarantees:
- Set `appendfsync: everysec` (default) for balance
- Use `appendfsync: always` for maximum durability (slower)
- Monitor `redis_aof_last_rewrite_duration_sec` for rewrite performance

---

## Operational Checklist

Before deploying to production:

- [ ] **Security**
  - [ ] NetworkPolicy enabled with appropriate selectors
  - [ ] Authentication enabled with external secret
  - [ ] Non-default password set (never use auto-generate in prod)
  - [ ] TLS configured (when implemented) or network-level encryption

- [ ] **High Availability**
  - [ ] PodDisruptionBudget enabled (`minAvailable: 4` for 6-node cluster)
  - [ ] Topology spread constraints with `DoNotSchedule`
  - [ ] Pod anti-affinity configured
  - [ ] Cluster deployed across multiple AZs

- [ ] **Resource Management**
  - [ ] `maxmemory` set to ~90% of container memory limit
  - [ ] Appropriate `maxmemory-policy` for use case
  - [ ] Persistence enabled with adequate storage size
  - [ ] Node affinity to stateful nodepool

- [ ] **Monitoring**
  - [ ] Prometheus metrics enabled
  - [ ] ServiceMonitor created and discovered
  - [ ] Alerts configured (memory, evictions, cluster health)
  - [ ] Dashboards imported (Grafana)

- [ ] **Backup & Recovery**
  - [ ] Backup strategy defined (RDB + AOF)
  - [ ] Backup automation configured (CronJob to S3/GCS)
  - [ ] Recovery procedure tested
  - [ ] RTO/RPO targets met

- [ ] **Configuration Review**
  - [ ] `requireFullCoverage: "no"` for partial availability
  - [ ] Graceful shutdown hook enabled (`lifecycle.preStop.enabled: true`)
  - [ ] Startup probe configured for large datasets (if needed)
  - [ ] Resource requests/limits appropriate for workload

---

## Performance Tuning

### 1. Memory Optimization

```yaml
config:
  maxmemory: "1800mb"
  maxmemory-policy: "allkeys-lru"  # For cache use case
  # OR
  maxmemory-policy: "noeviction"   # For datastore use case
```

### 2. Persistence Optimization

```yaml
config:
  # Reduce RDB frequency for less disk I/O
  save: "3600 1 1800 10 900 100"

  # Use faster AOF fsync
  appendfsync: "no"  # WARNING: Risk of data loss on crash
  # OR keep default
  appendfsync: "everysec"  # Recommended balance
```

### 3. Cluster Optimization

```yaml
cluster:
  # More aggressive failover
  nodeTimeout: 3000
  replicaValidityFactor: 5
```

---

## Troubleshooting

### Common Issues

**Issue:** Pods not spreading across AZs
- **Solution:** Set `topologySpreadConstraints.whenUnsatisfiable: "ScheduleAnyway"` temporarily
- **Check:** Ensure nodes exist in multiple AZs (`kubectl get nodes -L topology.kubernetes.io/zone`)

**Issue:** Cluster won't form (pods stuck in Init)
- **Solution:** Check cluster init job logs (`kubectl logs -l app.kubernetes.io/component=cluster-init`)
- **Check:** Ensure all pods are reachable via headless service

**Issue:** Memory errors or OOM kills
- **Solution:** Set `config.maxmemory` to 90% of `resources.limits.memory`
- **Check:** Monitor `redis_used_memory_bytes` metric

**Issue:** Slow failovers
- **Solution:** Decrease `cluster.nodeTimeout` and `cluster.replicaValidityFactor`
- **Check:** Network latency between pods

---

## Support & Additional Resources

- [Valkey Cluster Tutorial](https://valkey.io/topics/cluster-tutorial/)
- [Valkey Configuration Documentation](https://valkey.io/topics/config/)
- [Kubernetes StatefulSet Best Practices](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Prometheus Operator ServiceMonitor](https://prometheus-operator.dev/docs/operator/design/#servicemonitor)

---

**Last Updated:** December 15, 2025
**Chart Version:** 1.0.0
