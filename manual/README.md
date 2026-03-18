# fWarrange 매뉴얼 개요 (Manual Structure Overview)

본 문서는 fWarrange 사용자/개발자 매뉴얼의 상위 구조와 작성 가이드를 정의합니다. 실제 세부 문서는 본 구조에 따라 하위 파일로 확장합니다.

## 목적과 범위
- 대상: 일반 사용자(기본 GUI 사용), 파워유저(CLI 스크립트 연동), 개발자(Swift/SwiftUI 환경 커스텀), AI 에이전트 사용자(Skill/MCP 연동)
- 범위: 설치 → 빠른 시작 → 사용자 가이드(GUI/CLI/API/Skill/MCP) → FAQ
- 규칙: 모든 링크는 리포지토리 루트 기준 상대 경로 사용, 한국어(kr/)/영어(en/) 이중 언어 지원

## 디렉토리 구조

```
_public/manual/
├── README.md                    # 본 파일 (매뉴얼 구조 가이드)
├── FunctionalSpecification.md   # 기능 명세서
├── ReferenceAgenda.md           # 참조 목록
├── Glossary.md                  # 용어 사전
├── kr/                          # 한국어 매뉴얼
│   ├── 01_Overview.md           # 제품 개요
│   ├── 02_Install.md            # 설치 및 권한 설정
│   ├── 03_QuickStart.md         # 빠른 시작 (저장→복원 3단계)
│   ├── 04_GUI_Usage.md          # GUI 사용법 (5탭 설정)
│   ├── 05_CLI_Usage.md          # CLI 사용법
│   ├── 06_API_Usage.md          # REST API 사용법 (14개 엔드포인트)
│   ├── 07_Skill_Usage.md        # Claude Code Skill 사용법
│   ├── 08_MCP_Usage.md          # MCP 서버 사용법
│   └── 09_FAQ.md                # 자주 묻는 질문
└── en/                          # English Manual
    ├── 01_Overview.md           # Product Overview
    ├── 02_Install.md            # Installation & Permissions
    ├── 03_QuickStart.md         # Quick Start
    ├── 04_GUI_Usage.md          # GUI Usage
    ├── 05_CLI_Usage.md          # CLI Usage
    ├── 06_API_Usage.md          # REST API Usage
    ├── 07_Skill_Usage.md        # Claude Code Skill Usage
    ├── 08_MCP_Usage.md          # MCP Server Usage
    └── 09_FAQ.md                # FAQ
```

## GUI 설정 탭 구성 (5탭)

| 탭 | 주요 항목 |
|----|-----------|
| 일반 | 언어, 데이터 경로, 권한 상태, 자동실행, 테마 |
| 단축키 | 캡처/복구/목록 등 5개 단축키 설정 |
| 복구 | 재시도 횟수, 간격, 매칭 점수 기준, 제외 앱 목록 |
| API | REST 서버 활성화, 포트 설정, 외부 접속 허용, CIDR 필터 |
| 고급 | 로그 설정, 기타 옵션, Dangerous Zone |

## 빠른 시작(요약)
- **캡처**: `cd lib/wArrange_core/ && swift saveWindowsInfo.swift`
- **복원**: `cd lib/wArrange_core/ && swift setWindows.swift`
- **앱 보기**: `swift list_all_apps.swift`
- **GUI 빌드**: `xcodebuild -scheme fWarrange -configuration Debug build`
- **API 서버**: 설정 → API 탭에서 활성화 후 `curl http://localhost:3016/`
- **API 캡처**: `curl -X POST http://localhost:3016/api/v1/capture -H "Content-Type: application/json" -d '{"name":"myLayout"}'`
- **API 복구**: `curl -X POST http://localhost:3016/api/v1/layouts/myLayout/restore`
- **Skill 캡처**: `/fwarrange:fwarrange capture --name=myLayout`
- **Skill 복원**: `/fwarrange:fwarrange restore myLayout`

## 작성 진행 상황 (To-Do)

### 한국어 (kr/)
- [x] 01_Overview.md - 제품 개요
- [x] 02_Install.md - 설치 및 권한 설정
- [x] 03_QuickStart.md - 빠른 시작
- [x] 04_GUI_Usage.md - GUI 사용법
- [x] 05_CLI_Usage.md - CLI 사용법
- [x] 06_API_Usage.md - REST API 사용법 (14개 엔드포인트, curl 예제, 보안, Apple Shortcuts)
- [x] 07_Skill_Usage.md - Claude Code Skill 사용법
- [x] 08_MCP_Usage.md - MCP 서버 사용법
- [x] 09_FAQ.md - 자주 묻는 질문

### 영어 (en/)
- [x] 01_Overview.md - Product Overview
- [x] 02_Install.md - Installation & Permissions
- [x] 03_QuickStart.md - Quick Start
- [x] 04_GUI_Usage.md - GUI Usage
- [x] 05_CLI_Usage.md - CLI Usage
- [x] 06_API_Usage.md - REST API Usage
- [x] 07_Skill_Usage.md - Claude Code Skill Usage
- [x] 08_MCP_Usage.md - MCP Server Usage
- [x] 09_FAQ.md - FAQ

### 공통 문서
- [x] README.md - 매뉴얼 구조 가이드
- [x] FunctionalSpecification.md - 기능 명세서 (Skill, MCP 섹션 포함)
- [x] ReferenceAgenda.md - 참조 목록 (Skill, MCP 섹션 포함)
- [x] Glossary.md - 용어 사전 (Skill, MCP 용어 포함)

## 관련 문서(핵심 링크)
- **시스템 문서**: `GEMINI.md`, `tasks.md`
- **이슈 관리**: `Issue.md`
- **API 스펙**: `_public/api/openapi.yaml`
- **REST 설계 문서**: `_doc_design/RestAPI.md`
- **API 테스트 스크립트**: `lib/rest/test-api.sh`
- **Skill 정의**: `_public/agents/claude/skills/fwarrange/SKILL.md`
- **Plugin 설정**: `_public/agents/claude/.claude-plugin/plugin.json`

---
본 README는 매뉴얼의 "맵" 역할을 합니다. 각 섹션 작성 시 본 구조를 기준으로 문서를 추가하고, 완료 후 본 리스트의 To-Do를 체크하세요.
