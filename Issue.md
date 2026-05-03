---
name: Issue
description: fWarrangeCli 이슈 관리
date: 2026-04-07
---
# Issue Management
* Issue HWM: 68
* Save Point: 2026-04-27 (close Issue55/57/56 — API v2 문서 정합성 감사)
  - 251036a (2026-05-03) - Feat(MenuBar): Issue68 — Quit All
  - 1b9fec7 (2026-05-02) - Fix(REST): Issue67 — pause GET / 버그 수정
  - 06939f9 (2026-05-02) - Docs: Close Issue66
  - f5fa7aa (2026-05-02) - Docs: Close Issue66
  - 4e11b5d (2026-05-02) - Feat(MenuBar): Close Issue62/63/64
  - 1d9a438 (2026-05-02) - Docs: Register Issue63
  - 732348b (2026-05-02) - Chore: launchAtLogin 기본 true(Issue228) + 문서·.gitignore 정리
  - 2a219fa (2026-05-01) - Fix(CLI): Issue60 — cmdTest v2 정합화 + delete-all/quit confirm 헤더 버그 수정


# 🤔 결정사항
* _doc_design/paid_cli_protocol.md 기준 진행(paidApp앱과 연동)
* _doc_design/menuBar_enhance.md 기준 진행(메뉴바)

# 🌱 이슈후보

# 🚧 진행중

# 📕 중요

# 📙 일반
# 📗 선택

# ✅ 완료
## Issue68: [Refactor] 메뉴바 Quit → paidApp 통합 종료 (Quit All) (등록: 2026-05-03) (✅ 완료, 251036a) ✅
* 목적: cliApp 메뉴바 Quit 클릭 시 cliApp만 종료되고 paidApp(`fWarrange`)이 잔존하는 현상(2026-05-03 재현 확인). paidApp 측 Cmd+Q는 정상 동작하므로 본 이슈는 **cliApp 측 작업**임. paidApp 레포 Issue232에서 paidApp `MenuBarExtra` 제거 후 cliApp 메뉴바가 유일한 paidApp 종료 트리거가 되어야 하나 미연결 상태.
* 상세:
    - 현상: cliApp 메뉴바 → Quit → cliApp 프로세스만 종료, paidApp(`/Applications/_nowage_app/fWarrange.app`) 프로세스는 좀비처럼 잔존
    - 관련 SSOT: 상위 paidApp 레포 `_doc_design/paid_cli_protocol.md` §3.3 "Quit All 시퀀스" — cliApp 트리거 흐름 미반영
    - 관련: paidApp 레포 Issue232 (paidApp 메뉴바 제거, 2026-05-03 완료)
* 구현 명세:
    - `MenuBarManager.swift` 또는 `MenuBarView.swift` Quit 액션 핸들러에서 paidApp 종료 신호 발송
    - 옵션 A: paidApp URL Scheme `fwarrange://command?action=quit` open
    - 옵션 B: paidApp pid 검색 후 `kill -TERM`
    - 옵션 C: REST `/api/v2/paidapp/quit` 신규 엔드포인트 추가 후 paidApp이 self-terminate
    - 옵션 결정 후 paidApp 레포 SSOT `_doc_design/paid_cli_protocol.md` §3.3 갱신 필요 (양 레포 동기 PR)
    - 검증: cliApp 메뉴바 Quit → paidApp + cliApp 모두 종료, ps에서 잔존 0개 확인


> 종결된 이슈는 [`z_old/old_issue.md`](z_old/old_issue.md)로 이관됨.

# ⏸️ 보류

# 🚫 취소

> 종결된 이슈는 [`z_old/old_issue.md`](z_old/old_issue.md)로 이관됨.

# 📜 참고
