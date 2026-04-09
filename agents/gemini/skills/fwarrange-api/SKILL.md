---
title: fwarrange-api
description: fWarrange REST API와 통신하여 창 레이아웃을 관리하는 Gemini 스킬
date: 2026-03-26
---

이 스킬은 실행 중인 fWarrange 앱의 REST API(기본 포트: 3016)와 통신하여 창 레이아웃을 관리하는 방법을 제공합니다.

<description>
fWarrange 앱이 실행 중일 때, macOS의 창 위치와 크기를 캡처하고 복원하거나 레이아웃 목록을 관리하는 API 통신 스킬입니다.
</description>

<instructions>
fWarrange 앱의 창 관리 작업을 수행해야 할 때 이 스킬을 활용하세요.
앱의 REST API는 기본적으로 `http://localhost:3016`에서 동작합니다. 항상 API가 켜져 있는지 확인하기 위해 Health Check를 먼저 수행하세요.

# 주요 API Endpoint 목록 (cURL 사용)

1. **상태 확인 (Health Check)**
   ```bash
   curl http://localhost:3016/
   ```
2. **레이아웃 목록 조회**
   ```bash
   curl http://localhost:3016/api/v1/layouts
   ```
3. **현재 창 레이아웃 캡처 및 저장**
   ```bash
   curl -X POST http://localhost:3016/api/v1/capture \
     -H "Content-Type: application/json" \
     -d '{"name": "저장할레이아웃명"}'
   ```
4. **특정 레이아웃으로 창 복원**
   ```bash
   curl -X POST http://localhost:3016/api/v1/layouts/{레이아웃명}/restore \
     -H "Content-Type: application/json" \
     -d '{}'
   ```
5. **레이아웃 삭제**
   ```bash
   curl -X DELETE http://localhost:3016/api/v1/layouts/{레이아웃명}
   ```
6. **현재 열려있는 창 목록 조회 (저장 안 함)**
   ```bash
   curl http://localhost:3016/api/v1/windows/current
   ```
7. **현재 실행 중인 앱 목록 조회**
   ```bash
   curl http://localhost:3016/api/v1/windows/apps
   ```

**주의사항**:
* 모든 통신은 JSON 형식으로 이루어지며, `{"status": "ok", "data": ...}` 구조를 가집니다.
* API 호출 시 `Connection refused` 오류가 발생하면, fWarrange 앱이 실행 중이지 않거나 환경설정에서 API 기능이 비활성화되어 있는 것입니다. 사용자에게 이를 안내하세요.
</instructions>