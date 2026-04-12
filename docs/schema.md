# 数据模型

SQLite via SQLAlchemy 2.0 async，所有表由 Alembic 管理。

## ER

```
users ──< conversations ──< messages
  │
  └──< favorite_phrases

scene_phrases (预置 + 用户自定义)
translation_cache (高频翻译缓存)
```

## 表结构

### users

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | UUID |
| device_id | VARCHAR(255) UNIQUE | 设备标识 |
| default_source_language | VARCHAR(10) | 默认源语言 |
| created_at / updated_at | DATETIME | 时间戳 |

### scene_phrases

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | UUID |
| scene_category | VARCHAR(50) | restaurant / transport / … |
| subcategory | VARCHAR(50) | 点餐 / 结账 … |
| source_text | TEXT | 原文（中文） |
| target_text | TEXT | 译文 |
| source_language | VARCHAR(10) | 默认 zh |
| target_language | VARCHAR(10) | ja / ko / en … |
| transliteration | TEXT | 注音/罗马音 |
| is_custom | BOOLEAN | 自定义短语标记 |
| user_id | VARCHAR(36) FK users | 自定义短语关联用户 |
| use_count | INTEGER | 使用次数 |
| priority | INTEGER | 排序权重 |
| last_used_at | DATETIME | 最近使用时间 |
| created_at | DATETIME | 时间戳 |

索引：`(scene_category, target_language)`、`target_language`

### conversations

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | UUID |
| user_id | VARCHAR(36) FK | 可选 |
| destination | VARCHAR(100) | 目的地 |
| source_language / target_language | VARCHAR(10) | 方向 |
| message_count | INTEGER | 消息数 |
| created_at / updated_at | DATETIME | |

### messages

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | UUID |
| conversation_id | FK ON DELETE CASCADE | |
| speaker | VARCHAR(20) | user / counterpart |
| source_text / translated_text | TEXT | |
| input_type | VARCHAR(20) | text / voice / photo |
| audio_url | TEXT | 可选 |
| created_at | DATETIME | |

索引：`conversation_id`

### favorite_phrases

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | |
| user_id | VARCHAR(36) FK | 必填 |
| source_text / target_text | TEXT | |
| source_language / target_language | VARCHAR(10) | |
| scene_category | VARCHAR(50) | 可选 |
| source_phrase_id | VARCHAR(36) | 可选，关联 scene_phrases |

### translation_cache

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | |
| source_text / source_language / target_language | — | 三元组唯一 |
| translated_text | TEXT | |
| transliteration | TEXT | 可空 |
| engine | VARCHAR(50) | mock / anthropic |
| hit_count | INTEGER | 命中次数 |

唯一约束：`(source_text, source_language, target_language)`

## 迁移

初始迁移：`migrations/versions/20260412_0001_initial.py`。

```bash
cd backend
uv run alembic revision --autogenerate -m "变更描述"
uv run alembic upgrade head
```
