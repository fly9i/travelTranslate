"""pytest 公共 fixtures。"""

import os
from collections.abc import AsyncGenerator
from pathlib import Path

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

# 在导入应用前设置测试环境变量
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///:memory:"
os.environ["TRANSLATION_ENGINE"] = "mock"
os.environ["APP_DEBUG"] = "false"


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """提供启动了 lifespan 的异步 HTTP 客户端。"""
    from app.core.database import AsyncSessionLocal, Base, engine
    from app.main import app
    from app.models import (  # noqa: F401
        conversation,
        favorite,
        message,
        phrase,
        translation_cache,
        user,
    )
    from app.services.phrase_service import PhraseService

    # 重建内存数据库
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

    # 导入预置短语
    phrases_dir = Path(__file__).parent.parent / "app" / "data" / "phrases"
    async with AsyncSessionLocal() as db:
        await PhraseService(db).seed_from_json(phrases_dir)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def sample_user_id() -> str:
    """返回固定 UUID 作为测试用户 ID。"""
    return "00000000-0000-0000-0000-000000000001"
