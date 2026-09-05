#!/usr/bin/env bash
# 모델 가중치와 토크나이저를 artifacts/ 로 내려받는다.
#
# 저장소에 넣지 않는 이유는 두 가지다. 가중치가 93MB 라 클론이 무거워지고,
# 나중에 SURF 의 TLD-aware 가중치로 갈아탈 때 파일만 바꿔 끼우면 되게 하려는 것이다.
set -euo pipefail

DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/artifacts"
mkdir -p "$DEST"

MODEL_URL="https://huggingface.co/snsec-net/dga-detector-drift26dsn/resolve/main/finetuning.pt"
TOKENIZER_URL="https://raw.githubusercontent.com/snsec-net/2026-DSN-DRIFT/main/artifacts/tokenizer/tokenizer-0-30522-both.json"

# 파일명은 SURF_AI_model 의 VARIANTS['drift'] 가 기대하는 이름에 맞춘다.
MODEL_DEST="$DEST/finetuning_0331_2010.pt"
TOKENIZER_DEST="$DEST/tokenizer-0-30522-both.json"

fetch() {
    local url="$1" dest="$2" label="$3"
    if [ -s "$dest" ]; then
        echo "  이미 있음: $label ($(du -h "$dest" | cut -f1))"
        return
    fi
    echo "  받는 중: $label"
    curl -fL --progress-bar "$url" -o "$dest.part"
    mv "$dest.part" "$dest"
}

echo "아티팩트를 $DEST 로 받습니다."
fetch "$MODEL_URL" "$MODEL_DEST" "가중치 (finetuning.pt)"
fetch "$TOKENIZER_URL" "$TOKENIZER_DEST" "토크나이저"

echo
echo "확인:"
ls -lh "$DEST" | tail -n +2

# 받은 가중치가 기대한 구조인지 본다. 다른 체크포인트를 받아 오면
# 컨테이너가 뜬 뒤 shape mismatch 로 죽는데, 그때는 원인을 찾기 번거롭다.
if command -v python3 >/dev/null && python3 -c "import torch" 2>/dev/null; then
    echo
    echo "체크포인트 구조 확인:"
    python3 - "$MODEL_DEST" <<'PY'
import sys, torch
sd = torch.load(sys.argv[1], map_location='cpu', weights_only=False)
if not isinstance(sd, dict):
    sd = sd.state_dict()
expect = {
    'embedding_t.embedding.weight': (30522, 256),
    'embedding_c.embedding.weight': (43, 256),
    'classifier_head.dense1.weight': (512, 1024),
}
ok = True
for key, shape in expect.items():
    got = tuple(sd[key].shape) if key in sd else None
    mark = '✅' if got == shape else '❌'
    if got != shape:
        ok = False
    print(f"  {mark} {key}: {got} (기대 {shape})")
print("  -> drift variant 와 일치" if ok else "  -> 불일치. SURF_MODEL_VARIANT 를 확인하세요")
PY
fi
