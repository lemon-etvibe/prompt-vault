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

6. 프로젝트 메타 정보 및 리포트 팔레트 설정:
   - `project_name`: 프로젝트 이름 (기본: 현재 디렉토리명)
   - `project_description`: 프로젝트 한 줄 설명 (기본: 빈 문자열)
   - `palette`: 5색 팔레트 배열 — colormind.io API로 자동 생성, 실패 시 `${CLAUDE_PLUGIN_ROOT}/data/palettes.json`에서 랜덤 선택

   팔레트 생성 방법:
   ```bash
   # 1차: colormind.io API 호출 (무료, 키 불필요)
   curl -s -X POST http://colormind.io/api/ -d '{"model":"default"}'
   # 응답의 RGB 배열을 HEX로 변환하여 palette 필드에 저장

   # 2차 fallback: 큐레이션 팔레트에서 랜덤 선택
   jq -r '.['"$RANDOM_INDEX"']' "${CLAUDE_PLUGIN_ROOT}/data/palettes.json"
   ```

   팔레트 역할 안내:
   - `palette[0]`: Primary — 헤더, 주요 버튼, 타이틀
   - `palette[1]`: Secondary — 타임라인, 뱃지, 링크
   - `palette[2]`: Accent — 하이라이트, 호버, 강조
   - `palette[3]`: Surface — 카드 배경, 구분선
   - `palette[4]`: Muted — 서브텍스트, 비활성 상태

   기본 설정 예시:
   ```json
   {
     "model": "claude-opus-4-6",
     "context_window_tokens": 200000,
     "warn_percent": 80,
     "warn_bytes": 640000,
     "project_name": "My Project",
     "project_description": "",
     "palette": ["#264653", "#2A9D8F", "#E9C46A", "#F4A261", "#E76F51"]
   }
   ```

7. 초기화 완료 메시지 출력 — 생성된 팔레트 미리보기 포함
