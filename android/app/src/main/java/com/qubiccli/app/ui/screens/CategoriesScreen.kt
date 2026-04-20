package com.qubiccli.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.qubiccli.app.LocalAppState
import com.qubiccli.app.data.Command
import com.qubiccli.app.data.CommandCategory
import com.qubiccli.app.ui.QubicColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoriesScreen(nav: NavHostController) {
    val app = LocalAppState.current
    var search by remember { mutableStateOf("") }

    Column(
        Modifier
            .fillMaxSize()
            .background(QubicColors.Base),
    ) {
        // Header
        Column(Modifier.padding(16.dp)) {
            Text(
                "Qubic CLI",
                color = QubicColors.Text,
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
            )
            Text(
                "${app.catalog.commands.size} commands · ${app.catalog.categories.size} categories",
                color = QubicColors.TextDim,
                fontSize = 12.sp,
            )
        }

        // Search
        OutlinedTextField(
            value = search,
            onValueChange = { search = it },
            placeholder = { Text("Search commands", color = QubicColors.TextDim) },
            leadingIcon = { Icon(Icons.Outlined.Search, null, tint = QubicColors.TextDim) },
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = QubicColors.Text,
                unfocusedTextColor = QubicColors.Text,
                focusedBorderColor = QubicColors.Accent,
                unfocusedBorderColor = QubicColors.Hairline,
                cursorColor = QubicColors.Accent,
            ),
        )

        Spacer(Modifier.height(12.dp))

        if (search.isBlank()) {
            val cats = remember(app.catalog) { app.catalog.categories.sortedBy { it.order } }
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxSize(),
            ) {
                items(cats, key = { it.id }) { cat ->
                    CategoryCard(
                        category = cat,
                        count = app.catalog.commandsIn(cat.name).size,
                        onClick = { nav.navigate("category/${cat.name}") },
                    )
                }
            }
        } else {
            val results = remember(search) { app.catalog.search(search) }
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                if (results.isEmpty()) {
                    Text(
                        "No matches for \"$search\"",
                        color = QubicColors.TextDim,
                        modifier = Modifier.padding(top = 40.dp),
                    )
                }
                results.forEach { cmd ->
                    CommandCard(cmd = cmd, isFav = app.history.isFavorite(cmd.flag)) {
                        nav.navigate("command/${cmd.flag}")
                    }
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}

@Composable
fun CategoryCard(category: CommandCategory, count: Int, onClick: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 130.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(QubicColors.Surface)
            .border(1.dp, QubicColors.Hairline, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
    ) {
        Box(
            Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(QubicColors.Accent.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(categoryEmoji(category.icon), fontSize = 18.sp)
        }
        Spacer(Modifier.weight(1f))
        Text(
            category.name,
            color = QubicColors.Text,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            "$count ${if (count == 1) "command" else "commands"}",
            color = QubicColors.TextDim,
            fontSize = 12.sp,
        )
    }
}

@Composable
fun CommandCard(cmd: Command, isFav: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(QubicColors.Surface)
            .border(1.dp, QubicColors.Hairline, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        val tint = when {
            cmd.readOnly  -> QubicColors.Accent
            cmd.needsSeed -> QubicColors.Warn
            else          -> androidx.compose.ui.graphics.Color(0xFFB084E8)
        }
        Box(
            Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(tint.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                when { cmd.readOnly -> "R"; cmd.needsSeed -> "S"; else -> "!" },
                color = tint,
                fontWeight = FontWeight.Bold,
            )
        }
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    cmd.flag,
                    color = QubicColors.Text,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                if (isFav) {
                    Spacer(Modifier.width(6.dp))
                    Text("★", color = QubicColors.Accent, fontSize = 12.sp)
                }
                Spacer(Modifier.weight(1f))
                if (cmd.readOnly)  Badge("READ", QubicColors.Accent)
                if (cmd.needsSeed) { Spacer(Modifier.width(4.dp)); Badge("SIGNS", QubicColors.Warn) }
            }
            Spacer(Modifier.height(4.dp))
            Text(
                cmd.description,
                color = QubicColors.TextDim,
                fontSize = 12.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
fun Badge(text: String, color: androidx.compose.ui.graphics.Color) {
    Box(
        Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(color.copy(alpha = 0.15f))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    ) {
        Text(text, color = color, fontSize = 9.sp, fontWeight = FontWeight.Bold)
    }
}

/** Rough mapping from iOS SF Symbol names to emoji (no icon asset polish). */
private fun categoryEmoji(sfSymbol: String): String = when {
    sfSymbol.contains("wallet") -> "W"
    sfSymbol.contains("arrow") -> "→"
    sfSymbol.contains("doc") -> "Do"
    sfSymbol.contains("bolt") -> "B"
    sfSymbol.contains("key") -> "K"
    sfSymbol.contains("chart") -> "C"
    sfSymbol.contains("cube") -> "Cu"
    sfSymbol.contains("person") -> "P"
    sfSymbol.contains("gear") -> "G"
    sfSymbol.contains("shield") -> "S"
    sfSymbol.contains("star") -> "*"
    sfSymbol.contains("lock") -> "L"
    else -> "#"
}
