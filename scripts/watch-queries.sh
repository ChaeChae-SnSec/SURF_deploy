#!/usr/bin/env bash
# 발표용 실시간 질의 로그.
#
#   ./scripts/watch-queries.sh              모든 클라이언트
#   ./scripts/watch-queries.sh 10.3.0.16    그 기기의 질의만
#
# unbound 원본 로그는 디버그 줄이 섞여 스크롤이 지저분하다. 판정 결과만 한 줄씩
# 남기고 색을 입힌다. 시연 중 화면 한쪽에 띄우는 용도다.
#
# 여러 기기가 동시에 SURF 를 쓰고 있으면 화면이 섞인다. 시연에서는 보여줄 기기
# 하나만 인자로 넘겨 그 기기의 질의만 흐르게 하는 편이 낫다.
#
# SSH 로 접속해 띄운다면 tmux 안에서 실행한다. 연결이 끊겨도 살아 있다.
#   tmux new -s surf './scripts/watch-queries.sh 10.3.0.16'
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

FILTER="${1:-}"

RED=$'\033[38;5;203m'; BLUE=$'\033[38;5;75m'; YEL=$'\033[38;5;179m'
DIM=$'\033[2m'; BOLD=$'\033[1m'; OFF=$'\033[0m'

printf '%s\n' "${BOLD}SURF — 실시간 질의 로그${OFF}"
if [ -n "$FILTER" ]; then
    printf '%s\n' "${DIM}클라이언트 ${FILTER} 의 질의만 표시${OFF}"
else
    printf '%s\n' "${DIM}모든 클라이언트${OFF}"
fi
printf '%s\n' "${DIM}차단은 붉은색, 통과는 파란색, 허용 목록은 노란색. Ctrl+C 로 종료.${OFF}"
printf '%s\n\n' "${DIM}$(printf '─%.0s' {1..74})${OFF}"

CLIENT=""
BLOCKED=0
TOTAL=0

emit() {  # 색 도메인 표시 상태
    local color=$1 domain=$2 state=$3
    TOTAL=$((TOTAL + 1))
    printf '%s%s%s  %s%-44s%s %s  %s%s%s\n' \
        "$DIM" "$(date +%H:%M:%S)" "$OFF" \
        "$color" "$domain" "$OFF" "$state" \
        "$DIM" "${CLIENT:-?}" "$OFF"
}

docker compose logs -f --tail 0 unbound 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *"FINAL IP CHECK"*)
            CLIENT="${line##*Client ID: }"
            CLIENT="${CLIENT%% *}"
            continue
            ;;
    esac

    # 필터가 걸려 있으면 그 기기의 질의만 통과시킨다.
    if [ -n "$FILTER" ] && [ "$CLIENT" != "$FILTER" ]; then
        continue
    fi

    case "$line" in
        *"SURF BLOCKED"*)
            D="${line##*SURF BLOCKED] }"
            BLOCKED=$((BLOCKED + 1))
            emit "$RED" "$D" "${RED}← 차단${OFF}"
            ;;
        *"SURF AI ALLOWED"*)
            D="${line##*SURF AI ALLOWED] }"
            emit "$BLUE" "$D" "${DIM}통과  ${OFF}"
            ;;
        *"WHITELIST PASS"*)
            D="${line##*WHITELIST PASS]: }"
            emit "$YEL" "$D" "${DIM}허용목록${OFF}"
            ;;
    esac
done
