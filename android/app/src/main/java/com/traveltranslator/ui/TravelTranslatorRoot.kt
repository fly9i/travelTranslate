package com.traveltranslator.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.traveltranslator.ui.conversation.ConversationScreen
import com.traveltranslator.ui.display.FullScreenDisplay
import com.traveltranslator.ui.favorites.FavoritesScreen
import com.traveltranslator.ui.home.HomeScreen
import com.traveltranslator.ui.scene.SceneScreen
import com.traveltranslator.ui.settings.SettingsScreen

/** 导航根路由。 */
@Composable
fun TravelTranslatorRoot() {
    val navController = rememberNavController()
    val currentEntry by navController.currentBackStackEntryAsState()
    val currentRoute = currentEntry?.destination?.route

    val showBottomBar = currentRoute in listOf(
        Routes.HOME, Routes.SCENES, Routes.FAVORITES, Routes.SETTINGS,
    )

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                NavigationBar {
                    bottomItems.forEach { item ->
                        val selected = currentEntry?.destination?.hierarchy?.any {
                            it.route == item.route
                        } == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(item.route) {
                                    popUpTo(Routes.HOME) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(item.icon, contentDescription = item.label) },
                            label = { Text(item.label) },
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Routes.HOME,
            modifier = Modifier.padding(innerPadding),
        ) {
            composable(Routes.HOME) {
                HomeScreen(
                    onSceneClick = { category ->
                        navController.navigate("${Routes.SCENE_DETAIL}/$category")
                    },
                    onDisplayText = { source, target ->
                        navController.navigate("${Routes.DISPLAY}/${source}/${target}")
                    },
                    onOpenConversation = { navController.navigate(Routes.CONVERSATION) },
                )
            }
            composable(Routes.SCENES) {
                SceneScreen(
                    onSceneClick = { category ->
                        navController.navigate("${Routes.SCENE_DETAIL}/$category")
                    }
                )
            }
            composable("${Routes.SCENE_DETAIL}/{category}") { entry ->
                val category = entry.arguments?.getString("category") ?: "restaurant"
                com.traveltranslator.ui.scene.SceneDetailScreen(
                    category = category,
                    onBack = { navController.popBackStack() },
                    onDisplay = { source, target ->
                        navController.navigate("${Routes.DISPLAY}/${source}/${target}")
                    }
                )
            }
            composable(Routes.FAVORITES) { FavoritesScreen() }
            composable(Routes.SETTINGS) { SettingsScreen() }
            composable(Routes.CONVERSATION) {
                ConversationScreen(onBack = { navController.popBackStack() })
            }
            composable("${Routes.DISPLAY}/{source}/{target}") { entry ->
                val source = entry.arguments?.getString("source").orEmpty()
                val target = entry.arguments?.getString("target").orEmpty()
                FullScreenDisplay(
                    sourceText = source,
                    targetText = target,
                    onClose = { navController.popBackStack() }
                )
            }
        }
    }
}

/** 路由常量。 */
object Routes {
    const val HOME = "home"
    const val SCENES = "scenes"
    const val SCENE_DETAIL = "scene_detail"
    const val FAVORITES = "favorites"
    const val SETTINGS = "settings"
    const val CONVERSATION = "conversation"
    const val DISPLAY = "display"
}

private data class BottomItem(
    val route: String,
    val label: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
)

private val bottomItems = listOf(
    BottomItem(Routes.HOME, "翻译", Icons.Filled.Home),
    BottomItem(Routes.SCENES, "场景", Icons.Filled.Star),
    BottomItem(Routes.FAVORITES, "收藏", Icons.Filled.Favorite),
    BottomItem(Routes.SETTINGS, "设置", Icons.Filled.Settings),
)
