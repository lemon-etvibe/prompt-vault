---
description: "Generate visual HTML dashboards from phase logs. Use when the user asks for '리포트', '보고서', 'report', or 'dashboard'."
argument-hint: [summary|detail|all|custom]
allowed-tools: ["Skill"]
---

**You MUST use the Skill tool to invoke `prompt-vault:report` with args `{argument or "all"}`.**

This skill:
- Runs `generate-report.sh` to parse `_index.md` + `phase-*.md` → HTML reports
- Generates `report-summary.html` (dashboard) and `report-detail.html` (chat log)
- Zero token cost — pure shell script execution

Do NOT generate or write HTML manually — always delegate to the skill.
