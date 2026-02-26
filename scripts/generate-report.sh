#!/bin/bash
# generate-report.sh — prompt-vault HTML report generator
# Parses _index.md + phase-*.md → report-summary.html + report-detail.html
# Token cost: ZERO (pure shell script)

set -euo pipefail

LOGS_DIR=".local/logs"
CONFIG="${LOGS_DIR}/.config"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# === 0. Validate environment ===
if [ ! -d "$LOGS_DIR" ]; then
  echo "ERROR: ${LOGS_DIR} not found. Run /prompt-vault:init first." >&2
  exit 1
fi

# Temp directory for intermediate files (Oracle #4: avoid large shell variables)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# === 1. Read config ===
if command -v jq &>/dev/null && [ -f "$CONFIG" ]; then
  PROJECT_NAME=$(jq -r '.project_name // empty' "$CONFIG")
  PROJECT_DESC=$(jq -r '.project_description // empty' "$CONFIG")
  COLOR_1=$(jq -r '.palette[0] // .theme_color // empty' "$CONFIG")
  COLOR_2=$(jq -r '.palette[1] // empty' "$CONFIG")
  COLOR_3=$(jq -r '.palette[2] // empty' "$CONFIG")
  COLOR_4=$(jq -r '.palette[3] // empty' "$CONFIG")
  COLOR_5=$(jq -r '.palette[4] // empty' "$CONFIG")
fi

# Defaults (jq missing or fields empty)
PROJECT_NAME="${PROJECT_NAME:-$(basename "$(pwd)")}"
PROJECT_DESC="${PROJECT_DESC:-}"
COLOR_1="${COLOR_1:-#264653}"
COLOR_2="${COLOR_2:-#2A9D8F}"
COLOR_3="${COLOR_3:-#E9C46A}"
COLOR_4="${COLOR_4:-#F4A261}"
COLOR_5="${COLOR_5:-#E76F51}"

GENERATED_AT=$(date '+%Y-%m-%d %H:%M')

# === Helper: HTML escape (Neo #1: added single quote) ===
html_escape() {
  local text="$1"
  text="${text//&/&amp;}"
  text="${text//</&lt;}"
  text="${text//>/&gt;}"
  text="${text//\"/&quot;}"
  text="${text//\'/&#39;}"
  printf '%s' "$text"
}

# === Helper: Escape string for sed replacement (Neo #2: special chars) ===
sed_escape() {
  printf '%s' "$1" | sed 's/[&/|\\]/\\&/g'
}

# === Helper: Replace marker in file using head/tail split (Oracle #3: temp file) ===
replace_marker() {
  local file="$1"
  local marker="$2"
  local content_file="$3"
  local tmp="${file}.tmp"

  local marker_line
  marker_line=$(grep -n "$marker" "$file" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -z "$marker_line" ]; then
    return
  fi

  head -n $((marker_line - 1)) "$file" > "$tmp"
  cat "$content_file" >> "$tmp"
  tail -n +$((marker_line + 1)) "$file" >> "$tmp"
  mv "$tmp" "$file"
}

# === Helper: Extract section content using awk state machine (Oracle #1: moved out of loop) ===
extract_section() {
  local file="$1"
  local section="$2"
  awk -v sect="$section" '
    $0 == "## " sect { found=1; next }
    found && /^## / { exit }
    found { print }
  ' "$file" | sed '/^[[:space:]]*$/d'
}

# === Helper: Convert markdown list to HTML (Oracle #2: moved out of loop) ===
md_to_html_list() {
  local text="$1"
  if [ -z "$text" ]; then
    echo "<p class=\"text-gray-400 text-sm italic\">-</p>"
    return
  fi
  echo "<ul class=\"space-y-1 text-sm text-gray-700\">"
  echo "$text" | while IFS= read -r line; do
    line=$(echo "$line" | sed 's/^- //')
    [ -z "$line" ] && continue
    echo "  <li class=\"flex gap-2\"><span class=\"text-gray-400\">&bull;</span><span>${line}</span></li>"
  done
  echo "</ul>"
}

# === 2. Parse _index.md ===
PHASE_COUNT=0
DONE_COUNT=0
FIRST_DATE=""
LAST_DATE=""

# Temp files for accumulated HTML (Oracle #4: avoid ARG_MAX)
PHASE_TABLE_FILE="${TMP_DIR}/phase_table.html"
PHASE_TIMELINE_FILE="${TMP_DIR}/phase_timeline.html"
PHASE_NAV_FILE="${TMP_DIR}/phase_nav.html"
PHASE_SECTIONS_FILE="${TMP_DIR}/phase_sections.html"

: > "$PHASE_TABLE_FILE"
: > "$PHASE_TIMELINE_FILE"
: > "$PHASE_NAV_FILE"
: > "$PHASE_SECTIONS_FILE"

INDEX_FILE="${LOGS_DIR}/_index.md"
if [ -f "$INDEX_FILE" ]; then
  while IFS='|' read -r _ num title status date summary _; do
    num=$(echo "$num" | xargs 2>/dev/null || echo "$num")
    title=$(echo "$title" | xargs 2>/dev/null || echo "$title")
    status=$(echo "$status" | xargs 2>/dev/null || echo "$status")
    date=$(echo "$date" | xargs 2>/dev/null || echo "$date")
    summary=$(echo "$summary" | xargs 2>/dev/null || echo "$summary")

    [ -z "$num" ] && continue
    PHASE_COUNT=$((PHASE_COUNT + 1))

    # Track dates
    if [ -z "$FIRST_DATE" ]; then
      FIRST_DATE="$date"
    fi
    LAST_DATE="$date"

    # Count done
    if [ "$status" = "done" ]; then
      DONE_COUNT=$((DONE_COUNT + 1))
    fi

    # Status badge class
    local_status_class="status-pending"
    case "$status" in
      done) local_status_class="status-done" ;;
      in-progress|active) local_status_class="status-in-progress" ;;
    esac

    # Escape for HTML
    e_title=$(html_escape "$title")
    e_summary=$(html_escape "$summary")

    # Phase table row → temp file
    cat >> "$PHASE_TABLE_FILE" <<TABLEEOF
          <tr><td class="font-mono text-gray-400">${num}</td><td class="font-medium">${e_title}</td><td><span class="status-badge ${local_status_class}">${status}</span></td><td class="text-gray-500">${date}</td><td class="text-gray-500">${e_summary}</td></tr>
TABLEEOF

    # Timeline item → temp file
    cat >> "$PHASE_TIMELINE_FILE" <<TLEOF
      <div class="timeline-item mb-8">
        <div class="flex justify-between items-start mb-1">
          <span class="text-xs font-semibold px-2 py-0.5 rounded-full" style="background: var(--color-primary); color: white;">Phase ${num}</span>
          <span class="text-xs text-gray-400">${date}</span>
        </div>
        <h3 class="font-bold text-gray-800">${e_title}</h3>
        <p class="text-sm text-gray-500 mt-1">${e_summary}</p>
      </div>
TLEOF

    # Phase nav link → temp file
    cat >> "$PHASE_NAV_FILE" <<NAVEOF
      <a href="#phase-${num}"><span class="badge">${num}</span> ${e_title}</a>
NAVEOF

  done < <(awk 'NR>3 && /^\|/ && !/^\|[-| ]+\|$/' "$INDEX_FILE")
fi

# Date range
DATE_RANGE="${FIRST_DATE:-N/A}"
if [ -n "$LAST_DATE" ] && [ "$FIRST_DATE" != "$LAST_DATE" ]; then
  DATE_RANGE="${FIRST_DATE} ~ ${LAST_DATE}"
fi

# Progress percentage
if [ "$PHASE_COUNT" -gt 0 ]; then
  PROGRESS_PCT="$((DONE_COUNT * 100 / PHASE_COUNT))%"
else
  PROGRESS_PCT="0%"
fi

# === 3. Parse phase-*.md files ===
for phase_file in "${LOGS_DIR}"/phase-*.md; do
  [ -f "$phase_file" ] || continue

  # Extract phase number from filename
  PHASE_NUM=$(basename "$phase_file" | sed 's/phase-\([0-9]*\)\.md/\1/')

  # Title
  PHASE_TITLE=$(awk 'NR==1 {sub(/^# Phase [0-9]+: /, ""); print}' "$phase_file")
  PHASE_TITLE=$(html_escape "$PHASE_TITLE")

  # Date
  PHASE_DATE=$(awk -F': ' '/^\- \*\*Date\*\*/ {print $2}' "$phase_file")

  # Extract sections
  USER_PROMPT=$(extract_section "$phase_file" "User Prompt")
  USER_PROMPT=$(html_escape "$USER_PROMPT")
  USER_PROMPT=$(echo "$USER_PROMPT" | sed 's/^&gt; //')

  ACTIONS=$(extract_section "$phase_file" "Actions")
  ACTIONS=$(html_escape "$ACTIONS")

  RESULTS=$(extract_section "$phase_file" "Results")
  RESULTS=$(html_escape "$RESULTS")

  DECISIONS=$(extract_section "$phase_file" "Decisions")
  DECISIONS=$(html_escape "$DECISIONS")

  NEXT=$(extract_section "$phase_file" "Next")
  NEXT=$(html_escape "$NEXT")

  # Convert to HTML lists
  ACTIONS_HTML=$(md_to_html_list "$ACTIONS")
  RESULTS_HTML=$(md_to_html_list "$RESULTS")
  DECISIONS_HTML=$(md_to_html_list "$DECISIONS")
  NEXT_HTML=$(md_to_html_list "$NEXT")

  # Build phase section → temp file
  cat >> "$PHASE_SECTIONS_FILE" <<PHEOF
    <section id="phase-${PHASE_NUM}" class="phase-section">
      <div class="phase-header p-6 mb-4">
        <div class="flex items-center gap-3 mb-2">
          <span class="text-xs font-semibold px-2.5 py-1 rounded-full" style="background: var(--color-primary); color: white;">Phase ${PHASE_NUM}</span>
          <span class="text-xs text-gray-400">${PHASE_DATE}</span>
        </div>
        <h2 class="text-xl font-bold text-gray-800">${PHASE_TITLE}</h2>
      </div>
PHEOF

  # User Prompt — left chat bubble
  if [ -n "$USER_PROMPT" ]; then
    cat >> "$PHASE_SECTIONS_FILE" <<USEREOF
      <div class="mb-4">
        <div class="flex items-start gap-3">
          <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm flex-shrink-0" style="background: var(--color-primary); color: white;">U</div>
          <div class="chat-user p-4">
            <p class="text-sm text-gray-700 whitespace-pre-wrap">${USER_PROMPT}</p>
          </div>
        </div>
      </div>
USEREOF
  fi

  # Claude Response — right chat bubble with collapsible sections
  cat >> "$PHASE_SECTIONS_FILE" <<AIEOF
      <div class="mb-4">
        <div class="flex items-start gap-3 justify-end">
          <div class="chat-ai p-4">
            <div class="step-card p-4 mb-3">
              <details>
                <summary class="text-sm font-bold text-gray-700">Actions <span class="tool-badge ml-2">수행 작업</span></summary>
                <div class="mt-3">${ACTIONS_HTML}</div>
              </details>
            </div>
            <div class="step-card p-4 mb-3">
              <details>
                <summary class="text-sm font-bold text-gray-700">Results <span class="tool-badge ml-2">결과</span></summary>
                <div class="mt-3">${RESULTS_HTML}</div>
              </details>
            </div>
            <div class="step-card p-4 mb-3">
              <details>
                <summary class="text-sm font-bold text-gray-700">Decisions <span class="tool-badge ml-2">결정</span></summary>
                <div class="mt-3">${DECISIONS_HTML}</div>
              </details>
            </div>
          </div>
          <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm flex-shrink-0 bg-gray-200 text-gray-600">C</div>
        </div>
      </div>
