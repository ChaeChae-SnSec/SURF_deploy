# SURF 구조

구현에서 실제로 알아야 하는 것만 적는다. 배포 절차는 [README](README.md)에 있다.

## 판별 경로가 둘이다

같은 모델을 쓰지만 도메인이 모델까지 도달하는 길이 두 가지고, 각각 막을 수 있는
범위가 다르다.

```mermaid
flowchart TB
    subgraph A["단독 모드 — 확장만 설치"]
        A1[주소창 입력·링크 클릭] --> A2[onBeforeNavigate]
        A2 --> A3{내장 allowlist<br/>241개}
        A3 -->|해당| A9[통과]
        A3 -->|미해당| A4{로컬 허용·판정 캐시}
        A4 -->|hit| A9
        A4 -->|miss| A5["GET /predict<br/>X-SURF-Client: 토큰"]
        A5 --> A6{blocked?}
        A6 -->|예| A7[blocked.html]
        A6 -->|아니오| A9
    end

    subgraph B["DNS 연동 모드 — DoH 설정 추가"]
        B1[브라우저·백그라운드 프로세스<br/>모든 이름 해석] --> B2["doh_proxy<br/>/dns-query?c=토큰"]
        B2 --> B3[Unbound + 판별 모듈]
        B3 -->|DGA| B4[NXDOMAIN]
        B3 -->|정상| B5[상용 리졸버로 forward]
        B4 --> B6[ERR_NAME_NOT_RESOLVED]
        B6 --> B7[onErrorOccurred]
        B7 --> B8["GET /check"]
        B8 --> B9[blocked.html]
    end
```

| | 단독 모드 | DNS 연동 모드 |
|---|---|---|
| 설치 | 확장만 | 확장 + 크롬 DoH 설정 |
| 막는 범위 | 브라우저에서 사용자가 여는 것 | 기기의 모든 이름 해석 |
| 백그라운드 C2 통신 | 못 막는다 | 막는다 |
| 진입 지점 | `background.js` `onBeforeNavigate` | `doh_proxy.py` `/dns-query` |
| 서버 호출 | `/predict` (즉석 추론) | `/check` (차단 기록 조회) |

감염된 PC가 사용자 몰래 C2 도메인을 찾는 질의는 브라우저를 거치지 않는다. 그것을
막는 것은 DNS 계층뿐이고, 단독 모드는 설치 장벽을 없애는 대신 그 범위를 포기한다.
확장의 `CONFIG.PROACTIVE`를 false로 두면 단독 모드만 끄고 DNS 경로를 남길 수 있다.

## 배포 형태와 쓰임

클라이언트를 어떻게 붙이느냐에 따라 덮는 범위와 준비 부담이 달라진다. 네 가지가
가능하지만 발표에 반드시 필요한 것은 둘이고, 하나는 백업이며, 하나는 시연이 아니라
운영용이다.

| 형태 | 클라이언트가 할 일 | 덮는 범위 | 어디서 쓰나 | 필요도 |
|---|---|---|---|---|
| **A. 확장 단독** | 설치만 | 브라우저에서 사용자가 여는 것 | 심사 교수 각자 기기 | **필수** |
| **B. 크롬 DoH + 확장** | 크롬 보안 DNS 설정 | 크롬 안 전체 | 발표자 노트북 | 백업 |
| **C. 로컬 DoH 프록시** | cloudflared 설치, OS DNS 변경 | **기기 전체** | 발표자 노트북 | **필수** |
| **D. 53 직결** | OS DNS 를 서버 IP 로 | 기기 전체 | 연구실 내부 | 운영용 |

### A. 확장 단독 — 체험의 문턱을 없애는 자리

`PROACTIVE: true` 인 확장은 DNS 를 거치지 않는다. 이동 직전에 `/predict` 를 직접
호출하고 스스로 차단 페이지로 보낸다. DNS 설정도, 토큰 맞추기도 필요 없다. 토큰은
설치 시점에 확장이 만들어 자기 안에서만 쓰므로 어긋날 데가 없다.

심사 교수가 자기 기기로 직접 만져보려면 설치 외에 아무것도 요구해선 안 된다.
이 형태가 그 조건을 만족하는 유일한 방법이다.

### B. 크롬 DoH + 확장 — C 가 안 될 때의 대비

DNS 계층이 동작한다는 것은 보여주지만, 화면에 나타나는 결과는 A 와 같다. 차단
페이지의 배지가 `SURF DNS 차단` 인지 `AI 실시간 판별` 인지로만 갈린다. C 가
브라우저까지 포함해 덮으므로, C 가 되면 B 를 따로 보여줄 이유는 없다.

