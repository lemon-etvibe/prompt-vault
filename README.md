# prompt-vault

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/lemon-etvibe/prompt-vault)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> 컨텍스트 자동 보호 기능을 갖춘 Claude Code용 페이즈 기반 대화 로깅 플러그인

## prompt-vault란?

Claude Code로 장시간 프로젝트를 진행하다 보면 컨텍스트가 압축(compaction)되면서 **중요한 작업 이력과 진행 상태가 손실**됩니다. prompt-vault는 이 문제를 해결하기 위해 태어났습니다.

### 해결하는 문제

- **컨텍스트 압축 시 작업 이력 손실**: 압축 후에는 이전 페이즈의 결정 사항과 진행 상황을 기억하지 못함
- **프로젝트 진행 상태 추적 부재**: 어디까지 완료했고, 무엇을 결정했는지 한눈에 파악하기 어려움
- **수동 로깅의 번거로움**: 별도 문서에 작업 내용을 일일이 기록해야 하는 부담

### 해결 방법

prompt-vault는 **훅(Hook) 기반 자동 복구**와 **페이즈 단위 구조화 로깅**으로 이 문제를 해결합니다:

1. **자동 컨텍스트 모니터링**: 매 응답마다 컨텍스트 사용량을 체크하고 80% 도달 시 경고
2. **페이즈 기반 로깅**: 의미 있는 작업 단위를 `/prompt-vault:log` 명령으로 체계적으로 기록
3. **자동 복구**: 컨텍스트 압축 후 세션 재시작 시 페이즈 인덱스와 최신 로그를 자동 주입

### 핵심 이점

- ✅ **구조화된 로깅**: 사용자 프롬프트, 수행 작업, 결과, 결정 사항을 체계적으로 기록
- ✅ **자동 컨텍스트 보호**: Stop/PreCompact/SessionStart 훅으로 압축 전후 진행 상태 자동 보존
- ✅ **Git 안전 저장**: 모든 로그는 `.local/logs/`에 저장되어 git에서 자동 제외
- ✅ **멀티 프로젝트 지원**: 각 프로젝트마다 독립적인 로그 관리, 재사용 가능한 플러그인 형태

## 주요 기능

### 📝 페이즈 기반 로깅
- 완료된 작업을 `phase-001.md`, `phase-002.md` 형식으로 자동 번호 매김
- 사용자 프롬프트, 수행 작업, 결과, 결정 사항, 다음 단계를 포함한 구조화된 형식
- `_index.md`로 모든 페이즈를 테이블 형태로 한눈에 조회

### ⚠️ 컨텍스트 사용량 자동 경고
- 매 응답 후 transcript 크기 모니터링
- 80% 임계값 초과 시 자동 경고 메시지
- 모델별 컨텍스트 윈도우에 맞춘 정확한 임계값 설정

### 🔄 압축 후 자동 복구
- **PreCompact 훅**: 압축 시점을 `compaction.log`에 자동 기록
- **SessionStart 훅**: 압축 후 세션 재시작 시 `_index.md` + 최신 페이즈 로그를 Claude에게 자동 주입
- 진행 상태를 잃지 않고 작업 연속성 보장

### 📊 HTML 리포트 시각화
- `/prompt-vault:report`로 페이즈 로그를 시각적 HTML 리포트로 변환
- **요약 대시보드**: 타임라인, 통계 카드, 페이즈 인덱스 테이블
- **상세 로그 뷰**: 채팅 버블 UI로 사용자 프롬프트 ↔ Claude 응답 표시
- Coolors 기반 5색 팔레트로 프로젝트별 고유한 디자인
- 순수 정적 HTML — 브라우저만 있으면 열람 가능

### 🔒 Git 안전 저장
- 모든 로그는 프로젝트의 `.local/logs/` 디렉토리에 저장
- 초기화 시 `.gitignore`에 `.local/` 자동 추가
- 민감한 작업 이력이 실수로 커밋되지 않도록 보호

## 사전 요구사항

