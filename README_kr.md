---
title: fWarrange
description: fWarrange macOS 창 레이아웃 복원 도구 소개 (한국어)
date: 2026-04-08
---
[![en](https://img.shields.io/badge/lang-en-blue.svg)](./README.md)

<img src="./manual/app-icon.png" width="28" height="28"> [EN](https://finfra.kr/product/fWarrange/en/index.html) | [KR](https://finfra.kr/product/fWarrange/kr/index.html)

> **최고의 Mac 창 관리, 간편한 레이아웃 복원.**

macOS 창 관리 및 레이아웃 도구. 단축키 하나로 창 위치와 크기를 저장하고 복원하세요. 멀티 디스플레이 워크플로우에 최적화되어 있습니다.

# 에디션

| 에디션                 | 인터페이스        | 가격                | 설치                                                           | 버전   | 소스             |
| ---------------------- | ----------------- | ------------------- | -------------------------------------------------------------- | ------ | ---------------- |
| **fWarrange** (GUI)    | 풀 GUI + 메뉴바   | 유료 (App Store)    | [App Store](https://finfra.kr/product/fWarrange/kr/index.html) | 최신   | 비공개           |
| **fWarrangeCli** (CLI) | 메뉴바 + REST API | **무료 & 오픈소스** | `brew install finfra/tap/fwarrange-cli`                        | 1.0.2  | [`cli/`](./cli/) |

이 레포지터리는 다음 두 가지 역할을 합니다:
* 유료 GUI 버전 (App Store)의 **사용자 지원 및 문서**
* 무료 CLI 버전의 **오픈소스 코드 저장소**

# 주요 기능

* **단축키 복원** - 저장된 레이아웃을 핫키로 즉시 복원
* **간편 저장** - 현재 창 위치와 크기를 원클릭으로 저장
* **자동 캡처** - 시스템 슬립 또는 화면 잠금 시 자동으로 레이아웃 저장 (v1.0.2+)
* **미니멀 인터페이스** - 메뉴바에서 조용히 동작
* **멀티 디스플레이 지원** - 여러 모니터에 걸친 레이아웃 기억
* **다중 워크스페이스** - 작업별로 다른 레이아웃 저장
* **세밀한 복원** - 앱 배치에 대한 정밀 제어
* **초고속 전환** - 키보드만으로 워크스페이스 전환
* **안정적 동시성** - 스레드 안전 설정 및 작업 처리

# 설치 (fWarrangeCli)

무료 오픈소스 CLI 엔진은 Homebrew로 배포됩니다.

```bash
# 1. tap 추가 및 설치
brew tap finfra/tap
brew install finfra/tap/fwarrange-cli

# 2. 백그라운드 서비스 시작 (로그인 시 자동 시작)
brew services start fwarrange-cli

# 3. REST API 동작 확인
curl http://localhost:3016/api/v2/status
```

## 서비스 관리

```bash
brew services start fwarrange-cli     # 시작 (로그인 시 자동 시작)
brew services stop fwarrange-cli      # 중지
brew services restart fwarrange-cli   # 재시작
brew upgrade fwarrange-cli            # 최신 버전으로 업데이트
```

## 제거

```bash
brew services stop fwarrange-cli      # 먼저 서비스 중지
brew uninstall fwarrange-cli          # 앱 제거
brew untap finfra/tap                 # (선택) tap 제거
```

> 레이아웃 데이터는 제거 후에도 `~/Documents/finfra/fWarrangeData/`에 보존됩니다.
> 모든 데이터를 지우려면 해당 폴더를 직접 삭제하세요.

> **손쉬운 사용 권한 필요.** 최초 실행 시 창 제어를 위해
> *시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용*에서 권한을 허용하세요.

소스 빌드 및 상세 내용은 [`cli/README.md`](./cli/README.md) 참조.

# 시스템 요구사항

* macOS 14.0 이상

# 제품 페이지

| 언어    | 링크                                                                          |
| ------- | ----------------------------------------------------------------------------- |
| English | [fWarrange - Product Page](https://finfra.kr/product/fWarrange/en/index.html) |
| 한국어  | [fWarrange - 제품 페이지](https://finfra.kr/product/fWarrange/kr/index.html)  |

# Finfra 다른 제품

## 서비스
| 제품                           | 설명                                  | 링크                                                                                                                                  |
| ------------------------------ | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Local LLM Agent Coding Support | AI Agent 개발 시스템 및 엔지니어 교육 | [EN](https://finfra.kr/product/LocalLLMAgentCoding/en/index.html) / [KR](https://finfra.kr/product/LocalLLMAgentCoding/kr/index.html) |
| Mac App Development            | macOS 앱 개발, 컨설팅 및 교육         | [EN](https://finfra.kr/product/MacAppDev/en/index.html) / [KR](https://finfra.kr/product/MacAppDev/kr/index.html)                     |

## Mac OS 앱
| 제품         | 설명                                    | 링크                                                                                                                    |
| ------------ | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| fSnippet     | 강력한 텍스트 확장 및 스니펫 도구       | [EN](https://finfra.kr/product/fSnippet/en/index.html) / [KR](https://finfra.kr/product/fSnippet/kr/index.html)         |
| fBanner      | 클립보드에서 배너 이미지로, 즉시 변환   | [EN](https://finfra.kr/product/fBanner/en/index.html) / [KR](https://finfra.kr/product/fBanner/kr/index.html)           |
| fBoard       | 나만의 개인 스크린 보드                 | [EN](https://finfra.kr/product/fBoard/en/index.html) / [KR](https://finfra.kr/product/fBoard/kr/index.html)             |
| fQRGen       | 클립보드에서 QR 코드로, 즉시 생성       | [EN](https://finfra.kr/product/fQRGen/en/index.html) / [KR](https://finfra.kr/product/fQRGen/kr/index.html)             |
| fGoogleSheet | Mac용 가장 빠른 Google Sheets 메뉴바 앱 | [EN](https://finfra.kr/product/fGoogleSheet/en/index.html) / [KR](https://finfra.kr/product/fGoogleSheet/kr/index.html) |

# 문서

| 문서                                 | 설명                              |
| ------------------------------------ | --------------------------------- |
| [매뉴얼](./manual/)                  | 사용자 매뉴얼 (KR/EN)             |
| [REST API](./api/)                   | REST API 레퍼런스 및 OpenAPI 명세 |
| [MCP 서버](./mcp/)                   | Model Context Protocol 서버       |
| [Claude Code 스킬](./agents/claude/) | Claude Code 플러그인              |
| [다국어 리소스](./localization/)     | 다국어 문자열 리소스              |

# 커뮤니티 및 지원

## 이슈
* [GitHub Issues](https://github.com/Finfra/fWarrange_public/issues)

## 게시판 (English)
| 카테고리 | 링크                                                                    |
| -------- | ----------------------------------------------------------------------- |
| Notice   | [fWarrange Notice](https://finfra.kr/w1/category/fwarrange-notice/)     |
| Guide    | [fWarrange Guide](https://finfra.kr/w1/category/fwarrange-guide/)       |
| QnA      | [fWarrange QnA](https://finfra.kr/w1/category/fwarrange-qna/)           |
| Feedback | [fWarrange Feedback](https://finfra.kr/w1/category/fwarrange-feedback/) |

## 게시판 (한국어)
| 카테고리 | 링크                                                                     |
| -------- | ------------------------------------------------------------------------ |
| 공지     | [fWarrange 공지](https://finfra.kr/w1/category/fwarrange-notice-kr/)     |
| 사용법   | [fWarrange 사용법](https://finfra.kr/w1/category/fwarrange-guide-kr/)    |
| QnA      | [fWarrange QnA](https://finfra.kr/w1/category/fwarrange-qna-kr/)         |
| 피드백   | [fWarrange 피드백](https://finfra.kr/w1/category/fwarrange-feedback-kr/) |

# 라이선스

Copyright (c) finfra.kr. All rights reserved.
