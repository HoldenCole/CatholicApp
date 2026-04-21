import SwiftUI

// Two shared visual treatments that every Introibo page uses:
//   1. The gold hairline page frame  (PageFrameModifier)
//   2. The subtle paper grain overlay (PaperGrainOverlay)
//
// Apply both with .pageChrome() — or use them individually.

struct PageFrameModifier: ViewModifier {
    var inset: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    // Outer hairline
                    Rectangle()
                        .stroke(Color.frameLine, lineWidth: 0.5)
                    // Faint inner hairline, 3pt in
                    Rectangle()
                        .stroke(Color.frameLine.opacity(0.5), lineWidth: 0.5)
                        .padding(3)
                }
                .padding(inset)
                .allowsHitTesting(false)
            )
    }
}

struct PaperGrainOverlay: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                // Subtle dot pattern using a Canvas — three layered radial
                // dot fields at different scales, multiplied on top of the
                // page to add tactile warmth without washing out the content.
                Canvas { ctx, size in
                    let layers: [(step: CGFloat, radius: CGFloat, alpha: Double, offset: CGPoint)] = [
                        (step: 7,  radius: 0.6, alpha: 0.025, offset: CGPoint(x: 1, y: 2)),
                        (step: 13, radius: 0.7, alpha: 0.02,  offset: CGPoint(x: 5, y: 9)),
                        (step: 11, radius: 0.6, alpha: 0.018, offset: CGPoint(x: 3, y: 7)),
                    ]
                    let dotColor = Color(red: 92/255, green: 60/255, blue: 30/255)
                    for layer in layers {
                        var y: CGFloat = layer.offset.y
                        while y < size.height {
                            var x: CGFloat = layer.offset.x
                            while x < size.width {
                                let rect = CGRect(
                                    x: x - layer.radius, y: y - layer.radius,
                                    width: layer.radius * 2, height: layer.radius * 2
                                )
                                ctx.fill(Path(ellipseIn: rect), with: .color(dotColor.opacity(layer.alpha)))
                                x += layer.step
                            }
                            y += layer.step
                        }
                    }
                }
                .blendMode(.multiply)
                .opacity(0.7)
                .allowsHitTesting(false)
            )
    }
}

struct PageChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.pageBackground.ignoresSafeArea())
            .modifier(PaperGrainOverlay())
            .modifier(PageFrameModifier())
    }
}

extension View {
    /// Applies the full Introibo page look: parchment background (walnut
    /// in dark mode) + paper grain overlay + gold hairline frame.
    /// Use as the top-level modifier on each screen's root container.
    func pageChrome() -> some View {
        modifier(PageChromeModifier())
    }

    /// Just the gold hairline frame, without the paper grain. For dark
    /// headers or overlays that have their own background treatment.
    func pageFrame(inset: CGFloat = 10) -> some View {
        modifier(PageFrameModifier(inset: inset))
    }
}
