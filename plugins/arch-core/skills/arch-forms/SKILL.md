---
name: arch-forms
description: Use when building or changing any form — adding a field, wiring validation, handling submit, marking a field required, adding a cancel or submit button, or building a multi-step wizard. Also use when a form will not submit and no error is visible, field errors from the server are not reaching their fields, inputs in one form look inconsistent, or someone is about to import useForm from @tanstack/react-form.
stacks: [nextjs, tanstack-start]
---

# Forms

Before stack detection, read [owning-workspace routing](../../reference/agent-workflows/context-routing.md).
Here `package.json` and local conventions mean the target's owning workspace, not necessarily
repository root. Unsupported sibling stacks do not inherit this skill.

**Applies only to repos built on the `exx0dusss/architectures` blueprint.** If this repo has no
`docs/architecture/` directory and no `AGENTS.md` naming one of these stacks, this skill does not
apply — stop and ignore it.

One factory, one way to build a form. `createFormHook` in `hooks/form` exports `useAppForm` with
the field components and submit button already bound — that binding is the entire reason the
factory exists.

## Read the reference for this repo's stack

| `package.json` has | Read |
| --- | --- |
| `next` | `../../reference/nextjs/forms.md` |
| `@tanstack/react-start` | `../../reference/tanstack-start/forms.md` |

If the repo has its own `docs/architecture/forms.md` or `docs/conventions/forms.md`, read that
instead — a consumer's local instantiation outranks the blueprint.

## Adding a field type

Add the component under `components/form/`, then register it in the `fieldComponents` map in
`hooks/form`. One registration, available in every form. Never build a one-off field inside a
route's component folder.

## Red flags — stop and re-read the reference

- `useForm` imported from `@tanstack/react-form` → use `useAppForm`; a raw `useForm` has no field context, so no registered component is reachable
- A one-off field component inside a route folder → register it in `fieldComponents` instead
- A form-only Zod schema written alongside the resource's → reuse the resource schema; a parallel schema drifts
- A hardcoded user-facing message in a validator → schema factory pattern, `createXxxSchema(t)` with `identityTranslate` default
- Fields not wrapped in `<form onSubmit>` → loses Enter-to-submit and accessibility
- A field marked `required` without a validator → the operator gets only the browser's native bubble, which a scroll container can hide. **A form that will not submit while showing no visible error is almost always a `required` nobody meant to set**
- A raw millisecond literal for an availability-check query → use the named gc-time constant
- **(Next.js)** a submit handler treating a server action as throwing → actions return `ApiResult<T>`; branch on `result.ok` and map `result.error.fieldErrors` onto the matching fields
- **(Next.js)** invalidation hand-written in a submit handler → declare it in mutation `meta`
- **(Next.js)** wizard state lifted through layouts → keep step values in a store, each step its own route so the back button works
- **(Next.js)** `File` objects in a persisted wizard store → they do not survive JSON; persist metadata only
- **(TanStack Start)** a bare `Label` + `Input` pair → `Field` + `FieldLabel` + control + conditional `FieldError`
- **(TanStack Start)** a form control without `variant="muted"` inside a `Card`/`Sheet`/`Dialog` → mixed variants in one form look broken even when each control is individually valid
- **(TanStack Start)** `FieldError` rendering the raw errors array → take the first and coerce: `{String(field.state.meta.errors[0] ?? "")}`
- **(TanStack Start)** a `SubscribeButton` alone in a hand-written `<div className="flex justify-end">` inside a `Card` → that div is `FormCardActions`
- **(TanStack Start)** a dirtyable form with no way back → use the escape-hatch primitive for its container; only auth screens and single-shot action forms are exempt
