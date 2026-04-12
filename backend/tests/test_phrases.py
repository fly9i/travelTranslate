"""场景短语接口测试。"""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_phrase_package_ja(client: AsyncClient) -> None:
    """日语短语包。"""
    resp = await client.get("/api/v1/phrases/packages/ja")
    assert resp.status_code == 200
    body = resp.json()
    assert body["language"] == "ja"
    assert body["total"] > 0
    assert any(p["target_text"] == "こんにちは" for p in body["phrases"])


@pytest.mark.asyncio
async def test_phrase_package_filter_category(client: AsyncClient) -> None:
    """按场景过滤。"""
    resp = await client.get("/api/v1/phrases/packages/ja", params={"category": "restaurant"})
    assert resp.status_code == 200
    body = resp.json()
    assert all(p["scene_category"] == "restaurant" for p in body["phrases"])


@pytest.mark.asyncio
async def test_create_custom_phrase(client: AsyncClient) -> None:
    """创建自定义短语。"""
    resp = await client.post(
        "/api/v1/phrases/custom",
        json={
            "scene_category": "daily",
            "source_text": "晚安",
            "target_text": "おやすみ",
            "target_language": "ja",
            "transliteration": "oyasumi",
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["is_custom"] is True
    assert body["source_text"] == "晚安"
