---
title: fWarrangeCli 설치
description: fWarrangeCli 설치 · 손쉬운 사용 권한 · REST API 확인 (한국어)
date: 2026.10.08
---
# 설치 및 권한 설정

## 1. 시스템 요구사항

| 항목  | 요구                                 |
| ----- | ------------------------------------ |
| macOS | 14.0 이상                            |
| 설치  | Homebrew                             |
| 권한  | 손쉬운 사용(Accessibility) 권한 필수 |
| 빌드  | Xcode 15.0 이상 (소스 빌드 시만)     |

## 2. Homebrew 로 설치 (권장)

```bash
brew tap finfra/tap
brew install finfra/tap/fwarrange-cli
brew services start fwarrange-cli     # 시작 + 로그인 시 자동 시작
```

앱은 `/opt/homebrew/opt/fwarrange-cli/fWarrangeCli.app` 에 설치되고, 실행되면 메뉴바에 아이콘이 나타납니다.

| 작업     | 명령                                                                |
| -------- | ------------------------------------------------------------------- |
| 중지     | `brew services stop fwarrange-cli`                                  |
| 재시작   | `brew services restart fwarrange-cli`                               |
| 업데이트 | `brew upgrade fwarrange-cli`                                        |
| 삭제     | `brew services stop fwarrange-cli` → `brew uninstall fwarrange-cli` |

삭제해도 `~/Documents/finfra/fWarrangeData/` 의 레이아웃·설정은 남습니다. 완전히 지우려면 이 폴더를 직접 삭제하세요.

## 3. 소스에서 빌드

```bash
git clone https://github.com/Finfra/fWarrange_public.git
cd fWarrange_public/cli
xcodebuild -scheme fWarrangeCli -configuration Release build
```

결과물: `~/Library/Developer/Xcode/DerivedData/fWarrangeCli-*/Build/Products/Release/fWarrangeCli.app`

## 4. 손쉬운 사용 권한

창의 위치·크기를 바꾸려면 **fWarrangeCli** 에 손쉬운 사용 권한이 있어야 합니다.

1. **시스템 설정** › **개인정보 보호 및 보안** › **손쉬운 사용**
2. **fWarrangeCli** 를 켭니다 (없으면 `+` 로 `/opt/homebrew/opt/fwarrange-cli/fWarrangeCli.app` 추가)
3. 확인: `curl -s http://localhost:3016/api/v2/status/accessibility`

| 증상                               | 해결                                                       |
| ---------------------------------- | ---------------------------------------------------------- |
| 목록에 켜져 있는데 창이 안 움직임  | 끄고 다시 켜거나, `-` 로 지운 뒤 다시 추가                 |
| 소스 빌드 후 권한이 풀림           | 빌드마다 서명이 달라져 다시 등록해야 함                    |
| 단축키는 반응하는데 창이 안 움직임 | 권한이 꺼진 상태 — 위 1~2 를 다시 하고 fWarrangeCli 재시작 |

## 5. REST API 확인

REST 서버는 **기본으로 켜져 있습니다**(포트 3016).

```bash
curl -s http://localhost:3016/api/v2/status
```

`"status" : "ok"` 가 나오면 정상입니다. 서버 끄기 · 포트 · 외부 접속 허용은 `_config.yml` 에서 바꿉니다 — [메뉴바 사용법 › 설정 파일](04_MenuBar_Usage.md#설정-파일-_configyml).

## 6. (선택) GUI 래퍼 fWarrange

레이아웃 목록 · 미니맵 · 설정 창을 GUI 로 쓰려면 App Store 앱 **fWarrange** 를 추가로 설치합니다. fWarrange 는 이 fWarrangeCli 를 통해 동작합니다 — [fWarrange 안내 페이지](https://finfra.kr/product/fWarrange/kr/index.html).

## 다음 단계

* [빠른 시작](03_QuickStart.md)
* [메뉴바 사용법](04_MenuBar_Usage.md)
