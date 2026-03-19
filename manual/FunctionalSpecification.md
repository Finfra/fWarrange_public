---
title: fWarrange 사용자 매뉴얼 및 기능 명세서 (User Manual & Functional Specification)
description: 본 문서는 fWarrange의 핵심 기술인 **CoreGraphics 기반 고정밀 레이아웃 캡처**, 지능적인 **Score 기반 스마트 창 매칭 복원 알고리즘**, **REST API**, **Claude Code Skill**, **MCP 서버 연동**에 대한 포괄적인 가이드를 제공합니다.
date: 2026.03.18
tags: [매뉴얼, 사용자 가이드, 윈도우 제어, 기능 명세, Skill, MCP]
---

# fWarrange란? (Overview)

fWarrange는 macOS 사용자의 작업 환경을 기억하고 단 한 번의 조작으로 수많은 창들의 위치와 크기를 완벽하게 되돌려 놓는 **윈도우 레이아웃 복원 도구**입니다.
다중 모니터 환경이나 복잡한 개발/디자인 작업 시 흩어지는 창들을 매번 다시 배치할 필요 없이, 지정된 목적(개발, 회의, 디자인 등)에 맞는 앱 창 배열을 즉시 복원합니다.
순수 Swift 코어 스크립트 기반 모터 구동과 사용자 친화적인 SwiftUI GUI 래퍼를 모두 지원하여, 파워유저부터 일반 타겟까지 아우르는 생산성 소프트웨어입니다.

---

# 1. 고정밀 레이아웃 캡처 (Layout Capture System)

현재 눈에 보이는 화면의 상태와 모든 애플리케이션의 윈도우 크기를 그대로 복제해 내는 정보 수집 코어입니다.

## 1.1. CoreGraphics 기반의 윈도우 스캔 (`saveWindowsInfo.swift`)

### 1.1.1. 안전한 정보 추출
`appKit`에 의존하지 않고 시스템 하부의 `CGWindowListCopyWindowInfo` API를 사용하여 윈도우 객체들을 탐색합니다. 불필요한 백그라운드 데몬, 투명 툴팁 바, 혹은 상단 메뉴바 등을 걸러내고 유효한(Interactive) 앱 창 데이터만 추출합니다.

### 1.1.2. 구조화된 YAML 직렬화 보관
수집된 각각의 윈도우 데이터는 다음과 같은 형태의 YAML 텍스트(`data/windowInfo.yml`) 포맷으로 영구 저장됩니다:
- `app`: 프로세스 내 애플리케이션 이름 (예: Safari)
- `window`: 활성화된 탭 혹은 창의 타이틀 명
- `layer`: Z-Index 레이어 뎁스(0번이 일반적인 창)
- `pos`, `size`: `x`, `y` 좌표 및 `width`, `height` 절대 픽셀 값

---

# 2. 스마트 창 복원 엔진 (Smart Restoration Engine)

가장 복잡하고 강력한 컴포넌트입니다. 앱이 재실행되거나 탭이 변경되어 **과거 저장 시점의 윈도우 ID와 현재의 윈도우 ID가 달라지더라도** 원래 위치를 유추해 찾아가는 퍼지 매칭 시스템입니다.

## 2.1. 동적 매칭 스코어 시스템 (Dynamic Score Matching)

`setWindows.swift` 작동 시, 단순히 앱 이름만 보지 않고 화면상 떠 있는 앱 창과 YAML 저장 기록을 다각도로 교차 점검하여 **가장 높은 점수(Score)**를 획득한 창끼리 결합시킵니다:

