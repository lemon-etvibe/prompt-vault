---
name: init
description: "Initialize prompt-vault logging environment. Use when starting a new project, when .local/logs/ doesn't exist, or when the user says 'init', '초기화', 'set up logging'. Also trigger if other skills fail because logging isn't set up yet."
disable-model-invocation: true
---

Set up the prompt-vault logging environment for a project.

## Procedure

1. Create `.local/logs/` directory
2. Add `.local/` to `.gitignore` (skip if already present)
   — WHY: 로그는 개인 작업 기록이라 git에 포함하면 안 됨
3. Initialize `.local/logs/_index.md` (template-based)

   ```markdown
   # Phase Log Index

   | # | Title | Status | Date | Summary |
   |---|-------|--------|------|---------|
   ```

4. Add Phase Logging Protocol section to `CLAUDE.md` (skip if already present)
   — WHY: Claude가 로깅 프로토콜을 자동으로 따르게 하기 위해
   → Reference content from ${CLAUDE_PLUGIN_ROOT}/templates/claude-md-snippet.md
5. Ask user about model/plan and set context threshold in `.local/logs/.config`:

   | Model | Context | 80% threshold (est. bytes) |
   |-------|---------|---------------------------|
   | Opus 4.6 (200K) | 200K tokens | ~640,000 bytes |
   | Sonnet 4.5 (200K) | 200K tokens | ~640,000 bytes |
   | Haiku 4.5 (200K) | 200K tokens | ~640,000 bytes |
   | Extended (1M) | 1M tokens | ~3,200,000 bytes |

6. Set up project metadata and report palette:
   - `project_name`: Project name (default: current directory name)
   - `project_description`: One-line project description (default: empty)
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
     "model": "claude-opus-4-6",
     "context_window_tokens": 200000,
     "warn_percent": 80,
     "warn_bytes": 640000,
     "project_name": "My Project",
     "project_description": "",
     "palette": ["#264653", "#2A9D8F", "#E9C46A", "#F4A261", "#E76F51"]
   }
   ```

7. Configure auto-logging:
   - Ask user: "자동 로깅을 활성화할까요? (Stop 훅에서 턴 수 기반 자동 기록)"
   - If yes: MERGE `autoLog` into existing `.config` (do NOT overwrite other fields)
     — WHY: 기존 설정(palette, warn_bytes 등)을 덮어쓰지 않기 위해
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

8. Output initialization complete message — include generated palette preview and restart guide:

   ```
   ✅ 초기화 완료! CLAUDE.md에 로깅 프로토콜이 추가되었습니다.
   💡 Claude를 재시작하면 프로토콜이 자동 적용됩니다:
      /exit → claude --continue
   ```

   Note: Use `--continue` flag to resume the session with CLAUDE.md changes applied.
