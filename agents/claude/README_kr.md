# fWarrange Claude Code Plugin

fWarrange REST API를 통해 macOS 창 레이아웃을 저장하고 복구하는 Claude Code 플러그인입니다.
설치 후 Claude Code에서 슬래시 커맨드로 창 레이아웃을 즉시 관리할 수 있습니다.

---

## 플러그인 구조

```
.claude-plugin/
└── plugin.json              # 플러그인 매니페스트
skills/
└── fwarrange/
    └── SKILL.md             # 창 레이아웃 관리 스킬
```

---

## 스킬

### `fwarrange` — 창 레이아웃 관리

fWarrange REST API를 통해 macOS 창의 위치와 크기를 저장하고 복구합니다.

**사용 예시:**
```
/fwarrange:fwarrange capture
/fwarrange:fwarrange capture --name=coding-setup
/fwarrange:fwarrange restore my-workspace
/fwarrange:fwarrange list
/fwarrange:fwarrange detail my-workspace
/fwarrange:fwarrange rename old-name new-name
/fwarrange:fwarrange delete my-workspace
/fwarrange:fwarrange delete-all
/fwarrange:fwarrange remove-windows my-workspace 14205 5032
/fwarrange:fwarrange windows
/fwarrange:fwarrange apps
/fwarrange:fwarrange status
/fwarrange:fwarrange locale
/fwarrange:fwarrange locale --set=en
```

**주요 기능:**
- 서버 미실행 시 fWarrange.app 실행 안내
- 현재 창 레이아웃 캡처 (이름 지정 및 앱 필터링 가능)
- 커스텀 재시도 설정으로 저장된 레이아웃 복구
- 메타데이터 포함 전체 레이아웃 목록 조회
- 레이아웃 상세 정보 조회 (창 위치, 크기)
- 레이아웃 이름 변경 및 삭제
- 전체 레이아웃 삭제 (안전 확인 헤더 필요)
- 레이아웃에서 특정 창 ID로 제거
- 현재 창 및 실행 중인 앱 조회
- 접근성 권한 상태 확인
- 앱 언어(locale) 조회 및 변경

**옵션:**

| 옵션                | 설명            | 기본값                  |
| ------------------- | --------------- | ----------------------- |
| `--name=<이름>`     | 레이아웃 이름   | 자동 생성               |
| `--server=<주소>`   | 서버 주소 변경  | `http://localhost:3016` |
| `--set=<코드>`      | 언어 코드 설정  | -                       |

**API 요약 (14개 엔드포인트):**

| 메서드 | 엔드포인트                                | 설명                     |
| ------ | ----------------------------------------- | ------------------------ |
| GET    | `/`                                       | 서버 상태 확인           |
| GET    | `/api/v1/layouts`                         | 레이아웃 목록 조회       |
| DELETE | `/api/v1/layouts`                         | 전체 레이아웃 삭제 (*)   |
| GET    | `/api/v1/layouts/{name}`                  | 레이아웃 상세 조회       |
| PUT    | `/api/v1/layouts/{name}`                  | 레이아웃 이름 변경       |
| DELETE | `/api/v1/layouts/{name}`                  | 레이아웃 삭제            |
| POST   | `/api/v1/capture`                         | 현재 레이아웃 캡처       |
| POST   | `/api/v1/layouts/{name}/restore`          | 레이아웃 복구            |
| POST   | `/api/v1/layouts/{name}/windows/remove`   | 특정 창 제거             |
| GET    | `/api/v1/windows/current`                 | 현재 창 목록             |
| GET    | `/api/v1/windows/apps`                    | 실행 중인 앱 목록        |
| GET    | `/api/v1/status/accessibility`            | 접근성 권한 확인         |
| GET    | `/api/v1/locale`                          | 언어 설정 조회           |
| PUT    | `/api/v1/locale`                          | 언어 설정 변경           |

(*) `X-Confirm-Delete-All: true` 헤더 필요.

---

## 설치 방법

### 방법 1: Plugin 설치 (권장)

```bash
/plugin marketplace add nowage/fWarrange
/plugin install fwarrange
```

### 방법 2: 수동 복사

플러그인 디렉토리를 프로젝트에 복사합니다:

```bash
# fWarrange 프로젝트 루트에서 실행
cp -r _public/agents/claude/.claude-plugin .claude-plugin
cp -r _public/agents/claude/skills .claude/skills
```

### 방법 3: 심볼릭 링크

```bash
ln -sf _public/agents/claude/skills/fwarrange .claude/skills/fwarrange
```

---

## 전제 조건

fWarrange REST API 서버가 실행 중이어야 합니다:

| 서버              | 실행 방법                                      |
| ----------------- | ---------------------------------------------- |
| macOS 네이티브 앱 | fWarrange.app 실행 (REST API는 기본 비활성. 설정 > API 탭에서 활성화) |

> 서버가 꺼져 있으면 스킬이 사용자에게 fWarrange.app 실행을 안내합니다.

**macOS 접근성 권한**이 창 복구 기능에 필요합니다:
- 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 > fWarrange.app 추가

---

## 함께 사용하면 좋은 확장

| 확장                       | 위치           | 설명                                              |
| -------------------------- | -------------- | ------------------------------------------------- |
| [MCP Server](../../mcp/)  | `_public/mcp/` | MCP 프로토콜로 창 레이아웃 관리 (Claude Desktop 호환) |

---

## 라이선스

MIT
