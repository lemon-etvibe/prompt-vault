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
