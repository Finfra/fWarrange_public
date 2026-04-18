---
name: apiTest_plan_v2
description: openapi_v2.yaml 기반 API v2 테스트 스크립트 계획
date: 2026-04-13
---

# 개요

`api/openapi_v2.yaml` 기반 **v2** REST API 테스트 스크립트 매핑.
v1 테스트는 [apiTest_plan_v1.md](apiTest_plan_v1.md) 참조.

v2는 Settings 화면 전체(General/Restore/API/Advanced/Excluded Apps/Shortcuts/
Factory Reset)를 granular endpoint로 노출함.

* 파일명 규칙: `{00-99}.{내역}.sh`
* 스크립트 위치: `cli/_tool/apiTest/v2/`
* Base URL: `http://localhost:3016`
* API Root: `/api/v2`

# 실행 방법

```bash
# v2 전체
source cli/_tool/apiTestDo.sh v2

# 특정 번호만 실행
source cli/_tool/apiTestDo.sh v2 0      # v2/00.v2-health
source cli/_tool/apiTestDo.sh v2 16     # v2/16.v2-excluded-apps-reset

# 에러 테스트
source cli/_tool/apiTestDo.sh v2 E      # v2 에러 전체
source cli/_tool/apiTestDo.sh v2 E01    # v2/E01만

# 모든 버전 + 정상/에러 일괄 (v1 + v2)
source cli/_tool/apiTestDo.sh all
```

# 스크립트 목록

## Health

| 번호 | 파일명              | Method | Endpoint        |
| ---: | :------------------ | :----- | :-------------- |
|   00 | `00.v2-health.sh`   | GET    | `/health`       |

## Settings 조회 (GET)

| 번호 | 파일명                               | Method | Endpoint                                 |
| ---: | :----------------------------------- | :----- | :--------------------------------------- |
|   01 | `01.v2-settings.sh`                  | GET    | `/api/v2/settings`                       |
|   02 | `02.v2-settings-general.sh`          | GET    | `/api/v2/settings/general`               |
|   03 | `03.v2-settings-restore.sh`          | GET    | `/api/v2/settings/restore`               |
|   04 | `04.v2-settings-api.sh`              | GET    | `/api/v2/settings/api`                   |
|   05 | `05.v2-settings-advanced.sh`         | GET    | `/api/v2/settings/advanced`              |
|   06 | `06.v2-settings-excluded-apps.sh`    | GET    | `/api/v2/settings/restore/excluded-apps` |
|   07 | `07.v2-settings-shortcuts.sh`        | GET    | `/api/v2/settings/shortcuts`             |

## Settings 업데이트 (PATCH)

| 번호 | 파일명                               | Method | Endpoint                      |
| ---: | :----------------------------------- | :----- | :---------------------------- |
|   08 | `08.v2-settings-general-patch.sh`    | PATCH  | `/api/v2/settings/general`    |
|   09 | `09.v2-settings-restore-patch.sh`    | PATCH  | `/api/v2/settings/restore`    |
|   10 | `10.v2-settings-advanced-patch.sh`   | PATCH  | `/api/v2/settings/advanced`   |
|   11 | `11.v2-settings-patch.sh`            | PATCH  | `/api/v2/settings`            |
|   12 | `12.v2-settings-api-patch.sh`        | PATCH  | `/api/v2/settings/api`        |

## Excluded Apps 변형

| 번호 | 파일명                               | Method | Endpoint                                       |
| ---: | :----------------------------------- | :----- | :--------------------------------------------- |
|   13 | `13.v2-excluded-apps-put.sh`         | PUT    | `/api/v2/settings/restore/excluded-apps`       |
|   14 | `14.v2-excluded-apps-post.sh`        | POST   | `/api/v2/settings/restore/excluded-apps`       |
|   15 | `15.v2-excluded-apps-delete.sh`      | DELETE | `/api/v2/settings/restore/excluded-apps`       |
|   16 | `16.v2-excluded-apps-reset.sh`       | POST   | `/api/v2/settings/restore/excluded-apps/reset` |

## Shortcuts / Factory Reset

| 번호 | 파일명                           | Method | Endpoint                                            |
| ---: | :------------------------------- | :----- | :-------------------------------------------------- |
|   17 | `17.v2-shortcuts-put.sh`         | PUT    | `/api/v2/settings/shortcuts`                        |
|   18 | `18.v2-factory-reset.sh`         | POST   | `/api/v2/settings/factory-reset` (X-Confirm, FORCE=1) |

# 에러 테스트 (E prefix)

에러가 **나야만 정상**인 테스트. 서버 입력 검증 검증용.

| 번호 | 파일명                                   | 기대 응답 | 검증 내용                       |
| :--- | :--------------------------------------- | :-------- | :------------------------------ |
| E01  | `E01.v2-factory-reset-no-confirm.sh`     | 400       | X-Confirm 헤더 없이 초기화      |
| E02  | `E02.v2-settings-api-invalid-port.sh`    | 400       | 범위 초과 포트(65536) 설정 시도 |

# 실행 순서 권장

* **안전한 읽기 전용**: 0, 1, 2, 3, 4, 5, 6, 7
* **상태 변경 (주의)**: 8, 9, 10, 11, 12, 17
* **Excluded Apps 변형**: 13, 14, 15, 16 (순차 실행 권장)
* **파괴적 (FORCE=1 게이트)**: 18 (factory-reset)

# 파일 구조

```
cli/_tool/apiTest/v2/
├── 00.v2-health.sh ~ 18.v2-factory-reset.sh
└── E01.v2-factory-reset-no-confirm.sh, E02.v2-settings-api-invalid-port.sh
```
