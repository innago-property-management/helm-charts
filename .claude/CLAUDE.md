# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is Innago's Helm charts repository containing reusable Kubernetes deployment charts. Charts are packaged and published to both GitHub Releases and GHCR (GitHub Container Registry) with GPG signing via chart-releaser-action.

**Main branch:** `main` (commits are blocked via pre-commit hook)

**Available Charts:**
- `webapp` - Core chart for deploying ASP.NET web applications with Vault integration, HPA, migrations, and health checks
- `valkey-cluster` - Valkey (Redis fork) deployment supporting both cluster and standalone modes with persistence and monitoring
- `innago-vault-k8s-role-operator` - Operator for automatic Vault role/policy creation (wraps webapp chart)
- `cronjob` - Simple CronJob deployment wrapper
- `registry-container-webhook` - Image registry rewriting webhook (wraps harbor-container-webhook)

## Development Workflow

### Testing Charts Locally

```bash
# Validate chart syntax
helm lint charts/<chart-name>

# Render templates with default values
helm template <release-name> charts/<chart-name>

# Render with custom values
helm template <release-name> charts/<chart-name> -f charts/<chart-name>/values-overrides-<env>.yaml

# Check for issues (requires helm-docs)
helm-docs --dry-run
```

### Updating Chart Documentation

README.md files are **auto-generated** from Chart.yaml and values.yaml using helm-docs:

```bash
# Regenerate all chart READMEs (run from repo root)
helm-docs

# Regenerate specific chart
helm-docs --chart-search-root charts/<chart-name>
```

**Important:** Never manually edit the Values tables in README.md files - they're generated from values.yaml comments using the `# --` annotation format.

### Working with Dependencies

Charts with dependencies (e.g., `innago-vault-k8s-role-operator` depends on `webapp`):

```bash
# Add Helm repos referenced in Chart.yaml dependencies
helm repo add innago-webapp oci://ghcr.io/innago-property-management/helm-charts

# Update dependencies (downloads to charts/<chart-name>/charts/)
helm dependency update charts/<chart-name>

# List dependencies
helm dependency list charts/<chart-name>
```

Dependencies are automatically updated during CI/CD before chart-releaser runs.

### Pre-commit Hooks

This repo uses pre-commit hooks for security and quality:

```bash
# Install pre-commit hooks
pre-commit install

# Run hooks manually
pre-commit run --all-files
```

Configured hooks:
- **gitleaks** - Secret scanning
- **prevent-commits-to-default-branch** - Blocks commits to main branch

## Chart Architecture

### webapp Chart (charts/webapp/)

The core application chart with these key features:

**Vault Integration:**
- Uses Bank-Vaults annotations (`vault.security.banzaicloud.io/*`) for secret injection
- Supports `innago-vault-k8s-role-operator` integration via `.Values.innagoVaultK8sRoleOperator.use`
- When enabled, creates a ConfigMap triggering the operator to provision Vault role/policy

**Migration Jobs:**
- Pre-install/pre-upgrade Helm hook for database migrations
- Configurable via `.Values.migrationJob.*`
- Supports `waitForItInInitContainer` mode for long-running migrations

**Deployment Features:**
- Minimum 2 replicas enforced (see `deployment.yaml:14`)
- HPA support with configurable metrics
- Topology spread constraints for availability
- Pod disruption budgets
- Health checks at `/healthz/live` and `/healthz/ready`
- Prometheus metrics at `/metricsz`

**Configuration:**
- `appsettings` values rendered to ConfigMap (ASP.NET appsettings.json pattern)
- Environment variables via `containerEnvironmentVariables` and `containerEnvFrom`
- Additional containers/sidecars via `additionalContainers`

### valkey-cluster Chart (charts/valkey-cluster/)

Valkey deployment with dual-mode support:

**Cluster Mode** (`.Values.cluster.enabled: true`):
- Minimum 6 replicas required (3 masters + 3 replicas)
- Automatic cluster initialization via Job (`cluster-init-job.yaml`)
- StatefulSet with headless service for pod DNS
- Configurable cluster parameters: `nodeTimeout`, `requireFullCoverage`, `allowReadsWhenDown`, `replicaValidityFactor`

**Standalone Mode** (`.Values.cluster.enabled: false`):
- Single instance or master-replica setup
- Use `values-overrides-standalone.yaml` for configuration

**Key Features:**
- **Persistence:** AOF + RDB with PVC support, configurable `maxmemory` limits
- **Monitoring:** Prometheus metrics via redis_exporter sidecar, ServiceMonitor for Prometheus Operator
- **Security:** Password authentication with auto-generate option (⚠️ not recommended for production), optional NetworkPolicy for traffic control
- **High Availability:**
  - PodDisruptionBudget enabled by default (`minAvailable: 4` for 6-node cluster)
  - Topology spread constraints for availability zone distribution
  - Pod anti-affinity (preferred by default, configurable to required)
- **Graceful Shutdown:** Lifecycle preStop hook with BGSAVE delay (default 5s)
- **Node Scheduling:** Default node selector for stateful workloads (`karpenter.sh/nodepool: stateful`)
- **ArgoCD/Helm Hooks:** Cluster init job supports both ArgoCD (`PostSync`) and Helm hooks via `.Values.cluster.init.hookType`

