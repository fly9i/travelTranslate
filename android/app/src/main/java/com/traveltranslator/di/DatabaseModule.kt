package com.traveltranslator.di

import android.content.Context
import androidx.room.Room
import com.traveltranslator.data.local.AppDatabase
import com.traveltranslator.data.local.dao.FavoriteDao
import com.traveltranslator.data.local.dao.PhraseDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/** 数据库依赖注入。 */
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "traveltranslator.db")
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    fun providePhraseDao(db: AppDatabase): PhraseDao = db.phraseDao()

    @Provides
    fun provideFavoriteDao(db: AppDatabase): FavoriteDao = db.favoriteDao()
}
