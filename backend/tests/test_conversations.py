"""对话接口测试。"""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_conversation_flow(client: AsyncClient) -> None:
    """创建对话并追加消息。"""
    # 创建对话
    create = await client.post(
        "/api/v1/conversations",
        json={
            "destination": "东京",
            "source_language": "zh",
            "target_language": "ja",
        },
    )
    assert create.status_code == 201
    conv_id = create.json()["id"]

    # 追加用户消息
    msg = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"speaker": "user", "source_text": "你好", "input_type": "text"},
    )
    assert msg.status_code == 201
    assert msg.json()["translated_text"] == "こんにちは"

    # 获取详情
    detail = await client.get(f"/api/v1/conversations/{conv_id}")
    assert detail.status_code == 200
    body = detail.json()
    assert body["message_count"] == 1
    assert len(body["messages"]) == 1


@pytest.mark.asyncio
async def test_conversation_not_found(client: AsyncClient) -> None:
    """不存在的对话返回 404。"""
    resp = await client.get("/api/v1/conversations/nonexistent")
    assert resp.status_code == 404
