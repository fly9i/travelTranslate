package com.traveltranslator.ui.conversation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

/** 实时对话模式（简化版：支持文字输入 + 左右气泡）。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConversationScreen(onBack: () -> Unit, viewModel: ConversationViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("实时对话 🇨🇳 ↔ 🇯🇵") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(12.dp)) {
            LazyColumn(
                modifier = Modifier.weight(1f).fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(state.messages) { msg ->
                    MessageBubble(
                        isUser = msg.speaker == "user",
                        source = msg.sourceText,
                        translated = msg.translatedText,
                    )
                }
            }
            state.error?.let {
                Text("错误：$it", color = MaterialTheme.colorScheme.error)
            }
            Spacer(Modifier.height(8.dp))
            InputRow(
                text = state.input,
                onChange = viewModel::updateInput,
                speaker = state.speaker,
                onSwitchSpeaker = viewModel::switchSpeaker,
                onSend = viewModel::send,
                loading = state.loading,
            )
        }
    }
}

@Composable
private fun MessageBubble(isUser: Boolean, source: String, translated: String) {
    val align = if (isUser) Alignment.CenterStart else Alignment.CenterEnd
    val background = if (isUser) MaterialTheme.colorScheme.surfaceVariant
    else MaterialTheme.colorScheme.primaryContainer
    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = align) {
        Column(
            modifier = Modifier
                .background(background, RoundedCornerShape(12.dp))
                .padding(12.dp),
        ) {
            Text(
                text = if (isUser) "🧑 你" else "👤 对方",
                style = MaterialTheme.typography.labelSmall,
            )
            Spacer(Modifier.height(4.dp))
            Text(text = source)
            Spacer(Modifier.height(4.dp))
            Text(
                text = translated,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

@Composable
private fun InputRow(
    text: String,
    onChange: (String) -> Unit,
    speaker: String,
    onSwitchSpeaker: () -> Unit,
    onSend: () -> Unit,
    loading: Boolean,
) {
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = text,
                onValueChange = onChange,
                modifier = Modifier.weight(1f),
                placeholder = {
                    Text(if (speaker == "user") "我说中文…" else "对方说日文…")
                },
            )
            Spacer(Modifier.height(0.dp))
            Button(onClick = onSend, enabled = !loading && text.isNotBlank()) {
                Text("发送")
            }
        }
        Spacer(Modifier.height(4.dp))
        Button(onClick = onSwitchSpeaker, modifier = Modifier.fillMaxWidth()) {
            Text(if (speaker == "user") "🔄 切换到对方说话" else "🔄 切换回我说话")
        }
    }
}
