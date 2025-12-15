# Production-Readiness Review: registry-container-webhook Helm Chart

**Chart Version:** 1.0.0
**Review Date:** 2025-12-15
**Reviewer:** Claude Sonnet 4.5

## Executive Summary

The `registry-container-webhook` chart is a wrapper around the `harbor-container-webhook` dependency (v0.8.1) that provides container image repository rewriting for Kubernetes clusters. As a **mutating admission webhook**, this component operates in the critical path of pod creation and requires special attention to security, reliability, and failure modes.

**Critical Findings:**
- **13 P0 (Critical) issues** - Primarily related to webhook-specific concerns, security, and availability
- **15 P1 (High Priority) issues** - Production readiness gaps and best practices
- **8 P2 (Medium Priority) issues** - Documentation and enhanced features
- **4 P3 (Low Priority) issues** - Nice-to-haves

**Primary Concerns:**
1. No visibility into dependency's failure policy (could block all pod creation)
2. Missing resource limits (webhook pods could be OOM-killed, blocking cluster)
3. No PodDisruptionBudget (voluntary disruptions could break the cluster)
4. No health checks visibility (failed webhooks = cluster outage)
5. Minimal production configuration examples
6. No security context configuration
7. Missing observability (metrics, ServiceMonitor)

---

## P0 (Critical) - Issues That Could Cause Outages or Security Vulnerabilities

### 1. **Unknown Webhook Failure Policy**
**Impact:** If the webhook's `failurePolicy` is set to `Fail` (strict mode), any webhook unavailability will block ALL pod creation cluster-wide. This is catastrophic.

**Problem:** The chart provides no visibility or control over the dependency's `MutatingWebhookConfiguration` failure policy. Users cannot determine if the webhook will:
- Block pod creation when webhook pods are down (`failurePolicy: Fail`)
- Allow pod creation without mutation when webhook is down (`failurePolicy: Ignore`)

**Recommended Fix:**
```yaml
# In values.yaml, expose this critical setting
harbor-container-webhook:
  webhook:
    failurePolicy: Ignore  # or Fail - must be explicitly documented
```

**Documentation Required:**
```markdown
## Webhook Failure Policy

This webhook uses failurePolicy: [Fail|Ignore]

- **Fail**: Strict mode - blocks pod creation if webhook is unavailable (recommended for security-critical environments)
- **Ignore**: Best-effort mode - allows pod creation without image rewriting if webhook is down (recommended for availability)

⚠️ **WARNING**: If set to 'Fail', ensure you have configured:
- Resource requests/limits to prevent OOM kills
- PodDisruptionBudget to prevent simultaneous pod termination
- Multiple replicas for high availability
- Health checks configured properly
```

**Complexity:** Simple (documentation + values passthrough)

---

### 2. **No Resource Limits Configured**
**Impact:** Without memory limits, webhook pods can be OOM-killed by the kernel. If the webhook pod dies and `failurePolicy: Fail` is set, the entire cluster freezes - no pods can be created.

**Problem:** `values.yaml` only passes through dependency configuration. No resource limits are set or documented.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m      # Prevent CPU throttling during bursts
      memory: 256Mi  # Prevent OOM kills
```

**Rationale:**
- Admission webhooks must respond within 10s (default timeout) or pods fail to schedule
- Memory leaks or excessive memory usage → OOM kill → webhook unavailable → cluster freeze (if failurePolicy: Fail)
- CPU limits prevent webhook from being starved during high pod creation rates

**Complexity:** Simple

---

### 3. **No PodDisruptionBudget**
**Impact:** During cluster maintenance (node drains, upgrades), Kubernetes may terminate all webhook pods simultaneously, causing pod creation failures.

**Problem:** No PDB is configured to prevent voluntary disruptions from breaking the webhook.

**Recommended Fix:**
Create `templates/poddisruptionbudget.yaml`:
```yaml
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "registry-container-webhook.fullname" . }}-pdb
  labels:
    {{- include "registry-container-webhook.labels" . | nindent 4 }}
spec:
  {{- if .Values.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  {{- else }}
  maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable | default 1 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "registry-container-webhook.selectorLabels" . | nindent 6 }}
{{- end }}
```

```yaml
# values.yaml
podDisruptionBudget:
  enabled: true
  # For 2 replicas: keep 1 available during voluntary disruptions
  minAvailable: 1
  # Alternative: maxUnavailable: 1
```

**Complexity:** Simple

---

### 4. **No Replica Count Configuration**
**Impact:** If the dependency defaults to 1 replica and the webhook pod restarts, the cluster could experience pod creation failures.

**Problem:** No documented or configured replica count. High availability requires multiple replicas.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  replicaCount: 2  # Minimum for HA

  # Anti-affinity to spread across nodes
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app.kubernetes.io/name: harbor-container-webhook
            topologyKey: kubernetes.io/hostname
```

**Complexity:** Simple

---

### 5. **No Health Check Configuration Visibility**
**Impact:** Without proper health checks, Kubernetes may route webhook requests to unhealthy pods, causing pod creation timeouts (10s default).

