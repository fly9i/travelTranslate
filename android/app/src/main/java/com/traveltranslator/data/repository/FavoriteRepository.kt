package com.traveltranslator.data.repository

import com.traveltranslator.data.local.dao.FavoriteDao
import com.traveltranslator.data.local.entity.FavoriteEntity
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

/** 收藏仓库（本地优先）。 */
@Singleton
class FavoriteRepository @Inject constructor(
    private val dao: FavoriteDao,
) {
    fun observeAll(): Flow<List<FavoriteEntity>> = dao.flowAll()

    suspend fun add(entity: FavoriteEntity) = dao.insert(entity)

    suspend fun remove(entity: FavoriteEntity) = dao.delete(entity)
}
