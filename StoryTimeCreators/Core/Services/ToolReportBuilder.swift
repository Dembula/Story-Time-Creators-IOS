import Foundation

enum ToolReportBuilder {
    static func build(projectId: String, tool: ProjectTool, json: Data?) -> [ToolActivityRow] {
        guard let json, !json.isEmpty else { return [] }
        guard let obj = try? JSONSerialization.jsonObject(with: json) else { return [] }

        switch tool {
        case .ideaDevelopment:
            return ideasRows(from: obj)
        case .scriptWriting:
            return scriptRows(from: obj)
        case .scriptReview:
            return scriptReviewRows(from: obj)
        case .budgetBuilder, .expenseTracker:
            return expenseRows(from: obj)
        case .productionScheduling, .callSheetGenerator:
            return scheduleRows(from: obj)
        case .castingPortal:
            return castingRows(from: obj)
        case .continuityManager:
            return continuityRows(from: obj)
        case .incidentReporting:
            return incidentRows(from: obj)
        case .tableReads:
            return tableReadRows(from: obj)
        case .legalContracts:
            return contractRows(from: obj)
        case .fundingHub:
            return fundingRows(from: obj)
        default:
            return genericRows(from: obj, tool: tool)
        }
    }

    static func merge(activity: [ProjectActivityItem], tool: ProjectTool) -> [ToolActivityRow] {
        activity.map { item in
            ToolActivityRow(
                id: item.id,
                title: item.message ?? item.type ?? "Activity",
                detail: item.metadata,
                actorName: item.user?.name,
                timestamp: DateParser.display(item.createdAt),
                kind: item.type,
                icon: iconForTool(tool)
            )
        }
    }

