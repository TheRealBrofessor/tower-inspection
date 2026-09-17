# Report Engine Specification — Source-Faithful PDF

**Source of truth:** `docs/source_inspection_form.docx` + real completed report (`Cedartown Fairgrounds - Polk County Tower Inspection.docx`). All measurements below are extracted from those documents — not invented.

## Page Geometry
- US Letter: 8.5" × 11"
- Photos: ~3.33" × 3.33" squares, **2 per row** (measured: 3.31–3.36" in real report)
- Photo grid: left column of item table

## Page Header (data-driven)
- Left: `{siteName}` + inspection date (source header shows site name; blank form's "Harmony Remote" is placeholder data)
- Right: `ASR: {asr}` and `Page {n}` (footer area contains page number in source: "Page PAGE" field)
- Every page of the body carries this header (Word header1.xml applies to all pages)

## Page Footer (fixed, from source)
```
Elite Tower, LLC
PO Box 30249
Savannah, GA 31410
```

## Cover Block (page 1, before section A)
```
Tower Site Inspection Report

Site Name: {siteName}
ASR: {asr}
Prepared for: {preparedFor}
Address: {address}          ← optional; line omitted if empty

Elite Tower, LLC
PO Box 30249
Savannah, GA 31410

Date of Inspection: {inspectionDate}
```
(Exactly the paragraph sequence from source document.xml, with live values substituted.)

## Per-Item Layout (faithful to source tables)
For each inspection item (A.1 … E.1, in template order):

1. **Section header** (when entering a new section): `A.  STRUCTURE CONDITION` — bold, full-width
2. **Item line**: `{fullLabel}` e.g. `A.1 Rust - Check structure for rust.` (exact schema wording)
3. **Status row** — 4 equal columns:
   `☐ Okay | ☐ Possible Improvement | ☐ Needs Repair | ☐ Not Applicable`
   Selected status renders `☑` instead of `☐` (convention verified in real report)
4. **Two-column body**: left = photo grid, right = `Observations and Recommendations` + comment text
5. **Photos fill left column 2-per-row at 3.33"**; preserve aspect ratio, never distort; center-crop to square only if derivative allows (or letterbox — prefer fit-within to avoid distortion)
6. **Continuation rule** (from source structure): each item has photo blocks — main block `{iid}.1 {title} - Photographs` then, when photos overflow the block's capacity (3 per the field-app default: photos 1-3 in main block), continuation block `{iid}.2 {title} – Photographs (Continued)` carries photos 4-6, then further continuation pages `{iid}.3 … (Continued)` for 7-9, etc. Block numbering follows the source convention: `{iid}.{n}`.
7. Empty photo slots: in the OFFICIAL export, if an item has fewer photos than slots in a started block, render the remaining slots as empty boxes (keeps the form's structure, per master prompt §21). If an item has zero photos, the photo block header still renders with empty box(es) — matching blank-form structure.

## Statuses & glyphs
- Unselected: `☐` (U+2610), Selected: `☑` (U+2611)
- A.4 prefilled observation is template default text — render it if user hasn't replaced it (verify: schema prefilledObservation is seeded as the comment on creation)

## Renderer Architecture
```
canonical schema + inspection tree (domain objects)
        ↓ lib/features/reports/report_renderer.dart (pure Dart: builds a layout model)
layout model (pages -> blocks -> elements)
        ↓ lib/features/reports/pdf_composer.dart (pdf package: draws layout model)
PDF file (app documents dir /reports/{inspectionId}/{timestamp}.pdf)
        ↓ printing package layout preview + share_plus native sheet
```
- Renderer is UI-independent (testable without Flutter widgets)
- Continuation logic lives in the layout model, unit-testable
- Photo embeds use report_path derivative (~1000px JPEG q80) to keep PDFs reasonable; originals never modified

## Test Strategy (M7 acceptance)
1. Unit: layout model — item order, status mapping, continuation math (1 photo → 1 block; 3 photos → 1 block; 4 → 2 blocks; 6 → 2; 7 → 3), empty-slot rendering
2. Golden-ish: generate sample inspection PDF with 1/3/4+/6 photos per item + long comments; render pages to PNG (pdftoppm) and compare against source docx page structure
3. Claude Opus 5 independent fidelity review once auth is restored
