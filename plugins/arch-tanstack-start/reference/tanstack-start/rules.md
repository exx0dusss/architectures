---
status: stable
---

# Critical Rules

Rules that must NEVER be broken. Violating these causes bugs, security issues, or architectural drift.

## Data fetching

1. **ALL backend calls go through server functions.** Use `createServerFn` — never call backends directly from client code. Server functions are the sole gateway to external APIs.

2. **TanStack Query is the sole caching layer.** No framework-level caching. Query options control stale/gc times.

3. **Route loaders use `ensureQueryData`.** For SSR prefetch, call `context.queryClient.ensureQueryData()` in the route `loader`. Never call server functions directly in components for initial data.

## Server functions

4. **Use `.inputValidator()` for input validation.** Every server function with input must pass a Zod schema to `.inputValidator(schema)`. No manual `.parse()` needed — Standard Schema support handles it.

5. **GET for reads, POST for mutations.** `createServerFn({ method: "GET" })` for data fetching, `{ method: "POST" }` for create/update/delete.

6. **Auth is session-first.** TanStack Start `useSession()` is the app auth source of truth. External backend tokens live only in `*.server.ts` bridge modules. Never pass tokens from the client.

## Types

7. **Use `z.infer` for DTO types** (post-transform shape). Use `z.input` only for form/request input types.

8. **No "Schema" suffix on types.** `Flow`, not `FlowSchema`. `CreateFlow`, not `CreateFlowSchema`.

## Imports

9. **Import UI primitives from `components/ui/`.** All shadcn/Base UI components live in `components/ui/`.

10. **Never expose server env vars to the client.** All backend URLs are server-only. Client vars use `VITE_` prefix.

## Styling

11. **Use semantic color tokens.** Never hardcode `text-white`, `bg-white/[0.xx]`, `text-purple-400`. Use `text-foreground`, `bg-accent-primary`, etc.

12. **Use typography tokens.** Never use raw `text-sm`, `text-xs`, `text-lg`. Use the semantic scale: `text-display`, `text-title-lg`, `text-title`, `text-title-sm`, `text-body-lg`, `text-body`, `text-body-sm`, plus semantic-only `text-label`, `text-caption`, `text-code`. Enforce mechanically with a CI guard script (`scripts/check-type-scale.ts` pattern) that fails on any raw text-size utility in `src/`.

## Service convention

13. **Follow the 6-file `x.z` pattern for every resource.** `{r}.schema.ts`, `{r}.api-schema.ts`, `{r}.functions.ts`, `{r}.query-options.ts`, `{r}.hooks.ts`, `{r}.search-params.ts`.

14. **Enums go at the TOP of `{r}.schema.ts`.** Before create/update/DTO schemas.

15. **Use the schema factory pattern** for user-facing validation. `createXxxSchema(t: TranslateFn)` with `identityTranslate` default.

## State management

16. **API data → TanStack Query. URL state → nuqs. UI state → Zustand.** No overlap. No exceptions.

## Route conventions

17. **Use `validateSearch` with Zod v4 for search params.** Pass a Zod schema directly (no adapter needed): `validateSearch: z.object({ page: z.number().default(1).catch(1) })`.

18. **Use `loaderDeps` when loaders depend on search params.** Extract deps explicitly: `loaderDeps: ({ search }) => ({ page: search.page })`. Search params are NOT available directly in loaders.

19. **Use `useSuspenseQuery` in components with loaders.** When the route loader calls `ensureQueryData`, the component should use `useSuspenseQuery` (data guaranteed available).

20. **Define `head()` with dynamic meta from `loaderData`.** Every route with a loader should generate title, description, og:tags from loaded data.

21. **Define `errorComponent` and `notFoundComponent`.** At minimum on the root route. Per-route for data-dependent pages. Use `throw notFound()` in loaders for missing resources.

22. **Configure `staleTime` on QueryClient.** Set `defaultOptions.queries.staleTime` (e.g., 30s) to prevent immediate refetch after SSR hydration.

## Zod

23. **Import as `import * as z from "zod"`.** Namespace import, bare `"zod"` path. Never use destructured `{ z }` or `"zod/v4"` path.

24. **Use `{ error: "..." }` for error messages.** Not string shorthand: `.min(5, { error: "Too short" })`, not `.min(5, "Too short")`.

