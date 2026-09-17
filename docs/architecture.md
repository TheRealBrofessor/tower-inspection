# Architecture

## Stack
- **Flutter 3.47.4 stable** (Dart 3.13.3), single codebase, Android + iOS
- **State:** `provider` (ChangeNotifier `InspectionBloc`) — deliberately no heavier framework for a focused field app
- **Persistence:** `sqflite` (SQLite, WAL journal, foreign keys ON, versioned migrations via `schema_version` + `onUpgrade`)
- **Camera:** `image_picker` (native camera), `permission_handler` (runtime permissions)
- **Images:** `image` package for report derivatives (~1000px JPEG q80); originals preserved untouched
- **Report:** `pdf` package (pure-Dart, offline), `printing` for preview, `share_plus` for native share sheets

## Layering (strict, UI-independent core)
```
assets/canonical_form_schema.json   ← single source of truth for form structure
        │
lib/core/schema/schema_loader.dart  ← parse + validate (dup ids, empty statuses)
        │
lib/domain/models.dart              ← InspectionTemplate/Section/Item, Inspection,
        │                            ItemResponse, PhotoAttachment, Report
lib/data/                           ← database.dart (migrations), inspection_repository.dart,
        │                            photo_storage.dart  — all SQL parameterized
lib/features/                       ← UI: inspections/ (list, detail, bloc),
        │                            camera/, reviews/, reports/ (renderer UI-independent)
lib/main.dart                       ← providers + MaterialApp + theme
```

## Key flows
- **Autosave:** every status tap, site-field edit, photo op persists immediately (fire-and-forget); comments debounce 300ms + flush on dispose
- **Offline-first:** zero network code in the app; DB + photos live in app documents dir
- **Crash recovery:** repository reloads full state from SQLite on open; nothing critical is memory-only

## Report path (UI-independent, per docs/report-engine.md)
```
domain objects → report_renderer (layout model: pages/blocks/elements,
                 continuation math) → pdf_composer (pdf package) → file
```
The layout model is pure Dart → unit-testable without widgets.

## Data model (SQLite v1)
- `inspections` (id TEXT PK, template_version, site fields, status, timestamps)
- `item_responses` (inspection_id, item_id → composite PK; status, comments)
- `photo_attachments` (id PK, inspection_id, item_id, order_index UNIQUE(inspection,item,order), original_path, report_path, captured_at, metadata_json)
- `reports` (generated report records)

## Platform isolation
- Platform-specific code confined to: permission prompts, camera plugin, share sheet, file paths — all behind repository/service interfaces. Android manifest + iOS Info.plist carry only camera/storage permission strings.
