package com.traveltranslator.domain.model

/** 翻译结果领域模型。 */
data class TranslationResult(
    val translatedText: String,
    val transliteration: String?,
    val confidence: Double,
    val engine: String,
    val cached: Boolean,
)

/** 目的地（UI 层用）。 */
data class Destination(
    val code: String,
    val language: String,
    val flag: String,
    val name: String,
)

/** 场景入口。 */
data class SceneEntry(
    val category: String,
    val icon: String,
    val label: String,
)

/** 内置目的地列表。 */
object Destinations {
    val all: List<Destination> = listOf(
        Destination("JP", "ja", "🇯🇵", "东京"),
        Destination("KR", "ko", "🇰🇷", "首尔"),
        Destination("US", "en", "🇺🇸", "美国"),
        Destination("TH", "th", "🇹🇭", "曼谷"),
        Destination("FR", "fr", "🇫🇷", "巴黎"),
        Destination("DE", "de", "🇩🇪", "柏林"),
    )
}

/** 内置场景入口。 */
object Scenes {
    val all: List<SceneEntry> = listOf(
        SceneEntry("restaurant", "🍜", "餐厅"),
        SceneEntry("transport", "🚃", "交通"),
        SceneEntry("hotel", "🏨", "酒店"),
        SceneEntry("shopping", "🛍️", "购物"),
        SceneEntry("emergency", "🚨", "急救"),
        SceneEntry("direction", "🗺️", "问路"),
    )
}
