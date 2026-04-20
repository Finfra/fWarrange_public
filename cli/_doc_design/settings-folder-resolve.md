---
name: settings-folder-resolve
description: cliApp 시작 시 데이터 폴더(baseDirectory) 및 레이아웃 저장 경로를 인식·결정하는 절차 설계 문서
date: 2026-04-13
---

# 개요

cliApp은 **앱 시작 시 자신의 데이터 폴더(baseDirectory)가 어디 있는지를 다음 순서로 인식한다**: 환경변수 확인 → 없으면 기본 경로 사용 → DataStorageMode에 따라 레이아웃 저장 서브디렉토리 결정 → 마이그레이션/초기화 → 설정 파일 로드. 이 문서는 그 인식 절차 전체를 기술한다.

# 용어 정의

| 용어              | 의미                                       | 예시                                             |
| :---------------- | :----------------------------------------- | :----------------------------------------------- |
| `baseDirectory`   | 데이터 폴더 루트                           | `~/Documents/finfra/fWarrangeData`               |
| `dataDirectory`   | 레이아웃 YAML 파일이 저장된 폴더           | `{baseDirectory}/{hostname}` 또는 `{baseDirectory}/_share` |
| `_config.yml`     | 앱 설정 파일 (YAML)                        | `{baseDirectory}/_config.yml`                    |
| `DataStorageMode` | 레이아웃 저장 분기 (`.host` / `.share`)    | `host` = 머신별 독립, `share` = 공용             |
| `hostname`        | 현재 머신 이름 (`.local` 접미사 제거)      | `mac-studio`                                     |

# baseDirectory 인식 (우선순위)

앱 시작 시 `YAMLLayoutStorageService.resolveDefaultBaseDirectory()`가 호출되어 baseDirectory를 결정함. 인식 우선순위:

```
1. 환경변수 fWarrangeCli_config  (비어 있지 않을 때)
2. 기본 경로: ~/Documents/finfra/fWarrangeData
```

```swift
// LayoutStorageService.swift:59-69
static func resolveDefaultBaseDirectory() -> URL {
    if let envPath = ProcessInfo.processInfo.environment[envConfigKey], !envPath.isEmpty {
        return URL(fileURLWithPath: (envPath as NSString).expandingTildeInPath)
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/finfra/fWarrangeData")
}
```

> baseDirectory는 `_config.yml`에 저장되지 않는다. `_config.yml`은 baseDirectory 안에 위치하므로 자기참조 불가.

# dataDirectory 분기 (DataStorageMode)

baseDirectory 결정 후, `DataStorageMode` 설정에 따라 실제 레이아웃 YAML을 저장할 `dataDirectory`가 결정됨.

```
DataStorageMode.host  →  {baseDirectory}/{hostname}/   (머신별 독립)
DataStorageMode.share →  {baseDirectory}/_share/       (공용)
```

```swift
// LayoutStorageService.swift:26-32
switch storageMode {
case .host:
    let hostname = Self.currentHostname()
    self.dataDirectory = baseDir.appendingPathComponent(hostname)
case .share:
    self.dataDirectory = baseDir.appendingPathComponent("_share")
}
```

hostname은 `.local` 접미사를 제거한 값을 사용함:
```swift
// LayoutStorageService.swift:49-55
static func currentHostname() -> String {
    let hostname = ProcessInfo.processInfo.hostName
    if hostname.hasSuffix(".local") { return String(hostname.dropLast(6)) }
    return hostname
}
```

# 폴더 구조

```
{baseDirectory}/                    ← 데이터 폴더 루트
├── _config.yml                     ← 앱 설정 파일
├── logs/                           ← 로그 파일 (wlog.log)
├── {hostname}/                     ← host 모드 레이아웃 저장소
│   ├── my-layout.yml
│   └── 2026-04-13-1.yml
└── _share/                         ← share 모드 공용 저장소
    └── *.yml
```

# 마이그레이션 및 초기화 (AppState.init)

앱 시작(`AppState.init()`)에서 host 모드일 때 다음 2가지를 순서대로 실행:

