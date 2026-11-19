# PROJECT_STATE — Tower Inspection

**Last updated:** 2026-11-18

## Current status

The existing Flutter application remains an offline-first field workflow with
SQLite persistence, 18 canonical inspection items, camera/gallery capture,
review validation, PDF generation, and native sharing. Android debug and iOS
unsigned CI workflows have passed on the current `main` baseline.

This stabilization branch adds serialized autosave writes and removes silent
PDF observation clipping. These changes are intended for controlled evaluation,
not a production-readiness declaration.

## Verified implementation

- Canonical schema: five sections and 18 items, loaded from
  `assets/canonical_form_schema.json`.
- Persistence: SQLite WAL mode, foreign keys, migrations, inspection/photo
  deletion cleanup, close/reopen recovery tests, and deletion that remains
  successful even when optional local file cleanup encounters an error.
- Media: original and report derivatives are tracked separately; replacement
  and deletion remove associated stored files through the photo storage layer.
- Reports: status rows, cover/site/ASR fields, ordered photo blocks, continued
  photo blocks, missing-photo boxes, and long observations are covered by
  automated tests.
- CI: Android analyze/tests/debug APK and iOS analyze/tests/unsigned build
  workflows are configured. Local Flutter execution is environment-dependent.

## Release and field blockers

- No physical Android/iOS field evaluation has been completed in this pass.
- The historical Android signing credential is compromised; rotate the key and
  do not reuse it. History has not been rewritten automatically.
- Rights to the source inspection form and hardcoded contractor branding must
  be confirmed before external distribution.
- Release signing, target-device permissions, force-close recovery, native
  sharing, and visual report fidelity require independent device verification.

## Commercial architecture direction

Keep the current inspection repository and schema stable while adding future
capabilities behind explicit boundaries:

1. Versioned templates and organization branding.
2. Export/backup packages with schema and media manifests.
3. Supervisor review and approval records.
4. Optional sync adapters above the offline repository.
5. Separate drone-imagery and assisted-finding ingestion adapters.

Cloud sync, drone auditing, AI findings, and automated audit workflows are
future work and are not represented as existing functionality.
