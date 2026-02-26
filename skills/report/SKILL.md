---
name: report
description: 페이즈 로그를 HTML 리포트로 시각화한다.
disable-model-invocation: false
argument-hint: [summary|detail|all|custom]
---

페이즈 로그 데이터를 파싱하여 시각화된 HTML 리포트를 생성한다.

## 인자

- `summary` — 요약 대시보드만 생성
- `detail` — 상세 채팅 로그 뷰만 생성
- `all` (기본) — 둘 다 생성
- `custom` — Claude가 사용자 요청에 맞게 커스텀 리포트 생성

## 실행 절차

### 기본 리포트 (summary / detail / all)

1. `${CLAUDE_PLUGIN_ROOT}/scripts/generate-report.sh` 실행:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/generate-report.sh" [summary|detail|all]
   ```

2. 생성된 파일 경로를 사용자에게 안내:
   - `.local/logs/report-summary.html` — 프로젝트 요약 대시보드
   - `.local/logs/report-detail.html` — 페이즈별 상세 채팅 로그

3. 브라우저에서 여는 방법 안내:
   ```bash
   open .local/logs/report-summary.html   # macOS
   xdg-open .local/logs/report-detail.html # Linux
   ```

### 커스텀 리포트 (custom)

1. 먼저 기본 리포트를 생성한다 (위 절차 동일).
2. 사용자의 추가 요청을 확인한다 (예: "회고 섹션 추가", "특정 팔레트 적용").
3. 생성된 HTML 파일을 읽고, 사용자 요청에 맞게 수정/보강한다.
4. 수정된 파일을 저장하고 경로를 안내한다.

## 데이터 소스

리포트 생성 시 다음 데이터를 참조한다:

- **프로젝트 메타**: `.local/logs/.config` — `project_name`, `project_description`, `palette`
- **페이즈 인덱스**: `.local/logs/_index.md` — 페이즈 목록 테이블
- **페이즈 상세**: `.local/logs/phase-*.md` — 각 페이즈의 프롬프트, 작업, 결과, 결정, 다음 단계
- **추가 컨텍스트** (있으면 참고): `package.json`, `CLAUDE.md`

## 에러 처리

- `.local/logs/` 미존재 → 사용자에게 `/prompt-vault:init` 실행을 안내
- `_index.md` 없음 → 빈 리포트 생성, 경고 메시지 포함
- `phase-*.md` 비표준 형식 → 파싱 가능한 부분만 표시, 나머지는 빈 상태
- `.config` 없음 → 기본값으로 동작 (프로젝트 디렉토리명, 기본 팔레트)
