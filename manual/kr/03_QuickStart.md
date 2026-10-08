---
title: fWarrangeCli 빠른 시작
description: fWarrangeCli 빠른 시작 — 저장 · 이동 · 복원 3단계 (한국어)
date: 2026.10.08
---
# 빠른 시작 (Quick Start)

핵심 흐름은 **저장 → (창이 흩어짐) → 복원** 3단계입니다. 같은 일을 메뉴바 · 단축키 · 명령행 · REST API 어느 쪽으로든 할 수 있습니다.

## Step 1: 현재 배치 저장

원하는 대로 창을 배치한 뒤 저장합니다.

| 방법   | 조작                                                                                                                |
| ------ | ------------------------------------------------------------------------------------------------------------------- |
| 메뉴바 | 아이콘 › **📷 창 레이아웃 저장** (이름은 `YYYY-MM-DD-N` 자동)                                                       |
| 단축키 | ⌘F7                                                                                                                 |
| 명령행 | `fWarrangeCli capture myWorkspace`                                                                                  |
| API    | `curl -X POST http://localhost:3016/api/v2/capture -H "Content-Type: application/json" -d '{"name":"myWorkspace"}'` |

## Step 2: 창 위치가 바뀜

다른 작업을 하다 창이 흩어졌거나, 다른 배치로 바꿨다가 돌아오고 싶은 상황입니다.

## Step 3: 저장한 배치로 복원

| 방법   | 조작                                                                    |
| ------ | ----------------------------------------------------------------------- |
| 메뉴바 | 아이콘 › 레이아웃 이름 클릭 (또는 **🔁 최근 레이아웃 복구**)            |
| 단축키 | ⌥⌘F7 (최근) · ⇧⌘F7 (기본 레이아웃)                                      |
| 명령행 | `fWarrangeCli restore myWorkspace`                                      |
| API    | `curl -X POST http://localhost:3016/api/v2/layouts/myWorkspace/restore` |

명령행의 `fWarrangeCli` 는 Homebrew 설치 시 `/opt/homebrew/opt/fwarrange-cli/fWarrangeCli.app/Contents/MacOS/fWarrangeCli` 입니다 — [메뉴바 사용법 › 명령행](04_MenuBar_Usage.md#명령행-cli).

## 활용 예 (REST API)

### 작업별 레이아웃 전환

```bash
# 저장
curl -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" -d '{"name":"coding"}'
curl -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" -d '{"name":"meeting"}'

# 전환
curl -X POST http://localhost:3016/api/v2/layouts/coding/restore
curl -X POST http://localhost:3016/api/v2/layouts/meeting/restore
```

### 특정 앱만 저장

```bash
curl -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"webDev", "filterApps":["Safari","iTerm2"]}'
```

### 레이아웃 관리

```bash
curl -s http://localhost:3016/api/v2/layouts                  # 목록
curl -s http://localhost:3016/api/v2/layouts/myWorkspace      # 상세
curl -X PUT http://localhost:3016/api/v2/layouts/myWorkspace \
  -H "Content-Type: application/json" -d '{"newName":"dailySetup"}'   # 이름 변경
curl -X DELETE http://localhost:3016/api/v2/layouts/dailySetup        # 삭제
```

## GUI 로 하려면

레이아웃 목록 · 미니맵에서 고르고 체크한 창만 복원하는 GUI 는 래퍼 앱 **fWarrange** 가 제공합니다 — [fWarrange 안내 페이지](https://finfra.kr/product/fWarrange/kr/index.html).

## 다음 단계

* [메뉴바 사용법](04_MenuBar_Usage.md) — 메뉴 · 단축키 · 명령행 · `_config.yml`
* [REST API 사용법](05_API_Usage.md) — 전체 엔드포인트
* [Skill 사용법](06_Skill_Usage.md) — Claude Code 에서 자연어 제어
* [MCP 서버 사용법](07_MCP_Usage.md) — AI 도구 연동
