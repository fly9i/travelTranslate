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
