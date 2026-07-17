import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var auth: AuthService
    @StateObject private var va = VAController()

    var body: some View {
        ZStack(alignment: .leading) {
            STColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if shouldShowToolReturn {
                    ToolReturnBar()
                }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .disabled(router.isSideMenuOpen)
            .overlay {
                if router.isSideMenuOpen {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { router.closeMenu() }
                }
            }

            SideMenuView()
                .frame(width: 300)
                .offset(x: router.isSideMenuOpen ? 0 : -320)
                .zIndex(20)

            if !va.isOpen {
                VAFloatingButton(controller: va)
                    .zIndex(30)
            }

            if va.isOpen {
                VAPanelView(controller: va)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(40)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: va.isOpen)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: router.isSideMenuOpen)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.startLocation.x < 24 && value.translation.width > 60 {
                        router.toggleMenu()
                    } else if router.isSideMenuOpen && value.translation.width < -60 {
                        router.closeMenu()
                    }
                }
        )
    }

    private var shouldShowToolReturn: Bool {
        guard let origin = router.toolReturnDestination else { return false }
        guard origin == .preProduction || origin == .production || origin == .postProduction else {
            return false
        }
        switch router.destination {
        case .cast, .crew, .locations, .equipment, .catering, .music, .upload:
            return true
        default:
            return false
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { router.toggleMenu() } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(STColor.surfaceElevated))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(router.isShowingProjectTool ? (router.selectedTool?.label ?? router.destination.title) : router.destination.title)
                    .font(STFont.display(18, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                if let name = auth.currentUser?.displayName {
                    Text(name)
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.textMuted)
                }
            }

            Spacer()

            Image("SplashLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(STColor.background.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle().fill(STColor.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if router.isShowingProjectTool,
           let tool = router.selectedTool,
           let projectId = router.selectedProjectId {
            ProjectToolDetailView(projectId: projectId, tool: tool)
        } else {
            switch router.destination {
            case .commandCenter:
                CommandCenterView()
            case .projects:
                ProjectsView()
            case .network:
                NetworkView()
            case .messages:
                MessagesView()
            case .account:
                AccountView()
            case .catalogue:
                CatalogueView()
            case .upload:
                UploadView()
            case .revenue:
                RevenueView()
            case .originals:
                OriginalsView()
            case .preProduction:
                PhaseHubView(phase: .preProduction)
            case .production:
                PhaseHubView(phase: .production)
            case .postProduction:
                PhaseHubView(phase: .postProduction)
            case .cast:
                CastingPortalView()
            case .crew:
                CrewMarketplaceView()
            case .locations:
                LocationsView()
            case .equipment:
                EquipmentView()
            case .catering:
                CateringView()
            case .music:
                MusicScoringView()
            case .legalInbox:
                LegalInboxView()
            }
        }
    }
}
