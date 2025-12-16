# Innago Helm Charts

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/innago)](https://artifacthub.io/packages/search?repo=innago)

Production-ready Helm charts for Kubernetes deployments maintained by Innago.

## Available Charts

### [valkey-cluster](./charts/valkey-cluster)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/innago)](https://artifacthub.io/packages/helm/innago/valkey-cluster)

A Helm chart for deploying Valkey in cluster or standalone mode with persistence, monitoring, and automated cluster initialization.

- **Category**: Database
- **Features**: Cluster mode, standalone mode, persistence, Prometheus metrics, automated initialization

### [webapp](./charts/webapp)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/innago)](https://artifacthub.io/packages/helm/innago/webapp)

Innago Helm chart for deploying web applications to Kubernetes with production-ready patterns.

- **Category**: Integration & Delivery
- **Features**: HPA, health probes, ConfigMaps, Secrets, Ingress, ServiceMonitor

### [innago-vault-k8s-role-operator](./charts/innago-vault-k8s-role-operator)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/innago)](https://artifacthub.io/packages/helm/innago/innago-vault-k8s-role-operator)

Kubernetes operator for managing HashiCorp Vault roles and policies.

- **Category**: Security
- **Type**: Kubernetes Operator
- **Features**: Automated Vault role creation, policy management, Kubernetes auth integration

### [cronjob](./charts/cronjob)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/innago)](https://artifacthub.io/packages/helm/innago/cronjob)

Innago Helm Chart for deploying Kubernetes CronJobs.

- **Category**: Integration & Delivery
- **Features**: Flexible scheduling, resource management, ServiceAccount configuration

### [registry-container-webhook](./charts/registry-container-webhook)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/innago)](https://artifacthub.io/packages/helm/innago/registry-container-webhook)

Kubernetes admission webhook to rewrite container image references for registry caching.

- **Category**: Integration & Delivery
- **Features**: Image rewriting, registry caching, admission controller

## Installation

### Add Helm Repository

```bash
helm repo add innago https://innago-property-management.github.io/helm-charts/
helm repo update
```

### Install a Chart

```bash
# Install valkey-cluster
helm install my-valkey innago/valkey-cluster

# Install webapp
helm install my-webapp innago/webapp

# Install cronjob
helm install my-cronjob innago/cronjob

# Install vault operator
helm install vault-operator innago/innago-vault-k8s-role-operator

# Install registry webhook
helm install registry-webhook innago/registry-container-webhook
```

## OCI Registry

Charts are also available via OCI registry at `ghcr.io`:

```bash
# Install from OCI registry
helm install my-valkey oci://ghcr.io/innago-property-management/helm-charts/valkey-cluster

# Pull chart to local directory
helm pull oci://ghcr.io/innago-property-management/helm-charts/valkey-cluster --untar
```

## Chart Development

### Prerequisites
- Helm 3.x
- Kubernetes cluster (for testing)

### Testing Charts Locally

```bash
# Lint all charts
helm lint charts/*/

# Template a chart
helm template my-release charts/valkey-cluster/

# Install in dry-run mode
helm install my-release charts/valkey-cluster/ --dry-run --debug
```

### Contributing

1. Make changes to charts
2. Update chart version in `Chart.yaml`
3. Run `helm lint charts/CHART_NAME/`
4. Create PR
5. Charts are automatically published on merge to `main`

## License

Apache 2.0 - See [LICENSE](./LICENSE) for details.

## Support

For questions, issues, or contributions:
- [GitHub Issues](https://github.com/innago-property-management/helm-charts/issues)
- Email: support@innago.com

## Verified Publisher

This repository is a verified publisher on Artifact Hub. All charts are:
- ✅ Digitally signed
- ✅ Regularly updated
- ✅ Production-tested
- ✅ Apache 2.0 licensed
