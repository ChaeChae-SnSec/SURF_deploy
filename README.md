# SURF 배포 스택

AI DGA 판별 DNS 서비스를 서버 한 대에 올리는 구성이다. 코드는 네 저장소에 나뉘어
있고, 여기서는 그것들을 컨테이너로 묶어 세운다.

```
                        인터넷
                           │
                    Cloudflare (도메인)
                           │
                     cloudflared  ← 아웃바운드 연결만 쓴다
        ┌──────────────────┼──────────────────┐
   dns.<도메인>        api.<도메인>       dash.<도메인>
   /dns-query           /predict           Grafana
        │                  │                   │
     doh :8053  ──►  unbound :53           api :5000
        └────────►  redis  ◄──┴──────────────────┘
                       │
                  prometheus ──► grafana
```

## 구조에서 중요한 두 가지

**doh 가 unbound 의 네트워크 네임스페이스를 공유한다.** DoH 프록시는 클라이언트
토큰마다 `127.x.y.z` 를 배정하고 그 주소를 소스로 Unbound 에 질의한다. Unbound
모듈이 `tokmap` 을 되읽어 토큰을 복원하는 방식이라, 컨테이너를 분리하면 소스
주소가 도커 네트워크 IP 로 바뀌어 클라이언트 구분이 통째로 사라진다.

**포트를 밖으로 열지 않는다.** 모든 서비스는 `expose` 만 하고 cloudflared 가
아웃바운드로 연결한다. 공인 IP 에 53/UDP 를 여는 것은 오픈 리졸버가 되어 증폭
반사 공격에 악용되므로 선택지가 아니다.

## 요구 사항

| | |
|---|---|
| RAM | 최소 4GB, 권장 8GB — unbound 와 api 가 모델을 각각 물고 있다 |
| CPU | 2코어 이상 |
| 디스크 | 10GB (이미지에 torch 가 들어간다) |
| 그 외 | Docker, Docker Compose v2, Cloudflare 계정과 도메인 |

## 배포

```bash
git clone <이 저장소> && cd SURF_deploy
cp .env.example .env && $EDITOR .env      # 터널 토큰, Grafana 비밀번호
./scripts/fetch-artifacts.sh              # 가중치·토크나이저 내려받기
docker compose build
docker compose up -d
docker compose ps
```

첫 빌드는 torch 를 받느라 시간이 걸린다. api 컨테이너는 모델을 올리는 데
1~3분이 걸리므로 헬스체크의 `start-period` 를 180초로 잡아 두었다.

### Cloudflare 터널

대시보드에서 터널을 만들고 토큰을 `.env` 에 넣은 뒤, 공개 호스트명을 셋 연결한다.

| 호스트명 | 서비스 |
|---|---|
| `dns.<도메인>` | `http://unbound:8053` |
| `api.<도메인>` | `http://api:5000` |
| `dash.<도메인>` | `http://grafana:3000` |

대시보드 개편으로 이 설정은 **Public Hostname 이 아니라 Routes 탭**에 있다.
터널을 연 다음 Routes → Add route 로 셋을 등록한다.

주소를 서비스 이름으로 쓰는 것은 cloudflared 를 이 스택의 컨테이너로 돌리기
때문이다. 호스트에 직접 설치한 cloudflared 를 쓴다면 도커 네트워크 이름이 보이지
않으므로 `BIND_ADDR` 로 연 주소(예: `10.3.0.15:8053`)를 대신 넣어야 한다. 둘을
동시에 돌리면 커넥터가 둘이 되어 요청이 나뉘고, 한쪽이 서비스에 닿지 못하면
절반이 실패한다.

DoH 종단이 `unbound` 인 것은 doh 가 unbound 의 네트워크 네임스페이스를 쓰기 때문이다.

`dash` 는 Cloudflare Access 로 잠근다. 잠그지 않으면 대시보드가 인터넷에 공개된다.

### 클라이언트 설정

**확장 프로그램** — `config.js` 의 `API_BASE_URL` 을 `https://api.<도메인>` 으로.
DNS 설정 없이 이것만으로 동작한다.

**DoH (발표자 기기)** — 크롬 `설정 → 개인정보 및 보안 → 보안 → 보안 DNS 사용 →
맞춤 설정` 에 아래를 넣는다. `?c=` 값은 확장의 `CLIENT_TOKEN` 과 같아야 한다.

```
https://dns.<도메인>/dns-query?c=<클라이언트 토큰>
```

캡티브 포털이 있는 네트워크(학교 와이파이 등)에서는 **포털 로그인을 먼저 끝내고
DoH 를 켠다.** 순서가 바뀌면 포털 페이지가 뜨지 않는다.

## 확인

```bash
curl -s https://api.<도메인>/healthz
curl -s "https://api.<도메인>/predict?domain=google.com"
docker compose exec doh python tools/check_doh.py     # DoH 왕복 검증
docker compose logs -f unbound
```

## 모델 교체

SURF 의 TLD-aware 가중치를 확보하면 아티팩트를 바꾸고 variant 만 돌린다.

```bash
cp finetuning_0120_1528.pt tokenizer-2-32393-both-tld.json artifacts/
sed -i 's/^SURF_MODEL_VARIANT=.*/SURF_MODEL_VARIANT=surf-tld/' .env
docker compose up -d --force-recreate unbound api
```

어휘 크기, 시퀀스 길이, 위치 인코딩, 분류 헤드 차원, 전처리가 variant 단위로
묶여 있어 이 두 줄이면 된다. 잘못 짝지으면 기동 시점에 shape mismatch 로 멈춘다.

## 저장소

| 저장소 | 역할 |
|---|---|
| `SURF_dns_server` | Unbound 판별 모듈, DoH 종단 |
| `SURF_web_server` | 확장이 붙는 HTTP API |
| `SURF_AI_model` | 모델 정의와 전처리 |
| `SURF_extension` | 크롬 확장 |
