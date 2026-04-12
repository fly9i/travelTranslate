"""OCR 翻译接口（占位实现）。

后端不主动做端侧 OCR；此接口作为端侧 OCR 失败时的后备通道，
当前实现为 stub，便于前端调通接口，后续可接 Google Cloud Vision。
"""

import logging

from fastapi import APIRouter, File, Form, UploadFile
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ocr", tags=["ocr"])


class OcrBlock(BaseModel):
    """识别到的一个文字块。"""

    original_text: str
    translated_text: str
    bounding_box: dict[str, int]


class OcrResponse(BaseModel):
    """OCR 响应。"""

    blocks: list[OcrBlock]
    note: str | None = None


@router.post("/translate", response_model=OcrResponse)
async def ocr_translate(
    image: UploadFile = File(...),
    target_language: str = Form(default="zh"),
) -> OcrResponse:
    """OCR + 翻译（后备实现）。

    当前仅读取图片大小做 echo，真实 OCR 建议在端侧完成。
    """
    content = await image.read()
    logger.info(
        "收到 OCR 请求：%s bytes, target=%s, filename=%s",
        len(content),
        target_language,
        image.filename,
    )
    return OcrResponse(
        blocks=[],
        note="后端 OCR 暂未启用，请使用端侧 OCR（Android ML Kit / iOS Vision）",
    )
