---
name: cmdTest_plan_v1
description: fWarrangeCli CLI v1 커맨드 테스트 계획 (cmd_design.md 기반)
date: 2026-04-13
---

# 개요

`cli/_doc_design/cmd_design.md` 기반 CLI **v1** 커맨드 테스트 스크립트 매핑.
v2 커맨드는 [cmdTest_plan_v2.md](cmdTest_plan_v2.md) 참조.

* 파일명 규칙: `{00-99}.{내역}.sh`
* 스크립트 위치: `cli/_tool/cmdTest/v1/`
* 실행 대상: `fWarrangeCli` 바이너리 (Homebrew 설치 또는 빌드 결과물)
* 전제 조건: fWarrangeCli 데몬이 실행 중이어야 함 (CLI는 REST API 호출)

# 실행 방법

```bash
# v1 전체 (하위 호환 기본값)
source cli/_tool/cmdTestDo.sh
source cli/_tool/cmdTestDo.sh v1

# 특정 번호만 실행
source cli/_tool/cmdTestDo.sh v1 0      # v1/00.help

# 에러 테스트
source cli/_tool/cmdTestDo.sh v1 E      # v1 에러 전체
source cli/_tool/cmdTestDo.sh v1 E01    # v1/E01만
```

# 바이너리 경로

```bash
# Homebrew 설치 시
CLI="/opt/homebrew/opt/fwarrange-cli/fWarrangeCli.app/Contents/MacOS/fWarrangeCli"

# 로컬 빌드 시
CLI="/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli"

# 또는 DerivedData에서 직접
CLI=$(cd cli && xcodebuild -scheme fWarrangeCli -configuration Release -showBuildSettings 2>/dev/null | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)/fWarrangeCli.app/Contents/MacOS/fWarrangeCli
```

# 스크립트 목록

## 정보 커맨드

| 번호 | 파일명             | 커맨드                     | 기대 결과                    |
| ---: | :----------------- | :------------------------- | :--------------------------- |
|   00 | `00.help.sh`       | `fWarrangeCli --help`      | 도움말 텍스트 출력           |
|   01 | `01.version.sh`    | `fWarrangeCli --version`   | 버전 JSON                    |
|   02 | `02.status.sh`     | `fWarrangeCli status`      | 데몬 상태 JSON               |
|   03 | `03.health.sh`     | `fWarrangeCli health`      | 헬스 체크 JSON               |
|   04 | `04.settings.sh`   | `fWarrangeCli settings`    | 앱 설정 JSON                 |

## 레이아웃 커맨드

| 번호 | 파일명                      | 커맨드                                           | 기대 결과          |
| ---: | :-------------------------- | :----------------------------------------------- | :----------------- |
|   05 | `05.capture.sh`             | `fWarrangeCli capture testCmd`                   | 캡처 성공 JSON     |
|   06 | `06.list.sh`                | `fWarrangeCli list`                              | 레이아웃 목록 JSON |
|   07 | `07.show.sh`                | `fWarrangeCli show testCmd`                      | 레이아웃 상세 JSON |
|   08 | `08.rename.sh`              | `fWarrangeCli rename testCmd testCmdRenamed`     | 이름 변경 JSON     |
|   09 | `09.delete.sh`              | `fWarrangeCli delete testCmdRenamed`             | 삭제 성공 JSON     |
|   10 | `10.restore.sh`             | `fWarrangeCli restore testCmd`                   | 복구 결과 JSON     |
|   11 | `11.remove-windows.sh`      | `fWarrangeCli remove-windows testCmd 1234`       | 창 제거 JSON       |
|   12 | `12.delete-all.sh`          | `fWarrangeCli delete-all --confirm`              | 전체 삭제 JSON     |

## 창 정보 커맨드

| 번호 | 파일명             | 커맨드                                  | 기대 결과          |
| ---: | :----------------- | :-------------------------------------- | :----------------- |
|   13 | `13.windows.sh`    | `fWarrangeCli windows`                  | 현재 창 목록 JSON  |
|   14 | `14.windows-filter.sh` | `fWarrangeCli windows --filter Safari` | 필터된 창 목록    |
|   15 | `15.apps.sh`       | `fWarrangeCli apps`                     | 실행 중 앱 JSON    |

## 시스템 커맨드

| 번호 | 파일명                  | 커맨드                              | 기대 결과         |
| ---: | :---------------------- | :---------------------------------- | :---------------- |
|   16 | `16.accessibility.sh`   | `fWarrangeCli accessibility`        | 권한 상태 JSON    |
|   17 | `17.quit.sh`            | `fWarrangeCli quit --confirm`       | 데몬 종료 (최후)  |

