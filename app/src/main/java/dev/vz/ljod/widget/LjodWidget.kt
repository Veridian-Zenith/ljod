package dev.vz.ljod.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider

class LjodWidget : GlanceAppWidget() {
    override suspend fun provideGlance(
        context: Context,
        id: GlanceId,
    ) {
        provideContent {
            GlanceTheme {
                Content()
            }
        }
    }

    @Composable
    private fun Content() {
        Box(
            modifier =
                GlanceModifier
                    .fillMaxSize()
                    .background(ColorProvider(Color(0xFF050000)))
                    .cornerRadius(20.dp)
                    .padding(12.dp),
        ) {
            Row(
                modifier = GlanceModifier.fillMaxSize(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier =
                        GlanceModifier
                            .size(48.dp)
                            .background(ColorProvider(Color(0xFFE11D2E)))
                            .cornerRadius(12.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "L",
                        style =
                            TextStyle(
                                color = ColorProvider(Color(0xFFFFFFFF)),
                                fontSize = 22.sp,
                                fontWeight = FontWeight.Bold,
                            ),
                    )
                }
                Spacer(modifier = GlanceModifier.width(12.dp))
                Column {
                    Text(
                        text = "Ljod",
                        style =
                            TextStyle(
                                color = ColorProvider(Color(0xFFE11D2E)),
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                            ),
                    )
                    Text(
                        text = "Open player",
                        style =
                            TextStyle(
                                color = ColorProvider(Color(0xFFA89A9A)),
                                fontSize = 12.sp,
                            ),
                    )
                }
            }
        }
    }
}

class LjodWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = LjodWidget()
}
