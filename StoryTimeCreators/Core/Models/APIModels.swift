import Foundation

// MARK: - Command Center

struct CommandCenterAPIResponse: Codable {
    var analytics: CreatorAnalyticsPayload?
    var overview: CommandCenterOverview?
    var production: CommandCenterProduction?
    var ai: CommandCenterAI?
    var retention: RetentionSnapshot?
}

struct CommandCenterOverview: Codable {
    var activeProjects: Int?
    var topFilmTitle: String?
    var topFilmViews: Int?
    var topFilmRevenueRand: Double?
    var viewerGrowth7dPct: Double?
    var engagementRateApprox: Double?
    var viewsLast7d: Int?
    var viewsPrev7d: Int?
}

struct CommandCenterProduction: Codable {
    var shootDaysTotal: Int?
    var openIncidents: Int?
    var callSheetsSaved: Int?
    var tasksByStatus: [String: Int]?
}

struct CommandCenterAI: Codable {
    var modocConversationsInRange: Int?
    var modocUserMessagesInRange: Int?
    var topTasks: [ModocTaskCount]?
}

struct ModocTaskCount: Codable, Identifiable {
    var task: String
    var count: Int
    var id: String { task }
}

struct CreatorAnalyticsPayload: Codable {
    var rangeKey: String?
    var period: AnalyticsPeriod?
    var revenue: AnalyticsRevenue?
    var engagement: AnalyticsEngagement?
    var contentPerformance: [ContentPerformanceRow]?
    var projects: AnalyticsProjects?
    var competition: AnalyticsCompetition?
}

struct AnalyticsPeriod: Codable {
    var start: String?
    var end: String?
}

struct AnalyticsRevenue: Codable {
    var amount: Double?
    var watchTimeSeconds: Double?
    var sharePercent: Double?
    var totalViews: Int?
    var streamCount: Int?
    var perViewRand: Double?
    var perStreamRand: Double?
    var creatorPool: Double?
    var viewerSubRevenue: Double?
}

struct AnalyticsEngagement: Codable {
    var totalViews: Int?
    var uniqueWatchers: Int?
    var averageWatchTimeSeconds: Double?
    var totalWatchTimeSeconds: Double?
    var totalComments: Int?
    var totalRatings: Int?
    var watchlistCount: Int?
    var contentCount: Int?
}

struct ContentPerformanceRow: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var type: String?
    var reviewStatus: String?
    var seasonCount: Int?
    var views: Int?
    var watchTimeSeconds: Double?
    var comments: Int?
    var ratings: Int?
    var watchlistAdds: Int?
    var avgRating: Double?
}

struct AnalyticsProjects: Codable {
    var total: Int?
    var byPhase: [String: Int]?
    var byStatus: [String: Int]?
}

struct AnalyticsCompetition: Codable {
    var periodName: String?
    var endDate: String?
    var rank: Int?
    var voteCount: Int?
}

struct RetentionSnapshot: Codable {
    var sampleSize: Int?
    var curve: [RetentionPoint]?
    var byTitle: [RetentionByTitle]?
}

struct RetentionPoint: Codable, Identifiable {
    var checkpoint: Int
    var retainedPct: Double
    var id: Int { checkpoint }
}

struct RetentionByTitle: Codable, Identifiable {
    var contentId: String
    var title: String
    var sampleSize: Int?
    var medianCompletionPct: Double?
    var curve: [RetentionPoint]?
    var id: String { contentId }
}

struct CommandCenterCalendarPayload: Codable {
    var events: [CommandCenterCalendarEvent]?
    var teamMembers: [CalendarTeamMember]?
    var companyId: String?
    var companyName: String?
    var isCompanyAccount: Bool?
    var projects: [CalendarProjectRef]?
    var rangeStart: String?
    var rangeEnd: String?
}

struct CommandCenterCalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    var kind: String?
    var title: String
    var description: String?
    var startAt: String
    var endAt: String?
    var allDay: Bool?
    var projectId: String?
    var projectTitle: String?
    var href: String?
    var editable: Bool?
    var visibility: String?
    var assigneeId: String?
    var assigneeName: String?
    var createdById: String?
    var status: String?

    var startDate: Date? { DateParser.parse(startAt) }
}

