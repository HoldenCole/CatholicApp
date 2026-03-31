import Foundation

/// A saint whose practices and rule of life can be followed.
struct SaintProfile: Identifiable, Codable {
    var id: String { slug }
    let slug: String
    let name: String
    let latinName: String
    let title: String              // e.g. "Doctor of the Church"
    let feastDay: String           // e.g. "January 28"
    let era: String                // e.g. "1225-1274"
    let charism: String            // One-line summary of their spirituality
    let biography: String          // Brief bio
    let dailyPractices: [SaintPractice]
    let penances: [SaintPractice]?
    let quotes: [SaintQuote]
    let relatedPrayers: [String]?  // Prayer slugs
}

struct SaintPractice: Identifiable, Codable {
    var id: String { slug }
    let slug: String
    let title: String
    let description: String
    let timeOfDay: String?         // "morning", "midday", "evening", "anytime"
    let isRequired: Bool           // Required vs recommended
}

struct SaintQuote: Codable {
    let quote: String
    let source: String?
}
