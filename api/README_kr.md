# fWarrange REST API 문서

## 개요

fWarrange는 macOS 윈도우 창 위치/크기를 저장하고 복구하는 REST API를 제공합니다.

| 서버 구현 | 기술 스택 | 기본 포트 |
|-----------|-----------|-----------|
| macOS 네이티브 앱 | Swift / Network.framework (NWListener) | 3016 |

모든 응답은 `{"status": "ok", "data": ...}` 래퍼 형식을 따릅니다. API는 기본적으로 **비활성화** 상태이며, 앱 설정에서 활성화해야 합니다.

> OpenAPI 3.0 스펙: [openapi.yaml](./openapi.yaml)

---

## 엔드포인트

### 1. 서버 상태 확인

```
GET /
```

**응답**:
```json
{
  "status": "ok",
  "app": "fWarrange",
  "version": "1.08",
  "port": 3016
}
```

---

### 2. 레이아웃 목록 조회

```
GET /api/v1/layouts
```

**응답**:
```json
{
  "status": "ok",
  "data": [
    {
      "name": "myLayout",
      "windowCount": 12,
      "fileDate": "2026-03-17T10:30:00Z"
    }
  ]
}
```

---

### 3. 레이아웃 상세 조회

```
GET /api/v1/layouts/{name}
```

#### 경로 파라미터

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | string | 예 | 레이아웃 이름 (YAML 파일명, 확장자 제외) |

**응답 (200)**: 레이아웃의 전체 창 정보 (name, windowCount, fileDate, windows 배열)

**에러**:

| 상태 코드 | 원인 | 응답 예시 |
|-----------|------|-----------|
| 404 | 레이아웃 없음 | `{"status": "error", "error": "Layout 'unknown' not found"}` |

---

### 4. 레이아웃 이름 변경

```
PUT /api/v1/layouts/{name}
Content-Type: application/json
```

#### 요청 파라미터

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `newName` | string | 예 | 새 레이아웃 이름 |

#### 요청 예시

```json
{
  "newName": "workSetup-v2"
}
```

**응답 (200)**:
```json
{
  "status": "ok",
  "data": {
    "oldName": "workSetup",
    "newName": "workSetup-v2"
  }
}
```

**에러**:

| 상태 코드 | 원인 |
|-----------|------|
| 400 | 잘못된 요청 |
| 404 | 레이아웃 없음 |

---

### 5. 레이아웃 삭제

```
DELETE /api/v1/layouts/{name}
```

**응답 (200)**:
```json
{
  "status": "ok",
  "data": {
    "deleted": "myLayout"
  }
}
```

---

### 6. 전체 레이아웃 삭제

```
DELETE /api/v1/layouts
```

안전을 위해 `X-Confirm-Delete-All: true` 헤더가 필수입니다.

**응답 (200)**:
```json
{
  "status": "ok",
  "data": {
    "deletedCount": 5
  }
}
```

**에러**:

| 상태 코드 | 원인           |
| --------- | -------------- |
| 400       | 확인 헤더 누락 |

---

### 7. 현재 창 캡처 및 저장

```
POST /api/v1/capture
Content-Type: application/json
```

#### 요청 파라미터

| 필드         | 타입     | 필수   | 기본값              | 설명           |
| ------------ | -------- | ------ | ------------------- | -------------- |
| `name`       | string   | 아니오 | 날짜 기반 자동 생성 | 레이아웃 이름  |
| `filterApps` | string[] | 아니오 | 전체 앱             | 캡처할 앱 필터 |

#### 요청 예시

```json
{
  "name": "myLayout",
  "filterApps": ["Safari", "iTerm2"]
}
```

빈 본문 `{}` 전송 시 기본값이 적용됩니다.

**응답 (200)**:
```json
{
  "status": "ok",
  "data": {
    "name": "myLayout",
    "windowCount": 5,
    "windows": [...]
  }
}
```

---

### 8. 레이아웃 복구

```
POST /api/v1/layouts/{name}/restore
Content-Type: application/json
```

점수 기반 창 매칭 알고리즘으로 비동기 처리됩니다. **Accessibility 권한 필수**.

#### 요청 파라미터

| 필드             | 타입    | 필수   | 기본값 | 설명                   |
| ---------------- | ------- | ------ | ------ | ---------------------- |
| `maxRetries`     | integer | 아니오 | 5      | 최대 재시도 횟수       |
| `retryInterval`  | number  | 아니오 | 0.5    | 재시도 간격 (초)       |
| `minimumScore`   | integer | 아니오 | 30     | 최소 매칭 점수 (0-100) |
| `enableParallel` | boolean | 아니오 | true   | 앱별 병렬 복구 활성화  |

#### 요청 예시

```json
{
  "maxRetries": 3,
  "retryInterval": 1.0,
  "minimumScore": 50,
  "enableParallel": true
}
```

**응답 (200)**:
```json
{
  "status": "ok",
  "data": {
    "total": 10,
    "succeeded": 8,
    "failed": 2,
    "results": [
      {
        "app": "Safari",
        "window": "Start Page",
        "matchType": "ID",
        "score": 100,
        "success": true
      }
    ]
  }
}
```

**에러**:

| 상태 코드 | 원인 |
|-----------|------|
| 403 | Accessibility 권한 없음 |
| 404 | 레이아웃 없음 |

---

### 9. 레이아웃에서 특정 창 제거

```
POST /api/v1/layouts/{name}/windows/remove
Content-Type: application/json
```

#### 요청 파라미터

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `windowIds` | integer[] | 예 | 제거할 Window ID 배열 |

#### 요청 예시

```json
{
  "windowIds": [14205, 5032]
}
```

**응답 (200)**:
```json
{
  "status": "ok",
  "data": {
    "layout": "myLayout",
    "removedCount": 2,
    "remainingCount": 10
  }
}
```

---

### 10. 현재 창 목록 조회

```
GET /api/v1/windows/current
```

저장하지 않고 현재 열려 있는 창 목록만 반환합니다.

#### 쿼리 파라미터

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `filterApps` | string | 아니오 | 쉼표 구분 앱 이름 필터 (예: `Safari,iTerm2`) |

**응답 (200)**:
```json
{
  "status": "ok",
  "data": {
    "windowCount": 15,
    "windows": [...]
  }
}
```

---

### 11. 실행 중인 앱 목록

```
GET /api/v1/windows/apps
```

**응답**:
```json
{
  "status": "ok",
  "data": {
    "apps": ["Safari", "iTerm2", "Xcode", "Finder", "Slack"]
  }
}
```

---

### 12. Accessibility 권한 상태

```
GET /api/v1/status/accessibility
```

**응답**:
```json
{
  "status": "ok",
  "data": {
    "granted": true
  }
}
```

---

### 13. 언어 설정 조회

```
GET /api/v1/locale
```

**응답**:
```json
{
  "status": "ok",
  "data": {
    "current": "ko",
    "supported": ["system", "ko", "en", "ja", "ar", "zh-Hans", "zh-Hant", "fr", "de", "hi", "es"]
  }
}
```

---

### 14. 언어 설정 변경

```
PUT /api/v1/locale
Content-Type: application/json
```

앱 재시작이 필요합니다. `"system"`을 사용하면 macOS 시스템 언어를 따릅니다.

#### 요청 파라미터

| 필드       | 타입   | 필수 | 설명                                 |
| ---------- | ------ | ---- | ------------------------------------ |
| `language` | string | 예   | 언어 코드 (예: `ko`, `en`, `system`) |

**응답 (200)**:
```json
{
  "status": "ok",
  "data": {
    "language": "en",
    "restartRequired": true
  }
}
```

---

## 사용 예시

### cURL

