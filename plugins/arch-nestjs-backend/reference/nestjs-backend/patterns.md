# Implementation Patterns

Cross-cutting patterns used throughout the architecture.

## Domain events (EventEmitter2)

Modules communicate exclusively through domain events. No module imports another module's services or repositories.

```typescript
// shared/events/domain-events.ts — event class definitions
export class OrderPlacedEvent {
  constructor(
    public readonly orderId: string,
    public readonly customerId: string | null,
    public readonly orderNumber: string,
    public readonly total: number,
    public readonly items: { productId: string; quantity: number }[],
  ) {}
}
```

### Emitting events

```typescript
// order.service.ts
@Injectable()
export class OrderService {
  constructor(private readonly eventEmitter: EventEmitter2) {}

  async createOrder(data: CreateOrderData) {
    const order = await this.orderRepo.create(data);

    this.eventEmitter.emit(
      'order.placed',
      new OrderPlacedEvent(order.id, order.customerId, order.orderNumber, order.total, data.items),
    );

    return order;
  }
}
```

### Listening to events

```typescript
// notification.service.ts — in a DIFFERENT module
@Injectable()
export class NotificationService {
  @OnEvent('order.placed')
  async onOrderPlaced(payload: OrderPlacedEvent) {
    await this.emailService.sendOrderConfirmation(/* ... */);
    await this.telegramService.notifyAdmin(/* ... */);
  }
}

// inventory/handlers/order-placed.handler.ts — in yet another module
@Injectable()
export class OrderPlacedHandler {
  @OnEvent('order.placed')
  async handle(payload: OrderPlacedEvent) {
    for (const item of payload.items) {
      await this.inventoryService.reserve(item.productId, item.quantity);
    }
  }
}
```

**Key rule:** Event handlers that call external APIs must dispatch BullMQ jobs, never make synchronous HTTP calls.

### Event naming convention

```
{domain}.{past_tense_verb}
```

Examples: `order.placed`, `order.status_changed`, `payment.completed`, `inventory.stock_low`, `product.updated`, `user.registered`

## Repository pattern (Drizzle)

Each module owns its repository. Repositories encapsulate all database access and expose domain-oriented methods.

```typescript
@Injectable()
export class OrderRepository {
  constructor(@Inject(DB) private readonly db: Database) {}

  async create(data: CreateOrderData) {
    return this.db.transaction(async (tx) => {
      const [order] = await tx.insert(ordersTable).values(orderData).returning();
      await tx.insert(orderItemsTable).values(items.map((i) => ({ ...i, orderId: order.id })));
      await tx.insert(orderStatusHistoryTable).values({
        orderId: order.id, fromStatus: null, toStatus: 'pending',
      });
      return order;
    });
  }
}
```

### Transaction boundaries

- Wrap multi-table writes in `this.db.transaction()`
- Transactions stay within a single repository method -- never pass `tx` across module boundaries
- Use `sql` tagged template for complex WHERE clauses (e.g., atomic status transitions)

## Zod-first validation

No class-validator. All DTOs are Zod schemas imported from `zod/v4`.

```typescript
// dtos/create-order.dto.ts
import { z } from 'zod/v4';

export const createOrderSchema = z.object({
  items: z.array(z.object({
    productId: z.string().uuid(),
    quantity: z.int().min(1),
  })).min(1),
  deliveryMethod: z.enum(['nova_poshta', 'ukrposhta', 'self_pickup']),
  paymentMethod: z.enum(['liqpay', 'monobank', 'cod']),
  comment: z.string().max(500).optional(),
});

export type CreateOrderDto = z.infer<typeof createOrderSchema>;
```

### Validation in controllers

```typescript
@Post()
async create(@Body() body: unknown) {
  const result = createOrderSchema.safeParse(body);
  if (!result.success) {
    throw new BadRequestException({
      message: 'Validation failed',
      details: result.error.errors.map((e) => ({
        field: e.path.join('.'),
        message: e.message,
      })),
    });
  }
  return this.orderService.create(result.data);
}
```

### Environment validation

```typescript
// shared/config/env.validation.ts
export const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  // ...
});

// app.module.ts
ConfigModule.forRoot({
  validate: (config) => envSchema.parse(config),
})
```

App fails to start if env vars are missing or invalid.

## Idempotency interceptor

Prevents duplicate processing of order creation, payment initiation, and other critical mutations.

```typescript
@UseInterceptors(IdempotencyInterceptor)
@Post('orders')
async createOrder(@Body() body: CreateOrderDto) { /* ... */ }
```

**How it works:**
1. Client sends `Idempotency-Key` header (UUID)
2. Interceptor checks `idempotency_keys` table for a non-expired match
3. If found, returns the cached response immediately (no re-processing)
4. If not found, processes the request, then stores the response with 24h TTL
5. Uses `onConflictDoNothing()` for race-condition safety

## Channel adapter pattern (notifications)

Multi-channel notification delivery through a single event handler:

```
Domain Event (order.placed)
  └─> NotificationService.onOrderPlaced()
        ├─> EmailService.sendOrderConfirmation()     # Direct (fast)
        ├─> TelegramService.notifyAdmin()            # Direct (fast)
        └─> notificationQueue.add('send-sms', {...}) # Async (slow/external)
```

