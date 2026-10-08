---
title: fWarrangeCli
description: fWarrange companion helper daemon — 창 캡처/복구를 위한 REST API 서버
date: 2026.10.08
---

fWarrangeCli 는 macOS 창 배치를 저장·복원하는 엔진임. 메뉴바 에이전트 앱으로 실행되며 전역 단축키·명령행·REST API 를 제공함.

> **fWarrange 는 fWarrangeCli 의 GUI 래퍼임.** App Store 앱 fWarrange(Sandbox)는 레이아웃 목록·미니맵·설정 창을 얹고, 모든 캡처·복원을 REST API 로 이 데몬에 맡김. fWarrangeCli 는 fWarrange 없이 단독으로 동작함.

사용자 매뉴얼: [manual/](../manual/README.md) · fWarrange(GUI): [안내 페이지](https://finfra.kr/product/fWarrange/kr/index.html)

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

> * **소스 코드**는 Apache-2.0 입니다. 직접 빌드하면 수량 제한 없이 사용할 수 있습니다.
> * 아래 Homebrew 패키지 같은 **공식 빌드**는 개인 용도·교육·비영리·오픈소스 프로젝트, 그리고 그 밖의 조직은 **동시 250 카피**까지 무료입니다. 그 이상이거나 재판매·번들·호스팅 용도라면 상업 라이선스([COMMERCIAL.md](../COMMERCIAL.md))가 필요하며, 설치하면 [배포본 약관](../DISTRIBUTION-TERMS_ko.md)([English](../DISTRIBUTION-TERMS.md))에 동의한 것으로 봅니다.

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

Homebrew 로 설치했다면 `brew services`(launchd) 서비스로 실행함 — 지금 시작하고 로그인할 때마다 자동 시작하며, 비정상 종료 시 launchd 가 다시 띄움.

```bash
brew services start fwarrange-cli      # 시작 + 로그인 시 자동 시작
brew services restart fwarrange-cli    # 재시작 (ex) _config.yml 수정 뒤)
brew services stop fwarrange-cli       # 중지
```

메뉴바 **🚀 로그인 시 자동 시작**(`_config.yml` 의 `launchAtLogin`)은 `brew services` 없이 띄운 빌드의 로그인 항목을 다룸. [설치](../manual/kr/02_Install.md) 참조.

# REST API

* **기본 포트**: `3016`
* **API 버전**: `v2` 단일 — `v1` 은 폐기되어 모든 `/api/v1/*` 요청이 `410 Gone` 을 돌려줌
* **서비스 루트**: `http://localhost:3016/api/v2`
* **OpenAPI 명세**: [`api/openapi_v2.yaml`](../api/openapi_v2.yaml)

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
curl -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" \
  -d '{"name": "my-layout"}'

# 레이아웃 복구
curl -X POST http://localhost:3016/api/v2/layouts/my-layout/restore

# 상태 확인
curl http://localhost:3016/api/v2/cli/status
```

# 설정

설정은 `~/Documents/finfra/fWarrangeData/_config.yml` 에 저장됨(메뉴 **설정 ▸ 설정 파일 열기**). fWarrange 설정 창도 같은 파일을 고침. 주요 키:

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

fWarrange(GUI)는 REST API 를 거쳐 같은 폴더를 읽음.

# Accessibility 권한

fWarrangeCli는 창 위치를 제어하기 위해 Accessibility 권한이 필요함:

**시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 > fWarrangeCli 추가**

# 라이선스

fWarrangeCli 소스 코드는 [Apache License 2.0](../LICENSE) 으로 제공됩니다 ([NOTICE](../NOTICE) 참조, 한글 참고 번역 [LICENSE_ko.md](../LICENSE_ko.md)).

* **공식 빌드**(Homebrew `finfra/tap`, GitHub Releases)에는 [DISTRIBUTION-TERMS.md](../DISTRIBUTION-TERMS.md) 가 추가로 적용됩니다 — 개인 용도·교육·비영리·오픈소스 프로젝트, 그리고 그 밖의 조직은 법인당 동시 250 카피까지 무료입니다. 직접 빌드한 것에는 적용되지 않습니다
* 이름·아이콘: [TRADEMARK.md](../TRADEMARK.md) · 상업 라이선스: [COMMERCIAL.md](../COMMERCIAL.md)

Copyright (c) 2026 Finfra Co., Ltd. (https://finfra.kr)
