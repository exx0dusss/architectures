# Services & Integration Patterns

## Module communication

```
Module A → EventEmitter2.emit('order.placed') → Module B @OnEvent('order.placed')
```

Never import services across modules. The shared module provides infrastructure (DB, Redis, RBAC).

## Payment strategy pattern

Multiple payment providers behind a common interface:

```typescript
interface PaymentProvider {
  createPayment(order: Order): Promise<PaymentSession>;
  verifyWebhook(body: string, signature: string): boolean;
  handleWebhook(payload: unknown): Promise<PaymentResult>;
}
```

Implementations: LiqPay, Monobank, Cash on Delivery.

## Webhook signature verification

```typescript
// LiqPay — SHA1
verifyLiqPaySignature(data: string, signature: string): boolean {
  return sha1(this.privateKey + data + this.privateKey) === signature;
}

// Monobank — HMAC SHA256
verifyMonoSignature(body: string, signature: string): boolean {
  return createHmac('sha256', this.merchantToken).update(body).digest('hex') === signature;
}
```

**Rule:** Always verify before processing. Log and discard invalid webhooks.

## Notification channel adapter

```typescript
interface ChannelAdapter {
  formatMessage(template: string, data: Record<string, unknown>): string;
  sendMessage(to: string, message: string): Promise<void>;
  validateConfig(config: Record<string, unknown>): boolean;
}
```

Implementations: Email (Resend), Telegram, SMS, Viber, WhatsApp. Registered at module init, dispatched by notification service.

## Search (Meilisearch)

```typescript
@OnEvent('product.updated')
async handleProductUpdated(event: ProductUpdatedEvent) {
  await this.meiliClient.index('products').updateDocuments([{
    id: event.productId,
    name: event.name,
    description: event.description,
    categoryId: event.categoryId,
    price: event.price,
    status: event.status,
  }]);
}
```

Index updates happen via domain events, not inline in CRUD operations.

## File storage (MinIO + imgproxy)

Upload → MinIO (S3-compatible) → imgproxy generates variants on-the-fly:

```
Original: /uploads/{uuid}.jpg
Thumbnail: /imgproxy/rs:fit:200:200/{s3_url}
Product:   /imgproxy/rs:fit:800:800/{s3_url}
```

No pre-generated thumbnails. imgproxy handles resizing, format conversion (WebP/AVIF), and caching.

## OpenAPI as contract

```
NestJS Swagger decorators → OpenAPI 3.1 spec → openapi-typescript → typed fetch clients
```

The spec is the single source of truth for frontend API clients. Keep `@ApiProperty`, `@ApiResponse`, `@ApiOperation` decorators up to date.
