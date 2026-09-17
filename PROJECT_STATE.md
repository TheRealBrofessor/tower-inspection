# PROJECT_STATE — Tower Inspection Field App

**Last updated:** 2026-09-16 (Hermes session)
**Orchestrator:** Hermes • **Builder:** Codex CLI (gpt-5.6-sol) • **Reviewer:** Claude Opus 5 (auth expired — pending re-login; cross-implementation audits performed by Hermes meanwhile)

## Current Milestone: 3 (Interactive Inspection) — in progress via Codex

## Environment (verified by execution)
- Flutter 3.47.4 stable @ /home/professor/flutter/flutter/bin (Dart 3.13.3)
- Project: /home/professor/tower-inspection (flutter create, org com.elitetower, platforms android+ios)
- Codex CLI 0.154.0 @ ~/.local/bin/codex (model gpt-5.6-sol, sandbox danger-full-access)
- Claude CLI 2.1.233 @ ~/.local/bin/claude — **OAuth session expired; `claude auth login` started (browser flow), needs user completion in desktop browser**
- Git repo initialized, milestone 0-1 committed (501645e)
- Android SDK present at ~/android-sdk (build capability to verify)
- No macOS/Xcode → iOS compile/signing NOT possible on this machine (documented limitation)

## Source of Truth
- Authoritative form: `docs/source_inspection_form.docx` (copy of "Blank inspection SS 4-03-26.docx")
- Canonical schema: `assets/canonical_form_schema.json` (templateVersion 1.0.0)
- Real completed report reference: `/home/professor/polk county/Cedartown Fairgrounds - Polk County Tower Inspection.docx`

## Extraction Audit Results (Hermes independent re-parse, 2026-09-16)
- Sections A–E: MATCH (5/5)
- Items: 18/18 MATCH, wording exact
- Photo blocks: 24/24 MATCH, continued-flags MATCH
- Statuses: 4 exact on all items
- Fixes applied post-audit:
  1. headerConvention now data-driven (siteName + ASR + page) — blank form header held example data ("Harmony Remote"/1322046)
  2. Added optional `address` site field (present in real completed reports)
  3. A.4 prefilledObservation confirmed IN the blank form → it is template default text, keep as such

## Report Fidelity Spec (measured from real report)
- Letter 8.5×11", photos ~3.33" squares, 2 per row
- Header: site name left | "ASR: {asr} Page {n}" right; Footer: Elite Tower, LLC / PO Box 30249 / Savannah, GA 31410
- Status row: 4 columns ☐/☑ selected
- Continuation tables: "{item} – Photographs (Continued)" for overflow photos

## Defects / TODO
- [ ] Codex building: domain models, schema loader, sqflite db, repository, list+detail screens, tests (M2-3)
- [ ] M4 camera system (3 default slots, add/manage photos)
- [ ] M5 offline recovery test (force-close/restart)
- [ ] M6 review/validation screen
- [ ] M7 PDF report engine (source-faithful, pdf package, continuation logic)
- [ ] M8 share (share_plus Android/iOS sheets)
- [ ] M9 Claude cross-platform audit (blocked on Claude auth)
- [ ] M10 full acceptance test incl. sample inspection + visual PDF comparison
- [ ] M11 release docs

## Decisions
- Flutter (per master prompt; no stronger alternative demonstrated)
- sqflite + sqflite_common_ffi for tests; parameterized SQL only
- pdf package for PDF generation (local, offline); DOCX deferred — evaluate after PDF fidelity is proven
- share_plus for native share sheets
- Status glyphs ☐/☑ preserved from source form for report fidelity
