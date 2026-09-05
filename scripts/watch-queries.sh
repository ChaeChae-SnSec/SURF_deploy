#!/usr/bin/env bash
# 발표용 실시간 질의 로그.
#
#   ./scripts/watch-queries.sh
#
# unbound 원본 로그는 디버그 줄이 섞여 스크롤이 지저분하다. 판정 결과만 한 줄씩
# 남기고 색을 입혀 화면에 띄운다. 시연 중 옆에 켜두는 용도다.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

RED=$'\033[38;5;203m'; BLUE=$'\033[38;5;75m'; YEL=$'\033[38;5;179m'
DIM=$'\033[2m'; BOLD=$'\033[1m'; OFF=$'\033[0m'

printf '%s\n' "${BOLD}SURF — 실시간 질의 로그${OFF}"
printf '%s\n' "${DIM}차단은 붉은색, 통과는 파란색, 허용 목록은 노란색. Ctrl+C 로 종료.${OFF}"
printf '%s\n\n' "${DIM}$(printf '─%.0s' {1..72})${OFF}"

docker compose logs -f --tail 0 unbound 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *"FINAL IP CHECK"*)
            CLIENT="${line##*Client ID: }"
            CLIENT="${CLIENT%% *}"
            ;;
        *"SURF BLOCKED"*)
            D="${line##*SURF BLOCKED] }"
            printf '%s  %s%-46s%s %s← 차단%s  %s%s%s\n' \
                "$(date +%H:%M:%S)" "$RED" "$D" "$OFF" "$RED" "$OFF" \
                "$DIM" "${CLIENT:-?}" "$OFF"
            ;;
        *"SURF AI ALLOWED"*)
            D="${line##*SURF AI ALLOWED] }"
            printf '%s  %s%-46s%s %s통과%s    %s%s%s\n' \
                "$(date +%H:%M:%S)" "$BLUE" "$D" "$OFF" "$DIM" "$OFF" \
                "$DIM" "${CLIENT:-?}" "$OFF"
            ;;
        *"WHITELIST PASS"*)
            D="${line##*WHITELIST PASS]: }"
            printf '%s  %s%-46s%s %s허용 목록%s\n' \
                "$(date +%H:%M:%S)" "$YEL" "$D" "$OFF" "$DIM" "$OFF"
            ;;
    esac
done
