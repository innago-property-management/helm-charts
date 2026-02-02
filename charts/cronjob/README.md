# cronjob

![Version: 2.0.2](https://img.shields.io/badge/Version-2.0.2-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.36.1](https://img.shields.io/badge/AppVersion-1.36.1-informational?style=flat-square)

Innago Helm Chart for deploying a CronJob

**Homepage:** <https://innago-property-management.github.io/helm-charts/cronjob>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Innago | <support@innago.com> |  |

## Source Code

* <https://github.com/innago-property-management/helm-charts/tree/main/charts/cronjob>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| additionalContainers | list | `[]` | Additional containers to run alongside the main job container See https://kubernetes.io/docs/concepts/workloads/pods/ |
| affinity | object | `{}` |  |
| args | list | `[]` | Arguments to pass to command (or to container ENTRYPOINT if command not set) |
| command | list | `["/bin/sh","-c","date; echo Hello!"]` | Command to run in the container (overrides ENTRYPOINT) |
| containerEnvFrom | list | `[]` |  |
| containerEnvironmentVariables | list | `[]` |  |
| containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsGroup":65534,"runAsNonRoot":true,"runAsUser":65534}` | Container-level security context See https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| cronjob | object | `{"concurrencyPolicy":"Forbid","failedJobsHistoryLimit":5,"startingDeadlineSeconds":300,"successfulJobsHistoryLimit":3,"suspend":false}` | CronJob-specific configuration |
| cronjob.concurrencyPolicy | string | `"Forbid"` | Concurrency policy: Allow, Forbid, or Replace - Allow: allows concurrent jobs (default) - Forbid: skips new job if previous is still running - Replace: replaces currently running job with new job |
| cronjob.failedJobsHistoryLimit | int | `5` | Number of failed job history to retain |
| cronjob.startingDeadlineSeconds | int | `300` | Deadline in seconds for starting the job if it misses scheduled time If not set, jobs have no deadline |
| cronjob.successfulJobsHistoryLimit | int | `3` | Number of successful job history to retain |
| cronjob.suspend | bool | `false` | Suspend cron job execution (useful for maintenance) |
| fullnameOverride | string | `""` |  |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"busybox","tag":""}` | Container image configuration |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy (Always, IfNotPresent, Never) |
| image.repository | string | `"busybox"` | Container registry and repository |
| image.tag | string | `""` | Image tag override (defaults to Chart.appVersion) IMPORTANT: Do not use "latest" in production |
| imagePullSecrets | list | `[]` |  |
| initContainers | list | `[]` | Init containers to run before the main job container See https://kubernetes.io/docs/concepts/workloads/pods/init-containers/ |
| job | object | `{"activeDeadlineSeconds":600,"backoffLimit":3}` | Job-level configuration (applied to each job created) |
| job.activeDeadlineSeconds | int | `600` | Maximum duration in seconds for job to complete Job will be terminated if it exceeds this time |
| job.backoffLimit | int | `3` | Number of retries before marking job as failed |
| metrics | object | `{"enabled":false,"path":"/metrics","port":8080,"serviceMonitor":{"enabled":false,"interval":"30s","labels":{},"namespace":"","scrapeTimeout":"10s"}}` | Metrics configuration |
| metrics.enabled | bool | `false` | Enable metrics endpoint (if job supports it) |
| metrics.path | string | `"/metrics"` | Metrics endpoint path |
| metrics.port | int | `8080` | Metrics endpoint port |
| metrics.serviceMonitor | object | `{"enabled":false,"interval":"30s","labels":{},"namespace":"","scrapeTimeout":"10s"}` | ServiceMonitor configuration for Prometheus Operator |
| metrics.serviceMonitor.enabled | bool | `false` | Enable ServiceMonitor creation |
| metrics.serviceMonitor.interval | string | `"30s"` | Scrape interval |
| metrics.serviceMonitor.labels | object | `{}` | Additional labels for ServiceMonitor |
| metrics.serviceMonitor.namespace | string | `""` | ServiceMonitor namespace (defaults to release namespace) |
| metrics.serviceMonitor.scrapeTimeout | string | `"10s"` | Scrape timeout |
| nameOverride | string | `""` |  |
| networkPolicy | object | `{"egress":{"customRules":[],"dns":{"enabled":true},"enabled":false},"enabled":false}` | Network policy configuration |
| networkPolicy.egress | object | `{"customRules":[],"dns":{"enabled":true},"enabled":false}` | Egress rules configuration |
| networkPolicy.egress.customRules | list | `[]` | Custom egress rules |
| networkPolicy.egress.dns | object | `{"enabled":true}` | DNS egress configuration |
| networkPolicy.egress.dns.enabled | bool | `true` | Allow DNS resolution |
| networkPolicy.egress.enabled | bool | `false` | Enable egress rules (restricts outbound traffic) |
| networkPolicy.enabled | bool | `false` | Enable NetworkPolicy creation |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{"fsGroup":65534,"runAsGroup":65534,"runAsNonRoot":true,"runAsUser":65534,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod-level security context See https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| resources | object | `{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Resource requests and limits See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ |
| schedule | string | `"0 */2 * * *"` | Cron schedule in standard cron format Format: "minute hour day month weekday" Examples:   "*/5 * * * *"     - Every 5 minutes   "0 */2 * * *"     - Every 2 hours   "0 0 * * *"       - Daily at midnight   "0 0 * * 0"       - Weekly on Sunday Tip: Use https://crontab.guru for help |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| tolerations | list | `[]` |  |
| ttlSecondsAfterFinished | string | `nil` |  |
| volumeMounts | list | `[]` | Volume mounts for the main container See https://kubernetes.io/docs/concepts/storage/volumes/ |
| volumes | list | `[]` | Volumes to mount in the job pod See https://kubernetes.io/docs/concepts/storage/volumes/ |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
