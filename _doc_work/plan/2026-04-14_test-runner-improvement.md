---
name: 2026-04-14_test-runner-improvement
description: apiTestDo.sh / cmdTestDo.sh 테스트 러너 개선 계획
date: 2026-04-14
---

# 배경

`apiTestDo.sh`와 `cmdTestDo.sh` 실행 시 발견된 3가지 문제점과 1가지 추가 문제점에 대한 해결 계획.

# 문제점

## P1. 로그 미확인
* **현상**: 테스트 실행 전후 `wlog.log` 파일을 확인하지 않음
* **영향**: REST API 오류나 내부 예외가 로그에만 기록되어 테스트 결과만으로 놓칠 수 있음
* **대상 파일**: `cli/_tool/apiTestDo.sh`, `cli/_tool/cmdTestDo.sh`

## P2. 빌드 없이 실행
* **현상**: 테스트 전 `bash cli/_tool/run.sh`를 실행하지 않아 과거 바이너리로 테스트 가능성 있음
* **영향**: 최신 코드 변경이 반영되지 않은 앱 버전으로 테스트가 실행될 수 있음
* **대상 파일**: `cli/_tool/apiTestDo.sh`, `cli/_tool/cmdTestDo.sh`

## P3. 결과 미저장
* **현상**: 테스트 결과를 파일로 저장하지 않아 이력 추적 불가
* **영향**: 테스트 회귀 여부 비교 불가, 이슈 첨부 불가
* **대상 파일**: `cli/_tool/apiTestDo.sh`, `cli/_tool/cmdTestDo.sh`

## P4. quit 테스트가 데몬 종료 (추가 발견)
* **현상**: `all` 실행 시 `v1/17.cli-quit.sh`와 `cmdTest/v1/17.quit.sh`가 실제 데몬을 종료시켜 이후 테스트 전체 실패
* **영향**: `all` 옵션 사용 불가 (v2 테스트가 빈 응답으로 허위 통과)
* **대상 파일**: `cli/_tool/apiTest/v1/17.cli-quit.sh`, `cli/_tool/cmdTest/v1/17.quit.sh`

# 해결 방법

## S1. 로그 확인 기능 추가
* 테스트 시작 전: `wlog.log` 현재 라인 수 기록 (baseline)
* 테스트 완료 후: baseline 이후 신규 로그 라인을 리포트에 포함
* 로그 경로: `~/Documents/finfra/fWarrangeData/logs/wlog.log`

## S2. 실행 전 빌드 옵션
* `run.sh` 실행 후 테스트 진행 (기본 동작)
* `--skip-build` 플래그로 빌드 생략 가능 (이미 최신 바이너리 실행 중인 경우)
* `--run-only` 플래그로 빌드 없이 재실행만 가능

## S3. 결과 자동 저장
* 저장 경로: `_doc_work/report/YYYYMMDD_HHMMSS_{api|cmd}test.md`
* 형식: Markdown (결과 테이블 + 전체 출력 포함)
* 실행 후 경로 출력

## S4. quit/factory-reset SKIP 처리
* `FORCE=1` 환경변수 없으면 SKIP (factory-reset과 동일 방식)
* `all` 실행 시 데몬 종료 없이 전체 테스트 완주 가능

# 구현 명세

## apiTestDo.sh 변경사항

```
[헤더 추가]
--skip-build : 빌드 생략
--run-only   : 빌드 없이 실행만
--no-report  : 리포트 저장 생략

[실행 전]
1. --skip-build 없으면 bash cli/_tool/run.sh 실행
2. wlog.log 현재 wc -l 기록

[실행 후]
3. _doc_work/report/ 에 결과 저장
4. wlog.log에서 신규 라인 추출 및 리포트에 포함
```

## cmdTestDo.sh 변경사항
* apiTestDo.sh와 동일 구조 적용

## 17.cli-quit.sh / 17.quit.sh 변경사항
```bash
if [ "${FORCE:-0}" != "1" ]; then
  echo "SKIP: 데몬 종료 테스트. 실행하려면 FORCE=1 ./17.cli-quit.sh"
  exit 0
fi
```

# 파일 변경 목록

| 파일                                          | 변경 유형 |
| :-------------------------------------------- | :-------- |
| `cli/_tool/apiTestDo.sh`                      | 수정      |
| `cli/_tool/cmdTestDo.sh`                      | 수정      |
| `cli/_tool/apiTest/v1/17.cli-quit.sh`         | 수정      |
| `cli/_tool/cmdTest/v1/17.quit.sh`             | 수정      |
