# 시연용 도메인

발표에서 쓸 도메인을 미리 검증해 고정한 목록이다. 2026-09-05 기준 `drift` 체크포인트로
확인했다. 모델이나 가중치를 바꾸면 다시 검증해야 한다.

## 즉석에서 만든 도메인을 쓰면 안 되는 이유

모델이 놓치는 경우가 있다. 실제로 `qpwoeiruty1234xzcv.biz` 는 정상으로 판정된다.
그런데 그런 도메인은 등록되어 있지 않으므로 상위 리졸버가 NXDOMAIN 을 돌려주고,
화면에는 우리가 막았을 때와 똑같은 오류가 뜬다.

| | 화면 | 차단 기록 | 차단 페이지 |
|---|---|---|---|
| 모델이 차단 | NXDOMAIN | 남음 | 뜸 |
| 모델이 놓침 + 미등록 도메인 | NXDOMAIN | 없음 | **안 뜸** |

둘을 화면으로 구분할 수 없으니, 발표 중에 차단 페이지가 안 뜨면 원인을 찾을 수 없다.
검증된 목록만 쓴다.

## 차단되는 도메인

실제 DGA 데이터셋(`snsec-net/dga-detection-drift26dsn`)의 악성 표본에 TLD 를 붙인 것이다.
지어낸 문자열이 아니라 실제 DGA 계열에서 나온 이름이라 시연에서 설명하기도 낫다.

확장 경로(`/predict`)와 DNS 경로(53) 양쪽에서 확인했다. **24개 전부 NXDOMAIN** 이다.

| 도메인 | 위험도 |
|---|---|
| `vokqozlcrlgveiqj.org` | 100.00 |
| `1xor1sg1p9clw6heicetbkhmla.ru` | 100.00 |
| `uftsqrqok.biz` | 99.22 |
| `1skh8ueo1ou141um0nwsg8ellh.ru` | 100.00 |
| `jfwvpxlrcpw.info` | 99.77 |
| `ptnfkbaotnrttfeiyjkr.net` | 100.00 |
| `crhuaaflpsjd.info` | 99.60 |
| `1dyykml1fby9vp1tfttj91a0202o.net` | 100.00 |
| `ulqoqfnmspvd.org` | 99.63 |
| `v1s22i8fjg835i73ijxm674j.biz` | 100.00 |
| `iloboqrbenpgkx.info` | 99.95 |
| `xjcmfdsxmdvrkhnroj.com` | 100.00 |
| `rvolapqbaxugylaog.org` | 100.00 |
| `41u705if8tqv.com` | 100.00 |
| `uvegygrjtlefru.biz` | 99.97 |
| `1lph3tm220os5km7ritxu2wiu.org` | 100.00 |
| `pefkmfumomloeo.org` | 99.99 |
| `kunmfgnqjlidmtsj.org` | 100.00 |
| `1fhrezqapl81gt7ubvy10wwmng.info` | 100.00 |
| `ppkgqqosratmqorm.info` | 100.00 |
| `1kc60alvrb8841nb4wc8zq7b8j.info` | 100.00 |
| `1l1wwr0tln8my1telr8sbjyken.org` | 100.00 |
| `fgfjvwwyorptqzet.ru` | 100.00 |
| `rbvidgfecw7zktmmljfiz7rq.net` | 99.95 |

짧은 시연에는 앞의 세 개면 충분하다. 길이와 형태가 서로 달라 화면에서 잘 구분된다.

```
vokqozlcrlgveiqj.org
uftsqrqok.biz
1skh8ueo1ou141um0nwsg8ellh.ru
```

## 통과하는 도메인

대비를 보여줄 때 쓴다. 전부 정상 해석되는 것을 확인했다.

```
google.com
naver.com
github.com
wikipedia.org
daum.net
youtube.com
stackoverflow.com
arxiv.org
coupang.com
cloudflare.com
python.org
```

`sookmyung.ac.kr` 은 목록에서 뺐다. 최상위에 A 레코드가 없어서 우리 서버뿐 아니라
1.1.1.1 과 8.8.8.8 에서도 빈 응답이 온다. 차단이 아니라 NOERROR 이므로 동작은 정상이지만,
화면에는 아무것도 안 나와 오해를 부른다. 학교 도메인을 쓸 일이 있으면 `www.sookmyung.ac.kr`
을 쓴다.

## 다시 검증하려면

모델을 교체했거나 오랜만에 발표 준비를 재개했을 때 돌린다.

```bash
for d in <차단 도메인들>; do
  printf "%-38s " "$d"
  dig +noall +comments +time=3 @10.3.0.15 "$d" | grep -oE "status: [A-Z]+"
done
```

`NXDOMAIN` 이 아닌 것이 하나라도 나오면 그 도메인은 목록에서 뺀다.

## 발표 직전에 할 일

검증하며 쌓인 시험 트래픽이 대시보드 숫자에 섞여 있다. 깨끗한 화면으로 시작하려면
지표를 들고 있는 두 컨테이너를 다시 올린다. Prometheus 에 남은 과거 구간은 지워지지
않으므로, 대시보드의 시간 범위를 재시작 이후로 잡는 편이 간단하다.

```bash
docker compose restart unbound api
```
