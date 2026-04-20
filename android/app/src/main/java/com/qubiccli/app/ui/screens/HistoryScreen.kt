package com.qubiccli.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.qubiccli.app.LocalAppState
import com.qubiccli.app.data.HistoryEntry
import com.qubiccli.app.ui.QubicColors
import java.text.DateFormat
import java.util.Date

@Composable
fun HistoryScreen() {
    val app = LocalAppState.current
    val entries = app.history.entries

    Column(Modifier.fillMaxSize().background(QubicColors.Base).padding(16.dp)) {
        Text("History", color = QubicColors.Text, fontWeight = FontWeight.Bold, fontSize = 24.sp)
        Spacer(Modifier.height(12.dp))
        if (entries.isEmpty()) {
            Text("No history yet", color = QubicColors.Text, fontWeight = FontWeight.SemiBold)
            Text(
                "Commands you run will appear here.",
                color = QubicColors.TextDim,
                fontSize = 12.sp,
            )
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(entries, key = { it.id }) { e -> HistoryCard(e) }
            }
        }
    }
}

@Composable
private fun HistoryCard(e: HistoryEntry) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(QubicColors.Surface)
            .border(1.dp, QubicColors.Hairline, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (e.exitCode == 0) "✓" else "✗",
                color = if (e.exitCode == 0) QubicColors.Success else QubicColors.Danger,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.width(6.dp))
            Text(
                e.flag,
                color = QubicColors.Text,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.SemiBold,
                fontSize = 13.sp,
            )
            Spacer(Modifier.weight(1f))
            Text(
                DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT).format(Date(e.date)),
                color = QubicColors.TextDim,
                fontSize = 10.sp,
            )
        }
        Spacer(Modifier.height(4.dp))
        Text(
            e.args.joinToString(" "),
            color = QubicColors.TextDim,
            fontSize = 11.sp,
            maxLines = 2,
        )
        if (e.stdoutHead.isNotEmpty()) {
            Spacer(Modifier.height(6.dp))
            Text(
                e.stdoutHead,
                color = QubicColors.TextDim,
                fontFamily = FontFamily.Monospace,
                fontSize = 10.sp,
                maxLines = 3,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(6.dp))
                    .background(QubicColors.Base.copy(alpha = 0.5f))
                    .padding(8.dp),
            )
        }
    }
}
