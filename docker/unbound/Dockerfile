# Unbound + AI 판별 모듈.
#
# 배포판 패키지의 unbound 는 파이썬 모듈이 꺼진 채로 빌드되어 있어 쓸 수 없다.
# --with-pythonmodule 로 직접 빌드한다. 모듈이 도는 인터프리터와 torch 를 설치한
# 인터프리터가 같아야 하므로 처음부터 끝까지 python:3.11 하나로 맞춘다.

ARG PYTHON_VERSION=3.11

# ---------------------------------------------------------------- 빌드
FROM python:${PYTHON_VERSION}-slim AS build

ARG UNBOUND_VERSION=1.20.0
ARG PYTHON_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl pkg-config swig \
        libssl-dev libexpat1-dev libevent-dev bison flex \
    && rm -rf /var/lib/apt/lists/*

# configure 가 이 값을 안 주면 python3.11.16 처럼 패치 버전까지 붙은 실행 파일을
# 찾다가 실패한다. 이미지에 있는 이름은 python3.11 이다.
ENV PYTHON_VERSION=${PYTHON_VERSION}

RUN curl -fsSL "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz" \
        -o /tmp/unbound.tar.gz \
    && tar -xzf /tmp/unbound.tar.gz -C /tmp \
    && cd "/tmp/unbound-${UNBOUND_VERSION}" \
    && ./configure \
        --prefix=/opt/unbound \
        --with-pythonmodule \
        --with-libevent \
        --with-ssl \
        --disable-static \
    && make -j"$(nproc)" \
    && make install

# ---------------------------------------------------------------- 런타임
FROM python:${PYTHON_VERSION}-slim

ARG DNS_REF=main
ARG MODEL_REF=main

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git libssl3 libexpat1 libevent-2.1-7 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/unbound /opt/unbound

# CPU 전용 휠을 쓴다. GPU 런타임이 딸려오면 이미지가 몇 배로 불어난다.
RUN pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        torch \
    && pip install --no-cache-dir \
        transformers tldextract numpy pandas polars tqdm \
        redis prometheus-client python-dotenv

WORKDIR /srv/app
RUN git clone --depth 1 --branch "${DNS_REF}" \
        https://github.com/ChaeChae-SnSec/SURF_dns_server.git \
    && git clone --depth 1 --branch "${MODEL_REF}" \
        https://github.com/ChaeChae-SnSec/SURF_AI_model.git \
    && rm -rf SURF_dns_server/.git SURF_AI_model/.git

ENV PYTHONPATH=/srv/app \
    PYTHONUNBUFFERED=1

RUN mkdir -p /var/lib/unbound /srv/artifacts

EXPOSE 53/udp 53/tcp 9101

# 컨테이너 안에서는 권한 분리와 chroot 를 unbound 가 아니라 도커가 담당한다.
CMD ["/opt/unbound/sbin/unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
