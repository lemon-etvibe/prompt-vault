---
name: log
description: 현재 페이즈의 대화 내용을 .local/logs/에 기록한다. 페이즈 완료 시 호출.
disable-model-invocation: false
argument-hint: [phase-title]
---

현재 대화 세션에서 완료된 작업을 페이즈 로그로 기록한다.

## 실행 절차

1. `.local/logs/` 디렉토리 확인 (없으면 생성)
2. 기존 `phase-*.md` 파일 개수로 다음 번호 결정 (3자리 zero-pad)
3. 아래 포맷으로 `phase-NNN.md` 작성:

   ```
   # Phase NNN: $ARGUMENTS (또는 자동 추론 제목)

   - **Date**: YYYY-MM-DD
   - **Session**: (세션 ID 또는 시각)

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

4. `.local/logs/_index.md` 업데이트: 해당 페이즈 행 추가/상태 변경

   ```
   | NNN | 제목 | done | YYYY-MM-DD | 한줄 요약 |
   ```

5. 완료 메시지 출력
