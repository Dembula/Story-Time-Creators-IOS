# App Store Connect — Create these In-App Purchases

Match **exactly** (product IDs used in the iOS binary):

| Product ID | Type | Purpose |
|---|---|---|
| `online.storytime.creators.sub.upload.yearly` | Auto-renewable subscription (group: Creator Plans) | Catalogue unlimited · yearly |
| `online.storytime.creators.sub.pipeline.monthly` | Auto-renewable subscription | Pipeline · monthly |
| `online.storytime.creators.sub.pipeline.yearly` | Auto-renewable subscription | Pipeline · yearly |
| `online.storytime.creators.upload.perfilm` | Consumable | Per-film upload fee (pay-per-film plan) |

**Pay per film** plan itself is free to select in-app (no IAP). Upload fee is required on each “Submit for review”.

Local testing: attach `Configuration.storekit` to the Xcode scheme (Run → Options → StoreKit Configuration).

**Backend deploy required:** ship `_ref-web/src/app/api/creator/ios/purchase/route.ts` to production so App Store transactions unlock licenses and content after purchase.
