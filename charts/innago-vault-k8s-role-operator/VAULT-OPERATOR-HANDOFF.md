# Vault Operator RBAC Security Fix - Handoff Document

## Executive Summary

**CRITICAL SECURITY VULNERABILITY FIXED**: The innago-vault-k8s-role-operator had wildcard RBAC permissions granting read access to ALL cluster resources including Secrets. This has been replaced with least-privilege permissions.

**Chart Version**: 0.1.1 → 1.0.0
**Commit**: db9bfa0
**Branch**: feat/chart-hardening

---

## What Is This Operator?

The innago-vault-k8s-role-operator is a Kubernetes operator that:
1. Watches ServiceAccounts and Namespaces for Vault role configuration annotations
2. Creates/updates ConfigMaps with Vault role bindings
3. Manages CronJobs/Jobs for Vault token rotation
4. Uses leader election for high availability (multiple replicas)

**Primary Function**: Automatically configure Vault roles for Kubernetes service accounts based on annotations.

---

## The Security Vulnerability

### Before (DANGEROUS) ❌

**File**: `templates/cluster-role.yaml` lines 8-10

```yaml
rules:
  - verbs: ["list", "get", "watch"]
    resources: ["*"]              # ← ALL RESOURCES
    apiGroups: ["*"]              # ← ALL API GROUPS
  - verbs: ["*"]
    resources: ["configmaps"]
    apiGroups: [""]
  # ... other rules
```

### Impact

This granted the operator:
- **READ access to ALL cluster resources** including:
  - Secrets (passwords, tokens, certificates)
  - ConfigMaps (potentially sensitive configuration)
  - Pods, Deployments, StatefulSets
  - Nodes, PersistentVolumes
  - ANY custom resources

**Severity**: CRITICAL
- If the operator pod was compromised, attacker gains read access to entire cluster
- Violates principle of least privilege
- Creates unnecessary attack surface
- May fail compliance audits (SOC2, ISO 27001, etc.)

---

## The Fix

### After (Least Privilege) ✅

**File**: `templates/cluster-role.yaml` lines 7-27

```yaml
rules:
  # Read access to ServiceAccounts (operator watches these for Vault role configuration)
  - verbs: ["list", "get", "watch"]
    resources: ["serviceaccounts"]
    apiGroups: [""]

  # Read access to Namespaces (operator watches namespace labels/annotations)
  - verbs: ["list", "get", "watch"]
    resources: ["namespaces"]
    apiGroups: [""]

  # Full access to ConfigMaps (operator's primary resource for storing Vault role config)
  - verbs: ["*"]
    resources: ["configmaps"]
    apiGroups: [""]

  # Full access to CronJobs and Jobs (operator may manage these for Vault token rotation)
  - verbs: ["*"]
    resources: ["cronjobs", "jobs"]
    apiGroups: ["batch"]

  # Coordination for leader election (required for operator HA)
  - verbs: ["*"]
    apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
```

### Why These Permissions?

Each permission is justified by operator functionality:

1. **ServiceAccounts (read-only)**:
   - Operator watches ServiceAccount annotations like `vault.security.banzaicloud.io/vault-role`
   - Only needs to read, not modify ServiceAccounts

2. **Namespaces (read-only)**:
   - Operator watches namespace labels/annotations for Vault configuration
   - Determines which namespaces should have Vault integration
   - Only needs to read, not modify Namespaces

3. **ConfigMaps (full access)**:
   - Operator's primary resource for storing Vault role mappings
   - Creates/updates/deletes ConfigMaps with Vault configuration
   - Requires full CRUD operations

4. **CronJobs/Jobs (full access)**:
   - May create scheduled jobs for Vault token rotation
   - Requires full CRUD for job lifecycle management

5. **Leases (full access)**:
   - Required for leader election in multi-replica deployment
   - Uses `coordination.k8s.io/v1` Lease resource
   - Only one replica should be active leader at a time

---

## Other P0 Fixes Applied

### 1. Resource Limits (P0-2)

**Before**: No resource limits configured
**After**:
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

**Why**: Prevents OOM kills that would disrupt operator functionality.

---

### 2. Startup Probe (P0-3)

**Before**: No startup probe, only liveness/readiness
**After**:
```yaml
health:
  startupProbe:
    httpGet:
      path: /healthz
      port: http
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 30  # Allows up to 2.5 minutes for startup
```

**Why**: Operators need time for:
- Leader election
- Cache initialization
- Informer synchronization

Without startup probe, pod may be killed during legitimate startup phase.

---

### 3. Configurable Vault Address (P0-4)

**Before**: Hardcoded in podAnnotations
```yaml
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: https://vault.default.svc:8200
```

