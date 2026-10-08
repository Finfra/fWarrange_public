---
title: fWarrange GUI 사용법
description: fWarrange GUI 앱 사용 방법 (한국어)
date: 2026-03-26
---
# GUI 사용법

fWarrange는 창 레이아웃을 저장하고 복원하는 macOS 앱입니다. 실제 창 캡처·복원은 무료 헬퍼 앱 **fWarrangeCli**가 수행하고, fWarrange는 그 결과를 보여 주고 조작하는 메인 창을 제공합니다. 메뉴바 아이콘은 fWarrangeCli의 것입니다.

> 아래 스크린샷은 fWarrange 1.1.3(영어 UI)에서 촬영했습니다.

## 헬퍼 연결 (fWarrangeCli)

fWarrange를 실행했을 때 fWarrangeCli가 설치되어 있지 않거나 실행 중이 아니면 안내 창이 나타납니다.

![fWarrangeCli 필요 안내](../img/06_helper-guide.png)

| 구역             | 내용                                                                                           |
| ---------------- | ---------------------------------------------------------------------------------------------- |
| 【Install】      | 설치되어 있지 않을 때만 실행 — `brew tap finfra/tap` · `brew install finfra/tap/fwarrange-cli` |
| 【Start】 방법 1 | Homebrew 서비스로 시작(권장) — `brew services start fwarrange-cli`                             |
| 【Start】 방법 2 | Spotlight(⌘Space)에서 `fWarrangeCli` 입력 후 Enter                                             |
| 【Start】 방법 3 | Finder에서 `/opt/homebrew/opt/fwarrange-cli/` 또는 `/Applications/` 의 앱을 직접 실행          |
| 버튼             | **Start Service**(서비스 시작) · **Download from GitHub** · **Close**                          |

연결되기 전까지 하단 상태바에 `Waiting for fWarrangeCli connection...` 이 표시됩니다. 연결되면 상태바 오른쪽에 fWarrangeCli의 손쉬운 사용(Accessibility) 권한 상태가 나타납니다.

## 메인 화면

![메인 화면](../img/01_main-overview.png)

| 영역     | 설명                                                                                                                       |
| -------- | -------------------------------------------------------------------------------------------------------------------------- |
| 사이드바 | 저장된 레이아웃 목록(이름 · 창 수 · 저장 시각)과 검색창                                                                    |
| 미니맵   | 선택한 레이아웃의 창 배치를 모니터 단위로 표시. 우상단 **Apps Visible** 로 창 표시를 켜고 끄며, 우하단 **Restore** 로 복원 |
| 창 목록  | 앱별로 묶인 창 목록 — 모니터 번호 · 위치 · 크기 · 창 ID. 항목 오른쪽 휴지통으로 레이아웃에서 창을 뺌                       |
| 상태바   | 작업 상태 메시지와 fWarrangeCli 권한 상태                                                                                  |

### 툴바

| 버튼                 | 동작                                                                                     |
| -------------------- | ---------------------------------------------------------------------------------------- |
| **Default**          | 기본 레이아웃으로 복원 (기본 레이아웃을 지정하지 않으면 비활성)                          |
| **Restore Selected** | 선택한 레이아웃을 복원 — 창 목록에서 체크한 창이 있으면 그 창만 복원                     |
| **New Save**         | 현재 창 배치를 새 레이아웃으로 저장                                                      |
| **Clean Up**         | 선택 · 마지막 · 기본 레이아웃 3개만 남기고 나머지를 삭제 (레이아웃이 4개 이상일 때 활성) |
| ⚙️ (설정)             | 설정 창 열기 (⌘,)                                                                        |

툴바 버튼의 표시 방식(아이콘만 · 이름+아이콘 · 이름만)은 설정 › 고급 탭에서 바꿀 수 있습니다.

### 레이아웃 목록 메뉴

레이아웃을 우클릭하면 다음 메뉴가 나타납니다.

* **복구** · **기본 레이아웃으로 설정** · **이름 변경** · **삭제**
* ⌘클릭(개별) 또는 ⇧클릭(범위)으로 여러 레이아웃을 고르면 **선택 항목 복구(N개) · 선택 항목 삭제(N개) · 선택 해제** 로 한 번에 처리합니다

