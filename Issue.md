---
name: Issue
description: fWarrangeCli 이슈 관리
date: 2026-04-07
---
# Issue Management
* Issue HWM: 118
* Checkpoints: 2026-06-22 (Issue85·Issue83 종결 — MCP v2 마이그레이션 + npm 1.0.2 배포, Hash b587581)
  - 5012bb2 (2026-09-05) - Chore: checkpoint — Issue94 등록 + 결정사항 링크 표 정리 (VSCode 설정 동반)

# 🤔 결정사항

결정은 **각 정본 문서**에 산다 — 여기 사본을 두지 않는다(2026.09.02 정리).

| 결정                                                                                  | 정본                                                                       |
| :------------------------------------------------------------------------------------ | :------------------------------------------------------------------------- |
| paidApp↔cliApp 연동은 상위 레포 프로토콜 문서 기준                                    | [paid_cli_protocol.md](../_doc_arch/paid_cli_protocol.md) — 상위 메인 레포 |
| 메뉴바는 `cli/_doc_arch/menuBar_enhance.md` 기준 (로컬 SSOT · gitignored)             | [menuBar_enhance.md](cli/_doc_arch/menuBar_enhance.md)                     |
| Issue72_1 베이스라인 검토일 2026-05-22 — 1주 실사용 수집 후 Phase 2~7 우선순위 재조정 | Issue72_1 본문                                                             |
| Issue72_6 — cliApp(non-sandbox)에서 CGS 계열 비공개 API 사용 합의 (2026-05-16)        | Issue72_6 본문                                                             |

# 🌱 이슈후보

# 🚧 진행중

# 📕 중요

# 📙 일반

## Issue114: 1.1.2 공개본 출고 테스트 발견 결함 — 단일 창 복원 판정·테스트 도구 위험·README 불일치 (등록: 2026-09-29)
* 목적: prj5#Issue107 jma 출고 테스트(2026-09-29, release/1.1.1 `af8537b` = 공개 1.1.2) 결과 기록 — 증거 result: partial
* 상세:
    - ① 단일 창 레이아웃을 다른 위치에서 복원하면 `noMatch`/`windowNotFound`·succeeded 0 보고, 실제로는 근사 이동 — 3회 재현(prj16#Issue283 ②). 1.1.1 부터인지는 미확인
    - ② 1.1.2 공개본에 남은 기지 결함: Issue108 ②(클린 설치 첫 기동 `_config.yml` 이 호스트 폴더로 이동 → paidApp 목록에 `_config` 레이아웃) · Issue111(cliApp 재기동 뒤 `not_running`) · Issue112(publish dry-run 요약 거짓 ✅) — develop 수정분이 1.1.2 에 없다
    - ③ `fwc-test.sh` API 단계 `delete-all` 이 실제 사용자 데이터 폴더 레이아웃을 전부 지운다 · API·CMD 단계를 응답 내용이 아니라 실행 건수로 PASS 판정
    - ④ `cli/README.md` 불일치 — v1 «maintained» 인데 실제 410 · «brew services 불필요» 인데 Formula 에 service 정의 · 수동 기동 예시에 개발 경로 `/Applications/_nowage_app/`
    - ⑤ `jma-fwarrange-deploy.sh` 기본값이 jm4→jma rsync 라 jma 의 release 소스를 jm4 develop 으로 덮는다(이번엔 `--no-sync` 로 우회)
* 증거: `cli/_doc_work/_release/v1.1.2/release-test_1.1.2_jma-2026.09.29.md` · prj16 `_doc_work/_release/v1.1.2/jma-logs_2026.09.29/`

# 📗 선택

## Issue118: [Test] `fwc-run-xcode.sh` 가 Xcode 에 열린 문서가 없는 차가운 상태에서 workspace 로드 60s 대기를 넘겨 `fwc-test.sh` 가 빌드 전에 실패 (등록: 2026-10-04)
* 목적: R1 4행(`app-bundle-all-clear`)이 코드와 무관하게 환경 상태로 실패한다 — 출고 테스트마다 재현 가능
* 상세:
    - 재현(jma 2026-10-04 R1 사전 점검): Xcode 실행 중·열린 문서 0 → `fwc-test.sh` Step 2 `[open] fWarrangeCli.xcodeproj 오픈 중...` → `execution error: Xcode workspace did not finish loading within 60s (-2700)` → `❌ 빌드 실패 — 중단`
    - 우회: 대상 프로젝트를 Xcode 에 미리 열고 로드 완료 후 실행 → ALL CLEAR 6/0 (`cli/_doc_work/_release/v1.1.2/release-test_1.1.2_r1pre-2026.10.04.md` 4행)
    - 연관: Issue114 ③(`fwc-test.sh` delete-all 이 실 데이터 폴더를 지움)
* 구현 명세:
    - 로드 대기를 문서 유무·Xcode 기동 직후 여부에 따라 연장하거나, `loaded` 폴링 상한을 설정값으로
    - red 먼저: Xcode 문서 0 상태에서 `fwc-run-xcode.sh build-deploy` 가 성공하는지(jma)

# ✅ 완료

## Issue117: [Security] 레이아웃 이름에 `../` 가 들어가면 base 밖에 `*.yml` 쓰기·삭제·이름변경 가능 — 이름 검증 부재 (등록: 2026-10-04, 완료: 2026-10-04, Hash: 38898c6, 20c9d38) ✅
* 목적: Issue115 가 `dataDirectoryPath` 로 base 를 옮기는 길을 막았지만, 같은 공격자(토큰 없는 REST, CIDR 만 검사)가 레이아웃 **이름**으로 같은 결과를 얻는다 (Issue115 적대적 검증 2026-10-04 — 기존 결함이라 범위 밖으로 분리)
* 상세:
    - `LayoutStorageService` 의 save·load·delete·rename 이 `dataDirectory.appendingPathComponent("\(name).yml")` — 이름 검증이 없다(최초 커밋 48e01d7 부터)
    - URL 경로는 `/` 로 쪼개 `..` 단독만 들어오지만, JSON body 의 이름(`POST /capture {name}`·`PUT /layouts/{name} {newName}` 등)은 `../../x` 를 그대로 받는다 → `{data}/../../x.yml` 쓰기·이동
* 구현 명세:
    - 이름 검증 단일 지점: 빈 값·`/`·`\0`·`..` 구성요소·선행 `.` 거부, 길이 상한. REST 는 400, 저장소 계층도 방어(이중)
    - red 먼저: `../escape` 이름으로 save·rename 하면 dataDirectory 밖에 파일이 생기지 않는다
    - openapi_v2 의 name 제약 기술 동기
* 결과 (2026-10-04, **38898c6** · 후속 **20c9d38** · release/1.1.1 병합 23873c2):
    - `StorageName` 단일 판정(`LayoutStorageService.swift`): 새 이름(save·rename 대상·REST 생성)은 `rejection`(빈/공백·`/`·NUL·`.`/`..`·255바이트 초과), 기존 항목(load·delete·rename 원본)은 `escapeRejection` 만 + `fileURL` 이 결과 경로가 저장 폴더 밖이면 throw
    - 범위 확대: 같은 결함이 **Mode 저장소**(`ModeStorageService` — `{base}/{host}/modes/{name}.yml`)에도 있어 함께 수정. REST 400: capture `name` · layout rename `newName` · mode 생성 `name`. openapi_v2 동기
    - 적대적 검증(우회·회귀 리뷰 + 지적별 반박): 우회 0건 · 회귀 1건(nit — 이전 버전의 공백 이름 항목이 열기·삭제·이름변경 불가) → 20c9d38 에서 기존 항목은 탈출 판정만으로 분리
    - TDD: 재생목록 23행 red(4테스트 9단언 — 실제로 폴더 밖 쓰기·이동·삭제 재현) + 후속 red(3) → green · jm4·**jma XCTest 124/124**
    - jma `/run`(brew local) FAIL 0 · REST E2E: `../` 이름 capture·mode 생성·rename 400, 일반 이름 capture→rename→delete 200, 잔여 파일 0. E2E capture 가 비어 있던 `defaultLayoutName` 을 테스트 이름으로 채워 원복(키 제거)함 — capture 의 «기본값 없으면 새 이름 지정»·rename/delete 가 기본값을 따라가지 않는 동작은 기존 동작(범위 밖)

## Issue116: [Bug] 접근성 시작 안내 `show()` 에 중복 표시 가드가 없어, Issue110 이후 안내 창이 겹쳐 뜰 수 있음 (등록: 2026-10-04, 완료: 2026-10-04, Hash: d079be1, fb4cbbd) ✅
* 목적: Issue110 이 안내를 run loop 블록(`RunLoop.main.perform(inModes: [.common])`)으로 옮기면서, 열린 안내의 모달 루프 안에서 다음 안내가 실행된다 — 예전엔 직렬 메인 큐가 자연히 하나씩만 띄웠다 (ultrareview 2026-10-03 — nit)
* 상세:
    - `isPresenting` 가드는 `showPermissionLost()` 에만 있고 `show(windowManager:)` 는 확인·설정 둘 다 안 한다(`AccessibilityGuidePresenter.swift:24-61`)
    - 결과: `show()` 연속 호출, 또는 시작 안내와 권한 상실 안내가 겹치면 알림이 쌓인다
* 구현 명세:
    - 두 안내가 같은 가드를 공유 — 접근성 안내는 한 번에 하나
    - 테스트 시임: 모달 실행(`runModal`)을 주입 가능하게, 설정 열기 동작을 클로저로 분리
    - red 먼저: 안내 표시 중(중첩 modal-panel run loop) 다시 `show()` 를 부르면 알림이 1개만 뜬다 — 재생목록 22행
* 결과 (2026-10-04, **d079be1** · 테스트 보강 **fb4cbbd** · release/1.1.1 병합 805b50a·8e085fd):
    - `scheduleExclusive`: 시작 안내·권한 상실 안내가 같은 `isPresenting` 가드 — 접근성 안내는 한 번에 하나. 시임 `runModal` 주입 · `show(openSettings:)` 분리
    - TDD: 재생목록 22행 red(알림 3개 겹침 — 리뷰 지적 실재 확인) → green. 테스트 감사 관찰 반영 fb4cbbd: 중첩 요청 처리 확인 감시 블록(공허한 통과 방지)
    - 검증: jm4 XCTest 117/117 · jma XCTest 117/117. 실기 E2E 미실시 — jma 접근성 `granted` 라 안내가 뜨지 않음(TCC 리셋은 사람 재승인 필요해 생략)

## Issue115: [Security] `dataDirectoryPath` 가 경로 검증 없이 레이아웃 base 가 됨 — 토큰 없는 REST PATCH 로 임의 폴더 지정·첫 기동 마이그레이션이 그 폴더의 `*.yml` 을 옮김 (등록: 2026-10-04, 완료: 2026-10-04, Hash: f4d83b5, 2d88660) ✅
* 목적: Issue108 ① 이후 `dataDirectoryPath` 가 실제로 쓰이게 되면서, 검증 없는 경로가 파일시스템 동작(폴더 생성·yml 이동·저장·삭제)으로 이어진다 (ultrareview 2026-10-03, release/1.1.1 `f97926d` — normal)
* 상세:
    - `resolveLayoutBaseDirectory()`(`LayoutStorageService.swift:71-86`)는 trim·`~` 확장 뒤 `createDirectory(withIntermediateDirectories: true)` 만 한다 — 홈 밖·시스템 폴더·심볼릭 링크 우회를 거르지 않는다
    - 값은 `PATCH /api/v2/settings`·`/settings/general` 로 바뀐다(`RESTServer.swift:730`). REST 는 인증 토큰이 없고 CIDR 만 본다 — `allowExternalAccess` 를 켜면 허용 대역 누구나 바꿀 수 있다(기본 false, 127.0.0.1)
    - 코드 판독 추가 발견: 다음 기동 때 `AppState` 가 그 base 에 `migrateRootDataIfNeeded()` 를 돌려 **루트의 `_` 아닌 `*.yml` 전부를 `<base>/<host>/` 로 옮긴다** — 사용자가 정상 선택한 일반 폴더(ex) 동기화 폴더)에서도 남의 yml 이 옮겨지고, 이후 delete-all 대상이 된다. 레거시 마이그레이션(Issue166_3)은 기본 설정 폴더에만 의미가 있다
* 구현 명세:
    - 검증 단일 지점 `YAMLLayoutStorageService.validateDataDirectoryPath` — 절대 경로(`~` 확장 후), `..` 정규화 + 존재하는 조상의 심볼릭 링크 해소 뒤 **홈 디렉토리 또는 `/Volumes` 의 하위**(그 자체는 불가)만 허용
    - 기동 시: 거부되면 경고 로그 후 설정 폴더 유지(`resolveLayoutBaseDirectory`)
    - PATCH 시: 거부되면 `400` — 디스크에 저장하지 않는다. openapi_v2 동기
    - 레거시 루트 마이그레이션은 레이아웃 base 가 설정 폴더일 때만 돈다(`_share` 복사는 fWarrange 소유 하위 폴더라 유지)
    - red 먼저: ① 허용 루트 밖(`/private/tmp`)·심볼릭 링크 우회 경로가 base 로 채택됨 ② PATCH 검증이 거부 사유를 내지 않음 ③ 사용자 지정 base 의 남의 `*.yml` 이 호스트 폴더로 옮겨짐 — 재생목록 21행
* 결과 (2026-10-04, **f4d83b5** · 후속 **2d88660** · release/1.1.1 병합 3146b1b·6ba8487):
    - `validateDataDirectoryPath` 단일 판정: `~` 확장 → 절대 경로 → `..` 정규화 + 존재 조상 `realpath` 뒤 **홈·`/Volumes` 의 엄격한 하위**만. 기동 시 거부 → 설정 폴더 유지 · PATCH `/settings`·`/settings/general` 거부 → 400(일부도 적용 안 함) · openapi_v2 동기
    - 레거시 루트 마이그레이션은 레이아웃 base == 설정 폴더일 때만(`prepareHostLayoutBase`)
    - 적대적 검증(관점별 리뷰 4 + 지적별 반박) 후속 2d88660: 실제 쓰기 폴더 `{base}/{host}`·`_share` 가 base 밖(심볼릭 링크)을 가리키면 거부 · `/Users/Shared`(world-writable — 다른 계정이 호스트 폴더를 심을 수 있음) 허용 철회
    - TDD: 재생목록 21행 red(신규 6테스트 14단언 + 후속 2) → green · jm4 XCTest 117/117 · **jma XCTest 117/117**
    - jma E2E(실행 중 cliApp, release 트리): 허용 밖 4종(`/private/tmp`·`/Volumes/../etc`·상대·`/`) 400 + 폴더 미생성·`_config.yml` 미기록·동반 필드(`theme`) 미적용 · 허용 경로 200 → 원값(null) 복원
    - jma `/run`(brew local, 2026-10-04): 1차는 brew install 거부 — jma CLT 26.6 ↔ Xcode 27.0, 배포 중 Homebrew 자동 갱신(8b92a1a)이 CLT 일치를 요구(9/28 은 같은 조합으로 통과). 사람이 CLT 27.0 설치 후 재실행 → `fwarrange-cli 1.1.2` `started` · 정식 서명(Apple Development) · 접근성 granted · PATCH `/private/tmp` **400**
    - 분리 등록: 레이아웃 이름 `../` 경로 탈출(기존 결함, high) → **Issue117** · paidApp 400 뒤 거부 경로 표시 → **prj16#Issue285** · 기각: 업그레이드 시 저장값 무시(a30f5d0 미출시라 해당 없음)·개행 값(기존 직렬화, 거부 시 설정 폴더로 안전 귀결)