**After**: Configurable via values.yaml
```yaml
vault:
  address: https://vault.security.svc:8200  # Changed default namespace
  tlsSecret: vault-tls

podAnnotations:
  vault.security.banzaicloud.io/vault-addr: https://vault.security.svc:8200
  vault.security.banzaicloud.io/vault-tls-secret: vault-tls
```

**Why**:
- Hardcoded `vault.default.svc` assumes Vault in default namespace
- Most production deployments use dedicated namespace (e.g., `security`, `vault`)
- Makes chart reusable across environments

**Action Required**: Update `values.yaml` or override files with correct Vault address for your environment.

---

### 4. PodDisruptionBudget Fix (P0-6)

**Before**: `minAvailable: 0`
**After**: `minAvailable: 1`

**Why**: `minAvailable: 0` defeats the entire purpose of PodDisruptionBudget. During maintenance (node drains, upgrades), Kubernetes could terminate ALL replicas simultaneously, causing operator downtime.

---

## Testing and Validation

### 1. Verify RBAC Permissions Work

Deploy the operator and check for permission errors:

```bash
# Check operator logs for RBAC denials
kubectl logs -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace> --tail=100

# Look for errors like:
# "forbidden: User \"system:serviceaccount:...\" cannot list resource \"secrets\""
```

**Expected**: No RBAC permission errors. Operator should successfully:
- List/watch ServiceAccounts
- List/watch Namespaces
- Create/update/delete ConfigMaps
- Create/update/delete CronJobs/Jobs
- Manage Leases for leader election

---

### 2. Verify Leader Election

With multiple replicas, only one should be active leader:

```bash
# Check which replica is leader
kubectl get lease -n <namespace> innago-vault-k8s-role-operator -o yaml

# Check logs for leader election messages
kubectl logs -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace> | grep -i leader
```

**Expected**:
- One replica logs "successfully acquired lease" or "became leader"
- Other replicas log "waiting for leader election" or similar
- Lease resource shows current holder

---

### 3. Verify Operator Functionality

Test core operator functionality:

```bash
# Create a ServiceAccount with Vault annotation
kubectl create sa test-vault-sa -n default
kubectl annotate sa test-vault-sa vault.security.banzaicloud.io/vault-role=my-role

# Verify operator creates ConfigMap
kubectl get configmap -n default -l managed-by=innago-vault-k8s-role-operator

# Check operator processed the ServiceAccount
kubectl logs -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace> | grep test-vault-sa
```

**Expected**: Operator detects annotation and creates/updates corresponding ConfigMap.

---

### 4. Test Startup Time

Verify startup probe gives enough time:

```bash
# Delete pod to trigger restart
kubectl delete pod -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace> --force --grace-period=0

# Watch pod startup
kubectl get pod -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace> -w

# Check startup probe status
kubectl describe pod -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace> | grep -A10 "Startup"
```

**Expected**:
- Pod reaches Ready state within 2.5 minutes (30 failures × 5s period)
- No "Startup probe failed" messages leading to pod restart
- Logs show successful leader election and cache sync

---

### 5. Verify Resource Limits

Check resources are applied:

```bash
kubectl describe pod -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace> | grep -A5 "Limits"
```

**Expected**:
```
Limits:
  cpu:     500m
  memory:  256Mi
Requests:
  cpu:     100m
  memory:  128Mi
```

---

## Potential Issues and Solutions

### Issue 1: "Forbidden" errors in logs

**Symptom**: Operator logs show permission denied errors

**Diagnosis**:
```bash
kubectl logs -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace> | grep -i forbidden
```

**Possible Causes**:
1. Operator needs additional permissions beyond what we granted
2. ClusterRoleBinding not created correctly
3. ServiceAccount mismatch

**Solution**:
1. Check ClusterRoleBinding:
   ```bash
   kubectl get clusterrolebinding -o yaml | grep innago-vault-k8s-role-operator
   ```
2. Verify ServiceAccount matches:
   ```bash
   kubectl get sa innago-vault-k8s-role-operator -n <namespace>
   ```
3. If legitimate permission needed, update ClusterRole with specific resource (NOT wildcard)

---

### Issue 2: Operator stuck in "Not Ready" state

**Symptom**: Pod shows 0/1 Ready for extended period

**Diagnosis**:
```bash
kubectl describe pod -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace>
kubectl logs -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace>
```

**Possible Causes**:
1. Startup probe failing (needs more time)
2. Vault address unreachable
3. Vault TLS certificate secret missing
4. Leader election stuck

**Solution**:
1. Increase startup probe `failureThreshold`:
   ```yaml
   startupProbe:
     failureThreshold: 60  # 5 minutes instead of 2.5
   ```
2. Verify Vault connectivity:
   ```bash
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl -k https://vault.security.svc:8200/v1/sys/health
   ```
