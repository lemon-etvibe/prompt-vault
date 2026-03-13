#!/bin/bash
# get-lang.sh — Read lang setting from .config
# Usage: source "$(dirname "$0")/get-lang.sh"
# Sets: LANG_CODE="en" or "ko"

CONFIG=".local/logs/.config"
if command -v jq &>/dev/null && [ -f "$CONFIG" ]; then
  LANG_CODE=$(jq -r '.lang // "ko"' "$CONFIG" 2>/dev/null)
else
  LANG_CODE="ko"
fi
LANG_CODE="${LANG_CODE:-ko}"
