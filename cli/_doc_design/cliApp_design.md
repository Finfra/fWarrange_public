---
name: cliApp_design
description: cliApp 헬퍼 앱 아키텍처 설계 — Sandbox 우회를 위한 분리 구조
date: 2026-04-26
---

# 배경

paidApp은 타 앱 창 위치/크기를 제어하기 위해 Accessibility API를 사용하며, 이는 App Sandbox와 근본적으로 양립 불가함 (상위 레포 `_doc_work/report/AppStoreFail.md` 참조).

App Store 배포를 위해 **cliApp**(비샌드박스 헬퍼) + **paidApp**(샌드박스 GUI) 2-앱 구조로 전환함.

# 핵심 원칙

* cliApp: **비샌드박스**, Accessibility API 사용, REST API 서버 역할, 창 제어 로직 전담
* paidApp: **샌드박스**, App Store 배포 가능, 순수 GUI 클라이언트, cliApp에 REST로 접근
* REST API 스펙은 `api/openapi_v2.yaml`(현행)이 SSOT. 분리 초기에는 호환성을 위해 v1을 유지했으나, 이후 설정 CRUD·Modes·라이프사이클 알림 등을 추가하며 v2 슈펴셋으로 확장(Issue54로 v2 전환 완료)

# 아키텍처 비교

## AS-IS (단일 앱)

```
paidApp (Non-Sandbox)
├── SwiftUI GUI
├── RESTServer (port 3016)
├── WindowManager → CaptureService / RestoreService (AX API)
├── LayoutManager → YAMLStorageService
└── HotKeyService, DisplaySwitchService ...
```

## TO-BE (2-앱 분리)

```
paidApp (Sandbox, App Store)            cliApp (Non-Sandbox, Helper)
├── SwiftUI GUI                         ├── RESTServer (port 3016)
├── RESTClient → HTTP → ─────────────► ├── WindowManager
│   (localhost:3016)                    │   ├── CGWindowCaptureService
│                                       │   └── AXWindowRestoreService
├── LayoutListView                      ├── LayoutManager
├── SettingsSheet                       │   └── YAMLLayoutStorageService
└── StatusBar                           ├── HotKeyService (글로벌 단축키)
                                        ├── DisplaySwitchService
                                        └── ScreenMoveService
```

# cliApp 상세 설계

## 앱 유형

* **macOS CLI/Agent 앱** (GUI 없음, 메뉴바 아이콘만 표시)
* LSUIElement = YES (Dock에 표시 안 함)
* Login Items로 자동 시작

## 이관 대상 (paidApp → cliApp)

| 컴포넌트                   | 역할                       | 비고                         |
| :------------------------- | :------------------------- | :--------------------------- |
| RESTServer                 | HTTP 서버 (port 3016)      | 그대로 이관                  |
| WindowManager              | 캡처/복원 조율             | 그대로 이관                  |
| CGWindowCaptureService     | 창 정보 수집               | CGWindowList API 사용        |
| AXWindowRestoreService     | 창 위치/크기 변경          | Accessibility API 사용       |
| YAMLLayoutStorageService   | 레이아웃 YAML 파일 I/O     | 데이터 경로 공유             |
| HotKeyService              | 글로벌 단축키              | 비샌드박스에서만 동작        |
| DisplaySwitchService       | 디스플레이 전환 감지       | 그대로 이관                  |
| ScreenMoveService          | 디스플레이 원점 이동       | 그대로 이관                  |
| SystemAccessibilityService | 접근성 권한 확인           | 그대로 이관                  |

## cliApp에 남는 것 (cliApp 고유)

* 메뉴바 상태 아이콘 (실행 중 표시)
* 상태 표시: 연결 수, 마지막 요청 시각
* 종료/재시작 메뉴

## REST API 엔드포인트

스펙 SSOT: `api/openapi_v2.yaml`. 인간 가독 버전: `cli/_doc_design/RestAPI_v2.md`.
기본 prefix는 `/api/v2`이며, v1 직접 호출은 410 Gone(Issue54).

### 기본 / 변경 알림

| Method | Path                          | 설명                                   |
| :----- | :---------------------------- | :------------------------------------- |
| GET    | `/`                           | Health check (root, prefix 없이)       |
| GET    | `/api/v2/health`              | Health check                           |
| GET    | `/api/v2/changes?since={seq}` | 변경 알림 폴링 (단조 증가 seq 링버퍼)  |

### 레이아웃 / 캡처 / 복원

