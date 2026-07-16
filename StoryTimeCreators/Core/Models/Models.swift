import Foundation

struct CreatorUser: Codable, Identifiable, Equatable {
    let id: String
    var name: String?
    var email: String?
    var image: String?
    var role: String?
    var activeRole: String?
    var bio: String?
    var headline: String?
    var location: String?
    var website: String?
    var networkHandle: String?
    var professionalName: String?
    var phoneNumber: String?
    var platformRoles: [String]?
    var multiRole: Bool?

    var displayName: String {
        if let professionalName, !professionalName.isEmpty { return professionalName }
        if let name, !name.isEmpty { return name }
        if let networkHandle, !networkHandle.isEmpty { return "@\(networkHandle)" }
        return email ?? "Creator"
    }

    var effectiveRole: String {
        activeRole ?? role ?? ""
    }

    var isCreatorPortalEligible: Bool {
        let roles = Set((platformRoles ?? []) + [effectiveRole].filter { !$0.isEmpty })
        let creator = Set([
            "CONTENT_CREATOR", "MUSIC_CREATOR", "EQUIPMENT_COMPANY", "LOCATION_OWNER",
            "CREW_TEAM", "CASTING_AGENCY", "CATERING_COMPANY", "FUNDER", "ADMIN",
        ])
        return !roles.isDisjoint(with: creator)
    }
}

struct ProjectsResponse: Codable {
    let projects: [CreatorProject]
    let meId: String?
}

struct CreatorProject: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var logline: String?
    var type: String?
    var genre: String?
    var status: String?
    var phase: String?
    var budget: Double?
    var createdAt: String?
    var updatedAt: String?
    var ideasCount: Int?
    var isOriginal: Bool?
    var pipelineRollup: PipelineRollup?
    var projectToolProgress: [ToolProgress]?

    var phaseLabel: String {
        switch (phase ?? status ?? "").uppercased() {
        case "PRE_PRODUCTION": return "Pre-Production"
        case "PRODUCTION": return "Production"
        case "POST_PRODUCTION": return "Post-Production"
        default: return phase ?? status ?? "Project"
        }
    }
}

struct PipelineRollup: Codable, Hashable {
    var overallPercent: Double?
    var completedTools: Int?
    var totalTools: Int?
}

struct ToolProgress: Codable, Hashable, Identifiable {
    var toolId: String
    var phase: String?
    var status: String?
    var percent: Double?

    var id: String { toolId }
}

struct CommandCenterPayload: Codable {
    var range: String?
    var stats: CommandCenterStats?
    var recentProjects: [CreatorProject]?
    var calendarEvents: [CalendarEvent]?
    var revenue: RevenueSnapshot?
    var ecosystem: EcosystemSummary?
}

struct CommandCenterStats: Codable {
    var projectCount: Int?
    var catalogueCount: Int?
    var watchHours: Double?
    var revenueZar: Double?
    var messagesUnread: Int?
    var networkConnections: Int?
}

struct RevenueSnapshot: Codable {
    var totalZar: Double?
    var periodZar: Double?
    var currency: String?
}

struct EcosystemSummary: Codable {
    var castCount: Int?
    var crewCount: Int?
    var locationCount: Int?
    var equipmentCount: Int?
}

struct CalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var startsAt: String?
    var endsAt: String?
    var projectId: String?
    var notes: String?
}

struct ContentListResponse: Codable {
    var content: [CatalogueItem]?
    var items: [CatalogueItem]?

    var all: [CatalogueItem] { content ?? items ?? [] }
}

struct CatalogueItem: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var type: String?
    var reviewStatus: String?
    var thumbnailUrl: String?
    var posterUrl: String?
    var createdAt: String?
}

struct MessagesResponse: Codable {
    var threads: [MessageThread]?
    var messages: [ChatMessage]?
}

struct MessageThread: Codable, Identifiable, Hashable {
    let id: String
    var subject: String?
    var preview: String?
    var updatedAt: String?
    var unreadCount: Int?
    var counterpartName: String?
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    var body: String?
    var content: String?
    var createdAt: String?
    var senderId: String?
    var senderName: String?