### 선택 복원

창 목록에서 원하는 창만 체크한 뒤 **Restore Selected** 를 누르면 체크한 창만 원래 위치로 돌아갑니다. 버튼에 선택한 창 수가 함께 표시됩니다.

![선택 복원](../img/02_selective-restore.png)

### 새 레이아웃 저장

**New Save** 를 누르면 저장 창이 열립니다. 이름은 날짜 기반으로 미리 채워지며, **Use app filter** 를 켜면 저장할 앱을 골라 일부 앱의 창만 저장할 수 있습니다.

![새 레이아웃 저장](../img/03_save-layout.png)

## 설정 (5탭 구성)

툴바의 ⚙️ 버튼 또는 ⌘, 로 설정 창을 엽니다. 탭은 ⌘1 ~ ⌘5 로 바로 이동할 수 있습니다. 설정값은 fWarrangeCli 설정 파일 `~/Documents/finfra/fWarrangeData/_config.yml` 에 저장됩니다.

### 탭 1: 일반 (General)

![일반 설정](../img/05_settings-general.png)

| 항목                        | 기본값             | 설명                                                                                                           |
| --------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------- |
| 언어 (Select Language)      | 시스템             | 앱 표시 언어. 바꾸면 앱 재시작 후 적용                                                                         |
| 저장 모드 (Storage Mode)    | Host (Per-machine) | **Host**: 컴퓨터마다 하위 폴더(`fWarrangeData/<호스트명>/`)에 저장 · **Share**: 여러 컴퓨터가 같은 폴더를 공유 |
| 데이터 경로                 | (비어 있음)        | **Change** 로 폴더 지정. 비워 두면 `~/Documents/finfra/fWarrangeData` 사용                                     |
| 권한 (Permissions)          | -                  | fWarrangeCli의 손쉬운 사용(Accessibility) 권한 상태                                                            |
| 자동 실행 (Launch at Login) | 켬                 | macOS 로그인 시 fWarrange 자동 실행                                                                            |
| 테마 (Appearance Mode)      | System Default     | 시스템 기본 / 라이트 / 다크 — 즉시 적용                                                                        |
| 앱 전환기 (Show in ⌘+Tab)   | 켬                 | 끄면 ⌘Tab 목록과 Dock에서 사라지고 fWarrangeCli 메뉴바에서만 열 수 있음                                        |

### 탭 2: 단축키 (Shortcuts)

![단축키 설정](../img/07_settings-shortcuts.png)

각 항목을 클릭해 단축키를 바꿉니다. **전역 단축키**는 fWarrangeCli가 등록하므로 fWarrange가 비활성 상태여도 동작하고, **로컬 단축키**는 fWarrange 창이 활성일 때만 동작합니다.

| 구분 | 기능                            | 기본 단축키 | 설명                            |
| ---- | ------------------------------- | ----------- | ------------------------------- |
| 전역 | 저장 (Save)                     | ⌘F7         | 현재 창 배치 저장               |
| 전역 | 기본 복원 (Restore Default)     | ⇧⌘F7        | 기본 레이아웃 복원              |
| 전역 | 마지막 복원 (Restore Last)      | ⌥⌘F7        | 마지막으로 쓴 레이아웃 복원     |
| 전역 | 메인 창 열기 (Open Main Window) | ⌃⇧⌘F7       | fWarrange 메인 창 표시          |
| 전역 | 되돌리기 (Undo)                 | 미지정      | 창 재배치 직전 상태로 되돌리기  |
| 로컬 | 선택 복원 (Restore Selected)    | 미지정      | 툴바의 Restore Selected 와 같음 |

> 스크린샷은 메인 창 열기를 해제한 상태입니다. 단축키는 `_config.yml` 에서 줄을 지우면 등록이 해제됩니다.

### 탭 3: 복원 (Restore)

![복원 설정](../img/04_settings-restore.png)