| Method | Path                                            | 설명                          |
| :----- | :---------------------------------------------- | :---------------------------- |
| GET    | `/api/v2/layouts`                               | 레이아웃 목록                 |
| DELETE | `/api/v2/layouts`                               | 모든 레이아웃 삭제            |
| GET    | `/api/v2/layouts/{name}`                        | 레이아웃 상세                 |
| PUT    | `/api/v2/layouts/{name}`                        | 레이아웃 이름 변경            |
| DELETE | `/api/v2/layouts/{name}`                        | 레이아웃 삭제                 |
| POST   | `/api/v2/layouts/{name}/restore`                | 레이아웃 복원                 |
| POST   | `/api/v2/layouts/{name}/windows/remove`         | 레이아웃에서 특정 창 제거     |
| POST   | `/api/v2/capture`                               | 현재 창 캡처 후 저장          |

### 창 / UI 상태

| Method | Path                          | 설명                  |
| :----- | :---------------------------- | :-------------------- |
| GET    | `/api/v2/windows/current`     | 현재 창 목록 (저장 X) |
| GET    | `/api/v2/windows/apps`        | 실행 중 앱 목록       |
| PUT    | `/api/v2/ui/state`            | UI 상태 변경          |
| GET    | `/api/v2/status/accessibility`| 접근성 권한 상태      |

### 설정 (탭 단위 분리, PATCH 부분 갱신)

| Method | Path                                              | 설명                                 |
| :----- | :------------------------------------------------ | :----------------------------------- |
| GET    | `/api/v2/settings`                                | 전체 설정 조회                       |
| PATCH  | `/api/v2/settings`                                | 임의 필드 부분 갱신                  |
| GET    | `/api/v2/settings/general`                        | General 탭 조회                      |
| PATCH  | `/api/v2/settings/general`                        | General 탭 갱신                      |
| GET    | `/api/v2/settings/restore`                        | Restore 탭 조회                      |
| PATCH  | `/api/v2/settings/restore`                        | Restore 탭 갱신                      |
| GET    | `/api/v2/settings/restore/excluded-apps`          | 제외 앱 목록 조회                    |
| PUT    | `/api/v2/settings/restore/excluded-apps`          | 제외 앱 목록 전체 교체               |
| POST   | `/api/v2/settings/restore/excluded-apps`          | 제외 앱 추가                         |
| DELETE | `/api/v2/settings/restore/excluded-apps`          | 제외 앱 제거                         |
| POST   | `/api/v2/settings/restore/excluded-apps/reset`    | 제외 앱 기본값 복원                  |
| GET    | `/api/v2/settings/api`                            | REST API 서버 설정 조회              |
| PATCH  | `/api/v2/settings/api`                            | REST API 서버 설정 갱신              |
| GET    | `/api/v2/settings/advanced`                       | Advanced 탭 조회                     |
| PATCH  | `/api/v2/settings/advanced`                       | Advanced 탭 갱신                     |
| GET    | `/api/v2/settings/shortcuts`                      | 단축키 조회                          |
| PUT    | `/api/v2/settings/shortcuts`                      | 단축키 갱신                          |
| POST   | `/api/v2/settings/factory-reset`                  | 모든 설정 공장 초기화                |

### Modes (컨텍스트 전환, Issue192)

| Method | Path                              | 설명                              |
| :----- | :-------------------------------- | :-------------------------------- |
| GET    | `/api/v2/modes`                   | 모드 목록                         |
| POST   | `/api/v2/modes`                   | 신규 모드 생성                    |
| GET    | `/api/v2/modes/{name}`            | 모드 상세                         |
| PATCH  | `/api/v2/modes/{name}`            | 모드 부분 갱신                    |
| DELETE | `/api/v2/modes/{name}`            | 모드 삭제                         |
| POST   | `/api/v2/modes/{name}/activate`   | 모드 활성화 (레이아웃 복원 + 앱 실행) |

### CLI 자기제어

| Method | Path                  | 설명                                |
| :----- | :-------------------- | :---------------------------------- |
| GET    | `/api/v2/cli/status`  | cliApp 상태 정보                    |
| GET    | `/api/v2/cli/version` | cliApp 버전                         |
| POST   | `/api/v2/cli/quit`    | cliApp 종료                         |
| POST   | `/api/v2/shutdown`    | cliApp 프로세스 종료 (외부 호출용)  |

### paidApp 라이프사이클 알림

