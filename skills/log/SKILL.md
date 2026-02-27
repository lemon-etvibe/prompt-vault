---
name: log
description: Record the current phase conversation to .local/logs/. Call when a phase is complete.
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

6. Output completion message
