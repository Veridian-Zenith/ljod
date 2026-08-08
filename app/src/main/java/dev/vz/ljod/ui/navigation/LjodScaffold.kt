package dev.vz.ljod.ui.navigation

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.LibraryMusic
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import dev.vz.ljod.ui.theme.Amber
import dev.vz.ljod.ui.theme.VoidSurface
import dev.vz.ljod.ui.theme.VoidSurfaceHigh
import dev.vz.ljod.ui.theme.TextMuted

private data class NavItem(val screen: Screen, val icon: ImageVector, val label: String)

private val navItems = listOf(
    NavItem(Screen.Home, Icons.Rounded.Home, "Home"),
    NavItem(Screen.Library, Icons.Rounded.LibraryMusic, "Library"),
    NavItem(Screen.Settings, Icons.Rounded.Settings, "Settings"),
)

@Composable
fun LjodScaffold(
    currentScreen: Screen,
    onNavigate: (Screen) -> Unit,
    content: @Composable (PaddingValues) -> Unit
) {
    Scaffold(
        containerColor = VoidSurface,
        bottomBar = {
            NavigationBar(containerColor = VoidSurfaceHigh) {
                navItems.forEach { item ->
                    NavigationBarItem(
                        selected = currentScreen == item.screen,
                        onClick = { onNavigate(item.screen) },
                        icon = { Icon(item.icon, contentDescription = item.label) },
                        label = { Text(item.label) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Amber,
                            selectedTextColor = Amber,
                            unselectedIconColor = TextMuted,
                            unselectedTextColor = TextMuted,
                            indicatorColor = VoidSurfaceHigh,
                        )
                    )
                }
            }
        }
    ) { padding ->
        content(padding)
    }
}
