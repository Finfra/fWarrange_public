# 빠른 시작 (Quick Start)

fWarrange의 핵심 흐름은 **저장 -> 이동 -> 복원** 3단계입니다.

## 3단계 흐름

### Step 1: 현재 레이아웃 저장 (캡처)

원하는 앱 배치를 만든 후, 그 상태를 저장합니다.

**GUI 방식:**
- 메뉴바 아이콘 > "캡처" 버튼 클릭

**CLI 방식:**
```bash
cd lib/wArrange_core/
swift saveWindowsInfo.swift --name=myWorkspace
```

**API 방식:**
```bash
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"myWorkspace"}'
```

### Step 2: 창 위치 변경

다른 작업을 하면서 창의 위치가 변경된 상황을 가정합니다.
(또는 다른 레이아웃으로 전환한 후 원래 배치로 돌아가고 싶을 때)

### Step 3: 저장된 레이아웃 복원

저장했던 그 배치 그대로 모든 창을 되돌립니다.

**GUI 방식:**
- 메뉴바 아이콘 > 레이아웃 목록에서 선택 > "복원" 클릭

**CLI 방식:**
```bash
cd lib/wArrange_core/
swift setWindows.swift --name=myWorkspace
```

**API 방식:**
```bash
curl -X POST http://localhost:3016/api/v1/layouts/myWorkspace/restore
```

## 활용 시나리오

### 시나리오 1: 개발 환경 전환
```bash
# 코딩 레이아웃 저장
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"coding"}'

# 회의 레이아웃 저장
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"meeting"}'

# 필요할 때 전환
curl -X POST http://localhost:3016/api/v1/layouts/coding/restore
curl -X POST http://localhost:3016/api/v1/layouts/meeting/restore
```

### 시나리오 2: 특정 앱만 저장
```bash
# Safari와 iTerm2만 캡처
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"webDev", "filterApps":["Safari","iTerm2"]}'
```

### 시나리오 3: 레이아웃 관리
```bash
# 전체 목록 조회
curl -s http://localhost:3016/api/v1/layouts | python3 -m json.tool

# 특정 레이아웃 상세 확인
curl -s http://localhost:3016/api/v1/layouts/myWorkspace | python3 -m json.tool

# 레이아웃 이름 변경
curl -X PUT http://localhost:3016/api/v1/layouts/myWorkspace \
  -H "Content-Type: application/json" \
  -d '{"newName":"dailySetup"}'

# 레이아웃 삭제
curl -X DELETE http://localhost:3016/api/v1/layouts/dailySetup
```

## 다음 단계

- [GUI 사용법](04_GUI_Usage.md) - 설정 탭 상세 안내
- [CLI 사용법](05_CLI_Usage.md) - 스크립트 옵션 상세
- [REST API 사용법](06_API_Usage.md) - 전체 엔드포인트 레퍼런스
