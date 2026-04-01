FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/app/.cache/huggingface \
    TRANSFORMERS_CACHE=/app/.cache/huggingface \
    FAISS_ROOT=/app/faiss_db

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Original heavyweight install path kept for reference:
# COPY backend/requirements.txt ./requirements.txt
# RUN pip install --upgrade pip && pip install -r requirements.txt
COPY backend/requirements.k8s.txt ./requirements.k8s.txt
RUN pip install --upgrade pip && pip install -r requirements.k8s.txt

# Original backend entrypoint kept in the repository:
# COPY backend/rag_backend_full.py ./rag_backend_full.py
COPY backend/backend_api.py ./backend_api.py
COPY infra/k8s/files/hbm_erd_ddl.sql ./hbm_erd_ddl.sql

EXPOSE 8002

# Original command kept for reference:
# CMD ["python", "rag_backend_full.py"]
CMD ["python", "backend_api.py"]