| 항목                                 | 기본값                            | 설명                                                                              |
| ------------------------------------ | --------------------------------- | --------------------------------------------------------------------------------- |
| 재시도 횟수 (Retry Count)            | 5                                 | 창 이동이 검증되지 않을 때 최대 재시도 횟수                                       |
| 재시도 간격 (Retry Interval)         | 0.5초                             | 재시도 사이 대기 시간                                                             |
| 최소 매칭 점수 (Min Match Score)     | 30                                | 이 점수 미만의 창 매칭은 무시                                                     |
| 기본 제외 앱 (Default Excluded Apps) | Activity Monitor, System Settings | 캡처·복원에서 뺄 앱. 이름 입력 후 **Add**, **Restore Defaults** 로 기본 목록 복귀 |

창 매칭 점수는 창 ID 일치 100 · 제목 완전 일치 90 · 정규식 80 · 포함 70 · 크기·비율·면적 유사도 60~30 순입니다.

### 탭 4: API

![API 설정](../img/08_settings-api.png)

| 항목          | 기본값 | 설명                                         |
| ------------- | ------ | -------------------------------------------- |
| 상태 (Status) | -      | fWarrangeCli 연결 상태 · 버전 · 가동 시간    |
| 포트 (Port)   | 3016   | REST API 수신 포트. 바꾸면 앱 재시작 후 적용 |
| 테스트 (Test) | -      | 동작 확인 명령 `curl http://localhost:3016/` |

REST 서버는 fWarrangeCli에 내장되어 **기본으로 켜져 있습니다**. 서버 끄기·외부 접속 허용·허용 IP 대역은 GUI가 아니라 `_config.yml` 에서 지정합니다.

| `_config.yml` 키      | 기본값           | 설명                    |
| --------------------- | ---------------- | ----------------------- |
| `restServerEnabled`   | `true`           | REST API 서버 사용 여부 |
| `allowExternalAccess` | `false`          | LAN 등 외부 접속 허용   |
| `allowedCIDR`         | `192.168.0.0/16` | 외부 접속 허용 IP 대역  |

### 탭 5: 고급 (Advanced)

![고급 설정](../img/09_settings-advanced.png)

| 구역           | 항목                                   | 기본값    | 설명                                                |
| -------------- | -------------------------------------- | --------- | --------------------------------------------------- |
| 로그           | 로그 위치 · **Open Folder**            | -         | `~/Library/Logs/fWarrange/wlog.log`                 |
| 로그           | 로그 모드 (Log Mode)                   | CRITICAL  | 기록할 최소 로그 수준                               |
| 기타 옵션      | 복원 버튼 스타일                       | Name+Icon | 툴바 버튼 표시 — 아이콘만 / 이름+아이콘 / 이름만    |
| 기타 옵션      | 삭제 확인 (Delete Confirmation)        | 켬        | 레이아웃 삭제·정리 전 확인 창 표시                  |
| 기타 옵션      | 우클릭 전환 (Right-click switch)       | 끔        | 보조 모니터에서 우클릭 시 메인 디스플레이로 전환    |
| 자동 저장      | 슬립 시 자동 저장 (Auto-save on sleep) | 켬        | 슬립·로그아웃 때 현재 창 상태를 자동 저장           |
| 자동 저장      | 최대 자동 저장 수                      | 5         | 보관할 자동 저장본 최대 개수                        |
| 자동 저장      | 자동 캡처 보관 기간                    | 7일       | 자동 캡처된 레이아웃을 이 기간 뒤 삭제 (0 = 무제한) |
| Dangerous Zone | Remove All Layouts                     | -         | 저장된 레이아웃 YAML 파일 전체 삭제                 |
| Dangerous Zone | Factory Reset                          | -         | 모든 설정을 기본값으로 초기화                       |

## 일반적인 사용 흐름

1. 원하는 대로 창을 배치합니다
2. **New Save**(또는 ⌘F7)로 현재 배치를 저장합니다
3. 필요할 때 사이드바에서 레이아웃을 골라 **Restore**(또는 단축키)로 복원합니다
4. 자주 쓰는 레이아웃은 우클릭 › **기본 레이아웃으로 설정** 후 **Default**(⇧⌘F7)로 바로 복원합니다

## 다음 단계

* [REST API 사용법](05_API_Usage.md)
* [Skill 사용법](06_Skill_Usage.md)
* [MCP 서버 사용법](07_MCP_Usage.md)
