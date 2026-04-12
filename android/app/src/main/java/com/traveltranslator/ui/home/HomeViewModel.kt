package com.traveltranslator.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.traveltranslator.data.repository.TranslationRepository
import com.traveltranslator.domain.model.Destination
import com.traveltranslator.domain.model.Destinations
import com.traveltranslator.domain.model.TranslationResult
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/** 首页 UI 状态。 */
data class HomeUiState(
    val destination: Destination = Destinations.all.first(),
    val inputText: String = "",
    val loading: Boolean = false,
    val result: TranslationResult? = null,
    val error: String? = null,
)

/** 首页 ViewModel。 */
@HiltViewModel
class HomeViewModel @Inject constructor(
    private val translationRepository: TranslationRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(HomeUiState())
    val state: StateFlow<HomeUiState> = _state.asStateFlow()

    fun updateInput(text: String) {
        _state.update { it.copy(inputText = text) }
    }

    fun switchDestination() {
        val current = _state.value.destination
        val next = Destinations.all
            .let { list -> list[(list.indexOf(current) + 1) % list.size] }
        _state.update { it.copy(destination = next, result = null) }
    }

    fun translate() {
        val current = _state.value
        if (current.inputText.isBlank()) return
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val result = translationRepository.translate(
                sourceText = current.inputText,
                targetLanguage = current.destination.language,
            )
            _state.update { state ->
                result.fold(
                    onSuccess = { state.copy(loading = false, result = it, error = null) },
                    onFailure = { state.copy(loading = false, error = it.message ?: "网络错误") },
                )
            }
        }
    }
}
