# -------------------------------------------------------------------
# PURPOSE:
# Container image for the LLM Gateway service.
#
# RESPONSIBILITIES:
# - Package FastAPI gateway code
# - Run uvicorn HTTP server
# - Provide stable API layer in front of Ollama/vLLM
#
# In short:
# Runtime image for AI request routing.
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
