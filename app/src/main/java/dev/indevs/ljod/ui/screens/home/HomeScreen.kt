package dev.indevs.ljod.ui.screens.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.indevs.ljod.ui.theme.Amber
import dev.indevs.ljod.ui.theme.TextSecondary

@Composable
fun HomeScreen(padding: PaddingValues) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(horizontal = 24.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.Top,
    ) {
        Text(
            text = "Veridian Zenith",
            style = MaterialTheme.typography.headlineLarge,
            color = Amber,
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "Forge your sound.",
            style = MaterialTheme.typography.bodyLarge,
            color = TextSecondary,
        )
    }
}
