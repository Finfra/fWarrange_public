---
name: run
description: fWarrangeCli 빌드 및 실행 테스트
date: 2026-04-18
---

인자: $ARGUMENTS

`cli/_tool/run.sh` 또는 `cli/_tool/kill.sh` 스크립트를 실행하여 fWarrangeCli를 빌드/실행/종료함.

Issue31 이후 빌드 실체는 **Xcode GUI를 AppleScript로 제어**하는 `run-xcode.sh`가 담당하며, `run.sh`는 이를 래핑하는 진입점임 (TCC 회피).

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
## 또는
bash cli/_tool/run.sh kill
```

## 인자 처리

* **인자 없음** (`/run`): `bash cli/_tool/run.sh` 실행 — `build-run` 모드 (Xcode 빌드 → 배포 → 실행)
* **`run-only`** (`/run run-only`): 기존 배포 앱만 실행
* **`full`** (`/run full`): All Clear Test — 빌드→배포→_config.yml 초기화→기본값 검증→API/CMD 전체 테스트→로그 검사→결과 리포트
* **`kill`** (`/run kill`): 프로세스 종료만
* **기타 인자**: `run-xcode.sh` 에 그대로 위임 (`open`, `stop`, `build`, `deploy-run` 등)

## full 모드 상세 (All Clear Test)

| Step | 동작                                  |
| :--- | :------------------------------------ |
| 0    | 기존 프로세스 종료                    |
| 1    | _config.yml 백업 & 삭제              |
| 2    | Xcode 빌드 & 배포 & 실행 (`run-xcode.sh build-deploy`) |
| 3    | REST API 헬스 체크 (최대 10초 대기)  |
| 4    | _config.yml 기본값 검증 (19개 필드)  |
| 5    | API 테스트 전체 (v1 + v2)            |
| 6    | CMD 테스트 전체 (v1 + v2)            |
| 7    | 로그 파일 ERROR/CRITICAL 검사        |
| 8    | _config.yml 복원 & 원본 설정 재시작  |

## 파일 변경 시 주의 (Issue31 제약)

외부에서 소스 파일을 수정한 직후 Xcode가 **"Revert/Keep Xcode Version" 다이얼로그**를 띄우면 AppleScript 빌드가 `-1728` 에러로 실패함. 이 경우 Xcode 창에서 **"Revert" 버튼을 수동 클릭**한 뒤 재실행해야 함. 스크립트가 안내 메시지를 출력함.
