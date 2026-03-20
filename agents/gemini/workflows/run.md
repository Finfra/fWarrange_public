---
description: "fWarrange 앱 빌드 및 실행"
---

1. **앱 빌드 및 실행**:

   **옵션 A: Xcode에서 실행 (권장)**
   ```bash
   open fWarrange/fWarrange.xcodeproj
   # Xcode에서 ▶ (Run) 버튼 클릭
   ```

   **옵션 B: 터미널 빌드 후 실행**
   ```bash
   cd fWarrange
   xcodebuild -scheme fWarrange -configuration Debug build -quiet

   BUILD_DIR=$(xcodebuild -scheme fWarrange -showBuildSettings | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)
   open "$BUILD_DIR/fWarrange.app"
   ```

2. **실행 확인**:
   - 앱이 실행되고 런타임 에러 없이 동작하는지 확인합니다.

3. **Swift 스크립트 실행** (lib 기능 테스트):
   ```bash
   cd lib/wArrange_core

   # 창 정보 저장
   swift saveWindowsInfo.swift -v

   # 창 복구
   swift setWindows.swift -v
   ```

## 문제 해결 (Troubleshooting)
빌드가 실패하거나 앱이 실행되지 않을 경우 **Build Doctor Skill**을 참고하세요.
- **스킬 경로**: `.agent/skills/build-doctor/SKILL.md`
- **빠른 복구**: `DerivedData` 삭제 및 `Clean Build` 시도
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData/fWarrange-*
  cd fWarrange && xcodebuild -scheme fWarrange -configuration Debug clean
  ```
