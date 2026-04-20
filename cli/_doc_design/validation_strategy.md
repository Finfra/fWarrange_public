---
name: validation_strategy
description: API 업그레이드 시 테스트 검증 전략 — openapi.yaml ↔ apiTest ↔ cmdTest 교차 검증 절차
date: 2026-04-13
---

# 목적

API 엔드포인트를 추가/수정/삭제할 때 **openapi.yaml, 테스트 스크립트(apiTest/cmdTest), 소스 코드** 3자가 항상 동기화되도록 하는 검증 절차를 정의함.

# 검증 계층 구조

```
openapi_v1.yaml / openapi_v2.yaml (SSOT)
    ↓ 명세 기준
apiTest/v1/ + apiTest/v2/ (curl 기반 REST 테스트)
    ↓ 동일 기능
cmdTest/ (CLI 바이너리 테스트)
    ↓ 통합 시나리오
CRUD 시나리오 (capture → restore → delete → 실패 확인)
```

# 검증 대상 파일

| 구분            | 경로                                                       | 역할                   |
| :-------------- | :--------------------------------------------------------- | :--------------------- |
| API 명세 v1     | `api/openapi_v1.yaml`                                      | v1 엔드포인트 정의 (SSOT) |
| API 명세 v2     | `api/openapi_v2.yaml`                                      | v2 엔드포인트 정의 (SSOT) |
| API 테스트 v1   | `cli/_tool/apiTest/v1/*.sh`                                | curl 기반 REST 테스트 (v1) |
| API 테스트 v2   | `cli/_tool/apiTest/v2/*.sh`                                | curl 기반 REST 테스트 (v2) |
| API 테스트 계획 v1 | `cli/_tool/apiTest/apiTest_plan_v1.md`                  | v1 스크립트 목록/상세  |
| API 테스트 계획 v2 | `cli/_tool/apiTest/apiTest_plan_v2.md`                  | v2 스크립트 목록/상세  |
| CLI 테스트      | `cli/_tool/cmdTest/*.sh`                                   | CLI 바이너리 테스트    |
| CLI 테스트 계획 | `cli/_tool/cmdTest/cmdTest_plan.md`                        | 스크립트 목록/상세     |
| 소스 코드       | `cli/fWarrangeCli/Services/RESTServer.swift`               | 라우팅 구현            |
| CLI 핸들러      | `cli/fWarrangeCli/Services/CLIHandler.swift`               | CLI 커맨드 구현        |
| 설정 서비스     | `cli/fWarrangeCli/Services/SettingsService.swift`          | v2 설정 처리           |
| 테스트 리포트   | `cli/_doc_work/report/`                                    | 검증 결과 기록         |

# 테스트 디렉토리

| 경로                     | 역할                  | 실행기           |
| :----------------------- | :-------------------- | :--------------- |
| `cli/_tool/apiTest/v1/`  | REST API curl 테스트 (v1) | `apiTestDo.sh v1` |
| `cli/_tool/apiTest/v2/`  | REST API curl 테스트 (v2) | `apiTestDo.sh v2` |
| `cli/_tool/cmdTest/`     | CLI 커맨드 테스트     | `cmdTestDo.sh`   |
| `cli/_doc_work/report/`  | 검증 리포트 저장      | -                |

# 파일명 규칙

```
{00~99}.{내역}.sh       ← 정상 케이스
E{01~99}.{내역}.sh      ← 에러 케이스
```

* 내역: kebab-case
* 동적 데이터: 테스트 내에서 사전 캡처 후 사용 (하드코딩 금지)

# 검증 절차 (API 업그레이드 시)

## Phase 1: 명세-구현 동기화 확인

```
openapi_v1.yaml / openapi_v2.yaml의 paths 섹션에서 모든 엔드포인트 추출
  ↓
RESTServer.swift의 라우팅 핸들러와 1:1 대응 확인
  ↓
불일치 시 → openapi.yaml 또는 소스 코드 수정
```

