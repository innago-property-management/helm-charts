# Production Readiness Review: innago-vault-k8s-role-operator

**Chart Version:** 0.1.1
**App Version:** 0.1.1
**Review Date:** 2025-12-15
**Reviewer:** Claude (Automated Review)

---

## Executive Summary

This Helm chart deploys a Vault Kubernetes Role Operator that manages Vault roles and policies for service accounts. The chart uses the `webapp` subchart as a dependency, which provides solid production-grade patterns. However, there are several critical issues that must be addressed before production deployment, particularly around RBAC permissions, resource limits, and operator-specific configurations.

**Overall Readiness:** ⚠️ **NOT READY FOR PRODUCTION**

**Critical Issues:** 6 P0, 8 P1
**Total Issues:** 29

---

## Priority 0 (Critical) - Production Blockers

### P0-1: Overly Permissive RBAC Permissions

**File:** `/templates/cluster-role.yaml` (Lines 8-10)

**Issue:**
```yaml
rules:
  - verbs: ["list", "get", "watch"]
    resources: ["*"]
    apiGroups: ["*"]
```

This grants the operator read access to **ALL resources in ALL API groups** across the entire cluster, including Secrets, which is a severe security vulnerability. An operator should follow the principle of least privilege.

**Impact:**
- **CRITICAL SECURITY RISK:** Operator can read all Secrets, ConfigMaps, and sensitive resources cluster-wide
- Violates least-privilege security principle
- Potential compliance violations (SOC2, GDPR, HIPAA)
- If operator pod is compromised, entire cluster is exposed

**Recommended Fix:**
Specify only the exact resources needed:
```yaml
rules:
  # Read access to specific resources only
  - verbs: ["list", "get", "watch"]
    resources: ["serviceaccounts"]
    apiGroups: [""]
  - verbs: ["list", "get", "watch"]
    resources: ["namespaces"]
    apiGroups: [""]
  # Full access to ConfigMaps (operator's primary resource)
  - verbs: ["*"]
    resources: ["configmaps"]
    apiGroups: [""]
  # Coordination for leader election
  - verbs: ["*"]
    apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
  # If watching Jobs/CronJobs is truly needed
  - verbs: ["list", "get", "watch"]
    resources: ["cronjobs", "jobs"]
    apiGroups: ["batch"]
```

**Complexity:** Simple (template-only change)

---

### P0-2: Missing Resource Limits

**File:** `values.yaml` (webapp subchart passthrough)

**Issue:**
No resource limits are defined for the operator container. The webapp subchart defaults only include requests but not limits.

**Impact:**
- Pod can consume unlimited CPU/memory, causing node instability
- No protection against memory leaks or runaway processes
- Kubernetes cannot make informed scheduling decisions
- Risk of OOM kills affecting other workloads
- Violates production best practices

**Recommended Fix:**
Add to `values.yaml`:
```yaml
innago-webapp:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m      # Prevents CPU starvation of other pods
      memory: 256Mi  # Prevents OOM affecting node
```

For an operator watching ConfigMaps, these are reasonable starting values. Monitor and adjust based on actual usage.

**Complexity:** Simple (values.yaml only)

---

### P0-3: No Startup Probe for Operator

**File:** `values.yaml`

**Issue:**
Operators often require time to initialize (connect to Vault, set up watches, perform leader election). Without a startup probe, the liveness probe may kill the pod during legitimate startup delays.

**Impact:**
- Pod may be killed by liveness probe during slow startup
- Leader election can take 15-30 seconds
- Vault connection establishment may be slow
- Causes crashloop backoff in production
- Delays operator becoming operational

**Recommended Fix:**
Add to `values.yaml`:
```yaml
innago-webapp:
  health:
    # Startup probe prevents liveness from killing during slow initialization
    startupProbe:
      httpGet:
        path: /healthz
        port: http
      initialDelaySeconds: 0
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 30  # 150 seconds total for startup
      successThreshold: 1
    livenessProbe:
      httpGet:
        path: /healthz
        port: http
      initialDelaySeconds: 10  # Reduced since startup probe handles initialization
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /healthz
        port: http
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
```

**Complexity:** Simple (values.yaml only)

---

### P0-4: Hardcoded Vault Address in Default Values

**File:** `values.yaml` (Lines 54)

**Issue:**
```yaml
vault.security.banzaicloud.io/vault-addr: https://vault.default.svc:8200
```

Hardcoded to `default` namespace. This will fail in most production deployments where Vault is in a different namespace (e.g., `vault`, `vault-system`, or per-environment namespaces).

**Impact:**
- **CRITICAL:** Operator cannot connect to Vault in production
- Chart is not portable across environments
- Requires users to override in every deployment
- Common cause of "it works in dev but not prod" issues

**Recommended Fix:**
Make it configurable with sensible defaults:
```yaml
innago-webapp:
  podAnnotations:
    # Vault configuration - MUST be configured per environment
    vault.security.banzaicloud.io/vault-addr: {{ .Values.vault.address | default "https://vault.vault-system.svc:8200" }}
    vault.security.banzaicloud.io/vault-tls-secret: {{ .Values.vault.tlsSecret | default "vault-tls" }}
    keptn.sh/workload: *name
    keptn.sh/version: *tag
    keptn.sh/app: *name

# Add vault configuration section
vault:
  # -- Vault server address (must be accessible from operator pod)
  address: "https://vault.vault-system.svc:8200"
  # -- Name of secret containing Vault TLS certificate
  tlsSecret: "vault-tls"
```

Add validation to templates:
```yaml
{{- if not .Values.vault.address }}
{{- fail "vault.address is required for operator to function" }}
{{- end }}
```

**Complexity:** Moderate (requires template changes + validation)

---

### P0-5: Missing Leader Election Configuration

**File:** `values.yaml` (operator configuration)

