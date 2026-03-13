import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Services
    let calendarService  = EventKitService()
    let reminderService  = ReminderService()

    // MARK: - Menubar
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var menuBarManager: MenuBarManager!
    private var eventMonitor: Any?

    // MARK: - applicationWillFinishLaunching
    // Critical: delegate and categories must be set before the app finishes launching
    // so that notification responses delivered on cold-launch are not lost.
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register defaults before any UserDefaults reads
        UserDefaults.standard.register(defaults: [
            "reminderMinutes":      5,
            "notificationsEnabled": true,
            "hudEnabled":           false,
        ])

        // Set delegate immediately so willPresent / didReceive fire correctly
        UNUserNotificationCenter.current().delegate = self

        // Register notification categories before any notification fires
        reminderService.notificationService.registerCategories()
    }

    // MARK: - applicationDidFinishLaunching

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()

        menuBarManager = MenuBarManager(statusItem: statusItem)
        menuBarManager.setPopover(popover)
        menuBarManager.start(observing: calendarService)

        reminderService.start(observing: calendarService)

        // Request permissions then start fetching
        Task {
            await reminderService.notificationService.requestAuthorization()
            await calendarService.requestAccessAndFetch()
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "📅"
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 560)
        popover.behavior = .applicationDefined
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView()
                .environmentObject(calendarService)
        )
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            // Defensive: remove any stale monitor before adding a new one
            removeEventMonitor()

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        // Note: removeEventMonitor() is called in popoverDidClose (the authoritative cleanup point)
        // to handle all close paths (Escape, programmatic, click-outside).
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

}

// MARK: - NSPopoverDelegate

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        // Authoritative cleanup point — fires regardless of how the popover closed
        removeEventMonitor()
        menuBarManager.popoverDidClose()
        NotificationCenter.default.post(name: .menuCalPopoverDidClose, object: nil)
    }
}

extension Notification.Name {
    static let menuCalPopoverDidClose = Notification.Name("menuCalPopoverDidClose")
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Show banner + play sound even when the app is frontmost
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle action button taps
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "JOIN":
            if let urlString = info["meetingURL"] as? String,
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }

        case "SNOOZE":
            // Reconstruct a lightweight event stub for rescheduling
            if let eventId = info["eventId"] as? String,
               let event = calendarService.events.first(where: { $0.id == eventId }) {
                Task { @MainActor in
                    reminderService.notificationService.scheduleSnooze(for: event, minutes: 5)
                }
            }

        default:
            break
        }

        completionHandler()
    }
}
