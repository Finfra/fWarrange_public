---
name: TDD Runner
description: lib/wArrange_core/ 내 Swift 스크립트를 실행하여 기능을 검증합니다.
---

# TDD Runner Skill

fWarrange의 핵심 로직은 `lib/wArrange_core/` 내 Swift 스크립트로 구현되어 있습니다.
Xcode Unit Test 대신 스크립트 직접 실행으로 기능을 검증합니다.

## 기본 실행 (Usage)

```bash
cd lib/wArrange_core

# 창 정보 저장 테스트
swift saveWindowsInfo.swift -v

# 창 복구 테스트
swift setWindows.swift -v

# 앱 목록 확인
swift list_apps.swift
swift list_all_apps.swift
swift list_cg.swift
```

## 저장→복구 순환 테스트

```bash
cd lib/wArrange_core

# 1. 현재 레이아웃 저장
swift saveWindowsInfo.swift -v --name=test_layout

# 2. 저장된 내용 확인
cat data/test_layout.yml

# 3. 복구 실행
swift setWindows.swift -v --name=test_layout
```

## 스크립트 컴파일 검증

```bash
cd lib/wArrange_core
swiftc saveWindowsInfo.swift -o /tmp/test_save && echo "✅ saveWindowsInfo OK"
swiftc setWindows.swift -o /tmp/test_set && echo "✅ setWindows OK"
```

## 범위 (Scope)

- **saveWindowsInfo.swift**: CGWindowListCopyWindowInfo() 기반 창 정보 수집
- **setWindows.swift**: AXUIElement 기반 창 위치/크기 복원 (Accessibility 권한 필요)
- **list_*.swift**: 진단용 - 앱/창 목록 출력
- **data/*.yml**: 저장된 레이아웃 파일
