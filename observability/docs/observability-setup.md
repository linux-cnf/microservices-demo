# 🚀 Observability Setup (Prometheus + Grafana + Blackbox)

This document describes how to set up monitoring for the microservices demo in a reproducible, production-style way.

---

# 📦 1. Deploy Application

```bash
kubectl apply -f release/kubernetes-manifests.yaml
```

Verify:

```bash
kubectl get pods
kubectl get svc
```

---

# 🧱 2. Create Monitoring Namespace

```bash
kubectl apply -f observability/monitoring/namespace.yaml
```

---

# 📊 3. Install Prometheus + Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f observability/monitoring/kube-prometheus-stack/values.yaml
```

Verify:

```bash
kubectl get pods -n monitoring
```

---

# 🔍 4. Access Prometheus & Grafana

## Step 1: Create SSH tunnel

```bash
./observability/access/ssh-tunnel.sh
```

## Step 2: Port forward services

```bash
./observability/access/port-forward-grafana.sh
./observability/access/port-forward-prometheus.sh
```

## Access URLs

* Grafana → http://127.0.0.1:3000
* Prometheus → http://127.0.0.1:9090

---

# 🔐 5. Grafana Login

Default credentials:

```text
username: admin
password: admin
```

(Defined in values.yaml)

---

# 📦 6. Install Blackbox Exporter

```bash
helm upgrade --install blackbox prometheus-community/prometheus-blackbox-exporter \
  -n monitoring \
  -f observability/monitoring/blackbox/values.yaml
```

Verify:

```bash
kubectl get pods -n monitoring | grep blackbox
```

---

# 🧪 7. Apply ServiceMonitor and Probes

```bash
kubectl apply -f observability/monitoring/blackbox/blackbox-servicemonitor.yaml
kubectl apply -f observability/monitoring/blackbox/all-services-probes.yaml
```

Verify:

```bash
kubectl get probe -n monitoring
kubectl get servicemonitor -n monitoring
```

---

# 📊 8. Import Grafana Dashboards

Go to Grafana:

👉 Dashboards → Import

Import:

* observability/monitoring/grafana/dashboards/cpu-dashboard.json
* observability/monitoring/grafana/dashboards/blackbox-probes-dashboard.json

Select Prometheus datasource when prompted.

---

# 🔍 9. Verify Metrics in Prometheus

Open Prometheus UI and run:

```promql
probe_success
```

```promql
probe_duration_seconds
```

```promql
container_cpu_usage_seconds_total
```

---

# 🧠 Key Concepts

## Prometheus

* Collects and stores metrics
* Uses pull-based scraping

## Grafana

* Visualizes metrics
* Builds dashboards

## Blackbox Exporter

* Performs synthetic monitoring
* Tests endpoints like a real user

---

# 🔥 Golden Signals (SRE)

| Signal       | Metric                 |
| ------------ | ---------------------- |
| Availability | probe_success          |
| Latency      | probe_duration_seconds |
| Errors       | probe_success == 0     |
| Traffic      | request metrics        |

---

# 🚨 Debugging Guide

## ❌ No probe data

Check:

```bash
kubectl get probe -n monitoring
kubectl logs -n monitoring deploy/blackbox-prometheus-blackbox-exporter
```

---

## ❌ Prometheus not scraping probes

Check:

```bash
kubectl get prometheus monitoring-kube-prometheus-prometheus -n monitoring -o yaml | grep probeSelector -A5
```

---

## ❌ Grafana shows no data

Check in Prometheus:

```promql
probe_success
```

If empty → issue is not Grafana

---

# 🔥 Real-world Scenarios

## Scenario 1: Pods running but app is down

```text
kubectl get pods → Running
probe_success → 0
```

👉 Cause:

* LoadBalancer broken
* Service misconfiguration
* DNS issue

---

## Scenario 2: High latency

```text
probe_duration_seconds ↑
```

👉 Cause:

* CPU saturation
* DB slowness
* network issues

---

## Scenario 3: Intermittent failures

```text
probe_success → 1,0,1,0
```

👉 Cause:

* unstable service
* autoscaling delays
* network flakiness

---

# 🚀 Production Improvements

* Enable persistence for Prometheus & Grafana
* Add Alertmanager rules (Slack/Email)
* Add Loki for logs
* Add tracing (Istio / OpenTelemetry)
* Add SLO dashboards

---

# 🧠 Interview-Level Explanation

You can say:

```text
I manage observability as code using Helm values for Prometheus,
Probe CRDs for synthetic monitoring, and Grafana dashboards stored in Git.
I also maintain runbooks and access scripts for reproducibility.
```

---

# 🏁 Summary

You have implemented:

* Metrics collection (Prometheus)
* Visualization (Grafana)
* Synthetic monitoring (Blackbox)
* Dashboards as code
* Monitoring as code
* Runbook documentation

---

# 🚀 Next Steps

* Add alert rules (PrometheusRule)
* Integrate Slack alerts
* Build SLO dashboar

