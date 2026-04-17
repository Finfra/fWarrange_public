---
name: run
description: fWarrangeCli 빌드 및 실행 테스트
date: 2026-04-17
---

인자: $ARGUMENTS

`cli/_tool/run.sh` 또는 `cli/_tool/kill.sh` 스크립트를 실행하여 fWarrangeCli를 빌드/실행/종료함.

## 실행 방법

```bash
# 빌드 후 배포 및 실행 (기본)
bash cli/_tool/run.sh

# 빌드 없이 실행만
bash cli/_tool/run.sh run-only

# All Clear Test (통합 테스트)
bash cli/_tool/run.sh full

# 프로세스 종료만
bash cli/_tool/kill.sh
```

## 인자 처리

* **인자 없음** (`/run`): `bash cli/_tool/run.sh` 실행
* **`run-only`** (`/run run-only`): `bash cli/_tool/run.sh run-only` 실행
* **`full`** (`/run full`): All Clear Test — 빌드→배포→_config.yml 초기화→기본값 검증→API/CMD 전체 테스트→로그 검사→결과 리포트
* **`kill`** (`/run kill`): `bash cli/_tool/kill.sh` 실행 — 프로세스 종료만 수행
* **기타 인자**: `bash cli/_tool/run.sh $ARGUMENTS` 그대로 전달

## full 모드 상세 (All Clear Test)

| Step | 동작                                  |
| :--- | :------------------------------------ |
| 0    | 기존 프로세스 종료                    |
| 1    | _config.yml 백업 & 삭제              |
| 2    | Debug 빌드 & 배포                    |
| 3    | 앱 실행                              |
| 4    | REST API 헬스 체크 (최대 10초 대기)  |
| 5    | _config.yml 기본값 검증 (19개 필드)  |
| 6    | API 테스트 전체 (v1 + v2)            |
| 7    | CMD 테스트 전체 (v1 + v2)            |
| 8    | 로그 파일 ERROR/CRITICAL 검사        |
| 9    | _config.yml 복원 & 원본 설정 재시작  |
