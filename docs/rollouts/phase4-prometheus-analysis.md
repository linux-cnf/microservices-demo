# Phase 4 - Prometheus Based Argo Rollouts Analysis

## Objective

Validate that Argo Rollouts can automatically evaluate Prometheus metrics during a canary deployment and stop promotion when application health degrades.

---

## Architecture

Browser
→ Frontend Rollout
→ Argo Rollouts
→ AnalysisRun
→ Prometheus
→ Rollout Decision

Argo Rollouts executes AnalysisRuns during canary steps and queries Prometheus to determine whether the rollout should continue, pause, or abort.

---

## Analysis Template

AnalysisTemplate:

```yaml
frontend-success-rate
```

Configured metrics:

1. frontend-pod-availability
2. frontend-failed-probe-rate
3. frontend-restart-increase
4. frontend-readiness-latency-p95

---

## Canary Strategy

```yaml
steps:
- setWeight: 10
- pause: { duration: 2m }
- analysis:
    templates:
    - templateName: frontend-success-rate
- setWeight: 25
- pause: { duration: 2m }
- setWeight: 50
- pause: { duration: 2m }
- setWeight: 100
```

---

## Metric Definitions

### 1. Frontend Pod Availability

Purpose:

Ensure frontend pods are Ready during rollout.

Prometheus Query:

```promql
sum(kube_pod_status_ready{
  namespace="boutique",
  condition="true",
  pod=~"frontend-.*"
})
```

Success Condition:

```yaml
result[0] >= 1
```

---

### 2. Failed Probe Rate

Purpose:

Detect readiness/liveness probe failures.

Prometheus Query:

```promql
sum(rate(
  prober_probe_total{
    namespace="boutique",
    pod=~"frontend-.*",
    result="failed"
  }[5m]
)) or vector(0)
```

Success Condition:

```yaml
result[0] == 0
```

---

### 3. Container Restart Increase

Purpose:

Detect application instability during rollout.

Prometheus Query:

```promql
sum(increase(
  kube_pod_container_status_restarts_total{
    namespace="boutique",
    pod=~"frontend-.*"
  }[5m]
)) or vector(0)
```

Success Condition:

```yaml
result[0] == 0
```

---

### 4. Readiness Latency P95

Purpose:

Detect slow application startup or degraded readiness behavior.

Prometheus Query:

```promql
histogram_quantile(
  0.95,
  sum(
    rate(
      prober_probe_duration_seconds_bucket{
        namespace="boutique",
        pod=~"frontend-.*",
        probe_type="Readiness"
      }[5m]
    )
  ) by (le)
)
```

Success Condition:

```yaml
result[0] < 0.5
```

---

# Validation Results

## Success Scenario

A rollout was triggered by modifying:

```yaml
PHASE4_METRIC_TEST
```

which generated a new Rollout revision and AnalysisRun.

Result:

```text
AnalysisRun: Successful
Rollout: Healthy
Argo CD Application: Synced / Healthy
```

All metrics passed:

```text
frontend-pod-availability      Successful
frontend-failed-probe-rate     Successful
frontend-restart-increase      Successful
frontend-readiness-latency-p95 Successful
```

---

## Failure Scenario

To validate rollback protection, the AnalysisTemplate was intentionally modified.

Original:

```yaml
successCondition: result[0] >= 1
```

Test Failure Condition:

```yaml
successCondition: result[0] >= 999
```

Expected Result:

```text
Metric evaluation fails
AnalysisRun becomes Failed
Rollout becomes Degraded
Rollout promotion stops
```

Observed Result:

```text
AnalysisRun: Failed
Rollout: Degraded
Reason:
Metric "frontend-pod-availability"
assessed Failed due to failed (2)
> failureLimit (1)
```

This confirmed that Argo Rollouts correctly blocked promotion when analysis conditions failed.

---

## Recovery Scenario

The AnalysisTemplate was restored:

```yaml
successCondition: result[0] >= 1
```

The rollout was recovered using:

```bash
kubectl argo rollouts retry rollout frontend -n boutique
```

Result:

```text
New AnalysisRun created
AnalysisRun: Successful
Rollout: Healthy
```

Observed:

```text
frontend-79b5766cc6-4-2     Failed
frontend-79b5766cc6-4-2.1   Successful
```

This validated recovery from an aborted rollout without requiring a new deployment.

---

# Commands Used

Trigger rollout:

```bash
./scripts/trigger-frontend-rollout-analysis.sh
```

Watch rollout:

```bash
kubectl argo rollouts get rollout frontend -n boutique --watch
```

Watch AnalysisRuns:

```bash
kubectl get analysisrun -n boutique -w
```

Describe AnalysisRun:

```bash
kubectl describe analysisrun <name> -n boutique
```

Retry failed rollout:

```bash
kubectl argo rollouts retry rollout frontend -n boutique
```

---

# Conclusion

Phase 4 successfully demonstrated:

* Prometheus-based rollout verification
* Automated metric evaluation
* Canary promotion gating
* Automatic rollout abortion on failed metrics
* Recovery using rollout retry
* GitOps integration with Argo CD

The platform now supports metric-driven deployment validation and safe progressive delivery.

Next Phase:

**Phase 5 - Istio Traffic-Based Canary Deployments**

