[English](GETTING_STARTED.en.md) | 한국어

# prompt-vault 시작 가이드

환영합니다! 이 튜토리얼은 prompt-vault 플러그인을 처음 사용하는 분들을 위한 실습 중심 가이드입니다. 단계별로 따라하면서 플러그인의 핵심 기능을 익혀보세요.

## 학습 목표

이 튜토리얼을 완료하면 다음을 할 수 있습니다:

1. ✅ 프로젝트에 prompt-vault 로깅 환경 초기화
2. ✅ 페이즈 단위로 작업 내용을 체계적으로 기록
3. ✅ 페이즈 진행 상황을 한눈에 확인
4. ✅ 컨텍스트 보호 메커니즘 이해 및 활용
5. ✅ 실제 프로젝트에서 모범 사례 적용

**소요 시간**: 15-20분
**난이도**: 초급

## 사전 요구사항

시작하기 전에 다음을 준비하세요:

```bash
# 1. Claude Code 설치 확인
claude --version

# 2. jq 설치 확인
which jq

# 없다면 설치:
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

## 튜토리얼 준비

### 1단계: 플러그인 설치

**방법 1: Claude 플러그인 추가 (권장)**
```bash
claude plugin add lemon-etvibe/prompt-vault
```

**방법 2: 수동 설치**
```bash
git clone https://github.com/lemon-etvibe/prompt-vault.git
```

### 2단계: 샘플 프로젝트 생성

```bash
# 튜토리얼용 프로젝트 디렉토리 생성
mkdir ~/tutorial-todo-app
cd ~/tutorial-todo-app

# Claude 시작 (방법 1로 설치했다면 바로 실행)
claude

# 방법 2로 설치했다면:
# claude  # prompt-vault 플러그인이 자동 로드됨
```

### 3단계: 플러그인 로드 확인

Claude가 시작되면 다음과 같은 메시지가 표시되어야 합니다:

```
✓ Loaded plugin: prompt-vault (1.1.0)
  Skills: /prompt-vault:init, /prompt-vault:log, /prompt-vault:status, /prompt-vault:report
```

만약 표시되지 않는다면:
- `claude plugin add`로 설치한 경우: `claude plugin list`로 설치 확인
- 수동 설치의 경우: `--plugin-dir` 경로가 정확한지 확인
- `prompt-vault/.claude-plugin/plugin.json` 파일이 존재하는지 확인

## 페이즈 1: 로깅 환경 초기화

이제 본격적으로 prompt-vault를 사용해봅시다!

### 1.1 초기화 실행

Claude에게 다음을 입력하세요:

```
/prompt-vault:init
```

### 1.2 예상 출력

Claude가 다음과 같은 작업을 수행합니다:

```
✓ Created .local/logs/ directory
✓ Created .local/logs/.config with context thresholds
✓ Created .local/logs/_index.md (phase index table)
✓ Added .local/ to .gitignore
✓ Added Phase Logging Protocol to CLAUDE.md

Initialization complete! You can now use:
- /prompt-vault:log [title] — Log completed work
- /prompt-vault:status — View phase progress
```

### 1.3 생성된 파일 확인

터미널에서 생성된 파일을 확인해보세요:

```bash
# 디렉토리 구조 확인
ls -la .local/logs/

# 출력 예시:
# .config
# _index.md

