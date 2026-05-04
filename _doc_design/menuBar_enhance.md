---
name: menuBar_enhance
description: fWarrangeCli(cliApp) 메뉴바 구조 — paidApp 메뉴 없음, 아이콘 변경만
date: 2026-05-04
version: "1.2"
---

> **상위 SSOT**: paidApp ↔ cliApp 상호작용 프로토콜 전체는 [`paid_cli_protocol.md`](../../_doc_design/paid_cli_protocol.md)에서 단일 관리됨.
> **버전 이력**: v1.0 — paidApp/cliApp 각각 메뉴바 설계 (별도 구조). v1.1 — 구조 동형화 후 cliApp 단일 전담으로 통합. v1.2 — 종료 항목 단축키·다국어 정책 정비(Issue70).

## 기본 방침

* **paidApp 메뉴 없음**: paidApp(`fWarrange`)은 자체 메뉴바 미사용. 모든 메뉴바 관련 작업은 cliApp에서 전담
* **paidApp 상태에 따라 아이콘 변경**: `paidAppStatus` 글로벌 변수에 따라 메뉴바 아이콘 모양 결정
* **cliApp이 단일 메뉴바 진입점**: 모든 액션은 cliApp 메뉴에서 호출

## paidApp 상태 변수 (`paidAppStatus`)

cliApp이 보유하는 글로벌 변수. **저장하지 않으며 cliApp 시작 시 매번 갱신**.

| 값           | 의미                    |
| :----------- | :---------------------- |
| `notInstall` | paidApp 미설치 (초기값) |
| `stopped`    | 설치 O, 미실행          |
| `started`    | 실행 중                 |

**`started` 전환 트리거**: api 요청이 수신되거나, paidApp 시작 프로세스가 성공한 경우.

## 시작 흐름

### paidApp 시작 시 (paidApp → cliApp 감지)

```
paidApp 시작
  └─ api v2 포트(3016) 접근 테스트
       ├─ 성공 → 정상 동작
       └─ 실패 → cliApp 설치 여부 판단
              ├─ 미설치 → [설치 링크 창] 표시
              └─ 설치 O, 서비스 미시작 → [터미널 안내 창] 표시
                   (예: brew services start fwarrange-cli)
```

* 설치/서비스 시작 안내를 **별도 창으로 분리** — 혼동 방지

### cliApp 시작 시 (cliApp → paidApp 감지)

```
cliApp 시작 → paidAppStatus = notInstall (초기화)
  └─ paidApp 설치 여부 확인
       ├─ 미설치 → paidAppStatus = notInstall, 종료
       └─ 설치 O
              ├─ 실행 중 → paidAppStatus = started, 추가 작업 없음
              └─ 미실행 → paidApp 실행 시도
                     └─ 성공(api 요청 수신 or 프로세스 확인) → paidAppStatus = started
```

## 메뉴바 아이콘

| `paidAppStatus` | 아이콘            |
| :-------------- | :---------------- |
| `started`       | 전체 아이콘       |
| `stopped`       | 잘린(크롭) 아이콘 |
| `notInstall`    | 잘린(크롭) 아이콘 |

## 유료 기능 클릭 처리

| `paidAppStatus` | 동작                                  |
| :-------------- | :------------------------------------ |
| `started`       | 해당 기능 실행                        |
| `stopped`       | paidApp 실행 시도 → 성공 시 기능 실행 |
| `notInstall`    | App Store 안내 다이얼로그 표시        |

## cliApp 메뉴 구조

```
fWarrangeCli (cliApp)
├── ℹ️ About fWarrangeCli                  {menu.about}
├── ─────
├── 🔁 Restore Last Layout       {restoreLast}        ⌥⌘F7
├── ⭐ Restore Default Layout    {restoreDefault}      ⇧⌘F7
├──          ⭐ {Default Layout name}   Default
├── {Recent N layouts}
├── ...and K more
├── ─────
├── 🖥️ Open Main Window          {showMain}            ⌃⇧⌘F7
├── 📷 Save Window Layout        {save}                ⌘F7
├── 👻 Daemon                                    ▶
│   ├── Status: Running · Port 3016 · Uptime …
│   ├── Restart Daemon
│   └── Pause / Resume REST API
├── ⚙️ Configuration                             ▶
│   ├── ⚙️ Settings…             {showSettings}
│   ├── 📄 Open Config File      {revealConfig}
│   ├── 📁 Open Data Folder
│   └── 📋 Open Log Folder
├── ─────
├── ☑ 🚀 Launch at Login                   {menu.launchAtLogin}
├── [paidApp 활성 시] Quit fWarrange       {menu.quit.fwarrange}      ⌘Q
├── [paidApp 활성 시] Quit All             {menu.quit.all}
└── [paidApp 비활성 시] Quit fWarrangeCli  {menu.quit.fwarrangecli}
```

