# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-02-27

### Added
- Auto-logging system via Stop and PreCompact hooks
- `scripts/autolog.mjs` — Node.js auto-logging engine (zero external dependencies)
  - JSONL transcript parsing with readline streams
  - Turn-based trigger (configurable threshold, default: 3 turns)
  - SHA-256 hash dedup prevents Stop → PreCompact double-logging
  - Lock file with stale PID detection prevents concurrent execution
  - Phase log generation compatible with `generate-report.sh`
- `last-log-state.json` — state tracking for incremental logging
- `- **Trigger**:` metadata field in phase template
- Auto-log opt-in configuration via `/prompt-vault:init`

### Changed
- `hooks/hooks.json` — added autolog.mjs to Stop (timeout: 10s) and PreCompact (timeout: 15s) hooks
- `skills/init/SKILL.md` — added autoLog configuration step (enabled, turnThreshold)
- `skills/log/SKILL.md` — manual log now updates `last-log-state.json` to prevent auto-logger duplication
- `templates/phase.md` — added Trigger metadata field
- `plugin.json` — version bumped to 1.2.0

## [1.1.0] - 2026-02-26

### Added
- `/prompt-vault:report` skill — visualize phase logs as HTML reports
- `scripts/generate-report.sh` — zero token cost report generation (pure shell)
- `templates/report-summary.html` — project summary dashboard template
- `templates/report-detail.html` — detailed chat log viewer template
- `data/palettes.json` — 13 curated 5-color palette presets
- colormind.io API integration for automatic palette generation
- `.config` extended with `project_name`, `project_description`, `palette` fields
- Dual-track architecture: shell script (auto) + Claude skill (custom)
- Summary ↔ Detail cross-navigation links

### Changed
- `skills/init/SKILL.md` — added palette setup flow with colormind.io fallback
- `plugin.json` — version bumped to 1.1.0

## [1.0.0] - 2026-02-12

### Added
- Initial release
- `/prompt-vault:init` — project logging environment initialization
- `/prompt-vault:log` — phase-based conversation logging
- `/prompt-vault:status` — progress summary display
- Hook system: Stop (context warning), PreCompact (checkpoint), SessionStart (recovery)
- `scripts/context-check.sh` — automatic context usage monitoring
- `scripts/pre-compact.sh` — pre-compaction checkpoint recording
- `scripts/post-compact.sh` — post-compaction auto-recovery
- Phase log template (`templates/phase.md`)
- Comprehensive documentation (README, ARCHITECTURE, GETTING_STARTED)
