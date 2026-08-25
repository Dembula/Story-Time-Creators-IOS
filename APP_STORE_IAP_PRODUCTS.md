# App Store Connect — Create these In-App Purchases

Match **exactly** (product IDs used in the iOS binary):

| Product ID | Type | Purpose |
|---|---|---|
| `online.storytime.creators.sub.upload.yearly` | Auto-renewable subscription (group: Creator Plans) | Catalogue unlimited · yearly |
| `online.storytime.creators.sub.pipeline.monthly` | Auto-renewable subscription | Pipeline · monthly |
| `online.storytime.creators.sub.pipeline.yearly` | Auto-renewable subscription | Pipeline · yearly |
| `online.storytime.creators.upload.perfilm` | Consumable | Per-film upload fee (pay-per-film plan) |

**Pay per film** plan itself is free to select in-app (no IAP). Upload fee is required on each “Submit for review”.

## Checklist before App Review (sandbox)

1. **Paid Apps Agreement** is Active (Business section).
2. Each product has **price**, **English localization** (display name + description), and is cleared for the version under review (Ready to Submit / Approved / Waiting for Review).
3. All four products share subscription group **Creator Plans** (consumable is outside the group).
4. Test with a **Sandbox Apple ID** on a device/TestFlight build (not only StoreKit Configuration).
5. After purchase, Confirm plan unlocks (banner “Finish your creator plan” dismisses). If Apple charged but the studio didn’t unlock, tap **Restore purchases** — the app re-sends the signed transaction to `POST /api/creator/ios/purchase`.

Local testing: attach `Configuration.storekit` to the Xcode scheme (Run → Options → StoreKit Configuration).

**Backend:** production must expose `POST /api/creator/ios/purchase` (Story-Time-Production). The iOS client sends StoreKit 2 JWS as `signedTransaction` / `signedTransactionInfo` / `jwsRepresentation` and never falls back to raw Transaction JSON.