**Issue:**
The ClusterRole includes permissions for `leases` (coordination.k8s.io), suggesting leader election, but there's no configuration for:
- Leader election lease name
- Lease duration
- Renew deadline
- Retry period

Multiple replicas without proper leader election will cause conflicting Vault operations.

**Impact:**
- **CRITICAL:** Multiple operator instances will race, causing:
  - Duplicate Vault role creation attempts
  - Conflicting policy updates
  - Resource thrashing
  - Vault API rate limiting
- Data corruption risk in Vault configuration
- Unpredictable operator behavior

**Recommended Fix:**
Add to `values.yaml`:
```yaml
innago-webapp:
  containerEnvironmentVariables:
    # Leader election configuration
    - name: LEADER_ELECTION_ENABLED
      value: "true"
    - name: LEADER_ELECTION_ID
      value: "innago-vault-k8s-role-operator-leader"
    - name: LEADER_ELECTION_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    # Operator configuration
    - name: OPERATOR_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
```

Document in README.md that only the leader performs Vault operations.

**Complexity:** Moderate (requires application code verification + env vars)

---

### P0-6: Missing Fail-Fast Validation

**File:** `templates/cluster-role.yaml`, `Chart.yaml`

**Issue:**
No validation that required dependencies are present:
- No check that webapp subchart is actually deployed
- No validation of RBAC permissions
- No check that Vault annotations are configured

**Impact:**
- Silent failures during deployment
- Chart appears to deploy successfully but doesn't work
- Difficult to troubleshoot for users
- Wasted time debugging obvious configuration errors

**Recommended Fix:**
Add template validation in `templates/_helpers.tpl`:
```yaml
{{/*
Validate operator configuration
*/}}
{{- define "innago-vault-k8s-role-operator.validateConfig" -}}
{{- if not .Values.vault }}
{{- fail "vault configuration is required. Set vault.address and vault.tlsSecret" }}
{{- end }}
{{- if not .Values.vault.address }}
{{- fail "vault.address is required for operator to connect to Vault" }}
{{- end }}
{{- if not .Values.serviceAccount.create }}
{{- fail "serviceAccount.create must be true for operator to function" }}
{{- end }}
{{- if .Values.innago-webapp.replicaCount }}
{{- if gt (int .Values.innago-webapp.replicaCount) 1 }}
{{- if not (index .Values.innago-webapp.containerEnvironmentVariables "LEADER_ELECTION_ENABLED") }}
{{- fail "Leader election must be enabled when replicaCount > 1 to prevent conflicting operations" }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
```

Add to both RBAC templates:
```yaml
{{- include "innago-vault-k8s-role-operator.validateConfig" . }}
```

**Complexity:** Moderate (template changes + testing)

---

## Priority 1 (High Priority) - Production Readiness Gaps

### P1-1: Inadequate PodDisruptionBudget Configuration

**File:** `values.yaml` (Lines 22-30)

**Issue:**
```yaml
podDisruptionBudget:
  disabled: false
  minAvailable: 0        # ← PROBLEM
  maxUnavailable: 1
```

Setting `minAvailable: 0` means during node drains/upgrades, **all operator pods can be unavailable simultaneously**. This defeats the purpose of having a PDB.

**Impact:**
- During cluster maintenance (node drains), operator becomes completely unavailable
- New workloads cannot get Vault roles/policies during upgrades
- Violates high availability expectations
- PDB provides no actual protection

**Recommended Fix:**
For operators, ensure at least one pod is always available:
```yaml
innago-webapp:
  podDisruptionBudget:
    disabled: false
    minAvailable: 1      # Always keep at least one operator pod running
    maxUnavailable: null # Use minAvailable instead
    unhealthyPodEvictionPolicy: IfHealthyBudget
```

This ensures during voluntary disruptions (node drains), Kubernetes waits for new pod to be ready before terminating the old one.

**Complexity:** Simple (values.yaml only)

---

### P1-2: Missing Resource Requests

**File:** `values.yaml` (webapp subchart)

**Issue:**
No resource requests are defined, causing pods to be scheduled as BestEffort QoS class.

**Impact:**
- Pod scheduled as BestEffort (lowest QoS class)
- First to be evicted during node pressure
- No CPU/memory guarantees
- Unpredictable performance
- Cannot use Vertical Pod Autoscaler effectively

**Recommended Fix:**
See P0-2 - adding both requests and limits together.

**Complexity:** Simple (values.yaml only)

---

### P1-3: No Metrics/Observability Configuration

**File:** `values.yaml`

**Issue:**
No metrics collection configured. The webapp subchart has ServiceMonitor support, but it's not enabled or configured.

**Impact:**
- No visibility into operator health
- Cannot detect when operator stops processing ConfigMaps
- No alerting on failures
- Cannot track ConfigMap processing latency
- Difficult to troubleshoot production issues
- No SLO/SLA monitoring capability

**Recommended Fix:**
Add to `values.yaml`:
```yaml
innago-webapp:
  # Enable metrics
  metrics:
    enabled: true
    path: /metrics  # Standard Prometheus path
    port: http
    serviceMonitor:
      enabled: true
      namespace: ""  # Same as release
      labels:
        release: prometheus  # Adjust to your Prometheus Operator release name
      interval: 30s
      scrapeTimeout: 10s
```

Ensure the operator application exposes metrics at `/metrics` including:
- `vault_role_operations_total{status="success|failure"}`
- `vault_configmap_processing_duration_seconds`
- `vault_operator_reconcile_total{result="success|failure"}`
- `vault_operator_leader{status="true|false"}`

**Complexity:** Moderate (requires application metrics + ServiceMonitor config)

---

### P1-4: Replica Count Should Be 2+ for HA

**File:** `values.yaml`

**Issue:**
No explicit replica count is set, defaulting to webapp chart's default of 2. However, this isn't explicitly documented for the operator use case.

