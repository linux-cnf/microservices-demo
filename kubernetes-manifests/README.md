# Kubernetes manifests

These service manifests are the direct-deployment/Skaffold source for Online
Boutique. Skaffold replaces their image references when it builds and deploys
the application.

For a prebuilt, versioned direct deployment, use
[`release/kubernetes-manifests.yaml`](../release/kubernetes-manifests.yaml).
For the current environment-aware GitOps deployment, use the overlays under
[`kustomize/environments`](../kustomize/environments); Argo CD owns those
resources in dev and prod.

Render this directory's Kustomization without applying it:

```bash
kubectl kustomize kubernetes-manifests >/tmp/online-boutique.yaml
```

Do not assume these manifests and `kustomize/base` are interchangeable. The
latter includes platform-specific reliability and rollout behavior used by the
environment overlays.
