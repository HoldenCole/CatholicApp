import SwiftUI

extension Font {
    // MARK: - Display / Latin Text (Palatino)
    static let latinDisplay = Font.custom("Palatino", size: 28).weight(.semibold)
    static let latinTitle = Font.custom("Palatino", size: 22).weight(.medium)
    static let latinBody = Font.custom("Palatino", size: 18)
    static let latinCaption = Font.custom("Palatino", size: 14)

    // MARK: - Phonetic Text (Palatino Italic)
    static let phoneticBody = Font.custom("Palatino-Italic", size: 18)
    static let phoneticLarge = Font.custom("Palatino-Italic", size: 20)

    // MARK: - Body / English (Georgia)
    static let englishDisplay = Font.custom("Georgia", size: 28).weight(.semibold)
    static let englishTitle = Font.custom("Georgia", size: 22).weight(.medium)
    static let englishBody = Font.custom("Georgia", size: 18)
    static let englishCaption = Font.custom("Georgia", size: 14)

    // MARK: - UI Labels (SF Pro — clean, serious, native iOS)
    static let uiLabelLarge = Font.system(size: 17, weight: .semibold, design: .default)
    static let uiLabel = Font.system(size: 15, weight: .medium, design: .default)
    static let uiLabelSmall = Font.system(size: 13, weight: .medium, design: .default)
    static let uiCaption = Font.system(size: 11, weight: .regular, design: .default)

    // MARK: - Tab Bar
    static let tabLabel = Font.system(size: 10, weight: .medium, design: .default)

    // MARK: - Section Headers
    static let sectionHeader = Font.system(size: 13, weight: .semibold, design: .default)
}
