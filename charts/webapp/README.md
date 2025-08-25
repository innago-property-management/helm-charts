# webapp

![Version: 2.4.0](https://img.shields.io/badge/Version-2.4.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 2.4.0](https://img.shields.io/badge/AppVersion-2.4.0-informational?style=flat-square)

Innago Helm chart for a WebApp in Kubernetes

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| additionalContainerPorts | list | `[]` | if `service.enableHttps` is true, then a port named https will be added to the main container |
| additionalContainers | list | `[]` | this follows the pod spec on containers. see https://kubernetes.io/docs/concepts/workloads/pods/ |
| additionalServicePorts | list | `[]` |  |
| affinity | object | `{}` |  |
| appsettings | object | `{}` |  |
| autoscaling | object | `{"enabled":"no","maxReplicas":4,"minReplicas":2,"targetCPUUtilizationPercentage":80}` | see https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/ |
| containerEnvFrom | list | `[]` |  |
| containerEnvironmentVariables | list | `[]` |  |
| containerSecurityContext | string | `nil` | see https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| deploymentAnnotations | object | `{}` | Annotations to add to the deployment |
| deploymentLabels | object | `{}` | Labels to add to the deployment |
| fullnameOverride | string | `""` |  |
| health.livenessProbe.httpGet.path | string | `"/healthz/live"` |  |
| health.livenessProbe.httpGet.port | string | `"http"` |  |
| health.readinessProbe.httpGet.path | string | `"/healthz/ready"` |  |
| health.readinessProbe.httpGet.port | string | `"http"` |  |
| httpContainerPort | int | `80` | just the port number. the recommended value is 8080 if you control the image. |
| httpsContainerPort | int | `443` | just the port number. the recommended value is 8443 if you control the image. this is only used if `service.enableHttps` is true |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"nginx"` |  |
| image.tag | string | `""` | this is generally the only value you will change between releases |
| imagePullSecrets | list | `[]` | name of secret in the namespace that contains docker config for image repository |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| innagoVaultK8sRoleOperator.additionalPolicies | list | `[]` | an array of additional policy names. you would use this if dynamic secrets for a database, messaging system, etc. are in use. |
| innagoVaultK8sRoleOperator.use | bool | `true` | whether a config map to trigger vault role and policy should be created. if the https://github.com/innago-property-management/innago-vault-k8s-role-operator is present in the cluster, including this will create a config map which will then be used by the operator to create a policy and role for the service account used by your app. |
| metrics.path | string | `"/metricsz"` |  |
| metrics.port | string | `"http"` |  |
| migrationJob.annotations | object | `{}` |  |
| migrationJob.command | string | `nil` |  |
| migrationJob.containerEnvFrom | list | `[]` |  |
| migrationJob.enabled | bool | `false` |  |
| migrationJob.environmentVariables | list | `[]` |  |
| migrationJob.image.pullPolicy | string | `"IfNotPresent"` |  |
| migrationJob.image.repository | string | `""` |  |
| migrationJob.image.tag | string | `""` | this value is independent of the version of the image used in the deployment of the core app |
| migrationJob.volumeMounts | list | `[]` |  |
| migrationJob.volumes | list | `[]` |  |
| migrationJob.waitForItInInitContainer | bool | `false` | use true if your migrations take a long time, causing the helm hook to fail |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` | see https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ |
| podAnnotations | object | `{"vault.security.banzaicloud.io/vault-addr":"http://vault.default.svc:8200"}` | Annotations to add to the primary pod |
| podDisruptionBudget.disabled | bool | `false` | If true, a PodDisruptionBudget will not be created. |
| podDisruptionBudget.maxUnavailable | int | `1` | The maximum number of pods that can be unavailable after an eviction. |
| podDisruptionBudget.minAvailable | int | `0` | The minimum number of pods that must be available after an eviction. |
| podDisruptionBudget.unhealthyPodEvictionPolicy | string | `"IfHealthyBudget"` | The policy for evicting unhealthy pods. |
| podLabels | string | `nil` | Labels to add to the pod |
| podSecurityContext | string | `nil` | see https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| replicaCount | int | `2` | replicaCount is only used if HPA is not enabled |
| resources | object | `{"requests":{"cpu":"100m","memory":"128Mi"}}` | see https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ |
| service.enableHttps | bool | `false` | the port will target a container port with the same name |
| service.httpsPort | int | `443` |  |
| service.port | int | `80` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | If not set and create is true, a name is generated using the fullname template |
| tolerations | list | `[]` | see https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ |
| topologySpreadConstraints | object | `{"disabled":false,"maxSkew":1,"topologyKey":"kubernetes.io/hostname","whenUnsatisfiable":"ScheduleAnyway"}` | Topology spread constraints settings. See https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ |
| topologySpreadConstraints.disabled | bool | `false` | If true, topology spread constraints will not be applied. |
| topologySpreadConstraints.maxSkew | int | `1` | The maximum skew between topologies. |
| topologySpreadConstraints.topologyKey | string | `"kubernetes.io/hostname"` | The key for topology domain. |
| topologySpreadConstraints.whenUnsatisfiable | string | `"ScheduleAnyway"` | What to do when a pod doesn't satisfy the spread constraint. |
| volumeMounts | list | `[]` | see https://kubernetes.io/docs/concepts/storage/volumes/ |
| volumes | list | `[]` | see https://kubernetes.io/docs/concepts/storage/volumes/ |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
