# innago-vault-k8s-role-operator

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart for Kubernetes

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://ghcr.io/innago-property-management/helm-charts | innago-webapp(webapp) | 2.5.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| innago-webapp | object | `{"containerSecurityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":10001,"runAsNonRoot":true,"runAsUser":10001,"seccompProfile":{"type":"RuntimeDefault"}},"fullnameOverride":"innago-vault-k8s-role-operator","health":{"livenessProbe":{"httpGet":{"path":"/healthz","port":"http"}},"readinessProbe":{"httpGet":{"path":"/healthz","port":"http"}},"startupProbe":{"failureThreshold":30,"httpGet":{"path":"/healthz","port":"http"},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":3}},"httpContainerPort":8080,"image":{"repository":"ghcr.io/innago-property-management/innago-vault-k8s-role-operator","tag":"1.0.0"},"innagoVaultK8sRoleOperator":{"use":false},"podAnnotations":{"keptn.sh/app":"innago-vault-k8s-role-operator","keptn.sh/version":"1.0.0","keptn.sh/workload":"innago-vault-k8s-role-operator","vault.security.banzaicloud.io/vault-addr":"https://vault.security.svc:8200","vault.security.banzaicloud.io/vault-tls-secret":"vault-tls"},"podDisruptionBudget":{"disabled":false,"maxUnavailable":1,"minAvailable":1,"unhealthyPodEvictionPolicy":"IfHealthyBudget"},"resources":{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"100m","memory":"128Mi"}},"topologySpreadConstraints":{"disabled":false,"maxSkew":1,"topologyKey":"kubernetes.io/hostname","whenUnsatisfiable":"ScheduleAnyway"},"vault":{"address":"https://vault.security.svc:8200","tlsSecret":"vault-tls"}}` | Settings for the innago-webapp. |
| innago-webapp.containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":10001,"runAsNonRoot":true,"runAsUser":10001,"seccompProfile":{"type":"RuntimeDefault"}}` | security context see https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| innago-webapp.fullnameOverride | string | `"innago-vault-k8s-role-operator"` | A name to override the generated name of the kubernetes objects. |
| innago-webapp.health | object | `{"livenessProbe":{"httpGet":{"path":"/healthz","port":"http"}},"readinessProbe":{"httpGet":{"path":"/healthz","port":"http"}},"startupProbe":{"failureThreshold":30,"httpGet":{"path":"/healthz","port":"http"},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":3}}` | Liveness and readiness probe settings. See https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| innago-webapp.health.livenessProbe | object | `{"httpGet":{"path":"/healthz","port":"http"}}` | Liveness probe settings. |
| innago-webapp.health.livenessProbe.httpGet.path | string | `"/healthz"` | The path for the health probe. |
| innago-webapp.health.livenessProbe.httpGet.port | string | `"http"` | The port for the health probe. |
| innago-webapp.health.readinessProbe | object | `{"httpGet":{"path":"/healthz","port":"http"}}` | Readiness probe settings. |
| innago-webapp.health.readinessProbe.httpGet.path | string | `"/healthz"` | The path for the health probe. |
| innago-webapp.health.readinessProbe.httpGet.port | string | `"http"` | The port for the health probe. |
| innago-webapp.health.startupProbe | object | `{"failureThreshold":30,"httpGet":{"path":"/healthz","port":"http"},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":3}` | Startup probe settings (operators need time for leader election). |
| innago-webapp.health.startupProbe.failureThreshold | int | `30` | Number of failures before pod is considered unhealthy. |
| innago-webapp.health.startupProbe.httpGet.path | string | `"/healthz"` | The path for the health probe. |
| innago-webapp.health.startupProbe.httpGet.port | string | `"http"` | The port for the health probe. |
| innago-webapp.health.startupProbe.initialDelaySeconds | int | `10` | Initial delay before first check (seconds). |
| innago-webapp.health.startupProbe.periodSeconds | int | `5` | How often to perform the probe (seconds). |
| innago-webapp.health.startupProbe.timeoutSeconds | int | `3` | Timeout for the probe (seconds). |
| innago-webapp.httpContainerPort | int | `8080` | http container port |
| innago-webapp.image | object | `{"repository":"ghcr.io/innago-property-management/innago-vault-k8s-role-operator","tag":"1.0.0"}` | Image settings. |
| innago-webapp.image.repository | string | `"ghcr.io/innago-property-management/innago-vault-k8s-role-operator"` | The repository for the application image. |
| innago-webapp.image.tag | string | `"1.0.0"` | The tag for the application image. |
| innago-webapp.podAnnotations | object | `{"keptn.sh/app":"innago-vault-k8s-role-operator","keptn.sh/version":"1.0.0","keptn.sh/workload":"innago-vault-k8s-role-operator","vault.security.banzaicloud.io/vault-addr":"https://vault.security.svc:8200","vault.security.banzaicloud.io/vault-tls-secret":"vault-tls"}` | Annotations to add to the primary pod |
| innago-webapp.podDisruptionBudget | object | `{"disabled":false,"maxUnavailable":1,"minAvailable":1,"unhealthyPodEvictionPolicy":"IfHealthyBudget"}` | Pod Disruption Budget settings. See https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets |
| innago-webapp.podDisruptionBudget.disabled | bool | `false` | If true, a PodDisruptionBudget will not be created. |
| innago-webapp.podDisruptionBudget.maxUnavailable | int | `1` | The maximum number of pods that can be unavailable after an eviction. |
| innago-webapp.podDisruptionBudget.minAvailable | int | `1` | The minimum number of pods that must be available after an eviction. IMPORTANT: Set to 1 for production to ensure high availability during maintenance. |
| innago-webapp.podDisruptionBudget.unhealthyPodEvictionPolicy | string | `"IfHealthyBudget"` | The policy for evicting unhealthy pods. |
| innago-webapp.resources | object | `{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Resource requests and limits for the operator. CRITICAL: Prevents OOM kills and ensures stable operation. |
| innago-webapp.topologySpreadConstraints | object | `{"disabled":false,"maxSkew":1,"topologyKey":"kubernetes.io/hostname","whenUnsatisfiable":"ScheduleAnyway"}` | Topology spread constraints settings. See https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ |
| innago-webapp.topologySpreadConstraints.disabled | bool | `false` | If true, topology spread constraints will not be applied. |
| innago-webapp.topologySpreadConstraints.maxSkew | int | `1` | The maximum skew between topologies. |
| innago-webapp.topologySpreadConstraints.topologyKey | string | `"kubernetes.io/hostname"` | The key for topology domain. |
| innago-webapp.topologySpreadConstraints.whenUnsatisfiable | string | `"ScheduleAnyway"` | What to do when a pod doesn't satisfy the spread constraint. |
| innago-webapp.vault | object | `{"address":"https://vault.security.svc:8200","tlsSecret":"vault-tls"}` | Vault configuration |
| innago-webapp.vault.address | string | `"https://vault.security.svc:8200"` | Vault server address (protocol://host:port) IMPORTANT: Configure this for your environment. Default assumes Vault in 'security' namespace. |
| innago-webapp.vault.tlsSecret | string | `"vault-tls"` | Name of the secret containing the Vault TLS certificate Recommendation: Use https://github.com/emberstack/kubernetes-reflector to replicate the secret into all namespaces |
| serviceAccount | object | `{"annotations":{"app":"innago-vault-k8s-role-operator","app.kubernetes.io/name":"innago-vault-k8s-role-operator"},"create":true,"name":"innago-vault-k8s-role-operator"}` | Service account settings. |
| serviceAccount.annotations | object | `{"app":"innago-vault-k8s-role-operator","app.kubernetes.io/name":"innago-vault-k8s-role-operator"}` | Annotations to add to the service account. |
| serviceAccount.create | bool | `true` | If true, a service account will be created. |
| serviceAccount.name | string | `"innago-vault-k8s-role-operator"` | The name of the service account to use. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
