---
title: fWarrange 제품 개요
description: fWarrange 제품 개요 및 핵심 기능 소개 (한국어)
date: 2026-03-26
---

# fWarrange란?

fWarrange는 macOS 사용자의 작업 환경을 기억하고, 단 한 번의 조작으로 수많은 창들의 위치와 크기를 완벽하게 되돌려 놓는 **윈도우 레이아웃 복원 도구**입니다.

다중 모니터 환경이나 복잡한 개발/디자인 작업 시 흩어지는 창들을 매번 다시 배치할 필요 없이, 지정된 목적(개발, 회의, 디자인 등)에 맞는 앱 창 배열을 즉시 복원합니다.

# 핵심 기능

| 기능              | 설명                                                         |
| ----------------- | ------------------------------------------------------------ |
| 레이아웃 캡처     | CoreGraphics 기반으로 모든 활성 창의 위치/크기를 YAML로 저장 |
| 스마트 복원       | 점수 기반 매칭 알고리즘으로 창 ID가 바뀌어도 정확히 복원     |
| 다중 레이아웃     | 목적별(개발, 회의, 디자인) 복수 프로필 관리                  |
| 다중 모니터       | 보조 모니터 포함 전체 디스플레이 환경 지원                   |
| REST API          | HTTP 기반 원격 제어 (자동화, Apple Shortcuts 연동)           |
| Claude Code Skill | AI 에이전트에서 자연어로 레이아웃 관리                       |
| MCP 서버          | AI 도구(Claude Desktop 등)에서 직접 호출 가능                |

# 아키텍처

fWarrange는 두 가지 컴포넌트로 구성됩니다:

```
+----------------------------------+
|  SwiftUI GUI (메뉴바 앱)          |
|  - 5탭 설정 (일반/단축키/복구/API/고급) |
|  - REST API 내장 서버              |
+----------------------------------+
          |  호출
+----------------------------------+
|  Swift 코어 스크립트               |
|  lib/wArrange_core/              |
|  - saveWindowsInfo.swift (캡처)   |
|  - setWindows.swift (복원)        |
+----------------------------------+
          |  사용
+----------------------------------+
|  macOS 시스템 API                 |
|  - CoreGraphics (창 정보 읽기)     |
|  - Accessibility API (창 제어)     |
+----------------------------------+
```

# 데이터 흐름

```
[CoreGraphics] CGWindowListCopyWindowInfo()
      | 창 정보 수집 (id, pos, size, layer)
      v
[saveWindowsInfo.swift] --> YAML 직렬화 --> data/*.yml
      |
      v
[setWindows.swift] YAML 파싱 --> 앱/창 매칭 --> AXUIElement 설정
```

# 지원 환경

| 항목       | 요구사항                             |
| ---------- | ------------------------------------ |
| OS         | macOS 15.0 (Sequoia) 이상            |
| Swift      | 5.10 이상                            |
| 프레임워크 | SwiftUI, AppKit, CoreGraphics        |
| 권한       | 손쉬운 사용(Accessibility) 권한 필수 |

# 인터페이스 개요

fWarrange는 4가지 방식으로 사용할 수 있습니다:

1. **GUI 앱** - 메뉴바 상주 앱으로 클릭 한 번에 캡처/복원
2. **CLI 스크립트** - 터미널에서 직접 Swift 스크립트 실행
3. **REST API** - curl, Apple Shortcuts, 자동화 스크립트로 HTTP 호출
4. **AI 연동** - Claude Code Skill 또는 MCP 서버로 AI 에이전트에서 제어

## CLI 스크립트 빠른 참조

GUI 앱 없이 `lib/wArrange_core/` 디렉토리의 Swift 스크립트로 직접 사용할 수 있습니다:

```bash
# 캡처
swift saveWindowsInfo.swift                     # 기본 파일(windowInfo.yml)로 저장
swift saveWindowsInfo.swift --name=myLayout     # 이름 지정 저장
swift saveWindowsInfo.swift --app=Safari,iTerm2 # 특정 앱만 캡처
swift saveWindowsInfo.swift -v                  # 상세 출력

# 복원
swift setWindows.swift                          # 기본 파일에서 복원
swift setWindows.swift --name=myLayout          # 이름 지정 복원
swift setWindows.swift -v                       # 매칭 점수 등 상세 출력

# 진단
swift list_apps.swift                           # Accessibility API 기반 창 목록
swift list_all_apps.swift                       # 실행 중 앱 목록
swift list_cg.swift                             # CoreGraphics 기반 창 목록
```

# 다음 단계

* [설치 및 권한 설정](02_Install.md)
* [빠른 시작](03_QuickStart.md)
