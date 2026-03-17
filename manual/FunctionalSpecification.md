---
title: fWarrange 사용자 매뉴얼 및 기능 명세서 (User Manual & Functional Specification)
description: 본 문서는 fWarrange의 핵심 기술인 **CoreGraphics 기반 고정밀 레이아웃 캡처**, 지능적인 **Score 기반 스마트 창 매칭 복원 알고리즘**, 그리고 **Accessibility 제어 기술**에 대한 포괄적인 가이드를 제공합니다.
date: 2026.03.14
tags: [매뉴얼, 사용자 가이드, 윈도우 제어, 기능 명세]
---

# fWarrange란? (Overview)

fWarrange는 macOS 사용자의 작업 환경을 기억하고 단 한 번의 조작으로 수많은 창들의 위치와 크기를 완벽하게 되돌려 놓는 **윈도우 레이아웃 복원 도구**입니다.
다중 모니터 환경이나 복잡한 개발/디자인 작업 시 흩어지는 창들을 매번 다시 배치할 필요 없이, 지정된 목적(개발, 회의, 디자인 등)에 맞는 앱 창 배열을 즉시 복원합니다.
순수 Swift 코어 스크립트 기반 모터 구동과 사용자 친화적인 SwiftUI GUI 래퍼를 모두 지원하여, 파워유저부터 일반 타겟까지 아우르는 생산성 소프트웨어입니다.

---

# 1. 고정밀 레이아웃 캡처 (Layout Capture System)

현재 눈에 보이는 화면의 상태와 모든 애플리케이션의 윈도우 크기를 그대로 복제해 내는 정보 수집 코어입니다.

## 1.1. CoreGraphics 기반의 윈도우 스캔 (`saveWindowsInfo.swift`)

### 1.1.1. 안전한 정보 추출
`appKit`에 의존하지 않고 시스템 하부의 `CGWindowListCopyWindowInfo` API를 사용하여 윈도우 객체들을 탐색합니다. 불필요한 백그라운드 데몬, 투명 툴팁 바, 혹은 상단 메뉴바 등을 걸러내고 유효한(Interactive) 앱 창 데이터만 추출합니다.

### 1.1.2. 구조화된 YAML 직렬화 보관
수집된 각각의 윈도우 데이터는 다음과 같은 형태의 YAML 텍스트(`data/windowInfo.yml`) 포맷으로 영구 저장됩니다:
- `app`: 프로세스 내 애플리케이션 이름 (예: Safari)
- `window`: 활성화된 탭 혹은 창의 타이틀 명
- `layer`: Z-Index 레이어 뎁스(0번이 일반적인 창)
- `pos`, `size`: `x`, `y` 좌표 및 `width`, `height` 절대 픽셀 값

---

# 2. 스마트 창 복원 엔진 (Smart Restoration Engine)

가장 복잡하고 강력한 컴포넌트입니다. 앱이 재실행되거나 탭이 변경되어 **과거 저장 시점의 윈도우 ID와 현재의 윈도우 ID가 달라지더라도** 원래 위치를 유추해 찾아가는 퍼지 매칭 시스템입니다.

## 2.1. 동적 매칭 스코어 시스템 (Dynamic Score Matching)

`setWindows.swift` 작동 시, 단순히 앱 이름만 보지 않고 화면상 떠 있는 앱 창과 YAML 저장 기록을 다각도로 교차 점검하여 **가장 높은 점수(Score)**를 획득한 창끼리 결합시킵니다:

- **100점 (Perfect Match)**: 앱과 창의 Window ID(PID)가 정확히 동일한 경우 (가장 확실함)
- **90점 (Title Match)**: Window ID는 변했지만 창의 전체 텍스트 제목(Title)이 과거 저장 기록과 글자 하나 안 틀리고 똑같은 경우.
- **80점 (Regex/Pattern Match)**: 약간의 변형이 생긴 경우. 설정된 정규표현식이나 동적 제목 생성 패턴과 일치하는지 분석합니다.
- **70점 (Keyword Match)**: 웹브라우저 등에서 제목이 일부 바뀌었으나(예: `[Google - 검색]`), 핵심 도메인 키워드가 일치하는 경우.
- **60~30점 (Geometry Fallback)**: 제목마저 완전히 바뀌었다면(가령 빈 문서가 다른 프로젝트 문서로 변함), 최후의 수단으로 화면에서의 유사한 위치 비율, 면적 사이즈 등을 분석하여 가장 과거 이력과 흡사했던 창을 도출합니다.

## 2.2. AppKit Accessibility(`AXUIElement`) 강제 제어

점수가 매겨져 짝(Pair) 지어진 윈도우는 macOS의 **손쉬운 사용(Accessibility)** 권한을 활용해 즉시 목표 좌표와 사이즈로 강제 이동 및 리사이즈됩니다. 이 방식은 애니메이션 딜레이 없이 즉각적이고 정확하게 창을 옮길 수 있게 합니다.

---

# 3. 유연도 높은 CLI 및 진단 편의성

GUI가 없어도 동작하는 가벼운 독립형 툴킷(lib/wArrange_core)을 근간으로 삼기 때문에 자동화(Automator, Alfred, 쉘 스크립트 등) 접목이 탁월합니다.

### 3.1. CLI 래핑 커맨드

- `-v` (Verbose): 모든 매칭 계산의 스코어 로그와 진행 상태를 터미널로 상세 출력하여 디버깅을 돕습니다.
- `--name=profileName`: 기본 `windowInfo.yml` 대신 사용자가 지정한 `profileName.yml` (예: `dev_mode.yml`, `design_mode.yml`)에서 데이터를 읽거나 저장할 수 있습니다.
- `--app=AppA,AppB`: 화면의 수많은 앱 중 특정 앱 배열 상태만 부분 저장/복구하고 싶을 때 사용 가능합니다.

### 3.2. 진단 전용 스크립트 묶음

- `list_apps.swift`: 손쉬운 사용 권한 도달이 정상적인지 체크합니다.
- `list_cg.swift`: CoreGraphics 단에서 창이 제대로 인지되고 있는지 확인합니다.
- 복원 실패 시, 이 두 스크립트 출력 결과를 비교하는 것으로 트러블슈팅을 직관적으로 끝낼 수 있습니다.

---

# 4. SwiftUI GUI 연동 아키텍처

GUI 애플리케이션은 뒷단의 코어 스크립트들을 간편하게 조작할 수 있도록 래핑(Wrapping)된 컨트롤 레이어로 작동합니다.
상단 메뉴바 트레이(Tray) 앱 형태로 상주하며, 클릭 한 방에 CLI 명령어(`swift setWindows.swift --name=xxx`)를 쉘 아웃으로 대신 실행해 주어 파워유저의 강력함과 일반 사용자의 편의성을 동시에 잡았습니다.
