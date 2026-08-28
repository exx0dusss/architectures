# Authentication and Authorization

## Authentication flow

### JWT + refresh token rotation

```
Login/Register
  └─> AuthService validates credentials (Argon2id verify)
        └─> JwtTokenService generates:
              ├─> Access token (JWT, 15min TTL, signed with HS256)
              └─> Refresh token (random 32-byte hex, stored in Redis, 7-day TTL)
                    └─> Both set as httpOnly cookies
```

### Cookie configuration

| Cookie | Path | SameSite | Scope |
|--------|------|----------|-------|
| `access_token` | `/` | `lax` | All API requests |
| `refresh_token` | `/api/auth` | `strict` | Refresh endpoint only |

Both cookies are `httpOnly` and `secure` in production. Never stored in localStorage.

### Token refresh

```
POST /api/auth/refresh
  └─> Read refresh_token from cookie
        └─> Validate against Redis
              └─> Revoke old refresh token (rotation)
                    └─> Generate new access + refresh tokens
                          └─> Set new cookies
```

Refresh token rotation: every refresh invalidates the old token and issues a new one. If a revoked token is used, it indicates theft -- revoke all tokens for that user.

### JWT payload

```typescript
interface JwtPayload {
  sub: string;    // User ID (UUID)
  email: string;
  role: string;   // Role name
}
```

### Guards

| Guard | Purpose |
|-------|---------|
| `JwtAuthGuard` | Extracts and verifies JWT from cookie/Bearer header, sets `req.user` |
| `OptionalAuthGuard` | Same as above but does not reject unauthenticated requests |
| `PermissionGuard` | Checks CASL permissions from `@RequirePermission` metadata |
| `ThrottlerGuard` | Global rate limiting (60 req/min default) |

## OAuth2 via Arctic

Arctic provides OAuth2 client implementations for Google, Apple, Facebook.

```
GET /api/auth/:provider
  └─> Generate state, set oauth_state cookie
        └─> Redirect to provider authorization URL

GET /api/auth/:provider/callback
  └─> Validate state cookie (CSRF protection)
        └─> Exchange code for tokens (Arctic)
              └─> Fetch user profile from provider
                    └─> AuthService.loginOrCreateFromOAuth()
                          └─> Find or create user + oauth_accounts record
                                └─> Issue JWT + refresh token cookies
                                      └─> Redirect to store callback URL
```

Provider implementations follow a common interface:

```typescript
interface OAuthProvider {
  enabled: boolean;
  createAuthorizationURL(state: string): URL;
  validateAuthorizationCode(code: string): Promise<OAuth2Tokens>;
  getUserProfile(accessToken: string): Promise<OAuthProfile>;
}
```

## CASL-based RBAC

### Role hierarchy

```
super_admin        # Full access, can manage other admins
  └─ admin         # Full access except deleting users
      ├─ manager   # Products, inventory, orders, imports, reviews
      ├─ marketer  # Analytics, ad campaigns, read-only products/orders
      └─ support   # Orders (read/update), users (read), chat
          └─ customer  # Own orders, reviews, wishlist, read products
              └─ service  # API key access with explicit scopes
```

### Ability factory

```typescript
function defineAbilitiesFor(user: AuthUser): AppAbility {
  const { can, cannot, build } = new AbilityBuilder(createMongoAbility);

  switch (user.role) {
    case 'super_admin':
      can('manage', 'all');
      break;
    case 'admin':
      can('manage', 'all');
      cannot('delete', 'User');  // Cannot delete other admins
      break;
    case 'manager':
      can('manage', 'Product');
      can('manage', 'Category');
      can('manage', 'Inventory');
      can('manage', 'Order');
      can('read', 'Analytics');
      break;
    case 'customer':
      can('read', 'Product');
      can('create', 'Order');
      can('read', 'Order');      // Own orders enforced at query level
      can('manage', 'Review');
      can('manage', 'Wishlist');
      break;
    case 'service':
      // Scope-based: scopes array like ['read:Product', 'create:Order']
      for (const scope of user.scopes ?? []) {
        const [action, subject] = scope.split(':');
        can(action, subject);
      }
      break;
  }

  return build();
}
```

### Actions and subjects

**Actions:** `create`, `read`, `update`, `delete`, `manage` (wildcard for all actions)

**Subjects:** `Product`, `Category`, `Brand`, `Inventory`, `Order`, `Payment`, `User`, `Role`, `Review`, `Chat`, `Analytics`, `Health`, `all`

### Using permissions in controllers

```typescript
@Controller('api/admin/products')
@UseGuards(JwtAuthGuard, PermissionGuard)
export class ProductAdminController {

  @Post()
  @RequirePermission({ action: 'create', subject: 'Product' })
  async create(@Body() body: unknown) { /* ... */ }

  @Delete(':id')
  @RequirePermission({ action: 'delete', subject: 'Product' })
  async remove(@Param('id') id: string) { /* ... */ }
}
```

### Guard execution order

```
Request
  └─> JwtAuthGuard (sets req.user)
        └─> PermissionGuard (reads @RequirePermission metadata, builds ability, checks)
              └─> Controller method
```

If no `@RequirePermission` is set, `PermissionGuard` passes through (allow by default). Use `@RequirePermission` on every non-public route.
