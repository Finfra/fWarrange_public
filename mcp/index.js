#!/usr/bin/env node

/**
 * fWarrange MCP Server
 *
 * Usage:
 *   node index.js [--server=<url>]
 *
 * Arguments:
 *   --server=<url> : (옵션) fWarrange REST API 서버 주소 (기본값: http://localhost:3016)
 *
 * Environment:
 *   FWARRANGE_SERVER : 환경변수 설정 (--server 옵션보다 우선순위 낮음)
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// 서버 주소 결정: CLI 인자 > 환경변수 > 기본값
function getServerUrl() {
  const arg = process.argv.find((a) => a.startsWith("--server="));
  if (arg) return arg.split("=").slice(1).join("=");
  return process.env.FWARRANGE_SERVER || "http://localhost:3016";
}

const SERVER_URL = getServerUrl();

const server = new McpServer({
  name: "fwarrange-mcp",
  version: "1.0.0",
});

// 공통 헬퍼: API 호출 후 JSON 응답 반환
async function apiCall(path, options = {}) {
  const url = `${SERVER_URL}${path}`;
  const res = await fetch(url, options);
  const contentType = res.headers.get("content-type") || "";

  if (contentType.includes("application/json")) {
    const json = await res.json();
    if (!res.ok) {
      return {
        isError: true,
        content: [
          {
            type: "text",
            text: `API 오류 (${res.status}): ${JSON.stringify(json, null, 2)}`,
          },
        ],
      };
    }
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(json, null, 2),
        },
      ],
    };
  }

  const text = await res.text();
  if (!res.ok) {
    return {
      isError: true,
      content: [
        {
          type: "text",
          text: `API 오류 (${res.status}): ${text}`,
        },
      ],
    };
  }
  return {
    content: [
      {
        type: "text",
        text: text || `응답: ${res.status} ${res.statusText}`,
      },
    ],
  };
}

// 공통 에러 래퍼
function withErrorHandler(fn) {
  return async (params) => {
    try {
      return await fn(params);
    } catch (err) {
      return {
        isError: true,
        content: [
          {
            type: "text",
            text: `요청 실패: ${err.message}\n서버 주소: ${SERVER_URL}`,
          },
        ],
      };
    }
  };
}

// ─────────────────────────────────────────────
// Tool 1: health_check
// ─────────────────────────────────────────────
server.tool(
  "health_check",
  "fWarrange 서버 상태를 확인합니다",
  {},
  withErrorHandler(async () => {
    return await apiCall("/");
  })
);

// ─────────────────────────────────────────────
// Tool 2: list_layouts
// ─────────────────────────────────────────────
server.tool(
  "list_layouts",
  "저장된 레이아웃 목록을 조회합니다",
  {},
  withErrorHandler(async () => {
    return await apiCall("/api/v1/layouts");
  })
);

// ─────────────────────────────────────────────
// Tool 3: get_layout
// ─────────────────────────────────────────────
server.tool(
  "get_layout",
  "특정 레이아웃의 상세 정보(창 목록)를 조회합니다",
  {
    name: z.string().describe("레이아웃 이름 (확장자 제외)"),
  },
  withErrorHandler(async ({ name }) => {
    return await apiCall(`/api/v1/layouts/${encodeURIComponent(name)}`);
  })
);

// ─────────────────────────────────────────────
// Tool 4: capture_layout
// ─────────────────────────────────────────────
server.tool(
  "capture_layout",
  "현재 열려 있는 창 레이아웃을 캡처하여 저장합니다",
  {
    name: z
      .string()
      .optional()
      .describe("저장할 레이아웃 이름 (미지정 시 기본값 사용)"),
    filterApps: z
      .array(z.string())
      .optional()
      .describe("캡처할 앱 이름 목록 (미지정 시 전체)"),
  },
  withErrorHandler(async ({ name, filterApps }) => {
    const body = {};
    if (name) body.name = name;
    if (filterApps) body.filterApps = filterApps;

    return await apiCall("/api/v1/capture", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  })
);

// ─────────────────────────────────────────────
// Tool 5: restore_layout
// ─────────────────────────────────────────────
server.tool(
  "restore_layout",
  "저장된 레이아웃을 복구하여 창 위치/크기를 재배치합니다",
  {
    name: z.string().describe("복구할 레이아웃 이름"),
    maxRetries: z
      .number()
      .optional()
      .describe("최대 재시도 횟수 (기본값: 5)"),
    retryInterval: z
      .number()
      .optional()
      .describe("재시도 간격(초) (기본값: 0.5)"),
    minimumScore: z
      .number()
      .optional()
      .describe("최소 매칭 점수 (기본값: 50)"),
    enableParallel: z
      .boolean()
      .optional()
      .describe("병렬 복구 활성화 여부"),
  },
  withErrorHandler(async ({ name, maxRetries, retryInterval, minimumScore, enableParallel }) => {
    const body = {};
    if (maxRetries !== undefined) body.maxRetries = maxRetries;
    if (retryInterval !== undefined) body.retryInterval = retryInterval;
    if (minimumScore !== undefined) body.minimumScore = minimumScore;
    if (enableParallel !== undefined) body.enableParallel = enableParallel;

    return await apiCall(
      `/api/v1/layouts/${encodeURIComponent(name)}/restore`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      }
    );
  })
);

// ─────────────────────────────────────────────
// Tool 6: rename_layout
// ─────────────────────────────────────────────
server.tool(
  "rename_layout",
  "레이아웃 이름을 변경합니다",
  {
    name: z.string().describe("현재 레이아웃 이름"),
    newName: z.string().describe("변경할 새 이름"),
  },
  withErrorHandler(async ({ name, newName }) => {
    return await apiCall(
      `/api/v1/layouts/${encodeURIComponent(name)}`,
      {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ newName }),
      }
    );
  })
);

// ─────────────────────────────────────────────
// Tool 7: delete_layout
// ─────────────────────────────────────────────
server.tool(
  "delete_layout",
  "특정 레이아웃을 삭제합니다",
  {
    name: z.string().describe("삭제할 레이아웃 이름"),
  },
  withErrorHandler(async ({ name }) => {
    return await apiCall(
      `/api/v1/layouts/${encodeURIComponent(name)}`,
      { method: "DELETE" }
    );
  })
);

// ─────────────────────────────────────────────
// Tool 8: delete_all_layouts
// ─────────────────────────────────────────────
server.tool(
  "delete_all_layouts",
  "저장된 모든 레이아웃을 삭제합니다 (확인 헤더 필요)",
  {},
  withErrorHandler(async () => {
    return await apiCall("/api/v1/layouts", {
      method: "DELETE",
      headers: { "X-Confirm-Delete-All": "true" },
    });
  })
);

// ─────────────────────────────────────────────
// Tool 9: remove_windows
// ─────────────────────────────────────────────
server.tool(
  "remove_windows",
  "레이아웃에서 특정 창(Window ID)을 제거합니다",
  {
    name: z.string().describe("레이아웃 이름"),
    windowIds: z
      .array(z.number())
      .describe("제거할 Window ID 목록"),
  },
  withErrorHandler(async ({ name, windowIds }) => {
    return await apiCall(
      `/api/v1/layouts/${encodeURIComponent(name)}/windows/remove`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ windowIds }),
      }
    );
  })
);

// ─────────────────────────────────────────────
// Tool 10: get_current_windows
// ─────────────────────────────────────────────
server.tool(
  "get_current_windows",
  "현재 열려 있는 창 목록을 조회합니다",
  {
    filterApps: z
      .array(z.string())
      .optional()
      .describe("필터링할 앱 이름 목록 (미지정 시 전체)"),
  },
  withErrorHandler(async ({ filterApps }) => {
    let path = "/api/v1/windows/current";
    if (filterApps && filterApps.length > 0) {
      const params = new URLSearchParams();
      filterApps.forEach((app) => params.append("filterApps", app));
      path += `?${params.toString()}`;
    }
    return await apiCall(path);
  })
);

// ─────────────────────────────────────────────
// Tool 11: get_running_apps
// ─────────────────────────────────────────────
server.tool(
  "get_running_apps",
  "현재 실행 중인 애플리케이션 목록을 조회합니다",
  {},
  withErrorHandler(async () => {
    return await apiCall("/api/v1/windows/apps");
  })
);

// ─────────────────────────────────────────────
// Tool 12: check_accessibility
// ─────────────────────────────────────────────
server.tool(
  "check_accessibility",
  "macOS 손쉬운 사용(Accessibility) 권한 상태를 확인합니다",
  {},
  withErrorHandler(async () => {
    return await apiCall("/api/v1/status/accessibility");
  })
);

// ─────────────────────────────────────────────
// 서버 시작
// ─────────────────────────────────────────────
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("MCP 서버 시작 실패:", err);
  process.exit(1);
});
