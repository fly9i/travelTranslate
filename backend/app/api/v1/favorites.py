"""收藏短语接口。"""

import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.favorite import FavoritePhrase
from app.schemas.favorite import FavoriteCreate, FavoriteOut

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/favorites", tags=["favorites"])


@router.post("", response_model=FavoriteOut, status_code=201)
async def add_favorite(
    payload: FavoriteCreate,
    db: AsyncSession = Depends(get_db),
) -> FavoriteOut:
    """添加收藏。"""
    fav = FavoritePhrase(
        user_id=payload.user_id,
        source_text=payload.source_text,
        target_text=payload.target_text,
        source_language=payload.source_language,
        target_language=payload.target_language,
        scene_category=payload.scene_category,
        source_phrase_id=payload.source_phrase_id,
    )
    db.add(fav)
    await db.commit()
    await db.refresh(fav)
    return FavoriteOut.model_validate(fav)


@router.get("", response_model=list[FavoriteOut])
async def list_favorites(
    user_id: str,
    db: AsyncSession = Depends(get_db),
) -> list[FavoriteOut]:
    """列出用户收藏。"""
    stmt = (
        select(FavoritePhrase)
        .where(FavoritePhrase.user_id == user_id)
        .order_by(FavoritePhrase.created_at.desc())
    )
    result = await db.execute(stmt)
    favs = result.scalars().all()
    return [FavoriteOut.model_validate(f) for f in favs]


@router.delete("/{favorite_id}", status_code=204)
async def delete_favorite(
    favorite_id: str,
    db: AsyncSession = Depends(get_db),
) -> None:
    """删除收藏。"""
    stmt = select(FavoritePhrase).where(FavoritePhrase.id == favorite_id)
    result = await db.execute(stmt)
    fav = result.scalar_one_or_none()
    if fav is None:
        raise HTTPException(status_code=404, detail="收藏不存在")
    await db.delete(fav)
    await db.commit()
