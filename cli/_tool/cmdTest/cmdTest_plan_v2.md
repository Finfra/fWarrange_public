---
name: cmdTest_plan_v2
description: fWarrangeCli CLI v2 커맨드 테스트 계획 (openapi_v2.yaml 기반)
date: 2026-04-13
---

# 개요

`api/openapi_v2.yaml` 기반 CLI **v2** 서브커맨드 테스트 스크립트 매핑.
v1 커맨드는 [cmdTest_plan_v1.md](cmdTest_plan_v1.md) 참조.

`CLIHandler.swift`의 `v2` 서브커맨드가 Settings 전 탭(General/Restore/API/Advanced/
Excluded Apps/Shortcuts/Factory Reset)을 노출함.

* 파일명 규칙: `{00-99}.{내역}.sh`
* 스크립트 위치: `cli/_tool/cmdTest/v2/`
* 실행 대상: `fWarrangeCli` 바이너리 (Homebrew 설치 또는 빌드 결과물)
* 전제 조건: fWarrangeCli 데몬이 실행 중이어야 함

# 실행 방법

```bash
# v2 전체
source cli/_tool/cmdTestDo.sh v2

# 특정 번호만 실행
source cli/_tool/cmdTestDo.sh v2 0      # v2/00.v2-settings
source cli/_tool/cmdTestDo.sh v2 15     # v2/15.v2-excluded-apps-reset

# 에러 테스트
source cli/_tool/cmdTestDo.sh v2 E      # v2 에러 전체
source cli/_tool/cmdTestDo.sh v2 E01    # v2/E01만

# 모든 버전 + 정상/에러 일괄 (v1 + v2)
source cli/_tool/cmdTestDo.sh all
```

# 바이너리 경로

```bash
# Homebrew 설치 시
CLI="/opt/homebrew/opt/fwarrangecli/fWarrangeCli.app/Contents/MacOS/fWarrangeCli"

# 로컬 빌드 시
CLI="/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli"
```

# 스크립트 목록

## Settings 조회 (GET)

| 번호 | 파일명                       | 커맨드                 | 엔드포인트                            |
| ---: | :--------------------------- | :--------------------- | :------------------------------------ |
|   00 | `00.v2-settings.sh`          | `v2 settings`          | GET `/settings`                       |
|   01 | `01.v2-settings-general.sh`  | `v2 settings general`  | GET `/settings/general`               |
|   02 | `02.v2-settings-restore.sh`  | `v2 settings restore`  | GET `/settings/restore`               |
|   03 | `03.v2-settings-api.sh`      | `v2 settings api`      | GET `/settings/api`                   |
|   04 | `04.v2-settings-advanced.sh` | `v2 settings advanced` | GET `/settings/advanced`              |
|   05 | `05.v2-excluded-apps.sh`     | `v2 excluded-apps`     | GET `/settings/restore/excluded-apps` |
|   06 | `06.v2-shortcuts.sh`         | `v2 shortcuts`         | GET `/settings/shortcuts`             |

## Settings 업데이트 (PATCH)

| 번호 | 파일명                               | 커맨드                                 | 엔드포인트                 |
| ---: | :----------------------------------- | :------------------------------------- | :------------------------- |
|   07 | `07.v2-settings-general-patch.sh`    | `v2 settings general patch '{...}'`    | PATCH `/settings/general`  |
|   08 | `08.v2-settings-restore-patch.sh`    | `v2 settings restore patch '{...}'`    | PATCH `/settings/restore`  |
|   09 | `09.v2-settings-advanced-patch.sh`   | `v2 settings advanced patch '{...}'`   | PATCH `/settings/advanced` |
|   10 | `10.v2-settings-patch.sh`            | `v2 settings patch '{...}'`            | PATCH `/settings`          |
|   11 | `11.v2-settings-api-patch.sh`        | `v2 settings api patch '{...}'`        | PATCH `/settings/api`      |

## Excluded Apps 변형

| 번호 | 파일명                            | 커맨드                            | 엔드포인트                                   |
| ---: | :-------------------------------- | :-------------------------------- | :------------------------------------------- |
|   12 | `12.v2-excluded-apps-set.sh`      | `v2 excluded-apps set <app>...`   | PUT `/settings/restore/excluded-apps`        |
|   13 | `13.v2-excluded-apps-add.sh`      | `v2 excluded-apps add <app>`      | POST `/settings/restore/excluded-apps`       |
|   14 | `14.v2-excluded-apps-remove.sh`   | `v2 excluded-apps remove <app>`   | DELETE `/settings/restore/excluded-apps`     |
|   15 | `15.v2-excluded-apps-reset.sh`    | `v2 excluded-apps reset`          | POST `/settings/restore/excluded-apps/reset` |

## Shortcuts / Factory Reset

| 번호 | 파일명                       | 커맨드                                   | 엔드포인트                    |
| ---: | :--------------------------- | :--------------------------------------- | :---------------------------- |
|   16 | `16.v2-shortcuts-set.sh`     | `v2 shortcuts set '{...}'`               | PUT `/settings/shortcuts`     |
|   17 | `17.v2-factory-reset.sh`     | `v2 factory-reset --confirm` (FORCE=1)   | POST `/settings/factory-reset` |

# 에러 테스트 (E prefix)

에러가 **나야만 정상**인 테스트. CLI 입력 검증 및 에러 핸들링 검증용.

| 번호 | 파일명                                   | 커맨드                            | 기대 결과             |
| :--- | :--------------------------------------- | :-------------------------------- | :-------------------- |
| E01  | `E01.v2-factory-reset-no-confirm.sh`     | `v2 factory-reset`                | `--confirm` 필수 에러 |
| E02  | `E02.v2-settings-unknown-tab.sh`         | `v2 settings foobar`              | 알 수 없는 탭 에러    |

# 실행 순서 권장

* **안전한 읽기 전용**: 0, 1, 2, 3, 4, 5, 6
* **상태 변경 (주의)**: 7, 8, 9, 10, 11, 16
* **Excluded Apps 변형**: 12, 13, 14, 15 (순차 실행 권장)
* **파괴적 (FORCE=1 게이트)**: 17 (factory-reset)

# 파일 구조

```
cli/_tool/cmdTest/v2/
├── 00.v2-settings.sh ~ 17.v2-factory-reset.sh
└── E01.v2-factory-reset-no-confirm.sh, E02.v2-settings-unknown-tab.sh
```
