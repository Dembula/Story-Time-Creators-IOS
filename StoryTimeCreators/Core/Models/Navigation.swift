import Foundation
import Combine
import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable, Hashable {
    case commandCenter
    case projects
    case network
    case messages
    case account
    case catalogue
    case upload
    case revenue
    case originals
    case preProduction
    case production
    case postProduction
    case cast
    case crew
    case locations
    case equipment
    case catering
    case music
    case legalInbox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commandCenter: return "Command Center"
        case .projects: return "My Projects"
        case .network: return "Network"
        case .messages: return "Messages"
        case .account: return "My Account"
        case .catalogue: return "My Catalogue"
        case .upload: return "Catalogue Upload"
        case .revenue: return "Revenue"
        case .originals: return "Originals"
        case .preProduction: return "Pre-Production"
        case .production: return "Production"
        case .postProduction: return "Post-Production"
        case .cast: return "Casting Portal"
        case .crew: return "Crew"
        case .locations: return "Locations"
        case .equipment: return "Equipment"
        case .catering: return "Catering"
        case .music: return "Music & Scoring"
        case .legalInbox: return "Legal Inbox"
        }
    }

    var systemImage: String {
        switch self {
        case .commandCenter: return "square.grid.2x2.fill"
        case .projects: return "folder.fill"
        case .network: return "person.3.fill"
        case .messages: return "bubble.left.and.bubble.right.fill"
        case .account: return "person.crop.circle.fill"
        case .catalogue: return "film.stack.fill"
        case .upload: return "arrow.up.doc.fill"
        case .revenue: return "chart.line.uptrend.xyaxis"
        case .originals: return "star.circle.fill"
        case .preProduction: return "list.clipboard.fill"
        case .production: return "video.fill"
        case .postProduction: return "slider.horizontal.3"
        case .cast: return "theatermasks.fill"
        case .crew: return "wrench.and.screwdriver.fill"
        case .locations: return "mappin.and.ellipse"
        case .equipment: return "camera.fill"
        case .catering: return "fork.knife"
        case .music: return "music.note.list"
        case .legalInbox: return "doc.text.fill"
        }
    }

    static let operating: [AppDestination] = [
        .commandCenter, .projects, .network, .messages, .account,
    ]

    static let monetization: [AppDestination] = [
        .catalogue, .upload, .revenue,
    ]

    static let pipeline: [AppDestination] = [
        .preProduction, .production, .postProduction,
    ]
}