struct CalendarTeamMember: Codable, Identifiable {
    var userId: String
    var name: String
    var email: String?
    var profileDisplayName: String?
    var id: String { userId }
}

struct CalendarProjectRef: Codable, Identifiable, Hashable {
    let id: String
    var title: String
}

// MARK: - Network

struct NetworkPostsResponse: Codable {
    var posts: [EnrichedNetworkPost]?
}

struct EnrichedNetworkPost: Codable, Identifiable, Hashable {
    let id: String
    var authorId: String?
    var body: String?
    var imageUrls: String?
    var videoUrls: String?
    var contentId: String?
    var projectId: String?
    var postType: String?
    var createdAt: String?
    var updatedAt: String?
    var author: NetworkAuthor?
    var content: NetworkPostContentRef?
    var project: NetworkPostProjectRef?
    var likeCount: Int?
    var commentCount: Int?
    var saveCount: Int?
    var likedByViewer: Bool?
    var savedByViewer: Bool?

    var parsedImageURLs: [String] {
        JSONStringArray.decode(imageUrls)
    }

    var createdDate: Date? { DateParser.parse(createdAt) }
}

struct NetworkAuthor: Codable, Hashable {
    var id: String?
    var name: String?
    var email: String?
    var networkHandle: String?
    var handle: String?
    var displayName: String?
    var image: String?
    var headline: String?
    var primaryRole: String?
    var professionalName: String?

    var label: String {
        displayName ?? professionalName ?? name ?? (handle.map { "@\($0)" }) ?? "Creator"
    }
}

struct NetworkPostContentRef: Codable, Hashable {
    var id: String?
    var title: String?
    var type: String?
    var posterUrl: String?
}

struct NetworkPostProjectRef: Codable, Hashable {
    var id: String?
    var title: String?
    var type: String?
    var phase: String?
    var status: String?
}

struct NetworkCreatorsResponse: Codable {
    var creators: [DiscoverCreator]?
}

struct DiscoverCreator: Codable, Identifiable, Hashable {
    let id: String
    var name: String?
    var email: String?
    var networkHandle: String?
    var image: String?
    var bio: String?
    var role: String?
    var headline: String?
    var location: String?
    var handle: String?
    var displayName: String?
    var following: Bool?
    var connectionStatus: String?
    var followerCount: Int?

    var label: String {
        displayName ?? name ?? (handle.map { "@\($0)" }) ?? "Creator"
    }
}

struct NetworkConnectionsResponse: Codable {
    var received: [ConnectionRequestRow]?
    var sent: [ConnectionRequestRow]?
}

struct ConnectionRequestRow: Codable, Identifiable, Hashable {
    let id: String
    var fromId: String?
    var toId: String?
    var status: String?
    var message: String?
    var createdAt: String?
    var respondedAt: String?
    var from: NetworkAuthor?
    var to: NetworkAuthor?
}

struct NetworkProfileResponse: Codable {
    var user: NetworkProfileUser?
    var following: Bool?
    var connectionStatus: String?
    var followerCount: Int?
    var followingCount: Int?
    var contents: [NetworkProfileContent]?
    var posts: [EnrichedNetworkPost]?
}

struct NetworkProfileUser: Codable, Identifiable {
    let id: String
    var name: String?
    var email: String?
    var networkHandle: String?
    var image: String?
    var bio: String?
    var headline: String?
    var location: String?
    var website: String?
    var role: String?
    var previousWork: String?
    var handle: String?
    var displayName: String?
    var primaryRole: String?
    var professionalName: String?
    var skills: String?
    var expertiseAreas: String?
    var yearsExperience: Int?
    var networkProfilePublic: Bool?
    var createdAt: String?

    var label: String {
        displayName ?? professionalName ?? name ?? (handle.map { "@\($0)" }) ?? "Creator"
    }
}

struct NetworkProfileContent: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var type: String?
    var posterUrl: String?
    var createdAt: String?
}

struct NetworkChatsResponse: Codable {
    var conversations: [NetworkConversation]?
}

