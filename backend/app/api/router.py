"""聚合所有 API v1 路由。"""

from fastapi import APIRouter

from app.api.v1 import conversations, favorites, ocr, phrases, speech, translate

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(translate.router)
api_router.include_router(phrases.router)
api_router.include_router(conversations.router)
api_router.include_router(favorites.router)
api_router.include_router(ocr.router)
api_router.include_router(speech.router)
