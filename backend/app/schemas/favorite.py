"""收藏短语 schema。"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class FavoriteCreate(BaseModel):
    """创建收藏。"""

    user_id: str
    source_text: str
    target_text: str
    source_language: str = "zh"
    target_language: str
    scene_category: str | None = None
    source_phrase_id: str | None = None


class FavoriteOut(BaseModel):
    """收藏输出。"""

    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    source_text: str
    target_text: str
    source_language: str
    target_language: str
    scene_category: str | None
    source_phrase_id: str | None
    created_at: datetime
