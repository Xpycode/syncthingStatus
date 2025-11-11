import Cocoa
import SwiftUI
import Foundation
import Combine
import UserNotifications
import QuartzCore

// MARK: - Window Controller
class MainWindowController: NSWindowController {
    convenience init(syncthingClient: SyncthingClient, settings: SyncthingSettings, appDelegate: AppDelegate) {
        let contentView = ContentView(appDelegate: appDelegate, syncthingClient: syncthingClient, settings: settings, isPopover: false)
            .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)

        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.intrinsicContentSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Syncthing Status"
        window.titleVisibility = .hidden
        window.center()

        self.init(window: window)
    }
}

// MARK: - Hosting Controller Helpers
final class OpaqueHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        view = OpaqueHostingView(rootView: rootView)
    }
}

private final class OpaqueHostingView<Content: View>: NSHostingView<Content> {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureOpaqueBackground()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        configureOpaqueBackground()
    }

    private func configureOpaqueBackground() {
        wantsLayer = true
        if layer == nil {
            layer = CALayer()
        }
        guard let layer else { return }

        let appearance = window?.effectiveAppearance ?? effectiveAppearance
        var resolvedColor = NSColor.windowBackgroundColor
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor = NSColor.windowBackgroundColor
        }

        layer.isOpaque = true
        layer.backgroundColor = resolvedColor.cgColor
        layer.cornerRadius = 12
        layer.masksToBounds = true
    }
}

