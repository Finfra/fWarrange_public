---
title: paidApp REST API v2 설계 문서
description: cliApp REST API v2 서버 설계 및 엔드포인트 명세 (v1 슈퍼셋)
date: 2026-04-18
---

# 1. 개요

cliApp의 REST API v2는 v1의 완전한 슈퍼셋이다. GUI(paidApp)가 `/changes` 폴링으로 상태를 동기화하고, 설정을 탭 단위로 세분화하여 CRUD 할 수 있도록 확장했다. 모든 v1 엔드포인트는 `/api/v2/*`에서 동일하게 동작한다.

* **프레임워크**: `Network.framework` (`NWListener` + `NWConnection`) — 외부 의존성 없음
* **서비스 루트**: `http://localhost:3016/api/v2`
* **API 스펙**: [`api/openapi_v2.yaml`](../../api/openapi_v2.yaml)
* **이전 버전**: [`RestAPI_v1.md`](./RestAPI_v1.md) — 레거시 유지, 향후 제거 예정

## 설계 원칙

| 원칙                       | 설명                                                   |
| -------------------------- | ------------------------------------------------------ |
| v1 슈퍼셋                  | v2는 v1의 모든 엔드포인트를 포함하며 추가 기능 제공    |
| 탭 단위 세분화 Settings    | General/Restore/API/Advanced 별 GET/PATCH 분리          |
| 명시적 변경 알림           | `/changes` (adaptive polling) 단일 채널 제공           |
| Manager 계층 직접 호출     | REST 핸들러 → Manager → Service 흐름 유지              |
| 설정 전체 PATCH 허용       | `/settings`에서 임의 필드 부분 갱신                     |

---

# 2. 아키텍처

```
paidApp (Sandbox GUI)                   cliApp (Non-Sandbox Daemon)
    RESTCLIClient ──── HTTP/JSON ─────►  RESTServer (NWListener)
    CLIHealthMonitor                      ├─ HTTP 파싱
    LayoutListView / SettingsSheet        ├─ 라우팅 (/api/v1 + /api/v2)
                                          └─ ChangeTracker (seq 링버퍼)
                                                 │ 직접 호출
                                     ┌───────────┼───────────┐
                                     ▼           ▼           ▼
                              WindowManager  LayoutManager  ModeManager
                                     ↓           ↓           ↓
                              Service Layer (프로토콜 + 구현체)
                                     ↓
                              macOS API (CoreGraphics, Accessibility)
```

---

# 3. v1 대비 변경 요약

## 3.1 추가된 태그/엔드포인트

| 태그      | 추가 엔드포인트                                          |
| --------- | -------------------------------------------------------- |
| Changes   | `GET /changes?since={seq}` (adaptive polling)            |
| Settings  | `/settings/general`, `/restore`, `/api`, `/advanced` 탭 |
| Settings  | `/settings/restore/excluded-apps` GET/PUT/POST/DELETE    |
| Settings  | `/settings/restore/excluded-apps/reset`                  |
| Settings  | `/settings/factory-reset` (X-Confirm 필요)               |
| Shortcuts | `/settings/shortcuts` GET/PUT                            |
| Layouts   | `DELETE /layouts` (전체 삭제, 확인 헤더)                 |
| CLI       | `POST /cli/quit` (X-Confirm 필요)                        |
| Modes     | `/modes`, `/modes/{name}`, `/modes/{name}/activate` (Phase 2) |

## 3.2 제거/대체

| v1                                        | v2 대체                                           |
| ----------------------------------------- | ------------------------------------------------- |
| `GET /locale`, `PUT /locale`              | `/settings/general` (`appLanguage` 필드)          |
| `GET /` (Health)                          | `GET /health`                                     |

---

# 4. 엔드포인트 요약

> 상세 스펙은 [`openapi_v2.yaml`](../_public/api/openapi_v2.yaml) 참조

## 4.1 Health / Changes

| Method | Path        | 설명                                      |
| ------ | ----------- | ----------------------------------------- |
| GET    | `/health`   | Health Check                              |
| GET    | `/changes`  | 변경 시퀀스 조회 (adaptive polling)       |

