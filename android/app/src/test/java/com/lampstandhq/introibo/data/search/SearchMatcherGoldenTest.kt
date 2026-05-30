package com.lampstandhq.introibo.data.search

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

// MARK: - Cross-platform SearchMatcher parity + unit tests
//
// Android's ContentStore needs an Android Context to load assets, which a plain
// JVM unit test cannot provide. So `matcherGoldenFixtures` runs the SAME
// search_query_golden.json contract (and the iOS test runs it against real
// content) over a SYNTHETIC index built from documents that stand in for the
// real corpus rows the fixtures target. The matcher algorithm + the fixture
// file are therefore exercised identically; the remaining tests are pure
// algorithm checks that pin cross-platform behaviour (Levenshtein, ordering).

class SearchMatcherGoldenTest {

    // ---- Fixture model ----

    @Serializable
    private data class QueryGolden(val cases: List<Case>) {
        @Serializable
        data class Case(
            val query: String,
            val minExpectedResultCount: Int,
            val mustContainDocId: String? = null,
            val mustMatchType: String? = null,
        )
    }

    private val json = Json { ignoreUnknownKeys = true }

    private fun loadGolden(): QueryGolden {
        val stream = javaClass.classLoader!!.getResourceAsStream("search_query_golden.json")
            ?: error("search_query_golden.json not found on test classpath")
        val text = stream.bufferedReader().use { it.readText() }
        return json.decodeFromString(text)
    }

    // A small synthetic corpus standing in for the real content rows the
    // fixtures target. Folded searchText is produced by the real fold() so the
    // matcher runs over genuinely-folded text.
    private fun doc(
        id: String,
        type: ContentType,
        title: String,
        display: String,
    ): SearchDocument = SearchDocument(
        id = id,
        type = type,
        title = title,
        subtitle = null,
        displayText = display,
        searchText = SearchNormalizer.fold("$title $display"),
        target = DeepLinkTarget(type, id.substringAfter(':').substringBefore('#'), null),
    )

    private fun syntheticIndex(): SearchIndex {
        val index = SearchIndex()
        index.replacePartition(
            "test",
            listOf(
                doc("prayer:ave", ContentType.PRAYER, "Ave María", "Ave María, grátia plena, Dóminus tecum."),
                doc("prayer:kyrie", ContentType.PRAYER, "Kýrie", "Kýrie eléison. Christe eléison."),
                doc("missal:kyrie", ContentType.MISSAL, "Kyrie", "Kyrie eleison, Christe eleison, Kyrie eleison."),
                doc("office:vesperae#part:3", ContentType.OFFICE, "Vespers", "Antiphon ad Magníficat. Magníficat ánima mea Dóminum."),
            ),
        )
        return index
    }

    @Test
    fun matcherGoldenFixtures() {
        val golden = loadGolden()
        assertTrue("golden query fixture set is empty", golden.cases.isNotEmpty())
        val index = syntheticIndex()

        for (c in golden.cases) {
            val results = SearchMatcher.search(c.query, index)
            assertTrue(
                "query \"${c.query}\" returned ${results.size}, expected >= ${c.minExpectedResultCount}",
                results.size >= c.minExpectedResultCount,
            )
            c.mustContainDocId?.let { needle ->
                assertTrue(
                    "query \"${c.query}\" had no result whose id contains \"$needle\"",
                    results.any { it.document.id.contains(needle) },
                )
            }
            c.mustMatchType?.let { typeRaw ->
                assertTrue(
                    "query \"${c.query}\" had no result of type \"$typeRaw\"",
                    results.any { it.document.type.wire == typeRaw },
                )
            }
        }
    }

    @Test
    fun emptyQueryReturnsNoResults() {
        val index = syntheticIndex()
        assertTrue(SearchMatcher.search("", index).isEmpty())
        assertTrue(SearchMatcher.search("   ", index).isEmpty())
    }

    // ---- Pure Levenshtein ----

    @Test
    fun levenshteinDistance() {
        assertEquals(3, Levenshtein.distance("kitten", "sitting"))
        assertEquals(3, Levenshtein.distance("", "abc"))
        assertEquals(0, Levenshtein.distance("abc", "abc"))
        assertEquals(2, Levenshtein.distance("flaw", "lawn"))
    }

    @Test
    fun levenshteinIsWithin() {
        assertTrue(Levenshtein.isWithin("kyrie", "kirie", 1))
        assertTrue(!Levenshtein.isWithin("kyrie", "abcde", 1))
        assertTrue(Levenshtein.isWithin("magnificat", "magnficat", 2))
        assertTrue(!Levenshtein.isWithin("magnificat", "mag", 2))
    }

    // ---- Ordering ----

    @Test
    fun titleHitsRankAboveBodyHits() {
        val bodyOnly = SearchDocument(
            id = "prayer:body", type = ContentType.PRAYER, title = "Some Other Title",
            subtitle = null, displayText = "gloria patri et filio",
            searchText = "gloria patri et filio",
            target = DeepLinkTarget(ContentType.PRAYER, "body", null),
        )
        val titleHit = SearchDocument(
            id = "prayer:title", type = ContentType.PRAYER, title = "Gloria",
            subtitle = null, displayText = "ut supra", searchText = "gloria",
            target = DeepLinkTarget(ContentType.PRAYER, "title", null),
        )
        val index = SearchIndex()
        index.replacePartition("test", listOf(bodyOnly, titleHit)) // body first

        val results = SearchMatcher.search("gloria", index)
        assertEquals("prayer:title", results.first().document.id)
        assertEquals(2, results.size)
    }

    @Test
    fun substringPartialMatch() {
        val d = SearchDocument(
            id = "prayer:m", type = ContentType.PRAYER, title = "Magnificat",
            subtitle = null, displayText = "Magnificat anima mea Dominum",
            searchText = "magnificat anima mea dominum",
            target = DeepLinkTarget(ContentType.PRAYER, "m", null),
        )
        val index = SearchIndex()
        index.replacePartition("test", listOf(d))
        assertEquals(1, SearchMatcher.search("magn", index).size)
    }

    @Test
    fun typeFilter() {
        val prayer = SearchDocument(
            id = "prayer:x", type = ContentType.PRAYER, title = "Ave", subtitle = null,
            displayText = "Ave Maria", searchText = "ave maria",
            target = DeepLinkTarget(ContentType.PRAYER, "x", null),
        )
        val saint = SearchDocument(
            id = "saint:y", type = ContentType.SAINT, title = "Ave", subtitle = null,
            displayText = "Ave Maria", searchText = "ave maria",
            target = DeepLinkTarget(ContentType.SAINT, "y", null),
        )
        val index = SearchIndex()
        index.replacePartition("test", listOf(prayer, saint))
        val onlyPrayers = SearchMatcher.search("ave", index, ContentType.PRAYER)
        assertEquals(1, onlyPrayers.size)
        assertEquals(ContentType.PRAYER, onlyPrayers.first().document.type)
    }
}
