package com.qubiccli.app.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.qubiccli.app.LocalAppState
import com.qubiccli.app.data.Command
import com.qubiccli.app.data.CommandArg
import com.qubiccli.app.data.ExecResponse
import com.qubiccli.app.net.Api
import com.qubiccli.app.ui.QubicColors
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommandDetailScreen(nav: NavHostController, flag: String) {
    val app = LocalAppState.current
    val command = remember(flag) { app.catalog.commands.firstOrNull { it.flag == flag } }

    if (command == null) {
        Box(Modifier.fillMaxSize().background(QubicColors.Base), contentAlignment = Alignment.Center) {
            Text("Command not found: $flag", color = QubicColors.TextDim)
        }
        return
    }

    val values = remember { mutableStateMapOf<String, String>() }
    var useStoredSeed by remember { mutableStateOf(true) }
    var running by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<ExecResponse?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var showConfirm by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val isFav = app.history.favorites.value.contains(command.flag)

    val canRun = remember(values.toMap(), command) {
        command.args.filter { it.required }.all { (values[it.name] ?: "").isNotEmpty() }
    }

    fun runNow() {
        scope.launch {
            running = true
            error = null
            result = null
            try {
                val argsOut = mutableListOf<String>()
                argsOut.add(command.flag)
                for (a in command.args) {
                    val v = values[a.name] ?: ""
                    if (v.isEmpty()) continue
                    if (a.type == "bool") {
                        if (v.lowercase() == "true" || v == "1") continue // flag-only booleans handled elsewhere
                    }
                    argsOut.add(v)
                }
                if (command.needsSeed) {
                    val seed = if (useStoredSeed) app.settings.seed else (values["__seed"] ?: "")
                    if (seed.isNotEmpty()) {
                        argsOut.add(0, seed)
                        argsOut.add(0, "-seed")
                    }
                }
                val api = Api(app.settings)
                val resp = api.exec(argsOut, timeoutSec = 60)
                result = resp
                app.history.record(command.flag, argsOut, resp)
            } catch (e: Exception) {
                error = e.message ?: e.toString()
            } finally {
                running = false
            }
        }
    }

    Scaffold(
        containerColor = QubicColors.Base,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        command.flag,
                        color = QubicColors.Text,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = FontFamily.Monospace,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, null, tint = QubicColors.Accent)
                    }
                },
                actions = {
                    IconButton(onClick = { app.history.toggleFavorite(command.flag) }) {
                        Icon(
                            if (isFav) Icons.Outlined.Star else Icons.Outlined.StarBorder,
                            null,
                            tint = QubicColors.Accent,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = QubicColors.Base),
            )
        },
    ) { inner ->
        Column(
            Modifier
                .fillMaxSize()
                .background(QubicColors.Base)
                .padding(inner)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            // Header card
            Card(colors = CardDefaults.cardColors(containerColor = QubicColors.Surface)) {
                Column(Modifier.padding(14.dp)) {
                    Row {
                        if (command.readOnly)  Badge("READ",  QubicColors.Accent)
                        if (command.needsSeed) { Spacer(Modifier.width(6.dp)); Badge("SIGNS", QubicColors.Warn) }
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(
                        command.flag,
                        color = QubicColors.Text,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp,
                    )
                    Text(command.description, color = QubicColors.TextDim, fontSize = 13.sp)
                }
            }

            // Seed section
            if (command.needsSeed) {
                Card(colors = CardDefaults.cardColors(containerColor = QubicColors.Surface)) {
                    Column(Modifier.padding(14.dp)) {
                        Text("Seed", color = QubicColors.TextDim, fontSize = 12.sp)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("Use stored seed", color = QubicColors.Text, modifier = Modifier.weight(1f))
                            Switch(
                                checked = useStoredSeed,
                                onCheckedChange = { useStoredSeed = it },
                                colors = SwitchDefaults.colors(checkedTrackColor = QubicColors.Accent),
                            )
                        }
                        if (!useStoredSeed) {
                            OutlinedTextField(
                                value = values["__seed"] ?: "",
                                onValueChange = { values["__seed"] = it },
                                label = { Text("55-char seed", color = QubicColors.TextDim) },
                                visualTransformation = PasswordVisualTransformation(),
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        } else if (app.settings.seed.isEmpty()) {
                            Text(
                                "No seed stored — add one in Settings.",
                                color = QubicColors.Danger,
                                fontSize = 12.sp,
                            )
                        } else {
                            Text("Using seed from Keystore", color = QubicColors.TextDim, fontSize = 12.sp)
                        }
                    }
                }
            }

            // Args
            if (command.args.isNotEmpty()) {
                Card(colors = CardDefaults.cardColors(containerColor = QubicColors.Surface)) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text("Arguments", color = QubicColors.TextDim, fontSize = 12.sp)
                        command.args.forEach { arg ->
                            ArgField(
                                arg = arg,
                                value = values[arg.name] ?: "",
                                onChange = { values[arg.name] = it },
                                settings = app.settings,
                            )
                        }
                    }
                }
            }

            // Run button
            Button(
                onClick = {
                    error = null; result = null
                    if (command.needsSeed && !command.readOnly) showConfirm = true else runNow()
                },
                enabled = !running && canRun,
                colors = ButtonDefaults.buttonColors(
                    containerColor = QubicColors.Accent,
                    contentColor = QubicColors.Base,
                    disabledContainerColor = QubicColors.SurfaceHigh,
                    disabledContentColor = QubicColors.TextDim,
                ),
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (running) {
                    CircularProgressIndicator(
                        color = QubicColors.Base,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                }
                Text(
                    if (running) "Running…"
                    else if (command.needsSeed) "Review & Run"
                    else "Run",
                    fontWeight = FontWeight.SemiBold,
                )
            }

            result?.let { ResultBlock(it) }
            error?.let {
                Card(colors = CardDefaults.cardColors(containerColor = QubicColors.Surface)) {
                    Column(Modifier.padding(14.dp)) {
                        Text("Error", color = QubicColors.TextDim, fontSize = 12.sp)
                        Text(
                            it,
                            color = QubicColors.Danger,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 12.sp,
                        )
                    }
                }
            }

            Spacer(Modifier.height(24.dp))
        }
    }

    if (showConfirm) {
        AlertDialog(
            onDismissRequest = { showConfirm = false },
            confirmButton = {
                TextButton(onClick = { showConfirm = false; runNow() }) {
                    Text("Run", color = QubicColors.Danger)
                }
            },
            dismissButton = {
                TextButton(onClick = { showConfirm = false }) {
                    Text("Cancel", color = QubicColors.TextDim)
                }
            },
            title = { Text("Confirm", color = QubicColors.Text) },
            text = {
                Text(
                    "This will sign and submit a transaction via qubic-cli ${command.flag}. Proceed?",
                    color = QubicColors.TextDim,
                )
            },
            containerColor = QubicColors.Surface,
        )
    }
}

