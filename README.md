# ClipSafe

ClipSafe is a lightweight clipboard history app for macOS, built with Swift, SwiftUI, and AppKit.

## Features

- Automatically tracks clipboard changes.
- Searchable clipboard history.
- Persistent history across app restarts.
- Seven-day history retention.
- Pin and restore clipboard entries.
- Pause and resume monitoring.
- Delete individual entries or clear all history.
- Global Option + Command + V keyboard shortcut.
- Local JSON storage, capped at 1,000 entries.

## Requirements

- macOS
- Swift and Swift Package Manager

## Build from source

Clone the repository:

```bash
git clone https://github.com/henrymorgan5/ClipSafe.git
cd ClipSafe
swift build -c release
```

The release executable is created at `.build/release/ClipSafe`.

## Data and privacy

Clipboard history is stored locally at:

`~/Library/Application Support/ClipSafe/history.json`

Entries older than seven days are removed during history loading and saving. Pinned entries are also subject to this retention period.

**Important:** History is stored as unencrypted JSON. Avoid copying passwords or other confidential information while monitoring is enabled.

ClipSafe does not implement cloud synchronisation.

## Testing

Manual testing has confirmed:

- History persists after restarting.
- Clipboard monitoring can be paused.
- Individual entries can be deleted.
- All history can be cleared.
- The keyboard shortcut works.

These are manual test results; automated tests have not been confirmed as passing.

## Contributing

Bug reports, feature suggestions, and pull requests are welcome. Please test changes before submitting a pull request.

## License

See [LICENSE](LICENSE) for the project's license.