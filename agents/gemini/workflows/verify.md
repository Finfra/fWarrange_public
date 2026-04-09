---
description: "배포하거나 버전을 올리지 않고 빌드만 검증합니다."
title: verify
date: 2026-03-26
---

이 워크플로우는 Debug 스킴을 사용하여 프로젝트를 컴파일하고 문법 오류나 빌드 실패가 없는지 확인합니다.
다음 작업은 **수행하지 않습니다**:
* 버전 번호 증가
* `/Applications` 내 앱 교체
* 실행 중인 프로세스 종료

1. **Xcode 앱 빌드 검증**:
    ```bash
    cd fWarrange
    xcodebuild -scheme fWarrange -configuration Debug build -quiet && echo "✅ Build OK"
    ```

2. **Swift 스크립트 컴파일 검증**:
    ```bash
    cd lib/wArrange_core
    swiftc saveWindowsInfo.swift -o /tmp/verify_save && echo "✅ saveWindowsInfo OK"
    swiftc setWindows.swift -o /tmp/verify_set && echo "✅ setWindows OK"
    ```
