# fWarrange 사용자 매뉴얼 참조 (Reference Agenda)

## 1. 윈도우 관리 및 데이터 구조 (Window Management & Data Structure)
### 1-1. 레이아웃 데이터 포맷 (YAML Structure Overview)
### 1-2. 활성 창 정보 수집의 원리 (CoreGraphics 기반 수집 로직)
### 1-3. 접근성 제어 기반 윈도우 복원 (AppKit Accessibility API 연동)

## 2. 스마트 창 매칭 알고리즘 (Smart Window Matching)
### 2-1. 매칭 스코어링 시스템 개요 (Scoring System: PID, Title, Size)
### 2-2. 정규식 및 키워드 기반 하위 탐색 (Regex & Keyword Match)
### 2-3. 크기·비율 기반 유사도 매칭 (Similarity & Area Fallback)

## 3. 코어 스크립트 및 CLI 환경 (Core Scripts & CLI Environment)
### 3-1. 레이아웃 저장 스크립트 개요 (`saveWindowsInfo.swift`)
### 3-2. 레이아웃 복원 스크립트 동작 및 옵션 (`setWindows.swift`)
### 3-3. 진단 및 모니터링 스크립트 (`list_apps.swift`, `list_cg.swift`)

## 4. 고급 기능 및 GUI 설정 (Advanced Features & GUI)
### 4-1. 다중 모니터 복원 및 좌표계 이해 (Multi-Monitor Coordinates)
### 4-2. SwiftUI GUI 아키텍처 및 설정 (GUI Integration & macOS App)
### 4-3. 손쉬운 사용 권한 문제 해결 (Accessibility Permissions Troubleshooting)

## 5. REST API 서버 (REST API Server)
### 5-1. 내장 HTTP 서버 아키텍처 (NWListener 기반 서버 구조)
### 5-2. 엔드포인트 레퍼런스 (12개 API 엔드포인트 상세 명세)
### 5-3. 보안 및 접근 제어 (CIDR 화이트리스트, localhost 바인딩)
### 5-4. 자동화 연동 가이드 (curl, Apple Shortcuts, 쉘 스크립트)

## 6. 설정 및 커스터마이징 (Settings & Customization)
### 6-1. 설정 탭 구조 (일반/단축키/복구/API/고급)
### 6-2. 글로벌 단축키 커스터마이징 (5개 단축키 편집)
### 6-3. 테마 및 UI 옵션 (다크 모드, 미니맵 높이, 앱 전환기)
