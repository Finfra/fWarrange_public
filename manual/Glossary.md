# 용어 사전 (Glossary)

이 문서는 fWarrange 프로젝트 내의 주요 기술 용어와 다국어 번역을 통일하기 위해 정리된 문서입니다. 다국어 매뉴얼 작성 및 앱 로컬라이제이션(Localization) 시 본 용어집을 최우선으로 준수합니다.

## 핵심 용어 (Core Terms)

| 설명 (설계/기능)                                                  | English           | Korean (기준)    | Japanese             | German                    | Simplified Chinese |
| :---------------------------------------------------------------- | :---------------- | :--------------- | :------------------- | :------------------------ | :----------------- |
| 앱 화면에서의 창의 위치 및 크기 기록 단위                         | Layout            | 레이아웃         | レイアウト           | Layout                    | 布局 (Bùjú)        |
| 실행 중인 애플리케이션의 활성 화면 조각                           | Window            | 윈도우 (창)      | ウィンドウ           | Fenster                   | 窗口 (Chuāngkǒu)   |
| 과거 상태와 현재 창의 동일성을 수치화한 점수                      | Matching Score    | 매칭 점수        | マッチングスコア     | Übereinstimmungsbewertung | 匹配分数           |
| macOS에서 창을 제어하기 위해 시스템이 요구하는 필수 권한          | Accessibility     | 손쉬운 사용      | アクセシビリティ     | Bedienungshilfen          | 辅助功能           |
| 사용자가 현재 클릭하여 조작 가능한 최상단 윈도우                  | Active Window     | 활성 창          | アクティブウィンドウ | Aktives Fenster           | 活动窗口           |
| 창 제목이 바뀐 경우, 면적이나 크기 비율로 대신 창을 찾아내는 로직 | Geometry Fallback | 도형 유사도 판별 | 幾何学的類似性判定   | Geometrie-Rückgriff       | 几何相似度匹配     |
| 지정된 템플릿(Layout)의 좌표와 크기로 창을 이동시키는 액션        | Restore / Apply   | 복원 (적용)      | 復元 (適用)          | Wiederherstellen          | 恢复 (应用)        |
| 현재 윈도우의 상태를 YAML 문서로 보존하는 액션                    | Save / Capture    | 캡처 (저장)      | キャプチャ (保存)    | Speichern (Erfassen)      | 保存 (捕获)        |
| 패턴 매칭 규칙을 통한 창 제목 역추적 기법                         | Regex Match       | 정규식 매칭      | 正規表現マッチング   | Regex-Übereinstimmung     | 正则匹配           |
| 다중 모니터 구성을 아우르는 하나의 논리적 바탕화면                | Workspace         | 워크스페이스     | ワークスペース       | Arbeitsbereich            | 工作区             |

## REST API 관련 용어

| 설명 (설계/기능)                                                  | English           | Korean (기준)    | Japanese             | German                    | Simplified Chinese |
| :---------------------------------------------------------------- | :---------------- | :--------------- | :------------------- | :------------------------ | :----------------- |
| 외부 클라이언트가 HTTP로 앱 기능을 원격 호출하는 인터페이스       | REST API          | REST API         | REST API             | REST API                  | REST API           |
| 네트워크 요청을 수신하여 응답을 반환하는 내장 서버                | Embedded Server   | 내장 서버        | 内蔵サーバー         | Eingebetteter Server      | 内置服务器         |
| IP 주소 대역을 지정하여 접근을 제한하는 보안 규칙                 | CIDR Whitelist    | CIDR 화이트리스트 | CIDRホワイトリスト   | CIDR-Whitelist            | CIDR白名单         |
| 앱 내부 이벤트를 다른 컴포넌트에 비동기 전달하는 메커니즘         | Notification      | 알림 (노티피케이션) | 通知               | Benachrichtigung          | 通知               |
| 앱 상단 메뉴바에 상주하는 시스템 트레이 형태의 인터페이스         | Menu Bar App      | 메뉴바 앱        | メニューバーアプリ   | Menüleisten-App           | 菜单栏应用         |

## AI 연동 관련 용어 (Skill / MCP / Plugin)

| 설명 (설계/기능)                                                  | English               | Korean (기준)      |
| :---------------------------------------------------------------- | :-------------------- | :------------------ |
| Claude Code에서 슬래시 커맨드로 호출되는 특정 기능 단위           | Skill                 | 스킬                |
| AI 모델이 외부 도구와 상호작용하기 위한 표준 프로토콜             | MCP (Model Context Protocol) | MCP                |
| 기능 확장을 위해 호스트 앱에 추가 설치하는 소프트웨어 모듈        | Plugin                | 플러그인            |
| Anthropic의 AI 코딩 어시스턴트 CLI 도구                           | Claude Code           | Claude Code         |
| Anthropic의 AI 데스크탑 클라이언트 앱                             | Claude Desktop        | Claude Desktop      |
| Node.js 패키지 관리자                                             | npm                   | npm                 |
| 프로세스 간 표준 입출력을 통한 통신 방식                          | stdio                 | stdio               |
| AI가 외부 시스템의 기능을 호출하기 위해 사용하는 인터페이스       | Tool                  | 도구 (Tool)         |
| MCP 서버의 설정을 정의하는 JSON 파일                              | MCP Config            | MCP 설정 파일       |
| AI 에이전트가 자연어 요청을 분석하여 적절한 도구를 선택하는 과정  | Tool Selection        | 도구 선택           |

> **참고 (Notes)**:
> *   빈 칸 혹은 미번역 항목은 향후 Localization 팀과의 협의 후 `Localizable.strings` 리소스를 기준으로 업데이트 될 예정입니다.
> *   과도한 시스템 운영체제 종속 단어(System Preferences, System Settings 등)는 macOS의 버전에 따라 달라지므로, 해당 버전 가닥을 타도록 원문(General)을 유지할 것을 권장합니다.
> *   "손쉬운 사용"은 한국어 macOS 공식 용어이므로 어떠한 상황에서도 "접근성"보다 우선하여 사용해야 합니다.