**확인 명령:**
```bash
# openapi_v1.yaml 엔드포인트 목록
grep -E '^\s+/' api/openapi_v1.yaml | grep -v '#' | grep -v 'url:' | sed 's/://g' | awk '{print $1}' | sort -u

# openapi_v2.yaml 엔드포인트 목록
grep -E '^\s+/' api/openapi_v2.yaml | grep -v '#' | grep -v 'url:' | sed 's/://g' | awk '{print $1}' | sort -u

# RESTServer.swift 라우팅 경로
grep -E 'case.*apiBasePath|path ==' cli/fWarrangeCli/Services/RESTServer.swift
```

## Phase 2: 테스트 커버리지 확인

```
openapi.yaml의 각 엔드포인트에 대해:
  ├── apiTest에 대응 스크립트 존재?
  ├── cmdTest에 대응 스크립트 존재? (CLI 미대응 엔드포인트 제외)
  ├── 에러 응답(400, 404, 403 등)에 대응 에러 테스트 존재?
  └── optional 파라미터 테스트 존재?
```

## Phase 3: 시나리오 테스트 실행

단위 테스트 통과 후, 레이아웃 생명주기 전체를 순차 검증:

```
1. capture × 2 (이름 지정)
2. capture × 1 (이름 생략 → 기본 레이아웃)
3. restore × 2 (이름 지정 + 기본 레이아웃)
4. delete → list 확인 (삭제된 항목 미포함)
5. 전체 삭제
6. 삭제된 레이아웃 restore (실패 기대)
```

**API 시나리오:**
```bash
BASE="http://localhost:3016/api/v1"
# Step 1: 캡처
curl -X POST "$BASE/capture" -H "Content-Type: application/json" -d '{"name":"scenA"}'
curl -X POST "$BASE/capture" -H "Content-Type: application/json" -d '{"name":"scenB"}'
# Step 2: 기본 캡처
curl -X POST "$BASE/capture" -H "Content-Type: application/json" -d '{}'
# Step 3: 복구
curl -X POST "$BASE/layouts/scenA/restore" -H "Content-Type: application/json" -d '{}'
curl -X POST "$BASE/layouts/default/restore" -H "Content-Type: application/json" -d '{}'
# Step 4: 삭제 + 확인
curl -X DELETE "$BASE/layouts/scenB"
curl "$BASE/layouts"
# Step 5: 정리
curl -X DELETE "$BASE/layouts/scenA"
curl -X DELETE "$BASE/layouts/default"
# Step 6: 실패 확인
curl -X POST "$BASE/layouts/scenA/restore" -H "Content-Type: application/json" -d '{}'
# 기대: status=error
```

**CLI 시나리오:**
```bash
CLI="/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli"
$CLI capture cliA && $CLI capture cliB && $CLI capture
$CLI restore cliA && $CLI restore default
$CLI delete cliB && $CLI list
$CLI delete cliA && $CLI delete default
$CLI restore cliA  # 기대: error
```

## Phase 4: plan 문서 동기화

테스트 스크립트를 추가/수정하면 반드시 plan 문서도 함께 업데이트:

* `cli/_tool/apiTest/apiTest_plan_v1.md` — v1 스크립트 목록 테이블 + 상세 섹션
* `cli/_tool/apiTest/apiTest_plan_v2.md` — v2 스크립트 목록 테이블 + 상세 섹션
* `cli/_tool/cmdTest/cmdTest_plan.md` — 스크립트 목록 테이블 + 상세 섹션

## Phase 5: 리포트 생성

검증 결과를 `cli/_doc_work/report/` 에 기록:

* 파일명: `check_api_cmd_report.md` (최신 결과 덮어쓰기) 또는 날짜별 아카이브
* 포함 내용: 환경, 시나리오별 PASS/FAIL, 발견 사항, 미해결 과제

# 교차 검증 매트릭스

## v1 엔드포인트

