package com.traveltranslator.ui.favorites

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.traveltranslator.data.local.entity.FavoriteEntity
import com.traveltranslator.data.repository.FavoriteRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

/** 收藏 ViewModel。 */
@HiltViewModel
class FavoritesViewModel @Inject constructor(
    private val repository: FavoriteRepository,
) : ViewModel() {

    val favorites: StateFlow<List<FavoriteEntity>> = repository.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
}
