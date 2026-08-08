package dev.vz.ljod.app

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.vectorResource
import dev.vz.ljod.R
import dev.vz.ljod.core.ui.navigation.Screen
import dev.vz.ljod.core.ui.navigation.ScreenHost
import dev.vz.ljod.core.ui.theme.LjodPalettes
import dev.vz.ljod.core.ui.theme.LjodTheme
import dev.vz.ljod.playback.PlaybackController
import dev.vz.ljod.playback.PlaybackService
import dev.vz.ljod.ui.home.HomeScreen
import dev.vz.ljod.ui.library.LibraryScreen
import dev.vz.ljod.ui.settings.SettingsScreen

@Composable
fun LjodShell() {
    val palette = LjodPalettes.Nordic

    LjodTheme(palette = palette) {
        ScreenHost(
            screens = listOf(
                Screen("home", ImageVector.vectorResource(R.drawable.ic_home), "Home") { p -> HomeScreen(p) },
                Screen("library", ImageVector.vectorResource(R.drawable.ic_library), "Library") { p -> LibraryScreen(p) },
                Screen("settings", ImageVector.vectorResource(R.drawable.ic_settings), "Settings") { p -> SettingsScreen(p) },
            ),
            barColor = palette.surfaceHigh,
            selectedColor = palette.accent,
            unselectedColor = palette.onSurfaceVariant,
        )
    }
}
