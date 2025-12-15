# WebApp Helm Chart - P2 (Medium Priority) Review

**Review Date:** December 15, 2025
**Chart Version:** 2.5.0
**Reviewer:** Claude Sonnet 4.5
**Context:** Post P0/P1 improvements review

This document identifies Medium Priority (P2) improvements for the webapp Helm chart. These are non-critical enhancements that would improve documentation, observability, security hardening, user experience, and alignment with production-grade best practices (using valkey-cluster chart as reference).

---

## Documentation Improvements

### 1. Missing Production Deployment Guide

**Description:**
The webapp chart lacks a comprehensive production deployment guide similar to valkey-cluster's `PRODUCTION.md`. Users have no centralized reference for production-ready configuration, security hardening, and operational best practices.

**Impact:**
- Users may deploy with insecure defaults in production
- Missing guidance on resource sizing, security context, and HA configuration
- No operational checklist for production readiness
- Steeper learning curve for new users

**Recommended Fix:**
Create `/Volumes/Repos/helm-charts/charts/webapp/PRODUCTION.md` covering:

```markdown
# Production Deployment Guide

## Security Hardening
- Container security context best practices (runAsNonRoot, capabilities, seccomp)
- Pod security context recommendations
- NetworkPolicy configuration patterns
- Secret management with Vault
- Image pull secrets setup

## High Availability
- HPA configuration guidelines
- PodDisruptionBudget recommendations
- Topology spread constraints
- Multi-AZ deployment patterns

## Resource Management
- CPU/memory sizing guidance by workload type
- Resource limits vs requests trade-offs
- VPA integration recommendations

## Migration Job Best Practices
- Timeout configuration
- Resource allocation
- Hook vs init container pattern selection
- Troubleshooting common issues

## Monitoring & Observability
- ServiceMonitor configuration
- Key metrics to monitor
- Health check configuration
- Alerting recommendations

## Operational Checklist
- Pre-deployment verification steps
- Post-deployment validation
- Upgrade procedures
- Rollback strategies
```

**Implementation Complexity:** **2 points** (documentation effort, requires production experience consolidation)

**Reference:** See `/Volumes/Repos/helm-charts/charts/valkey-cluster/PRODUCTION.md` for structure

---

### 2. Enhanced NOTES.txt Post-Install Guidance

**Description:**
Current `NOTES.txt` only provides basic service connection instructions. It lacks contextual information about enabled features, validation steps, and next actions users should take.

**Current State:**
```
1. Get the application URL by running these commands:
[basic kubectl commands]
```

**Impact:**
- Users don't know what features are actually enabled in their deployment
- No guidance on verifying the deployment succeeded
- Missing next steps for common tasks (scaling, monitoring, migrations)

**Recommended Fix:**
Enhance `templates/NOTES.txt` to include:

```yaml
{{- if .Values.autoscaling.enabled }}
** Autoscaling Enabled **
HPA configured with {{ .Values.autoscaling.minReplicas }}-{{ .Values.autoscaling.maxReplicas }} replicas
Target CPU: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}%

Monitor scaling:
  kubectl get hpa {{ include "WebApp.fullname" . }} -n {{ .Release.Namespace }} --watch
{{- end }}

{{- if .Values.migrationJob.enabled }}
** Database Migration Job **
{{- if .Values.migrationJob.waitForItInInitContainer }}
Migration runs as init container (blocks pod startup)
{{- else }}
Migration runs as pre-install/pre-upgrade hook
{{- end }}

Check migration status:
  kubectl get jobs -l app.kubernetes.io/name={{ include "WebApp.fullname" . }}-migrations -n {{ .Release.Namespace }}
{{- end }}

{{- if and .Values.metrics.enabled .Values.metrics.serviceMonitor.enabled }}
** Monitoring Enabled **
ServiceMonitor created for Prometheus Operator
Metrics endpoint: {{ .Values.metrics.path }} on port {{ .Values.metrics.port }}

Verify ServiceMonitor:
  kubectl get servicemonitor {{ include "WebApp.fullname" . }} -n {{ .Release.Namespace }}
{{- end }}

{{- if .Values.networkPolicy.enabled }}
** NetworkPolicy Enabled **
Network access restricted to configured selectors
{{- end }}

{{- if not .Values.podDisruptionBudget.disabled }}
** PodDisruptionBudget Active **
Configured to maintain availability during voluntary disruptions
{{- end }}

Verify deployment health:
  kubectl get pods -l app.kubernetes.io/name={{ include "WebApp.fullname" . }} -n {{ .Release.Namespace }}
  kubectl logs -l app.kubernetes.io/name={{ include "WebApp.fullname" . }} -n {{ .Release.Namespace }} --tail=50
```

**Implementation Complexity:** **1 point** (straightforward template enhancement)

---

### 3. Inline Values.yaml Documentation Gaps

