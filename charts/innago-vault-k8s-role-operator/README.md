# innago-vault-k8s-role-operator

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.16.0](https://img.shields.io/badge/AppVersion-1.16.0-informational?style=flat-square)

A Helm chart for Kubernetes

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://ghcr.io/innago-property-management/helm-charts | innago-webapp(webapp) | 2.3.1 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| innago-webapp | object | `{"fullnameOverride":"innago-vault-k8s-role-operator","health":{"livenessProbe":{"httpGet":{"path":"/healthz","port":"http"}},"readinessProbe":{"httpGet":{"path":"/healthz","port":"http"}}},"image":{"repository":"ghcr.io/innago-property-management/innago-vault-k8s-role-operator","tag":"1.0.0"},"podAnnotations":{"vault.security.banzaicloud.io/vault-addr":"https://vault.default.svc:8200","vault.security.banzaicloud.io/vault-tls-secret":"vault-tls"},"podDisruptionBudget":{"disabled":false,"maxUnavailable":1,"minAvailable":0,"unhealthyPodEvictionPolicy":"IfHealthyBudget"},"topologySpreadConstraints":{"disabled":false,"maxSkew":1,"topologyKey":"kubernetes.io/hostname","whenUnsatisfiable":"ScheduleAnyway"}}` | Settings for the innago-webapp. |
| innago-webapp.fullnameOverride | string | `"innago-vault-k8s-role-operator"` | A name to override the generated name of the kubernetes objects. |
| innago-webapp.health | object | `{"livenessProbe":{"httpGet":{"path":"/healthz","port":"http"}},"readinessProbe":{"httpGet":{"path":"/healthz","port":"http"}}}` | Liveness and readiness probe settings. See https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| innago-webapp.health.livenessProbe | object | `{"httpGet":{"path":"/healthz","port":"http"}}` | Liveness probe settings. |
| innago-webapp.health.livenessProbe.httpGet.path | string | `"/healthz"` | The path for the health probe. |
| innago-webapp.health.livenessProbe.httpGet.port | string | `"http"` | The port for the health probe. |
| innago-webapp.health.readinessProbe | object | `{"httpGet":{"path":"/healthz","port":"http"}}` | Readiness probe settings. |
| innago-webapp.health.readinessProbe.httpGet.path | string | `"/healthz"` | The path for the health probe. |
| innago-webapp.health.readinessProbe.httpGet.port | string | `"http"` | The port for the health probe. |
| innago-webapp.image | object | `{"repository":"ghcr.io/innago-property-management/innago-vault-k8s-role-operator","tag":"1.0.0"}` | Image settings. |
| innago-webapp.image.repository | string | `"ghcr.io/innago-property-management/innago-vault-k8s-role-operator"` | The repository for the application image. |
| innago-webapp.image.tag | string | `"1.0.0"` | The tag for the application image. |
| innago-webapp.podAnnotations | object | `{"vault.security.banzaicloud.io/vault-addr":"https://vault.default.svc:8200","vault.security.banzaicloud.io/vault-tls-secret":"vault-tls"}` | Annotations to add to the primary pod |
| innago-webapp.podAnnotations."vault.security.banzaicloud.io/vault-addr" | string | `"https://vault.default.svc:8200"` | vault address |
| innago-webapp.podAnnotations."vault.security.banzaicloud.io/vault-tls-secret" | string | `"vault-tls"` | name of the secret containing the vault TLS certificate recommendation: use something like https://github.com/emberstack/kubernetes-reflector to replicate the secret into all namespaces |
| innago-webapp.podDisruptionBudget | object | `{"disabled":false,"maxUnavailable":1,"minAvailable":0,"unhealthyPodEvictionPolicy":"IfHealthyBudget"}` | Pod Disruption Budget settings. See https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets |
| innago-webapp.podDisruptionBudget.disabled | bool | `false` | If true, a PodDisruptionBudget will not be created. |
| innago-webapp.podDisruptionBudget.maxUnavailable | int | `1` | The maximum number of pods that can be unavailable after an eviction. |
| innago-webapp.podDisruptionBudget.minAvailable | int | `0` | The minimum number of pods that must be available after an eviction. |
| innago-webapp.podDisruptionBudget.unhealthyPodEvictionPolicy | string | `"IfHealthyBudget"` | The policy for evicting unhealthy pods. |
| innago-webapp.topologySpreadConstraints | object | `{"disabled":false,"maxSkew":1,"topologyKey":"kubernetes.io/hostname","whenUnsatisfiable":"ScheduleAnyway"}` | Topology spread constraints settings. See https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ |
| innago-webapp.topologySpreadConstraints.disabled | bool | `false` | If true, topology spread constraints will not be applied. |
| innago-webapp.topologySpreadConstraints.maxSkew | int | `1` | The maximum skew between topologies. |
| innago-webapp.topologySpreadConstraints.topologyKey | string | `"kubernetes.io/hostname"` | The key for topology domain. |
| innago-webapp.topologySpreadConstraints.whenUnsatisfiable | string | `"ScheduleAnyway"` | What to do when a pod doesn't satisfy the spread constraint. |
| serviceAccount | object | `{"annotations":{"app":"innago-vault-k8s-role-operator","app.kubernetes.io/name":"innago-vault-k8s-role-operator"},"create":true,"name":"innago-vault-k8s-role-operator"}` | Service account settings. |
| serviceAccount.annotations | object | `{"app":"innago-vault-k8s-role-operator","app.kubernetes.io/name":"innago-vault-k8s-role-operator"}` | Annotations to add to the service account. |
| serviceAccount.create | bool | `true` | If true, a service account will be created. |
| serviceAccount.name | string | `"innago-vault-k8s-role-operator"` | The name of the service account to use. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