```swift
// AppState.swift:33-36
let storageMode = settings.dataStorageMode ?? .host
if storageMode == .host {
    YAMLLayoutStorageService.migrateRootDataIfNeeded()
    YAMLLayoutStorageService.copyShareDataIfNeeded()
}
```

## migrateRootDataIfNeeded (Issue166_3)

루트에 흩어진 구버전 `.yml` 파일을 `{hostname}/` 폴더로 이동:

```
조건: hostname 폴더가 없고 + baseDirectory 루트에 .yml이 있음
처리: hostname 폴더 생성 → .yml 파일 이동
```

## copyShareDataIfNeeded (Issue166_2)

신규 머신에서 `_share` 데이터를 `{hostname}/`로 복사 (초기 시드):

```
조건: hostname 폴더가 없고 + _share 폴더에 .yml이 있음
처리: hostname 폴더 생성 → _share의 .yml 복사 (원본 유지)
```

# _config.yml 인식 흐름

`AppState.init()`에서 `YAMLSettingsService(baseDirectory: baseDir)`로 생성 후 `load()` 호출:

```
_config.yml 존재?
  YES → YAML 파싱 → AppSettings 로드
  NO  → AppSettings.defaults 반환
        → settingsService.save(settings) 으로 기본값으로 파일 생성
```

```swift
// AppState.swift:27-30
if !FileManager.default.fileExists(atPath: settingsService.configFilePath) {
    settingsService.save(settings)
}
```

> fSnippetCli와 달리 번들에서 복사하지 않고, 하드코딩 기본값(`AppSettings.defaults`)으로 즉시 파일을 생성한다.

# dataDirectoryPath 설정 (API 경로 변경)

`PATCH /api/v2/settings/general`로 `dataDirectoryPath` 필드 변경 가능:

```bash
curl -X PATCH http://localhost:3016/api/v2/settings/general \
  -H "Content-Type: application/json" \
  -d '{"dataStorageMode": "share"}'
```

내부 처리 (`AppState.swift`):
```swift
if let v = body["dataDirectoryPath"] as? String { s.dataDirectoryPath = v.isEmpty ? nil : v }
if body["dataDirectoryPath"] is NSNull          { s.dataDirectoryPath = nil }
```

> `dataStorageMode` 또는 `dataDirectoryPath` 변경 후에는 앱 재시작이 필요하다. `resolveDefaultBaseDirectory()`는 시작 시 1회만 호출되기 때문.

# 로그 경로

`Logger`는 baseDirectory 기준으로 로그 파일 경로를 결정함:

```swift
// AppState.swift:198-199
let home = FileManager.default.homeDirectoryForCurrentUser.path
return "\(home)/Documents/finfra/fWarrangeData/logs/wlog.log"
```

> 현재 환경변수 기반 baseDirectory를 따르지 않고 하드코딩된 경로를 사용한다. 환경변수로 baseDirectory를 변경해도 로그 경로는 고정됨 (개선 여지 있음).

# 관련 클래스

| 클래스                     | 역할                                                              |
| :------------------------- | :---------------------------------------------------------------- |
| `YAMLLayoutStorageService` | baseDirectory 결정, hostname 분기, 마이그레이션/복사, YAML 저장소 |
| `YAMLSettingsService`      | `_config.yml` 읽기/쓰기, AppSettings 직렬화                      |
| `AppSettings`              | `dataStorageMode`, `dataDirectoryPath` 필드 정의                 |
| `AppState`                 | 시작 시 경로 결정 → 마이그레이션 → 설정 로드 흐름 조율           |
| `Logger`                   | 로그 파일 경로 결정 (현재 하드코딩)                              |

# 관련 이슈

| 이슈      | 내용                                               |
| :-------- | :------------------------------------------------- |
| Issue166_2 | host 모드 최초 실행 시 _share에서 데이터 복사     |
| Issue166_3 | 루트 yml → hostname 폴더 마이그레이션             |
| Issue166_4 | hostname 불일치 감지 (`detectHostnameMismatch()`) |