**Description:**
While the chart has extensive comments in `values.yaml`, several areas lack examples, edge case warnings, or best practice guidance found in the valkey-cluster chart.

**Specific Gaps:**

1. **Security Context Examples:**
   - Current: Only basic comments with example values
   - Needed: Production-ready security context block with explanation

2. **Resource Configuration:**
   - Current: No guidance on sizing by workload type
   - Needed: Examples for small/medium/large deployments

3. **HPA Configuration:**
   - Current: No memory-based autoscaling example
   - Needed: Combined CPU+memory target example

4. **Health Probe Tuning:**
   - Current: Default values with no context
   - Needed: Guidance on tuning for slow-starting apps

**Impact:**
- Users copy-paste defaults without understanding implications
- No clear path from development to production configuration
- Trial-and-error approach to resource sizing

**Recommended Fix:**
Add comprehensive inline documentation following valkey-cluster pattern:

```yaml
# -- Container security context
# Production recommendation: Enable all security hardening features
# Example for ASP.NET apps on non-root ports:
containerSecurityContext:
  runAsUser: 10001        # Must exist in container image
  runAsGroup: 10001       # Must exist in container image
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true  # Requires tmpfs mounts for /tmp
#
# Note: readOnlyRootFilesystem requires volumeMounts for writable paths:
# volumeMounts:
#   - name: tmp
#     mountPath: /tmp
# volumes:
#   - name: tmp
#     emptyDir: {}

# -- Resource requests and limits
# Sizing guidance:
# - Small app (1-10 req/sec): cpu: 100m, memory: 128Mi
# - Medium app (10-100 req/sec): cpu: 500m, memory: 512Mi
# - Large app (100+ req/sec): cpu: 1000m, memory: 1Gi
# Recommendation: Set requests based on average usage, omit limits to allow VPA
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  # Limits intentionally omitted - consider VPA for automatic sizing
```

**Implementation Complexity:** **2 points** (requires production knowledge, careful examples)

---

### 4. Missing README Examples Section

**Description:**
The auto-generated README only documents values table. It lacks practical usage examples, common configuration patterns, and quickstart guides found in production charts.

**Impact:**
- No clear "getting started" path for new users
- Users must piece together configuration from values.yaml comments
- Common patterns not documented (ASP.NET apps, Java apps, migration patterns)

**Recommended Fix:**
Extend README with examples section (before helm-docs delimiter):

```markdown
## Quick Start

### Basic Deployment

```yaml
# values.yaml
image:
  repository: myregistry/myapp
  tag: "1.0.0"

resources:
  requests:
    cpu: 100m
    memory: 128Mi
```

```bash
helm install my-webapp innago/webapp -f values.yaml
```

### ASP.NET Core Application

See [value-overrides-aspnet-secure-vault.yaml](value-overrides-aspnet-secure-vault.yaml) for complete example.

Key configurations:
- Non-root user (10001:10001)
- Port 8080 (non-privileged)
- Read-only root filesystem
- Vault integration for secrets

### With Database Migrations

```yaml
migrationJob:
  enabled: true
  image:
    repository: myregistry/myapp-migrations
    tag: "1.0.0"
  # Use init container for long-running migrations
  waitForItInInitContainer: true
```

### High Availability Setup

```yaml
autoscaling:
  enabled: yes
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

podDisruptionBudget:
  disabled: false
  minAvailable: 2

topologySpreadConstraints:
  disabled: false
  whenUnsatisfiable: DoNotSchedule
```

## Common Patterns

### Vault Integration

Configure pod annotations for Bank-Vaults mutating webhook:

```yaml
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "http://vault.default.svc:8200"

containerEnvironmentVariables:
  - name: DATABASE_URL
    value: "vault:/secret/data/myapp#databaseUrl"
```

### Multiple Containers (Sidecar Pattern)

```yaml
additionalContainers:
  - name: log-forwarder
    image: fluent/fluent-bit:latest
    volumeMounts:
      - name: logs
        mountPath: /var/log
```

## Monitoring

Enable Prometheus metrics collection:

```yaml
metrics:
  enabled: true
  path: /metricsz
  port: http
  serviceMonitor:
    enabled: true
    labels:
      release: prometheus
```
```

**Implementation Complexity:** **3 points** (requires writing comprehensive examples, testing scenarios)

---

## Security Hardening Opportunities

### 5. Security Context Defaults Too Permissive

**Description:**
The webapp chart has no default security context values, unlike valkey-cluster which enforces security hardening by default. This creates a security gap for users who don't explicitly configure security contexts.

**Current State:**
```yaml
podSecurityContext:
#  runAsNonRoot: true

containerSecurityContext:
#  runAsUser: 10001
#  allowPrivilegeEscalation: false
```

**Impact:**
- Pods run as root by default (security risk)
- No protection against privilege escalation
- No capability dropping
- Not ready for Pod Security Standards (restricted)