    private static func ideasRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any],
              let ideas = dict["ideas"] as? [[String: Any]] else { return [] }
        return ideas.compactMap { idea in
            guard let id = idea["id"] as? String else { return nil }
            return ToolActivityRow(
                id: id,
                title: idea["title"] as? String ?? "Idea",
                detail: idea["logline"] as? String ?? idea["notes"] as? String,
                actorName: nil,
                timestamp: DateParser.display(idea["updatedAt"] as? String ?? idea["createdAt"] as? String),
                kind: "IDEA",
                icon: "lightbulb.fill"
            )
        }
    }

    private static func scriptRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any],
              let script = dict["script"] as? [String: Any],
              let versions = script["versions"] as? [[String: Any]] else { return [] }
        return versions.compactMap { v in
            guard let id = v["id"] as? String else { return nil }
            let label = v["versionLabel"] as? String ?? "Version"
            let preview = (v["content"] as? String)?.prefix(120).description
            return ToolActivityRow(
                id: id,
                title: "Script \(label)",
                detail: preview,
                actorName: v["createdById"] as? String,
                timestamp: DateParser.display(v["createdAt"] as? String ?? v["autoSavedAt"] as? String),
                kind: "SCRIPT_VERSION",
                icon: "doc.text.fill"
            )
        }
    }

    private static func scriptReviewRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any] else { return [] }
        var rows: [ToolActivityRow] = []
        if let requests = dict["requests"] as? [[String: Any]] {
            for req in requests {
                guard let id = req["id"] as? String else { continue }
                let requester = (req["requester"] as? [String: Any])?["name"] as? String
                rows.append(ToolActivityRow(
                    id: id,
                    title: "Review request — \(req["status"] as? String ?? "pending")",
                    detail: (req["scriptVersion"] as? [String: Any])?["versionLabel"] as? String,
                    actorName: requester,
                    timestamp: DateParser.display(req["createdAt"] as? String),
                    kind: "SCRIPT_REVIEW",
                    icon: "doc.text.magnifyingglass"
                ))
            }
        }
        return rows
    }

    private static func expenseRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any],
              let expenses = dict["expenses"] as? [[String: Any]] else { return [] }
        return expenses.compactMap { e in
            guard let id = e["id"] as? String else { return nil }
            let amount = e["amount"] as? Double
            return ToolActivityRow(
                id: id,
                title: e["description"] as? String ?? e["vendor"] as? String ?? "Expense",
                detail: amount.map { "R\(String(format: "%.2f", $0))" },
                actorName: (e["createdBy"] as? [String: Any])?["name"] as? String,
                timestamp: DateParser.display(e["createdAt"] as? String ?? e["spentAt"] as? String),
                kind: "EXPENSE",
                icon: "creditcard.fill"
            )
        }
    }

    private static func scheduleRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any] else { return [] }
        let days = (dict["shootDays"] as? [[String: Any]]) ?? (dict["callSheets"] as? [[String: Any]]) ?? []
        return days.compactMap { d in
            guard let id = d["id"] as? String else { return nil }
            return ToolActivityRow(
                id: id,
                title: d["title"] as? String ?? "Shoot day \(d["shootDayNumber"] as? Int ?? 0)",
                detail: [d["locationSummary"] as? String, d["callTime"] as? String].compactMap { $0 }.joined(separator: " · "),
                actorName: nil,
                timestamp: DateParser.display(d["date"] as? String),
                kind: "SCHEDULE",
                icon: "calendar"
            )
        }
    }

    private static func castingRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any],
              let roles = dict["roles"] as? [[String: Any]] else { return [] }
        return roles.compactMap { r in
            guard let id = r["id"] as? String else { return nil }
            return ToolActivityRow(
                id: id,
                title: r["name"] as? String ?? "Role",
                detail: [r["status"] as? String, r["importance"] as? String].compactMap { $0 }.joined(separator: " · "),
                actorName: r["assignedCast"] as? String,
                timestamp: nil,
                kind: "CASTING",
                icon: "theatermasks.fill"
            )
        }
    }

    private static func continuityRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any],
              let notes = dict["notes"] as? [[String: Any]] else { return [] }
        return notes.compactMap { n in
            guard let id = n["id"] as? String else { return nil }
            return ToolActivityRow(
                id: id,
                title: (n["scene"] as? [String: Any]).flatMap { s in
                    if let num = s["number"] as? Int, let heading = s["heading"] as? String {
                        return "Scene \(num): \(heading)"
                    }
                    return s["heading"] as? String
                } ?? "Continuity note",
                detail: n["body"] as? String,
                actorName: (n["createdBy"] as? [String: Any])?["name"] as? String,
                timestamp: DateParser.display(n["createdAt"] as? String),
                kind: "CONTINUITY",
                icon: "film.fill"
            )
        }
    }

    private static func incidentRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any],
              let incidents = dict["incidents"] as? [[String: Any]] else { return [] }
        return incidents.compactMap { i in
            guard let id = i["id"] as? String else { return nil }
            return ToolActivityRow(
                id: id,
                title: i["title"] as? String ?? "Incident",
                detail: i["description"] as? String,
                actorName: (i["createdBy"] as? [String: Any])?["name"] as? String,
                timestamp: DateParser.display(i["createdAt"] as? String),
                kind: "INCIDENT",
                icon: "exclamationmark.triangle.fill"
            )
        }
    }

    private static func tableReadRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any],
              let sessions = dict["sessions"] as? [[String: Any]] else { return [] }
        return sessions.compactMap { s in
            guard let id = s["id"] as? String else { return nil }
            return ToolActivityRow(
                id: id,
                title: s["title"] as? String ?? "Table read",
                detail: s["notes"] as? String,
                actorName: nil,
                timestamp: DateParser.display(s["scheduledAt"] as? String ?? s["createdAt"] as? String),
                kind: "TABLE_READ",
                icon: "book.fill"
            )
        }
    }

    private static func contractRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any],
              let contracts = dict["contracts"] as? [[String: Any]] else { return [] }
        return contracts.compactMap { c in
            guard let id = c["id"] as? String else { return nil }
            return ToolActivityRow(
                id: id,
                title: c["subject"] as? String ?? c["type"] as? String ?? "Contract",
                detail: c["status"] as? String,
                actorName: (c["createdBy"] as? [String: Any])?["name"] as? String,
                timestamp: DateParser.display(c["createdAt"] as? String),
                kind: "CONTRACT",
                icon: "doc.text.fill"
            )
        }
    }

    private static func fundingRows(from obj: Any) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any] else { return [] }
        if let funding = dict["funding"] as? [String: Any], let id = funding["id"] as? String {
            return [ToolActivityRow(
                id: id,
                title: "Funding — \(funding["status"] as? String ?? "status")",
                detail: funding["option"] as? String,
                actorName: nil,
                timestamp: DateParser.display(funding["updatedAt"] as? String),
                kind: "FUNDING",
                icon: "banknote.fill"
            )]
        }
        return []
    }

    private static func genericRows(from obj: Any, tool: ProjectTool) -> [ToolActivityRow] {
        guard let dict = obj as? [String: Any] else { return [] }
        var rows: [ToolActivityRow] = []
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            if let array = value as? [[String: Any]], !array.isEmpty, let first = array.first, first["id"] != nil {
                for item in array.prefix(20) {
                    guard let id = item["id"] as? String else { continue }
                    rows.append(ToolActivityRow(
                        id: "\(key)-\(id)",
                        title: item["title"] as? String ?? item["name"] as? String ?? key,
                        detail: item["description"] as? String ?? item["status"] as? String,
                        actorName: (item["createdBy"] as? [String: Any])?["name"] as? String
                            ?? (item["user"] as? [String: Any])?["name"] as? String,
                        timestamp: DateParser.display(item["createdAt"] as? String ?? item["updatedAt"] as? String),
                        kind: key.uppercased(),
                        icon: tool.systemImage
                    ))
                }
            }
        }
        return rows
    }

    private static func iconForTool(_ tool: ProjectTool) -> String {
        tool.systemImage
    }
}
