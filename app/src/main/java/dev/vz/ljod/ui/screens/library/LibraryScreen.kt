package dev.vz.ljod.ui.screens.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.vz.ljod.ui.theme.TextSecondary

@Composable
fun LibraryScreen(padding: PaddingValues) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(horizontal = 24.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.Top,
    ) {
        Text(
            text = "Library",
            style = MaterialTheme.typography.headlineLarge,
        )
        Text(
            text = "Your music, forged in silence.",
            style = MaterialTheme.typography.bodyLarge,
            color = TextSecondary,
        )
    }
}
