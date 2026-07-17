import SwiftUI

/// Back chrome for marketplace tools opened from a phase hub.
struct ToolReturnBar: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        if let origin = router.toolReturnDestination,
           origin == .preProduction || origin == .production || origin == .postProduction {
            HStack {
                Button {
                    router.leaveToolDetail()
                } label: {
                    Label(origin.title, systemImage: "chevron.left")
                        .font(STFont.body(14, weight: .semibold))
                        .foregroundStyle(STColor.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }
}
