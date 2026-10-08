---
title: fWarrangeCli FAQ
description: fWarrangeCli 자주 묻는 질문 (한국어)
date: 2026.10.08
---
# 자주 묻는 질문 (FAQ)

## fWarrangeCli 와 fWarrange

### Q: fWarrangeCli 와 fWarrange 는 무엇이 다른가요?
A: **fWarrangeCli** 는 창 캡처·복원·단축키·REST API 를 수행하는 엔진(Homebrew, 무료)이고, **fWarrange** 는 그 위에 레이아웃 목록·미니맵·설정 창을 얹은 **GUI 래퍼**(App Store, 유료)입니다. fWarrange 는 fWarrangeCli 의 REST API 로 동작합니다 — [개요](01_Overview.md#fwarrangecli-와-fwarrange-gui-래퍼).

### Q: fWarrange 없이 fWarrangeCli 만 써도 되나요?
A: 네. 메뉴바 · 전역 단축키 · 명령행 · REST API · Skill · MCP 가 모두 fWarrangeCli 만으로 동작합니다. 반대로 fWarrange 는 fWarrangeCli 없이 동작하지 않습니다.

### Q: fWarrange(GUI) 사용법은 어디에 있나요?
A: [fWarrange 안내 페이지](https://finfra.kr/product/fWarrange/kr/index.html) 에 있습니다. 메뉴바의 **메인 창 열기** · **환경설정…** 은 fWarrange 를 엽니다.

### Q: fWarrangeCli 는 무료인가요?
A: 이 저장소의 소스 코드는 Apache-2.0 오픈소스입니다(`mcp/` 패키지는 MIT). 직접 빌드하면 수량 제한 없이 사용할 수 있습니다. 공식 빌드(Homebrew `finfra/tap`, GitHub Releases)는 개인 용도·교육·비영리·오픈소스 프로젝트, 그리고 그 밖의 조직은 법인당 동시 250 카피까지 무료이며, 그 이상이거나 재판매·번들·호스팅 용도라면 [COMMERCIAL.md](../../COMMERCIAL.md) 를 참고하세요. 상세: [DISTRIBUTION-TERMS.md](../../DISTRIBUTION-TERMS.md) · [TRADEMARK.md](../../TRADEMARK.md) · [LICENSE_ko.md](../../LICENSE_ko.md). GUI 래퍼 fWarrange 는 App Store 유료 앱입니다.

### Q: 어떤 macOS 버전에서 동작하나요?
A: fWarrangeCli 는 macOS 14.0 이상, fWarrange 는 15.6 이상입니다. Apple Silicon · Intel 모두 지원합니다.

## 권한

### Q: "손쉬운 사용 권한이 필요합니다" 오류가 나타납니다.
A: 시스템 설정 › 개인정보 보호 및 보안 › 손쉬운 사용에서 **fWarrangeCli** 를 켭니다. fWarrange 에는 권한이 필요 없습니다 — [설치 › 손쉬운 사용 권한](02_Install.md#4-손쉬운-사용-권한).

### Q: 단축키는 반응하는데 창이 움직이지 않습니다.
A: 단축키 등록은 권한과 무관하게 되지만 창 이동은 권한이 있어야 합니다. 권한을 다시 켜고 fWarrangeCli 를 재시작하세요.

### Q: 소스에서 빌드할 때마다 권한이 풀립니다.
A: 새로 빌드하면 서명이 달라져 macOS 가 다른 앱으로 인식합니다. 빌드마다 다시 등록해야 합니다. Homebrew 공식 빌드는 서명이 고정되어 있습니다.

## 레이아웃 저장/복원

### Q: 창 복원이 실패합니다.
A: 다음을 확인하세요.
1. fWarrangeCli 에 손쉬운 사용 권한이 있는지
2. 복원하려는 앱이 실행 중인지
3. 복원 응답(REST·명령행)의 창별 결과에서 어떤 창이 매칭되지 않았는지

### Q: 복원 시 창 위치가 약간 어긋납니다.
A: 복원 검증은 3px 오차를 허용합니다. 일부 앱(특히 Electron 기반)은 시스템 제약으로 정확한 위치 지정이 안 될 수 있습니다.

### Q: 다중 모니터에서 음수 좌표가 표시됩니다.
A: 정상입니다. macOS 좌표계에서 메인 모니터 왼쪽·위쪽에 놓인 보조 모니터의 좌표는 음수입니다.

### Q: 디스플레이 배치를 바꾸면 어떻게 되나요?
A: 이전에 저장한 좌표가 엉뚱한 위치를 가리킬 수 있습니다. 배치를 바꾼 뒤에는 레이아웃을 새로 저장하세요.

### Q: 특정 앱의 창만 저장할 수 있나요?
A: 네, REST API `capture` 의 `filterApps` 필드를 사용합니다 — [빠른 시작 › 특정 앱만 저장](03_QuickStart.md#특정-앱만-저장).

### Q: 전체 화면(Full Screen) 앱도 복원되나요?
A: 전체 화면 앱은 별도 Space 에서 실행되므로 좌표 기반 복원이 적용되지 않습니다.

## REST API

### Q: API 서버는 켜져 있나요?
A: 기본으로 켜져 있습니다(`restServerEnabled: true`, 포트 3016, `127.0.0.1` 만 허용). fWarrange 도 이 서버로 동작하므로 끄면 fWarrange 가 멈춥니다. 잠시 막으려면 메뉴바 **데몬 ▸ REST API 일시 정지** 를 씁니다.

### Q: 외부 네트워크에서 접속할 수 있나요?
A: `_config.yml` 에서 `allowExternalAccess: true` 와 `allowedCIDR`(기본 `192.168.0.0/16`)를 지정하면 LAN 에서 접근할 수 있습니다. 인터넷에 직접 노출하는 것은 권장하지 않습니다.

### Q: 포트를 바꿀 수 있나요?
A: `_config.yml` 의 `restServerPort` 를 바꾸고 fWarrangeCli 를 재시작합니다 — [메뉴바 사용법 › 설정 파일](04_MenuBar_Usage.md#설정-파일-_configyml).

### Q: Apple Shortcuts 에서 호출하려면?
A: Shortcuts 의 "URL 내용 가져오기" 액션으로 `http://localhost:3016/api/v2/layouts/myLayout/restore` 를 POST 로 호출합니다 — [API 사용법](05_API_Usage.md#apple-shortcuts-연동).

## Skill / MCP

### Q: Skill 과 MCP 의 차이는 무엇인가요?
A:
* **Skill**: Claude Code 에서 `/fwarrange:fwarrange` 슬래시 커맨드로 호출. 내부적으로 curl 실행
* **MCP**: Claude Desktop/Code 에서 AI 가 알맞은 도구를 골라 호출. 자연어 지원

### Q: MCP 서버가 연결되지 않습니다.
A: 다음을 확인하세요.
1. fWarrangeCli 가 실행 중이고 `curl -s http://localhost:3016/api/v2/status` 가 응답하는지
2. `claude_desktop_config.json` 의 JSON 문법이 올바른지
3. Node.js 18 이상이 설치되어 있는지
4. `npx fwarrange-mcp` 를 직접 실행해 오류 메시지 확인

### Q: Skill/MCP 에 fWarrange(GUI)가 필요한가요?
A: 아니요. Skill 과 MCP 는 fWarrangeCli 의 REST API 로 동작하므로 fWarrangeCli 만 실행 중이면 됩니다.

## 성능

### Q: 창이 많으면 복원이 느린가요?
A: 앱별 병렬 복원(`enableParallelRestore: true`)이 기본이라 20~30개 창도 수 초 안에 복원됩니다.

## 관련 문서

* [개요](01_Overview.md)
* [설치](02_Install.md)
* [메뉴바 사용법](04_MenuBar_Usage.md)
* [REST API 사용법](05_API_Usage.md)
* [Skill 사용법](06_Skill_Usage.md)
* [MCP 서버 사용법](07_MCP_Usage.md)
* [fWarrange(GUI) 안내 페이지](https://finfra.kr/product/fWarrange/kr/index.html)
