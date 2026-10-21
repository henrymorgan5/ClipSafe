
import AppKit
import SwiftUI
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var model = ClipboardModel()
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: "ClipSafe"
            )
            button.toolTip = "ClipSafe clipboard history"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: ClipboardView(
                model: model,
                closeAction: { [weak self] in self?.closePopover() }
            )
        )

        model.startMonitoring()
        registerGlobalShortcut()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func togglePopoverFromShortcut() {
        DispatchQueue.main.async { [weak self] in
            self?.togglePopover(nil)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func registerGlobalShortcut() {
        let hotKeyID = EventHotKeyID(
            signature: OSType(0x43534C46),
            id: 1
        )
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }

                var pressedID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedID
                )

                if status == noErr && pressedID.id == 1 {
                    let app = Unmanaged<AppDelegate>
                        .fromOpaque(userData)
                        .takeUnretainedValue()
                    app.togglePopoverFromShortcut()
                }

                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )

        // Option + Command + V
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stopMonitoring()
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
}

struct ClipboardEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var copiedAt: Date = Date()
    var sourceBundleID: String?
    var isPinned: Bool = false
}

@MainActor
final class ClipboardModel: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published var isMonitoring = true
    @Published var searchText = ""

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let pasteboard = NSPasteboard.general
    private let maxEntries = 1000
    private let retentionInterval: TimeInterval = 7 * 24 * 60 * 60

    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let directory = appSupport.appendingPathComponent(
            "ClipSafe",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("history.json")
    }()

    init() {
        load()
    }

    var filteredEntries: [ClipboardEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.text.localizedCaseInsensitiveContains(query)
        }
    }

    func startMonitoring() {
        guard timer == nil else { return }

        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.45,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            lastChangeCount = pasteboard.changeCount
        }
    }

    private func checkClipboard() {
        guard isMonitoring else { return }

        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        // Avoid consecutive duplicate entries.
        guard entries.first?.text != text else { return }

        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let entry = ClipboardEntry(text: text, sourceBundleID: source)

        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        save()
    }

    func restore(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    func togglePin(_ entry: ClipboardEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id })
        else {
            return
        }

        entries[index].isPinned.toggle()
        sortEntries()
        save()
    }

    func delete(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clearHistory() {
        entries.removeAll()
        save()
    }

    private func sortEntries() {
        entries.sort {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.copiedAt > $1.copiedAt
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode(
                [ClipboardEntry].self,
                from: data
              )
        else {
            return
        }

        let cutoff = Date().addingTimeInterval(-retentionInterval)
        entries = decoded.filter { $0.copiedAt > cutoff }
        sortEntries()

        if entries.count != decoded.count {
            save()
        }
    }

    private func save() {
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        entries = entries.filter { $0.copiedAt > cutoff }

        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        try? data.write(to: storageURL, options: .atomic)
    }
}

struct ClipboardView: View {
    @ObservedObject var model: ClipboardModel
    let closeAction: () -> Void
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clipboard")
                    .font(.title2)

                Text("ClipSafe")
                    .font(.headline)

                Spacer()

                Button(action: { model.toggleMonitoring() }) {
                    Label(
                        model.isMonitoring ? "Pause" : "Resume",
                        systemImage: model.isMonitoring
                            ? "pause.fill" : "play.fill"
                    )
                }
                .help("Pause or resume clipboard monitoring")
            }
            .padding()

            TextField(
                "Search clipboard history",
                text: $model.searchText
            )
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)

            if !model.isMonitoring {
                Label("Monitoring paused", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            if model.filteredEntries.isEmpty {
                Spacer()

                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)

                Text(
                    model.searchText.isEmpty
                        ? "Nothing copied yet" : "No matching entries"
                )
                .foregroundStyle(.secondary)
                .padding(.top, 6)

                Text("Copied text will appear here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            } else {
                List {
                    ForEach(model.filteredEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.text)
                                .font(.system(size: 13))
                                .lineLimit(4)
                                .textSelection(.enabled)

                            HStack(spacing: 8) {
                                Text(entry.copiedAt, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                if entry.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }

                                Spacer()

                                Button {
                                    model.restore(entry)
                                    closeAction()
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .help("Copy this entry back to the clipboard")

                                Button {
                                    model.togglePin(entry)
                                } label: {
                                    Image(
                                        systemName: entry.isPinned
                                            ? "pin.slash" : "pin"
                                    )
                                }
                                .buttonStyle(.borderless)
                                .help(entry.isPinned ? "Unpin entry" : "Pin entry")

                                Button(role: .destructive) {
                                    model.delete(entry)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Delete entry")
                            }
                        }
                        .padding(.vertical, 5)
                        .contextMenu {
                            Button("Copy to clipboard") {
                                model.restore(entry)
                                closeAction()
                            }

                            Button(entry.isPinned ? "Unpin" : "Pin") {
                                model.togglePin(entry)
                            }

                            Button("Delete", role: .destructive) {
                                model.delete(entry)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            HStack {
                Text("\(model.entries.count) saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear history", role: .destructive) {
                    showingClearConfirmation = true
                }
                .disabled(model.entries.isEmpty)
            }
            .padding()
        }
        .frame(width: 380, height: 500)
        .confirmationDialog(
            "Delete all clipboard history?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All History", role: .destructive) {
                model.clearHistory()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all saved entries from this Mac.")
        }
    }
}

@main
struct ClipSafeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
