# Tower Inspection Field App

Cross-platform (Android + iOS) tower-site inspection app built with Flutter.
Replaces the paper/Word workflow: take photos in-app against each inspection item,
tap statuses, dictate/type observations, then generate a **source-faithful PDF report**
matching the existing "Tower Site Inspection Report" Word form — all offline.

## Install (Android, today)
`dist/TowerInspection-v1.0.0.apk` — signed release build. Copy to phone → open → allow install.
See `docs/android.md`.

## What it does
- **New Inspection** → fill Site Name / ASR / Prepared for / Address / Date
- 18 inspection items across sections A–E (STRUCTURE CONDITION, TOWER LIGHTING,
  ANTENNAS AND LINES, GROUNDING, CONCRETE CONDITION) — extracted from the authoritative
  source form `Blank inspection SS 4-03-26.docx` (kept at `docs/source_inspection_form.docx`)
- Per item: 4 clickable statuses (Okay / Possible Improvement / Needs Repair / Not Applicable),
  3 default photo slots + unlimited "Add Photo", observations field
- Everything **autosaves** to local SQLite (WAL, FK-enforced); survives app kill / reboot / power loss
- **Review** screen: errors (missing statuses/site fields) vs warnings (no photos, findings without
  comments); tap a finding to jump to the item
- **Generate report**: PDF that reproduces the original form structure — cover block, section
  headers, item wording, ☐/☑ status row, photo grid (2-per-row, 3.33″ boxes), observations column,
  continuation blocks "(Continued)" for photos 4+ — then **share** via the native Android/iOS share sheet
- 100% offline. No analytics, no network code, photos stay on-device.

## Project layout
```
assets/canonical_form_schema.json   ← versioned form structure (single source of truth)
lib/domain/    models               lib/data/     sqlite + photo storage + repository
lib/features/  inspections/camera/reviews/reports lib/core/     schema loader + theme
tool/fidelity_sample.dart           ← generates the sample fidelity PDF
```

## Development
```bash
export PATH=/home/professor/flutter/flutter/bin:$PATH
flutter analyze && flutter test          # 26+ tests
flutter run                               # device/emulator
dart run tool/fidelity_sample.dart out.pdf  # sample report
```

## Docs
`docs/architecture.md` · `docs/report-engine.md` · `docs/android.md` · `docs/ios.md` ·
`docs/FIELD_EVALUATION.md` — and `PROJECT_STATE.md` for status.

## Status (2026-09-16)
Milestones 0–8 complete: schema extraction (independently audited), app, camera, offline
recovery, review, PDF engine, share. Android debug+release APKs built and verified signed.
iOS project complete but needs a Mac/Xcode to compile (see docs/ios.md).
