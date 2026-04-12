package com.traveltranslator.data.repository

import com.traveltranslator.data.local.dao.PhraseDao
import com.traveltranslator.data.local.entity.PhraseEntity
import com.traveltranslator.data.remote.ApiService
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

/** 场景短语仓库：先读本地，必要时从后端同步离线包。 */
@Singleton
class PhraseRepository @Inject constructor(
    private val api: ApiService,
    private val dao: PhraseDao,
) {

    fun observe(language: String, category: String? = null): Flow<List<PhraseEntity>> =
        if (category == null) dao.flowByLanguage(language)
        else dao.flowByCategory(language, category)

    /** 从后端拉取并写入本地（增量替换非自定义部分）。 */
    suspend fun syncPackage(language: String): Result<Int> = runCatching {
        val pkg = api.getPhrasePackage(language)
        val entities = pkg.phrases.map {
            PhraseEntity(
                id = it.id,
                sceneCategory = it.sceneCategory,
                subcategory = it.subcategory,
                sourceText = it.sourceText,
                targetText = it.targetText,
                sourceLanguage = it.sourceLanguage,
                targetLanguage = it.targetLanguage,
                transliteration = it.transliteration,
                isCustom = it.isCustom,
                useCount = 0,
                priority = it.priority,
            )
        }
        dao.clearPreset(language)
        dao.upsertAll(entities)
        entities.size
    }
}
