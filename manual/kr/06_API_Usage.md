# REST API 사용법

fWarrange는 내장 HTTP 서버를 통해 REST API를 제공합니다. curl, Apple Shortcuts, 자동화 스크립트 등에서 fWarrange의 모든 핵심 기능을 원격으로 호출할 수 있습니다.

## 서버 정보

| 항목 | 값 |
|------|-----|
| 기본 주소 | `http://localhost:3016` |
| 프레임워크 | Apple Network.framework (NWListener) |
| 외부 의존성 | 없음 (순수 Swift 구현) |
| Content-Type | `application/json; charset=utf-8` |

## 서버 활성화

1. fWarrange 앱 실행
2. 메뉴바 아이콘 > 설정 > **API** 탭
3. **서버 활성화** 토글 ON
4. 포트 확인 (기본: 3016)

## 응답 형식

모든 응답은 JSON 형식입니다:

```json
// 성공
{"status": "ok", "data": {...}}

// 에러
{"status": "error", "error": "에러 메시지"}
```

## 엔드포인트 레퍼런스 (14개)

### 상태 확인

#### GET / - Health Check

```bash
curl -s http://localhost:3016/ | python3 -m json.tool
```

응답:
```json
{
    "status": "ok",
    "app": "fWarrange",
    "version": "1.08",
    "port": 3016
}
```

### 레이아웃 관리

#### GET /api/v1/layouts - 레이아웃 목록

```bash
curl -s http://localhost:3016/api/v1/layouts | python3 -m json.tool
```

응답:
```json
{
    "status": "ok",
    "data": [
        {"name": "myLayout", "windowCount": 12, "fileDate": "2026-03-17T10:30:00Z"},
        {"name": "workSetup", "windowCount": 8, "fileDate": "2026-03-16T09:00:00Z"}
    ]
}
```

#### GET /api/v1/layouts/{name} - 레이아웃 상세

```bash
curl -s http://localhost:3016/api/v1/layouts/myLayout | python3 -m json.tool
```

#### POST /api/v1/capture - 창 캡처 후 저장

```bash
# 기본 (자동 이름)
curl -s -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" | python3 -m json.tool

# 이름 지정
curl -s -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"myLayout"}' | python3 -m json.tool

# 특정 앱만 캡처
curl -s -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"webDev", "filterApps":["Safari","iTerm2"]}' | python3 -m json.tool
```

요청 본문:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| name | string | 아니오 | 레이아웃 이름 (생략 시 날짜 자동 생성) |
| filterApps | string[] | 아니오 | 캡처할 앱 목록 (생략 시 전체) |

#### POST /api/v1/layouts/{name}/restore - 레이아웃 복원

```bash
# 기본 설정으로 복원
curl -s -X POST http://localhost:3016/api/v1/layouts/myLayout/restore | python3 -m json.tool

# 커스텀 설정
curl -s -X POST http://localhost:3016/api/v1/layouts/myLayout/restore \
  -H "Content-Type: application/json" \
  -d '{"maxRetries":3, "retryInterval":1.0, "minimumScore":50, "enableParallel":true}' | python3 -m json.tool
```

요청 본문 (선택):

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| maxRetries | int | 5 | 최대 재시도 횟수 |
| retryInterval | double | 0.5 | 재시도 간격 (초) |
| minimumScore | int | 30 | 최소 매칭 점수 (0-100) |
| enableParallel | bool | true | 앱별 병렬 복원 |

응답:
```json
{
    "status": "ok",
    "data": {
        "total": 12,
        "succeeded": 11,
        "failed": 1,
        "results": [
            {"app": "Safari", "window": "Google", "matchType": "ID", "score": 100, "success": true},
            {"app": "iTerm2", "window": "~ - zsh", "matchType": "Title(Exact)", "score": 90, "success": true}
        ]
    }
}
```

#### PUT /api/v1/layouts/{name} - 이름 변경

```bash
curl -s -X PUT http://localhost:3016/api/v1/layouts/myLayout \
  -H "Content-Type: application/json" \
  -d '{"newName":"dailySetup"}' | python3 -m json.tool
```

