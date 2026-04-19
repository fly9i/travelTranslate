"""流式视觉翻译接口：图片 + OCR 块 → 多模态 LLM → SSE。"""

import json
import logging

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse

from app.services.vision_translate_service import OCRBlockInput, VisionTranslateService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/vision", tags=["vision"])


@router.post("/translate/stream")
async def vision_translate_stream(
    image: UploadFile = File(...),
    ocr_blocks: str = Form(...),
    source_language: str = Form(...),
    target_language: str = Form(...),
    destination: str | None = Form(None),
) -> StreamingResponse:
    """接收图片 + OCR 块，SSE 流式返回 LLM 过程和最终结构化翻译结果。

    ocr_blocks 必须是 JSON 字符串：[{"index": 0, "text": "..."}, ...]
    """
    try:
        raw = json.loads(ocr_blocks)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail=f"ocr_blocks JSON 无效: {exc}") from exc

    if not isinstance(raw, list):
        raise HTTPException(status_code=400, detail="ocr_blocks 必须是数组")

    blocks: list[OCRBlockInput] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        try:
            bbox_raw = item.get("bbox")
            bbox: tuple[float, float, float, float] | None = None
            if isinstance(bbox_raw, dict):
                try:
                    bbox = (
                        float(bbox_raw.get("x", 0.0)),
                        float(bbox_raw.get("y", 0.0)),
                        float(bbox_raw.get("w", 0.0)),
                        float(bbox_raw.get("h", 0.0)),
                    )
                except (TypeError, ValueError):
                    bbox = None
            blocks.append(
                OCRBlockInput(
                    index=int(item.get("index")),
                    text=str(item.get("text") or "").strip(),
                    bbox=bbox,
                )
            )
        except (TypeError, ValueError):
            continue

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="图片为空")

    media_type = image.content_type or "image/jpeg"
    logger.info(
        "POST /vision/translate/stream image=%s size=%d blocks=%d "
        "source=%s target=%s destination=%s",
        image.filename,
        len(image_bytes),
        len(blocks),
        source_language,
        target_language,
        destination,
    )

    service = VisionTranslateService()

    async def event_source():
        async for chunk in service.stream(
            image_bytes=image_bytes,
            image_media_type=media_type,
            blocks=blocks,
            source_language=source_language,
            target_language=target_language,
            destination=destination,
        ):
            yield chunk

    return StreamingResponse(
        event_source(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )
