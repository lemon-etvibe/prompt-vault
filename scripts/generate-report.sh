#!/bin/bash
# generate-report.sh — prompt-vault HTML 리포트 생성기
# _index.md + phase-*.md 파싱 → report-summary.html + report-detail.html 생성
# 토큰 비용: 제로 (순수 셸 스크립트)

set -euo pipefail

LOGS_DIR=".local/logs"
CONFIG="${LOGS_DIR}/.config"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# === 0. 환경 검증 ===
if [ ! -d "$LOGS_DIR" ]; then
  echo "ERROR: ${LOGS_DIR} not found. Run /prompt-vault:init first." >&2
  exit 1
fi

# 임시 디렉토리 (대용량 셸 변수 회피)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# === 1. 설정 읽기 ===
if command -v jq &>/dev/null && [ -f "$CONFIG" ]; then
  PROJECT_NAME=$(jq -r '.project_name // empty' "$CONFIG")
  PROJECT_DESC=$(jq -r '.project_description // empty' "$CONFIG")
  COLOR_1=$(jq -r '.palette[0] // .theme_color // empty' "$CONFIG")
  COLOR_2=$(jq -r '.palette[1] // empty' "$CONFIG")
  COLOR_3=$(jq -r '.palette[2] // empty' "$CONFIG")
  COLOR_4=$(jq -r '.palette[3] // empty' "$CONFIG")
  COLOR_5=$(jq -r '.palette[4] // empty' "$CONFIG")
fi

# 기본값 (jq 미설치 또는 필드 비어있을 때)
PROJECT_NAME="${PROJECT_NAME:-$(basename "$(pwd)")}"
PROJECT_DESC="${PROJECT_DESC:-}"
COLOR_1="${COLOR_1:-#264653}"
COLOR_2="${COLOR_2:-#2A9D8F}"
COLOR_3="${COLOR_3:-#E9C46A}"
COLOR_4="${COLOR_4:-#F4A261}"
COLOR_5="${COLOR_5:-#E76F51}"

GENERATED_AT=$(date '+%Y-%m-%d %H:%M')

# === 헬퍼: HTML 이스케이핑 ===
html_escape() {
  local text="$1"
  text="${text//&/&amp;}"
  text="${text//</&lt;}"
  text="${text//>/&gt;}"
  text="${text//\"/&quot;}"
  text="${text//\'/&#39;}"
  printf '%s' "$text"
}

# === 헬퍼: sed 치환용 특수문자 이스케이핑 ===
sed_escape() {
  printf '%s' "$1" | sed 's/[&/|\\]/\\&/g'
}

# === 헬퍼: head/tail 분할로 마커 치환 ===
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

# === 헬퍼: awk 상태머신으로 섹션 내용 추출 ===
extract_section() {
  local file="$1"
  local section="$2"
  awk -v sect="$section" '
    $0 == "## " sect { found=1; next }
    found && /^## / { exit }
    found { print }
  ' "$file" | sed '/^[[:space:]]*$/d'
}

# === 헬퍼: 마크다운 리스트 → HTML 변환 ===
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

# === 2. _index.md 파싱 ===
PHASE_COUNT=0
DONE_COUNT=0
FIRST_DATE=""
LAST_DATE=""

# HTML 누적용 임시 파일 (ARG_MAX 회피)
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

# 날짜 범위
DATE_RANGE="${FIRST_DATE:-N/A}"
if [ -n "$LAST_DATE" ] && [ "$FIRST_DATE" != "$LAST_DATE" ]; then
  DATE_RANGE="${FIRST_DATE} ~ ${LAST_DATE}"
fi

# 진행률
if [ "$PHASE_COUNT" -gt 0 ]; then
  PROGRESS_PCT="$((DONE_COUNT * 100 / PHASE_COUNT))%"
else
  PROGRESS_PCT="0%"
fi

# === 3. phase-*.md 파싱 ===
for phase_file in "${LOGS_DIR}"/phase-*.md; do
  [ -f "$phase_file" ] || continue

  # 파일명에서 페이즈 번호 추출
  PHASE_NUM=$(basename "$phase_file" | sed 's/phase-\([0-9]*\)\.md/\1/')

  # 제목
  PHASE_TITLE=$(awk 'NR==1 {sub(/^# Phase [0-9]+: /, ""); print}' "$phase_file")
  PHASE_TITLE=$(html_escape "$PHASE_TITLE")

  # 날짜
  PHASE_DATE=$(awk -F': ' '/^\- \*\*Date\*\*/ {print $2}' "$phase_file")

  # 섹션 추출
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

  # HTML 리스트로 변환
  ACTIONS_HTML=$(md_to_html_list "$ACTIONS")
  RESULTS_HTML=$(md_to_html_list "$RESULTS")
  DECISIONS_HTML=$(md_to_html_list "$DECISIONS")
  NEXT_HTML=$(md_to_html_list "$NEXT")

  # 페이즈 섹션 HTML 조립 → temp file
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

  # 사용자 프롬프트 — 좌측 채팅 버블
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

  # Claude 응답 — 우측 채팅 버블 (접기/펼치기)
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

  # 다음 단계 — 별도 카드
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

# === 4. 요약 리포트 생성 ===
report_type="${1:-all}"

# sed용 변수 사전 이스케이핑
S_PROJECT_NAME=$(sed_escape "$PROJECT_NAME")
S_PROJECT_DESC=$(sed_escape "$PROJECT_DESC")

generate_summary() {
  local template="${PLUGIN_ROOT}/templates/report-summary.html"
  local output="${LOGS_DIR}/report-summary.html"

  if [ ! -f "$template" ]; then
    echo "ERROR: Template not found: ${template}" >&2
    return 1
  fi

  # 1단계: 단순 플레이스홀더 sed 치환
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

  # 2단계: 반복 구간 마커를 임시 파일로 치환
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

  # 1단계: 단순 플레이스홀더 sed 치환
  sed "s|{{PROJECT_NAME}}|${S_PROJECT_NAME}|g; \
       s|{{COLOR_1}}|${COLOR_1}|g; \
       s|{{COLOR_2}}|${COLOR_2}|g; \
       s|{{COLOR_3}}|${COLOR_3}|g; \
       s|{{COLOR_4}}|${COLOR_4}|g; \
       s|{{COLOR_5}}|${COLOR_5}|g; \
       s|{{GENERATED_AT}}|${GENERATED_AT}|g" "$template" > "$output"

  # 2단계: 반복 구간 마커를 임시 파일로 치환
  replace_marker "$output" "{{PHASE_SECTIONS}}" "$PHASE_SECTIONS_FILE"
  replace_marker "$output" "{{PHASE_NAV}}" "$PHASE_NAV_FILE"

  echo "Generated: ${output}"
}

# === 5. 인자에 따라 실행 ===
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
