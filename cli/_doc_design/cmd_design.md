---
name: cmd_design
description: cliApp CLI 커맨드 인터페이스 설계
date: 2026-04-27
---

# 배경

현재 cliApp은 메뉴바 GUI 앱 + REST API로만 동작하며, 터미널에서 직접 명령을 실행할 수 없음. `fWarrangeCli --help`, `fWarrangeCli capture` 등의 CLI 커맨드를 추가하여 쉘 스크립트 및 자동화 연동을 지원함.

# 설계 원칙

* CLI 인자가 있으면 해당 커맨드 실행 후 종료 (exit)
* CLI 인자가 없으면 기존 메뉴바 앱으로 동작 (GUI 모드)
* REST API와 1:1 대응 — CLI는 내부적으로 localhost REST API를 호출
* 출력 포맷: 기본 JSON, `--pretty` 시 jq 스타일 정렬

# 실행 모드

```
fWarrangeCli                  → GUI 모드 (메뉴바 앱, 기존 동작)
fWarrangeCli <command> [args] → CLI 모드 (실행 후 종료)
```

# 커맨드 목록

## 정보 (Info)

| 커맨드              | 설명                   | 대응 API              |
| :------------------ | :--------------------- | :-------------------- |
| `--help`, `-h`      | 도움말 출력            | -                     |
| `--version`, `-v`   | 버전 정보              | GET /cli/version      |
| `status`            | 데몬 상태 조회         | GET /cli/status       |
| `health`            | 헬스 체크              | GET /                 |
| `settings`          | 앱 설정 조회           | GET /settings         |

## 레이아웃 (Layout)

| 커맨드                              | 설명               | 대응 API                            |
| :---------------------------------- | :----------------- | :---------------------------------- |
| `list`                              | 레이아웃 목록      | GET /layouts                        |
| `show <name>`                       | 레이아웃 상세      | GET /layouts/{name}                 |
| `capture [name]`                    | 창 캡처 저장       | POST /capture                       |
| `restore <name>`                    | 레이아웃 복구      | POST /layouts/{name}/restore        |
| `rename <old> <new>`                | 이름 변경          | PUT /layouts/{name}                 |
| `delete <name>`                     | 레이아웃 삭제      | DELETE /layouts/{name}              |
| `delete-all --confirm`              | 전체 삭제          | DELETE /layouts                     |
| `remove-windows <name> <id> [...]`  | 특정 창 제거       | POST /layouts/{name}/windows/remove |

## 창 정보 (Window)

| 커맨드                       | 설명                 | 대응 API                  |
| :--------------------------- | :------------------- | :------------------------ |
| `windows [--filter <apps>]`  | 현재 창 목록         | GET /windows/current      |
| `apps`                       | 실행 중 앱 목록      | GET /windows/apps         |

## 시스템 (System)

| 커맨드           | 설명                 | 대응 API                    |
| :--------------- | :------------------- | :-------------------------- |
| `accessibility`  | Accessibility 권한   | GET /status/accessibility   |
| `quit --confirm` | 데몬 종료            | POST /cli/quit              |

# 공통 옵션

| 옵션               | 설명                          | 기본값              |
| :----------------- | :---------------------------- | :------------------ |
| `--port <port>`    | REST API 포트                 | 3016                |
| `--host <host>`    | REST API 호스트               | localhost           |
| `--pretty`         | JSON 출력 정렬                | false               |
| `--quiet`, `-q`    | 출력 최소화 (exit code만)     | false               |

# 구현 전략

## Phase 1: ProcessInfo 기반 (권장)

```swift
// fWarrangeCliApp.swift init()에서 처리
let args = ProcessInfo.processInfo.arguments
if args.count > 1 {
    CLIHandler.handle(args: Array(args.dropFirst()))
    exit(0)
}
// else: 기존 GUI 모드
```

## Phase 2: CLIHandler 구조

```swift
struct CLIHandler {
    static let baseURL = "http://localhost:\(port)/api/v2"

    static func handle(args: [String]) {
        switch args.first {
        case "--help", "-h":    printHelp()
        case "--version", "-v": fetchAndPrint("/cli/version")
        case "status":          fetchAndPrint("/cli/status")
        case "health":          fetchAndPrint("/")
        case "settings":        fetchAndPrint("/settings")
        case "list":            fetchAndPrint("/layouts")
        case "show":            fetchAndPrint("/layouts/\(args[safe: 1])")
        case "capture":         postAndPrint("/capture", body: ["name": args[safe: 1] ?? "default"])
        case "restore":         postAndPrint("/layouts/\(args[safe: 1])/restore")
        // ...
        default:                printHelp(); exit(1)
        }
    }
}
```

## Phase 3: 별도 실행 파일 (향후)

fWarrangeCli.app 바이너리를 직접 호출하는 대신, 경량 CLI wrapper를 별도로 제공할 수 있음:

```bash
# Homebrew 설치 시 bin에 symlink
/opt/homebrew/bin/fwarrange → CLIHandler (curl 래퍼 또는 Swift CLI)
```

# 출력 예시

```bash
$ fWarrangeCli --help
fWarrangeCli - Window arrangement helper daemon

Usage: fWarrangeCli [command] [options]

Commands:
  status              Show daemon status
  health              Health check
  settings            Show app settings
  list                List layouts
  show <name>         Show layout detail
  capture [name]      Capture and save current windows
  restore <name>      Restore layout
  rename <old> <new>  Rename layout
  delete <name>       Delete layout
  windows             List current windows
  apps                List running apps
  accessibility       Check accessibility permission
  quit --confirm      Quit daemon

Options:
  -h, --help          Show this help
  -v, --version       Show version
  --port <port>       API port (default: 3016)
  --pretty            Pretty-print JSON output
  -q, --quiet         Minimal output

$ fWarrangeCli list
[{"name":"work","windowCount":12,"fileDate":"2026-04-08T10:30:00Z"},...]

$ fWarrangeCli capture my-layout
{"status":"success","name":"my-layout","windowCount":15}

$ fWarrangeCli status
{"status":"running","uptime_seconds":3600,"version":"1.0.0","port":3016}
```

# 에러 처리

| 상황                    | exit code | 출력                                    |
| :---------------------- | :-------: | :-------------------------------------- |
| 성공                    | 0         | JSON 응답                               |
| 데몬 미실행             | 1         | `Error: fWarrangeCli is not running`    |
| 잘못된 커맨드           | 1         | `Error: Unknown command` + help         |
| 필수 인자 누락          | 1         | `Error: <name> required`                |
| API 에러 (4xx/5xx)      | 1         | API 에러 JSON 그대로 출력               |

# 의존성

* 없음 — `URLSession`으로 localhost HTTP 호출만 사용
* ArgumentParser 등 외부 라이브러리 불필요
