"""场景短语相关 schema。"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class PhraseBase(BaseModel):
    """短语基础字段。"""

    scene_category: str = Field(..., description="场景分类：restaurant/transport/hotel 等")
    subcategory: str | None = None
    source_text: str
    target_text: str
    source_language: str = "zh"
    target_language: str
    transliteration: str | None = None


class PhraseCreate(PhraseBase):
    """创建自定义短语。"""

    user_id: str | None = None
    is_custom: bool = True


class PhraseOut(PhraseBase):
    """短语输出。"""

    model_config = ConfigDict(from_attributes=True)

    id: str
    is_custom: bool
    use_count: int
    priority: int
    created_at: datetime


class PhrasePackage(BaseModel):
    """场景短语包（按语言打包）。"""

    language: str
    destination: str | None = None
    version: str = "1.0.0"
    total: int
    phrases: list[PhraseOut]