@Composable
private fun ArgField(
    arg: CommandArg,
    value: String,
    onChange: (String) -> Unit,
    settings: com.qubiccli.app.data.Settings,
) {
    Column(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(arg.name, color = QubicColors.TextDim, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            if (arg.required) {
                Spacer(Modifier.width(6.dp))
                Text("required", color = QubicColors.Accent, fontSize = 10.sp)
            }
            Spacer(Modifier.weight(1f))
            Text(arg.type.uppercase(), color = QubicColors.TextFaint, fontSize = 10.sp)
        }
        Spacer(Modifier.height(4.dp))
        when (arg.type) {
            "number", "tick" -> OutlinedTextField(
                value = value,
                onValueChange = onChange,
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth(),
            )
            "address", "hex" -> OutlinedTextField(
                value = value,
                onValueChange = onChange,
                singleLine = true,
                textStyle = androidx.compose.ui.text.TextStyle(fontFamily = FontFamily.Monospace),
                modifier = Modifier.fillMaxWidth(),
            )
            "bool" -> Row(verticalAlignment = Alignment.CenterVertically) {
                Switch(
                    checked = value == "true",
                    onCheckedChange = { onChange(if (it) "true" else "false") },
                    colors = SwitchDefaults.colors(checkedTrackColor = QubicColors.Accent),
                )
            }
            "file" -> FileArgInput(value, onChange, settings)
            else -> OutlinedTextField(
                value = value,
                onValueChange = onChange,
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        arg.hint?.takeIf { it.isNotEmpty() }?.let {
            Spacer(Modifier.height(2.dp))
            Text(it, color = QubicColors.TextFaint, fontSize = 10.sp)
        }
    }
}

@Composable
private fun FileArgInput(
    value: String,
    onChange: (String) -> Unit,
    settings: com.qubiccli.app.data.Settings,
) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var uploading by remember { mutableStateOf(false) }
    var uploadedName by remember { mutableStateOf<String?>(null) }
    var uploadedSize by remember { mutableLongStateOf(0L) }
    var fileError by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            fileError = null
            uploading = true
            try {
                val bytes = ctx.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: throw IllegalStateException("Could not open file")
                val name = queryDisplayName(ctx, uri) ?: "upload.bin"
                val api = Api(settings)
                val resp = api.upload(bytes, name)
                onChange(resp.path)
                uploadedName = name
                uploadedSize = resp.size
            } catch (e: Exception) {
                fileError = e.message ?: e.toString()
            } finally {
                uploading = false
            }
        }
    }

    Column(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedButton(
                onClick = { picker.launch("*/*") },
                enabled = !uploading,
                colors = ButtonDefaults.outlinedButtonColors(contentColor = QubicColors.Accent),
            ) {
                if (uploading) {
                    CircularProgressIndicator(
                        strokeWidth = 2.dp,
                        color = QubicColors.Accent,
                        modifier = Modifier.size(14.dp),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text("Uploading…")
                } else {
                    Text("Choose file…")
                }
            }
            if (value.isNotEmpty()) {
                Spacer(Modifier.width(8.dp))
                TextButton(onClick = {
                    onChange("")
                    uploadedName = null
                    uploadedSize = 0
                    fileError = null
                }) { Text("Clear", color = QubicColors.TextDim) }
            }
        }
        uploadedName?.let {
            Spacer(Modifier.height(4.dp))
            Text("$it · ${human(uploadedSize)}", color = QubicColors.Text, fontSize = 11.sp)
        }
        Spacer(Modifier.height(6.dp))
        OutlinedTextField(
            value = value,
            onValueChange = onChange,
            placeholder = {
                Text(
                    "…or type a filename (for output files)",
                    color = QubicColors.TextFaint,
                    fontSize = 11.sp,
                )
            },
            singleLine = true,
            textStyle = androidx.compose.ui.text.TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp),
            modifier = Modifier.fillMaxWidth(),
        )
        fileError?.let {
            Text(it, color = QubicColors.Danger, fontSize = 10.sp)
        }
    }
}

