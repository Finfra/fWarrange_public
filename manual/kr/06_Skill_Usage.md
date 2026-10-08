---
title: fWarrangeCli Skill 사용법
description: fWarrangeCli Skill 사용 방법 (한국어)
date: 2026.10.08
---
# Claude Code Skill 사용법

fWarrangeCli 는 Claude Code 의 Skill(스킬) 시스템과 연동되어, AI 에이전트에서 자연어로 윈도우 레이아웃을 관리할 수 있습니다. Skill 은 fWarrangeCli 의 REST API 만 쓰므로 GUI 래퍼 fWarrange 는 필요 없습니다.

## 개요

Claude Code Skill은 `/fwarrange:fwarrange` 슬래시 커맨드를 통해 fWarrangeCli REST API(v2)를 호출합니다. 사용자는 터미널에서 curl 명령어를 직접 입력할 필요 없이, 자연어 기반으로 레이아웃을 캡처하고 복원할 수 있습니다.

## 전제 조건

1. **fWarrangeCli 실행 중** (REST API 서버는 기본으로 켜져 있음 — [설치](02_Install.md#5-rest-api-확인))
2. **Claude Code** 설치 및 실행
3. **fwarrange Skill** 설치 완료

## 설치 방법

Skill 은 통합 플러그인 레포 [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins) 의 `fWarrange/` 에서 배포합니다.

### 방법 1: 플러그인 마켓플레이스 (권장)

Claude Code 에서:

```
/plugin marketplace add Finfra/f-claude-plugins
/plugin install fwarrange@f-claude-plugins
```

### 방법 2: 수동 복사

```bash
git clone https://github.com/Finfra/f-claude-plugins.git
mkdir -p .claude-plugin .claude
cp f-claude-plugins/fWarrange/plugin.json .claude-plugin/plugin.json
cp -r f-claude-plugins/fWarrange/skills .claude/skills
```

## 사용 예제

### 레이아웃 캡처

```
/fwarrange:fwarrange capture
/fwarrange:fwarrange capture --name=coding-setup
```

Claude가 현재 화면의 모든 창 배치를 저장합니다.

### 레이아웃 복원

```
/fwarrange:fwarrange restore my-workspace
```

저장된 레이아웃으로 창 배치를 되돌립니다.

### 레이아웃 목록 조회

```
/fwarrange:fwarrange list
```

저장된 모든 레이아웃의 이름, 창 수, 날짜를 표시합니다.

### 권한 상태 확인

```
/fwarrange:fwarrange status
```

손쉬운 사용(Accessibility) 권한 상태를 확인합니다.

### 현재 창 목록

```
/fwarrange:fwarrange windows
```

현재 열려 있는 모든 창의 정보를 표시합니다.

### 실행 중 앱 목록

```
/fwarrange:fwarrange apps
```

현재 실행 중인 GUI 앱 목록을 표시합니다.

### 레이아웃 상세 조회

```
/fwarrange:fwarrange detail my-workspace
```

특정 레이아웃의 창 목록과 위치/크기 정보를 표시합니다.

### 레이아웃 이름 변경

```
/fwarrange:fwarrange rename old-name new-name
```

저장된 레이아웃의 이름을 변경합니다.

### 레이아웃 삭제

```
/fwarrange:fwarrange delete my-workspace
```

특정 레이아웃을 삭제합니다.

### 전체 레이아웃 삭제

```
/fwarrange:fwarrange delete-all
```

저장된 모든 레이아웃을 삭제합니다. Claude가 실행 전 사용자에게 확인을 요청합니다.

### 특정 창 제거

```
/fwarrange:fwarrange remove-windows my-workspace 14205 5032
```

레이아웃에서 특정 Window ID의 창을 제거합니다.

### 언어 설정

```
/fwarrange:fwarrange locale
/fwarrange:fwarrange locale --set=en
```

앱의 표시 언어를 조회하거나 변경합니다.

## 동작 흐름

```
사용자: /fwarrange:fwarrange capture --name=dev
         |
Claude Code: 서버 상태 확인 (GET /)
         |
         +-- 서버 미응답 시 --> fWarrangeCli 시작 명령 안내
         |
         +-- 서버 정상 시 --> POST /api/v2/capture 호출
         |
         +-- 결과 보고: "dev 레이아웃으로 12개 창 저장 완료"
```

## 서버 미실행 시 동작

서버가 응답하지 않으면 Claude는 다음과 같이 안내합니다:

> "fWarrange REST API 서버(fWarrangeCli)가 실행 중이 아닙니다. Homebrew 로 시작해 주세요:"
> ```bash
> brew services start finfra/tap/fwarrange-cli
> ```
> "준비되면 알려주세요."

Claude는 자동으로 서버를 시작하지 **않습니다**. 사용자 확인 후 작업을 계속합니다.

## Skill API 레퍼런스

Skill 내부에서 호출하는 REST API 엔드포인트:

| 커맨드                           | API 호출                                     |
| -------------------------------- | -------------------------------------------- |
| `capture`                        | POST `/api/v2/capture`                       |
| `restore <name>`                 | POST `/api/v2/layouts/{name}/restore`        |
| `list`                           | GET `/api/v2/layouts`                        |
| `detail <name>`                  | GET `/api/v2/layouts/{name}`                 |
| `rename <name> <newName>`        | PUT `/api/v2/layouts/{name}`                 |
| `delete <name>`                  | DELETE `/api/v2/layouts/{name}`              |
| `delete-all`                     | DELETE `/api/v2/layouts`                     |
| `remove-windows <name> <ids...>` | POST `/api/v2/layouts/{name}/windows/remove` |
| `status`                         | GET `/api/v2/status/accessibility`           |
| `windows`                        | GET `/api/v2/windows/current`                |
| `apps`                           | GET `/api/v2/windows/apps`                   |
| `locale`                         | GET `/api/v2/settings/general`               |

## 옵션

| 옵션             | 설명                      | 기본값                  |
| ---------------- | ------------------------- | ----------------------- |
| `--name=<이름>`  | 캡처/복원할 레이아웃 이름 | 자동 생성               |
| `--server=<URL>` | 서버 주소 변경            | `http://localhost:3016` |

## 트러블슈팅

| 문제                       | 해결                                                            |
| -------------------------- | --------------------------------------------------------------- |
| "서버가 응답하지 않습니다" | fWarrangeCli 실행 여부와 `_config.yml` 의 `restServerEnabled` 확인 |
| Skill을 찾을 수 없음       | `/plugin` 목록에서 `fwarrange` 설치 여부 확인                   |
| 복원 실패                  | 손쉬운 사용 권한 확인 (`/fwarrange:fwarrange status`)           |

## 다음 단계

* [MCP 서버 사용법](07_MCP_Usage.md)
* [FAQ](08_FAQ.md)