# 스크립트 상세

## 0. help

```bash
$CLI --help
# 기대: Usage 텍스트, exit code 0
```

## 1. version

```bash
$CLI --version
# 기대: {"version":"x.x.x",...}
```

## 2. status

```bash
$CLI status
# 기대: {"status":"running","uptime_seconds":...}
```

## 3. health

```bash
$CLI health
# 기대: {"status":"ok","layout_count":...}
```

## 4. settings

```bash

$CLI settings

# 기대: {"settings":{...},"dataPath":"..."}
```

## 5. capture

```bash
$CLI capture testCmd
$CLI capture 
# 기대: {"status":"success","name":"testCmd","windowCount":...}
```

## 6. list

```bash
$CLI list

# 기대: [{"name":"testCmd",...},...]
```

## 7. show

```bash
$CLI show testCmd

# 기대: {"name":"testCmd","windows":[...]}
```

## 8. rename

```bash
$CLI rename testCmd testCmdRenamed
# 기대: {"status":"success","oldName":"testCmd","newName":"testCmdRenamed"}
```

## 9. delete

```bash
$CLI delete testCmdRenamed
# 기대: {"status":"success","name":"testCmdRenamed"}
```

## 10. restore

```bash
# 사전 조건: default 레이아웃이 존재해야 함
$CLI restore          # 파라미터 없으면 'default' 레이아웃으로 복구
$CLI restore testCmd  # 또는 특정 레이아웃명 지정
# 기대: {"status":"success","restored":...,"failed":...}
```

## 11. remove-windows

```bash
$CLI remove-windows testCmd 1234
# 기대: {"status":"success",...} 또는 해당 ID 없으면 에러
```

## 12. delete-all

```bash
$CLI delete-all --confirm
# 기대: {"status":"success","deletedCount":...}
```

## 13. windows

```bash
$CLI windows

# 기대: [{"app":"Safari","window":"...","pos":{...},...},...]
```

## 14. windows-filter

```bash
$CLI windows --filter Safari
# 기대: Safari 창만 포함된 배열
```

## 15. apps

```bash
$CLI apps
# 기대: ["Safari","Finder","iTerm2",...]
```

## 16. accessibility

```bash
$CLI accessibility
# 기대: {"granted":true} 또는 {"granted":false}
```

## 17. quit

```bash
$CLI quit --confirm
# 기대: 데몬 종료, exit code 0
```

# 에러 테스트 (E prefix)

에러가 **나야만 정상**인 테스트. CLI 에러 핸들링 검증용.

| 번호 | 파일명                        | 커맨드                            | 기대 결과                |
| :--- | :---------------------------- | :-------------------------------- | :----------------------- |
| E01  | `E01.unknown-command.sh`      | `fWarrangeCli foobar`             | Error + help, exit 1     |
| E02  | `E02.show-missing-name.sh`    | `fWarrangeCli show`               | Error: name required     |
| E03  | `E03.show-404.sh`             | `fWarrangeCli show nonexistent`   | 404 에러 JSON            |
| E04  | `E04.delete-no-name.sh`       | `fWarrangeCli delete`             | Error: name required     |
| E05  | `E05.delete-all-no-confirm.sh`| `fWarrangeCli delete-all`         | Error: --confirm 필수    |
| E06  | `E06.quit-no-confirm.sh`      | `fWarrangeCli quit`               | Error: --confirm 필수    |
| E07  | `E07.daemon-not-running.sh`   | (데몬 중지 후) `fWarrangeCli status` | Error: not running    |

# 실행 순서 권장

* **안전한 읽기 전용**: 0, 1, 2, 3, 4, 6, 13, 14, 15, 16
* **상태 변경 (주의)**: 5, 7, 8, 10, 11
* **삭제 (위험)**: 9, 12
* **앱 종료 (최후)**: 17

# API 전용 엔드포인트 (v1 CLI 미대응)

| 엔드포인트       | Method | 사유                                      |
| :--------------- | :----- | :---------------------------------------- |
| `PUT /ui/state`  | PUT    | GUI 자동화 전용 — CLI 커맨드로 노출 불필요 |

# 파일 구조

```
cli/_tool/cmdTest/v1/
├── 00.help.sh ~ 17.quit.sh
└── E01.unknown-command.sh ~ E07.daemon-not-running.sh
```
