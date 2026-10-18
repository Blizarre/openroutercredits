# OpenRouter Credits — macOS Menu Bar Widget

## Decisions
- Native SwiftUI, macOS 14+, local Xcode build
- Menu-bar-only app (`LSUIElement`, no Dock icon)
- Menu bar: `creditcard.fill` icon + `$12.34` (monospaced digits, tooltip)
- Popover: balance, last updated/stale state, refresh, open OpenRouter, settings, quit
- OpenRouter **management API key**, stored in Keychain
- Refresh every 5 minutes + low-balance notification
- USD formatting

## Data source
- `GET https://openrouter.ai/api/v1/credits`
- Header: `Authorization: Bearer <management-key>`
- Response: `{ "data": { "total_credits": 100.5, "total_usage": 25.75 } }`
- Remaining = `total_credits - total_usage`, decoded as `Decimal`
- Management key from https://openrouter.ai/settings/management-keys
- Error mapping: 401 invalid/expired key, 403 not a management key, 500 retry/backoff

## UX
### Menu bar
- SF Symbol `creditcard.fill` + formatted USD balance
- Tooltip with full balance and last update time

### Popover
- Large balance, last updated / stale / error state
- Refresh, Open OpenRouter, Settings, Quit

### Settings
- "OpenRouter management API key" secure field, Save + Test Connection
- Low-balance threshold, default $5
- Launch at login toggle
- Refresh interval shown as 5 minutes
- Keychain explanation (local only, never logged)

### Notifications
- Low-balance notification once per downward threshold crossing
- In-app warning remains visible as a fallback if notifications are unavailable

## Architecture
```
OpenRouterCredits/
  OpenRouterCreditsApp.swift      # MenuBarExtra + Settings scene
  AppDelegate.swift               # accessory app, wake notifications, app lifecycle
  Models/
    CreditsSnapshot.swift
    CreditsResponse.swift
  Services/
    OpenRouterAPIClient.swift     # only file that knows the endpoint
    KeychainStore.swift
    CreditsStore.swift            # @Observable state + refresh loop
    NotificationService.swift
    LowBalanceTracker.swift
    LaunchAtLoginController.swift
  UI/
    MenuBarLabel.swift
    PopoverView.swift
    SettingsView.swift
  Resources/Assets.xcassets
  Info.plist                      # LSUIElement = true
  OpenRouterCredits.xcodeproj     # checked-in Xcode project
```

- `CreditsStore` owns balance, loading, error, last-updated, refresh scheduling
- Keychain: `kSecClassGenericPassword`, accessible after first unlock
- No key in UserDefaults, logs, crash reports, or URLs
- Refresh on wake and on popover open if stale; no overlapping requests
- Backoff on 429/5xx/network errors
- Low-balance notification once per downward threshold crossing

## Phases
1. Xcode project, menu-bar app, settings shell
2. Keychain + API client + balance display
3. 5-minute refresh, wake refresh, popover, stale state
4. Low-balance notification + launch at login
5. Tests, app icon, README, polish

## Tests
- Money formatting (zero, large, negative)
- JSON decoding with missing optional fields
- Error mapping: 401, 403, 500, offline
- Threshold-crossing notification logic
- Manual: no key, bad key, expired key, sleep/wake, offline, multiple displays, menu bar truncation

## Risks
- Management key is account-level admin: Keychain only
- Notifications on unsigned local builds may be unreliable; fall back to in-app warning
- Menu bar width: compact format + tooltip, optional icon-only mode later

## Not in scope
- Multiple accounts/workspaces
- Usage history or charts
- Auto-update
- Always-on-top floating panel

## Diagnostic
- `check-credits.sh` prompts for the key and prints total credits, total usage, and remaining
