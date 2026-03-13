---
name: init
description: "Initialize prompt-vault logging environment. Use when starting a new project, when .local/logs/ doesn't exist, or when the user says init, 초기화, set up logging. Also trigger if other skills fail because logging isnt set up yet."
disable-model-invocation: false
argument-hint: [en|ko]
---

Set up the prompt-vault logging environment for a project.

## Language Detection (Step 1 — ALWAYS run this first, no exceptions)

**IMPORTANT: Always ask the user to choose a language before doing anything else, even if `.local/logs/` already exists.**

1. Check `$ARGUMENTS`:
   - If `$ARGUMENTS` is `en` → set `LANG_CODE="en"`, skip asking
   - If `$ARGUMENTS` is `ko` → set `LANG_CODE="ko"`, skip asking
   - If `$ARGUMENTS` is empty → **ask the user NOW**:
     ```
     Choose language / 언어 선택:
     [1] English (default — recommended for shared projects)
     [2] 한국어

     Enter 1 or 2 (default: 1):
     ```
   - User selects 1 or presses Enter → `LANG_CODE="en"`
   - User selects 2 → `LANG_CODE="ko"`

Save `LANG_CODE` — it will be written to config in step 7.

## Procedure

2. Create `.local/logs/` directory
3. Add `.local/` to `.gitignore` (skip if already present)
   — WHY: Logs are personal work records and should not be committed to git
4. Initialize `.local/logs/_index.md` (template-based)

   ```markdown
   # Phase Log Index

   | # | Title | Status | Date | Summary |
   |---|-------|--------|------|---------|
   ```

5. Add Phase Logging Protocol section to `CLAUDE.md` (skip if already present)
   — WHY: So Claude automatically follows the logging protocol
   → Reference content from ${CLAUDE_PLUGIN_ROOT}/templates/claude-md-snippet.md
6. Ask user about model/plan and set context threshold in `.local/logs/.config`:

   | Model | Context | 80% threshold (est. bytes) |
   |-------|---------|---------------------------|
   | Opus 4.6 (200K) | 200K tokens | ~640,000 bytes |
   | Sonnet 4.5 (200K) | 200K tokens | ~640,000 bytes |
   | Haiku 4.5 (200K) | 200K tokens | ~640,000 bytes |
   | Extended (1M) | 1M tokens | ~3,200,000 bytes |

7. Set up project metadata and report palette:
   - `project_name`: Project name (default: current directory name)
   - `project_description`: One-line project description (default: empty)
   - `lang`: Language code from step 1 (`"en"` or `"ko"`)
   - `palette`: 5-color palette array — auto-generate via colormind.io API, fallback to `${CLAUDE_PLUGIN_ROOT}/data/palettes.json` random selection

   Palette generation methods:
   ```bash
   # Primary: colormind.io API call (free, no key required)
   curl -s -X POST http://colormind.io/api/ -d '{"model":"default"}'
   # Convert RGB array from response to HEX and store in palette field

   # Fallback: random selection from curated palettes
   jq -r '.['"$RANDOM_INDEX"']' "${CLAUDE_PLUGIN_ROOT}/data/palettes.json"
   ```

   Palette role guide:
   - `palette[0]`: Primary — headers, main buttons, titles
   - `palette[1]`: Secondary — timeline, badges, links
   - `palette[2]`: Accent — highlights, hover, emphasis
   - `palette[3]`: Surface — card backgrounds, dividers
   - `palette[4]`: Muted — subtext, inactive states

   Default config example:
   ```json
   {
     "lang": "en",
     "model": "claude-opus-4-6",
     "context_window_tokens": 200000,
     "warn_percent": 80,
     "warn_bytes": 640000,
     "project_name": "My Project",
     "project_description": "",
     "palette": ["#264653", "#2A9D8F", "#E9C46A", "#F4A261", "#E76F51"]
   }
   ```

8. Configure auto-logging:
   - en: "Enable auto-logging? (Turn-count based automatic recording via Stop hook)"
   - ko: "자동 로깅을 활성화할까요? (Stop 훅에서 턴 수 기반 자동 기록)"
   - If yes: MERGE `autoLog` into existing `.config` (do NOT overwrite other fields)
     — WHY: To avoid overwriting existing settings (palette, warn_bytes, etc.)
     ```json
     {
       "autoLog": {
         "enabled": true,
         "turnThreshold": 3
       }
     }
     ```
   - If no: skip (autoLog key absent = disabled by default)
   - Note: Read existing `.config` first, merge `autoLog` key, then write back

9. Output initialization complete message — include generated palette preview and restart guide:

   Based on chosen language:
   - en:
     ```
     ✅ Initialized! Phase Logging Protocol added to CLAUDE.md.
     💡 Restart Claude to apply: /exit → claude --continue
     ```
   - ko:
     ```
     ✅ 초기화 완료! CLAUDE.md에 로깅 프로토콜이 추가되었습니다.
     💡 Claude를 재시작하면 프로토콜이 자동 적용됩니다: /exit → claude --continue
     ```

   Note: Use `--continue` flag to resume the session with CLAUDE.md changes applied.
