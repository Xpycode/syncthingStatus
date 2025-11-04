import Cocoa
import SwiftUI
import Foundation
import Combine
import UserNotifications

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
        window.center()

        self.init(window: window)
    }
}

// MARK: - AppDelegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var windowController: MainWindowController?
    weak var settingsWindow: NSWindow?
    let settings: SyncthingSettings
    let syncthingClient: SyncthingClient
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Loading")?.withSymbolConfiguration(.init(pointSize: 16, weight: .regular))
            statusButton.image?.isTemplate = true
            statusButton.action = #selector(statusItemClicked)
            statusButton.target = self
        }

        setupPopover()
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
    
    func setupPopover() {
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: ContentView(appDelegate: self, syncthingClient: syncthingClient, settings: settings, isPopover: true)
        )
    }

    func updatePopoverSize(height: CGFloat) {
        guard let popover else { return }
        
        let screenPadding: CGFloat = 100.0
        let maxHeight: CGFloat
        
        if let screen = statusItem?.button?.window?.screen {
            maxHeight = screen.visibleFrame.height - screenPadding
        } else if let mainScreen = NSScreen.main {
            maxHeight = mainScreen.visibleFrame.height - screenPadding
        } else {
            maxHeight = 700
        }
        
        let newHeight = min(height, maxHeight)
        let newSize = NSSize(width: 400, height: newHeight)
        
        if popover.contentSize != newSize {
            popover.contentSize = newSize
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
        guard let statusButton = statusItem?.button else { return }

        let iconName: String
        let accessibilityDescription: String

        if !syncthingClient.isConnected {
            iconName = "wifi.exclamationmark"
            accessibilityDescription = "Disconnected"
        } else {
            let isActivelySyncing = syncthingClient.folderStatuses.values.contains { $0.state == "syncing" } ||
                                    syncthingClient.deviceCompletions.contains { deviceID, completion in
                                        guard let connection = syncthingClient.connections[deviceID], connection.connected else { return false }
                                        return !isEffectivelySynced(completion: completion, settings: settings)
                                    }

            if isActivelySyncing {
                iconName = "arrow.triangle.2.circlepath"
                accessibilityDescription = "Syncing"
            } else {
                let connectedDevices = syncthingClient.devices.filter { syncthingClient.connections[$0.deviceID]?.connected == true }
                let allConnectedDevicesArePaused = !connectedDevices.isEmpty && connectedDevices.allSatisfy { $0.paused }

                if allConnectedDevicesArePaused {
                    iconName = "pause.circle.fill"
                    accessibilityDescription = "Paused"
                } else {
                    let isFullySynced = syncthingClient.folderStatuses.values.allSatisfy { $0.state == "idle" && $0.needFiles == 0 }

                    if isFullySynced {
                        iconName = "checkmark.circle.fill"
                        accessibilityDescription = "Synced"
                    } else {
                        iconName = "exclamationmark.arrow.circlepath"
                        accessibilityDescription = "Out of Sync"
                    }
                }
            }
        }
        statusButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: accessibilityDescription)
        statusButton.image?.isTemplate = true
    }
    
    @objc func statusItemClicked() {
        guard let statusButton = statusItem?.button else { return }
        
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
        
        syncthingClient.$folderStatuses
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
        
        settings.$refreshInterval
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.startMonitoring() }
            .store(in: &cancellables)
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
