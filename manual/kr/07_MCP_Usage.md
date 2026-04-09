---
title: fWarrange MCP 사용법
description: fWarrange MCP 서버 사용 방법 (한국어)
date: 2026-03-26
---
# MCP 서버 사용법

fWarrange는 **MCP (Model Context Protocol)** 서버를 제공하여, Claude Desktop, Claude Code 등 AI 도구에서 fWarrange의 기능을 네이티브 도구(Tool)로 직접 호출할 수 있습니다.

## MCP란?

MCP(Model Context Protocol)는 AI 모델이 외부 도구와 상호작용하기 위한 표준 프로토콜입니다. fWarrange MCP 서버를 설정하면, AI가 "레이아웃 저장해줘"라는 요청을 받았을 때 자체적으로 적절한 도구를 호출하여 작업을 수행합니다.

### Skill vs MCP 차이점

| 구분            | Claude Code Skill              | MCP 서버                       |
| --------------- | ------------------------------ | ------------------------------ |
| 동작 방식       | 슬래시 커맨드 -> curl 호출     | AI가 직접 Tool 호출            |
| 설치 위치       | `.claude/commands/`            | `claude_desktop_config.json`   |
| 호출 방법       | `/fwarrange:fwarrange capture` | AI가 자동 판단하여 호출        |
| 지원 클라이언트 | Claude Code                    | Claude Desktop, Claude Code 등 |
| 자연어 지원     | 커맨드 기반                    | 완전 자연어                    |

## 전제 조건

1. **fWarrange 앱 실행 중** (REST API 서버 활성화 상태)
2. **Node.js** 18 이상 설치
3. **npm** 설치

## 설치

### npm 패키지 설치

```bash
npm install -g fwarrange-mcp
```

### 소스에서 빌드

```bash
cd mcp
npm install
npm run build
```

## 설정

### Claude Desktop 설정

`~/Library/Application Support/Claude/claude_desktop_config.json` 파일을 편집합니다:

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

프로젝트 루트의 `.mcp.json` 파일에 추가합니다:

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

### 서버 주소 변경

기본값 외의 주소를 사용할 경우, `args`에 `--server=` 옵션을 추가합니다:

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

### 글로벌 설치 후 설정

```bash
npm install -g fwarrange-mcp
```

```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "fwarrange-mcp"
    }
  }
}
```

### 환경 변수

| 변수                | 기본값                  | 설명                         |
| ------------------- | ----------------------- | ---------------------------- |
| `FWARRANGE_API_URL` | `http://localhost:3016` | fWarrange REST API 서버 주소 |

## 제공 도구 (14개)

MCP 서버는 다음 도구(Tool)를 AI에게 제공합니다:

### 상태 확인

| 도구                  | 설명                       |
| --------------------- | -------------------------- |
| `health_check`        | 서버 상태 및 버전 확인     |
| `check_accessibility` | 손쉬운 사용 권한 상태 확인 |

### 레이아웃 관리

| 도구                 | 설명                      | 매개변수                                                 |
| -------------------- | ------------------------- | -------------------------------------------------------- |
| `list_layouts`       | 저장된 레이아웃 목록 조회 | -                                                        |
| `get_layout`         | 특정 레이아웃 상세 정보   | `name`                                                   |
| `capture_layout`     | 현재 창 배치 캡처 및 저장 | `name?`, `filterApps?`                                   |
| `restore_layout`     | 저장된 레이아웃 복원      | `name`, `maxRetries?`, `retryInterval?`, `minimumScore?` |
| `rename_layout`      | 레이아웃 이름 변경        | `name`, `newName`                                        |
| `delete_layout`      | 레이아웃 삭제             | `name`                                                   |
| `delete_all_layouts` | 전체 레이아웃 삭제        | -                                                        |
| `remove_windows`     | 레이아웃에서 특정 창 제거 | `name`, `windowIds`                                      |

### 윈도우 조회

| 도구                  | 설명                            | 매개변수      |
| --------------------- | ------------------------------- | ------------- |
| `get_current_windows` | 현재 화면의 창 목록 (저장 없이) | `filterApps?` |
| `get_running_apps`    | 실행 중인 앱 목록               | -             |

### 시스템 설정

| 도구         | 설명                | 매개변수   |
| ------------ | ------------------- | ---------- |
| `get_locale` | 현재 언어 설정 조회 | -          |
| `set_locale` | 앱 언어 변경        | `language` |

## 사용 예시

MCP가 설정되면, Claude Desktop이나 Claude Code에서 자연어로 요청하면 됩니다:

### 레이아웃 캡처
> "현재 창 배치를 coding-setup이라는 이름으로 저장해줘"

Claude가 `capture_layout` 도구를 호출하여 저장합니다.

### 레이아웃 복원
> "아까 저장한 coding-setup 레이아웃으로 복원해줘"

Claude가 `restore_layout` 도구를 호출합니다.

### 상태 확인
> "지금 어떤 레이아웃들이 저장되어 있어?"

Claude가 `list_layouts` 도구를 호출하여 목록을 보여줍니다.

### 복합 작업
> "Safari만 현재 위치 저장하고, 이전에 저장한 meeting 레이아웃 복원해줘"

Claude가 `capture_layout(filterApps: ["Safari"])` 후 `restore_layout(name: "meeting")`을 순차 호출합니다.

## 통신 프로토콜

```
Claude Desktop/Code  <--stdio-->  fwarrange-mcp  <--HTTP-->  fWarrange App
                                   (Node.js)                  (REST API :3016)
```

* AI 클라이언트와 MCP 서버 사이: **stdio** (표준 입출력)
* MCP 서버와 fWarrange 앱 사이: **HTTP** (REST API)

## 디버깅

### MCP Inspector로 테스트

MCP Inspector를 사용하면 브라우저에서 각 도구를 인터랙티브하게 테스트할 수 있습니다:

```bash
npx @modelcontextprotocol/inspector npx fwarrange-mcp
```

### 서버 연결 확인

```bash
# fWarrange REST API 서버 동작 확인
curl http://localhost:3016/
```

## 트러블슈팅

| 문제                     | 해결                                                                    |
| ------------------------ | ----------------------------------------------------------------------- |
| MCP 서버가 연결되지 않음 | `claude_desktop_config.json` 경로 및 JSON 문법 확인                     |
| "서버 응답 없음"         | fWarrange 앱 실행 및 REST API 활성화 확인                               |
| 도구가 목록에 안 보임    | Claude Desktop 재시작, 또는 `npx fwarrange-mcp` 직접 실행하여 오류 확인 |
| 권한 오류                | 손쉬운 사용 권한 확인 (`check_accessibility` 도구 사용)                 |
| 포트 충돌                | `--server=` 옵션 또는 `FWARRANGE_API_URL` 환경 변수로 포트 변경         |

## 다음 단계

* [FAQ](08_FAQ.md)
* [REST API 상세](05_API_Usage.md)
