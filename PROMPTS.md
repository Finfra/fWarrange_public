---
name: PROMPTS
description: fWarrangeCli(_public) 프로젝트 프롬프트 모음
date: 2026.06.19
---

# Info
## 자주쓰는 프롬프트 모음

### 빌드·배포
* /run
* /run kill
* /deploy brew local
* brew version, cliApp version(VERSION 파일), paidApp version, xcode 버전 모두 맞춰줘.

### jma 사용자 테스트
* jma의 git 브랜치·마지막 커밋이 맞고 stage 없으면 jma에서 run, 설정창 스크린샷 찍어서 playground로 sync하고 검토해줘.
* jma에서 설정창의 모든 탭 스크린샷 작업 진행해줘.
* jma에서 푸시하고 jm4에서 풀 받고, 이슈 끝까지 해결. before·after 스크린샷 포함 레포트 생성해줘.
* jma에서 클린 테스트.

### 개발 주기
* /dev Issue{{이슈번호}}
* /issue-fix Issue{{이슈번호}}
* /issue-closer
* 보류된 이슈 중 지금 작업할 만한 것 1개만 추천해줘.
* {{증상}}. 원인 찾아줘. debug_TECH.md와 consultant-m 호출해서 분석.
* noteForHuman.md에 노트만 해주고 이슈는 해결 처리.
* paidApp 수정이 필요하면 paidApp 이슈 파일에 등록 후 fpm-do 16 {{이슈번호}} 해결.

### 문서·Git
* 설계 문서·코드·이슈 확인해서 README.md / README_kr.md 업데이트.
* 커밋하고 push, brew update
* /uc

# History
## 2026.09.27
* 복사용 평문 형식으로 전환 — 백틱·부연 설명 제거, 한 줄 한 프롬프트, 변수 자리는 fSnippet 플레이스홀더 {{필드명}} 형식
* 세션 히스토리 기반 재정리 — jma 사용자 테스트·원인 분석·스크린샷 레포트 추가. 일회성 항목(VERSION 파일 형식 결정, os 시작 이슈 질문, pairApp push·README 비교, `save point update` → `/uc`) 제거

## 2026.06.19
* 초기 생성 — 채팅 히스토리 기반 프롬프트 수집. 메인 `fWarrange/PROMPTS.md` 양식 준수, cliApp(_public) 컨텍스트로 조정.
