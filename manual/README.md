# fWarrange 매뉴얼 개요 (Manual Structure Overview)

본 문서는 fWarrange 사용자/개발자 매뉴얼의 상위 구조와 작성 가이드를 정의합니다. 실제 세부 문서는 본 구조에 따라 하위 파일로 확장합니다.

## 목적과 범위
- 대상: 일반 사용자(기본 GUI 사용), 파워유저(CLI 스크립트 연동), 개발자(Swift/SwiftUI 환경 커스텀)
- 범위: 설치 → 빠른 시작 → 사용자 가이드 → 스마트 매칭 규칙 → 디버깅/레퍼런스 → FAQ/릴리스/부록
- 규칙: 모든 링크는 리포지토리 루트 기준 상대 경로 사용, 한국어 우선

## 디렉토리 구조(제안)
- 01_Overview/
  - Introduction.md: 제품 개요, macOS 윈도우 복원 목적, GUI와 코어 스크립트 분리 아키텍처
  - Architecture.md: 아키텍처 요약 및 데이터 흐름 다이어그램 링크
    - 참조: `_doc_design/design_ARCHITECTURE.md`
- 02_Install/
  - Install_macOS.md: 요구사항(macOS 15.0+), 빌드/설치 방법
  - Permissions.md: 손쉬운 사용(Accessibility) 권한 설정/진단 가이드(터미널, App별)
- 03_QuickStart/
  - QuickStart.md: 레이아웃 저장부터 복구까지 표준 3단계 흐름(저장 → 윈도우 이동 → 복원)
- 04_UserGuide/
  - GUI_Usage.md: SwiftUI 시스템 트레이 앱 사용법 및 자동화 설정
  - CLI_Usage.md: `saveWindowsInfo.swift`, `setWindows.swift` 매개변수 활용 및 커스텀 YAML 데이터 지정
- 05_LayoutRules/
  - MatchingAlgorithm.md: 스마트 매칭 엔진(Score System: 100~30점) 단계별 규칙해설
  - YAML_DataStructure.md: `windowInfo.yml`의 좌표계(pos), 크기(size), 레이어 속성 정리
- 06_Advanced/
  - Scripting.md: `list_apps.swift`, `list_cg.swift` 상세 활용 및 타 시스템 연동
- 07_Debugging/
  - Logs.md: 앱 로그, 터미널 출력 형식 및 오류 판단 방법
  - Troubleshooting.md: 손쉬운 사용 권한 꼬임 해결, 창 크기 계산(CoreGraphics vs AppKit) 문제 진단
- 08_Reference/
  - Options.md: 스크립트 `-v`, `--name`, `--app` 등 옵션 모음
- 09_FAQ/
  - FAQ.md: 윈도우 복원 실패, 서브 모니터 좌표 문제, 전체 창 vs 크롬 탭 복구 등 자주 묻는 질문
- 10_Release/
  - Changelog.md: 버전별 변경 요약
- 99_Appendix/
  - Glossary.md: 용어 사전(프로젝트 용어/다국어 통일)

## 작성 가이드
- 파일/제목 규칙: 폴더별 주제 중심, 명사형 제목 사용
- 링크 정책: 문서 간 교차 참조는 상대 경로 사용(예: `../05_LayoutRules/MatchingAlgorithm.md`)
- 코드/명령 표기: 백틱(`)으로 감싸 명확히 표기 (예: `swift saveWindowsInfo.swift`)
- 스크린샷: `finfraHome/_resource/product/fWarrange.capture/` 파일들을 참조하여 삽입

## 빠른 시작(요약)
- **캡처**: `cd lib/wArrange_core/ && swift saveWindowsInfo.swift`
- **복원**: `cd lib/wArrange_core/ && swift setWindows.swift`
- **앱 보기**: `swift list_all_apps.swift`
- **GUI 빌드**: `xcodebuild -scheme fWarrange -configuration Debug build`

## 향후 작성 일정(To‑Do)
- [ ] 01_Overview/Introduction.md 초안
- [ ] 02_Install/Permissions.md (손쉬운 사용 권한 스크린샷 포함)
- [ ] 04_UserGuide/CLI_Usage.md
- [ ] 05_LayoutRules/MatchingAlgorithm.md (스코어 표 정리)
- [ ] 07_Debugging/Troubleshooting.md (권한 초기화 등)
- [ ] 09_FAQ/FAQ.md

## 관련 문서(핵심 링크)
- **시스템 문서**: `GEMINI.md`, `tasks.md`
- **이슈 관리**: `Issue.md`

---
본 README는 매뉴얼의 “맵” 역할을 합니다. 각 섹션 작성 시 본 구조를 기준으로 문서를 추가하고, 완료 후 본 리스트의 To‑Do를 체크하세요.
