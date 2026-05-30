package com.lampstandhq.introibo.ui.navigation

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.ui.confession.ConfessionScreen
import com.lampstandhq.introibo.ui.learn.LearnScreen
import com.lampstandhq.introibo.ui.missal.MissalScreen
import com.lampstandhq.introibo.ui.missal.ProperScreen
import com.lampstandhq.introibo.ui.office.HourSheet
import com.lampstandhq.introibo.ui.office.OfficeScreen
import com.lampstandhq.introibo.ui.prayers.PrayerDetailSheet
import com.lampstandhq.introibo.ui.prayers.PrayersScreen
import com.lampstandhq.introibo.ui.reference.ReferenceDetailScreen
import com.lampstandhq.introibo.ui.reference.ReferenceScreen
import com.lampstandhq.introibo.ui.rosary.RosaryScreen
import com.lampstandhq.introibo.ui.saints.SaintDetailScreen
import com.lampstandhq.introibo.ui.saints.SaintsScreen
import com.lampstandhq.introibo.ui.search.SearchScreen
import com.lampstandhq.introibo.ui.stations.StationsScreen
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.today.SettingsScreen
import com.lampstandhq.introibo.ui.today.TodayScreen

// ---------------------------------------------------------------------------
// Tab descriptor
// ---------------------------------------------------------------------------

private data class TabItem(
    val label: String,
    val icon: ImageVector,
    val screen: Screen,
)

private val tabs = listOf(
    TabItem("Hodie",  Icons.Filled.WbSunny,    Screen.Today),
    TabItem("Missa",  Icons.Filled.Book,        Screen.Missal),
    TabItem("Oratio", Icons.Filled.AutoStories, Screen.Prayers),
    TabItem("Schola", Icons.Filled.School,      Screen.Learn),
    TabItem("Liber",  Icons.Filled.MenuBook,    Screen.Reference),
)

// ---------------------------------------------------------------------------
// Main nav host
// ---------------------------------------------------------------------------

/**
 * Root composable that hosts the 5-tab BottomNavigation and per-tab NavHosts.
 * Mirrors the iOS ContentView TabView.
 */
