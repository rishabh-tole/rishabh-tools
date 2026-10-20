import AppKit
import RishabhFCCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let binaries = Binaries.find()
    private let watcher = DragWatcher()
    private let wheel = WheelController()
    private var statusBar: StatusBar?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if anotherInstanceIsRunning() {
            Log.info("already running, exiting")
            exit(0)
        }
        statusBar = StatusBar(binaries: binaries)
        watcher.onTap = { [weak self] mode, files in self?.tapped(mode, files) }
        watcher.onEnd = { [weak self] in self?.wheel.closeSoon() }
        wheel.onDrop = { [weak self] mode, choice, files in self?.run(mode, choice, files) }
        watcher.start()
        Log.info("started (ffmpeg: \(binaries.ffmpeg ?? "none"), cwebp: \(binaries.cwebp ?? "none"))")
    }

    /// A modifier was tapped mid-drag: open that wheel, switch to it, or close it if it's already showing.
    private func tapped(_ mode: Mode, _ files: [URL]) {
        if wheel.mode == mode { return wheel.close() }
        let choices = Catalog.choices(mode, for: files.map(Item.init(url:)), encoders: binaries.encoders)
        guard !choices.isEmpty else {
            let what = files.count == 1 ? files[0].lastPathComponent : "these files"
            Toast.shared.anchor = NSEvent.mouseLocation
            return Toast.shared.show(mode == .tools ? "No tools for \(what)" : "Can't convert \(what)")
        }
        wheel.open(mode, choices: choices, at: NSEvent.mouseLocation)
    }

    private func run(_ mode: Mode, _ choice: Choice, _ files: [URL]) {
        Log.info("\(mode.rawValue) \(choice.id): \(files.map(\.path))")
        if mode == .actions {
            if let message = FileActions.perform(choice.id, files) { Toast.shared.show(message) }
            return
        }
        Toast.shared.show("\(choice.label.capitalized)…", busy: true)
        let binaries = binaries
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try Jobs.run(mode, choice, files: files, binaries: binaries) }
            DispatchQueue.main.async {
                switch result {
                case .success(let outputs):
                    let text = outputs.count == 1 ? outputs[0].lastPathComponent : "\(outputs.count) files"
                    Toast.shared.show("✓ \(text)", reveal: outputs)
                case .failure(let error):
                    Log.error("\(choice.id) failed: \(error.localizedDescription)")
                    Toast.shared.show("✗ \(error.localizedDescription)")
                }
            }
        }
    }

    private func anotherInstanceIsRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }
}

extension Item {
    /// Packages (.app, .rtfd) count as files: they convert or zip as a whole.
    init(url: URL) {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        self.init(name: url.lastPathComponent, isDirectory: values?.isDirectory == true && values?.isPackage != true)
    }
}

/// `rishabhfc --run <convert|tools> <id> <file>...` runs one job without the UI (scripting and testing).
private func runFromCommandLine(_ args: [String]) -> Never {
    guard args.count >= 3, let mode = Mode(rawValue: args[0]), mode != .actions else {
        print("usage: rishabhfc --run <convert|tools> <id> <file>...")
        exit(2)
    }
    let files = args.dropFirst(2).map { URL(fileURLWithPath: $0).standardizedFileURL }
    let choice = Choice(args[1], args[1].uppercased())
    do {
        try Jobs.run(mode, choice, files: Array(files), binaries: .find()).forEach { print($0.path) }
        exit(0)
    } catch {
        print("error: \(error.localizedDescription)")
        exit(1)
    }
}

/// `rishabhfc --snapshot <out.png> <light|dark> <slot> <mode> <file>...` renders the wheel to a PNG (docs and checks).
private func snapshot(_ args: [String]) -> Never {
    guard args.count >= 5, let mode = Mode(rawValue: args[3]) else {
        print("usage: rishabhfc --snapshot <out.png> <light|dark> <hovered slot> <mode> <file>...")
        exit(2)
    }
    let files = args.dropFirst(4).map { URL(fileURLWithPath: $0) }
    let view = WheelView(frame: NSRect(x: 0, y: 0, width: WheelView.side, height: WheelView.side))
    view.appearance = NSAppearance(named: args[1] == "dark" ? .darkAqua : .aqua)
    view.choices = Catalog.choices(mode, for: files.map(Item.init(url:)), encoders: Binaries.find().encoders)
    view.hovered = Int(args[2])
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
    view.cacheDisplay(in: view.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[0]))
    exit(0)
}

let app = NSApplication.shared
let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: "--run") { runFromCommandLine(Array(arguments[(index + 1)...])) }
if let index = arguments.firstIndex(of: "--snapshot") { snapshot(Array(arguments[(index + 1)...])) }
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