struct NetworkConversation: Codable, Identifiable, Hashable {
    let id: String
    var participants: [NetworkAuthor]?
    var lastMessage: NetworkChatMessage?
}

struct NetworkChatThreadResponse: Codable {
    var conversationId: String?
    var messages: [NetworkChatMessage]?
}

struct NetworkChatMessage: Codable, Identifiable, Hashable {
    let id: String
    var body: String?
    var createdAt: String?
    var sender: NetworkAuthor?
    var createdDate: Date? { DateParser.parse(createdAt) }
}

struct CreateNetworkPostBody: Encodable {
    var body: String?
    var imageUrls: [String]?
    var contentId: String?
}

struct ConnectBody: Encodable {
    var message: String?
}

struct ConnectionActionBody: Encodable {
    var action: String
    var requestId: String?
}

// MARK: - Messages (marketplace)

struct MarketplaceMessage: Codable, Identifiable, Hashable {
    let id: String
    var body: String
    var createdAt: String
    var senderId: String
    var receiverId: String
    var requestId: String?
    var locationBookingId: String?
    var crewTeamRequestId: String?
    var castingInquiryId: String?
    var cateringBookingId: String?
    var sender: MessageParty?
    var receiver: MessageParty?
    var request: EquipmentRequestContext?
    var locationBooking: LocationBookingContext?
    var crewTeamRequest: CrewRequestContext?
    var castingInquiry: CastingInquiryContext?
    var cateringBooking: CateringBookingContext?

    var createdDate: Date? { DateParser.parse(createdAt) }
}

struct MessageParty: Codable, Hashable {
    var id: String?
    var name: String?
    var role: String?
}

struct EquipmentRequestContext: Codable, Hashable {
    var id: String?
    var equipment: EquipmentCompanyRef?
}

struct EquipmentCompanyRef: Codable, Hashable {
    var companyName: String?
    var category: String?
}

struct LocationBookingContext: Codable, Hashable {
    var id: String?
    var location: LocationNameRef?
}

struct LocationNameRef: Codable, Hashable {
    var name: String?
    var type: String?
}

struct CrewRequestContext: Codable, Hashable {
    var id: String?
    var crewTeam: CrewCompanyRef?
}

struct CrewCompanyRef: Codable, Hashable {
    var companyName: String?
}

struct CastingInquiryContext: Codable, Hashable {
    var id: String?
    var agency: AgencyNameRef?
}

struct AgencyNameRef: Codable, Hashable {
    var agencyName: String?
}

struct CateringBookingContext: Codable, Hashable {
    var id: String?
    var cateringCompany: CateringCompanyRef?
}

struct CateringCompanyRef: Codable, Hashable {
    var companyName: String?
}

struct SendMarketplaceMessageBody: Encodable {
    var body: String
    var receiverId: String
    var requestId: String?
    var locationBookingId: String?
    var crewTeamRequestId: String?
    var castingInquiryId: String?
    var cateringBookingId: String?
}

// MARK: - Content / Catalogue

struct CreatorContentItem: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var description: String?
    var type: String?
    var posterUrl: String?
    var backdropUrl: String?
    var videoUrl: String?
    var trailerUrl: String?
    var category: String?
    var tags: String?
    var language: String?
    var country: String?
    var year: Int?
    var duration: Int?
    var episodes: Int?
    var reviewStatus: String?
    var reviewNote: String?
    var reviewFeedback: String?
    var submittedAt: String?
    var reviewedAt: String?
    var published: Bool?
    var createdAt: String?
    var updatedAt: String?
    var linkedProjectId: String?
    var _count: ContentCounts?
    var ratings: [ContentRatingScore]?
    var linkedProject: LinkedProjectRef?
    var seasons: [ContentSeasonRef]?
    var stream: ContentStreamInfo?

    var avgRating: Double? {
        guard let ratings, !ratings.isEmpty else { return nil }
        return Double(ratings.map(\.score).reduce(0, +)) / Double(ratings.count)
    }
}

struct ContentCounts: Codable, Hashable {
    var watchSessions: Int?
    var ratings: Int?
    var comments: Int?
    var seasons: Int?
}

