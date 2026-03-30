import SwiftUI

struct MasteryRingView: View {
    let percentage: Double
    @State private var animatedPercentage: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.goldLeaf.opacity(0.15), lineWidth: 8)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0, to: animatedPercentage)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.sanctuaryRed, .goldLeaf]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(animatedPercentage * 100))%")
                    .font(.custom("Palatino", size: 22).weight(.semibold))
                    .foregroundStyle(.white)
                Text("Mastery")
                    .font(.custom("Palatino-Italic", size: 10))
                    .foregroundStyle(.goldLeaf)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedPercentage = percentage
            }
        }
        .onChange(of: percentage) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedPercentage = newValue
            }
        }
    }
}
