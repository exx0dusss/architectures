# Critical Rules

## Module boundaries

1. **Domain events for inter-module communication.** Modules NEVER import each other's services or repositories. Use `EventEmitter2` domain events. The shared module is the only exception.

2. **Event naming convention:** `{module}.{action}` — e.g., `order.placed`, `inventory.low`, `payment.completed`.

3. **No synchronous external API calls from event handlers.** Dispatch BullMQ jobs instead. Event handlers should be fast.

## Data integrity

4. **Prices in kopecks (integers).** `4999.00₴ = 499900`. Never use floats for money.

5. **UUIDs for all IDs.** UUID v7 (time-ordered) for primary keys. No auto-increment integers in API responses.

6. **Timestamps always UTC.** Use `timestamptz` in PostgreSQL. Never store local times.

7. **Order items snapshot product data.** Name, SKU, price are immutable at order time.

## Validation & security

8. **Zod v4 validation on all inputs.** Import as `import * as z from "zod"`. Use `{ error: "..." }` for error messages.

9. **CASL guards on all non-public routes.** Use `@RequirePermission({ action, subject })`. Never rely on role checks alone.

10. **Idempotency-Key header on order creation and payment.** Check `idempotency_keys` table before processing. Return cached response on duplicate.

11. **Webhook signature verification.** Always verify LiqPay SHA1 and Monobank HMAC before processing payment webhooks.

## Architecture

12. **Repository pattern for all database access.** No raw Drizzle queries in services. Repositories handle transactions.

13. **Drizzle snake_case casing.** All DB column names are `snake_case`. Drizzle handles mapping.

14. **OpenAPI spec is the contract.** NestJS Swagger decorators → OpenAPI spec → `openapi-typescript` → typed clients for store/CRM. Keep decorators up to date.

15. **Two-process deployment.** `api` runs `main.ts` (HTTP+WS). `worker` runs `worker.ts` (BullMQ). Same image, different entrypoints.
