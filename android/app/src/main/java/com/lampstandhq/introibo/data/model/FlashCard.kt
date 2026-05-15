package com.lampstandhq.introibo.data.model

/**
 * FlashCard is a type alias for [Course.Section.Card].
 * The iOS app uses FlashCard as a SwiftUI view; on Android the data
 * model is already defined as [Course.Section.Card]. This alias is
 * provided for convenience when referencing flashcard data.
 */
typealias FlashCard = Course.Section.Card