#### DELETE /api/v1/layouts/{name} - 레이아웃 삭제

```bash
curl -s -X DELETE http://localhost:3016/api/v1/layouts/myLayout | python3 -m json.tool
```

#### DELETE /api/v1/layouts - 전체 레이아웃 삭제

안전을 위해 확인 헤더가 필수입니다:

```bash
curl -s -X DELETE http://localhost:3016/api/v1/layouts \
  -H "X-Confirm-Delete-All: true" | python3 -m json.tool
```

#### POST /api/v1/layouts/{name}/windows/remove - 특정 창 제거

```bash
curl -s -X POST http://localhost:3016/api/v1/layouts/myLayout/windows/remove \
  -H "Content-Type: application/json" \
  -d '{"windowIds":[14205, 5032]}' | python3 -m json.tool
```

### 윈도우 조회

#### GET /api/v1/windows/current - 현재 창 목록 (저장 없이)

```bash
# 전체 창
curl -s http://localhost:3016/api/v1/windows/current | python3 -m json.tool

# 특정 앱만
curl -s "http://localhost:3016/api/v1/windows/current?filterApps=Safari,iTerm2" | python3 -m json.tool
```

#### GET /api/v1/windows/apps - 실행 중 앱 목록

```bash
curl -s http://localhost:3016/api/v1/windows/apps | python3 -m json.tool
```

### 시스템 상태

#### GET /api/v1/status/accessibility - 손쉬운 사용 권한 상태

```bash
curl -s http://localhost:3016/api/v1/status/accessibility | python3 -m json.tool
```

#### GET /api/v1/locale - 현재 언어 설정

```bash
curl -s http://localhost:3016/api/v1/locale | python3 -m json.tool
```

응답:
```json
{
    "status": "ok",
    "data": {
        "current": "ko",
        "supported": ["system", "ko", "en", "ja", "ar", "zh-Hans", "zh-Hant", "fr", "de", "hi", "es"]
    }
}
```

#### PUT /api/v1/locale - 언어 변경

```bash
curl -s -X PUT http://localhost:3016/api/v1/locale \
  -H "Content-Type: application/json" \
  -d '{"language":"en"}' | python3 -m json.tool
```

> 언어 변경 후 앱 재시작이 필요합니다.

## 보안

### 기본 보안 정책

| 항목 | 설정 |
|------|------|
| 기본 바인딩 | `127.0.0.1` (localhost만 접근 가능) |
| 기본 상태 | 비활성 (수동 활성화 필요) |
| 인터넷 노출 | 금지 (로컬/LAN 전용) |

### 외부 접속 허용 시

1. 설정 > API 탭 > **외부 접속** 활성화
2. CIDR 화이트리스트 설정 (기본: `192.168.0.0/16`)
3. 서버가 `0.0.0.0`으로 바인딩됨
4. 허용 CIDR에 맞지 않는 IP는 **403 Forbidden** 응답
5. `127.0.0.1`, `::1`은 항상 허용

### CIDR 설정 예시

```
192.168.0.0/16          # 일반 가정/사무실 LAN
10.0.0.0/8              # VPN 대역
192.168.1.0/24,10.0.0.0/8  # 복수 대역 (쉼표 구분)
```

## Apple Shortcuts 연동

macOS Shortcuts 앱에서 fWarrange API를 호출하여 자동화할 수 있습니다:

1. Shortcuts 앱 열기
2. 새 단축키 생성
3. "URL 내용 가져오기" 액션 추가
4. URL: `http://localhost:3016/api/v1/layouts/myLayout/restore`
5. 메서드: POST
6. Siri, 키보드 단축키, 또는 메뉴바에서 실행

### 예시: 캡처 단축키
- URL: `http://localhost:3016/api/v1/capture`
- 메서드: POST
- 헤더: Content-Type: application/json
- 본문: `{"name":"quickSave"}`

## API 스펙 문서

전체 OpenAPI 3.0 스펙은 다음 파일에서 확인할 수 있습니다:
- `_public/api/openapi.yaml`

## 다음 단계

- [Skill 사용법](07_Skill_Usage.md)
- [MCP 서버 사용법](08_MCP_Usage.md)
