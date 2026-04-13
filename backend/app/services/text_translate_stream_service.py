"""文本翻译的流式服务：把 LLM 生成的 token 通过 SSE 推给前端。

不写缓存、不查缓存——即时翻译输入框只想要最快的反馈。
"""

from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import AsyncIterator

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)


class TextTranslateStreamService:
    """按 TRANSLATION_ENGINE 路由的流式文本翻译服务。"""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    async def stream(
        self,
        source_text: str,
        source_language: str,
        target_language: str,
        polish: bool,
        context: str | None,
    ) -> AsyncIterator[bytes]:
        """产出 SSE 字节流。事件：status / delta / final / error。"""
        logger.info(
            "text translate stream start: source=%s target=%s polish=%s len=%d text=%r",
            source_language,
            target_language,
            polish,
            len(source_text),
            source_text[:80],
        )
        if not source_text.strip():
            logger.warning("text translate stream: 原文为空")
            yield self._sse("error", {"message": "原文为空"})
            return

        yield self._sse("status", {"message": "连接模型…"})

        engine = self.settings.translation_engine.lower()
        logger.info("text translate engine=%s", engine)
        try:
            if engine == "anthropic" and self.settings.anthropic_api_key:
                async for chunk in self._stream_anthropic(
                    source_text, source_language, target_language, polish, context
                ):
                    yield chunk
                return
            if engine == "openai" and self.settings.openai_api_key:
                async for chunk in self._stream_openai(
                    source_text, source_language, target_language, polish, context
                ):
                    yield chunk
                return
        except Exception as exc:  # noqa: BLE001
            logger.exception("text translate stream failed: %s", exc)
            yield self._sse("error", {"message": f"翻译失败：{exc}"})
            return

        # 兜底：没配置 LLM 时直接返回一个 final，保持前端协议一致
        yield self._sse(
            "final",
            {
                "translated_text": f"[{target_language}] {source_text}",
                "cultural_note": None,
                "engine": "mock",
            },
        )

    @staticmethod
    def _sse(event: str, data: dict) -> bytes:
        payload = json.dumps(data, ensure_ascii=False)
        return f"event: {event}\ndata: {payload}\n\n".encode("utf-8")

    @staticmethod
    def _build_prompt(
        source_text: str,
        source_language: str,
        target_language: str,
        polish: bool,
        context: str | None,
    ) -> str:
        scene_hint = f"场景：{context}。" if context else ""
        if polish:
            return (
                f"你是一名资深的跨文化旅行翻译助手。{scene_hint}"
                f"把下面这段 {source_language} 文本翻译到 {target_language}，"
                "要求：\n"
                "1) 符合当地语用习惯（敬语等级、地道说法、避免直译尴尬）；\n"
                "2) 如有需要注意的文化/礼仪差异，用中文写一条简短提醒；\n"
                "3) 严格按 JSON 输出，不要任何额外文字或 Markdown：\n"
                '{"translated_text": "...", "cultural_note": "..."}'
                "\n4) 若无文化提醒，cultural_note 填空字符串。\n\n"
                f"原文：{source_text}"
            )
        return (
            f"你是一名旅行翻译助手。{scene_hint}"
            f"把下面这段 {source_language} 文本翻译成 {target_language}，"
            "口语化、简洁、礼貌。只输出译文本身，不要解释。\n\n"
            f"原文：{source_text}"
        )

    async def _stream_anthropic(
        self,
        source_text: str,
        source_language: str,
        target_language: str,
        polish: bool,
        context: str | None,
    ) -> AsyncIterator[bytes]:
        try:
            from anthropic import AsyncAnthropic
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("anthropic SDK 未安装") from exc

        client = AsyncAnthropic(api_key=self.settings.anthropic_api_key)
        prompt = self._build_prompt(
            source_text, source_language, target_language, polish, context
        )
        logger.info(
            "anthropic text request: model=%s prompt_len=%d",
            self.settings.anthropic_model,
            len(prompt),
        )
        logger.debug("anthropic text prompt:\n%s", prompt)

        accumulated = ""
        chunk_count = 0
        async with client.messages.stream(
            model=self.settings.anthropic_model,
            max_tokens=512 if polish else 256,
            messages=[{"role": "user", "content": prompt}],
        ) as stream:
            yield self._sse("status", {"message": "模型思考中…"})
            async for text in stream.text_stream:
                if not text:
                    continue
                accumulated += text
                chunk_count += 1
                yield self._sse("delta", {"text": text})
                await asyncio.sleep(0)

        logger.info(
            "anthropic text stream done: chunks=%d raw_len=%d",
            chunk_count,
            len(accumulated),
        )
        logger.debug("anthropic text raw:\n%s", accumulated)
        translated, note = self._parse(accumulated, polish)
        logger.info(
            "anthropic text final: translated=%r note=%r", translated[:120], note
        )
        yield self._sse(
            "final",
            {
                "translated_text": translated,
                "cultural_note": note,
                "engine": "anthropic",
            },
        )

    async def _stream_openai(
        self,
        source_text: str,
        source_language: str,
        target_language: str,
        polish: bool,
        context: str | None,
    ) -> AsyncIterator[bytes]:
        try:
            from openai import AsyncOpenAI
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("openai SDK 未安装") from exc

        client = AsyncOpenAI(
            api_key=self.settings.openai_api_key,
            base_url=self.settings.openai_base_url,
        )
        prompt = self._build_prompt(
            source_text, source_language, target_language, polish, context
        )
        logger.info(
            "openai text request: model=%s base_url=%s prompt_len=%d",
            self.settings.openai_model,
            self.settings.openai_base_url,
            len(prompt),
        )
        logger.debug("openai text prompt:\n%s", prompt)

        accumulated = ""
        chunk_count = 0
        stream = await client.chat.completions.create(
            model=self.settings.openai_model,
            max_tokens=512 if polish else 256,
            stream=True,
            messages=[{"role": "user", "content": prompt}],
        )
        yield self._sse("status", {"message": "模型思考中…"})
        async for chunk in stream:
            if not chunk.choices:
                continue
            delta = chunk.choices[0].delta
            text = getattr(delta, "content", None) or ""
            if not text:
                continue
            accumulated += text
            chunk_count += 1
            yield self._sse("delta", {"text": text})

        logger.info(
            "openai text stream done: chunks=%d raw_len=%d",
            chunk_count,
            len(accumulated),
        )
        logger.debug("openai text raw:\n%s", accumulated)
        translated, note = self._parse(accumulated, polish)
        logger.info(
            "openai text final: translated=%r note=%r", translated[:120], note
        )
        yield self._sse(
            "final",
            {
                "translated_text": translated,
                "cultural_note": note,
                "engine": "openai",
            },
        )

    @staticmethod
    def _parse(raw: str, polish: bool) -> tuple[str, str | None]:
        """polish 模式尝试 JSON 解析；普通模式原样返回。"""
        stripped = raw.strip()
        if not polish:
            return stripped, None
        if stripped.startswith("```"):
            stripped = stripped.strip("`")
            if stripped.lower().startswith("json"):
                stripped = stripped[4:].strip()
        try:
            data = json.loads(stripped)
            translated = str(data.get("translated_text") or "").strip()
            note_raw = data.get("cultural_note")
            note = str(note_raw).strip() if note_raw else None
            return (translated or raw.strip(), note or None)
        except (json.JSONDecodeError, AttributeError):
            return raw.strip(), None
