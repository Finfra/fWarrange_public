---
title: fWarrangeCli 매뉴얼 참조 목록 (Reference Agenda)
description: fWarrangeCli 매뉴얼이 다루는 참조 주제 목록과 각 주제의 정본 위치
date: 2026.10.08
---

fWarrangeCli 매뉴얼이 다루는(또는 다룰) 주제 목록입니다. 각 주제 옆에 정본 문서를 적었습니다 — 같은 내용을 여러 곳에 다시 쓰지 않고 정본으로 링크합니다. fWarrange(GUI 래퍼)의 화면 주제는 fWarrange 쪽 매뉴얼이 다룹니다.

# 1. 레이아웃 데이터와 저장

## 1-1. 레이아웃 YAML 형식 (`app` · `bundleId` · `window` · `layer` · `id` · `pos` · `size`) — [기능 명세 1.3](FunctionalSpecification.md#13-yaml-형식)
## 1-2. 저장 위치와 저장 모드 (`host` · `share`) · 모드 · 로그 · 통계 파일 — [기능 명세 9](FunctionalSpecification.md#9-설정과-저장-위치)
## 1-3. 설정 파일 `_config.yml` 키 — [04 메뉴바 사용법](kr/04_MenuBar_Usage.md#설정-파일-_configyml)

# 2. 캡처

## 2-1. CGWindowList 열거 + 손쉬운 사용 API 제목 보정 — [기능 명세 1.1](FunctionalSpecification.md#11-창-열거--cgwindowlist--손쉬운-사용-api-하이브리드)
## 2-2. 제외 앱 · `filterApps` · 레이아웃 이름 규칙 — [기능 명세 1](FunctionalSpecification.md#1-레이아웃-캡처)

# 3. 복원과 창 매칭

## 3-1. 점수 표 (ID 100 · 제목 90 · 정규식 80 · 포함 70 · 기하 60~30) — [기능 명세 2.1](FunctionalSpecification.md#21-점수-기반-창-매칭)
## 3-2. 매칭 모드 `strict` · `normal` · `loose` 와 Moom 폴백 — [기능 명세 2.2](FunctionalSpecification.md#22-매칭-모드-mode)
## 3-3. 3px 검증 · 재시도 · 병렬 복원 · 최선 결과 보고 — [기능 명세 2.3](FunctionalSpecification.md#23-이동--검증--재시도)
## 3-4. 선택 복원(`windowIds`) · 시험 실행(`dryRun`) — [기능 명세 2.4](FunctionalSpecification.md#24-선택-복원--시험-실행)
## 3-5. 제목 정규화 룰 · 복원 통계 — [기능 명세 3·4](FunctionalSpecification.md#3-제목-정규화)
## 3-6. 다중 모니터 좌표(음수 좌표) · 디스플레이 배치 변경 — [08 FAQ](kr/08_FAQ.md)

# 4. 모드와 자동 저장

## 4-1. 모드 정의(`layoutRef` · `requiredApps`) · 활성화 · 명령행 `mode` / `switch` — [기능 명세 5](FunctionalSpecification.md#5-모드-mode)
## 4-2. 슬립·화면 잠금 시 자동 저장 · 보관 개수와 기간 — [기능 명세 6](FunctionalSpecification.md#6-자동-저장)

# 5. 메뉴바 · 단축키 · 명령행

## 5-1. 메뉴 구성과 데몬 제어(재시작 · REST 일시 정지) — [04 메뉴바 사용법](kr/04_MenuBar_Usage.md#메뉴-구성)
## 5-2. 전역 단축키 5종 · 바꾸는 방법(`_config.yml` · REST · 명령행 · fWarrange) · 표기 규칙 · 되돌리기 범위 · 문제 해결 — [09 단축키 사용법](kr/09_Shortcut_Usage.md)
## 5-3. 명령행 명령과 옵션(`--port` · `--host` · `--pretty` · `-q`) — [04 › 명령행](kr/04_MenuBar_Usage.md#명령행-cli)

# 6. REST API v2

## 6-1. 서비스 루트 `/api/v2` · v1 `410 Gone` · 응답 형식 — [05 REST API](kr/05_API_Usage.md)
## 6-2. 엔드포인트 범주(레이아웃 · 캡처/복원 · 창 · 매칭 품질 · 모드 · 설정 · 상태 · 데몬 제어 · 변경 감지 · GUI 연동) — [기능 명세 8](FunctionalSpecification.md#8-rest-api-v2), 계약 정본 [api/openapi_v2.yaml](../api/openapi_v2.yaml)
## 6-3. 보안(localhost 바인딩 · CIDR 화이트리스트 · `403`) — [기능 명세 8.2](FunctionalSpecification.md#82-보안)
## 6-4. 자동화 연동(curl · Apple Shortcuts · 셸 스크립트) — [05 › Apple Shortcuts](kr/05_API_Usage.md#apple-shortcuts-연동) · [03 빠른 시작](kr/03_QuickStart.md)

# 7. 설치와 권한

## 7-1. Homebrew 설치 · `brew services` · 소스 빌드 — [02 설치](kr/02_Install.md)
## 7-2. 손쉬운 사용 권한 부여 · 문제 해결 — [02 설치](kr/02_Install.md) · [08 FAQ](kr/08_FAQ.md)

# 8. Claude Code Skill

## 8-1. 설치(플러그인 마켓플레이스 [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins) · 수동 복사) — [06 Skill](kr/06_Skill_Usage.md)
## 8-2. `/fwarrange:fwarrange` 명령 · 내부 REST 호출 대응 · 서버 미실행 시 동작 — [06 Skill](kr/06_Skill_Usage.md)

# 9. MCP 서버

## 9-1. 구조 — Claude Desktop/Code ⇄ stdio ⇄ `fwarrange-mcp`(Node.js) ⇄ HTTP ⇄ fWarrangeCli(:3016), 환경 변수 `FWARRANGE_API_URL` — [07 MCP](kr/07_MCP_Usage.md)
## 9-2. 제공 도구 13종 · Claude Desktop(`claude_desktop_config.json`) · Claude Code(`.mcp.json`) 설정 — [07 MCP](kr/07_MCP_Usage.md) · 소스 [mcp/](../mcp/)

# 10. fWarrange(GUI 래퍼)와의 관계

## 10-1. 역할 분담 · 연동 경로(REST · URL Scheme) — [01 개요](kr/01_Overview.md)
## 10-2. GUI 화면(레이아웃 목록 · 미니맵 · 설정 창) — fWarrange 쪽 매뉴얼, 공개 안내는 [fWarrange 안내 페이지](https://finfra.kr/product/fWarrange/kr/index.html)
