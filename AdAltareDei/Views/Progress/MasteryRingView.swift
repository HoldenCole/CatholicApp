import SwiftUI

struct MasteryRingView: View {
    let percentage: Double

    @State private var animatedPercentage: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.goldLeaf.opacity(0.15), lineWidth: 12)
                    .frame(width: 140, height: 140)

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedPercentage)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.sanctuaryRed, .goldLeaf]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: 2) {
                    Text("\(Int(animatedPercentage * 100))%")
                        .font(.englishDisplay)
                        .foregroundStyle(.ink)

                    Text("Mastery")
                        .font(.uiCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Overall Latin Prayer Mastery")
                .font(.uiLabel)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
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

#Preview {
    MasteryRingView(percentage: 0.65)
        .padding()
}