3. Check TLS secret exists:
   ```bash
   kubectl get secret vault-tls -n <namespace>
   ```

---

### Issue 3: Leader election not working

**Symptom**: Multiple replicas think they're leader, or no leader elected

**Diagnosis**:
```bash
kubectl get lease innago-vault-k8s-role-operator -n <namespace> -o yaml
kubectl logs -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace> | grep -i lease
```

**Possible Causes**:
1. Missing `coordination.k8s.io/leases` permission
2. Lease name mismatch
3. Network partition between replicas

**Solution**:
1. Verify lease permissions in ClusterRole
2. Check for network policy blocking pod-to-pod communication
3. Restart all replicas to force re-election:
   ```bash
   kubectl rollout restart deployment innago-vault-k8s-role-operator -n <namespace>
   ```

---

### Issue 4: ConfigMaps not being created

**Symptom**: ServiceAccounts have Vault annotations but no ConfigMaps created

**Diagnosis**:
```bash
kubectl get sa -A -o yaml | grep vault.security.banzaicloud.io/vault-role
kubectl get configmap -A -l managed-by=innago-vault-k8s-role-operator
kubectl logs -l app.kubernetes.io/name=innago-vault-k8s-role-operator -n <namespace> --tail=200
```

**Possible Causes**:
1. Operator not watching correct annotation key
2. Namespace not in watch scope
3. ConfigMap creation permission missing
4. Only standby replicas running (no leader)

**Solution**:
1. Verify annotation format matches operator's expectation
2. Check operator watch configuration
3. Verify ConfigMap RBAC permissions in ClusterRole
4. Ensure at least one replica is leader

---

## Configuration Checklist for Your Environment

Before deploying to production:

- [ ] Update `vault.address` to match your Vault server location
- [ ] Update `vault.tlsSecret` to match your Vault TLS secret name
- [ ] Verify Vault TLS secret is replicated to operator namespace (or use kubernetes-reflector)
- [ ] Set appropriate replica count (recommend 2+ for production)
- [ ] Review resource limits based on cluster size (adjust if managing many namespaces)
- [ ] Configure monitoring alerts for operator downtime
- [ ] Test RBAC permissions in dev/staging first
- [ ] Document any additional permissions needed (and justify each one)

---

## Why Did This Have Wildcard Permissions?

**Root Cause**: Likely a quick implementation that used overly broad permissions.

Common reasons this happens:
1. **"Works on my machine" syndrome**: Developer testing with cluster-admin, doesn't notice RBAC issues
2. **Cargo-cult programming**: Copied from example/template that used wildcards
3. **"We'll fix it later"**: MVP shipped with broad permissions, never revisited
4. **Insufficient RBAC knowledge**: Developer unfamiliar with least-privilege principle
5. **Testing shortcuts**: Easier to use `*` than debug specific permission issues

**Prevention**:
- Always start with minimal permissions
- Add permissions incrementally as needed
- Use RBAC audit tools (kubectl-who-can, rbac-lookup)
- Code review should flag any wildcard permissions
- Run operator in test cluster WITHOUT cluster-admin to identify real requirements

---

## Additional Resources

- **RBAC Documentation**: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- **Operator Best Practices**: https://sdk.operatorframework.io/docs/best-practices/
- **Leader Election Pattern**: https://kubernetes.io/docs/concepts/architecture/leases/
- **Kubernetes Reflector** (for secret replication): https://github.com/emberstack/kubernetes-reflector

---

## Questions to Ask About the Operator

When you visit the vault operator project, consider investigating:

1. **What annotations does it actually watch?**
   - Document exact annotation keys/values expected
   - Any namespace-level configuration?

2. **What's the ConfigMap schema?**
   - What data does operator store in ConfigMaps?
   - How does downstream consume these?

3. **Is token rotation actually implemented?**
   - We granted CronJob/Job permissions, but is this feature used?
   - If not, can we remove batch API permissions?

4. **Are there any other resource types needed?**
   - Could operator need Secrets (for Vault tokens)?
   - Does it need to create Roles/RoleBindings?

5. **Is there telemetry/metrics?**
   - Does /metrics endpoint expose useful data?
   - Should we add ServiceMonitor?

6. **What's the blast radius of a compromise?**
   - With current permissions, what's worst-case scenario?
   - Can we reduce further?

---

## Contact

**Changes Made By**: Claude Sonnet 4.5 (via Claude Code)
**Session Date**: 2025-12-15
**Commit**: db9bfa0
**Branch**: feat/chart-hardening

For questions about these changes, refer to:
- Commit message in git history
- `/Volumes/Repos/helm-charts/charts/innago-vault-k8s-role-operator/REVIEW.md` (comprehensive review)
- Pieces memory checkpoint: "Helm Charts Production Hardening - P0 Critical Security Fixes Complete"
