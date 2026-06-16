"""
AI Agent Orchestrator

Purpose:
Adds agent-level logic before calling the LLM Gateway.

Responsibilities:
- Receive user prompts
- Add a platform-specific system prompt
- Call llm-gateway /chat
- Return a structured response

Future:
Tool routing, Prometheus/Loki/Kubernetes API tools, guardrails.
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

SYSTEM_PROMPT = """
You are an AI Platform Assistant.

Responsibilities:
- Help with Kubernetes
- Help with Argo CD
- Help with GitOps
- Help with Istio
- Help with Observability
- Help with AI Platform Operations

Keep responses concise and technical.
""".strip()


class ChatRequest(BaseModel):
    prompt: str


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "ai-agent-orchestrator"}


@app.get("/readyz")
def readyz():
    return {"status": "ready", "llm_gateway": LLM_GATEWAY_URL}


@app.post("/agent/chat")
def agent_chat(req: ChatRequest):
    final_prompt = f"""
System:
{SYSTEM_PROMPT}

User:
{req.prompt}
"""

    response = requests.post(
        f"{LLM_GATEWAY_URL}/chat",
        json={"prompt": final_prompt},
        timeout=120,
    )
    response.raise_for_status()

    return response.json()
