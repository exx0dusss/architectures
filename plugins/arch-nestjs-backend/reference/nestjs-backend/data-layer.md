# Data Layer (Drizzle ORM)

## Schema helpers

Reusable column definitions for consistency across all tables.

```typescript
// shared/database/schema/helpers.ts
import { v7 as uuidv7 } from 'uuid';
import { timestamp, uuid } from 'drizzle-orm/pg-core';

// UUID v7 primary key — time-ordered, index-friendly
export function pk() {
  return uuid().primaryKey().$defaultFn(() => uuidv7());
}

// Standard createdAt / updatedAt columns
export const timestamps = {
  createdAt: timestamp({ withTimezone: true, mode: 'date' })
    .defaultNow().notNull().$default(() => new Date()),
  updatedAt: timestamp({ withTimezone: true, mode: 'date' })
    .defaultNow().notNull().$onUpdate(() => new Date()),
};

// Soft-delete column
export const softDelete = {
  deletedAt: timestamp({ withTimezone: true, mode: 'date' }),
};
```

### Usage

```typescript
export const productsTable = pgTable('products', {
  id: pk(),
  name: varchar({ length: 500 }).notNull(),
  slug: varchar({ length: 500 }).unique().notNull(),
  price: integer().notNull(),         // In kopecks
  compareAtPrice: integer(),          // In kopecks
  ...timestamps,
  ...softDelete,
});
```

Every table gets `id` (UUID v7), `createdAt`, `updatedAt`. Tables with lifecycle states get `deletedAt` for soft deletes.

## Prices in kopecks

All monetary values are stored and transmitted as integers representing the smallest currency unit (kopecks for UAH, cents for USD).

```
4999.00 UAH = 499900 kopecks
```

**Rules:**
- Column type: `integer().notNull()`
- Never use `numeric`, `decimal`, or `real` for prices
- Frontend handles display formatting (`(price / 100).toFixed(2)`)
- All arithmetic stays in integer domain -- no floating-point rounding errors

```typescript
// Schema
price: integer().notNull(),           // 499900
compareAtPrice: integer(),            // 599900 (original price before discount)
costPrice: integer(),                 // 250000 (supplier cost)

// Order items
unitPrice: integer().notNull(),       // Snapshot at order time
quantity: integer().notNull(),
totalPrice: integer().notNull(),      // unitPrice * quantity
```

## EAV pattern for product attributes

Products have dynamic, category-dependent attributes (voltage, wattage, color temperature, etc.) stored via Entity-Attribute-Value.

### Attribute definitions table

```typescript
export const attributeDefinitionsTable = pgTable('attribute_definitions', {
  id: pk(),
  name: varchar({ length: 200 }).notNull(),       // "Voltage"
  slug: varchar({ length: 200 }).unique().notNull(), // "voltage"
  type: attrTypeEnum().notNull(),                  // 'text' | 'number' | 'enum' | 'boolean'
  unit: varchar({ length: 20 }),                   // "V", "W", "K"
  isFilterable: boolean().default(false).notNull(),
  filterType: filterTypeEnum(),                    // 'checkbox' | 'range' | 'swatch' | 'color'
  enumValues: jsonb().$type<string[]>(),           // For enum type: ["220V", "12V", "24V"]
  sortOrder: integer().default(0).notNull(),
});
```

### Product attributes table

```typescript
export const productAttributesTable = pgTable('product_attributes', {
  id: pk(),
  productId: uuid().notNull().references(() => productsTable.id, { onDelete: 'cascade' }),
  attrDefId: uuid().notNull().references(() => attributeDefinitionsTable.id),
  valueText: varchar({ length: 500 }),     // For text type
  valueNumber: numeric({ precision: 10, scale: 2 }),  // For number type
  valueEnum: varchar({ length: 200 }),     // For enum type
}, (t) => [
  uniqueIndex().on(t.productId, t.attrDefId),  // One value per attribute per product
]);
```

**Query pattern:** Join `product_attributes` with `attribute_definitions` to get typed attribute values with labels and units.

## Order item snapshots

Order items capture a snapshot of the product at order time. The `productName`, `productSku`, and `unitPrice` are denormalized -- they will not change even if the product is updated or deleted later.

```typescript
export const orderItemsTable = pgTable('order_items', {
  id: pk(),
  orderId: uuid().notNull().references(() => ordersTable.id, { onDelete: 'cascade' }),
  productId: uuid().notNull().references(() => productsTable.id),
  variantId: uuid(),
  productName: varchar({ length: 500 }).notNull(),   // Snapshot
  productSku: varchar({ length: 50 }).notNull(),      // Snapshot
  unitPrice: integer().notNull(),                      // Snapshot (kopecks)
  quantity: integer().notNull(),
  totalPrice: integer().notNull(),                     // unitPrice * quantity
});
```

**Key rule:** Never join order items back to products for display. Use the snapshot fields. The `productId` reference exists only for analytics and linking.

## Inventory reservation

Two-field model for tracking stock:

```typescript
export const inventoryTable = pgTable('inventory', {
  id: pk(),
  productId: uuid().notNull().unique().references(() => productsTable.id),
  quantity: integer().default(0).notNull(),         // Total physical stock
  reserved: integer().default(0).notNull(),         // Reserved for pending orders
  lowStockThreshold: integer().default(5).notNull(),
  ...timestamps,
});
```

**Available stock:** `available = quantity - reserved`

### Reservation lifecycle

```
Order placed    -> reserved += quantity
Payment failed  -> reserved -= quantity
Order shipped   -> quantity -= reserved_amount, reserved -= reserved_amount
Order cancelled -> reserved -= quantity
```

When `available` drops below `lowStockThreshold`, emit `inventory.stock_low` domain event.

## Snake_case casing

All database column names use snake_case. Drizzle's column naming is already snake_case by default:

```typescript
// Drizzle column names map to snake_case in PostgreSQL
createdAt    -> created_at
customerId   -> customer_id
orderNumber  -> order_number
```

Configure the Drizzle client with `casing: 'snake_case'` if using camelCase property names in TypeScript.

## Database connection

```typescript
// shared/database/database.module.ts
export const DB = Symbol('DB');
export type Database = PostgresJsDatabase<typeof schema>;

@Module({
  providers: [{
    provide: DB,
    useFactory: () => {
      const client = postgres(process.env.DATABASE_URL);
      return drizzle(client, { schema, casing: 'snake_case' });
    },
  }],
  exports: [DB],
})
export class DatabaseModule {}
```

Inject with `@Inject(DB) private readonly db: Database`.

## Type inference

```typescript
// Derive types from table definitions
export type Product = typeof productsTable.$inferSelect;
export type NewProduct = typeof productsTable.$inferInsert;

// Use in repositories
async create(data: NewProduct): Promise<Product> {
  const [row] = await this.db.insert(productsTable).values(data).returning();
  return row;
}
```

## Pagination pattern

```typescript
async findPaginated(page: number, limit: number) {
  const offset = (page - 1) * limit;

  const [rows, countResult] = await Promise.all([
    this.db.query.ordersTable.findMany({
      orderBy: (o, { desc }) => [desc(o.createdAt)],
      limit,
      offset,
    }),
    this.db.select({ count: sql<number>`count(*)::int` }).from(ordersTable),
  ]);

  return {
    data: rows,
    meta: { total: countResult[0]?.count ?? 0, page, limit },
  };
}
```

Parallel count + data fetch for optimal performance.
