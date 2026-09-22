package dev.vz.ljod.ui.search

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.theme.AmoledPalette
import dev.vz.ljod.data.model.Song
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable

@Composable
fun SearchScreen(
    query: String,
    results: List<Song>,
    onSearch: (String) -> Unit,
    onBack: () -> Unit,
    onSongClick: (Song) -> Unit,
) {
    var currentQuery by remember { mutableStateOf(query) }

    LaunchedEffect(currentQuery) {
        onSearch(currentQuery)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AmoledPalette.bg)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(Icons.Rounded.ArrowBack, contentDescription = "Back")
            }
            OutlinedTextField(
                value = currentQuery,
                onValueChange = { currentQuery = it },
                label = { Text("Search songs, albums, artists") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
        }
        Text(
            text = "${results.size} result${if (results.size == 1) "" else "s"}",
            color = AmoledPalette.textSecondary,
        )
        LazyColumn(modifier = Modifier.fillMaxSize()) {
            items(results) { song ->
                GlassSurface {
                    Text(
                        text = song.title,
                        color = AmoledPalette.textPrimary,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSongClick(song) }
                            .padding(12.dp),
                    )
                }
            }
        }
    }
}
