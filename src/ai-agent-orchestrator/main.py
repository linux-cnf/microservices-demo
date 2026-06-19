"""
AI Agent Orchestrator

Purpose:
Adds agent-level logic before calling the LLM Gateway.

Responsibilities:
- Receive user prompts
- Detect whether platform metrics are needed
- Query Prometheus for live cluster metrics
- Convert Prometheus results into clean tool output
- Add platform-specific context
- Call ai-llm-gateway /chat
- Return structured response with tool results

Current tools:
- Prometheus query tool

Future:
Loki, Tempo, Kubernetes API tools, guardrails.
"""

import os
from typing import Any

import requests
from fastapi import FastAPI
from pydantic import BaseModel


app = FastAPI(title="ai-agent-orchestrator")

LLM_GATEWAY_URL = os.getenv(
    "LLM_GATEWAY_URL",
    "http://ai-llm-gateway.ai.svc.cluster.local:8080",
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

Rules:
- If tool context is provided, treat it as the live source of truth.
- Do not invent kubectl output.
- Do not suggest commands when the answer is already present in tool context.
- Keep responses concise and technical.
""".strip()


class ChatRequest(BaseModel):
    prompt: str


def query_prometheus(query: str) -> dict[str, Any]:
    response = requests.get(
        f"{PROMETHEUS_URL}/api/v1/query",
        params={"query": query},
        timeout=15,
    )
    response.raise_for_status()
    return response.json()


def extract_prometheus_value(result: dict[str, Any]) -> float | str:
    try:
        values = result["data"]["result"]

        if not values:
            return 0

        return float(values[0]["value"][1])

    except Exception as exc:
        return f"error: {exc}"


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


def build_prometheus_tool_result() -> dict[str, Any]:
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
            'sum(kube_pod_status_ready{namespace="ai",condition="true",pod=~"ai-llm-gateway-.*"})'
        ),
        "ollama_ready": (
            'sum(kube_pod_status_ready{namespace="ai",condition="true",pod=~"ollama-.*"})'
        ),
        "ai_agent_ready": (
            'sum(kube_pod_status_ready{namespace="ai",condition="true",pod=~"ai-agent-orchestrator-.*"})'
        ),
    }

    results: dict[str, Any] = {}

    for name, promql in queries.items():
        try:
            raw_result = query_prometheus(promql)
            results[name] = {
                "query": promql,
                "value": extract_prometheus_value(raw_result),
            }
        except Exception as exc:
            results[name] = {
                "query": promql,
                "error": str(exc),
            }

    return results


def build_tool_context(tool_result: dict[str, Any]) -> str:
    return f"""
Live Prometheus metrics from the ai namespace:

{tool_result}

Answer using only these metrics.
Do not invent pod names or kubectl output.
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
    tool_used = "none"
    tool_result = {}

    if should_use_prometheus(req.prompt):
        tool_used = "prometheus"
        tool_result = build_prometheus_tool_result()

    tool_context = (
        build_tool_context(tool_result)
        if tool_used == "prometheus"
        else "No live tool context used."
    )

    final_prompt = f"""
System:
{SYSTEM_PROMPT}

Tool Context:
{tool_context}

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
        "tool_used": tool_used,
        "tool_result": tool_result,
        "response": response.json(),
    }
