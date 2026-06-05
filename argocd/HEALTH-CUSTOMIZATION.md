#Argo CD Health Customization
Goal: Improve GitOps visibility and deployment accuracy.
Implemented:
- Argo CD Application custom health check
- Elasticsearch custom health check
- ExternalSecret custom health check
- Prometheus custom health check
- ServiceMonitor health check
- Sync waves for platform dependency order
- Ignore noisy runtime status fields

Result:
- Reduced false Degraded/Progressing status
- Better CRD health visibility
- More reliable GitOps status in Argo CD
