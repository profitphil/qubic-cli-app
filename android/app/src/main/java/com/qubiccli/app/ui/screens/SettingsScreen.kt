package com.qubiccli.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.qubiccli.app.LocalAppState
import com.qubiccli.app.net.Api
import com.qubiccli.app.ui.QubicColors
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen() {
    val app = LocalAppState.current
    val s = app.settings
    val scope = rememberCoroutineScope()

    var baseURL by remember { mutableStateOf(s.baseURL) }
    var nodeIP by remember { mutableStateOf(s.nodeIP) }
    var nodePort by remember { mutableStateOf(s.nodePort) }
    var tokenField by remember { mutableStateOf("") }
    var seedField by remember { mutableStateOf("") }
    var showSeed by remember { mutableStateOf(false) }
    var healthStatus by remember { mutableStateOf<String?>(null) }
    var healthOK by remember { mutableStateOf<Boolean?>(null) }
    val hasToken = s.token.isNotEmpty()
    val hasSeed = s.seed.isNotEmpty()

    Column(
        Modifier
            .fillMaxSize()
            .background(QubicColors.Base)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Settings", color = QubicColors.Text, fontWeight = FontWeight.Bold, fontSize = 24.sp)

        // Backend
        SectionCard("Backend") {
            OutlinedTextField(
                value = baseURL,
                onValueChange = { baseURL = it; s.persistBaseURL(it) },
                label = { Text("Base URL", color = QubicColors.TextDim) },
                placeholder = { Text("http://100.x.x.x:8787", color = QubicColors.TextFaint) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = tokenField,
                    onValueChange = { tokenField = it },
                    label = { Text("API token", color = QubicColors.TextDim) },
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(8.dp))
                TextButton(
                    enabled = tokenField.isNotEmpty(),
                    onClick = { s.persistToken(tokenField); tokenField = "" },
                ) { Text("Save", color = QubicColors.Accent) }
            }
            if (hasToken) {
                Text(
                    "Token stored in Keystore (EncryptedSharedPreferences)",
                    color = QubicColors.TextDim,
                    fontSize = 11.sp,
                )
            }
            OutlinedButton(
                onClick = {
                    scope.launch {
                        healthStatus = "Testing…"
                        healthOK = null
                        try {
                            val ok = Api(s).health()
                            healthOK = ok
                            healthStatus = if (ok) "Reachable" else "Not reachable"
                        } catch (e: Exception) {
                            healthOK = false
                            healthStatus = e.message
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = QubicColors.Accent),
            ) { Text("Test connection") }
            healthStatus?.let {
                Row {
                    Text(
                        when (healthOK) {
                            true  -> "✓ "
                            false -> "✗ "
                            else  -> ""
                        },
                        color = when (healthOK) {
                            true  -> QubicColors.Success
                            false -> QubicColors.Danger
                            else  -> QubicColors.TextDim
                        },
                    )
                    Text(it, color = QubicColors.Text, fontSize = 12.sp)
                }
            }
        }

        // Node
        SectionCard("Node") {
            OutlinedTextField(
                value = nodeIP,
                onValueChange = { nodeIP = it; s.persistNodeIP(it) },
                label = { Text("Node IP (optional)", color = QubicColors.TextDim) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = nodePort,
                onValueChange = { nodePort = it; s.persistNodePort(it) },
                label = { Text("Node port", color = QubicColors.TextDim) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                "Auto-injected as -nodeip / -nodeport into every command.",
                color = QubicColors.TextFaint,
                fontSize = 11.sp,
            )
        }

        // Seed
        SectionCard("Seed") {
            OutlinedTextField(
                value = seedField,
                onValueChange = { seedField = it },
                label = { Text("55-char seed", color = QubicColors.TextDim) },
                visualTransformation = if (showSeed) VisualTransformation.None else PasswordVisualTransformation(),
                singleLine = true,
                textStyle = androidx.compose.ui.text.TextStyle(fontFamily = FontFamily.Monospace),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Show seed while typing", color = QubicColors.Text, modifier = Modifier.weight(1f))
                Switch(
                    checked = showSeed,
                    onCheckedChange = { showSeed = it },
                    colors = SwitchDefaults.colors(checkedTrackColor = QubicColors.Accent),
                )
            }
            Row {
                TextButton(
                    enabled = seedField.length == 55,
                    onClick = { s.persistSeed(seedField); seedField = "" },
                ) { Text("Save seed", color = QubicColors.Accent) }
                Spacer(Modifier.weight(1f))
                if (hasSeed) {
                    TextButton(onClick = { s.persistSeed("") }) {
                        Text("Clear", color = QubicColors.Danger)
                    }
                }
            }
            if (hasSeed) {
                Text(
                    "Stored in Keystore · device-only · AES-GCM",
                    color = QubicColors.TextDim,
                    fontSize = 11.sp,
                )
            }
            Text(
                "Used only when you run a command that signs a transaction. Anyone with your seed can drain your wallet — do not share.",
                color = QubicColors.TextFaint,
                fontSize = 11.sp,
            )
        }

        // About
        SectionCard("About") {
            Row { Text("App", color = QubicColors.Text, modifier = Modifier.weight(1f)); Text("QubicApp 0.2", color = QubicColors.TextDim) }
            Row { Text("Backend", color = QubicColors.Text, modifier = Modifier.weight(1f)); Text("qubic-api remote", color = QubicColors.TextDim) }
        }

        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun SectionCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(colors = CardDefaults.cardColors(containerColor = QubicColors.Surface)) {
        Column(
            Modifier.padding(14.dp).fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(title, color = QubicColors.TextDim, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            content()
        }
    }
}