그럼에도 남겨두는 이유는 준비 부담이 낮아서다. C 는 프로그램 설치와 OS 설정 변경이
필요하지만 B 는 크롬 설정 한 줄이다. 발표장에서 C 가 무너졌을 때 즉시 갈아탈 수
있는 대비책으로 가치가 있다.

크롬 설정에 넣는 주소는 두 형태 모두 받는다.

```
https://dns.<도메인>/dns-query?c=<토큰>
https://dns.<도메인>/dns-query/<토큰>
```

크롬은 입력한 주소를 URI 템플릿으로 다루는데 쿼리 문자열이 이미 붙어 있으면 등록을
거부하는 경우가 있다. 그때는 경로 형태를 쓴다.

### C. 로컬 DoH 프록시 — 핵심 주장을 실증하는 자리

기기에서 작은 DoH 클라이언트를 돌리고 OS 의 DNS 를 그쪽으로 돌린다.

```
cloudflared proxy-dns --address 127.0.0.1 --port 53 \
  --upstream "https://dns.<도메인>/dns-query/<토큰>"
```

이 형태만이 브라우저 밖을 덮는다. 감염된 기기가 사용자 몰래 C2 도메인을 찾는
질의는 브라우저를 거치지 않으므로, 그것을 막는 장면은 A 나 B 로는 만들 수 없다.
DGA 차단이라는 주장의 핵심이 여기 걸려 있다.

OS 의 DNS 설정 칸은 IP 주소만 받는다. 우리 서버는 공인 IP 로 53 을 열 수 없으므로
(열면 오픈 리졸버가 된다) 기기 안에 다리를 하나 두고 `127.0.0.1` 을 가리키게 한다.

**윈도우**

