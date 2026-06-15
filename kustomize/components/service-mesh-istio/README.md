# Service Mesh Istio Component

This component enables Istio service mesh capabilities for the Boutique application.

## Purpose

The goal of this component is to improve:

* Service-to-service security
* Traffic visibility
* Least-privilege communication
* Resilience testing
* Operational observability

---

## Kiali

### What is Kiali?

Kiali is the visualization and management dashboard for Istio.

It provides:

* Service dependency graph
* Request rates
* Error rates
* Latency metrics
* mTLS visibility
* Traffic flow analysis

### Access Kiali

```bash
kubectl port-forward svc/kiali -n istio-system 20001:20001
```

Open:

```text
http://localhost:20001
```

Generate traffic:

```bash
for i in {1..100}; do
  curl -s -o /dev/null http://34.45.27.5
done
```

Navigate to:

```text
Graph -> Namespace: boutique
```

---

## PeerAuthentication (mTLS)

### What is PeerAuthentication?

PeerAuthentication controls whether service-to-service communication uses mTLS.

Current configuration:

```yaml
mtls:
  mode: STRICT
```

### Why STRICT?

STRICT mode ensures:

* All service-to-service traffic is encrypted
* Service identities are verified
* Plain-text traffic is rejected
* Non-mesh workloads cannot communicate directly

### Validation

Create a namespace without Istio sidecars:

```bash
kubectl create ns mtls-test

kubectl run plain-client -n mtls-test \
  --image=curlimages/curl \
  --restart=Never \
  -- sleep 3600
```

Attempt to access a mesh-protected service:

```bash
kubectl exec -n mtls-test plain-client -- \
  curl -s -o /dev/null -w "%{http_code}\n" \
  http://frontend.boutique.svc.cluster.local:80
```

Expected:

```text
000
```

This proves STRICT mTLS is enforced.

Cleanup:

```bash
kubectl delete ns mtls-test
```

---

## AuthorizationPolicy

### What is AuthorizationPolicy?

AuthorizationPolicy controls which workloads are allowed to communicate.

Unlike NetworkPolicy which works at network/IP level, AuthorizationPolicy works using workload identity and service accounts.

### Current Service Access Rules

```text
istio-ingressgateway -> frontend

frontend -> productcatalogservice
frontend -> recommendationservice
frontend -> cartservice
frontend -> checkoutservice
frontend -> currencyservice
frontend -> shippingservice

checkoutservice -> paymentservice
checkoutservice -> emailservice
checkoutservice -> shippingservice
checkoutservice -> productcatalogservice
checkoutservice -> cartservice
checkoutservice -> currencyservice

cartservice -> redis-cart
```

### Active Policies

```bash
kubectl get authorizationpolicy -n boutique
```

Expected:

```text
cartservice-allow-required-callers
checkoutservice-allow-frontend
currencyservice-allow-required-callers
emailservice-allow-checkoutservice
frontend-allow-ingressgateway
paymentservice-allow-checkoutservice
productcatalogservice-allow-required-callers
recommendationservice-allow-frontend
redis-cart-allow-cartservice
shippingservice-allow-required-callers
```

### Negative Validation

Create an unauthorized pod:

```bash
kubectl run test-client -n boutique \
  --image=curlimages/curl \
  --restart=Never \
  -- sleep 3600
```

Attempt access:

```bash
kubectl exec -n boutique test-client -- \
  curl -s -o /dev/null -w "%{http_code}\n" \
  http://productcatalogservice:3550/products
```

Expected:

```text
403
```

This proves unauthorized workloads are blocked.

Cleanup:

```bash
kubectl delete pod test-client -n boutique
```

---

## Fault Injection

### What is Fault Injection?

Fault injection intentionally introduces failures into application traffic to validate resilience.

Common scenarios:

* Slow backend responses
* Service failures
* Network instability
* Dependency outages

### Why not managed by GitOps?

Fault injection is intended for temporary testing.

Keeping it permanently enabled in Argo CD could impact normal application traffic.

Therefore:

```text
Git tracked
Not permanently deployed
Activated only during testing
```

### Available Fault Tests

#### Delay Test

Simulates backend latency.

Enable:

```bash
./scripts/run-recommendationservice-fault-test.sh delay
```

Validation:

```bash
for i in {1..30}; do
  curl -s -o /dev/null -w "%{time_total}\n" http://34.45.27.5
done
```

Expected:

```text
Most requests around 0.7s
Some requests around 2-4s
```

#### Abort Test

Simulates backend HTTP 500 errors.

Enable:

```bash
./scripts/run-recommendationservice-fault-test.sh abort
```

Validation:

```bash
for i in {1..50}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://34.45.27.5
done | sort | uniq -c
```

Expected:

```text
Mostly HTTP 200
Some HTTP 500
Or graceful fallback behavior
```

#### Cleanup

Disable fault injection:

```bash
./scripts/run-recommendationservice-fault-test.sh clean
```

---

## Validation Commands

### Verify Argo CD

```bash
kubectl get application -n argocd
```

### Verify mTLS

```bash
kubectl get peerauthentication -n boutique
```

### Verify Authorization Policies

```bash
kubectl get authorizationpolicy -n boutique
```

### Verify Istio Routing

```bash
kubectl get virtualservice -n boutique
```

### Verify Application

```bash
curl -I http://34.45.27.5
```

Expected:

```text
HTTP/1.1 200 OK
```

---

## Interview Summary

Phase 6 focused on improving security, visibility, and resilience within the service mesh.

Implemented features:

* Kiali for service dependency visualization and traffic analysis
* STRICT mTLS using PeerAuthentication
* Service-specific AuthorizationPolicies using least-privilege principles
* Negative security validation proving unauthorized traffic is blocked
* Fault injection framework for latency and failure testing
* Reusable operational script for resilience testing

Key achievements:

* Removed broad namespace-level allow policy
* Implemented workload-specific access control
* Validated mTLS enforcement
* Validated AuthorizationPolicy enforcement
* Added repeatable resilience testing workflows

This phase demonstrates practical service mesh security and operational readiness using Istio.

