# valkey-cluster

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 8.0.1](https://img.shields.io/badge/AppVersion-8.0.1-informational?style=flat-square)

A Helm chart for deploying Valkey in cluster or standalone mode with persistence, monitoring, and automated cluster initialization

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{"podAntiAffinity":{"type":"preferred","weight":100}}` | Affinity for pod assignment |
| affinity.podAntiAffinity | object | `{"type":"preferred","weight":100}` | Pod anti-affinity configuration |
| affinity.podAntiAffinity.type | string | `"preferred"` | Use preferred (soft) or required (hard) anti-affinity "preferred" allows pods to be scheduled on same node if necessary "required" enforces strict node distribution |
| affinity.podAntiAffinity.weight | int | `100` | Weight for preferred anti-affinity (1-100) |
| auth | object | `{"autoGenerate":true,"enabled":true,"existingSecret":"","existingSecretPasswordKey":"password","password":""}` | Valkey authentication configuration |
| auth.autoGenerate | bool | `true` | Auto-generate a random password if password is empty (and no existingSecret) WARNING: Auto-generated passwords change on each helm template render Set to true for development/testing ONLY. Use existingSecret for production. |
| auth.enabled | bool | `true` | Enable password authentication |
| auth.existingSecret | string | `""` | Name of existing secret containing Valkey password (recommended for production) |
| auth.existingSecretPasswordKey | string | `"password"` | Key in existing secret that contains the password |
| auth.password | string | `""` | Valkey password (if not using existingSecret) IMPORTANT: You must configure ONE of: password, autoGenerate=true, or existingSecret Leave empty when using existingSecret or autoGenerate |
| cluster | object | `{"allowReadsWhenDown":"no","enabled":true,"init":{"activeDeadlineSeconds":300,"backoffLimit":5,"enabled":true,"hookType":"argocd"},"masterCount":3,"nodeTimeout":5000,"replicaValidityFactor":10,"replicasPerMaster":1,"requireFullCoverage":"no"}` | Valkey cluster configuration |
| cluster.allowReadsWhenDown | string | `"no"` | Allow reads when cluster is marked as failed |
| cluster.enabled | bool | `true` | Enable cluster mode (requires minimum 6 replicas) |
| cluster.init | object | `{"activeDeadlineSeconds":300,"backoffLimit":5,"enabled":true,"hookType":"argocd"}` | Enable cluster initialization job |
| cluster.init.activeDeadlineSeconds | int | `300` | Init job active deadline in seconds |
| cluster.init.backoffLimit | int | `5` | Init job backoff limit |
| cluster.init.hookType | string | `"argocd"` | Hook type: "argocd" or "helm" |
| cluster.masterCount | int | `3` | Number of master shards (for cluster mode) Total replicas should be masterCount * (1 + replicasPerMaster) |
| cluster.nodeTimeout | int | `5000` | Cluster node timeout in milliseconds |
| cluster.replicaValidityFactor | int | `10` | Replica validity factor (default 10) Controls how long a replica can be disconnected before being invalid for failover |
| cluster.replicasPerMaster | int | `1` | Number of replicas per master shard |
| cluster.requireFullCoverage | string | `"no"` | Require full hash slot coverage for cluster to accept writes Set to "no" for partial availability during failures |
| config | object | `{"appendfsync":"everysec","appendonly":"yes","custom":"","maxmemory":"","maxmemory-policy":"noeviction","save":"900 1 300 10 60 10000"}` | Valkey configuration options These will be merged into valkey.conf |
| config.appendfsync | string | `"everysec"` | AOF fsync policy |
| config.appendonly | string | `"yes"` | Enable AOF persistence |
| config.custom | string | `""` | Additional custom configuration Add any valkey.conf directives here |
| config.maxmemory | string | `""` | Maximum memory limit (e.g., "1800mb") Should be ~90% of container memory limit. Empty means no limit. |
| config.maxmemory-policy | string | `"noeviction"` | Maximum memory policy |
| config.save | string | `"900 1 300 10 60 10000"` | Save snapshots to disk |
| containerEnvFrom | list | `[]` | Container environment from (ConfigMap/Secret references) |
| containerEnvironmentVariables | list | `[]` | Container environment variables |
| containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":false,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}` | Container security context |
| fullnameOverride | string | `""` | String to fully override valkey-cluster.fullname |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"docker.io/valkey/valkey"` | Valkey Docker image repository |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion |
| imagePullSecrets | list | `[]` | Docker registry secret names as an array |
| lifecycle | object | `{"preStop":{"delay":5,"enabled":true}}` | Lifecycle hooks configuration |
| lifecycle.preStop | object | `{"delay":5,"enabled":true}` | preStop hook for graceful shutdown |
| lifecycle.preStop.delay | int | `5` | Delay in seconds after triggering BGSAVE before shutdown |
| lifecycle.preStop.enabled | bool | `true` | Enable preStop hook |
| livenessProbe | object | `{"enabled":true,"failureThreshold":3,"initialDelaySeconds":30,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5}` | Liveness probe configuration |
| metrics | object | `{"enabled":true,"image":{"pullPolicy":"IfNotPresent","repository":"oliver006/redis_exporter","tag":"v1.66.0"},"port":9121,"resources":{"limits":{"cpu":"100m","memory":"128Mi"},"requests":{"cpu":"50m","memory":"64Mi"}},"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}}` | Prometheus metrics exporter configuration |
| metrics.enabled | bool | `true` | Enable redis_exporter sidecar for Prometheus metrics |
| metrics.image | object | `{"pullPolicy":"IfNotPresent","repository":"oliver006/redis_exporter","tag":"v1.66.0"}` | redis_exporter image |
| metrics.port | int | `9121` | redis_exporter port |
| metrics.resources | object | `{"limits":{"cpu":"100m","memory":"128Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}` | redis_exporter resources |
| metrics.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}` | redis_exporter security context |
| nameOverride | string | `""` | String to partially override valkey-cluster.fullname |
| networkPolicy | object | `{"egress":{"customRules":[],"dns":{"to":[]},"enabled":false},"enabled":false,"ingress":{"allowExternal":false,"customRules":[],"namespaceSelector":{},"podSelector":{},"prometheusNamespaceSelector":{}}}` | Network policy configuration |
| networkPolicy.egress | object | `{"customRules":[],"dns":{"to":[]},"enabled":false}` | Egress rules configuration |
| networkPolicy.egress.customRules | list | `[]` | Custom egress rules (advanced) |
| networkPolicy.egress.dns | object | `{"to":[]}` | DNS egress configuration |
| networkPolicy.egress.dns.to | list | `[]` | Custom DNS egress selectors (overrides defaults) If unset, defaults to kube-system namespace with kube-dns labels For CoreDNS or different configurations, customize these selectors Example for custom CoreDNS: to:   - namespaceSelector:       matchLabels:         kubernetes.io/metadata.name: kube-system   - podSelector:       matchLabels:         k8s-app: coredns |
| networkPolicy.egress.enabled | bool | `false` | Enable egress rules (restricts outbound traffic) |
| networkPolicy.enabled | bool | `false` | Enable NetworkPolicy creation |
| networkPolicy.ingress | object | `{"allowExternal":false,"customRules":[],"namespaceSelector":{},"podSelector":{},"prometheusNamespaceSelector":{}}` | Ingress rules configuration |
| networkPolicy.ingress.allowExternal | bool | `false` | Allow external client connections (beyond pod-to-pod) Requires at least one of namespaceSelector or podSelector to be set |
| networkPolicy.ingress.customRules | list | `[]` | Custom ingress rules (advanced) |
| networkPolicy.ingress.namespaceSelector | object | `{}` | Namespace selector for allowed clients Example: namespaceSelector: { matchLabels: { name: "app-namespace" } } |
| networkPolicy.ingress.podSelector | object | `{}` | Pod selector for allowed clients Example: podSelector: { matchLabels: { app: "my-app" } } |
| networkPolicy.ingress.prometheusNamespaceSelector | object | `{}` | Namespace selector for Prometheus Example: prometheusNamespaceSelector: { matchLabels: { name: "monitoring" } } |
| nodeSelector | object | `{}` | Node selector for pod assignment Example for Karpenter: { karpenter.sh/nodepool: stateful } Example for node type: { node.kubernetes.io/instance-type: m5.large } |
| persistence | object | `{"accessModes":["ReadWriteOnce"],"annotations":{},"enabled":true,"size":"8Gi","storageClass":""}` | Persistence configuration |
| persistence.accessModes | list | `["ReadWriteOnce"]` | PVC Access Mode |
| persistence.annotations | object | `{}` | Annotations for PVCs |
| persistence.enabled | bool | `true` | Enable persistence using PVC |
| persistence.size | string | `"8Gi"` | PVC Storage Request |
| persistence.storageClass | string | `""` | PVC Storage Class Leave empty ("") to use cluster default storage class If set to "-", storageClassName: "", which disables dynamic provisioning Set to specific class name for cloud providers (e.g., "ebs-sc" for AWS, "standard-rwo" for GKE) |
| podAnnotations | object | `{}` | Annotations to add to the pod |
| podDisruptionBudget | object | `{"enabled":true,"maxUnavailable":null,"minAvailable":null}` | Pod disruption budget configuration |
| podDisruptionBudget.enabled | bool | `true` | Enable PodDisruptionBudget |
| podDisruptionBudget.maxUnavailable | string | `nil` | Maximum unavailable pods (alternative to minAvailable) If both minAvailable and maxUnavailable are null, minAvailable is auto-calculated |
| podDisruptionBudget.minAvailable | string | `nil` | Minimum available pods If not set, defaults to: - Cluster mode: max(1, replicaCount - 2) [allows up to 2 nodes down] - Standalone mode: 1 [keeps at least 1 instance] Set explicitly to override auto-calculation |
| podSecurityContext | object | `{"fsGroup":1000,"runAsGroup":1000,"runAsUser":1000}` | Pod security context |
| readinessProbe | object | `{"enabled":true,"failureThreshold":3,"initialDelaySeconds":10,"periodSeconds":5,"successThreshold":1,"timeoutSeconds":3}` | Readiness probe configuration |
| replicaCount | int | `6` | Number of Valkey replicas to deploy For cluster mode: minimum 6 (3 masters + 3 replicas) For standalone mode: 1-2 |
| resources | object | `{"limits":{"cpu":"1000m","memory":"2Gi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Resource limits and requests |
| service | object | `{"client":{"annotations":{},"port":6379,"type":"ClusterIP"},"headless":{"annotations":{},"clusterIP":"None","type":"ClusterIP"}}` | Service configuration |
| service.client | object | `{"annotations":{},"port":6379,"type":"ClusterIP"}` | Client service for application access |
| service.client.annotations | object | `{}` | Annotations for client service |
| service.client.port | int | `6379` | Service port |
| service.client.type | string | `"ClusterIP"` | Service type for client service |
| service.headless | object | `{"annotations":{},"clusterIP":"None","type":"ClusterIP"}` | Headless service for StatefulSet pod DNS |
| service.headless.annotations | object | `{}` | Annotations for headless service |
| service.headless.clusterIP | string | `"None"` | Cluster IP (use "None" for headless) |
| service.headless.type | string | `"ClusterIP"` | Service type for headless service |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| serviceMonitor | object | `{"enabled":true,"interval":"30s","labels":{"release":"prometheus"},"namespace":"","namespaceSelector":{},"scrapeTimeout":"10s"}` | ServiceMonitor configuration for Prometheus Operator |
| serviceMonitor.enabled | bool | `true` | Enable ServiceMonitor creation |
| serviceMonitor.interval | string | `"30s"` | ServiceMonitor scrape interval |
| serviceMonitor.labels | object | `{"release":"prometheus"}` | ServiceMonitor labels |
| serviceMonitor.namespace | string | `""` | ServiceMonitor namespace (defaults to release namespace) |
| serviceMonitor.namespaceSelector | object | `{}` | Namespace selector for ServiceMonitor (if monitoring across namespaces) Example: namespaceSelector: { matchNames: ["valkey-cluster"] } |
| serviceMonitor.scrapeTimeout | string | `"10s"` | ServiceMonitor scrape timeout |
| startupProbe | object | `{"enabled":false,"failureThreshold":30,"initialDelaySeconds":0,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5}` | Startup probe configuration (prevents liveness failures during slow starts) |
| tls | object | `{"authClients":"no","clusterEnabled":false,"enabled":false,"existingSecret":"","port":6380}` | TLS configuration (future enhancement - not yet implemented) When implemented, will support: - tls-port for encrypted client connections - tls-cluster yes for encrypted cluster bus - Certificate mounting via secrets - tls-auth-clients for mutual TLS |
| tls.authClients | string | `"no"` | Require client authentication (mTLS) |
| tls.clusterEnabled | bool | `false` | Enable TLS for cluster bus communication |
| tls.enabled | bool | `false` | Enable TLS encryption |
| tls.existingSecret | string | `""` | Existing secret containing TLS certificates Expected keys: tls.crt, tls.key, ca.crt |
| tls.port | int | `6380` | TLS port for client connections |
| tolerations | list | `[]` | Tolerations for pod assignment |
| topologySpreadConstraints | object | `{"enabled":true,"maxSkew":1,"topologyKey":"topology.kubernetes.io/zone","whenUnsatisfiable":"ScheduleAnyway"}` | Topology spread constraints for availability zone distribution |
| topologySpreadConstraints.enabled | bool | `true` | Enable topology spread constraints |
| topologySpreadConstraints.maxSkew | int | `1` | Maximum skew allowed between zones |
| topologySpreadConstraints.topologyKey | string | `"topology.kubernetes.io/zone"` | Topology key to spread across (typically topology.kubernetes.io/zone) |
| topologySpreadConstraints.whenUnsatisfiable | string | `"ScheduleAnyway"` | What to do if constraint cannot be satisfied: DoNotSchedule or ScheduleAnyway |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
