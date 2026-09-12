---
status: stable
---

# Forms

Every form uses the repo's canonical TanStack Form pattern. There is one way to build a form.

## The hook factory

`src/hooks/form.tsx` calls `createFormHook` and exports `useAppForm`. Field components and the
form-level submit button are bound in at that point, which is the entire reason the factory
exists:

| Bound as | Kind |
| --- | --- |
| `TextField`, `PasswordField`, `NumberField`, `CheckboxField`, `DateTimePickerField` | field-level |
| `SubscribeButton` | form-level |

**Always use `useAppForm`.** Never import `useForm` from `@tanstack/react-form` directly — a raw
`useForm` has no `fieldContext`, so none of the registered components are reachable.

### Adding a field type

Add the component under `components/form/`, then register it in the `fieldComponents` map in
`hooks/form.tsx`. One registration, available in every form. Do not build a one-off field inside
a route's `-components/`.

## Anatomy

```tsx
const form = useAppForm({
  defaultValues: { email: "", password: "" },
  validators: { onSubmit: loginSchema }, // Zod v4, reused from the resource schema
  onSubmit: async ({ value }) => {
    /* mutation */
  },
});

<form.AppForm>
  <form
    onSubmit={(event) => {
      event.preventDefault();
      form.handleSubmit();
    }}
  >
    <FieldGroup>
      <form.AppField name="email">{(field) => <field.TextField label="Email" type="email" />}</form.AppField>
      <form.AppField name="password">{(field) => <field.PasswordField label="Password" />}</form.AppField>
      <form.SubscribeButton loadingText="Saving…">Save</form.SubscribeButton>
    </FieldGroup>
  </form>
</form.AppForm>;
```

When a wrapper does not exist for what you need, drop to `form.Field` and build the field body by
hand — `Field` + `FieldLabel` + control + conditional `FieldError`:

```tsx
<form.Field
  name="title"
  children={(field) => {
    const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
    return (
      <Field data-invalid={isInvalid || undefined}>
        <FieldLabel htmlFor={field.name}>Title</FieldLabel>
        <Input
          id={field.name}
          name={field.name}
          value={field.state.value}
          onChange={(event) => field.handleChange(event.target.value)}
          onBlur={field.handleBlur}
          aria-invalid={isInvalid || undefined}
          variant="muted"
        />
        {isInvalid && <FieldError>{String(field.state.meta.errors[0] ?? "")}</FieldError>}
      </Field>
    );
  }}
/>
```

## Rules

1. **Always wrap fields in `<form onSubmit>`.** It buys Enter-to-submit and accessibility. An
   empty `onSubmit` is fine when the page uses per-button mutations (a save/schedule/send trio).
2. **Every plain control sits in `Field` + `FieldLabel` + control + conditional `FieldError`.**
   No bare `Label` + `Input` pairs.
3. **`FieldError` takes the first error, coerced to string** —
   `{String(field.state.meta.errors[0] ?? "")}`. Errors may be Zod issues or strings depending on
   the validator.
4. **Composite field bodies** (audience builders, step cards, custom picker groups) own their own
   labels and do not need `Field`. Wrap the outermost form node only.
5. **`required` is opt-in — mark it, and pair it with a validator.** Every field wrapper defaults
   to `required={false}`. A genuinely mandatory field passes `required` explicitly *and* carries a
   validator, so the operator gets the inline `FieldError` rather than only the browser's native
   bubble — which a sheet's scroll container can hide. A field wrapper that defaults `required` to
   true makes optional fields unsaveable while showing no visible error; if a form will not submit
   and nothing is highlighted, suspect a `required` nobody meant to set.
6. **Use the prebuilt wrappers for common cases**, inline the anatomy when you need custom
   behaviour.

## Muted variant

`variant="muted"` is the default mental model for form inputs. Every `Input`, `Textarea`,
`Selector`, `DateTimePicker`, `InputGroup`, and combobox inside a `Card`, `Sheet`, `Dialog`, or
form section **must** be muted. Mixed variants in one form look broken even when each control is
individually valid.

**The wrappers already default to it — raw controls are the drift vector.** `form.AppField` +
`field.XField` is muted for free; what drifts is a control dropped into a `form.Field` by hand, or
a wrapper that shipped without the default.

Grep rule: a form control without `variant=`, in a file that renders a `Card` / `Sheet` /
`Dialog`.

Containers follow the same rule — a hand-rolled box around form content is `bg-muted/40` (see
`patterns.md`). A bordered box with no fill between muted inputs reads as a hole. Use the shared
switch/note/card primitives rather than writing the recipe again.

## Submit button

`SubscribeButton` subscribes to form state:

- `isSubmitting` — always disables the button and swaps the label for `loadingText`.
- `disableIfInvalid` (default `false`) — additionally disables when `!canSubmit || !isPristine`.
  Opt in where a save should be blocked until the user actually changes something.

## Escape hatch — every form needs a way back

A form the operator can dirty must offer a way to abandon the edit. Which primitive owns it
depends on what "cancel" means there — dismiss the container, or revert to server state. Never
hand-roll the row.

| Form lives in | Primitive | Cancel means |
| --- | --- | --- |
| Sheet | `SheetFormFooter type="edit\|create\|delete"` | dismiss the sheet |
| Dialog / AlertDialog | `DialogFooter` / `AlertDialogFooter` + outline Cancel | dismiss the overlay |
| `$id` page editor | `FormDirtyBar` (+ `useDirtyGuard`) | `form.reset()` — floating, dirty-gated |
| Card in a page body (settings tabs, security cards, accordion rows) | `FormCardActions` | `form.reset()` — inline row, dirty-gated |

Genuine exceptions, do **not** add a cancel: auth screens (no prior state and nowhere to return
to) and single-shot action forms that persist nothing (search, URL ingest, filter bars).

A `SubscribeButton` alone in a hand-written `<div className="flex justify-end">` inside a `Card`
is the drift signal — that div is `FormCardActions`.

## Validation

Validators are the Zod schemas from the resource's `{r}.schema.ts` — the same schemas the API
layer parses with. Do not write a parallel form-only schema.

For user-facing messages, use the schema factory pattern (`createXxxSchema(t)` with
`identityTranslate` as the default) so one schema serves both the API boundary and the localized
form.