enum ProjectTool: String, CaseIterable, Identifiable, Hashable {
    // Pre
    case ideaDevelopment = "idea-development"
    case scriptWriting = "script-writing"
    case scriptReview = "script-review"
    case scriptBreakdown = "script-breakdown"
    case budgetBuilder = "budget-builder"
    case productionScheduling = "production-scheduling"
    case castingPortal = "casting-portal"
    case crewMarketplace = "crew-marketplace"
    case locationMarketplace = "location-marketplace"
    case visualPlanning = "visual-planning"
    case legalContracts = "legal-contracts"
    case fundingHub = "funding-hub"
    case tableReads = "table-reads"
    case productionWorkspace = "production-workspace"
    case equipmentPlanning = "equipment-planning"
    case riskInsurance = "risk-insurance"
    case productionReadiness = "production-readiness"
    // Production
    case controlCenter = "control-center"
    case callSheetGenerator = "call-sheet-generator"
    case onSetTasks = "on-set-tasks"
    case equipmentTracking = "equipment-tracking"
    case shootProgress = "shoot-progress"
    case continuityManager = "continuity-manager"
    case dailiesReview = "dailies-review"
    case expenseTracker = "expense-tracker"
    case incidentReporting = "incident-reporting"
    case onSetCatering = "on-set-catering"
    case wrap = "wrap"
    // Post
    case footageIngestion = "footage-ingestion"
    case editingStudio = "editing-studio"
    case soundDesign = "sound-design"
    case musicScoring = "music-scoring"
    case visualEffects = "visual-effects"
    case colorGrading = "color-grading"
    case finalSoundMix = "final-sound-mix"
    case finalCutApproval = "final-cut-approval"
    case filmPackaging = "film-packaging"
    case distribution = "distribution"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ideaDevelopment: return "Idea Development"
        case .scriptWriting: return "Script Writing"
        case .scriptReview: return "Script Review"
        case .scriptBreakdown: return "Script Breakdown"
        case .budgetBuilder: return "Budget Builder"
        case .productionScheduling: return "Production Scheduling"
        case .castingPortal: return "Casting Portal"
        case .crewMarketplace: return "Crew Marketplace"
        case .locationMarketplace: return "Location Marketplace"
        case .visualPlanning: return "Visual Planning"
        case .legalContracts: return "Legal & Contracts"
        case .fundingHub: return "Funding Hub"
        case .tableReads: return "Table Reads"
        case .productionWorkspace: return "Production Workspace"
        case .equipmentPlanning: return "Equipment Planning"
        case .riskInsurance: return "Risk & Insurance"
        case .productionReadiness: return "Production Readiness"
        case .controlCenter: return "Production Control Center"
        case .callSheetGenerator: return "Call Sheet Generator"
        case .onSetTasks: return "On-Set Tasks"
        case .equipmentTracking: return "Equipment Tracking"
        case .shootProgress: return "Shoot Progress"
        case .continuityManager: return "Continuity Manager"
        case .dailiesReview: return "Dailies Review"
        case .expenseTracker: return "Expense Tracker"
        case .incidentReporting: return "Incident Reporting"
        case .onSetCatering: return "On-Set Catering"
        case .wrap: return "Production Wrap"
        case .footageIngestion: return "Footage Ingestion"
        case .editingStudio: return "Editing Studio"
        case .soundDesign: return "Sound Design"
        case .musicScoring: return "Music & Scoring"
        case .visualEffects: return "Visual Effects"
        case .colorGrading: return "Color Grading"
        case .finalSoundMix: return "Final Sound Mix"
        case .finalCutApproval: return "Final Cut Approval"
        case .filmPackaging: return "Film Packaging"
        case .distribution: return "Distribution"
        }
    }

    var phase: ProjectPhase {
        switch self {
        case .ideaDevelopment, .scriptWriting, .scriptReview, .scriptBreakdown, .budgetBuilder,
             .productionScheduling, .castingPortal, .crewMarketplace, .locationMarketplace,
             .visualPlanning, .legalContracts, .fundingHub, .tableReads, .productionWorkspace,
             .equipmentPlanning, .riskInsurance, .productionReadiness:
            return .preProduction
        case .controlCenter, .callSheetGenerator, .onSetTasks, .equipmentTracking, .shootProgress,
             .continuityManager, .dailiesReview, .expenseTracker, .incidentReporting, .onSetCatering, .wrap:
            return .production
        default:
            return .postProduction
        }
    }

    var apiPathSegment: String {
        switch self {
        case .ideaDevelopment: return "ideas"
        case .scriptWriting: return "script"
        case .scriptReview: return "script-review"
        case .scriptBreakdown: return "breakdown"
        case .budgetBuilder: return "budget"
        case .productionScheduling: return "schedule"
        case .castingPortal: return "casting"
        case .crewMarketplace: return "crew"
        case .locationMarketplace: return "visual-assets"
        case .visualPlanning: return "visual-assets"
        case .legalContracts: return "contracts"
        case .fundingHub: return "funding"
        case .tableReads: return "table-reads"
        case .productionWorkspace: return "production-workspace"
        case .equipmentPlanning: return "equipment-plan"
        case .riskInsurance: return "risk"
        case .productionReadiness: return "readiness"
        case .controlCenter: return "production-control-center"
        case .callSheetGenerator: return "call-sheets"
        case .onSetTasks: return "tasks"
        case .equipmentTracking: return "equipment-plan"
        case .shootProgress: return "shoot-progress"
        case .continuityManager: return "continuity"
        case .dailiesReview: return "dailies"
        case .expenseTracker: return "expenses"
        case .incidentReporting: return "incidents"
        case .onSetCatering: return "vendors"
        case .wrap: return "production-wrap"
        case .footageIngestion: return "footage"
        case .musicScoring: return "music-selection"
        case .distribution: return "distribution"
        case .editingStudio, .soundDesign, .visualEffects, .colorGrading,
             .finalSoundMix, .finalCutApproval, .filmPackaging:
            return "final-delivery"
        }
    }

    static func tools(for phase: ProjectPhase) -> [ProjectTool] {
        allCases.filter { $0.phase == phase }
    }

    /// Tools shown on phase hub pages (matches web `POST_PRODUCTION_HUB_TOOLS`).
    static func hubTools(for phase: ProjectPhase) -> [ProjectTool] {
        switch phase {
        case .postProduction:
            return [.musicScoring, .distribution]
        default:
            return tools(for: phase)
        }
    }

    var systemImage: String {
        switch self {
        case .ideaDevelopment: return "lightbulb.fill"
        case .scriptWriting: return "pencil.and.outline"
        case .scriptReview: return "doc.text.magnifyingglass"
        case .scriptBreakdown: return "list.bullet.rectangle"
        case .budgetBuilder: return "dollarsign.circle.fill"
        case .productionScheduling: return "calendar"
        case .castingPortal: return "theatermasks.fill"
        case .crewMarketplace: return "person.3.fill"
        case .locationMarketplace: return "mappin.and.ellipse"
        case .visualPlanning: return "photo.on.rectangle.angled"
        case .legalContracts: return "doc.text.fill"
        case .fundingHub: return "banknote.fill"
        case .tableReads: return "book.fill"
        case .productionWorkspace: return "folder.fill"
        case .equipmentPlanning: return "camera.fill"
        case .riskInsurance: return "shield.fill"
        case .productionReadiness: return "checkmark.seal.fill"
        case .controlCenter: return "slider.horizontal.3"
        case .callSheetGenerator: return "doc.richtext.fill"
        case .onSetTasks: return "checklist"
        case .equipmentTracking: return "shippingbox.fill"
        case .shootProgress: return "chart.bar.fill"
        case .continuityManager: return "film.fill"
        case .dailiesReview: return "play.rectangle.fill"
        case .expenseTracker: return "creditcard.fill"
        case .incidentReporting: return "exclamationmark.triangle.fill"
        case .onSetCatering: return "fork.knife"
        case .wrap: return "flag.checkered"
        case .footageIngestion: return "arrow.down.doc.fill"
        case .editingStudio: return "scissors"
        case .soundDesign: return "waveform"
        case .musicScoring: return "music.note.list"
        case .visualEffects: return "sparkles"
        case .colorGrading: return "paintpalette.fill"
        case .finalSoundMix: return "speaker.wave.3.fill"
        case .finalCutApproval: return "checkmark.circle.fill"
        case .filmPackaging: return "shippingbox.fill"
        case .distribution: return "globe"
        }
    }
}

