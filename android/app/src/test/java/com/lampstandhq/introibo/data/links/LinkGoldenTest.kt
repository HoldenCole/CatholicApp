package com.lampstandhq.introibo.data.links

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// MARK: - Cross-platform link parser parity tests
//
// Runs LinkTarget.parse and LinkMarkup.runs against every case in
// link_golden.json and asserts correctness. The SAME fixture file is run by
// the iOS test (LinkGoldenTests.swift). If both pass, iOS and Android link
// parsing produces identical output — the parity guarantee.
//
// The fixture lives at android/app/src/test/resources/link_golden.json
// (mirror of Introibo/Resources/link_golden.json — keep them identical).

class LinkGoldenTest {

    // -- Decodable fixture shapes --

    @Serializable
    private data class Golden(
        val parse: List<ParseCase>,
        val runs: List<RunsCase>,
    )

    @Serializable
    private data class ParseCase(
        val input: String,
        val type: String? = null,
        val id: String? = null,
        val position: String? = null,
    )

    @Serializable
    private data class RunsCase(
        val input: String,
        val runs: List<RunExpected>,
    )

    @Serializable
    private data class RunExpected(
        val kind: String,
        val text: String,
        val target: String? = null,
    )

    private val json = Json { ignoreUnknownKeys = true }

    private fun loadGolden(): Golden {
        val stream = javaClass.classLoader!!.getResourceAsStream("link_golden.json")
            ?: error("link_golden.json not found on test classpath")
        val text = stream.bufferedReader().use { it.readText() }
        return json.decodeFromString(text)
    }

    // -- LinkTarget.parse tests --

    @Test
    fun parseMatchesGoldenFixtures() {
        val golden = loadGolden()
        assertTrue("parse fixture set is empty", golden.parse.isNotEmpty())

        for (c in golden.parse) {
            val result = LinkTarget.parse(c.input)

            if (c.type != null && c.id != null) {
                // Expect a successful parse
                assertNotNull("parse(\"${c.input}\") returned null, expected success", result)
                result!!
                assertEquals(
                    "parse(\"${c.input}\").type",
                    c.type,
                    result.type.wire,
                )
                assertEquals(
                    "parse(\"${c.input}\").id",
                    c.id,
                    result.id,
                )
                assertEquals(
                    "parse(\"${c.input}\").position",
                    c.position,
                    result.position,
                )
            } else {
                // Expect parse failure
                assertNull(
                    "parse(\"${c.input}\") should return null but got $result",
                    result,
                )
            }
        }
    }

    // -- LinkMarkup.runs tests --

    @Test
    fun runsMatchGoldenFixtures() {
        val golden = loadGolden()
        assertTrue("runs fixture set is empty", golden.runs.isNotEmpty())

        for (c in golden.runs) {
            val actual = LinkMarkup.runs(c.input)
            assertEquals(
                "runs(\"${c.input}\") run count",
                c.runs.size,
                actual.size,
            )

            for ((i, expected) in c.runs.withIndex()) {
                if (i >= actual.size) continue

                when (val run = actual[i]) {
                    is TextRun.Text -> {
                        assertEquals(
                            "run[$i] of \"${c.input}\": got Text, expected ${expected.kind}",
                            "text",
                            expected.kind,
                        )
                        assertEquals(
                            "run[$i] of \"${c.input}\": text",
                            expected.text,
                            run.text,
                        )
                    }
                    is TextRun.Link -> {
                        assertEquals(
                            "run[$i] of \"${c.input}\": got Link, expected ${expected.kind}",
                            "link",
                            expected.kind,
                        )
                        assertEquals(
                            "run[$i] of \"${c.input}\": link text",
                            expected.text,
                            run.text,
                        )
                        // Reconstruct the target string for comparison
                        assertNotNull(
                            "run[$i] of \"${c.input}\": link run missing target in fixture",
                            expected.target,
                        )
                        var targetStr = "${run.target.type.wire}:${run.target.id}"
                        if (run.target.position != null) {
                            targetStr += "#${run.target.position}"
                        }
                        assertEquals(
                            "run[$i] of \"${c.input}\": target",
                            expected.target,
                            targetStr,
                        )
                    }
                }
            }
        }
    }
}
