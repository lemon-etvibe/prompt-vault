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

5. Output completion message