* `Open Main Window`: paidApp 설치 시 실행, 미설치 시 App Store / Browse / Cancel 다이얼로그
* `Settings…`: paidApp 감지 시 paidApp Settings 위임, 미감지 시 cliApp 자체 설정

## 종료 항목 정책 (Termination Menu Items)

상위 SSOT인 [`paid_cli_protocol.md` §3.3](../../../_doc_design/paid_cli_protocol.md) 종료 정책 표를 메뉴 UI에 매핑한 규칙.

| `paidAppStatus` | 노출 항목                         | 단축키 표시 | 동작                                                                          |
| :-------------- | :-------------------------------- | :---------- | :---------------------------------------------------------------------------- |
| `started`       | `Quit fWarrange` (단독 종료)      | ⌘Q          | `PaidAppLauncher.terminate()` — paidApp만 종료, cliApp 잔존                   |
| `started`       | `Quit All` (paidApp + cliApp)     | (미표시)    | `quitApp()` 시퀀스 — paidApp + cliApp 모두 종료 (Issue68/Issue236 — 3단 폴백) |
| `stopped`       | `Quit fWarrangeCli` (cliApp 단독) | (미표시)    | cliApp 자기 종료만                                                            |
| `notInstall`    | `Quit fWarrangeCli` (cliApp 단독) | (미표시)    | cliApp 자기 종료만                                                            |

### 단축키 표시 원칙

* ⌘Q는 **paidApp 활성 시 `Quit fWarrange` 항목에만** 부여 (paidApp App 메뉴 Cmd+Q와 동일 의미체계 — paidApp 단독 종료)
* `Quit All` / `Quit fWarrangeCli`에는 **단축키 미부여** — 시스템 전체 stop의 오발화 방지
* paidApp 비활성 시에는 `Quit fWarrange` / `Quit All` 항목을 숨기고 `Quit fWarrangeCli` 단일 항목만 노출

## 메뉴 텍스트 다국어 지원 (Localization)

모든 메뉴 항목 텍스트는 다국어 리소스 키 참조로 노출. 하드코딩 금지.

### 신규 다국어 키

| 키                       | en (기본)          | ko (예시)         | 비고                           |
| :----------------------- | :----------------- | :---------------- | :----------------------------- |
| `menu.about`             | About fWarrangeCli | fWarrangeCli 정보 |                                |
| `menu.launchAtLogin`     | Launch at Login    | 로그인 시 실행    |                                |
| `menu.quit.fwarrange`    | Quit fWarrange     | fWarrange 종료    | paidApp 활성 시에만 노출       |
| `menu.quit.all`          | Quit All           | 모두 종료         | paidApp 활성 시에만 노출       |
| `menu.quit.fwarrangecli` | Quit fWarrangeCli  | fWarrangeCli 종료 | paidApp 비활성 시에만 노출     |

### 다국어 리소스 위치

* `cli/fWarrangeCli/*.lproj/Localizable.strings` 또는 `.xcstrings` (구현 선택)
* 지원 언어: paidApp `_public/localization/` 정책과 매트릭스 동기화 (최소 en/ko)
* 시스템 언어 변경 시 메뉴 즉시 갱신 — `NSMenu` rebuild 트리거 필요

## 단축키 체계

**F7 앵커 패턴** — 레이아웃 4개 액션 모두 `F7` 키에 모디파이어 조합.

| 액션                   | 단축키 | `_config.yml` 키         |
| :--------------------- | :----- | :----------------------- |
| Save Window Layout     | ⌘F7    | `saveShortcut`           |
| Restore Last Layout    | ⌥⌘F7   | `restoreLastShortcut`    |
| Restore Default Layout | ⇧⌘F7   | `restoreDefaultShortcut` |
| Open Main Window       | ⌃⇧⌘F7  | `showMainWindowShortcut` |

* **글로벌 핫키**: cliApp `HotKeyService`가 단일 진입점으로 등록
* 단축키 SSOT: `~/Documents/finfra/fWarrangeData/_config.yml`

## 관련 파일

| 파일                                             | 역할                          |
| :----------------------------------------------- | :---------------------------- |
| `cli/fWarrangeCli/Managers/MenuBarManager.swift` | cliApp 메뉴바 NSMenu 구현     |
| `cli/fWarrangeCli/Utils/KeySpecParser.swift`     | 단축키 파싱 유틸리티          |
| `cli/fWarrangeCli/Services/HotKeyService.swift`  | 글로벌 핫키 등록              |
| `cli/fWarrangeCli/Models/AppSettings.swift`      | `KeyboardShortcutConfig` 정의 |
| `~/Documents/finfra/fWarrangeData/_config.yml`   | 단축키 SSOT                   |
| `api/openapi_v2.yaml`                            | cliApp REST 엔드포인트        |
