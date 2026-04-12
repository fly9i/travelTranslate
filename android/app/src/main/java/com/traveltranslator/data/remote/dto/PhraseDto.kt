package com.traveltranslator.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 短语 DTO。 */
@Serializable
data class PhraseDto(
    @SerialName("id") val id: String,
    @SerialName("scene_category") val sceneCategory: String,
    @SerialName("subcategory") val subcategory: String? = null,
    @SerialName("source_text") val sourceText: String,
    @SerialName("target_text") val targetText: String,
    @SerialName("source_language") val sourceLanguage: String = "zh",
    @SerialName("target_language") val targetLanguage: String,
    @SerialName("transliteration") val transliteration: String? = null,
    @SerialName("is_custom") val isCustom: Boolean = false,
    @SerialName("priority") val priority: Int = 0,
)

/** 短语包响应。 */
@Serializable
data class PhrasePackageDto(
    @SerialName("language") val language: String,
    @SerialName("total") val total: Int,
    @SerialName("phrases") val phrases: List<PhraseDto>,
)