**Impact:**
- Single point of failure if only 1 replica configured
- No redundancy during pod crashes or node failures
- Downtime during rolling updates
- ConfigMap changes not processed during operator downtime

**Recommended Fix:**
Explicitly set and document:
```yaml
innago-webapp:
  # Replica count - minimum 2 for high availability
  # With leader election, only the leader performs operations
  # Followers provide failover capability
  replicaCount: 2

  # Or enable HPA for dynamic scaling based on load
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 4
    targetCPUUtilizationPercentage: 80
```

Document in README.md:
- Why 2+ replicas are recommended
- How leader election works
- Failover behavior

**Complexity:** Simple (values.yaml + documentation)

---

### P1-5: Missing NetworkPolicy

**File:** No networkpolicy template exists

**Issue:**
The webapp subchart supports NetworkPolicy, but it's not configured. Operators should have restricted network access.

**Impact:**
- Operator pod can make arbitrary outbound connections
- No network segmentation
- Increased attack surface if pod is compromised
- Violates defense-in-depth security principle
- May fail security audits

**Recommended Fix:**
Enable and configure NetworkPolicy:
```yaml
innago-webapp:
  networkPolicy:
    enabled: true
    ingress:
      # Allow Prometheus to scrape metrics
      allowExternal: true
      prometheusNamespaceSelector:
        matchLabels:
          name: monitoring
    egress:
      enabled: true
      # Allow DNS
      dns:
        to: []  # Uses default kube-system/kube-dns
      customRules:
        # Allow connection to Vault
        - to:
            - namespaceSelector:
                matchLabels:
                  name: vault-system  # Adjust to your Vault namespace
          ports:
            - protocol: TCP
              port: 8200
        # Allow Kubernetes API server access (for watching ConfigMaps)
        - to:
            - namespaceSelector: {}
              podSelector:
                matchLabels:
                  component: apiserver
          ports:
            - protocol: TCP
              port: 443
```

**Complexity:** Moderate (requires knowing Vault namespace + testing)

---

### P1-6: No Graceful Shutdown Configuration

**File:** `values.yaml`

**Issue:**
While the webapp chart has `lifecycle.preStop` support, it's not optimally configured for an operator that may be processing ConfigMaps.

**Impact:**
- In-flight ConfigMap processing may be interrupted
- Vault operations may be left incomplete
- Potential for partial role/policy creation
- Increased error rates during rolling updates

**Recommended Fix:**
Configure appropriate graceful shutdown:
```yaml
innago-webapp:
  lifecycle:
    terminationGracePeriodSeconds: 60  # Give operator time to finish work
    preStop:
      enabled: true
      sleepSeconds: 10  # Allow time for deregistration + work completion
```

Ensure operator application:
1. Handles SIGTERM gracefully
2. Stops accepting new work
3. Completes in-flight operations (with timeout)
4. Releases leader election lease
5. Exits cleanly

**Complexity:** Moderate (requires application-side handling + config)

---

### P1-7: Chart Description is Generic

**File:** `Chart.yaml` (Line 3)

**Issue:**
```yaml
description: A Helm chart for Kubernetes
```

This is the default boilerplate description and provides no information about what this chart actually does.

**Impact:**
- Users don't understand chart purpose from `helm search`
- Poor discoverability in Helm repositories
- Looks unprofessional
- No SEO for chart registry searches

**Recommended Fix:**
```yaml
description: Kubernetes operator that automatically creates Vault roles and policies for service accounts by watching annotated ConfigMaps
```

**Complexity:** Simple (Chart.yaml only)

---

### P1-8: README Badges are Incorrect

**File:** `README.md` (Line 3)

**Issue:**
```markdown
![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)
![AppVersion: 1.16.0](https://img.shields.io/badge/AppVersion-1.16.0-informational?style=flat-square)
```

But `Chart.yaml` shows:
```yaml
version: 0.1.1
appVersion: "0.1.1"
```

Badges are outdated and incorrect.

**Impact:**
- Misleading documentation
- Users may install wrong version
- Loss of trust in documentation quality

**Recommended Fix:**
Regenerate README with `helm-docs`:
```bash
cd /Volumes/Repos/helm-charts/charts/innago-vault-k8s-role-operator
helm-docs
```

Or manually update badges to match Chart.yaml.

Add CI check to ensure README stays in sync (see P2-10).

**Complexity:** Simple (regenerate with helm-docs)

---

## Priority 2 (Medium Priority) - Enhanced Features & Documentation

### P2-1: No Usage Examples in README

**File:** `README.md`

**Issue:**
The README is auto-generated and only contains the values table. No examples of how to:
- Install the chart
- Configure for different environments
- Create ConfigMaps that trigger operator
- Verify operator is working

**Impact:**
- Steep learning curve for new users
- Increased support burden
- Users may misconfigure critical settings
- No self-service troubleshooting

**Recommended Fix:**
Add sections to README.md:

```markdown
## Installation

### Prerequisites
- Kubernetes 1.27+
- Helm 3.8+
- Vault 1.12+ installed in cluster
- vault-secrets-webhook or similar Vault integration

### Quick Start

```bash
# Add repository
helm repo add innago https://ghcr.io/innago-property-management/helm-charts

# Install operator
helm install vault-operator innago/innago-vault-k8s-role-operator \
  --namespace vault-system \
  --set vault.address="https://vault.vault-system.svc:8200" \
  --set vault.tlsSecret="vault-tls"
```

### Configuration Examples

#### Development Environment
```yaml
vault:
  address: "https://vault.default.svc:8200"
  tlsSecret: "vault-tls"

innago-webapp:
  replicaCount: 1
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi
```

#### Production Environment
```yaml
vault:
  address: "https://vault.vault-system.svc.cluster.local:8200"
  tlsSecret: "vault-tls-prod"

