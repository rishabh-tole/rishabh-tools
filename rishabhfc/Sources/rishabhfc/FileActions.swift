import AppKit

/// The Control wheel: things to do with files that aren't conversions. Returns a toast message, if any.
enum FileActions {
    static func perform(_ id: String, _ files: [URL]) -> String? {
        let count = files.count == 1 ? files[0].lastPathComponent : "\(files.count) items"
        switch id {
        case "airdrop":
            NSApp.activate()
            NSSharingService(named: .sendViaAirDrop)?.perform(withItems: files)
            return nil
        case "float":
            FloatShelf.show(files)
            return nil
        case "copy":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(files as [NSURL])
            return "Copied \(count)"
        case "copypath":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(files.map(\.path).joined(separator: "\n"), forType: .string)
            return files.count == 1 ? "Copied path" : "Copied \(files.count) paths"
        case "move":
            return move(files)
        case "terminal":
            openTerminal(at: files[0])
            return nil
        default:
            return nil
        }
    }

    private static func move(_ files: [URL]) -> String? {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Move Here"
        panel.directoryURL = files[0].deletingLastPathComponent()
        guard panel.runModal() == .OK, let destination = panel.url else { return nil }
        do {
            for file in files {
                try FileManager.default.moveItem(at: file, to: Output.free(file.lastPathComponent, in: destination))
            }
            return "Moved to \(destination.lastPathComponent)"
        } catch {
            Log.error("move failed: \(error.localizedDescription)")
            return "✗ \(error.localizedDescription)"
        }
    }

    /// Opens the folder (or the file's folder) in iTerm2 when installed, otherwise Terminal.
    private static func openTerminal(at url: URL) {
        let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let folder = isFolder ? url : url.deletingLastPathComponent()
        let workspace = NSWorkspace.shared
        guard let app = workspace.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2")
            ?? workspace.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
        workspace.open([folder], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
}
