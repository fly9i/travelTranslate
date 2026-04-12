"""FastAPI 应用入口。"""

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.router import api_router
from app.config import get_settings
from app.core.database import AsyncSessionLocal, init_db
from app.core.logging import setup_logging
from app.services.phrase_service import PhraseService

logger = logging.getLogger(__name__)

PHRASES_DIR = Path(__file__).parent / "data" / "phrases"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期：初始化数据库 + 导入预置短语。"""
    setup_logging()
    settings = get_settings()
    logger.info("启动 %s (env=%s)", settings.app_name, settings.app_env)

    # 确保 data 目录存在
    data_dir = Path("./data")
    data_dir.mkdir(parents=True, exist_ok=True)

    await init_db()

    # 导入预置短语
    async with AsyncSessionLocal() as db:
        service = PhraseService(db)
        inserted = await service.seed_from_json(PHRASES_DIR)
        if inserted:
            logger.info("预置短语导入完成：%d 条", inserted)

    yield
    logger.info("关闭 %s", settings.app_name)


def create_app() -> FastAPI:
    """工厂方法：创建 FastAPI 应用。"""
    settings = get_settings()

    app = FastAPI(
        title=settings.app_name,
        description="TravelTranslator 旅行沟通助手后端服务",
        version="0.1.0",
        lifespan=lifespan,
    )

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # 统一异常处理
    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        """兜底异常处理。"""
        logger.exception("未处理异常: %s %s -> %s", request.method, request.url.path, exc)
        return JSONResponse(
            status_code=500,
            content={"error": "InternalServerError", "detail": str(exc)},
        )

    # 路由
    app.include_router(api_router)

    @app.get("/", tags=["meta"])
    async def root() -> dict[str, str]:
        """根路径，返回服务信息。"""
        return {
            "app": settings.app_name,
            "version": "0.1.0",
            "docs": "/docs",
        }

    @app.get("/health", tags=["meta"])
    async def health() -> dict[str, str]:
        """健康检查。"""
        return {"status": "ok"}

    return app


app = create_app()
