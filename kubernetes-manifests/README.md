# ./kubernetes-manifests

:warning: Kubernetes manifests provided in this directory are not directly
deployable to a cluster. They are meant to be used with `skaffold` command to
insert the correct `image:` tags.

Use the manifests in [/release](/release) directory which are configured with
pre-built public images.

#adding a below note to understand "diff kubernetes-manifests/frontend.yaml kustomize/base/frontend.yaml"
kubernetes-manifests contains static Kubernetes YAMLs that can be applied directly using kubectl apply -f. kustomize/base contains reusable base manifests managed by Kustomize, allowing environment-specific overlays (dev, staging, prod) to customize configurations without duplicating YAML. In production GitOps environments, Kustomize is commonly used because it improves maintainability and reduces manifest duplication
