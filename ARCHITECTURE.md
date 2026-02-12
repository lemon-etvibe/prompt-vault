# prompt-vault 아키텍처 가이드

이 문서는 prompt-vault 플러그인의 기술적 내부 구조, 설계 결정 사항, 확장 방법을 다룹니다. 개발자와 기여자를 위한 심층 가이드입니다.

## 목차

- [개요](#개요)
- [플러그인 구조](#플러그인-구조)
- [핵심 구성 요소](#핵심-구성-요소)
- [훅 구현 상세](#훅-구현-상세)
- [스킬 구현 상세](#스킬-구현-상세)
- [데이터 흐름](#데이터-흐름)
- [환경 변수](#환경-변수)
- [설정 스키마](#설정-스키마)
- [템플릿 시스템](#템플릿-시스템)
- [커스터마이징 가이드](#커스터마이징-가이드)
- [확장 포인트](#확장-포인트)
- [테스팅 및 디버깅](#테스팅-및-디버깅)
- [성능 고려사항](#성능-고려사항)
- [보안 및 개인정보](#보안-및-개인정보)
- [기여 가이드](#기여-가이드)
- [버전 히스토리](#버전-히스토리)

## 개요

### 아키텍처 한눈에 보기

```
prompt-vault/
├── .claude-plugin/
│   └── plugin.json          # 플러그인 매니페스트
├── hooks/
│   └── hooks.json           # 훅 등록 (Stop, PreCompact, SessionStart)
├── scripts/
│   ├── context-check.sh     # Stop 훅: 컨텍스트 사용량 체크
│   ├── pre-compact.sh       # PreCompact 훅: 압축 시점 기록
│   └── post-compact.sh      # SessionStart 훅: 복구 데이터 주입
├── skills/
│   ├── init/SKILL.md        # /prompt-vault:init 스킬
│   ├── log/SKILL.md         # /prompt-vault:log 스킬
│   └── status/SKILL.md      # /prompt-vault:status 스킬
└── templates/
    ├── phase.md             # 페이즈 로그 템플릿
    ├── index.md             # _index.md 초기 템플릿
    └── claude-md-snippet.md # CLAUDE.md 삽입 프로토콜
```

### 설계 철학

**금고(Vault) 메타포**:
- 프롬프트와 작업 이력을 안전하게 보관
- 컨텍스트가 압축되어도 진행 상태를 지킴
- 자동화된 보호 메커니즘 (사용자 개입 최소화)

**주요 설계 원칙**:

1. **멱등성(Idempotency)**: `/prompt-vault:init`는 여러 번 실행해도 안전
2. **분리(Separation)**: 로그는 `.local/logs/`에 저장하여 git에서 제외
3. **자동화(Automation)**: 훅 기반 자동 경고 및 복구
4. **재사용성(Reusability)**: 모든 프로젝트에서 동일한 플러그인 사용

## 플러그인 구조

### 디렉토리 역할

| 디렉토리/파일 | 역할 | 접근 방식 |
|--------------|------|----------|
| `.claude-plugin/plugin.json` | 플러그인 메타데이터 (이름, 버전, 설명) | Claude Code가 로드 시 읽음 |
| `hooks/hooks.json` | 훅 등록 파일 (Stop, PreCompact, SessionStart) | Claude Code가 훅 이벤트 발생 시 참조 |
| `scripts/*.sh` | 훅 구현 스크립트 (Bash) | `hooks.json`에서 `command`로 참조 |
| `skills/*/SKILL.md` | 스킬 정의 및 프롬프트 | 사용자가 `/prompt-vault:*` 실행 시 Claude에게 주입 |
| `templates/*.md` | 마크다운 템플릿 파일 | `init`, `log` 스킬에서 파일 생성 시 사용 |

### 파일 크기 및 복잡도

| 파일 | 줄 수 | 복잡도 | 설명 |
|------|-------|--------|------|
| `plugin.json` | 9 | 낮음 | JSON 메타데이터만 |
| `hooks.json` | 38 | 낮음 | 선언적 훅 등록 |
| `context-check.sh` | 26 | 중간 | `jq`, `wc`, 조건문 포함 |
| `pre-compact.sh` | 13 | 낮음 | 단순 파일 append |
| `post-compact.sh` | 20 | 낮음 | `cat`, `ls`, 파이프 |
| `init/SKILL.md` | 44 | 중간 | 6단계 초기화 절차 |
| `log/SKILL.md` | 47 | 높음 | 번호 매김, 파일 생성, 인덱스 업데이트 |
| `status/SKILL.md` | 9 | 낮음 | 단순 읽기 작업 |

## 핵심 구성 요소

### 1. 플러그인 매니페스트 (plugin.json)

**스키마**:
```json
{
  "name": "prompt-vault",
  "version": "1.0.0",
  "description": "...",
  "author": { "name": "etvibe" },
  "keywords": ["logging", "phase", "context", "history", "session"],
  "license": "MIT"
}
```

**필드 설명**:
- `name`: 플러그인 고유 ID (디렉토리명과 일치 권장)
- `version`: 시맨틱 버저닝 (MAJOR.MINOR.PATCH)
- `description`: Claude Code UI에 표시되는 설명
- `keywords`: 검색 및 분류용 태그

**버전 관리**:
- `1.0.0`: 초기 릴리스 (현재)
- `1.x.y`: 하위 호환성 유지 업데이트
- `2.0.0`: 주요 API 변경 시

### 2. 훅 시스템 (hooks.json)

**훅 라이프사이클**:

| 훅 타입 | 트리거 시점 | 실행 컨텍스트 | 주요 용도 |
|---------|------------|--------------|----------|
| `Stop` | Claude 응답 완료 후 | 매 응답마다 | 모니터링, 경고 |
| `PreCompact` | 컨텍스트 압축 직전 | 압축 시작 전 | 상태 저장, 로깅 |
| `SessionStart` | 세션 시작 시 | 새 세션 초기화 | 복구, 주입 |

**훅 타입**:
- **`command`**: Bash 스크립트 실행
- **`matcher`**: SessionStart 훅의 조건 (예: `"compact"` = 압축 후에만)

**환경 변수 전달**:
- `${CLAUDE_PLUGIN_ROOT}`: 플러그인 디렉토리 절대 경로
- `$TRANSCRIPT_PATH`: 세션 transcript 파일 경로 (Stop 훅)
- `$PWD`: 사용자의 프로젝트 디렉토리

### 3. 스킬 시스템 (SKILL.md)

**SKILL.md 형식**:
```markdown
---
name: skill-name
description: 스킬 설명 (한 줄)
disable-model-invocation: true/false
argument-hint: [인자 힌트]
---

스킬 프롬프트 본문 (Claude에게 주입됨)
```

**YAML 프론트매터 필드**:
- `name`: 스킬 이름 (디렉토리명과 일치해야 함)
- `description`: 스킬 목적 및 동작 설명
- `disable-model-invocation`:
  - `true`: 프롬프트만 주입, Claude가 모델 호출하지 않음 (읽기 전용 작업)
  - `false`: Claude가 모델 호출하여 콘텐츠 생성 가능 (쓰기 작업)
- `argument-hint`: 사용자에게 표시할 인자 힌트 (예: `[phase-title]`)

**모델 호출 플래그**:
- `init`: `disable-model-invocation: true` (파일 조작만)
- `log`: `disable-model-invocation: false` (로그 콘텐츠 생성 필요)
- `status`: `disable-model-invocation: false` (출력 포맷팅 필요)

## 훅 구현 상세

### Stop 훅: context-check.sh

**목적**: 매 응답 후 컨텍스트 사용량 체크 및 경고

**데이터 흐름**:
```
Claude 응답 → Stop 훅 트리거 → JSON stdin → context-check.sh
                                              ↓
                                       transcript_path 추출
                                              ↓
                                       파일 크기 측정
                                              ↓
                                       .config에서 threshold 읽기
                                              ↓
                                       크기 > threshold?
                                       ↙ Yes     ↘ No
                               경고 출력       종료 (0)
```

**코드 분석**:

```bash
#!/bin/bash
# 1. stdin에서 JSON 읽기
INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# 2. transcript 파일 존재 확인
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# 3. .config에서 임계값 읽기
CONFIG=".local/logs/.config"
if [ -f "$CONFIG" ]; then
  THRESHOLD=$(jq -r '.warn_bytes // 640000' "$CONFIG")
else
  THRESHOLD=640000  # 기본값: 200K 모델의 80%
fi

# 4. transcript 크기 측정
SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d ' ')

# 5. 임계값 초과 시 경고
if [ "$SIZE" -gt "$THRESHOLD" ]; then
  PCT=$((SIZE * 100 / (THRESHOLD * 100 / 80)))
  echo "⚠️ [prompt-vault] Context ~${PCT}% used (${SIZE} bytes)."
  echo "💡 Run /prompt-vault:log to save progress, then /compact to free context."
fi
```

**성능**:
- `jq` 파싱: ~10ms
- `wc` 실행: ~20ms
- 조건 평가: ~5ms
- **총 오버헤드**: ~35-50ms (사용자 체감 불가)

**입력 예시**:
```json
{
  "transcript_path": "/Users/user/.claude/sessions/abc123.jsonl"
}
```

**출력 예시**:
```
⚠️ [prompt-vault] Context ~85% used (680000 bytes).
💡 Run /prompt-vault:log to save progress, then /compact to free context.
```

### PreCompact 훅: pre-compact.sh

**목적**: 압축 시점 감사 추적(audit trail)

**코드 분석**:

```bash
#!/bin/bash
LOG_DIR=".local/logs"
if [ -d "$LOG_DIR" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  PHASE_COUNT=$(ls -1 "$LOG_DIR"/phase-*.md 2>/dev/null | wc -l | tr -d ' ')
  {
    echo "⚠️ Auto-compaction at $TIMESTAMP"
    echo "Phase count: $PHASE_COUNT"
    echo "---"
  } >> "$LOG_DIR/compaction.log"
fi
```

**동작**:
1. `.local/logs/` 디렉토리 존재 확인
2. 현재 타임스탬프 생성
3. `phase-*.md` 파일 개수 카운트
4. `compaction.log`에 append

**stdout 없음**: 이 훅은 사용자에게 출력하지 않음 (백그라운드 로깅)

**compaction.log 예시**:
```
⚠️ Auto-compaction at 2026-02-12 14:32:10
Phase count: 5
---
⚠️ Auto-compaction at 2026-02-12 16:45:23
Phase count: 8
---
```

### SessionStart 훅: post-compact.sh

**목적**: 압축 후 세션 재시작 시 진행 상태 복구

**핵심**: 이 훅의 **stdout이 Claude의 새 세션 컨텍스트로 주입됨**

**코드 분석**:

```bash
#!/bin/bash
LOG_DIR=".local/logs"
if [ -d "$LOG_DIR" ]; then
  echo "=== Phase Progress (post-compaction recovery) ==="

  # _index.md 출력
  if [ -f "$LOG_DIR/_index.md" ]; then
    cat "$LOG_DIR/_index.md"
  fi

  echo ""
  echo "=== Latest Phase Log ==="

  # 가장 최근 phase-*.md 출력
  LATEST=$(ls -t "$LOG_DIR"/phase-*.md 2>/dev/null | head -1)
  if [ -n "$LATEST" ]; then
    cat "$LATEST"
  else
    echo "(No phases logged yet)"
  fi

  echo "=== End Recovery ==="
fi
```

**데이터 흐름**:
```
압축 완료 → 새 세션 시작 → SessionStart 훅 (matcher: "compact")
                                       ↓
                               post-compact.sh 실행
                                       ↓
                       stdout: _index.md + latest phase
                                       ↓
                       Claude의 새 세션 컨텍스트로 주입
```

**복구 데이터 크기**:
- `_index.md`: ~500 bytes (페이즈 테이블)
- `phase-*.md`: ~1-3 KB (최신 로그)
- **총 주입**: ~2-5 KB (컨텍스트에 부담 없음)

**matcher 조건**:
- `"matcher": "compact"`: 압축 후에만 실행
- 일반 세션 시작 시에는 실행되지 않음

## 스킬 구현 상세

### /prompt-vault:init

**목적**: 프로젝트에 로깅 환경 초기화

**6단계 절차**:

1. **`.local/logs/` 디렉토리 생성**
   ```bash
   mkdir -p .local/logs/
   ```

2. **`.gitignore`에 `.local/` 추가**
   - 기존 `.gitignore` 읽기
   - `.local/` 행이 없으면 추가
   - 멱등: 이미 있으면 스킵

3. **`.local/logs/_index.md` 초기화**
   - `${CLAUDE_PLUGIN_ROOT}/templates/index.md` 복사
   - 내용:
     ```markdown
     # Phase Log Index

     | # | Title | Status | Date | Summary |
     |---|-------|--------|------|---------|
     ```

4. **`CLAUDE.md`에 Phase Logging Protocol 추가**
   - `${CLAUDE_PLUGIN_ROOT}/templates/claude-md-snippet.md` 내용 삽입
   - 기존 `CLAUDE.md`가 없으면 생성
   - 이미 프로토콜 섹션이 있으면 스킵

5. **`.local/logs/.config` 생성**
   - 사용자에게 모델 확인 (환경 변수 또는 기본값)
   - 임계값 계산:
     ```
     warn_bytes = context_window_tokens × 4 × (warn_percent / 100)
     ```
   - JSON 형식으로 저장:
     ```json
     {
       "model": "claude-opus-4-6",
       "context_window_tokens": 200000,
       "warn_percent": 80,
       "warn_bytes": 640000
     }
     ```

6. **완료 메시지 출력**

**멱등성 보장**:
- 각 단계에서 파일/디렉토리 존재 확인
- 이미 있으면 스킵, 없으면 생성
- 여러 번 실행해도 안전

**환경 변수 활용**:
```markdown
→ ${CLAUDE_PLUGIN_ROOT}/templates/claude-md-snippet.md 내용 참조
```
Claude가 프롬프트 처리 시 `${CLAUDE_PLUGIN_ROOT}`를 플러그인 경로로 치환

### /prompt-vault:log [제목]

**목적**: 완료된 작업을 페이즈 로그로 기록

**5단계 절차**:

1. **`.local/logs/` 확인**
   - 없으면 생성 (또는 `/init` 안내)

2. **페이즈 번호 결정**
   ```bash
   # 기존 phase-*.md 파일 glob
   EXISTING=$(ls -1 .local/logs/phase-*.md 2>/dev/null)

   # 최대 번호 추출 + 1
   MAX_NUM=$(echo "$EXISTING" | sed 's/.*phase-\([0-9]*\)\.md/\1/' | sort -n | tail -1)
   NEXT_NUM=$((MAX_NUM + 1))

   # 3자리 zero-padding
   PHASE_NUM=$(printf "%03d" $NEXT_NUM)
   ```

3. **`phase-NNN.md` 생성**
   - `${CLAUDE_PLUGIN_ROOT}/templates/phase.md` 기반
   - 다음 내용 채우기:
     - 제목: `$ARGUMENTS` 또는 Claude가 추론
     - Date: `YYYY-MM-DD`
     - Session: 세션 ID
     - User Prompt: 대화 이력에서 추출
     - Actions: Claude가 수행한 작업 나열
     - Results: 산출물 요약
     - Decisions: 결정 사항
     - Next: 다음 단계
   - **모델 호출 활성화** (`disable-model-invocation: false`) → Claude가 콘텐츠 생성

4. **`_index.md` 업데이트**
   - 기존 테이블 읽기
   - 새 행 추가:
     ```markdown
     | NNN | 제목 | done | YYYY-MM-DD | 한줄 요약 |
     ```
   - 파일 다시 쓰기

5. **완료 메시지 출력**
   ```
   ✓ Logged phase 003: "제목"
   ✓ Updated _index.md
   ```

**페이즈 번호 매김 특성**:
- 기존 파일 개수 기반이 아닌 **최대 번호 + 1**
- 파일 삭제 시 번호 건너뛸 수 있음 (예: 001, 003, 004)
- 의도적 설계: 페이즈 삭제/재정렬 가능

**모델 생성 콘텐츠**:
- User Prompt: 대화 이력 참조
- Actions: 파일 생성/수정 이력 추출
- Results: 산출물 요약 생성
- Decisions: 맥락에서 결정 사항 추론

### /prompt-vault:status

**목적**: 페이즈 진행 상황 요약 표시

**간단한 구현**:

```markdown
`.local/logs/_index.md`를 읽어 현재까지의 페이즈 진행 상태를 요약 표시한다.
파일이 없으면 `/prompt-vault:init`을 안내한다.
```

**오류 처리**:
- `_index.md` 없음 → "Run `/prompt-vault:init` first"
- `.local/logs/` 없음 → 동일 안내

**출력 형식**:
```markdown
# Phase Log Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | ... | done | 2026-02-12 | ... |
| 002 | ... | done | 2026-02-12 | ... |

Total: 2 phases completed
```

## 데이터 흐름

### 정상 워크플로우 (경고만)

```
사용자 프롬프트
    ↓
Claude 응답 생성
    ↓
Stop 훅 트리거
    ↓
context-check.sh 실행
    ↓
transcript 크기 < 임계값?
    ↓ No
경고 출력
    ↓
사용자에게 표시
```

### 압축 워크플로우 (전체 사이클)

```
사용자: /prompt-vault:log "제목"
    ↓
Claude: phase-NNN.md 생성, _index.md 업데이트
    ↓
사용자: /compact
    ↓
PreCompact 훅 트리거
    ↓
pre-compact.sh: compaction.log 기록
    ↓
Claude: 컨텍스트 압축 (대화 요약)
    ↓
새 세션 시작 (matcher: "compact")
    ↓
SessionStart 훅 트리거
    ↓
post-compact.sh: _index.md + latest phase 출력
    ↓
stdout → Claude의 새 세션 컨텍스트
    ↓
Claude: 복구된 상태로 준비 완료
    ↓
사용자: 작업 재개
```

## 환경 변수

### Claude Code 제공 변수

| 변수 | 제공 시점 | 값 예시 | 용도 |
|------|----------|---------|------|
| `${CLAUDE_PLUGIN_ROOT}` | 스킬 프롬프트 처리 시 | `/Users/user/prompt-vault` | 템플릿 경로 참조 |
| `$TRANSCRIPT_PATH` | Stop 훅 실행 시 | `/Users/user/.claude/sessions/abc.jsonl` | transcript 크기 측정 |
| `$PWD` | 모든 훅/스킬 | `/Users/user/my-project` | 프로젝트 디렉토리 |

### 플러그인 내부 변수

| 변수 | 스크립트 | 용도 |
|------|---------|------|
| `LOG_DIR` | 모든 `.sh` | `.local/logs` 경로 상수 |
| `CONFIG` | `context-check.sh` | `.local/logs/.config` 경로 |
| `THRESHOLD` | `context-check.sh` | 임계값 바이트 수 |
| `PHASE_NUM` | (스킬 로직) | 다음 페이즈 번호 (001, 002, ...) |

## 설정 스키마

### .config JSON 스키마

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["model", "context_window_tokens", "warn_percent", "warn_bytes"],
  "properties": {
    "model": {
      "type": "string",
      "description": "Claude 모델 ID",
      "examples": ["claude-opus-4-6", "claude-sonnet-4-5-20250929"]
    },
    "context_window_tokens": {
      "type": "integer",
      "description": "컨텍스트 윈도우 크기 (토큰 수)",
      "minimum": 1,
      "examples": [200000, 1000000]
    },
    "warn_percent": {
      "type": "integer",
      "description": "경고 발생 임계값 (퍼센트)",
      "minimum": 1,
      "maximum": 100,
      "examples": [80, 70]
    },
    "warn_bytes": {
      "type": "integer",
      "description": "경고 발생 임계값 (바이트 수)",
      "minimum": 1,
      "examples": [640000, 3200000]
    }
  }
}
```

### 임계값 계산

**공식**:
```
warn_bytes = context_window_tokens × bytes_per_token × (warn_percent / 100)
```

**bytes_per_token 추정**:
- 일반적으로 1 토큰 ≈ 4 바이트 (영어 기준)
- 한글: 1 토큰 ≈ 2-3 바이트 (더 많은 문자 인코딩)
- **보수적 추정**: 4 바이트 사용 (안전 마진)

**예시**:
```
200K 모델, 80% 임계값:
200,000 × 4 × 0.8 = 640,000 bytes

1M 모델, 80% 임계값:
1,000,000 × 4 × 0.8 = 3,200,000 bytes
```

## 템플릿 시스템

### phase.md 구조

```markdown
# Phase NNN: TITLE

- **Date**: YYYY-MM-DD
- **Session**: SESSION_ID

## User Prompt
> 사용자의 원본 요청을 가능한 원문 그대로 기록

## Actions
- Claude가 수행한 주요 작업을 시간순으로 나열
- 사용한 도구, 조회한 파일, 생성/수정한 파일 포함

## Results
- 산출물 요약 (생성된 파일 경로, 핵심 발견사항)
- 주요 데이터나 수치

## Decisions
- 내려진 결정 사항과 그 이유

## Next
- 다음 단계 또는 미결 사항
```

**섹션 목적**:
- **User Prompt**: 요구사항 추적
- **Actions**: 실행 이력 (재현 가능성)
- **Results**: 산출물 검증
- **Decisions**: 아키텍처 결정 기록 (ADR)
- **Next**: 작업 연속성

### index.md 구조

```markdown
# Phase Log Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
```

**컬럼 의미**:
- `#`: 페이즈 번호 (001, 002, ...)
- `Title`: 페이즈 제목
- `Status`: 상태 (일반적으로 `done`, 확장 가능: `in-progress`, `blocked`)
- `Date`: 완료 일자 (YYYY-MM-DD)
- `Summary`: 한 줄 요약 (30-50자)

### claude-md-snippet.md

**프로토콜 내용**:
```markdown
# Phase Logging Protocol (prompt-vault)

## 규칙
- 의미 있는 작업 단위(페이즈)가 완료되면 `/prompt-vault:log [제목]`으로 기록
- 사용자가 명시적으로 호출하거나, Claude가 페이즈 완료를 인지하면 자동 제안
- 컨텍스트 압축 전에는 반드시 현재 작업을 로깅할 것

## 컨텍스트 관리
- 대화가 길어지면 `/compact` 전에 `/prompt-vault:log`로 저장
- 압축 후에는 `.local/logs/_index.md` 참조하여 진행 상태 파악
- 서브에이전트(Task)를 활용하여 메인 컨텍스트 부하 경감
- `/prompt-vault:status`로 현재 진행 상태 확인 가능
```

**용도**: 대상 프로젝트의 `CLAUDE.md`에 삽입하여 Claude가 로깅 프로토콜을 따르도록 유도

## 커스터마이징 가이드

### 1. 임계값 변경

**목적**: 경고를 더 일찍 또는 더 늦게 받기

**방법**:
```bash
vim .local/logs/.config
```

**70%로 낮추기** (더 일찍 경고):
```json
{
  "model": "claude-opus-4-6",
  "context_window_tokens": 200000,
  "warn_percent": 70,
  "warn_bytes": 560000
}
```

**90%로 높이기** (더 늦게 경고):
```json
{
  "warn_percent": 90,
  "warn_bytes": 720000
}
```

### 2. 맞춤 페이즈 형식

**목적**: 조직의 문서화 표준에 맞추기

**방법**:
```bash
vim ~/Downloads/prompt-vault/templates/phase.md
```

**예시: 이슈 트래커 링크 추가**:
```markdown
# Phase NNN: TITLE

- **Date**: YYYY-MM-DD
- **Session**: SESSION_ID
- **Issue**: [#123](https://github.com/user/repo/issues/123)

...
```

### 3. 새 훅 추가

**목적**: 압축 후 Slack 알림 등 커스텀 동작

**방법**:
```bash
# 1. 스크립트 작성
vim ~/Downloads/prompt-vault/scripts/notify-slack.sh

#!/bin/bash
# Slack webhook으로 압축 알림 전송
WEBHOOK_URL="https://hooks.slack.com/services/..."
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Context compacted!"}' \
  $WEBHOOK_URL
```

```bash
# 2. 실행 권한 부여
chmod +x ~/Downloads/prompt-vault/scripts/notify-slack.sh

# 3. hooks.json 편집
vim ~/Downloads/prompt-vault/hooks/hooks.json
```

```json
{
  "hooks": {
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/pre-compact.sh",
            "statusMessage": "Saving phase log..."
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-slack.sh",
            "statusMessage": "Notifying Slack..."
          }
        ]
      }
    ]
  }
}
```

### 4. 다국어 지원

**목적**: 페이즈 로그를 영어로 작성

**방법**:
```bash
vim ~/Downloads/prompt-vault/templates/phase.md
```

**영어 템플릿**:
```markdown
# Phase NNN: TITLE

- **Date**: YYYY-MM-DD
- **Session**: SESSION_ID

## User Prompt
> Original user request

## Actions
- Actions performed by Claude

## Results
- Output summary

## Decisions
- Decisions made and rationale

## Next
- Next steps or pending items
```

## 확장 포인트

### 1. 페이즈 내보내기 (HTML/PDF)

**아이디어**: 로그를 웹 페이지 또는 PDF로 변환

**구현 예시**:
```bash
# Pandoc 사용
pandoc .local/logs/phase-*.md -o project-report.pdf

# 또는 새 스킬 추가
/prompt-vault:export [format]
# 내부적으로 pandoc 호출
```

### 2. 페이즈 검색 기능

**아이디어**: 키워드로 과거 페이즈 검색

**구현 예시**:
```bash
# 새 스킬: /prompt-vault:search [keyword]
# 내부적으로 grep -r "[keyword]" .local/logs/
# 결과를 포맷팅하여 출력
```

### 3. Git 통합

**아이디어**: 각 페이즈를 자동으로 git 커밋

**구현 예시**:
```bash
# /prompt-vault:log 후 자동 커밋
git add .local/logs/
git commit -m "phase-NNN: [제목]"
```

**주의**: 민감 정보 포함 가능, 선택적 기능으로 제공

### 4. 팀 협업 기능

**아이디어**: 팀원별 페이즈 태깅

**구현 예시**:
```markdown
# Phase NNN: TITLE

- **Date**: YYYY-MM-DD
- **Author**: @username
...
```

## 테스팅 및 디버깅

### 수동 테스팅 워크플로우

**1. 초기화 테스트**:
```bash
cd ~/test-project
claude --plugin-dir ~/Downloads/prompt-vault
/prompt-vault:init
ls -la .local/logs/
cat .local/logs/.config
cat .local/logs/_index.md
```

**2. 로깅 테스트**:
```bash
/prompt-vault:log "테스트 페이즈"
ls .local/logs/phase-*.md
cat .local/logs/phase-001.md
cat .local/logs/_index.md
```

**3. 상태 테스트**:
```bash
/prompt-vault:status
```

**4. 훅 테스트**:
```bash
# Stop 훅 수동 실행
echo '{"transcript_path":"/path/to/transcript.jsonl"}' | \
  ~/Downloads/prompt-vault/scripts/context-check.sh

# PreCompact 훅
~/Downloads/prompt-vault/scripts/pre-compact.sh
cat .local/logs/compaction.log

# SessionStart 훅
~/Downloads/prompt-vault/scripts/post-compact.sh
```

### 훅 디버깅

**echo 문 추가**:
```bash
vim ~/Downloads/prompt-vault/scripts/context-check.sh

# 디버그 출력 추가
echo "DEBUG: TRANSCRIPT=$TRANSCRIPT" >&2
echo "DEBUG: SIZE=$SIZE, THRESHOLD=$THRESHOLD" >&2
```

**stderr로 로깅**:
- stdout은 Claude에게 표시
- stderr는 디버그용 (`>&2`)

**독립 실행 테스트**:
```bash
# 가짜 transcript 생성
dd if=/dev/zero of=/tmp/test-transcript bs=1024 count=700  # 700KB

# 수동 테스트
echo '{"transcript_path":"/tmp/test-transcript"}' | \
  ~/Downloads/prompt-vault/scripts/context-check.sh
```

### 일반적인 문제

| 문제 | 원인 | 해결 |
|------|------|------|
| `jq: command not found` | jq 미설치 | `brew install jq` |
| `Permission denied: .local/logs/` | 쓰기 권한 없음 | `chmod +w .local/logs/` |
| 경고 없음 | `.config` 없음 또는 임계값 너무 높음 | `/init` 재실행 또는 임계값 조정 |
| 복구 없음 | 압축 전 로깅 안 함 | 압축 전 반드시 `/log` 실행 |
| 페이즈 번호 중복 | 경쟁 조건 (동시 로깅) | 순차 실행 권장 |

## 성능 고려사항

### Stop 훅 오버헤드

**측정**:
```bash
time echo '{"transcript_path":"/path/to/transcript"}' | \
  scripts/context-check.sh
```

**결과**:
- `jq` 파싱: ~10ms
- `wc` 실행: ~20ms
- 조건 평가: ~5ms
- **총**: 35-50ms

**영향**: 사용자 체감 불가 (Claude 응답 생성 시간이 수 초)

### 로그 작업 시간

**측정**:
- 파일 생성: ~100ms
- 모델 호출 (콘텐츠 생성): 2-5초
- 인덱스 업데이트: ~50ms
- **총**: 2-5초

**병목**: 모델 호출 (불가피, 품질 우선)

### 복구 데이터 크기

**주입 데이터**:
- `_index.md`: ~500 bytes (10개 페이즈 기준)
- `phase-*.md`: ~1-3 KB
- **총**: ~2-5 KB

**영향**: 컨텍스트 윈도우의 ~0.01% (무시 가능)

## 보안 및 개인정보

### 로컬 저장소

- 모든 로그는 사용자 기기에만 저장
- 네트워크 전송 없음
- 외부 서비스 의존성 없음

### Git 안전

- `.local/` 디렉토리는 `.gitignore`에 자동 추가
- 실수로 커밋되는 것 방지
- 민감한 API 키, 내부 로직 보호

### 사용자 책임

**경고**: 로그에는 다음이 포함될 수 있음:
- 사용자 프롬프트 (요구사항)
- 생성된 코드 (내부 로직)
- 결정 사항 (아키텍처 비밀)
- 파일 경로 (프로젝트 구조)

**권장사항**:
- 민감한 정보는 로그에 포함하지 않기
- Git에 커밋 전 검토
- 팀 공유 시 민감 정보 제거

## 기여 가이드

### 개발 설정

```bash
# 1. 저장소 클론
git clone https://github.com/lemon-etvibe/prompt-vault.git
cd prompt-vault

# 2. 로컬 테스트
claude --plugin-dir $(pwd)

# 3. 코드 스타일 검사
shellcheck scripts/*.sh
```

### PR 가이드라인

**브랜치 명명**:
- `feature/add-export-skill`: 새 기능
- `fix/hook-permission-error`: 버그 수정
- `docs/architecture-update`: 문서 개선

**커밋 메시지**:
```
<type>: <subject>

<body>

<footer>
```

**타입**:
- `feat`: 새 기능
- `fix`: 버그 수정
- `docs`: 문서만 변경
- `refactor`: 코드 구조 개선
- `test`: 테스트 추가

**예시**:
```
feat: add /prompt-vault:search skill

Implement keyword-based phase search using grep.
Supports regex patterns and outputs formatted results.

Closes #42
```

### 코드 스타일

**Bash**:
- `shellcheck` 통과 필수
- 변수는 대문자 (`PHASE_NUM`)
- 에러 처리: `set -e` 또는 명시적 체크

**마크다운**:
- CommonMark 준수
- 코드 블록에 언어 힌트 (```bash, ```json)
- 테이블 정렬

## 버전 히스토리

### v1.0.0 (2026-02-12)

**초기 릴리스**:
- ✅ 3개 스킬: `init`, `log`, `status`
- ✅ 3개 훅: Stop, PreCompact, SessionStart
- ✅ 템플릿 시스템
- ✅ 컨텍스트 임계값 자동 경고
- ✅ 압축 후 자동 복구
- ✅ Git 안전 저장

**알려진 제한**:
- 페이즈 검색 기능 없음 (수동 `grep` 필요)
- PDF 내보내기 미지원
- Git 자동 커밋 미지원

**향후 계획**:
- v1.1.0: `/prompt-vault:search` 스킬
- v1.2.0: `/prompt-vault:export` 스킬
- v2.0.0: 다중 사용자 협업 기능

## 참조

- **Claude Code 플러그인 문서**: https://docs.anthropic.com/claude-code/plugins
- **훅 시스템 사양**: https://docs.anthropic.com/claude-code/hooks
- **스킬 사양**: https://docs.anthropic.com/claude-code/skills
- **GitHub 저장소**: https://github.com/lemon-etvibe/prompt-vault

---

**질문이나 제안이 있으신가요?**
GitHub Issues에서 논의해주세요. 기여를 환영합니다!
