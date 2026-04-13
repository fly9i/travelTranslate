"""场景理解接口测试。"""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_vision_describe_empty(client: AsyncClient) -> None:
    """空 OCR 文本应返回 other 并给出提示。"""
    resp = await client.post(
        "/api/v1/vision/describe",
        json={
            "ocr_texts": [],
            "source_language": "ja",
            "user_language": "zh",
            "destination": "日本",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["scene_type"] == "other"
    assert "未识别到文字" in body["summary"]
    assert body["items"] == []


@pytest.mark.asyncio
async def test_vision_describe_fallback(client: AsyncClient) -> None:
    """未配置 LLM 时走 mock 兜底，不应抛异常。"""
    resp = await client.post(
        "/api/v1/vision/describe",
        json={
            "ocr_texts": ["ラーメン 800円", "餃子 500円"],
            "source_language": "ja",
            "user_language": "zh",
            "destination": "日本",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["engine"] in {"mock", "anthropic", "openai"}
    assert isinstance(body["summary"], str) and len(body["summary"]) > 0


@pytest.mark.asyncio
async def test_translate_polish_schema(client: AsyncClient) -> None:
    """polish 字段应被 schema 接受；mock 引擎不返回 cultural_note。"""
    resp = await client.post(
        "/api/v1/translate",
        json={
            "source_text": "你好",
            "source_language": "zh",
            "target_language": "ja",
            "polish": True,
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "cultural_note" in body
