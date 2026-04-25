import SwiftUI

struct SplashView: View {
    @Binding var isFinished: Bool
    @State private var opacity: Double = 0
    @State private var crossScale: Double = 0.8

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.walnut, Color.walnutHi, Color.walnut],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                monstranceIcon
                    .scaleEffect(crossScale)

                VStack(spacing: 8) {
                    Text("Introíbo")
                        .font(.system(size: 42, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(Color.ivory)

                    Text("Ad altáre Dei")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color.goldLeaf)
                        .tracking(3)
                        .textCase(.uppercase)
                }

                Spacer()

                Text("A prayer companion for traditional Catholics")
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 48)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                opacity = 1
                crossScale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    isFinished = true
                }
            }
        }
    }

    private var monstranceIcon: some View {
        ZStack {
            Circle()
                .stroke(Color.goldLeaf.opacity(0.3), lineWidth: 1)
                .frame(width: 80, height: 80)
            Circle()
                .stroke(Color.goldLeaf.opacity(0.2), lineWidth: 0.5)
                .frame(width: 100, height: 100)

            ForEach(0..<12, id: \.self) { i in
                Rectangle()
                    .fill(Color.goldLeaf.opacity(0.25))
                    .frame(width: 0.5, height: 18)
                    .offset(y: -56)
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            Circle()
                .fill(Color.goldLeaf.opacity(0.15))
                .frame(width: 50, height: 50)
            Circle()
                .fill(Color.goldLeaf.opacity(0.5))
                .frame(width: 20, height: 20)

            Rectangle()
                .fill(Color.ivory.opacity(0.4))
                .frame(width: 0.8, height: 10)
            Rectangle()
                .fill(Color.ivory.opacity(0.4))
                .frame(width: 10, height: 0.8)

            Rectangle()
                .fill(Color.goldLeaf.opacity(0.4))
                .frame(width: 3, height: 22)
                .offset(y: 48)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.goldLeaf.opacity(0.3))
                .frame(width: 16, height: 3)
                .offset(y: 62)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.goldLeaf.opacity(0.2))
                .frame(width: 26, height: 3)
                .offset(y: 67)

            Rectangle()
                .fill(Color.goldLeaf.opacity(0.4))
                .frame(width: 2, height: 14)
                .offset(y: -48)
            Rectangle()
                .fill(Color.goldLeaf.opacity(0.4))
                .frame(width: 10, height: 2)
                .offset(y: -43)
        }
        .frame(width: 140, height: 160)
    }
}
