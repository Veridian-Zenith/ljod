package dev.vz.ljod.ui.metadata

import android.content.ContentValues
import android.provider.MediaStore
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import dev.vz.ljod.core.ui.theme.NordicPalette

@Composable
fun MetadataEditScreen(
    songId: Long,
    initialTitle: String,
    initialArtist: String,
    initialAlbum: String,
    onSaved: () -> Unit = {},
    onBack: () -> Unit = {},
) {
    val context = LocalContext.current
    var title by remember { mutableStateOf(initialTitle) }
    var artist by remember { mutableStateOf(initialArtist) }
    var album by remember { mutableStateOf(initialAlbum) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(NordicPalette.bg)
            .padding(horizontal = 24.dp, vertical = 16.dp)
            .verticalScroll(rememberScrollState()),
    ) {
        Icon(
            Icons.AutoMirrored.Rounded.ArrowBack,
            contentDescription = "Back",
            tint = NordicPalette.textSecondary,
            modifier = Modifier.clickable(onClick = onBack).padding(4.dp),
        )
        Spacer(Modifier.height(8.dp))
        Text("Edit Metadata", style = MaterialTheme.typography.headlineMedium, color = NordicPalette.accent)
        Spacer(Modifier.height(24.dp))

        StyledTextField("Title", title, { title = it })
        Spacer(Modifier.height(12.dp))
        StyledTextField("Artist", artist, { artist = it })
        Spacer(Modifier.height(12.dp))
        StyledTextField("Album", album, { album = it })
        Spacer(Modifier.height(24.dp))

        Button(
            onClick = {
                try {
                    val values = ContentValues().apply {
                        put(MediaStore.Audio.Media.TITLE, title)
                        put(MediaStore.Audio.Media.ARTIST, artist)
                        put(MediaStore.Audio.Media.ALBUM, album)
                    }
                    context.contentResolver.update(
                        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values,
                        "${MediaStore.Audio.Media._ID} = ?", arrayOf(songId.toString()),
                    )
                    Toast.makeText(context, "Metadata saved", Toast.LENGTH_SHORT).show()
                    onSaved()
                } catch (e: Exception) {
                    Toast.makeText(context, "Failed to save: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            },
            colors = ButtonDefaults.buttonColors(containerColor = NordicPalette.accent),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Save Changes", color = NordicPalette.bg)
        }
    }
}

@Composable
private fun StyledTextField(label: String, value: String, onValueChange: (String) -> Unit) {
    OutlinedTextField(
        value = value, onValueChange = onValueChange, label = { Text(label) }, singleLine = true,
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = NordicPalette.textPrimary, unfocusedTextColor = NordicPalette.textPrimary,
            focusedBorderColor = NordicPalette.accent, unfocusedBorderColor = NordicPalette.border,
            focusedLabelColor = NordicPalette.accent, unfocusedLabelColor = NordicPalette.textSecondary,
            cursorColor = NordicPalette.accent,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
}
