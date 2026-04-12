"""翻译服务：按配置路由到 mock 字典 / Claude API。"""

import logging
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.models.translation_cache import TranslationCache

logger = logging.getLogger(__name__)


@dataclass
class TranslationResult:
    """翻译结果。"""

    translated_text: str
    transliteration: str | None
    confidence: float
    engine: str
    cached: bool


# 兜底字典：无网络/无 API Key 时提供最小可用翻译
FALLBACK_DICT: dict[str, dict[str, tuple[str, str | None]]] = {
    "zh->ja": {
        "你好": ("こんにちは", "konnichiwa"),
        "谢谢": ("ありがとう", "arigatou"),
        "请给我菜单": ("メニューをください", "menyuu wo kudasai"),
        "请给我看菜单": ("メニューを見せてください", "menyuu wo misete kudasai"),
        "洗手间在哪里": ("トイレはどこですか", "toire wa doko desu ka"),
        "多少钱": ("いくらですか", "ikura desu ka"),
        "可以刷卡吗": ("カードは使えますか", "kaado wa tsukaemasu ka"),
    },
    "zh->en": {
        "你好": ("Hello", None),
        "谢谢": ("Thank you", None),
        "请给我菜单": ("May I have the menu please?", None),
        "洗手间在哪里": ("Where is the restroom?", None),
        "多少钱": ("How much is it?", None),
    },
    "zh->ko": {
        "你好": ("안녕하세요", "annyeonghaseyo"),
        "谢谢": ("감사합니다", "gamsahamnida"),
        "洗手间在哪里": ("화장실이 어디에 있어요", "hwajangsil-i eodie isseoyo"),
    },
}


class TranslationService:
    """翻译服务。"""

    def __init__(self, db: AsyncSession, settings: Settings | None = None) -> None:
        self.db = db
        self.settings = settings or get_settings()

    async def translate(
        self,
        source_text: str,
        source_language: str,
        target_language: str,
        context: str | None = None,
    ) -> TranslationResult:
        """翻译入口：先查缓存，再调引擎，最后兜底。"""
        # 1) 缓存查询
        cached = await self._get_cached(source_text, source_language, target_language)
        if cached is not None:
            logger.info("translation cache hit: %s -> %s", source_language, target_language)
            return TranslationResult(
                translated_text=cached.translated_text,
                transliteration=cached.transliteration,
                confidence=1.0,
                engine=cached.engine,
                cached=True,
            )

        # 2) 按配置选择引擎
        engine = self.settings.translation_engine.lower()
        try:
            if engine == "anthropic" and self.settings.anthropic_api_key:
                result = await self._translate_with_anthropic(
                    source_text, source_language, target_language, context
                )
            elif engine == "openai" and self.settings.openai_api_key:
                result = await self._translate_with_openai(
                    source_text, source_language, target_language, context
                )
            else:
                result = self._translate_with_fallback(
                    source_text, source_language, target_language
                )
        except Exception as exc:  # pragma: no cover - 降级路径
            logger.exception("translation engine failed, fallback: %s", exc)
            result = self._translate_with_fallback(
                source_text, source_language, target_language
            )

        # 3) 写入缓存
        await self._save_cache(
            source_text=source_text,
            source_language=source_language,
            target_language=target_language,
            result=result,
        )
        return result

    async def _get_cached(
        self, source_text: str, source_language: str, target_language: str
    ) -> TranslationCache | None:
        """查询缓存。"""
        try:
            stmt = select(TranslationCache).where(
                TranslationCache.source_text == source_text,
                TranslationCache.source_language == source_language,
                TranslationCache.target_language == target_language,
            )
            result = await self.db.execute(stmt)
            row = result.scalar_one_or_none()
            if row is not None:
                row.hit_count += 1
                await self.db.commit()
            return row
        except SQLAlchemyError as exc:
            logger.error("cache lookup failed: %s", exc)
            await self.db.rollback()
            return None

    async def _save_cache(
        self,
        source_text: str,
        source_language: str,
        target_language: str,
        result: TranslationResult,
    ) -> None:
        """保存缓存。"""
        try:
            entry = TranslationCache(
                source_text=source_text,
                source_language=source_language,
                target_language=target_language,
                translated_text=result.translated_text,
                transliteration=result.transliteration,
                engine=result.engine,
            )
            self.db.add(entry)
            await self.db.commit()
        except SQLAlchemyError as exc:
            logger.error("cache save failed: %s", exc)
            await self.db.rollback()

    def _translate_with_fallback(
        self, source_text: str, source_language: str, target_language: str
    ) -> TranslationResult:
        """使用内置字典兜底翻译。"""
        key = f"{source_language}->{target_language}"
        entry = FALLBACK_DICT.get(key, {}).get(source_text.strip())
        if entry:
            translated, transliteration = entry
            return TranslationResult(
                translated_text=translated,
                transliteration=transliteration,
                confidence=0.6,
                engine="mock",
                cached=False,
            )
        # 最终兜底：返回原文 + 标记
        return TranslationResult(
            translated_text=f"[{target_language}] {source_text}",
            transliteration=None,
            confidence=0.3,
            engine="mock",
            cached=False,
        )

    async def _translate_with_anthropic(
        self,
        source_text: str,
        source_language: str,
        target_language: str,
        context: str | None,
    ) -> TranslationResult:
        """调用 Claude API 翻译。"""
        try:
            from anthropic import AsyncAnthropic
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("anthropic SDK 未安装") from exc

        client = AsyncAnthropic(api_key=self.settings.anthropic_api_key)
        prompt = self._build_prompt(source_text, source_language, target_language, context)
        message = await client.messages.create(
            model=self.settings.anthropic_model,
            max_tokens=256,
            messages=[{"role": "user", "content": prompt}],
        )
        translated = "".join(
            block.text for block in message.content if getattr(block, "type", "") == "text"
        ).strip()
        if not translated:
            raise RuntimeError("Claude 返回空译文")
        return TranslationResult(
            translated_text=translated,
            transliteration=None,
            confidence=0.95,
            engine="anthropic",
            cached=False,
        )

    async def _translate_with_openai(
        self,
        source_text: str,
        source_language: str,
        target_language: str,
        context: str | None,
    ) -> TranslationResult:
        """调用 OpenAI 兼容接口翻译（支持 OpenAI / DeepSeek / 通义 / Ollama 等）。"""
        try:
            from openai import AsyncOpenAI
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("openai SDK 未安装") from exc

        client = AsyncOpenAI(
            api_key=self.settings.openai_api_key,
            base_url=self.settings.openai_base_url,
        )
        prompt = self._build_prompt(source_text, source_language, target_language, context)
        completion = await client.chat.completions.create(
            model=self.settings.openai_model,
            max_tokens=256,
            messages=[{"role": "user", "content": prompt}],
        )
        translated = (completion.choices[0].message.content or "").strip()
        if not translated:
            raise RuntimeError("OpenAI 兼容接口返回空译文")
        return TranslationResult(
            translated_text=translated,
            transliteration=None,
            confidence=0.95,
            engine="openai",
            cached=False,
        )

    @staticmethod
    def _build_prompt(
        source_text: str,
        source_language: str,
        target_language: str,
        context: str | None,
    ) -> str:
        """构造翻译提示词。"""
        scene_hint = f"场景：{context}。" if context else ""
        return (
            f"你是一名旅行翻译助手。{scene_hint}"
            f"请把下面这段 {source_language} 文本翻译成 {target_language}，"
            "要求口语化、简洁、礼貌，便于在当地与人沟通。"
            "只输出译文本身，不要附加解释或标点强调。\n\n"
            f"原文：{source_text}"
        )
