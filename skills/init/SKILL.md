---
name: init
description: 현재 프로젝트에 prompt-vault 로깅 환경을 초기화한다.
disable-model-invocation: true
---

프로젝트에 prompt-vault 로깅 환경을 셋업한다.

## 실행 절차

1. `.local/logs/` 디렉토리 생성
2. `.gitignore`에 `.local/` 추가 (이미 있으면 스킵)
3. `.local/logs/_index.md` 초기화 (템플릿 기반)

   ```markdown
   # Phase Log Index

   | # | Title | Status | Date | Summary |
   |---|-------|--------|------|---------|
   ```

4. `CLAUDE.md`에 Phase Logging Protocol 섹션 추가 (이미 있으면 스킵)
   → ${CLAUDE_PLUGIN_ROOT}/templates/claude-md-snippet.md 내용 참조
5. 사용자에게 모델/플랜을 확인하고 `.local/logs/.config`에 context threshold 설정:

   | 모델 | 컨텍스트 | 80% threshold (추정 bytes) |
   |------|----------|---------------------------|
   | Opus 4.6 (200K) | 200K tokens | ~640,000 bytes |
   | Sonnet 4.5 (200K) | 200K tokens | ~640,000 bytes |
   | Haiku 4.5 (200K) | 200K tokens | ~640,000 bytes |
   | Extended (1M) | 1M tokens | ~3,200,000 bytes |

   기본 설정 예시:
   ```json
   {
     "model": "claude-opus-4-6",
     "context_window_tokens": 200000,
     "warn_percent": 80,
     "warn_bytes": 640000
   }
   ```

6. 초기화 완료 메시지 출력
