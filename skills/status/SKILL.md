---
name: status
description: "Show phase progress summary. Use when the user asks '진행 상황', '현재 상태', 'status', 'progress', what's been done, or how many phases are logged."
disable-model-invocation: false
---

Read `.local/logs/_index.md` and display a formatted progress summary.

## Output Format

Display in this structure:
- Total phases / completed count
- Last logged phase title and date
- Table of recent phases (last 5)

## Error Handling

- `.local/logs/` not found → "로그 환경이 설정되지 않았습니다. `/prompt-vault:init`을 먼저 실행해주세요."
- `_index.md` exists but empty (no rows) → "아직 기록된 페이즈가 없습니다. 작업 완료 후 `/prompt-vault:log`로 기록해보세요."

## Example

**Output**:
```
📊 Phase Progress: 5 phases (5 done)
📅 Latest: Phase 005 — 자동 로깅 구현 (2026-03-12)

| # | Title | Status | Date |
|---|-------|--------|------|
| 005 | 자동 로깅 구현 | done | 2026-03-12 |
| 004 | 리포트 UI 개선 | done | 2026-03-10 |
| 003 | 로그인 버그 수정 | done | 2026-03-08 |
```