**Problem:** No visibility into liveness/readiness probe configuration from the dependency.

**Recommended Fix:**
Document the dependency's health check configuration and expose if possible:
```yaml
# values.yaml
harbor-container-webhook:
  livenessProbe:
    httpGet:
      path: /healthz
      port: metrics
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 3
    failureThreshold: 3

  readinessProbe:
    httpGet:
      path: /readyz
      port: metrics
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3
```

**Complexity:** Moderate (requires understanding dependency's health endpoints)

---

### 6. **No TLS Certificate Management Documentation**
**Impact:** Admission webhooks REQUIRE TLS. If certificate management fails (expiration, rotation), the webhook stops working and could block pod creation.

**Problem:** No documentation on how TLS certificates are managed, rotated, or monitored. Users don't know:
- Does the dependency use cert-manager?
- Does it self-generate certificates?
- How are certificates rotated?
- What happens when certificates expire?

**Recommended Fix:**
Add to README.md:
```markdown
## TLS Certificate Management

This webhook requires TLS certificates to communicate with the Kubernetes API server.

### Certificate Provider
[Document what the dependency uses: cert-manager, self-signed, external CA]

### Certificate Rotation
[Document rotation strategy and timeline]

### Monitoring Certificate Expiration
[Provide guidance on monitoring certificate expiration]

### Troubleshooting Certificate Issues
```bash
# Check webhook configuration
kubectl get mutatingwebhookconfiguration harbor-container-webhook -o yaml

# Check certificate expiration
kubectl get secret [cert-secret-name] -n [namespace] -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

**Complexity:** Simple (documentation only)

---

### 7. **No Security Context Configuration**
**Impact:** Webhooks run with elevated privileges by default (can see all pod specs cluster-wide). Without security context restrictions, a compromised webhook pod could be used to attack the cluster.

**Problem:** No security context is configured or exposed in values.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 65534  # nobody
    fsGroup: 65534
    seccompProfile:
      type: RuntimeDefault

  containerSecurityContext:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    runAsUser: 65534
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true  # If supported by dependency
```

**Complexity:** Simple (requires verification that dependency supports these constraints)

---

### 8. **No Webhook Timeout Configuration**
**Impact:** Default webhook timeout is 10s. If the webhook is slow (network issues, CPU throttling), pods fail to create. Too short = false failures. Too long = slow pod creation.

**Problem:** No visibility or control over webhook timeout.

**Recommended Fix:**
```yaml
# values.yaml - if dependency supports it
harbor-container-webhook:
  webhook:
    timeoutSeconds: 10  # Default, adjust based on observed latency
```

Document recommended values:
```markdown
## Webhook Timeout

The webhook timeout controls how long Kubernetes waits for the webhook to respond.

- **Default**: 10 seconds
- **Recommended**: 5-10 seconds for image rewriting (low latency operation)
- **Too low**: Pods fail to create due to timeout
- **Too high**: Slow pod creation affects user experience

Monitor webhook latency via metrics and adjust accordingly.
```

**Complexity:** Simple

---

### 9. **No Namespace Selector Configuration**
**Impact:** By default, webhooks may apply to ALL namespaces including `kube-system`. If the webhook fails, critical system pods cannot be created, causing cluster instability.

**Problem:** No namespace selector is configured to exclude critical system namespaces.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  webhook:
    namespaceSelector:
      matchExpressions:
        - key: kubernetes.io/metadata.name
          operator: NotIn
          values:
            - kube-system
            - kube-public
            - kube-node-lease
            - cert-manager  # Avoid circular dependency if using cert-manager
```

**Complexity:** Simple

---

### 10. **No Object Selector Configuration**
**Impact:** Webhook may process ALL pods, including completed Jobs, static pods, or pods that should not have image rewriting applied.

**Problem:** No object selector to filter which pods should be mutated.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  webhook:
    objectSelector:
      matchExpressions:
        # Example: only mutate pods with specific label
        - key: registry-rewrite
          operator: NotIn
          values:
            - "false"
```

**Complexity:** Simple

---

### 11. **Missing Fail-Fast Validation**
**Impact:** Invalid configuration (e.g., replacement `REPO` not substituted) is only discovered at runtime when pods fail to create.

**Problem:** The default values contain placeholder `REPO` strings that will cause image pull failures if not replaced.

**Recommended Fix:**
Add validation to `templates/NOTES.txt`:
```yaml
{{- $invalidConfig := false }}
{{- range .Values.harbor-container-webhook.rules }}
  {{- if contains "REPO" .replace }}
    {{- $invalidConfig = true }}
  {{- end }}
{{- end }}

{{- if $invalidConfig }}
{{- fail "\n\nERROR: Invalid configuration detected!\n\nThe 'replace' values contain placeholder 'REPO' strings.\nYou must replace 'REPO' with your actual container registry URL.\n\nExample:\n  harbor-container-webhook:\n    rules:\n      - name: 'docker.io rewrite rule'\n        matches:\n          - '^docker.io'\n        replace: 'registry.example.com/dockerhub'\n\nSee values.yaml for all rules that need updating.\n" }}
{{- end }}
```

**Complexity:** Simple

---

### 12. **No Monitoring/Alerting Guidance**
**Impact:** Operators cannot detect webhook failures, certificate expiration, high latency, or error rates. Issues are only discovered when users report pod creation failures.

**Problem:** No ServiceMonitor, no metrics documentation, no alerting guidance.

**Recommended Fix:**
Create `templates/servicemonitor.yaml`:
```yaml
{{- if and .Values.metrics.enabled .Values.metrics.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "registry-container-webhook.fullname" . }}
  {{- if .Values.metrics.serviceMonitor.namespace }}
  namespace: {{ .Values.metrics.serviceMonitor.namespace }}
  {{- else }}
  namespace: {{ .Release.Namespace }}
  {{- end }}
  labels:
    {{- include "registry-container-webhook.labels" . | nindent 4 }}
    {{- with .Values.metrics.serviceMonitor.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      {{- include "registry-container-webhook.selectorLabels" . | nindent 6 }}
  endpoints:
    - port: metrics
      path: /metrics
      interval: {{ .Values.metrics.serviceMonitor.interval | default "30s" }}
      scrapeTimeout: {{ .Values.metrics.serviceMonitor.scrapeTimeout | default "10s" }}
{{- end }}
```

```yaml
# values.yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: false
    namespace: ""
    labels:
      release: prometheus
    interval: 30s
    scrapeTimeout: 10s
```

Add alerting guidance to README:
```markdown
## Monitoring & Alerting

### Key Metrics to Monitor

1. **Webhook Availability**: Pod readiness status
2. **Webhook Latency**: p50, p95, p99 response times
3. **Webhook Errors**: HTTP error rate (4xx, 5xx)
4. **Certificate Expiration**: Days until TLS cert expires

### Recommended Alerts

```yaml
# PrometheusRule example
- alert: WebhookHighErrorRate
  expr: rate(webhook_errors_total[5m]) > 0.1
  annotations:
    summary: "Container webhook error rate above 10%"

- alert: WebhookHighLatency
  expr: histogram_quantile(0.95, webhook_duration_seconds) > 2
  annotations:
    summary: "Container webhook p95 latency above 2s"

- alert: WebhookCertExpiringSoon
  expr: (cert_expiration_timestamp - time()) / 86400 < 14
  annotations:
    summary: "Webhook TLS certificate expires in <14 days"
```
```

**Complexity:** Moderate

---

### 13. **No NetworkPolicy**
**Impact:** Webhook pods can communicate with any service in the cluster. If compromised, they could be used to attack internal services.

**Problem:** No NetworkPolicy is configured to restrict webhook pod communication.

**Recommended Fix:**
Create `templates/networkpolicy.yaml`:
```yaml
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "registry-container-webhook.fullname" . }}
  labels:
    {{- include "registry-container-webhook.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "registry-container-webhook.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow Kubernetes API server to reach webhook
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: TCP
          port: 9443  # Webhook HTTPS port (adjust if needed)
    {{- if .Values.metrics.enabled }}
    # Allow Prometheus to scrape metrics
    - from:
        {{- if .Values.networkPolicy.prometheusNamespaceSelector }}
        - namespaceSelector:
            {{- toYaml .Values.networkPolicy.prometheusNamespaceSelector | nindent 12 }}
        {{- else }}
        - podSelector: {}
        {{- end }}
      ports:
        - protocol: TCP
          port: 8080  # Metrics port (adjust if needed)
    {{- end }}
  egress:
    # Allow DNS resolution
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
    # Allow connection to Kubernetes API server
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: default
      ports:
        - protocol: TCP
          port: 443
    # Allow upstream image registry checks (if checkUpstream: true)
    {{- if .Values.networkPolicy.allowUpstreamChecks }}
    - to:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 443
    {{- end }}
{{- end }}
```

```yaml
# values.yaml
networkPolicy:
  enabled: false
  prometheusNamespaceSelector: {}
  allowUpstreamChecks: false
```

**Complexity:** Moderate

---

## P1 (High Priority) - Production Readiness Gaps

### 14. **No Graceful Shutdown Configuration**
**Impact:** When webhook pods are terminated, in-flight webhook requests may fail, causing pod creation failures.

**Problem:** No lifecycle hooks configured for graceful shutdown.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  lifecycle:
    preStop:
      exec:
        command:
          - /bin/sh
          - -c
          - sleep 5  # Allow time for kube-apiserver to stop sending requests

  terminationGracePeriodSeconds: 30
```

**Complexity:** Simple

---

### 15. **No Topology Spread Constraints**
**Impact:** Multiple webhook replicas may be scheduled on the same node. If that node fails, all replicas are lost, causing webhook unavailability.

**Problem:** No topology spread constraints to distribute replicas across nodes/zones.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: harbor-container-webhook
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: harbor-container-webhook
```

**Complexity:** Simple

---

### 16. **Placeholder Configuration in Production Values**
**Impact:** Users may deploy with placeholder `REPO` values, causing image pull failures for all pods in the cluster.

**Problem:** Default `values.yaml` contains non-functional placeholders:
```yaml
replace: 'REPO/dockerhub'  # Invalid!
```

**Recommended Fix:**
Option 1: Use commented examples with fail-fast validation (see P0 #11)
```yaml
# values.yaml
harbor-container-webhook:
  rules:
    # REQUIRED: Uncomment and configure at least one rule
    # - name: 'docker.io rewrite rule'
    #   matches:
    #     - '^docker.io'
    #   replace: 'registry.example.com/dockerhub'
    #   checkUpstream: false
```

Option 2: Provide environment-specific overlays:
```yaml
# values.yaml (disabled by default)
harbor-container-webhook:
  rules: []

# values-production.yaml (example)
harbor-container-webhook:
  rules:
    - name: 'docker.io rewrite rule'
      matches:
        - '^docker.io'
      replace: '123456789.dkr.ecr.us-east-1.amazonaws.com/dockerhub'
      checkUpstream: false
```

**Complexity:** Simple

---

### 17. **No HPA Configuration**
**Impact:** During high pod creation rates (cluster autoscaling, mass deployments), webhook pods may be overwhelmed, causing timeouts.

**Problem:** No HorizontalPodAutoscaler is configured or documented.

**Recommended Fix:**
Create `templates/hpa.yaml`:
```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "registry-container-webhook.fullname" . }}
  labels:
    {{- include "registry-container-webhook.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "registry-container-webhook.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
```

```yaml
# values.yaml
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

**Note:** HPA should only be enabled if PDB is configured to maintain minimum availability.

**Complexity:** Simple

---

### 18. **No Node Selector / Tolerations Configuration**
**Impact:** Webhook pods may be scheduled on nodes that are not suitable (e.g., spot instances, nodes without guaranteed availability).

**Problem:** No node selector or tolerations are configured or exposed.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  nodeSelector:
    # Example: dedicated node pool for critical infrastructure
    # node.kubernetes.io/role: infrastructure

  tolerations: []
  # Example: avoid spot instances
  # - key: "workload-type"
  #   operator: "Equal"
  #   value: "spot"
  #   effect: "NoSchedule"
```

**Complexity:** Simple

---

### 19. **No Priority Class Configuration**
**Impact:** During resource contention, webhook pods may be evicted by kubelet, causing cluster-wide pod creation failures.

**Problem:** No priorityClassName is set to protect webhook pods from eviction.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  priorityClassName: system-cluster-critical  # or create custom PriorityClass
```

**Important:** Only use `system-cluster-critical` if truly necessary. Consider creating a custom PriorityClass:
```yaml
# templates/priorityclass.yaml (optional)
{{- if .Values.priorityClass.create }}
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: {{ include "registry-container-webhook.fullname" . }}-priority
value: {{ .Values.priorityClass.value }}
globalDefault: false
description: "Priority class for registry container webhook"
{{- end }}
```

**Complexity:** Simple

---

### 20. **No ConfigMap Checksum Annotation**
**Impact:** When rewriting rules change, webhook pods are not automatically restarted, causing inconsistent behavior (some pods use old rules, some use new).

**Problem:** No ConfigMap checksum annotation to trigger rolling restarts.

**Recommended Fix:**
This depends on the dependency's Deployment template. If you have control over it via values:
```yaml
# If dependency supports pod annotations
harbor-container-webhook:
  podAnnotations:
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

If not, document manual restart requirement:
```markdown
## Updating Rewrite Rules

After updating rewrite rules in values.yaml, you must manually restart webhook pods:

```bash
helm upgrade registry-container-webhook . -f values.yaml
kubectl rollout restart deployment -l app.kubernetes.io/name=harbor-container-webhook
```
```

**Complexity:** Simple (if supported by dependency)

---

### 21. **No Readiness Gate for Webhook Registration**
**Impact:** Webhook pods may be marked ready before the MutatingWebhookConfiguration is registered, causing a race condition.

**Problem:** No coordination between pod readiness and webhook registration.

**Recommended Fix:**
This is typically handled by the dependency. Document the startup sequence and any race conditions:
```markdown
## Deployment Order

1. Deploy chart: `helm install registry-container-webhook ...`
2. Wait for webhook pods to be Ready: `kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=harbor-container-webhook --timeout=60s`
3. Verify webhook configuration: `kubectl get mutatingwebhookconfiguration harbor-container-webhook`
4. Test with a sample pod to ensure mutation is working

**Note:** During initial installation, there may be a brief period where the webhook configuration is registered but pods are not ready. This is normal and self-corrects within 30-60 seconds.
```

**Complexity:** Simple (documentation)

---

### 22. **No Version Pinning in dependency**
**Impact:** Chart dependency on `0.8.1` is pinned, but users updating the chart may unexpectedly get breaking changes in the dependency.

**Problem:** While the current dependency version is pinned, there's no documentation about version compatibility or upgrade paths.

**Recommended Fix:**
Add to README.md:
```markdown
## Dependency Management

This chart depends on `harbor-container-webhook` version `0.8.1`.

### Upgrading Dependency Version

Before upgrading the dependency version:

1. Review [harbor-container-webhook changelog](https://github.com/indeed/harbor-container-webhook/releases)
2. Test in a non-production cluster
3. Verify backward compatibility with your rewrite rules
4. Update `Chart.lock` after modifying `Chart.yaml`

```bash
# Update dependency version
helm dependency update

# Test upgrade in staging
helm upgrade --install registry-container-webhook . --dry-run --debug
```

### Current Version Compatibility
- `harbor-container-webhook 0.8.1`: Kubernetes 1.24+
- Tested on: [list tested K8s versions]
```

**Complexity:** Simple (documentation)

---

### 23. **No Labels for Monitoring/Alerting**
**Impact:** Metrics and logs from webhook pods cannot be easily filtered or aggregated.

**Problem:** No standardized labels for environment, team, or component.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  podLabels:
    app.kubernetes.io/component: admission-webhook
    app.kubernetes.io/part-of: cluster-infrastructure

commonLabels:
  # Add to all resources
  app.kubernetes.io/managed-by: helm
  helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
```

**Complexity:** Simple

---

### 24. **No Liveness Probe Configured**
**Impact:** If webhook pods hang (deadlock, network issue), Kubernetes won't restart them, causing webhook requests to timeout.

**Problem:** No visibility into whether liveness probes are configured in the dependency.

**Recommended Fix:**
Expose liveness probe configuration (see P0 #5).

**Complexity:** Simple

---

### 25. **No Startup Probe for Slow Starts**
**Impact:** If webhook pods are slow to start (pulling images, initializing), liveness probe may kill them prematurely.

**Problem:** No startup probe to protect slow-starting pods.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  startupProbe:
    httpGet:
      path: /healthz
      port: metrics
    initialDelaySeconds: 0
    periodSeconds: 5
    failureThreshold: 30  # 150s total startup time allowed
```

**Complexity:** Simple

---

### 26. **No Documentation of checkUpstream Behavior**
**Impact:** Users may not understand that `checkUpstream: true` adds latency and external dependencies to pod creation.

**Problem:** The `checkUpstream` flag is not documented.

**Recommended Fix:**
Add to README.md:
```markdown
## Configuration Options

### checkUpstream

Controls whether the webhook verifies that the target image exists in the upstream registry before rewriting.

```yaml
checkUpstream: false  # Default - faster, but may rewrite to non-existent images
checkUpstream: true   # Validate upstream - slower, safer
```

**Recommendation**: Use `false` in production for performance. Use `true` only if:
- You need validation that images exist before rewriting
- You can tolerate additional latency (adds network call to upstream registry)
- Your network policy allows webhook pods to reach external registries
```

**Complexity:** Simple (documentation)

---

### 27. **No Resource Requests Configured**
**Impact:** Without resource requests, webhook pods have no guaranteed resources and may be scheduled on overloaded nodes, causing high latency.

**Problem:** No resource requests are configured (see P0 #2 for limits).

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  resources:
    requests:
      cpu: 100m      # Guaranteed CPU
      memory: 128Mi  # Guaranteed memory
    limits:
      cpu: 500m
      memory: 256Mi
```

**Complexity:** Simple

---

### 28. **No Documentation of Metrics**
**Impact:** Operators cannot monitor webhook performance without knowing which metrics are available.

**Problem:** No documentation of available metrics.

**Recommended Fix:**
Add to README.md:
```markdown
## Available Metrics

The webhook exposes Prometheus metrics on port `8080` (adjust if different) at `/metrics`.

### Key Metrics

- `webhook_requests_total`: Total webhook requests
- `webhook_request_duration_seconds`: Request duration histogram
- `webhook_errors_total`: Total webhook errors
- `webhook_mutations_total`: Total successful mutations

### Viewing Metrics

```bash
kubectl port-forward svc/harbor-container-webhook 8080:8080
curl http://localhost:8080/metrics
```
```

**Complexity:** Simple (documentation, requires investigation of dependency's metrics)

---

## P2 (Medium Priority) - Documentation & Enhanced Features

### 29. **Insufficient README Documentation**
**Impact:** Users struggle to configure the chart correctly, leading to misconfiguration and support burden.

**Problem:** Current README only shows generated values table, no usage examples or troubleshooting.

**Recommended Fix:**
Expand README.md with:
- Prerequisites (cert-manager, Prometheus Operator if using ServiceMonitor)
- Installation guide with examples
- Configuration examples for common scenarios (ECR, Harbor, GCR rewriting)
- Upgrade guide
- Troubleshooting section
- Architecture diagram showing webhook flow

**Example sections:**
```markdown
## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- cert-manager 1.0+ (for TLS certificate management)
- Prometheus Operator (optional, for ServiceMonitor)

## Installation

### Basic Installation (Development)

```bash
helm install registry-container-webhook . \
  --set harbor-container-webhook.rules[0].replace='registry.local/dockerhub'
```

### Production Installation (AWS ECR Example)

```bash
helm install registry-container-webhook . \
  -f values-production.yaml \
  --set harbor-container-webhook.replicaCount=3 \
  --set harbor-container-webhook.resources.requests.cpu=200m \
  --set harbor-container-webhook.resources.limits.memory=512Mi
```

## Common Configuration Scenarios

### AWS ECR Registry
[See value-overrides-example.yaml]

### Harbor Registry
```yaml
harbor-container-webhook:
  rules:
    - name: 'docker.io → Harbor proxy'
      matches:
        - '^docker.io'
      replace: 'harbor.example.com/dockerhub-proxy'
      checkUpstream: false
```

### GCP Artifact Registry
[...]

## Troubleshooting

### Pods fail to create with "webhook timeout"
[...]

### Images not being rewritten
[...]

### Certificate errors
[...]
```

**Complexity:** Moderate (writing comprehensive docs)

---

### 30. **No NOTES.txt Output**
**Impact:** After installation, users receive no guidance on verification or next steps.

**Problem:** `templates/NOTES.txt` is empty.

**Recommended Fix:**
```yaml
# templates/NOTES.txt
{{- $invalidConfig := false }}
{{- range .Values.harbor-container-webhook.rules }}
  {{- if contains "REPO" .replace }}
    {{- $invalidConfig = true }}
  {{- end }}
{{- end }}

{{- if $invalidConfig }}

⚠️  WARNING: Configuration contains placeholder values!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Your rewrite rules contain 'REPO' placeholders.
Pods will FAIL to create until you configure actual registry URLs.

Update your values and run:
  helm upgrade {{ .Release.Name }} registry-container-webhook

{{- else }}

✓ registry-container-webhook installed successfully!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Webhook Name: {{ include "registry-container-webhook.fullname" . }}
Namespace:    {{ .Release.Namespace }}

Active Rewrite Rules:
{{- range .Values.harbor-container-webhook.rules }}
  • {{ .name }}
    {{ index .matches 0 }} → {{ .replace }}
{{- end }}

Next Steps:

1. Verify webhook is running:
   kubectl get pods -l app.kubernetes.io/name=harbor-container-webhook -n {{ .Release.Namespace }}

2. Check webhook configuration:
   kubectl get mutatingwebhookconfiguration harbor-container-webhook

3. Test with a sample pod:
   kubectl run test-nginx --image=nginx --dry-run=server -o yaml

4. Monitor webhook logs:
   kubectl logs -l app.kubernetes.io/name=harbor-container-webhook -n {{ .Release.Namespace }} -f

{{- if .Values.metrics.serviceMonitor.enabled }}

5. View metrics (Prometheus):
   kubectl port-forward svc/harbor-container-webhook 8080:8080 -n {{ .Release.Namespace }}
   curl http://localhost:8080/metrics
{{- end }}

For more information, see: README.md

{{- end }}
```

**Complexity:** Simple

---

### 31. **No value-overrides-example.yaml for Multiple Environments**
**Impact:** Users must manually create environment-specific configurations.

**Problem:** Only one example file exists, not comprehensive.

**Recommended Fix:**
Create additional examples:
- `examples/values-dev.yaml`
- `examples/values-staging.yaml`
- `examples/values-production.yaml`
- `examples/values-aws-ecr.yaml`
- `examples/values-gcp-artifact-registry.yaml`
- `examples/values-harbor.yaml`

**Complexity:** Simple

---

### 32. **No Tests**
**Impact:** Chart changes cannot be validated automatically. Breaking changes may be introduced.

**Problem:** No `templates/tests/` directory with connection tests.

**Recommended Fix:**
Create `templates/tests/test-webhook-response.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "registry-container-webhook.fullname" . }}-test"
  labels:
    {{- include "registry-container-webhook.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  containers:
    - name: test
      image: curlimages/curl:latest
      command:
        - sh
        - -c
        - |
          # Test that webhook is reachable (if metrics endpoint is public)
          # Adjust based on actual service exposure
          echo "Webhook test: Check that service exists"
          nslookup harbor-container-webhook.{{ .Release.Namespace }}.svc.cluster.local
  restartPolicy: Never
```

Run with: `helm test registry-container-webhook`

**Complexity:** Moderate

---

### 33. **No ArgoCD Support**
**Impact:** Users deploying via ArgoCD may encounter sync issues or slow rollouts.

**Problem:** No ArgoCD-specific annotations or configuration.

**Recommended Fix:**
Add ArgoCD-friendly features:
```yaml
# values.yaml
argocd:
  # Enable ArgoCD sync waves
  syncWave: "-1"  # Deploy webhook before applications

  # Enable ArgoCD health checks
  healthCheck:
    enabled: true
```

Add to deployment annotations:
```yaml
# In dependency configuration, if supported
harbor-container-webhook:
  deploymentAnnotations:
    argocd.argoproj.io/sync-wave: "-1"  # Deploy early
```

**Complexity:** Simple

---

### 34. **No Image Pull Secret Documentation**
**Impact:** If webhook container image is in a private registry, users don't know how to configure pull secrets.

**Problem:** No documentation or configuration for imagePullSecrets.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  imagePullSecrets:
    - name: registry-credentials
```

Document in README:
```markdown
## Using Private Container Registries

If the webhook image is in a private registry:

1. Create image pull secret:
```bash
kubectl create secret docker-registry registry-credentials \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass \
  -n webhook-namespace
```

2. Configure in values:
```yaml
harbor-container-webhook:
  imagePullSecrets:
    - name: registry-credentials
```
```

**Complexity:** Simple

---

### 35. **No Support for Multiple Webhook Instances**
**Impact:** In multi-tenant clusters, users may want different rewrite rules per namespace.

**Problem:** No support for deploying multiple instances with different configurations.

**Recommended Fix:**
Document multi-instance deployment pattern:
```markdown
## Multi-Tenant Deployments

To deploy multiple webhook instances with different rules:

1. Deploy to separate namespaces with different release names:
```bash
helm install webhook-team-a . -n team-a -f values-team-a.yaml
helm install webhook-team-b . -n team-b -f values-team-b.yaml
```

2. Configure namespace selectors to isolate webhooks:
```yaml
# values-team-a.yaml
harbor-container-webhook:
  webhook:
    namespaceSelector:
      matchLabels:
        team: team-a
```

**Note:** Only one webhook can be named `harbor-container-webhook` cluster-wide. Use `fullnameOverride` to avoid conflicts.
```

**Complexity:** Simple (documentation)

---

### 36. **No Changelog**
**Impact:** Users cannot determine what changed between versions.

**Problem:** No CHANGELOG.md file.

**Recommended Fix:**
Create `CHANGELOG.md`:
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-15

### Added
- Initial release
- Support for docker.io, mcr.microsoft.com, quay.io, gcr.io rewriting
- Basic values configuration

### Dependencies
- harbor-container-webhook: 0.8.1
```

**Complexity:** Simple

---

## P3 (Low Priority) - Nice-to-Haves

### 37. **No Support for Kustomize**
**Impact:** Users preferring Kustomize over Helm have additional integration work.

**Problem:** No Kustomize overlays provided.

**Recommended Fix:**
Add `kustomize/` directory with base and overlays:
```yaml
# kustomize/base/kustomization.yaml
resources:
  - https://github.com/indeed/harbor-container-webhook/releases/download/v0.8.1/manifest.yaml

# kustomize/overlays/production/kustomization.yaml
bases:
  - ../../base
patchesStrategicMerge:
  - replica-patch.yaml
  - resources-patch.yaml
```

**Complexity:** Moderate

---

### 38. **No OCI Registry Support Documented**
**Impact:** Users may not know the chart can be published to OCI registries.

**Problem:** No documentation of OCI registry usage.

**Recommended Fix:**
Document OCI publishing:
```markdown
## Publishing to OCI Registry

```bash
helm package .
helm push registry-container-webhook-1.0.0.tgz oci://registry.example.com/charts
```

## Installing from OCI Registry

```bash
helm install registry-container-webhook oci://registry.example.com/charts/registry-container-webhook --version 1.0.0
```
```

**Complexity:** Simple (documentation)

---

### 39. **No Support for Custom CA Certificates**
**Impact:** In air-gapped environments with custom CAs, webhook may fail to validate upstream registries (if checkUpstream: true).

**Problem:** No support for mounting custom CA certificates.

**Recommended Fix:**
```yaml
# values.yaml
harbor-container-webhook:
  customCA:
    enabled: false
    secretName: custom-ca-certs
    mountPath: /etc/ssl/certs/custom-ca.crt
    subPath: ca.crt
```

**Complexity:** Moderate

---

### 40. **No Pre-commit Hooks for Chart Validation**
**Impact:** Chart errors are only discovered during CI or deployment.

**Problem:** No local validation tooling.

**Recommended Fix:**
Add `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/gruntwork-io/pre-commit
    rev: v0.1.17
    hooks:
      - id: helmlint

  - repo: https://github.com/norwoodj/helm-docs
    rev: v1.11.0
    hooks:
      - id: helm-docs
        args:
          - --chart-search-root=.
```

Document in README:
```markdown
## Development

### Pre-commit Hooks

```bash
pip install pre-commit
pre-commit install
```

This will automatically run helm lint and regenerate docs before commits.
```

**Complexity:** Simple

---

## Summary by Priority

| Priority | Count | Key Focus |
|----------|-------|-----------|
| P0 (Critical) | 13 | Webhook failure modes, security, availability |
| P1 (High) | 15 | Production readiness, configuration, monitoring |
| P2 (Medium) | 8 | Documentation, testing, examples |
| P3 (Low) | 4 | Developer experience, advanced features |
| **Total** | **40** | |

---

## Recommended Implementation Order

### Phase 1: Critical Fixes (P0 Issues)
**Goal:** Prevent cluster outages and security vulnerabilities

1. Add fail-fast validation for placeholder values (#11)
2. Configure resource limits and requests (#2, #27)
3. Add PodDisruptionBudget (#3)
4. Configure replica count and anti-affinity (#4)
5. Document TLS certificate management (#6)
6. Configure security contexts (#7)
7. Add namespace selector (#9)
8. Create ServiceMonitor and monitoring guidance (#12)
9. Add NetworkPolicy (#13)
10. Document/configure webhook failure policy (#1)
11. Document/configure health checks (#5)
12. Document/configure webhook timeout (#8)
13. Add object selector guidance (#10)

**Estimated Complexity:** 2-3 days of work + testing

---

### Phase 2: Production Hardening (P1 Issues)
**Goal:** Production-ready with proper lifecycle, scaling, and observability

14-28: Implement all P1 items
- Lifecycle hooks
- Topology spread
- Production-ready values
- HPA (optional)
- Node selectors/tolerations
- Priority class
- ConfigMap checksums
- Documentation improvements

**Estimated Complexity:** 3-5 days of work + testing

---

### Phase 3: Enhanced Documentation (P2 Issues)
**Goal:** Comprehensive docs, examples, and tests

29-36: Documentation, examples, and testing
- Comprehensive README
- NOTES.txt
- Multiple value examples
- Helm tests
- ArgoCD support
- Changelog

**Estimated Complexity:** 2-3 days of work

---

### Phase 4: Quality of Life (P3 Issues)
**Goal:** Developer experience and advanced features

37-40: Nice-to-have features
- Kustomize support
- OCI documentation
- Custom CA support
- Pre-commit hooks

**Estimated Complexity:** 1-2 days of work

---

## Risk Assessment

### Current Risk Level: **HIGH**

**Justification:**
- Admission webhook operates in critical path of pod creation
- No visibility into failure policy (could block entire cluster)
- No resource limits (OOM kills could cause webhook unavailability)
- No PDB (voluntary disruptions could break webhook)
- Placeholder values will cause immediate failures if deployed as-is
- No documented security context (webhook can see all pod specs cluster-wide)

### Post-P0-Fixes Risk Level: **MEDIUM**

**Remaining Risks:**
- Dependency on external chart (limited control over implementation)
- No comprehensive test coverage
- Limited operational experience documented

### Post-P1-Fixes Risk Level: **LOW**

**Acceptable Risks:**
- External dependency (mitigated by proper configuration)
- Advanced features not implemented (non-blocking for production use)

---

## Comparison with Reference Charts

### vs. webapp Chart
**Missing Features:**
- ✅ webapp has comprehensive health checks → registry-container-webhook: unknown
- ✅ webapp has PDB with smart defaults → registry-container-webhook: missing
- ✅ webapp has lifecycle hooks → registry-container-webhook: unknown
- ✅ webapp has metrics & ServiceMonitor → registry-container-webhook: missing
- ✅ webapp has NetworkPolicy → registry-container-webhook: missing
- ✅ webapp has topology spread constraints → registry-container-webhook: missing
- ✅ webapp has checksum annotations → registry-container-webhook: unknown

### vs. valkey-cluster Chart
**Missing Features:**
- ✅ valkey has security contexts → registry-container-webhook: missing
- ✅ valkey has resource limits → registry-container-webhook: missing
- ✅ valkey has comprehensive probes → registry-container-webhook: unknown
- ✅ valkey has PDB with cluster-aware defaults → registry-container-webhook: missing
- ✅ valkey has metrics sidecar → registry-container-webhook: unknown
- ✅ valkey has ServiceMonitor → registry-container-webhook: missing
- ✅ valkey has NetworkPolicy → registry-container-webhook: missing

**Key Difference:** Reference charts are self-contained, while registry-container-webhook wraps an external dependency with limited configuration exposure.

---

## Conclusion

The `registry-container-webhook` chart requires significant hardening before production use. The primary concern is that **as a mutating admission webhook, failures can block pod creation cluster-wide**, making availability and failure mode configuration critical.

**Immediate Actions Required (Before Production Deployment):**
1. Validate and document webhook `failurePolicy`
2. Configure resource limits to prevent OOM kills
3. Add PodDisruptionBudget to prevent voluntary disruptions
4. Configure multiple replicas with anti-affinity
5. Replace placeholder values with actual registry URLs
6. Add fail-fast validation to prevent misconfiguration

**Estimated Total Effort:**
- Phase 1 (Critical): 2-3 days
- Phase 2 (Production): 3-5 days
- Phase 3 (Documentation): 2-3 days
- Phase 4 (Quality of Life): 1-2 days
- **Total: 8-13 days** for full production readiness

**Alternative Approach:**
Consider evaluating if the dependency `harbor-container-webhook` can be forked or if templates can be overridden to gain more control over critical configurations. The current wrapper approach provides minimal configuration surface area, making many production hardening features difficult to implement without dependency changes.
