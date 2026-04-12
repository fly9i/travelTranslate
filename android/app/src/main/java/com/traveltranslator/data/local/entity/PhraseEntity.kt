package com.traveltranslator.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/** 本地短语实体：离线包 + 自定义短语。 */
@Entity(tableName = "local_scene_phrases")
data class PhraseEntity(
    @PrimaryKey val id: String,
    val sceneCategory: String,
    val subcategory: String?,
    val sourceText: String,
    val targetText: String,
    val sourceLanguage: String,
    val targetLanguage: String,
    val transliteration: String?,
    val isCustom: Boolean,
    val useCount: Int,
    val priority: Int,
)
