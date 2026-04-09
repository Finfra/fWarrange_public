---
name: Issue
description: fWarrangeCli 이슈 관리
date: 2026-04-07
---

# Issue Management

- Issue HWM: 17
- Save Point: - 2026-04-08 (d78b046)

# 🤔 결정사항

# 🌱 이슈후보

# 🚧 진행중

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료

## Issue17: 에러 메시지 한국어 통일 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: REST API 및 CLI의 영어 에러 메시지를 한국어로 통일
* 구현 명세:
    - `RESTServer.swift`: `methodNotAllowed()` 에러 메시지 "Method Not Allowed" → "허용되지 않는 HTTP 메서드입니다"
    - `CLIHandler.swift`: `exitError()` prefix "Error:" → "오류:"
    - 기타 에러 메시지는 이미 한국어 (13개 핸들러 확인 완료)
* 검증:
    - Release 빌드 성공, API 테스트 15개 엔드포인트 전체 PASS

## Issue16: 존재하지 않는 레이아웃 삭제 시 HTTP 404 응답 표준화 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: `DELETE /layouts/{name}` 호출 시 해당 레이아웃이 존재하지 않으면 HTTP 404를 반환하도록 표준화
* 구현 명세:
    - `RESTServer.swift`: `handleDeleteLayout`에서 `getLayouts().contains` 사전 검사 후 `.notFound()` 반환
    - `openapi.yaml`: DELETE /layouts/{name} 경로에 404 응답 코드 + ErrorResponse 스키마 명세
    - `E03.layout-delete-404.sh`: 존재하지 않는 레이아웃 삭제 시 404 검증 에러 테스트
* 검증:
    - API 테스트 PASS

## Issue15: 기본 레이아웃 관리 API 추가 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: 기본 레이아웃을 지정/조회하는 REST API 엔드포인트 추가
* 구현 명세:
    - `RESTServer.swift`: `GET /settings/default-layout` + `PUT /settings/default-layout` 라우팅 및 핸들러
    - `RESTServerHandlers`: `getDefaultLayoutName`, `setDefaultLayoutName` 클로저
    - `AppState.swift`: `settingsService` 기반 실제 저장/로드 연결
    - `openapi.yaml`: 엔드포인트 명세
    - `12.default-layout.sh`: GET/PUT 테스트 + 원복
* 검증:
    - API 테스트 PASS

## Issue14: API/CLI 기본 레이아웃 이름 불일치 통일 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: API/CLI 모두 기본 레이아웃 이름을 `default`로 통일
* 구현 명세:
    - `RESTServer.swift`: `handleCapture` 기본값 `"default"`
    - `CLIHandler.swift`: capture 커맨드 기본값 `"default"`
    - `openapi.yaml`: CaptureRequest 스키마에 `defaults to "default"` 명시
    - `validation_strategy.md`: 양쪽 `default` 통일 완료 기록
* 검증:
    - API/CLI 양쪽 기본값 일치 확인

## Issue13: Paid 버전 관련 불필요 코드 삭제 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: `paid_version.md` 설계 문서 기준으로 불필요한 Paid 관련 코드 정리
* 구현 명세:
    - `paid_version.md`: 관련 소스 파일 테이블에서 실제 미존재 함수 `isPaidAppRunning` 참조 삭제
    - Swift 소스에는 삭제 대상 없음 (모든 함수가 실제 사용 중)
    - `com.finfra` 레거시 번들ID 없음 확인
* 검증:
    - Release 빌드 성공

## Issue9: 메뉴바 Settings/Management Window/About 버튼 추가 — Paid 버전 연동 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: 메뉴바에 Settings, Management Window, About 3개 버튼을 추가하고 paid 버전 설치 여부에 따라 기능 분기
* 구현 명세:
    - `MenuBarView.swift`: Settings / Management Window / About 3개 버튼 UI, `tryLaunchPaidFeature()` 호출, `showPaidOnlyAlert()` (App Store/Locate/Cancel), `bundleIdentifier == "kr.finfra.fWarrange"` 검증
    - `AppState.swift`: `detectPaidApp()` 경로 기반 감지 + `launchPaidApp()` 실행 + `tryLaunchPaidFeature()` 안내 알림