# .config 내용 확인
cat .local/logs/.config
```

**예상 출력**:
```json
{
  "model": "claude-opus-4-6",
  "context_window_tokens": 200000,
  "warn_percent": 80,
  "warn_bytes": 640000
}
```

### 1.4 연습 1.1: .config 필드 이해하기

`.config` 파일의 각 필드를 살펴봅시다:

- **`model`**: 현재 사용 중인 Claude 모델 ID
- **`context_window_tokens`**: 모델의 컨텍스트 윈도우 크기 (토큰 수)
- **`warn_percent`**: 경고를 발생시킬 임계값 (80% = 컨텍스트의 80% 사용 시)
- **`warn_bytes`**: transcript 파일의 바이트 크기로 환산한 임계값

**계산 예시**:
```
200,000 토큰 × 4 바이트/토큰 × 80% = 640,000 바이트
```

### 1.5 연습 1.2: 멱등성 테스트

`/prompt-vault:init`를 다시 실행해보세요. 이미 존재하는 파일은 건너뛰고, 새로운 내용만 추가됩니다.

```
/prompt-vault:init
```

**예상 출력**:
```
✓ .local/logs/ already exists, skipping
✓ .config already exists, skipping
...
```

이것이 **멱등 연산(idempotent operation)**입니다. 여러 번 실행해도 안전합니다!

## 페이즈 2: 첫 작업 시뮬레이션

이제 실제 작업을 시뮬레이션해봅시다.

### 2.1 시나리오: 할 일 앱 만들기

Claude에게 다음을 요청하세요:

```
간단한 할 일 앱을 만들어줘. Python으로 할 일 추가, 조회, 완료 표시 기능을 구현해줘.
```

Claude가 `todo.py` 파일을 생성할 것입니다. 예시 코드:

```python
# todo.py
todos = []

def add_todo(task):
    todos.append({"task": task, "done": False})
    print(f"Added: {task}")

def list_todos():
    for i, todo in enumerate(todos, 1):
        status = "✓" if todo["done"] else " "
        print(f"{i}. [{status}] {todo['task']}")

def mark_done(index):
    if 0 <= index < len(todos):
        todos[index]["done"] = True
        print(f"Marked done: {todos[index]['task']}")

if __name__ == "__main__":
    add_todo("Buy milk")
    add_todo("Write tutorial")
    list_todos()
    mark_done(0)
    list_todos()
```

### 2.2 작업 확인

```bash
# 생성된 파일 확인
ls todo.py

# 실행 테스트
python todo.py
```

**예상 출력**:
```
Added: Buy milk
Added: Write tutorial
1. [ ] Buy milk
2. [ ] Write tutorial
Marked done: Buy milk
1. [✓] Buy milk
2. [ ] Write tutorial
```

## 페이즈 3: 첫 페이즈 로깅

작업을 완료했으니 이제 로깅해봅시다!

### 3.1 페이즈 로그 생성

Claude에게 다음을 입력하세요:

```
/prompt-vault:log "할 일 앱 기본 기능 구현"
```

### 3.2 생성된 로그 확인

```bash
# phase-001.md 파일 확인
cat .local/logs/phase-001.md
```

**예상 출력**:
```markdown
# Phase 001: 할 일 앱 기본 기능 구현

- **Date**: 2026-02-12
- **Session**: 0e303ae8-0889-4a75-b99b-3a642be5c07c

## User Prompt
> 간단한 할 일 앱을 만들어줘. Python으로 할 일 추가, 조회, 완료 표시 기능을 구현해줘.

## Actions
- Python 할 일 앱 구현을 위한 `todo.py` 파일 생성
- 다음 기능 구현:
  - `add_todo(task)`: 새 할 일 추가
  - `list_todos()`: 모든 할 일 조회
  - `mark_done(index)`: 할 일 완료 표시
- 간단한 테스트 케이스 추가 (main block)

## Results
- **파일 생성**: `todo.py` (약 25줄)
- **핵심 자료구조**: `todos` 리스트 (딕셔너리 요소: task, done)
- **상태 표시**: 완료는 ✓, 미완료는 빈칸

## Decisions
- **언어 선택**: Python (간결함, 가독성)
- **자료구조**: 리스트 + 딕셔너리 (간단한 구조, DB 불필요)
- **출력 형식**: 이모지 체크박스 (시각적 명확성)

## Next
- 삭제 기능 추가
- 파일 저장/로드 기능 (영속성)
- CLI 인터페이스 개선
```

### 3.3 인덱스 확인

```bash
# _index.md 확인
cat .local/logs/_index.md
```

**예상 출력**:
```markdown
# Phase Log Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | 할 일 앱 기본 기능 구현 | done | 2026-02-12 | Python으로 할 일 추가/조회/완료 기능 구현 |
```

### 3.4 연습 2.1: 두 번째 페이즈 추가

이번에는 삭제 기능을 추가해봅시다. Claude에게:

```
todo.py에 삭제 기능을 추가해줘. 인덱스로 할 일을 삭제할 수 있어야 해.
```

Claude가 `delete_todo(index)` 함수를 추가할 것입니다. 완료 후:

```
/prompt-vault:log "할 일 삭제 기능 추가"
```

### 3.5 연습 2.2: 두 페이즈 비교

```bash
# 두 번째 로그 확인
cat .local/logs/phase-002.md

