package dev.vz.ljod.core.ui.navigation

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.vector.ImageVector

data class Screen(
    val key: String,
    val icon: ImageVector,
    val label: String,
    val content: @Composable (PaddingValues) -> Unit,
)

@Composable
fun ScreenHost(
    screens: List<Screen>,
    initialScreen: String = screens.first().key,
) {
    var current by remember { mutableStateOf(initialScreen) }
    val screen = screens.first { it.key == current }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surfaceVariant,
            ) {
                screens.forEach { s ->
                    NavigationBarItem(
                        selected = current == s.key,
                        onClick = { current = s.key },
                        icon = { Icon(s.icon, contentDescription = s.label) },
                        label = { Text(s.label) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.primary,
                            selectedTextColor = MaterialTheme.colorScheme.primary,
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            indicatorColor = MaterialTheme.colorScheme.surfaceVariant,
                        )
                    )
                }
            }
        }
    ) { padding ->
        screen.content(padding)
    }
}
