# ClipSafe

A local-first macOS clipboard history app. ClipSafe captures text copied to the macOS pasteboard and keeps a searchable history in your user Application Support directory.

## Features

- Menu bar popover
- Global shortcut: **Option + Command + V**
- Search clipboard history
- Copy an older item back to the clipboard
- Pin and delete individual entries
- Pause and resume monitoring
- Clear all history
- Local JSON storage; no account, cloud sync, telemetry, or network requests
- History retained until manually deleted (up to 1,000 entries in this initial version)

## Requirements

- macOS 13 or later
- Apple Silicon or Intel Mac
- Swift 5.9 or later
- Xcode is recommended. The Command Line Tools may be sufficient to compile, depending on the macOS SDK installed.

## Build and run

From this directory:

```sh
swift build
swift run
```

For a distributable `.app` bundle, use Xcode or create a signed/notarized release build. This initial repository is a source project, not a pre-signed application.

## Privacy notes

Clipboard contents can include secrets. ClipSafe stores captured text locally in:

`~/Library/Application Support/ClipSafe/history.json`

No clipboard content is sent over the network. History remains until you clear it, subject to the 1,000-entry cap. Pause monitoring before copying sensitive content. This first version does not yet provide per-app exclusions, encrypted storage, automatic secret detection, or a secure auto-expiring history.

Clipboard monitoring polls the macOS pasteboard approximately every 0.45 seconds. Clipboard changes made and replaced between polls may be missed. The source-app label is best-effort because the frontmost app can change before the poll runs.

## Keyboard shortcut

The app registers Option + Command + V as a global hotkey. If another application already owns that combination, the registration may fail; custom shortcut configuration is not implemented yet.

## Development

```sh
swift test
```

## Contributing

Issues and pull requests are welcome. Please include reproduction steps and tests for bug fixes.

## License

MIT. See [LICENSE](LICENSE).
