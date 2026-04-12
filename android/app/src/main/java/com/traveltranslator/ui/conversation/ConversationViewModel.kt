package com.traveltranslator.ui.conversation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.traveltranslator.data.remote.ApiService
import com.traveltranslator.data.remote.dto.CreateConversationDto
import com.traveltranslator.data.remote.dto.MessageDto
import com.traveltranslator.data.remote.dto.SendMessageDto
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/** 对话 UI 状态。 */
data class ConversationUiState(
    val conversationId: String? = null,
    val messages: List<MessageDto> = emptyList(),
    val input: String = "",
    val speaker: String = "user",
    val loading: Boolean = false,
    val error: String? = null,
)

/** 对话 ViewModel。 */
@HiltViewModel
class ConversationViewModel @Inject constructor(
    private val api: ApiService,
) : ViewModel() {

    private val _state = MutableStateFlow(ConversationUiState())
    val state: StateFlow<ConversationUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            runCatching {
                api.createConversation(
                    CreateConversationDto(
                        destination = "东京",
                        sourceLanguage = "zh",
                        targetLanguage = "ja",
                    )
                )
            }.onSuccess { conv ->
                _state.update { it.copy(conversationId = conv.id) }
            }.onFailure { e ->
                _state.update { it.copy(error = e.message) }
            }
        }
    }

    fun updateInput(text: String) = _state.update { it.copy(input = text) }

    fun switchSpeaker() = _state.update {
        it.copy(speaker = if (it.speaker == "user") "counterpart" else "user")
    }

    fun send() {
        val snapshot = _state.value
        val convId = snapshot.conversationId ?: return
        if (snapshot.input.isBlank()) return
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            runCatching {
                api.sendMessage(
                    conversationId = convId,
                    body = SendMessageDto(
                        speaker = snapshot.speaker,
                        sourceText = snapshot.input,
                        inputType = "text",
                    ),
                )
            }.onSuccess { msg ->
                _state.update {
                    it.copy(
                        loading = false,
                        input = "",
                        messages = it.messages + msg,
                    )
                }
            }.onFailure { e ->
                _state.update { it.copy(loading = false, error = e.message) }
            }
        }
    }
}
