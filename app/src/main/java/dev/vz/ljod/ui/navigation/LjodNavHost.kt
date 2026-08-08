package dev.vz.ljod.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import dev.vz.ljod.ui.screens.home.HomeScreen
import dev.vz.ljod.ui.screens.library.LibraryScreen
import dev.vz.ljod.ui.screens.settings.SettingsScreen

enum class Screen { Home, Library, Settings }

@Composable
fun LjodAppContent() {
    var currentScreen by remember { mutableStateOf(Screen.Home) }

    LjodScaffold(
        currentScreen = currentScreen,
        onNavigate = { currentScreen = it }
    ) { padding ->
        when (currentScreen) {
            Screen.Home -> HomeScreen(padding)
            Screen.Library -> LibraryScreen(padding)
            Screen.Settings -> SettingsScreen(padding)
        }
    }
}