innago-webapp:
  replicaCount: 2
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 4

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

  networkPolicy:
    enabled: true

  metrics:
    serviceMonitor:
      enabled: true
```

### Using the Operator

Create a ConfigMap to trigger Vault role creation:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-vault-config
  namespace: my-app
  annotations:
    innago.com/vault-k8s-role: ""
data:
  serviceAccountName: "my-app-sa"
  additionalPolicies: "database-reader,rabbitmq-publisher"
```

The operator will:
1. Watch for ConfigMaps with `innago.com/vault-k8s-role` annotation
2. Create a Vault policy for the namespace
3. Create a Vault Kubernetes auth role
4. Bind the role to the service account

### Troubleshooting

Check operator logs:
```bash
kubectl logs -n vault-system -l app.kubernetes.io/name=innago-vault-k8s-role-operator --tail=100
```

Verify operator is leader:
```bash
kubectl get lease -n vault-system innago-vault-k8s-role-operator-leader -o yaml
```

Check metrics:
```bash
kubectl port-forward -n vault-system svc/innago-vault-k8s-role-operator 8080:80
curl localhost:8080/metrics
```
```

**Complexity:** Moderate (documentation effort)

---

### P2-2: No Version Compatibility Matrix

**File:** `README.md`

**Issue:**
No documentation of which Kubernetes versions, Vault versions, or Helm versions are supported.

**Impact:**
- Users waste time with incompatible versions
- Support burden for version-related issues
- No clear upgrade path

**Recommended Fix:**
Add to README.md:

```markdown
## Compatibility

| Component | Version Required | Notes |
|-----------|-----------------|-------|
| Kubernetes | 1.27+ | Uses `unhealthyPodEvictionPolicy` (K8s 1.26+) |
| Helm | 3.8+ | OCI registry support required |
| Vault | 1.12+ | Kubernetes auth engine required |
| vault-secrets-webhook | Any | Bank-Vaults webhook for secret injection |

### Kubernetes Version-Specific Features

- **1.27+**: PodDisruptionBudget `matchLabelKeys` support
- **1.26+**: `unhealthyPodEvictionPolicy` support
- **1.25+**: Topology spread constraints enhancements
```

**Complexity:** Simple (documentation only)

---

### P2-3: Missing RBAC Documentation

**File:** `README.md`

**Issue:**
No documentation explaining what RBAC permissions the operator requires and why.

**Impact:**
- Security teams cannot audit permissions
- Unclear if permissions are appropriate
- Difficult to implement least-privilege adjustments

**Recommended Fix:**
Add to README.md:

```markdown
## RBAC Permissions

The operator requires the following cluster-level permissions:

| Resource | Verbs | Reason |
|----------|-------|--------|
| `serviceaccounts` | `list`, `get`, `watch` | Validate service accounts in ConfigMaps |
| `namespaces` | `list`, `get`, `watch` | Namespace-scoped policy creation |
| `configmaps` | `*` (all) | Primary operator resource - watch and update status |
| `leases` (coordination.k8s.io) | `*` (all) | Leader election coordination |

### Security Considerations

- The operator does NOT require access to Secrets
- Vault credentials are injected via vault-secrets-webhook annotations
- ClusterRole is required because operator manages roles across namespaces
- Consider using namespace-scoped Role if operating in single namespace

### Restricting to Specific Namespaces

If you only need the operator to watch specific namespaces, modify the ClusterRole to use namespace-scoped Roles:

```yaml
# Instead of ClusterRole, create Role in each namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: vault-operator
  namespace: my-app-namespace
rules:
  - verbs: ["*"]
    resources: ["configmaps"]
    apiGroups: [""]
```
```

**Complexity:** Simple (documentation only)

---

### P2-4: No Health Check Documentation

**File:** `README.md`, `NOTES.txt`

**Issue:**
`NOTES.txt` just says "TODO". No guidance on verifying operator health or functionality.

**Impact:**
- Users don't know if installation succeeded
- No clear success criteria
- Difficult to troubleshoot

**Recommended Fix:**
Update `templates/NOTES.txt`:

```
Thank you for installing {{ .Chart.Name }}!

The Vault Kubernetes Role Operator has been deployed.

1. Check operator status:

   kubectl get pods -n {{ .Release.Namespace }} -l app.kubernetes.io/name={{ include "innago-vault-k8s-role-operator.name" . }}

2. View operator logs:

   kubectl logs -n {{ .Release.Namespace }} -l app.kubernetes.io/name={{ include "innago-vault-k8s-role-operator.name" . }} --tail=50

3. Verify leader election (if running multiple replicas):

   kubectl get lease -n {{ .Release.Namespace }} {{ include "innago-vault-k8s-role-operator.fullname" . }}-leader -o yaml

4. Test the operator by creating a ConfigMap:

   kubectl apply -f - <<EOF
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: test-vault-role
     namespace: {{ .Release.Namespace }}
     annotations:
       innago.com/vault-k8s-role: ""
   data:
     serviceAccountName: "default"
     additionalPolicies: ""
   EOF

5. Check operator logs for processing:

   kubectl logs -n {{ .Release.Namespace }} -l app.kubernetes.io/name={{ include "innago-vault-k8s-role-operator.name" . }} --tail=20 | grep test-vault-role

{{- if .Values.metrics.serviceMonitor.enabled }}

6. Access metrics:

   kubectl port-forward -n {{ .Release.Namespace }} svc/{{ include "innago-vault-k8s-role-operator.fullname" . }} 8080:80
   curl http://localhost:8080/metrics
{{- end }}