**Recommended Fix:**
Provide secure defaults while allowing override:

```yaml
# values.yaml
podSecurityContext:
  fsGroup: 10001
  runAsUser: 10001
  runAsGroup: 10001
  # Commented for backward compatibility with sidecars
  # runAsNonRoot: true

containerSecurityContext:
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  capabilities:
    drop:
      - ALL
  # Note: readOnlyRootFilesystem requires app support for tmpfs
  readOnlyRootFilesystem: false
```

Add clear documentation about when to override:
```yaml
# Override for custom user IDs or root requirements (not recommended)
# containerSecurityContext:
#   runAsUser: 1000
```

**Migration Path:**
- Document as BREAKING in CHANGELOG
- Provide migration guide for apps requiring root
- Add note about updating Dockerfile to support non-root user

**Implementation Complexity:** **5 points** (requires careful default selection, backward compatibility consideration, migration guide)

---

### 6. Missing Startup Probe Support

**Description:**
The chart only supports liveness and readiness probes. For applications with slow startup times (large framework initialization, dependency downloads), liveness probes may kill pods prematurely. Valkey-cluster chart includes startup probe support.

**Impact:**
- Slow-starting applications may fail liveness checks during initialization
- Users resort to excessively long `initialDelaySeconds` on liveness probe
- Poor user experience for Java apps, large .NET apps, apps with warmup

**Current Workaround:**
```yaml
health:
  livenessProbe:
    initialDelaySeconds: 120  # Very long delay to prevent startup kills
```

**Recommended Fix:**
Add startup probe configuration:

```yaml
# values.yaml
health:
  # -- Startup probe configuration (prevents liveness failures during slow starts)
  # Startup probe runs first, liveness probe starts after first success
  # Example: 30 failures * 10s period = 5min maximum startup time
  startupProbe:
    enabled: false
    httpGet:
      path: /healthz/startup
      port: http
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 30
    successThreshold: 1

  livenessProbe:
    httpGet:
      path: /healthz/live
      port: http
    initialDelaySeconds: 10    # Can be lower with startup probe
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
    successThreshold: 1
```

Template addition in `deployment.yaml`:
```yaml
{{- if .Values.health.startupProbe.enabled }}
startupProbe: {{- toYaml .Values.health.startupProbe | nindent 14 }}
{{- end }}
```

**Implementation Complexity:** **2 points** (straightforward addition, follows existing probe pattern)

**Reference:** Valkey-cluster `values.yaml` lines 220-227, `statefulset.yaml` lines 178-195

---

### 7. No Resource Limit Guidelines

**Description:**
Unlike the valkey-cluster chart which provides clear resource limit/request guidance and rationale, the webapp chart has no documented strategy for resource configuration. This leads to inconsistent deployments and potential resource exhaustion.

**Current State:**
```yaml
resources:
  # limits:
  #   cpu: 100m
  #   memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

**Impact:**
- No guidance on whether to set limits
- Risk of OOMKilled pods with no memory limits
- QoS class unpredictability
- VPA integration unclear

**Recommended Fix:**
Add comprehensive documentation and recommended pattern:

```yaml
# -- Resource requests and limits
# See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
#
# Strategy Recommendations:
# 1. Development: Set requests only (allows VPA to tune limits)
# 2. Production (no VPA): Set both requests and limits based on profiling
# 3. Production (with VPA): Set requests only, let VPA manage limits
#
# QoS Classes:
# - Guaranteed: requests == limits (predictable, highest priority)
# - Burstable: requests < limits (flexible, medium priority)
# - BestEffort: no requests/limits (lowest priority, avoid in production)
#
# Sizing Guidelines:
# - Requests: Based on P95 actual usage from profiling
# - Limits: 1.5-2x requests for burst capacity
# - Memory: Set limit to prevent runaway growth causing node pressure
# - CPU: Consider omitting limit (avoid throttling) unless strict isolation needed
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  # Limits intentionally omitted to allow burst and VPA recommendations
  # Set explicitly if:
  # - VPA not available
  # - Strict resource isolation required
  # - Application has known maximum resource consumption
  # limits:
  #   cpu: 500m
  #   memory: 512Mi
```

**Implementation Complexity:** **1 point** (documentation only)

---

## Observability Enhancements

### 8. Limited Metrics Configuration

**Description:**
The chart only exposes a basic metrics endpoint configuration. It lacks support for multiple metrics endpoints, metrics customization, or conditional metrics exposure found in production charts.

**Current State:**
```yaml
metrics:
  enabled: true
  path: /metricsz
  port: http
