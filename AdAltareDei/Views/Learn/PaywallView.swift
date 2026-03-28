import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 20)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.goldLeaf.opacity(0.12))
                            .frame(width: 100, height: 100)

                        Image(systemName: "cross.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.goldLeaf)
                    }

                    // Title
                    VStack(spacing: 8) {
                        Text("Ad Altare Dei")
                            .font(.latinDisplay)
                            .foregroundStyle(.ink)

                        Text("Premium")
                            .font(.latinTitle)
                            .foregroundStyle(.goldLeaf)
                            .tracking(2)
                            .textCase(.uppercase)
                    }

                    // Features list
                    VStack(alignment: .leading, spacing: 16) {
                        premiumFeature(
                            icon: "brain.head.profile",
                            title: "AI Latin Tutor",
                            description: "Personalized courses that adapt to your skill level"
                        )
                        premiumFeature(
                            icon: "text.book.closed.fill",
                            title: "Full Course Library",
                            description: "Grammar, vocabulary, prayer breakdowns, and Latin reading"
                        )
                        premiumFeature(
                            icon: "waveform",
                            title: "Pronunciation Coach",
                            description: "AI-powered feedback on your Latin pronunciation"
                        )
                        premiumFeature(
                            icon: "person.2.fill",
                            title: "Mass Server Training",
                            description: "Complete altar server response course"
                        )
                        premiumFeature(
                            icon: "book.pages",
                            title: "Vulgate Reading",
                            description: "Guided Latin scripture reading with comprehension aids"
                        )
                    }
                    .padding(.horizontal, 8)

                    // Price cards
                    VStack(spacing: 12) {
                        pricingCard(
                            title: "Annual",
                            price: "$29.99/year",
                            subtitle: "Best value — $2.50/month",
                            isHighlighted: true
                        )

                        pricingCard(
                            title: "Monthly",
                            price: "$4.99/month",
                            subtitle: "Cancel anytime",
                            isHighlighted: false
                        )
                    }

                    // Restore
                    Button {
                        // StoreKit restore purchases
                    } label: {
                        Text("Restore Purchases")
                            .font(.uiLabel)
                            .foregroundStyle(.secondary)
                    }

                    Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                        .font(.uiCaption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(Color.parchment)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func premiumFeature(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.goldLeaf)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.uiLabel)
                    .foregroundStyle(.ink)

                Text(description)
                    .font(.uiCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func pricingCard(title: String, price: String, subtitle: String, isHighlighted: Bool) -> some View {
        Button {
            // StoreKit purchase flow
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.uiLabelLarge)
                        .foregroundStyle(isHighlighted ? .white : .ink)

                    Text(subtitle)
                        .font(.uiCaption)
                        .foregroundStyle(isHighlighted ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                Text(price)
                    .font(.englishTitle)
                    .foregroundStyle(isHighlighted ? .white : .sanctuaryRed)
            }
            .padding()
            .background(isHighlighted ? Color.sanctuaryRed : Color.warmWhite)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.sanctuaryRed, lineWidth: 2)
                }
            }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(AppSettings())
}
