"""对话相关 schema。"""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ConversationCreate(BaseModel):
    """创建对话。"""

    destination: str | None = None
    source_language: str = "zh"
    target_language: str
    user_id: str | None = None


class MessageCreate(BaseModel):
    """创建消息。"""

    speaker: Literal["user", "counterpart"] = "user"
    source_text: str = Field(..., min_length=1)
    input_type: Literal["text", "voice", "photo"] = "text"
    audio_url: str | None = None


class MessageOut(BaseModel):
    """消息输出。"""

    model_config = ConfigDict(from_attributes=True)

    id: str
    conversation_id: str
    speaker: str
    source_text: str
    translated_text: str
    input_type: str
    audio_url: str | None
    created_at: datetime


class ConversationOut(BaseModel):
    """对话输出。"""

    model_config = ConfigDict(from_attributes=True)

    id: str
    destination: str | None
    source_language: str
    target_language: str
    message_count: int
    created_at: datetime
    updated_at: datetime


class ConversationDetail(ConversationOut):
    """对话详情（含消息列表）。"""

    messages: list[MessageOut] = []
