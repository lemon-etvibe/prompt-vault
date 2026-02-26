[English](CONTRIBUTING.en.md) | 한국어

# 기여 가이드

prompt-vault에 기여해 주셔서 감사합니다! 🎉

## 기여 방법

### 버그 리포트

1. [GitHub Issues](https://github.com/lemon-etvibe/prompt-vault/issues)에서 기존 이슈를 확인하세요
2. 동일한 이슈가 없으면 새 이슈를 생성하세요
3. 다음 정보를 포함해 주세요:
   - 재현 단계
   - 예상 동작 vs 실제 동작
   - 환경 정보 (OS, Claude Code 버전, jq 버전)

### 기능 제안

1. [GitHub Issues](https://github.com/lemon-etvibe/prompt-vault/issues)에서 Feature Request 이슈를 생성하세요
2. 제안하는 기능의 사용 시나리오를 설명해 주세요
3. 가능하다면 구현 방향도 함께 제안해 주세요

### 풀 리퀘스트

1. 레포지토리를 Fork하세요
2. 기능 브랜치를 생성하세요: `git checkout -b feature/my-feature`
3. 변경 사항을 커밋하세요: `git commit -m "feat: add my feature"`
4. 브랜치를 Push하세요: `git push origin feature/my-feature`
5. Pull Request를 생성하세요

## 코드 스타일

### 셸 스크립트
- `shellcheck`로 검증
- 주석은 한글로 작성
- `set -euo pipefail` 사용
- 함수명은 snake_case

### 마크다운
- CommonMark 표준 준수
- 사용자 문서는 한글 기본 + 영문 `.en.md` 분리
- AI 문서 (CLAUDE.md, SKILL.md)는 영문

### HTML 템플릿
- Tailwind CSS CDN 사용
- 빌드 프로세스 없이 순수 정적 HTML
- 플레이스홀더는 `{{MARKER_NAME}}` 형식

## 커밋 컨벤션

[Conventional Commits](https://www.conventionalcommits.org/) 표준을 따릅니다:

- `feat:` — 새 기능
- `fix:` — 버그 수정
- `docs:` — 문서 변경
- `chore:` — 빌드/도구 변경
- `refactor:` — 코드 리팩토링

## 라이선스

기여하신 코드는 MIT 라이선스 하에 배포됩니다.