- **Claude Code**: 최신 버전 (훅 시스템 지원 필요)
- **jq**: JSON 처리기 (훅 동작에 필수)
  ```bash
  # macOS
  brew install jq

  # Ubuntu/Debian
  sudo apt install jq

  # Windows (WSL)
  sudo apt install jq
  ```
- **플랫폼**: macOS, Linux, Windows WSL

## 설치

```bash
# 1. 플러그인 클론
git clone https://github.com/lemon-etvibe/prompt-vault.git

# 2. 플러그인 디렉토리 지정하여 Claude 실행
claude --plugin-dir /path/to/prompt-vault
```

## 빠른 시작 (5분)

```bash
# 1. 프로젝트에 로깅 환경 초기화
/prompt-vault:init

# 2. 기능 작업 진행
[사용자] "할 일 앱 기본 기능 구현해줘"
[Claude] "네, todo.py를 생성하겠습니다..."

# 3. 작업 완료 후 페이즈 로깅
/prompt-vault:log "할 일 앱 기본 기능 구현"

# 4. 진행 상태 확인
/prompt-vault:status

# 5. 계속 작업하다가 컨텍스트 경고 발생
⚠️ [prompt-vault] Context ~85% used (680000 bytes).
💡 Run /prompt-vault:log to save progress, then /compact to free context.

# 6. 체크포인트 로깅 후 압축
/prompt-vault:log "체크포인트: 삭제 기능 추가 완료"
/compact

# 7. 다음 세션에서 자동 복구됨!
=== Phase Progress (post-compaction recovery) ===
# Phase Log Index
| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | 할 일 앱 기본 기능 구현 | done | 2026-02-12 | CRUD 기본 기능 완성 |
| 002 | 체크포인트: 삭제 기능 추가 완료 | done | 2026-02-12 | 삭제 기능 및 확인 대화상자 구현 |
=== End Recovery ===
```

## 스킬 레퍼런스

### `/prompt-vault:init`

**목적**: 프로젝트에 로깅 환경 초기화

**동작**:
- `.local/logs/` 디렉토리 생성
- `.local/logs/.config` 생성 (모델별 컨텍스트 임계값 설정)
- `.local/logs/_index.md` 초기화 (페이즈 인덱스 테이블)
- `.gitignore`에 `.local/` 추가 (이미 있으면 스킵)
- `CLAUDE.md`에 Phase Logging Protocol 섹션 추가 (이미 있으면 스킵)

**사용 시점**: 프로젝트당 한 번만 실행 (멱등 연산)

**예시**:
```bash
/prompt-vault:init
```

### `/prompt-vault:log [제목]`

**목적**: 완료된 작업을 페이즈 로그로 기록

**형식**: `phase-NNN.md` (NNN은 001부터 자동 증가)

**포함 내용**:
- **User Prompt**: 사용자의 원본 요청
- **Actions**: Claude가 수행한 주요 작업 (도구, 파일 조회/생성/수정)
- **Results**: 산출물 요약 (파일 경로, 핵심 발견사항, 주요 데이터)
- **Decisions**: 내려진 결정 사항과 그 이유
- **Next**: 다음 단계 또는 미결 사항

**사용 시점**:
- 의미 있는 작업 단위(페이즈) 완료 후
- 컨텍스트 경고 발생 시 (압축 전 필수)
- 휴식 전 현재 작업 상태 저장

**예시**:
```bash
/prompt-vault:log "사용자 인증 API 구현"
/prompt-vault:log "데이터베이스 스키마 설계"
```

### `/prompt-vault:report [summary|detail|all|custom]`

**목적**: 페이즈 로그를 시각화된 HTML 리포트로 변환

**동작**:
- `scripts/generate-report.sh` 실행 (토큰 비용 제로)
- `.local/logs/report-summary.html` — 프로젝트 요약 대시보드
- `.local/logs/report-detail.html` — 페이즈별 상세 채팅 로그

**인자**:
- `summary`: 요약 대시보드만
- `detail`: 상세 로그 뷰만
- `all` (기본): 둘 다
- `custom`: Claude가 커스텀 리포트 생성

