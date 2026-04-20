package com.qubiccli.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.qubiccli.app.LocalAppState
import com.qubiccli.app.ui.QubicColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommandListScreen(nav: NavHostController, categoryName: String) {
    val app = LocalAppState.current
    val list = remember(categoryName) { app.catalog.commandsIn(categoryName) }

    Scaffold(
        containerColor = QubicColors.Base,
        topBar = {
            TopAppBar(
                title = { Text(categoryName, color = QubicColors.Text, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, null, tint = QubicColors.Accent)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = QubicColors.Base),
            )
        },
    ) { inner ->
        Column(Modifier.fillMaxSize().background(QubicColors.Base).padding(inner)) {
            Text(
                "${list.size} commands",
                color = QubicColors.TextDim,
                fontSize = 12.sp,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            )
            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(list, key = { it.flag }) { cmd ->
                    CommandCard(cmd, isFav = app.history.isFavorite(cmd.flag)) {
                        nav.navigate("command/${cmd.flag}")
                    }
                }
            }
        }
    }
}

@Composable
fun FavoritesScreen(nav: NavHostController) {
    val app = LocalAppState.current
    val favSet = app.history.favorites.value
    val favs = remember(favSet) { app.catalog.commands.filter { favSet.contains(it.flag) } }

    Column(Modifier.fillMaxSize().background(QubicColors.Base).padding(16.dp)) {
        Text("Favorites", color = QubicColors.Text, fontWeight = FontWeight.Bold, fontSize = 24.sp)
        Spacer(Modifier.height(12.dp))
        if (favs.isEmpty()) {
            Text("No favorites yet", color = QubicColors.Text, fontWeight = FontWeight.SemiBold)
            Text(
                "Tap the star on any command to pin it here.",
                color = QubicColors.TextDim,
                fontSize = 12.sp,
            )
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(favs, key = { it.flag }) { cmd ->
                    CommandCard(cmd, isFav = true) { nav.navigate("command/${cmd.flag}") }
                }
            }
        }
    }
}
