package com.traveltranslator.ui.scene

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.traveltranslator.data.local.entity.PhraseEntity
import com.traveltranslator.data.repository.PhraseRepository
import com.traveltranslator.domain.model.Scenes
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** 场景详情 UI 状态。 */
data class SceneDetailState(
    val title: String = "",
    val phrases: List<PhraseEntity> = emptyList(),
)

/** 场景详情 ViewModel（当前固定加载 ja 语言，后续可跟全局目的地联动）。 */
@HiltViewModel
class SceneDetailViewModel @Inject constructor(
    private val repository: PhraseRepository,
) : ViewModel() {

    private val currentLanguage = "ja"

    init {
        viewModelScope.launch { repository.syncPackage(currentLanguage) }
    }

    fun stateFor(category: String): StateFlow<SceneDetailState> {
        val scene = Scenes.all.firstOrNull { it.category == category }
        val title = scene?.let { "${it.icon} ${it.label}常用" } ?: category
        return repository.observe(currentLanguage, category)
            .map { list -> SceneDetailState(title = title, phrases = list) }
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = SceneDetailState(title = title),
            )
    }

    private val _trigger = MutableStateFlow(0)
}