**예시**:
```bash
/prompt-vault:report           # 기본 리포트 생성
/prompt-vault:report summary   # 요약만
/prompt-vault:report custom    # 커스텀 (추가 요청 반영)
open .local/logs/report-summary.html  # 브라우저에서 열기
```

### `/prompt-vault:status`

**목적**: 페이즈 진행 상황 요약 표시

**동작**: `.local/logs/_index.md`를 읽어 페이즈 테이블 출력

**사용 시점**:
- 프로젝트 이력 파악이 필요할 때
- 압축 후 복구된 내용 확인
- 다음 작업 계획 수립 전

**예시**:
```bash
/prompt-vault:status
```

## 컨텍스트 보호 메커니즘

prompt-vault는 세 가지 훅(Hook)을 통해 컨텍스트 압축 전후로 작업 이력을 보호합니다.

### Stop 훅 (context-check.sh)

**트리거**: Claude의 매 응답 완료 후

**동작**:
1. 현재 세션의 transcript 파일 크기 측정
2. `.local/logs/.config`에서 `warn_bytes` 임계값 읽기
3. transcript 크기가 임계값 초과 시 경고 메시지 출력
4. `/prompt-vault:log` + `/compact` 명령 안내

**성능**: 일반적으로 ~50ms 미만

**예시 출력**:
```
⚠️ [prompt-vault] Context ~85% used (680000 bytes).
💡 Run /prompt-vault:log to save progress, then /compact to free context.
```

### PreCompact 훅 (pre-compact.sh)

**트리거**: 컨텍스트 압축 직전

**동작**:
1. 현재 타임스탬프 기록
2. 현재 페이즈 개수 카운트
3. `.local/logs/compaction.log`에 압축 이력 추가

**목적**: 압축 시점 감사 추적 (audit trail)

**출력 없음** (백그라운드 로깅만)

### SessionStart 훅 (post-compact.sh)

**트리거**: 컨텍스트 압축 후 세션 재시작 시 (matcher: "compact")

**동작**:
1. `.local/logs/_index.md` 읽기
2. 가장 최근 `phase-*.md` 파일 읽기 (수정 시간 기준)
3. 두 내용을 stdout으로 출력 → **Claude의 새 세션 컨텍스트로 주입됨**

**핵심**: 이 훅의 stdout이 압축 후 Claude가 보는 첫 메시지가 됨

**예시 출력**:
```
=== Phase Progress (post-compaction recovery) ===
# Phase Log Index
| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | 기능 A 구현 | done | 2026-02-12 | ... |
| 002 | 기능 B 추가 | done | 2026-02-12 | ... |

=== Latest Phase Log ===
# Phase 002: 기능 B 추가
- **Date**: 2026-02-12
...
=== End Recovery ===
```

## 생성되는 프로젝트 구조

`/prompt-vault:init` 실행 후 프로젝트에 다음 구조가 생성됩니다:

```
your-project/
├── .local/
│   └── logs/
│       ├── .config          # 모델/임계값 설정 (JSON)
│       ├── _index.md        # 페이즈 인덱스 테이블
│       ├── phase-001.md     # 첫 번째 페이즈 로그
│       ├── phase-002.md     # 두 번째 페이즈 로그
│       ├── compaction.log   # 자동 압축 이력 (감사 추적)
│       ├── report-summary.html  # 프로젝트 요약 대시보드 (자동 생성)
│       └── report-detail.html   # 페이즈별 상세 채팅 로그 (자동 생성)
├── .gitignore               # .local/ 추가됨 (이미 있으면 병합)
└── CLAUDE.md                # Phase Logging Protocol 섹션 추가됨
```

## 설정

### `.config` 형식

`.local/logs/.config` 파일은 JSON 형식으로 컨텍스트 임계값을 정의합니다:

