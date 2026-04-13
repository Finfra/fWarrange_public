---
name: apiTest_plan
description: openapi_v1.yaml 기반 API 테스트 스크립트 생성 계획
date: 2026-04-07
---

# 개요

`api/openapi_v1.yaml` 분석 결과 총 16개 엔드포인트 → 테스트 스크립트로 매핑.

* 파일명 규칙: `{00-99}.{내역}.sh`
* 스크립트 위치: `cli/_tool/apiTest/`
* Base URL: `http://localhost:3016`
* API Root: `/api/v1`

# 실행 방법

```bash
# 정상 테스트 전체 실행
source cli/_tool/apiTestDo.sh

# 특정 번호만 실행
source cli/_tool/apiTestDo.sh 0      # 00.health
source cli/_tool/apiTestDo.sh 15     # 15.cli-status

# 에러 테스트 전체 실행
source cli/_tool/apiTestDo.sh E

# 에러 테스트 개별 실행
source cli/_tool/apiTestDo.sh E01    # E01.layout-detail-404

# 정상 + 에러 전체 실행
source cli/_tool/apiTestDo.sh all
```

# 스크립트 목록

| 번호 | 파일명                           | Method | Endpoint                                | Tag     |
| ---: | :------------------------------- | :----- | :-------------------------------------- | :------ |
|   00 | `00.health.sh`                   | GET    | `/` (`/api/v1/health`)                  | Status   |
|   01 | `01.settings.sh`                 | GET    | `/api/v1/settings`                      | Settings |
|   02 | `02.layouts-list.sh`             | GET    | `/api/v1/layouts`                       | Layouts  |
|   03 | `03.layout-detail.sh`            | GET    | `/api/v1/layouts/{name}`                | Layouts |
|   04 | `04.layout-rename.sh`            | PUT    | `/api/v1/layouts/{name}`                | Layouts |
|   05 | `05.layout-delete.sh`            | DELETE | `/api/v1/layouts/{name}`                | Layouts |
|   06 | `06.layouts-delete-all.sh`       | DELETE | `/api/v1/layouts`                       | Layouts |
|   07 | `07.capture.sh`                  | POST   | `/api/v1/capture`                       | Capture |
|   08 | `08.restore.sh`                  | POST   | `/api/v1/layouts/{name}/restore`        | Restore |
|   09 | `09.layout-remove-windows.sh`    | POST   | `/api/v1/layouts/{name}/windows/remove` | Layouts |
|   10 | `10.windows-current.sh`          | GET    | `/api/v1/windows/current`               | Windows |
|   11 | `11.windows-apps.sh`             | GET    | `/api/v1/windows/apps`                  | Windows |
|   14 | `14.ui-state.sh`                 | PUT    | `/api/v1/ui/state`                      | UI      |
|   15 | `15.cli-status.sh`               | GET    | `/api/v1/cli/status`                    | CLI     |
|   16 | `16.cli-version.sh`              | GET    | `/api/v1/cli/version`                   | CLI     |
|   17 | `17.cli-quit.sh`                 | POST   | `/api/v1/cli/quit`                      | CLI     |
|   18 | `18.accessibility.sh`            | GET    | `/api/v1/status/accessibility`          | System  |

# v2 스크립트 목록

