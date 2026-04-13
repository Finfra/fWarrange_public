---
name: Issue25_tasks
description: Issue25 구현 태스크 목록 — testDo 스크립트 개선
date: 2026-04-14
---

# Task 목록

## Task 1: apiTestDo.sh 개선
* **파일**: `cli/_tool/apiTestDo.sh`
* **작업**:
    - `pre_flight()` 함수 추가 — `run.sh` 호출
    - `check_logs()` 함수 추가 — wlog.log 에러 확인
    - `save_report()` 함수 추가 — `_doc_work/report/` 저장
    - `--run`, `--log`, `--report` 옵션 파싱 추가
* **완료 기준**: `bash apiTestDo.sh --run --log --report all` 실행 시 빌드·테스트·로그확인·리포트 저장 자동화

## Task 2: cmdTestDo.sh 개선
* **파일**: `cli/_tool/cmdTestDo.sh`
* **작업**: Task 1과 동일한 3가지 기능 추가
* **완료 기준**: `bash cmdTestDo.sh --run --log --report all` 실행 시 동일 자동화

## Task 3: 통합 테스트 실행
* **작업**:
    - `bash apiTestDo.sh --run --log --report all` 실행
    - `bash cmdTestDo.sh --log --report all` 실행 (run.sh는 한 번만)
* **완료 기준**: `_doc_work/report/` 에 리포트 2개 생성, 로그 에러 없음

## Task 4: Issue.md 업데이트
* **작업**: Issue25 커밋 해시 기록 후 완료 섹션 이동
* **완료 기준**: 커밋 완료
