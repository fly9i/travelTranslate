"""翻译接口。"""

import logging

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.translate import (
    TranslateBatchItem,
    TranslateBatchRequest,
    TranslateBatchResponse,
    TranslateRequest,
    TranslateResponse,
)
from app.services.text_translate_stream_service import TextTranslateStreamService
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
        polish=payload.polish,
    )
    return TranslateResponse(
        translated_text=result.translated_text,
        transliteration=result.transliteration,
        confidence=result.confidence,
        engine=result.engine,
        cached=result.cached,
        cultural_note=result.cultural_note,
    )


@router.post("/batch", response_model=TranslateBatchResponse)
async def translate_batch(
    payload: TranslateBatchRequest,
    db: AsyncSession = Depends(get_db),
) -> TranslateBatchResponse:
    """批量翻译：一次 LLM 调用翻译多条文本，用于 OCR 贴图等场景。"""
    service = TranslationService(db)
    translated, engine = await service.translate_batch(
        source_texts=payload.source_texts,
        source_language=payload.source_language,
        target_language=payload.target_language,
        context=payload.context,
    )
    items = [
        TranslateBatchItem(source_text=src, translated_text=tr)
        for src, tr in zip(payload.source_texts, translated, strict=False)
    ]
    return TranslateBatchResponse(items=items, engine=engine)


@router.post("/stream")
async def translate_stream(payload: TranslateRequest) -> StreamingResponse:
    """文本翻译的 SSE 流式接口。事件：status / delta / final / error。"""
    service = TextTranslateStreamService()
    generator = service.stream(
        source_text=payload.source_text,
        source_language=payload.source_language,
        target_language=payload.target_language,
        polish=payload.polish,
        context=payload.context,
    )
    return StreamingResponse(
        generator,
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )
