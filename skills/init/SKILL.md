---
name: init
description: "Initialize prompt-vault logging environment. Use when starting a new project, when .local/logs/ doesn't exist, or when the user says init, 초기화, set up logging. Also trigger if other skills fail because logging isnt set up yet."
disable-model-invocation: false
argument-hint: [en|ko]
---

Set up the prompt-vault logging environment for a project.
This skill collects user preferences, then delegates all file creation to `init.sh`.

## Step 1: Language

Check `$ARGUMENTS`:
- `en` → `LANG=en`, skip asking
- `ko` → `LANG=ko`, skip asking
- empty → ask:
  ```
  Choose language / 언어 선택:
  [1] English (default)  [2] 한국어
  ```

## Step 2: Model & Context

Ask which model/plan is in use:

| Model | context_tokens | warn_bytes |
|-------|---------------|------------|
| Opus 4.6 / Sonnet 4.5 / Haiku 4.5 (200K) | 200000 | 640000 |
| Extended (1M) | 1000000 | 3200000 |

## Step 3: Project Metadata

- `project_name`: default = current directory name
- `project_description`: one-line description (default: empty)

## Step 4: Palette

Generate a 5-color palette:
```bash
# Primary: colormind.io API (free, no key)
curl -s -X POST http://colormind.io/api/ -d '{"model":"default"}'
# Convert RGB → HEX array

# Fallback: random from curated palettes
jq -r ".[$RANDOM_INDEX]" "${CLAUDE_PLUGIN_ROOT}/data/palettes.json"
```

## Step 5: Auto-Logging

Ask:
- en: "Enable auto-logging? (Turn-count based automatic recording via Stop hook)"
- ko: "자동 로깅을 활성화할까요? (Stop 훅에서 턴 수 기반 자동 기록)"

If yes → `auto_log=true`, `turn_threshold=3`
If no → `auto_log=false`

## Step 6: Run init.sh

**MUST execute this command — this is the core of initialization:**

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init.sh" \
  "$PWD" \
  "<LANG>" \
  "<MODEL_ID>" \
  "<CONTEXT_TOKENS>" \
  "<WARN_BYTES>" \
  "<PROJECT_NAME>" \
  "<PROJECT_DESC>" \
  '<PALETTE_JSON>' \
  "<AUTO_LOG_ENABLED>" \
  "<TURN_THRESHOLD>"
```

The script creates ALL required files:
- `.local/logs/` directory
- `.local/logs/.config` (NOT config.json — the file MUST be named `.config`)
- `.local/logs/_index.md`
- `.gitignore` entry
- `CLAUDE.md` logging protocol section

## Step 7: Verify & Report

After init.sh completes, verify these files exist:
```bash
ls -la .local/logs/.config .local/logs/_index.md
grep "Phase Logging Protocol" CLAUDE.md
```

**If any file is missing, report the error — do NOT silently skip.**

Output:
- en: `✅ Initialized! Phase Logging Protocol added to CLAUDE.md.`
- ko: `✅ 초기화 완료! CLAUDE.md에 로깅 프로토콜이 추가되었습니다.`

Then:
```
💡 Restart Claude to apply: /exit → claude --continue
```