| 번호 | 파일명                                    | Method | Endpoint                                    | Tag      |
| ---: | :---------------------------------------- | :----- | :------------------------------------------ | :------- |
|   20 | `20.v2-settings.sh`                       | GET    | `/api/v2/settings`                          | Settings |
|   21 | `21.v2-settings-general.sh`               | GET    | `/api/v2/settings/general`                  | Settings |
|   22 | `22.v2-settings-restore.sh`               | GET    | `/api/v2/settings/restore`                  | Settings |
|   23 | `23.v2-settings-api.sh`                   | GET    | `/api/v2/settings/api`                      | Settings |
|   24 | `24.v2-settings-advanced.sh`              | GET    | `/api/v2/settings/advanced`                 | Settings |
|   25 | `25.v2-settings-excluded-apps.sh`         | GET    | `/api/v2/settings/restore/excluded-apps`    | Settings |
|   26 | `26.v2-settings-shortcuts.sh`             | GET    | `/api/v2/settings/shortcuts`                | Shortcuts |
|   27 | `27.v2-settings-general-patch.sh`         | PATCH  | `/api/v2/settings/general`                  | Settings |
|   28 | `28.v2-settings-restore-patch.sh`         | PATCH  | `/api/v2/settings/restore`                  | Settings |
|   29 | `29.v2-settings-advanced-patch.sh`        | PATCH  | `/api/v2/settings/advanced`                 | Settings |
|   30 | `30.v2-settings-patch.sh`                 | PATCH  | `/api/v2/settings`                          | Settings |
|   31 | `31.v2-settings-api-patch.sh`             | PATCH  | `/api/v2/settings/api`                      | Settings |
|   32 | `32.v2-excluded-apps-put.sh`              | PUT    | `/api/v2/settings/restore/excluded-apps`    | Settings |
|   33 | `33.v2-excluded-apps-post.sh`             | POST   | `/api/v2/settings/restore/excluded-apps`    | Settings |
|   34 | `34.v2-excluded-apps-delete.sh`           | DELETE | `/api/v2/settings/restore/excluded-apps`    | Settings |
|   35 | `35.v2-excluded-apps-reset.sh`            | POST   | `/api/v2/settings/restore/excluded-apps/reset` | Settings |
|   36 | `36.v2-shortcuts-put.sh`                  | PUT    | `/api/v2/settings/shortcuts`                | Shortcuts |
|   37 | `37.v2-factory-reset.sh`                  | POST   | `/api/v2/settings/factory-reset` (FORCE=1)  | Settings |

> v2 엔드포인트는 `openapi_v2.yaml` 기준 **모두 커버** (GET/PATCH/PUT/POST/DELETE).
> 37번은 파괴적이므로 `FORCE=1` 환경변수 설정 시에만 실행됨.

# 에러 테스트 (E prefix) - v2 추가

| 번호 | 파일명                                  | 기대 응답 | 검증 내용                        |
| :--- | :------------------------------------- | :-------- | :------------------------------- |
| E08  | `E08.v2-factory-reset-no-confirm.sh`  | 400       | X-Confirm 헤더 없이 초기화      |
| E09  | `E09.v2-settings-api-invalid-port.sh` | 400       | 범위 초과 포트(65536) 설정 시도 |

# 스크립트 상세

## 0. health

```bash
# 서버 루트 (/) 및 versioned health (/api/v1/health) 테스트
echo "--- GET / (서버 루트) ---"
curl -s --connect-timeout 3 http://localhost:3016/ | jq .
echo "--- GET /api/v1/health (versioned) ---"
curl -s --connect-timeout 3 "$BASE/health" | jq .
```

## 1. settings

```bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 "$BASE/settings" | jq .
```

## 2. layouts-list

```bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 "$BASE/layouts" | jq .
```

## 3. layout-detail

```bash
# Usage: ./03.layout-detail.sh [layout_name]
BASE="http://localhost:3016/api/v1"
NAME=${1:-testCapture}
curl -s --connect-timeout 3 "$BASE/layouts/$NAME" | jq .
```

## 4. layout-rename

```bash
# Usage: ./04.layout-rename.sh <old_name> <new_name>
BASE="http://localhost:3016/api/v1"
OLD=${1:?old name required}
NEW=${2:?new name required}
curl -s --connect-timeout 3 -X PUT "$BASE/layouts/$OLD" \
  -H "Content-Type: application/json" \
  -d "{\"newName\": \"$NEW\"}" | jq .
```

## 5. layout-delete

```bash
# Usage: ./05.layout-delete.sh <layout_name>
BASE="http://localhost:3016/api/v1"
NAME=${1:?layout name required}
curl -s --connect-timeout 3 -X DELETE "$BASE/layouts/$NAME" | jq .
```

## 6. layouts-delete-all

```bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 -X DELETE "$BASE/layouts" \
  -H "X-Confirm-Delete-All: true" | jq .
```

## 7. capture

