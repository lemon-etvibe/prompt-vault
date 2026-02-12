# prompt-vault — Claude Code Plugin

## 개요
프로젝트 진행 중 각 페이즈별 사용자 프롬프트와 Claude의 실행 결과를 체계적으로 기록하고, 컨텍스트 압축 시에도 진행 상태를 보존하는 Claude Code 플러그인.

## 설계 철학
- **프롬프트와 작업 이력을 안전하게 보관하는 금고(vault)** — 컨텍스트가 압축되어도 진행 상태를 지킨다
- 모든 프로젝트에서 재사용 가능한 플러그인 형태
- 로그는 프로젝트의 `.local/logs/`에 저장 (git 추적 제외)

## 파일 구조 및 역할

| 파일 | 역할 |
|------|------|
| `.claude-plugin/plugin.json` | 플러그인 매니페스트 (이름, 버전, 설명) |
| `skills/init/SKILL.md` | `/prompt-vault:init` — 프로젝트에 로깅 환경 초기화 (.local/logs, .gitignore, CLAUDE.md, .config) |
| `skills/log/SKILL.md` | `/prompt-vault:log [제목]` — 완료된 작업을 phase-NNN.md로 기록 |
| `skills/status/SKILL.md` | `/prompt-vault:status` — _index.md 기반 진행 상태 요약 |
| `hooks/hooks.json` | Stop(컨텍스트 경고), PreCompact(시점 기록), SessionStart(복구) 훅 등록 |
| `scripts/context-check.sh` | Stop 훅 — transcript 크기로 컨텍스트 사용량 추정, 80% 초과 시 경고 |
| `scripts/pre-compact.sh` | PreCompact 훅 — compaction.log에 압축 시점/페이즈 수 기록 |
| `scripts/post-compact.sh` | SessionStart 훅 — 압축 후 _index.md + 최신 phase를 stdout으로 재주입 |
| `templates/phase.md` | 페이즈 로그 작성 템플릿 |
| `templates/index.md` | _index.md 초기 템플릿 |
| `templates/claude-md-snippet.md` | 대상 프로젝트 CLAUDE.md에 삽입할 로깅 프로토콜 |

## 대상 프로젝트에 생성되는 구조

```
project/
├── .local/
│   └── logs/
│       ├── .config          # 모델/threshold 설정
│       ├── _index.md        # 페이즈 인덱스 테이블
│       ├── phase-001.md     # 각 페이즈 로그
│       ├── phase-002.md
│       └── compaction.log   # 자동 압축 이력
├── .gitignore               # .local/ 추가됨
└── CLAUDE.md                # 로깅 프로토콜 섹션 추가됨
```

## 컨텍스트 threshold 설정

| 모델 | 컨텍스트 | 80% warn_bytes |
|------|----------|----------------|
| Opus/Sonnet/Haiku (200K) | 200K tokens | 640,000 bytes |
| Extended (1M) | 1M tokens | 3,200,000 bytes |

## 사용법

```bash
claude --plugin-dir /path/to/prompt-vault
```

## 현재 상태
- v1.0.0 초기 구현 완료
- GitHub: https://github.com/lemon-etvibe/prompt-vault
- 상세 사용 가이드(README) 보강 필요
