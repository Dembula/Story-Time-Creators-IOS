import SwiftUI

struct VAPanelView: View {
    @ObservedObject var controller: VAController
    @State private var input = ""

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 520
            let panelWidth = isCompact ? geo.size.width : min(400, geo.size.width * 0.9)

            ZStack(alignment: .trailing) {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { controller.close() }

                VStack(spacing: 0) {
                    header
                    messagesList
                    suggestionsRow
                    composer
                }
                .frame(width: panelWidth)
                .frame(maxHeight: .infinity)
                .background(STColor.surface)
                .safeAreaPadding(.bottom, 8)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: isCompact ? 0 : 20,
                        bottomLeadingRadius: isCompact ? 0 : 20,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: 24, x: -8)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .trailing)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(STColor.primary.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "sparkles")
                    .foregroundStyle(STColor.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Story Time VA")
                    .font(STFont.display(16, weight: .bold))
                    .foregroundStyle(STColor.textPrimary)
                Text(controller.statusAvailable ? "Online" : "Checking availability…")
                    .font(STFont.body(11))
                    .foregroundStyle(controller.statusAvailable ? STColor.success : STColor.textMuted)
            }

            Spacer()

            Button { controller.close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(STColor.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(STColor.surfaceElevated))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(STColor.background.opacity(0.95))
        .overlay(alignment: .bottom) {
            Rectangle().fill(STColor.border).frame(height: 1)
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if controller.messages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your production assistant")
                                .font(STFont.display(17, weight: .semibold))
                                .foregroundStyle(STColor.textPrimary)
                            Text("Ask about scripts, schedules, casting, crew, locations, or your pipeline.")
                                .font(STFont.body(13))
                                .foregroundStyle(STColor.textSecondary)
                        }
                        .padding(.top, 8)
                    }

                    ForEach(Array(controller.messages.enumerated()), id: \.offset) { index, message in
                        messageBubble(message)
                            .id(index)
                    }

                    if controller.isSending {
                        HStack(spacing: 8) {
                            ProgressView().tint(STColor.primary)
                            Text("Thinking…")
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.textMuted)
                        }
                        .padding(.leading, 4)
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: controller.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: controller.messages.last?.text) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func messageBubble(_ message: (role: String, text: String)) -> some View {
        let isUser = message.role == "user"
        return HStack {
            if isUser { Spacer(minLength: 24) }
            Text(message.text.isEmpty ? "…" : message.text)
                .font(STFont.body(14))
                .foregroundStyle(isUser ? Color.black.opacity(0.9) : STColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: 320, alignment: isUser ? .trailing : .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUser ? AnyShapeStyle(STColor.brandGradient) : AnyShapeStyle(STColor.surfaceElevated))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isUser ? Color.clear : STColor.border, lineWidth: 1)
                        )
                )
            if !isUser { Spacer(minLength: 24) }
        }
    }

    private var suggestionsRow: some View {
        Group {
            if !controller.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(controller.suggestions.enumerated()), id: \.offset) { _, suggestion in
                            Button {
                                controller.applySuggestion(suggestion)
                            } label: {
                                Text(suggestion)
                                    .font(STFont.body(12, weight: .medium))
                                    .foregroundStyle(STColor.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(STColor.primary.opacity(0.12))
                                            .overlay(Capsule().stroke(STColor.primary.opacity(0.28), lineWidth: 1))
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(controller.isSending)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .overlay(alignment: .top) {
                    Rectangle().fill(STColor.border).frame(height: 1)
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask anything…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(STFont.body(14))
                .foregroundStyle(STColor.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(STColor.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(STColor.border, lineWidth: 1)
                        )
                )

            Button {
                let text = input
                input = ""
                Task { await controller.send(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(canSend ? STColor.primary : STColor.textMuted)
            }
            .disabled(!canSend)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(STColor.background.opacity(0.98))
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !controller.isSending
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard !controller.messages.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(controller.messages.count - 1, anchor: .bottom)
        }
    }
}
