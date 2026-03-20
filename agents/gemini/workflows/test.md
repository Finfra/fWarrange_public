---
description: "저장→복구 순환 테스트 (Swift 스크립트 기반)"
---

# Test Workflow

## 1. 테스트 전 준비
테스트할 창들을 화면에 열어둡니다. (Safari, iTerm2, Xcode 등)

## 2. 창 정보 저장
```bash
cd lib/wArrange_core
swift saveWindowsInfo.swift -v --name=test_layout
```

저장 결과 확인:
```bash
cat lib/wArrange_core/data/test_layout.yml
```

## 3. 창 위치 변경
저장 후 창들을 임의로 이동/크기 조정하여 레이아웃을 변경합니다.

## 4. 창 복구
```bash
cd lib/wArrange_core
swift setWindows.swift -v --name=test_layout
```

## 5. 결과 확인
- 각 창이 저장된 위치/크기로 정확히 복원되었는지 확인합니다.
- `-v` 출력에서 `✅` / `❌` 상태를 확인합니다.

## 진단 스크립트 (Diagnostic)
```bash
cd lib/wArrange_core
swift list_apps.swift        # Accessibility API 앱 목록
swift list_cg.swift          # CoreGraphics 창 목록
```
