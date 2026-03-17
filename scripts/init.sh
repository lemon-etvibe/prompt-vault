#!/usr/bin/env bash
# init.sh — prompt-vault deterministic initialization
# Called by SKILL.md after collecting user preferences.
#
# Usage: bash init.sh <project_dir> <lang> <model_id> <context_tokens> <warn_bytes> <project_name> <project_desc> <palette_json> <auto_log_enabled> <turn_threshold>
#
# All file creation is handled here to prevent Claude from improvising.

set -euo pipefail

PROJECT_DIR="${1:-.}"
LANG_CODE="${2:-en}"
MODEL_ID="${3:-claude-opus-4-6}"
CONTEXT_TOKENS="${4:-200000}"
WARN_BYTES="${5:-640000}"
PROJECT_NAME="${6:-$(basename "$PROJECT_DIR")}"
PROJECT_DESC="${7:-}"
PALETTE_JSON="${8:-[\"#264653\",\"#2A9D8F\",\"#E9C46A\",\"#F4A261\",\"#E76F51\"]}"
AUTO_LOG_ENABLED="${9:-false}"
TURN_THRESHOLD="${10:-3}"

LOGS_DIR="$PROJECT_DIR/.local/logs"
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# === 1. Create logs directory ===
mkdir -p "$LOGS_DIR"

# === 2. Add .local/ to .gitignore ===
GITIGNORE="$PROJECT_DIR/.gitignore"
if [ -f "$GITIGNORE" ]; then
  if ! grep -qxF '.local/' "$GITIGNORE"; then
    printf '\n# prompt-vault logs\n.local/\n' >> "$GITIGNORE"
  fi
else
  printf '# prompt-vault logs\n.local/\n' > "$GITIGNORE"
fi

# === 3. Create _index.md ===
INDEX_FILE="$LOGS_DIR/_index.md"
if [ ! -f "$INDEX_FILE" ]; then
  cat > "$INDEX_FILE" << 'INDEXEOF'
# Phase Log Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
INDEXEOF
fi

# === 4. Create .config ===
CONFIG_FILE="$LOGS_DIR/.config"
if [ -f "$CONFIG_FILE" ]; then
  # Merge: preserve existing fields, update provided ones
  TEMP_CONFIG=$(mktemp)
  # Build new config JSON
  cat > "$TEMP_CONFIG" << CFGEOF
{
  "lang": "$LANG_CODE",
  "model": "$MODEL_ID",
  "context_window_tokens": $CONTEXT_TOKENS,
  "warn_percent": 80,
  "warn_bytes": $WARN_BYTES,
  "project_name": "$PROJECT_NAME",
  "project_description": "$PROJECT_DESC",
  "palette": $PALETTE_JSON
}
CFGEOF
  # Merge: existing + new (new wins on conflicts)
  if command -v jq &>/dev/null; then
    jq -s '.[0] * .[1]' "$CONFIG_FILE" "$TEMP_CONFIG" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  else
    # No jq: overwrite with new config
    mv "$TEMP_CONFIG" "$CONFIG_FILE"
  fi
  rm -f "$TEMP_CONFIG"
else
  cat > "$CONFIG_FILE" << CFGEOF
{
  "lang": "$LANG_CODE",
  "model": "$MODEL_ID",
  "context_window_tokens": $CONTEXT_TOKENS,
  "warn_percent": 80,
  "warn_bytes": $WARN_BYTES,
  "project_name": "$PROJECT_NAME",
  "project_description": "$PROJECT_DESC",
  "palette": $PALETTE_JSON
}
CFGEOF
fi

# === 5. Merge autoLog if enabled ===
if [ "$AUTO_LOG_ENABLED" = "true" ]; then
  if command -v jq &>/dev/null; then
    jq --argjson threshold "$TURN_THRESHOLD" \
      '. + {"autoLog": {"enabled": true, "turnThreshold": $threshold}}' \
      "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  else
    # Fallback: append manually (not ideal but functional)
    sed -i.bak 's/}$/,\n  "autoLog": {"enabled": true, "turnThreshold": '"$TURN_THRESHOLD"'}\n}/' "$CONFIG_FILE"
    rm -f "${CONFIG_FILE}.bak"
  fi
fi

# === 6. Add CLAUDE.md snippet ===
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
SNIPPET_FILE="$PLUGIN_ROOT/templates/claude-md-snippet.md"
if [ -f "$CLAUDE_MD" ]; then
  if ! grep -q "Phase Logging Protocol" "$CLAUDE_MD"; then
    printf '\n' >> "$CLAUDE_MD"
    cat "$SNIPPET_FILE" >> "$CLAUDE_MD"
  fi
else
  cat "$SNIPPET_FILE" > "$CLAUDE_MD"
fi

# === 7. Output result ===
echo "OK"
echo "LOGS_DIR=$LOGS_DIR"
echo "CONFIG=$CONFIG_FILE"
echo "INDEX=$INDEX_FILE"
