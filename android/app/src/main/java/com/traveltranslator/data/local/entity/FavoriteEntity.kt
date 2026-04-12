package com.traveltranslator.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/** 本地收藏短语。 */
@Entity(tableName = "local_favorites")
data class FavoriteEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val sourceText: String,
    val targetText: String,
    val sourceLanguage: String,
    val targetLanguage: String,
    val sceneCategory: String?,
    val createdAt: Long = System.currentTimeMillis(),
    val synced: Boolean = false,
)
