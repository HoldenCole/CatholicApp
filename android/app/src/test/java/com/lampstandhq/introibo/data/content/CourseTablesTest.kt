package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.Course
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * The Latin lessons' paradigm tables (a declension, a conjugation): every
 * table carries its rows, and the Spanish and French overlays give each one
 * cells of the same shape, the Latin column unchanged and the rest translated,
 * so ContentStore lays them over (it keeps the English otherwise).
 */
class CourseTablesTest {
    private val json = Json { ignoreUnknownKeys = true }
    private val assets: File = listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
        .map(::File).first { it.isDirectory }

    @Test
    fun everyTableHasRowsAndTranslatedOverlays() {
        val courses = json.decodeFromString<List<Course>>(File(assets, "courses.json").readText())
        val tables = courses.flatMap { c -> c.sections.mapIndexedNotNull { i, s -> if (s.type == "table") Triple(c.slug, i, s) else null } }
        assertTrue("the lessons have tables", tables.isNotEmpty())
        for (lang in listOf("es", "fr")) {
            val ov = json.parseToJsonElement(File(assets, "courses_$lang.json").readText()).jsonObject
            for ((slug, i, s) in tables) {
                val rows = s.rows ?: error("$slug[$i]: a table without rows")
                assertTrue("$slug[$i]: a header and at least one form", rows.size >= 2)
                val sec = ov[slug]!!.jsonObject["sections_$lang"]!!.jsonArray[i].jsonObject
                val t = (sec["rows_$lang"] as? JsonArray ?: error("$slug[$i]: no rows_$lang"))
                    .map { r -> r.jsonArray.map { it.jsonPrimitive.content } }
                assertEquals("$slug[$i] $lang rows", rows.size, t.size)
                rows.zip(t).forEachIndexed { r, (a, b) ->
                    assertEquals("$slug[$i] $lang row $r cells", a.size, b.size)
                    if (r > 0) assertEquals("$slug[$i] $lang row $r Latin", a[1], b[1])
                    assertNotEquals("$slug[$i] $lang row $r translated", a.last(), b.last())
                }
            }
        }
    }
}
