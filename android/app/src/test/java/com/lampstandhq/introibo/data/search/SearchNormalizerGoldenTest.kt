package com.lampstandhq.introibo.data.search

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

// MARK: - Cross-platform fold() parity test
//
// Runs SearchNormalizer.fold against every {input, expectedFolded} pair in
// search_golden.json and asserts equality. The SAME fixture file is run by the
// iOS test (SearchNormalizerGoldenTests.swift). If both pass, iOS and Android
// fold() produce identical output on the fixture set — the parity guarantee.
//
// The fixture lives at android/app/src/test/resources/search_golden.json
// (mirror of Introibo/Resources/search_golden.json — keep them identical).

class SearchNormalizerGoldenTest {

    @Serializable
    private data class Golden(val pairs: List<Pair>) {
        @Serializable
        data class Pair(val input: String, val expectedFolded: String)
    }

    private val json = Json { ignoreUnknownKeys = true }

    private fun loadGolden(): Golden {
        val stream = javaClass.classLoader!!.getResourceAsStream("search_golden.json")
            ?: error("search_golden.json not found on test classpath")
        val text = stream.bufferedReader().use { it.readText() }
        return json.decodeFromString(text)
    }

    @Test
    fun foldMatchesGoldenFixtures() {
        val golden = loadGolden()
        assertTrue("golden fixture set is empty", golden.pairs.isNotEmpty())
        for (pair in golden.pairs) {
            val folded = SearchNormalizer.fold(pair.input)
            assertEquals(
                "fold(\"${pair.input}\")",
                pair.expectedFolded,
                folded,
            )
        }
    }

    @Test
    fun foldIsIdempotent() {
        val golden = loadGolden()
        for (pair in golden.pairs) {
            val once = SearchNormalizer.fold(pair.input)
            val twice = SearchNormalizer.fold(once)
            assertEquals("fold is not idempotent for \"${pair.input}\"", once, twice)
        }
    }
}