```bash
# Usage: ./07.capture.sh [layout_name] [filterApps]
# filterApps 예: "Safari,iTerm2"
BASE="http://localhost:3016/api/v1"
NAME=${1:-testCapture}
FILTER=${2:-}

if [ -n "$FILTER" ]; then
  echo "--- capture with filterApps: $FILTER ---"
  curl -s --connect-timeout 3 -X POST "$BASE/capture" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$NAME\", \"filterApps\": [$(echo "$FILTER" | sed 's/[^,]*/"&"/g')]}" | jq .
else
  curl -s --connect-timeout 3 -X POST "$BASE/capture" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$NAME\"}" | jq .
fi
```

## 8. restore

```bash
# Usage: ./08.restore.sh [layout_name]
BASE="http://localhost:3016/api/v1"
NAME=${1:-testCapture}
curl -s --connect-timeout 3 -X POST "$BASE/layouts/$NAME/restore" \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
```

## 9. layout-remove-windows

```bash
# Usage: ./09.layout-remove-windows.sh <layout_name> <id1> [id2] ...
BASE="http://localhost:3016/api/v1"
NAME=${1:?layout name required}; shift
IDS=$(printf '%s,' "$@" | sed 's/,$//')
curl -s --connect-timeout 3 -X POST "$BASE/layouts/$NAME/windows/remove" \
  -H "Content-Type: application/json" \
  -d "{\"windowIds\": [$IDS]}" | jq .
```

## 10. windows-current

```bash
# Usage: ./10.windows-current.sh [filterApps]
BASE="http://localhost:3016/api/v1"
FILTER=${1:-}
URL="$BASE/windows/current"
[ -n "$FILTER" ] && URL="$URL?filterApps=$FILTER"
curl -s --connect-timeout 3 "$URL" | jq .
```

## 11. windows-apps

```bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 "$BASE/windows/apps" | jq .
```

## 14. ui-state

```bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 -X PUT "$BASE/ui/state" \
  -H "Content-Type: application/json" \
  -d '{"hideWindows": true}' | jq .
```

## 15. cli-status

```bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 "$BASE/cli/status" | jq .
```

## 16. cli-version

```bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 "$BASE/cli/version" | jq .
```

## 17. cli-quit

```bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 -X POST "$BASE/cli/quit" \
  -H "X-Confirm: true" | jq .
```

## 18. accessibility

```bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 "$BASE/status/accessibility" | jq .
```

# CLI 미대응 엔드포인트

| 엔드포인트       | Method | 사유                                      |
| :--------------- | :----- | :---------------------------------------- |
| `PUT /ui/state`  | PUT    | GUI 자동화 전용 — CLI 커맨드로 노출 불필요 |

# 에러 테스트 (E prefix)

에러가 **나야만 정상**인 테스트. 서버의 에러 핸들링 검증용.

| 번호 | 파일명                            | 기대 응답 | 검증 내용                    |
| :--- | :-------------------------------- | :-------- | :--------------------------- |
| E01  | `E01.layout-detail-404.sh`        | 404       | 존재하지 않는 레이아웃 조회  |
| E02  | `E02.layout-rename-no-body.sh`    | 400       | body 없이 rename 요청        |
| E03  | `E03.layout-delete-404.sh`        | 404       | 존재하지 않는 레이아웃 삭제  |
| E04  | `E04.delete-all-no-confirm.sh`    | 400       | 확인 헤더 없이 전체 삭제     |
| E05  | `E05.restore-404.sh`              | 404       | 존재하지 않는 레이아웃 복구  |
| E06  | `E06.cli-quit-no-confirm.sh`      | 400       | 확인 헤더 없이 종료          |
| E07  | `E07.invalid-endpoint.sh`         | error     | 존재하지 않는 엔드포인트     |

# 실행 순서 권장

* **안전한 읽기 전용**: 0, 1, 2, 3, 10, 11, 15, 16, 18
* **상태 변경 (주의)**: 4, 7, 8, 14
* **삭제 (위험)**: 5, 6, 9
* **앱 종료 (최후)**: 17

# 파일 구조

```
cli/_tool/
├── apiTestDo.sh              # 실행기 (전체/개별)
└── apiTest/
    ├── apiTest_plan.md        # 이 문서
    ├── 00.health.sh
    ├── 01.settings.sh
    ├── ...
    ├── 18.accessibility.sh
    ├── E01.layout-detail-404.sh
    ├── ...
    └── E07.invalid-endpoint.sh
```
