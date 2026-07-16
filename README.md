# Story Time Creators (iOS)

Native SwiftUI creator portal for [Story Time](https://story-time.online), built to mirror the web creator experience — without marketplace payments.

## Open & run

1. On a Mac, open `StoryTimeCreators.xcodeproj` in Xcode 16+.
2. Select your **Team** under Signing & Capabilities.
3. Confirm **Sign in with Apple** is enabled (entitlements already included).
4. Run on an iPhone simulator or device (iOS 17+).

Privacy usage strings are left to Xcode’s automatic generation (`GENERATE_INFOPLIST_FILE`). A small `OAuthURLTypes.plist` only registers the `storytimecreators://` callback scheme for Apple/Google/GitHub OAuth.

## What you get

- Orange Creators splash + app icon branding
- Email/password creator sign-in (NextAuth `credentials-creator`)
- Sign in with Apple (native button + NextAuth Apple OAuth), plus Google/GitHub
- Side menu that **auto-closes** when a destination is selected (swipe from left edge supported)
- Command Center, Projects, Network, Messages, Account
- Catalogue, upload draft (no checkout), revenue
- Originals
- Full pre / production / post pipeline tool hubs wired to `/api/creator/projects/...`
- Casting, crew, locations, equipment, catering, music, legal inbox — **browse, roster, inquire/request only**
- Floating VA (MODOC) chat panel streaming from `/api/modoc/chat`

## API

All traffic goes to `https://story-time.online` with session cookies (same auth as the web creator portal).

Configure the base URL in `StoryTimeCreators/Core/Network/AppConfig.swift` if you need a staging host.

## Payments intentionally disabled

These web flows are **not** available in the app (tools remain usable without paying):

- Marketplace checkout (`/*/pay`)
- Audition listing / confirm-hire fees
- Executive paid script review
- Catalogue upload fee / license purchase
- IP marketplace purchase
- Wallet top-up / PayFast card flows

Creators can still manage cast/crew rosters, browse vendors, and send inquiries or booking requests.

## Project layout

```
StoryTimeCreators/
  App/                 Entry + root routing
  Core/                Auth, API client, models, theme
  Features/            Screens (shell, tools, marketplace, VA)
  Resources/           Assets (SplashLogo, AppIcon)
```

## Demo accounts

Use the same creator demo accounts as the web app (see Story-Time-Production `DEMO_ACCOUNTS.md`), e.g. password `storytime2025`.