AIEOF

  # Next — separate card
  if [ -n "$NEXT" ]; then
    cat >> "$PHASE_SECTIONS_FILE" <<NEXTEOF
      <div class="next-card p-4 ml-11 mb-4">
        <div class="text-xs font-semibold text-gray-500 mb-2">Next Steps</div>
        ${NEXT_HTML}
      </div>
NEXTEOF
  fi

  echo "    </section>" >> "$PHASE_SECTIONS_FILE"
  echo "" >> "$PHASE_SECTIONS_FILE"
done

# === 4. Generate summary report ===
report_type="${1:-all}"

# Pre-escape variables for sed (Neo #2: special char safety)
S_PROJECT_NAME=$(sed_escape "$PROJECT_NAME")
S_PROJECT_DESC=$(sed_escape "$PROJECT_DESC")

generate_summary() {
  local template="${PLUGIN_ROOT}/templates/report-summary.html"
  local output="${LOGS_DIR}/report-summary.html"

  if [ ! -f "$template" ]; then
    echo "ERROR: Template not found: ${template}" >&2
    return 1
  fi

  # Step 1: Simple placeholder sed replacement (escaped values)
  sed "s|{{PROJECT_NAME}}|${S_PROJECT_NAME}|g; \
       s|{{PROJECT_DESC}}|${S_PROJECT_DESC}|g; \
       s|{{COLOR_1}}|${COLOR_1}|g; \
       s|{{COLOR_2}}|${COLOR_2}|g; \
       s|{{COLOR_3}}|${COLOR_3}|g; \
       s|{{COLOR_4}}|${COLOR_4}|g; \
       s|{{COLOR_5}}|${COLOR_5}|g; \
       s|{{PHASE_COUNT}}|${PHASE_COUNT}|g; \
       s|{{DONE_COUNT}}|${DONE_COUNT}|g; \
       s|{{PROGRESS_PCT}}|${PROGRESS_PCT}|g; \
       s|{{DATE_RANGE}}|${DATE_RANGE}|g; \
       s|{{GENERATED_AT}}|${GENERATED_AT}|g" "$template" > "$output"

  # Step 2: Multi-line markers via temp files
  replace_marker "$output" "{{PHASE_TABLE}}" "$PHASE_TABLE_FILE"
  replace_marker "$output" "{{PHASE_TIMELINE}}" "$PHASE_TIMELINE_FILE"

  echo "Generated: ${output}"
}

generate_detail() {
  local template="${PLUGIN_ROOT}/templates/report-detail.html"
  local output="${LOGS_DIR}/report-detail.html"

  if [ ! -f "$template" ]; then
    echo "ERROR: Template not found: ${template}" >&2
    return 1
  fi

  # Step 1: Simple placeholder sed replacement (escaped values)
  sed "s|{{PROJECT_NAME}}|${S_PROJECT_NAME}|g; \
       s|{{COLOR_1}}|${COLOR_1}|g; \
       s|{{COLOR_2}}|${COLOR_2}|g; \
       s|{{COLOR_3}}|${COLOR_3}|g; \
       s|{{COLOR_4}}|${COLOR_4}|g; \
       s|{{COLOR_5}}|${COLOR_5}|g; \
       s|{{GENERATED_AT}}|${GENERATED_AT}|g" "$template" > "$output"

  # Step 2: Multi-line markers via temp files
  replace_marker "$output" "{{PHASE_SECTIONS}}" "$PHASE_SECTIONS_FILE"
  replace_marker "$output" "{{PHASE_NAV}}" "$PHASE_NAV_FILE"

  echo "Generated: ${output}"
}

# === 5. Execute based on argument ===
case "$report_type" in
  summary)
    generate_summary
    ;;
  detail)
    generate_detail
    ;;
  all|"")
    generate_summary
    generate_detail
    ;;
  *)
    echo "Usage: generate-report.sh [summary|detail|all]" >&2
    exit 1
    ;;
esac
