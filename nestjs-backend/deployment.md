# Deployment

## Two-process architecture

The application runs as two separate processes from the same Docker image.

### Process 1: API (main.ts)

```typescript
const app = await NestFactory.create(AppModule);
app.use(cookieParser());
app.enableCors({ origin: [storeUrl, crmUrl], credentials: true });
app.use(helmet());
app.useGlobalFilters(new GlobalExceptionFilter());
await app.listen(3001);
```

**Responsibilities:** HTTP REST API, WebSocket gateway (Socket.IO on `/ws`), Swagger docs, rate limiting.

### Process 2: Worker (worker.ts)

```typescript
const app = await NestFactory.createApplicationContext(WorkerModule);
await app.init();
```

**Responsibilities:** BullMQ job consumers, cron jobs (`@nestjs/schedule`). No HTTP listener.

### Why two processes

| Concern | API | Worker |
|---------|-----|--------|
| Long-running jobs | Block event loop | Isolated |
| Crash impact | Affects HTTP | No HTTP impact |
| Scaling | By traffic | By queue depth |
| Memory | Stable | Spiky (imports, syncs) |

## Docker

```dockerfile
FROM node:22-slim AS base
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build && pnpm build:worker
```

```yaml
# docker-compose.yml
services:
  api:
    build: .
    command: node dist/main.js
    ports: ["3001:3001"]
  worker:
    build: .
    command: node dist/worker.js
```

## Infrastructure services

| Service | Purpose | Default port |
|---------|---------|-------------|
| PostgreSQL 16 | Primary database | 5432 |
| Redis 7 | Cache, queue backend, pub/sub | 6379 |
| Meilisearch 1.12+ | Full-text search | 7700 |
| MinIO | S3-compatible object storage | 9000 |
| imgproxy | Image transformation | 8080 |
| Caddy 2 | Reverse proxy, TLS | 80/443 |

## Environment validation

All env vars validated at startup with Zod — app fails to start if vars are missing:

```typescript
export const envSchema = z.object({
  PORT: z.coerce.number().default(3001),
  NODE_ENV: z.enum(['development', 'production', 'test']),
  DATABASE_URL: z.string().min(1),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  MEILI_URL: z.string().default('http://localhost:7700'),
  JWT_SECRET: z.string().min(1),
  // ... all required vars
});
```