## 4.2 Settings (전체)

| Method | Path                                       | 설명                               |
| ------ | ------------------------------------------ | ---------------------------------- |
| GET    | `/settings`                                | 전체 설정 스냅샷                   |
| PATCH  | `/settings`                                | 임의 필드 부분 갱신                |
| POST   | `/settings/factory-reset`                  | 전체 기본값 복원 (X-Confirm 필요)  |

## 4.3 Settings (탭별)

| Method | Path                                            | 설명                                 |
| ------ | ----------------------------------------------- | ------------------------------------ |
| GET    | `/settings/general`                             | General 탭 조회                      |
| PATCH  | `/settings/general`                             | 언어/저장 모드/경로/로그인/테마 변경 |
| GET    | `/settings/restore`                             | Restore 탭 조회                      |
| PATCH  | `/settings/restore`                             | 재시도/매칭 임계값 변경              |
| GET    | `/settings/restore/excluded-apps`               | 제외 앱 목록                         |
| PUT    | `/settings/restore/excluded-apps`               | 제외 앱 전체 교체                    |
| POST   | `/settings/restore/excluded-apps`               | 제외 앱 추가                         |
| DELETE | `/settings/restore/excluded-apps`               | 제외 앱 제거                         |
| POST   | `/settings/restore/excluded-apps/reset`         | 제외 앱 기본값 복원                  |
| GET    | `/settings/api`                                 | REST 서버 설정 조회                  |
| PATCH  | `/settings/api`                                 | 포트/외부접속/CIDR/활성화 변경       |
| GET    | `/settings/advanced`                            | Advanced 탭 조회                     |
| PATCH  | `/settings/advanced`                            | 로그레벨/자동저장/UI 옵션 변경       |

## 4.4 Shortcuts

| Method | Path                    | 설명                 |
| ------ | ----------------------- | -------------------- |
| GET    | `/settings/shortcuts`   | 현재 단축키 표시 문자열 |
| PUT    | `/settings/shortcuts`   | 단축키 슬롯별 업데이트 |

## 4.5 Layouts / Capture / Restore

| Method | Path                                    | 설명                                       |
| ------ | --------------------------------------- | ------------------------------------------ |
| GET    | `/layouts`                              | 레이아웃 목록                              |
| DELETE | `/layouts`                              | 전체 삭제 (`X-Confirm-Delete-All: true`)   |
| GET    | `/layouts/{name}`                       | 레이아웃 상세                              |
| PUT    | `/layouts/{name}`                       | 이름 변경                                  |
| DELETE | `/layouts/{name}`                       | 개별 삭제                                  |
| POST   | `/layouts/{name}/restore`               | 복구 (async)                               |
| POST   | `/layouts/{name}/windows/remove`        | 특정 창 제거                               |
| POST   | `/capture`                              | 현재 창 캡처 후 저장                       |

## 4.6 Windows / UI / System / CLI

| Method | Path                         | 설명                               |
| ------ | ---------------------------- | ---------------------------------- |
| GET    | `/windows/current`           | 현재 창 목록 (저장 없이)           |
| GET    | `/windows/apps`              | 실행 중 앱 목록                    |
| PUT    | `/ui/state`                  | UI 상태 변경 (캡처 자동화)         |
| GET    | `/status/accessibility`      | 접근성 권한 상태                   |
| GET    | `/cli/status`                | CLI 헬퍼 상태                      |
| GET    | `/cli/version`               | CLI 헬퍼 버전                      |
| POST   | `/cli/quit`                  | CLI 종료 (`X-Confirm: true`)       |

## 4.7 Modes (Phase 2 — 컨텍스트 스위칭)

| Method | Path                            | 설명                                         |
| ------ | ------------------------------- | -------------------------------------------- |
| GET    | `/modes`                        | 모드 목록 + 현재 활성 모드                   |
| POST   | `/modes`                        | 새 모드 생성                                 |
| GET    | `/modes/{name}`                 | 모드 상세                                    |
| PATCH  | `/modes/{name}`                 | 부분 업데이트                                |
| DELETE | `/modes/{name}`                 | 모드 삭제                                    |
| POST   | `/modes/{name}/activate`        | 활성화 (레이아웃 복구 + 필수 앱 실행)        |

