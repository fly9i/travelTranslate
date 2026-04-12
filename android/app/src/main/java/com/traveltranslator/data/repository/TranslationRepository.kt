package com.traveltranslator.data.repository

import com.traveltranslator.data.remote.ApiService
import com.traveltranslator.data.remote.dto.TranslateRequestDto
import com.traveltranslator.domain.model.TranslationResult
import javax.inject.Inject
import javax.inject.Singleton

/** 翻译仓库。 */
@Singleton
class TranslationRepository @Inject constructor(
    private val api: ApiService,
) {
    suspend fun translate(
        sourceText: String,
        sourceLanguage: String = "zh",
        targetLanguage: String,
        context: String? = null,
    ): Result<TranslationResult> = runCatching {
        val resp = api.translate(
            TranslateRequestDto(
                sourceText = sourceText,
                sourceLanguage = sourceLanguage,
                targetLanguage = targetLanguage,
                context = context,
            )
        )
        TranslationResult(
            translatedText = resp.translatedText,
            transliteration = resp.transliteration,
            confidence = resp.confidence,
            engine = resp.engine,
            cached = resp.cached,
        )
    }
}