**Network Policy:**
When `.Values.networkPolicy.enabled: true`:
- Automatic rules for pod-to-pod cluster bus (port 16379)
- Client access control via namespace/pod selectors
- Prometheus metrics scraping allowed
- Optional egress rules with DNS resolution allowed

**⚠️ TLS Support:** Planned but not yet implemented (see values.yaml lines 323-341 for future structure)

**Production Configuration Tips:**
- Set `auth.autoGenerate: false` and use `auth.existingSecret` for password management
- Configure `maxmemory` to ~90% of container memory limit to prevent OOM kills
- Enable NetworkPolicy in production for defense-in-depth
- Use `hookType: "argocd"` when deploying via ArgoCD for proper sync wave handling
- For cluster mode, ensure `replicaCount = masterCount * (1 + replicasPerMaster)` (e.g., 3 masters × 2 = 6 total)
- Consider `cluster.requireFullCoverage: "no"` for partial availability during node failures

## Version Management and Releases

### Chart Versioning

Chart versions follow SemVer and are defined in `Chart.yaml`:

```yaml
version: 1.2.3      # Chart version
appVersion: 1.2.3   # Application version (Docker image tag default)
```

**When to bump versions:**
- **Patch** (1.2.3 → 1.2.4): Bug fixes, documentation, non-breaking template changes
- **Minor** (1.2.3 → 1.3.0): New features, new values, backwards-compatible changes
- **Major** (1.2.3 → 2.0.0): Breaking changes, removed values, incompatible updates

### Release Process

1. Create feature branch (never commit to `main`)
2. Make changes to chart(s)
3. Update `Chart.yaml` version
4. Run `helm-docs` to regenerate README.md
5. Commit and push - auto-PR workflow creates PR
6. Merge to `main` triggers build-publish workflow:
   - Packages charts
   - Signs with GPG (using `CR_KEY` secret)
   - Creates GitHub Release with changelog
   - Publishes `.tgz` to GitHub Releases
   - Pushes to `oci://ghcr.io/innago-property-management/helm-charts`

**Chart Consumption:**

```bash
# From GHCR (OCI registry)
helm install my-app oci://ghcr.io/innago-property-management/helm-charts/webapp --version 2.4.0

# From GitHub Releases (via chart-releaser)
helm repo add innago https://innago-property-management.github.io/helm-charts
helm install my-app innago/webapp --version 2.4.0
```

## CI/CD Workflows

### build-publish.yml
Runs on: Push to `main`, tags, PRs, manual dispatch
- Updates Helm dependencies
- Packages and signs charts with GPG
- Releases to GitHub Releases (via chart-releaser-action)
- Pushes to GHCR OCI registry
- Only releases charts with version bumps (`skip_existing: true`)

### merge-checks.yml
Runs on: PRs, manual dispatch
- **SAST**: Semgrep static analysis
- **Secrets**: Gitleaks scanning

### auto-pr.yml
Runs on: Push to non-main branches
- Auto-creates PR using Oui-DELIVER reusable workflow
- Uses `SEMVER_TOKEN` for PR creation

## Common Patterns

### Adding a New Chart

```bash
# Create chart structure
helm create charts/my-new-chart

# Edit Chart.yaml metadata
# Edit values.yaml with proper comments (# --)
# Edit templates/

# Generate README
helm-docs --chart-search-root charts/my-new-chart

# Test locally
helm lint charts/my-new-chart
helm template test charts/my-new-chart

# Commit on feature branch and open PR
```

### Value Overrides Pattern

Charts use `values-overrides-<purpose>.yaml` files for common configurations:
- `values-overrides-standalone.yaml` (valkey-cluster: single instance mode)
- `value-overrides-aspnet-secure-vault.yaml` (webapp: ASP.NET + Vault setup)

These are reference examples, not loaded by default.

### Vault Integration Pattern

For webapps needing Vault secrets:

1. Set pod annotations in `values.yaml`:
```yaml
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "http://vault.default.svc:8200"
  vault.security.banzaicloud.io/vault-role: "my-app"
```

2. Enable operator integration:
```yaml
innagoVaultK8sRoleOperator:
  use: true
  additionalPolicies:
    - "database-dynamic-creds"
    - "messaging-creds"
```

3. Reference secrets in env vars using `vault:` prefix (Bank-Vaults format)

## Template Conventions

- Use `{{ include "ChartName.fullname" . | lower }}` for resource names (lowercase enforced)
- Minimum replicas enforced at template level: `{{ max 2 .Values.replicaCount }}`
- Topology spread constraints conditional via `.Values.topologySpreadConstraints.disabled`
- Capability-based API version handling: `{{- if ge (int .Capabilities.KubeVersion.Minor) 27 }}`

## Security Notes

- Never commit to `main` branch (blocked by pre-commit hook)
- GPG signing enforced for chart releases
- Gitleaks runs on all commits (pre-commit + CI)
- Semgrep SAST scans all PRs
- Use `.gitleaksignore` and `.semgrepignore` to suppress false positives
