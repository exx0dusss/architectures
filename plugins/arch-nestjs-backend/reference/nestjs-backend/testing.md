# Testing

## Stack

| Tool | Purpose |
|------|---------|
| Vitest | Unit + integration tests |
| Supertest | HTTP endpoint testing |
| `createTestApp()` | Test app factory |

## Test structure

```
test/
├── setup.ts                    # createTestApp utility
├── e2e/
│   ├── auth.e2e-spec.ts        # Auth flow tests
│   ├── products.e2e-spec.ts    # Product CRUD tests
│   └── orders.e2e-spec.ts      # Order lifecycle tests
└── unit/
    └── modules/
        └── {module}/
            └── {module}.service.spec.ts
```

## E2E test pattern

```typescript
describe('Auth (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createTestApp();
  });

  afterAll(async () => {
    await app.close();
  });

  it('registers a new user', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email, password, firstName, lastName })
      .expect(201);

    expect(res.body).toHaveProperty('user');
    expect(res.body.user.email).toBe(email);
  });
});
```

## createTestApp utility

```typescript
export async function createTestApp(): Promise<INestApplication> {
  const module = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();

  const app = module.createNestApplication();
  app.useGlobalFilters(new GlobalExceptionFilter());
  await app.init();
  return app;
}
```

## Config

```typescript
// vitest.config.ts — unit tests
export default defineConfig({
  test: {
    globals: true,
    root: './',
    include: ['src/**/*.spec.ts'],
  },
});

// vitest.e2e.config.ts — E2E tests (serial, separate forks)
export default defineConfig({
  test: {
    globals: true,
    root: './',
    include: ['test/e2e/**/*.e2e-spec.ts'],
    pool: 'forks',
    poolOptions: { forks: { singleFork: true } },
  },
});
```

## Rules

- E2E tests run serially (single fork) to avoid port conflicts
- Unit tests mock repositories, not databases
- Test database uses separate schema or test containers
- Never skip cleanup in `afterAll`
