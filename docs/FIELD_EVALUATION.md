# Field evaluation checklist

This is a private, controlled evaluation procedure for Tower Inspection. It is not a release or a customer deployment. Use fictional inspection data only until the ownership and data-handling review is complete.

## Before the evaluation

- Use a test device and a current debug build from the repository. Do not redistribute the older signed APK in `dist/`.
- Run `flutter analyze` and `flutter test`. Record the results; do not mark them passed without executing them.
- Keep the device offline for the inspection workflow. The app is intended to work without a connection.
- Do not import an employer's inspection form, customer information, site photographs, or other proprietary records into a shareable demo.
- Use a fictional site name, fictional address, and clearly synthetic ASR identifier.

## Five-minute evaluator path

1. Open the app and create a new inspection with fictional site details.
2. Open an inspection item in each section. Choose a status and add a short observation.
3. Add one photo of an ordinary non-sensitive object using the device camera. Confirm that the photo appears on the correct item.
4. Close the app and reopen it. Verify that the site details, statuses, observations, and photo remain available without network access.
5. Open Review. Confirm missing required information is reported as an error and missing supporting evidence is identified as a warning where applicable.
6. Complete the required fields, generate a PDF, and inspect the cover, section headings, item labels, statuses, observations, photo placement, and page breaks.
7. Open the device share sheet, but share only with an evaluator you have explicitly authorized.

## Record evidence

| Check | Expected result | Actual result / device |
| --- | --- | --- |
| App opens | No crash | |
| Offline entry | Fields and statuses work offline | |
| Photo attachment | Photo associated with correct item | |
| Restart recovery | Saved data remains intact | |
| Review | Missing fields and warnings are understandable | |
| PDF generation | Opens and preserves entered information | |
| Native share | Share sheet opens; no unexpected upload | |

Record device model, Android version, app commit, and the exact steps for any failure. Remove test photographs from shared artifacts unless permission to share them is explicit.

## Release and pilot blockers

This checklist does not certify the app for public distribution. Before any external pilot, rotate the Android signing key, audit full Git history for credentials and keystores, confirm rights to the underlying form/template, sanitize all sample records and PDFs, and verify the actual release build on target devices. The iOS build must be tested separately on a supported Mac/Xcode environment.

Do not represent the app as production-ready until those checks are complete.
