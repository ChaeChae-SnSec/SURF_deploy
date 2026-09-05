# DoH 종단. 모델을 싣지 않으므로 torch 가 필요 없고 이미지가 가볍다.
FROM python:3.11-slim

ARG DNS_REF=main

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        flask gunicorn redis prometheus-client python-dotenv dnspython

WORKDIR /srv/app
RUN git clone --depth 1 --branch "${DNS_REF}" \
        https://github.com/ChaeChae-SnSec/SURF_dns_server.git \
    && rm -rf SURF_dns_server/.git

ENV PYTHONUNBUFFERED=1
WORKDIR /srv/app/SURF_dns_server

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS http://127.0.0.1:${DOH_PORT:-8053}/healthz || exit 1

CMD ["gunicorn", "-c", "gunicorn.doh.conf.py", "doh_proxy:app"]