| openapi_v1.yaml 엔드포인트           | Method | apiTest (v1/)    | cmdTest          | 비고             |
| :------------------------------------ | :----- | :--------------- | :--------------- | :--------------- |
| GET /health                           | GET    | 00.health        | 03.health        | 서버루트 / 포함  |
| GET /settings                         | GET    | 01.settings      | 04.settings      |                  |
| GET /layouts                          | GET    | 02.layouts-list  | 06.list          |                  |
| DELETE /layouts                       | DELETE | 06.delete-all    | 12.delete-all    |                  |
| GET /layouts/{name}                   | GET    | 03.layout-detail | 07.show          |                  |
| PUT /layouts/{name}                   | PUT    | 04.layout-rename | 08.rename        |                  |
| DELETE /layouts/{name}                | DELETE | 05.layout-delete | 09.delete        |                  |
| POST /capture                         | POST   | 07.capture       | 05.capture       | filterApps 포함  |
| POST /layouts/{name}/restore          | POST   | 08.restore       | 10.restore       |                  |
| POST /layouts/{name}/windows/remove   | POST   | 09.remove-win    | 11.remove-win    |                  |
| GET /windows/current                  | GET    | 10.win-current   | 13.windows       | filterApps 쿼리  |
| GET /windows/current?filterApps=      | (쿼리) | 10.(파라미터)    | 14.win-filter    |                  |
| GET /windows/apps                     | GET    | 11.win-apps      | 15.apps          |                  |
| PUT /ui/state                         | PUT    | 14.ui-state      | -                | API 전용         |
| GET /settings/default-layout          | GET    | 12.default-layout | -               | 설정 전용        |
| PUT /settings/default-layout          | PUT    | 12.default-layout | -               | 설정 전용        |
| GET /cli/status                       | GET    | 15.cli-status    | 02.status        |                  |
| GET /cli/version                      | GET    | 16.cli-version   | 01.version       |                  |
| POST /cli/quit                        | POST   | 17.cli-quit      | 17.quit          |                  |
| GET /status/accessibility             | GET    | 18.access        | 16.access        |                  |

## v2 엔드포인트

| openapi_v2.yaml 엔드포인트                            | Method | apiTest (v2/)                    | cmdTest | 비고              |
| :---------------------------------------------------- | :----- | :------------------------------- | :------ | :---------------- |
| GET /health                                           | GET    | 00.v2-health                     | -       | v1 공용           |
| GET /api/v2/settings                                  | GET    | 01.v2-settings                   | -       | 전체 설정         |
| GET /api/v2/settings/general                          | GET    | 02.v2-settings-general           | -       |                   |
| GET /api/v2/settings/restore                          | GET    | 03.v2-settings-restore           | -       |                   |
| GET /api/v2/settings/api                              | GET    | 04.v2-settings-api               | -       |                   |
| GET /api/v2/settings/advanced                         | GET    | 05.v2-settings-advanced          | -       |                   |
| GET /api/v2/settings/restore/excluded-apps            | GET    | 06.v2-settings-excluded-apps     | -       |                   |
| GET /api/v2/settings/shortcuts                        | GET    | 07.v2-settings-shortcuts         | -       |                   |
| PATCH /api/v2/settings/general                        | PATCH  | 08.v2-settings-general-patch     | -       |                   |
| PATCH /api/v2/settings/restore                        | PATCH  | 09.v2-settings-restore-patch     | -       |                   |
| PATCH /api/v2/settings/advanced                       | PATCH  | 10.v2-settings-advanced-patch    | -       |                   |
| PATCH /api/v2/settings                                | PATCH  | 11.v2-settings-patch             | -       | 전체 일괄 수정    |
| PATCH /api/v2/settings/api                            | PATCH  | 12.v2-settings-api-patch         | -       |                   |
| PUT /api/v2/settings/restore/excluded-apps            | PUT    | 13.v2-excluded-apps-put          | -       | 전체 교체         |
| POST /api/v2/settings/restore/excluded-apps           | POST   | 14.v2-excluded-apps-post         | -       | 단건 추가         |
| DELETE /api/v2/settings/restore/excluded-apps         | DELETE | 15.v2-excluded-apps-delete       | -       | 단건 삭제         |
| POST /api/v2/settings/restore/excluded-apps/reset     | POST   | 16.v2-excluded-apps-reset        | -       | 기본값 복원       |
| PUT /api/v2/settings/shortcuts                        | PUT    | 17.v2-shortcuts-put              | -       |                   |
| POST /api/v2/settings/factory-reset                   | POST   | 18.v2-factory-reset              | -       | X-Confirm 필수    |

