# -------------------------------------------------------------------
# PURPOSE:
# Container image for the AI Agent Orchestrator.
#
# RESPONSIBILITIES:
# - Package FastAPI agent code
# - Run uvicorn HTTP server
# - Call the internal LLM Gateway service
#
# In short:
# Runtime image for agent-level AI request handling.
# -------------------------------------------------------------------

FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
