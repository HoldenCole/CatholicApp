package com.lampstandhq.introibo.ui.navigation

import androidx.navigation.NavController
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.search.ContentType
import com.lampstandhq.introibo.data.search.DeepLinkTarget

/**
 * DeepLinkRouter (Phase 3: deep-link navigation) — Android mirror of iOS
 * Introibo/Data/Search/DeepLinkRouter.swift.
 *
 * Resolves a [DeepLinkTarget] (carried by every SearchDocument, and — in the
 * future — by a contextual link or a Home-Screen widget) into a concrete
 * NavHost route, then navigates to it. The destination composable reads the
 * `pos` arg (= [DeepLinkTarget.position]) and scrolls to the keyed item.
 *
 * Single entry point: [open]. Intentionally surface-agnostic — a future
 * widget/URL entry can call the same [open] once the NavController exists.
 */
object DeepLinkRouter {

    /**
     * The one public entry point. Resolves [target] against [ContentStore] into
     * a route and navigates. No-op if the target cannot be resolved (e.g. an
     * Ordinary missal section that has no standalone detail screen).
     */
    fun open(navController: NavController, target: DeepLinkTarget) {
        val route = resolve(target) ?: return
        navController.navigate(route)
    }

    /**
     * Maps a [DeepLinkTarget] to its NavHost route string, or null if the
     * content is missing / has no detail destination. Pure; reused for tests.
     * Mirrors iOS DeepLinkRouter.resolve.
     */
    fun resolve(target: DeepLinkTarget): String? = when (target.type) {
        ContentType.PRAYER -> {
            ContentStore.prayer(target.id)?.let {
                Screen.PrayerDetail.createRoute(target.id, target.position)
            }
        }

        ContentType.MISSAL -> {
            // Proper element/feast docs and Ordinary-section docs both carry
            // MISSAL. Proper slugs are the formulary slugs; the position is the
            // element name or "feast". Ordinary sections have no detail screen.
            ContentStore.anyProper(target.id)?.let {
                Screen.ProperDetail.createRoute(target.id, target.position)
            }
        }

        ContentType.OFFICE -> {
            ContentStore.hour(target.id)?.let {
                Screen.HourDetail.createRoute(target.id, target.position)
            }
        }

        ContentType.REFERENCE, ContentType.CALENDAR -> {
            ContentStore.referenceEntry(target.id)?.let {
                Screen.ReferenceDetail.createRoute(target.id)
            }
        }

        ContentType.SAINT -> {
            ContentStore.saint(target.id)?.let {
                Screen.SaintDetail.createRoute(target.id, target.position)
            }
        }
    }
}
