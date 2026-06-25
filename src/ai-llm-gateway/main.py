"""
LLM Gateway Service

Purpose:
Central API layer between application/frontend and the LLM runtime.

Responsibilities:
- Accept user prompts through a stable /chat API
- Forward prompts to Ollama today
- Keep frontend independent from Ollama/vLLM implementation details
- Prepare future support for auth, rate limiting, routing, and audit logging
"""

import os
import time
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel, Field
from prometheus_client import (
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST,
)

OLLAMA_URL = os.getenv(
    "OLLAMA_URL",
    "http://ai-ollama.ai.svc.cluster.local:11434",
)

DEFAULT_MODEL = os.getenv(
    "DEFAULT_MODEL",
    "tinyllama",
)

app = FastAPI(
    title="LLM Gateway",
    description="Gateway service for routing AI requests to LLM runtimes.",
    version="0.1.0",
)

# ==========================================================
# Prometheus Metrics
# ==========================================================

AI_REQUESTS_TOTAL = Counter(
    "ai_llm_gateway_requests_total",
    "Total number of LLM Gateway requests",
    ["endpoint", "method"],
)

AI_ERRORS_TOTAL = Counter(
    "ai_llm_gateway_errors_total",
    "Total number of LLM Gateway errors",
    ["endpoint"],
)

AI_REQUEST_LATENCY_SECONDS = Histogram(
    "ai_llm_gateway_request_latency_seconds",
    "LLM Gateway request latency",
    ["endpoint"],
)


class ChatRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=4000)
    model: Optional[str] = None


class ChatResponse(BaseModel):
    model: str
    response: str


@app.get("/healthz")
def healthz():
    return {
        "status": "ok",
        "service": "ai-llm-gateway",
    }


@app.get("/readyz")
async def readyz():

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(
                f"{OLLAMA_URL}/api/tags"
            )
            response.raise_for_status()

        return {
            "status": "ready",
            "ollama": "reachable",
        }

    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=f"Ollama runtime is not reachable: {exc}",
        ) from exc


@app.get("/metrics")
def metrics():
    return Response(
        generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
    )


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):

    start_time = time.time()

    AI_REQUESTS_TOTAL.labels(
        endpoint="/chat",
        method="POST",
    ).inc()

    model = request.model or DEFAULT_MODEL

    payload = {
        "model": model,
        "prompt": f"""Answer directly and briefly.

User question:
{request.prompt}

Answer:""",
        "stream": False,
        "options": {
            "temperature": 0.1,
            "top_p": 0.3,
            "num_predict": 80,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                f"{OLLAMA_URL}/api/generate",
                json=payload,
            )

            response.raise_for_status()

        data = response.json()

        return ChatResponse(
            model=model,
            response=data.get("response", ""),
        )

    except httpx.HTTPStatusError as exc:

        AI_ERRORS_TOTAL.labels(
            endpoint="/chat",
        ).inc()

        raise HTTPException(
            status_code=exc.response.status_code,
            detail=exc.response.text,
        ) from exc

    except Exception as exc:

        AI_ERRORS_TOTAL.labels(
            endpoint="/chat",
        ).inc()

        raise HTTPException(
            status_code=500,
            detail=f"LLM Gateway request failed: {exc}",
        ) from exc

    finally:

        AI_REQUEST_LATENCY_SECONDS.labels(
            endpoint="/chat",
        ).observe(
            time.time() - start_time
        )