# API 전용 엔드포인트 (CLI 미대응)

| 엔드포인트                 | Method | 사유                                        |
| :------------------------- | :----- | :------------------------------------------ |
| `PUT /ui/state`            | PUT    | GUI 캡처 자동화 전용 — CLI 노출 불필요       |
| v2 `/api/v2/settings/*`    | 다수   | 설정 전용 — CLI 노출 미구현                 |

CLI에서 대응하지 않는 엔드포인트는 apiTest에서만 검증하며, cmdTest_plan에 "API 전용" 섹션으로 명시함.

# openapi.yaml ↔ apiTest 파라미터 커버리지

## v1

| 엔드포인트                          | 필수 파라미터          | optional 파라미터                                      | 테스트 현황                   |
| :---------------------------------- | :--------------------- | :----------------------------------------------------- | :---------------------------- |
| `GET /health`                       | -                      | -                                                      | ✅ (00) 서버루트+versioned    |
| `GET /settings`                     | -                      | -                                                      | ✅ (01)                       |
| `GET /layouts`                      | -                      | -                                                      | ✅ (02)                       |
| `GET /layouts/{name}`               | name                   | -                                                      | ✅ (03)                       |
| `PUT /layouts/{name}`               | name, newName(body)    | -                                                      | ✅ (04)                       |
| `DELETE /layouts/{name}`            | name                   | -                                                      | ✅ (05)                       |
| `DELETE /layouts`                   | X-Confirm-Delete-All   | -                                                      | ✅ (06)                       |
| `POST /capture`                     | -                      | name, filterApps                                       | ✅ name(07), filterApps(07)   |
| `POST /layouts/{name}/restore`      | name                   | maxRetries, retryInterval, minimumScore, enableParallel | ✅ 기본(08), ⚠️ optional 미테스트 |
| `POST /layouts/{name}/windows/remove` | name, windowIds      | -                                                      | ✅ (09)                       |
| `GET /windows/current`              | -                      | filterApps                                             | ✅ 기본(10), filterApps(10)   |
| `GET /windows/apps`                 | -                      | -                                                      | ✅ (11)                       |
| `PUT /ui/state`                     | -                      | hideWindows, selectApps, excludeApps                   | ✅ hideWindows(14), ⚠️ selectApps 미테스트 |
| `GET /cli/status`                   | -                      | -                                                      | ✅ (15)                       |
| `GET /cli/version`                  | -                      | -                                                      | ✅ (16)                       |
| `POST /cli/quit`                    | X-Confirm              | -                                                      | ✅ (17)                       |
| `GET /status/accessibility`         | -                      | -                                                      | ✅ (18)                       |

**미커버 파라미터 (v1):**
* `POST /restore`의 optional (maxRetries, retryInterval, minimumScore, enableParallel)
* `PUT /ui/state`의 selectApps, excludeApps

## v2

