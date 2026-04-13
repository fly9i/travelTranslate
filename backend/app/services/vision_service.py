"""场景理解服务：基于 OCR 文字让 LLM 输出结构化描述。"""

import json
import logging
from dataclasses import dataclass, field

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)


@dataclass
class VisionItem:
    name: str
    original: str | None = None
    description: str | None = None
    tags: list[str] = field(default_factory=list)
    recommendation: str | None = None


@dataclass
class VisionResult:
    scene_type: str
    summary: str
    items: list[VisionItem]
    warnings: list[str]
    engine: str


class VisionService:
    """场景理解服务。"""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    async def describe(
        self,
        ocr_texts: list[str],
        source_language: str,
        user_language: str,
        destination: str | None,
        hint: str | None,
    ) -> VisionResult:
        """调用 LLM 做场景理解。失败降级到简单总结。"""
        joined = "\n".join(t.strip() for t in ocr_texts if t.strip())
        if not joined:
            return VisionResult(
                scene_type="other",
                summary="图片中未识别到文字。",
                items=[],
                warnings=[],
                engine="mock",
            )

        engine = self.settings.translation_engine.lower()
        try:
            if engine == "anthropic" and self.settings.anthropic_api_key:
                return await self._describe_with_anthropic(
                    joined, source_language, user_language, destination, hint
                )
            if engine == "openai" and self.settings.openai_api_key:
                return await self._describe_with_openai(
                    joined, source_language, user_language, destination, hint
                )
        except Exception as exc:
            logger.exception("vision describe failed, fallback: %s", exc)

        return self._fallback(joined)

    @staticmethod
    def _fallback(joined: str) -> VisionResult:
        first_line = joined.splitlines()[0][:40]
        return VisionResult(
            scene_type="other",
            summary=f"识别到文字：{first_line}…（未启用 LLM，无法生成详细说明）",
            items=[],
            warnings=[],
            engine="mock",
        )

    @staticmethod
    def _build_prompt(
        joined: str,
        source_language: str,
        user_language: str,
        destination: str | None,
        hint: str | None,
    ) -> str:
        dest_hint = f"目的地：{destination}。" if destination else ""
        user_hint = f"用户补充：{hint}。" if hint else ""
        return (
            "你是一名旅行场景助手。下面是用户在境外拍照后 OCR 得到的文字片段（可能乱序、可能有识别错误）。"
            f"图中文字语言：{source_language}。{dest_hint}{user_hint}"
            f"请用 {user_language} 向用户解释这是什么场景、关键信息、以及旅行者需要注意的事项。\n\n"
            "严格按以下 JSON 格式输出，不要加 Markdown 代码块或额外文字：\n"
            "{\n"
            '  "scene_type": "menu | sign | receipt | document | ticket | other",\n'
            '  "summary": "一段总体说明，2-4 句",\n'
            '  "items": [\n'
            '    {"name": "用用户语言表述的名称", "original": "原文", "description": "食材/说明", "tags": ["辣", "含花生"], "recommendation": "推荐度或提醒"}\n'
            "  ],\n"
            '  "warnings": ["旅行者应该注意的事项，可 0-3 条"]\n'
            "}\n"
            "items 数组在非菜单场景可为空。tags 要关注辣度/过敏源/素食/酒精/宗教/强制消费等。\n\n"
            f"OCR 文字：\n{joined}"
        )

    async def _describe_with_anthropic(
        self,
        joined: str,
        source_language: str,
        user_language: str,
        destination: str | None,
        hint: str | None,
    ) -> VisionResult:
        try:
            from anthropic import AsyncAnthropic
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("anthropic SDK 未安装") from exc

        client = AsyncAnthropic(api_key=self.settings.anthropic_api_key)
        prompt = self._build_prompt(joined, source_language, user_language, destination, hint)
        message = await client.messages.create(
            model=self.settings.anthropic_model,
            max_tokens=2048,
            messages=[{"role": "user", "content": prompt}],
        )
        raw = "".join(
            block.text for block in message.content if getattr(block, "type", "") == "text"
        ).strip()
        return self._parse(raw, engine="anthropic")

    async def _describe_with_openai(
        self,
        joined: str,
        source_language: str,
        user_language: str,
        destination: str | None,
        hint: str | None,
    ) -> VisionResult:
        try:
            from openai import AsyncOpenAI
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("openai SDK 未安装") from exc

        client = AsyncOpenAI(
            api_key=self.settings.openai_api_key,
            base_url=self.settings.openai_base_url,
        )
        prompt = self._build_prompt(joined, source_language, user_language, destination, hint)
        kwargs: dict = {
            "model": self.settings.openai_model,
            "max_tokens": 2048,
            "messages": [{"role": "user", "content": prompt}],
            "response_format": {"type": "json_object"},
        }
        extra = self.settings.openai_extra_body_dict
        if extra:
            kwargs["extra_body"] = extra
        completion = await client.chat.completions.create(**kwargs)
        raw = (completion.choices[0].message.content or "").strip()
        return self._parse(raw, engine="openai")

    @staticmethod
    def _parse(raw: str, engine: str) -> VisionResult:
        stripped = raw.strip()
        if stripped.startswith("```"):
            stripped = stripped.strip("`")
            if stripped.lower().startswith("json"):
                stripped = stripped[4:].strip()
        try:
            data = json.loads(stripped)
        except json.JSONDecodeError as exc:
            logger.warning("vision describe JSON 解析失败: %s", exc)
            return VisionResult(
                scene_type="other",
                summary=stripped[:200] if stripped else "LLM 返回无效内容",
                items=[],
                warnings=[],
                engine=engine,
            )

        items_raw = data.get("items") or []
        items: list[VisionItem] = []
        for it in items_raw:
            if not isinstance(it, dict):
                continue
            items.append(
                VisionItem(
                    name=str(it.get("name", "")).strip(),
                    original=(str(it["original"]).strip() if it.get("original") else None),
                    description=(
                        str(it["description"]).strip() if it.get("description") else None
                    ),
                    tags=[str(t).strip() for t in (it.get("tags") or []) if str(t).strip()],
                    recommendation=(
                        str(it["recommendation"]).strip() if it.get("recommendation") else None
                    ),
                )
            )
        warnings = [str(w).strip() for w in (data.get("warnings") or []) if str(w).strip()]
        return VisionResult(
            scene_type=str(data.get("scene_type", "other")).strip() or "other",
            summary=str(data.get("summary", "")).strip(),
            items=items,
            warnings=warnings,
            engine=engine,
        )