25. **Use top-level validators.** `z.email()` not `z.string().email()`. `z.url()` not `z.string().url()`.

## TanStack Start

26. **No `"use client"` or `"use server"` directives.** TanStack Start is not RSC. Use `createServerFn` for server boundaries.

27. **Button uses `render` prop, not `asChild`.** Base UI pattern: `<Button render={<Link to="/" />} nativeButton={false}>`. Never use `asChild`.

28. **Do not wrap `createServerFn` in opaque custom factories.** Start must be able to see the actual server-function boundary. Use middleware for shared behavior, not wrappers that hide `createServerFn(...)`.

29. **Server-only internals live in `*.server.ts`.** Session access, token refresh, backend API client, and request logging stay in server-only modules and are imported only from server functions or other server-only files.

30. **Protected layouts must revalidate auth on navigation.** In `beforeLoad`, call `queryClient.fetchQuery({ ...authMeQueryOptions(), staleTime: 0 })` instead of trusting stale cached user state.

31. **Do not retry auth failures repeatedly in TanStack Query.** Queries and mutations should stop retrying on `401`/unauthorized errors so logout/refresh behavior is immediate.

32. **Route files must not pull `*.server.ts` into the client-reachable import graph.** If a route, route-local component, or helper can be imported by the browser, keep server-only access behind `createServerFn` or a server-only loader implementation. Never statically import `api-client.server`, session modules, or token bridges from route code.

33. **Use route loaders only for stable required data.** If a page can render without a dataset, template list, profile list, or optional integration surface, fetch it inside the page with TanStack Query instead of blocking navigation on the loader.

34. **Missing backend surfaces must degrade, not crash navigation.** Heavy admin sections should render empty/error states for optional endpoints or not-yet-migrated tables instead of failing the whole route.

35. **Do not blame `intent` preload first.** If hover preloading or early navigation freezes a route, treat that as a signal that the route tree has invalid imports or too much synchronous route-entry work. Fix the route graph before disabling preload.

17. **Invalidate the entire resource key on mutation success.** `queryClient.invalidateQueries({ queryKey: flowKeys.all })`.

## Auth

18. **Never store tokens in localStorage or sessionStorage.** TanStack Start session + HTTP-only cookies only.

19. **Refresh splits shared HTTP from per-request session write.** Dedupe concurrent refreshes via a `Map<refreshToken, Promise>` keyed on the refresh token. The shared refresh promise MUST NOT call `session.update()` inside itself — TanStack Start sessions are per-request, so only the first caller's session would receive the new tokens, and sibling server functions would silently retry with the already-rotated refresh token and log the user out. Apply the shared refresh result to each caller's own session after the promise resolves. See `auth-rbac.md` § Critical: the per-request session race.

20. **No barrels inside `lib/auth/`.** No `src/lib/auth/index.ts`, no `src/lib/auth/server/index.ts`. Import directly from the owning file. Barrels drift, hide unused exports, and risk pulling server-only modules into client-reachable graphs.

## Architecture

21. **Route-scoped components go in `-components/`.** Dash-prefixed folder, not routable, colocated with route files.

22. **Service folders mirror backend services.** `services/main/`, `services/auth/`, `services/chatting/` — one per backend.

## Styling

23. **Icon/SVG opacity on the element, not the stroke.** Use `className="opacity-40"` on the element, never `strokeOpacity` or `fillOpacity` SVG attributes. For muted icons: `<Icon className="size-4 opacity-40" />`.

24. **Use design system tokens.** Never use raw `var(--custom-*)` inline. Use Tailwind semantic classes mapped to CSS variables (`bg-card`, `text-foreground`, `border-border`, etc.).

25. **No `as any` or `as unknown as` type casts.** Fix types at the source. Exception: test files for partial mocking.

26. **No proxy routes.** Server functions replace the entire `app/api/[service]/[...path]` proxy pattern from Next.js.

## Naming

27. **Use full descriptive names for domain objects.** Never abbreviate callback parameters. `workspace` not `w` or `ws`. `token` not `t`. `bot` not `b`. `broadcast` not `bc`. When the full name would shadow an outer variable, use `item`.

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

28. **Never use `any`.** Use proper types, Zod schema inference, or `unknown` with type guards. `any` silently disables type checking and propagates to every variable it touches.

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