```

**Gaps:**
- No support for separate metrics port (security isolation)
- No support for multiple metrics paths (application + system metrics)
- No authentication/authorization configuration for metrics endpoint
- ServiceMonitor doesn't support relabeling or metric filtering

**Impact:**
- Metrics endpoint exposed on same port as application (security concern)
- Cannot scrape from multiple endpoints (e.g., /metrics + /healthz/metrics)
- No way to filter high-cardinality metrics
- Limited observability in complex deployments

**Recommended Fix:**
Enhance metrics configuration:

```yaml
metrics:
  # -- Enable metrics endpoint
  enabled: true
  # -- Metrics endpoint path (primary)
  path: /metricsz
  # -- Metrics endpoint port name (uses same port as http by default)
  # Set to different port for security isolation
  port: http
  # -- Additional metrics endpoints to scrape
  # Example: Application metrics + runtime metrics
  additionalEndpoints: []
  #   - path: /metrics/runtime
  #     port: http
  #     interval: 60s

  # -- ServiceMonitor configuration for Prometheus Operator
  serviceMonitor:
    enabled: false
    namespace: ""
    labels: {}
    interval: 30s
    scrapeTimeout: 10s
    namespaceSelector: {}
    # -- Metric relabel configurations to apply to samples before ingestion
    # Example: Drop high-cardinality metrics
    metricRelabelings: []
    #   - sourceLabels: [__name__]
    #     regex: 'http_request_duration_seconds_bucket'
    #     action: drop
    # -- Relabel configurations to apply to samples before scraping
    relabelings: []
```

Template enhancement in `servicemonitor.yaml`:
```yaml
endpoints:
  - port: {{ .Values.metrics.port }}
    path: {{ .Values.metrics.path }}
    interval: {{ .Values.metrics.serviceMonitor.interval }}
    scrapeTimeout: {{ .Values.metrics.serviceMonitor.scrapeTimeout }}
    {{- with .Values.metrics.serviceMonitor.relabelings }}
    relabelings:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.metrics.serviceMonitor.metricRelabelings }}
    metricRelabelings:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- range .Values.metrics.additionalEndpoints }}
  - port: {{ .port }}
    path: {{ .path }}
    {{- if .interval }}
    interval: {{ .interval }}
    {{- end }}
  {{- end }}
```

**Implementation Complexity:** **3 points** (requires ServiceMonitor enhancement, testing)

---

### 9. No Structured Logging Configuration

**Description:**
The chart doesn't provide built-in support for structured logging configuration or log aggregation patterns. Applications must manually configure logging format, which leads to inconsistent log formats across deployments.

**Impact:**
- Inconsistent log formats across applications
- Harder to aggregate and query logs
- No standardized metadata injection (pod name, namespace, etc.)
- Missing guidance on log level configuration

**Recommended Fix:**
Add logging configuration section:

```yaml
# -- Logging configuration
logging:
  # -- Log format: json or text
  # Recommendation: Use json for production (easier to parse)
  format: json
  # -- Default log level
  level: info
  # -- Environment variables for common logging frameworks
  # These are automatically added to containerEnvironmentVariables
  autoInjectEnvVars: true
  # -- Custom logging environment variables
  additionalEnvVars: []
  #   - name: LOG_STRUCTURED
  #     value: "true"
```

Template injection in `deployment.yaml`:
```yaml
{{- if .Values.logging.autoInjectEnvVars }}
# Logging configuration (auto-injected)
{{- if eq .Values.logging.format "json" }}
- name: LOG_FORMAT
  value: "json"
- name: LOGGING__CONSOLE__FORMATTERNAME  # ASP.NET Core
  value: "json"
{{- end }}
- name: LOG_LEVEL
  value: {{ .Values.logging.level | quote }}
- name: LOGGING__LOGLEVEL__DEFAULT  # ASP.NET Core
  value: {{ .Values.logging.level | title | quote }}
{{- end }}
```

**Implementation Complexity:** **3 points** (requires template logic, framework-specific variables)

---

### 10. Missing Deployment Strategy Configuration

**Description:**
The chart uses default Kubernetes deployment strategy (RollingUpdate with 25% surge/unavailable). For production deployments, users often need to customize rolling update parameters, or use recreate strategy for specific scenarios.

**Impact:**
- No control over rollout speed
- Cannot configure for zero-downtime deployments explicitly
- No blue-green or canary deployment support
- Migrations during updates not coordinated with deployment strategy

**Recommended Fix:**
Add deployment strategy configuration:

```yaml
# -- Deployment strategy configuration
# See https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy
deploymentStrategy:
  # -- Deployment strategy type: RollingUpdate or Recreate
  type: RollingUpdate
  # -- Rolling update configuration
  rollingUpdate:
    # -- Maximum number of pods that can be created over desired replicas
    # Percentage or absolute number
    maxSurge: 25%
    # -- Maximum number of pods that can be unavailable during update
    # Percentage or absolute number
    # For zero-downtime: set to 0 (requires maxSurge > 0)
    maxUnavailable: 25%