| Method | Path                          | 설명                              |
| :----- | :---------------------------- | :-------------------------------- |
| POST   | `/api/v2/paidapp/register`    | paidApp 세션 등록                 |
| POST   | `/api/v2/paidapp/unregister`  | paidApp 세션 해제                 |
| GET    | `/api/v2/paidapp/status`      | paidApp 라이프사이클 상태 스냅샷  |

## Entitlements

```xml
<!-- fWarrangeCli.entitlements -->
<key>com.apple.security.app-sandbox</key>
<false/>
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

# paidApp (GUI) 변경 사항

## 제거 대상

| 컴포넌트                   | 사유                              |
| :------------------------- | :-------------------------------- |
| RESTServer                 | cliApp으로 이관                   |
| CGWindowCaptureService     | REST 호출로 대체                  |
| AXWindowRestoreService     | REST 호출로 대체                  |
| HotKeyService              | cliApp으로 이관                   |
| DisplaySwitchService       | cliApp으로 이관                   |
| ScreenMoveService          | cliApp으로 이관                   |
| `_AXUIElementGetWindow`    | Private API 제거 (App Store 심사) |

## 추가 대상

| 컴포넌트          | 역할                                            |
| :---------------- | :---------------------------------------------- |
| RESTClient        | cliApp REST API 호출 (URLSession 기반)        |
| CLIHealthMonitor | cliApp 연결 상태 모니터링 (주기적 poll)        |
| CLIAutoLauncher  | cliApp 미실행 시 자동 시작                    |

## 설정 UI 변경 (API 탭)

기존 `RESTServerSettingsView`(탭 3: API)를 cliApp 연결 설정 UI로 전환함.
기존에는 내장 RESTServer 활성화/포트/외부접속을 직접 제어했으나, TO-BE에서는 cliApp 헬퍼의 상태 확인 + 포트 설정 역할로 변경.

### AS-IS (내장 REST 서버 제어)

```
┌─ API ──────────────────────────────────┐
│ [x] REST API 서버 활성화               │
│ 상태: 🟢 실행 중                       │
│ 포트: [3016] (변경 시 서버 재시작 필요) │
│ 외부 접속: [ ] 허용                    │
│ 허용 대역: [192.168.0.0/16]           │
│ 테스트: curl http://localhost:3016/    │
└────────────────────────────────────────┘
```

### TO-BE (cliApp 연결 관리)

```
┌─ API ──────────────────────────────────────────┐
│ fWarrange Base 연결                            │
│                                                │
│ 상태: 🟢 연결됨 (v1.0.0, uptime 2h 30m)      │
│   또는 🔴 연결 안 됨                           │
│                                                │
│ 포트:   [3016] (변경 시 앱 재시작 필요)        │
│                                                │
│ ──────────────────────────────────             │
│ [fWarrange Base 미설치 시]                     │
│ ⚠️ fWarrange Base가 필요합니다                 │
│ 설치: brew install finfra/tap/fwarrange-cli   │
│                             [복사] [설치 안내] │
│                                                │
│ ──────────────────────────────────             │
│ 테스트: curl http://localhost:3016/            │
└────────────────────────────────────────────────┘
```

### UI 구성 요소

| 요소               | 설명                                                     |
| :----------------- | :------------------------------------------------------- |
| 상태 표시          | `GET /` health check 결과 — 🟢연결됨 / 🔴연결 안 됨     |
| 버전 표시          | `GET /api/v2/cli/version` 응답값 표시                   |
| 포트 설정          | AppSettings.restServerPort (기본 3016), RESTClient에 반영 |
| Brew 설치 안내     | cliApp 미감지 시 설치 명령어 + 복사 버튼               |
| 설치 안내 버튼     | GitHub 릴리즈 페이지 또는 Homebrew 안내 링크             |
| 테스트 curl        | 현재 포트 기반 curl 명령 표시 (텍스트 선택 가능)         |

## Entitlements (Sandbox 활성화)

```xml
<!-- fWarrange.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

* `network.server` 불필요 — 서버 역할은 cliApp이 담당
* `network.client`만 필요 — localhost REST 호출

## RESTClient 설계

```swift
protocol CLIAPIClient {
    func getLayouts() async throws -> [LayoutMetadata]
    func getLayout(name: String) async throws -> Layout
    func capture(name: String?) async throws -> Layout
    func restore(name: String) async throws -> RestoreStatus
    func getCurrentWindows() async throws -> [WindowInfo]
    func getAccessibilityStatus() async throws -> Bool
    func getCLIStatus() async throws -> CLIStatus
}

final class RESTCLIClient: CLIAPIClient {
    private let baseURL: URL  // http://127.0.0.1:3016
    private let session: URLSession

    // 모든 메서드는 URLSession 기반 HTTP 호출
}
```

