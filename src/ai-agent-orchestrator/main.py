"""
AI Agent Orchestrator

Purpose:
Adds agent-level logic before calling the AI LLM Gateway.

Responsibilities:
- Receive user prompts
- Detect whether platform data is needed
- Query Prometheus for live metrics
- Query Kubernetes API for live resource state
- Add platform-specific context
- Call ai-llm-gateway /chat
- Return structured response with tool results

Current tools:
- Prometheus query tool
- Kubernetes API tool

Future:
Loki, Tempo, product/catalog API tools, guardrails.
"""

import os
from typing import Any

import requests
from fastapi import FastAPI
from kubernetes import client, config
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

DEFAULT_K8S_NAMESPACE = os.getenv("DEFAULT_K8S_NAMESPACE", "ai")

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
- Do not invent pod names, deployment names, events, or metrics.
- Do not suggest commands when the answer is already present in tool context.
- Keep responses concise and technical.
""".strip()


try:
    config.load_incluster_config()
    K8S_CORE = client.CoreV1Api()
    K8S_APPS = client.AppsV1Api()
except Exception:
    K8S_CORE = None
    K8S_APPS = None


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
        "restart count",
        "restarts",
        "ready count",
        "availability",
        "prometheus",
        "metrics",
        "usage",
        "running count",
        "health count",
    ]

    prompt_lower = prompt.lower()
    return any(keyword in prompt_lower for keyword in keywords)


def should_use_kubernetes(prompt: str) -> bool:
    keywords = [
        "kubernetes",
        "k8s",
        "pod",
        "pods",
        "deployment",
        "deployments",
        "event",
        "events",
        "namespace",
        "imagepullbackoff",
        "crashloopbackoff",
        "pending",
        "notready",
        "not ready",
        "rollout",
        "service",
        "services",
        "replicaset",
        "replicasets",
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
        "ai_llm_gateway_ready": (
            'sum(kube_pod_status_ready{namespace="ai",condition="true",pod=~"ai-llm-gateway-.*"})'
        ),
        "ai_ollama_ready": (
            'sum(kube_pod_status_ready{namespace="ai",condition="true",pod=~"ai-ollama-.*"})'
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


def build_kubernetes_tool_result(namespace: str = DEFAULT_K8S_NAMESPACE) -> dict[str, Any]:
    if not K8S_CORE or not K8S_APPS:
        return {"error": "Kubernetes client is not initialized"}

    pods = K8S_CORE.list_namespaced_pod(namespace=namespace)
    deployments = K8S_APPS.list_namespaced_deployment(namespace=namespace)
    events = K8S_CORE.list_namespaced_event(namespace=namespace)

    return {
        "namespace": namespace,
        "pods": [
            {
                "name": pod.metadata.name,
                "phase": pod.status.phase,
                "node": pod.spec.node_name,
                "restart_count": sum(
                    container.restart_count
                    for container in (pod.status.container_statuses or [])
                ),
                "containers_ready": all(
                    container.ready
                    for container in (pod.status.container_statuses or [])
                ),
            }
            for pod in pods.items
        ],
        "deployments": [
            {
                "name": deploy.metadata.name,
                "replicas": deploy.status.replicas or 0,
                "ready_replicas": deploy.status.ready_replicas or 0,
                "available_replicas": deploy.status.available_replicas or 0,
            }
            for deploy in deployments.items
        ],
        "recent_events": [
            {
                "type": event.type,
                "reason": event.reason,
                "object": f"{event.involved_object.kind}/{event.involved_object.name}",
                "message": event.message,
            }
            for event in sorted(
                events.items,
                key=lambda item: item.last_timestamp or item.event_time or item.metadata.creation_timestamp,
            )[-10:]
        ],
    }


def build_tool_context(tool_used: str, tool_result: dict[str, Any]) -> str:
    if tool_used == "none":
        return "No live tool context used."

    return f"""
Live {tool_used} tool result from the platform:

{tool_result}

Answer using only this live tool result.
Do not invent kubectl output, metrics, pod names, or events.
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
        "kubernetes_client": "ready" if K8S_CORE and K8S_APPS else "not_ready",
    }


@app.post("/agent/chat")
def agent_chat(req: ChatRequest):
    tool_used = "none"
    tool_result: dict[str, Any] = {}

    if should_use_kubernetes(req.prompt):
        tool_used = "kubernetes"
        tool_result = build_kubernetes_tool_result()
    elif should_use_prometheus(req.prompt):
        tool_used = "prometheus"
        tool_result = build_prometheus_tool_result()

    tool_context = build_tool_context(tool_used, tool_result)

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
