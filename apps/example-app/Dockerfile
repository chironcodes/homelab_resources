# example-app — multi-stage build template
#
# Copy this file to apps/<your-app>/Dockerfile and adapt as needed.
# Key conventions:
#   - Two stages: builder (installs deps) and runtime (lean image that ships)
#   - Non-root user with explicit UID/GID (1001) — never run as root in production
#   - HEALTHCHECK defined here so it works even without compose
#   - USER appuser must be the last user directive before CMD

# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --upgrade pip \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

RUN groupadd --gid 1001 appgroup \
 && useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

# Copy only installed packages from builder — no build tools ship in the final image
COPY --from=builder /install /usr/local

# Copy source with correct ownership in a single layer
COPY --chown=appuser:appgroup src/ .

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/healthz || exit 1

CMD ["python", "main.py"]
