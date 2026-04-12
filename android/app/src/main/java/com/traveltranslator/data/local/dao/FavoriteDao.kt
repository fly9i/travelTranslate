package com.traveltranslator.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import com.traveltranslator.data.local.entity.FavoriteEntity
import kotlinx.coroutines.flow.Flow

/** 收藏短语 DAO。 */
@Dao
interface FavoriteDao {

    @Query("SELECT * FROM local_favorites ORDER BY createdAt DESC")
    fun flowAll(): Flow<List<FavoriteEntity>>

    @Insert
    suspend fun insert(entity: FavoriteEntity): Long

    @Delete
    suspend fun delete(entity: FavoriteEntity)
}
