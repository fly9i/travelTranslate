package com.traveltranslator.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.traveltranslator.data.local.dao.FavoriteDao
import com.traveltranslator.data.local.dao.PhraseDao
import com.traveltranslator.data.local.entity.FavoriteEntity
import com.traveltranslator.data.local.entity.PhraseEntity

/** Room 数据库。 */
@Database(
    entities = [PhraseEntity::class, FavoriteEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun phraseDao(): PhraseDao
    abstract fun favoriteDao(): FavoriteDao
}
