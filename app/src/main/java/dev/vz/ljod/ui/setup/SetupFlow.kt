package dev.vz.ljod.ui.setup

import android.Manifest
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import dev.vz.ljod.core.ui.theme.AmoledPalette
import dev.vz.ljod.core.ui.glass.GlassSurface
import androidx.compose.foundation.background

private fun isPermissionGranted(context: Context, perm: String): Boolean =
    context.checkSelfPermission(perm) == android.content.pm.PackageManager.PERMISSION_GRANTED

@Composable
fun SetupFlow(onComplete: () -> Unit) {
    val context = LocalContext.current
    var folderUri by remember { mutableStateOf<Uri?>(null) }
    var notifGranted by remember {
        mutableStateOf(
            if (android.os.Build.VERSION.SDK_INT >= 33) isPermissionGranted(context, Manifest.permission.POST_NOTIFICATIONS) else true,
        )
    }
    var audioGranted by remember { mutableStateOf(isPermissionGranted(context, Manifest.permission.READ_MEDIA_AUDIO)) }

    val permLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { results ->
        notifGranted = results[Manifest.permission.POST_NOTIFICATIONS] ?: notifGranted
        audioGranted = results[Manifest.permission.READ_MEDIA_AUDIO] ?: audioGranted
    }

    val folderLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocumentTree(),
    ) { uri ->
        uri?.let {
            context.contentResolver.takePersistableUriPermission(
                it,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            folderUri = it
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AmoledPalette.bg),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(32.dp),
        ) {
            GlassSurface {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(16.dp)) {
                    Text("Welcome to Ljod", style = MaterialTheme.typography.headlineLarge, color = AmoledPalette.textPrimary)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Set up your music library", style = MaterialTheme.typography.bodyMedium, color = AmoledPalette.textSecondary)
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            Text("1. Select a music folder", color = AmoledPalette.textPrimary)
            Button(
                onClick = { folderLauncher.launch(Uri.parse("content://com.android.externalstorage.documents/document/primary%3AMusic")) },
                modifier = Modifier.fillMaxWidth(),
            ) { Text(if (folderUri == null) "Select Music Folder" else "Folder Selected ✓") }
            folderUri?.let {
                Text("Path: ${it.path}", color = AmoledPalette.textSecondary, style = MaterialTheme.typography.bodySmall)
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text("2. Grant permissions", color = AmoledPalette.textPrimary)
            Text("Notifications: ${if (notifGranted) "✓" else "required"}", color = AmoledPalette.textSecondary)
            Text("Audio access: ${if (audioGranted) "✓" else "required"}", color = AmoledPalette.textSecondary)
            Button(
                onClick = {
                    permLauncher.launch(
                        buildList {
                            if (android.os.Build.VERSION.SDK_INT >= 33 && !notifGranted) add(Manifest.permission.POST_NOTIFICATIONS)
                            if (!audioGranted) add(Manifest.permission.READ_MEDIA_AUDIO)
                        }.toTypedArray(),
                    )
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Grant Permissions") }
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = onComplete,
                enabled = folderUri != null && audioGranted,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Continue to Library") }
        }
    }
}
