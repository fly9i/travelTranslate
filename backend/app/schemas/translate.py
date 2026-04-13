"""翻译接口的请求/响应 schema。"""

from pydantic import BaseModel, Field


class TranslateBatchRequest(BaseModel):
    """批量翻译请求：一次性把多条文本送入 LLM，显著降低耗时与 token。"""

    source_texts: list[str] = Field(
        ..., min_length=1, max_length=200, description="待翻译文本列表"
    )
    source_language: str = Field(default="auto", description="源语言代码")
    target_language: str = Field(..., description="目标语言代码")
    context: str | None = Field(default=None, description="场景上下文")


class TranslateBatchItem(BaseModel):
    """批量翻译结果项。"""

    source_text: str
    translated_text: str


class TranslateBatchResponse(BaseModel):
    """批量翻译响应。"""

    items: list[TranslateBatchItem]
    engine: str = "mock"


class TranslateRequest(BaseModel):
    """翻译请求。"""

    source_text: str = Field(..., min_length=1, max_length=2000, description="待翻译文本")
    source_language: str = Field(default="zh", description="源语言代码，如 zh")
    target_language: str = Field(..., description="目标语言代码，如 ja/ko/en")
    context: str | None = Field(
        default=None, description="场景上下文，如 restaurant/transport"
    )
    conversation_id: str | None = Field(default=None, description="对话 ID，可选")
    polish: bool = Field(
        default=False,
        description="开启文化润色：译文语用更地道，并返回 cultural_note 文化提醒",
    )


class TranslateResponse(BaseModel):
    """翻译响应。"""

    translated_text: str
    transliteration: str | None = None
    confidence: float = 1.0
    engine: str = "mock"
    cached: bool = False
    cultural_note: str | None = Field(
        default=None, description="文化语境提醒（仅 polish=true 时返回）"
    )
