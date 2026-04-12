package com.traveltranslator.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 翻译请求 DTO。 */
@Serializable
data class TranslateRequestDto(
    @SerialName("source_text") val sourceText: String,
    @SerialName("source_language") val sourceLanguage: String = "zh",
    @SerialName("target_language") val targetLanguage: String,
    @SerialName("context") val context: String? = null,
    @SerialName("conversation_id") val conversationId: String? = null,
)

/** 翻译响应 DTO。 */
@Serializable
data class TranslateResponseDto(
    @SerialName("translated_text") val translatedText: String,
    @SerialName("transliteration") val transliteration: String? = null,
    @SerialName("confidence") val confidence: Double = 1.0,
    @SerialName("engine") val engine: String = "mock",
    @SerialName("cached") val cached: Boolean = false,
)