```

Template addition in `deployment.yaml`:
```yaml
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ max 2 .Values.replicaCount }}
  {{- end }}
  {{- if .Values.deploymentStrategy }}
  strategy:
    {{- toYaml .Values.deploymentStrategy | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "WebApp.selectorLabels" . | nindent 6 }}
```

**Implementation Complexity:** **2 points** (straightforward addition, standard K8s API)

---

## Convenience Features

### 11. No Support for Service Annotations

**Description:**
The Service template doesn't support custom annotations, which are commonly needed for cloud provider integrations (AWS NLB, GCP ILB), service mesh configurations, and other service-level metadata.

**Current State:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "WebApp.fullname" . | lower }}
  labels:
    {{- include "WebApp.labels" . | nindent 4 }}
# No annotations support
```

**Impact:**
- Cannot configure AWS Load Balancer Controller annotations
- Cannot add service mesh metadata
- Cannot configure custom DNS annotations
- Users must maintain separate patch files

**Common Use Cases:**
- AWS: `service.beta.kubernetes.io/aws-load-balancer-type: nlb`
- GCP: `cloud.google.com/load-balancer-type: "Internal"`
- Istio: Service mesh routing annotations
- External DNS: Custom DNS configuration

**Recommended Fix:**
Add service annotations configuration:

```yaml
# values.yaml
service:
  type: ClusterIP
  port: 80
  enableHttps: false
  httpsPort: 443
  # -- Annotations to add to the Service
  # Example for AWS NLB:
  #   service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  #   service.beta.kubernetes.io/aws-load-balancer-internal: "true"
  annotations: {}
```

Template update in `service.yaml`:
```yaml
metadata:
  name: {{ include "WebApp.fullname" . | lower }}
  labels:
    {{- include "WebApp.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
```

**Implementation Complexity:** **1 point** (trivial addition)

---

### 12. No ConfigMap/Secret Checksums for Additional Volumes

**Description:**
The chart includes checksum annotation for `appsetting-configmap.yaml` to trigger pod restarts on config changes. However, if users mount additional ConfigMaps or Secrets via `volumes`/`volumeMounts`, changes to those resources don't trigger automatic pod restarts.

**Current State:**
```yaml
# deployment.yaml
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/appsetting-configmap.yaml") . | sha256sum }}
```

**Impact:**
- Additional ConfigMaps/Secrets require manual pod restarts
- Config drift between mounted config and running pods
- Confusing behavior for users expecting automatic updates

**Recommended Fix:**
Add support for automatic checksum generation:

```yaml
# values.yaml
# -- Automatically restart pods when these ConfigMaps change
# List of ConfigMap names to include in checksum calculation
configMapChecksums: []
#   - my-app-config
#   - shared-config

# -- Automatically restart pods when these Secrets change
# List of Secret names to include in checksum calculation
secretChecksums: []
#   - my-app-secrets
#   - database-credentials
```

Template enhancement in `deployment.yaml`:
```yaml
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/appsetting-configmap.yaml") . | sha256sum }}
  {{- range .Values.configMapChecksums }}
  checksum/configmap-{{ . }}: {{ (lookup "v1" "ConfigMap" $.Release.Namespace .) | toJson | sha256sum }}
  {{- end }}
  {{- range .Values.secretChecksums }}
  checksum/secret-{{ . }}: {{ (lookup "v1" "Secret" $.Release.Namespace .) | toJson | sha256sum }}
  {{- end }}
```

**Note:** This requires Helm 3+ with lookup function support.

**Implementation Complexity:** **3 points** (requires lookup function, testing, documentation)

---

### 13. Missing InitContainer Configuration Support

**Description:**
The chart only includes migration-specific init container configuration. For other common init container patterns (waiting for dependencies, downloading config, running setup scripts), users must manually patch the deployment.

**Impact:**
- Cannot wait for database readiness before starting app
- Cannot download external configuration at startup
- Cannot run initialization scripts
- Limited flexibility for advanced deployment patterns

**Recommended Fix:**
Add general-purpose init container support:

```yaml
# values.yaml
# -- Init containers to run before the main application container
# Follows Kubernetes pod.spec.initContainers syntax
# Example: Wait for database
initContainers: []
#   - name: wait-for-db
#     image: busybox:1.36
#     command:
#       - sh
#       - -c
#       - |
#         until nc -z postgres 5432; do
#           echo "Waiting for postgres..."
#           sleep 2
#         done
#   - name: download-config
#     image: curlimages/curl:latest
#     command:
#       - sh
#       - -c
#       - curl -o /config/app.json https://config-server/app.json
#     volumeMounts:
#       - name: config
#         mountPath: /config
```

