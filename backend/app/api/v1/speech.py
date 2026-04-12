"""语音识别接口（占位实现）。

真实的 ASR 建议使用端侧能力（Android SpeechRecognizer / iOS Speech）。
本接口作为后备通道。
"""

import logging

from fastapi import APIRouter, File, Form, UploadFile
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/speech", tags=["speech"])


class SpeechToTextResponse(BaseModel):
    """语音识别结果。"""

    text: str
    confidence: float
    note: str | None = None


@router.post("/recognize", response_model=SpeechToTextResponse)
async def speech_to_text(
    file: UploadFile = File(...),
    language: str = Form(default="zh"),
) -> SpeechToTextResponse:
    """音频 -> 文本。"""
    content = await file.read()
    logger.info(
        "收到 ASR 请求：%s bytes, language=%s, filename=%s",
        len(content),
        language,
        file.filename,
    )
    return SpeechToTextResponse(
        text="",
        confidence=0.0,
        note="后端 ASR 暂未启用，请使用端侧 ASR",
    )