```json
{
  "model": "claude-opus-4-6",
  "context_window_tokens": 200000,
  "warn_percent": 80,
  "warn_bytes": 640000,
  "project_name": "My Project",
  "project_description": "프로젝트 설명",
  "palette": ["#264653", "#2A9D8F", "#E9C46A", "#F4A261", "#E76F51"]
}
```

**필드 설명**:
- `model`: 사용 중인 Claude 모델 ID
- `context_window_tokens`: 모델의 컨텍스트 윈도우 크기 (토큰 수)
- `warn_percent`: 경고 발생 임계값 (퍼센트)
- `warn_bytes`: 경고 발생 임계값 (transcript 바이트 수)
- `project_name`: 리포트 제목에 사용 (기본: 디렉토리명)
- `project_description`: 리포트 부제목 (기본: 빈 문자열)
- `palette`: 5색 팔레트 배열 — [primary, secondary, accent, surface, muted]

### 모델별 권장 임계값

| 모델 | 컨텍스트 윈도우 | 80% 임계값 (bytes) |
|------|----------------|-------------------|
| Opus 4.6 (200K) | 200,000 tokens | 640,000 bytes |
| Sonnet 4.5 (200K) | 200,000 tokens | 640,000 bytes |
| Haiku 4.5 (200K) | 200,000 tokens | 640,000 bytes |
| Extended (1M) | 1,000,000 tokens | 3,200,000 bytes |

**계산 공식**: `warn_bytes = (context_window_tokens × 4) × (warn_percent / 100)`
(1 토큰 ≈ 4 바이트 추정)

### 임계값 커스터마이징

`.config` 파일을 직접 편집하여 임계값을 조정할 수 있습니다:

```bash
# 임계값을 70%로 낮추기 (더 일찍 경고)
vim .local/logs/.config
# warn_percent를 70으로, warn_bytes를 560000으로 변경
```

## 모범 사례

### 로깅 시점

**✅ 다음 시점에 로깅하세요**:
- 의미 있는 기능 완성 후 (예: "사용자 인증 구현")
- 중요한 결정 사항 기록 시 (예: "PostgreSQL 선택, 이유: ...")
- 휴식/종료 전 현재 작업 상태 저장
- 컨텍스트 경고 발생 시 (압축 전 필수)

**❌ 너무 잦은 로깅 피하기**:
- 단순 오타 수정, 한 줄 변경마다 로깅하지 않기
- 페이즈는 30-60분 정도의 집중 작업 단위가 적당

### 페이즈 명명 규칙

**좋은 예**:
- "사용자 인증 API 구현"
- "데이터베이스 스키마 설계"
- "프론트엔드 컴포넌트 리팩토링"

**피해야 할 예**:
- "작업1", "작업2" (의미 없음)
- "코드 수정" (너무 모호함)
- "버그 수정" (어떤 버그인지 명시)

### 컨텍스트 관리 팁

1. **정기적인 상태 확인**: `/prompt-vault:status`로 진행 상황 파악
2. **압축 전 필수 로깅**: 경고 발생 시 반드시 현재 작업 저장
3. **의미 단위 페이즈**: 한 페이즈는 하나의 명확한 목표를 가져야 함
4. **서브에이전트 활용**: 긴 탐색 작업은 Task 도구로 위임하여 메인 컨텍스트 보호

## FAQ

### Q1. 성능 영향은 어느 정도인가요?

**A**: 최소한입니다. Stop 훅은 매 응답마다 실행되지만 ~50ms 미만의 오버헤드만 발생합니다. 사용자는 체감하기 어렵습니다.

### Q2. 로그를 수동으로 편집할 수 있나요?

**A**: 네, 가능합니다. 모든 로그는 일반 마크다운 파일이므로 원하는 에디터로 자유롭게 편집할 수 있습니다. `_index.md`도 수동 업데이트 가능합니다.

### Q3. 압축 전에 로깅하는 것을 잊었다면?

**A**: 압축 전까지 기록된 페이즈는 보존되지만, 현재 작업 중이던 내용은 손실됩니다. SessionStart 훅이 최신 페이즈만 복구하므로, 압축 직전까지의 대화는 복구되지 않습니다. **따라서 경고 발생 시 반드시 로깅하는 것이 중요합니다.**

