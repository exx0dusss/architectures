---
name: openapi-check
description: Validate schemas against backend Swagger/OpenAPI specs
---

# OpenAPI Validator

Compare Zod schemas in `services/` against the backend's OpenAPI/Swagger specification.

## Checks

1. **URL alignment** — code endpoint paths match spec paths
2. **Method alignment** — GET/POST/PUT/DELETE match spec
3. **Query params** — required params present in api-schema
4. **Request body** — create/update schemas match spec request body
5. **Response schema** — DTO schema fields match spec response

## Input

- OpenAPI spec URL or file path
- Service directory to audit

## Output

Mismatch report with field-level diff.
