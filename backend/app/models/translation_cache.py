"""翻译缓存模型（高频短语缓存，降低 API 成本）。"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


class TranslationCache(Base):
    """翻译结果缓存。"""

    __tablename__ = "translation_cache"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    source_text: Mapped[str] = mapped_column(Text)
    source_language: Mapped[str] = mapped_column(String(10))
    target_language: Mapped[str] = mapped_column(String(10))
    translated_text: Mapped[str] = mapped_column(Text)
    transliteration: Mapped[str | None] = mapped_column(Text, nullable=True)
    engine: Mapped[str] = mapped_column(String(50), default="mock")
    hit_count: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint(
            "source_text",
            "source_language",
            "target_language",
            name="uq_translation_cache_text_pair",
        ),
    )
