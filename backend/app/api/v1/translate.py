"""翻译接口。"""

import logging

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.translate import TranslateRequest, TranslateResponse
from app.services.translation_service import TranslationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/translate", tags=["translate"])


@router.post("", response_model=TranslateResponse)
async def translate(
    payload: TranslateRequest,
    db: AsyncSession = Depends(get_db),
) -> TranslateResponse:
    """翻译文本。"""
    service = TranslationService(db)
    result = await service.translate(
        source_text=payload.source_text,
        source_language=payload.source_language,
        target_language=payload.target_language,
        context=payload.context,
    )
    return TranslateResponse(
        translated_text=result.translated_text,
        transliteration=result.transliteration,
        confidence=result.confidence,
        engine=result.engine,
        cached=result.cached,
    )
