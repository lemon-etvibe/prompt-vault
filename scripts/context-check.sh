#!/bin/bash
# Claude 응답 완료 시마다 실행 — transcript 크기로 컨텍스트 사용량 추정
INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# 설정 파일에서 threshold 읽기 (없으면 기본값)
CONFIG=".local/logs/.config"
if [ -f "$CONFIG" ]; then
  THRESHOLD=$(jq -r '.warn_bytes // 640000' "$CONFIG")
else
  # 기본: 200K 토큰 모델의 80% ≈ 640KB transcript
  THRESHOLD=640000
fi

SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d ' ')

if [ "$SIZE" -gt "$THRESHOLD" ]; then
  PCT=$((SIZE * 100 / (THRESHOLD * 100 / 80)))
  echo "⚠️ [prompt-vault] Context ~${PCT}% used (${SIZE} bytes)."
  echo "💡 Run /prompt-vault:log to save progress, then /compact to free context."
fi