Template addition in `deployment.yaml`:
```yaml
spec:
  # ... existing spec ...
  {{- if or .Values.initContainers (and .Values.migrationJob.enabled .Values.migrationJob.waitForItInInitContainer) }}
  initContainers:
    {{- if and .Values.migrationJob.enabled .Values.migrationJob.waitForItInInitContainer }}
    - name: k8s-wait-for
      image: "{{ .Values.migrationJob.initContainerImage.repository }}:{{ .Values.migrationJob.initContainerImage.tag }}"
      imagePullPolicy: {{ .Values.migrationJob.initContainerImage.pullPolicy }}
      args:
        - "job"
        - {{ include "WebApp.migrationJobName" . }}
    {{- end }}
    {{- with .Values.initContainers }}
      {{- toYaml . | nindent 8 }}
    {{- end }}
  {{- end }}
```

**Implementation Complexity:** **2 points** (requires careful template refactoring)

---

### 14. No Pod Labels Configuration

**Description:**
While the chart supports `podAnnotations`, `podLabels` configuration is incomplete. The values.yaml shows `podLabels: #{}` (commented out) but doesn't provide clear guidance or examples for common label use cases.

**Current State:**
```yaml
# values.yaml
podLabels: #{}
#  hello: world
```

**Impact:**
- Cannot add custom labels for monitoring selectors
- Cannot tag pods for cost allocation
- Cannot add team/ownership labels
- Service mesh and policy tools can't target pods by custom labels

**Common Use Cases:**
- Cost allocation: `cost-center: engineering`, `team: platform`
- Monitoring: `prometheus.io/scrape: "true"`
- Policy: `policy.security/scan: "enabled"`
- Service mesh: `version: v1.2.3`, `environment: production`

**Recommended Fix:**
Enhance documentation and provide examples:

```yaml
# values.yaml
# -- Labels to add to pods
# These labels are added in addition to standard app.kubernetes.io labels
# Common use cases:
# - Cost allocation: team, cost-center, environment
# - Monitoring: prometheus.io/*, datadog/*
# - Policy enforcement: policy.*/*, security/*
# - Service mesh: version, traffic routing labels
podLabels: {}
#   team: platform
#   cost-center: engineering
#   version: v1.2.3
#   environment: production
```

Also ensure template properly handles empty podLabels:
```yaml
# deployment.yaml (already correctly implemented)
labels:
  {{- include "WebApp.selectorLabels" . | nindent 8 }}
  {{- if .Values.podLabels }}
    {{- toYaml .Values.podLabels | nindent 8 }}
  {{- end }}
```

**Implementation Complexity:** **1 point** (documentation improvement only, template already correct)

---

### 15. Missing HPA Behavior Configuration (v2 API)

**Description:**
The chart uses HPA v2 API but only configures basic CPU-based scaling. It doesn't expose advanced v2 features like behavior policies (scale-up/down velocity), memory-based scaling, or custom metrics.

**Current State:**
```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
# Only CPU metric configured
```

**Missing Features:**
- Scale-up/down behavior policies (velocity control)
- Memory-based autoscaling
- Custom metrics support
- Multiple metric types

**Impact:**
- Cannot prevent rapid scaling oscillation
- Cannot configure different scale-up vs scale-down rates
- Memory-based scaling requires manual HPA creation
- Limited autoscaling sophistication

**Recommended Fix:**
Enhance HPA configuration to expose v2 API features:

```yaml
# values.yaml
autoscaling:
  enabled: no
  minReplicas: 2
  maxReplicas: 4
  # -- Target CPU utilization percentage
  targetCPUUtilizationPercentage: 80
  # -- Target memory utilization percentage (optional)
  # Requires memory requests to be set
  targetMemoryUtilizationPercentage: null
  # -- Custom metrics for autoscaling (advanced)
  # Example: Scale based on HTTP requests per second
  customMetrics: []
  #   - type: Pods
  #     pods:
  #       metric:
  #         name: http_requests_per_second
  #       target:
  #         type: AverageValue
  #         averageValue: "1000"

  # -- HPA scaling behavior configuration (v2 API)
  # Controls scale-up/down velocity and stabilization
  behavior: {}
  #   scaleDown:
  #     stabilizationWindowSeconds: 300
  #     policies:
  #       - type: Percent
  #         value: 50
  #         periodSeconds: 60
  #   scaleUp:
  #     stabilizationWindowSeconds: 0
  #     policies:
  #       - type: Percent
  #         value: 100
  #         periodSeconds: 30
  #       - type: Pods
  #         value: 2
  #         periodSeconds: 30
  #     selectPolicy: Max
```

Template enhancement in `hpa.yaml`:
```yaml
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "WebApp.fullname" . | lower }}
  minReplicas: {{ max 2 .Values.autoscaling.minReplicas }}
  maxReplicas: {{ max 2 .Values.autoscaling.minReplicas .Values.autoscaling.maxReplicas }}
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
    {{- with .Values.autoscaling.customMetrics }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.autoscaling.behavior }}
  behavior:
    {{- toYaml . | nindent 4 }}
  {{- end }}
```

