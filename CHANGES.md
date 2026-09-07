# Chart Changes: `webapp` and `fake-job`

Chart-level history for the two charts that changed during the September 2026 work.
For the Argo CD side of it — which environments were migrated, where to set the new
values, and what to check before moving `prod` — see
[webapp-fakejob-chart-updates.md](https://github.com/innago-property-management/argocd-shared/blob/main/docs/webapp-fakejob-chart-updates.md)
in `argocd-shared`.

Each chart's `artifacthub.io/changes` annotation carries the same information per
release; this file collects it in one place with the reasoning behind each change.

## Versions at a glance

| webapp | Date | Theme |
|--------|------|-------|
| [3.4.0](#webapp-340) | unreleased | CPU metric can be switched off for memory-only scaling |
| [3.3.0](#webapp-330) | 2026-09-07 | HPA scales on memory as well as CPU |
| [3.2.2](#webapp-322) | 2026-09-07 | Stop deleting the ServiceAccount on every sync |
| [3.2.1](#webapp-321) | 2026-09-03 | Migration cleanup also prunes pre-3.1.0 jobs |
| [3.2.0](#webapp-320) | 2026-09-03 | ReplicaSet retention, replica floor removed, values-driven job knobs |
| [3.1.0](#webapp-310) | 2026-09-03 | Migration job history limit |
| [3.0.0](#webapp-300) | 2026-09-03 | Vault-role ConfigMap becomes opt-in |

| fake-job | Date | Theme |
|----------|------|-------|
| [1.0.4](#fake-job-104) | 2026-09-03 | ReplicaSet retention, replicas clamped to 0..1, values-driven config |
| [1.0.3](#fake-job-103) | 2026-09-03 | Imported into this repository |

---

## webapp 3.4.0

**Unreleased.**

### Added

- **CPU scaling can be switched off, for memory-only autoscaling.** Set
  `autoscaling.targetCPUUtilizationPercentage` to `null`, `0` or `false` and the CPU
  metric is dropped, leaving the HPA scaling on memory alone. The two targets are now
  symmetric — either can be disabled the same way:

  | `targetCPUUtilizationPercentage` | `targetMemoryUtilizationPercentage` | HPA metrics |
  |---|---|---|
  | `80` | `80` | CPU + memory (default) |
  | `null` / `0` / `false` | `80` | memory only |
  | `80` | `null` / `0` / `false` | CPU only |
  | disabled | disabled | **rendering fails** |

  Disabling both is rejected with an explicit message rather than rendering an HPA with
  an empty `metrics` list, because Kubernetes silently defaults such an HPA to an 80%
  CPU target — autoscaling on something nobody configured. The check only applies when
  `autoscaling.enabled` is true, so clearing both targets on a release that does not
  autoscale is still fine.

---

## webapp 3.3.0

### Changed

- **The HPA now scales on memory as well as CPU by default.**
  `autoscaling.targetMemoryUtilizationPercentage` defaults to `80` instead of `null`.
  A pod that is memory bound rather than CPU bound would otherwise never trigger a
  scale-up.

  To scale on CPU only, disable it explicitly in the values override:

  ```yaml
  autoscaling:
    targetMemoryUtilizationPercentage: null   # or 0 / false
  ```

  The metric is a **`ContainerResource`** metric scoped to the application container,
  not a pod-wide `Resource` metric. A `Resource` metric sums requests across every
  container in the pod, so a single sidecar added through `additionalContainers`
  without a memory request would make the metric `<unknown>` — and an unavailable
  metric stops the HPA scaling **entirely**, including on CPU. Scoping it to the
  application container keeps sidecars out of the calculation.
  `ContainerResource` is GA from Kubernetes 1.30; all Innago clusters run 1.34.

  The application container still needs a memory request. The chart sets
  `resources.requests.memory: 128Mi` by default and that survives a partial
  `resources` override, so this works unless the request is deliberately removed.

  CPU remains a pod-wide `Resource` metric, unchanged, so existing HPA behaviour is
  not altered.


---

## webapp 3.2.2

### Fixed

- **The ServiceAccount is no longer deleted on every sync.** The ServiceAccount, Role
  and RoleBinding carried `helm.sh/hook-delete-policy: before-hook-creation`, so Argo CD
  deleted the account at the start of every sync before recreating it. Any sync that did
  not finish the recreation left the Deployment permanently unable to start pods:

  ```
  pods "instant-payout-webapp-5db4989565-" is forbidden: error looking up service account
  instant-payout/instant-payout-webapp: serviceaccount "instant-payout-webapp" not found
  ```

  On qa this took out 6 of 76 webapp deployments, each stuck at 0/2 and missing its
  ServiceAccount, Role *and* RoleBinding — all three are deleted together. Nothing
  distinguished the affected releases in configuration; they simply lost the race
  between deletion and recreation, so which apps broke was arbitrary.

  The `pre-install,pre-upgrade` hook and weight `-10` remain: the migration job is a
  PreSync hook that mounts this account, so it must exist in the same phase. Only the
  delete policy is gone, because the account is a long-lived dependency of the
  Deployment rather than a throwaway bootstrap object. The migration jobs keep
  `before-hook-creation`, where recreation is the point.

  Latent since 2.6.x. It surfaced when qa moved from 2.0.x to 3.2.1, converting 76
  ServiceAccounts from tracked resources into delete-on-every-sync hooks at once.

- **Replaced an invalid Argo CD sync option.** The ServiceAccount carried
  `argocd.argoproj.io/sync-options: PreserveResources=true`, which is not a recognised
  sync option and was silently ignored — so the protection it looked like it provided
  did not exist. Now `Prune=false`, on the ServiceAccount, Role and RoleBinding.

---

## webapp 3.2.1

### Fixed

- **Migration history cleanup now prunes jobs created before 3.1.0.** The cleanup hook
  selected on `app.kubernetes.io/component=migrations`, a label only added in 3.1.0, so
  jobs from older charts were invisible to it. In `innago-merlin` the hook ran, matched
  1 job out of 56, and deleted nothing.

  It now selects on labels every chart version has always set, and excludes itself:

  ```
  app.kubernetes.io/name=<fullname>,app.kubernetes.io/instance=<release>,app.kubernetes.io/component!=migrations-cleanup
  ```

  A `key!=value` selector also matches objects that lack the key entirely, which is what
  brings the legacy jobs into scope.

---

## webapp 3.2.0

### Added

- **ReplicaSet retention.** `revisionHistoryLimit` now defaults to **3**; Kubernetes
  retains 10 when the field is unset, so every deployment left up to ten old
  ReplicaSets behind. Note the limit counts *old* ReplicaSets, so 4 total (3 + the
  active one) is the expected steady state.
- **Migration job timings are values, not literals.** `migrationJob.backoffLimit` (3),
  `migrationJob.activeDeadlineSeconds` (300), `migrationJob.cleanupBackoffLimit` (1),
  `migrationJob.cleanupActiveDeadlineSeconds` (120) and
  `migrationJob.cleanupTtlSecondsAfterFinished` (300). Each defaults to the number that
  was previously hardcoded, so nothing changes unless overridden.

### Changed

- **BREAKING: `replicaCount` and `autoscaling.minReplicas` are honoured as written,
  including `0`.** The templates previously rendered
  `replicas: {{ max 2 .Values.replicaCount }}` and
  `minReplicas: {{ max 2 .Values.autoscaling.minReplicas }}`, silently raising any lower
  value. Supporting scale-to-zero required removing that floor.

  Consequence: a release with `replicaCount: 1` was quietly running **2** pods and now
  runs 1. Review values files before upgrading an environment — in dev, 97 of them set
  `replicaCount: 1`.

  `maxReplicas` is still clamped to `max 1 minReplicas maxReplicas`, since the HPA API
  rejects `maxReplicas: 0`. Scaling an HPA to zero additionally needs the
  `HPAScaleToZero` feature gate; scaling a Deployment to zero via `replicaCount: 0`
  does not.

### Note

`migrationJob.annotations` used to suggest setting `ttlSecondsAfterFinished` there.
That never worked — it is a Job **spec** field, not an annotation. Use
`migrationJob.historyLimit`.

---

## webapp 3.1.0

### Added

- **Migration job history limit.** `migrationJob.historyLimit` (default **3**) with a
  `post-install,post-upgrade` hook that deletes all but the newest N.

  Migration jobs are named after a hash of the migration image, so every new migration
  image produced a differently named Job. `before-hook-creation` only replaces a hook
  resource of the *same* name, and Kubernetes has no history limit for standalone Jobs
  (only `CronJob` has `successfulJobsHistoryLimit`), so every migration ever run stayed
  in the namespace with a `Completed` pod attached. One cluster had 1,667 such jobs.

  Supporting pieces: an `app.kubernetes.io/component: migrations` label on the migration
  job, `delete` on `jobs` added to the release Role only when the cleanup is active, and
  `migrationJob.cleanupImage` (`alpine/kubectl:1.34.1` — the image needs `kubectl` *and*
  a shell, which `registry.k8s.io/kubectl` and `rancher/kubectl` do not provide).
  Set `historyLimit: 0` to keep everything and skip the hook entirely.

---

## webapp 3.0.0

### Changed

- **BREAKING: `innagoVaultK8sRoleOperator.use` now defaults to `false`.** The vault-role
  ConfigMap is opt-in. Releases that relied on the old default stop having their Vault
  role created or refreshed; add `innagoVaultK8sRoleOperator: {use: true}` to keep it.
- **BREAKING: the vault-role ConfigMap is a normal release resource**, not a
  `pre-install,pre-upgrade` hook, so it is removed on uninstall instead of being
  orphaned.

  Upgrade note: a release that already has the ConfigMap from a hook has no Helm
  ownership metadata on it, so a plain `helm upgrade` can fail with *"exists and cannot
  be imported into the current release"*. Argo CD's `ServerSideApply=true` on the
  resource adopts it instead, so the GitOps path is unaffected.

### Added

- Standard chart labels on the vault-role ConfigMap, so it is selectable by
  `app.kubernetes.io/instance` like every other resource.

### Fixed

- The `networkPolicy`, `metrics`/`serviceMonitor`, `vpa` and `innagoVaultK8sRoleOperator`
  gates are nil-safe and default to disabled — nulling or removing one of those blocks
  disables the feature instead of failing template rendering with
  `nil pointer evaluating interface {}`.
- The vault-role ConfigMap name no longer ends up with a double hyphen when the release
  fullname is truncated.

---

## fake-job 1.0.4

### Added

- **ReplicaSet retention**, matching webapp: `revisionHistoryLimit` defaults to **3**.
- **`replicaCount`, `revisionHistoryLimit`, `httpContainerPort` and `containerEnvFrom`
  are configurable from values.** `replicas` was hardcoded to 1, and the last two were
  read by the template but never declared, so they could not be discovered from
  `values.yaml`.
- **Replicas are clamped to 0..1 and follow the paired webapp.** This chart runs at most
  one worker, but its Argo CD application shares a values file with its webapp sibling,
  where `replicaCount` is written for the webapp:

  ```gotemplate
  {{- $desired := .Values.replicaCount -}}
  {{- $autoscaling := default dict .Values.autoscaling -}}
  {{- if $autoscaling.enabled -}}
  {{- $desired = $autoscaling.minReplicas -}}
  {{- end }}
  replicas: {{ if kindIs "invalid" $desired }}1{{ else }}{{ max 0 (min 1 (int $desired)) }}{{ end }}
  ```

  So webapp >= 1 replica means 1 here, and webapp at 0 means 0. Three deliberate
  choices:

  1. `autoscaling.minReplicas` governs when autoscaling is on, because `replicaCount` is
     then the value the webapp itself ignores.
  2. Values above 1 are clamped rather than rejected — a `fail` would break this
     application's sync whenever somebody legitimately raises the webapp to 2 replicas.
  3. `kindIs "invalid"` instead of `| default`, because Sprig's `default` treats `0` as
     empty and would make scale-to-zero impossible.

  This chart creates no HPA. It only *reads* `autoscaling.minReplicas` to infer the
  paired webapp's intent; with no such block it falls back to `replicaCount`.

---

## fake-job 1.0.3

### Added

- **Imported into this repository** from an external registry
  (`tcr.taazaa.cloud/shared` @ 1.0.2), and published alongside every other Innago chart
  at `ghcr.io/innago-property-management/helm-charts`.
- Chart metadata to match the other charts here — icon, `home`, `sources`, maintainers,
  keywords and the `artifacthub.io/*` annotations — plus a README and real post-install
  notes in place of a `TODO`.

`values.yaml` was kept byte-identical to the imported 1.0.2 chart in this release, so
existing releases render unchanged; the new keys arrived in 1.0.4.

---

## Breaking changes by version

| Version | Breaking change | Action |
|---------|-----------------|--------|
| 3.0.0 | `innagoVaultK8sRoleOperator.use` defaults to `false` | add `use: true` where the Vault role is needed |
| 3.0.0 | vault-role ConfigMap is a tracked resource | none under Argo CD; plain `helm upgrade` may need the old ConfigMap removed |
| 3.2.0 | replica floor of 2 removed | set `replicaCount: 2` where two pods are expected |
| 3.3.0 | HPA scales on memory by default | set `targetMemoryUtilizationPercentage: null` for CPU-only |

Upgrading from 2.x, go straight to **3.2.2 or later**: 3.2.0 and 3.2.1 delete the
ServiceAccount on every sync and can leave a Deployment permanently unable to start.
