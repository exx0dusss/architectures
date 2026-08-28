---
name: form-migrator
description: Migrate manual useState forms to TanStack Form with Zod validation
---

> **ARCHIVED (2026-08): completed-migration artifact.** The migration this agent drove is finished in every consumer repo. Kept for reference only — do not copy it into new projects.

# Form Migrator Agent

Convert manual `useState` + `handleChange` form patterns to TanStack Form with Zod v4 validation.

## Detection

Look for these patterns indicating a manual form:

```ts
// Manual form state
const [form, setForm] = useState<FormData>(initial)
const [errors, setErrors] = useState<Record<string, string>>({})

// Manual change handler
const handleChange = (field: string, value: string) => {
  setForm(prev => ({ ...prev, [field]: value }))
}

// Manual validation
function validateForm(form: FormData) {
  const errors: Record<string, string> = {}
  if (!form.name) errors.name = "Required"
  return errors
}
```

## Migration Steps

### 1. Replace useState with useForm

```ts
// BEFORE
const [form, setForm] = useState(initialForm)
const [errors, setErrors] = useState({})

// AFTER
import { useForm } from "@tanstack/react-form"

const form = useForm({
  defaultValues: initialForm,
  validators: { onSubmit: formSchema },
  onSubmit: async ({ value }) => { /* handle submit */ },
})
```

### 2. Replace manual fields with form.Field

```tsx
// BEFORE
<Input value={form.phone} onChange={(e) => handleChange("phone", e.target.value)} />
{errors.phone && <span>{errors.phone}</span>}

// AFTER
<form.Field name="phone" children={(field) => (
  <Field data-invalid={!field.state.meta.isValid || undefined}>
    <FieldLabel>Телефон</FieldLabel>
    <Input
      value={field.state.value}
      onChange={(e) => field.handleChange(e.target.value)}
      onBlur={field.handleBlur}
      aria-invalid={!field.state.meta.isValid || undefined}
    />
    {!field.state.meta.isValid && <FieldError errors={field.state.meta.errors} />}
  </Field>
)} />
```

### 3. Replace manual validation with Zod schema

```ts
// BEFORE (manual)
function validateForm(form) {
  if (!form.phone) errors.phone = "Required"
}

// AFTER (Zod v4 schema as validator)
import { z } from "zod/v4"

const formSchema = z.object({
  phone: z.string().regex(/^\+380\d{9}$/, { error: "Невірний номер" }),
  firstName: z.string().min(2, { error: "Мінімум 2 символи" }),
})

const form = useForm({
  validators: { onSubmit: formSchema },
})
```

### 4. Replace manual submit with form.handleSubmit

```tsx
// BEFORE
<button onClick={handleSubmit}>Submit</button>

// AFTER
<form.Subscribe
  selector={(s) => [s.canSubmit, s.isSubmitting]}
  children={([canSubmit, isSubmitting]) => (
    <button onClick={() => form.handleSubmit()} disabled={!canSubmit}>
      {isSubmitting ? "..." : "Submit"}
    </button>
  )}
/>
```

### 5. Delete manual validation function

Remove the hand-rolled `validateForm()`, manual `setErrors()`, and error clearing logic.

## Linked Fields

For password confirmation or dependent fields:

```tsx
<form.Field name="confirm" validators={{
  onChangeListenTo: ['password'],
  onChange: ({ value, fieldApi }) =>
    value !== fieldApi.form.getFieldValue('password') ? 'Mismatch' : undefined,
}} />
```

## Rules

- Import Zod from `"zod/v4"`
- Use `{ error: "..." }` for Zod error messages
- Use `z.email()` not `z.string().email()`
- Wire errors to shadcn `<FieldError errors={field.state.meta.errors} />`
- Use `form.Subscribe` for submit button state
- Delete ALL manual validation code after migration
