import SwiftUI

struct CalendarGridView: View {
    let events: [CommandCenterCalendarEvent]
    @Binding var displayedMonth: Date
    var onSelectEvent: (CommandCenterCalendarEvent) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    private var eventsByDay: [String: [CommandCenterCalendarEvent]] {
        Dictionary(grouping: events) { event in
            guard let date = event.startDate else { return "unknown" }
            return dayKey(date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            monthHeader
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(daysInMonth(), id: \.self) { day in
                    dayCell(day)
                }
            }
            selectedDayEvents
        }
        .padding(14)
        .glassPanel()
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(STColor.primary)
            }
            Spacer()
            Text(monthTitle)
                .font(STFont.display(17, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(STColor.primary)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol.prefix(2).uppercased())
                    .font(STFont.body(10, weight: .semibold))
                    .foregroundStyle(STColor.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @State private var selectedDay: String?

    private func dayCell(_ date: Date?) -> some View {
        Group {
            if let date {
                let key = dayKey(date)
                let dayEvents = eventsByDay[key] ?? []
                let isSelected = selectedDay == key
                Button {
                    selectedDay = key
                } label: {
                    VStack(spacing: 4) {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(STFont.body(13, weight: isToday(date) ? .bold : .medium))
                            .foregroundStyle(isToday(date) ? STColor.accent : STColor.textPrimary)
                        if !dayEvents.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(0..<min(dayEvents.count, 3), id: \.self) { _ in
                                    Circle()
                                        .fill(STColor.primary)
                                        .frame(width: 4, height: 4)
                                }
                            }
                        } else {
                            Spacer().frame(height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? STColor.primary.opacity(0.18) : (isToday(date) ? STColor.surfaceElevated : .clear))
                    )
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(height: 44)
            }
        }
    }

    @ViewBuilder
    private var selectedDayEvents: some View {
        let visible = selectedDay.flatMap { eventsByDay[$0] } ?? eventsForMonth()
        if !visible.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedDay == nil ? "This month" : "Selected day")
                    .font(STFont.body(12, weight: .semibold))
                    .foregroundStyle(STColor.textMuted)
                ForEach(visible.prefix(8)) { event in
                    Button { onSelectEvent(event) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: icon(for: event.kind))
                                .foregroundStyle(STColor.primary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(STFont.body(13, weight: .semibold))
                                    .foregroundStyle(STColor.textPrimary)
                                    .lineLimit(1)
                                Text(subtitle(for: event))
                                    .font(STFont.body(11))
                                    .foregroundStyle(STColor.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(STColor.surfaceElevated))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private func shiftMonth(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = next
            selectedDay = nil
        }
    }

    private func daysInMonth() -> [Date?] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))!
        let range = cal.range(of: .day, in: .month, for: start)!
        let firstWeekday = cal.component(.weekday, from: start)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: start) {
                days.append(d)
            }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func eventsForMonth() -> [CommandCenterCalendarEvent] {
        let key = DateParser.monthKey(displayedMonth)
        return events.filter { ($0.startAt.hasPrefix(key)) }
    }

    private func icon(for kind: String?) -> String {
        switch kind {
        case "SHOOT_DAY": return "video.fill"
        case "CALL_SHEET": return "doc.richtext.fill"
        case "TABLE_READ": return "book.fill"
        case "INCIDENT", "INCIDENT_RESOLVED": return "exclamationmark.triangle.fill"
        case "PROJECT_TASK": return "checklist"
        default: return "calendar"
        }
    }

    private func subtitle(for event: CommandCenterCalendarEvent) -> String {
        [DateParser.display(event.startAt), event.projectTitle, event.assigneeName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
