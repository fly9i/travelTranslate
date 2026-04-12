package com.traveltranslator.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Send
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.traveltranslator.domain.model.Destination
import com.traveltranslator.domain.model.Destinations
import com.traveltranslator.domain.model.SceneEntry
import com.traveltranslator.domain.model.Scenes

/** 首页：目的地切换 + 场景快捷入口 + 即时翻译 + 最近使用。 */
@Composable
fun HomeScreen(
    onSceneClick: (String) -> Unit,
    onDisplayText: (String, String) -> Unit,
    onOpenConversation: () -> Unit,
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        DestinationHeader(
            destination = state.destination,
            onSwitch = viewModel::switchDestination,
        )

        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            items(Scenes.all) { scene ->
                SceneCard(scene = scene, onClick = { onSceneClick(scene.category) })
            }
        }

        InputArea(
            text = state.inputText,
            onChange = viewModel::updateInput,
            onSubmit = { viewModel.translate() },
            loading = state.loading,
        )

        state.result?.let { result ->
            TranslationResultCard(
                sourceText = state.inputText,
                translatedText = result.translatedText,
                transliteration = result.transliteration,
                onDisplay = { onDisplayText(state.inputText, result.translatedText) },
            )
        }

        state.error?.let { Text("错误：$it", color = MaterialTheme.colorScheme.error) }

        TextButton(onClick = onOpenConversation) { Text("进入实时对话模式 →") }
    }
}

@Composable
private fun DestinationHeader(destination: Destination, onSwitch: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = "${destination.flag} ${destination.name}",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
        )
        TextButton(onClick = onSwitch) { Text("切换目的地") }
    }
}

@Composable
private fun SceneCard(scene: SceneEntry, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f),
        onClick = onClick,
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(text = scene.icon, fontSize = 36.sp)
            Spacer(Modifier.height(4.dp))
            Text(text = scene.label)
        }
    }
}

@Composable
private fun InputArea(
    text: String,
    onChange: (String) -> Unit,
    onSubmit: () -> Unit,
    loading: Boolean,
) {
    Column {
        OutlinedTextField(
            value = text,
            onValueChange = onChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text("说点什么 / 输入要翻译的内容…") },
            trailingIcon = {
                IconButton(onClick = { /* TODO: ASR */ }) {
                    Icon(Icons.Default.Mic, contentDescription = "语音")
                }
            },
        )
        Spacer(Modifier.height(8.dp))
        Button(
            onClick = onSubmit,
            enabled = !loading && text.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (loading) {
                CircularProgressIndicator(modifier = Modifier.height(20.dp))
            } else {
                Icon(Icons.Default.Send, contentDescription = null)
                Spacer(Modifier.height(0.dp))
                Text("  翻译")
            }
        }
    }
}

@Composable
private fun TranslationResultCard(
    sourceText: String,
    translatedText: String,
    transliteration: String?,
    onDisplay: () -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = sourceText, style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.height(8.dp))
            Text(
                text = translatedText,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            transliteration?.let {
                Spacer(Modifier.height(4.dp))
                Text(text = it, style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(8.dp))
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
                Button(onClick = onDisplay) { Text("📺 展示给对方") }
            }
        }
    }
}