Each channel (email, Telegram, SMS, push) is a separate service. The `NotificationService` acts as the router, deciding which channels to use per event type.

For slow or unreliable channels, dispatch BullMQ jobs instead of calling directly.

## Job queue (BullMQ)

Queues are registered in the app module:

```typescript
BullModule.registerQueue(
  { name: 'import' },
  { name: 'catalog' },
  { name: 'notification' },
  { name: 'health' },
)
```

### Adding jobs from services

```typescript
@Injectable()
export class NotificationService {
  constructor(@InjectQueue('notification') private readonly queue: Queue) {}

  async notifyShipped(orderNumber: string, email: string) {
    await this.queue.add('send-email', {
      to: email,
      subject: `Order ${orderNumber} shipped`,
      html: '...',
    });
  }
}
```

### Consuming jobs in the worker process

```typescript
@Processor('notification')
export class NotificationConsumer extends WorkerHost {
  async process(job: Job) {
    switch (job.name) {
      case 'send-email':
        await this.emailService.send(job.data);
        break;
      case 'send-telegram-user':
        await this.telegramService.sendToUser(job.data);
        break;
      default:
        // An unknown name is a producer/worker version skew, not a no-op.
        throw new Error(`Unknown job ${job.name} on queue notification`);
    }
  }
}
```

Consumers run in the `worker.ts` process, not the HTTP process. **A job name the worker does not
know fails loudly** — a silent `switch` fall-through completes the job, so the producer believes
the work happened and nothing records that it did not.

### Queued runs for work that scales with rows

Anything whose cost grows with the number of rows — an import, an export, a bulk rewrite, a
rollback — is a **run on a worker**, never work inside the request or in the browser. A long
request is cut off by a proxy timeout or a closed tab part-way through, with no record of how far
it got.

1. **The request validates, stores, records and enqueues.** It validates the input, stores the
   uploaded bytes in object storage, writes the run row, enqueues the step and answers `202` with
   the run. Parsing, planning, writing and building a file happen only in the worker. Fixed-cost
   work with no rows (an empty template) may stay a direct response.
2. **A run is one row with an explicit status machine** for its whole life — queued, planning,
   awaiting input, ready, applying, terminal success/partial/error, cancelled, rolling back. Whether
   a step waits for a worker or runs in one is a `claimed_at` column, not a status of its own.
3. **Every transition is a conditional write** on the status (and revision, when the run carries
   one) that the writer read: `UPDATE … WHERE id = $1 AND status = $2 AND revision = $3`, and zero
   rows updated means someone else moved it. The API, the worker and the reaper then never
   overwrite one another, and a plan superseded by newer input writes nothing.
4. **Progress is a heartbeat that persists state.** The write loop flushes its row count and any
   undo snapshots every few hundred rows, so a run whose worker dies mid-way can still be reported
   and rolled back.
5. **A reaper fails stuck runs.** A step queued past a threshold with no worker or no job, or a
   claimed step with no heartbeat past another threshold, moves to `error` with a reason
   (`worker_unavailable`, `timed_out`). The API may apply the same rules to the run it is polled
   about, so a client never waits on a run nobody will finish.
6. **Give long runs their own queue** with its own concurrency, so a long apply never waits behind
   unrelated scheduled jobs, or the other way round.

### One Redis, many worktrees

When parallel worktrees share one local Redis, every worker listens on BullMQ's default `bull`
prefix, so a worker left running in one worktree claims another worktree's jobs and runs them on
different code. Give each worktree its own prefix from env, and read it everywhere a queue or
worker is built — the module root and any hand-run script that enqueues:

```typescript
BullModule.forRoot({
  connection: { url: env.REDIS_URL },
  prefix: env.BULLMQ_PREFIX, // `bull` by default; `bull-<worktree>` in a worktree
})
```

Worktree setup writes the prefix next to the worktree's other derived values (ports, cookie
names). The main checkout and deployed environments keep the default, so their existing queues
stay readable. A prefix change only takes effect once that worktree's API and worker restart.

## Global exception filter

All unhandled exceptions pass through a single filter that produces a standardized response:

```json
{
  "statusCode": 400,
  "error": "VALIDATION_ERROR",
  "message": "Validation failed",
  "details": [{ "field": "email", "message": "Invalid email" }],
  "timestamp": "2026-01-15T10:30:00.000Z",
  "path": "/api/auth/register"
}
```

Error code mapping:

| Status | Code |
|--------|------|
| 400 | `VALIDATION_ERROR` |
| 401 | `UNAUTHORIZED` |
| 403 | `FORBIDDEN` |
| 404 | `NOT_FOUND` |
| 409 | `CONFLICT` |
| 429 | `RATE_LIMITED` |
| 500 | `INTERNAL_ERROR` |

Non-HttpException errors are logged with stack traces but return a generic 500 to the client.

## OpenAPI generation

```typescript
// main.ts
const swaggerConfig = new DocumentBuilder()
  .setTitle('API')
  .setVersion('1.0')
  .addCookieAuth('access_token')
  .addBearerAuth()
  .build();

const document = SwaggerModule.createDocument(app, swaggerConfig);
SwaggerModule.setup('api/docs', app, document);
```

The generated OpenAPI spec is the contract between backend and all frontend clients. Use `@ApiTags`, `@ApiOperation`, `@ApiResponse` decorators on every controller method.
