"""对话接口。"""

import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.conversation import (
    ConversationCreate,
    ConversationDetail,
    ConversationOut,
    MessageCreate,
    MessageOut,
)
from app.services.conversation_service import ConversationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/conversations", tags=["conversations"])


@router.post("", response_model=ConversationOut, status_code=201)
async def create_conversation(
    payload: ConversationCreate,
    db: AsyncSession = Depends(get_db),
) -> ConversationOut:
    """创建一次对话。"""
    service = ConversationService(db)
    conv = await service.create(payload)
    return ConversationOut.model_validate(conv)


@router.get("/{conversation_id}", response_model=ConversationDetail)
async def get_conversation(
    conversation_id: str,
    db: AsyncSession = Depends(get_db),
) -> ConversationDetail:
    """获取对话详情。"""
    service = ConversationService(db)
    conv = await service.get(conversation_id)
    if conv is None:
        raise HTTPException(status_code=404, detail="对话不存在")
    return ConversationDetail(
        id=conv.id,
        destination=conv.destination,
        source_language=conv.source_language,
        target_language=conv.target_language,
        message_count=conv.message_count,
        created_at=conv.created_at,
        updated_at=conv.updated_at,
        messages=[MessageOut.model_validate(m) for m in conv.messages],
    )


@router.post("/{conversation_id}/messages", response_model=MessageOut, status_code=201)
async def add_message(
    conversation_id: str,
    payload: MessageCreate,
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    """追加一条对话消息（自动翻译）。"""
    service = ConversationService(db)
    conv = await service.get(conversation_id)
    if conv is None:
        raise HTTPException(status_code=404, detail="对话不存在")
    msg = await service.add_message(conv, payload)
    return MessageOut.model_validate(msg)