* 검증:
    - 3개 버튼 동작 확인, Bundle ID `kr.finfra` 올바름

## Issue12: CLI 커맨드 테스트 스크립트 체계 구축 (등록: 2026-04-08, 해결: 2026-04-08, commit: TBD) ✅

* 목적: apiTest와 동일한 체계로 CLI 커맨드 테스트 가능하게 함
* 구현 명세:
    - `cli/_tool/cmdTestDo.sh`: 전체/개별/에러 테스트 실행기
    - `cli/_tool/cmdTest/`: 정상 18개 + 에러 7개 테스트 스크립트
    - 시나리오 테스트 (API + CLI): 레이아웃 CRUD + 복구 + 실패 검증 9/9 PASS
* 검증:
    - API 시나리오 9/9 PASS, CLI 시나리오 9/9 PASS
    - 리포트: `cli/_doc_work/report/check_api_cmd_report.md`

## Issue10: 앱 시작 시 Paid 버전 감지 → fWarrange 실행 후 메뉴바에서 제거 (등록: 2026-04-08, 해결: 2026-04-08, commit: d78b046) ✅

* 목적: fWarrangeCli 시작 시 fWarrange(Paid) 감지되면 fWarrange를 실행하고 fWarrangeCli는 메뉴바에서 제거
* 구현 명세:
    - `AppState.swift`: terminate() 제거 → `hideMenuBar` 플래그로 메뉴바만 숨김, REST 서버 유지
    - `fWarrangeCliApp.swift`: `MenuBarExtra(isInserted:)` 바인딩으로 동적 제어
    - `detectPaidApp()`: `NSWorkspace` bundleID 검색 제거, `/Applications/` 명시적 경로만 검색 (~/Library 제외)
    - Paid 앱 실행 성공 시에만 메뉴바 숨김, 실패 시 메뉴바 유지
* 검증:
    - Paid 앱 미실행 시: 메뉴바 아이콘 표시, REST API 정상
    - Paid 앱 실행 성공 시: 메뉴바 숨김, REST API 정상 유지

## Issue11: 메뉴바 아이콘 대각선 클리핑 적용 (등록: 2026-04-08, 해결: 2026-04-08, commit: c4bd7a1) ✅

* 목적: 메뉴바 아이콘을 대각선으로 잘라서 아래 부분을 숨김 처리
* 구현 명세:
    - fWarrangeCliApp.swift: `makeMenuBarIcon()` 정적 메서드 추가
    - `rectangle.3.group` SF Symbol에 `NSBezierPath` 클리핑 적용 (왼쪽 하단 ~ 오른쪽 40% 높이 대각선)
    - `MenuBarExtra` label을 커스텀 `Image(nsImage:)` 방식으로 변경
* 검증:
    - Debug 빌드 및 실행 확인

## Issue6: CLI 커맨드 인터페이스 구현 (등록: 2026-04-08, 해결: 2026-04-08, commit: 584819e) ✅

* 목적: 터미널에서 `fWarrangeCli <command>` 형태로 직접 명령 실행 가능하게 함
* 구현 명세:
    - CLIHandler.swift: CLI 커맨드 파싱 및 REST API 호출 핸들러
    - fWarrangeCliApp.swift: ProcessInfo 기반 CLI/GUI 모드 분기
    - REST API 1:1 대응 — 내부적으로 localhost REST API 호출
* 검증:
    - 설계 문서 대비 전체 커맨드 구현 확인 (정보/레이아웃/창/시스템)
    - 공통 옵션 (--port, --host, --pretty, -q) 구현 확인

## Issue8: 서비스 관리 방식 전환 — LaunchAgent/brew service → 앱 내 LoginItem (등록: 2026-04-08, 해결: 2026-04-08, commit: 7ae9a38) ✅

* 목적: OS 시작 시 자동 실행을 외부 서비스(LaunchAgent, brew services) 대신 앱 내 SMAppService(LoginItem)로 관리
* 구현 명세:
    - cli/service/ 전체 삭제 (LaunchAgent plist, install.sh, uninstall.sh)
    - Formula service 블록 제거 (Homebrew는 설치만 담당)
    - AppSettings.launchAtLogin 필드 추가
    - AppState: SMAppService 기반 syncLaunchAtLogin/setLaunchAtLogin
    - MenuBarView: "로그인 시 자동 시작" 토글 추가
    - README 문서 업데이트
