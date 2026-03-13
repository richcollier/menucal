import AppKit
import Combine

/// Drives the NSStatusItem title string using composable tokens.
/// Observes todayEvents (always today, regardless of calendar selection)
/// and TokenSettingsManager for live updates.
@MainActor
class MenuBarManager {

    private weak var statusItem: NSStatusItem?
    private weak var popover: NSPopover?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var todayEvents: [CalendarEvent] = []
    private let tokenSettings = TokenSettingsManager.shared
    private var pendingTitleUpdate = false

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func setPopover(_ popover: NSPopover) {
        self.popover = popover
    }

    func start(observing calendarService: EventKitService) {
        // Always track today's events for the menubar (not the calendar-selected day)
        calendarService.$todayEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                self?.todayEvents = events
                self?.updateTitle()
            }
            .store(in: &cancellables)

        // Re-render when token config changes (deferred until popover closes)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &cancellables)

        // Refresh clock/countdown/progress every 30s without hitting the API
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.updateTitle() }
        }
    }

    // MARK: - Title update

    private func updateTitle() {
        if popover?.isShown == true {
            pendingTitleUpdate = true
            return
        }
        applyTitle()
    }

    /// Called by AppDelegate via NSPopoverDelegate when the popover closes.
    func popoverDidClose() {
        if pendingTitleUpdate {
            applyTitle()
        }
    }

    private func applyTitle() {
        statusItem?.button?.title = buildTitle()
        pendingTitleUpdate = false
    }

    private func buildTitle() -> String {
        let enabled = tokenSettings.enabledTokens
        guard !enabled.isEmpty else { return "📅" }
        let parts = enabled.compactMap { renderToken($0) }
        return parts.isEmpty ? "📅" : parts.joined(separator: "  ")
    }

    // MARK: - Token rendering

    private func renderToken(_ token: MenuBarToken) -> String? {
        switch token {

        case .eventTitle:
            return nextEvent()?.title.truncated(to: 22)

        case .countdown:
            guard let next = nextEvent() else { return nil }
            if next.isInProgress {
                let mins = max(0, Int(next.endDate.timeIntervalSinceNow / 60))
                return "ends \(mins)m"
            }
            let mins = next.minutesUntilStart
            if mins < 60 { return "in \(mins)m" }
            let h = mins / 60, m = mins % 60
            return m == 0 ? "in \(h)h" : "in \(h)h \(m)m"

        case .clock:
            return DateFormatters.time.string(from: Date())

        case .date:
            return DateFormatters.shortDate.string(from: Date())

        case .dayProgress:
            let cal = Calendar.current
            let now = Date()
            let start = cal.startOfDay(for: now)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            let p = now.timeIntervalSince(start) / end.timeIntervalSince(start)
            return progressBar(p, width: 8)

        case .yearProgress:
            let cal = Calendar.current
            let now = Date()
            let year = cal.component(.year, from: now)
            let start = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
            let end   = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
            let p = now.timeIntervalSince(start) / end.timeIntervalSince(start)
            return "\(Int(p * 100))%"
        }
    }

    // MARK: - Helpers

    private func nextEvent() -> CalendarEvent? {
        let now = Date()
        return todayEvents
            .filter { $0.endDate > now && !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    private func progressBar(_ progress: Double, width: Int) -> String {
        let filled = max(0, min(width, Int(progress * Double(width))))
        return String(repeating: "▓", count: filled) + String(repeating: "░", count: width - filled)
    }
}

private extension String {
    func truncated(to length: Int) -> String {
        count > length ? String(prefix(length)) + "…" : self
    }
}
