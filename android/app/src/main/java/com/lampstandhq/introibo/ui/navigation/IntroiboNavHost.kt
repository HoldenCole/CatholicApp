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
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.lampstandhq.introibo.ui.learn.LearnScreen
import com.lampstandhq.introibo.ui.missal.MissalScreen
import com.lampstandhq.introibo.ui.prayers.PrayersScreen
import com.lampstandhq.introibo.ui.reference.ReferenceScreen
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
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
                TodayScreen()
            }
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
        }
    }
}
