"""场景短语服务。"""

import json
import logging
from pathlib import Path

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.phrase import ScenePhrase
from app.schemas.phrase import PhraseCreate

logger = logging.getLogger(__name__)


class PhraseService:
    """场景短语管理。"""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def list_by_language(
        self,
        target_language: str,
        scene_category: str | None = None,
    ) -> list[ScenePhrase]:
        """按语言/场景筛选短语。"""
        stmt = select(ScenePhrase).where(ScenePhrase.target_language == target_language)
        if scene_category:
            stmt = stmt.where(ScenePhrase.scene_category == scene_category)
        stmt = stmt.order_by(
            ScenePhrase.scene_category,
            ScenePhrase.subcategory,
            ScenePhrase.priority.desc(),
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def count_by_language(self, target_language: str) -> int:
        """统计某语言短语总数。"""
        stmt = select(func.count(ScenePhrase.id)).where(
            ScenePhrase.target_language == target_language
        )
        result = await self.db.execute(stmt)
        return int(result.scalar_one() or 0)

    async def create_custom(self, data: PhraseCreate) -> ScenePhrase:
        """创建自定义短语。"""
        phrase = ScenePhrase(
            scene_category=data.scene_category,
            subcategory=data.subcategory,
            source_text=data.source_text,
            target_text=data.target_text,
            source_language=data.source_language,
            target_language=data.target_language,
            transliteration=data.transliteration,
            is_custom=True,
            user_id=data.user_id,
        )
        self.db.add(phrase)
        await self.db.commit()
        await self.db.refresh(phrase)
        return phrase

    async def seed_from_json(self, phrases_dir: Path) -> int:
        """从 JSON 文件批量导入预置短语（仅在数据库为空时执行）。"""
        existing = await self.db.execute(
            select(func.count(ScenePhrase.id)).where(ScenePhrase.is_custom.is_(False))
        )
        if (existing.scalar_one() or 0) > 0:
            return 0

        inserted = 0
        for json_file in sorted(phrases_dir.glob("phrases_*.json")):
            try:
                with json_file.open("r", encoding="utf-8") as f:
                    pkg = json.load(f)
            except (OSError, json.JSONDecodeError) as exc:
                logger.error("加载短语包失败 %s: %s", json_file, exc)
                continue

            lang = pkg.get("language")
            if not lang:
                continue

            for scene in pkg.get("scenes", []):
                category = scene.get("category")
                for sub in scene.get("subcategories", []):
                    sub_name = sub.get("name")
                    for p in sub.get("phrases", []):
                        phrase = ScenePhrase(
                            scene_category=category,
                            subcategory=sub_name,
                            source_text=p["source"],
                            target_text=p["target"],
                            source_language="zh",
                            target_language=lang,
                            transliteration=p.get("pinyin"),
                            priority=p.get("priority", 0),
                            is_custom=False,
                        )
                        self.db.add(phrase)
                        inserted += 1

        if inserted:
            await self.db.commit()
            logger.info("导入预置短语 %d 条", inserted)
        return inserted
