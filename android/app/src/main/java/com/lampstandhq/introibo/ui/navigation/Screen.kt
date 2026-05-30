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

    // ---- Detail screens with arguments ----
    data object ProperDetail : Screen("proper/{slug}") {
        fun createRoute(slug: String): String = "proper/$slug"
    }

    data object PrayerDetail : Screen("prayer/{slug}") {
        fun createRoute(slug: String): String = "prayer/$slug"
    }
}