* 검증:
    - Debug 빌드 성공 확인

## Issue7: 단축키 설정 human-readable 형식 지원 (등록: 2026-04-08, 해결: 2026-04-08, commit: e3510da) ✅

* 목적: _config.yml의 단축키 설정을 사용자가 직접 수정할 수 있는 형식으로 변경
* 구현 명세:
    - AppSettings.swift: `KeyboardShortcutConfig.from(displayString:)` 역매핑 메서드 추가
    - SettingsService.swift: 저장 시 `"⌘F7"` 형식, 파싱 시 레거시(`98:1048576`) + human-readable 양쪽 지원
* 검증:
    - Debug 빌드 성공 확인
    - _config.yml 형식 변환 확인 (`98:1048576` → `"⌘F7"`)

## Issue4: GET /settings 엔드포인트 추가 (등록: 2026-04-08, 해결: 2026-04-08, commit: f953436) ✅

* 목적: 현재 앱 설정값과 데이터 경로를 REST API로 조회 가능하게 함
* 구현 명세:
    - RESTServer.swift: `GET /api/v1/settings` 라우트 + 핸들러 추가
    - openapi.yaml: `/settings` 엔드포인트 정의, 미사용 `/locale` 제거
* 검증:
    - `01.settings.sh` 테스트 스크립트 실행 확인

## Issue3: openapi.yaml 기반 API 테스트 스크립트 구현 (등록: 2026-04-07, 해결: 2026-04-08, commit: 67cd061) ✅

* 목적: apiTest_plan.md에 정의된 18개 엔드포인트 테스트 스크립트를 모두 생성하고, apiTestDo.sh로 순차/개별 실행 가능하게 함
* 구현 명세:
    - Shell: cli/_tool/apiTest/ 내 18개 정상 + 7개 에러 테스트 스크립트 생성
    - apiTestDo.sh 전체/개별 실행 래퍼 추가
* 검증:
    - apiTestDo.sh로 전체 실행 테스트

## Issue5: Homebrew service 방식 fWarrangeCli 서비스 관리 (등록: 2026-04-08, 해결: 2026-04-08, commit: 5fd0601) ✅

* 목적: `brew services start/stop/restart fWarrangeCli` 명령으로 fWarrangeCli 데몬을 관리 가능하게 함
* 구현 명세:
    - Formula/fWarrangeCli.rb: pre-built .app 설치 + brew services 지원
    - cli/service/fWarrangeCli.plist: LaunchAgent plist 생성
    - cli/service/install.sh: plist 설치 스크립트
    - cli/service/uninstall.sh: plist 제거 스크립트
* 검증:
    - brew install/services start/stop/restart/info 동작 확인
    - 로컬 tap (finfra/tap) 테스트 완료

## Issue2: 환경변수 fWarrangeCli_config 기반 데이터 경로 설정 (등록: 2026-04-07, 해결: 2026-04-07, commit: 13fc324) ✅

* 목적: 환경변수 fWarrangeCli_config로 데이터 디렉토리 경로를 외부에서 지정 가능하게 함
* 상세:
    - 환경변수 미설정 시 ~/Documents/finfra/fWarrange/ 기본값 사용
    - 기존 기본 경로 fWarrangeData → fWarrange 변경
* 구현 명세:
    - LayoutStorageService.swift: resolveDefaultBaseDirectory()에 환경변수 우선 확인 로직 추가
    - Logger.swift: 로그 디렉토리 경로도 동일 환경변수 로직 적용

## Issue1: health 엔드포인트에 기본 정보 추가 (등록: 2026-04-07, 해결: 2026-04-07, commit: 748eaf2) ✅

* 목적: GET / health 응답에 layout_count, uptime_seconds 필드 추가
* 구현 명세:
    - RESTServer.swift handleHealthCheck에 uptime_seconds, layout_count 추가
    - apiTest.sh 테스트 스크립트 생성

# ⏸️ 보류

# 🚫 취소

# 📜 참고
