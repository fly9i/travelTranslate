"""收藏短语模型。"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


class FavoritePhrase(Base):
    """用户收藏的短语。"""

    __tablename__ = "favorite_phrases"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    source_text: Mapped[str] = mapped_column(Text)
    target_text: Mapped[str] = mapped_column(Text)
    source_language: Mapped[str] = mapped_column(String(10), default="zh")
    target_language: Mapped[str] = mapped_column(String(10))
    scene_category: Mapped[str | None] = mapped_column(String(50), nullable=True)
    source_phrase_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped["User"] = relationship("User", back_populates="favorites")  # noqa: F821
