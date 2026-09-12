# Module Structure

## Top-level layout

```
src/
├── main.ts                    # HTTP + WebSocket entrypoint
├── worker.ts                  # BullMQ consumer entrypoint
├── app.module.ts              # HTTP app module (all modules)
├── worker.module.ts           # Worker module (only modules with consumers)
└── modules/
    ├── auth/                  # Identity, JWT, OAuth, sessions
    ├── user/                  # Profiles, addresses, wishlist
    ├── catalog/               # Products, categories, brands, attributes
    ├── inventory/             # Stock levels, reservations
    ├── cart/                  # Cart state, promo codes
    ├── order/                 # Checkout, order lifecycle
    ├── payment/               # Payment providers, webhooks
    ├── delivery/              # Carrier integrations, tracking
    ├── review/                # Reviews, moderation
    ├── import/                # Data import, CSV/XML parsing
    ├── notification/          # Email, Telegram, push
    ├── chat/                  # Support conversations (WebSocket)
    ├── crm/                   # Analytics, dashboards
    └── shared/                # Cross-cutting infrastructure
```

## Layer structure within each module

Each domain module follows a four-layer DDD structure:

```
{module}/
├── domain/                    # Pure business logic (no NestJS imports)
│   ├── entities/              # Domain entities
│   ├── value-objects/         # Value objects
│   ├── events/                # Domain event classes
│   └── interfaces/            # Repository/service interfaces
├── application/               # Use cases and orchestration
│   ├── commands/              # Write operations
│   ├── queries/               # Read operations
│   ├── services/              # Application services
│   └── handlers/              # Domain event handlers
├── infrastructure/            # External world adapters
│   ├── repositories/          # Drizzle repository implementations
│   ├── adapters/              # Third-party API clients
│   └── consumers/             # BullMQ job consumers
└── presentation/              # HTTP layer
    ├── controllers/           # REST controllers
    ├── dtos/                  # Zod schema DTOs
    ├── guards/                # Module-specific guards
    └── decorators/            # Module-specific decorators
```

For smaller modules, flatten the layers -- the key constraint is that imports flow inward (presentation -> application -> domain), never outward.

## Flat module example (simpler modules)

```
banner/
├── banner.module.ts
├── banner.service.ts
├── banner.repository.ts
├── banner.controller.ts
├── banner-admin.controller.ts
└── dtos/
    └── create-banner.dto.ts
```

## Controller split pattern

Every module exposes two controllers:

| Controller | Prefix | Auth | Purpose |
|-----------|--------|------|---------|
| `{module}.controller.ts` | `/api/{module}` | Public or customer | Storefront-facing |
| `{module}-admin.controller.ts` | `/api/admin/{module}` | Admin/manager | CRM-facing |

This keeps public and admin APIs cleanly separated with different RBAC policies.

## Shared module breakdown

```
shared/
├── config/
│   └── env.validation.ts      # Zod schema for environment variables
├── database/
│   ├── database.module.ts     # Drizzle connection provider (DB token)
│   ├── schema/                # All Drizzle table definitions
│   │   ├── helpers.ts         # pk(), timestamps, softDelete mixins
│   │   ├── index.ts           # Barrel export
│   │   ├── users.ts
│   │   ├── products.ts
│   │   ├── orders.ts
│   │   └── ...
│   └── seed.ts                # Database seeder
├── events/
│   ├── domain-events.ts       # Domain event class definitions
│   └── redis-publish.handler.ts  # Event -> Redis pub/sub bridge
├── filters/
│   └── global-exception.filter.ts  # Standardized error responses
├── gateway/
│   └── events.gateway.ts     # Socket.IO WebSocket gateway
├── interceptors/
│   └── idempotency.interceptor.ts  # Idempotency-Key handling
├── rbac/
│   ├── ability.factory.ts     # CASL ability definitions
│   ├── permission.guard.ts    # Permission guard
│   └── require-permission.decorator.ts  # @RequirePermission decorator
├── redis/
│   └── redis.module.ts        # Redis pub/sub/cache providers
├── health/
│   └── health.controller.ts   # Basic health check endpoint
└── shared.module.ts           # Exports all shared providers
```

## App module vs Worker module

```typescript
// app.module.ts — full module set, HTTP + WebSocket
@Module({
  imports: [
    ConfigModule.forRoot({ validate: (c) => envSchema.parse(c) }),
    EventEmitterModule.forRoot({ wildcard: true }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 60 }]),
    BullModule.forRootAsync({ /* Redis connection */ }),
    SharedModule,
    AuthModule, CatalogModule, OrderModule, /* ... all modules */
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}

// worker.module.ts — only modules that have BullMQ consumers
@Module({
  imports: [
    ConfigModule.forRoot({ validate: (c) => envSchema.parse(c) }),
    EventEmitterModule.forRoot({ wildcard: true }),
    BullModule.forRootAsync({ /* Redis connection */ }),
    SharedModule,
    ImportModule, CatalogModule, NotificationModule, /* ... consumer modules only */
  ],
})
export class WorkerModule {}
```

## Naming conventions

| Category | Pattern | Example |
|----------|---------|---------|
| Files | kebab-case | `order-admin.controller.ts` |
| Classes | PascalCase | `OrderAdminController` |
| Functions | camelCase | `findByCustomerId` |
| DB columns | snake_case (via Drizzle casing) | `created_at`, `order_number` |
| Import alias | `~/` -> `src/` | `import { DB } from '~/modules/shared/database/database.module'` |
| Module files | `{name}.module.ts` | `order.module.ts` |
| Services | `{name}.service.ts` | `order.service.ts` |
| Repositories | `{name}.repository.ts` | `order.repository.ts` |
| Controllers | `{name}.controller.ts` | `order.controller.ts` |
| DTOs | `{name}.dto.ts` in `dtos/` | `create-order.dto.ts` |
| Event handlers | `{event-name}.handler.ts` | `order-placed.handler.ts` |
| Consumers | `{name}.consumer.ts` | `notification.consumer.ts` |
| Jobs | `{name}.job.ts` | `abandoned-cart.job.ts` |