For more information, see the chart README:
https://github.com/innago-property-management/helm-charts/tree/main/charts/innago-vault-k8s-role-operator
```

**Complexity:** Simple (template update)

---

### P2-5: Missing Upgrade Notes

**File:** `README.md`

**Issue:**
No documentation on how to upgrade the operator or what breaking changes to watch for.

**Impact:**
- Risky upgrades
- Users may unknowingly break production
- No migration path for configuration changes

**Recommended Fix:**
Add to README.md:

```markdown
## Upgrading

### From 0.1.x to 0.2.x (Future)

TBD - will be documented when breaking changes are introduced.

### Best Practices for Upgrades

1. **Review Release Notes**: Always check GitHub releases for breaking changes
2. **Test in Non-Production**: Upgrade dev/staging environments first
3. **Backup Configuration**: Save current values with `helm get values`
4. **Use `--dry-run`**: Preview changes before applying
5. **Monitor Metrics**: Watch operator metrics during and after upgrade

### Upgrade Command

```bash
# Get current values
helm get values vault-operator -n vault-system > current-values.yaml

# Upgrade with your values
helm upgrade vault-operator innago/innago-vault-k8s-role-operator \
  --namespace vault-system \
  --values current-values.yaml \
  --version 0.1.1
```

### Rollback

If issues occur, rollback to previous version:

```bash
helm rollback vault-operator -n vault-system
```
```

**Complexity:** Simple (documentation only)

---

### P2-6: No Prometheus Alerts Examples

**File:** `README.md` or separate `examples/` directory

**Issue:**
If metrics are exposed (P1-3), there should be example Prometheus alerts for common operator issues.

**Impact:**
- Users don't know what to alert on
- No proactive issue detection
- Increased MTTR (Mean Time To Resolution)

**Recommended Fix:**
Create `examples/prometheus-alerts.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: vault-operator-alerts
  namespace: vault-system
  labels:
    prometheus: kube-prometheus
