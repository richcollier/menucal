import SwiftUI

struct EventListView: View {
    @EnvironmentObject var calendarService: EventKitService
    @State private var expandedEventId: String? = nil
    @State private var showSettings = false

    var allDayEvents: [CalendarEvent] {
        calendarService.events.filter { $0.isAllDay }
    }

    var timedEvents: [CalendarEvent] {
        calendarService.events.filter { !$0.isAllDay }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minHeight: 280)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(calendarService)
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuCalPopoverDidClose)) { _ in
            showSettings = false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Button { navigateDay(by: -1) } label: {
                Image(systemName: "chevron.left").font(.caption.bold())
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            dayPill("Yesterday", offset: -1)
            dayPill("Today",     offset:  0)
            dayPill("Tomorrow",  offset:  1)

            Button { navigateDay(by: 1) } label: {
                Image(systemName: "chevron.right").font(.caption.bold())
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            if calendarService.isLoading {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await calendarService.fetchTodaysEvents() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Refresh")

            Button { showSettings = true } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func dayPill(_ label: String, offset: Int) -> some View {
        let cal = Calendar.current
        let target = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date()))!
        let isSelected = cal.isDate(calendarService.selectedDate, inSameDayAs: target)
        return Button(label) {
            Task { await calendarService.selectDate(target) }
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundColor(isSelected ? .white : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
        .clipShape(Capsule())
    }

    private func navigateDay(by value: Int) {
        let next = Calendar.current.date(byAdding: .day, value: value, to: calendarService.selectedDate) ?? calendarService.selectedDate
        Task { await calendarService.selectDate(next) }
    }

    // MARK: - Event list

    @ViewBuilder
    private var content: some View {
        if calendarService.isLoading && calendarService.events.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading events…")
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if let error = calendarService.lastError {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
        } else if calendarService.events.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("No events today")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Spacer()
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !allDayEvents.isEmpty {
                            allDaySectionHeader
                            ForEach(allDayEvents) { event in
                                row(for: event)
                            }
                            Divider().padding(.leading, 40)
                        }

                        ForEach(timedEvents) { event in
                            row(for: event)
                                .id(event.id)
                        }
                    }
                }
                .onAppear {
                    scrollToCurrentEvent(proxy: proxy)
                }
            }
        }
    }

    private var allDaySectionHeader: some View {
        Text("All day")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 6)
    }

    @ViewBuilder
    private func row(for event: CalendarEvent) -> some View {
        VStack(spacing: 0) {
            EventRowView(
                event: event,
                isExpanded: expandedEventId == event.id,
                onTap: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        expandedEventId = expandedEventId == event.id ? nil : event.id
                    }
                }
            )
            Divider().padding(.leading, 40)
        }
    }

    // MARK: - Helpers

    private func scrollToCurrentEvent(proxy: ScrollViewProxy) {
        let inProgress = timedEvents.first { $0.isInProgress }
        let firstUpcoming = timedEvents.first { !$0.isPast && !$0.isInProgress }
        if let target = inProgress ?? firstUpcoming {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { proxy.scrollTo(target.id, anchor: .top) }
            }
        }
    }
}
