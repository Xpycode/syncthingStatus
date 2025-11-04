import AppKit

enum SyncState {
    case normal
    case error
    case uploading
    case downloading
    case upAndDown
}

@MainActor
final class SyncthingStatusIcon: NSObject {
    let statusItem: NSStatusItem
    var frameInterval: TimeInterval = 0.5 {
        didSet {
            guard !currentFrameNames.isEmpty else { return }
            startAnimation(names: currentFrameNames, interval: frameInterval, tooltip: currentTooltip)
        }
    }

    private let frameSets: [SyncState: [String]] = [
        .uploading: ["syncthingStatus-UP_1", "syncthingStatus-UP_2", "syncthingStatus-UP_3"],
        .downloading: ["syncthingStatus-DOWN_1", "syncthingStatus-DOWN_2", "syncthingStatus-DOWN_3"],
        .upAndDown: [
            "syncthingStatus-UpDown_1",
            "syncthingStatus-UpDown_2",
            "syncthingStatus-UpDown_3",
            "syncthingStatus-UpDown_4"
        ]
    ]

    private let staticIcons: [SyncState: String] = [
        .normal: "syncthingStatus-Normal",
        .error: "syncthingStatus-ERROR"
    ]

    private var cachedImages: [String: NSImage] = [:]
    private var animationTimer: Timer?
    private var currentFrameNames: [String] = []
    private var currentFrameIndex = 0
    private var currentTooltip: String = ""

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        preloadAllImages()
        if let button = statusItem.button {
            button.image = image(named: "syncthingStatus-Normal")
            button.toolTip = "In sync"
            button.setAccessibilityTitle("In sync")
            button.target = self
            button.action = #selector(didTap(_:))
        }
        currentTooltip = "In sync"
    }

    func set(state: SyncState) {
        switch state {
        case .normal:
            stopAnimation()
            currentFrameNames = []
            currentTooltip = "In sync"
            if let name = staticIcons[.normal] {
                applyImage(named: name, tooltip: "In sync")
            }

        case .error:
            stopAnimation()
            currentFrameNames = []
            currentTooltip = "Error"
            if let name = staticIcons[.error] {
                applyImage(named: name, tooltip: "Error")
            }

        case .uploading:
            startAnimation(
                names: frameSets[.uploading] ?? [],
                interval: frameInterval,
                tooltip: "Uploading…"
            )

        case .downloading:
            startAnimation(
                names: frameSets[.downloading] ?? [],
                interval: frameInterval,
                tooltip: "Downloading…"
            )

        case .upAndDown:
            startAnimation(
                names: frameSets[.upAndDown] ?? [],
                interval: frameInterval,
                tooltip: "Syncing (up & down)…"
            )
        }
    }

    func startAnimation(names: [String], interval: TimeInterval, tooltip: String) {
        guard !names.isEmpty else { return }

        stopAnimation()

        currentFrameNames = names
        currentFrameIndex = 0
        currentTooltip = tooltip

        applyImage(named: names[currentFrameIndex], tooltip: tooltip)

        let timer = Timer(timeInterval: interval, target: self, selector: #selector(handleAnimationTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        currentFrameIndex = 0
    }

    @objc func didTap(_ sender: Any?) {
        // TODO: Wire up menu presentation or app activation.
    }

    @objc private func handleAnimationTick() {
        guard !currentFrameNames.isEmpty else {
            stopAnimation()
            return
        }

        currentFrameIndex = (currentFrameIndex + 1) % currentFrameNames.count
        applyImage(named: currentFrameNames[currentFrameIndex], tooltip: currentTooltip)
    }

    private func applyImage(named name: String, tooltip: String) {
        guard let button = statusItem.button else { return }
        guard let image = image(named: name) else { return }

        image.isTemplate = false
        button.image = image
        button.toolTip = tooltip
        button.setAccessibilityTitle(tooltip)
    }

    private func image(named name: String) -> NSImage? {
        if let cached = cachedImages[name] {
            return cached
        }
        if let image = NSImage(named: name) {
            image.isTemplate = false
            cachedImages[name] = image
            return image
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "menuBarStatusIcons"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = false
            cachedImages[name] = image
            return image
        }
        return nil
    }

    private func preloadAllImages() {
        let animatedNames = frameSets.values.flatMap { $0 }
        let staticNames = Array(staticIcons.values)
        let allNames = Set(animatedNames + staticNames)
        allNames.forEach { _ = image(named: $0) }
    }
    
    deinit {
        animationTimer?.invalidate()
        animationTimer = nil
        currentFrameNames = []
    }
}

/*
 Usage:

 final class AppDelegate: NSObject, NSApplicationDelegate {
     private var icon: SyncthingStatusIcon!
     func applicationDidFinishLaunching(_ note: Notification) {
         icon = SyncthingStatusIcon()
         icon.set(state: .upAndDown) // example
     }
 }
 */