    var text: String { body ?? content ?? "" }
}

struct NetworkFeedResponse: Codable {
    var posts: [NetworkPost]?
    var connections: [NetworkPerson]?
}

struct NetworkPost: Codable, Identifiable, Hashable {
    let id: String
    var body: String?
    var authorName: String?
    var authorId: String?
    var createdAt: String?
    var likeCount: Int?
}

struct NetworkPerson: Codable, Identifiable, Hashable {
    let id: String
    var name: String?
    var headline: String?
    var image: String?
    var networkHandle: String?
}

struct CastRosterResponse: Codable {
    var items: [RosterContact]?
    var roster: [RosterContact]?
    var contacts: [RosterContact]?

    var all: [RosterContact] { items ?? roster ?? contacts ?? [] }
}

struct RosterContact: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var role: String?
    var email: String?
    var phone: String?
    var notes: String?
    var agency: String?
    var department: String?
    var pastWork: String?
    var pastProjects: String?

    enum CodingKeys: String, CodingKey {
        case id, name, role, email, phone, notes, agency, department, pastWork, pastProjects
        case roleType, contactEmail
    }

    init(
        id: String,
        name: String,
        role: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        notes: String? = nil,
        agency: String? = nil,
        department: String? = nil,
        pastWork: String? = nil,
        pastProjects: String? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.email = email
        self.phone = phone
        self.notes = notes
        self.agency = agency
        self.department = department
        self.pastWork = pastWork
        self.pastProjects = pastProjects
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        role = (try? c.decode(String.self, forKey: .role))
            ?? (try? c.decode(String.self, forKey: .roleType))
        email = (try? c.decode(String.self, forKey: .email))
            ?? (try? c.decode(String.self, forKey: .contactEmail))
        phone = try? c.decode(String.self, forKey: .phone)
        notes = try? c.decode(String.self, forKey: .notes)
        agency = try? c.decode(String.self, forKey: .agency)
        department = try? c.decode(String.self, forKey: .department)
        pastWork = try? c.decode(String.self, forKey: .pastWork)
        pastProjects = try? c.decode(String.self, forKey: .pastProjects)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(role, forKey: .role)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(phone, forKey: .phone)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(agency, forKey: .agency)
        try c.encodeIfPresent(department, forKey: .department)
        try c.encodeIfPresent(pastWork, forKey: .pastWork)
        try c.encodeIfPresent(pastProjects, forKey: .pastProjects)
    }
}

struct LocationListResponse: Codable {
    var locations: [LocationListing]?
    var items: [LocationListing]?

    var all: [LocationListing] { locations ?? items ?? [] }
}

struct LocationListing: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var type: String?
    var city: String?
    var dailyRate: Double?
    var description: String?
    var photoUrls: [String]?
}

struct CrewTeamsResponse: Codable {
    var teams: [CrewTeam]?
    var items: [CrewTeam]?

    var all: [CrewTeam] { teams ?? items ?? [] }
}

struct CrewTeam: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var specialty: String?
    var location: String?
    var description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, specialty, location, description, companyName, city, country, specializations
    }

    init(id: String, name: String, specialty: String? = nil, location: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.specialty = specialty
        self.location = location
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .companyName))
            ?? "Crew Team"
        specialty = (try? c.decode(String.self, forKey: .specialty))
            ?? (try? c.decode(String.self, forKey: .specializations))
        let city = try? c.decode(String.self, forKey: .city)
        let country = try? c.decode(String.self, forKey: .country)
        if let loc = try? c.decode(String.self, forKey: .location) {
            location = loc
        } else if city != nil || country != nil {
            location = [city, country].compactMap { $0 }.joined(separator: ", ")
        }
        description = try? c.decode(String.self, forKey: .description)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(specialty, forKey: .specialty)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(description, forKey: .description)
    }
}

struct CastingAgenciesResponse: Codable {
    var agencies: [CastingAgency]?
    var items: [CastingAgency]?

    var all: [CastingAgency] { agencies ?? items ?? [] }
}