**Implementation Complexity:** **3 points** (requires HPA v2 API knowledge, testing)

---

## Comparison with Production-Grade Charts

### 16. No Helper Template for Version Labels

**Description:**
The chart duplicates version label logic in multiple templates. Valkey-cluster demonstrates better template organization with dedicated helper functions for consistent version labeling.

**Current State:**
```yaml
# deployment.yaml
{{- if .Values.image.tag }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}

# migration-job.yaml
{{- if .Values.migrationJob.image.tag }}
app.kubernetes.io/version: {{ .Values.migrationJob.image.tag | quote }}
{{- end }}
```

**Impact:**
- Logic duplication across templates
- Inconsistent version labeling if one location is updated
- Harder to maintain and extend

**Recommended Fix:**
Add helper template in `_helpers.tpl`:

```yaml
{{/*
Version label for main application
*/}}
{{- define "WebApp.versionLabel" -}}
{{- if .Values.image.tag -}}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- else if .Chart.AppVersion -}}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}
{{- end -}}

{{/*
Version label for migrations
*/}}
{{- define "WebAppMigrations.versionLabel" -}}
{{- if .Values.migrationJob.image.tag -}}
app.kubernetes.io/version: {{ .Values.migrationJob.image.tag | quote }}
{{- else if .Chart.AppVersion -}}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}
{{- end -}}
```

Update label sections to use helpers:
```yaml
# deployment.yaml labels
{{ include "WebApp.selectorLabels" . }}
{{ include "WebApp.versionLabel" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
```

**Implementation Complexity:** **1 point** (simple refactoring)

---

### 17. Incomplete Vault Integration Documentation

**Description:**
The chart includes `innagoVaultK8sRoleOperator` support and sample values for Bank-Vaults, but lacks comprehensive documentation on:
- How the Vault integration actually works
- What the vault-role-operator does
- How to troubleshoot Vault injection
- Migration from non-Vault to Vault-based secrets

**Current Documentation:**
Only inline comments in values.yaml, no dedicated guide.

**Impact:**
- Users struggle to understand Vault integration
- Trial-and-error approach to configuring Vault annotations
- No troubleshooting guide when injection fails
- Unclear best practices for secret management

**Recommended Fix:**
Create `/Volumes/Repos/helm-charts/charts/webapp/VAULT-INTEGRATION.md`:

```markdown
# Vault Integration Guide

## Overview

This chart supports HashiCorp Vault integration through two mechanisms:
1. Bank-Vaults Mutating Webhook (recommended)
2. Manual secret mounting

## Bank-Vaults Integration

### Prerequisites

- Bank-Vaults operator installed in cluster
- Vault server accessible from cluster
- innago-vault-k8s-role-operator (optional, for automatic role creation)

### Basic Configuration

```yaml
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "http://vault.default.svc:8200"

containerEnvironmentVariables:
  - name: DATABASE_PASSWORD
    value: "vault:/secret/data/myapp#databasePassword"
```

### Automatic Role Creation

Enable vault-role-operator integration:

```yaml
innagoVaultK8sRoleOperator:
  use: true
  additionalPolicies:
    - database-dynamic-creds
    - messaging-credentials