struct ContentRatingScore: Codable, Hashable {
    var score: Int
}

struct LinkedProjectRef: Codable, Hashable {
    var id: String?
    var title: String?
}

struct ContentSeasonRef: Codable, Identifiable, Hashable {
    let id: String
    var seasonNumber: Int?
    var title: String?
    var published: Bool?
}

struct ContentStreamInfo: Codable, Hashable {
    var video: StreamAssetStatus?
    var trailer: StreamAssetStatus?
}

struct StreamAssetStatus: Codable, Hashable {
    var status: String?
    var playbackUrl: String?
}

struct CreateContentBody: Encodable {
    var contentId: String?
    var title: String
    var type: String
    var description: String?
    var posterUrl: String?
    var videoUrl: String?
    var trailerUrl: String?
    var linkedProjectId: String?
    var reviewStatus: String?
}

struct ContentDetailResponse: Codable {
    // GET ?id= returns single item directly
}

// MARK: - Upload

struct PresignRequest: Encodable {
    var fileName: String
    var size: Int
    var contentType: String?
}

struct PresignResponse: Decodable {
    var uploadUrl: String
    var key: String
    var contentType: String
    var headers: PresignHeaders?
}

struct PresignHeaders: Decodable {
    var contentType: String?

    enum CodingKeys: String, CodingKey {
        case contentType = "Content-Type"
    }
}

struct UploadCompleteRequest: Encodable {
    var key: String
    var contentType: String?
    var fileName: String?
}

struct UploadCompleteResponse: Decodable {
    var ok: Bool?
    var storageRef: String?
    var publicUrl: String?
    var sourceUrl: String?
    var streamPlaybackUrl: String?
    var streamHlsUrl: String?
}

// MARK: - Revenue

struct CreatorRevenueResponse: Codable {
    var revenue: Double?
    var watchTime: Double?
    var share: Double?
    var periodStart: String?
    var periodEnd: String?
    var totalViews: Int?
    var streamCount: Int?
    var perViewRand: Double?
    var perStreamRand: Double?
    var creatorPool: Double?
    var viewerSubRevenue: Double?
    var walletAvailable: Double?
    var walletTotalEarnings: Double?
    var projectedRevenue: Double?
}

// MARK: - Project workspace / activity

struct ProductionWorkspaceResponse: Codable {
    var activityFeed: [ProjectActivityItem]?
    var tasks: [ProjectTaskItem]?
    var taskSummary: [String: Int]?
}

struct ProjectActivityItem: Codable, Identifiable, Hashable {
    let id: String
    var type: String?
    var message: String?
    var metadata: String?
    var createdAt: String?
    var user: ActivityUser?

    var createdDate: Date? { DateParser.parse(createdAt) }
}

struct ActivityUser: Codable, Hashable {
    var id: String?
    var name: String?
    var email: String?
}

struct ProjectTaskItem: Codable, Identifiable, Hashable {
    let id: String
    var title: String?
    var description: String?
    var status: String?
    var priority: String?
    var dueDate: String?
    var department: String?
}

struct ScriptAPIResponse: Codable {
    var script: ProjectScriptDetail?
}

struct ProjectScriptDetail: Codable, Identifiable {
    let id: String
    var title: String?
    var currentVersionId: String?
    var createdAt: String?
    var updatedAt: String?
    var versions: [ScriptVersionDetail]?
}

struct ScriptVersionDetail: Codable, Identifiable, Hashable {
    let id: String
    var versionLabel: String?
    var content: String?
    var createdById: String?
    var createdAt: String?
    var autoSavedAt: String?
}

struct IdeasAPIResponse: Codable {
    var ideas: [ProjectIdeaDetail]?
}

struct ProjectIdeaDetail: Codable, Identifiable, Hashable {
    let id: String
    var title: String?
    var logline: String?
    var notes: String?
    var createdAt: String?
    var updatedAt: String?
}

struct ScriptReviewAPIResponse: Codable {
    var notes: ScriptReviewNotesPayload?
    var requests: [ScriptReviewRequestDetail]?
}