// MARK: - AppDelegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private var statusIcon: SyncthingStatusIcon?
    var popover: NSPopover?
    var windowController: MainWindowController?
    weak var settingsWindow: NSWindow?
    let settings: SyncthingSettings
    let syncthingClient: SyncthingClient
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var pendingGlobalSyncNotification = false
    private var popoverSizeUpdateTask: Task<Void, Never>?
    
    override init() {
        let settings = SyncthingSettings()
        self.settings = settings
        self.syncthingClient = SyncthingClient(settings: settings)
        super.init()
        bindClient()
    }
    
    init(settings: SyncthingSettings) {
        self.settings = settings
        self.syncthingClient = SyncthingClient(settings: settings)
        super.init()
        bindClient()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusIcon = SyncthingStatusIcon()
        if let statusButton = statusIcon?.statusItem.button {
            statusButton.target = self
            statusButton.action = #selector(statusItemClicked)
        }
        updateStatusIcon()

        setupPopover()
        UNUserNotificationCenter.current().delegate = self
        configureNotificationCategories()
        requestNotificationPermissions()
        NSApp.setActivationPolicy(.accessory)
        startMonitoring()
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func configureNotificationCategories() {
        let resumeFolder = UNNotificationAction(
            identifier: NotificationAction.resumeFolder.rawValue,
            title: "Resume Folder",
            options: []
        )
        let pauseFolder = UNNotificationAction(
            identifier: NotificationAction.pauseFolder.rawValue,
            title: "Pause Folder",
            options: []
        )
        let resumeDevice = UNNotificationAction(
            identifier: NotificationAction.resumeDevice.rawValue,
            title: "Resume Device",
            options: []
        )
        let pauseDevice = UNNotificationAction(
            identifier: NotificationAction.pauseDevice.rawValue,
            title: "Pause Device",
            options: []
        )
        let resumeAllDevices = UNNotificationAction(
            identifier: NotificationAction.resumeAllDevices.rawValue,
            title: "Resume All Devices",
            options: []
        )
        let pauseAllDevices = UNNotificationAction(
            identifier: NotificationAction.pauseAllDevices.rawValue,
            title: "Pause All Devices",
            options: []
        )
        let openApp = UNNotificationAction(
            identifier: NotificationAction.openApp.rawValue,
            title: "Open syncthingStatus",
            options: [.foreground]
        )

        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(
                identifier: NotificationCategory.folderPaused.rawValue,
                actions: [resumeFolder],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: NotificationCategory.folderResumed.rawValue,
                actions: [pauseFolder],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: NotificationCategory.devicePaused.rawValue,
                actions: [resumeDevice],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: NotificationCategory.deviceResumed.rawValue,
                actions: [pauseDevice],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: NotificationCategory.allDevicesPaused.rawValue,
                actions: [resumeAllDevices],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: NotificationCategory.allDevicesResumed.rawValue,
                actions: [pauseAllDevices],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: NotificationCategory.folderStalled.rawValue,
                actions: [openApp],
                intentIdentifiers: [],
                options: []
            )
        ]

        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
    
    func setupPopover() {
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.animates = true

        let controller = OpaqueHostingController(
            rootView: ContentView(appDelegate: self, syncthingClient: syncthingClient, settings: settings, isPopover: true)
        )
        popover?.contentViewController = controller
    }

    func updatePopoverSize(height: CGFloat) {
        // Cancel any pending update
        popoverSizeUpdateTask?.cancel()

        // Debounce updates to prevent constant resizing
        popoverSizeUpdateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms debounce

            guard !Task.isCancelled, let popover else { return }

            let screenPadding: CGFloat = 100.0
            let screenHeight: CGFloat

            if let screen = statusIcon?.statusItem.button?.window?.screen {
                screenHeight = screen.visibleFrame.height
            } else if let mainScreen = NSScreen.main {
                screenHeight = mainScreen.visibleFrame.height
            } else {
                screenHeight = 900
            }

            // Use percentage of screen height as max, with padding
            let maxHeightPercentage = settings.popoverMaxHeightPercentage / 100.0
            let maxHeight = (screenHeight * maxHeightPercentage) - screenPadding

            // Use content height up to max height
            let finalHeight = min(height, maxHeight)
            let newSize = NSSize(width: 400, height: finalHeight)

            if popover.contentSize != newSize {
                popover.contentSize = newSize
            }
        }
    }

    private func startMonitoring() {
        Task {
            await syncthingClient.refresh()
            self.updateStatusIcon()
        }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.syncthingClient.refresh()
                await MainActor.run { self.updateStatusIcon() }
            }
        }
    }
    
    func updateStatusIcon() {
        guard let icon = statusIcon else { return }

        let button = icon.statusItem.button
        let activityThreshold: Double = 1024 // 1 KB/s

        if !syncthingClient.isConnected {
            icon.set(state: .error)
            button?.toolTip = "Disconnected"
            button?.setAccessibilityTitle("Disconnected")
            pendingGlobalSyncNotification = false
            return
        }

        let totalDownload = syncthingClient.currentDownloadSpeed
        let totalUpload = syncthingClient.currentUploadSpeed

        let isDownloading = totalDownload > activityThreshold
        let isUploading = totalUpload > activityThreshold

        let isActivelySyncing = syncthingClient.folderStatuses.values.contains { $0.state == "syncing" } ||
            syncthingClient.deviceCompletions.contains { deviceID, completion in
                guard let connection = syncthingClient.connections[deviceID], connection.connected else { return false }
                return !isEffectivelySynced(completion: completion, settings: settings)
            }

        let connectedDevices = syncthingClient.devices.filter { syncthingClient.connections[$0.deviceID]?.connected == true }
        let allConnectedDevicesArePaused = !connectedDevices.isEmpty && connectedDevices.allSatisfy { $0.paused }
        let isFullySynced = syncthingClient.folderStatuses.values.allSatisfy { $0.state == "idle" && $0.needFiles == 0 }

        if isUploading && isDownloading {
            icon.set(state: .upAndDown)
            pendingGlobalSyncNotification = true
        } else if isUploading {
            icon.set(state: .uploading)
            pendingGlobalSyncNotification = true
        } else if isDownloading {
            icon.set(state: .downloading)
            pendingGlobalSyncNotification = true
        } else if isActivelySyncing {
            icon.set(state: .upAndDown)
            pendingGlobalSyncNotification = true
        } else if allConnectedDevicesArePaused {
            icon.set(state: .normal)
            button?.toolTip = "Paused"
            button?.setAccessibilityTitle("Paused")
        } else if isFullySynced {
            icon.set(state: .normal)
            button?.toolTip = "In sync"
            button?.setAccessibilityTitle("In sync")
            if pendingGlobalSyncNotification {
                syncthingClient.handleGlobalSyncComplete()
                pendingGlobalSyncNotification = false
            }
        } else {
            icon.set(state: .error)
            button?.toolTip = "Out of sync"
            button?.setAccessibilityTitle("Out of sync")
        }
    }
    
    @objc func statusItemClicked() {
        guard let statusButton = statusIcon?.statusItem.button else { return }
        
        if let popover, popover.isShown {
            closePopover()
        } else {
            showPopover(statusButton)
        }
    }
    
    @objc func openMainWindow() {
        closePopover()
        if windowController == nil {
            windowController = MainWindowController(syncthingClient: syncthingClient, settings: settings, appDelegate: self)
            windowController?.window?.delegate = self
        }
        NSApp.setActivationPolicy(.regular)
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func presentSettings(using openSettingsAction: @escaping () -> Void) {
        closePopover()
        NSApp.setActivationPolicy(.regular)

        if bringExistingSettingsWindowToFront() {
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            openSettingsAction()
            DispatchQueue.main.async { [weak self] in
                self?.configureSettingsWindowIfNeeded()
            }
        }
    }

    private func configureSettingsWindowIfNeeded() {
        guard let window = locateSettingsWindow() else {
            revertToAccessoryIfAppropriate()
            return
        }
        settingsWindow = window
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
    }

    private func bringExistingSettingsWindowToFront() -> Bool {
        guard let window = locateSettingsWindow() else { return false }
        settingsWindow = window
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        return true
    }

    private func locateSettingsWindow() -> NSWindow? {
        if let window = settingsWindow, window.isVisible {
            return window
        }
        let titles = settingsWindowTitles
        return NSApp.windows.first { window in
            titles.contains(window.title)
        }
    }

    private var settingsWindowTitles: [String] {
        let bundle = Bundle.main
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let appName = displayName ?? bundleName ?? ProcessInfo.processInfo.processName
        return ["\(appName) Settings", "\(appName) Preferences", "Settings", "Preferences"]
    }

    private func revertToAccessoryIfAppropriate(excluding closingWindow: NSWindow? = nil) {
        DispatchQueue.main.async {
            let visibleWindows = NSApp.windows.filter { $0 !== closingWindow && $0.isVisible }
            if visibleWindows.isEmpty {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    func showPopover(_ sender: NSButton) {
        popover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }
    
    func closePopover() {
        popover?.performClose(nil)
    }
    
    func quit() {
        timer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === windowController?.window {
            windowController = nil
            revertToAccessoryIfAppropriate(excluding: window)
        } else if window === settingsWindow {
            settingsWindow = nil
            revertToAccessoryIfAppropriate(excluding: window)
        }
    }
    
    private func bindClient() {
        syncthingClient.$isConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
        
        syncthingClient.$deviceCompletions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
        
        syncthingClient.$transferRates
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
        
        syncthingClient.$connections
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
        
        syncthingClient.$devices
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
        
        syncthingClient.$folderStatuses
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
        
        settings.$refreshInterval
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.startMonitoring() }
            .store(in: &cancellables)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor [weak self] in
            guard let self else {
                completionHandler()
                return
            }
            self.processNotificationResponse(response)
            completionHandler()
        }
    }

    @MainActor
    private func processNotificationResponse(_ response: UNNotificationResponse) {
        let identifier = response.actionIdentifier
        if identifier == UNNotificationDismissActionIdentifier {
            return
        }

        let userInfo = response.notification.request.content.userInfo

        if identifier == UNNotificationDefaultActionIdentifier {
            openMainWindow()
            return
        }

        guard let action = NotificationAction(rawValue: identifier) else { return }
        handleNotificationAction(action, userInfo: userInfo)
    }

    private func handleNotificationAction(_ action: NotificationAction, userInfo: [AnyHashable: Any]) {
        guard let target = userInfo["target"] as? String else { return }

        switch action {
        case .resumeFolder:
            guard target == "folder", let folderID = userInfo["id"] as? String else { return }
            Task { await syncthingClient.resumeFolder(folderID: folderID) }
        case .pauseFolder:
            guard target == "folder", let folderID = userInfo["id"] as? String else { return }
            Task { await syncthingClient.pauseFolder(folderID: folderID) }
        case .resumeDevice:
            guard target == "device", let deviceID = userInfo["id"] as? String else { return }
            Task { await syncthingClient.resumeDevice(deviceID: deviceID) }
        case .pauseDevice:
            guard target == "device", let deviceID = userInfo["id"] as? String else { return }
            Task { await syncthingClient.pauseDevice(deviceID: deviceID) }
        case .resumeAllDevices:
            guard target == "allDevices", let wasPaused = userInfo["paused"] as? Bool, wasPaused else { return }
            Task { await syncthingClient.resumeAllDevices() }
        case .pauseAllDevices:
            guard target == "allDevices", let wasPaused = userInfo["paused"] as? Bool, !wasPaused else { return }
            Task { await syncthingClient.pauseAllDevices() }
        case .openApp:
            openMainWindow()
        }
    }
}

// MARK: - Main App Structure
@main
struct SyncthingStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // The Settings scene is the source of truth for the settings window.
        Settings {
            SettingsView(settings: appDelegate.settings, syncthingClient: appDelegate.syncthingClient)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsCommandBridge(appDelegate: appDelegate)
            }
            CommandGroup(after: .windowArrangement) {
                Menu("Debug") {
                    Menu("Devices") {
                        Button("5 Devices") {
                            appDelegate.syncthingClient.enableDebugMode(
                                deviceCount: 5,
                                folderCount: appDelegate.syncthingClient.debugMode ? appDelegate.syncthingClient.folders.count : 0
                            )
                        }
                        Button("10 Devices") {
                            appDelegate.syncthingClient.enableDebugMode(
                                deviceCount: 10,
                                folderCount: appDelegate.syncthingClient.debugMode ? appDelegate.syncthingClient.folders.count : 0
                            )
                        }
                        Button("15 Devices") {
                            appDelegate.syncthingClient.enableDebugMode(
                                deviceCount: 15,
                                folderCount: appDelegate.syncthingClient.debugMode ? appDelegate.syncthingClient.folders.count : 0
                            )
                        }
                    }
                    Menu("Folders") {
                        Button("5 Folders") {
                            appDelegate.syncthingClient.enableDebugMode(
                                deviceCount: appDelegate.syncthingClient.debugMode ? appDelegate.syncthingClient.devices.count : 0,
                                folderCount: 5
                            )
                        }
                        Button("10 Folders") {
                            appDelegate.syncthingClient.enableDebugMode(
                                deviceCount: appDelegate.syncthingClient.debugMode ? appDelegate.syncthingClient.devices.count : 0,
                                folderCount: 10
                            )
                        }
                        Button("15 Folders") {
                            appDelegate.syncthingClient.enableDebugMode(
                                deviceCount: appDelegate.syncthingClient.debugMode ? appDelegate.syncthingClient.devices.count : 0,
                                folderCount: 15
                            )
                        }
                    }
                    Divider()
                    Button("Disable Debug Mode") {
                        appDelegate.syncthingClient.disableDebugMode()
                    }
                    .disabled(!appDelegate.syncthingClient.debugMode)
                }
            }
        }
    }
}

private struct SettingsCommandBridge: View {
    @Environment(\.openSettings) private var openSettings
    let appDelegate: AppDelegate

    var body: some View {
        Button("Settings…") {
            appDelegate.presentSettings(using: openSettings.callAsFunction)
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
