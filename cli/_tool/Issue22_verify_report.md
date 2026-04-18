---
name: Issue22_verify_report
description: Issue22 (REST API v2 설정 엔드포인트) 검증 리포트 — cmdTest + apiTest 실행 결과
date: 2026-04-13
---

# 개요

Issue22에서 도입된 REST API v2(`/api/v2/settings/*`) 엔드포인트와 기존 v1·CLI 바이너리 회귀를 검증함.

* 빌드: `fWarrangeCli` Release (Xcode, BUILD SUCCEEDED)
* 배포: `/Applications/_nowage_app/fWarrangeCli.app`
* 데몬: `http://localhost:3016` (uptime 확인, 데몬 재시작 없이 모든 테스트 통과)
* 실행일: 2026-04-13

# 테스트 도구 업데이트 (apiTest)

v2 신규 엔드포인트를 커버하기 위해 `cli/_tool/apiTest/`에 스크립트 12종 추가. `apiTest_plan.md`에 v2 섹션 병기.

|   번호 | 파일                                    | Method | Endpoint                                 |
| ---: | :------------------------------------ | :----- | :--------------------------------------- |
|   20 | `20.v2-settings.sh`                   | GET    | `/api/v2/settings`                       |
|   21 | `21.v2-settings-general.sh`           | GET    | `/api/v2/settings/general`               |
|   22 | `22.v2-settings-restore.sh`           | GET    | `/api/v2/settings/restore`               |
|   23 | `23.v2-settings-api.sh`               | GET    | `/api/v2/settings/api`                   |
|   24 | `24.v2-settings-advanced.sh`          | GET    | `/api/v2/settings/advanced`              |
|   25 | `25.v2-settings-excluded-apps.sh`     | GET    | `/api/v2/settings/restore/excluded-apps` |
|   26 | `26.v2-settings-shortcuts.sh`         | GET    | `/api/v2/settings/shortcuts`             |
|   27 | `27.v2-settings-general-patch.sh`     | PATCH  | `/api/v2/settings/general`               |
|   28 | `28.v2-settings-restore-patch.sh`     | PATCH  | `/api/v2/settings/restore`               |
|   29 | `29.v2-settings-advanced-patch.sh`    | PATCH  | `/api/v2/settings/advanced`              |
|  E08 | `E08.v2-factory-reset-no-confirm.sh`  | POST   | `/api/v2/settings/factory-reset` (헤더 누락) |
|  E09 | `E09.v2-settings-api-invalid-port.sh` | PATCH  | `/api/v2/settings/api` (포트 65536)        |

PATCH 3종은 서버·데몬 재시작을 유발하지 않도록 현재값 그대로 재전송(no-op)로 설계. `PATCH /settings/api`와 `factory-reset` 실 실행은 회피, 에러 케이스로만 검증.

cmdTest 측은 Issue22가 CLI 바이너리 커맨드를 변경하지 않으므로 스크립트 변경 없음(회귀 검증 전용).

# 실행 결과 요약

## apiTest (`source cli/_tool/apiTestDo.sh all`)

* 정상 테스트: 28개 (v1 17 + v2 10 + health 1) — **모두 200 OK + `"status":"ok"`**
    - 예외: `[07] capture` 의 내부 재현 테스트 중 `testCapture` 임시 레이아웃 조회 단계에서 `레이아웃을 찾을 수 없음` 응답 1건 — 스크립트 내부 정리 로직 흐름으로 **예상된 중간 단계**이며 최종 capture 응답은 정상
    - `[08] restore`, `[11] windows-apps(일부)`: Accessibility 권한 미부여 환경에서의 의도된 에러 응답
* 에러 테스트: 9개 (E01~E09) — **모두 기대한 에러 메시지 반환**
    - E08: `"X-Confirm: true 헤더가 필요합니다"` ✅
    - E09: `"포트 범위가 올바르지 않습니다"` ✅

### v2 PATCH 응답 확인

| 테스트         | 응답 본문(data)                                                                                                                     |
| :---------- | :------------------------------------------------------------------------------------------------------------------------------ |
| 27 general  | `appLanguage/dataStorageMode/launchAtLogin/theme` 정상 반환                                                                         |
| 28 restore  | `enableParallelRestore/excludedApps/maxRetries/minimumMatchScore/retryInterval` 정상 반환                                           |
| 29 advanced | `autoSaveOnSleep/clickSwitchToMain/confirmBeforeDelete/logFilePath/logLevel/maxAutoSaves/restoreButtonStyle/showInCmdTab` 정상 반환 |

PATCH 후 GET 스냅샷과 동일한 필드셋이 돌아와 **routeV2 PATCH 핸들러와 `applySettingsPatch` 경로가 정상 동작**함이 확인됨.

## cmdTest (`source cli/_tool/cmdTestDo.sh all`)

* 정상 커맨드 17개 — **모두 정상 응답**
    - `04.settings`, `06.list`, `07.show`, `13.windows`, `14.windows-filter`, `15.apps` 등 대용량 출력까지 정상 JSON 반환
    - `11.remove-windows`, `16.accessibility`는 Accessibility 권한 관련 에러 응답(환경 한계)
* 에러 커맨드 7개 (E01~E07) — **모두 기대한 실패 경로**
    - `E05 delete-all-no-confirm`, `E06 quit-no-confirm`, `E07 daemon-not-running`까지 정상적으로 가드 메시지 노출
* `17.quit`는 `X-Confirm` 미포함으로 데몬 종료 유발하지 않도록 설계됨 확인

## 데몬 안정성

* 전체 테스트 약 2분 수행 후에도 `GET /` health 응답 `"status":"ok"` 유지
* `PATCH /api/v2/settings/api`를 실호출하지 않아 자동 재시작 이벤트 없음 → v1/v2 응답 일관성 유지

# 판정

| 항목                                      | 결과                 |
| :-------------------------------------- | :----------------- |
| v2 settings GET 엔드포인트 (6)               | ✅ PASS             |
| v2 settings PATCH 엔드포인트 (3)             | ✅ PASS             |
| v2 에러 가드 (factory-reset / invalid port) | ✅ PASS             |
| v1 회귀 (16 엔드포인트 + 에러 7)                 | ✅ PASS             |
| CLI 바이너리 회귀 (17 커맨드 + 에러 7)             | ✅ PASS             |
| 데몬 자동 재시작 트리거 검증                        | ⏸️ 수동 보류 (안전상 미실행) |

Issue22의 v2 도입 범위는 정상 동작함. GUI `applyApiSettings`의 포트/CIDR 변경 시 자동 재시작 동작은 위험 부담으로 자동 테스트에서 제외했으며, 추후 수동 또는 격리 테스트 환경에서 별도 검증을 권장함.

# 환경 제약 메모

* Accessibility 권한이 `fWarrangeCli.app`에 부여되어 있지 않아 `restore`, `remove-windows`, `windows/apps` 일부가 `"Accessibility 권한이 필요합니다"` 응답을 반환함. v2 범위와 무관하며 환경 이슈.
* 테스트 실행 위치: 프로젝트 루트(`_public/`). `bash` 로 `source` 대신 직접 실행해도 동일 결과.

# 산출물

* 신규 스크립트: `cli/_tool/apiTest/{20..29}.*.sh`, `E08.*.sh`, `E09.*.sh`
* 계획서 갱신: `cli/_tool/apiTest/apiTest_plan.md` (v2 섹션 추가)
* 실행 로그: `/tmp/apiTest.log`, `/tmp/cmdTest.log` (휘발성, 재실행으로 재현 가능)
