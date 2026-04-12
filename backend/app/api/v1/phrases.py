"""场景短语接口。"""

import logging

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.phrase import PhraseCreate, PhraseOut, PhrasePackage
from app.services.phrase_service import PhraseService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/phrases", tags=["phrases"])


@router.get("/packages/{language}", response_model=PhrasePackage)
async def get_phrase_package(
    language: str,
    category: str | None = Query(default=None, description="可选场景分类"),
    db: AsyncSession = Depends(get_db),
) -> PhrasePackage:
    """获取离线短语包。"""
    service = PhraseService(db)
    phrases = await service.list_by_language(language, category)
    return PhrasePackage(
        language=language,
        total=len(phrases),
        phrases=[PhraseOut.model_validate(p) for p in phrases],
    )


@router.post("/custom", response_model=PhraseOut, status_code=201)
async def create_custom_phrase(
    payload: PhraseCreate,
    db: AsyncSession = Depends(get_db),
) -> PhraseOut:
    """创建自定义短语。"""
    service = PhraseService(db)
    phrase = await service.create_custom(payload)
    return PhraseOut.model_validate(phrase)