struct CastingAgency: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var location: String?
    var description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, location, description, agencyName, city, country
    }

    init(id: String, name: String, location: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.location = location
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .agencyName))
            ?? "Agency"
        if let loc = try? c.decode(String.self, forKey: .location) {
            location = loc
        } else {
            let city = try? c.decode(String.self, forKey: .city)
            let country = try? c.decode(String.self, forKey: .country)
            location = [city, country].compactMap { $0 }.joined(separator: ", ")
            if location?.isEmpty == true { location = nil }
        }
        description = try? c.decode(String.self, forKey: .description)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(description, forKey: .description)
    }
}

struct EquipmentListResponse: Codable {
    var equipment: [EquipmentItem]?
    var items: [EquipmentItem]?

    var all: [EquipmentItem] { equipment ?? items ?? [] }
}

struct EquipmentItem: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var category: String?
    var dailyRate: Double?
    var description: String?
    var location: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, dailyRate, description, location, companyName
    }

    init(id: String, name: String, category: String? = nil, dailyRate: Double? = nil, description: String? = nil, location: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.dailyRate = dailyRate
        self.description = description
        self.location = location
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .companyName))
            ?? "Equipment"
        category = try? c.decode(String.self, forKey: .category)
        dailyRate = try? c.decode(Double.self, forKey: .dailyRate)
        description = try? c.decode(String.self, forKey: .description)
        location = try? c.decode(String.self, forKey: .location)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encodeIfPresent(dailyRate, forKey: .dailyRate)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(location, forKey: .location)
    }
}

struct CateringListResponse: Codable {
    var companies: [CateringCompany]?
    var items: [CateringCompany]?

    var all: [CateringCompany] { companies ?? items ?? [] }
}

struct CateringCompany: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var cuisine: String?
    var location: String?
    var description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, cuisine, location, description, companyName, city, country, specializations
    }

    init(id: String, name: String, cuisine: String? = nil, location: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.cuisine = cuisine
        self.location = location
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .companyName))
            ?? "Catering"
        cuisine = (try? c.decode(String.self, forKey: .cuisine))
            ?? (try? c.decode(String.self, forKey: .specializations))
        if let loc = try? c.decode(String.self, forKey: .location) {
            location = loc
        } else {
            let city = try? c.decode(String.self, forKey: .city)
            let country = try? c.decode(String.self, forKey: .country)
            location = [city, country].compactMap { $0 }.joined(separator: ", ")
            if location?.isEmpty == true { location = nil }
        }
        description = try? c.decode(String.self, forKey: .description)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(cuisine, forKey: .cuisine)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(description, forKey: .description)
    }
}

struct ProjectIdeasResponse: Codable {
    var ideas: [ProjectIdea]?
}

struct ProjectIdea: Codable, Identifiable, Hashable {
    let id: String
    var title: String?
    var summary: String?
    var notes: String?
    var createdAt: String?
}

struct ProjectScriptResponse: Codable {
    var script: ProjectScript?
    var versions: [ScriptVersion]?
}

struct ProjectScript: Codable, Identifiable, Hashable {
    let id: String
    var title: String?
    var content: String?
    var body: String?
    var updatedAt: String?

    var text: String { content ?? body ?? "" }
}

struct ScriptVersion: Codable, Identifiable, Hashable {
    let id: String
    var label: String?
    var createdAt: String?
}

struct BudgetResponse: Codable {
    var lines: [BudgetLine]?
    var total: Double?
    var currency: String?
}

struct BudgetLine: Codable, Identifiable, Hashable {
    let id: String
    var category: String?
    var description: String?
    var amount: Double?
}

struct ScheduleResponse: Codable {
    var days: [ShootDay]?
}

struct ShootDay: Codable, Identifiable, Hashable {
    let id: String
    var date: String?
    var location: String?
    var callTime: String?
    var notes: String?
}

struct CastingRolesResponse: Codable {
    var roles: [CastingRole]?
}

struct CastingRole: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var importance: String?
    var status: String?
    var description: String?
    var dailyRate: Double?
}

struct ModocStatus: Codable {
    var available: Bool?
    var provider: String?
    var defaultModel: String?
}

struct ModocContext: Codable {
    var greeting: String?
    var suggestions: [String]?
    var unreadCount: Int?
}

