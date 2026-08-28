# NestJS Backend Architecture

DDD modular monolith with domain events, two-process deployment, Drizzle ORM, and attribute-based access control.

## Philosophy

- **DDD modular monolith** -- bounded contexts as NestJS modules, not microservices
- **Domain events for module communication** -- modules never import each other's internals, only emit/listen to events via EventEmitter2
- **Two-process architecture** -- HTTP+WebSocket in one process, BullMQ workers in another, same Docker image
- **Zod-first validation** -- no class-validator decorators, all DTOs are Zod schemas
- **OpenAPI as the contract** -- NestJS Swagger decorators generate the spec, openapi-typescript generates typed clients
- **Prices in kopecks** -- all monetary values are integers, never floats

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | NestJS 11 |
| Runtime | Node.js 22 LTS |
| Language | TypeScript 5.7+ |
| ORM | Drizzle ORM |
| Database | PostgreSQL 16 |
| Cache / Queue / PubSub | Redis 7 |
| Job Queue | BullMQ |
| Search Engine | Meilisearch |
| Object Storage | MinIO (S3-compatible) |
| Image Transform | imgproxy |
| Auth | Custom JWT + Arctic (OAuth2) |
| RBAC | CASL (attribute-based access control) |
| Password Hashing | Argon2id (@node-rs/argon2) |
| Validation | Zod v4 |
| Logging | Pino |
| Reverse Proxy | Caddy 2 |
| Testing | Vitest + Supertest |
| Package Manager | pnpm |

## When to use

- E-commerce backends with complex domain logic
- Multi-role CRM/admin systems
- Projects needing real-time updates (WebSocket) alongside REST
- Teams wanting DDD boundaries without microservice overhead

## When NOT to use

- Simple CRUD APIs (use a lighter framework)
- GraphQL-first projects (different data layer patterns)
- Serverless deployments (NestJS assumes long-running processes)

## Files in this architecture

| File | What it covers |
|------|---------------|
| [structure.md](./structure.md) | Module and folder layout |
| [patterns.md](./patterns.md) | Key implementation patterns |
| [auth-rbac.md](./auth-rbac.md) | Authentication and authorization |
| [data-layer.md](./data-layer.md) | Drizzle ORM patterns and schema design |
| [deployment.md](./deployment.md) | Two-process architecture and infrastructure |
| [real-time.md](./real-time.md) | WebSocket gateway and real-time events |
| [services.md](./services.md) | Module communication and external integrations |
| [rules.md](./rules.md) | Critical rules that must never be broken |
| [testing.md](./testing.md) | Testing strategy and patterns |
