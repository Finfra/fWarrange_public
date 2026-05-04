---
title: paidApp REST API 설계 문서
description: paidApp 내장 REST API 서버 설계 및 엔드포인트 명세
date: 2026-03-26
---

# 1. 개요

paidApp에 내장 REST API 서버를 추가하여 외부 클라이언트(CLI, 자동화 스크립트, 다른 앱)에서 **설정을 제외한 모든 핵심 기능**을 원격 호출할 수 있도록 합니다.

* **프레임워크**: `Network.framework` (`NWListener` + `NWConnection`) — 외부 의존성 없음
* **참조 구현**: fQRGen 프로젝트의 `RESTServer.swift`
* **API 스펙**: [`api/openapi.yaml`](../../api/openapi.yaml)

## 설계 원칙

| 원칙               | 설명                                 |
| ---------------- | ---------------------------------- |
| Manager 계층 직접 호출 | REST 핸들러 → Manager → Service 흐름 유지 |
| ViewModel 우회     | REST API는 ViewModel을 거치지 않음        |
| 설정 제외            | AppSettings 변경은 GUI 전용             |
| 비동기 지원           | restore는 async → 비블로킹 응답           |

---

# 2. 아키텍처

```
REST Client (curl, Shortcuts, 자동화 스크립트)
    ↓ HTTP (JSON)
┌─────────────────────────────────────┐
│  RESTServer (NWListener)            │  ← 신규 추가
│  ├─ HTTP 파싱 (parseHTTPRequest)    │
│  ├─ 라우팅 (route)                  │
│  └─ JSON 응답 생성                  │
└──────────────┬──────────────────────┘
               │ 직접 호출
    ┌──────────┼──────────┐
    ▼          ▼          ▼
WindowManager  LayoutManager  (기존 Manager)
    ↓          ↓
Service Layer (기존 프로토콜)
    ↓
macOS API (CoreGraphics, Accessibility)
```

---

# 3. RESTServer 클래스 핵심

```swift
@Observable
final class RESTServer {
    var isRunning = false
    var port: UInt16 = 3016
    var allowExternal: Bool = false
    var allowedCIDR: String = "192.168.0.0/16"

    private let windowManager: WindowManager
    private let layoutManager: LayoutManager
    private let settingsService: SettingsService
    private var listener: NWListener?

    func start(port: UInt16? = nil) { ... }
    func stop() { ... }
}
```

**의존성 조립** (`fWarrangeApp.swift`):
```swift
let restServer = RESTServer(
    windowManager: windowManager,
    layoutManager: layoutManager,
    settingsService: settingsService
)
```

---

# 4. 엔드포인트 요약

> 상세 스펙은 [`openapi.yaml`](../../api/openapi.yaml) 참조

| Method   | Path                                    | 설명                                |
| -------- | --------------------------------------- | --------------------------------- |
| `GET`    | `/`                                     | Health Check                      |
| `GET`    | `/api/v1/layouts`                       | 레이아웃 목록                           |
| `GET`    | `/api/v1/layouts/{name}`                | 레이아웃 상세                           |
| `POST`   | `/api/v1/capture`                       | 창 캡처 후 저장                         |
| `POST`   | `/api/v1/layouts/{name}/restore`        | 레이아웃 복구 (async)                   |
| `PUT`    | `/api/v1/layouts/{name}`                | 이름 변경                             |
| `DELETE` | `/api/v1/layouts/{name}`                | 삭제                                |
| `DELETE` | `/api/v1/layouts`                       | 전체 삭제 (`X-Confirm-Delete-All` 필요) |
| `POST`   | `/api/v1/layouts/{name}/windows/remove` | 특정 창 제거                           |
| `GET`    | `/api/v1/windows/current`               | 현재 창 목록 (저장 없이)                   |
| `GET`    | `/api/v1/windows/apps`                  | 실행 중 앱 목록                         |
| `GET`    | `/api/v1/status/accessibility`          | 권한 상태                             |
| `GET`    | `/api/v1/locale`                        | 현재 언어 및 지원 언어 목록                  |
| `PUT`    | `/api/v1/locale`                        | 앱 언어 변경 (재시작 필요)                  |

---

# 5. 핵심 Example (curl)

> 기본 포트: `3016`, 서버 활성화 필요 (설정 → API 탭)

## Health Check

```bash
curl http://localhost:3016/
```
```json
{"status":"ok","app":"fWarrange","version":"1.08","port":3016}
```

## 창 캡처 및 저장

```bash
# 전체 창 캡처 (이름 자동)
curl -X POST http://localhost:3016/api/v1/capture

# 이름 지정 + 특정 앱만 캡처
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"myLayout","filterApps":["Safari","iTerm2"]}'
```
```json
{"status":"ok","data":{"name":"myLayout","windowCount":5,"windows":[...]}}
```

# 레이아웃 목록 조회

```bash
curl http://localhost:3016/api/v1/layouts
```
```json
{"status":"ok","data":[{"name":"myLayout","windowCount":12,"fileDate":"2026-03-17T10:30:00Z"},{"name":"workSetup","windowCount":8,"fileDate":"2026-03-16T09:00:00Z"}]}
```

## 레이아웃 상세 조회

```bash
curl http://localhost:3016/api/v1/layouts/myLayout
```
```json
{"status":"ok","data":{"name":"myLayout","windowCount":12,"fileDate":"2026-03-17T10:30:00Z","windows":[{"id":14205,"app":"Safari","window":"Start Page","layer":0,"pos":{"x":-1707,"y":99},"size":{"width":1707,"height":1280}},...]}}
```

## 레이아웃 복구

