---
title: fWarrangeCli 매뉴얼
description: fWarrangeCli 사용자 매뉴얼 목차 · 구조 · 작성 원칙 (fWarrange GUI 매뉴얼과의 관계 포함)
date: 2026.10.08
---
# fWarrangeCli 매뉴얼

**fWarrangeCli** 는 macOS 창 배치를 저장·복원하는 엔진입니다. 메뉴바 · 전역 단축키 · 명령행 · REST API · Skill · MCP 로 쓸 수 있으며, 이 폴더는 그 사용법을 다룹니다.

> **fWarrange 는 fWarrangeCli 의 GUI 래퍼입니다.** App Store 앱 fWarrange 는 레이아웃 목록 · 미니맵 · 설정 창을 제공하고, 실제 캡처·복원은 모두 fWarrangeCli 의 REST API 로 수행합니다. fWarrange 의 화면 사용법은 fWarrange 쪽 매뉴얼이 다루며, 공개 안내는 **[fWarrange 안내 페이지](https://finfra.kr/product/fWarrange/kr/index.html)** 에 있습니다.
>
> **fWarrange is a GUI wrapper for fWarrangeCli.** The App Store app fWarrange provides a layout list, minimap, and settings window; every capture and restore is performed through the fWarrangeCli REST API. The fWarrange screens are covered by the fWarrange-side manual; public information is on the **[fWarrange product page](https://finfra.kr/product/fWarrange/en/index.html)**.

# 목차

| #   | 한국어                                  | English                                  | 내용                                              |
| :-- | :-------------------------------------- | :--------------------------------------- | :------------------------------------------------ |
| 01  | [개요](kr/01_Overview.md)               | [Overview](en/01_Overview.md)            | fWarrangeCli 와 fWarrange(GUI 래퍼)의 관계 · 기능 |
| 02  | [설치](kr/02_Install.md)                | [Installation](en/02_Install.md)         | Homebrew · 소스 빌드 · 손쉬운 사용 권한           |
| 03  | [빠른 시작](kr/03_QuickStart.md)        | [Quick Start](en/03_QuickStart.md)       | 저장 → 복원 3단계                                 |
| 04  | [메뉴바 사용법](kr/04_MenuBar_Usage.md) | [Menu Bar Usage](en/04_MenuBar_Usage.md) | 메뉴 · 전역 단축키 · `_config.yml` · 명령행       |
| 05  | [REST API](kr/05_API_Usage.md)          | [REST API](en/05_API_Usage.md)           | v2 주요 엔드포인트 · 보안 · Apple Shortcuts       |
| 06  | [Skill](kr/06_Skill_Usage.md)           | [Skill](en/06_Skill_Usage.md)            | Claude Code Skill                                 |
| 07  | [MCP](kr/07_MCP_Usage.md)               | [MCP](en/07_MCP_Usage.md)                | MCP 서버 `fwarrange-mcp`                          |
| 08  | [FAQ](kr/08_FAQ.md)                     | [FAQ](en/08_FAQ.md)                      | 자주 묻는 질문                                    |

공통 문서: [기능 명세](FunctionalSpecification.md) · [용어 사전](Glossary.md) · [참조 목록](ReferenceAgenda.md)

# 디렉토리 구조

```
manual/
├── README.md                    # 본 파일 (목차·구조)
├── FunctionalSpecification.md   # 기능 명세서
├── Glossary.md                  # 용어 사전
├── ReferenceAgenda.md           # 참조 목록
├── kr/                          # 한국어
│   ├── 01_Overview.md
│   ├── 02_Install.md
│   ├── 03_QuickStart.md
│   ├── 04_MenuBar_Usage.md
│   ├── 05_API_Usage.md
│   ├── 06_Skill_Usage.md
│   ├── 07_MCP_Usage.md
│   └── 08_FAQ.md
└── en/                          # English (같은 구성)
```

# 빠른 시작 (요약)

| 작업     | 방법                                                                                                             |
| :------- | :--------------------------------------------------------------------------------------------------------------- |
| 설치     | `brew install finfra/tap/fwarrange-cli` → `brew services start fwarrange-cli`                                    |
| 저장     | 메뉴바 **📷 창 레이아웃 저장** · ⌘F7                                                                             |
| 복원     | 메뉴바에서 레이아웃 클릭 · ⌥⌘F7(최근) · ⇧⌘F7(기본)                                                               |
| API 상태 | `curl -s http://localhost:3016/api/v2/status`                                                                    |
| API 저장 | `curl -X POST http://localhost:3016/api/v2/capture -H "Content-Type: application/json" -d '{"name":"myLayout"}'` |
| API 복원 | `curl -X POST http://localhost:3016/api/v2/layouts/myLayout/restore`                                             |
| Skill    | `/fwarrange:fwarrange capture --name=myLayout` · `/fwarrange:fwarrange restore myLayout`                         |
| MCP      | Claude Desktop/Code 에서 "현재 창 배치를 저장해줘"                                                               |

# 작성 원칙

* 이 폴더는 **fWarrangeCli 전용**입니다. fWarrange(GUI) 화면 설명·스크린샷은 fWarrange 저장소의 `manual/`(비공개)에 두고, 여기서는 공개 안내 페이지로 링크만 겁니다
* 두 매뉴얼은 서로 링크합니다 — fWarrange 매뉴얼은 엔진 기능(메뉴바·단축키·API·Skill·MCP)을 이 폴더로 보내고, 이 폴더는 GUI 를 fWarrange 안내 페이지로 보냅니다
* 한국어(`kr/`)와 영어(`en/`)는 같은 구성 · 같은 파일명으로 함께 갱신합니다
* 경로는 이 레포 루트 기준 상대 경로를 씁니다(`_public/` 접두사 금지)
* REST API 의 정본은 [`api/openapi_v2.yaml`](../api/openapi_v2.yaml) 입니다. v1 은 폐기되어 `410 Gone` 을 돌려줍니다

# 관련 문서

* **API 스펙**: [api/openapi_v2.yaml](../api/openapi_v2.yaml)
* **API 테스트 스크립트**: [api/test-api.sh](../api/test-api.sh)
* **MCP 서버**: [mcp/](../mcp/) (npm 패키지 `fwarrange-mcp`)
* **Skill**: [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins) 의 `fWarrange/`
* **fWarrange(GUI) 안내**: [finfra.kr/product/fWarrange](https://finfra.kr/product/fWarrange/kr/index.html)
