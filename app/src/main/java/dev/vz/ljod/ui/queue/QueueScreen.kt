package dev.vz.ljod.ui.queue

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.ClearAll
import androidx.compose.material.icons.rounded.DragHandle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.vz.ljod.core.ui.glass.GlassButton
import dev.vz.ljod.core.ui.glass.GlassIconButton
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme
import dev.vz.ljod.playback.PlaybackController

@Composable
fun QueueScreen(
    controller: PlaybackController,
    onBack: () -> Unit,
) {
    val items by controller.mediaItems.collectAsState()
    val currentIndex by controller.currentIndex.collectAsState()
    val title by controller.title.collectAsState()
    val artist by controller.artist.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(horizontal = 18.dp)) {
        Spacer(Modifier.height(40.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            GlassIconButton(
                icon = Icons.AutoMirrored.Rounded.ArrowBack,
                contentDescription = "Back",
                onClick = onBack,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                "Up next",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = LjodTheme.palette.textPrimary,
            )
            Spacer(Modifier.weight(1f))
            GlassIconButton(
                icon = Icons.Rounded.ClearAll,
                contentDescription = "Clear queue",
                onClick = { controller.clearQueue() },
                tone = GlassTone.Danger,
            )
        }
        Spacer(Modifier.height(16.dp))
        if (items.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("Queue is empty", style = MaterialTheme.typography.bodyMedium, color = LjodTheme.palette.textSecondary)
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                itemsIndexed(items, key = { _, item -> item.mediaId.orEmpty() + item.localConfiguration?.uri.toString() }) { index, item ->
                    val isCurrent = index == currentIndex
                    GlassSurface(
                        tone = if (isCurrent) GlassTone.Warm else GlassTone.Subtle,
                        modifier = Modifier.fillMaxWidth(),
                        cornerRadius = LjodDimens.radiusMd,
                    ) {
                        Row(
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        val id = item.mediaId?.toLongOrNull() ?: return@clickable
                                        controller.setQueue(items.mapNotNull { it.mediaId }, id.toString())
                                    }.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(
                                modifier =
                                    Modifier
                                        .size(36.dp)
                                        .clip(
                                            LjodDimens.radiusSm.let {
                                                androidx.compose.foundation.shape
                                                    .RoundedCornerShape(it)
                                            },
                                        ).background(
                                            if (isCurrent) {
                                                Brush.verticalGradient(listOf(LjodTheme.palette.accent, LjodTheme.palette.accentDeep))
                                            } else {
                                                Brush.verticalGradient(listOf(LjodTheme.palette.surfaceHigh, LjodTheme.palette.surface))
                                            },
                                        ),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = (index + 1).toString(),
                                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                                    color = if (isCurrent) LjodTheme.palette.onAccent else LjodTheme.palette.textSecondary,
                                )
                            }
                            Spacer(Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text =
                                        item.mediaMetadata.title
                                            ?.toString()
                                            .orEmpty(),
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                    color = LjodTheme.palette.textPrimary,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                Text(
                                    text =
                                        item.mediaMetadata.artist
                                            ?.toString()
                                            .orEmpty(),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = LjodTheme.palette.textSecondary,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                            Spacer(Modifier.width(8.dp))
                            GlassIconButton(
                                icon = Icons.Rounded.DragHandle,
                                contentDescription = "Reorder",
                                onClick = { /* future reorder UI */ },
                                size = 36.dp,
                                iconSize = LjodDimens.iconSm,
                            )
                        }
                    }
                }
            }
        }
    }
}
