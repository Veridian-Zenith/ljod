package dev.vz.ljod.ui.lyrics

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.vz.ljod.core.ui.theme.NordicPalette
import dev.vz.ljod.data.lyrics.LyricsResult

@Composable
fun LyricsSearchScreen(
    title: String,
    artist: String,
    searchResults: List<LyricsResult>,
    onSearch: (String, String) -> Unit,
    onResultClick: (LyricsResult) -> Unit,
    onBack: () -> Unit,
) {
    BackHandler { onBack() }

    var searchTitle by remember { mutableStateOf(title) }
    var searchArtist by remember { mutableStateOf(artist) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(NordicPalette.bg)
            .padding(horizontal = 24.dp, vertical = 16.dp),
    ) {
        Icon(
            Icons.AutoMirrored.Rounded.ArrowBack,
            contentDescription = "Back",
            tint = NordicPalette.textSecondary,
            modifier = Modifier.clickable(onClick = onBack).padding(4.dp),
        )

        Spacer(Modifier.height(8.dp))
        Text("Search Lyrics", style = MaterialTheme.typography.headlineMedium, color = NordicPalette.accent)

        Spacer(Modifier.height(16.dp))

        OutlinedTextField(
            value = searchTitle,
            onValueChange = { searchTitle = it },
            label = { Text("Song Title") },
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = NordicPalette.textPrimary,
                unfocusedTextColor = NordicPalette.textPrimary,
                focusedBorderColor = NordicPalette.accent,
                unfocusedBorderColor = NordicPalette.border,
                focusedLabelColor = NordicPalette.accent,
                cursorColor = NordicPalette.accent,
            ),
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(Modifier.height(8.dp))

        OutlinedTextField(
            value = searchArtist,
            onValueChange = { searchArtist = it },
            label = { Text("Artist") },
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = NordicPalette.textPrimary,
                unfocusedTextColor = NordicPalette.textPrimary,
                focusedBorderColor = NordicPalette.accent,
                unfocusedBorderColor = NordicPalette.border,
                focusedLabelColor = NordicPalette.accent,
                cursorColor = NordicPalette.accent,
            ),
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(Modifier.height(12.dp))

        Text(
            "SEARCH",
            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
            color = NordicPalette.accent,
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(NordicPalette.accentDim)
                .clickable { onSearch(searchTitle, searchArtist) }
                .padding(horizontal = 16.dp, vertical = 8.dp),
        )

        Spacer(Modifier.height(16.dp))

        if (searchResults.isNotEmpty()) {
            Text(
                "${searchResults.size} results found",
                style = MaterialTheme.typography.bodySmall,
                color = NordicPalette.textSecondary,
            )
            Spacer(Modifier.height(8.dp))
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(searchResults) { result ->
                    SearchResultRow(result = result, onClick = { onResultClick(result) })
                }
            }
        }
    }
}

@Composable
private fun SearchResultRow(result: LyricsResult, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(NordicPalette.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(
            result.source,
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
            color = NordicPalette.textPrimary,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            "${result.lines.size} lines${if (result.isSynced) " (synced)" else ""}",
            style = MaterialTheme.typography.bodySmall,
            color = NordicPalette.textSecondary,
        )
        if (result.lines.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            Text(
                result.lines.take(3).joinToString("\n") { it.text },
                style = MaterialTheme.typography.bodySmall,
                color = NordicPalette.textSecondary.copy(alpha = 0.7f),
                maxLines = 3,
            )
        }
    }
}