private fun queryDisplayName(ctx: android.content.Context, uri: Uri): String? {
    return runCatching {
        ctx.contentResolver.query(uri, null, null, null, null)?.use { c ->
            val idx = c.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && c.moveToFirst()) c.getString(idx) else null
        }
    }.getOrNull()
}

private fun human(n: Long): String {
    if (n < 1024) return "$n B"
    val kb = n / 1024.0
    if (kb < 1024) return "%.1f KB".format(kb)
    val mb = kb / 1024.0
    return "%.1f MB".format(mb)
}

@Composable
private fun ResultBlock(r: ExecResponse) {
    Card(colors = CardDefaults.cardColors(containerColor = QubicColors.Surface)) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                val ok = r.exit_code == 0
                Text(
                    if (ok) "✓ Success" else "✗ Exit ${r.exit_code}",
                    color = if (ok) QubicColors.Success else QubicColors.Danger,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.weight(1f))
                Text("${r.duration_ms} ms", color = QubicColors.TextDim, fontSize = 11.sp)
                if (r.timed_out) {
                    Spacer(Modifier.width(6.dp))
                    Badge("TIMEOUT", QubicColors.Warn)
                }
            }
            if (r.stdout.isNotEmpty()) TextBlock("stdout", r.stdout)
            if (r.stderr.isNotEmpty()) TextBlock("stderr", r.stderr)
        }
    }
}

@Composable
private fun TextBlock(label: String, text: String) {
    Column {
        Text(label.uppercase(), color = QubicColors.TextDim, fontSize = 10.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(4.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(QubicColors.Base.copy(alpha = 0.7f))
                .border(1.dp, QubicColors.Hairline, RoundedCornerShape(8.dp))
                .padding(10.dp),
        ) {
            SelectionContainer {
                Text(
                    text,
                    color = QubicColors.Text,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                )
            }
        }
    }
}

@Composable
private fun SelectionContainer(content: @Composable () -> Unit) {
    androidx.compose.foundation.text.selection.SelectionContainer { content() }
}

// Badge(...) is defined in CategoriesScreen.kt (same package).