# 인덱스 업데이트 확인
cat .local/logs/_index.md
```

이제 `_index.md`에 두 개의 행이 표시됩니다!

## 페이즈 4: 진행 상태 확인

### 4.1 상태 조회

Claude에게:

```
/prompt-vault:status
```

### 4.2 예상 출력

```markdown
# Phase Log Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | 할 일 앱 기본 기능 구현 | done | 2026-02-12 | Python으로 할 일 추가/조회/완료 기능 구현 |
| 002 | 할 일 삭제 기능 추가 | done | 2026-02-12 | 인덱스 기반 할 일 삭제 함수 구현 |

Total: 2 phases completed
```

### 4.3 사용 사례

`/prompt-vault:status`는 다음 상황에서 유용합니다:
- 프로젝트를 오랜만에 다시 열었을 때
- 팀원에게 진행 상황을 공유할 때
- 다음 작업 계획을 세울 때

## 페이즈 5: 컨텍스트 보호 체험

이 섹션에서는 prompt-vault의 핵심 기능인 **컨텍스트 보호 메커니즘**을 체험합니다.

### 5.1 컨텍스트 경고 시뮬레이션

실제로는 장시간 작업 후 컨텍스트가 80%를 넘으면 자동 경고가 표시됩니다:

```
⚠️ [prompt-vault] Context ~85% used (680000 bytes).
💡 Run /prompt-vault:log to save progress, then /compact to free context.
```

### 5.2 내부 동작 이해

**Stop 훅 (context-check.sh)**이 매 응답 후 실행됩니다:

1. 현재 transcript 파일 크기 측정
2. `.local/logs/.config`에서 `warn_bytes` (640,000) 읽기
3. transcript 크기가 임계값 초과 시 경고 출력

**확인해보기**:
```bash
# Stop 훅 스크립트 확인
cat ~/Downloads/prompt-vault/scripts/context-check.sh
```

### 5.3 압축 전 체크포인트 저장

경고가 표시되면 다음을 실행:

```
/prompt-vault:log "체크포인트: 파일 저장/로드 기능 추가 완료"
/compact
```

### 5.4 압축 워크플로우

`/compact` 실행 시 다음이 순차적으로 발생합니다:

1. **PreCompact 훅** (`pre-compact.sh`) 실행
   - 현재 시각과 페이즈 개수를 `.local/logs/compaction.log`에 기록

2. **Claude가 컨텍스트 압축**
   - 긴 대화를 요약하여 컨텍스트 공간 확보

3. **SessionStart 훅** (`post-compact.sh`) 실행
   - `.local/logs/_index.md` 읽기
   - 가장 최근 `phase-*.md` 읽기
   - **두 내용을 stdout으로 출력 → Claude의 새 세션 컨텍스트로 주입**

### 5.5 복구 확인

압축 후 Claude는 다음과 같은 복구 메시지를 표시합니다:

```
=== Phase Progress (post-compaction recovery) ===
# Phase Log Index
| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | 할 일 앱 기본 기능 구현 | done | 2026-02-12 | ... |
| 002 | 할 일 삭제 기능 추가 | done | 2026-02-12 | ... |
| 003 | 체크포인트: 파일 저장/로드 기능 추가 완료 | done | 2026-02-12 | ... |