spec:
  groups:
    - name: vault-operator
      interval: 30s
      rules:
        - alert: VaultOperatorDown
          expr: up{job="innago-vault-k8s-role-operator"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Vault operator is down"
            description: "No vault operator pods are reachable for {{ $labels.namespace }}"

        - alert: VaultOperatorNoLeader
          expr: vault_operator_leader != 1
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "Vault operator has no leader"
            description: "Leader election may be failing"

        - alert: VaultOperatorHighErrorRate
          expr: rate(vault_role_operations_total{status="failure"}[5m]) > 0.1
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "High error rate in vault operations"
            description: "Vault operator is failing {{ $value }} operations/sec"

        - alert: VaultOperatorSlowProcessing
          expr: histogram_quantile(0.99, rate(vault_configmap_processing_duration_seconds_bucket[5m])) > 30
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Vault operator processing is slow"
            description: "P99 processing time is {{ $value }}s"
```

Document in README.md:

```markdown
## Monitoring & Alerting

Example Prometheus alerts are available in `examples/prometheus-alerts.yaml`.

Apply with:
```bash
kubectl apply -f examples/prometheus-alerts.yaml
```

Recommended alerts:
- **VaultOperatorDown**: No operator pods available (critical)
- **VaultOperatorNoLeader**: Leader election failure (warning)
- **VaultOperatorHighErrorRate**: Vault operation failures (warning)
- **VaultOperatorSlowProcessing**: Long processing times (warning)
```

**Complexity:** Moderate (requires metrics design + alert tuning)

---

### P2-7: No ConfigMap Annotation Documentation

**File:** `README.md`

**Issue:**
The core functionality (watching ConfigMaps with specific annotations) is not well documented. Users need to understand:
- Which annotation triggers the operator
- What data fields are required
- What additionalPolicies format is expected

**Impact:**
- Users don't know how to use the operator
- Trial-and-error configuration
- Increased support burden

**Recommended Fix:**
Add to README.md:

```markdown
## ConfigMap Format

The operator watches for ConfigMaps with the annotation `innago.com/vault-k8s-role: ""`.

### Required Fields

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <app-name>-vault-config
  namespace: <app-namespace>
  annotations:
    innago.com/vault-k8s-role: ""  # This triggers the operator
    argocd.argoproj.io/sync-options: ServerSideApply=true  # If using ArgoCD
data:
  serviceAccountName: "<service-account-name>"  # Required
  additionalPolicies: "<policy1>,<policy2>"     # Optional, comma-separated
```

### Field Descriptions

| Field | Required | Format | Description |
|-------|----------|--------|-------------|
| `serviceAccountName` | Yes | String | Name of ServiceAccount to bind Vault role to |
| `additionalPolicies` | No | CSV | Comma-separated list of additional Vault policies |

### Examples

#### Basic: Single namespace policy
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-vault
  namespace: my-app
  annotations:
    innago.com/vault-k8s-role: ""
data:
  serviceAccountName: "my-app-sa"
  additionalPolicies: ""
```

This creates:
- Vault policy: `my-app-namespace-policy`
- Vault role: `my-app-namespace-role`
- Binds role to `my-app/my-app-sa` service account

#### Advanced: With database access
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-vault
  namespace: my-app
  annotations:
    innago.com/vault-k8s-role: ""
data:
  serviceAccountName: "my-app-sa"
  additionalPolicies: "postgres-readonly,redis-access"
```

This creates same policy/role as above, plus attaches:
- `postgres-readonly` policy
- `redis-access` policy

### Validation

The operator validates:
- ✅ ServiceAccount exists in the same namespace
- ✅ Additional policies exist in Vault (if specified)
- ✅ ConfigMap is in a namespace (not cluster-scoped)

Invalid ConfigMaps are logged but do not crash the operator.
```

**Complexity:** Simple (documentation only)

---

### P2-8: No Development/Contributing Guide

**File:** `CONTRIBUTING.md` or `README.md`

**Issue:**
No guidance for developers who want to:
- Modify the chart
- Test locally
- Contribute improvements

**Impact:**
- Difficult for others to contribute
- No standardized development workflow
- Quality variations in contributions

**Recommended Fix:**
Add to README.md:

```markdown
## Development

### Prerequisites
- Kubernetes cluster (kind, minikube, or k3d)
- Helm 3.8+
- kubectl
- [helm-docs](https://github.com/norwoodj/helm-docs) for regenerating README

### Local Testing

1. **Install dependencies:**
   ```bash
   helm dependency update
   ```

2. **Lint the chart:**
   ```bash
   helm lint .
   ```

3. **Template and review:**
   ```bash
   helm template test-release . --values values.yaml > output.yaml
   ```

4. **Install to local cluster:**
   ```bash
   helm install test-release . \
     --namespace vault-system \
     --create-namespace \
     --set vault.address="https://vault.default.svc:8200"
   ```

5. **Run tests:**
   ```bash
   helm test test-release -n vault-system
   ```

### Making Changes

1. Update chart templates or values
2. Regenerate README: `helm-docs`
3. Update Chart.yaml version (follow SemVer)
4. Test installation on local cluster
5. Submit pull request

### Versioning

This chart follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Incompatible API changes
- **MINOR**: Backwards-compatible functionality additions
- **PATCH**: Backwards-compatible bug fixes

### Release Process

1. Update `Chart.yaml` version
2. Update `CHANGELOG.md`
3. Regenerate docs: `helm-docs`
4. Tag release: `git tag v0.1.1`
5. Push: `git push --tags`
6. CI/CD publishes to chart repository
```

**Complexity:** Simple (documentation only)

---

### P2-9: Missing CHANGELOG

**File:** `CHANGELOG.md`

**Issue:**
No changelog to track changes between versions.

**Impact:**
- Users don't know what changed
- Difficult to assess upgrade risk
- No historical record of fixes/features

**Recommended Fix:**
Create `CHANGELOG.md`:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- TBD

## [0.1.1] - 2025-08-25

### Changed
- Updated webapp subchart dependency to 2.4.0
- Updated ConfigMap naming to include random suffix for ArgoCD compatibility

### Fixed
- Added ArgoCD sync annotation to ConfigMap template

## [0.1.0] - 2025-08-XX

### Added
- Initial release of innago-vault-k8s-role-operator chart
- ClusterRole and ClusterRoleBinding for operator RBAC
- Integration with webapp subchart for deployment
- Support for Vault Kubernetes auth backend
- ConfigMap-based operator triggering
- Leader election support via leases
- PodDisruptionBudget configuration
- Topology spread constraints

[Unreleased]: https://github.com/innago-property-management/helm-charts/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/innago-property-management/helm-charts/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/innago-property-management/helm-charts/releases/tag/v0.1.0
```

**Complexity:** Simple (documentation only)

---

### P2-10: No CI/CD Validation

**File:** `.github/workflows/` or similar CI config

**Issue:**
No automated checks for:
- Helm linting
- Template rendering
- README sync with values
- RBAC validation

**Impact:**
- Breaking changes may merge undetected
- Documentation drift
- Manual testing burden

**Recommended Fix:**
Create `.github/workflows/chart-test.yaml` (if using GitHub Actions):

```yaml
name: Lint and Test Charts

on:
  pull_request:
    paths:
      - 'charts/innago-vault-k8s-role-operator/**'

jobs:
  lint-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Helm
        uses: azure/setup-helm@v4
        with:
          version: v3.14.0

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install chart-testing
        uses: helm/chart-testing-action@v2.6.1

      - name: Run chart-testing (lint)
        run: ct lint --charts charts/innago-vault-k8s-role-operator

      - name: Install helm-docs
        run: |
          cd /tmp
          wget https://github.com/norwoodj/helm-docs/releases/download/v1.14.2/helm-docs_1.14.2_Linux_x86_64.tar.gz
          tar -xvf helm-docs_1.14.2_Linux_x86_64.tar.gz
          sudo mv helm-docs /usr/local/bin/

      - name: Verify README is up to date
        run: |
          cd charts/innago-vault-k8s-role-operator
          helm-docs
          git diff --exit-code README.md || (echo "README.md is out of sync. Run 'helm-docs' and commit." && exit 1)

      - name: Create kind cluster
        uses: helm/kind-action@v1.10.0

      - name: Run chart-testing (install)
        run: ct install --charts charts/innago-vault-k8s-role-operator
```

**Complexity:** Moderate (requires CI/CD setup)

---

### P2-11: No Security Context for Init Containers

**File:** `values.yaml` (webapp subchart)

**Issue:**
While the main container has security context configured, if the webapp chart uses init containers (e.g., for migrations), their security context may not be set.

**Impact:**
- Init containers may run as root unnecessarily
- Security policy violations
- Increased attack surface

**Recommended Fix:**
Verify webapp subchart sets security context for all init containers. If not, override:

```yaml
innago-webapp:
  # If webapp chart supports init container security context
  initContainerSecurityContext:
    runAsUser: 10001
    runAsGroup: 10001
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
    capabilities:
      drop:
        - ALL
```

Note: This depends on webapp chart supporting this configuration.

**Complexity:** Simple if supported, Moderate if webapp chart needs updating

---

## Priority 3 (Low Priority) - Nice-to-Haves

### P3-1: No Helm Test

**File:** `templates/tests/` directory

**Issue:**
No Helm test to validate operator deployment. The tests directory appears to be empty or minimal.

**Impact:**
- Cannot run `helm test` to verify installation
- No automated post-install validation
- Manual verification required

**Recommended Fix:**
Create `templates/tests/test-operator-connection.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "innago-vault-k8s-role-operator.fullname" . }}-test-connection"
  labels:
    {{- include "innago-vault-k8s-role-operator.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['{{ include "innago-vault-k8s-role-operator.fullname" . }}:80/healthz']
  restartPolicy: Never
```

**Complexity:** Simple (single test template)

---

### P3-2: No Values Schema

**File:** `values.schema.json`

**Issue:**
Helm 3 supports JSON schema validation for values.yaml, but no schema is provided.

**Impact:**
- No type checking on user-provided values
- Users may set invalid values (e.g., strings where ints expected)
- Errors only discovered at runtime

**Recommended Fix:**
Create `values.schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "vault": {
      "type": "object",
      "required": ["address"],
      "properties": {
        "address": {
          "type": "string",
          "pattern": "^https?://",
          "description": "Vault server address"
        },
        "tlsSecret": {
          "type": "string",
          "description": "Name of secret containing Vault TLS certificate"
        }
      }
    },
    "serviceAccount": {
      "type": "object",
      "properties": {
        "create": {
          "type": "boolean"
        },
        "name": {
          "type": "string"
        }
      }
    }
  }
}
```

**Complexity:** Moderate (requires understanding JSON Schema)

---

### P3-3: No Support for Custom Labels

**File:** `values.yaml`

**Issue:**
No way to add custom labels to all resources (for organization tracking, cost allocation, etc.).

**Impact:**
- Cannot implement company-wide labeling standards
- Difficult to track resources for billing/reporting
- No support for GitOps labels

**Recommended Fix:**
Add to `values.yaml`:

```yaml
# -- Additional labels to add to all resources
commonLabels: {}
  # team: platform
  # cost-center: engineering
  # environment: production
