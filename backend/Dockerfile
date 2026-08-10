FROM python:3.11-slim

WORKDIR /app

# System deps (optional, keeps image small)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App + SQL seeds + default uploads (covers)
COPY app/ ./app/
COPY sql/ ./sql/
COPY uploads/ ./uploads/

# Default to SQLite for free HF Spaces (override with Space secrets)
ENV DB_TYPE=sqlite \
    SQLITE_FILE=/data/novel_app.db \
    UPLOAD_DIR=/data/uploads \
    PYTHONUNBUFFERED=1

# Persist DB/uploads if HF mounts /data; else fall back under /app
RUN mkdir -p /data/uploads /app/uploads

# Hugging Face Spaces listens on 7860
EXPOSE 7860

# Create /data on start if missing, then run API
CMD ["sh", "-c", "mkdir -p /data/uploads && if [ ! -d /data ]; then export SQLITE_FILE=/app/novel_app.db UPLOAD_DIR=/app/uploads; fi; uvicorn app.main:app --host 0.0.0.0 --port 7860"]
