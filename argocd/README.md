# Argo CD GitOps control plane

This directory defines the app-of-apps control plane for development and
production. Argo CD reconciles the desired state in this repository, prunes
removed resources, and self-heals drift for Applications with automated sync.

## Environment roots

| Manifest | Branch | Child applications |
| --- | --- | --- |
| `platform-root-app-dev.yaml` | `develop` | `argocd/apps/dev` |
| `platform-root-app-prod.yaml` | `main` | `argocd/apps/prod` |
| `platform-root-app.yaml` | `main` | Legacy/general `argocd/apps` set |

Use the environment-specific roots for current deployments. The dev and prod
directories keep source revisions, values files, namespaces, and workload
overlays explicit rather than relying on runtime branch substitution.

```bash
kubectl apply -f argocd/platform-root-app-dev.yaml   # development cluster
kubectl apply -f argocd/platform-root-app-prod.yaml  # production cluster
```

Argo CD itself must already be installed and able to reach this repository.
The bootstrap values are in `bootstrap/values.yaml`; health and notification
configuration lives in `argocd-cm-health-patch.yaml` and
`argocd-notifications-cm.yaml`.

## Managed platform

The environment application sets deploy:

- External Secrets Operator and Google Secret Manager-backed resources
- ECK, Elasticsearch/Kibana, and Elastic Agent
- Prometheus/Grafana/Alertmanager observability
- Tempo/OpenTelemetry tracing
- Argo Rollouts
- Istio base, control plane, ingress gateway, and Kiali
- the environment-specific Online Boutique Kustomize overlay
- a scheduled Argo CD health report

Argo Projects constrain source repositories and destinations. Sync-wave
annotations order prerequisites such as namespaces, operators, and CRDs before
their consumers. Consult the annotations in the environment manifests for the
authoritative ordering; different resources can share a wave.

The optional AI Application is under
`optional-apps/ai-platform/manifests/ai-platform.yaml`. It tracks `main` and is
not included in either root app automatically. The supported AI workflow is
currently production-only.

## Branch and workload mapping

```text
develop -> argocd/apps/dev  -> kustomize/environments/dev
main    -> argocd/apps/prod -> kustomize/environments/prod
```

The Boutique Applications deploy Argo Rollouts-enabled overlays. The production
rollout uses `argocd/apps/argo-rollouts`; development uses the reduced-resource
`argocd/apps/argo-rollouts-dev` customization.

## Secrets and notifications

Secret values are not stored here. External Secrets Operator uses Workload
Identity to read Google Secret Manager and materialize Kubernetes Secrets. The
notification ConfigMap references the `argocd-notifications-secret`; populate
its backing secret through the configured ExternalSecret before expecting Slack
notifications.

## Operations

```bash
kubectl get applications,appprojects -n argocd
kubectl describe application <name> -n argocd
kubectl get externalsecrets -A
kubectl get rollouts,analysisruns -A

# Force Argo CD to re-read an Application source
kubectl annotate application <name> -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

With the Argo CD CLI configured:

```bash
argocd app list
argocd app get <name>
argocd app diff <name>
```

Avoid fixing drift with persistent imperative edits: update the appropriate
`develop` or `main` source and let Argo CD reconcile it. See
[HEALTH-CUSTOMIZATION.md](HEALTH-CUSTOMIZATION.md) for custom health behavior.
