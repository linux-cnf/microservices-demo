## AI Platform On-Demand GitOps Workflow

The AI platform is deployed only when required. Core platform bootstrap does not automatically deploy AI workloads.

```text
ai-platform-bootstrap.yml
  → Enables the dedicated AI node pool using Terraform

scripts/ai-cluster-bootstrap.sh
  → Registers the optional ai-platform Argo CD application

ai-microservices-ci.yml
  → Builds and pushes AI microservice images after src/ai-* changes
  → Creates a GitOps image-tag update PR

ai-agent-orchestrator-ci.yml
  → Builds and pushes ai-agent-orchestrator image after src/ai-agent-orchestrator changes
  → Creates a GitOps image-tag update PR

Argo CD
  → Deploys AI workloads from Git manifests


Execution Order:
1. Run ai-platform-bootstrap workflow with run_apply=true
2. Run ./scripts/ai-cluster-bootstrap.sh from bastion or whitelisted machine
3. Merge AI service code changes
4. CI builds image and creates image-tag PR
5. Merge image-tag PR
6. Argo CD reconciles the ai-platform application
