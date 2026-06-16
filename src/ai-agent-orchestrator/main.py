"""
AI Agent Orchestrator

Purpose:
Adds agent-level logic before calling the LLM Gateway.

Responsibilities:
- Receive user prompts
- Detect whether platform metrics are needed
- Query Prometheus for live cluster metrics
- Add platform-specific context
- Call llm-gateway /chat
- Return a structured response

Current tools:
- Prometheus query tool

Future:
Loki, Tempo, Kubernetes API tools, guardrails.
"""

import os

import requests
from fastapi import FastAPI
from pydantic import BaseModel


app = FastAPI(title="ai-agent-orchestrator")

LLM_GATEWAY_URL = os.getenv(
    "LLM_GATEWAY_URL",
    "http://llm-gateway.ai.svc.cluster.local:8080",
)

PROMETHEUS_URL = os.getenv(
    "PROMETHEUS_URL",
    "http://observability-kube-prometh-prometheus.monitoring.svc.cluster.local:9090",
)

SYSTEM_PROMPT = """
You are an AI Platform Assistant.

Responsibilities:
- Help with Kubernetes
- Help with Argo CD
- Help with GitOps
- Help with Istio
- Help with Observability
- Help with AI Platform Operations

When tool context is provided, use it as live cluster data.
Keep responses concise and technical.
""".strip()


class ChatRequest(BaseModel):
    prompt: str


def query_prometheus(query: str) -> dict:
    response = requests.get(
        f"{PROMETHEUS_URL}/api/v1/query",
        params={"query": query},
        timeout=15,
    )
    response.raise_for_status()
    return response.json()


def should_use_prometheus(prompt: str) -> bool:
    keywords = [
        "cpu",
        "memory",
        "pod",
        "pods",
        "restart",
        "restarts",
        "ready",
        "availability",
        "prometheus",
        "metrics",
        "usage",
        "running",
        "health",
    ]

    prompt_lower = prompt.lower()
    return any(keyword in prompt_lower for keyword in keywords)


def build_prometheus_context(prompt: str) -> str:
    queries = {
        "ai_pods_ready": (
            'sum(kube_pod_status_ready{namespace="ai",condition="true"})'
        ),
        "ai_pods_running": (
            'sum(kube_pod_status_phase{namespace="ai",phase="Running"})'
        ),
        "ai_container_restarts": (
            'sum(kube_pod_container_status_restarts_total{namespace="ai"})'
        ),
        "llm_gateway_ready": (
            'sum(kube_pod_status_ready{namespace="ai",condition="true",pod=~"llm-gateway-.*"})'
        ),
        "ollama_ready": (
            'sum(kube_pod_status_ready{namespace="ai",condition="true",pod=~"ollama-.*"})'
        ),
    }

    results = {}

    for name, promql in queries.items():
        try:
            results[name] = query_prometheus(promql)
        except Exception as exc:
            results[name] = {"error": str(exc), "query": promql}

    return f"""
Prometheus tool context:
{results}
""".strip()


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "ai-agent-orchestrator"}


@app.get("/readyz")
def readyz():
    return {
        "status": "ready",
        "llm_gateway": LLM_GATEWAY_URL,
        "prometheus": PROMETHEUS_URL,
    }


@app.post("/agent/chat")
def agent_chat(req: ChatRequest):
    tool_context = ""

    if should_use_prometheus(req.prompt):
        tool_context = build_prometheus_context(req.prompt)

    final_prompt = f"""
System:
{SYSTEM_PROMPT}

Tool Context:
{tool_context or "No live tool context used."}

User:
{req.prompt}
"""

    response = requests.post(
        f"{LLM_GATEWAY_URL}/chat",
        json={"prompt": final_prompt},
        timeout=120,
    )
    response.raise_for_status()

    return {
        "agent": "ai-platform-agent",
        "tool_used": "prometheus" if tool_context else "none",
        "response": response.json(),
    }
