# Claude Code Skill 사용법

fWarrange는 Claude Code의 Skill(스킬) 시스템과 연동되어, AI 에이전트에서 자연어로 윈도우 레이아웃을 관리할 수 있습니다.

## 개요

Claude Code Skill은 `/fwarrange:fwarrange` 슬래시 커맨드를 통해 fWarrange REST API를 호출합니다. 사용자는 터미널에서 curl 명령어를 직접 입력할 필요 없이, 자연어 기반으로 레이아웃을 캡처하고 복원할 수 있습니다.

## 전제 조건

1. **fWarrange 앱 실행 중** (REST API 서버 활성화 상태)
2. **Claude Code** 설치 및 실행
3. **fwarrange Skill** 설치 완료

## 설치 방법

### 방법 1: Claude Code Plugin 설치 (권장)

```bash
claude plugin install --from https://github.com/nowage/fWarrange --path _public/agents/claude
```

설치 후 `.claude-plugin/plugin.json`이 참조되어 Skill이 자동 등록됩니다.

### 방법 2: 수동 복사

Skill 파일을 프로젝트의 `.claude/commands/skills/` 디렉토리에 복사합니다:

```bash
# fWarrange 리포지토리에서
cp _public/agents/claude/skills/fwarrange/SKILL.md \
   <YOUR_PROJECT>/.claude/commands/skills/fwarrange.md
```

### 방법 3: 글로벌 설치

모든 프로젝트에서 사용하려면 글로벌 커맨드 디렉토리에 복사합니다:

```bash
cp _public/agents/claude/skills/fwarrange/SKILL.md \
   ~/.claude/commands/fwarrange.md
```

## 사용 예제

### 레이아웃 캡처

```
/fwarrange:fwarrange capture
/fwarrange:fwarrange capture --name=coding-setup
```

Claude가 현재 화면의 모든 창 배치를 저장합니다.

### 레이아웃 복원

```
/fwarrange:fwarrange restore my-workspace
```

저장된 레이아웃으로 창 배치를 되돌립니다.

### 레이아웃 목록 조회

```
/fwarrange:fwarrange list
```

저장된 모든 레이아웃의 이름, 창 수, 날짜를 표시합니다.

### 권한 상태 확인

```
/fwarrange:fwarrange status
```

손쉬운 사용(Accessibility) 권한 상태를 확인합니다.

### 현재 창 목록

```
/fwarrange:fwarrange windows
```

현재 열려 있는 모든 창의 정보를 표시합니다.

### 실행 중 앱 목록

```
/fwarrange:fwarrange apps
```

현재 실행 중인 GUI 앱 목록을 표시합니다.

## 동작 흐름

```
사용자: /fwarrange:fwarrange capture --name=dev
         |
Claude Code: 서버 상태 확인 (GET /)
         |
         +-- 서버 미응답 시 --> "fWarrange 앱을 실행해주세요" 안내
         |
         +-- 서버 정상 시 --> POST /api/v1/capture 호출
         |
         +-- 결과 보고: "dev 레이아웃으로 12개 창 저장 완료"
```

## 서버 미실행 시 동작

서버가 응답하지 않으면 Claude는 다음과 같이 안내합니다:

> "fWarrange REST API 서버가 실행 중이 아닙니다. 다음 명령으로 앱을 실행해주세요:"
> ```bash
> open -a "fWarrange"
> ```
> "준비되면 알려주세요."

Claude는 자동으로 서버를 시작하지 **않습니다**. 사용자 확인 후 작업을 계속합니다.

## Skill API 레퍼런스

Skill 내부에서 호출하는 REST API 엔드포인트:

| 커맨드 | API 호출 |
|--------|----------|
| `capture` | POST `/api/v1/capture` |
| `restore <name>` | POST `/api/v1/layouts/{name}/restore` |
| `list` | GET `/api/v1/layouts` |
| `status` | GET `/api/v1/status/accessibility` |
| `windows` | GET `/api/v1/windows/current` |
| `apps` | GET `/api/v1/windows/apps` |

## 옵션

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `--name=<이름>` | 캡처/복원할 레이아웃 이름 | 자동 생성 |
| `--server=<URL>` | 서버 주소 변경 | `http://localhost:3016` |

## 트러블슈팅

| 문제 | 해결 |
|------|------|
| "서버가 응답하지 않습니다" | fWarrange 앱 실행 및 API 서버 활성화 확인 |
| Skill을 찾을 수 없음 | 설치 경로 확인 (`~/.claude/commands/` 또는 프로젝트 `.claude/`) |
| 복원 실패 | 손쉬운 사용 권한 확인 (`/fwarrange:fwarrange status`) |

## 다음 단계

- [MCP 서버 사용법](08_MCP_Usage.md)
- [FAQ](09_FAQ.md)
