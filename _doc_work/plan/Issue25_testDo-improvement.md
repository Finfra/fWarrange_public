---
name: Issue25_testDo-improvement
description: apiTestDo.sh / cmdTestDo.sh 개선 계획 — run.sh 사전 실행, 로그 확인, 결과 저장
date: 2026-04-14
---

# 문제 정의

`apiTestDo.sh`와 `cmdTestDo.sh` 실행 시 아래 3가지 절차가 누락되어 있음.

| # | 문제 | 영향 |
|---|------|------|
| 1 | **run.sh 미실행** | 최신 빌드 미반영 상태로 테스트 → 결과 신뢰성 저하 |
| 2 | **로그 미확인** | 테스트 통과해도 앱 내부 에러/경고를 놓침 |
| 3 | **결과 미저장** | 테스트 이력 없음 → 회귀 비교 불가 |

# 해결 방안

## A. run.sh 사전 실행 통합

`apiTestDo.sh` / `cmdTestDo.sh`에 `--run` 옵션 또는 `pre-flight` 단계 추가.
- 실행 시 `cli/_tool/run.sh` 호출 → 빌드·배포·실행·health check 수행
- 기존 인자 호환 유지 (`all`, `v1`, `v2`, `E`, `E01` 등)

**변경 위치**: `apiTestDo.sh`, `cmdTestDo.sh` 상단 `pre_flight()` 함수 추가

```bash
pre_flight() {
    echo "=== Pre-flight: run.sh 실행 ==="
    bash "$(dirname "$_SELF")/run.sh"
}
```

## B. 로그 확인 (post-test log check)

테스트 완료 후 로그에서 ERROR/CRITICAL 항목을 자동 추출하여 출력.

**로그 경로**: `~/Documents/finfra/fWarrangeData/logs/wlog.log`

```bash
check_logs() {
    local LOG="$HOME/Documents/finfra/fWarrangeData/logs/wlog.log"
    echo "=== Post-test Log Check ==="
    if [ -f "$LOG" ]; then
        local errors=$(grep -E "❌|CRITICAL|ERROR" "$LOG" | tail -20)
        if [ -n "$errors" ]; then
            echo "⚠️  에러/크리티컬 로그 발견:"
            echo "$errors"
        else
            echo "✅ 에러 없음"
        fi
    else
        echo "로그 파일 없음: $LOG"
    fi
}
```

## C. 결과 저장 (_doc_work/report)

테스트 완료 후 결과를 `_doc_work/report/` 폴더에 마크다운으로 자동 저장.

**파일명**: `{YYYYMMDD}_{HHMMSS}_{test-type}_report.md`
- ex) `20260414_001200_apiTest_report.md`

**내용 구조**:
```markdown
---
name: {파일명}
description: {test-type} 테스트 결과 리포트
date: {YYYY-MM-DD}
---

# 개요
- 실행일시: ...
- 앱 버전: ...
- 업타임: ...

# 테스트 결과
...

# 로그 요약
...
```

# 구현 명세

## 수정 대상 파일
- `cli/_tool/apiTestDo.sh` — pre_flight, check_logs, save_report 추가
- `cli/_tool/cmdTestDo.sh` — 동일하게 적용

## 새 옵션 구조

```
apiTestDo.sh [--run] [--log] [--report] [args...]
cmdTestDo.sh [--run] [--log] [--report] [args...]
```

- `--run`: 테스트 전 run.sh 실행 (빌드+배포+시작)
- `--log`: 테스트 후 wlog.log에서 에러 확인
- `--report`: 결과를 _doc_work/report에 저장

## 호환성
- 기존 인자(`all`, `v1`, `v2`, `E`, `E01` 등)는 그대로 유지
- 새 옵션은 선택적(opt-in) — 기존 스크립트 동작 변경 없음

# 구현 순서
1. `_doc_work/tasks/` Task 파일 생성
2. Issue.md에 Issue25 등록
3. `apiTestDo.sh` 수정 (pre_flight, check_logs, save_report)
4. `cmdTestDo.sh` 수정 (동일)
5. 전체 테스트 실행 (`--run --log --report all`)
6. `_doc_work/report/` 결과 저장 확인
