package com.lampstandhq.introibo.ui.navigation

/**
 * Sealed class representing all navigable destinations in the app.
 * Each object carries a unique [route] string used by the Compose NavHost.
 */
sealed class Screen(val route: String) {

    // ---- Bottom-bar tabs ----
    data object Today     : Screen("today")
    data object Missal    : Screen("missal")
    data object Prayers   : Screen("prayers")
    data object Learn     : Screen("learn")
    data object Reference : Screen("reference")

    // ---- Devotion sub-screens ----
    data object Office     : Screen("office")
    data object Stations   : Screen("stations")
    data object Confession : Screen("confession")
    data object Rosary     : Screen("rosary")
    data object Saints     : Screen("saints")

    // ---- Utility ----
    data object Onboarding : Screen("onboarding")
    data object Tutorial   : Screen("tutorial")
    data object Settings   : Screen("settings")
    data object Search     : Screen("search")
    data object Calendar   : Screen("calendar")

    // ---- Detail screens with arguments (deep-link targets) ----
    //
    // Each carries the content slug plus an optional `pos` query arg = the
    // DeepLinkTarget.position anchor (proper element name, "part:<i>",
    // "section:<i>"/"prayer:<i>", or absent). The detail composable scrolls to
    // the keyed item when `pos` is present. Mirrors the iOS DeepLinkRouter /
    // initialAnchor contract.

    data object ProperDetail : Screen("proper/{slug}?pos={pos}") {
        fun createRoute(slug: String, pos: String? = null): String =
            "proper/$slug" + (pos?.let { "?pos=$it" } ?: "")
    }

    data object PrayerDetail : Screen("prayer/{slug}?pos={pos}") {
        // Prayers anchor to the whole document today; `pos` is accepted but unused.
        fun createRoute(slug: String, pos: String? = null): String =
            "prayer/$slug" + (pos?.let { "?pos=$it" } ?: "")
    }

    data object SaintDetail : Screen("saint/{slug}?pos={pos}") {
        fun createRoute(slug: String, pos: String? = null): String =
            "saint/$slug" + (pos?.let { "?pos=$it" } ?: "")
    }

    data object ReferenceDetail : Screen("reference/{slug}") {
        fun createRoute(slug: String): String = "reference/$slug"
    }

    data object HourDetail : Screen("office/{slug}?pos={pos}") {
        fun createRoute(slug: String, pos: String? = null): String =
            "office/$slug" + (pos?.let { "?pos=$it" } ?: "")
    }
}