```

Update `_helpers.tpl`:

```yaml
{{- define "innago-vault-k8s-role-operator.labels" -}}
helm.sh/chart: {{ include "innago-vault-k8s-role-operator.chart" . }}
{{ include "innago-vault-k8s-role-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}
```

**Complexity:** Simple (template changes)

---

### P3-4: No Support for Pod Priority Class

**File:** `values.yaml`

**Issue:**
No way to set priority class for operator pods. In production, operators often need higher priority than regular workloads to ensure they keep running during resource pressure.

**Impact:**
- Operator may be evicted during node pressure
- Cannot prioritize critical infrastructure components
- May lose operator during cluster scaling events

**Recommended Fix:**
Add to `values.yaml`:

```yaml
innago-webapp:
  # -- Priority class for operator pods (ensures operator stays running during pressure)
  priorityClassName: "system-cluster-critical"  # or "system-node-critical" or custom class
```

Verify webapp chart supports `priorityClassName`. If not, this requires webapp chart update.

**Complexity:** Simple if webapp supports it, Moderate otherwise

---

### P3-5: No Affinity Rules for Operator

**File:** `values.yaml`

**Issue:**
No affinity rules configured. For operators, it's often desirable to spread replicas across nodes/zones.

**Impact:**
- Both replicas may land on same node (reduced HA)
- No zone-awareness for multi-zone clusters
- Increased risk during node failures

**Recommended Fix:**
Topology spread constraints are already configured (good!), but could add pod anti-affinity as well:

```yaml
innago-webapp:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app.kubernetes.io/name: innago-vault-k8s-role-operator
            topologyKey: kubernetes.io/hostname
```

However, topology spread constraints (already configured) are generally better for modern Kubernetes. This is optional.

**Complexity:** Simple (values.yaml only)

---

### P3-6: No Support for External Secrets Operator

**File:** `values.yaml`, templates

**Issue:**
Chart assumes vault-secrets-webhook (Bank-Vaults) for secret injection. Some organizations use External Secrets Operator instead.

**Impact:**
- Limited compatibility with other secret management approaches
- Chart locked into specific secret management tool

**Recommended Fix:**
Document alternative approaches in README.md:

```markdown
## Alternative Secret Management

### Using External Secrets Operator

If you use External Secrets Operator instead of vault-secrets-webhook:

1. Create ExternalSecret for Vault token:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: vault-operator-token
  namespace: vault-system
spec:
  secretStoreRef:
    name: vault-secret-store
    kind: ClusterSecretStore
  target:
    name: vault-token
  data:
    - secretKey: token
      remoteRef:
        key: secret/vault-operator
        property: token
```

2. Mount secret in operator deployment (requires webapp chart modification or override)

Or, for full compatibility, add to `values.yaml`:

```yaml
# -- Secret management configuration
secretManagement:
  # -- Type of secret management: "vault-webhook" or "external-secrets"
  type: "vault-webhook"

  # -- For External Secrets Operator
  externalSecrets:
    enabled: false
    secretStoreName: "vault-secret-store"
    vaultPath: "secret/vault-operator"
```

**Complexity:** Moderate (requires template logic for different secret management types)

---

### P3-7: No Kustomize Support

**File:** Root of chart or `kustomization.yaml`

**Issue:**
Some users prefer Kustomize over Helm. No kustomization.yaml is provided.

**Impact:**
- Kustomize users must convert chart manually
- No GitOps-friendly plain YAML option

**Recommended Fix:**
Provide pre-rendered examples in `examples/kustomize/`:

```bash
mkdir -p examples/kustomize
helm template vault-operator . > examples/kustomize/all-resources.yaml
```

Create `examples/kustomize/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - all-resources.yaml

# Users can overlay their customizations
namespace: vault-system

commonLabels:
  app: vault-operator

# Example patches
patchesStrategicMerge:
  - |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: innago-vault-k8s-role-operator
    spec:
      replicas: 3
```

Document in README.md that this is for reference only and may become outdated.

**Complexity:** Simple (generate examples)

---

### P3-8: No OpenTelemetry Trace Support

**File:** `values.yaml`

**Issue:**
No support for distributed tracing (OpenTelemetry). Modern operators benefit from trace context propagation.

**Impact:**
- Cannot trace requests across operator → Vault → Kubernetes API
- Difficult to debug performance issues
- No visibility into operation latency breakdown

**Recommended Fix:**
Add to `values.yaml`:

```yaml
innago-webapp:
  containerEnvironmentVariables:
    # OpenTelemetry configuration
    - name: OTEL_EXPORTER_OTLP_ENDPOINT
      value: "http://otel-collector.observability.svc:4317"
    - name: OTEL_SERVICE_NAME
      value: "vault-k8s-role-operator"
    - name: OTEL_TRACES_ENABLED
      value: "true"
```

Requires operator application to use OpenTelemetry SDK.

**Complexity:** Moderate (requires application instrumentation)

---

### P3-9: No Mutation Webhook for Validation

**File:** Templates for ValidatingWebhookConfiguration

**Issue:**
No validation webhook to validate ConfigMaps before they're created. Users may create invalid ConfigMaps that silently fail.

**Impact:**
- Invalid ConfigMaps are only detected in operator logs
- No fast-fail for user errors
- Difficult to debug why ConfigMap isn't processed

**Recommended Fix:**
This is a significant feature requiring:
1. ValidatingWebhookConfiguration template
2. Webhook server in operator application
3. TLS certificate management (cert-manager)
4. Validation logic

Example structure:
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: vault-operator-webhook
  annotations:
    cert-manager.io/inject-ca-from: vault-system/vault-operator-webhook-cert
webhooks:
  - name: configmap.vault.innago.com
    rules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["configmaps"]
    clientConfig:
      service:
        name: vault-operator-webhook
        namespace: vault-system
        path: /validate
    admissionReviewVersions: ["v1"]
    sideEffects: None
```

**Complexity:** Complex (significant feature addition)

---

### P3-10: No Horizontal Pod Autoscaler Configuration

**File:** `values.yaml`

**Issue:**
HPA is supported by webapp subchart but not configured or documented for operator use case.

**Impact:**
- Manual scaling only
- Cannot handle load spikes (many ConfigMap changes)
- Wasted resources during low activity

**Recommended Fix:**
Add configuration and documentation:

```yaml
innago-webapp:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 4
    targetCPUUtilizationPercentage: 80
    # Custom metrics (requires metrics-server + custom metrics)
    # targetMemoryUtilizationPercentage: 80
```

Document in README.md when HPA makes sense:
- Large clusters with many namespaces
- Frequent ConfigMap changes
- Multiple teams creating workloads

**Complexity:** Simple (values.yaml + documentation)

---

## Summary Statistics

| Priority | Count | Description |
|----------|-------|-------------|
| **P0** | 6 | Critical production blockers requiring immediate attention |
| **P1** | 8 | High-priority production readiness gaps |
| **P2** | 11 | Medium-priority enhancements and documentation |
| **P3** | 10 | Low-priority nice-to-haves and optimizations |
| **Total** | **35** | Total issues identified |

---

## Recommended Implementation Order

### Phase 1: Production Blockers (Before ANY production deployment)
1. **P0-1**: Fix RBAC overpermissions (CRITICAL SECURITY)
2. **P0-2**: Add resource limits
3. **P0-3**: Add startup probe
4. **P0-4**: Make Vault address configurable
5. **P0-5**: Document/configure leader election
6. **P0-6**: Add fail-fast validation

**Estimated Effort:** 8-13 complexity points (1-2 days for experienced Helm developer)

### Phase 2: Production Readiness (Before wide adoption)
1. **P1-1**: Fix PodDisruptionBudget
2. **P1-3**: Enable metrics & ServiceMonitor
3. **P1-4**: Configure replica count for HA
4. **P1-5**: Enable NetworkPolicy
5. **P1-6**: Configure graceful shutdown
6. **P1-8**: Fix README badges
7. **P2-1**: Add usage examples to README

**Estimated Effort:** 13-21 complexity points (2-3 days)

### Phase 3: Documentation & Polish (For maintainability)
1. **P2-2 through P2-9**: Complete documentation suite
2. **P2-10**: Add CI/CD validation
3. **P3-1**: Add Helm test

**Estimated Effort:** 8-13 complexity points (1-2 days)

### Phase 4: Advanced Features (Optional, as needed)
1. **P3-2 through P3-10**: Nice-to-have features based on user feedback

**Estimated Effort:** Variable (21+ points, 3-5 days depending on scope)

---

## Comparison with Reference Charts

### vs. valkey-cluster Chart
The valkey-cluster chart demonstrates these production patterns that operator chart lacks:
- ✅ Comprehensive resource limits
- ✅ Detailed metrics with ServiceMonitor
- ✅ Network policy templates
- ✅ Sophisticated lifecycle hooks
- ✅ Startup probes
- ✅ Extensive documentation
- ✅ Validation logic in templates

### vs. webapp Chart
The webapp chart (used as dependency) provides:
- ✅ Good security context defaults
- ✅ PDB support (though misconfigured in operator values)
- ✅ Topology spread constraints
- ✅ Graceful shutdown hooks
- ✅ Checksum annotations for config changes
- ✅ Network policy support

The operator chart should leverage these capabilities better through proper values configuration.

---

## Conclusion

The innago-vault-k8s-role-operator chart has a solid foundation by leveraging the webapp subchart, but requires significant hardening before production use. The most critical issues are:

1. **Overly permissive RBAC** (P0-1) - immediate security risk
2. **Missing resource limits** (P0-2) - stability risk
3. **Hardcoded Vault address** (P0-4) - portability blocker
4. **Lack of observability** (P1-3) - operational blind spot

Addressing the Phase 1 (P0) issues is mandatory before any production deployment. Phase 2 (P1) issues should be resolved before considering the chart "production-ready" for general use.

The chart shows good architectural decisions (using webapp subchart, ClusterRole for cross-namespace operation, leader election preparation), but needs configuration refinement and documentation to reach production quality comparable to the valkey-cluster reference chart.