- **100점 (Perfect Match)**: 앱과 창의 Window ID(PID)가 정확히 동일한 경우 (가장 확실함)
- **90점 (Title Match)**: Window ID는 변했지만 창의 전체 텍스트 제목(Title)이 과거 저장 기록과 글자 하나 안 틀리고 똑같은 경우.
- **80점 (Regex/Pattern Match)**: 약간의 변형이 생긴 경우. 설정된 정규표현식이나 동적 제목 생성 패턴과 일치하는지 분석합니다.
- **70점 (Keyword Match)**: 웹브라우저 등에서 제목이 일부 바뀌었으나(예: `[Google - 검색]`), 핵심 도메인 키워드가 일치하는 경우.
- **60~30점 (Geometry Fallback)**: 제목마저 완전히 바뀌었다면(가령 빈 문서가 다른 프로젝트 문서로 변함), 최후의 수단으로 화면에서의 유사한 위치 비율, 면적 사이즈 등을 분석하여 가장 과거 이력과 흡사했던 창을 도출합니다.

## 2.2. AppKit Accessibility(`AXUIElement`) 강제 제어

점수가 매겨져 짝(Pair) 지어진 윈도우는 macOS의 **손쉬운 사용(Accessibility)** 권한을 활용해 즉시 목표 좌표와 사이즈로 강제 이동 및 리사이즈됩니다. 이 방식은 애니메이션 딜레이 없이 즉각적이고 정확하게 창을 옮길 수 있게 합니다.

---

# 3. 유연도 높은 CLI 및 진단 편의성

GUI가 없어도 동작하는 가벼운 독립형 툴킷(lib/wArrange_core)을 근간으로 삼기 때문에 자동화(Automator, Alfred, 쉘 스크립트 등) 접목이 탁월합니다.

### 3.1. CLI 래핑 커맨드

- `-v` (Verbose): 모든 매칭 계산의 스코어 로그와 진행 상태를 터미널로 상세 출력하여 디버깅을 돕습니다.
- `--name=profileName`: 기본 `windowInfo.yml` 대신 사용자가 지정한 `profileName.yml` (예: `dev_mode.yml`, `design_mode.yml`)에서 데이터를 읽거나 저장할 수 있습니다.
- `--app=AppA,AppB`: 화면의 수많은 앱 중 특정 앱 배열 상태만 부분 저장/복구하고 싶을 때 사용 가능합니다.

### 3.2. 진단 전용 스크립트 묶음

- `list_apps.swift`: 손쉬운 사용 권한 도달이 정상적인지 체크합니다.
- `list_cg.swift`: CoreGraphics 단에서 창이 제대로 인지되고 있는지 확인합니다.
- 복원 실패 시, 이 두 스크립트 출력 결과를 비교하는 것으로 트러블슈팅을 직관적으로 끝낼 수 있습니다.

---

# 4. SwiftUI GUI 연동 아키텍처

GUI 애플리케이션은 뒷단의 코어 스크립트들을 간편하게 조작할 수 있도록 래핑(Wrapping)된 컨트롤 레이어로 작동합니다.
상단 메뉴바 트레이(Tray) 앱 형태로 상주하며, 클릭 한 방에 CLI 명령어(`swift setWindows.swift --name=xxx`)를 쉘 아웃으로 대신 실행해 주어 파워유저의 강력함과 일반 사용자의 편의성을 동시에 잡았습니다.

---

# 5. REST API 서버 (Remote Control Interface)

외부 클라이언트(curl, Apple Shortcuts, 자동화 스크립트)에서 fWarrange의 핵심 기능을 HTTP로 원격 호출할 수 있는 내장 서버입니다.

## 5.1. 서버 아키텍처
- **프레임워크**: Apple Network.framework (NWListener + NWConnection)
- **외부 의존성 없음**: 순수 Swift 구현, 추가 패키지 불필요
- **Manager 직접 호출**: REST 핸들러 → WindowManager/LayoutManager (ViewModel 우회)
- **Notification 연동**: 캡처/복구/삭제/이름변경 완료 시 GUI 자동 갱신

## 5.2. 엔드포인트 (14개)

| Method | Path | 설명 |
|---|---|---|
| GET | / | Health Check (버전, 포트) |
| GET | /api/v1/layouts | 레이아웃 목록 |
| GET | /api/v1/layouts/{name} | 레이아웃 상세 (모든 WindowInfo) |
| POST | /api/v1/capture | 창 캡처 후 저장 (name, filterApps) |
| POST | /api/v1/layouts/{name}/restore | 레이아웃 복구 (maxRetries, retryInterval, minimumScore, enableParallel) |
| PUT | /api/v1/layouts/{name} | 이름 변경 (newName) |
| DELETE | /api/v1/layouts/{name} | 삭제 |
| DELETE | /api/v1/layouts | 전체 삭제 (X-Confirm-Delete-All 헤더 필수) |
| POST | /api/v1/layouts/{name}/windows/remove | 특정 창 제거 (windowIds) |
| GET | /api/v1/windows/current | 현재 창 목록 (저장 없이, filterApps 쿼리) |
| GET | /api/v1/windows/apps | 실행 중 앱 목록 |
| GET | /api/v1/status/accessibility | Accessibility 권한 상태 |
| GET | /api/v1/locale | 현재 언어 설정 |
| PUT | /api/v1/locale | 언어 변경 (language) |

## 5.3. 응답 형식
- 성공: `{"status": "ok", "data": {...}}`
- 에러: `{"status": "error", "error": "메시지"}`
- Content-Type: application/json; charset=utf-8

## 5.4. 보안
- **기본 비활성**: 사용자가 설정 → API 탭에서 수동 활성화
- **localhost only**: 기본 바인딩 127.0.0.1 (외부 접근 불가)
- **외부 접속**: allowExternal 활성화 시 0.0.0.0 바인딩 + CIDR 화이트리스트
- **CIDR**: 기본 192.168.0.0/16, 쉼표로 복수 대역 지정 가능
- **localhost 항상 허용**: 127.0.0.1, ::1은 CIDR 무관하게 허용
- **비허용 IP**: 403 Forbidden 응답

## 5.5. 설정 항목

| 항목 | 기본값 | 설명 |
|---|---|---|
| 서버 활성화 | false | REST API 서버 시작/중지 |
| 포트 | 3016 | HTTP 수신 포트 |
| 외부 접속 | false | LAN/WAN 접근 허용 |
| 허용 CIDR | 192.168.0.0/16 | IP 화이트리스트 |

## 5.6. 활용 예시

### 캡처 후 복구 (자동화)
```bash
# 현재 레이아웃 저장
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"autoSaved"}'

# 저장된 레이아웃 복구
curl -X POST http://localhost:3016/api/v1/layouts/autoSaved/restore
```

### Apple Shortcuts 연동
Shortcuts 앱에서 "URL 내용 가져오기" 액션으로 REST API 호출 가능

---

# 6. Claude Code Skill 연동 (AI Agent Integration - Skill)

Claude Code의 Skill 시스템을 통해 AI 에이전트에서 fWarrange를 자연어 기반으로 제어할 수 있습니다.

## 6.1. Skill 개요

fWarrange Skill은 `/fwarrange:fwarrange` 슬래시 커맨드로 fWarrange REST API를 호출합니다. curl 명령어 없이도 Claude Code 대화 중에 레이아웃을 관리할 수 있습니다.

**전제 조건**: fWarrange 앱이 실행 중이고 REST API 서버가 활성화되어 있어야 합니다.

## 6.2. 설치 방법

### 방법 1: Plugin 설치 (권장)
```bash
claude plugin install --from https://github.com/nowage/fWarrange --path _public/agents/claude
```

### 방법 2: 수동 복사 (프로젝트별)
```bash
cp _public/agents/claude/skills/fwarrange/SKILL.md \
   <PROJECT>/.claude/commands/skills/fwarrange.md
```

### 방법 3: 글로벌 설치
```bash
cp _public/agents/claude/skills/fwarrange/SKILL.md \
   ~/.claude/commands/fwarrange.md
```

## 6.3. 사용 예제

