"""场景理解接口：基于 OCR 文字让 LLM 输出结构化说明。"""

import logging

from fastapi import APIRouter

from app.schemas.vision import VisionDescribeRequest, VisionDescribeResponse, VisionItem
from app.services.vision_service import VisionService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/vision", tags=["vision"])


@router.post("/describe", response_model=VisionDescribeResponse)
async def describe(payload: VisionDescribeRequest) -> VisionDescribeResponse:
    """根据 OCR 文字生成结构化场景说明。"""
    service = VisionService()
    result = await service.describe(
        ocr_texts=payload.ocr_texts,
        source_language=payload.source_language,
        user_language=payload.user_language,
        destination=payload.destination,
        hint=payload.hint,
    )
    return VisionDescribeResponse(
        scene_type=result.scene_type,
        summary=result.summary,
        items=[
            VisionItem(
                name=item.name,
                original=item.original,
                description=item.description,
                tags=item.tags,
                recommendation=item.recommendation,
            )
            for item in result.items
        ],
        warnings=result.warnings,
        engine=result.engine,
    )
