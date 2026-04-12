package com.traveltranslator.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.traveltranslator.data.local.entity.PhraseEntity
import kotlinx.coroutines.flow.Flow

/** 本地短语 DAO。 */
@Dao
interface PhraseDao {

    @Query("SELECT * FROM local_scene_phrases WHERE targetLanguage = :lang ORDER BY priority DESC")
    fun flowByLanguage(lang: String): Flow<List<PhraseEntity>>

    @Query(
        "SELECT * FROM local_scene_phrases " +
            "WHERE targetLanguage = :lang AND sceneCategory = :category ORDER BY priority DESC"
    )
    fun flowByCategory(lang: String, category: String): Flow<List<PhraseEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(phrases: List<PhraseEntity>)

    @Query("DELETE FROM local_scene_phrases WHERE targetLanguage = :lang AND isCustom = 0")
    suspend fun clearPreset(lang: String)

    @Query("SELECT COUNT(*) FROM local_scene_phrases WHERE targetLanguage = :lang")
    suspend fun countByLanguage(lang: String): Int
}