| 커맨드 | 동작 |
|--------|------|
| `/fwarrange:fwarrange capture` | 현재 창 배치 저장 (자동 이름) |
| `/fwarrange:fwarrange capture --name=dev` | "dev" 이름으로 캡처 |
| `/fwarrange:fwarrange restore my-workspace` | "my-workspace" 레이아웃 복원 |
| `/fwarrange:fwarrange list` | 저장된 레이아웃 목록 |
| `/fwarrange:fwarrange detail my-workspace` | 레이아웃 상세 정보 조회 |
| `/fwarrange:fwarrange rename old-name new-name` | 레이아웃 이름 변경 |
| `/fwarrange:fwarrange delete my-workspace` | 레이아웃 삭제 |
| `/fwarrange:fwarrange delete-all` | 전체 레이아웃 삭제 |
| `/fwarrange:fwarrange remove-windows name 14205 5032` | 레이아웃에서 특정 창 제거 |
| `/fwarrange:fwarrange status` | Accessibility 권한 확인 |
| `/fwarrange:fwarrange windows` | 현재 창 목록 |
| `/fwarrange:fwarrange apps` | 실행 중 앱 목록 |
| `/fwarrange:fwarrange locale` | 언어 설정 조회 |
| `/fwarrange:fwarrange locale --set=en` | 언어 변경 |

## 6.4. 서버 미실행 시 동작

서버가 응답하지 않으면 Claude는 다음과 같이 안내합니다:
> "fWarrange REST API 서버가 실행 중이 아닙니다. `open -a "fWarrange"` 명령으로 앱을 실행해주세요."

Claude는 자동으로 서버를 시작하지 **않으며**, 사용자 확인 후 작업을 계속합니다.

---

# 7. MCP 서버 (AI Agent Integration - MCP)

MCP(Model Context Protocol) 서버를 통해 Claude Desktop, Claude Code 등 AI 도구에서 fWarrange 기능을 네이티브 도구(Tool)로 직접 호출할 수 있습니다.

## 7.1. MCP 개요

MCP는 AI 모델이 외부 도구와 상호작용하기 위한 표준 프로토콜입니다. Skill이 명시적 슬래시 커맨드를 사용하는 반면, MCP는 AI가 자동으로 적절한 도구를 판단하여 호출합니다.

## 7.2. 설치 및 설정

### npm 패키지 설치
```bash
npm install -g fwarrange-mcp
```

### Claude Desktop 설정
`~/Library/Application Support/Claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "npx",
      "args": ["-y", "fwarrange-mcp"],
      "env": {
        "FWARRANGE_API_URL": "http://localhost:3016"
      }
    }
  }
}
```

### Claude Code 설정
프로젝트 루트 `.mcp.json`:
```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "npx",
      "args": ["-y", "fwarrange-mcp"],
      "env": {
        "FWARRANGE_API_URL": "http://localhost:3016"
      }
    }
  }
}
```

## 7.3. 제공 도구 (14개)

| 도구 | 설명 | 매개변수 |
|------|------|----------|
| `health_check` | 서버 상태 확인 | - |
| `check_accessibility` | Accessibility 권한 확인 | - |
| `list_layouts` | 레이아웃 목록 | - |
| `get_layout` | 레이아웃 상세 | `name` |
| `capture_layout` | 캡처 및 저장 | `name?`, `filterApps?` |
| `restore_layout` | 레이아웃 복원 | `name`, `maxRetries?`, `retryInterval?`, `minimumScore?` |
| `rename_layout` | 이름 변경 | `name`, `newName` |
| `delete_layout` | 삭제 | `name` |
| `delete_all_layouts` | 전체 레이아웃 삭제 | - |
| `remove_windows` | 레이아웃에서 특정 창 제거 | `name`, `windowIds` |
| `get_current_windows` | 현재 창 목록 | `filterApps?` |
| `get_running_apps` | 실행 중 앱 목록 | - |
| `get_locale` | 언어 설정 조회 | - |
| `set_locale` | 언어 변경 | `language` |

## 7.4. 통신 구조

```
Claude Desktop/Code  <--stdio-->  fwarrange-mcp  <--HTTP-->  fWarrange App
                                   (Node.js)                  (REST API :3016)
```

- AI 클라이언트 ↔ MCP 서버: **stdio** (표준 입출력)
- MCP 서버 ↔ fWarrange 앱: **HTTP** (REST API)