## Issue113: [TDD] 재생목록 풀 재실행 — 전 목표 회귀 (common#Issue108 웨이브) (등록: 2026-09-29, 완료: 2026-09-29, Hash: e7e1685) ✅
* 목적: 사용자 지시(common#Issue108) — TDD 대상 전 prj 재생목록 풀 실행. 재생목록은 20/20 ✅ 이므로 현 HEAD 가 여전히 green 인지 회귀 확인하고 red 는 고친다
* 상세:
    - 대상: [tdd/playlist.md](tdd/playlist.md) ✅ 20행 (⬜ 행 없음) · 러너 전용 스크립트 없음 → 실행 열 그대로
    - 제약(웨이브 승계): 빌드성은 jma 전용·공용 잠금 `/tmp/jma-xcode.lock` + 300초 워치독 · jm4 는 가벼운 것만 · `pkill -f`·push·worktree 금지
* 구현 명세:
    - TDD 해당 없음: 회귀 재실행이며 red 가 나오지 않아 수정 대상 없음
* 결과 (2026-09-29, HEAD `48167f7`):
    - jma: HEAD 를 `git bundle` 로 `/tmp/fwc-tdd-src` 에 격리 클론(jma 기존 사본·설치본 무접촉) → GUI tmux 에서 잠금 획득 후 `xcodebuild build-for-testing` rc 0 → `test-without-building -testPlan fWarrangeCli` **108/108 passed, 0 failures** (15 스위트 — TDDPlaylistTests·BrewHandoffTests·OfficialBuildMarkerTests·AccessibilityGuideSchedulingTests 등) · `fwc-deploy-brew-test.sh --summary` PASS 1 (기출고 cli-v1.1.2 에서 빌드 전 중단)·PASS 2 (미실행 4단계 ⏭, 가짜 버전 9.9.354) · 00:45:33~00:46:23
    - jm4: `fwc-deploy-brew-test.sh` (check 1, xcodebuild 스텁·읽기 전용) PASS 1
    - 미실행: 9행 `fwc-test.sh` — `kill.sh` 가 `pkill -9 -f "MacOS/fWarrangeCli"` 를 부르고 jma 설치본을 Debug 로 교체한다. 웨이브 제약과 충돌해 돌리지 않았고, 9행 성질(기본값 시드)은 XCTest `testMissingConfigIsSeededWithDefaults` 로 확인
    - red → fix: 없음 · 로그 `logs/test/tdd-full_issue108_jma_20260929.log` (로컬, gitignored)

## Issue110: [Bug] 접근성 미승인 기동 시 `AccessibilityGuidePresenter` 모달(`NSAlert runModal`)이 메인 스레드를 잡아 REST v2 가 무응답 (등록: 2026-09-28, 완료: 2026-09-28, Hash: 7b56aff) ✅
* 목적: 데몬의 REST 가 사람이 안내 창을 닫을 때까지 멈춘다 — paidApp·스크립트가 레이아웃 조회부터 막힌다 (1.1.2 출고 R1 2단계 원복 중 발견)
* 상세:
    - 재현(jma 2026-09-28): TCC 접근성 리셋 뒤 brew 설치본 cliApp 1.1.1 기동 → `/` ·`/api/v2/health` 는 200, `/api/v2/status/accessibility`·`/api/v2/layouts` 는 8초 타임아웃(000). `sample` 메인 스레드 = `AccessibilityGuidePresenter` → `NSAlert runModal` → `runModalForWindow:`
    - 증거: `cli/_doc_work/_release/v1.1.2/logs/r1s2_restore_cli_sample_20260928_1606.txt` (1.1.1 바이너리 — 1.1.2 코드 경로도 `AppState` 가 미승인 시 `showAccessibilityGuide()` 호출, 동일 여부 검증 필요)
    - 영향: R1 4·11행(REST 테스트)은 clear 뒤 첫 기동마다 이 모달을 만난다
    - 비재현 (2026-09-28, 후보 41d93f8 R1 3행): clear 직후 소스 빌드 `open` 기동에서는 미승인 중에도 `/api/v2/status/accessibility` 가 응답했다(`granted:false`) — 재현 조건이 brew 설치본(launchd) 기동에 한정될 수 있다(검증 필요)
* 구현 명세:
    - red 먼저: 미승인 상태에서 안내 표시 중에도 `GET /api/v2/layouts` 가 응답함을 단언
    - 후보: 모달 대신 비모달 창(또는 `beginSheet`), REST 처리가 메인 액터 대기에 묶이지 않게
* 결과 (2026-09-28, 8f76dad 테스트 · **7b56aff** 수정 · `fix/issue110-a11y-guide-nonmodal`):
    - 진짜 원인: 안내를 `DispatchQueue.main.async` 블록 **안에서** `runModal()` 로 띄워, 창이 닫힐 때까지 그 블록이 끝나지 않고 직렬 메인 큐가 비워지지 않았다. REST v2 핸들러는 메인 큐로 넘어가므로 전부 대기. `/`·`/health` 는 메인 큐를 안 거쳐 응답(비재현 조건 차이는 기동 경로의 호출 순서 차이로 봄)
    - 수정: `AccessibilityGuidePresenter.schedule` = `RunLoop.main.perform(inModes: [.common])` — run loop 블록은 메인 큐 콜아웃 밖이라 모달 루프가 메인 큐를 계속 처리. 시작 시 안내·운영 중 권한 상실 안내 둘 다. 모달 형태·중복 방지 유지
    - TDD: `AccessibilityGuideSchedulingTests`(중첩 modal-panel run loop 안에서 메인 큐 작업 실행) red → green · 재생목록 20행 · jma XCTest **108/108**
    - jma E2E (TCC 리셋 → brew 기동): 수정 전 공개본 1.1.2 `layouts=000` · 수정 빌드 `layouts=200`·`granted:false` 응답 — `sample` 로 메인 스레드가 `NSAlert runModal` 안임을 확인. 이후 공개본 1.1.2 로 원복(이 수정은 다음 출고분부터)

## Issue108: `dataDirectoryPath` 설정이 저장만 되고 레이아웃 경로에 반영되지 않음 + 첫 기동 시 `_config.yml` 이 호스트 폴더로 옮겨짐 (등록: 2026-09-28, 완료: 2026-09-28, Hash: d117d12, a30f5d0) ✅
* 목적: paidApp 설정 › 일반의 데이터 폴더 «변경»이 동작하지 않는다 — App Store 1.1.1 스크린샷 05 캡션(«저장 폴더 직접 선택»)·entitlement `files.user-selected.read-write` 근거와 충돌한다 (prj16#Issue265 위임 A 중 발견)
* 상세:
    - 출처: prj16 위임 A(`_doc_work/delegation_2026.09.28_appstore-prefix.md`) — 결정 권한 C 등급(타 repo 이슈 등록)으로 등록만 함. 판단 재료: prj16 `_doc_work/_release/v1.1.1/screenshots/candidates.md` «발견 3»
    - ① `PATCH /api/v2/settings/general {dataDirectoryPath}` 는 `_config.yml` 에 기록만 된다. 저장소 경로는 `YAMLLayoutStorageService.resolveDefaultBaseDirectory()` 가 `Env.configPath`(환경변수 `fWarrangeCli_config`) → `~/Documents/finfra/fWarrangeData` 로만 정하고 `settings.dataDirectoryPath` 를 읽지 않는다. `init(dataDirectoryURL:)` 호출처는 `fWarrangeCliTests/TDDPlaylistTests.swift` 뿐 (2026-09-28 grep 실측)
    - ② `AppState.init` 이 `_config.yml` 을 먼저 만들고(기본값 저장) 그 뒤 `migrateRootDataIfNeeded()` 가 **루트의 `*.yml` 전부**를 `<base>/<host>/` 로 옮긴다 — `pathExtension == "yml"` 이라 `_config.yml` 도 대상. 호스트 폴더가 없는 첫 기동(신규 설치·새 `fWarrangeCli_config`)마다 재현 가능성(검증 필요 — 코드 판독만, 실행 미확인)
    - ② 실측 재현 (2026-09-28, jma clear 직후 1.1.2 후보 45688ee 첫 기동 — Issue107 R1 3행): 로그 `기존 데이터 마이그레이션 완료: jma-2/` 뒤 루트에 `_config.yml` 없음, `jma-2/_config.yml` 만 존재
    - ② 재재현 + 파급 (2026-09-28, 후보 41d93f8 R1 3·4행): 첫 기동에서 `jma-2/_config.yml` 로 이동한 파일이 레이아웃 **`_config`** 로 목록에 오르고, 4행 API `DELETE /layouts`(delete-all)가 그것까지 지웠다(`deletedCount 1`) — 설정 파일이 레이아웃 삭제에 쓸려 나간다. 호스트 폴더가 생긴 뒤 기동은 루트에 새 `_config.yml` 을 만든다
    - 우회(촬영용): prj16 `screenshots/demo/setup-demo.sh` 가 호스트 폴더를 미리 만들고 `open --env fWarrangeCli_config=…` 로 기동
    - ✅ ② 해소 (2026-09-28, **d117d12**, `fix/issue108-config-migration`): `_` 접두 파일을 마이그레이션에서 제외 · 설정 파일만 있는 루트는 호스트 폴더를 만들지 않음. 재생목록 16행 `root-config-stays-at-root` red(4단언) → green. ① 은 정책 결정 대기라 이슈 유지
* 구현 명세:
    - ① `dataDirectoryPath` 가 있으면 그것을 base 로 쓰도록 `resolveDefaultBaseDirectory()` 우선순위를 `env > settings.dataDirectoryPath > 기본값` 으로 — 변경 시 재기동 필요 여부·기존 데이터 이전 정책을 함께 정한다. red 먼저: 설정 변경 후 `GET /api/v2/layouts` 가 새 폴더를 보는지
    - ② 마이그레이션 대상에서 `_config.yml`(및 `_` 접두 파일) 제외. red 먼저: 빈 base 에서 AppState 기동 → 루트 `_config.yml` 존재 단언
    - 수정 후 prj16 AppStoreDoc·review-notes 의 entitlement 근거와 스크린샷 05 캡션을 재확인
* 결과 (2026-09-28):
    - ② d117d12 — `_` 접두 파일 마이그레이션 제외 (재생목록 16행)
    - ① **a30f5d0** (`fix/issue108-data-directory`) — 사용자 결정 «다음 기동부터 적용»: `resolveLayoutBaseDirectory` 우선순위 환경변수 > `dataDirectoryPath`(`~` 확장·폴더 생성, 실패 시 경고 후 설정 폴더) > 설정 폴더. AppState 의 저장소·마이그레이션·`_share` 복사가 레이아웃 base 를 쓴다. `_config.yml` 은 설정 폴더 유지. 기존 레이아웃은 옮기지 않음. openapi 설명 동기. 재생목록 19행 red(3단언) → green
    - 검증: jma clean clone XCTest **107/107**. 미검증: paidApp UI 에서 폴더 변경 → cliApp 재기동 → 새 폴더 목록까지의 실기 흐름(테스트는 판정 함수·배선 단위)
    - 남은 것(prj16 몫): AppStoreDoc·review-notes entitlement 근거·스크린샷 05 캡션 재확인 — 이제 «변경»이 동작하므로 캡션 유지 가능, paidApp 쪽 «재시작 뒤 적용» 안내 문구 필요 여부 판단 → **prj16#Issue282** 로 등록(e2a060f)

## Issue112: [Bug] `fwc-deploy-brew.sh publish --dry-run` 이 태그·release 중복 검사를 건너뛰고, 요약표가 실행 안 한 push·release 를 ✅ 로 찍음 (Issue107 결함 ① 분리) (등록: 2026-09-28, 완료: 2026-09-28, Hash: 12ec148) ✅
* 목적: 출고 판단자가 dry-run 결과를 믿고 기출고 번호를 다시 내거나, 이미 올라갔다고 오독한다 — dry-run 이 실제 publish 의 위험을 미리 보여 주지 못한다
* 상세:
    - 결함 ①(Issue107): Step 0-3 태그·release 중복 검사를 live 에서만 해, 기출고 `cli-v1.1.1` 재출고 계획을 dry-run 이 ALL CLEAR 로 보고했다
    - 요약표 오표시(1.1.2 R1 3단계 보고 4절): dry-run 인데 «git tag push ✅ · gh release ✅ · tap push ✅» 로 찍힌다 — 실행되지 않은 단계다
* 구현 명세:
    - dry-run 에서도 원격 태그·release 존재를 조회해 중복이면 FAIL(또는 경고 + 비 0 종료)
    - 요약표는 dry-run 단계를 «⏭ 계획(미실행)» 처럼 실행 결과와 구분되는 표기로
    - red 먼저: 기존 태그 번호로 `publish --dry-run` → ALL CLEAR 가 나오는 것을 재현하는 검사
* 결과 (2026-09-28, 1e42616 검사 · **12ec148** 수정 · `fix/issue112-dryrun-dup-check`):
    - Step 0-3 중복 검사를 dry-run 에서도 수행 — 기출고 버전이면 빌드 전 FAIL
    - dry-run 의 미실행 단계(git tag push·gh release·tap push·검증)는 «⏭ (dry-run 계획, 미실행)» — PASS 개수에서 제외
    - 검사 `cli/_tool/fwc-deploy-brew-test.sh`: 1) xcodebuild 스텁으로 빌드 없이 중복 정지 확인 — red(jma: 사전조건 통과 후 Step 1 도달) → green · 2) `--summary` 가짜 미출고 버전(9.9.969) dry-run → ⏭ 4건 PASS. 재생목록 18행 `publish-dry-run-truthful`

