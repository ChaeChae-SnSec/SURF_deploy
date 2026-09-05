# 확장 프로그램이 붙는 HTTP API.
FROM python:3.11-slim

ARG WEB_REF=main
ARG MODEL_REF=main

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        torch \
    && pip install --no-cache-dir \
        transformers tldextract numpy pandas polars tqdm \
        flask flask-cors gunicorn redis prometheus-client python-dotenv

WORKDIR /srv/app
RUN git clone --depth 1 --branch "${WEB_REF}" \
        https://github.com/ChaeChae-SnSec/SURF_web_server.git \
    && git clone --depth 1 --branch "${MODEL_REF}" \
        https://github.com/ChaeChae-SnSec/SURF_AI_model.git \
    && rm -rf SURF_web_server/.git SURF_AI_model/.git

ENV PYTHONPATH=/srv/app \
    PYTHONUNBUFFERED=1

WORKDIR /srv/app/SURF_web_server
EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=180s --retries=3 \
    CMD curl -fsS http://127.0.0.1:5000/healthz || exit 1

CMD ["gunicorn", "-c", "gunicorn.conf.py", "extension:app"]