---

# 5. 이벤트 모델

## 5.1 변경 유형

`layout.created`, `layout.updated`, `layout.deleted`, `settings.changed`, `shortcuts.changed`

## 5.2 Polling (`/changes`)

GUI가 주기적으로 당기는 단일 변경 알림 채널. 단조 증가 `seq`, CLI 재시작 시 0으로 초기화(→ 전체 재로드 신호), 최대 100건 링버퍼 유지.

> **이력**: 초기 설계에는 `/events` SSE 푸시 채널이 함께 정의되어 있었으나(Issue220, 2026-04-26), 양측 사용처 0건 + `/changes` 폴링으로 동일 역할 충족 + cliApp 메뉴바 데몬에서의 long-lived connection 운영 비용을 사유로 스펙 제거되었음. 변경 알림은 `/changes` 단일 채널로 일원화함.

```bash
curl "http://localhost:3016/api/v2/changes?since=42"
```
```json
{
  "currentSeq": 47,
  "changes": [
    {"seq": 43, "type": "layout.created", "target": "my-layout", "timestamp": "..."},
    {"seq": 44, "type": "settings.changed", "target": "advanced", "timestamp": "..."}
  ]
}
```

GUI 권장 주기: **활성 3초 / 비활성 30초**. `currentSeq < lastKnownSeq` 시 CLI 재시작으로 판단하여 전체 재로드.

---

# 6. 핵심 Example (curl)

> 기본 포트: `3016`, 서버 활성화 필요 (설정 → API 탭)

## Health Check

```bash
curl http://localhost:3016/api/v2/health
```
```json
{"status":"ok","app":"fWarrangeCli","version":"2.0","port":3016}
```

## 전체 설정 조회 / 부분 갱신

```bash
curl http://localhost:3016/api/v2/settings
curl -X PATCH http://localhost:3016/api/v2/settings \
  -H "Content-Type: application/json" \
  -d '{"logLevel":5,"autoSaveOnSleep":true}'
```

## General 탭 갱신

```bash
curl -X PATCH http://localhost:3016/api/v2/settings/general \
  -H "Content-Type: application/json" \
  -d '{"appLanguage":"ko","theme":"system","launchAtLogin":true}'
```

## Restore 탭 + 제외 앱

```bash
curl http://localhost:3016/api/v2/settings/restore
curl http://localhost:3016/api/v2/settings/restore/excluded-apps

# 추가
curl -X POST http://localhost:3016/api/v2/settings/restore/excluded-apps \
  -H "Content-Type: application/json" -d '{"apps":["Xcode"]}'

# 기본값 복원
curl -X POST http://localhost:3016/api/v2/settings/restore/excluded-apps/reset
```

## API 탭 (서버 설정)

```bash
curl -X PATCH http://localhost:3016/api/v2/settings/api \
  -H "Content-Type: application/json" \
  -d '{"restServerPort":3016,"allowExternalAccess":false,"allowedCIDR":"192.168.0.0/16"}'
```

## Factory Reset

```bash
curl -X POST http://localhost:3016/api/v2/settings/factory-reset \
  -H "X-Confirm: true"
```

## Shortcuts

```bash
curl -X PUT http://localhost:3016/api/v2/settings/shortcuts \
  -H "Content-Type: application/json" \
  -d '{"saveShortcut":"⌘⌥S","restoreDefaultShortcut":"⌘⌥R"}'
```

## Capture / Restore (v1 동일)

```bash
curl -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"myLayout","filterApps":["Safari","iTerm2"]}'

curl -X POST http://localhost:3016/api/v2/layouts/myLayout/restore \
  -H "Content-Type: application/json" \
  -d '{"maxRetries":3,"retryInterval":1.0,"minimumScore":50,"enableParallel":true}'
```

## Layouts 전체 삭제 (확인 헤더 필수)

```bash
curl -X DELETE http://localhost:3016/api/v2/layouts \
  -H "X-Confirm-Delete-All: true"
```

