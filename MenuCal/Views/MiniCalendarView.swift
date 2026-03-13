import SwiftUI

struct MiniCalendarView: View {
    @EnvironmentObject var calendarService: EventKitService
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())

    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            monthHeader
            dayLabelRow
            calendarGrid
            if let refreshed = calendarService.lastRefreshed {
                Text(refreshedLabel(refreshed))
                    .font(.caption2)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .task(id: displayedMonth) {
            await calendarService.refreshEventDays(for: displayedMonth)
        }
        .onChange(of: calendarService.selectedDate) {
            let newMonth = cal.startOfMonth(for: calendarService.selectedDate)
            if newMonth != displayedMonth {
                displayedMonth = newMonth
            }
        }
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle)
                .font(.subheadline.bold())
                .onTapGesture { jumpToToday() }

            Spacer()

            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Day labels (Su Mo Tu ...)

    private var dayLabelRow: some View {
        HStack(spacing: 0) {
            ForEach(dayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar grid

    private var calendarGrid: some View {
        let days = daysInMonth(for: displayedMonth)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date {
                    DayCell(
                        date: date,
                        isToday: cal.isDateInToday(date),
                        isSelected: cal.isDate(date, inSameDayAs: calendarService.selectedDate),
                        hasEvents: calendarService.eventDaysInMonth.contains(DateFormatters.dateOnly.string(from: date))
                    ) {
                        Task { await calendarService.selectDate(date) }
                    }
                } else {
                    Color.clear.frame(height: 26)
                }
            }
        }
    }

    // MARK: - Helpers

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = cal.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func jumpToToday() {
        displayedMonth = cal.startOfMonth(for: Date())
        Task { await calendarService.selectDate(Date()) }
    }

    private func refreshedLabel(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        return mins < 1 ? "Updated <1m ago" : "Updated \(mins)m ago"
    }

    private func daysInMonth(for month: Date) -> [Date?] {
        let firstDay = cal.startOfMonth(for: month)
        let firstWeekday = cal.component(.weekday, from: firstDay) - 1 // 0 = Sunday
        let dayCount = cal.range(of: .day, in: .month, for: month)!.count

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for i in 0..<dayCount {
            days.append(cal.date(byAdding: .day, value: i, to: firstDay))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let hasEvents: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption)
                .foregroundColor(foregroundColor)
                .frame(width: 24, height: 24)
                .background(background)
                .clipShape(Circle())

            Circle()
                .fill(Color.accentColor)
                .frame(width: 4, height: 4)
                .opacity(hasEvents && !isSelected ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var foregroundColor: Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        return .primary
    }

    private var background: Color {
        if isSelected { return .accentColor }
        if isToday { return Color.accentColor.opacity(0.15) }
        return .clear
    }
}

// MARK: - Calendar extension

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps)!
    }
}