```bash
# 기본 설정으로 복구
curl -X POST http://localhost:3016/api/v1/layouts/myLayout/restore

# 커스텀 설정
curl -X POST http://localhost:3016/api/v1/layouts/myLayout/restore \
  -H "Content-Type: application/json" \
  -d '{"maxRetries":3,"retryInterval":1.0,"minimumScore":50,"enableParallel":true}'
```
```json
{"status":"ok","data":{"total":12,"succeeded":11,"failed":1,"results":[]}}
```

# 레이아웃 이름 변경

```bash
curl -X PUT http://localhost:3016/api/v1/layouts/myLayout \
  -H "Content-Type: application/json" \
  -d '{"newName":"workSetup-v2"}'
```
```json
{"status":"ok","data":{"oldName":"myLayout","newName":"workSetup-v2"}}
```

## 레이아웃 삭제

```bash
# 단일 삭제
curl -X DELETE http://localhost:3016/api/v1/layouts/workSetup-v2

# 전체 삭제 (확인 헤더 필수)
curl -X DELETE http://localhost:3016/api/v1/layouts \
  -H "X-Confirm-Delete-All: true"
```
```json
{"status":"ok","data":{"deleted":"workSetup-v2"}}
```

# 특정 창 제거

```bash
curl -X POST http://localhost:3016/api/v1/layouts/myLayout/windows/remove \
  -H "Content-Type: application/json" \
  -d '{"windowIds":[14205,5032]}'
```
```json
{"status":"ok","data":{"layout":"myLayout","removedCount":2,"remainingCount":10}}
```

## 현재 창 목록 (저장 없이)

```bash
# 전체
curl http://localhost:3016/api/v1/windows/current

# 특정 앱만 필터
curl "http://localhost:3016/api/v1/windows/current?filterApps=Safari,iTerm2"
```
```json
{"status":"ok","data":{"windowCount":3,"windows":[...]}}
```

# 실행 중 앱 목록

```bash
curl http://localhost:3016/api/v1/windows/apps
```
```json
{"status":"ok","data":{"apps":["Safari","iTerm2","Xcode","Finder","Slack"]}}
```

## Accessibility 권한 상태

```bash
curl http://localhost:3016/api/v1/status/accessibility
```
```json
{"status":"ok","data":{"granted":true}}
```

## 언어 조회 및 변경

```bash
# 현재 언어 + 지원 언어 목록
curl http://localhost:3016/api/v1/locale
```
```json
{"status":"ok","data":{"current":"ko","supported":["system","ko","en","ja","ar","zh-Hans","zh-Hant","fr","de","hi","es"]}}
```

```bash
# 언어 변경 (앱 재시작 필요)
curl -X PUT http://localhost:3016/api/v1/locale \
  -H "Content-Type: application/json" \
  -d '{"language":"en"}'
```
```json
{"status":"ok","data":{"language":"en","restartRequired":true}}
```

# 에러 응답 예시

```bash
# 존재하지 않는 레이아웃
curl http://localhost:3016/api/v1/layouts/nonexistent
```
```json
{"status":"error","error":"Layout 'nonexistent' not found"}
```

```bash
# 전체 삭제 헤더 누락
curl -X DELETE http://localhost:3016/api/v1/layouts
```
```json
{"status":"error","error":"X-Confirm-Delete-All: true 헤더가 필요합니다"}
```

---

# 6. UI 연동 (Notification 패턴)


REST 요청 완료 시 Notification을 발행하여 앱 UI를 자동 갱신합니다.

| Notification           | 발생 시점    | UI 반응     |
| ---------------------- | -------- | --------- |
| `RESTCaptureCompleted` | 캡처 저장 완료 | 목록 새로고침   |
| `RESTRestoreCompleted` | 복구 완료    | 상태 메시지 표시 |
| `RESTLayoutDeleted`    | 삭제 완료    | 목록 새로고침   |
| `RESTLayoutRenamed`    | 이름 변경 완료 | 목록 새로고침   |

---

# 7. 보안

| 모드         | 바인딩         | 접근 제어       |
| ---------- | ----------- | ----------- |
| 기본 (외부 꺼짐) | `127.0.0.1` | 로컬만         |
| 외부 허용      | `0.0.0.0`   | CIDR 화이트리스트 |

* API 기본 **꺼짐**, 사용자가 설정에서 수동 활성화
* `127.0.0.1`은 항상 허용
* 비허용 IP → `403 Forbidden`
* 기본 CIDR: `192.168.0.0/16`

---

# 8. 설정 항목 (SettingsView)

| 항목       | UserDefaults 키      | 기본값              |
| -------- | ------------------- | ---------------- |
| 서버 활성화   | `restServerEnabled` | `false`          |
| 포트       | `restServerPort`    | `3016`           |
| 외부 접속 허용 | `restAllowExternal` | `false`          |
| 허용 CIDR  | `restAllowedCIDR`   | `192.168.0.0/16` |

---

# 9. 구현 파일

**신규**: `fWarrange/fWarrange/Services/RESTServer.swift`

**수정**:
* `fWarrangeApp.swift` — DI 조립 및 시작
* `MainViewModel.swift` — Notification 수신
* `SettingsView.swift` — REST API 설정 섹션
* `AppSettings.swift` — REST 설정 필드 (선택적)

---

# 10. 구현 순서

1. `RESTServer.swift` 기본 구조 (NWListener, HTTP 파싱, 라우팅)
2. 읽기 전용 엔드포인트 (`GET /`, layouts, windows)
3. 쓰기 엔드포인트 (`POST capture`, `PUT rename`, `DELETE`)
4. 복구 엔드포인트 (`POST restore`) — async 처리
5. UI 연동 (Notification, SettingsView)
6. 테스트 스크립트: `lib/rest/test-api.sh`