enum ProjectPhase: String, CaseIterable, Identifiable {
    case preProduction = "PRE_PRODUCTION"
    case production = "PRODUCTION"
    case postProduction = "POST_PRODUCTION"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preProduction: return "Pre-Production"
        case .production: return "Production"
        case .postProduction: return "Post-Production"
        }
    }

    var destination: AppDestination {
        switch self {
        case .preProduction: return .preProduction
        case .production: return .production
        case .postProduction: return .postProduction
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var destination: AppDestination = .commandCenter
    @Published var isSideMenuOpen = false
    @Published var selectedProjectId: String?
    @Published var selectedTool: ProjectTool?
    @Published var projectPath: [ProjectNav] = []
    /// Where to return after leaving a tool (phase hub vs projects).
    @Published var toolReturnDestination: AppDestination?

    var isShowingProjectTool: Bool {
        guard let tool = selectedTool else { return false }
        return !tool.isMarketplaceStyle
    }

    func open(_ dest: AppDestination) {
        destination = dest
        selectedTool = nil
        toolReturnDestination = nil
        if dest == .projects {
            selectedProjectId = nil
            projectPath = []
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isSideMenuOpen = false
        }
    }

    func toggleMenu() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isSideMenuOpen.toggle()
        }
    }

    func closeMenu() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isSideMenuOpen = false
        }
    }

    func openProject(_ id: String) {
        selectedProjectId = id
        projectPath = [.overview(id)]
        destination = .projects
        selectedTool = nil
        toolReturnDestination = nil
        closeMenu()
    }

    func openTool(_ tool: ProjectTool, projectId: String?) {
        toolReturnDestination = destination
        selectedTool = tool
        selectedProjectId = projectId ?? selectedProjectId

        switch tool {
        case .castingPortal:
            destination = .cast
        case .crewMarketplace:
            destination = .crew
        case .locationMarketplace:
            destination = .locations
        case .equipmentPlanning:
            destination = .equipment
        case .onSetCatering:
            destination = .catering
        case .musicScoring:
            destination = .music
        case .distribution:
            destination = .upload
        default:
            // Stay on the current screen (phase hub or projects); shell overlays the tool report.
            if let pid = selectedProjectId {
                projectPath = [.overview(pid), .tool(pid, tool)]
            }
        }
        closeMenu()
    }

    func leaveToolDetail() {
        let returnTo = toolReturnDestination
        selectedTool = nil
        toolReturnDestination = nil
        if let pid = selectedProjectId {
            projectPath = [.overview(pid)]
        } else {
            projectPath = []
        }
        if let returnTo {
            destination = returnTo
        }
    }
}

enum ProjectNav: Hashable {
    case overview(String)
    case tool(String, ProjectTool)
}

extension ProjectTool {
    var isMarketplaceStyle: Bool {
        switch self {
        case .castingPortal, .crewMarketplace, .locationMarketplace,
             .equipmentPlanning, .onSetCatering, .musicScoring, .distribution:
            return true
        default:
            return false
        }
    }
}
