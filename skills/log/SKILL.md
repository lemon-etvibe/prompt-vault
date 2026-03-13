---
name: log
description: "Record completed work as a phase log. Use proactively when a task is done, before context compaction, when the user says '로그', '기록', 'save progress', 'log', or before ending a session. If in doubt, suggest logging — losing progress is worse than an extra log."
disable-model-invocation: false
argument-hint: [phase-title]
---

Record completed work from the current conversation session as a phase log.

## Procedure

1. Verify `.local/logs/` directory exists (create if missing)
2. Determine next phase number from existing `phase-*.md` file count (3-digit zero-padded)
3. Write `phase-NNN.md` in the following format:

   ```
   # Phase NNN: $ARGUMENTS (or auto-inferred title)

   - **Date**: YYYY-MM-DD
   - **Session**: (session ID or timestamp)
   - **Trigger**: manual

   ## User Prompt
   > Record the user's original request as close to verbatim as possible

   ## Actions
   - List major actions performed by Claude in chronological order
   - Include tools used, files read, files created/modified

   ## Results
   - Summary of deliverables (generated file paths, key findings)
   - Key data or metrics

   ## Decisions
   - Decisions made and their rationale

   ## Next
   - Next steps or open items
   ```

4. Update `.local/logs/_index.md`: add/update the phase row

   ```
   | NNN | Title | done | YYYY-MM-DD | One-line summary |
   ```

5. Update auto-log state file (`.local/logs/last-log-state.json`) to prevent auto-logger duplication:
   — WHY: 자동 로거(Stop/PreCompact 훅)가 같은 내용을 중복 기록하지 않도록
   - Compute transcript hash via Bash:
     ```bash
     shasum -a 256 ~/.claude/projects/.../SESSION_ID.jsonl | cut -d' ' -f1
     ```
     Prefix with `sha256:` to form `"sha256:<hex>"`
   - Write state:
     ```json
     {
       "lastLogTimestamp": <current_timestamp_ms>,
       "lastTranscriptHash": "sha256:<hash>",
       "lastLogTurnCount": <total_turn_count>,
       "lastPhaseNumber": "<NNN>",
       "lastTrigger": "manual"
     }
     ```
   - This ensures the auto-logger (Stop/PreCompact hooks) won't re-log the same content

6. Output completion message (bilingual based on `lang` in `.local/logs/.config`):
   - en: "✅ Phase NNN logged."
   - ko: "✅ Phase NNN 기록 완료."

## Example

**Input**: `/prompt-vault:log 로그인 버그 수정`

**Output** (`phase-003.md`):
```markdown
# Phase 003: 로그인 버그 수정
- **Date**: 2026-03-12
- **Session**: abc123
- **Trigger**: manual

## User Prompt
> 로그인 시 null 에러 수정해줘

## Actions
- Read: src/auth.ts
- Edit: src/auth.ts — null 체크 추가
...
```