### Q4. 여러 프로젝트에서 동시에 사용할 수 있나요?

**A**: 네, 각 프로젝트의 `.local/logs/` 디렉토리가 독립적으로 관리되므로 문제없이 사용할 수 있습니다. 플러그인은 `$PWD`(현재 작업 디렉토리)를 기준으로 동작합니다.

### Q5. 로그를 Git에 커밋하고 싶다면?

**A**: `.gitignore`에서 `.local/` 행을 제거하면 됩니다. 단, 민감한 정보(API 키, 내부 로직 등)가 포함될 수 있으니 주의하세요. 팀 협업 시 유용할 수 있습니다.

### Q6. 페이즈 번호를 삭제하면 어떻게 되나요?

**A**: `/prompt-vault:log`는 기존 `phase-*.md` 파일 개수로 다음 번호를 결정하므로, 파일을 삭제해도 다음 로그는 빈 번호를 채웁니다. 예: 001, 002, 003이 있는데 002를 삭제하면 다음은 004입니다.

### Q7. 압축 없이도 로그가 유용한가요?

**A**: 네, 압축과 무관하게 프로젝트 이력을 체계적으로 관리하는 데 매우 유용합니다. `/prompt-vault:status`로 언제든 진행 상황을 조회할 수 있고, `grep`으로 과거 결정 사항을 검색할 수 있습니다.

## 문제 해결

### 권한 오류 발생

**증상**: `Permission denied: .local/logs/`

**해결**:
```bash
# 프로젝트 디렉토리 소유권 확인
ls -la .local/

# 필요 시 소유권 변경
sudo chown -R $USER:$USER .local/
```

### 컨텍스트 경고가 나타나지 않음

**원인 1**: `jq`가 설치되지 않음

**해결**:
```bash
# jq 설치 확인
which jq

# 없으면 설치
brew install jq  # macOS
```

**원인 2**: `.config` 파일이 없거나 잘못됨

**해결**:
```bash
# .config 파일 확인
cat .local/logs/.config

# 없으면 /prompt-vault:init 재실행
/prompt-vault:init
```

### 압축 후 복구가 작동하지 않음

**원인**: 압축 전에 페이즈를 로깅하지 않음

**해결**: SessionStart 훅은 `.local/logs/` 디렉토리가 있고, `_index.md`와 `phase-*.md` 파일이 최소 하나 이상 존재해야 작동합니다. 압축 전에 반드시 `/prompt-vault:log`를 실행하세요.

### 페이즈 번호가 건너뛰어짐

**원인**: 이전에 페이즈 파일을 수동으로 삭제했거나 번호 매김 로직이 기존 파일 개수 기반

**해결**: 정상 동작입니다. 번호는 순차적으로 증가하지 않아도 되며, 파일명으로 정렬하면 됩니다.

## 기여

기여를 환영합니다! 버그 리포트, 기능 제안, 풀 리퀘스트 모두 환영합니다.

- **아키텍처 이해**: [ARCHITECTURE.md](ARCHITECTURE.md)에서 플러그인 내부 구조를 확인하세요
- **이슈 제기**: [GitHub Issues](https://github.com/lemon-etvibe/prompt-vault/issues)
- **풀 리퀘스트**: 코드 스타일은 `shellcheck`로 검증하고, 마크다운은 CommonMark를 따릅니다

## 관련 문서

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — 플러그인 기술 내부 구조 및 개발자 가이드
- **[GETTING_STARTED.md](GETTING_STARTED.md)** — 단계별 튜토리얼 및 실습 가이드
- **[CLAUDE.md](CLAUDE.md)** — 한글 설계 문서 및 철학
- **[GitHub Repository](https://github.com/lemon-etvibe/prompt-vault)** — 소스 코드 및 이슈 트래킹

## 라이선스

MIT License - 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

---

**Made with ❤️ by [etvibe](https://github.com/lemon-etvibe)**