@Composable
fun IntroiboNavHost() {
    val colors = IntroiboTheme.colors
    var selectedIndex by rememberSaveable { mutableIntStateOf(0) }

    // One NavController per tab to preserve back stacks independently.
    // For the initial port we use a single NavHost and swap content;
    // each tab's screen manages its own internal navigation.
    val navController = rememberNavController()

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = colors.pageBackground,
                tonalElevation = 0.dp,
            ) {
                tabs.forEachIndexed { index, tab ->
                    NavigationBarItem(
                        selected = selectedIndex == index,
                        onClick = {
                            if (selectedIndex != index) {
                                selectedIndex = index
                                navController.navigate(tab.screen.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        },
                        icon = {
                            Icon(
                                imageVector = tab.icon,
                                contentDescription = tab.label,
                            )
                        },
                        label = {
                            Text(
                                text = tab.label,
                                fontFamily = FontFamily.Serif,
                                fontStyle = FontStyle.Italic,
                                fontSize = 11.sp,
                            )
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = colors.sanctuaryRed,
                            selectedTextColor = colors.sanctuaryRed,
                            unselectedIconColor = colors.tertiaryText,
                            unselectedTextColor = colors.tertiaryText,
                            indicatorColor = colors.sanctuaryRed.copy(alpha = 0.08f),
                        ),
                    )
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Today.route,
            modifier = Modifier.padding(innerPadding),
            enterTransition = { EnterTransition.None },
            exitTransition = { ExitTransition.None },
        ) {
            composable(Screen.Today.route) {
                TodayScreen(
                    onNavigateSettings = { navController.navigate(Screen.Settings.route) },
                    onNavigateOffice = { navController.navigate(Screen.Office.route) },
                    onNavigateStations = { navController.navigate(Screen.Stations.route) },
                    onNavigateConfession = { navController.navigate(Screen.Confession.route) },
                    onNavigateRosary = { navController.navigate(Screen.Rosary.route) },
                    onNavigateSaints = { navController.navigate(Screen.Saints.route) },
                    onNavigateSearch = { navController.navigate(Screen.Search.route) },
                )
            }
            composable(Screen.Settings.route) { SettingsScreen(onDismiss = { navController.popBackStack() }) }
            composable(Screen.Search.route) {
                SearchScreen(
                    onDismiss = { navController.popBackStack() },
                    onSelectTarget = { target ->
                        // Close search, then deep-link to the resolved destination.
                        navController.popBackStack()
                        DeepLinkRouter.open(navController, target)
                    },
                )
            }
            composable(Screen.Office.route) { OfficeScreen(onBack = { navController.popBackStack() }) }
            composable(Screen.Stations.route) { StationsScreen(onBack = { navController.popBackStack() }) }
            composable(Screen.Confession.route) { ConfessionScreen(onBack = { navController.popBackStack() }) }
            composable(Screen.Rosary.route) { RosaryScreen(onBack = { navController.popBackStack() }) }
            composable(Screen.Saints.route) { SaintsScreen(onBack = { navController.popBackStack() }) }
            composable(Screen.Missal.route) {
                MissalScreen()
            }
            composable(Screen.Prayers.route) {
                PrayersScreen()
            }
            composable(Screen.Learn.route) {
                LearnScreen()
            }
            composable(Screen.Reference.route) {
                ReferenceScreen()
            }

            // ---- Deep-link detail destinations ----
            // Each resolves its slug (+ optional `pos` anchor) against
            // ContentStore and renders the existing detail composable. Mirrors
            // the iOS DeepLinkRouter → .sheet(item:) flow.

            composable(
                route = Screen.ProperDetail.route,
                arguments = listOf(
                    navArgument("slug") { type = NavType.StringType },
                    navArgument("pos") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entry ->
                val slug = entry.arguments?.getString("slug") ?: return@composable
                val pos = entry.arguments?.getString("pos")
                ContentStore.anyProper(slug)?.let { proper ->
                    ProperScreen(
                        proper = proper,
                        onDismiss = { navController.popBackStack() },
                        scrollToAnchor = pos,
                    )
                }
            }

            composable(
                route = Screen.PrayerDetail.route,
                arguments = listOf(
                    navArgument("slug") { type = NavType.StringType },
                    navArgument("pos") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entry ->
                val slug = entry.arguments?.getString("slug") ?: return@composable
                ContentStore.prayer(slug)?.let { prayer ->
                    PrayerDetailSheet(
                        prayer = prayer,
                        onDismiss = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Screen.SaintDetail.route,
                arguments = listOf(
                    navArgument("slug") { type = NavType.StringType },
                    navArgument("pos") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entry ->
                val slug = entry.arguments?.getString("slug") ?: return@composable
                val pos = entry.arguments?.getString("pos")
                ContentStore.saint(slug)?.let { saint ->
                    SaintDetailScreen(
                        saint = saint,
                        onDismiss = { navController.popBackStack() },
                        scrollToAnchor = pos,
                    )
                }
            }

            composable(
                route = Screen.ReferenceDetail.route,
                arguments = listOf(
                    navArgument("slug") { type = NavType.StringType },
                ),
            ) { entry ->
                val slug = entry.arguments?.getString("slug") ?: return@composable
                ContentStore.referenceEntry(slug)?.let { entryModel ->
                    ReferenceDetailScreen(
                        entry = entryModel,
                        onDismiss = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Screen.HourDetail.route,
                arguments = listOf(
                    navArgument("slug") { type = NavType.StringType },
                    navArgument("pos") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entry ->
                val slug = entry.arguments?.getString("slug") ?: return@composable
                val pos = entry.arguments?.getString("pos")
                // Use the raw template hour (store.hours) — the same corpus the
                // office search extractor indexes — so "part:<index>" aligns.
                ContentStore.hour(slug)?.let { hour ->
                    HourSheet(
                        hour = hour,
                        onDismiss = { navController.popBackStack() },
                        scrollToPartIndex = pos?.removePrefix("part:")?.toIntOrNull(),
                    )
                }
            }
        }
    }
}
