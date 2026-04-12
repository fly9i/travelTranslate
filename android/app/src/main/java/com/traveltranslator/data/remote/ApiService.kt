package com.traveltranslator.data.remote

import com.traveltranslator.data.remote.dto.ConversationDto
import com.traveltranslator.data.remote.dto.CreateConversationDto
import com.traveltranslator.data.remote.dto.MessageDto
import com.traveltranslator.data.remote.dto.PhrasePackageDto
import com.traveltranslator.data.remote.dto.SendMessageDto
import com.traveltranslator.data.remote.dto.TranslateRequestDto
import com.traveltranslator.data.remote.dto.TranslateResponseDto
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

/** 后端 REST API 接口定义。 */
interface ApiService {

    @POST("api/v1/translate")
    suspend fun translate(@Body body: TranslateRequestDto): TranslateResponseDto

    @GET("api/v1/phrases/packages/{language}")
    suspend fun getPhrasePackage(
        @Path("language") language: String,
        @Query("category") category: String? = null,
    ): PhrasePackageDto

    @POST("api/v1/conversations")
    suspend fun createConversation(@Body body: CreateConversationDto): ConversationDto

    @POST("api/v1/conversations/{id}/messages")
    suspend fun sendMessage(
        @Path("id") conversationId: String,
        @Body body: SendMessageDto,
    ): MessageDto
}