## CLI 종료

```bash
curl -X POST http://localhost:3016/api/v2/cli/quit \
  -H "X-Confirm: true"
```

## Modes (Phase 2)

```bash
# 모드 목록
curl http://localhost:3016/api/v2/modes

# 모드 생성
curl -X POST http://localhost:3016/api/v2/modes \
  -H "Content-Type: application/json" \
  -d '{"name":"Work","icon":"briefcase","shortcut":"⌘⌥1","layout":"workSetup","requiredApps":[{"bundleId":"com.apple.Safari","action":"launch"}]}'

# 모드 활성화
curl -X POST http://localhost:3016/api/v2/modes/Work/activate
```

---

# 7. 데이터 모델 핵심

## 7.1 FullSettings (PATCH 가능 전 필드)

```
appLanguage, dataStorageMode (host|share), dataDirectoryPath,
launchAtLogin, theme (system|light|dark),
maxRetries, retryInterval, minimumMatchScore, enableParallelRestore, excludedApps[],
restServerEnabled, restServerPort, allowExternalAccess, allowedCIDR,
logLevel, autoSaveOnSleep, maxAutoSaves,
restoreButtonStyle (iconOnly|nameIcon|nameOnly),
confirmBeforeDelete, showInCmdTab, clickSwitchToMain, defaultLayoutName
```

## 7.2 ModeInfo

```
name, icon (SF Symbol), shortcut, layoutRef,
requiredApps: [{ bundleId, action(launch|hide|ignore) }]
```

## 7.3 WindowMatchResult

```
app, window, matchedTitle,
matchType: ID | Title(Exact) | Regex | Title(Contains) | Width | Height | Ratio | Area | None,
score (0-100), success
```

---

# 8. 보안

| 모드         | 바인딩         | 접근 제어          |
| ------------ | -------------- | ------------------ |
| 기본 (외부 ⨯) | `127.0.0.1`    | 로컬만             |
| 외부 허용    | `0.0.0.0`      | CIDR 화이트리스트  |

* API 기본 **꺼짐**, 사용자가 `/settings/api` PATCH 또는 GUI에서 수동 활성화
* `127.0.0.1`은 항상 허용
* 비허용 IP → `403 Forbidden`
* 기본 CIDR: `192.168.0.0/16`
* `factory-reset`, `cli/quit`, `layouts` 전체 삭제는 **확인 헤더(X-Confirm / X-Confirm-Delete-All)** 필수

---

# 9. 구현 파일

## cliApp (서버)

| 파일                                                  | 역할                          |
| ----------------------------------------------------- | ----------------------------- |
| `cli/fWarrangeCli/Services/RESTServer.swift`          | NWListener, 라우팅 (v1 + v2)  |
| `cli/fWarrangeCli/Services/ChangeTracker.swift`       | 변경 seq 링버퍼               |
| `cli/fWarrangeCli/Managers/ModeManager.swift`         | 모드 CRUD + 활성화            |
| `cli/fWarrangeCli/Models/Mode.swift`, `AppConfig.swift` | 모드 도메인 모델              |

## paidApp (클라이언트)

| 파일                                                 | 역할                          |
| ---------------------------------------------------- | ----------------------------- |
| `fWarrange/fWarrange/Services/RESTCLIClient.swift`   | v2 엔드포인트 호출            |
| `fWarrange/fWarrange/Services/CLIHealthMonitor.swift` | `/health` 폴링 (5s)           |
| `fWarrange/fWarrange/Services/ChangePoller.swift`    | `/changes` 폴링 (3s/30s)      |
| `fWarrange/fWarrange/Views/ModeListView.swift`       | 모드 GUI                      |

---

# 10. 버전 전환 정책

* v1과 v2는 병행 제공. 동일 요청이 `/api/v1/*` 또는 `/api/v2/*` 양쪽에서 동작
* 신규 기능(Settings 세분화, Changes, Modes)은 v2 전용
* v1은 **deprecated**. 제거 시점은 GUI 마이그레이션 완료 후 별도 공지
* 외부 자동화/통합은 가급적 v2를 사용할 것
