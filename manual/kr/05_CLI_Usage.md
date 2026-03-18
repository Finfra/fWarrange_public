# CLI 사용법

fWarrange의 코어 기능은 독립 실행형 Swift 스크립트로 구현되어 있으며, GUI 없이도 터미널에서 직접 사용할 수 있습니다.

## 작업 디렉토리

모든 CLI 스크립트는 `lib/wArrange_core/` 디렉토리에서 실행합니다:

```bash
cd lib/wArrange_core/
```

## 레이아웃 저장 (saveWindowsInfo.swift)

현재 화면에 보이는 모든 창의 위치와 크기를 YAML 파일로 저장합니다.

### 기본 사용법

```bash
# 기본 파일명으로 저장 (data/windowInfo.yml)
swift saveWindowsInfo.swift

# 상세 출력 모드
swift saveWindowsInfo.swift -v

# 파일명 지정
swift saveWindowsInfo.swift --name=myLayout

# 특정 앱만 저장
swift saveWindowsInfo.swift --app=Safari,iTerm2
```

### 매개변수

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `-v` | 수집된 창 정보를 상세 출력 | 비활성 |
| `--name=<이름>` | 저장할 파일명 (확장자 불필요) | windowInfo |
| `--app=<앱1,앱2>` | 특정 앱의 창만 저장 | 모든 앱 |

### 출력 예시 (-v 모드)

```
[saveWindowsInfo] Safari - "Google" pos=(100, 200) size=(1200x800)
[saveWindowsInfo] iTerm2 - "~ - zsh" pos=(0, 25) size=(800x600)
[saveWindowsInfo] Xcode - "fWarrange" pos=(-1707, 99) size=(1707x1280)
총 3개 창 정보 저장 완료: data/myLayout.yml
```

## 레이아웃 복원 (setWindows.swift)

저장된 YAML 파일을 읽어 각 창을 원래 위치로 복원합니다.

### 기본 사용법

```bash
# 기본 파일에서 복원 (data/windowInfo.yml)
swift setWindows.swift

# 상세 출력 모드
swift setWindows.swift -v

# 특정 레이아웃 복원
swift setWindows.swift --name=myLayout
```

### 매개변수

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `-v` | 매칭 점수, 재시도 과정 상세 출력 | 비활성 |
| `--name=<이름>` | 복원할 레이아웃 파일명 | windowInfo |

### 출력 예시 (-v 모드)

```
[setWindows] 매칭: Safari "Google" -> score=100 (ID match)
[setWindows] 복구 완료: Safari pos=(100, 200)
[setWindows] 매칭: iTerm2 "~ - zsh" -> score=90 (Title match)
[setWindows] 복구 완료: iTerm2 pos=(0, 25)
[setWindows] 매칭: Xcode "fWarrange" -> score=70 (Title contains)
[setWindows] 복구 실패: Xcode (재시도 3/5)
[setWindows] 복구 완료: Xcode pos=(-1707, 99)
```

### 창 매칭 점수 시스템

| 점수 | 매칭 조건 | 설명 |
|------|-----------|------|
| 100 | Window ID 일치 | 시스템 창 ID가 동일 |
| 90 | 제목 완벽 일치 | 창 제목이 정확히 동일 |
| 80 | 정규식 매칭 | 패턴 기반 제목 매칭 |
| 70 | 제목 포함 | 핵심 키워드가 포함 |
| 60~30 | 기하학적 유사도 | 크기, 비율, 면적 비교 |

## 진단 스크립트

### list_apps.swift - Accessibility API 기반 창 목록

```bash
swift list_apps.swift
```

손쉬운 사용 권한이 올바르게 설정되었는지 확인합니다.

### list_all_apps.swift - 실행 중 앱 목록

```bash
swift list_all_apps.swift
```

NSWorkspace 기반으로 현재 실행 중인 모든 앱을 표시합니다.

### list_cg.swift - CoreGraphics 기반 창 목록

```bash
swift list_cg.swift
```

CoreGraphics 단에서 인식되는 창 목록을 확인합니다. `list_apps.swift`와 비교하면 권한 문제를 진단할 수 있습니다.

## 데이터 파일 구조

저장된 레이아웃 파일은 YAML 형식입니다:

```yaml
- app: "Safari"
  window: "Google"
  layer: 0
  id: 14205
  pos:
    x: 100.0
    y: 200.0
  size:
    width: 1200.0
    height: 800.0
```

파일 위치: `lib/wArrange_core/data/<name>.yml`

## 자동화 연동

### cron 예시
```bash
# 매일 오전 9시에 개발 레이아웃 복원
0 9 * * * cd /path/to/lib/wArrange_core && swift setWindows.swift --name=dev
```

### Alfred/Raycast 연동
스크립트 경로를 지정하여 핫키로 바인딩할 수 있습니다.

## 다음 단계

- [REST API 사용법](06_API_Usage.md)
- [Skill 사용법](07_Skill_Usage.md)