[릴리스 페이지](https://github.com/cloudflare/cloudflared/releases)에서
`cloudflared-windows-amd64.exe` 를 받는다. 53 은 특권 포트라 관리자 권한
PowerShell 에서 실행한다.

```powershell
netstat -ano | findstr ":53 "     # 먼저 점유 확인. Docker Desktop 과 ICS 가 흔하다

.\cloudflared.exe proxy-dns --address 127.0.0.1 --port 53 `
  --upstream "https://dns.<도메인>/dns-query/<토큰>"
```

DNS 설정은 `설정 → 네트워크 및 인터넷 → Wi-Fi → 하드웨어 속성 → DNS 서버 할당
→ 편집 → 수동 → IPv4 켜기 → 기본 DNS: 127.0.0.1`.

**macOS**

```bash
brew install cloudflared
sudo lsof -nP -iUDP:53                          # 점유 확인. 보통 비어 있다

sudo cloudflared proxy-dns --address 127.0.0.1 --port 53 \
  --upstream "https://dns.<도메인>/dns-query/<토큰>"
```

DNS 설정은 `시스템 설정 → 네트워크 → Wi-Fi → 세부사항 → DNS` 에서 `127.0.0.1` 추가.

**리눅스**

`systemd-resolved` 가 `127.0.0.53:53` 을 잡고 있지만 `127.0.0.1:53` 은 보통 비어
있어 그대로 쓸 수 있다.

```bash
sudo ss -ulnp | grep ':53 '                     # 점유 확인

sudo cloudflared proxy-dns --address 127.0.0.1 --port 53 \
  --upstream "https://dns.<도메인>/dns-query/<토큰>"

nmcli con mod "<연결 이름>" ipv4.ignore-auto-dns yes ipv4.dns 127.0.0.1
nmcli con up "<연결 이름>"
```

세 경우 모두 확인 방법은 같다.

```bash
nslookup vokqozlcrlgveiqj.org     # NXDOMAIN 이면 SURF 를 거치고 있다
```

### D. 53 직결 — 시연이 아니라 데이터를 쌓는 자리

OS 의 DNS 를 서버 IP 로 지정한다. 같은 망 안에서만 되므로 발표장에서는 쓸 수 없다.
발표 자료에 넣을 실운영 기록을 모으는 것이 이 형태의 쓸모다. 며칠분 로그가 쌓이면
차단 건수, 오탐 신고, 추론 지연을 실측치로 제시할 수 있다.

한 가지 주의할 점이 있다. 이 형태에서는 Unbound 가 클라이언트를 IP 로 기록하는데,
확장이 터널을 지나 `/check` 를 호출하면 그 IP 가 사라진다. 아래 절에서 다룬다.

## 클라이언트를 IP가 아니라 토큰으로 식별한다

허용 상태와 차단 기록은 기기별로 묶여야 한다. 그런데 Cloudflare 터널이나 DoH를
지나면 서버가 보는 주소가 전부 `127.0.0.1`로 뭉개진다. IP를 키로 쓰면 한 사람이
누른 "30분 허용"이 모든 사용자에게 적용된다.

토큰은 확장이 설치 시점에 발급해 `chrome.storage.local`에 넣는다. 두 경로가 각각
다른 방법으로 이 토큰을 서버까지 전달한다.

**HTTP 경로** — 확장이 `X-SURF-Client` 헤더에 실어 보낸다. Flask의 `client_id()`가
헤더, `?c=` 쿼리, `remote_addr` 순으로 찾는다.

**DNS 경로** — Unbound는 HTTP 헤더를 볼 수 없다. 그래서 DoH 프록시가 토큰을 주소로
바꿔서 전달한다.

```
doh_proxy.synthetic_ip("demo01")  ->  127.163.254.19      (sha256 기반, 결정적)
Redis  SETEX tokmap:127.163.254.19  7d  "demo01"
UDP 소켓을 127.163.254.19에 bind 하고 Unbound로 질의

surf_unbound.resolve_client_id("127.163.254.19")
    -> Redis GET tokmap:127.163.254.19
    -> "demo01"
```

리눅스는 `127.0.0.0/8` 전체를 `lo`의 local 라우트로 잡고 있어서 이 대역 어디에나
추가 설정 없이 bind 할 수 있다. 주소 공간이 1600만 개라 충돌은 사실상 없다.

**53 에 직접 붙는 경우(형태 D)는 이 경로를 타지 않는다.** 소스 주소가 실제 IP 라
`resolve_client_id` 가 손대지 않고 그대로 식별자가 된다. 그래서 차단 기록이
`block_mark:10.3.0.16:도메인` 처럼 IP 로 남는다.

문제는 확장이 그 기록을 찾을 수 없다는 데 있다. 확장은 언제나 토큰 헤더를 보내고,
요청이 터널을 지나면 실제 IP 가 `127.0.0.1` 로 뭉개져 사라진다. 기기별 기록만으로는
이 조합을 맞출 방법이 없다.

그래서 Unbound 가 차단할 때 도메인 단위 기록(`block_recent`, 60초)을 함께 남기고,
`/check` 가 기기별 조회에 실패하면 그것을 본다. 판정은 도메인만 보고 하므로 같은
도메인이면 누구에게나 같은 결과다. 응답의 `matched` 필드로 어느 근거로 찾았는지
구분된다.

이 방식 때문에 **`doh` 컨테이너가 `unbound`의 네트워크 네임스페이스를 공유해야
한다**(`network_mode: "service:unbound"`). 컨테이너를 분리하면 소스 주소가 도커
네트워크 IP가 되어 `127.` 판정이 깨지고 클라이언트 구분이 통째로 사라진다.

DoH를 함께 쓰는 기기는 확장의 `CLIENT_TOKEN`과 DoH URL의 `?c=` 값이 같아야 한다.

## 시연에서 로그를 보여줄 때

`scripts/watch-queries.sh` 가 판정 결과만 골라 색을 입혀 흘려준다. 원본 로그는
디버그 줄이 섞여 화면에 띄우기 어렵다.

```bash
./scripts/watch-queries.sh 10.3.0.16     # 그 기기의 질의만
tmux new -s surf './scripts/watch-queries.sh 10.3.0.16'   # SSH 가 끊겨도 유지
```

여러 기기가 동시에 SURF 를 쓰고 있으면 화면이 섞이므로, 보여줄 기기 하나만 인자로
넘긴다.

**캐시 때문에 정상 도메인은 한 번만 찍힌다.** 같은 정상 도메인을 다시 조회하면
unbound 가 캐시에서 응답해 판별 모듈까지 오지 않는다. 반면 차단은 모듈이 응답을
직접 만들어 돌려주므로 캐시에 남지 않고, 몇 번을 조회해도 매번 로그에 찍힌다.
시연의 핵심인 차단 장면은 반복해도 안전하다.

터미널과 대시보드는 역할이 다르다. 터미널은 질의 하나하나가 실시간으로 판정되는
것을, 대시보드는 그것이 쌓인 집계를 보여준다. 두 화면을 나란히 두면 설명이 겹치지
않는다.

## Redis 키

세 컴포넌트가 같은 Redis를 본다. 키의 `<cid>`는 위에서 정한 토큰이고, 한 곳만
IP로 되돌리면 차단 페이지가 뜨지 않는다.

| 키 | 쓰는 쪽 | 읽는 쪽 | TTL | 용도 |
|---|---|---|---|---|
| `pred:<domain>` | api | api | 6시간 | 판정 캐시. 같은 도메인 반복 추론을 막는다 |
| `block_mark:<cid>:<domain>` | unbound, api | api `/check` | 300초 | NXDOMAIN이 우리 모델 때문인지 판별하는 근거 |
| `block_recent:<domain>` | unbound | api `/check` | 60초 | 기기별 기록으로 못 찾는 조합의 폴백 |
| `allow:<cid>:<domain>` | api `/allow` | unbound, api | 30분 | 임시 허용 |
| `whitelist:<cid>:<domain>` | api `/allow` | unbound, api | 없음 | 영구 허용 |
| `tokmap:<127.x.y.z>` | doh | unbound | 7일 | 소스 주소에서 토큰 복원 |
| `fp_reports` (zset) | api | 운영자 | 없음 | 오탐 신고 누적. allowlist 반영 대상을 뽑는다 |
| `rl:<cid>:<분>` | api | api | 120초 | 분 단위 요청 제한 |

`/allow`는 토큰과 IP 양쪽 이름에 모두 기록한다. Unbound 가 어느 쪽으로 보든 허용이
걸려야 하기 때문이다. 동시에 `pred:` 와 `block_mark:` 를 지운다. 남겨두면 허용 직후
재조회에서 다시 막힌다.

요청 IP 가 루프백이면 식별자 후보에서 뺀다. 터널 뒤에서는 모든 요청이 `127.0.0.1`
로 보이므로, 그것을 식별자로 쓰면 한 사람의 허용이 모든 사용자에게 적용된다.

## 서버 호출을 줄이는 세 단계

브라우저의 모든 이동마다 모델을 돌리면 지연도 부하도 감당이 안 된다. 세 단계로
거른다.

1. **내장 allowlist** — `whitelist.js`의 도메인 241개. 접미사 매칭이고 서버로
   나가지 않는다. 흔한 사이트 방문 기록이 서버에 남지 않는 부수 효과가 있다.
2. **확장 판정 캐시** — 메모리와 `chrome.storage.session` 2단. 차단 판정은 30분,
   정상 판정은 6시간 들고 있는다.
3. **서버 판정 캐시** — Redis `pred:`. 여러 사용자가 같은 도메인을 열어도 추론은
   한 번이다.

서버가 죽거나 2.5초 안에 답하지 않으면 통과시킨다. 파일럿 중에 서버가 멈췄다고
사용자 브라우징까지 막히면 안 된다.

## 모델 교체

체크포인트마다 어휘 크기, 시퀀스 길이, 위치 인코딩 방식, 분류 헤드 차원, 전처리가
전부 다르다. 하나라도 어긋나면 로드 시점에 shape mismatch로 멈춘다. 그래서
`model_setting.py`의 `VARIANTS`에 한 묶음으로 둔다.

| | `drift` (현재) | `surf-tld` |
|---|---|---|
| subword | 30522 / len 30 | 32393 / len 35 |
| char | 43 / len 77 | 2273 / len 82 |
| positional encoding | 학습형 `nn.Embedding` | 고정 sinusoidal |
| classifier head | `pool` (1024) | `cls` (512) |
| 전처리 | eSLD (`google`) | TLD wrap (`google[.com]`) |
| 가중치 | 공개됨 | 미확보 |

전처리 차이가 특히 조용히 망가진다. DRIFT는 TLD를 뗀 eSLD로 학습되어 있어서
`google.com`을 그대로 넣으면 학습 분포와 어긋나 **모든 도메인이 정상으로 나온다**.
에러가 아니라 판별이 무너지는 방식이라 알아채기 어렵다.

교체는 `artifacts/`에 파일을 넣고 `.env`의 `SURF_MODEL_VARIANT`를 바꾸면 된다.

## 컨테이너 배치

```
cloudflared ──┐ (아웃바운드 연결만, 열린 포트 없음)
              │
   ┌──────────┴───────────┬─────────────┐
   │                      │             │
unbound :53          api :5000    grafana :3000
  + doh :8053          (모델)         ↑
  (같은 netns)                    prometheus :9090
  (모델)                              ↑
   └────────── redis ◄────┴───────────┘
```

`unbound`와 `api`가 모델을 각각 로드하므로 프로세스 메모리에 사본이 둘 생긴다.
RAM 4GB가 최소이고 8GB를 권한다. `doh`는 모델을 싣지 않아 이미지가 260MB다.

배포판 unbound 패키지는 파이썬 모듈이 꺼진 채로 빌드되어 있어 쓸 수 없다.
`--with-pythonmodule`로 직접 빌드하고, 모듈이 도는 인터프리터와 torch를 설치한
인터프리터를 `python:3.11` 하나로 맞춘다.

Prometheus는 세 곳을 따로 수집한다. DNS 경로는 `surf_dns_*`, DoH는 `surf_doh_*`,
확장 단독 경로는 `surf_ext_*`로 이름을 나눠 두었다.
