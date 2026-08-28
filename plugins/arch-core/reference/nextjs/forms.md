# Forms

TanStack Form with a project-wide hook factory. There is one way to build a form.

## The hook factory

`src/hooks/form.ts` calls `createFormHook` and exports `useAppForm`, `withForm`, and
`withFieldGroup`. Field components are bound in at that point:

| Bound as | Kind |
| --- | --- |
| `TextField`, `TextareaField`, `SelectField`, `FileField` | field-level |
| `SubscribeButton` | form-level |

Contexts live in `hooks/form-context.ts`.

**Always use `useAppForm`.** Never import `useForm` from `@tanstack/react-form` directly — the
bound field components are the reason the factory exists.

### Adding a field type

Add the component under `components/form/`, then register it in the `fieldComponents` map in
`hooks/form.ts`. One registration, available in every form. Do not build a one-off field inside a
route's `_components/`.

## Anatomy

```tsx
const form = useAppForm({
  defaultValues: { name: "", channelId: "" } as CreateFlowFormValues,
  validators: { onChange: createFlowFormSchema },
  onSubmit: async ({ value }) => {
    await createMutation.mutateAsync({ path: { workspaceId }, data: value });
  },
});

return (
  <form
    onSubmit={(event) => {
      event.preventDefault();
      form.handleSubmit();
    }}
  >
    <form.AppField name="name">{(field) => <field.TextField label="Flow name" />}</form.AppField>
    <form.AppField name="channelId">
      {(field) => <field.SelectField items={channelOptions} label="Channel" />}
    </form.AppField>
    <form.SubscribeButton />
  </form>
);
```

Always wrap fields in `<form onSubmit>` — it buys Enter-to-submit and accessibility.

## Validation

Validators are Zod schemas from the resource's `schema.ts` — the same schemas the API layer parses
with. Do not write a parallel form-only schema. For user-facing messages, use the schema factory
pattern (`createXxxSchema(t)` with `identityTranslate` as the default) so one schema serves both
the API boundary and the localized form.

Async and cross-field validation lives in the resource's `validation.ts`. The reference shape is a
validator factory taking the query client, the sync schema, and the current value:

1. run the sync schema first,
2. skip the round-trip when the value is unchanged or already invalid,
3. check availability through `queryClient.fetchQuery`, so the result is cached like any other
   query.

Availability checks use the shared availability query fn and its named gc-time constant from
`services/_shared/` — never an inline millisecond literal.

## Submission

Forms submit through server actions, so they receive `ApiResult<T>` rather than a throw:

- `result.ok === false` → surface `result.error.message`, and map `result.error.fieldErrors`
  (`Record<string, string[]>`) onto the matching fields.
- Success feedback is a toast; cache invalidation is declared via mutation `meta`, not written by
  hand in the submit handler.

## Multi-step forms

Wizards keep step values in a Zustand store rather than lifting state through layouts, and **each
step is its own route** so the browser back button works.

A store that carries wizard state across steps is persisted and validated on rehydrate — persisted
shapes outlive code changes. `File` objects do not survive JSON serialization: persist metadata
only and keep the files themselves in memory for the session.
