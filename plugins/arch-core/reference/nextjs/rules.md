# Critical Rules

Rules that must NEVER be broken. Violating these causes bugs, security issues, or architectural drift.

## Data fetching

1. **NEVER use Next.js fetch cache on API calls.** No `cache: "force-cache"`, `next: { revalidate }`, `next: { tags }`, `revalidateTag()`, `revalidatePath()`, or `unstable_cache()`. TanStack Query is the sole caching layer.

2. **React `cache()` is for request deduplication only.** Import from `"react"`, NOT `"next/cache"`. Used in `queries.ts` to prevent duplicate fetches within a single server render.

3. **`serverFetch` defaults to `cache: "no-store"`.** Never override this.

## Server actions

4. **ALWAYS wrap server actions in `safeAction()`.** Return `Promise<ApiResult<T>>`, never throw.

5. **ALWAYS validate input with Zod.** Every server action and query function must `.parse()` its input.

## Types

6. **Use `z.infer` for DTO types** (post-transform shape). Use `z.input` only for form/request input types.

7. **No "Schema" suffix on types.** `Flow`, not `FlowSchema`. `CreateFlow`, not `CreateFlowSchema`.

## Imports

8. **Import UI primitives from `components/ui/`.** All shadcn/Base UI components live in `components/ui/`.

9. **Never expose server env vars to the client.** All backend URLs are server-only. Client uses the proxy (`/api/{service}/...`).

## Styling

10. **Use semantic color tokens.** Never hardcode `text-white`, `bg-white/[0.xx]`, `text-purple-400`. Use `text-foreground`, `bg-accent-primary`, etc.

11. **Use typography tokens.** Never use raw `text-sm`, `text-xs`, `text-lg`. Use `text-body`, `text-body-small`, `text-heading-large`, etc.

## Service convention

12. **Follow the 7-file pattern for every resource.** `schema.ts`, `api-schema.ts`, `queries.ts`, `query-options.ts`, `actions.ts`, `use-{resource}.ts`, `search-params.ts`.

13. **Enums go at the TOP of `schema.ts`.** Before create/update/DTO schemas.

14. **Use the schema factory pattern** for user-facing validation. `createXxxSchema(t: TranslateFn)` with `identityTranslate` default.

## State management

15. **API data → TanStack Query. URL state → nuqs. UI state → Zustand.** No overlap. No exceptions.

16. **Invalidate the entire resource key on mutation success.** `queryClient.invalidateQueries({ queryKey: flowKeys.all })`.

## Auth

17. **Never store tokens in localStorage or sessionStorage.** Cookies only (`httpOnly`, `secure`, `sameSite: lax`).

18. **Use `refreshWithLock()` for token refresh.** Prevents concurrent refresh races.

## Architecture

19. **Page-specific components go in `_components/`.** Private folder, not routable, colocated with `page.tsx`.

20. **Service folders mirror backend services.** `services/main/`, `services/auth/`, `services/chatting/` — one per backend.

## Naming

21. **Use full descriptive names for domain objects.** Never abbreviate callback parameters. `workspace` not `w` or `ws`. `token` not `t`. `bot` not `b`. `broadcast` not `bc`. When the full name would shadow an outer variable, use `item`.

   **Exceptions:** `e` for DOM events, `i`/`j`/`k` for loop indices, `a`/`b` in sort comparators.

   **Bad:**
   ```typescript
   workspaces.find((w) => w.slug === slug)
   tokens.filter((t) => t.revokedAt === null)
   ```

   **Good:**
   ```typescript
   workspaces.find((workspace) => workspace.slug === slug)
   tokens.filter((token) => token.revokedAt === null)
   ```

## Types (continued)

22. **Never use `any`.** Use proper types, Zod schema inference, or `unknown` with type guards. `any` silently disables type checking and propagates to every variable it touches.

   **Bad:**
   ```typescript
   const data: any = await api.get("/users")
   workspaces.find((w: any) => w.slug === slug)
   ```

   **Good:**
   ```typescript
   const data = await api.get("/users", { schema: userListSchema })
   workspaces.find((workspace: Workspace) => workspace.slug === slug)
   ```
