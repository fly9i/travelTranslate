"""翻译服务：按配置路由到 mock 字典 / Claude API。"""

import html
import json
import logging
from dataclasses import dataclass

import httpx
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
    cultural_note: str | None = None


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
        polish: bool = False,
    ) -> TranslationResult:
        """翻译入口：先查缓存，再调引擎，最后兜底。polish 模式不走缓存。"""
        if not polish:
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

        engine = self.settings.translation_engine.lower()
        try:
            if engine == "anthropic" and self.settings.anthropic_api_key:
                result = await self._translate_with_anthropic(
                    source_text, source_language, target_language, context, polish
                )
            elif engine == "openai" and self.settings.openai_api_key:
                result = await self._translate_with_openai(
                    source_text, source_language, target_language, context, polish
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

        if not polish:
            await self._save_cache(
                source_text=source_text,
                source_language=source_language,
                target_language=target_language,
                result=result,
            )
        return result

    async def translate_batch(
        self,
        source_texts: list[str],
        source_language: str,
        target_language: str,
        context: str | None = None,
    ) -> tuple[list[str], str]:
        """批量翻译：一次 LLM 调用返回多条译文。

        返回 (译文列表, 引擎名)。译文顺序与输入顺序一致；若引擎失败则逐条兜底。
        """
        if not source_texts:
            return [], "mock"

        engine = self.settings.batch_translation_engine.lower()
        if engine == "inherit":
            engine = self.settings.translation_engine.lower()

        try:
            if engine == "google" and self.settings.google_translate_api_key:
                results = await self._batch_google(
                    source_texts, source_language, target_language
                )
                return results, "google"
            if engine == "anthropic" and self.settings.anthropic_api_key:
                results = await self._batch_anthropic(
                    source_texts, source_language, target_language, context
                )
                return results, "anthropic"
            if engine == "openai" and self.settings.openai_api_key:
                results = await self._batch_openai(
                    source_texts, source_language, target_language, context
                )
                return results, "openai"
        except Exception as exc:
            logger.exception("batch translation failed, fallback per item: %s", exc)

        results = [
            self._translate_with_fallback(t, source_language, target_language).translated_text
            for t in source_texts
        ]
        return results, "mock"

    async def _batch_google(
        self,
        source_texts: list[str],
        source_language: str,
        target_language: str,
    ) -> list[str]:
        """调用 Google Cloud Translation v2 REST API 批量翻译。

        一次 POST 可带多个 q 字段，响应顺序与请求顺序一致。
        v2 比 v3 好处是不需要 Google Cloud project id，只要 API key。
        """
        url = f"{self.settings.google_translate_base_url}/language/translate/v2"
        params = {"key": self.settings.google_translate_api_key}
        data: list[tuple[str, str]] = [("q", t) for t in source_texts]
        data.append(("target", self._normalize_google_lang(target_language)))
        data.append(("format", "text"))
        if source_language and source_language.lower() != "auto":
            data.append(("source", self._normalize_google_lang(source_language)))

        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(url, params=params, data=data)
        if resp.status_code != 200:
            logger.error(
                "google translate failed: status=%s body=%s", resp.status_code, resp.text
            )
            raise RuntimeError(f"google translate http {resp.status_code}")

        payload = resp.json()
        items = (payload.get("data") or {}).get("translations") or []
        if len(items) != len(source_texts):
            logger.warning(
                "google translate item count mismatch: got %d expected %d",
                len(items),
                len(source_texts),
            )
        results: list[str] = []
        for idx, original in enumerate(source_texts):
            if idx < len(items):
                translated = items[idx].get("translatedText") or ""
                # Google 返回的 translatedText 会 HTML 转义 & ' " 等字符，解回来
                results.append(html.unescape(translated) if translated else original)
            else:
                results.append(original)
        return results

    @staticmethod
    def _normalize_google_lang(code: str) -> str:
        """把项目里的语言码映射到 Google Translate 支持的 BCP-47 代码。"""
        mapping = {
            "zh": "zh-CN",
            "zh-hans": "zh-CN",
            "zh-hant": "zh-TW",
            "jp": "ja",
            "kr": "ko",
        }
        return mapping.get(code.lower(), code)

    async def _batch_anthropic(
        self,
        source_texts: list[str],
        source_language: str,
        target_language: str,
        context: str | None,
    ) -> list[str]:
        """调用 Claude 批量翻译。"""
        try:
            from anthropic import AsyncAnthropic
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("anthropic SDK 未安装") from exc

        client = AsyncAnthropic(api_key=self.settings.anthropic_api_key)
        prompt = self._build_batch_prompt(
            source_texts, source_language, target_language, context
        )
        message = await client.messages.create(
            model=self.settings.anthropic_model,
            max_tokens=max(512, 64 * len(source_texts)),
            messages=[{"role": "user", "content": prompt}],
        )
        raw = "".join(
            block.text for block in message.content if getattr(block, "type", "") == "text"
        ).strip()
        return self._parse_batch_output(raw, len(source_texts), source_texts)

    async def _batch_openai(
        self,
        source_texts: list[str],
        source_language: str,
        target_language: str,
        context: str | None,
    ) -> list[str]:
        """调用 OpenAI 兼容接口批量翻译。"""
        try:
            from openai import AsyncOpenAI
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("openai SDK 未安装") from exc

        client = AsyncOpenAI(
            api_key=self.settings.openai_api_key,
            base_url=self.settings.openai_base_url,
        )
        prompt = self._build_batch_prompt(
            source_texts, source_language, target_language, context
        )
        completion = await client.chat.completions.create(
            model=self.settings.openai_model,
            max_tokens=max(512, 64 * len(source_texts)),
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
        )
        raw = (completion.choices[0].message.content or "").strip()
        return self._parse_batch_output(raw, len(source_texts), source_texts)

    @staticmethod
    def _build_batch_prompt(
        source_texts: list[str],
        source_language: str,
        target_language: str,
        context: str | None,
    ) -> str:
        """构造批量翻译 prompt。要求模型输出严格 JSON 对象。"""
        scene_hint = f"场景：{context}。" if context else ""
        numbered = "\n".join(f"{i + 1}. {t}" for i, t in enumerate(source_texts))
        return (
            f"你是一名旅行翻译助手。{scene_hint}"
            f"请把下列编号文本从 {source_language} 翻译成 {target_language}，"
            "要求口语化、简洁、贴近实际语境。\n"
            "严格按 JSON 输出，不要任何额外文字或 Markdown：\n"
            '{"translations": [{"id": 1, "text": "..."}, ...]}\n'
            "必须保持 id 与输入编号一一对应，数量一致。\n\n"
            f"原文：\n{numbered}"
        )

    @staticmethod
    def _parse_batch_output(
        raw: str, expected: int, source_texts: list[str]
    ) -> list[str]:
        """解析批量翻译的 JSON 输出，缺失位置用原文兜底。"""
        stripped = raw.strip()
        if stripped.startswith("```"):
            stripped = stripped.strip("`")
            if stripped.lower().startswith("json"):
                stripped = stripped[4:].strip()
        try:
            data = json.loads(stripped)
        except json.JSONDecodeError:
            logger.warning("批量翻译 JSON 解析失败，回退原文")
            return list(source_texts)

        items = data.get("translations") if isinstance(data, dict) else None
        if not isinstance(items, list):
            return list(source_texts)

        result = list(source_texts)
        for item in items:
            if not isinstance(item, dict):
                continue
            idx_raw = item.get("id")
            text = item.get("text")
            try:
                idx = int(idx_raw) - 1
            except (TypeError, ValueError):
                continue
            if 0 <= idx < expected and isinstance(text, str) and text.strip():
                result[idx] = text.strip()
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
        polish: bool,
    ) -> TranslationResult:
        """调用 Claude API 翻译。"""
        try:
            from anthropic import AsyncAnthropic
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("anthropic SDK 未安装") from exc

        client = AsyncAnthropic(api_key=self.settings.anthropic_api_key)
        prompt = self._build_prompt(source_text, source_language, target_language, context, polish)
        message = await client.messages.create(
            model=self.settings.anthropic_model,
            max_tokens=512 if polish else 256,
            messages=[{"role": "user", "content": prompt}],
        )
        raw = "".join(
            block.text for block in message.content if getattr(block, "type", "") == "text"
        ).strip()
        if not raw:
            raise RuntimeError("Claude 返回空译文")
        translated, note = self._parse_llm_output(raw, polish)
        return TranslationResult(
            translated_text=translated,
            transliteration=None,
            confidence=0.95,
            engine="anthropic",
            cached=False,
            cultural_note=note,
        )

    async def _translate_with_openai(
        self,
        source_text: str,
        source_language: str,
        target_language: str,
        context: str | None,
        polish: bool,
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
        prompt = self._build_prompt(source_text, source_language, target_language, context, polish)
        completion = await client.chat.completions.create(
            model=self.settings.openai_model,
            max_tokens=512 if polish else 256,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"} if polish else None,
        )
        raw = (completion.choices[0].message.content or "").strip()
        if not raw:
            raise RuntimeError("OpenAI 兼容接口返回空译文")
        translated, note = self._parse_llm_output(raw, polish)
        return TranslationResult(
            translated_text=translated,
            transliteration=None,
            confidence=0.95,
            engine="openai",
            cached=False,
            cultural_note=note,
        )

    @staticmethod
    def _build_prompt(
        source_text: str,
        source_language: str,
        target_language: str,
        context: str | None,
        polish: bool,
    ) -> str:
        """构造翻译提示词。"""
        scene_hint = f"场景：{context}。" if context else ""
        if polish:
            return (
                f"你是一名资深的跨文化旅行翻译助手。{scene_hint}"
                f"把下面这段 {source_language} 文本翻译到 {target_language}，"
                "要求：\n"
                "1) 译文要符合当地语用习惯（敬语等级、地道说法、避免直译尴尬）；\n"
                "2) 如果存在中国游客需要注意的文化/礼仪/习惯差异，用中文写一条简短提醒；\n"
                "3) 严格按 JSON 输出，不要加任何额外文字或 Markdown 代码块：\n"
                '{"translated_text": "...", "cultural_note": "..."}'
                "\n4) 若无文化提醒，cultural_note 填空字符串。\n\n"
                f"原文：{source_text}"
            )
        return (
            f"你是一名旅行翻译助手。{scene_hint}"
            f"请把下面这段 {source_language} 文本翻译成 {target_language}，"
            "要求口语化、简洁、礼貌，便于在当地与人沟通。"
            "只输出译文本身，不要附加解释或标点强调。\n\n"
            f"原文：{source_text}"
        )

    @staticmethod
    def _parse_llm_output(raw: str, polish: bool) -> tuple[str, str | None]:
        """解析 LLM 输出。polish 模式下尝试 JSON 解析，失败则原样当译文。"""
        if not polish:
            return raw, None
        stripped = raw.strip()
        if stripped.startswith("```"):
            # 去掉 ```json ... ``` 包装
            stripped = stripped.strip("`")
            if stripped.lower().startswith("json"):
                stripped = stripped[4:].strip()
        try:
            data = json.loads(stripped)
            translated = str(data.get("translated_text", "")).strip()
            note_raw = data.get("cultural_note")
            note = str(note_raw).strip() if note_raw else None
            if not translated:
                return raw, None
            return translated, (note or None)
        except (json.JSONDecodeError, AttributeError):
            logger.warning("polish 模式 JSON 解析失败，原样返回")
            return raw, None
