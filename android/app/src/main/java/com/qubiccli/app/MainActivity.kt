package com.qubiccli.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Apps
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.qubiccli.app.data.Catalog
import com.qubiccli.app.data.History
import com.qubiccli.app.data.Settings
import com.qubiccli.app.ui.QubicColors
import com.qubiccli.app.ui.QubicTheme
import com.qubiccli.app.ui.screens.CategoriesScreen
import com.qubiccli.app.ui.screens.CommandDetailScreen
import com.qubiccli.app.ui.screens.CommandListScreen
import com.qubiccli.app.ui.screens.FavoritesScreen
import com.qubiccli.app.ui.screens.HistoryScreen
import com.qubiccli.app.ui.screens.SettingsScreen

/** Simple global state holder. */
class AppState(
    val settings: Settings,
    val catalog: Catalog,
    val history: History,
)

val LocalAppState = staticCompositionLocalOf<AppState> {
    error("AppState not provided")
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val appState = AppState(
            settings = Settings(applicationContext),
            catalog = Catalog(applicationContext),
            history = History(applicationContext),
        )
        setContent {
            QubicTheme {
                CompositionLocalProvider(LocalAppState provides appState) {
                    RootScaffold()
                }
            }
        }
    }
}

private sealed class Tab(val route: String, val label: String, val icon: ImageVector) {
    data object Browse    : Tab("browse",    "Browse",    Icons.Outlined.Apps)
    data object Favorites : Tab("favorites", "Favorites", Icons.Outlined.Star)
    data object History   : Tab("history",   "History",   Icons.Outlined.History)
    data object Settings  : Tab("settings",  "Settings",  Icons.Outlined.Settings)
}

private val tabs = listOf(Tab.Browse, Tab.Favorites, Tab.History, Tab.Settings)

@Composable
private fun RootScaffold() {
    val nav = rememberNavController()
    val backStack by nav.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route

    Scaffold(
        containerColor = QubicColors.Base,
        bottomBar = {
            NavigationBar(containerColor = QubicColors.Base) {
                tabs.forEach { tab ->
                    val selected = currentRoute == tab.route || currentRoute?.startsWith(tab.route + "/") == true
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            nav.navigate(tab.route) {
                                popUpTo(nav.graph.startDestinationId) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = QubicColors.Accent,
                            selectedTextColor = QubicColors.Accent,
                            unselectedIconColor = QubicColors.TextDim,
                            unselectedTextColor = QubicColors.TextDim,
                            indicatorColor = QubicColors.SurfaceHigh,
                        ),
                    )
                }
            }
        },
    ) { inner ->
        Box(Modifier.fillMaxSize().padding(inner)) {
            NavHost(nav, startDestination = Tab.Browse.route) {
                composable(Tab.Browse.route) { CategoriesScreen(nav) }
                composable(
                    "category/{name}",
                    arguments = listOf(navArgument("name") { type = NavType.StringType }),
                ) { entry ->
                    val name = entry.arguments?.getString("name").orEmpty()
                    CommandListScreen(nav, name)
                }
                composable(
                    "command/{flag}",
                    arguments = listOf(navArgument("flag") { type = NavType.StringType }),
                ) { entry ->
                    val flag = entry.arguments?.getString("flag").orEmpty()
                    CommandDetailScreen(nav, flag)
                }

                composable(Tab.Favorites.route) { FavoritesScreen(nav) }
                composable(Tab.History.route)   { HistoryScreen() }
                composable(Tab.Settings.route)  { SettingsScreen() }
            }
        }
    }
}