```bash
# 헬스 체크
curl http://localhost:3016/

# 레이아웃 목록
curl http://localhost:3016/api/v1/layouts

# 레이아웃 상세
curl http://localhost:3016/api/v1/layouts/myLayout

# 현재 창 캡처 및 저장
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name": "myLayout"}'

# 특정 앱만 캡처
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name": "safariOnly", "filterApps": ["Safari", "iTerm2"]}'

# 레이아웃 복구
curl -X POST http://localhost:3016/api/v1/layouts/myLayout/restore \
  -H "Content-Type: application/json" \
  -d '{}'

# 레이아웃 이름 변경
curl -X PUT http://localhost:3016/api/v1/layouts/myLayout \
  -H "Content-Type: application/json" \
  -d '{"newName": "workSetup"}'

# 레이아웃 삭제
curl -X DELETE http://localhost:3016/api/v1/layouts/myLayout

# 전체 삭제 (확인 헤더 필수)
curl -X DELETE http://localhost:3016/api/v1/layouts \
  -H "X-Confirm-Delete-All: true"

# 현재 창 목록 (저장 안 함)
curl http://localhost:3016/api/v1/windows/current

# 특정 앱 창만 조회
curl "http://localhost:3016/api/v1/windows/current?filterApps=Safari,iTerm2"

# 실행 중인 앱 목록
curl http://localhost:3016/api/v1/windows/apps

# Accessibility 권한 상태
curl http://localhost:3016/api/v1/status/accessibility

# 언어 설정 조회
curl http://localhost:3016/api/v1/locale

# 언어 변경
curl -X PUT http://localhost:3016/api/v1/locale \
  -H "Content-Type: application/json" \
  -d '{"language": "en"}'
```

### Python

```python
import requests

BASE = "http://localhost:3016"

# 레이아웃 목록
layouts = requests.get(f"{BASE}/api/v1/layouts").json()
print(layouts["data"])

# 현재 창 캡처
response = requests.post(
    f"{BASE}/api/v1/capture",
    json={"name": "myLayout"}
)
print(response.json())

# 레이아웃 복구
response = requests.post(
    f"{BASE}/api/v1/layouts/myLayout/restore",
    json={}
)
result = response.json()
print(f"복구: {result['data']['succeeded']}/{result['data']['total']}")
```

---

## 보안

| 항목        | 설명                                                                   |
| ----------- | ---------------------------------------------------------------------- |
| 기본 바인딩 | `127.0.0.1` (localhost only)                                           |
| 기본 상태   | **비활성화** (앱 설정에서 활성화 필요)                                 |
| 외부 접근   | 설정에서 명시적 활성화 필요, `0.0.0.0` 바인딩 + CIDR 화이트리스트 적용 |
| CIDR 기본값 | `192.168.0.0/16` (쉼표로 복수 지정 가능)                               |
| localhost   | CIDR 설정과 무관하게 항상 허용                                         |
| 비허용 IP   | `403 Forbidden` 응답                                                   |

> **주의**: 이 API는 공용 인터넷에 노출해서는 안 됩니다.

---

## 에러 응답 형식

모든 에러는 동일한 형식을 따릅니다:

```json
{
  "status": "error",
  "error": "에러 메시지"
}
```

| 상태 코드 | 일반적인 원인                                   |
| --------- | ----------------------------------------------- |
| 400       | 잘못된 JSON, 필수 파라미터 누락, 확인 헤더 누락 |
| 403       | Accessibility 권한 없음, CIDR 차단              |
| 404       | 레이아웃 없음, 잘못된 경로                      |
| 500       | 서버 내부 오류                                  |

---

## 테스트

```bash
# 자동화 테스트 (14개 항목)
bash _public/api/test-api.sh [port]

# 예시: 포트 지정
bash _public/api/test-api.sh 3017
```

테스트 항목:
1. Health Check (GET `/`)
2. Accessibility 상태 확인
3. 실행 중인 앱 목록
4. 현재 창 목록
5. 현재 창 목록 (앱 필터)
6. 창 캡처 및 저장
7. 레이아웃 목록 조회
8. 레이아웃 상세 조회
9. 레이아웃 이름 변경
10. 변경된 레이아웃 상세 조회
11. 레이아웃 복구
12. 레이아웃 삭제
13. 404 응답 처리
14. 전체 삭제 (헤더 누락 시 400 처리)
