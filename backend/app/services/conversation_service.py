"""对话服务。"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.conversation import Conversation
from app.models.message import Message
from app.schemas.conversation import ConversationCreate, MessageCreate
from app.services.translation_service import TranslationService


class ConversationService:
    """双向对话管理。"""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create(self, data: ConversationCreate) -> Conversation:
        """创建对话。"""
        conv = Conversation(
            user_id=data.user_id,
            destination=data.destination,
            source_language=data.source_language,
            target_language=data.target_language,
        )
        self.db.add(conv)
        await self.db.commit()
        await self.db.refresh(conv)
        return conv

    async def get(self, conversation_id: str) -> Conversation | None:
        """获取对话详情（含消息）。"""
        stmt = (
            select(Conversation)
            .where(Conversation.id == conversation_id)
            .options(selectinload(Conversation.messages))
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def list_by_user(self, user_id: str) -> list[Conversation]:
        """按用户列出历史对话。"""
        stmt = (
            select(Conversation)
            .where(Conversation.user_id == user_id)
            .order_by(Conversation.updated_at.desc())
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def add_message(
        self,
        conversation: Conversation,
        data: MessageCreate,
    ) -> Message:
        """向对话中追加一条消息（自动翻译）。"""
        # 根据说话人方向决定翻译方向
        if data.speaker == "user":
            src_lang = conversation.source_language
            tgt_lang = conversation.target_language
        else:
            src_lang = conversation.target_language
            tgt_lang = conversation.source_language

        translator = TranslationService(self.db)
        result = await translator.translate(
            source_text=data.source_text,
            source_language=src_lang,
            target_language=tgt_lang,
            context="conversation",
        )

        msg = Message(
            conversation_id=conversation.id,
            speaker=data.speaker,
            source_text=data.source_text,
            translated_text=result.translated_text,
            input_type=data.input_type,
            audio_url=data.audio_url,
        )
        self.db.add(msg)
        conversation.message_count += 1
        await self.db.commit()
        await self.db.refresh(msg)
        return msg
