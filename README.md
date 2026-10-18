# OpenRouter Credits

A macOS 14+ menu bar widget that shows the remaining balance of an OpenRouter
account. The app uses the OpenRouter management API and stores the management
key only in the macOS Keychain.

## Requirements

- macOS 14 or later
- Xcode 16 or later (developed with Xcode 27)
- An OpenRouter **management API key** from
  <https://openrouter.ai/settings/management-keys>

## Build and run

```sh
make build   # build the app into .build/Build/Products/Debug
make test    # run the unit tests
make run     # build and launch the menu bar app
```

The project is a checked-in Xcode project, so opening
`OpenRouterCredits.xcodeproj` in Xcode also works.

## Development status

This project is being implemented in phases. See `PLAN.md` for the full design.
