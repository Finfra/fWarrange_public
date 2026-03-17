# 용어 사전 (Glossary)

이 문서는 fWarrange 프로젝트 내의 주요 기술 용어와 다국어 번역을 통일하기 위해 정리된 문서입니다. 다국어 매뉴얼 작성 및 앱 로컬라이제이션(Localization) 시 본 용어집을 최우선으로 준수합니다.

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

> **참고 (Notes)**:
> *   빈 칸 혹은 미번역 항목은 향후 Localization 팀과의 협의 후 `Localizable.strings` 리소스를 기준으로 업데이트 될 예정입니다.
> *   과도한 시스템 운영체제 종속 단어(System Preferences, System Settings 등)는 macOS의 버전에 따라 달라지므로, 해당 버전 가닥을 타도록 원문(General)을 유지할 것을 권장합니다.
> *   "손쉬운 사용"은 한국어 macOS 공식 용어이므로 어떠한 상황에서도 "접근성"보다 우선하여 사용해야 합니다.