=== Latest Phase Log ===
# Phase 003: 체크포인트: 파일 저장/로드 기능 추가 완료
- **Date**: 2026-02-12
...
=== End Recovery ===
```

### 5.6 핵심 인사이트

**압축 후에도 진행 상황이 보존됩니다!**

- ✅ 페이즈 인덱스 테이블 복구 (전체 이력)
- ✅ 최신 페이즈 로그 복구 (직전 작업 컨텍스트)
- ✅ Claude가 프로젝트 상태를 인지한 상태로 재시작

### 5.7 연습 3.1: 압축 이력 확인

```bash
# 압축 이력 파일 확인
cat .local/logs/compaction.log
```

**예상 출력**:
```
⚠️ Auto-compaction at 2026-02-12 14:32:10
Phase count: 3
---
```

## 실제 시나리오

### 시나리오 1: 여러 날에 걸친 프로젝트

**1일차**:
```bash
# 프로젝트 시작
/prompt-vault:init
[작업 1] "사용자 인증 구현"
/prompt-vault:log "사용자 인증 API 구현"
[작업 2] "데이터베이스 설계"
/prompt-vault:log "PostgreSQL 스키마 설계"
```

**2일차 재개**:
```bash
# 어제까지의 상태 확인
/prompt-vault:status

# 출력:
# | 001 | 사용자 인증 API 구현 | done | 2026-02-11 | ... |
# | 002 | PostgreSQL 스키마 설계 | done | 2026-02-11 | ... |

# 이제 다음 작업 시작
[작업 3] "프론트엔드 구현"
```

### 시나리오 2: 여러 프로젝트 관리

```bash
# 프로젝트 A
cd ~/project-a
claude  # prompt-vault 플러그인이 자동 로드됨
/prompt-vault:init
[작업...]

# 프로젝트 B (독립적인 로그)
cd ~/project-b
claude  # prompt-vault 플러그인이 자동 로드됨
/prompt-vault:init
[작업...]
```

각 프로젝트의 `.local/logs/`는 완전히 독립적입니다!

### 시나리오 3: 팀 협업 (향후)

Git에 로그를 커밋하여 팀원과 공유:

```bash
# .gitignore에서 .local/ 제거
vim .gitignore
# (`.local/` 행 삭제)

# 로그 커밋
git add .local/logs/
git commit -m "docs: Add phase logs for sprint 1"
git push
```

## 모범 사례

### 로깅 시점

**완료 기준**을 명확히 하세요:

- ✅ "API 엔드포인트 3개 구현 완료" → 로깅
- ✅ "버그 수정 및 테스트 통과" → 로깅
- ❌ "코드 작성 중..." → 아직 로깅하지 않음

### 페이즈 명명

**행동 중심, 결과 지향적**으로:

```bash
# 좋은 예
/prompt-vault:log "사용자 인증 JWT 토큰 구현"
/prompt-vault:log "React 컴포넌트 3개 리팩토링"

# 피해야 할 예
/prompt-vault:log "작업"          # 너무 모호함
/prompt-vault:log "코드 수정"      # 의미 없음
```

### 페이즈 세분화

**30-60분 집중 작업 단위**로 나누세요:

```
❌ 너무 큼: "전체 앱 구현"
✅ 적당함: "사용자 모델 및 API 엔드포인트 구현"
❌ 너무 작음: "함수 하나 추가"
```

## 고급 팁

### 1. 수동 페이즈 편집

로그는 일반 마크다운 파일이므로 자유롭게 편집 가능:

```bash
vim .local/logs/phase-001.md
# 오타 수정, 내용 보완, 링크 추가 등
```

### 2. 이력 검색

과거 결정 사항이나 키워드 검색:

```bash
# "PostgreSQL" 언급된 페이즈 찾기
grep -r "PostgreSQL" .local/logs/

# 출력 예시:
# phase-002.md:## Decisions
# phase-002.md:- **데이터베이스**: PostgreSQL 선택, 이유: JSONB 지원
```

### 3. 맞춤 임계값 설정

컨텍스트 경고를 더 일찍 받고 싶다면:

```bash
vim .local/logs/.config
```

```json
{
  "model": "claude-opus-4-6",
  "context_window_tokens": 200000,
  "warn_percent": 70,          # 80 → 70으로 변경
  "warn_bytes": 560000         # 640000 → 560000으로 변경
}
```

### 4. 페이즈 내보내기

문서화나 리포트 작성에 활용:

```bash
# 모든 페이즈를 하나의 파일로 병합
cat .local/logs/phase-*.md > project-history.md

# 특정 기간의 페이즈만
cat .local/logs/phase-{001..005}.md > sprint1-history.md
```

## 튜토리얼 문제 해결

### 문제 1: 권한 거부

**증상**:
```
Error: Permission denied: .local/logs/
```

**해결**:
```bash
# 프로젝트 디렉토리 소유권 확인
ls -la .local/

