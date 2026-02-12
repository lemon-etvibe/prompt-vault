#!/bin/bash
# 컨텍스트 압축 후 세션 재시작 시 실행
# stdout → Claude에게 컨텍스트로 주입
LOG_DIR=".local/logs"
if [ -d "$LOG_DIR" ]; then
  echo "=== Phase Progress (post-compaction recovery) ==="
  if [ -f "$LOG_DIR/_index.md" ]; then
    cat "$LOG_DIR/_index.md"
  fi
  echo ""
  echo "=== Latest Phase Log ==="
  LATEST=$(ls -t "$LOG_DIR"/phase-*.md 2>/dev/null | head -1)
  if [ -n "$LATEST" ]; then
    cat "$LATEST"
  else
    echo "(No phases logged yet)"
  fi
  echo "=== End Recovery ==="
fi
