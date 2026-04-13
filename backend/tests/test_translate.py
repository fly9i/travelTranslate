"""翻译接口测试。"""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health(client: AsyncClient) -> None:
    """健康检查。"""
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_translate_fallback(client: AsyncClient) -> None:
    """兜底字典命中。"""
    resp = await client.post(
        "/api/v1/translate",
        json={
            "source_text": "你好",
            "source_language": "zh",
            "target_language": "ja",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["translated_text"] == "こんにちは"
    assert body["engine"] == "mock"
    assert body["cached"] is False


@pytest.mark.asyncio
async def test_translate_cache_hit(client: AsyncClient) -> None:
    """二次调用命中缓存。"""
    payload = {
        "source_text": "谢谢",
        "source_language": "zh",
        "target_language": "ja",
    }
    first = await client.post("/api/v1/translate", json=payload)
    assert first.status_code == 200
    second = await client.post("/api/v1/translate", json=payload)
    assert second.status_code == 200
    assert second.json()["cached"] is True


@pytest.mark.asyncio
async def test_translate_batch_fallback(client: AsyncClient) -> None:
    """批量翻译接口：无 LLM 时走兜底字典，顺序与输入一致。"""
    resp = await client.post(
        "/api/v1/translate/batch",
        json={
            "source_texts": ["你好", "谢谢", "洗手间在哪里"],
            "source_language": "zh",
            "target_language": "ja",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["engine"] == "mock"
    assert [item["source_text"] for item in body["items"]] == [
        "你好",
        "谢谢",
        "洗手间在哪里",
    ]
    assert body["items"][0]["translated_text"] == "こんにちは"
    assert body["items"][1]["translated_text"] == "ありがとう"


@pytest.mark.asyncio
async def test_translate_batch_parser() -> None:
    """批量解析器：缺项用原文兜底、乱数据整体兜底。"""
    from app.services.translation_service import TranslationService

    parse = TranslationService._parse_batch_output
    out = parse(
        '{"translations":[{"id":1,"text":"hi"},{"id":2,"text":"bye"}]}',
        2,
        ["你好", "再见"],
    )
    assert out == ["hi", "bye"]

    partial = parse('{"translations":[{"id":1,"text":"hi"}]}', 2, ["a", "b"])
    assert partial == ["hi", "b"]

    fallback = parse("not json", 2, ["a", "b"])
    assert fallback == ["a", "b"]
