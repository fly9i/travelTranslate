"""场景短语模型（预置 + 用户自定义）。"""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


class ScenePhrase(Base):
    """场景短语：每条包含原文 + 译文 + 注音 + 分类。"""

    __tablename__ = "scene_phrases"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    scene_category: Mapped[str] = mapped_column(String(50), index=True)
    subcategory: Mapped[str | None] = mapped_column(String(50), nullable=True)
    source_text: Mapped[str] = mapped_column(Text)
    target_text: Mapped[str] = mapped_column(Text)
    source_language: Mapped[str] = mapped_column(String(10), default="zh")
    target_language: Mapped[str] = mapped_column(String(10), index=True)
    transliteration: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_custom: Mapped[bool] = mapped_column(Boolean, default=False)
    user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id"), nullable=True
    )
    use_count: Mapped[int] = mapped_column(Integer, default=0)
    priority: Mapped[int] = mapped_column(Integer, default=0)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_scene_phrases_category_lang", "scene_category", "target_language"),
    )
