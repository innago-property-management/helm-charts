# fake-job

![Version: 1.0.4](https://img.shields.io/badge/Version-1.0.4-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.16.0](https://img.shields.io/badge/AppVersion-1.16.0-informational?style=flat-square)

Innago Helm Chart for deploying a long-running background job worker as a Deployment

**Homepage:** <https://innago-property-management.github.io/helm-charts/fake-job>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Innago | <support@innago.com> |  |

## Source Code

* <https://github.com/innago-property-management/helm-charts/tree/main/charts/fake-job>

## Installation

```bash
helm repo add innago https://innago-property-management.github.io/helm-charts/
helm repo update
helm install my-fake-job innago/fake-job
```

Or from the OCI registry:

```bash
helm install my-fake-job oci://ghcr.io/innago-property-management/helm-charts/fake-job --version 1.0.4
```

## Resources Created

* `Deployment` — single replica running the configured image
* `ServiceAccount` — created when `serviceAccount.create` is `true`

No `Service` is created; the container port is declared for liveness/readiness probes only.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity rules for pod scheduling |
| containerEnvFrom | list | `[]` | envFrom sources (ConfigMaps/Secrets) for the main container |
| extraEnv | list | `[]` | Environment variables for the main container |
| fullnameOverride | string | `""` | Override the fully qualified name of the released resources |
| httpContainerPort | int | `80` | Container port exposed by the workload, named "http" |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"nginx","tag":""}` | Container image configuration |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy (Always, IfNotPresent, Never) |
| image.repository | string | `"nginx"` | Container registry and repository |
| image.tag | string | `""` | Image tag override (defaults to Chart.appVersion) IMPORTANT: Do not use "latest" in production |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| jobPodLabels | object | `{}` | Additional labels for the job pod |
| livenessProbe | object | `{"httpGet":{"path":"/","port":"http"}}` | Liveness probe for the container |
| nameOverride | string | `""` | Override the chart name used in resource names and labels |
| nodeSelector | object | `{}` | Node selector for pod scheduling |
| podAnnotations | object | `{}` | Additional annotations for the job pod |
| podSecurityContext | object | `{}` | Pod-level security context See https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| readinessProbe | object | `{"httpGet":{"path":"/","port":"http"}}` | Readiness probe for the container |
| replicaCount | int | `1` | Number of pod replicas. This chart runs at most a single instance: only 0 or 1 are meaningful. 0 scales the deployment to zero; values above 1 are clamped to 1. When the release shares a values file with the webapp chart, the count follows the webapp - autoscaling.minReplicas governs when autoscaling.enabled is true, otherwise replicaCount does |
| resources | object | `{}` | Resource requests and limits See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ |
| revisionHistoryLimit | int | `3` | Number of old ReplicaSets to retain for rollback. Kubernetes keeps 10 by default |
| securityContext | object | `{}` | Container-level security context See https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| serviceAccount.annotations | object | `{}` | Additional annotations for the ServiceAccount (e.g. IRSA role ARN) |
| serviceAccount.automount | bool | `true` | Automount the ServiceAccount token into the pod |
| serviceAccount.create | bool | `true` | Create a ServiceAccount for the workload |
| serviceAccount.name | string | `""` | ServiceAccount name (defaults to the fullname when create is true, otherwise "default") |
| tolerations | list | `[]` | Tolerations for pod scheduling |
| volumeMounts | list | `[]` | Volume mounts for the main container See https://kubernetes.io/docs/concepts/storage/volumes/ |
| volumes | list | `[]` | Volumes to mount in the job pod See https://kubernetes.io/docs/concepts/storage/volumes/ |
