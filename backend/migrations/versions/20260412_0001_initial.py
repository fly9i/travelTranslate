"""初始化数据库表结构。

Revision ID: 20260412_0001
Revises:
Create Date: 2026-04-12

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260412_0001"
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """创建初始表。"""
    op.create_table(
        "users",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("device_id", sa.String(length=255), nullable=False),
        sa.Column("default_source_language", sa.String(length=10), server_default="zh"),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now()),
        sa.UniqueConstraint("device_id", name="uq_users_device_id"),
    )
    op.create_index("ix_users_device_id", "users", ["device_id"])

    op.create_table(
        "scene_phrases",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("scene_category", sa.String(length=50), nullable=False),
        sa.Column("subcategory", sa.String(length=50), nullable=True),
        sa.Column("source_text", sa.Text(), nullable=False),
        sa.Column("target_text", sa.Text(), nullable=False),
        sa.Column("source_language", sa.String(length=10), server_default="zh"),
        sa.Column("target_language", sa.String(length=10), nullable=False),
        sa.Column("transliteration", sa.Text(), nullable=True),
        sa.Column("is_custom", sa.Boolean(), server_default=sa.text("0")),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("use_count", sa.Integer(), server_default="0"),
        sa.Column("priority", sa.Integer(), server_default="0"),
        sa.Column("last_used_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )
    op.create_index(
        "idx_scene_phrases_category_lang",
        "scene_phrases",
        ["scene_category", "target_language"],
    )
    op.create_index("ix_scene_phrases_target_language", "scene_phrases", ["target_language"])

    op.create_table(
        "conversations",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("destination", sa.String(length=100), nullable=True),
        sa.Column("source_language", sa.String(length=10), nullable=False),
        sa.Column("target_language", sa.String(length=10), nullable=False),
        sa.Column("message_count", sa.Integer(), server_default="0"),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now()),
    )

    op.create_table(
        "messages",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column(
            "conversation_id",
            sa.String(length=36),
            sa.ForeignKey("conversations.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("speaker", sa.String(length=20), nullable=False),
        sa.Column("source_text", sa.Text(), nullable=False),
        sa.Column("translated_text", sa.Text(), nullable=False),
        sa.Column("input_type", sa.String(length=20), server_default="text"),
        sa.Column("audio_url", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )
    op.create_index("ix_messages_conversation_id", "messages", ["conversation_id"])

    op.create_table(
        "favorite_phrases",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("source_text", sa.Text(), nullable=False),
        sa.Column("target_text", sa.Text(), nullable=False),
        sa.Column("source_language", sa.String(length=10), server_default="zh"),
        sa.Column("target_language", sa.String(length=10), nullable=False),
        sa.Column("scene_category", sa.String(length=50), nullable=True),
        sa.Column("source_phrase_id", sa.String(length=36), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )
    op.create_index("ix_favorite_phrases_user_id", "favorite_phrases", ["user_id"])

    op.create_table(
        "translation_cache",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("source_text", sa.Text(), nullable=False),
        sa.Column("source_language", sa.String(length=10), nullable=False),
        sa.Column("target_language", sa.String(length=10), nullable=False),
        sa.Column("translated_text", sa.Text(), nullable=False),
        sa.Column("transliteration", sa.Text(), nullable=True),
        sa.Column("engine", sa.String(length=50), server_default="mock"),
        sa.Column("hit_count", sa.Integer(), server_default="1"),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
        sa.UniqueConstraint(
            "source_text",
            "source_language",
            "target_language",
            name="uq_translation_cache_text_pair",
        ),
    )


def downgrade() -> None:
    """回滚。"""
    op.drop_table("translation_cache")
    op.drop_index("ix_favorite_phrases_user_id", table_name="favorite_phrases")
    op.drop_table("favorite_phrases")
    op.drop_index("ix_messages_conversation_id", table_name="messages")
    op.drop_table("messages")
    op.drop_table("conversations")
    op.drop_index("ix_scene_phrases_target_language", table_name="scene_phrases")
    op.drop_index("idx_scene_phrases_category_lang", table_name="scene_phrases")
    op.drop_table("scene_phrases")
    op.drop_index("ix_users_device_id", table_name="users")
    op.drop_table("users")
