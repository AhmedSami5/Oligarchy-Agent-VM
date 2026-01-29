# Multi-stage Dockerfile for DeMoD Agent System
# Supports development, production, and cloud deployments

# ========================================
# Base Stage - Runtime Dependencies
# ========================================
FROM python:3.11-slim as base

# System dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Node.js dependencies for web UI
COPY package*.json ./
RUN npm ci --only=production

# ========================================
# Development Stage
# ========================================
FROM base as development

# Development dependencies
RUN pip install --no-cache-dir -r requirements-dev.txt
RUN npm ci

# Copy development files
COPY . .

# Development environment variables
ENV FLASK_ENV=development
ENV PYTHONPATH=/app
ENV DEBUG=true

# Development server
EXPOSE 8000
CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=8000"]

# ========================================
# Production Stage
# ========================================
FROM base as production

# Production dependencies only
RUN pip install --no-cache-dir gunicorn

# Copy application files
COPY src/ /app/src/
COPY configs/ /app/configs/
COPY ui/web/dist/ /app/static/  # Built web UI

# Production environment variables
ENV FLASK_ENV=production
ENV PYTHONPATH=/app
ENV GUNICORN_WORKERS=4

# Production server
EXPOSE 8000
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Production server with Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "src.api.main:app"]

# ========================================
# Cloud Stage - Optimized for Cloud Deployment
# ========================================
FROM production as cloud

# Security hardening for cloud
RUN groupadd -r agent && useradd -r -g agent agent
RUN chown -R agent:agent /app
USER agent

# Multi-architecture support
ARG TARGETARCH
ARG TARGETOS

# Cloud-specific optimizations
ENV PYTHONUNBUFFERED=1
ENV GUNICORN_WORKERS=2
ENV GUNICORN_THREADS=4

# Cloud server configuration
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4", "--timeout=120", "src.api.main:app"]