# 소유권 변경
sudo chown -R $USER:$USER .local/
```

### 문제 2: 경고가 표시되지 않음

**원인**: `jq` 미설치 또는 `.config` 파일 문제

**해결**:
```bash
# jq 확인
which jq
brew install jq  # 없으면 설치

# .config 확인
cat .local/logs/.config
/prompt-vault:init  # 없으면 재초기화
```

### 문제 3: 압축 후 복구 없음

**원인**: 압축 전에 페이즈를 로깅하지 않음

**해결**:
- SessionStart 훅은 최소한 하나의 `phase-*.md` 파일이 있어야 작동
- 압축 전 반드시 `/prompt-vault:log` 실행

### 문제 4: 페이즈 번호 건너뛰기

**증상**: phase-001, phase-003 존재, phase-002 없음

**원인**: 이전에 phase-002를 수동 삭제했거나 번호 매김 로직 특성

**해결**: **정상 동작입니다.** 페이즈 번호는 연속적이지 않아도 됩니다. 파일명으로 정렬하면 됩니다.

## 다음 단계

축하합니다! 이제 prompt-vault의 핵심 기능을 모두 익혔습니다.

### 추가 학습 자료

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — 플러그인 내부 구조 심층 분석
  - 훅 시스템 작동 원리
  - 스킬 구현 세부사항
  - 커스터마이징 가이드

- **[README.md](README.md)** — 빠른 참조 가이드
  - FAQ
  - 문제 해결
  - 모범 사례

### 커스터마이징 탐색

플러그인을 자신의 워크플로우에 맞게 조정해보세요:

- 페이즈 템플릿 수정 (`templates/phase.md`)
- 임계값 조정 (`.local/logs/.config`)
- 새 훅 추가 (`hooks/hooks.json`)

### 멀티 프로젝트 워크플로우

실제 프로젝트에서 플러그인을 활용해보세요:

```bash
cd ~/my-real-project
claude  # prompt-vault 플러그인이 자동 로드됨
/prompt-vault:init
[실제 작업 시작]
```

## 자가 평가 퀴즈

튜토리얼을 잘 이해했는지 확인해보세요:

### Q1. `/prompt-vault:init`는 언제 실행하나요?
**A**: 프로젝트당 한 번만 실행합니다. 멱등 연산이므로 여러 번 실행해도 안전합니다.

### Q2. 페이즈 로그는 어떤 형식으로 저장되나요?
**A**: `.local/logs/phase-NNN.md` 마크다운 파일 (NNN은 001부터 자동 증가)

### Q3. 컨텍스트 경고는 언제 표시되나요?
**A**: transcript 크기가 `.config`의 `warn_bytes` 임계값(기본 640KB)을 초과할 때

### Q4. 압축 후 무엇이 복구되나요?
**A**: `_index.md` (페이즈 인덱스 테이블) + 가장 최근 `phase-*.md` (최신 페이즈 로그)

### Q5. Stop 훅의 역할은 무엇인가요?
**A**: 매 응답 후 transcript 크기를 체크하고, 80% 초과 시 경고 메시지 출력

### Q6. 로그를 Git에 커밋하려면?
**A**: `.gitignore`에서 `.local/` 행을 제거하면 됩니다. (민감 정보 주의!)

### Q7. 페이즈 번호가 건너뛰어도 되나요?
**A**: 네, 정상입니다. 파일을 삭제하면 번호가 건너뛸 수 있습니다.

### Q8. 여러 프로젝트에서 동시에 사용 가능한가요?
**A**: 네, 각 프로젝트의 `.local/logs/`는 독립적으로 관리됩니다.

## 리소스

- **GitHub**: https://github.com/lemon-etvibe/prompt-vault
- **이슈 트래킹**: https://github.com/lemon-etvibe/prompt-vault/issues
- **README.md**: 빠른 참조 가이드
- **ARCHITECTURE.md**: 기술 내부 구조

---

**질문이나 피드백이 있으신가요?**
GitHub Issues에 자유롭게 남겨주세요. 여러분의 의견을 기다립니다!

**Happy logging! 🚀**