struct CreateProjectBody: Encodable {
    var title: String
    var logline: String?
    var type: String?
    var genre: String?
}

struct CreateRosterBody: Encodable {
    var name: String
    var role: String?
    var email: String?
    var phone: String?
    var notes: String?
}

struct InquiryBody: Encodable {
    var message: String
    var projectId: String?
    var agencyId: String?
    var teamId: String?
    var locationId: String?
    var equipmentId: String?
    var cateringCompanyId: String?
}

struct BookingRequestBody: Encodable {
    var locationId: String?
    var equipmentId: String?
    var cateringCompanyId: String?
    var projectId: String?
    var message: String?
    var startDate: String?
    var endDate: String?
}

struct ChatPostBody: Encodable {
    var messages: [ChatUIMessage]
    var scope: String?
    var pageContext: [String: String]?
    var conversationId: String?
}

struct ChatUIMessage: Encodable {
    var role: String
    var content: String
}

struct CalendarEventsResponse: Codable {
    var events: [CalendarEvent]?
}

struct MusicTrack: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var artistName: String?
    var genre: String?
    var mood: String?
    var duration: Int?
    var description: String?
    var licenseType: String?

    enum CodingKeys: String, CodingKey {
        case id, title, artistName, genre, mood, duration, description, licenseType
    }

    init(id: String, title: String, artistName: String? = nil, genre: String? = nil, mood: String? = nil, duration: Int? = nil, description: String? = nil, licenseType: String? = nil) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.genre = genre
        self.mood = mood
        self.duration = duration
        self.description = description
        self.licenseType = licenseType
    }
}

struct LegalInboxItem: Codable, Identifiable, Hashable {
    let id: String
    var projectId: String
    var projectTitle: String
    var title: String
    var status: String?
    var statusLabel: String?
    var senderName: String?
    var requiredAction: String?
    var signatureDeadline: String?
    var updatedAt: String?
}

struct LegalInboxBuckets: Codable {
    var waitingForYou: [LegalInboxItem]?
    var pending: [LegalInboxItem]?
    var completed: [LegalInboxItem]?
}

struct LegalInboxResponse: Codable {
    var buckets: LegalInboxBuckets?
}

struct CreateCastRosterBody: Encodable {
    var name: String
    var roleType: String?
    var contactEmail: String?
    var notes: String?
    var pastWork: String?
}

struct UpdateCastRosterBody: Encodable {
    var name: String?
    var roleType: String?
    var contactEmail: String?
    var notes: String?
    var pastWork: String?
}

struct CreateCrewRosterBody: Encodable {
    var name: String
    var role: String?
    var department: String?
    var contactEmail: String?
    var phone: String?
    var notes: String?
    var pastProjects: String?
}

struct CastInquiryBody: Encodable {
    var agencyId: String
    var projectName: String?
    var roleName: String?
    var message: String?
    var talentId: String?
    var projectId: String?
}

struct CrewTeamRequestBody: Encodable {
    var crewTeamId: String
    var projectName: String?
    var message: String?
    var projectId: String?
}

struct LocationBookingBody: Encodable {
    var locationId: String
    var note: String?
    var shootType: String?
    var startDate: String?
    var endDate: String?
    var crewSize: Int?
    var projectId: String?
    var projectTitle: String?
}

struct EquipmentRequestBody: Encodable {
    var equipmentId: String
    var note: String?
    var startDate: String?
    var endDate: String?
    var projectId: String?
    var projectTitle: String?
}

struct CateringBookingBody: Encodable {
    var cateringCompanyId: String
    var eventDate: String?
    var headCount: Int?
    var note: String?
    var projectId: String?
    var projectTitle: String?
}

struct MusicSelectionBody: Encodable {
    var trackId: String
    var usage: String?
    var notes: String?
}

struct MusicSelectionResponse: Codable {
    var selection: MusicSelection?
}

struct MusicSelection: Codable, Identifiable, Hashable {
    let id: String
    var usage: String?
    var notes: String?
    var track: MusicTrack?
}

struct IdResponse: Decodable {
    let id: String
}

struct OkResponse: Decodable {
    var ok: Bool?
}
