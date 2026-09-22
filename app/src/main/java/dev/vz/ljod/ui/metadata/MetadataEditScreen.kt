package dev.vz.ljod.ui.metadata

import android.content.ContentValues
import android.provider.MediaStore
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.vz.ljod.core.ui.glass.GlassButton
import dev.vz.ljod.core.ui.glass.GlassIconButton
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.theme.LjodTheme

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
    val palette = LjodTheme.palette
    var title by remember { mutableStateOf(initialTitle) }
    var artist by remember { mutableStateOf(initialArtist) }
    var album by remember { mutableStateOf(initialAlbum) }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .background(palette.bg)
                .padding(horizontal = 18.dp, vertical = 16.dp)
                .verticalScroll(rememberScrollState()),
    ) {
        GlassIconButton(
            icon = Icons.AutoMirrored.Rounded.ArrowBack,
            contentDescription = "Back",
            onClick = onBack,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            "Edit metadata",
            style = MaterialTheme.typography.displaySmall.copy(fontWeight = FontWeight.Black),
            color = palette.accent,
        )
        Spacer(Modifier.height(24.dp))
        StyledTextField("Title", title, { title = it })
        Spacer(Modifier.height(12.dp))
        StyledTextField("Artist", artist, { artist = it })
        Spacer(Modifier.height(12.dp))
        StyledTextField("Album", album, { album = it })
        Spacer(Modifier.height(24.dp))
        GlassButton(
            text = "Save changes",
            onClick = {
                try {
                    val values =
                        ContentValues().apply {
                            put(MediaStore.Audio.Media.TITLE, title)
                            put(MediaStore.Audio.Media.ARTIST, artist)
                            put(MediaStore.Audio.Media.ALBUM, album)
                        }
                    val updated =
                        context.contentResolver.update(
                            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                            values,
                            "${MediaStore.Audio.Media._ID} = ?",
                            arrayOf(songId.toString()),
                        )
                    val msg = if (updated > 0) "Metadata saved" else "No changes written"
                    Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                    onSaved()
                } catch (e: Exception) {
                    Toast.makeText(context, "Failed: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            },
            tone = GlassTone.Accent,
        )
    }
}

@Composable
private fun StyledTextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
) {
    val palette = LjodTheme.palette
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
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
}
