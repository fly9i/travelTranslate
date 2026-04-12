package com.traveltranslator.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 创建对话请求。 */
@Serializable
data class CreateConversationDto(
    @SerialName("destination") val destination: String? = null,
    @SerialName("source_language") val sourceLanguage: String = "zh",
    @SerialName("target_language") val targetLanguage: String,
    @SerialName("user_id") val userId: String? = null,
)

/** 对话输出。 */
@Serializable
data class ConversationDto(
    @SerialName("id") val id: String,
    @SerialName("destination") val destination: String? = null,
    @SerialName("source_language") val sourceLanguage: String,
    @SerialName("target_language") val targetLanguage: String,
    @SerialName("message_count") val messageCount: Int = 0,
)

/** 发送消息请求。 */
@Serializable
data class SendMessageDto(
    @SerialName("speaker") val speaker: String,
    @SerialName("source_text") val sourceText: String,
    @SerialName("input_type") val inputType: String = "text",
)

/** 消息输出。 */
@Serializable
data class MessageDto(
    @SerialName("id") val id: String,
    @SerialName("conversation_id") val conversationId: String,
    @SerialName("speaker") val speaker: String,
    @SerialName("source_text") val sourceText: String,
    @SerialName("translated_text") val translatedText: String,
    @SerialName("input_type") val inputType: String,
)
