---
title: fWarrangeCli
description: fWarrange companion helper daemon — 창 캡처/복구를 위한 REST API 서버
date: 2026-04-07
---

[fWarrange](https://github.com/Finfra/fWarrange_public)의 companion helper daemon. 메뉴바 에이전트 앱으로 실행되며, 창 캡처 및 복구를 위한 REST API를 제공함.

fWarrange (App Store 버전)는 Sandbox 규정 준수를 위해 모든 Accessibility API 작업을 이 데몬에 위임함.

# 아키텍처

```
fWarrange (Sandbox, App Store)          fWarrangeCli (Non-Sandbox, Helper)
├── SwiftUI GUI                         ├── RESTServer (port 3016)
├── RESTClient ──── HTTP ─────────────► ├── WindowManager
│   (localhost:3016)                    │   ├── CGWindowCaptureService
│                                       │   └── AXWindowRestoreService
└── SettingsSheet                       ├── LayoutManager (YAML I/O)
                                        ├── HotKeyService (Global Shortcuts)
                                        └── DisplaySwitchService
```

# 요구사항

* macOS 14.0 이상
* Xcode 15.0+ (빌드 시에만 필요)
* Accessibility 권한 부여 필요

# 설치

## Homebrew (권장)

```bash
brew tap finfra/tap
brew install finfra/tap/fwarrange-cli
```

## 소스 빌드

```bash
cd ../cli
xcodebuild -scheme fWarrangeCli -configuration Release build
```

# 서비스 관리

로그인 시 자동 시작은 앱 내 설정(macOS Login Items)으로 관리됨.
Homebrew는 설치만 담당 — `brew services` 불필요.

```bash
# 수동 실행
open /Applications/_nowage_app/fWarrangeCli.app
```

# REST API

* **기본 포트**: `3016`
* **API 버전**: `v2` (현행), `v1` (레거시, 유지)
* **서비스 루트**: `http://localhost:3016/api/v2`
* **OpenAPI 명세**: [`api/openapi_v2.yaml`](../api/openapi_v2.yaml) · [`api/openapi_v1.yaml`](../api/openapi_v1.yaml) (레거시)

## 엔드포인트

모든 경로는 서비스 루트 `/api/v2` 기준. 전체 명세: [`api/openapi_v2.yaml`](../api/openapi_v2.yaml)

### 상태

| Method | Path      | 설명                                       |
| :----- | :-------- | :----------------------------------------- |
| GET    | `/health` | 헬스 체크 (절대 루트 `GET /`에서도 접근 가능) |

### 레이아웃

| Method | Path                             | 설명                             |
| :----- | :------------------------------- | :------------------------------- |
| GET    | `/layouts`                       | 레이아웃 목록                    |
| GET    | `/layouts/{name}`                | 레이아웃 상세                    |
| PUT    | `/layouts/{name}`                | 레이아웃 이름 변경               |
| DELETE | `/layouts/{name}`                | 레이아웃 삭제                    |
| DELETE | `/layouts`                       | 전체 삭제 (X-Confirm-Delete-All 헤더) |
| POST   | `/layouts/{name}/windows/remove` | 특정 창 제거                     |

### 캡처 & 복구

| Method | Path                      | 설명               |
| :----- | :------------------------ | :----------------- |
| POST   | `/capture`                | 창 캡처 및 저장    |
| POST   | `/layouts/{name}/restore` | 레이아웃 복구      |

### 창 정보

| Method | Path               | 설명                            |
| :----- | :----------------- | :------------------------------ |
| GET    | `/windows/current` | 현재 창 목록 (filterApps 쿼리)  |
| GET    | `/windows/apps`    | 실행 중인 앱 목록               |

### 시스템

| Method | Path                    | 설명               |
| :----- | :---------------------- | :----------------- |
| GET    | `/status/accessibility` | Accessibility 권한 |
| GET    | `/locale`               | 현재 언어 조회     |
| PUT    | `/locale`               | 앱 언어 변경       |

### UI

| Method | Path        | 설명                                     |
| :----- | :---------- | :--------------------------------------- |
| PUT    | `/ui/state` | UI 상태 제어 (창 숨기기, 앱 선택 등)     |

### CLI 관리

| Method | Path           | 설명                            |
| :----- | :------------- | :------------------------------ |
| GET    | `/cli/status`  | 데몬 상태 (uptime, 버전, 포트)  |
| GET    | `/cli/version` | 버전 정보                       |
| POST   | `/cli/quit`    | 데몬 종료 (X-Confirm 헤더 필수) |

## 빠른 테스트

```bash
# 헬스 체크
curl http://localhost:3016/

# 현재 창 캡처
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name": "my-layout"}'

# 레이아웃 복구
curl -X POST http://localhost:3016/api/v1/layouts/my-layout/restore

# 상태 확인
curl http://localhost:3016/api/v1/cli/status
```

# 설정

설정은 UserDefaults에 저장됨:

| Key                   | 기본값 | 설명                    |
| :-------------------- | :----- | :---------------------- |
| restServerPort        | 3016   | REST 서버 포트          |
| maxRetries            | 5      | 창 매칭 재시도 횟수     |
| retryInterval         | 0.5    | 재시도 간격 (초)        |
| minimumMatchScore     | 30     | 최소 매칭 점수          |
| enableParallelRestore | true   | 병렬 복구 모드          |
| dataStorageMode       | host   | `host` 또는 `share`     |

# 데이터 디렉토리

레이아웃 파일 (YAML)은 다음 경로에 저장됨:

```
~/Documents/finfra/fWarrangeData/{hostname}/*.yml
```

fWarrange GUI 앱과 공유됨.

# Accessibility 권한

fWarrangeCli는 창 위치를 제어하기 위해 Accessibility 권한이 필요함:

**시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 > fWarrangeCli 추가**

# 라이선스

Copyright (c) Finfra. All rights reserved.
