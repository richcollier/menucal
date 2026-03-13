import AppKit
import SwiftUI
import Combine

/// Manages the floating always-on-top HUD panel shown before meetings.
/// Does not conform to ObservableObject — it doesn't publish state to SwiftUI.
@MainActor
class HUDService {

    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?
    private var shownEventIDs = Set<String>()
    private var lastShownDate = Calendar.current.startOfDay(for: Date())
    private var checkTimer: Timer?
    private var currentEvents: [CalendarEvent] = []
    private let notificationService: NotificationService

    init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    // MARK: - Lifecycle

    func start(observing calendarService: EventKitService) {
        calendarService.$events
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                self?.handleEventsUpdate(events)
            }
            .store(in: &cancellables)

        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.checkForTriggers() }
        }
    }

    // MARK: - Events update

    private func handleEventsUpdate(_ events: [CalendarEvent]) {
        // Reset shown IDs when the day rolls over
        let today = Calendar.current.startOfDay(for: Date())
        if today > lastShownDate {
            shownEventIDs.removeAll()
            lastShownDate = today
        }

        currentEvents = events
        checkForTriggers()
    }

    // MARK: - Trigger check

    private func checkForTriggers() {
        guard UserDefaults.standard.bool(forKey: "hudEnabled") else { return }

        let minutesBefore = UserDefaults.standard.integer(forKey: "reminderMinutes")

        for event in currentEvents {
            guard
                !event.isAllDay,
                !event.isPast,
                !shownEventIDs.contains(event.id),
                event.minutesUntilStart <= minutesBefore
            else { continue }

            shownEventIDs.insert(event.id)
            show(for: event)
            return // show one at a time
        }
    }

    // MARK: - Show / Hide

    private func show(for event: CalendarEvent) {
        // Dismiss any existing HUD first
        hidePanel(animated: false)

        let hostingView = NSHostingView(rootView: HUDContentView(
            event: event,
            onJoin: { [weak self] in
                if let url = event.meetingURL { NSWorkspace.shared.open(url) }
                self?.hidePanel(animated: true)
            },
            onDismiss: { [weak self] in
                self?.hidePanel(animated: true)
            },
            onSnooze: { [weak self] in
                self?.notificationService.scheduleSnooze(for: event, minutes: 5)
                self?.hidePanel(animated: true)
            }
        ))

        // Size the panel to fit the hosting view
        let size = hostingView.fittingSize
        let panelFrame = NSRect(origin: .zero, size: CGSize(width: 340, height: max(size.height, 100)))

        let newPanel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true
        newPanel.hidesOnDeactivate = false
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.contentView = hostingView

        // Position: top-right of main screen
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - panelFrame.width - 16
            let y = screen.visibleFrame.maxY - panelFrame.height - 8
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Fade in
        newPanel.alphaValue = 0
        newPanel.orderFront(nil)  // NOT makeKeyAndOrderFront — would steal focus
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            newPanel.animator().alphaValue = 1
        }

        panel = newPanel
    }

    func hidePanel(animated: Bool) {
        dismissWorkItem?.cancel()
        guard let p = panel else { return }
        panel = nil

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                p.animator().alphaValue = 0
            }, completionHandler: {
                p.orderOut(nil)
            })
        } else {
            p.orderOut(nil)
        }
    }

    // MARK: - Combine storage

    private var cancellables = Set<AnyCancellable>()
}
