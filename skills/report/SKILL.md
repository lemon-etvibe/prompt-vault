---
name: report
description: Visualize phase logs as HTML reports.
disable-model-invocation: false
argument-hint: [summary|detail|all|custom]
---

Parse phase log data and generate visualized HTML reports.

## Arguments

- `summary` — Generate summary dashboard only
- `detail` — Generate detailed chat log view only
- `all` (default) — Generate both
- `custom` — Claude generates a custom report based on user request

## Procedure

### Standard Reports (summary / detail / all)

1. Execute `${CLAUDE_PLUGIN_ROOT}/scripts/generate-report.sh`:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/generate-report.sh" [summary|detail|all]
   ```

2. Inform the user of generated file paths:
   - `.local/logs/report-summary.html` — Project summary dashboard
   - `.local/logs/report-detail.html` — Phase-by-phase detailed chat log

3. Guide how to open in browser:
   ```bash
   open .local/logs/report-summary.html   # macOS
   xdg-open .local/logs/report-detail.html # Linux
   ```

### Custom Reports (custom)

1. First generate standard reports (same procedure as above).
2. Confirm the user's additional requests (e.g., "add retrospective section", "apply specific palette").
3. Read the generated HTML files and modify/enhance per user request.
4. Save modified files and inform the user of paths.

## Data Sources

Reference the following data when generating reports:

- **Project metadata**: `.local/logs/.config` — `project_name`, `project_description`, `palette`
- **Phase index**: `.local/logs/_index.md` — phase list table
- **Phase details**: `.local/logs/phase-*.md` — prompts, actions, results, decisions, next steps per phase
- **Additional context** (if available): `package.json`, `CLAUDE.md`

## Error Handling

- `.local/logs/` does not exist → Guide user to run `/prompt-vault:init`
- `_index.md` missing → Generate empty report with warning message
- `phase-*.md` non-standard format → Display parseable parts only, leave rest empty
- `.config` missing → Use defaults (project directory name, default palette)