## Issue106: XCTest 호스트가 BrewServiceSync.onAppStart() 를 그대로 탐 — 테스트 격리 결손·호스트 미종료 (🌱 후보 승격) (등록: 2026-09-28, 완료: 2026-09-28, Hash: 8eba7ff) ✅
* 목적: 실 brew 서비스 조회(멈춰 있으면 `brew services start` handoff 까지)로 격리(#11) 결손 + 동기 `waitUntilExit` 중첩 런루프 안에서 테스트가 돌면 완료 후 호스트가 종료되지 않음(경쟁, 4/8회) (Issue105 중 발견)
* 상세:
    - 출처: prj3 mq `20260928-023246-001` ③ — prj3#Issue756 C 등급: 🌱 후보 → 번호 이슈 승격(후보 줄은 다음 정리 때 삭제)
    - 진단: `cli/_doc_work/debug_TECH.md`
* 구현 명세:
    - `XCTestConfigurationFilePath` 가드 후보 — 재현 테스트 red 먼저(8회 반복 종료 확인)
* 결과 (2026-09-28, cf32218 테스트 · **8eba7ff** 수정 · `fix/issue106-test-host-brew`):
    - `BrewServiceSync.StartEnvironment.isTestHost`(live = `XCTestConfigurationFilePath`) 를 `onAppStart` 첫 판정으로 — 테스트 호스트는 launchctl·brew 조회 전에 skip
    - TDD: `testTestHostSkipsBrewSyncBeforeTouchingBrew` red(jma — `handedOff` · 이벤트 loaded?→brew?→formula?→start→flush→exit) → green · 재생목록 17행 `test-host-skips-brew-sync`
    - 검증: jma clean clone develop(9194869) XCTest **104/104** · 호스트 정상 종료. «8회 반복» 은 원인(실 brew 경로) 자체를 막아 대체함 — 1.1.2 R1 3단계부터 교착 미재현

## Issue111: [Bug] cliApp 재시작 뒤 `GET /api/v2/paidapp/status` 가 실행 중인 paidApp 을 `not_running` 으로 답함 — 메뉴 모드 판정(PaidAppMonitor)과 status 판정(paidAppRouter) 갈림 (등록: 2026-09-28, 완료: 2026-09-28, Hash: aebef57) ✅
* 목적: 같은 사실(«paidApp 이 떠 있는가»)을 두 곳이 따로 판정해 cliApp 재시작 뒤 서로 다른 답을 낸다 — status 를 믿는 소비자(스크립트·QA·paidApp 쪽 점검)가 떠 있는 paidApp 을 없는 것으로 본다 (1.1.2 출고 R1 8행 뒤 jma 실측)
* 상세:
    - 재현 (2026-09-28 17:25, jma): paidApp 1.1.1 실행 중(PID 91381) 상태에서 cliApp 만 재기동(`brew services` 재설치·start) → `/api/v2/paidapp/status` = `{"state":"not_running"}` 이 90초 넘게 유지. paidApp 은 `applicationDidFinishLaunching` 에서만 register 한다
    - 원인: `handlePaidAppStatus`(RESTServer.swift) 는 `paidAppRouter.status()` — REST register 기록만 본다. 재시작 복원(`PaidAppMonitor.init` 의 `runningApplications` 검색 → `.paidAppActive`)은 메뉴 모드에만 반영되고 status 에는 닿지 않는다
    - 규약: `paid_cli_protocol.md` §3.4 «cliApp 재시작 → register 기록 소실 가능 → 실행 중 paidApp 검색으로 복원» — status 가 그 복원을 반영하지 않아 규약과 어긋남
    - 1.1.2 회귀 아님(관련 코드 무변경). R1 12행은 paidApp 을 cliApp 뒤에 띄워 register 가 일어나는 순서라 드러나지 않았다
* 구현 명세:
    - 판정 단일 지점으로 통일: status 도 «register 기록 없음 + `runningApplications` 에 `kr.finfra.fWarrange` 있음» 이면 `running`(pid·출처 표기) — 또는 cliApp 기동 시 복원 경로가 router 에도 기록을 만든다. 어느 쪽이든 PaidAppMonitor 와 router 가 같은 답을 내야 한다
    - red 먼저: register 기록 없이 paidApp 실행 중인 상태를 주입 → status 가 `not_running` 을 내는 테스트 → 수정 뒤 green
    - openapi_v2.yaml `paidapp/status` 응답 설명 동기(api-rules)
* 결과 (2026-09-28, aebef57 · `fix/issue111-paidapp-status`):
    - `PaidAppRouter.status()`: 등록 기록이 없고 paidApp 프로세스가 실행 중이면 `running`(pid·version·bundlePath, `sessionId`·`registeredAt` 없음). 등록 기록이 있으면 그것이 우선
    - 실행 중 paidApp 조회를 `RunningPaidAppResolver` 로 주입 — 테스트 호스트 머신에 실제 paidApp 이 떠 있어도 기존 status 테스트가 흔들리지 않게(jm4 실측: paidApp 실행 중)
    - TDD: `testStatusReportsRunningPaidAppWithoutRegistration` red(4단언) → green · openapi_v2.yaml 설명 동기
    - 검증: **jma** clean clone XCTest **102/102** (jm4 는 사용자 사용 중이라 jma 에서 실행) · 테스트 호스트 정상 종료

## Issue107: cliApp brew·npm 출고 R1 중단 — 기출고 `cli-v1.1.1` 번호 충돌·jma 화면 잠김 (등록: 2026-09-28, 완료: 2026-09-28, Hash: 8553c40, 41d93f8, c7c8c21, d375c08) ✅
* 목적: 사용자 결정(2026-09-28, prj3 세션 05cbbead · mq 20260928-120438-001 — H:배포 승인)으로 fWarrangeCli 를 Homebrew tap·npm 으로 출고하려 R1 을 돌렸으나, 1.1.1 은 이미 공개 출고된 번호라 이번 변경(Issue95~105)을 1.1.1 로 낼 수 없다 — 버전 결정 대기
* report: `../_doc_work/report/cli-release-1.1.1_report.md`, `../_doc_work/report/cli-release-1.1.2-stage1_report.md`, `../_doc_work/report/cli-release-1.1.2-stage2_report.md`, `../_doc_work/report/cli-release-1.1.2-stage3_report.md`
* 상세:
    - 위임: `../_doc_work/delegation_2026.09.28_cli-brew-npm-release.md` · 공개 반영(push·publish)은 prj3 세션 몫
    - 증거(partial): `cli/_doc_work/_release/v1.1.1/release-test_1.1.1.md` — 1행 조건부(XCTest 93/93, Issue106 호스트 교착 재현) · 2~12행 미실행(jma `CGSSessionScreenIsLocked=1`) · 6행 dry-run 9 PASS(순서 밖 정보 실행)
    - 충돌: `cli-v1.1.1` 태그(da9c41a, 2026-07-21 Issue89)·GitHub release(Latest)·공개 tap Formula(sha256 af8dca…, 구 CC BY-NC 라이선스)가 이미 있다. 그 뒤 코드 커밋 11건. 같은 번호 덮어쓰기는 기존 태그 변경 금지 + `brew upgrade` 미감지
    - 정책: fapp-gitflow «버전은 항상 동일 — patch 예외 없음» → cliApp 단독 1.1.2 불가. paidApp 1.1.1 은 App Store 미제출(Issue265 대기 · prj16)이라 락스텝 1.1.2 는 추가 심사 비용이 없다
    - jma 경합: 잠금 해제 시 prj16 스크린샷 위임 B 가 jma 를 자동 점유(mq 20260928-120452-001) — R1 의 clear·재배포와 순서 조정 필요
    - npm: `fwarrange-mcp` 배포 불요 — `index.js`·`package.json` 이 공개본 1.0.2 와 동일(차이는 README 라이선스 문단·LICENSE 파일 신규뿐)
    - 발견 결함 ①: `fwc-deploy-brew.sh publish --dry-run` 이 태그·release 중복 검사(Step 0-3)를 live 에서만 해 기출고 번호 재출고 계획을 PASS 로 보고한다
    - 발견 결함 ②: 증거 기본 경로 `_doc_work/_release` 가 이 레포 경로 규칙(루트 `_doc_work/` 금지·doc-root-guard 차단)과 충돌 → `tdd/release.md` 에 `evidence_dir` 선언 필요. `cli/_doc_work/` 도 gitignore 라 R3(증거 커밋)용 추적 위치는 공개 노출(jma·prj16 SHA) 여부와 함께 결정
    - 2026-09-28 사용자 결정: paidApp·cliApp **락스텝 1.1.2** (⏸️ → 🚧). 2단계 위임 — 1단계(bump + R1 1행, jm4) `../_doc_work/delegation_2026.09.28_cli-1.1.2-bump.md` · 2단계(jma 2~12행)는 prj16 스크린샷 위임 B 종료·jma 잠금 해제 뒤
    - 1단계 bump: `VERSION` 1.1.1 → 1.1.2 · pbxproj `MARKETING_VERSION` ×2 · `cli/project.yml` + **`cli/Formula/fwarrange-cli.rb` url(sha256 은 0 자리표시 — publish 뒤 실값, Issue89 da9c41a→79227f6 선례) · `cli/version-meta.yml` `version:`** — 뒤 두 곳은 위임 지시에 없었으나 `testVersionSourcesAgree`(개발 재생목록 10행)가 대조하므로 빠뜨리면 1행이 확정 실패한다. `brew:` 상태 필드(formula·installed 1.1.1)는 설치 실태라 publish 뒤 갱신
    - ✅ 1단계 완료 (2026-09-28, bump 8553c40): R1 1행 `dev-playlist-green` jm4 **조건부 통과** — XCTest 93/93 passed · 번들 1.1.2 · Issue106 호스트 교착 재현(호스트만 kill → `TEST SUCCEEDED` rc 0) · `fwc-test.sh` 부분은 4행(jma)으로. 증거 `cli/_doc_work/_release/v1.1.2/release-test_1.1.2.md`(`result: partial`, `dirty: yes` — 타 세션 미커밋분) · 보고 `../_doc_work/report/cli-release-1.1.2-stage1_report.md` · 2단계(jma 2~12행) 대기
    - ⛔ 2단계 종료 (2026-09-28, 후보 45688ee — cd2a8eb 뒤 prj16#Issue280 이 manual md·png 만 추가, 빌드 입력 동일): R1 **`result: fail`** — 2행 `jma-clean-state` 통과 · **3행 `source-build-from-readme` 실패** → 위임 규약대로 정지(4~12행 미실행). README 빌드는 성공(1.1.2·Apple Development 유효)하나 `open` 기동 550ms 만에 앱이 스스로 종료 — brew 바이너리만 보고 formula 미설치 상태에서 `brew services start` 위임 후 결과와 무관하게 `exit(0)` (**Issue109**). 부수 발견: 접근성 미승인 기동 시 안내 모달이 REST v2 를 막음(**Issue110**) · 2행 clear 가 TCC 접근성·brew formula trust 를 리셋하므로 4·11행은 사람 승인 단계가 필요 · jma 는 1.1.1 두 앱·데이터·설정으로 원복(접근성 권한만 사람 손 필요). 보고 `../_doc_work/report/cli-release-1.1.2-stage2_report.md`
    - ✅ 3단계 R1 통과 (2026-09-28, 새 후보 **41d93f8** — Issue109 수정): **`result: pass` · `dirty: no`**(모든 빌드가 후보 clean clone) — 1행 jm4 XCTest 98/98(Issue106 교착 미재현) · 2~7·9~12행 jma 통과 · 8행 출고 후. 3행 소스 빌드 60초 생존 · 4행 `fwc-test.sh` ALL CLEAR · 6행 dry-run 외부 상태 전후 동일 · 7행 publish tarball 설치 CDHash 보존 · 10·11행 prj16 0d8e211 `--check` FAIL 0·REST 18/0 · 12행 prj16 v1.1.1 등록·목록 반영. 접근성 재승인은 `say` 뒤 사람이 16:45 처리. R2 `recheck` 사전 확인 ✅. jma 1.1.1 원복 `--check` FAIL 0(접근성 `granted` 유지). 보고 `../_doc_work/report/cli-release-1.1.2-stage3_report.md` — 공개 반영은 prj3 세션 몫
    - 결함 ② 해소 (c7c8c21): `tdd/release.md` `evidence_dir: cli/_doc_work/_release` — recheck 가 «증거 없음» 대신 실제 증거를 읽는다. 첫 R1 통과에 따라 `r2: warn → block`(recheck ❌ 가 rc 0 으로 통과하던 경고 모드 종료)
    - ✅ 공개 출고 (2026-09-28 17:2x, 사용자 승인 — prj26 세션 da453e47 · 오케스트레이터 05cbbead 종료로 인계): release/1.1.1 push(c6edbf7) → GitHub clone 에서 main ← release `--no-ff` 병합 **d375c08**(NOTICE add/add 충돌 1건 → release 판, main 판 19줄 전부 포함 확인 · 병합 트리 = release 트리) → 병합 커밋 recheck ✅ → main push → `publish --dry-run` 9/0 → `publish` 9/0: 태그 **`cli-v1.1.2`**(→ d375c08) · GitHub release **Latest** · asset `fWarrangeCli-1.1.2.tar.gz` sha256 `402dbe5e…` = 공개 tap Formula(Finfra/homebrew-tap 8395a11) · 번들 1.1.2 서명 유효. 원 저장소 `main` fast-forward·태그 동기
    - ✅ R1 8행 `brew-tap-published-install` 통과 (17:25, jma): 공개 tap 동기(로컬 테스트 `fwarrange-cli.rb` 만 되돌리고 ff — `fsnippet-cli.rb` 로컬 수정 무접촉) → formula 단위 클린(데이터·paidApp·TCC 보존, 7행과 같은 방식) → `brew install finfra/tap/fwarrange-cli` → 라벨 1.1.2 = 번들 1.1.2 = REST 1.1.2 = `VERSION` · Homebrew 7 trust 자동 복구 · 접근성 `granted` 승계. jma 최종 = **공개본 1.1.2**(출고 후라 1.1.1 로 되돌리지 않음) + paidApp 1.1.1. 로그 `cli/_doc_work/_release/v1.1.2/logs/r1s4_row08_public_tap.log`
    - 출고 뒤 정리: `cli/Formula/fwarrange-cli.rb` sha256 0 → 실값 · `cli/version-meta.yml` `formula_version` 1.1.2(`installed_version` 은 jm4 설치 실태 1.1.1 유지). npm 배포 없음(불요 판정 유지)
    - 분리: 결함 ① + dry-run 요약 «push ✅» 오표시 → **Issue112** · 출고 뒤 발견한 `paidapp/status` 판정 갈림 → **Issue111**
* 구현 명세:
    - 사용자 결정: 버전 번호 — paidApp·cliApp 락스텝 1.1.2 로 결정됨 (2026-09-28)
    - 결정 후: bump(`version-rules` 절차) → 새 후보 커밋에서 R1 처음부터(jma 잠금 해제 + 스크린샷 촬영과 점유 순서 합의) → R2 recheck → main `--no-ff` 병합 → main 에서 `publish`
    - 결함 ①: dry-run 에서도 중복을 경고(또는 FAIL)로 내게 — 재현: 현 상태에서 `publish --dry-run` 이 ALL CLEAR → Issue112 로 이관

## Issue109: [Bug] `open` 기동한 cliApp 이 brew 바이너리만 있으면 formula 미설치여도 `brew services start` 위임 후 `exit(0)` — README 소스 빌드 앱이 기동 직후 사라짐 (등록: 2026-09-28, 완료: 2026-09-28, Hash: 41d93f8) ✅
* 목적: 출고 R1 3행 `source-build-from-readme` 실패 원인. Homebrew 가 깔린 Mac 에서 README «Build from Source» 로 만든 앱을 `open` 하면 REST 가 한 번 응답한 뒤 1초 안에 종료된다 — 소스 빌드 사용자는 앱을 쓸 수 없다 (1.1.2 출고 R1 2단계 중 발견 · 위임 지시 «코드 수정은 범위 밖 — 이슈후보로» 에 따라 등록만)
* 상세:
    - 재현(jma 2026-09-28, 후보 45688ee, clear 직후): `open …/Release/fWarrangeCli.app` → 100ms 에 자식 `brew services start fwarrange-cli` 생성 → brew 가 `Refusing to load formula finfra/tap/fwarrange-cli from untrusted tap` (rc=1, formula 미설치) → 550ms 에 앱 종료. 통합 로그 `CoreAnalytics … Entering exit handler`(정상 종료, 크래시 아님)
    - 원인(코드 판독): `BrewServiceSync.onAppStart()` 의 skip 조건이 optOut·launchd 기동·서비스 로드·**brew 바이너리 유무**뿐이고 formula 설치 여부를 보지 않는다 → `performHandoffStart()` 가 `brew services start` rc 와 무관하게 `Foundation.exit(0)` (`cli/fWarrangeCli/Services/BrewServiceSync.swift` onAppStart·performHandoffStart)
    - 도입: Issue41 `03192bb` — 기출고 cli-v1.0.1~1.1.1 에도 포함(1.1.2 회귀 아님). jma 는 그동안 `kr.finfra.fWarrangeCli` `fwc.autoStartBrewService=false` 옵트아웃이 있어 가려져 있었다 — clear 가 prefs 를 지워 드러남
    - 부수: 종료 직전 `logI("[brew-sync] performHandoffStart …")` 가 `wlog_cliApp.log` 에 남지 않는다 — exit 가 Logger 비동기 쓰기를 앞질러 자체 종료가 로그상 보이지 않음
    - 관련: Issue106(같은 `onAppStart()` 가 XCTest 호스트에서 도는 격리 결손)
    - 증거: `cli/_doc_work/_release/v1.1.2/logs/r1s2_row03_*` · 보고 `../_doc_work/report/cli-release-1.1.2-stage2_report.md`
* 구현 명세:
    - red 먼저: brew 바이너리 있음 + formula 미설치(또는 `brew services start` 실패) 상태에서 `onAppStart()` 가 프로세스를 종료하지 않음을 단언 (brew 조회는 주입으로 격리)
    - 후보: handoff 전에 formula 설치 확인(`brew list --versions fwarrange-cli` 등) + `brew services start` 실패 시 exit 하지 않고 현 프로세스를 primary 로 유지. exit 전 Logger flush
    - 수정 후 새 후보 커밋에서 R1 1행부터 다시 (Issue107)
* 결과 (2026-09-28, 위임 `../_doc_work/delegation_2026.09.28_cli-1.1.2-fix109-r1.md`):
    - 수정 41d93f8: handoff 전 formula 서비스 실행 파일(`{prefix}/opt/fwarrange-cli/fWarrangeCli.app/…` — Formula `service` `run` 경로) 확인 · `brew services start` 실패 시 exit 하지 않고 primary 유지(`handoffInProgress` 리셋) · 성공 시 `Logger.flush()` 뒤 exit · 외부 효과 `StartEnvironment` 주입
    - TDD: `tdd/playlist.md` 15행 `brew-handoff-keeps-primary` — `BrewHandoffTests` 5건 red 5/5 실패(단언 8) → green · flush 테스트는 no-op flush 로 red 재확인 · XCTest 98/98 (jm4)
    - 실측: R1 3행(jma clear 직후 formula 미설치, 후보 41d93f8) `open` → 60초 생존·REST 200·자식 `brew services` 0회 — 이전 후보는 0.55초에 자체 종료. 증거 `cli/_doc_work/_release/v1.1.2/release-test_1.1.2.md` · 진단 `cli/_doc_work/debug_TECH.md`

## Issue105: 라이선스 훅 문서 v1.1 → v1.2 재동기 + Official Build 구분 표식 (prj6#Issue17 적대적 검토 반영) (등록: 2026-09-27, 완료: 2026-09-28, Hash: f4bd0c7, b4ee029, 26c6f0f) ✅
* 목적: Issue103 은 v1.1 템플릿으로 적용됐다. prj6 적대적 검토 29건 중 약관 정의 우회(컨테이너·CI·개인 예외·50% 미만 지배)·수정 금지와 Apache §2 충돌·NOTICE 의 Apache 전체 선언이 v1.1 에 남아 있다. v1.2 로 올린다
* depends: prj6#Issue17
* 상세:
    - 문서 재동기: `DISTRIBUTION-TERMS.md` → v1.2 전문 교체(자리표 `{{EFFECTIVE_DATE}}` 는 이번 커밋일 — v1.x 판 발효일 이후 빌드는 새 판) · `TRADEMARK.md`·`COMMERCIAL.md`·`NOTICE` → v1.2(`{{MARKS}}` 는 NOTICE·TRADEMARK 동일 값) · `LICENSE_ko.md` 는 Apache 참고 번역이라 변경 없음
    - README(en·ko) **설치 명령 바로 앞**에 약관 2줄(DISTRIBUTION-TERMS §0 요약)을 둔다 — 설치 후 caveats 만으로는 약관규제법상 사전 고지가 약하다(검토 medium)
    - Official Build 구분 표식(2단계 — 코드 변경이라 tdd red 먼저): 공식 빌드에만 들어가는 `resources/official/`(브랜드 배너·아이콘) + 공식 빌드 스크립트 분기 + `--version` 출력에 `Finfra Official Build` 표기. 소스 빌드에는 넣지 않는다. 없으면 약관 §1(b) 가 빈 집합이라 법무가 적용 대상을 구별 못 한다 — 1단계와 한 이슈로 하되 커밋은 나눈다
    - 근거: 템플릿 `/Users/nowage/_git/___oracle/data/template/license/`(v1.2, prj6 `3195f25`) · 검토 처분표 `/Users/nowage/_git/___oracle/_doc_work/report/license-hook-review_issue17_report.md` §반영 결과 · 정본 `/Users/nowage/_git/___oracle/_doc_arch/license-profiles.md` §3-2·§5
    - **한국어 약관본 추가** (prj6 템플릿 `/Users/nowage/_git/___oracle/data/template/license/DISTRIBUTION-TERMS_ko.md`): 루트 `DISTRIBUTION-TERMS_ko.md` 를 영문 v1.2 와 **같은 커밋**으로 — 약관 §10 이 한국 거주 개인에게 한국어본의 동등 효력을 약속하므로 영문과 어긋나면 안 된다. 자리표 값은 영문과 동일. 확인: `diff <(grep -oE '^## [0-9]+\.' DISTRIBUTION-TERMS.md) <(grep -oE '^## [0-9]+\.' DISTRIBUTION-TERMS_ko.md)` 무출력
* 구현 명세:
    - 검증: 4개 문서 `Version 1.2` · `grep -c '{{' ` 0 · README 설치 명령 앞 약관 2줄 · `mcp/LICENSE` MIT 불변
    - 금지: `git push` · npm publish · `Finfra/homebrew-tap` 수정 · 기존 태그 변경 · 템플릿 frontmatter·`📄 템플릿` 블록 복사
    - `Issue.md` 는 `python3 ~/.claude/sh/issue-tx.py --file Issue.md stage --issues <N>` / `check` 경유 · 커밋 후 ✅ 이동 + hash 기록
* 결과:
    - 검증 통과 — 4개 문서 `Version 1.2`(TRADEMARK·COMMERCIAL·NOTICE 는 템플릿에 본문 판 표기가 없어 한 줄 추가) · `{{` 0건 · README(en·ko)·cli/README(en·ko) 설치 명령 앞 약관 2줄 · `mcp/LICENSE` 불변 · DISTRIBUTION-TERMS 는 템플릿과 단어열 일치 · 한국어본 조항 번호 `diff` 무출력
    - 1단계(f4bd0c7): `{{MARKS}}` = `"fWarrangeCli", "fWarrange", the fWarrange icon`(NOTICE·TRADEMARK 동일) · 테마 전용 행·조항은 제외 · v1.1 의 "free for individuals" 를 v1.2 "personal use" 로 README·FAQ·formula caveats(스냅샷·생성기 2곳)까지 동기 · 명세의 «LICENSE_ko 변경 없음» 은 요약 절에 v1.1 개인 예외 문구가 있어 **요약 절만** 수정(Apache 번역부 불변)
    - 한국어본(b4ee029): 요건이 1단계 커밋 뒤에 추가돼 «영문과 같은 커밋» 은 못 지켰다 — 두 판 모두 v1.2 로 HEAD 에서 정합
    - 2단계(26c6f0f): `cli/resources/official/`(배너) + 빌드 단계 주입(약관 6종 동봉 = §6 «패키지 안») + `/cli/version` `distribution` → `--version` 에 `Finfra Official Build`/`Source Build`. 아이콘은 넣지 않았다(최소 1종 = 배너로 충족, 전용 아이콘 자산 없음). tdd #14 red→green, XCTest 93/93(jm4)
    - 실측 발견: Xcode 는 빌드 단계만 번들을 바꾼 증분 빌드를 **재서명하지 않는다** → 공식 빌드를 전용 DerivedData + clean build 로 고정하고 `official_build_gate`(배너·`codesign --strict`) 추가. 진단은 `cli/_doc_work/debug_TECH.md`
    - 미수행(사용자 몫): `git push` · tap formula caveats 갱신(personal use 문구) push · 실제 brew 공식 배포로 `--version` E2E

## Issue104: [Permission] 미승인 부팅 시 손쉬운 사용 목록 자동 등록 — prj25 Issue237 이식 (등록: 2026-09-27, 완료: 2026-09-27, Hash: 33b878a) ✅
* 목적: jma 에서 fWarrangeCli 가 손쉬운 사용 목록에 올라오지 않아 사용자가 수동 추가했다. 권한 요청 API 를 전혀 호출하지 않았고, `AppState` 주석의 *"ad-hoc 서명에서는 시스템 프롬프트 무효"* 는 Apple Development 서명 전환 전의 낡은 전제였다
* 상세:
    - Issue96 의 *"프롬프트는 실행 중 프로세스에 무효"* 는 유지 — 이번 요청은 **부팅 직후 새 프로세스 1회**에 한정
    - 한 번 켠 권한은 재배포 뒤에도 유지(jma 재배포 2회 실측, `status/accessibility` granted=true)
* 구현 명세:
    - `AccessibilityBootListing`(`Services/AccessibilityService.swift`) — prj25 와 동일 계약. 호출은 `AppState` 부팅 미승인 분기, `XCTestConfigurationFilePath` 있으면 생략
    - 검증: `TDDPlaylistTests.swift` 의 `AccessibilityBootListingTests` 2건 jma green · E2E — 목록 `−` 삭제 → 재기동 → 목록 자동 재등록 캡처
* 결과: jma E2E — 목록 `−` 삭제 → `brew services restart` → 두 앱 모두 목록에 자동 재등록 확인(캡처). 사용자 스위치 ON 후 재시작 없이 granted=true. 재배포 2회 후에도 권한 유지(T1)

## Issue103: 라이선스 프로파일 A 적용 — CC BY-NC 4.0 이중 → Apache-2.0 + 훅 ①상표 ②배포본 약관(N=250), mcp/ 는 MIT (등록: 2026-09-27, 완료: 2026-09-27, Hash: 7449eff) ✅
* 목적: CC 는 소프트웨어에 부적합하고 NC 는 회사 사용을 전부 막아 채택을 죽인다. 정본대로 소스 오픈 + 코드 밖 훅으로 전환한다(완화 방향이라 소급 문제 없음)
* 상세:
    - 루트 `LICENSE`(현 이중 문서) → Apache-2.0 원문 · `NOTICE` · `TRADEMARK.md`·`DISTRIBUTION-TERMS.md`·`COMMERCIAL.md`(`{{N}}`=250 · `{{EFFECTIVE_DATE}}`=커밋일 · `{{CHANNELS}}`=Homebrew tap finfra/tap, GitHub Releases) · `LICENSE_ko.md` 참고 번역
    - 현 LICENSE "Notes" 절(`fwarrange-mcp` ≤1.0.2 MIT)은 README 절로 이관 + "1.0.2 이후~이번 커밋 이전은 CC BY-NC 4.0 이중" 한 줄 추가
    - `mcp/` 는 프로파일 C: `mcp/LICENSE` MIT 원문 · `mcp/package.json.license` `(CC-BY-NC-4.0 OR LicenseRef-Commercial)` → `MIT`
    - README(en·kr) 라이선스 절을 `cli/`(Apache-2.0 + 훅 3문서) / `mcp/`(MIT) 표로 교체
    - 정본 `/Users/nowage/_git/___oracle/_doc_arch/license-profiles.md` §4 row 26 · 템플릿 `/Users/nowage/_git/___oracle/data/template/license/README.md`(자리표 값 표 포함 — `{{N}}`=250 · `{{LICENSOR}}`=`Finfra Co., Ltd. (https://finfra.kr)` · `{{CONTACT}}`=finfra@gmail.com)
* 구현 명세:
    - 검증: 위 파일 전부 존재 · README 라이선스 절이 각 파일을 링크 · `grep -rn "All rights reserved" README*` 0건 · 정본 §4 해당 행과 대조
    - 금지: `git push`(공개 라이선스 변경은 사용자가 push) · npm publish · `Finfra/homebrew-tap` 수정(formula `license "Apache-2.0"`·caveats 갱신 명령만 report 에 적는다) · 기존 릴리스 태그 변경
    - `Issue.md` 는 `python3 ~/.claude/sh/issue-tx.py --file Issue.md stage --issues <N>` / `check` 경유 스테이징 · 커밋 후 ✅ 이동 + hash 기록
* 결과:
    - 검증 4항 통과 — 파일 7종 존재 · README(en·kr) 7종 링크 · `All rights reserved` 0건 · 정본 §4 row 26·§5 혼합 프로파일 규칙 충족. Apache 원문 md5 `3b83ef96…` = apache.org 공식본
    - 명세 외 동반 정리: `cli/`·`mcp/` README · manual FAQ · `openapi_v2.yaml` `info.license` · brew formula 생성기(local·publish)·스냅샷의 `license "Apache-2.0"` + caveats 약관 3줄 (§5 «3곳 동시 갱신»)
    - 보류: `openapi_v1.yaml` license 표기(동결 규칙) · tarball 약관 동봉 · `CONTRIBUTING.md` 부재 · prj6 `COMMERCIAL.md` 템플릿 절 번호(§3→§4) 결손 — 상세·tap 갱신 명령은 `cli/_doc_work/report/Issue103_license_report.md`
    - 미수행(사용자 몫): `git push` · tap formula push · npm publish

## Issue102: [Security] RESTServer 가 allowExternal=false 인데 `*:3016` 전체 인터페이스 바인딩 — 외부 노출 (등록: 2026-09-27, 완료: 2026-09-27, Hash: c5d8906) ✅
* 목적: cliApp REST 는 기본 로컬 전용(allowExternal=false)이어야 하는데 jma `lsof` 실측에서 `*:3016`(tcp46) 전체 인터페이스에 바인딩돼 있었다. 같은 네트워크의 외부 호스트가 3016 에 접근 가능한 노출. Issue101(REST 무응답) 검증 중 발견
* depends: Issue101
* 상세:
    - 원인: `RESTServer.bindListener()` 가 `requiredLocalEndpoint`(127.0.0.1)를 **NWListener 생성 후** `listener.parameters` 에 설정. `NWListener(using:)` 는 생성 시점 params 를 고정하므로 사후 변경이 반영되지 않아 전체 바인딩으로 남았다
    - 2차 함정(수정 중 실측): 생성 **전** params 에 넣되 `on: nwPort` 와 함께 두면 requiredLocalEndpoint(host+port 완전 지정)와 중복돼 **listener 가 ready 되지 않고 REST 서버가 아예 안 뜬다**(lsof 3016 없음·REST 000). `on:` 생략으로 해결
* 구현 명세:
    - `bindListener()`: allowExternal=false 면 생성 전 `params.requiredLocalEndpoint = 127.0.0.1:port` + `NWListener(using: params)`(on: 생략). allowExternal=true 는 `NWListener(using: params, on: nwPort)` 유지
    - 검증(jma, 공용 잠금): `lsof -nP -iTCP:3016 -sTCP:LISTEN` → **127.0.0.1:3016**(이전 `*:3016`) · REST 200 · 유닛테스트 84개 green · 배포 ALL CLEAR 11 PASS/0 FAIL
    - ⚠️ 동작 변경(외부 3016 접근 차단) — jm4 재배포 시 반영. common-cf 보고

## Issue101: [Bug] REST 3016 이 연결을 받고도 응답하지 않는다 — AppState 이중 생성 + 고아 listener (등록: 2026-09-27, 완료: 2026-09-27, Hash: 9a710c6) ✅
* 목적: prj5#Issue99 라운드 중 jma cliApp(pid 28113)이 3016 LISTEN·프로세스 생존 상태인데 health 가 타임아웃됐다. prj16 TDD 가 cliApp 에 의존하므로 원인을 제거한다
* 상세:
    - **실측 (jma, macOS 26.6.2)**: 기동 직후 1~2 요청만 200, 이후 전부 무응답. `netstat` 상 연결은 accept 돼 fd 가 있으나 Recv-Q 가 읽히지 않음. `heap 28113` → AppState 1·RESTServer 1·`NWConcrete_nw_listener` 1, **`NWConnection` 0개** — 연결이 start 없이 버려짐
    - **대조 (jm4, macOS 26.7)**: `heap` → AppState **2**·RESTServer **2** — 이중 생성은 공통 결함이고, jm4 는 서버를 띄운 쪽이 우연히 살아 있어 증상이 가려졌다
    - **원인**: `fWarrangeCliApp` 의 `@State private var appState = AppState()` 를 `App.init` 에서 읽음. SwiftUI(`LazyStatePropertyBox`)가 설치하는 인스턴스와 init 이 읽은 인스턴스가 갈라져 AppState 가 여러 개 생기고(XCTest 호스트 실측 3개), init 쪽 인스턴스가 REST listener 를 띄운 뒤 해제된다. `NWListener` 는 시작 후 프레임워크가 붙들고 있어 포트를 계속 점유하고, `newConnectionHandler` 의 `[weak self]` 가 nil 이라 연결을 cancel 도 없이 버린다 → 클라이언트 무한 대기
    - 보조 결함: `RESTServer` 에 deinit 이 없어 해제돼도 listener 를 닫지 않음 · `start()` 재호출 시 이전 listener 참조만 덮어써 고아가 됨 · 교체된 listener 의 늦은 `.cancelled` 콜백이 새 listener 의 `isRunning` 을 덮을 수 있음
* 구현 명세:
    - `AppRuntime.appState`(static let, 프로세스 단일)가 AppState 를 강하게 소유. `@State` 제거
    - `AppState.initialize()` 1회 가드 (App.init 재호출 대비) · `AppState.instanceCount` 계측
    - `RESTServer`: `deinit` 에서 `listener.cancel()` · `start()` 가 이전 listener 를 먼저 cancel · self 부재 시 `connection.cancel()` · stateUpdateHandler 는 현재 listener 일 때만 반영
    - 재현 테스트 `RESTListenerLifecycleTests`(TDDPlaylistTests.swift) — 수정 전 jma 에서 3건 red(AppState 3개, 해제 후 포트 점유, 재시작 후 stop 해도 포트 점유)
* 검증 (2026-09-27, jma):
    - **red → green**: 수정 전 3건 red → 수정 후 `fWarrangeCliTests` **84/84 passed**(EXIT_0). 1차 수정(재시작 시 이전 listener 즉시 cancel)은 새 listener 가 준비되지 않아 1건 red — cancel 이 비동기라 같은 포트 재바인딩이 실패. 기존 `stop()→start()` 재시작 경로(메뉴·설정 PATCH)에도 잠재된 문제였으므로 «은퇴 완료(.cancelled) → 바인딩» 직렬화로 해소
    - **실환경**: jma `fwc-deploy-brew.sh local`(tmux·정식 서명) 재설치 → `brew services` started · 60초간 health **30/30** · `heap` AppState 1·RESTServer 1·listener 1 (수정 전 jm4 2·2)
    - 후속 후보: `allowExternal=false` 인데 listener 가 `*:3016`(tcp46)으로 바인딩됨 — `requiredLocalEndpoint` 를 listener 생성 **후** 설정해 반영 안 됨 (이슈후보 등록)

## Issue100: [Bug] PaidApp 생존추적 유닛테스트 7건 실패 — unregister 위조 회귀 + Logger 디렉토리(선재) (등록: 2026-09-27, 완료: 2026-09-27, Hash: 92fd06a) ✅
* 목적: `fWarrangeCliTests` 전체 실행 시 PaidApp 생존 추적 도메인 테스트 7건이 실패한다(66개 중). Issue94 검증 중 발견한 **선재 결함**으로 `showInCmdTab` 제거와 인과 없음. register/unregister 인가·세션 구분·로그 디렉토리 자동생성이 기대와 어긋난다
* 상세:
    - 실패 7건(5 케이스): `PaidAppRouterTests.testStatusReturnsRunningAfterRegister`(register 실패) · `.testUnregisterWithForgedSessionIdFails403`(위조 sessionId 가 403 아닌 success) · `PaidAppStateLoggerTests.testAutoCreateDirectory`(디렉토리·파일 자동생성 실패) · `PaidAppStateStoreTests.testSameBundleIdDifferentStartTimeProducesDifferentSessions`(XCTAssertFalse 실패) · `.testUnregisterWithForgedSessionIdFails`(위조 unregister 가 성공)
    - **cliApp 실행 여부 무관**: brew cliApp 을 stop 후 재실행해도 동일 7건 재현 → 실행 인스턴스 충돌 아님
    - **격리 결함 의심**: `PaidAppStateStore()` 를 인자 없이 생성(공유/실경로 상태)해 테스트 간·실행 잔여 상태와 충돌하는 것으로 추정. 위조 sessionId 통과·디렉토리 이미 존재 양상이 이를 시사
* 구현 명세:
    - 각 테스트가 임시 디렉토리(격리된 store 경로)를 쓰도록 setUp/tearDown 정비, 공유 상태 초기화. 인가 로직이 실제로 깨졌는지(코드 결함) vs 오염된 상태 탓인지 분리 확인
    - jma·jm4 양쪽에서 재현·수정 후 `fWarrangeCliTests` 전체 green 확인
    - 요청 출처: Issue94(showInCmdTab 제거) 검증 중 전체 스위트 실행에서 발견
* 검증·종결 (2026-09-27, Hash: 92fd06a):
    - **원인 3갈래 확정** (오진 2건 기각 — 상세 [`debug_TECH.md`](_public/cli/_doc_work/debug_TECH.md)): ① unregister 위조 통과 = 회귀 a197e62(`startTime nil → ?? true` 가 sessionId 불일치를 덮음) ② Logger 가 fileURL 주입 시 부모 디렉토리 미생성 ③ 테스트 bundlePath `"/p"` 가 setUp mock 미매핑 → 단계② forbidden
    - "실행 중 cliApp 충돌"·"테스트 격리 오염" 가설은 **단독 실행에서도 재현**돼 기각. 실행·순서 무관한 로직/데이터 결함
    - **수정**: unregister 는 sessionId 불일치 시 startTime 제공 시에만 fallback(위조 차단, 앱 코드) · appendSync 부모 디렉토리 자동생성(앱 코드) · 테스트 bundlePath 매핑 경로로
    - jma 검증: `fWarrangeCliTests` **66개 전부 green**(TEST SUCCEEDED)
    - ⚠️ **동작 변경**(unregister 위조 차단·Logger 디렉토리) 있음 — jm4 cliApp 재배포 필요 여부는 common-cf 에 보고(재배포는 잡/유휴 조건에서 처리)


## Issue94: [Cleanup] `showInCmdTab` 죽은 키 제거 — paidApp 소유 이전으로 소비처 소멸 (등록: 2026-09-04, 완료: 2026-09-27, Hash: 9376526) ✅
* 목적: paidApp 이 ⌘+Tab 앱 전환기 표시 설정의 소유를 자신의 UserDefaults 로 가져가면서(prj16#Issue276), cliApp 의 `showInCmdTab` 키는 **읽는 쪽도 쓰는 쪽도 없는 죽은 키**가 되었다. 남겨두면 소비처 없는 설정이 REST 응답·`_config.yml` 에 계속 노출되어, 다음에 이 키를 보는 사람이 "어딘가 쓰이겠거니" 하고 되살릴 여지를 남긴다
* depends: prj16#Issue276
* 상세:
    - **왜 paidApp 이 가져갔나**: `NSApp.setActivationPolicy` 는 paidApp **프로세스 자신의 상태**다. cliApp 설정 파일이 소유할 성질이 아니며, 실제로 저장(cliApp `showInCmdTab`)과 복원(paidApp `showInAppSwitcher`)이 갈라져 있어 토글이 재시작에 반영되지 않는 고장이 있었다. prj16#Issue276 에서 소유를 paidApp 으로 일원화하여 해소함
    - **현재 상태 실측**: paidApp 소스에 `showInCmdTab` 참조 0건(설명 주석 1건 제외). cliApp 은 여전히 키를 보유·응답하지만 그 값을 쓰는 클라이언트가 없다
    - 제거 대상 4곳:
        - `fWarrangeCli/_config.yml:30` — `showInCmdTab: true`
        - `fWarrangeCli/Models/AppSettings.swift:168,213` — 필드 선언·기본값
        - `fWarrangeCli/Models/AppSettings+Patch.swift:28,65` — 직렬화·패치 매핑
        - `fWarrangeCli/Services/RESTServer.swift:643` — `/settings/advanced` 허용 키 화이트리스트
* 구현 명세:
    - 위 4곳에서 키를 제거한다. `confirmBeforeDelete`·`clickSwitchToMain` 은 **그대로 둔다** — 두 키는 paidApp 고급 탭이 계속 사용 중이다
    - **API 스펙 동시 갱신 필수**(api-rules): `api/openapi_v2.yaml` 의 `/settings/advanced` 스키마에서 `showInCmdTab` 제거. 소스만 고치고 스펙을 두면 규칙 위반
    - 기존 사용자의 `_config.yml` 에 남은 `showInCmdTab` 행은 파싱 시 무시되므로 마이그레이션 불필요. 다만 설정 저장이 한 번 일어나면 자연히 사라진다
    - ⚠️ 제거 전 paidApp 최신 소스에서 `showInCmdTab` 참조가 여전히 0건인지 재확인할 것 — 확인 없이 제거하면 소유 이전이 되돌려진 경우를 놓친다
* 검증·종결 (2026-09-27):
    - **코드는 이미 제거됨**: 소스 4곳(AppSettings.swift 필드, AppSettings+Patch 직렬화·패치, RESTServer advanced 화이트리스트, _config.yml) + API 스펙(`openapi_v2.yaml` `/settings/advanced` 스키마 2곳)에서 `showInCmdTab` 전부 제거 확인. 제거는 9376526(Issue95 커밋)에 함께 반영돼 있었고 본 이슈는 명시 종결만 남아 있었다
    - **paidApp 소비처 0건 재확인**: `fWarrange/` 실참조 0
    - **회귀 없음 (jma, ff-only f4b59a2)**: `ServiceLabelAndPermissionTests` 11개 green — `showInCmdTab` 제거를 직접 검증(`fullSettingsDict`·`applySettingsPatch` 에서 nil)하는 케이스 포함. `confirmBeforeDelete`·`clickSwitchToMain` 은 보존
    - ⚠️ 전체 스위트에 **무관한 선재 실패 7건**(PaidAppRouter/StateStore/StateLogger — paidApp 생존 추적 도메인) 관측. cliApp 실행 여부와 무관하게 재현되며 `showInCmdTab` 과 인과 없음. 별도 Issue100 으로 분리
    - jm4 재배포 불필요: 동작 변경 없는 죽은 키 정리 — cliApp 재배포 없이 문서 종결

## Issue95: [Bug] Homebrew 서비스 label 규약 변경(`homebrew.mxcl.*` → `sh.brew.*`)으로 cliApp 무한 self-handoff — brew 최신 머신에서 기동 불가 (등록: 2026-09-05, 완료: 2026-09-27, Hash: 9376526, 203ca4f) ✅
* 목적: Homebrew 가 서비스 label 규약을 `homebrew.mxcl.{formula}` 에서 `sh.brew.{formula}` 로 바꿨다. cliApp 은 구 label 을 **소스 3곳에 하드코딩**하고 있어, 최신 brew 가 깔린 머신에서 `brew services start` 든 `open` 이든 앱이 `exit(0)` 으로 즉시 종료하며 **전혀 기동하지 못한다**. 크래시도 로그도 남지 않아 원인 파악이 어렵다. brew 를 업데이트하는 모든 사용자에게 순차적으로 도달하는 회귀이므로 조기 수정이 필요하다
* 상세:
    - **실발생**: 2026-09-05 jma(macOS 26.6.2) 에 cliApp 1.1.1 배포 중 발생. `brew update` 로 Homebrew 가 6.0.21-126 이 되면서 label 이 바뀜. jm4 는 6.0.21-83 이라 아직 구 label 을 써서 정상 동작 중 — **jm4 도 `brew update` 하는 순간 같은 장애가 재현된다**
    - **무한 루프 경로**: `BrewServiceSync.onAppStart()` 의 skip 조건 두 개가 모두 구 label 에 의존한다
        - `isLaunchedByLaunchd()` — `XPC_SERVICE_NAME == "homebrew.mxcl.fwarrange-cli"` 비교. 신규 label 은 `sh.brew.fwarrange-cli` 라 **launchd 가 띄운 프로세스조차 false** 로 판정
        - `isServiceLoaded()` — `launchctl list` 출력에서 구 label 을 찾음. 신규 label 로 등록돼 있어도 **false**
        - 두 skip 이 모두 빗나가 `performHandoffStart()` → `brew services start` → `Foundation.exit(0)` → launchd 가 새 프로세스 spawn → 같은 판정 반복. 프로세스가 하나도 남지 않고 brew state 는 `stopped` 로 수렴
    - **하드코딩 위치 3곳**:
        - `cli/fWarrangeCli/Services/BrewServiceSync.swift:16` — `static let serviceLabel`
        - `cli/fWarrangeCli/Services/SingleInstanceGuard.swift:19` — `launchdServiceLabel` (중복 인스턴스 판정 오작동)
        - `cli/fWarrangeCli/Services/LoginItemService.swift:29` — LaunchAgents plist 경로 (로그인 항목 연동 오작동)
    - **현재 우회 상태(jma)**: `defaults write kr.finfra.fWarrangeCli fwc.autoStartBrewService -bool false` 로 `onAppStart()` 첫 skip 조건을 태워 label 판정 자체를 건너뛰게 한 뒤 `open` 으로 수동 기동함. 앱·REST(3016) 는 정상이나 **재부팅 시 자동 시작되지 않는다**
* 검증 (2026-09-27, prj16 세션 · jma):
    - jma(Homebrew **7.0.6-64** = 신규 label 규약)에 HEAD `9c4bfd8` 을 tmux 경유 **정식 서명**으로 재빌드·배포 후 실측 — `brew services list` → `fwarrange-cli started` (`~/Library/LaunchAgents/sh.brew.fwarrange-cli.plist`) · `launchctl list` → `sh.brew.fwarrange-cli` exit 0 · cliApp 프로세스 **1개**(무한 self-handoff 흔적 없음) · REST 3016 정상 · 서명 주체 `Apple Development: JungGu Nam (3VGC26E2B8)`
    - 즉 **신규 label 머신에서 brew services 로 기동·유지됨**을 확인했다. 재시작(`brew services restart`) 2회도 단일 프로세스로 정상 복귀
    - ⚠️ **jm4 는 아직 미해소**: jm4 도 이미 Homebrew **7.0.6-70**(신규 규약)인데 `brew services list` 가 `fwarrange-cli none` 이고 설치 바이너리는 9/6 빌드(수정 이전)다. 현재 우회(`fwc.autoStartBrewService=false` + `open`)로 떠 있을 뿐이라 **재부팅 시 자동 시작되지 않는다**. jm4 재배포가 종결 조건 — 사용자가 jm4 를 쓰는 중이라 이번 세션에서는 미실행
* jm4 해소 (2026-09-27 14:14 — `prj26-finish-watch` 잡이 jm4 유휴 시 자동 재배포):
    - `fwc-deploy-brew.sh local` → **ALL CLEAR 11 PASS / 0 FAIL**. 우회 스위치 제거(`defaults delete kr.finfra.fWarrangeCli fwc.autoStartBrewService`) 후 `brew services restart`
    - 검증 4항 실측(`redeploy_20260927_140851.log`): `Successfully started fwarrange-cli (label: sh.brew.fwarrange-cli)` · REST 3016 = 200 · cliApp 프로세스 **1개**(self-handoff 흔적 없음) · launchd `sh.brew.fwarrange-cli` 1 → 요약 `deploy_rc=0 services=started procs=1 rest=200 launchd=1`
    - restart(stopped→started)도 단일 프로세스로 정상 복귀. jm4(신규 label Homebrew 7.0.6)에서 **brew services 자동 기동·재부팅 생존을 우회 없이 확보** — 종결 조건 충족. 근본 수정은 9376526(두 label 규약 동시 인식), jma 실측은 203ca4f
* 구현 명세:
    - label 을 단일 상수로 고정하지 말고 **두 규약을 모두 인식**한다. `["sh.brew.fwarrange-cli", "homebrew.mxcl.fwarrange-cli"]` 후보 배열로 두고 `isLaunchedByLaunchd()` 는 `XPC_SERVICE_NAME` 이 그중 하나와 일치하면 true, `isServiceLoaded()` 는 `launchctl list` 에 하나라도 있으면 true 로 판정
    - 더 견고한 대안은 label 문자열 비교를 버리고 **`~/Library/LaunchAgents/` 에서 formula 명을 포함하는 plist 를 탐색**해 그 `Label` 키를 읽는 동적 조회다. brew 가 규약을 또 바꿔도 따라간다. 어느 쪽을 택하든 세 파일이 **같은 판정 함수 하나를 공유**하도록 단일 지점으로 모을 것 — 지금처럼 3곳에 흩어져 있으면 다음 변경 때 또 반쪽만 고쳐진다
    - `LoginItemService` 의 plist 경로도 같은 조회 결과를 쓰도록 바꾼다
    - **회귀 검증**: 구 brew(jm4, 6.0.21-83)와 신 brew(jma, 6.0.21-126) 양쪽에서 ① `brew services start` 후 프로세스 생존 ② `open` 기동 후 프로세스 생존 ③ `/api/v2/status` 200 응답 ④ `brew services list` 가 `started` 로 표시 — 4항을 모두 확인한다
    - 수정 후 jma 의 우회 스위치를 되돌린다: `defaults delete kr.finfra.fWarrangeCli fwc.autoStartBrewService`
    - 관련 선례: Issue86(brew services 미등록 실행), Issue39 Phase4(SingleInstanceGuard 도입)

## Issue98: [Feat] Undo 기능 — 단축키로 창 재배치 직전 상태 복원 (등록: 2026-09-26, 완료: 2026-09-27, Hash: 9c4bfd8) ✅
* 목적: 레이아웃 복구(restore) 실행 직후, 단축키 한 번으로 복구 직전의 창 배치로 되돌리는 Undo 기능. 잘못된 복구를 즉시 취소할 수 있게 한다.
* 상세:
    - 복구 실행 **직전에 현재 창 배치를 스냅샷**으로 보관 → Undo 단축키로 그 스냅샷 복원
    - 5번째 글로벌 단축키 신규 지정 필요 (save/restoreDefault/restoreLast/showMainWindow 에 이어)
    - 스냅샷 보관 범위·수명·다중 Undo 여부 등 정책 결정 필요 → **신기능이라 brainstorming → 설계 선행**
* 구현 명세:
    - brainstorming 으로 트리거·스냅샷 보관 정책·단축키 확정 후 구현
    - 복구 경로(`WindowRestoreService`)와 캡처 경로(`WindowCaptureService`) 재사용 — 복구 직전 캡처를 임시 레이아웃으로 저장하는 방식 검토
* 진행 (2026-09-27):
    - 설계 확정(brainstorming): 단일 Undo(직전 1회)·복구 직전 전체 창 배치 스냅샷·메모리 휘발·F7 계열 기본값(⌃⌘F7). spec `cli/_doc_work/plan/undo_design.md`
    - **cliApp 구현 완료 (Hash: 9c4bfd8)**: `HotKeyAction.undo` + `AppState.undoSnapshot`(복구 직전 `captureCurrentWindows` 저장) + `case .undo` 복원. `UndoShortcutTests` 기본값(⌃⌘F7)·접근성 2건 통과
    - **paidApp Settings UI (prj16 Issue278, Hash: 590208f)**: Shortcuts 탭에 "되돌리기" 행 + `undoShortcut` 필드 + syncFromSettings/syncToCLI 배선
    - **XCUITest 재검증 (2026-09-27, jma, Automation Mode on)**: 1차 `has not loaded accessibility` 는 배포 앱(`/Applications/_nowage_app`) 종료로 제거. 2차 — "되돌리기:" 행 미도달로 실패(exit 65). 원인은 UI 회귀가 아니라 **테스트 하네스**: ⌘2 탭 전환이 `NSEvent.addLocalMonitorForEvents`(창 포커스 의존)라 XCUITest typeKey 로 불안정. undoShortcut UI 는 dylib 심볼 3개로 실재 확인(기능 정상)
    - **하네스 해소·최종 green (2026-09-27)**: prj16#Issue279 가 테스트 하네스를 견고화(f4966bd) — 실패 원인이 ⌘2 타이밍 한 겹이 아니라 세 겹이었다. ① 배포본(`/Applications/_nowage_app`) 단일 인스턴스 가드가 테스트 인스턴스를 `NSApp.terminate`(XCUITest 는 이를 `has not loaded accessibility` 로만 보고) ② 메인 창 scene `.defaultLaunchBehavior(.suppressed)`(Issue241)로 콜드 스타트 windows=0 → Window 메뉴로 메인 창 선행 오픈 ③ SettingsSheet 식별자가 하위로 전파돼 탭 식별자가 덮임 → 라벨 `(⌘2)`(로케일 무관) NSPredicate 로 특정. 앱 코드 무변경, 테스트 파일만 수정
    - **독립 재검증 (jma, 배포본 종료 후)**: `testUndoShortcutRowInSettings passed (11.738s), TEST SUCCEEDED` — fwarrange-1c 의 2회 green(12.3s/11.8s)과 합쳐 3회 일관 통과
* depends: prj16#Issue279 (해소 — f4966bd 수정, a46f171 종결)

## Issue99: [Bug] "Restore Default" 단축키가 작동하지 않는다 (등록: 2026-09-26, 완료: 2026-09-27, Hash: 962aad4, 9dc89df) ✅
* 목적: paidApp Settings 에서 지정한 "Restore Default"(기본 레이아웃 복구) 단축키(기본값 ⇧⌘F7)를 눌러도 복구가 실행되지 않는다. 사용자가 설정한 단축키가 무효한 것처럼 보인다. 원인이 코드인지 환경(키 리매핑)인지 jma 에서 재현·확정 후 원인을 제거한다.
* 상세:
    - `restoreDefaultShortcut` → `HotKeyService` Carbon 등록 → `AppState.handleHotKeyAction(.restoreDefault)` 경로
    - **다른 단축키(save 등)와의 비교가 진단 핵심** — 이 액션만 안 되면 코드(restoreDefault 분기), 전부 안 되면 등록·환경 문제
    - 이전 F5~F12/Karabiner 환경 문제(`cli/_doc_work/debug_TECH.md` 2026-09-06)와 구분: ⇧⌘F7 은 Karabiner `12Key2Knob` 가 shift+F7 을 매크로로 가로채는 조합이라 환경 요인이 유력하나 코드 경로도 함께 점검
* 구현 명세:
    - jma 에서 재현 → 원인 규명(환경 vs 코드) → 원인 제거 → 검증
    - 환경 요인이면 기본 단축키를 F7 비의존 조합으로 이전하는 것을 함께 검토
* 검증 (2026-09-27, prj16 세션 · jma HEAD 9c4bfd8 정식 서명 빌드):
    - **환경 가설 기각**: Karabiner `12Key2Knob` 의 F7 규칙 4종은 전부 `device_if`(vendor 4489 / product 34960) + 수식어 **exact match** 다(`mandatory: [shift]`, `optional` 없음). ⇧⌘F7 은 command 가 섞여 **어느 규칙과도 매칭되지 않는다** → Karabiner 는 이 조합을 가로채지 않는다. 등록 시 유력하다고 본 환경 요인은 원인이 아니다
    - **원인 = 코드(죽은 참조) 확정**: jm4 `defaultLayoutName = "2026-07-12-1"` 인데 현존 레이아웃 7개에 그 이름이 **없다**. jm4 설치 바이너리는 9/6 빌드로 수정(962aad4) 이전이라 존재하지 않는 이름으로 복구를 시도해 조용히 실패하는 상태가 지금도 유지되고 있다
    - **수정 유효 확인 (fallback)**: `defaultLayoutName` 에 존재하지 않는 이름(`ghost-layout-9999`)을 주입하고 restoreDefault 단축키(jma 설정값 ⌃⌥⌘D)를 tmux 경유로 발사 → **최신 레이아웃으로 fallback 복구가 실제 실행됨**(restore-stats `totalAttempts` 32→46, `successes` 31→45 = 창 14개). 조용한 실패가 사라졌다
    - ⚠️ **미해소 갭 — 근본예방 훅이 REST 경로에서 발동하지 않는다**: `onLayoutDeleted` 가 `AppState.settings`(프로세스 시작 시 로드한 **스냅샷**)와 이름을 비교하는데, `PUT /settings/default-layout` 는 저장소만 갱신하고 그 스냅샷은 갱신하지 않는다. 실측 — REST 로 기본 레이아웃을 바꾼 뒤 그 레이아웃을 삭제하면 `defaultLayoutName` 이 **죽은 이름으로 남는다**. cliApp 재시작 후(메모리=저장값) 같은 시나리오는 정상 정리된다(`default` 복귀)
    - **실사용 경로가 정확히 이 갭에 해당한다** — paidApp GUI 의 설정 변경은 전부 cliApp REST 를 타므로, 사용자가 GUI 로 기본 레이아웃을 바꾼 세션에서는 근본예방이 한 번도 작동하지 않는다
    - 수정 방향(제안): 훅에서 `self.settings` 대신 `settingsService.load()` 와 대조하거나, `mutate` 블록 안에서 비교·정리를 함께 수행 — 판정을 **저장소 단일 지점**으로 모은다
    - 잔여: jm4 는 수정 이전 바이너리를 쓰고 있어 **재배포 전까지 증상이 그대로**다 (jm4 사용 중이라 미실행)
* 해소 (2026-09-27, Hash: 9dc89df):
    - 위 미해소 갭 제거 — `AppState.clearDeadDefaultLayout(deletedName:svc:)` 신설. `onLayoutDeleted` 가 `self.settings`(프로세스 시작 스냅샷)이 아니라 `settingsService.load()`(최신 저장값)와 대조해 죽은 `defaultLayoutName` 을 정리한다. 판정을 **저장소 단일 지점**으로 통일 — REST 로 기본 레이아웃을 바꾼 세션에서도 근본예방이 발동한다
    - jma 검증: `UndoShortcutTests` 4건 전부 통과(`TEST SUCCEEDED`) — REST 최신값 기준 정리(`testClearDeadDefaultLayoutViaLatestStore`)·비일치 무시(`testClearDeadDefaultLayoutIgnoresNonMatch`) 포함
    - 테스트 인프라: XCTest host app 이 `Early unexpected exit`(exited with code 0 before establishing connection)로 죽던 문제도 함께 해결 — `AppEntry.main` 이 XCTest 환경에서 CLI·중복차단만 건너뛰고 `fWarrangeCliApp.main`(GUI RunLoop)은 유지하도록 수정
    - 잔여(비차단): jm4 재배포 시 수정 반영 — 사용자 사용 중이라 미실행. restoreDefault fallback fix 자체는 962aad4

## Issue76: paidApp 실행 감지 시 메뉴바 아이콘 즉시 전환 (등록: 2026-05-17, 보류: 2026-05-17, 완료: 2026-09-19 — 구현 불필요 확정) ✅
* 목적: paidApp launch 시 메뉴바 아이콘 즉시 전환 보장
* depends: Issue75 (완료 `7b2e44b` — 의존 해소됨)
* 결론: **재개 조건 미충족이 실측으로 재확인되어 구현 불필요로 확정**하고 보류 섹션에서 내보냄. 등록 당일 보류 사유였던 "기존 메커니즘(PaidAppMonitor launch 핸들러 → AppState `startObservingMenuBarIcon` → MenuBarManager `observeIcon`) 정상 동작"이 4개월 뒤 클린 환경에서도 그대로 성립함.
* 재검증 실측 (2026-09-19, jma 클린 환경 / paidApp·cliApp 모두 1.1.1):
    - 측정 방법: cliApp 로그 레벨이 critical(5)이라 `logI` 가 파일에 남지 않으므로 로그 대신 **메뉴바 픽셀을 직접 관측**했다. 상태아이콘 구역(X=600~800, 높이 30pt)을 0.12초 간격으로 촬영해 md5 가 바뀌는 시점을 측정하고, `logs/paidapp_state_transitions.log` 로 교차 확인했다.
    - **paidApp 종료 → cliApp 아이콘 복원: 0.66초**
    - **paidApp 실행 → paidApp 활성 아이콘 전환: 0.45초**. 같은 사이클에서 앱 기동 완료(`event=register`)까지는 2.2초가 걸렸으므로, 아이콘 전환은 기동 완료를 기다리지 않고 `didLaunchApplicationNotification` 시점에 일어난다.
    - 왕복 복귀 일치: 전환 전 md5 `9fb157b092` = 재전환 후 md5 `9fb157b092` 로 완전 일치. 누락·잔상 없음.
    - 상태 전환 로그 교차 확인: `cleanup(didTerminate) 2026-09-19T03:33:00.147Z` → `register 2026-09-19T03:33:02.358Z`.
    - 증거: `cli/_doc_work/report/issue76_20260919/` (메뉴바 전체 스트립 3종 + `result.json`)
* 계측 함정 (다음 사람을 위한 기록):
    - 메뉴바 status item 은 `CGWindowListCopyWindowInfo` 에 **잡히지 않는 경우가 있다**. `fWarrangeCli` 는 layer 25 창이 0건으로 열거돼 창 단위 캡처(`screencapture -l`)가 불가했고, 구역 캡처(`-R`)로 우회해야 했다.
    - 상태아이콘은 **우측 정렬**이라 아이콘이 하나 사라지면 그 **왼쪽 항목들이 오른쪽으로 밀린다**. 처음 잡은 프로브 구역(X=820~1300)은 변화 지점의 오른쪽이라 전환을 전혀 못 잡았다. 실제 전환 구간은 X=600~800 이었다.
    - 시계(X≈1327~)와 앱 메뉴(좌측)는 관계없이 바뀌므로 프로브 구역에서 반드시 제외한다.
* 참조:
    - `cli/fWarrangeCli/Managers/PaidAppMonitor.swift:39-51`
    - `cli/fWarrangeCli/AppState.swift:504-526`
    - `cli/fWarrangeCli/Managers/MenuBarManager.swift:29-67`

## Issue97: cliApp AppIcon 전 사이즈 확대 크롭 손상 — 유료 앱 원본으로 재생성 (등록: 2026-09-09, 완료: 2026-09-09) (Hash: 0fd89c2) ✅
* 목적: `cli/fWarrangeCli/Assets.xcassets/AppIcon.appiconset` 의 아이콘이 **7개 사이즈 전부** 확대 크롭돼 있었다. "infra" 의 뒷 글자와 여우 심볼 일부가 프레임 밖으로 잘려 CLI 앱 아이콘이 온전히 표시되지 않는다.
* 상세:
    - 증상: 16~1024px 7개 파일이 모두 같은 비율로 확대 크롭 — 원본 하나가 이미 잘린 상태에서 세트가 생성된 것으로 보인다
    - 대조 실측: 유료 앱 `fWarrange/fWarrange/Assets.xcassets/AppIcon.appiconset/icon_1024.png` 와 `_public/manual/app-icon.png` 는 **평균 픽셀차 0.0 으로 완전히 동일**한 정상 원본이다. cliApp 은 별도 디자인을 가진 적이 없다
    - 파급: prj10(finfraHome) 제품 페이지의 CLI 아이콘과 실제 앱 아이콘이 어긋나 있었다. prj10 Issue41 로 별도 추적
* 구현 명세:
    - 유료 앱 `icon_1024.png` 를 원본으로 `Contents.json` 의 7개 항목(16/32/64/128/256/512/1024px)을 LANCZOS 리사이즈로 재생성
    - 검증: 재생성본 16·128·1024px 렌더로 크롭 없음 육안 확인 완료
    - 참고: Issue76 계열의 **메뉴바 아이콘**(paidApp/cliApp 전환)은 AppIcon 과 별개 에셋이므로 본 수정의 영향 범위 밖이다
    - 남은 결정: cliApp 에 유료 앱과 구별되는 전용 아이콘이 필요한지는 별도 판단 사항

## Issue96: [Permission] 운영 중 접근성 권한이 제거되면 단축키가 조용히 죽는다 — 감지·안내 부재 (등록: 2026-09-06)
* 목적: 권한을 **앱 시작 시에만** 확인하므로(`AppState.swift:467`), 운영 중 사용자가 접근성 권한을 제거하면 단축키가 **아무 안내 없이 안 먹기 시작**한다. 사용자는 앱이 고장난 줄로만 안다.
* 상세:
    - **prj25(fSnippetCli) Issue211~227 조사에서 파생.** 그쪽은 같은 상황에서 **키보드 전체가 잠기는** 심각한 증상이었고, 원인·해법이 모두 규명됐다
    - ⚠️ **본 프로젝트는 그 심각도가 아니다** — 아래 구조 차이로 **락이 구조적으로 불가능**하다. 심각도는 "기능이 조용히 죽는다" 수준
    | 항목             | fSnippetCli (prj25)                       | fWarrangeCli (본 프로젝트)            |
    | :--------------- | :---------------------------------------- | :------------------------------------ |
    | 키 수신          | `CGEvent.tapCreate` — 전 입력이 통과      | **Carbon `RegisterEventHotKey`**      |
    | 보조             | NSEvent 글로벌 모니터                     | NSEvent **로컬** 모니터(앱 활성 시만) |
    | 입력 스트림 개입 | 전면                                      | 등록된 단축키만                       |
    | 권한 상실 시     | 전 입력이 tap 반환을 대기 → **시스템 락** | 단축키만 무효 → **락 없음**           |
    - `cli/` 소스에 `CGEvent.tapCreate` **0건** (grep 히트는 전부 `agents/gemini/skills/` 하위 유틸 스크립트)
    - `HotKeyService.swift:23` 이 선택 이유를 기록 — *"NSEvent.addGlobalMonitorForEvents는 이벤트 소비 불가 → 비프음 발생"*
    - 아울러 `AppState.swift:466` 주석이 이미 `prompt:false` 를 지키고 있다. prj25 가 Issue222~227 에서 네 라운드에 걸쳐 배운 *"`prompt: true` 는 실행 중 프로세스에 무효"* 를 **본 프로젝트는 이미 알고 회피 중**이다
* 구현 명세:
    - **감지 — 본 프로젝트에 맞는 비대칭을 쓴다.** prj25 의 Issue220(CGEventTap ↔ NSEvent 모니터 비대칭)은 CGEventTap 이 없어 그대로 옮길 수 없다. 대신:
        - `RegisterEventHotKey` 로 등록한 핫키는 **권한과 무관하게 눌린다**
        - 반면 창 조작 API(`AXUIElement*`)는 권한이 없으면 **실패한다**
        - 즉 **"핫키는 들어왔는데 창 조작이 실패"** 가 권한 상실의 관측 증거다
    - **안내 — `Restart Now` 단일 버튼** (prj25 Issue225 결론 재사용). 실행 중인 프로세스는 접근성 목록에 스스로를 되돌릴 수 없으므로 재시작이 유일한 복구 경로다. 설정 창을 열어도 목록에 항목이 없어 켤 대상이 없다
    - **중복 방지 필수** (prj25 Issue221) — `NSAlert.runModal()` 은 블로킹이라 가드가 없으면 호출이 큐에 쌓여 닫는 즉시 또 뜬다. `isPresenting` 플래그로 억제
    - ⚠️ **`prompt: true` 를 쓰지 않는다** (prj25 Issue227) — 실행 중 프로세스에는 효과가 없고 창만 반복 표시된다
    - **부수 정리**: `AccessibilityService.requestAccessibility()`(내부 `prompt: true`)와 `WindowManager` 의 래퍼는 **호출부 0건인 죽은 코드**다. 남겨두면 나중에 누군가 이것을 쓰다가 prj25 가 겪은 함정에 그대로 빠진다
* 참고: prj25 `_public/Issue.md` Issue211~227 (완료) · `cli/_doc_work/debug_TECH.md` "반증된 가설 3건과 진단 플로우"
* ✅ **해결 (2026-09-08, commit: 9376526 — jma 검증 완료)**
    - 구현은 `9376526` 에 이미 포함돼 있었고 커밋 메시지가 *"아직 미검증 진행 중 코드 — jma 클린 테스트 기준점 확보용"* 이었다. 본 항목은 그 **jma 검증**을 마친 기록이다
    - **빌드**: jma Release 빌드 성공. ⚠️ ssh 직접 실행은 codesign 에서 `errSecInternalComponent` 로 실패하므로 **tmux 경유**가 필수다(prj25 deploy 스킬과 동일 제약)
    - **테스트**: `ServiceLabelAndPermissionTests` **11개 전부 통과** — brew label 신구 규약 인식(Issue95), 죽은 설정 키 제거, `showMainWindow` 가 접근성 권한을 요구하지 않음 등
    - **실환경 확인**: jma brew 서비스가 신규 규약 label `sh.brew.fwarrange-cli` 로 기동됨 — Issue95 대응이 실제로 동작
    - ⚠️ **남은 것**: 접근성 권한을 실제로 회수한 상태의 **실기 시나리오 검증은 하지 않았다**(권한 회수가 다른 도구에 영향을 주므로). 안내 표시 경로는 단위 테스트 수준까지만 확인됐다
    - ⚠️ **동반 관찰**: 같은 실행에서 `PaidAppRouterTests`·`PaidAppStateLoggerTests`·`PaidAppStateStoreTests` **7건이 실패**한다. 본 이슈와 무관한 기존 테스트이며 공유 상태(파일·실행 중 인스턴스)에 의존하는 성격으로 보인다 — 별도 확인 대상
    - ⚠️ **테스트 실행 제약**: `SingleInstanceGuard` 가 테스트 러너를 종료시켜(`Early unexpected exit`) 테스트가 아예 시작되지 않는다. `brew services stop fwarrange-cli` 로 기존 인스턴스를 내린 뒤에야 실행된다

## Issue93: [Docs] CLAUDE.md 커맨드·에이전트 테이블이 실제 `.claude/` 구성과 불일치 (등록: 2026-08-18, 완료: 2026-08-18, Hash: 문서 미추적 — 아래 명세 참조) ✅
* 목적: `CLAUDE.md` 의 SCAR 목록 표가 실제 `.claude/commands/`·`.claude/agents/` 구성보다 낡아, 신규 커맨드·에이전트를 세션이 인지하지 못함. consultant-m 검토 발견(2026-08-18).
* 상세:
    - 커맨드 표(138~152행): 11개만 나열(build·deploy·dev·run·verify·git·issue·issue-reg·issue-fix·issue-closer·refactor). 실제 `.claude/commands/` 는 **14개** — `api-test.md`·`brew-apply.md`·`doc-work-archive.md` 누락
    - 에이전트 표(154~164행): 7개만 나열(build·build-doctor·deployment·git·refactor·rule-manager·verify). 실제 `.claude/agents/` 는 **8개** — `doc-work-archive.md` 누락
    - 원인: 신규 SCAR 도입 시 `CLAUDE.md` 표 갱신이 절차에 없어 누락 누적
    - 앱 런타임 무관 — 문서 전용. 릴리스 안전(releaseSafe)
* 구현 명세:
    - 누락 3커맨드·1에이전트를 각 파일 frontmatter `description` 원문 기준으로 표에 추가. 기능 그룹 순서 유지(`brew-apply` 는 `deploy` 뒤, `api-test` 는 `verify` 뒤, `doc-work-archive` 는 말미)
    - 컬럼 폭을 최장 항목(`doc-work-archive`)에 맞춰 양 표 재정렬
    - 검증: `ls .claude/commands/` 14건·`ls .claude/agents/` 8건과 표 행 수 1:1 대조 완료
    - ⚠️ **커밋 해시 없음**: `CLAUDE.md` 는 [.gitignore](.gitignore) 3행으로 **untracked** — 본 repo(공개 배포용)에서 추적하지 않는 로컬 전용 문서임. 수정은 워킹트리에 반영 완료했으나 커밋 대상이 아니며, `git add -f` 는 로컬 문서를 공개 repo 에 유출시키므로 수행하지 않음
    - 후속(선택): 신규 SCAR 추가 시 `CLAUDE.md` 표 갱신을 `rule-manager` 에이전트 체크리스트에 편입 🚧

## Issue92: [Docs] noteForHuman.md 배포 버전 표기가 실제(1.1.1)보다 낡음(1.0.2) (등록: 2026-08-18, 완료: 2026-08-18, Hash: 문서 미추적 — 아래 명세 참조) ✅
* 목적: 개발자 참고문서 `noteForHuman.md` 의 배포 버전 주석이 1.0.2 로 남아, 실제 배포본(1.1.1)과 어긋난 채 안내됨. consultant-m 검토 발견(2026-08-18).
* 상세:
    - `noteForHuman.md:26` — `# 현재 배포 버전: 1.0.2 (cli-v1.0.2)` (빠른 시작 curl 예시 블록의 헤더 주석)
    - 실측 SSOT 는 모두 1.1.1 로 정합: [VERSION](VERSION)(1.1.1) · `cli/version-meta.yml`(1.1.1, Issue91 동기화) · `cli/Formula/fwarrange-cli.rb` URL basename(`cli-v1.1.1`) · Issue89·91 종결 기록
    - 2026-07-21 Issue89(1.1.1 신규 릴리스) 종결 시 본 문서만 갱신 누락
    - 주석 문자열이라 앱 런타임·빌드 산출물 무관. 릴리스 안전(releaseSafe)
* 구현 명세:
    - 26행을 `# 현재 배포 버전: 1.1.1 (cli-v1.1.1)` 로 수정 (VERSION 파일 실측값 기준)
    - 검증: [VERSION](VERSION) 내용과 문자열 일치 확인. 다른 버전 표기 잔존 없음
    - ⚠️ **커밋 해시 없음**: `noteForHuman.md` 는 [.gitignore](.gitignore) 17행으로 **untracked** — 로컬 전용 문서. 워킹트리 수정만 완료, `git add -f` 미수행(Issue93 과 동일 사유)

## Issue91: [Chore] brew 원격 배포(publish) 사전 준비 점검 — 버전 정합·Release 빌드 확인 (등록: 2026-08-18, 완료: 2026-08-18, Hash: f3609d7) ✅
* 목적: GitHub API major outage 로 `/deploy brew publish` 실행이 불가한 상황에서, 원격 배포 전 사전 점검(버전 정합·빌드 통과)만 선행 수행 (pm-do 위임, 원격 배포 자체는 금지 범위)
* 상세:
    - VERSION(1.1.1) 기준 정합 점검: `cli/Formula/fwarrange-cli.rb` 는 URL basename `fWarrangeCli-1.1.1.tar.gz` 로 정합 (Issue89 설계 — version 필드 없음, URL 스캔이 SSOT)
    - `cli/version-meta.yml` mirror 값 3곳(version·formula_version·installed_version)이 1.0.1 로 낡아 있음 → 1.1.1 로 동기화, checked 일자 갱신 (brew list 실측: fwarrange-cli 1.1.1)
    - Release 빌드 통과 확인: `xcodebuild -scheme fWarrangeCli -configuration Release build` exit 0 (Sendable 경고만, 에러 0). 배포 없음
* 구현 명세:
    - 검증: Formula URL·sha256 은 cli-v1.1.1 릴리스 기준 유지, publish 시 `fwc-deploy-brew.sh` 게이트 2종(version_gate·bundle_version_gate)이 재검증
    - 후속: GitHub API 복구 후 `/deploy brew publish` 실행 가능 (준비 완료 상태)

## Issue89: [Bug] 배포 사고 — brew 패키지 라벨(1.1.0)과 앱 번들 실제 버전(1.0.2) 불일치 (등록: 2026-07-17, 완료: 2026-07-21, Hash: da9c41a, release: cli-v1.1.1) ✅
* 목적: `brew install fwarrange-cli`로 **1.1.0을 설치해도 실제로 깔리는 앱은 1.0.2**임. 패키지 라벨과 번들 실체가 어긋난 채 이미 배포됨. `VERSION` 파일만 bump되고 xcodeproj `MARKETING_VERSION`이 따라가지 않아 발생. paidApp(prj16) Issue267 버전 SSOT 작성 중 실측 발견.
* 실측 근거 (2026-07-17, 사고 상태):
    | 위치                                                              | 값                  |
    | :---------------------------------------------------------------- | :------------------ |
    | `_public/VERSION`                                                 | **1.1.0**           |
    | `cli/fWarrangeCli.xcodeproj` `MARKETING_VERSION` (2곳: 514·636행) | **1.0.2**           |
    | `cli/Formula/fwarrange-cli.rb` `version`                          | **1.0.0**           |
    | brew 설치 패키지 라벨                                             | **1.1.0**           |
    | **brew 설치본 앱 번들 실측**                                      | **1.0.2** 🔴         |
    | 실행 중 데몬 REST 응답                                            | 1.0.2 (구 프로세스) |
* 원인 (메커니즘 확정): `fwc-deploy-brew.sh`가 `VERSION`만 읽어 tarball명·Formula version(=패키지 라벨)을 생성하는데, 앱 번들 실체 버전은 xcodeproj `MARKETING_VERSION` → `Info.plist`로 흐름. **두 경로가 독립**이고 교차 검증 지점이 없어 `VERSION`만 올리면 라벨=1.1.0·내용물=1.0.2. 빌드·설치 모두 성공하여 무인지.
* 해결 (2026-07-21):
    - **T1** ✅: xcodeproj `MARKETING_VERSION` → 1.1.1 (2곳, VERSION과 강제 동일). `CURRENT_PROJECT_VERSION`은 `= 1` 빌드번호 트랙으로 별도 유지(정책 확인).
    - **T2** ✅: 재빌드 + `/deploy brew local` → **3중 실측 정합**: 셀러 라벨·번들(`CFBundleShortVersionString`)·데몬 REST 모두 `1.1.1`.
    - **T3 (재발 방지, 핵심)** ✅: `fwc-deploy-brew.sh` 게이트 2종 신설 (local·publish 양 경로). `version_gate`: `VERSION` ≠ `MARKETING_VERSION` 이면 빌드 전 중단. `bundle_version_gate`: 빌드 산출물 `CFBundleShortVersionString` ≠ `VERSION` 이면 패키징 전 중단. 3케이스(정합/드리프트/번들불일치) 동작 검증 완료.
    - **T4** ✅: `Formula/fwarrange-cli.rb` 미사용 화석 `version "1.0.0"` 제거 — tap이 URL basename에서 버전 스캔하므로 `VERSION` 단일 SSOT. 파일은 참조 스냅샷임을 헤더에 명시.
    - **T5** ✅: 재배포 방침 = **1.1.1 신규 릴리스** (버전 역행 회피, 태그 불변 원칙 유지). `/deploy brew publish` → `cli-v1.1.1` GH release + `Finfra/homebrew-tap` push 완료. 원격 Formula 실측: url basename `1.1.1`, sha256 `af8dca78…` 일치. 기존 사고 릴리스 `cli-v1.1.0`은 그대로 두되, 사용자는 `brew upgrade`로 정상 1.1.1 번들 획득.
* 참조: paidApp 버전 관리 SSOT `~/_git/__all/fWarrange/_doc_arch/version_manage_with_cliApp.md`. paidApp 측 이슈: prj16#Issue267.

## Issue90: cli/_doc_arch 문서 ↔ 소스코드 정합성 감사 2차 및 갱신 (등록: 2026-07-20, 완료: 2026-07-20, Hash: 306a5cc) ✅
* 목적: 1차 감사(2026-06-15, 체크포인트 609c51d) 이후 소스 변경분(Issue80 settings 원자화, Issue81 AutoCapture 신설, Issue82 brew publish, ff36f3d showSettingsShortcut 제거, Issue85 MCP v2, Issue87 이중 라이선스, Issue88 MenuBar fallback 제거)이 `cli/_doc_arch/` 문서에 미반영 — 문서·소스 대조 후 불일치를 문서에 직접 갱신.
* 상세:
    - 대상 8문서 감사 → **총 32건 수정** (문서 30건 + `api/openapi_v2.yaml` 스키마 2건). 병렬 subagent 5기 + 메인 직접(README.md·yaml)
    - 주요 교정: 라인 참조 드리프트 15건(Issue88 -5줄 시프트 등), `containsTitle` 단방향 정정, 캡처 이름 생략 기본값 `"default"` 폐기 반영(실제 `nextDailySequenceName()`), Formula 실배포 방식(사전 빌드 tarball), 깨진 링크 3건, `--help` 출력 예시 현행화, 다국어 리소스 실체(`LocalizedStringManager.swift` 하드코딩) 정정
    - 부수 발견·해소: 소스 `matchAreaMatchEnabled`(RESTServer.swift:642)가 `openapi_v2.yaml` `FullSettings`/`RestoreSettings` 스키마에 미정의 (api-rules 위반) → 스키마 추가
* 구현 명세:
    - 리포트: `cli/_doc_work/report/cli-doc-arch-audit2_report.md` (문서별 수정 내역 + 소스 근거 file:line)
    - 검증: `python3 yaml.safe_load` 파싱 통과. Swift 코드 무변경 — 빌드 불필요
    - git 추적 변경분만 커밋(306a5cc): openapi_v2.yaml + RestAPI_v2.md + window_recognize.md. 나머지 문서·리포트는 gitignored 로컬 전용

## Issue88: [Bug] MenuBarManager "Open Main Window" 항목이 미등록 fallback 단축키를 실제 등록된 것처럼 표시 (등록: 2026-07-16, 완료: 2026-07-16, Hash: a4292c1) ✅
* 목적: 메뉴바 "Open Main Window" 항목이 실제로는 등록되지 않은 fallback 단축키(`⌃⇧⌘F7`)를 라벨로 표시해, 사용자가 실제 동작하는 글로벌 단축키로 오인함. paidApp(fWarrange) Settings 패널은 실제 상태("Not Set")를 정확히 표시 중이었고, 그 과정에서 이 불일치가 발견됨 (paidApp #Issue266).
* 상세:
    - `Managers/MenuBarManager.swift:12` — `fallbackShowMain = KeyboardShortcutConfig.from(displayString: "⌃⇧⌘F7")` 정의.
    - `Managers/MenuBarManager.swift:119` — 메뉴 항목 라벨에 `state.settings.showMainWindowShortcut ?? MenuBarManager.fallbackShowMain` 사용 → 실제 설정이 `nil`이어도 메뉴에는 항상 `⌃⇧⌘F7`가 표시됨.
    - `Services/HotKeyService.swift` `register(settings:handler:)` — `showMainWindowShortcut`이 `nil`이면 `validShortcuts`에서 제외되어 Carbon 핫키로 **등록되지 않음**. 즉 메뉴에 보이는 `⌃⇧⌘F7`는 실제로 눌러도 동작하지 않는 "가짜" 표시.
    - `Models/AppSettings.swift:200` — `showMainWindowShortcut` 기본값 `nil` (Issue61 의도: `_config.yml`에 명시된 항목만 글로벌 등록되도록 보장).
    - `Services/RESTServer.swift:801-804` / `AppState.swift:225-234` `getShortcutsDisplay()` — `s.showMainWindowShortcut?.displayString ?? ""`로 실제 값만 반환(fallback 미적용). paidApp은 이 값을 그대로 표시하므로 "Not Set"이 **정확한 표시**임 — paidApp 측 버그 아님.
    - 참고: `saveShortcut`/`restoreDefaultShortcut`/`restoreLastShortcut`는 `MenuBarManager`에서도 동일하게 fallback 상수(`fallbackSave` 등)를 쓰지만, 이들은 실사용자 환경에서 `_config.yml`에 이미 명시적으로 설정되어 있어 fallback이 노출된 적이 없었던 것으로 추정. `showMainWindowShortcut`만 미설정 상태로 남아 fallback 표시가 그대로 드러난 것으로 보임.
* 구현 명세: `MenuBarManager.swift`에서 fallback 상수 4개(`fallbackSave`/`fallbackRestoreLast`/`fallbackRestoreDefault`/`fallbackShowMain`) 및 관련 주석 삭제. 4개 메뉴 항목 모두 `state.settings.X ?? fallback` → `state.settings.X` 로 변경 — `makeShortcutItem`이 `nil`을 이미 처리(keyEquivalent 빈 문자열)하므로 실제 등록된 단축키만 라벨에 표시됨. Save/RestoreDefault/RestoreLast 3개도 동일 정책 일괄 적용(옵션 1 채택).
* 검증: `xcodebuild -scheme fWarrangeCli -configuration Release build -quiet` 성공(exit 0) + `_tool/fwc-deploy-debug.sh` 배포·기동 + `curl localhost:3016/` 정상 응답(`isRunning: true`) 확인. UI 상 메뉴 항목 직접 클릭 검증은 미실시(REST/기동 레벨 검증만) — 후속 육안 확인 권장.
## Issue87: 라이선스 정책 변경 — 이중 라이선스(CC BY-NC 4.0 무료 + 상업 라이선스 유료) (등록: 2026-07-13, 완료: 2026-07-15, Hash: ffa4df9, c4e39f5, b4a874b) ✅
* 목적: 기존 "All rights reserved" 단일 저작권 고지를 이중 라이선스 체계로 전환 — 비상업 이용은 CC BY-NC 4.0 무료, 상업 이용은 유료 상업 라이선스
* 상세:
    - 사용자 결정 (hub 폼 회수): 무료 축 = CC BY-NC 4.0 (요청 원문 CC BY 4.0은 상업 이용도 무료 허용이라 이중 라이선스 모델과 상충 → BY-NC 채택), 기존 MIT 컴포넌트(mcp·Formula)도 이중 라이선스로 통일
    - 신규: 루트 `LICENSE` (이중 라이선스 전문, 영문)
    - 갱신: `README.md`·`README_kr.md`·`cli/README.md`·`cli/README_kr.md`·`mcp/README.md`·`mcp/README_kr.md` License 섹션
    - 갱신: `mcp/package.json` license 필드 `MIT` → `(CC-BY-NC-4.0 OR LicenseRef-Commercial)`, `cli/Formula/fwarrange-cli.rb` `license "MIT"` → `license any_of: ["CC-BY-NC-4.0", :cannot_represent]`
    - 2차 잔존 정리 (2026-07-15, GitHub 원격 전수 감사): `cli/_tool/fwc-deploy-brew.sh` Formula 재생성 heredoc 2곳(L195·L512) `license "MIT"` → dual DSL (brew 배포 시 MIT 회귀 차단), `api/openapi_v1.yaml`·`api/openapi_v2.yaml` info.license MIT → dual + LICENSE URL, `manual/en/08_FAQ.md`·`manual/kr/08_FAQ.md` "MIT 오픈소스" 답변 → 이중 라이선스 안내 (Hash: b4a874b)
* 구현 명세:
    - npm 기배포 버전(≤1.0.2)은 MIT로 배포된 사실 불변 — LICENSE·mcp README에 명시. 신규 배포분부터 이중 라이선스 적용
    - 상업 라이선스 문의 채널: https://finfra.kr
    - 운영 후속(별도): npm 1.0.3+ 재배포 시 레지스트리 표기 갱신, brew tap 재배포 시 신규 Formula 라이선스 반영
* 검증: 원격(origin/main) + 작업 트리 grep 전수 — "All rights reserved"·MIT license 필드 잔존 0건 (기배포 MIT 유지 고지 문구는 의도된 예외). bash -n·yaml 파싱 정상

## Issue86: fwarrange-cli brew services 미등록 실행 — 서비스 등록 조치 (등록: 2026-07-05, 완료: 2026-07-05, Hash: 026fdee) ✅
* 목적: fwarrange-cli 데몬이 brew services 미등록 상태(launchctl 라벨 application.*)로 직접 실행 중이라 재부팅 시 자동 시작이 안 됨. brew services 정식 등록으로 라이프사이클 정상화
* 상세:
    - 진단: brew services list → fwarrange-cli "none", 실제로는 PID 1048로 /opt/homebrew/Cellar/fwarrange-cli/1.0.1/fWarrangeCli.app 실행 중
    - 근거: launchctl 라벨이 homebrew.mxcl.* 이 아닌 application.kr.finfra.fWarrangeCli.* — 앱 직접 open 경로로 기동된 상태
    - ~/Library/LaunchAgents/에 homebrew.mxcl.fwarrange-cli.plist 부재
    - 리스크: 재부팅 시 자동 시작 안 됨 (배포 형태 SSOT: brew services start fwarrange-cli 가 정상 기동 경로)
    - 출처: ___common 세션 진단 문서 hub_htm_20260705_152219_a_brew-services-mismatch.htm
* 구현 명세 (운영 조치 — 코드 변경 없음):
    1. `pkill -f 'MacOS/fWarrangeCli'` — 기존 직접 실행 프로세스(PID 1048) 종료 (중복 기동 방지)
    2. `brew services start fwarrange-cli` — LaunchAgent 등록·기동 (`homebrew.mxcl.fwarrange-cli.plist` 생성)
* 검증:
    - `brew services list` → fwarrange-cli **started**
    - `launchctl list` → 라벨 `homebrew.mxcl.fwarrange-cli` (PID 60467, exit 0) — application.* 라벨 소멸
    - `curl :3016/` → `status: ok`, version 1.0.1
    - `POST /api/v2/capture` 실동작 27개 창 캡처 성공 (접근성 권한 유지 확인) 후 테스트 레이아웃 삭제
## Issue83: [MCP] npm 재배포 — fwarrange-mcp v1.0.2 (등록: 2026-06-21, 완료: 2026-06-22, Hash: b587581) ✅
* 목적: fwarrange-mcp MCP 서버를 npm 레지스트리에 재배포하여 최신 변경분(v2 마이그레이션)을 공개 패키지에 반영.
* depends: Issue85
* 결과:
    - Issue85 코드 변경분 포함하여 `fwarrange-mcp@1.0.2` npm 배포 완료 (registry `latest`=1.0.2 검증)
    - 버전 1.0.0→1.0.2 (당초 1.0.1 계획 → VERSION SSOT 정합 위해 1.0.2)
    - tarball: index.js + README.md + package.json (3파일, 5.5kB)
    - 검증: `npm view fwarrange-mcp version` → `1.0.2`, dist-tags.latest=1.0.2

## Issue85: [MCP] fwarrange-mcp index.js를 REST API v2로 마이그레이션 — v1 410 Gone 회귀 수정 (등록: 2026-06-22, 완료: 2026-06-22, Hash: b587581) ✅
* 목적: `mcp/index.js`의 모든 REST 호출이 `/api/v1/*` 사용 중. v1은 deprecated → `410 Gone`(Issue213 Phase 1). v2 cliApp 상대로 MCP 전체 미동작. v2 마이그레이션 + v2에 없는 `/locale` tool 제거.
* task: `cli/_doc_work/tasks/mcp-v2-migration_task.md`
* 결과:
    - `API_BASE="/api/v2"` 상수 추출, `/api/v1/` 12곳 전부 v2 교체 (grep `/api/v1/`=0건)
    - get_locale·set_locale tool 삭제 (15→13개, locale은 cliApp 메뉴바 daemon 미제공)
    - version 1.0.0→1.0.2 (VERSION SSOT 정합), `node --check` 통과
    - `README.md`·`README_kr.md` locale tool 섹션 제거, v1 잔존 0건
    - public 코드 주석 영어 규칙 준수 (API_BASE 주석 영문화)

## Issue81: [Feat] 시스템 슬립/잠금 시 자동 레이아웃 캡처 + retentionDays 자동 삭제 + isAuto 표식 (등록: 2026-06-15, 완료: 2026-06-21, Hash: a980016) ✅
* 목적: 시스템 슬립/화면 잠금 시 자동으로 레이아웃을 캡처하고, 저장 기간(retentionDays) 초과분을 자동 삭제하며, paidApp 레이아웃 리스트에서 자동 캡처본을 구분할 수 있게 isAuto 표식을 노출. 기존 dead setting(`autoSaveOnSleep`)을 실제 배선.
* plan: `cli/_doc_work/plan/auto_capture_on_sleep_plan.md`
* task: `cli/_doc_work/tasks/auto_capture_on_sleep_task.md`
* 설계 결정 (2026-06-15 브레인스토밍 폼):
    - 트리거: 시스템 슬립(`willSleepNotification`) + 화면 잠금(`com.apple.screenIsLocked`), `autoSaveOnSleep` 게이트, 5초 디바운스
    - 보관: `retentionDays` 신규 설정(기본 7, 0=무제한). auto- 레이아웃만 삭제, 수동 절대 보존
    - 표식: 이름 prefix `auto-` → `isAuto` 파생. 스키마 무변경·하위호환
    - paidApp 표식 UI는 상위 #16에 별도 이슈 등록(직접 수정 금지)
* 구현 명세:
    - 신규 `Managers/AutoCaptureCoordinator.swift` (슬립/잠금 관측 + 캡처 + 디바운스)
    - `LayoutManager`: `nextAutoCaptureName`, `cleanupExpiredAutoCaptures`
    - `AppSettings`(+Patch)·`SettingsService`·`_config.yml`: `retentionDays`
    - `Layout`/`LayoutMetadata`: `isAuto`
    - `RESTServer`: advanced 탭 `retentionDays` + 목록/캡처 응답 `isAuto`
    - `AppState`: Coordinator 기동 + 기동 시 cleanup
    - `api/openapi_v2.yaml` + `cli/_doc_arch/RestAPI_v2.md` 동기화
* 검증: Debug 빌드, 잠금 캡처, autoSaveOnSleep=false 미캡처, /layouts isAuto, retention 삭제(수동 보존)
## Issue84: [Fix] cmd+, 글로벌 단축키 제거 — showSettingsShortcut 설정·REST 필드 삭제 (등록: 2026-06-21, 완료: 2026-06-21, Hash: ff36f3d) ✅
* 목적: cliApp이 ⌘,를 Carbon 글로벌 핫키로 등록하여 시스템 전역에서 설정 창이 열리던 동작 제거. ⌘,는 macOS 표준 in-app Preferences 키이므로 글로벌 점유는 부적절.
* 상세:
    - 원인 cliApp 단독 — HotKeyService가 ⌘,를 글로벌 등록 (로그 `'showSettings' 등록 완료 (⌘,)` + `트리거 id=5` 확정). paidApp은 글로벌 핫키 메커니즘 없음(in-app `⌘,` SwiftUI만 보유) → 원인 아님
    - HotKeyService: showSettings 등록 제거 + `HotKeyAction.showSettings` enum·핸들러 삭제 → Carbon 핫키 4개(save/restoreDefault/restoreLast/showMainWindow)
    - `showSettingsShortcut`: AppSettings 필드·defaults·SettingsService 직렬화/파싱·AppState shortcuts dict·`openapi_v2.yaml` shortcuts 필드 제거
    - 상위 #16 repo 설계문서 `_doc_arch/UI.md`·`ARCHITECTURE.md` 동기화 (별도 `/git` 커밋 필요)
* 검증: Debug 재빌드(EXIT=0) + 데몬 재기동 로그 `Carbon 핫키 4개`(⌘, 없음). 잔여 `showSettings` 참조 0건
## Issue82: [Deploy] `/deploy brew publish` 자동화 — 원격 finfra/homebrew-tap 배포 (등록: 2026-06-18, 완료: 2026-06-18, Hash: 5eecb2c·6c67c1a, tap: 68545a3, release: cli-v1.0.2) ✅
* 목적: 수동으로 수행하던 원격 Homebrew tap 배포(GitHub release + Formula push)를 `cmd_publish`로 자동화. `/deploy brew publish` 단일 커맨드로 일반 사용자가 `brew install finfra/tap/fwarrange-cli` 가능하게 함.
* 구현:
    - `fwc-config.sh`: `GH_RELEASE_REPO`·`REMOTE_TAP_SLUG`·`REMOTE_TAP_URL` 추가
    - `cmd_publish` (fwc-deploy-brew.sh): 사전조건(gh auth·태그 중복 차단) → Release 빌드 → version-named tarball(`fWarrangeCli-{ver}.tar.gz`, 서명 .app) → `git tag cli-v{ver}` push → `gh release create` + asset 업로드 → **temp clone tap** Formula(release URL+sha256) 갱신·commit·push → `brew audit` 검증
    - `--dry-run` 플래그: 외부 변경 없이 빌드·tarball·clone·Formula 생성만 검증
    - 함정 해결: 로컬 tap이 `brew tap-new` 로컬생성분(remote 미설정)이라 직접 push 불가 → 원격 `git@github.com:Finfra/homebrew-tap.git` temp clone 경유 (로컬 brew tap 상태 미오염)
* 라이브 배포 결과 (1.0.2):
    - VERSION 1.0.1→1.0.2 (Issue80·81 반영), MARKETING_VERSION(pbxproj·project.yml) 동기화
    - 태그 `cli-v1.0.2` + release asset `fWarrangeCli-1.0.2.tar.gz` (sha256 `8c3e22e3…`) 업로드
    - 원격 tap Formula push → asset sha256 ↔ Formula sha256 **byte-identical 검증 통과**
    - audit clean: `version` 줄 제거(URL 스캔)·`assert_path_exists` 전환 (6c67c1a + tap 68545a3)
* 검증: 원격 formula url/sha256 일치 + release asset 다운로드 sha256 대조 일치 + Ruby Syntax OK. 외부 사용자 `brew install finfra/tap/fwarrange-cli` end-to-end 정상
* 후속 메모: pairApp(fSnippetCli #25) `fsc-deploy-brew.sh` cmd_publish 도 동일 stub → 동일 패턴 적용 가능 (별도 이슈)

## Issue80: [REST] `/api/v2/settings/{tab}` 탭별 PATCH Bool `false` 미영속화 — 동시성 lost update 재현·수정 (등록: 2026-06-15, 완료: 2026-06-15, Hash: e62208b) ✅
* 목적: Phase 4(Issue72_4) 당시 발견된 "탭별 PATCH가 Bool false를 디스크에 영속화하지 않음(전체 `/settings` PATCH는 정상)" 후보를 검증·종결
* 조사 1차 (순차 단일 PATCH — 재현 안 됨):
    - Bool 7개 필드 전부 탭별 단일 PATCH `false` → 디스크 영속화 정상 라이브 확인 (`enableParallelRestore`·`matchAreaMatchEnabled`·`autoSaveOnSleep`·`confirmBeforeDelete`·`showInCmdTab`·`clickSwitchToMain`·`launchAtLogin`)
    - `applySettingsPatch`는 `as? Bool`로 false 정상 처리, YAML round-trip(`Bool("false")` 파싱)도 정상
* 조사 2차 (동시 PATCH — **재현됨**): 서로 다른 6개 bool 필드를 **동시(concurrent) burst**로 `false` PATCH → 3개만 persist, 나머지는 default(true)로 잔존하는 **lost update** 확정. 순차 테스트만으로는 놓치는 race
* 근본 원인: **Issue78(`53f2dfe`)** 이 settingsPatch를 OperationRegistry "동시 허용"으로 풀었으나, 핸들러는 비원자적 `load()→mutate→save()`(전체 `_config.yml` 통째 쓰기)를 수행. 동시 요청이 stale state를 로드 후 마지막에 save하면 다른 요청의 `false` write가 default(true)로 clobber됨. baseline-default가 true인 필드의 false 만 손실 → "Bool false 미영속화"로 관측됨. 전체 `/settings` PATCH가 정상이던 이유 = 단일 원자 요청이라 무경합
* 수정:
    - `SettingsService` 프로토콜에 원자적 `mutate(_:)` 추가 + 프로세스 전역 `SettingsMutationLock`(NSLock)으로 `load→transform→save` 직렬화 (`SettingsService.swift`)
    - `AppState`의 설정 read-modify-write closure 전수 라우팅 — patchSettings/updateShortcuts/excludedApps 4종/defaultLayoutName/applyApiSettings/hotkey-save (`AppState.swift`)
* 검증: Debug 빌드·배포 후 6개 필드 동시 false burst x3 라운드 → 전부 false persist (lost update 0건, PASS)
* 비고: 선행 조사가 순차 단일 PATCH만 보고 "재현 불가"로 1차 판정했으나, Issue78이 도입한 동시 허용 경로를 concurrent burst로 검증하니 race 재현. 본 종결은 그 정정

## Issue79: [Docs/Plugin] API 문서 + LLM plugin(prj20) 최신화 — cliApp/brew 전환 반영 (등록: 2026-06-13, 완료: 2026-06-13) (Hash: 0b2536e, prj20 8ec2ade·4cfed60) ✅ (fSnippet #25 Issue166 미러)
* 목적: fWarrange 공개 문서·prj20 LLM plugin 이 paidApp GUI 기준으로 stale. cliApp(fWarrangeCli)/brew 운영 모델로 동기화
* 구현:
    - prj20 `f-claude-plugins/fWarrange/skills/fwarrange/SKILL.md` (8ec2ade): prereq `open -a fWarrange`+"Settings > API tab Enable" → `brew install/services start finfra/tap/fwarrange-cli`. date bump
    - prj20 SKILL.md health check 정정 (4cfed60): Step1 `GET /health` → `GET /` — 라이브 실행 중 `/health` 가 HTTP 404 반환 확인(`/` 는 200). 서버 기동 중에도 미기동 오판정하던 버그
    - `_public/api/README.md`·`README_kr.md` (0b2536e): Server "macOS Native App" → fWarrangeCli helper(Homebrew), 기본 상태 비활성→활성(localhost), OpenAPI 스펙 포인터에 v2(현행 전체 API) 추가·v1 레거시 표기
* 검증: fwarrangecli brew 서비스 기동 → REST 3016 GET / HTTP 200 (`app=fWarrangeCli, version 1.0.1, isRunning=true`). prereq GUI런치 0건, brew명 하이픈 정확
* 참고: README 본문 엔드포인트 일부 `/api/v1/*` 표기 — 전면 v1→v2 재작성은 본 이슈 범위 밖(별도 후보). 본 이슈는 운영 모델(cliApp/brew) + 스펙 포인터까지
## Issue78: [REST] 장기 동작 진행 상태 노출 (일반화) — `/operations` + `op.*` 이벤트 발행 (등록: 2026-05-18, 완료: 2026-05-18, commit: 53f2dfe) ✅
* 목적: capture 한정이 아니라 cliApp 모든 long-running 핸들러(capture, restore, layout.delete/rename, settings.patch, shortcuts.set, factoryReset)에 진행 상태 노출 채널을 제공. paidApp이 op type별 진행 메시지·완료 감지·행 대응을 통합 관리할 수 있게 함. 상위 SSOT(`~/_git/__all/fWarrange/_doc_arch/paid_cli_protocol.md` §6.7 일반화) 반영.
* 역의존 메모: prj16#Issue254 가 본 이슈에 의존 (paidApp이 사용하려면 cliApp endpoint·이벤트가 먼저 가용해야 함)
* 구현 결과:
    - 신규 actor `OperationRegistry` (`cli/fWarrangeCli/Services/OperationRegistry.swift`): UUID 발급, 직렬화 enforce(capture/restore/factoryReset), op.started/finished/failed 발행
    - 신규 enum `OpType`, struct `Operation` (`cli/fWarrangeCli/Models/`)
    - `ChangeTracker.record(...)`에 `opId: String?` 옵셔널 인자 추가, ChangeEvent 직렬화에 포함
    - `GET /api/v2/operations` 라우팅 추가 (idle 시 `{"operations":[]}`, 진행 중 시 스냅샷)
    - 대상 핸들러 모두 register/complete 경로 적용 + 직렬화 위반 시 `409 Conflict`:
        * REST: handleCapture / handleRestore / handleRenameLayout / handleDeleteLayout / handleSetShortcuts / handleFactoryReset / settings PATCH(전체+탭별)
        * HotKey: AppState.handleHotKeyAction(.save) Cmd+F7 경로도 OperationRegistry 경유
* 검증 결과 (Debug 빌드 + 로컬 실행):
    - `GET /operations` idle → `{"operations":[]}`
    - 동시 두 번 `POST /capture` → 첫 200, 둘째 `409 Conflict` (`capture가 이미 진행 중입니다`)
    - `GET /changes` 응답에 `op.started(opId) → layout.created → op.finished(opId)` 순서 확인
    - 동시 `PATCH /settings/general` + `PATCH /settings/restore` → 둘 다 200 (동시 허용 OK)

## Issue77: [Logging] cliApp 로그 파일명을 `wlog_cliApp.log`로 변경 — paidApp과 명명 대칭 (등록: 2026-05-18) (✅ 완료, 39004f7) ✅
* 목적: 현재 cliApp(fWarrangeCli) 로그가 `~/Documents/finfra/fWarrangeData/logs/wlog.log`로 출력됨. paidApp(fWarrange)도 동일 데이터 폴더 공유 시 식별 어려움 → cliApp을 `wlog_cliApp.log`로 명명 분리. fSnippet Issue132와 동일 패턴(`flog_cliApp.log`) 미러링.
* 상세:
    - 현재 경로: `~/Documents/finfra/fWarrangeData/logs/wlog.log` (실시간), `wlog_YYYY-MM-DD_HH-mm-ss.log` (세션 아카이브)
    - 변경 후: `wlog_cliApp.log` (실시간), `wlog_cliApp_YYYY-MM-DD_HH-mm-ss.log` (세션 아카이브)
    - 코드 위치:
        - `cli/fWarrangeCli/Utils/Logger.swift` L68 (logFileURL), L118 + L142 (archivedLogURL)
        - `cli/fWarrangeCli/AppState.swift` L244 (REST 응답용 경로)
        - `cli/_tool/fwc-test.sh` L25, `cli/_tool/apiTestDo.sh` L26, `cli/_tool/cmdTestDo.sh` L24 (테스트 LOG_FILE)
* 구현 명세:
    - Logger.swift L68: `"wlog.log"` → `"wlog_cliApp.log"`
    - Logger.swift L118, L142: `"wlog_\(sessionDateString).log"` → `"wlog_cliApp_\(sessionDateString).log"`
    - AppState.swift L244 + 테스트 스크립트 LOG_FILE 동기화
    - 기존 `wlog.log` grep으로 `.claude/`, `cli/`, README 전 영역 정리 (로컬 룰·스킬 문서 포함)
    - 검증: 재배포 후 `wlog_cliApp.log` 생성 + 기존 `wlog.log` 미갱신 확인
    - 옛 `wlog.log` 자동 마이그레이션 미적용 (사용자 수동 삭제)
* 관련: fSnippet Issue132 (대응 패턴), 향후 paidApp(fWarrange) 로그 폴더 Library/Logs 이관 이슈와 별개

## Issue75: PaidAppMonitor terminate 핸들러 — 잔존 인스턴스 무시하여 .cliOnly 오전환 (등록: 2026.05.17) (✅ 완료, 7b2e44b) ✅
* 목적: paidApp 다중/단명 인스턴스 발생 시 한 인스턴스 종료만으로 메뉴바가 cliApp 아이콘으로 잘못 복원되는 문제 해결
* 상세:
    - 현상: paidApp 활성 상태인데 메뉴바 아이콘이 cliApp 아이콘으로 표시됨
    - 재현 로그: `~/Documents/finfra/fWarrangeData/logs/wlog.log` 23:43:26~27 구간 — pid 61357 launch→terminate 직후 잔존 pid 60997 무시하고 `.cliOnly` 전환
    - 위치: `cli/fWarrangeCli/Managers/PaidAppMonitor.swift:53-67` `didTerminateApplicationNotification` 핸들러
* 구현 명세:
    - **파일**: `cli/fWarrangeCli/Managers/PaidAppMonitor.swift`
    - **변경 함수**: `startObserving(onTerminate:)` 내부 `didTerminateApplicationNotification` 클로저
    - **변경 로직**:
        - terminate 알림 수신 후 `Task { @MainActor }` 본문에서 `NSRunningApplication.runningApplications(withBundleIdentifier: self.paidAppBundleId).isEmpty` 잔존 체크 추가
        - 잔존 인스턴스 존재 시: state 유지 + `onTerminateCallback` 호출 금지 + 정보 로그만 기록 후 early return
        - 잔존 없을 때만: `state = .cliOnly` + 기존 로그 + `onTerminateCallback?(app)` 실행
    - **부가 정리**: `app.bundleIdentifier == "kr.finfra.fWarrange"` 하드코딩을 `self.paidAppBundleId` 상수 참조로 통일
    - **검증**: Release 빌드 `BUILD SUCCEEDED` 확인. cliApp 재기동 후 paidApp 살아있는 상태에서 paidApp 단명 인스턴스(launchPaidApp self-terminate 등) 발생 시 메뉴바 아이콘이 paidApp 활성 유지되어야 함



## Issue74: [REST] 레이아웃 복구 응답에 실패 윈도우 상세 정보 노출 (등록: 2026-05-16, 완료: 2026-05-16, commit: fc33e79) ✅
* 목적: paidApp Issue246(복구 실패 상세 보기) 선수 작업. `POST /api/v2/layouts/{name}/restore` 응답 `data`에 `failures` 배열을 추가하여 paidApp이 실패한 윈도우의 식별 정보·실패 사유를 표시할 수 있게 함.
* 선행 관계: 상위 paidApp Issue246의 **선수 이슈**
* plan: `cli/_doc_work/plan/restore_failures_response_plan.md`
* 구현 명세:
    - **Phase 1 — OpenAPI v2 스펙 확장 (`api/openapi_v2.yaml`)**:
        - `RestoreFailureItem` 스키마 신설 (app/title/layer/id/pos/size/reason)
        - `reason` enum: appNotRunning, windowNotFound, belowMinimumScore, axOperationFailed, other
        - `RestoreResponse.data.failures` 필드 추가
        - 예시 응답 2종 (allSuccess, partialFailure)
    - **Phase 2 — RESTServer 구현 (`cli/fWarrangeCli/Services/RESTServer.swift handleRestore`)**:
        - `results.filter { !$0.success }`로 실패 항목 추출
        - 각 항목에 `targetWindow`의 WindowInfo(app/title/layer/id/pos/size) 매핑
        - `classifyRestoreFailure` 정적 헬퍼: `NSWorkspace.shared.runningApplications` 기반으로 4 사유 분류
            - app 미실행 + `matchType==.noMatch` + `score==0` → `appNotRunning`
            - `matchType==.noMatch` 또는 `score==0` → `windowNotFound`
            - `score < minimumScore` → `belowMinimumScore`
            - 그 외 (점수 충분하지만 success=false) → `axOperationFailed`
        - 응답 `data.failures` 배열 직렬화하여 반환
* 검증:
    - `curl -X POST /api/v2/layouts/2026-05-16-6/restore | jq '.data.failures'`로 실패 윈도우 정보 확인 (`{app:"Finder", title:"animationTest", reason:"windowNotFound", ...}`)
    - `failures.count == failed` 카운트 일치 (27 total, 26 succeeded, 1 failed)
* 알려진 운영 메모:
    - Debug 빌드 직접 실행 시 `BrewServiceSync.onAppStart`가 `brew services start`로 위임 후 self-terminate → brew 구버전이 다시 띄워짐
    - 해결: `brew services stop fwarrange-cli` + `defaults write kr.finfra.fWarrangeCli fwc.autoStartBrewService -bool false` + DerivedData 직접 실행

## Issue73: [Bug] ChangeTracker 발행 누락 + LayoutManager SSOT 누수 — paidApp 적응형 폴링 변경 알림 결손 (등록: 2026-05-16) (✅ 완료, 0580ad8) ✅
* 목적: cliApp `ChangeTracker.record(...)` 발행 지점 누락으로 paidApp `/changes` 폴링이 일부 변경을 인지하지 못함. 또한 `LayoutManager` CRUD 메서드 자체에 `record(...)` 호출이 없어 외부 호출 경로(RESTServer 핸들러·`AppState.handleHotKeyAction`)에서만 발행 → 향후 직접 호출 추가 시 누락 위험 상시. 상위 `_doc_arch/paid_cli_protocol.md` §6 SSOT 정합화.
* 선행 관계: 상위 paidApp 레포 Issue248의 **선수 이슈** (cliApp 측 발행이 보장되어야 paidApp 측 폴링·suspend 보수화의 효과 검증 가능)
* 상세:
    - 누락된 발행 지점 (RESTServer.swift):
        - `handleRemoveWindows` (1483) — `layout.updated` 누락 → 창 일부 제거 시 paidApp 미반영
        - `handleSetDefaultLayout` (1567) — `settings.changed`(target=`defaultLayout`) 누락
        - `handleSetUIState` (1590) — 정책 결정 후 추가 검토 (선택)
    - LayoutManager SSOT 누수 — 메서드 내부에 `record` 없음:
        - `saveLayout` (79)
        - `deleteLayout` (86)
        - `deleteLayouts` (153)
        - `deleteAllLayouts` (100)
        - `renameLayout` (169)
        - `removeWindows` (107)
        - `updateWindowPositions` (117)
    - DisplaySwitchService / ScreenMoveService 일괄 좌표 갱신 시 `layout.updated` 발행 여부 미확인 (확인 후 누락 시 추가)
* 구현 명세:
    - Phase A — 누락 발행 추가 (RESTServer):
        - `handleRemoveWindows` 성공 분기 끝에 `ChangeTracker.shared.record(type: "layout.updated", target: name)`
        - `handleSetDefaultLayout` 성공 분기 끝에 `ChangeTracker.shared.record(type: "settings.changed", target: "defaultLayout")`
    - Phase B — SSOT 이관 (LayoutManager 내부 발행):
        - 각 CRUD 메서드 마지막 줄에 `ChangeTracker.shared.record(...)` 추가
        - `saveLayout` → `layout.created`/`layout.updated`(덮어쓰기 시) 판단 후 발행
        - `deleteLayouts` → 루프 내 각 name마다 `layout.deleted`
        - `renameLayout` → `layout.deleted`(oldName) + `layout.created`(newName) (SSOT §6.4 매핑 준수)
        - `removeWindows` / `updateWindowPositions` → `layout.updated`
        - RESTServer/AppState 측 중복 호출 제거 (이중 발행 방지)
    - Phase C — 폭주 방지:
        - `ChangeTracker`에 동일 (type, target) 100ms throttle 옵션 도입 (updateWindowPositions 다건 호출 시)
        - 또는 호출 측에서 단일 트랜잭션 후 1회 발행으로 묶기
    - Phase D — 디스플레이/스크린 이동:
        - `DisplaySwitchService` / `ScreenMoveService`가 LayoutManager 경유로 좌표 갱신하도록 정리되어 있는지 확인
        - 직접 storageService 호출 시 `layout.updated` 발행 추가
    - 검증:
        - `curl -X POST /api/v2/layouts/X/windows/remove` 후 `GET /api/v2/changes?since=N` 응답에 `layout.updated` 포함
        - `POST /api/v2/settings/defaultLayout` 후 `settings.changed`(target=defaultLayout) 포함
        - cliApp 메뉴바 / Cmd+F7 / REST capture 각각에서 `layout.created` 1회씩만 발행 (이중 발행 없음)
        - paidApp Issue248 검증 시나리오와 함께 end-to-end 자동 갱신 확인
* 관련:
    - 상위: paidApp 레포 Issue248 (`~/_git/__all/fWarrange/Issue.md`)
    - SSOT: `~/_git/__all/fWarrange/_doc_arch/paid_cli_protocol.md` §6 (변경 알림 프로토콜)
    - 기반: Issue27(시퀀스 API), Issue220(SSE 제거 → /changes 일원화)


## Issue72: [Feat] 창 인식률 개선 — 7-Phase 통합 작업 (등록: 2026-05-15) (✅ 완료, 2026-05-16) ✅
* 목적: "정밀 복구 실패의 원인이 ID 방식인지 윈도우명인지 이중 매칭 문제인지" 토의(이슈후보 출신)를 시발점으로, 측정 인프라부터 사용자 개입 UI까지 7개 Phase로 매칭 알고리즘을 체계적으로 개선
* plan: `cli/_doc_work/plan/window_recognize_plan.md`
* task: `cli/_doc_work/tasks/window_recognize_task.md`
* design: `cli/_doc_arch/window_recognize.md`
* report: `cli/_doc_work/report/window_recognize_issue72_report.md`
* 구현 명세:
    - 7개 서브 이슈 Issue72_1~Issue72_7 모두 처리 (cliApp 측 코드 완료)
    - 18개 커밋 (Issue72 직접 16 + checkpoint 1 + 리팩토링 1)
    - 신규 Swift 파일 4종 (RestoreStats, RestoreStatsCollector, TitleNormalizer, MatchMode)
    - 신규 REST 엔드포인트 5개 (`/restore-stats` GET·DELETE, `/normalize-rules` GET·PUT·DELETE)
    - 확장 파라미터: `POST /layouts/{name}/restore`에 `mode`, `interactive`/`dryRun`
    - WindowInfo 옵셔널 필드 6개 추가 (모두 구 yml 하위호환)
    - 신규 비공개 API: CGSMainConnectionID, CGSGetActiveSpace, CGSCopySpacesForWindows (cliApp non-sandbox)
    - apiTest/v2 신규 6개 (33~38)
    - openapi_v2.yaml + RestAPI_v2.md §4.8~§4.11 동기화
* 후속 작업:
    - Task 1.6 베이스라인 수집 (2026-05-22 후 `window_recognize_baseline.md`)
    - paidApp 다이얼로그·`/resolve` (별도 레포)
    - PWA 매칭 활용·이슈후보(tab PATCH false 버그)는 베이스라인 후 결정

## Issue72_1: [Feat] Phase 1 — 측정 인프라 (RestoreStats + REST) (등록: 2026-05-15) (✅ 완료, 02d2bd0) ✅
* 목적: 모든 후속 Phase의 효과 검증 토대 구축. 복구 매칭 결과를 누적 통계로 노출
* 구현 명세:
    - RestoreStats 모델 + JSONRestoreStatsCollector actor
    - WindowRestoreService 매칭 결과 push (recordBatch)
    - ~/Library/Application Support/fWarrangeCli/restore-stats.json 즉시 영속
    - GET/DELETE /api/v2/restore-stats
    - openapi_v2.yaml + RestAPI_v2.md §4.8
    - apiTest/v2/33, 34 신규
* 검증: 54건 누적·재시작 보존·DELETE 사이클 정상
* 후속: 1주일 베이스라인 수집 → window_recognize_baseline.md (2026-05-22)

## Issue72_2: [Feat] Phase 2 — 데이터 수집 확장 (windowOrder + displayUUID) (등록: 2026-05-15) (✅ 완료, 1899014) ✅
* 목적: 매칭 정확도 향상을 위해 캡처 시점에 추가 시그널 수집
* 구현 명세:
    - WindowInfo.windowOrder (PID별 onscreen 인덱스), displayUUID 옵셔널 필드
    - CGDisplayCreateUUIDFromDisplayID + Cocoa↔Quartz 좌표 변환 + squaredDistance fallback
    - YAML 하위호환
* 검증: 4-monitor 환경 UUID 4종 일관, 다중 창 windowOrder 순차 (Code 0~8, KakaoTalk 0~8)
* 한계: Chrome PID 분기로 windowOrder=[0,0] — Phase 6에서 다중 식별자 토대

## Issue72_3: [Feat] Phase 3 — 타이틀 정규화 룰셋 (등록: 2026-05-15) (✅ 완료, a776be1) ✅
* 목적: 동적 타이틀(브라우저·에디터·터미널·채팅)로 인한 exactTitle(90점) 매칭 실패 회복
* 구현 명세:
    - TitleNormalizer 서비스 (DispatchQueue concurrent + barrier write)
    - 빌트인 10개 룰 (Safari/Chrome/Edge/Firefox/Code/Cursor/Slack/iTerm2/Terminal/Xcode)
    - 사용자 편집본: ~/Library/Application Support/fWarrangeCli/title_normalize.yml
    - GET/PUT/DELETE /api/v2/normalize-rules
    - WindowInfo.windowRaw (정규화 전 원본 보존)
    - openapi_v2.yaml + RestAPI_v2.md §4.9
* 검증: VSCode 13창 정규화 실측 (`⚓ fWarrange — Issue.md` → `⚓ fWarrange`)

## Issue72_4: [Feat] Phase 4 — 점수 함수 개선 (distance 가산 + areaMatch 옵션) (등록: 2026-05-15) (✅ 완료, c4162f6) ✅
* 목적: 카테고리 점수 + distance 가산 + areaMatch 비활성화 옵션으로 노이즈 매칭 감소
* 구현 명세:
    - computeMatchScore에 distance 0~9점 가산 (score>0 && score<100 가드, 카테고리 경계 보존)
    - AppSettings.matchAreaMatchEnabled 옵션 + SettingsService yml 직렬화
    - /settings/restore 탭에 노출
* 검증: 빌드 통과, /settings/restore GET 노출, 56창 회귀 없음
* 후속 이슈후보: /settings/{tab} PATCH Bool false 영속화 버그 (전체 /settings PATCH는 정상)

## Issue72_5: [Feat] Phase 5 — 매칭 모드 + Moom 폴백 (strict/normal/loose) (등록: 2026-05-15) (✅ 완료, 48df335) ✅
* 목적: 사용자 "정확히"/"비슷하게" 의도 표현. loose 모드에서 Moom 스타일 최후 폴백
* 구현 명세:
    - MatchMode enum + RuntimeMatchPolicy struct (모드별 정책 빌더 팩토리)
    - strict(≥70, 기하 차단) / normal(설정값) / loose(≥30 + 1:N + Moom)
    - WindowInfo.matchMode 창 단위 override
    - Moom 폴백: 앱별 창 수 == target 수 → windowOrder 정렬 배분
    - POST /api/v2/layouts/{name}/restore에 mode 파라미터
    - openapi + RestAPI_v2.md §4.10
* 검증: 3 모드 e2e 각 57/57, MatchType 분포 ID 388 / Title(Exact) 1 / Width 1 / None 4

## Issue72_6: [Feat] Phase 6 — Spaces(spaceId) + PWA(originURL) (등록: 2026-05-15) (✅ 완료, dc0f36f) ✅
* 목적: OSS 미개척 시나리오 — Spaces 분산 창·Chrome PWA 구분 매칭 토대
* 비공개 API 도입 합의 상세 (2026-05-16, 결정사항에서 이관): CGSGetActiveSpace·CGSCopySpacesForWindows·CGSMainConnectionID 사용. App Store 영향 無 (cliApp은 brew 배포). macOS 업데이트 시 폐기 가능성 대비 nil 반환 안전망 보유. 상위 `_doc_arch/paid_cli_protocol.md` 차기 갱신 시 반영 권장.
* 구현 명세:
    - 6-1: 비공개 CGSCopySpacesForWindows + WindowInfo.spaceId + 매칭 +3점 가산
    - 6-2: Chromium 5종 화이트리스트 + ps -p {pid} -o command= → --app=URL 파싱 + WindowInfo.originURL
    - AXPrivateAPI.swift에 CGSMainConnectionID/CGSGetActiveSpace/CGSCopySpacesForWindows 바인딩
    - Issue.md 결정사항에 cliApp 비공개 API 도입 합의 기록
* 검증: 56창 spaceId=1 일관 추출, PWA 코드 빌드 통과
* 한계: Space 분산·PWA 실측 환경 후속. appMatches 다중 식별자 매칭 활용은 별도 후속

## Issue72_7: [Feat] Phase 7-1 — Interactive REST dry-run (등록: 2026-05-15) (✅ cliApp PoC 완료, 1d4246d) ✅
* 목적: 매칭 시뮬레이션(dry-run) — paidApp 후보 선택 다이얼로그 사전 조회
* 구현 명세:
    - WindowRestoreService에 dryRun: Bool 인자 추가 (3 호출부 + Moom 가드)
    - POST /api/v2/layouts/{name}/restore body의 interactive 또는 dryRun (동의어, OR)
    - 응답: success=false, matchedTitle="(dry-run) {원본}", score/matchType 정상
    - openapi + RestAPI_v2.md §4.11
    - apiTest/v2/38
* 검증: dry-run 56창(succeeded=0) vs 실제 56/56
* 후속 (별도 레포): paidApp 다이얼로그(7-2), /resolve 엔드포인트, MatchCandidate/InteractiveSession, 학습(7-3)

## Issue71: [Fix] VSCode 등 CGWindowOwnerName ↔ localizedName 불일치 앱 복구 실패 (등록: 2026-05-08) (✅ 완료, 7b41337) ✅
* 목적: VSCode·Code Helper 등 `kCGWindowOwnerName` 과 `NSRunningApplication.localizedName` 이 다른 앱이 복구되지 않는 문제를 근본 해결.
* 상세:
    - 현상: REST `/api/v2/layouts/{name}/restore` 호출 시 `[복구] 'Visual Studio Code' - 성공: 0, 대기: 10` → `[조기 종료] 남은 창의 앱이 모두 미실행 상태: Visual Studio Code` 로 1회 시도 만에 종료. VSCode가 명백히 실행 중인데도 매칭 실패.
    - 근본 원인 (실측):
        - `kCGWindowOwnerName` = `"Visual Studio Code"` (yml `app` 필드에 저장)
        - `NSRunningApplication.localizedName` = `"Code"` (복구 매칭 기준)
        - 기존 매칭 로직 `name == appName || name.hasPrefix(appName) || appName.hasPrefix(name)` 가 `"Code"` ↔ `"Visual Studio Code"` 양방향 prefix 모두 false → 매칭 0건
    - 영향 범위: bundleURL 표시명과 localizedName 이 다른 모든 앱 (이름 기반 매칭의 구조적 한계)
* 구현 명세 (해결 방식 — 단순 매칭 강화가 아닌 식별자 자체를 안정화):
    - WindowInfo 모델에 `bundleId: String?` 옵셔널 필드 추가 (CFBundleIdentifier — OS·언어·표시명 변경 무관)
    - WindowCaptureService: `kCGWindowOwnerPID` → NSRunningApplication.bundleIdentifier 매핑 후 저장
    - LayoutStorageService: YAML 직렬화·파싱에 `bundleId:` 라인 추가 (구 yml 호환 — 없으면 nil)
    - WindowRestoreService 매칭 헬퍼 `appMatches(_:targetApp:targetBundleId:)`:
        - 1순위: bundleIdentifier 정확 일치
        - 2순위: 다중 이름 후보(localizedName, bundleURL `.app` 제거 형식, executableURL) 정확/양방향 prefix
        - 3개소(병렬 경로·순차 경로·조기 종료 체크) 헬퍼 호출 통일
    - RESTServer.windowInfoToDict: bundleId 응답 포함 (옵셔널)
    - OpenAPI v2 WindowInfo 스키마 동기화
* 검증:
    - 신 yml(bundleId 포함) 47/47 복구 성공 (VSCode 10/10 포함)
    - 구 yml(2026-05-08-3, bundleId 없음) VSCode 10/10 — 이름 기반 fallback 정상 동작
    - REST `/capture` 응답에 `bundleId='com.microsoft.VSCode'`, `'com.apple.dt.Xcode'` 노출 확인
    - Release 빌드·brew local 재배포·헬스체크 OK

## Issue70: [Feat] cliApp 메뉴바 종료 항목 단축키 표시 정비 + 다국어 지원 (등록: 2026-05-04) (✅ 완료, c47bbcd) ✅
* 목적: cliApp 메뉴바의 종료 항목 단축키 표시를 종료 정책(`paid_cli_protocol.md` §3.3)과 일치시키고, 메뉴 항목 다국어 지원을 추가. paidApp Cmd+Q는 paidApp 단독 종료에만 표시되어야 하며, cliApp Quit All에는 단축키 미부여(오발화 방지).
* 상세:
    - 배경:
        - paidApp Issue239(Cmd+Q로 cliApp 동반 종료) 취소 — 정책: Cmd+Q는 paidApp 단독 종료, 메뉴바 Quit All은 cliApp 메뉴 단일 진입점
        - 현재 `cli/_doc_arch/menuBar_enhance.md`의 메뉴 구조에서 `Quit ⌘Q` 표기가 단일 항목에 부여되어 있어 정책과 불일치
        - 메뉴 항목 텍스트가 영어 하드코딩으로 추정 — 다국어 미지원
    - 관련 파일:
        - `cli/fWarrangeCli/Managers/MenuBarManager.swift` (NSMenu 구성)
        - `cli/_doc_arch/menuBar_enhance.md` (SSOT 메뉴 구조 — 본 이슈에서 수정)
        - `cli/fWarrangeCli/*.lproj/Localizable.strings` 또는 `.xcstrings` (다국어 리소스)
* 구현 명세:
    - 1단계 — `cli/_doc_arch/menuBar_enhance.md` 수정:
        - "Quit ⌘Q" 단일 항목을 정책 기반 2~1항목 구조로 분리:
            - paidApp 활성(`paidAppStatus = started`): `Quit fWarrange ⌘Q` + `Quit All` (단축키 없음)
            - paidApp 비활성(`stopped`/`notInstall`): `Quit fWarrangeCli` (cliApp 단독, 단축키 없음)
        - 단축키 표시 규칙: ⌘Q는 **paidApp 활성 시 paidApp 단독 종료 항목에만** 표시
        - 메뉴 텍스트는 다국어 키 참조 형식: `menu.quit.fwarrange`, `menu.quit.all`, `menu.quit.fwarrangecli`
    - 2단계 — `MenuBarManager.swift` 구현:
        - paidApp 상태 분기로 종료 항목 구성
        - paidApp 활성: `Quit fWarrange`(⌘Q, paidApp 단독) + `Quit All`(단축키 없음, 통합 종료)
        - paidApp 비활성: `Quit fWarrangeCli` 단일 항목, 단축키 없음
        - paidApp 단독 종료 액션: `PaidAppLauncher.terminate()` 호출 (cliApp은 잔존)
        - Quit All 액션: 기존 `quitApp()` 시퀀스 (Issue68/Issue236 — 3단 폴백)
    - 3단계 — 다국어 리소스 추가:
        - 신규 키: `menu.quit.fwarrange`, `menu.quit.all`, `menu.quit.fwarrangecli`
        - 지원 언어 매트릭스는 `localization/` 기존 정책 따름 (en/ko 최소 + 기타 기존 지원 언어 동기화)
        - About 항목 등 기존 다국어 미적용 메뉴 항목도 동시 정비 (선택적, 발견 시)
    - 4단계 — 검증:
        - paidApp 활성 시 메뉴 열기: `Quit fWarrange ⌘Q` + `Quit fWarrangeCli`(단축키 없음) 노출 확인
        - paidApp 비활성 시 메뉴 열기: `Quit fWarrangeCli` 단일 항목, 단축키 없음 확인
        - paidApp 단독 종료 후 cliApp 잔존(`pgrep fWarrangeCli`) 확인
        - Quit All 시 paidApp + cliApp 모두 종료 확인
        - 시스템 언어 변경 시 메뉴 텍스트 즉시 반영 확인 (en/ko)

## Issue69: [Feat] 메뉴바 paidApp 연동 일관성 — About 분기 + Open Main Window URL Scheme (등록: 2026-05-03) (✅ 완료, 1a375a1) ✅
* 목적: paidApp 동작 상태에 따라 메뉴 표기·동작이 자연스러워지도록 정비함. 두 증상은 같은 패턴(paidApp 활성 시 paidApp을 우선시해야 함)이라 묶어 처리.
    1. About 메뉴: paidApp 동작 중일 때 "About fWarrangeCli"가 아니라 "About fWarrange"가 표시되어야 하고, About 창 내용도 paidApp 정보로 바뀌어야 함.
    2. "Open Main Window" 메뉴: 클릭 시 paidApp이 활성화는 되지만 메인 창이 열리지 않음. 핫키 경로는 URL Scheme(`fwarrange://command?action=main`)을 쓰는데 메뉴 경로는 `NSWorkspace.shared.open(url)`만 호출해서 LSUIElement 모드 paidApp의 메인 창을 띄우지 못함.
* 상세:
    - About 메뉴 타이틀은 paidApp 미동작 시 "About fWarrangeCli", 동작 중 시 "About fWarrange" (en/ko/ja 동시 적용)
    - About 창: paidApp 모드 시 paidApp 번들 아이콘·이름·버전 표시, App Store 링크 추가
    - Open Main Window 메뉴 액션을 `state.openPaidApp(action: "main")`(URL Scheme)으로 변경, `openSettings()`와 일관 패턴
* 구현 명세:
    - `cli/fWarrangeCli/Utils/LocalizedStringManager.swift`: `menu.about.cli`, `menu.about.paid` 키 추가 (en/ko/ja). 기존 `menu.about`는 호환용으로 유지 또는 제거.
    - `cli/fWarrangeCli/Managers/MenuBarManager.swift`:
        + `buildMenuItems`에서 `appState?.paidAppMonitor.state == .paidAppActive` 여부에 따라 About 메뉴 타이틀 분기
        + `openMainWindow()`에서 `_ = state.launchPaidApp()` → `state.openPaidApp(action: "main")` 변경
    - `cli/fWarrangeCli/Managers/AboutWindowManager.swift`:
        + `showAbout(isPaidActive: Bool)` 시그니처로 변경 (호출 측에서 paidApp 상태 전달)
        + `AboutView`를 `isPaidActive` 분기로 두 가지 컨텐츠 렌더링
        + paidApp 모드: 타이틀 "About fWarrange", paidApp 번들 아이콘/이름/버전 표시 (NSRunningApplication.bundleURL 또는 PaidAppLauncher.detect()), App Store 링크 추가 (`macappstore://apps.apple.com/app/fwarrange/id6744105753`)
    - 검증: paidApp 미실행 / 실행 두 상태 모두 메뉴 타이틀·About 창 내용·Open Main Window 동작 확인. Release 빌드 통과.

## Issue68: [Refactor] 메뉴바 Quit → paidApp 통합 종료 (Quit All) (등록: 2026-05-03) (✅ 완료, 251036a) ✅
* 목적: cliApp 메뉴바 Quit 클릭 시 cliApp만 종료되고 paidApp(`fWarrange`)이 잔존하는 현상(2026-05-03 재현 확인). paidApp 측 Cmd+Q는 정상 동작하므로 본 이슈는 **cliApp 측 작업**임. paidApp 레포 Issue232에서 paidApp `MenuBarExtra` 제거 후 cliApp 메뉴바가 유일한 paidApp 종료 트리거가 되어야 하나 미연결 상태.
* 상세:
    - 현상: cliApp 메뉴바 → Quit → cliApp 프로세스만 종료, paidApp(`/Applications/_nowage_app/fWarrange.app`) 프로세스는 좀비처럼 잔존
    - 관련 SSOT: 상위 paidApp 레포 `_doc_arch/paid_cli_protocol.md` §3.3 "Quit All 시퀀스" — cliApp 트리거 흐름 미반영
    - 관련: paidApp 레포 Issue232 (paidApp 메뉴바 제거, 2026-05-03 완료)
* 구현 명세:
    - `MenuBarManager.swift` 또는 `MenuBarView.swift` Quit 액션 핸들러에서 paidApp 종료 신호 발송
    - 옵션 A: paidApp URL Scheme `fwarrange://command?action=quit` open
    - 옵션 B: paidApp pid 검색 후 `kill -TERM`
    - 옵션 C: REST `/api/v2/paidapp/quit` 신규 엔드포인트 추가 후 paidApp이 self-terminate
    - 옵션 결정 후 paidApp 레포 SSOT `_doc_arch/paid_cli_protocol.md` §3.3 갱신 필요 (양 레포 동기 PR)
    - 검증: cliApp 메뉴바 Quit → paidApp + cliApp 모두 종료, ps에서 잔존 0개 확인


> 종결된 이슈는 [`z_old/old_issue.md`](z_old/old_issue.md)로 이관됨.

# ⏸️ 보류

# 🚫 취소

> 종결된 이슈는 [`z_old/old_issue.md`](z_old/old_issue.md)로 이관됨.

# 📜 참고
