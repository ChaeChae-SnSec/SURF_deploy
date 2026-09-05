# DoH 종단. 모델을 싣지 않으므로 torch 가 필요 없고 이미지가 가볍다.
FROM python:3.11-slim

ARG DNS_REF=main

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        flask gunicorn redis prometheus-client python-dotenv dnspython

WORKDIR /srv/app
# 브랜치 이름은 그대로인데 커밋만 바뀌면 도커가 아래 clone 레이어를 캐시에서
# 재사용해 옛 코드가 그대로 들어간다. 이미지를 새 커밋으로 갱신할 때는
# CACHEBUST 를 바꿔서 이 지점부터 다시 받게 한다.
#   CACHEBUST=$(date +%s) docker compose build
ARG CACHEBUST=0
RUN git clone --depth 1 --branch "${DNS_REF}" \
        https://github.com/ChaeChae-SnSec/SURF_dns_server.git \
    && rm -rf SURF_dns_server/.git

ENV PYTHONUNBUFFERED=1
WORKDIR /srv/app/SURF_dns_server

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS http://127.0.0.1:${DOH_PORT:-8053}/healthz || exit 1

CMD ["gunicorn", "-c", "gunicorn.doh.conf.py", "doh_proxy:app"]
