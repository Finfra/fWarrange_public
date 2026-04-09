---
title: fWarrange 설치 가이드
description: fWarrange 설치 및 초기 설정 가이드 (한국어)
date: 2026-03-26
---
# 설치 및 권한 설정

## 1. 시스템 요구사항

| 항목   | 최소 요구           |
| ------ | ------------------- |
| macOS  | 15.0 (Sequoia) 이상 |
| Swift  | 5.10 이상           |
| Xcode  | 16.0 이상 (빌드 시) |
| 디스크 | 약 50MB             |

## 2. 설치 방법

### 2.1. 배포 앱 설치 (권장)

1. `fWarrange.app`을 `/Applications/` 또는 원하는 폴더에 복사
2. 처음 실행 시 macOS Gatekeeper 경고가 나타나면 "열기" 선택

### 2.2. 소스에서 빌드

```bash
# 리포지토리 클론
git clone https://github.com/nowage/fWarrange.git
cd fWarrange

# Xcode 빌드
cd fWarrange
xcodebuild -scheme fWarrange -configuration Debug build
```

빌드 결과물은 DerivedData 경로에 생성됩니다:
```
~/Library/Developer/Xcode/DerivedData/fWarrange-*/Build/Products/Debug/fWarrange.app
```

## 2.3. CLI 전용 사용 (GUI 없이)

GUI 앱 없이 코어 스크립트만 사용할 수도 있습니다:

```bash
cd lib/wArrange_core/
swift saveWindowsInfo.swift    # 캡처
swift setWindows.swift         # 복원
```

## 3. 손쉬운 사용(Accessibility) 권한 설정

창의 위치와 크기를 제어하려면 반드시 **손쉬운 사용** 권한이 필요합니다.

### 3.1. 권한 부여 절차

1. **시스템 설정** 열기
2. **개인정보 보호 및 보안** > **손쉬운 사용** 이동
3. 좌측 하단 자물쇠 아이콘 클릭하여 잠금 해제
4. `+` 버튼으로 다음 앱 추가:
   - **GUI 앱 사용 시**: `fWarrange.app`
   - **CLI 스크립트 사용 시**: `Terminal.app` 또는 `iTerm2.app`

### 3.2. 권한 확인

```bash
# CLI로 확인
cd lib/wArrange_core/
swift list_apps.swift
```

정상 출력되면 권한이 올바르게 설정된 것입니다. "권한이 필요합니다" 메시지가 나타나면 위 절차를 다시 확인하세요.

REST API로도 확인 가능합니다:
```bash
curl -s http://localhost:3016/api/v1/status/accessibility | python3 -m json.tool
```

## 3.3. 권한 문제 해결

| 증상                                  | 해결 방법                                               |
| ------------------------------------- | ------------------------------------------------------- |
| 권한 목록에 앱이 있지만 작동하지 않음 | 체크박스 해제 후 재체크, 또는 앱 삭제 후 재등록         |
| 권한 창이 열리지 않음                 | 터미널에서 `tccutil reset Accessibility` 실행 후 재설정 |
| 빌드 후 권한이 풀림                   | 새 빌드마다 바이너리 서명이 달라지므로 재등록 필요      |

## 4. REST API 서버 활성화

기본적으로 REST API 서버는 **비활성** 상태입니다.

1. fWarrange 앱 실행
2. 메뉴바 아이콘 클릭 > **설정**
3. **API** 탭 이동
4. **서버 활성화** 토글 ON
5. 포트 확인 (기본: 3016)

## 다음 단계

* [빠른 시작](03_QuickStart.md)
* [GUI 사용법](04_GUI_Usage.md)