struct ScriptReviewNotesPayload: Codable {
    var body: String?
}

struct ScriptReviewRequestDetail: Codable, Identifiable, Hashable {
    let id: String
    var status: String?
    var createdAt: String?
    var requester: ActivityUser?
    var reviewer: ActivityUser?
    var scriptVersion: ScriptVersionRef?
}

struct ScriptVersionRef: Codable, Hashable {
    var id: String?
    var versionLabel: String?
    var createdAt: String?
}

struct ExpensesAPIResponse: Codable {
    var expenses: [ExpenseRow]?
    var dashboard: ExpenseDashboard?
}

struct ExpenseRow: Codable, Identifiable, Hashable {
    let id: String
    var department: String?
    var vendor: String?
    var description: String?
    var amount: Double?
    var spentAt: String?
    var createdAt: String?
    var createdBy: ActivityUser?
}

struct ExpenseDashboard: Codable {
    var totalBudget: Double?
    var totalSpend: Double?
    var remainingBudget: Double?
    var budgetHealthScore: Double?
}

struct ContinuityAPIResponse: Codable {
    var notes: [ContinuityNote]?
}

struct ContinuityNote: Codable, Identifiable, Hashable {
    let id: String
    var body: String?
    var createdAt: String?
    var createdBy: ActivityUser?
    var scene: SceneRef?
}

struct SceneRef: Codable, Hashable {
    var number: Int?
    var heading: String?
}

// MARK: - Tool activity row (UI)

struct ToolActivityRow: Identifiable, Hashable {
    let id: String
    var title: String
    var detail: String?
    var actorName: String?
    var timestamp: String?
    var kind: String?
    var icon: String
}

// MARK: - Helpers

enum DateParser {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let d = ISO8601DateFormatter.stFractional.date(from: raw) { return d }
        if let d = ISO8601DateFormatter.st.date(from: raw) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let d = f.date(from: raw) { return d }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: raw)
    }

    static func display(_ raw: String?) -> String {
        guard let date = parse(raw) else { return raw ?? "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    static func monthKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }
}

enum JSONStringArray {
    static func decode(_ raw: String?) -> [String] {
        guard let raw, let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

enum ModocStreamParser {
    /// Strips Vercel AI SDK / OpenRouter stream framing and returns human-readable text.
    static func extractText(from chunk: String) -> String {
        var output = ""
        var buffer = chunk
        while let start = buffer.firstIndex(of: "{") {
            if start > buffer.startIndex {
                let prefix = String(buffer[..<start])
                if !prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    output += prefix
                }
            }
            guard let end = buffer[start...].firstIndex(of: "}") else {
                break
            }
            let jsonSlice = buffer[start...end]
            if let data = jsonSlice.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let type = obj["type"] as? String {
                    if type == "text-delta", let delta = obj["textDelta"] as? String {
                        output += delta
                    } else if type == "text-delta", let delta = obj["delta"] as? String {
                        output += delta
                    } else if let text = obj["text"] as? String {
                        output += text
                    }
                } else if let text = obj["text"] as? String {
                    output += text
                } else if let delta = obj["delta"] as? String {
                    output += delta
                } else if let choices = obj["choices"] as? [[String: Any]],
                          let content = choices.first?["delta"] as? [String: Any],
                          let text = content["content"] as? String {
                    output += text
                }
            }
            buffer = end < buffer.endIndex ? String(buffer[buffer.index(after: end)...]) : ""
        }
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !trimmed.hasPrefix("{") {
            output += trimmed
        }
        return output
    }

    static func cleanFullResponse(_ text: String) -> String {
        if !text.contains("{\"type\"") && !text.contains("{\"type\":") {
            return text
        }
        var result = ""
        var remaining = text
        while let range = remaining.range(of: #"(\{"type"[^}]+\})"#, options: .regularExpression) {
            let before = String(remaining[..<range.lowerBound])
            if !before.isEmpty { result += before }
            let token = String(remaining[range])
            result += extractText(from: token)
            remaining = String(remaining[range.upperBound...])
        }
        result += extractText(from: remaining)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