```

This creates:
- Vault policy allowing read access to `/secret/data/myapp/*`
- Kubernetes auth role binding service account to policy

### Common Patterns

#### Database Connection String

```yaml
containerEnvironmentVariables:
  - name: ConnectionStrings__DefaultConnection
    value: "vault:/secret/data/myapp#connectionString"
```

#### Multiple Secrets from Same Path

```yaml
- name: DB_HOST
  value: "vault:/secret/data/postgres#host"
- name: DB_PORT
  value: "vault:/secret/data/postgres#port"
- name: DB_PASSWORD
  value: "vault:/secret/data/postgres#password"
```

#### Dynamic Database Credentials

```yaml
innagoVaultK8sRoleOperator:
  additionalPolicies:
    - postgres-dynamic-creds

containerEnvironmentVariables:
  - name: DB_USERNAME
    value: "vault:/database/creds/myapp-role#username"
  - name: DB_PASSWORD
    value: "vault:/database/creds/myapp-role#password"
```

### Troubleshooting

#### Secrets Not Injected

Check vault-env init container logs:
```bash
kubectl logs <pod-name> -c vault-env
```

#### Permission Denied

Verify Vault policy allows read access:
```bash
vault policy read <service-account-name>
```

#### Wrong Vault Address

Check annotation is correct for your environment:
```yaml
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "http://vault.vault-system.svc:8200"
```
```

**Implementation Complexity:** **3 points** (requires Vault expertise, comprehensive documentation)

---

### 18. No Chart Tests Beyond Basic Connection

**Description:**
The chart only includes a basic connection test (`templates/tests/test-connection.yaml`). Production charts should include tests for:
- Health endpoint validation
- Metrics endpoint accessibility
- Migration job completion (if enabled)
- ServiceMonitor creation (if enabled)

**Current Test Coverage:**
```yaml
# templates/tests/test-connection.yaml
# Only tests if service DNS resolves and port is open
```

**Impact:**
- No validation that application actually started correctly
- Cannot verify health checks are working
- No automated testing of chart configuration
- Users must manually verify deployment success

**Recommended Fix:**
Add comprehensive Helm test suite:

```yaml
# templates/tests/test-health-endpoints.yaml
{{- if .Values.health.readinessProbe }}
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "WebApp.fullname" . }}-test-health
  labels:
    {{- include "WebApp.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  containers:
    - name: wget
      image: busybox:1.36
      command:
        - wget
        - --spider
        - --timeout=5
        - "http://{{ include "WebApp.fullname" . }}:{{ .Values.service.port }}{{ .Values.health.readinessProbe.httpGet.path }}"
  restartPolicy: Never
{{- end }}

# templates/tests/test-metrics.yaml
{{- if and .Values.metrics.enabled }}
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "WebApp.fullname" . }}-test-metrics
  labels:
    {{- include "WebApp.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  containers:
    - name: wget
      image: busybox:1.36
      command:
        - wget
        - --spider
        - --timeout=5
        - "http://{{ include "WebApp.fullname" . }}:{{ .Values.service.port }}{{ .Values.metrics.path }}"
  restartPolicy: Never
{{- end }}

# templates/tests/test-migration-job.yaml
{{- if .Values.migrationJob.enabled }}
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "WebApp.fullname" . }}-test-migration
  labels:
    {{- include "WebApp.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  containers:
    - name: check-job
      image: bitnami/kubectl:latest
      command:
        - kubectl
        - wait
        - --for=condition=complete
        - --timeout=300s
        - job/{{ include "WebApp.migrationJobName" . }}
  restartPolicy: Never
  serviceAccountName: {{ include "WebApp.serviceAccountName" . }}
{{- end }}
```

Run tests:
```bash
helm test my-webapp
```

**Implementation Complexity:** **3 points** (requires multiple test pods, RBAC considerations)

---

## Summary

### Priority Matrix

| Issue # | Category | Complexity | Impact | Recommendation |
|---------|----------|------------|--------|----------------|
| 1 | Documentation | 2 | High | Implement in next minor release |
| 2 | Documentation | 1 | Medium | Quick win |
| 3 | Documentation | 2 | Medium | Gradual improvement |
| 4 | Documentation | 3 | High | Implement with examples |
| 5 | Security | 5 | High | Plan for major version (breaking) |
| 6 | Security | 2 | Medium | Implement in next minor release |
| 7 | Documentation | 1 | Medium | Quick win |
| 8 | Observability | 3 | Medium | Implement if monitoring is priority |
| 9 | Observability | 3 | Low | Optional enhancement |
| 10 | Deployment | 2 | Medium | Implement in next minor release |
| 11 | Convenience | 1 | High | Quick win |
| 12 | Convenience | 3 | Medium | Implement with caution (lookup) |
| 13 | Convenience | 2 | Medium | Implement in next minor release |
| 14 | Documentation | 1 | Low | Quick win |
| 15 | Scalability | 3 | Medium | Implement if HPA is widely used |
| 16 | Maintainability | 1 | Low | Optional refactoring |
| 17 | Documentation | 3 | High | High priority for Vault users |
| 18 | Testing | 3 | Medium | Implement for production confidence |

### Recommended Roadmap

**Phase 1: Quick Wins (1-2 points complexity)**
- Issue #2: Enhanced NOTES.txt
- Issue #7: Resource limit guidelines
- Issue #11: Service annotations support
- Issue #14: Pod labels documentation
- Issue #16: Helper template refactoring

**Phase 2: High-Value Medium Effort (2-3 points complexity)**
- Issue #1: Production deployment guide
- Issue #3: Inline values documentation
- Issue #6: Startup probe support
- Issue #10: Deployment strategy configuration
- Issue #13: Init container support

**Phase 3: Advanced Features (3+ points complexity)**
- Issue #4: README examples section
- Issue #8: Enhanced metrics configuration
- Issue #15: HPA v2 behavior configuration
- Issue #17: Vault integration guide
- Issue #18: Comprehensive test suite

**Phase 4: Breaking Changes (requires major version)**
- Issue #5: Security context secure defaults

**Optional/As-Needed**
- Issue #9: Structured logging (framework-specific)
- Issue #12: ConfigMap/Secret checksums (lookup dependency)

---

**Total Issues Identified:** 18
**Quick Wins (≤1 point):** 5
**Medium Effort (2-3 points):** 10
**High Effort (≥4 points):** 3
**Breaking Changes:** 1

**Estimated Total Effort:** 41 complexity points (approximately 2-3 sprint cycles for implementation + testing + documentation)
