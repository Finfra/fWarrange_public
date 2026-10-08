---
title: fWarrangeCli 메뉴바 사용법
description: fWarrangeCli 메뉴바 · 전역 단축키 · 명령행 · _config.yml (한국어)
date: 2026.10.08
---
# 메뉴바 사용법

fWarrangeCli 는 화면 상단 메뉴바에 아이콘 하나로 상주합니다. 창 저장·복원, 데몬(REST 서버) 관리, 설정 파일 열기를 이 메뉴에서 합니다. 레이아웃 목록·미니맵·설정 창 같은 GUI 는 래퍼 앱 **fWarrange** 의 기능입니다 — [fWarrange 안내 페이지](https://finfra.kr/product/fWarrange/kr/index.html).

## 메뉴 구성

| 메뉴                         | 기본 단축키 | 동작                                                                                           |
| ---------------------------- | ----------- | ---------------------------------------------------------------------------------------------- |
| ℹ️ fWarrangeCli 정보          | -           | 버전 정보. fWarrange 실행 중에는 **fWarrange 정보** 로 바뀜                                    |
| 🔁 최근 레이아웃 복구        | ⌥⌘F7        | 마지막으로 쓴 레이아웃 복원                                                                    |
| ⭐ 기본 레이아웃 복구        | ⇧⌘F7        | 기본 레이아웃 복원                                                                             |
| (레이아웃 목록)              | -           | 기본 레이아웃(`⭐ 이름   기본`) + 최근 5개. 클릭하면 복원. 나머지는 `...외 N개` 로 표시        |
| 🖥️ 메인 창 열기               | ⌃⇧⌘F7       | fWarrange 메인 창 표시 — **fWarrange 필요**                                                    |
| 📷 창 레이아웃 저장          | ⌘F7         | 현재 창 배치를 `YYYY-MM-DD-N` 이름으로 저장                                                    |
| 👻 데몬 ▸ 상태               | -           | `상태: 실행 중 · 포트 3016 · 가동 …`                                                           |
| 👻 데몬 ▸ 데몬 재시작        | -           | REST 서버 재시작                                                                               |
| 👻 데몬 ▸ REST API 일시 정지 | -           | REST 요청을 잠시 막음(다시 누르면 **REST API 재개**). 일시 정지 중에는 fWarrange 도 동작 안 함 |
| ⚙️ 설정 ▸ 환경설정…           | -           | fWarrange 설정 창 열기 — **fWarrange 필요**                                                    |
| ⚙️ 설정 ▸ 설정 파일 열기      | -           | Finder 에서 `_config.yml` 선택                                                                 |
| ⚙️ 설정 ▸ 데이터 폴더 열기    | -           | 레이아웃 YAML 이 있는 폴더 열기                                                                |
| ⚙️ 설정 ▸ 로그 폴더 열기      | -           | `~/Documents/finfra/fWarrangeData/logs/` (`wlog_cliApp.log`)                                   |
| 🚀 로그인 시 자동 시작       | -           | 체크 표시로 켜고 끔                                                                            |
| fWarrangeCli 종료            | -           | fWarrange 가 꺼져 있을 때 표시                                                                 |
| fWarrange 종료 · 모두 종료   | ⌘Q · -      | fWarrange 실행 중일 때 표시. **fWarrange 종료** 는 fWarrange 만, **모두 종료** 는 두 앱 모두   |

* 메뉴 언어는 `_config.yml` 의 `appLanguage`(기본 `system`)를 따릅니다
* **메인 창 열기** · **환경설정…** 은 fWarrange 를 여는 메뉴입니다. fWarrange 가 없으면 **App Store** · **찾아보기** · **취소** 를 고르는 안내 창이 나타납니다
* 단축키는 메뉴를 열지 않아도 어디서나 동작합니다(전역 단축키). 창을 옮기는 단축키는 손쉬운 사용 권한이 있어야 합니다

## 전역 단축키

| `_config.yml` 키         | 기본값  | 동작                    |
| ------------------------ | ------- | ----------------------- |
| `saveShortcut`           | `⌘F7`   | 창 레이아웃 저장        |
| `restoreDefaultShortcut` | `⇧⌘F7`  | 기본 레이아웃 복구      |
| `restoreLastShortcut`    | `⌥⌘F7`  | 최근 레이아웃 복구      |
| `showMainWindowShortcut` | `⌃⇧⌘F7` | fWarrange 메인 창       |
| `undoShortcut`           | (없음)  | 직전 창 배치로 되돌리기 |

기호는 `⌃`=Control · `⌥`=Option · `⇧`=Shift · `⌘`=Command 입니다. 줄을 지우면 그 단축키는 등록되지 않습니다. fWarrange 가 있으면 설정 › 단축키 탭에서 바꿀 수도 있습니다.

## 설정 파일 `_config.yml`

위치: `~/Documents/finfra/fWarrangeData/_config.yml` (메뉴 **설정 ▸ 설정 파일 열기**). fWarrangeCli 의 모든 설정이 이 파일 하나에 있으며, fWarrange 설정 창도 이 파일을 고칩니다.

| 키                                                   | 기본값                                | 설명                                                     |
| ---------------------------------------------------- | ------------------------------------- | -------------------------------------------------------- |
| `excludedApps`                                       | `Activity Monitor`, `System Settings` | 캡처·복원에서 뺄 앱                                      |
| `maxRetries` · `retryInterval`                       | `5` · `0.5`                           | 창 이동 검증 실패 시 재시도 횟수 · 간격(초)              |
| `minimumMatchScore`                                  | `30`                                  | 이 점수 미만의 창 매칭은 무시                            |
| `restServerEnabled` · `restServerPort`               | `true` · `3016`                       | REST API 서버 사용 여부 · 포트                           |
| `allowExternalAccess` · `allowedCIDR`                | `false` · `192.168.0.0/16`            | 외부(LAN) 접속 허용 · 허용 IP 대역                       |
| `dataStorageMode`                                    | `host`                                | `host`: 컴퓨터별 하위 폴더 · `share`: 여러 컴퓨터가 공유 |
| `launchAtLogin` · `appLanguage`                      | `true` · `system`                     | 로그인 시 자동 시작 · 메뉴 언어                          |
| `autoSaveOnSleep` · `maxAutoSaves` · `retentionDays` | `true` · `5` · `7`                    | 슬립 시 자동 저장 · 보관 개수 · 보관 일수                |
| `logLevel`                                           | `5`                                   | 0=verbose … 5=critical                                   |

## 명령행 (CLI)

fWarrangeCli 실행 파일에 인자를 주면 실행 중인 데몬에 REST 요청을 보내고 결과를 출력합니다. Homebrew 설치 시 경로는 다음과 같습니다.

```bash
FWC=/opt/homebrew/opt/fwarrange-cli/fWarrangeCli.app/Contents/MacOS/fWarrangeCli

$FWC status                 # 데몬 상태
$FWC list                   # 레이아웃 목록
$FWC capture myWorkspace    # 현재 창 배치 저장
$FWC restore myWorkspace    # 복원 (이름 생략 시 default)
$FWC show myWorkspace       # 레이아웃 상세
$FWC accessibility          # 손쉬운 사용 권한 확인
$FWC --help                 # 전체 명령 (rename·delete·windows·apps·mode·v2 settings 등)
```

옵션: `--port <포트>`(기본 3016) · `--host <호스트>` · `--pretty`(JSON 정리) · `-q`(종료 코드만).

## 다음 단계

* [REST API 사용법](05_API_Usage.md)
* [Claude Code Skill 사용법](06_Skill_Usage.md)
* [MCP 서버 사용법](07_MCP_Usage.md)
* GUI(레이아웃 목록·미니맵·설정 창): [fWarrange 안내 페이지](https://finfra.kr/product/fWarrange/kr/index.html)
