"""收藏接口测试。"""

import pytest
from httpx import AsyncClient
from sqlalchemy import insert

from app.core.database import AsyncSessionLocal
from app.models.user import User


@pytest.mark.asyncio
async def test_favorite_crud(client: AsyncClient, sample_user_id: str) -> None:
    """收藏的创建、列出、删除。"""
    # 先创建用户（外键依赖）
    async with AsyncSessionLocal() as db:
        await db.execute(
            insert(User).values(id=sample_user_id, device_id="test-device")
        )
        await db.commit()

    # 新建收藏
    create = await client.post(
        "/api/v1/favorites",
        json={
            "user_id": sample_user_id,
            "source_text": "谢谢",
            "target_text": "ありがとう",
            "target_language": "ja",
            "scene_category": "daily",
        },
    )
    assert create.status_code == 201
    fav_id = create.json()["id"]

    # 列出
    list_resp = await client.get("/api/v1/favorites", params={"user_id": sample_user_id})
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 1

    # 删除
    del_resp = await client.delete(f"/api/v1/favorites/{fav_id}")
    assert del_resp.status_code == 204
