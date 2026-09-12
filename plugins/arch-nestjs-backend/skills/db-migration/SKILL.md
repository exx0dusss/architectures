---
name: db-migration
description: Use when changing the database schema — adding or altering a table, column, index, constraint, enum, trigger, or partition, or when a migration fails to apply. Also use when tempted to reach for drizzle-kit push.
stacks: [nestjs-backend]
---

# Database migrations

**`generate` + `migrate`. `push` has no place in a repo with a migrations folder.**

`drizzle-kit push` diffs the schema files against the live database and applies immediately — no
review, no history. It cannot express `pg_trgm` GIN indexes, functional (`lower()`) indexes,
`CREATE EXTENSION`, or `tsvector` details, so it drifts from them and then offers to DROP them.
One `--force` wipes a search feature. Committed SQL files never diff the live database, which is
what makes drift structurally impossible.

Retire it rather than relying on discipline: point the `db:push` script at something that exits
non-zero with the reason. A command that still runs will be run.

[data-layer reference](../../reference/nestjs-backend/data-layer.md) is the doctrine. A repo with its own migrations doc outranks both
on anything specific to that database.

## The everyday loop

1. Edit the schema files.
2. `db:generate --name <change>` — writes `NNNN_<change>.sql` and updates the snapshot under
   `migrations/meta/`.
3. **Read the generated SQL.** Every time. Use the [migration review workflow](../../agents/migration-reviewer.md) directly, or the
   named agent when available — it derives
   which objects are hand-authored and must never be dropped.
4. Commit the SQL in the **same** changeset as the schema edit.
5. `db:migrate` locally. On deploy, migrations run before the app boots, under a Postgres advisory
   lock so N replicas starting at once cannot race, aborting the deploy if one fails.

## Objects drizzle-kit cannot generate

Extensions, functions, triggers, partitioning and its partition-ensuring function, and indexes
with modifiers the schema DSL cannot spell — `NULLS NOT DISTINCT`, partial `WHERE`, an operator
class. These are hand-written into migration SQL and deliberately kept **out of the schema files**,
so `generate` stays oblivious and never proposes dropping them.

Where the schema file must still declare something for typing, declare the plain form and treat
the SQL as authoritative. A generated `DROP` on that index is the classic false diff.

To add another:

```bash
db:generate --custom --name <thing>
```

Write the raw SQL into it, **and register the object in a DDL test** that greps the migrations
folder for each object and runs in the default test command. Skipping that registration leaves the
object unprotected against a future baseline squash — it disappears and nothing fails.

## Red flags

- `db:push`, `drizzle-kit push`, or "just sync the schema" → no review, no history
- a schema edit committed without its `.sql` → the next environment gets neither
- a generated `DROP` on an index, function or trigger nobody added in this change → almost
  certainly a hand-authored object
- `NOT NULL` added with no default and no backfill → fails on any non-empty table
- money as `numeric` or `float` → integers in the minor unit
- `serial` / `bigserial` primary key → UUID v7 via the shared helper
- `timestamp` without time zone → `timestamptz`
- a custom migration with no entry in the DDL test

## Backfills

A backfill is a migration, not a script someone remembers to run. Keep them beside the other
migration tooling under one recognisable prefix, and state in the pull request whether the
backfill is idempotent and what it costs on production-sized data.
