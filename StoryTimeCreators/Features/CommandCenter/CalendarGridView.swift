import SwiftUI

private struct CalendarDayItem: Identifiable {
    let id: String
    let date: Date?
}

struct CalendarGridView: View {
    let events: [CommandCenterCalendarEvent]
    @Binding var displayedMonth: Date
    var onSelectEvent: (CommandCenterCalendarEvent) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols
    @State private var selectedDay: String?

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
                ForEach(dayItems()) { item in
                    dayCell(item)
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
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(STFont.body(10, weight: .semibold))
                    .foregroundStyle(STColor.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ item: CalendarDayItem) -> some View {
        if let date = item.date {
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
                            ForEach(0..<min(dayEvents.count, 3), id: \.self) { idx in
                                Circle()
                                    .fill(STColor.primary)
                                    .frame(width: 4, height: 4)
                                    .id("\(item.id)-dot-\(idx)")
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
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 44)
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
                ForEach(Array(visible.prefix(8))) { event in
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

    private func dayItems() -> [CalendarDayItem] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))!
        let range = cal.range(of: .day, in: .month, for: start)!
        let firstWeekday = cal.component(.weekday, from: start)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var items: [CalendarDayItem] = []
        for i in 0..<leading {
            items.append(CalendarDayItem(id: "pad-leading-\(i)", date: nil))
        }
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: start) {
                items.append(CalendarDayItem(id: "day-\(dayKey(d))", date: d))
            }
        }
        let trailing = (7 - (items.count % 7)) % 7
        for i in 0..<trailing {
            items.append(CalendarDayItem(id: "pad-trailing-\(i)", date: nil))
        }
        return items
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
        return events.filter { $0.startAt.hasPrefix(key) }
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

// MARK: - Event editor (create / edit / delete manual events)

struct CalendarEventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let event: CommandCenterCalendarEvent?
    let defaultDate: Date
    let projects: [CreatorProject]
    /// Returns nil on success, or an error message.
    let onSave: (CreateCalendarEventBody) async -> String?
    let onDelete: (() async -> String?)?

    @State private var title = ""
    @State private var notes = ""
    @State private var allDay = true
    @State private var startAt = Date()
    @State private var hasEnd = false
    @State private var endAt = Date()
    @State private var projectId: String = ""
    @State private var visibility = "PERSONAL"
    @State private var error: String?
    @State private var isSaving = false
    @State private var isDeleting = false

    private var isEditing: Bool { event != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("When") {
                    Toggle("All day", isOn: $allDay)
                    DatePicker(
                        "Start",
                        selection: $startAt,
                        displayedComponents: allDay ? [.date] : [.date, .hourAndMinute]
                    )
                    Toggle("Set end time", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker(
                            "End",
                            selection: $endAt,
                            displayedComponents: allDay ? [.date] : [.date, .hourAndMinute]
                        )
                    }
                }

                Section("Link") {
                    Picker("Project", selection: $projectId) {
                        Text("None").tag("")
                        ForEach(projects) { project in
                            Text(project.title).tag(project.id)
                        }
                    }
                    Picker("Visibility", selection: $visibility) {
                        Text("Personal").tag("PERSONAL")
                        Text("Team").tag("TEAM")
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .font(STFont.body(13))
                            .foregroundStyle(STColor.danger)
                    }
                }

                if isEditing, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                isDeleting = true
                                let err = await onDelete()
                                isDeleting = false
                                if let err { error = err } else { dismiss() }
                            }
                        } label: {
                            HStack {
                                if isDeleting { ProgressView() }
                                Text("Delete event")
                            }
                        }
                        .disabled(isDeleting)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(STColor.background)
            .navigationTitle(isEditing ? "Edit event" : "New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear(perform: prefill)
        }
        .preferredColorScheme(.dark)
    }

    private func prefill() {
        guard let event else {
            startAt = defaultDate
            endAt = defaultDate
            return
        }
        title = event.title
        notes = event.description ?? ""
        allDay = event.allDay ?? true
        visibility = event.visibility ?? "PERSONAL"
        projectId = event.projectId ?? ""
        if let start = event.startDate { startAt = start }
        if let end = DateParser.parse(event.endAt) {
            endAt = end
            hasEnd = true
        }
    }

    private func save() {
        Task {
            isSaving = true
            error = nil
            let body = CreateCalendarEventBody(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: notes.isEmpty ? nil : notes,
                startAt: DateParser.iso(startAt),
                endAt: hasEnd ? DateParser.iso(endAt) : nil,
                allDay: allDay,
                visibility: visibility,
                projectId: projectId.isEmpty ? nil : projectId,
                assigneeId: nil
            )
            let err = await onSave(body)
            isSaving = false
            if let err { error = err } else { dismiss() }
        }
    }
}