| 엔드포인트                                        | 필수 파라미터     | optional 파라미터 | 테스트 현황  |
| :------------------------------------------------ | :---------------- | :---------------- | :----------- |
| `GET /api/v2/settings`                            | -                 | -                 | ✅ (01)      |
| `GET /api/v2/settings/general`                    | -                 | -                 | ✅ (02)      |
| `GET /api/v2/settings/restore`                    | -                 | -                 | ✅ (03)      |
| `GET /api/v2/settings/api`                        | -                 | -                 | ✅ (04)      |
| `GET /api/v2/settings/advanced`                   | -                 | -                 | ✅ (05)      |
| `GET /api/v2/settings/restore/excluded-apps`      | -                 | -                 | ✅ (06)      |
| `GET /api/v2/settings/shortcuts`                  | -                 | -                 | ✅ (07)      |
| `PATCH /api/v2/settings/general`                  | body(partial)     | -                 | ✅ (08)      |
| `PATCH /api/v2/settings/restore`                  | body(partial)     | -                 | ✅ (09)      |
| `PATCH /api/v2/settings/advanced`                 | body(partial)     | -                 | ✅ (10)      |
| `PATCH /api/v2/settings`                          | body(partial)     | -                 | ✅ (11)      |
| `PATCH /api/v2/settings/api`                      | body(partial)     | -                 | ✅ (12)      |
| `PUT /api/v2/settings/restore/excluded-apps`      | body(array)       | -                 | ✅ (13)      |
| `POST /api/v2/settings/restore/excluded-apps`     | bundleId(body)    | -                 | ✅ (14)      |
| `DELETE /api/v2/settings/restore/excluded-apps`   | bundleId(query)   | -                 | ✅ (15)      |
| `POST /api/v2/settings/restore/excluded-apps/reset` | -               | -                 | ✅ (16)      |
| `PUT /api/v2/settings/shortcuts`                  | body(object)      | -                 | ✅ (17)      |
| `POST /api/v2/settings/factory-reset`             | X-Confirm         | -                 | ✅ (18), E01 |

# 알려진 차이점

## API vs CLI 기본 레이아웃 이름

| 방식 | 이름 생략 시 기본값 | 소스 위치                            |
| :--- | :------------------ | :----------------------------------- |
| API  | `default`           | RESTServer.swift `handleCapture`     |
| CLI  | `default`           | CLIHandler.swift capture 기본값      |

시나리오 테스트 시 양쪽 기본값이 다르므로 주의.

# 번호 체계

API 테스트와 CLI 테스트의 번호가 다름 (의도적). 각각의 논리적 그룹핑 우선:

* **apiTest**: openapi.yaml paths 순서 기반
* **cmdTest**: CLI UX 흐름 기반 (정보 → 레이아웃 → 창 → 시스템)

번호 매핑이 필요하면 교차 검증 매트릭스 참조.

# 현재 커버리지 (2026-04-13 기준)

## v1 apiTest: 17 정상 + 7 에러 = 24개

| 범위   | 번호    | 내용                                                |
| :----- | :------ | :-------------------------------------------------- |
| 기본   | 00~11   | 전 엔드포인트 기본 호출 (서버루트 `/` 포함)          |
| UI     | 14      | ui-state (API 전용)                                 |
| CLI    | 15~17   | cli-status, cli-version, cli-quit                   |
| 시스템 | 18      | accessibility                                       |
| 에러   | E01~E07 | 404(3), 400(3), invalid-endpoint(1)                 |

## v2 apiTest: 19 정상 + 2 에러 = 21개

| 범위              | 번호    | 내용                                                          |
| :---------------- | :------ | :------------------------------------------------------------ |
| Health            | 00      | health (v1 공용)                                              |
| Settings GET      | 01~07   | settings 전체 + 각 섹션(general/restore/api/advanced/excluded-apps/shortcuts) |
| Settings PATCH    | 08~12   | general/restore/advanced/settings/api 부분 수정               |
| Excluded Apps     | 13~16   | put(전체교체)/post(추가)/delete(삭제)/reset(기본값)            |
| Shortcuts/Reset   | 17~18   | shortcuts put, factory-reset                                  |
| 에러              | E01~E02 | factory-reset(confirm 누락), api-invalid-port(범위 초과)       |

## cmdTest: 18 정상 + 7 에러 = 25개

