---
id: api-endpoint-verification-pattern
trigger: when making changes to REST API endpoints or response schemas
confidence: 0.7
domain: code-style
source: session-observation
scope: project
project_id: 9d456d722db3
project_name: _public
---

# API Endpoint Path Verification Pattern

## Action
Before making REST API endpoint changes, search for existing endpoint path definitions (`/api/v1/`, `/api/v2/`) in codebase and verify OpenAPI schema sync to ensure consistency across versions.

## Evidence
- Observed 5 times in session
- Pattern: grep/search for API paths (events 11, 19, 21), Issue documentation with endpoint changes (events 9, 13), Harness.md API skill references (event 3)
- Workflow: edit endpoint → search existing paths → update schema → document in Issue.md → verify health checks
- Last observed: 2026-04-24
