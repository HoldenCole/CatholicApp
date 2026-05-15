import SwiftUI

// MARK: - Spotlight frame preference key

/// Views that want to be spotlighted report their frame via this key.
struct SpotlightFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - View modifier to register a spotlight anchor

extension View {
    /// Marks this view as a spotlight target with the given identifier.
    func spotlightAnchor(_ id: String) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: SpotlightFrameKey.self,
                        value: [id: geo.frame(in: .global)]
                    )
            }
        )
    }
}

// MARK: - TutorialOverlay

/// Full-screen overlay that dims the screen, optionally cuts a spotlight
/// hole around a named element, and shows an instruction pill.
struct TutorialOverlay: View {
    var manager: TutorialManager
    var spotlightFrames: [String: CGRect]

    @State private var visible = false

    var body: some View {
        if manager.isShowingTutorial, let step = manager.currentStep {
            ZStack {
                // Dim layer with optional spotlight cutout
                dimLayer(step: step)
                    .ignoresSafeArea()

                // Skip button — top right
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeOut(duration: 0.3)) {
                                visible = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                manager.skip()
                            }
                        } label: {
                            Text("Skip tutorial")
                                .font(.captionSm)
                                .foregroundStyle(Color.ivory.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Skip tutorial")
                    }
                    Spacer()
                }

                // Instruction pill
                pillView(step: step)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                let isLastStep = manager.currentStepIndex >= manager.currentSteps.count - 1
                withAnimation(.easeOut(duration: 0.3)) {
                    visible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    manager.advance()
                    if !isLastStep {
                        withAnimation(.easeIn(duration: 0.3)) {
                            visible = true
                        }
                    }
                }
            }
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(manager.isShowingTutorial)
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) {
                    visible = true
                }
            }
            .onChange(of: manager.isShowingTutorial) { _, showing in
                if showing {
                    withAnimation(.easeIn(duration: 0.3)) {
                        visible = true
                    }
                }
            }
            // Let system edge swipes (back gesture) pass through
            .gesture(
                DragGesture()
                    .onChanged { _ in }
                    .onEnded { _ in }
            )
        }
    }

    // MARK: - Dim layer

    @ViewBuilder
    private func dimLayer(step: TutorialStep) -> some View {
        if let elementID = step.spotlightElementID,
           let frame = spotlightFrames[elementID] {
            // Dim with rounded-rect cutout
            Canvas { context, size in
                // Fill entire canvas with dim colour
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color.walnut.opacity(0.75))
                )
                // Cut out the spotlight hole
                let insetFrame = frame.insetBy(dx: -8, dy: -8)
                let cutout = Path(roundedRect: insetFrame, cornerRadius: 12)
                context.blendMode = .destinationOut
                context.fill(cutout, with: .color(.white))
            }
            .compositingGroup()
        } else {
            // Full dim, no cutout
            Color.walnut.opacity(0.75)
        }
    }

    // MARK: - Instruction pill

    @ViewBuilder
    private func pillView(step: TutorialStep) -> some View {
        let pillContent = Text(step.text)
            .font(.body)
            .foregroundStyle(Color(.sRGB, red: 0.2, green: 0.15, blue: 0.1))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.parchment)
            )
            .padding(.horizontal, 32)

        switch step.pillPosition {
        case .top:
            VStack {
                pillContent
                    .padding(.top, 100)
                Spacer()
            }
        case .bottom:
            VStack {
                Spacer()
                pillContent
                    .padding(.bottom, 120)
            }
        case .center:
            pillContent
        }
    }
}
