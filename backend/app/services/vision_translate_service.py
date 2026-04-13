"""流式视觉翻译服务：把图片 + OCR 块交给多模态 LLM，流式返回场景说明、
  思考过程和结构化翻译项目。用 Server-Sent Events (SSE) 推给前端。"""

from __future__ import annotations

import asyncio
import base64
import json
import logging
from collections.abc import AsyncIterator
from dataclasses import dataclass

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)


@dataclass
class OCRBlockInput:
    """前端上传的 OCR 块，带图像归一化 bbox（Vision 左下原点坐标系）。"""

    index: int
    text: str


@dataclass
class VisionTranslateItem:
    """LLM 输出的一个翻译项目。"""

    ocr_indices: list[int]
    source_text: str
    translated_text: str
    note: str | None = None


@dataclass
class VisionTranslateResult:
    """最终结构化结果。"""

    scene_type: str
    summary: str
    items: list[VisionTranslateItem]
    engine: str


class VisionTranslateService:
    """流式视觉翻译服务。按 engine 路由到 anthropic / openai。"""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    async def stream(
        self,
        image_bytes: bytes,
        image_media_type: str,
        blocks: list[OCRBlockInput],
        source_language: str,
        target_language: str,
        destination: str | None,
    ) -> AsyncIterator[bytes]:
        """主入口：产出 SSE 字节流。"""
        logger.info(
            "vision translate start: image=%d bytes type=%s blocks=%d "
            "source=%s target=%s destination=%s",
            len(image_bytes),
            image_media_type,
            len(blocks),
            source_language,
            target_language,
            destination,
        )
        for b in blocks:
            logger.debug("  ocr[%d]: %s", b.index, b.text)

        yield self._sse("status", {"message": "正在读取图像…"})

        if not blocks:
            logger.warning("vision translate: 未提供 OCR 文字块")
            yield self._sse("error", {"message": "未提供 OCR 文字块"})
            return

        engine = self.settings.translation_engine.lower()
        logger.info("vision translate engine=%s model=%s", engine,
                    self.settings.anthropic_model if engine == "anthropic"
                    else self.settings.openai_model)
        try:
            if engine == "anthropic" and self.settings.anthropic_api_key:
                async for chunk in self._stream_anthropic(
                    image_bytes, image_media_type, blocks,
                    source_language, target_language, destination,
                ):
                    yield chunk
                return
            if engine == "openai" and self.settings.openai_api_key:
                async for chunk in self._stream_openai(
                    image_bytes, image_media_type, blocks,
                    source_language, target_language, destination,
                ):
                    yield chunk
                return
        except Exception as exc:  # noqa: BLE001
            logger.exception("vision translate stream failed: %s", exc)
            yield self._sse("error", {"message": f"视觉翻译失败：{exc}"})
            return

        yield self._sse(
            "error",
            {"message": "未配置可用的视觉 LLM（设置 TRANSLATION_ENGINE + API Key）"},
        )

    @staticmethod
    def _sse(event: str, data: dict) -> bytes:
        """把一条事件编码成 SSE 帧。"""
        payload = json.dumps(data, ensure_ascii=False)
        return f"event: {event}\ndata: {payload}\n\n".encode("utf-8")

    @staticmethod
    def _build_prompt(
        blocks: list[OCRBlockInput],
        source_language: str,
        target_language: str,
        destination: str | None,
    ) -> str:
        dest_hint = f"用户所在地/目的地：{destination}。" if destination else ""
        numbered = "\n".join(f"[{b.index}] {b.text}" for b in blocks)
        return (
            "你是一名旅行翻译助手。下面是用户拍摄的图片和本地 OCR 识别出的文字块，"
            f"每条带编号。{dest_hint}图中文字语言：{source_language}，目标译文语言：{target_language}。\n\n"
            "请完成三件事：\n"
            "1. 判断场景类型（menu / sign / receipt / document / ticket / other）；\n"
            "2. 在 OCR 片段里挑出用户真正关心、值得翻译的项目，忽略装饰、页眉页脚、无意义文字；\n"
            "3. 每个项目把相关的 OCR 编号合并（比如一道菜的名字和价格），给出原文和地道译文，"
            "必要时补一条简短文化提醒 / 过敏源 / 消费注意。\n\n"
            "严格按以下 JSON 输出，不要任何 Markdown 代码块或额外文字：\n"
            "{\n"
            '  "scene_type": "menu | sign | receipt | document | ticket | other",\n'
            '  "summary": "1-3 句整体说明",\n'
            '  "items": [\n'
            "    {\n"
            '      "ocr_indices": [0, 1],\n'
            '      "source_text": "合并后的完整原文",\n'
            '      "translated_text": "地道译文",\n'
            '      "note": "可选提醒，或 null"\n'
            "    }\n"
            "  ]\n"
            "}\n\n"
            "注意：ocr_indices 必须来自下面 OCR 列表里的编号，不要编造；items 顺序按图像阅读顺序。\n\n"
            f"OCR 列表（共 {len(blocks)} 条）：\n{numbered}"
        )

    async def _stream_anthropic(
        self,
        image_bytes: bytes,
        image_media_type: str,
        blocks: list[OCRBlockInput],
        source_language: str,
        target_language: str,
        destination: str | None,
    ) -> AsyncIterator[bytes]:
        try:
            from anthropic import AsyncAnthropic
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("anthropic SDK 未安装") from exc

        client = AsyncAnthropic(api_key=self.settings.anthropic_api_key)
        prompt = self._build_prompt(blocks, source_language, target_language, destination)
        b64 = base64.standard_b64encode(image_bytes).decode("ascii")
        logger.info(
            "anthropic vision request: model=%s prompt_len=%d image_b64_len=%d",
            self.settings.anthropic_model,
            len(prompt),
            len(b64),
        )
        logger.debug("anthropic prompt:\n%s", prompt)

        yield self._sse("status", {"message": "连接 Claude 视觉模型…"})

        accumulated = ""
        chunk_count = 0
        async with client.messages.stream(
            model=self.settings.anthropic_model,
            max_tokens=self.settings.max_tokens_vision,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": image_media_type,
                                "data": b64,
                            },
                        },
                        {"type": "text", "text": prompt},
                    ],
                }
            ],
        ) as stream:
            yield self._sse("status", {"message": "模型思考中…"})
            await asyncio.sleep(0)
            async for text in stream.text_stream:
                if not text:
                    continue
                accumulated += text
                chunk_count += 1
                yield self._sse("delta", {"text": text})
                await asyncio.sleep(0)

        logger.info(
            "anthropic stream done: chunks=%d raw_len=%d", chunk_count, len(accumulated)
        )
        logger.debug("anthropic raw output:\n%s", accumulated)
        yield self._sse("status", {"message": "正在解析结果…"})
        result = self._parse(accumulated, engine="anthropic")
        logger.info(
            "vision translate parsed: scene=%s items=%d summary=%r",
            result.scene_type,
            len(result.items),
            result.summary[:80],
        )
        for i, item in enumerate(result.items):
            logger.info(
                "  item[%d] indices=%s src=%r -> tgt=%r note=%r",
                i,
                item.ocr_indices,
                item.source_text[:60],
                item.translated_text[:60],
                (item.note or "")[:60],
            )
        yield self._sse("final", self._result_to_dict(result))

    async def _stream_openai(
        self,
        image_bytes: bytes,
        image_media_type: str,
        blocks: list[OCRBlockInput],
        source_language: str,
        target_language: str,
        destination: str | None,
    ) -> AsyncIterator[bytes]:
        try:
            from openai import AsyncOpenAI
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("openai SDK 未安装") from exc

        client = AsyncOpenAI(
            api_key=self.settings.openai_api_key,
            base_url=self.settings.openai_base_url,
        )
        prompt = self._build_prompt(blocks, source_language, target_language, destination)
        b64 = base64.standard_b64encode(image_bytes).decode("ascii")
        data_url = f"data:{image_media_type};base64,{b64}"
        logger.info(
            "openai vision request: model=%s base_url=%s prompt_len=%d image_b64_len=%d",
            self.settings.openai_model,
            self.settings.openai_base_url,
            len(prompt),
            len(b64),
        )
        logger.debug("openai prompt:\n%s", prompt)

        yield self._sse("status", {"message": "连接视觉模型…"})

        accumulated = ""
        chunk_count = 0
        kwargs: dict = {
            "model": self.settings.openai_model,
            "max_tokens": self.settings.max_tokens_vision,
            "stream": True,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {"type": "image_url", "image_url": {"url": data_url}},
                    ],
                }
            ],
        }
        extra = self.settings.openai_extra_body_dict
        if extra:
            kwargs["extra_body"] = extra
            logger.info("openai vision extra_body=%s", extra)
        stream = await client.chat.completions.create(**kwargs)
        yield self._sse("status", {"message": "模型思考中…"})
        await asyncio.sleep(0)
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
            await asyncio.sleep(0)

        logger.info(
            "openai stream done: chunks=%d raw_len=%d", chunk_count, len(accumulated)
        )
        logger.debug("openai raw output:\n%s", accumulated)
        yield self._sse("status", {"message": "正在解析结果…"})
        result = self._parse(accumulated, engine="openai")
        logger.info(
            "vision translate parsed: scene=%s items=%d summary=%r",
            result.scene_type,
            len(result.items),
            result.summary[:80],
        )
        for i, item in enumerate(result.items):
            logger.info(
                "  item[%d] indices=%s src=%r -> tgt=%r note=%r",
                i,
                item.ocr_indices,
                item.source_text[:60],
                item.translated_text[:60],
                (item.note or "")[:60],
            )
        yield self._sse("final", self._result_to_dict(result))

    @staticmethod
    def _parse(raw: str, engine: str) -> VisionTranslateResult:
        """尽量稳的 JSON 解析：去掉可能的 ```json 包装，提取第一个对象字面量。"""
        stripped = raw.strip()
        if stripped.startswith("```"):
            stripped = stripped.strip("`")
            if stripped.lower().startswith("json"):
                stripped = stripped[4:].strip()
        # 若模型前后还带着解说文字，尝试抓第一个 { ... } 块
        if not stripped.startswith("{"):
            start = stripped.find("{")
            end = stripped.rfind("}")
            if start >= 0 and end > start:
                stripped = stripped[start : end + 1]

        try:
            data = json.loads(stripped)
        except json.JSONDecodeError as exc:
            logger.warning("vision translate JSON 解析失败: %s", exc)
            return VisionTranslateResult(
                scene_type="other",
                summary="模型返回无法解析的内容",
                items=[],
                engine=engine,
            )

        items_raw = data.get("items") or []
        items: list[VisionTranslateItem] = []
        for it in items_raw:
            if not isinstance(it, dict):
                continue
            idx_raw = it.get("ocr_indices") or []
            indices: list[int] = []
            for v in idx_raw:
                try:
                    indices.append(int(v))
                except (TypeError, ValueError):
                    continue
            src = str(it.get("source_text") or "").strip()
            tgt = str(it.get("translated_text") or "").strip()
            if not src and not tgt:
                continue
            note_raw = it.get("note")
            note = str(note_raw).strip() if note_raw else None
            items.append(
                VisionTranslateItem(
                    ocr_indices=indices,
                    source_text=src,
                    translated_text=tgt,
                    note=note or None,
                )
            )

        return VisionTranslateResult(
            scene_type=str(data.get("scene_type") or "other").strip() or "other",
            summary=str(data.get("summary") or "").strip(),
            items=items,
            engine=engine,
        )

    @staticmethod
    def _result_to_dict(result: VisionTranslateResult) -> dict:
        return {
            "scene_type": result.scene_type,
            "summary": result.summary,
            "engine": result.engine,
            "items": [
                {
                    "ocr_indices": it.ocr_indices,
                    "source_text": it.source_text,
                    "translated_text": it.translated_text,
                    "note": it.note,
                }
                for it in result.items
            ],
        }
