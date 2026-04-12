# 架构概览

## 分层

```
┌──────────────────────────────────────────────────┐
│                    客户端                         │
│  ┌──────────────┐      ┌──────────────────────┐  │
│  │  Android App │      │      iOS App         │  │
│  │  Compose     │      │      SwiftUI         │  │
│  └──────┬───────┘      └──────────┬───────────┘  │
│         │                        │               │
│         └────────┬───────────────┘               │
│                  │ HTTPS / JSON                  │
└──────────────────┼──────────────────────────────┘
┌──────────────────┼──────────────────────────────┐
│                后端服务                           │
│  ┌───────────────┼────────────────────────────┐  │
│  │            FastAPI (Python 3.12)           │  │
│  │  ┌──────────────────────────────────────┐  │  │
│  │  │  translate / phrases / conversations │  │  │
│  │  │  favorites / ocr(stub) / speech(stub)│  │  │
│  │  └──────────────────────────────────────┘  │  │
│  └───────────────┼────────────────────────────┘  │
│                  │                               │
│  ┌───────────────┼────────────────────────────┐  │
│  │  SQLite (via SQLAlchemy async + Alembic)   │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

## 后端目录

```
backend/
├── app/
│   ├── main.py              # FastAPI 入口 + lifespan
│   ├── config.py            # pydantic-settings 配置
│   ├── core/                # database / logging
│   ├── models/              # SQLAlchemy ORM
│   ├── schemas/             # Pydantic 请求/响应模型
│   ├── services/            # 业务逻辑
│   │   ├── translation_service.py   # 引擎路由（mock / Claude）
│   │   ├── phrase_service.py        # 短语 CRUD + JSON 导入
│   │   └── conversation_service.py  # 对话管理
│   ├── api/
│   │   ├── router.py        # 聚合路由
│   │   └── v1/              # 版本化路由
│   └── data/phrases/        # 预置短语 JSON
├── migrations/              # Alembic
└── tests/                   # pytest
```

## 翻译引擎路由

```
                ┌─────────────┐
request ───────▶│ 查询缓存表  │──hit──▶ 返回 cached=True
                └─────┬───────┘
                      │ miss
                      ▼
          engine = anthropic? ──yes──▶ Claude API
                      │
                      no (或失败降级)
                      ▼
              使用兜底字典 / echo 原文
                      │
                      ▼
              写入缓存表 + 返回
```

- **兜底策略**：Claude 调用失败自动降级到内置字典或 echo，保证 API 可用。
- **缓存**：按 `(source_text, source_language, target_language)` 唯一约束。
- **上下文**：`context` 字段（如 `restaurant`）会注入 Claude prompt 以提升翻译准确度。

## 客户端数据流

### Android（单向数据流 + Repository）

```
UI (Compose) ─event→ ViewModel ─call→ Repository ─HTTP→ Backend
      ▲                                    │
      └─────────── StateFlow ←──────────────┘
                                Room 本地缓存 (offline)
```

### iOS（MVVM + async/await）

```
View (SwiftUI) ─binding→ @Published ViewModel ─await→ Service ─URLSession→ Backend
```

## 离线策略

- Android：Room 数据库缓存预置短语包（`PhraseRepository.syncPackage`），场景列表直接读 DAO，离线可浏览。
- iOS：当前版本直接调后端获取，后续可落地到 Core Data / SwiftData 实现完整离线。
- TTS：端侧系统语音合成器离线可用（iOS `AVSpeechSynthesizer`，Android `TextToSpeech`）。