## 기존 Manager → RESTClient 전환

```
AS-IS: MainViewModel → WindowManager → CaptureService (직접 AX API 호출)
TO-BE: MainViewModel → RESTCLIClient → HTTP → cliApp REST API
```

* MainViewModel의 public 인터페이스는 최대한 유지
* 내부 구현만 Manager 직접 호출 → REST 호출로 교체

# 데이터 경로 공유

두 앱이 동일한 데이터 디렉토리를 참조해야 함:

* **기본 경로**: `~/Documents/finfra/fWarrangeData/`
* **레이아웃 파일**: `~/Documents/finfra/fWarrangeData/{hostname}/*.yml`
* **lib 스크립트 데이터**: `lib/wArrange_core/data/*.yml`

Sandbox 앱에서 `~/Documents/` 접근:
* `com.apple.security.files.user-selected.read-write` entitlement로 가능
* 또는 App Group 컨테이너 사용 (향후 검토)

# 통신 프로토콜

* **전송**: HTTP/1.1 over TCP (localhost:3016)
* **포맷**: JSON (기존 API와 동일)
* **인증**: 없음 (localhost only)
* **타임아웃**: 연결 5초, 요청 30초
* **재시도**: 연결 실패 시 3회 재시도 (1초 간격)

# 배포 전략

| 앱              | 배포 방식          | Sandbox | 비고                     |
| :-------------- | :----------------- | :------ | :----------------------- |
| paidApp         | App Store          | Yes     | GUI 클라이언트           |
| cliApp          | Homebrew (주력)    | No      | `brew install` 설치      |

* paidApp 첫 실행 시 cliApp 미설치 안내 + brew 명령어 제공
* cliApp은 Login Items 등록으로 자동 시작

## cliApp 소스코드 위치

* **소스**: `cli/fWarrangeCli/` (공개 레포 `Finfra/fWarrange_public` 내)
* **Homebrew Formula**: `cli/Formula/fwarrange-cli.rb`
* 공개 레포에서 빌드 + 배포, 메인 레포에서 이슈 관리

## Homebrew 배포

```bash
# Tap 등록 (최초 1회)
brew tap finfra/tap

# 설치
brew install finfra/tap/fwarrange-cli

# 서비스 등록 (Login Items 대체)
brew services start fwarrange-cli
```

### Formula 구조

```ruby
class FwarrangeCli < Formula
  desc "Window arrangement helper daemon for fWarrange"
  homepage "https://github.com/Finfra/fWarrange_public"
  url "https://github.com/Finfra/fWarrange_public/archive/refs/tags/cli-v1.0.0.tar.gz"
  sha256 "..."

  depends_on :macos
  depends_on xcode: ["15.0", :build]

  def install
    system "xcodebuild", "-project", "fWarrangeCli/fWarrangeCli.xcodeproj",
           "-scheme", "fWarrangeCli",
           "-configuration", "Release",
           "-derivedDataPath", buildpath/"build",
           "SYMROOT=#{buildpath}/build"
    prefix.install Dir["build/Release/fWarrangeCli.app"]
  end

  service do
    run "#{prefix}/fWarrangeCli.app/Contents/MacOS/fWarrangeCli"
    keep_alive true
    log_path "#{var}/log/fwarrange-cli.log"
  end
end
```

### 릴리즈 태그 규칙

* cliApp 전용 태그: `cli-v{MAJOR}.{MINOR}.{PATCH}`
* ex) `cli-v1.0.0`, `cli-v1.1.0`

# lib/wArrange_core 스크립트 관계

기존 Swift 스크립트(`saveWindowsInfo.swift`, `setWindows.swift`)는 cliApp이 내부적으로 활용하거나, 독립 CLI 도구로 유지:

* cliApp의 Service 계층이 동일 로직을 Swift 코드로 내장
* lib 스크립트는 CLI 독립 사용 + 디버깅 용도로 유지

# 향후 고려사항

* **XPC 전환**: REST 대신 XPC로 전환 시 보안 강화 가능 (Apple 공식 IPC). 단, 구현 복잡도 증가
* **SMAppService**: macOS 13+ Login Items 등록 API로 cliApp 자동 시작 관리
* **Privileged Helper Tool**: 필요시 launchd 기반 헬퍼로 전환 가능