| 범위     | 번호    | 내용                                      |
| :------- | :------ | :---------------------------------------- |
| 정보     | 00~04   | help, version, status, health, settings   |
| 레이아웃 | 05~12   | capture, list, show, rename, delete, restore, remove-windows, delete-all |
| 창 정보  | 13~15   | windows, windows-filter, apps             |
| 시스템   | 16~17   | accessibility, quit                       |
| 에러     | E01~E07 | 미알 커맨드(1), 인자 누락(2), 404(1), confirm 누락(2), 데몬 미실행(1) |

# 발견된 이슈 및 제약사항

| 이슈                                    | 상태      | 비고                                               |
| :-------------------------------------- | :-------- | :------------------------------------------------- |
| API/CLI 기본 레이아웃 이름 통일 완료    | 해결      | API/CLI 모두 `default` 사용 (Issue14)              |
| 존재하지 않는 레이아웃 삭제 시 에러 형식 | 이슈후보  | 404 아닌 일반 error, 한/영 메시지 혼재             |
| 기본 레이아웃 관리 API 부재             | 이슈후보  | 명시적 default-layout 설정/조회 없음                |
| restore optional 파라미터 미테스트      | 미커버    | maxRetries 등 커스텀 값 검증 미흡                   |
| ui-state selectApps 미테스트            | 미커버    | `all`, `none`, `top:N`, 배열 형식 미검증           |

# API 업그레이드 시 추가 예정 엔드포인트

| Method | Endpoint                      | 설명                | 우선도 | 테스트 영향                       |
| :----- | :---------------------------- | :------------------ | :----- | :-------------------------------- |
| PUT    | `/api/v1/settings/default-layout` | 기본 레이아웃 설정 | 중     | 시나리오 테스트 확장 가능          |
| GET    | `/api/v1/layouts/{name}/screens` | 스크린별 창 그룹핑 | 낮     | 멀티 디스플레이 검증 확장          |

# 체크리스트 (API 업그레이드 시)

* [ ] openapi_v1.yaml 또는 openapi_v2.yaml에 엔드포인트 추가/수정
* [ ] RESTServer.swift에 라우팅 + 핸들러 구현
* [ ] SettingsService.swift에 비즈니스 로직 추가 (v2 설정 관련 시)
* [ ] CLIHandler.swift에 대응 커맨드 추가 (API 전용이 아닌 경우)
* [ ] apiTest에 테스트 스크립트 추가 (필수 + optional 파라미터 모두 커버)
* [ ] cmdTest에 테스트 스크립트 추가 (CLI 대응 시)
* [ ] 에러 케이스 테스트 추가 (E prefix)
* [ ] apiTest_plan_v1.md 또는 apiTest_plan_v2.md 업데이트
* [ ] cmdTest_plan.md 업데이트
* [ ] 교차 검증 매트릭스 업데이트 (이 문서)
* [ ] 시나리오 테스트 실행 및 PASS 확인
* [ ] 리포트 생성 (`cli/_doc_work/report/`)

# 관련 문서

| 문서                                            | 역할                        |
| :---------------------------------------------- | :-------------------------- |
| `api/openapi_v1.yaml`                           | v1 API 명세 (SSOT)          |
| `api/openapi_v2.yaml`                           | v2 API 명세 (SSOT)          |
| `cli/_tool/apiTest/apiTest_plan_v1.md`          | v1 apiTest 스크립트 목록/매핑 |
| `cli/_tool/apiTest/apiTest_plan_v2.md`          | v2 apiTest 스크립트 목록/매핑 |
| `cli/_tool/cmdTest/cmdTest_plan.md`             | cmdTest 스크립트 목록/매핑  |
| `cli/_doc_work/report/check_api_cmd_report.md`  | 시나리오 검증 리포트        |
| `cli/_doc_design/cmd_design.md`                 | CLI 커맨드 설계             |
| `.claude/rules/api-rules.md`                    | API 동기화 규칙             |
