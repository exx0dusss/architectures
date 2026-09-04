# Component source routing

Composition starts from component's owning system. Name and appearance are insufficient: provider
contract defines anatomy, accessibility, state, responsive behavior, and supported composition.

## Resolve before composing

For each major primitive or pattern—sheet, dialog, table, command menu, form, chart, carousel:

1. Identify local implementation and its provider from imports, registry config, package manifest,
   or component source.
2. Load provider-specific skill when installed. A consumer mapping may point to vendored or package
   skill; use it instead of relying on memory.
3. Read project configuration through provider's supported project-context command. MCP may expose
   registry items without knowing local aliases, framework, base primitive, or installed state.
4. Use provider MCP to search registry, view full item source, and fetch examples when those tools
   exist. Use official docs for API reference outside MCP's registry contract.
5. Inspect local wrapper and at least one existing usage. Local wrapper may intentionally narrow or
   extend upstream contract.
6. Compose using intersection: upstream contract plus local wrapper plus product conventions.

## shadcn route

shadcn separates project context from registry access:

1. Load official shadcn skill.
2. Run `npx shadcn@latest info --json` for local style, base primitive, aliases, framework, and
   installed component state. shadcn MCP has no equivalent.
3. Call `shadcn:view_items_in_registries` for exact item source.
4. Call `shadcn:get_item_examples_from_registries` for demos and composition examples. Use
   `shadcn:search_items_in_registries` first only when item is unknown.
5. Inspect local component file and existing product usage.

For Sheet, registry/docs define it as Dialog extension with composition
`Sheet > SheetTrigger + SheetContent > SheetHeader(Title, Description) + SheetFooter`; content also
owns side and close-button options. Project's selected Base UI, React Aria, or Radix implementation
then determines underlying API and trigger composition. Read matching API reference rather than
mixing variants.

## Source priority

1. Consumer's explicit conventions and wrapper contract.
2. Installed provider skill and project-context command.
3. Provider registry source and examples through MCP.
4. Provider's matching official API documentation.
5. Existing consumer usages.
6. General visual-language doctrine.
7. External galleries as visual hypotheses only.

Higher source owns API and product constraints. Lower source can improve composition without
contradicting it.

## Evidence

Record major component sources in handoff: provider skill loaded, MCP/doc query performed, local
wrapper inspected, and exemplar usage inspected. If provider capability is unavailable, state gap
and use official docs or local source rather than silently guessing.
