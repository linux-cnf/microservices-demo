# AI Platform Engineering Portfolio Showcase

This project extends the Online Boutique microservices platform into a production-grade AI Platform Engineering demo.

## What Was Built

The platform includes:

- GKE-based Kubernetes infrastructure
- Terraform-managed AI node pool
- GitHub Actions bootstrap and destroy workflows
- GitOps delivery through Argo CD
- AI runtime using Ollama/vLLM-ready design
- LLM Gateway service
- AI Agent Orchestrator
- Frontend AI Assistant integration
- Observability with Prometheus, Grafana, Elasticsearch/Loki-ready logs, and Tempo
- Istio mTLS, AuthorizationPolicy, and traffic control
- Argo Rollouts canary deployment with automated analysis

## Architecture Summary

User traffic enters through the Online Boutique frontend. The frontend AI Assistant calls the AI Agent Orchestrator. The orchestrator decides which tool to use, such as Prometheus, Kubernetes API, logs, or tracing, and then sends context to the LLM Gateway. The LLM Gateway communicates with the local AI runtime such as Ollama or future vLLM.

## Why This Is Production Grade

This platform demonstrates:

- Infrastructure as Code
- GitOps-based deployment
- Secure service-to-service communication
- Progressive delivery
- Observability-driven rollback
- Cost-controlled AI infrastructure
- Operational runbooks
- Interview-ready demo scenarios

## Interview Pitch

I designed and implemented an AI Platform Engineering layer on top of a Kubernetes microservices platform. The system provisions a dedicated AI node pool using Terraform, deploys AI services through Argo CD, exposes an LLM Gateway and AI Agent Orchestrator, integrates platform tools like Prometheus and Kubernetes API, and secures traffic using Istio. I also added canary rollout support using Argo Rollouts so AI services can be upgraded safely with automated validation and rollback.
