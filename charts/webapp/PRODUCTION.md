# WebApp Helm Chart - Production Deployment Guide

This guide covers best practices and recommendations for deploying the WebApp Helm chart to production environments.

## Table of Contents

- [Quick Start](#quick-start)
- [High Availability](#high-availability)
- [Security](#security)
- [Resource Management](#resource-management)
- [Monitoring & Observability](#monitoring--observability)
- [Network Policies](#network-policies)
- [Database Migrations](#database-migrations)
- [Deployment Strategies](#deployment-strategies)
- [Troubleshooting](#troubleshooting)
- [Production Checklist](#production-checklist)

## Quick Start

### Minimum Production Configuration

```yaml
# values-production.yaml
replicaCount: 3

image:
  repository: myapp
  tag: "1.0.0"  # Always pin to specific version
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: registry-credentials

# High availability
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Production strategy
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0  # Zero-downtime deployments

# Resource requests (set based on your profiling)
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    memory: 1Gi  # Always set memory limit

# Health checks
health:
  startupProbe:
    httpGet:
      path: /healthz/startup
      port: http
    failureThreshold: 30
    periodSeconds: 10
  livenessProbe:
    httpGet:
      path: /healthz/live
      port: http
    initialDelaySeconds: 10
    periodSeconds: 10
    failureThreshold: 3
  readinessProbe:
    httpGet:
      path: /healthz/ready
      port: http
    initialDelaySeconds: 5
    periodSeconds: 5
    failureThreshold: 3

# Graceful shutdown
lifecycle:
  terminationGracePeriodSeconds: 60
  preStop:
    enabled: true
    sleepSeconds: 10

# Security
containerSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL

podSecurityContext:
  runAsNonRoot: true
  fsGroup: 10001

# High availability
podDisruptionBudget:
  disabled: false
  minAvailable: 2

topologySpreadConstraints:
  disabled: false
  maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule

# Monitoring
metrics:
  enabled: true
  path: /metricsz
  serviceMonitor:
    enabled: true
    interval: 30s
    labels:
      release: prometheus

# Network security
networkPolicy:
  enabled: true
  ingress:
    allowExternal: true
    namespaceSelector:
      matchLabels:
        name: ingress-nginx
  egress:
    enabled: true
```

## High Availability

### Replica Configuration

**Development**: 2 replicas (minimum for testing HA)
**Production**: 3+ replicas with HPA

```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  # Optional memory-based scaling
  # targetMemoryUtilizationPercentage: 80
```

### Pod Disruption Budget

Ensures minimum availability during voluntary disruptions (node drains, cluster upgrades):

```yaml
podDisruptionBudget:
  disabled: false
  minAvailable: 2  # At least 2 pods must remain available
  # OR use maxUnavailable
  # maxUnavailable: 1
```

### Topology Spread Constraints

Distribute pods across availability zones:

```yaml
topologySpreadConstraints:
  disabled: false
  maxSkew: 1
  topologyKey: topology.kubernetes.io/zone  # Spread across AZs
  whenUnsatisfiable: DoNotSchedule  # Strict enforcement
```

For node-level spread (same AZ):

```yaml
topologySpreadConstraints:
  topologyKey: kubernetes.io/hostname  # Spread across nodes
  whenUnsatisfiable: ScheduleAnyway  # Soft enforcement
```

### Deployment Strategy

Zero-downtime rolling updates:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1          # One extra pod during update
    maxUnavailable: 0    # Never reduce below desired count
```

For stateful applications that can't run multiple versions:

```yaml
strategy:
  type: Recreate  # Terminate all old pods before creating new ones
```

## Security

### Container Security Context

**Minimal privileges**:

```yaml
containerSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001  # Must exist in your container image
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true  # Requires writable volumes for temp files
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL
    # Only add specific capabilities if required
    # add:
    #   - NET_BIND_SERVICE  # For binding to port 80/443
```

### Image Pull Secrets

For private registries:

```yaml
imagePullSecrets:
  - name: registry-credentials
```

Create the secret:

```bash
kubectl create secret docker-registry registry-credentials \
  --docker-server=myregistry.io \
  --docker-username=myuser \
  --docker-password=mypassword \
  --namespace=production
```

### Secrets Management with Vault

Using [Bank-Vaults](https://github.com/bank-vaults/bank-vaults) webhook:

```yaml
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "https://vault.vault.svc:8200"
  vault.security.banzaicloud.io/vault-role: "webapp-production"
  vault.security.banzaicloud.io/vault-skip-verify: "false"
  vault.security.banzaicloud.io/vault-tls-secret: "vault-tls"

containerEnvironmentVariables:
  - name: DATABASE_PASSWORD
    value: vault:secret/data/production/database#password
  - name: API_KEY
    value: vault:secret/data/production/api#key

# Enable Vault Role Operator integration
innagoVaultK8sRoleOperator:
  use: true
  additionalPolicies:
    - database-dynamic-credentials
```

## Resource Management

### Sizing Strategy

1. **Profile your application** in a staging environment
2. **Set requests based on P95 usage**
3. **Set limits conservatively** (or use VPA)

### With VPA (Recommended)

Let VPA manage limits based on actual usage:

```yaml
resources:
  requests:
    cpu: 100m      # Initial guess
    memory: 128Mi  # Initial guess
  # No limits - VPA will recommend them
```

Deploy VPA in recommendation mode first:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  updatePolicy:
    updateMode: "Off"  # Recommendation only
```

After 1-2 weeks, check recommendations:

```bash
kubectl describe vpa webapp-vpa
```

### Without VPA

Set both requests and limits based on profiling:

```yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m      # 2x requests for burst
    memory: 1Gi     # Always set memory limit
```

### QoS Classes

- **Guaranteed** (requests = limits): Highest priority, predictable performance
- **Burstable** (requests < limits): Medium priority, flexible for bursts
- **BestEffort** (no requests/limits): Lowest priority, **avoid in production**

**Production recommendation**: Use **Burstable** with memory limits

### Example Sizing by Workload

```yaml
# Small app (1-10 req/sec)
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi

# Medium app (10-100 req/sec)
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    memory: 1Gi

# Large app (100+ req/sec)
resources:
  requests:
    cpu: 1000m
    memory: 1Gi
  limits:
    memory: 2Gi
```

## Monitoring & Observability

### Prometheus Metrics

Enable ServiceMonitor for Prometheus Operator:

```yaml
metrics:
  enabled: true
  path: /metricsz
  port: http
  serviceMonitor:
    enabled: true
    namespace: ""  # Defaults to release namespace
    labels:
      release: prometheus  # Match your Prometheus operator label selector
    interval: 30s
    scrapeTimeout: 10s
```

### Health Check Endpoints

Your application must expose:

- `/healthz/startup` - Startup probe (optional for slow-starting apps)
- `/healthz/live` - Liveness probe (is the app alive?)
- `/healthz/ready` - Readiness probe (can the app serve traffic?)
- `/metricsz` - Prometheus metrics (if metrics enabled)

### Startup Probe

For slow-starting applications (>30 seconds):

```yaml
health:
  startupProbe:
    httpGet:
      path: /healthz/startup
      port: http
    initialDelaySeconds: 0
    periodSeconds: 10
    failureThreshold: 30  # 300 seconds total (30 * 10s)
    successThreshold: 1
```

Startup probe prevents premature liveness probe failures during startup.

### Structured Logging

Configure your application for structured JSON logging:

```yaml
containerEnvironmentVariables:
  - name: ASPNETCORE_ENVIRONMENT
    value: Production
  - name: Logging__Console__FormatterName
    value: json
```

### Distributed Tracing

Add correlation IDs to track requests:

```yaml
podLabels:
  app.kubernetes.io/part-of: my-application
  app.kubernetes.io/version: "1.0.0"

containerEnvironmentVariables:
  - name: OTEL_SERVICE_NAME
    value: webapp
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: http://otel-collector:4317
```

## Network Policies

### Basic NetworkPolicy

Restrict ingress to specific namespaces:

```yaml
networkPolicy:
  enabled: true
  ingress:
    allowExternal: true
    namespaceSelector:
      matchLabels:
        name: ingress-nginx
    podSelector: {}
  egress:
    enabled: true
    customRules:
      - to:
        - namespaceSelector:
            matchLabels:
              name: database
        ports:
        - protocol: TCP
          port: 5432
```

### Allow Prometheus Scraping

```yaml
networkPolicy:
  enabled: true
  ingress:
    prometheusNamespaceSelector:
      matchLabels:
        name: monitoring
```

### Custom DNS Configuration

For clusters not using kube-dns:

```yaml
networkPolicy:
  egress:
    dns:
      to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
        - podSelector:
            matchLabels:
              k8s-app: coredns
```

### Egress to External APIs

```yaml
networkPolicy:
  egress:
    customRules:
      # Allow HTTPS to external APIs
      - to:
        - namespaceSelector: {}
        ports:
        - protocol: TCP
          port: 443
      # Allow specific CIDR range
      - to:
        - ipBlock:
            cidr: 10.0.0.0/8
```

## Database Migrations

### Migration Job Options

**Option 1: Helm Hook (Default)**

Runs before deployment, blocks Helm operation:

```yaml
migrationJob:
  enabled: true
  waitForItInInitContainer: false  # Uses Helm pre-install/pre-upgrade hook
  image:
    repository: myapp-migrations
    tag: "1.0.0"
  environmentVariables:
    - name: ConnectionStrings__DefaultConnection
      value: vault:secret/data/production/database#connectionString
```

**Good for**: Fast migrations (<5 minutes)
**Limitations**: Helm will timeout on long migrations

**Option 2: Init Container**

Pods wait for migration to complete:

```yaml
migrationJob:
  enabled: true
  waitForItInInitContainer: true  # Pods block on migration completion
```

**Good for**: Long-running migrations
**Limitations**: Pods won't start until migration completes

### Migration Best Practices

1. **Test migrations in staging first**
2. **Use backward-compatible migrations** (add columns before removing)
3. **Set appropriate timeouts**:

```yaml
migrationJob:
  annotations:
    helm.sh/hook-delete-policy: before-hook-creation
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
```

4. **Monitor migration logs**:

```bash
kubectl logs -l app.kubernetes.io/name=webapp-migrations -n production --tail=100 -f
```

## Deployment Strategies

### Blue-Green Deployment

Deploy new version alongside old:

1. Deploy new version with different label:

```yaml
podLabels:
  version: v2
```

2. Switch service selector when ready
3. Remove old deployment

### Canary Deployment

Gradual rollout to subset of users (requires service mesh or ingress controller):

```yaml
# Deploy canary
helm install webapp-canary ./webapp \
  -f values-production.yaml \
  --set podLabels.version=canary \
  --set autoscaling.minReplicas=1 \
  --set autoscaling.maxReplicas=2

# Monitor metrics, increase replicas gradually
# Remove old version when satisfied
```

### Rolling Update (Default)

Gradual replacement of pods:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 25%        # Max 25% extra pods during rollout
    maxUnavailable: 0    # Never reduce below desired count
```

## Troubleshooting

### Pods Not Starting

Check events:

```bash
kubectl get events -n production --sort-by='.lastTimestamp'
kubectl describe pod <pod-name> -n production
```

Common issues:
- **ImagePullBackOff**: Check imagePullSecrets
- **CrashLoopBackOff**: Check logs and liveness probe
- **Pending**: Check resources, node selectors, affinity rules

### Failed Health Checks

Check probe configuration:

```bash
kubectl logs <pod-name> -n production
kubectl describe pod <pod-name> -n production | grep -A 10 "Liveness\|Readiness"
```

Adjust probe thresholds:

```yaml
health:
  livenessProbe:
    initialDelaySeconds: 30  # Increase if app is slow to start
    failureThreshold: 5      # More tolerance for transient failures
```

### High CPU/Memory Usage

Check current usage:

```bash
kubectl top pod -n production -l app.kubernetes.io/name=webapp
```

Check VPA recommendations:

```bash
kubectl describe vpa webapp-vpa -n production
```

### Migration Job Failures

Check job status:

```bash
kubectl get jobs -n production -l app.kubernetes.io/name=webapp-migrations
kubectl logs job/webapp-migrations-<hash> -n production
```

Delete failed job and retry:

```bash
kubectl delete job webapp-migrations-<hash> -n production
helm upgrade webapp ./webapp -f values-production.yaml
```

### Network Policy Issues

Test connectivity:

```bash
# Deploy debug pod
kubectl run debug --rm -it --image=nicolaka/netshoot -n production -- /bin/bash

# Test DNS
nslookup kubernetes.default

# Test connectivity
curl http://webapp:80/healthz/live
```

Check NetworkPolicy:

```bash
kubectl get networkpolicy -n production
kubectl describe networkpolicy webapp -n production
```

## Production Checklist

### Pre-Deployment

- [ ] Image tag pinned to specific version (not `latest`)
- [ ] Image pull secrets configured
- [ ] Resource requests and limits set (based on profiling or VPA)
- [ ] Replica count ≥ 3 (or HPA with minReplicas ≥ 3)
- [ ] PodDisruptionBudget enabled
- [ ] Topology spread constraints enabled
- [ ] Security contexts configured (runAsNonRoot, read-only filesystem)
- [ ] Health check endpoints implemented and tested
- [ ] Graceful shutdown configured (terminationGracePeriodSeconds, preStop hook)
- [ ] Secrets managed via Vault or Kubernetes Secrets
- [ ] Database migrations tested in staging

### Monitoring

- [ ] ServiceMonitor created (if using Prometheus Operator)
- [ ] Metrics endpoint exposed and validated
- [ ] Structured logging enabled (JSON format)
- [ ] Distributed tracing configured (optional)
- [ ] Alerts configured for:
  - High error rate
  - High latency (P95, P99)
  - Pod restarts
  - Memory/CPU approaching limits

### Security

- [ ] NetworkPolicy enabled
- [ ] Container runs as non-root
- [ ] Read-only root filesystem (if possible)
- [ ] Capabilities dropped
- [ ] seccompProfile set to RuntimeDefault
- [ ] No secrets in environment variables (use Vault)
- [ ] Image vulnerability scanning passed

### High Availability

- [ ] Multiple replicas (≥3)
- [ ] HPA enabled with appropriate thresholds
- [ ] PodDisruptionBudget minAvailable ≥ 2
- [ ] Topology spread across zones
- [ ] Zero-downtime deployment strategy (maxUnavailable: 0)
- [ ] Graceful shutdown tested

### Post-Deployment

- [ ] Verify all pods are running: `kubectl get pods -n production`
- [ ] Check health endpoints: `kubectl port-forward svc/webapp 8080:80 -n production`
- [ ] Verify metrics collection: Check Prometheus targets
- [ ] Test application functionality
- [ ] Monitor resource usage for 24-48 hours
- [ ] Review logs for errors or warnings
- [ ] Validate alerts are firing correctly

## Example: Complete Production Values

```yaml
# values-production.yaml - Complete example
replicaCount: 3

image:
  repository: myregistry.io/myapp
  tag: "1.2.3"
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: registry-credentials

strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    memory: 1Gi

health:
  startupProbe:
    httpGet:
      path: /healthz/startup
      port: http
    failureThreshold: 30
    periodSeconds: 10
  livenessProbe:
    httpGet:
      path: /healthz/live
      port: http
    initialDelaySeconds: 10
    periodSeconds: 10
    failureThreshold: 3
  readinessProbe:
    httpGet:
      path: /healthz/ready
      port: http
    initialDelaySeconds: 5
    periodSeconds: 5
    failureThreshold: 3

lifecycle:
  terminationGracePeriodSeconds: 60
  preStop:
    enabled: true
    sleepSeconds: 10

containerSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL

podSecurityContext:
  runAsNonRoot: true
  fsGroup: 10001

podDisruptionBudget:
  disabled: false
  minAvailable: 2

topologySpreadConstraints:
  disabled: false
  maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule

metrics:
  enabled: true
  path: /metricsz
  serviceMonitor:
    enabled: true
    interval: 30s
    labels:
      release: prometheus

networkPolicy:
  enabled: true
  ingress:
    allowExternal: true
    namespaceSelector:
      matchLabels:
        name: ingress-nginx
  egress:
    enabled: true

podLabels:
  team: platform
  cost-center: engineering
  environment: production

podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "https://vault.vault.svc:8200"
  vault.security.banzaicloud.io/vault-role: "webapp-production"

containerEnvironmentVariables:
  - name: ASPNETCORE_ENVIRONMENT
    value: Production
  - name: ConnectionStrings__DefaultConnection
    value: vault:secret/data/production/database#connectionString

migrationJob:
  enabled: true
  waitForItInInitContainer: false
  image:
    repository: myregistry.io/myapp-migrations
    tag: "1.2.3"
  environmentVariables:
    - name: ConnectionStrings__DefaultConnection
      value: vault:secret/data/production/database#connectionString

innagoVaultK8sRoleOperator:
  use: true
  additionalPolicies:
    - database-dynamic-credentials
```

## Additional Resources

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [12-Factor App](https://12factor.net/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
