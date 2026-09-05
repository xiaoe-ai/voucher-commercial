# Commercial Migration Channel V1 — Fixed Report

Status: ACTIVE / MANUAL-ONLY
Date: 2026-09-05
Repository: `xiaoe-ai/voucher-commercial`
Commercial Supabase project ref: `hukihbcyyqhanaqrizvm`

## Purpose

Provide a reusable, stable migration path for Commercial Voucher without recreating Supabase CLI links or temporary access tokens each time.

This channel is for schema/data migration SQL files stored under `supabase/migrations/`.

It is NOT the normal XiaoE application management channel. Normal runtime operations continue through the XiaoE Commercial gateway/bridge route.

## Canonical connection

Connection type: Supabase Session Pooler / PostgreSQL / `psql`

- Host: `aws-0-ap-southeast-1.pooler.supabase.com`
- Port: `5432`
- Database: `postgres`
- User: `postgres.hukihbcyyqhanaqrizvm`
- SSL: required
- Project ref lock: `hukihbcyyqhanaqrizvm`

Password is never stored in this repository. The workflow reads it only from GitHub Actions secret:

`SUPABASE_DB_PASSWORD`

## Workflow

File:

`.github/workflows/commercial-migration-channel.yml`

Trigger:

`workflow_dispatch` only.

Normal pushes do not run database migrations.

Inputs:

1. `migration_path` — exact `.sql` file under `supabase/migrations/`
2. `mode` — `dry_run` or `apply`
3. `confirmation` — required for apply; must equal `APPLY-COMMERCIAL-HUKIH`

## Execution sequence

1. Lock and verify Commercial project/host/user/database values.
2. Verify `SUPABASE_DB_PASSWORD` is present without printing it.
3. Validate that the requested file is an exact SQL file under `supabase/migrations/` and reject path traversal.
4. Print the migration SHA-256 for traceability.
5. Verify live Session Pooler connection.
6. Run the migration inside a transaction and force `ROLLBACK`.
7. If mode is `dry_run`, stop after successful rollback.
8. If mode is `apply`, require exact confirmation string.
9. Re-run migration transactionally and `COMMIT` only if every SQL statement succeeds.
10. Run a final connection check.

## Safety rules

- Commercial-only route.
- No Production/Stage/Daughter project refs are accepted by the fixed workflow values.
- No Supabase management access token is required.
- No password or URI containing the password may be committed to GitHub.
- Apply is never automatic.
- Dry-run always happens before apply.
- SQL errors abort the transaction via `ON_ERROR_STOP=1`.
- Only one Commercial migration workflow may execute at a time through GitHub Actions concurrency control.

## Relationship to XiaoE

Runtime management remains:

`XiaoE -> commercial-invoke-gateway -> external-supabase-bridge -> xiaoe-voucher-bridge -> Commercial DB`

Migration management is separate:

`GitHub manual workflow -> Supabase Session Pooler -> Commercial PostgreSQL`

The two paths are intentionally separated so normal XiaoE operations cannot accidentally perform arbitrary schema migrations.

## Verified origin

The Session Pooler route was live-tested on 2026-09-05 during the Company Profile migration.

The successful sequence was:

- Connection verification: PASS
- Transactional rollback dry-run: PASS
- Transactional apply: PASS
- Company Profile read through XiaoE bridge after migration: HTTP 200
- Commercial bridge health after migration: HTTP 200

## Required secret lifecycle

`SUPABASE_DB_PASSWORD` must remain present in GitHub Actions secrets if this migration channel is expected to be immediately usable.

If the database password is rotated, update the GitHub secret before the next migration. The non-secret host/port/database/user values normally remain unchanged unless Supabase changes the project pooler endpoint.

## Operating rule

For future Commercial Voucher migrations, reuse this channel rather than rebuilding a temporary migration workflow.

Recommended process:

`Create migration SQL -> manual dry_run -> review -> manual apply with confirmation -> verify via XiaoE bridge/health`
