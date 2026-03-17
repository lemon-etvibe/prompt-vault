---
name: report
description: "Generate visual HTML dashboards from phase logs. Use when the user asks for '리포트', '보고서', 'report', 'dashboard', visualization, or wants to see work history in a browser."
disable-model-invocation: false
argument-hint: [summary|detail|all|custom]
---

Generate HTML reports from phase logs using the shell script.

**CRITICAL: NEVER generate HTML yourself. ALWAYS run the shell script below.**

## Procedure

### Step 1: Run the script

**MUST execute this command — do NOT write HTML manually:**

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/generate-report.sh" "${1:-all}"
```

Arguments: `summary`, `detail`, `all` (default), or omit for `all`.

The script generates exactly two files:
- `.local/logs/report-summary.html` — Project summary dashboard
- `.local/logs/report-detail.html` — Phase-by-phase detailed chat log

**Do NOT create `report.html`, `report_detail.html`, or any other filename.**

### Step 2: Verify output

```bash
ls -la .local/logs/report-summary.html .local/logs/report-detail.html
```

**If either file is missing, report the error — do NOT generate HTML as fallback.**

### Step 3: Report to user

Read `lang` from `.local/logs/.config` (default: `"ko"`).

- en: `✅ Report generated!`
- ko: `✅ 리포트 생성 완료!`

Then show file paths and open command:
```
- Summary: .local/logs/report-summary.html
- Detail: .local/logs/report-detail.html

open .local/logs/report-summary.html
```

## Custom Reports (`custom` argument only)

1. Run the standard script first (Step 1 above).
2. Ask the user what they want to customize.
3. Read the **generated** HTML and modify per request.
4. Save and inform paths.

## Error Handling

- `.local/logs/` not found → Guide user to run `/prompt-vault:init`
- Script fails → Show error output, do NOT attempt manual HTML generation
- `.config` missing → Script uses defaults automatically
