---
title: fWarrange MCP Server
description: fWarrange REST API를 MCP 도구로 제공하는 서버 안내 (한국어)
date: 2026-03-26
---

fWarrange REST API를 [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) 도구로 제공하는 서버입니다.
AI 에이전트(Claude Code, Claude Desktop 등)에서 macOS 창 레이아웃을 직접 관리할 수 있습니다.

# 전제 조건

fWarrange REST API 서버가 실행 중이어야 합니다:

| 서버              | 실행 방법                                     |
| ----------------- | --------------------------------------------- |
| macOS 네이티브 앱 | fWarrange.app 실행 (설정에서 REST API 활성화) |

기본 서버 주소: `http://localhost:3016`

---

# 설치

## 방법 1: 글로벌 설치 (권장)

```bash
npm install -g fwarrange-mcp
```

[![npm](https://img.shields.io/npm/v/fwarrange-mcp)](https://www.npmjs.com/package/fwarrange-mcp)

## 방법 2: npx (설치 없이 바로 실행)

별도 설치 없이 MCP 설정에서 `npx`로 직접 실행합니다.

## 방법 3: 소스에서 직접 실행

```bash
git clone https://github.com/nowage/fWarrange.git
cd fWarrange/mcp
npm install
```

---

# 설정

## Claude Code

* `~/.claude/settings.json` 또는 프로젝트 `.claude/settings.json`에 추가:
  - Claude Desktop의 경우 `~/Library/Application Support/Claude/claude_desktop_config.json`에 추가:
```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "npx",
      "args": ["-y", "fwarrange-mcp"]
    }
  }
}
```

* 소스에서 직접 실행했다면:
```json
  "mcpServers": {
    "fwarrange": {
      "command": "node",
      "args": [
        "{PROJECT_ROOT-type-or-paste-it}/mcp/index.js"
      ]
    }
  }
```

* 서버 주소를 변경하려면:
```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "npx",
      "args": ["-y", "fwarrange-mcp", "--server=http://192.168.0.10:3016"]
    }
  }
}
```

## 글로벌 설치 후 사용

```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "fwarrange-mcp"
    }
  }
}
```

---

# 제공 도구 (Tools)

## 1. `health_check`

fWarrange 서버 상태를 확인합니다.

**파라미터**: 없음

**응답 예시**:
```json
{
  "status": "ok",
  "app": "fWarrange",
  "port": 3016
}
```

---

## 2. `list_layouts`

저장된 레이아웃 목록을 조회합니다.

**파라미터**: 없음

**응답 예시**:
```json
{
  "layouts": [
    { "name": "work", "windowCount": 8, "fileDate": "2026-03-18T10:00:00Z" },
    { "name": "home", "windowCount": 5, "fileDate": "2026-03-17T20:00:00Z" }
  ]
}
```

---

## 3. `get_layout`

특정 레이아웃의 상세 정보(창 목록)를 조회합니다.

**파라미터**:

| 이름   | 타입   | 필수 | 설명                        |
| ------ | ------ | ---- | --------------------------- |
| `name` | string | 예   | 레이아웃 이름 (확장자 제외) |

**응답 예시**:
```json
{
  "name": "work",
  "windows": [
    {
      "app": "Safari",
      "window": "Start Page",
      "id": 14205,
      "pos": { "x": 100, "y": 200 },
      "size": { "width": 1200, "height": 800 }
    }
  ]
}
```

---

## 4. `capture_layout`

현재 열려 있는 창 레이아웃을 캡처하여 저장합니다.

**파라미터**:

| 이름         | 타입     | 필수   | 설명                                  |
| ------------ | -------- | ------ | ------------------------------------- |
| `name`       | string   | 아니오 | 레이아웃 이름 (미지정 시 기본값 사용) |
| `filterApps` | string[] | 아니오 | 캡처할 앱 이름 목록 (미지정 시 전체)  |

**사용 예시** (Claude에게 요청):
```
현재 창 레이아웃을 "work"라는 이름으로 캡처해줘
```

---

## 5. `restore_layout`

저장된 레이아웃을 복구하여 창 위치/크기를 재배치합니다.

**파라미터**:

| 이름             | 타입    | 필수   | 기본값 | 설명                  |
| ---------------- | ------- | ------ | ------ | --------------------- |
| `name`           | string  | 예     | -      | 복구할 레이아웃 이름  |
| `maxRetries`     | number  | 아니오 | 5      | 최대 재시도 횟수      |
| `retryInterval`  | number  | 아니오 | 0.5    | 재시도 간격(초)       |
| `minimumScore`   | number  | 아니오 | 30     | 최소 창 매칭 점수     |
| `enableParallel` | boolean | 아니오 | -      | 병렬 복구 활성화 여부 |

**사용 예시** (Claude에게 요청):
```
"work" 레이아웃으로 복구해줘
```

---

## 6. `rename_layout`

레이아웃 이름을 변경합니다.

**파라미터**:

| 이름      | 타입   | 필수 | 설명           |
| --------- | ------ | ---- | -------------- |
| `name`    | string | 예   | 현재 이름      |
| `newName` | string | 예   | 변경할 새 이름 |

---

## 7. `delete_layout`

특정 레이아웃을 삭제합니다.

**파라미터**:

| 이름   | 타입   | 필수 | 설명                 |
| ------ | ------ | ---- | -------------------- |
| `name` | string | 예   | 삭제할 레이아웃 이름 |

---

## 8. `delete_all_layouts`

저장된 모든 레이아웃을 삭제합니다. `X-Confirm-Delete-All` 헤더가 자동으로 전송됩니다.

**파라미터**: 없음

---

## 9. `remove_windows`

레이아웃에서 특정 창(Window ID)을 제거합니다.

**파라미터**:

| 이름        | 타입     | 필수 | 설명                  |
| ----------- | -------- | ---- | --------------------- |
| `name`      | string   | 예   | 레이아웃 이름         |
| `windowIds` | number[] | 예   | 제거할 Window ID 목록 |

**사용 예시** (Claude에게 요청):
```
"work" 레이아웃에서 Window ID 14205, 14210을 제거해줘
```

---

## 10. `get_current_windows`

현재 열려 있는 창 목록을 조회합니다.

**파라미터**:

| 이름         | 타입     | 필수   | 설명                              |
| ------------ | -------- | ------ | --------------------------------- |
| `filterApps` | string[] | 아니오 | 필터링할 앱 이름 (미지정 시 전체) |

**사용 예시** (Claude에게 요청):
```
Safari와 iTerm2의 현재 창 목록을 보여줘
```

---

## 11. `get_running_apps`

현재 실행 중인 애플리케이션 목록을 조회합니다.

**파라미터**: 없음

---

## 12. `check_accessibility`

macOS 손쉬운 사용(Accessibility) 권한 상태를 확인합니다.

**파라미터**: 없음

**응답 예시**:
```json
{
  "accessible": true
}
```

---

## 13. `set_ui_state`

캡처 자동화를 위해 앱 UI 상태를 제어합니다 (창 목록 숨기기, 앱 선택 등).

**파라미터**:

| 이름          | 타입                 | 필수   | 설명                                              |
| ------------- | -------------------- | ------ | ------------------------------------------------- |
| `hideWindows` | boolean              | 아니오 | 레이아웃 상세 뷰에서 창 목록 숨기기/표시          |
| `selectApps`  | string 또는 string[] | 아니오 | `"all"`, `"none"`, `"top:N"`, 또는 앱 이름 배열   |
| `excludeApps` | string[]             | 아니오 | 선택에서 제외할 앱 목록                           |

**사용 예시** (Claude에게 요청):
```
창 목록을 숨기고 Safari와 iTerm2만 선택해줘
```

**응답 예시**:
```json
{
  "status": "ok",
  "data": {
    "hideWindows": true,
    "selectApps": ["Safari", "iTerm2"]
  }
}
```

---

## 14. `get_locale`

현재 앱 언어 설정과 지원 언어 목록을 조회합니다.

**파라미터**: 없음

**응답 예시**:
```json
{
  "status": "ok",
  "data": {
    "current": "ko",
    "supported": ["system", "ko", "en", "ja", "ar", "zh-Hans", "zh-Hant", "fr", "de", "hi", "es"]
  }
}
```

---

## 15. `set_locale`

앱 표시 언어를 변경합니다. 적용을 위해 앱 재시작이 필요합니다.

**파라미터**:

| 이름       | 타입   | 필수 | 설명                                       |
| ---------- | ------ | ---- | ------------------------------------------ |
| `language` | string | 예   | 언어 코드 (예: "ko", "en", "ja", "system") |

**응답 예시**:
```json
{
  "status": "ok",
  "data": {
    "language": "en",
    "restartRequired": true
  }
}
```

---

# 디버깅

## MCP Inspector로 테스트

```bash
npx @modelcontextprotocol/inspector npx fwarrange-mcp
```

브라우저에서 Inspector UI가 열리며, 각 도구를 직접 테스트할 수 있습니다.

## 서버 연결 확인

```bash
# fWarrange REST API 서버가 실행 중인지 확인
curl http://localhost:3016/
```

---

# npm 배포

```bash
cd mcp
npm publish
```

---

# 아키텍처

```
Claude Code / Claude Desktop
    |
    | MCP (stdio)
    v
fwarrange-mcp (이 서버)
    |
    | HTTP (REST API)
    v
fWarrange Server (localhost:3016)
    └── macOS 네이티브 앱 (Swift/SwiftUI)
```

---

# 라이선스

MIT
