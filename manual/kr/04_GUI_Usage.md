# GUI 사용법

fWarrange는 macOS 메뉴바에 상주하는 SwiftUI 앱으로, 클릭 한 번에 레이아웃을 관리할 수 있습니다.

## 메인 화면

메뉴바 아이콘을 클릭하면 레이아웃 목록과 주요 버튼이 표시됩니다.

![메인 화면](https://finfra.kr/product/fWarrange/kr/main_1.png)

![메인 화면 전체](https://finfra.kr/product/fWarrange/kr/main_all.png)

### 주요 기능
- **캡처 버튼**: 현재 창 배치를 새 레이아웃으로 저장
- **레이아웃 목록**: 저장된 레이아웃 선택 및 복원
- **삭제**: 레이아웃 삭제
- **이름 변경**: 레이아웃 이름 편집

## 설정 (5탭 구성)

메뉴바 > 설정 아이콘으로 설정 창을 엽니다.

### 탭 1: 일반 (General)

![일반 설정](https://finfra.kr/product/fWarrange/kr/setting_1_general.png)

| 항목        | 설명                                                |
| ----------- | --------------------------------------------------- |
| 언어        | 앱 표시 언어 선택 (시스템, 한국어, 영어, 일본어 등) |
| 데이터 경로 | 레이아웃 YAML 파일 저장 위치                        |
| 권한 상태   | 손쉬운 사용(Accessibility) 권한 확인                |
| 자동 실행   | macOS 로그인 시 자동 시작                           |
| 테마        | 시스템/라이트/다크 모드                             |

### 탭 2: 단축키 (Shortcuts)

![단축키 설정](https://finfra.kr/product/fWarrange/kr/setting_2_shortcuts.png)

5개의 글로벌 단축키를 사용자 지정할 수 있습니다:

| 기능      | 기본 단축키 | 설명                  |
| --------- | ----------- | --------------------- |
| 캡처      | -           | 현재 창 배치 저장     |
| 복구      | -           | 마지막 레이아웃 복원  |
| 목록      | -           | 레이아웃 선택 창 표시 |
| 팝업 열기 | -           | 메뉴바 팝업 토글      |
| 설정      | -           | 설정 창 열기          |

### 탭 3: 복구 (Restore)

![복구 설정](https://finfra.kr/product/fWarrange/kr/setting_3_restore.png)

| 항목           | 기본값    | 설명                             |
| -------------- | --------- | -------------------------------- |
| 재시도 횟수    | 5         | 창 매칭 실패 시 최대 재시도 횟수 |
| 재시도 간격    | 0.5초     | 재시도 사이 대기 시간            |
| 최소 매칭 점수 | 30        | 이 점수 미만의 매칭은 무시       |
| 제외 앱 목록   | 시스템 앱 | 캡처/복원에서 제외할 앱          |

**제외 앱 기본값:**
- Window Server, Control Center, Presentation Assistant
- Dock, SystemUIServer, Spotlight

### 탭 4: API

![API 설정](https://finfra.kr/product/fWarrange/kr/setting_4_api.png)

| 항목           | 기본값         | 설명                    |
| -------------- | -------------- | ----------------------- |
| 서버 활성화    | OFF            | REST API 서버 시작/중지 |
| 포트           | 3016           | HTTP 수신 포트          |
| 외부 접속 허용 | OFF            | LAN/WAN에서의 접근 허용 |
| 허용 CIDR      | 192.168.0.0/16 | IP 화이트리스트         |

### 탭 5: 고급 (Advanced)

![고급 설정](https://finfra.kr/product/fWarrange/kr/setting_5_advanced.png)

| 항목           | 설명                            |
| -------------- | ------------------------------- |
| 로그 설정      | 디버그 로그 활성화/비활성화     |
| Dangerous Zone | 전체 레이아웃 삭제, 설정 초기화 |

## 일반적인 사용 흐름

1. 메뉴바 아이콘 클릭
2. "캡처" 버튼으로 현재 배치 저장
3. 필요할 때 목록에서 레이아웃 선택하여 복원

## 다음 단계

- [REST API 사용법](05_API_Usage.md)
- [Skill 사용법](06_Skill_Usage.md)
- [MCP 서버 사용법](07_MCP_Usage.md)
