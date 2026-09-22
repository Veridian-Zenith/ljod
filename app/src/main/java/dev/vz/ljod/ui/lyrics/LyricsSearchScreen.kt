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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.vz.ljod.core.ui.glass.GlassButton
import dev.vz.ljod.core.ui.glass.GlassIconButton
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme
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
    val palette = LjodTheme.palette
    var searchTitle by remember { mutableStateOf(title) }
    var searchArtist by remember { mutableStateOf(artist) }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .background(palette.bg)
                .padding(horizontal = 18.dp, vertical = 16.dp),
    ) {
        GlassIconButton(
            icon = Icons.AutoMirrored.Rounded.ArrowBack,
            contentDescription = "Back",
            onClick = onBack,
        )
        Spacer(Modifier.height(12.dp))
        Text("Search Lyrics", style = MaterialTheme.typography.displaySmall.copy(fontWeight = FontWeight.Black), color = palette.accent)
        Spacer(Modifier.height(16.dp))
        OutlinedTextField(
            value = searchTitle,
            onValueChange = { searchTitle = it },
            label = { Text("Song Title") },
            singleLine = true,
            colors =
                OutlinedTextFieldDefaults.colors(
                    focusedTextColor = palette.textPrimary,
                    unfocusedTextColor = palette.textPrimary,
                    focusedBorderColor = palette.accent,
                    unfocusedBorderColor = palette.border,
                    focusedLabelColor = palette.accent,
                    cursorColor = palette.accent,
                ),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = searchArtist,
            onValueChange = { searchArtist = it },
            label = { Text("Artist") },
            singleLine = true,
            colors =
                OutlinedTextFieldDefaults.colors(
                    focusedTextColor = palette.textPrimary,
                    unfocusedTextColor = palette.textPrimary,
                    focusedBorderColor = palette.accent,
                    unfocusedBorderColor = palette.border,
                    focusedLabelColor = palette.accent,
                    cursorColor = palette.accent,
                ),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        GlassButton(text = "SEARCH", onClick = { onSearch(searchTitle, searchArtist) }, tone = GlassTone.Accent)
        Spacer(Modifier.height(16.dp))
        if (searchResults.isNotEmpty()) {
            Text("${searchResults.size} results", style = MaterialTheme.typography.bodySmall, color = palette.textSecondary)
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
private fun SearchResultRow(
    result: LyricsResult,
    onClick: () -> Unit,
) {
    val palette = LjodTheme.palette
    GlassSurface(
        tone = GlassTone.Subtle,
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = LjodDimens.radiusLg,
        onClick = onClick,
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                result.source,
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                color = palette.textPrimary,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                "${result.lines.size} lines${if (result.isSynced) " (synced)" else ""}",
                style = MaterialTheme.typography.bodySmall,
                color = palette.textSecondary,
            )
            if (result.lines.isNotEmpty()) {
                Spacer(Modifier.height(4.dp))
                Text(
                    result.lines.take(3).joinToString("\n") { it.text },
                    style = MaterialTheme.typography.bodySmall,
                    color = palette.textSecondary.copy(alpha = 0.7f),
                    maxLines = 3,
                )
            }
        }
    }
}
