# webapp

![Version: 2.5.0](https://img.shields.io/badge/Version-2.5.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 2.5.0](https://img.shields.io/badge/AppVersion-2.5.0-informational?style=flat-square)

Innago Helm chart for a WebApp in Kubernetes

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| additionalContainerPorts | list | `[]` | Follows Kubernetes container port syntax |
| additionalContainers | list | `[]` | Common patterns:    - OAuth2 Proxy for authentication    - Fluent Bit for log shipping    - Cloud SQL Proxy for database connections    - Envoy proxy for service mesh |
| additionalServicePorts | list | `[]` | Useful for exposing metrics, gRPC, or custom protocols |
| affinity | object | `{}` | Example: Prefer spreading pods across different zones  podAntiAffinity:    preferredDuringSchedulingIgnoredDuringExecution:      - weight: 100        podAffinityTerm:          labelSelector:            matchExpressions:              - key: app.kubernetes.io/name                operator: In                values:                  - webapp          topologyKey: topology.kubernetes.io/zone |
| autoscaling | object | `{"behavior":{},"enabled":"no","maxReplicas":4,"minReplicas":2,"targetCPUUtilizationPercentage":80,"targetMemoryUtilizationPercentage":null}` | Requires metrics-server to be installed in the cluster |
| autoscaling.behavior | object | `{}` | See https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#scaling-policies |
| autoscaling.enabled | string | `"no"` | Enable HPA (disables fixed replicaCount) |
| autoscaling.maxReplicas | int | `4` | Maximum number of replicas (set based on expected peak load) |
| autoscaling.minReplicas | int | `2` | Minimum number of replicas (recommended: 2+ for HA) |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Example: 80 means scale up when average CPU > 80% |
| autoscaling.targetMemoryUtilizationPercentage | string | `nil` | Requires memory requests to be set |
| configMaps | list | `[]` | The ConfigMap name will be prefixed with the release fullname |
| configVersion | string | `""` | Only needed if you manage ConfigMaps outside of Helm |
| containerEnvFrom | list | `[]` | Example: Load all variables from a ConfigMap or Secret |
| containerEnvironmentVariables | list | `[]` | Common patterns:    - ASPNETCORE_ENVIRONMENT: "Production"    - LOG_LEVEL: "Info"    - Feature flags and toggles |
| containerSecurityContext | object | `{}` | Production recommendation: Set all commented values below |
| deploymentAnnotations | object | `{}` | Useful for external tools that watch Deployment metadata |
| deploymentLabels | object | `{}` | Useful for organizational grouping or policy matching |
| fullnameOverride | string | `""` | Useful when migrating from another naming scheme |
| health.livenessProbe.failureThreshold | int | `3` |  |
| health.livenessProbe.httpGet.path | string | `"/healthz/live"` |  |
| health.livenessProbe.httpGet.port | string | `"http"` |  |
| health.livenessProbe.initialDelaySeconds | int | `10` |  |
| health.livenessProbe.periodSeconds | int | `10` |  |
| health.livenessProbe.successThreshold | int | `1` |  |
| health.livenessProbe.timeoutSeconds | int | `5` |  |
| health.readinessProbe.failureThreshold | int | `3` |  |
| health.readinessProbe.httpGet.path | string | `"/healthz/ready"` |  |
| health.readinessProbe.httpGet.port | string | `"http"` |  |
| health.readinessProbe.initialDelaySeconds | int | `5` |  |
| health.readinessProbe.periodSeconds | int | `5` |  |
| health.readinessProbe.successThreshold | int | `1` |  |
| health.readinessProbe.timeoutSeconds | int | `3` |  |
| health.startupProbe | object | `{}` | If not set, no startup probe is configured |
| httpContainerPort | int | `80` | Default: 80 for compatibility with nginx base image |
| httpsContainerPort | int | `443` | Recommended: 8443 for non-root users |
| image.pullPolicy | string | `"IfNotPresent"` | Always: Pull on every pod start (useful for development with :latest tag) |
| image.repository | string | `"nginx"` | Container image repository (change this to your application image) |
| image.tag | string | `""` | IMPORTANT: Always pin to specific version in production, never use "latest" |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` | Examples:    cert-manager.io/cluster-issuer: "letsencrypt-prod"  # Automatic TLS with cert-manager    nginx.ingress.kubernetes.io/limit-rps: "10"         # Rate limiting    nginx.ingress.kubernetes.io/rewrite-target: /       # Path rewriting |
| ingress.className | string | `""` | Kubernetes 1.18+ uses ingressClassName instead of annotation |
| ingress.enabled | bool | `false` | Exposes HTTP/HTTPS routes from outside the cluster to services |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Each host can have multiple paths routing to this service |
| ingress.tls | list | `[]` | Secret can be created manually or via cert-manager |
| initContainers | list | `[]` | Common use cases: database migrations, configuration setup, dependency checks |
| innagoVaultK8sRoleOperator.additionalPolicies | list | `[]` | an array of additional policy names. you would use this if dynamic secrets for a database, messaging system, etc. are in use. |
| innagoVaultK8sRoleOperator.use | bool | `true` | whether a config map to trigger vault role and policy should be created. if the https://github.com/innago-property-management/innago-vault-k8s-role-operator is present in the cluster, including this will create a config map which will then be used by the operator to create a policy and role for the service account used by your app. |
| lifecycle | object | `{"preStop":{"enabled":true,"sleepSeconds":5},"terminationGracePeriodSeconds":30}` | Lifecycle hooks and termination configuration |
| lifecycle.preStop | object | `{"enabled":true,"sleepSeconds":5}` | preStop hook configuration |
| lifecycle.preStop.enabled | bool | `true` | Enable preStop hook for graceful shutdown |
| lifecycle.preStop.sleepSeconds | int | `5` | Seconds to sleep in preStop hook (allows load balancer to deregister) |
| lifecycle.terminationGracePeriodSeconds | int | `30` | Pod termination grace period (seconds) Time for graceful shutdown before SIGKILL |
| metrics.enabled | bool | `true` | Enable metrics endpoint |
| metrics.path | string | `"/metricsz"` | Metrics endpoint path |
| metrics.port | string | `"http"` | Metrics endpoint port name |
| metrics.serviceMonitor | object | `{"enabled":false,"interval":"30s","labels":{},"metricRelabelings":[],"namespace":"","namespaceSelector":{},"relabelings":[],"scrapeTimeout":"10s"}` | ServiceMonitor configuration for Prometheus Operator |
| metrics.serviceMonitor.enabled | bool | `false` | Enable ServiceMonitor creation |
| metrics.serviceMonitor.interval | string | `"30s"` | Scrape interval |
| metrics.serviceMonitor.labels | object | `{}` | Must match Prometheus serviceMonitorSelector |
| metrics.serviceMonitor.metricRelabelings | list | `[]` | See https://prometheus.io/docs/prometheus/latest/configuration/configuration/#metric_relabel_configs |
| metrics.serviceMonitor.namespace | string | `""` | ServiceMonitor namespace (defaults to release namespace) |
| metrics.serviceMonitor.namespaceSelector | object | `{}` | Namespace selector for ServiceMonitor |
| metrics.serviceMonitor.relabelings | list | `[]` | See https://prometheus.io/docs/prometheus/latest/configuration/configuration/#relabel_config |
| metrics.serviceMonitor.scrapeTimeout | string | `"10s"` | Scrape timeout |
| migrationJob.annotations | object | `{}` | Example: Set TTL for automatic cleanup    ttlSecondsAfterFinished: "86400"  # Delete job after 24 hours |
| migrationJob.command | string | `nil` | Example for EF Core: ["dotnet", "ef", "database", "update"] |
| migrationJob.containerEnvFrom | list | `[]` | Load environment variables from ConfigMaps or Secrets |
| migrationJob.enabled | bool | `false` | Creates a Kubernetes Job to run database migrations before app deployment |
| migrationJob.environmentVariables | list | `[]` | Use Vault syntax for secrets: vault:/secret/data/path#key |
| migrationJob.image.pullPolicy | string | `"IfNotPresent"` |  |
| migrationJob.image.repository | string | `""` | Should contain your database migration tooling (e.g., dotnet ef, flyway, liquibase) |
| migrationJob.image.tag | string | `""` | Allows independent versioning of migrations |
| migrationJob.initContainerImage | object | `{"pullPolicy":"IfNotPresent","repository":"groundnuty/k8s-wait-for","tag":"v2.0"}` | Production recommendation: Mirror this image to your private registry |
| migrationJob.resources | object | `{"requests":{"cpu":"100m","memory":"256Mi"}}` | Resource requests for migration job container Limits intentionally omitted to allow VPA recommendations |
| migrationJob.volumeMounts | list | `[]` |  |
| migrationJob.volumes | list | `[]` |  |
| migrationJob.waitForItInInitContainer | bool | `false` | Use true for long-running migrations (>5 minutes) to avoid Helm timeouts |
| nameOverride | string | `""` | Rarely needed, defaults to chart name "webapp" |
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
| nodeSelector | object | `{}` | Examples:    disktype: ssd  # Only schedule on nodes with SSD storage    nodepool: application-pool  # AWS Karpenter/GKE node pool selection |
| podAnnotations | object | `{}` | Annotations to add to the primary pod |
| podDisruptionBudget.disabled | bool | `false` | If true, a PodDisruptionBudget will not be created. |
| podDisruptionBudget.maxUnavailable | string | `nil` | The maximum number of pods that can be unavailable after an eviction. If both minAvailable and maxUnavailable are null, maxUnavailable defaults to 1 |
| podDisruptionBudget.minAvailable | string | `nil` | The minimum number of pods that must be available after an eviction. If not set, defaults to calculated value based on replica count Set explicitly to override (e.g., minAvailable: 2) |
| podDisruptionBudget.unhealthyPodEvictionPolicy | string | `"IfHealthyBudget"` | The policy for evicting unhealthy pods. |
| podLabels | object | `{}` | Labels to add to pods These labels are added in addition to standard app.kubernetes.io labels Common use cases: - Cost allocation: team, cost-center, environment - Monitoring: prometheus.io/*, datadog/* - Policy enforcement: policy.*/*, security/* - Service mesh: version, traffic routing labels |
| podSecurityContext | object | `{}` | See https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| replicaCount | int | `2` | For production, use HPA instead of fixed replica count |
| resources | object | `{"requests":{"cpu":"100m","memory":"128Mi"}}` | see https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/  Strategy Recommendations: 1. Development: Set requests only (allows VPA to tune limits) 2. Production (no VPA): Set both requests and limits based on profiling 3. Production (with VPA): Set requests only, let VPA manage limits  QoS Classes: - Guaranteed: requests == limits (predictable, highest priority) - Burstable: requests < limits (flexible, medium priority) - BestEffort: no requests/limits (lowest priority, avoid in production)  Sizing Guidelines: - Requests: Based on P95 actual usage from profiling - Limits: 1.5-2x requests for burst capacity - Memory: Set limit to prevent runaway growth causing node pressure - CPU: Consider omitting limit (avoid throttling) unless strict isolation needed  Example sizing by workload: - Small app (1-10 req/sec): cpu: 100m, memory: 128Mi - Medium app (10-100 req/sec): cpu: 500m, memory: 512Mi - Large app (100+ req/sec): cpu: 1000m, memory: 1Gi |
| service.annotations | object | `{}` | Service annotations for cloud provider integrations Example for AWS NLB:   service.beta.kubernetes.io/aws-load-balancer-type: "nlb"   service.beta.kubernetes.io/aws-load-balancer-internal: "true" Example for GCP Internal Load Balancer:   cloud.google.com/load-balancer-type: "Internal" Example for Azure Internal LB:   service.beta.kubernetes.io/azure-load-balancer-internal: "true" |
| service.enableHttps | bool | `false` | Adds a port named "https" targeting the container's https port |
| service.httpsPort | int | `443` | HTTPS service port (when enableHttps=true) |
| service.port | int | `80` | HTTP service port (external port that clients connect to) |
| service.type | string | `"ClusterIP"` | NodePort: Expose on each node's IP at a static port |
| serviceAccount.annotations | object | `{}` | Example for GCP Workload Identity: iam.gke.io/gcp-service-account: SA_NAME@PROJECT.iam.gserviceaccount.com |
| serviceAccount.create | bool | `true` | Required for Vault integration, IRSA (AWS), Workload Identity (GCP), or pod identity features |
| serviceAccount.name | string | `""` | If not set and create=false, uses "default" |
| strategy | object | `{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0},"type":"RollingUpdate"}` | See https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy |
| strategy.rollingUpdate.maxSurge | int | `1` | Maximum number of pods that can be created over desired replicas (can be absolute number or percentage) |
| strategy.rollingUpdate.maxUnavailable | int | `0` | Maximum number of pods that can be unavailable during update (can be absolute number or percentage) |
| strategy.type | string | `"RollingUpdate"` | Strategy type: RollingUpdate or Recreate |
| tolerations | list | `[]` | Example: Tolerate nodes with specific workload taint  - key: "workload"    operator: "Equal"    value: "application"    effect: "NoSchedule" |
| topologySpreadConstraints | object | `{"disabled":false,"maxSkew":1,"topologyKey":"kubernetes.io/hostname","whenUnsatisfiable":"ScheduleAnyway"}` | Topology spread constraints settings. See https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ |
| topologySpreadConstraints.disabled | bool | `false` | If true, topology spread constraints will not be applied. |
| topologySpreadConstraints.maxSkew | int | `1` | The maximum skew between topologies. |
| topologySpreadConstraints.topologyKey | string | `"kubernetes.io/hostname"` | The key for topology domain. |
| topologySpreadConstraints.whenUnsatisfiable | string | `"ScheduleAnyway"` | What to do when a pod doesn't satisfy the spread constraint. |
| volumeMounts | list | `[]` | Tips:    - Use subPath to mount single files instead of entire volumes    - Set readOnly: true for config/secret mounts (security best practice)    - Ensure mountPath doesn't conflict with application directories |
| volumes | list | `[]` | Common volume types:    - configMap: Mount config files from ConfigMap    - secret: Mount sensitive data from Secret    - emptyDir: Temporary storage (cleared on pod restart)    - persistentVolumeClaim: Persistent storage |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
