#!/bin/bash
# 컨텍스트 압축 직전 실행 — 자동 시점 기록
LOG_DIR=".local/logs"
if [ -d "$LOG_DIR" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  PHASE_COUNT=$(ls -1 "$LOG_DIR"/phase-*.md 2>/dev/null | wc -l | tr -d ' ')
  {
    echo "⚠️ Auto-compaction at $TIMESTAMP"
    echo "Phase count: $PHASE_COUNT"
    echo "---"
  } >> "$LOG_DIR/compaction.log"
fi
